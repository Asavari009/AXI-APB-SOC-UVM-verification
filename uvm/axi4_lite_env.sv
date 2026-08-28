//============================================================
// File    : axi4_lite_env.sv
// Project : AXI4-Lite UVM Testbench — Phase 3
// Purpose : UVM Environment — the top-level container that
//           wires the agent, scoreboard, and coverage together.
//============================================================

class axi4_lite_env extends uvm_env;
    `uvm_component_utils(axi4_lite_env)

    //----------------------------------------------------------
    // Sub-components
    //----------------------------------------------------------
    axi4_lite_agent       agent;
    axi4_lite_scoreboard  scoreboard;
    axi4_lite_coverage    coverage;

    //----------------------------------------------------------
    // Constructor
    //----------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    //----------------------------------------------------------
    // Build Phase — create all sub-components
    //----------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        agent      = axi4_lite_agent::type_id::create("agent",      this);
        scoreboard = axi4_lite_scoreboard::type_id::create("scoreboard", this);
        coverage   = axi4_lite_coverage::type_id::create("coverage", this);

        // Set agent to active mode
        uvm_config_db #(uvm_active_passive_enum)::set(
            this, "agent", "is_active", UVM_ACTIVE);

        `uvm_info("ENV", "Environment build complete", UVM_MEDIUM)
    endfunction

    //----------------------------------------------------------
    // Connect Phase — wire analysis ports
    //----------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        // Agent monitor → Scoreboard
        agent.ap.connect(scoreboard.analysis_export);

        // Agent monitor → Coverage
        agent.ap.connect(coverage.analysis_export);

        `uvm_info("ENV", "Analysis ports connected: agent -> scoreboard + coverage", UVM_MEDIUM)
    endfunction

endclass : axi4_lite_env
