//--------------------------------------------------------------------------------
// trigger.vhd
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
// Complex 4 stage 32 channel trigger. 
//
// All commands are passed on to the stages. This file only maintains
// the global trigger level and it outputs the run condition if it is set
// by any of the stages.
// 
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Ian Davis (IED) - Verilog version, changed to use LUT based 
//    masked comparisons, and other cleanups created - mygizmos.org
// 
// 05/21/2014 - Added edge triggers, removerd LUT-based comparisons by Magnus Karlsson
//

`timescale 1ns/100ps

module trigger(
  clock, reset, 
  dataIn, validIn, 
  wrMask, wrValue,
  wrConfig, wrEdge,
  config_data,
  arm, demux_mode, 
  // outputs...
  capture, run);

input clock, reset;
input validIn;
input [31:0] dataIn;		// Channel data...
input [3:0] wrMask;		// Write trigger mask register
input [3:0] wrValue;		// Write trigger value register
input [3:0] wrConfig;		// Write trigger config register
input [3:0] wrEdge;		// Write trigger edge register
input [31:0] config_data;	// Data to write into trigger config regs
input arm;
input demux_mode;
output capture;			// Store captured data in fifo.
output run;			// Tell controller when trigger hit.

reg capture, next_capture;
reg [1:0] levelReg, next_levelReg;

// if any of the stages set run, then capturing starts...
wire [3:0] stageRun;
wire run = |stageRun;


//
// Instantiate stages...
//
wire [3:0] stageMatch;
stage stage0 (
  .clock(clock), .reset(reset), .dataIn(dataIn), .validIn(validIn), 
  .wrMask(wrMask[0]), .wrValue(wrValue[0]), .wrEdge(wrEdge[0]), 
  .wrConfig(wrConfig[0]), .config_data(config_data),
  .arm(arm), .level(levelReg), .demux_mode(demux_mode),
  .run(stageRun[0]), .match(stageMatch[0]));

stage stage1 (
  .clock(clock), .reset(reset), .dataIn(dataIn), .validIn(validIn), 
  .wrMask(wrMask[1]), .wrValue(wrValue[1]), .wrEdge(wrEdge[1]), 
  .wrConfig(wrConfig[1]), .config_data(config_data),
  .arm(arm), .level(levelReg), .demux_mode(demux_mode),
  .run(stageRun[1]), .match(stageMatch[1]));

stage stage2 (
  .clock(clock), .reset(reset), .dataIn(dataIn), .validIn(validIn), 
  .wrMask(wrMask[2]), .wrValue(wrValue[2]), .wrEdge(wrEdge[2]), 
  .wrConfig(wrConfig[2]), .config_data(config_data),
  .arm(arm), .level(levelReg), .demux_mode(demux_mode),
  .run(stageRun[2]), .match(stageMatch[2]));

stage stage3 (
  .clock(clock), .reset(reset), .dataIn(dataIn), .validIn(validIn), 
  .wrMask(wrMask[3]), .wrValue(wrValue[3]), .wrEdge(wrEdge[3]), 
  .wrConfig(wrConfig[3]), .config_data(config_data),
  .arm(arm), .level(levelReg), .demux_mode(demux_mode),
  .run(stageRun[3]), .match(stageMatch[3]));


//
// Increase level on match (on any level?!)...
//
initial levelReg = 2'b00;
always @(posedge clock or posedge reset) 
begin : P2
  if (reset) 
    begin
      capture = 1'b0;
      levelReg = 2'b00;
    end
  else 
    begin
      capture = next_capture;
      levelReg = next_levelReg;
    end
end

always @*
begin
  #1;
  next_capture = arm | capture;
  next_levelReg = levelReg;
  if (|stageMatch) next_levelReg = levelReg + 1;
end
endmodule


