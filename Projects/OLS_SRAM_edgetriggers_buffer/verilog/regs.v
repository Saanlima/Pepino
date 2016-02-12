
//
// Delay a signal by one clock...
//
module dly_signal (clk, indata, outdata);
parameter WIDTH = 1;
input clk;
input [WIDTH-1:0] indata;
output [WIDTH-1:0] outdata;
reg [WIDTH-1:0] outdata, next_outdata;
always @(posedge clk) outdata = next_outdata;
always @*
begin
  #1;
  next_outdata = indata;
end
endmodule



//
// Delay & Synchronizer pipelines...
//
module pipeline_stall (clk, reset, datain, dataout);
parameter WIDTH = 1;
parameter DELAY = 1;
input clk, reset;
input [WIDTH-1:0] datain;
output [WIDTH-1:0] dataout;
reg [(WIDTH*DELAY)-1:0] dly_datain, next_dly_datain;
assign dataout = dly_datain[(WIDTH*DELAY)-1 : WIDTH*(DELAY-1)];
initial dly_datain = 0;
always @ (posedge clk or posedge reset)
begin
  if (reset)
    dly_datain = 0;
  else dly_datain = next_dly_datain;
end
always @*
begin
  #1;
  next_dly_datain = {dly_datain, datain};
end
endmodule



//
// Two back to back flop's.  A full synchronizer (which XISE 
// will convert into a nice shift register using a single LUT)
// to sample asynchronous signals safely.
//
module full_synchronizer (clk, reset, datain, dataout);
parameter WIDTH = 1;
input clk, reset;
input [WIDTH-1:0] datain;
output [WIDTH-1:0] dataout;
pipeline_stall #(WIDTH,2) sync (clk, reset, datain, dataout);
endmodule


//
// Create a stretched synchronized reset pulse...
//
module reset_sync (clk, hardreset, reset);
input clk, hardreset;
output reset;

reg [3:0] reset_reg, next_reset_reg;
assign reset = reset_reg[3];

initial reset_reg = 4'hF;
always @ (posedge clk or posedge hardreset)
begin
  if (hardreset)
    reset_reg = 4'hF;
  else reset_reg = next_reset_reg;
end

always @*
begin
  next_reset_reg = {reset_reg,1'b0};
end
endmodule


