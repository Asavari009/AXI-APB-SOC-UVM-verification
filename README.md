# AXI-APB SoC UVM Verification

A complete AMBA bus subsystem designed and formally verified from scratch in SystemVerilog and UVM — spanning an AXI4-Lite Master, AXI-to-APB Protocol Bridge, and APB peripheral, verified with a dual-agent UVM environment and 15 formally proven SVA properties.

---

## Project Overview

```
cmd_if → AXI4-Lite Master → AXI4-Lite Bus → AXI-to-APB Bridge → APB Bus → APB Slave
```

| Layer | What Was Built |
|-------|---------------|
| RTL | AXI4-Lite Slave, Master, AXI-to-APB Bridge, APB Slave |
| Directed TB | 3 testbenches — 89 tests total |
| UVM | Dual-agent environment, scoreboard, coverage |
| Formal | 15 SVA properties proven using Questa Formal |

---

## Results at a Glance

| Phase | Description | Result |
|-------|-------------|--------|
| 1 | AXI4-Lite Slave directed TB |  10/10 PASS |
| 2+3 | AXI4-Lite UVM |  100% coverage, 0 errors |
| 4 | Master+Slave directed TB |  46/46 PASS |
| 5 | Full system directed TB |  33/33 PASS |
| 6 | Full system UVM |  237 checks, 0 failures, 100% coverage |
| 7 | Questa Formal |  15 properties PROVEN, 0 counterexamples |

---

## Repository Structure

```
├── rtl/
│   ├── axi4_lite_slave.sv        # AXI4-Lite slave register file
│   ├── axi4_lite_master.sv       # AXI4-Lite master FSM
│   ├── axi4_lite_top.sv          # Master + Slave integration
│   ├── axi4_lite_to_apb.sv       # AXI-to-APB bridge
│   ├── apb_slave.sv              # APB peripheral
│   └── system_top.sv             # Full system integration
│
├── tb/
│   ├── axi4_lite_if.sv           # AXI4-Lite interface + SVA
│   ├── apb_if.sv                 # APB interface + SVA
│   ├── axi4_lite_cmd_if.sv       # Command interface
│   ├── tb_top.sv                 # Phase 1 directed TB
│   ├── tb_top_master.sv          # Phase 4 directed TB
│   ├── tb_top_system.sv          # Phase 5 directed TB
│   ├── tb_top_uvm.sv             # Phase 2+3 UVM TB top
│   ├── tb_top_system_uvm.sv      # Phase 6 UVM TB top
│   └── formal/
│       ├── bridge_props.sv       # 15 SVA properties
│       ├── bridge_formal_tb.sv   # Formal testbench top
│       └── flist.f               # Formal file list
│
├── uvm/
│   ├── axi4_lite_pkg.sv          # Phase 2+3 UVM package
│   ├── axi4_lite_seq_item.sv
│   ├── axi4_lite_driver.sv
│   ├── axi4_lite_monitor.sv
│   ├── axi4_lite_agent.sv
│   ├── axi4_lite_sequences.sv
│   ├── axi4_lite_scoreboard.sv
│   ├── axi4_lite_coverage.sv
│   ├── axi4_lite_env.sv
│   ├── axi4_lite_base_test.sv
│   ├── axi4_lite_rand_test.sv
│   ├── axi4_lite_full_test.sv
│   ├── system_pkg.sv             # Phase 6 UVM package
│   ├── cmd_seq_item.sv
│   ├── cmd_driver.sv
│   ├── cmd_monitor.sv
│   ├── cmd_agent.sv
│   ├── apb_seq_item.sv
│   ├── apb_monitor.sv
│   ├── apb_agent.sv
│   ├── e2e_scoreboard.sv
│   ├── system_coverage.sv
│   ├── system_env.sv
│   ├── system_sequences.sv
│   └── system_tests.sv
│
└── sim/
    ├── compile_slave_directed.do  # Phase 1
    ├── compile.do                 # Phase 2+3
    ├── compile_master.do          # Phase 4
    ├── compile_system.do          # Phase 5
    ├── compile_system_uvm.do      # Phase 6
    ├── compile_formal.do          # Phase 7
    └── formal_init.tcl            # Formal setup
```

