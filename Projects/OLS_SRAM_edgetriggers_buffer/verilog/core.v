//--------------------------------------------------------------------------------
// core.vhd
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
// The core contains all "platform independent" modules and provides a
// simple interface to those components. The core makes the analyzer
// memory type and computer interface independent.
//
// This module also provides a better target for test benches as commands can
// be sent to the core easily.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis - mygizmos.org
// 
// 05/21/2014 - Magnus Karlsson - Added edge trigger to basic trigger module
//

`timescale 1ns/100ps
//`define HEARTBEAT
//`define SLOW_EXTCLK

module core(
  clock, extReset, 
  extClock, extTriggerIn, 
  opcode, config_data, execute, indata, outputBusy, 
  // outputs...
  sampleReady50, outputSend, stableInput,
  memoryWrData, memoryRead, memoryWrite, memoryLastWrite,
  extTriggerOut, extClockOut, armLED, 
  triggerLED, wrFlags, extTestMode);

parameter [31:0] MEMORY_DEPTH=6;

input clock;
input extReset;			// External reset
input [7:0] opcode;		// Configuration command from serial/SPI interface
input [31:0] config_data;
input execute;			// opcode & config_data valid
input [31:0] indata;		// Input sample data
input extClock;
input outputBusy;
input extTriggerIn;

output sampleReady50;
output outputSend;
output [31:0] stableInput;
output [31:0] memoryWrData;
output memoryRead;
output memoryWrite;
output memoryLastWrite;
output extTriggerOut;
output extClockOut;
output armLED;
output triggerLED;
output wrFlags;
output extTestMode;


//
// Interconnect...
//
wire [31:0] syncedInput;

wire [3:0] wrtrigmask; 
wire [3:0] wrtrigval; 
wire [3:0] wrtrigcfg;
wire [3:0] wrtrigedge;
wire wrDivider; 
wire wrsize; 
wire wrfwd;
wire wrbwd;

wire sample_valid;
wire [31:0] sample_data; 

wire dly_sample_valid;
wire [31:0] dly_sample_data;

wire aligned_data_valid;
wire [31:0] aligned_data;

wire rle_data_valid; 
wire [31:0] rle_data;

wire arm_basic, arm_adv;
wire arm = arm_basic;// | arm_adv;

wire sampleClock; 


//
// Generate external clock reference...
//
`ifdef SLOW_EXTCLK

reg [1:0] scount, next_scount;
assign extClockOut = scount[1];
initial scount=0;
always @ (posedge sampleClock)
begin
  scount = next_scount;
end
always @*
begin
  next_scount = scount+1'b1;
end

`else

wire extClockOut = sampleClock;

`endif


//
// Reset...
//
wire resetCmd;
wire reset = extReset | resetCmd;

reset_sync reset_sync_core (clock, reset, reset_core); 
reset_sync reset_sync_sample (sampleClock, reset_core, reset_sample);


//
// Decode flags register...
//
wire [31:0] flags_reg;
wire demux_mode = flags_reg[0];                    // DDR sample the input data
wire filter_mode = flags_reg[1];                   // Apply half-clock glitch noise filter to input data
wire [3:0] disabledGroups = flags_reg[5:2];        // Which channel groups should -not- be captured.
wire extClock_mode = flags_reg[6];                 // Use external clock for sampling.
wire falling_edge = flags_reg[7];                  // Capture on falling edge of sample clock.
wire rleEnable = flags_reg[8];                     // RLE compress samples
wire numberScheme = flags_reg[9];                  // Swap upper/lower 16 bits
wire extTestMode = flags_reg[10] && !numberScheme; // Generate external test pattern on upper 16 bits of indata
wire intTestMode = flags_reg[11];                  // Sample internal test pattern instead of indata[31:0]
wire [1:0] rle_mode = flags_reg[15:14];            // Change how RLE logic issues <value> & <counts>


//
// Sample external trigger signals...
//
wire run_basic, run_adv, run; 
dly_signal extTriggerIn_reg (clock, extTriggerIn, sampled_extTriggerIn);
dly_signal extTriggerOut_reg (clock, run, extTriggerOut);

assign run = sampled_extTriggerIn | run_basic;// | run_adv;



//
// Pipistrello LEDs are connected to GND so a logic 1 turns the LED on.
//
reg armLED, next_armLED;
reg triggerLED, next_triggerLED;

`ifdef HEARTBEAT
reg [31:0] hcount, next_hcount;
initial hcount=0;
always @ (posedge clock)
begin
  hcount = next_hcount;
