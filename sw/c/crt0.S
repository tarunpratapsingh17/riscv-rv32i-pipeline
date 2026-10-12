# -----------------------------------------------------------------------------
# crt0.S - start-up code for bare-metal C programs on rv32i_core
#   sets up gp and sp, clears .bss, calls main(), reports the result:
#   main() == 0  -> write 1 to TOHOST (PASS)
#   main() == n  -> write (n<<1)|1   (FAIL, code n)
# -----------------------------------------------------------------------------
    .section .text.init
    .globl _start
_start:
    .option push
    .option norelax
    la      gp, __global_pointer$
    .option pop
    la      sp, _stack_top

    la      t0, _bss_start
    la      t1, _bss_end
1:  bgeu    t0, t1, 2f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       1b
2:
    call    main

    li      t0, 0x00010000          # TOHOST
    bnez    a0, 3f
    li      t1, 1
    sw      t1, 0(t0)
    j       4f
3:  slli    t1, a0, 1
    ori     t1, t1, 1
    sw      t1, 0(t0)
4:  j       4b
