`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// vga_debug_display.v
//
// Read-only VGA debug display for SAP-1 controls, bus, registers, and ALU.
// Generates simple 640x480-style VGA timing from CLK100MHZ using a /4 pixel tick.
// -----------------------------------------------------------------------------

module sap1_vga_debug_display (
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] bus_value,
    input  wire [7:0] a_value,
    input  wire [7:0] b_value,
    input  wire [7:0] alu_result,
    input  wire       mode_switch,
    input  wire       halt_switch,
    input  wire       alu_su,
    input  wire       alu_eo,
    input  wire       manual_bus_oe,

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

    reg [1:0] pix_div;
    reg [9:0] h_count;
    reg [9:0] v_count;

    wire pixel_tick = (pix_div == 2'd0);
    wire visible = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
    wire text_pixel;
    wire [3:0] text_r;
    wire [3:0] text_g;
    wire [3:0] text_b;

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
        .alu_result(alu_result),
        .mode_switch(mode_switch),
        .halt_switch(halt_switch),
        .alu_su(alu_su),
        .alu_eo(alu_eo),
        .manual_bus_oe(manual_bus_oe),
        .text_pixel(text_pixel),
        .text_r(text_r),
        .text_g(text_g),
        .text_b(text_b)
    );

    assign vga_r = (visible && text_pixel) ? text_r : 4'h0;
    assign vga_g = (visible && text_pixel) ? text_g : 4'h0;
    assign vga_b = (visible && text_pixel) ? text_b : 4'h0;

endmodule


module sap1_vga_debug_text (
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire [7:0] bus_value,
    input  wire [7:0] a_value,
    input  wire [7:0] b_value,
    input  wire [7:0] alu_result,
    input  wire       mode_switch,
    input  wire       halt_switch,
    input  wire       alu_su,
    input  wire       alu_eo,
    input  wire       manual_bus_oe,

    output wire       text_pixel,
    output wire [3:0] text_r,
    output wire [3:0] text_g,
    output wire [3:0] text_b
);
    localparam TEXT_X = 10'd16;
    localparam TEXT_Y = 10'd16;

    localparam COLOR_WHITE = 2'd0;
    localparam COLOR_GREEN = 2'd1;
    localparam COLOR_RED   = 2'd2;

    wire in_text_area = (x >= TEXT_X) && (x < TEXT_X + 10'd256) &&
                        (y >= TEXT_Y) && (y < TEXT_Y + 10'd80);
    wire [9:0] rel_x = x - TEXT_X;
    wire [9:0] rel_y = y - TEXT_Y;
    wire [4:0] char_col = rel_x[9:3];
    wire [3:0] char_row = rel_y[6:3];
    wire [2:0] glyph_x = rel_x[2:0];
    wire [2:0] glyph_y = rel_y[2:0];

    reg [7:0] glyph;
    reg [7:0] glyph_row;
    reg [1:0] glyph_color;
    reg       row_switch_value;

    always @* begin
        row_switch_value = 1'b0;

        case (char_row)
            4'd0: row_switch_value = mode_switch;
            4'd1: row_switch_value = halt_switch;
            4'd2: row_switch_value = alu_su;
            4'd3: row_switch_value = alu_eo;
            4'd4: row_switch_value = manual_bus_oe;
            default: row_switch_value = 1'b0;
        endcase
    end

    always @* begin
        glyph_color = COLOR_WHITE;

        if (char_row <= 4'd4) begin
            if ((char_col >= 5'd11) && (char_col <= 5'd16)) begin
                glyph_color = row_switch_value ? COLOR_RED : COLOR_GREEN;
            end else if ((char_col >= 5'd19) && (char_col <= 5'd26)) begin
                glyph_color = row_switch_value ? COLOR_GREEN : COLOR_RED;
            end
        end
    end

    always @* begin
        glyph = 8'h20;

        case (char_row)
            4'd0: begin
                case (char_col)
                    5'd0:  glyph = "S";
                    5'd1:  glyph = "W";
                    5'd2:  glyph = "0";
                    5'd4:  glyph = "C";
                    5'd5:  glyph = "L";
                    5'd6:  glyph = "O";
                    5'd7:  glyph = "C";
                    5'd8:  glyph = "K";
                    5'd11: glyph = "0";
                    5'd13: glyph = "A";
                    5'd14: glyph = "U";
                    5'd15: glyph = "T";
                    5'd16: glyph = "O";
                    5'd19: glyph = "1";
                    5'd21: glyph = "M";
                    5'd22: glyph = "A";
                    5'd23: glyph = "N";
                    5'd24: glyph = "U";
                    5'd25: glyph = "A";
                    5'd26: glyph = "L";
                    default: glyph = 8'h20;
                endcase
            end
            4'd1: begin
                case (char_col)
                    5'd0:  glyph = "S";
                    5'd1:  glyph = "W";
                    5'd2:  glyph = "1";
                    5'd4:  glyph = "H";
                    5'd5:  glyph = "A";
                    5'd6:  glyph = "L";
                    5'd7:  glyph = "T";
                    5'd11: glyph = "0";
                    5'd13: glyph = "R";
                    5'd14: glyph = "U";
                    5'd15: glyph = "N";
                    5'd19: glyph = "1";
                    5'd21: glyph = "H";
                    5'd22: glyph = "A";
                    5'd23: glyph = "L";
                    5'd24: glyph = "T";
                    5'd25: glyph = "E";
                    5'd26: glyph = "D";
                    default: glyph = 8'h20;
                endcase
            end
            4'd2: begin
                case (char_col)
                    5'd0:  glyph = "S";
                    5'd1:  glyph = "W";
                    5'd2:  glyph = "5";
                    5'd4:  glyph = "S";
                    5'd5:  glyph = "U";
                    5'd11: glyph = "0";
                    5'd13: glyph = "A";
                    5'd14: glyph = "D";
                    5'd15: glyph = "D";
                    5'd19: glyph = "1";
                    5'd21: glyph = "S";
                    5'd22: glyph = "U";
                    5'd23: glyph = "B";
                    default: glyph = 8'h20;
                endcase
            end
            4'd3: begin
                case (char_col)
                    5'd0:  glyph = "S";
                    5'd1:  glyph = "W";
                    5'd2:  glyph = "6";
                    5'd4:  glyph = "E";
                    5'd5:  glyph = "O";
                    5'd11: glyph = "0";
                    5'd13: glyph = "!";
                    5'd14: glyph = "O";
                    5'd15: glyph = "U";
                    5'd16: glyph = "T";
                    5'd19: glyph = "1";
                    5'd21: glyph = "O";
                    5'd22: glyph = "U";
                    5'd23: glyph = "T";
                    default: glyph = 8'h20;
                endcase
            end
            4'd4: begin
                case (char_col)
                    5'd0:  glyph = "S";
                    5'd1:  glyph = "W";
                    5'd2:  glyph = "7";
                    5'd4:  glyph = "B";
                    5'd5:  glyph = "U";
                    5'd6:  glyph = "S";
                    5'd11: glyph = "0";
                    5'd13: glyph = "!";
                    5'd14: glyph = "O";
                    5'd15: glyph = "U";
                    5'd16: glyph = "T";
                    5'd19: glyph = "1";
                    5'd21: glyph = "O";
                    5'd22: glyph = "U";
                    5'd23: glyph = "T";
                    default: glyph = 8'h20;
                endcase
            end
            4'd6: begin
                case (char_col)
                    5'd0:  glyph = "B";
                    5'd1:  glyph = "U";
                    5'd2:  glyph = "S";
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
            end
            4'd7: begin
                case (char_col)
                    5'd0:  glyph = "R";
                    5'd1:  glyph = "E";
                    5'd2:  glyph = "G";
                    5'd4:  glyph = "A";
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
            end
            4'd8: begin
                case (char_col)
                    5'd0:  glyph = "R";
                    5'd1:  glyph = "E";
                    5'd2:  glyph = "G";
                    5'd4:  glyph = "B";
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
            4'd9: begin
                case (char_col)
                    5'd0:  glyph = "A";
                    5'd1:  glyph = "L";
                    5'd2:  glyph = "U";
                    5'd11: glyph = "-";
                    5'd13: glyph = alu_result[7] ? "1" : "0";
                    5'd14: glyph = alu_result[6] ? "1" : "0";
                    5'd15: glyph = alu_result[5] ? "1" : "0";
                    5'd16: glyph = alu_result[4] ? "1" : "0";
                    5'd17: glyph = alu_result[3] ? "1" : "0";
                    5'd18: glyph = alu_result[2] ? "1" : "0";
                    5'd19: glyph = alu_result[1] ? "1" : "0";
                    5'd20: glyph = alu_result[0] ? "1" : "0";
                    default: glyph = 8'h20;
                endcase
            end
            default: glyph = 8'h20;
        endcase
    end

    always @* begin
        case (glyph)
            "!": case (glyph_y)
                3'd0: glyph_row = 8'b00011000;
                3'd1: glyph_row = 8'b00011000;
                3'd2: glyph_row = 8'b00011000;
                3'd3: glyph_row = 8'b00011000;
                3'd4: glyph_row = 8'b00011000;
                3'd5: glyph_row = 8'b00000000;
                3'd6: glyph_row = 8'b00011000;
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
            "5": case (glyph_y)
                3'd0: glyph_row = 8'b01111110;
                3'd1: glyph_row = 8'b01100000;
                3'd2: glyph_row = 8'b01111100;
                3'd3: glyph_row = 8'b00000110;
                3'd4: glyph_row = 8'b00000110;
                3'd5: glyph_row = 8'b01100110;
                3'd6: glyph_row = 8'b00111100;
                default: glyph_row = 8'b00000000;
            endcase
            "6": case (glyph_y)
                3'd0: glyph_row = 8'b00111100;
                3'd1: glyph_row = 8'b01100000;
                3'd2: glyph_row = 8'b01100000;
                3'd3: glyph_row = 8'b01111100;
                3'd4: glyph_row = 8'b01100110;
                3'd5: glyph_row = 8'b01100110;
                3'd6: glyph_row = 8'b00111100;
                default: glyph_row = 8'b00000000;
            endcase
            "7": case (glyph_y)
                3'd0: glyph_row = 8'b01111110;
                3'd1: glyph_row = 8'b00000110;
                3'd2: glyph_row = 8'b00001100;
                3'd3: glyph_row = 8'b00011000;
                3'd4: glyph_row = 8'b00110000;
                3'd5: glyph_row = 8'b00110000;
                3'd6: glyph_row = 8'b00110000;
                default: glyph_row = 8'b00000000;
            endcase
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
            "C": case (glyph_y)
                3'd0: glyph_row = 8'b00111100;
                3'd1: glyph_row = 8'b01100110;
                3'd2: glyph_row = 8'b01100000;
                3'd3: glyph_row = 8'b01100000;
                3'd4: glyph_row = 8'b01100000;
                3'd5: glyph_row = 8'b01100110;
                3'd6: glyph_row = 8'b00111100;
                default: glyph_row = 8'b00000000;
            endcase
            "D": case (glyph_y)
                3'd0: glyph_row = 8'b01111100;
                3'd1: glyph_row = 8'b01100110;
                3'd2: glyph_row = 8'b01100110;
                3'd3: glyph_row = 8'b01100110;
                3'd4: glyph_row = 8'b01100110;
                3'd5: glyph_row = 8'b01100110;
                3'd6: glyph_row = 8'b01111100;
                default: glyph_row = 8'b00000000;
            endcase
            "E": case (glyph_y)
                3'd0: glyph_row = 8'b01111110;
                3'd1: glyph_row = 8'b01100000;
                3'd2: glyph_row = 8'b01100000;
                3'd3: glyph_row = 8'b01111100;
                3'd4: glyph_row = 8'b01100000;
                3'd5: glyph_row = 8'b01100000;
                3'd6: glyph_row = 8'b01111110;
                default: glyph_row = 8'b00000000;
            endcase
            "G": case (glyph_y)
                3'd0: glyph_row = 8'b00111100;
                3'd1: glyph_row = 8'b01100110;
                3'd2: glyph_row = 8'b01100000;
                3'd3: glyph_row = 8'b01101110;
                3'd4: glyph_row = 8'b01100110;
                3'd5: glyph_row = 8'b01100110;
                3'd6: glyph_row = 8'b00111100;
                default: glyph_row = 8'b00000000;
            endcase
            "H": case (glyph_y)
                3'd0: glyph_row = 8'b01100110;
                3'd1: glyph_row = 8'b01100110;
                3'd2: glyph_row = 8'b01100110;
                3'd3: glyph_row = 8'b01111110;
                3'd4: glyph_row = 8'b01100110;
                3'd5: glyph_row = 8'b01100110;
                3'd6: glyph_row = 8'b01100110;
                default: glyph_row = 8'b00000000;
            endcase
            "K": case (glyph_y)
                3'd0: glyph_row = 8'b01100110;
                3'd1: glyph_row = 8'b01101100;
                3'd2: glyph_row = 8'b01111000;
                3'd3: glyph_row = 8'b01110000;
                3'd4: glyph_row = 8'b01111000;
                3'd5: glyph_row = 8'b01101100;
                3'd6: glyph_row = 8'b01100110;
                default: glyph_row = 8'b00000000;
            endcase
            "L": case (glyph_y)
                3'd0: glyph_row = 8'b01100000;
                3'd1: glyph_row = 8'b01100000;
                3'd2: glyph_row = 8'b01100000;
                3'd3: glyph_row = 8'b01100000;
                3'd4: glyph_row = 8'b01100000;
                3'd5: glyph_row = 8'b01100000;
                3'd6: glyph_row = 8'b01111110;
                default: glyph_row = 8'b00000000;
            endcase
            "M": case (glyph_y)
                3'd0: glyph_row = 8'b01100011;
                3'd1: glyph_row = 8'b01110111;
                3'd2: glyph_row = 8'b01111111;
                3'd3: glyph_row = 8'b01101011;
                3'd4: glyph_row = 8'b01100011;
                3'd5: glyph_row = 8'b01100011;
                3'd6: glyph_row = 8'b01100011;
                default: glyph_row = 8'b00000000;
            endcase
            "N": case (glyph_y)
                3'd0: glyph_row = 8'b01100110;
                3'd1: glyph_row = 8'b01110110;
                3'd2: glyph_row = 8'b01111110;
                3'd3: glyph_row = 8'b01111110;
                3'd4: glyph_row = 8'b01101110;
                3'd5: glyph_row = 8'b01100110;
                3'd6: glyph_row = 8'b01100110;
                default: glyph_row = 8'b00000000;
            endcase
            "O": case (glyph_y)
                3'd0: glyph_row = 8'b00111100;
                3'd1: glyph_row = 8'b01100110;
                3'd2: glyph_row = 8'b01100110;
                3'd3: glyph_row = 8'b01100110;
                3'd4: glyph_row = 8'b01100110;
                3'd5: glyph_row = 8'b01100110;
                3'd6: glyph_row = 8'b00111100;
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
            "S": case (glyph_y)
                3'd0: glyph_row = 8'b00111110;
                3'd1: glyph_row = 8'b01100000;
                3'd2: glyph_row = 8'b01100000;
                3'd3: glyph_row = 8'b00111100;
                3'd4: glyph_row = 8'b00000110;
                3'd5: glyph_row = 8'b00000110;
                3'd6: glyph_row = 8'b01111100;
                default: glyph_row = 8'b00000000;
            endcase
            "T": case (glyph_y)
                3'd0: glyph_row = 8'b01111110;
                3'd1: glyph_row = 8'b00011000;
                3'd2: glyph_row = 8'b00011000;
                3'd3: glyph_row = 8'b00011000;
                3'd4: glyph_row = 8'b00011000;
                3'd5: glyph_row = 8'b00011000;
                3'd6: glyph_row = 8'b00011000;
                default: glyph_row = 8'b00000000;
            endcase
            "U": case (glyph_y)
                3'd0: glyph_row = 8'b01100110;
                3'd1: glyph_row = 8'b01100110;
                3'd2: glyph_row = 8'b01100110;
                3'd3: glyph_row = 8'b01100110;
                3'd4: glyph_row = 8'b01100110;
                3'd5: glyph_row = 8'b01100110;
                3'd6: glyph_row = 8'b00111100;
                default: glyph_row = 8'b00000000;
            endcase
            "W": case (glyph_y)
                3'd0: glyph_row = 8'b01100011;
                3'd1: glyph_row = 8'b01100011;
                3'd2: glyph_row = 8'b01100011;
                3'd3: glyph_row = 8'b01101011;
                3'd4: glyph_row = 8'b01111111;
                3'd5: glyph_row = 8'b01110111;
                3'd6: glyph_row = 8'b01100011;
                default: glyph_row = 8'b00000000;
            endcase
            default: glyph_row = 8'b00000000;
        endcase
    end

    assign text_pixel = in_text_area && glyph_row[3'd7 - glyph_x];
    assign text_r = (glyph_color == COLOR_GREEN) ? 4'h0 : 4'hF;
    assign text_g = (glyph_color == COLOR_RED)   ? 4'h0 : 4'hF;
    assign text_b = (glyph_color == COLOR_WHITE) ? 4'hF : 4'h0;

endmodule
