`timescale 1ns / 100ps

//
// Simulation testbench stubs for Xilinx modules...
//
module BUFG(I,O);
input I;
output O;
assign #1 O=I;
endmodule


module BUFGMUX(O,I0,I1,S);
input I0,I1,S;
output O;
assign #1 O = (S) ? I1 : I0;
endmodule


module DCM(CLKIN,PSCLK,PSEN,PSINCDEC,RST,CLK2X,CLK0,CLKFB);
input CLKIN, PSCLK, PSEN, PSINCDEC, RST, CLKFB;
output CLK2X, CLK0;

assign #1 CLK0 = CLKIN;

reg CLK2X;
initial CLK2X=0;
always @(posedge CLK0)
begin
  CLK2X = 1'b1;
  #5;
  CLK2X = 1'b0;
  #5;
  CLK2X = 1'b1;
  #5;
  CLK2X = 1'b0;
end
endmodule


module ODDR2(Q,D0,D1,C0,C1);
input D0,D1,C0,C1;
output Q;
reg Q;
initial Q=0;
always @(posedge C0) Q=D0;
always @(posedge C1) Q=D1;
endmodule


module RAMB16_S9(CLK, ADDR, DI, DIP, DO, DOP, EN, SSR, WE);
input CLK, EN, SSR, WE;
input [10:0] ADDR;
input [7:0] DI;
input DIP;
output [7:0] DO;
output DOP;

parameter WRITE_MODE = 0;

wire [10:0] #1 dly_ADDR = ADDR;
wire [8:0] #1 dly_DATA = {DIP,DI};
wire #1 dly_EN = EN;
wire #1 dly_WE = WE;

reg [8:0] mem[0:2047];

reg [7:0] DO;
reg DOP;

reg sampled_EN;
reg [8:0] rddata;

integer i;
initial
begin
  for (i=0; i<2048; i=i+1) mem[i] = 9'h15A;
end

always @(posedge CLK)
begin
  if (dly_EN && dly_WE) mem[dly_ADDR] = dly_DATA;
  rddata = mem[dly_ADDR];
  sampled_EN = dly_EN;
  #1;
  if (sampled_EN) {DOP,DO} = rddata; 
end
endmodule


module RAM16X1S (A0,A1,A2,A3,WCLK,WE,D,O);
input A0,A1,A2,A3,WCLK,WE,D;
output O;

reg mem[0:15];

wire #1 dly_WE = WE;
wire #1 dly_D = D;
wire [3:0] addr = {A3,A2,A1,A0};
wire [3:0] #1 dly_addr = addr;

always @(posedge WCLK)
begin
  if (dly_WE) mem[dly_addr] = dly_D;
end

reg [3:0] rdaddr;
reg O;
always @*
begin
  rdaddr = dly_addr;
  #1;
  O = mem[rdaddr];
end
endmodule


module RAM16X4S (A0,A1,A2,A3,WCLK,WE,D0,D1,D2,D3,O0,O1,O2,O3);
input A0,A1,A2,A3,WCLK,WE,D0,D1,D2,D3;
output O0,O1,O2,O3;
RAM16X1S bit0 (A0,A1,A2,A3,WCLK,WE,D0,O0);
RAM16X1S bit1 (A0,A1,A2,A3,WCLK,WE,D1,O1);
RAM16X1S bit2 (A0,A1,A2,A3,WCLK,WE,D2,O2);
RAM16X1S bit3 (A0,A1,A2,A3,WCLK,WE,D3,O3);
endmodule


module SRLC16E (A0,A1,A2,A3,CLK,CE,D,Q15,Q);
input A0,A1,A2,A3,CLK,CE,D;
output Q15,Q;

reg [15:0] mem;

wire #1 dly_CE = CE;
wire #1 dly_D = D;
wire [3:0] addr = {A3,A2,A1,A0};
wire [3:0] #1 dly_addr = addr;

assign Q15 = mem[15];

always @(posedge CLK)
begin
  if (dly_CE) mem = {mem,dly_D};
end

reg [3:0] rdaddr;
reg Q;
always @*
begin
  rdaddr = dly_addr;
  #1;
  Q = mem[rdaddr];
end
endmodule


module MUXCY (S,CI,DI,O);
input S,CI,DI;
output O;
reg O;
always @* begin #0.1; O = (S) ? CI : DI; end
endmodule



