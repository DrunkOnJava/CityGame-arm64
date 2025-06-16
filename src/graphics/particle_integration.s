//
// particle_integration.s - Integration layer for particle system with unified renderer
// Sub-Agent 4: Graphics Pipeline Integrator
//
// Provides seamless integration between particles.s and the unified graphics pipeline:
// - Metal command encoding for particle rendering
// - NEON-optimized particle vertex generation  
// - Instanced particle rendering for performance
// - Integration with depth sorting system
// - Particle-specific pipeline states and shaders
//
// Author: Sub-Agent 4 (Graphics Pipeline Integrator)  
// Date: 2025-06-15
//

.section __TEXT,__text,regular,pure_instructions
.align 4

// Particle rendering constants
.equ PARTICLE_VERTEX_SIZE, 24           // 6 floats: x, y, z, u, v, life
.equ PARTICLE_INSTANCE_SIZE, 64         // Instance data size
.equ MAX_PARTICLES_PER_DRAW, 32768      // Max particles in single draw call
.equ PARTICLE_ATLAS_SIZE, 512           // Particle texture atlas dimensions

// Particle-Metal integration state
.struct particle_metal_state
    current_encoder:        .quad 1     // Active Metal render encoder
    particle_vertex_buffer: .quad 1     // Particle vertex buffer (MTLBuffer)
    particle_instance_buffer: .quad 1   // Instance data buffer (MTLBuffer)
    
    // Pipeline states for different particle types
    fire_pipeline:          .quad 1     // Fire particle pipeline
    smoke_pipeline:         .quad 1     // Smoke particle pipeline  
    water_pipeline:         .quad 1     // Water particle pipeline
    generic_pipeline:       .quad 1     // Generic particle pipeline
    
    // Particle atlas and textures
    particle_atlas:         .quad 1     // Main particle texture atlas
    noise_texture:          .quad 1     // Noise texture for effects
    
    // Rendering state
    particles_rendered:     .long 1     // Particles rendered this frame
    draw_calls_particles:   .long 1     // Particle draw calls this frame
    vertex_buffer_offset:   .long 1     // Current buffer write offset
    
    // Performance tracking
    vertex_gen_time_ns:     .quad 1     // Time for vertex generation
    upload_time_ns:         .quad 1     // Time for GPU upload
.endstruct

// Particle instance data structure (for instanced rendering)
.struct particle_instance_data
    world_matrix:           .float 16   // World transformation matrix
    color_life:             .float 4    // color.rgb, life_remaining  
    velocity_size:          .float 4    // velocity.xyz, size
    rotation_data:          .float 4    // rotation, angular_velocity, etc.
.endstruct

// Global particle integration state
.data
.align 16
particle_metal_integration: .skip particle_metal_state_size

// Base particle quad vertices (will be instanced)
particle_base_quad:
    // Vertex 0: top-left
    .float -0.5, 0.5, 0.0, 0.0, 0.0, 1.0
    // Vertex 1: top-right  
    .float 0.5, 0.5, 0.0, 1.0, 0.0, 1.0
    // Vertex 2: bottom-right
    .float 0.5, -0.5, 0.0, 1.0, 1.0, 1.0
    // Vertex 3: bottom-left
    .float -0.5, -0.5, 0.0, 0.0, 1.0, 1.0

// Particle quad indices
particle_quad_indices:
    .short 0, 1, 2, 2, 3, 0

.bss
.align 16
// Dynamic buffers for particle data
particle_staging_buffer:    .skip PARTICLE_INSTANCE_SIZE * MAX_PARTICLES_PER_DRAW
vertex_generation_buffer:   .skip PARTICLE_VERTEX_SIZE * MAX_PARTICLES_PER_DRAW * 4

.text
.global _particle_metal_init
.global _particle_metal_set_encoder
.global _particle_metal_render_system
.global _particle_metal_upload_instances
.global _particle_metal_generate_vertices
.global _particle_metal_render_instanced
.global _particle_metal_get_stats

