/***************************************************************************************************
*  wing.v
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
module wing
(
  wing_in,                        // Wing interface
  wing_out,
  wing_dir,
  wing_int,
  wing_led1,
  wing_led2,
  wing_led3,
  wing_led4,

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


  input      [15:0]      wing_in;
  output     [15:0]      wing_out;
  output     [15:0]      wing_dir;
  output                 wing_int;
  output                 wing_led1;
  output                 wing_led2;
  output                 wing_led3;
  output                 wing_led4;

  input                  Bus2IP_Clk;
  input                  Bus2IP_Reset;
  input      [31:0]      Bus2IP_Data;
  input      [3:0]       Bus2IP_BE;
  input      [4:0]       Bus2IP_Adr;
  input                  Bus2IP_RD;
  input                  Bus2IP_WR;
  input                  Bus2IP_CS;
  output     [31:0]      IP2Bus_Data;
  output                 IP2Bus_RdAck;
  output                 IP2Bus_WrAck;

  wire       [15:0]      wing_in;   // pins
  wire       [15:0]      wing_out;  // port
  wire       [15:0]      wing_dir;  // dir
  wire                   wing_int;  // interrupt
  reg        [15:0]      wing_in_d; // registered pins
  reg        [15:0]      wing_in_d2; 
  reg        [31:0]      rdCE, wrCE;
  reg        [15:0]      port;
  reg        [15:0]      dir;
  reg        [15:0]      pwm0;
  reg        [15:0]      pwm1;
  reg        [15:0]      pwm2;
  reg        [15:0]      pwm3;
  reg        [15:0]      pwm4;
  reg        [15:0]      pwm5;
  reg        [15:0]      pwm6;
  reg        [15:0]      pwm7;
  reg        [15:0]      pwm8;
  reg        [15:0]      pwm9;
  reg        [15:0]      pwm10;
  reg        [15:0]      pwm11;
  reg        [15:0]      pwm12;
  reg        [15:0]      pwm13;
  reg        [15:0]      pwm14;
  reg        [15:0]      pwm15;
  reg        [15:0]      pwm_en;
  reg        [31:0]      int_sel;
  reg        [15:0]      int_flag, next_int_flag;
  reg        [15:0]      led_map;
  wire       [31:0]      slv_reg_write_sel;
  wire       [31:0]      slv_reg_read_sel;
  reg        [31:0]      slv_ip2bus_data;
  wire                   slv_read_ack;
  wire                   slv_write_ack;
  reg        [31:0]      slv_write_data;
  reg        [3:0]       slv_write_be;
  integer                byte_index, bit_index;

  reg        [15:0]      pwm_counter;
  wire       [15:0]      pwm_out;
  wire                   pwm0_out;
  wire                   pwm1_out;
  wire                   pwm2_out;
  wire                   pwm3_out;
  wire                   pwm4_out;
  wire                   pwm5_out;
  wire                   pwm6_out;
  wire                   pwm7_out;
  wire                   pwm8_out;
  wire                   pwm9_out;
  wire                   pwm10_out;
  wire                   pwm11_out;
  wire                   pwm12_out;
  wire                   pwm13_out;
  wire                   pwm14_out;
  wire                   pwm15_out;
  wire       [3:0]       led1_select;
  wire       [3:0]       led2_select;
  wire       [3:0]       led3_select;
  wire       [3:0]       led4_select;


  always @( posedge Bus2IP_Clk )
    begin
      wing_in_d <= wing_in;
      wing_in_d2 <= wing_in_d;
    end
 
  // interrupt detect logic
  always @ (*)
    begin
      next_int_flag = int_flag;
      for ( bit_index = 0; bit_index <= 16-1; bit_index = bit_index+1 )
        if ( ((wing_in_d2[bit_index] == 0) && (wing_in_d[bit_index] == 1) && (int_sel[bit_index*2] == 1)) || // rising edge
             ((wing_in_d2[bit_index] == 1) && (wing_in_d[bit_index] == 0) && (int_sel[bit_index*2 + 1] == 1)) ) // falling edge
          next_int_flag[bit_index] = 1;
    end

  // interrupt generation
  assign wing_int = |int_flag;
 

  // pwm counter and comparators
  always @( posedge Bus2IP_Clk )
    if ( Bus2IP_Reset == 1'b1 )
      pwm_counter <= 0;
    else
      pwm_counter <= pwm_counter + 1;

  assign pwm0_out = (pwm0 > pwm_counter) && pwm_en[0];
  assign pwm1_out = (pwm1 > pwm_counter) && pwm_en[1];
  assign pwm2_out = (pwm2 > pwm_counter) && pwm_en[2];
  assign pwm3_out = (pwm3 > pwm_counter) && pwm_en[3];
  assign pwm4_out = (pwm4 > pwm_counter) && pwm_en[4];
  assign pwm5_out = (pwm5 > pwm_counter) && pwm_en[5];
  assign pwm6_out = (pwm6 > pwm_counter) && pwm_en[6];
  assign pwm7_out = (pwm7 > pwm_counter) && pwm_en[7];
  assign pwm8_out = (pwm8 > pwm_counter) && pwm_en[8];
  assign pwm9_out = (pwm9 > pwm_counter) && pwm_en[9];
  assign pwm10_out = (pwm10 > pwm_counter) && pwm_en[10];
  assign pwm11_out = (pwm11 > pwm_counter) && pwm_en[11];
  assign pwm12_out = (pwm12 > pwm_counter) && pwm_en[12];
  assign pwm13_out = (pwm13 > pwm_counter) && pwm_en[13];
  assign pwm14_out = (pwm14 > pwm_counter) && pwm_en[14];
  assign pwm15_out = (pwm15 > pwm_counter) && pwm_en[15];
  
  assign pwm_out = {pwm15_out,pwm14_out,pwm13_out,pwm12_out,pwm11_out,pwm10_out,pwm9_out,pwm8_out,pwm7_out,pwm6_out,pwm5_out,pwm4_out,pwm3_out,pwm2_out,pwm1_out,pwm0_out};

  assign wing_out = (port & ~pwm_en) | (pwm_out & pwm_en);
  assign wing_dir = ~(dir | pwm_en);
  
  assign led1_select = led_map[3:0];
  assign led2_select = led_map[7:4];
  assign led3_select = led_map[11:8];
  assign led4_select = led_map[15:12];

  assign wing_led1 = wing_in_d[led1_select];
  assign wing_led2 = wing_in_d[led2_select];
  assign wing_led3 = wing_in_d[led3_select];
  assign wing_led4 = wing_in_d[led4_select];


  always @( posedge Bus2IP_Clk )
    if (Bus2IP_WR) begin
      slv_write_data <= Bus2IP_Data;
      slv_write_be <= Bus2IP_BE;
    end

  always @ ( posedge Bus2IP_Clk ) begin
    if (Bus2IP_RD & Bus2IP_CS)
      case (Bus2IP_Adr)
        5'b00000: rdCE <= 32'b10000000000000000000000000000000;
        5'b00001: rdCE <= 32'b01000000000000000000000000000000;
        5'b00010: rdCE <= 32'b00100000000000000000000000000000;
        5'b00011: rdCE <= 32'b00010000000000000000000000000000;
        5'b00100: rdCE <= 32'b00001000000000000000000000000000;
        5'b00101: rdCE <= 32'b00000100000000000000000000000000;
        5'b00110: rdCE <= 32'b00000010000000000000000000000000;
        5'b00111: rdCE <= 32'b00000001000000000000000000000000;
        5'b01000: rdCE <= 32'b00000000100000000000000000000000;
        5'b01001: rdCE <= 32'b00000000010000000000000000000000;
        5'b01010: rdCE <= 32'b00000000001000000000000000000000;
        5'b01011: rdCE <= 32'b00000000000100000000000000000000;
        5'b01100: rdCE <= 32'b00000000000010000000000000000000;
        5'b01101: rdCE <= 32'b00000000000001000000000000000000;
        5'b01110: rdCE <= 32'b00000000000000100000000000000000;
        5'b01111: rdCE <= 32'b00000000000000010000000000000000;
        5'b10000: rdCE <= 32'b00000000000000001000000000000000;
        5'b10001: rdCE <= 32'b00000000000000000100000000000000;
        5'b10010: rdCE <= 32'b00000000000000000010000000000000;
        5'b10011: rdCE <= 32'b00000000000000000001000000000000;
        5'b10100: rdCE <= 32'b00000000000000000000100000000000;
        5'b10101: rdCE <= 32'b00000000000000000000010000000000;
        5'b10110: rdCE <= 32'b00000000000000000000001000000000;
        5'b10111: rdCE <= 32'b00000000000000000000000100000000;
        5'b11000: rdCE <= 32'b00000000000000000000000010000000;
        5'b11001: rdCE <= 32'b00000000000000000000000001000000;
        5'b11010: rdCE <= 32'b00000000000000000000000000100000;
        5'b11011: rdCE <= 32'b00000000000000000000000000010000;
        5'b11100: rdCE <= 32'b00000000000000000000000000001000;
        5'b11101: rdCE <= 32'b00000000000000000000000000000100;
        5'b11110: rdCE <= 32'b00000000000000000000000000000010;
        5'b11111: rdCE <= 32'b00000000000000000000000000000001;
      endcase
    else
      rdCE <= 32'b00000000000000000000000000000000;
  end

  always @ ( posedge Bus2IP_Clk ) begin
    if (Bus2IP_WR & Bus2IP_CS)
      case (Bus2IP_Adr)
        5'b00000: wrCE <= 32'b10000000000000000000000000000000;
        5'b00001: wrCE <= 32'b01000000000000000000000000000000;
        5'b00010: wrCE <= 32'b00100000000000000000000000000000;
        5'b00011: wrCE <= 32'b00010000000000000000000000000000;
        5'b00100: wrCE <= 32'b00001000000000000000000000000000;
        5'b00101: wrCE <= 32'b00000100000000000000000000000000;
        5'b00110: wrCE <= 32'b00000010000000000000000000000000;
        5'b00111: wrCE <= 32'b00000001000000000000000000000000;
        5'b01000: wrCE <= 32'b00000000100000000000000000000000;
        5'b01001: wrCE <= 32'b00000000010000000000000000000000;
        5'b01010: wrCE <= 32'b00000000001000000000000000000000;
        5'b01011: wrCE <= 32'b00000000000100000000000000000000;
        5'b01100: wrCE <= 32'b00000000000010000000000000000000;
        5'b01101: wrCE <= 32'b00000000000001000000000000000000;
        5'b01110: wrCE <= 32'b00000000000000100000000000000000;
        5'b01111: wrCE <= 32'b00000000000000010000000000000000;
        5'b10000: wrCE <= 32'b00000000000000001000000000000000;
        5'b10001: wrCE <= 32'b00000000000000000100000000000000;
        5'b10010: wrCE <= 32'b00000000000000000010000000000000;
        5'b10011: wrCE <= 32'b00000000000000000001000000000000;
        5'b10100: wrCE <= 32'b00000000000000000000100000000000;
        5'b10101: wrCE <= 32'b00000000000000000000010000000000;
        5'b10110: wrCE <= 32'b00000000000000000000001000000000;
        5'b10111: wrCE <= 32'b00000000000000000000000100000000;
        5'b11000: wrCE <= 32'b00000000000000000000000010000000;
        5'b11001: wrCE <= 32'b00000000000000000000000001000000;
        5'b11010: wrCE <= 32'b00000000000000000000000000100000;
        5'b11011: wrCE <= 32'b00000000000000000000000000010000;
        5'b11100: wrCE <= 32'b00000000000000000000000000001000;
        5'b11101: wrCE <= 32'b00000000000000000000000000000100;
        5'b11110: wrCE <= 32'b00000000000000000000000000000010;
        5'b11111: wrCE <= 32'b00000000000000000000000000000001;
      endcase
    else
      wrCE <= 32'b00000000000000000000000000000000;
  end

  assign
    slv_reg_write_sel = wrCE[31:0],
    slv_reg_read_sel  = rdCE[31:0],
    slv_write_ack     = wrCE[0] || wrCE[1] || wrCE[2] || wrCE[3] || wrCE[4] || wrCE[5] || wrCE[6] || wrCE[7] || wrCE[8] || wrCE[9] || wrCE[10] || wrCE[11] || wrCE[12] || wrCE[13] || wrCE[14] || wrCE[15] || wrCE[16] || wrCE[17] || wrCE[18] || wrCE[19] || wrCE[20] || wrCE[21] || wrCE[22] || wrCE[23] || wrCE[24] || wrCE[25] || wrCE[26] || wrCE[27] || wrCE[28] || wrCE[29] || wrCE[30] || wrCE[31],
    slv_read_ack      = rdCE[0] || rdCE[1] || rdCE[2] || rdCE[3] || rdCE[4] || rdCE[5] || rdCE[6] || rdCE[7] || rdCE[8] || rdCE[9] || rdCE[10] || rdCE[11] || rdCE[12] || rdCE[13] || rdCE[14] || rdCE[15] || rdCE[16] || rdCE[17] || rdCE[18] || rdCE[19] || rdCE[20] || rdCE[21] || rdCE[22] || rdCE[23] || rdCE[24] || rdCE[25] || rdCE[26] || rdCE[27] || rdCE[28] || rdCE[29] || rdCE[30] || rdCE[31];

  always @( posedge Bus2IP_Clk )
    begin
      if ( Bus2IP_Reset == 1'b1 )
        begin
          port <= 0;
          dir <= 0;
          pwm0 <= 0;
          pwm1 <= 0;
          pwm2 <= 0;
          pwm3 <= 0;
          pwm4 <= 0;
          pwm5 <= 0;
          pwm6 <= 0;
          pwm7 <= 0;
          pwm8 <= 0;
          pwm9 <= 0;
          pwm10 <= 0;
          pwm11 <= 0;
          pwm12 <= 0;
          pwm13 <= 0;
          pwm14 <= 0;
          pwm15 <= 0;
          pwm_en <= 0;
          int_sel <= 0;
          int_flag <= 0;
          led_map <= 16'hfedc;
        end
      else
        begin
          int_flag <= next_int_flag;
          case ( slv_reg_write_sel )
            32'b10000000000000000000000000000000 : // port
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  port[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b01000000000000000000000000000000 : // port_set
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  for ( bit_index = 0; bit_index <= 7; bit_index = bit_index+1 )
                    if ( slv_write_data[(byte_index*8) + bit_index] == 1 )
                      port[(byte_index*8) + bit_index] <= 1'b1;
            32'b00100000000000000000000000000000 : // port_clr
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  for ( bit_index = 0; bit_index <= 7; bit_index = bit_index+1 )
                    if ( slv_write_data[(byte_index*8) + bit_index] == 1 )
                      port[(byte_index*8) + bit_index] <= 1'b0;
            32'b00010000000000000000000000000000 : // port_tgl
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  for ( bit_index = 0; bit_index <= 7; bit_index = bit_index+1 )
                    if ( slv_write_data[(byte_index*8) + bit_index] == 1 )
                      port[(byte_index*8) + bit_index] <= ~port[(byte_index*8) + bit_index];
            32'b00001000000000000000000000000000 : // dir
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  dir[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000100000000000000000000000000 : // dir_set
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  for ( bit_index = 0; bit_index <= 7; bit_index = bit_index+1 )
                    if ( slv_write_data[(byte_index*8) + bit_index] == 1 )
                      dir[(byte_index*8) + bit_index] <= 1'b1;
            32'b00000010000000000000000000000000 : // dir_clr
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  for ( bit_index = 0; bit_index <= 7; bit_index = bit_index+1 )
                    if ( slv_write_data[(byte_index*8) + bit_index] == 1 )
                      dir[(byte_index*8) + bit_index] <= 1'b0;
            32'b00000001000000000000000000000000 : // pin -> port_tgl
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  for ( bit_index = 0; bit_index <= 7; bit_index = bit_index+1 )
                    if ( slv_write_data[(byte_index*8) + bit_index] == 1 )
                      port[(byte_index*8) + bit_index] <= ~port[(byte_index*8) + bit_index];
            32'b00000000100000000000000000000000 : // pwmcmp_0
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  pwm0[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000010000000000000000000000 : //pwmcmp_1
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  pwm1[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000001000000000000000000000 : //pwmcmp_2
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  pwm2[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000000100000000000000000000 : //pwmcmp_3
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  pwm3[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000000010000000000000000000 : //pwmcmp_4
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  pwm4[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000000001000000000000000000 : //pwmcmp_5
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  pwm5[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000000000100000000000000000 : //pwmcmp_6
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  pwm6[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000000000010000000000000000 : //pwmcmp_7
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  pwm7[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000000000001000000000000000 : //pwmcmp_8
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  pwm8[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000000000000100000000000000 : //pwmcmp_9
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  pwm9[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000000000000010000000000000 : //pwmcmp_10
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  pwm10[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000000000000001000000000000 : //pwmcmp_11
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  pwm11[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000000000000000100000000000 : //pwmcmp_12
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  pwm12[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000000000000000010000000000 : //pwmcmp_13
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  pwm13[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000000000000000001000000000 : //pwmcmp_14
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  pwm14[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000000000000000000100000000 : //pwmcmp_15
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  pwm15[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000000000000000000010000000 : // pwm_en
              for ( byte_index = 0; byte_index <= 1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  pwm_en[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000000000000000000001000000 : // pwm_enset
              for ( byte_index = 0; byte_index <= 1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  for ( bit_index = 0; bit_index <= 7; bit_index = bit_index+1 )
                    if ( slv_write_data[(byte_index*8) + bit_index] == 1 )
                      pwm_en[(byte_index*8) + bit_index] <= 1'b1;
            32'b00000000000000000000000000100000 : // pwm_enclr
              for ( byte_index = 0; byte_index <= 1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  for ( bit_index = 0; bit_index <= 7; bit_index = bit_index+1 )
                    if ( slv_write_data[(byte_index*8) + bit_index] == 1 )
                      pwm_en[(byte_index*8) + bit_index] <= 1'b0;
            32'b00000000000000000000000000010000 : // int_sel
              for ( byte_index = 0; byte_index <= (16/4)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  int_sel[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000000000000000000000001000 : // int_flag
              for ( byte_index = 0; byte_index <= (16/8)-1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  for ( bit_index = 0; bit_index <= 7; bit_index = bit_index+1 )
                    if ( slv_write_data[(byte_index*8) + bit_index] == 1 )
                      int_flag[(byte_index*8) + bit_index] <= 1'b0;
            32'b00000000000000000000000000000100 :
              for ( byte_index = 0; byte_index <= 1; byte_index = byte_index+1 )
                if ( slv_write_be[byte_index] == 1 )
                  led_map[(byte_index*8) +: 8] <= slv_write_data[(byte_index*8) +: 8];
            32'b00000000000000000000000000000010 :
              if ( slv_write_be[0] == 1 ) begin
                port[slv_write_data[3:0]] <= 1'b1;
                pwm_en[slv_write_data[3:0]] <= 1'b0;
              end
            32'b00000000000000000000000000000001 :
              if ( slv_write_be[0] == 1 ) begin
                port[slv_write_data[3:0]] <= 1'b0;
                pwm_en[slv_write_data[3:0]] <= 1'b0;
              end
            default : begin
              port <= port;
              dir <= dir;
              pwm0 <= pwm0;
              pwm1 <= pwm1;
              pwm2 <= pwm2;
              pwm3 <= pwm3;
              pwm4 <= pwm4;
              pwm5 <= pwm5;
              pwm6 <= pwm6;
              pwm7 <= pwm7;
              pwm8 <= pwm8;
              pwm9 <= pwm9;
              pwm10 <= pwm10;
              pwm11 <= pwm11;
              pwm12 <= pwm12;
              pwm13 <= pwm13;
              pwm14 <= pwm14;
              pwm15 <= pwm15;
              pwm_en <= pwm_en;
              int_sel <= int_sel;
              led_map <= led_map;
            end
          endcase
        end
    end

  always @( slv_reg_read_sel or port or dir or wing_in_d or pwm0 or pwm1 or pwm2 or pwm3 or pwm4 or pwm5 or pwm6 or pwm7 or pwm8 or pwm9 or pwm10 or pwm11 or pwm12 or pwm13 or pwm14 or pwm15 or pwm_en or int_sel or int_flag or led_map )
    begin 
      case ( slv_reg_read_sel )
        32'b10000000000000000000000000000000 : slv_ip2bus_data = port;
        32'b01000000000000000000000000000000 : slv_ip2bus_data = 0;
        32'b00100000000000000000000000000000 : slv_ip2bus_data = 0;
        32'b00010000000000000000000000000000 : slv_ip2bus_data = 0;
        32'b00001000000000000000000000000000 : slv_ip2bus_data = dir;
        32'b00000100000000000000000000000000 : slv_ip2bus_data = 0;
        32'b00000010000000000000000000000000 : slv_ip2bus_data = 0;
        32'b00000001000000000000000000000000 : slv_ip2bus_data = wing_in_d;
        32'b00000000100000000000000000000000 : slv_ip2bus_data = pwm0;
        32'b00000000010000000000000000000000 : slv_ip2bus_data = pwm1;
        32'b00000000001000000000000000000000 : slv_ip2bus_data = pwm2;
        32'b00000000000100000000000000000000 : slv_ip2bus_data = pwm3;
        32'b00000000000010000000000000000000 : slv_ip2bus_data = pwm4;
        32'b00000000000001000000000000000000 : slv_ip2bus_data = pwm5;
        32'b00000000000000100000000000000000 : slv_ip2bus_data = pwm6;
        32'b00000000000000010000000000000000 : slv_ip2bus_data = pwm7;
        32'b00000000000000001000000000000000 : slv_ip2bus_data = pwm8;
        32'b00000000000000000100000000000000 : slv_ip2bus_data = pwm9;
        32'b00000000000000000010000000000000 : slv_ip2bus_data = pwm10;
        32'b00000000000000000001000000000000 : slv_ip2bus_data = pwm11;
        32'b00000000000000000000100000000000 : slv_ip2bus_data = pwm12;
        32'b00000000000000000000010000000000 : slv_ip2bus_data = pwm13;
        32'b00000000000000000000001000000000 : slv_ip2bus_data = pwm14;
        32'b00000000000000000000000100000000 : slv_ip2bus_data = pwm15;
        32'b00000000000000000000000010000000 : slv_ip2bus_data = pwm_en;
        32'b00000000000000000000000001000000 : slv_ip2bus_data = 0;
        32'b00000000000000000000000000100000 : slv_ip2bus_data = 0;
        32'b00000000000000000000000000010000 : slv_ip2bus_data = int_sel;
        32'b00000000000000000000000000001000 : slv_ip2bus_data = int_flag;
        32'b00000000000000000000000000000100 : slv_ip2bus_data = led_map;
        32'b00000000000000000000000000000010 : slv_ip2bus_data = 0;
        32'b00000000000000000000000000000001 : slv_ip2bus_data = 0;
        default : slv_ip2bus_data = 0;
      endcase
    end


  assign IP2Bus_Data = slv_ip2bus_data;
  assign IP2Bus_WrAck = slv_write_ack;
  assign IP2Bus_RdAck = slv_read_ack;

endmodule
