;------------------------------------------------------------------------------
; camera_performance_profiler.s - Hardware performance monitoring
;------------------------------------------------------------------------------

.include "../include/debug_constants.inc"

; Performance counter events
.equ PMC_CYCLES,          0x02    ; CPU cycles
.equ PMC_INSTRUCTIONS,    0x1B    ; Instructions retired
.equ PMC_L1D_CACHE_MISS,  0x03    ; L1 data cache misses
.equ PMC_BRANCHES,        0x0C    ; Branch instructions

; Profiler constants
.equ MAX_SAMPLES,         1024
.equ SAMPLE_SIZE,         32

.section __DATA,__data
.align 6

; Performance samples ring buffer
.globl _perf_samples
_perf_samples:
    .space MAX_SAMPLES * SAMPLE_SIZE

; Profiler state
.globl _profiler_state
_profiler_state:
    .quad   0               ; Current sample index
    .quad   0               ; Total samples collected
    .quad   0               ; Start time
    .quad   0               ; Last report time
    .word   0               ; Enabled flag
    .word   0               ; _padding

; Per-function timing
.globl _function_timings
_function_timings:
    .quad   0               ; camera_update total
    .quad   0               ; process_keyboard_input
    .quad   0               ; process_mouse_input
    .quad   0               ; process_scroll_input
    .quad   0               ; update_physics
    .quad   0               ; update_view_matrix
    .quad   0               ; Count for each

.section __TEXT,__text,regular,pure_instructions
.align 2

