set_global_assignment -entity "hdmi_out" -library "lib_hdmi_out" -name IP_TOOL_NAME "altera_gpio_lite"
set_global_assignment -entity "hdmi_out" -library "lib_hdmi_out" -name IP_TOOL_VERSION "23.1"
set_global_assignment -entity "hdmi_out" -library "lib_hdmi_out" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_hdmi_out" -name SPD_FILE [file join $::quartus(sip_path) "hdmi_out.spd"]

set_global_assignment -library "lib_hdmi_out" -name MISC_FILE [file join $::quartus(sip_path) "hdmi_out_sim/hdmi_out.v"]
set_global_assignment -library "lib_hdmi_out" -name MISC_FILE [file join $::quartus(sip_path) "hdmi_out_sim/altera_gpio_lite/altera_gpio_lite.sv"]
