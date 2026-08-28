//============================================================
// File    : axi4_lite_rand_test.sv
// Project : AXI4-Lite UVM Testbench — Phase 3
// Purpose : Constrained-random test.
//           Runs random transactions (80% valid / 20% DECERR)
//           followed by error injection.
//           Scoreboard checks every transaction automatically.
//           Coverage model measures what was hit.
//
// Run with: +UVM_TESTNAME=axi4_lite_rand_test
//============================================================

class axi4_lite_rand_test extends axi4_lite_base_test;
    `uvm_component_utils(axi4_lite_rand_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_lite_rand_seq  rand_seq;
        axi4_lite_error_seq err_seq;

        phase.raise_objection(this, "Starting random test");
        `uvm_info("TEST", "=== axi4_lite_rand_test START ===", UVM_LOW)

        // Phase A: 64 constrained-random transactions
        rand_seq = axi4_lite_rand_seq::type_id::create("rand_seq");
        rand_seq.num_transactions = 64;
        rand_seq.start(env.agent.sequencer);

        // Phase B: deliberate error injection
        err_seq = axi4_lite_error_seq::type_id::create("err_seq");
        err_seq.start(env.agent.sequencer);

        `uvm_info("TEST", "=== axi4_lite_rand_test DONE ===", UVM_LOW)
        phase.drop_objection(this, "Random test complete");
    endtask

endclass : axi4_lite_rand_test
