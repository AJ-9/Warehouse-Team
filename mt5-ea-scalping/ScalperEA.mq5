#property copyright "ScalperEA"
#property version   "1.0"
#property strict

#include <Trade/Trade.mqh>

//============================ Inputs ============================//
input string   Inp__General_____          = "--- General ---";              // --- Section ---
input bool     InpAllowLong               = true;                           // Allow BUY
input bool     InpAllowShort              = true;                           // Allow SELL
input double   InpLots                    = 0.10;                           // Fixed lot (ignored if UseRiskPercent)
input bool     InpUseRiskPercent          = false;                          // Use risk % per trade
input double   InpRiskPercent             = 1.0;                            // Risk percent of balance
input int      InpMaxSpreadPoints         = 25;                             // Max spread (points)
input int      InpMaxSlippagePoints       = 10;                             // Max deviation (points)
input long     InpMagicNumber             = 567890;                         // Magic number

input string   Inp__Signals_____          = "--- Signals ---";              // --- Section ---
input int      InpFastEMA                 = 5;                              // Fast EMA period
input int      InpSlowEMA                 = 20;                             // Slow EMA period
input bool     InpUseADX                  = true;                           // Filter: ADX
input int      InpADXPeriod               = 14;                             // ADX period
input double   InpMinADX                  = 20.0;                           // Min ADX to trade
input bool     InpUseStochastic           = true;                           // Filter: Stochastic
input int      InpStoK                    = 5;                              // Stochastic K period
input int      InpStoD                    = 3;                              // Stochastic D period
input int      InpStoSlowing              = 3;                              // Stochastic slowing
input bool     InpUseCCI                  = true;                           // Filter: CCI
input int      InpCCIPeriod               = 14;                             // CCI period
input int      InpCCIThreshold            = 0;                              // CCI threshold (buy>thr, sell<thr)
input bool     InpUseSAR                  = true;                           // Filter: Parabolic SAR
input double   InpSARStep                 = 0.02;                           // SAR step
input double   InpSARMax                  = 0.2;                            // SAR max

input string   Inp__Risk_____             = "--- Risk/Exits ---";           // --- Section ---
input int      InpStopLossPoints          = 50;                             // Stop Loss (points)
input int      InpTakeProfitPoints        = 80;                             // Take Profit (points)
input bool     InpUseTrailing             = true;                           // Use trailing stop
input int      InpTrailStartPoints        = 40;                             // Trailing starts at (points in profit)
input int      InpTrailStepPoints         = 10;                             // Trailing step (points)
input bool     InpUseBreakEven            = false;                          // Move SL to breakeven
input int      InpBreakEvenPoints         = 30;                             // Breakeven trigger (points)
input bool     InpUseSwingSL              = false;                          // Use SL by swing high/low
input int      InpSwingLookbackBars       = 10;                             // Bars to look back for swing
input int      InpSwingBufferPoints       = 5;                              // Extra buffer (points)

input string   Inp__Session_____          = "--- Session ---";              // --- Section ---
input bool     InpUseSessionFilter        = true;                           // Use trading hours filter
input int      InpSessionStartHour        = 7;                              // Start hour (broker time)
input int      InpSessionEndHour          = 22;                             // End hour (broker time, inclusive start, exclusive end)

input string   Inp__Limits_____           = "--- Limits ---";               // --- Section ---
input bool     InpUseDailyLimits          = false;                          // Enforce daily limits
input int      InpMaxTradesPerDay         = 10;                             // Max entries per day
input double   InpDailyLossLimit          = 100.0;                          // Max daily loss (account currency)

//============================ Globals ============================//
CTrade trade;

int  hMAFast = INVALID_HANDLE;
int  hMASlow = INVALID_HANDLE;
int  hADX    = INVALID_HANDLE;
int  hStoch  = INVALID_HANDLE;
int  hCCI    = INVALID_HANDLE;
int  hSAR    = INVALID_HANDLE;

