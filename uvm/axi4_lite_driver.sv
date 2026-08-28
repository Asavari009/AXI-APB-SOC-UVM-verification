//============================================================
// File    : axi4_lite_driver.sv
// Project : AXI4-Lite UVM Testbench
// Purpose : UVM Driver — pulls seq_items from the sequencer
//           and drives all 5 AXI4-Lite channels on the
//           virtual interface.
//============================================================

class axi4_lite_driver extends uvm_driver #(axi4_lite_seq_item);
    `uvm_component_utils(axi4_lite_driver)

    //----------------------------------------------------------
    // Virtual Interface Handle
    //----------------------------------------------------------
    virtual axi4_lite_if vif;

    //----------------------------------------------------------
    // Constructor
    //----------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    //----------------------------------------------------------
    // Build Phase — get virtual interface from config_db
    //----------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual axi4_lite_if)::get(
                this, "", "vif", vif))
            `uvm_fatal("NOVIF", "axi4_lite_driver: virtual interface not found. Check uvm_config_db in tb_top_uvm.")
    endfunction

    //----------------------------------------------------------
    // Run Phase — Main Driver Loop
    //----------------------------------------------------------
    task run_phase(uvm_phase phase);
        axi4_lite_seq_item req;

        // Drive all master-side signals to 0
        init_signals();

        // Wait for reset to deassert (handle already-deasserted case)
        if (!vif.ARESETn) @(posedge vif.ARESETn);
        repeat(2) @(posedge vif.ACLK);

        `uvm_info("DRV", "Reset released — driver entering main loop", UVM_MEDIUM)

        forever begin
            // Blocking get from sequencer
            seq_item_port.get_next_item(req);

            `uvm_info("DRV",
                $sformatf("Got item: %s", req.convert2string()), UVM_HIGH)

            // Dispatch to correct channel handler
            if (req.rw == axi4_lite_seq_item::WRITE)
                drive_write(req);
            else
                drive_read(req);

            seq_item_port.item_done();
        end
    endtask

    //----------------------------------------------------------
    // Drive Write Transaction
    //----------------------------------------------------------
    task drive_write(axi4_lite_seq_item req);
        @(posedge vif.ACLK);

        // Assert both channels at once
        vif.AWVALID <= 1'b1;
        vif.AWADDR  <= req.addr;
        vif.AWPROT  <= req.prot;
        vif.WVALID  <= 1'b1;
        vif.WDATA   <= req.data;
        vif.WSTRB   <= req.strb;

        // ---- FORK: AW and W handshakes in parallel ----
        fork
            begin : aw_handshake
                do @(posedge vif.ACLK); while (!vif.AWREADY);
                vif.AWVALID <= 1'b0;
            end
            begin : w_handshake
                do @(posedge vif.ACLK); while (!vif.WREADY);
                vif.WVALID <= 1'b0;
            end
        join
        // ------------------------------------------------

        // Accept B response
        vif.BREADY <= 1'b1;
        do @(posedge vif.ACLK); while (!vif.BVALID);

        // Write response back into seq_item for scoreboard use
        req.resp = vif.BRESP;

        vif.BREADY <= 1'b0;
        @(posedge vif.ACLK);

        `uvm_info("DRV",
            $sformatf("Write done  addr=0x%08h  data=0x%08h  BRESP=0b%02b",
                       req.addr, req.data, req.resp), UVM_HIGH)
    endtask

    //----------------------------------------------------------
    // Drive Read Transaction
    //----------------------------------------------------------
    task drive_read(axi4_lite_seq_item req);
        @(posedge vif.ACLK);
        vif.ARVALID <= 1'b1;
        vif.ARADDR  <= req.addr;
        vif.ARPROT  <= req.prot;

        // AR handshake
        do @(posedge vif.ACLK); while (!vif.ARREADY);
        vif.ARVALID <= 1'b0;

        // Accept R response
        vif.RREADY <= 1'b1;
        do @(posedge vif.ACLK); while (!vif.RVALID);

        // Write response and data back into seq_item
        req.rdata = vif.RDATA;
        req.resp  = vif.RRESP;

        vif.RREADY <= 1'b0;
        @(posedge vif.ACLK);

        `uvm_info("DRV",
            $sformatf("Read  done  addr=0x%08h  rdata=0x%08h  RRESP=0b%02b",
                       req.addr, req.rdata, req.resp), UVM_HIGH)
    endtask

    //----------------------------------------------------------
    // Initialise all master-side signals
    //----------------------------------------------------------
    task init_signals();
        vif.AWVALID <= 0;  vif.AWADDR <= 0;  vif.AWPROT <= 0;
        vif.WVALID  <= 0;  vif.WDATA  <= 0;  vif.WSTRB  <= 0;
        vif.BREADY  <= 0;
        vif.ARVALID <= 0;  vif.ARADDR <= 0;  vif.ARPROT <= 0;
        vif.RREADY  <= 0;
    endtask

endclass : axi4_lite_driver