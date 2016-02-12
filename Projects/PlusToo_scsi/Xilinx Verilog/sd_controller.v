/***************************************************************************************************
*  sd_controller.v
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

module sd_controller(
  clk,
  reset,
  control,
  switch_pending,
  clk_stopped,
  sd_clk,
  sd_cmd_in,
  sd_cmd_out,
  sd_cmd_oe,
  sd_dat_in,
  sd_dat_out,
  sd_dat_oe,
  fifo_din,
  fifo_rd,
  fifo_wr,
  fifo_dout,
  timeout,
  command_valid,
  command,
  command_busy,
  resp_valid,
  response,
  cmd_crc_ok,
  sd_write_enable,
  sd_read_enable,
  wide_width_data,
  send_busy,
  rec_busy,
  sd_busy,
  dat_crc_ok,
  startup
  );

  input clk;
  input reset;
  input[8:0] control;
  output switch_pending;
  output clk_stopped;

  // sd card interface
  output sd_clk;
  input sd_cmd_in;
  output sd_cmd_out;
  output sd_cmd_oe;
  input[3:0] sd_dat_in;
  output[3:0] sd_dat_out;
  output sd_dat_oe;

  output[7:0] fifo_dout;
  input[7:0] fifo_din;
  output fifo_wr;
  output fifo_rd;
  
  // sm interface
  output timeout;
  input command_valid;
  input[39:0] command;
  output command_busy;
  output resp_valid;
  output[119:0] response;
  output cmd_crc_ok;

  input sd_write_enable;
  input sd_read_enable;
  input wide_width_data;
  output send_busy;
  output rec_busy;
  output sd_busy;
  output dat_crc_ok;
  output startup;

  wire send_busy;
  wire rec_busy;

  wire[3:0] sd_dat_in, sd_dat_out;

  wire[119:0] response;

  wire block_available = 1'b1;

  wire switch_pending;
  wire sd_busy;
  
  wire rst = reset | control[8];

  reg[6:0] clkdiv, clkcmp;
  reg sd_clk;
  reg timeout_dec_en;
  reg clk_stopped;
  reg[6:0] startup_cnt;
  
  wire startup;


  sd_cmd sd_cmd1(
    .sd_clk(sd_clk),
    .reset(rst),
    .sd_cmd_in(sd_cmd_in),
    .command_valid(command_valid),
    .command(command),
    .sd_cmd_out(sd_cmd_out),
    .sd_cmd_oe(sd_cmd_oe),
    .command_busy(command_busy),
    .resp_valid(resp_valid),
    .response(response),
    .crc_ok(cmd_crc_ok),
    .timeout(timeout)
  );
  
  sd_dat sd_dat1(
    .sd_clk(sd_clk),
    .reset(rst),
    .sd_write_enable(sd_write_enable),
    .sd_read_enable(sd_read_enable),
    .wide_width_data(wide_width_data),
    .block_available(block_available), 
    .sd_dat_in(sd_dat_in),
    .sd_dat_out(sd_dat_out),
    .sd_dat_oe(sd_dat_oe),
    .fifo_din(fifo_din),
    .fifo_rd(fifo_rd),
    .fifo_wr(fifo_wr),
    .fifo_dout(fifo_dout),
    .send_busy(send_busy),
    .rec_busy(rec_busy),
    .crc_ok(dat_crc_ok),
    .sd_busy(sd_busy)
  );


  always @ (posedge clk) begin
    if (reset) begin
      clkdiv <= 7'b0;
      sd_clk <= 1'b1;
      timeout_dec_en <= 1'b0;
      clkcmp <= control[7:1];
      clk_stopped <= 1'b0;
    end else if (clkdiv == clkcmp) begin
      clkdiv <= 7'b0;
      sd_clk <= ~sd_clk | control[0];
      timeout_dec_en <= ~sd_clk;
      clkcmp <= control[7:1];
      clk_stopped <= control[0];
    end else if (clkdiv == 7'b0) begin
      clkdiv <= (control[0] || (control[7:1] == 7'b0)) ? 7'b0 : clkdiv + 1'b1;
      sd_clk <= sd_clk | control[0];
      timeout_dec_en <= 1'b0;
      clkcmp <= control[7:1];
      clk_stopped <= control[0];
    end else begin
      clkdiv <= clkdiv + 1'b1;
      timeout_dec_en <= 1'b0;
      clk_stopped <= 1'b0;
    end
  end

  assign switch_pending = (clkcmp != control[7:1]);

  always @ (posedge clk) begin
    if (reset)
      startup_cnt <= 7'h7f;
    else if (timeout_dec_en && (startup_cnt > 7'b0))
      startup_cnt <= startup_cnt - 1'b1;
  end
  
  assign startup = (startup_cnt == 7'b0);

endmodule
