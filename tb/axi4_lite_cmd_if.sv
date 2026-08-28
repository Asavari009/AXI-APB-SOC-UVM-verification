//============================================================
// File    : axi4_lite_cmd_if.sv
// Project : AXI4-Lite Project — Phase 4
// Purpose : Command Interface for the AXI4-Lite Master.
//============================================================

`timescale 1ns/1ps

interface axi4_lite_cmd_if #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
)(
    input logic ACLK,
    input logic ARESETn
);

    //----------------------------------------------------------
    // Command Channel (user -> master)
    //----------------------------------------------------------
    logic                      cmd_valid;
    logic                      cmd_ready;
    logic                      cmd_write;
    logic [ADDR_WIDTH-1:0]     cmd_addr;
    logic [DATA_WIDTH-1:0]     cmd_wdata;
    logic [DATA_WIDTH/8-1:0]   cmd_wstrb;
    logic [2:0]                cmd_prot;

    //----------------------------------------------------------
    // Response Channel (master -> user)
    //----------------------------------------------------------
    logic                      rsp_valid;
    logic                      rsp_ready;
    logic [DATA_WIDTH-1:0]     rsp_rdata;
    logic [1:0]                rsp_resp;
    logic                      rsp_error;
    logic                      rsp_timeout;

    //==========================================================
    // MODPORT: Driver (testbench drives commands, accepts responses)
    //==========================================================
    modport driver (
        input  ACLK, ARESETn,
        // Command — driver drives
        output cmd_valid, cmd_write, cmd_addr,
               cmd_wdata, cmd_wstrb, cmd_prot,
        input  cmd_ready,
        // Response — driver receives
        input  rsp_valid, rsp_rdata, rsp_resp,
               rsp_error, rsp_timeout,
        output rsp_ready
    );

    //==========================================================
    // MODPORT: Master RTL (receives commands, sends responses)
    //==========================================================
    modport master (
        input  ACLK, ARESETn,
        // Command — master receives
        input  cmd_valid, cmd_write, cmd_addr,
               cmd_wdata, cmd_wstrb, cmd_prot,
        output cmd_ready,
        // Response — master drives
        output rsp_valid, rsp_rdata, rsp_resp,
               rsp_error, rsp_timeout,
        input  rsp_ready
    );

    //==========================================================
    // MODPORT: Monitor (passive observation only)
    //==========================================================
    modport monitor (
        input  ACLK, ARESETn,
        input  cmd_valid, cmd_ready, cmd_write,
               cmd_addr,  cmd_wdata, cmd_wstrb, cmd_prot,
        input  rsp_valid, rsp_ready, rsp_rdata,
               rsp_resp,  rsp_error, rsp_timeout
    );

    //==========================================================
    // SVA Assertions - Command Interface Protocol Rules
    //==========================================================

    // cmd_valid must not deassert without cmd_ready handshake
    property p_cmd_valid_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        (cmd_valid && !cmd_ready) |=> cmd_valid;
    endproperty

    // cmd_addr must be stable while cmd_valid is high
    property p_cmd_addr_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        (cmd_valid && !cmd_ready) |=> $stable(cmd_addr);
    endproperty

    // cmd_write must be stable while cmd_valid is high
    property p_cmd_write_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        (cmd_valid && !cmd_ready) |=> $stable(cmd_write);
    endproperty

    // rsp_valid must not deassert without rsp_ready handshake
    property p_rsp_valid_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        (rsp_valid && !rsp_ready) |=> rsp_valid;
    endproperty

    // rsp_rdata must be stable while rsp_valid is high
    property p_rsp_rdata_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        (rsp_valid && !rsp_ready) |=> $stable(rsp_rdata);
    endproperty

    assert property (p_cmd_valid_stable)
        else $error("CMD_IF VIOLATION: cmd_valid dropped without cmd_ready");
    assert property (p_cmd_addr_stable)
        else $error("CMD_IF VIOLATION: cmd_addr changed while cmd_valid high");
    assert property (p_cmd_write_stable)
        else $error("CMD_IF VIOLATION: cmd_write changed while cmd_valid high");
    assert property (p_rsp_valid_stable)
        else $error("CMD_IF VIOLATION: rsp_valid dropped without rsp_ready");
    assert property (p_rsp_rdata_stable)
        else $error("CMD_IF VIOLATION: rsp_rdata changed while rsp_valid high");

endinterface : axi4_lite_cmd_if
