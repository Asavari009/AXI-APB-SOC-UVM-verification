//============================================================
// File    : axi4_lite_sequences.sv
// Project : AXI4-Lite UVM Testbench
//============================================================

//==============================================================
// 1. Base Sequence
//==============================================================
class axi4_lite_base_seq extends uvm_sequence #(axi4_lite_seq_item);
    `uvm_object_utils(axi4_lite_base_seq)

    function new(string name = "axi4_lite_base_seq");
        super.new(name);
    endfunction

    //----------------------------------------------------------
    // Normal write — uses constraints (valid address range)
    //----------------------------------------------------------
    task do_write(
        input  bit [31:0] addr,
        input  bit [31:0] data,
        input  bit [3:0]  strb  = 4'hF,
        input  bit [2:0]  prot  = 3'b000,
        output bit [1:0]  resp
    );
        axi4_lite_seq_item item;
        item = axi4_lite_seq_item::type_id::create("wr_item");
        start_item(item);
        if (!item.randomize() with {
                rw   == axi4_lite_seq_item::WRITE;
                addr == local::addr;
                data == local::data;
                strb == local::strb;
                prot == local::prot; })
            `uvm_fatal("RAND_FAIL", "Write item randomization failed")
        finish_item(item);
        resp = item.resp;
        `uvm_info("SEQ",
            $sformatf("Write: addr=0x%08h data=0x%08h strb=0b%04b BRESP=0b%02b",
                       addr, data, strb, resp), UVM_MEDIUM)
    endtask

    //----------------------------------------------------------
    // Normal read — uses constraints (valid address range)
    //----------------------------------------------------------
    task do_read(
        input  bit [31:0] addr,
        output bit [31:0] rdata,
        output bit [1:0]  resp,
        input  bit [2:0]  prot = 3'b000
    );
        axi4_lite_seq_item item;
        item = axi4_lite_seq_item::type_id::create("rd_item");
        start_item(item);
        if (!item.randomize() with {
                rw   == axi4_lite_seq_item::READ;
                addr == local::addr;
                prot == local::prot; })
            `uvm_fatal("RAND_FAIL", "Read item randomization failed")
        finish_item(item);
        rdata = item.rdata;
        resp  = item.resp;
        `uvm_info("SEQ",
            $sformatf("Read:  addr=0x%08h rdata=0x%08h RRESP=0b%02b",
                       addr, rdata, resp), UVM_MEDIUM)
    endtask

    //----------------------------------------------------------
    // RAW write — bypasses ALL constraints.
    // Used mainly for error injection: out-of-range or unaligned
    // addresses that would conflict with c_addr_in_range.
    //----------------------------------------------------------
    task do_write_raw(
        input  bit [31:0] addr,
        input  bit [31:0] data,
        input  bit [3:0]  strb,
        output bit [1:0]  resp
    );
        axi4_lite_seq_item item;
        item = axi4_lite_seq_item::type_id::create("raw_wr_item");
        start_item(item);
        // Directly assign — no randomize(), no constraints
        item.rw   = axi4_lite_seq_item::WRITE;
        item.addr = addr;
        item.data = data;
        item.strb = strb;
        item.prot = 3'b000;
        finish_item(item);
        resp = item.resp;
        `uvm_info("SEQ",
            $sformatf("Write(raw): addr=0x%08h data=0x%08h BRESP=0b%02b",
                       addr, data, resp), UVM_MEDIUM)
    endtask

    //----------------------------------------------------------
    // RAW read — bypasses ALL constraints.
    //----------------------------------------------------------
    task do_read_raw(
        input  bit [31:0] addr,
        output bit [31:0] rdata,
        output bit [1:0]  resp
    );
        axi4_lite_seq_item item;
        item = axi4_lite_seq_item::type_id::create("raw_rd_item");
        start_item(item);
        item.rw   = axi4_lite_seq_item::READ;
        item.addr = addr;
        item.strb = 4'hF;
        item.prot = 3'b000;
        finish_item(item);
        rdata = item.rdata;
        resp  = item.resp;
        `uvm_info("SEQ",
            $sformatf("Read (raw): addr=0x%08h rdata=0x%08h RRESP=0b%02b",
                       addr, rdata, resp), UVM_MEDIUM)
    endtask

endclass : axi4_lite_base_seq


//==============================================================
// 2. Single Write Sequence
//==============================================================
class axi4_lite_write_seq extends axi4_lite_base_seq;
    `uvm_object_utils(axi4_lite_write_seq)

    bit [31:0] addr = 32'h00;
    bit [31:0] data = 32'hDEAD_BEEF;
    bit [3:0]  strb = 4'hF;

    function new(string name = "axi4_lite_write_seq");
        super.new(name);
    endfunction

    task body();
        bit [1:0] resp;
        `uvm_info("SEQ", "=== Single Write Sequence ===", UVM_MEDIUM)
        do_write(addr, data, strb, 3'b000, resp);
    endtask

endclass : axi4_lite_write_seq


//==============================================================
// 3. Single Read Sequence
//==============================================================
class axi4_lite_read_seq extends axi4_lite_base_seq;
    `uvm_object_utils(axi4_lite_read_seq)

    bit [31:0] addr  = 32'h00;
    bit [31:0] rdata;
    bit [1:0]  resp;

    function new(string name = "axi4_lite_read_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "=== Single Read Sequence ===", UVM_MEDIUM)
        do_read(addr, rdata, resp);
    endtask

endclass : axi4_lite_read_seq


//==============================================================
// 4. Write then Read-back Sequence
//==============================================================
class axi4_lite_wr_rd_seq extends axi4_lite_base_seq;
    `uvm_object_utils(axi4_lite_wr_rd_seq)

    bit [31:0] addr = 32'h00;
    bit [31:0] data = 32'hCAFE_BABE;

    function new(string name = "axi4_lite_wr_rd_seq");
        super.new(name);
    endfunction

    task body();
        bit [31:0] rdata;
        bit [1:0]  wr_resp, rd_resp;
        `uvm_info("SEQ", "=== Write-Read-back Sequence ===", UVM_MEDIUM)
        do_write(addr, data, 4'hF, 3'b000, wr_resp);
        do_read (addr, rdata, rd_resp);
        if (rdata === data)
            `uvm_info("SEQ",
                $sformatf("Write/read-back MATCH addr=0x%08h data=0x%08h",
                           addr, rdata), UVM_LOW)
        else
            `uvm_error("SEQ",
                $sformatf("Write/read-back MISMATCH addr=0x%08h wrote=0x%08h got=0x%08h",
                           addr, data, rdata))
    endtask

endclass : axi4_lite_wr_rd_seq


//==============================================================
// 5. Register Walk Sequence
//==============================================================
class axi4_lite_reg_walk_seq extends axi4_lite_base_seq;
    `uvm_object_utils(axi4_lite_reg_walk_seq)

    localparam int NUM_REGS = 16;

    function new(string name = "axi4_lite_reg_walk_seq");
        super.new(name);
    endfunction

    task body();
        bit [31:0] rdata;
        bit [1:0]  resp;
        int        pass_cnt = 0;
        int        fail_cnt = 0;

        `uvm_info("SEQ", "=== Register Walk Sequence START ===", UVM_LOW)

        `uvm_info("SEQ", "Writing all registers...", UVM_MEDIUM)
        for (int i = 0; i < NUM_REGS; i++) begin
            bit [1:0] wr_resp;
            do_write(i * 4, 32'hA000_0000 + i, 4'hF, 3'b000, wr_resp);
        end

        `uvm_info("SEQ", "Reading back all registers...", UVM_MEDIUM)
        for (int i = 0; i < NUM_REGS; i++) begin
            bit [31:0] expected = 32'hA000_0000 + i;
            do_read(i * 4, rdata, resp);
            if (rdata === expected) begin
                `uvm_info("SEQ",
                    $sformatf("reg[%0d] PASS expected=0x%08h got=0x%08h",
                               i, expected, rdata), UVM_HIGH)
                pass_cnt++;
            end else begin
                `uvm_error("SEQ",
                    $sformatf("reg[%0d] FAIL expected=0x%08h got=0x%08h",
                               i, expected, rdata))
                fail_cnt++;
            end
        end

        `uvm_info("SEQ",
            $sformatf("=== Register Walk DONE  PASS=%0d  FAIL=%0d ===",
                       pass_cnt, fail_cnt), UVM_LOW)
    endtask

endclass : axi4_lite_reg_walk_seq


//==============================================================
// 6. Constrained-Random Sequence
//    80% valid addresses, 20% out-of-range (DECERR)
//==============================================================
class axi4_lite_rand_seq extends axi4_lite_base_seq;
    `uvm_object_utils(axi4_lite_rand_seq)

    int unsigned num_transactions = 64;

    function new(string name = "axi4_lite_rand_seq");
        super.new(name);
    endfunction

    task body();
        axi4_lite_seq_item item;
        `uvm_info("SEQ",
            $sformatf("=== Random Sequence START  (%0d transactions) ===",
                       num_transactions), UVM_LOW)

        for (int i = 0; i < num_transactions; i++) begin
            item = axi4_lite_seq_item::type_id::create("rand_item");
            start_item(item);
            if (!item.randomize() with {
                    addr[1:0] == 2'b00;
                    addr dist {
                        [32'h00:32'h3C] :/ 80,
                        [32'h40:32'hFF] :/ 20
                    };
                    strb != 4'b0000; })
                `uvm_fatal("RAND_FAIL", "axi4_lite_rand_seq: randomization failed")
            finish_item(item);
        end

        `uvm_info("SEQ", "=== Random Sequence DONE ===", UVM_LOW)
    endtask

endclass : axi4_lite_rand_seq


//==============================================================
// 7. Error Injection Sequence
//    Uses do_write_raw / do_read_raw to bypass constraints
//==============================================================
class axi4_lite_error_seq extends axi4_lite_base_seq;
    `uvm_object_utils(axi4_lite_error_seq)

    function new(string name = "axi4_lite_error_seq");
        super.new(name);
    endfunction

    task body();
        bit [1:0]  resp;
        bit [31:0] rdata;

        `uvm_info("SEQ", "=== Error Injection Sequence START ===", UVM_LOW)

        // Out-of-range write — use RAW (bypasses c_addr_in_range)
        do_write_raw(32'hFFFF_0000, 32'hBAD_BABE, 4'hF, resp);
        if (resp == 2'b11)
            `uvm_info("SEQ", "OOB write DECERR: correct", UVM_MEDIUM)
        else
            `uvm_error("SEQ", "OOB write should have returned DECERR")

        // Out-of-range read — use RAW
        do_read_raw(32'hFFFF_0000, rdata, resp);
        if (resp == 2'b11)
            `uvm_info("SEQ", "OOB read DECERR: correct", UVM_MEDIUM)
        else
            `uvm_error("SEQ", "OOB read should have returned DECERR")

        // Unaligned write (byte 1) — use RAW
        do_write_raw(32'h0000_0001, 32'h1234_5678, 4'hF, resp);
        if (resp == 2'b11)
            `uvm_info("SEQ", "Unaligned write DECERR: correct", UVM_MEDIUM)
        else
            `uvm_error("SEQ", "Unaligned write should have returned DECERR")

        `uvm_info("SEQ", "=== Error Injection Sequence DONE ===", UVM_LOW)
    endtask

endclass : axi4_lite_error_seq


//==============================================================
// 8. Byte Strobe Coverage Sequence  (Phase 3 — coverage closure)
//
// Exercises all 7 strobe patterns to close the
// 14.3% gap in cp_strb:
//   4'b0001  byte 0 only
//   4'b0010  byte 1 only
//   4'b0100  byte 2 only
//   4'b1000  byte 3 only
//   4'b0011  lower half-word
//   4'b1100  upper half-word
//   4'b1111  full word 
//
// Method for each pattern:
//   1. Writes 0xFFFFFFFF to seed the register (all ones)
//   2. Writes 0x12345678 with the specific strobe
//   3. Calculate expected value by applying strobe in software
//   4. Read back and compare
//   Scoreboard verifies independently at the same time.
//==============================================================
class axi4_lite_strobe_seq extends axi4_lite_base_seq;
    `uvm_object_utils(axi4_lite_strobe_seq)

    function new(string name = "axi4_lite_strobe_seq");
        super.new(name);
    endfunction

    task body();
        bit [31:0] rdata;
        bit [1:0]  resp;
        int        pass_cnt = 0;
        int        fail_cnt = 0;

        `uvm_info("SEQ", "=== Byte Strobe Coverage Sequence START ===", UVM_LOW)

        // Run each strobe pattern on a dedicated register
        // reg[0] addr=0x00 — strobe 4'b0001 (byte 0)
        run_strobe_test(32'h00, 4'b0001, pass_cnt, fail_cnt);

        // reg[1] addr=0x04 — strobe 4'b0010 (byte 1)
        run_strobe_test(32'h04, 4'b0010, pass_cnt, fail_cnt);

        // reg[2] addr=0x08 — strobe 4'b0100 (byte 2)
        run_strobe_test(32'h08, 4'b0100, pass_cnt, fail_cnt);

        // reg[3] addr=0x0C — strobe 4'b1000 (byte 3)
        run_strobe_test(32'h0C, 4'b1000, pass_cnt, fail_cnt);

        // reg[4] addr=0x10 — strobe 4'b0011 (lower half-word)
        run_strobe_test(32'h10, 4'b0011, pass_cnt, fail_cnt);

        // reg[5] addr=0x14 — strobe 4'b1100 (upper half-word)
        run_strobe_test(32'h14, 4'b1100, pass_cnt, fail_cnt);

        // reg[6] addr=0x18 — strobe 4'b1111 (full word — confirm still works)
        run_strobe_test(32'h18, 4'b1111, pass_cnt, fail_cnt);

        `uvm_info("SEQ",
            $sformatf("=== Byte Strobe Sequence DONE  PASS=%0d  FAIL=%0d ===",
                       pass_cnt, fail_cnt), UVM_LOW)
    endtask

    //----------------------------------------------------------
    // run_strobe_test
    // Seeds a register with 0xFFFFFFFF, writes 0x12345678 with
    // the given strobe, reads back and checks expected value.
    //----------------------------------------------------------
    task run_strobe_test(
        input  bit [31:0] addr,
        input  bit [3:0]  strb,
        inout  int        pass_cnt,
        inout  int        fail_cnt
    );
        bit [31:0] seed_data  = 32'hFFFF_FFFF;
        bit [31:0] write_data = 32'h1234_5678;
        bit [31:0] expected;
        bit [31:0] rdata;
        bit [1:0]  resp;

        // Step 1: Seed register with all 1s (full strobe — compatible with c_strb_full)
        do_write(addr, seed_data, 4'hF, 3'b000, resp);

        // Step 2: Write with specific strobe — use RAW to bypass c_strb_full constraint
        // c_strb_full forces strb==4'hF, which conflicts with partial strobes
        do_write_raw(addr, write_data, strb, resp);

        // Step 3: Calculate expected value in software
        // Same logic as the RTL — apply strobe byte by byte
        expected = seed_data;
        if (strb[0]) expected[ 7: 0] = write_data[ 7: 0];
        if (strb[1]) expected[15: 8] = write_data[15: 8];
        if (strb[2]) expected[23:16] = write_data[23:16];
        if (strb[3]) expected[31:24] = write_data[31:24];

        // Step 4: Read back
        do_read(addr, rdata, resp);

        // Step 5: Check (scoreboard also checks independently)
        if (rdata === expected) begin
            `uvm_info("SEQ",
                $sformatf("Strobe 0b%04b PASS  addr=0x%02h  got=0x%08h  exp=0x%08h",
                           strb, addr, rdata, expected), UVM_MEDIUM)
            pass_cnt++;
        end else begin
            `uvm_error("SEQ",
                $sformatf("Strobe 0b%04b FAIL  addr=0x%02h  got=0x%08h  exp=0x%08h",
                           strb, addr, rdata, expected))
            fail_cnt++;
        end
    endtask

endclass : axi4_lite_strobe_seq