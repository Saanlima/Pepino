import string
import array
import sys
import time
import subprocess

T4K_8_8 = string.Template("""
module $ramname (
    input [7:0] dia,
    output [7:0] doa,
    input wea,
    input ena,
    input clka,
    input ssra,
    input [12:0] addra,
    input [7:0] dib,
    output [7:0] dob,
    input web,
    input enb,
    input clkb,
    input ssrb,
    input [12:0] addrb
    );
$rams
endmodule
""")

bram11 = string.Template("""
    RAMB16_S1_S1 #(
      $init
    ) ram$i (
      .DIA(dia[$i]),
      .WEA(wea),
      .ENA(ena),
      .CLKA(clka),
      .ADDRA(addra),
      .DOA(doa[$i]),
      .SSRA(ssra),

      .DIB(dib[$i]),
      .WEB(web),
      .ENB(enb),
      .CLKB(clkb),
      .ADDRB(addrb),
      .DOB(dob[$i]),
      .SSRB(ssrb)
      );
""")

T4K_2_8 = string.Template("""
module $ramname (
    input [1:0] dia,
    output [1:0] doa,
    input wea,
    input ena,
    input clka,
    input ssra,
    input [14:0] addra,
    input [7:0] dib,
    output [7:0] dob,
    input web,
    input enb,
    input clkb,
    input ssrb,
    input [12:0] addrb
    );
$rams
endmodule
""")

bram14 = string.Template("""
    RAMB16_S1_S4 #(
      $init
    ) ram$i (
      .DIA(dia[$i]),
      .WEA(wea),
      .ENA(ena),
      .CLKA(clka),
      .ADDRA(addra),
      .DOA(doa[$i]),
      .SSRA(ssra),

      .DIB({dib[6+$i],dib[4+$i],dib[2+$i],dib[0+$i]}),
      .WEB(web),
      .ENB(enb),
      .CLKB(clkb),
      .ADDRB(addrb),
      .DOB({dob[6+$i],dob[4+$i],dob[2+$i],dob[0+$i]}),
      .SSRB(ssrb)
      );
""")

T16K_8_8 = string.Template("""
module $ramname (
    input [7:0] dia,
    output [7:0] doa,
    input wea,
    input ena,
    input clka,
    input ssra,
    input [14:0] addra,
    input [7:0] dib,
    output [7:0] dob,
    input web,
    input enb,
    input clkb,
    input ssrb,
    input [14:0] addrb
    );
$rams
endmodule
""")

bram44 = string.Template("""
    RAMB16_S4_S4 #(
      $init
    ) ram$i (
      .DIA(dia[4*$i+3:4*$i]),
      .WEA(wea),
      .ENA(ena),
      .CLKA(clka),
      .ADDRA(addra),
      .DOA(doa[4*$i+3:4*$i]),
      .SSRA(ssra),

      .DIB(dib[4*$i+3:4*$i]),
      .WEB(web),
      .ENB(enb),
      .CLKB(clkb),
      .ADDRB(addrb),
      .DOB(dob[4*$i+3:4*$i]),
      .SSRB(ssrb)
      );
""")

T2K_8_16 = string.Template("""
module $ramname (
    input [7:0] DIA,
    output [7:0] DOA,
    input WEA,
    input ENA,
    input CLKA,
    input SSRA,
    input [10:0] ADDRA,
    input [15:0] DIB,
    output [15:0] DOB,
    input WEB,
    input ENB,
    input CLKB,
    input SSRB,
    input [9:0] ADDRB
    );
$rams
endmodule
""")

bram816 = string.Template("""
    RAMB16_S9_S18 #(
      $init
    ) ram (
      .DIPA(0),
      .DIA(DIA),
      .WEA(WEA),
      .ENA(ENA),
      .CLKA(CLKA),
      .ADDRA(ADDRA),
      .DOA(DOA),
      .SSRA(SSRA),

      .DIPB(0),
      .DIB(DIB),
      .WEB(WEB),
      .ENB(ENB),
      .CLKB(CLKB),
      .ADDRB(ADDRB),
      .DOB(DOB),
      .SSRB(SSRB)
      );
""")

T2K_8_32 = string.Template("""
module $ramname (
    input [7:0] DIA,
    output [7:0] DOA,
    input WEA,
    input ENA,
    input CLKA,
    input SSRA,
    input [10:0] ADDRA,
    input [31:0] DIB,
    output [31:0] DOB,
    input WEB,
    input ENB,
    input CLKB,
    input SSRB,
    input [8:0] ADDRB
    );
$rams
endmodule
""")

bram832 = string.Template("""
    RAMB16_S9_S36 #(
      $init
    ) ram (
      .DIPA(0),
      .DIA(DIA),
      .WEA(WEA),
      .ENA(ENA),
      .CLKA(CLKA),
      .ADDRA(ADDRA),
      .DOA(DOA),
      .SSRA(SSRA),

      .DIPB(0),
      .DIB(DIB),
      .WEB(WEB),
      .ENB(ENB),
      .CLKB(CLKB),
      .ADDRB(ADDRB),
      .DOB(DOB),
      .SSRB(SSRB)
      );
""")

T128_8_8 = string.Template("""
module $ramname (
  input wclk,
  input [7:0] ad,
  input wea,
  input [6:0] a,
  input [6:0] b,
  output reg [7:0] ao,
  output reg [7:0] bo
  );
  wire [7:0] _ao;
  wire [7:0] _bo;
  always @(posedge wclk)
  begin
    ao <= _ao;
    bo <= _bo;
  end
$rams
endmodule
""")
ram88 = string.Template("""
      mRAM128X1D
      #( $init )
      ram$i(
        .D(ad[$i]),
        .WE(wea),
        .WCLK(wclk),
        .A0(a[0]),
        .A1(a[1]),
        .A2(a[2]),
        .A3(a[3]),
        .A4(a[4]),
        .A5(a[5]),
        .A6(a[6]),
        .DPRA0(b[0]),
        .DPRA1(b[1]),
        .DPRA2(b[2]),
        .DPRA3(b[3]),
        .DPRA4(b[4]),
        .DPRA5(b[5]),
        .DPRA6(b[6]),
        .SPO(_ao[$i]),
        .DPO(_bo[$i]));
""")

