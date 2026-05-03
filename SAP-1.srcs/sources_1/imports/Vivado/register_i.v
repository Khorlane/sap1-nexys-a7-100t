`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// register_i.v
//
// Physical-style SAP-1 instruction register subassembly:
//   - two 74LS173-style 4-bit register chips
//   - one 74LS245-style 8-bit output buffer
//
// Control behavior:
//   II=0 is the normal hold state; the instruction register keeps its value.
//   II=1 loads the full 8-bit instruction from the shared bus on a sap_clk_en
//        pulse.
//   IO=0 is the normal idle state; the instruction register does not drive the
//        bus.
//   IO=1 requests that the low-nibble operand drive the shared bus through
//        bus.v as {4'b0000, operand}.
//
// The high nibble is exposed as opcode for the future instruction decoder.
// The low nibble is exposed as operand and is the only nibble that can drive
// the bus.
// -----------------------------------------------------------------------------

module register_i (
    input  wire       clk,
    input  wire       reset,
    input  wire       sap_clk_en,

    input  wire       II,
    input  wire       IO,
    input  wire [7:0] bus_value,

    output wire [7:0] i_value,
    output wire [3:0] opcode,
    output wire [3:0] operand,
    output wire [7:0] i_out,
    output wire       i_oe
);

    wire [3:0] i_low;
    wire [3:0] i_high;
    wire [7:0] operand_bus_value;

    chip_74ls173 u_i_low (
        .clk(clk),
        .reset(reset),
        .clock_enable(sap_clk_en),
        .load(II),
        .data_in(bus_value[3:0]),
        .q(i_low)
    );

    chip_74ls173 u_i_high (
        .clk(clk),
        .reset(reset),
        .clock_enable(sap_clk_en),
        .load(II),
        .data_in(bus_value[7:4]),
        .q(i_high)
    );

    assign i_value = {i_high, i_low};
    assign opcode = i_value[7:4];
    assign operand = i_value[3:0];
    assign operand_bus_value = {4'b0000, operand};

    chip_74ls245 u_i_output_buffer (
        .data_in(operand_bus_value),
        .output_enable(IO),
        .data_out(i_out),
        .output_enable_intent(i_oe)
    );

endmodule