end
`endif

always @(posedge clock or posedge extReset) 
begin
  if (extReset) begin
    triggerLED = 0;
  end else begin
    triggerLED = next_triggerLED;
  end
end

always @(posedge clock or posedge reset) 
begin
  if (reset) begin
    armLED = 0;
  end else begin
    armLED = next_armLED;
  end
end

always @*
begin
  #1;
  next_armLED = armLED;
  next_triggerLED = triggerLED;
  if (arm) 
    begin
      next_armLED = 1'b1;
      next_triggerLED = 1'b0;
    end
  else if (run) 
    begin
      next_armLED = 1'b0;
      next_triggerLED = 1'b1;
    end

`ifdef HEARTBEAT
  next_hcount = (~|hcount) ? 100000000 : (hcount-1'b1);
  next_armLED = armLED;
  if (~|hcount) next_armLED = !armLED;
`endif
end


//
// Select between internal and external sampling clock...
//
BUFGMUX BUFGMUX_intex(
  .O(sampleClock), // Clock MUX output
  .I0(clock),      // Clock0 input
  .I1(extClock),   // Clock1 input
  .S(extClock_mode));


//
// Decode commands & config registers...
//
decoder decoder(
  .clock(clock),
  .execute(execute),
  .opcode(opcode),
  // outputs...
  .wrtrigmask(wrtrigmask),
  .wrtrigval(wrtrigval),
  .wrtrigcfg(wrtrigcfg),
  .wrtrigedge(wrtrigedge),
  .wrspeed(wrDivider),
  .wrsize(wrsize),
  .wrfwd(wrfwd),
  .wrbwd(wrbwd),
  .wrFlags(wrFlags),
  .wrTrigSelect(wrTrigSelect),
  .wrTrigChain(wrTrigChain),
  .finish_now(finish_now),
  .arm_basic(arm_basic),
  .arm_adv(arm_adv),
  .resetCmd(resetCmd));


//
// Configuration flags register...
//
flags flags(
  .clock(clock),
  .wrFlags(wrFlags),
  .config_data(config_data),
  .finish_now(finish_now),
  // outputs...
  .flags_reg(flags_reg));


//
// Capture input relative to sampleClock...
//
sync sync(
  .clock(sampleClock),
  .indata(indata),
  .intTestMode(intTestMode),
  .numberScheme(numberScheme),
  .filter_mode(filter_mode),
  .demux_mode(demux_mode),
  .falling_edge(falling_edge),
  // outputs...
  .outdata(syncedInput));


//
// Transfer from input clock (whatever it may be) to the core clock 
// (used for everything else, including RLE counts)...
//
async_fifo async_fifo(
  .wrclk(sampleClock), .wrreset(reset_sample),
  .rdclk(clock), .rdreset(reset_core),
  .space_avail(), .wrenb(1'b1), .wrdata(syncedInput),
  .read_req(1'b1), .data_avail(), 
  .data_valid(stableValid), .data_out(stableInput));


//
// Capture data at programmed intervals...
//
sampler sampler(
  .clock(clock),
  .extClock_mode(extClock_mode),
  .wrDivider(wrDivider),
  .config_data(config_data[23:0]),
  .validIn(stableValid),
  .dataIn(stableInput),
  // outputs...
  .validOut(sample_valid),
  .dataOut(sample_data),
  .ready50(sampleReady50));


//
// Evaluate standard triggers...
//
trigger trigger(
  .clock(clock),
  .reset(reset_core),
  .validIn(sample_valid),
  .dataIn(sample_data),
  .wrMask(wrtrigmask),
  .wrValue(wrtrigval),
  .wrConfig(wrtrigcfg),
  .wrEdge(wrtrigedge),
  .config_data(config_data),
  .arm(arm_basic),
  .demux_mode(demux_mode),
  // outputs...
  .run(run_basic),
  .capture(capture_basic));

/*
//
// Evaluate advanced triggers...
//
trigger_adv trigger_adv(
  .clock(clock),
  .reset(reset_core),
  .validIn(sample_valid),
  .dataIn(sample_data),
  .wrSelect(wrTrigSelect),
  .wrChain(wrTrigChain),
  .config_data(config_data),
  .arm(arm_adv),
  .finish_now(finish_now),
  // outputs...
  .run(run_adv),
  .capture(capture_adv));
*/
wire capture = capture_basic;// || capture_adv;


//
// Delay samples so they're in phase with trigger "capture" outputs.
//
delay_fifo delay_fifo (
  .clock(clock),
  .validIn(sample_valid),
  .dataIn(sample_data),
  // outputs
  .validOut(dly_sample_valid),
  .dataOut(dly_sample_data));
//defparam delay_fifo.DELAY = 3; // 3 clks to match advanced trigger
defparam delay_fifo.DELAY = 2;


//
// Align data so gaps from disabled groups removed...
//
data_align data_align (
  .clock(clock),
  .disabledGroups(disabledGroups),
  .validIn(dly_sample_valid && capture),
  .dataIn(dly_sample_data),
  // outputs...
  .validOut(aligned_data_valid),
  .dataOut(aligned_data));


//
// Detect duplicate data & insert RLE counts (if enabled)... 
// Requires client software support to decode.
//
rle_enc rle_enc (
  .clock(clock),
  .reset(reset_core),
  .enable(rleEnable),
  .arm(arm),
  .rle_mode(rle_mode),
  .demux_mode(demux_mode),
  .disabledGroups(disabledGroups),
  .validIn(aligned_data_valid),
  .dataIn(aligned_data),
  // outputs...
  .validOut(rle_data_valid),
  .dataOut(rle_data));


//
// Delay run (trigger) pulse to complensate for 
// data_align & rle_enc delay...
//
pipeline_stall dly_arm_reg (
  .clk(clock), 
  .reset(reset_core), 
  .datain(arm), 
  .dataout(dly_arm));
defparam dly_arm_reg.DELAY = 2;

pipeline_stall dly_run_reg (
  .clk(clock), 
  .reset(reset_core), 
  .datain(run), 
  .dataout(dly_run));
defparam dly_run_reg.DELAY = 1;


//
// The brain's...  mmm... brains...
//
controller controller(
  .clock(clock),
  .reset(reset_core),
  .run(dly_run),
  .wrSize(wrsize),
  .wrFwd(wrfwd),
  .wrBwd(wrbwd),
  .config_data(config_data),
  .validIn(rle_data_valid),
  .dataIn(rle_data),
  .arm(dly_arm),
  .busy(outputBusy),
  // outputs...
  .send(outputSend),
  .memoryWrData(memoryWrData),
  .memoryRead(memoryRead),
  .memoryWrite(memoryWrite),
  .memoryLastWrite(memoryLastWrite));

endmodule

