//============================================================
// File    : apb_seq_item.sv
// Project : System UVM Testbench — Phase 6
// Purpose : APB transaction object.
//           Captured by the APB monitor from the bus.
//           Used by scoreboard to verify bridge correctness.
//============================================================

class apb_seq_item extends uvm_sequence_item;
    `uvm_object_utils(apb_seq_item)

    //----------------------------------------------------------
    // Fields captured from APB SETUP phase
    //----------------------------------------------------------
    bit [31:0] paddr;    // byte address
    bit        pwrite;   // 1=write 0=read
    bit [31:0] pwdata;   // write data
    bit [3:0]  pstrb;    // byte strobes
    bit [2:0]  pprot;    // protection

    //----------------------------------------------------------
    // Fields captured from APB ACCESS phase (PREADY=1)
    //----------------------------------------------------------
    bit [31:0] prdata;   // read data from slave
    bit        pslverr;  // slave error flag

    //----------------------------------------------------------
    // Constructor
    //----------------------------------------------------------
    function new(string name = "apb_seq_item");
        super.new(name);
    endfunction

    //----------------------------------------------------------
    // Utilities
    //----------------------------------------------------------
    function string convert2string();
        if (pwrite)
            return $sformatf(
                "[APB WR] addr=0x%08h data=0x%08h strb=0b%04b | pslverr=%0b",
                paddr, pwdata, pstrb, pslverr);
        else
            return $sformatf(
                "[APB RD] addr=0x%08h rdata=0x%08h | pslverr=%0b",
                paddr, prdata, pslverr);
    endfunction

    function void do_copy(uvm_object rhs);
        apb_seq_item item;
        super.do_copy(rhs);
        if (!$cast(item, rhs))
            `uvm_fatal("CAST", "apb_seq_item do_copy cast failed")
        paddr   = item.paddr;
        pwrite  = item.pwrite;
        pwdata  = item.pwdata;
        pstrb   = item.pstrb;
        pprot   = item.pprot;
        prdata  = item.prdata;
        pslverr = item.pslverr;
    endfunction

endclass : apb_seq_item
