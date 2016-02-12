/***************************************************************************************************
*  sd_dat.v
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

module sd_dat(
  sd_clk,
  reset,
  sd_write_enable,
  sd_read_enable,
  wide_width_data,
  block_available,
  fifo_din,
  sd_dat_in,
  sd_dat_out,
  sd_dat_oe,
  fifo_rd,
  fifo_wr,
  fifo_dout,
  send_busy,
  rec_busy,
  crc_ok,
  sd_busy);

  input sd_clk;
  input reset;
  input sd_write_enable;
  input sd_read_enable;
  input wide_width_data;
  input block_available;
  input[7:0] fifo_din;
  input[3:0] sd_dat_in;
  
  output[3:0] sd_dat_out; 
  output sd_dat_oe;
  output fifo_rd;
  output fifo_wr;
  output[7:0] fifo_dout;
  output send_busy;
  output rec_busy;
  output crc_ok;
  output sd_busy;

  
  parameter SIZE = 5;
  parameter 
  IDLE        = 5'b00001,
  WRITE       = 5'b00010,
  WRITE_CRC   = 5'b00100,
  CHECK_CRC   = 5'b01000,
  READ        = 5'b10000;

  reg[SIZE-1:0] state;
  reg[SIZE-1:0] next_state;

  reg[3:0] dat_in;
  reg[3:0] sd_dat_out;
  reg sd_dat_oe;
  
  reg dat_oe, next_dat_oe;
  reg dat_out0, next_dat_out0;
  reg dat_out1, next_dat_out1;
  reg dat_out2, next_dat_out2;
  reg dat_out3, next_dat_out3;
  reg fifo_rd;
  reg fifo_wr;
  reg send_crc, next_send_crc;
  reg[10:0] count, next_count;
  reg[4:0] crc_status, next_crc_status;
  reg send_busy, next_send_busy;
  reg rec_busy, next_rec_busy;
  reg crc_ok, next_crc_ok;
  reg crc_read_en, next_crc_read_en;
  reg[3:0] dat_in_dly;
  reg sd_write_enable_d, sd_read_enable_d;
  reg wide_width_data_d;
  
  wire[16:1] crc_write0, crc_write1, crc_write2, crc_write3;
  wire[16:1] crc_read0, crc_read1, crc_read2, crc_read3;
  
  wire[7:0] fifo_dout;
  wire sd_busy;

  wire [3:0] din;
  
  assign fifo_dout = {dat_in_dly, dat_in};
  assign sd_busy = ~dat_in[0];

  assign din = count[0] ? fifo_din[3:0] : fifo_din[7:4];

  //instatiate the crc units
  crc_16 crc_16_wr0 (din[0], !send_crc, sd_clk, dat_oe, crc_write0);
  crc_16 crc_16_wr1 (din[1], !send_crc, sd_clk, dat_oe, crc_write1);
  crc_16 crc_16_wr2 (din[2], !send_crc, sd_clk, dat_oe, crc_write2);
  crc_16 crc_16_wr3 (din[3], !send_crc, sd_clk, dat_oe, crc_write3);

  crc_16 crc_16_rd0 (dat_in[0], crc_read_en, sd_clk, ~rec_busy, crc_read0);
  crc_16 crc_16_rd1 (dat_in[1], crc_read_en, sd_clk, ~rec_busy, crc_read1);
  crc_16 crc_16_rd2 (dat_in[2], crc_read_en, sd_clk, ~rec_busy, crc_read2);
  crc_16 crc_16_rd3 (dat_in[3], crc_read_en, sd_clk, ~rec_busy, crc_read3);




  // sd input synchronizers
  always @ (posedge sd_clk or posedge reset) begin
    if (reset) begin
      dat_in <= 4'hf;
    end else begin
      dat_in <= sd_dat_in;
    end
  end

  // sd output registers (clocked on negative edge!)
  always @ (negedge sd_clk or posedge reset) begin
    if (reset) begin
      sd_dat_out <= 4'b1111;
      sd_dat_oe <= 1'b1;
    end else begin
      sd_dat_out <= {dat_out3, dat_out2, dat_out1, dat_out0};
      sd_dat_oe <= dat_oe;
    end
  end

  // control signal input synchronizers
  always @ (posedge sd_clk or posedge reset) begin
    if (reset) begin
      sd_write_enable_d <= 1'b0;
      sd_read_enable_d <= 1'b0;
      wide_width_data_d <= 1'b0;
    end else begin
      sd_write_enable_d <= sd_write_enable;
      sd_read_enable_d <= sd_read_enable;
      wide_width_data_d <= wide_width_data;
    end
  end
  always @ (posedge sd_clk or posedge reset) begin
    if (reset) begin
      state <= IDLE;
      dat_oe <= 1'b1;
      dat_out0 <= 1'b0;
      dat_out1 <= 1'b0;
      dat_out2 <= 1'b0;
      dat_out3 <= 1'b0;
      send_crc <= 1'b0;
      count <= 11'd0;
      crc_status <= 5'b00000;
      send_busy <= 1'b0;
      rec_busy <= 1'b0;
      crc_ok <= 1'b0;
      crc_read_en <= 1'b0;
      dat_in_dly <= 4'h0;
    end else begin
      state <= next_state;
      dat_oe <= next_dat_oe;
      dat_out0 <= next_dat_out0;
      dat_out1 <= next_dat_out1;
      dat_out2 <= next_dat_out2;
      dat_out3 <= next_dat_out3;
      send_crc <= next_send_crc;
      count <= next_count;
      crc_status <= next_crc_status;
      send_busy <= next_send_busy;
      rec_busy <= next_rec_busy;
      crc_ok <= next_crc_ok;
      crc_read_en <= next_crc_read_en;
      dat_in_dly <= dat_in;
    end
  end

  always @ * begin
    next_state = state;
    next_crc_status = crc_status;
    next_send_busy = send_busy;
    next_rec_busy = rec_busy;
    next_crc_ok = crc_ok;
    next_crc_read_en = crc_read_en;
    next_dat_oe = 1'b1;
    fifo_rd = 1'b0;
    fifo_wr = 1'b0;
    next_dat_out0 = 1'b0;
    next_dat_out1 = 1'b0;
    next_dat_out2 = 1'b0;
    next_dat_out3 = 1'b0;
    next_send_crc = 1'b0;
    next_count = 11'd0;
    case(state)                                            
      IDLE: begin
        if (sd_write_enable_d && block_available) begin
          next_send_busy = 1'b1;
          next_dat_oe = 1'b0;
          fifo_rd = 1'b1;
          next_count = 11'd1040; // start, 2*512 data, crc, stop
          next_state = WRITE;
        end else if (sd_read_enable_d && dat_oe && (dat_in == 4'b0000)) begin
          next_rec_busy = 1'b1;
          next_crc_read_en = 1'b1;
          next_crc_ok = 1'b0;
          next_count = (wide_width_data_d ? 11'd144 : 11'd1040);
          next_state = READ;
        end
      end
      WRITE: begin
        next_dat_oe = 1'b0;
        fifo_rd = count[0];
        next_dat_out0 = din[0];
        next_dat_out1 = din[1];
        next_dat_out2 = din[2];
        next_dat_out3 = din[3];
        next_count = count - 1'b1;
        if (count == 11'd17) begin
          fifo_rd = 1'b0;
          next_send_crc = 1'b1;
          next_state = WRITE_CRC;
        end
      end
      WRITE_CRC: begin
        next_crc_status = 5'b00000;
        next_crc_ok = 1'b0;
        next_dat_oe = 1'b0;
        next_send_crc = 1'b1;
        next_count = count - 1'b1;
        next_dat_out0 = send_crc ? crc_write0[count] : 1'b1;
        next_dat_out1 = send_crc ? crc_write1[count] : 1'b1;
        next_dat_out2 = send_crc ? crc_write2[count] : 1'b1;
        next_dat_out3 = send_crc ? crc_write3[count] : 1'b1;
        if (count == 11'd1)
          next_send_crc = 1'b0;
        else if (count == 11'd0) begin
          next_count = 11'd9;
          next_state = CHECK_CRC;
        end
      end
      CHECK_CRC: begin
        if (count == 11'd0) begin
          if (dat_in[0]) begin
            next_crc_ok = (crc_status == 5'b00101);
            next_send_busy = 1'b0;
            next_state = IDLE;
          end
        end else begin
          next_count = count - 1'b1;
          next_crc_status = {crc_status[3:0], dat_in[0]};
        end
      end
      READ: begin
        if (count == 11'd0) begin
          next_rec_busy = 1'b0;
          next_state = IDLE;
        end else begin
          next_count = count - 1'b1;
          if (!crc_read_en) begin
            next_crc_ok = crc_ok && 
            (crc_read0[count] == dat_in[0]) &&
            (crc_read1[count] == dat_in[1]) &&
            (crc_read2[count] == dat_in[2]) &&
            (crc_read3[count] == dat_in[3]);
          end else begin
            fifo_wr = count[0];
          end
          if (count == 11'd17) begin
            next_crc_ok = 1'b1;
            next_crc_read_en = 1'b0;
          end
        end
      end
      default: next_state = IDLE;
    endcase     
  end 


endmodule



