;------------------------------------------------------------------------------
; memory_leak_detector.s - Memory allocation tracking for debugging
;------------------------------------------------------------------------------

.include "../include/debug_constants.inc"

; Constants
.equ MAX_ALLOCATIONS,     4096
.equ ALLOCATION_ENTRY_SIZE, 32

.section __DATA,__data
.align 6

; Allocation tracking table
.globl _allocation_table
_allocation_table:
    .space MAX_ALLOCATIONS * ALLOCATION_ENTRY_SIZE

; Leak detector state
.globl _leak_detector_state
_leak_detector_state:
    .quad   0               ; Total allocations
    .quad   0               ; Total deallocations
    .quad   0               ; Current bytes allocated
    .quad   0               ; Peak bytes allocated
    .quad   0               ; Allocation failures
    .quad   0               ; Double free attempts
    .word   0               ; Enabled flag
    .word   0               ; _padding

; Allocation categories
.globl _allocation_stats
_allocation_stats:
    .quad   0               ; Small allocations (<64 bytes)
    .quad   0               ; Medium allocations (64-1024 bytes)
    .quad   0               ; Large allocations (>1024 bytes)
    .quad   0               ; Camera-specific allocations

.section __TEXT,__text,regular,pure_instructions
.align 2

;------------------------------------------------------------------------------
; Initialize leak detector
;------------------------------------------------------------------------------
.globl _leak_detector_init
_leak_detector_init:
    stp     x29, x30, [sp, #-16]!
    
    ; Clear detector state
    adrp    x0, _leak_detector_state@PAGE
    add     x0, x0, _leak_detector_state@PAGEOFF
    mov     x1, #7              ; 7 * 8 = 56 bytes
1:
    str     xzr, [x0], #8
    subs    x1, x1, #1
    b.ne    1b
    
    ; Clear allocation table
    adrp    x0, _allocation_table@PAGE
    add     x0, x0, _allocation_table@PAGEOFF
    mov     x1, #(MAX_ALLOCATIONS * ALLOCATION_ENTRY_SIZE / 16)
2:
    stp     xzr, xzr, [x0], #16
    subs    x1, x1, #1
    b.ne    2b
    
    ; Clear stats
    adrp    x0, _allocation_stats@PAGE
    add     x0, x0, _allocation_stats@PAGEOFF
    stp     xzr, xzr, [x0, #0]
    stp     xzr, xzr, [x0, #16]
    
    ; Enable detector
    adrp    x0, _leak_detector_state@PAGE
    add     x0, x0, _leak_detector_state@PAGEOFF
    mov     w1, #1
    str     w1, [x0, #48]
    
    ldp     x29, x30, [sp], #16
    ret

;------------------------------------------------------------------------------
; Track allocation
;------------------------------------------------------------------------------
.globl _leak_detector_track_alloc
_leak_detector_track_alloc:
    ; X0 = pointer, X1 = size, X2 = caller address
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    ; Check if enabled
    adrp    x19, _leak_detector_state@PAGE
    add     x19, x19, _leak_detector_state@PAGEOFF
    ldr     w3, [x19, #48]
    cbz     w3, track_disabled
    
    mov     x20, x0             ; Save pointer
    mov     x21, x1             ; Save size
    mov     x22, x2             ; Save caller
    
    ; Find free slot in allocation table
    adrp    x3, _allocation_table@PAGE
    add     x3, x3, _allocation_table@PAGEOFF
    mov     x4, #0              ; Index
    
find_slot:
    cmp     x4, #MAX_ALLOCATIONS
    b.ge    table_full
    
    lsl     x5, x4, #5          ; index * 32
    add     x6, x3, x5
    ldr     x7, [x6, #0]        ; Check if slot is free
    cbz     x7, found_slot
    
    add     x4, x4, #1
    b       find_slot
    
found_slot:
    ; Store allocation info
    str     x20, [x6, #0]       ; Pointer
    str     x21, [x6, #8]       ; Size
    str     x22, [x6, #16]      ; Caller
    mrs     x7, CNTVCT_EL0
    str     x7, [x6, #24]       ; Timestamp
    
    ; Update statistics
    ldr     x0, [x19, #0]       ; Total allocations
    add     x0, x0, #1
    str     x0, [x19, #0]
    
    ldr     x0, [x19, #16]      ; Current bytes
    add     x0, x0, x21
    str     x0, [x19, #16]
    
    ldr     x1, [x19, #24]      ; Peak bytes
    cmp     x0, x1
    b.ls    1f
    str     x0, [x19, #24]      ; Update peak
1:
    
    ; Categorize allocation
    adrp    x0, _allocation_stats@PAGE
    add     x0, x0, _allocation_stats@PAGEOFF
    
    cmp     x21, #64
    b.hs    2f
    ldr     x1, [x0, #0]        ; Small
    add     x1, x1, #1
    str     x1, [x0, #0]
    b       track_done
2:
    cmp     x21, #1024
    b.hs    3f
    ldr     x1, [x0, #8]        ; Medium
    add     x1, x1, #1
    str     x1, [x0, #8]
    b       track_done
3:
    ldr     x1, [x0, #16]       ; Large
    add     x1, x1, #1
    str     x1, [x0, #16]
    
track_done:
track_disabled:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret
    
table_full:
    ; Increment failure count
    ldr     x0, [x19, #32]
    add     x0, x0, #1
    str     x0, [x19, #32]
    b       track_disabled

;------------------------------------------------------------------------------
; Track deallocation
;------------------------------------------------------------------------------
.globl _leak_detector_track_free
_leak_detector_track_free:
    ; X0 = pointer
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    
    ; Check if enabled
    adrp    x19, _leak_detector_state@PAGE
    add     x19, x19, _leak_detector_state@PAGEOFF
    ldr     w1, [x19, #48]
    cbz     w1, free_disabled
    
    mov     x20, x0             ; Save pointer
    
    ; Find allocation in table
    adrp    x1, _allocation_table@PAGE
    add     x1, x1, _allocation_table@PAGEOFF
    mov     x2, #0              ; Index
    
find_alloc:
    cmp     x2, #MAX_ALLOCATIONS
    b.ge    not_found
    
    lsl     x3, x2, #5          ; index * 32
    add     x4, x1, x3
    ldr     x5, [x4, #0]        ; Pointer
    cmp     x5, x20
    b.eq    found_alloc
    
    add     x2, x2, #1
    b       find_alloc
    
found_alloc:
    ; Get size before clearing
    ldr     x5, [x4, #8]        ; Size
    
    ; Clear entry
    stp     xzr, xzr, [x4, #0]
    stp     xzr, xzr, [x4, #16]
    
    ; Update statistics
    ldr     x0, [x19, #8]       ; Total deallocations
    add     x0, x0, #1
    str     x0, [x19, #8]
    
    ldr     x0, [x19, #16]      ; Current bytes
    sub     x0, x0, x5
    str     x0, [x19, #16]
    
    b       free_done
    
not_found:
    ; Possible double free
    ldr     x0, [x19, #40]      ; Double free attempts
    add     x0, x0, #1
    str     x0, [x19, #40]
    
free_done:
free_disabled:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

;------------------------------------------------------------------------------
; Check for leaks
;------------------------------------------------------------------------------
.globl _leak_detector_check_leaks
_leak_detector_check_leaks:
    ; Returns number of leaks in X0
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    
    adrp    x19, _allocation_table@PAGE
    add     x19, x19, _allocation_table@PAGEOFF
    
    mov     x0, #0              ; Leak count
    mov     x1, #0              ; Index
    
check_loop:
    cmp     x1, #MAX_ALLOCATIONS
    b.ge    check_done
    
    lsl     x2, x1, #5          ; index * 32
    ldr     x3, [x19, x2]       ; Pointer
    cbz     x3, 1f              ; Skip if empty
    
    add     x0, x0, #1          ; Found leak
    
1:
    add     x1, x1, #1
    b       check_loop
    
check_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

;------------------------------------------------------------------------------
; Generate leak report
;------------------------------------------------------------------------------
.globl _leak_detector_report
_leak_detector_report:
    ; X0 = output buffer
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x22, x0             ; Save output buffer
    
    ; Get state
    adrp    x19, _leak_detector_state@PAGE
    add     x19, x19, _leak_detector_state@PAGEOFF
    
    ; Store summary in buffer
    ldp     x0, x1, [x19, #0]   ; Total allocs/deallocs
    stp     x0, x1, [x22, #0]
    ldp     x0, x1, [x19, #16]  ; Current/peak bytes
    stp     x0, x1, [x22, #16]
    ldp     x0, x1, [x19, #32]  ; Failures/double frees
    stp     x0, x1, [x22, #32]
    
    ; Count leaks and store details
    bl      _leak_detector_check_leaks
    str     x0, [x22, #48]      ; Leak count
    
    ; Get allocation stats
    adrp    x20, _allocation_stats@PAGE
    add     x20, x20, _allocation_stats@PAGEOFF
    ldp     x0, x1, [x20, #0]   ; Small/medium
    stp     x0, x1, [x22, #56]
    ldp     x0, x1, [x20, #16]  ; Large/camera
    stp     x0, x1, [x22, #72]
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

;------------------------------------------------------------------------------
; Track camera-specific allocation
;------------------------------------------------------------------------------
.globl _leak_detector_track_camera_alloc
_leak_detector_track_camera_alloc:
    ; X0 = pointer, X1 = size
    stp     x29, x30, [sp, #-16]!
    
    ; Track as normal allocation
    mov     x2, x30             ; Use our return address as caller
    bl      _leak_detector_track_alloc
    
    ; Increment camera-specific counter
    adrp    x0, _allocation_stats@PAGE
    add     x0, x0, _allocation_stats@PAGEOFF
    ldr     x1, [x0, #24]       ; Camera allocations
    add     x1, x1, #1
    str     x1, [x0, #24]
    
    ldp     x29, x30, [sp], #16
    ret