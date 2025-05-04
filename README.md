# fpga_life
A FPGA implementation of Conways's game of life. 

Approx 1 million generations of life per second (256x256).
![life hdmi](life_gen.jpeg "Life Generation with HDMI display")

## Background

(insert pic link to life glider gif)

Life in this case is a cellular automata game played on a grid of cells, where each cell is alive (1) or dead (0). The cellular automata rules are applied to all grid cells simultaneously to determine each cells next state, 1 or 0 from its state and the number of live neighours (0 to 8). The rules are: i) If a dead cell has 3 live neighbors it will be born and live. ii) if a live cell has 2 or 3 live neighbours it will continue to live. iii) Otherwise the cell remains dead or dies. 
Start with any arragement of cells on the grid. Itteratively applying the life rules to the grid cells simultaneously each time advancing 1 generation of life. 
If all cells die you loose the game of life.

(insert bibliography on Game of Life reference )

I found conway's life as a kid and was always interested in the active patterns people had discovered. The patterns have been shown remarkable capable, ie: like simulating a computer as patterns.
I've implemented life in many ways in software over the years, as a fun excersize.
During a graduate vlsi design course I was able to propose, and see through a group project to implement a vlsi chip to implement life. 
I think I might still have the actual chips in a drawer somewhere (plot shown below). I'd have to look up the technical paper, 
but think it was 1000 generations per second for a similar gid size using 32 of these chips.

![vlsi life chip plot](life_chip.jpeg "WTLCH - Waterloo Life Chip")

Over my career I've improved the releavant design techniques. I thought I would revisit Life, you know, for fun.

Implementing that old chip in system Verilog turned out nicely. Formerly a large pcb with 32 chips and memories for a 256x256 array, it now all fits in a $20 FPGA chip with 1000x the performance too.

The FPGA is adept at DVI or HDMI video output, and can compactly be used to display the life cell array in a window beside live statistics.

## Platform

My previously designed fpga board and its code for HDMI/DVI output made a solid starting platform for this project.

The fpga 10M04 was chosen as a low cost and the development software was free. 
The software (Quartus) is very very good at producing high density, high performance implementations of 
of my verilog described designs. Once compiled, the hardware design can be programmed into flash memory inside the fpga.
When power is applied the design is loaded instantly (10msec) and begins operating at 100's of Mhz frequencies.

A 2nd fpag board was built partially populated, with just the system resources and HDMI connectors. In that case the largest
10M25 was used to test the cross compatibility between the 2 different sizes. Although initially things fit on both fpga's, the 10M04 is 97% utilized 
so anticipate only using the 10M25 as features are added. I should also be able to extend array size and increase performance.

![fpga dev board](life_board.jpeg "A little FPGA board I designed")

## Implementation

Re-using the platform code for clocking, wvga hdmi/dvi video and text overlay allows focus on the core algorithm implementation.

The code is implemented in system verilog.

I implemented a 1r1w 256bit 256word memory using 8 memory blocks (M9K's). Each word of the memory is 1 row of the cell array.
The data path needed to support both the read write to maintain 1 row/cycle rate, but also needed to support initialization writes and video row reads.

HDMI video output is accomplisehd by making a single read of a full row on each active scanline of the video output row, and shifted the read data out during that that video row. 

![Datapath Whiteboard](life_datapath.jpeg "Life fpga design datapath (whiteboard)")

## Performance

Here's a picture of the display showing over 700K generations per second and lots of room for increased performance.

(hex b233e = 729,918 generations/sec)

![Maximum speed](life_speed.jpeg "Life at over 700,000 generations per second")

Would love to work on and even 1000x faster version some day.....

Eric





