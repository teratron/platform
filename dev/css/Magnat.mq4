//+------------------------------------------------------------------+
//|                                                       Magnat.mq4 |
//|                                Copyright © 2018, Alexandrov Oleg |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2018, Metaquotes"
#property link      "http://www.metaquotes.ru"
#property version   "3.00"
#property strict

#define MAGIC       9797
//extern int    SetHour = 15;
//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input ENUM_TIMEFRAMES TimeFrame = PERIOD_H1;
//PERIOD_H4 - 240 / 180 / 120 / 60
//PERIOD_H1 - 60

extern bool   TradeON      = true;  //Вкл/Выкл. торговли
extern double BarProfit    = 40;    //BarProfit (пункты), высота тела свечи
extern double TakeProfit   = 200;   //TakeProfit (пункты)
extern double StopLoss     = 200;   //StopLoss (пункты)
extern double TrailingStop = 150;   //TrailingStop (пункты), если 0, то отключен
/*extern*/ int    TimeDelay    = 10;    //Задержка (минуты)
/*extern*/ int    TimeLimit    = 50;    //Предел (минуты)

//Параметры модуля расчёта лота
//-----------------------------------------
extern double LotsDepoOne = 0.0; //Размер депозита для одного минилота и по достижению которого начинается увеличения лота, 0 - фиксированный лот,

//Параметры расчёта истории баланса
//-----------------------------------------
extern datetime StartTimeBalance = D'2018.12.01';

//+------------------------------------------------------------------+
//| Parameters                                                       |
//+------------------------------------------------------------------+
string   Label;
datetime BarTimer;
double   TP, SL, TS, BP;
double   Points, Balance;
double   Lots, LotsMax, LotsMin;
double   ProfitBuy  = 0.0;
double   ProfitSell = 0.0;
int      MaxSpread  = 20;
int      Attempts   = 10;
int      Slippage   = 20;
int      Digit, Magic;

//Arrays
//-----------------------------------------
double D[24,7];
int TD[24], TL[24];

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
	Digit   = (int)MarketInfo(NULL, MODE_DIGITS);
	LotsMax = MarketInfo(NULL, MODE_MAXLOT);
	LotsMin = MarketInfo(NULL, MODE_MINLOT);
	Points  = MarketInfo(NULL, MODE_POINT);

	SL = StopLoss*Points;
	BP = BarProfit*Points;
	TP = TakeProfit*Points;
	TS = TrailingStop*Points;
	BarTimer = TimeCurrent();

	//Magic эксперта
	//-----------------------------------------
	if (IsDemo()) Magic = 63797/*MAGIC + TimeFrame*100*/; else Magic = MAGIC;

	//Текст комментария ордера
	//-----------------------------------------
	if (Magic != MAGIC) Label = "Magnat #" + (string)Magic; else Label = "Magnat";

	//Проверка состояния для нормальной работы эксперта
	//-----------------------------------------
	if (!IsTesting() || IsVisualMode()) {
		if (Magic > 2147483646 || TakeProfit < StopLoss || TakeProfit < TrailingStop)
			Alert("Условия не соответствуют нормальной работе эксперта");
		Lots = GetSizeLot();
	}

	//Удаляем эксперт при не совпадении условий
	//-----------------------------------------
	if (IsOptimization())
		if (Magic > 2147483646 || TakeProfit < StopLoss || TakeProfit < TrailingStop) ExpertRemove();

	//TimeFrame/PERIOD_H1   PERIOD_D1/TimeFrame
	//-----------------------------------------
	for (int i=0; i<24; i+=TimeFrame/PERIOD_H1) AnalizeBars(TimeFrame, i);
	//AnalizeBars(TimeFrame, SetHour);

	if (!IsTesting())
		if (DayOfWeek() == 5 || DayOfWeek() == 1) OnTick();
//---
	return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
	if (!IsTesting()) {
		WriteStatistic();
		Comment("");
	}
