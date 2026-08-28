#=============================================================
# File    : compile_system_uvm.do
# Project : Full System UVM Testbench — Phase 6
# Usage   : do compile_system_uvm.do
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

# ---- 2. System UVM Package ----
puts "\n--- Compiling System UVM Package ---"
vlog -sv -work work +acc -timescale "1ns/1ps" \
     +incdir+../uvm \
     ../uvm/system_pkg.sv

# ---- 3. RTL ----
puts "\n--- Compiling RTL ---"
vlog -sv -work work +acc -timescale "1ns/1ps" ../rtl/axi4_lite_slave.sv
vlog -sv -work work +acc -timescale "1ns/1ps" ../rtl/axi4_lite_master.sv
vlog -sv -work work +acc -timescale "1ns/1ps" ../rtl/axi4_lite_to_apb.sv
vlog -sv -work work +acc -timescale "1ns/1ps" ../rtl/apb_slave.sv
vlog -sv -work work +acc -timescale "1ns/1ps" ../rtl/system_top.sv

# ---- 4. UVM Testbench Top ----
puts "\n--- Compiling UVM TB Top ---"
vlog -sv -work work +acc -timescale "1ns/1ps" \
     +incdir+../uvm \
     ../tb/tb_top_system_uvm.sv

# ---- 5. Simulate ----
puts "\n--- Launching Simulation ---"
vsim -modelsimini questa.ini \
     -sv_seed random \
     -t 1ns \
     +UVM_TESTNAME=system_full_test \
     +UVM_VERBOSITY=UVM_MEDIUM \
     work.tb_top_system_uvm

# ---- Waveform ----
add wave -divider "=== CLOCK & RESET ==="
add wave -color cyan /tb_top_system_uvm/ACLK
add wave -color cyan /tb_top_system_uvm/ARESETn

add wave -divider "=== CMD INTERFACE ==="
add wave -color yellow /tb_top_system_uvm/cmd_if/cmd_valid
add wave -color yellow /tb_top_system_uvm/cmd_if/cmd_ready
add wave -color yellow /tb_top_system_uvm/cmd_if/cmd_write
add wave -color yellow -hex /tb_top_system_uvm/cmd_if/cmd_addr
add wave -color yellow -hex /tb_top_system_uvm/cmd_if/cmd_wdata
add wave -color lime /tb_top_system_uvm/cmd_if/rsp_valid
add wave -color lime /tb_top_system_uvm/cmd_if/rsp_ready
add wave -color lime -hex /tb_top_system_uvm/cmd_if/rsp_rdata
add wave -color lime /tb_top_system_uvm/cmd_if/rsp_error

add wave -divider "=== BRIDGE STATE ==="
add wave -color white /tb_top_system_uvm/dut/u_bridge/state
add wave -color white /tb_top_system_uvm/dut/u_bridge/is_write

add wave -divider "=== APB BUS ==="
add wave -color gold /tb_top_system_uvm/apb_bif/PSEL
add wave -color gold /tb_top_system_uvm/apb_bif/PENABLE
add wave -color gold /tb_top_system_uvm/apb_bif/PWRITE
add wave -color gold -hex /tb_top_system_uvm/apb_bif/PADDR
add wave -color gold -hex /tb_top_system_uvm/apb_bif/PWDATA
add wave -color gold /tb_top_system_uvm/apb_bif/PREADY
add wave -color gold -hex /tb_top_system_uvm/apb_bif/PRDATA
add wave -color gold /tb_top_system_uvm/apb_bif/PSLVERR

add wave -divider "=== APB SLAVE REGISTERS ==="
add wave -color cyan -hex /tb_top_system_uvm/dut/u_apb_slave/dbg_reg

configure wave -namecolwidth 380
configure wave -valuecolwidth 150
run -all
wave zoom full
