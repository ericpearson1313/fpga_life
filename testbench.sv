// top level launcher sim.
`timescale 1ns / 1ps
module testbench( );

`define HDMI_INFOFRAME
//`define FONT_GEN
//`define DIV_TEST
//`define PSRAM_TEST
//`define BLASTER_TEST


///////////////////////////////
`ifdef HDMI_INFOFRAME

    //////////////////////
    // Let there be Clocks!
    //////////////////////
    
    logic clk, clk4;
    initial begin
        clk = 1'b1;
		  clk4 = 1'b1;
        forever begin
				#(2.5ns) clk4 = 0;
				#(2.5ns) clk4 = 1;
				#(2.5ns) clk4 = 0;
				#(2.5ns) begin clk4 = 1; clk = ~clk; end
        end 
    end
	 
	 // Reset generation
	 
	 logic reset; // active high
	 initial begin
			reset = 1'b1;
			for( int ii = 0; ii < 10; ii++ ) begin
				@(posedge clk);
			end
			@(negedge clk);
			reset = 1'b0;
	 end
			
	 // Simulation stop.
	 
	 initial begin
        for( int ii = 0; ii < 100; ii++ ) 
				@(posedge clk);
        $stop;
	 end

	 ////////////////
	 // UUT
	 ////////////////
	 
	 packet_test _uut (
		.clk( clk ),
		.reset( reset )
	 );

`endif // HDMI_INFOFRAME

///////////////////////////////
`ifdef FONT_GEN
	
	logic clk, reset;
	logic blank, hsync, vsync;
	logic [7:0] char_x, char_y;
	logic [255:0] ascii_char;
	logic [15:0] hex_char;
	logic [1:0] bin_char;

	ascii_font57 _font
	(
		.clk( 0 ),
		.reset( 0 ),
		.blank( 0 ),
		.hsync( 0 ),
		.vsync( 0 ),
		.char_x( char_x ), // 0 to 105 chars horizontally
		.char_y( char_y ), // o to 59 rows vertically
		.hex_char   ( hex_char ),
		.binary_char( bin_char ),
		.ascii_char ( ascii_char )	
	);

	 initial begin
        #(2.5ns)
        $stop;
	 end
`endif // FONT_GEN

