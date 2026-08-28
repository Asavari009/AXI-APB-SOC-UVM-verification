//============================================================
// File    : axi4_lite_monitor.sv
// Project : AXI4-Lite UVM Testbench
// Purpose : UVM Monitor — passively observes all 5 AXI4-Lite
//           channels without driving anything.
//           Assembles complete transactions and broadcasts
//           them via an analysis port to the scoreboard
//           and coverage collector.
//
// Two independent threads run in parallel:
//   - monitor_write_channel : AW + W + B -> write transaction
//   - monitor_read_channel  : AR + R     -> read transaction
//============================================================

class axi4_lite_monitor extends uvm_monitor;
    `uvm_component_utils(axi4_lite_monitor)

    //----------------------------------------------------------
    // Virtual Interface (monitor modport — for observation only)
    //----------------------------------------------------------
    virtual axi4_lite_if vif;

    //----------------------------------------------------------
    // Analysis Port — broadcasts captured transactions
    // Connected to: scoreboard, coverage (Phase 3)
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
        ap = new("ap", this);
        if (!uvm_config_db #(virtual axi4_lite_if)::get(
                this, "", "vif", vif))
            `uvm_fatal("NOVIF",
                "axi4_lite_monitor: virtual interface not found in config_db.")
    endfunction

    //----------------------------------------------------------
    // Run Phase — Spawn both channel monitors
    //----------------------------------------------------------
    task run_phase(uvm_phase phase);
        // Wait for reset to deassert before monitoring
        if (!vif.ARESETn) @(posedge vif.ARESETn);
        @(posedge vif.ACLK);

        `uvm_info("MON", "Reset released — monitor active", UVM_MEDIUM)

        // Run write and read monitors as permanent background threads
        fork
            monitor_write_channel();
            monitor_read_channel();
        join_none
    endtask

    //----------------------------------------------------------
    // Write Channel Monitor
    //
    // Captures AW and W handshakes in parallel (any order),
    // then waits for B response to complete the transaction.
    //----------------------------------------------------------
    task monitor_write_channel();
        forever begin
            axi4_lite_seq_item trans;
            bit [31:0] cap_addr;
            bit [2:0]  cap_prot;
            bit [31:0] cap_data;
            bit [3:0]  cap_strb;

            trans    = axi4_lite_seq_item::type_id::create("mon_wr");
            trans.rw = axi4_lite_seq_item::WRITE;

            // ---- Capture AW and W handshakes in parallel ----
            // AW and W may arrive in any order; fork handles both
            fork
                begin : cap_aw
                    do @(posedge vif.ACLK);
                    while (!(vif.AWVALID && vif.AWREADY));
                    cap_addr = vif.AWADDR;
                    cap_prot = vif.AWPROT;
                end
                begin : cap_w
                    do @(posedge vif.ACLK);
                    while (!(vif.WVALID && vif.WREADY));
                    cap_data = vif.WDATA;
                    cap_strb = vif.WSTRB;
                end
            join
            // -------------------------------------------------

            trans.addr = cap_addr;
            trans.prot = cap_prot;
            trans.data = cap_data;
            trans.strb = cap_strb;

            // ---- Capture B response ----
            do @(posedge vif.ACLK);
            while (!(vif.BVALID && vif.BREADY));
            trans.resp = vif.BRESP;

            `uvm_info("MON",
                $sformatf("Observed: %s", trans.convert2string()), UVM_HIGH)

            // Broadcast completed transaction to scoreboard/coverage
            ap.write(trans);
        end
    endtask

    //----------------------------------------------------------
    // Read Channel Monitor
    //
    // Captures AR handshake, then R data/response.
    //----------------------------------------------------------
    task monitor_read_channel();
        forever begin
            axi4_lite_seq_item trans;

            trans    = axi4_lite_seq_item::type_id::create("mon_rd");
            trans.rw = axi4_lite_seq_item::READ;

            // ---- Capture AR handshake ----
            do @(posedge vif.ACLK);
            while (!(vif.ARVALID && vif.ARREADY));
            trans.addr = vif.ARADDR;
            trans.prot = vif.ARPROT;

            // ---- Capture R data/response ----
            do @(posedge vif.ACLK);
            while (!(vif.RVALID && vif.RREADY));
            trans.rdata = vif.RDATA;
            trans.resp  = vif.RRESP;

            `uvm_info("MON",
                $sformatf("Observed: %s", trans.convert2string()), UVM_HIGH)

            ap.write(trans);
        end
    endtask

endclass : axi4_lite_monitor
