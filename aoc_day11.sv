
module aoc_day11 (
	input logic clk,
	input logic reset,
	input logic  [21:0] out,
	input logic  [21:0] fft_ofs,
	input logic  [21:0] dac_ofs,
	output logic [21:0] svr,
	output logic [21:0] you,
	output logic [21:0] fft,
	output logic [21:0] dac
	);

`include "day11_declaration.sv"
`include "day11_operation.sv"

endmodule
