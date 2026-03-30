OUTPUT_FORMAT("elf32-littleriscv", "elf32-littleriscv", "elf32-littleriscv")
OUTPUT_ARCH(riscv)
ENTRY(_start)

BOOTROM_BASE = 0x00001000;
BOOTROM_LIMIT = 0x00003000;
DTIM_BASE = 0x00003000;

SECTIONS
{
  /* Starting at 0x1000 to match bootROM location */
  . = BOOTROM_BASE;

  .text :
  {
    *(.text.unlikely .text.*_unlikely .text.unlikely.*)
    *(.init)    /* Ensure init code is here */
    *(.text .text.* .gnu.linkonce.t.*)
    *(.fini)
  }

  __bootrom_end = .;
  ASSERT(__bootrom_end <= BOOTROM_LIMIT,
         "BootROM overflow: .text exceeds 0x2fff; image no longer fits before DTIM at 0x3000")

  /* Data segment — must be in DTIM (0x3000+), not IROM.
   * The IROM is instruction-fetch-only hardware; data loads to 0x1000-0x2FFF
   * stall the AHB bus permanently because uncore.sv has no HREADY response for HSELIROM. */
  . = DTIM_BASE;
  _data_start = .;
  .rodata :
  {
    *(.rodata .rodata.* .gnu.linkonce.r.*)
    *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4) *(.srodata.cst2) *(.srodata .srodata.*)
  }
  .data :
  {
    *(.data .data.* .gnu.linkonce.d.*)
    CONSTRUCTORS
  }

  /* Small data section and Global Pointer */
  .sdata :
  {
    __SDATA_BEGIN__ = .;
    PROVIDE(__global_pointer$ = . + 0x800);
    *(.sdata .sdata.* .gnu.linkonce.s.*)
  }
  _edata = .;
  PROVIDE(edata = .);

  /* Thread Local Storage */
  .tdata :
  {
    _tdata_begin = .;
    *(.tdata .tdata.* .gnu.linkonce.td.*)
    _tdata_end = .;
  }
  .tbss :
  {
    *(.tbss .tbss.* .gnu.linkonce.tb.*)
    *(.tcommon)
    _tbss_end = .;
  }

  /* BSS (Zero-initialized data) */
  . = ALIGN(0x10);
  __bss_start = .;
  .sbss :
  {
    *(.dynsbss)
    *(.sbss .sbss.* .gnu.linkonce.sb.*)
    *(.scommon)
  }
  .bss :
  {
    *(.dynbss)
    *(.bss .bss.* .gnu.linkonce.b.*)
    *(COMMON)
  }
  _end = .;
  PROVIDE(end = .);

  /* Discard unnecessary sections */
  /DISCARD/ : { *(.note.GNU-stack) *(.gnu_debuglink) *(.gnu.lto_*) *(.interp) }
}
