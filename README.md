# AOC Day 11 Part 2

Update: extended the datapath from 12 to 22 bits, and confirmed the circuit fits in the fpga and both Part 1 and 2 are correclty calculated.

    Time to calulate part 1 increased to 182.4ns.
    Time to calculate part 2 is 547ns (3 cycles).
    The area increased from 6771 LE (lut4) to 12554 LE.

It would be interesting to compare timing and LE usage between the Altera MAX10 with Lut4's vs the XIlinx Artix-7 with Lut5's.

# AOC Day 11 Part 1 

Implemented in a MAX10 fpga. Solution time in 164.2ns. This example showcases the fpgas, parallel computation, low latency and re-configuability.

Implemented the Day 11 puzzle solution by converting each puzzle text to a line of verilog. This implemented the full datapath solution calculation. In order to fit
I had to reduce the datapath from 64-bit to 12-bit. This is enough for Part 1, but the full 64-bits is needed for the part 2 calculation. I'm tyring to implement that on my 100K Artix-7 fpga.

![lowest_latency](17f46dd.jpg)
