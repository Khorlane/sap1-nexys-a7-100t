`timescale 1ns / 1ps
`include "sap1_config.vh"

// -----------------------------------------------------------------------------
// sap1_top.v
//
// Top-level Nexys A7-100T SAP-1 shell.
//
// Current build stage:
//   - Instantiates the SAP-1 clock controller.
//   - Instantiates temporary manual bus/Register A load test harness.
//   - Exposes the clock state and manual bus controls on LEDs.
//   - Dims LED0-LED15 through global 8-bit PWM.
//   - Dims LED16_R/LED17_R separately because the RGB LEDs are much brighter.
//
// Board controls:
//   BTNU = reset
//   BTNC = manual step
//   BTNL = request one A-register load on the next SAP clock-enable pulse
//   BTNR = request one B-register load on the next SAP clock-enable pulse
//   SW0  = clock mode: 0 auto, 1 manual
//   SW1  = halt:       0 run,  1 halted
//   SW5  = ALU subtract control
//   SW6  = ALU output-enable
//   SW7  = manual bus output-enable
//   SW15-SW8 = manual bus value
//
// LEDs before PWM dimming:
//   LED16_R = selected SAP clock-enable pulse, stretched locally for visibility
//   LED17_R = astable/auto pulse, always independent of mode/halt
//   LED0    = clock mode
//   LED1    = halt
//   LED5    = ALU subtract control
//   LED6    = ALU output-enable
//   LED7    = manual bus output-enable
//   LED15-8 = manual bus value
//
// LED brightness:
//   LED0-LED15 are controlled by LED_PWM_DUTY1 in sap1_config.vh.
//   LED16_R/LED17_R use their own lower PWM duty LED_PWM_DUTY2 because the RGB LEDs are very bright.
// -----------------------------------------------------------------------------