//---
   return;
}
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
void OnTick() {
//---
	int i, j, k;
	bool check = false;
	datetime timer_buy  = 0;
	datetime timer_sell = 0;

	//Счётчик открытых позиций
	//-----------------------------------------
	int order_sell = 0;
	int order_buy  = 0;

	ProfitSell = 0.0;
	ProfitBuy  = 0.0;

	for (i=0; i<OrdersTotal(); i++) {
		if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderMagicNumber() == Magic && OrderSymbol() == Symbol()) {
			if (OrderType() == OP_BUY) {
				if (timer_buy < OrderOpenTime()) timer_buy = OrderOpenTime();
				ProfitBuy += OrderProfit();
				order_buy++;
			}
			if (OrderType() == OP_SELL) {
				if (timer_sell < OrderOpenTime()) timer_sell = OrderOpenTime();
				ProfitSell += OrderProfit();
				order_sell++;
			}
		}
	}
	if (timer_buy == 0 || timer_sell == 0) {
		for (i=0; i<OrdersHistoryTotal(); i++) {
			if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && OrderMagicNumber() == Magic && OrderSymbol() == Symbol()) {
				if (OrderType() == OP_BUY  && timer_buy  < OrderOpenTime()) timer_buy  = OrderOpenTime();
				if (OrderType() == OP_SELL && timer_sell < OrderOpenTime()) timer_sell = OrderOpenTime();
			}
		}
	}

	//Закрытие по истечению бара
	//--------------------------------------------
	if (TimeFrame < PERIOD_H1) {
		for (i=0; i<PERIOD_H1/TimeFrame; i++) {
			check = Minute() == TimeFrame*(i + 1) - 1;
			if (check) break;
		}
	} else {
		if (TimeFrame > PERIOD_H1) check = Minute() == 59 && TimeHour(iTime(NULL, TimeFrame, 0)) + TimeFrame/PERIOD_H1 - 1 == Hour();
		else check = Minute() == 59;
	}
	if (check) {
		if (order_buy  > 0) order_buy  = CloseOrder(OP_BUY);
		if (order_sell > 0) order_sell = CloseOrder(OP_SELL);
	}

	//Открытие
	//--------------------------------------------
	if (iBarShift(NULL, TimeFrame, BarTimer) > 0) {
		if (TradeON && TimeAllowed() && MarketInfo(NULL, MODE_SPREAD) <= MaxSpread && order_buy == 0 && order_sell == 0) {
			k = 0;

			if (TimeFrame < PERIOD_H1) {
				for (i=0; i<PERIOD_H1/TimeFrame; i++) {
					j = TimeFrame*i;
					if (Minute() >= TimeDelay + j && Minute() < TimeLimit + j && Minute() < TimeFrame + j) {
					    k = 1;
					    break;
					}
				}
			} else {
				if (TimeFrame > PERIOD_H1) {
					j = (Hour() - TimeHour(iTime(NULL, TimeFrame, 0)))*PERIOD_H1 + Minute();
					if (j >= TimeDelay && j < TimeLimit) {
					    k = 1;
					}
				} else {
					if (Minute() >= TD[Hour()] && Minute() <= TL[Hour()]) {
				    //if (Minute() >= TimeDelay && Minute() < TimeLimit) {
				        k = 1;
				    }
				}
			}

			if (k > 0) {
				Lots = GetSizeLot();
				double open = iOpen(NULL, TimeFrame, 0);
				double bid  = MarketInfo(NULL, MODE_BID);
				double ask  = MarketInfo(NULL, MODE_ASK);

				if (k == 1 && iHigh(NULL, PERIOD_M1, 0) > open && iLow(NULL, PERIOD_M1, 0) < open) {
					double low  = open - iLow(NULL, TimeFrame, 0);
					double high = iHigh(NULL, TimeFrame, 0) - open;

					if (high < low && iHigh(NULL, PERIOD_M1, 1) < open /*&& iOpen(NULL, TimeFrame, 1) < open*/ && iBarShift(NULL, TimeFrame, timer_buy) > 0) {
						i = OpenOrder(OP_BUY, Lots, ask, bid-SL, bid+TP, Label, 0);
						BarTimer = TimeCurrent();
					}
					if (high > low && iLow(NULL, PERIOD_M1, 1) > open /*&& iOpen(NULL, TimeFrame, 1) > open*/ && iBarShift(NULL, TimeFrame, timer_sell) > 0) {
						i = OpenOrder(OP_SELL, Lots, bid, ask+SL, ask-TP, Label, 0);
						BarTimer = TimeCurrent();
					}
				}
			}
		}
	}

	//TrailingStop
	//--------------------------------------------
	if (TrailingStop > 0.0)
		if (order_buy > 0 || order_sell > 0) TrailingOrder();

	//Вывод информации
	//--------------------------------------------
	if (!IsTesting() || IsVisualMode()) {
		Balance = GetHistoryBalance(); //Считаем баланс для текущего эксперта
		Info(GetLastError());
	}
