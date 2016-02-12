//--------------------------------------------------------------------------------
//
// sram_interface.v
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
// Writes data to SRAM incrementally, fully filling a 32bit word before
// moving onto the next one.   On reads, pulls data back out in reverse
// order (to maintain SUMP client compatability).  But really, backwards?!!?
//
//--------------------------------------------------------------------------------
//

`define MAX_ADDRESS 256*1024-1  // 256K x 32
`define MAX_INDEX 17  // 17:0 = 256K

`timescale 1ns/100ps

module sram_interface(
  clk, wrFlags, config_data,
  write, lastwrite, 
  read, wrdata, 
  // outputs...
  rddata, rdvalid,
  // SRAM
  sramAddr,
  sramData,
  _sramCE,
  _sramOE,
  _sramWE,
  _sramDS);

input clk;
input wrFlags;
input [3:0] config_data;
input read, write, lastwrite;
input [31:0] wrdata;
output [31:0] rddata;
output [3:0] rdvalid;

output [18:0] sramAddr;
inout [31:0] sramData;
output _sramCE;
output _sramOE;
output _sramWE;
output [3:0] _sramDS;


//
// Interconnect...
//
wire [31:0] wrdata;
wire [31:0] ram_dataout;


//
// Registers...
//
reg init, next_init;
reg [1:0] mode, next_mode;
reg [3:0] validmask, next_validmask;

reg [3:0] clkenb, next_clkenb;
reg [`MAX_INDEX:0] address, next_address;
reg [3:0] rdvalid, next_rdvalid;

