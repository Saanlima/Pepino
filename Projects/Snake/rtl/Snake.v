// Snake game modified for Pepino
// Magnus Karlsson
// See http://www.instructables.com/id/Snake-on-an-FPGA-Verilog/ for info about the original project

module Snake(start, master_clk, KB_clk, KB_data, VGA_R, VGA_G, VGA_B, VGA_hSync, VGA_vSync);
  input start;
  input master_clk, KB_clk, KB_data;
  output reg [2:0] VGA_R;
  output reg [2:0] VGA_G;
  output reg [1:0] VGA_B;
  output VGA_hSync, VGA_vSync;

  // How much the snake grows for each apple hit
  parameter [6:0] SIZE_INCREASE = 4;
  
  wire [9:0] xCount; //x pixel
  wire [9:0] yCount; //y pixel

  wire displayArea; //is it in the active display area?
  wire VGA_clk; //25 MHz
  wire R;
  wire G;
  wire B;
  wire [3:0] direction;
  reg game_over;
  reg apple, border;
  reg [6:0] size;
  reg [6:0] appleX = 40;
  reg [6:0] appleY = 10;
  wire [6:0]rand_X;
  wire [6:0]rand_Y;
  reg [6:0] snakeX[0:127];
  reg [6:0] snakeY[0:127];
  reg [127:0] snakeBody;
  wire update;

  integer count;

  // Use a CDM to generate VGA clock (25 MHz) from input clock (50 MHz)
  DCM #(.CLKIN_DIVIDE_BY_2("TRUE"), .CLKIN_PERIOD(20.000))
  dcm(.CLKIN(master_clk), .CLKFB(VGA_clk), .RST(1'b0), .PSEN(1'b0),
      .PSINCDEC(1'b0), .PSCLK(1'b0), .DSSEN(1'b0), .CLK0(VGA_clk));

  VGA_gen gen1(VGA_clk, xCount, yCount, displayArea, VGA_hSync, VGA_vSync);
  randomGrid rand1(VGA_clk, rand_X, rand_Y);
  kbInput kbIn(VGA_clk, KB_clk, KB_data, direction);
  updateClk UPDATE(VGA_clk, update);
  
  always@(posedge VGA_clk) begin
    if (~start) begin
      // place the snake head at display center
      snakeX[0] <= 40;
      snakeY[0] <= 30;
      for(count = 1; count < 128; count = count + 1)
        begin
          // place the invisible snake parts outside the scanning area
          snakeX[count] <= 127;
          snakeY[count] <= 127;
        end
      size <= 1;
      game_over <= 0;
    end else if (~game_over) begin
      if (update) begin
        for(count = 1; count < 128; count = count + 1)
          begin
            if(size > count)
            begin
              snakeX[count] <= snakeX[count - 1];
              snakeY[count] <= snakeY[count - 1];
            end
          end
        case(direction)
          4'b0001: snakeY[0] <= (snakeY[0] - 1);
          4'b0010: snakeX[0] <= (snakeX[0] - 1);
          4'b0100: snakeY[0] <= (snakeY[0] + 1);
          4'b1000: snakeX[0] <= (snakeX[0] + 1);
        endcase
      end else begin
        // detect if snake head hit the apple
        if ((snakeX[0] == appleX) && (snakeY[0] == appleY)) begin
          appleX <= rand_X;
          appleY <= rand_Y;
          if (size < 128 - SIZE_INCREASE)
            size <= size + SIZE_INCREASE;
        end
        // detect if snake head hit border        
        else if ((snakeX[0] == 0) || (snakeX[0] == 79) || (snakeY[0] == 0) || (snakeY[0] == 59))
          game_over <= 1'b1;
        // detect if snake head hit the snake body
        else if (|snakeBody[127:1] && snakeBody[0])
          game_over <= 1'b1;
      end
    end
  end

  // Detect if the VGA scanning is hitting the border
  always @(posedge VGA_clk)
  begin
    border <= ((xCount[9:3] == 0) || (xCount[9:3] == 79) || (yCount[9:3] == 0) || (yCount[9:3] == 59));
  end

  // Detect if the VGA scanning is hitting the apple
  always @(posedge VGA_clk)
  begin
    apple <= (xCount[9:3] == appleX) && (yCount[9:3] == appleY);
  end

  // Detect of the VGA scanning is hitting the snake head or snake body
  always@(posedge VGA_clk)
  begin
    for(count = 0; count < 128; count = count + 1)
      snakeBody[count] <= (xCount[9:3] == snakeX[count]) & (yCount[9:3] == snakeY[count]);
  end

  assign R = (displayArea && (apple || game_over));
  assign G = (displayArea && (|snakeBody && ~game_over));
  assign B = (displayArea && (border && ~game_over) );

  always@(posedge VGA_clk)
  begin
    VGA_R = {3{R}};
    VGA_G = {3{G}};
    VGA_B = {2{B}};
  end 

endmodule


//////////////////////////////////////////////////////////////////////////////////////////////////////

module VGA_gen(VGA_clk, xCount, yCount, displayArea, VGA_hSync, VGA_vSync);

  input VGA_clk;
  output reg [9:0]xCount, yCount; 
  output reg displayArea;  
  output VGA_hSync, VGA_vSync;

  reg p_hSync, p_vSync; 
  
  integer porchHF = 640; //start of horizntal front porch
  integer syncH = 656;//start of horizontal sync
  integer porchHB = 752; //start of horizontal back porch
  integer maxH = 799; //total length of line.

  integer porchVF = 480; //start of vertical front porch 
  integer syncV = 490; //start of vertical sync
  integer porchVB = 492; //start of vertical back porch
  integer maxV = 525; //total rows. 

  always@(posedge VGA_clk)
  begin
    if(xCount == maxH)
      xCount <= 0;
    else
      xCount <= xCount + 1;
  end
  always@(posedge VGA_clk)
  begin
    if(xCount == maxH)
    begin
      if(yCount == maxV)
        yCount <= 0;
      else
      yCount <= yCount + 1;
    end
  end
  
  always@(posedge VGA_clk)
  begin
    displayArea <= ((xCount < porchHF) && (yCount < porchVF)); 
  end

  always@(posedge VGA_clk)
  begin
    p_hSync <= ((xCount >= syncH) && (xCount < porchHB)); 
    p_vSync <= ((yCount >= syncV) && (yCount < porchVB)); 
  end
 
  assign VGA_vSync = ~p_vSync; 
  assign VGA_hSync = ~p_hSync;
endmodule    


//////////////////////////////////////////////////////////////////////////////////////////////////////

module randomGrid(VGA_clk, rand_X, rand_Y);
  input VGA_clk;
  output reg [6:0] rand_X;
  output reg [6:0] rand_Y;

  always @(posedge VGA_clk)
  begin  
    rand_X <= ((rand_X + 3) % 78) + 1;
    rand_Y <= ((rand_Y + 5) % 58) + 1;
  end
  
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////

module kbInput(VGA_clk, KB_clk, KB_data, direction);
  input VGA_clk;
  input KB_clk;
  input KB_data;
  output reg [3:0] direction = 4'b0000;
   
  reg Q0, Q1;
  reg [10:0] shreg;
  reg [7:0] code;
  wire endbit;

  assign endbit = ~shreg[0];
  assign shift = Q1 & ~Q0;

  always @ (posedge VGA_clk) begin
    Q0 <= KB_clk;
    Q1 <= Q0;
    shreg <= (endbit) ? 11'h7FF : shift ? {KB_data, shreg[10:1]} : shreg;
    if (endbit)
      code <= shreg[8:1];
    if(code == 8'h1D)
      direction <= 4'b0001;
    else if(code == 8'h1C)
      direction <= 4'b0010;
    else if(code == 8'h1B)
      direction <= 4'b0100;
    else if(code == 8'h23)
      direction <= 4'b1000;
  end   
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////

module updateClk(VGA_clk, update);
  input VGA_clk;
  output reg update;
  reg [21:0]count;  

  always@(posedge VGA_clk)
  begin
    if(count == 1777777) begin
      update <= 1'b1;
      count <= 22'b0;
    end else begin
      update <= 1'b0;
      count <= count + 1'b1;
    end
  end
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////


