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
