//============================================================
// File    : axi4_lite_to_apb.sv
// Project : AXI4-Lite to APB Bridge — Phase 5
// Purpose : Translates AXI4-Lite transactions into APB
//           two-phase transactions.
//
//   AXI4-Lite Master -> [Bridge] -> APB Slave
//
// Protocol mapping:
//   AXI write (AW+W) -> APB SETUP -> APB ACCESS -> AXI B
//   AXI read  (AR)   -> APB SETUP -> APB ACCESS -> AXI R
//
// Response mapping:
//   APB PSLVERR=0 -> AXI RESP=OKAY   (2'b00)
//   APB PSLVERR=1 -> AXI RESP=SLVERR (2'b10)
//
// Key features:
//   - Accepts AW and W in any order (like AXI4-Lite slave)
//   - APB transaction starts only after BOTH AW and W received
//   - Supports variable wait states (PREADY=0)
//   - PSEL deasserts between transactions (APB rule)
//   - PENABLE deasserts after each PREADY handshake (APB rule)
//
// State Machine:
//   IDLE    -> accept AXI write (AW+W) or read (AR)
//   WAIT_W  -> got AW first, waiting for W
//   WAIT_AW -> got W first, waiting for AW
//   SETUP   -> APB SETUP phase (PSEL=1, PENABLE=0, 1 cycle)
//   ACCESS  -> APB ACCESS phase (PSEL=1, PENABLE=1, ≥1 cycle)
//   WR_RESP -> drive AXI B channel response
//   RD_RESP -> drive AXI R channel response
//============================================================

