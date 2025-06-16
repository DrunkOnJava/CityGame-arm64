//
// metal_pipeline.s - Metal rendering pipeline setup for SimCity ARM64
// Agent 3: Graphics & Rendering Pipeline
//
// Implements Metal device initialization, command queue management,
// render pipeline state creation, and buffer management for high-performance
// tile-based deferred rendering (TBDR) on Apple Silicon.
//
// Performance targets:
// - < 1000 draw calls per frame
// - 60-120 FPS with 1M tiles visible
// - < 500MB texture memory usage
//
// Author: Agent 3 (Graphics)
// Date: 2025-06-15
//

.section __TEXT,__text,regular,pure_instructions
.align 4

// Metal framework imports and constants
.equ MTL_DEVICE_TYPE_INTEGRATED, 0
.equ MTL_DEVICE_TYPE_DISCRETE, 1
.equ MTL_RESOURCE_STORAGE_MODE_SHARED, 0
.equ MTL_RESOURCE_STORAGE_MODE_MANAGED, 1
.equ MTL_RESOURCE_STORAGE_MODE_PRIVATE, 2
.equ MTL_PIXEL_FORMAT_BGRA8UNORM, 80
.equ MTL_LOAD_ACTION_CLEAR, 2
.equ MTL_STORE_ACTION_STORE, 1

// Graphics pipeline structure definitions
.struct metal_device_info
    device_ptr:         .quad 1     // MTLDevice pointer
    command_queue_ptr:  .quad 1     // MTLCommandQueue pointer
    library_ptr:        .quad 1     // MTLLibrary pointer
    max_buffer_length:  .quad 1     // Maximum buffer size
    supports_unified_memory: .quad 1 // Unified memory architecture flag
    tile_width:         .long 1     // TBDR tile width
    tile_height:        .long 1     // TBDR tile height
.endstruct

.struct render_pipeline_state
    vertex_shader_ptr:      .quad 1     // Vertex shader function
    fragment_shader_ptr:    .quad 1     // Fragment shader function
    pipeline_state_ptr:     .quad 1     // MTLRenderPipelineState
    vertex_descriptor_ptr:  .quad 1     // MTLVertexDescriptor
    color_format:           .long 1     // Pixel format
    depth_format:           .long 1     // Depth format
    sample_count:           .long 1     // MSAA sample count
    blend_enabled:          .byte 1     // Blending enabled
    depth_test_enabled:     .byte 1     // Depth testing enabled
    cull_mode:              .byte 1     // Face culling mode
    fill_mode:              .byte 1     // Fill mode (solid/wireframe)
    .align 8
.endstruct

.struct render_state
    current_pipeline:       .quad 1     // Current pipeline state
    viewport:               .float 4    // x, y, width, height
    depth_range:            .float 2    // near, far
    scissors_enabled:       .byte 1     // Scissor testing
    .align 8
    scissors_rect:          .float 4    // x, y, width, height
    clear_color:            .float 4    // RGBA clear color
    clear_depth:            .float 1    // Clear depth value
    clear_stencil:          .byte 1     // Clear stencil value
    .align 8
.endstruct

.struct pipeline_cache
    tile_pipeline:          .quad 1     // Tile rendering pipeline
    sprite_pipeline:        .quad 1     // Sprite rendering pipeline
    ui_pipeline:            .quad 1     // UI rendering pipeline
    debug_pipeline:         .quad 1     // Debug wireframe pipeline
    skybox_pipeline:        .quad 1     // Skybox pipeline
    shadow_pipeline:        .quad 1     // Shadow mapping pipeline
    postprocess_pipeline:   .quad 1     // Post-processing pipeline
    cache_hits:             .quad 1     // Performance counter
    cache_misses:           .quad 1     // Performance counter
.endstruct

.struct command_buffer_pool
    buffer_pool:        .quad 16    // Pool of command buffers
    current_index:      .long 1     // Current buffer index
    pool_size:          .long 1     // Total pool size
    frame_semaphore:    .quad 1     // Frame synchronization
    frame_inflight:     .long 3     // Triple buffering
    completion_handlers: .quad 16   // Completion callback handlers
.endstruct

.struct resource_binding
    vertex_buffer:      .quad 1     // Vertex buffer pointer
    index_buffer:       .quad 1     // Index buffer pointer
    textures:           .quad 8     // Texture array (8 slots)
    vertex_uniforms:    .quad 1     // Vertex uniform buffer
    fragment_uniforms:  .quad 1     // Fragment uniform buffer
    texture_count:      .long 1     // Number of bound textures
    binding_hash:       .long 1     // Hash of current bindings
.endstruct

.struct buffer_pool_entry
    buffer_ptr:         .quad 1     // MTLBuffer pointer
    size:               .quad 1     // Buffer size
    usage_flags:        .long 1     // Usage flags
    last_used_frame:    .long 1     // Frame when last used
    in_use:             .byte 1     // Currently in use flag
    .align 8
.endstruct

.struct resource_cache
    binding_cache:      .quad 64    // Cache of recent bindings
    buffer_cache:       .quad 32    // Cache of buffer objects
    texture_cache:      .quad 16    // Cache of texture objects
    cache_size:         .long 1     // Current cache entries
    max_cache_size:     .long 1     // Maximum cache entries
    cache_hits:         .quad 1     // Performance counter
    cache_misses:       .quad 1     // Performance counter
.endstruct

// Global graphics state
.data
.align 8
graphics_device_info:   .skip metal_device_info_size
main_pipeline_state:    .skip render_pipeline_state_size
current_render_state:   .skip render_state_size
pipeline_state_cache:   .skip pipeline_cache_size
command_pool:           .skip command_buffer_pool_size
current_bindings:       .skip resource_binding_size
resource_binding_cache: .skip resource_cache_size
vertex_buffer_pool:     .skip 512      // Pre-allocated vertex buffers
uniform_buffer_pool:    .skip 256      // Pre-allocated uniform buffers
optimized_buffer_pool:  .skip (buffer_pool_entry_size * 128)  // Optimized buffer pool

// Vertex attribute definitions for isometric tiles
.struct tile_vertex
    position:   .float 3    // x, y, z position
    uv:         .float 2    // texture coordinates
    color:      .float 4    // RGBA color
    normal:     .float 3    // surface normal
