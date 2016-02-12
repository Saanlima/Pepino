//--------------------------------------------------------------------------------
// stage.vhd
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
// Programmable 32 channel trigger stage. It can operate in serial
// and parallel mode. In serial mode any of the input channels
// can be used as input for the 32bit shift register. Comparison
// is done using the value and mask registers on the input in
// parallel mode and on the shift register in serial mode.
// If armed and 'level' has reached the configured minimum value,
// the stage will start to check for a match.
// The match and run output signal delay can be configured.
// The stage will disarm itself after a match occured or when reset is set.
//
// The stage supports "high speed demux" operation in serial and parallel
// mode. (Lower and upper 16 channels contain a 16bit sample each.)
//
// Matching is done using a pipeline. This should not increase the minimum
// time needed between two dependend trigger stage matches, because the
// dependence is evaluated in the last pipeline step.
// It does however increase the delay for the capturing process, but this
// can easily be software compensated. (By adjusting the before/after ratio.)
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Ian Davis (IED) - Verilog version, changed to use LUT based 
//    masked comparisons, and other cleanups created - mygizmos.org
// 
// 05/22/2014 - Magnus Karlsson - Added edge triggers, removerd LUT-based comparisons
//

`timescale 1ns/100ps

module stage(
  clock, reset, dataIn, validIn,
  wrMask, wrValue, wrEdge, 
  wrConfig, config_data,
  arm, demux_mode, level,
  // outputs...
  run, match);

parameter TRUE = 1'b1;
parameter FALSE = 1'b0;

input clock, reset;
input validIn;
input [31:0] dataIn;		// Channel data...
input wrMask;			// Write trigger mask register
input wrValue;		// Write trigger value register
input wrEdge;			// Write trigger edge register
input wrConfig;		// Write trigger config register
input [31:0] config_data;	// Data to write into trigger config regs
input arm;
input demux_mode;
input [1:0] level;
output run;
output match;


//
// Registers...
//
reg [31:0] dataIn_dlyd;
reg validIn_dlyd;
reg [31:0] maskRegister, next_maskRegister;
reg [31:0] valueRegister, next_valueRegister;
reg [31:0] edgeRegister, next_edgeRegister;
reg [27:0] configRegister, next_configRegister;
reg [15:0] counter, next_counter; 

reg [31:0] shiftRegister, next_shiftRegister;
reg match32Register, next_match32Register;

reg run, next_run;
reg match, next_match;


//
// Useful decodes...
//
wire cfgStart = configRegister[27];
wire cfgSerial = configRegister[26];
wire [4:0] cfgChannel = configRegister[24:20];
wire [1:0] cfgLevel = configRegister[17:16];
wire [15:0] cfgDelay = configRegister[15:0];


// Remember last data in for edge triggers
always @ (posedge clock)
  if (wrConfig) begin
    dataIn_dlyd <= 0;
    validIn_dlyd <= 0;
  end else begin
    dataIn_dlyd <= validIn ? dataIn : dataIn_dlyd;
    validIn_dlyd <= validIn | validIn_dlyd;
  end
    
//
// Handle mask, value, edge & config register write requests
//
always @ (posedge clock or posedge reset)
  if (reset) begin
    maskRegister <= 0;
    valueRegister <= 0;
    edgeRegister <= 0;
    configRegister <= 0;
  end else begin
    maskRegister <= next_maskRegister;
    valueRegister <= next_valueRegister;
    edgeRegister <= next_edgeRegister;
    configRegister <= next_configRegister;
  end

always @*
begin
  next_maskRegister = (wrMask) ? config_data : maskRegister;
  next_valueRegister = (wrValue) ? config_data : valueRegister;
  next_edgeRegister = (wrEdge) ? config_data : edgeRegister;
  next_configRegister = (wrConfig) ? config_data[27:0] : configRegister;
end


//
// Use shift register or dataIn depending on configuration...
//
wire [31:0] testValue = (cfgSerial) ? shiftRegister : dataIn;

//
// Match detector
//
wire [31:0] edgeMatch, bitMatch;
genvar i;
generate
  for(i = 0 ; i < 32 ; i = i + 1)
    begin
      assign edgeMatch[i] = validIn_dlyd & (valueRegister[i] ? (dataIn[i] & ~dataIn_dlyd[i]) : (~dataIn[i] & dataIn_dlyd[i]));
      assign bitMatch[i] = ~maskRegister[i] | ((edgeRegister[i] & ~cfgSerial) ? edgeMatch[i] : (~testValue[i] ^ valueRegister[i]));
    end
endgenerate
    
wire matchL16 = &bitMatch[15:0];
wire matchH16 = &bitMatch[31:16];


//
// In demux mode only one half must match, in normal mode both words must match...
//
always @(posedge clock) 
begin
  match32Register <= next_match32Register;
end

always @*
begin
  if (demux_mode) 
    next_match32Register = matchL16 | matchH16;
  else next_match32Register = matchL16 & matchH16;
end


//
// Select serial channel based on cfgChannel...
//
wire serialChannelL16 = dataIn[{1'b0,cfgChannel[3:0]}];
wire serialChannelH16 = dataIn[{1'b1,cfgChannel[3:0]}];


//
// Shift in bit from selected channel whenever dataIn is ready...
always @(posedge clock) 
begin
  shiftRegister <= next_shiftRegister;
end

always @*
begin
  next_shiftRegister = shiftRegister;
  if (validIn)
    if (demux_mode) // in demux mode two bits come in per sample
      next_shiftRegister = {shiftRegister,serialChannelH16,serialChannelL16};
    else next_shiftRegister = {shiftRegister, (cfgChannel[4]) ? serialChannelH16 : serialChannelL16};
end


//
// Trigger state machine...
//
parameter [1:0]
  OFF = 2'h0,
  ARMED = 2'h1,
  MATCHED = 2'h2;

reg [1:0] state, next_state;

initial state = OFF;
always @(posedge clock or posedge reset) 
begin
  if (reset) 
    begin
      state = OFF;
      counter = 0;
      match = FALSE;
      run = FALSE;
    end
  else 
    begin
      state = next_state;
      counter = next_counter;
      match = next_match;
      run = next_run;
    end
end

always @*
begin
  #1;
  next_state = state;
  next_counter = counter;
  next_match = FALSE;
  next_run = FALSE;

  case (state) // synthesis parallel_case
    OFF : 
      begin
        if (arm) next_state = ARMED;
      end

    ARMED : 
      begin
        next_counter = cfgDelay;
        if (match32Register && (level >= cfgLevel)) 
          next_state = MATCHED;
      end

    MATCHED : 
      begin
        if (validIn)
	  begin
            next_counter = counter-1'b1;
            if (~|counter)
	      begin
                next_run = cfgStart;
                next_match = ~cfgStart;
                next_state = OFF;
              end
	  end
      end
  endcase
end
endmodule
