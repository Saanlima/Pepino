/***************************************************************************************************
*  sd_fsm.v
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

module sd_fsm(
  clk,
  reset,
  control,
  switch_pending,
  clk_stopped,
  command_valid,
  command,
  command_busy,
  cmd_crc_ok,
  timeout,
  response,
  resp_valid,
  sd_write_enable,
  sd_read_enable,
  wide_width_data,
  send_busy,
  rec_busy,
  sd_busy,
  dat_crc_ok,
  error,
  disk_mounted,
  blocks,
  sd_active,
  sd_read,
  sd_write,
  startup,
  io_rd,
  io_wr,
  io_ack,
  io_lba);

  input clk;
  input reset;
  output [8:0] control;
  input switch_pending;
  input clk_stopped;
  output command_valid;
  output[39:0] command;
  input command_busy;
  input cmd_crc_ok;
  input timeout;
  input[119:0] response;
  input resp_valid;
  output sd_write_enable;
  output sd_read_enable;
  output wide_width_data;
  input send_busy;
  input rec_busy;
  input sd_busy;
  input dat_crc_ok;
  output error;
  output disk_mounted;
  output [ 21:0] blocks;
  output sd_active;
  output sd_read;
  output sd_write;
  input startup;
  input io_rd;
  input io_wr;
  input [31:0] io_lba;
  output io_ack;

  parameter SIZE = 26;
  parameter 
  INIT_0   = 26'b00000000000000000000000001,
  INIT_1   = 26'b00000000000000000000000010,
  INIT_2   = 26'b00000000000000000000000100,
  INIT_3   = 26'b00000000000000000000001000,
  INIT_4   = 26'b00000000000000000000010000,
  INIT_5   = 26'b00000000000000000000100000,
  INIT_6   = 26'b00000000000000000001000000,
  INIT_7   = 26'b00000000000000000010000000,
  INIT_8   = 26'b00000000000000000100000000,
  INIT_9   = 26'b00000000000000001000000000,
  INIT_10  = 26'b00000000000000010000000000,
  INIT_11  = 26'b00000000000000100000000000,
  INIT_12  = 26'b00000000000001000000000000,
  INIT_13  = 26'b00000000000010000000000000,
  IDLE     = 26'b00000000000100000000000000,
  READ_1   = 26'b00000000001000000000000000,
  READ_2   = 26'b00000000010000000000000000,
  READ_3   = 26'b00000000100000000000000000,
  READ_4   = 26'b00000001000000000000000000,
  WRITE_1  = 26'b00000010000000000000000000,
  WRITE_2  = 26'b00000100000000000000000000,
  WRITE_3  = 26'b00001000000000000000000000,
  WRITE_4  = 26'b00010000000000000000000000,
  DONE_1   = 26'b00100000000000000000000000,
  DONE_2   = 26'b01000000000000000000000000,
  ERROR    = 26'b10000000000000000000000000;
  
  reg [SIZE-1:0] state, next_state;
  reg [15:0] rca, next_rca;
  reg [1:0] ver, next_ver;
  reg hcs, next_hcs;
  reg [39:0] command, next_command;
  reg command_valid, next_command_valid;
  reg error, next_error;
  reg disk_mounted, next_disk_mounted;
  reg io_ack, next_io_ack;
  reg sd_active, next_sd_active;
  reg sd_read, next_sd_read;
  reg sd_write, next_sd_write;
  reg [8:0] counter, next_counter;
  reg [8:0] control, next_control;
  reg sd_write_enable, next_sd_write_enable;
  reg sd_read_enable, next_sd_read_enable;
  reg [21:0] size, next_size; // last block on the card / 1024
  reg wide_width_data, next_wide_width_data;  reg erase_error, next_erase_error;
  
  wire [21:0] blocks;
  
  assign blocks = ((ver == 2'b11) ? (size + 1'b1) : 22'h768); // assume 1GB SDSC card

  always @ (posedge clk) begin
    if (reset) begin
      state <= INIT_0;
      rca <= 16'h0000;
      ver <= 2'b00;
      hcs <= 1'b0;
      error <= 1'b0;
      disk_mounted <= 1'b0;
      io_ack <= 1'b0;
      sd_active <= 1'b0;
      sd_read <= 1'b0;
      sd_write <= 1'b0;
      counter <= 9'b0;
      command <= 40'b0;
      command_valid <= 1'b0;
      control <= 9'h1ff;
      sd_write_enable <= 1'b0;
      sd_read_enable <= 1'b0;
      size <= 22'd0;
      wide_width_data <= 1'b0;
    end else begin
      state <= next_state;
      rca <= next_rca;
      ver <= next_ver;
      hcs <= next_hcs;
      error <= next_error;
      disk_mounted <= next_disk_mounted;
      io_ack <= next_io_ack;
      sd_active <= next_sd_active;
      sd_read <= next_sd_read;
      sd_write <= next_sd_write;
      counter <= next_counter;
      command <= next_command;
      command_valid <= next_command_valid;
      control <= next_control;
      sd_write_enable <= next_sd_write_enable;
      sd_read_enable <= next_sd_read_enable;
      size <= next_size;
      wide_width_data <= next_wide_width_data;
    end
  end

  always @ * begin
    next_state = state;
    next_command = command;
    next_command_valid = command_valid;
    next_rca = rca;
    next_ver = ver;
    next_hcs = hcs;
    next_error = error;
    next_disk_mounted = disk_mounted;
    next_io_ack = 1'b0;
    next_sd_active = sd_active;
    next_sd_read = sd_read;
    next_sd_write = sd_write;
    next_counter = counter;
    next_control = control;
    next_sd_write_enable = sd_write_enable;
    next_sd_read_enable = sd_read_enable;
    next_size = size;
    next_wide_width_data = wide_width_data;
    case(state)
      INIT_0: begin
        next_disk_mounted = 1'b0;
        next_sd_active = 1'b0;
        next_sd_read = 1'b0;
        next_sd_write = 1'b0;
        next_control = 9'h1ff;
        next_counter = counter + 1'b1;
        next_state = counter[8] ? INIT_1 : INIT_0;
      end
      INIT_1: begin
        next_control = 9'h0fe;
        next_state = INIT_2;
      end
      INIT_2: begin
        if (startup) begin
          // issue sd-card reset command
          next_command = 40'h4000000000; // CMD0, ARG0 (no response expected)
          next_command_valid = 1'b1;
          next_ver = 2'b00; // unknown card type
          next_rca = 16'h0000;
          next_hcs = 1'b0;
          next_sd_active = 1'b1;
          next_state = INIT_3;
        end
      end
      INIT_3: begin
        if (command_busy)
          next_command_valid = 1'b0;
        if (timeout && !command_valid) begin
          // issue CMD8 to check for SD Ver 2.0 card
          next_command = 40'h48000001aa; // CMD8, voltage range, check pattern
          next_command_valid = 1'b1;
          next_state = INIT_4;
        end
      end
      INIT_4: begin
        if (command_busy)
          next_command_valid = 1'b0;
        if (timeout && !command_valid) begin
          // no response ->  SD Ver 1.0 card
          // issue ACMD41 command until not busy
          next_ver = 2'b01; // indicate SD Ver 1.0 card
          next_command = 40'h7700000000; // first issue CMD55
          next_command_valid = 1'b1;
          next_state = INIT_5;
        end else if (resp_valid && !command_valid) begin
          if (response[11:0] == 12'h1aa) begin
            // valid Ver 2.0 response, do Ver 2.0 card init here
            next_hcs = 1'b1; // indicate high capacity support
            // issue ACMD41 command until not busy
            next_command = 40'h7700000000; // first issue CMD55
            next_command_valid = 1'b1;
            next_state = INIT_5;
          end else begin
            //invalid response
            next_state = ERROR;
          end
        end
      end
      INIT_5: begin
        if (command_busy)
          next_command_valid = 1'b0;
        if (timeout && !command_valid) begin
          next_state = ERROR;
        end else if (resp_valid && !command_valid) begin
          if (cmd_crc_ok) begin
            // then issue CMD41 with correct HCS bit
            next_command = {8'h69,1'b0,hcs,30'h0ff8000};
            next_command_valid = 1'b1;
            next_state = INIT_6;
          end else begin
            next_command = 40'h7700000000; // re-issue CMD55
            next_command_valid = 1'b1;
          end
        end
      end
      INIT_6: begin
        if (command_busy)
          next_command_valid = 1'b0;
        if (timeout && !command_valid) begin
          next_state = ERROR;
        end else if (resp_valid && !command_valid) begin
          if (response[31] == 1'b0) begin
            // busy, issue ACMD41 again
            next_command = 40'h7700000000;
            next_command_valid = 1'b1;
            next_state = INIT_5;
          end else begin
            // if Ver 2.0 - grab the CCA bit (high capacity or standard capacity)
            if (ver == 2'b00)
              next_ver = (response[30] ? 2'b11 : 2'b10); 
            // issue CMD2 to get CID, big response
            next_command = 40'hc200000000;
            next_command_valid = 1'b1;
            next_state = INIT_7;
          end
        end
      end
      INIT_7: begin
        if (command_busy)
          next_command_valid = 1'b0;
        if (timeout && !command_valid) begin
          next_state = ERROR;
        end else if (resp_valid && !command_valid) begin
          // issue CMD3 to get the relative card address (RCA)
          next_command = 40'h4300000000;
          next_command_valid = 1'b1;
          next_state = INIT_8;
        end
      end
      INIT_8: begin
        if (command_busy)
          next_command_valid = 1'b0;
        if (timeout && !command_valid) begin
          next_state = ERROR;
        end else if (resp_valid && !command_valid) begin
          // grab the RCA
          next_rca = response[31:16];
          // issue CMD9 to get the CSD register
          next_command = {8'hc9,response[31:16],16'h0000};
          next_command_valid = 1'b1;
          next_state = INIT_9;
        end
      end
      INIT_9: begin
        if (command_busy)
          next_command_valid = 1'b0;
        if (timeout && !command_valid) begin
          next_state = ERROR;
        end else if (resp_valid && !command_valid) begin
          // grab size info from the CSD data
          next_size = response[61:40]; // assume this is an SDHC card
          // issue CMD7 to put the card in transfer state
          next_command = {8'h47,rca,16'h0000};
          next_command_valid = 1'b1;
          next_state = INIT_10;
        end
      end
      INIT_10: begin
        if (command_busy)
          next_command_valid = 1'b0;
        if (timeout && !command_valid) begin
          next_state = ERROR;
        end else if (resp_valid && !command_valid) begin
          // issue CMD16 to set the block size to 512
          next_command = 40'h5000000200;
          next_command_valid = 1'b1;
          next_state = INIT_11;
        end
      end
      INIT_11: begin
        if (command_busy)
          next_command_valid = 1'b0;
        if (timeout && !command_valid) begin
          next_state = ERROR;
        end else if (resp_valid && !command_valid) begin
          // Set bus width to 4 (ACMD6)
          next_command = {8'h77,rca,16'h0000}; // first issue CMD55
          next_command_valid = 1'b1;
          next_state = INIT_12;
        end
      end
      INIT_12: begin
        if (command_busy)
          next_command_valid = 1'b0;
        if (timeout && !command_valid) begin
          next_state = ERROR;
        end else if (resp_valid && !command_valid) begin
          // issue ACMD6
          next_command = 40'h4600000002; // then issue ACMD6
          next_command_valid = 1'b1;
          next_state = INIT_13;
        end
      end
      INIT_13: begin
        if (command_busy)
          next_command_valid = 1'b0;
        if (timeout && !command_valid) begin
          next_state = ERROR;
        end else if (resp_valid && !command_valid) begin
          next_control = 9'h00; // change to fastest clock speed
          next_state = IDLE;
        end
      end
      IDLE: begin
        if (!switch_pending) begin
          next_disk_mounted = 1'b1;
          next_sd_active = 1'b0;
          next_sd_read = 1'b0;
          next_sd_write = 1'b0;
          if (io_rd)
            next_state = READ_1;
          else if (io_wr)
            next_state = WRITE_1;
        end
      end
      READ_1: begin
        if (ver == 2'b11)
          next_command = {8'h51, io_lba};
        else
          next_command = {8'h51, io_lba[22:0],9'h0};
        next_command_valid = 1'b1;
        next_sd_active = 1'b1;
        next_sd_read = 1'b1;
        next_state = READ_2;
      end
      READ_2: begin
        if (command_busy) begin
          next_command_valid = 1'b0;
          next_sd_read_enable = 1'b1;
        end
        if (timeout && !command_valid) begin
          next_state = ERROR;
        end else if (resp_valid && !command_valid) begin
          next_state = READ_3;
        end
      end
      READ_3: begin
        if (rec_busy) begin
          next_sd_read_enable = 1'b0;
          next_state = READ_4;
        end
      end
      READ_4: begin
        if (!rec_busy) begin
          if (!dat_crc_ok)
            next_state = ERROR;
          else begin
          next_io_ack = 1'b1;
          next_state = DONE_1;
          end
        end
      end
      WRITE_1: begin
        if (ver == 2'b11)
          next_command = {8'h58, io_lba};
        else
          next_command = {8'h58, io_lba[22:0],9'h0};
        next_command_valid = 1'b1;
        next_sd_active = 1'b1;
        next_sd_write = 1'b1;
        next_state = WRITE_2;
      end
      WRITE_2: begin
        if (command_busy) begin
          next_command_valid = 1'b0;
        end
        if (timeout && !command_valid) begin
          next_state = ERROR;
        end else if (resp_valid && !command_valid) begin
          next_sd_write_enable = 1'b1;
          next_state = WRITE_3;
        end
      end
      WRITE_3: begin
        if (send_busy) begin
          next_sd_write_enable = 1'b0;
          next_state = WRITE_4;
        end
      end
      WRITE_4: begin
        if (!send_busy) begin
          next_io_ack = 1'b1;
          next_state = DONE_1;
        end
      end
      DONE_1 : begin
        next_state = DONE_2;
      end
      DONE_2 : begin
        next_state = IDLE;
      end
      ERROR: begin
        next_command_valid = 1'b0;
        next_control = 9'h1ff;
        next_error = 1'b1;
        next_disk_mounted = 1'b0;
        next_io_ack = 1'b0;
      end

      default: begin
        next_state = INIT_0;
      end
    endcase
  end
endmodule
      