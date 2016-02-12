//--------------------------------------------------------------------------------
// demux.vhd
//
// Copyright (C) 2006 Michael Poppitz
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
// Details: http://www.sump.org/projects/analyzer/
//
// Demultiplexes 16 input channels into 32 output channels,
// thus doubling the sampling rate for those channels.
//
// This module barely does anything anymore, but is kept for historical reasons.
// 
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis - mygizmos.org
// 

`timescale 1ns/100ps

(* equivalent_register_removal = "no" *) 
module demux(clock, indata, indata180, outdata);

input clock;
input [15:0] indata;
input [15:0] indata180;
output [31:0] outdata;

reg [15:0] dly_indata180, next_dly_indata180;
assign outdata = {dly_indata180,indata};

always @(posedge clock) 
begin
  dly_indata180 = next_dly_indata180;
end
always @*
begin
  #1;
  next_dly_indata180 = indata180;
end

endmodule

