//============================================================
// File    : axi4_lite_top.sv
// Project : AXI4-Lite Project — Phase 4
// Purpose : Top-level integration connecting:
//             - AXI4-Lite Master (initiator)
//             - AXI4-Lite Slave  (register file target)
//
// The Master and Slave are connected via the AXI4-Lite
// interface. The top level exposes:
//   - The command interface (for testbench to drive)
//   - Clock and reset
//
//   cmd_if -> Master -> [AXI4-Lite Bus] -> Slave
//                                               (16 regs)
//============================================================

`timescale 1ns/1ps

module axi4_lite_top #(
    parameter int DATA_WIDTH     = 32,
    parameter int ADDR_WIDTH     = 32,
    parameter int NUM_REGS       = 16,
    parameter int TIMEOUT_CYCLES = 256
)(
    // Global
    input  logic                      ACLK,
    input  logic                      ARESETn,

    // Command Interface (testbench drives here)
    input  logic                      cmd_valid,
    output logic                      cmd_ready,
    input  logic                      cmd_write,
    input  logic [ADDR_WIDTH-1:0]     cmd_addr,
    input  logic [DATA_WIDTH-1:0]     cmd_wdata,
    input  logic [DATA_WIDTH/8-1:0]   cmd_wstrb,
    input  logic [2:0]                cmd_prot,

    // Response Interface (testbench reads here)
    output logic                      rsp_valid,
    input  logic                      rsp_ready,
    output logic [DATA_WIDTH-1:0]     rsp_rdata,
    output logic [1:0]                rsp_resp,
    output logic                      rsp_error,
    output logic                      rsp_timeout
);

    //==========================================================
    // Internal AXI4-Lite Bus Signals
    // (connecting Master outputs to Slave inputs)
    //==========================================================
    // Write Address Channel
    logic                    awvalid;
    logic                    awready;
    logic [ADDR_WIDTH-1:0]   awaddr;
    logic [2:0]              awprot;

    // Write Data Channel
    logic                    wvalid;
    logic                    wready;
    logic [DATA_WIDTH-1:0]   wdata;
    logic [DATA_WIDTH/8-1:0] wstrb;

    // Write Response Channel
    logic                    bvalid;
    logic                    bready;
    logic [1:0]              bresp;

    // Read Address Channel
    logic                    arvalid;
    logic                    arready;
    logic [ADDR_WIDTH-1:0]   araddr;
    logic [2:0]              arprot;

    // Read Data Channel
    logic                    rvalid;
    logic                    rready;
    logic [DATA_WIDTH-1:0]   rdata;
    logic [1:0]              rresp;

    //==========================================================
    // AXI4-Lite Master Instance
    //==========================================================
    axi4_lite_master #(
        .DATA_WIDTH     (DATA_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .TIMEOUT_CYCLES (TIMEOUT_CYCLES)
    ) u_master (
        .ACLK       (ACLK),
        .ARESETn    (ARESETn),
        // Command interface
        .cmd_valid  (cmd_valid),
        .cmd_ready  (cmd_ready),
        .cmd_write  (cmd_write),
        .cmd_addr   (cmd_addr),
        .cmd_wdata  (cmd_wdata),
        .cmd_wstrb  (cmd_wstrb),
        .cmd_prot   (cmd_prot),
        // Response interface
        .rsp_valid  (rsp_valid),
        .rsp_ready  (rsp_ready),
        .rsp_rdata  (rsp_rdata),
        .rsp_resp   (rsp_resp),
        .rsp_error  (rsp_error),
        .rsp_timeout(rsp_timeout),
        // AXI4-Lite outputs
        .AWVALID    (awvalid),  .AWREADY (awready),
        .AWADDR     (awaddr),   .AWPROT  (awprot),
        .WVALID     (wvalid),   .WREADY  (wready),
        .WDATA      (wdata),    .WSTRB   (wstrb),
        .BVALID     (bvalid),   .BREADY  (bready),
        .BRESP      (bresp),
        .ARVALID    (arvalid),  .ARREADY (arready),
        .ARADDR     (araddr),   .ARPROT  (arprot),
        .RVALID     (rvalid),   .RREADY  (rready),
        .RDATA      (rdata),    .RRESP   (rresp)
    );

    //==========================================================
    // AXI4-Lite Slave Instance
    //==========================================================
    axi4_lite_slave #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .NUM_REGS   (NUM_REGS)
    ) u_slave (
        .ACLK    (ACLK),
        .ARESETn (ARESETn),
        // AXI4-Lite inputs (from master)
        .AWVALID (awvalid),  .AWREADY (awready),
        .AWADDR  (awaddr),   .AWPROT  (awprot),
        .WVALID  (wvalid),   .WREADY  (wready),
        .WDATA   (wdata),    .WSTRB   (wstrb),
        .BVALID  (bvalid),   .BREADY  (bready),
        .BRESP   (bresp),
        .ARVALID (arvalid),  .ARREADY (arready),
        .ARADDR  (araddr),   .ARPROT  (arprot),
        .RVALID  (rvalid),   .RREADY  (rready),
        .RDATA   (rdata),    .RRESP   (rresp)
    );

endmodule : axi4_lite_top
