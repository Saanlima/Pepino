/***************************************************************************************************
*  sound.v
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
module sound(
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
  IP2Bus_WrAck,                   // IP to Bus write transfer acknowledgement
  IP2Bus_Int,                     // IP to Bus interrupt
  audio_left,                     // left channel output
  audio_right                     // right channel output
  );

  input         Bus2IP_Clk;
  input         Bus2IP_Reset;
  input [31:0]  Bus2IP_Data;
  input [3:0]   Bus2IP_BE;
  input [1:0]   Bus2IP_Adr;
  input         Bus2IP_RD;
  input         Bus2IP_WR;
  input         Bus2IP_CS;
  output [31:0] IP2Bus_Data;
  output        IP2Bus_RdAck;
  output        IP2Bus_WrAck;
  output        IP2Bus_Int;
  output        audio_left;
  output        audio_right;

  reg [15:0] period;
  reg go, int_en;
  reg [31:0] slv_ip2bus_data;
  wire fifo_we;
  reg fifo_we_d;
  wire [31:0] fifo_din, fifo_dout;
  wire stop;
  reg [15:0] counter;
  reg fifo_rd;
  reg [11:0] leftValue, rightValue;

  always @(posedge Bus2IP_Clk) begin
    if (Bus2IP_Reset) begin
      period <= 16'd0;
      go <= 0;
    end else if (Bus2IP_CS & Bus2IP_WR) begin
      if ((Bus2IP_Adr == 2'b00) && (Bus2IP_BE[1:0] == 2'b11))
        period <= Bus2IP_Data[15:0];
      if ((Bus2IP_Adr == 2'b01) && (Bus2IP_BE[0] == 1'b1)) begin
        go <= Bus2IP_Data[0];
        int_en <= Bus2IP_Data[1];
      end
    end
  end

  always @(*)
    case(Bus2IP_Adr) // synopsys full_case parallel_case
      2'b00: slv_ip2bus_data = {16'd0, period};
      2'b01: slv_ip2bus_data = {30'd0, int_en, go};
      2'b10: slv_ip2bus_data = {31'd0, fifo_full};
      2'b11: slv_ip2bus_data = 32'd0;
      default: slv_ip2bus_data = 32'd0;      
    endcase


  assign fifo_we = Bus2IP_CS & Bus2IP_WR & ((Bus2IP_Adr == 2'b11) && (Bus2IP_BE[3:0] == 4'b1111));
  assign fifo_din = Bus2IP_Data[31:0];
  assign stop = ~go;
  assign IP2Bus_Int = ~fifo_full & int_en;
  assign IP2Bus_RdAck = Bus2IP_CS & Bus2IP_RD;
  assign IP2Bus_WrAck = Bus2IP_CS & Bus2IP_WR;
  assign IP2Bus_Data = (IP2Bus_RdAck == 1'b1) ? slv_ip2bus_data :  0 ;

  
  sound_fifo sound_fifo(
    .clk(Bus2IP_Clk),
    .srst(stop),
    .din(fifo_din),
    .wr_en(fifo_we & !fifo_we_d),
    .rd_en(fifo_rd),
    .dout(fifo_dout),
    .full(),
    .empty(fifo_empty),
    .prog_full(fifo_full)
  );

  always @(posedge Bus2IP_Clk) begin
    if (stop) begin
      counter <= 0;
      fifo_rd <= 0;
      leftValue <= 0;
      rightValue <= 0;
      fifo_we_d <= 0;
    end else begin
      fifo_we_d <= fifo_we;
      if (counter == period) begin
        counter <= 0;
        fifo_rd <= 1;
      end else begin
        counter <= counter + 1;
        fifo_rd <= 0;
      end
      if (fifo_rd & !fifo_empty) begin
        leftValue <= fifo_dout[15:4];
        rightValue <= fifo_dout[31:20];
      end
    end
  end

  dac left_dac(
    .DACout(audio_left), 
    .DACin(leftValue), 
    .clock(Bus2IP_Clk)
  );
  
  dac right_dac(
    .DACout(audio_right), 
    .DACin(rightValue), 
    .clock(Bus2IP_Clk)
  );
  
endmodule
