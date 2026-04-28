`timescale 1ns / 1ps
`include "sap1_config.vh"
// -----------------------------------------------------------------------------
// sap1_clock.v
//
// FPGA-safe Ben Eater SAP-1 style clock controller.
//
// This module does NOT create a new FPGA clock.
// It creates a one-CLK100MHZ-cycle clock-enable pulse named sap_clk_en.
//
// Use like this in SAP-1 modules:
//
//   always @(posedge clk or posedge reset) begin
//       if (reset) begin
//           ...
//       end else if (sap_clk_en) begin
//           ...
//       end
//   end
//
// Controls:
//   mode_switch = 0 -> automatic slow clock
//   mode_switch = 1 -> manual step button
//   halt_switch = 1 -> force sap_clk_en off
// -----------------------------------------------------------------------------

module sap1_clock #(
    parameter AUTO_PERIOD_CLKS = `AUTO_PERIOD_CLKS,
    parameter DEBOUNCE_CLKS    = `DEBOUNCE_CLKS,
    parameter LED_HOLD_CLKS    = `LED_HOLD_CLKS
) (
    input  wire clk,
    input  wire reset,
    input  wire step_button,
    input  wire mode_switch,
    input  wire halt_switch,

    output wire sap_clk_en,

    output wire led_selected_clock,
    output wire led_auto_clock,
    output wire led_manual_clock,
    output wire led_mode,
    output wire led_halt
);
    wire auto_pulse;
    wire manual_pulse;

    sap1_clock_auto #(
        .PERIOD_CLKS(AUTO_PERIOD_CLKS)
    ) u_auto_clock (
        .clk(clk),
        .reset(reset),
        .pulse(auto_pulse)
    );

    sap1_clock_manual #(
        .DEBOUNCE_CLKS(DEBOUNCE_CLKS)
    ) u_manual_clock (
        .clk(clk),
        .reset(reset),
        .button_raw(step_button),
        .pulse(manual_pulse)
    );

    assign sap_clk_en =
        halt_switch ? 1'b0 :
        mode_switch ? manual_pulse :
                      auto_pulse;

    sap1_pulse_stretcher #(
        .HOLD_CLKS(LED_HOLD_CLKS)
    ) u_selected_clock_led (
        .clk(clk),
        .reset(reset),
        .pulse_in(sap_clk_en),
        .visible_out(led_selected_clock)
    );

    sap1_pulse_stretcher #(
        .HOLD_CLKS(LED_HOLD_CLKS)
    ) u_auto_clock_led (
        .clk(clk),
        .reset(reset),
        .pulse_in(auto_pulse),
        .visible_out(led_auto_clock)
    );

    sap1_pulse_stretcher #(
        .HOLD_CLKS(LED_HOLD_CLKS)
    ) u_manual_clock_led (
        .clk(clk),
        .reset(reset),
        .pulse_in(manual_pulse),
        .visible_out(led_manual_clock)
    );

    assign led_mode = mode_switch;
    assign led_halt = halt_switch;

endmodule


module sap1_clock_auto #(
    parameter PERIOD_CLKS = 25_000_000
) (
    input  wire clk,
    input  wire reset,
    output reg  pulse
);
    reg [31:0] count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 32'd0;
            pulse <= 1'b0;
        end else begin
            pulse <= 1'b0;

            if (count == PERIOD_CLKS - 1) begin
                count <= 32'd0;
                pulse <= 1'b1;
            end else begin
                count <= count + 1'b1;
            end
        end
    end

endmodule


module sap1_clock_manual #(
    parameter DEBOUNCE_CLKS = 1_000_000
) (
    input  wire clk,
    input  wire reset,
    input  wire button_raw,
    output reg  pulse
);
    wire button_clean;
    reg  button_clean_d;

    sap1_button_debounce #(
        .DEBOUNCE_CLKS(DEBOUNCE_CLKS)
    ) u_button_debounce (
        .clk(clk),
        .reset(reset),
        .button_raw(button_raw),
        .button_clean(button_clean)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            button_clean_d <= 1'b0;
            pulse          <= 1'b0;
        end else begin
            button_clean_d <= button_clean;
            pulse          <= button_clean & ~button_clean_d;
        end
    end

endmodule


module sap1_button_debounce #(
    parameter DEBOUNCE_CLKS = 1_000_000
) (
    input  wire clk,
    input  wire reset,
    input  wire button_raw,
    output reg  button_clean
);
    reg        sync_0;
    reg        sync_1;
    reg [31:0] stable_count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sync_0       <= 1'b0;
            sync_1       <= 1'b0;
            stable_count <= 32'd0;
            button_clean <= 1'b0;
        end else begin
            sync_0 <= button_raw;
            sync_1 <= sync_0;

            if (sync_1 == button_clean) begin
                stable_count <= 32'd0;
            end else if (stable_count == DEBOUNCE_CLKS - 1) begin
                button_clean <= sync_1;
                stable_count <= 32'd0;
            end else begin
                stable_count <= stable_count + 1'b1;
            end
        end
    end

endmodule


module sap1_pulse_stretcher #(
    parameter HOLD_CLKS = 10_000_000
) (
    input  wire clk,
    input  wire reset,
    input  wire pulse_in,
    output wire visible_out
);
    reg [31:0] count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 32'd0;
        end else if (pulse_in) begin
            count <= HOLD_CLKS;
        end else if (count != 0) begin
            count <= count - 1'b1;
        end
    end

    assign visible_out = (count != 0);

endmodule
