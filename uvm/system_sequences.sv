//============================================================
// File    : system_sequences.sv
// Project : System UVM Testbench — Phase 6
// Purpose : Sequence library for the full system.
//           All sequences drive via cmd_seq_item which
//           flows: cmd_if -> Master -> AXI -> Bridge -> APB
//============================================================

//==============================================================
// 1. Base Sequence — helper tasks for all other sequences
//==============================================================
class system_base_seq extends uvm_sequence #(cmd_seq_item);
    `uvm_object_utils(system_base_seq)

    function new(string name = "system_base_seq");
        super.new(name);
    endfunction

    //----------------------------------------------------------
    // Normal write (uses constraints — valid address/strobe)
    //----------------------------------------------------------
    task do_write(
        input  bit [31:0] addr,
        input  bit [31:0] data,
        input  bit [3:0]  strb = 4'hF,
        output bit [1:0]  resp,
        output bit        err
    );
        cmd_seq_item item;
        item = cmd_seq_item::type_id::create("wr");
        start_item(item);
        item.rw   = cmd_seq_item::WRITE;
        item.addr = addr;
        item.data = data;
        item.strb = strb;
        item.prot = 3'b000;
        finish_item(item);
        resp = item.resp;
        err  = item.error;
        `uvm_info("SEQ",
            $sformatf("Write: addr=0x%08h data=0x%08h strb=0b%04b err=%0b",
                       addr, data, strb, err), UVM_MEDIUM)
    endtask

    //----------------------------------------------------------
    // Normal read
    //----------------------------------------------------------
    task do_read(
        input  bit [31:0] addr,
        output bit [31:0] rdata,
        output bit [1:0]  resp,
        output bit        err
    );
        cmd_seq_item item;
        item = cmd_seq_item::type_id::create("rd");
        start_item(item);
        item.rw   = cmd_seq_item::READ;
        item.addr = addr;
        item.prot = 3'b000;
        finish_item(item);
        rdata = item.rdata;
        resp  = item.resp;
        err   = item.error;
        `uvm_info("SEQ",
            $sformatf("Read:  addr=0x%08h rdata=0x%08h err=%0b",
                       addr, rdata, err), UVM_MEDIUM)
    endtask

    //----------------------------------------------------------
    // Raw write — bypasses constraints (for error injection)
    //----------------------------------------------------------
    task do_write_raw(
        input  bit [31:0] addr,
        input  bit [31:0] data,
        input  bit [3:0]  strb,
        output bit [1:0]  resp,
        output bit        err
    );
        cmd_seq_item item;
        item = cmd_seq_item::type_id::create("wr_raw");
        start_item(item);
        item.rw   = cmd_seq_item::WRITE;
        item.addr = addr;
        item.data = data;
        item.strb = strb;
        item.prot = 3'b000;
        finish_item(item);
        resp = item.resp;
        err  = item.error;
        `uvm_info("SEQ",
            $sformatf("Write(raw): addr=0x%08h data=0x%08h err=%0b",
                       addr, data, err), UVM_MEDIUM)
    endtask

    //----------------------------------------------------------
    // Raw read — bypasses constraints (for error injection)
    //----------------------------------------------------------
    task do_read_raw(
        input  bit [31:0] addr,
        output bit [31:0] rdata,
        output bit [1:0]  resp,
        output bit        err
    );
        cmd_seq_item item;
        item = cmd_seq_item::type_id::create("rd_raw");
        start_item(item);
        item.rw   = cmd_seq_item::READ;
        item.addr = addr;
        item.prot = 3'b000;
        finish_item(item);
        rdata = item.rdata;
        resp  = item.resp;
        err   = item.error;
        `uvm_info("SEQ",
            $sformatf("Read (raw): addr=0x%08h rdata=0x%08h err=%0b",
                       addr, rdata, err), UVM_MEDIUM)
    endtask

endclass : system_base_seq


//==============================================================
// 2. Register Walk — write and read back all 16 APB registers
//==============================================================
class system_reg_walk_seq extends system_base_seq;
    `uvm_object_utils(system_reg_walk_seq)

    localparam int NUM_REGS = 16;

    function new(string name = "system_reg_walk_seq");
        super.new(name);
    endfunction

    task body();
        bit [31:0] rdata;
        bit [1:0]  resp;
        bit        err;
        int        pass_cnt = 0;
        int        fail_cnt = 0;

        `uvm_info("SEQ", "=== System Register Walk START ===", UVM_LOW)

        // Write all registers
        `uvm_info("SEQ", "Writing all APB registers...", UVM_MEDIUM)
        for (int i = 0; i < NUM_REGS; i++) begin
            bit [1:0] wr_resp; bit wr_err;
            do_write(i*4, 32'hC000_0000 + i, 4'hF, wr_resp, wr_err);
        end

        // Read back and verify
        `uvm_info("SEQ", "Reading back all APB registers...", UVM_MEDIUM)
        for (int i = 0; i < NUM_REGS; i++) begin
            bit [31:0] expected = 32'hC000_0000 + i;
            do_read(i*4, rdata, resp, err);
            if (rdata === expected) begin
                `uvm_info("SEQ",
                    $sformatf("reg[%0d] PASS got=0x%08h", i, rdata), UVM_HIGH)
                pass_cnt++;
            end else begin
                `uvm_error("SEQ",
                    $sformatf("reg[%0d] FAIL got=0x%08h exp=0x%08h",
                               i, rdata, expected))
                fail_cnt++;
            end
        end

        `uvm_info("SEQ",
            $sformatf("=== Register Walk DONE PASS=%0d FAIL=%0d ===",
                       pass_cnt, fail_cnt), UVM_LOW)
    endtask