//---
}
//+------------------------------------------------------------------+
//| Анализируем бары                                                 |
//+------------------------------------------------------------------+
void AnalizeBars(int timeframe, int hour) {
//---
	int i, j, delay, limit;
	int s = hour*3600;
	int sum_delay = 0, sum_limit = 0;
	int cnt_delay = 0, cnt_limit = 0;

	int min = timeframe, max = 0;
	int avg = 0, avg_min = 0, avg_max = 0, avg_min_max = 0;

	for (i=1; i<iBars(NULL, PERIOD_D1); i++) {
		datetime t = iTime(NULL, PERIOD_D1, i) + s;
		int h = iBarShift(NULL, timeframe, t);
		int m = iBarShift(NULL, PERIOD_M1, t);

		double open  = iOpen (NULL, timeframe, h);
		double close = iClose(NULL, timeframe, h);
		double high  = iHigh (NULL, timeframe, h) - open;
		double low   = open - iLow(NULL, timeframe, h);

		//Time Delay
		for (j=m-1, delay=1; j>m-timeframe; j--) {
			if (iHigh(NULL, PERIOD_M1, j) > open && iLow(NULL, PERIOD_M1, j) < open) {
				if ((close-open > BP && high < low && iHigh(NULL, PERIOD_M1, j+1) < open) ||
				    (open-close > BP && high > low && iLow (NULL, PERIOD_M1, j+1) > open)) break;
			}
			delay++;
		}
		if (delay > 1 && delay < timeframe) {
		    //Print("   ",delay);
			//if (min > delay) min = delay;
			//if (max < delay) max = delay;
			sum_delay += delay;
			cnt_delay++;
		}

		//Time Limit
		for (j=m-timeframe+1, limit=timeframe-1; j<m; j++) {
			if (iHigh(NULL, PERIOD_M1, j) > open && iLow(NULL, PERIOD_M1, j) < open) {
				if ((close-open > BP && high < low && iHigh(NULL, PERIOD_M1, j+1) < open) ||
				    (open-close > BP && high > low && iLow (NULL, PERIOD_M1, j+1) > open)) break;
			}
			limit--;
		}
		if (limit > 1 && limit < timeframe) {
			//Print("   ",limit);
			//if (min > limit) min = limit;
			//if (max < limit) max = limit;
			sum_limit += limit;
			cnt_limit++;
		}
	}

	//Print("--- ",sum_delay," ",cnt_delay);
	//Print("--- ",sum_limit," ",cnt_limit/*,"  min ",min,"  max ",max*/);

	if (cnt_delay > 0) TD[hour] = (int)MathRound(sum_delay*1.0/cnt_delay);
	if (cnt_limit > 0) TL[hour] = (int)MathRound(sum_limit*1.0/cnt_limit);
	//Print(TD[hour]," / ",TL[hour]);
}
//+------------------------------------------------------------------+
//| Сигнал Moving Average                                            |
//+------------------------------------------------------------------+
/*int GetSignalMA(int timeframe, int period, int methode, int price, int shift) {
//---
	double ma_0 = iMA(NULL, timeframe, period, 0, methode, price, shift);
	double ma_1 = iMA(NULL, timeframe, period, 0, methode, price, shift+1);

	if (ma_0 > ma_1) {
	   if (ma_1 < iMA(NULL, timeframe, period, 0, methode, price, shift+2)) return(2);
	   return(1);
	}
	if (ma_0 < ma_1) {
	   if (ma_1 > iMA(NULL, timeframe, period, 0, methode, price, shift+2)) return(-2);
	   return(-1);
	}
//---
   return(0);
}*/
//+------------------------------------------------------------------+
//| Сигнал Moving Average                                            |
//+------------------------------------------------------------------+
/*int GetSignalMA(int timeframe, int period, int methode, int price, int shift) {
//---
	int i, j, k;
	double ma_0, ma_1;

	for (i=1, j=0, k=0; i<=period; i++) {
		ma_0 = iMA(NULL, timeframe, i, 0, methode, price, shift);
		ma_1 = iMA(NULL, timeframe, i, 0, methode, price, shift+1);

		if (ma_0 != ma_1) {
			if (ma_0 > ma_1) {
			   j++;
			   if (j == period) {
				   if (ma_1 < iMA(NULL, timeframe, i, 0, methode, price, shift+2)) return(2);
				   return(1);
				}
			} else {
			   k++;
			   if (k == period) {
				   if (ma_1 > iMA(NULL, timeframe, i, 0, methode, price, shift+2)) return(-2);
				   return(-1);
				}
			}
		} else return(0);

		if (j > 0 && k > 0) return(0);
	}
//---
   return(0);
}*/
//+------------------------------------------------------------------+
//| Сигнал ATR                                                       |
//+------------------------------------------------------------------+
/*int GetSignalATR(int timeframe, int period, double level, int shift) {
//---
   int i, j, k, p = period - 1;
	double atr_0, atr_1, avg = 0.0;

	for (i=2, j=0, k=0; i<=period; i++) {
      atr_0 = iATR(NULL, timeframe, period, shift);
      atr_1 = iATR(NULL, timeframe, period, shift+1);
      avg  += atr_0;

		if (atr_0 != atr_1) {
			if (atr_0 > atr_1) {
			   j++;
			   if (j == p) {
			      avg /= p;
				   if (avg > level*Points) return(2);
				   return(1);
				}
			} else {
			   k++;
			   if (k == p) {
			      avg /= p;
				   if (avg < level*Points) return(-2);
				   return(-1);
				}
			}
		} else return(0);

		if (j > 0 && k > 0) return(0);
	}
//---
   return(0);
}*/
//+------------------------------------------------------------------+
//| Сигнал Standart Deviation                                        |
//+------------------------------------------------------------------+
/*int GetSignalStDev(int timeframe, int period, int methode, int price, double level, int shift) {
//---
   int i, j, k, p = period - 1;
	double std_0, std_1, avg = 0.0;

	for (i=2, j=0, k=0; i<=period; i++) {
      std_0 = iStdDev(NULL, timeframe, i, 0, methode, price, shift);
      std_1 = iStdDev(NULL, timeframe, i, 0, methode, price, shift+1);
      avg  += std_0;

		if (std_0 != std_1) {
			if (std_0 > std_1) {
			   j++;
			   if (j == p) {
			      avg /= p;
				   if (avg > level*Points) return(2);
				   return(1);
				}
			} else {
			   k++;
			   if (k == p) {
			      avg /= p;
				   if (avg < level*Points) return(-2);
				   return(-1);
				}
			}
		} else return(0);

		if (j > 0 && k > 0) return(0);
	}
//---
   return(0);
}*/
//+------------------------------------------------------------------+
//| Открытие ордера                                                  |
//+------------------------------------------------------------------+
int OpenOrder(int type, double lots, double price, double sl, double tp, string label, datetime xp) {
//---
	int ticket, k = 0;

	while (true) {
		ticket = -1;
		switch (type) {
			case OP_BUY      : ticket = OrderSend(Symbol(), type, lots, price, Slippage, sl, tp, label, Magic,  0, clrBlue);      break;
			case OP_SELL     : ticket = OrderSend(Symbol(), type, lots, price, Slippage, sl, tp, label, Magic,  0, clrRed);       break;
			case OP_BUYSTOP  : ticket = OrderSend(Symbol(), type, lots, price, Slippage, sl, tp, label, Magic, xp, clrRoyalBlue); break;
			case OP_SELLSTOP : ticket = OrderSend(Symbol(), type, lots, price, Slippage, sl, tp, label, Magic, xp, clrTomato);    break;
			case OP_BUYLIMIT : ticket = OrderSend(Symbol(), type, lots, price, Slippage, sl, tp, label, Magic, xp, clrRoyalBlue); break;
			case OP_SELLLIMIT: ticket = OrderSend(Symbol(), type, lots, price, Slippage, sl, tp, label, Magic, xp, clrTomato);    break;
			default          : return(ticket);
		}
		if (ticket < 0) {
			k++;
			if (k >= Attempts) {
				if (!IsTesting()) Print("Не удалось открыть/отложить ордер");
				Sleep(5000);
				return(ticket);
			}
			Sleep(1000);
			RefreshRates();
		} else return(ticket);
	}
//---
	return(-1);
}
//+------------------------------------------------------------------+
//| Закрытие ордеров                                                 |
//+------------------------------------------------------------------+
int CloseOrder(int type) {
//---
	string text = "закрыть";
	bool   check;
	int    i, j, k;

	for (i=OrdersTotal()-1, j=0; i>=0; i--) {
		if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderMagicNumber() == Magic && OrderSymbol() == Symbol() && OrderType() == type) {
			j++;
			k = 0;
			while (true) {
				switch (type) {
					case OP_BUY      : check = OrderClose(OrderTicket(), OrderLots(), MarketInfo(NULL, MODE_BID), Slippage, clrViolet); break;
					case OP_SELL     : check = OrderClose(OrderTicket(), OrderLots(), MarketInfo(NULL, MODE_ASK), Slippage, clrViolet); break;
      				case OP_BUYSTOP  :
      				case OP_SELLSTOP :
      				case OP_BUYLIMIT :
      				case OP_SELLLIMIT: check = OrderDelete(OrderTicket()); text = "удалить отложенный"; break;
					default          : return(0);
				}
				if (check) {
   				j--;
   				break;
				} else {
					k++;
					if (k >= Attempts) {
						if (!IsTesting()) Print("Не удалось ",text," ордер");
						Sleep(5000);
						break;
					}
					Sleep(1000);
					RefreshRates();
				}
			}
		}
	}
