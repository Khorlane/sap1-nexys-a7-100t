`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// mar.v
//
// Physical-style SAP-1 memory address register subassembly:
//   - one DPDT-style run/program switch
//   - one 4-channel DIP-switch-style manual address input
//   - one 74LS157-style quad 2-to-1 selector
//   - one 74LS173-style 4-bit register
//
// In run mode, the RAM address comes from the 74LS173 MAR register.
// In program mode, the RAM address comes from the manual DIP-switch input.
//
// MI loads the low bus nibble into the MAR register on a sap_clk_en pulse.
// The 74LS157 output becomes the RAM address input.
// -----------------------------------------------------------------------------

module mar (
    input  wire       clk,
    input  wire       reset,
    input  wire       sap_clk_en,

    input  wire       MI,
    input  wire       program_mode,
    input  wire [3:0] dip_address,
    input  wire [7:0] bus_value,

    output wire [3:0] mar_value,
    output wire [3:0] ram_addr,
    output wire       program_led,
    output wire       run_led
);

    wire [3:0] u1_dip_switch_value;
    wire [3:0] u2_mux_out;

    dpdt_run_program_switch u0_mode_switch (
        .program_mode(program_mode),
        .program_led(program_led),
        .run_led(run_led)
    );

    dip_switch_4channel u1_manual_address_switch (
        .switch_value(dip_address),
        .address_out(u1_dip_switch_value)
    );

    chip_74ls173 u3_mar_register (
        .clk(clk),
        .reset(reset),
        .clock_enable(sap_clk_en),
        .load(MI),
        .data_in(bus_value[3:0]),
        .q(mar_value)
    );

    chip_74ls157 u2_address_selector (
        .select(program_mode),
        .enable(1'b1),
        .a_in(u1_dip_switch_value),
        .b_in(mar_value),
        .y_out(u2_mux_out)
    );

    assign ram_addr = u2_mux_out;

endmodule


module dpdt_run_program_switch (
    input  wire program_mode,

    output wire program_led,
    output wire run_led
);

    // Ben's physical switch lights the red LED in program mode
    // and the green LED in run mode.
    assign program_led = program_mode;
    assign run_led = ~program_mode;

endmodule


module dip_switch_4channel (
    input  wire [3:0] switch_value,

    output wire [3:0] address_out
);

    // Represents the four manual address switches feeding the 74LS157 A inputs.
    assign address_out = switch_value;

endmodule


module chip_74ls157 (
    input  wire       select,
    input  wire       enable,
    input  wire [3:0] a_in,
    input  wire [3:0] b_in,

    output wire [3:0] y_out
);

    // 74LS157 pin 15 is active-low enable in hardware.
    // The top-level ties the physical enable low, represented here as enable=1.
    assign y_out = enable ? (select ? a_in : b_in) : 4'b0000;

endmodule
