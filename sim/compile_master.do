#=============================================================
# File    : compile_master.do
# Project : AXI4-Lite Phase 4 — Master + Slave directed TB
# Usage   : do compile_master.do
#=============================================================

# ---- Local ini fix ----
if {![file exists questa.ini]} { vmap -c }
set env(MODELSIM) [file normalize "./questa.ini"]

if {[file exists work]} {
    vdel -modelsimini questa.ini -lib work -all
}
vlib work
vmap -modelsimini questa.ini work work

# ---- 1. Interface files ----
puts "\n--- Compiling Interfaces ---"
vlog -sv -work work +acc -timescale "1ns/1ps" \
    ../tb/axi4_lite_if.sv

vlog -sv -work work +acc -timescale "1ns/1ps" \
    ../tb/axi4_lite_cmd_if.sv

# ---- 2. RTL files ----
puts "\n--- Compiling RTL ---"
vlog -sv -work work +acc -timescale "1ns/1ps" \
    ../rtl/axi4_lite_slave.sv

vlog -sv -work work +acc -timescale "1ns/1ps" \
    ../rtl/axi4_lite_master.sv

vlog -sv -work work +acc -timescale "1ns/1ps" \
    ../rtl/axi4_lite_top.sv

# ---- 3. Directed Testbench ----
puts "\n--- Compiling Directed Testbench ---"
vlog -sv -work work +acc -timescale "1ns/1ps" \
    ../tb/tb_top_master.sv

# ---- 4. Simulate ----
puts "\n--- Launching Simulation ---"
vsim -modelsimini questa.ini \
     -sv_seed random \
     -t 1ns \
     work.tb_top_master

# ---- Waveform Setup ----
add wave -divider "=== CLOCK & RESET ==="
add wave -color cyan  /tb_top_master/ACLK
add wave -color cyan  /tb_top_master/ARESETn

add wave -divider "=== COMMAND INTERFACE ==="
add wave -color yellow /tb_top_master/cmd_valid
add wave -color yellow /tb_top_master/cmd_ready
add wave -color yellow /tb_top_master/cmd_write
add wave -color yellow -hex /tb_top_master/cmd_addr
add wave -color yellow -hex /tb_top_master/cmd_wdata
add wave -color yellow -hex /tb_top_master/cmd_wstrb

add wave -divider "=== RESPONSE INTERFACE ==="
add wave -color lime /tb_top_master/rsp_valid
add wave -color lime /tb_top_master/rsp_ready
add wave -color lime -hex /tb_top_master/rsp_rdata
add wave -color lime /tb_top_master/rsp_resp
add wave -color lime /tb_top_master/rsp_error
add wave -color lime /tb_top_master/rsp_timeout

add wave -divider "=== MASTER INTERNALS ==="
add wave -color white /tb_top_master/dut/u_master/state
add wave -color white /tb_top_master/dut/u_master/aw_done
add wave -color white /tb_top_master/dut/u_master/w_done
add wave -color white /tb_top_master/dut/u_master/tmo_cnt

add wave -divider "=== AXI BUS (Master→Slave) ==="
add wave -color orange /tb_top_master/dut/awvalid
add wave -color orange /tb_top_master/dut/awready
add wave -color orange -hex /tb_top_master/dut/awaddr
add wave -color orange /tb_top_master/dut/wvalid
add wave -color orange /tb_top_master/dut/wready
add wave -color orange -hex /tb_top_master/dut/wdata
add wave -color magenta /tb_top_master/dut/bvalid
add wave -color magenta /tb_top_master/dut/bready
add wave -color magenta /tb_top_master/dut/bresp
add wave -color green /tb_top_master/dut/arvalid
add wave -color green /tb_top_master/dut/arready
add wave -color green -hex /tb_top_master/dut/araddr
add wave -color lime /tb_top_master/dut/rvalid
add wave -color lime /tb_top_master/dut/rready
add wave -color lime -hex /tb_top_master/dut/rdata

add wave -divider "=== SLAVE REGISTER FILE ==="
add wave -color gold -hex /tb_top_master/dut/u_slave/dbg_reg

# ---- Run ----
configure wave -namecolwidth 350
configure wave -valuecolwidth 150
run -all
wave zoom full
