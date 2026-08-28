//============================================================
// File    : apb_slave.sv
// Project : AXI4-Lite to APB Bridge — Phase 5
// Purpose : APB Slave — simple register file peripheral.
//
// Features:
//   - Parameterizable number of 32-bit registers
//   - Configurable wait states (WAIT_STATES parameter)
//   - PSLVERR on out-of-range or unaligned addresses
//   - Byte strobe (PSTRB) support
//   - Two-phase APB handshake (SETUP + ACCESS)
//
// APB timing:
//   Cycle N:   PSEL=1, PENABLE=0  <- SETUP  (address/ctrl stable)
//   Cycle N+1: PSEL=1, PENABLE=1  <- ACCESS (PREADY=0 -> wait state)
//   Cycle N+W: PSEL=1, PENABLE=1, PREADY=1 <- transfer completes
//
// WAIT_STATES=0 → PREADY always 1 in ACCESS (no wait, fastest)
// WAIT_STATES=N → PREADY goes high after N extra ACCESS cycles
//============================================================

`timescale 1ns/1ps

module apb_slave #(
    parameter int DATA_WIDTH  = 32,
    parameter int ADDR_WIDTH  = 32,
    parameter int NUM_REGS    = 16,
    parameter int WAIT_STATES = 0     // extra ACCESS cycles before PREADY
)(
    // APB Signals
    input  logic                      PCLK,
    input  logic                      PRESETn,

    input  logic                      PSEL,
    input  logic                      PENABLE,
    input  logic [ADDR_WIDTH-1:0]     PADDR,
    input  logic                      PWRITE,
    input  logic [DATA_WIDTH-1:0]     PWDATA,
    input  logic [DATA_WIDTH/8-1:0]   PSTRB,
    input  logic [2:0]                PPROT,

    output logic                      PREADY,
    output logic [DATA_WIDTH-1:0]     PRDATA,
    output logic                      PSLVERR
);

    //==========================================================
    // Local Parameters
    //==========================================================
    localparam int STRB_WIDTH   = DATA_WIDTH / 8;
    localparam int BYTE_OFFSET  = $clog2(STRB_WIDTH);    // 2 for 32-bit
    localparam int REG_IDX_BITS = $clog2(NUM_REGS);

    // Response codes (reuse AXI naming for clarity)
    localparam logic OKAY   = 1'b0;
    localparam logic SLVERR = 1'b1;

    //==========================================================
    // Register File
    //==========================================================
    logic [DATA_WIDTH-1:0] reg_file [0:NUM_REGS-1];

    //==========================================================
    // Address Decode
    //==========================================================
    logic [REG_IDX_BITS-1:0] reg_idx;
    logic                     addr_valid;

    // Word-aligned address check + range check
    assign reg_idx    = PADDR[REG_IDX_BITS + BYTE_OFFSET - 1 : BYTE_OFFSET];
    assign addr_valid = (PADDR[BYTE_OFFSET-1:0] == '0) &&
                        (PADDR < (NUM_REGS * STRB_WIDTH));

    //==========================================================
    // Wait State Counter
    //==========================================================
    localparam int CNT_W = (WAIT_STATES > 0) ? $clog2(WAIT_STATES + 1) : 1;
    logic [CNT_W-1:0] wait_cnt;
    logic             wait_done;

    // PREADY goes high when wait count is satisfied
    generate
        if (WAIT_STATES == 0) begin : gen_no_wait
            assign wait_done = 1'b1;  // always ready immediately
        end else begin : gen_wait
            assign wait_done = (wait_cnt >= WAIT_STATES[CNT_W-1:0]);
        end
    endgenerate

    //==========================================================
    // APB State Machine
    // ACCESS phase: count wait states, then completes the transfer
    //==========================================================
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            PREADY  <= 1'b0;
            PRDATA  <= '0;
            PSLVERR <= 1'b0;
            wait_cnt <= '0;

            for (int i = 0; i < NUM_REGS; i++)
                reg_file[i] <= '0;

        end else begin
            // Default: not ready, no error
            PREADY  <= 1'b0;
            PSLVERR <= 1'b0;

            if (PSEL && PENABLE) begin
                // In ACCESS phase — count wait states
                if (!wait_done) begin
                    wait_cnt <= wait_cnt + 1;

                end else begin
                    // Wait states done — complete transfer
                    PREADY   <= 1'b1;
                    wait_cnt <= '0;

                    if (addr_valid) begin
                        PSLVERR <= 1'b0;

                        if (PWRITE) begin
                            // Write with byte strobes
                            for (int b = 0; b < STRB_WIDTH; b++) begin
                                if (PSTRB[b])
                                    reg_file[reg_idx][b*8 +: 8] <=
                                        PWDATA[b*8 +: 8];
                            end
                            PRDATA <= '0;
                        end else begin
                            // Read
                            PRDATA <= reg_file[reg_idx];
                        end

                    end else begin
                        // Bad address — signal error
                        PSLVERR <= 1'b1;
                        PRDATA  <= '0;
                    end
                end

            end else if (!PSEL) begin
                // Between transactions — reset counter
                wait_cnt <= '0;
            end
        end
    end

    //==========================================================
    // Debugging the visibility
    //==========================================================
    // synthesis translate_off
    logic [DATA_WIDTH-1:0] dbg_reg [0:NUM_REGS-1];
    always_comb begin
        for (int i = 0; i < NUM_REGS; i++)
            dbg_reg[i] = reg_file[i];
    end
    // synthesis translate_on

endmodule : apb_slave
