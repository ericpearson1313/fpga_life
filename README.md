# fpga_life
A FPGA implementation of Conways's game of life. 

A million generations-per-second FPGA implementation of Conway's Game of Life on a 256x256 grid.

A personal record.

## Background

(insert pic link to life glider)

Life in this case is a cellular automata game played on a grid of cells, where each cell is alive (1) or dead (0). The cellular automata rules are applied to all grid cells simultaneously to determine each cells next state, 1 or 0 from its state and the number of live neighours (0 to 8). The rules are: i) If a dead cell has 3 live neighbors it will be born and live. ii) if a live cell has 2 or 3 live neighbours it will continue to live. iii) Otherwise the cell remains dead or dies. 
Start with any arragement of cells on the grid. Itteratively applying the life rules to the grid cells simultaneously each time advancing 1 generation of life. 
If all cells die you loose the game of life.

(insert link to Conways Game of Life)

I found conway's life as a kid and was always interested in the active patterns people had discovered. 
It turns out some very interesting things happen with these patterns. They've been shown remarkable capable, ie: like computer operations performed by generations of patterns of cells.
I've implemented life in many ways in software over the years, as a fun excersize.
During a graduate vlsi design course I was able to propose, and see through a group project to implement a vlsi chip to implement life. 
I think I might still have the actual chips in a drawer. They were big ceramic 40 pin dips.  I'd have to look up the technical paper, 
but think it was 1000 generations per second for a similar gid size using 32 of these chips.

(insert micro photograph of chip)

Its been a long time and I've honned the releavant design techniques. I thought I would revisit, you know, for enjoyment.

Implementing that old chip in system Verilog turned out nicely. Formerly a large pcb with 32 chips and memories for a 256x256 array, it now all fits in a $20 FPGA chip with 1000x the performance too.

The FPGA is adept at DVI or HDMI video output, and can compactly be used to display the life cell array in a window beside live statistics.

## Platform

Re-using my sucessful fpga board, in particular its HDMI connectors and re-using the platform code.

The fpga 10M04 was chosen as a low cost and the development software was free. 
The software (Quartus) is very very good at producing high density, high performance implementations of 
of my verilog described designs. Once compiled, the hardware design can be programmed into flash memory inside the fpga.
When power is applied the design is loaded instantly (10msec) and begins operating at 100's of Mhz frequencies.

## Implementation

Re-using the platform code for clocking, wvga hdmi/dvi video and text overlay allows focus on the core algorithm implementation.

(block diagram of hardware with datapaths.)

I implemented a 1r1w 256bit 256word memory using 8 memory blocks (M9K's). Each work of the memory is 1 row of the cell array.
The data path needed to support both the read write to maintain 1 row/cycle rate, but also needed to support initialization writes and video row reads.
On each active scanline of the video output 1 read is made at the start of the row, which shifted out to generate video of that row. 

The cell datapath is  





