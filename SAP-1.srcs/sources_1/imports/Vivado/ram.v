`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// ram.v
//
// Physical-style SAP-1 RAM subassembly:
//   - two 74LS189-style 16x4 RAM chips
//   - two 74LS04-style inverter banks
//   - one 74LS245-style 8-bit output buffer
//
// U1 and U2 share the same 4 address lines.
// U1 stores the low nibble.
// U2 stores the high nibble.
//
// RI writes bus_value[7:0] into RAM on a sap_clk_en pulse.
// RO requests that the RAM output value drive the shared bus.
//
// The real 74LS189 has inverted outputs, so this model preserves that internal
// shape by producing inverted chip outputs and then correcting them through
// 74LS04-style inverter banks.
// -----------------------------------------------------------------------------

module ram (
    input  wire       clk,
    input  wire       reset,
    input  wire       sap_clk_en,

    input  wire       RI,
    input  wire       RO,
    input  wire [3:0] ram_addr,
    input  wire [7:0] bus_value,

    output wire [7:0] ram_value,
    output wire [7:0] ram_leds,
    output wire [7:0] ram_out,
    output wire       ram_oe
);

    wire [3:0] u1_raw_out;
    wire [3:0] u2_raw_out;

    wire [3:0] u3_inverted_out;
    wire [3:0] u4_inverted_out;

    chip_74ls189 u1_ram_low_nibble (
        .clk(clk),
        .reset(reset),
        .clock_enable(sap_clk_en),
        .write_enable(RI),
        .address(ram_addr),
        .data_in(bus_value[3:0]),
        .data_out_n(u1_raw_out)
    );

    chip_74ls189 u2_ram_high_nibble (
        .clk(clk),
        .reset(reset),
        .clock_enable(sap_clk_en),
        .write_enable(RI),
        .address(ram_addr),
        .data_in(bus_value[7:4]),
        .data_out_n(u2_raw_out)
    );

    chip_74ls04_4bit u3_low_nibble_inverters (
        .data_in(u1_raw_out),
        .data_out(u3_inverted_out)
    );

    chip_74ls04_4bit u4_high_nibble_inverters (
        .data_in(u2_raw_out),
        .data_out(u4_inverted_out)
    );

    assign ram_value = {u4_inverted_out, u3_inverted_out};

    // ram_led1-ram_led8 are the corrected RAM outputs after the 74LS04s.
    assign ram_leds = ram_value;

    ram_chip_74ls245 u5_output_buffer (
        .data_in(ram_value),
        .output_enable(RO),
        .data_out(ram_out),
        .output_enable_intent(ram_oe)
    );

endmodule


module chip_74ls189 (
    input  wire       clk,
    input  wire       reset,
    input  wire       clock_enable,
    input  wire       write_enable,
    input  wire [3:0] address,
    input  wire [3:0] data_in,

    output wire [3:0] data_out_n
);

    reg [3:0] memory [0:15];

    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 16; i = i + 1) begin
                memory[i] <= 4'h0;
            end
        end else if (clock_enable) begin
            if (write_enable) begin
                memory[address] <= data_in;
            end
        end
    end

    // The real 74LS189 presents inverted outputs.
    assign data_out_n = ~memory[address];

endmodule


module chip_74ls04_4bit (
    input  wire [3:0] data_in,

    output wire [3:0] data_out
);

    assign data_out = ~data_in;

endmodule


module ram_chip_74ls245 (
    input  wire [7:0] data_in,
    input  wire       output_enable,

    output wire [7:0] data_out,
    output wire       output_enable_intent
);

    assign data_out = data_in;
    assign output_enable_intent = output_enable;

endmodule
