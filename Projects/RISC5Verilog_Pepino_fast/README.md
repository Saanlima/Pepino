Oberon RISC5 for Pepino
=======================

This is a fast version (37.5 MHz vs. 25 MHz) version of the Oberon RISC5 system. 

The original files can be found at the [Project Oberon page](http://www.projectoberon.com/).
Original Project Oberon design and source code copyright © 1991–2015 Niklaus Wirth (NW) and Jürg Gutknecht (JG)

For further information see the [Pepino Wiki page](http://www.saanlima.com/pepino/index.php?title=Welcome_to_Pepino).

Changes from the original code
------------------------------

- Clock generation
  - A PLL is used to generate a 37.5 clock from the 50 MHz board clock
  - A DCM is used re-generated a 37.5 MHz system clock and a 75 MHz video clock that are in phase
- The SRAM write signal is genereated using the 75 MHz clock
- Timing constants for UART Rx, UART Tx, SPI and millsecond counter are updated based on the faster clock rate

Binaries are available in the ISE folder.
