# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Hard rule: do not write RTL

From the README: **"No AI is used to write any RTL."** The `.sv`/`.v` files under `fpga_files/rtl/` are
the entire point of this project — the author is learning RTL design by hand. AI is used only for:

- Architecture discussion (talk through uArch, dataflow, CDC, FIFO/BRAM tradeoffs)
- CMake / build plumbing
- Basic testbench scaffolding
- Python host scripts

If asked to "fix" or "add" something and the natural implementation lands in `fpga_files/rtl/`, stop and
describe the change instead of writing it — unless the user explicitly asks for RTL edits in that message.
Testbenches (`fpga_files/tb/`), CMake, `main/` firmware, and `scripts/` are fair game.

## What this is

An MNIST digit-inference accelerator split across an ESP32 (host) and an FPGA (accelerator), connected by
SPI. The ESP32 streams 28x28 pixels and control writes over SPI; the FPGA runs a hardcoded
784 -> 16 -> ReLU -> 10 -> argmax network entirely in fabric and returns the predicted digit.

Weights/biases are baked into BRAM at synthesis time (`$readmemh` preload) — a deliberate tradeoff for
learning simplicity over a programmable accelerator.

Board history: started on a Nandland GO Board (iCE40, 1k LUTs — too small for 784-wide), moving to a
Nexys A7 100T. `fpga_files/rtl/apio.ini` still targets `go-board`.

## Commands

### Verilator simulation (the main dev loop)

Build dir is `fpga_files/build/`, already configured. Testbenches are registered in
`fpga_files/CmakeLists.txt` — **only `tb/pipe` is currently enabled**; the others are commented out
because they reference pre-refactor module shapes.

```bash
cd fpga_files/build
cmake ..                              # only needed after editing a CmakeLists.txt
cmake --build . --target pipe_tb      # targets: pipe_tb, matrix_mult_tb, top_tb, spi_timer_control (when enabled)

# Run from fpga_files/, NOT from build/ — see the working-directory note below
cd .. && ./build/tb/pipe/pipe_tb
```

VCDs land in `fpga_files/waves/`. The `.ron` files next to them are Surfer viewer state.

**Working directory matters.** The RTL calls `$readmemh("weights/hidden_0.hex", ...)`, resolved against
the simulator's CWD. Each TB's `CmakeLists.txt` creates a `fpga_files/weights -> rtl/weights` symlink for
this. Running a TB binary from anywhere but `fpga_files/` silently preloads zeros.

Lint a single module without a full TB:

```bash
cd fpga_files
verilator --lint-only -Irtl -Irtl/spi -Irtl/compute rtl/compute/pipe_top.sv --top-module pipe_top
```

### Host scripts (weights + goldens)

`scripts/README.md` is thorough — read it before touching these. The short version:

```bash
python3 scripts/train_minst.py                      # train, export weights, dump goldens for test image 0
python3 scripts/train_minst.py --load --index 42    # re-dump goldens for a different image, no retrain
python3 scripts/gen_matmul_golden.py                # regenerate tb/matrix_mult/expected_c.hex
```

`train_minst.py` writes directly into `fpga_files/rtl/weights/` and `fpga_files/tb/pipe/`. **Re-run
`gen_matmul_golden.py` after every `train_minst.py` run** — it reads the same `.hex` files and goes stale
otherwise.

### ESP32 firmware

Standard ESP-IDF (v6.0.1, per `.vscode/settings.json`; port `/dev/tty.usbserial-0001`):

```bash
idf.py build
idf.py -p /dev/tty.usbserial-0001 flash monitor
```

### Synthesis

`apio` drives yosys/nextpnr from `fpga_files/rtl/` (`apio build`, `apio upload`). Note the old Lattice
toolchain could not handle SystemVerilog, which is why the flow moved to apio/yosys.

## Architecture

### Data path, end to end

```
ESP32 (main/)                    FPGA (fpga_files/rtl/)
matrix_controller.c              spi_rx (SPI clk domain)
  -> matrix_to_spi_queue           -> spi_rx_sync    [CDC: handshake, not a FIFO]
  -> spi_wrap.c (SPI master)       -> packet_decoder [drops NOPs, splits fields]
                                   -> register_model [tag/addr decode, the only RAL]
                                      -> pipe_top     (pixel writes, go bit, status/result reads)
                                      -> async_fifo -> spi_tx (read data back out on POCI)
```

The CDC in `spi_rx_sync` is a handshake, deliberately **not** an async FIFO on `spi_sck`: the ESP32 only
toggles SCK while CS is asserted, so a FIFO clocked on SCK would stall a transaction's last word until the
*next* transaction arrived. This bug and its diagnosis are written up in `docs/project_log.md` (July 1st).