;------------------------------------------------------------------------------
; Initialize performance profiler
;------------------------------------------------------------------------------
.globl _camera_profiler_init
_camera_profiler_init:
    stp     x29, x30, [sp, #-16]!
    
    ; Clear profiler state
    adrp    x0, _profiler_state@PAGE
    add     x0, x0, _profiler_state@PAGEOFF
    
    ; Zero the state
    stp     xzr, xzr, [x0, #0]
    stp     xzr, xzr, [x0, #16]
    
    ; Clear samples buffer
    adrp    x1, _perf_samples@PAGE
    add     x1, x1, _perf_samples@PAGEOFF
    mov     x2, #(MAX_SAMPLES * SAMPLE_SIZE)
1:
    stp     xzr, xzr, [x1], #16
    subs    x2, x2, #16
    b.ne    1b
    
    ; Clear function timings
    adrp    x0, _function_timings@PAGE
    add     x0, x0, _function_timings@PAGEOFF
    mov     x2, #14             ; 7 entries * 8 bytes each / 8
2:
    str     xzr, [x0], #8
    subs    x2, x2, #1
    b.ne    2b
    
    ldp     x29, x30, [sp], #16
    ret

;------------------------------------------------------------------------------
; Start profiling
;------------------------------------------------------------------------------
.globl _camera_profiler_start
_camera_profiler_start:
    adrp    x0, _profiler_state@PAGE
    add     x0, x0, _profiler_state@PAGEOFF
    
    ; Set enabled flag
    mov     w1, #1
    str     w1, [x0, #32]
    
    ; Record start time
    mrs     x1, CNTVCT_EL0
    str     x1, [x0, #16]
    
    ret

;------------------------------------------------------------------------------
; Stop profiling
;------------------------------------------------------------------------------
.globl _camera_profiler_stop
_camera_profiler_stop:
    adrp    x0, _profiler_state@PAGE
    add     x0, x0, _profiler_state@PAGEOFF
    
    ; Clear enabled flag
    str     wzr, [x0, #32]
    
    ret

;------------------------------------------------------------------------------
; Mark frame boundary and collect sample
;------------------------------------------------------------------------------
.globl _camera_profiler_mark_frame
_camera_profiler_mark_frame:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    
    ; Check if enabled
    adrp    x19, _profiler_state@PAGE
    add     x19, x19, _profiler_state@PAGEOFF
    ldr     w0, [x19, #32]
    cbz     w0, prof_disabled
    
    ; Get current time
    mrs     x20, CNTVCT_EL0
    
    ; Calculate sample buffer position
    ldr     x0, [x19, #0]       ; Current index
    adrp    x1, _perf_samples@PAGE
    add     x1, x1, _perf_samples@PAGEOFF
    lsl     x2, x0, #5          ; index * 32
    add     x1, x1, x2
    
    ; Store timestamp
    str     x20, [x1, #0]
    
    ; Read performance counters (if available)
    ; Note: Requires kernel support on macOS
    ; For now, we'll use time-based metrics
    
    ; Store frame time delta
    ldr     x2, [x19, #24]      ; Last report time
    sub     x3, x20, x2
    str     x3, [x1, #8]
    str     x20, [x19, #24]     ; Update last time
    
    ; Update index (ring buffer)
    add     x0, x0, #1
    and     x0, x0, #(MAX_SAMPLES - 1)
    str     x0, [x19, #0]
    
    ; Increment total samples
    ldr     x0, [x19, #8]
    add     x0, x0, #1
    str     x0, [x19, #8]
    
prof_disabled:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

;------------------------------------------------------------------------------
; Function timing macros
;------------------------------------------------------------------------------
.macro PROF_FUNC_START func_id
    .ifdef PERF_MONITORING
    mrs     x28, CNTVCT_EL0
    .endif
.endm

.macro PROF_FUNC_END func_id
    .ifdef PERF_MONITORING
    mrs     x27, CNTVCT_EL0
    sub     x27, x27, x28       ; Duration
    
    adrp    x26, _function_timings@PAGE
    add     x26, x26, _function_timings@PAGEOFF
    
    ; Add to total time
    ldr     x25, [x26, #(\func_id * 8)]
    add     x25, x25, x27
    str     x25, [x26, #(\func_id * 8)]
    
    ; Increment count
    ldr     x25, [x26, #(48 + \func_id * 8)]
    add     x25, x25, #1
    str     x25, [x26, #(48 + \func_id * 8)]
    .endif
.endm

;------------------------------------------------------------------------------
; Generate performance report
;------------------------------------------------------------------------------
.globl _camera_profiler_report
_camera_profiler_report:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    adrp    x19, _profiler_state@PAGE
    add     x19, x19, _profiler_state@PAGEOFF
    
    ; Get total samples
    ldr     x20, [x19, #8]
    cbz     x20, no_samples
    
    ; Calculate statistics
    adrp    x21, _perf_samples@PAGE
    add     x21, x21, _perf_samples@PAGEOFF
    
    mov     x0, #0              ; Min time (start with max)
    mvn     x0, x0
    mov     x1, #0              ; Max time
    mov     x2, #0              ; Total time
    
    ; Scan samples
    mov     x3, #0              ; Index
scan_loop:
    cmp     x3, x20
    b.ge    scan_done
    cmp     x3, #MAX_SAMPLES
    b.ge    scan_done
    
    lsl     x4, x3, #5          ; index * 32
    ldr     x5, [x21, x4]       ; Frame time
    add     x5, x21, x4
    ldr     x5, [x5, #8]        ; Delta time
    
    ; Update min
    cmp     x5, x0
    b.hs    1f
    mov     x0, x5
1:
    ; Update max
    cmp     x5, x1
    b.ls    2f
    mov     x1, x5
2:
    ; Update total
    add     x2, x2, x5
    
    add     x3, x3, #1
    b       scan_loop
    
scan_done:
    ; Calculate average
    udiv    x3, x2, x20         ; Average
    
    ; Print report (would normally output to buffer)
    ; For now, store in profiler state
    str     x0, [x19, #40]      ; Min
    str     x1, [x19, #48]      ; Max
    str     x3, [x19, #56]      ; Avg
    
no_samples:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

;------------------------------------------------------------------------------
; Get function timing
;------------------------------------------------------------------------------
.globl _camera_profiler_get_function_time
_camera_profiler_get_function_time:
    ; X0 = function ID
    cmp     x0, #7
    b.hs    invalid_func
    
    adrp    x1, _function_timings@PAGE
    add     x1, x1, _function_timings@PAGEOFF
    
    lsl     x2, x0, #3
    ldr     x0, [x1, x2]        ; Total time
    ldr     x1, [x1, x2]        ; Count
    add     x1, x1, #48
    
    ret
    
invalid_func:
    mov     x0, #0
    mov     x1, #0
    ret