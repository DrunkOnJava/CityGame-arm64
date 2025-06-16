//
// sprite_batch.s - Sprite batching system optimized for TBDR on Apple Silicon
// Agent 3: Graphics & Rendering Pipeline
//
// Implements efficient sprite batching specifically optimized for Apple GPU's
// Tile-Based Deferred Renderer (TBDR) architecture:
// - Screen-space tile binning for optimal TBDR performance
// - Dynamic batching to minimize draw calls (<1000 per frame)
// - Memory-efficient vertex streaming for Apple Silicon unified memory
// - NEON SIMD optimized batch processing
//
// Performance targets:
// - < 1000 draw calls per frame
// - 60-120 FPS with 1M sprites
// - Efficient tile bin utilization
// - Minimal GPU state changes
//
// Author: Agent 3 (Graphics)
// Date: 2025-06-15
//

.section __TEXT,__text,regular,pure_instructions
.align 4

// TBDR and batching constants
.equ MAX_BATCH_SIZE, 2048          // Sprites per batch
.equ MAX_BATCHES, 512              // Total batches
.equ SCREEN_TILE_SIZE, 32          // Apple GPU tile size
.equ MAX_SCREEN_TILES_X, 64        // 2048 / 32
.equ MAX_SCREEN_TILES_Y, 64        // 2048 / 32
.equ MAX_TEXTURES_PER_BATCH, 16    // Texture atlas slots
.equ VERTEX_BUFFER_SIZE, 0x400000  // 4MB vertex buffer
.equ INDEX_BUFFER_SIZE, 0x180000   // 1.5MB index buffer

// Sprite batching structures
.struct sprite_instance
    position:       .float 2    // Screen X, Y
    size:           .float 2    // Width, Height
    uv_rect:        .float 4    // U1, V1, U2, V2
    color:          .long 1     // RGBA color
    texture_id:     .short 1    // Texture atlas ID
    depth:          .float 1    // Z-depth
    rotation:       .float 1    // Rotation angle
.endstruct

.struct instance_data
    world_matrix:   .float 16   // World transformation matrix
    uv_transform:   .float 4    // UV transformation (offset, scale)
    color_mult:     .float 4    // Color multiplier (RGBA)
    instance_id:    .long 1     // Instance identifier
    .align 16
.endstruct

.struct instanced_batch
    base_mesh:      .quad 1     // Base mesh vertex buffer
    instance_buffer: .quad 1    // Instance data buffer
    instance_count: .long 1     // Number of instances
    max_instances:  .long 1     // Maximum instances per batch
    texture_atlas:  .quad 1     // Shared texture atlas
    vertex_count:   .long 1     // Vertices per instance
    index_count:    .long 1     // Indices per instance
.endstruct

.struct sprite_batch
    texture_id:     .short 1    // Primary texture
    blend_mode:     .byte 1     // Blending mode
    shader_id:      .byte 1     // Shader variant
    sprite_count:   .short 1    // Number of sprites
    vertex_offset:  .long 1     // Vertex buffer offset
    index_offset:   .long 1     // Index buffer offset
    screen_tiles:   .quad 1     // Bitmask of affected screen tiles
.endstruct

.struct screen_tile_bin
    batch_list:     .quad 1     // Linked list of batches
    sprite_count:   .short 1    // Sprites in this tile
    depth_range:    .float 2    // Min/max depth in tile
.endstructure

.struct batch_renderer_state
    current_batch:      .long 1     // Current batch index
    total_batches:      .long 1     // Total batches this frame
    vertex_write_pos:   .long 1     // Current vertex write position
    index_write_pos:    .long 1     // Current index write position
    draw_calls_issued:  .long 1     // Number of draw calls
    sprites_rendered:   .long 1     // Total sprites rendered
.endstruct

// Global batching state
.data
.align 16
renderer_state:         .skip batch_renderer_state_size
sprite_batches:         .skip sprite_batch_size * MAX_BATCHES
instanced_batches:      .skip instanced_batch_size * 64
screen_tile_bins:       .skip screen_tile_bin_size * MAX_SCREEN_TILES_X * MAX_SCREEN_TILES_Y
staging_sprites:        .skip sprite_instance_size * MAX_BATCH_SIZE * MAX_BATCHES
instance_data_staging:  .skip instance_data_size * 8192    // 8K instances max

// Vertex buffer layout for sprites (interleaved)
.struct sprite_vertex
    position:   .float 2    // Screen position
    uv:         .float 2    // Texture coordinates
    color:      .byte 4     // RGBA (packed)
.endstruct

// Pre-allocated GPU buffers
.bss
.align 16
vertex_stream_buffer:   .skip VERTEX_BUFFER_SIZE
index_stream_buffer:    .skip INDEX_BUFFER_SIZE
gpu_vertex_buffer:      .quad 1     // MTLBuffer pointer
gpu_index_buffer:       .quad 1     // MTLBuffer pointer

// Performance counters
batch_stats:
    batches_created:    .quad 1
    batches_merged:     .quad 1
    draw_calls_saved:   .quad 1
    tile_bins_used:     .quad 1
    gpu_memory_used:    .quad 1

.text
.global _sprite_batch_init
.global _sprite_batch_begin_frame
.global _sprite_batch_add_sprite
.global _sprite_batch_flush_batches
.global _sprite_batch_end_frame
.global _sprite_batch_optimize_tiles
.global _sprite_batch_get_stats
.global _sprite_batch_create_instanced
.global _sprite_batch_add_instance
.global _sprite_batch_render_instanced
.global _sprite_batch_update_instance_buffer
.global _sprite_batch_optimize_instances

