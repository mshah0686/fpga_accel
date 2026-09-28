"""Quantize a float weight dump to signed 16-bit fixed point.

Run it:  python3 scripts/quantizer.py scripts/training_weights/hidden_weights.txt
         python3 scripts/quantizer.py <file> --scale 16384             # weights, Q2.14
         python3 scripts/quantizer.py <bias>  --scale 2097152 --width 32  # Q11.21
Output:  scripts/quantized_weights/<same name>
"""

import argparse
import math
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(SCRIPT_DIR, "quantized_weights")


def read_floats(path):
    with open(path) as f:
        return [[float(v) for v in line.split()] for line in f if line.strip()]


def pick_format(max_abs, width):
    """1 sign bit + int_bits + frac_bits = width, int bits sized to hold max_abs."""
    int_bits = 0 if max_abs == 0 else max(0, math.ceil(math.log2(max_abs)))
    return int_bits, width - 1 - int_bits


def quantize(rows, scale, width):
    lo, hi = -(1 << (width - 1)), (1 << (width - 1)) - 1
    out = []
    clipped = 0
    for row in rows:
        q_row = []
        for v in row:
            q = int(round(v * scale))
            if q < lo or q > hi:
                clipped += 1
                q = max(lo, min(hi, q))
            q_row.append(q)
        out.append(q_row)
    return out, clipped


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("-o", "--output")
    parser.add_argument("-s", "--scale", type=int,
                        help="multiplier to use, e.g. 16384 for Q2.14 "
                             "(default: sized from the file's own range)")
    parser.add_argument("-w", "--width", type=int, default=16,
                        help="output word width in bits (default 16; use 32 for biases)")
    args = parser.parse_args()

    rows = read_floats(args.input)
    flat = [v for row in rows for v in row]
    lo, hi = min(flat), max(flat)
    max_abs = max(abs(lo), abs(hi))

    if args.scale:
        scale = float(args.scale)
        frac_bits = int(round(math.log2(scale)))
        int_bits = args.width - 1 - frac_bits
    else:
        int_bits, frac_bits = pick_format(max_abs, args.width)
        scale = float(1 << frac_bits)
    q_rows, clipped = quantize(rows, scale, args.width)

    if scale == float(1 << frac_bits) and 0 <= int_bits:
        fmt = f"Q{int_bits + 1}.{frac_bits}"
    else:
        fmt = "custom"

    out_path = args.output
    if out_path is None:
        os.makedirs(OUT_DIR, exist_ok=True)
        out_path = os.path.join(OUT_DIR, os.path.basename(args.input))

    with open(out_path, 'w') as f:
        f.write(f"# source {args.input}\n")
        f.write(f"# shape {len(rows)}x{len(rows[0])}\n")
        f.write(f"# range min {lo!r} max {hi!r} max_abs {max_abs!r}\n")
        f.write(f"# format {fmt} scale {int(scale)} width {args.width} clipped {clipped}\n")
        for row in q_rows:
            f.write(" ".join(str(q) for q in row) + "\n")

    print(f"Saved: {out_path} ({len(rows)}x{len(rows[0])})")
    print(f"Range: [{lo:.6f}, {hi:.6f}]  max_abs {max_abs:.6f}")
    print(f"Format: {fmt}, scale {int(scale)}, width {args.width}, clipped {clipped}")
