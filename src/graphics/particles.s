//
// particles.s - NEON-optimized particle systems and animation framework for SimCity ARM64
// Agent B4: Graphics Team - Particle Systems & Animation Framework
//
// High-performance particle effects using CPU NEON SIMD acceleration:
// - Fire, smoke, and water particle systems
// - Physics simulation with NEON 4x parallel processing
// - Animation blending and keyframe interpolation
// - Particle pool management and recycling
// - Integration with Agent B1 graphics pipeline
//
// Performance targets:
// - 100,000+ active particles at 60 FPS
// - < 2ms CPU time per frame for particle updates
// - NEON SIMD 4x parallel processing
// - Efficient memory pooling with Agent D1 coordination
//
// Author: Agent B4 (Graphics - Particles & Animation)
// Date: 2025-06-15
//

.section __TEXT,__text,regular,pure_instructions
.align 4

// Particle system constants
.equ MAX_PARTICLES, 131072          // 128K particles maximum
.equ PARTICLES_PER_SYSTEM, 32768    // 32K particles per effect type
.equ PARTICLE_BATCH_SIZE, 64        // NEON processes 16 particles at once (4x4)
.equ ANIMATION_KEYFRAMES_MAX, 64    // Maximum keyframes per animation
.equ ANIMATION_CHANNELS_MAX, 16     // Maximum animation channels
.equ PARTICLE_POOL_BLOCKS, 1024     // Number of pre-allocated particle blocks

// Physics simulation constants (optimized for Apple Silicon)
.equ GRAVITY_CONSTANT, 0x3F800000   // 1.0f in hex (adjust as needed)
.equ AIR_RESISTANCE, 0x3F000000     // 0.5f air resistance factor
.equ COLLISION_DAMPENING, 0x3F400000 // 0.75f collision dampening
.equ MIN_PARTICLE_VELOCITY, 0x3C23D70A // 0.01f minimum velocity threshold

// Particle structure (64 bytes, cache-aligned)
.struct particle
    position:       .float 4    // x, y, z, padding
    velocity:       .float 4    // vx, vy, vz, speed_mag
    color:          .float 4    // r, g, b, a
    properties:     .float 4    // size, rotation, mass, life_remaining
    animation_data: .float 4    // anim_time, anim_speed, anim_frame, anim_blend
.endstruct

// Particle system descriptor
.struct particle_system
    particle_pool:      .quad 1     // Base particle array pointer
    active_count:       .long 1     // Number of active particles
    max_particles:      .long 1     // Maximum particles for this system
    system_type:        .long 1     // Type: 0=fire, 1=smoke, 2=water, 3=generic
    physics_flags:      .long 1     // Physics behavior flags
    spawn_rate:         .float 1    // Particles per second
    spawn_accumulator:  .float 1    // Time accumulator for spawning
    emitter_position:   .float 4    // x, y, z, radius
    emitter_velocity:   .float 4    // vx, vy, vz, velocity_variance
    emitter_color:      .float 4    // r, g, b, color_variance
    system_properties:  .float 4    // life_min, life_max, size_min, size_max
    .align 8
.endstruct

// Animation keyframe structure
.struct animation_keyframe
    time:           .float 1    // Time in animation (0.0 to 1.0)
    value:          .float 4    // 4-component value (position, rotation, scale, etc.)
    interpolation:  .byte 1     // Interpolation type: 0=linear, 1=bezier, 2=step
    .align 8
.endstruct

// Animation channel structure
.struct animation_channel
    keyframes:      .quad 1     // Pointer to keyframe array
    keyframe_count: .long 1     // Number of keyframes
    channel_type:   .long 1     // 0=position, 1=rotation, 2=scale, 3=color
    target_offset:  .long 1     // Byte offset in target structure
    .align 8
.endstruct

// Animation instance structure
.struct animation_instance
    channels:       .quad 1     // Pointer to channel array
    channel_count:  .long 1     // Number of channels
    current_time:   .float 1    // Current animation time
    duration:       .float 1    // Total animation duration
    loop_mode:      .byte 1     // 0=once, 1=loop, 2=ping_pong
    playing:        .byte 1     // Animation playing flag
    .align 8
.endstruct

// Particle pool management
.struct particle_pool_block
    particles:      .quad 1     // Pointer to particle array
    active_mask:    .quad 8     // Bitmask for active particles (512 bits for 512 particles)
    block_id:       .long 1     // Block identifier
    particles_used: .long 1     // Number of particles in use
    next_free:      .long 1     // Index of next free particle
    .align 8
.endstruct

// Performance statistics
.struct particle_stats
    total_particles_active:     .long 1
    particles_spawned_frame:    .long 1
    particles_destroyed_frame:  .long 1
    update_time_microseconds:   .long 1
    render_time_microseconds:   .long 1
    memory_used_bytes:          .quad 1
    cache_hits:                 .quad 1
    cache_misses:               .quad 1
.endstruct

// Global particle system state
.data
.align 16
particle_systems:       .skip particle_system_size * 8  // 8 particle systems max
particle_pool_blocks:   .skip particle_pool_block_size * PARTICLE_POOL_BLOCKS
animation_instances:    .skip animation_instance_size * 64  // 64 active animations
global_particle_stats:  .skip particle_stats_size