//============================ Helpers ============================//
double PointValue()
{
    double tick_value = 0.0, tick_size = 0.0;
    if(!SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE, tick_value)) return 0.0;
    if(!SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE,  tick_size))  return 0.0;
    if(tick_size <= 0.0) return 0.0;
    return tick_value * (_Point / tick_size); // money per point for 1.0 lot
}

double NormalizeLot(double lot)
{
    double min_lot=0.0, max_lot=0.0, step=0.0;
    SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN,  min_lot);
    SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX,  max_lot);
    SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP, step);
    if(step <= 0.0) step = 0.01;
    lot = MathMax(min_lot, MathMin(max_lot, lot));
    return MathFloor(lot/step + 1e-8) * step;
}

bool InSession()
{
    if(!InpUseSessionFilter) return true;
    MqlDateTime t; TimeToStruct(TimeCurrent(), t);
    int hour = t.hour;
    if(InpSessionStartHour == InpSessionEndHour) return true; // no restriction
    if(InpSessionStartHour < InpSessionEndHour)
        return (hour >= InpSessionStartHour && hour < InpSessionEndHour);
    // overnight window (e.g., 22..6)
    return (hour >= InpSessionStartHour || hour < InpSessionEndHour);
}

int CurrentSpreadPoints()
{
    double bid = 0, ask = 0;
    SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
    SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
    return (int)MathRound((ask - bid) / _Point);
}

datetime StartOfToday()
{
    MqlDateTime t; TimeToStruct(TimeCurrent(), t);
    t.hour = 0; t.min = 0; t.sec = 0;
    return StructToTime(t);
}

bool GetTodayStats(int &tradesIn, double &realizedProfit)
{
    tradesIn = 0; realizedProfit = 0.0;
    datetime from = StartOfToday();
    datetime to = TimeCurrent();
    if(!HistorySelect(from, to)) return false;
    int total = HistoryDealsTotal();
    for(int i = 0; i < total; i++)
    {
        ulong   ticket = HistoryDealGetTicket(i);
        string  sym    = HistoryDealGetString(ticket, DEAL_SYMBOL);
        long    magic  = (long)HistoryDealGetInteger(ticket, DEAL_MAGIC);
        int     entry  = (int)HistoryDealGetInteger(ticket, DEAL_ENTRY);
        double  profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        if(sym != _Symbol || magic != InpMagicNumber) continue;
        if(entry == DEAL_ENTRY_IN) tradesIn++;
        if(entry == DEAL_ENTRY_OUT) realizedProfit += profit;
    }
    return true;
}

bool CalcSwingSL(bool isBuy, double &slOut)
{
    if(InpSwingLookbackBars <= 0) return false;
    if(isBuy)
    {
        double lows[];
        if(CopyLow(_Symbol, _Period, 1, InpSwingLookbackBars, lows) != InpSwingLookbackBars) return false;
        double minLow = lows[0];
        for(int i = 1; i < ArraySize(lows); i++) if(lows[i] < minLow) minLow = lows[i];
        slOut = minLow - InpSwingBufferPoints * _Point;
        return true;
    }
    else
    {
        double highs[];
        if(CopyHigh(_Symbol, _Period, 1, InpSwingLookbackBars, highs) != InpSwingLookbackBars) return false;
        double maxHigh = highs[0];
        for(int i = 1; i < ArraySize(highs); i++) if(highs[i] > maxHigh) maxHigh = highs[i];
        slOut = maxHigh + InpSwingBufferPoints * _Point;
        return true;
    }
}

