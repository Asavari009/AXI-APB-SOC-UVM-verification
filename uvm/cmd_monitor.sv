//============================================================
// File    : cmd_monitor.sv
// Project : System UVM Testbench — Phase 6
// Purpose : Passively monitors the Master command interface.
//           Captures both the command handshake and response
//           handshake, assembles into cmd_seq_item, and
//           broadcasts to scoreboard.
//============================================================

class cmd_monitor extends uvm_monitor;
    `uvm_component_utils(cmd_monitor)

    virtual axi4_lite_cmd_if vif;
    uvm_analysis_port #(cmd_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual axi4_lite_cmd_if)::get(
                this, "", "cmd_vif", vif))
            `uvm_fatal("NOVIF", "cmd_monitor: cmd_vif not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        if (!vif.ARESETn) @(posedge vif.ARESETn);
        @(posedge vif.ACLK);
        `uvm_info("CMD_MON", "Monitor active", UVM_MEDIUM)

        forever begin
            cmd_seq_item trans;
            trans = cmd_seq_item::type_id::create("mon_cmd");

            // Step 1: Capture command handshake
            do @(posedge vif.ACLK);
            while (!(vif.cmd_valid && vif.cmd_ready));

            trans.rw   = vif.cmd_write ?
                         cmd_seq_item::WRITE : cmd_seq_item::READ;
            trans.addr = vif.cmd_addr;
            trans.data = vif.cmd_wdata;
            trans.strb = vif.cmd_wstrb;
            trans.prot = vif.cmd_prot;

            // Step 2: Capture response handshake
            // (comes after bridge processes through APB)
            do @(posedge vif.ACLK);
            while (!(vif.rsp_valid && vif.rsp_ready));

            trans.rdata     = vif.rsp_rdata;
            trans.resp      = vif.rsp_resp;
            trans.error     = vif.rsp_error;
            trans.timeout_f = vif.rsp_timeout;

            `uvm_info("CMD_MON",
                $sformatf("Observed: %s", trans.convert2string()), UVM_HIGH)

            ap.write(trans);
        end
    endtask

endclass : cmd_monitor
