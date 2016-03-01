`timescale 1ns / 1ps   // MK 29.2.2016

module Multiplier(
  input clk, run, u,
  output stall,
  input [31:0] x, y,
  output [63:0] z);

wire [63:0] z_signed, z_unsigned;
reg [63:0] P;
reg S;

assign z = P;
assign stall = run & ~S;

mult_signed mult_s(.x(x), .y(y), .z(z_signed));
mult_unsigned mult_us(.x(x), .y(y), .z(z_unsigned));

always @ (posedge(clk)) begin
  P <= u ? z_unsigned : z_signed;
  S <= run;
end

endmodule

module mult_signed (
  input signed [31:0] x,
  input signed [31:0] y,
  output signed [63:0] z);
  
assign z = x * y;

endmodule

module mult_unsigned (
  input [31:0] x,
  input [31:0] y,
  output [63:0] z);
  
assign z = x * y;

endmodule
