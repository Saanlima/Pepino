/***************************************************************************************************
*  spi.v
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
module spi
(
  spi_in,
  spi_out,
  spi_dir,
  spi_led,
  spi_int,
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

  input      [3:0]       spi_in;
  output     [3:0]       spi_out;
  output     [3:0]       spi_dir;
  output                 spi_led;
  output                 spi_int;

  input                  Bus2IP_Clk;
  input                  Bus2IP_Reset;
  input      [31:0]      Bus2IP_Data;
  input      [3:0]       Bus2IP_BE;
  input      [3:0]       Bus2IP_Adr;
  input                  Bus2IP_RD;
  input                  Bus2IP_WR;
  input                  Bus2IP_CS;
  output     [31:0]      IP2Bus_Data;
  output                 IP2Bus_RdAck;
  output                 IP2Bus_WrAck;



  wire       [3:0]       spi_in;   // pins
  wire       [3:0]       spi_out;  // port
  wire       [3:0]       spi_dir;  // dir
  wire                   spi_int;  // interrupt
  wire                   spi_led;  // LED
  
  reg        [3:0]       spi_in_d;
  reg        [10:0]      rdCE, wrCE;
  reg        [3:0]       port;
  reg        [3:0]       dir;
  reg        [7:0]       spcr;
  reg        [7:0]       sptx;
  reg        [7:0]       sprx;
  wire       [10:0]      slv_reg_write_sel;
  wire       [10:0]      slv_reg_read_sel;
  reg        [31:0]      slv_ip2bus_data;
  wire                   slv_read_ack;
  wire                   slv_write_ack;

  reg                    spi2x;
  reg                    txflag;
  reg        [7:0]       treg;
  reg        [1:0]       state;
  reg        [2:0]       bcnt;
  reg                    sck;
  reg                    wfre, rfwe;
  reg                    spif, spif_read;
  reg                    wcol, wcol_read;
  
  integer                bit_index;
  
  // Serial Peripheral Control Register
  wire       spie  = spcr[7];   // Interrupt enable bit
  wire       spe   = spcr[6];   // System Enable bit
  wire       dord  = spcr[5];   // Data Order Bit
  wire       mstr  = spcr[4];   // Master Mode Select Bit
  wire       cpol  = spcr[3];   // Clock Polarity Bit
  wire       cpha  = spcr[2];   // Clock Phase Bit
  wire [1:0] spr   = spcr[1:0]; // Clock Rate Select Bits
  
  wire [2:0] espr = {spi2x, spr};
 

  reg [9:0] clkcnt;
  always @(posedge Bus2IP_Clk)
    if(spe & (|clkcnt & |state))
      clkcnt <= clkcnt - 10'h1;
    else
      case (espr)
        3'b000: clkcnt <= 10'd24;  // 4 MHz
        3'b001: clkcnt <= 10'd99;  // 1 MHz
        3'b010: clkcnt <= 10'd399; // 250 KHz
        3'b011: clkcnt <= 10'd799; // 125 KHz
        3'b100: clkcnt <= 10'd9;   // 10 MHz
        3'b101: clkcnt <= 10'd49;  // 2 MHz
        3'b110: clkcnt <= 10'd199; // 500 KHz
        3'b111: clkcnt <= 10'd399; // 250 KHz
      endcase

  wire ena = ~|clkcnt;

  wire wr_spsr = ((slv_reg_write_sel == 11'b00000000010) & (Bus2IP_BE[0] == 1));
  wire rd_spsr = ((slv_reg_read_sel  == 11'b00000000010) & (Bus2IP_BE[0] == 1));
  
  wire wr_sptx = ((slv_reg_write_sel == 11'b00000000001) & (Bus2IP_BE[0] == 1));
  wire rd_sprx = ((slv_reg_read_sel  == 11'b00000000001) & (Bus2IP_BE[0] == 1));
  
  wire wfov = wr_sptx & |state; 


  always @( posedge Bus2IP_Clk )
    begin
      spi_in_d <= spi_in;
    end

  always @(posedge Bus2IP_Clk)
    if (~spe | Bus2IP_Reset | wr_sptx | rd_sprx) begin
      spif_read <= 0;
      wcol_read <= 0;
    end else if (rd_spsr) begin
      spif_read <= spif;
      wcol_read <= wcol;
    end

  always @(posedge Bus2IP_Clk)
    if (~spe | Bus2IP_Reset)
      spif <= 1'b0;
    else
      spif <= (rfwe | spif) & ~((wr_sptx | rd_sprx) & spif_read);


  always @(posedge Bus2IP_Clk)
    if (~spe | Bus2IP_Reset)
      wcol <= 1'b0;
    else
      wcol <= (wfov | wcol) & ~((wr_sptx | rd_sprx) & wcol_read);


  always @(posedge Bus2IP_Clk)
    if (~spe | Bus2IP_Reset)
      txflag <= 1'b0;
    else
      txflag <= (wr_sptx | txflag) & ~wfre;

  always @(posedge Bus2IP_Clk)
    if (~spe | Bus2IP_Reset)
      sprx <= 1'b0;
    else if (rfwe)
      sprx <= treg;

  always @(posedge Bus2IP_Clk)
    if (~spe | Bus2IP_Reset)
      begin
        state <= 2'b00; // idle
        bcnt  <= 3'h0;
        treg  <= 8'h00;
        wfre  <= 1'b0;
        rfwe  <= 1'b0;
        sck   <= 1'b0;
      end
    else
      begin
        wfre <= 1'b0;
        rfwe <= 1'b0;

        case (state)
          2'b00:
            begin
              bcnt  <= 3'h7;
              treg  <= sptx;
              sck   <= cpol;

              if (txflag) begin
                wfre  <= 1'b1;
                state <= 2'b01;
                if (cpha)
                  sck   <= ~sck;
              end
            end

          2'b01:
            begin
              sck     <= ~sck;
              state   <= 2'b11;
            end

          2'b11:
            if (ena) begin
            
              if (dord)
                treg <= {miso, treg[7:1]};
              else
                treg <= {treg[6:0], miso};
              
              bcnt <= bcnt - 3'h1;

              if (~|bcnt) begin
                state <= 2'b00;
                sck   <= cpol;
                rfwe  <= 1'b1;
              end else begin
                state <= 2'b01;
                sck   <= ~sck;
              end
            end

          2'b10: state <= 2'b00;
        endcase
      end

  assign mosi = dord ? treg[0] : treg[7];
  assign miso = spi_in_d[0];
  assign spi_led = ~spi_in_d[3];
  assign spi_int = spif & spie;
  assign spi_out = spe ? {port[3], sck, mosi, 1'b0} : port;
  assign spi_dir = spe ? {~dir[3], 3'b001} : ~dir;

  always @ * begin
    if (Bus2IP_RD & Bus2IP_CS)
      case (Bus2IP_Adr)
        4'b0000: rdCE = 11'b10000000000;
        4'b0001: rdCE = 11'b01000000000;
        4'b0010: rdCE = 11'b00100000000;
        4'b0011: rdCE = 11'b00010000000;
        4'b0100: rdCE = 11'b00001000000;
        4'b0101: rdCE = 11'b00000100000;
        4'b0110: rdCE = 11'b00000010000;
        4'b0111: rdCE = 11'b00000001000;
        4'b1000: rdCE = 11'b00000000100;
        4'b1001: rdCE = 11'b00000000010;
        4'b1010: rdCE = 11'b00000000001;
      endcase
    else
      rdCE = 11'b00000000000;
  end

  always @ * begin
    if (Bus2IP_WR & Bus2IP_CS)
      case (Bus2IP_Adr)
        4'b0000: wrCE = 11'b10000000000;
        4'b0001: wrCE = 11'b01000000000;
        4'b0010: wrCE = 11'b00100000000;
        4'b0011: wrCE = 11'b00010000000;
        4'b0100: wrCE = 11'b00001000000;
        4'b0101: wrCE = 11'b00000100000;
        4'b0110: wrCE = 11'b00000010000;
        4'b0111: wrCE = 11'b00000001000;
        4'b1000: wrCE = 11'b00000000100;
        4'b1001: wrCE = 11'b00000000010;
        4'b1010: wrCE = 11'b00000000001;
      endcase
    else
      wrCE = 11'b00000000000;
  end

  assign
    slv_reg_write_sel = wrCE[10:0],
    slv_reg_read_sel  = rdCE[10:0],
    slv_write_ack     = wrCE[0] || wrCE[1] || wrCE[2] || wrCE[3] || wrCE[4] || wrCE[5] || wrCE[6] || wrCE[7] || wrCE[8] || wrCE[9] || wrCE[10],
    slv_read_ack      = rdCE[0] || rdCE[1] || rdCE[2] || rdCE[3] || rdCE[4] || rdCE[5] || rdCE[6] || rdCE[7] || rdCE[8] || rdCE[9] || rdCE[10];

  always @( posedge Bus2IP_Clk )
    begin
      if ( Bus2IP_Reset == 1'b1 )
        begin
          port <= 0;
          dir <= 0;
          spcr <= 0;
          spi2x <= 0;
          sptx <= 0;
        end
      else
        case ( slv_reg_write_sel )
          11'b10000000000 : // port
            if ( Bus2IP_BE[0] == 1 )
              port <= Bus2IP_Data[3:0];
          11'b01000000000 : // port_set
            if ( Bus2IP_BE[0] == 1 )
              for ( bit_index = 0; bit_index <= 3; bit_index = bit_index+1 )
                if ( Bus2IP_Data[bit_index] == 1 )
                  port[bit_index] <= 1'b1;
          11'b00100000000 : // port_clr
            if ( Bus2IP_BE[0] == 1 )
              for ( bit_index = 0; bit_index <= 3; bit_index = bit_index+1 )
                if ( Bus2IP_Data[bit_index] == 1 )
                  port[bit_index] <= 1'b0;
          11'b00010000000 : // port_tgl
            if ( Bus2IP_BE[0] == 1 )
              for ( bit_index = 0; bit_index <= 3; bit_index = bit_index+1 )
                if ( Bus2IP_Data[bit_index] == 1 )
                  port[bit_index] <= ~port[bit_index];
          11'b00001000000 : // dir
            if ( Bus2IP_BE[0] == 1 )
              dir <= Bus2IP_Data[3:0];
          11'b00000100000 : // dir_set
            if ( Bus2IP_BE[0] == 1 )
              for ( bit_index = 0; bit_index <= 3; bit_index = bit_index+1 )
                if ( Bus2IP_Data[bit_index] == 1 )
                  dir[bit_index] <= 1'b1;
          11'b00000010000 : // dir_clr
            if ( Bus2IP_BE[0] == 1 )
              for ( bit_index = 0; bit_index <= 3; bit_index = bit_index+1 )
                if ( Bus2IP_Data[bit_index] == 1 )
                  dir[bit_index] <= 1'b0;
          11'b00000001000 : // pin -> port_tgl
            if ( Bus2IP_BE[0] == 1 )
              for ( bit_index = 0; bit_index <= 3; bit_index = bit_index+1 )
                if ( Bus2IP_Data[bit_index] == 1 )
                  port[bit_index] <= ~port[bit_index];
          11'b00000000100 :
            if ( Bus2IP_BE[0] == 1 )
              spcr <= Bus2IP_Data[7:0];
          11'b00000000010 :
            if ( Bus2IP_BE[0] == 1 )
              spi2x <= Bus2IP_Data[0];
          11'b00000000001 :
            if ( Bus2IP_BE[0] == 1 )
              sptx <= Bus2IP_Data[7:0];
          default : begin
            port <= port;
            dir <= dir;
            spcr <= spcr;
            spi2x <= spi2x;
            sptx <= sptx;
          end
        endcase
    end

  always @( slv_reg_read_sel or port or dir or spi_in_d or spcr or spif or wcol or spi2x or sprx )
    begin 
      case ( slv_reg_read_sel )
        11'b10000000000 : slv_ip2bus_data <= port;
        11'b00001000000 : slv_ip2bus_data <= dir;
        11'b00000010000 : slv_ip2bus_data <= spi_in_d;
        11'b00000000100 : slv_ip2bus_data <= spcr;
        11'b00000000010 : slv_ip2bus_data <= {spif, wcol, 5'b0, spi2x};
        11'b00000000001 : slv_ip2bus_data <= sprx;
        default : slv_ip2bus_data <= 0;
      endcase
    end

  assign IP2Bus_Data = (slv_read_ack == 1'b1) ? slv_ip2bus_data :  0 ;
  assign IP2Bus_WrAck = slv_write_ack;
  assign IP2Bus_RdAck = slv_read_ack;

endmodule
