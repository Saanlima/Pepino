`timescale 1ns/100ps


module top(
  clkin,
  switch,
  LED,
  SW
  );

  input clkin;
  input switch;
  output [7:0] LED;
  input [7:0] SW;
  
  reg clk;
  reg [7:0] LED;
  
  always @(posedge clkin)
    clk <= ~clk;

  always @(posedge clk or posedge switch)
  begin
    if(switch)
      begin
        LED <= 8'b00000000;
      end
    else begin
      LED <= SW;
    end
  end

endmodule
