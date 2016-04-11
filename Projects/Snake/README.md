Snake game for Pepino
=======================

This is a port of the Snake game first posted at http://www.instructables.com/id/Snake-on-an-FPGA-Verilog/

Changes from the original code
------------------------------

- Clock generation: A DCM is used generated a 25 MHz VGA_clock
- Changed the design to be complete synchronous (all flip-flops are clocked by VGA_clock)
- The size of a block is changed from 10x10 pixels to 8x8 pixels to reduce the logic
- Almost all the code is rewritten from scratch, the only code left is the VGA controller code

Binaries are available in the ISE folder.
