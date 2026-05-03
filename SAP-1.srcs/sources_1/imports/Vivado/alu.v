`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// alu.v
//
// Physical-style SAP-1 adder/subtractor subassembly:
//   - two 74LS86-style quad XOR chips
//   - two 74LS283-style 4-bit adders
//   - one 74LS245-style 8-bit output buffer
//
// Control behavior:
//   SU=0 selects add; SU=1 selects subtract by XOR-adjusting Register B and
//        feeding the low adder carry-in.
//   EO=0 is the normal idle state; the ALU does not drive the bus.
//   EO=1 requests that the ALU drive alu_result onto the shared bus through
//        bus.v.
// -----------------------------------------------------------------------------

module alu (
    input  wire [7:0] a_value,
    input  wire [7:0] b_value,
    input  wire       EO,
    input  wire       SU,

    output wire [7:0] alu_result,
    output wire [7:0] alu_out,
    output wire       alu_oe,
    output wire       carry_out
);

    wire [3:0] b_low_adjusted;
    wire [3:0] b_high_adjusted;
    wire [3:0] low_sum;
    wire [3:0] high_sum;
    wire       low_carry_out;

    chip_74ls86 u_b_low_xor (
        .a(b_value[3:0]),
        .b({4{SU}}),
        .y(b_low_adjusted)
    );

    chip_74ls86 u_b_high_xor (
        .a(b_value[7:4]),
        .b({4{SU}}),
        .y(b_high_adjusted)
    );

    chip_74ls283 u_low_adder (
        .a(a_value[3:0]),
        .b(b_low_adjusted),
        .carry_in(SU),
        .sum(low_sum),
        .carry_out(low_carry_out)
    );

    chip_74ls283 u_high_adder (
        .a(a_value[7:4]),
        .b(b_high_adjusted),
        .carry_in(low_carry_out),
        .sum(high_sum),
        .carry_out(carry_out)
    );

    assign alu_result = {high_sum, low_sum};

    chip_74ls245 u_alu_output_buffer (
        .data_in(alu_result),
        .output_enable(EO),
        .data_out(alu_out),
        .output_enable_intent(alu_oe)
    );

endmodule


module chip_74ls86 (
    input  wire [3:0] a,
    input  wire [3:0] b,

    output wire [3:0] y
);

    assign y = a ^ b;

endmodule


module chip_74ls283 (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire       carry_in,

    output wire [3:0] sum,
    output wire       carry_out
);

    assign {carry_out, sum} = a + b + carry_in;

endmodule
