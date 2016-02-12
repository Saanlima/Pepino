//--------------------------------------------------------------------------------
// clockman.vhd
//
// Author: Michael "Mr. Sump" Poppitz
//
// Details: http://www.sump.org/projects/analyzer/
//
// This is only a wrapper for Xilinx' DCM component so it doesn't
// have to go in the main code and can be replaced more easily.
//
// Creates 100Mhz core clk0 from 32Mhz input reference clock.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version created by Ian Davis - mygizmos.org
// 
// 09/08/2013 - Version for Pepino by Magnus Karlsson
//
`timescale 1ns/100ps

module pll_wrapper (clkin, clk0);
input clkin; // clock input
output clk0; // double clock rate output

wire clkin;
wire clk0;

wire clk2x; 

  DCM_SP DCM_baseClock (
    .CLKIN(clkin),
    .CLKFB(clk0),
    .RST(1'b0),
    .PSEN(1'b0),
    .PSINCDEC(1'b0),
    .PSCLK(1'b0),
    .DSSEN(1'b0),
    .CLK0(),
    .CLK90(),
    .CLK180(),
    .CLK270(),
    .CLKDV(),
    .CLK2X(clk2x),
    .CLK2X180(),
    .CLKFX(),
    .CLKFX180(),
    .STATUS(),
    .LOCKED(),
    .PSDONE());

  defparam DCM_baseClock.CLKIN_DIVIDE_BY_2 = "FALSE";
  defparam DCM_baseClock.CLKIN_PERIOD = 20.000;
  defparam DCM_baseClock.CLK_FEEDBACK = "2X";

  BUFG BUFG_clkfb(.I(clk2x), .O(clk0));

endmodule

