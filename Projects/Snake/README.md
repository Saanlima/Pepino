Snake game for Pepino
=======================

This is a port of the Snake game first posted at http://www.instructables.com/id/Snake-on-an-FPGA-Verilog/

The keyboard keys W,A,S,D are used to control the direction of the snake.
The snake grows by four blocks each time the snake head hits the apple (controlled by parameter)


Changes from the original code
------------------------------

- Clock generation: A DCM is used generated the 25 MHz VGA_clock
- The design is changed to be complete synchronous (all flip-flops are clocked by VGA_clock)
- The size of a block is changed from 10x10 pixels to 8x8 pixels to reduce the logic
- The snake growth is controlled by a parameter
- Almost all the code is rewritten from scratch, basically the only original code is the VGA controller

Binaries for Pepino_LX9 and Pepino_LX25 are available in the ISE folder.
