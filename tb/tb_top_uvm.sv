//============================================================
// File    : tb_top_uvm.sv
// Project : AXI4-Lite UVM Testbench
//============================================================

`timescale 1ns/1ps

module tb_top_uvm;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi4_lite_pkg::*;

    localparam int DATA_WIDTH = 32;
    localparam int ADDR_WIDTH = 32;
    localparam int NUM_REGS   = 16;
    localparam int CLK_PERIOD = 10;

    //----------------------------------------------------------
    // Clock and Reset
    //----------------------------------------------------------
    logic ACLK    = 0;
    logic ARESETn = 0;

    always #(CLK_PERIOD/2) ACLK = ~ACLK;

    //----------------------------------------------------------
    // AXI4-Lite Interface
    //----------------------------------------------------------
    axi4_lite_if #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) axi_if (
        .ACLK    (ACLK),
        .ARESETn (ARESETn)
    );

    //----------------------------------------------------------
    // DUT
    //----------------------------------------------------------
    axi4_lite_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .NUM_REGS  (NUM_REGS)
    ) dut (
        .ACLK    (ACLK),
        .ARESETn (ARESETn),
        .AWVALID (axi_if.AWVALID),  .AWREADY (axi_if.AWREADY),
        .AWADDR  (axi_if.AWADDR),   .AWPROT  (axi_if.AWPROT),
        .WVALID  (axi_if.WVALID),   .WREADY  (axi_if.WREADY),
        .WDATA   (axi_if.WDATA),    .WSTRB   (axi_if.WSTRB),
        .BVALID  (axi_if.BVALID),   .BREADY  (axi_if.BREADY),
        .BRESP   (axi_if.BRESP),
        .ARVALID (axi_if.ARVALID),  .ARREADY (axi_if.ARREADY),
        .ARADDR  (axi_if.ARADDR),   .ARPROT  (axi_if.ARPROT),
        .RVALID  (axi_if.RVALID),   .RREADY  (axi_if.RREADY),
        .RDATA   (axi_if.RDATA),    .RRESP   (axi_if.RRESP)
    );

    //----------------------------------------------------------
    // Block 1: Register vif and launch UVM at TIME 0
    //----------------------------------------------------------
    initial begin
        uvm_config_db #(virtual axi4_lite_if)::set(
            null,
            "uvm_test_top.*",
            "vif",
            axi_if);
        run_test();   // time 0   UVM takes control
    end

    //----------------------------------------------------------
    // Block 2: Reset sequence   runs CONCURRENTLY with UVM
    //----------------------------------------------------------
    initial begin
        ARESETn = 1'b0;
        repeat(5) @(posedge ACLK);
        ARESETn = 1'b1;
    end

    //----------------------------------------------------------
    // Simulation Timeout Watchdog
    //----------------------------------------------------------
    initial begin
        #500_000;
        `uvm_fatal("TIMEOUT", "Simulation exceeded 500us   possible deadlock")
    end

endmodule : tb_top_uvm