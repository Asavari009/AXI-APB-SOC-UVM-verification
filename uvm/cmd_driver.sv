//============================================================
// File    : cmd_driver.sv
// Project : System UVM Testbench — Phase 6
// Purpose : UVM Driver for the Master command interface. 
//============================================================

class cmd_driver extends uvm_driver #(cmd_seq_item);
    `uvm_component_utils(cmd_driver)

    virtual axi4_lite_cmd_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual axi4_lite_cmd_if)::get(
                this, "", "cmd_vif", vif))
            `uvm_fatal("NOVIF", "cmd_driver: cmd_vif not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        cmd_seq_item req;
        init_signals();

        // Wait for reset
        if (!vif.ARESETn) @(posedge vif.ARESETn);
        repeat(2) @(posedge vif.ACLK);

        `uvm_info("CMD_DRV", "Reset released — driver ready", UVM_MEDIUM)

        forever begin
            seq_item_port.get_next_item(req);
            `uvm_info("CMD_DRV", req.convert2string(), UVM_HIGH)

            if (req.rw == cmd_seq_item::WRITE)
                drive_write(req);
            else
                drive_read(req);

            seq_item_port.item_done();
        end
    endtask

    //----------------------------------------------------------
    // Drive a write command
    //----------------------------------------------------------
    task drive_write(cmd_seq_item req);
        // Wait for master to be ready
        @(posedge vif.ACLK);
        while (!vif.cmd_ready) @(posedge vif.ACLK);

        // Issue write command
        vif.cmd_valid <= 1'b1;
        vif.cmd_write <= 1'b1;
        vif.cmd_addr  <= req.addr;
        vif.cmd_wdata <= req.data;
        vif.cmd_wstrb <= req.strb;
        vif.cmd_prot  <= req.prot;

        // Wait for command acceptance
        do @(posedge vif.ACLK); while (!vif.cmd_ready);
        vif.cmd_valid <= 1'b0;

        // Accept response (holds through bridge + APB latency)
        vif.rsp_ready <= 1'b1;
        do @(posedge vif.ACLK); while (!vif.rsp_valid);
        req.resp      = vif.rsp_resp;
        req.error     = vif.rsp_error;
        req.timeout_f = vif.rsp_timeout;
        vif.rsp_ready <= 1'b0;
        @(posedge vif.ACLK);
    endtask

    //----------------------------------------------------------
    // Drive a read command
    //----------------------------------------------------------
    task drive_read(cmd_seq_item req);
        @(posedge vif.ACLK);
        while (!vif.cmd_ready) @(posedge vif.ACLK);

        vif.cmd_valid <= 1'b1;
        vif.cmd_write <= 1'b0;
        vif.cmd_addr  <= req.addr;
        vif.cmd_prot  <= req.prot;

        do @(posedge vif.ACLK); while (!vif.cmd_ready);
        vif.cmd_valid <= 1'b0;

        vif.rsp_ready <= 1'b1;
        do @(posedge vif.ACLK); while (!vif.rsp_valid);
        req.rdata     = vif.rsp_rdata;
        req.resp      = vif.rsp_resp;
        req.error     = vif.rsp_error;
        req.timeout_f = vif.rsp_timeout;
        vif.rsp_ready <= 1'b0;
        @(posedge vif.ACLK);
    endtask

    task init_signals();
        vif.cmd_valid <= 0; vif.cmd_write <= 0;
        vif.cmd_addr  <= 0; vif.cmd_wdata <= 0;
        vif.cmd_wstrb <= 0; vif.cmd_prot  <= 0;
        vif.rsp_ready <= 0;
    endtask

endclass : cmd_driver