//---
	return(j);
}
//+------------------------------------------------------------------+
//| TrailingStop                                                     |
//+------------------------------------------------------------------+
void TrailingOrder() {
//---
   bool check;
   double sl_buy  = MarketInfo(NULL, MODE_BID) - TS;
   double sl_sell = MarketInfo(NULL, MODE_ASK) + TS;

	for (int i=0; i<OrdersTotal(); i++) {
		if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderMagicNumber() == Magic && OrderSymbol() == Symbol()) {
			if (OrderType() == OP_BUY && OrderOpenPrice() <= sl_buy && OrderStopLoss()+TS <= sl_buy)
				check = OrderModify(OrderTicket(), OrderOpenPrice(), sl_buy, OrderTakeProfit(), 0, clrGreen);

			if (OrderType() == OP_SELL && OrderOpenPrice() >= sl_sell && OrderStopLoss()-TS >= sl_sell)
				check = OrderModify(OrderTicket(), OrderOpenPrice(), sl_sell, OrderTakeProfit(), 0, clrGreen);
		}
	}
//---
	return;
}
//+------------------------------------------------------------------+
//| Разрешение на торговлю                                           |
//+------------------------------------------------------------------+
bool TimeAllowed() {
//---
	int week = DayOfWeek();
	int hour = Hour();

	if ((week != 1 || (week == 1 && hour > 3)) &&
		(week != 5 || (week == 5 && hour < 20))) return(true);
//---
	return(false);
}
//+------------------------------------------------------------------+
//| Размер лота                                                      |
//+------------------------------------------------------------------+
double GetSizeLot() {
//---
	double lots = LotsMin;

	if (LotsDepoOne > 0.0 && AccountBalance() >= LotsDepoOne) lots = NormalizeDouble(AccountBalance()/LotsDepoOne*LotsMin, 2);
	if (lots > LotsMax) lots = LotsMax;
	if (lots < LotsMin) lots = LotsMin;
//---
	return(lots);
}
//+------------------------------------------------------------------+
//| Возвращает сумму баланса за определённый период                  |
//+------------------------------------------------------------------+
double GetHistoryBalance() {
//---
	int i, j, k;
	double profit  = 0.0;
	double balance = 0.0;

	ArrayInitialize(D, 0.0);

	for (i=0; i<OrdersHistoryTotal(); i++) {
		if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && OrderMagicNumber() == Magic && OrderSymbol() == Symbol() && OrderOpenTime() >= StartTimeBalance) {
			if (OrderType() == OP_BUY || OrderType() == OP_SELL) {
				profit   = OrderProfit() + OrderSwap() + OrderCommission();
				balance += profit;

				for (j=0; j<24; j++)
					if (TimeHour(OrderOpenTime()) == j) break;

				for (k=1; k<6; k++)
					if (TimeDayOfWeek(OrderOpenTime()) == k) break;

				D[j,k] += profit;
			}
		}
	}
