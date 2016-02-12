//--------------------------------------------------------------------------------
//
// data_align.v
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
// Details: 
//   http://www.dangerousprototypes.com/ols
//   http://www.gadgetfactory.net/gf/project/butterflylogic
//   http://www.mygizmos.org/ols
//
// This module takes the sampled input, and shifts/compacts the data to
// eliminate any disabled groups. ie:
//
//   Channels 0,1,2 are disabled:  
//     dataOut[7:0] = channel3     (dataIn[31:24])
//
//   Channels 1,2 are disabled:    
//     dataOut[15:0] = {channel3,channel0}   (dataIn[31:24],dataIn[7:0])
//
// Compacting the data like this allows for easier RLE & filling of SRAM.
//
//--------------------------------------------------------------------------------

`timescale 1ns/100ps

module data_align(
  clock, disabledGroups, 
  validIn, dataIn, 
  // outputs...
  validOut, dataOut);

input clock;
input [3:0] disabledGroups;
input validIn;
input [31:0] dataIn;
output validOut;
output [31:0] dataOut;


//
// Registers...
//
reg [1:0] insel0, next_insel0;
reg [1:0] insel1, next_insel1;
reg insel2, next_insel2;

reg [31:0] dataOut, next_dataOut;
reg validOut, next_validOut;


//
// Input data mux...
//
always @ (posedge clock)
begin
  dataOut = next_dataOut;
  validOut = next_validOut;
end

always @*
begin
  #1;
  next_dataOut = dataIn;
  next_validOut = validIn;
  case (insel0[1:0])
    2'h1 : next_dataOut[7:0] = dataIn[15:8];
    2'h2 : next_dataOut[7:0] = dataIn[23:16];
    2'h3 : next_dataOut[7:0] = dataIn[31:24];
  endcase
  case (insel1[1:0])
    2'h1 : next_dataOut[15:8] = dataIn[23:16];
    2'h2 : next_dataOut[15:8] = dataIn[31:24];
  endcase
  case (insel2)
    1'b1 : next_dataOut[23:16] = dataIn[31:24];
  endcase
end


always @(posedge clock) 
begin
  insel0 = next_insel0;
  insel1 = next_insel1;
  insel2 = next_insel2;
end

always @*
begin
  #1;

  //
  // This block computes the mux settings for mapping the various
  // possible channels combinations onto the 32 bit BRAM block.
  //
  // If one group is selected, inputs are mapped to bits [7:0].
  // If two groups are selected, inputs are mapped to bits [15:0].
  // If three groups are selected, inputs are mapped to bits [23:0].
  // Otherwise, input pass unchanged...
  //
  // Each "insel" signal controls the select for an output mux.
  //
  // ie: insel0 controls what is -output- on bits[7:0].   
  //     Thus, if insel0 equal 2, dataOut[7:0] = dataIn[23:16]
  //
  next_insel0 = 2'h0;
  next_insel1 = 2'h0;
  next_insel2 = 1'b0;
  case (disabledGroups)
    // 24 bit configs...
    4'b0001 : begin next_insel2 = 1'b1; next_insel1=2'h1; next_insel0=2'h1; end
    4'b0010 : begin next_insel2 = 1'b1; next_insel1=2'h1; end
    4'b0100 : begin next_insel2 = 1'b1; end

    // 16 bit configs...
    4'b0011 : begin next_insel1=2'h2; next_insel0=2'h2; end
    4'b0101 : begin next_insel1=2'h2; next_insel0=2'h1; end
    4'b1001 : begin next_insel1=2'h1; next_insel0=2'h1; end
    4'b0110 : begin next_insel1=2'h2; end
    4'b1010 : begin next_insel1=2'h1; end
    4'b1100 : begin next_insel1=2'h0; end

    // 8 bit configs...
    4'b0111 : next_insel0 = 2'h3;
    4'b1011 : next_insel0 = 2'h2;
    4'b1101 : next_insel0 = 2'h1;
  endcase
end
endmodule

