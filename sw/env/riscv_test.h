// -----------------------------------------------------------------------------
// riscv_test.h - minimal bare-metal test environment for the official
// riscv-tests (https://github.com/riscv-software-src/riscv-tests).
//
// Replaces the upstream "p" environment, which needs CSRs and machine mode.
// Pass/fail is reported by writing to the TOHOST address that the testbench
// watches:  1 = pass,  (test_number << 1) | 1 = fail.
// -----------------------------------------------------------------------------
#ifndef _RV32I_PIPELINE_TEST_H
#define _RV32I_PIPELINE_TEST_H

#define TOHOST_ADDR 0x00010000

#define RVTEST_RV64U .macro init; .endm
#define RVTEST_RV32U .macro init; .endm

#define TESTNUM gp

#define RVTEST_CODE_BEGIN       \
        .section .text.init;    \
        .align  6;              \
        .globl _start;          \
_start:                         \
        init;

#define RVTEST_CODE_END         \
        unimp

#define RVTEST_PASS             \
        fence;                  \
        li  TESTNUM, 1;         \
        li  t6, TOHOST_ADDR;    \
        sw  TESTNUM, 0(t6);     \
1:      j 1b;

#define RVTEST_FAIL             \
        fence;                  \
1:      beqz TESTNUM, 1b;       \
        sll TESTNUM, TESTNUM, 1;\
        or  TESTNUM, TESTNUM, 1;\
        li  t6, TOHOST_ADDR;    \
        sw  TESTNUM, 0(t6);     \
1:      j 1b;

#define EXTRA_DATA

#define RVTEST_DATA_BEGIN       \
        EXTRA_DATA              \
        .align 4;               \
        .global begin_signature;\
begin_signature:

#define RVTEST_DATA_END         \
        .align 4;               \
        .global end_signature;  \
end_signature:

#endif
