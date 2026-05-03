`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// pc.v
//
// Physical-style SAP-1 program counter subassembly:
//   - one 74LS161-style 4-bit counter
//   - one 74LS245-style 8-bit output buffer
//
// CE increments the program counter on a sap_clk_en pulse.
// CO requests that the program counter drive the low nibble onto the shared bus.
// J loads the program counter from the low bus nibble on a sap_clk_en pulse.
// -----------------------------------------------------------------------------

module pc (
    input  wire       clk,
    input  wire       reset,
    input  wire       sap_clk_en,

    input  wire       CE,
    input  wire       CO,
    input  wire       J,
    input  wire [7:0] bus_value,

    output wire [3:0] pc_value,
    output wire [7:0] pc_out,
    output wire       pc_oe
);

    wire [7:0] pc_bus_value;

    chip_74ls161 u_pc_counter (
        .clk(clk),
        .reset(reset),
        .clock_enable(sap_clk_en),
        .count_enable(CE),
        .load(J),
        .data_in(bus_value[3:0]),
        .q(pc_value)
    );

    assign pc_bus_value = {4'b0000, pc_value};

    pc_chip_74ls245 u_pc_output_buffer (
        .data_in(pc_bus_value),
        .output_enable(CO),
        .data_out(pc_out),
        .output_enable_intent(pc_oe)
    );

endmodule


module chip_74ls161 (
    input  wire       clk,
    input  wire       reset,
    input  wire       clock_enable,
    input  wire       count_enable,
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
            end else if (count_enable) begin
                q <= q + 1'b1;
            end
        end
    end

endmodule


module pc_chip_74ls245 (
    input  wire [7:0] data_in,
    input  wire       output_enable,

    output wire [7:0] data_out,
    output wire       output_enable_intent
);

    assign data_out = data_in;
    assign output_enable_intent = output_enable;

endmodule
