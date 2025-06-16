.global _main
.align 4

.text

_main:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    adrp x0, hello_msg@PAGE
    add x0, x0, hello_msg@PAGEOFF
    bl _printf
    
    mov x0, #0
    ldp x29, x30, [sp], #16
    ret

.data
hello_msg:
    .asciz "Hello from SimCity ARM64!\n"