/* Linker script for C programs: 64 KB RAM, stack grows down from the top */
OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
  . = 0x00000000;
  .text.init : { *(.text.init) }
  .text      : { *(.text) *(.text.*) }
  .rodata    : { *(.rodata) *(.rodata.*) *(.srodata) *(.srodata.*) }

  . = ALIGN(16);
  .data      : { *(.data) *(.data.*) }
  .sdata     : {
    __global_pointer$ = . + 0x800;
    *(.sdata) *(.sdata.*)
  }

  . = ALIGN(4);
  _bss_start = .;
  .sbss      : { *(.sbss) *(.sbss.*) }
  .bss       : { *(.bss) *(.bss.*) *(COMMON) }
  . = ALIGN(4);
  _bss_end = .;

  _stack_top = 0x00010000;
}
