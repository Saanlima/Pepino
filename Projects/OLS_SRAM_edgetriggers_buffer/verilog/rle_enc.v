//--------------------------------------------------------------------------------
// rle_enc.vhd
//
// Copyright (C) 2007 Jonas Diemer
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
// Run Length Encoder
//
// If enabled, encode the incoming data with the following scheme:
// The MSB (bit 31) is used as a flag for the encoding.
// If the MSB is clear, the datum represents "regular" data
//  if set, the datum represents the number of repetitions of the previous data
//
//--------------------------------------------------------------------------------
//
// 01/11/2010 - Verilog Version + cleanups created by Ian Davis - mygizmos.org
//              This was basically a total rewrite for cleaner synth.
//
// RLE_MODE: Controls how <value>'s & <rle-count>'s are output.
//    0 : Repeat.  <value>'s reissued after every <rle-count> field -and- <rle-count> is inclusive of <value>
//    1 : Always.  <value>'s reissued after every <rle-count> field.
//    2 : Periodic.  <value>'s reissued approx every 256 <rle-count> fields.
//    3 : Unlimited.  <value>'s can be followed by unlimited numbers of <rle-count> fields.
// 
// 05/22/2014 - Magnus Karlsson - Fixed the RLE encoder for demux mode
//

`timescale 1ns/100ps

module rle_enc(
  clock, reset, 
  enable, arm, 
  rle_mode, demux_mode,
  disabledGroups, 
  dataIn, validIn, 
  // outputs...
  dataOut, validOut);

input clock, reset;
input enable, arm;
input [1:0] rle_mode;
input demux_mode;
input [3:0] disabledGroups;
input [31:0] dataIn;
input validIn;
output [31:0] dataOut;
output validOut;

localparam TRUE = 1'b1;
localparam FALSE = 1'b0;
localparam RLE_COUNT = 1'b1;


//
// Registers...
//
reg active, next_active;
reg mask_flag, next_mask_flag;
reg [1:0] mode, next_mode;
reg [30:0] data_mask, next_data_mask;
reg [30:0] last_data, next_last_data;
reg last_valid, next_last_valid;
reg [31:0] dataOut, next_dataOut;
reg validOut, next_validOut;

reg [30:0] count, next_count;		// # of times seen same input data
reg [8:0] fieldcount, next_fieldcount;	// # times output back-to-back <rle-counts> with no <value>
reg [1:0] track, next_track;		// Track if at start of rle-coutn sequence.

wire [30:0] inc_count = count+1'b1;
wire count_zero = ~|count;
wire count_gt_one = track[1];
wire count_full = (count==data_mask);

reg demux_mismatch;
reg mismatch;

wire [30:0] masked_dataIn = dataIn & data_mask;


// Repeat mode: In <value><rle-count> pairs, a count of 4 means 4 samples.
//   In other words, in repeat mode the count is inclusive of the value.
//   When disabled (repitition mode), the count is exclusive.
wire rle_repeat_mode = 0; // (rle_mode==0);  // Disabled - modes 0 & 1 now identical


//
// Figure out what mode we're in (8/16/24 or 32 bit)...
//
always @ (posedge clock)
begin
  mode = next_mode;
  data_mask = next_data_mask;
end
always @*
begin
  next_mode = 2'h3; // 24 or 32-bit
  case (disabledGroups)
    4'b1110,4'b1101,4'b1011,4'b0111 : next_mode = 2'h0; // 8-bit
    4'b1100,4'b1010,4'b0110,4'b1001,4'b0101,4'b0011 : next_mode = 2'h1; // 16-bit
    4'b1000,4'b0100,4'b0010,4'b0001 : next_mode = 2'h2; // 24-bit
  endcase

  // Mask to strip off disabled groups.  Data must have already been
  // aligned (see data_align.v)...
  // Also, if demux mode mask out both values
  next_data_mask = demux_mode ? 32'h7FFF7FFF : 32'h7FFFFFFF;
  case (mode)
    2'h0 : next_data_mask = 32'h0000007F;
    2'h1 : next_data_mask = demux_mode ? 32'h00007F7F : 32'h00007FFF;
    2'h2 : next_data_mask = 32'h007FFFFF;
  endcase
end


//
// Control Logic...
//
initial begin active=0; mask_flag=0; count=0; fieldcount=0; track=0; validOut=0; last_valid=0; end
always @ (posedge clock or posedge reset)
begin
  if (reset)
    begin
      active = 0;
      mask_flag = 0;
    end
  else 
    begin
      active = next_active;
      mask_flag = next_mask_flag;
    end
end

always @ (posedge clock)
begin
  count = next_count;
  fieldcount = next_fieldcount;
  track = next_track;
  dataOut = next_dataOut;
  validOut = next_validOut;
  last_data = next_last_data;
  last_valid = next_last_valid;
end

always @*
begin
  next_active = active | (enable && arm);
  next_mask_flag = mask_flag | (enable && arm); // remains asserted even if rle_enable turned off

  next_dataOut = (mask_flag) ? masked_dataIn : dataIn;
  next_validOut = validIn;
  next_last_data = (validIn) ? masked_dataIn : last_data; 
  next_last_valid = FALSE;
  next_count = count & {31{active}};
  next_fieldcount = fieldcount & {9{active}};
  next_track = track & {2{active}};


  mismatch = |(masked_dataIn^last_data); // detect any difference not masked

  if (demux_mode)
    begin
      case (mode)
        2'h0 : demux_mismatch = 0; // not valid in demux mode
        2'h1 : demux_mismatch = (dataIn[14:8] != dataIn[6:0]);
        2'h2 : demux_mismatch = 0; // not valid in demux mode
        2'h3 : demux_mismatch = (dataIn[30:16] != dataIn[14:0]);
      endcase
    end
  else
    demux_mismatch = 0;

  if (active)
    begin
      next_validOut = FALSE;
      next_last_valid = last_valid | validIn;

      if (validIn && last_valid)
        if (!enable || mismatch || demux_mismatch || count_full) // if mismatch, or counter full, then output count (if count>1)...
          begin
	    next_active = enable;
            next_validOut = TRUE;
            next_dataOut = {RLE_COUNT,count};
            case (mode)
              2'h0 : next_dataOut = {RLE_COUNT,count[6:0]};
              2'h1 : next_dataOut = {RLE_COUNT,count[14:0]};
              2'h2 : next_dataOut = {RLE_COUNT,count[22:0]};
            endcase
            if (!count_gt_one) next_dataOut = last_data;

	    next_fieldcount = fieldcount+1'b1; // inc # times output rle-counts

	    // If mismatch, or rle_mode demands it, set count=0 (which will force reissue of a <value>).
	    // Otherwise, set to 1 to avoid thre redundant <value> from being output.
	    next_count = (mismatch || demux_mismatch || ~rle_mode[1] || ~rle_mode[0] & fieldcount[8]) ? 0 : 1;
	    next_track = next_count[1:0];
          end
        else // match && !count_full
	  begin
            next_count = inc_count;
	    if (count_zero) // write initial data if count zero
	      begin
		next_fieldcount = 0;
		next_validOut = TRUE;
	      end
	    if (rle_repeat_mode && count_zero) next_count = 2;
	    next_track = {|track,1'b1};
	  end
    end
end
endmodule

