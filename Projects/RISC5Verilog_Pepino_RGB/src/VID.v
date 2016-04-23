`timescale 1ns / 1ps
// 1024x768 display controller NW/PR 24.1.2014
// Modified for 4 bits/pixel MK 18.4.2016

module VID(
    input clk, pclk, inv,
    input [31:0] viddata,
    output reg req,  // SRAM read request
    output [17:0] vidadr,
    output hsync, vsync,  // to display
    output [7:0] RGB);

localparam Org = 18'b0111_1111_1111_0000_00;  // 7FF00: adr of vcnt=1023
reg [10:0] hcnt;
reg [9:0] vcnt;
reg [6:0] hword;  // from hcnt, but latched in the clk domain
reg [31:0] vidbuf, pixbuf;
reg hblank;
wire pclk, hend, vend, vblank, xfer;
wire vid_R, vid_G, vid_B;

assign hend = (hcnt == 1343), vend = (vcnt == 801);
assign vblank = (vcnt[8] & vcnt[9]);  // (vcnt >= 768)
assign hsync = ~((hcnt >= 1080+6) & (hcnt < 1184+6));  // -ve polarity
assign vsync = (vcnt >= 771) & (vcnt < 776);  // +ve polarity
assign xfer = (hcnt[2:0] == 6);  // data delay > hcnt cycle + req cycle
assign vid_B = (pixbuf[0] ^ inv) & ~hblank & ~vblank;
assign vid_G = (pixbuf[1] ^ inv) & ~hblank & ~vblank;
assign vid_R = (pixbuf[2] ^ inv) & ~hblank & ~vblank;
assign RGB = {vid_B, vid_B, vid_G, vid_G, vid_G, vid_R, vid_R, vid_R};
assign vidadr = Org + {1'b0, ~vcnt, hword};

always @(posedge pclk) begin  // pixel clock domain
  hcnt <= hend ? 0 : hcnt+1;
  vcnt <= hend ? (vend ? 0 : (vcnt+1)) : vcnt;
  hblank <= xfer ? hcnt[10] : hblank;  // hcnt >= 1024
  pixbuf <= xfer ? vidbuf : {4'b0000, pixbuf[31:4]}; // 4 bits/pixel
end

always @(posedge clk) begin  // CPU (SRAM) clock domain
  hword <= hcnt[9:3];
  req <= ~vblank & ~hcnt[10] & (hcnt[3] ^ hword[0]);  // i.e. adr changed
  vidbuf <= req ? viddata : vidbuf;
end

endmodule
