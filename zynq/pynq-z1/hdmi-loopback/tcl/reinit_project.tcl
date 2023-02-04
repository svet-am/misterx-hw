# Get common environment information
set scriptPath [ file dirname [ file normalize [ info script ] ] ]
set hostOS [lindex $tcl_platform(os) 0]
puts $scriptPath

create_project project $scriptPath/../work -part xc7z020clg400-1
set_msg_config -id {[IP_Flow 19-4965]} -new_severity {WARNING}

set_param board.repoPaths $scriptPath/../../../../board_files/

set_property  ip_repo_paths  $scriptPath/../../../../vivado-library/ [current_project]
update_ip_catalog

set_property board_part www.digilentinc.com:pynq-z1:part0:1.0 [current_project]

create_bd_design -dir $scriptPath/../ipi "system"

startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0
create_bd_cell -type ip -vlnv digilentinc.com:ip:rgb2dvi:1.4 rgb2dvi_0
create_bd_cell -type ip -vlnv digilentinc.com:ip:dvi2rgb:2.0 dvi2rgb_0
create_bd_cell -type ip -vlnv xilinx.com:ip:v_axi4s_vid_out:4.0 v_axi4s_vid_out_0
create_bd_cell -type ip -vlnv xilinx.com:ip:v_tc:6.2 v_tc_0
create_bd_cell -type ip -vlnv xilinx.com:ip:v_vid_in_axi4s:5.0 v_vid_in_axi4s_0
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_1
endgroup

startgroup
# Modify Zynq PS Configuration
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]
set_property CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {200} [get_bd_cells processing_system7_0]

# Modify xclcontant_0
set_property CONFIG.CONST_VAL {0} [get_bd_cells xlconstant_0]

# Modify xclcontant_1
set_property CONFIG.CONST_VAL {1} [get_bd_cells xlconstant_1]

# Modify the PL clocking wizard IP
startgroup
set_property -dict [list \
  CONFIG.CLKOUT1_JITTER {109.241} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200.000} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {5.000} \
] [get_bd_cells clk_wiz_0]
endgroup

# Modify Timing Controller
set_property -dict [list \
  CONFIG.HAS_AXI4_LITE {false} \
  CONFIG.auto_generation_mode {true} \
] [get_bd_cells v_tc_0]
endgroup

# Connect Signals
startgroup
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK]
connect_bd_net [get_bd_pins rgb2dvi_0/PixelClk] [get_bd_pins v_axi4s_vid_out_0/aclk]
connect_bd_net [get_bd_pins v_tc_0/clk] [get_bd_pins rgb2dvi_0/PixelClk]
connect_bd_net [get_bd_pins v_vid_in_axi4s_0/aclk] [get_bd_pins rgb2dvi_0/PixelClk]
connect_bd_net [get_bd_pins dvi2rgb_0/PixelClk] [get_bd_pins rgb2dvi_0/PixelClk]
connect_bd_net [get_bd_pins v_tc_0/gen_clken] [get_bd_pins v_axi4s_vid_out_0/vtg_ce]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins dvi2rgb_0/RefClk]
connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins clk_wiz_0/reset]

connect_bd_intf_net [get_bd_intf_pins dvi2rgb_0/RGB] [get_bd_intf_pins v_vid_in_axi4s_0/vid_io_in]
connect_bd_intf_net [get_bd_intf_pins v_vid_in_axi4s_0/vtiming_out] [get_bd_intf_pins v_tc_0/vtiming_in]
connect_bd_intf_net [get_bd_intf_pins v_axi4s_vid_out_0/video_in] [get_bd_intf_pins v_vid_in_axi4s_0/video_out]
connect_bd_intf_net [get_bd_intf_pins v_axi4s_vid_out_0/vid_io_out] [get_bd_intf_pins rgb2dvi_0/RGB]
connect_bd_intf_net [get_bd_intf_pins v_tc_0/vtiming_out] [get_bd_intf_pins v_axi4s_vid_out_0/vtiming_in]
endgroup

# Make external ports
startgroup
make_bd_pins_external  [get_bd_pins clk_wiz_0/clk_in1]
set_property name sys_clock [get_bd_ports clk_in1_0]
set_property CONFIG.PHASE 0.0 [get_bd_ports sys_clock]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_ports sys_clock]

make_bd_intf_pins_external  [get_bd_intf_pins dvi2rgb_0/DDC]
set_property name hdmi_rx_ddc [get_bd_intf_ports DDC_0]

make_bd_intf_pins_external  [get_bd_intf_pins dvi2rgb_0/TMDS]
set_property name hdmi_rx [get_bd_intf_ports TMDS_0]

make_bd_intf_pins_external  [get_bd_intf_pins rgb2dvi_0/TMDS]
set_property name hdmi_tx [get_bd_intf_ports TMDS_0]

make_bd_pins_external  [get_bd_pins xlconstant_1/dout]
set_property name hdmi_rx_hpd [get_bd_ports dout_0]
endgroup

save_bd_design
close_bd_design [get_bd_designs system]

add_files -norecurse $scriptPath/../src/system_wrapper.v
add_files -fileset constrs_1 -norecurse $scriptPath/../constr/PYNQ-Z1_C.xdc

launch_runs impl_1 -to_step write_bitstream -jobs 19