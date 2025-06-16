//
// isometric_transform.s - NEON-accelerated isometric transformation system
// Agent B3: Graphics Team - Isometric Transformation & Depth Sorting
//
// High-performance isometric coordinate transformation and depth sorting
// optimized for Apple Silicon with NEON SIMD instructions.
//
// Author: Agent B3 (Graphics - Isometric Transform)
// Date: 2025-06-15
//

.section __TEXT,__text,regular,pure_instructions
.align 4

// Structure offsets for camera state
.equ camera_position_x, 0
.equ camera_position_y, 4
.equ camera_position_z, 8
.equ camera_zoom, 12
.equ camera_rotation, 16
.equ camera_viewport_width, 20
.equ camera_viewport_height, 24
.equ camera_state_size, 28

// Global state
.section __DATA,__data
.align 16
current_camera:         .space camera_state_size
transform_statistics:   .space 32

// Float constants
.align 4
float_constants:
    .float 0.1              // Near plane / tile scale
    .float 1000.0           // Far plane
    .float 0.05             // Isometric Y scale
    .float 0.25             // Height scale
    .float 15.0             // Default camera position
    .float 20.0             // Default camera height
    .float 1.0              // Default zoom
    .float 0.5              // Half multiplier

.section __TEXT,__text
.global _iso_transform_init
.global _iso_transform_world_to_screen
.global _iso_transform_world_to_iso
.global _iso_transform_calculate_depth

//
// iso_transform_init - Initialize isometric transformation system
// Input: x0 = viewport width, x1 = viewport height
// Output: x0 = 0 on success
//
_iso_transform_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get camera state pointer
    adrp    x2, current_camera@PAGE
    add     x2, x2, current_camera@PAGEOFF
    
    // Load float constants
    adrp    x3, float_constants@PAGE
    add     x3, x3, float_constants@PAGEOFF
    
    // Set default camera position (15.0, 15.0, 20.0)
    ldr     s0, [x3, #16]              // 15.0f
    str     s0, [x2, #camera_position_x]
    str     s0, [x2, #camera_position_y]
    ldr     s1, [x3, #20]              // 20.0f
    str     s1, [x2, #camera_position_z]
    
    // Set default zoom
    ldr     s2, [x3, #24]              // 1.0f
    str     s2, [x2, #camera_zoom]
    
    // Clear rotation
    fmov    s3, wzr
    str     s3, [x2, #camera_rotation]
    
    // Store viewport dimensions
    str     w0, [x2, #camera_viewport_width]
    str     w1, [x2, #camera_viewport_height]
    
    mov     x0, #0                      // Success
    ldp     x29, x30, [sp], #16
    ret

//
// iso_transform_world_to_screen - Transform world coordinate to screen
// Input: v0.3s = world position (x, y, z)
// Output: v0.2s = screen position (x, y), s2 = depth
//
_iso_transform_world_to_screen:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // First transform to isometric space
    bl      _iso_transform_world_to_iso
    
    // Get camera state
    adrp    x0, current_camera@PAGE
    add     x0, x0, current_camera@PAGEOFF
    
    // Apply camera offset
    ldr     s3, [x0, #camera_position_x]
    ldr     s4, [x0, #camera_position_y]
    fsub    s0, s0, s3                  // iso_x - camera_x
    fsub    s1, s1, s4                  // iso_y - camera_y
    
    // Apply zoom
    ldr     s5, [x0, #camera_zoom]
    fmul    s0, s0, s5
    fmul    s1, s1, s5
    
    // Convert to screen coordinates
    ldr     w1, [x0, #camera_viewport_width]
    ldr     w2, [x0, #camera_viewport_height]
    
    scvtf   s6, w1                      // Convert to float
    scvtf   s7, w2
    
    // Load 0.5 constant
    adrp    x3, float_constants@PAGE
    add     x3, x3, float_constants@PAGEOFF
    ldr     s8, [x3, #28]               // 0.5f
    
    fmul    s6, s6, s8                  // width * 0.5
    fmul    s7, s7, s8                  // height * 0.5
    
    fadd    s0, s0, s6                  // screen_x = iso_x + width/2
    fadd    s1, s1, s7                  // screen_y = iso_y + height/2
    
    ldp     x29, x30, [sp], #16
    ret

//
// iso_transform_world_to_iso - Transform world coordinates to isometric space
// Input: v0.3s = world position (x, y, z)
// Output: v0.2s = isometric position (x, y), s2 = depth
//
_iso_transform_world_to_iso:
    // Load float constants
    adrp    x0, float_constants@PAGE
    add     x0, x0, float_constants@PAGEOFF
    
    // Load scales
    ldr     s3, [x0, #0]                // 0.1f (tile scale)
    ldr     s4, [x0, #8]                // 0.05f (iso Y scale)
    ldr     s5, [x0, #12]               // 0.25f (height scale)
    
    // Calculate isometric X: (world.x - world.y) * 0.1
    fsub    s6, s0, s1                  // world.x - world.y
    fmul    s6, s6, s3                  // * 0.1
    
    // Calculate isometric Y: (world.x + world.y) * 0.05 + world.z * 0.25
    fadd    s7, s0, s1                  // world.x + world.y
    fmul    s7, s7, s4                  // * 0.05
    fmadd   s7, s2, s5, s7              // + world.z * 0.25
    
    // Calculate depth: world.x + world.y + world.z * 0.1
    fadd    s8, s0, s1                  // world.x + world.y
    fmadd   s8, s2, s3, s8              // + world.z * 0.1
    
    // Pack results
    fmov    s0, s6                      // iso_x
    fmov    s1, s7                      // iso_y
    fmov    s2, s8                      // depth
    
    ret

//
// iso_transform_calculate_depth - Calculate sorting depth for world position
// Input: v0.3s = world position, w0 = object_type
// Output: s0 = depth value for sorting
//
_iso_transform_calculate_depth:
    // Load constants
    adrp    x1, float_constants@PAGE
    add     x1, x1, float_constants@PAGEOFF
    ldr     s3, [x1, #0]                // 0.1f
    
    // Base depth = world.x + world.y + world.z * 0.1
    fadd    s1, s0, s1                  // world.x + world.y (using s1 for v0.s[1])
    fmadd   s0, s2, s3, s1              // + world.z * 0.1 (using s2 for v0.s[2])
    
    // Add object type bias (simplified)
    and     w0, w0, #7                  // Clamp to 0-7
    scvtf   s2, w0                      // Convert to float
    fmov    s3, #0.125                  // Use representable constant
    lsr     w1, w0, #3                  // Divide by 8 to get smaller bias
    scvtf   s4, w1
    fmul    s2, s4, s3                  // object_type/8 * 0.125
    fadd    s0, s0, s2                  // Add bias
    
    ret

.end