///////////////////////////////
`ifdef DIV_TEST

    //////////////////////
    // Let there be Clocks!
    //////////////////////
    
    logic clk, clk4;
    initial begin
        clk = 1'b1;
		  clk4 = 1'b1;
        forever begin
				#(2.5ns) clk4 = 0;
				#(2.5ns) clk4 = 1;
				#(2.5ns) clk4 = 0;
				#(2.5ns) begin clk4 = 1; clk = ~clk; end
        end 
    end
	 
	 // Reset generation
	 
	 logic reset; // active high
	 initial begin
			reset = 1'b1;
			for( int ii = 0; ii < 10; ii++ ) begin
				@(posedge clk);
			end
			@(negedge clk);
			reset = 1'b0;
	 end
			
	 // Simulation stop.
	 
	 initial begin
        for( int ii = 0; ii < 1000; ii++ ) 
				@(posedge clk);
        $stop;
	 end

    //////////////////////
    // UUT Unit Under Test
    //////////////////////

	 logic [11:0] voltage, current, resistance;
	 logic [11:0] vin, iin, rout;
	 logic in_valid, out_valid;
 	 ohm_div _uut (
		// Input clock
		.clk( clk ),
		.reset( reset ),
		// Votlage and Current Inputs
		.valid_in( in_valid ),
		.v_in( vin ), // ADC Vout
		.i_in( iin ), // ADC Iout
		// Resistance Output
		.valid_out( out_valid ),
		.r_out( rout )
	);
	
	// covert adc to signed, and vice versa
	assign vin = voltage ^ 12'h7ff; // .2005 V/DN
	assign iin = current ^ 12'h7ff; // 205 DN/A
	assign resistance = rout ^ 12'h7ff; // 32 DN/ohm
	
	// test

	
	initial begin
		// reset signals
		voltage = 0;
		current = 0;
		in_valid = 0;
      // startup delay (for future reset)
      for( int ii = 0; ii < 15; ii++ ) @(posedge clk); // 15 cycles
		
	// Test Case #1
	// 2.5 ohms 5 volts, 2 amps
		@(posedge clk);
		voltage = 5.0 / 0.2005;
		current = 2 * 209;
		in_valid = 1;
		@(posedge clk);
		voltage = 0;
		current = 0;
		in_valid = 0;
		// wait for data output
		while( !out_valid ) @(posedge clk);			
		
		// Observe 6.5 format = '04E , about 2.4 ohms


	// Test Case #2
	// 30 ohms 90 volts, 3 amps
		@(posedge clk);	
		voltage = 90 / 0.2005;
		current = 3 * 209;
		in_valid = 1;
		@(posedge clk);
		voltage = 0;
		current = 0;
		in_valid = 0;
		// wait for data output
		while( !out_valid ) @(posedge clk);			
		
		// Observe '3AD, about 29.4 ohms
		
	// Test Case #3 - Clipping
	// 70 ohms 140 volts, 2 amps
		@(posedge clk);	
		voltage = 140 / 0.2005;
		current = 2 * 209;
		in_valid = 1;
		@(posedge clk);
		voltage = 0;
		current = 0;
		in_valid = 0;
		// wait for data output
		while( !out_valid ) @(posedge clk);			
		
		// Observe '7FF Clipped value
		
		// Stop Sim in a bit
      for( int ii = 0; ii < 100; ii++ ) @(posedge clk); // 16 cycles		
		 $stop;
		
	end
	
	
	
	
	
`endif // DIV_TEST

///////////////////////////////
`ifdef PSRAM_TEST


    //////////////////////
    // Let there be Clocks!
    //////////////////////
    
    logic clk, clk4;
    initial begin
        clk = 1'b1;
		  clk4 = 1'b1;
        forever begin
				#(2.5ns) clk4 = 0;
				#(2.5ns) clk4 = 1;
				#(2.5ns) clk4 = 0;
				#(2.5ns) begin clk4 = 1; clk = ~clk; end
        end 
    end
	 
	 // Reset generation
	 
	 logic reset; // active high
	 initial begin
			reset = 1'b1;
			for( int ii = 0; ii < 10; ii++ ) begin
				@(posedge clk);
			end
			@(negedge clk);
			reset = 1'b0;
	 end
			
	 // Simulation stop.
	 
	 initial begin
        for( int ii = 0; ii < 1000; ii++ ) 
				@(posedge clk);
        $stop;
	 end
	 


    //////////////////////
    // UUT Unit Under Test
    //////////////////////


	logic [7:0] 	spi_data_out;
	logic   			spi_data_oe;
	logic [1:0]   	spi_le_out; // match delay
	logic [7:0] 	spi_data_in;
	logic [1:0]		spi_le_in; // match IO registering
	logic				spi_clk;
	logic				spi_cs;
	logic				spi_rwds_out;
	logic				spi_rwds_oe;
	logic				spi_rwds_in;
	
	// SPI Controller
	
	logic psram_ready;
	logic [17:0] rdata;
	logic rvalid;
	
	// Loopback SPI I/O
	
	assign spi_data_in = spi_data_out;
	assign spi_le_in = spi_le_out;
	assign spi_rwds_in = spi_rwds_out;
	
	psram_ctrl _uut (
		// System
		.clk		( clk ),
		.clk4		( clk4 ),
		.reset	( reset ),
		// Psram spi8 interface
		.spi_data_out( spi_data_out ),
		.spi_data_oe(  spi_data_oe  ),
		.spi_le_out( 	spi_le_out 	 ),
		.spi_data_in( 	spi_data_in  ),
		.spi_le_in( 	spi_le_in 	 ),
		.spi_clk( 		spi_clk 		 ),
		.spi_cs( 		spi_cs 		 ),
		.spi_rwds_out( spi_rwds_out ),
		.spi_rwds_oe( 	spi_rwds_oe  ),
		.spi_rwds_in( 	spi_rwds_in  ),
		// Status
		.psram_ready( psram_ready ),	// Indicates control is ready to accept requests
		// AXI4 R/W port
		// Write Data
		.wdata( 16'h0000 ),
		.wvalid( 1'b1 ), // always avail)
		.wready(      ),
		// Write Addr
		.awaddr( 25'h000_0000 ),
		.awlen( 8'h08 ),	// assumed 8
		.awvalid( 1'b0 ), // write valid
		.awready( ),
		// Write Response
		.bready( 1'b1 ),	// Assume 1, non blocking
		.bvalid(  ),
		.bresp(  ),
		// Read Addr
		.araddr( 25'h000_0000 ),
		.arlen( 8'h04 ),	// assumed 4
		.arvalid( 1'b0 ), // read valid	
		.arready(),
		// Read Data
		.rdata( rdata[17:0] ),
		.rvalid( rvalid ),
		.rready( 1'b1 ) // Assumed 1, non blocking
	);	

`endif // PSRAM_TEST

