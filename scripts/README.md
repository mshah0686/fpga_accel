# scripts/

Host-side tooling that trains the MNIST network, quantizes it into the files the
RTL loads, and generates golden values to check the hardware against.

## Requirements

- `torch` and `torchvision` (developed against 2.8.0 / 0.23.0)
- MNIST is already cached in `scripts/data/`, so nothing is downloaded on a
  normal run.

Every path is anchored to the script's own location, so these commands work from
any working directory.

---

## `train_minst.py`

Trains a 784 -> 16 -> 10 MLP, exports its weights and biases for the RTL, then
runs one image through **both** a float (PyTorch) path and a **bit-exact integer
model of the hardware**, dumping every intermediate layer.

```
usage: train_minst.py [-h] [--load] [--epochs EPOCHS] [--index INDEX]
                      [--split {test,train}]

  --load                skip training and restore mnist_model.pt
  --epochs EPOCHS       training epochs (ignored with --load, default: 3)
  --index INDEX         which image to run inference on (default: 0)
  --split {test,train}  dataset split the image comes from (default: test)
```

### Common tasks

```bash
# Train from scratch (~1-2 min on CPU), export weights, dump goldens for test image 0
python3 scripts/train_minst.py

# Train longer
python3 scripts/train_minst.py --epochs 10

# Re-dump goldens for a different image WITHOUT retraining
python3 scripts/train_minst.py --load --index 42

# Use a training-split image instead
python3 scripts/train_minst.py --load --split train --index 7
```

The model is saved to `scripts/mnist_model.pt` on every training run, so `--load`
always picks up the most recently trained weights. Re-running with `--load` and
the same `--index` is deterministic: identical numbers every time.

### What it writes

| File | Location | Consumed by |
|---|---|---|
| `hidden_0..15.hex` | `fpga_files/rtl/weights/` | hidden weight BRAM (`hidden_weights_bram_u` in `pipe_top.sv`) |
| `output_0..9.hex` | `fpga_files/rtl/weights/` | output weight BRAM (`output_weights_bram_u`) |
| `hidden_biases.svh` | `fpga_files/rtl/weights/` | `` `include ``d by `pipe_top.sv`, feeds `MAC_BIAS` |
| `output_biases.svh` | `fpga_files/rtl/weights/` | `` `include ``d by `pipe_top.sv`, feeds `MAC_BIAS` |
| `pixels_0.hex` | `fpga_files/rtl/weights/` | pixel BRAM, and `gen_matmul_golden.py` |
| `expected_hidden.hex` | `fpga_files/tb/pipe/` | `tb_pipe` — 16 hidden pre-activations |
| `expected_relu.hex` | `fpga_files/tb/pipe/` | `tb_pipe` — 16 ReLU outputs |
| `expected_output.hex` | `fpga_files/tb/pipe/` | `tb_pipe` — 10 output logits |
| `expected_argmax.hex` | `fpga_files/tb/pipe/` | `tb_pipe` — predicted class |
| `mnist_model.pt` | `scripts/` | `--load` |

Each `expected_*.hex` header records the image index, true label, and scale
factor, so a stale golden file identifies itself.

> **Not yet wired up:** `tb_pipe.v` currently drives a constant `0xCC` pixel and
> the pixel BRAM is `PRELOAD=0`, so nothing reads `pixels_0.hex` or the
> `expected_*` files yet. Streaming the image in and comparing is a separate
> TB change.

---

## Fixed-point reference

Every integer in the dumps is a real number multiplied by a fixed scale factor.
The factors differ per stage because the operands do:

| Value | Format | Scale |
|---|---|---|
| Weights (`hidden_*.hex`, `output_*.hex`) | Q8.8, 16-bit signed | 256 |
| Pixels (`pixels_0.hex`) | raw uint8, zero-extended | 255 |
| Biases (`*_biases.svh`) | Q24.8, 32-bit signed | 256 |
| Hidden accumulator / ReLU | 32-bit signed | **65280** (= 256 x 255) |
| Output accumulator (logits) | 32-bit signed | **16711680** (= 256 x 65280) |

To read a dumped value as a real number, divide by its stage's scale — which is
exactly what the `fixed/<scale>` column of the console table shows.

Note the bias rows: biases are quantized at 256 but are preloaded into
accumulators whose other terms arrive at 65280. That difference is visible in the
dump as a gap between the `float` and `fixed/65280` columns.

---

## Reading the dump

```
--- HIDDEN (pre-activation) ---
 idx          float   fixed (hex)     fixed (dec)     fixed/65280
   0      -3.334719      FFFC0068         -262040       -4.014093
```

- `float` — PyTorch's answer, full precision.
- `fixed (hex)` — the exact 32-bit pattern the RTL accumulator holds.
- `fixed (dec)` — the same value read as signed.
- `fixed/<scale>` — the fixed-point value converted back to a real number, so it
  can be compared against `float` directly.

The integer model mirrors the RTL term for term: Q8.8 sign-extended weights,
zero-extended pixel bytes, bias preloaded on the first MAC term, and truncation
to 32 bits after **every** accumulate. If any accumulator wraps, the script
prints an overflow warning naming the untruncated sum.

### The argmax block

```
  true label                 : 7
  float argmax               : 7
  hardware argmax (unsigned) : 8   <- what argmax.sv computes
  hardware argmax (signed)   : 7
```

Both readings are printed on purpose. `argmax.sv` compares a packed **unsigned**
vector, so any negative logit has its MSB set and outranks every positive one.
The signed line is what the math intends; the unsigned line is what the hardware
actually does, and it is the value written to `expected_argmax.hex`.

---

## `gen_matmul_golden.py`

Computes the expected product for `tb_matrix_mult`: the hidden weight matrix
times the pixel vector, straight from the same `.hex` files the BRAMs preload,
written to `fpga_files/tb/matrix_mult/expected_c.hex`.

```bash
python3 scripts/gen_matmul_golden.py
```

**Re-run it whenever `pixels_0.hex` or the hidden weights change** — including
after every `train_minst.py` run. It computes a pure `A*B` with **no bias**, so
its output will not match `expected_hidden.hex`; the two differ by exactly the
preloaded bias term.
