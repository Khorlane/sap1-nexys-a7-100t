`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// bus.v
//
// FPGA-safe shared 8-bit SAP-1 bus.
//
// The physical SAP-1 uses tri-state bus drivers. Internal FPGA tri-state nets
// are avoided here; each source provides a data value and an output-enable
// intent, and this module owns the final bus value.
// -----------------------------------------------------------------------------

module bus (
    input  wire [7:0] a_out,
    input  wire       a_oe,
    input  wire [7:0] b_out,
    input  wire       b_oe,
    input  wire [7:0] pc_out,
    input  wire       pc_oe,
    input  wire [7:0] alu_out,
    input  wire       alu_oe,
    input  wire [7:0] manual_bus_value,
    input  wire       manual_bus_oe,

    output wire [7:0] bus_value,
    output wire       bus_conflict
);

    assign bus_conflict =
        (a_oe & b_oe) |
        (a_oe & pc_oe) |
        (a_oe & alu_oe) |
        (a_oe & manual_bus_oe) |
        (b_oe & pc_oe) |
        (b_oe & alu_oe) |
        (b_oe & manual_bus_oe) |
        (pc_oe & alu_oe) |
        (pc_oe & manual_bus_oe) |
        (alu_oe & manual_bus_oe);

    assign bus_value =
        bus_conflict  ? 8'h00 :
        a_oe          ? a_out :
        b_oe          ? b_out :
        pc_oe         ? pc_out :
        alu_oe        ? alu_out :
        manual_bus_oe ? manual_bus_value :
                        8'h00;

endmodule
