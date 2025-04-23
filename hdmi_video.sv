


module TDMS_encoder 
// translated from VHDL orginally by MikeField <hamster@snap.net.nz>
// re-written to closer match DVI-1.0 spec
(
	input clk,        // pixel rate clock
	input [7:0] data, // raw 8 bit video
	input [1:0] c, 	// control bits {c1,c0}
	input blank,      // !den == video blanking
	// Additional HDMI controls
	input video_guard,	// insert video guard bytes
	input [1:0] channel,	// channel id 0,1,2
	input data_guard,		// insert guard bytes, but sync on channel 1
	input island,			// data islands encoded with TERC4
	input [3:0] island_data,		// Data island data
	// Encoded output
	output [9:0] encoded, // encoded pixel
	output [9:0] dvi_encoded // no islands, guards, pre-ambles
);

logic [8:0] xored, xnored;
logic [3:0] ones;
logic [8:0] data_word, data_word_inv;
logic [3:0] data_word_disparity;
logic [3:0] dc_bias = 4'b0000;

// Work our the two different encodings for the byte

assign xored[0] = data[0];
assign xored[1] = data[1] ^ xored[0];
assign xored[2] = data[2] ^ xored[1];
assign xored[3] = data[3] ^ xored[2];
assign xored[4] = data[4] ^ xored[3];
assign xored[5] = data[5] ^ xored[4];
assign xored[6] = data[6] ^ xored[5];
assign xored[7] = data[7] ^ xored[6];
assign xored[8] = 1'b1;

assign xnored[0] = data[0];
assign xnored[1] = data[1] ~^ xnored[0];
assign xnored[2] = data[2] ~^ xnored[1];
assign xnored[3] = data[3] ~^ xnored[2];
assign xnored[4] = data[4] ~^ xnored[3];
assign xnored[5] = data[5] ~^ xnored[4];
assign xnored[6] = data[6] ~^ xnored[5];
assign xnored[7] = data[7] ~^ xnored[6];
assign xnored[8] = 1'b0;

