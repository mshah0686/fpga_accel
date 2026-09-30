"""Sweep tb_pipe over a range of MNIST test images.

For each index: regenerate the goldens with pipeline.py, rerun the compiled
testbench, and record whether it passed.

The testbench is built once up front rather than per index -- only the
golden_*.hex files change between iterations, and tb_pipe.v $readmemh's them at
time 0 of every run, so nothing needs recompiling.

    python3 fpga_files/tb/pipe/iterate_many_index.py                 # images 0-100
    python3 fpga_files/tb/pipe/iterate_many_index.py --start 200 --end 250
    python3 fpga_files/tb/pipe/iterate_many_index.py --indices 3,8,42

stdout and stderr from failing runs are written to tb/pipe/iterate_logs/.
Exits non-zero if any index failed. The goldens left on disk afterwards are
whichever index ran last, so re-run pipeline.py before debugging a single image.
"""

import argparse
import os
import re
import subprocess
import sys

TB_DIR = os.path.dirname(os.path.abspath(__file__))
FPGA_DIR = os.path.abspath(os.path.join(TB_DIR, os.pardir, os.pardir))
REPO_DIR = os.path.abspath(os.path.join(FPGA_DIR, os.pardir))

PIPELINE = os.path.join(REPO_DIR, "scripts", "model_pipeline", "pipeline.py")
BUILD_DIR = os.path.join(FPGA_DIR, "build")
BINARY = os.path.join(BUILD_DIR, "tb", "pipe", "pipe_tb")
LOG_DIR = os.path.join(TB_DIR, "iterate_logs")

TB_TARGET = "pipe_tb"
RUN_TIMEOUT_S = 600   # the TB has its own watchdog; this catches a wedged sim


def run(cmd, cwd):
    return subprocess.run(cmd, cwd=cwd, text=True, timeout=RUN_TIMEOUT_S,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def build():
    """Build once. Incremental, so this is a no-op on an up-to-date tree."""
    if not os.path.isdir(BUILD_DIR):
        sys.exit(f"no build dir at {BUILD_DIR} -- run `cmake ..` in it first")

    print(f"building {TB_TARGET} ...", flush=True)
    res = run(["cmake", "--build", ".", "--target", TB_TARGET], BUILD_DIR)
    if res.returncode != 0:
        print(res.stdout)
        sys.exit(f"build failed ({res.returncode})")

    if not os.path.isfile(BINARY):
        sys.exit(f"built, but no binary at {BINARY}")


def gen_goldens(index):
    """Run pipeline.py for one image. Returns (label, model_pred, output)."""
    res = run([sys.executable, PIPELINE, "--index", str(index)], REPO_DIR)
    if res.returncode != 0:
        return None, None, res.stdout

    # "ran     MNIST t10k image 0, true label 7" / "argmax  7  (hit)"
    label = re.search(r"true label (\d+)", res.stdout)
    pred = re.search(r"^argmax\s+(\d+)", res.stdout, re.MULTILINE)
    return (int(label.group(1)) if label else None,
            int(pred.group(1)) if pred else None,
            res.stdout)


def run_tb():
    """Run the sim from fpga_files/ so golden/ and weights/ resolve.

    Returns (passed, first FAIL line or None, output).
    """
    res = run([BINARY], FPGA_DIR)
    fail = next((l.strip() for l in res.stdout.splitlines() if "FAIL" in l), None)
    return res.returncode == 0 and fail is None, fail, res.stdout


def describe(fail_line):
    """'[16090] FAIL output class 6: expected ...' -> 'output class 6'."""
    if not fail_line:
        return "nonzero exit, no FAIL line"
    after = fail_line.split("FAIL", 1)[1].strip()
    return after.split(":", 1)[0].strip() or after


def write_log(index, text):
    os.makedirs(LOG_DIR, exist_ok=True)
    path = os.path.join(LOG_DIR, f"index_{index}.log")
    with open(path, 'w') as f:
        f.write(text)
    return os.path.relpath(path, REPO_DIR)


def parse_indices(args):
    if args.indices:
        return [int(v) for v in args.indices.replace(",", " ").split()]
    if args.end < args.start:
        sys.exit(f"--end {args.end} is below --start {args.start}")
    return list(range(args.start, args.end + 1))


def main():
    parser = argparse.ArgumentParser(
        description="Run tb_pipe against pipeline.py goldens over many MNIST images.")
    parser.add_argument("--start", type=int, default=0,
                        help="first MNIST t10k index (default 0)")
    parser.add_argument("--end", type=int, default=100,
                        help="last index, inclusive (default 100)")
    parser.add_argument("--indices",
                        help="explicit comma/space separated list, overrides "
                             "--start/--end")
    parser.add_argument("--stop-on-fail", action="store_true",
                        help="stop at the first failing index")
    parser.add_argument("--no-build", action="store_true",
                        help="skip the build step and use the existing binary")
    args = parser.parse_args()

    indices = parse_indices(args)

    if args.no_build:
        if not os.path.isfile(BINARY):
            sys.exit(f"no binary at {BINARY} -- drop --no-build")
    else:
        build()

    if not indices:
        sys.exit("no indices to run")

    print(f"sweeping {len(indices)} image(s), {indices[0]} to {indices[-1]}",
          flush=True)
    print(f"{'idx':>5}  {'label':>5}  {'model':>5}  result", flush=True)

    failures = []
    model_misses = []
    checked = 0

    for index in indices:
        checked += 1
        label, pred, out = gen_goldens(index)
        if pred is None:
            log = write_log(index, out)
            failures.append((index, "pipeline.py failed", log))
            print(f"{index:>5}  {'?':>5}  {'?':>5}  PIPELINE ERROR  ({log})",
                  flush=True)
            if args.stop_on_fail:
                break
            continue

        if pred != label:
            model_misses.append(index)

        passed, fail_line, out = run_tb()
        if passed:
            print(f"{index:>5}  {label:>5}  {pred:>5}  PASS", flush=True)
        else:
            what = describe(fail_line)
            log = write_log(index, out)
            failures.append((index, what, log))
            print(f"{index:>5}  {label:>5}  {pred:>5}  FAIL  {what}  ({log})",
                  flush=True)
            if args.stop_on_fail:
                break

    print()
    print(f"ran     {checked} of {len(indices)} image(s)")
    print(f"passed  {checked - len(failures)}")
    print(f"failed  {len(failures)}")
    if model_misses:
        print(f"note    the model itself missed the label on {len(model_misses)} "
              f"image(s): {model_misses[:20]}"
              f"{' ...' if len(model_misses) > 20 else ''}")
        print("        a model miss is a quantization/accuracy result, not a "
              "testbench failure")

    if failures:
        print("\nfailing indices:")
        for index, what, log in failures:
            print(f"  {index:>5}  {what}  -> {log}")
        return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit("\ninterrupted")
