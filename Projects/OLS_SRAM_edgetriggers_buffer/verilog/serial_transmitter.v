//--------------------------------------------------------------------------------
// transmitter.v
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
// Takes 32bit (one sample) and sends it out on the SPI interface
// End of transmission is signalled by taking back the busy flag.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis (IED) - mygizmos.org
// 01/22/2011 - IED - Tweaked to accept meta data write requests.
//
// 09/06/2013 - Magnus Karlsson - Converted to serial communication
//

`timescale 1ns/100ps

module serial_transmitter(
  clock, extReset,
  send, send_data, send_valid,
  writeMeta, meta_data,
  query_id, query_dataIn, dataIn,
  // outputs...
  tx, busy, byteDone);

parameter [31:0] FREQ = 100000000;
parameter [31:0] RATE = 115200;

input clock;
input extReset;

input send;
input [31:0] send_data;
input [3:0] send_valid;
input writeMeta;
input [7:0] meta_data;
input query_id;
input query_dataIn;
input [31:0] dataIn;
output tx;
output busy;
output byteDone;

parameter [1:0]
  TX_IDLE = 2'h0,
  TX_START = 2'h1,
  TX_SEND = 2'h2,
  TX_STOP = 2'h3;

parameter BITLENGTH = FREQ / RATE;  // 100M / 115200 ~= 868

reg [31:0] sampled_send_data, next_sampled_send_data;
reg [3:0] sampled_send_valid, next_sampled_send_valid;
reg [2:0] bits, next_bits;
reg [1:0] bytesel, next_bytesel;

reg busy, next_busy;
reg writeByte; 

reg [1:0] tx_state, next_tx_state;
reg [9:0] tx_count, next_tx_count;
reg [2:0] bitcount, next_bitcount;
reg [7:0] txByte, next_txByte;
reg tx, next_tx;
reg byteDone, next_byteDone;

//
// Byte select mux...   Revised for better synth. - IED
//
reg [7:0] byte;
reg disabled;
always @*
begin
  #1;
  byte = 0;
  disabled = 0;
  case (bytesel)
    2'h0 : begin byte = sampled_send_data[7:0]; disabled = !sampled_send_valid[0]; end
    2'h1 : begin byte = sampled_send_data[15:8]; disabled = !sampled_send_valid[1]; end
    2'h2 : begin byte = sampled_send_data[23:16]; disabled = !sampled_send_valid[2]; end
    2'h3 : begin byte = sampled_send_data[31:24]; disabled = !sampled_send_valid[3]; end
  endcase
end


//
// Transmit UART - MK
//
always @(posedge clock or posedge extReset) 
begin
  if (extReset) begin
    tx_state = TX_IDLE;
    bitcount = 3'b0;
    txByte = 8'b0;
    byteDone = 1'b1;
    tx_count = 10'd0;
    tx = 1'b1;
  end else begin 
    tx_state = next_tx_state;
    bitcount = next_bitcount;
    txByte = next_txByte;
    byteDone = next_byteDone;
    tx_count = next_tx_count;
    tx = next_tx;
  end
end

always @*
begin
  #1;
  next_tx_state = tx_state;
  next_bitcount = bitcount;
  next_txByte = txByte;
  next_byteDone = 1'b1;
  next_tx_count = 0;
  next_tx = tx;

  case(tx_state)
    TX_IDLE: begin
      next_tx = 1'b1;
      next_bitcount = 0;
      if ((writeByte & !disabled) | writeMeta) begin
        next_tx_state = TX_START;
        next_byteDone = 0;
        next_txByte = writeMeta ? meta_data : byte;
        next_tx = 1'b0;
      end
    end
    TX_START: begin
      next_tx_count = tx_count + 1'b1;
      next_byteDone = 0;
      if (tx_count == BITLENGTH - 1) begin
        next_tx_state = TX_SEND;
        next_tx_count = 0;
        next_tx = txByte[0];
        next_txByte = {1'b0, txByte[7:1]};
      end
    end
    TX_SEND: begin
      next_tx_count = tx_count + 1'b1;
      next_byteDone = 0;
      if (tx_count == BITLENGTH - 1) begin
        next_tx_count = 0;
        next_bitcount = bitcount + 1'b1;
        if (bitcount == 3'd7) begin
          next_tx_state = TX_STOP;
          next_tx = 1'b1;
        end else begin
          next_tx = txByte[0];
          next_txByte = {1'b0, txByte[7:1]};
        end
      end
    end
    TX_STOP: begin
      next_tx_count = tx_count + 1'b1;
      next_byteDone = 0;
      if (tx_count == BITLENGTH - 1) begin
        next_tx_count = 0;
        next_bitcount = bitcount + 1'b1;
        if (bitcount == 3'd1) begin
          next_tx_state = TX_IDLE;
          next_byteDone = 1'b1;
        end
      end
    end
  endcase
end



//
// Control FSM for sending 32 bit words out serial interface...
//
parameter [1:0] INIT = 0, IDLE = 1, SEND = 2, POLL = 3;
reg [1:0] state, next_state;

initial state = INIT;
always @(posedge clock or posedge extReset) 
begin
  if (extReset) 
    begin
      state = INIT;
      sampled_send_data = 32'h0;
      sampled_send_valid = 4'h0;
      bytesel = 3'h0;
      busy = 1'b0;
    end 
  else 
    begin
      state = next_state;
      sampled_send_data = next_sampled_send_data;
      sampled_send_valid = next_sampled_send_valid;
      bytesel = next_bytesel;
      busy = next_busy;
    end
end

always @*
begin
  #1;
  next_state = state;
  next_sampled_send_data = sampled_send_data;
  next_sampled_send_valid = sampled_send_valid;
  next_bytesel = bytesel;

  next_busy = (state != IDLE) || send || !byteDone;
  writeByte = 1'b0;

  case (state) // when write is '1', data will be available with next cycle
    INIT :
      begin
        next_sampled_send_data = 32'h0;
        next_sampled_send_valid = 4'hF;
        next_bytesel = 3'h0;
        next_busy = 1'b0;
        next_state = IDLE;
      end

    IDLE : 
      begin
        next_sampled_send_data = send_data;
        next_sampled_send_valid = send_valid;
        next_bytesel = 0;

        if (send) 
          next_state = SEND;
        else if (query_id) // output dword containing "SLA1" signature
          begin
            next_sampled_send_data = 32'h534c4131; // "SLA1"
            next_sampled_send_valid = 4'hF;
            next_state = SEND;
          end
        else if (query_dataIn)
          begin
            next_sampled_send_data = dataIn;
            next_sampled_send_valid = 4'hF;
            next_state = SEND;
          end
      end

    SEND : // output dword send by controller...
      begin
        writeByte = 1'b1;
        next_bytesel = bytesel + 1'b1;
        next_state = POLL;
      end

    POLL : 
      begin
        if (byteDone)
          next_state = (~|bytesel) ? IDLE : SEND;
      end

    default : next_state = INIT;
  endcase
end
endmodule

