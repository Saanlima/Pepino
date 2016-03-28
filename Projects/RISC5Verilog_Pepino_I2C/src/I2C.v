/******************************************************************************
*  I2C.v
*
*  Copyright (c) 2016, Magnus Karlsson
*  All rights reserved.
*
*  Redistribution and use in source and binary forms, with or without 
*  modification, are permitted provided that the following conditions are met:
*
*  1. Redistributions of source code must retain the above copyright notice, 
*     this list of conditions and the following disclaimer.
*  2. Redistributions in binary form must reproduce the above copyright notice,
*     this list of conditions and the following disclaimer in the documentation
*     and/or other materials provided with the distribution.
*
*  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
*  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
*  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
*  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
*  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
*  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
*  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
*  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
*  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
*  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
*  POSSIBILITY OF SUCH DAMAGE.
*
******************************************************************************/

module I2C (
  input clk,
  input rst,
  inout SCL,
  inout SDA,
  input [15:0] sclh,
  input [15:0] scll,
  output [7:0] control,
  output [4:0] status,
  output [7:0] data,
  input [7:0] wrdata,
  input wr_conset,
  input wr_data,
  input wr_conclr
);

  parameter 
  IDLE     = 22'b0000000000000000000001,
  START    = 22'b0000000000000000000010,
  ADDR1    = 22'b0000000000000000000100,
  ADDR2    = 22'b0000000000000000001000,
  ADDR3    = 22'b0000000000000000010000,
  ADDR4    = 22'b0000000000000000100000,
  ADDR5    = 22'b0000000000000001000000,
  WRITE1   = 22'b0000000000000010000000,
  WRITE2   = 22'b0000000000000100000000,
  WRITE3   = 22'b0000000000001000000000,
  WRITE4   = 22'b0000000000010000000000,
  WRITE5   = 22'b0000000000100000000000,
  READ1    = 22'b0000000001000000000000,
  READ2    = 22'b0000000010000000000000,
  READ3    = 22'b0000000100000000000000,
  READ4    = 22'b0000001000000000000000,
  READ5    = 22'b0000010000000000000000,
  STOP1    = 22'b0000100000000000000000,
  STOP2    = 22'b0001000000000000000000,
  STOP3    = 22'b0010000000000000000000,
  RESTART1 = 22'b0100000000000000000000,
  RESTART2 = 22'b1000000000000000000000;

  
  reg [21:0] state, next_state;
  reg [7:0] data_sr, next_data_sr;
  reg read, next_read;
  reg [4:0] status_reg, next_status_reg;
  reg [2:0] bitcnt, next_bitcnt;
  reg ack_out, next_ack_out;
  reg SDA_out, next_SDA_out;
  reg SCL_out, next_SCL_out;
  reg [15:0] delay_counter, next_delay_counter;
  reg set_interrupt, clr_stop;
  reg enable, start, stop, interrupt, ack_enable;

  assign SDA = SDA_out ? 1'bz : 1'b0;
  assign SCL = SCL_out ? 1'bz : 1'b0;
  assign SDA_in = SDA;
  assign SCL_in = SCL;
  
  assign status = interrupt ? status_reg : 5'h1f;
  assign data = data_sr;
  assign control = {1'b0, enable, start, stop, interrupt, ack_enable, 2'b00};

  // control register bits
  always @ (posedge clk) begin
    if (~rst | (wr_conclr & wrdata[6]))
      enable <= 1'b0;
    else if (wr_conset & wrdata[6])
      enable <= 1'b1;
    if (~rst | (wr_conclr & wrdata[5]))
      start <= 1'b0;
    else if (wr_conset & wrdata[5])
      start <= 1'b1;
    if (~rst | ~enable | clr_stop)
      stop <= 1'b0;
    else if (wr_conset & wrdata[4])
      stop <= 1'b1;
    if (~rst | ~enable | (wr_conclr & wrdata[3]))
      interrupt <= 1'b0;
    else if (set_interrupt)
      interrupt <= 1'b1;
    if (~rst | (wr_conclr & wrdata[2]))
      ack_enable <= 1'b0;
    else if (wr_conset & wrdata[2])
      ack_enable <= 1'b1;
  end

  always @ (posedge clk) begin
    if (~enable) begin
      state <= IDLE;
      data_sr <= 8'd0;
      read <= 1'b0;
      status_reg <= 5'd0;
      bitcnt <= 3'd0;
      ack_out <= 1'b0;
      SDA_out <= 1'b1;
      SCL_out <= 1'b1;
      delay_counter <= 16'd0;
    end else begin
      state <= next_state;
      data_sr <= (interrupt & wr_data) ? wrdata : next_data_sr;
      read <= next_read;
      status_reg <= next_status_reg;
      bitcnt <= next_bitcnt;
      ack_out <= next_ack_out;
      SDA_out <= next_SDA_out;
      SCL_out <= next_SCL_out;
      delay_counter <= next_delay_counter;
    end
  end

  always @ * begin
    next_state = state;
    next_data_sr = data_sr;
    next_read = read;
    next_status_reg = status_reg;
    next_bitcnt = bitcnt;
    next_delay_counter = delay_counter;
    next_ack_out = ack_out;
    next_SDA_out = SDA_out;
    next_SCL_out = SCL_out;
    set_interrupt = 1'b0;
    clr_stop = 1'b0;
    case (state)
      IDLE: begin
        next_SDA_out = 1'b1;
        next_SCL_out = 1'b1;
        next_delay_counter = 16'd0;
        if (start & ~interrupt) begin
          next_status_reg = 5'h01;
          next_SDA_out = 1'b0;
          next_state = START;
        end
      end
      START: begin
        next_delay_counter = delay_counter + 1'b1;
        if (delay_counter == sclh) begin
          next_SCL_out = 1'b0;
          set_interrupt = 1'b1;
          next_delay_counter = 16'd0;
          next_state = ADDR1;
        end
      end
      ADDR1: begin
        next_delay_counter = 16'd0;
        if (~interrupt) begin
          if (stop) begin
            next_SCL_out = 1'b1;
            next_state = STOP1;
          end else if (start) begin
            next_SDA_out = 1'b1;
            next_state = RESTART1;
          end else begin
            next_bitcnt = 3'd0;
            next_read = data_sr[0];
            next_SDA_out = data_sr[7];
            next_state = ADDR2;
          end
        end
      end
      ADDR2: begin
        next_delay_counter = delay_counter + 1'b1;
         if (delay_counter == scll) begin
          next_SCL_out = 1'b1;
          next_data_sr = {data_sr[6:0], SDA_in};
          next_delay_counter = 16'd0;
          next_state = ADDR3;
        end
      end
      ADDR3: begin
        // clock stretching
        next_delay_counter = SCL_in ? delay_counter + 1'b1 : 16'd0;
        if(delay_counter == sclh) begin
          next_SCL_out = 1'b0;
          next_bitcnt = bitcnt + 1'b1;
          next_delay_counter = 16'd0;
          if (bitcnt == 3'd7) begin
            next_SDA_out = 1'b1;
            next_state = ADDR4;
          end else begin
            next_SDA_out = data_sr[7];
            next_state = ADDR2;
          end
        end
      end
      ADDR4: begin
        next_delay_counter = delay_counter + 1'b1;
         if (delay_counter == scll) begin
          next_SCL_out = 1'b1;
          next_delay_counter = 16'd0;
          next_state = ADDR5;
        end
      end
      ADDR5: begin
        // clock stretching
        next_delay_counter = SCL_in ? delay_counter + 1'b1 : 16'd0;
        if(delay_counter == sclh) begin
          next_SCL_out = 1'b0;
          next_delay_counter = 16'd0;
          next_status_reg = read ? (SDA_in ? 5'h9 : 5'h8)
                                 : (SDA_in ? 5'h4 : 5'h3);
          set_interrupt = 1'b1;
          next_state = read ? READ1 : WRITE1;
        end
      end

      WRITE1: begin
        next_delay_counter = 16'd0;
        if (~interrupt) begin
          if (stop) begin
            next_state = STOP1;
          end else if (start) begin
            next_SDA_out = 1'b1;
            next_state = RESTART1;
          end else begin
            next_bitcnt = 3'd0;
            next_SDA_out = data_sr[7];
            next_state = WRITE2;
          end
        end
      end
      WRITE2: begin
        next_delay_counter = delay_counter + 1'b1;
         if (delay_counter == scll) begin
          next_SCL_out = 1'b1;
          next_data_sr = {data_sr[6:0], SDA_in};
          next_delay_counter = 16'd0;
          next_state = WRITE3;
        end
      end
      WRITE3: begin
        // clock stretching
        next_delay_counter = SCL_in ? delay_counter + 1'b1 : 16'd0;
        if(delay_counter == sclh) begin
          next_SCL_out = 1'b0;
          next_bitcnt = bitcnt + 1'b1;
          next_delay_counter = 16'd0;
          if (bitcnt == 3'd7) begin
            next_SDA_out = 1'b1;
            next_state = WRITE4;
          end else begin
            next_SDA_out = data_sr[7];
            next_state = WRITE2;
          end
        end
      end
      WRITE4: begin
        next_delay_counter = delay_counter + 1'b1;
         if (delay_counter == scll) begin
          next_SCL_out = 1'b1;
          next_delay_counter = 16'd0;
          next_state = WRITE5;
        end
      end
      WRITE5: begin
        // clock stretching
        next_delay_counter = SCL_in ? delay_counter + 1'b1 : 16'd0;
        if(delay_counter == sclh) begin
          next_SCL_out = 1'b0;
          next_delay_counter = 16'd0;
          next_status_reg = SDA_in ? 5'h6 : 5'h5;
          set_interrupt = 1'b1;
          next_state = WRITE1;
        end
      end

      READ1: begin
        next_delay_counter = 16'd0;
        if (~interrupt) begin
          if (stop) begin
            next_state = STOP1;
          end else if (start) begin
            next_SDA_out = 1'b1;
            next_state = RESTART1;
          end else begin
            next_bitcnt = 3'd0;
            next_SDA_out = 1'b1;
            next_ack_out = ~ack_enable;
            next_state = READ2;
          end
        end
      end
      READ2: begin
        next_delay_counter = delay_counter + 1'b1;
         if (delay_counter == scll) begin
          next_SCL_out = 1'b1;
          next_data_sr = {data_sr[6:0], SDA_in};
          next_delay_counter = 16'd0;
          next_state = READ3;
        end
      end
      READ3: begin
        // clock stretching
        next_delay_counter = SCL_in ? delay_counter + 1'b1 : 16'd0;
        if(delay_counter == sclh) begin
          next_SCL_out = 1'b0;
          next_bitcnt = bitcnt + 1'b1;
          next_delay_counter = 16'd0;
          if (bitcnt == 3'd7) begin
            next_SDA_out = ack_out;
            next_state = READ4;
          end else begin
            next_state = READ2;
          end
        end
      end
      READ4: begin
        next_delay_counter = delay_counter + 1'b1;
         if (delay_counter == scll) begin
          next_SCL_out = 1'b1;
          next_delay_counter = 16'd0;
          next_state = READ5;
        end
      end
      READ5: begin
        // clock stretching
        next_delay_counter = SCL_in ? delay_counter + 1'b1 : 16'd0;
        if(delay_counter == sclh) begin
          next_SCL_out = 1'b0;
          next_delay_counter = 16'd0;
          next_status_reg = ack_out ? 5'hb : 5'ha;
          set_interrupt = 1'b1;
          next_state = READ1;
        end
      end

      STOP1: begin
        next_delay_counter = delay_counter + 1'b1;
        if (delay_counter == scll) begin
          next_SCL_out = 1'b1;
          next_delay_counter = 16'd0;
          next_state = STOP2;
        end
      end
      STOP2: begin
        next_delay_counter = delay_counter + 1'b1;
        if (delay_counter == sclh) begin
          next_SDA_out = 1'b1;
          next_delay_counter = 16'd0;
          next_state = STOP3;
        end
      end
      STOP3: begin
        next_delay_counter = delay_counter + 1'b1;
        if (delay_counter == sclh) begin
          clr_stop = 1'b1;
          next_state = IDLE;
        end
      end

      RESTART1: begin
        next_delay_counter = delay_counter + 1'b1;
        if (delay_counter == scll) begin
          next_SCL_out = 1'b1;
          next_delay_counter = 16'd0;
          next_state = RESTART2;
        end
      end
      RESTART2: begin
        next_delay_counter = delay_counter + 1'b1;
        if (delay_counter == sclh) begin
          next_status_reg = 5'h02;
          next_SDA_out = 1'b0;
          next_state = START;
        end
      end
      default:
        next_state = IDLE;
    endcase
  end
endmodule
        