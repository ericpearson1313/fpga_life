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
	assign speaker		= 1'b0;
	assign speaker_n	= 1'b0;
	
	// Float future comm port
	assign digio = 7'bzzz_zzzz;
	
	// Rs232
	assign tx2323 = rx232; // wire through
	
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



	// Integrate the life engine
	logic [255:0] init_word;
	logic [255:0] life_word; // latched read workd
	life_engine _life_engine (
		.clk  ( clk4 ),
		.reset( reset ),
		.raddr( count[7:0] ),
		.waddr( count[7:0] ),
		.we( count[2] ),
		.re( count[3] ),
		.ld( count[17] ),
		.dout( life_word ), // 256bit wordlatched by ld flag, for video shift reg
		.init( count[21] ),
		.init_data( init_word ) // 256 bit
	);
	
	// Generate Init word (lfsr for now)
	
	always_ff @(posedge clk4 ) begin
		if( reset ) begin
			init_word <= 256'b1;
		end else begin
			init_word <= { init_word[254:0], init_word[255] ^ init_word[1] };
		end
	end

	// Generation counter
	
	logic [47:0] gen_count;
	always_ff@( posedge clk4 ) begin
		gen_count <= gen_count + 1;
	end

	// Life Control state machine.
	// Generates cell read and write addresses 
	// and we and rd signals.
	// During Hblank of active lines the a single cycle will be used to load a word 
	// the async load will take place later when in the display window
	// will also count seconds, and frames to get the generation rate
	// will also increment eon counter, 
	// need an init memory method.
	// suggest maybe true dual port and use the 2nd write port from a 256bit write reg.
	
		
	
	
	
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
	
	// Life_row shift register
	// Loaded from stolen cycle during hblank (by state machine)
	// WIthin window (256,128) to (511,383) will be in the window
	// will generate 2 colors.
	
		// Video shift register
	
	logic [255:0] life_row; // loaded async
	logic vid_shift;
	logic [9:0] xcnt, ycnt; // Position counters
	logic blank_d1;
	logic life_fg, life_bg;

	always @(posedge hdmi_clk) begin
			// Video Couter
			blank_d1 <= blank;
			xcnt <= ( blank ) ? 0 : xcnt + 1;
			ycnt <= ( vsync ) ? 0 : 
					  ( blank && !blank_d1 ) ? ycnt + 1 : ycnt;
			// Life cell row shift register, *NOTE* Async load
			life_row <= ( vid_shift ) ? { 1'b0, life_row[255:1] } : life_word;
			// Overlay
			life_fg <= ( xcnt >= 256 && xcnt < 512 && ycnt >= 128 && ycnt < 384 &&  life_row[0] ) ? 1'b1 : 1'b0;
			life_bg <= ( xcnt >= 256 && xcnt < 512 && ycnt >= 128 && ycnt < 384 && !life_row[0] ) ? 1'b1 : 1'b0;
	end
	

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
	logic [4:0] id_str;
	string_overlay #(.LEN(21)) _id0(.clk(hdmi_clk), .reset(reset), .char_x(char_x), .char_y(char_y),.ascii_char(ascii_char), .x('h48), .y('h09), .out( id_str[0]), .str( "Conway's Game of LIFE" ) );
	hex_overlay    #(.LEN(12 )) _id1(.clk(hdmi_clk), .reset(reset), .char_x(char_x), .char_y(char_y),.hex_char(hex_char), .x('h50),.y('d58), .out( id_str[1]), .in( gen_count[47:0] ) );
   //bin_overlay    #(.LEN(1 )) _id2(.clk(hdmi_clk), .reset(reset), .char_x(char_x), .char_y(char_y),.bin_char(bin_char), .x('h46),.y('h09), .out( id_str[2]), .in( disp_id == 32'h0E96_0001 ) );
	string_overlay #(.LEN(12)) _id3(.clk(hdmi_clk), .reset(reset), .char_x(char_x), .char_y(char_y),.ascii_char(ascii_char), .x('d120),.y('d59), .out( id_str[3]), .str( "ERIC PEARSON" ) );

	
	// Merge overlays
	logic overlay;
	assign overlay = ( text_ovl && text_color == 0 ) | // normal text
						  (|id_str  ) ;
	
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
		.reset( reset | charge ),  // battery limit during charging
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
		.red   ( test_red   | overlay_red   ),
		.green ( test_green | overlay_green ),
		.blue  ( test_blue  | overlay_blue  ),
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
	




module life_engine #(
	WIDTH = 256,
	DEPTH = 256,
	DBITS = 8
) (
	input clk,
	input reset,
	// Memory Control
	input logic [DBITS-1:0] raddr, // also used for init writes
	input logic [DBITS-1:0] waddr,
	input	logic we,
	input logic re,
	// External Data Control
	input logic ld,
	output logic [WIDTH-1:0] dout, // data out
	// Init port
	input logic init,
	input logic [WIDTH-1:0] init_data
	
);

////////////////

////////////////

	
	// Memory
	
	logic [WIDTH-1:0] ram [0:DEPTH-1];
	logic [WIDTH-1:0] mem_wdata;
	logic [WIDTH-1:0] mem_rdata;
	logic [WIDTH-1:0] cell_next;
	logic re_del;


	
	always_ff@(posedge clk)
	begin
		// Write
		if(we) ram[waddr] <= ( init ) ? init_data : mem_wdata;
		// Read
		re_del <= re;	// delay to match read data
		mem_rdata <= ram[raddr];
	end	
	

	always_ff@(posedge clk)
		if( ld ) dout <= mem_rdata;
				
	// Shift register
	logic [2:0][WIDTH-1:0] cell_array;
	
	// Shift register input
	always_ff@(posedge clk)
	begin
		cell_array[2:0] <= (re_del) ? { cell_array[1:0], mem_rdata } : cell_array[2:0];
	end

	logic [255:0][1:0] add3;
	logic [255:0][1:0] add3_q;
	logic [255:0][3:0] add9;
	always_comb begin : _life_cells
		// Form add3 array
		for( int ii = 0; ii < 256; ii++ ) begin
			add3[ii] =  { 1'b0, cell_array[2][ii] } +
							{ 1'b0, cell_array[1][ii] } +
							{ 1'b0, cell_array[0][ii] } ;
		end
		// Form add9 array (adding 3 x add3 values)
		for( int ii = 0; ii < 256; ii++ ) begin
			add9[ii] =  { 2'b00, (ii==255)?add3_q[0]:add3_q[ii+1] } +
							{ 2'b00,                     add3_q[ii+0] } +
							{ 2'b00, (ii==0)?add3_q[255]:add3_q[ii-1] } ;
		end
		// Calculate cell state
		for( int ii = 0; ii < 256; ii++ ) begin
			cell_next[ii] = ((( add9[ii]==4 ) &&  cell_array[1][ii] ) ||  // 4 alive of which we are 1 --> rule: alive and 3 neighbours --> stay alive
								  (( add9[ii]==3 ) &&  cell_array[1][ii] ) ||  // 3 alive of which we are 1 --> rule: alive and 2 neighbours --> stay Alive
								  (( add9[ii]==3 ) && !cell_array[1][ii] )) 	  // 3 alive and we are not    --> rule:  dead and 3 neighbours --> newly Alive
																		  ? 1'b1 : 1'b0; // otherwise the cell dies or remains dead.
		end
	end
	
	always @(posedge clk) 
		add3_q <= add3;
		
	always_ff@(posedge clk)
		mem_wdata <= cell_next;

endmodule