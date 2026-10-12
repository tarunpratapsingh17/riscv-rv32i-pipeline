# -----------------------------------------------------------------------------
# fence_i_inline.S - directed test for FENCE.I in straight-line code
#
# The official riscv-tests fence_i test reaches the modified code through a
# jump, which re-fetches anyway, so it passes even if FENCE.I does nothing.
# Here the overwritten instruction sits directly after FENCE.I (and one slot
# later), so it is already in the pipeline when the store lands: it only
# executes the NEW code if FENCE.I really flushes and re-fetches.
# -----------------------------------------------------------------------------
#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32U
RVTEST_CODE_BEGIN

  # test 2: patched instruction immediately after fence.i
  li    TESTNUM, 2
  li    a3, 0
  la    t0, 1f
  lw    t1, new_insn
  sw    t1, 0(t0)           # store is in MEM while fence.i is in EX
  fence.i
1:addi  a3, a3, 1           # overwritten with "addi a3, a3, 7"
  li    t2, 7
  bne   a3, t2, fail

  # test 3: patched instruction two slots after fence.i
  li    TESTNUM, 3
  li    a3, 0
  la    t0, 2f
  lw    t1, new_insn
  sw    t1, 0(t0)
  fence.i
  nop
2:addi  a3, a3, 1           # overwritten with "addi a3, a3, 7"
  li    t2, 7
  bne   a3, t2, fail

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

new_insn:
  addi  a3, a3, 7

RVTEST_DATA_END
