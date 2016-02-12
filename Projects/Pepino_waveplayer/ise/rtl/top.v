/***************************************************************************************************
*  top.v
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
module top(
    clkin,
    switch,
    LED5,
    usb_txd,
    usb_rxd,
    Wing_A,
    sd_miso,
    sd_mosi,
    sd_sck,
    sd_cs,
    audio_l,
    audio_r
  );

  input clkin;
  input switch;
  output LED5;
  output usb_txd;
  input usb_rxd;
  inout [15:0] Wing_A;
  inout sd_miso, sd_mosi, sd_sck, sd_cs;
  output audio_l;
  output audio_r;

  wire clk;
  wire reset;
  wire LED1;
  wire [15:0] Wing_A;
  wire [15:0] wing0_in, wing0_out, wing0_dir;
  wire [3:0] spi0_in, spi0_out, spi0_dir;
  
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing0  (.IO(Wing_A[0]),  .O(wing0_in[0]),  .I(wing0_out[0]),  .T(wing0_dir[0]));
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing1  (.IO(Wing_A[1]),  .O(wing0_in[1]),  .I(wing0_out[1]),  .T(wing0_dir[1]));
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing2  (.IO(Wing_A[2]),  .O(wing0_in[2]),  .I(wing0_out[2]),  .T(wing0_dir[2]));
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing3  (.IO(Wing_A[3]),  .O(wing0_in[3]),  .I(wing0_out[3]),  .T(wing0_dir[3]));
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing4  (.IO(Wing_A[4]),  .O(wing0_in[4]),  .I(wing0_out[4]),  .T(wing0_dir[4]));
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing5  (.IO(Wing_A[5]),  .O(wing0_in[5]),  .I(wing0_out[5]),  .T(wing0_dir[5]));
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing6  (.IO(Wing_A[6]),  .O(wing0_in[6]),  .I(wing0_out[6]),  .T(wing0_dir[6]));
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing7  (.IO(Wing_A[7]),  .O(wing0_in[7]),  .I(wing0_out[7]),  .T(wing0_dir[7]));
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing8  (.IO(Wing_A[8]),  .O(wing0_in[8]),  .I(wing0_out[8]),  .T(wing0_dir[8]));
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing9  (.IO(Wing_A[9]),  .O(wing0_in[9]),  .I(wing0_out[9]),  .T(wing0_dir[9]));
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing10 (.IO(Wing_A[10]), .O(wing0_in[10]), .I(wing0_out[10]), .T(wing0_dir[10]));
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing11 (.IO(Wing_A[11]), .O(wing0_in[11]), .I(wing0_out[11]), .T(wing0_dir[11]));
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing12 (.IO(Wing_A[12]), .O(wing0_in[12]), .I(wing0_out[12]), .T(wing0_dir[12]));
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing13 (.IO(Wing_A[13]), .O(wing0_in[13]), .I(wing0_out[13]), .T(wing0_dir[13]));
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing14 (.IO(Wing_A[14]), .O(wing0_in[14]), .I(wing0_out[14]), .T(wing0_dir[14]));
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing15 (.IO(Wing_A[15]), .O(wing0_in[15]), .I(wing0_out[15]), .T(wing0_dir[15]));

  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing16 (.IO(sd_miso),  .O(spi0_in[0]),  .I(spi0_out[0]),  .T(spi0_dir[0]));
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing17 (.IO(sd_mosi),  .O(spi0_in[1]),  .I(spi0_out[1]),  .T(spi0_dir[1]));
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing18 (.IO(sd_sck),  .O(spi0_in[2]),  .I(spi0_out[2]),  .T(spi0_dir[2]));
  IOBUF #(.DRIVE(8), .SLEW("FAST")) wing19 (.IO(sd_cs),  .O(spi0_in[3]),  .I(spi0_out[3]),  .T(spi0_dir[3]));


  DCM_SP DCM_SP_INST
  (
    .CLKIN(clkin),
    .CLKFB(clkfb),
    .RST(1'b0),
    .PSEN(1'b0),
    .PSINCDEC(1'b0),
    .PSCLK(1'b0),
    .DSSEN(1'b0),
    .CLK0(clkfb),
    .CLK90(),
    .CLK180(),
    .CLK270(),
    .CLKDV(),
    .CLK2X(),
    .CLK2X180(),
    .CLKFX(clk120m),
    .CLKFX180(),
    .STATUS(),
    .LOCKED(pll_lckd),
    .PSDONE()
  );

  defparam DCM_SP_INST.CLKIN_DIVIDE_BY_2 = "FALSE";
  defparam DCM_SP_INST.CLKIN_PERIOD = 20.00;
  defparam DCM_SP_INST.CLK_FEEDBACK = "1X";
  defparam DCM_SP_INST.CLKFX_MULTIPLY = 12;
  defparam DCM_SP_INST.CLKFX_DIVIDE = 5;

  BUFG BUFG_clkfb(.I(clk120m), .O(clk));


  wire io_as;
  wire io_rs;
  wire io_ws;
  wire [31:0] io_adr;
  wire [3:0] io_be;
  wire [31:0] io_wdata;
  reg  [31:0] io_rdata;
  wire io_rdy;
  wire [2:0] interrupts;
  wire uart0_cs;
  wire uart0_rdAck, uart0_wrAck;
  wire uart0_int;
  wire [31:0] uart0_rdata;
  wire wing0_cs;
  wire wing0_rdAck, wing0_wrAck;
  wire [31:0] wing0_rdata;
  wire wing0_int;
  wire timebase0_cs;
  wire timebase0_rdAck, timebase0_wrAck;
  wire [31:0] timebase0_rdata;
  wire spi0_cs;
  wire spi0_rdAck, spi0_wrAck;
  wire [31:0] spi0_rdata;
  wire spi0_int;
  wire sound0_cs;
  wire sound0_rdAck, sound0_wrAck;
  wire [31:0] sound0_rdata;
  wire sound0_int;
  
  assign reset = ~pll_lckd | switch;
  
  assign uart0_cs = ~io_adr[10] & ~io_adr[9] & ~io_adr[8] & io_as;
  assign wing0_cs = ~io_adr[10] & ~io_adr[9] & io_adr[8] & io_as;
  assign timebase0_cs = ~io_adr[10] & io_adr[9] & ~io_adr[8] & io_as;
  assign spi0_cs = ~io_adr[10] & io_adr[9] & io_adr[8] & io_as;
  assign sound0_cs = io_adr[10] & ~io_adr[9] & ~io_adr[8] & io_as;
  assign io_rdy = sound0_rdAck | sound0_wrAck | uart0_rdAck | uart0_wrAck | wing0_rdAck | wing0_wrAck | timebase0_rdAck | timebase0_wrAck | spi0_rdAck | spi0_wrAck;
  assign interrups = {spi0_int, wing0_int, uart0_int};
  
  always @ * begin
    case ({sound0_rdAck, spi0_rdAck, timebase0_rdAck, wing0_rdAck, uart0_rdAck})
      5'b00001: io_rdata = uart0_rdata;
      5'b00010: io_rdata = wing0_rdata;
      5'b00100: io_rdata = timebase0_rdata;
      5'b01000: io_rdata = spi0_rdata;
      5'b10000: io_rdata = sound0_rdata;
      default: io_rdata = 32'b0;
    endcase
  end

  microblaze_mcs_v1_3 mcs_0 (
    .Clk             (clk),             // input Clk
    .Reset           (reset),           // input Reset
    .IO_Addr_Strobe  (io_as),           // output IO_Addr_Strobe
    .IO_Read_Strobe  (io_rs),           // output IO_Read_Strobe
    .IO_Write_Strobe (io_ws),           // output IO_Write_Strobe
    .IO_Address      (io_adr),          // output [31 : 0] IO_Address
    .IO_Byte_Enable  (io_be),           // output [3 : 0] IO_Byte_Enable
    .IO_Write_Data   (io_wdata),        // output [31 : 0] IO_Write_Data
    .IO_Read_Data    (io_rdata),        // input [31 : 0] IO_Read_Data
    .IO_Ready        (io_rdy),          // input IO_Ready
    .INTC_Interrupt  (interrups),       // input [2 : 0] INTC_Interrupt
    .INTC_IRQ        ()                 // output INTC_IRQ

  );

  uart uart_0 (
    .UART_tx         (usb_txd),
    .UART_rx         (usb_rxd),
    .UART_int        (uart0_int),
    .Bus2IP_Clk      (clk),             // Bus to IP clock
    .Bus2IP_Reset    (reset),           // Bus to IP reset
    .Bus2IP_Data     (io_wdata),        // Bus to IP data bus
    .Bus2IP_BE       (io_be),           // Bus to IP byte enables
    .Bus2IP_Adr      (io_adr[3:2]),     // Bus to IP address bus
    .Bus2IP_RD       (io_rs),           // Bus to IP read chip enable
    .Bus2IP_WR       (io_ws),           // Bus to IP write chip enable
    .Bus2IP_CS       (uart0_cs),        // Bus to IP chip enable
    .IP2Bus_Data     (uart0_rdata),     // IP to Bus data bus
    .IP2Bus_RdAck    (uart0_rdAck),     // IP to Bus read transfer acknowledgement
    .IP2Bus_WrAck    (uart0_wrAck)      // IP to Bus write transfer acknowledgement
  );

  wing wing_0 (
    .wing_in         (wing0_in),        // Wing interface
    .wing_out        (wing0_out),
    .wing_dir        (wing0_dir),
    .wing_int        (wing0_int),
    .wing_led1       (),
    .wing_led2       (),
    .wing_led3       (),
    .wing_led4       (),
    .Bus2IP_Clk      (clk),             // Bus to IP clock
    .Bus2IP_Reset    (reset),           // Bus to IP reset
    .Bus2IP_Data     (io_wdata),        // Bus to IP data bus
    .Bus2IP_BE       (io_be),           // Bus to IP byte enables
    .Bus2IP_Adr      (io_adr[7:2]),     // Bus to IP address bus
    .Bus2IP_RD       (io_rs),           // Bus to IP read enable
    .Bus2IP_WR       (io_ws),           // Bus to IP write enable
    .Bus2IP_CS       (wing0_cs),        // Bus to IP chip select
    .IP2Bus_Data     (wing0_rdata),     // IP to Bus data bus
    .IP2Bus_RdAck    (wing0_rdAck),     // IP to Bus read transfer acknowledgement
    .IP2Bus_WrAck    (wing0_wrAck)      // IP to Bus write transfer acknowledgement
  );

  timebase timebase_0 (
    .Bus2IP_Clk      (clk),             // Bus to IP clock
    .Bus2IP_Reset    (reset),           // Bus to IP reset
    .Bus2IP_Data     (io_wdata),        // Bus to IP data bus
    .Bus2IP_BE       (io_be),           // Bus to IP byte enables
    .Bus2IP_Adr      (io_adr[3:2]),     // Bus to IP address bus
    .Bus2IP_RD       (io_rs),           // Bus to IP read enable
    .Bus2IP_WR       (io_ws),           // Bus to IP write enable
    .Bus2IP_CS       (timebase0_cs),    // Bus to IP chip select
    .IP2Bus_Data     (timebase0_rdata), // IP to Bus data bus
    .IP2Bus_RdAck    (timebase0_rdAck), // IP to Bus read transfer acknowledgement
    .IP2Bus_WrAck    (timebase0_wrAck)  // IP to Bus write transfer acknowledgement
  );

  spi spi_0 (
    .spi_in          (spi0_in),
    .spi_out         (spi0_out),
    .spi_dir         (spi0_dir),
    .spi_led         (LED5),
    .spi_int         (spi0_int),
    .Bus2IP_Clk      (clk),               // Bus to IP clock
    .Bus2IP_Reset    (reset),             // Bus to IP reset
    .Bus2IP_Data     (io_wdata),          // Bus to IP data bus
    .Bus2IP_BE       (io_be),             // Bus to IP byte enables
    .Bus2IP_Adr      (io_adr[5:2]),       // Bus to IP address bus
    .Bus2IP_RD       (io_rs),             // Bus to IP read enable
    .Bus2IP_WR       (io_ws),             // Bus to IP write enable
    .Bus2IP_CS       (spi0_cs),           // Bus to IP chip select
    .IP2Bus_Data     (spi0_rdata),        // IP to Bus data bus
    .IP2Bus_RdAck    (spi0_rdAck),        // IP to Bus read transfer acknowledgement
    .IP2Bus_WrAck    (spi0_wrAck)         // IP to Bus write transfer acknowledgement
  );

  sound sound_0 (
    .audio_left      (audio_l),
    .audio_right     (audio_r),
    .IP2Bus_Int      (),
    .Bus2IP_Clk      (clk),             // Bus to IP clock
    .Bus2IP_Reset    (reset),           // Bus to IP reset
    .Bus2IP_Data     (io_wdata),        // Bus to IP data bus
    .Bus2IP_BE       (io_be),           // Bus to IP byte enables
    .Bus2IP_Adr      (io_adr[3:2]),     // Bus to IP address bus
    .Bus2IP_RD       (io_rs),           // Bus to IP read chip enable
    .Bus2IP_WR       (io_ws),           // Bus to IP write chip enable
    .Bus2IP_CS       (sound0_cs),       // Bus to IP chip enable
    .IP2Bus_Data     (sound0_rdata),    // IP to Bus data bus
    .IP2Bus_RdAck    (sound0_rdAck),    // IP to Bus read transfer acknowledgement
    .IP2Bus_WrAck    (sound0_wrAck)     // IP to Bus write transfer acknowledgement
  );

endmodule
