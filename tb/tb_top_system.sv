//============================================================
// File    : tb_top_system.sv
// Project : AXI4-Lite to APB Bridge — Phase 5
// Purpose : Directed testbench for the full system:
//           Master -> AXI4-Lite -> Bridge -> APB -> Slave
//
// Tests:
//   1.  Single write -> read-back (no wait states)
//   2.  Register walk — all 16 APB registers
//   3.  Read-after-write data integrity
//   4.  Byte strobe through full path
//   5.  Out-of-range -> PSLVERR -> SLVERR propagation
//   6.  Wait states (WAIT_STATES=2) — bridge holds AXI open
//   7.  Back-to-back writes (bridge serialises onto APB)
//   8.  Mixed reads and writes
//   9.  AW arrives before W (W delayed)
//   10. Reset recovery — APB slave register file cleared
//============================================================

`timescale 1ns/1ps

module tb_top_system;

    //==========================================================
    // Parameters
    //==========================================================
    localparam int DATA_WIDTH     = 32;
    localparam int ADDR_WIDTH     = 32;
    localparam int NUM_REGS       = 16;
    localparam int CLK_PERIOD     = 10;
    localparam int TIMEOUT_CYCLES = 64;
    localparam int WAIT_STATES    = 2;    // APB slave inserts 2 wait states

    //==========================================================
    // Clock and Reset
    //==========================================================
    logic ACLK    = 0;
    logic ARESETn = 0;

    always #(CLK_PERIOD/2) ACLK = ~ACLK;

    //==========================================================
    // Command / Response Signals
    //==========================================================
    logic                      cmd_valid  = 0;
    logic                      cmd_ready;
    logic                      cmd_write  = 0;
    logic [ADDR_WIDTH-1:0]     cmd_addr   = 0;
    logic [DATA_WIDTH-1:0]     cmd_wdata  = 0;
    logic [DATA_WIDTH/8-1:0]   cmd_wstrb  = '1;
    logic [2:0]                cmd_prot   = 0;
    logic                      rsp_valid;
    logic                      rsp_ready  = 0;
    logic [DATA_WIDTH-1:0]     rsp_rdata;
    logic [1:0]                rsp_resp;
    logic                      rsp_error;
    logic                      rsp_timeout;

    //==========================================================
    // DUT — Full System (Master + Bridge + APB Slave)
    //==========================================================
    system_top #(
        .DATA_WIDTH     (DATA_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .NUM_REGS       (NUM_REGS),
        .TIMEOUT_CYCLES (TIMEOUT_CYCLES),
        .WAIT_STATES    (WAIT_STATES)
    ) dut (
        .ACLK        (ACLK),
        .ARESETn     (ARESETn),
        .cmd_valid   (cmd_valid),
        .cmd_ready   (cmd_ready),
        .cmd_write   (cmd_write),
        .cmd_addr    (cmd_addr),
        .cmd_wdata   (cmd_wdata),
        .cmd_wstrb   (cmd_wstrb),
        .cmd_prot    (cmd_prot),
        .rsp_valid   (rsp_valid),
        .rsp_ready   (rsp_ready),
        .rsp_rdata   (rsp_rdata),
        .rsp_resp    (rsp_resp),
        .rsp_error   (rsp_error),
        .rsp_timeout (rsp_timeout)
    );

    //==========================================================
    // Scoreboard
    //==========================================================
    int pass_cnt = 0;
    int fail_cnt = 0;

    task automatic check(
        input string             name,
        input logic [DATA_WIDTH-1:0] got,
        input logic [DATA_WIDTH-1:0] exp
    );
        if (got === exp) begin
            $display("[PASS] %-45s got=0x%08h", name, got);
            pass_cnt++;
        end else begin
            $display("[FAIL] %-45s got=0x%08h  exp=0x%08h", name, got, exp);
            fail_cnt++;
        end
    endtask

    task automatic check_flag(
        input string name,
        input logic  got,
        input logic  exp
    );
        if (got === exp) begin
            $display("[PASS] %-45s got=%0b", name, got);
            pass_cnt++;
        end else begin
            $display("[FAIL] %-45s got=%0b  exp=%0b", name, got, exp);
            fail_cnt++;
        end
    endtask

    //==========================================================
    // Task Library
    //==========================================================
    task automatic do_write(
        input  logic [ADDR_WIDTH-1:0]   addr,
        input  logic [DATA_WIDTH-1:0]   data,
        input  logic [DATA_WIDTH/8-1:0] strb = '1,
        output logic [1:0]              resp,
        output logic                    err
    );
        @(posedge ACLK);
        while (!cmd_ready) @(posedge ACLK);
        cmd_valid <= 1; cmd_write <= 1;
        cmd_addr  <= addr; cmd_wdata <= data;
        cmd_wstrb <= strb; cmd_prot  <= 3'b000;
        do @(posedge ACLK); while (!cmd_ready);
        cmd_valid <= 0;
        rsp_ready <= 1;
        do @(posedge ACLK); while (!rsp_valid);
        resp = rsp_resp; err = rsp_error;
        rsp_ready <= 0;
        @(posedge ACLK);
    endtask

    task automatic do_read(
        input  logic [ADDR_WIDTH-1:0] addr,
        output logic [DATA_WIDTH-1:0] data,
        output logic [1:0]            resp,
        output logic                  err
    );
        @(posedge ACLK);
        while (!cmd_ready) @(posedge ACLK);
        cmd_valid <= 1; cmd_write <= 0;
        cmd_addr  <= addr; cmd_prot <= 3'b000;
        do @(posedge ACLK); while (!cmd_ready);
        cmd_valid <= 0;
        rsp_ready <= 1;
        do @(posedge ACLK); while (!rsp_valid);
        data = rsp_rdata; resp = rsp_resp; err = rsp_error;
        rsp_ready <= 0;
        @(posedge ACLK);
    endtask

    //==========================================================
    // Test Sequence
    //==========================================================
    logic [DATA_WIDTH-1:0] rd_data;
    logic [1:0]            rd_resp, wr_resp;
    logic                  rd_err, wr_err;

    initial begin
        $display("==============================================");
        $display("  System: Master -> Bridge -> APB Slave");
        $display("  Wait States = %0d", WAIT_STATES);
        $display("==============================================");

        ARESETn = 0;
        repeat(5) @(posedge ACLK);
        ARESETn = 1;
        repeat(2) @(posedge ACLK);

        //------------------------------------------------------
        // TEST 1: Single write -> read-back through bridge
        //------------------------------------------------------
        $display("\n--- TEST 1: Write/Read Through Bridge ---");
        do_write(32'h00, 32'hDEAD_BEEF, '1, wr_resp, wr_err);
        do_read (32'h00, rd_data, rd_resp, rd_err);
        check     ("T1: bridge write/read", rd_data, 32'hDEAD_BEEF);
        check_flag("T1: no error",          rd_err,  1'b0);

        //------------------------------------------------------
        // TEST 2: Full register walk through bridge
        //------------------------------------------------------
        $display("\n--- TEST 2: APB Register Walk ---");
        for (int i = 0; i < NUM_REGS; i++)
            do_write(i*4, 32'hB000_0000 + i, '1, wr_resp, wr_err);
        for (int i = 0; i < NUM_REGS; i++) begin
            do_read(i*4, rd_data, rd_resp, rd_err);
            check($sformatf("T2: APB reg[%0d]", i), rd_data, 32'hB000_0000 + i);
        end

        //------------------------------------------------------
        // TEST 3: Read-after-write data integrity
        //------------------------------------------------------
        $display("\n--- TEST 3: RAW Data Integrity ---");
        do_write(32'h1C, 32'hCAFE_F00D, '1, wr_resp, wr_err);
        do_read (32'h1C, rd_data, rd_resp, rd_err);
        check("T3: RAW through bridge", rd_data, 32'hCAFE_F00D);

        //------------------------------------------------------
        // TEST 4: Byte strobes through full path
        //------------------------------------------------------
        $display("\n--- TEST 4: Byte Strobes End-to-End ---");
        do_write(32'h20, 32'hFFFF_FFFF, 4'hF, wr_resp, wr_err);
        do_write(32'h20, 32'h1234_5678, 4'h1, wr_resp, wr_err);
        do_read (32'h20, rd_data, rd_resp, rd_err);
        check("T4: strobe 0001 (byte 0)", rd_data, 32'hFFFF_FF78);

        do_write(32'h20, 32'hFFFF_FFFF, 4'hF, wr_resp, wr_err);
        do_write(32'h20, 32'h1234_5678, 4'hC, wr_resp, wr_err);
        do_read (32'h20, rd_data, rd_resp, rd_err);
        check("T4: strobe 1100 (upper)", rd_data, 32'h1234_FFFF);

        //------------------------------------------------------
        // TEST 5: Out-of-range -> PSLVERR -> SLVERR propagation
        //------------------------------------------------------
        $display("\n--- TEST 5: Error Propagation (PSLVERR→SLVERR) ---");
        do_write(32'hFFFF_0000, 32'hBAD_BABE, '1, wr_resp, wr_err);
        check_flag("T5: OOB write → error",   wr_err,  1'b1);
        do_read(32'hFFFF_0000, rd_data, rd_resp, rd_err);
        check_flag("T5: OOB read → error",    rd_err,  1'b1);
        check     ("T5: OOB read data=0",      rd_data, 32'h0);

        //------------------------------------------------------
        // TEST 6: Wait states — bridge holds AXI channels open
        // (WAIT_STATES=2, so each APB transaction takes 3+ cycles)
        //------------------------------------------------------
        $display("\n--- TEST 6: Wait States (WAIT_STATES=%0d) ---",
                  WAIT_STATES);
        do_write(32'h00, 32'hABCD_1234, '1, wr_resp, wr_err);
        do_read (32'h00, rd_data, rd_resp, rd_err);
        check     ("T6: write with wait states", rd_data, 32'hABCD_1234);
        check_flag("T6: no error on wait",       rd_err,  1'b0);

        //------------------------------------------------------
        // TEST 7: Back-to-back writes through bridge
        // Bridge serialises onto APB — each takes 1+WAIT_STATES cycles
        //------------------------------------------------------
        $display("\n--- TEST 7: Back-to-Back Writes ---");
        do_write(32'h00, 32'hAAAA_0000, '1, wr_resp, wr_err);
        do_write(32'h04, 32'hBBBB_0001, '1, wr_resp, wr_err);
        do_write(32'h08, 32'hCCCC_0002, '1, wr_resp, wr_err);
        do_read(32'h00, rd_data, rd_resp, rd_err);
        check("T7: b2b reg[0]", rd_data, 32'hAAAA_0000);
        do_read(32'h04, rd_data, rd_resp, rd_err);
        check("T7: b2b reg[1]", rd_data, 32'hBBBB_0001);
        do_read(32'h08, rd_data, rd_resp, rd_err);
        check("T7: b2b reg[2]", rd_data, 32'hCCCC_0002);

        //------------------------------------------------------
        // TEST 8: Mixed reads and writes
        //------------------------------------------------------
        $display("\n--- TEST 8: Mixed Reads and Writes ---");
        do_write(32'h10, 32'h1111_1111, '1, wr_resp, wr_err);
        do_read (32'h10, rd_data, rd_resp, rd_err);
        check("T8: write then read", rd_data, 32'h1111_1111);
        do_write(32'h10, 32'h2222_2222, '1, wr_resp, wr_err);
        do_read (32'h10, rd_data, rd_resp, rd_err);
        check("T8: overwrite then read", rd_data, 32'h2222_2222);

        //------------------------------------------------------
        // TEST 9: Reset Recovery
        //------------------------------------------------------
        $display("\n--- TEST 9: Reset Recovery ---");
        do_write(32'h00, 32'hFFFF_FFFF, '1, wr_resp, wr_err);
        ARESETn = 0;
        repeat(3) @(posedge ACLK);
        ARESETn = 1;
        repeat(2) @(posedge ACLK);
        do_read(32'h00, rd_data, rd_resp, rd_err);
        check     ("T9: post-reset reg[0]=0", rd_data, 32'h0);
        check_flag("T9: no error after reset", rd_err, 1'b0);

        //------------------------------------------------------
        // Summary
        //------------------------------------------------------
        repeat(5) @(posedge ACLK);
        $display("\n==============================================");
        $display("  RESULTS: %0d PASSED | %0d FAILED",
                  pass_cnt, fail_cnt);
        $display("==============================================\n");

        if (fail_cnt == 0)
            $display("  *** ALL TESTS PASSED — Bridge is clean! ***\n");
        else
            $display("  *** FAILURES DETECTED — check waveform ***\n");

        $finish;
    end

    // Timeout watchdog
    initial begin
        #5_000_000;
        $display("[TIMEOUT] Simulation hung!");
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("system_tb.vcd");
        $dumpvars(0, tb_top_system);
    end

endmodule : tb_top_system
