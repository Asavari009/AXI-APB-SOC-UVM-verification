#=============================================================
# File    : compile_slave_directed.do
# Purpose : Phase 1 — AXI4-Lite Slave directed testbench
#=============================================================
if {![file exists questa.ini]} { vmap -c }
set env(MODELSIM) [file normalize "./questa.ini"]
if {[file exists work]} { vdel -modelsimini questa.ini -lib work -all }
vlib work
vmap -modelsimini questa.ini work work

vlog -sv -work work +acc -timescale "1ns/1ps" ../tb/axi4_lite_if.sv
vlog -sv -work work +acc -timescale "1ns/1ps" ../rtl/axi4_lite_slave.sv
vlog -sv -work work +acc -timescale "1ns/1ps" ../tb/tb_top.sv

vsim -modelsimini questa.ini -sv_seed random -t 1ns work.tb_top

add wave -divider "=== CLOCK & RESET ==="
add wave /tb_top/ACLK
add wave /tb_top/ARESETn
add wave -divider "=== AXI WRITE ==="
add wave /tb_top/axi_if/AWVALID
add wave /tb_top/axi_if/AWREADY
add wave -hex /tb_top/axi_if/AWADDR
add wave /tb_top/axi_if/WVALID
add wave /tb_top/axi_if/WREADY
add wave -hex /tb_top/axi_if/WDATA
add wave /tb_top/axi_if/BVALID
add wave /tb_top/axi_if/BREADY
add wave /tb_top/axi_if/BRESP
add wave -divider "=== AXI READ ==="
add wave /tb_top/axi_if/ARVALID
add wave /tb_top/axi_if/ARREADY
add wave -hex /tb_top/axi_if/ARADDR
add wave /tb_top/axi_if/RVALID
add wave /tb_top/axi_if/RREADY
add wave -hex /tb_top/axi_if/RDATA
add wave -divider "=== REGISTER FILE ==="
add wave -hex /tb_top/dut/dbg_reg

configure wave -namecolwidth 300
configure wave -valuecolwidth 150
run -all
wave zoom full
