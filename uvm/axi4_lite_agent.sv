//============================================================
// File    : axi4_lite_agent.sv
// Project : AXI4-Lite UVM Testbench
// Purpose : UVM Agent — container that groups the driver,
//           monitor, and sequencer into one reusable block.
//
// Modes:
//   UVM_ACTIVE  (default) : driver + sequencer + monitor
//   UVM_PASSIVE           : monitor only (no driving)
//============================================================

class axi4_lite_agent extends uvm_agent;
    `uvm_component_utils(axi4_lite_agent)

    //----------------------------------------------------------
    // Sub-components
    //----------------------------------------------------------
    axi4_lite_driver                        driver;
    axi4_lite_monitor                       monitor;
    uvm_sequencer #(axi4_lite_seq_item)     sequencer;

    //----------------------------------------------------------
    // Analysis Port
    // Forwards monitor output to env-level components.
    // Scoreboard and coverage connect here (Phase 3).
    //----------------------------------------------------------
    uvm_analysis_port #(axi4_lite_seq_item) ap;

    //----------------------------------------------------------
    // Constructor
    //----------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    //----------------------------------------------------------
    // Build Phase
    //----------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Analysis port always exists
        ap = new("ap", this);

        // Monitor always created — even in passive mode
        monitor = axi4_lite_monitor::type_id::create("monitor", this);

        // Driver + sequencer only in ACTIVE mode
        if (get_is_active() == UVM_ACTIVE) begin
            driver    = axi4_lite_driver::type_id::create("driver", this);
            sequencer = uvm_sequencer #(axi4_lite_seq_item)::type_id::create(
                            "sequencer", this);
            `uvm_info("AGENT", "Agent created in ACTIVE mode", UVM_MEDIUM)
        end else begin
            `uvm_info("AGENT", "Agent created in PASSIVE mode", UVM_MEDIUM)
        end
    endfunction

    //----------------------------------------------------------
    // Connect Phase
    //----------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        // Always: forward monitor AP to agent AP
        monitor.ap.connect(ap);

        // Active mode only: wire driver to sequencer
        if (get_is_active() == UVM_ACTIVE)
            driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

endclass : axi4_lite_agent