`ifdef BLASTER_TEST
parameter R = 10.0; // Load resistance
parameter CAP_VOLTAGE = 320.0;
parameter COIL_UH = 399.0;
parameter FREQ_MHZ = 48;
parameter PERIOD_NS = 20.8;
parameter CAP_UF = 1.0;  // typicall 100uF
parameter CURRENT = 2 	; // integer amps, 1 to 7

logic arm, fire;
logic pwm, dump;
logic done, charge;
logic n_sclk, n_cs;
logic [3:0] data, data_n;

    //////////////////////
    // Let there be Clock!
    //////////////////////
    
    logic clk;
    initial begin
        clk = 1'b1;
        forever begin
            #(10.4ns) clk = ~clk;
        end 
    end
	 
	 // Reset generation
	 
	 logic reset; // active high
	 initial begin
			reset = 1'b1;
			for( int ii = 0; ii < 3; ii++ ) begin
				@(posedge clk);
			end
			@(negedge clk);
			reset = 1'b0;
	 end
			
	 // Simulation stop.
	 
	 initial begin
        for( int ii = 0; ii < 80000; ii++ ) 
				@(posedge clk);
        $stop;
	 end
	 

blaster _uut (
	// Input Buttons
	.arm_button( arm ), // arm is the power button
	.fire_button( fire ),

	// Output LED/SPK
	.arm_led(),
	.cont_led(),
	.speaker(),
	
	// Charger
	.lt3420_done( done ),
	.lt3420_charge( charge ),

	// Voltage Controls
	.pwm( pwm ),
	.dump( dump ),

	// Continuity feedback
	.cont( 1'b1 ),
	
	// Current setting
	.iset( CURRENT  ),
	
	// External A/D Converters (2.5v)
	.ad_cs( n_cs ),
	.ad_sdata_a( data[1:0] ),
	.ad_sdata_b( data[3:2] ),

	// Input clock
	.clk( clk ),
	.reset( reset )
);


		
		// TODO, turn these back to reals (but after I get git setup)
		
		real ecap, ecap_n; 		
		real icap, icap_n; 
		real vcap, vcap_n; 
		real iout, iout_n; 
		real vout, vout_n; 
	 
	
		
	initial begin
		// hardware will wait for fire;
		fire = 1'b0;
		arm  = 1'b1; // arm assume to go high with power-on at this time.
		done = 1'b1; // for sim show charge complete
      // startup delay (for future reset)
      for( int ii = 0; ii < 10; ii++ ) @(posedge clk); // 10 cycles
		// Fire
		fire = 1'b1;
	end // fire		
		
	initial begin


	/////////////////////
	// System Model     
	/////////////////////	
	// Model of power module 
	// root states are capacitor energy and coil (output) current.
	// The model updates these dynamically from the pwm state
	// The cap voltage is derived from cap energy, and cap current from pwm and coil current.
	// The output voltage is a function of igniter resistance and coil (output) current.
	// 
	
		vcap = CAP_VOLTAGE;
		ecap = (0.5 * CAP_UF * CAP_VOLTAGE * CAP_VOLTAGE)/1000000.0; 
		icap = 0;
		vout = 0;
		iout = 0;

		// on a cycle loop, now responde to PWM 
		// TODO add dump modelling
		
		forever begin
			@(posedge clk ) ;
			if( pwm == 0 ) begin
				// output off, I falls at rate Vout/L*t
				iout_n = iout - ((vout / (COIL_UH * FREQ_MHZ))); 
				// The updated Vout is IR
				vout_n = (iout_n * R);
				// Icap = 0; Ecap, Vcap unchanged
				icap_n = 0;
				vcap_n = vcap;
				ecap_n = ecap;
			end else begin 
				// output is on, I rises by (Vin-Vout)/L
				iout_n = iout + (((vcap - vout) / (COIL_UH * FREQ_MHZ)));
				// The updated Vout is IR
				vout_n = (iout_n * R);
				// Icap = Iout
				icap_n = iout_n;
				// cap drops by energy used this cycle IVT
				ecap_n = ecap - ((((((iout+iout_n)/2)*vcap) / (FREQ_MHZ*1000000.0)))) ;
				// votlage is calc from energy

				vcap_n = ($sqrt( (2.0 * ecap_n) / CAP_UF ) * 1000.0);

			end
			
			iout = iout_n;
			vout = vout_n;
			ecap = ecap_n;
			vcap = vcap_n;
			icap = icap_n;		
		end // Analog model
	end // analog model

	
	/////////////////////
	// AD7352 Model     
	/////////////////////
	// Models amplification
	// adc sampling, conversion
	// and transmission
	
	// ADC sampling and transmission.
	logic [11:0] sh_vcap;	// 0 to 350 volts  350/4096
	logic [11:0] sh_icap;	// 0 to 12 amp     12/4096
	logic [11:0] sh_vout;	// 0 to 350 volts
	logic [11:0] sh_iout;	// 0 to 12 amp

	assign n_sclk = clk; // same clock, adc just uses negedge.
	
	initial begin
		data_n = 4'b0;
	   sh_vcap = 0.0;
		sh_icap = 0.0;
		sh_vout = 0.0;
		sh_iout = 0.0;
		forever begin
			@(negedge n_sclk ) 
			while( n_cs != 1 ) begin // it has to start high
				@(negedge n_sclk ); 
			end
			while( n_cs != 0 ) begin // wait for it to go low
				@(negedge n_sclk ); 
			end
			// first falling edge with n_cs active low, output 2nd zero
			data_n = 4'b0;
			// sample 
			sh_vcap[11:0] = int'(vcap * 8  );
			sh_icap[11:0] = int'(icap * 256);
			sh_vout[11:0] = int'(vout * 8  );
			sh_iout[11:0] = int'(iout * 256);

			@(negedge n_sclk ); 
			for( int bitpos = 11; bitpos >= 0; bitpos-- ) begin
				data_n[3:0] = { sh_vcap[bitpos], sh_icap[bitpos], sh_vout[bitpos], sh_iout[bitpos] };
				@(negedge n_sclk ); 
			end
			data_n[3:0] = 4'b0;
		end // adc
	end
	
	// adc oe.
	assign data[3:0] = ( n_cs == 1'b0 ) ? data_n[3:0] : 4'bxxxx;
`endif // BLASTER_TEST

endmodule
