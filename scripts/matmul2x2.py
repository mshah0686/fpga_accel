#!/usr/bin/env python3
"""2x2 matrix multiply on hex values.

Input file format: 4 lines, 2 hex numbers per line.
    line 1-2 -> matrix A (row 0, row 1)
    line 3-4 -> matrix B (row 0, row 1)

Blank lines and lines starting with '#' are ignored. The '0x' prefix is
optional. Results are printed in hex, truncated to ACC_WIDTH bits to match
the accumulator in the RTL.

    python3 scripts/matmul2x2.py scripts/example.txt
"""

import sys

ACC_WIDTH = 16
ACC_MASK = (1 << ACC_WIDTH) - 1


def read_matrices(path):
    with open(path) as f:
        rows = []
        for line in f:
            line = line.split('#')[0].strip()
            if not line:
                continue
            vals = [int(tok, 16) for tok in line.replace(',', ' ').split()]
            if len(vals) != 2:
                sys.exit(f"{path}: expected 2 hex values per line, got {len(vals)}: {line!r}")
            rows.append(vals)

    if len(rows) != 4:
        sys.exit(f"{path}: expected 4 rows (2 for A, 2 for B), got {len(rows)}")

    return rows[:2], rows[2:]


def matmul(a, b):
    return [[sum(a[r][k] * b[k][c] for k in range(2)) & ACC_MASK
             for c in range(2)]
            for r in range(2)]


def show(name, m, width):
    print(f"{name} =")
    for row in m:
        print("  " + "  ".join(f"0x{v:0{width}X}" for v in row))


def main():
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} <input.txt>")

    a, b = read_matrices(sys.argv[1])
    c = matmul(a, b)

    show("A", a, 2)
    show("B", b, 2)
    show("C = A x B", c, ACC_WIDTH // 4)


if __name__ == "__main__":
    main()
