;------------------------------------------------------------------------------
; camera_controller_working.s - Working camera controller with debugging
;------------------------------------------------------------------------------

.section __DATA,__data
.align 6

; Global camera state
.globl _camera_state
_camera_state:
    .float  0.0, 0.0        ; iso_x, iso_y (offset 0)
    .float  50.0, 50.0      ; world_x, world_z (offset 8)
    .float  100.0           ; height (offset 16)
    .float  0.0             ; rotation (offset 20)
    .float  0.0, 0.0        ; vel_x, vel_z (offset 24)
    .float  0.0             ; zoom_vel (offset 32)
    .float  0.0             ; rot_vel (offset 36)
    .float  0.0, 0.0        ; edge_pan_x, edge_pan_z (offset 40)
    .word   0               ; bounce_timer (offset 48)
    .word   0, 0, 0         ; padding (offset 52)

.globl _camera_view_matrix
_camera_view_matrix:
    .float  1.0, 0.0, 0.0, 0.0
    .float  0.0, 1.0, 0.0, 0.0
    .float  0.0, 0.0, 1.0, 0.0
    .float  0.0, 0.0, 0.0, 1.0

; Debug state
.globl _camera_debug_state
_camera_debug_state:
    .quad   0               ; Last error code
    .quad   0               ; Frame counter
    .quad   0               ; Input events processed
    .quad   0               ; Physics updates
    .quad   0               ; Frame start time
    .quad   0               ; Last frame time
    .quad   0               ; Min frame time
    .quad   0               ; Max frame time
    .quad   0               ; Average frame time
    .quad   0               ; Performance violations

; Constants as data
.align 4
const_base_speed:       .float 35.0
const_speed_boost:      .float 2.5
const_max_velocity:     .float 200.0
const_accel_rate:       .float 8.0
const_smoothing:        .float 0.3
const_damping:          .float 0.95
const_min_damping:      .float 0.7
const_pan_sens:         .float 0.3
const_edge_speed:       .float 50.0
const_edge_smooth:      .float 0.7
const_edge_weight:      .float 0.3
const_zoom_sens:        .float 0.03
const_zoom_smooth:      .float 0.2
const_min_zoom:         .float 5.0
const_max_zoom:         .float 1000.0
const_bounds_min:       .float -10000.0
const_bounds_max:       .float 10000.0

.section __TEXT,__text,regular,pure_instructions
.align 2