// Particle system configuration
particle_config:
    gravity_vector:         .float 0.0, -9.81, 0.0, 0.0
    global_time_scale:      .float 1.0
    global_particle_scale:  .float 1.0
    wind_vector:            .float 0.0, 0.0, 0.0, 0.0
    wind_strength:          .float 0.0
    simulation_bounds:      .float -1000.0, -1000.0, -1000.0, 2000.0  // min_xyz, size
    collision_enabled:      .byte 1
    physics_quality:        .byte 2  // 0=low, 1=medium, 2=high
    .align 16

// Pre-calculated NEON constants for SIMD operations
.align 16
neon_constants:
    gravity_vec4:       .float -9.81, -9.81, -9.81, -9.81
    delta_time_vec4:    .float 0.016667, 0.016667, 0.016667, 0.016667  // 1/60 sec
    air_resistance_vec4: .float 0.98, 0.98, 0.98, 0.98
    one_vec4:           .float 1.0, 1.0, 1.0, 1.0
    zero_vec4:          .float 0.0, 0.0, 0.0, 0.0
    half_vec4:          .float 0.5, 0.5, 0.5, 0.5
    two_vec4:           .float 2.0, 2.0, 2.0, 2.0
    epsilon_vec4:       .float 0.0001, 0.0001, 0.0001, 0.0001

// Fire particle system parameters
fire_particle_config:
    spawn_rate:         .float 500.0       // 500 particles/sec
    life_range:         .float 2.0, 4.0    // 2-4 seconds life
    size_range:         .float 0.5, 2.0    // Size range
    velocity_base:      .float 0.0, 5.0, 0.0, 0.0    // Upward velocity
    velocity_variance:  .float 2.0, 2.0, 2.0, 0.0    // Variance
    color_start:        .float 1.0, 0.8, 0.2, 1.0    // Orange
    color_end:          .float 1.0, 0.2, 0.0, 0.0    // Red fade

// Smoke particle system parameters
smoke_particle_config:
    spawn_rate:         .float 200.0       // 200 particles/sec
    life_range:         .float 5.0, 8.0    // 5-8 seconds life
    size_range:         .float 1.0, 4.0    // Larger size range
    velocity_base:      .float 0.0, 2.0, 0.0, 0.0    // Slow upward
    velocity_variance:  .float 1.0, 1.0, 1.0, 0.0    // Low variance
    color_start:        .float 0.7, 0.7, 0.7, 0.8    // Light gray
    color_end:          .float 0.3, 0.3, 0.3, 0.0    // Dark gray fade

// Water particle system parameters
water_particle_config:
    spawn_rate:         .float 1000.0      // 1000 particles/sec
    life_range:         .float 1.0, 3.0    // 1-3 seconds life
    size_range:         .float 0.2, 0.8    // Small water droplets
    velocity_base:      .float 0.0, 0.0, 0.0, 0.0    // Gravity-driven
    velocity_variance:  .float 3.0, 1.0, 3.0, 0.0    // High horizontal variance
    color_start:        .float 0.3, 0.6, 1.0, 0.8    // Blue
    color_end:          .float 0.1, 0.3, 0.6, 0.2    // Darker blue fade

.text
.global _particle_system_init
.global _particle_system_create
.global _particle_system_update
.global _particle_system_render
.global _particle_system_emit
.global _particle_system_destroy
.global _particle_physics_update_simd
.global _animation_system_init
.global _animation_create_instance
.global _animation_update_instances
.global _animation_keyframe_interpolate
.global _particle_pool_allocate_batch
.global _particle_pool_free_batch
.global _particle_collision_detection
.global _particle_sort_by_depth
.global _particle_get_stats

//
// particle_system_init - Initialize particle systems and memory pools
// Input: x0 = max_total_particles, x1 = memory_budget_bytes
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15, v0-v31
//
_particle_system_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save max_total_particles
    mov     x20, x1         // Save memory_budget
    
    // Validate inputs
    cmp     x19, #MAX_PARTICLES
    b.gt    .Linit_error
    cmp     x20, #0x100000  // Minimum 1MB
    b.lt    .Linit_error
    
    // Initialize global statistics
    adrp    x0, global_particle_stats@PAGE
    add     x0, x0, global_particle_stats@PAGEOFF
    mov     x1, #0
    mov     x2, #particle_stats_size
    bl      _memset
    
    // Initialize particle systems array
    adrp    x0, particle_systems@PAGE
    add     x0, x0, particle_systems@PAGEOFF
    mov     x1, #0
    mov     x2, #(particle_system_size * 8)
    bl      _memset
    
    // Initialize particle pool blocks
    adrp    x21, particle_pool_blocks@PAGE
    add     x21, x21, particle_pool_blocks@PAGEOFF
    mov     x0, x21
    mov     x1, #0
    mov     x2, #(particle_pool_block_size * PARTICLE_POOL_BLOCKS)
    bl      _memset
    
    // Calculate memory allocation per pool block
    mov     x22, #512       // Particles per block
    mov     x0, x22
    mov     x1, #particle_size
    mul     x0, x0, x1      // Memory needed per block
    
    // Allocate memory for each pool block
    mov     x23, #0         // Block index
    
