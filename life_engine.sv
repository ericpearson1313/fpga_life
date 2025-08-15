// 2D Life engine
// WIDTH x HEIGHT x GENS for each memory read. 
// Memory depth = DEPTH
module life_engine_2D #(
	WIDTH = 37,		// Array width = Datapath width
	DEPTH = 256,	// memory Depth, (ignored, always 256 supported)
	HEIGHT = 36,	// Datapath height
	DBITS = 8,		// depth address bitwidth, (ignored, only 8 supported)
	GENS  = 2		// hardware Generations per pass
) (
	// System
	input clk,
	input reset,
	// Memory Control
	input logic [2:0][2:0][7:0] raddr, // also used for init writes
	input logic [7:0] waddr,
	input	logic we,
	// cell array shift input
	input logic sh,
	// External Data Control
	input logic ld,
	input logic [5:0] ld_sel, // addressed row in the block
	output logic [WIDTH-1:0] dout, // data out
	// Init port
	input logic init,
	input logic [WIDTH*HEIGHT-1:0] init_data
	
);

	// Memory
	// Built up from call_ram_32 = M4K org as 32bx256w, registered I/O 
	// nine memories for 3x3 neighbour hood. 
	// Neighbors represent neighbour location (We swap when writing)	
	// 
	logic [GENS*GENS   -1+31:0] mem00_din, mem00_dout; // UL
	logic [GENS*GENS   -1+31:0] mem02_din, mem02_dout;	// UR
	logic [GENS*GENS   -1+31:0] mem20_din, mem20_dout;	// LL
	logic [GENS*GENS   -1+31:0] mem22_din, mem22_dout;	// LR
	logic [GENS*WIDTH  -1+31:0] mem10_din, mem10_dout;	// Top
	logic [GENS*WIDTH  -1+31:0] mem12_din, mem12_dout;	// Bot
	logic [GENS*HEIGHT -1+31:0] mem01_din, mem01_dout;	// Left
	logic [GENS*HEIGHT -1+31:0] mem21_din, mem21_dout;	// Right
	logic [WIDTH*HEIGHT-1+31:0] mem11_din, mem11_dout;	// center core
	

	// Generate sufficient 32bit mems to cover each of the 9 spatial arrays 
	genvar genii;
	generate 
		for( genii = 0; genii < GENS*GENS; genii+=32 ) begin : _mem_corner
			cell_ram32 _ram00 ( .clock( clk ), .data( mem00_din[genii+31-:32] ), .rdaddress( raddr[0][0] ), .wraddress( waddr ), .wren( we ),	.q( mem00_dout[genii+31-:32] ));
			cell_ram32 _ram20 ( .clock( clk ), .data( mem20_din[genii+31-:32] ), .rdaddress( raddr[2][0] ), .wraddress( waddr ), .wren( we ),	.q( mem20_dout[genii+31-:32] ));
			cell_ram32 _ram02 ( .clock( clk ), .data( mem02_din[genii+31-:32] ), .rdaddress( raddr[0][2] ), .wraddress( waddr ), .wren( we ),	.q( mem02_dout[genii+31-:32] ));
			cell_ram32 _ram22 ( .clock( clk ), .data( mem22_din[genii+31-:32] ), .rdaddress( raddr[2][2] ), .wraddress( waddr ), .wren( we ),	.q( mem22_dout[genii+31-:32] ));
		end
		for( genii = 0; genii < GENS*HEIGHT; genii+=32 ) begin : _mem_edgelr
			cell_ram32 _ram10 ( .clock( clk ), .data( mem10_din[genii+31-:32] ), .rdaddress( raddr[1][0] ), .wraddress( waddr ), .wren( we ),	.q( mem10_dout[genii+31-:32] ));
			cell_ram32 _ram12 ( .clock( clk ), .data( mem12_din[genii+31-:32] ), .rdaddress( raddr[1][2] ), .wraddress( waddr ), .wren( we ),	.q( mem12_dout[genii+31-:32] ));
		end
		for( genii = 0; genii < GENS*WIDTH; genii+=32 ) begin : _mem_edgetb
			cell_ram32 _ram01 ( .clock( clk ), .data( mem01_din[genii+31-:32] ), .rdaddress( raddr[0][1] ), .wraddress( waddr ), .wren( we ),	.q( mem01_dout[genii+31-:32] ));
			cell_ram32 _ram21 ( .clock( clk ), .data( mem21_din[genii+31-:32] ), .rdaddress( raddr[2][1] ), .wraddress( waddr ), .wren( we ),	.q( mem21_dout[genii+31-:32] ));
		end
		for( genii = 0; genii < WIDTH*HEIGHT; genii+=32 ) begin : _mem_core
			cell_ram32 _ram11 ( .clock( clk ), .data( mem11_din[genii+31-:32] ), .rdaddress( raddr[1][1] ), .wraddress( waddr ), .wren( we ),	.q( mem11_dout[genii+31-:32] ));
		end
	endgenerate

	
	// Video Read port
	logic [1:0] ld_del;
	logic [1:0][5:0] ld_sel_del;
	logic [HEIGHT-1:0][WIDTH-1:0] dout_mux;
	assign dout_mux = mem11_dout[HEIGHT*WIDTH-1:0]; // reformat central array as rows
	always_ff @(posedge clk) begin
		ld_del[1:0] <= { ld_del[0], ld };
		ld_sel_del[1:0] <= { ld_sel_del[0], ld_sel };
		if( ld_del[1] ) dout <= dout_mux[ld_sel_del[1]]; // latch row for video ***ASYNC after DELAY*** load and shift
	end

	// Build contiguous life data input array (with overlaps) from the nine different memories
	logic [HEIGHT+2*GENS-1:0][WIDTH+2*GENS-1:0] cell_input;
	always_comb begin
		for( int yy = 0; yy < HEIGHT+2*GENS; yy++ ) begin
			for( int xx = 0; xx < WIDTH+2*GENS; xx++ ) begin
				if      ( xx >= GENS && xx < WIDTH+GENS && yy >= GENS && yy < HEIGHT+GENS ) cell_input[yy][xx] = mem11_dout[(yy-GENS)       *WIDTH+(xx-GENS)      ];//central
				else if ( xx <  GENS                    && yy  < GENS                     ) cell_input[yy][xx] = mem00_dout[ yy             *GENS + xx            ];// UL
				else if ( xx >= GENS && xx < WIDTH+GENS && yy  < GENS                     ) cell_input[yy][xx] = mem01_dout[ yy             *WIDTH+(xx-GENS)      ];// Top
				else if ( xx >= GENS+WIDTH              && yy  < GENS                     ) cell_input[yy][xx] = mem02_dout[ yy             *GENS +(xx-GENS-WIDTH)];// UR
				else if ( xx <  GENS                    && yy >= GENS && yy < GENS+HEIGHT ) cell_input[yy][xx] = mem10_dout[(yy-GENS)       *GENS + xx            ];// LEFT
				else if ( xx >= GENS+WIDTH              && yy >= GENS && yy < GENS+HEIGHT ) cell_input[yy][xx] = mem12_dout[(yy-GENS)       *GENS +(xx-GENS-WIDTH)];// RIGHT
				else if ( xx <  GENS                    && yy >= GENS+HEIGHT              ) cell_input[yy][xx] = mem20_dout[(yy-GENS-HEIGHT)*GENS + xx            ];// LL
				else if ( xx >= GENS && xx < WIDTH+GENS && yy >= GENS+HEIGHT              ) cell_input[yy][xx] = mem21_dout[(yy-GENS-HEIGHT)*WIDTH+(xx-GENS)      ];// Bot
				else/*if( xx >= GENS+WIDTH              && yy >= GENS+HEIGHT            )*/ cell_input[yy][xx] = mem22_dout[(yy-GENS-HEIGHT)*GENS +(xx-GENS-WIDTH)];// LR
			end // xx
		end // yy	
	end 
	
	
	// Now the actual cells arrays inputs_ and outputs for cell_arrays for generation life state
	logic [0:GENS-1][HEIGHT+2*GENS-1:0][WIDTH+2*GENS-1:0] cell_out; // comb Outputs of each generation	 
	logic [0:GENS-1][HEIGHT+2*GENS-1:0][WIDTH+2*GENS-1:0] cell_in;	 // reggister Inputs for each generation
	always_ff @(posedge clk) begin
		for( int gg = 0; gg < GENS; gg++ ) begin
			for( int yy = 0; yy < HEIGHT+2*GENS; yy++ ) begin 
				for( int xx = 0; xx < WIDTH+2*GENS; xx++ ) begin
					cell_in[gg][yy][xx] <= ( gg == 0 ) ? cell_input[yy][xx]    : // from memory for gen 0	
																    cell_out[gg-1][yy][xx]; // prev generation
				end // xx
			end //yy
		end //gg
	end // always
	
	// Input adders fully populate, 
	logic [0:GENS-1][HEIGHT+2*GENS-1:0][WIDTH+2*GENS-1:0][1:0] add3v;	 // |  shape 1x3 verical
	logic [0:GENS-1][HEIGHT+2*GENS-1:0][WIDTH+2*GENS-1:0][2:0] add4h;	 // =  shape
	logic [0:GENS-1][HEIGHT+2*GENS-1:0][WIDTH+2*GENS-1:0][1:0] add3h;	 // -  shape 1x3 horizontal
	logic [0:GENS-1][HEIGHT+2*GENS-1:0][WIDTH+2*GENS-1:0][2:0] add4v;	 // ii shape
	
	always_comb begin
		// default add3h = 0; add3v = 0; add4h = 0; add4v = 0;
		for( int gg = 0; gg < GENS; gg++ ) begin
			for( int yy = 1; yy < HEIGHT+2*GENS-1; yy++ ) begin // no sums needed for first or last rows
				for( int xx = 0; xx < WIDTH+2*GENS-1; xx++ ) // =shape, skip last column
					add4h[gg][yy][xx] =  { 2'b00, cell_in[gg][yy-1][xx  ] } +
											   { 2'b00, cell_in[gg][yy-1][xx+1] } +
											   { 2'b00, cell_in[gg][yy+1][xx  ] } +
											   { 2'b00, cell_in[gg][yy+1][xx+1] };
				for( int xx = 0; xx < WIDTH+2*GENS; xx++ )   // |shape, every column
					add3v[gg][yy][xx]  = { 1'b0 , cell_in[gg][yy-1][xx  ] } +
							  					{ 1'b0 , cell_in[gg][yy  ][xx  ] } +
												{ 1'b0 , cell_in[gg][yy+1][xx  ] } ;
			end //yy
			for( int yy = 0; yy < HEIGHT+2*GENS-1; yy++ ) begin // no sums needed for last rows
				for( int xx = 1; xx < WIDTH+2*GENS-1; xx++ ) //ii shape, skip first and last column
					add4v[gg][yy][xx] =  { 2'b00, cell_in[gg][yy  ][xx-1] } +
											   { 2'b00, cell_in[gg][yy+1][xx-1] } +
											   { 2'b00, cell_in[gg][yy  ][xx+1] } +
											   { 2'b00, cell_in[gg][yy+1][xx+1] };
			end // yy
			for( int yy = 0; yy < HEIGHT+2*GENS; yy++ ) begin // sums for all rows
				for( int xx = 1; xx < WIDTH+2*GENS-1; xx++ ) // -shape, skip first, last column
					add3h[gg][yy][xx]  = { 1'b0 , cell_in[gg][yy  ][xx-1] } +
							  					{ 1'b0 , cell_in[gg][yy  ][xx  ] } +
												{ 1'b0 , cell_in[gg][yy  ][xx+1] } ;
			end //y
		end //gg
	end
	
	// Build arrays of Add8 input's (add4[2:0], add3[1:0], add1} 
	// Optimizing 2D reuse of add3, add4 sums
	// arrange the inputs for the add8's as linear array of 6 bit add8 inputs
	logic [GENS-1:0][(WIDTH+2*GENS-2)*(HEIGHT+2*GENS-2)-1+5:0][5:0] add8_in;
	always_comb begin
		for( int gg = 0; gg < GENS; gg++ ) begin // generations
			for( int yy = gg+1; yy < HEIGHT+2*GENS-gg-1; yy++ ) begin // narrowing height
				for( int xx = gg+1; xx < WIDTH+2*GENS-gg-1; xx++ ) begin // narrowing width
					add8_in[gg][(yy-gg-1)*(WIDTH+2*(GENS-gg-1))+xx-gg-1] = // Packed into LSB of add8 input array per generation
						(xx%3 == 0 && yy%3 == 0) ? { add4h[gg][yy][xx  ], add3v[gg][yy][xx-1], cell_in[gg][yy][xx+1] } : // |=* anything
						(xx%3 == 0 && yy%3 == 1) ? { add4v[gg][yy][xx  ], add3h[gg][yy-1][xx], cell_in[gg][yy+1][xx] } : // |=* vert
						(xx%3 == 0 && yy%3 == 2) ? { add4v[gg][yy][xx-1], add3h[gg][yy+1][xx], cell_in[gg][yy-1][xx] } : // *=| vert
						(xx%3 == 1             ) ? { add4h[gg][yy][xx  ], add3v[gg][yy][xx-1], cell_in[gg][yy][xx+1] } : // |=* horiz
					 /*(xx%3 == 2             )*/ { add4h[gg][yy][xx-1], add3v[gg][yy][xx+1], cell_in[gg][yy][xx-1] } ; // *=| horiz
				end // xx
			end // yy
		end // gg
	end
	
	
	// generate Add8's with hardcoded add431_cell with qunituple (5x) adders
	logic [GENS-1:0][(WIDTH+2*GENS-2)*(HEIGHT+2*GENS-2)-1+5:0][2:0] add8_out_a;
	genvar gengg, genkk;
	generate
		for( gengg = 0; gengg < GENS; gengg++ ) begin : _gen431_gen
			for( genkk = 0; genkk < (WIDTH+2*(GENS-gengg-1)) * (HEIGHT+2*(GENS-gengg-1)); genkk+=5 ) begin : _gen431_cell
			add431_cell _add431(
				.in	( {   add8_in[gengg][genkk+4], 
								add8_in[gengg][genkk+3], 
								add8_in[gengg][genkk+2], 
								add8_in[gengg][genkk+1], 
								add8_in[gengg][genkk+0] } ),
				.add8  ( add8_out_a[gengg][genkk+4-:5] )
			);
			end // genkk
		end // gengg
	endgenerate
				
	// unpack the add8 outputs into array form
	logic [0:GENS-1][HEIGHT+2*GENS-1:0][WIDTH+2*GENS-1:0][2:0] add8_out_b;
	always_comb begin
		for( int gg = 0; gg < GENS; gg++ ) begin // generations
			for( int yy = gg+1; yy < HEIGHT+2*GENS-gg-1; yy++ ) begin // narrowing height
				for( int xx = gg+1; xx < WIDTH+2*GENS-gg-1; xx++ ) begin // narrowing width
					add8_out_b[gg][yy][xx] = add8_out_a[gg][(yy-gg-1)*(WIDTH+2*(GENS-gg-1))+xx-gg-1];
				end // xx
			end // yy
		end // gg
	end
		
	// Register and connect up add8 outputs and delay orig accordingly
	logic [0:GENS-1][HEIGHT+2*GENS-1:0][WIDTH+2*GENS-1:0][2:0] add8; // final add8
	logic [0:GENS-1][HEIGHT+2*GENS-1:0][WIDTH+2*GENS-1:0]      orig; // de	
	always_ff @(posedge clk) begin
		for( int gg = 0; gg < GENS; gg++ ) begin // generations
			for( int yy = gg+1; yy < HEIGHT+2*GENS-gg-1; yy++ ) begin // narrowing width
				for( int xx = gg+1; xx < WIDTH+2*GENS-gg-1; xx++ ) begin // narrowing width
					add8[gg][yy][xx] <= add8_out_b[gg][yy][xx];
					orig[gg][yy][xx] <=    cell_in[gg][yy][xx]; // and delay orig cell to keep aligned					
				end // xx
			end // yy
		end // gg
	end

	// Cell life state calculated 
	always_comb begin : _life_cell
		for( int gg = 0; gg < GENS; gg++ ) begin
			for( int xx = gg+1; xx < WIDTH+2*GENS-gg-1 ; xx++ ) begin
				for( int yy = gg+1; yy < HEIGHT+2*GENS-gg-1; yy++ ) begin // ***LIFE***
					cell_out[gg][yy][xx] = ((( add8[gg][yy][xx]==3 ) &&  orig[gg][yy][xx] ) ||  // rule: alive and 3 neighbours --> stay alive
													(( add8[gg][yy][xx]==2 ) &&  orig[gg][yy][xx] ) ||  // rule: alive and 2 neighbours --> stay Alive
													(( add8[gg][yy][xx]==3 ) && !orig[gg][yy][xx] ))    // rule:  dead and 3 neighbours --> newly Alive
																										? 1'b1 : 1'b0; // otherwise the cell dies or remains dead.
				end // yy
			end // xx
		end // gg
	end

	// Final Generation output reg is ram write data
	logic [HEIGHT-1:0][WIDTH-1:0] out; // final registered output generation	 
	always_ff @(posedge clk) begin 
		for( int xx = 0; xx < WIDTH; xx++ ) 
			for( int yy = 0; yy < HEIGHT; yy++ ) 
				out[yy][xx] <= cell_out[GENS-1][yy+GENS][xx+GENS];
	end
			
	// Format write data for memory inputs with boundary replication and cross wiring
	always_comb begin
		// mem_din central array
		for( int xx = 0; xx < WIDTH; xx++ ) begin
			for( int yy = 0; yy < HEIGHT; yy++ ) begin
				mem11_din[yy*WIDTH+xx] = out[yy][xx];
			end // yy
		end // gg
		// Top Bot
		for( int xx = 0; xx < WIDTH; xx ++ ) begin
			for( int yy = 0; yy < GENS; yy++ ) begin
				mem01_din[yy*WIDTH+xx] = out[HEIGHT-GENS+yy][xx]; // Top is taken from botton
				mem21_din[yy*WIDTH+xx] = out[            yy][xx]; // Bot is taken from top
			end // yy
		end // xx
		// Sides
		for( int xx = 0; xx < GENS; xx++ ) begin
			for( int yy = 0; yy < HEIGHT; yy++ ) begin
				mem10_din[yy*GENS+xx]  = out[yy][WIDTH-GENS+xx];	// Left is taken from right
				mem12_din[yy*GENS+xx]  = out[yy][           xx];	// Right is taken from left
			end // yy
		end // xx
		// Corners
		for( int xx = 0; xx < GENS; xx++ ) begin
			for( int yy = 0; yy < GENS; yy++ ) begin
				mem00_din[yy*GENS+xx] = out[HEIGHT-GENS+yy][WIDTH-GENS+xx]; 	// UL gets LR
				mem02_din[yy*GENS+xx] = out[HEIGHT-GENS+yy][           xx]; 	// UR gets LL
				mem20_din[yy*GENS+xx] = out[            yy][WIDTH-GENS+xx]; 	// LL gets UR
				mem22_din[yy*GENS+xx] = out[            yy][           xx]; 	// LR gets UL
			end // xx
		end // yy
	end

endmodule // life_engine_2D	

/////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////



// 1.5D Life engine
// WIDTH x HEIGHT array of life cells spanning the full with of the arrya
// GENS copies of the block to give multiple generations.
module life_engine_1d5 #(
	WIDTH = 256,	// Array width = Datapath width
	DEPTH = 256,	// memory Depth
	HEIGHT = 8,	 	// Datapath height
	DBITS = 8,		// depth address bitwidth
	GENS  = 2		// hardware Generations per pass
) (
	// System
	input clk,
	input reset,
	// Memory Control
	input logic [DBITS-1:0] raddr, // also used for init writes
	input logic [DBITS-1:0] waddr,
	input	logic [HEIGHT-1:0] we,
	// cell array shift input
	input logic sh,
	// External Data Control
	input logic ld,
	input logic [2:0] ld_sel, // addressed row in the block
	output logic [WIDTH-1:0] dout, // data out
	// Init port
	input logic init,
	input logic [WIDTH-1:0] init_data
	
);

	// Memory
	
	logic [WIDTH*HEIGHT-1:0] ram [0:DEPTH-1];
	logic [HEIGHT-1:0][WIDTH-1:0] mem_wdata;
	logic [HEIGHT-1:0][WIDTH-1:0] mem_rdata;

	// Fully registered 2 port ram 2048 bits = Max BW
	// Generate loop of 8x our 256 bit wide ones
	
	genvar genii;
	generate 
		for( genii = 0; genii < HEIGHT; genii++ ) begin : _cell_ram
			cell_ram _cell_ram (
				.clock( clk ),
				.data( (init) ? init_data : mem_wdata[genii] ),
				.rdaddress( raddr ),
				.wraddress( waddr ),
				.wren( we[genii] ),
				.q( mem_rdata[genii] )
			);
		end
	endgenerate
	
	// Video Read port
	logic [1:0] ld_del;
	logic [1:0][2:0] ld_sel_del;
	always_ff @(posedge clk) begin
		ld_del[1:0] <= { ld_del[0], ld };
		ld_sel_del[1:0] <= { ld_sel_del[0], ld_sel[2:0] };
		if( ld_del[1] ) dout <= mem_rdata[ld_sel_del[1][2:0]]; // latch 1 row for video read.
	end

	// Read data registers 3 consecutive read words (each 256x8 bits)
	
	logic [2:0][HEIGHT-1:0][WIDTH-1:0] cell_array;
	always_ff@(posedge clk)
	begin
		cell_array[2:1] <= cell_array[1:0];
		cell_array[0]   <= mem_rdata;
	end
	
	// Build cell_input array for ease of itteration
	logic [HEIGHT+2*GENS-1:0][WIDTH-1:0] cell_input;
	always_comb begin
		for( int xx = 0; xx < WIDTH; xx++ ) begin
			for( int yy = 0; yy < GENS; yy++ ) begin // above overlap
				cell_input[yy            ][xx] = cell_array[2][HEIGHT-GENS+yy][xx];
			end
			for( int yy = 0; yy < HEIGHT; yy++ ) begin // main array
				cell_input[yy+GENS       ][xx] = cell_array[1][yy]            [xx];
			end
			for( int yy = 0; yy < GENS; yy++ ) begin // below overlap
				cell_input[yy+GENS+HEIGHT][xx] = cell_array[0][yy]            [xx];
			end
		end
	end
	

	// add3 - 3bit vertical tally stage is registered
	logic [0:GENS-1][HEIGHT+2*GENS-3:0][WIDTH-1:0][1:0] add3;
	logic [0:GENS-1][HEIGHT+2*GENS-3:0][WIDTH-1:0]      orig; // register the center for later use
	logic [0:GENS-1][HEIGHT+2*GENS-3:0][WIDTH-1:0]      cell_next;
	always_ff @(posedge clk ) begin : _add3
		for( int gg = 0; gg < GENS; gg++ ) begin
			for( int xx = 0; xx < WIDTH; xx++ ) begin
				for( int yy = 0; yy < HEIGHT + 2*GENS - 2*gg - 2; yy++ ) begin
					if( gg == 0 ) begin // data from cell array 
						add3[gg][yy][xx] <= { 1'b0, cell_input[yy+0][xx] } +
												  { 1'b0, cell_input[yy+1][xx] } +
												  { 1'b0, cell_input[yy+2][xx] } ;
						orig[gg][yy][xx] <= cell_input[yy+1][xx];
					end else begin // Data from prev gen
						add3[gg][yy][xx] <= { 1'b0, cell_next[gg-1][yy+0][xx] } +
												  { 1'b0, cell_next[gg-1][yy+1][xx] } +
												  { 1'b0, cell_next[gg-1][yy+2][xx] } ;
						orig[gg][yy][xx] <= cell_next[gg-1][yy+1][xx];

					end
				end // yy
			end // xx
		end // gg
	end

	// add9 is sum of 3 add3's horizontally, combinatorial
	logic [0:GENS-1][HEIGHT+2*GENS-3:0][WIDTH-1:0][2:0] add9;
	always_comb begin : _add9
		for( int gg = 0; gg < GENS; gg++ ) begin
			for( int xx = 0; xx < WIDTH; xx++ ) begin
				for( int yy = 0; yy < HEIGHT + GENS - 2*gg - 2; yy++ ) begin
					if( xx == 0 ) begin // left wrap
						add9[gg][yy][xx] =  { 1'b0, add3[gg][yy][WIDTH-1] } +
											     { 1'b0, add3[gg][yy][xx+0] } +
											     { 1'b0, add3[gg][yy][xx+1] } ;
					end else if( xx == WIDTH-1 ) begin // Right wrap
						add9[gg][yy][xx] =  { 1'b0, add3[gg][yy][xx-1] } +
											     { 1'b0, add3[gg][yy][xx+0] } +
											     { 1'b0, add3[gg][yy][   0] } ;
					end else begin
						add9[gg][yy][xx] =  { 1'b0, add3[gg][yy][xx-1] } +
											     { 1'b0, add3[gg][yy][xx+0] } +
											     { 1'b0, add3[gg][yy][xx+1] } ;
					end
				end // yy
			end // xx
		end // gg
	end

	// Cell state is registered

	always_ff @(posedge clk) begin : _life_cell
		for( int gg = 0; gg < GENS; gg++ ) begin
			for( int xx = 0; xx < WIDTH; xx++ ) begin
				for( int yy = 0; yy < HEIGHT + GENS - 2*gg - 2; yy++ ) begin // ***LIFE***
					cell_next[gg][yy][xx] <= ((( add9[gg][yy][xx]==4 ) &&  orig[gg][yy][xx] ) ||  // 4 alive of which we are 1 --> rule: alive and 3 neighbours --> stay alive
													  (( add9[gg][yy][xx]==3 ) &&  orig[gg][yy][xx] ) ||  // 3 alive of which we are 1 --> rule: alive and 2 neighbours --> stay Alive
													  (( add9[gg][yy][xx]==3 ) && !orig[gg][yy][xx] ))    // 3 alive and we are not    --> rule:  dead and 3 neighbours --> newly Alive
																										? 1'b1 : 1'b0; // otherwise the cell dies or remains dead.
				end // yy
			end // xx
		end // gg
	end
		
	// Final Generation output reg is ram write data
	
	always_comb 
		for( int xx = 0; xx < WIDTH; xx++ ) 
			for( int yy = 0; yy < HEIGHT; yy++ ) 	
				mem_wdata[yy][xx] = cell_next[GENS-1][yy][xx];
			

endmodule // life_engine_1d5	

// Linear Life engine complex repacked to get 7.3 LE
// WIDTH copies of life engine spanning a full row of the array.
// GENS copies of the row to give multiple generations per pass.		
module life_engine_packed #(
	WIDTH = 256,	// Datapath width, image width
	DEPTH = 256,	// memory depth, image height
	HEIGHT = 0,		// Unused here
	DBITS = 8,		// depth address bitwidth
	GENS  = 1		// hardware Generations per pass
) (
	input clk,
	input reset,
	// Memory Control
	input logic [DBITS-1:0] raddr, // also used for init writes
	input logic [DBITS-1:0] waddr,
	input	logic we,
	// cell array shift input
	input logic sh,
	// External Data Control
	input logic ld,
	output logic [WIDTH-1:0] dout, // data out
	// Init port
	input logic init,
	input logic [WIDTH-1:0] init_data
	
);

//////////////////
// SAME
//////////////////

	// Memory
	
	logic [WIDTH-1:0] ram [0:DEPTH-1];
	logic [WIDTH-1:0] mem_wdata;
	logic [WIDTH-1:0] mem_rdata;

	// Fully registered 2 port ram
	cell_ram _cell_ram (
		.clock( clk ),
		.data( (init) ? init_data : mem_wdata ),
		.rdaddress( raddr ),
		.wraddress( waddr ),
		.wren( we ),
		.q( mem_rdata )
	);
	
	logic [1:0] ld_del
;	always_ff@(posedge clk) begin
		ld_del[1:0] <= { ld_del[0], ld };
		if( ld_del[1] ) dout <= mem_rdata;
	end
		
	// Shift register arrays
	logic [0:GENS-1][2:0][WIDTH-1:0] cell_array;
	
	// Shift register input
	logic [0:GENS-1][WIDTH-1:0] cell_next; // new generation input
	always_ff@(posedge clk)
	begin
		cell_array[0][2:1] <= cell_array[0][1:0];
		cell_array[0][0]   <= mem_rdata;
		for( int gg = 1; gg < GENS; gg++ ) begin
			cell_array[gg][2:1] <= cell_array[gg][1:0];
			cell_array[gg][0]   <= cell_next[gg-1];
		end
	end

//////////////////
// REPACKED
//////////////////
	
	// Hardcoded WIDTH = 256 for dev, parameterize later
	
	logic [0:GENS-1][WIDTH-1:0][1:0] add3;	 // | shape	
	logic [0:GENS-1][WIDTH-1:0][2:0] add4;	 // = shape
	logic [0:GENS-1][WIDTH-1:0][3:0] add8; // final add8
	
	// Registered Input adders
	always_comb begin
		for( int gg = 0; gg < GENS; gg++ ) begin
			for( int xx = 0; xx < WIDTH; xx++ ) // =shape
				add4[gg][xx] = 	{ 2'b00, cell_array[gg][2][xx] } +
										{ 2'b00, cell_array[gg][2][(xx==WIDTH-1)?0:(xx+1)] } +
										{ 2'b00, cell_array[gg][0][xx] } +
										{ 2'b00, cell_array[gg][0][(xx==WIDTH-1)?0:(xx+1)] };
										
			for( int xx = 0; xx < WIDTH; xx++ ) // |shape
				add3[gg][xx]  =   { 1'b0, cell_array[gg][2][xx] } +
										{ 1'b0, cell_array[gg][1][xx] } +
										{ 1'b0, cell_array[gg][0][xx] } ;
		end //gg
	end
	
	// Add 8 adders

	//always_comb begin
	//	for( int gg = 0; gg < GENS; gg++ ) begin
	//		for( int xx = 0 ; xx < WIDTH; xx+=3 ) // |=*
	//			add8[gg][xx] = { 1'b0,  add4[gg][xx] } +
	//								{ 2'b00, add3[gg][(xx==0)?(WIDTH-1):(xx-1)] } +
	//								cell_array[gg][1][(xx==WIDTH-1)?0:(xx+1)] ;
	//		for( int xx = 1 ; xx < WIDTH; xx+=3 ) // |=*
	//			add8[gg][xx] = { 1'b0,  add4[gg][xx] } +
	//								{ 2'b00, add3[gg][xx-1] } + 
	//								cell_array[gg][1][xx+1] ;
	//		for( int xx = 2 ; xx < WIDTH; xx+=3 ) // *=|
	//			add8[gg][xx] = { 1'b0,  add4[gg][xx-1] } + 
	//								{ 2'b00, add3[gg][xx+1] } + 
	//								cell_array[gg][1][xx-1] ;	 
	//	end // gg
	//end
	
	// arrange the inputs for the add8's
	logic [GENS*WIDTH-1:0][5:0] add8_in;	// line up all the add8's inputs (wrap accross generations)
	always_comb begin
		for( int gg = 0; gg < GENS; gg++ ) begin
			for( int xx = 0 ; xx < WIDTH; xx+=3 ) // |=*
				add8_in[gg*WIDTH+xx] = { add4[gg][xx] ,  add3[gg][(xx==0)?(WIDTH-1):(xx-1)], cell_array[gg][1][(xx==WIDTH-1)?0:(xx+1)] };
			for( int xx = 1 ; xx < WIDTH; xx+=3 ) // |=*
				add8_in[gg*WIDTH+xx] = { add4[gg][xx] ,  add3[gg][xx-1]                    , cell_array[gg][1][xx+1] };
			for( int xx = 2 ; xx < WIDTH; xx+=3 ) // *=|
				add8_in[gg*WIDTH+xx] = { add4[gg][xx-1], add3[gg][xx+1]                    , cell_array[gg][1][xx-1] };	 
		end // gg
	end
	
	
	// generate Adders
	logic [GENS*WIDTH-1+5:0][2:0] add8_out;
	genvar kk;
	generate
		for( kk = 0; kk < (GENS*WIDTH); kk+=5 ) begin : _gen431
			add431_cell _add431(
				.in	( {   ((kk+4)>=GENS*WIDTH)?6'h00:add8_in[kk+4], 
								((kk+3)>=GENS*WIDTH)?6'h00:add8_in[kk+3], 
								((kk+2)>=GENS*WIDTH)?6'h00:add8_in[kk+2], 
								((kk+1)>=GENS*WIDTH)?6'h00:add8_in[kk+1], 
								((kk+0)>=GENS*WIDTH)?6'h00:add8_in[kk+0] } ),
				.add8  ( add8_out[kk+4-:5] )
			);
		end
	endgenerate
				
	// Connect up the add8 outputs

	always_ff @(posedge clk) begin
		for( int gg = 0; gg < GENS; gg++ )
			for( int xx = 0; xx < WIDTH; xx++ )
				add8[gg][xx] <= add8_out[gg*WIDTH+xx];
	end
				
	// Calculate cell state
	always_comb begin
		for( int gg = 0; gg < GENS; gg++ )
			for( int xx = 0; xx < WIDTH; xx++ )
				cell_next[gg][xx]  =((( add8[gg][xx][2:0]==3 ) &&  cell_array[gg][2][xx] ) ||  // 4 alive of which we are 1 --> rule: alive and 3 neighbours --> stay alive
											(( add8[gg][xx][2:0]==2 ) &&  cell_array[gg][2][xx] ) ||  // 3 alive of which we are 1 --> rule: alive and 2 neighbours --> stay Alive
											(( add8[gg][xx][2:0]==3 ) && !cell_array[gg][2][xx] )) 	  // 3 alive and we are not    --> rule:  dead and 3 neighbours --> newly Alive
																			  ? 1'b1 : 1'b0; // otherwise the cell dies or remains dead.
	end
		
	// Final Generation output reg
	always_ff@(posedge clk)
		mem_wdata <= cell_next[GENS-1];

endmodule



// Linear Life engine
// WIDTH copies of life engine spanning a full row of the array.
// GENS copies of the row to give multiple generations per pass.
module life_engine #(
	WIDTH = 256,	// Datapath width, image width
	DEPTH = 256,	// memory depth, image height
	HEIGHT = 0,		// Unused here
	DBITS = 8,		// depth address bitwidth
	GENS  = 1		// hardware Generations per pass
) (
	input clk,
	input reset,
	// Memory Control
	input logic [DBITS-1:0] raddr, // also used for init writes
	input logic [DBITS-1:0] waddr,
	input	logic we,
	// cell array shift input
	input logic sh,
	// External Data Control
	input logic ld,
	output logic [WIDTH-1:0] dout, // data out
	// Init port
	input logic init,
	input logic [WIDTH-1:0] init_data
	
);

	// Memory
	
	logic [WIDTH-1:0] ram [0:DEPTH-1];
	logic [WIDTH-1:0] mem_wdata;
	logic [WIDTH-1:0] mem_rdata;

	// Fully registered 2 port ram
	cell_ram _cell_ram (
		.clock( clk ),
		.data( (init) ? init_data : mem_wdata ),
		.rdaddress( raddr ),
		.wraddress( waddr ),
		.wren( we ),
		.q( mem_rdata )
	);
	
	logic [1:0] ld_del
;	always_ff@(posedge clk) begin
		ld_del[1:0] <= { ld_del[0], ld };
		if( ld_del[1] ) dout <= mem_rdata;
	end
		
	// Shift register arrays
	logic [0:GENS-1][2:0][WIDTH-1:0] cell_array;
	
	// Shift register input
	logic [1:0] sh_del;
	logic [0:GENS-1][WIDTH-1:0] cell_next; // new generation input
	always_ff@(posedge clk)
	begin
		// delay shift for global reg enable
		sh_del <= { sh_del[0], sh };
		
		// Cell shift register array is updated
		if( sh_del[1] ) begin
			cell_array[0][2:1] <= cell_array[0][1:0];
			cell_array[0][0]   <= mem_rdata;
			for( int gg = 1; gg < GENS; gg++ ) begin
				cell_array[gg][2:1] <= cell_array[gg][1:0];
				cell_array[gg][0]   <= cell_next[gg-1];
			end
		end else begin // hold
			cell_array <= cell_array;
		end
	end

	logic [0:GENS-1][WIDTH-1:0][1:0] add3;
	logic [0:GENS-1][WIDTH-1:0][1:0] add3_q;
	logic [0:GENS-1][WIDTH-1:0][3:0] add9;

	always_comb begin : _life_cells
		// Form add3 array
		for( int gg = 0; gg < GENS; gg++ )
			for( int ii = 0; ii < WIDTH; ii++ ) begin
			add3[gg][ii] =  { 1'b0, cell_array[gg][2][ii] } +
								 { 1'b0, cell_array[gg][1][ii] } +
								 { 1'b0, cell_array[gg][0][ii] } ;
		end
		// Form add9 array (adding 3 x add3 values)
		for( int gg = 0; gg < GENS; gg++ )
			for( int ii = 0; ii < WIDTH; ii++ ) begin
				add9[gg][ii] =  { 2'b00, (ii==255)?add3_q[gg][0]:add3_q[gg][ii+1] } +
									 { 2'b00,                         add3_q[gg][ii+0] } +
									 { 2'b00, (ii==0)?add3_q[gg][255]:add3_q[gg][ii-1] } ;
		end
		// Calculate cell state
		for( int gg = 0; gg < GENS; gg++ )
			for( int ii = 0; ii < WIDTH; ii++ ) begin
				cell_next[gg][ii] = ((( add9[gg][ii]==4 ) &&  cell_array[gg][2][ii] ) ||  // 4 alive of which we are 1 --> rule: alive and 3 neighbours --> stay alive
											(( add9[gg][ii]==3 ) &&  cell_array[gg][2][ii] ) ||  // 3 alive of which we are 1 --> rule: alive and 2 neighbours --> stay Alive
											(( add9[gg][ii]==3 ) && !cell_array[gg][2][ii] )) 	  // 3 alive and we are not    --> rule:  dead and 3 neighbours --> newly Alive
																			  ? 1'b1 : 1'b0; // otherwise the cell dies or remains dead.
		end
	end

	// GENS * WIDTH register
	// global reg enable wire
	always @(posedge clk) 
		if( sh_del[1] ) add3_q <= add3;
		
	// Final Generation output reg
	always_ff@(posedge clk)
		if( sh_del[1] ) mem_wdata <= cell_next[GENS-1];

endmodule




// Implement 5 add8 in a single carry chain of 5*3+1=16 cells
module add431_cell
	(
		input  logic [4:0][5:0] in,	// 5 sets of 6bits { add4[2:0], addr3[1:0], add1 }
		output logic [4:0][2:0] add8 // Sum of 8 with in 3-bits with 8 wrapping to 0; 
	);

	logic [4:0][2:0] add4;
	logic [4:0][1:0] add3;
	logic [0:4]      add1; // null operation: sum of 1 bit 
	
	// Extractd First stage adder inputs
	always_comb begin
		for( int ii = 0; ii < 5; ii++ )
			{ add4[ii][2:0], add3[ii][1:0], add1[ii] } = in[ii][5:0];
	end

	// now we build 5 adders: add8[ii] = add4[ii] + add3[ii] + add1[ii] 
	// implemented as 16 carry chain linked LEs. (instead of 20les otherwise)
	
	// Each LE has a carry and sum outputs and 3 lut input bits
	logic [15:0] sout;
	logic [15:0] cout;
	logic [15:0][2:0] lut_in;
	
	// Build the carry chain and connect lut inputs.
	//						Lut Inputs  C       B        A
	assign lut_in[ 0][2:0] = {     1'b0, add1[0]   ,       1'b0} ;	// carry feed in of add1
	assign lut_in[ 1][2:0] = { cout[ 0], add3[0][0], add4[0][0]} ;
	assign lut_in[ 2][2:0] = { cout[ 1], add3[0][1], add4[0][1]} ;
	assign lut_in[ 3][2:0] = { cout[ 2], add1[1]   , add4[0][2]} ; // merge msb addition and carry-feedin.
	assign lut_in[ 4][2:0] = { cout[ 3], add3[1][0], add4[1][0]} ;
	assign lut_in[ 5][2:0] = { cout[ 4], add3[1][1], add4[1][1]} ;
	assign lut_in[ 6][2:0] = { cout[ 5], add1[2]   , add4[1][2]} ; // merge msb addition and carry-feedin.
	assign lut_in[ 7][2:0] = { cout[ 6], add3[2][0], add4[2][0]} ;
	assign lut_in[ 8][2:0] = { cout[ 7], add3[2][1], add4[2][1]} ;
	assign lut_in[ 9][2:0] = { cout[ 8], add1[3]   , add4[2][2]} ; // merge msb addition and carry-feedin.
	assign lut_in[10][2:0] = { cout[ 9], add3[3][0], add4[3][0]} ;
	assign lut_in[11][2:0] = { cout[10], add3[3][1], add4[3][1]} ;
	assign lut_in[12][2:0] = { cout[11], add1[4]   , add4[3][2]} ; // merge msb addition and carry-feedin.
	assign lut_in[13][2:0] = { cout[12], add3[4][0], add4[4][0]} ;
	assign lut_in[14][2:0] = { cout[13], add3[4][1], add4[4][1]} ;
	assign lut_in[15][2:0] = { cout[14],       1'b0, add4[4][2]} ;	// final msb addition
	
	// Now the LE manually instantiated
	genvar gg;
	generate
		for( gg = 0; gg < 16; gg++ ) begin : _add8_chain
			fiftyfivenm_lcell_comb #( // twas hard to find this
				.dont_touch ( "off" ), // Allows synth to swapA,B Inputs and account for carry inversions
				.lpm_type   ( "fiftyfivenm_lcell_comb"), // infers Max10 is a 55nm chip?
				.sum_lutc_input ( "cin" ),	// set arithmetic mode.				
				.lut_mask 	( (gg== 0) ? 16'h00CC :		// Sum=0     , Carry = B
								  (gg== 1) ? 16'h96E8 :		// Sum=A+B+C , Carry = A&B|C&B|A&C 
								  (gg== 2) ? 16'h96E8 :		// Sum=A+B+C , Carry = A&B|C&B|A&C
								  (gg== 3) ? 16'h5ACC :		// Sum=A  +C , Carry = B
								  (gg== 4) ? 16'h96E8 :		// Sum=A+B+C , Carry = A&B|C&B|A&C
								  (gg== 5) ? 16'h96E8 :		// Sum=A+B+C , Carry = A&B|C&B|A&C 
								  (gg== 6) ? 16'h5ACC :		// Sum=A  +C , Carry = B
								  (gg== 7) ? 16'h96E8 :		// Sum=A+B+C , Carry = A&B|C&B|A&C 
								  (gg== 8) ? 16'h96E8 :		// Sum=A+B+C , Carry = A&B|C&B|A&C
								  (gg== 9) ? 16'h5ACC :		// Sum=A  +C , Carry = B
								  (gg==10) ? 16'h96E8 :		// Sum=A+B+C , Carry = A&B|C&B|A&C
								  (gg==11) ? 16'h96E8 :		// Sum=A+B+C , Carry = A&B|C&B|A&C 
								  (gg==12) ? 16'h5ACC :		// Sum=A  +C , Carry = B
								  (gg==13) ? 16'h96E8 :		// Sum=A+B+C , Carry = A&B|C&B|A&C 
								  (gg==14) ? 16'h96E8 :		// Sum=A+B+C , Carry = A&B|C&B|A&C
								/*(gg==15)*/ 16'h5A00 )		// Sum=A  +C , Carry = 0
			) _add8s (
				.dataa	(lut_in[gg][0]),
				.datab	(lut_in[gg][1]),
				.datac	(1'b0),  // not used, carry inpu
				.datad	(1'b1),	// 1 selects sum as output, 0 carry
				.cin		(lut_in[gg][2]),
				.combout	(sout[gg]),
				.cout		(cout[gg])
			);		
		end // gg
	endgenerate
	
	// Assign the add8 outputs from sout skipping sout[0]
	always_comb begin
		for( int ii = 0; ii < 5; ii++ )
			add8[ii][2:0] = sout[3*(ii+1)-:3];
	end
endmodule