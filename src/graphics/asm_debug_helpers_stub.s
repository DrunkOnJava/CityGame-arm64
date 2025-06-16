;------------------------------------------------------------------------------
; asm_debug_helpers_stub.s - Stub implementation
;------------------------------------------------------------------------------

.section __TEXT,__text,regular,pure_instructions
.align 2

.globl _debug_checkpoint
_debug_checkpoint:
    ret

.globl _debug_assert
_debug_assert:
    ret

.globl _debug_trace_enter
_debug_trace_enter:
    ret

.globl _debug_trace_exit
_debug_trace_exit:
    ret

.globl _debug_dump_registers
_debug_dump_registers:
    ret

.globl _debug_dump_neon
_debug_dump_neon:
    ret

.globl _debug_dump_camera_state
_debug_dump_camera_state:
    ret

.globl _debug_memory_dump
_debug_memory_dump:
    ret

.globl _debug_validate_pointer
_debug_validate_pointer:
    mov     x0, #1
    ret

.globl _debug_conditional_break
_debug_conditional_break:
    ret