.global threads_init
.global get_thread_count
.align 4
threads_init:
    mov x0, #0
    ret
get_thread_count:
    mov x0, #8
    ret
