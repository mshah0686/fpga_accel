Full-chip testbench: instantiates `top` (SPI front-end + register model + inference pipe) and talks to
it only through the SPI pins — no hierarchical pokes into the DUT.

Sequence, matching what the ESP32 firmware does:

1. 392 pixel writes, two pixels per 16-bit DATA field. Pixel `i` goes in the low byte of a write to
   address `i`, pixel `i+1` in the high byte — so pixels 0,1 → addr 0, pixels 2,3 → addr 2, …
2. Write `1` to the MATRIX control register (addr 0) — GO.
3. Poll the MATRIX status register (addr 0) in a loop until bit 0 (idle) reads back high.
4. Read the MATRIX result register (addr 1) and compare the low 4 bits against `golden_argmax.hex`.

Each read is two transactions (the READ, then NOPs until the response shifts back out on POCI); the
monitor keeps the frame only when its top 16 bits are zero, which is how a real response is told apart
from `spi_tx`'s SKIP (POCI held high) and from a write transaction.

Only the pixel stimulus and the final argmax are checked — the intermediate taps are `tb_pipe`'s job.

Goldens come from `scripts/model_pipeline/pipeline.py`, which writes them into `fpga_files/golden/` —
the same files `tb_pipe` reads. `$readmemh` resolves `golden/...` against the simulator's CWD, so run
from the `fpga_files/` root (or use `run_top_tb`, which pins it).

```bash
python3 scripts/model_pipeline/pipeline.py --index 0
cd fpga_files/build && cmake --build . --target run_top_tb
```

VCD goes to `waves/tb_top.vcd` (run from the `fpga_files/` root, or use `run_top_tb`).
