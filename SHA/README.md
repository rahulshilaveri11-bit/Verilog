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
├── SHAtop_module/          # Top-level accelerator module + testbench
├── message_padding/        # SHA-256 message padding (FIPS 180-4 §5.1.1)
├── expander_block/         # Message schedule W[0..63] generator
├── compressor_block/       # 64-round compression function
├── functions/              # Reusable SHA-256 logical functions
│   └── sha_256_functions.vh
└── README.md               # NIST constants & initial hash values
```

### Module Overview

| Module | Responsibility |
|---|---|
| `SHAtop_module` | Top-level wrapper. FSM-based sequencer, input handshake, pipelined coordination of all sub-blocks |
| `message_padding` | Accepts a byte stream and appends padding + 64-bit message length per FIPS 180-4. Handles single-block and multi-block messages |
| `expander_block` | Expands each 512-bit padded block into the 64-word message schedule W[0..63] |
| `compressor_block` | Executes the 64-round compression function using working variables A–H and round constants K[0..63] |
| `sha_256_functions.vh` | Shared logical functions: ROTR, SHR, Ch, Maj, Σ₀, Σ₁, σ₀, σ₁ |

---

## 🧩 Design Highlights

- **Streaming input** — byte-level handshake (`valid_input`, `byte_in`, `last_byte`) handles messages of any length without fixed-size buffers
- **NIST FIPS 180-4 compliant** — message padding, round constants (K[0–63]), and initial hash values (H[0–7]) all sourced from the official spec
- **Modular pipeline** — three-stage pipeline (pad → expand → compress) with a sequencer FSM ensuring correct cycle-level timing
- **Clean FSM design** — `message_padding` uses a 5-state FSM (`IDLE → RECEIVING → PADDING → EXTRA_BLOCK_FILL → FLUSH`) to handle edge cases (e.g., 448-bit boundary, extra block for long length fields)
- **Synchronous, register-based** — all state in registers clocked on `clk`; asynchronous `rst` resets everything cleanly
- **Testbenches included** — every module has a corresponding `.tb` testbench

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
    compressor_block/compressor_block.v
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

---

## 📚 Background

SHA-256 is part of the SHA-2 family (Secure Hash Algorithm 2), designed by the NSA and standardized by NIST in 2002. It produces a fixed 256-bit output from an arbitrary-length input and is still widely used in **TLS 1.3, Bitcoin mining, digital signatures, and file integrity verification**.

This project implements the algorithm in hardware (Verilog RTL) rather than software, making it suitable for:
- FPGA accelerators (e.g., Xilinx/Intel FPGA)
- ASIC implementation
- Embedded systems requiring constant-time hashing
- Hardware security modules (HSMs)

---

## 📄 License

MIT License
