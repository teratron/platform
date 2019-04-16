//+------------------------------------------------------------------+
//|                                                     Pipsator.mq4 |
//|                                Copyright © 2017, Alexandrov Oleg |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2017, Metaquotes"
#property link      "http://www.metaquotes.ru"
#property version   "11.00"
#property strict

#define MAGIC       938

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input ENUM_TIMEFRAMES TimeFrame = PERIOD_H1;

extern bool   TradeON      = true; //Вкл/Выкл. торговли
extern double TakeProfit   = 200;  //TakeProfit (пункты)
extern double TrailingStop = 0.0;  //TrailingStop (пункты), если ноль, то отключен
extern int    Expiration   = 720;  //Время истечения отложенного ордера

//Параметры индикатора Bollinger Bands
//-----------------------------------------
extern int    BBPeriod    = 5;        //Период Bollinger Bands
extern double BBDeviation = 5.0;      //Кол-во стандартных отклонений Bollinger Bands
input ENUM_APPLIED_PRICE BBPrice = 0; //Цена Bollinger Bands (0...6)

//Параметры канала мартингейла
//-----------------------------------------
extern double Step   = 100; //Расстояние между ценой и ордерами (пункты)
extern double kLot   = 2.0; //Коэфициент увеличение лота
extern int    Orders = 10;  //Количество ордеров в канале, 0 - выставляются только 2 ордера, без мартингейла
extern int    Shift  = 0;   //Открытие на 0 - Close, 1 - Сигнал на предыдущей свече

//Параметры модуля расчёта лота
//-----------------------------------------
extern double LotsDepoOne = 0.0; //Размер депозита для одного минилота и по достижению которого начинается увеличения лота, 0 - фиксированный лот,

//Параметры расчёта истории баланса
//-----------------------------------------
extern datetime StartTimeBalance = D'2018.01.01';

//+------------------------------------------------------------------+
//| Parameters                                                       |
//+------------------------------------------------------------------+
string   Label;
datetime BarTimer;
double   TP, TS, ST;
double   Points, Balance;
double   Lots, LotsMax, LotsMin;
double   Breakeven  = 0.0;
double   ProfitBuy  = 0.0;
double   ProfitSell = 0.0;
int      MaxSpread  = 20;
int      Attempts   = 10;
int      Slippage   = 20;
int      Digit, Magic, MaxOrder, XP;

