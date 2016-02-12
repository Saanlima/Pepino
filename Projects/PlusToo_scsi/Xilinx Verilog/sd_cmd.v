/***************************************************************************************************
*  sd_cmd.v
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

module sd_cmd(
  sd_clk,
  reset,// active high
  sd_cmd_in,
  command_valid,
  command,
  sd_cmd_out,
  sd_cmd_oe,
  command_busy,
  resp_valid,
  response,
  crc_ok,
  timeout);

  input sd_clk;
  input reset;
  input sd_cmd_in;
  input command_valid;
  input[39:0] command;
  
  output sd_cmd_out; 
  output sd_cmd_oe;
  output command_busy;
  output resp_valid;
  output[119:0] response;
  output crc_ok;
  output timeout;

  
  parameter SIZE = 3;
  parameter 
  IDLE   = 3'b001,
  WRITE  = 3'b010,
  READ   = 3'b100;

  reg[SIZE-1:0] state;
  reg[SIZE-1:0] next_state;
  
  reg command_valid_d;
  reg cmd_in;

  reg sd_cmd_out;
  reg sd_cmd_oe;
  
  reg cmd_out, next_cmd_out;
  reg cmd_oe, next_cmd_oe;
  reg[47:0] data, next_data;
  reg[133:0] resp_buffer;
  reg crc_read_en, next_crc_read_en;
  reg command_busy, next_command_busy;
  reg[5:0] index, next_index;
  reg send_crc, next_send_crc;
  reg bigresp, next_bigresp;
  reg[7:0] resp_cnt, next_resp_cnt;
  reg shift_resp;
  reg resp_valid, next_resp_valid;
  reg set_crc_status, next_set_crc_status;
  reg crc_ok;
  reg[6:0] to_cnt, next_to_cnt;
  reg to_cnt_en, next_to_cnt_en;
  reg timeout, next_timeout;

  wire[7:1] crc_write;
  wire[6:0] crc_read;
  wire[119:0] response = resp_buffer[127:8];

  crc_7 crc_7_wr( 
    .bit (data[index]),
    .enable (!send_crc),
    .clk (sd_clk),
    .reset (cmd_oe),
    .crc (crc_write));


  crc_7 crc_7_rd( 
    .bit (cmd_in),
    .enable (crc_read_en),
    .clk (sd_clk),
    .reset (!cmd_oe),
    .crc (crc_read));


  // input synchronizers
  always @ (posedge sd_clk or posedge reset) begin
    if (reset) begin
      command_valid_d <= 1'b0;
      cmd_in <= 1'b1;
    end else begin
      command_valid_d <= command_valid;
      cmd_in <= sd_cmd_in;
    end
  end

  // sd output registers (clocked on negative edge!)
  always @ (negedge sd_clk or posedge reset) begin
    if (reset) begin
      sd_cmd_out <= 1'b1;
      sd_cmd_oe <= 1'b1;
    end else begin
      sd_cmd_out <= cmd_out;
      sd_cmd_oe <= cmd_oe;
    end
  end
  
  always @ (posedge sd_clk) begin
    bigresp <= next_bigresp;
    resp_cnt <= next_resp_cnt;
    crc_read_en <= next_crc_read_en;
  end

  always @ (posedge sd_clk or posedge reset) begin
    if (reset) begin
      state <= IDLE;
      cmd_out <= 1'b1;
      cmd_oe <= 1'b1;
      command_busy <= 1'b0;
      index <= 6'd0;
      send_crc <= 1'b0;
      data <= 48'h000000000000;
      resp_buffer <= 134'b0;
      resp_valid <= 1'b0;
      set_crc_status <= 1'b0;
      crc_ok <= 1'b0;
      to_cnt <= 7'd0;
      to_cnt_en <= 1'b0;
      timeout <= 1'b0;
    end else begin
      state <= next_state;
      cmd_out <= next_cmd_out;
      cmd_oe <= next_cmd_oe;
      command_busy <= next_command_busy;
      index <= next_index;
      send_crc <= next_send_crc;
      data <= next_data;
      if (shift_resp)
        resp_buffer <= {resp_buffer[132:0], cmd_in};
      resp_valid <= next_resp_valid;
      set_crc_status <= next_set_crc_status;
      if (set_crc_status)
        crc_ok <= (resp_buffer[7:0] == {crc_read, 1'b1});
      to_cnt <= next_to_cnt;
      to_cnt_en <= next_to_cnt_en;
      timeout <= next_timeout;
    end
  end

  always @ * begin
    next_state = state;
    next_data = data;
    next_command_busy = command_busy;
    next_cmd_oe = 1'b1;
    next_cmd_out = 1'b1;
    next_index = index;
    next_send_crc = send_crc;
    next_resp_cnt = 8'd0;
    next_crc_read_en = crc_read_en;
    next_bigresp = bigresp;
    shift_resp = 1'b0;
    next_resp_valid = set_crc_status? 1'b1 : resp_valid;
    next_set_crc_status = 1'b0;
    next_timeout = timeout;
    next_to_cnt = to_cnt;
    next_to_cnt_en = to_cnt_en;
    case(state)                                            
      IDLE: begin
        next_command_busy = 1'b0;
        next_send_crc = 1'b0;
        if (to_cnt_en && !timeout) begin
          next_to_cnt = to_cnt + 1'b1;
          next_timeout = (to_cnt == 7'h7f);
        end
        if (command_valid_d) begin
          next_bigresp = command[39];
          next_data = {1'b0, command[38:0], 7'h00, 1'b1}; // start bit, command, crc, stop
          next_command_busy = 1'b1;
          next_timeout = 1'b0;
          next_to_cnt = 7'd0;
          next_index = 6'd47;
          next_cmd_oe = 1'b0;
          next_resp_valid = 1'b0;
          next_state = WRITE;
        end else if (cmd_oe && !cmd_in) begin
          next_crc_read_en = 1'b1;
          next_state = READ;
        end
      end
      WRITE: begin
        next_cmd_oe = 1'b0;
        next_cmd_out = send_crc ? crc_write[index] : data[index];
        next_index = index - 1'b1;
        if (index == 6'd8)
          next_send_crc = 1'b1;
        else if (index == 6'd1)
          next_send_crc = 1'b0;
        else if (index == 6'd0) begin
          next_to_cnt_en = 1'b1;
          next_state = IDLE;
        end
      end
      READ: begin
        next_to_cnt_en = 1'b0;
        shift_resp = 1'b1;
        next_resp_cnt = resp_cnt + 1'b1;
        if (resp_cnt == (bigresp ? 8'd126 : 8'd38))
		      next_crc_read_en = 1'b0;
        if (resp_cnt == (bigresp ? 8'd134 : 8'd46)) begin
          next_set_crc_status = 1'b1;
          next_state = IDLE;
        end
      end
      default: next_state  = IDLE;
    endcase     
  end 


endmodule



