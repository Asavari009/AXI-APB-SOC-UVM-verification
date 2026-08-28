//============================================================
// File    : cmd_agent.sv
// Project : System UVM Testbench — Phase 6
// Purpose : Active UVM agent for the command interface.
//           Contains driver + monitor + sequencer.
//           Drives the Master RTL command port.
//============================================================

class cmd_agent extends uvm_agent;
    `uvm_component_utils(cmd_agent)

    cmd_driver                      driver;
    cmd_monitor                     monitor;
    uvm_sequencer #(cmd_seq_item)   sequencer;

    uvm_analysis_port #(cmd_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap      = new("ap", this);
        monitor = cmd_monitor::type_id::create("monitor", this);

        if (get_is_active() == UVM_ACTIVE) begin
            driver    = cmd_driver::type_id::create("driver", this);
            sequencer = uvm_sequencer #(cmd_seq_item)::type_id::create(
                            "sequencer", this);
            `uvm_info("CMD_AGENT", "Active mode", UVM_MEDIUM)
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        monitor.ap.connect(ap);
        if (get_is_active() == UVM_ACTIVE)
            driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

endclass : cmd_agent