---

## Requirements

- **Simulator:** Questa Sim 2021.1 or later
- **UVM:** 1.1d (built into Questa)
- **Formal:** Questa Formal (Phase 7 only)
- **Language:** SystemVerilog IEEE 1800-2012

---

## Setup — Run Once

```bash
git clone https://github.com/yourusername/axi-apb-soc-uvm-verification.git
cd axi-apb-soc-uvm-verification/sim

# Set local ini (avoids shared server permission errors)
export MODELSIM=$(pwd)/questa.ini
# OR for newer Questa:
export QSIM_INI=$(pwd)/questa.ini

# Launch Questa
vsim &
```

---

## Running Each Phase

All commands are typed in the **Questa transcript window**.
The `transcript` command saves results to a log file.

---

### Phase 1 — AXI4-Lite Slave Directed Testbench

Tests the slave RTL in isolation. Covers handshake, byte strobes,
DECERR, back-pressure, AW/W ordering, and reset.

```tcl
transcript to ../results/phase1_slave_directed.log
do compile_slave_directed.do
transcript to {}
```

**Expected output:**
```
[PASS] T1: reg[0] read-back
...
RESULTS: 10 PASSED | 0 FAILED
*** ALL TESTS PASSED ***
```

---

### Phase 2+3 — AXI4-Lite UVM (Register Walk)

Full UVM environment on the AXI4-Lite slave.
Scoreboard, coverage model, constrained-random sequences.

**Run base test (register walk):**
```tcl
transcript to ../results/phase2_axi_uvm_base.log
do compile.do
transcript to {}
```

**Run full test (100% coverage closure):**

Edit `compile.do` — change `UVM_TESTNAME`:
```
+UVM_TESTNAME=axi4_lite_full_test \
```
```tcl
transcript to ../results/phase3_axi_uvm_full.log
do compile.do
transcript to {}
```

**Expected output:**
```
=== Register Walk DONE  PASS=16  FAIL=0 ===
Total Coverage : 100.0%
SCOREBOARD: ALL CHECKS PASSED
*** TEST PASSED ***
UVM_ERROR : 0  UVM_FATAL : 0
```

---

### Phase 4 — AXI4-Lite Master + Slave Directed Testbench

Tests the Master RTL connected to the Slave.
Covers write/read, back-to-back, byte strobes,
out-of-range, mixed patterns, and reset.

```tcl
transcript to ../results/phase4_master_directed.log
do compile_master.do
transcript to {}
```

**Expected output:**
```
RESULTS: 46 PASSED | 0 FAILED
*** ALL TESTS PASSED — Master RTL is clean! ***
```

---

### Phase 5 — Full System Directed Testbench

Tests the complete Master → AXI-to-APB Bridge → APB Slave path.
Verifies error propagation (PSLVERR→SLVERR) and wait states.

```tcl
transcript to ../results/phase5_system_directed.log
do compile_system.do
transcript to {}
```

**Expected output:**
```
Wait States = 2
RESULTS: 33 PASSED | 0 FAILED
*** ALL TESTS PASSED — Bridge is clean! ***
```

---

### Phase 6 — Full System UVM

Dual-agent UVM environment. CMD agent drives the Master command
interface. APB agent passively observes the APB bus.
Cross-protocol scoreboard checks 237 transactions.

**Run base test:**
```tcl
transcript to ../results/phase6_system_uvm_base.log
do compile_system_uvm.do
transcript to {}
```

**Run full test (100% coverage):**

Edit `compile_system_uvm.do` — change `UVM_TESTNAME`:
```
+UVM_TESTNAME=system_full_test \
```
```tcl
transcript to ../results/phase6_system_uvm_full.log
do compile_system_uvm.do
transcript to {}
```

**Expected output:**
```
Total Coverage   : 100.0%
Write checks PASS :  62    Write checks FAIL :   0
Read  checks PASS :  55    Read  checks FAIL :   0
Error prop  PASS  : 120    Error prop  FAIL  :   0
E2E SCOREBOARD: ALL CHECKS PASSED
*** TEST PASSED ***
UVM_ERROR : 0  UVM_FATAL : 0
```

---

### Phase 7 — Formal Verification (Questa Formal)

