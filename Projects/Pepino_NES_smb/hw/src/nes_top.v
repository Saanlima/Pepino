/***************************************************************************************************
** fpga_nes/hw/src/nes_top.v
*
*  Copyright (c) 2012, Brian Bennett
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
*  Top level module for an fpga-based Nintendo Entertainment System emulator.
***************************************************************************************************/

/*
*
* Modified for Pepino 11/29/2015  Magnus Karlsson
*
*/

module nes_top
(
  input  wire        CLK_50MHZ,         // 50MHz system clock signal
  input  wire        SWITCH,            // Microblaze reset
  input  wire        RESET,             // NES system reset
  input  wire        CONSOLE_RESET,     // console reset
  input  wire        NES_JOYPAD_DATA1, 
  input  wire        NES_JOYPAD_DATA2,
  output wire        VGA_HSYNC,         // vga hsync signal
  output wire        VGA_VSYNC,         // vga vsync signal
  output wire [2:0]  VGA_RED,           // vga red signal
  output wire [2:0]  VGA_GREEN,         // vga green signal
  output wire [1:0]  VGA_BLUE,          // vga blue signal
  output wire        NES_JOYPAD_CLK,    // joypad output clk signal
  output wire        NES_JOYPAD_LATCH,  // joypad output latch signal
  output wire        AUDIO_LEFT,        // pwm output audio channel
  output wire        AUDIO_RIGHT,       // pwm output audio channel
  output wire        SD_LED,
  inout  wire        SD_MISO,
  inout  wire        SD_MOSI,
  inout  wire        SD_SCK,
  inout  wire        SD_CS  
);

//
// System Memory Buses
//
wire [ 7:0] cpumc_din;
wire [15:0] cpumc_a;
wire        cpumc_r_nw;

wire [ 7:0] ppumc_din;
wire [13:0] ppumc_a;
wire        ppumc_wr;


wire        clkfb, clk2x;
wire        pll_locked;
wire        clk_100MHz;

DCM_SP DCM_SP_INST
(
  .CLKIN(CLK_50MHZ),
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
  .CLK2X(clk2x),
  .CLK2X180(),
  .CLKFX(),
  .CLKFX180(),
  .STATUS(),
  .LOCKED(pll_locked),
  .PSDONE()
);

defparam DCM_SP_INST.CLKIN_DIVIDE_BY_2 = "FALSE";
defparam DCM_SP_INST.CLKIN_PERIOD = 20.00;
defparam DCM_SP_INST.CLK_FEEDBACK = "1X";

BUFG BUFG_clkfb(.I(clk2x), .O(clk_100MHz));

//
// RP2A03: Main processing chip including CPU, APU, joypad control, and sprite DMA control.
//
wire        rp2a03_rdy;
wire [ 7:0] rp2a03_din;
wire        rp2a03_nnmi;
wire [ 7:0] rp2a03_dout;
wire [15:0] rp2a03_a;
wire        rp2a03_r_nw;
wire        rp2a03_brk;
wire [ 3:0] rp2a03_dbgreg_sel;
wire [ 7:0] rp2a03_dbgreg_din;
wire        rp2a03_dbgreg_wr;
wire [ 7:0] rp2a03_dbgreg_dout;
wire        audio;

