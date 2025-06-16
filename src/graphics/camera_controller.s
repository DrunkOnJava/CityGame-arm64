;------------------------------------------------------------------------------
; MODULE:    camera_controller.s
; ARCH:      AArch64 (Apple Silicon)
; DEPS:      metal_encoder.s, isometric_transform.s, input_handler.s
; PURPOSE:   NEON-accelerated isometric camera with smooth navigation
;------------------------------------------------------------------------------

; .include "../platform/syscalls.inc"

.section __DATA,__data
.align 6                    ; 64-byte cache line alignment

; Global camera state (persistent across frames)
.globl _camera_state
_camera_state:
    .float  0.0, 0.0        ; iso_x, iso_y - Isometric screen position  
    .float  50.0, 50.0      ; world_x, world_z - World grid position
    .float  100.0           ; height - Camera height (5-1000 units)
    .float  0.0             ; rotation - Y-axis rotation (0-360°)
    .float  0.0, 0.0        ; vel_x, vel_z - World velocity
    .float  0.0             ; zoom_vel - Zoom velocity  
    .float  0.0             ; rot_vel - Rotation velocity
    .float  0.0, 0.0        ; edge_pan_x, edge_pan_z - Edge panning
    .word   0               ; bounce_timer - Elastic bounce animation
    .word   0, 0, 0         ; padding to 64 bytes

; View matrix for renderer (4x4)
.globl _camera_view_matrix
_camera_view_matrix:
    .float  1.0, 0.0, 0.0, 0.0
    .float  0.0, 1.0, 0.0, 0.0
    .float  0.0, 0.0, 1.0, 0.0
    .float  0.0, 0.0, 0.0, 1.0

; Input state buffer offsets
.equ    INPUT_KEYS,             0x00
.equ    INPUT_MOUSE_X,          0x10
.equ    INPUT_MOUSE_Y,          0x14
.equ    INPUT_MOUSE_DELTA_X,    0x18
.equ    INPUT_MOUSE_DELTA_Y,    0x1C
.equ    INPUT_MOUSE_BUTTONS,    0x20
.equ    INPUT_SCROLL_Y,         0x24

; Key bit positions
.equ    KEY_UP,                 0
.equ    KEY_DOWN,               1
.equ    KEY_LEFT,               2
.equ    KEY_RIGHT,              3
.equ    KEY_SHIFT,              4
.equ    KEY_W,                  5
.equ    KEY_A,                  6
.equ    KEY_S,                  7
.equ    KEY_D,                  8

; Camera constants
.equ    MIN_HEIGHT,             5       ; In float representation
.equ    MAX_HEIGHT,             1000
.equ    BASE_SPEED,             20
.equ    ACCEL_TIME,             30      ; 0.5s at 60fps
.equ    DECEL_TIME,             18      ; 0.3s at 60fps
.equ    EDGE_THRESHOLD,         15
.equ    BOUNCE_DURATION,        18      ; 0.3s at 60fps
.equ    ROTATION_SPEED,         15      ; degrees/second

.section __TEXT,__text,regular,pure_instructions
.align 2