bool GetIndicatorValues(
    double &emaFastCurr, double &emaFastPrev,
    double &emaSlowCurr, double &emaSlowPrev,
    double &adxMain, double &diPlus, double &diMinus,
    double &stochK, double &stochD,
    double &cci, double &sar)
{
    double buf[3];

    double emaFast[2];
    if(CopyBuffer(hMAFast, 0, 0, 2, emaFast) != 2) return false;
    emaFastCurr = emaFast[0];
    emaFastPrev = emaFast[1];

    double emaSlow[2];
    if(CopyBuffer(hMASlow, 0, 0, 2, emaSlow) != 2) return false;
    emaSlowCurr = emaSlow[0];
    emaSlowPrev = emaSlow[1];

    if(InpUseADX)
    {
        if(CopyBuffer(hADX, 0, 0, 1, buf) != 1) return false; adxMain = buf[0];
        if(CopyBuffer(hADX, 1, 0, 1, buf) != 1) return false; diPlus  = buf[0];
        if(CopyBuffer(hADX, 2, 0, 1, buf) != 1) return false; diMinus = buf[0];
    }

    if(InpUseStochastic)
    {
        if(CopyBuffer(hStoch, 0, 0, 1, buf) != 1) return false; stochK = buf[0];
        if(CopyBuffer(hStoch, 1, 0, 1, buf) != 1) return false; stochD = buf[0];
    }

    if(InpUseCCI)
    {
        if(CopyBuffer(hCCI, 0, 0, 1, buf) != 1) return false; cci = buf[0];
    }

    if(InpUseSAR)
    {
        if(CopyBuffer(hSAR, 0, 0, 1, buf) != 1) return false; sar = buf[0];
    }

    return true;
}

bool BuySignal()
{
    double emaFastCurr, emaFastPrev, emaSlowCurr, emaSlowPrev;
    double adxMain=0, diPlus=0, diMinus=0, stochK=0, stochD=0, cci=0, sar=0;
    if(!GetIndicatorValues(emaFastCurr, emaFastPrev, emaSlowCurr, emaSlowPrev,
                           adxMain, diPlus, diMinus, stochK, stochD, cci, sar)) return false;

    bool crossUp = (emaFastPrev < emaSlowPrev) && (emaFastCurr > emaSlowCurr);
    if(!crossUp) return false;

    if(InpUseADX && !(adxMain >= InpMinADX && diPlus >= diMinus)) return false;
    if(InpUseStochastic && !(stochK >= stochD)) return false;
    if(InpUseCCI && !(cci >= InpCCIThreshold)) return false;
    if(InpUseSAR)
    {
        double bid=0; SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
        if(!(sar <= bid)) return false;
    }
    return true;
}

bool SellSignal()
{
    double emaFastCurr, emaFastPrev, emaSlowCurr, emaSlowPrev;
    double adxMain=0, diPlus=0, diMinus=0, stochK=0, stochD=0, cci=0, sar=0;
    if(!GetIndicatorValues(emaFastCurr, emaFastPrev, emaSlowCurr, emaSlowPrev,
                           adxMain, diPlus, diMinus, stochK, stochD, cci, sar)) return false;

    bool crossDown = (emaFastPrev > emaSlowPrev) && (emaFastCurr < emaSlowCurr);
    if(!crossDown) return false;

    if(InpUseADX && !(adxMain >= InpMinADX && diMinus >= diPlus)) return false;
    if(InpUseStochastic && !(stochK <= stochD)) return false;
    if(InpUseCCI && !(cci <= -InpCCIThreshold)) return false;
    if(InpUseSAR)
    {
        double ask=0; SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
        if(!(sar >= ask)) return false;
    }
    return true;
}

bool HasOpenPosition(int &posType)
{
    if(PositionSelect(_Symbol))
    {
        posType = (int)PositionGetInteger(POSITION_TYPE);
        return true;
    }
    return false;
}

double CalcLotsByRisk(int sl_points)
{
    if(!InpUseRiskPercent || sl_points <= 0) return NormalizeLot(InpLots);
    double balance=0.0; AccountInfoDouble(ACCOUNT_BALANCE, balance);
    double riskMoney = balance * (InpRiskPercent/100.0);
    double valPerPointPerLot = PointValue();
    if(valPerPointPerLot <= 0.0) return NormalizeLot(InpLots);
    double lot = riskMoney / (sl_points * valPerPointPerLot);
    return NormalizeLot(lot);
}

