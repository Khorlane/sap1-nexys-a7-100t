`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// vga_debug_display.v
//
// Read-only VGA debug display for the SAP-1 bus, Register A, and Register B.
// Generates simple 640x480-style VGA timing from CLK100MHZ using a /4 pixel tick.
// -----------------------------------------------------------------------------

module sap1_vga_debug_display (
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] bus_value,
    input  wire [7:0] a_value,
    input  wire [7:0] b_value,

    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b,
    output wire       vga_hs,
    output wire       vga_vs
);
    localparam H_VISIBLE = 10'd640;
    localparam H_FRONT   = 10'd16;
    localparam H_SYNC    = 10'd96;
    localparam H_BACK    = 10'd48;
    localparam H_TOTAL   = 10'd800;

    localparam V_VISIBLE = 10'd480;
    localparam V_FRONT   = 10'd10;
    localparam V_SYNC    = 10'd2;
    localparam V_BACK    = 10'd33;
    localparam V_TOTAL   = 10'd525;

    localparam TEXT_X = 10'd16;
    localparam TEXT_Y = 10'd16;

    reg [1:0]  pix_div;
    reg [9:0]  h_count;
    reg [9:0]  v_count;

    wire pixel_tick = (pix_div == 2'd0);
    wire visible = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
    wire text_pixel;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pix_div <= 2'd0;
        end else begin
            pix_div <= pix_div + 1'b1;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end else if (pixel_tick) begin
            if (h_count == H_TOTAL - 1'b1) begin
                h_count <= 10'd0;
                if (v_count == V_TOTAL - 1'b1) begin
                    v_count <= 10'd0;
                end else begin
                    v_count <= v_count + 1'b1;
                end
            end else begin
                h_count <= h_count + 1'b1;
            end
        end
    end

    assign vga_hs = ~((h_count >= H_VISIBLE + H_FRONT) &&
                      (h_count <  H_VISIBLE + H_FRONT + H_SYNC));
    assign vga_vs = ~((v_count >= V_VISIBLE + V_FRONT) &&
                      (v_count <  V_VISIBLE + V_FRONT + V_SYNC));

    sap1_vga_debug_text u_text (
        .x(h_count),
        .y(v_count),
        .bus_value(bus_value),
        .a_value(a_value),
        .b_value(b_value),
        .text_pixel(text_pixel)
    );

    assign vga_r = (visible && text_pixel) ? 4'hF : 4'h0;
    assign vga_g = (visible && text_pixel) ? 4'hF : 4'h0;
    assign vga_b = (visible && text_pixel) ? 4'hF : 4'h0;

endmodule


module sap1_vga_debug_text (
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire [7:0] bus_value,
    input  wire [7:0] a_value,
    input  wire [7:0] b_value,
    output wire       text_pixel
);
    localparam TEXT_X = 10'd16;
    localparam TEXT_Y = 10'd16;
    localparam LINE0  = 4'd0;
    localparam LINE1  = 4'd2;
    localparam LINE2  = 4'd4;

    wire in_text_area = (x >= TEXT_X) && (x < TEXT_X + 10'd192) &&
                        (y >= TEXT_Y) && (y < TEXT_Y + 10'd48);
    wire [9:0] rel_x = x - TEXT_X;
    wire [9:0] rel_y = y - TEXT_Y;
    wire [4:0] char_col = rel_x[9:3];
    wire [3:0] char_row = rel_y[6:3];
    wire [2:0] glyph_x = rel_x[2:0];
    wire [2:0] glyph_y = rel_y[2:0];

    reg [7:0] glyph;
    reg [7:0] glyph_row;

    always @* begin
        glyph = 8'h20;

        if (char_row == LINE0) begin
            case (char_col)
                5'd0:  glyph = "B";
                5'd1:  glyph = "u";
                5'd2:  glyph = "s";
                5'd4:  glyph = "-";
                5'd5:  glyph = "-";
                5'd6:  glyph = "-";
                5'd7:  glyph = "-";
                5'd8:  glyph = "-";
                5'd9:  glyph = "-";
                5'd10: glyph = "-";
                5'd11: glyph = "-";
                5'd13: glyph = bus_value[7] ? "1" : "0";
                5'd14: glyph = bus_value[6] ? "1" : "0";
                5'd15: glyph = bus_value[5] ? "1" : "0";
                5'd16: glyph = bus_value[4] ? "1" : "0";
                5'd17: glyph = bus_value[3] ? "1" : "0";
                5'd18: glyph = bus_value[2] ? "1" : "0";
                5'd19: glyph = bus_value[1] ? "1" : "0";
                5'd20: glyph = bus_value[0] ? "1" : "0";
                default: glyph = 8'h20;
            endcase
        end else if (char_row == LINE1) begin
            case (char_col)
                5'd0:  glyph = "R";
                5'd1:  glyph = "e";
                5'd2:  glyph = "g";
                5'd3:  glyph = "i";
                5'd4:  glyph = "s";
                5'd5:  glyph = "t";
                5'd6:  glyph = "e";
                5'd7:  glyph = "r";
                5'd9:  glyph = "A";
                5'd11: glyph = "-";
                5'd13: glyph = a_value[7] ? "1" : "0";
                5'd14: glyph = a_value[6] ? "1" : "0";
                5'd15: glyph = a_value[5] ? "1" : "0";
                5'd16: glyph = a_value[4] ? "1" : "0";
                5'd17: glyph = a_value[3] ? "1" : "0";
                5'd18: glyph = a_value[2] ? "1" : "0";
                5'd19: glyph = a_value[1] ? "1" : "0";
                5'd20: glyph = a_value[0] ? "1" : "0";
                default: glyph = 8'h20;
            endcase
        end else if (char_row == LINE2) begin
            case (char_col)
                5'd0:  glyph = "R";
                5'd1:  glyph = "e";
                5'd2:  glyph = "g";
                5'd3:  glyph = "i";
                5'd4:  glyph = "s";
                5'd5:  glyph = "t";
                5'd6:  glyph = "e";
                5'd7:  glyph = "r";
                5'd9:  glyph = "B";
                5'd11: glyph = "-";
                5'd13: glyph = b_value[7] ? "1" : "0";
                5'd14: glyph = b_value[6] ? "1" : "0";
                5'd15: glyph = b_value[5] ? "1" : "0";
                5'd16: glyph = b_value[4] ? "1" : "0";
                5'd17: glyph = b_value[3] ? "1" : "0";
                5'd18: glyph = b_value[2] ? "1" : "0";
                5'd19: glyph = b_value[1] ? "1" : "0";
                5'd20: glyph = b_value[0] ? "1" : "0";
                default: glyph = 8'h20;
            endcase
        end
    end

    always @* begin
        case (glyph)
            "A": case (glyph_y)
                3'd0: glyph_row = 8'b00111100;
                3'd1: glyph_row = 8'b01100110;
                3'd2: glyph_row = 8'b01100110;
                3'd3: glyph_row = 8'b01111110;
                3'd4: glyph_row = 8'b01100110;
                3'd5: glyph_row = 8'b01100110;
                3'd6: glyph_row = 8'b01100110;
                default: glyph_row = 8'b00000000;
            endcase
            "B": case (glyph_y)
                3'd0: glyph_row = 8'b01111100;
                3'd1: glyph_row = 8'b01100110;
                3'd2: glyph_row = 8'b01100110;
                3'd3: glyph_row = 8'b01111100;
                3'd4: glyph_row = 8'b01100110;
                3'd5: glyph_row = 8'b01100110;
                3'd6: glyph_row = 8'b01111100;
                default: glyph_row = 8'b00000000;
            endcase
            "R": case (glyph_y)
                3'd0: glyph_row = 8'b01111100;
                3'd1: glyph_row = 8'b01100110;
                3'd2: glyph_row = 8'b01100110;
                3'd3: glyph_row = 8'b01111100;
                3'd4: glyph_row = 8'b01111000;
                3'd5: glyph_row = 8'b01101100;
                3'd6: glyph_row = 8'b01100110;
                default: glyph_row = 8'b00000000;
            endcase
            "e": case (glyph_y)
                3'd0: glyph_row = 8'b00000000;
                3'd1: glyph_row = 8'b00111100;
                3'd2: glyph_row = 8'b01100110;
                3'd3: glyph_row = 8'b01111110;
                3'd4: glyph_row = 8'b01100000;
                3'd5: glyph_row = 8'b01100110;
                3'd6: glyph_row = 8'b00111100;
                default: glyph_row = 8'b00000000;
            endcase
            "g": case (glyph_y)
                3'd0: glyph_row = 8'b00000000;
                3'd1: glyph_row = 8'b00111110;
                3'd2: glyph_row = 8'b01100110;
                3'd3: glyph_row = 8'b01100110;
                3'd4: glyph_row = 8'b00111110;
                3'd5: glyph_row = 8'b00000110;
                3'd6: glyph_row = 8'b00111100;
                default: glyph_row = 8'b00000000;
            endcase
            "i": case (glyph_y)
                3'd0: glyph_row = 8'b00011000;
                3'd1: glyph_row = 8'b00000000;
                3'd2: glyph_row = 8'b00111000;
                3'd3: glyph_row = 8'b00011000;
                3'd4: glyph_row = 8'b00011000;
                3'd5: glyph_row = 8'b00011000;
                3'd6: glyph_row = 8'b00111100;
                default: glyph_row = 8'b00000000;
            endcase
            "r": case (glyph_y)
                3'd0: glyph_row = 8'b00000000;
                3'd1: glyph_row = 8'b01111100;
                3'd2: glyph_row = 8'b01100110;
                3'd3: glyph_row = 8'b01100000;
                3'd4: glyph_row = 8'b01100000;
                3'd5: glyph_row = 8'b01100000;
                3'd6: glyph_row = 8'b01100000;
                default: glyph_row = 8'b00000000;
            endcase
            "s": case (glyph_y)
                3'd0: glyph_row = 8'b00000000;
                3'd1: glyph_row = 8'b00111110;
                3'd2: glyph_row = 8'b01100000;
                3'd3: glyph_row = 8'b00111100;
                3'd4: glyph_row = 8'b00000110;
                3'd5: glyph_row = 8'b01100110;
                3'd6: glyph_row = 8'b00111100;
                default: glyph_row = 8'b00000000;
            endcase
            "t": case (glyph_y)
                3'd0: glyph_row = 8'b00011000;
                3'd1: glyph_row = 8'b01111110;
                3'd2: glyph_row = 8'b00011000;
                3'd3: glyph_row = 8'b00011000;
                3'd4: glyph_row = 8'b00011000;
                3'd5: glyph_row = 8'b00011000;
                3'd6: glyph_row = 8'b00001110;
                default: glyph_row = 8'b00000000;
            endcase
            "u": case (glyph_y)
                3'd0: glyph_row = 8'b00000000;
                3'd1: glyph_row = 8'b01100110;
                3'd2: glyph_row = 8'b01100110;
                3'd3: glyph_row = 8'b01100110;
                3'd4: glyph_row = 8'b01100110;
                3'd5: glyph_row = 8'b01100110;
                3'd6: glyph_row = 8'b00111110;
                default: glyph_row = 8'b00000000;
            endcase
            "-": case (glyph_y)
                3'd0: glyph_row = 8'b00000000;
                3'd1: glyph_row = 8'b00000000;
                3'd2: glyph_row = 8'b00000000;
                3'd3: glyph_row = 8'b01111110;
                3'd4: glyph_row = 8'b00000000;
                3'd5: glyph_row = 8'b00000000;
                3'd6: glyph_row = 8'b00000000;
                default: glyph_row = 8'b00000000;
            endcase
            "0": case (glyph_y)
                3'd0: glyph_row = 8'b00111100;
                3'd1: glyph_row = 8'b01100110;
                3'd2: glyph_row = 8'b01101110;
                3'd3: glyph_row = 8'b01110110;
                3'd4: glyph_row = 8'b01100110;
                3'd5: glyph_row = 8'b01100110;
                3'd6: glyph_row = 8'b00111100;
                default: glyph_row = 8'b00000000;
            endcase
            "1": case (glyph_y)
                3'd0: glyph_row = 8'b00011000;
                3'd1: glyph_row = 8'b00111000;
                3'd2: glyph_row = 8'b00011000;
                3'd3: glyph_row = 8'b00011000;
                3'd4: glyph_row = 8'b00011000;
                3'd5: glyph_row = 8'b00011000;
                3'd6: glyph_row = 8'b00111100;
                default: glyph_row = 8'b00000000;
            endcase
            default: glyph_row = 8'b00000000;
        endcase
    end

    assign text_pixel = in_text_area && glyph_row[3'd7 - glyph_x];

endmodule
