module crc_7(bit, enable, clk, reset, crc);
  input bit;
  input enable;
  input clk;
  input reset;
  output[6:0] crc;

  reg[6:0] crc;   

  wire inv;

  assign inv = bit ^ crc[6];

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      crc = 0;
    end else begin
      if (enable) begin
        crc[6] = crc[5];
        crc[5] = crc[4];
        crc[4] = crc[3];
        crc[3] = crc[2] ^ inv;
        crc[2] = crc[1];
        crc[1] = crc[0];
        crc[0] = inv;
      end
    end
  end

endmodule

