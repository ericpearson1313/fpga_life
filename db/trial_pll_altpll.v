//altpll bandwidth_type="AUTO" CBX_DECLARE_ALL_CONNECTED_PORTS="OFF" clk0_divide_by=8 clk0_duty_cycle=50 clk0_multiply_by=1 clk0_phase_shift="0" clk1_divide_by=1 clk1_duty_cycle=50 clk1_multiply_by=1 clk1_phase_shift="0" clk2_divide_by=1 clk2_duty_cycle=50 clk2_multiply_by=4 clk2_phase_shift="0" clk3_divide_by=3 clk3_duty_cycle=50 clk3_multiply_by=2 clk3_phase_shift="0" clk4_divide_by=3 clk4_duty_cycle=50 clk4_multiply_by=10 clk4_phase_shift="0" device_family="MAX 10" inclk0_input_frequency=20833 intended_device_family="MAX 10" lpm_hint="CBX_MODULE_PREFIX=trial_pll" operation_mode="no_compensation" pll_type="AUTO" port_clk0="PORT_USED" port_clk1="PORT_USED" port_clk2="PORT_USED" port_clk3="PORT_USED" port_clk4="PORT_USED" port_clk5="PORT_UNUSED" port_extclk0="PORT_UNUSED" port_extclk1="PORT_UNUSED" port_extclk2="PORT_UNUSED" port_extclk3="PORT_UNUSED" port_inclk1="PORT_UNUSED" port_phasecounterselect="PORT_UNUSED" port_phasedone="PORT_UNUSED" port_scandata="PORT_UNUSED" port_scandataout="PORT_UNUSED" width_clock=5 clk inclk CARRY_CHAIN="MANUAL" CARRY_CHAIN_LENGTH=48
//VERSION_BEGIN 23.1 cbx_altclkbuf 2023:11:29:19:36:39:SC cbx_altiobuf_bidir 2023:11:29:19:36:39:SC cbx_altiobuf_in 2023:11:29:19:36:39:SC cbx_altiobuf_out 2023:11:29:19:36:39:SC cbx_altpll 2023:11:29:19:36:39:SC cbx_cycloneii 2023:11:29:19:36:39:SC cbx_lpm_add_sub 2023:11:29:19:36:39:SC cbx_lpm_compare 2023:11:29:19:36:39:SC cbx_lpm_counter 2023:11:29:19:36:39:SC cbx_lpm_decode 2023:11:29:19:36:39:SC cbx_lpm_mux 2023:11:29:19:36:37:SC cbx_mgl 2023:11:29:19:36:47:SC cbx_nadder 2023:11:29:19:36:39:SC cbx_stratix 2023:11:29:19:36:39:SC cbx_stratixii 2023:11:29:19:36:39:SC cbx_stratixiii 2023:11:29:19:36:39:SC cbx_stratixv 2023:11:29:19:36:39:SC cbx_util_mgl 2023:11:29:19:36:39:SC  VERSION_END
//CBXI_INSTANCE_NAME="life_core_trial_pll_spll_altpll_altpll_component"
// synthesis VERILOG_INPUT_VERSION VERILOG_2001
// altera message_off 10463



// Copyright (C) 2023  Intel Corporation. All rights reserved.
//  Your use of Intel Corporation's design tools, logic functions 
//  and other software and tools, and any partner logic 
//  functions, and any output files from any of the foregoing 
//  (including device programming or simulation files), and any 
//  associated documentation or information are expressly subject 
//  to the terms and conditions of the Intel Program License 
//  Subscription Agreement, the Intel Quartus Prime License Agreement,
//  the Intel FPGA IP License Agreement, or other applicable license
//  agreement, including, without limitation, that your use is for
//  the sole purpose of programming logic devices manufactured by
//  Intel and sold by Intel or its authorized distributors.  Please
//  refer to the applicable agreement for further details, at
//  https://fpgasoftware.intel.com/eula.



//synthesis_resources = fiftyfivenm_pll 1 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
module  trial_pll_altpll
	( 
	clk,
	inclk) /* synthesis synthesis_clearbox=1 */;
	output   [4:0]  clk;
	input   [1:0]  inclk;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0   [1:0]  inclk;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire  [4:0]   wire_pll1_clk;
	wire  wire_pll1_fbout;

	fiftyfivenm_pll   pll1
	( 
	.activeclock(),
	.clk(wire_pll1_clk),
	.clkbad(),
	.fbin(wire_pll1_fbout),
	.fbout(wire_pll1_fbout),
	.inclk(inclk),
	.locked(),
	.phasedone(),
	.scandataout(),
	.scandone(),
	.vcooverrange(),
	.vcounderrange()
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.areset(1'b0),
	.clkswitch(1'b0),
	.configupdate(1'b0),
	.pfdena(1'b1),
	.phasecounterselect({3{1'b0}}),
	.phasestep(1'b0),
	.phaseupdown(1'b0),
	.scanclk(1'b0),
	.scanclkena(1'b1),
	.scandata(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	);
	defparam
		pll1.bandwidth_type = "auto",
		pll1.clk0_divide_by = 8,
		pll1.clk0_duty_cycle = 50,
		pll1.clk0_multiply_by = 1,
		pll1.clk0_phase_shift = "0",
		pll1.clk1_divide_by = 1,
		pll1.clk1_duty_cycle = 50,
		pll1.clk1_multiply_by = 1,
		pll1.clk1_phase_shift = "0",
		pll1.clk2_divide_by = 1,
		pll1.clk2_duty_cycle = 50,
		pll1.clk2_multiply_by = 4,
		pll1.clk2_phase_shift = "0",
		pll1.clk3_divide_by = 3,
		pll1.clk3_duty_cycle = 50,
		pll1.clk3_multiply_by = 2,
		pll1.clk3_phase_shift = "0",
		pll1.clk4_divide_by = 3,
		pll1.clk4_duty_cycle = 50,
		pll1.clk4_multiply_by = 10,
		pll1.clk4_phase_shift = "0",
		pll1.inclk0_input_frequency = 20833,
		pll1.operation_mode = "no_compensation",
		pll1.pll_type = "auto",
		pll1.lpm_type = "fiftyfivenm_pll";
	assign
		clk = {wire_pll1_clk[4:0]};
endmodule //trial_pll_altpll
//VALID FILE
