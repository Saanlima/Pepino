// PlusToo_top for Saanlima Pepino FPGA board

module plusToo_top(
  // clock inputs
  input            CLOCK_50, // 50 MHz
  input            SWITCH,
  input [7:0]      SW,

  // VGA
  output           VGA_HSYNC, // VGA H_SYNC
  output           VGA_VSYNC, // VGA V_SYNC
  output [2:0]     VGA_RED,   // VGA Red
  output [2:0]     VGA_GREEN, // VGA Green
  output [1:0]     VGA_BLUE,  // VGA Blue

  output [18:0]    sramAddr,
  inout [31:0]     sramData,
  output           _sramCE0,
  output           _sramCE1,
  output           _sramOE,
  output           _sramWE,
  output [3:0]     _sramDS,

  output           AUDIO_L,      // sigma-delta DAC output left
  output           AUDIO_R,      // sigma-delta DAC output left

  inout            mouseClk,
  inout            mouseData,
  inout            keyClk,
  inout            keyData,

  output           FLASH_CK,
  output           FLASH_CS,
  output           FLASH_SI,
  input            FLASH_SO,
  output           FLASH_HOLD,
  output           FLASH_WP,
  output [7:0]     LED,

  output           sd_clk,
  inout            sd_cmd,
  inout [3:0]      sd_dat,
  output           sd_active,
  input            sd_switch
  );

