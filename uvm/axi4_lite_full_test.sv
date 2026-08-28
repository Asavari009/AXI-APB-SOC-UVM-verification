//============================================================
// File    : axi4_lite_full_test.sv
// Project : AXI4-Lite UVM Testbench — Phase 3 Coverage Closure
// Purpose : Runs all four sequences back-to-back to achieve
//           maximum coverage closure.
//
// Sequence order:
//   1. reg_walk_seq  — hits all 16 registers, both directions
//   2. strobe_seq    — closes strobe pattern coverage gap
//   3. rand_seq      — random stimulus, 80/20 valid/DECERR split
//   4. error_seq     — deliberate bad addresses
//
// Run with: +UVM_TESTNAME=axi4_lite_full_test
//============================================================

class axi4_lite_full_test extends axi4_lite_base_test;
    `uvm_component_utils(axi4_lite_full_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_lite_reg_walk_seq  reg_walk;
        axi4_lite_strobe_seq    strobe;
        axi4_lite_rand_seq      rand_seq;
        axi4_lite_error_seq     err_seq;

        phase.raise_objection(this, "Full coverage test running");
        `uvm_info("TEST", "=== axi4_lite_full_test START ===", UVM_LOW)

        // ---- Step 1: Register walk ----
        // Writes + reads all 16 registers — basic correctness
        `uvm_info("TEST", "Step 1: Register walk", UVM_LOW)
        reg_walk = axi4_lite_reg_walk_seq::type_id::create("reg_walk");
        reg_walk.start(env.agent.sequencer);

        // ---- Step 2: Byte strobe patterns ----
        // Closes the 14.3% strobe coverage gap
        `uvm_info("TEST", "Step 2: Byte strobe patterns", UVM_LOW)
        strobe = axi4_lite_strobe_seq::type_id::create("strobe");
        strobe.start(env.agent.sequencer);

        // ---- Step 3: Constrained-random ----
        // Random addr/data/rw — fills remaining register cross coverage
        `uvm_info("TEST", "Step 3: Constrained-random (64 transactions)", UVM_LOW)
        rand_seq = axi4_lite_rand_seq::type_id::create("rand_seq");
        rand_seq.num_transactions = 64;
        rand_seq.start(env.agent.sequencer);

        // ---- Step 4: Error injection ----
        // DECERR on both read and write paths
        `uvm_info("TEST", "Step 4: Error injection", UVM_LOW)
        err_seq = axi4_lite_error_seq::type_id::create("err_seq");
        err_seq.start(env.agent.sequencer);

        `uvm_info("TEST", "=== axi4_lite_full_test DONE ===", UVM_LOW)
        phase.drop_objection(this, "Full coverage test complete");
    endtask

endclass : axi4_lite_full_test