rp2a03 rp2a03_blk(
  .clk_in(clk_100MHz),
  .rst_in(RESET),
  .rdy_in(rp2a03_rdy),
  .d_in(rp2a03_din),
  .nnmi_in(rp2a03_nnmi),
  .nres_in(~CONSOLE_RESET),
  .d_out(rp2a03_dout),
  .a_out(rp2a03_a),
  .r_nw_out(rp2a03_r_nw),
  .brk_out(rp2a03_brk),
  .jp_data1_in(NES_JOYPAD_DATA1),
  .jp_data2_in(NES_JOYPAD_DATA2),
  .jp_clk(NES_JOYPAD_CLK),
  .jp_latch(NES_JOYPAD_LATCH),
  .mute_in(3'b0),
  .audio_out(audio),
  .dbgreg_sel_in(rp2a03_dbgreg_sel),
  .dbgreg_d_in(rp2a03_dbgreg_din),
  .dbgreg_wr_in(rp2a03_dbgreg_wr),
  .dbgreg_d_out(rp2a03_dbgreg_dout)
);

assign AUDIO_LEFT = audio;
assign AUDIO_RIGHT = audio;

//
// CART: cartridge emulator
//
wire        cart_prg_nce;
wire [ 7:0] cart_prg_dout;
wire [ 7:0] cart_chr_dout;
wire        cart_ciram_nce;
wire        cart_ciram_a10;
wire [39:0] cart_cfg;
wire        cart_cfg_upd;

cart cart_blk(
  .clk_in(clk_100MHz),
  .cfg_in(cart_cfg),
  .cfg_upd_in(cart_cfg_upd),
  .prg_nce_in(cart_prg_nce),
  .prg_a_in(cpumc_a[14:0]),
  .prg_r_nw_in(cpumc_r_nw),
  .prg_d_in(cpumc_din),
  .prg_d_out(cart_prg_dout),
  .chr_a_in(ppumc_a),
  .chr_r_nw_in(~ppumc_wr),
  .chr_d_in(ppumc_din),
  .chr_d_out(cart_chr_dout),
  .ciram_nce_out(cart_ciram_nce),
  .ciram_a10_out(cart_ciram_a10)
);

assign cart_prg_nce = ~cpumc_a[15];

//
// WRAM: internal work ram
//
wire       wram_en;
wire [7:0] wram_dout;

wram wram_blk(
  .clk_in(clk_100MHz),
  .en_in(wram_en),
  .r_nw_in(cpumc_r_nw),
  .a_in(cpumc_a[10:0]),
  .d_in(cpumc_din),
  .d_out(wram_dout)
);

assign wram_en = (cpumc_a[15:13] == 0);

//
// VRAM: internal video ram
//
wire [10:0] vram_a;
wire [ 7:0] vram_dout;

assign vram_a = { cart_ciram_a10, ppumc_a[9:0] };

vram vram_blk(
  .clk_in(clk_100MHz),
  .en_in(~cart_ciram_nce),
  .r_nw_in(~ppumc_wr),
  .a_in(vram_a),
  .d_in(ppumc_din),
  .d_out(vram_dout)
);

//
// PPU: picture processing unit block.
//
wire [ 2:0] ppu_ri_sel;     // ppu register interface reg select
wire        ppu_ri_ncs;     // ppu register interface enable
wire        ppu_ri_r_nw;    // ppu register interface read/write select
wire [ 7:0] ppu_ri_din;     // ppu register interface data input
wire [ 7:0] ppu_ri_dout;    // ppu register interface data output

wire [13:0] ppu_vram_a;     // ppu video ram address bus
wire        ppu_vram_wr;    // ppu video ram read/write select
wire [ 7:0] ppu_vram_din;   // ppu video ram data bus (input)
wire [ 7:0] ppu_vram_dout;  // ppu video ram data bus (output)

wire        ppu_nvbl;       // ppu /VBL signal.


// PPU snoops the CPU address bus for register reads/writes.  Addresses 0x2000-0x2007
// are mapped to the PPU register space, with every 8 bytes mirrored through 0x3FFF.
assign ppu_ri_sel  = cpumc_a[2:0];
assign ppu_ri_ncs  = (cpumc_a[15:13] == 3'b001) ? 1'b0 : 1'b1;
assign ppu_ri_r_nw = cpumc_r_nw;
assign ppu_ri_din  = cpumc_din;

ppu ppu_blk(
  .clk_in(clk_100MHz),
  .rst_in(RESET),
  .ri_sel_in(ppu_ri_sel),
  .ri_ncs_in(ppu_ri_ncs),
  .ri_r_nw_in(ppu_ri_r_nw),
  .ri_d_in(ppu_ri_din),
  .vram_d_in(ppu_vram_din),
  .pix_en(),
  .vde_out(),
  .hsync_out(VGA_HSYNC),
  .vsync_out(VGA_VSYNC),
  .r_out(VGA_RED),
  .g_out(VGA_GREEN),
  .b_out(VGA_BLUE),
  .ri_d_out(ppu_ri_dout),
  .nvbl_out(ppu_nvbl),
  .vram_a_out(ppu_vram_a),
  .vram_d_out(ppu_vram_dout),
  .vram_wr_out(ppu_vram_wr)
);


//
// HCI: host communication interface block.  Interacts with NesDbg software through serial port.
//
wire        rxd;
wire        txd;
wire        hci_active;
wire [ 7:0] hci_cpu_din;
wire [ 7:0] hci_cpu_dout;
wire [15:0] hci_cpu_a;
wire        hci_cpu_r_nw;
wire [ 7:0] hci_ppu_vram_din;
wire [ 7:0] hci_ppu_vram_dout;
wire [15:0] hci_ppu_vram_a;
wire        hci_ppu_vram_wr;

hci hci_blk(
  .clk(clk_100MHz),
  .rst(RESET),
  .rx(rxd),
  .brk(rp2a03_brk),
  .cpu_din(hci_cpu_din),
  .cpu_dbgreg_in(rp2a03_dbgreg_dout),
  .ppu_vram_din(hci_ppu_vram_din),
  .tx(txd),
  .active(hci_active),
  .cpu_r_nw(hci_cpu_r_nw),
  .cpu_a(hci_cpu_a),
  .cpu_dout(hci_cpu_dout),
  .cpu_dbgreg_sel(rp2a03_dbgreg_sel),
  .cpu_dbgreg_out(rp2a03_dbgreg_din),
  .cpu_dbgreg_wr(rp2a03_dbgreg_wr),
  .ppu_vram_wr(hci_ppu_vram_wr),
  .ppu_vram_a(hci_ppu_vram_a),
  .ppu_vram_dout(hci_ppu_vram_dout),
  .cart_cfg(cart_cfg),
  .cart_cfg_upd(cart_cfg_upd)
);

// Mux cpumc signals from rp2a03 or hci blk, depending on debug break state (hci_active).
assign rp2a03_rdy  = (hci_active) ? 1'b0         : 1'b1;
assign cpumc_a     = (hci_active) ? hci_cpu_a    : rp2a03_a;
assign cpumc_r_nw  = (hci_active) ? hci_cpu_r_nw : rp2a03_r_nw;
assign cpumc_din   = (hci_active) ? hci_cpu_dout : rp2a03_dout;

assign rp2a03_din  = cart_prg_dout | wram_dout | ppu_ri_dout;
assign hci_cpu_din = cart_prg_dout | wram_dout | ppu_ri_dout;

// Mux ppumc signals from ppu or hci blk, depending on debug break state (hci_active).
assign ppumc_a          = (hci_active) ? hci_ppu_vram_a[13:0] : ppu_vram_a;
assign ppumc_wr         = (hci_active) ? hci_ppu_vram_wr      : ppu_vram_wr;
assign ppumc_din        = (hci_active) ? hci_ppu_vram_dout    : ppu_vram_dout;

assign ppu_vram_din     = cart_chr_dout | vram_dout;
assign hci_ppu_vram_din = cart_chr_dout | vram_dout;

// Issue NMI interupt on PPU vertical blank.
assign rp2a03_nnmi = ppu_nvbl;


//
// Microblaze_MCS
//
wire mb_reset;
wire io_as;
wire io_rs;
wire io_ws;
wire [31:0] io_adr;
wire [3:0] io_be;
wire [31:0] io_wdata;
reg  [31:0] io_rdata;
wire io_rdy;
wire uart0_cs;
wire uart0_rdAck, uart0_wrAck;
wire uart0_int;
wire [31:0] uart0_rdata;
wire timebase0_cs;
wire timebase0_rdAck, timebase0_wrAck;
wire [31:0] timebase0_rdata;
wire spi0_cs;
wire spi0_rdAck, spi0_wrAck;
wire [31:0] spi0_rdata;
wire spi0_int;
wire [3:0] spi0_in, spi0_out, spi0_dir;

assign mb_reset = ~pll_locked | SWITCH;
assign uart0_cs = ~io_adr[10] & ~io_adr[9] & ~io_adr[8] & io_as;
assign timebase0_cs = ~io_adr[10] & io_adr[9] & ~io_adr[8] & io_as;
assign spi0_cs = ~io_adr[10] & io_adr[9] & io_adr[8] & io_as;
assign io_rdy = uart0_rdAck | uart0_wrAck | timebase0_rdAck | timebase0_wrAck | spi0_rdAck | spi0_wrAck;
  
always @ * begin
  case ({spi0_rdAck, timebase0_rdAck, uart0_rdAck})
    3'b001: io_rdata = uart0_rdata;
    3'b010: io_rdata = timebase0_rdata;
    3'b100: io_rdata = spi0_rdata;
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
  .UART_tx         (rxd),
  .UART_rx         (txd),
  .UART_int        (),
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
  .spi_led         (SD_LED),
  .spi_int         (),
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

IOBUF #(.DRIVE(8), .SLEW("FAST")) io_miso (.IO(SD_MISO), .O(spi0_in[0]),  .I(spi0_out[0]),  .T(spi0_dir[0]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) io_mosi (.IO(SD_MOSI), .O(spi0_in[1]),  .I(spi0_out[1]),  .T(spi0_dir[1]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) io_sck  (.IO(SD_SCK),  .O(spi0_in[2]),  .I(spi0_out[2]),  .T(spi0_dir[2]));
IOBUF #(.DRIVE(8), .SLEW("FAST")) io_cs   (.IO(SD_CS),   .O(spi0_in[3]),  .I(spi0_out[3]),  .T(spi0_dir[3]));
  
  
endmodule

