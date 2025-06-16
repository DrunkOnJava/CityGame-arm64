//
// sprite_batch_integration.s - Integration layer between sprite_batch.s and metal_encoder.s
// Sub-Agent 4: Graphics Pipeline Integrator
//
// Provides seamless integration between the sprite batching system and Metal command encoding:
// - Automatic Metal buffer binding for sprite vertices
// - Optimized draw call generation from sprite batches
// - Texture atlas management for batched sprites
// - NEON-optimized vertex data transfer to GPU
//
// Author: Sub-Agent 4 (Graphics Pipeline Integrator)
// Date: 2025-06-15
//

.section __TEXT,__text,regular,pure_instructions
.align 4

// Integration constants
.equ SPRITE_VERTEX_SIZE, 20             // 5 floats: x, y, u, v, color_packed
.equ VERTICES_PER_SPRITE, 4             // Quad rendering
.equ INDICES_PER_SPRITE, 6              // Two triangles
.equ MAX_TEXTURE_ATLASES, 32            // Maximum bound texture atlases

// Sprite-Metal integration state
.struct sprite_metal_state
    current_encoder:        .quad 1     // Active Metal render encoder
    vertex_buffer_gpu:      .quad 1     // GPU vertex buffer (MTLBuffer)
    index_buffer_gpu:       .quad 1     // GPU index buffer (MTLBuffer)
    
    // Pipeline states for different sprite types
    default_pipeline:       .quad 1     // Default sprite pipeline state
    alpha_pipeline:         .quad 1     // Alpha-blended sprite pipeline
    additive_pipeline:      .quad 1     // Additive blending pipeline
    
    // Texture management
    bound_atlases:          .quad MAX_TEXTURE_ATLASES
    atlas_bindings:         .long MAX_TEXTURE_ATLASES    // Texture slot bindings
    current_atlas_count:    .long 1     // Number of bound atlases
    
    // Batch state
    current_batch_id:       .long 1     // Current batch being processed
    vertices_uploaded:      .long 1     // Vertices uploaded this frame
    draw_calls_issued:      .long 1     // Draw calls issued this frame
.endstruct

// Global integration state
.data
.align 16
sprite_metal_integration:   .skip sprite_metal_state_size

// Pre-generated index buffer for quads (shared across all sprites)
sprite_quad_indices:
    .short 0, 1, 2, 2, 3, 0    // First quad
    .short 4, 5, 6, 6, 7, 4    // Second quad
    .short 8, 9, 10, 10, 11, 8 // Third quad
    .short 12, 13, 14, 14, 15, 12 // Fourth quad
    // ... continues for batch size

.text
.global _sprite_batch_metal_init
.global _sprite_batch_metal_set_encoder
.global _sprite_batch_metal_bind_atlas
.global _sprite_batch_metal_flush_batch
.global _sprite_batch_metal_upload_vertices
.global _sprite_batch_metal_draw_batch
.global _sprite_batch_metal_cleanup