The TX path *does* use `async_fifo`, clocked on `~spi_sck` — SPI drives on negedge, latches on posedge.

### SPI packet format

32 bits, defined by macros in `fpga_files/rtl/fpga_types.sv`:

```
[CMD: 2][TAG: 2][ADDR: 10][DATA: 16]

CMD:  NOP=0  READ=1  WRITE=2
TAG:  PIXEL=0  MATRIX=1
ADDR (PIXEL):  index into the 784 flattened pixels
ADDR (MATRIX): 0x0 = STATUS/CONTROL, 0x1 = RESULT
```

Reads take **two** transactions: the READ, then a follow-up (NOP is fine) for the FPGA to shift the
response back — the RX CDC plus RAL turnaround exceeds one packet's latency.

16-bit DATA carries **two pixels per write**, halving the 784 pixel writes. The RTL is mid-migration to
this (`pipe_top` has a `FIXME` on the still-8-bit pixel write port).

### Inference pipeline (`rtl/compute/pipe_top.sv`)

`pipe_control_fsm` sequences two passes over the same `matrix_mult_top` pattern, alternating a
`compute_block` register between HIDDEN and OUTPUT on each GO pulse:

1. **Hidden** — `matrix_mult_top` M=16, K=784, N=1. A-operand from 16 preloaded weight BRAMs
   (`weights/hidden_0..15.hex`), B-operand from the pixel BRAM. Bias via the `MAC_BIAS` parameter.
2. **ReLU** — purely combinational (`relu.sv`), latched on `hidden_result_valid`.
3. **Output** — `matrix_mult_top` M=10, K=16, N=1. Weights from 10 BRAMs; the 16 activations are small
   enough to live in flops, so `output_activations_bram_rd_*` is a *fake* BRAM interface muxing the
   latched ReLU registers.
4. **Argmax** — combinational, latched on `output_result_valid`.

The multiplier is an **output-stationary systolic array**: `mult_datapath` staggers A along rows and B
down columns into a `systolic_mac` grid, accumulators stay put, and completion is a hardcoded
`M + N + K - 2` cycle count rather than a done-signal from the array. `MAC_BIAS` preloads each PE's
accumulator on the `first_in` term.

`bram_wrapper` instantiates N `single_port_bram`s (one per array edge node) and sign- or zero-extends
their output to `OUTDATA_WIDTH` — that's how 16-bit Q8.8 weights and 8-bit unsigned pixels feed a common
`MAX_DATA_WIDTH` datapath.

### Fixed-point contract

Silently breaking this is the easiest way to get wrong-but-plausible results. Full table in
`scripts/README.md`; the essentials:

| Value | Format | Scale |
|---|---|---|
| Weights (`hidden_*.hex`, `output_*.hex`) | Q8.8 signed 16-bit | 256 |
| Pixels | raw uint8, zero-extended | 255 |
| Biases (`*_biases.svh`) | Q24.8 signed 32-bit | 256 |
| Hidden accumulator / ReLU | signed 32-bit | 65280 |
| Output logits | signed 32-bit | 16711680 |

Biases are quantized at 256 but preloaded into accumulators whose other terms arrive at 65280 — the
`float` vs `fixed/65280` gap in the script's dump is expected, not a bug.

Also note `argmax.sv` compares the packed vector **unsigned**, so a negative logit outranks every positive
one. `train_minst.py` prints both the signed and unsigned answers on purpose, and writes the *unsigned*
one to `expected_argmax.hex` to match the hardware.

## Current state

The compute pipeline (`pipe_top` and below) builds, simulates, and runs. The SPI/RAL path above it is
**mid-refactor and does not lint**: `top.sv` and `register_model.sv` have syntax errors (stray trailing
commas, duplicated `wire` declarations, undeclared signals), and `fpga_types.sv` defines `` `TAG_WIDTTH ``
while consumers reference `` `TAG_WIDTH ``. This is in-flight hand-written RTL work — surface it, don't
silently repair it.

`tb_pipe.v` drives a constant `0xCC` pixel and the pixel BRAM is `PRELOAD=0`, so `pixels_0.hex` and the
`expected_*.hex` goldens are generated but not yet consumed. Wiring real stimulus and comparison into
`tb_pipe` is a known open task.

## Journal

`docs/project_log.md` is a dated engineering journal — status, the bug being chased, and next steps per
session. It is the best source for *why* a design choice was made. When work wraps up a meaningful chunk,
append a dated entry in the existing style rather than editing older ones.

Typos in signal/parameter names (`NUERONS`, `TAG_WIDTTH`, `train_minst`) are load-bearing — match them.
