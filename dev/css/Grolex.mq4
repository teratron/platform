//+------------------------------------------------------------------+
//|                                                       Grolex.mq4 |
//|                                Copyright © 2016, Alexandrov Oleg |
//|                                                      71427321893 |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2016, Metaquotes"
#property link      "http://www.metaquotes.ru"
#property version   "19.00"
#property strict

#define MAGIC       7379

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input ENUM_TIMEFRAMES TimeFrame = PERIOD_H1;

/*extern*/ bool   TradeON      = true;
extern double Profit       = 5.0;  //Профит (валюта), закрывает все ордера при получении профита, если 0, то Profit - отключен
extern double Loss         = 0.0;  //Убыток (валюта), закрывает все ордера при получении убытка, если 0, то Loss - отключен
extern double TakeProfit   = 100;  //TakeProfit (пункты)
extern double StopLoss     = 100;  //StopLoss (пункты)

//Параметры индикатора RSI
//-----------------------------------------
extern int RSIPeriod = 2;  //Период RSI
extern int RSILevel  = 30; //Уровень RSI (0...100)
input ENUM_APPLIED_PRICE RSIPrice = 0; //Цена RSI (0...6)

//Параметры сетки
//-----------------------------------------
extern double Step   = 80;  //Расстояние между ордерами (пункты)
extern double kLot   = 2.0; //Коэфициент увеличение лота
extern double kStep  = 1.0; //Коэфициент увеличение шага
extern int    Orders = 5;   //Количество ордеров в веере, если 0, то выставляеться только базовая позиция
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
double   Balance, Points, SL, TP, TS, SLStep, TPStep;
double   Lots, LotsMax, LotsMin;
double   BaseBuy    = 0.0;
double   BaseSell   = 0.0;
double   ProfitBuy  = 0.0;
double   ProfitSell = 0.0;
int      Attempts   = 10;
int      Slippage   = 30;
int      Digit, Magic, MaxOrder;