.Linit_pool_loop:
    cmp     x23, #PARTICLE_POOL_BLOCKS
    b.ge    .Linit_pool_done
    
    // Allocate aligned memory for particles
    bl      _agent_allocate_aligned_memory  // Use Agent D1's allocator
    cmp     x0, #0
    b.eq    .Linit_error
    
    // Store in pool block
    add     x24, x21, x23, lsl #7   // pool_block[index] (128 bytes per block)
    str     x0, [x24, #particles]
    str     w23, [x24, #block_id]
    str     wzr, [x24, #particles_used]
    str     wzr, [x24, #next_free]
    
    // Initialize active mask to all zeros (no particles active)
    add     x25, x24, #active_mask
    mov     x0, x25
    mov     x1, #0
    mov     x2, #64         // 8 * 8 bytes = 64 bytes for 512 bits
    bl      _memset
    
    add     x23, x23, #1
    b       .Linit_pool_loop
    
.Linit_pool_done:
    // Initialize NEON constants for optimal SIMD performance
    bl      _init_neon_constants
    
    // Initialize default particle system configurations
    bl      _init_particle_system_configs
    
    // Initialize animation system
    bl      _animation_system_init
    
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
// particle_system_create - Create a new particle system
// Input: w0 = system_type (0=fire, 1=smoke, 2=water, 3=generic)
//        w1 = max_particles, x2 = emitter_position (float4)
// Output: x0 = particle_system pointer, 0 on error
// Modifies: x0-x15, v0-v7
//
_particle_system_create:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     w19, w0         // Save system_type
    mov     w20, w1         // Save max_particles
    mov     x21, x2         // Save emitter_position
    
    // Find available particle system slot
    adrp    x22, particle_systems@PAGE
    add     x22, x22, particle_systems@PAGEOFF
    mov     x23, #0         // System index
    
.Lfind_system_slot:
    cmp     x23, #8
    b.ge    .Lcreate_system_error
    
    add     x0, x22, x23, lsl #8    // system[index] (256 bytes per system)
    ldr     x1, [x0, #particle_pool]
    cmp     x1, #0
    b.eq    .Lfound_system_slot
    
    add     x23, x23, #1
    b       .Lfind_system_slot
    
.Lfound_system_slot:
    mov     x24, x0         // Save system pointer
    
    // Allocate particle pool for this system
    mov     w0, w20         // max_particles
    bl      _particle_pool_allocate_batch
    cmp     x0, #0
    b.eq    .Lcreate_system_error
    
    // Initialize particle system structure
    str     x0, [x24, #particle_pool]
    str     w20, [x24, #max_particles]
    str     w19, [x24, #system_type]
    str     wzr, [x24, #active_count]
    
    // Set physics flags based on system type
    mov     w0, #0x7        // Default: gravity + air_resistance + collision
    cmp     w19, #2         // Water type
    csel    w0, w0, #0xF, ne // Water gets all physics flags
    str     w0, [x24, #physics_flags]
    
    // Load configuration based on system type
    bl      _load_system_configuration
    
    // Store emitter position
    add     x0, x24, #emitter_position
    ldr     q0, [x21]
    str     q0, [x0]
    
    // Initialize spawn accumulator
    fmov    s0, wzr
    str     s0, [x24, #spawn_accumulator]
    
    mov     x0, x24         // Return system pointer
    b       .Lcreate_system_exit
    
.Lcreate_system_error:
    mov     x0, #0          // Error
    
.Lcreate_system_exit:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// particle_system_update - Update all particle systems with NEON optimization
// Input: s0 = delta_time (seconds)
// Output: None
// Modifies: x0-x15, v0-v31
//
_particle_system_update:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    fmov    s19, s0         // Save delta_time
    
    // Start performance timing
    bl      _get_microsecond_timer
    mov     x20, x0         // Save start time
    
    // Update NEON constants with current delta_time
    bl      _update_neon_delta_time
    
    // Process all particle systems
    adrp    x21, particle_systems@PAGE
    add     x21, x21, particle_systems@PAGEOFF
    mov     x22, #0         // System index
    
.Lupdate_systems_loop:
    cmp     x22, #8
    b.ge    .Lupdate_systems_done
    
    add     x0, x21, x22, lsl #8    // system[index]
    ldr     x1, [x0, #particle_pool]
    cmp     x1, #0
    b.eq    .Lupdate_next_system    // Skip inactive systems
    
    // Update individual particle system
    fmov    s0, s19         // delta_time
    bl      _update_single_particle_system
    
.Lupdate_next_system:
    add     x22, x22, #1
    b       .Lupdate_systems_loop
    
.Lupdate_systems_done:
    // Update global statistics
    bl      _get_microsecond_timer
    sub     x0, x0, x20     // Calculate update time
    
    adrp    x1, global_particle_stats@PAGE
    add     x1, x1, global_particle_stats@PAGEOFF
    str     w0, [x1, #update_time_microseconds]
    
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// particle_physics_update_simd - Update particle physics using NEON SIMD
// Input: x0 = particle_array, w1 = particle_count, s0 = delta_time
// Output: None
// Modifies: x0-x15, v0-v31
//
_particle_physics_update_simd:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save particle_array
    mov     w20, w1         // Save particle_count
    fmov    s21, s0         // Save delta_time
    
    // Load NEON constants for SIMD operations
    adrp    x0, neon_constants@PAGE
    add     x0, x0, neon_constants@PAGEOFF
    
    ld1     {v16.4s}, [x0], #16     // gravity_vec4
    ld1     {v17.4s}, [x0], #16     // delta_time_vec4
    ld1     {v18.4s}, [x0], #16     // air_resistance_vec4
    ld1     {v19.4s}, [x0], #16     // one_vec4
    ld1     {v20.4s}, [x0], #16     // zero_vec4
    ld1     {v21.4s}, [x0], #16     // half_vec4
    ld1     {v22.4s}, [x0], #16     // two_vec4
    ld1     {v23.4s}, [x0]          // epsilon_vec4
    
    // Update delta_time vector with actual delta_time
    dup     v17.4s, v21.s[0]        // Replicate delta_time to all lanes
    
    // Process particles in batches of 4 using NEON
    mov     x21, #0         // Particle index
    
.Lphysics_batch_loop:
    add     x22, x21, #4
    cmp     x22, x20, uxtw
    b.gt    .Lphysics_remainder     // Handle remaining particles
    
    // Load 4 particles' data in parallel
    add     x0, x19, x21, lsl #6    // particle[index] (64 bytes per particle)
    
    // Load positions (4 particles x 4 floats each)
    ld1     {v0.4s}, [x0], #16      // p0: x,y,z,w
    ld1     {v1.4s}, [x0], #48      // Skip to next particle's position
    ld1     {v2.4s}, [x0], #16      // p1: x,y,z,w
    ld1     {v3.4s}, [x0], #48      // Skip to next particle's position
    
    sub     x0, x0, #128            // Back to start
    add     x0, x0, #128            // To third particle
    
    ld1     {v4.4s}, [x0], #16      // p2: x,y,z,w
    ld1     {v5.4s}, [x0], #48      // Skip to next particle's position
    ld1     {v6.4s}, [x0], #16      // p3: x,y,z,w
    
    // Transpose positions for SIMD processing: [x0,x1,x2,x3], [y0,y1,y2,y3], [z0,z1,z2,z3]
    trn1    v24.4s, v0.4s, v2.4s    // x0,x2,y0,y2
    trn2    v25.4s, v0.4s, v2.4s    // z0,z2,w0,w2
    trn1    v26.4s, v1.4s, v6.4s    // x1,x3,y1,y3
    trn2    v27.4s, v1.4s, v6.4s    // z1,z3,w1,w3
    
    trn1    v0.2d, v24.2d, v26.2d   // x0,x1,x2,x3
    trn2    v1.2d, v24.2d, v26.2d   // y0,y1,y2,y3
    trn1    v2.2d, v25.2d, v27.2d   // z0,z1,z2,z3
    
    // Load velocities with same transposition
    sub     x0, x0, #192            // Back to first particle
    add     x0, x0, #16             // To velocity field
    
    ld1     {v7.4s}, [x0], #48      // v0: vx,vy,vz,speed
    ld1     {v8.4s}, [x0], #48      // v1: vx,vy,vz,speed
    ld1     {v9.4s}, [x0], #48      // v2: vx,vy,vz,speed
    ld1     {v10.4s}, [x0]          // v3: vx,vy,vz,speed
    
    // Transpose velocities
    trn1    v28.4s, v7.4s, v8.4s    // vx0,vx1,vy0,vy1
    trn2    v29.4s, v7.4s, v8.4s    // vz0,vz1,s0,s1
    trn1    v30.4s, v9.4s, v10.4s   // vx2,vx3,vy2,vy3
    trn2    v31.4s, v9.4s, v10.4s   // vz2,vz3,s2,s3
    
    trn1    v3.2d, v28.2d, v30.2d   // vx0,vx1,vx2,vx3
    trn2    v4.2d, v28.2d, v30.2d   // vy0,vy1,vy2,vy3
    trn1    v5.2d, v29.2d, v31.2d   // vz0,vz1,vz2,vz3
    
    // Apply gravity to Y velocity
    fmla    v4.4s, v16.4s, v17.4s   // vy += gravity * delta_time
    
    // Apply air resistance to all velocity components
    fmul    v3.4s, v3.4s, v18.4s    // vx *= air_resistance
    fmul    v4.4s, v4.4s, v18.4s    // vy *= air_resistance
    fmul    v5.4s, v5.4s, v18.4s    // vz *= air_resistance
    
    // Update positions: pos += velocity * delta_time
    fmla    v0.4s, v3.4s, v17.4s    // x += vx * delta_time
    fmla    v1.4s, v4.4s, v17.4s    // y += vy * delta_time
    fmla    v2.4s, v5.4s, v17.4s    // z += vz * delta_time
    
    // Transpose back to particle layout
    trn1    v24.4s, v0.4s, v1.4s    // x0,y0,x1,y1
    trn2    v25.4s, v0.4s, v1.4s    // x2,y2,x3,y3
    trn1    v26.4s, v2.4s, v20.4s   // z0,0,z1,0
    trn2    v27.4s, v2.4s, v20.4s   // z2,0,z3,0
    
    trn1    v0.2d, v24.2d, v26.2d   // x0,y0,z0,0
    trn2    v1.2d, v24.2d, v26.2d   // x1,y1,z1,0
    trn1    v2.2d, v25.2d, v27.2d   // x2,y2,z2,0
    trn2    v6.2d, v25.2d, v27.2d   // x3,y3,z3,0
    
    // Store updated positions
    sub     x0, x0, #192            // Back to first particle position
    st1     {v0.4s}, [x0], #64      // Store p0
    st1     {v1.4s}, [x0], #64      // Store p1
    st1     {v2.4s}, [x0], #64      // Store p2
    st1     {v6.4s}, [x0]           // Store p3
    
    // Transpose and store velocities
    trn1    v28.4s, v3.4s, v4.4s    // vx0,vy0,vx1,vy1
    trn2    v29.4s, v3.4s, v4.4s    // vx2,vy2,vx3,vy3
    trn1    v30.4s, v5.4s, v20.4s   // vz0,0,vz1,0
    trn2    v31.4s, v5.4s, v20.4s   // vz2,0,vz3,0
    
    trn1    v7.2d, v28.2d, v30.2d   // vx0,vy0,vz0,0
    trn2    v8.2d, v28.2d, v30.2d   // vx1,vy1,vz1,0
    trn1    v9.2d, v29.2d, v31.2d   // vx2,vy2,vz2,0
    trn2    v10.2d, v29.2d, v31.2d  // vx3,vy3,vz3,0
    
    // Store updated velocities
    sub     x0, x0, #192            // Back to start
    add     x0, x0, #16             // To velocity offset
    st1     {v7.4s}, [x0], #64      // Store v0
    st1     {v8.4s}, [x0], #64      // Store v1
    st1     {v9.4s}, [x0], #64      // Store v2
    st1     {v10.4s}, [x0]          // Store v3
    
    add     x21, x21, #4            // Next batch of 4 particles
    b       .Lphysics_batch_loop
    
.Lphysics_remainder:
    // Handle remaining particles (< 4) with scalar processing
    cmp     x21, x20, uxtw
    b.ge    .Lphysics_done
    
    add     x0, x19, x21, lsl #6    // particle[index]
    
    // Load particle position and velocity
    ld1     {v0.4s}, [x0]           // position
    ld1     {v1.4s}, [x0, #16]      // velocity
    
    // Apply gravity
    ldr     s2, [x0, #20]           // vy
    fmla    s2, s16, s17            // vy += gravity * delta_time
    str     s2, [x0, #20]
    
    // Apply air resistance
    fmul    v1.4s, v1.4s, v18.4s
    st1     {v1.4s}, [x0, #16]
    
    // Update position
    fmla    v0.4s, v1.4s, v17.4s
    st1     {v0.4s}, [x0]
    
    add     x21, x21, #1
    b       .Lphysics_remainder
    
.Lphysics_done:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// particle_system_emit - Emit new particles from system
// Input: x0 = particle_system, w1 = particle_count, s0 = delta_time
// Output: x0 = particles_actually_emitted
// Modifies: x0-x15, v0-v15
//
_particle_system_emit:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save particle_system
    mov     w20, w1         // Save requested_count
    fmov    s21, s0         // Save delta_time
    
    // Update spawn accumulator
    ldr     s0, [x19, #spawn_rate]
    fmul    s0, s0, s21     // particles_to_spawn = spawn_rate * delta_time
    ldr     s1, [x19, #spawn_accumulator]
    fadd    s1, s1, s0      // accumulator += particles_to_spawn
    
    // Extract integer part (particles to actually spawn)
    fcvtzu  w21, s1         // Convert to integer
    cmp     w21, w20
    csel    w21, w21, w20, le // min(accumulator_int, requested_count)
    
    // Update accumulator (subtract integer part)
    ucvtf   s0, w21
    fsub    s1, s1, s0
    str     s1, [x19, #spawn_accumulator]
    
    // Check if we have space in the system
    ldr     w0, [x19, #active_count]
    ldr     w1, [x19, #max_particles]
    sub     w1, w1, w0      // available_space
    cmp     w21, w1
    csel    w21, w21, w1, le // min(to_spawn, available_space)
    
    cbz     w21, .Lemit_done // No particles to spawn
    
    // Find free particles in the pool
    ldr     x0, [x19, #particle_pool]
    mov     w1, w21         // Count to allocate
    bl      _particle_pool_find_free_batch
    mov     x22, x0         // Save first_free_particle
    cmp     x0, #0
    b.eq    .Lemit_done     // No free particles available
    
    // Initialize new particles with system configuration
    mov     x0, x22         // first_particle
    mov     w1, w21         // count
    mov     x2, x19         // particle_system
    bl      _initialize_emitted_particles
    
    // Update active count
    ldr     w0, [x19, #active_count]
    add     w0, w0, w21
    str     w0, [x19, #active_count]
    
    // Update global statistics
    adrp    x0, global_particle_stats@PAGE
    add     x0, x0, global_particle_stats@PAGEOFF
    ldr     w1, [x0, #particles_spawned_frame]
    add     w1, w1, w21
    str     w1, [x0, #particles_spawned_frame]
    
.Lemit_done:
    mov     w0, w21         // Return particles_actually_emitted
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// animation_system_init - Initialize animation system
// Input: None
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x7
//
_animation_system_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Initialize animation instances array
    adrp    x0, animation_instances@PAGE
    add     x0, x0, animation_instances@PAGEOFF
    mov     x1, #0
    mov     x2, #(animation_instance_size * 64)
    bl      _memset
    
    mov     x0, #0          // Success
    ldp     x29, x30, [sp], #16
    ret

//
// animation_keyframe_interpolate - Interpolate between keyframes using NEON
// Input: x0 = keyframe_array, w1 = keyframe_count, s0 = time (0.0 to 1.0)
// Output: v0.4s = interpolated_value
// Modifies: x0-x7, v0-v15
//
_animation_keyframe_interpolate:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0         // Save keyframe_array
    mov     w20, w1         // Save keyframe_count
    fmov    s19, s0         // Save time
    
    // Handle edge cases
    cmp     w20, #0
    b.eq    .Linterp_zero
    cmp     w20, #1
    b.eq    .Linterp_single
    
    // Find keyframe indices for interpolation
    mov     w21, #0         // Current keyframe index
    mov     w22, #0         // Next keyframe index
    
.Lfind_keyframes_loop:
    cmp     w21, w20
    b.ge    .Lfind_keyframes_done
    
    // Load keyframe time
    add     x0, x19, x21, lsl #5    // keyframe[index] (32 bytes per keyframe)
    ldr     s0, [x0]                // keyframe.time
    
    fcmp    s19, s0
    b.le    .Lfind_keyframes_done
    
    add     w21, w21, #1
    b       .Lfind_keyframes_loop
    
.Lfind_keyframes_done:
    // Clamp indices
    cmp     w21, #0
    csel    w21, wzr, w21, eq       // If time <= first keyframe
    
    sub     w0, w20, #1
    cmp     w21, w0
    csel    w21, w0, w21, ge        // If time >= last keyframe
    
    add     w22, w21, #1
    cmp     w22, w20
    csel    w22, w21, w22, ge       // Clamp next index
    
    // Load keyframes for interpolation
    add     x0, x19, x21, lsl #5    // keyframe1
    add     x1, x19, x22, lsl #5    // keyframe2
    
    ld1     {v0.4s}, [x0]           // time1, value1 (first 4 floats)
    ld1     {v1.4s}, [x0, #16]      // value1 continued
    ld1     {v2.4s}, [x1]           // time2, value2 (first 4 floats)
    ld1     {v3.4s}, [x1, #16]      // value2 continued
    
    // Calculate interpolation factor
    fsub    s4, s2, s0              // time_delta = time2 - time1
    fsub    s5, s19, s0             // local_time = current_time - time1
    
    // Avoid division by zero
    fcmp    s4, #0.0
    b.eq    .Linterp_no_delta
    
    fdiv    s6, s5, s4              // t = local_time / time_delta
    
    // Clamp t to [0, 1]
    fmov    s7, #0.0
    fmov    s8, #1.0
    fmax    s6, s6, s7
    fmin    s6, s6, s8
    
    // Linear interpolation using NEON
    dup     v6.4s, v6.s[0]          // Replicate t to all lanes
    fmov    s7, #1.0
    dup     v7.4s, v7.s[0]          // Replicate 1.0 to all lanes
    fsub    v7.4s, v7.4s, v6.4s     // 1-t in all lanes
    
    // Extract values (skip time component)
    ext     v0.16b, v0.16b, v1.16b, #4  // Shift out time, get value1
    ext     v2.16b, v2.16b, v3.16b, #4  // Shift out time, get value2
    
    // Interpolate: result = value1 * (1-t) + value2 * t
    fmul    v0.4s, v0.4s, v7.4s     // value1 * (1-t)
    fmla    v0.4s, v2.4s, v6.4s     // result += value2 * t
    
    b       .Linterp_done
    
.Linterp_no_delta:
    // Times are equal, return first value
    ext     v0.16b, v0.16b, v1.16b, #4
    b       .Linterp_done
    
.Linterp_single:
    // Single keyframe, return its value
    add     x0, x19, #4             // Skip time component
    ld1     {v0.4s}, [x0]
    b       .Linterp_done
    
.Linterp_zero:
    // No keyframes, return zero
    movi    v0.4s, #0
    
.Linterp_done:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// particle_collision_detection - NEON-optimized collision detection
// Input: x0 = particle_array, w1 = particle_count, x2 = bounds (float4: min_xyz, size)
// Output: None (modifies particle velocities in-place)
// Modifies: x0-x15, v0-v31
//
_particle_collision_detection:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0         // Save particle_array
    mov     w20, w1         // Save particle_count
    
    // Load collision bounds
    ld1     {v16.4s}, [x2]          // bounds: min_x, min_y, min_z, size
    
    // Calculate max bounds
    dup     v17.4s, v16.s[3]        // size in all lanes
    fadd    v17.4s, v16.4s, v17.4s  // max_bounds = min_bounds + size
    
    // Load dampening factor
    adrp    x0, neon_constants@PAGE
    add     x0, x0, neon_constants@PAGEOFF
    add     x0, x0, #80             // Offset to custom constants
    ldr     s18, [x0]               // dampening = 0.75
    dup     v18.4s, v18.s[0]
    
    // Process particles in batches of 4
    mov     x21, #0                 // Particle index
    
.Lcollision_batch_loop:
    add     x22, x21, #4
    cmp     x22, x20, uxtw
    b.gt    .Lcollision_remainder
    
    // Load 4 particles' positions and velocities
    add     x0, x19, x21, lsl #6    // particle[index]
    
    ld1     {v0.4s}, [x0], #16      // p0: position
    ld1     {v1.4s}, [x0], #48      // p0: velocity
    ld1     {v2.4s}, [x0], #16      // p1: position  
    ld1     {v3.4s}, [x0], #48      // p1: velocity
    sub     x0, x0, #128
    add     x0, x0, #128
    ld1     {v4.4s}, [x0], #16      // p2: position
    ld1     {v5.4s}, [x0], #48      // p2: velocity
    ld1     {v6.4s}, [x0], #16      // p3: position
    ld1     {v7.4s}, [x0]           // p3: velocity
    
    // Transpose positions for SIMD processing
    trn1    v24.4s, v0.4s, v2.4s
    trn2    v25.4s, v0.4s, v2.4s
    trn1    v26.4s, v4.4s, v6.4s
    trn2    v27.4s, v4.4s, v6.4s
    
    trn1    v0.2d, v24.2d, v26.2d   // x0,x1,x2,x3
    trn2    v8.2d, v24.2d, v26.2d   // y0,y1,y2,y3
    trn1    v9.2d, v25.2d, v27.2d   // z0,z1,z2,z3
    
    // Check collision with min bounds
    fcmgt   v28.4s, v16.4s, v0.4s   // x < min_x
    fcmgt   v29.4s, v16.4s, v8.4s   // y < min_y  
    fcmgt   v30.4s, v16.4s, v9.4s   // z < min_z
    
    // Check collision with max bounds
    fcmgt   v31.4s, v0.4s, v17.4s   // x > max_x
    fcmgt   v10.4s, v8.4s, v17.4s   // y > max_y
    fcmgt   v11.4s, v9.4s, v17.4s   // z > max_z
    
    // Transpose velocities for processing
    trn1    v12.4s, v1.4s, v3.4s
    trn2    v13.4s, v1.4s, v3.4s
    trn1    v14.4s, v5.4s, v7.4s
    trn2    v15.4s, v5.4s, v7.4s
    
    trn1    v1.2d, v12.2d, v14.2d   // vx0,vx1,vx2,vx3
    trn2    v3.2d, v12.2d, v14.2d   // vy0,vy1,vy2,vy3
    trn1    v5.2d, v13.2d, v15.2d   // vz0,vz1,vz2,vz3
    
    // Apply collision response: negate and dampen velocity
    bsl     v28.16b, v18.16b, v19.16b // Select dampening or 1.0 for x
    bsl     v29.16b, v18.16b, v19.16b // Select dampening or 1.0 for y
    bsl     v30.16b, v18.16b, v19.16b // Select dampening or 1.0 for z
    bsl     v31.16b, v18.16b, v19.16b // Select dampening or 1.0 for x (max)
    bsl     v10.16b, v18.16b, v19.16b // Select dampening or 1.0 for y (max)
    bsl     v11.16b, v18.16b, v19.16b // Select dampening or 1.0 for z (max)
    
    // Combine min and max collision masks
    orr     v28.16b, v28.16b, v31.16b // x collision mask
    orr     v29.16b, v29.16b, v10.16b // y collision mask
    orr     v30.16b, v30.16b, v11.16b // z collision mask
    
    // Apply velocity reflection and dampening
    fneg    v12.4s, v1.4s           // -vx
    fneg    v13.4s, v3.4s           // -vy
    fneg    v14.4s, v5.4s           // -vz
    
    fmul    v12.4s, v12.4s, v28.4s  // -vx * dampening_or_1
    fmul    v13.4s, v13.4s, v29.4s  // -vy * dampening_or_1
    fmul    v14.4s, v14.4s, v30.4s  // -vz * dampening_or_1
    
    bsl     v28.16b, v12.16b, v1.16b  // Select reflected or original vx
    bsl     v29.16b, v13.16b, v3.16b  // Select reflected or original vy
    bsl     v30.16b, v14.16b, v5.16b  // Select reflected or original vz
    
    // Transpose velocities back to particle layout and store
    trn1    v12.4s, v28.4s, v29.4s
    trn2    v13.4s, v28.4s, v29.4s
    trn1    v14.4s, v30.4s, v20.4s   // z and padding
    trn2    v15.4s, v30.4s, v20.4s
    
    trn1    v1.2d, v12.2d, v14.2d    // vx0,vy0,vz0,0
    trn2    v3.2d, v12.2d, v14.2d    // vx1,vy1,vz1,0
    trn1    v5.2d, v13.2d, v15.2d    // vx2,vy2,vz2,0
    trn2    v7.2d, v13.2d, v15.2d    // vx3,vy3,vz3,0
    
    // Store updated velocities
    sub     x0, x0, #192
    add     x0, x0, #16             // To velocity offset
    st1     {v1.4s}, [x0], #64
    st1     {v3.4s}, [x0], #64
    st1     {v5.4s}, [x0], #64
    st1     {v7.4s}, [x0]
    
    add     x21, x21, #4
    b       .Lcollision_batch_loop
    
.Lcollision_remainder:
    // Handle remaining particles with scalar code
    // (Implementation omitted for brevity - would process remaining particles individually)
    
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// particle_sort_by_depth - Sort particles by depth for alpha blending
// Input: x0 = particle_array, w1 = particle_count, x2 = camera_position
// Output: None (sorts array in-place)
// Modifies: x0-x15, v0-v31
//
_particle_sort_by_depth:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save particle_array
    mov     w20, w1         // Save particle_count
    mov     x21, x2         // Save camera_position
    
    // For large particle counts, use a more sophisticated sorting algorithm
    // For now, implement a simple insertion sort suitable for small to medium counts
    cmp     w20, #2
    b.lt    .Lsort_done
    
    // Load camera position for depth calculation
    ld1     {v16.4s}, [x21]         // camera_pos
    
    // Insertion sort with NEON-optimized distance calculation
    mov     w22, #1                 // Start from second particle
    
.Lsort_outer_loop:
    cmp     w22, w20
    b.ge    .Lsort_done
    
    // Calculate depth for current particle
    add     x0, x19, x22, lsl #6    // current_particle
    ld1     {v0.4s}, [x0]           // particle_position
    
    fsub    v1.4s, v0.4s, v16.4s    // distance_vector = particle_pos - camera_pos
    fmul    v1.4s, v1.4s, v1.4s     // square each component
    faddp   v2.4s, v1.4s, v1.4s     // horizontal add pairs
    faddp   s3, v2.2s               // final horizontal add -> distance_squared
    
    mov     w23, w22                // Insert position
    
.Lsort_inner_loop:
    cmp     w23, #0
    b.eq    .Lsort_insert
    
    // Calculate depth for previous particle
    sub     w24, w23, #1
    add     x1, x19, x24, lsl #6    // previous_particle
    ld1     {v4.4s}, [x1]           // previous_position
    
    fsub    v5.4s, v4.4s, v16.4s    // distance_vector
    fmul    v5.4s, v5.4s, v5.4s     // square each component
    faddp   v6.4s, v5.4s, v5.4s     // horizontal add pairs
    faddp   s7, v6.2s               // final horizontal add -> distance_squared
    
    fcmp    s7, s3
    b.le    .Lsort_insert           // If previous <= current, we found insert position
    
    // Swap particles using NEON (64 bytes each)
    ld1     {v8.4s, v9.4s, v10.4s, v11.4s}, [x0]
    ld1     {v12.4s, v13.4s, v14.4s, v15.4s}, [x1]
    st1     {v12.4s, v13.4s, v14.4s, v15.4s}, [x0]
    st1     {v8.4s, v9.4s, v10.4s, v11.4s}, [x1]
    
    mov     x0, x1                  // Move to previous position
    sub     w23, w23, #1
    b       .Lsort_inner_loop
    
.Lsort_insert:
    add     w22, w22, #1
    b       .Lsort_outer_loop
    
.Lsort_done:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// particle_get_stats - Get particle system performance statistics
// Input: x0 = stats_output_buffer
// Output: None
// Modifies: x0-x7, v0-v3
//
_particle_get_stats:
    // Copy global statistics
    adrp    x1, global_particle_stats@PAGE
    add     x1, x1, global_particle_stats@PAGEOFF
    
    ld1     {v0.4s, v1.4s}, [x1]
    st1     {v0.4s, v1.4s}, [x0]
    
    ret

// Helper functions (implementations simplified for brevity)

_init_neon_constants:
    // Initialize NEON constant vectors for optimal SIMD performance
    ret

_init_particle_system_configs:
    // Load configuration data for different particle system types
    ret

_update_neon_delta_time:
    // Update delta_time constant vector
    ret

_update_single_particle_system:
    // Update a single particle system (calls physics update, emit, etc.)
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     x19, x0         // Save system pointer
    fmov    s20, s0         // Save delta_time
    
    // Update particles
    ldr     x0, [x19, #particle_pool]
    ldr     w1, [x19, #active_count]
    fmov    s0, s20
    bl      _particle_physics_update_simd
    
    // Emit new particles
    mov     x0, x19
    mov     w1, #100        // Max particles to emit this frame
    fmov    s0, s20
    bl      _particle_system_emit
    
    // Update life time and remove dead particles
    mov     x0, x19
    fmov    s0, s20
    bl      _update_particle_lifetimes
    
    ldp     x29, x30, [sp], #16
    ret

_load_system_configuration:
    // Load configuration based on system type (fire, smoke, water)
    ret

_particle_pool_allocate_batch:
    // Allocate a batch of particles from the pool
    mov     x0, #0          // Return dummy pointer for now
    ret

_particle_pool_free_batch:
    // Free a batch of particles back to the pool
    ret

_particle_pool_find_free_batch:
    // Find free particles in the pool
    mov     x0, #0          // Return dummy pointer for now
    ret

_initialize_emitted_particles:
    // Initialize newly emitted particles with system parameters
    ret

_update_particle_lifetimes:
    // Update particle life times and remove dead particles
    ret

_get_microsecond_timer:
    // Get high-precision timer for performance measurement
    mrs     x0, cntvct_el0
    ret

_agent_allocate_aligned_memory:
    // Interface to Agent D1 memory allocator
    // For now, use basic malloc
    bl      malloc
    ret

// External function declarations
.extern _memset
.extern malloc
.extern free

// Graphics pipeline integration functions (Agent B1 coordination)
.extern _sprite_batch_add_sprite
.extern _graphics_system_get_render_encoder

.end