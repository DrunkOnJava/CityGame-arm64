;------------------------------------------------------------------------------
; asm_debug_helpers.s - Low-level debugging utilities
;------------------------------------------------------------------------------

.include "../include/debug_constants.inc"

.section __DATA,__data
.align 4

; Debug strings
debug_checkpoint_msg:
    .asciz "CHECKPOINT %d reached\n"
debug_assert_msg:
    .asciz "ASSERTION FAILED: %s\n"
debug_trace_enter_msg:
    .asciz "ENTER: %s\n"
debug_trace_exit_msg:
    .asciz "EXIT: %s (ret=%ld)\n"
register_dump_header:
    .asciz "\n=== REGISTER DUMP ===\n"
neon_dump_header:
    .asciz "\n=== NEON REGISTER DUMP ===\n"
camera_state_header:
    .asciz "\n=== CAMERA STATE ===\n"

.section __TEXT,__text,regular,pure_instructions
.align 2

;------------------------------------------------------------------------------
; Debug checkpoint
;------------------------------------------------------------------------------
.globl _debug_checkpoint
_debug_checkpoint:
    ; X0 = checkpoint ID
    stp     x29, x30, [sp, #-16]!
    
    .ifdef DEBUG_BUILD
    mov     x1, x0
    adrp    x0, debug_checkpoint_msg@PAGE
    add     x0, x0, debug_checkpoint_msg@PAGEOFF
    bl      _printf
    .endif
    
    ldp     x29, x30, [sp], #16
    ret

;------------------------------------------------------------------------------
; Debug assertion
;------------------------------------------------------------------------------
.globl _debug_assert
_debug_assert:
    ; X0 = condition (0 = failed), X1 = message
    stp     x29, x30, [sp, #-16]!
    
    .ifdef DEBUG_BUILD
    cbnz    x0, assert_passed
    
    ; Assertion failed
    mov     x2, x1
    adrp    x0, debug_assert_msg@PAGE
    add     x0, x0, debug_assert_msg@PAGEOFF
    mov     x1, x2
    bl      _printf
    
    ; Breakpoint
    brk     #0x1
    
assert_passed:
    .endif
    
    ldp     x29, x30, [sp], #16
    ret

;------------------------------------------------------------------------------
; Function trace enter
;------------------------------------------------------------------------------
.globl _debug_trace_enter
_debug_trace_enter:
    ; X0 = function name
    stp     x29, x30, [sp, #-16]!
    
    .ifdef DEBUG_BUILD
    mov     x1, x0
    adrp    x0, debug_trace_enter_msg@PAGE
    add     x0, x0, debug_trace_enter_msg@PAGEOFF
    bl      _printf
    .endif
    
    ldp     x29, x30, [sp], #16
    ret

;------------------------------------------------------------------------------
; Function trace exit
;------------------------------------------------------------------------------
.globl _debug_trace_exit
_debug_trace_exit:
    ; X0 = function name, X1 = return value
    stp     x29, x30, [sp, #-16]!
    
    .ifdef DEBUG_BUILD
    mov     x2, x1
    mov     x1, x0
    adrp    x0, debug_trace_exit_msg@PAGE
    add     x0, x0, debug_trace_exit_msg@PAGEOFF
    bl      _printf
    .endif
    
    ldp     x29, x30, [sp], #16
    ret

;------------------------------------------------------------------------------
; Dump general purpose registers
;------------------------------------------------------------------------------
.globl _debug_dump_registers
_debug_dump_registers:
    stp     x29, x30, [sp, #-144]!
    
    ; Save all registers
    stp     x0, x1, [sp, #16]
    stp     x2, x3, [sp, #32]
    stp     x4, x5, [sp, #48]
    stp     x6, x7, [sp, #64]
    stp     x8, x9, [sp, #80]
    stp     x10, x11, [sp, #96]
    stp     x12, x13, [sp, #112]
    stp     x14, x15, [sp, #128]
    
    .ifdef DEBUG_BUILD
    ; Print header
    adrp    x0, register_dump_header@PAGE
    add     x0, x0, register_dump_header@PAGEOFF
    bl      _printf
    
    ; Print each register pair
    mov     x19, #0             ; Register counter
    add     x20, sp, #16        ; Register save area
    
dump_reg_loop:
    cmp     x19, #16
    b.ge    dump_reg_done
    
    ; Load register pair
    ldp     x1, x2, [x20], #16
    
    ; Print format: "X%d: 0x%016lx  X%d: 0x%016lx\n"
    mov     x0, x19
    add     x3, x19, #1
    bl      print_reg_pair
    
    add     x19, x19, #2
    b       dump_reg_loop
    
dump_reg_done:
    .endif
    
    ; Restore registers
    ldp     x0, x1, [sp, #16]
    ldp     x2, x3, [sp, #32]
    ldp     x4, x5, [sp, #48]
    ldp     x6, x7, [sp, #64]
    ldp     x8, x9, [sp, #80]
    ldp     x10, x11, [sp, #96]
    ldp     x12, x13, [sp, #112]
    ldp     x14, x15, [sp, #128]
    
    ldp     x29, x30, [sp], #144
    ret

;------------------------------------------------------------------------------
; Dump NEON registers
;------------------------------------------------------------------------------
.globl _debug_dump_neon
_debug_dump_neon:
    stp     x29, x30, [sp, #-512]!
    
    ; Save NEON registers
    stp     q0, q1, [sp, #16]
    stp     q2, q3, [sp, #48]
    stp     q4, q5, [sp, #80]
    stp     q6, q7, [sp, #112]
    stp     q8, q9, [sp, #144]
    stp     q10, q11, [sp, #176]
    stp     q12, q13, [sp, #208]
    stp     q14, q15, [sp, #240]
    stp     q16, q17, [sp, #272]
    stp     q18, q19, [sp, #304]
    stp     q20, q21, [sp, #336]
    stp     q22, q23, [sp, #368]
    stp     q24, q25, [sp, #400]
    stp     q26, q27, [sp, #432]
    stp     q28, q29, [sp, #464]
    stp     q30, q31, [sp, #496]
    
    .ifdef DEBUG_BUILD
    ; Print header
    adrp    x0, neon_dump_header@PAGE
    add     x0, x0, neon_dump_header@PAGEOFF
    bl      _printf
    
    ; Print each vector register
    mov     x19, #0             ; Register counter
    add     x20, sp, #16        ; Register save area
    
dump_neon_loop:
    cmp     x19, #32
    b.ge    dump_neon_done
    
    ; Print V register contents
    mov     x0, x19
    mov     x1, x20
    bl      print_vector_reg
    
    add     x19, x19, #1
    add     x20, x20, #16
    b       dump_neon_loop
    
dump_neon_done:
    .endif
    
    ; Restore NEON registers
    ldp     q0, q1, [sp, #16]
    ldp     q2, q3, [sp, #48]
    ldp     q4, q5, [sp, #80]
    ldp     q6, q7, [sp, #112]
    ldp     q8, q9, [sp, #144]
    ldp     q10, q11, [sp, #176]
    ldp     q12, q13, [sp, #208]
    ldp     q14, q15, [sp, #240]
    ldp     q16, q17, [sp, #272]
    ldp     q18, q19, [sp, #304]
    ldp     q20, q21, [sp, #336]
    ldp     q22, q23, [sp, #368]
    ldp     q24, q25, [sp, #400]
    ldp     q26, q27, [sp, #432]
    ldp     q28, q29, [sp, #464]
    ldp     q30, q31, [sp, #496]
    
    ldp     x29, x30, [sp], #512
    ret

;------------------------------------------------------------------------------
; Dump camera state
;------------------------------------------------------------------------------
.globl _debug_dump_camera_state
_debug_dump_camera_state:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    
    .ifdef DEBUG_BUILD
    ; Print header
    adrp    x0, camera_state_header@PAGE
    add     x0, x0, camera_state_header@PAGEOFF
    bl      _printf
    
    ; Load camera state
    adrp    x19, _camera_state@PAGE
    add     x19, x19, _camera_state@PAGEOFF
    
    ; Print position
    ldp     s0, s1, [x19, #8]       ; world_x, world_z
    ldr     s2, [x19, #16]          ; height
    bl      print_position
    
    ; Print velocity
    ldp     s0, s1, [x19, #24]      ; vel_x, vel_z
    bl      print_velocity
    
    ; Print edge pan
    ldp     s0, s1, [x19, #40]      ; edge_pan_x, edge_pan_z
    bl      print_edge_pan
    
    ; Print zoom and rotation
    ldr     s0, [x19, #32]          ; zoom_vel
    ldr     s1, [x19, #36]          ; rot_vel
    bl      print_zoom_rotation
    
    ; Print bounce timer
    ldr     w0, [x19, #48]
    bl      print_bounce_timer
    .endif
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

;------------------------------------------------------------------------------
; Memory dump
;------------------------------------------------------------------------------
.globl _debug_memory_dump
_debug_memory_dump:
    ; X0 = address, X1 = size
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    
    .ifdef DEBUG_BUILD
    mov     x19, x0             ; Save address
    mov     x20, x1             ; Save size
    
    ; Print header
    mov     x1, x0
    mov     x2, x20
    bl      print_memory_header
    
    ; Dump memory in 16-byte chunks
    mov     x21, #0             ; Offset
    
mem_dump_loop:
    cmp     x21, x20
    b.ge    mem_dump_done
    
    ; Calculate remaining bytes
    sub     x22, x20, x21
    mov     x23, #16
    cmp     x22, x23
    csel    x22, x22, x23, lt
    
    ; Print line
    add     x0, x19, x21        ; Current address
    mov     x1, x21             ; Offset
    mov     x2, x22             ; Bytes to print
    bl      print_memory_line
    
    add     x21, x21, #16
    b       mem_dump_loop
    
mem_dump_done:
    .endif
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

;------------------------------------------------------------------------------
; Validate pointer
;------------------------------------------------------------------------------
.globl _debug_validate_pointer
_debug_validate_pointer:
    ; X0 = pointer, X1 = expected alignment
    ; Returns 1 if valid, 0 if invalid
    
    ; Check for NULL
    cbz     x0, invalid_ptr
    
    ; Check alignment
    sub     x2, x1, #1          ; alignment - 1
    tst     x0, x2
    b.ne    invalid_ptr
    
    ; Check for kernel space (high bit set)
    tst     x0, #(1 << 63)
    b.ne    invalid_ptr
    
    ; Valid pointer
    mov     x0, #1
    ret
    
invalid_ptr:
    mov     x0, #0
    ret

;------------------------------------------------------------------------------
; Helper functions (would normally call printf with proper format strings)
;------------------------------------------------------------------------------
print_reg_pair:
    ; Simplified - would format and print register pair
    ret

print_vector_reg:
    ; Simplified - would format and print vector register
    ret

print_position:
    ; Simplified - would format and print position
    ret

print_velocity:
    ; Simplified - would format and print velocity
    ret

print_edge_pan:
    ; Simplified - would format and print edge pan
    ret

print_zoom_rotation:
    ; Simplified - would format and print zoom/rotation
    ret

print_bounce_timer:
    ; Simplified - would format and print bounce timer
    ret

print_memory_header:
    ; Simplified - would print memory dump header
    ret

print_memory_line:
    ; Simplified - would print memory line
    ret

;------------------------------------------------------------------------------
; Conditional breakpoint
;------------------------------------------------------------------------------
.globl _debug_conditional_break
_debug_conditional_break:
    ; X0 = condition
    cbz     x0, no_break
    brk     #0x2
no_break:
    ret