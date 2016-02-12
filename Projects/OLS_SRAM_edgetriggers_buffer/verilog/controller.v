//--------------------------------------------------------------------------------
// controller.vhd
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
// Controls the capturing & readback operation.
// 
// If no other operation has been activated, the controller samples data
// into the memory. When the run signal is received, it continues to do so
// for fwd * 4 samples and then sends bwd * 4 samples  to the transmitter.
// This allows to capture data from before the trigger match which is a nice 
// feature.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis - mygizmos.org
// 
// 09/16/2013 - Magnus Karlsson - Added separate registers for count and delay to 
//                                increase the sample count beyond 256K
//

`timescale 1ns/100ps

module controller(
  clock, reset, run,
  wrSize, wrFwd, wrBwd, config_data,
  validIn, dataIn, busy, arm, 
  // outputs...
  send, memoryWrData, memoryRead, 
  memoryWrite, memoryLastWrite);

input clock;
input reset;
input run;
input wrSize;
input wrFwd;
input wrBwd;
input [31:0] config_data;
input validIn;
input [31:0] dataIn;
input busy;
input arm;

output send;
output [31:0] memoryWrData;
output memoryRead;
output memoryWrite;
output memoryLastWrite;

reg [25:0] fwd, next_fwd; // Config registers...
reg [25:0] bwd, next_bwd;

reg send, next_send;
reg memoryRead, next_memoryRead;
reg memoryWrite, next_memoryWrite;
reg memoryLastWrite, next_memoryLastWrite;

reg [27:0] counter, next_counter; 
wire [27:0] counter_inc = counter+1'b1;


reg [31:0] memoryWrData, next_memoryWrData;
always @(posedge clock) 
begin
  memoryWrData = next_memoryWrData;
end
always @*
begin
  #1; next_memoryWrData = dataIn;
end



//
// Control FSM...
//
parameter [2:0]
  IDLE =     3'h0,
  SAMPLE =   3'h1,
  DELAY =    3'h2,
  READ =     3'h3,
  READWAIT = 3'h4;

reg [2:0] state, next_state; 

initial state = IDLE;
always @(posedge clock or posedge reset) 
begin
  if (reset)
    begin
      state = IDLE;
      memoryWrite = 1'b0;
      memoryLastWrite = 1'b0;
      memoryRead = 1'b0;
    end
  else 
    begin
      state = next_state;
      memoryWrite = next_memoryWrite;
      memoryLastWrite = next_memoryLastWrite;
      memoryRead = next_memoryRead;
    end
end

always @(posedge clock)
begin
  counter = next_counter;
  send = next_send;
end

// FSM to control the controller action
always @*
begin
  #1;
  next_state = state;
  next_counter = counter;
  next_memoryWrite = 1'b0;
  next_memoryLastWrite = 1'b0;
  next_memoryRead = 1'b0;
  next_send = 1'b0;

  case(state)
    IDLE :
      begin
        next_counter = 0;
        next_memoryWrite = 1;
	if (run) next_state = DELAY;
	else if (arm) next_state = SAMPLE;
      end

    // default mode: write data samples to memory
    SAMPLE : 
      begin
        next_counter = 0;
        next_memoryWrite = validIn;
        if (run) next_state = DELAY;
      end

    // keep sampling for 4 * fwd + 4 samples after run condition
    DELAY : 
      begin
	if (validIn)
	  begin
	    next_memoryWrite = 1'b1;
            next_counter = counter_inc;
            if (counter == {fwd,2'b11}) 	// IED - Evaluate only on validIn to make behavior
	      begin				// match between sampling on all-clocks verses occasionally.
		next_memoryLastWrite = 1'b1;	// Added LastWrite flag to simplify write->read memory handling.
		next_counter = 0;
		next_state = READ;
	      end
	  end
      end

    // read back 4 * bwd + 4 samples after DELAY
    // go into wait state after each sample to give transmitter time
    READ : 
      begin
        next_memoryRead = 1'b1;
        next_send = 1'b1;
        if (counter == {bwd,2'b11}) 
	  begin
            next_counter = 0;
            next_state = IDLE;
          end
        else 
	  begin
            next_counter = counter_inc;
            next_state = READWAIT;
          end
      end

    // wait for the transmitter to become ready again
    READWAIT : 
      begin
        if (!busy && !send) next_state = READ;
      end
  endcase
end


//
// Set speed and size registers if indicated...
//
always @(posedge clock) 
begin
  fwd = next_fwd;
  bwd = next_bwd;
end

always @*
begin
  #1;
  next_fwd = fwd;
  next_bwd = bwd;

  if (wrSize) 
    begin
      next_fwd = {10'd0, config_data[31:16]};
      next_bwd = {10'd0, config_data[15:0]};
    end
  else if (wrFwd)
    next_fwd = config_data[25:0];
  else if (wrBwd)
    next_bwd = config_data[25:0];
end
endmodule

