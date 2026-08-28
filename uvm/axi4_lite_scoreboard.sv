//============================================================
// File    : axi4_lite_scoreboard.sv
// Project : AXI4-Lite UVM Testbench — Phase 3
// Purpose : Independent checker with a software shadow model
//           of the register file.
//
// How it works:
//   - Receives every transaction from the monitor via analysis port
//   - On WRITE: updates its own shadow register file (applies strobes)
//   - On READ : compares rdata against shadow — flags any mismatch
//   - Tracks DECERR transactions separately
//   - Prints a full summary in report_phase
//============================================================

class axi4_lite_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(axi4_lite_scoreboard)

    //----------------------------------------------------------
    // Analysis Import — monitor writes transactions here
    //----------------------------------------------------------
    uvm_analysis_imp #(axi4_lite_seq_item, axi4_lite_scoreboard) analysis_export;

    //----------------------------------------------------------
    // Shadow Register File
    // Mirrors exactly what the DUT's register file should contain
    //----------------------------------------------------------
    localparam int NUM_REGS = 16;
    bit [31:0] shadow [0:NUM_REGS-1];

    //----------------------------------------------------------
    // Statistics
    //----------------------------------------------------------
    int write_ok_cnt    = 0;
    int write_err_cnt   = 0;
    int read_pass_cnt   = 0;
    int read_fail_cnt   = 0;
    int decerr_cnt      = 0;

    //----------------------------------------------------------
    // Constructor
    //----------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    //----------------------------------------------------------
    // Build Phase
    //----------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        analysis_export = new("analysis_export", this);
        foreach (shadow[i]) shadow[i] = 32'h0;
        `uvm_info("SB", "Scoreboard initialised — shadow reg file cleared", UVM_MEDIUM)
    endfunction

    //----------------------------------------------------------
    // write() — called by UVM for every transaction the
    //           monitor broadcasts on its analysis port
    //----------------------------------------------------------
    function void write(axi4_lite_seq_item trans);
        if (trans.rw == axi4_lite_seq_item::WRITE)
            process_write(trans);
        else
            process_read(trans);
    endfunction

    //----------------------------------------------------------
    // Process Write Transaction
    //----------------------------------------------------------
    function void process_write(axi4_lite_seq_item trans);
        int idx;

        if (trans.resp == 2'b00) begin
            // OKAY — update shadow with byte strobes
            idx = trans.addr >> 2;
            for (int b = 0; b < 4; b++) begin
                if (trans.strb[b])
                    shadow[idx][b*8 +: 8] = trans.data[b*8 +: 8];
            end
            write_ok_cnt++;
            `uvm_info("SB",
                $sformatf("WRITE OK  reg[%0d]=0x%08h  (strb=0b%04b)",
                           idx, shadow[idx], trans.strb), UVM_HIGH)

        end else begin
            // DECERR — bad address, shadow unchanged
            write_err_cnt++;
            decerr_cnt++;
            `uvm_info("SB",
                $sformatf("WRITE DECERR  addr=0x%08h  (shadow unchanged)",
                           trans.addr), UVM_MEDIUM)
        end
    endfunction

    //----------------------------------------------------------
    // Process Read Transaction
    //----------------------------------------------------------
    function void process_read(axi4_lite_seq_item trans);
        int idx;
        bit [31:0] expected;

        if (trans.resp == 2'b00) begin
            // OKAY — compare rdata against shadow
            idx      = trans.addr >> 2;
            expected = shadow[idx];

            if (trans.rdata === expected) begin
                read_pass_cnt++;
                `uvm_info("SB",
                    $sformatf("READ  PASS  reg[%0d]  got=0x%08h  exp=0x%08h",
                               idx, trans.rdata, expected), UVM_HIGH)
            end else begin
                read_fail_cnt++;
                `uvm_error("SB",
                    $sformatf("READ  FAIL  reg[%0d]  got=0x%08h  exp=0x%08h",
                               idx, trans.rdata, expected))
            end

        end else begin
            // DECERR — rdata should be 0
            decerr_cnt++;
            read_fail_cnt += (trans.rdata !== 32'h0) ? 1 : 0;
            if (trans.rdata !== 32'h0)
                `uvm_error("SB",
                    $sformatf("READ  DECERR but rdata=0x%08h (expected 0x0)",
                               trans.rdata))
            else
                `uvm_info("SB",
                    $sformatf("READ  DECERR  addr=0x%08h  rdata=0x0 (correct)",
                               trans.addr), UVM_MEDIUM)
        end
    endfunction

    //----------------------------------------------------------
    // Report Phase — final summary
    //----------------------------------------------------------
    function void report_phase(uvm_phase phase);
        $display("");
        $display("╔══════════════════════════════════════╗");
        $display("║       SCOREBOARD SUMMARY             ║");
        $display("╠══════════════════════════════════════╣");
        $display("║  Writes OK     : %4d                ║", write_ok_cnt);
        $display("║  Writes DECERR : %4d                ║", write_err_cnt);
        $display("║  Reads  PASS   : %4d                ║", read_pass_cnt);
        $display("║  Reads  FAIL   : %4d                ║", read_fail_cnt);
        $display("║  Total DECERR  : %4d                ║", decerr_cnt);
        $display("╚══════════════════════════════════════╝");

        if (read_fail_cnt == 0)
            `uvm_info("SB", "SCOREBOARD: ALL CHECKS PASSED", UVM_NONE)
        else
            `uvm_error("SB", "SCOREBOARD: FAILURES DETECTED")
    endfunction

endclass : axi4_lite_scoreboard
