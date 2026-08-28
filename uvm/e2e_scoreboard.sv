//============================================================
// File    : e2e_scoreboard.sv
// Project : System UVM Testbench — Phase 6
// Purpose : End-to-end cross-protocol scoreboard.
//
// Receives from TWO analysis ports:
//   cmd_export  <- cmd_monitor  (what the user requested)
//   apb_export  <- apb_monitor  (what appeared on APB bus)
//
// Checks:
//   1. Every CMD write  -> exactly one APB write, data matches
//   2. Every CMD read   -> exactly one APB read,  data matches
//   3. APB PSLVERR=1    -> CMD error=1 (error propagated)
//   4. APB PSLVERR=0    -> CMD error=0 (no false errors)
//   5. CMD read rdata   == shadow register value
//============================================================

class e2e_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(e2e_scoreboard)

    //----------------------------------------------------------
    // Analysis imports — one per protocol
    // uvm_analysis_imp_decl macros declared in system_pkg.sv
    //----------------------------------------------------------
    uvm_analysis_imp_cmd #(cmd_seq_item, e2e_scoreboard) cmd_export;
    uvm_analysis_imp_apb #(apb_seq_item, e2e_scoreboard) apb_export;

    //----------------------------------------------------------
    // APB transaction queues (populated before cmd arrives)
    //----------------------------------------------------------
    apb_seq_item apb_write_q[$];
    apb_seq_item apb_read_q[$];

    //----------------------------------------------------------
    // Shadow register file
    //----------------------------------------------------------
    localparam int NUM_REGS = 16;
    bit [31:0] shadow [0:NUM_REGS-1];

    //----------------------------------------------------------
    // Statistics
    //----------------------------------------------------------
    int write_pass = 0;
    int write_fail = 0;
    int read_pass  = 0;
    int read_fail  = 0;
    int err_pass   = 0;
    int err_fail   = 0;

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
        cmd_export = new("cmd_export", this);
        apb_export = new("apb_export", this);
        foreach (shadow[i]) shadow[i] = '0;
        `uvm_info("E2E_SB", "Scoreboard initialised", UVM_MEDIUM)
    endfunction

    //----------------------------------------------------------
    // write_apb — called when APB monitor captures a transaction
    // Store in queue for matching when CMD response arrives
    //----------------------------------------------------------
    function void write_apb(apb_seq_item trans);
        `uvm_info("E2E_SB",
            $sformatf("APB captured: %s", trans.convert2string()), UVM_HIGH)

        if (trans.pwrite) begin
            // Update shadow on write (with byte strobes)
            if (!trans.pslverr) begin
                int idx = trans.paddr >> 2;
                if (idx < NUM_REGS) begin
                    for (int b = 0; b < 4; b++) begin
                        if (trans.pstrb[b])
                            shadow[idx][b*8 +: 8] = trans.pwdata[b*8 +: 8];
                    end
                end
            end
            apb_write_q.push_back(trans);
        end else begin
            apb_read_q.push_back(trans);
        end
    endfunction

    //----------------------------------------------------------
    // write_cmd — called when CMD monitor captures a transaction
    // Match with queued APB transaction and verify
    //----------------------------------------------------------
    function void write_cmd(cmd_seq_item trans);
        `uvm_info("E2E_SB",
            $sformatf("CMD captured: %s", trans.convert2string()), UVM_HIGH)

        if (trans.rw == cmd_seq_item::WRITE)
            check_write(trans);
        else
            check_read(trans);
    endfunction

    //----------------------------------------------------------
    // Check write transaction
    //----------------------------------------------------------
    function void check_write(cmd_seq_item cmd);
        apb_seq_item apb;

        if (apb_write_q.size() == 0) begin
            `uvm_error("E2E_SB",
                "CMD write arrived but APB write queue is empty")
            write_fail++;
            return;
        end

        apb = apb_write_q.pop_front();

        // Check: address matches
        if (cmd.addr !== apb.paddr) begin
            `uvm_error("E2E_SB",
                $sformatf("WRITE addr mismatch: CMD=0x%08h APB=0x%08h",
                           cmd.addr, apb.paddr))
            write_fail++;
        end

        // Check: data matches
        if (!apb.pslverr && cmd.addr == apb.paddr) begin
            if (cmd.data !== apb.pwdata) begin
                `uvm_error("E2E_SB",
                    $sformatf("WRITE data mismatch: CMD=0x%08h APB=0x%08h",
                               cmd.data, apb.pwdata))
                write_fail++;
            end else begin
                write_pass++;
                `uvm_info("E2E_SB",
                    $sformatf("WRITE PASS addr=0x%08h data=0x%08h",
                               cmd.addr, cmd.data), UVM_HIGH)
            end
        end

        // Check: error propagation
        if (apb.pslverr !== cmd.error) begin
            `uvm_error("E2E_SB",
                $sformatf("WRITE error prop FAIL: PSLVERR=%0b cmd.error=%0b",
                           apb.pslverr, cmd.error))
            err_fail++;
        end else begin
            err_pass++;
        end
    endfunction

    //----------------------------------------------------------
    // Check read transaction
    //----------------------------------------------------------
    function void check_read(cmd_seq_item cmd);
        apb_seq_item apb;
        int idx;
        bit [31:0] expected;

        if (apb_read_q.size() == 0) begin
            `uvm_error("E2E_SB",
                "CMD read arrived but APB read queue is empty")
            read_fail++;
            return;
        end

        apb = apb_read_q.pop_front();

        // Check: address matches
        if (cmd.addr !== apb.paddr) begin
            `uvm_error("E2E_SB",
                $sformatf("READ addr mismatch: CMD=0x%08h APB=0x%08h",
                           cmd.addr, apb.paddr))
            read_fail++;
            return;
        end

        if (!apb.pslverr) begin
            // Check: cmd rdata matches APB prdata
            if (cmd.rdata !== apb.prdata) begin
                `uvm_error("E2E_SB",
                    $sformatf("READ data mismatch: CMD.rdata=0x%08h APB.prdata=0x%08h",
                               cmd.rdata, apb.prdata))
                read_fail++;
            end

            // Check: cmd rdata matches shadow model
            idx      = cmd.addr >> 2;
            expected = shadow[idx];
            if (cmd.rdata !== expected) begin
                `uvm_error("E2E_SB",
                    $sformatf("READ shadow mismatch: got=0x%08h expected=0x%08h",
                               cmd.rdata, expected))
                read_fail++;
            end else begin
                read_pass++;
                `uvm_info("E2E_SB",
                    $sformatf("READ PASS addr=0x%08h rdata=0x%08h",
                               cmd.addr, cmd.rdata), UVM_HIGH)
            end
        end

        // Check error propagation
        if (apb.pslverr !== cmd.error) begin
            `uvm_error("E2E_SB",
                $sformatf("READ error prop FAIL: PSLVERR=%0b cmd.error=%0b",
                           apb.pslverr, cmd.error))
            err_fail++;
        end else begin
            err_pass++;
        end
    endfunction

    //----------------------------------------------------------
    // Report Phase
    //----------------------------------------------------------
    function void report_phase(uvm_phase phase);
        $display("");
        $display("╔══════════════════════════════════════════╗");
        $display("║     END-TO-END SCOREBOARD SUMMARY        ║");
        $display("╠══════════════════════════════════════════╣");
        $display("║  Write checks PASS  : %4d               ║", write_pass);
        $display("║  Write checks FAIL  : %4d               ║", write_fail);
        $display("║  Read  checks PASS  : %4d               ║", read_pass);
        $display("║  Read  checks FAIL  : %4d               ║", read_fail);
        $display("║  Error prop  PASS   : %4d               ║", err_pass);
        $display("║  Error prop  FAIL   : %4d               ║", err_fail);
        $display("╚══════════════════════════════════════════╝");

        if (write_fail + read_fail + err_fail == 0)
            `uvm_info("E2E_SB", "E2E SCOREBOARD: ALL CHECKS PASSED", UVM_NONE)
        else
            `uvm_error("E2E_SB", "E2E SCOREBOARD: FAILURES DETECTED")
    endfunction

endclass : e2e_scoreboard
