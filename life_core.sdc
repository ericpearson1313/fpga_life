derive_pll_clocks -create_base_clocks

#create_clock -period 20.833 -waveform {0.000 10.416} -name clk_in clk_in

#create_generated_clock -source clk_in -divide_by 8                 -duty_cycle 50.00 -name {_spll|altpll_component|auto_generated|pll1|clk[0]}   clk_out
#create_generated_clock -source clk_in                              -duty_cycle 50.00 -name {_spll|altpll_component|auto_generated|pll1|clk[1]}       clk
#create_generated_clock -source clk_in              -multiply_by 4  -duty_cycle 50.00 -name {_spll|altpll_component|auto_generated|pll1|clk[2]}      clk4
#create_generated_clock -source clk_in -divide_by 3 -multiply_by 2  -duty_cycle 50.00 -name {_spll|altpll_component|auto_generated|pll1|clk[3]}  hdmi_clk
#create_generated_clock -source clk_in -divide_by 3 -multiply_by 10 -duty_cycle 50.00 -name {_spll|altpll_component|auto_generated|pll1|clk[4]} hdmi_clk5

# Create a base clock for the PLL input clock
#create_clock -name __name -period __period [get_ports __port]
# Create a generated clock for each PLL output clock
#create_generated_clock -name __name -divide_by __factor -multiply_by __factor -source __source [get_pins __target] 
# Create additional generated clocks for each PLL output clock
#create_generated_clock -name __name -divide_by __factor -multiply_by __factor -source __source [get_pins __target] 

#create_clock -period 20.833 -waveform {0.000 10.416} -name clk_in clk_in
#create_generated_clock -source {_spll|altpll_component|auto_generated|pll1|inclk[0]} -divide_by 8 -duty_cycle 50.00 -name {_spll|altpll_component|auto_generated|pll1|clk[0]} {_spll|altpll_component|auto_generated|pll1|clk[0]}
#create_generated_clock -source {_spll|altpll_component|auto_generated|pll1|inclk[0]} -duty_cycle 50.00 -name {_spll|altpll_component|auto_generated|pll1|clk[1]} {_spll|altpll_component|auto_generated|pll1|clk[1]}
#create_generated_clock -source {_spll|altpll_component|auto_generated|pll1|inclk[0]} -multiply_by 4 -duty_cycle 50.00 -name {_spll|altpll_component|auto_generated|pll1|clk[2]} {_spll|altpll_component|auto_generated|pll1|clk[2]}
#create_generated_clock -source {_spll|altpll_component|auto_generated|pll1|inclk[0]} -divide_by 3 -multiply_by 2 -duty_cycle 50.00 -name {_spll|altpll_component|auto_generated|pll1|clk[3]} {_spll|altpll_component|auto_generated|pll1|clk[3]}
#create_generated_clock -source {_spll|altpll_component|auto_generated|pll1|inclk[0]} -divide_by 3 -multiply_by 10 -duty_cycle 50.00 -name {_spll|altpll_component|auto_generated|pll1|clk[4]} {_spll|altpll_component|auto_generated|pll1|clk[4]}

derive_clock_uncertainty

#Ignore paths from base clock clk[1], clk[2] to video clocks clk[3], clk[4] for now
set_false_path -from [get_clocks {_spll|altpll_component|auto_generated|pll1|clk[1]}] -to [get_clocks {_spll|altpll_component|auto_generated|pll1|clk[3]}]
set_false_path -from [get_clocks {_spll|altpll_component|auto_generated|pll1|clk[1]}] -to [get_clocks {_spll|altpll_component|auto_generated|pll1|clk[4]}]
set_false_path -from [get_clocks {_spll|altpll_component|auto_generated|pll1|clk[2]}] -to [get_clocks {_spll|altpll_component|auto_generated|pll1|clk[3]}]
set_false_path -from [get_clocks {_spll|altpll_component|auto_generated|pll1|clk[2]}] -to [get_clocks {_spll|altpll_component|auto_generated|pll1|clk[4]}]
*
#Ignore case of auto generated we_reg to output 
#The simulataneous raddr=waddr is avoided by design
#set_false_path -from {life_engine:_life_engine|altsyncram:ram_rtl_0|altsyncram_9q71:auto_generated|ram_block1a100~porta_we_reg} -to {life_engine:_life_engine|cell_array[0][101]}
#set_false_path -from [get_registers {*ram_block*porta_we_reg}] -to [get_registers {life_engine:_life_engine|cell_array*}]

#break up intentionally created carry chains.
#Break add8 carry chains from cin to cout.
#suspect the tool eliminates these paths as it looks at the LE lut contents. Can probably not worry about it.
#need to get correct syntax, names and regular expressions.
#set_false_path -from [get_pins {*add431_cell:*|lut_in[3][2]}]  -to [get_pins {*add431_cell:*|cout[3]}]
#set_false_path -from [get_pins {*add431_cell:*|lut_in[6][2]}]  -to [get_pins {*add431_cell:*|cout[6]}]
#set_false_path -from [get_pins {*add431_cell:*|lut_in[9][2]}]  -to [get_pins {*add431_cell:*|cout[9]}]
#set_false_path -from [get_pins {*add431_cell:*|lut_in[12][2]}] -to [get_pins {*add431_cell:*|cout[12]}]
#break add8 path from B to sout
#set_false_path -from [get_pins {*add431_cell:*|lut_in[3][1]}]  -to [get_pins {*add431_cell:*|sout[3]}]
#set_false_path -from [get_pins {*add431_cell:*|lut_in[6][1]}]  -to [get_pins {*add431_cell:*|sout[6]}]
#set_false_path -from [get_pins {*add431_cell:*|lut_in[9][1]}]  -to [get_pins {*add431_cell:*|sout[9]}]
#set_false_path -from [get_pins {*add431_cell:*|lut_in[12][1]}] -to [get_pins {*add431_cell:*|sout[12]}]
#break add8 path from A to cout
#set_false_path -from [get_pins {*add431_cell:*|lut_in[3][0]}]  -to [get_pins {*add431_cell:*|cout[3]}]
#set_false_path -from [get_pins {*add431_cell:*|lut_in[6][0]}]  -to [get_pins {*add431_cell:*|cout[6]}]
#set_false_path -from [get_pins {*add431_cell:*|lut_in[9][0]}]  -to [get_pins {*add431_cell:*|cout[9]}]
#set_false_path -from [get_pins {*add431_cell:*|lut_in[12][0]}] -to [get_pins {*add431_cell:*|cout[12]}]

