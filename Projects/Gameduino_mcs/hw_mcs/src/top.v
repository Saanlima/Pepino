/***************************************************************************************************
*  top.v
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
module top
(
  input  wire        CLK_50MHZ,         // 50MHz system clock signal
  input  wire        SWITCH,            // Microblaze reset
  output wire        VGA_HSYNC,         // vga hsync signal
  output wire        VGA_VSYNC,         // vga vsync signal
  output wire [2:0]  VGA_RED,           // vga red signal
  output wire [2:0]  VGA_GREEN,         // vga green signal
  output wire [1:0]  VGA_BLUE,          // vga blue signal
  output wire        AUDIO_LEFT,        // pwm output audio channel
  output wire        AUDIO_RIGHT,       // pwm output audio channel
  output wire        LED1,
  output wire        LED2,
  output wire        LED3,
  output wire        LED4,
  output wire        LED5,
  inout  wire [15:0] WING_A,
  inout  wire        SD_MISO,
  inout  wire        SD_MOSI,
  inout  wire        SD_SCK,
  inout  wire        SD_CS,
  output wire        SPI_FLASH_Wn,
  output wire        SPI_FLASH_SS,
  output wire        SPI_FLASH_SCLK,
  output wire        SPI_FLASH_MOSI,
  input  wire        SPI_FLASH_MISO,
  output wire        SPI_FLASH_HOLDn,
  output wire        txd,
  input  wire        rxd
);


wire clkfbout, pllclk0, pllclk1, pllclk2, pllclk3;
wire pll_locked;
wire pix_clk, pix_clkx2, clk_100MHz;

wire [4:0] vga_red;
wire [4:0] vga_green;
wire [4:0] vga_blue;
wire vga_hsync;
wire vga_vsync;

assign VGA_HSYNC = vga_hsync;
assign VGA_VSYNC = vga_vsync;
assign VGA_RED = vga_red[4:2];
assign VGA_GREEN = vga_green[4:2];
assign VGA_BLUE = vga_blue[4:3];

assign SPI_FLASH_Wn = 1'b1;
assign SPI_FLASH_HOLDn = 1'b1;


wire mb_reset;
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
wire spi1_cs;
wire spi1_rdAck, spi1_wrAck;
wire [31:0] spi1_rdata;
wire spi1_int;
wire [15:0] wing0_in, wing0_out, wing0_dir;
wire [3:0] spi0_in, spi0_out, spi0_dir;
wire [3:0] spi1_in, spi1_out, spi1_dir;


PLL_BASE # (
  .CLKIN_PERIOD(20),
  .CLKFBOUT_MULT(10),
  .CLKOUT0_DIVIDE(1),
  .CLKOUT1_DIVIDE(10),
  .CLKOUT2_DIVIDE(5),
  .CLKOUT3_DIVIDE(5),
  .COMPENSATION("INTERNAL")
) pll_blk (
  .CLKFBOUT(clkfbout),
  .CLKOUT0(pllclk0), // 500 MHz
  .CLKOUT1(pllclk1), // 50 MHz
  .CLKOUT2(pllclk2), // 100 MHz
  .CLKOUT3(pllclk3), // 100 MHz
  .CLKOUT4(),
  .CLKOUT5(),
  .LOCKED(pll_locked),
  .CLKFBIN(clkfbout),
  .CLKIN(CLK_50MHZ),
  .RST(SWITCH)
  );

BUFG pclkbufg (.I(pllclk1), .O(pix_clk));
BUFG pclkx2bufg (.I(pllclk2), .O(pix_clkx2));
BUFG pclkx4bufg (.I(pllclk3), .O(clk_100MHz));

wire AUX_in, AUX_out, AUX_oe;
assign AUX_in = AUX_oe ? AUX_out : (wing0_dir[2] ? 1'b1 : wing0_out[2]);

gameduino gameduino_blk(
  .vga_clk(pix_clk),
  .vga_red(vga_red),
  .vga_green(vga_green),
  .vga_blue(vga_blue),
  .vga_hsync_n(vga_hsync),
  .vga_vsync_n(vga_vsync),
  .vga_active(),

  .SCK(spi1_out[2]),
  .MOSI(spi1_out[1]),
  .MISO(spi1_in[0]),
  .SSEL(wing0_out[9]),
  .AUX_in(AUX_in),
  .AUX_out(AUX_out),
  .AUX_oe(AUX_oe),
  .AUDIOL(AUDIO_LEFT),
  .AUDIOR(AUDIO_RIGHT),

  .flashMOSI(SPI_FLASH_MOSI),
  .flashMISO(SPI_FLASH_MISO),
  .flashSCK(SPI_FLASH_SCLK),
  .flashSSEL(SPI_FLASH_SS)
  
);
  



//
// Microblaze_MCS
//
assign mb_reset = ~pll_locked;
assign uart0_cs = ~io_adr[10] & ~io_adr[9] & ~io_adr[8] & io_as;
assign wing0_cs = ~io_adr[10] & ~io_adr[9] & io_adr[8] & io_as;
assign timebase0_cs = ~io_adr[10] & io_adr[9] & ~io_adr[8] & io_as;
assign spi0_cs = ~io_adr[10] & io_adr[9] & io_adr[8] & io_as;
assign spi1_cs = io_adr[10] & ~io_adr[9] & ~io_adr[8] & io_as;
assign io_rdy = uart0_rdAck | uart0_wrAck | wing0_rdAck | wing0_wrAck | timebase0_rdAck | timebase0_wrAck | spi0_rdAck | spi0_wrAck | spi1_rdAck | spi1_wrAck;
  
always @ * begin
  case ({spi1_rdAck, spi0_rdAck, timebase0_rdAck, wing0_rdAck, uart0_rdAck})
    5'b00001: io_rdata = uart0_rdata;
    5'b00010: io_rdata = wing0_rdata;
    5'b00100: io_rdata = timebase0_rdata;
    5'b01000: io_rdata = spi0_rdata;
    5'b10000: io_rdata = spi1_rdata;
    default: io_rdata = 32'b0;
  endcase
end
  
microblaze_mcs_v1_3 mcs_0 (
  .Clk             (clk_100MHz),      // input Clk
  .Reset           (mb_reset),        // input Reset
  .IO_Addr_Strobe  (io_as),           // output IO_Addr_Strobe
  .IO_Read_Strobe  (io_rs),           // output IO_Read_Strobe
  .IO_Write_Strobe (io_ws),           // output IO_Write_Strobe
  .IO_Address      (io_adr),          // output [31 : 0] IO_Address
  .IO_Byte_Enable  (io_be),           // output [3 : 0] IO_Byte_Enable
  .IO_Write_Data   (io_wdata),        // output [31 : 0] IO_Write_Data
  .IO_Read_Data    (io_rdata),        // input [31 : 0] IO_Read_Data
  .IO_Ready        (io_rdy)           // input IO_Ready
);

mb_uart uart_0 (
  .UART_tx         (txd),
  .UART_rx         (rxd),
  .UART_int        (uart0_int),
  .Bus2IP_Clk      (clk_100MHz),      // Bus to IP clock
  .Bus2IP_Reset    (mb_reset),        // Bus to IP reset
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

mb_wing wing_0 (
  .wing_in         (wing0_in),        // Wing interface
  .wing_out        (wing0_out),
  .wing_dir        (wing0_dir),
  .wing_int        (wing0_int),
  .wing_led1       (LED1),
  .wing_led2       (LED2),
  .wing_led3       (LED3),
  .wing_led4       (LED4),
  .Bus2IP_Clk      (clk_100MHz),      // Bus to IP clock
  .Bus2IP_Reset    (mb_reset),        // Bus to IP reset
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

mb_timebase timebase_0 (
  .Bus2IP_Clk      (clk_100MHz),      // Bus to IP clock
  .Bus2IP_Reset    (mb_reset),        // Bus to IP reset
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

mb_spi spi_0 (
  .spi_in          (spi0_in),
  .spi_out         (spi0_out),
  .spi_dir         (spi0_dir),
  .spi_led         (LED5),
  .spi_int         (spi0_int),
  .Bus2IP_Clk      (clk_100MHz),        // Bus to IP clock
  .Bus2IP_Reset    (mb_reset),          // Bus to IP reset
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

mb_spi spi_1 (
  .spi_in          (spi1_in),
  .spi_out         (spi1_out),
  .spi_dir         (spi1_dir),
  .spi_led         (),
  .spi_int         (spi1_int),
  .Bus2IP_Clk      (clk_100MHz),        // Bus to IP clock
  .Bus2IP_Reset    (mb_reset),          // Bus to IP reset
  .Bus2IP_Data     (io_wdata),          // Bus to IP data bus
  .Bus2IP_BE       (io_be),             // Bus to IP byte enables
  .Bus2IP_Adr      (io_adr[5:2]),       // Bus to IP address bus
  .Bus2IP_RD       (io_rs),             // Bus to IP read enable
  .Bus2IP_WR       (io_ws),             // Bus to IP write enable
  .Bus2IP_CS       (spi1_cs),           // Bus to IP chip select
  .IP2Bus_Data     (spi1_rdata),        // IP to Bus data bus
  .IP2Bus_RdAck    (spi1_rdAck),        // IP to Bus read transfer acknowledgement
  .IP2Bus_WrAck    (spi1_wrAck)         // IP to Bus write transfer acknowledgement
);

wire wing0_in_2;
assign wing0_in[2] = ~wing0_dir[2] ? wing0_in_2 : (AUX_oe ? AUX_out : wing0_in_2);

wire spi1_in_0;

IOBUF #(.DRIVE(8), .SLEW("FAST")) wing0  (.IO(WING_A[0]),  .O(wing0_in[0]),  .I(wing0_out[0]),  .T(wing0_dir[0]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) wing1  (.IO(WING_A[1]),  .O(wing0_in[1]),  .I(wing0_out[1]),  .T(wing0_dir[1]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) wing2  (.IO(WING_A[2]),  .O(wing0_in_2),  .I(wing0_out[2]),  .T(wing0_dir[2]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) wing3  (.IO(WING_A[3]),  .O(wing0_in[3]),  .I(wing0_out[3]),  .T(wing0_dir[3]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) wing4  (.IO(WING_A[4]),  .O(wing0_in[4]),  .I(wing0_out[4]),  .T(wing0_dir[4]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) wing5  (.IO(WING_A[5]),  .O(wing0_in[5]),  .I(wing0_out[5]),  .T(wing0_dir[5]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) wing6  (.IO(WING_A[6]),  .O(wing0_in[6]),  .I(wing0_out[6]),  .T(wing0_dir[6]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) wing7  (.IO(WING_A[7]),  .O(wing0_in[7]),  .I(wing0_out[7]),  .T(wing0_dir[7]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) wing8  (.IO(WING_A[8]),  .O(wing0_in[8]),  .I(wing0_out[8]),  .T(wing0_dir[8]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) wing9  (.IO(WING_A[9]),  .O(wing0_in[9]),  .I(wing0_out[9]),  .T(wing0_dir[9]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) wing10 (.IO(WING_A[10]), .O(wing0_in[10]), .I(wing0_out[10]), .T(wing0_dir[10]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) wing11 (.IO(WING_A[11]), .O(wing0_in[11]), .I(wing0_out[11]), .T(wing0_dir[11]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) wing12 (.IO(WING_A[12]), .O(wing0_in[12]), .I(wing0_out[12]), .T(wing0_dir[12]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) wing13 (.IO(WING_A[13]), .O(wing0_in[13]), .I(wing0_out[13]), .T(wing0_dir[13]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) wing14 (.IO(WING_A[14]), .O(wing0_in[14]), .I(wing0_out[14]), .T(wing0_dir[14]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) wing15 (.IO(WING_A[15]), .O(wing0_in[15]), .I(wing0_out[15]), .T(wing0_dir[15]));
  
IOBUF #(.DRIVE(8), .SLEW("FAST")) io_miso (.IO(SD_MISO), .O(spi0_in[0]),  .I(spi0_out[0]),  .T(spi0_dir[0]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) io_mosi (.IO(SD_MOSI), .O(spi0_in[1]),  .I(spi0_out[1]),  .T(spi0_dir[1]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) io_sck  (.IO(SD_SCK),  .O(spi0_in[2]),  .I(spi0_out[2]),  .T(spi0_dir[2]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) io_cs   (.IO(SD_CS),   .O(spi0_in[3]),  .I(spi0_out[3]),  .T(spi0_dir[3]));

endmodule

