//--------------------------------------------------------------------------------
//
// trigger_adv.v
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
// Complex 32 channel trigger, with 16 state trigger control FSM engine.
// Uses Xilinx LUT's (look-up-table's) to perform the mask & compare operations.
// Each LUT stores two bytes, thus lots of config bits for the client to play with...
//
// The trigger stage FSM is basically more LUT's, used to create if-then-else
// conditions and specifying actions.   Available actions are:
//    HIT:      Jump to specified state # on hit-term if occurs "count" times
//    ELSE:     Jump to alternate state # on else-term match
//    CAPTURE:  Perform one capture on capture-term match
//    TRIGGER:  Start capturing data
//
// If neither HIT or ELSE matches, the state spins.
//
//--------------------------------------------------------------------------------
//
// Configuration:
// -------------
//
// To configure so much logic, we leverage the FPGA's built-in shift registers.
// The FPGA is normally configured from the external serial FLASH flash chip
// by connecting all internal parts into one massive shift register.
//
// Lucky for us, its possible to use that feature on individual LUT's.  Thus 
// the advanced triggers can be organized using blocks of long shift registers.
// This approach might seem painful, but it saves huge amounts of FPGA logic.
//
// There are 64 trigger shift register chains, encompassing 11094 config bits. 
// There are also DWORD values stored for FSM states & timer limits.  Combined 
// they total 11678 config bits.  :-)
//
//
// Client
// ------
//
// The client initializes the long shift-regs using the Select-Chain command,
// followed by one or more Write-Chain commands.  Each data write adds
// 32-bits to the selected serial shift-register chain.
//
// Exceptions are the FSM state configs & timer limits, which are DWORD values 
// stored directly.  However, the client sees no difference (just more writes
// to trigger config regs).
//
// Client Long Commands (command byte + four data bytes, LSB data byte first):
//     0x9E  ADVTRIG-Select-Chain  (LSB = Chain#.  Other bytes reserved.)
//     0x9F  ADVTRIG-Write-Chain
//
// FSM State Data (DWORD's)
//   0x00      = FSM State 0  {Trigger,StartTimer[1:0],ClearTimer[1:0],StopTimer[1:0],ElseState[3:0],Count[19:0]}
//   0x01      = FSM State 1
//   0x02      = FSM State 2
//   0x03      = FSM State 3
//   0x04      = FSM State 4
//   0x05      = FSM State 5
//   0x06      = FSM State 6
//   0x07      = FSM State 7
//   0x08      = FSM State 8
//   0x09      = FSM State 9
//   0x0A      = FSM State 10
//   0x0B      = FSM State 11
//   0x0C      = FSM State 12
//   0x0D      = FSM State 13
//   0x0E      = FSM State 14
//   0x0F      = FSM State 15
//
// LUTCHAIN's
//   0x20      = trigterm a {ax0,ax1,ax2,ax3,ay0,ay1,ay2,ay3) (128 bit chains)
//   0x21      = trigterm b 
//   0x22      = trigterm c
//   0x23      = trigterm d
//   0x24      = trigterm e
//   0x25      = trigterm f
//   0x26      = trigterm g
//   0x27      = trigterm h
//   0x28      = trigterm i
//   0x29      = trigterm j
//
//   0x30      = range 1 lower (512 bit chains)
//   0x31      = range 1 upper (512 bit chains)
//   0x32      = range 2 lower (512 bit chains)
//   0x33      = range 2 upper (512 bit chains)
//
//   0x34      = edge 1 (64 bit chains)
//   0x35      = edge 2 (64 bit chains)
//
//   0x38-0x39 = timer 1 limit (DWORD's)
//   0x3A-0x3B = timer 2 limit (DWORD's)
//
//   0x40      = state 0 hit-term {(a,b)(c,range1)(d,edge1)(e,timer1)(f,g)(h,range2)(i,edge2)(h,timer2)(mid1)(mid2)(final)} (176 bits)
//   0x41      = state 0 else-term 
//   0x42      = state 0 capture-term 
//   0x44-0x46 = state 1 terms
//   0x48-0x4A = state 2 terms
//   0x4C-0x4E = state 3 terms
//   0x50-0x52 = state 4 terms
//   0x54-0x56 = state 5 terms
//   0x58-0x5A = state 6 terms
//   0x5C-0x5E = state 7 terms
//   0x60-0x62 = state 8 terms
//   0x64-0x66 = state 9 terms
//   0x68-0x6A = state 10 terms
//   0x6C-0x6E = state 11 terms
//   0x70-0x72 = state 12 terms
//   0x74-0x76 = state 13 terms
//   0x78-0x7A = state 14 terms
//   0x7C-0x7E = state 15 terms
//

