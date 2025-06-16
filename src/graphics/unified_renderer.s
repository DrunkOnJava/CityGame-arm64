//
// unified_renderer.s - Unified Graphics Pipeline for SimCity ARM64
// Sub-Agent 4: Graphics Pipeline Integrator
//
// Unifies all graphics rendering modules into a cohesive pipeline:
// - Metal command encoding via metal_encoder.s
// - Sprite batching via sprite_batch.s  
// - Particle effects via particles.s
// - Depth sorting via depth_sorter.s
// - Camera transforms via camera.s and isometric_transform.s
// - Debug overlay integration
//
// Performance targets:
// - 60 FPS at 1M+ sprites
// - <1000 draw calls per frame
// - <4GB memory usage
// - <50% CPU on Apple M1
//
// Author: Sub-Agent 4 (Graphics Pipeline Integrator)
// Date: 2025-06-15
//

.section __TEXT,__text,regular,pure_instructions
.align 4

// Unified renderer constants
.equ MAX_RENDER_LAYERS, 16
.equ MAX_RENDER_PASSES, 8
.equ UNIFIED_FRAME_BUFFER_SIZE, 0x8000000  // 128MB frame buffer
.equ GRAPHICS_THREAD_COUNT, 4

// Unified render state structure
.struct unified_render_state
    metal_device:           .quad 1     // MTLDevice pointer
    command_queue:          .quad 1     // MTLCommandQueue pointer
    current_encoder:        .quad 1     // Current render encoder
    current_frame:          .long 1     // Frame counter
    frame_time_ns:          .quad 1     // Current frame time
    
    // Rendering modules
    sprite_renderer:        .quad 1     // sprite_batch system
    particle_system:        .quad 1     // particle system
    depth_sorter:          .quad 1     // depth sorting system
    camera_system:         .quad 1     // camera system
    
    // Pipeline state
    current_layer:         .long 1     // Current rendering layer
    viewport_set:          .byte 1     // Viewport configured
    .align 8
    viewport:              .float 6    // x, y, width, height, znear, zfar
    
    // Statistics
    triangles_rendered:    .quad 1
    draw_calls_issued:     .quad 1
    sprites_rendered:      .quad 1
    particles_rendered:    .quad 1
    
    // Performance timers
    frame_start_time:      .quad 1
    render_time_gpu:       .quad 1
    render_time_cpu:       .quad 1
.endstruct

// Render pass descriptor
.struct render_pass_desc
    pass_type:             .long 1     // 0=background, 1=world, 2=ui, 3=debug
    layer_mask:            .long 1     // Bitmask of layers to render
    clear_color:           .float 4    // RGBA clear color
    depth_test:            .byte 1     // Enable depth testing
    blend_mode:            .byte 1     // Blending mode
    .align 8
.endstruct

// Global unified render state
.data
.align 16
g_render_state:         .skip unified_render_state_size
render_passes:          .skip render_pass_desc_size * MAX_RENDER_PASSES
frame_statistics:
    frames_rendered:    .quad 1
    total_frame_time:   .quad 1
    avg_frame_time:     .quad 1
    min_frame_time:     .quad 1
    max_frame_time:     .quad 1

// Predefined render passes
default_render_passes:
    // Background pass
    .long 0             // pass_type = background
    .long 0x1           // layer_mask = layer 0 only
    .float 0.2, 0.3, 0.4, 1.0  // Clear color (blue-gray)
    .byte 1             // depth_test = true
    .byte 0             // blend_mode = none
    .align 8
    
    // World rendering pass  
    .long 1             // pass_type = world
    .long 0xFE          // layer_mask = layers 1-7
    .float 0.0, 0.0, 0.0, 0.0  // No clear
    .byte 1             // depth_test = true
    .byte 1             // blend_mode = alpha
    .align 8
    
    // UI pass
    .long 2             // pass_type = ui
    .long 0x700         // layer_mask = layers 8-10
    .float 0.0, 0.0, 0.0, 0.0  // No clear
    .byte 0             // depth_test = false
    .byte 1             // blend_mode = alpha
    .align 8
    
    // Debug overlay pass
    .long 3             // pass_type = debug
    .long 0x8000        // layer_mask = layer 15
    .float 0.0, 0.0, 0.0, 0.0  // No clear
    .byte 0             // depth_test = false
    .byte 1             // blend_mode = alpha
    .align 8

