//--------------------------------------------------------------------------------
//
// timer.v
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
// 36-bit timer for advanced triggers.   Gives range from 10ns to ~670 seconds.
//
//--------------------------------------------------------------------------------

`timescale 1ns/100ps

module timer (
  clk, reset, wrenb, wraddr, config_data, 
  update_timers, fsm_start_timer, fsm_clear_timer, fsm_stop_timer,
  timer_elapsed);
input clk, reset;
input wrenb, wraddr;
input [31:0] config_data;
input update_timers;
input fsm_start_timer, fsm_clear_timer, fsm_stop_timer;
output timer_elapsed;

reg [35:0] timer, next_timer;
reg [35:0] timer_limit, next_timer_limit; // 10ns to 687 seconds
reg timer_active, next_timer_active;
reg timer_elapsed, next_timer_elapsed;

//
// 10ns resolution timer's...
//
initial 
begin 
  timer = 36'h0;
  timer_active = 1'b0;
  timer_elapsed = 1'b0;
  timer_limit = 36'h0;
end

always @ (posedge clk)
begin
  timer = next_timer;
  timer_active = next_timer_active;
  timer_elapsed = next_timer_elapsed;
  timer_limit = next_timer_limit;
end

always @*
begin
  next_timer = (timer_elapsed) ? 36'h0 : timer;
  next_timer_active = timer_active;
  next_timer_elapsed = timer_elapsed;
  next_timer_limit = timer_limit;

  if (timer_active) 
    begin
      next_timer = timer+1'b1;
      if (timer >= timer_limit) 
	begin
	  next_timer_elapsed = 1'b1;
	  next_timer_active = 1'b0;
	end
    end

  if (update_timers) 
    begin
      if (fsm_start_timer) next_timer_active=1'b1;
      if (fsm_clear_timer) begin next_timer=0; next_timer_elapsed=1'b0; end
      if (fsm_stop_timer) next_timer_active=1'b0;
    end

  if (wrenb)
    case (wraddr)
      1'b0 : next_timer_limit[31:0] = config_data;
      1'b1 : next_timer_limit[35:32] = config_data[3:0];
    endcase

  if (reset)
    begin
      next_timer = 0;
      next_timer_active = 0;
      next_timer_elapsed = 0;
    end
end

endmodule
