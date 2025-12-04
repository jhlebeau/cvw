.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
    li a0, 42
    li a1, 43
    li a2, 44
    addi a2, a2, -32
self_loop:
    j self_loop
