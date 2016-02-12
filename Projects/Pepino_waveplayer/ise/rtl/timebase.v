/***************************************************************************************************
*  timebase.v
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
module timebase
(
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


  input                                   Bus2IP_Clk;
  input                                   Bus2IP_Reset;
  input      [31:0]                       Bus2IP_Data;
  input      [3:0]                        Bus2IP_BE;
  input      [1:0]                        Bus2IP_Adr;
  input                                   Bus2IP_RD;
  input                                   Bus2IP_WR;
  input                                   Bus2IP_CS;
  output     [31:0]                       IP2Bus_Data;
  output                                  IP2Bus_RdAck;
  output                                  IP2Bus_WrAck;

  reg        [7:0]                        clkCounter1;
  reg        [9:0]                        clkCounter2;
  reg        [31:0]                       clkCounter3;
  reg        [31:0]                       micros, millis;
  reg                                     inc_delay;
  reg                                     clr_delay;
  reg                                     delay_to;
  wire                                    counterEnable;
  wire       [7:0]                        clkFreq;

  reg        [15:0]                       delayControl;
  reg        [31:0]                       delay;
  reg        [3:0]                        rdCE, wrCE;
  wire       [3:0]                        slv_reg_write_sel;
  wire       [3:0]                        slv_reg_read_sel;
  reg        [31:0]                       slv_ip2bus_data;
  wire                                    slv_read_ack;
  wire                                    slv_write_ack;
  integer                                 byte_index, bit_index;

  assign clkFreq = delayControl[7:0];
  assign counterEnable = delayControl[8];
  
  always @( posedge Bus2IP_Clk )
    begin
      if ( counterEnable == 1'b0 )
        begin
          clkCounter1 <= 0;
          clkCounter2 <= 0;
          inc_delay <= 0;
          micros <= 0;
          millis <= 0;
        end
      else
        begin
          if (clkCounter1 >= clkFreq)
            begin
              inc_delay <= 1;
              micros <= micros + 1;
              clkCounter1 <= 1;
              if (clkCounter2 == 999)
                begin
                  millis <= millis + 1;
                  clkCounter2 <= 0;
                end
              else
                clkCounter2 <= clkCounter2 + 1;
            end
          else
            begin
              clkCounter1 <= clkCounter1 + 1;
              inc_delay <= 0;
            end
        end
    end        

  always @( posedge Bus2IP_Clk )
    begin
      if ((counterEnable == 1'b0) || (clr_delay == 1'b1))
        begin
          delay_to <= 0;
          clkCounter3 <= 1;
        end
      else if (inc_delay == 1'b1)
        begin
          if (clkCounter3 >= delay)
            delay_to <= 1;
          else 
            clkCounter3 <= clkCounter3 + 1;
        end
    end

  always @ * begin
    if (Bus2IP_RD & Bus2IP_CS)
      case (Bus2IP_Adr)
        2'b00: rdCE = 4'b1000;
        2'b01: rdCE = 4'b0100;
        2'b10: rdCE = 4'b0010;
        2'b11: rdCE = 4'b0001;
      endcase
    else
      rdCE = 4'b0000;
  end

  always @ * begin
    if (Bus2IP_WR & Bus2IP_CS)
      case (Bus2IP_Adr)
        2'b00: wrCE = 4'b1000;
        2'b01: wrCE = 4'b0100;
        2'b10: wrCE = 4'b0010;
        2'b11: wrCE = 4'b0001;
      endcase
    else
      wrCE = 4'b0000;
  end

  assign
    slv_reg_write_sel = wrCE[3:0],
    slv_reg_read_sel  = rdCE[3:0],
    slv_write_ack     = wrCE[0] || wrCE[1] || wrCE[2] || wrCE[3],
    slv_read_ack      = rdCE[0] || rdCE[1] || rdCE[2] || rdCE[3];

  always @( posedge Bus2IP_Clk )
    begin
      if ( Bus2IP_Reset == 1'b1 )
        begin
          delayControl <= 0;
          delay <= 0;
          clr_delay <= 0;
        end
      else
        begin
          clr_delay <= 0;
          case ( slv_reg_write_sel )
            4'b1000 :
              for ( byte_index = 0; byte_index <= 1; byte_index = byte_index+1 )
                if ( Bus2IP_BE[byte_index] == 1 )
                  delayControl[(byte_index*8) +: 8] <= Bus2IP_Data[(byte_index*8) +: 8];
            4'b0100 : begin
              clr_delay <= 1;
              for ( byte_index = 0; byte_index <= (32/8)-1; byte_index = byte_index+1 )
                if ( Bus2IP_BE[byte_index] == 1 )
                  delay[(byte_index*8) +: 8] <= Bus2IP_Data[(byte_index*8) +: 8];
              end
            default : begin
              delayControl <= delayControl;
              delay <= delay;
            end
          endcase
        end
    end


  always @( slv_reg_read_sel or delay_to or counterEnable or clkFreq or delay or micros or millis )
    begin 
      case ( slv_reg_read_sel )
        4'b1000 : slv_ip2bus_data <= {delay_to, counterEnable, clkFreq};
        4'b0100 : slv_ip2bus_data <= delay;
        4'b0010 : slv_ip2bus_data <= micros;
        4'b0001 : slv_ip2bus_data <= millis;
        default : slv_ip2bus_data <= 0;
      endcase
    end


  assign IP2Bus_Data = (slv_read_ack == 1'b1) ? slv_ip2bus_data :  0 ;
  assign IP2Bus_WrAck = slv_write_ack;
  assign IP2Bus_RdAck = slv_read_ack;

endmodule
