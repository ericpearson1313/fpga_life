// Conway's Game of Life
// Cellular Automata


`timescale 1ns / 1ps
module life_core
(
	// Input Buttons
	input  logic arm_button,
	input  logic fire_button,

	// Output LED/SPK
	output logic arm_led_n,
	output logic cont_led_n,
	output logic speaker,
	output logic speaker_n,
	
	// Bank 1A: Analog Inputs / IO
	output [8:1] anain,
	
	// Bank 7, future serial port
	inout [6:0] digio,
	
	// Bank 1B Rs232
	input 		rx232,
	output 		tx232,
	
	// High Voltage 
	output logic lt3420_charge,
	input  logic lt3420_done,
	output logic pwm,	
	output logic dump,
	input  logic cont_n,
	
	// External A/D Converters (2.5v)
	output logic        ad_cs,
	output logic		  ad_sclk,
	input  logic  [1:0] ad_sdata_a,
	input  logic  [1:0] ad_sdata_b,
	input  logic        CIdiag,
	input  logic        CVdiag,
	input  logic        LIdiag,
	input  logic 		  LVdiag,
	
	// External Current Control Input
	input	 logic  [2:0] iset, // Current target in unit amps  
	
	// SPI8 Bus
	inout  wire [7:0]  spi8_data_pad,   //   pad_io.export
	inout  wire spi_clk0,
	inout  wire spi_ncs,
	inout  wire spi_ds,
	inout  wire spi_nrst,
	
	// HDMI Output 1 (Tru LVDS)
	output logic		hdmi_d0,
	output logic		hdmi_d1,
	output logic		hdmi_d2,
	output logic      hdmi_ck,

	// HDMI Output 2 (Tru LVDS)
	output logic		hdmi2_d0,
	output logic		hdmi2_d1,
	output logic		hdmi2_d2,
	output logic      hdmi2_ck,
	
	// Input clock, reset
	output logic clk_out, // Differential output
	input logic clk_in,	// Reference 48Mhz or other
	input logic reset_n
);

/////////////////////
//
// Unused IO Tie-off/Turn off
//		Extdev may/may_not be present
//
/////////////////////

	// Turn off leds speaker
	assign arm_led_n	= 1'b0; 
	assign cont_led_n	= 1'b0;
	//assign speaker		= 1'b0;
	//assign speaker_n	= 1'b0;
	
	// Float future comm port
	assign digio = 7'bzzz_zzzz;
	
	// Rs232
	assign tx232 = rx232; // wire through
	
	// Safe the High Voltage 
	assign lt3420_charge = 1'b0;
	assign  pwm 			= 1'b0;
	assign  dump 			= 1'b1; // turn on dump for safety
	
	// Tie off Turn off A/D Converters 
	assign ad_cs 	= 1'b0;
	assign ad_sclk = 1'b0;
	
	// Tie off/turn off SPI8 Bus
	assign spi8_data_pad = 8'bzzzz_zzzz;
	assign spi_clk0 	= 1'b0;
	assign spi_ncs 	= 1'b1;
	assign spi_ds 		= 1'bz;
	assign spi_nrst 	= 1'b0;


/////////////////////
//
// Clock and Reset
//
/////////////////////


// PLL (only 1 PLL in E144 package!)

logic clk;	// global 48Mhz clock
logic clk4; // global 192MhZ spi8 clk
logic hdmi_clk; 	// Pixel clk, apparentlyi can support 720p
logic hdmi_clk5;  // 5x pixel clk clock for data xmit, 10b*3=30/3lanes=10ddr=5 

trial_pll _spll(
	.inclk0 (clk_in),		// External clock input
	.c0     (clk_out), 	// Flash Clock 6Mhz, also External clock output differential
	.c1	  (clk),			// Global Clock ADC rate 48 Mhz
	.c2	  (clk4),		// Global Clock SPI8 rate 192 Mhz
	.c3	  (hdmi_clk),	// HDMI pixel clk
	.c4	  (hdmi_clk5)  // HDMI ddr clock 5x
	);
	
// assign ad_sclk  = !clk;		// TODO: Ren-enable if ADC is used. Impotant that its inverterted!!!!

// delayed from fpga config and external reset d-assert

logic [3:0] reset_shift = 0; // initial value upon config
always @(posedge clk) begin
		if( !reset_n ) begin
			reset_shift <= 4'h0;
		end else begin
			if( reset_shift != 4'HF ) begin
				reset_shift[3:0] <= reset_shift[3:0] + 4'h1;
			end else begin
				reset_shift[3:0] <= reset_shift[3:0];
			end
		end
end

logic reset;
assign reset = (reset_shift[3:0] != 4'hF) ? 1'b1 : 1'b0; // reset de-asserted after all bit shifted in 


/////////////////////
//
// Debug LEDs anain[8:1]
//
/////////////////////	

assign anain[3:1] = iset[2:0]; // active low switch inputs
assign anain[4] = !reset;
logic [24:0] count;
always @(posedge clk4) begin
	count <= count + 1;
end
assign anain[8:5] = count[24:21];
assign anain[8]=count[24];

// Fire Button

logic fire_button_debounce;
logic fbd_delay;
logic short_fire;
logic long_fire; // fire button held down >1 wsec

debounce _firedb ( .clk( clk ), .reset( reset ), .in( fire_button ), .out( fire_button_debounce ), .long( long_fire ));

always @(posedge clk) begin
	fbd_delay <= fire_button_debounce;
	short_fire <= fire_button_debounce & !fbd_delay;
end

// Speaker C5 to C6
logic [15:0] tone_cnt;
logic cont_tone;
logic spk_toggle;

always @(posedge clk) begin
	if( tone_cnt == 0 ) begin
		spk_toggle <= !spk_toggle;
		tone_cnt   <= ( fire_button_debounce  ) ? { 16'h2CCA } /* C5 */ : 
								   //( key == 5'h12 ) ? { 16'h27E7 } /* D5 */ :
								   //( key == 5'h13 ) ? { 16'h238D } /* E5 */ :
								   //( key == 5'h14 ) ? { 16'h218E } /* F5 */ :
								   //( key == 5'h15 ) ? { 16'h1DE5 } /* G5 */ :
								   //( key == 5'h16 ) ? { 16'h1AA2 } /* A5 */ :
								   //( key == 5'h17 ) ? { 16'h17BA } /* B5 */ :
								   //( key == 5'h18 ) ? { 16'h1665 } /* C6 */ : 
														                0; // mute
	end else begin
		tone_cnt <= tone_cnt - 1;
		spk_toggle <= spk_toggle;
	end
end

assign speaker = spk_toggle; 
assign speaker_n = !speaker;

/////////////////////
//
// Life Engine
//
/////////////////////
/////////////////////////////
	parameter WIDTH = 45;	// Datapath width, image width
	parameter DEPTH = 256;	// memory depth, image height
	parameter HEIGHT = 44;	// Datapath height
	parameter DBITS = 8;		// depth address bitwidth
	parameter GENS  = 1;	// hardware Generations per pass
	parameter WIDTH_B = 16;  // blocks wide
	parameter HEIGHT_B = 10; // blocks high
/////////////////////////////


	// Integrate the life engine
	logic init_word;
	logic [HEIGHT-1:0][WIDTH-1:0] read_word; // latched read word
	logic [2:0][2:0][DBITS-1:0] raddr;
	logic [DBITS-1:0] waddr;
	logic we; // write enable of life calc output or current init word
	logic sh; // shift in a row (from last cycle read)
	logic ld; // latch a row into dout (from last cycle)
	logic we_init; // selects init_word as we data source 
	logic init;	
	
	life_engine_2D #(
		.WIDTH( WIDTH ),
		.DEPTH( DEPTH ),
		.HEIGHT( HEIGHT ),
		.DBITS( DBITS ),
		.GENS(  GENS  )
		)  _life_engine (
		.clk  ( clk4 ),
		.reset( reset ),
		.raddr( raddr ),
		.waddr( waddr ),
		.we( we ),
		//.sh( sh ),
		.ld( ld ),  // loads addresssed word into dout port for the video scan
		.dout( read_word ), // full array wordlatched by ld flag, for video shift reg
		.init( init ), // data is shifted into word, hold 1M cycles-ish, write as need
		.init_data( init_word ) // bit shift input
	);
	
	// Generate Init word (lfsr for now)
	// LFSR from: https://datacipy.elektroniche.cz/lfsr_table.pdf
	
	logic [255:0] lfsr;
	always_ff @(posedge clk4 ) begin
		if( reset ) begin
				  lfsr <= { 16'b1011000001011000,  
								16'b1100000100111010, 
								16'b0101000001101111, 
								16'b1000001001110000, 
								16'b1101101100001001, 
								16'b0101110111110010, 
								16'b1011100000011111, 
								16'b1111110000011111, 
								16'b0010111111011001, 
								16'b1100100100110111, 
								16'b1100100110100000, 
								16'b1011000110011111, 
								16'b0111001010110001, 
								16'b0011011000011000, 
								16'b1001101101000100, 
								16'b0101001100100001 }; // start non zero rand
		end else begin // Taps 255 253 250 245  -- zewro based
			lfsr <= {             lfsr[0],		// 255
						 lfsr[255],		
						 lfsr[254] ^ lfsr[0],		// 253th
						 lfsr[253:252],
						 lfsr[251] ^ lfsr[0],
						 lfsr[250:247],
						 lfsr[246] ^ lfsr[0],
						 lfsr[245:1] };
		end
	end
	
	assign init_word = lfsr[0];
	
	// Life Control state machine.
	// Generates cell read and write addresses 
	// and we and rd signals.

	// Signal from video display (aready in clk4)
	logic [DBITS-1:0] vraddr; // ASYNC loaded, but stable before use in clk4 domain
	logic             vload;  // Pulse indication video read request and address stable.

	// Generation read state machine, runs loops if life_go. 
	// Min 2 cycles for life_go as maybe over-ridden
	// Will complete 
	
	localparam IDLE_COUNT  = (2<<DBITS)-1;
	localparam START_COUNT = 0;
	localparam WRITE_DELAY = 6; // Cycles after read when I should sent write
	localparam DONE_COUNT  = WIDTH_B*HEIGHT_B - 1;

	// Life start, single pulse or continuous
	logic life_go;
	assign life_go = short_fire /* 1-shot generation */ || long_fire /* hold max gen speed */;
	
	
	// Loop through image
	logic [DBITS:0] read_cnt;
	logic [3:0] base;
	always_ff @( posedge clk4 ) begin
		if( reset ) begin
			read_cnt <= IDLE_COUNT; // idle state
			base     <= 1; // base ram ddr
		end else begin
			if( read_cnt == IDLE_COUNT ) begin
				read_cnt <= ( life_go ) ? START_COUNT : IDLE_COUNT; // when go starts at -1 ('h3ff)
			end else if ( read_cnt == DONE_COUNT ) begin  // counts up to 105 giving 256+1lead+6pipe
				read_cnt <= ( life_go ) ? START_COUNT : IDLE_COUNT; // restart if go unless vid pend
			end else begin
				read_cnt <= read_cnt + 1;
			end
			// Increment base when finished gen
			base <= ( read_cnt == DONE_COUNT ) ? ((base == HEIGHT_B-1) ? 0 : base+1 ) : base; 
		end
	end
	
	
	// Row address mapping pipeline. Packing 10 rows into 15 while 
	// suporting top/bot wrap and not overwriting mem.
	// Cost is 2 extra rows, one for row 0 and one always available for write.
	// Need 4 of them for row-1, row, row+1, and base+1 (for write)
	// 4 cycle pipeline
	logic [3:0][3:0] row_reg; 
	logic [3:0][3:0] base_reg;
	logic [3:0][1:0] roweq0; // pipeline
	logic [3:0][1:0] basebit0;
	logic [3:0][4:0] basesum;
	logic [3:0][4:0] basemod;
	logic [3:0][3:0] adj_row;
	always_ff @(posedge clk4) begin
		row_reg[0] <= (read_cnt[7:4]==0) ? HEIGHT_B-1 : read_cnt[7:4]-1; // row-1
		row_reg[1] <= (read_cnt == IDLE_COUNT) ? vraddr[7:4] : read_cnt[7:4]; // row
		row_reg[2] <= (read_cnt[7:4]==HEIGHT_B-1) ? 0 : read_cnt[7:4]+1; // row+1
		row_reg[3] <=  read_cnt[7:4]; // Write row
		base_reg[0] <= base;
		base_reg[1] <= base;
		base_reg[2] <= base;
		base_reg[3] <= (base==HEIGHT_B-1) ? 0 : base+1;
		for( int ii = 0; ii < 4; ii++ ) begin
			roweq0[ii][0] <= ( row_reg[ii] == 0 ) ? 1'b1 : 1'b0;
			roweq0[ii][1] <= roweq0[ii][0];
			basebit0[ii][0] <= base_reg[ii][0]; // lsb bit 0
			basebit0[ii][1] <= basebit0[ii][0];
			basesum[ii] <= { 1'b0, row_reg[ii] } - { 1'b0, base_reg[ii] };
			basemod[ii] <= ( basesum[ii][4] || basesum[ii]==0 ) ? basesum[ii] + HEIGHT_B : basesum[ii];
			adj_row[ii] <= ( roweq0[ii][1] ) ? ( basebit0[ii][1] ? 4'hf : 4'h0 ) : basemod[ii][3:0];
		end // ii
	end
	
	
	// Column addressing pipeline
	// Matching depth to row pipe
	// does col+/- for life read
	logic [3:0] col_mux;
	logic [1:0][3:0] col_del;
	logic [2:0][3:0] adj_col;
	always_ff @(posedge clk4) begin
		col_mux <= (read_cnt == IDLE_COUNT) ? vraddr[3:0] : read_cnt[3:0]; // col
		col_del[0] <= col_mux;
		col_del[1] <= col_del[0];
		adj_col[0] <= col_del[1] - 1;
		adj_col[1] <= col_del[1];
		adj_col[2] <= col_del[1] + 1;
	end
	
	// Assign the 9 read addresses
	assign raddr[0][0] = { adj_row[0], adj_col[0] };
	assign raddr[0][1] = { adj_row[0], adj_col[1] };
	assign raddr[0][2] = { adj_row[0], adj_col[2] };
	assign raddr[1][0] = { adj_row[1], adj_col[0] };
	assign raddr[1][1] = { adj_row[1], adj_col[1] };
	assign raddr[1][2] = { adj_row[1], adj_col[2] };
	assign raddr[2][0] = { adj_row[2], adj_col[0] };
	assign raddr[2][1] = { adj_row[2], adj_col[1] };
	assign raddr[2][2] = { adj_row[2], adj_col[2] };

	
	logic [21:0] init_count; // init counter, 2 million cycles
	
	
	// Pipe delay write address
	// Write should be 6 cycles after read	
	logic [WRITE_DELAY-2:0][7:0] waddr_del; // 5 cycle delay +1 for output reg itself
	always_ff @(posedge clk4) begin
		waddr_del <= { waddr_del[WRITE_DELAY-3:0], {adj_row[3], adj_col[1]} };
	   waddr     <= ( we_init ) ? init_count[19-:8] : waddr_del[WRITE_DELAY-2];
	end
	
	// Created delayed write enable (accout for row/col adj and write delay
	logic [WRITE_DELAY-2+4:0] we_del;
	always_ff @(posedge clk4) begin
		we_del <= { we_del[WRITE_DELAY-3+4:0], ((read_cnt == IDLE_COUNT) ? 1'b0 : 1'b1)};
		we     <= we_init | we_del[WRITE_DELAY-2+4];
	end
	
	// Create and delay ld signal for video read
	logic [3:0] ld_del;
	always_ff @(posedge clk4) begin
		{ ld, ld_del } <= { ld_del, vload };
	end
	
	
	////////////////////////////////////////////////////
	// Generation counters
	// count seconds, and generation ticks 
	logic        gen_tick;
	logic [47:0] gen_count;
	always_ff@( posedge clk4 ) begin
		gen_tick <=  ( read_cnt == DONE_COUNT ) ? 1'b1 : 1'b0;
		gen_count <= ( gen_tick ) ? gen_count + GENS : gen_count;
	end
	
	logic [25:0] second_count;	// clk = 48Mhz osc
	logic 	    second_tick; // 1 pulse / sec
	always_ff @(posedge clk) begin
		second_count <= ( second_count == 26'd48_000_000 - 1 ) ? 26'd0 : second_count + 1;
		second_tick <= ( second_count == 26'd0 ) ? 1'b1 : 1'b0;
	end
	
	logic [31:0] genpersec_latch;
	logic [31:0] genpersec_count;
	logic [3:0] sec_del;
	always_ff @(posedge clk4) begin
		sec_del[3:0] <= { sec_del[2:0], second_tick };
		if( sec_del[2] && !sec_del[3] ) begin // second pulse rising edge
			genpersec_latch <= genpersec_count;
			genpersec_count <= ( gen_tick ) ? 1 : 0;
		end else begin
			genpersec_latch <= genpersec_latch;
			genpersec_count <= ( gen_tick ) ? genpersec_count + GENS : genpersec_count;
		end
	end
	
	////////////////////////////////////////////////////
	// Initialization cycles. Wait for startup
	// Write 256 blocks after waiting 4096 cycles each (1Mcycles total)
	
	always @(posedge clk4) begin	
		if( reset ) begin
			init_count <= 0;
		end else begin
			init_count <= ( init_count == 22'h200000 ) ? 22'h200000 : init_count + 1;
		end
	end
		
	// wait 128K cycles after reset, then 64k cycles of 256row writes every 256 cycles, then stop and hold
	always @(posedge clk4) begin
		we_init <= ( init_count[21:20] == 2'h1 && init_count[11:0] == 12'hfff ) ? 1'b1 : 1'b0;
		init <= ( init_count == 22'h200000 ) ? 1'b0 : 1'b1;
	end
	
	/////////////////////////////////
	////
	////       VIDEO
	////
	//////////////////////////////////
	
	// HDMI reset
	logic [3:0] hdmi_reg;
	always @(posedge hdmi_clk) begin
		hdmi_reg[3:0] <= { hdmi_reg[2:0], reset };
	end
	logic hdmi_reset;
	assign hdmi_reset = hdmi_reg[3];
	
	logic video_preamble;
	logic data_preamble;
	logic video_guard;
	logic data_guard;
	logic data_island;
	
	// XVGA 800x480x60hz sych generator
	logic blank, hsync, vsync;
	vga_800x480_sync _sync
	(
		.clk(   hdmi_clk   ),	
		.reset( reset ),
		.blank( blank ),
		.hsync( hsync ),
		.vsync( vsync ),
		// HDMI encoding controls
		.video_preamble( video_preamble ),
		.data_preamble ( data_preamble  ),
		.video_guard   ( video_guard    ),
		.data_guard    ( data_guard     ),
		.data_island   ( data_island    )
	);
	
	
//////////////////////////////////////////////////////////////////////////////	
//////////////////// LIFE  VIDEO  GENERATOR /////////////////////////////////

	// Video lines displaying life cells will be shifted out of register (45 pels wide), which are loaded every WIDTH=45 cycles.
	// At the start of each block row the next address is calculated and with a toggle, ASYNC sent over to life clk domain. The address of the block
	// will be inserted into the life accesses  and the output buffer loaded from block read data row muxed and async transmission back in time for next load.
	// Life areana is 16 blocks x 45 = 720 pels By 10 blocks x 44 = 440 pels high
	// Display it at (40,20) till (760,460) and generate 2 colors
	
	
	// Video shift register
	// VIdeo clock domain


	// Video X, Y Counter
	logic [9:0] xcnt, ycnt; // Position counters
	logic blank_d1;
	always @(posedge hdmi_clk) begin
			// Video Couter
			blank_d1 <= blank;
			xcnt <= ( blank ) ? 0 : xcnt + 1;
			ycnt <= ( vsync ) ? 0 : 
					  ( blank && !blank_d1 ) ? ycnt + 1 : ycnt;
	end


	// Life Cell block row addressing
	logic active; // active life window
	logic vid_tgl; // toggle ASYNC request
	logic [5:0] vid_x;
	logic [3:0] vid_bx;
	logic [5:0] vid_y;
	logic [3:0] vid_by;
	always @(posedge hdmi_clk) begin
		// get active window
		active <= ( xcnt >=  39 && 
						xcnt <  759 &&
						ycnt >=  19 &&
						ycnt <  459 	) ? 1'b1 : 1'b0;
		// Clear counters during vsync and increment during active
		if( vsync ) begin // should always be corrent but reset anyway
			vid_x <= 0;
			vid_bx <= 1;  // we pre-fetch 
			vid_y <= 0;
			vid_by <= 0;
		end else if( active ) begin // step through block row addressing
			vid_x  <= ( vid_x == WIDTH-1  ) ? 0 : vid_x + 1; // walk row within blocks
			vid_bx <= ( vid_x == WIDTH-1  && vid_bx == WIDTH_B-1) ? 0 : // wrap at pic edge
			          ( vid_x == WIDTH-1 ) ? vid_bx + 1 : vid_bx; // step at the edge of each.
			vid_y  <= ( vid_x == WIDTH-1  && vid_bx == WIDTH_B-1) ? (( vid_y == HEIGHT-1 ) ? 0 : vid_y + 1 ) : vid_y; // step down row within a block 
			vid_by <= ( vid_x == WIDTH-1  && vid_bx == WIDTH_B-1    && vid_y == HEIGHT-1) ? (( vid_by == HEIGHT_B-1 ) ? 0 : vid_by+1 ) : vid_by; // step down through frame
			vid_tgl<= ( vid_x == WIDTH-1  ) ? !vid_tgl : vid_tgl; // Toggle as addressed update to next block
		end // active
	end
			
//////////////////////////////////////////////////////////////////////////////
///////////////////////   Clock Domain Change ////////////////////////////////			

	// toggle from hdmi_clk domain generates pulse in clk4 domain
	logic [4:0] vid_cc_tgl;
	always @(posedge clk4) vid_cc_tgl <= { vid_cc_tgl[3]^vid_cc_tgl[2], vid_cc_tgl[2:0], vid_tgl/*ASYNC*/ };
		
	// Register counters needed for address calc
	// we'll wait long enough before using, long? timing path ok
	logic [3:0] vid_cc_bx;
	logic [5:0] vid_cc_y;
	logic [3:0] vid_cc_by;
	always @(posedge clk4 ) begin 
		vid_cc_bx	<= vid_bx; 
		vid_cc_y		<= vid_y;
		vid_cc_by	<= vid_by;
	end
	
	// Video read pulse and address to RAM
	assign vraddr[7:0] = { vid_cc_by[3:0], vid_cc_bx[3:0] }; // will be re-mapped via BASE
	assign vload       = vid_cc_tgl[4]; // address stable

	// Full array of data will be latched by mem system, need to mux, do it from mem clock, but captured by video clock
	logic [WIDTH-1:0] mem_rd; // loaded data block row
	assign mem_rd = read_word[vid_cc_y[5:0]];	//ASYNC MUX	-- allows flexible place & route for this big mux
			
			
///////////////////////   Clock Domain Revert ////////////////////////////////			
//////////////////////////////////////////////////////////////////////////////	
			
	logic [WIDTH-1:0] life_row; // loaded async
	logic life_fg, life_bg;
			
	always_ff @(posedge hdmi_clk) begin
			if( active ) begin
				if( vid_x == WIDTH-1 ) begin
					life_row <= mem_rd; // ASYNC (on purpose)
				end else begin
					life_row <= { 1'b1, life_row[WIDTH-1:1] };
				end
			end
			// Overlay
			life_fg <= ( active &&  life_row[0] ) ? 1'b1 : 1'b0;
			life_bg <= ( active && !life_row[0] ) ? 1'b1 : 1'b0;
	end

///////////////////////// LIFE VIDEO GENERATION done /////////////////////////
//////////////////////////////////////////////////////////////////////////////
	

	// Font Generator
	logic [7:0] char_x, char_y;
	logic [255:0] ascii_char;
	logic [15:0] hex_char;
	logic [1:0] bin_char;
	ascii_font57 _font
	(
		.clk( hdmi_clk ),
		.reset( reset ),
		.blank( blank ),
		.hsync( hsync ),
		.vsync( vsync ),
		.char_x( char_x ), // 0 to 105 chars horizontally
		.char_y( char_y ), // o to 59 rows vertically
		.hex_char   ( hex_char ),
		.binary_char( bin_char ),
		.ascii_char ( ascii_char )	
	);

	// test pattern gen
	logic [7:0] test_red, test_green, test_blue;
	test_pattern _testgen 
	(
		.clk( hdmi_clk  ),
		.reset( reset ),
		.blank( blank ),
		.hsync( hsync ),
		.vsync( vsync ),
		.red	( test_red   ),
		.green( test_green ),
		.blue	( test_blue  )
	);	
	
	// Flash Memory interface (init font and text overlay)
	// the serial interface runs at 6 Mhz (max 7 Mhz!)
	// we assigned c0 the output diff pair clock to this interface.
	
	logic [11:0] 	flash_addr; // 32 bit word address, 16Kbytes total flash for M04
	logic 			flash_read;
	logic				flash_data;
	logic 			flash_wait;
	logic 			flash_valid;
	ufm_flash _flash (
		.clock						( clk_out 			 ), // 6 Mhz
		.avmm_data_addr			( flash_addr[11:0] ), // word address 
		.avmm_data_read			( flash_read 		 ),
		.avmm_data_readdata		( flash_data 		 ),
		.avmm_data_waitrequest	( flash_wait 		 ),
		.avmm_data_readdatavalid( flash_valid 		 ),
		.avmm_data_burstcount	( 128 * 32 			 ), // 4K bit burst
		.reset_n						( !reset 			 )
	);	
	
	// Text Overlay (from flash rom)
	logic text_ovl;
	logic [3:0] text_color;
	text_overlay _text
	(
		.clk( hdmi_clk  ),
		.reset( reset ),
		.blank( blank ),
		.hsync( hsync ),
		.vsync( vsync ),
		// Overlay output bit for ORing
		.overlay( text_ovl ),
		.color( text_color ),
		// Avalon bus to init font and text rams
		.flash_clock( clk_out 			 ), // 6 Mhz
		.flash_addr ( flash_addr[11:0] ), // word address 
		.flash_read ( flash_read 		 ),
		.flash_data ( flash_data 		 ),
		.flash_wait ( flash_wait 		 ),
		.flash_valid( flash_valid 		 )
	);

	
	// Overlay Text - Dynamic
	logic [6:0] id_str;
	string_overlay #(.LEN(21)) _id0(.clk(hdmi_clk), .reset(reset), .char_x(char_x), .char_y(char_y),.ascii_char(ascii_char), .x('h48), .y('h01), .out( id_str[0]), .str( "Conway's Game of LIFE" ) );
	hex_overlay    #(.LEN(12 )) _id1(.clk(hdmi_clk), .reset(reset), .char_x(char_x), .char_y(char_y),.hex_char(hex_char), .x('h50),.y('d59), .out( id_str[1]), .in( gen_count[47:0] ) );
   //bin_overlay    #(.LEN(1 )) _id2(.clk(hdmi_clk), .reset(reset), .char_x(char_x), .char_y(char_y),.bin_char(bin_char), .x('h46),.y('h09), .out( id_str[2]), .in( disp_id == 32'h0E96_0001 ) );
	//string_overlay #(.LEN(14)) _id3(.clk(hdmi_clk), .reset(reset), .char_x(char_x), .char_y(char_y),.ascii_char(ascii_char), .x('d119),.y('d58), .out( id_str[3]), .str( "commit 0123abc" ) );
	hex_overlay    #(.LEN(8 )) _id4(.clk(hdmi_clk), .reset(reset), .char_x(char_x), .char_y(char_y),.hex_char(hex_char), .x('h30),.y('d59), .out( id_str[4]), .in( genpersec_latch[31:0] ) );
	string_overlay #(.LEN(17)) _id5(.clk(hdmi_clk), .reset(reset), .char_x(char_x), .char_y(char_y),.ascii_char(ascii_char), .x('h48), .y('d58), .out( id_str[5]), .str( "Total Generations" ) );
	string_overlay #(.LEN(15)) _id6(.clk(hdmi_clk), .reset(reset), .char_x(char_x), .char_y(char_y),.ascii_char(ascii_char), .x('h28), .y('d58), .out( id_str[6]), .str( "Generations/sec" ) );

	logic overlay; // default overlay layer bit
	assign overlay = ( text_ovl && text_color == 0 ) | // normal text
						  (|id_str  ) ; // reduction OR of the id string bits.
	
	// Overlay Color
	logic [7:0] overlay_red, overlay_green, overlay_blue;
	assign { overlay_red, overlay_green, overlay_blue } =
			( overlay ) ? 24'hFFFFFF :
			( life_fg ) ? 24'h00c0c0 /* smpte_turquise_surf */ :
			( life_bg ) ? 24'h1d1d1d /* smpte_eerie_black   */ :
			( text_ovl && text_color == 4'h1 ) ? 24'hf00000 :
			( text_ovl && text_color == 4'h2 ) ? 24'hFFFFFF :
			( text_ovl && text_color == 4'h3 ) ? 24'hff0000 :			
			( text_ovl && text_color == 4'h4 ) ? 24'h00ff00 :
			( text_ovl && text_color == 4'h5 ) ? 24'h0000ff :
			( text_ovl && text_color == 4'h6 ) ? 24'hc0c0c0 :
			( text_ovl && text_color == 4'h7 ) ? 24'h0000c0 :
			( text_ovl && text_color == 4'h8 ) ? 24'h00c0c0 :
			( text_ovl && text_color == 4'h9 ) ? 24'h00c000 : 
			( text_ovl && text_color == 4'hA ) ? 24'hc0c000 : 
			( text_ovl                       ) ? 24'hf0f000 : 
															 24'h000000 ;

	// video encoder
	// Simultaneous HDMI and DVI

	logic [7:0] hdmi2_data;
	logic [7:0] dvi_data;
	video_encoder _encode2
	(
		.clk  ( hdmi_clk  ),
		.clk5 ( hdmi_clk5 ),
		.reset( reset ),  // battery limit during charging
		.blank( blank ),
		.hsync( hsync ),
		.vsync( vsync ),
		// HDMI encoding control
		.video_preamble( video_preamble ),
		.data_preamble ( data_preamble  ),
		.video_guard   ( video_guard    ),
		.data_guard    ( data_guard     ),
		.data_island   ( data_island    ),	
		// YUV mode input
		.yuv_mode		( 0 ), // use YUV2 mode, cheap USb capture devices provice lossless YUV2 capture mode 
		// RBG Data
		.red   ( ( !life_fg & !life_bg ) ? ( test_red   | overlay_red   ) : overlay_red   ),
		.green ( ( !life_fg & !life_bg ) ? ( test_green | overlay_green ) : overlay_green ),
		.blue  ( ( !life_fg & !life_bg ) ? ( test_blue  | overlay_blue  ) : overlay_blue  ),
		// HDMI and DVI encoded video
		.hdmi_data( hdmi2_data ),
		.dvi_data( dvi_data )
	);
		
	// HDMI 2 Output, DVI outputs
	hdmi_out _hdmi2_out ( // LDVS DDR outputs
		.outclock( hdmi_clk5 ),
		.din( dvi_data ),
		.pad_out( {hdmi2_d2, hdmi2_d1, hdmi2_d0, hdmi2_ck} ), 
		.pad_out_b( )  // true differential, _b not req
	);
	
	// HDMI 1 output, HDMI outputs, with YUV2 support
	hdmi_out _hdmi_out ( // LDVS DDR outputs
		.outclock( hdmi_clk5 ),
		.din( hdmi2_data ),
		.pad_out( {hdmi_d2, hdmi_d1, hdmi_d0, hdmi_ck} ), 
		.pad_out_b( )  // true differential, _b not req
	);
endmodule
	






// Debounce of pushbutton
module debounce(
	input clk,
	input reset,
	input in,
	output out,	// fixed pulse 15ms after 5ms pressure
	output long // after fire held for > 2/3 sec, until release
	);
	
	logic [25:0] count1; // total 1.3 sec
	logic [22:0] count0;
	logic [2:0] state;
	logic [2:0] meta;
	logic       inm;

	
	always @(posedge clk) { inm, meta } <= { meta, in };
	
	// State Machine	
	localparam S_IDLE 		= 0;
	localparam S_WAIT_PRESS	= 1;
	localparam S_WAIT_PULSE	= 2;
	localparam S_WAIT_LONG	= 3;
	localparam S_LONG			= 4;
	localparam S_WAIT_OFF	= 5;
	localparam S_WAIT_LOFF	= 6;
	
	always @(posedge clk) begin
		if( reset ) begin
			state <= S_IDLE;
		end else begin
			case( state )
				S_IDLE 		 :	state <= ( inm ) ? S_WAIT_PRESS : S_IDLE;
				S_WAIT_PRESS :	state <= (!inm ) ? S_IDLE       : (count1 == ( 5  * 48000 )) ? S_WAIT_PULSE : S_WAIT_PRESS;
				S_WAIT_PULSE :	state <=                          (count1 == ( 25 * 48000 )) ? S_WAIT_LONG  : S_WAIT_PULSE; 
				S_WAIT_LONG	 :	state <= (!inm ) ? S_WAIT_OFF   : (count1 >= 26'h20_00000  ) ? S_LONG       : S_WAIT_LONG;
				S_LONG		 :	state <= (!inm ) ? S_WAIT_LOFF  :  S_LONG;
				S_WAIT_OFF	 :	state <= ( inm ) ? S_WAIT_LONG  : (count0 == ( 100 * 48000)) ? S_IDLE       : S_WAIT_OFF;
				S_WAIT_LOFF	 :	state <= ( inm ) ? S_LONG       : (count0 == ( 100 * 48000)) ? S_IDLE       : S_WAIT_LOFF;
				default: state <= S_IDLE;
			endcase
		end
	end
	
	assign out = (state == S_WAIT_PULSE) ? 1'b1 : 1'b0;
	assign long = (state == S_LONG || state == S_WAIT_LOFF) ? 1'b1 : 1'b0;
	
	// Counters
	always @(posedge clk) begin
		if( reset ) begin
			count0 <= 0;
			count1 <= 0;
		end else begin
			count0 <= ( state == S_WAIT_OFF  || 
			            state == S_WAIT_LOFF ) ? (count0 + 1) : 0; // count when low waiting
			count1 <= ( state == S_IDLE      ) ? 0            : (count1 + 1); 
		end
	end

endmodule