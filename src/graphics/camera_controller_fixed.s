;------------------------------------------------------------------------------
; camera_controller_fixed.s - Fixed camera controller with proper debugging
;------------------------------------------------------------------------------

.include "../include/debug_constants.inc"

; Camera control constants with improvements from testing
.equ EDGE_THRESHOLD,      20      ; Pixels from edge for panning
.equ EDGE_HYSTERESIS,     5       ; Prevent edge flicker
.equ DEAD_ZONE_RADIUS,    2       ; Ignore tiny movements
.equ MAX_VELOCITY,        200.0   ; Maximum movement velocity
.equ VELOCITY_DAMPING,    0.95    ; Gradual slowdown
.equ ACCEL_CURVE_POWER,   2.0     ; Quadratic acceleration
.equ ZOOM_INERTIA,        0.85    ; Zoom momentum preservation
.equ ZOOM_SMOOTHING,      0.2     ; Input smoothing factor
.equ ELASTIC_STRENGTH,    50.0    ; Bounce-back force
.equ ELASTIC_DAMPING,     0.7     ; Oscillation control

; Performance targets
.equ TARGET_FRAME_TIME,   4166667 ; 4.16ms in nanoseconds (240Hz)
.equ PERF_SAMPLE_COUNT,   240     ; 1 second of samples

.section __DATA,__data
.align 6

; Global camera state (128-byte aligned for cache efficiency)
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

; Edge panning state with hysteresis
.globl _edge_pan_state
_edge_pan_state:
    .word   0               ; Active edges (bitmask)
    .word   0               ; Previous edges
    .float  0.0, 0.0        ; Smoothed edge velocity

.section __TEXT,__text,regular,pure_instructions
.align 2

