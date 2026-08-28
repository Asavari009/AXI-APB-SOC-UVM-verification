//============================================================
// File    : tb_top_system_uvm.sv
// Project : System UVM Testbench — Phase 6
// Purpose : UVM testbench top for the full system.
//           Instantiates system_top DUT and two interfaces:
//             - axi4_lite_cmd_if : driven by cmd_driver
//             - apb_if           : observed by apb_monitor
//============================================================

`timescale 1ns/1ps

module tb_top_system_uvm;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import system_pkg::*;

    localparam int DATA_WIDTH     = 32;
    localparam int ADDR_WIDTH     = 32;
    localparam int NUM_REGS       = 16;
    localparam int CLK_PERIOD     = 10;
    localparam int TIMEOUT_CYCLES = 256;
    localparam int WAIT_STATES    = 2;

    //----------------------------------------------------------
    // Clock and Reset
    //----------------------------------------------------------
    logic ACLK    = 0;
    logic ARESETn = 0;

    always #(CLK_PERIOD/2) ACLK = ~ACLK;

    //----------------------------------------------------------
    // Interface 1: Command Interface (drives Master)
    //----------------------------------------------------------
    axi4_lite_cmd_if #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) cmd_if (
        .ACLK    (ACLK),
        .ARESETn (ARESETn)
    );

    //----------------------------------------------------------
    // Interface 2: APB Interface (observes Bridge→Slave bus)
    //----------------------------------------------------------
    apb_if #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) apb_bif (
        .PCLK    (ACLK),
        .PRESETn (ARESETn)
    );

    //----------------------------------------------------------
    // DUT: Full System (Master + Bridge + APB Slave)
    //----------------------------------------------------------
    system_top #(
        .DATA_WIDTH     (DATA_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .NUM_REGS       (NUM_REGS),
        .TIMEOUT_CYCLES (TIMEOUT_CYCLES),
        .WAIT_STATES    (WAIT_STATES)
    ) dut (
        .ACLK        (ACLK),
        .ARESETn     (ARESETn),
        // Command interface wired to cmd_if
        .cmd_valid   (cmd_if.cmd_valid),
        .cmd_ready   (cmd_if.cmd_ready),
        .cmd_write   (cmd_if.cmd_write),
        .cmd_addr    (cmd_if.cmd_addr),
        .cmd_wdata   (cmd_if.cmd_wdata),
        .cmd_wstrb   (cmd_if.cmd_wstrb),
        .cmd_prot    (cmd_if.cmd_prot),
        // Response interface wired to cmd_if
        .rsp_valid   (cmd_if.rsp_valid),
        .rsp_ready   (cmd_if.rsp_ready),
        .rsp_rdata   (cmd_if.rsp_rdata),
        .rsp_resp    (cmd_if.rsp_resp),
        .rsp_error   (cmd_if.rsp_error),
        .rsp_timeout (cmd_if.rsp_timeout)
    );

    //----------------------------------------------------------
    // Connect APB interface to DUT internal APB bus
    // These are observation-only (no driving from TB side)
    //----------------------------------------------------------
    assign apb_bif.PSEL    = dut.psel;
    assign apb_bif.PENABLE = dut.penable;
    assign apb_bif.PADDR   = dut.paddr;
    assign apb_bif.PWRITE  = dut.pwrite;
    assign apb_bif.PWDATA  = dut.pwdata;
    assign apb_bif.PSTRB   = dut.pstrb;
    assign apb_bif.PPROT   = dut.pprot;
    assign apb_bif.PREADY  = dut.pready;
    assign apb_bif.PRDATA  = dut.prdata;
    assign apb_bif.PSLVERR = dut.pslverr;

    //----------------------------------------------------------
    // UVM Setup
    //----------------------------------------------------------
    initial begin
        // Register BOTH virtual interfaces in config_db
        uvm_config_db #(virtual axi4_lite_cmd_if)::set(
            null, "uvm_test_top.*", "cmd_vif", cmd_if);

        uvm_config_db #(virtual apb_if)::set(
            null, "uvm_test_top.*", "apb_vif", apb_bif);

        // Launch UVM test (name from +UVM_TESTNAME)
        run_test();
    end

    //----------------------------------------------------------
    // Reset sequence — runs concurrently with UVM
    //----------------------------------------------------------
    initial begin
        ARESETn = 1'b0;
        repeat(5) @(posedge ACLK);
        ARESETn = 1'b1;
    end

    //----------------------------------------------------------
    // Timeout watchdog
    //----------------------------------------------------------
    initial begin
        #2_000_000;
        `uvm_fatal("TIMEOUT", "Simulation exceeded 2ms")
    end

endmodule : tb_top_system_uvm
