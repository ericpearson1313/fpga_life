
module day11_tb();

	// Let there be clock 
        logic clk;
        logic reset;

        // Create clock
        initial begin
                clk = 0;
                for( ;; ) begin
                        #(10ns);
                        clk = !clk;
                end
        end

	// turn on waveform dump
	initial begin
        	$timeformat(-9, 0, "ns", 12); // 1: scale (ns=-9), 2: decimals, 3: suffix, 4: print-field width
        	$dumpfile("day11.fst");
        	$dumpvars(1,i_day11);
        end
	

	// DUT Connections
	logic [63:0] svr, you, out, fft, dac, fft_ofs, dac_ofs;
	logic [63:0] out_you, out_fft, out_dac, fft_dac, fft_svr, dac_fft, dac_svr;

    	initial begin
		out     = 0;
		fft_ofs = 0;
		dac_ofs = 0;
		@(negedge clk);
		$display( "%b%b%b : you = %d, dac = %d, fft = %d, svr = %d ",  out[0], fft_ofs[0], dac_ofs[0], you, dac, fft, svr);
		out     = 1;
		fft_ofs = 0;
		dac_ofs = 0;
		@(negedge clk);
		out_you = you;
		out_fft = fft;
		out_dac = dac;
		$display( "%b%b%b : you = %d, dac = %d, fft = %d, svr = %d ",  out[0], fft_ofs[0], dac_ofs[0], you, dac, fft, svr);
		out     = 0;
		fft_ofs = 1;
		dac_ofs = 0;
		@(negedge clk);
		fft_svr = svr;
		fft_dac = dac;
		$display( "%b%b%b : you = %d, dac = %d, fft = %d, svr = %d ",  out[0], fft_ofs[0], dac_ofs[0], you, dac, fft, svr);
		out     = 0;
		fft_ofs = 0;
		dac_ofs = 1;
		@(negedge clk);
		dac_fft = fft;
		dac_svr = svr;
		$display( "%b%b%b : you = %d, dac = %d, fft = %d, svr = %d ",  out[0], fft_ofs[0], dac_ofs[0], you, dac, fft, svr);
		
		// Solutions
		$display( "all YOU-OUT paths   : %d", out_you );
		$display( "all YOU-DAC-FFT-OUT : %d", out_fft * fft_dac * dac_svr );
		$display( "all YOU-FFT-DAC-OUT : %d", out_dac * dac_fft * fft_svr );
		$finish();
	end // initial

	// Instantiate day 10 synthesizable verilog 
	aoc_day11 i_day11 (
		.clk	( clk ),
		.reset	( reset ),
		// circuit inputs
		.out    ( out ),
		.fft_ofs( fft_ofs ),
		.dac_ofs( dac_ofs ),
		// Circuit outputs
		.svr    ( svr ),
		.you    ( you ),
		.fft    ( fft ),
		.dac    ( dac )
	);
endmodule




module aoc_day11 (
	input logic clk,
	input logic reset,
	input logic [63:0] out,
	input logic [63:0] fft_ofs,
	input logic [63:0] dac_ofs,
	output logic [63:0] svr,
	output logic [63:0] you,
	output logic [63:0] fft,
	output logic [63:0] dac
	);

`include "day11_declaration.sv"
`include "day11_operation.sv"

endmodule
