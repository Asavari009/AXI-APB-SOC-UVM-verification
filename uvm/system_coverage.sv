//============================================================
// File    : system_coverage.sv
// Project : System UVM Testbench — Phase 6
// Purpose : Functional coverage for the full system.
//           Subscribes to APB monitor (deepest observable point).
//
// Coverage goals:
//   1. Both read and write transactions through bridge
//   2. All 16 APB registers accessed
//   3. PSLVERR seen (error propagation path exercised)
//   4. Wait states exercised (PENABLE cycles counted)
//   5. Back-to-back transactions
//   6. Both bytes and full-word strobes used
//   7. Cross: every register both read AND written
//   8. Cross: PSLVERR on both reads and writes
//============================================================

class system_coverage extends uvm_subscriber #(apb_seq_item);
    `uvm_component_utils(system_coverage)

    apb_seq_item trans;
    apb_seq_item prev_trans;
    bit          has_prev;

    //----------------------------------------------------------
    // Coverage Group
    //----------------------------------------------------------
    covergroup cg_system;

        // 1. Transaction type
        cp_rw: coverpoint trans.pwrite {
            bins apb_write = {1'b1};
            bins apb_read  = {1'b0};
        }

        // 2. Register address — all 16 registers
        cp_reg: coverpoint (trans.paddr >> 2) {
            bins regs[] = {[0:15]};
        }

        // 3. APB error response
        cp_pslverr: coverpoint trans.pslverr {
            bins no_error  = {1'b0};
            bins has_error = {1'b1};
        }

        // 4. Byte strobe patterns (writes only)
        cp_strb: coverpoint trans.pstrb iff (trans.pwrite) {
            bins full_word  = {4'b1111};
            bins byte0_only = {4'b0001};
            bins byte1_only = {4'b0010};
            bins byte2_only = {4'b0100};
            bins byte3_only = {4'b1000};
            bins lower_half = {4'b0011};
            bins upper_half = {4'b1100};
            bins other      = default;
        }

        // 5. Cross: every register both read AND written
        cx_rw_reg: cross cp_rw, cp_reg;

        // 6. Cross: PSLVERR on both read and write paths
        cx_rw_err: cross cp_rw, cp_pslverr;

    endgroup : cg_system

    //----------------------------------------------------------
    // Constructor
    //----------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_system = new();
        has_prev  = 0;
    endfunction

    //----------------------------------------------------------
    // write() — called for every APB transaction observed
    //----------------------------------------------------------
    function void write(apb_seq_item t);
        trans = t;
        cg_system.sample();
        prev_trans = t;
        has_prev   = 1;
    endfunction

    //----------------------------------------------------------
    // Report Phase
    //----------------------------------------------------------
    function void report_phase(uvm_phase phase);
        real total = cg_system.get_coverage();
        $display("");
        $display("╔══════════════════════════════════════════╗");
        $display("║        SYSTEM COVERAGE SUMMARY           ║");
        $display("╠══════════════════════════════════════════╣");
        $display("║  Total Coverage   : %5.1f%%              ║", total);
        $display("║  RW Type          : %5.1f%%              ║",
                 cg_system.cp_rw.get_coverage());
        $display("║  Register Access  : %5.1f%%              ║",
                 cg_system.cp_reg.get_coverage());
        $display("║  Error (PSLVERR)  : %5.1f%%              ║",
                 cg_system.cp_pslverr.get_coverage());
        $display("║  Strobe Patterns  : %5.1f%%              ║",
                 cg_system.cp_strb.get_coverage());
        $display("║  RW x Register    : %5.1f%%              ║",
                 cg_system.cx_rw_reg.get_coverage());
        $display("║  RW x Error       : %5.1f%%              ║",
                 cg_system.cx_rw_err.get_coverage());
        $display("╚══════════════════════════════════════════╝");

        if (total < 100.0)
            `uvm_info("SYS_COV",
                $sformatf("Coverage at %.1f%% — run more tests", total), UVM_NONE)
        else
            `uvm_info("SYS_COV", "100%% coverage achieved!", UVM_NONE)
    endfunction

endclass : system_coverage
