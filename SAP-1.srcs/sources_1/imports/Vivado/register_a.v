`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// register_a.v
//
// Physical-style SAP-1 A register subassembly:
//   - two 74LS173-style 4-bit register chips
//   - one 74LS245-style 8-bit output buffer
//
// AI loads Register A from the shared bus on a sap_clk_en pulse.
// AO requests that Register A drive the shared bus through bus.v.
// -----------------------------------------------------------------------------

module register_a (
    input  wire       clk,
    input  wire       reset,
    input  wire       sap_clk_en,

    input  wire       AI,
    input  wire       AO,
    input  wire [7:0] bus_value,

    output wire [7:0] a_value,
    output wire [7:0] a_out,
    output wire       a_oe
);

    wire [3:0] a_low;
    wire [3:0] a_high;

    chip_74ls173 u_a_low (
        .clk(clk),
        .reset(reset),
        .clock_enable(sap_clk_en),
        .load(AI),
        .data_in(bus_value[3:0]),
        .q(a_low)
    );

    chip_74ls173 u_a_high (
        .clk(clk),
        .reset(reset),
        .clock_enable(sap_clk_en),
        .load(AI),
        .data_in(bus_value[7:4]),
        .q(a_high)
    );

    assign a_value = {a_high, a_low};

    chip_74ls245 u_a_output_buffer (
        .data_in(a_value),
        .output_enable(AO),
        .data_out(a_out),
        .output_enable_intent(a_oe)
    );

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


module chip_74ls245 (
    input  wire [7:0] data_in,
    input  wire       output_enable,

    output wire [7:0] data_out,
    output wire       output_enable_intent
);

    assign data_out = data_in;
    assign output_enable_intent = output_enable;

endmodule