endclass : system_reg_walk_seq


//==============================================================
// 3. Constrained Random Sequence
//    80% valid addresses, 20% out-of-range (PSLVERR path)
//==============================================================
class system_rand_seq extends system_base_seq;
    `uvm_object_utils(system_rand_seq)

    int unsigned num_transactions = 64;

    function new(string name = "system_rand_seq");
        super.new(name);
    endfunction

    task body();
        cmd_seq_item item;
        `uvm_info("SEQ",
            $sformatf("=== Random Sequence START (%0d txns) ===",
                       num_transactions), UVM_LOW)

        for (int i = 0; i < num_transactions; i++) begin
            item = cmd_seq_item::type_id::create("rand_item");
            start_item(item);
            if (!item.randomize() with {
                    addr[1:0] == 2'b00;
                    addr dist {
                        [32'h00:32'h3C] :/ 80,
                        [32'h40:32'hFF] :/ 20
                    };
                    strb != 4'b0000; })
                `uvm_fatal("RAND", "system_rand_seq randomization failed")
            finish_item(item);
        end

        `uvm_info("SEQ", "=== Random Sequence DONE ===", UVM_LOW)
    endtask

endclass : system_rand_seq


//==============================================================
// 4. Error Injection Sequence
//    Tests PSLVERR -> SLVERR propagation through bridge
//==============================================================
class system_error_seq extends system_base_seq;
    `uvm_object_utils(system_error_seq)

    function new(string name = "system_error_seq");
        super.new(name);
    endfunction

    task body();
        bit [31:0] rdata;
        bit [1:0]  resp;
        bit        err;

        `uvm_info("SEQ", "=== Error Injection Sequence START ===", UVM_LOW)

        // Out-of-range write → PSLVERR → SLVERR
        do_write_raw(32'hFFFF_0000, 32'hBAD_BABE, 4'hF, resp, err);
        if (err)
            `uvm_info("SEQ", "OOB write error propagated correctly", UVM_MEDIUM)
        else
            `uvm_error("SEQ", "OOB write should have returned error")

        // Out-of-range read → PSLVERR → SLVERR
        do_read_raw(32'hFFFF_0000, rdata, resp, err);
        if (err)
            `uvm_info("SEQ", "OOB read error propagated correctly", UVM_MEDIUM)
        else
            `uvm_error("SEQ", "OOB read should have returned error")

        // Unaligned address → PSLVERR
        do_write_raw(32'h0000_0001, 32'h1234_5678, 4'hF, resp, err);
        if (err)
            `uvm_info("SEQ", "Unaligned write error propagated correctly", UVM_MEDIUM)
        else
            `uvm_error("SEQ", "Unaligned write should have returned error")

        `uvm_info("SEQ", "=== Error Injection Sequence DONE ===", UVM_LOW)
    endtask

endclass : system_error_seq


//==============================================================
// 5. Byte Strobe Sequence — exercises all 7 strobe patterns
//==============================================================
class system_strobe_seq extends system_base_seq;
    `uvm_object_utils(system_strobe_seq)

    function new(string name = "system_strobe_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "=== Byte Strobe Sequence START ===", UVM_LOW)
        run_strobe(32'h00, 4'b0001);   // byte 0
        run_strobe(32'h04, 4'b0010);   // byte 1
        run_strobe(32'h08, 4'b0100);   // byte 2
        run_strobe(32'h0C, 4'b1000);   // byte 3
        run_strobe(32'h10, 4'b0011);   // lower half-word
        run_strobe(32'h14, 4'b1100);   // upper half-word
        run_strobe(32'h18, 4'b1111);   // full word
        `uvm_info("SEQ", "=== Byte Strobe Sequence DONE ===", UVM_LOW)
    endtask

    task run_strobe(input bit [31:0] addr, input bit [3:0] strb);
        bit [31:0] rdata;
        bit [1:0]  resp;
        bit        err;
        bit [31:0] expected;

        // Seed with all 1s
        do_write(addr, 32'hFFFF_FFFF, 4'hF, resp, err);

        // Write with specific strobe (raw to bypass c_strb_full)
        do_write_raw(addr, 32'h1234_5678, strb, resp, err);

        // Calculate expected
        expected = 32'hFFFF_FFFF;
        if (strb[0]) expected[ 7: 0] = 8'h78;
        if (strb[1]) expected[15: 8] = 8'h56;
        if (strb[2]) expected[23:16] = 8'h34;
        if (strb[3]) expected[31:24] = 8'h12;

        // Read back
        do_read(addr, rdata, resp, err);

        if (rdata === expected)
            `uvm_info("SEQ",
                $sformatf("Strobe 0b%04b PASS addr=0x%02h got=0x%08h",
                           strb, addr, rdata), UVM_MEDIUM)
        else
            `uvm_error("SEQ",
                $sformatf("Strobe 0b%04b FAIL addr=0x%02h got=0x%08h exp=0x%08h",
                           strb, addr, rdata, expected))
    endtask

endclass : system_strobe_seq
