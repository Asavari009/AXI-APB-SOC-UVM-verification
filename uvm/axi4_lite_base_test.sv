//============================================================
// File    : axi4_lite_base_test.sv
// Project : AXI4-Lite UVM Testbench — Phase 3
// Purpose : Uses axi4_lite_env (agent + scoreboard + coverage)
//           Runs register walk as smoke test
//============================================================

class axi4_lite_base_test extends uvm_test;
    `uvm_component_utils(axi4_lite_base_test)

    axi4_lite_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = axi4_lite_env::type_id::create("env", this);
        `uvm_info("TEST", "Build phase complete", UVM_MEDIUM)
    endfunction

    task run_phase(uvm_phase phase);
        axi4_lite_reg_walk_seq seq;
        phase.raise_objection(this, "Starting reg walk");
        `uvm_info("TEST", "=== axi4_lite_base_test START ===", UVM_LOW)
        seq = axi4_lite_reg_walk_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);
        `uvm_info("TEST", "=== axi4_lite_base_test DONE ===", UVM_LOW)
        phase.drop_objection(this, "Reg walk complete");
    endtask

    function void report_phase(uvm_phase phase);
        uvm_report_server svr = uvm_report_server::get_server();
        if (svr.get_severity_count(UVM_FATAL) == 0 &&
            svr.get_severity_count(UVM_ERROR) == 0)
            `uvm_info("TEST", "*** TEST PASSED ***", UVM_NONE)
        else
            `uvm_info("TEST", "*** TEST FAILED — check errors above ***", UVM_NONE)
    endfunction

endclass : axi4_lite_base_test