//Arrays
//-----------------------------------------
double P[], D[24,7];

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
   Digit   = (int)MarketInfo(NULL, MODE_DIGITS);
   LotsMax = MarketInfo(NULL, MODE_MAXLOT);
	LotsMin = MarketInfo(NULL, MODE_MINLOT);
   Points  = MarketInfo(NULL, MODE_POINT);

   TP = TakeProfit*Points;
   SL = StopLoss*Points;
   BarTimer = 0;

   if (Step > 20) TPStep = Step; else TPStep = 20;
	SLStep = (StopLoss   - TPStep)*Points;
	TPStep = (TakeProfit - TPStep)*Points;

   //Зполняем масив шагов с учётом kStep
   //-----------------------------------------
   if (Orders > 0) {
   	ArrayResize(P, Orders);
   	P[0] = Step;
   	for (int i=1; i<Orders; i++) P[i] = P[i-1] + Step*MathPow(kStep, i);
   	SL += P[Orders-1]*Points;
   }

	//Magic эксперта
	//-----------------------------------------
	if (IsDemo()) Magic = MAGIC + TimeFrame*100 + RSIPeriod*200 + (int)Step*400+ (int)(kStep*100)*800 + (int)(kLot*100)*1600; else Magic = MAGIC;

	//Текст комментария ордера
	//-----------------------------------------
	if (Magic != MAGIC) Label = "Grolex #" + (string)Magic; else Label = "Grolex";

   //Проверка состояния для нормальной работы эксперта
   //-----------------------------------------
   if (!IsTesting() || IsVisualMode()) 
   	if (Magic > 2147483646) Alert("Условия не соответствуют нормальной работе эксперта");

   //Удаляем эксперт при не совпадении условий
   //-----------------------------------------
	if (IsOptimization())
	   if (Magic > 2147483646 || RSIPrice == 1 || RSIPrice == 2 || RSIPrice == 3 || RSIPeriod == 1) ExpertRemove();

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
	datetime timer_buy  = 0;
	datetime timer_sell = 0;
   double op_buy  = 0.0, tp_buy  = 0.0, sl_buy  = 0.0, lt_buy  = 0.0;
   double op_sell = 0.0, tp_sell = 0.0, sl_sell = 0.0, lt_sell = 0.0;
   double bid, ask, spread;

	//Счётчик открытых позиций 
	//-----------------------------------------
	int order_sell = 0;
	int order_buy  = 0;
	int sell_loss  = 0;
	int buy_loss   = 0;

	ProfitSell = 0.0;
	ProfitBuy  = 0.0;
	BaseSell   = 0.0;
	BaseBuy    = 0.0;

	for (i=0; i<OrdersTotal(); i++)
		if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderMagicNumber() == Magic && OrderSymbol() == Symbol()) {
			if (OrderType() == OP_BUY) {
			   if (timer_buy < OrderOpenTime()) timer_buy = OrderOpenTime();
			   if (order_buy == 0) {
			      BaseBuy = OrderProfit()/OrderLots();
      			op_buy = OrderOpenPrice();
      			tp_buy = OrderTakeProfit();
				   sl_buy = OrderStopLoss();
				   lt_buy = OrderLots();
				}
			   if (order_buy > 0)
			      if (OrderOpenPrice() < op_buy) buy_loss++;
			   ProfitBuy += OrderProfit();
			   order_buy++;
			}
			if (OrderType() == OP_SELL) {
			   if (timer_sell < OrderOpenTime()) timer_sell = OrderOpenTime();
			   if (order_sell == 0) {
			      BaseSell = OrderProfit()/OrderLots();
      			op_sell = OrderOpenPrice();
      			tp_sell = OrderTakeProfit();
				   sl_sell = OrderStopLoss();
				   lt_sell = OrderLots();
				}
			   if (order_sell > 0)
			      if (OrderOpenPrice() > op_sell) sell_loss++;
			   ProfitSell += OrderProfit();
			   order_sell++;
			}
		}

	if (timer_buy == 0 || timer_sell == 0)
   	for (i=0; i<OrdersHistoryTotal(); i++)
   		if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && OrderMagicNumber() == Magic && OrderSymbol() == Symbol()) {
   			if (OrderType() == OP_BUY  && timer_buy  < OrderOpenTime()) timer_buy  = OrderOpenTime();
   			if (OrderType() == OP_SELL && timer_sell < OrderOpenTime()) timer_sell = OrderOpenTime();
   		}

   //Лоты
   //--------------------------------------------
   Lots = GetSizeLot();

	//Закрытие по достижению определённого профита
	//--------------------------------------------
	double profit = ProfitBuy + ProfitSell;
	if ((Profit > 0.0 && profit >= Profit*Lots/LotsMin) || (Loss > 0.0 && profit <= Loss*Lots/LotsMin)) {
   	if (order_buy  > 0) order_buy  = CloseOrder(OP_BUY);
      if (order_sell > 0) order_sell = CloseOrder(OP_SELL);
	}

	//Заходим при появлении нового бара
	//--------------------------------------------
	if (Shift > 0) i = iBarShift(NULL, TimeFrame, BarTimer); else i = iBarShift(NULL, PERIOD_M1, BarTimer);
	if (i > 0) {
	   BarTimer = TimeCurrent();

		//Закрытие по сигналу
		if (order_sell > 0)
		   if (GetSignalRSI(TimeFrame, RSIPeriod, RSIPrice, 100-RSILevel, Shift) > 0 ||
		       GetSignalRSI(TimeFrame, RSIPeriod, RSIPrice, RSILevel, Shift) > 0) order_sell = CloseOrder(OP_SELL);

		if (order_buy > 0)
		   if (GetSignalRSI(TimeFrame, RSIPeriod, RSIPrice, 100-RSILevel, Shift) < 0 ||
		       GetSignalRSI(TimeFrame, RSIPeriod, RSIPrice, RSILevel, Shift) < 0) order_buy = CloseOrder(OP_BUY);

		//Открытие по сигналу первой/базовой позиции
		if (TradeON && TimeAllowed() && MarketInfo(NULL, MODE_SPREAD) <= Slippage) {
         i = GetSignalRSI(TimeFrame, RSIPeriod, RSIPrice, RSILevel, Shift);
         if (i != 0) {
            bid = MarketInfo(NULL, MODE_BID);
            ask = MarketInfo(NULL, MODE_ASK);
      		if (i > 0 && order_buy  == 0 && iBarShift(NULL, TimeFrame, timer_buy)  > 0) j = OpenOrder(OP_BUY,  Lots, ask, bid-SL, bid+TP, Label+" @0", 0);
      	   if (i < 0 && order_sell == 0 && iBarShift(NULL, TimeFrame, timer_sell) > 0) j = OpenOrder(OP_SELL, Lots, bid, ask+SL, ask-TP, Label+" @0", 0);
         }
      }
		if (!IsTesting() || IsVisualMode()) Balance = GetHistoryBalance(); //Считаем баланс для текущего эксперта
   }

   //Открытие позиций в сетке и поддягивание стопов
   //--------------------------------------------
	if (order_buy > 0 || order_sell > 0) {
      j = 0;
      k = 0;
      spread = MarketInfo(NULL, MODE_SPREAD);
      bid    = MarketInfo(NULL, MODE_BID);
      ask    = MarketInfo(NULL, MODE_ASK);

      if (TradeON && spread < Slippage) {
   		if (BaseBuy < 0 && buy_loss < Orders && P[buy_loss]+spread <= MathAbs(BaseBuy)) {
   		   i = buy_loss + 1;
            lt_buy = NormalizeDouble(MathRound(lt_buy*MathPow(kLot, i)*100)/100, 2);
            if (lt_buy > LotsMax) lt_buy = LotsMax;

      	   sl_buy = bid - SL;
      	   tp_buy = bid + TP;

   		   j = OpenOrder(OP_BUY, lt_buy, ask, sl_buy, tp_buy, Label+" @"+IntegerToString(i), 0);
   		   if (j > 0) ModifyStop(j, sl_buy, tp_buy);
   		}
   		if (BaseSell < 0 && sell_loss < Orders && P[sell_loss]+spread <= MathAbs(BaseSell)) {
   		   i = sell_loss + 1;
            lt_sell = NormalizeDouble(MathRound(lt_sell*MathPow(kLot, i)*100)/100, 2);
            if (lt_sell > LotsMax) lt_sell = LotsMax;

      	   sl_sell = ask + SL;
      	   tp_sell = ask - TP;

   		   k = OpenOrder(OP_SELL, lt_sell, bid, sl_sell, tp_sell, Label+" @"+IntegerToString(i), 0);
   		   if (k > 0) ModifyStop(k, sl_sell, tp_sell);
   		}
   	}

   	//Смещение стопов
      if (j == 0 && order_buy > 0)
         if (ask >= tp_buy-TPStep || bid <= sl_buy+SLStep) ModifyStop(0, bid-SL, bid+TP);

      if (k == 0 && order_sell > 0)
         if (bid <= tp_sell+TPStep || ask >= sl_sell-SLStep) ModifyStop(0, ask+SL, ask-TP);
	}

	//Вывод информации
	//--------------------------------------------
	if (!IsTesting() || IsVisualMode()) Info(GetLastError());