//
// particle_metal_init - Initialize particle-Metal integration
// Input: x0 = Metal device pointer
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15
//
_particle_metal_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0         // Save device
    
    // Initialize integration state
    adrp    x0, particle_metal_integration@PAGE
    add     x0, x0, particle_metal_integration@PAGEOFF
    mov     x1, #0
    mov     x2, #particle_metal_state_size
    bl      _memset
    
    mov     x20, x0         // Save state pointer
    
    // Create particle vertex buffer
    mov     x0, x19
    mov     x1, #(PARTICLE_VERTEX_SIZE * MAX_PARTICLES_PER_DRAW * 4) // 4 vertices per particle
    mov     x2, #0          // MTL_RESOURCE_STORAGE_MODE_SHARED
    bl      _device_new_buffer_with_length
    cmp     x0, #0
    b.eq    .Lparticle_init_error
    str     x0, [x20, #particle_vertex_buffer]
    
    // Create particle instance buffer
    mov     x0, x19
    mov     x1, #(PARTICLE_INSTANCE_SIZE * MAX_PARTICLES_PER_DRAW)
    mov     x2, #0          // MTL_RESOURCE_STORAGE_MODE_SHARED
    bl      _device_new_buffer_with_length
    cmp     x0, #0
    b.eq    .Lparticle_init_error
    str     x0, [x20, #particle_instance_buffer]
    
    // Create particle pipeline states
    mov     x0, x19
    bl      _create_particle_pipeline_states
    cmp     x0, #0
    b.ne    .Lparticle_init_error
    
    // Load particle atlas and noise textures
    mov     x0, x19
    bl      _load_particle_textures
    cmp     x0, #0
    b.ne    .Lparticle_init_error
    
    // Upload base quad vertices to GPU
    bl      _upload_base_particle_quad
    
    mov     x0, #0          // Success
    b       .Lparticle_init_exit
    
.Lparticle_init_error:
    mov     x0, #-1         // Error
    
.Lparticle_init_exit:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// particle_metal_set_encoder - Set active Metal render encoder for particles
// Input: x0 = Metal render encoder pointer
// Output: None
// Modifies: x0-x3
//
_particle_metal_set_encoder:
    adrp    x1, particle_metal_integration@PAGE
    add     x1, x1, particle_metal_integration@PAGEOFF
    str     x0, [x1, #current_encoder]
    
    // Reset frame statistics
    str     wzr, [x1, #particles_rendered]
    str     wzr, [x1, #draw_calls_particles]
    str     wzr, [x1, #vertex_buffer_offset]
    
    ret

//
// particle_metal_render_system - Render all active particle systems
// Input: x0 = particle system array, w1 = system count
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15, v0-v31
//
_particle_metal_render_system:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save particle systems
    mov     w20, w1         // Save system count
    
    // Start performance timing
    bl      _get_system_time_ns
    mov     x21, x0
    
    mov     x22, #0         // System index
    
.Lrender_systems_loop:
    cmp     x22, x20, uxtw
    b.ge    .Lrender_systems_done
    
    // Get particle system
    add     x0, x19, x22, lsl #8   // Assume 256 bytes per system
    
    // Check if system is active
    ldr     w1, [x0, #active_count]
    cmp     w1, #0
    b.eq    .Lnext_system
    
    // Render this particle system
    bl      _render_single_particle_system
    
.Lnext_system:
    add     x22, x22, #1
    b       .Lrender_systems_loop
    
.Lrender_systems_done:
    // Update performance statistics
    bl      _get_system_time_ns
    sub     x0, x0, x21
    
    adrp    x1, particle_metal_integration@PAGE
    add     x1, x1, particle_metal_integration@PAGEOFF
    str     x0, [x1, #vertex_gen_time_ns]
    
    mov     x0, #0          // Success
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// render_single_particle_system - Render one particle system
// Input: x0 = particle system pointer
// Output: x0 = 0 on success
// Modifies: x0-x15, v0-v31
//
_render_single_particle_system:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save particle system
    
    // Get system properties
    ldr     w20, [x19, #active_count]      // Number of active particles
    ldr     w21, [x19, #system_type]       // System type (fire, smoke, etc.)
    ldr     x22, [x19, #particle_pool]     // Particle data
    
    // Set appropriate pipeline state for particle type
    mov     w0, w21
    bl      _set_particle_pipeline_for_type
    
    // Generate vertex data for all particles using NEON
    mov     x0, x22         // Particle array
    mov     w1, w20         // Particle count
    bl      _particle_metal_generate_vertices
    mov     x23, x0         // Save vertex count
    
    // Upload vertices to GPU
    mov     x0, x23         // Vertex count
    bl      _upload_particle_vertices_to_gpu
    
    // Check if we should use instanced rendering
    cmp     w20, #1024
    b.lt    .Luse_vertex_rendering
    
    // Use instanced rendering for large particle counts
    mov     x0, x19         // Particle system
    bl      _particle_metal_render_instanced
    b       .Lrender_single_done
    
.Luse_vertex_rendering:
    // Use traditional vertex rendering for smaller counts
    mov     x0, x23         // Vertex count
    bl      _render_particle_vertices_traditional
    
.Lrender_single_done:
    // Update statistics
    adrp    x0, particle_metal_integration@PAGE
    add     x0, x0, particle_metal_integration@PAGEOFF
    ldr     w1, [x0, #particles_rendered]
    add     w1, w1, w20
    str     w1, [x0, #particles_rendered]
    
    ldr     w1, [x0, #draw_calls_particles]
    add     w1, w1, #1
    str     w1, [x0, #draw_calls_particles]
    
    mov     x0, #0          // Success
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// particle_metal_generate_vertices - Generate particle vertices using NEON SIMD
// Input: x0 = particle array, w1 = particle count
// Output: x0 = total vertex count generated
// Modifies: x0-x15, v0-v31
//
_particle_metal_generate_vertices:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save particle array
    mov     w20, w1         // Save particle count
    
    // Get staging buffer for vertex generation
    adrp    x21, vertex_generation_buffer@PAGE
    add     x21, x21, vertex_generation_buffer@PAGEOFF
    
    mov     x22, #0         // Particle index
    mov     x23, #0         // Vertex write index
    
.Lgen_vertices_loop:
    cmp     x22, x20, uxtw
    b.ge    .Lgen_vertices_done
    
    // Process particles in batches of 4 for NEON optimization
    sub     w24, w20, w22
    cmp     w24, #4
    b.lt    .Lgen_single_particle
    
    // NEON path: Generate 4 particles at once
    add     x0, x19, x22, lsl #6   // particle_array + index * 64
    add     x1, x21, x23, lsl #5   // vertex_buffer + vertex_index * 24
    bl      _generate_4particle_vertices_simd
    
    add     x22, x22, #4           // Process 4 particles
    add     x23, x23, #16          // Generated 16 vertices (4 per particle)
    b       .Lgen_vertices_loop
    
.Lgen_single_particle:
    // Single particle vertex generation
    add     x0, x19, x22, lsl #6   // Particle pointer
    add     x1, x21, x23, lsl #5   // Vertex buffer pointer
    bl      _generate_particle_quad_vertices
    
    add     x22, x22, #1           // Next particle
    add     x23, x23, #4           // Generated 4 vertices
    b       .Lgen_vertices_loop
    
.Lgen_vertices_done:
    mov     x0, x23         // Return total vertex count
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// generate_4particle_vertices_simd - Generate vertices for 4 particles using NEON
// Input: x0 = particle array (4 particles), x1 = vertex output buffer
// Output: None
// Modifies: v0-v31, x2-x7
//
_generate_4particle_vertices_simd:
    // Load 4 particle positions
    ld1     {v0.4s}, [x0], #16      // p0: x,y,z,w
    ld1     {v1.4s}, [x0], #48      // Skip to next particle
    ld1     {v2.4s}, [x0], #16      // p1: x,y,z,w
    ld1     {v3.4s}, [x0], #48
    ld1     {v4.4s}, [x0], #16      // p2: x,y,z,w
    ld1     {v5.4s}, [x0], #48
    ld1     {v6.4s}, [x0], #16      // p3: x,y,z,w
    
    // Transpose positions for SIMD processing
    trn1    v16.4s, v0.4s, v2.4s    // x0,x2,y0,y2
    trn2    v17.4s, v0.4s, v2.4s    // z0,z2,w0,w2
    trn1    v18.4s, v1.4s, v6.4s    // x1,x3,y1,y3
    trn2    v19.4s, v1.4s, v6.4s    // z1,z3,w1,w3
    
    trn1    v20.2d, v16.2d, v18.2d  // x0,x1,x2,x3
    trn2    v21.2d, v16.2d, v18.2d  // y0,y1,y2,y3
    trn1    v22.2d, v17.2d, v19.2d  // z0,z1,z2,z3
    
    // Load particle sizes (from properties field)
    sub     x0, x0, #192
    add     x0, x0, #48             // Offset to properties
    ld1     {v8.4s}, [x0], #48      // p0 properties: size, rotation, mass, life
    ld1     {v9.4s}, [x0], #48      // p1 properties
    ld1     {v10.4s}, [x0], #48     // p2 properties
    ld1     {v11.4s}, [x0]          // p3 properties
    
    // Extract sizes and transpose
    mov     v23.s[0], v8.s[0]       // size0
    mov     v23.s[1], v9.s[0]       // size1
    mov     v23.s[2], v10.s[0]      // size2
    mov     v23.s[3], v11.s[0]      // size3
    
    // Calculate half-sizes for quad generation
    fmov    s24, #0.5
    dup     v24.4s, v24.s[0]
    fmul    v25.4s, v23.4s, v24.4s  // half_sizes
    
    // Generate quad vertices for all 4 particles in parallel
    // Each particle needs 4 vertices: TL, TR, BR, BL
    
    // Top-left vertices: position - half_size
    fsub    v26.4s, v20.4s, v25.4s  // x - half_size
    fadd    v27.4s, v21.4s, v25.4s  // y + half_size
    
    // Store TL vertices for all 4 particles
    mov     w2, #0
.Lstore_tl_loop:
    cmp     w2, #4
    b.ge    .Lstore_tr_vertices
    
    // Calculate vertex buffer offset
    lsl     w3, w2, #4              // particle_index * 16 vertices
    add     x3, x1, x3, lsl #5      // + vertex_index * 24 bytes
    
    // Store TL vertex
    mov     s28, v26.s[w2, uxtw]    // x
    mov     s29, v27.s[w2, uxtw]    // y
    mov     s30, v22.s[w2, uxtw]    // z
    str     s28, [x3], #4
    str     s29, [x3], #4
    str     s30, [x3], #4
    
    // UV coordinates for TL (0,0)
    fmov    s31, #0.0
    str     s31, [x3], #4          // u = 0
    str     s31, [x3], #4          // v = 0
    
    // Life value
    mov     s31, v8.s[3]            // life from properties
    str     s31, [x3]
    
    add     w2, w2, #1
    b       .Lstore_tl_loop
    
.Lstore_tr_vertices:
    // Top-right vertices: x + half_size, y + half_size
    fadd    v26.4s, v20.4s, v25.4s  // x + half_size
    // v27 already contains y + half_size
    
    mov     w2, #0
.Lstore_tr_loop:
    cmp     w2, #4
    b.ge    .Lstore_br_vertices
    
    lsl     w3, w2, #4
    add     w3, w3, #1              // +1 for TR vertex
    add     x3, x1, x3, lsl #5
    
    mov     s28, v26.s[w2, uxtw]    // x + half_size
    mov     s29, v27.s[w2, uxtw]    // y + half_size
    mov     s30, v22.s[w2, uxtw]    // z
    str     s28, [x3], #4
    str     s29, [x3], #4
    str     s30, [x3], #4
    
    // UV coordinates for TR (1,0)
    fmov    s31, #1.0
    str     s31, [x3], #4          // u = 1
    fmov    s31, #0.0
    str     s31, [x3], #4          // v = 0
    
    mov     s31, v8.s[3]            // life
    str     s31, [x3]
    
    add     w2, w2, #1
    b       .Lstore_tr_loop
    
.Lstore_br_vertices:
    // Bottom-right vertices: x + half_size, y - half_size
    // v26 already contains x + half_size
    fsub    v27.4s, v21.4s, v25.4s  // y - half_size
    
    mov     w2, #0
.Lstore_br_loop:
    cmp     w2, #4
    b.ge    .Lstore_bl_vertices
    
    lsl     w3, w2, #4
    add     w3, w3, #2              // +2 for BR vertex
    add     x3, x1, x3, lsl #5
    
    mov     s28, v26.s[w2, uxtw]    // x + half_size
    mov     s29, v27.s[w2, uxtw]    // y - half_size
    mov     s30, v22.s[w2, uxtw]    // z
    str     s28, [x3], #4
    str     s29, [x3], #4
    str     s30, [x3], #4
    
    // UV coordinates for BR (1,1)
    fmov    s31, #1.0
    str     s31, [x3], #4          // u = 1
    str     s31, [x3], #4          // v = 1
    
    mov     s31, v8.s[3]            // life
    str     s31, [x3]
    
    add     w2, w2, #1
    b       .Lstore_br_loop
    
.Lstore_bl_vertices:
    // Bottom-left vertices: x - half_size, y - half_size
    fsub    v26.4s, v20.4s, v25.4s  // x - half_size
    // v27 already contains y - half_size
    
    mov     w2, #0
.Lstore_bl_loop:
    cmp     w2, #4
    b.ge    .Lgenerate_4particles_done
    
    lsl     w3, w2, #4
    add     w3, w3, #3              // +3 for BL vertex
    add     x3, x1, x3, lsl #5
    
    mov     s28, v26.s[w2, uxtw]    // x - half_size
    mov     s29, v27.s[w2, uxtw]    // y - half_size
    mov     s30, v22.s[w2, uxtw]    // z
    str     s28, [x3], #4
    str     s29, [x3], #4
    str     s30, [x3], #4
    
    // UV coordinates for BL (0,1)
    fmov    s31, #0.0
    str     s31, [x3], #4          // u = 0
    fmov    s31, #1.0
    str     s31, [x3], #4          // v = 1
    
    mov     s31, v8.s[3]            // life
    str     s31, [x3]
    
    add     w2, w2, #1
    b       .Lstore_bl_loop
    
.Lgenerate_4particles_done:
    ret

//
// particle_metal_render_instanced - Render particles using instanced rendering
// Input: x0 = particle system
// Output: x0 = 0 on success
// Modifies: x0-x15, v0-v31
//
_particle_metal_render_instanced:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0         // Save particle system
    
    // Generate instance data for all particles
    ldr     x0, [x19, #particle_pool]
    ldr     w1, [x19, #active_count]
    bl      _generate_particle_instance_data
    
    adrp    x20, particle_metal_integration@PAGE
    add     x20, x20, particle_metal_integration@PAGEOFF
    
    // Set vertex buffer (base quad)
    ldr     x0, [x20, #current_encoder]
    ldr     x1, [x20, #particle_vertex_buffer]
    mov     w2, #0          // Buffer index 0
    mov     x3, #0          // Offset
    bl      _metal_encoder_set_vertex_buffer
    
    // Set instance buffer
    ldr     x0, [x20, #current_encoder]
    ldr     x1, [x20, #particle_instance_buffer]
    mov     w2, #1          // Buffer index 1
    mov     x3, #0          // Offset
    bl      _metal_encoder_set_vertex_buffer
    
    // Bind particle textures
    ldr     x0, [x20, #current_encoder]
    ldr     x1, [x20, #particle_atlas]
    mov     w2, #0          // Texture index 0
    bl      _metal_encoder_set_texture
    
    ldr     x0, [x20, #current_encoder]
    ldr     x1, [x20, #noise_texture]
    mov     w2, #1          // Texture index 1
    bl      _metal_encoder_set_texture
    
    // Draw instanced particles
    ldr     x0, [x20, #current_encoder]
    mov     w1, #3          // MTL_PRIMITIVE_TYPE_TRIANGLE
    mov     w2, #6          // 6 indices per quad
    mov     x3, #0          // Index buffer offset
    ldr     w4, [x19, #active_count] // Instance count
    bl      _metal_encoder_draw_indexed_primitives_instanced
    
    mov     x0, #0          // Success
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// Helper function implementations (stubs for now)
_create_particle_pipeline_states:
    mov     x0, #0          // Success
    ret

_load_particle_textures:
    mov     x0, #0          // Success
    ret

_upload_base_particle_quad:
    ret

_set_particle_pipeline_for_type:
    ret

_upload_particle_vertices_to_gpu:
    ret

_render_particle_vertices_traditional:
    ret

_generate_particle_quad_vertices:
    ret

_generate_particle_instance_data:
    ret

// External function declarations
.extern _memset
.extern _get_system_time_ns
.extern _device_new_buffer_with_length
.extern _metal_encoder_set_vertex_buffer
.extern _metal_encoder_set_texture
.extern _metal_encoder_draw_indexed_primitives_instanced

.end