vv = open("../verilog/generated.v", "w")

pattern = range(100) * 200

def geninit1(img, i):
    r = []
    for j in range(64):
        bytes = img[256 * j:256 * (j + 1)][::-1]
        bits = [(1 & (b >> i)) for b in bytes]
        r.append(".INIT_%02X(256'b%s)" % (j, "".join([str(b) for b in bits])))
    return ",\n".join(r)

def geninit4(img, i):
    """ For 4-bit RAMs, each 256 bits holds half the init for 128 bytes """
    r = []
    for j in range(64):
        bytes = img[64 * j:64 * (j + 1)]
        bits = [(15 & (b >> (4 * i))) for b in bytes][::-1]
        r.append(".INIT_%02X(256'h%s)" % (j, "".join(["%X"%b for b in bits])))
    return ",\n".join(r)

def deinterleave(b, i):
    r = 0
    r |= 1 & (b >> i)
    r |= (1 & (b >> (2+i))) << 1
    r |= (1 & (b >> (4+i))) << 2
    r |= (1 & (b >> (6+i))) << 3
    return r

def geninit4i(img, i):
    """ For 4-bit RAMs, each 256 bits holds half the init for 128 bytes """
    r = []
    for j in range(64):
        bytes = img[64 * j:64 * (j + 1)]
        bits = [deinterleave(b, i) for b in bytes][::-1]
        r.append(".INIT_%02X(256'h%s)" % (j, "".join(["%X"%b for b in bits])))
    return ",\n".join(r)

def geninit4(img, i):
    """ For 4-bit RAMs, each 256 bits holds half the init for 128 bytes """
    r = []
    for j in range(64):
        bytes = img[64 * j:64 * (j + 1)]
        bits = [(15 & (b >> (4 * i))) for b in bytes][::-1]
        r.append(".INIT_%02X(256'h%s)" % (j, "".join(["%X"%b for b in bits])))
    return ",\n".join(r)

def geninit8(img):
    r = []
    for j in range(64):
        bytes = img[32 * j:32 * (j + 1)][::-1]
        r.append(".INIT_%02X(256'h%s)" % (j, "".join(["%02X"%b for b in bytes])))
    return ",".join(r)

def geninit128x1(img, i):
    bits = [(1 & (b >> i)) for b in img][::-1]
    return ".INIT(128'b%s)" % "".join([str(b) for b in bits])

from prep import encode
import Image

def pad(a, sz):
    return array.array('B', (a.tostring() + (chr(0) * sz))[:sz])

if 0:
    meml = []
    for l in open("sketches/logo.dump"):
        meml += [int(f,16) for f in l.split()[1:17]]
    assert len(meml) == 32768
    mem = array.array('B', meml)
else:
    mem = array.array('B', [0] * 32768)
    mem = array.array('B', open("sketches/proto/cold.dump").read())

picimg = mem[0x0000:0x1000]
chrimg = mem[0x1000:0x2000]
palimg = mem[0x2000:0x2800]

sprvalimg = mem[0x3000:0x3800]
sprpalimg = mem[0x3800:0x4000]
sprimg = mem[0x4000:0x8000]

svn = subprocess.Popen("svnversion", stdout=subprocess.PIPE).stdout.read().strip()
signature = ("Built %s from svn %s" % (time.ctime(), svn)).ljust(64)
print len(signature), signature
for (i, c) in enumerate(signature):
    sprvalimg[0x700 + i] = ord(c)

print >>vv, T16K_8_8.substitute(ramname = "RAM_SPRIMG",
                                rams = "".join([bram11.substitute(i = i,
                                                                  init = geninit1(sprimg, i)) for i in range(8)]))
print >>vv, T4K_8_8.substitute(ramname = "RAM_PICTURE",
                                rams = "".join([bram44.substitute(i = i,
                                                                  init = geninit4(picimg, i)) for i in range(2)]))
print >>vv, T4K_2_8.substitute(ramname = "RAM_CHR",
                                rams = "".join([bram14.substitute(i = i,
                                                                  init = geninit4i(chrimg, i)) for i in range(2)]))
print >>vv, T2K_8_16.substitute(ramname = "RAM_PAL",
                                rams = bram816.substitute(init = geninit8(palimg)))

print >>vv, T2K_8_32.substitute(ramname = "RAM_SPRVAL",
                                rams = bram832.substitute(init = geninit8(sprvalimg)))

print >>vv, T2K_8_16.substitute(ramname = "RAM_SPRPAL",
                                rams = bram816.substitute(init = geninit8(sprpalimg)))

j1code = pad(array.array('B', open("sketches/j1firmware/cold.binbe").read()), 256) # bigendian
j1codeimgl = array.array('B', j1code[1::2])
print >>vv, T128_8_8.substitute(ramname = "RAM_CODEL",
                                rams = "".join([ram88.substitute(i = i, init = geninit128x1(j1codeimgl, i)) for i in range(8)]))
j1codeimgh = array.array('B', j1code[0::2])
print >>vv, T128_8_8.substitute(ramname = "RAM_CODEH",
                                rams = "".join([ram88.substitute(i = i, init = geninit128x1(j1codeimgh, i)) for i in range(8)]))

sys.exit(0)
