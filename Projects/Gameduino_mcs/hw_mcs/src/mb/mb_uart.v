/***************************************************************************************************
*  mb_uart.v
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
module mb_uart
(
  UART_tx,
  UART_rx,
  UART_int,
  Bus2IP_Clk,                     // Bus to IP clock
  Bus2IP_Reset,                   // Bus to IP reset
  Bus2IP_Data,                    // Bus to IP data bus
  Bus2IP_BE,                      // Bus to IP byte enables
  Bus2IP_Adr,                     // Bus to IP address bus
  Bus2IP_RD,                      // Bus to IP read enable
  Bus2IP_WR,                      // Bus to IP write enable
  Bus2IP_CS,                      // Bus to IP chip select
  IP2Bus_Data,                    // IP to Bus data bus
  IP2Bus_RdAck,                   // IP to Bus read transfer acknowledgement
  IP2Bus_WrAck                    // IP to Bus write transfer acknowledgement
);


  output                     UART_tx;
  input                      UART_rx;
  output                     UART_int;

  input                      Bus2IP_Clk;
  input                      Bus2IP_Reset;
  input      [31:0]          Bus2IP_Data;
  input      [3:0]           Bus2IP_BE;
  input      [1:0]           Bus2IP_Adr;
  input                      Bus2IP_RD;
  input                      Bus2IP_WR;
  input                      Bus2IP_CS;
  output     [31:0]          IP2Bus_Data;
  output                     IP2Bus_RdAck;
  output                     IP2Bus_WrAck;

  reg        [15:0]          baud_count;
  reg  		                   en_16_x_baud;
  wire                       tx_data_present;
  wire  	                   tx_full;
  wire  	                   tx_half_full;
  wire       [7:0] 	         rx_data;
  wire  	                   rx_data_present;
  wire  	                   rx_full;
  wire  	                   rx_half_full;
  wire                       write_to_uart;
  wire                       read_from_uart;
  wire                       uart_enable;
  wire                       rx_interrupt_enable;
  wire                       tx_interrupt_enable;

  wire       [1:0]           uart_rx_status;
  wire       [2:0]           uart_tx_status;

  reg        [2:0]           uart_control;
  reg        [15:0]          baud_control;
  reg        [2:0]           rdCE, wrCE;
  wire       [2:0]           slv_reg_write_sel;
  wire       [2:0]           slv_reg_read_sel;
  reg        [31:0]          slv_ip2bus_data;
  wire                       slv_read_ack;
  wire                       slv_write_ack;
  
  integer                    byte_index, bit_index;

  assign uart_rx_status = {rx_data_present,rx_full};
  assign uart_tx_status = {tx_data_present,tx_full,tx_half_full};
  
  always @ * begin
    if (Bus2IP_RD & Bus2IP_CS)
      case (Bus2IP_Adr)
        2'b00: rdCE = 3'b100;
        2'b01: rdCE = 3'b010;
        2'b10: rdCE = 3'b001;
        2'b11: rdCE = 3'b000;
      endcase
    else
      rdCE = 4'b0000;
  end

  always @ * begin
    if (Bus2IP_WR & Bus2IP_CS)
      case (Bus2IP_Adr)
        2'b00: wrCE = 3'b100;
        2'b01: wrCE = 3'b010;
        2'b10: wrCE = 3'b001;
        2'b11: wrCE = 3'b000;
      endcase
    else
      wrCE = 4'b0000;
  end

  assign
    slv_reg_write_sel = wrCE[2:0],
    slv_reg_read_sel  = rdCE[2:0],
    slv_write_ack     = wrCE[0] || wrCE[1] || wrCE[2],
    slv_read_ack      = rdCE[0] || rdCE[1] || rdCE[2];

  assign uart_enable = uart_control[2];
  assign rx_interrupt_enable = uart_control[1];
  assign tx_interrupt_enable = uart_control[0];
  assign write_to_uart = slv_reg_write_sel[2] & Bus2IP_BE[0];
  assign read_from_uart = slv_reg_read_sel[2] & Bus2IP_BE[0];
  assign UART_int = uart_enable & ((rx_interrupt_enable & rx_data_present) | (tx_interrupt_enable & ~tx_half_full));

  always @( posedge Bus2IP_Clk )
    begin
      if ( Bus2IP_Reset == 1'b1 )
        begin
          uart_control <= 0;
          baud_control <= 0;
        end
      else
        case ( slv_reg_write_sel )
          3'b010 :
            if ( Bus2IP_BE[0] == 1 )
              uart_control <= Bus2IP_Data[7:5];
          3'b001 :
            for ( byte_index = 0; byte_index <= 1; byte_index = byte_index+1 )
              if ( Bus2IP_BE[byte_index] == 1 )
                baud_control[(byte_index*8) +: 8] <= Bus2IP_Data[(byte_index*8) +: 8];
          default :
            begin
              uart_control <= uart_control;
              baud_control <= baud_control;
            end
        endcase
    end
    
  always @( * )
    begin 

      case ( slv_reg_read_sel )
        3'b100 : slv_ip2bus_data <= rx_data;
        3'b010 : slv_ip2bus_data <= {rx_data, uart_enable, rx_interrupt_enable, tx_interrupt_enable, uart_rx_status, uart_tx_status};
        3'b001 : slv_ip2bus_data <= baud_control;
        default : slv_ip2bus_data <= 0;
      endcase

    end

  assign IP2Bus_Data = (slv_read_ack == 1'b1) ? slv_ip2bus_data :  0 ;
  assign IP2Bus_WrAck = slv_write_ack;
  assign IP2Bus_RdAck = slv_read_ack;

  always @(posedge Bus2IP_Clk) begin
    if (Bus2IP_Reset | slv_reg_write_sel[0]) begin
      baud_count <= 16'b0;
      en_16_x_baud <= 1'b0;
    end else begin
      if (baud_count == baud_control) begin
        baud_count <= 16'b0;
        en_16_x_baud <= 1'b1;
      end else begin
        baud_count <= baud_count + 1;
        en_16_x_baud <= 1'b0;
      end
    end
  end

/////////////////////////////////////////////////////////////////////////////////////////
// UART Transmitter with integral 16 byte FIFO buffer
/////////////////////////////////////////////////////////////////////////////////////////
uart_tx6 transmit
(	.data_in(Bus2IP_Data[7:0]),
  .buffer_write(write_to_uart),
  .buffer_reset(~uart_enable),
  .en_16_x_baud(en_16_x_baud),
  .serial_out(UART_tx),
  .buffer_data_present(tx_data_present),
  .buffer_full(tx_full),
  .buffer_half_full(tx_half_full),
  .clk(Bus2IP_Clk)
);

/////////////////////////////////////////////////////////////////////////////////////////
// UART Receiver with integral 16 byte FIFO buffer
/////////////////////////////////////////////////////////////////////////////////////////
uart_rx6 receive
(	.serial_in(UART_rx),
  .data_out(rx_data),
  .buffer_read(read_from_uart),
  .buffer_reset(~uart_enable),
  .en_16_x_baud(en_16_x_baud),
  .buffer_data_present(rx_data_present),
  .buffer_full(rx_full),
  .buffer_half_full(rx_half_full),
  .clk(Bus2IP_Clk)
);

endmodule