module sap1_top (
    input  wire        CLK100MHZ,
    input  wire        BTNC,
    input  wire        BTNL,
    input  wire        BTNR,
    input  wire        BTNU,
    input  wire [15:0] SW,

    output wire [15:0] LED,
    output wire        LED16_R,
    output wire        LED17_R,

    output wire [7:0]  AN,
    output wire [6:0]  SEG,
    output wire        DP,

    output wire [3:0]  VGA_R,
    output wire [3:0]  VGA_G,
    output wire [3:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS
);
    wire reset;
    wire mode_switch_sync;
    wire halt_switch_sync;
    wire su_switch_sync;
    wire eo_switch_sync;
    wire sap_clk_en;
    wire load_a_button_pulse;
    wire load_b_button_pulse;

    wire [7:0] manual_bus_value;
    wire       manual_bus_oe;
    wire [7:0] sap_bus_value;
    wire       bus_conflict;

    wire       a_input_enable;
    wire       a_output_enable;
    wire [7:0] a_value;
    wire [7:0] a_out;
    wire       a_oe;

    wire       b_input_enable;
    wire [7:0] b_value;

    wire [7:0] alu_result;
    wire [7:0] alu_out;
    wire       alu_oe;
    wire       alu_carry_out;

    wire led_selected_clock;
    wire led_auto_clock;
    wire led_manual_clock;
    wire led_mode;
    wire led_halt;

    wire led_pwm_enable;
    wire led16_pwm_enable;

    wire raw_led16_r;
    wire raw_led17_r;
    wire [15:0] raw_led;

    reg [23:0] led16_hold;
    reg        ai_pending;
    reg        bi_pending;

    assign reset = BTNU;
    assign manual_bus_value = SW[15:8];
    assign manual_bus_oe    = SW[7];
    assign a_input_enable   = ai_pending;
    assign a_output_enable  = 1'b0;
    assign b_input_enable   = bi_pending;

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

    sap1_switch_sync u_su_switch_sync (
        .clk(CLK100MHZ),
        .reset(reset),
        .switch_raw(SW[5]),
        .switch_sync(su_switch_sync)
    );

    sap1_switch_sync u_eo_switch_sync (
        .clk(CLK100MHZ),
        .reset(reset),
        .switch_raw(SW[6]),
        .switch_sync(eo_switch_sync)
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

    sap1_clock_manual #(
        .DEBOUNCE_CLKS(`DEBOUNCE_CLKS)
    ) u_load_a_button (
        .clk(CLK100MHZ),
        .reset(reset),
        .button_raw(BTNL),
        .pulse(load_a_button_pulse)
    );

    sap1_clock_manual #(
        .DEBOUNCE_CLKS(`DEBOUNCE_CLKS)
    ) u_load_b_button (
        .clk(CLK100MHZ),
        .reset(reset),
        .button_raw(BTNR),
        .pulse(load_b_button_pulse)
    );

    always @(posedge CLK100MHZ or posedge reset) begin
        if (reset) begin
            ai_pending <= 1'b0;
        end else if (sap_clk_en && ai_pending) begin
            ai_pending <= 1'b0;
        end else if (load_a_button_pulse) begin
            ai_pending <= 1'b1;
        end
    end

    always @(posedge CLK100MHZ or posedge reset) begin
        if (reset) begin
            bi_pending <= 1'b0;
        end else if (sap_clk_en && bi_pending) begin
            bi_pending <= 1'b0;
        end else if (load_b_button_pulse) begin
            bi_pending <= 1'b1;
        end
    end

    register_a u_register_a (
        .clk(CLK100MHZ),
        .reset(reset),
        .sap_clk_en(sap_clk_en),
        .AI(a_input_enable),
        .AO(a_output_enable),
        .bus_value(sap_bus_value),
        .a_value(a_value),
        .a_out(a_out),
        .a_oe(a_oe)
    );

    register_b u_register_b (
        .clk(CLK100MHZ),
        .reset(reset),
        .sap_clk_en(sap_clk_en),
        .BI(b_input_enable),
        .bus_value(sap_bus_value),
        .b_value(b_value)
    );

    alu u_alu (
        .a_value(a_value),
        .b_value(b_value),
        .EO(eo_switch_sync),
        .SU(su_switch_sync),
        .alu_result(alu_result),
        .alu_out(alu_out),
        .alu_oe(alu_oe),
        .carry_out(alu_carry_out)
    );

    bus u_bus (
        .a_out(a_out),
        .a_oe(a_oe),
        .alu_out(alu_out),
        .alu_oe(alu_oe),
        .manual_bus_value(manual_bus_value),
        .manual_bus_oe(manual_bus_oe),
        .bus_value(sap_bus_value),
        .bus_conflict(bus_conflict)
    );

    sap1_vga_debug_display u_vga_debug_display (
        .clk(CLK100MHZ),
        .reset(reset),
        .bus_value(sap_bus_value),
        .a_value(a_value),
        .b_value(b_value),
        .alu_result(alu_result),
        .alu_su(su_switch_sync),
        .alu_eo(eo_switch_sync),
        .vga_r(VGA_R),
        .vga_g(VGA_G),
        .vga_b(VGA_B),
        .vga_hs(VGA_HS),
        .vga_vs(VGA_VS)
    );

    // Global PWM dimmer for LED0-LED15.
    sap1_led_pwm #(
        .PWM_DUTY(`LED_PWM_DUTY1)
    ) u_led_pwm (
        .clk(CLK100MHZ),
        .reset(reset),
        .pwm_enable(led_pwm_enable)
    );

    // Separate much lower PWM duty for LED16_R/LED17_R.
    // The red channels of the RGB LEDs are much brighter than LED0-LED15.
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
    assign raw_led17_r = led_auto_clock;

    assign raw_led[0]    = led_mode;
    assign raw_led[1]    = led_halt;
    assign raw_led[4:2]  = 3'b000;
    assign raw_led[5]    = su_switch_sync;
    assign raw_led[6]    = eo_switch_sync;
    assign raw_led[7]    = manual_bus_oe;
    assign raw_led[15:8] = manual_bus_value;

    assign LED16_R = raw_led16_r & led16_pwm_enable;
    assign LED17_R = raw_led17_r & led16_pwm_enable;
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
