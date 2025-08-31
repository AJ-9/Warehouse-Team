# ScalperEA (MT5)

Expert Advisor for MT5 implementing a configurable scalping strategy based on EMA(5/20) cross with optional filters (ADX, Stochastic, CCI, Parabolic SAR), spread/slippage control, SL/TP, trailing stop and breakeven, trading session filter, MagicNumber, daily limits, and optional swing-based SL.

## Features
- Entries on EMA(5/20) cross
- Filters: ADX (min strength, +DI/-DI), Stochastic (K vs D), CCI threshold, Parabolic SAR side
- Risk: fixed lot or % balance (auto lot by SL distance)
- Exits: SL/TP, optional trailing stop and breakeven
- Trade management: one position per symbol, close on opposite signal
- Protections: max spread, max slippage, trading hours filter
- MagicNumber for deal attribution
- Daily limits: max trades/day and daily loss cap
- Optional SL by recent swing high/low with buffer

## Parameters (key)
- General: `AllowLong/AllowShort`, `Lots`, `UseRiskPercent`, `RiskPercent`, `MaxSpreadPoints`, `MaxSlippagePoints`, `MagicNumber`
- Signals: `FastEMA=5`, `SlowEMA=20`, `UseADX/MinADX`, `UseStochastic (K/D/Slowing)`, `UseCCI (Period/Threshold)`, `UseSAR (Step/Max)`
- Risk/Exits: `StopLossPoints`, `TakeProfitPoints`, `UseTrailing (TrailStart/TrailStep)`, `UseBreakEven (BreakEvenPoints)`, `UseSwingSL`, `SwingLookbackBars`, `SwingBufferPoints`
- Session: `UseSessionFilter`, `SessionStartHour`, `SessionEndHour`
- Limits: `UseDailyLimits`, `MaxTradesPerDay`, `DailyLossLimit`

All distances are in broker points (respect the symbol's `_Point`). On 5-digit quotes, 1 pip = 10 points.

## Installation
1. Copy `ScalperEA.mq5` to `MQL5/Experts/` in your MT5 data directory (or create `Experts/ScalperEA/`).
2. Open in MetaEditor, compile (F7). Attach to a chart (e.g., EURUSD M1–M15).
3. Configure inputs per your broker and preferences.

## Notes
- For risk-based sizing, set `UseRiskPercent=true` and ensure SL is defined (points or swing).
- Swing SL: EA computes last swing low/high over `SwingLookbackBars` and adds `SwingBufferPoints`.
- Daily limits: EA counts today's entries (by MagicNumber) and realized PnL; stops when limits are reached.

## Testing
- Strategy Tester: `Every tick based on real ticks`, enable visualization.
- Validate entries/exits, trailing behavior, daily limits, and swing SL.

## Disclaimer
This EA is provided for educational purposes. Live trading involves risk. Test thoroughly on a demo account before using on real funds.