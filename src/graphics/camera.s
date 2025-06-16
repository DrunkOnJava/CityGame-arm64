.global camera_init
.global camera_update
.global camera_screen_to_world
.global camera_world_to_screen
.global camera_set_target
.global camera_smooth_follow
.global camera_apply_momentum
.global camera_handle_input
.global camera_get_bounds
.global camera_is_visible

// Enhanced Camera structure offsets (compatible with isometric_transform.s)
.equ Camera_position_x, 0
.equ Camera_position_y, 4  
.equ Camera_position_z, 8
.equ Camera_target_x, 12
.equ Camera_target_y, 16
.equ Camera_target_z, 20
.equ Camera_up_x, 24
.equ Camera_up_y, 28
.equ Camera_up_z, 32
.equ Camera_zoom, 36
.equ Camera_target_zoom, 40
.equ Camera_rotation, 44
.equ Camera_target_rotation, 48
.equ Camera_velocity_x, 52
.equ Camera_velocity_y, 56
.equ Camera_momentum_decay, 60
.equ Camera_viewport_width, 64
.equ Camera_viewport_height, 68
.equ Camera_near_plane, 72
.equ Camera_far_plane, 76
.equ Camera_fov, 80
.equ Camera_projection_type, 84
.equ Camera_bounds_min_x, 88
.equ Camera_bounds_min_y, 92
.equ Camera_bounds_max_x, 96
.equ Camera_bounds_max_y, 100
.equ Camera_smooth_factor, 104
.equ Camera_proj_matrix, 108
.equ Camera_view_matrix, 172
.equ Camera_size, 236

