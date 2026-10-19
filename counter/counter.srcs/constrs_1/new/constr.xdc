## External reset (active-low)
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} \
    [get_ports {reset_rtl}]

## System clock (100 MHz)
set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS33} \
    [get_ports {sys_clock}]
create_clock -add -name sys_clk_pin -period 10.000 \
    -waveform {0.000 5.000} [get_ports {sys_clock}]

## Frequency counter input
set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS33} \
    [get_ports {sig_in_0}]
    
