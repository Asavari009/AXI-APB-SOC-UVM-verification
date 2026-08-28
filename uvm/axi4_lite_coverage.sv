//============================================================
// File    : axi4_lite_coverage.sv
// Project : AXI4-Lite UVM Testbench — Phase 3
// Purpose : Functional coverage model.
//           Extends uvm_subscriber which gives us a built-in
//           analysis_export — no manual wiring needed.
//
// Coverage goals:
//   1. Both transaction types (read + write) exercised
//   2. All 16 registers accessed
//   3. All byte strobe patterns exercised
//   4. Both response types seen (OKAY + DECERR)
//   5. Cross: every register both read AND written
//   6. Cross: response type vs transaction type
//============================================================

class axi4_lite_coverage extends uvm_subscriber #(axi4_lite_seq_item);
    `uvm_component_utils(axi4_lite_coverage)

    // Current transaction being sampled
    axi4_lite_seq_item trans;

    //----------------------------------------------------------
    // Covergroup — sampled on every monitored transaction
    //----------------------------------------------------------
    covergroup cg_axi4_lite;

        //------------------------------------------------------
        // 1. Transaction Type
        //------------------------------------------------------
        cp_rw: coverpoint trans.rw {
            bins write_txn = {axi4_lite_seq_item::WRITE};
            bins read_txn  = {axi4_lite_seq_item::READ};
        }

        //------------------------------------------------------
        // 2. Register Address (all 16 registers)
        //    trans.addr >> 2 gives register index 0–15
        //------------------------------------------------------
        cp_reg_idx: coverpoint (trans.addr >> 2) {
            bins reg_addr[] = {[0:15]};
        }

        //------------------------------------------------------
        // 3. Write Byte Strobe Patterns (write transactions only)
        //------------------------------------------------------
        cp_strb: coverpoint trans.strb iff
                            (trans.rw == axi4_lite_seq_item::WRITE) {
            bins full_word  = {4'b1111};   // all 4 bytes
            bins byte0_only = {4'b0001};   // byte 0 only
            bins byte1_only = {4'b0010};   // byte 1 only
            bins byte2_only = {4'b0100};   // byte 2 only
            bins byte3_only = {4'b1000};   // byte 3 only
            bins lower_half = {4'b0011};   // bytes [1:0]
            bins upper_half = {4'b1100};   // bytes [3:2]
            bins other      = default;
        }

        //------------------------------------------------------
        // 4. Response Types
        //------------------------------------------------------
        cp_resp: coverpoint trans.resp {
            bins okay   = {2'b00};
            bins decerr = {2'b11};
        }

        //------------------------------------------------------
        // 5. Cross: Every register accessed in BOTH directions
        //    Goal: all 32 bins hit (16 regs × 2 directions)
        //------------------------------------------------------
        cx_rw_reg: cross cp_rw, cp_reg_idx;

        //------------------------------------------------------
        // 6. Cross: Response vs Transaction Type
        //    Goal: DECERR seen on both reads and writes
        //------------------------------------------------------
        cx_rw_resp: cross cp_rw, cp_resp;

    endgroup : cg_axi4_lite

    //----------------------------------------------------------
    // Constructor
    //----------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_axi4_lite = new();
    endfunction

    //----------------------------------------------------------
    // write() — called by UVM for every monitored transaction
    //----------------------------------------------------------
    function void write(axi4_lite_seq_item t);
        trans = t;
        cg_axi4_lite.sample();
    endfunction

    //----------------------------------------------------------
    // Report Phase — print coverage results
    //----------------------------------------------------------
    function void report_phase(uvm_phase phase);
        real total_cov = cg_axi4_lite.get_coverage();
        $display("");
        $display("╔══════════════════════════════════════╗");
        $display("║       COVERAGE SUMMARY               ║");
        $display("╠══════════════════════════════════════╣");
        $display("║  Total Coverage  : %5.1f%%            ║", total_cov);
        $display("║  RW Type         : %5.1f%%            ║",
                 cg_axi4_lite.cp_rw.get_coverage());
        $display("║  Register Access : %5.1f%%            ║",
                 cg_axi4_lite.cp_reg_idx.get_coverage());
        $display("║  Strobe Patterns : %5.1f%%            ║",
                 cg_axi4_lite.cp_strb.get_coverage());
        $display("║  Response Types  : %5.1f%%            ║",
                 cg_axi4_lite.cp_resp.get_coverage());
        $display("║  RW x Register   : %5.1f%%            ║",
                 cg_axi4_lite.cx_rw_reg.get_coverage());
        $display("║  RW x Response   : %5.1f%%            ║",
                 cg_axi4_lite.cx_rw_resp.get_coverage());
        $display("╚══════════════════════════════════════╝");

        if (total_cov < 100.0)
            `uvm_info("COV",
                $sformatf("Coverage at %.1f%% — add more tests to close gaps",
                           total_cov), UVM_NONE)
        else
            `uvm_info("COV", "100%% coverage achieved!", UVM_NONE)
    endfunction

endclass : axi4_lite_coverage