.section __TEXT,__text
camera_init:
    // x0 = camera struct pointer
    // x1 = viewport width
    // x2 = viewport height
    
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Initialize position to isometric view above world center
    fmov s0, #15.0              // World center X
    fmov s1, #15.0              // World center Y  
    fmov s2, #20.0              // Height above world
    str s0, [x0, #Camera_position_x]
    str s1, [x0, #Camera_position_y]
    str s2, [x0, #Camera_position_z]
    
    // Initialize target (look at world center)
    str s0, [x0, #Camera_target_x]
    str s1, [x0, #Camera_target_y]
    fmov s2, #0.0
    str s2, [x0, #Camera_target_z]
    
    // Initialize up vector (Y-up)
    fmov s0, #0.0
    fmov s1, #1.0
    fmov s2, #0.0
    str s0, [x0, #Camera_up_x]
    str s1, [x0, #Camera_up_y]
    str s2, [x0, #Camera_up_z]
    
    // Default zoom and targets
    fmov s0, #1.0
    str s0, [x0, #Camera_zoom]
    str s0, [x0, #Camera_target_zoom]
    
    // No rotation
    fmov s0, #0.0
    str s0, [x0, #Camera_rotation]
    str s0, [x0, #Camera_target_rotation]
    
    // Initialize velocity and momentum
    fmov s0, #0.0
    str s0, [x0, #Camera_velocity_x]
    str s0, [x0, #Camera_velocity_y]
    fmov s0, #0.85              // Momentum decay factor
    str s0, [x0, #Camera_momentum_decay]
    
    // Store viewport
    str w1, [x0, #Camera_viewport_width]
    str w2, [x0, #Camera_viewport_height]
    
    // Set clipping planes
    fmov s0, #0.1
    str s0, [x0, #Camera_near_plane]
    fmov s0, #1000.0
    str s0, [x0, #Camera_far_plane]
    
    // Set camera bounds (world limits)
    fmov s0, #-10.0
    str s0, [x0, #Camera_bounds_min_x]
    str s0, [x0, #Camera_bounds_min_y]
    fmov s0, #40.0
    str s0, [x0, #Camera_bounds_max_x]
    str s0, [x0, #Camera_bounds_max_y]
    
    // Smooth interpolation factor
    fmov s0, #8.0
    str s0, [x0, #Camera_smooth_factor]
    
    // Set orthographic projection
    mov w3, #0
    strb w3, [x0, #Camera_projection_type]
    
    // Calculate initial matrices
    bl calculate_view_matrix
    bl calculate_projection_matrix
    
    ldp x29, x30, [sp], #16
    ret

camera_update:
    // x0 = camera struct
    // w1 = delta_x
    // w2 = delta_y
    // s0 = delta_zoom
    
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Update position
    ldr s1, [x0, #Camera_position_x]
    scvtf s2, w1
    fadd s1, s1, s2
    str s1, [x0, #Camera_position_x]
    
    ldr s1, [x0, #Camera_position_y]
    scvtf s2, w2
    fadd s1, s1, s2
    str s1, [x0, #Camera_position_y]
    
    // Update zoom
    ldr s1, [x0, #Camera_zoom]
    fadd s1, s1, s0
    
    // Clamp zoom between 0.25 and 4.0
    fmov s2, #0.25
    fmov s3, #4.0
    fmax s1, s1, s2
    fmin s1, s1, s3
    str s1, [x0, #Camera_zoom]
    
    // Recalculate matrices
    bl calculate_view_matrix
    bl calculate_projection_matrix
    
    ldp x29, x30, [sp], #16
    ret

camera_screen_to_world:
    // x0 = camera struct
    // w1 = screen_x
    // w2 = screen_y
    // Returns world coordinates in s0, s1
    
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Get viewport dimensions
    ldr w3, [x0, #Camera_viewport_width]
    ldr w4, [x0, #Camera_viewport_height]
    
    // Normalize to [-1, 1]
    scvtf s0, w1
    scvtf s1, w3
    fdiv s0, s0, s1
    fmov s2, #2.0
    fmul s0, s0, s2
    fmov s2, #1.0
    fsub s0, s0, s2
    
    scvtf s1, w2
    scvtf s2, w4
    fdiv s1, s1, s2
    fmov s2, #2.0
    fmul s1, s1, s2
    fmov s2, #1.0
    fsub s1, s1, s2
    fneg s1, s1  // Flip Y
    
    // Apply camera transform
    ldr s2, [x0, #Camera_zoom]
    fdiv s0, s0, s2
    fdiv s1, s1, s2
    
    ldr s2, [x0, #Camera_position_x]
    fadd s0, s0, s2
    ldr s2, [x0, #Camera_position_y]
    fadd s1, s1, s2
    
    ldp x29, x30, [sp], #16
    ret

camera_world_to_screen:
    // x0 = camera struct
    // s0 = world_x
    // s1 = world_y
    // Returns screen coordinates in w0, w1
    
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Apply camera transform
    ldr s2, [x0, #Camera_position_x]
    fsub s0, s0, s2
    ldr s2, [x0, #Camera_position_y]
    fsub s1, s1, s2
    
    ldr s2, [x0, #Camera_zoom]
    fmul s0, s0, s2
    fmul s1, s1, s2
    
    // Convert to screen coordinates
    ldr w2, [x0, #Camera_viewport_width]
    ldr w3, [x0, #Camera_viewport_height]
    
    // Map from [-1, 1] to screen
    fmov s2, #1.0
    fadd s0, s0, s2
    fmov s2, #0.5
    fmul s0, s0, s2
    scvtf s2, w2
    fmul s0, s0, s2
    fcvtzu w0, s0
    
    fneg s1, s1  // Flip Y back
    fmov s2, #1.0
    fadd s1, s1, s2
    fmov s2, #0.5
    fmul s1, s1, s2
    scvtf s2, w3
    fmul s1, s1, s2
    fcvtzu w1, s1
    
    ldp x29, x30, [sp], #16
    ret

calculate_view_matrix:
    // x0 = camera struct
    // Calculate view matrix based on position, zoom, rotation
    
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // For now, create identity matrix
    add x1, x0, #Camera_view_matrix
    
    // Clear matrix
    mov x2, #64
.clear_view:
    strb wzr, [x1], #1
    subs x2, x2, #1
    b.ne .clear_view
    
    // Set identity
    add x1, x0, #Camera_view_matrix
    fmov s0, #1.0
    str s0, [x1, #0]   // [0,0]
    str s0, [x1, #20]  // [1,1]
    str s0, [x1, #40]  // [2,2]
    str s0, [x1, #60]  // [3,3]
    
    ldp x29, x30, [sp], #16
    ret

calculate_projection_matrix:
    // x0 = camera struct
    // Calculate orthographic projection matrix
    
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    add x1, x0, #Camera_proj_matrix
    
    // Clear matrix
    mov x2, #64
.clear_proj:
    strb wzr, [x1], #1
    subs x2, x2, #1
    b.ne .clear_proj
    
    // Set orthographic projection
    add x1, x0, #Camera_proj_matrix
    
    // Get viewport dimensions
    ldr w2, [x0, #Camera_viewport_width]
    ldr w3, [x0, #Camera_viewport_height]
    
    // Calculate orthographic matrix
    scvtf s0, w2
    fmov s1, #2.0
    fdiv s0, s1, s0    // 2/width
    str s0, [x1, #0]   // [0,0]
    
    scvtf s0, w3
    fdiv s0, s1, s0    // 2/height
    str s0, [x1, #20]  // [1,1]
    
    fmov s0, #-1.0
    str s0, [x1, #40]  // [2,2] = -1 for depth
    
    fmov s0, #1.0
    str s0, [x1, #60]  // [3,3]
    
    ldp x29, x30, [sp], #16
    ret

//
// camera_set_target - Set camera target position for smooth following
// Input: x0 = camera struct, v0.3s = target position
// Output: None
// Modifies: v0
//
camera_set_target:
    str s0, [x0, #Camera_target_x]
    str s1, [x0, #Camera_target_y]
    str s2, [x0, #Camera_target_z]
    ret

//
// camera_smooth_follow - Update camera with smooth interpolation
// Input: x0 = camera struct, s0 = delta_time
// Output: None
// Modifies: v0-v7
//
camera_smooth_follow:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Load smooth factor and calculate lerp amount
    ldr s1, [x0, #Camera_smooth_factor]
    fmul s1, s1, s0                     // smooth_factor * delta_time
    fmov s2, #1.0
    fmin s1, s1, s2                     // Clamp to 1.0
    
    // Interpolate position towards target
    ldr s3, [x0, #Camera_position_x]
    ldr s4, [x0, #Camera_target_x]
    fsub s5, s4, s3                     // target - current
    fmadd s3, s5, s1, s3                // current + (diff * lerp)
    str s3, [x0, #Camera_position_x]
    
    ldr s3, [x0, #Camera_position_y]
    ldr s4, [x0, #Camera_target_y]
    fsub s5, s4, s3
    fmadd s3, s5, s1, s3
    str s3, [x0, #Camera_position_y]
    
    // Interpolate zoom
    ldr s3, [x0, #Camera_zoom]
    ldr s4, [x0, #Camera_target_zoom]
    fsub s5, s4, s3
    fmadd s3, s5, s1, s3
    
    // Clamp zoom between 0.25 and 4.0
    fmov s6, #0.25
    fmov s7, #4.0
    fmax s3, s3, s6
    fmin s3, s3, s7
    str s3, [x0, #Camera_zoom]
    
    // Interpolate rotation (with wrapping)
    ldr s3, [x0, #Camera_rotation]
    ldr s4, [x0, #Camera_target_rotation]
    fsub s5, s4, s3
    
    // Handle rotation wrapping
    fmov s6, #3.14159265
    fcmp s5, s6
    b.le .Lno_wrap_pos
    fsub s5, s5, #6.28318531           // Subtract 2*PI
.Lno_wrap_pos:
    fmov s6, #-3.14159265
    fcmp s5, s6
    b.ge .Lno_wrap_neg
    fadd s5, s5, #6.28318531           // Add 2*PI
.Lno_wrap_neg:
    
    fmadd s3, s5, s1, s3
    str s3, [x0, #Camera_rotation]
    
    // Apply bounds checking
    bl camera_apply_bounds
    
    // Recalculate matrices
    bl calculate_view_matrix
    bl calculate_projection_matrix
    
    ldp x29, x30, [sp], #16
    ret

//
// camera_apply_momentum - Apply momentum-based camera movement
// Input: x0 = camera struct, s0 = delta_time
// Output: None
// Modifies: v0-v3
//
camera_apply_momentum:
    // Load velocity
    ldr s1, [x0, #Camera_velocity_x]
    ldr s2, [x0, #Camera_velocity_y]
    
    // Apply velocity to position
    ldr s3, [x0, #Camera_position_x]
    fmadd s3, s1, s0, s3               // pos += velocity * delta_time
    str s3, [x0, #Camera_position_x]
    
    ldr s3, [x0, #Camera_position_y]
    fmadd s3, s2, s0, s3
    str s3, [x0, #Camera_position_y]
    
    // Apply momentum decay
    ldr s3, [x0, #Camera_momentum_decay]
    fmul s1, s1, s3                    // velocity *= decay_factor
    fmul s2, s2, s3
    str s1, [x0, #Camera_velocity_x]
    str s2, [x0, #Camera_velocity_y]
    
    ret

//
// camera_handle_input - Process camera input with momentum
// Input: x0 = camera struct, w1 = input_flags, v0.2s = mouse_delta, s2 = scroll_delta
// Output: None
// Modifies: v0-v4
//
camera_handle_input:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Check for drag input (bit 0)
    tbnz w1, #0, .Lhandle_drag
    
    // Check for zoom input (bit 1)  
    tbnz w1, #1, .Lhandle_zoom
    
    b .Linput_done
    
.Lhandle_drag:
    // Convert mouse delta to world movement
    ldr s3, [x0, #Camera_zoom]
    fdiv s4, #1.0, s3                  // Inverse zoom for sensitivity
    
    fmul v0.2s, v0.2s, v4.s[0]        // Scale by inverse zoom
    
    // Add to velocity for momentum
    ldr s5, [x0, #Camera_velocity_x]
    ldr s6, [x0, #Camera_velocity_y]
    fadd s5, s5, v0.s[0]
    fadd s6, s6, v0.s[1]
    str s5, [x0, #Camera_velocity_x]
    str s6, [x0, #Camera_velocity_y]
    
    b .Linput_done
    
.Lhandle_zoom:
    // Update target zoom
    ldr s3, [x0, #Camera_target_zoom]
    fmov s4, #0.1                      // Zoom sensitivity
    fmadd s3, s2, s4, s3               // target_zoom += scroll * sensitivity
    
    // Clamp zoom
    fmov s5, #0.25
    fmov s6, #4.0
    fmax s3, s3, s5
    fmin s3, s3, s6
    str s3, [x0, #Camera_target_zoom]
    
.Linput_done:
    ldp x29, x30, [sp], #16
    ret

//
// camera_apply_bounds - Apply world bounds to camera position
// Input: x0 = camera struct
// Output: None
// Modifies: v0-v3
//
camera_apply_bounds:
    // Load bounds
    ldr s0, [x0, #Camera_bounds_min_x]
    ldr s1, [x0, #Camera_bounds_max_x]
    ldr s2, [x0, #Camera_bounds_min_y]
    ldr s3, [x0, #Camera_bounds_max_y]
    
    // Clamp X position
    ldr s4, [x0, #Camera_position_x]
    fmax s4, s4, s0
    fmin s4, s4, s1
    str s4, [x0, #Camera_position_x]
    
    // Clamp Y position
    ldr s4, [x0, #Camera_position_y]
    fmax s4, s4, s2
    fmin s4, s4, s3
    str s4, [x0, #Camera_position_y]
    
    ret

//
// camera_get_bounds - Get camera view bounds in world space
// Input: x0 = camera struct, x1 = output bounds (float[4])
// Output: bounds in format [min_x, min_y, max_x, max_y]
// Modifies: v0-v4
//
camera_get_bounds:
    // Load camera position and zoom
    ldr s0, [x0, #Camera_position_x]
    ldr s1, [x0, #Camera_position_y]
    ldr s2, [x0, #Camera_zoom]
    
    // Load viewport dimensions
    ldr w3, [x0, #Camera_viewport_width]
    ldr w4, [x0, #Camera_viewport_height]
    
    // Calculate view size in world units
    scvtf s3, w3
    scvtf s4, w4
    fdiv s3, s3, s2                    // world_width = screen_width / zoom
    fdiv s4, s4, s2                    // world_height = screen_height / zoom
    
    fmov s5, #0.5
    fmul s3, s3, s5                    // half_width
    fmul s4, s4, s5                    // half_height
    
    // Calculate bounds
    fsub s6, s0, s3                    // min_x = pos_x - half_width
    fadd s7, s0, s3                    // max_x = pos_x + half_width
    fsub s8, s1, s4                    // min_y = pos_y - half_height
    fadd s9, s1, s4                    // max_y = pos_y + half_height
    
    // Store bounds
    str s6, [x1, #0]                   // min_x
    str s8, [x1, #4]                   // min_y
    str s7, [x1, #8]                   // max_x
    str s9, [x1, #12]                  // max_y
    
    ret

//
// camera_is_visible - Test if world position is visible in camera view
// Input: x0 = camera struct, v0.3s = world position
// Output: w0 = 1 if visible, 0 if not
// Modifies: v0-v4, x1-x2
//
camera_is_visible:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    
    // Get camera bounds
    add x1, sp, #16                    // Use stack space for bounds
    bl camera_get_bounds
    
    // Load bounds
    add x1, sp, #16
    ld1 {v1.4s}, [x1]                 // [min_x, min_y, max_x, max_y]
    
    // Test if position is within bounds
    fcmp s0, v1.s[0]                   // pos.x >= min_x
    b.lt .Lnot_visible
    fcmp s0, v1.s[2]                   // pos.x <= max_x
    b.gt .Lnot_visible
    fcmp v0.s[1], v1.s[1]              // pos.y >= min_y
    b.lt .Lnot_visible
    fcmp v0.s[1], v1.s[3]              // pos.y <= max_y
    b.gt .Lnot_visible
    
    mov w0, #1                         // Visible
    b .Lvisibility_done
    
.Lnot_visible:
    mov w0, #0                         // Not visible
    
.Lvisibility_done:
    ldp x29, x30, [sp], #32
    ret

.section __DATA,__bss
.global main_camera
main_camera:
    .space Camera_size  // Enhanced camera struct size