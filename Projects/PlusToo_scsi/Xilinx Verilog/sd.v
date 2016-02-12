/***************************************************************************************************
*  sd.v
*
*  Copyright (c) 2015, Magnus Karlsson
*  All rights reserved.
*
*  Redistribution and use in source and binary forms, with or without modification, are permitted
*  provided that the following conditions are met:
*
*  1. Redistributions of source code must retain the above copyright notice, this list of conditions
*     and the following disclaimer.
*  2. Redistributions in binary form must reproduce the above copyright notice, this list of
*     conditions and the following disclaimer in the documentation and/or other materials provided
*     with the distribution.
*
*  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
*  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
*  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
*  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
*  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
*  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
*  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
*  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
***************************************************************************************************/

`timescale 1ns/100ps

module sd(
  clk,
  reset,
  sd_clk,
  sd_cmd,
  sd_dat,
  sd_active,
  sd_read,
  sd_write,
  error,
  disk_mounted,
  blocks,
  io_lba,
  io_rd,
  io_wr,
  io_ack,
  io_din,
  io_din_strobe,
  io_dout,
  io_dout_strobe
  );

  input clk;
  input reset;

  // sd card interface
  output sd_clk;
  inout sd_cmd;
  inout [3:0] sd_dat;
  output sd_active;
  output sd_read;
  output sd_write;
  output disk_mounted;
  output [21:0] blocks;
  output error;
  
  input [31:0] io_lba;
  input io_rd;
  input io_wr;
  output io_ack;
  output [7:0] io_din;
  output io_din_strobe;
  input [7:0] io_dout;
  output io_dout_strobe;
  
  wire [119:0] response;
  wire [39:0] command;
  wire [8:0] control;

  wire fifo_wr;
  wire fifo_rd;
  reg io_din_strobe;
  reg io_dout_strobe;
  
  wire [3:0] sd_dat_out, sd_dat_in;
  
  assign sd_cmd = sd_cmd_oe ? 1'bZ : sd_cmd_out;
  assign sd_cmd_in = sd_cmd;
  assign sd_dat = sd_dat_oe ? 4'bZZZZ : sd_dat_out;
  assign sd_dat_in = sd_dat;

  always @ (posedge clk)
    io_din_strobe <= fifo_wr;

  always @ (posedge sd_clk)
    io_dout_strobe <= fifo_rd;
    
	sd_controller sd_cntrl(
    .clk(clk), 
    .reset(reset), 
    .control(control),
    .switch_pending(switch_pending),
    .clk_stopped(clk_stopped),
    .sd_clk(sd_clk), 
    .sd_cmd_in(sd_cmd_in), 
    .sd_cmd_out(sd_cmd_out), 
    .sd_cmd_oe(sd_cmd_oe), 
    .sd_dat_in(sd_dat_in), 
    .sd_dat_out(sd_dat_out), 
    .sd_dat_oe(sd_dat_oe), 
    .fifo_din(io_dout),
    .fifo_rd(fifo_rd),
    .fifo_dout(io_din),
    .fifo_wr(fifo_wr),
    .timeout(timeout), 
    .command_valid(command_valid), 
    .command(command), 
    .command_busy(command_busy), 
    .resp_valid(resp_valid), 
    .response(response), 
    .cmd_crc_ok(cmd_crc_ok), 
    .sd_write_enable(sd_write_enable), 
    .sd_read_enable(sd_read_enable), 
    .wide_width_data(wide_width_data), 
    .send_busy(send_busy), 
    .rec_busy(rec_busy), 
    .sd_busy(sd_busy),
    .dat_crc_ok(dat_crc_ok),
    .startup(startup)
	);

  sd_fsm fsm(
    .clk(clk),
    .reset(reset),
    .control(control),
    .switch_pending(switch_pending),
    .clk_stopped(clk_stopped),
    .command_valid(command_valid), 
    .command(command), 
    .command_busy(command_busy), 
    .cmd_crc_ok(cmd_crc_ok), 
    .timeout(timeout),
    .response(response),
    .resp_valid(resp_valid), 
    .sd_write_enable(sd_write_enable), 
    .sd_read_enable(sd_read_enable), 
    .wide_width_data(wide_width_data), 
    .send_busy(send_busy), 
    .rec_busy(rec_busy), 
    .sd_busy(sd_busy),
    .dat_crc_ok(dat_crc_ok),
    .error(error),
    .disk_mounted(disk_mounted),
    .blocks(blocks),
    .sd_active(sd_active),
    .sd_read(sd_read),
    .sd_write(sd_write),
    .startup(startup),
    .io_rd(io_rd),
    .io_wr(io_wr),
    .io_ack(io_ack),
    .io_lba(io_lba)
  );

endmodule
