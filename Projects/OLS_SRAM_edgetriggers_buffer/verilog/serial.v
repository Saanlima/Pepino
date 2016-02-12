//--------------------------------------------------------------------------------
// spi_slave.v
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
// spi_slave
//
//--------------------------------------------------------------------------------
//
// 01/22/2011 - Ian Davis - Added meta data generator.
//
// 09/06/2013 - Magnus Karlsson - Converted to serial communication
//

`timescale 1ns/100ps

module serial(
  clock, extReset, 
  rx, dataIn,
  send, send_data, send_valid,
  // outputs
  cmd, execute, busy, tx);

parameter [31:0] FREQ = 100000000;
parameter [31:0] RATE = 115200;

input clock;
input extReset;
input send;
input [31:0] send_data;
input [3:0] send_valid;
input [31:0] dataIn;
input rx;

output [39:0] cmd;
output execute;
output busy;
output tx;

wire [39:0] cmd;
wire execute;
wire busy;
wire tx;


//
// Registers...
//
reg query_id, next_query_id; 
reg query_metadata, next_query_metadata;
reg query_dataIn, next_query_dataIn; 
reg dly_execute, next_dly_execute; 

wire [7:0] opcode;
wire [31:0] opdata;
assign cmd = {opdata,opcode};


//
// Synchronize inputs...
//
full_synchronizer rx_sync (clock, extReset, rx, sync_rx);


//
// Instantaite the meta data generator...
//
wire [7:0] meta_data;
meta_handler meta_handler(
  .clock(clock), .extReset(extReset),
  .query_metadata(query_metadata), .xmit_idle(!busy && !send && byteDone),
  .writeMeta(writeMeta), .meta_data(meta_data));


//
// Instantiate the heavy lifters...
//
serial_receiver #(.FREQ(FREQ), .RATE(RATE)) serial_receiver(
  .clock(clock), .extReset(extReset),
  .rx(sync_rx), .transmitting(busy),
  .op(opcode), .data(opdata), .execute(execute));

serial_transmitter #(.FREQ(FREQ), .RATE(RATE)) serial_transmitter(
  .clock(clock), .extReset(extReset),
  .send(send), .send_data(send_data), .send_valid(send_valid),
  .writeMeta(writeMeta), .meta_data(meta_data),
  .query_id(query_id), 
  .query_dataIn(query_dataIn), .dataIn(dataIn),
  .tx(tx), .busy(busy), .byteDone(byteDone));


//
// Process special commands not handled by core decoder...
//
always @(posedge clock) 
begin
  query_id = next_query_id;
  query_metadata = next_query_metadata;
  query_dataIn = next_query_dataIn;
  dly_execute = next_dly_execute;
end

always @*
begin
  #1;
  next_query_id = 1'b0; 
  next_query_metadata = 1'b0;
  next_query_dataIn = 1'b0;
  next_dly_execute = execute;

  if (!dly_execute && execute)
    case (opcode)
      8'h02 : next_query_id = 1'b1;
      8'h04 : next_query_metadata = 1'b1; 
      8'h06 : next_query_dataIn = 1'b1;
    endcase
end
endmodule
