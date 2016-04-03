/***************************************************************************************************
*  echo.v
*
*  Copyright (c) 2013, Magnus Karlsson
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
module echo (
  clock,     // 50 MHz input clock
  rx,        // incoming serial data from FTDI chip
  tx,        // outgoing serial data to FTDI chip
  rx_led,
  tx_led
);

input clock;
input rx;
output tx;
output rx_led;
output tx_led;

parameter [31:0] FREQ = 50000000; // incoming clock frequency
parameter [31:0] RATE = 115200; // desired baud rate
parameter BITLENGTH = FREQ / RATE;

parameter [1:0]
  RX_IDLE = 2'h0,
  RX_START = 2'h1,
  RX_RECEIVE = 2'h2,
  RX_STOP = 2'h3;

  parameter [1:0]
  TX_IDLE = 2'h0,
  TX_START = 2'h1,
  TX_SEND = 2'h2,
  TX_STOP = 2'h3;

assign rx_led = ~rx;
assign tx_led = ~tx;

//
// reset logic
//
  
reg [3:0] reset_reg;
wire reset = reset_reg[3];

initial reset_reg = 4'b1111;
always @ (posedge clock)
begin
  reset_reg <= {reset_reg[2:0],1'b0};
end
  
  
//
// Receive UART
//

reg [1:0] rx_state, next_rx_state;
reg [9:0] rx_count, next_rx_count;
reg [2:0] rx_bitcount, next_rx_bitcount;
reg [7:0] rxByte, next_rxByte;
reg byteready, next_byteready;

always @(posedge clock or posedge reset) 
begin
  if (reset) begin
    rx_state <= RX_IDLE;
    rx_bitcount <= 3'b0;
    rxByte <= 8'b0;
    byteready <= 1'b0;
    rx_count <= 10'd0;
  end else begin 
    rx_state <= next_rx_state;
    rx_bitcount <= next_rx_bitcount;
    rxByte <= next_rxByte;
    byteready <= next_byteready;
    rx_count <= next_rx_count;
  end
end

always @* 
begin
  next_rx_state = rx_state;
  next_rx_bitcount = rx_bitcount;
  next_rxByte = rxByte;
  next_byteready = 1'b0;
  next_rx_count = 0;

  case(rx_state)
    RX_IDLE: begin
      if (!rx) begin
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
        next_rx_bitcount = rx_bitcount + 1'b1;
        next_rxByte = {rx, rxByte[7:1]};
        if (rx_bitcount == 3'd7)
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
// Memory and control for storing and retrieving data
//

reg [10:0] wr_pointer, rd_pointer, rd_stop;
reg [7:0] ram [0:2047];
reg [7:0] data_out;
reg data_available;


always @(posedge clock or posedge reset)
begin
  if (reset) begin
    wr_pointer <= 11'd0;
    rd_stop <= 11'd0;
  end else if (byteready) begin
    ram[wr_pointer] <= rxByte;
    wr_pointer <= wr_pointer + 1'b1;
    if (rxByte == 8'h0d) // carrage return, advance the stop pointer
      rd_stop <= wr_pointer + 1'b1;
  end
end

assign stop = (rd_pointer == rd_stop); // send data if not stop

always @(posedge clock or posedge reset)
begin
  if (reset) begin
    data_out <= 0;
    rd_pointer <= 11'd0;
    data_available <= 1'b0;
  end else if (~stop & byteDone & ~data_available) begin
    data_out <= ram[rd_pointer];
    rd_pointer <= rd_pointer + 1'b1;
    data_available <= 1'b1;
  end else
    data_available <= 1'b0;
end




//
// Transmit UART
//

reg [1:0] tx_state, next_tx_state;
reg [9:0] tx_count, next_tx_count;
reg [2:0] tx_bitcount, next_tx_bitcount;
reg [7:0] txByte, next_txByte;
reg tx, next_tx;
reg byteDone, next_byteDone;

always @(posedge clock or posedge reset) 
begin
  if (reset) begin
    tx_state <= TX_IDLE;
    tx_bitcount <= 3'b0;
    txByte <= 8'b0;
    byteDone <= 1'b1;
    tx_count <= 10'd0;
    tx <= 1'b1;
  end else begin 
    tx_state <= next_tx_state;
    tx_bitcount <= next_tx_bitcount;
    txByte <= next_txByte;
    byteDone <= next_byteDone;
    tx_count <= next_tx_count;
    tx <= next_tx;
  end
end

always @*
begin
  next_tx_state = tx_state;
  next_tx_bitcount = tx_bitcount;
  next_txByte = txByte;
  next_byteDone = 1'b1;
  next_tx_count = 0;
  next_tx = tx;

  case(tx_state)
    TX_IDLE: begin
      next_tx = 1'b1;
      next_tx_bitcount = 0;
      if (data_available) begin
        next_tx_state = TX_START;
        next_byteDone = 0;
        next_txByte = data_out;
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
        next_tx_bitcount = tx_bitcount + 1'b1;
        if (tx_bitcount == 3'd7) begin
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
        next_tx_bitcount = tx_bitcount + 1'b1;
        if (tx_bitcount == 3'd1) begin
          next_tx_state = TX_IDLE;
          next_byteDone = 1'b1;
        end
      end
    end
  endcase
end

endmodule