//Arrays
//-----------------------------------------
double D[24,7];
double BBM[3];
double BBU[3];
double BBL[3];

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
	Digit   = (int)MarketInfo(NULL, MODE_DIGITS);
	LotsMax = MarketInfo(NULL, MODE_MAXLOT);
	LotsMin = MarketInfo(NULL, MODE_MINLOT);
	Points  = MarketInfo(NULL, MODE_POINT);
	BarTimer = 0;

	if (Orders > 0) Breakeven = GetBreakeven();

	ST = Step*Points;
	TP = TakeProfit*Points;
	TS = TrailingStop*Points;
	XP = Expiration*60;

	//Magic эксперта
	//-----------------------------------------
	if (IsDemo()) Magic = MAGIC + TimeFrame*100 + BBPeriod*300 + (int)BBDeviation*300 + (int)Step*900 + (int)(kLot*100)*2700 + Orders*8100 + Shift*24300; else Magic = MAGIC;

	//Текст комментария ордера
	//-----------------------------------------
	if (Magic != MAGIC) Label = "Pipsator #" + IntegerToString(Magic); else Label = "Pipsator";

	//Проверка состояния для нормальной работы эксперта
	//-----------------------------------------
	if (!IsTesting() || IsVisualMode()) {
		if (Magic > 2147483646) Alert("Условия не соответствуют нормальной работе эксперта");
		Lots = GetSizeLot();
	}

	//Удаляем эксперт при не совпадении условий
	//-----------------------------------------
	if (IsOptimization())
		if (Magic > 2147483646) ExpertRemove();

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
	int i, j;
	bool check;
	datetime timer = 0, xp;
	double op_buy  = 0.0, tp_buy  = 0.0, sl_buy  = 0.0, lt_buy  = 0.0;
	double op_sell = 0.0, tp_sell = 0.0, sl_sell = 0.0, lt_sell = 0.0;
	double lt_base = 0.0, lot;
	double bid, ask, tp, sl, spread;

	//Счётчик открытых позиций
	//-----------------------------------------
	int order_sell = 0;
	int order_buy  = 0;
	int order_sellstop = 0;
	int order_buystop  = 0;

	ProfitSell = 0.0;
	ProfitBuy  = 0.0;

	for (i=0; i<OrdersTotal(); i++) {
		if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderMagicNumber() == Magic && OrderSymbol() == Symbol()) {
			if (OrderType() == OP_BUY || OrderType() == OP_SELL || OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP) {
				if (timer < OrderOpenTime()) timer = OrderOpenTime();
				if (order_buy == 0 && order_sell == 0 && order_buystop == 0 && order_sellstop == 0) lt_base = OrderLots();
				if ((OrderType() == OP_BUY && order_buy == 0) || (OrderType() == OP_BUYSTOP && order_buystop == 0)) {
					op_buy = OrderOpenPrice();
					tp_buy = OrderTakeProfit();
					sl_buy = OrderStopLoss();
				}
				if ((OrderType() == OP_SELL && order_sell == 0) || (OrderType() == OP_SELLSTOP && order_sellstop == 0)) {
					op_sell = OrderOpenPrice();
					tp_sell = OrderTakeProfit();
					sl_sell = OrderStopLoss();
				}
				if (OrderType() == OP_BUY) {
					ProfitBuy += OrderProfit();
					lt_buy    += OrderLots();
					order_buy++;
				}
				if (OrderType() == OP_SELL) {
					ProfitSell += OrderProfit();
					lt_sell    += OrderLots();
					order_sell++;
				}
				if (OrderType() == OP_BUYSTOP) {
					if (order_buystop > 0 && OrderOpenPrice() != op_buy) check = OrderModify(OrderTicket(), op_buy, sl_buy, tp_buy, OrderExpiration(), clrGreen);
					order_buystop++;
				}
				if (OrderType() == OP_SELLSTOP) {
					if (order_sellstop > 0 && OrderOpenPrice() != op_sell) check = OrderModify(OrderTicket(), op_sell, sl_sell, tp_sell, OrderExpiration(), clrGreen);
					order_sellstop++;
				}
			}
		}
	}

	if (timer == 0) {
		for (i=0; i<OrdersHistoryTotal(); i++) {
			if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && OrderMagicNumber() == Magic && OrderSymbol() == Symbol()) {
				if (OrderType() == OP_BUY || OrderType() == OP_SELL) {
					if (timer < OrderCloseTime()) timer = OrderCloseTime();
				}
			}
		}
	}

	//Контроль одновременного закрытия всех
	//ордеров по профиту
	//-----------------------------------------
	if (Orders > 0) {
		if (order_buy > 0 && order_sell == 0 && order_sellstop == 0) {
			j = CloseOrder(OP_BUY);
			if (order_buystop > 0) j = CloseOrder(OP_BUYSTOP);
			return;
		}
		if (order_buy == 0 && order_sell > 0 && order_buystop == 0) {
			j = CloseOrder(OP_SELL);
			if (order_sellstop > 0) j = CloseOrder(OP_SELLSTOP);
			return;
		}
	}

	//Закрытие ордеров по достижению профита
	//и определенного количества ордеров
	//--------------------------------------------
	if (ProfitBuy+ProfitSell > 0.0 && order_buy+order_sell > 4) {
		if (order_buy  > 0)     j = CloseOrder(OP_BUY);
		if (order_sell > 0)     j = CloseOrder(OP_SELL);
		if (order_buystop  > 0) j = CloseOrder(OP_BUYSTOP);
		if (order_sellstop > 0) j = CloseOrder(OP_SELLSTOP);
		return;
	}

	//Время истечения отложенных ордеров
	//-----------------------------------------
	if (Expiration > 0) xp = TimeCurrent() + XP; else xp = iTime(NULL, TimeFrame, 0) + TimeFrame*60 - 30;

	//Заходим при появлении нового бара
	//--------------------------------------------
	if (Shift > 0) i = iBarShift(NULL, TimeFrame, BarTimer); else i = 1;

	if (i > 0) {
		if (Shift > 0) BarTimer = TimeCurrent();

		//Окладываем первые отложенные ордера
		if (order_buy == 0 && order_sell == 0 && order_buystop == 0 && order_sellstop == 0) {
			spread = MarketInfo(NULL, MODE_SPREAD);

			if (TradeON && TimeAllowed() && iBarShift(NULL, TimeFrame, timer) > 0 && spread <= MaxSpread) {
				if (GetSignalBB(TimeFrame, BBPeriod, BBDeviation, BBPrice, Shift) == 1) {
					if (Shift == 0) BarTimer = TimeCurrent();
					Lots = GetSizeLot();
					bid  = MarketInfo(NULL, MODE_BID);
					ask  = MarketInfo(NULL, MODE_ASK);

					tp = ST + TP;
					if (Orders > 0) {
						Breakeven = GetBreakeven();
						tp += Breakeven;
						sl  = tp;
					} else {
						tp += 2*spread*Points;
						sl  = ST;
					}
					j = OpenOrder(OP_BUYSTOP,  Lots, ask+ST, bid-sl, bid+tp, Label+" @1", xp);
					j = OpenOrder(OP_SELLSTOP, Lots, bid-ST, ask+sl, ask-tp, Label+" @1", xp);
				}
			}
		}
	}

	//Открытие последующих ордеров в канале
	//--------------------------------------------
	if (Orders > 0) {
		i = order_buy + order_sell;
		if (i > 0 && i <= Orders) {
			if (MarketInfo(NULL, MODE_SPREAD) <= MaxSpread) {
				if (order_buy == 0 && order_sell == 1 && order_buystop == 1 && order_sellstop == 0) {
					lot = NormalizeDouble(MathRound(lt_base*(kLot-1)*100)/100, 2);
					if (lot < LotsMin) lot = LotsMin;
					j = OpenOrder(OP_BUYSTOP, lot, op_buy, sl_buy, tp_buy, Label+" @2", xp);
				}
				if (order_buy == 1 && order_sell == 0 && order_buystop == 0 && order_sellstop == 1) {
					lot = NormalizeDouble(MathRound(lt_base*(kLot-1)*100)/100, 2);
					if (lot < LotsMin) lot = LotsMin;
					j = OpenOrder(OP_SELLSTOP, lot, op_sell, sl_sell, tp_sell, Label+" @2", xp);
				}
				if (order_buystop == 0 && order_sellstop == 0 && lt_buy > 0 && lt_sell > 0) {
					if (lt_buy < lt_sell && order_sell > 0) {
						lot = NormalizeDouble(MathRound(lt_base*MathPow(kLot, i-1)*100)/100, 2);
						j = OpenOrder(OP_BUYSTOP, lot, op_buy, sl_buy, tp_buy, Label+" @"+IntegerToString(i), xp);
					}
					if (lt_buy > lt_sell && order_buy > 0) {
						lot = NormalizeDouble(MathRound(lt_base*MathPow(kLot, i-1)*100)/100, 2);
						j = OpenOrder(OP_SELLSTOP, lot, op_sell, sl_sell, tp_sell, Label+" @"+IntegerToString(i), xp);
					}
				}
			}
		}
	} else {
		//TrailingStop
		if (TrailingStop > 0.0)
			if (order_buy > 0 || order_sell > 0) TrailingOrder();
	}

	//Удаление ордеров после закрытия позиций
	//--------------------------------------------
	if (order_buy == 0 && order_sell == 0 && iBarShift(NULL, PERIOD_M1, BarTimer) > 0) {
		if (order_buystop  > 0 && order_sellstop == 0) j = CloseOrder(OP_BUYSTOP);
		if (order_sellstop > 0 && order_buystop  == 0) j = CloseOrder(OP_SELLSTOP);
	}

	//Вывод информации
	//--------------------------------------------
	if (!IsTesting() || IsVisualMode()) {
		Balance = GetHistoryBalance(); //Считаем баланс для текущего эксперта
		Info(GetLastError());
	}
