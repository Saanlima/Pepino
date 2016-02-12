//--------------------------------------------------------------------------------
// sync.vhd
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
// Synchronizes input with clock on rising or falling edge and does some
// optional preprocessing. (Noise filter and demux.)
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis - mygizmos.org
//              Revised to carefully avoid any cross-connections between indata
//              bits from the I/O's until a couple flops have sampled everything.
//              Also moved testcount & numberScheme selects from top level here.
// 

`timescale 1ns/100ps

module sync (clock, indata, intTestMode, numberScheme, filter_mode, demux_mode, falling_edge, outdata);

input clock;
input [31:0] indata;
input intTestMode;
input numberScheme;
input filter_mode;
input demux_mode;
input falling_edge;
output [31:0] outdata;


//
// Sample config flags (for better synthesis)...
//
dly_signal sampled_intTestMode_reg (clock, intTestMode, sampled_intTestMode);
dly_signal sampled_numberScheme_reg (clock, numberScheme, sampled_numberScheme);


//
// Synchronize indata guarantees use of iob ff on spartan 3 (as filter and demux do)
//
wire [31:0] sync_indata, sync_indata180;
ddr_inbuf inbuf (clock, indata, sync_indata, sync_indata180);
 


//
// Internal test mode.  Put aa 8-bit test pattern munged in 
// different ways onto the 32-bit input...
//
reg [7:0] testcount, next_testcount;
initial testcount=0;
always @ (posedge clock) testcount = next_testcount;
always @* begin #1; next_testcount = testcount+1'b1; end

wire [7:0] testcount1 = {
  testcount[0],testcount[1],testcount[2],testcount[3],
  testcount[4],testcount[5],testcount[6],testcount[7]};

wire [7:0] testcount2 = {
  testcount[3],testcount[2],testcount[1],testcount[0],
  testcount[4],testcount[5],testcount[6],testcount[7]};

wire [7:0] testcount3 = {
  testcount[3],testcount[2],testcount[1],testcount[0],
  testcount[7],testcount[6],testcount[5],testcount[4]};

wire [31:0] itm_count;
(* equivalent_register_removal = "no" *)
dly_signal #(32) sampled_testcount_reg (clock, {testcount3,testcount2,testcount1,testcount}, itm_count);

//wire [31:0] itm_indata = (sampled_intTestMode) ? {testcount3,testcount2,testcount1,testcount} : sync_indata;
//wire [31:0] itm_indata180 = (sampled_intTestMode) ? {~testcount3,~testcount2,~testcount1,~testcount} : sync_indata180;
wire [31:0] itm_indata = (sampled_intTestMode) ? itm_count : sync_indata;
wire [31:0] itm_indata180 = (sampled_intTestMode) ? ~itm_count : sync_indata180;



//
// Instantiate demux.  Special case for number scheme mode, since demux upper bits we have
// the final full 32-bit shouldn't be swapped.  So it's preswapped here, to "undo" the final 
// numberscheme on output...
//
wire [31:0] demuxL_indata; 
demux demuxL (
  .clock(clock),
  .indata(itm_indata[15:0]), 
  .indata180(itm_indata180[15:0]), 
  .outdata(demuxL_indata));

wire [31:0] demuxH_indata; 
demux demuxH (
  .clock(clock),
  .indata(itm_indata[31:16]), 
  .indata180(itm_indata180[31:16]), 
  .outdata(demuxH_indata));

wire [31:0] demux_indata = (sampled_numberScheme) ? {demuxH_indata[15:0],demuxH_indata[31:16]} : demuxL_indata;


//
// Instantiate noise filter...
//
wire [31:0] filtered_indata; 
filter filter (
  .clock(clock), 
  .indata(itm_indata),
  .indata180(itm_indata180),
  .outdata(filtered_indata));


//
// Another pipeline step for indata selector to not decrease maximum clock rate...
//
reg [1:0] select, next_select;
reg [31:0] selectdata, next_selectdata;
reg [31:0] outdata;

always @(posedge clock) 
begin
  select = next_select;
  selectdata = next_selectdata;
end

always @*
begin
  #1;
  if (demux_mode)	   // IED - better starting point for synth tools...
    next_select = 2'b10;
  else if (filter_mode)
    next_select = 2'b11;
  else next_select = {1'b0,falling_edge};

  // 4:1 mux...
  case (select) 
    2'b00 : next_selectdata = itm_indata;
    2'b01 : next_selectdata = itm_indata180;
    2'b10 : next_selectdata = demux_indata;
    2'b11 : next_selectdata = filtered_indata;
  endcase

  //
  // Apply number scheme.  ie: swap upper/lower 16 bits as desired...
  //
  outdata = (sampled_numberScheme) ? {selectdata[15:0],selectdata[31:16]} : selectdata;
end
endmodule