//---
   return(balance);
}
//+------------------------------------------------------------------+
//| Записывает статистику в файл                                     |
//+------------------------------------------------------------------+
void WriteStatistic() {
//---
	double balance = GetHistoryBalance();

	//Название файла
	string filename = "Magnat_" + Symbol() + "_M" + (string)TimeFrame + "_#" + (string)Magic + ".txt";

	//Запись в файл
	int handle = FileOpen(filename, FILE_CSV|FILE_WRITE, "\t");

	FileWrite(handle, "TimeFrame", TimeFrame);
	FileWrite(handle, "TakeProfit", TakeProfit);
	FileWrite(handle, "StopLoss", StopLoss);
	FileWrite(handle, "TrailingStop", TrailingStop);
	FileWrite(handle, "");
	FileWrite(handle, "Час", "|", "Сумма", "|", "Пн", "Вт", "Ср", "Чт", "Пт");
	FileWrite(handle, " ", "|", " ", "|");

	for (int i=0; i<24; i++) {
		double depohour = 0.0;
		for (int j=1; j<6; j++) {
			depohour += D[i,j];
			D[j-1,0] += D[i,j];
		}
		FileWrite(handle, i, "|", DoubleToString(depohour, 2), "|", DoubleToString(D[i,1], 2), DoubleToString(D[i,2], 2), DoubleToString(D[i,3], 2), DoubleToString(D[i,4], 2), DoubleToString(D[i,5], 2));
	}
	FileWrite(handle, " ", "|", " ", "|");
	FileWrite(handle, "Баланс:", " ", DoubleToString(balance, 2), "|", DoubleToString(D[0,0], 2), DoubleToString(D[1,0], 2), DoubleToString(D[2,0], 2), DoubleToString(D[3,0], 2), DoubleToString(D[4,0], 2));
	FileClose(handle);
//---
	return;
}
//+------------------------------------------------------------------+
//| Возвращает описание ошибки                                       |
//+------------------------------------------------------------------+
string ErrorDescription(int code) {
//---
	string error;

	switch(code) {
		//Коды ошибок от торгового сервера:
		case 0   : error = "Нет ошибки";                                               break;
		case 1   : error = "Нет ошибки, но результат неизвестен";                      break;
		case 2   : error = "Общая ошибка";                                             break;
		case 3   : error = "Неправильные параметры";                                   break;
		case 4   : error = "Торговый сервер занят";                                    break;
		case 5   : error = "Старая версия клиентского терминала";                      break;
		case 6   : error = "Нет связи с торговым сервером";                            break;
		case 7   : error = "Недостаточно прав";                                        break;
		case 8   : error = "Слишком частые запросы";                                   break;
		case 9   : error = "Недопустимая операция нарушающая функционирование сервера";break;
		case 64  : error = "Счет заблокирован";                                        break;
		case 65  : error = "Неправильный номер счета";                                 break;
		case 128 : error = "Истек срок ожидания совершения сделки";                    break;
		case 129 : error = "Неправильная цена";                                        break;
		case 130 : error = "Неправильные стопы";                                       break;
		case 131 : error = "Неправильный объем";                                       break;
		case 132 : error = "Рынок закрыт";                                             break;
		case 133 : error = "Торговля запрещена";                                       break;
		case 134 : error = "Недостаточно денег для совершения операции";               break;
		case 135 : error = "Цена изменилась";                                          break;
		case 136 : error = "Нет цен";                                                  break;
		case 137 : error = "Брокер занят";                                             break;
		case 138 : error = "Новые цены";                                               break;
		case 139 : error = "Ордер заблокирован и уже обрабатывается";                  break;
		case 140 : error = "Разрешена только покупка";                                 break;
		case 141 : error = "Слишком много запросов";                                   break;
		case 145 : error = "Модификация запрещена, т.к. ордер слишком близок к рынку"; break;
		case 146 : error = "Подсистема торговли занята";                               break;
		case 147 : error = "Использование даты истечения ордера запрещено брокером";   break;
		case 148 : error = "Количество открытых и отложенных ордеров достигло предела";break;
		case 149 : error = "Попытка открыть противоположную позицию к уже существующей в случае, если хеджирование запрещено";break;
		case 150 : error = "Попытка закрыть позицию в противоречии с правилом FIFO";   break;

		//Коды ошибок выполнения MQL4-программы:
		case 4000: error = "Нет ошибки";                                               break;
		case 4001: error = "Неправильный указатель функции";                           break;
		case 4002: error = "Индекс массива - вне диапазона";                           break;
		case 4003: error = "Нет памяти для стека функций";                             break;
		case 4004: error = "Переполнение стека после рекурсивного вызова";             break;
		case 4005: error = "На стеке нет памяти для передачи параметров";              break;
		case 4006: error = "Нет памяти для строкового параметра";                      break;
		case 4007: error = "Нет памяти для временной строки";                          break;
		case 4008: error = "Неинициализированная строка";                              break;
		case 4009: error = "Неинициализированная строка в массиве";                    break;
		case 4010: error = "Нет памяти для строкового массива";                        break;
		case 4011: error = "Слишком длинная строка";                                   break;
		case 4012: error = "Остаток от деления на ноль";                               break;
		case 4013: error = "Деление на ноль";                                          break;
		case 4014: error = "Неизвестная команда";                                      break;
		case 4015: error = "Неправильный переход";                                     break;
		case 4016: error = "Неинициализированный массив";                              break;
		case 4017: error = "Вызовы DLL не разрешены";                                  break;
		case 4018: error = "Невозможно загрузить библиотеку";                          break;
		case 4019: error = "Невозможно вызвать функцию";                               break;
		case 4020: error = "Вызовы внешних библиотечных функций не разрешены";         break;
		case 4021: error = "Недостаточно памяти для строки, возвращаемой из функции";  break;
		case 4022: error = "Система занята";                                           break;
		case 4050: error = "Неправильное количество параметров функции";               break;
		case 4051: error = "Недопустимое значение параметра функции";                  break;
		case 4052: error = "Внутренняя ошибка строковой функции";                      break;
		case 4053: error = "Ошибка массива";                                           break;
		case 4054: error = "Неправильное использование массива-таймсерии";             break;
		case 4055: error = "Ошибка пользовательского индикатора";                      break;
		case 4056: error = "Массивы несовместимы";                                     break;
		case 4057: error = "Ошибка обработки глобальныех переменных";                  break;
		case 4058: error = "Глобальная переменная не обнаружена";                      break;
		case 4059: error = "Функция не разрешена в тестовом режиме";                   break;
		case 4060: error = "Функция не разрешена";                                     break;
		case 4061: error = "Ошибка отправки почты";                                    break;
		case 4062: error = "Ожидается параметр типа string";                           break;
		case 4063: error = "Ожидается параметр типа integer";                          break;
		case 4064: error = "Ожидается параметр типа double";                           break;
		case 4065: error = "В качестве параметра ожидается массив";                    break;
		case 4066: error = "Запрошенные исторические данные в состоянии обновления";   break;
		case 4067: error = "Ошибка при выполнении торговой операции";                  break;
		case 4068: error = "Ресурс не найден";                                         break;
		case 4069: error = "Ресурс не поддерживается";                                 break;
		case 4070: error = "Дубликат ресурса";                                         break;
		case 4071: error = "Ошибка инициализации пользовательского индикатора";        break;
		case 4072: error = "Ошибка загрузки пользовательского индикатора";             break;
		case 4073: error = "Нет исторических данных";                                  break;
		case 4074: error = "Не хватает памяти для исторических данных";                break;
		case 4075: error = "Не хватает памяти для расчёта индикатора";                 break;
		case 4099: error = "Конец файла";                                              break;
		case 4100: error = "Ошибка при работе с файлом";                               break;
		case 4101: error = "Неправильное имя файла";                                   break;
		case 4102: error = "Слишком много открытых файлов";                            break;
		case 4103: error = "Невозможно открыть файл";                                  break;
		case 4104: error = "Несовместимый режим доступа к файлу";                      break;
		case 4105: error = "Ни один ордер не выбран";                                  break;
		case 4106: error = "Неизвестный символ";                                       break;
		case 4107: error = "Неправильный параметр цены для торговой функции";          break;
		case 4108: error = "Неверный номер тикета";                                    break;
		case 4109: error = "Торговля не разрешена";                                    break;
		case 4110: error = "Длинные позиции не разрешены";                             break;
		case 4111: error = "Короткие позиции не разрешены";                            break;
		case 4200: error = "Объект уже существует";                                    break;
		case 4201: error = "Запрошено неизвестное свойство объекта";                   break;
		case 4202: error = "Объект не существует";                                     break;
		case 4203: error = "Неизвестный тип объекта";                                  break;
		case 4204: error = "Нет имени объекта";                                        break;
		case 4205: error = "Ошибка координат объекта";                                 break;
		case 4206: error = "Не найдено указанное подокно";                             break;
		case 4207: error = "Ошибка при работе с объектом";                             break;
		default  : error = "Неизвестная ошибка";                                       break;
	}
//---
	return(error);
}
//+------------------------------------------------------------------+
//| Вывод информации                                                 |
//+------------------------------------------------------------------+
void Info(int error) {
//---
	Comment("-------------------------------------------------------------",
			"\nMagnat [M",(string)TimeFrame,"] #",(string)Magic,"\n",
			"-------------------------------------------------------------",
			"\nTakeProfit: ",(string)TakeProfit,
			"\nStopLoss: ",(string)StopLoss,
			"\nTrailingStop: ",(string)TrailingStop,
			"\nTimeDelay: ",(string)TD[Hour()],
			"\nTimeLimit: ",(string)TL[Hour()],
			"\nLots: ",DoubleToString(Lots, 2),
			"\nProfit: ",DoubleToString(ProfitBuy+ProfitSell, 2)," (",DoubleToString(ProfitBuy, 2),"/",DoubleToString(ProfitSell, 2),")",
			"\n----------------------",
			"\nИстория баланса с ",TimeToString(StartTimeBalance, TIME_DATE)," по текущий момент: ",DoubleToString(Balance, 2),
			"\n№",(string)error," ",ErrorDescription(error));

	if (error > 0) Print("№",(string)error," ",ErrorDescription(error));
//---
	return;
}
//+------------------------------------------------------------------+
//| end of expert                                                    |
//+------------------------------------------------------------------+