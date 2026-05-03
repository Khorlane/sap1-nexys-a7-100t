`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// chips.v
//
// Shared physical-style chip helper models used by multiple SAP-1 components.
//
// Project convention:
//   Internal control signals are active-high unless the name ends in _n.
//   A load/output-enable input at 0 is normally idle or holding state.
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


module chip_74ls173 (
    input  wire       clk,
    input  wire       reset,
    input  wire       clock_enable,
    input  wire       load,
    input  wire [3:0] data_in,

    output reg  [3:0] q
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q <= 4'h0;
        end else if (clock_enable) begin
            if (load) begin
                q <= data_in;
            end
        end
    end

endmodule
