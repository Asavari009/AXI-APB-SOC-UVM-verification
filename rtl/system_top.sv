//============================================================
// File    : system_top.sv
// Project : AXI4-Lite to APB Bridge — Phase 5
// Purpose : Full system integration:
//
//   cmd_if -> AXI4-Lite Master -> AXI4-Lite to APB Bridge -> APB Slave
//
// Parameters:
//   DATA_WIDTH     — data bus width (32)
//   ADDR_WIDTH     — address width (32)
//   NUM_REGS       — APB slave register count (16)
//   TIMEOUT_CYCLES — master watchdog threshold
//   WAIT_STATES    — APB slave wait states (0=no wait)
//============================================================

`timescale 1ns/1ps

module system_top #(
    parameter int DATA_WIDTH     = 32,
    parameter int ADDR_WIDTH     = 32,
    parameter int NUM_REGS       = 16,
    parameter int TIMEOUT_CYCLES = 256,
    parameter int WAIT_STATES    = 0
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

    // Response Interface
    output logic                      rsp_valid,
    input  logic                      rsp_ready,
    output logic [DATA_WIDTH-1:0]     rsp_rdata,
    output logic [1:0]                rsp_resp,
    output logic                      rsp_error,
    output logic                      rsp_timeout
);

    //==========================================================
    // AXI4-Lite Internal Bus (Master -> Bridge)
    //==========================================================
    logic                    awvalid, awready;
    logic [ADDR_WIDTH-1:0]   awaddr;
    logic [2:0]              awprot;

    logic                    wvalid, wready;
    logic [DATA_WIDTH-1:0]   wdata;
    logic [DATA_WIDTH/8-1:0] wstrb;

    logic                    bvalid, bready;
    logic [1:0]              bresp;

    logic                    arvalid, arready;
    logic [ADDR_WIDTH-1:0]   araddr;
    logic [2:0]              arprot;

    logic                    rvalid, rready;
    logic [DATA_WIDTH-1:0]   rdata;
    logic [1:0]              rresp;

    //==========================================================
    // APB Internal Bus (Bridge -> Slave)
    //==========================================================
    logic                    psel, penable;
    logic [ADDR_WIDTH-1:0]   paddr;
    logic                    pwrite;
    logic [DATA_WIDTH-1:0]   pwdata;
    logic [DATA_WIDTH/8-1:0] pstrb;
    logic [2:0]              pprot;

    logic                    pready;
    logic [DATA_WIDTH-1:0]   prdata;
    logic                    pslverr;

    //==========================================================
    // AXI4-Lite Master
    //==========================================================
    axi4_lite_master #(
        .DATA_WIDTH     (DATA_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .TIMEOUT_CYCLES (TIMEOUT_CYCLES)
    ) u_master (
        .ACLK        (ACLK),
        .ARESETn     (ARESETn),
        // Command interface
        .cmd_valid   (cmd_valid),
        .cmd_ready   (cmd_ready),
        .cmd_write   (cmd_write),
        .cmd_addr    (cmd_addr),
        .cmd_wdata   (cmd_wdata),
        .cmd_wstrb   (cmd_wstrb),
        .cmd_prot    (cmd_prot),
        // Response interface
        .rsp_valid   (rsp_valid),
        .rsp_ready   (rsp_ready),
        .rsp_rdata   (rsp_rdata),
        .rsp_resp    (rsp_resp),
        .rsp_error   (rsp_error),
        .rsp_timeout (rsp_timeout),
        // AXI4-Lite bus
        .AWVALID (awvalid), .AWREADY (awready),
        .AWADDR  (awaddr),  .AWPROT  (awprot),
        .WVALID  (wvalid),  .WREADY  (wready),
        .WDATA   (wdata),   .WSTRB   (wstrb),
        .BVALID  (bvalid),  .BREADY  (bready),
        .BRESP   (bresp),
        .ARVALID (arvalid), .ARREADY (arready),
        .ARADDR  (araddr),  .ARPROT  (arprot),
        .RVALID  (rvalid),  .RREADY  (rready),
        .RDATA   (rdata),   .RRESP   (rresp)
    );

    //==========================================================
    // AXI4-Lite to APB Bridge
    //==========================================================
    axi4_lite_to_apb #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_bridge (
        .ACLK    (ACLK),
        .ARESETn (ARESETn),
        // AXI4-Lite slave side
        .AWVALID (awvalid), .AWREADY (awready),
        .AWADDR  (awaddr),  .AWPROT  (awprot),
        .WVALID  (wvalid),  .WREADY  (wready),
        .WDATA   (wdata),   .WSTRB   (wstrb),
        .BVALID  (bvalid),  .BREADY  (bready),
        .BRESP   (bresp),
        .ARVALID (arvalid), .ARREADY (arready),
        .ARADDR  (araddr),  .ARPROT  (arprot),
        .RVALID  (rvalid),  .RREADY  (rready),
        .RDATA   (rdata),   .RRESP   (rresp),
        // APB master side
        .PSEL    (psel),    .PENABLE (penable),
        .PADDR   (paddr),   .PWRITE  (pwrite),
        .PWDATA  (pwdata),  .PSTRB   (pstrb),
        .PPROT   (pprot),
        .PREADY  (pready),  .PRDATA  (prdata),
        .PSLVERR (pslverr)
    );

    //==========================================================
    // APB Slave (register file peripheral)
    //==========================================================
    apb_slave #(
        .DATA_WIDTH  (DATA_WIDTH),
        .ADDR_WIDTH  (ADDR_WIDTH),
        .NUM_REGS    (NUM_REGS),
        .WAIT_STATES (WAIT_STATES)
    ) u_apb_slave (
        .PCLK    (ACLK),
        .PRESETn (ARESETn),
        .PSEL    (psel),
        .PENABLE (penable),
        .PADDR   (paddr),
        .PWRITE  (pwrite),
        .PWDATA  (pwdata),
        .PSTRB   (pstrb),
        .PPROT   (pprot),
        .PREADY  (pready),
        .PRDATA  (prdata),
        .PSLVERR (pslverr)
    );

endmodule : system_top