//
// sprite_batch_init - Initialize sprite batching system
// Input: x0 = Metal device pointer
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15
//
_sprite_batch_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0         // Save device pointer
    
    // Initialize renderer state
    adrp    x0, renderer_state@PAGE
    add     x0, x0, renderer_state@PAGEOFF
    mov     x1, #0
    mov     x2, #batch_renderer_state_size
    bl      _memset
    
    // Initialize sprite batches array
    adrp    x0, sprite_batches@PAGE
    add     x0, x0, sprite_batches@PAGEOFF
    mov     x1, #0
    mov     x2, #(sprite_batch_size * MAX_BATCHES)
    bl      _memset
    
    // Initialize screen tile bins
    adrp    x0, screen_tile_bins@PAGE
    add     x0, x0, screen_tile_bins@PAGEOFF
    mov     x1, #0
    mov     x2, #(screen_tile_bin_size * MAX_SCREEN_TILES_X * MAX_SCREEN_TILES_Y)
    bl      _memset
    
    // Create GPU vertex buffer
    mov     x0, x19
    mov     x1, #VERTEX_BUFFER_SIZE
    mov     x2, #0          // MTL_RESOURCE_STORAGE_MODE_SHARED
    bl      _device_new_buffer_with_length
    cmp     x0, #0
    b.eq    .Linit_error
    adrp    x1, gpu_vertex_buffer@PAGE
    add     x1, x1, gpu_vertex_buffer@PAGEOFF
    str     x0, [x1]
    
    // Create GPU index buffer
    mov     x0, x19
    mov     x1, #INDEX_BUFFER_SIZE
    mov     x2, #0          // MTL_RESOURCE_STORAGE_MODE_SHARED
    bl      _device_new_buffer_with_length
    cmp     x0, #0
    b.eq    .Linit_error
    adrp    x1, gpu_index_buffer@PAGE
    add     x1, x1, gpu_index_buffer@PAGEOFF
    str     x0, [x1]
    
    // Get buffer contents pointers for CPU writing
    adrp    x0, gpu_vertex_buffer@PAGE
    add     x0, x0, gpu_vertex_buffer@PAGEOFF
    ldr     x0, [x0]
    bl      _buffer_contents
    adrp    x1, vertex_stream_buffer@PAGE
    add     x1, x1, vertex_stream_buffer@PAGEOFF
    str     x0, [x1, #-8]   // Store pointer before buffer
    
    adrp    x0, gpu_index_buffer@PAGE
    add     x0, x0, gpu_index_buffer@PAGEOFF
    ldr     x0, [x0]
    bl      _buffer_contents
    adrp    x1, index_stream_buffer@PAGE
    add     x1, x1, index_stream_buffer@PAGEOFF
    str     x0, [x1, #-8]   // Store pointer before buffer
    
    mov     x0, #0          // Success
    b       .Linit_exit
    
.Linit_error:
    mov     x0, #-1         // Error
    
.Linit_exit:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// sprite_batch_begin_frame - Begin new frame batch processing
// Input: None
// Output: None
// Modifies: x0-x7
//
_sprite_batch_begin_frame:
    // Reset frame state
    adrp    x0, renderer_state@PAGE
    add     x0, x0, renderer_state@PAGEOFF
    mov     x1, #0
    str     x1, [x0, #current_batch]
    str     x1, [x0, #total_batches]
    str     x1, [x0, #vertex_write_pos]
    str     x1, [x0, #index_write_pos]
    str     x1, [x0, #draw_calls_issued]
    str     x1, [x0, #sprites_rendered]
    
    // Clear screen tile bins
    adrp    x0, screen_tile_bins@PAGE
    add     x0, x0, screen_tile_bins@PAGEOFF
    mov     x1, #0
    mov     x2, #(screen_tile_bin_size * MAX_SCREEN_TILES_X * MAX_SCREEN_TILES_Y)
    bl      _memset
    
    ret

//
// sprite_batch_add_sprite - Add sprite to batching system
// Input: x0 = sprite_instance pointer
// Output: x0 = 0 on success, -1 if batch full
// Modifies: x0-x15
//
_sprite_batch_add_sprite:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save sprite pointer
    
    // Load sprite data for analysis
    ldr     s0, [x19, #position]        // X
    ldr     s1, [x19, #position + 4]    // Y
    ldr     s2, [x19, #size]            // Width
    ldr     s3, [x19, #size + 4]        // Height
    ldrh    w4, [x19, #texture_id]
    
    // Calculate affected screen tiles
    bl      _calculate_affected_tiles
    mov     x20, x0         // Save tile mask
    
    // Find or create appropriate batch
    mov     x0, w4          // Texture ID
    mov     x1, x20         // Tile mask
    bl      _find_compatible_batch
    mov     x21, x0         // Batch index
    
    cmp     x21, #-1
    b.eq    .Ladd_sprite_create_batch
    
    // Add to existing batch
    b       .Ladd_sprite_to_batch
    
.Ladd_sprite_create_batch:
    // Create new batch
    bl      _create_new_batch
    mov     x21, x0
    cmp     x21, #-1
    b.eq    .Ladd_sprite_error
    
.Ladd_sprite_to_batch:
    // Add sprite to batch
    mov     x0, x21         // Batch index
    mov     x1, x19         // Sprite data
    bl      _add_sprite_to_batch_internal
    cmp     x0, #0
    b.ne    .Ladd_sprite_error
    
    // Update screen tile bins
    mov     x0, x20         // Tile mask
    mov     x1, x21         // Batch index
    bl      _update_tile_bins
    
    mov     x0, #0          // Success
    b       .Ladd_sprite_exit
    
.Ladd_sprite_error:
    mov     x0, #-1         // Error
    
.Ladd_sprite_exit:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// calculate_affected_tiles - Calculate which screen tiles sprite affects
// Input: s0-s3 = sprite bounds (x, y, width, height)
// Output: x0 = tile bitmask (64-bit for up to 64 tiles)
// Modifies: x0-x7, v0-v7
//
_calculate_affected_tiles:
    // Convert sprite bounds to tile coordinates
    fmov    s4, #SCREEN_TILE_SIZE
    fdiv    s5, s0, s4      // left_tile = x / tile_size
    fdiv    s6, s1, s4      // top_tile = y / tile_size
    fadd    s7, s0, s2      // right = x + width
    fadd    s8, s1, s3      // bottom = y + height
    fdiv    s7, s7, s4      // right_tile = right / tile_size
    fdiv    s8, s8, s4      // bottom_tile = bottom / tile_size
    
    // Convert to integer tile indices
    fcvtms  w0, s5          // left_tile (floor)
    fcvtms  w1, s6          // top_tile (floor)
    fcvtps  w2, s7          // right_tile (ceil)
    fcvtps  w3, s8          // bottom_tile (ceil)
    
    // Clamp to valid tile range
    cmp     w0, #0
    csel    w0, w0, wzr, ge
    cmp     w1, #0
    csel    w1, w1, wzr, ge
    cmp     w2, #MAX_SCREEN_TILES_X
    mov     w4, #MAX_SCREEN_TILES_X
    csel    w2, w2, w4, le
    cmp     w3, #MAX_SCREEN_TILES_Y
    mov     w5, #MAX_SCREEN_TILES_Y
    csel    w3, w3, w5, le
    
    // Generate tile bitmask (simplified for 8x8 tiles in 64-bit mask)
    mov     x6, #0          // Result bitmask
    mov     w7, w1          // Current Y
    
.Ltile_y_loop:
    cmp     w7, w3
    b.ge    .Ltile_done
    
    mov     w8, w0          // Current X
    
.Ltile_x_loop:
    cmp     w8, w2
    b.ge    .Ltile_x_done
    
    // Calculate tile index and set bit
    mul     w9, w7, #8      // Assuming 8x8 tile grid for bitmask
    add     w9, w9, w8
    cmp     w9, #64
    b.ge    .Ltile_x_next   // Skip if beyond 64-bit mask
    
    mov     x10, #1
    lsl     x10, x10, x9
    orr     x6, x6, x10
    
.Ltile_x_next:
    add     w8, w8, #1
    b       .Ltile_x_loop
    
.Ltile_x_done:
    add     w7, w7, #1
    b       .Ltile_y_loop
    
.Ltile_done:
    mov     x0, x6          // Return bitmask
    ret

//
// find_compatible_batch - Find existing batch compatible with sprite
// Input: w0 = texture_id, x1 = tile_mask
// Output: x0 = batch index, -1 if none found
// Modifies: x0-x7
//
_find_compatible_batch:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     w19, w0         // Save texture_id
    mov     x20, x1         // Save tile_mask
    
    // Get current batch count
    adrp    x0, renderer_state@PAGE
    add     x0, x0, renderer_state@PAGEOFF
    ldr     w1, [x0, #total_batches]
    
    mov     w2, #0          // Batch index
    
.Lfind_batch_loop:
    cmp     w2, w1
    b.ge    .Lfind_batch_not_found
    
    // Get batch pointer
    adrp    x3, sprite_batches@PAGE
    add     x3, x3, sprite_batches@PAGEOFF
    add     x3, x3, x2, lsl #6    // batch_index * 64 (sprite_batch_size)
    
    // Check texture compatibility
    ldrh    w4, [x3, #texture_id]
    cmp     w4, w19
    b.ne    .Lfind_batch_next
    
    // Check if batch has room
    ldrh    w4, [x3, #sprite_count]
    cmp     w4, #MAX_BATCH_SIZE
    b.ge    .Lfind_batch_next
    
    // Check tile overlap (TBDR optimization)
    ldr     x4, [x3, #screen_tiles]
    and     x5, x4, x20     // Overlap mask
    cmp     x5, #0
    b.eq    .Lfind_batch_next   // No overlap, different tiles
    
    // Found compatible batch
    mov     x0, x2
    b       .Lfind_batch_exit
    
.Lfind_batch_next:
    add     w2, w2, #1
    b       .Lfind_batch_loop
    
.Lfind_batch_not_found:
    mov     x0, #-1
    
.Lfind_batch_exit:
    ldp     x29, x30, [sp], #16
    ret

//
// create_new_batch - Create new sprite batch
// Input: None
// Output: x0 = batch index, -1 if no space
// Modifies: x0-x7
//
_create_new_batch:
    // Check if we have space for new batch
    adrp    x0, renderer_state@PAGE
    add     x0, x0, renderer_state@PAGEOFF
    ldr     w1, [x0, #total_batches]
    
    cmp     w1, #MAX_BATCHES
    b.ge    .Lcreate_batch_error
    
    // Initialize new batch
    adrp    x2, sprite_batches@PAGE
    add     x2, x2, sprite_batches@PAGEOFF
    add     x2, x2, x1, lsl #6    // batch_index * 64
    
    // Clear batch structure
    mov     x3, #0
    str     x3, [x2, #texture_id]
    str     x3, [x2, #sprite_count]
    str     x3, [x2, #screen_tiles]
    
    // Increment batch count
    add     w1, w1, #1
    str     w1, [x0, #total_batches]
    
    // Return new batch index
    sub     x0, x1, #1
    ret
    
.Lcreate_batch_error:
    mov     x0, #-1
    ret

//
// sprite_batch_flush_batches - Generate GPU commands for all batches
// Input: x0 = render encoder
// Output: None
// Modifies: x0-x15, v0-v31
//
_sprite_batch_flush_batches:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save render encoder
    
    // Get total batch count
    adrp    x0, renderer_state@PAGE
    add     x0, x0, renderer_state@PAGEOFF
    ldr     w20, [x0, #total_batches]
    
    mov     w21, #0         // Current batch index
    
.Lflush_batch_loop:
    cmp     w21, w20
    b.ge    .Lflush_batch_done
    
    // Process batch using SIMD for vertex generation
    mov     x0, x21         // Batch index
    bl      _generate_batch_vertices
    
    // Get batch data
    adrp    x22, sprite_batches@PAGE
    add     x22, x22, sprite_batches@PAGEOFF
    add     x22, x22, x21, lsl #6
    
    ldrh    w0, [x22, #sprite_count]
    cmp     w0, #0
    b.eq    .Lflush_batch_next  // Skip empty batches
    
    // Set texture for batch
    mov     x0, x19         // Render encoder
    ldrh    w1, [x22, #texture_id]
    bl      _set_fragment_texture
    
    // Draw batch
    mov     x0, x19         // Render encoder
    ldr     w1, [x22, #vertex_offset]
    ldrh    w2, [x22, #sprite_count]
    lsl     w2, w2, #2      // * 4 vertices per sprite
    bl      _draw_batch_primitives
    
    // Update statistics
    adrp    x0, renderer_state@PAGE
    add     x0, x0, renderer_state@PAGEOFF
    ldr     w1, [x0, #draw_calls_issued]
    add     w1, w1, #1
    str     w1, [x0, #draw_calls_issued]
    
    ldr     w1, [x0, #sprites_rendered]
    ldrh    w2, [x22, #sprite_count]
    add     w1, w1, w2
    str     w1, [x0, #sprites_rendered]
    
.Lflush_batch_next:
    add     w21, w21, #1
    b       .Lflush_batch_loop
    
.Lflush_batch_done:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// generate_batch_vertices - Generate vertices for a batch using NEON SIMD
// Input: x0 = batch index
// Output: None
// Modifies: x0-x15, v0-v31
//
_generate_batch_vertices:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save batch index
    
    // Get batch data
    adrp    x20, sprite_batches@PAGE
    add     x20, x20, sprite_batches@PAGEOFF
    add     x20, x20, x19, lsl #6
    
    ldrh    w0, [x20, #sprite_count]
    cmp     w0, #0
    b.eq    .Lgen_vertices_done
    
    // Get vertex buffer write position
    adrp    x1, renderer_state@PAGE
    add     x1, x1, renderer_state@PAGEOFF
    ldr     w2, [x1, #vertex_write_pos]
    str     w2, [x20, #vertex_offset]  // Store for draw call
    
    // Calculate vertices using SIMD processing
    adrp    x21, staging_sprites@PAGE
    add     x21, x21, staging_sprites@PAGEOFF
    add     x21, x21, x19, lsl #15    // batch_index * 32KB (MAX_BATCH_SIZE * sprite_instance_size)
    
    // Get CPU vertex buffer pointer
    adrp    x22, vertex_stream_buffer@PAGE
    add     x22, x22, vertex_stream_buffer@PAGEOFF
    ldr     x22, [x22, #-8]    // Get stored pointer
    add     x22, x22, x2, lsl #5   // Add offset * 32 (sprite_vertex_size * 4)
    
    mov     w3, #0          // Sprite index
    
    // Process 4 sprites in parallel when possible
.Lgen_vertex_sprite_loop:
    cmp     w3, w0
    b.ge    .Lgen_vertex_sprite_done
    
    // Check if we can process 4 sprites in parallel
    sub     w4, w0, w3      // Remaining sprites
    cmp     w4, #4
    b.lt    .Lgen_vertex_single
    
    // SIMD path: Process 4 sprites at once
    bl      _generate_4sprites_simd
    add     w3, w3, #4
    b       .Lgen_vertex_sprite_loop
    
.Lgen_vertex_single:
    // Load sprite data (single sprite processing)
    add     x4, x21, x3, lsl #5    // sprite_index * 32
    
    // Load position and size
    ld1     {v0.4s}, [x4], #16      // position.xy, size.xy
    ld1     {v1.4s}, [x4], #16      // uv_rect
    ldr     w5, [x4], #4            // color
    ldrh    w6, [x4], #2            // texture_id
    ldr     s2, [x4], #4            // depth
    ldr     s3, [x4]                // rotation
    
    // Generate 4 vertices for sprite quad using SIMD
    // Calculate corner positions with rotation support
    bl      _generate_quad_vertices_rotated
    
    add     w3, w3, #1
    b       .Lgen_vertex_sprite_loop
    
.Lgen_vertex_sprite_done:
    // Update vertex write position
    lsl     w0, w0, #2              // sprites * 4 vertices
    lsl     w0, w0, #3              // * 8 (20 bytes per vertex, rounded to 32)
    adrp    x1, renderer_state@PAGE
    add     x1, x1, renderer_state@PAGEOFF
    ldr     w2, [x1, #vertex_write_pos]
    add     w2, w2, w0
    str     w2, [x1, #vertex_write_pos]
    
.Lgen_vertices_done:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// generate_4sprites_simd - Generate vertices for 4 sprites using NEON SIMD parallel processing
// Input: x21 = sprite data base, x22 = vertex buffer, w3 = sprite index
// Output: None, updates x22 vertex buffer pointer
// Modifies: v0-v31, x4-x7
//
_generate_4sprites_simd:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Load 4 sprites worth of data in parallel
    add     x4, x21, x3, lsl #5     // First sprite offset
    
    // Load positions for all 4 sprites (8 floats: x1,y1,x2,y2,x3,y3,x4,y4)
    ld1     {v0.4s}, [x4], #32      // sprite0: pos.xy, size.xy
    ld1     {v1.4s}, [x4], #32      // sprite1: pos.xy, size.xy  
    ld1     {v2.4s}, [x4], #32      // sprite2: pos.xy, size.xy
    ld1     {v3.4s}, [x4], #32      // sprite3: pos.xy, size.xy
    
    // Load UV coordinates for all 4 sprites
    sub     x4, x4, #96            // Back to start + 16 bytes offset
    add     x4, x4, #16
    ld1     {v4.4s}, [x4], #32      // sprite0: uv_rect
    ld1     {v5.4s}, [x4], #32      // sprite1: uv_rect
    ld1     {v6.4s}, [x4], #32      // sprite2: uv_rect
    ld1     {v7.4s}, [x4], #32      // sprite3: uv_rect
    
    // Load colors for all 4 sprites (pack into single vector)
    sub     x4, x4, #96            // Back to start + 32 bytes offset
    add     x4, x4, #32
    ldr     w5, [x4], #32          // sprite0 color
    ldr     w6, [x4], #32          // sprite1 color
    ldr     w7, [x4], #32          // sprite2 color
    ldr     w8, [x4]               // sprite3 color
    
    // Pack colors into SIMD register
    fmov    s16, w5
    mov     v16.s[1], w6
    mov     v16.s[2], w7
    mov     v16.s[3], w8
    
    // Calculate all 4 sprite quad positions using SIMD
    // Extract X positions: v8 = [x0, x1, x2, x3]
    mov     v8.s[0], v0.s[0]
    mov     v8.s[1], v1.s[0] 
    mov     v8.s[2], v2.s[0]
    mov     v8.s[3], v3.s[0]
    
    // Extract Y positions: v9 = [y0, y1, y2, y3]
    mov     v9.s[0], v0.s[1]
    mov     v9.s[1], v1.s[1]
    mov     v9.s[2], v2.s[1]
    mov     v9.s[3], v3.s[1]
    
    // Extract half-widths: v10 = [w0/2, w1/2, w2/2, w3/2]
    mov     v10.s[0], v0.s[2]
    mov     v10.s[1], v1.s[2]
    mov     v10.s[2], v2.s[2]
    mov     v10.s[3], v3.s[2]
    fmov    s20, #0.5
    dup     v20.4s, v20.s[0]
    fmul    v10.4s, v10.4s, v20.4s
    
    // Extract half-heights: v11 = [h0/2, h1/2, h2/2, h3/2]
    mov     v11.s[0], v0.s[3]
    mov     v11.s[1], v1.s[3]
    mov     v11.s[2], v2.s[3]
    mov     v11.s[3], v3.s[3]
    fmul    v11.4s, v11.4s, v20.4s
    
    // Calculate corner positions for all sprites in parallel
    fsub    v12.4s, v8.4s, v10.4s  // left = x - width/2
    fadd    v13.4s, v8.4s, v10.4s  // right = x + width/2
    fsub    v14.4s, v9.4s, v11.4s  // top = y - height/2
    fadd    v15.4s, v9.4s, v11.4s  // bottom = y + height/2
    
    // Generate vertices for all 4 sprites (16 vertices total)
    mov     w9, #0                 // Sprite counter
    
.Lsimd_sprite_loop:
    cmp     w9, #4
    b.ge    .Lsimd_sprites_done
    
    // Extract current sprite's corner positions
    mov     s21, v12.s[w9, uxtw]   // left
    mov     s22, v13.s[w9, uxtw]   // right
    mov     s23, v14.s[w9, uxtw]   // top
    mov     s24, v15.s[w9, uxtw]   // bottom
    
    // Extract current sprite's UV coordinates
    add     x5, sp, #-64           // Temp space for UV extraction
    cmp     w9, #0
    b.eq    .Luse_v4
    cmp     w9, #1
    b.eq    .Luse_v5
    cmp     w9, #2
    b.eq    .Luse_v6
    // w9 == 3, use v7
    st1     {v7.4s}, [x5]
    b       .Lextract_uv
.Luse_v4:
    st1     {v4.4s}, [x5]
    b       .Lextract_uv
.Luse_v5:
    st1     {v5.4s}, [x5]
    b       .Lextract_uv
.Luse_v6:
    st1     {v6.4s}, [x5]
    
.Lextract_uv:
    ld1     {v25.4s}, [x5]         // Current sprite UV
    
    // Extract current sprite color
    mov     w10, v16.s[w9, uxtw]
    
    // Vertex 0: top-left
    str     s21, [x22], #4         // left x
    str     s23, [x22], #4         // top y
    str     s25, [x22], #4         // u1
    fmov    s26, v25.s[1]
    str     s26, [x22], #4         // v1
    str     w10, [x22], #4         // color
    
    // Vertex 1: top-right
    str     s22, [x22], #4         // right x
    str     s23, [x22], #4         // top y
    fmov    s27, v25.s[2]
    str     s27, [x22], #4         // u2
    str     s26, [x22], #4         // v1
    str     w10, [x22], #4         // color
    
    // Vertex 2: bottom-right
    str     s22, [x22], #4         // right x
    str     s24, [x22], #4         // bottom y
    str     s27, [x22], #4         // u2
    fmov    s28, v25.s[3]
    str     s28, [x22], #4         // v2
    str     w10, [x22], #4         // color
    
    // Vertex 3: bottom-left
    str     s21, [x22], #4         // left x
    str     s24, [x22], #4         // bottom y
    str     s25, [x22], #4         // u1
    str     s28, [x22], #4         // v2
    str     w10, [x22], #4         // color
    
    add     w9, w9, #1
    b       .Lsimd_sprite_loop
    
.Lsimd_sprites_done:
    ldp     x29, x30, [sp], #16
    ret

//
// generate_quad_vertices_rotated - Generate quad vertices with rotation support
// Input: v0.4s = position+size, v1.4s = uv_rect, w5 = color, s3 = rotation
// Output: Writes 4 vertices to x22 buffer
// Modifies: v0-v15, s20-s31
//
_generate_quad_vertices_rotated:
    // Check if rotation is needed
    fmov    s20, #0.0
    fcmp    s3, s20
    b.eq    .Lno_rotation
    
    // Rotation path: Calculate rotated quad vertices
    // Get center position
    fmov    s21, v0.s[0]           // center_x
    fmov    s22, v0.s[1]           // center_y
    
    // Get half dimensions
    fmov    s23, v0.s[2]
    fmov    s24, v0.s[3]
    fmov    s25, #0.5
    fmul    s23, s23, s25          // half_width
    fmul    s24, s24, s25          // half_height
    
    // Pre-calculate sin/cos
    fmov    s26, s3                // rotation angle
    bl      _fast_sin_cos          // Returns sin in s27, cos in s28
    
    // Calculate rotated corner offsets
    // For each corner: rotated_x = cos*dx - sin*dy, rotated_y = sin*dx + cos*dy
    
    // Corner 0: top-left (-half_width, -half_height)
    fneg    s29, s23               // -half_width
    fneg    s30, s24               // -half_height
    fmul    s31, s28, s29          // cos * (-half_width)
    fmls    s31, s27, s30          // - sin * (-half_height)
    fadd    s31, s31, s21          // + center_x = final x0
    
    fmul    s0, s27, s29           // sin * (-half_width)
    fmla    s0, s28, s30           // + cos * (-half_height)
    fadd    s0, s0, s22            // + center_y = final y0
    
    // Store vertex 0
    str     s31, [x22], #4         // x
    str     s0, [x22], #4          // y
    str     s1, [x22], #4          // u1
    fmov    s2, v1.s[1]
    str     s2, [x22], #4          // v1
    str     w5, [x22], #4          // color
    
    // Corner 1: top-right (half_width, -half_height)
    fmul    s31, s28, s23          // cos * half_width
    fmls    s31, s27, s30          // - sin * (-half_height)
    fadd    s31, s31, s21          // + center_x = final x1
    
    fmul    s0, s27, s23           // sin * half_width
    fmla    s0, s28, s30           // + cos * (-half_height)
    fadd    s0, s0, s22            // + center_y = final y1
    
    // Store vertex 1
    str     s31, [x22], #4         // x
    str     s0, [x22], #4          // y
    fmov    s3, v1.s[2]
    str     s3, [x22], #4          // u2
    str     s2, [x22], #4          // v1
    str     w5, [x22], #4          // color
    
    // Corner 2: bottom-right (half_width, half_height)
    fmul    s31, s28, s23          // cos * half_width
    fmls    s31, s27, s24          // - sin * half_height
    fadd    s31, s31, s21          // + center_x = final x2
    
    fmul    s0, s27, s23           // sin * half_width
    fmla    s0, s28, s24           // + cos * half_height
    fadd    s0, s0, s22            // + center_y = final y2
    
    // Store vertex 2
    str     s31, [x22], #4         // x
    str     s0, [x22], #4          // y
    str     s3, [x22], #4          // u2
    fmov    s4, v1.s[3]
    str     s4, [x22], #4          // v2
    str     w5, [x22], #4          // color
    
    // Corner 3: bottom-left (-half_width, half_height)
    fneg    s29, s23               // -half_width
    fmul    s31, s28, s29          // cos * (-half_width)
    fmls    s31, s27, s24          // - sin * half_height
    fadd    s31, s31, s21          // + center_x = final x3
    
    fmul    s0, s27, s29           // sin * (-half_width)
    fmla    s0, s28, s24           // + cos * half_height
    fadd    s0, s0, s22            // + center_y = final y3
    
    // Store vertex 3
    str     s31, [x22], #4         // x
    str     s0, [x22], #4          // y
    str     s1, [x22], #4          // u1
    str     s4, [x22], #4          // v2
    str     w5, [x22], #4          // color
    
    ret
    
.Lno_rotation:
    // No rotation: Standard quad generation
    fsub    s4, v0.s[0], v0.s[2]    // left = x - width/2
    fadd    s5, v0.s[0], v0.s[2]    // right = x + width/2  
    fsub    s6, v0.s[1], v0.s[3]    // top = y - height/2
    fadd    s7, v0.s[1], v0.s[3]    // bottom = y + height/2
    
    // Vertex 0: top-left
    str     s4, [x22], #4           // x
    str     s6, [x22], #4           // y
    str     s1, [x22], #4           // u1
    fmov    s2, v1.s[1]
    str     s2, [x22], #4           // v1
    str     w5, [x22], #4           // color
    
    // Vertex 1: top-right
    str     s5, [x22], #4           // x
    str     s6, [x22], #4           // y
    fmov    s8, v1.s[2]            // u2
    str     s8, [x22], #4           // u2
    str     s2, [x22], #4           // v1
    str     w5, [x22], #4           // color
    
    // Vertex 2: bottom-right
    str     s5, [x22], #4           // x
    str     s7, [x22], #4           // y
    str     s8, [x22], #4           // u2
    fmov    s9, v1.s[3]            // v2
    str     s9, [x22], #4           // v2
    str     w5, [x22], #4           // color
    
    // Vertex 3: bottom-left
    str     s4, [x22], #4           // x
    str     s7, [x22], #4           // y
    str     s1, [x22], #4           // u1
    str     s9, [x22], #4           // v2
    str     w5, [x22], #4           // color
    
    ret

//
// fast_sin_cos - Fast sine and cosine approximation using NEON
// Input: s26 = angle in radians
// Output: s27 = sin(angle), s28 = cos(angle)
// Modifies: s26-s31
//
_fast_sin_cos:
    // Fast trigonometric approximation using Taylor series
    // sin(x) ≈ x - x³/6 + x⁵/120 (for small x)
    // cos(x) ≈ 1 - x²/2 + x⁴/24 (for small x)
    
    // Normalize angle to [-π, π]
    fmov    s29, #6.283185307       // 2π
    fmov    s30, #3.141592654       // π
    
    // Reduce angle to primary range
    fdiv    s31, s26, s29
    frintm  s31, s31                // floor(angle / 2π)
    fmls    s26, s31, s29           // angle = angle - 2π * floor(angle / 2π)
    
    // If angle > π, subtract 2π
    fcmp    s26, s30
    b.le    .Langle_in_range
    fsub    s26, s26, s29
    
.Langle_in_range:
    // Calculate x² and x³ for approximations
    fmul    s29, s26, s26           // x²
    fmul    s30, s29, s26           // x³
    fmul    s31, s29, s29           // x⁴
    
    // Calculate sin(x) ≈ x - x³/6 + x⁵/120
    fmov    s27, #0.166666667       // 1/6
    fmul    s27, s30, s27           // x³/6
    fsub    s27, s26, s27           // x - x³/6
    // Simplified: skip x⁵/120 term for performance
    
    // Calculate cos(x) ≈ 1 - x²/2 + x⁴/24
    fmov    s28, #1.0               // 1
    fmov    s0, #0.5                // 1/2
    fmul    s0, s29, s0             // x²/2
    fsub    s28, s28, s0            // 1 - x²/2
    fmov    s0, #0.041666667        // 1/24
    fmul    s0, s31, s0             // x⁴/24
    fadd    s28, s28, s0            // 1 - x²/2 + x⁴/24
    
    ret

//
// sprite_batch_optimize_tiles - Optimize batch order for TBDR tile efficiency
// Input: None
// Output: None
// Modifies: x0-x15
//
_sprite_batch_optimize_tiles:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Sort batches by screen tiles to improve TBDR performance
    // This groups batches that affect similar screen areas together
    
    adrp    x0, renderer_state@PAGE
    add     x0, x0, renderer_state@PAGEOFF
    ldr     w1, [x0, #total_batches]
    
    cmp     w1, #2
    b.lt    .Loptimize_done // Need at least 2 batches to sort
    
    // Simple insertion sort by tile mask (good for mostly sorted data)
    mov     w2, #1          // Start from second batch
    
.Lsort_outer_loop:
    cmp     w2, w1
    b.ge    .Lsort_done
    
    // Get current batch tile mask
    adrp    x3, sprite_batches@PAGE
    add     x3, x3, sprite_batches@PAGEOFF
    add     x4, x3, x2, lsl #6     // current batch
    ldr     x5, [x4, #screen_tiles]  // Current tile mask
    
    mov     w6, w2          // Insert position
    sub     w7, w2, #1      // Compare position
    
.Lsort_inner_loop:
    cmp     w7, #0
    b.lt    .Lsort_insert
    
    add     x8, x3, x7, lsl #6     // Compare batch
    ldr     x9, [x8, #screen_tiles]
    
    // Compare tile masks (simple numeric comparison)
    cmp     x9, x5
    b.le    .Lsort_insert
    
    // Shift batch up
    add     x10, x3, x6, lsl #6    // Destination
    mov     x11, #sprite_batch_size
    bl      _memcpy             // Copy batch
    
    sub     w6, w6, #1      // Move insert position
    sub     w7, w7, #1      // Move compare position
    b       .Lsort_inner_loop
    
.Lsort_insert:
    // Insert current batch at position w6
    add     x10, x3, x6, lsl #6    // Insert position
    mov     x11, #sprite_batch_size
    bl      _memcpy             // Copy back current batch
    
    add     w2, w2, #1
    b       .Lsort_outer_loop
    
.Lsort_done:
    // Update statistics
    adrp    x0, batch_stats@PAGE
    add     x0, x0, batch_stats@PAGEOFF
    ldr     x1, [x0, #batches_created]
    add     x1, x1, x2
    str     x1, [x0, #batches_created]
    
.Loptimize_done:
    ldp     x29, x30, [sp], #16
    ret

//
// sprite_batch_end_frame - End frame processing
// Input: None
// Output: None
// Modifies: x0-x7
//
_sprite_batch_end_frame:
    // Final optimization pass
    bl      _sprite_batch_optimize_tiles
    
    // Update GPU memory usage statistics
    adrp    x0, renderer_state@PAGE
    add     x0, x0, renderer_state@PAGEOFF
    ldr     w1, [x0, #vertex_write_pos]
    ldr     w2, [x0, #index_write_pos]
    
    adrp    x3, batch_stats@PAGE
    add     x3, x3, batch_stats@PAGEOFF
    add     x4, x1, x2      // Total memory used
    str     x4, [x3, #gpu_memory_used]
    
    ret

//
// sprite_batch_get_stats - Get batching statistics
// Input: x0 = stats buffer pointer
// Output: None
// Modifies: x0-x3
//
_sprite_batch_get_stats:
    // Copy renderer state
    adrp    x1, renderer_state@PAGE
    add     x1, x1, renderer_state@PAGEOFF
    mov     x2, #batch_renderer_state_size
    bl      _memcpy
    
    // Append batch statistics
    add     x0, x0, x2
    adrp    x1, batch_stats@PAGE
    add     x1, x1, batch_stats@PAGEOFF
    mov     x2, #40         // Size of batch_stats
    bl      _memcpy
    
    ret

// Helper function stubs
_add_sprite_to_batch_internal:
    ret

_update_tile_bins:
    ret

_set_fragment_texture:
    ret

_draw_batch_primitives:
    ret

//
// sprite_batch_create_instanced - Create instanced batch for similar sprites
// Input: x0 = device pointer, x1 = max instances, x2 = base mesh
// Output: x0 = instanced batch pointer, 0 on error
// Modifies: x0-x15
//
_sprite_batch_create_instanced:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save device
    mov     x20, x1         // Save max instances
    mov     x21, x2         // Save base mesh
    
    // Find available instanced batch slot
    adrp    x22, instanced_batches@PAGE
    add     x22, x22, instanced_batches@PAGEOFF
    
    mov     x0, #0          // Batch index
    mov     x1, #64         // Max instanced batches
    
.Lfind_instanced_slot:
    cmp     x0, x1
    b.ge    .Lcreate_instanced_error
    
    add     x2, x22, x0, lsl #6    // instanced_batch_size = 64
    ldr     x3, [x2, #instance_buffer]
    cmp     x3, #0
    b.eq    .Lfound_instanced_slot
    
    add     x0, x0, #1
    b       .Lfind_instanced_slot
    
.Lfound_instanced_slot:
    mov     x23, x2         // Save batch pointer
    
    // Create instance data buffer
    mov     x0, x19         // Device
    mov     x1, x20, lsl #7 // max_instances * instance_data_size (128 bytes)
    mov     x2, #0          // Storage mode: shared
    bl      _device_new_buffer_with_length
    
    cmp     x0, #0
    b.eq    .Lcreate_instanced_error
    
    // Initialize instanced batch
    str     x21, [x23, #base_mesh]
    str     x0, [x23, #instance_buffer]
    str     wzr, [x23, #instance_count]
    str     w20, [x23, #max_instances]
    
    // Set default vertex/index counts for quad
    mov     w0, #4
    str     w0, [x23, #vertex_count]
    mov     w0, #6
    str     w0, [x23, #index_count]
    
    mov     x0, x23         // Return batch pointer
    b       .Lcreate_instanced_exit
    
.Lcreate_instanced_error:
    mov     x0, #0          // Error
    
.Lcreate_instanced_exit:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// sprite_batch_add_instance - Add instance to instanced batch
// Input: x0 = instanced batch, x1 = instance data
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15
//
_sprite_batch_add_instance:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0         // Save batch
    mov     x20, x1         // Save instance data
    
    // Check if batch has space
    ldr     w0, [x19, #instance_count]
    ldr     w1, [x19, #max_instances]
    cmp     w0, w1
    b.ge    .Ladd_instance_error
    
    // Get staging area for instance data
    adrp    x21, instance_data_staging@PAGE
    add     x21, x21, instance_data_staging@PAGEOFF
    add     x21, x21, x0, lsl #7    // instance_index * instance_data_size
    
    // Copy instance data to staging
    mov     x0, x21
    mov     x1, x20
    mov     x2, #instance_data_size
    bl      _memcpy
    
    // Increment instance count
    ldr     w0, [x19, #instance_count]
    add     w0, w0, #1
    str     w0, [x19, #instance_count]
    
    mov     x0, #0          // Success
    b       .Ladd_instance_exit
    
.Ladd_instance_error:
    mov     x0, #-1         // Error
    
.Ladd_instance_exit:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// sprite_batch_update_instance_buffer - Update GPU instance buffer
// Input: x0 = instanced batch
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15
//
_sprite_batch_update_instance_buffer:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0         // Save batch
    
    ldr     w20, [x19, #instance_count]
    cmp     w20, #0
    b.eq    .Lupdate_instance_success  // Nothing to update
    
    // Get GPU buffer contents
    ldr     x0, [x19, #instance_buffer]
    bl      _buffer_contents
    mov     x21, x0         // GPU buffer pointer
    
    // Copy staging data to GPU buffer
    adrp    x0, instance_data_staging@PAGE
    add     x0, x0, instance_data_staging@PAGEOFF
    mov     x1, x21
    mov     x2, x20, lsl #7  // instance_count * instance_data_size
    bl      _memcpy
    
.Lupdate_instance_success:
    mov     x0, #0          // Success
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// sprite_batch_render_instanced - Render instanced batch
// Input: x0 = render encoder, x1 = instanced batch
// Output: None
// Modifies: x0-x15
//
_sprite_batch_render_instanced:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0         // Save render encoder
    mov     x20, x1         // Save batch
    
    ldr     w21, [x20, #instance_count]
    cmp     w21, #0
    b.eq    .Lrender_instanced_done
    
    // Update instance buffer first
    mov     x0, x20
    bl      _sprite_batch_update_instance_buffer
    
    // Set vertex buffer (base mesh)
    mov     x0, x19
    ldr     x1, [x20, #base_mesh]
    mov     x2, #0          // Buffer index 0
    mov     x3, #0          // Offset
    bl      _render_encoder_set_vertex_buffer
    
    // Set instance buffer
    mov     x0, x19
    ldr     x1, [x20, #instance_buffer]
    mov     x2, #1          // Buffer index 1
    mov     x3, #0          // Offset
    bl      _render_encoder_set_vertex_buffer
    
    // Set texture atlas
    ldr     x1, [x20, #texture_atlas]
    cmp     x1, #0
    b.eq    .Lrender_instanced_draw
    
    mov     x0, x19
    mov     x2, #0          // Texture index
    bl      _render_encoder_set_fragment_texture
    
.Lrender_instanced_draw:
    // Draw instanced primitives
    mov     x0, x19
    mov     x1, #0          // Primitive type (triangles)
    ldr     w2, [x20, #index_count]    // Index count per instance
    mov     x3, #0          // Index offset
    mov     w4, w21         // Instance count
    bl      _render_encoder_draw_indexed_primitives_instanced
    
    // Update statistics
    adrp    x0, renderer_state@PAGE
    add     x0, x0, renderer_state@PAGEOFF
    ldr     w1, [x0, #draw_calls_issued]
    add     w1, w1, #1
    str     w1, [x0, #draw_calls_issued]
    
    ldr     w1, [x0, #sprites_rendered]
    add     w1, w1, w21
    str     w1, [x0, #sprites_rendered]
    
.Lrender_instanced_done:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// sprite_batch_optimize_instances - Optimize instance data for rendering
// Input: x0 = instanced batch
// Output: None
// Modifies: x0-x15
//
_sprite_batch_optimize_instances:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0         // Save batch
    
    ldr     w20, [x19, #instance_count]
    cmp     w20, #2
    b.lt    .Loptimize_instances_done
    
    // Sort instances by depth for proper alpha blending
    adrp    x0, instance_data_staging@PAGE
    add     x0, x0, instance_data_staging@PAGEOFF
    mov     x1, x20         // Instance count
    bl      _sort_instances_by_depth
    
    // Batch instances with similar properties
    bl      _batch_similar_instances
    
.Loptimize_instances_done:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// sort_instances_by_depth - Sort instances by depth for alpha blending
// Input: x0 = instance array, x1 = count
// Output: None
// Modifies: x0-x15, v0-v31
//
_sort_instances_by_depth:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    cmp     x1, #2
    b.lt    .Lsort_instances_done
    
    // Simple insertion sort for small instance counts
    mov     x2, #1          // Start index
    
.Lsort_instances_loop:
    cmp     x2, x1
    b.ge    .Lsort_instances_done
    
    // Get current instance depth (assume it's in color_mult.w)
    add     x3, x0, x2, lsl #7    // current instance
    ldr     s0, [x3, #color_mult + 12]  // depth value
    
    mov     x4, x2          // Insert position
    
.Lsort_instances_inner:
    cmp     x4, #0
    b.eq    .Lsort_instances_insert
    
    sub     x5, x4, #1
    add     x6, x0, x5, lsl #7    // previous instance
    ldr     s1, [x6, #color_mult + 12]
    
    fcmp    s1, s0
    b.le    .Lsort_instances_insert
    
    // Swap instances
    bl      _swap_instances
    
    mov     x4, x5
    b       .Lsort_instances_inner
    
.Lsort_instances_insert:
    add     x2, x2, #1
    b       .Lsort_instances_loop
    
.Lsort_instances_done:
    ldp     x29, x30, [sp], #16
    ret

//
// batch_similar_instances - Group instances with similar properties
// Input: None (uses global staging data)
// Output: None
// Modifies: x0-x15
//
_batch_similar_instances:
    // Implementation for grouping similar instances
    // This would analyze texture usage, depth ranges, etc.
    ret

//
// swap_instances - Swap two instances in the array
// Input: x3 = instance1 ptr, x6 = instance2 ptr
// Output: None
// Modifies: x7-x10, v0-v3
//
_swap_instances:
    // Swap 128-byte instance data using SIMD
    ld1     {v0.4s, v1.4s, v2.4s, v3.4s}, [x3]
    ld1     {v4.4s, v5.4s, v6.4s, v7.4s}, [x6]
    st1     {v4.4s, v5.4s, v6.4s, v7.4s}, [x3], #64
    st1     {v0.4s, v1.4s, v2.4s, v3.4s}, [x6], #64
    
    ld1     {v0.4s, v1.4s, v2.4s, v3.4s}, [x3]
    ld1     {v4.4s, v5.4s, v6.4s, v7.4s}, [x6]
    st1     {v4.4s, v5.4s, v6.4s, v7.4s}, [x3]
    st1     {v0.4s, v1.4s, v2.4s, v3.4s}, [x6]
    
    ret

//
// sprite_batch_calculate_atlas_uv - Calculate UV coordinates for sprite in atlas
// Input: w0 = sprite_id, w1 = atlas_width, w2 = atlas_height, x3 = output uv pointer
// Output: x0 = 0 on success, -1 on error
// Modifies: v0-v7
//
_sprite_batch_calculate_atlas_uv:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Find sprite in atlas registry
    bl      _find_sprite_in_atlas
    cmp     x0, #0
    b.eq    .Luv_calc_error
    
    mov     x4, x0          // Save sprite entry pointer
    
    // Load pixel coordinates
    ldrh    w5, [x4, #pixel_rect]      // x1
    ldrh    w6, [x4, #pixel_rect + 2]  // y1
    ldrh    w7, [x4, #pixel_rect + 4]  // x2
    ldrh    w8, [x4, #pixel_rect + 6]  // y2
    
    // Convert to UV coordinates using SIMD
    // UV = pixel_coord / atlas_size
    ucvtf   s0, w5          // x1 to float
    ucvtf   s1, w6          // y1 to float
    ucvtf   s2, w7          // x2 to float
    ucvtf   s3, w8          // y2 to float
    
    ucvtf   s4, w1          // atlas_width to float
    ucvtf   s5, w2          // atlas_height to float
    
    // Calculate UV coordinates: [u1, v1, u2, v2]
    fdiv    s0, s0, s4      // u1 = x1 / atlas_width
    fdiv    s1, s1, s5      // v1 = y1 / atlas_height
    fdiv    s2, s2, s4      // u2 = x2 / atlas_width
    fdiv    s3, s3, s5      // v2 = y2 / atlas_height
    
    // Store UV coordinates
    str     s0, [x3]        // u1
    str     s1, [x3, #4]    // v1
    str     s2, [x3, #8]    // u2
    str     s3, [x3, #12]   // v2
    
    mov     x0, #0          // Success
    b       .Luv_calc_exit
    
.Luv_calc_error:
    mov     x0, #-1         // Error
    
.Luv_calc_exit:
    ldp     x29, x30, [sp], #16
    ret

//
// sprite_batch_calculate_atlas_uv_batch - Calculate UV coordinates for multiple sprites in batch
// Input: x0 = sprite_id_array, x1 = count, x2 = atlas_width, x3 = atlas_height, x4 = output_uv_array
// Output: x0 = number of successful calculations
// Modifies: x0-x15, v0-v31
//
_sprite_batch_calculate_atlas_uv_batch:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save sprite_id_array
    mov     x20, x1         // Save count
    mov     w21, w2         // Save atlas_width
    mov     w22, w3         // Save atlas_height
    mov     x23, x4         // Save output_uv_array
    
    // Convert atlas dimensions to float for SIMD
    ucvtf   s16, w21        // atlas_width
    ucvtf   s17, w22        // atlas_height
    dup     v18.4s, v16.s[0] // [atlas_width, atlas_width, atlas_width, atlas_width]
    dup     v19.4s, v17.s[0] // [atlas_height, atlas_height, atlas_height, atlas_height]
    
    mov     x24, #0         // Index
    mov     x25, #0         // Success counter
    
    // Process 4 sprites at once when possible
.Luv_batch_loop:
    cmp     x24, x20
    b.ge    .Luv_batch_done
    
    // Check if we can process 4 sprites
    sub     x5, x20, x24
    cmp     x5, #4
    b.lt    .Luv_batch_single
    
    // SIMD path: Process 4 sprites
    bl      _calculate_4sprite_uvs_simd
    add     x25, x25, x0    // Add successful calculations
    add     x24, x24, #4
    b       .Luv_batch_loop
    
.Luv_batch_single:
    // Single sprite processing
    ldr     w0, [x19, x24, lsl #2]  // sprite_id
    mov     w1, w21         // atlas_width
    mov     w2, w22         // atlas_height
    add     x3, x23, x24, lsl #4   // output UV pointer (16 bytes per UV)
    bl      _sprite_batch_calculate_atlas_uv
    
    cmp     x0, #0
    cinc    x25, x25, eq    // Increment if successful
    
    add     x24, x24, #1
    b       .Luv_batch_loop
    
.Luv_batch_done:
    mov     x0, x25         // Return success count
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// calculate_4sprite_uvs_simd - Calculate UV coordinates for 4 sprites using SIMD
// Input: x19 = sprite_id_array, x23 = output_uv_array, x24 = current index
//        v18 = atlas_width vector, v19 = atlas_height vector
// Output: x0 = number of successful calculations
// Modifies: x0-x15, v0-v31
//
_calculate_4sprite_uvs_simd:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Load 4 sprite IDs
    add     x0, x19, x24, lsl #2
    ld1     {v0.4s}, [x0]           // Load 4 sprite IDs as integers
    
    mov     x5, #0          // Success counter
    mov     x6, #0          // Sprite index within the 4
    
.Lsimd_uv_loop:
    cmp     x6, #4
    b.ge    .Lsimd_uv_done
    
    // Extract current sprite ID
    mov     w0, v0.s[x6, uxtw]
    
    // Find sprite in atlas registry
    bl      _find_sprite_in_atlas
    cmp     x0, #0
    b.eq    .Lsimd_uv_next
    
    mov     x7, x0          // Save sprite entry pointer
    
    // Load pixel coordinates
    ldrh    w1, [x7, #pixel_rect]      // x1
    ldrh    w2, [x7, #pixel_rect + 2]  // y1
    ldrh    w3, [x7, #pixel_rect + 4]  // x2
    ldrh    w4, [x7, #pixel_rect + 6]  // y2
    
    // Convert to float and pack into vector
    ucvtf   s20, w1         // x1
    ucvtf   s21, w2         // y1
    ucvtf   s22, w3         // x2
    ucvtf   s23, w4         // y2
    
    // Pack into single vector: [x1, y1, x2, y2]
    mov     v24.s[0], v20.s[0]
    mov     v24.s[1], v21.s[0]
    mov     v24.s[2], v22.s[0]
    mov     v24.s[3], v23.s[0]
    
    // Create atlas dimension vector for this calculation
    mov     v25.s[0], v18.s[0]      // atlas_width
    mov     v25.s[1], v19.s[0]      // atlas_height
    mov     v25.s[2], v18.s[0]      // atlas_width
    mov     v25.s[3], v19.s[0]      // atlas_height
    
    // Calculate UV: pixel_coords / atlas_dims
    fdiv    v26.4s, v24.4s, v25.4s  // [u1, v1, u2, v2]
    
    // Store UV coordinates
    add     x8, x23, x24, lsl #4    // Base output pointer
    add     x8, x8, x6, lsl #4      // Add offset for current sprite
    st1     {v26.4s}, [x8]          // Store UV coordinates
    
    add     x5, x5, #1              // Increment success counter
    
.Lsimd_uv_next:
    add     x6, x6, #1
    b       .Lsimd_uv_loop
    
.Lsimd_uv_done:
    mov     x0, x5          // Return success count
    ldp     x29, x30, [sp], #16
    ret

//
// sprite_batch_optimize_uv_cache - Optimize UV coordinate cache for better performance
// Input: None
// Output: x0 = 0 on success
// Modifies: x0-x15
//
_sprite_batch_optimize_uv_cache:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Analyze UV access patterns and reorganize cache
    // This function would collect statistics on UV coordinate access
    // and reorganize the atlas layout for better cache performance
    
    // For now, implement basic cache warming
    adrp    x0, sprite_registry@PAGE
    add     x0, x0, sprite_registry@PAGEOFF
    
    // Touch UV coordinates to warm cache
    mov     x1, #0          // Index
    mov     x2, #1024       // Cache warm count
    
.Lwarm_cache_loop:
    cmp     x1, x2
    b.ge    .Lwarm_cache_done
    
    add     x3, x0, x1, lsl #5     // sprite_entry offset
    ld1     {v0.4s}, [x3, #uv_rect] // Load UV coordinates
    // Just loading is enough to warm cache
    
    add     x1, x1, #1
    b       .Lwarm_cache_loop
    
.Lwarm_cache_done:
    mov     x0, #0          // Success
    ldp     x29, x30, [sp], #16
    ret

//
// sprite_batch_advanced_batching - Advanced batch optimization with draw call reduction
// Input: None
// Output: x0 = number of batches reduced
// Modifies: x0-x15, v0-v31
//
_sprite_batch_advanced_batching:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, #0         // Batches merged counter
    
    // Get current batch count
    adrp    x20, renderer_state@PAGE
    add     x20, x20, renderer_state@PAGEOFF
    ldr     w21, [x20, #total_batches]
    
    cmp     w21, #2
    b.lt    .Ladvanced_batch_done
    
    // Phase 1: Merge batches with same texture and compatible tiles
    bl      _merge_compatible_batches
    add     x19, x19, x0
    
    // Phase 2: Optimize batch order for TBDR efficiency
    bl      _optimize_batch_tbdr_order
    
    // Phase 3: Create instanced batches for repeated sprites
    bl      _create_instanced_sprite_batches
    add     x19, x19, x0
    
    // Update statistics
    adrp    x0, batch_stats@PAGE
    add     x0, x0, batch_stats@PAGEOFF
    ldr     x1, [x0, #batches_merged]
    add     x1, x1, x19
    str     x1, [x0, #batches_merged]
    
    ldr     x1, [x0, #draw_calls_saved]
    add     x1, x1, x19
    str     x1, [x0, #draw_calls_saved]
    
.Ladvanced_batch_done:
    mov     x0, x19         // Return merge count
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// merge_compatible_batches - Merge batches that can be combined
// Input: None
// Output: x0 = number of batches merged
// Modifies: x0-x15
//
_merge_compatible_batches:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, #0         // Merge counter
    
    // Get batch array
    adrp    x20, sprite_batches@PAGE
    add     x20, x20, sprite_batches@PAGEOFF
    
    adrp    x21, renderer_state@PAGE
    add     x21, x21, renderer_state@PAGEOFF
    ldr     w22, [x21, #total_batches]
    
    mov     w0, #0          // First batch index
    
.Lmerge_outer_loop:
    cmp     w0, w22
    b.ge    .Lmerge_done
    
    add     x1, x20, x0, lsl #6     // First batch pointer
    ldrh    w2, [x1, #sprite_count]
    cmp     w2, #0
    b.eq    .Lmerge_next_first      // Skip empty batches
    
    add     w3, w0, #1              // Second batch index
    
.Lmerge_inner_loop:
    cmp     w3, w22
    b.ge    .Lmerge_next_first
    
    add     x4, x20, x3, lsl #6     // Second batch pointer
    ldrh    w5, [x4, #sprite_count]
    cmp     w5, #0
    b.eq    .Lmerge_next_second     // Skip empty batches
    
    // Check if batches can be merged
    // 1. Same texture
    ldrh    w6, [x1, #texture_id]
    ldrh    w7, [x4, #texture_id]
    cmp     w6, w7
    b.ne    .Lmerge_next_second
    
    // 2. Combined sprite count <= MAX_BATCH_SIZE
    add     w8, w2, w5
    cmp     w8, #MAX_BATCH_SIZE
    b.gt    .Lmerge_next_second
    
    // 3. Compatible screen tiles (overlapping or adjacent)
    ldr     x9, [x1, #screen_tiles]
    ldr     x10, [x4, #screen_tiles]
    bl      _check_tile_compatibility
    cmp     x0, #0
    b.eq    .Lmerge_next_second
    
    // Merge batch 2 into batch 1
    bl      _merge_batch_sprites
    
    // Mark batch 2 as empty
    strh    wzr, [x4, #sprite_count]
    str     xzr, [x4, #screen_tiles]
    
    // Update batch 1 sprite count
    strh    w8, [x1, #sprite_count]
    
    // Combine screen tiles
    orr     x9, x9, x10
    str     x9, [x1, #screen_tiles]
    
    add     x19, x19, #1            // Increment merge counter
    mov     w2, w8                  // Update sprite count for batch 1
    
.Lmerge_next_second:
    add     w3, w3, #1
    b       .Lmerge_inner_loop
    
.Lmerge_next_first:
    add     w0, w0, #1
    b       .Lmerge_outer_loop
    
.Lmerge_done:
    // Compact batch array by removing empty batches
    bl      _compact_batch_array
    
    mov     x0, x19         // Return merge count
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// Helper function stubs for advanced batching
_find_sprite_in_atlas:
    // Stub: Find sprite entry in atlas registry
    mov     x0, #0
    ret

_check_tile_compatibility:
    // Stub: Check if two tile masks are compatible for merging
    mov     x0, #1          // Return compatible for now
    ret

_merge_batch_sprites:
    // Stub: Merge sprite data from one batch to another
    ret

_compact_batch_array:
    // Stub: Remove empty batches and compact array
    ret

_optimize_batch_tbdr_order:
    // Stub: Optimize batch order for TBDR efficiency
    ret

_create_instanced_sprite_batches:
    // Stub: Create instanced batches for repeated sprites
    mov     x0, #0          // Return 0 instances created for now
    ret

// External function declarations
.extern _memset
.extern _memcpy
.extern _device_new_buffer_with_length
.extern _buffer_contents
.extern _render_encoder_draw_indexed_primitives_instanced

.end