;------------------------------------------------------------------------------
; Main camera update
; X0 = pointer to input buffer, S0 = delta time
;------------------------------------------------------------------------------
.globl _camera_update
_camera_update:
    stp     x29, x30, [sp, #-64]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     d8, d9, [sp, #48]
    mov     x29, sp
    
    ; Load camera state pointer
    adrp    x19, _camera_state@PAGE
    add     x19, x19, _camera_state@PAGEOFF
    
    ; Save inputs
    mov     x20, x0                 ; Input state pointer
    fmov    s31, s0                 ; Delta time
    
    ; Process keyboard input
    bl      process_keyboard_input
    
    ; Process mouse input
    bl      process_mouse_input
    
    ; Process scroll input
    bl      process_scroll_input
    
    ; Update physics
    bl      update_physics
    
    ; Update view matrix
    bl      update_view_matrix
    
    ; Restore registers and return
    ldp     d8, d9, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

;------------------------------------------------------------------------------
; Process keyboard input
;------------------------------------------------------------------------------
process_keyboard_input:
    stp     x29, x30, [sp, #-16]!
    
    ; Load key state
    ldr     w0, [x20, #0]           ; Key bitmask
    
    ; Calculate movement vector
    fmov    s0, #0.0                ; X movement
    fmov    s1, #0.0                ; Z movement
    mov     w4, #0                  ; Movement active flag
    
    ; Check arrow keys
    tst     w0, #0x01               ; Up arrow
    b.eq    1f
    fmov    s1, #1.0
    mov     w4, #1
1:
    tst     w0, #0x02               ; Down arrow
    b.eq    2f
    fmov    s1, #-1.0
    mov     w4, #1
2:
    tst     w0, #0x04               ; Left arrow
    b.eq    3f
    fmov    s0, #-1.0
    mov     w4, #1
3:
    tst     w0, #0x08               ; Right arrow
    b.eq    4f
    fmov    s0, #1.0
    mov     w4, #1
4:
    
    ; Normalize diagonal movement
    cbz     w4, no_movement
    fmul    s2, s0, s0              ; x²
    fmul    s3, s1, s1              ; z²
    fadd    s2, s2, s3              ; x² + z²
    fcmp    s2, #0.0
    b.eq    no_movement
    
    fsqrt   s2, s2                  ; magnitude
    fmov    s3, #1.0
    fdiv    s3, s3, s2              ; 1/magnitude
    fmul    s0, s0, s3              ; normalized X
    fmul    s1, s1, s3              ; normalized Z
no_movement:
    
    ; Apply speed
    adrp    x1, const_base_speed@PAGE
    add     x1, x1, const_base_speed@PAGEOFF
    ldr     s2, [x1]                ; Base speed
    
    ; Check shift for boost
    tst     w0, #0x10               ; Shift key
    b.eq    5f
    adrp    x1, const_speed_boost@PAGE
    add     x1, x1, const_speed_boost@PAGEOFF
    ldr     s3, [x1]
    fmul    s2, s2, s3
5:
    
    ; Scale movement by speed
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    
    ; Update velocity
    ldp     s3, s4, [x19, #24]      ; Current velocity
    
    ; Calculate acceleration
    adrp    x1, const_accel_rate@PAGE
    add     x1, x1, const_accel_rate@PAGEOFF
    ldr     s5, [x1]
    fmul    s5, s5, s31             ; Scale by delta time
    
    ; Apply smoothing
    adrp    x1, const_smoothing@PAGE
    add     x1, x1, const_smoothing@PAGEOFF
    ldr     s6, [x1]
    fmul    s5, s5, s6
    
    ; Update velocity
    fsub    s6, s0, s3              ; Target - current
    fmul    s6, s6, s5              ; Scale
    fadd    s3, s3, s6              ; Update
    
    fsub    s7, s1, s4
    fmul    s7, s7, s5
    fadd    s4, s4, s7
    
    ; Store updated velocity
    stp     s3, s4, [x19, #24]
    
    ldp     x29, x30, [sp], #16
    ret

;------------------------------------------------------------------------------
; Process mouse input
;------------------------------------------------------------------------------
process_mouse_input:
    stp     x29, x30, [sp, #-32]!
    stp     d8, d9, [sp, #16]
    
    ; Check for mouse drag
    ldr     w0, [x20, #0x20]        ; Mouse buttons
    tst     w0, #1                  ; Left button
    b.eq    check_edge_pan
    
    ; Get mouse deltas
    ldp     w1, w2, [x20, #0x18]    ; delta_x, delta_y
    
    ; Convert to float
    scvtf   s0, w1
    scvtf   s1, w2
    
    ; Apply sensitivity
    adrp    x3, const_pan_sens@PAGE
    add     x3, x3, const_pan_sens@PAGEOFF
    ldr     s2, [x3]
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    
    ; Apply to position
    ldp     s3, s4, [x19, #8]       ; world position
    fsub    s3, s3, s0              ; Pan X
    fadd    s4, s4, s1              ; Pan Z
    stp     s3, s4, [x19, #8]
    
check_edge_pan:
    ; Simple edge panning
    ldp     w0, w1, [x20, #0x10]    ; mouse_x, mouse_y
    ldp     w2, w3, [x20, #0x28]    ; screen dimensions
    
    cmp     w2, #0
    b.ne    1f
    mov     w2, #800
    mov     w3, #600
1:
    
    fmov    s8, #0.0                ; Edge pan X
    fmov    s9, #0.0                ; Edge pan Z
    
    ; Check edges
    cmp     w0, #20
    b.gt    2f
    fmov    s8, #-1.0
2:
    sub     w4, w2, #20
    cmp     w0, w4
    b.lt    3f
    fmov    s8, #1.0
3:
    cmp     w1, #20
    b.gt    4f
    fmov    s9, #1.0
4:
    sub     w4, w3, #20
    cmp     w1, w4
    b.lt    5f
    fmov    s9, #-1.0
5:
    
    ; Apply edge speed
    adrp    x1, const_edge_speed@PAGE
    add     x1, x1, const_edge_speed@PAGEOFF
    ldr     s10, [x1]
    fmul    s8, s8, s10
    fmul    s9, s9, s10
    
    ; Store edge pan
    stp     s8, s9, [x19, #40]
    
    ldp     d8, d9, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

;------------------------------------------------------------------------------
; Process scroll input
;------------------------------------------------------------------------------
process_scroll_input:
    stp     x29, x30, [sp, #-16]!
    
    ; Get scroll delta
    ldrsh   w0, [x20, #0x26]        ; scroll_y
    cbz     w0, scroll_done
    
    ; Convert to float
    scvtf   s0, w0
    
    ; Apply sensitivity
    adrp    x1, const_zoom_sens@PAGE
    add     x1, x1, const_zoom_sens@PAGEOFF
    ldr     s1, [x1]
    fmul    s0, s0, s1
    
    ; Update height
    ldr     s1, [x19, #16]          ; Current height
    fmov    s2, #1.0
    fadd    s2, s2, s0              ; 1 + delta
    fmul    s1, s1, s2              ; Apply zoom
    
    ; Clamp
    adrp    x1, const_min_zoom@PAGE
    add     x1, x1, const_min_zoom@PAGEOFF
    ldr     s2, [x1]
    adrp    x1, const_max_zoom@PAGE
    add     x1, x1, const_max_zoom@PAGEOFF
    ldr     s3, [x1]
    
    fmax    s1, s1, s2
    fmin    s1, s1, s3
    
    ; Store
    str     s1, [x19, #16]
    
scroll_done:
    ldp     x29, x30, [sp], #16
    ret

;------------------------------------------------------------------------------
; Update physics
;------------------------------------------------------------------------------
update_physics:
    stp     x29, x30, [sp, #-32]!
    stp     d8, d9, [sp, #16]
    
    ; Load velocities
    ldp     s0, s1, [x19, #24]      ; vel_x, vel_z
    
    ; Add edge pan
    ldp     s2, s3, [x19, #40]      ; edge_pan
    fadd    s0, s0, s2
    fadd    s1, s1, s3
    
    ; Apply damping
    adrp    x1, const_damping@PAGE
    add     x1, x1, const_damping@PAGEOFF
    ldr     s4, [x1]
    fmul    s0, s0, s4
    fmul    s1, s1, s4
    
    ; Store velocities
    stp     s0, s1, [x19, #24]
    
    ; Update position
    ldp     s2, s3, [x19, #8]       ; world position
    fmadd   s2, s0, s31, s2         ; x += vx * dt
    fmadd   s3, s1, s31, s3         ; z += vz * dt
    stp     s2, s3, [x19, #8]
    
    ldp     d8, d9, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

;------------------------------------------------------------------------------
; Update view matrix
;------------------------------------------------------------------------------
update_view_matrix:
    adrp    x0, _camera_view_matrix@PAGE
    add     x0, x0, _camera_view_matrix@PAGEOFF
    
    ; Get position
    ldp     s0, s1, [x19, #8]       ; world_x, world_z
    ldr     s2, [x19, #16]          ; height
    
    ; Negate for view matrix
    fneg    s0, s0
    fneg    s1, s1
    fneg    s2, s2
    
    ; Store translation
    str     s0, [x0, #12]
    str     s2, [x0, #28]
    str     s1, [x0, #44]
    
    ret

;------------------------------------------------------------------------------
; Reset camera
;------------------------------------------------------------------------------
.globl _camera_reset
_camera_reset:
    adrp    x0, _camera_state@PAGE
    add     x0, x0, _camera_state@PAGEOFF
    
    ; Reset position to 50.0, 50.0
    adrp    x1, const_edge_speed@PAGE
    add     x1, x1, const_edge_speed@PAGEOFF
    ldr     s0, [x1]                ; Load 50.0
    str     s0, [x0, #8]            ; world_x
    str     s0, [x0, #12]           ; world_z
    
    ; Reset height to 100.0
    fmov    s0, #10.0
    fmov    s1, #10.0
    fmul    s0, s0, s1              ; 100.0
    str     s0, [x0, #16]           ; height
    
    ; Clear velocities
    stp     wzr, wzr, [x0, #24]
    stp     wzr, wzr, [x0, #32]
    stp     wzr, wzr, [x0, #40]
    str     wzr, [x0, #48]          ; Clear bounce timer
    
    ret

;------------------------------------------------------------------------------
; Validate camera state
;------------------------------------------------------------------------------
.globl _camera_validate_state
_camera_validate_state:
    adrp    x0, _camera_state@PAGE
    add     x0, x0, _camera_state@PAGEOFF
    
    ; Check for NaN
    ldp     s0, s1, [x0, #8]
    ldr     s2, [x0, #16]
    
    fcmp    s0, s0
    b.ne    nan_detected
    fcmp    s1, s1
    b.ne    nan_detected
    fcmp    s2, s2
    b.ne    nan_detected
    
    ; Check bounds
    adrp    x1, const_bounds_min@PAGE
    add     x1, x1, const_bounds_min@PAGEOFF
    ldr     s3, [x1]
    adrp    x1, const_bounds_max@PAGE
    add     x1, x1, const_bounds_max@PAGEOFF
    ldr     s4, [x1]
    
    fcmp    s0, s3
    b.lt    bounds_error
    fcmp    s0, s4
    b.gt    bounds_error
    fcmp    s1, s3
    b.lt    bounds_error
    fcmp    s1, s4
    b.gt    bounds_error
    
    mov     x0, #0
    ret
    
nan_detected:
    mov     x0, #0x6004             ; ERR_MATH_NAN
    ret
    
bounds_error:
    mov     x0, #0x2003             ; ERR_PHYSICS_BOUNDS
    ret

;------------------------------------------------------------------------------
; Get world position
;------------------------------------------------------------------------------
.globl _camera_get_world_position
_camera_get_world_position:
    adrp    x0, _camera_state@PAGE
    add     x0, x0, _camera_state@PAGEOFF
    
    ldp     s0, s1, [x0, #8]        ; world_x, world_z
    ldr     s2, [x0, #16]           ; height
    
    ret

;------------------------------------------------------------------------------
; Get performance stats (stub)
;------------------------------------------------------------------------------
.globl _camera_get_performance_stats
_camera_get_performance_stats:
    ; Just clear the output buffer
    stp     xzr, xzr, [x0, #0]
    stp     xzr, xzr, [x0, #16]
    stp     xzr, xzr, [x0, #32]
    ret