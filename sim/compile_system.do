#=============================================================
# File    : compile_system.do
# Project : Full System — Master + Bridge + APB Slave
# Usage   : do compile_system.do
#=============================================================

# ---- Local ini fix ----
if {![file exists questa.ini]} { vmap -c }
set env(MODELSIM) [file normalize "./questa.ini"]

if {[file exists work]} {
    vdel -modelsimini questa.ini -lib work -all
}
vlib work
vmap -modelsimini questa.ini work work

# ---- 1. Interfaces ----
puts "\n--- Compiling Interfaces ---"
vlog -sv -work work +acc -timescale "1ns/1ps" ../tb/axi4_lite_if.sv
vlog -sv -work work +acc -timescale "1ns/1ps" ../tb/apb_if.sv
vlog -sv -work work +acc -timescale "1ns/1ps" ../tb/axi4_lite_cmd_if.sv

# ---- 2. RTL ----
puts "\n--- Compiling RTL ---"
vlog -sv -work work +acc -timescale "1ns/1ps" ../rtl/axi4_lite_slave.sv
vlog -sv -work work +acc -timescale "1ns/1ps" ../rtl/axi4_lite_master.sv
vlog -sv -work work +acc -timescale "1ns/1ps" ../rtl/axi4_lite_to_apb.sv
vlog -sv -work work +acc -timescale "1ns/1ps" ../rtl/apb_slave.sv
vlog -sv -work work +acc -timescale "1ns/1ps" ../rtl/system_top.sv

# ---- 3. Testbench ----
puts "\n--- Compiling Testbench ---"
vlog -sv -work work +acc -timescale "1ns/1ps" ../tb/tb_top_system.sv

# ---- 4. Simulate ----
puts "\n--- Launching Simulation ---"
vsim -modelsimini questa.ini \
     -sv_seed random \
     -t 1ns \
     work.tb_top_system

# ---- Waveform Setup ----
add wave -divider "=== CLOCK & RESET ==="
add wave -color cyan /tb_top_system/ACLK
add wave -color cyan /tb_top_system/ARESETn

add wave -divider "=== COMMAND INTERFACE ==="
add wave -color yellow /tb_top_system/cmd_valid
add wave -color yellow /tb_top_system/cmd_ready
add wave -color yellow /tb_top_system/cmd_write
add wave -color yellow -hex /tb_top_system/cmd_addr
add wave -color yellow -hex /tb_top_system/cmd_wdata

add wave -divider "=== RESPONSE INTERFACE ==="
add wave -color lime /tb_top_system/rsp_valid
add wave -color lime /tb_top_system/rsp_ready
add wave -color lime -hex /tb_top_system/rsp_rdata
add wave -color lime /tb_top_system/rsp_error

add wave -divider "=== AXI4-LITE BUS (Master→Bridge) ==="
add wave -color orange /tb_top_system/dut/awvalid
add wave -color orange /tb_top_system/dut/awready
add wave -color orange -hex /tb_top_system/dut/awaddr
add wave -color orange /tb_top_system/dut/wvalid
add wave -color orange /tb_top_system/dut/wready
add wave -color orange -hex /tb_top_system/dut/wdata
add wave -color magenta /tb_top_system/dut/bvalid
add wave -color magenta /tb_top_system/dut/bready
add wave -color magenta /tb_top_system/dut/bresp
add wave -color green /tb_top_system/dut/arvalid
add wave -color green /tb_top_system/dut/arready
add wave -color lime /tb_top_system/dut/rvalid
add wave -color lime /tb_top_system/dut/rready
add wave -color lime -hex /tb_top_system/dut/rdata

add wave -divider "=== BRIDGE INTERNALS ==="
add wave -color white /tb_top_system/dut/u_bridge/state
add wave -color white /tb_top_system/dut/u_bridge/is_write
add wave -color white -hex /tb_top_system/dut/u_bridge/lat_addr
add wave -color white -hex /tb_top_system/dut/u_bridge/lat_wdata

add wave -divider "=== APB BUS (Bridge→Slave) ==="
add wave -color gold /tb_top_system/dut/psel
add wave -color gold /tb_top_system/dut/penable
add wave -color gold /tb_top_system/dut/pwrite
add wave -color gold -hex /tb_top_system/dut/paddr
add wave -color gold -hex /tb_top_system/dut/pwdata
add wave -color gold /tb_top_system/dut/pready
add wave -color gold -hex /tb_top_system/dut/prdata
add wave -color gold /tb_top_system/dut/pslverr

add wave -divider "=== APB SLAVE REGISTER FILE ==="
add wave -color cyan -hex /tb_top_system/dut/u_apb_slave/dbg_reg

# ---- Run ----
configure wave -namecolwidth 380
configure wave -valuecolwidth 150
run -all
wave zoom full
