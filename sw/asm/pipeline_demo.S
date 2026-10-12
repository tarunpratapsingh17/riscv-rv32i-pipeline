# -----------------------------------------------------------------------------
# pipeline_demo.S - shows (and checks) the three hazard mechanisms back to back.
# docs/pipeline.png is drawn from a simulation of this program.
#   1. ALU -> ALU dependence      : forwarded, no stall
#   2. load -> use dependence     : 1-cycle stall, then forwarded from MEM/WB
#   3. taken branch               : resolved in EX, 2 younger instructions flushed
# -----------------------------------------------------------------------------
#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32U
RVTEST_CODE_BEGIN

  la    x9, value           # x9 = &value (loaded below)
  li    x6, 0
  li    x7, 0

  addi  x1, x0, 5           # x1 = 5
  addi  x2, x1, 3           # needs x1 next cycle -> EX/MEM forward      x2 = 8
  add   x3, x1, x2          # x1 from MEM/WB, x2 from EX/MEM             x3 = 13
  lw    x4, 0(x9)           # x4 = 100
  add   x5, x4, x1          # load-use: stall 1 cycle                    x5 = 105
  beq   x5, x5, 1f          # always taken
  addi  x6, x0, 1           # wrong path - must be flushed
  addi  x7, x0, 2           # wrong path - must be flushed
1:sub   x8, x5, x3          # x8 = 92

  li    TESTNUM, 2
  li    t0, 92
  bne   x8, t0, fail
  li    TESTNUM, 3
  bne   x6, x0, fail        # flushed instructions must not write
  bne   x7, x0, fail

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

value: .word 100

RVTEST_DATA_END
