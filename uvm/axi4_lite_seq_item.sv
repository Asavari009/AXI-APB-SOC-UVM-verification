//============================================================
// File    : axi4_lite_seq_item.sv
// Project : AXI4-Lite UVM Testbench
// Purpose : UVM Sequence Item — represents one AXI4-Lite
//           transaction (read or write).
//============================================================

class axi4_lite_seq_item extends uvm_sequence_item;
    `uvm_object_utils(axi4_lite_seq_item)

    //----------------------------------------------------------
    // Transaction Direction
    //----------------------------------------------------------
    typedef enum bit { READ = 1'b0, WRITE = 1'b1 } rw_e;

    //----------------------------------------------------------
    // Randomizable Fields  (driven by sequences -> driver)
    //----------------------------------------------------------
    rand rw_e       rw;      // Transaction direction
    rand bit [31:0] addr;    // Byte address
    rand bit [31:0] data;    // Write data (ignored for reads)
    rand bit [3:0]  strb;    // Write byte-lane enables
    rand bit [2:0]  prot;    // AXI protection attributes

    //----------------------------------------------------------
    // Response Fields  (filled in by driver after transaction)
    //----------------------------------------------------------
    bit [31:0] rdata;   // Data returned on read
    bit [1:0]  resp;    // BRESP or RRESP

    //----------------------------------------------------------
    // Constraints
    //----------------------------------------------------------

    // AXI4-Lite requires word-aligned addresses
    constraint c_word_aligned {
        addr[1:0] == 2'b00;
    }

    // Stay within the 16-register slave address space (0x00–0x3C)
    constraint c_addr_in_range {
        addr inside {[32'h00 : 32'h3C]};
    }

    // Write must have at least one active byte strobe
    constraint c_strb_nonzero {
        (rw == WRITE) -> (strb != 4'b0000);
    }

    // Default: full-word strobe (override per-test when needed)
    constraint c_strb_full {
        strb == 4'b1111;
    }

    // Default: normal non-secure data access
    constraint c_prot_default {
        prot == 3'b000;
    }

    //----------------------------------------------------------
    // Constructor
    //----------------------------------------------------------
    function new(string name = "axi4_lite_seq_item");
        super.new(name);
    endfunction

    //----------------------------------------------------------
    // UVM Field Utilities
    //----------------------------------------------------------

    // Human-readable string for logging
    function string convert2string();
        if (rw == WRITE)
            return $sformatf(
                "[WRITE] addr=0x%08h  data=0x%08h  strb=0b%04b  prot=0b%03b | BRESP=0b%02b",
                addr, data, strb, prot, resp);
        else
            return $sformatf(
                "[READ ] addr=0x%08h  rdata=0x%08h prot=0b%03b           | RRESP=0b%02b",
                addr, rdata, prot, resp);
    endfunction

    // Deep copy
    function void do_copy(uvm_object rhs);
        axi4_lite_seq_item item;
        super.do_copy(rhs);
        if (!$cast(item, rhs))
            `uvm_fatal("CAST_ERR", "do_copy: cast to axi4_lite_seq_item failed")
        rw    = item.rw;
        addr  = item.addr;
        data  = item.data;
        strb  = item.strb;
        prot  = item.prot;
        rdata = item.rdata;
        resp  = item.resp;
    endfunction

    // Comparison (stimulus fields only — not response)
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        axi4_lite_seq_item item;
        if (!$cast(item, rhs)) return 0;
        return (rw   == item.rw   &&
                addr == item.addr &&
                data == item.data &&
                strb == item.strb &&
                prot == item.prot);
    endfunction

    // Pretty-print via uvm_printer
    function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_string("rw",    rw.name());
        printer.print_field ("addr",  addr,  32, UVM_HEX);
        printer.print_field ("data",  data,  32, UVM_HEX);
        printer.print_field ("strb",  strb,  4,  UVM_BIN);
        printer.print_field ("prot",  prot,  3,  UVM_BIN);
        printer.print_field ("rdata", rdata, 32, UVM_HEX);
        printer.print_field ("resp",  resp,  2,  UVM_BIN);
    endfunction

endclass : axi4_lite_seq_item