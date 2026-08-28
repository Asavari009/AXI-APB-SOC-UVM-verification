//============================================================
// File    : system_env.sv
// Project : System UVM Testbench — Phase 6
// Purpose : Top-level UVM environment for the full system.
//
// Components:
//   cmd_agent    — ACTIVE: drives Master command interface
//   apb_agent    — PASSIVE: observes APB bus
//   e2e_scoreboard — cross-protocol checker
//   system_coverage — functional coverage model
//
// Analysis port connections:
//   cmd_agent.ap  -> scoreboard.cmd_export
//   apb_agent.ap  -> scoreboard.apb_export
//   apb_agent.ap  -> coverage.analysis_export
//============================================================

class system_env extends uvm_env;
    `uvm_component_utils(system_env)

    cmd_agent        cmd_agnt;
    apb_agent        apb_agnt;
    e2e_scoreboard   scoreboard;
    system_coverage  coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        cmd_agnt   = cmd_agent::type_id::create("cmd_agnt",   this);
        apb_agnt   = apb_agent::type_id::create("apb_agnt",   this);
        scoreboard = e2e_scoreboard::type_id::create("scoreboard", this);
        coverage   = system_coverage::type_id::create("coverage", this);

        // CMD agent always active
        uvm_config_db #(uvm_active_passive_enum)::set(this, "cmd_agnt", "is_active", UVM_ACTIVE);

        // APB agent always passive
        uvm_config_db #(uvm_active_passive_enum)::set(this, "apb_agnt", "is_active", UVM_PASSIVE);

        `uvm_info("SYS_ENV", "System environment built", UVM_MEDIUM)
    endfunction

    function void connect_phase(uvm_phase phase);
        // CMD monitor -> scoreboard
        cmd_agnt.ap.connect(scoreboard.cmd_export);

        // APB monitor -> scoreboard + coverage
        apb_agnt.ap.connect(scoreboard.apb_export);
        apb_agnt.ap.connect(coverage.analysis_export);

        `uvm_info("SYS_ENV", "Analysis ports connected", UVM_MEDIUM)
    endfunction

endclass : system_env
