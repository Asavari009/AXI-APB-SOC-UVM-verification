//============================================================
// File    : system_tests.sv
// Project : System UVM Testbench — Phase 6
// Purpose : UVM Tests for the full system.
//
// Tests:
//   system_base_test  — register walk smoke test
//   system_rand_test  — 64 constrained-random transactions
//   system_full_test  — all sequences, coverage closure
//
// Run with: +UVM_TESTNAME=system_base_test
//           +UVM_TESTNAME=system_rand_test
//           +UVM_TESTNAME=system_full_test
//============================================================

//==============================================================
// Base Test — register walk through full system
//==============================================================
class system_base_test extends uvm_test;
    `uvm_component_utils(system_base_test)

    system_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = system_env::type_id::create("env", this);
        `uvm_info("TEST", "system_base_test build complete", UVM_MEDIUM)
    endfunction

    task run_phase(uvm_phase phase);
        system_reg_walk_seq seq;
        phase.raise_objection(this, "base test");
        `uvm_info("TEST", "=== system_base_test START ===", UVM_LOW)
        seq = system_reg_walk_seq::type_id::create("seq");
        seq.start(env.cmd_agnt.sequencer);
        `uvm_info("TEST", "=== system_base_test DONE ===", UVM_LOW)
        phase.drop_objection(this, "base test done");
    endtask

    function void report_phase(uvm_phase phase);
        uvm_report_server svr = uvm_report_server::get_server();
        if (svr.get_severity_count(UVM_FATAL) == 0 &&
            svr.get_severity_count(UVM_ERROR) == 0)
            `uvm_info("TEST", "*** TEST PASSED ***", UVM_NONE)
        else
            `uvm_info("TEST", "*** TEST FAILED ***", UVM_NONE)
    endfunction

endclass : system_base_test


//==============================================================
// Random Test — constrained-random + error injection
//==============================================================
class system_rand_test extends system_base_test;
    `uvm_component_utils(system_rand_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        system_rand_seq  rand_seq;
        system_error_seq err_seq;

        phase.raise_objection(this, "rand test");
        `uvm_info("TEST", "=== system_rand_test START ===", UVM_LOW)

        rand_seq = system_rand_seq::type_id::create("rand_seq");
        rand_seq.num_transactions = 64;
        rand_seq.start(env.cmd_agnt.sequencer);

        err_seq = system_error_seq::type_id::create("err_seq");
        err_seq.start(env.cmd_agnt.sequencer);

        `uvm_info("TEST", "=== system_rand_test DONE ===", UVM_LOW)
        phase.drop_objection(this, "rand test done");
    endtask

endclass : system_rand_test


//==============================================================
// Full Test — all sequences for maximum coverage closure
//==============================================================
class system_full_test extends system_base_test;
    `uvm_component_utils(system_full_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        system_reg_walk_seq  reg_walk;
        system_strobe_seq    strobe;
        system_rand_seq      rand_seq;
        system_error_seq     err_seq;

        phase.raise_objection(this, "full test");
        `uvm_info("TEST", "=== system_full_test START ===", UVM_LOW)

        // Step 1: Register walk — basic correctness
        `uvm_info("TEST", "Step 1: Register walk", UVM_LOW)
        reg_walk = system_reg_walk_seq::type_id::create("reg_walk");
        reg_walk.start(env.cmd_agnt.sequencer);

        // Step 2: Byte strobe patterns — close strobe coverage
        `uvm_info("TEST", "Step 2: Byte strobe patterns", UVM_LOW)
        strobe = system_strobe_seq::type_id::create("strobe");
        strobe.start(env.cmd_agnt.sequencer);

        // Step 3: Constrained-random — hit remaining bins
        `uvm_info("TEST", "Step 3: Constrained-random (64 txns)", UVM_LOW)
        rand_seq = system_rand_seq::type_id::create("rand_seq");
        rand_seq.num_transactions = 64;
        rand_seq.start(env.cmd_agnt.sequencer);

        // Step 4: Error injection — PSLVERR paths
        `uvm_info("TEST", "Step 4: Error injection", UVM_LOW)
        err_seq = system_error_seq::type_id::create("err_seq");
        err_seq.start(env.cmd_agnt.sequencer);

        `uvm_info("TEST", "=== system_full_test DONE ===", UVM_LOW)
        phase.drop_objection(this, "full test done");
    endtask

endclass : system_full_test