void ApplyTrailing()
{
    if(!InpUseTrailing) return;
    if(!PositionSelect(_Symbol)) return;

    long   type    = PositionGetInteger(POSITION_TYPE);
    double price   = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl      = PositionGetDouble(POSITION_SL);
    double open    = PositionGetDouble(POSITION_PRICE_OPEN);

    int profit_points = (int)MathRound((type == POSITION_TYPE_BUY ? (price - open) : (open - price)) / _Point);
    if(profit_points < InpTrailStartPoints && !(InpUseBreakEven && profit_points >= InpBreakEvenPoints)) return;

    double new_sl;
    if(InpUseBreakEven && profit_points >= InpBreakEvenPoints)
    {
        // Move to BE + small buffer of TrailStep
        if(type == POSITION_TYPE_BUY)
            new_sl = open + InpTrailStepPoints * _Point;
        else
            new_sl = open - InpTrailStepPoints * _Point;
    }
    else
    {
        if(type == POSITION_TYPE_BUY)
            new_sl = price - InpTrailStepPoints * _Point;
        else
            new_sl = price + InpTrailStepPoints * _Point;
    }

    // Ensure SL only tightens in the direction of profit
    if(type == POSITION_TYPE_BUY)
    {
        if(sl == 0.0 || new_sl > sl)
        {
            bool ok = trade.PositionModify(_Symbol, new_sl, PositionGetDouble(POSITION_TP));
            if(ok) Print("Trailing updated (BUY) SL=", DoubleToString(new_sl, _Digits));
        }
    }
    else
    {
        if(sl == 0.0 || new_sl < sl)
        {
            bool ok = trade.PositionModify(_Symbol, new_sl, PositionGetDouble(POSITION_TP));
            if(ok) Print("Trailing updated (SELL) SL=", DoubleToString(new_sl, _Digits));
        }
    }
}

void CloseOnOppositeSignal()
{
    if(!PositionSelect(_Symbol)) return;
    int type = (int)PositionGetInteger(POSITION_TYPE);
    if(type == POSITION_TYPE_BUY && SellSignal())
    {
        bool ok = trade.PositionClose(_Symbol);
        if(ok) Print("Closed BUY on opposite signal: ", _Symbol);
        else   Print("Close BUY failed retcode=", trade.ResultRetcode());
    }
    else if(type == POSITION_TYPE_SELL && BuySignal())
    {
        bool ok = trade.PositionClose(_Symbol);
        if(ok) Print("Closed SELL on opposite signal: ", _Symbol);
        else   Print("Close SELL failed retcode=", trade.ResultRetcode());
    }
}

