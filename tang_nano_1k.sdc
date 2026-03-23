# =============================================================
# tang_nano_1k.sdc  —  Timing Constraint (SDC format)
# Clock: 27 MHz onboard oscillator
# IP synthesis Fmax: 120 MHz → 27 MHz có timing slack rất lớn
# =============================================================

# Tạo clock 27 MHz trên pin clk
create_clock -name clk -period 37.037 [get_ports {clk}]

# False path cho input button (debounce xử lý bằng RTL, không cần timing)
set_false_path -from [get_ports {btn}]

# False path cho LED output (combinational latch → IO, không critical)
set_false_path -to [get_ports {led_r}]
set_false_path -to [get_ports {led_g}]
