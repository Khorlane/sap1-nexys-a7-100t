`timescale 1ns / 1ps

// SAP-1 Manual RAM Loader
//
// Models Ben Eater's extra RAM programming board.
//
// Physical parts represented:
//
//   U1 = manual RAM write push button
//   U2 = 74LS157 write-signal selector
//   U3 = 8-channel DIP switch for manual RAM data
//   U4 = 74LS157 low-nibble RAM data selector
//   U5 = 74LS157 high-nibble RAM data selector
//   U6 = 74LS00 NAND gate used for CPU-mode RAM write timing
//
// Ben ties the select pins of U2, U4, and U5 together.
// In this module that shared signal is ram_loader_sel.
//
// Convention used here:
//
//   ram_loader_sel = 0  -> manual/program mode
//   ram_loader_sel = 1  -> normal run mode
//   manual_write_btn = 0 -> idle/no manual write
//   manual_write_btn = 1 -> manual write button pressed
//   ri_n = 1 -> idle/no CPU RAM write request
//   ri_n = 0 -> CPU RAM write requested
//   ram_write_n = 1 -> RAM write inactive/idle
//   ram_write_n = 0 -> RAM write active
//
// That matches 74LS157 behavior:
//
//   S = 0 selects A inputs
//   S = 1 selects B inputs
//
// Therefore:
//
//   A side = manual loader path
//   B side = normal CPU/bus path
//
// This module intentionally models the physical loader's active-low write
// boundary. If connected to the current RAM module's active-high RI input,
// convert at the integration point with ram_write_enable = ~ram_write_n.

module ram_loader (
  input        clk,

  // Shared select signal tied to U2, U4, and U5 select pins.
  input        ram_loader_sel,

  // U1 manual write push button.
  // This should be 1 when pressed.
  input        manual_write_btn,

  // U3 manual data DIP switches.
  // These are the logical switch values from the FPGA board.
  // If your physical switches are active-low, invert them before or inside here.
  input  [7:0] manual_data_sw,

  // Normal CPU/bus-side RAM data input.
  // This corresponds to the RAM module 74LS245 bus-side data.
  input  [7:0] bus_data,

  // CPU RAM-in control signal.
  // Ben's RI control signal is active-low.
  input        ri_n,

  // Data sent to RAM data inputs.
  output [7:0] ram_data_in,

  // RAM write control output.
  // Active-low write enable for the RAM chips.
  output       ram_write_n
);

  // ---------------------------------------------------------------------------
  // U3 - Manual data DIP switch behavior
  //
  // Ben wires the DIP switches so that an "on" switch pulls the selected
  // data line low.
  //
  // So the manual data presented to the RAM selector is active-low relative
  // to the visible switch position:
  //
  //   switch on  -> 0
  //   switch off -> 1
  //
  // If manual_data_sw already represents the electrical line level after
  // pullups/pulldowns, remove this inversion.
  // ---------------------------------------------------------------------------

  wire [7:0] manual_data_to_ram;

  assign manual_data_to_ram = ~manual_data_sw;

  // ---------------------------------------------------------------------------
  // U4/U5 - 74LS157 RAM data selectors
  //
  // U4 selects the low nibble.
  // U5 selects the high nibble.
  //
  // S = 0 selects A inputs = manual DIP data.
  // S = 1 selects B inputs = bus data.
  // ---------------------------------------------------------------------------

  assign ram_data_in = (ram_loader_sel == 1'b0)
                     ? manual_data_to_ram
                     : bus_data;

  // ---------------------------------------------------------------------------
  // U6 - 74LS00 NAND gate
  //
  // Ben uses one NAND gate with:
  //
  //   U6 pin 1 = clock
  //   U6 pin 2 = RI control signal, active-low
  //   U6 pin 3 = NAND output
  //
  // On Ben's breadboard, the SAP-1 clock is not connected directly to U6 pin 1.
  // It is AC-coupled through a 0.01 uF capacitor, with a 1 kOhm resistor from
  // U6 pin 1 to ground. That RC network turns the clock edge into a short write
  // pulse instead of letting the RAM write signal follow the full clock-high
  // interval.
  //
  // This FPGA model represents that short write window digitally by expecting
  // clk to be the one-system-clock-cycle sap_clk_en pulse, not a free-running
  // generated clock. The RAM module then writes synchronously on the system
  // clock when that write pulse is active.
  //
  // Since RI is active-low:
  //
  //   ri_n = 0 and clk = 1 -> NAND output = 1
  //
  // The exact external RAM write polarity depends on the surrounding RAM
  // circuit. For Ben's SAP-1 style RAM, the write control is active-low,
  // so CPU-mode write should pulse low when RI is asserted and clock is high.
  //
  // Therefore cpu_write_n is derived as:
  //
  //   write when clk == 1 and ri_n == 0
  // ---------------------------------------------------------------------------

  wire cpu_write_n;

  assign cpu_write_n = ~(clk & ~ri_n);

  // ---------------------------------------------------------------------------
  // U2 - 74LS157 write-signal selector
  //
  // S = 0 selects A input = manual pushbutton write.
  // S = 1 selects B input = CPU RI/clock write path.
  //
  // manual_write_btn is assumed active-high from the FPGA input.
  // RAM write output is active-low, so pressing the button drives write low.
  // ---------------------------------------------------------------------------

  wire manual_write_n;

  assign manual_write_n = ~manual_write_btn;

  assign ram_write_n = (ram_loader_sel == 1'b0)
                     ? manual_write_n
                     : cpu_write_n;

endmodule
