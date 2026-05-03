`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// register_b.v
//
// Physical-style SAP-1 B register subassembly:
//   - two 74LS173-style 4-bit register chips
//   - one 74LS245-style 8-bit output buffer
//
// Control behavior:
//   BI=0 is the normal hold state; Register B keeps its value.
//   BI=1 loads Register B from the shared bus on a sap_clk_en pulse.
//   BO=0 is the normal idle state; Register B does not drive the bus.
//   BO=1 requests that Register B drive the shared bus through bus.v.
// Register B's value is also made available for the adder/subtractor.
// -----------------------------------------------------------------------------

module register_b (
    input  wire       clk,
    input  wire       reset,
    input  wire       sap_clk_en,

    input  wire       BI,
    input  wire       BO,
    input  wire [7:0] bus_value,

    output wire [7:0] b_value,
    output wire [7:0] b_out,
    output wire       b_oe
);

    wire [3:0] b_low;
    wire [3:0] b_high;

    chip_74ls173 u_b_low (
        .clk(clk),
        .reset(reset),
        .clock_enable(sap_clk_en),
        .load(BI),
        .data_in(bus_value[3:0]),
        .q(b_low)
    );

    chip_74ls173 u_b_high (
        .clk(clk),
        .reset(reset),
        .clock_enable(sap_clk_en),
        .load(BI),
        .data_in(bus_value[7:4]),
        .q(b_high)
    );

    assign b_value = {b_high, b_low};

    chip_74ls245 u_b_output_buffer (
        .data_in(b_value),
        .output_enable(BO),
        .data_out(b_out),
        .output_enable_intent(b_oe)
    );

endmodule
