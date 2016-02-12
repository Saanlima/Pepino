module crc_16(bit, enable, clk, reset, crc);
  input bit;
  input enable;
  input clk;
  input reset;
  output[15:0] crc;

  reg[15:0] crc;   

  wire inv;

  assign inv = bit ^ crc[15];
   
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      crc = 0;   
    end else begin
      if (enable==1) begin
        crc[15] = crc[14];
        crc[14] = crc[13];
        crc[13] = crc[12];
        crc[12] = crc[11] ^ inv;
        crc[11] = crc[10];
        crc[10] = crc[9];
        crc[9] = crc[8];
        crc[8] = crc[7];
        crc[7] = crc[6];
        crc[6] = crc[5];
        crc[5] = crc[4] ^ inv;
        crc[4] = crc[3];
        crc[3] = crc[2];
        crc[2] = crc[1];
        crc[1] = crc[0];
        crc[0] = inv;
      end
    end
  end
   
endmodule
