//============================================================
// File    : apb_if.sv
// Project : AXI4-Lite to APB Bridge — Phase 5
// Purpose : SystemVerilog Interface for APB protocol.
//
// APB (Advanced Peripheral Bus) is a simple 2-phase protocol:
//
//   SETUP phase  : PSEL=1, PENABLE=0
//                  Address/control signals driven and stable
//
//   ACCESS phase : PSEL=1, PENABLE=1
//                  Slave may insert wait states (PREADY=0)
//                  Transfer completes when PREADY=1
//
// Modports:
//   master  — bridge drives APB (PSEL, PENABLE, PADDR etc.)
//   slave   — peripheral responds (PREADY, PRDATA, PSLVERR)
//   monitor — passive observer (no driving)
//============================================================

`timescale 1ns/1ps

interface apb_if #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
)(
    input logic PCLK,
    input logic PRESETn
);

    //----------------------------------------------------------
    // APB Signals
    //----------------------------------------------------------
    logic                      PSEL;      // peripheral select
    logic                      PENABLE;   // access phase enable
    logic [ADDR_WIDTH-1:0]     PADDR;     // byte address
    logic                      PWRITE;    // 1=write 0=read
    logic [DATA_WIDTH-1:0]     PWDATA;    // write data
    logic [DATA_WIDTH/8-1:0]   PSTRB;     // byte lane enables
    logic [2:0]                PPROT;     // protection attributes

    logic                      PREADY;    // slave ready
    logic [DATA_WIDTH-1:0]     PRDATA;    // read data
    logic                      PSLVERR;   // slave error

    //==========================================================
    // MODPORT: Master (bridge drives APB)
    //==========================================================
    modport master (
        input  PCLK, PRESETn,
        output PSEL, PENABLE, PADDR, PWRITE,
               PWDATA, PSTRB, PPROT,
        input  PREADY, PRDATA, PSLVERR
    );

    //==========================================================
    // MODPORT: Slave (peripheral responds)
    //==========================================================
    modport slave (
        input  PCLK, PRESETn,
        input  PSEL, PENABLE, PADDR, PWRITE,
               PWDATA, PSTRB, PPROT,
        output PREADY, PRDATA, PSLVERR
    );

    //==========================================================
    // MODPORT: Monitor (passive — observe only)
    //==========================================================
    modport monitor (
        input  PCLK, PRESETn,
        input  PSEL, PENABLE, PADDR, PWRITE,
               PWDATA, PSTRB, PPROT,
        input  PREADY, PRDATA, PSLVERR
    );

    //==========================================================
    // SVA Protocol Assertions
    // Enforce APB timing rules automatically in simulation
    //==========================================================

    // Rule 1: PENABLE must not assert without PSEL
    property p_penable_requires_psel;
        @(posedge PCLK) disable iff (!PRESETn)
        PENABLE |-> PSEL;
    endproperty

    // Rule 2: PENABLE must be low in SETUP phase (first cycle)
    // i.e. when PSEL rises, PENABLE must be 0 that same cycle
    property p_setup_penable_low;
        @(posedge PCLK) disable iff (!PRESETn)
        ($rose(PSEL)) |-> !PENABLE;
    endproperty

    // Rule 3: PADDR must be stable from SETUP through ACCESS
    property p_paddr_stable;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && !PREADY) |=> $stable(PADDR);
    endproperty

    // Rule 4: PWRITE must be stable from SETUP through ACCESS
    property p_pwrite_stable;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && !PREADY) |=> $stable(PWRITE);
    endproperty

    // Rule 5: PWDATA must be stable during ACCESS phase (write)
    property p_pwdata_stable;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && PWRITE && !PREADY) |=> $stable(PWDATA);
    endproperty

    // Rule 6: PENABLE must deassert after PREADY handshake
    property p_penable_deassert;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && PREADY) |=> !PENABLE;
    endproperty

    // Rule 7: No PSLVERR without PSEL and PENABLE
    property p_pslverr_requires_access;
        @(posedge PCLK) disable iff (!PRESETn)
        PSLVERR |-> (PSEL && PENABLE);
    endproperty

    // Assert all properties
    assert property (p_penable_requires_psel)
        else $error("APB VIOLATION: PENABLE asserted without PSEL");
    assert property (p_setup_penable_low)
        else $error("APB VIOLATION: PENABLE high when PSEL first asserted");
    assert property (p_paddr_stable)
        else $error("APB VIOLATION: PADDR changed during ACCESS phase");
    assert property (p_pwrite_stable)
        else $error("APB VIOLATION: PWRITE changed during ACCESS phase");
    assert property (p_pwdata_stable)
        else $error("APB VIOLATION: PWDATA changed during ACCESS phase (write)");
    assert property (p_penable_deassert)
        else $error("APB VIOLATION: PENABLE did not deassert after PREADY");
    assert property (p_pslverr_requires_access)
        else $error("APB VIOLATION: PSLVERR outside PSEL+PENABLE window");

endinterface : apb_if
