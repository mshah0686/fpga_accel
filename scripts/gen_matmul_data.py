#!/usr/bin/env python3
"""Generate static operands + expected product for the matrix_mult testbench.

Models one dense neural-net layer: a MxK weight matrix times a Kx1 pixel
column, giving a Mx1 activation column.

    A (16x784) weights  *  B (784x1) pixels  =  C (16x1) activations

Operands are drawn from a fixed-seed PRNG so the data is "random" but
reproducible: rerunning this script regenerates byte-identical values, and
the expected results stay valid. Output is a Verilog include file of plain
assignments, meant to be `included inside the testbench initial block.

    python3 scripts/gen_matmul_data.py

Results are masked to ACC_WIDTH bits to match the RTL accumulator.
"""

import argparse
import random
import sys

DEFAULT_OUT = "fpga_files/tb/matrix_mult/matrix_data.vh"


def build_matrices(m, k, n, d_width, seed):
    """Random A (m x k) and B (k x n), each element d_width bits unsigned."""
    rng = random.Random(seed)
    hi = (1 << d_width) - 1
    a = [[rng.randint(0, hi) for _ in range(k)] for _ in range(m)]
    b = [[rng.randint(0, hi) for _ in range(n)] for _ in range(k)]
    return a, b


def matmul(a, b, m, k, n, acc_mask):
    return [[sum(a[r][i] * b[i][c] for i in range(k)) & acc_mask
             for c in range(n)]
            for r in range(m)]


def check_no_overflow(k, d_width, acc_width):
    """The RTL accumulator wraps silently, so refuse to emit a test whose
    worst case could not be represented."""
    worst = k * ((1 << d_width) - 1) ** 2
    if worst >= (1 << acc_width):
        sys.exit(f"ACC_WIDTH={acc_width} too narrow: worst-case sum {worst} "
                 f"needs {worst.bit_length()} bits")
    return worst


def emit_group(f, items, per_line):
    """Write already-formatted assignment strings, per_line of them per line."""
    for base in range(0, len(items), per_line):
        f.write("    " + " ".join(items[base:base + per_line]) + "\n")


def emit_assignments(f, lhs, rows, cols, values, d_width, per_line):
    """Write `lhs[r][c] = <d_width>'hXX;` assignments, per_line per source line.

    A single-column operand is walked down its rows instead of across its
    columns, so a Kx1 vector does not turn into K one-element lines."""
    if cols == 1:
        f.write(f"    // {lhs}[0..{rows - 1}][0]\n")
        emit_group(f, [f"{lhs}[{r}][0] = {d_width}'h{values[r][0]:02X};"
                       for r in range(rows)], per_line)
        return

    for r in range(rows):
        f.write(f"    // {lhs}[{r}][0..{cols - 1}]\n")
        emit_group(f, [f"{lhs}[{r}][{c}] = {d_width}'h{values[r][c]:02X};"
                       for c in range(cols)], per_line)


def write_include(path, a, b, c, m, k, n, d_width, acc_width, seed, worst):
    with open(path, "w") as f:
        f.write(f"""// -----------------------------------------------------------------------
// GENERATED FILE - do not edit by hand.
//   regenerate: python3 scripts/gen_matmul_data.py
//
// Static operands and expected product for tb_matrix_mult_top.
//   A ({m}x{k}) weights * B ({k}x{n}) pixels = C ({m}x{n}) activations
//   D_WIDTH = {d_width}, ACC_WIDTH = {acc_width}, PRNG seed = {seed:#x}
//
// Worst-case accumulator value for these dimensions is {worst:,},
// which fits in {worst.bit_length()} bits, so ACC_WIDTH={acc_width} cannot overflow.
// -----------------------------------------------------------------------

""")
        f.write(f"    // ===== A: {m}x{k} weight matrix =====\n")
        emit_assignments(f, "a", m, k, a, d_width, 8)

        f.write(f"\n    // ===== B: {k}x{n} pixel column =====\n")
        emit_assignments(f, "b", k, n, b, d_width, 8)

        f.write(f"\n    // ===== Expected C: {m}x{n} =====\n")
        for r in range(m):
            for col in range(n):
                f.write(f"    expected_c[{r}][{col}] = {acc_width}'d{c[r][col]};"
                        f"  // 0x{c[r][col]:07X}\n")


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("-m", type=int, default=16, help="rows of A / rows of C (default 16)")
    p.add_argument("-k", type=int, default=784, help="cols of A / rows of B (default 784)")
    p.add_argument("-n", type=int, default=1, help="cols of B / cols of C (default 1)")
    p.add_argument("--d-width", type=int, default=8, help="operand bits (default 8)")
    p.add_argument("--acc-width", type=int, default=26, help="accumulator bits (default 26)")
    p.add_argument("--seed", type=lambda s: int(s, 0), default=0xC0FFEE, help="PRNG seed")
    p.add_argument("-o", "--out", default=DEFAULT_OUT, help=f"output path (default {DEFAULT_OUT})")
    args = p.parse_args()

    worst = check_no_overflow(args.k, args.d_width, args.acc_width)

    a, b = build_matrices(args.m, args.k, args.n, args.d_width, args.seed)
    c = matmul(a, b, args.m, args.k, args.n, (1 << args.acc_width) - 1)

    write_include(args.out, a, b, c, args.m, args.k, args.n,
                  args.d_width, args.acc_width, args.seed, worst)

    print(f"A = {args.m}x{args.k}, B = {args.k}x{args.n}, "
          f"D_WIDTH={args.d_width}, ACC_WIDTH={args.acc_width}, seed={args.seed:#x}")
    print(f"worst-case accumulator = {worst:,} ({worst.bit_length()} bits) -> fits\n")
    print(f"C = A x B  ({args.m}x{args.n}):")
    for r in range(args.m):
        cells = "  ".join(f"{v:>10,} (0x{v:07X})" for v in c[r])
        print(f"  c[{r:2d}] = {cells}")
    print(f"\nwrote {args.out}")


if __name__ == "__main__":
    main()
