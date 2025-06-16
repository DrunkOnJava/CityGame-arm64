.global syscalls_init
.global usleep
.align 4
syscalls_init:
    mov x0, #0
    ret
usleep:
    mov x16, #0x5D
    svc #0x80
    ret