;------------------------------------------------------------------------------
; Main camera update with proper input handling
; X0 = pointer to input buffer, S0 = delta time
;------------------------------------------------------------------------------
.globl _camera_update
_camera_update:
    ; Save registers and create stack frame
    stp     x29, x30, [sp, #-64]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     d8, d9, [sp, #48]
    mov     x29, sp
    
    ; Performance timer start
    .ifdef PERF_MONITORING
    PERF_TIMER_START TIMER_TOTAL_FRAME
    .endif
    
    ; Record frame start time
    mrs     x0, CNTVCT_EL0          ; Get current timer
    str     x0, [x21, #32]          ; Store frame start
    
    ; Load camera state pointer
    adrp    x19, _camera_state@PAGE
    add     x19, x19, _camera_state@PAGEOFF
    
    ; Save inputs
    mov     x20, x0                 ; Input state pointer
    fmov    s31, s0                 ; Delta time
    
    ; Validate inputs
    .ifdef DEBUG_BUILD
    cbz     x20, input_null_error
    tst     x20, #7                 ; Check 8-byte alignment
    b.ne    input_alignment_error
    .endif
    
    ; Update debug counters
    adrp    x21, _camera_debug_state@PAGE
    add     x21, x21, _camera_debug_state@PAGEOFF
    ldr     x0, [x21, #8]           ; Frame counter
    add     x0, x0, #1
    str     x0, [x21, #8]
    
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
    
    ; Performance timer end
    .ifdef PERF_MONITORING
    PERF_TIMER_END TIMER_TOTAL_FRAME
    .endif
    
    ; Update frame timing statistics
    mrs     x0, CNTVCT_EL0          ; Current time
    ldr     x1, [x21, #32]          ; Frame start
    sub     x0, x0, x1              ; Frame duration
    str     x0, [x21, #40]          ; Last frame time
    
    ; Update min/max
    ldr     x1, [x21, #48]          ; Min time
    cmp     x1, #0
    b.ne    1f
    str     x0, [x21, #48]          ; Initialize min
1:
    cmp     x0, x1
    b.hs    2f
    str     x0, [x21, #48]          ; New min
2:
    ldr     x1, [x21, #56]          ; Max time
    cmp     x0, x1
    b.ls    3f
    str     x0, [x21, #56]          ; New max
3:
    
    ; Check performance violation
    ldr     x1, =4166667            ; TARGET_FRAME_TIME
    cmp     x0, x1
    b.ls    4f
    ldr     x1, [x21, #72]          ; Violations
    add     x1, x1, #1
    str     x1, [x21, #72]
4:
    
    ; Restore registers and return
    ldp     d8, d9, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

input_null_error:
    mov     x0, #ERR_INPUT_NULL_PTR
    bl      record_error
    b       camera_update_exit

input_alignment_error:
    mov     x0, #ERR_ALIGNMENT_VIOLATION
    bl      record_error
    b       camera_update_exit

camera_update_exit:
    ldp     d8, d9, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

;------------------------------------------------------------------------------
; Process keyboard input with proper arrow key handling
;------------------------------------------------------------------------------
process_keyboard_input:
    stp     x29, x30, [sp, #-16]!
    
    .ifdef PERF_MONITORING
    PERF_TIMER_START TIMER_INPUT_PROCESS
    .endif
    
    ; Load key state
    ldr     w0, [x20, #0]           ; Key bitmask
    
    ; Debug: log key state if non-zero
    .ifdef DEBUG_BUILD
    cbz     w0, no_keys_pressed
    adrp    x1, _camera_debug_state@PAGE
    add     x1, x1, _camera_debug_state@PAGEOFF
    ldr     x2, [x1, #16]           ; Input events
    add     x2, x2, #1
    str     x2, [x1, #16]
no_keys_pressed:
    .endif
    
    ; Calculate movement vector with dead zone
    fmov    s0, #0.0                ; X movement
    fmov    s1, #0.0                ; Z movement
    mov     w4, #0                  ; Movement active flag
    
    ; Check arrow keys with improved handling
    tst     w0, #0x01               ; Up arrow (bit 0)
    b.eq    1f
    fmov    s1, #1.0                ; Move forward (+Z)
    mov     w4, #1                  ; Mark movement active
1:
    tst     w0, #0x02               ; Down arrow (bit 1)
    b.eq    2f
    fmov    s1, #-1.0               ; Move backward (-Z)
    mov     w4, #1
2:
    tst     w0, #0x04               ; Left arrow (bit 2)
    b.eq    3f
    fmov    s0, #-1.0               ; Move left (-X)
    mov     w4, #1
3:
    tst     w0, #0x08               ; Right arrow (bit 3)
    b.eq    4f
    fmov    s0, #1.0                ; Move right (+X)
    mov     w4, #1
4:
    
    ; Normalize diagonal movement
    cbz     w4, no_movement
    fmul    s2, s0, s0              ; x²
    fmul    s3, s1, s1              ; z²
    fadd    s2, s2, s3              ; x² + z²
    fcmp    s2, #0.0
    b.eq    no_movement
    
    ; Calculate magnitude and normalize
    fsqrt   s2, s2                  ; magnitude
    fmov    s3, #1.0
    fdiv    s3, s3, s2              ; 1/magnitude
    fmul    s0, s0, s3              ; normalized X
    fmul    s1, s1, s3              ; normalized Z
no_movement:
    
    ; Apply speed modifiers with acceleration curve
    fmov    s2, #35.0               ; Base speed (tuned for responsiveness)
    
    ; Check shift key for boost
    tst     w0, #0x10               ; Shift (bit 4)
    b.eq    5f
    fmov    s3, #2.5                ; Speed multiplier
    fmul    s2, s2, s3
5:
    
    ; Apply acceleration curve (quadratic)
    cbz     w4, skip_accel
    ldp     s6, s7, [x19, #24]      ; Current velocity
    fmul    s6, s6, s6              ; vx²
    fmul    s7, s7, s7              ; vz²
    fadd    s6, s6, s7              ; v²
    fsqrt   s6, s6                  ; |v|
    
    ; Calculate acceleration factor (1 + v/max_v)
    fmov    s7, #MAX_VELOCITY
    fdiv    s6, s6, s7
    fmov    s7, #1.0
    fadd    s6, s6, s7              ; 1 + v/max_v
    fmul    s2, s2, s6              ; Apply curve
skip_accel:
    
    ; Scale movement by speed
    fmul    s0, s0, s2              ; X movement * speed
    fmul    s1, s1, s2              ; Z movement * speed
    
    ; Apply movement to velocity (with acceleration)
    ldp     s3, s4, [x19, #24]      ; Load current velocity
    
    ; Calculate acceleration with improved response
    fmov    s5, #8.0                ; Acceleration rate (tuned)
    fmul    s5, s5, s31             ; Scale by delta time
    
    ; Apply input smoothing for better control
    fmov    s8, #0.3                ; Smoothing factor
    fmul    s5, s5, s8
    
    ; Update velocity with improved acceleration
    fsub    s6, s0, s3              ; Target X - current X
    fmul    s6, s6, s5              ; Scale by acceleration
    fadd    s3, s3, s6              ; Update X velocity
    
    fsub    s7, s1, s4              ; Target Z - current Z
    fmul    s7, s7, s5              ; Scale by acceleration
    fadd    s4, s4, s7              ; Update Z velocity
    
    ; Clamp velocity to maximum
    fmul    s6, s3, s3              ; vx²
    fmul    s7, s4, s4              ; vz²
    fadd    s6, s6, s7              ; v²
    fsqrt   s6, s6                  ; |v|
    
    fmov    s7, #MAX_VELOCITY
    fcmp    s6, s7
    b.le    velocity_ok
    
    ; Scale down velocity
    fdiv    s7, s7, s6              ; max_v / |v|
    fmul    s3, s3, s7
    fmul    s4, s4, s7
velocity_ok:
    
    ; Store updated velocity
    stp     s3, s4, [x19, #24]
    
    .ifdef PERF_MONITORING
    PERF_TIMER_END TIMER_INPUT_PROCESS
    .endif
    
    ldp     x29, x30, [sp], #16
    ret

;------------------------------------------------------------------------------
; Process mouse input
;------------------------------------------------------------------------------
process_mouse_input:
    stp     x29, x30, [sp, #-32]!
    stp     d8, d9, [sp, #16]
    
    ; Check for mouse drag (panning)
    ldr     w0, [x20, #0x20]        ; Mouse buttons
    tst     w0, #1                  ; Left button
    b.eq    check_edge_pan
    
    ; Get mouse deltas
    ldp     w1, w2, [x20, #0x18]    ; mouse_delta_x, mouse_delta_y
    
    ; Convert to float and apply sensitivity
    scvtf   s0, w1
    scvtf   s1, w2
    fmov    s2, #0.3                ; Pan sensitivity (reduced)
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    
    ; Apply to world position (inverted for intuitive panning)
    ldp     s3, s4, [x19, #8]       ; Load world position
    fsub    s3, s3, s0              ; Pan X
    fadd    s4, s4, s1              ; Pan Z
    stp     s3, s4, [x19, #8]       ; Store back
    
check_edge_pan:
    ; Edge panning with hysteresis
    ldp     w0, w1, [x20, #0x10]    ; mouse_x, mouse_y
    
    ; Get screen dimensions
    ldp     w2, w3, [x20, #0x28]    ; screen_width, screen_height
    cmp     w2, #0
    b.ne    1f
    mov     w2, #800
    mov     w3, #600
1:
    
    ; Load edge state
    adrp    x5, _edge_pan_state@PAGE
    add     x5, x5, _edge_pan_state@PAGEOFF
    ldr     w6, [x5, #0]            ; Current edges
    ldr     w7, [x5, #4]            ; Previous edges
    
    ; Check edges with hysteresis
    mov     w8, #0                  ; New edge mask
    fmov    s8, #0.0                ; Edge pan X
    fmov    s9, #0.0                ; Edge pan Z
    
    ; Left edge
    mov     w9, #EDGE_THRESHOLD
    tst     w7, #1                  ; Was left active?
    b.eq    2f
    add     w9, w9, #EDGE_HYSTERESIS
2:
    cmp     w0, w9
    b.gt    3f
    orr     w8, w8, #1
    fmov    s8, #-1.0
3:
    ; Right edge
    sub     w9, w2, #EDGE_THRESHOLD
    tst     w7, #2                  ; Was right active?
    b.eq    4f
    sub     w9, w9, #EDGE_HYSTERESIS
4:
    cmp     w0, w9
    b.lt    5f
    orr     w8, w8, #2
    fmov    s8, #1.0
5:
    ; Top edge
    mov     w9, #EDGE_THRESHOLD
    tst     w7, #4                  ; Was top active?
    b.eq    6f
    add     w9, w9, #EDGE_HYSTERESIS
6:
    cmp     w1, w9
    b.gt    7f
    orr     w8, w8, #4
    fmov    s9, #1.0
7:
    ; Bottom edge
    sub     w9, w3, #EDGE_THRESHOLD
    tst     w7, #8                  ; Was bottom active?
    b.eq    8f
    sub     w9, w9, #EDGE_HYSTERESIS
8:
    cmp     w1, w9
    b.lt    9f
    orr     w8, w8, #8
    fmov    s9, #-1.0
9:
    
    ; Store new edge state
    str     w8, [x5, #0]            ; Current edges
    str     w6, [x5, #4]            ; Previous = old current
    
    ; Apply edge panning with progressive speed
    fmov    s10, #50.0              ; Base edge pan speed
    
    ; Progressive speed based on distance from edge
    cmp     w0, #10                 ; Very close to edge?
    b.gt    10f
    fmov    s11, #1.5               ; Speed multiplier
    fmul    s10, s10, s11
10:
    
    fmul    s8, s8, s10
    fmul    s9, s9, s10
    
    ; Smooth edge pan velocity
    ldp     s10, s11, [x5, #8]      ; Previous smoothed velocity
    fmov    s12, #0.7               ; Smoothing factor
    fmov    s13, #0.3               ; New weight
    fmul    s10, s10, s12           ; Old * 0.7
    fmul    s11, s11, s12
    fmul    s14, s8, s13            ; New * 0.3
    fmul    s15, s9, s13
    fadd    s8, s10, s14            ; Smoothed X
    fadd    s9, s11, s15            ; Smoothed Z
    stp     s8, s9, [x5, #8]        ; Store smoothed
    
    ; Store edge pan values
    stp     s8, s9, [x19, #40]
    
    ldp     d8, d9, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

;------------------------------------------------------------------------------
; Process scroll input (zoom)
;------------------------------------------------------------------------------
process_scroll_input:
    stp     x29, x30, [sp, #-16]!
    
    .ifdef PERF_MONITORING
    PERF_TIMER_START TIMER_ZOOM_CALC
    .endif
    
    ; Get scroll delta
    ldrsh   w0, [x20, #0x26]        ; scroll_y (signed 16-bit)
    cbz     w0, scroll_done
    
    ; Convert to float
    scvtf   s0, w0
    
    ; Load current height
    ldr     s1, [x19, #16]
    
    ; Calculate zoom with smoothing and inertia
    fmov    s2, #0.03               ; Zoom sensitivity (reduced)
    fmul    s0, s0, s2
    
    ; Apply zoom smoothing
    ldr     s2, [x19, #32]          ; zoom_vel
    fmov    s3, #ZOOM_SMOOTHING
    fmul    s0, s0, s3              ; New input weight
    fmov    s4, #1.0
    fsub    s4, s4, s3              ; Old weight
    fmul    s2, s2, s4
    fadd    s0, s0, s2              ; Smoothed zoom
    str     s0, [x19, #32]          ; Store zoom_vel
    
    ; Calculate exponential zoom
    fmov    s3, #1.0
    fadd    s3, s3, s0              ; 1 + delta
    
    ; Apply zoom
    fmul    s1, s1, s3
    
    ; Clamp to limits
    fmov    s4, #5.0                ; Min zoom
    fmov    s5, #1000.0             ; Max zoom
    fmax    s1, s1, s4
    fmin    s1, s1, s5
    
    ; Check if hit limit (for bounce effect)
    fcmp    s1, s4
    b.eq    hit_zoom_limit
    fcmp    s1, s5
    b.eq    hit_zoom_limit
    b       store_zoom
    
hit_zoom_limit:
    ; Trigger bounce animation
    mov     w0, #30                 ; 0.5 seconds at 60fps
    str     w0, [x19, #48]          ; bounce_timer
    
    .ifdef DEBUG_BUILD
    adrp    x0, _debug_counters@PAGE
    add     x0, x0, _debug_counters@PAGEOFF
    ldr     w1, [x0, #20]           ; Zoom limit hits
    add     w1, w1, #1
    str     w1, [x0, #20]
    .endif
    
store_zoom:
    ; Store new height
    str     s1, [x19, #16]
    
scroll_done:
    .ifdef PERF_MONITORING
    PERF_TIMER_END TIMER_ZOOM_CALC
    .endif
    
    ldp     x29, x30, [sp], #16
    ret

;------------------------------------------------------------------------------
; Update physics with proper damping
;------------------------------------------------------------------------------
update_physics:
    stp     x29, x30, [sp, #-32]!
    stp     d8, d9, [sp, #16]
    
    .ifdef PERF_MONITORING
    PERF_TIMER_START TIMER_PHYSICS_UPDATE
    .endif
    
    ; Load velocities
    ldp     s0, s1, [x19, #24]      ; vel_x, vel_z
    
    ; Add edge pan velocity
    ldp     s2, s3, [x19, #40]      ; edge_pan_x, edge_pan_z
    fadd    s0, s0, s2
    fadd    s1, s1, s3
    
    ; Apply velocity-dependent damping
    fmul    s5, s0, s0              ; vx²
    fmul    s6, s1, s1              ; vz²
    fadd    s5, s5, s6              ; v²
    fsqrt   s5, s5                  ; |v|
    
    ; Calculate damping (more damping at high speed)
    fmov    s4, #VELOCITY_DAMPING   ; Base damping
    fmov    s6, #50.0               ; Reference velocity
    fdiv    s5, s5, s6              ; v/ref
    fmov    s6, #0.1
    fmul    s5, s5, s6              ; Scale
    fsub    s4, s4, s5              ; Reduce damping by speed factor
    fmov    s5, #0.7                ; Min damping
    fmax    s4, s4, s5              ; Clamp to minimum
    
    fmul    s0, s0, s4
    fmul    s1, s1, s4
    
    ; Store updated velocities
    stp     s0, s1, [x19, #24]
    
    ; Update position
    ldp     s2, s3, [x19, #8]       ; world_x, world_z
    fmul    s4, s0, s31             ; vel_x * delta_time
    fmul    s5, s1, s31             ; vel_z * delta_time
    fadd    s2, s2, s4              ; world_x += vel_x * dt
    fadd    s3, s3, s5              ; world_z += vel_z * dt
    stp     s2, s3, [x19, #8]
    
    ; Handle bounce animation
    ldr     w0, [x19, #48]          ; bounce_timer
    cbz     w0, physics_done
    
    ; Update bounce
    sub     w0, w0, #1
    str     w0, [x19, #48]
    
    ; Calculate elastic bounce with damping
    scvtf   s6, w0
    fmov    s7, #30.0               ; Total frames
    fdiv    s6, s6, s7              ; Normalized time
    
    ; Damped sine wave: e^(-kt) * sin(wt)
    fmov    s7, #ELASTIC_DAMPING
    fmul    s7, s7, s6              ; k*t
    fneg    s7, s7                  ; -k*t
    ; Approximate e^x ≈ 1 + x + x²/2 for small x
    fmul    s8, s7, s7              ; x²
    fmov    s9, #0.5
    fmul    s8, s8, s9              ; x²/2
    fmov    s9, #1.0
    fadd    s9, s9, s7              ; 1 + x
    fadd    s9, s9, s8              ; 1 + x + x²/2 (e^(-kt))
    
    ; Calculate sine
    fmov    s7, #6.28318            ; 2*pi for full cycle
    fmul    s6, s6, s7              ; t * 2pi
    ; Better sine approximation
    fmul    s7, s6, s6              ; x²
    fmul    s8, s7, s6              ; x³
    fmov    s10, #6.0
    fdiv    s8, s8, s10             ; x³/6
    fmul    s10, s7, s7             ; x⁴
    fmul    s10, s10, s6            ; x⁵
    fmov    s11, #120.0
    fdiv    s10, s10, s11           ; x⁵/120
    fsub    s6, s6, s8              ; x - x³/6
    fadd    s6, s6, s10             ; x - x³/6 + x⁵/120
    
    ; Apply damping envelope
    fmul    s6, s6, s9
    
    ; Apply bounce to height
    fmov    s7, #2.0                ; Bounce amplitude
    fmul    s6, s6, s7
    ldr     s8, [x19, #16]          ; Current height
    fadd    s8, s8, s6
    str     s8, [x19, #16]
    
physics_done:
    .ifdef PERF_MONITORING
    PERF_TIMER_END TIMER_PHYSICS_UPDATE
    .endif
    
    ldp     d8, d9, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

;------------------------------------------------------------------------------
; Update view matrix
;------------------------------------------------------------------------------
update_view_matrix:
    stp     x29, x30, [sp, #-16]!
    
    adrp    x0, _camera_view_matrix@PAGE
    add     x0, x0, _camera_view_matrix@PAGEOFF
    
    ; Create translation matrix
    ldp     s0, s1, [x19, #8]       ; world_x, world_z
    ldr     s2, [x19, #16]          ; height
    
    ; Negate for view matrix
    fneg    s0, s0
    fneg    s1, s1
    fneg    s2, s2
    
    ; Update matrix translation
    str     s0, [x0, #12]           ; M[0][3]
    str     s2, [x0, #28]           ; M[1][3]
    str     s1, [x0, #44]           ; M[2][3]
    
    ldp     x29, x30, [sp], #16
    ret

;------------------------------------------------------------------------------
; Error recording
;------------------------------------------------------------------------------
record_error:
    ; x0 = error code
    adrp    x1, _camera_debug_state@PAGE
    add     x1, x1, _camera_debug_state@PAGEOFF
    str     x0, [x1, #0]            ; Store error code
    ret

;------------------------------------------------------------------------------
; Get camera world position (for external use)
;------------------------------------------------------------------------------
.globl _camera_get_world_position
_camera_get_world_position:
    adrp    x0, _camera_state@PAGE
    add     x0, x0, _camera_state@PAGEOFF
    
    ldp     s0, s1, [x0, #8]        ; world_x, world_z
    ldr     s2, [x0, #16]           ; height
    
    ret

;------------------------------------------------------------------------------
; Reset camera to default position
;------------------------------------------------------------------------------
.globl _camera_reset
_camera_reset:
    adrp    x0, _camera_state@PAGE
    add     x0, x0, _camera_state@PAGEOFF
    
    ; Reset position
    fmov    s0, #50.0
    fmov    s1, #50.0
    stp     s0, s1, [x0, #8]        ; world_x, world_z
    
    fmov    s0, #100.0
    str     s0, [x0, #16]           ; height
    
    ; Clear velocities
    stp     wzr, wzr, [x0, #24]     ; vel_x, vel_z
    stp     wzr, wzr, [x0, #32]     ; zoom_vel, rot_vel
    stp     wzr, wzr, [x0, #40]     ; edge_pan
    
    ; Reset edge pan state
    adrp    x1, _edge_pan_state@PAGE
    add     x1, x1, _edge_pan_state@PAGEOFF
    stp     wzr, wzr, [x1, #0]      ; Active/previous edges
    stp     wzr, wzr, [x1, #8]      ; Smoothed velocity
    
    ; Reset debug counters
    adrp    x1, _camera_debug_state@PAGE
    add     x1, x1, _camera_debug_state@PAGEOFF
    mov     x2, #80                 ; Size of debug state
    mov     x3, #0
1:
    str     xzr, [x1], #8
    subs    x2, x2, #8
    b.ne    1b
    
    ret

;------------------------------------------------------------------------------
; Get performance statistics
;------------------------------------------------------------------------------
.globl _camera_get_performance_stats
_camera_get_performance_stats:
    ; X0 = output buffer pointer
    adrp    x1, _camera_debug_state@PAGE
    add     x1, x1, _camera_debug_state@PAGEOFF
    
    ; Copy performance data
    ldp     x2, x3, [x1, #32]       ; Frame start, last time
    stp     x2, x3, [x0, #0]
    ldp     x2, x3, [x1, #48]       ; Min, max
    stp     x2, x3, [x0, #16]
    ldp     x2, x3, [x1, #64]       ; Average, violations
    stp     x2, x3, [x0, #32]
    
    ret

;------------------------------------------------------------------------------
; Validate camera state (for debugging)
;------------------------------------------------------------------------------
.globl _camera_validate_state
_camera_validate_state:
    ; Returns 0 if valid, error code otherwise
    adrp    x0, _camera_state@PAGE
    add     x0, x0, _camera_state@PAGEOFF
    
    ; Check for NaN/Inf in positions
    ldp     s0, s1, [x0, #8]        ; world_x, world_z
    ldr     s2, [x0, #16]           ; height
    
    ; Simple NaN check (NaN != NaN)
    fcmp    s0, s0
    b.ne    nan_detected
    fcmp    s1, s1
    b.ne    nan_detected
    fcmp    s2, s2
    b.ne    nan_detected
    
    ; Check bounds
    fmov    s3, #-10000.0
    fmov    s4, #10000.0
    fcmp    s0, s3
    b.lt    bounds_violation
    fcmp    s0, s4
    b.gt    bounds_violation
    fcmp    s1, s3
    b.lt    bounds_violation
    fcmp    s1, s4
    b.gt    bounds_violation
    
    ; Check height limits
    fmov    s3, #5.0
    fmov    s4, #1000.0
    fcmp    s2, s3
    b.lt    bounds_violation
    fcmp    s2, s4
    b.gt    bounds_violation
    
    ; Valid state
    mov     x0, #0
    ret
    
nan_detected:
    mov     x0, #ERR_MATH_NAN
    ret
    
bounds_violation:
    mov     x0, #ERR_PHYSICS_BOUNDS
    ret