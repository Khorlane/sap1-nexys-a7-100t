`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// register_b.v
//
// Physical-style SAP-1 B register subassembly:
//   - two 74LS173-style 4-bit register chips
//
// BI loads Register B from the shared bus on a sap_clk_en pulse.
// Register B does not drive the shared bus in the standard SAP-1 datapath;
// its value is made available for the adder/subtractor.
// -----------------------------------------------------------------------------

module register_b (
    input  wire       clk,
    input  wire       reset,
    input  wire       sap_clk_en,

    input  wire       BI,
    input  wire [7:0] bus_value,

    output wire [7:0] b_value
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

endmodule
