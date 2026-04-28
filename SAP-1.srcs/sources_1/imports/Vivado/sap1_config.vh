`ifndef SAP1_CONFIG_VH
`define SAP1_CONFIG_VH

`define AUTO_PERIOD_CLKS 100_000_000
`define DEBOUNCE_CLKS      1_000_000
`define LED_HOLD_CLKS     10_000_000

// 8-bit PWM LED brightness.
// 8'd255 = ~100%
// 8'd128 = ~50%
// 8'd64  = ~25%
// 8'd0   = off
`define LED_PWM_DUTY1     8'd16
`define LED_PWM_DUTY2     8'd2

`endif