//---
}
//+------------------------------------------------------------------+
//| Сигнал Bollinger Bands                                           |
//+------------------------------------------------------------------+
//|	double iBands(
//|		string       symbol,           // имя символа
//|		int          timeframe,        // таймфрейм
//|		int          period,           // период
//|		double       deviation,        // кол-во стандартных отклонений
//|		int          bands_shift,      // сдвиг относительно цены
//|		int          applied_price,    // тип цены
//|		int          mode,             // индекс линии: 0 - MODE_MAIN, 1 - MODE_UPPER, 2 - MODE_LOWER
//|		int          shift             // сдвиг
//|	);
//+------------------------------------------------------------------+
int GetSignalBB(int timeframe, int period, double deviation, int price, int shift) {
//---
	for (int i=0; i<4; i++) {
		BBM[i] = iBands(NULL, timeframe, period, deviation, 0, price, MODE_MAIN,  i+shift);
		BBU[i] = iBands(NULL, timeframe, period, deviation, 0, price, MODE_UPPER, i+shift);
		BBL[i] = iBands(NULL, timeframe, period, deviation, 0, price, MODE_LOWER, i+shift);
	}

	//Выход из сильного джения
	if (BBU[0] < BBU[1] && BBU[1] > BBU[2] && BBU[2] > BBU[3] &&
		BBL[0] > BBL[1] && BBL[1] < BBL[2] && BBL[2] < BBL[3]) {
		return(1);
	}

	//Выход из флета
	if (BBU[0] > BBU[1] && BBU[1] < BBU[2] && BBU[2] < BBU[3] &&
		BBL[0] < BBL[1] && BBL[1] > BBL[2] && BBL[2] > BBL[3]) {
		return(2);
	}
//---
   return(0);
}
//+------------------------------------------------------------------+
//| Безубыток                                                        |
//+------------------------------------------------------------------+
double GetBreakeven() {
//---
   double i = 0.0;
   double s = MarketInfo(NULL, MODE_SPREAD);
   double a = (Step*2 + s)*LotsMin;
   double b = -1*s*LotsMin;
   double c = LotsMin*kLot;

   while (a > b && kLot >= 1.5) {
      a += LotsMin;
      b += c;
      i++;
   }
//---
   return(NormalizeDouble(i*Points, Digit));
}
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

	if ((week != 5 || (week == 5 && hour < 23)) &&
		(week != 1 || (week == 1 && hour > 0))) return(true);
