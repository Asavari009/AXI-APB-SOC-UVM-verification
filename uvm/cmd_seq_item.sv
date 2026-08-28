//============================================================
// File    : cmd_seq_item.sv
// Project : System UVM Testbench — Phase 6
// Purpose : Command-level transaction object.
//           The driver translates this into cmd_if signals
//           which flow: Master -> AXI -> Bridge -> APB -> Slave.
//============================================================

class cmd_seq_item extends uvm_sequence_item;
    `uvm_object_utils(cmd_seq_item)

    typedef enum bit { READ = 1'b0, WRITE = 1'b1 } rw_e;

    //----------------------------------------------------------
    // Randomizable stimulus fields
    //----------------------------------------------------------
    rand rw_e       rw;
    rand bit [31:0] addr;
    rand bit [31:0] data;
    rand bit [3:0]  strb;
    rand bit [2:0]  prot;

    //----------------------------------------------------------
    // Response fields (filled by driver after transaction)
    //----------------------------------------------------------
    bit [31:0] rdata;
    bit [1:0]  resp;
    bit        error;
    bit        timeout_f;

    //----------------------------------------------------------
    // Constraints
    //----------------------------------------------------------
    constraint c_word_aligned  { addr[1:0] == 2'b00; }
    constraint c_addr_in_range { addr inside {[32'h00 : 32'h3C]}; }
    constraint c_strb_nonzero  { (rw == WRITE) -> (strb != 4'b0000); }
    constraint c_strb_full     { strb == 4'b1111; }
    constraint c_prot_default  { prot == 3'b000; }

    //----------------------------------------------------------
    // Constructor
    //----------------------------------------------------------
    function new(string name = "cmd_seq_item");
        super.new(name);
    endfunction

    //----------------------------------------------------------
    // Utilities
    //----------------------------------------------------------
    function string convert2string();
        if (rw == WRITE)
            return $sformatf(
                "[CMD WR] addr=0x%08h data=0x%08h strb=0b%04b | err=%0b",
                addr, data, strb, error);
        else
            return $sformatf(
                "[CMD RD] addr=0x%08h rdata=0x%08h | err=%0b",
                addr, rdata, error);
    endfunction

    function void do_copy(uvm_object rhs);
        cmd_seq_item item;
        super.do_copy(rhs);
        if (!$cast(item, rhs))
            `uvm_fatal("CAST", "cmd_seq_item do_copy cast failed")
        rw        = item.rw;
        addr      = item.addr;
        data      = item.data;
        strb      = item.strb;
        prot      = item.prot;
        rdata     = item.rdata;
        resp      = item.resp;
        error     = item.error;
        timeout_f = item.timeout_f;
    endfunction

    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        cmd_seq_item item;
        if (!$cast(item, rhs)) return 0;
        return (rw == item.rw && addr == item.addr &&
                data == item.data && strb == item.strb);
    endfunction

endclass : cmd_seq_item
