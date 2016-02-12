
//--------------------------------------------------------------------------------
//
// delay_fifo.v
// Copyright (C) 2011 Ian Davis
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program; if not, write to the Free Software Foundation, Inc.,
// 51 Franklin St, Fifth Floor, Boston, MA 02110, USA
//
//--------------------------------------------------------------------------------
//
// Simple delay FIFO.   Input data delayed by parameter "DELAY" numbers of 
// clocks (1 to 16).  Uses shift register LUT's, so takes only one LUT-RAM 
// per bit regardless of delay.
//
module delay_fifo (
  clock, reset,
  validIn, dataIn,
  // outputs
  validOut, dataOut);

parameter DELAY = 3;	// 1 to 16
parameter WIDTH = 32;

input clock, reset;
input validIn;
input [WIDTH-1:0] dataIn;
output validOut;
output [WIDTH-1:0] dataOut;

wire [3:0] dly = DELAY-1;
SRLC16E s(.A0(dly[0]), .A1(dly[1]), .A2(dly[2]), .A3(dly[3]), .CLK(clock), .CE(1'b1), .D(validIn), .Q(validOut));

wire [WIDTH-1:0] dataOut;
genvar i;
generate
  for (i=0; i<WIDTH; i=i+1) 
    begin : shiftgen
      SRLC16E s(.A0(dly[0]), .A1(dly[1]), .A2(dly[2]), .A3(dly[3]), .CLK(clock), .CE(1'b1), .D(dataIn[i]), .Q(dataOut[i]));
    end
endgenerate

endmodule