Mathematically proves 15 SVA properties on the AXI-to-APB bridge.
Covers data integrity, deadlock freedom, protocol compliance,
and error propagation.

```bash
# Launch Questa Formal (separate tool — not regular vsim)
cd sim
qformal &
```

```tcl
# In Questa Formal transcript:
transcript to ../results/phase7_formal.log
do compile_formal.do
transcript to {}
```

**Expected output:**
```
p_penable_requires_psel      PROVEN
p_setup_one_cycle            PROVEN
p_paddr_stable_in_access     PROVEN
p_pwrite_stable_in_access    PROVEN
p_pwdata_stable_in_access    PROVEN
p_penable_deasserts          PROVEN
p_write_data_integrity       PROVEN
p_address_integrity          PROVEN
p_pslverr_to_bresp           PROVEN
p_pslverr_to_rresp           PROVEN
p_no_deadlock                PROVEN
p_bvalid_in_wr_resp_only     PROVEN
p_rvalid_in_rd_resp_only     PROVEN
p_idle_when_both_ready       PROVEN
p_psel_deasserts             PROVEN

15/15 PROVEN — 0 counterexamples
```

---

## Run All Phases (Quick Reference)

```tcl
# Phase 1 — Slave directed
transcript to ../results/phase1_slave_directed.log
do compile_slave_directed.do
transcript to {}

# Phase 2+3 — AXI UVM (change UVM_TESTNAME for each)
transcript to ../results/phase2_axi_uvm_base.log
do compile.do
transcript to {}

# Phase 4 — Master directed
transcript to ../results/phase4_master_directed.log
do compile_master.do
transcript to {}

# Phase 5 — System directed
transcript to ../results/phase5_system_directed.log
do compile_system.do
transcript to {}

# Phase 6 — System UVM (change UVM_TESTNAME for each)
transcript to ../results/phase6_system_uvm_full.log
do compile_system_uvm.do
transcript to {}
```

---

## Key Design Details

### AXI4-Lite Slave
- 4-state write FSM: IDLE → WAIT_W / WAIT_AW → RESP
- 2-state read FSM: IDLE → DATA
- Byte-lane strobes applied per-bit
- DECERR on unaligned and out-of-range addresses

### AXI4-Lite Master
- 7-state FSM with independent AW/W channel tracking
- Configurable timeout watchdog (TIMEOUT_CYCLES parameter)
- Clean command interface decoupling AXI from user logic

### AXI-to-APB Bridge
- 7-state FSM: IDLE → WAIT_W/WAIT_AW → SETUP → ACCESS → WR_RESP/RD_RESP
- APB SETUP phase exactly 1 clock cycle (APB protocol requirement)
- Variable wait state support via PREADY
- PSLVERR → SLVERR/RRESP error mapping

### UVM Architecture
```
system_full_test
└── system_env
    ├── cmd_agent (ACTIVE)
    │   ├── cmd_driver    → drives Master command interface
    │   └── cmd_monitor   → observes commands + responses
    ├── apb_agent (PASSIVE)
    │   └── apb_monitor   → observes APB bus
    ├── e2e_scoreboard    ← cmd_monitor + apb_monitor
    └── system_coverage   ← apb_monitor
```

### Formal Properties (15 proven)
| Property | Claim |
|----------|-------|
| P1 | PENABLE only when PSEL |
| P2 | SETUP phase exactly 1 cycle |
| P3-P5 | Signals stable during ACCESS |
| P6 | PENABLE deasserts after PREADY |
| P7 | Data integrity: PWDATA == WDATA |
| P8 | Address integrity: PADDR == AWADDR |
| P9 | Write error propagation: PSLVERR → BRESP=SLVERR |
| P10 | Read error propagation: PSLVERR → RRESP=SLVERR |
| P11 | No deadlock: bridge always returns to IDLE |
| P12-P15 | Protocol safety properties |

---

## Tools and Protocols

**Tools:**
- Questa Sim 2026.1
- UVM 1.1d (built-in)
- Questa Formal 2026.1
- SystemVerilog IEEE 1800-2012

**Protocols:**
- AMBA AXI4-Lite (ARM IHI0022)
- AMBA APB (ARM IHI0024)

---