.endstruct

// Performance counters
.bss
.align 8
frame_stats:
    draw_calls_count:       .quad 1
    vertices_rendered:      .quad 1
    triangles_rendered:     .quad 1
    gpu_time_ms:            .quad 1
    cpu_time_ms:            .quad 1

.text
.global _metal_pipeline_init
.global _metal_create_device
.global _metal_create_command_queue
.global _metal_create_render_pipeline
.global _metal_create_vertex_descriptor
.global _metal_allocate_buffers
.global _metal_begin_frame
.global _metal_end_frame
.global _metal_get_stats
.global _metal_cleanup
.global _metal_create_render_encoder
.global _metal_set_render_state
.global _metal_bind_resources
.global _metal_submit_async
.global _metal_wait_for_completion
.global _metal_init_render_state
.global _metal_create_pipeline_variants
.global _metal_set_viewport
.global _metal_set_clear_color
.global _metal_get_pipeline_from_cache
.global _metal_bind_pipeline_state
.global _metal_init_resource_cache
.global _metal_bind_optimized_resources
.global _metal_allocate_transient_buffer
.global _metal_get_cached_buffer
.global _metal_validate_bindings
.global _metal_compute_binding_hash

//
// metal_pipeline_init - Initialize Metal rendering pipeline
// Input: None
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15, v0-v7
//
_metal_pipeline_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Clear graphics device info structure
    adrp    x0, graphics_device_info@PAGE
    add     x0, x0, graphics_device_info@PAGEOFF
    mov     x1, #0
    mov     x2, #metal_device_info_size
    bl      _memset
    
    // Create Metal device
    bl      _metal_create_device
    cmp     x0, #0
    b.ne    .Linit_error
    
    // Create command queue
    bl      _metal_create_command_queue
    cmp     x0, #0
    b.ne    .Linit_error
    
    // Create render pipeline state
    bl      _metal_create_render_pipeline
    cmp     x0, #0
    b.ne    .Linit_error
    
    // Allocate buffer pools
    bl      _metal_allocate_buffers
    cmp     x0, #0
    b.ne    .Linit_error
    
    // Initialize performance counters
    adrp    x0, frame_stats@PAGE
    add     x0, x0, frame_stats@PAGEOFF
    mov     x1, #0
    mov     x2, #32         // Size of frame_stats
    bl      _memset
    
    mov     x0, #0          // Success
    b       .Linit_exit
    
.Linit_error:
    mov     x0, #-1         // Error
    
.Linit_exit:
    ldp     x29, x30, [sp], #16
    ret

