//--------------------------------------------------------------------------------
// Logic_Sniffer.vhd
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
// Logic Analyzer top level module. It connects the core with the hardware
// dependend IO modules and defines all inputs and outputs that represent
// phyisical pins of the fpga.
//
// It defines two constants FREQ and RATE. The first is the clock frequency 
// used for receiver and transmitter for generating the proper baud rate.
// The second defines the speed at which to operate the serial port.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis (IED) - mygizmos.org
//

`timescale 1ns/100ps

//`define COMM_TYPE_SPI 1		// comment out for UART mode

module Logic_Sniffer(
  bf_clock,
  extClockIn,
  extTriggerIn,
  ch1_dir,
  ch2_dir,
  ch1_en,
  ch2_en,
  indata,
`ifdef COMM_TYPE_SPI
  miso, mosi, sclk, cs,
`else
  rx, tx,
`endif
  dataReady,
  armLED,
  triggerLED,
  breathLED,
  sramAddr,
  sramData,
  _sramCE0,
  _sramCE1,
  _sramOE,
  _sramWE,
  _sramDS);

input bf_clock;
input extClockIn;
input extTriggerIn;
output ch1_dir;
output ch2_dir;
output ch1_en;
output ch2_en;
inout [15:0] indata;
output dataReady;
output armLED;
output triggerLED;
output breathLED;

`ifdef COMM_TYPE_SPI
  output miso;
  input mosi;
  input sclk;
  input cs;
`else
  input rx;
  output tx;
`endif

  output [18:0] sramAddr;
  inout [31:0] sramData;
  output _sramCE0;
  output _sramCE1;
  output _sramOE;
  output _sramWE;
  output [3:0] _sramDS;


parameter FREQ = 100000000;  // limited to 100M by onboard SRAM
parameter RATE = 921600;  // maximum & base rate

wire extReset = 1'b0;
wire [39:0] cmd;
wire [31:0] sram_wrdata;
wire [31:0] sram_rddata; 
wire [3:0] sram_rdvalid;
wire [31:0] stableInput;

wire [7:0] opcode;
wire [31:0] config_data; 
assign {config_data,opcode} = cmd;


// Instantiate PLL...
pll_wrapper pll_wrapper ( .clkin(bf_clock), .clk0(clock));


// Output dataReady to PIC (so it'll enable our SPI CS#)...
dly_signal dataReady_reg (clock, busy, dataReady);


// breathing LED
reg [26:0] PMW_counter;
reg [5:0] PWM_adj;
reg [6:0] PWM_width;
reg breathLED;
always @(posedge clock or posedge extReset) begin
  if(extReset) begin
    PMW_counter <= 27'b0;
    PWM_width <= 7'b0;
    breathLED <= 1'b0;
    PWM_adj <= 6'b0;
  end else begin
    PMW_counter <= PMW_counter + 1'b1;
    PWM_width <= PWM_width[5:0] + PWM_adj;
    if(PMW_counter[26])
      PWM_adj <= PMW_counter[25:20];
    else 
      PWM_adj <= ~ PMW_counter[25:20];
    breathLED <= PWM_width[6];
  end
end

//
// Configure the probe pins...
//
reg [15:0] test_counter;
always @ (posedge clock or posedge extReset) begin
  if (extReset)
    test_counter <= 0;
  else
    test_counter <= test_counter + 1'b1;
end

wire [15:0] test_pattern = test_counter;

outbuf io_indata15 (.pad(indata[15]), .clk(clock), .outsig(test_pattern[15]), .oe(extTestMode));
outbuf io_indata14 (.pad(indata[14]), .clk(clock), .outsig(test_pattern[14]), .oe(extTestMode));
outbuf io_indata13 (.pad(indata[13]), .clk(clock), .outsig(test_pattern[13]), .oe(extTestMode));
outbuf io_indata12 (.pad(indata[12]), .clk(clock), .outsig(test_pattern[12]), .oe(extTestMode));
outbuf io_indata11 (.pad(indata[11]), .clk(clock), .outsig(test_pattern[11]), .oe(extTestMode));
outbuf io_indata10 (.pad(indata[10]), .clk(clock), .outsig(test_pattern[10]), .oe(extTestMode));
outbuf io_indata9 (.pad(indata[9]), .clk(clock), .outsig(test_pattern[9]), .oe(extTestMode));
outbuf io_indata8 (.pad(indata[8]), .clk(clock), .outsig(test_pattern[8]), .oe(extTestMode));

// external I/O buffer control pins
assign ch1_dir = 1'b0; // always input
assign ch2_dir = extTestMode; // output in external test mode

assign ch1_en = 1'b0; // always enabled
assign ch2_en = 1'b0; // always enabled

//
// Instantiate serial interface....
//
`ifdef COMM_TYPE_SPI

spi_slave spi_slave (
  .clock(clock), 
  .extReset(extReset),
  .sclk(sclk), 
  .cs(cs), 
  .mosi(mosi),
  .dataIn(stableInput),
  .send(send), 
  .send_data(sram_rddata), 
  .send_valid(sram_rdvalid),
  // outputs...
  .cmd(cmd), .execute(execute), 
  .busy(busy), .miso(miso));

`else 

serial #(.FREQ(FREQ), .RATE(RATE)) serial (
  .clock(clock), 
  .extReset(extReset),
  .rx(rx),
  .dataIn(stableInput),
  .send(send), 
  .send_data(sram_rddata), 
  .send_valid(sram_rdvalid),
  // outputs...
  .cmd(cmd), .execute(execute), 
  .busy(busy), .tx(tx));
 
`endif 


//
// Instantiate core...
//
core core (
  .clock(clock),
  .extReset(extReset),
  .extClock(extClockIn),
  .extTriggerIn(extTriggerIn),
  .opcode(opcode),
  .config_data(config_data),
  .execute(execute),
  .indata({16'd0, indata}),
  .outputBusy(busy),
  // outputs...
  .sampleReady50(),
  .stableInput(stableInput),
  .outputSend(send),
  .memoryWrData(sram_wrdata),
  .memoryRead(read),
  .memoryWrite(write),
  .memoryLastWrite(lastwrite),
  .extTriggerOut(),
  .extClockOut(), 
  .armLED(armLED),
  .triggerLED(triggerLED),
  .wrFlags(wrFlags),
  .extTestMode(extTestMode));


//
// Instantiate the memory...
//
sram_interface sram_interface (
  .clk(clock),
  .wrFlags(wrFlags), 
  .config_data(config_data[5:2]),
  .write(write), .lastwrite(lastwrite), .read(read),
  .wrdata(sram_wrdata),
  // outputs...
  .rddata(sram_rddata),
  .rdvalid(sram_rdvalid),
  // SRAM
  .sramAddr(sramAddr),
  .sramData(sramData),
  ._sramCE(_sramCE),
  ._sramOE(_sramOE),
  ._sramWE(_sramWE),
  ._sramDS(_sramDS));

assign _sramCE0 = _sramCE;
assign _sramCE1 = _sramCE;

endmodule

