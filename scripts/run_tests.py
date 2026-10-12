#!/usr/bin/env python3
"""
Run every program in tests/hex/ on the core (Icarus Verilog) and print a
pass/fail table with cycles, retired instructions and CPI.

    python3 scripts/run_tests.py                 # all tests
    python3 scripts/run_tests.py c-fib --trace   # one test, print every retired instruction
    python3 scripts/run_tests.py --build         # rebuild hex files first (needs toolchain)

Exit code is 0 only if every test passes.
"""
import argparse
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIM = os.path.join(ROOT, "sim_build")
RTL = ["rv32i_regfile.v", "rv32i_alu.v", "rv32i_imm_gen.v", "rv32i_decoder.v",
       "rv32i_hazard_unit.v", "rv32i_lsu.v", "rv32i_core.v"]


def compile_tb(rtl_dir=None, out=None):
    rtl_dir = rtl_dir or os.path.join(ROOT, "rtl")
    out = out or os.path.join(SIM, "tb_rv32i.vvp")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    cmd = ["iverilog", "-g2005", "-Wall", "-I", rtl_dir, "-o", out] + \
          [os.path.join(rtl_dir, f) for f in RTL] + [os.path.join(ROOT, "tb", "tb_rv32i.v")]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout + r.stderr)
        sys.exit("testbench compile failed")
    return out


def run_one(vvp, hexfile, extra=(), cwd=SIM):
    r = subprocess.run(["vvp", "-n", vvp, f"+hex={hexfile}"] + list(extra),
                       capture_output=True, text=True, errors="replace", cwd=cwd, timeout=600)
    out = r.stdout + r.stderr
    m = re.search(r"RESULT: (PASS|FAIL)(.*)", out)
    if not m:
        return False, None, out
    stats = dict(re.findall(r"(\w+)=([\d.]+)", m.group(2)))
    return m.group(1) == "PASS", stats, out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tests", nargs="*", help="test names (default: all)")
    ap.add_argument("--build", action="store_true", help="rebuild tests/hex first")
    ap.add_argument("--trace", action="store_true", help="print retired instructions")
    ap.add_argument("--vcd", action="store_true", help="dump sim_build/tb_rv32i.vcd")
    args = ap.parse_args()

    if args.build:
        subprocess.run([sys.executable, os.path.join(ROOT, "scripts", "build_tests.py")], check=True)

    hexes = sorted(glob.glob(os.path.join(ROOT, "tests", "hex", "*.hex")))
    if args.tests:
        hexes = [h for h in hexes if os.path.basename(h)[:-4] in args.tests]
    if not hexes:
        sys.exit("no tests found")

    vvp = compile_tb()
    extra = (["+trace"] if args.trace else []) + (["+vcd"] if args.vcd else [])

    n_pass = 0
    print(f"{'test':<22}{'result':<8}{'cycles':>9}{'instret':>9}{'CPI':>8}")
    print("-" * 56)
    for h in hexes:
        name = os.path.basename(h)[:-4]
        ok, st, out = run_one(vvp, h, extra)
        if args.trace or name.startswith("c-"):
            console = [l for l in out.splitlines()
                       if not l.startswith(("RESULT", "VCD info")) and "$finish" not in l
                       and "readmemh" not in l]
            for l in console:
                print("    | " + l)
        n_pass += ok
        if st:
            print(f"{name:<22}{'PASS' if ok else 'FAIL':<8}{st.get('cycles', ''):>9}"
                  f"{st.get('instret', ''):>9}{st.get('cpi', ''):>8}")
        else:
            print(f"{name:<22}FAIL\n" + "\n".join(out.splitlines()[-10:]))
        if not ok and st:
            print("    " + "\n    ".join(l for l in out.splitlines() if "ERROR" in l or "FAIL" in l))

    print("-" * 56)
    print(f"{n_pass}/{len(hexes)} tests passed")
    sys.exit(0 if n_pass == len(hexes) else 1)


if __name__ == "__main__":
    main()
