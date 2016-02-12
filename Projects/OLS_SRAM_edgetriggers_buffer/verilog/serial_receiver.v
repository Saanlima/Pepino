//--------------------------------------------------------------------------------
// spi_receiver.v
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
// Receives commands from the SPI interface. The first byte is the commands
// opcode, the following (optional) four byte are the command data.
// Commands that do not have the highest bit in their opcode set are
// considered short commands without data (1 byte long). All other commands are
// long commands which are 5 bytes long.
//
// After a full command has been received it will be kept available for 10 cycles
// on the op and data outputs. A valid command can be detected by checking if the
// execute output is set. After 10 cycles the registers will be cleared
// automatically and the receiver waits for new data from the serial port.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis (IED) - mygizmos.org
//
// 09/06/2013 - Magnus Karlsson - Converted to serial communication
//

`timescale 1ns/100ps

module serial_receiver(
  clock, extReset, 
  rx, transmitting,
  // outputs...
  op, data, execute);

parameter [31:0] FREQ = 100000000;
parameter [31:0] RATE = 115200;

input clock;
input extReset;
input rx;
input transmitting;
output [7:0] op;
output [31:0] data;
output execute;

parameter 
  READOPCODE = 1'h0,
  READLONG = 1'h1;

parameter [1:0]
  RX_IDLE = 2'h0,
  RX_START = 2'h1,
  RX_RECEIVE = 2'h2,
  RX_STOP = 2'h3;

parameter BITLENGTH = FREQ / RATE;  // 100M / 115200 ~= 868

reg state, next_state;                        // receiver state
reg [1:0] bytecount, next_bytecount;        // count rxed bytes of current command
reg [7:0] opcode, next_opcode;                // opcode byte
reg [31:0] databuf, next_databuf;        // data dword
reg execute, next_execute;

reg [1:0] rx_state, next_rx_state;
reg [9:0] rx_count, next_rx_count;
reg [2:0] bitcount, next_bitcount;
reg [7:0] rxByte, next_rxByte;
reg byteready, next_byteready;

assign op = opcode;
assign data = databuf;


//
// Receive UART - MK
//
always @(posedge clock or posedge extReset) 
begin
  if (extReset) begin
    rx_state = RX_IDLE;
    bitcount = 3'b0;
    rxByte = 8'b0;
    byteready = 1'b0;
    rx_count = 10'd0;
  end else begin 
    rx_state = next_rx_state;
    bitcount = next_bitcount;
    rxByte = next_rxByte;
    byteready = next_byteready;
    rx_count = next_rx_count;
  end
end

always @*
begin
  #1;
  next_rx_state = rx_state;
  next_bitcount = bitcount;
  next_rxByte = rxByte;
  next_byteready = 1'b0;
  next_rx_count = 0;

  case(rx_state)
    RX_IDLE: begin
      if (!rx & !transmitting) begin
        next_rx_state = RX_START;
      end
    end
    RX_START: begin
      if (!rx) begin
        next_rx_count = rx_count + 1'b1;
        if (rx_count == BITLENGTH/2 - 1) begin
          next_rx_state = RX_RECEIVE;
          next_rx_count = 0;
          next_rxByte = 8'b0;
        end
      end else begin
        next_rx_state = RX_IDLE;
      end
    end
    RX_RECEIVE: begin
      next_rx_count = rx_count + 1'b1;
      if (rx_count == BITLENGTH - 1) begin
        next_rx_count = 0;
        next_bitcount = bitcount + 1'b1;
        next_rxByte = {rx, rxByte[7:1]};
        if (bitcount == 3'd7)
          next_rx_state = RX_STOP;
      end
    end
    RX_STOP: begin
      next_rx_count = rx_count + 1'b1;
      if (rx_count == BITLENGTH - 1) begin
        next_rx_count = 0;
        next_byteready = 1'b1;
        next_rx_state = RX_IDLE;
      end
    end
  endcase
end

//
// Command tracking...
//
always @(posedge clock or posedge extReset) 
begin
  if (extReset)
    state = READOPCODE;
  else state = next_state;
end

initial databuf = 0;
always @(posedge clock) 
begin
  bytecount = next_bytecount;
  opcode = next_opcode;
  databuf = next_databuf;
  execute = next_execute;
end

always @*
begin
  #1;
  next_state = state;
  next_bytecount = bytecount;
  next_opcode = opcode;
  next_databuf = databuf;
  next_execute = 1'b0;
  
  case (state)
    READOPCODE : // receive byte
      begin
        next_bytecount = 0;
        if (byteready)
          begin
            next_opcode = rxByte;
            if (rxByte[7])
              next_state = READLONG;
            else // short command
              begin
                next_execute = 1'b1;
                  next_state = READOPCODE;
              end
          end
      end

    READLONG : // receive 4 word parameter
      begin
        if (byteready)
          begin
            next_bytecount = bytecount + 1'b1;
            next_databuf = {rxByte,databuf[31:8]};
            if (&bytecount) // execute long command
              begin
                next_execute = 1'b1;
                  next_state = READOPCODE;
              end
          end
      end
  endcase
end
endmodule

