#!/usr/bin/env python3
"""
Build the test programs into hex images for the testbench.

  * official RV32I unit tests (rv32ui) from riscv-tests, using the bare-metal
    environment in sw/env/
  * directed assembly tests from sw/asm/ (cases the official suite misses)
  * self-checking C programs from sw/c/

Needs riscv64-unknown-elf-gcc (with the rv32i multilib) and a checkout of
riscv-tests:

    git clone --depth 1 https://github.com/riscv-software-src/riscv-tests third_party/riscv-tests
    python3 scripts/build_tests.py

Output: tests/hex/*.hex (committed, so the simulation can run without the
toolchain) and build/*.elf / build/*.dump (disassembly, not committed).
"""
import argparse
import glob
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HEX_DIR = os.path.join(ROOT, "tests", "hex")
BUILD = os.path.join(ROOT, "build")
CC = "riscv64-unknown-elf-gcc"
OBJCOPY = "riscv64-unknown-elf-objcopy"
OBJDUMP = "riscv64-unknown-elf-objdump"
ARCH = ["-march=rv32i", "-mabi=ilp32"]
ISA_ARCH = ["-march=rv32i_zifencei", "-mabi=ilp32"]   # fence_i test needs Zifencei

# ma_data needs misaligned-access support (trap or hardware) - not implemented
SKIP_ISA = {"ma_data"}
C_PROGRAMS = ["hello", "fib", "sort", "matmul", "primes", "crc32"]
MEM_BYTES = 64 * 1024


def sh(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(" ".join(cmd))
        print(r.stdout + r.stderr)
        sys.exit(1)
    return r.stdout


def elf_to_hex(elf, hex_path):
    binf = elf[:-4] + ".bin"
    sh([OBJCOPY, "-O", "binary", elf, binf])
    data = open(binf, "rb").read()
    if len(data) > MEM_BYTES:
        sys.exit(f"{elf}: image is {len(data)} bytes, larger than {MEM_BYTES}")
    data += b"\x00" * (-len(data) % 4)
    with open(hex_path, "w") as fh:
        for i in range(0, len(data), 4):
            fh.write("%08x\n" % int.from_bytes(data[i:i + 4], "little"))
    with open(elf[:-4] + ".dump", "w") as fh:
        fh.write(sh([OBJDUMP, "-d", "-M", "no-aliases", elf]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--riscv-tests", default=os.path.join(ROOT, "third_party", "riscv-tests"))
    args = ap.parse_args()

    if not shutil.which(CC):
        sys.exit(f"{CC} not found - install the RISC-V GNU toolchain "
                 "(Ubuntu: sudo apt install gcc-riscv64-unknown-elf)")
    rt = args.riscv_tests
    if not os.path.isdir(os.path.join(rt, "isa", "rv32ui")):
        sys.exit(f"riscv-tests not found at {rt}\n"
                 "git clone --depth 1 https://github.com/riscv-software-src/riscv-tests "
                 "third_party/riscv-tests")

    os.makedirs(HEX_DIR, exist_ok=True)
    os.makedirs(BUILD, exist_ok=True)

    # ---------- riscv-tests rv32ui ----------
    n_isa = 0
    for src in sorted(glob.glob(os.path.join(rt, "isa", "rv32ui", "*.S"))):
        name = os.path.splitext(os.path.basename(src))[0]
        if name in SKIP_ISA:
            continue
        elf = os.path.join(BUILD, f"rv32ui-{name}.elf")
        sh([CC] + ISA_ARCH + ["-static", "-nostdlib", "-nostartfiles",
                          "-T", os.path.join(ROOT, "sw", "env", "link.ld"),
                          "-I", os.path.join(ROOT, "sw", "env"),
                          "-I", os.path.join(rt, "isa", "macros", "scalar"),
                          src, "-o", elf])
        elf_to_hex(elf, os.path.join(HEX_DIR, f"rv32ui-{name}.hex"))
        n_isa += 1

    # ---------- directed assembly tests ----------
    n_dir = 0
    for src in sorted(glob.glob(os.path.join(ROOT, "sw", "asm", "*.S"))):
        name = os.path.splitext(os.path.basename(src))[0]
        elf = os.path.join(BUILD, f"dir-{name}.elf")
        sh([CC] + ISA_ARCH + ["-static", "-nostdlib", "-nostartfiles",
                              "-T", os.path.join(ROOT, "sw", "env", "link.ld"),
                              "-I", os.path.join(ROOT, "sw", "env"),
                              "-I", os.path.join(rt, "isa", "macros", "scalar"),
                              src, "-o", elf])
        elf_to_hex(elf, os.path.join(HEX_DIR, f"dir-{name}.hex"))
        n_dir += 1

    # ---------- C programs ----------
    cdir = os.path.join(ROOT, "sw", "c")
    for prog in C_PROGRAMS:
        elf = os.path.join(BUILD, f"c-{prog}.elf")
        sh([CC] + ARCH + ["-O2", "-Wall", "-ffreestanding", "-fno-builtin",
                          "-nostdlib", "-nostartfiles",
                          "-T", os.path.join(cdir, "link_c.ld"),
                          os.path.join(cdir, "crt0.S"), os.path.join(cdir, "lib.c"),
                          os.path.join(cdir, prog + ".c"), "-lgcc", "-o", elf])
        elf_to_hex(elf, os.path.join(HEX_DIR, f"c-{prog}.hex"))

    print(f"built {n_isa} riscv-tests, {n_dir} directed tests and {len(C_PROGRAMS)} C programs "
          "into tests/hex/")


if __name__ == "__main__":
    main()