`timescale 1ns/1ps

module axi4_lite_to_apb #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
)(
    // Shared clock and reset
    input  logic                      ACLK,
    input  logic                      ARESETn,

    //----------------------------------------------------------
    // AXI4-Lite Slave Interface (receives from AXI master)
    //----------------------------------------------------------
    // Write Address Channel
    input  logic                      AWVALID,
    output logic                      AWREADY,
    input  logic [ADDR_WIDTH-1:0]     AWADDR,
    input  logic [2:0]                AWPROT,

    // Write Data Channel
    input  logic                      WVALID,
    output logic                      WREADY,
    input  logic [DATA_WIDTH-1:0]     WDATA,
    input  logic [DATA_WIDTH/8-1:0]   WSTRB,

    // Write Response Channel
    output logic                      BVALID,
    input  logic                      BREADY,
    output logic [1:0]                BRESP,

    // Read Address Channel
    input  logic                      ARVALID,
    output logic                      ARREADY,
    input  logic [ADDR_WIDTH-1:0]     ARADDR,
    input  logic [2:0]                ARPROT,

    // Read Data Channel
    output logic                      RVALID,
    input  logic                      RREADY,
    output logic [DATA_WIDTH-1:0]     RDATA,
    output logic [1:0]                RRESP,

    //----------------------------------------------------------
    // APB Master Interface (drives APB peripheral)
    //----------------------------------------------------------
    output logic                      PSEL,
    output logic                      PENABLE,
    output logic [ADDR_WIDTH-1:0]     PADDR,
    output logic                      PWRITE,
    output logic [DATA_WIDTH-1:0]     PWDATA,
    output logic [DATA_WIDTH/8-1:0]   PSTRB,
    output logic [2:0]                PPROT,

    input  logic                      PREADY,
    input  logic [DATA_WIDTH-1:0]     PRDATA,
    input  logic                      PSLVERR
);

    //==========================================================
    // AXI Response Codes
    //==========================================================
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    //==========================================================
    // State Machine
    //==========================================================
    typedef enum logic [2:0] {
        IDLE    = 3'b000,   // waiting for AXI transaction
        WAIT_W  = 3'b001,   // got AW, waiting for W
        WAIT_AW = 3'b010,   // got W, waiting for AW
        SETUP   = 3'b011,   // APB SETUP phase  (PSEL=1, PENABLE=0)
        ACCESS  = 3'b100,   // APB ACCESS phase (PSEL=1, PENABLE=1)
        WR_RESP = 3'b101,   // drive AXI B response
        RD_RESP = 3'b110    // drive AXI R response
    } state_e;

    state_e state;

    //==========================================================
    // Latched Transaction Fields
    //==========================================================
    logic [ADDR_WIDTH-1:0]   lat_addr;
    logic [DATA_WIDTH-1:0]   lat_wdata;
    logic [DATA_WIDTH/8-1:0] lat_wstrb;
    logic [2:0]              lat_prot;
    logic                    is_write;    // 1=write 0=read

    // Latched APB response
    logic [DATA_WIDTH-1:0]   lat_prdata;
    logic                    lat_pslverr;

    //==========================================================
    // Main State Machine
    //==========================================================
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            state   <= IDLE;

            // AXI outputs — deassert all
            AWREADY <= 1'b1;
            WREADY  <= 1'b1;
            BVALID  <= 1'b0;
            BRESP   <= RESP_OKAY;
            ARREADY <= 1'b1;
            RVALID  <= 1'b0;
            RDATA   <= '0;
            RRESP   <= RESP_OKAY;

            // APB outputs — deassert all
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
            PADDR   <= '0;
            PWRITE  <= 1'b0;
            PWDATA  <= '0;
            PSTRB   <= '0;
            PPROT   <= '0;

            // Internal latches
            lat_addr    <= '0;
            lat_wdata   <= '0;
            lat_wstrb   <= '0;
            lat_prot    <= '0;
            is_write    <= 1'b0;
            lat_prdata  <= '0;
            lat_pslverr <= 1'b0;

        end else begin
            case (state)

                //----------------------------------------------
                // IDLE
                // Accepts AXI write (AW+W) or read (AR).
                // Writes have priority over reads.
                // AW and W may arrive simultaneously or in any order.
                //----------------------------------------------
                IDLE: begin
                    AWREADY <= 1'b1;
                    WREADY  <= 1'b1;
                    ARREADY <= 1'b1;

                    // ---- Write path ----
                    if (AWVALID && WVALID) begin
                        // Both arrive at same time 
                        lat_addr  <= AWADDR;
                        lat_wdata <= WDATA;
                        lat_wstrb <= WSTRB;
                        lat_prot  <= AWPROT;
                        is_write  <= 1'b1;
                        AWREADY   <= 1'b0;
                        WREADY    <= 1'b0;
                        ARREADY   <= 1'b0;
                        state     <= SETUP;

                    end else if (AWVALID && !WVALID) begin
                        // AW arrived first
                        lat_addr <= AWADDR;
                        lat_prot <= AWPROT;
                        is_write <= 1'b1;
                        AWREADY  <= 1'b0;
                        ARREADY  <= 1'b0;
                        state    <= WAIT_W;

                    end else if (!AWVALID && WVALID) begin
                        // W arrived first
                        lat_wdata <= WDATA;
                        lat_wstrb <= WSTRB;
                        is_write  <= 1'b1;
                        WREADY    <= 1'b0;
                        ARREADY   <= 1'b0;
                        state     <= WAIT_AW;

                    // ---- Read path (lower priority than write) ----
                    end else if (ARVALID) begin
                        lat_addr  <= ARADDR;
                        lat_prot  <= ARPROT;
                        is_write  <= 1'b0;
                        AWREADY   <= 1'b0;
                        WREADY    <= 1'b0;
                        ARREADY   <= 1'b0;
                        state     <= SETUP;
                    end
                end

                //----------------------------------------------
                // WAIT_W
                // Got AW first — wait for W data
                //----------------------------------------------
                WAIT_W: begin
                    if (WVALID && WREADY) begin
                        lat_wdata <= WDATA;
                        lat_wstrb <= WSTRB;
                        WREADY    <= 1'b0;
                        state     <= SETUP;
                    end
                end

                //----------------------------------------------
                // WAIT_AW
                // Got W first — wait for AW address
                //----------------------------------------------
                WAIT_AW: begin
                    if (AWVALID && AWREADY) begin
                        lat_addr  <= AWADDR;
                        lat_prot  <= AWPROT;
                        AWREADY   <= 1'b0;
                        state     <= SETUP;
                    end
                end

                //----------------------------------------------
                // SETUP
                // APB SETUP phase — 1 clock cycle.
                // PSEL=1, PENABLE=0, all signals stable.
                // Next cycle always transitions to ACCESS.
                //----------------------------------------------
                SETUP: begin
                    PSEL    <= 1'b1;
                    PENABLE <= 1'b0;
                    PADDR   <= lat_addr;
                    PWRITE  <= is_write;
                    PWDATA  <= lat_wdata;
                    PSTRB   <= lat_wstrb;
                    PPROT   <= lat_prot;
                    state   <= ACCESS;
                end

                //----------------------------------------------
                // ACCESS
                // APB ACCESS phase — assert PENABLE.
                // Slave may hold PREADY=0 to insert wait states.
                // Transfer completes when PREADY=1.
                //----------------------------------------------
                ACCESS: begin
                    PENABLE <= 1'b1;

                    if (PREADY) begin
                        // Transfer complete — latch APB response
                        lat_prdata  <= PRDATA;
                        lat_pslverr <= PSLVERR;

                        // Deassert APB outputs
                        PSEL    <= 1'b0;
                        PENABLE <= 1'b0;

                        // Go to appropriate AXI response state
                        if (is_write)
                            state <= WR_RESP;
                        else
                            state <= RD_RESP;
                    end
                end

                //----------------------------------------------
                // WR_RESP
                // Drive AXI B channel with write response.
                // Map APB PSLVERR -> AXI SLVERR.
                //----------------------------------------------
                WR_RESP: begin
                    BVALID <= 1'b1;
                    BRESP  <= lat_pslverr ? RESP_SLVERR : RESP_OKAY;

                    if (BVALID && BREADY) begin
                        BVALID  <= 1'b0;
                        BRESP   <= RESP_OKAY;
                        // Re-enable AXI channels for next transaction
                        AWREADY <= 1'b1;
                        WREADY  <= 1'b1;
                        ARREADY <= 1'b1;
                        state   <= IDLE;
                    end
                end

                //----------------------------------------------
                // RD_RESP
                // Drive AXI R channel with read data and response.
                // Map APB PSLVERR -> AXI SLVERR.
                //----------------------------------------------
                RD_RESP: begin
                    RVALID <= 1'b1;
                    RDATA  <= lat_prdata;
                    RRESP  <= lat_pslverr ? RESP_SLVERR : RESP_OKAY;

                    if (RVALID && RREADY) begin
                        RVALID  <= 1'b0;
                        RDATA   <= '0;
                        RRESP   <= RESP_OKAY;
                        // Re-enable AXI channels for next transaction
                        AWREADY <= 1'b1;
                        WREADY  <= 1'b1;
                        ARREADY <= 1'b1;
                        state   <= IDLE;
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

    //==========================================================
    // Debug visibility
    //==========================================================
    // synthesis translate_off
    logic [2:0] dbg_state;
    logic       dbg_is_write;
    assign dbg_state    = state;
    assign dbg_is_write = is_write;
    // synthesis translate_on

endmodule : axi4_lite_to_apb