.text
.global _unified_renderer_init
.global _unified_renderer_begin_frame
.global _unified_renderer_end_frame
.global _unified_renderer_render_frame
.global _unified_renderer_set_camera
.global _unified_renderer_add_sprite
.global _unified_renderer_add_particles
.global _unified_renderer_get_stats
.global _unified_renderer_set_viewport
.global _unified_renderer_cleanup

//
// unified_renderer_init - Initialize unified graphics pipeline
// Input: x0 = Metal device pointer, x1 = viewport width, x2 = viewport height
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15, v0-v7
//
_unified_renderer_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save device
    mov     x20, x1         // Save width
    mov     x21, x2         // Save height
    
    // Initialize render state
    adrp    x0, g_render_state@PAGE
    add     x0, x0, g_render_state@PAGEOFF
    mov     x1, #0
    mov     x2, #unified_render_state_size
    bl      _memset
    
    // Store device and viewport
    adrp    x22, g_render_state@PAGE
    add     x22, x22, g_render_state@PAGEOFF
    str     x19, [x22, #metal_device]
    str     w20, [x22, #viewport + 16]    // Width as float
    str     w21, [x22, #viewport + 20]    // Height as float
    
    // Create command queue
    mov     x0, x19
    bl      _device_new_command_queue
    cmp     x0, #0
    b.eq    .Linit_error
    str     x0, [x22, #command_queue]
    
    // Initialize Metal encoder system
    mov     x0, x19
    bl      _metal_encoder_init
    cmp     x0, #0
    b.ne    .Linit_error
    
    // Initialize sprite batch system
    mov     x0, x19
    bl      _sprite_batch_init
    cmp     x0, #0
    b.ne    .Linit_error
    
    // Initialize particle system
    mov     x0, #131072     // Max 128K particles
    mov     x1, #0x2000000  // 32MB budget
    bl      _particle_system_init
    cmp     x0, #0
    b.ne    .Linit_error
    
    // Initialize depth sorter
    adrp    x0, default_iso_params@PAGE
    add     x0, x0, default_iso_params@PAGEOFF
    bl      _depth_sorter_init
    cmp     x0, #0
    b.ne    .Linit_error
    
    // Initialize camera system
    adrp    x0, main_camera@PAGE
    add     x0, x0, main_camera@PAGEOFF
    mov     x1, x20         // Viewport width
    mov     x2, x21         // Viewport height
    bl      camera_init
    str     x0, [x22, #camera_system]
    
    // Copy default render passes
    adrp    x0, render_passes@PAGE
    add     x0, x0, render_passes@PAGEOFF
    adrp    x1, default_render_passes@PAGE
    add     x1, x1, default_render_passes@PAGEOFF
    mov     x2, #(render_pass_desc_size * 4)
    bl      _memcpy
    
    // Set initial viewport
    ucvtf   s0, w20
    ucvtf   s1, w21
    adrp    x0, g_render_state@PAGE
    add     x0, x0, g_render_state@PAGEOFF
    str     s0, [x0, #viewport + 8]     // Width
    str     s1, [x0, #viewport + 12]    // Height
    fmov    s2, #0.1
    str     s2, [x0, #viewport + 16]    // Near
    fmov    s2, #1000.0
    str     s2, [x0, #viewport + 20]    // Far
    mov     w3, #1
    strb    w3, [x0, #viewport_set]
    
    mov     x0, #0          // Success
    b       .Linit_exit
    
.Linit_error:
    mov     x0, #-1         // Error
    
.Linit_exit:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// unified_renderer_begin_frame - Begin new rendering frame
// Input: None
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x7
//
_unified_renderer_begin_frame:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    // Get current time for frame timing
    bl      _get_system_time_ns
    mov     x19, x0
    
    adrp    x20, g_render_state@PAGE
    add     x20, x20, g_render_state@PAGEOFF
    str     x19, [x20, #frame_start_time]
    
    // Increment frame counter
    ldr     w0, [x20, #current_frame]
    add     w0, w0, #1
    str     w0, [x20, #current_frame]
    
    // Create command buffer
    bl      _metal_create_command_buffer
    cmp     x0, #0
    b.eq    .Lbegin_frame_error
    
    // Begin sprite batch frame
    bl      _sprite_batch_begin_frame
    
    // Clear depth sorter
    bl      _depth_sorter_clear
    
    // Reset frame statistics
    str     xzr, [x20, #triangles_rendered]
    str     xzr, [x20, #draw_calls_issued]
    str     xzr, [x20, #sprites_rendered]
    str     xzr, [x20, #particles_rendered]
    
    mov     x0, #0          // Success
    b       .Lbegin_frame_exit
    
.Lbegin_frame_error:
    mov     x0, #-1         // Error
    
.Lbegin_frame_exit:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// unified_renderer_render_frame - Execute complete frame rendering
// Input: None
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15, v0-v31
//
_unified_renderer_render_frame:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    adrp    x19, g_render_state@PAGE
    add     x19, x19, g_render_state@PAGEOFF
    
    // Execute each render pass
    mov     x20, #0         // Pass index
    
.Lrender_pass_loop:
    cmp     x20, #4         // 4 default passes
    b.ge    .Lrender_passes_done
    
    // Execute render pass
    mov     x0, x20
    bl      _execute_render_pass
    cmp     x0, #0
    b.ne    .Lrender_frame_error
    
    add     x20, x20, #1
    b       .Lrender_pass_loop
    
.Lrender_passes_done:
    mov     x0, #0          // Success
    b       .Lrender_frame_exit
    
.Lrender_frame_error:
    mov     x0, #-1         // Error
    
.Lrender_frame_exit:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// execute_render_pass - Execute a single render pass
// Input: x0 = pass index
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15, v0-v31
//
_execute_render_pass:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save pass index
    
    // Get pass descriptor
    adrp    x20, render_passes@PAGE
    add     x20, x20, render_passes@PAGEOFF
    add     x20, x20, x19, lsl #6   // pass_index * render_pass_desc_size
    
    // Create render encoder for this pass
    ldr     x0, [x20, #command_queue]  // Get from global state
    mov     x1, x20         // Pass descriptor as render pass descriptor
    bl      _metal_create_render_encoder
    cmp     x0, #0
    b.eq    .Lexec_pass_error
    mov     x21, x0         // Save render encoder
    
    // Set viewport if configured
    adrp    x22, g_render_state@PAGE
    add     x22, x22, g_render_state@PAGEOFF
    ldrb    w0, [x22, #viewport_set]
    cbz     w0, .Lskip_viewport
    
    mov     x0, x21
    add     x1, x22, #viewport
    bl      _metal_encoder_set_viewport
    
.Lskip_viewport:
    // Execute pass based on type
    ldr     w0, [x20, #pass_type]
    cmp     w0, #0
    b.eq    .Lexec_background_pass
    cmp     w0, #1
    b.eq    .Lexec_world_pass
    cmp     w0, #2
    b.eq    .Lexec_ui_pass
    cmp     w0, #3
    b.eq    .Lexec_debug_pass
    b       .Lexec_pass_done
    
.Lexec_background_pass:
    // Render background (could be skybox, solid color, etc.)
    bl      _render_background
    b       .Lexec_pass_done
    
.Lexec_world_pass:
    // Main world rendering with depth sorting
    mov     x0, x21         // Render encoder
    ldr     w1, [x20, #layer_mask]
    bl      _render_world_sorted
    b       .Lexec_pass_done
    
.Lexec_ui_pass:
    // UI rendering (no depth sorting needed)
    mov     x0, x21
    ldr     w1, [x20, #layer_mask]
    bl      _render_ui_elements
    b       .Lexec_pass_done
    
.Lexec_debug_pass:
    // Debug overlay rendering
    mov     x0, x21
    bl      _render_debug_overlay
    
.Lexec_pass_done:
    // End encoding
    mov     x0, x21
    bl      _metal_encoder_end_encoding
    
    mov     x0, #0          // Success
    b       .Lexec_pass_exit
    
.Lexec_pass_error:
    mov     x0, #-1         // Error
    
.Lexec_pass_exit:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// render_world_sorted - Render world objects with proper depth sorting
// Input: x0 = render encoder, w1 = layer mask
// Output: x0 = 0 on success
// Modifies: x0-x15, v0-v31
//
_render_world_sorted:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0         // Save encoder
    mov     w20, w1         // Save layer mask
    
    // Update camera transforms
    adrp    x0, main_camera@PAGE
    add     x0, x0, main_camera@PAGEOFF
    fmov    s0, #0.016667   // 60 FPS delta time
    bl      camera_smooth_follow
    
    // Update particle systems
    fmov    s0, #0.016667
    bl      _particle_system_update
    
    // Sort all depth entries
    bl      _depth_sorter_sort_parallel
    
    // Get sorted sprite list
    adrp    x0, sorted_sprite_buffer@PAGE
    add     x0, x0, sorted_sprite_buffer@PAGEOFF
    mov     x1, #65536      // Max sprites
    bl      _depth_sorter_get_sorted_list
    mov     x21, x0         // Save sprite count
    
    // Render sprites in depth order
    mov     x0, x19         // Render encoder
    adrp    x1, sorted_sprite_buffer@PAGE
    add     x1, x1, sorted_sprite_buffer@PAGEOFF
    mov     x2, x21         // Sprite count
    mov     w3, w20         // Layer mask
    bl      _render_sorted_sprites
    
    // Render particles (already sorted by particle system)
    mov     x0, x19
    bl      _particle_system_render
    
    // Update statistics
    adrp    x0, g_render_state@PAGE
    add     x0, x0, g_render_state@PAGEOFF
    ldr     x1, [x0, #sprites_rendered]
    add     x1, x1, x21
    str     x1, [x0, #sprites_rendered]
    
    mov     x0, #0          // Success
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// render_sorted_sprites - Render sprites in depth-sorted order
// Input: x0 = encoder, x1 = sprite array, x2 = count, w3 = layer mask
// Output: None
// Modifies: x0-x15, v0-v31
//
_render_sorted_sprites:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save encoder
    mov     x20, x1         // Save sprite array
    mov     x21, x2         // Save count
    mov     w22, w3         // Save layer mask
    
    // Use sprite batch system for efficient rendering
    mov     x0, x19
    bl      _sprite_batch_flush_batches
    
    // Process sprites in batches for optimal performance
    mov     x23, #0         // Sprite index
    
.Lrender_sprite_loop:
    cmp     x23, x21
    b.ge    .Lrender_sprites_done
    
    // Load sprite pointer
    ldr     x0, [x20, x23, lsl #3]  // sprite_array[index]
    
    // Add sprite to batch system (this handles layer filtering internally)
    bl      _sprite_batch_add_sprite
    
    add     x23, x23, #1
    b       .Lrender_sprite_loop
    
.Lrender_sprites_done:
    // Final batch flush
    mov     x0, x19
    bl      _sprite_batch_flush_batches
    
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// unified_renderer_end_frame - Complete frame rendering and present
// Input: None
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x7
//
_unified_renderer_end_frame:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    adrp    x19, g_render_state@PAGE
    add     x19, x19, g_render_state@PAGEOFF
    
    // Commit command buffer to GPU
    ldr     x0, [x19, #command_queue]
    bl      _get_current_command_buffer  // Helper to get current buffer
    bl      _metal_encoder_commit_command_buffer
    
    // End sprite batch frame
    bl      _sprite_batch_end_frame
    
    // Calculate frame timing
    bl      _get_system_time_ns
    ldr     x1, [x19, #frame_start_time]
    sub     x0, x0, x1      // Frame time in nanoseconds
    str     x0, [x19, #frame_time_ns]
    
    // Update frame statistics
    adrp    x20, frame_statistics@PAGE
    add     x20, x20, frame_statistics@PAGEOFF
    
    ldr     x1, [x20, #frames_rendered]
    add     x1, x1, #1
    str     x1, [x20, #frames_rendered]
    
    ldr     x2, [x20, #total_frame_time]
    add     x2, x2, x0
    str     x2, [x20, #total_frame_time]
    
    // Calculate average frame time
    udiv    x3, x2, x1
    str     x3, [x20, #avg_frame_time]
    
    // Update min/max frame times
    ldr     x4, [x20, #min_frame_time]
    cmp     x4, #0
    csel    x4, x0, x4, eq  // Set min on first frame
    cmp     x0, x4
    csel    x4, x0, x4, lt
    str     x4, [x20, #min_frame_time]
    
    ldr     x4, [x20, #max_frame_time]
    cmp     x0, x4
    csel    x4, x0, x4, gt
    str     x4, [x20, #max_frame_time]
    
    mov     x0, #0          // Success
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// unified_renderer_add_sprite - Add sprite to rendering pipeline
// Input: x0 = sprite data, v0.3s = world position, w1 = layer
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x7, v0-v3
//
_unified_renderer_add_sprite:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Add to depth sorter for proper sorting
    mov     x2, x0          // Save sprite data
    mov     w3, #1          // Object type: sprite
    mov     x0, x2          // Sprite pointer
    // v0.3s already contains world position
    mov     w2, w1          // Layer as layer_id
    bl      _depth_sorter_add_sprite
    
    cmp     x0, #-1
    b.eq    .Ladd_sprite_error
    
    mov     x0, #0          // Success
    b       .Ladd_sprite_exit
    
.Ladd_sprite_error:
    mov     x0, #-1         // Error
    
.Ladd_sprite_exit:
    ldp     x29, x30, [sp], #16
    ret

//
// unified_renderer_set_camera - Update camera for rendering
// Input: x0 = camera pointer
// Output: None
// Modifies: x0-x3
//
_unified_renderer_set_camera:
    adrp    x1, g_render_state@PAGE
    add     x1, x1, g_render_state@PAGEOFF
    str     x0, [x1, #camera_system]
    ret

//
// unified_renderer_get_stats - Get rendering statistics
// Input: x0 = stats output buffer
// Output: None
// Modifies: x0-x7
//
_unified_renderer_get_stats:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     x19, x0         // Save output buffer
    
    // Copy render state statistics
    adrp    x1, g_render_state@PAGE
    add     x1, x1, g_render_state@PAGEOFF
    add     x1, x1, #triangles_rendered
    mov     x2, #32         // Size of statistics block
    bl      _memcpy
    
    // Append frame statistics
    add     x0, x19, x2
    adrp    x1, frame_statistics@PAGE
    add     x1, x1, frame_statistics@PAGEOFF
    mov     x2, #40         // Size of frame statistics
    bl      _memcpy
    
    ldp     x29, x30, [sp], #16
    ret

// Helper rendering functions
_render_background:
    // Simple background rendering - could be expanded
    ret

_render_ui_elements:
    // UI rendering without depth sorting
    // Use sprite batch system for UI sprites
    bl      _sprite_batch_flush_batches
    ret

_render_debug_overlay:
    // Debug overlay rendering
    ret

_get_current_command_buffer:
    // Helper to get current command buffer
    // This would be implemented based on Metal command buffer management
    mov     x0, #0          // Stub
    ret

// Buffer for sorted sprites
.bss
.align 16
sorted_sprite_buffer:   .skip 8 * 65536     // 64K sprite pointers

// Default isometric parameters (would be defined elsewhere)
.data
.align 16
default_iso_params:
    .skip 128           // Placeholder for isometric parameters

// External function declarations
.extern _memset
.extern _memcpy
.extern _get_system_time_ns
.extern _device_new_command_queue
.extern _metal_encoder_init
.extern _metal_create_command_buffer
.extern _metal_create_render_encoder
.extern _metal_encoder_set_viewport
.extern _metal_encoder_end_encoding
.extern _metal_encoder_commit_command_buffer
.extern _sprite_batch_init
.extern _sprite_batch_begin_frame
.extern _sprite_batch_end_frame
.extern _sprite_batch_add_sprite
.extern _sprite_batch_flush_batches
.extern _particle_system_init
.extern _particle_system_update
.extern _particle_system_render
.extern _depth_sorter_init
.extern _depth_sorter_clear
.extern _depth_sorter_add_sprite
.extern _depth_sorter_sort_parallel
.extern _depth_sorter_get_sorted_list
.extern camera_init
.extern camera_smooth_follow
.extern main_camera

.end