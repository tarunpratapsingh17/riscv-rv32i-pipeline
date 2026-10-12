#!/usr/bin/env python3
"""
Fault injection: plant a classic pipeline bug into a copy of the RTL and check
that the test suite catches it. Every mutation must make at least one test fail.

    python3 scripts/fault_injection.py
"""
import glob
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run_tests import compile_tb, run_one, ROOT  # noqa: E402

# (description, file, original text, mutated text)
MUTATIONS = [
    ("no forwarding from EX/MEM",
     "rv32i_hazard_unit.v", "assign fwd_a = (mem_fwd_ok && mem_rd == ex_rs1) ? 2'b10 :",
     "assign fwd_a = (1'b0 && mem_rd == ex_rs1) ? 2'b10 :"),
    ("no forwarding from MEM/WB",
     "rv32i_hazard_unit.v", "(wb_fwd_ok  && wb_rd  == ex_rs2) ? 2'b01 : 2'b00;",
     "(1'b0 && wb_rd  == ex_rs2) ? 2'b01 : 2'b00;"),
    ("no load-use stall",
     "rv32i_hazard_unit.v", "assign load_use_stall = id_valid && ex_valid",
     "assign load_use_stall = 1'b0 && id_valid && ex_valid"),
    ("wrong-path instruction not flushed from IF/ID",
     "rv32i_core.v", "end else if (redirect) begin           // wrong-path instruction",
     "end else if (1'b0) begin           // wrong-path instruction"),
    ("register-file write bypass removed",
     "rv32i_regfile.v", "assign rdata1 = (raddr1 == 5'd0) ? 32'd0 : bypass1 ? wdata : regs[raddr1];",
     "assign rdata1 = (raddr1 == 5'd0) ? 32'd0 : regs[raddr1];"),
    ("x0 not hard-wired to zero",
     "rv32i_regfile.v", "assign rdata2 = (raddr2 == 5'd0) ? 32'd0 :",
     "assign rdata2 = 1'b0 ? 32'd0 :"),
    ("SRA behaves like SRL",
     "rv32i_alu.v", "`ALU_SRA:  y = $unsigned($signed(a) >>> shamt);",
     "`ALU_SRA:  y = a >> shamt;"),
    ("BLTU uses a signed compare",
     "rv32i_core.v", "`F3_BLTU: br_cond = (rs1_val <  rs2_val);",
     "`F3_BLTU: br_cond = ($signed(rs1_val) <  $signed(rs2_val));"),
    ("LB zero-extends instead of sign-extending",
     "rv32i_lsu.v", "`F3_B:   load_data = {{24{shifted[7]}},  shifted[7:0]};",
     "`F3_B:   load_data = {24'd0,  shifted[7:0]};"),
    ("SH always writes the low half-word",
     "rv32i_lsu.v", "wstrb = byte_off[1] ? 4'b1100 : 4'b0011;", "wstrb = 4'b0011;"),
    ("JAL/JALR link register gets pc instead of pc+4",
     "rv32i_core.v", "wire [31:0] ex_result = (id_ex_wb_sel == `WB_PC4) ? pc_plus4 : alu_y;",
     "wire [31:0] ex_result = (id_ex_wb_sel == `WB_PC4) ? id_ex_pc : alu_y;"),
    ("FENCE.I does not flush the pipeline",
     "rv32i_decoder.v", "fence_i = (funct3 == 3'b001);", "fence_i = 1'b0;"),
]


def main():
    # official suite first, then directed tests, then the (slower) C programs
    order = {"rv32ui": 0, "dir": 1, "c": 2}
    hexes = sorted(glob.glob(os.path.join(ROOT, "tests", "hex", "*.hex")),
                   key=lambda h: (order[os.path.basename(h).split("-")[0]], h))
    killed = 0
    with tempfile.TemporaryDirectory() as tmp:
        # baseline: known-good cycle counts give each run a tight timeout
        good = compile_tb(None, os.path.join(tmp, "good.vvp"))
        limit = {}
        for h in hexes:
            ok, st, _ = run_one(good, h, cwd=tmp)
            if not ok:
                sys.exit(f"baseline RTL fails {os.path.basename(h)} - fix that first")
            limit[h] = 2 * int(st["cycles"]) + 1000

        for desc, fname, orig, mut in MUTATIONS:
            mdir = os.path.join(tmp, "rtl")
            shutil.rmtree(mdir, ignore_errors=True)
            shutil.copytree(os.path.join(ROOT, "rtl"), mdir)
            path = os.path.join(mdir, fname)
            src = open(path).read()
            if orig not in src:
                print(f"SKIP      {desc}: pattern not found")
                continue
            open(path, "w").write(src.replace(orig, mut, 1))
            vvp = compile_tb(mdir, os.path.join(tmp, "m.vvp"))

            caught_by = None
            for h in hexes:                       # stop at the first failing test
                ok, _, _ = run_one(vvp, h, [f"+max_cycles={limit[h]}"], cwd=tmp)
                if not ok:
                    caught_by = os.path.basename(h)[:-4]
                    break
            if caught_by:
                killed += 1
                print(f"KILLED    {desc:<48} first caught by {caught_by}")
            else:
                print(f"SURVIVED  {desc:<48} no test noticed")

    print("-" * 78)
    print(f"{killed}/{len(MUTATIONS)} injected bugs caught by the test suite")
    sys.exit(0 if killed == len(MUTATIONS) else 1)


if __name__ == "__main__":
    main()
