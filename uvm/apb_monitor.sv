//============================================================
// File    : apb_monitor.sv
// Project : System UVM Testbench — Phase 6
// Purpose : Passively monitors the APB bus between bridge
//           and slave. Captures SETUP + ACCESS phases and
//           broadcasts completed transactions.
//
// APB capture sequence:
//   SETUP:  PSEL=1, PENABLE=0 -> capture addr/ctrl/data
//   ACCESS: PSEL=1, PENABLE=1, PREADY=1 -> capture response
//============================================================

class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)

    virtual apb_if vif;
    uvm_analysis_port #(apb_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual apb_if)::get(
                this, "", "apb_vif", vif))
            `uvm_fatal("NOVIF", "apb_monitor: apb_vif not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        if (!vif.PRESETn) @(posedge vif.PRESETn);
        @(posedge vif.PCLK);
        `uvm_info("APB_MON", "APB monitor active", UVM_MEDIUM)

        forever begin
            apb_seq_item trans;
            trans = apb_seq_item::type_id::create("mon_apb");

            // Step 1: Wait for SETUP phase (PSEL=1, PENABLE=0)
            do @(posedge vif.PCLK);
            while (!(vif.PSEL && !vif.PENABLE));

            // Capture control/address/data from SETUP phase
            trans.paddr  = vif.PADDR;
            trans.pwrite = vif.PWRITE;
            trans.pwdata = vif.PWDATA;
            trans.pstrb  = vif.PSTRB;
            trans.pprot  = vif.PPROT;

            // Step 2: Wait for ACCESS phase completion (PREADY=1)
            do @(posedge vif.PCLK);
            while (!(vif.PSEL && vif.PENABLE && vif.PREADY));

            // Capture response from ACCESS phase
            trans.prdata  = vif.PRDATA;
            trans.pslverr = vif.PSLVERR;

            `uvm_info("APB_MON",
                $sformatf("Observed: %s", trans.convert2string()), UVM_HIGH)

            ap.write(trans);
        end
    endtask

endclass : apb_monitor
