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

	
	//////////////////////////////////////////////
	// Monitor flash reads and write ram copy   //

	logic [11:0] burst_count; // count of 4Kbit bursts
	logic [11:0] burst_addr;  // latched of flash addr
	logic [63:0] whold;
	logic dummy;
	always_ff @(posedge clk_out ) begin
		burst_addr  <= ( flash_read && !flash_wait ) ? flash_addr : burst_addr;
		burst_count <= ( flash_read && !flash_wait ) ? 0 : // addr phase
						   ( flash_valid               ) ? burst_count + 1 : // data (bit) transfer
																	  burst_count;
		whold[63:0] <= ( flash_valid && burst_addr >= 'h800 ) ? { whold[62:0], flash_data } : whold[63:0] ;
	end

	// Flash data ram organized as r1w1 1K words x 64-bit, dual read
	// it will take 
	// flash ram written on slow flash clock. 
	// flash ram read below on an application clock
	logic [63:0] box_ram1[0:1023];
	logic [63:0] box_ram2[0:1023];
	always_ff @(posedge clk_out ) begin
			if(  flash_valid && burst_addr >= 'h800 && burst_count[5:0] == 63 ) begin
					box_ram1[{burst_addr[10-:4],burst_count[11-:6]}] <= { whold[62:0], flash_data };
					box_ram2[{burst_addr[10-:4],burst_count[11-:6]}] <= { whold[62:0], flash_data };
			end
	end
	
	// end of init from flash   //
	//////////////////////////////
	

	
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
	
	
	////////////////////////// Video display of puzzle data ////////////////////
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

	// Read the ram replicating each bit into 8x8 block from during two 256x256 windows (128,128) and (384,128)
	// and output RGB and asssert a window flag
	
	logic active_row, active_row_d;
	logic active_left; // active life window
	logic active_right; // active life window
	logic [14:0] row_addr;
	logic [14:0] pel_addr;
	logic [1:0] ram_data;
	always @(posedge hdmi_clk) begin
		// get active window
		active_row  <= ( !blank && ycnt >= 128 && ycnt < 128+256 ) ? 1'b1 : 1'b0;
		active_row_d<= active_row;
		active_left <= ( active_row && !blank && xcnt >= 64 && xcnt < 64+256) ? 1'b1 : 1'b0; 
		active_right<= ( active_row && !blank && xcnt >= 384+1 && xcnt < 384+256+1) ? 1'b1 : 1'b0; // delay 1 cycle due to color table ram
	end
	
	// Instantiate day 8 logic
	// TBD
	
	// Day 8 part 2 hardware
	// Process
	// init color table 2R1W mem 
	// (C) Dedicate one color table to raster access during right window window
	// (S) wait button press
	// (C) find next shortest path (full search boxs pairs)
	// Take a r/w pass thru the color table
	// if box pair sits on the two different colors (2 color table reads) map all higher color to the lower color
	// and after mapping check if all colors are now == 0 and set done
	// (S) if not done and long_press loop back for next shorted path pass.
	// (S) else if not done wait button press and loop back for next shortest pass
	// (S) if button step back to init color table
	
	// Connect to fire button
	logic vid_short, vid_long, vid_press, vid_but;
	debounce _vid_but ( .clk( hdmi_clk ), .reset( hdmi_reset ), .in( fire_button ), .out( vid_short ), .long( vid_long ));
	always @(posedge hdmi_clk)
		vid_but <= vid_short;
	assign vid_press = vid_short & ~vid_but;

	// Sequencer 
	localparam S_IDLE 	= 0; // goto init
	localparam S_INIT 	= 1; // Write a ramp 0 to 1023 into color table
	localparam S_BUTTON 	= 2; // wait for a button press
	localparam S_SEARCH 	= 3; // do the n*n/2 full search for next shortest pair
	localparam S_LOOKUP1	= 4; // lookup 2colors of the pair
	localparam S_LOOKUP2	= 5; // lookup 2colors of the pair
	localparam S_VECMAP 	= 6; // walk thru color table and map the pair and test is its all color==0
	localparam S_DONE 	= 7; // if not done a long or short button press got0 next full search, else done and button goto idle
	logic [3:0] state;
	
	logic init_done;	// 1024 cyels to write a ramp into color table
	logic search_done; // search next, 100K cycles
	logic map_done; // remap color tables and check if alldone 1024 cycles
	logic done; // completed part 2
	always_ff @(posedge hdmi_clk) begin
		if( hdmi_reset ) begin
			state <= S_IDLE;
		end else begin
			case( state ) 
			S_IDLE 	: begin state <=                                          S_INIT           	  ; end
			S_INIT 	: begin state <= (  init_done  								) ? S_BUTTON  : S_INIT 	  ; end
			S_BUTTON : begin state <= (  vid_long || vid_press  				) ? S_SEARCH  : S_BUTTON  ; end
			S_SEARCH : begin state <= (  search_done                       ) ? S_LOOKUP1 : S_SEARCH  ; end
			S_LOOKUP1: begin state <=                                          S_LOOKUP2             ; end
			S_LOOKUP2: begin state <=                                          S_VECMAP              ; end
			S_VECMAP : begin state <= (  map_done                          ) ? S_DONE    : S_VECMAP  ; end
			S_DONE 	: begin state <= ( !done && ( vid_long || vid_press ) ) ? S_SEARCH  : 
			                          (  done               && vid_press   ) ? S_INIT    : S_DONE    ; end
			default  : begin state <= 4'bxxxx; end
			endcase
		end
	end
	
	// Count number of strings of lights
	logic [15:0] scount;
	always_ff @(posedge hdmi_clk)
		scount <= ( state == S_INIT ) ? 0 : ( state == S_BUTTON && ( vid_long || vid_press ) ) ? scount + 1 : scount;
	

	// Video copy of Color table (always read to screen at raster rate) displayed live (during 40? sec solve) on right window
	// Index by raster position (an 8x8 cell location per box) and then generate the box RGB based on the indexed color.
	logic [9:0]  ctable [0:1023];
	logic [9:0] vctable [0:1023];
	logic [9:0] vcolor;
	logic [9:0] vidx;
	logic [9:0] vxcnt, vycnt;
	assign vxcnt = xcnt-384;
	assign vycnt = ycnt-128;
	assign vidx[9:0] = { vycnt[7-:5],vxcnt[7-:5] }; // index color tabel by screen location
	always_ff @(posedge hdmi_clk)
		vcolor <= vctable[ vidx ];
	logic [7:3] xcolor, ycolor;
	assign { ycolor, xcolor } = vcolor;
		
	logic [7:0] colr, colg, colb; // rgb
	assign { colr, colg, colb } = { { xcolor[3], ycolor[4], xcolor[6], ycolor[7], xcolor[4], ycolor[5], xcolor[7], ycolor[3] },
	                               ~{ ycolor[3], xcolor[5], ycolor[6], xcolor[3], ycolor[4], xcolor[6], ycolor[7], xcolor[4] },
										     { xcolor[4], ycolor[5], xcolor[7], ycolor[3], xcolor[5], ycolor[6], xcolor[3], ycolor[4] } };
	
	// Create left reference display window and RGB
	logic window;
	logic [9:0] wxcnt, wycnt;
	assign wxcnt = xcnt-384;
	assign wycnt = ycnt-128;
	logic [7:0] winr, wing, winb;
	assign { winr, wing, winb } = { { wxcnt[3], wycnt[4], wxcnt[6], wycnt[7], wxcnt[4], wycnt[5], wxcnt[7], wycnt[3] },
	                               ~{ wycnt[3], wxcnt[5], wycnt[6], wxcnt[3], wycnt[4], wxcnt[6], wycnt[7], wxcnt[4] }, 
											  { wxcnt[4], wycnt[5], wxcnt[7], wycnt[3], wxcnt[5], wycnt[6], wxcnt[3], wycnt[4] } };						
											
	// full pair search
		logic [63:0] thresh; // min cost threshold
		logic [63:0] distance; // pair cost^2
		logic [63:0] cost; // best cost so far
		logic [63:0] last_candidate; // reported puzzle sum, when we finish!
		
			logic [9:0] best_a, best_b;
			logic [9:0] a_count, b_count; 
			logic [4:0][9:0] a_count_del, b_count_del; 
			logic [17:0] dx, dy, dz;
			logic [35:0] dx2, dy2, dz2;
		   logic [63:0] box1, box2;
			logic search_run;
			logic [5:0] search_run_d;
			assign search_run = ( state == S_SEARCH ) ? 1'b1 : 1'b0;
			assign search_done = ( a_count == 998 && b_count == 999 ) ? 1'b1 : 1'b0;
			always_ff @(posedge hdmi_clk) begin
			if( hdmi_reset ) begin
				a_count <= 0; // lead couner
				b_count <= 1; // upper counter
			end else begin
				search_run_d[5:0] <= { search_run_d[4:0], search_run };
				a_count <= ( search_run && search_done    ) ? 0 : 
				           ( search_run && b_count == 999 ) ? a_count + 1 :
							                                     a_count;
				b_count <= ( search_run && search_done    ) ? 1 :
				           ( search_run && b_count == 999 ) ? a_count + 2 :
							  ( search_run                   ) ? b_count + 1 :
							                                     b_count;
				a_count_del[4:0] <= { a_count_del[3:0], a_count };
				b_count_del[4:0] <= { b_count_del[3:0], b_count };
				// Coord memory reads
				box1 <= box_ram1[a_count];
				box2 <= box_ram2[b_count];
				
				// Calc x,y,z differenced
				dx <= ( box1[53-:18] > box2[53-:18] ) ? ( box1[53-:18] - box2[53-:18] ) : ( box2[53-:18] - box1[53-:18] );
				dy <= ( box1[35-:18] > box2[35-:18] ) ? ( box1[35-:18] - box2[35-:18] ) : ( box2[35-:18] - box1[35-:18] );
				dz <= ( box1[17-:18] > box2[17-:18] ) ? ( box1[17-:18] - box2[17-:18] ) : ( box2[17-:18] - box1[17-:18] );
				
				// Calculate squared valued
				dx2 <= dx * dx;
				dy2 <= dy * dy;
				dz2 <= dz * dz;
				
				// Calculate pair distance
				distance <= dx2 + dy2 + dz2;
				
				// Update best
				cost <= ( !search_run ) ? (10000*10000)*3 : 
				        ( search_run && distance > thresh && distance < cost ) ? distance : cost;
				best_a <= ( search_run && distance > thresh && distance < cost ) ? a_count_del[4] : best_a;
				best_b <= ( search_run && distance > thresh && distance < cost ) ? b_count_del[4] : best_b;
				
				// update thresh when done
				thresh <= ( state == S_INIT ) ? 0 : ( search_run_d[5] && !search_run_d[4] ) ? cost : thresh;  
			end
		end
	
	// Color Mapping functdion
	// need to latch colors for best_a, best_b from next search
	// determine min_color, max_color
	// Determine mapped = ( read_color == MAX_COLOR ) ? min_color : read_color
	logic [9:0] a_color, b_color;
	logic [9:0] min_color, max_color; 
	logic [9:0] mapped;
	always_ff @(posedge hdmi_clk) begin
		a_color <= ( state == S_LOOKUP1 ) ? read_color : a_color;
		b_color <= ( state == S_LOOKUP2 ) ? read_color : b_color;
	end
	assign min_color = ( a_color < b_color ) ? a_color : b_color;
	assign max_color = ( a_color < b_color ) ? b_color : a_color;
	assign mapped = ( read_color == max_color ) ? min_color : read_color;
	
	
				
		// Color table operations, write to both banks, but only read 1
		// lookup 2 (two) colors for best_a and best_b and get min/max during S_LOOKUP1/2
		// walk and init color table during S_INIT
		// walk, map, test color table during S_VECMAP
	// Color table burst writes (init, map&test) A
	logic [9:0] ctable_addr;
	logic [9:0] ctable_waddr;
	logic [9:0] c_count;
	logic [9:0] read_color;
	
	

	always_ff @(posedge hdmi_clk) begin
		c_count <= ( state == S_IDLE  || state == S_LOOKUP2 ) ? 0 :
					  ( state == S_INIT  || state == S_VECMAP  ) ? c_count + 1 : c_count ;
		ctable_addr <= ( state == S_LOOKUP1 ) ? best_a :
		               ( state == S_LOOKUP2 ) ? best_b : c_count ;
		ctable_waddr <= ctable_addr;
		read_color <= ctable[ ctable_addr ];
		if( state == S_INIT || state == S_VECMAP ) begin
			ctable[ctable_waddr] <= ( S_INIT ) ? c_count : mapped;
		  vctable[ctable_waddr] <= ( S_INIT ) ? c_count : mapped;
		end	
	end
	assign init_done = ( state == S_INIT   && c_count == 10'h3ff ) ? 1'b1 : 1'b0;
	assign map_done  = ( state == S_VECMAP && c_count == 10'h3ff ) ? 1'b1 : 1'b0;
			                                                                        //
	//                                                                            //
	////////////////////////////////////////////////////////////////////////////////
	//////////////////////////////// AoC Day 8 done ////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////

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
	logic [35:0] candidate = 36'h012345678;
	logic [10:0] id_str; 
	string_overlay #(.LEN(25)) _id0(.clk(hdmi_clk), .reset(reset), .char_x(char_x), .char_y(char_y),.ascii_char(ascii_char), .x('d40), .y('d8 ), .out( id_str[0]), .str( "Advent of Code 2025 Day 8" ) );
	string_overlay #(.LEN(10)) _id1(.clk(hdmi_clk), .reset(reset), .char_x(char_x), .char_y(char_y),.ascii_char(ascii_char), .x('d40), .y('d48), .out( id_str[1]), .str( "Strings:0x" ) );
	string_overlay #(.LEN(10)) _id2(.clk(hdmi_clk), .reset(reset), .char_x(char_x), .char_y(char_y),.ascii_char(ascii_char), .x('d40), .y('d50), .out( id_str[2]), .str( " Part 1:  " ) );
	string_overlay #(.LEN(10)) _id3(.clk(hdmi_clk), .reset(reset), .char_x(char_x), .char_y(char_y),.ascii_char(ascii_char), .x('d40), .y('d52), .out( id_str[3]), .str( " Part 2:0x" ) );
	string_overlay #(.LEN(7 )) _id4(.clk(hdmi_clk), .reset(reset), .char_x(char_x), .char_y(char_y),.ascii_char(ascii_char), .x('d50), .y('d50), .out( id_str[4]), .str( "Yikes!!" ) );
	hex_overlay    #(.LEN(9 )) _id5(.clk(hdmi_clk), .reset(reset), .char_x(char_x), .char_y(char_y),.hex_char(hex_char),     .x('d50), .y('d52), .out( id_str[5]), .in( candidate[35:0] ) );
	hex_overlay    #(.LEN(4 )) _id6(.clk(hdmi_clk), .reset(reset), .char_x(char_x), .char_y(char_y),.hex_char(hex_char),     .x('d50), .y('d48), .out( id_str[6]), .in( scount ) );
	
	logic overlay; // default overlay layer bit
	assign overlay = ( text_ovl && text_color == 0 ) | // normal text
						  (|id_str  ) ; // reduction OR of the id string bits.
	
	// Overlay Color
	logic [7:0] overlay_red, overlay_green, overlay_blue;
	assign { overlay_red, overlay_green, overlay_blue } =
			( overlay ) ? 24'hFFFFFF :
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
		.red   ( ( active_left ) ? winr : ( active_right ) ? colr : ( test_red   | overlay_red   )  ),
		.green ( ( active_left ) ? wing : ( active_right ) ? colg : ( test_green | overlay_green )  ),
		.blue  ( ( active_left ) ? winb : ( active_right ) ? colb : ( test_blue  | overlay_blue  )  ),
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

module aoc_day7( 
	input clk,
	input vsync,				 // tie to vsync restart each frame
	input logic       valid, // puzzle data valid
	input logic 		first, // indiates first row, all above row is considered "."
	output logic      ovalid, // valid aligned with output
	input logic [1:0] pin,     // puzzle row data 
	output logic [1:0] pout,
	output logic [15:0] splits, // Count of splits for total frame
	output logic [63:0] dimensions
	);
	//assign ovalid = valid;
	//assign pout = ~pin;
	//always_ff @(posedge clk) splits <= ( vsync ) ? 0 : ( valid ) ? splits + 1 : splits;
	//assign dimensions = 64'h0123456789abcdef;
	
	// Delayed version of valid to drive everything
	
	logic [20:0] valid_del;
	always_ff @(posedge clk)
		valid_del[20:0] <= { valid_del[19:0], valid };

	
	
	// Memory buffers for prev scanlines of timeline cell counts (64) and prev coded line (2)
	// read address to mem read to aligned output
	
	logic [7:0] read_addr;
	logic [1:0] cread, cpreread;
	logic [63:0] tread, tpreread;
	logic [63:0] tmem [0:255];
	logic [1:0]  cmem [0:255];
	
	always_ff @(posedge clk) begin
		read_addr <= ( !valid ) ? 0 : read_addr + 1;
		tpreread     <= tmem[read_addr];
		cpreread     <= cmem[read_addr];
	end
	assign tread = ( first ) ? 64'h0 : tpreread;
	assign cread = ( first ) ? 2'h0  : cpreread;
	
	// input p-code delay buffers
	// 3 wide window for prev timeline and prev and curent flash codes
	
	logic [1:0] pcode;
	logic [2:0][1:0] pdel;
	logic [2:0][1:0] cdel;
	logic [2:0][63:0] tdel;
	always_ff @(posedge clk) begin
		pcode <= pin;
		pdel[2:0] <= { pdel[1:0], pcode };
		cdel[2:0] <= { cdel[1:0], cread };
		tdel[2:0] <= { tdel[1:0], tread };
	end

	
	// Calculation if this is a part 1 split
	// code: "|" - 1, "^" - 2, "S" - 3, else nothing
	logic split_flag;
	assign split_flag = ( pdel[1] == 2 && ( cdel[1] == 1 || cdel[1] == 3 )) ? 1'b1 : 1'b0;

	// Split accumulator cleared at vsync
	always_ff @(posedge clk) begin
		if( vsync ) begin
			splits <= 0;
		end else if ( valid_del[2] && split_flag ) begin
			splits <= splits + 1;
		end
	end
	
	// Calculations for updated current cell coding (to written to mem)
	// Rules: copy ^, copy S, else "|" if left_split, above, rigth_split
	logic [1:0] cnext;
	always_ff @(posedge clk) begin
		cnext <= ( pdel[1] == 2                 ) ? 2 :  // copy ^
				   ( pdel[1] == 3                 ) ? 3 :  // copy S
				   ( pdel[1] == 1                 ) ? 0 :  // no "|"'s present in puzzle text
					(                 cdel[1] == 3 ) ? 1 : // above "S"
					(                 cdel[1] == 1 ) ? 1 : // above energy
					( pdel[2] == 2 && cdel[2] == 1 ) ? 1 : // spit from left
					( pdel[0] == 2 && cdel[0] == 1 ) ? 1 : 0; // spit from right
																							
	end
	assign ovalid = valid_del[3];
	assign pout = cnext;
	// Calcuations for updateing the timeline count per part2 (to be written to mem)
	// we see which neighbours we will add to the timeline sum
	// we also have the special case of S which gets the inital timeline of 1.
	// timeline accumulator cleared before each row, double buffer to hold the output
	logic [63:0] tnext;
	logic [63:0] tacc, thold;
	always_ff @(posedge clk) begin
		tnext <=   ( pdel[1] == 3                 ) ? 64'd1   : // Initial "S" seed for timeline
		           ( pdel[1] == 2                 ) ? 64'd0   : // splitter "^" has zero timelines
					  ( pdel[1] == 1                 ) ? 64'h0   : // cannot happen, '|" not present in puzzlle input, only our output
				   ((( cdel[1] == 3 || cdel[1] == 1 ) ? tdel[1] : 64'd0 ) +
				    (( pdel[2] == 2 && cdel[2] == 1 ) ? tdel[2] : 64'd0 ) +
				    (( pdel[0] == 2 && cdel[0] == 1 ) ? tdel[0] : 64'd0 ) );
		tacc <=  ( valid_del[3] ) ? tacc + tnext : 0 ;	// accumulate over the row
		thold <= ( !valid_del[3] && valid_del[4] ) ? tacc : thold;  
	end
	assign dimensions = thold;
	
	// Memory write address and we for cur timeline and codes
	logic [7:0] write_addr;
	always_ff @(posedge clk) begin
		write_addr <= ( valid_del[3] ) ? write_addr+1 : 0;
		if( valid_del[3] ) begin
			tmem[write_addr] <= tnext;
			cmem[write_addr] <= cnext;
		end
	end
	
endmodule