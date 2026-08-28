//============================================================
// File    : system_pkg.sv
// Project : System UVM Testbench — Phase 6
// Purpose : Package wrapping all system UVM classes.
//
// _cmd → creates write_cmd() method
// _apb → creates write_apb() method
//============================================================

package system_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // ---- Analysis import type declarations ----
    `uvm_analysis_imp_decl(_cmd)
    `uvm_analysis_imp_decl(_apb)

    // ---- Transaction objects ----
    `include "cmd_seq_item.sv"
    `include "apb_seq_item.sv"

    // ---- CMD agent components ----
    `include "cmd_driver.sv"
    `include "cmd_monitor.sv"
    `include "cmd_agent.sv"

    // ---- APB agent components ----
    `include "apb_monitor.sv"
    `include "apb_agent.sv"

    // ---- Scoreboard + Coverage ----
    `include "e2e_scoreboard.sv"
    `include "system_coverage.sv"

    // ---- Environment ----
    `include "system_env.sv"

    // ---- Sequences + Tests ----
    `include "system_sequences.sv"
    `include "system_tests.sv"

endpackage : system_pkg
