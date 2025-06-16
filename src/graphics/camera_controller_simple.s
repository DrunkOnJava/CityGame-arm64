;------------------------------------------------------------------------------
; camera_controller_simple.s - Simplified version for Apple assembler
;------------------------------------------------------------------------------

.ifdef DEBUG_BUILD
.include "../include/debug_constants.inc"
.include "camera_debug_macros.s"
.endif

.section __DATA,__data
.align 6

; Global camera state
.globl _camera_state
_camera_state:
    .float  0.0, 0.0        ; iso_x, iso_y  
    .float  50.0, 50.0      ; world_x, world_z
    .float  100.0           ; height
    .float  0.0             ; rotation
    .float  0.0, 0.0        ; vel_x, vel_z
    .float  0.0             ; zoom_vel  
    .float  0.0             ; rot_vel
    .float  0.0, 0.0        ; edge_pan_x, edge_pan_z
    .word   0               ; bounce_timer
    .word   0, 0, 0         ; padding

.globl _camera_view_matrix
_camera_view_matrix:
    .float  1.0, 0.0, 0.0, 0.0
    .float  0.0, 1.0, 0.0, 0.0
    .float  0.0, 0.0, 1.0, 0.0
    .float  0.0, 0.0, 0.0, 1.0

.section __TEXT,__text,regular,pure_instructions
.align 2

;------------------------------------------------------------------------------
; Main camera update - simplified for testing
; X0 = pointer to input buffer, S0 = delta time
;------------------------------------------------------------------------------
.globl _camera_update
_camera_update:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     d8, d9, [sp, #32]
    mov     x29, sp
    
    ; Load camera state pointer
    adrp    x19, _camera_state@PAGE
    add     x19, x19, _camera_state@PAGEOFF
    
    ; Save inputs
    mov     x20, x0
    fmov    s31, s0
    
    ; Process keyboard movement
    ldr     w0, [x20, #0]           ; Load key mask
    
    ; Initialize movement scalars (not vector)
    fmov    s4, #0.0                ; X movement
    fmov    s5, #0.0                ; Z movement
    
    ; Check arrow keys
    ; Forward movement (Up arrow) - move in +Z
    tst     w0, #1                  ; Up key (bit 0)
    b.eq    1f
    fmov    s5, #1.0                ; +Z movement
1:
    ; Backward movement (Down arrow) - move in -Z
    tst     w0, #2                  ; Down key (bit 1)
    b.eq    2f
    fmov    s5, #-1.0               ; -Z movement
2:
    ; Left movement (Left arrow) - move in -X
    tst     w0, #4                  ; Left key (bit 2)
    b.eq    3f
    fmov    s4, #-1.0               ; -X movement
3:
    ; Right movement (Right arrow) - move in +X
    tst     w0, #8                  ; Right key (bit 3)
    b.eq    4f
    fmov    s4, #1.0                ; +X movement
4:
    
    ; Apply speed
    fmov    s1, #20.0               ; Base speed
    
    ; Check shift for speed boost
    tst     w0, #16                 ; Shift key (bit 4)
    b.eq    5f
    fmov    s2, #2.5                ; Speed multiplier
    fmul    s1, s1, s2
5:
    ; Scale movement by speed
    fmul    s4, s4, s1              ; Scale X movement
    fmul    s5, s5, s1              ; Scale Z movement
    
    ; Update velocity with acceleration
    ldp     s1, s2, [x19, #24]      ; Load current velocity (vel_x, vel_z)
    fmov    s3, #2.0                ; Acceleration factor
    fmul    s3, s3, s31             ; Scale by delta time
    
    ; Apply acceleration to velocity
    fmadd   s1, s4, s3, s1          ; vel_x += move_x * accel * dt
    fmadd   s2, s5, s3, s2          ; vel_z += move_z * accel * dt
    stp     s1, s2, [x19, #24]      ; Store updated velocity
    
    ; Apply friction
    ldr     x0, =0x3f666666         ; 0.9 in hex
    fmov    s3, w0
    fmul    s1, s1, s3
    fmul    s2, s2, s3
    stp     s1, s2, [x19, #24]
    
    ; Update position
    ldp     s3, s4, [x19, #8]       ; Load position
    fmadd   s3, s1, s31, s3
    fmadd   s4, s2, s31, s4
    stp     s3, s4, [x19, #8]
    
    ; Process mouse wheel zoom
    ldrsh   w0, [x20, #0x24]
    cbz     w0, 5f
    
    scvtf   s0, w0
    ldr     s1, [x19, #16]          ; Height
    ldr     x2, =0x3dcccccd         ; 0.1 in hex
    fmov    s2, w2
    fmul    s0, s0, s2
    fadd    s1, s1, s0
    
    ; Clamp height
    ldr     x2, =0x40a00000         ; 5.0
    ldr     x3, =0x447a0000         ; 1000.0
    fmov    s2, w2
    fmov    s3, w3
    fmax    s1, s1, s2
    fmin    s1, s1, s3
    str     s1, [x19, #16]
5:
    
    ; Process mouse drag panning
    ldr     w0, [x20, #0x20]        ; mouse_buttons
    tst     w0, #1                  ; Left button
    b.eq    6f
    
    ; Get mouse deltas
    ldp     w1, w2, [x20, #0x18]    ; mouse_delta_x, mouse_delta_y
    cbz     w1, 6f
    cbz     w2, 6f
    
    ; Convert to float and scale
    scvtf   s0, w1
    scvtf   s1, w2
    fmov    s2, #0.5                ; Pan sensitivity
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    
    ; Apply to position directly
    ldp     s3, s4, [x19, #8]       ; Load world position
    fsub    s3, s3, s0              ; Pan X (inverted)
    fadd    s4, s4, s1              ; Pan Z
    stp     s3, s4, [x19, #8]       ; Store back
6:
    
    ; Update view matrix (simplified)
    bl      update_simple_matrix
    
    ; Restore and return
    ldp     d8, d9, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

;------------------------------------------------------------------------------
; Simple matrix update
;------------------------------------------------------------------------------
update_simple_matrix:
    adrp    x0, _camera_view_matrix@PAGE
    add     x0, x0, _camera_view_matrix@PAGEOFF
    
    ; Create simple translation matrix
    ldp     s0, s1, [x19, #8]       ; world_x, world_z
    ldr     s2, [x19, #16]          ; height
    
    ; Negate for view matrix
    fneg    s0, s0
    fneg    s1, s1
    fneg    s2, s2
    
    ; Store translation in matrix
    str     s0, [x0, #12]
    str     s1, [x0, #28]
    str     s2, [x0, #44]
    
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