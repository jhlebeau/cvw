.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
    li a0, 42
    li a1, 43
    mul a2, a0, a1
    div a3, a2, a0
self_loop:
    j self_loop
