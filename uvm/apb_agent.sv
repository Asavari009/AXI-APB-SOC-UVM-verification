//============================================================
// File    : apb_agent.sv
// Project : System UVM Testbench — Phase 6
// Purpose : Passive APB agent — monitor only.
//           This agent observes what the bridge produces.
//============================================================

class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)

    apb_monitor                     monitor;
    uvm_analysis_port #(apb_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap      = new("ap", this);
        monitor = apb_monitor::type_id::create("monitor", this);
        `uvm_info("APB_AGENT", "Passive APB agent created", UVM_MEDIUM)
    endfunction

    function void connect_phase(uvm_phase phase);
        monitor.ap.connect(ap);
    endfunction

endclass : apb_agent
