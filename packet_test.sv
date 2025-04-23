// Simple test bench to generate HDMI infoFrame packets
// used to enable YUV format and switch to/from RGB.
// The excellent repo: https://github.com/hdl-util/hdmi.git
// Builds an auxillariy video info frame 24 bit header and 4x 56-bit words
// Then the packet assembly inserts the checksums and formats for output
// as 32 sequential words of 9 bits, ready for insertion in an HDMI data island
// The output will be saved to rom and writen to files
// Only executed during simulation

module packet_test ( 
	input logic clk,
	input logic reset 
	);

	// synthesis translate_off	
	 // Build Up a Packet

	logic [23:0] header_rgb;
	logic [23:0] header_yuv;
	logic [55:0] sub_rgb [3:0];
	logic [55:0] sub_yuv [3:0];
	
	auxiliary_video_information_info_frame 
	#(
    .VIDEO_FORMAT              	( 2'b01 		), // 00 = RGB, 01 = YCbCr 4:2:2, 10 = YCbCr 4:4:4
    .ACTIVE_FORMAT_INFO_PRESENT	( 1'b0 		), // Not valid
    .BAR_INFO							( 2'b00 		), // Not valid
    .SCAN_INFO							( 2'b00 		), // No data
    .COLORIMETRY						( 2'b00 		), // No data
    .PICTURE_ASPECT_RATIO			( 2'b00 		), // No data, See CEA-CEB16 for more information about Active Format Description processing.
    .ACTIVE_FORMAT_ASPECT_RATIO	( 4'b0000 	), // Not valid unless ACTIVE_FORMAT_INFO_PRESENT = 1'b1, then Same as picture aspect ratio
    .IT_CONTENT						( 1'b0 		), //  The IT content bit indicates when picture content is composed according to common IT practice (i.e. without regard to Nyquist criterion) and is unsuitable for analog reconstruction or filtering. When the IT content bit is set to 1, downstream processors should pass pixel data unfiltered and without analog reconstruction.
    .EXTENDED_COLORIMETRY			( 3'b000 	), // Not valid unless COLORIMETRY = 2'b11. The extended colorimetry bits, EC2, EC1, and EC0, describe optional colorimetry encoding that may be applicable to some implementations and are always present, whether their information is valid or not (see CEA 861-D Section 7.5.5).
    .RGB_QUANTIZATION_RANGE		( 2'b00 		), // Default. Displays conforming to CEA-861-D accept both a limited quantization range of 220 levels (16 to 235) anda full range of 256 levels (0 to 255) when receiving video with RGB color space (see CEA 861-D Sections 5.1, Section 5.2, Section 5.3 and Section 5.4). By default, RGB pixel data values should be assumed to have the limited range when receiving a CE video format, and the full range when receiving an IT format. The quantization bits allow the source to override this default and to explicitly indicate the current RGB quantization range.
    .NON_UNIFORM_PICTURE_SCALING ( 2'b00 		), // None. The Nonuniform Picture Scaling bits shall be set if the source device scales the picture or has determined that scaling has been performed in a specific direction.
    .VIDEO_ID_CODE               ( 7'h00 		), // Same as the one from the HDMI module
    .YCC_QUANTIZATION_RANGE		( 2'b00 		), // 00 = Limited, 01 = Full
    .CONTENT_TYPE						( 2'b00 		), // No data, becomes Graphics if IT_CONTENT = 1'b1.
    .PIXEL_REPETITION				( 4'b0000  	)  // None
	)
	_infoframe_yuv
	(
    .header ( header_yuv ),
    .sub		( sub_yuv 	)
	);

	auxiliary_video_information_info_frame 
	#(
    .VIDEO_FORMAT              	( 2'b00 		), // 00 = RGB, 01 = YCbCr 4:2:2, 10 = YCbCr 4:4:4
    .ACTIVE_FORMAT_INFO_PRESENT	( 1'b0 		), // Not valid
    .BAR_INFO							( 2'b00 		), // Not valid
    .SCAN_INFO							( 2'b00 		), // No data
    .COLORIMETRY						( 2'b00 		), // No data
    .PICTURE_ASPECT_RATIO			( 2'b00 		), // No data, See CEA-CEB16 for more information about Active Format Description processing.
    .ACTIVE_FORMAT_ASPECT_RATIO	( 4'b0000 	), // Not valid unless ACTIVE_FORMAT_INFO_PRESENT = 1'b1, then Same as picture aspect ratio
    .IT_CONTENT						( 1'b0 		), //  The IT content bit indicates when picture content is composed according to common IT practice (i.e. without regard to Nyquist criterion) and is unsuitable for analog reconstruction or filtering. When the IT content bit is set to 1, downstream processors should pass pixel data unfiltered and without analog reconstruction.
    .EXTENDED_COLORIMETRY			( 3'b000 	), // Not valid unless COLORIMETRY = 2'b11. The extended colorimetry bits, EC2, EC1, and EC0, describe optional colorimetry encoding that may be applicable to some implementations and are always present, whether their information is valid or not (see CEA 861-D Section 7.5.5).
    .RGB_QUANTIZATION_RANGE		( 2'b00 		), // Default. Displays conforming to CEA-861-D accept both a limited quantization range of 220 levels (16 to 235) anda full range of 256 levels (0 to 255) when receiving video with RGB color space (see CEA 861-D Sections 5.1, Section 5.2, Section 5.3 and Section 5.4). By default, RGB pixel data values should be assumed to have the limited range when receiving a CE video format, and the full range when receiving an IT format. The quantization bits allow the source to override this default and to explicitly indicate the current RGB quantization range.
    .NON_UNIFORM_PICTURE_SCALING ( 2'b00 		), // None. The Nonuniform Picture Scaling bits shall be set if the source device scales the picture or has determined that scaling has been performed in a specific direction.
    .VIDEO_ID_CODE               ( 7'h00 		), // Same as the one from the HDMI module
    .YCC_QUANTIZATION_RANGE		( 2'b00 		), // 00 = Limited, 01 = Full
    .CONTENT_TYPE						( 2'b00 		), // No data, becomes Graphics if IT_CONTENT = 1'b1.
    .PIXEL_REPETITION				( 4'b0000  	)  // None
	)
	_infoframe_rgb
	(
    .header ( header_rgb ),
    .sub		( sub_rgb 	)
	);	
	
	logic [8:0] packet_data_rgb;
	logic [8:0] packet_data_yuv;
	logic [4:0] counter;
	logic data_island_period;
	 
	 packet_assembler _pkt_assy_yuv (
    .clk_pixel 			( clk ),
    .reset     			( reset ),
    .data_island_period ( data_island_period ),
    .header 				( header_yuv ) , //Info Frame Packet
    .sub  					( sub_yuv ),
	 // Output 32 cyc, 9 bits to tdms encider
    .packet_data( packet_data_yuv ), // See Figure 5-4 Data Island Packet and ECC Structure
    .counter( counter ) // counter = 5'd0
	);
	 
	 packet_assembler _pkt_assy_rgb (
    .clk_pixel 			( clk ),
    .reset     			( reset ),
    .data_island_period ( data_island_period ),
    .header 				( header_rgb ) , //Info Frame Packet
    .sub  					( sub_rgb ),
	 // Output 32 cyc, 9 bits to tdms encider
    .packet_data( packet_data_rgb ), // See Figure 5-4 Data Island Packet and ECC Structure
    .counter( ) // counter = 5'd0
	);
	 
	// Save packet into a buffer
	logic [8:0] buffer_yuv [31:0];
	logic [8:0] buffer_rgb [31:0];
	always @(posedge clk) 
		if( data_island_period ) begin
			buffer_yuv[ counter[4:0] ] <= packet_data_yuv[8:0];	 
			buffer_rgb[ counter[4:0] ] <= packet_data_rgb[8:0];	 
		end

			
	// Create 32 cycle data island
	initial begin
		data_island_period = 0;
		for( int ii = 0; ii < 50; ii++ ) @(posedge clk);
		data_island_period = 1;
		for( int ii = 0; ii < 32; ii++ ) @(posedge clk);
		data_island_period = 0;
		for( int ii = 0; ii < 10; ii++ ) @(posedge clk);
		$writememb("info_frame_yuv.txt", buffer_yuv );		
		$writememb("info_frame_rgb.txt", buffer_rgb );		
	end
// synthesis translate_on
	
endmodule