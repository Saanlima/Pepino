//--------------------------------------------------------------------------------
// decoder.vhd
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
// Takes the opcode from the command received by the receiver and decodes it.
// The decoded command will be executed for one cycle.
//
// The receiver keeps the cmd output active long enough so all the
// data is still available on its cmd output when the command has
// been decoded and sent out to other modules with the next
// clock cycle. (Maybe this paragraph should go in receiver.vhd?)
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis - mygizmos.org
//
// 09/16/2013 - Magnus Karlsson - Added separate registers for count and delay to 
//                                increase the sample count beyond 256K
// 
// 05/21/2014 - Magnus Karlsson - Edge triggers added
//

`timescale 1ns/100ps

module decoder(
  clock, execute, opcode,
  // outputs...
  wrtrigmask, wrtrigval, wrtrigcfg, wrtrigedge,
  wrspeed, wrsize, wrfwd, wrbwd, wrFlags,
  wrTrigSelect, wrTrigChain,
  finish_now,
  arm_basic, arm_adv, resetCmd);

input clock;
input execute;
input [7:0] opcode;
output [3:0] wrtrigmask;
output [3:0] wrtrigval;
output [3:0] wrtrigcfg;
output [3:0] wrtrigedge;
output wrspeed;
output wrsize;
output wrfwd;
output wrbwd;
output wrFlags;
output wrTrigSelect;
output wrTrigChain;
output finish_now;
output arm_basic;
output arm_adv;
output resetCmd;


//
// Registers...
//
reg resetCmd, next_resetCmd;
reg arm_basic, next_arm_basic;
reg arm_adv, next_arm_adv;
reg [3:0] wrtrigmask, next_wrtrigmask;
reg [3:0] wrtrigval, next_wrtrigval;
reg [3:0] wrtrigcfg, next_wrtrigcfg;
reg [3:0] wrtrigedge, next_wrtrigedge;
reg wrspeed, next_wrspeed;
reg wrsize, next_wrsize;
reg wrfwd, next_wrfwd;
reg wrbwd, next_wrbwd;
reg wrFlags, next_wrFlags;
reg finish_now, next_finish_now;
reg wrTrigSelect, next_wrTrigSelect;
reg wrTrigChain, next_wrTrigChain;


//
// Control logic.  On "execute" signal,
// parse "opcode" and make things happen...
//
always @(posedge clock) 
begin
  resetCmd = next_resetCmd;
  arm_basic = next_arm_basic;
  arm_adv = next_arm_adv;
  wrtrigmask = next_wrtrigmask;
  wrtrigval = next_wrtrigval;
  wrtrigcfg = next_wrtrigcfg;
  wrtrigedge = next_wrtrigedge;
  wrspeed = next_wrspeed;
  wrsize = next_wrsize;
  wrfwd = next_wrfwd;
  wrbwd = next_wrbwd;
  wrFlags = next_wrFlags;
  finish_now = next_finish_now;
  wrTrigSelect = next_wrTrigSelect;
  wrTrigChain = next_wrTrigChain;
end

always @*
begin
  #1;
  next_resetCmd = 1'b0;
  next_arm_basic = 1'b0;
  next_arm_adv = 1'b0;
  next_wrtrigmask = 4'b0000;
  next_wrtrigval = 4'b0000;
  next_wrtrigcfg = 4'b0000;
  next_wrtrigedge = 4'b0000;
  next_wrspeed = 1'b0;
  next_wrsize = 1'b0;
  next_wrfwd = 1'b0;
  next_wrbwd = 1'b0;
  next_wrFlags = 1'b0;
  next_finish_now = 1'b0;
  next_wrTrigSelect = 1'b0;
  next_wrTrigChain = 1'b0;

  if (execute)
    case(opcode)
      // short commands
      8'h00 : next_resetCmd = 1'b1;
      8'h01 : next_arm_basic = 1'b1;
      8'h02 :;// Query ID (decoded in spi_slave.v)
      8'h03 :;// Selftest (reserved)
      8'h04 :;// Query Meta Data (decoded in spi_slave.v)
      8'h05 : next_finish_now = 1'b1;
      8'h06 :;// Query input data (decoded in spi_slave.v)
      8'h0F : next_arm_adv = 1'b1;
      8'h11 :;// XON (reserved)
      8'h13 :;// XOFF (reserved)

      // long commands
      8'h80 : next_wrspeed = 1'b1;
      8'h81 : next_wrsize = 1'b1;
      8'h82 : next_wrFlags = 1'b1;
      8'h83 : next_wrfwd = 1'b1;
      8'h84 : next_wrbwd = 1'b1;

      8'h9E : next_wrTrigSelect = 1'b1;
      8'h9F : next_wrTrigChain = 1'b1;

      8'hC0 : next_wrtrigmask[0] = 1'b1;
      8'hC1 : next_wrtrigval[0] = 1'b1;
      8'hC2 : next_wrtrigcfg[0] = 1'b1;
      8'hC3 : next_wrtrigedge[0] = 1'b1;
      8'hC4 : next_wrtrigmask[1] = 1'b1;
      8'hC5 : next_wrtrigval[1] = 1'b1;
      8'hC6 : next_wrtrigcfg[1] = 1'b1;
      8'hC7 : next_wrtrigedge[1] = 1'b1;
      8'hC8 : next_wrtrigmask[2] = 1'b1;
      8'hC9 : next_wrtrigval[2] = 1'b1;
      8'hCA : next_wrtrigcfg[2] = 1'b1;
      8'hCB : next_wrtrigedge[2] = 1'b1;
      8'hCC : next_wrtrigmask[3] = 1'b1;
      8'hCD : next_wrtrigval[3] = 1'b1;
      8'hCE : next_wrtrigcfg[3] = 1'b1;
      8'hCF : next_wrtrigedge[3] = 1'b1;
    endcase
end
endmodule

