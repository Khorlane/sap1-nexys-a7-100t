`timescale 1ns / 1ps
`include "sap1_config.vh"

// -----------------------------------------------------------------------------
// sap1_top.v
//
// Top-level Nexys A7-100T SAP-1 shell.
//
// Current build stage:
//   - Instantiates only the SAP-1 clock controller.
//   - Exposes the clock state on LEDs.
//   - Dims LED0-LED15 through global 8-bit PWM.
//   - Dims LED16_R separately because the RGB LED is much brighter.
//
// Board controls:
//   BTNU = reset
//   BTNC = manual step
//   SW0  = clock mode: 0 auto, 1 manual
//   SW1  = halt:       0 run,  1 halted
//
// LEDs before PWM dimming:
//   LED16_R = selected SAP clock-enable pulse, stretched locally for visibility
//   LED0    = automatic clock pulse, stretched by sap1_clock
//   LED1    = manual step pulse, stretched by sap1_clock
//   LED3    = clock mode
//   LED4    = halt
//
// LED brightness:
//   LED0-LED15 are controlled by LED_PWM_DUTY1 in sap1_config.vh.
//   LED16_R uses its own lower PWM duty LED_PWM_DUTY2 because the RGB LED is very bright.
// -----------------------------------------------------------------------------

module sap1_top (
    input  wire        CLK100MHZ,
    input  wire        BTNC,
    input  wire        BTNU,
    input  wire [15:0] SW,

    output wire [15:0] LED,
    output wire        LED16_R,

    output wire [7:0]  AN,
    output wire [6:0]  SEG,
    output wire        DP
);
    wire reset;
    wire mode_switch_sync;
    wire halt_switch_sync;
    wire sap_clk_en;

    wire led_selected_clock;
    wire led_auto_clock;
    wire led_manual_clock;
    wire led_mode;
    wire led_halt;

    wire led_pwm_enable;
    wire led16_pwm_enable;

    wire raw_led16_r;
    wire [15:0] raw_led;

    reg [23:0] led16_hold;

    assign reset = BTNU;

    sap1_switch_sync u_mode_switch_sync (
        .clk(CLK100MHZ),
        .reset(reset),
        .switch_raw(SW[0]),
        .switch_sync(mode_switch_sync)
    );

    sap1_switch_sync u_halt_switch_sync (
        .clk(CLK100MHZ),
        .reset(reset),
        .switch_raw(SW[1]),
        .switch_sync(halt_switch_sync)
    );

    sap1_clock #(
        .AUTO_PERIOD_CLKS(`AUTO_PERIOD_CLKS),
        .DEBOUNCE_CLKS(`DEBOUNCE_CLKS),
        .LED_HOLD_CLKS(`LED_HOLD_CLKS)
    ) u_sap1_clock (
        .clk(CLK100MHZ),
        .reset(reset),
        .step_button(BTNC),
        .mode_switch(mode_switch_sync),
        .halt_switch(halt_switch_sync),

        .sap_clk_en(sap_clk_en),

        .led_selected_clock(led_selected_clock),
        .led_auto_clock(led_auto_clock),
        .led_manual_clock(led_manual_clock),
        .led_mode(led_mode),
        .led_halt(led_halt)
    );

    // Global PWM dimmer for LED0-LED15.
    sap1_led_pwm #(
        .PWM_DUTY(`LED_PWM_DUTY1)
    ) u_led_pwm (
        .clk(CLK100MHZ),
        .reset(reset),
        .pwm_enable(led_pwm_enable)
    );

    // Separate much lower PWM duty for LED16_R.
    // LED16_R is the red channel of an RGB LED and is much brighter than LED0-LED15.
    sap1_led_pwm #(
        .PWM_DUTY(`LED_PWM_DUTY2)
    ) u_led16_pwm (
        .clk(CLK100MHZ),
        .reset(reset),
        .pwm_enable(led16_pwm_enable)
    );

    // Stretch the actual selected SAP clock-enable pulse so LED16_R stays on
    // long enough for PWM brightness control to be visible.
    always @(posedge CLK100MHZ or posedge reset) begin
        if (reset) begin
            led16_hold <= 24'd0;
        end else if (sap_clk_en) begin
            led16_hold <= `LED_HOLD_CLKS;
        end else if (led16_hold != 24'd0) begin
            led16_hold <= led16_hold - 1'b1;
        end
    end

    assign raw_led16_r = (led16_hold != 24'd0);

    assign raw_led[0]    = led_auto_clock;
    assign raw_led[1]    = led_manual_clock;
    assign raw_led[2]    = 1'b0;
    assign raw_led[3]    = led_mode;
    assign raw_led[4]    = led_halt;
    assign raw_led[15:5] = 11'b00000000000;

    assign LED16_R = raw_led16_r & led16_pwm_enable;
    assign LED     = raw_led & {16{led_pwm_enable}};

    // Seven-segment display intentionally blank for this stage.
    // Nexys A7 seven-segment anodes are active-low.
    assign AN  = 8'b11111111;
    assign SEG = 7'b1111111;
    assign DP  = 1'b1;

endmodule


module sap1_switch_sync (
    input  wire clk,
    input  wire reset,
    input  wire switch_raw,
    output wire switch_sync
);
    reg sync_0;
    reg sync_1;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sync_0 <= 1'b0;
            sync_1 <= 1'b0;
        end else begin
            sync_0 <= switch_raw;
            sync_1 <= sync_0;
        end
    end

    assign switch_sync = sync_1;

endmodule


module sap1_led_pwm #(
    parameter [7:0] PWM_DUTY = `LED_PWM_DUTY1
) (
    input  wire clk,
    input  wire reset,
    output wire pwm_enable
);
    reg [7:0] pwm_count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pwm_count <= 8'd0;
        end else begin
            pwm_count <= pwm_count + 1'b1;
        end
    end

    assign pwm_enable = (pwm_count < PWM_DUTY);

endmodule
