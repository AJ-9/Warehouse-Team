# ScalperEA (MT5)

Expert Advisor for MT5 implementing a configurable scalping strategy based on EMA(5/20) cross with optional filters (ADX, Stochastic, CCI, Parabolic SAR), spread/slippage control, SL/TP, trailing stop and breakeven, and trading session filter.

## Features
- Entries on EMA(5/20) cross
- Filters: ADX (min strength, +DI/-DI), Stochastic (K vs D), CCI threshold, Parabolic SAR side
- Risk: fixed lot or % balance (auto lot by SL distance)
- Exits: SL/TP, optional trailing stop and breakeven
- Trade management: one position per symbol, close on opposite signal
- Protections: max spread, max slippage, trading hours filter

## Parameters (key)
- General: `AllowLong/AllowShort`, `Lots`, `UseRiskPercent`, `RiskPercent`, `MaxSpreadPoints`, `MaxSlippagePoints`
- Signals: `FastEMA=5`, `SlowEMA=20`, `UseADX/MinADX`, `UseStochastic (K/D/Slowing)`, `UseCCI (Period/Threshold)`, `UseSAR (Step/Max)`
- Risk/Exits: `StopLossPoints`, `TakeProfitPoints`, `UseTrailing (TrailStart/TrailStep)`, `UseBreakEven (BreakEvenPoints)`
- Session: `UseSessionFilter`, `SessionStartHour`, `SessionEndHour`

All distances are in broker points (respect the symbol's `_Point`).

## Installation
1. Copy `ScalperEA.mq5` to `MQL5/Experts/` in your MT5 data directory.
2. Open in MetaEditor, compile. Attach to a chart (e.g., EURUSD M1–M15).
3. Configure inputs per your broker and preferences.

## Notes
- Use realistic `StopLossPoints`/`TakeProfitPoints` for your symbol's point size and typical spread.
- For risk-based position sizing, set `UseRiskPercent=true` and define `StopLossPoints`.
- Trailing works only after price reaches `TrailStartPoints`; breakeven can be enabled separately.
- The EA avoids trading outside the configured session and when spread exceeds `MaxSpreadPoints`.

## Testing
- Strategy Tester: `Every tick based on real ticks`, enable visualization to validate entries/exits.
- Set commission/spread modeling to match your broker. Validate slippage and session settings.

## Disclaimer
This EA is provided for educational purposes. Live trading involves risk. Test thoroughly on a demo account before using on real funds.