//---
}
//+------------------------------------------------------------------+
//| Сигнал RSI                                                       |
//+------------------------------------------------------------------+
int GetSignalRSI(int timeframe, int period, int price, int level, int shift) {
//---
	double rsi_0 = iRSI(NULL, timeframe, period, price, shift);
	double rsi_1 = iRSI(NULL, timeframe, period, price, shift+1);

   //пересечение уровня
	if (rsi_0 < level && rsi_1 > level) return(-1);
	level = 100 - level;
	if (rsi_0 > level && rsi_1 < level) return(1);
//---
   return(0);
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
			case OP_SELLLIMIT: ticket = OrderSend(Symbol(), type, lots, price, Slippage, sl, tp, label, Magic, xp, clrTomato);    break;;
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
//| Смещение стопов                                                  |
//+------------------------------------------------------------------+
void ModifyStop(int ticket, double sl, double tp) {
//---
	for (int i=0; i<OrdersTotal(); i++) {
		if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderMagicNumber() == Magic && OrderSymbol() == Symbol()) {
		   if (ticket > 0 && OrderTicket() == ticket) continue;
			if (OrderType() == OP_BUY || OrderType() == OP_SELL) {
			   if (sl == 0) sl = OrderStopLoss();
			   if (tp == 0) tp = OrderTakeProfit();
			   bool check = OrderModify(OrderTicket(), OrderOpenPrice(), sl, tp, 0, clrGreen);
			}
		}
   }
//---
	return;
}
//+------------------------------------------------------------------+
//| Размер лота                                                      |
//+------------------------------------------------------------------+
double GetSizeLot() {
//---
   double lots = LotsMin;
   double lotsmax = NormalizeDouble(MathRound(LotsMax/MathPow(kLot, Orders)*100)/100, 2);

   if (LotsDepoOne > 0 && AccountBalance() >= LotsDepoOne) lots = NormalizeDouble(AccountBalance()/LotsDepoOne*LotsMin, 2);
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
   int i, j, k;
   double depohour, lots;
   double balance = GetHistoryBalance();

	//Название файла
	string filename = "Grolex_" + Symbol() + "_M" + (string)TimeFrame + "_#" + (string)Magic + ".txt";

	//Запись в файл
	int handle = FileOpen(filename, FILE_CSV|FILE_WRITE, "\t");

   FileWrite(handle, "TimeFrame", TimeFrame);
   FileWrite(handle, "Profit  ", Profit);
   FileWrite(handle, "Loss  ", Loss);
   FileWrite(handle, "TakeProfit", TakeProfit);
   FileWrite(handle, "StopLoss", StopLoss);
   FileWrite(handle, "RSIPeriod", RSIPeriod);
   FileWrite(handle, "RSILevel", RSILevel);
   FileWrite(handle, "RSIPrice", RSIPrice);
   FileWrite(handle, "Step    ", Step);
   FileWrite(handle, "kStep   ", kStep);
   FileWrite(handle, "kLot    ", kLot);
   FileWrite(handle, "Orders  ", Orders);
   FileWrite(handle, "Shift   ", Shift);
   FileWrite(handle, "");
   FileWrite(handle, "Час", "|", "Сумма", "|", "Пн", "Вт", "Ср", "Чт", "Пт");
   FileWrite(handle, " ", "|", " ", "|");

   for (i=0; i<24; i++) {
      depohour = 0.0;
   	for (j=1; j<6; j++) {
   	   depohour += D[i,j];
   	   D[j-1,0] += D[i,j];
   	}
   	FileWrite(handle, i, "|", DoubleToString(depohour, 2), "|", DoubleToString(D[i,1], 2), DoubleToString(D[i,2], 2), DoubleToString(D[i,3], 2), DoubleToString(D[i,4], 2), DoubleToString(D[i,5], 2));
   }
   FileWrite(handle, " ", "|", " ", "|");
   FileWrite(handle, "Баланс:", " ", DoubleToString(balance, 2), "|", DoubleToString(D[0,0], 2), DoubleToString(D[1,0], 2), DoubleToString(D[2,0], 2), DoubleToString(D[3,0], 2), DoubleToString(D[4,0], 2));
   FileWrite(handle, "");
   FileWrite(handle, "Максимальное кол-во ордеров в веере", MaxOrder);

   if (Step > 0) {
      FileWrite(handle, "");
      FileWrite(handle, "Ордер", "|", "Высота", "|", "Лоты", "|", "Просадка");
      FileWrite(handle, " ", "|", " ", "|", " ", "|");

      for (k=1; k<=20; k++) {
         balance = 0.0;
         for (j=0; j<=k; j++) {
            depohour = 0.0;
            for (i=j; i<=k; i++) depohour += MathPow(kStep, i);
            lots = NormalizeDouble(MathRound(Lots*MathPow(kLot, j)*100)/100, 2);
            if (lots > LotsMax) lots = LotsMax;
            balance += depohour*lots*Step;
         }
         depohour = 0.0;
         for (j=0; j<k; j++) depohour += MathPow(kStep, j);
         lots = NormalizeDouble(MathRound(Lots*MathPow(kLot, k)*100)/100, 2);
         if (lots > LotsMax) lots = LotsMax;
         FileWrite(handle, k, "|", DoubleToString(depohour*Step, 0), "|", lots, "|", DoubleToString(balance, 2));
         if (lots == LotsMax) break;
      }
   }
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
			  "\nGrolex [M",TimeFrame,"] #",Magic,"\n",
			  "-------------------------------------------------------------",
		     "\nProfit: ",DoubleToString(Profit*Lots/LotsMin, 2)," (",DoubleToString(ProfitBuy+ProfitSell, 2),")",
		     "\nRSIPeriod: ",(string)RSIPeriod,
		     "\nStep: ",(string)Step,
		     "\nkStep: ",(string)kStep,
		     "\nkLot: ",(string)kLot,
		     "\nLots: ",DoubleToString(Lots, 2),
			  "\n----------------------",
			  "\nИстория баланса с ",TimeToString(StartTimeBalance, TIME_DATE)," по текущий момент: ",DoubleToString(Balance, 2),
			  "\n№",error," ",ErrorDescription(error));

	if (error > 0) Print("№",error," ",ErrorDescription(error));
//---
	return;
}
//+------------------------------------------------------------------+
//| end of expert                                                    |
//+------------------------------------------------------------------+