// Count how many ones are set in data
assign ones[3:0]  = (({ 3'b000, data[0] } 
						+   { 3'b000, data[1] }) 
						+  ({ 3'b000, data[2] } 
						+   { 3'b000, data[3] }))
                  + (({ 3'b000, data[4] } 
						+   { 3'b000, data[5] }) 
						+  ({ 3'b000, data[6] } 
						+   { 3'b000, data[7] }));
 
// Decide which encoding to use
assign data_word = ( ones > 4'd4 || ( ones == 4'd4 && data[0] == 1'b0 )) ? xnored : xored;

// Work out the DC bias of the dataword;
assign data_word_disparity[3:0]  = (({ 3'b110, data_word[0] } 
											+   { 3'b000, data_word[1] }) 
											+  ({ 3'b000, data_word[2] } 
											+   { 3'b000, data_word[3] }))
											+ (({ 3'b000, data_word[4] } 
											+   { 3'b000, data_word[5] }) 
											+  ({ 3'b000, data_word[6] } 
											+   { 3'b000, data_word[7] }));		
	
// Now work out what the output should be
// Added HDMI video and data gurads and data islands,
// otherwise DVI default of control during blanking

always @(posedge clk) begin
	if( video_guard ) begin
		encoded <= ( channel == 2'd0 || channel == 2'd2 ) ? 10'b1011001100 : 10'b0100110011;
		dvi_encoded <=  ( c[1:0] == 2'b00 ) ? 10'b1101010100 : // no video guard for DVI
						    ( c[1:0] == 2'b01 ) ? 10'b0010101011 :
						    ( c[1:0] == 2'b10 ) ? 10'b0101010100 : 
					       /*c[1:0] == 2'b11*/   10'b1010101011 ;	
	end else if( data_guard ) begin
		encoded <= ( channel == 2'd1 || channel == 2'd2 ) ? 10'b0100110011 :
		           ( c[1:0] == 2'b00 ) ? 10'b1010001110 :
		           ( c[1:0] == 2'b01 ) ? 10'b1001110001 :
		           ( c[1:0] == 2'b10 ) ? 10'b0101100011 :
		           /*c[1:0] == 2'b11*/   10'b1011000011 ;
		dvi_encoded <=  ( c[1:0] == 2'b00 ) ? 10'b1101010100 : // no data guard for DVI
						    ( c[1:0] == 2'b01 ) ? 10'b0010101011 :
						    ( c[1:0] == 2'b10 ) ? 10'b0101010100 : 
					       /*c[1:0] == 2'b11*/   10'b1010101011 ;		
	end else if( island ) begin
		encoded <= 	( island_data[3:0] == 4'h0 ) ? 10'b1010011100  :
						( island_data[3:0] == 4'h1 ) ? 10'b1001100011  :
						( island_data[3:0] == 4'h2 ) ? 10'b1011100100  :
						( island_data[3:0] == 4'h3 ) ? 10'b1011100010  :
						( island_data[3:0] == 4'h4 ) ? 10'b0101110001  :
						( island_data[3:0] == 4'h5 ) ? 10'b0100011110  :
						( island_data[3:0] == 4'h6 ) ? 10'b0110001110  :
						( island_data[3:0] == 4'h7 ) ? 10'b0100111100  :
						( island_data[3:0] == 4'h8 ) ? 10'b1011001100  :
						( island_data[3:0] == 4'h9 ) ? 10'b0100111001  :
						( island_data[3:0] == 4'ha ) ? 10'b0110011100  :
						( island_data[3:0] == 4'hb ) ? 10'b1011000110  :
						( island_data[3:0] == 4'hc ) ? 10'b1010001110  :
						( island_data[3:0] == 4'hd ) ? 10'b1001110001  :
						( island_data[3:0] == 4'he ) ? 10'b0101100011  :
						/*island_data[3:0] == 4'hf )*/ 10'b1011000011  ;	
		dvi_encoded <=  ( c[1:0] == 2'b00 ) ? 10'b1101010100 : // no data island for DVI
						    ( c[1:0] == 2'b01 ) ? 10'b0010101011 :
						    ( c[1:0] == 2'b10 ) ? 10'b0101010100 : 
					       /*c[1:0] == 2'b11*/   10'b1010101011 ;		
	end else if( blank == 1'b1 ) begin
		encoded <=  ( c[1:0] == 2'b00 ) ? 10'b1101010100 :
						( c[1:0] == 2'b01 ) ? 10'b0010101011 :
						( c[1:0] == 2'b10 ) ? 10'b0101010100 : 
					   /*c[1:0] == 2'b11*/   10'b1010101011 ;
		dvi_encoded <=  ( c[1:0] == 2'b00 ) ? 10'b1101010100 :
						    ( c[1:0] == 2'b01 ) ? 10'b0010101011 :
						    ( c[1:0] == 2'b10 ) ? 10'b0101010100 : 
					       /*c[1:0] == 2'b11*/   10'b1010101011 ;		
		dc_bias <= 4'd0;
	end else begin 
		if( dc_bias == 4'd0 || data_word_disparity == 4'd0 ) begin // dataword has no disparity
			encoded <=     ( data_word[8] ) ? { 2'b01,  data_word[7:0] } : 
			                                  { 2'b10, ~data_word[7:0] } ;
			dvi_encoded <= ( data_word[8] ) ? { 2'b01,  data_word[7:0] } : 
			                                  { 2'b10, ~data_word[7:0] } ;
			dc_bias <= ( data_word[8] ) ? dc_bias + data_word_disparity : 
			                              dc_bias - data_word_disparity;
	   end else begin
		   if( ( dc_bias[3] == 1'b0 && data_word_disparity[3] == 1'b0 ) ||
		       ( dc_bias[3] == 1'b1 && data_word_disparity[3] == 1'b1 ) ) begin
				encoded     <= { 1'b1, data_word[8], ~data_word[7:0] };
				dvi_encoded <= { 1'b1, data_word[8], ~data_word[7:0] };
				dc_bias <= dc_bias + {3'b000,  data_word[8]} - data_word_disparity;
		   end else begin
				encoded     <= { 1'b0, data_word[8],  data_word[7:0] };
				dvi_encoded <= { 1'b0, data_word[8],  data_word[7:0] };
				dc_bias <= dc_bias - {3'b000, ~data_word[8]} + data_word_disparity;
			end
		end
	end
end
												
endmodule // TDMS_encoder

//////////////////////////////////////////

module video_encoder
// Convert RGB video and sync into HDMI data for output to DDR I/O
(
	// Clock
	input clk,	// Pixel clk
	input clk5,	// 5x pixel clock for DVI output (2x)
	input reset,

	// HDMI Output
	output [7:0] hdmi_data, // ddr data for the HDMI port, sync with 5x hdmi clk
	output [7:0] dvi_data, // same as HDMI but without data islands and guarding
	
	// Video Sync Interface, pix clock sync
	input blank,
	input hsync,
	input vsync,
	
	// VGA baseband pixel data
	input [7:0] red,
	input [7:0] green,
	input [7:0] blue,
	
	// HDMI Encoding controls
	input video_preamble,
	input data_preamble ,
	input video_guard   ,
	input data_guard    ,
	input data_island   ,
	
	// Control input
	input yuv_mode	// when asserrtted change to HDMI YUV encoded
);

// TDMS encode each channel.

	logic [9:0] enc_red, enc_green, enc_blue;
	logic [9:0] dvi_red, dvi_green, dvi_blue;
	
	logic [2:0][1:0] cdata;  // hdmi control data
	logic [2:0][3:0] idata;  // hdmi island data
	logic [8:0]      packet; // packet data for insertion, 32 cycles
	logic [4:0]		  cx    ; // packet location

	assign cdata[0] = { !vsync, !hsync                         };
	assign cdata[1] = { 1'b0  , data_preamble | video_preamble };
	assign cdata[2] = { 1'b0  , data_preamble                  };	
	
	assign idata[0] = { cx != 0 , packet[0], !vsync, !hsync }; // note MSB should be 0 for first cycle?!?
	assign idata[1] = packet[4:1];
	assign idata[2] = packet[8:5];
	
	TDMS_encoder _enc_blue_0(  .clk( clk ),.data( blue ), .c( cdata[0] ), .blank( blank ), .dvi_encoded( dvi_blue  ),.encoded( enc_blue  ), .channel( 2'd0 ), .island( data_island ), .data_guard( data_guard ), .island_data( idata[0] ), .video_guard( video_guard ) );
	TDMS_encoder _enc_green_1( .clk( clk ),.data( green ),.c( cdata[1] ), .blank( blank ), .dvi_encoded( dvi_green ),.encoded( enc_green ), .channel( 2'd1 ), .island( data_island ), .data_guard( data_guard ), .island_data( idata[1] ), .video_guard( video_guard ) );
	TDMS_encoder _enc_red_2(   .clk( clk ),.data( red ),  .c( cdata[2] ), .blank( blank ), .dvi_encoded( dvi_red   ),.encoded( enc_red   ), .channel( 2'd2 ), .island( data_island ), .data_guard( data_guard ), .island_data( idata[2] ), .video_guard( video_guard ) );
	
	//assign { enc_blue, enc_green, enc_red } = { dvi_blue, dvi_green, dvi_red }; // USE DVI for both, TODO remove
	//logic [2:0] tmds_mode; // Mode select (0 = control, 1 = video, 2 = video guard, 3 = island, 4 = island guard)
	//assign tmds_mode[2:0] = ( video_guard ) ? 3'd2 : ( data_guard ) ? 3'd4 : ( data_island ) ? 3'd3 : ( !blank ) ? 3'd1 : 3'd0;
	//assign { dvi_blue, dvi_green, dvi_red } = { enc_blue, enc_green, enc_red };
	//tmds_channel #(.CN(0)) _lib_enc_blue_0 ( .clk_pixel( clk ), .video_data( blue ), .data_island_data( idata[0] ), .control_data( cdata[0] ), .mode( tmds_mode[2:0] ), .tmds(  ) );
	//tmds_channel #(.CN(1)) _lib_enc_green_1( .clk_pixel( clk ), .video_data( green), .data_island_data( idata[1] ), .control_data( cdata[1] ), .mode( tmds_mode[2:0] ), .tmds(  ) );
	//tmds_channel #(.CN(2)) _lib_enc_red_2  ( .clk_pixel( clk ), .video_data( red  ), .data_island_data( idata[2] ), .control_data( cdata[2] ), .mode( tmds_mode[2:0] ), .tmds(  ) );
	
	// HDMI YUV/RGB Data island generation
	// yuv_mode controls selection
	
//`define USE_PACKET_ROM
`ifdef USE_PACKET_ROM
	// packet from roms files (saves a few LEs)
	reg [8:0] yuv_rom[31:0];
	reg [8:0] rgb_rom[31:0];	
	initial
	begin
		$readmemb("info_frame_yuv.txt", yuv_rom);
		$readmemb("info_frame_rgb.txt", rgb_rom);	
	end
	
	always @(posedge clk) 
		cx <= ( data_island ) ? cx + 1 : 0;
	
	assign packet = ( yuv_mode ) ? yuv_rom[cx] : rgb_rom[cx];

`else // packet logic for easy modification

	// Packets generated by logic
	logic [23:0] header_rgb;
	logic [23:0] header_yuv;
	logic [55:0] sub_rgb [3:0];
	logic [55:0] sub_yuv [3:0];
	
	auxiliary_video_information_info_frame 		// CEA-861-E InfoFrame Type 2 
	#(
    .VIDEO_FORMAT              	( 2'b01 		), // 00 = RGB, 01 = YCbCr 4:2:2, 10 = YCbCr 4:4:4
    .ACTIVE_FORMAT_INFO_PRESENT	( 1'b0 		), // 
    .BAR_INFO							( 2'b00 		), 
    .SCAN_INFO							( 2'b00 		), // Underscan 2'b10
    .COLORIMETRY						( 2'b00 		), // smpte 170m - 2'b01
    .PICTURE_ASPECT_RATIO			( 2'b00 		), // No Date - 2'b00, 4:3 - 2'b01, 16:9 - 2'b10
    .ACTIVE_FORMAT_ASPECT_RATIO	( 4'b0000 	), 
    .IT_CONTENT						( 1'b0 		),
    .EXTENDED_COLORIMETRY			( 3'b000 	), 
    .RGB_QUANTIZATION_RANGE		( 2'b00 		),
    .NON_UNIFORM_PICTURE_SCALING ( 2'b00 		), 
    .VIDEO_ID_CODE               ( 7'h00 		), 
    .YCC_QUANTIZATION_RANGE		( 2'b00 		), // Full Range YUV 2'b01
    .CONTENT_TYPE						( 2'b00 		), // Graphics, don't filter
    .PIXEL_REPETITION				( 4'b0000  	)  
	)
	_infoframe_yuv
	(
    .header ( header_yuv ),
    .sub		( sub_yuv 	)
	);

	auxiliary_video_information_info_frame 		// CEA-861-E InfoFrame Type 2
	#(
    .VIDEO_FORMAT              	( 2'b00 		), // 00 = RGB, 01 = YCbCr 4:2:2, 10 = YCbCr 4:4:4
    .ACTIVE_FORMAT_INFO_PRESENT	( 1'b0 		), 
    .BAR_INFO							( 2'b00 		), 
    .SCAN_INFO							( 2'b00 		), // Underscan 2'b10
    .COLORIMETRY						( 2'b00 		), // RGB - 2'b00
    .PICTURE_ASPECT_RATIO			( 2'b00 		), // No Date - 2'b00, 4:3 - 2'b01, 16:9 - 2'b10 
    .ACTIVE_FORMAT_ASPECT_RATIO	( 4'b0000 	), 
    .IT_CONTENT						( 1'b0 		),
    .EXTENDED_COLORIMETRY			( 3'b000 	), 
    .RGB_QUANTIZATION_RANGE		( 2'b00 		), // Full Range RGB 2'b10,
    .NON_UNIFORM_PICTURE_SCALING ( 2'b00 		), 
    .VIDEO_ID_CODE               ( 7'h00 		), 
    .YCC_QUANTIZATION_RANGE		( 2'b00 		), 
    .CONTENT_TYPE						( 2'b00 		), 
    .PIXEL_REPETITION				( 4'b0000  	)  
	)
	_infoframe_rgb
	(
    .header ( header_rgb ),
    .sub		( sub_rgb 	)
	);	
	 
	 // Shifts out packet[8:0] over 32 island cycles
	packet_assembler _pkt_assy_yuv (
    .clk_pixel 			( clk ),
    .reset     			( reset ),
    .data_island_period ( data_island ),
    .header 				( ( yuv_mode ) ? header_yuv : header_rgb ), 
    .sub  					( ( yuv_mode ) ?    sub_yuv :    sub_rgb ),
    .packet_data        (  packet ), 
    .counter            (  cx     )
	);
`endif	 	
		
		
/////////////////////////////////
// 5x Clock Data Accelleration
//////////////////////////////////
	
// Determine clk5 load phase;
	logic toggle; // cross phase signal
	always @(posedge clk) toggle <= !toggle;
	
	logic [5:0] tdelay;
	logic [1:0][9:0] shift_d2, shift_d1, shift_d0;
	logic [9:0] shift_ck;
	always @(posedge clk5) begin
		if( reset ) begin
			tdelay <= 0;
			shift_d0 <= 20'd0;
			shift_d1 <= 20'd0;
			shift_d2 <= 20'd0;
			shift_ck <= 10'd0;
		end else begin
			tdelay[5:0] <= { tdelay[4:0], toggle };
			if( tdelay[3] ^ tdelay[4] ) begin // load
				shift_d0 <= { dvi_blue      , enc_blue       };
				shift_d1 <= { dvi_green     , enc_green      };
				shift_d2 <= { dvi_red       , enc_red        };
				shift_ck <= 10'b0000011111;
			end else begin
				shift_d2 <= { 2'b00, shift_d2[1][9:2], 2'b00, shift_d2[0][9:2] };
				shift_d1 <= { 2'b00, shift_d1[1][9:2], 2'b00, shift_d1[0][9:2] };
				shift_d0 <= { 2'b00, shift_d0[1][9:2], 2'b00, shift_d0[0][9:2] };
				shift_ck <= { 2'b00, shift_ck[9:2] };
			end
		end
	end
	assign hdmi_data = { shift_d2[0][1], shift_d1[0][1], shift_d0[0][1], shift_ck[1], 
	                     shift_d2[0][0], shift_d1[0][0], shift_d0[0][0], shift_ck[0] };	
	assign  dvi_data = { shift_d2[1][1], shift_d1[1][1], shift_d0[1][1], shift_ck[1], 
	                     shift_d2[1][0], shift_d1[1][0], shift_d0[1][0], shift_ck[0] };	
endmodule // video_encoder0


module vga_800x480_sync // Generate a video sync
#(
// Video Timing Counts
parameter VERT		= 480,
parameter VFRONT 	= 13, // 10,
parameter VSYNCP 	= 3,  // 2,
parameter VBACK	= 29, // 33,
parameter HORIZ   = 800,
parameter HFRONT 	= 40, // 40,
parameter HSYNCP 	= 48, // 128,
parameter HBACK	= 40, // 88,
parameter VISLAND = VERT+VFRONT+VSYNCP-1 // line we send a data island
)
(
	input clk,	// Pixel clk
	input reset,
	output blank,
	output hsync,
	output vsync,
	// HDMI flags
	output video_preamble,
	output data_preamble,
	output video_guard,
	output data_guard,
	output data_island
);


// hcnt, vcnt - free running raw counters for 800x525 video frame (including hvsync)
logic [11:0] hcnt, vcnt;
always @(posedge clk) begin
	if( reset ) begin
		hcnt <= 0;
		vcnt <= VERT;	 // start after active data
		hsync <= 1'b0;
		vsync <= 1'b0;
		blank <= 1'b0;
		video_preamble <= 1'b0;
		data_preamble 	<= 1'b0;
		video_guard 	<= 1'b0;
		data_guard 		<= 1'b0;
		data_island	 	<= 1'b0;
	end else begin 
		// free run hcnt vcnt 800 x 525
		if( hcnt < (HORIZ+HFRONT+HSYNCP+HBACK-1) ) begin
			hcnt <= hcnt + 1;
			vcnt <= vcnt;
		end else begin
			hcnt <= 0;
			if( vcnt < (VERT+VFRONT+VSYNCP+VBACK-1)) begin 
				vcnt <= vcnt + 1;
			end else begin
				vcnt <= 0;
			end
		end
		// Derive sync and blanking signals from the counters
		blank <= ( hcnt >= HORIZ || vcnt >= VERT ) ? 1'b1 : 1'b0;
		hsync <= ( hcnt >= HORIZ+HFRONT && hcnt < HORIZ+HFRONT+HSYNCP ) ? 1'b1 : 1'b0;
		vsync <= ( hcnt == HORIZ+HFRONT ) ? (( vcnt >= VERT+VFRONT && vcnt < VERT+VFRONT+VSYNCP ) ? 1'b1 : 1'b0 ) : vsync;
		// HDMI signals
		// Adding video preable and guard
		video_preamble <= ( hcnt >= (HORIZ+HFRONT+HSYNCP+HBACK-10) && 
								  hcnt < (HORIZ+HFRONT+HSYNCP+HBACK-2 ) &&
								  (vcnt < (VERT-1) || vcnt == (VERT+VFRONT+VSYNCP+VBACK-1)) ) ? 1'b1 : 1'b0;
		video_guard <=    ( hcnt >= (HORIZ+HFRONT+HSYNCP+HBACK-2) && 
								  (vcnt < (VERT-1) || vcnt == (VERT+VFRONT+VSYNCP+VBACK-1)) ) ? 1'b1 : 1'b0;
		// Adding Data { control 4 preamble 8, guard 2, island 32, guard 2 }						  
		data_preamble  <= ( vcnt == VISLAND && hcnt >= HORIZ+4 && hcnt < HORIZ+4+8 ) ? 1'b1 : 1'b0;
		data_guard		<= ( vcnt == VISLAND &&(hcnt == HORIZ+4+8 || hcnt == HORIZ+4+8+1 || hcnt == HORIZ+4+8+2+32 || hcnt == HORIZ+4+8+2+32+1 ) ) ? 1'b1 :1'b0;
		data_island    <= ( vcnt == VISLAND && hcnt >= HORIZ+4+8+2 && hcnt < HORIZ+4+8+2+32 ) ? 1'b1 : 1'b0;
	end
end
endmodule // vga_800x480 sync


module test_pattern
// Create a test patern
// 13 color bars
(
	// Clock
	input clk,	// Pixel clk
	input reset,

	// Video Sync Interface, pix clock sync
	input blank,
	input hsync,
	input vsync,
	
	// VGA baseband pixel data
	output [7:0] red,
	output [7:0] green,
	output [7:0] blue
);

logic [9:0] xcnt, ycnt;
logic [3:0] barcnt;
logic [5:0] cnt50;
logic blank_d1;

always @(posedge clk) begin
	if ( reset ) begin
		xcnt <= 0;
		ycnt <= 0;
		blank_d1 <= 0;
	end else begin
		blank_d1 <= blank;
		cnt50 <= ( blank || cnt50 == 61 ) ? 0 : cnt50 + 1; 
		barcnt <= ( blank ) ? 0 : ( cnt50 == 61 ) ? barcnt + 1 : barcnt;
		xcnt <= ( blank ) ? 0 : xcnt + 1;
		ycnt <= ( vsync ) ? 0 : 
		        ( blank && !blank_d1 ) ? ycnt + 1 : ycnt;
	end
end

// Color outputs a function of location
assign { red, green, blue } = // smpte color bars
		( barcnt == 4'h0 ) ? 24'hc0c0c0 /* smpte_argent */ :
		( barcnt == 4'h1 ) ? 24'hc0c000 /* smpte_acid_green */ :
		( barcnt == 4'h2 ) ? 24'h00c000 /* smpte_islamic_green */ :
		( barcnt == 4'h3 ) ? 24'h00c0c0 /* smpte_turquoise_surf */ :
		( barcnt == 4'h4 ) ? 24'hc000c0 /* smpte_deep_mageneta */ :
		( barcnt == 4'h5 ) ? 24'hc00000 /* smpte_ue_red */ :
		( barcnt == 4'h6 ) ? 24'h0000c0 /* smpte_medium_blud */ :
		( barcnt == 4'h7 ) ? 24'h131313 /* smpte_chinese_black */ :
		( barcnt == 4'h8 ) ? 24'h00214c /* smpte_oxford_blue */ :
		( barcnt == 4'h9 ) ? 24'hffffff /* smpte_white */ :
		( barcnt == 4'ha ) ? 24'h32006a /* smpte_deep_violet */ :
		( barcnt == 4'hb ) ? 24'h090909 /* smpte_vampire_black */ :
		( barcnt == 4'hc ) ? 24'h1d1d1d /* smpte_eerie_black */ : 
		                     24'h000000 /*  */ ;
											
//assign red   = {xcnt[6],{7{ycnt[5]}}};
//assign green = {xcnt[7],{7{ycnt[6]}}};
//assign blue  = {xcnt[8],{7{ycnt[7]}}};

endmodule // test_pattern