

`timescale 1 ps / 1 ps

module pacman_top (
  input  wire RSTBTN,
  input  wire SYS_CLK,
  input  wire [3:0] SW,
  input  wire [4:0] JOYSTICK,

  // VGA
  output wire VGA_HSYNC,       // VGA H_SYNC
  output wire VGA_VSYNC,       // VGA V_SYNC
  output wire [2:0] VGA_RED,   // VGA Red
  output wire [2:0] VGA_GREEN, // VGA Green
  output wire [1:0] VGA_BLUE,  // VGA Blue
  output wire [3:0] LED,
  output wire audio_l,
  output wire audio_r
);


  wire pllclk0, pllclk1, pllclk2;
  wire pclkx2, pclkx10, pll_lckd;
  wire clkfbout;
  wire reset;
  wire [3:0] vga_red, vga_green, vga_blue;

  //
  // Pixel Rate clock buffer
  //
  BUFG pclkbufg (.I(pllclk1), .O(pclk));

  //////////////////////////////////////////////////////////////////
  // 2x pclk is going to be used to drive OSERDES2
  // on the GCLK side
  //////////////////////////////////////////////////////////////////
  BUFG pclkx2bufg (.I(pllclk2), .O(pclkx2));

  //////////////////////////////////////////////////////////////////
  // 10x pclk is used to drive IOCLK network so a bit rate reference
  // can be used by OSERDES2
  //////////////////////////////////////////////////////////////////
  PLL_BASE # (
    .CLKIN_PERIOD(20),
    .CLKFBOUT_MULT(10), //set VCO to 10x of CLKIN
    .CLKOUT0_DIVIDE(2),
    .CLKOUT1_DIVIDE(20),
    .CLKOUT2_DIVIDE(10),
    .COMPENSATION("INTERNAL")
  ) PLL_OSERDES (
    .CLKFBOUT(clkfbout),
    .CLKOUT0(pllclk0),
    .CLKOUT1(pllclk1),
    .CLKOUT2(pllclk2),
    .CLKOUT3(),
    .CLKOUT4(),
    .CLKOUT5(),
    .LOCKED(pll_lckd),
    .CLKFBIN(clkfbout),
    .CLKIN(SYS_CLK),
    .RST(1'b0)
  );

  synchro #(.INITIALIZE("LOGIC1"))
  synchro_reset (.async(!pll_lckd),.sync(reset),.clk(pclk));


  // LED
  assign LED[3] = pll_lckd ;
 
  // PACMAN stuff
  
  reg [7:0] delay_count;
  reg pm_reset;
  wire ena_12;
  wire ena_6;
  
  always @ (posedge pclk or negedge pll_lckd) begin
    if (!pll_lckd) begin
      delay_count <= 8'd0;
      pm_reset <= 1'b1;
    end else begin
      delay_count <= delay_count + 1'b1;
      if (delay_count == 8'hff)
        pm_reset <= 1'b0;        
    end
  end
    
  assign ena_12 = delay_count[0];
  assign ena_6 = delay_count[0] & ~delay_count[1];

  
  PACMAN pm (
    .O_VIDEO_R(vga_red),
    .O_VIDEO_G(vga_green),
    .O_VIDEO_B(vga_blue),
    .O_HSYNC(vga_hsync),
    .O_VSYNC(vga_vsync),
    .O_BLANKING(),
    .O_AUDIO_L(audio_l),
    .O_AUDIO_R(audio_r),
    .I_JOYSTICK_A({1'b1,JOYSTICK[3:0]}),
    .I_JOYSTICK_B({1'b1,JOYSTICK[3:0]}),
    .JOYSTICK_A_GND(),
    .JOYSTICK_B_GND(),
    .I_SW(SW),
    .O_LED(LED[2:0]),
    .I_RESET(pm_reset),
    .I_CLK_REF(pclkx2),
    .I_CLK(pclk),
    .I_ENA_12(ena_12),
    .I_ENA_6(ena_6)
  );

  assign VGA_RED = vga_red[3:1];
  assign VGA_GREEN = vga_green[3:1];
  assign VGA_BLUE = vga_blue[3:2];
  assign VGA_HSYNC = ~vga_hsync;
  assign VGA_VSYNC = ~vga_vsync;

endmodule