wire maxaddr = (address == `MAX_ADDRESS);
wire addrzero = ~|address;


//
// Control logic...
//
initial 
begin
  init = 1'b0;
  mode = 2'b00;
  validmask = 4'hF;
  clkenb = 4'b1111;
  address = 0;
  rdvalid = 1'b0;
end
always @ (posedge clk)
begin
  init = next_init;
  mode = next_mode;
  validmask = next_validmask;
  clkenb = next_clkenb;
  address = next_address;
  rdvalid = next_rdvalid;
end


always @*
begin
  next_init = 1'b0;
  next_mode = mode;
  next_validmask = validmask;

  next_clkenb = clkenb;
  next_address = address;
  next_rdvalid = clkenb & validmask;

  //
  // Setup architecture of RAM based on which groups are enabled/disabled.
  //   If any one group is selected, 24k samples are possible.
  //   If any two groups are selected, 12k samples are possible.
  //   If three or four groups are selected, only 6k samples are possible.
  //
  if (wrFlags)
    begin
      next_init = 1'b1;
      next_mode = 0; // 32 bit wide, 6k deep  +  24 bit wide, 6k deep
      case (config_data)
        4'b1100, 4'b0011, 4'b0110, 4'b1001, 4'b1010, 4'b0101 : next_mode = 2'b10; // 16 bit wide
        4'b1110, 4'b1101, 4'b1011, 4'b0111 : next_mode = 2'b01; // 8 bit wide
      endcase

      // The clkenb register normally indicates which bytes are valid during a read.
      // However in 24-bit mode, all 32-bits of BRAM are being used.  Thus we need to
      // tweak things a bit.  Since data is aligned (see data_align.v), all we need 
      // do is ignore the MSB here...
      next_validmask = 4'hF;
      case (config_data)
        4'b0001, 4'b0010, 4'b0100, 4'b1000 : next_validmask = 4'h7;
      endcase
    end

  //
  // Handle writes & reads.  Fill a given line of RAM completely before
  // moving onward.   
  //
  // This differs from the original SUMP storage which wrapped around 
  // before changing clock enables.  Client sees no difference. However, 
  // it'll eventally allow easier streaming of data to the client...
  //
  casex ({write && !lastwrite, read})
    2'b1x : // inc clkenb/address on all but last write (to avoid first read being bogus)...
      begin
        next_clkenb = 4'b1111;
        casex (mode[1:0])
          2'bx1 : next_clkenb = {clkenb[2:0],clkenb[3]};   // 8 bit
          2'b1x : next_clkenb = {clkenb[1:0],clkenb[3:2]}; // 16 bit
        endcase
        if (clkenb[3]) next_address = (maxaddr) ? 0 : address+1'b1;
      end

    2'bx1 : 
      begin
        next_clkenb = 4'b1111;
        casex (mode[1:0])
          2'bx1 : next_clkenb = {clkenb[0],clkenb[3:1]};   // 8 bit
          2'b1x : next_clkenb = {clkenb[1:0],clkenb[3:2]}; // 16 bit
        endcase
        if (clkenb[0]) next_address = (addrzero) ? `MAX_ADDRESS : address-1'b1;
      end
  endcase

  //
  // Reset clock enables & ram address...
  //
  if (init) 
    begin
      next_clkenb = 4'b1111; 
      casex (mode[1:0])
        2'bx1 : next_clkenb = 4'b0001; // 1 byte writes
        2'b1x : next_clkenb = 4'b0011; // 2 byte writes
      endcase
      next_address = 0;
    end
end


//
// Prepare RAM input data.  Present write data to all four lanes of RAM.
//
reg [31:0] ram_datain;
always @*
begin
  ram_datain = wrdata;
  casex (mode[1:0])
    2'bx1 : ram_datain[31:0] = {wrdata[7:0],wrdata[7:0],wrdata[7:0],wrdata[7:0]}; // 8 bit memory
    2'b1x : ram_datain[31:0] = {wrdata[15:0],wrdata[15:0]}; // 16 bit memory
  endcase
end

reg [`MAX_INDEX:0] ram_addr;
reg [31:0] ram_wrdata, ram_data;
reg ram_write, ram_read;
reg [1:0] state, next_state;
reg ram_OE, next_ram_OE;
reg ram_WE, next_ram_WE;
reg ram_CE, next_ram_CE;
reg read_data_valid, next_read_data_valid;
reg _sramWE;


always @ (posedge clk) begin
  if (write & clkenb[0])
    ram_wrdata[7:0] <= ram_datain[7:0];
  if (write & clkenb[1])
    ram_wrdata[15:8] <= ram_datain[15:8];
  if (write & clkenb[2])
    ram_wrdata[23:16] <= ram_datain[23:16];
  if (write & clkenb[3])
    ram_wrdata[31:24] <= ram_datain[31:24];
  if ((write & clkenb[3]) | ram_read)
    ram_addr <= address;
  ram_write <= write & clkenb[3];
  ram_read <= read & clkenb[0];
  if (ram_write)
    ram_data <= ram_wrdata;
  else if (read_data_valid)
    ram_data <= sramData;
end

always @ (posedge clk) begin
  if (init) begin
    state <= 2'b00;
    ram_OE <= 1'b0;
    ram_WE <= 1'b0;
    ram_CE <= 1'b0;
    read_data_valid <= 1'b0;
  end else begin
    state <= next_state;
    ram_OE <= next_ram_OE;
    ram_WE <= next_ram_WE;
    ram_CE <= next_ram_CE;
    read_data_valid <= next_read_data_valid;
  end
end

always @ * begin
  next_state = state;
  next_ram_OE = 1'b0;
  next_ram_WE = 1'b0;
  next_ram_CE = 1'b0;
  next_read_data_valid = 1'b0;
  case (state)
  2'b00: begin
    if (ram_write) begin
      next_ram_WE = 1'b1;
      next_ram_CE = 1'b1;
      next_state = 2'b01;
    end else if (ram_read) begin
      next_ram_OE = 1'b1;
      next_ram_CE = 1'b1;
      next_state = 2'b10;
    end
  end
  2'b01: begin
    next_ram_CE = 1'b1;
    next_state = 2'b00;
  end
  2'b10: begin
    next_ram_OE = 1'b1;
    next_ram_CE = 1'b1;
    next_read_data_valid = 1'b1;
    next_state = 2'b00;
  end
  endcase
end

always @ (negedge clk)
  _sramWE <= ~ram_WE;

assign _sramOE = ~ram_OE;
assign _sramCE = ~ram_CE;
assign _sramDS = 4'b0000;
assign sramData = ram_OE ? 32'hZZZZZZZZ : ram_data;
assign sramAddr = {1'b0, ram_addr};

assign rddata = ram_data;

endmodule

