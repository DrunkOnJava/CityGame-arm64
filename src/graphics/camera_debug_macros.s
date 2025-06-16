;------------------------------------------------------------------------------
; camera_debug_macros.s - Comprehensive debugging infrastructure
; PURPOSE: Runtime diagnostics and error reporting for camera controller
;------------------------------------------------------------------------------

.include "debug_constants.inc"

;── Debug State Structure ─────────────────────────────────────────────────────
.section __DATA,__data
.align 4

.globl _debug_state
_debug_state:
    .quad   0                   ; Error code
    .quad   0                   ; Error context (PC)
    .quad   0                   ; Error data 1
    .quad   0                   ; Error data 2
    .ascii  "                                                                "  ; 64-byte message buffer
    
.globl _debug_counters
_debug_counters:
    .long   0                   ; Frame counter
    .long   0                   ; Input events processed
    .long   0                   ; Physics updates
    .long   0                   ; Collision detections
    .long   0                   ; Edge pan activations
    .long   0                   ; Zoom limit hits
    .long   0                   ; NaN/Inf detections
    .long   0                   ; Performance warnings

;── Debug Macros ──────────────────────────────────────────────────────────────
.macro DEBUG_CHECKPOINT label
    .ifdef DEBUG_BUILD
        adrp    x28, debug_checkpoint_\label@PAGE
        add     x28, x28, debug_checkpoint_\label@PAGEOFF
        str     x28, [x27, #DEBUG_LAST_CHECKPOINT]
    .endif
.endmacro

.macro ASSERT_REGISTER_RANGE reg, min, max, error_code
    .ifdef DEBUG_BUILD
        stp     x29, x30, [sp, #-16]!
        
        ; Check if register value is in valid range
        fmov    s29, \reg
        fmov    s30, \min
        fcmp    s29, s30
        b.ge    1f
        mov     x0, \error_code
        bl      _debug_assert_failed
    1:
        fmov    s30, \max
        fcmp    s29, s30
        b.le    2f
        mov     x0, \error_code | 0x1000
        bl      _debug_assert_failed
    2:
        ldp     x29, x30, [sp], #16
    .endif
.endmacro

.macro VALIDATE_POINTER ptr, alignment, error_code
    .ifdef DEBUG_BUILD
        ; Check for null
        cbz     \ptr, 9f
        
        ; Check alignment
        tst     \ptr, #(\alignment - 1)
        b.eq    8f
        
    9:  ; Invalid pointer
        adrp    x0, debug_msg_invalid_ptr@PAGE
        add     x0, x0, debug_msg_invalid_ptr@PAGEOFF
        mov     x1, \ptr
        mov     x2, \error_code
        bl      _debug_error
    8:
    .endif
.endmacro

.macro CHECK_NEON_VALIDITY vreg, label
    .ifdef DEBUG_BUILD
        stp     x29, x30, [sp, #-16]!
        
        ; Extract all lanes and check for NaN/Inf
        mov     x29, #0
        fcmp    \vreg.s[0], \vreg.s[0]
        csinc   x29, x29, x29, eq       ; Increment if NaN
        fcmp    \vreg.s[1], \vreg.s[1]
        csinc   x29, x29, x29, eq
        fcmp    \vreg.s[2], \vreg.s[2]
        csinc   x29, x29, x29, eq
        fcmp    \vreg.s[3], \vreg.s[3]
        csinc   x29, x29, x29, eq
        
        cbz     x29, 1f
        
        ; NaN detected
        adrp    x0, debug_msg_nan_detected@PAGE
        add     x0, x0, debug_msg_nan_detected@PAGEOFF
        adrp    x1, \label@PAGE
        add     x1, x1, \label@PAGEOFF
        bl      _debug_error
        
    1:
        ldp     x29, x30, [sp], #16
    .endif
.endmacro

.macro PERF_TIMER_START timer_id
    .ifdef PERF_MONITORING
        mrs     x26, CNTPCT_EL0             ; Read cycle counter
        adrp    x27, perf_timers@PAGE
        add     x27, x27, perf_timers@PAGEOFF
        str     x26, [x27, #(\timer_id * 16)]
    .endif
.endmacro

.macro PERF_TIMER_END timer_id
    .ifdef PERF_MONITORING
        mrs     x26, CNTPCT_EL0
        adrp    x27, perf_timers@PAGE
        add     x27, x27, perf_timers@PAGEOFF
        ldr     x25, [x27, #(\timer_id * 16)]
        sub     x26, x26, x25
        ldr     x25, [x27, #(\timer_id * 16 + 8)]
        add     x25, x25, x26
        str     x25, [x27, #(\timer_id * 16 + 8)]
    .endif
.endmacro

;── Error Reporting Functions ─────────────────────────────────────────────────
.section __TEXT,__text
.align 2

.globl _debug_error
_debug_error:
    ; x0 = error message, x1 = error data, x2 = error code
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    ; Store error information
    adrp    x19, _debug_state@PAGE
    add     x19, x19, _debug_state@PAGEOFF
    str     x2, [x19, #0]               ; Error code
    mrs     x20, ELR_EL1                ; Get return address
    str     x20, [x19, #8]              ; Error context
    str     x1, [x19, #16]              ; Error data
    
    ; Copy error message
    mov     x21, #0
1:  ldrb    w22, [x0, x21]
    strb    w22, [x19, #32, x21]
    add     x21, x21, #1
    cmp     x21, #63
    b.lo    1b
    
    ; Call system error handler
    bl      _system_error_handler
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.globl _debug_validate_camera_state
_debug_validate_camera_state:
    ; x0 = camera_state pointer
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0
    
    ; Validate pointer alignment
    VALIDATE_POINTER x19, 128, ERR_CAMERA_STATE_ALIGN
    
    ; Load and validate position
    ld1     {v0.4s}, [x19]
    CHECK_NEON_VALIDITY v0, camera_position_check
    
    ; Validate position bounds
    ASSERT_REGISTER_RANGE v0.s[0], #-10000.0, #10000.0, ERR_POSITION_X_BOUNDS
    ASSERT_REGISTER_RANGE v0.s[1], #-10000.0, #10000.0, ERR_POSITION_Y_BOUNDS
    ASSERT_REGISTER_RANGE v0.s[2], #-10000.0, #10000.0, ERR_POSITION_Z_BOUNDS
    
    ; Load and validate velocity
    ld1     {v1.4s}, [x19, #16]
    CHECK_NEON_VALIDITY v1, camera_velocity_check
    
    ; Check velocity limits
    fmul    v2.4s, v1.4s, v1.4s         ; Square velocities
    faddp   v3.4s, v2.4s, v2.4s         ; Sum squares
    faddp   s4, v3.2s
    fsqrt   s4, s4                      ; Magnitude
    
    fmov    s5, #200.0                  ; Max velocity
    fcmp    s4, s5
    b.le    1f
    
    ; Velocity exceeded
    adrp    x0, debug_msg_velocity_exceeded@PAGE
    add     x0, x0, debug_msg_velocity_exceeded@PAGEOFF
    fmov    w1, s4
    mov     x2, #ERR_VELOCITY_LIMIT
    bl      _debug_error
    
1:
    ; Validate zoom
    ldr     s6, [x19, #48]              ; Height
    ASSERT_REGISTER_RANGE s6, #5.0, #1000.0, ERR_ZOOM_BOUNDS
    
    ; Validate quaternion (must be unit length)
    ld1     {v7.4s}, [x19, #32]         ; Rotation quaternion
    fmul    v8.4s, v7.4s, v7.4s
    faddp   v9.4s, v8.4s, v8.4s
    faddp   s10, v9.2s
    fsqrt   s10, s10
    
    fsub    s11, s10, #1.0
    fabs    s11, s11
    fmov    s12, #0.01                  ; Tolerance
    fcmp    s11, s12
    b.le    2f
    
    ; Quaternion not normalized
    mov     x0, #ERR_QUATERNION_NOT_UNIT
    bl      _debug_assert_failed
    
2:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

;── Debug String Messages ─────────────────────────────────────────────────────
.section __TEXT,__cstring
debug_msg_invalid_ptr:
    .asciz  "Invalid pointer: %p (error: %x)"
debug_msg_nan_detected:
    .asciz  "NaN detected in %s"
debug_msg_velocity_exceeded:
    .asciz  "Velocity limit exceeded: %f"
debug_msg_stack_corruption:
    .asciz  "Stack corruption detected at %p"

;── Performance Monitoring ────────────────────────────────────────────────────
.section __DATA,__data
.align 3
perf_timers:
    .rept   16                  ; 16 timer slots
    .quad   0                   ; Start time
    .quad   0                   ; Accumulated time
    .endr

.section __TEXT,__text
.globl _debug_dump_performance
_debug_dump_performance:
    stp     x29, x30, [sp, #-16]!
    
    ; Calculate and print performance metrics
    adrp    x0, perf_timers@PAGE
    add     x0, x0, perf_timers@PAGEOFF
    
    ; Timer 0: Input processing
    ldr     x1, [x0, #8]
    bl      _print_perf_metric
    
    ; Timer 1: Physics integration
    ldr     x1, [x0, #24]
    bl      _print_perf_metric
    
    ; Timer 2: Collision detection
    ldr     x1, [x0, #40]
    bl      _print_perf_metric
    
    ldp     x29, x30, [sp], #16
    ret

;── Stack Guard Implementation ────────────────────────────────────────────────
.macro STACK_GUARD_PUSH
    .ifdef DEBUG_BUILD
        mov     x28, #0xDEADBEEFDEADBEEF    ; Canary value
        str     x28, [sp, #-16]!
    .endif
.endmacro

.macro STACK_GUARD_CHECK
    .ifdef DEBUG_BUILD
        ldr     x28, [sp], #16
        mov     x27, #0xDEADBEEFDEADBEEF
        cmp     x28, x27
        b.eq    1f
        
        ; Stack corruption
        adrp    x0, debug_msg_stack_corruption@PAGE
        add     x0, x0, debug_msg_stack_corruption@PAGEOFF
        mov     x1, sp
        mov     x2, #ERR_STACK_CORRUPTION
        bl      _debug_error
    1:
    .endif
.endmacro