//
// metal_create_device - Create and configure Metal device
// Input: None
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x7
//
_metal_create_device:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Call MTLCreateSystemDefaultDevice()
    bl      _MTLCreateSystemDefaultDevice
    cmp     x0, #0
    b.eq    .Ldevice_error
    
    // Store device pointer
    adrp    x1, graphics_device_info@PAGE
    add     x1, x1, graphics_device_info@PAGEOFF
    str     x0, [x1, #device_ptr]
    
    // Query device capabilities
    mov     x1, x0          // Device pointer
    bl      _query_device_capabilities
    
    // Verify Apple Silicon GPU support
    adrp    x0, graphics_device_info@PAGE
    add     x0, x0, graphics_device_info@PAGEOFF
    ldr     x1, [x0, #supports_unified_memory]
    cmp     x1, #0
    b.eq    .Ldevice_error  // Require unified memory architecture
    
    mov     x0, #0          // Success
    b       .Ldevice_exit
    
.Ldevice_error:
    mov     x0, #-1         // Error
    
.Ldevice_exit:
    ldp     x29, x30, [sp], #16
    ret

//
// query_device_capabilities - Query Metal device capabilities
// Input: x1 = MTLDevice pointer
// Output: Updates graphics_device_info structure
// Modifies: x0-x7
//
_query_device_capabilities:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     x0, x1          // Device pointer
    
    // Query maximum buffer length
    bl      _device_max_buffer_length
    adrp    x1, graphics_device_info@PAGE
    add     x1, x1, graphics_device_info@PAGEOFF
    str     x0, [x1, #max_buffer_length]
    
    // Check for unified memory architecture (Apple Silicon)
    adrp    x0, graphics_device_info@PAGE
    add     x0, x0, graphics_device_info@PAGEOFF
    ldr     x1, [x0, #device_ptr]
    bl      _device_has_unified_memory
    str     x0, [x1, #supports_unified_memory]
    
    // Query TBDR tile dimensions (Apple GPU specific)
    mov     w0, #32         // Apple GPU tile width
    mov     w1, #32         // Apple GPU tile height
    adrp    x2, graphics_device_info@PAGE
    add     x2, x2, graphics_device_info@PAGEOFF
    str     w0, [x2, #tile_width]
    str     w1, [x2, #tile_height]
    
    ldp     x29, x30, [sp], #16
    ret

//
// metal_create_command_queue - Create Metal command queue
// Input: None
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x3
//
_metal_create_command_queue:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get device pointer
    adrp    x0, graphics_device_info@PAGE
    add     x0, x0, graphics_device_info@PAGEOFF
    ldr     x0, [x0, #device_ptr]
    
    // Create command queue
    bl      _device_new_command_queue
    cmp     x0, #0
    b.eq    .Lqueue_error
    
    // Store command queue pointer
    adrp    x1, graphics_device_info@PAGE
    add     x1, x1, graphics_device_info@PAGEOFF
    str     x0, [x1, #command_queue_ptr]
    
    mov     x0, #0          // Success
    b       .Lqueue_exit
    
.Lqueue_error:
    mov     x0, #-1         // Error
    
.Lqueue_exit:
    ldp     x29, x30, [sp], #16
    ret

//
// metal_create_render_pipeline - Create render pipeline state
// Input: None
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15
//
_metal_create_render_pipeline:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Create default library
    adrp    x0, graphics_device_info@PAGE
    add     x0, x0, graphics_device_info@PAGEOFF
    ldr     x0, [x0, #device_ptr]
    bl      _device_new_default_library
    cmp     x0, #0
    b.eq    .Lpipeline_error
    
    // Store library pointer
    adrp    x1, graphics_device_info@PAGE
    add     x1, x1, graphics_device_info@PAGEOFF
    str     x0, [x1, #library_ptr]
    
    // Create vertex descriptor
    bl      _metal_create_vertex_descriptor
    cmp     x0, #0
    b.ne    .Lpipeline_error
    
    // Load vertex shader
    adrp    x0, graphics_device_info@PAGE
    add     x0, x0, graphics_device_info@PAGEOFF
    ldr     x0, [x0, #library_ptr]
    adr     x1, vertex_shader_name
    bl      _library_new_function_with_name
    adrp    x1, main_pipeline_state@PAGE
    add     x1, x1, main_pipeline_state@PAGEOFF
    str     x0, [x1, #vertex_shader_ptr]
    
    // Load fragment shader
    adrp    x0, graphics_device_info@PAGE
    add     x0, x0, graphics_device_info@PAGEOFF
    ldr     x0, [x0, #library_ptr]
    adr     x1, fragment_shader_name
    bl      _library_new_function_with_name
    adrp    x1, main_pipeline_state@PAGE
    add     x1, x1, main_pipeline_state@PAGEOFF
    str     x0, [x1, #fragment_shader_ptr]
    
    // Create pipeline descriptor
    bl      _create_render_pipeline_descriptor
    cmp     x0, #0
    b.eq    .Lpipeline_error
    
    // Create pipeline state
    mov     x1, x0          // Pipeline descriptor
    adrp    x0, graphics_device_info@PAGE
    add     x0, x0, graphics_device_info@PAGEOFF
    ldr     x0, [x0, #device_ptr]
    bl      _device_new_render_pipeline_state
    adrp    x1, main_pipeline_state@PAGE
    add     x1, x1, main_pipeline_state@PAGEOFF
    str     x0, [x1, #pipeline_state_ptr]
    
    mov     x0, #0          // Success
    b       .Lpipeline_exit
    
.Lpipeline_error:
    mov     x0, #-1         // Error
    
.Lpipeline_exit:
    ldp     x29, x30, [sp], #16
    ret

//
// metal_create_vertex_descriptor - Create vertex descriptor for tile rendering
// Input: None
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x7
//
_metal_create_vertex_descriptor:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Create vertex descriptor
    bl      _MTLVertexDescriptor_new
    cmp     x0, #0
    b.eq    .Lvertex_desc_error
    
    mov     x1, x0          // Vertex descriptor
    
    // Configure position attribute (attribute 0)
    mov     x0, #0          // Attribute index
    mov     x2, #0          // Buffer index
    mov     x3, #0          // Offset (position)
    mov     x4, #3          // Format: float3
    bl      _configure_vertex_attribute
    
    // Configure UV attribute (attribute 1)
    mov     x0, #1          // Attribute index
    mov     x2, #0          // Buffer index
    mov     x3, #12         // Offset (after position)
    mov     x4, #2          // Format: float2
    bl      _configure_vertex_attribute
    
    // Configure color attribute (attribute 2)
    mov     x0, #2          // Attribute index
    mov     x2, #0          // Buffer index
    mov     x3, #20         // Offset (after position + UV)
    mov     x4, #4          // Format: float4
    bl      _configure_vertex_attribute
    
    // Configure normal attribute (attribute 3)
    mov     x0, #3          // Attribute index
    mov     x2, #0          // Buffer index
    mov     x3, #36         // Offset (after position + UV + color)
    mov     x4, #3          // Format: float3
    bl      _configure_vertex_attribute
    
    // Configure buffer layout
    mov     x0, #0          // Buffer index
    mov     x1, #tile_vertex_size  // Stride
    mov     x2, #1          // Step function: per vertex
    bl      _configure_buffer_layout
    
    // Store vertex descriptor
    adrp    x0, main_pipeline_state@PAGE
    add     x0, x0, main_pipeline_state@PAGEOFF
    str     x1, [x0, #vertex_descriptor_ptr]
    
    mov     x0, #0          // Success
    b       .Lvertex_desc_exit
    
.Lvertex_desc_error:
    mov     x0, #-1         // Error
    
.Lvertex_desc_exit:
    ldp     x29, x30, [sp], #16
    ret

//
// metal_allocate_buffers - Pre-allocate buffer pools for performance
// Input: None
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15
//
_metal_allocate_buffers:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Initialize command buffer pool
    adrp    x0, command_pool@PAGE
    add     x0, x0, command_pool@PAGEOFF
    mov     x1, #0
    str     x1, [x0, #current_index]
    mov     x1, #16
    str     x1, [x0, #pool_size]
    
    // Allocate vertex buffer pool (1MB per buffer, 16 buffers)
    mov     x19, #0         // Loop counter
    mov     x20, #16        // Pool size
    mov     x21, #0x100000  // 1MB buffer size
    
.Lalloc_vertex_loop:
    cmp     x19, x20
    b.ge    .Lalloc_vertex_done
    
    // Allocate vertex buffer
    adrp    x0, graphics_device_info@PAGE
    add     x0, x0, graphics_device_info@PAGEOFF
    ldr     x0, [x0, #device_ptr]
    mov     x1, x21         // Buffer size
    mov     x2, #MTL_RESOURCE_STORAGE_MODE_SHARED
    bl      _device_new_buffer_with_length
    
    // Store buffer pointer
    adrp    x1, vertex_buffer_pool@PAGE
    add     x1, x1, vertex_buffer_pool@PAGEOFF
    add     x1, x1, x19, lsl #3    // x19 * 8
    str     x0, [x1]
    
    add     x19, x19, #1
    b       .Lalloc_vertex_loop
    
.Lalloc_vertex_done:
    // Allocate uniform buffer pool (64KB per buffer, 16 buffers)
    mov     x19, #0         // Loop counter
    mov     x21, #0x10000   // 64KB buffer size
    
.Lalloc_uniform_loop:
    cmp     x19, x20
    b.ge    .Lalloc_uniform_done
    
    // Allocate uniform buffer
    adrp    x0, graphics_device_info@PAGE
    add     x0, x0, graphics_device_info@PAGEOFF
    ldr     x0, [x0, #device_ptr]
    mov     x1, x21         // Buffer size
    mov     x2, #MTL_RESOURCE_STORAGE_MODE_SHARED
    bl      _device_new_buffer_with_length
    
    // Store buffer pointer
    adrp    x1, uniform_buffer_pool@PAGE
    add     x1, x1, uniform_buffer_pool@PAGEOFF
    add     x1, x1, x19, lsl #3    // x19 * 8
    str     x0, [x1]
    
    add     x19, x19, #1
    b       .Lalloc_uniform_loop
    
.Lalloc_uniform_done:
    mov     x0, #0          // Success
    ldp     x29, x30, [sp], #16
    ret

//
// metal_begin_frame - Begin new frame rendering with triple buffering
// Input: None
// Output: x0 = command buffer pointer, 0 on error
// Modifies: x0-x7
//
_metal_begin_frame:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    // Get command buffer from pool with triple buffering
    adrp    x19, command_pool@PAGE
    add     x19, x19, command_pool@PAGEOFF
    
    // Wait for frame completion if needed (CPU/GPU sync)
    bl      _wait_for_frame_completion
    
    ldr     w20, [x19, #current_index]
    ldr     w1, [x19, #frame_inflight]
    
    // Cycle to next buffer (triple buffering)
    add     w20, w20, #1
    cmp     w20, w1
    csel    w20, wzr, w20, ge   // Wrap around if at end
    str     w20, [x19, #current_index]
    
    // Get command buffer from pool
    add     x0, x19, #buffer_pool
    add     x0, x0, x20, lsl #3    // buffer_pool[index]
    ldr     x0, [x0]
    
    cmp     x0, #0
    b.eq    .Lbegin_frame_create_new
    
    // Wait for previous command buffer completion
    bl      _command_buffer_wait_until_completed
    
    // Reuse existing command buffer
    bl      _command_buffer_reset
    b       .Lbegin_frame_setup
    
.Lbegin_frame_create_new:
    // Create new command buffer
    adrp    x0, graphics_device_info@PAGE
    add     x0, x0, graphics_device_info@PAGEOFF
    ldr     x0, [x0, #command_queue_ptr]
    bl      _command_queue_command_buffer
    cmp     x0, #0
    b.eq    .Lbegin_frame_error
    
    // Store in pool
    add     x1, x19, #buffer_pool
    add     x1, x1, x20, lsl #3
    str     x0, [x1]
    
.Lbegin_frame_setup:
    mov     x21, x0         // Save command buffer
    
    // Reset frame statistics
    adrp    x1, frame_stats@PAGE
    add     x1, x1, frame_stats@PAGEOFF
    mov     x2, #0
    str     x2, [x1, #draw_calls_count]
    str     x2, [x1, #vertices_rendered]
    str     x2, [x1, #triangles_rendered]
    
    // Start high-precision CPU timing
    bl      _get_system_time_ns
    str     x0, [x1, #cpu_time_ms]
    
    // Set command buffer label for Metal GPU debugger
    mov     x0, x21
    adr     x1, frame_label
    bl      _command_buffer_set_label
    
    // Set up completion handler for triple buffering
    mov     x0, x21
    add     x1, x19, #completion_handlers
    add     x1, x1, x20, lsl #3
    bl      _setup_completion_handler
    
    mov     x0, x21         // Return command buffer
    b       .Lbegin_frame_exit
    
.Lbegin_frame_error:
    mov     x0, #0          // Error
    
.Lbegin_frame_exit:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// metal_end_frame - End frame rendering and present
// Input: x0 = command buffer pointer
// Output: None
// Modifies: x0-x7
//
_metal_end_frame:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     x19, x0         // Save command buffer
    
    // Commit command buffer
    bl      _command_buffer_commit
    
    // Calculate frame timing
    bl      _get_system_time_ns
    adrp    x1, frame_stats@PAGE
    add     x1, x1, frame_stats@PAGEOFF
    ldr     x2, [x1, #cpu_time_ms]
    sub     x0, x0, x2
    mov     x2, #1000000    // Convert to milliseconds
    udiv    x0, x0, x2
    str     x0, [x1, #cpu_time_ms]
    
    // Wait for completion (for timing)
    mov     x0, x19
    bl      _command_buffer_wait_until_completed
    
    ldp     x29, x30, [sp], #16
    ret

//
// metal_get_stats - Get current frame statistics
// Input: x0 = stats buffer pointer
// Output: None
// Modifies: x0-x3
//
_metal_get_stats:
    adrp    x1, frame_stats@PAGE
    add     x1, x1, frame_stats@PAGEOFF
    
    // Copy frame stats to output buffer
    mov     x2, #32         // Size of frame_stats structure
    
.Lcopy_stats_loop:
    cmp     x2, #0
    b.eq    .Lcopy_stats_done
    ldr     x3, [x1], #8
    str     x3, [x0], #8
    sub     x2, x2, #8
    b       .Lcopy_stats_loop
    
.Lcopy_stats_done:
    ret

//
// metal_cleanup - Clean up Metal resources
// Input: None
// Output: None
// Modifies: x0-x15
//
_metal_cleanup:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Release buffer pools
    mov     x19, #0         // Loop counter
    mov     x20, #16        // Pool size
    
.Lcleanup_vertex_loop:
    cmp     x19, x20
    b.ge    .Lcleanup_vertex_done
    
    adrp    x0, vertex_buffer_pool@PAGE
    add     x0, x0, vertex_buffer_pool@PAGEOFF
    add     x0, x0, x19, lsl #3
    ldr     x0, [x0]
    cmp     x0, #0
    b.eq    .Lcleanup_vertex_next
    bl      _release_object
    
.Lcleanup_vertex_next:
    add     x19, x19, #1
    b       .Lcleanup_vertex_loop
    
.Lcleanup_vertex_done:
    // Release uniform buffers
    mov     x19, #0
    
.Lcleanup_uniform_loop:
    cmp     x19, x20
    b.ge    .Lcleanup_uniform_done
    
    adrp    x0, uniform_buffer_pool@PAGE
    add     x0, x0, uniform_buffer_pool@PAGEOFF
    add     x0, x0, x19, lsl #3
    ldr     x0, [x0]
    cmp     x0, #0
    b.eq    .Lcleanup_uniform_next
    bl      _release_object
    
.Lcleanup_uniform_next:
    add     x19, x19, #1
    b       .Lcleanup_uniform_loop
    
.Lcleanup_uniform_done:
    // Release pipeline state
    adrp    x0, main_pipeline_state@PAGE
    add     x0, x0, main_pipeline_state@PAGEOFF
    ldr     x0, [x0, #pipeline_state_ptr]
    cmp     x0, #0
    b.eq    .Lcleanup_pipeline_done
    bl      _release_object
    
.Lcleanup_pipeline_done:
    // Release command queue
    adrp    x0, graphics_device_info@PAGE
    add     x0, x0, graphics_device_info@PAGEOFF
    ldr     x0, [x0, #command_queue_ptr]
    cmp     x0, #0
    b.eq    .Lcleanup_queue_done
    bl      _release_object
    
.Lcleanup_queue_done:
    // Release device
    adrp    x0, graphics_device_info@PAGE
    add     x0, x0, graphics_device_info@PAGEOFF
    ldr     x0, [x0, #device_ptr]
    cmp     x0, #0
    b.eq    .Lcleanup_device_done
    bl      _release_object
    
.Lcleanup_device_done:
    ldp     x29, x30, [sp], #16
    ret

//
// metal_create_render_encoder - Create render command encoder
// Input: x0 = command buffer, x1 = render pass descriptor
// Output: x0 = render encoder pointer, 0 on error
// Modifies: x0-x7
//
_metal_create_render_encoder:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Set render pass label for debugging
    mov     x2, x1          // Save render pass descriptor
    adr     x1, render_pass_label
    bl      _render_pass_set_label
    
    mov     x1, x2          // Restore render pass descriptor
    bl      _command_buffer_render_command_encoder
    
    ldp     x29, x30, [sp], #16
    ret

//
// metal_set_render_state - Set render pipeline state and viewport
// Input: x0 = render encoder, x1 = pipeline state, x2 = viewport
// Output: None
// Modifies: x0-x7
//
_metal_set_render_state:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0         // Save render encoder
    mov     x20, x2         // Save viewport
    
    // Set render pipeline state
    mov     x0, x19
    bl      _render_encoder_set_render_pipeline_state
    
    // Set viewport if provided
    cmp     x20, #0
    b.eq    .Lset_state_done
    
    mov     x0, x19
    mov     x1, x20
    bl      _render_encoder_set_viewport
    
.Lset_state_done:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// metal_bind_resources - Bind vertex/index buffers and textures
// Input: x0 = render encoder, x1 = resource binding info
// Output: None
// Modifies: x0-x15
//
_metal_bind_resources:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0         // Save render encoder
    mov     x20, x1         // Save binding info
    
    // Bind vertex buffer
    ldr     x1, [x20, #0]   // vertex_buffer
    cmp     x1, #0
    b.eq    .Lbind_index
    
    mov     x0, x19
    mov     x2, #0          // Buffer index
    mov     x3, #0          // Offset
    bl      _render_encoder_set_vertex_buffer
    
.Lbind_index:
    // Bind index buffer
    ldr     x1, [x20, #8]   // index_buffer
    cmp     x1, #0
    b.eq    .Lbind_textures
    
    mov     x0, x19
    mov     x2, #0          // Index type
    bl      _render_encoder_set_index_buffer
    
.Lbind_textures:
    // Bind fragment textures
    ldr     x1, [x20, #16]  // texture_array
    ldr     w2, [x20, #24]  // texture_count
    
    cmp     w2, #0
    b.eq    .Lbind_uniforms
    
    mov     w3, #0          // Texture index
    
.Lbind_texture_loop:
    cmp     w3, w2
    b.ge    .Lbind_uniforms
    
    mov     x0, x19
    ldr     x4, [x1, x3, lsl #3]    // texture_array[i]
    mov     x5, x3          // Texture index
    bl      _render_encoder_set_fragment_texture
    
    add     w3, w3, #1
    b       .Lbind_texture_loop
    
.Lbind_uniforms:
    // Bind uniform buffers
    ldr     x1, [x20, #32]  // vertex_uniforms
    cmp     x1, #0
    b.eq    .Lbind_resources_done
    
    mov     x0, x19
    mov     x2, #1          // Buffer index
    mov     x3, #0          // Offset
    bl      _render_encoder_set_vertex_buffer
    
.Lbind_resources_done:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// metal_submit_async - Submit command buffer asynchronously
// Input: x0 = command buffer pointer
// Output: None
// Modifies: x0-x7
//
_metal_submit_async:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Add completion handler for performance tracking
    adr     x1, completion_handler
    bl      _command_buffer_add_completed_handler
    
    // Commit command buffer
    bl      _command_buffer_commit
    
    ldp     x29, x30, [sp], #16
    ret

//
// metal_wait_for_completion - Wait for command buffer completion
// Input: x0 = command buffer pointer
// Output: None
// Modifies: x0-x7
//
_metal_wait_for_completion:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    bl      _command_buffer_wait_until_completed
    
    // Update GPU timing statistics
    bl      _get_system_time_ns
    adrp    x1, frame_stats@PAGE
    add     x1, x1, frame_stats@PAGEOFF
    ldr     x2, [x1, #cpu_time_ms]
    sub     x0, x0, x2
    mov     x2, #1000000
    udiv    x0, x0, x2
    str     x0, [x1, #gpu_time_ms]
    
    ldp     x29, x30, [sp], #16
    ret

// Completion handler for async command buffers
completion_handler:
    // Update performance counters
    adrp    x0, frame_stats@PAGE
    add     x0, x0, frame_stats@PAGEOFF
    bl      _get_system_time_ns
    // Handler implementation would go here
    ret

//
// metal_init_render_state - Initialize default render state
// Input: None
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x7, v0-v7
//
_metal_init_render_state:
    // Set default viewport (full screen)
    adrp    x0, current_render_state@PAGE
    add     x0, x0, current_render_state@PAGEOFF
    
    // Viewport: x=0, y=0, width=2048, height=2048 (default)
    mov     v0.s[0], wzr        // x = 0
    mov     v0.s[1], wzr        // y = 0
    fmov    s1, #2048.0         // width = 2048
    fmov    s2, #2048.0         // height = 2048
    mov     v0.s[2], v1.s[0]
    mov     v0.s[3], v2.s[0]
    str     q0, [x0, #viewport]
    
    // Depth range: near=0.0, far=1.0
    mov     v1.s[0], wzr        // near = 0.0
    fmov    s3, #1.0            // far = 1.0
    mov     v1.s[1], v3.s[0]
    str     d1, [x0, #depth_range]
    
    // Clear color: dark blue (0.1, 0.2, 0.4, 1.0)
    fmov    s0, #0.1
    fmov    s1, #0.2
    fmov    s2, #0.4
    fmov    s3, #1.0
    mov     v4.s[0], v0.s[0]
    mov     v4.s[1], v1.s[0]
    mov     v4.s[2], v2.s[0]
    mov     v4.s[3], v3.s[0]
    str     q4, [x0, #clear_color]
    
    // Clear depth and stencil
    fmov    s5, #1.0
    str     s5, [x0, #clear_depth]
    mov     w1, #0
    strb    w1, [x0, #clear_stencil]
    
    // Disable scissors by default
    strb    w1, [x0, #scissors_enabled]
    
    mov     x0, #0              // Success
    ret

//
// metal_create_pipeline_variants - Create all pipeline state variants
// Input: None
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15
//
_metal_create_pipeline_variants:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    adrp    x19, pipeline_state_cache@PAGE
    add     x19, x19, pipeline_state_cache@PAGEOFF
    
    // Create tile rendering pipeline
    mov     x0, #0              // Tile pipeline variant
    bl      _create_pipeline_variant
    cmp     x0, #0
    b.ne    .Lcreate_variants_error
    str     x0, [x19, #tile_pipeline]
    
    // Create sprite rendering pipeline
    mov     x0, #1              // Sprite pipeline variant
    bl      _create_pipeline_variant
    cmp     x0, #0
    b.ne    .Lcreate_variants_error
    str     x0, [x19, #sprite_pipeline]
    
    // Create UI rendering pipeline
    mov     x0, #2              // UI pipeline variant
    bl      _create_pipeline_variant
    cmp     x0, #0
    b.ne    .Lcreate_variants_error
    str     x0, [x19, #ui_pipeline]
    
    // Create debug wireframe pipeline
    mov     x0, #3              // Debug pipeline variant
    bl      _create_pipeline_variant
    cmp     x0, #0
    b.ne    .Lcreate_variants_error
    str     x0, [x19, #debug_pipeline]
    
    // Initialize performance counters
    str     xzr, [x19, #cache_hits]
    str     xzr, [x19, #cache_misses]
    
    mov     x0, #0              // Success
    b       .Lcreate_variants_exit
    
.Lcreate_variants_error:
    mov     x0, #-1             // Error
    
.Lcreate_variants_exit:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// metal_set_viewport - Set rendering viewport
// Input: x0 = viewport (float4: x, y, width, height)
// Output: None
// Modifies: x0-x3, v0-v1
//
_metal_set_viewport:
    adrp    x1, current_render_state@PAGE
    add     x1, x1, current_render_state@PAGEOFF
    
    // Load and store viewport
    ldr     q0, [x0]
    str     q0, [x1, #viewport]
    
    ret

//
// metal_set_clear_color - Set clear color for render passes
// Input: x0 = clear color (float4: r, g, b, a)
// Output: None
// Modifies: x0-x3, v0-v1
//
_metal_set_clear_color:
    adrp    x1, current_render_state@PAGE
    add     x1, x1, current_render_state@PAGEOFF
    
    // Load and store clear color
    ldr     q0, [x0]
    str     q0, [x1, #clear_color]
    
    ret

//
// metal_get_pipeline_from_cache - Get cached pipeline state
// Input: w0 = pipeline type (0=tile, 1=sprite, 2=ui, 3=debug)
// Output: x0 = pipeline state pointer, 0 if not found
// Modifies: x0-x3
//
_metal_get_pipeline_from_cache:
    adrp    x1, pipeline_state_cache@PAGE
    add     x1, x1, pipeline_state_cache@PAGEOFF
    
    cmp     w0, #3
    b.gt    .Lget_pipeline_miss
    
    // Load pipeline from cache
    ldr     x2, [x1, x0, lsl #3]    // cache[type]
    cmp     x2, #0
    b.eq    .Lget_pipeline_miss
    
    // Cache hit
    ldr     x3, [x1, #cache_hits]
    add     x3, x3, #1
    str     x3, [x1, #cache_hits]
    
    mov     x0, x2
    ret
    
.Lget_pipeline_miss:
    // Cache miss
    ldr     x2, [x1, #cache_misses]
    add     x2, x2, #1
    str     x2, [x1, #cache_misses]
    
    mov     x0, #0
    ret

//
// metal_bind_pipeline_state - Bind pipeline state with validation
// Input: x0 = render encoder, x1 = pipeline type
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x7
//
_metal_bind_pipeline_state:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0             // Save render encoder
    mov     w20, w1             // Save pipeline type
    
    // Get pipeline from cache
    mov     w0, w20
    bl      _metal_get_pipeline_from_cache
    cmp     x0, #0
    b.eq    .Lbind_pipeline_error
    
    // Set render pipeline state
    mov     x1, x0              // Pipeline state
    mov     x0, x19             // Render encoder
    bl      _render_encoder_set_render_pipeline_state
    
    // Update current render state
    adrp    x1, current_render_state@PAGE
    add     x1, x1, current_render_state@PAGEOFF
    str     x0, [x1, #current_pipeline]
    
    mov     x0, #0              // Success
    b       .Lbind_pipeline_exit
    
.Lbind_pipeline_error:
    mov     x0, #-1             // Error
    
.Lbind_pipeline_exit:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// create_pipeline_variant - Create a specific pipeline variant
// Input: w0 = variant type (0=tile, 1=sprite, 2=ui, 3=debug)
// Output: x0 = pipeline state pointer, 0 on error
// Modifies: x0-x15
//
_create_pipeline_variant:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Create pipeline descriptor
    bl      _create_render_pipeline_descriptor
    cmp     x0, #0
    b.eq    .Lcreate_variant_error
    
    // Configure variant-specific settings
    mov     x1, x0              // Pipeline descriptor
    mov     w0, w0              // Variant type (preserved)
    bl      _configure_pipeline_variant
    
    // Create pipeline state object
    adrp    x0, graphics_device_info@PAGE
    add     x0, x0, graphics_device_info@PAGEOFF
    ldr     x0, [x0, #device_ptr]
    bl      _device_new_render_pipeline_state
    
    ldp     x29, x30, [sp], #16
    ret
    
.Lcreate_variant_error:
    mov     x0, #0
    ldp     x29, x30, [sp], #16
    ret

//
// configure_pipeline_variant - Configure pipeline for specific use case
// Input: w0 = variant type, x1 = pipeline descriptor
// Output: None
// Modifies: x0-x7
//
_configure_pipeline_variant:
    // Implementation depends on variant type
    // This would configure blend states, depth testing, etc.
    ret

//
// metal_init_resource_cache - Initialize resource binding cache
// Input: None
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x7
//
_metal_init_resource_cache:
    // Initialize resource cache
    adrp    x0, resource_binding_cache@PAGE
    add     x0, x0, resource_binding_cache@PAGEOFF
    
    mov     x1, #0
    str     x1, [x0, #cache_size]
    mov     x1, #64
    str     x1, [x0, #max_cache_size]
    str     xzr, [x0, #cache_hits]
    str     xzr, [x0, #cache_misses]
    
    // Initialize current bindings
    adrp    x0, current_bindings@PAGE
    add     x0, x0, current_bindings@PAGEOFF
    mov     x1, #0
    mov     x2, #resource_binding_size
    bl      _memset
    
    // Initialize optimized buffer pool
    adrp    x0, optimized_buffer_pool@PAGE
    add     x0, x0, optimized_buffer_pool@PAGEOFF
    mov     x1, #0
    mov     x2, #(buffer_pool_entry_size * 128)
    bl      _memset
    
    mov     x0, #0              // Success
    ret

//
// metal_bind_optimized_resources - Optimized resource binding with caching
// Input: x0 = render encoder, x1 = resource binding info
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15
//
_metal_bind_optimized_resources:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0             // Save render encoder
    mov     x20, x1             // Save binding info
    
    // Compute hash of new bindings
    mov     x0, x20
    bl      _metal_compute_binding_hash
    mov     w21, w0             // Save hash
    
    // Check if bindings have changed
    adrp    x22, current_bindings@PAGE
    add     x22, x22, current_bindings@PAGEOFF
    ldr     w0, [x22, #binding_hash]
    cmp     w0, w21
    b.eq    .Lbind_optimized_cached  // Same bindings, skip
    
    // Validate bindings
    mov     x0, x20
    bl      _metal_validate_bindings
    cmp     x0, #0
    b.ne    .Lbind_optimized_error
    
    // Apply new bindings
    bl      _apply_resource_bindings
    
    // Update current bindings cache
    mov     x0, x22
    mov     x1, x20
    mov     x2, #resource_binding_size
    bl      _memcpy
    str     w21, [x22, #binding_hash]
    
    // Update cache statistics
    adrp    x0, resource_binding_cache@PAGE
    add     x0, x0, resource_binding_cache@PAGEOFF
    ldr     x1, [x0, #cache_misses]
    add     x1, x1, #1
    str     x1, [x0, #cache_misses]
    
    b       .Lbind_optimized_exit
    
.Lbind_optimized_cached:
    // Cache hit - bindings unchanged
    adrp    x0, resource_binding_cache@PAGE
    add     x0, x0, resource_binding_cache@PAGEOFF
    ldr     x1, [x0, #cache_hits]
    add     x1, x1, #1
    str     x1, [x0, #cache_hits]
    
.Lbind_optimized_exit:
    mov     x0, #0              // Success
    b       .Lbind_optimized_done
    
.Lbind_optimized_error:
    mov     x0, #-1             // Error
    
.Lbind_optimized_done:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// metal_allocate_transient_buffer - Allocate temporary buffer from pool
// Input: x0 = size, w1 = usage flags
// Output: x0 = buffer pointer, 0 on error
// Modifies: x0-x15
//
_metal_allocate_transient_buffer:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0             // Save size
    mov     w20, w1             // Save usage flags
    
    // Find available buffer in pool
    adrp    x21, optimized_buffer_pool@PAGE
    add     x21, x21, optimized_buffer_pool@PAGEOFF
    
    mov     x22, #0             // Pool index
    mov     x23, #128           // Pool size
    
.Lalloc_buffer_loop:
    cmp     x22, x23
    b.ge    .Lalloc_buffer_create_new
    
    // Get pool entry
    add     x0, x21, x22, lsl #6    // entry_size = 64 bytes
    
    // Check if available and suitable size
    ldrb    w1, [x0, #in_use]
    cbnz    w1, .Lalloc_buffer_next
    
    ldr     x2, [x0, #size]
    cmp     x2, x19
    b.lt    .Lalloc_buffer_next
    
    // Found suitable buffer
    mov     w1, #1
    strb    w1, [x0, #in_use]
    str     w20, [x0, #usage_flags]
    
    // Get current frame number (simplified)
    bl      _get_current_frame_number
    str     w0, [x0, #last_used_frame]
    
    ldr     x0, [x0, #buffer_ptr]
    b       .Lalloc_buffer_exit
    
.Lalloc_buffer_next:
    add     x22, x22, #1
    b       .Lalloc_buffer_loop
    
.Lalloc_buffer_create_new:
    // Create new buffer
    adrp    x0, graphics_device_info@PAGE
    add     x0, x0, graphics_device_info@PAGEOFF
    ldr     x0, [x0, #device_ptr]
    mov     x1, x19             // Size
    mov     x2, #0              // Storage mode: shared
    bl      _device_new_buffer_with_length
    
    // TODO: Add to pool if space available
    
.Lalloc_buffer_exit:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// metal_get_cached_buffer - Get buffer from cache or create new
// Input: x0 = size, w1 = usage flags
// Output: x0 = buffer pointer, 0 on error
// Modifies: x0-x7
//
_metal_get_cached_buffer:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // First try transient allocation
    bl      _metal_allocate_transient_buffer
    cmp     x0, #0
    b.ne    .Lget_cached_exit
    
    // Fall back to regular allocation
    adrp    x2, graphics_device_info@PAGE
    add     x2, x2, graphics_device_info@PAGEOFF
    ldr     x2, [x2, #device_ptr]
    mov     x3, x0              // Size (x0 from previous call)
    mov     x0, x2              // Device
    mov     x1, x3              // Size
    mov     x2, #0              // Storage mode
    bl      _device_new_buffer_with_length
    
.Lget_cached_exit:
    ldp     x29, x30, [sp], #16
    ret

//
// metal_validate_bindings - Validate resource binding configuration
// Input: x0 = resource binding info
// Output: x0 = 0 if valid, -1 if invalid
// Modifies: x0-x7
//
_metal_validate_bindings:
    // Check vertex buffer
    ldr     x1, [x0, #vertex_buffer]
    cmp     x1, #0
    b.eq    .Lvalidate_bindings_error
    
    // Check texture count
    ldr     w1, [x0, #texture_count]
    cmp     w1, #8
    b.gt    .Lvalidate_bindings_error
    
    // All validations passed
    mov     x0, #0
    ret
    
.Lvalidate_bindings_error:
    mov     x0, #-1
    ret

//
// metal_compute_binding_hash - Compute hash of resource bindings
// Input: x0 = resource binding info
// Output: w0 = hash value
// Modifies: x0-x7
//
_metal_compute_binding_hash:
    mov     w1, #0              // Initialize hash
    
    // Hash vertex buffer pointer
    ldr     x2, [x0, #vertex_buffer]
    eor     x1, x1, x2
    ror     x1, x1, #13
    
    // Hash index buffer pointer
    ldr     x2, [x0, #index_buffer]
    eor     x1, x1, x2
    ror     x1, x1, #17
    
    // Hash texture count
    ldr     w2, [x0, #texture_count]
    eor     w1, w1, w2
    ror     w1, w1, #7
    
    // Hash first few textures
    add     x3, x0, #textures
    mov     w4, #0
    
.Lhash_texture_loop:
    cmp     w4, #4              // Hash first 4 textures
    b.ge    .Lhash_done
    cmp     w4, w2              // Don't exceed texture count
    b.ge    .Lhash_done
    
    ldr     x5, [x3, x4, lsl #3]
    eor     x1, x1, x5
    ror     x1, x1, #11
    
    add     w4, w4, #1
    b       .Lhash_texture_loop
    
.Lhash_done:
    mov     w0, w1              // Return hash
    ret

//
// apply_resource_bindings - Apply resource bindings to render encoder
// Input: x19 = render encoder, x20 = binding info
// Output: None
// Modifies: x0-x15
//
_apply_resource_bindings:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Bind vertex buffer
    ldr     x1, [x20, #vertex_buffer]
    mov     x0, x19
    mov     x2, #0              // Buffer index
    mov     x3, #0              // Offset
    bl      _render_encoder_set_vertex_buffer
    
    // Bind index buffer
    ldr     x1, [x20, #index_buffer]
    cmp     x1, #0
    b.eq    .Lapply_textures
    
    mov     x0, x19
    mov     x2, #0              // Index type
    bl      _render_encoder_set_index_buffer
    
.Lapply_textures:
    // Bind textures
    ldr     w21, [x20, #texture_count]
    cmp     w21, #0
    b.eq    .Lapply_uniforms
    
    add     x22, x20, #textures
    mov     w23, #0
    
.Lapply_texture_loop:
    cmp     w23, w21
    b.ge    .Lapply_uniforms
    
    ldr     x1, [x22, x23, lsl #3]
    mov     x0, x19
    mov     x2, x23             // Texture index
    bl      _render_encoder_set_fragment_texture
    
    add     w23, w23, #1
    b       .Lapply_texture_loop
    
.Lapply_uniforms:
    // Bind uniform buffers
    ldr     x1, [x20, #vertex_uniforms]
    cmp     x1, #0
    b.eq    .Lapply_bindings_done
    
    mov     x0, x19
    mov     x2, #1              // Buffer index
    mov     x3, #0              // Offset
    bl      _render_encoder_set_vertex_buffer
    
.Lapply_bindings_done:
    ldp     x29, x30, [sp], #16
    ret

//
// get_current_frame_number - Get current frame number (simplified)
// Input: None
// Output: w0 = frame number
// Modifies: x0-x3
//
_get_current_frame_number:
    // Simple frame counter implementation
    adrp    x0, frame_stats@PAGE
    add     x0, x0, frame_stats@PAGEOFF
    ldr     x1, [x0, #draw_calls_count]   // Use draw calls as frame counter
    mov     w0, w1
    ret

// Shader names and labels
.section __TEXT,__cstring,cstring_literals
vertex_shader_name:     .asciz "tile_vertex_shader"
fragment_shader_name:   .asciz "tile_fragment_shader"
frame_label:            .asciz "SimCity Frame Render"
render_pass_label:      .asciz "Main Render Pass"

// External Metal framework functions (to be linked)
.extern _MTLCreateSystemDefaultDevice
.extern _device_new_command_queue
.extern _device_new_default_library
.extern _device_new_buffer_with_length
.extern _device_new_render_pipeline_state
.extern _device_max_buffer_length
.extern _device_has_unified_memory
.extern _library_new_function_with_name
.extern _MTLVertexDescriptor_new
.extern _configure_vertex_attribute
.extern _configure_buffer_layout
.extern _create_render_pipeline_descriptor
.extern _command_queue_command_buffer
.extern _command_buffer_commit
.extern _command_buffer_wait_until_completed
.extern _command_buffer_reset
.extern _command_buffer_set_label
.extern _command_buffer_render_command_encoder
.extern _command_buffer_add_completed_handler
.extern _render_pass_set_label
.extern _render_encoder_set_render_pipeline_state
.extern _render_encoder_set_viewport
.extern _render_encoder_set_vertex_buffer
.extern _render_encoder_set_index_buffer
.extern _render_encoder_set_fragment_texture
.extern _release_object
.extern _get_system_time_ns
.extern _memset

.end