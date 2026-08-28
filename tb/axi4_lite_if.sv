//============================================================
// File    : axi4_lite_if.sv
// Project : AXI4-Lite Project
// Purpose : SystemVerilog Interface for AXI4-Lite protocol
//           Defines all 5 channels with modports for:
//             - Master (initiator)
//             - Slave  (target)
//             - Monitor (passive observer)
//============================================================

`timescale 1ns/1ps

interface axi4_lite_if #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input logic ACLK,
    input logic ARESETn
);

    //----------------------------------------------------------
    // WRITE ADDRESS CHANNEL (AW)
    //----------------------------------------------------------
    logic                    AWVALID;
    logic                    AWREADY;
    logic [ADDR_WIDTH-1:0]   AWADDR;
    logic [2:0]              AWPROT;

    //----------------------------------------------------------
    // WRITE DATA CHANNEL (W)
    //----------------------------------------------------------
    logic                    WVALID;
    logic                    WREADY;
    logic [DATA_WIDTH-1:0]   WDATA;
    logic [DATA_WIDTH/8-1:0] WSTRB;

    //----------------------------------------------------------
    // WRITE RESPONSE CHANNEL (B)
    //----------------------------------------------------------
    logic                    BVALID;
    logic                    BREADY;
    logic [1:0]              BRESP;

    //----------------------------------------------------------
    // READ ADDRESS CHANNEL (AR)
    //----------------------------------------------------------
    logic                    ARVALID;
    logic                    ARREADY;
    logic [ADDR_WIDTH-1:0]   ARADDR;
    logic [2:0]              ARPROT;

    //----------------------------------------------------------
    // READ DATA CHANNEL (R)
    //----------------------------------------------------------
    logic                    RVALID;
    logic                    RREADY;
    logic [DATA_WIDTH-1:0]   RDATA;
    logic [1:0]              RRESP;

    //==========================================================
    // MODPORT : MASTER
    // The master drives address/data channels and receives resp
    //==========================================================
    modport master (
        input  ACLK, ARESETn,
        // AW
        output AWVALID, AWADDR, AWPROT,
        input  AWREADY,
        // W
        output WVALID, WDATA, WSTRB,
        input  WREADY,
        // B
        input  BVALID, BRESP,
        output BREADY,
        // AR
        output ARVALID, ARADDR, ARPROT,
        input  ARREADY,
        // R
        input  RVALID, RDATA, RRESP,
        output RREADY
    );

    //==========================================================
    // MODPORT : SLAVE
    // The slave receives address/data and drives responses
    //==========================================================
    modport slave (
        input  ACLK, ARESETn,
        // AW
        input  AWVALID, AWADDR, AWPROT,
        output AWREADY,
        // W
        input  WVALID, WDATA, WSTRB,
        output WREADY,
        // B
        output BVALID, BRESP,
        input  BREADY,
        // AR
        input  ARVALID, ARADDR, ARPROT,
        output ARREADY,
        // R
        output RVALID, RDATA, RRESP,
        input  RREADY
    );

    //==========================================================
    // MODPORT : MONITOR
    // Passive - can only observe, never drive
    //==========================================================
    modport monitor (
        input  ACLK, ARESETn,
        input  AWVALID, AWREADY, AWADDR, AWPROT,
        input  WVALID,  WREADY,  WDATA,  WSTRB,
        input  BVALID,  BREADY,  BRESP,
        input  ARVALID, ARREADY, ARADDR, ARPROT,
        input  RVALID,  RREADY,  RDATA,  RRESP
    );

    //==========================================================
    // PROTOCOL ASSERTIONS (SVA)
    //==========================================================

    // AXI Rule: VALID must not de-assert without a READY handshake
    property p_awvalid_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        (AWVALID && !AWREADY) |=> AWVALID;
    endproperty

    property p_wvalid_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        (WVALID && !WREADY) |=> WVALID;
    endproperty

    property p_arvalid_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        (ARVALID && !ARREADY) |=> ARVALID;
    endproperty

    // AXI Rule: Address must be stable while AWVALID is high
    property p_awaddr_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        (AWVALID && !AWREADY) |=> $stable(AWADDR);
    endproperty

    // AXI Rule: WDATA/WSTRB must be stable while WVALID is high
    property p_wdata_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        (WVALID && !WREADY) |=> $stable(WDATA);
    endproperty

    // AXI Rule: BVALID must not de-assert without BREADY
    property p_bvalid_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        (BVALID && !BREADY) |=> BVALID;
    endproperty

    // AXI Rule: RVALID must not de-assert without RREADY
    property p_rvalid_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        (RVALID && !RREADY) |=> RVALID;
    endproperty

    // Assert all properties
    assert property (p_awvalid_stable) else $error("AXI VIOLATION: AWVALID dropped without AWREADY handshake");
    assert property (p_wvalid_stable)  else $error("AXI VIOLATION: WVALID dropped without WREADY handshake");
    assert property (p_arvalid_stable) else $error("AXI VIOLATION: ARVALID dropped without ARREADY handshake");
    assert property (p_awaddr_stable)  else $error("AXI VIOLATION: AWADDR changed while AWVALID high");
    assert property (p_wdata_stable)   else $error("AXI VIOLATION: WDATA changed while WVALID high");
    assert property (p_bvalid_stable)  else $error("AXI VIOLATION: BVALID dropped without BREADY handshake");
    assert property (p_rvalid_stable)  else $error("AXI VIOLATION: RVALID dropped without RREADY handshake");

endinterface : axi4_lite_if
