//============================================================
// File    : axi4_lite_slave.sv
// Project : AXI4-Lite Project
// Purpose : AXI4-Lite compliant Slave with internal register
//           file. Supports:
//             - Parameterizable data/address width
//             - Parameterizable number of registers
//             - Byte-lane write strobes
//             - OKAY and DECERR responses
//             - Independent read/write state machines
//             - AW + W arriving in any order
//============================================================

`timescale 1ns/1ps

module axi4_lite_slave #(
    parameter int DATA_WIDTH = 32,          // Must be 32 or 64
    parameter int ADDR_WIDTH = 32,          // Address bus width
    parameter int NUM_REGS   = 16           // Number of 32-bit registers
)(
    // Global Signals
    input  logic                      ACLK,
    input  logic                      ARESETn,

    // ------- Write Address Channel (AW) -------
    input  logic                      AWVALID,
    output logic                      AWREADY,
    input  logic [ADDR_WIDTH-1:0]     AWADDR,
    input  logic [2:0]                AWPROT,

    // ------- Write Data Channel (W) -----------
    input  logic                      WVALID,
    output logic                      WREADY,
    input  logic [DATA_WIDTH-1:0]     WDATA,
    input  logic [DATA_WIDTH/8-1:0]   WSTRB,

    // ------- Write Response Channel (B) -------
    output logic                      BVALID,
    input  logic                      BREADY,
    output logic [1:0]                BRESP,

    // ------- Read Address Channel (AR) --------
    input  logic                      ARVALID,
    output logic                      ARREADY,
    input  logic [ADDR_WIDTH-1:0]     ARADDR,
    input  logic [2:0]                ARPROT,

    // ------- Read Data Channel (R) ------------
    output logic                      RVALID,
    input  logic                      RREADY,
    output logic [DATA_WIDTH-1:0]     RDATA,
    output logic [1:0]                RRESP
);

    //==========================================================
    // Local Parameters
    //==========================================================
    localparam int STRB_WIDTH    = DATA_WIDTH / 8;
    localparam int REG_IDX_BITS  = $clog2(NUM_REGS);
    localparam int BYTE_OFFSET   = $clog2(DATA_WIDTH / 8);  // 2 for 32-bit

    // AXI4 Response Codes
    localparam logic [1:0] RESP_OKAY   = 2'b00;  // Normal success
    localparam logic [1:0] RESP_EXOKAY = 2'b01;  // Exclusive access OK (unused)
    localparam logic [1:0] RESP_SLVERR = 2'b10;  // Slave error
    localparam logic [1:0] RESP_DECERR = 2'b11;  // Decode error (bad address)

    //==========================================================
    // Internal Register File
    //==========================================================
    logic [DATA_WIDTH-1:0] reg_file [0:NUM_REGS-1];

    //==========================================================
    // Write Path State Machine
    //
    //  WR_IDLE      : Ready to accept AW and/or W
    //  WR_WAIT_W    : Got AW first, waiting for W
    //  WR_WAIT_AW   : Got W first, waiting for AW
    //  WR_RESP      : Both received, send B response
    //==========================================================
    typedef enum logic [1:0] {
        WR_IDLE    = 2'b00,
        WR_WAIT_W  = 2'b01,
        WR_WAIT_AW = 2'b10,
        WR_RESP    = 2'b11
    } wr_state_e;

    wr_state_e wr_state, wr_state_next;

    // Latched write channel values
    logic [ADDR_WIDTH-1:0]   wr_addr_lat;
    logic [DATA_WIDTH-1:0]   wr_data_lat;
    logic [STRB_WIDTH-1:0]   wr_strb_lat;

    // Decoded register index and validity
    logic [REG_IDX_BITS-1:0] wr_reg_idx;
    logic                    wr_addr_valid;

    assign wr_reg_idx   = wr_addr_lat[REG_IDX_BITS + BYTE_OFFSET - 1 : BYTE_OFFSET];
    assign wr_addr_valid = (wr_addr_lat[BYTE_OFFSET-1:0] == '0) &&          // word-aligned
                           (wr_addr_lat < (NUM_REGS * STRB_WIDTH));          // in range

    //----------------------------------------------------------
    // Write State Machine — Sequential
    //----------------------------------------------------------
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn)
            wr_state <= WR_IDLE;
        else
            wr_state <= wr_state_next;
    end

    //----------------------------------------------------------
    // Write State Machine — Combinational Next State
    //----------------------------------------------------------
    always_comb begin
        wr_state_next = wr_state;
        case (wr_state)
            WR_IDLE: begin
                if (AWVALID && WVALID)        wr_state_next = WR_RESP;
                else if (AWVALID)             wr_state_next = WR_WAIT_W;
                else if (WVALID)              wr_state_next = WR_WAIT_AW;
            end
            WR_WAIT_W:  if (WVALID)           wr_state_next = WR_RESP;
            WR_WAIT_AW: if (AWVALID)          wr_state_next = WR_RESP;
            WR_RESP:    if (BVALID && BREADY) wr_state_next = WR_IDLE;
            default:                          wr_state_next = WR_IDLE;
        endcase
    end

    //----------------------------------------------------------
    // Write Channel - Outputs & Register File Writes
    //----------------------------------------------------------
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            AWREADY     <= 1'b1;
            WREADY      <= 1'b1;
            BVALID      <= 1'b0;
            BRESP       <= RESP_OKAY;
            wr_addr_lat <= '0;
            wr_data_lat <= '0;
            wr_strb_lat <= '0;

            // Clear register file on reset
            for (int i = 0; i < NUM_REGS; i++)
                reg_file[i] <= '0;

        end else begin
            case (wr_state)

                //----------------------------------------------
                WR_IDLE: begin
                    // Accept AW and W simultaneously
                    if (AWVALID && WVALID) begin
                        wr_addr_lat <= AWADDR;
                        wr_data_lat <= WDATA;
                        wr_strb_lat <= WSTRB;
                        AWREADY     <= 1'b0;
                        WREADY      <= 1'b0;
                    // Accept AW only
                    end else if (AWVALID) begin
                        wr_addr_lat <= AWADDR;
                        AWREADY     <= 1'b0;
                    // Accept W only
                    end else if (WVALID) begin
                        wr_data_lat <= WDATA;
                        wr_strb_lat <= WSTRB;
                        WREADY      <= 1'b0;
                    end
                end

                //----------------------------------------------
                WR_WAIT_W: begin
                    // AW already latched, wait for W
                    if (WVALID && WREADY) begin
                        wr_data_lat <= WDATA;
                        wr_strb_lat <= WSTRB;
                        WREADY      <= 1'b0;
                    end
                end

                //----------------------------------------------
                WR_WAIT_AW: begin
                    // W already latched, wait for AW
                    if (AWVALID && AWREADY) begin
                        wr_addr_lat <= AWADDR;
                        AWREADY     <= 1'b0;
                    end
                end

                //----------------------------------------------
                WR_RESP: begin
                    // First cycle: perform write and assert BVALID
                    if (!BVALID) begin
                        BVALID <= 1'b1;
                        if (wr_addr_valid) begin
                            // Apply byte write strobes
                            for (int b = 0; b < STRB_WIDTH; b++) begin
                                if (wr_strb_lat[b])
                                    reg_file[wr_reg_idx][b*8 +: 8] <= wr_data_lat[b*8 +: 8];
                            end
                            BRESP <= RESP_OKAY;
                        end else begin
                            BRESP <= RESP_DECERR;  // Address out of range
                        end
                    end

                    // Handshake complete: de-assert BVALID, re-enable ready
                    if (BVALID && BREADY) begin
                        BVALID  <= 1'b0;
                        AWREADY <= 1'b1;
                        WREADY  <= 1'b1;
                    end
                end

            endcase
        end
    end

    //==========================================================
    // Read Path State Machine
    //
    //  RD_IDLE : Wait for AR handshake
    //  RD_DATA : Drive R channel until RREADY
    //==========================================================
    typedef enum logic {
        RD_IDLE = 1'b0,
        RD_DATA = 1'b1
    } rd_state_e;

    rd_state_e rd_state;

    // Latched read address
    logic [ADDR_WIDTH-1:0]   rd_addr_lat;
    logic [REG_IDX_BITS-1:0] rd_reg_idx;
    logic                    rd_addr_valid;

    assign rd_reg_idx   = rd_addr_lat[REG_IDX_BITS + BYTE_OFFSET - 1 : BYTE_OFFSET];
    assign rd_addr_valid = (rd_addr_lat[BYTE_OFFSET-1:0] == '0) &&
                           (rd_addr_lat < (NUM_REGS * STRB_WIDTH));

    //----------------------------------------------------------
    // Read Channel — State Machine + Outputs
    //----------------------------------------------------------
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            rd_state    <= RD_IDLE;
            ARREADY     <= 1'b1;
            RVALID      <= 1'b0;
            RDATA       <= '0;
            RRESP       <= RESP_OKAY;
            rd_addr_lat <= '0;

        end else begin
            case (rd_state)

                //----------------------------------------------
                RD_IDLE: begin
                    if (ARVALID && ARREADY) begin
                        rd_addr_lat <= ARADDR;
                        ARREADY     <= 1'b0;
                        rd_state    <= RD_DATA;
                    end
                end

                //----------------------------------------------
                RD_DATA: begin
                    // First cycle: drive read data
                    if (!RVALID) begin
                        RVALID <= 1'b1;
                        if (rd_addr_valid) begin
                            RDATA <= reg_file[rd_reg_idx];
                            RRESP <= RESP_OKAY;
                        end else begin
                            RDATA <= '0;
                            RRESP <= RESP_DECERR;
                        end
                    end

                    // Handshake complete
                    if (RVALID && RREADY) begin
                        RVALID   <= 1'b0;
                        ARREADY  <= 1'b1;
                        rd_state <= RD_IDLE;
                    end
                end

            endcase
        end
    end

    //==========================================================
    // Debug / Visibility: exposes register file as a packed array
    //==========================================================
    // synthesis translate_off
    logic [DATA_WIDTH-1:0] dbg_reg [0:NUM_REGS-1];
    always_comb begin
        for (int i = 0; i < NUM_REGS; i++)
            dbg_reg[i] = reg_file[i];
    end
    // synthesis translate_on

endmodule : axi4_lite_slave
