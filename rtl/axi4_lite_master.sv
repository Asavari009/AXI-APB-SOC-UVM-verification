//============================================================
// File    : axi4_lite_master.sv
// Project : AXI4-Lite Project — Phase 4
// Purpose : AXI4-Lite Master RTL
//
// Accepts commands via a simple VALID/READY command
// interface and initiates AXI4-Lite read/write transactions.
//
// Features:
//   - Simple command/response interface (decouples AXI from user)
//   - Write path: drives AW and W simultaneously
//   - AW and W handled independently using done flags
//   - Configurable timeout watchdog (TIMEOUT_CYCLES)
//   - SLVERR/DECERR detection reported via rsp_error
//   - Timeout reported separately via rsp_timeout
//
// State Machine:
//   IDLE     -> accept command, latch fields
//   WR_CHAN  -> drive AW + W simultaneously, track independently
//   WR_RESP  -> wait for B response
//   RD_CHAN  -> drive AR channel
//   RD_DATA  -> capture R data
//   SEND_RSP -> hold response until user accepts
//   ERR_TMO  -> timeout: send error response and recover
//============================================================

`timescale 1ns/1ps

module axi4_lite_master #(
    parameter int DATA_WIDTH     = 32,
    parameter int ADDR_WIDTH     = 32,
    parameter int TIMEOUT_CYCLES = 256    // max cycles to wait for response
)(
    // Global Signals
    input  logic                      ACLK,
    input  logic                      ARESETn,

    //----------------------------------------------------------
    // Command Interface  (user logic -> master)
    //----------------------------------------------------------
    input  logic                      cmd_valid,  // user has a command
    output logic                      cmd_ready,  // master can accept
    input  logic                      cmd_write,  // 1=write  0=read
    input  logic [ADDR_WIDTH-1:0]     cmd_addr,   // target byte address
    input  logic [DATA_WIDTH-1:0]     cmd_wdata,  // write data
    input  logic [DATA_WIDTH/8-1:0]   cmd_wstrb,  // byte lane enables
    input  logic [2:0]                cmd_prot,   // AXI protection

    //----------------------------------------------------------
    // Response Interface  (master -> user logic)
    //----------------------------------------------------------
    output logic                      rsp_valid,    // response ready
    input  logic                      rsp_ready,    // user can accept
    output logic [DATA_WIDTH-1:0]     rsp_rdata,    // read data
    output logic [1:0]                rsp_resp,     // BRESP or RRESP
    output logic                      rsp_error,    // 1 = SLVERR/DECERR
    output logic                      rsp_timeout,  // 1 = watchdog fired

    //----------------------------------------------------------
    // AXI4-Lite Master Ports
    //----------------------------------------------------------
    // Write Address Channel
    output logic                      AWVALID,
    input  logic                      AWREADY,
    output logic [ADDR_WIDTH-1:0]     AWADDR,
    output logic [2:0]                AWPROT,

    // Write Data Channel
    output logic                      WVALID,
    input  logic                      WREADY,
    output logic [DATA_WIDTH-1:0]     WDATA,
    output logic [DATA_WIDTH/8-1:0]   WSTRB,

    // Write Response Channel
    input  logic                      BVALID,
    output logic                      BREADY,
    input  logic [1:0]                BRESP,

    // Read Address Channel
    output logic                      ARVALID,
    input  logic                      ARREADY,
    output logic [ADDR_WIDTH-1:0]     ARADDR,
    output logic [2:0]                ARPROT,

    // Read Data Channel
    input  logic                      RVALID,
    output logic                      RREADY,
    input  logic [DATA_WIDTH-1:0]     RDATA,
    input  logic [1:0]                RRESP
);

    //==========================================================
    // FSM State Encoding
    //==========================================================
    typedef enum logic [2:0] {
        IDLE     = 3'b000,   // waiting for command
        WR_CHAN  = 3'b001,   // driving AW + W channels
        WR_RESP  = 3'b010,   // waiting for B response
        RD_CHAN  = 3'b011,   // driving AR channel
        RD_DATA  = 3'b100,   // waiting for R data
        SEND_RSP = 3'b101,   // presenting response to user
        ERR_TMO  = 3'b110    // timeout — send error, recover
    } state_e;

    state_e state;

    //==========================================================
    // Latched Command Fields
    // Held stable for the duration of the AXI transaction
    //==========================================================
    logic [ADDR_WIDTH-1:0]     lat_addr;
    logic [DATA_WIDTH-1:0]     lat_wdata;
    logic [DATA_WIDTH/8-1:0]   lat_wstrb;
    logic [2:0]                lat_prot;

    //==========================================================
    // Write Channel Tracking Flags
    // Track AW and W independently 
    //==========================================================
    logic aw_done;   // AW handshake has completed
    logic w_done;    // W  handshake has completed

    //==========================================================
    // Timeout Watchdog
    //==========================================================
    localparam int TMO_W = $clog2(TIMEOUT_CYCLES + 1);
    logic [TMO_W-1:0] tmo_cnt;
    logic             tmo_fired;

    assign tmo_fired = (tmo_cnt >= TIMEOUT_CYCLES[TMO_W-1:0]);

    //==========================================================
    // Main FSM — Sequential
    //==========================================================
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            state       <= IDLE;
            cmd_ready   <= 1'b1;

            // AXI outputs
            AWVALID <= 1'b0;  AWADDR <= '0;  AWPROT <= '0;
            WVALID  <= 1'b0;  WDATA  <= '0;  WSTRB  <= '0;
            BREADY  <= 1'b0;
            ARVALID <= 1'b0;  ARADDR <= '0;  ARPROT <= '0;
            RREADY  <= 1'b0;

            // Response
            rsp_valid   <= 1'b0;
            rsp_rdata   <= '0;
            rsp_resp    <= '0;
            rsp_error   <= 1'b0;
            rsp_timeout <= 1'b0;

            // Internal
            aw_done   <= 1'b0;
            w_done    <= 1'b0;
            tmo_cnt   <= '0;
            lat_addr  <= '0;
            lat_wdata <= '0;
            lat_wstrb <= '0;
            lat_prot  <= '0;
        end else begin
            case (state)

                //----------------------------------------------
                // IDLE
                // Wait for a valid command.
                //----------------------------------------------
                IDLE: begin
                    cmd_ready <= 1'b1;

                    if (cmd_valid && cmd_ready) begin
                        // Latch command — decouples AXI timing from user
                        lat_addr  <= cmd_addr;
                        lat_wdata <= cmd_wdata;
                        lat_wstrb <= cmd_wstrb;
                        lat_prot  <= cmd_prot;
                        cmd_ready <= 1'b0;
                        tmo_cnt   <= '0;

                        if (cmd_write) begin
                            //---- WRITE PATH ----
                            // Drive AW and W simultaneously
                            // Slave may accept them in any order
                            AWVALID <= 1'b1;
                            AWADDR  <= cmd_addr;
                            AWPROT  <= cmd_prot;
                            WVALID  <= 1'b1;
                            WDATA   <= cmd_wdata;
                            WSTRB   <= cmd_wstrb;
                            aw_done <= 1'b0;
                            w_done  <= 1'b0;
                            state   <= WR_CHAN;
                        end else begin
                            //---- READ PATH ----
                            ARVALID <= 1'b1;
                            ARADDR  <= cmd_addr;
                            ARPROT  <= cmd_prot;
                            state   <= RD_CHAN;
                        end
                    end
                end

                //----------------------------------------------
                // WR_CHAN
                //----------------------------------------------
                WR_CHAN: begin
                    tmo_cnt <= tmo_cnt + 1;

                    // AW channel handshake
                    if (AWVALID && AWREADY) begin
                        AWVALID <= 1'b0;
                        aw_done <= 1'b1;
                    end

                    // W channel handshake
                    if (WVALID && WREADY) begin
                        WVALID <= 1'b0;
                        w_done <= 1'b1;
                    end

                    // Combinationally check if BOTH channels done
                    // (including handshakes happening THIS cycle)
                    if ((aw_done || (AWVALID && AWREADY)) &&
                        (w_done  || (WVALID  && WREADY ))) begin
                        BREADY  <= 1'b1;
                        tmo_cnt <= '0;
                        state   <= WR_RESP;
                    end else if (tmo_fired) begin
                        AWVALID <= 1'b0;
                        WVALID  <= 1'b0;
                        state   <= ERR_TMO;
                    end
                end

                //----------------------------------------------
                // WR_RESP
                // Wait for slave to assert BVALID.
                //----------------------------------------------
                WR_RESP: begin
                    tmo_cnt <= tmo_cnt + 1;

                    if (BVALID && BREADY) begin
                        BREADY      <= 1'b0;
                        rsp_valid   <= 1'b1;
                        rsp_rdata   <= '0;
                        rsp_resp    <= BRESP;
                        rsp_error   <= (BRESP != 2'b00);
                        rsp_timeout <= 1'b0;
                        state       <= SEND_RSP;
                    end else if (tmo_fired) begin
                        BREADY <= 1'b0;
                        state  <= ERR_TMO;
                    end
                end

                //----------------------------------------------
                // RD_CHAN
                // Drives AR channel. Waits for ARREADY handshake.
                //----------------------------------------------
                RD_CHAN: begin
                    tmo_cnt <= tmo_cnt + 1;

                    if (ARVALID && ARREADY) begin
                        ARVALID <= 1'b0;
                        RREADY  <= 1'b1;
                        tmo_cnt <= '0;
                        state   <= RD_DATA;
                    end else if (tmo_fired) begin
                        ARVALID <= 1'b0;
                        state   <= ERR_TMO;
                    end
                end

                //----------------------------------------------
                // RD_DATA
                // Waits for slave to assert RVALID.
                // Captures RDATA and RRESP.
                //----------------------------------------------
                RD_DATA: begin
                    tmo_cnt <= tmo_cnt + 1;

                    if (RVALID && RREADY) begin
                        RREADY      <= 1'b0;
                        rsp_valid   <= 1'b1;
                        rsp_rdata   <= RDATA;
                        rsp_resp    <= RRESP;
                        rsp_error   <= (RRESP != 2'b00);
                        rsp_timeout <= 1'b0;
                        state       <= SEND_RSP;
                    end else if (tmo_fired) begin
                        RREADY <= 1'b0;
                        state  <= ERR_TMO;
                    end
                end

                //----------------------------------------------
                // SEND_RSP
                // Hold response signals stable until user
                // accepts via rsp_ready handshake.
                //----------------------------------------------
                SEND_RSP: begin
                    if (rsp_valid && rsp_ready) begin
                        rsp_valid   <= 1'b0;
                        rsp_rdata   <= '0;
                        rsp_resp    <= '0;
                        rsp_error   <= 1'b0;
                        rsp_timeout <= 1'b0;
                        cmd_ready   <= 1'b1;
                        state       <= IDLE;
                    end
                end

                //----------------------------------------------
                // ERR_TMO
                // Timeout occurred - clean up AXI outputs
                //----------------------------------------------
                ERR_TMO: begin
                    // Deassert all AXI outputs (safety)
                    AWVALID <= 1'b0;
                    WVALID  <= 1'b0;
                    BREADY  <= 1'b0;
                    ARVALID <= 1'b0;
                    RREADY  <= 1'b0;

                    // Present timeout error to user
                    rsp_valid   <= 1'b1;
                    rsp_rdata   <= '0;
                    rsp_resp    <= 2'b10;  // report as SLVERR
                    rsp_error   <= 1'b1;
                    rsp_timeout <= 1'b1;

                    if (rsp_valid && rsp_ready) begin
                        rsp_valid   <= 1'b0;
                        rsp_error   <= 1'b0;
                        rsp_timeout <= 1'b0;
                        tmo_cnt     <= '0;
                        aw_done     <= 1'b0;
                        w_done      <= 1'b0;
                        cmd_ready   <= 1'b1;
                        state       <= IDLE;
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

    //==========================================================
    // Simulation-only debug signals
    //==========================================================
    // synthesis translate_off
    logic [2:0] dbg_state;
    logic       dbg_aw_done;
    logic       dbg_w_done;
    logic [TMO_W-1:0] dbg_tmo_cnt;

    assign dbg_state   = state;
    assign dbg_aw_done = aw_done;
    assign dbg_w_done  = w_done;
    assign dbg_tmo_cnt = tmo_cnt;
    // synthesis translate_on

endmodule : axi4_lite_master
