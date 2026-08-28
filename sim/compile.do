#=============================================================
# File    : compile.do
# Project : AXI4-Lite — Phase 2 (UVM Infrastructure)
# Usage   : From sim/ directory in Questa:  do compile.do
#=============================================================

# ---- Local ini fix (shared server permission workaround) ----
if {![file exists questa.ini]} { vmap -c }
set env(MODELSIM) [file normalize "./questa.ini"]

# ---- Clean and recreate work library ----
if {[file exists work]} {
    vdel -modelsimini questa.ini -lib work -all
}
vlib work
vmap -modelsimini questa.ini work work

# ---- 1. Interface ----
puts "\n--- Compiling Interface ---"
vlog -sv -work work +acc \
     -timescale "1ns/1ps" \
     ../tb/axi4_lite_if.sv

# ---- 2. UVM Package ----
# +incdir+../uvm lets `include directives inside the
# package find the class files by filename only
puts "\n--- Compiling UVM Package ---"
vlog -sv -work work +acc \
     -timescale "1ns/1ps" \
     +incdir+../uvm \
     ../uvm/axi4_lite_pkg.sv

# ---- 3. RTL DUT ----
puts "\n--- Compiling RTL ---"
vlog -sv -work work +acc \
     -timescale "1ns/1ps" \
     ../rtl/axi4_lite_slave.sv

# ---- 4. UVM Testbench Top ----
puts "\n--- Compiling UVM TB Top ---"
vlog -sv -work work +acc \
     -timescale "1ns/1ps" \
     +incdir+../uvm \
     ../tb/tb_top_uvm.sv

# ---- 5. Simulate ----
puts "\n--- Launching Simulation ---"
vsim -modelsimini questa.ini \
     -sv_seed random \
     -t 1ns \
     +UVM_TESTNAME=axi4_lite_full_test \
     +UVM_VERBOSITY=UVM_MEDIUM \
     work.tb_top_uvm

# ============================================================
# Waveform Setup
# ============================================================
add wave -divider "=== CLOCK & RESET ==="
add wave -color cyan /tb_top_uvm/ACLK
add wave -color cyan /tb_top_uvm/ARESETn

add wave -divider "=== WRITE ADDRESS (AW) ==="
add wave -color yellow /tb_top_uvm/axi_if/AWVALID
add wave -color yellow /tb_top_uvm/axi_if/AWREADY
add wave -color yellow -hex /tb_top_uvm/axi_if/AWADDR
add wave -color yellow /tb_top_uvm/axi_if/AWPROT

add wave -divider "=== WRITE DATA (W) ==="
add wave -color orange /tb_top_uvm/axi_if/WVALID
add wave -color orange /tb_top_uvm/axi_if/WREADY
add wave -color orange -hex /tb_top_uvm/axi_if/WDATA
add wave -color orange -hex /tb_top_uvm/axi_if/WSTRB

add wave -divider "=== WRITE RESPONSE (B) ==="
add wave -color magenta /tb_top_uvm/axi_if/BVALID
add wave -color magenta /tb_top_uvm/axi_if/BREADY
add wave -color magenta /tb_top_uvm/axi_if/BRESP

add wave -divider "=== READ ADDRESS (AR) ==="
add wave -color green /tb_top_uvm/axi_if/ARVALID
add wave -color green /tb_top_uvm/axi_if/ARREADY
add wave -color green -hex /tb_top_uvm/axi_if/ARADDR
add wave -color green /tb_top_uvm/axi_if/ARPROT

add wave -divider "=== READ DATA (R) ==="
add wave -color lime /tb_top_uvm/axi_if/RVALID
add wave -color lime /tb_top_uvm/axi_if/RREADY
add wave -color lime -hex /tb_top_uvm/axi_if/RDATA
add wave -color lime /tb_top_uvm/axi_if/RRESP

add wave -divider "=== DUT INTERNALS ==="
add wave -color white /tb_top_uvm/dut/wr_state
add wave -color white /tb_top_uvm/dut/rd_state
add wave -color white -hex /tb_top_uvm/dut/wr_addr_lat
add wave -color white -hex /tb_top_uvm/dut/wr_data_lat
add wave -color white /tb_top_uvm/dut/wr_addr_valid
add wave -color white /tb_top_uvm/dut/rd_addr_valid

add wave -divider "=== REGISTER FILE ==="
add wave -color gold -hex /tb_top_uvm/dut/dbg_reg

# ---- Run ----
configure wave -namecolwidth 320
configure wave -valuecolwidth 150
run -all
wave zoom full