`timescale 1ns/100ps

module trigger_adv (
  clock, reset, 
  dataIn, validIn, arm, finish_now,
  wrSelect, wrChain, config_data,
  // outputs...
  run, capture);

input clock, reset;
input validIn;
input [31:0] dataIn;		// Channel data...
input arm, finish_now;
input wrSelect,wrChain;
input [31:0] config_data;
output run;			// Full capture
output capture;			// Single capture


//
// Registers...
//
reg [4:0] wrcount, next_wrcount;
reg [6:0] wraddr, next_wraddr;
reg [31:0] wrdata, next_wrdata;
reg wrenb, next_wrenb;

reg active, next_active;
reg finished, next_finished;
reg force_capture, next_force_capture;
reg [3:0] state, next_state;
reg [19:0] hit_count, next_hit_count;
reg run, next_run;
reg capture, next_capture;

wire last_state = &state;

pipeline_stall #(.DELAY(2)) dly_validIn_reg (clock, reset, validIn, dly_validIn); // sync with output of trigterms



//
// Shift register initialization handler for LUT chains...
//
initial 
begin 
  wrcount=0;
  wraddr=0;
  wrdata=0;
  wrenb=1'b0;
end

always @ (posedge clock)
begin
  wrcount = next_wrcount;
  wraddr = next_wraddr;
  wrdata = next_wrdata;
  wrenb = next_wrenb;
end

always @*
begin
  next_wrcount = (wrenb) ? wrcount+1'b1 : 0;
  next_wraddr = wraddr;
  next_wrdata = wrdata;
  next_wrenb = wrenb && (~&wrcount);

  // Capture wraddr for trigger terms setup...
  if (wrSelect) next_wraddr = config_data[6:0];

  // Shift data into trigger terms on "wrChain" command...
  if (wrChain)
    begin
      next_wrcount = 0;
      next_wrdata = config_data;
      next_wrenb = 1'b1;
    end
  else if (wrenb)
    next_wrdata = {wrdata,1'b0};

  if (reset)
    begin
      next_wrcount = 0;
      next_wraddr = 0;
      next_wrenb = 1'b0;
    end
end



//
// Instantiate the fsm state RAM.  Reads are combinatorial.
// Writes are synchronous.
//
wire wrenb_fsm = wrChain && ~|wraddr[6:5];
wire [3:0] fsm_ramaddr = (wrChain) ? wraddr[3:0] : state;

wire [31:0] fsm_state;
ram_dword fsm_ram (clock, fsm_ramaddr, wrenb_fsm, config_data, fsm_state);


//
// Decode FSM state flags: 
//   {Trigger, StartTimer[2:1], ClearTimer[2:1], StopTimer[2:1], ElseNextState[3:0], Count[19:0]}
//
wire fsm_laststate;
wire fsm_trigger;
wire fsm_start_timer1;
wire fsm_clear_timer1;
wire fsm_stop_timer1;
wire fsm_start_timer2;
wire fsm_clear_timer2;
wire fsm_stop_timer2;
wire [3:0] fsm_else_state;
wire [19:0] fsm_count;
assign {
  fsm_laststate, fsm_trigger, 
  fsm_start_timer2, fsm_start_timer1, 
  fsm_clear_timer2, fsm_clear_timer1, 
  fsm_stop_timer2, fsm_stop_timer1, 
  fsm_else_state[3:0], fsm_count[19:0]} = fsm_state;


//
// Instantiate timers...
//
reg [1:0] wrenb_timer;
reg update_timers;

always @*
begin
  wrenb_timer=0;
  if ({wraddr[6:3],3'b0}==7'h38)
    case (wraddr[1])
      1'b0 : wrenb_timer[0] = wrChain;
      1'b1 : wrenb_timer[1] = wrChain;
    endcase
end

timer timer1 (clock, reset, wrenb_timer[0], wraddr[0], config_data, 
  update_timers, fsm_start_timer1, fsm_clear_timer1, fsm_stop_timer1, 
  timer1_elapsed);

timer timer2 (clock, reset, wrenb_timer[1], wraddr[0], config_data, 
  update_timers, fsm_start_timer2, fsm_clear_timer2, fsm_stop_timer2, 
  timer2_elapsed);


//
// Instantiate terms for 8 triggers.   Each term performs a
// masked compare on all 32 input bits...  Two clock latency.
//
wire hit_term, else_term, capture_term;
trigterms trigterms (
  clock, dataIn, timer1_elapsed, timer2_elapsed, 
  wrenb, wraddr, wrdata[31], 
  state, {capture_term, else_term, hit_term});


//
// Control FSM...
//
initial 
begin 
  active = 1'b0;
  finished = 1'b0;
  force_capture = 1'b0;
  state = 4'h0;
  hit_count = 20'h0;
  run = 1'b0;
  capture = 1'b0;
end

always @ (posedge clock)
begin
  active = next_active;
  finished = next_finished;
  force_capture = next_force_capture;
  state = next_state;
  hit_count = next_hit_count;
  run = next_run;
  capture = next_capture;
end

always @*
begin
  next_active = active | arm;
  next_finished = finished;
  next_force_capture = force_capture;
  next_state = state;
  next_hit_count = hit_count;
  next_run = 1'b0;
  next_capture = 1'b0;
  update_timers = 1'b0;

  // Evaluate state...
  if (active && dly_validIn)
    begin
      next_capture = capture_term || force_capture;
      if (!finished)
        if (hit_term)
	  begin
	    next_hit_count = hit_count+1'b1;
	    if (hit_count==fsm_count)
	      begin
	        update_timers = 1'b1;
	        next_hit_count = 0;
	        if (fsm_trigger || fsm_laststate || last_state) // trigger if requested, or fsm tries to wrap-around
  		  next_run = 1'b1;
  	        if (fsm_laststate || last_state) // no wrapping around
		  next_finished = 1'b1;
	        else next_state = state + 1;
	      end
	  end
        else if (else_term) 
	  begin
	    next_hit_count = 0;
	    next_state = fsm_else_state;
	  end
    end

  if (active && finish_now)
    begin
      next_finished = 1'b1;
      next_force_capture = 1'b1;
      next_run = 1;
    end

  if (reset)
    begin
      next_active = 1'b0;
      next_finished = 1'b0;
      next_force_capture = 1'b0;
      next_state = 0;
      next_hit_count = 0;
      next_run = 0;
    end
end
endmodule



//
// Mask & compare all 32 bits of input data, for eight trigger terms, in all possible 16 trigger states...
//
module trigterms (clock, dataIn, timer1_hit, timer2_hit, wrenb, wraddr, din, state, hit);
input clock;
input [31:0] dataIn;
input timer1_hit, timer2_hit;
input wrenb;
input [6:0] wraddr;
input din;
input [3:0] state;	// Current trigger state
output [2:0] hit;	// Hits matching trigger state summing-terms

reg [15:0] wrenb_term;
reg [7:0] wrenb_range_edge;
reg [15:0] wrenb_state;
always @*
begin
  #1;
  wrenb_term = 0;
  wrenb_range_edge = 0;
  wrenb_state = 0;
  casex (wraddr[6:3]) 
    4'b010x : wrenb_term[wraddr[3:0]] = wrenb; 	     // 0x20-0x2F
    4'b0110 : wrenb_range_edge[wraddr[2:0]] = wrenb; // 0x30-0x37
    4'b1xxx : wrenb_state[wraddr[5:2]] = wrenb;      // 0x40-0x7F
  endcase
end

wire [7:0] terma_hit, termb_hit, termc_hit, termd_hit;
wire [7:0] terme_hit, termf_hit, termg_hit, termh_hit;
wire [7:0] termi_hit, termj_hit;
trigterm_32bit terma (dataIn, clock, wrenb_term[0] || wrenb_term[15], din, terma_dout, terma_hit);
trigterm_32bit termb (dataIn, clock, wrenb_term[1] || wrenb_term[15], din, termb_dout, termb_hit);
trigterm_32bit termc (dataIn, clock, wrenb_term[2] || wrenb_term[15], din, termc_dout, termc_hit);
trigterm_32bit termd (dataIn, clock, wrenb_term[3] || wrenb_term[15], din, termd_dout, termd_hit);
trigterm_32bit terme (dataIn, clock, wrenb_term[4] || wrenb_term[15], din, terme_dout, terme_hit);
trigterm_32bit termf (dataIn, clock, wrenb_term[5] || wrenb_term[15], din, termf_dout, termf_hit);
trigterm_32bit termg (dataIn, clock, wrenb_term[6] || wrenb_term[15], din, termg_dout, termg_hit);
trigterm_32bit termh (dataIn, clock, wrenb_term[7] || wrenb_term[15], din, termh_dout, termh_hit);
trigterm_32bit termi (dataIn, clock, wrenb_term[8] || wrenb_term[15], din, termi_dout, termi_hit);
trigterm_32bit termj (dataIn, clock, wrenb_term[9] || wrenb_term[15], din, termj_dout, termj_hit);

trigterm_range range1l (dataIn, clock, wrenb_range_edge[0], din, range1_lower); // lower = datain>target
trigterm_range range1u (dataIn, clock, wrenb_range_edge[1], din, range1_upper); 
trigterm_range range2l (dataIn, clock, wrenb_range_edge[2], din, range2_lower);
trigterm_range range2u (dataIn, clock, wrenb_range_edge[3], din, range2_upper);

wire [31:0] dly_dataIn;
dly_signal #(32) dly_dataIn_reg (clock, dataIn, dly_dataIn);

trigterm_edge edge1 (dataIn, dly_dataIn, clock, wrenb_range_edge[4], din, edge1_hit);
trigterm_edge edge2 (dataIn, dly_dataIn, clock, wrenb_range_edge[5], din, edge2_hit);

wire range1_upper_hit = !range1_upper; // upper>=datain>lower
wire range2_upper_hit = !range2_upper; // upper>=datain>lower

wire [31:0] term_hits;
assign term_hits[31:30] = 0;
assign term_hits[29] = &termj_hit[7:4];
assign term_hits[28] = &termj_hit[3:0];
assign term_hits[27] = edge2_hit;
assign term_hits[26] = edge2_hit;
assign term_hits[25] = &termi_hit[7:4];
assign term_hits[24] = &termi_hit[3:0];
assign term_hits[23] = range2_upper_hit;
assign term_hits[22] = range2_lower;
assign term_hits[21] = &termh_hit[7:4];
assign term_hits[20] = &termh_hit[3:0];
assign term_hits[19] = &termg_hit[7:4];
assign term_hits[18] = &termg_hit[3:0];
assign term_hits[17] = &termf_hit[7:4];
assign term_hits[16] = &termf_hit[3:0];

assign term_hits[15:14] = 0;
assign term_hits[13] = &terme_hit[7:4];
assign term_hits[12] = &terme_hit[3:0];
assign term_hits[11] = edge1_hit;
assign term_hits[10] = edge1_hit;
assign term_hits[9] = &termd_hit[7:4];
assign term_hits[8] = &termd_hit[3:0];
assign term_hits[7] = range1_upper_hit;
assign term_hits[6] = range1_lower;
assign term_hits[5] = &termc_hit[7:4];
assign term_hits[4] = &termc_hit[3:0];
assign term_hits[3] = &termb_hit[7:4];
assign term_hits[2] = &termb_hit[3:0];
assign term_hits[1] = &terma_hit[7:4]; 
assign term_hits[0] = &terma_hit[3:0];

wire [31:0] sampled_term_hits;
dly_signal #(32) sampled_term_hits_reg (clock, term_hits, sampled_term_hits);

wire [31:0] use_term_hits = {
  timer2_hit, timer2_hit, sampled_term_hits[29:16], 
  timer1_hit, timer1_hit, sampled_term_hits[13:0]};

wire [2:0] state_hit[0:15];
trigstate state0 (use_term_hits, clock, wrenb_state[0], wraddr[1:0], din, state_hit[0]);
trigstate state1 (use_term_hits, clock, wrenb_state[1], wraddr[1:0], din, state_hit[1]);
trigstate state2 (use_term_hits, clock, wrenb_state[2], wraddr[1:0], din, state_hit[2]);
trigstate state3 (use_term_hits, clock, wrenb_state[3], wraddr[1:0], din, state_hit[3]);
trigstate state4 (use_term_hits, clock, wrenb_state[4], wraddr[1:0], din, state_hit[4]);
trigstate state5 (use_term_hits, clock, wrenb_state[5], wraddr[1:0], din, state_hit[5]);
trigstate state6 (use_term_hits, clock, wrenb_state[6], wraddr[1:0], din, state_hit[6]);
trigstate state7 (use_term_hits, clock, wrenb_state[7], wraddr[1:0], din, state_hit[7]);
trigstate state8 (use_term_hits, clock, wrenb_state[8], wraddr[1:0], din, state_hit[8]);
trigstate state9 (use_term_hits, clock, wrenb_state[9], wraddr[1:0], din, state_hit[9]);
trigstate stateA (use_term_hits, clock, wrenb_state[10], wraddr[1:0], din, state_hit[10]);
trigstate stateB (use_term_hits, clock, wrenb_state[11], wraddr[1:0], din, state_hit[11]);
trigstate stateC (use_term_hits, clock, wrenb_state[12], wraddr[1:0], din, state_hit[12]);
trigstate stateD (use_term_hits, clock, wrenb_state[13], wraddr[1:0], din, state_hit[13]);
trigstate stateE (use_term_hits, clock, wrenb_state[14], wraddr[1:0], din, state_hit[14]);
trigstate stateF (use_term_hits, clock, wrenb_state[15], wraddr[1:0], din, state_hit[15]);

wire [2:0] hit = state_hit[state];

endmodule



//
// Summing terms for a trigger state. ie:
//   0 : Hit-Term
//   1 : Else-Term
//   2 : Capture-Term
//
// Four cfg chains..
//   Three 256 bit chains for trigterm_64bit's
//   One 240 bit chain for ax/ay & ab sum-terms: 64+64+64+16+16+!6
//
module trigstate (term_hits, clock, wrenb, wraddr, din, hit);
input [31:0] term_hits;
input clock;
input wrenb;
input [1:0] wraddr;
input din;
output [2:0] hit;

reg [3:0] wrenb_sum;
always @*
begin
  wrenb_sum = 0;
  wrenb_sum[wraddr] = wrenb;	
end

trigsum hit_sum (term_hits, clock, wrenb_sum[0], din, hit_term);
trigsum else_sum (term_hits, clock, wrenb_sum[1], din, else_term);
trigsum capture_sum (term_hits, clock, wrenb_sum[2], din, capture_term);

// Sample output of hits...
reg [2:0] hit, next_hit;
always @ (posedge clock) hit = next_hit;
always @* next_hit = {capture_term, else_term, hit_term};

endmodule


//
// Sum trigger terms for one of the hit/else/capture state terms...
// 176 bit serial cfg chain (22 bytes)...
//
module trigsum (term_hits, clock, wrenb, din, hit);
input [31:0] term_hits;
input clock,wrenb,din;
output hit;
wire [7:0] pair_sum;
trigterm_32bit pair (term_hits, clock, wrenb, din, dout_pair, pair_sum);
trigterm_4bit mid0 (pair_sum[3:0], clock, wrenb, dout_pair, dout_mid0, mid0_sum);
trigterm_4bit mid1 (pair_sum[7:4], clock, wrenb, dout_mid0, dout_mid1, mid1_sum);
trigterm_4bit final ({2'h0,mid1_sum,mid0_sum}, clock, wrenb, dout_mid1, dout_final, hit);
endmodule


//
// Mask & compare 32 bits of input data for a trigger term.
// 128 bit serial cfg chain (16 bytes)...
//
module trigterm_32bit (dataIn, clock, wrenb, din, dout, hit);
input [31:0] dataIn;
input clock, wrenb, din;
output dout;
output [7:0] hit;
trigterm_4bit nyb0 (dataIn[3:0], clock, wrenb, din, n0, hit[0]);
trigterm_4bit nyb1 (dataIn[7:4], clock, wrenb, n0, n1, hit[1]);
trigterm_4bit nyb2 (dataIn[11:8], clock, wrenb, n1, n2, hit[2]);
trigterm_4bit nyb3 (dataIn[15:12], clock, wrenb, n2, n3, hit[3]);
trigterm_4bit nyb4 (dataIn[19:16], clock, wrenb, n3, n4, hit[4]);
trigterm_4bit nyb5 (dataIn[23:20], clock, wrenb, n4, n5, hit[5]);
trigterm_4bit nyb6 (dataIn[27:24], clock, wrenb, n5, n6, hit[6]);
trigterm_4bit nyb7 (dataIn[31:28], clock, wrenb, n6, dout, hit[7]);
endmodule


//
// Mask & compare 4 bits of input data.  
// 16 bit serial cfg chain.
//
module trigterm_4bit (addr, clock, wrenb, din, dout, hit);
input [3:0] addr;
input clock, wrenb, din;
output dout, hit;
SRLC16E ram (
  .A0(addr[0]), .A1(addr[1]), .A2(addr[2]), .A3(addr[3]), 
  .CLK(clock), .CE(wrenb), .D(din), .Q15(dout), .Q(hit));
endmodule




//
// A LUT chain for performing magnitude comparisons.  Uses fast-carry
// chain element of CLB's to do form a carry-look-ahead adder.  The value
// being added is encoded directly into the LUT RAM's.
// 512 bits.
//
module trigterm_range (dataIn, clock, wrenb, din, hit);
input [31:0] dataIn;
input clock, wrenb, din;
output hit;
trigterm_range_byte byte0 (dataIn[7:0], clock, wrenb, din, dout0, 1'b1, cout0);
trigterm_range_byte byte1 (dataIn[15:8], clock, wrenb, dout0, dout1, cout0, cout1);
trigterm_range_byte byte2 (dataIn[23:16], clock, wrenb, dout1, dout2, cout1, cout2);
trigterm_range_byte byte3 (dataIn[31:24], clock, wrenb, dout2, dout, cout2, hit);
endmodule


// 128 bits
module trigterm_range_byte (dataIn, clock, wrenb, din, dout, cin, cout);
input [7:0] dataIn;
input clock, wrenb, din, cin;
output dout, cout;
wire [6:0] chain, carry;
trigterm_range_bit bit0 (dataIn[0], clock, wrenb, din, chain[0], cin, carry[0]);
trigterm_range_bit bit1 (dataIn[1], clock, wrenb, chain[0], chain[1], carry[0], carry[1]);
trigterm_range_bit bit2 (dataIn[2], clock, wrenb, chain[1], chain[2], carry[1], carry[2]);
trigterm_range_bit bit3 (dataIn[3], clock, wrenb, chain[2], chain[3], carry[2], carry[3]);
trigterm_range_bit bit4 (dataIn[4], clock, wrenb, chain[3], chain[4], carry[3], carry[4]);
trigterm_range_bit bit5 (dataIn[5], clock, wrenb, chain[4], chain[5], carry[4], carry[5]);
trigterm_range_bit bit6 (dataIn[6], clock, wrenb, chain[5], chain[6], carry[5], carry[6]);
trigterm_range_bit bit7 (dataIn[7], clock, wrenb, chain[6], dout, carry[6], cout);
endmodule


module trigterm_range_bit (dataIn, clock, wrenb, din, dout, cin, cout);
input dataIn;
input clock, wrenb, din, cin;
output dout, cout;
SRLC16E ram0 (
  .A0(dataIn), .A1(1'b0), .A2(1'b0), .A3(1'b0), 
  .CLK(clock), .CE(wrenb), .D(din), .Q15(dout), .Q(hit));

MUXCY MUXCY_inst (.S(hit), .DI(dataIn), .CI(cin), .O(cout));
endmodule




//
// A LUT chain for detecting edges...
// 256 bits
//
module trigterm_edge (dataIn, dly_dataIn, clock, wrenb, din, hit);
input [31:0] dataIn, dly_dataIn;
input clock, wrenb, din;
output hit;

wire [63:0] use_dataIn = {
  dly_dataIn[31:30], dataIn[31:30],
  dly_dataIn[29:28], dataIn[29:28],
  dly_dataIn[27:26], dataIn[27:26],
  dly_dataIn[25:24], dataIn[25:24],
  dly_dataIn[23:22], dataIn[23:22],
  dly_dataIn[21:20], dataIn[21:20],
  dly_dataIn[19:18], dataIn[19:18],
  dly_dataIn[17:16], dataIn[17:16],
  dly_dataIn[15:14], dataIn[15:14],
  dly_dataIn[13:12], dataIn[13:12],
  dly_dataIn[11:10], dataIn[11:10],
  dly_dataIn[9:8], dataIn[9:8],
  dly_dataIn[7:6], dataIn[7:6],
  dly_dataIn[5:4], dataIn[5:4],
  dly_dataIn[3:2], dataIn[3:2],
  dly_dataIn[1:0], dataIn[1:0]};

wire [7:0] lohit, hihit;
trigterm_32bit loword (use_dataIn[31:0], clock, wrenb, din, doutlo, lohit);
trigterm_32bit hiword (use_dataIn[63:32], clock, wrenb, doutlo, dout, hihit);
assign hit = |{hihit,lohit};

endmodule



//
// RAM for storing FSM state info...
//
module ram_dword (clock, addr, wrenb, wrdata, rddata);
input clock;
input [3:0] addr;
input wrenb;
input [31:0] wrdata;
output [31:0] rddata;
ram_byte byte0 (clock, addr, wrenb, wrdata[7:0], rddata[7:0]);
ram_byte byte1 (clock, addr, wrenb, wrdata[15:8], rddata[15:8]);
ram_byte byte2 (clock, addr, wrenb, wrdata[23:16], rddata[23:16]);
ram_byte byte3 (clock, addr, wrenb, wrdata[31:24], rddata[31:24]);
endmodule


module ram_byte (clock, addr, wrenb, wrdata, rddata);
input clock;
input [3:0] addr;
input wrenb;
input [7:0] wrdata;
output [7:0] rddata;
RAM16X4S ram0 (
  .A0(addr[0]), .A1(addr[1]), .A2(addr[2]), .A3(addr[3]), .WCLK(clock), .WE(wrenb), 
  .D0(wrdata[0]), .D1(wrdata[1]), .D2(wrdata[2]), .D3(wrdata[3]),
  .O0(rddata[0]), .O1(rddata[1]), .O2(rddata[2]), .O3(rddata[3]));
RAM16X4S ram1 (
  .A0(addr[0]), .A1(addr[1]), .A2(addr[2]), .A3(addr[3]), .WCLK(clock), .WE(wrenb), 
  .D0(wrdata[4]), .D1(wrdata[5]), .D2(wrdata[6]), .D3(wrdata[7]),
  .O0(rddata[4]), .O1(rddata[5]), .O2(rddata[6]), .O3(rddata[7]));
endmodule


