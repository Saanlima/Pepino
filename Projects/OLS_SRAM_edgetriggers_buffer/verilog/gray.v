//--------------------------------------------------------------------------------
//
// gray.v
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
// These are verilog functions, called from within always blocks elsewhere.
// They compute the "gray" encoding of a binary value.  Gray counts increment
// by changing only a single bit, instead of possibly multiple bits as a binary
// counter would.  ie:
//
//    Binary    Gray
//     000      000
//     001      001
//     010      011
//     011      010
//     100      110
//     101      111
//     110      101
//     111      100
//
// The above 3-bit binary count can flip as many as 3-bits simultaneously (on
// wraparound back to zero).  The gray counter counter however, never flips
// more than one.
//
//--------------------------------------------------------------------------------
//
// The gray counter increment pattern is VERY valuable when moving multi-bit 
// values across asynchronous boundaries -- two clock domains with no relation 
// to one another.  The async-fifo in this design uses them specifically for that.
//
// There is no way to guarantee a raw multi-bit -binary- value can be synchronized 
// across an async boundary.  The bits could & would arrive in any order, causing 
// the receiving logic to become confused.  Bad medicine.
//
// The gray counter however, only ever syncs one bit no matter what.   Thus no 
// confused receiving logic.  A good thing.
//
// One small detail.  There must -never- be any combinatorial logic on the 
// actual async boundary.  ie: flop whatever in the source clock, flop it 
// again (more than once) in the destination clock.  
//
//--------------------------------------------------------------------------------
//
// Lastly, these functions are parameterizable.  Means they can be used for any 
// binary width needed by changing the "WIDTH" parameter (which must be 
// declared in the calling module).  ie:
//
//    // Create 42 bit width instance of a binary to gray count convertor...
//    module xyz(a,b);
//    parameter WIDTH = 42;
//    input [WIDTH-1:0] a;
//    output [WIDTH-1:0] b;
//    `include "gray.v"
//    reg [WIDTH-1:0] b;
//    always @* 
//    begin
//      b = gray2bin(a);
//    end
//    endmodule
//
//--------------------------------------------------------------------------------
//
function [WIDTH-1:0] gray2bin;
input [WIDTH-1:0] gray;
integer i;
begin
  // 5bit example: gray2bin = {gray[4], ^gray[4:3], ^gray[4:2], ^gray[4:1], ^gray[4:0]}
  gray2bin[WIDTH-1] = gray[WIDTH-1];
  for (i=WIDTH-2; i>=0; i=i-1) gray2bin[i] = gray2bin[i+1]^gray[i];
end
endfunction


function [WIDTH-1:0] bin2gray;
input [WIDTH-1:0] bin;
integer i;
begin
  // 5bit example: bin2gray = {bin[4], ^bin[4:3], ^bin[3:2], ^bin[2:1], ^bin[1:0]}
  for (i=0; i<WIDTH-1; i=i+1) bin2gray[i] = bin[i+1] ^ bin[i];
  bin2gray[WIDTH-1] = bin[WIDTH-1];
end
endfunction

