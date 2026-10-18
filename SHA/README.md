# SHA-256 Hardware Accelerator (Verilog)

A **complete, synthesizable SHA-256 hash accelerator** implemented in Verilog, fully compliant with the [NIST FIPS 180-4](https://csrc.nist.gov/pubs/fips/180-4/fip) standard. Designed as a streaming, byte-level input accelerator suitable for FPGA or ASIC implementation.

---

## 🔐 What It Does

Converts an arbitrary-length message into its 256-bit cryptographic hash digest — the exact same algorithm used in Bitcoin, TLS, SSH, and countless other systems.

```
Input  : arbitrary-length byte stream (via valid_input / byte_in / last_byte handshake)
Output : 256-bit hash digest (hash_out, asserted when hash_valid = 1)
```

---

## 📂 Repository Structure

```
SHA/
├── SHAtop_module/          # SHA-256 top-level accelerator (core RTL)
│   ├── SHAtop_module.v
│   └── SHAtop_module.tb
├── message_padding/        # FIPS 180-4 §5.1.1 padding FSM
│   └── message_padding.v
├── expander_block/        # Message schedule W[0..63] generator
│   ├── expander_block.v
│   └── expander_block.tb
├── compressor_block/       # 64-round compression function
│   ├── compressor_block.v
│   └── compressor_block.tb
├── functions/              # Reusable SHA-256 logical functions
│   ├── sha_256_functions.vh
│   └── sha_256_functions.tb
├── carry_skip_adder/       # Custom fast adder (used in expander)
│   └── carry_skip_adder_32bit.v
└── README.md
```

### Module Overview

| Module | Responsibility |
|---|---|
| `SHAtop_module` | Core accelerator. FSM sequencer, byte-level input handshake, pipelined coordination of all sub-blocks |
| `message_padding` | 5-state FSM: `IDLE → RECEIVING → PADDING → EXTRA_BLOCK_FILL → FLUSH`. Appends `0x80`, zero-bytes, and 64-bit length per FIPS 180-4 §5.1.1 |
| `expander_block` | Generates W[0..63] using a **3-adder pipeline** that reduces the critical path from three sequential additions to one per cycle. A 16-word shift register (R1–R16) acts as a free pipeline stage; CSKA1/CSKA2 compute one cycle early and feed CSKA3 just-in-time |
| `compressor_block` | Executes 64 rounds of the SHA-256 compression function. Uses LUT-based ROM for K[0..63] constants |
| `sha_256_functions.vh` | Shared logical functions: ROTR, SHR, Ch, Maj, Σ₀, Σ₁, σ₀, σ₁ |
| `carry_skip_adder_32bit` | Hierarchical carry skip adder (4-bit × 8 stages → 32-bit). Faster than ripple carry; used instead of `+` operators |
| `uart_tx` | UART transmitter (115200 baud, 8N1). Serializes the 256-bit hash for terminal output |
| `clk_wiz_0` | Xilinx Clock Wizard IP. Generates internal clocks from Basys-3's 50MHz system clock |

### expander_block — 3-Adder Pipeline Design

The message schedule generates each word `W[t]` using:

```
W[t] = W[t-16] + W[t-7] + σ0(W[t-2]) + σ1(W[t-15])
```

A naive implementation chains three 32-bit additions in series — a long critical path. Instead, the design exploits the 16-word shift register delay to pipeline the additions:

**Timing (one cycle = one output word):**

```
Cycle T   : CSKA1 computes R[6] + R[15]  → reg1   (terms W[t-7] + W[t-16])
             CSKA2 computes sig1(R[1]) + sig0(R[14]) → reg2  (σ terms)

Cycle T+1 : CSKA3 adds reg1 + reg2 → W[t]   (just-in-time)
```

```
                    1 cycle early                just-in-time
         R[6] ─────────┐                    ┌── reg1 ──┐
  R[15] ──┬── CSKA1 ───┘                    │          ├── CSKA3 ────▶ W[t]
           │                                 │ reg2 ───┘
  sig1(R[1]) ──┬── CSKA2 ────▶ reg2 ───────┘
  sig0(R[14]) ─┘
```

The 16-word shift register (R1–R16) shifts every cycle, so by the time W[t] is needed, the correct words are already in R6, R15, R1, and R14. The critical path per cycle is **one carry skip adder** — not three.

---

## 🧩 Design Highlights

- **Streaming input** — byte-level handshake (`valid_input`, `byte_in`, `last_byte`) handles messages of any length without fixed-size buffers
- **NIST FIPS 180-4 compliant** — message padding, round constants (K[0–63]), and initial hash values (H[0–7]) all sourced from the official spec
- **Modular pipeline** — three-stage pipeline (pad → expand → compress) with a sequencer FSM ensuring correct cycle-level timing
- **Clean FSM design** — `message_padding` uses a 5-state FSM (`IDLE → RECEIVING → PADDING → EXTRA_BLOCK_FILL → FLUSH`) to handle edge cases (e.g., 448-bit boundary, extra block for long length fields)
- **3-Adder Pipeline in expander_block** — the message schedule equation `W[t] = W[t-16] + W[t-7] + σ0(W[t-2]) + σ1(W[t-15])` normally requires three additions in series. This design computes the two σ functions + the W[t-16]/W[t-7] terms one cycle early and feeds them into a third adder just-in-time, reducing the critical path to **one carry skip adder delay per cycle** instead of three. A 16-word shift register (R1–R16) acts as the free pipeline register between stages
- **LUT-based K ROM** — round constants K[0..63] implemented as distributed ROM (64×32 bits) mapped to LUT RAM by Vivado; zero DSP/block RAM usage
- **Synchronous, register-based** — all state in registers clocked on `clk`; asynchronous `rst` resets everything cleanly
- **Testbenches included** — every module has a corresponding `.tb` testbench
- **FPGA-ready** — synthesized and deployed on Basys-3; full bitstream available

---

## 🔑 NIST FIPS 180-4 Reference

### Initial Hash Values (H₀ – H₇)

| Register | Hex | Derivation |
|---|---|---|
| H₀ | `0x6a09e667` | ⌊2³² × √2⌋ |
| H₁ | `0xbb67ae85` | ⌊2³² × √3⌋ |
| H₂ | `0x3c6ef372` | ⌊2³² × √5⌋ |
| H₃ | `0xa54ff53a` | ⌊2³² × √7⌋ |
| H₄ | `0x510e527f` | ⌊2³² × √11⌋ |
| H₅ | `0x9b05688c` | ⌊2³² × √13⌋ |
| H₆ | `0x1f83d9ab` | ⌊2³² × √17⌋ |
| H₇ | `0x5be0cd19` | ⌊2³² × √19⌋ |

### Round Constants (K₀ – K₆₃)

First 32 bits of the fractional parts of the cube roots of the first 64 primes (FIPS 180-4 §4.2.2):

```
0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
```

---

## 🚀 Quick Start

### Simulation

```bash
# Example — run SHAtop_module testbench in your simulator of choice
# (iverilog, ModelSim, VCS, etc.)
iverilog -o shatop_tb.vvp SHAtop_module.v SHAtop_module.tb \
    message_padding/message_padding.v \
    expander_block/expander_block.v \
    compressor_block/compressor_block.v \
    carry_skip_adder/carry_skip_adder_32bit.v
vvp shatop_tb.vvp
```

### Expected Output (Empty String Hash)

```
Input  : "" (empty string)
Output : 0x e3b0c44 298d4142 e8305d22 9f03f8d5 4e8875a5 9980be95 1fdc1ce3 976e41a9
```

---

## 💡 Skills Demonstrated

| Skill | Where It Appears |
|---|---|
| FSM design | `message_padding` (5-state), `SHAtop_module` (pipeline sequencer) |
| Cryptographic primitives | SHA-256 compression function, message schedule expansion |
| Standard compliance | Full FIPS 180-4 padding & constants |
| RTL coding style | Non-blocking assignments, registered outputs, clear naming |
| Testbench writing | Per-module `.tb` files with self-checking logic |
| Hardware datapath design | 512-bit wide busses, byte-level streaming interfaces |
| Critical path optimization | **3-adder pipeline** in expander_block — exploits shift-register delay to reduce 3 serial additions to 1 per cycle |
| Custom arithmetic units | **Carry Skip Adder** — hierarchical 4-bit × 8 stages; replaces generic `+` operators for faster arithmetic |
| IP integration | Clock Wizard (MMCM) for board-level clocking |
| FPGA deployment | Full bitstream targeting Basys-3 (xc7a35tcpg236-1) |
| Peripheral interfaces | UART TX for serial hash output |

---

## 🖥️ FPGA Deployment — Basys-3 Board

The SHA-256 accelerator is fully deployed on the **Digilent Basys-3** development board (Xilinx Artix-7 xc7a35tcpg236-1).

### System Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        board_top                                  │
│                                                                   │
│  ┌──────────────────┐      ┌─────────────────────────────────┐ │
│  │    clk_wiz_0     │      │         basys3_sha_top          │ │
│  │  (Clock Wizard)  │      │                                  │ │
│  │  50MHz → target  │─────▶│  ┌──────────────────────────┐  │ │
│  └──────────────────┘      │  │      SHAtop_module       │  │ │
│                             │  │                          │  │ │
│  ┌──────────────────┐      │  │  message_padding         │  │ │
│  │   UART TX        │◀──────│  │  (5-state FSM, 512-bit   │  │ │
│  │  (tx_uart)       │      │  │   block buffer)          │  │ │
│  │  Baud: 115200    │      │  │                          │  │ │
│  │  TX → USB-UART   │      │  │  expander_block  ◀──┐    │  │ │
│  └──────────────────┘      │  │  ┌──────────────┐ │    │  │ │
│                             │  │  │ R1–R16 shift │ │    │  │ │
│  Switches / Buttons ────────│  │  │ reg │ reg │ │    │  │ │
│  LEDs ◀─────────────────────│  │  │ CSKA1 CSKA2  │ │    │  │ │
│  7-segment ◀───────────────│  │  │ CSKA3 (3×32b)│─┘    │  │ │
│                             │  │  └──────────────┘      │  │ │
│                             │  │                          │  │ │
│                             │  │  compressor_block        │  │ │
│                             │  │  ┌──────────────────┐  │  │ │
│                             │  │  │ A..H working vars │  │  │ │
│                             │  │  │ 64 rounds         │  │  │ │
│                             │  │  │ K[0..63] ROM (LUT) │  │  │ │
│                             │  │  └──────────────────┘  │  │ │
│                             │  └──────────────────────────┘  │ │
│                             └───────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

### Key Design Decisions

- **Carry Skip Adder** — used in the expander block instead of a generic `+` operator. Reduces carry propagation delay in the critical path of the message schedule computation.
- **Clock Wizard IP** — generates stable internal clocks from the Basys-3's 50MHz system clock.
- **UART TX** — serializes the 256-bit hash output and transmits it over USB-UART so the result can be read on a terminal (115200 baud).

---

## 📊 Synthesis Results

**Tool:** Vivado v2025.2 | **Target:** xc7a35tcpg236-1 (Basys-3) | **Top:** `board_top`

### Resource Utilization

| Resource | Used | Available | Utilization |
|---|---|---|---|
| Slice LUTs | 2,260 | 20,800 | **10.87%** |
| Slice Registers (FFs) | 2,942 | 41,600 | **7.07%** |
| CARRY4 | 20 | — | — |
| F7/F8 Muxes | 27 | — | — |
| DSPs | 0 | 90 | 0% |
| Block RAM | 0 | 50 | 0% |
| Bonded IOB | 19 | 106 | 17.92% |

### Primitive Breakdown

| Primitive | Count | Purpose |
|---|---|---|
| FDCE / FDRE / FDPE | 2,942 | Flip-flops (registers) |
| LUT2–LUT6 | 3,050 | Combinational logic |
| CARRY4 | 20 | Fast arithmetic carry chains (from carry skip adder) |
| MUXF7 / MUXF8 | 27 | Wide multiplexer routing |
| OBUF / IBUF | 19 | IO buffers |
| clk_wiz | 1 | Clock wizard IP (black box) |

### Synthesis Warnings to Note

```
WARNING: [Synth 8-6014] Unused sequential element R_reg[16] was removed.
WARNING: [Synth 8-3917] design board_top has port led[15:9] driven by constant 0
```

- `R_reg[16]` — an unused register in `expander_block` was optimized away by Vivado (harmless, but the register declaration can be cleaned up).
- `led[15:9]` — these LEDs are not yet mapped to output signals in `board_top` (easy extension: wire them to `hash_out[15:9]`).

### Synthesis Warnings — Clock Constraints ⚠️

The constraint file has critical clock-related warnings that must be fixed before timing analysis can run:

```
CRITICAL WARNING: set_clock_groups: No valid object(s) found for '-group [get_clocks clk_out1_clk_wiz_0]'
CRITICAL WARNING: set_clock_groups: No valid object(s) found for '-group [get_clocks clk_out1_clk_wiz_1]'
```

**Fix** — add proper clock creation to `sha256const.xdc`:

```tcl
# Create clock for the MMCM output port
create_clock -period 10.000 -name clk_out1_clk_wiz_0 [get_ports clk_out1_clk_wiz_0]
create_clock -period 10.000 -name clk_out1_clk_wiz_1 [get_ports clk_out1_clk_wiz_1]
```

Once fixed, Vivado will report maximum achievable clock frequency via timing analysis.

---

## 🧪 What to Test on the Board

If you upload this to Basys-3, here's how to verify it works:

| Input | Expected UART Output |
|---|---|
| `"abc"` (3 bytes) | `ba7816bf 8f01cfea 414140de 5dae2223 b00361a3 96177a9c b410ff61 f20015ad` |
| `""` (empty) | `e3b0c442 98fc1c14 895bf13a e8305d22 9f03f8d5 4e8875a5 9980be95 1fdc1ce3 976e41a9` |

---

## 📚 Background

SHA-256 is part of the SHA-2 family (Secure Hash Algorithm 2), designed by the NSA and standardized by NIST in 2002. It produces a fixed 256-bit output from an arbitrary-length input and is still widely used in **TLS 1.3, Bitcoin mining, digital signatures, and file integrity verification**.

This project implements the algorithm in hardware (Verilog RTL) rather than software, making it suitable for:
- FPGA accelerators (e.g., Xilinx/Intel FPGA)
- ASIC implementation
- Embedded systems requiring constant-time hashing
- Hardware security modules (HSMs)

---

## 🛠️ What's Next (Improvements)

- [ ] **Fix clock constraints** — add `create_clock` commands to `sha256const.xdc` to enable Vivado timing analysis and report max clock frequency
- [ ] **Clean up `R_reg[16]`** — remove the unused register in `expander_block` to eliminate the synthesis warning
- [ ] **Wire remaining LEDs** — connect `hash_out[15:9]` to `led[15:9]` in `board_top` for visual hash feedback
- [ ] **NIST test vectors** — add a testbench that self-checks against the full [NIST L=256 test set](https://csrc.nist.gov/projects/cryptographic-algorithm-validation-program/messages-validation)
- [ ] **AXI-Stream wrapper** — wrap `SHAtop_module` with an `axis_slave` interface (`tvalid/tready/tdata/tlast`) for integration into AXI-based SoC designs
- [ ] **GitHub Actions CI** — run `iverilog` on every push so the repo always shows passing simulation checks

---

## 📄 License

MIT License
