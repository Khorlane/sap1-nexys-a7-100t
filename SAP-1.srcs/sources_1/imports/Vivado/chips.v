`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// chips.v
//
// Shared physical-style chip helper models used by multiple SAP-1 components.
// -----------------------------------------------------------------------------

module chip_74ls245 (
    input  wire [7:0] data_in,
    input  wire       output_enable,

    output wire [7:0] data_out,
    output wire       output_enable_intent
);

    assign data_out = data_in;
    assign output_enable_intent = output_enable;

endmodule
