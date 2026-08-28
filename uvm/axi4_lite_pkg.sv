//============================================================
// File    : axi4_lite_pkg.sv
// Project : AXI4-Lite UVM Testbench — Phase 3 
//============================================================

package axi4_lite_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // 1. Transaction object
    `include "axi4_lite_seq_item.sv"

    // 2. Driver + Monitor
    `include "axi4_lite_driver.sv"
    `include "axi4_lite_monitor.sv"

    // 3. Agent
    `include "axi4_lite_agent.sv"

    // 4. Sequences (write, read, wr_rd, reg_walk, rand, error, strobe)
    `include "axi4_lite_sequences.sv"

    // 5. Scoreboard + Coverage
    `include "axi4_lite_scoreboard.sv"
    `include "axi4_lite_coverage.sv"

    // 6. Environment
    `include "axi4_lite_env.sv"

    // 7. Tests
    `include "axi4_lite_base_test.sv"
    `include "axi4_lite_rand_test.sv"
    `include "axi4_lite_full_test.sv"

endpackage : axi4_lite_pkg