;------------------------------------------------------------------------------
; Main camera update routine (called at 60Hz)
; X0 = pointer to input buffer
; X1 = delta time (float)
;------------------------------------------------------------------------------
.globl _camera_update
_camera_update:
    ; Save callee-saved registers and setup frame
    stp     x29, x30, [sp, #-96]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     d8, d9, [sp, #48]
    stp     d10, d11, [sp, #64]
    stp     d12, d13, [sp, #80]
    mov     x29, sp
    
    ; Load camera state pointer
    adrp    x19, _camera_state@PAGE
    add     x19, x19, _camera_state@PAGEOFF
    
    ; Save input buffer and delta time
    mov     x20, x0
    fmov    s31, s0                     ; Delta time in s31
    
    ; Process keyboard input
    bl      process_keyboard_input
    
    ; Process mouse input
    bl      process_mouse_input
    
    ; Update physics
    bl      update_camera_physics
    
    ; Apply constraints
    bl      apply_camera_constraints
    
    ; Update view matrix
    bl      update_view_matrix
    
    ; Restore registers and return
    ldp     d12, d13, [sp, #80]
    ldp     d10, d11, [sp, #64]
    ldp     d8, d9, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

;------------------------------------------------------------------------------
; Process keyboard input for movement
;------------------------------------------------------------------------------
process_keyboard_input:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    ; Load keyboard state
    ldr     w0, [x20, #INPUT_KEYS]
    
    ; Initialize movement vector in v0 (x,z)
    movi    v0.2s, #0
    
    ; Check arrow keys / WASD
    tst     w0, #(1 << KEY_UP)
    b.eq    1f
    fmov    s1, #1.0
    mov     v0.s[1], v1.s[0]            ; Move forward (+Z)
1:
    tst     w0, #(1 << KEY_DOWN)
    b.eq    2f
    fmov    s1, #-1.0
    mov     v0.s[1], v1.s[0]            ; Move backward (-Z)
2:
    tst     w0, #(1 << KEY_LEFT)
    b.eq    3f
    fmov    s1, #-1.0
    mov     v0.s[0], v1.s[0]            ; Move left (-X)
3:
    tst     w0, #(1 << KEY_RIGHT)
    b.eq    4f
    fmov    s1, #1.0
    mov     v0.s[0], v1.s[0]            ; Move right (+X)
4:
    
    ; Check WASD keys (additive with arrows)
    tst     w0, #(1 << KEY_W)
    b.eq    5f
    fmov    s1, #1.0
    fadd    s2, s0, s1
    mov     v0.s[1], v2.s[0]
5:
    tst     w0, #(1 << KEY_S)
    b.eq    6f
    fmov    s1, #-1.0
    fadd    s2, s0, s1
    mov     v0.s[1], v2.s[0]
6:
    tst     w0, #(1 << KEY_A)
    b.eq    7f
    fmov    s1, #-1.0
    fadd    s2, s0, s1
    mov     v0.s[0], v2.s[0]
7:
    tst     w0, #(1 << KEY_D)
    b.eq    8f
    fmov    s1, #1.0
    fadd    s2, s0, s1
    mov     v0.s[0], v2.s[0]
8:
    
    ; Normalize movement vector if diagonal
    fmul    v1.2s, v0.2s, v0.2s         ; Square components
    faddp   s1, v1.2s                   ; Sum squares
    fsqrt   s1, s1                      ; Magnitude
    fcmp    s1, #0.0
    b.eq    9f
    
    ; Divide by magnitude to normalize
    fmov    s2, #1.0
    fdiv    s2, s2, s1
    fmul    v0.2s, v0.2s, v2.s[0]
9:
    
    ; Check shift for speed boost
    tst     w0, #(1 << KEY_SHIFT)
    b.eq    10f
    fmov    s1, #2.5
    fmul    v0.2s, v0.2s, v1.s[0]
10:
    
    ; Apply base speed
    fmov    s1, #BASE_SPEED
    fmul    v0.2s, v0.2s, v1.s[0]
    
    ; Apply acceleration to velocity
    ld1     {v1.2s}, [x19, #24]         ; Load current velocity
    fmov    s2, #2.0                    ; Acceleration rate (1/0.5s)
    fmul    s2, s2, s31                 ; Scale by delta time
    fmla    v1.2s, v0.2s, v2.s[0]       ; vel += input * accel * dt
    st1     {v1.2s}, [x19, #24]         ; Store velocity
    
    ; Handle rotation with Shift+Left/Right
    tst     w0, #(1 << KEY_SHIFT)
    b.eq    11f
    
    ; Check for rotation keys
    mov     w1, #0
    tst     w0, #(1 << KEY_LEFT)
    b.eq    12f
    mov     w1, #-1                     ; Rotate left
12:
    tst     w0, #(1 << KEY_RIGHT)
    b.eq    11f
    mov     w1, #1                      ; Rotate right
    
    ; Apply rotation
    scvtf   s0, w1
    fmov    s1, #ROTATION_SPEED
    fmul    s0, s0, s1
    fmul    s0, s0, s31                 ; degrees * dt
    ldr     s1, [x19, #20]              ; Current rotation
    fadd    s1, s1, s0
    str     s1, [x19, #20]
11:
    
    ldp     x29, x30, [sp], #16
    ret

;------------------------------------------------------------------------------
; Process mouse input (wheel zoom, edge pan, drag)
;------------------------------------------------------------------------------
process_mouse_input:
    stp     x29, x30, [sp, #-32]!
    stp     x21, x22, [sp, #16]
    mov     x29, sp
    
    ; Process scroll wheel zoom
    ldrsh   w0, [x20, #INPUT_SCROLL_Y]
    cbz     w0, 1f
    
    ; Calculate zoom factor: 1.15^scroll
    scvtf   s0, w0
    fmov    s1, #1.15
    bl      fast_pow_approx             ; Result in s0
    
    ; Apply to height
    ldr     s1, [x19, #16]              ; Current height
    fmul    s1, s1, s0
    str     s1, [x19, #16]
1:
    
    ; Check for mouse drag
    ldrb    w0, [x20, #INPUT_MOUSE_BUTTONS]
    tst     w0, #1                      ; Left button
    b.eq    2f
    
    ; Get mouse delta
    ldp     w1, w2, [x20, #INPUT_MOUSE_DELTA_X]
    scvtf   s0, w1
    scvtf   s1, w2
    
    ; Convert screen delta to world movement
    ; For isometric: world_x = (screen_x + 2*screen_y) / (2 * scale)
    ;               world_z = (2*screen_y - screen_x) / (2 * scale)
    fmov    s2, #0.5
    fmul    s3, s1, #2.0                ; 2 * screen_y
    
    fadd    s4, s0, s3                  ; screen_x + 2*screen_y
    fmul    s4, s4, s2                  ; / 2
    
    fsub    s5, s3, s0                  ; 2*screen_y - screen_x
    fmul    s5, s5, s2                  ; / 2
    
    ; Apply to position (inverted for drag feel)
    ldr     s6, [x19, #8]               ; world_x
    ldr     s7, [x19, #12]              ; world_z
    fsub    s6, s6, s4
    fsub    s7, s7, s5
    str     s6, [x19, #8]
    str     s7, [x19, #12]
2:
    
    ; Check for right-click orbital rotation
    tst     w0, #2                      ; Right button
    b.eq    3f
    
    ; Get mouse delta for rotation
    ldr     w1, [x20, #INPUT_MOUSE_DELTA_X]
    scvtf   s0, w1
    fmov    s1, #0.25                   ; 0.25 degrees per pixel
    fmul    s0, s0, s1
    
    ldr     s1, [x19, #20]              ; Current rotation
    fadd    s1, s1, s0
    str     s1, [x19, #20]
3:
    
    ; Edge panning
    ldp     w1, w2, [x20, #INPUT_MOUSE_X]  ; Mouse X,Y
    
    ; Get window dimensions (hardcoded for now)
    mov     w3, #1920                   ; Window width
    mov     w4, #1080                   ; Window height
    
    ; Check edges
    movi    v0.2s, #0                   ; Edge pan vector
    
    ; Right edge
    sub     w5, w3, w1
    cmp     w5, #EDGE_THRESHOLD
    b.gt    4f
    sub     w5, #EDGE_THRESHOLD, w5
    scvtf   s1, w5
    fmov    s2, #1.0
    fdiv    s1, s1, #EDGE_THRESHOLD
    fmul    s1, s1, s2
    mov     v0.s[0], v1.s[0]
4:
    
    ; Left edge  
    cmp     w1, #EDGE_THRESHOLD
    b.gt    5f
    sub     w5, #EDGE_THRESHOLD, w1
    scvtf   s1, w5
    fmov    s2, #-1.0
    fdiv    s1, s1, #EDGE_THRESHOLD
    fmul    s1, s1, s2
    mov     v0.s[0], v1.s[0]
5:
    
    ; Bottom edge
    sub     w5, w4, w2
    cmp     w5, #EDGE_THRESHOLD
    b.gt    6f
    sub     w5, #EDGE_THRESHOLD, w5
    scvtf   s1, w5
    fmov    s2, #1.0
    fdiv    s1, s1, #EDGE_THRESHOLD
    fmul    s1, s1, s2
    mov     v0.s[1], v1.s[0]
6:
    
    ; Top edge
    cmp     w2, #EDGE_THRESHOLD
    b.gt    7f
    sub     w5, #EDGE_THRESHOLD, w2
    scvtf   s1, w5
    fmov    s2, #-1.0
    fdiv    s1, s1, #EDGE_THRESHOLD
    fmul    s1, s1, s2
    mov     v0.s[1], v1.s[0]
7:
    
    ; Apply edge panning to velocity
    fmov    s1, #10.0                   ; Edge pan speed
    fmul    v0.2s, v0.2s, v1.s[0]
    ld1     {v1.2s}, [x19, #24]         ; Current velocity
    fadd    v1.2s, v1.2s, v0.2s
    st1     {v1.2s}, [x19, #24]
    
    ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

;------------------------------------------------------------------------------
; Update camera physics (velocity, position, deceleration)
;------------------------------------------------------------------------------
update_camera_physics:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    ; Load current state
    ld1     {v0.2s}, [x19, #8]          ; Position (world_x, world_z)
    ld1     {v1.2s}, [x19, #24]         ; Velocity
    
    ; Apply deceleration
    fmov    s2, #3.333                  ; 1/0.3s decel rate
    fmul    s2, s2, s31                 ; Scale by delta time
    fmov    s3, #1.0
    fsub    s3, s3, s2                  ; Decay factor
    
    ; Apply friction to velocity
    fmul    v1.2s, v1.2s, v3.s[0]
    
    ; Update position
    fmla    v0.2s, v1.2s, v31.s[0]      ; pos += vel * dt
    
    ; Store updated state
    st1     {v0.2s}, [x19, #8]          ; Position
    st1     {v1.2s}, [x19, #24]         ; Velocity
    
    ; Update zoom velocity
    ldr     s0, [x19, #32]              ; zoom_vel
    fmul    s0, s0, s3                  ; Apply friction
    str     s0, [x19, #32]
    
    ; Apply zoom velocity to height
    ldr     s1, [x19, #16]              ; height
    fmla    s1, s0, s31                 ; height += zoom_vel * dt
    str     s1, [x19, #16]
    
    ldp     x29, x30, [sp], #16
    ret

;------------------------------------------------------------------------------
; Apply camera constraints (bounds, height limits, elastic bounce)
;------------------------------------------------------------------------------
apply_camera_constraints:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    ; Constrain world position to map bounds (0-100)
    ld1     {v0.2s}, [x19, #8]          ; Position
    fmov    s1, #0.0
    fmov    s2, #100.0
    fmax    v0.2s, v0.2s, v1.s[0]       ; Max with 0
    fmin    v0.2s, v0.2s, v2.s[0]       ; Min with 100
    st1     {v0.2s}, [x19, #8]
    
    ; Constrain height with elastic bounce
    ldr     s0, [x19, #16]              ; height
    ldr     w0, [x19, #48]              ; bounce_timer
    
    fmov    s1, #5.0                    ; MIN_HEIGHT
    fcmp    s0, s1
    b.ge    1f
    
    ; Below minimum - start bounce
    cbnz    w0, 2f                      ; Already bouncing?
    mov     w0, #BOUNCE_DURATION
    str     w0, [x19, #48]
    b       2f
1:
    fmov    s1, #1000.0                 ; MAX_HEIGHT
    fcmp    s0, s1
    b.le    3f
    
    ; Above maximum - start bounce
    cbnz    w0, 2f
    mov     w0, #BOUNCE_DURATION
    str     w0, [x19, #48]
2:
    ; Apply bounce animation
    cbz     w0, 3f
    
    ; Calculate ease-out: t = 1 - (timer/duration)²
    scvtf   s2, w0
    fmov    s3, #BOUNCE_DURATION
    fdiv    s2, s2, s3                  ; Normalized time
    fmov    s3, #1.0
    fsub    s2, s3, s2                  ; 1 - t
    fmul    s2, s2, s2                  ; (1-t)²
    fsub    s2, s3, s2                  ; 1 - (1-t)²
    
    ; Interpolate back to limit
    fcmp    s0, #5.0
    b.ge    4f
    fmov    s1, #5.0
    b       5f
4:
    fmov    s1, #1000.0
5:
    fsub    s3, s1, s0                  ; Distance to limit
    fmul    s3, s3, s2                  ; Scale by curve
    fadd    s0, s0, s3                  ; Apply correction
    
    ; Decrement timer
    sub     w0, w0, #1
    str     w0, [x19, #48]
3:
    ; Clamp height to valid range
    fmov    s1, #5.0
    fmov    s2, #1000.0
    fmax    s0, s0, s1
    fmin    s0, s0, s2
    str     s0, [x19, #16]
    
    ; Wrap rotation to 0-360
    ldr     s0, [x19, #20]
    fmov    s1, #360.0
    fcmp    s0, s1
    b.lt    6f
    fsub    s0, s0, s1
6:
    fcmp    s0, #0.0
    b.ge    7f
    fadd    s0, s0, s1
7:
    str     s0, [x19, #20]
    
    ldp     x29, x30, [sp], #16
    ret

;------------------------------------------------------------------------------
; Update view matrix for renderer
;------------------------------------------------------------------------------
update_view_matrix:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    ; Load camera state
    ld1     {v0.2s}, [x19, #8]          ; world_x, world_z
    ldr     s1, [x19, #16]              ; height
    ldr     s2, [x19, #20]              ; rotation
    
    ; Convert world position to isometric screen coordinates
    ; iso_x = (world_x - world_z) * cos(30°)
    ; iso_y = (world_x + world_z) * sin(30°) - height
    
    fmov    s3, #0.866                  ; cos(30°)
    fmov    s4, #0.5                    ; sin(30°)
    
    ; Calculate iso_x
    fsub    s5, s0, v0.s[1]             ; world_x - world_z
    fmul    s5, s5, s3                  ; * cos(30°)
    str     s5, [x19, #0]               ; Store iso_x
    
    ; Calculate iso_y
    fadd    s6, s0, v0.s[1]             ; world_x + world_z
    fmul    s6, s6, s4                  ; * sin(30°)
    fsub    s6, s6, s1                  ; - height
    str     s6, [x19, #4]               ; Store iso_y
    
    ; Build 4x4 view matrix
    adrp    x0, _camera_view_matrix@PAGE
    add     x0, x0, _camera_view_matrix@PAGEOFF
    
    ; Identity matrix
    fmov    s7, #1.0
    fmov    s8, #0.0
    
    ; Row 0: [cos30, 0, -sin30, -iso_x]
    str     s3, [x0, #0]                ; cos(30°)
    str     s8, [x0, #4]                ; 0
    fneg    s9, s4
    str     s9, [x0, #8]                ; -sin(30°)
    fneg    s5, s5
    str     s5, [x0, #12]               ; -iso_x
    
    ; Row 1: [sin30*sin60, cos60, cos30*sin60, -iso_y]
    fmov    s9, #0.433                  ; sin(30°)*sin(60°)
    str     s9, [x0, #16]
    fmov    s9, #0.5                    ; cos(60°)
    str     s9, [x0, #20]
    fmov    s9, #0.75                   ; cos(30°)*sin(60°)
    str     s9, [x0, #24]
    fneg    s6, s6
    str     s6, [x0, #28]               ; -iso_y
    
    ; Row 2: [sin30*cos60, -sin60, cos30*cos60, -height]
    fmov    s9, #0.25                   ; sin(30°)*cos(60°)
    str     s9, [x0, #32]
    fmov    s9, #-0.866                 ; -sin(60°)
    str     s9, [x0, #36]
    fmov    s9, #0.433                  ; cos(30°)*cos(60°)
    str     s9, [x0, #40]
    fneg    s1, s1
    str     s1, [x0, #44]               ; -height
    
    ; Row 3: [0, 0, 0, 1]
    str     s8, [x0, #48]
    str     s8, [x0, #52]
    str     s8, [x0, #56]
    str     s7, [x0, #60]
    
    ldp     x29, x30, [sp], #16
    ret

;------------------------------------------------------------------------------
; Fast power approximation for zoom (1.15^x)
; Input: s0 = exponent
; Output: s0 = result
;------------------------------------------------------------------------------
fast_pow_approx:
    ; For small x: 1.15^x ≈ 1 + 0.1398x + 0.0098x²
    fmov    s1, s0                      ; Save x
    fmul    s2, s0, s0                  ; x²
    
    fmov    s3, #0.1398
    fmov    s4, #0.0098
    
    fmul    s0, s0, s3                  ; 0.1398x
    fmla    s0, s2, s4                  ; + 0.0098x²
    fmov    s2, #1.0
    fadd    s0, s0, s2                  ; 1 + ...
    
    ret

;------------------------------------------------------------------------------
; Get current camera position in world coordinates
; Output: s0 = world_x, s1 = world_z, s2 = height
;------------------------------------------------------------------------------
.globl _camera_get_world_position
_camera_get_world_position:
    adrp    x0, _camera_state@PAGE
    add     x0, x0, _camera_state@PAGEOFF
    
    ldr     s0, [x0, #8]                ; world_x
    ldr     s1, [x0, #12]               ; world_z  
    ldr     s2, [x0, #16]               ; height
    
    ret

;------------------------------------------------------------------------------
; Convert screen coordinates to world coordinates
; Input: s0 = screen_x, s1 = screen_y
; Output: s0 = world_x, s1 = world_z
;------------------------------------------------------------------------------
.globl _camera_screen_to_world
_camera_screen_to_world:
    adrp    x1, _camera_state@PAGE
    add     x1, x1, _camera_state@PAGEOFF
    
    ; Get camera offset
    ldr     s2, [x1, #0]                ; iso_x
    ldr     s3, [x1, #4]                ; iso_y
    
    ; Adjust for camera position
    fadd    s0, s0, s2
    fadd    s1, s1, s3
    
    ; Inverse isometric transform
    ; world_x = (screen_x/(2*cos30) + screen_y/(2*sin30))
    ; world_z = (screen_y/(2*sin30) - screen_x/(2*cos30))
    
    fmov    s4, #0.5773                 ; 1/(2*cos(30°))
    fmov    s5, #1.0                    ; 1/(2*sin(30°))
    
    fmul    s6, s0, s4                  ; screen_x/(2*cos30)
    fmul    s7, s1, s5                  ; screen_y/(2*sin30)
    
    fadd    s0, s6, s7                  ; world_x
    fsub    s1, s7, s6                  ; world_z
    
    ret

;------------------------------------------------------------------------------
; Get visible world bounds for culling
; Output: s0-s3 = min_x, min_z, max_x, max_z
;------------------------------------------------------------------------------
.globl _camera_get_visible_bounds
_camera_get_visible_bounds:
    adrp    x0, _camera_state@PAGE
    add     x0, x0, _camera_state@PAGEOFF
    
    ; Get camera position
    ldr     s0, [x0, #8]                ; world_x
    ldr     s1, [x0, #12]               ; world_z
    ldr     s2, [x0, #16]               ; height
    
    ; Calculate visible radius based on height
    fmov    s3, #0.02                   ; Height to radius factor
    fmul    s3, s2, s3
    
    ; Return bounds
    fsub    s4, s0, s3                  ; min_x
    fsub    s5, s1, s3                  ; min_z
    fadd    s6, s0, s3                  ; max_x
    fadd    s7, s1, s3                  ; max_z
    
    fmov    s0, s4
    fmov    s1, s5
    fmov    s2, s6
    fmov    s3, s7
    
    ret

.section __DATA,__const
.align 3

; Include file for syscall numbers
; .include "../platform/syscalls.inc"