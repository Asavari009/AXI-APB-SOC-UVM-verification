//============================================================
// File    : tb_top.sv
// Project : AXI4-Lite Project
//============================================================

`timescale 1ns/1ps

module tb_top;

    localparam int DATA_WIDTH = 32;
    localparam int ADDR_WIDTH = 32;
    localparam int NUM_REGS   = 16;
    localparam int CLK_PERIOD = 10;

    localparam logic [1:0] OKAY   = 2'b00;
    localparam logic [1:0] DECERR = 2'b11;

    //==========================================================
    // Clock and Reset
    //==========================================================
    logic ACLK    = 0;
    logic ARESETn = 0;

    always #(CLK_PERIOD/2) ACLK = ~ACLK;

    //==========================================================
    // Interface
    //==========================================================
    axi4_lite_if #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) axi_if (
        .ACLK    (ACLK),
        .ARESETn (ARESETn)
    );

    //==========================================================
    // DUT
    //==========================================================
    axi4_lite_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .NUM_REGS  (NUM_REGS)
    ) dut (
        .ACLK    (ACLK),
        .ARESETn (ARESETn),
        .AWVALID (axi_if.AWVALID), .AWREADY (axi_if.AWREADY),
        .AWADDR  (axi_if.AWADDR),  .AWPROT  (axi_if.AWPROT),
        .WVALID  (axi_if.WVALID),  .WREADY  (axi_if.WREADY),
        .WDATA   (axi_if.WDATA),   .WSTRB   (axi_if.WSTRB),
        .BVALID  (axi_if.BVALID),  .BREADY  (axi_if.BREADY),
        .BRESP   (axi_if.BRESP),
        .ARVALID (axi_if.ARVALID), .ARREADY (axi_if.ARREADY),
        .ARADDR  (axi_if.ARADDR),  .ARPROT  (axi_if.ARPROT),
        .RVALID  (axi_if.RVALID),  .RREADY  (axi_if.RREADY),
        .RDATA   (axi_if.RDATA),   .RRESP   (axi_if.RRESP)
    );

    //==========================================================
    // Scoreboard
    //==========================================================
    int pass_count = 0;
    int fail_count = 0;

    task automatic check(
        input string test_name,
        input logic [DATA_WIDTH-1:0] got,
        input logic [DATA_WIDTH-1:0] expected
    );
        if (got === expected) begin
            $display("[PASS] %-45s | got=0x%08h", test_name, got);
            pass_count++;
        end else begin
            $display("[FAIL] %-45s | got=0x%08h  expected=0x%08h",
                      test_name, got, expected);
            fail_count++;
        end
    endtask

    task automatic check_resp(
        input string test_name,
        input logic [1:0] got,
        input logic [1:0] expected
    );
        if (got === expected) begin
            $display("[PASS] %-45s | RESP=0b%02b", test_name, got);
            pass_count++;
        end else begin
            $display("[FAIL] %-45s | got=0b%02b  expected=0b%02b",
                      test_name, got, expected);
            fail_count++;
        end
    endtask

    //==========================================================
    // AXI Task Library
    //==========================================================

    // ----------------------------------------------------------
    // AXI Write 
    // ----------------------------------------------------------
    task automatic axi_write(
        input logic [ADDR_WIDTH-1:0]   addr,
        input logic [DATA_WIDTH-1:0]   data,
        input logic [DATA_WIDTH/8-1:0] strb    = '1,
        input int                      b_delay = 0
    );
        @(posedge ACLK);
        // Drive both channels simultaneously
        axi_if.AWVALID <= 1'b1;  axi_if.AWADDR <= addr;  axi_if.AWPROT <= 3'b0;
        axi_if.WVALID  <= 1'b1;  axi_if.WDATA  <= data;  axi_if.WSTRB  <= strb;

        // FORK: handle AW and W handshakes independently 
        fork
            // Thread 1: Wait for AW handshake
            begin
                do @(posedge ACLK); while (!axi_if.AWREADY);
                axi_if.AWVALID <= 1'b0;
            end
            // Thread 2: Wait for W handshake
            begin
                do @(posedge ACLK); while (!axi_if.WREADY);
                axi_if.WVALID <= 1'b0;
            end
        join  // Wait until BOTH handshakes complete

        // Optional back-pressure delay before accepting B response
        repeat(b_delay) @(posedge ACLK);
        axi_if.BREADY <= 1'b1;

        do @(posedge ACLK); while (!axi_if.BVALID);
        axi_if.BREADY <= 1'b0;
        @(posedge ACLK);
    endtask

    // ----------------------------------------------------------
    // AXI Write — AW sent first, W delayed
    // ----------------------------------------------------------
    task automatic axi_write_aw_first(
        input logic [ADDR_WIDTH-1:0]   addr,
        input logic [DATA_WIDTH-1:0]   data,
        input int                      delay_cycles = 3
    );
        @(posedge ACLK);
        axi_if.AWVALID <= 1'b1;
        axi_if.AWADDR  <= addr;
        axi_if.AWPROT  <= 3'b0;

        do @(posedge ACLK); while (!axi_if.AWREADY);
        axi_if.AWVALID <= 1'b0;

        repeat(delay_cycles) @(posedge ACLK);

        axi_if.WVALID <= 1'b1;
        axi_if.WDATA  <= data;
        axi_if.WSTRB  <= '1;

        do @(posedge ACLK); while (!axi_if.WREADY);
        axi_if.WVALID <= 1'b0;

        axi_if.BREADY <= 1'b1;
        do @(posedge ACLK); while (!axi_if.BVALID);
        axi_if.BREADY <= 1'b0;
        @(posedge ACLK);
    endtask

    // ----------------------------------------------------------
    // AXI Write — W sent first, AW delayed
    // ----------------------------------------------------------
    task automatic axi_write_w_first(
        input logic [ADDR_WIDTH-1:0]   addr,
        input logic [DATA_WIDTH-1:0]   data,
        input int                      delay_cycles = 3
    );
        @(posedge ACLK);
        axi_if.WVALID <= 1'b1;
        axi_if.WDATA  <= data;
        axi_if.WSTRB  <= '1;

        do @(posedge ACLK); while (!axi_if.WREADY);
        axi_if.WVALID <= 1'b0;

        repeat(delay_cycles) @(posedge ACLK);

        axi_if.AWVALID <= 1'b1;
        axi_if.AWADDR  <= addr;
        axi_if.AWPROT  <= 3'b0;

        do @(posedge ACLK); while (!axi_if.AWREADY);
        axi_if.AWVALID <= 1'b0;

        axi_if.BREADY <= 1'b1;
        do @(posedge ACLK); while (!axi_if.BVALID);
        axi_if.BREADY <= 1'b0;
        @(posedge ACLK);
    endtask

    // ----------------------------------------------------------
    // AXI Read
    // ----------------------------------------------------------
    task automatic axi_read(
        input  logic [ADDR_WIDTH-1:0] addr,
        output logic [DATA_WIDTH-1:0] data,
        output logic [1:0]            resp,
        input  int                    r_delay = 0
    );
        @(posedge ACLK);
        axi_if.ARVALID <= 1'b1;
        axi_if.ARADDR  <= addr;
        axi_if.ARPROT  <= 3'b0;

        do @(posedge ACLK); while (!axi_if.ARREADY);
        axi_if.ARVALID <= 1'b0;

        repeat(r_delay) @(posedge ACLK);
        axi_if.RREADY <= 1'b1;

        do @(posedge ACLK); while (!axi_if.RVALID);
        data = axi_if.RDATA;
        resp = axi_if.RRESP;
        axi_if.RREADY <= 1'b0;
        @(posedge ACLK);
    endtask

    //==========================================================
    // Signal Init
    //==========================================================
    task automatic init_signals();
        axi_if.AWVALID = 0; axi_if.AWADDR = 0; axi_if.AWPROT = 0;
        axi_if.WVALID  = 0; axi_if.WDATA  = 0; axi_if.WSTRB  = 0;
        axi_if.BREADY  = 0;
        axi_if.ARVALID = 0; axi_if.ARADDR = 0; axi_if.ARPROT = 0;
        axi_if.RREADY  = 0;
    endtask

    //==========================================================
    // Test Sequence
    //==========================================================
    logic [DATA_WIDTH-1:0] rd_data;
    logic [1:0]            rd_resp;

    initial begin
        $display("============================================");
        $display("  AXI4-Lite Slave Directed Testbench");
        $display("============================================");

        init_signals();
        ARESETn = 0;
        repeat(5) @(posedge ACLK);
        ARESETn = 1;
        repeat(2) @(posedge ACLK);

        //------------------------------------------------------
        // TEST 1: Basic Write → Read-back
        //------------------------------------------------------
        $display("\n--- TEST 1: Basic Write/Read-back ---");
        axi_write(32'h00, 32'hDEAD_BEEF);
        axi_read (32'h00, rd_data, rd_resp);
        check     ("T1: reg[0] read-back",   rd_data, 32'hDEAD_BEEF);
        check_resp("T1: read resp OKAY",      rd_resp, OKAY);

        //------------------------------------------------------
        // TEST 2: Full Register Walk
        //------------------------------------------------------
        $display("\n--- TEST 2: Register File Walk ---");
        for (int i = 0; i < NUM_REGS; i++)
            axi_write(i * 4, 32'hA000_0000 + i);
        for (int i = 0; i < NUM_REGS; i++) begin
            axi_read(i * 4, rd_data, rd_resp);
            check($sformatf("T2: reg[%0d] read-back", i), rd_data, 32'hA000_0000 + i);
        end

        //------------------------------------------------------
        // TEST 3: Byte Strobe
        //------------------------------------------------------
        $display("\n--- TEST 3: Byte Strobe Partial Write ---");
        axi_write(32'h04, 32'hFFFF_FFFF);
        axi_write(32'h04, 32'h1234_5678, 4'b0011);
        axi_read (32'h04, rd_data, rd_resp);
        check("T3: strobe [1:0] only", rd_data, 32'hFFFF_5678);

        axi_write(32'h08, 32'hFFFF_FFFF);
        axi_write(32'h08, 32'hAABB_CCDD, 4'b1100);
        axi_read (32'h08, rd_data, rd_resp);
        check("T3: strobe [3:2] only", rd_data, 32'hAABB_FFFF);

        //------------------------------------------------------
        // TEST 4: Back-pressure on BREADY
        //------------------------------------------------------
        $display("\n--- TEST 4: BREADY Back-pressure ---");
        axi_write(32'h0C, 32'hCAFE_F00D, '1, 3);
        axi_read (32'h0C, rd_data, rd_resp);
        check("T4: back-pressure write", rd_data, 32'hCAFE_F00D);

        //------------------------------------------------------
        // TEST 5: Back-pressure on RREADY
        //------------------------------------------------------
        $display("\n--- TEST 5: RREADY Back-pressure ---");
        axi_write(32'h10, 32'hBEEF_CAFE);
        axi_read (32'h10, rd_data, rd_resp, 4);
        check("T5: back-pressure read", rd_data, 32'hBEEF_CAFE);

        //------------------------------------------------------
        // TEST 6: Out-of-Range Address -> DECERR
        //------------------------------------------------------
        $display("\n--- TEST 6: Out-of-Range -> DECERR ---");
        axi_write(32'hFFFF_0000, 32'hBAD_BABE);
        check_resp("T6: write DECERR", axi_if.BRESP, DECERR);
        axi_read(32'hFFFF_0000, rd_data, rd_resp);
        check_resp("T6: read DECERR",  rd_resp, DECERR);

        //------------------------------------------------------
        // TEST 7: Unaligned Address -> DECERR
        //------------------------------------------------------
        $display("\n--- TEST 7: Unaligned Address -> DECERR ---");
        axi_write(32'h01, 32'h1234_5678);
        check_resp("T7: unaligned write DECERR", axi_if.BRESP, DECERR);
        axi_read(32'h03, rd_data, rd_resp);
        check_resp("T7: unaligned read DECERR",  rd_resp, DECERR);

        //------------------------------------------------------
        // TEST 8: AW First, W Delayed
        //------------------------------------------------------
        $display("\n--- TEST 8: AW First, W Delayed ---");
        axi_write_aw_first(32'h3C, 32'hABCD_1234, 3);
        axi_read(32'h3C, rd_data, rd_resp);
        check("T8: AW-first result", rd_data, 32'hABCD_1234);

        //------------------------------------------------------
        // TEST 9: W First, AW Delayed
        //------------------------------------------------------
        $display("\n--- TEST 9: W First, AW Delayed ---");
        axi_write_w_first(32'h38, 32'h5678_DCBA, 3);
        axi_read(32'h38, rd_data, rd_resp);
        check("T9: W-first result", rd_data, 32'h5678_DCBA);

        //------------------------------------------------------
        // TEST 10: Reset Recovery
        //------------------------------------------------------
        $display("\n--- TEST 10: Reset Recovery ---");
        axi_write(32'h00, 32'h1111_2222);
        ARESETn = 0;
        repeat(3) @(posedge ACLK);
        ARESETn = 1;
        repeat(2) @(posedge ACLK);
        axi_read(32'h00, rd_data, rd_resp);
        check     ("T10: post-reset reg[0]=0", rd_data, 32'h0);
        check_resp("T10: post-reset OKAY",     rd_resp, OKAY);

        //------------------------------------------------------
        // Summary
        //------------------------------------------------------
        repeat(5) @(posedge ACLK);
        $display("\n============================================");
        $display("  RESULTS: %0d PASSED | %0d FAILED",
                  pass_count, fail_count);
        $display("============================================\n");

        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED — RTL is clean! ***\n");
        else
            $display("  *** FAILURES DETECTED — check waveform ***\n");

        $finish;
    end

    // Timeout watchdog
    initial begin
        #500_000;
        $display("[TIMEOUT] Simulation exceeded limit!");
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("axi4_lite_tb.vcd");
        $dumpvars(0, tb_top);
    end

endmodule : tb_top