//============================ EA lifecycle ============================//
int OnInit()
{
    trade.SetDeviationInPoints(InpMaxSlippagePoints);
    trade.SetExpertMagicNumber((ulong)InpMagicNumber);

    hMAFast = iMA(_Symbol, _Period, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
    hMASlow = iMA(_Symbol, _Period, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
    if(hMAFast == INVALID_HANDLE || hMASlow == INVALID_HANDLE) return INIT_FAILED;

    if(InpUseADX)
    {
        hADX = iADX(_Symbol, _Period, InpADXPeriod);
        if(hADX == INVALID_HANDLE) return INIT_FAILED;
    }
    if(InpUseStochastic)
    {
        hStoch = iStochastic(_Symbol, _Period, InpStoK, InpStoD, InpStoSlowing, MODE_SMA, STO_LOWHIGH);
        if(hStoch == INVALID_HANDLE) return INIT_FAILED;
    }
    if(InpUseCCI)
    {
        hCCI = iCCI(_Symbol, _Period, InpCCIPeriod, PRICE_TYPICAL);
        if(hCCI == INVALID_HANDLE) return INIT_FAILED;
    }
    if(InpUseSAR)
    {
        hSAR = iSAR(_Symbol, _Period, InpSARStep, InpSARMax);
        if(hSAR == INVALID_HANDLE) return INIT_FAILED;
    }
    Print("ScalperEA initialized on ", _Symbol, " TF=", _Period);
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    if(hMAFast != INVALID_HANDLE) IndicatorRelease(hMAFast);
    if(hMASlow != INVALID_HANDLE) IndicatorRelease(hMASlow);
    if(hADX    != INVALID_HANDLE) IndicatorRelease(hADX);
    if(hStoch  != INVALID_HANDLE) IndicatorRelease(hStoch);
    if(hCCI    != INVALID_HANDLE) IndicatorRelease(hCCI);
    if(hSAR    != INVALID_HANDLE) IndicatorRelease(hSAR);
}

void OnTick()
{
    if(!InSession()) return;
    if(CurrentSpreadPoints() > InpMaxSpreadPoints) return;

    if(InpUseDailyLimits)
    {
        int tradesIn = 0; double realized = 0.0;
        if(GetTodayStats(tradesIn, realized))
        {
            if(tradesIn >= InpMaxTradesPerDay) { Print("Daily limit: max trades reached"); return; }
            if(-realized >= InpDailyLossLimit) { Print("Daily limit: loss limit reached"); return; }
        }
    }

    int posType = -1;
    bool hasPos = HasOpenPosition(posType);

    // Manage existing position
    if(hasPos)
    {
        ApplyTrailing();
        CloseOnOppositeSignal();
        return;
    }

    // No position: look for entries
    if(InpAllowLong && BuySignal())
    {
        int tp_pts = InpTakeProfitPoints;
        double price_ask = 0.0; SymbolInfoDouble(_Symbol, SYMBOL_ASK, price_ask);
        int sl_pts = InpStopLossPoints;
        double sl = 0.0;
        if(InpUseSwingSL)
        {
            double swingSL;
            if(CalcSwingSL(true, swingSL))
            {
                sl = swingSL;
                sl_pts = (int)MathRound((price_ask - sl) / _Point);
                if(sl_pts <= 0) sl_pts = InpStopLossPoints;
            }
        }
        if(sl == 0.0)
            sl = (sl_pts > 0) ? price_ask - sl_pts * _Point : 0.0;
        double tp = (tp_pts > 0) ? price_ask + tp_pts * _Point : 0.0;
        double lot = CalcLotsByRisk(sl_pts);

        if(lot > 0.0)
        {
            if(trade.Buy(lot, _Symbol, 0.0, sl, tp))
                Print("BUY opened lot=", DoubleToString(lot, 2), " SL=", DoubleToString(sl, _Digits), " TP=", DoubleToString(tp, _Digits));
            else
                Print("BUY failed retcode=", trade.ResultRetcode());
        }
        return;
    }

    if(InpAllowShort && SellSignal())
    {
        int tp_pts = InpTakeProfitPoints;
        double price_bid = 0.0; SymbolInfoDouble(_Symbol, SYMBOL_BID, price_bid);
        int sl_pts = InpStopLossPoints;
        double sl = 0.0;
        if(InpUseSwingSL)
        {
            double swingSL;
            if(CalcSwingSL(false, swingSL))
            {
                sl = swingSL;
                sl_pts = (int)MathRound((sl - price_bid) / _Point);
                if(sl_pts <= 0) sl_pts = InpStopLossPoints;
            }
        }
        if(sl == 0.0)
            sl = (sl_pts > 0) ? price_bid + sl_pts * _Point : 0.0;
        double tp = (tp_pts > 0) ? price_bid - tp_pts * _Point : 0.0;
        double lot = CalcLotsByRisk(sl_pts);

        if(lot > 0.0)
        {
            if(trade.Sell(lot, _Symbol, 0.0, sl, tp))
                Print("SELL opened lot=", DoubleToString(lot, 2), " SL=", DoubleToString(sl, _Digits), " TP=", DoubleToString(tp, _Digits));
            else
                Print("SELL failed retcode=", trade.ResultRetcode());
        }
        return;
    }
}