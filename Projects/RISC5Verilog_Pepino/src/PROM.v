`timescale 1ns / 1ps // 32-bit PROM initialised from hex file  PDR 23.12.13

module PROM (input clk,
  input enable, 
  input [8:0] adr,
  output reg [31:0] data);
  
reg [31:0] mem [511: 0];
initial $readmemh("../prom.mem", mem);
always @(posedge clk)
  if (enable)
    data <= mem[adr];

endmodule