//
// sprite_batch_metal_init - Initialize sprite-Metal integration
// Input: x0 = Metal device pointer
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15
//
_sprite_batch_metal_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0         // Save device
    
    // Initialize integration state
    adrp    x0, sprite_metal_integration@PAGE
    add     x0, x0, sprite_metal_integration@PAGEOFF
    mov     x1, #0
    mov     x2, #sprite_metal_state_size
    bl      _memset
    
    mov     x20, x0         // Save state pointer
    
    // Get GPU buffers from sprite batch system
    bl      _sprite_batch_get_gpu_vertex_buffer
    str     x0, [x20, #vertex_buffer_gpu]
    
    bl      _sprite_batch_get_gpu_index_buffer
    str     x0, [x20, #index_buffer_gpu]
    
    // Create pipeline states for different sprite rendering modes
    mov     x0, x19         // Device
    bl      _create_sprite_pipeline_states
    cmp     x0, #0
    b.ne    .Lsprite_metal_init_error
    
    // Initialize texture atlas bindings
    add     x0, x20, #bound_atlases
    mov     x1, #0
    mov     x2, #(8 * MAX_TEXTURE_ATLASES)
    bl      _memset
    
    mov     x0, #0          // Success
    b       .Lsprite_metal_init_exit
    
.Lsprite_metal_init_error:
    mov     x0, #-1         // Error
    
.Lsprite_metal_init_exit:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// sprite_batch_metal_set_encoder - Set active Metal render encoder
// Input: x0 = Metal render encoder pointer
// Output: None
// Modifies: x0-x3
//
_sprite_batch_metal_set_encoder:
    adrp    x1, sprite_metal_integration@PAGE
    add     x1, x1, sprite_metal_integration@PAGEOFF
    str     x0, [x1, #current_encoder]
    
    // Reset frame statistics
    str     wzr, [x1, #vertices_uploaded]
    str     wzr, [x1, #draw_calls_issued]
    str     wzr, [x1, #current_batch_id]
    
    ret

//
// sprite_batch_metal_bind_atlas - Bind texture atlas to Metal encoder
// Input: x0 = texture atlas pointer, w1 = texture slot
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x7
//
_sprite_batch_metal_bind_atlas:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0         // Save atlas
    mov     w20, w1         // Save slot
    
    // Validate slot
    cmp     w20, #MAX_TEXTURE_ATLASES
    b.ge    .Lbind_atlas_error
    
    adrp    x21, sprite_metal_integration@PAGE
    add     x21, x21, sprite_metal_integration@PAGEOFF
    
    // Store atlas in bindings
    add     x22, x21, #bound_atlases
    str     x19, [x22, x20, lsl #3]
    
    // Store slot mapping
    add     x22, x21, #atlas_bindings
    str     w20, [x22, x20, lsl #2]
    
    // Bind texture to Metal encoder
    ldr     x0, [x21, #current_encoder]
    mov     x1, x19         // Texture atlas
    mov     w2, w20         // Texture index
    bl      _metal_encoder_set_texture
    
    // Update atlas count
    ldr     w0, [x21, #current_atlas_count]
    cmp     w20, w0
    csel    w1, w20, w0, gt
    add     w1, w1, #1      // Max(slot + 1, current_count)
    str     w1, [x21, #current_atlas_count]
    
    mov     x0, #0          // Success
    b       .Lbind_atlas_exit
    
.Lbind_atlas_error:
    mov     x0, #-1         // Error
    
.Lbind_atlas_exit:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// sprite_batch_metal_flush_batch - Flush current sprite batch to Metal
// Input: x0 = batch index
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15, v0-v31
//
_sprite_batch_metal_flush_batch:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save batch index
    
    adrp    x20, sprite_metal_integration@PAGE
    add     x20, x20, sprite_metal_integration@PAGEOFF
    
    // Get batch information from sprite batch system
    mov     x0, x19
    bl      _sprite_batch_get_batch_info
    mov     x21, x0         // Batch info pointer
    cmp     x21, #0
    b.eq    .Lflush_batch_error
    
    // Get sprite count and texture for this batch
    ldrh    w22, [x21, #sprite_count]
    cmp     w22, #0
    b.eq    .Lflush_batch_done  // Empty batch
    
    ldrh    w23, [x21, #texture_id]
    
    // Set pipeline state based on batch properties
    ldrb    w0, [x21, #blend_mode]
    bl      _set_pipeline_for_blend_mode
    
    // Bind vertex and index buffers
    ldr     x0, [x20, #current_encoder]
    ldr     x1, [x20, #vertex_buffer_gpu]
    mov     w2, #0          // Buffer index 0
    ldr     w3, [x21, #vertex_offset]
    lsl     x3, x3, #5      // offset * SPRITE_VERTEX_SIZE * 4
    bl      _metal_encoder_set_vertex_buffer
    
    ldr     x0, [x20, #current_encoder]
    ldr     x1, [x20, #index_buffer_gpu]
    mov     w2, #0          // Index type: uint16
    ldr     w3, [x21, #index_offset]
    lsl     x3, x3, #1      // offset * sizeof(uint16)
    bl      _metal_encoder_set_index_buffer
    
    // Bind texture atlas
    ldr     x0, [x20, #current_encoder]
    add     x1, x20, #bound_atlases
    ldr     x1, [x1, x23, lsl #3]   // bound_atlases[texture_id]
    mov     w2, #0          // Texture index 0
    bl      _metal_encoder_set_texture
    
    // Issue draw call
    ldr     x0, [x20, #current_encoder]
    mov     w1, #3          // MTL_PRIMITIVE_TYPE_TRIANGLE
    lsl     w2, w22, #2     // sprite_count * INDICES_PER_SPRITE (6) / 1.5 = count * 4
    add     w2, w2, w22     
    add     w2, w2, w22     // sprite_count * 6
    mov     w3, #0          // Index type: uint16
    ldr     x4, [x20, #index_buffer_gpu]
    ldr     w5, [x21, #index_offset]
    lsl     x5, x5, #1      // offset * sizeof(uint16)
    bl      _metal_encoder_draw_indexed_primitives
    
    // Update statistics
    ldr     w0, [x20, #draw_calls_issued]
    add     w0, w0, #1
    str     w0, [x20, #draw_calls_issued]
    
    ldr     w0, [x20, #vertices_uploaded]
    lsl     w1, w22, #2     // sprite_count * 4 vertices
    add     w0, w0, w1
    str     w0, [x20, #vertices_uploaded]
    
.Lflush_batch_done:
    mov     x0, #0          // Success
    b       .Lflush_batch_exit
    
.Lflush_batch_error:
    mov     x0, #-1         // Error
    
.Lflush_batch_exit:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// sprite_batch_metal_upload_vertices - Upload sprite vertices to GPU using NEON
// Input: x0 = sprite batch, x1 = vertex count
// Output: x0 = GPU buffer offset
// Modifies: x0-x15, v0-v31
//
_sprite_batch_metal_upload_vertices:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save batch
    mov     x20, x1         // Save vertex count
    
    // Get GPU buffer contents pointer
    adrp    x21, sprite_metal_integration@PAGE
    add     x21, x21, sprite_metal_integration@PAGEOFF
    ldr     x0, [x21, #vertex_buffer_gpu]
    bl      _metal_buffer_contents
    mov     x22, x0         // GPU buffer base
    
    // Get current write offset from sprite batch system
    bl      _sprite_batch_get_vertex_write_offset
    mov     x23, x0         // Write offset
    
    // Calculate destination pointer
    add     x24, x22, x23, lsl #5  // base + offset * SPRITE_VERTEX_SIZE * 4
    
    // Upload vertices using NEON SIMD for optimal performance
    mov     x25, #0         // Vertex index
    
.Lupload_vertex_loop:
    cmp     x25, x20
    b.ge    .Lupload_vertices_done
    
    // Process 4 vertices at once using NEON
    add     x26, x20, #3
    sub     x26, x26, x25   // Remaining vertices
    cmp     x26, #4
    b.lt    .Lupload_vertex_single
    
    // SIMD upload of 4 vertices (320 bytes total)
    add     x0, x19, x25, lsl #5   // Source: batch + vertex_index * 32
    mov     x1, x24                // Destination GPU memory
    bl      _upload_4vertices_simd
    
    add     x24, x24, #320         // Advance destination (4 * 80 bytes)
    add     x25, x25, #4           // Advance vertex count
    b       .Lupload_vertex_loop
    
.Lupload_vertex_single:
    // Single vertex upload
    add     x0, x19, x25, lsl #5   // Source vertex
    ld1     {v0.4s, v1.4s}, [x0]   // Load 32 bytes (8 floats)
    st1     {v0.4s, v1.4s}, [x24]  // Store to GPU buffer
    
    add     x24, x24, #80          // Advance destination
    add     x25, x25, #1           // Next vertex
    b       .Lupload_vertex_loop
    
.Lupload_vertices_done:
    mov     x0, x23         // Return write offset
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// upload_4vertices_simd - Upload 4 vertices using NEON SIMD
// Input: x0 = source vertices, x1 = destination GPU memory
// Output: None
// Modifies: v0-v31
//
_upload_4vertices_simd:
    // Load 4 vertices (128 bytes) using NEON
    ld1     {v0.4s, v1.4s, v2.4s, v3.4s}, [x0], #64
    ld1     {v4.4s, v5.4s, v6.4s, v7.4s}, [x0]
    
    // Convert and pack vertices for GPU format
    // Each vertex: x, y, u, v, color_packed (20 bytes)
    // GPU format: x, y, 0, u, v, color_as_float (24 bytes padded to 32)
    
    // Process vertex 0
    mov     v16.s[0], v0.s[0]      // x
    mov     v16.s[1], v0.s[1]      // y
    fmov    s17, #0.0              // z = 0
    mov     v16.s[2], v17.s[0]     // z
    mov     v16.s[3], v0.s[2]      // u
    
    mov     v17.s[0], v0.s[3]      // v
    mov     w2, v0.s[4]            // color_packed
    bl      _unpack_color_to_float  // Convert to float
    mov     v17.s[1], v18.s[0]     // color as float
    
    // Store vertex 0 (32 bytes)
    st1     {v16.4s, v17.4s}, [x1], #32
    
    // Process vertex 1
    mov     v16.s[0], v1.s[0]      // x
    mov     v16.s[1], v1.s[1]      // y
    mov     v16.s[2], v17.s[0]     // z = 0
    mov     v16.s[3], v1.s[2]      // u
    
    mov     v17.s[0], v1.s[3]      // v
    mov     w2, v1.s[4]            // color_packed
    bl      _unpack_color_to_float
    mov     v17.s[1], v18.s[0]     // color as float
    
    st1     {v16.4s, v17.4s}, [x1], #32
    
    // Process vertex 2
    mov     v16.s[0], v2.s[0]      // x
    mov     v16.s[1], v2.s[1]      // y
    mov     v16.s[2], v17.s[0]     // z = 0
    mov     v16.s[3], v2.s[2]      // u
    
    mov     v17.s[0], v2.s[3]      // v
    mov     w2, v2.s[4]            // color_packed
    bl      _unpack_color_to_float
    mov     v17.s[1], v18.s[0]     // color as float
    
    st1     {v16.4s, v17.4s}, [x1], #32
    
    // Process vertex 3
    mov     v16.s[0], v3.s[0]      // x
    mov     v16.s[1], v3.s[1]      // y
    mov     v16.s[2], v17.s[0]     // z = 0
    mov     v16.s[3], v3.s[2]      // u
    
    mov     v17.s[0], v3.s[3]      // v
    mov     w2, v3.s[4]            // color_packed
    bl      _unpack_color_to_float
    mov     v17.s[1], v18.s[0]     // color as float
    
    st1     {v16.4s, v17.4s}, [x1]
    
    ret

//
// unpack_color_to_float - Convert packed RGBA color to float
// Input: w2 = packed color (RGBA8888)
// Output: s18 = color as float (for shader)
// Modifies: w3-w6, v18
//
_unpack_color_to_float:
    // Extract RGBA components
    and     w3, w2, #0xFF          // R
    lsr     w4, w2, #8
    and     w4, w4, #0xFF          // G
    lsr     w5, w2, #16
    and     w5, w5, #0xFF          // B
    lsr     w6, w2, #24            // A
    
    // Convert to normalized floats [0.0, 1.0]
    ucvtf   s19, w3
    fmov    s20, #255.0
    fdiv    s19, s19, s20          // R_float
    
    ucvtf   s20, w4
    fmov    s21, #255.0
    fdiv    s20, s20, s21          // G_float
    
    ucvtf   s21, w5
    fmov    s22, #255.0
    fdiv    s21, s21, s22          // B_float
    
    ucvtf   s22, w6
    fmov    s23, #255.0
    fdiv    s22, s22, s23          // A_float
    
    // Pack into single float for efficient shader use
    // This is a simplified packing - real implementation would depend on shader needs
    fmov    s18, s22               // Use alpha as representative value
    
    ret

//
// set_pipeline_for_blend_mode - Set appropriate pipeline state for blend mode
// Input: w0 = blend mode (0=none, 1=alpha, 2=additive)
// Output: None
// Modifies: x0-x7
//
_set_pipeline_for_blend_mode:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x1, sprite_metal_integration@PAGE
    add     x1, x1, sprite_metal_integration@PAGEOFF
    
    cmp     w0, #0
    b.eq    .Lset_default_pipeline
    cmp     w0, #1
    b.eq    .Lset_alpha_pipeline
    cmp     w0, #2
    b.eq    .Lset_additive_pipeline
    b       .Lset_pipeline_done     // Unknown mode, keep current
    
.Lset_default_pipeline:
    ldr     x0, [x1, #current_encoder]
    ldr     x1, [x1, #default_pipeline]
    bl      _metal_encoder_set_pipeline_state
    b       .Lset_pipeline_done
    
.Lset_alpha_pipeline:
    ldr     x0, [x1, #current_encoder]
    ldr     x1, [x1, #alpha_pipeline]
    bl      _metal_encoder_set_pipeline_state
    b       .Lset_pipeline_done
    
.Lset_additive_pipeline:
    ldr     x0, [x1, #current_encoder]
    ldr     x1, [x1, #additive_pipeline]
    bl      _metal_encoder_set_pipeline_state
    
.Lset_pipeline_done:
    ldp     x29, x30, [sp], #16
    ret

//
// create_sprite_pipeline_states - Create Metal pipeline states for sprite rendering
// Input: x0 = Metal device
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15
//
_create_sprite_pipeline_states:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0         // Save device
    
    adrp    x20, sprite_metal_integration@PAGE
    add     x20, x20, sprite_metal_integration@PAGEOFF
    
    // Create default pipeline (no blending)
    mov     x0, x19
    mov     w1, #0          // No blending
    bl      _create_sprite_pipeline
    cmp     x0, #0
    b.eq    .Lcreate_pipelines_error
    str     x0, [x20, #default_pipeline]
    
    // Create alpha blend pipeline
    mov     x0, x19
    mov     w1, #1          // Alpha blending
    bl      _create_sprite_pipeline
    cmp     x0, #0
    b.eq    .Lcreate_pipelines_error
    str     x0, [x20, #alpha_pipeline]
    
    // Create additive blend pipeline
    mov     x0, x19
    mov     w1, #2          // Additive blending
    bl      _create_sprite_pipeline
    cmp     x0, #0
    b.eq    .Lcreate_pipelines_error
    str     x0, [x20, #additive_pipeline]
    
    mov     x0, #0          // Success
    b       .Lcreate_pipelines_exit
    
.Lcreate_pipelines_error:
    mov     x0, #-1         // Error
    
.Lcreate_pipelines_exit:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// Helper function stubs (would be implemented with full Metal integration)
_create_sprite_pipeline:
    // Create Metal render pipeline state for sprite rendering
    mov     x0, #0          // Stub - return dummy pipeline
    ret

_sprite_batch_get_gpu_vertex_buffer:
    // Get GPU vertex buffer from sprite batch system
    mov     x0, #0          // Stub
    ret

_sprite_batch_get_gpu_index_buffer:
    // Get GPU index buffer from sprite batch system
    mov     x0, #0          // Stub
    ret

_sprite_batch_get_batch_info:
    // Get batch information structure
    mov     x0, #0          // Stub
    ret

_sprite_batch_get_vertex_write_offset:
    // Get current vertex write offset
    mov     x0, #0          // Stub
    ret

_metal_buffer_contents:
    // Get Metal buffer contents pointer
    mov     x0, #0          // Stub
    ret

// External function declarations
.extern _memset
.extern _memcpy
.extern _metal_encoder_set_vertex_buffer
.extern _metal_encoder_set_index_buffer
.extern _metal_encoder_set_texture
.extern _metal_encoder_set_pipeline_state
.extern _metal_encoder_draw_indexed_primitives

.end