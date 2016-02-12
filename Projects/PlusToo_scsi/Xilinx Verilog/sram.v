/***************************************************************************************************
*  sram.v
*
*  Copyright (c) 2015, Magnus Karlsson
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
***************************************************************************************************/

module sram (
  input clk64,
  input clk8,
  input _reset,
  input [15:0] memoryDataOut,
  output [15:0] memoryDataIn,
  input [20:0] memoryAddr,
  input _memoryLDS,
  input _memoryUDS,
  input _ramOE,
  input _ramWE,
  output [18:0] sramAddr,
  inout [31:0] sramData,
  output _sramCE,
  output _sramOE,
  output _sramWE,
  output [3:0] _sramDS
);

  reg [2:0] state;
  reg drive_outputs, next_drive_outputs;
  reg sramCE, next_sramCE;
  reg sramOE, next_sramOE;
  reg sramWE, next_sramWE;

  always @(posedge clk64 or negedge _reset) begin
    if (!_reset) begin
      state <= 3'd0;
      drive_outputs <= 1'b0;
      sramCE <= 1'b0;
      sramOE <= 1'b0;
      sramWE <= 1'b0;
    end else begin
      if(((state == 3'd7) && ( clk8 == 0)) ||
         ((state == 3'd0) && ( clk8 == 1)) ||
         ((state != 3'd0) && (state != 3'd7)))
           state <= state + 1'b1;
      drive_outputs <= next_drive_outputs;
      sramCE <= next_sramCE;
      sramOE <= next_sramOE;
      sramWE <= next_sramWE;
    end
  end

  always @ (*) begin
    next_drive_outputs = drive_outputs;
    next_sramCE = sramCE;
    next_sramOE = sramOE;
    next_sramWE = sramWE;
    
    case (state)
      3'd0: begin
        next_drive_outputs = 1'b0;
        next_sramCE = 1'b0;
        next_sramOE = 1'b0;
        next_sramWE = 1'b0;
      end
      3'd1: begin
        if (_ramOE == 0 | _ramWE == 0) begin
          next_sramCE = 1'b1;
        end
      end
      3'd2: begin
      end
      3'd3: begin
        if (sramCE) begin
          next_drive_outputs = ~_ramWE;
          next_sramOE = ~_ramOE;
        end
      end
      3'd4: begin
        if (sramCE) begin
          next_sramWE = ~_ramWE;
        end
      end
      3'd5: begin
      end
      3'd6: begin
        next_sramWE = 1'b0;
      end
      3'd7: begin
        next_drive_outputs = 1'b0;
        next_sramCE = 1'b0;
        next_sramOE = 1'b0;
        next_sramWE = 1'b0;
      end
    endcase
  end


  assign sramAddr = memoryAddr[20:2];
  assign sramData = drive_outputs ? {memoryDataOut, memoryDataOut} : 32'hZZZZZZZZ;
  assign memoryDataIn = memoryAddr[1] ? sramData[31:16] : sramData[15:0];
  assign _sramCE = ~sramCE;
  assign _sramOE = ~sramOE;
  assign _sramWE = ~sramWE;
  assign _sramDS = memoryAddr[1] ? {_memoryUDS, _memoryLDS, 2'b11} : {2'b11, _memoryUDS, _memoryLDS};

  
endmodule