//---
	return(false);
}
//+------------------------------------------------------------------+
//| Размер лота                                                      |
//+------------------------------------------------------------------+
double GetSizeLot() {
//---
	double lots    = LotsMin;
	double lotsmax = NormalizeDouble(MathRound(LotsMax/MathPow(kLot, Orders)*100)/100, 2);

	if (LotsDepoOne > 0.0 && AccountBalance() >= LotsDepoOne) lots = NormalizeDouble(AccountBalance()/LotsDepoOne*LotsMin, 2);
	if (lots > lotsmax) lots = lotsmax;
	if (lots < LotsMin) lots = LotsMin;
//---
	return(lots);
}
//+------------------------------------------------------------------+
//| Возвращает сумму баланса за определённый период                  |
//+------------------------------------------------------------------+
double GetHistoryBalance() {
//---
	int i, j, k, n, m;
	double profit  = 0.0;
	double balance = 0.0;
	MaxOrder = 0;

	ArrayInitialize(D, 0.0);

	for (i=0; i<OrdersHistoryTotal(); i++) {
		if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && OrderMagicNumber() == Magic && OrderSymbol() == Symbol() && OrderOpenTime() >= StartTimeBalance) {
			if (OrderType() == OP_BUY || OrderType() == OP_SELL) {
				profit   = OrderProfit() + OrderSwap() + OrderCommission();
				balance += profit;

				string label = OrderComment();
				n = StringFind(label, "@", 0);
				if (n > -1) {
					n++;
					k = StringFind(label, "[", n);
					if (k > -1) k -= n; else k = 0;
					m = (int)StringToInteger(StringSubstr(label, n, k));
					if (m > MaxOrder) MaxOrder = m;
				}

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
	string filename = "Pipsator_" + Symbol() + "_M" + (string)TimeFrame + "_#" + (string)Magic + ".txt";

	//Запись в файл
	int handle = FileOpen(filename, FILE_CSV|FILE_WRITE, "\t");

	FileWrite(handle, "TimeFrame", TimeFrame);
	FileWrite(handle, "TakeProfit", TakeProfit);
	FileWrite(handle, "TrailingStop", TrailingStop);
	FileWrite(handle, "BBPeriod", BBPeriod);
	FileWrite(handle, "BBDeviation", BBDeviation);
	FileWrite(handle, "BBPrice",  BBPrice);
	FileWrite(handle, "Step    ", Step);
	FileWrite(handle, "kLot    ", kLot);
	FileWrite(handle, "Orders  ", Orders);
	FileWrite(handle, "Shift   ", Shift);
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
	FileWrite(handle, "");
	if (Orders > 0) FileWrite(handle, "Максимальное кол-во ордеров в канале", MaxOrder);
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
            "\nPipsator [M",(string)TimeFrame,"] #",(string)Magic,"\n",
            "-------------------------------------------------------------",
            "\nTakeProfit: ",(string)TakeProfit,
            "\nTrailingStop: ",(string)TrailingStop,
            "\nStep: ",(string)Step,
            "\nOrders: ",(string)Orders,
            "\nkLot: ",(string)kLot,
            "\nBBPeriod: ",(string)BBPeriod,
            "\nBBDeviation: ",(string)BBDeviation,
            "\nBBPrice: ",(string)BBPrice,
            "\nBreakeven: ",DoubleToString(Breakeven/Points, 0),
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