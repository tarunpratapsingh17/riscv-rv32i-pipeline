# Pre-built test images

These `.hex` files are memory images loaded by `tb/tb_rv32i.v` (`+hex=<file>`),
so the simulation can be run with only Icarus Verilog installed.

| Prefix | Source |
|--------|--------|
| `rv32ui-*` | Official RISC-V unit tests, [riscv-tests](https://github.com/riscv-software-src/riscv-tests) `isa/rv32ui`, built with the bare-metal environment in `sw/env/`. Licensed under BSD-3-Clause, see `LICENSE-riscv-tests`. |
| `dir-*` | Directed assembly tests in `sw/asm/` |
| `c-*` | Self-checking C programs in `sw/c/` |

Rebuild them with `python3 scripts/build_tests.py` (needs `riscv64-unknown-elf-gcc`
and a riscv-tests checkout in `third_party/riscv-tests`).
