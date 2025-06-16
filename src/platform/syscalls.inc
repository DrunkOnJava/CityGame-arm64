;------------------------------------------------------------------------------
; syscalls.inc - macOS ARM64 system call definitions
;------------------------------------------------------------------------------

; System call numbers for macOS on ARM64
.equ    SYS_exit,           0x2000001
.equ    SYS_fork,           0x2000002
.equ    SYS_read,           0x2000003
.equ    SYS_write,          0x2000004
.equ    SYS_open,           0x2000005
.equ    SYS_close,          0x2000006
.equ    SYS_mmap,           0x200000C5
.equ    SYS_munmap,         0x2000049
.equ    SYS_mprotect,       0x200004A
.equ    SYS_pthread_create, 0x2000168
.equ    SYS_pthread_join,   0x200016A
.equ    SYS_pthread_self,   0x2000173
.equ    SYS_sched_yield,    0x200003C

; File flags
.equ    O_RDONLY,   0x0000
.equ    O_WRONLY,   0x0001
.equ    O_RDWR,     0x0002
.equ    O_CREAT,    0x0200
.equ    O_TRUNC,    0x0400

; Memory protection flags
.equ    PROT_NONE,  0x00
.equ    PROT_READ,  0x01
.equ    PROT_WRITE, 0x02
.equ    PROT_EXEC,  0x04

; Memory mapping flags
.equ    MAP_SHARED,     0x01
.equ    MAP_PRIVATE,    0x02
.equ    MAP_ANONYMOUS,  0x1000

; Standard file descriptors
.equ    STDIN,  0
.equ    STDOUT, 1
.equ    STDERR, 2