// ------------------------------ Plus Too Bus Timing ---------------------------------
// for stability and maintainability reasons the whole timing has been simplyfied:
//                00           01             10           11
//    ______ _____________ _____________ _____________ _____________ ___
//    ______X_video_cycle_X______IO_____X__cpu_cycle__X___unused____X___
//                        ^                    ^      ^
//                        |                    |      |
//                      video                 cpu    cpu
//                       read                write   read


  // synthesize a 32.5 MHz clock
  wire clkfbout, pllclk0, pllclk1, pllclk2;
  wire pll_locked;
  wire clk32, clk64;

  PLL_BASE # (
    .CLKIN_PERIOD(20),   // 50 MHz
    .CLKFBOUT_MULT(13),  // 650 MHz PLL freq
    .CLKOUT0_DIVIDE(2),  // 325 MHz = 10x pixel clock
    .CLKOUT1_DIVIDE(20), // 32.5 MHz = pixel clock
    .CLKOUT2_DIVIDE(10), // 65 MHz = 2x pixel clock
    .COMPENSATION("INTERNAL")
  ) pll_blk (
    .CLKFBOUT(clkfbout),
    .CLKOUT0(pllclk0),
    .CLKOUT1(pllclk1),
    .CLKOUT2(pllclk2),
    .CLKOUT3(),
    .CLKOUT4(),
    .CLKOUT5(),
    .LOCKED(pll_locked),
    .CLKFBIN(clkfbout),
    .CLKIN(CLOCK_50),
    .RST(1'b0)
    );

  BUFG pclkbufg (.I(pllclk1), .O(clk32));
  BUFG pclkx2bufg (.I(pllclk2), .O(clk64));

	// set the real-world inputs to sane defaults
	localparam serialIn = 1'b0,
				  configROMSize = 1'b1;  // 128K ROM
    
	wire [1:0] configRAMSize = 2'b10; // 1MB RAM
				  
	// interconnects
	// CPU
	wire clk8, _cpuReset, _cpuUDS, _cpuLDS, _cpuRW;
	wire [2:0] _cpuIPL;
	wire [7:0] cpuAddrHi;
	wire [23:0] cpuAddr;
	wire [15:0] cpuDataOut;
  wire [1:0] clk8Phase;
	
	// RAM/ROM
	wire _romOE;
	wire _ramOE, _ramWE;
	wire _memoryUDS, _memoryLDS;
	wire videoBusControl;
	wire dioBusControl;
	wire cpuBusControl;
	wire [21:0] memoryAddr;
	wire [15:0] memoryDataOut;
  wire [15:0] ramDataOut, memoryDataInMux;
  reg [15:0] romDataOut;
	
	// peripherals
	wire loadPixels, pixelOut, _hblank, _vblank;
	wire memoryOverlayOn, selectSCSI, selectSCC, selectIWM, selectVIA;	 
	wire [15:0] dataControllerDataOut;
	
	// audio
	wire snd_alt;
	wire loadSound;
	
	// floppy disk image interface
	wire dskReadAckInt;
	wire [21:0] dskReadAddrInt;
	wire dskReadAckExt;
	wire [21:0] dskReadAddrExt;
	
	// convert 1-bit pixel data to 3:3:2 RGB
	assign VGA_RED =   {pixelOut, pixelOut, pixelOut};
	assign VGA_GREEN = {pixelOut, pixelOut, pixelOut};
	assign VGA_BLUE =  {pixelOut, pixelOut};

	// the status register is controlled by the on screen display (OSD)
	wire [7:0] status;
	wire [1:0] buttons;

  wire [21:0] blocks;
	wire [31:0] io_lba;
	wire io_rd;
	wire io_wr;
	wire io_ack;
	wire [7:0] io_din;
	wire io_din_strobe0;
	wire [7:0] io_dout;
	wire io_dout_strobe;
  wire sd_error;
  wire sd_mounted;
  wire load_disk;

  assign _cpuAS = !(cpu_busstate != 2'b01);
	wire [1:0] cpu_busstate;
	wire cpu_clkena = cpuBusControl || (cpu_busstate == 2'b01);
	TG68KdotC_Kernel #(0,0,0,0,0,0) m68k (
    .clk            ( clk8           ),
    .nReset         ( _cpuReset      ),
    .clkena_in      ( cpu_clkena     ), 
    .data_in        ( dataControllerDataOut ),
    .IPL            ( _cpuIPL        ),
    .IPL_autovector ( 1'b1           ),
    .berr           ( 1'b0           ),
    .clr_berr       (                ),
    .CPU            ( 2'b00          ),   // 00=68000
    .addr           ( {cpuAddrHi, cpuAddr} ),
    .data_write     ( cpuDataOut     ),
    .nUDS           ( _cpuUDS        ),
    .nLDS           ( _cpuLDS        ),
    .nWr            ( _cpuRW         ),
    .busstate       ( cpu_busstate   ), // 00-> fetch code 10->read data 11->write data 01->no memaccess
    .nResetOut      (                ),
    .FC             (                )
);

	addrController_top ac0(
		.clk8(clk8), 
		.cpuAddr(cpuAddr), 
		._cpuUDS(_cpuUDS),
		._cpuLDS(_cpuLDS),
		._cpuRW(_cpuRW), 
		.turbo(SW[7]), 
		.configROMSize(configROMSize), 
		.configRAMSize(configRAMSize), 
		.memoryAddr(memoryAddr),			
		._memoryUDS(_memoryUDS),
		._memoryLDS(_memoryLDS),
		._romOE(_romOE), 
		._ramOE(_ramOE), 
		._ramWE(_ramWE),
		.videoBusControl(videoBusControl),	
		.dioBusControl(dioBusControl),	
		.cpuBusControl(cpuBusControl),	
		.selectSCSI(selectSCSI),
		.selectSCC(selectSCC),
		.selectIWM(selectIWM),
		.selectVIA(selectVIA),
		.hsync(VGA_HSYNC), 
		.vsync(VGA_VSYNC),
		._hblank(_hblank),
		._vblank(_vblank),
		.loadPixels(loadPixels),
		.memoryOverlayOn(memoryOverlayOn),

		.snd_alt(snd_alt),
		.loadSound(loadSound),

		.dskReadAddrInt(dskReadAddrInt),
		.dskReadAckInt(dskReadAckInt),
		.dskReadAddrExt(dskReadAddrExt),
		.dskReadAckExt(dskReadAckExt)
	);
	
	wire [1:0] diskEject;
  wire romLoaded;
  reg insertDisk;

	// addional ~8ms delay in reset
	wire n_reset = (rst_cnt == 0);
	reg [15:0] rst_cnt;

	always @(posedge clk8) begin
		// various source can reset the mac
		if(!pll_locked | !romLoaded) 
			rst_cnt <= 16'd65535;
		else if(rst_cnt != 0)
			rst_cnt <= rst_cnt - 16'd1;
	end

	wire [10:0] audio;
	sigma_delta_dac dac(
		.clk(clk32),
		.ldatasum({audio, 4'h0}),
		.rdatasum({audio, 4'h0}),
		.left(AUDIO_L),
		.right(AUDIO_R)
	);


	dataController_top dc0(
		.clk32(clk32), 
		.clk8(clk8),  
		._systemReset(n_reset), 
		._cpuReset(_cpuReset), 
		._cpuIPL(_cpuIPL),
		._cpuUDS(_cpuUDS), 
		._cpuLDS(_cpuLDS), 
		._cpuRW(_cpuRW), 
		.cpuDataIn(cpuDataOut),
		.cpuDataOut(dataControllerDataOut), 	
		.cpuAddrRegHi(cpuAddr[12:9]),
		.cpuAddrRegMid(cpuAddr[6:4]),  // for SCSI
		.cpuAddrRegLo(cpuAddr[2:1]),		
		.selectSCSI(selectSCSI),
		.selectSCC(selectSCC),
		.selectIWM(selectIWM),
		.selectVIA(selectVIA),
		.cpuBusControl(cpuBusControl),
		.videoBusControl(videoBusControl),
		.memoryDataOut(memoryDataOut),
		.memoryDataIn(memoryDataInMux),
		
		// peripherals
		.keyClk(keyClk), 
		.keyData(keyData), 
		.mouseClk(mouseClk),
		.mouseData(mouseData),
		.serialIn(serialIn), 
		
		// video
		._hblank(_hblank),
		._vblank(_vblank), 
		.pixelOut(pixelOut),
		.loadPixels(loadPixels),
		
		.memoryOverlayOn(memoryOverlayOn),

		.audioOut(audio),
		.snd_alt(snd_alt),
		.loadSound(loadSound),
		
		// floppy disk interface
		.insertDisk({1'b0, insertDisk}),
		.diskSides(2'b01),
		.diskEject(diskEject),
		.dskReadAddrInt(dskReadAddrInt),
		.dskReadAckInt(dskReadAckInt),
		.dskReadAddrExt(dskReadAddrExt),
		.dskReadAckExt(dskReadAckExt),

		// block device interface for scsi disk
    .blocks(blocks),
		.io_lba(io_lba),
		.io_rd(io_rd),
		.io_wr(io_wr),
		.io_ack(sd_mounted ? io_ack: (io_rd | io_wr)),
		.io_din(sd_mounted ? io_din : 8'h00),
		.io_din_strobe(io_din_strobe),
		.io_dout(io_dout),
		.io_dout_strobe(io_dout_strobe)
		);
		
  wire [15:0] flashDataOut;
  wire [19:0] flashAddr;
  reg LED2, LED1;

  assign LED = {sd_mounted, sd_error, 3'b0, insertDisk, LED2, LED1};
  assign load_disk = SWITCH & ~insertDisk;

  flash flash (
    .clk8(clk8),
    ._reset(pll_locked),
    .bad_load(LED1),
    .load_disk(load_disk),
    .disk(SW[3:0]),
    .dioBusControl(dioBusControl),
    .romLoaded(romLoaded),
    .diskLoaded(diskLoaded),
    .memoryDataOut(flashDataOut),
    .memoryAddr(flashAddr),
    ._ramWE(_flashWE),
    .loading(loading),
    .spi_sclk(FLASH_CK),
    .spi_ss(FLASH_CS),
    .spi_mosi(FLASH_SI),
    .spi_miso(FLASH_SO)
  );

  assign FLASH_WP = 1'b1;
  assign FLASH_HOLD = 1'b1;

  always @ (negedge clk8 or negedge pll_locked) begin
    if (!pll_locked) begin
      LED2 <= 1'b0;
      LED1 <= 1'b0;
      insertDisk <= 1'b0;
    end else begin
      if (_flashWE == 1'b0 & flashAddr == 20'd0) begin
        LED2 <= flashDataOut == 16'h4d1f;
        LED1 <= flashDataOut != 16'h4d1f;
      end
      insertDisk <= diskLoaded | (insertDisk & ~diskEject[0]);
    end
  end


  // sdram used for ram/rom maps directly into 68k address space
  wire download_cycle = loading && (dioBusControl | !romLoaded);

  wire [15:0] ramDataIn = download_cycle ? flashDataOut : memoryDataOut;
  wire [20:0] ramAddr = download_cycle ? {1'b1, flashAddr} : {~_romOE, memoryAddr[19:0]};
  wire _ramLDS = download_cycle ? _flashWE : _memoryLDS;
  wire _ramUDS = download_cycle ? _flashWE : _memoryUDS;
  wire _ramWR = download_cycle ? _flashWE : _ramWE;
  wire _ramRD = download_cycle ? 1'b1 : (_ramOE && _romOE);

  // during rom/disk download ffff is returned so the screen is black during download
  // "extra rom" is used to hold the disk image. It's expected to be byte wide and
  // we thus need to properly demultiplex the word returned from sdram in that case
  wire [15:0] extra_rom_data_demux = memoryAddr[0] ?
    {ramDataOut[7:0],ramDataOut[7:0]} : {ramDataOut[15:8],ramDataOut[15:8]};
  assign memoryDataInMux = download_cycle ? 16'hffff:
    (dskReadAckInt || dskReadAckExt) ? extra_rom_data_demux:
    ramDataOut;
    

  sram sram (
    .clk64(clk64),
    .clk8(clk8),
    ._reset(pll_locked),
    .memoryDataOut(ramDataIn),
    .memoryDataIn(ramDataOut),
    .memoryAddr(ramAddr),
    ._memoryLDS(_ramLDS),
    ._memoryUDS(_ramUDS),
    ._ramOE(_ramRD),
    ._ramWE(_ramWR),
    .sramAddr(sramAddr),
    .sramData(sramData),
    ._sramCE(_sramCE),
    ._sramOE(_sramOE),
    ._sramWE(_sramWE),
    ._sramDS(_sramDS)
  );

  assign _sramCE0 = _sramCE;
  assign _sramCE1 = _sramCE;

  sd sd (
    .clk(clk8),
    .reset(~pll_locked | sd_switch),
    .sd_clk(sd_clk),
    .sd_cmd(sd_cmd),
    .sd_dat(sd_dat),
    .sd_active(sd_active),
    .sd_read(),
    .sd_write(),
    .error(sd_error),
    .disk_mounted(sd_mounted),
    .blocks(blocks),
    .io_lba(io_lba),
    .io_rd(io_rd),
    .io_wr(io_wr),
    .io_ack(io_ack),
    .io_din(io_din),
    .io_din_strobe(io_din_strobe),
    .io_dout(io_dout),
    .io_dout_strobe(io_dout_strobe)
  );
endmodule
