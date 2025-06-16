// SimCity ARM64 Math Library - Agent Math Operations
// Agent 1: Core Engine Developer
// Specialized NEON-optimized math for 1M+ agent simulation

.cpu generic+simd
.arch armv8-a+simd

// Include platform constants
.include "../include/constants/platform_constants.h"
.include "../include/macros/platform_asm.inc"

.section .data
.align 4

// Constants for agent physics
.agent_max_velocity:    .float 10.0, 10.0, 10.0, 10.0     // Max velocity per axis
.agent_friction:        .float 0.95, 0.95, 0.95, 0.95     // Friction coefficient
.collision_epsilon:     .float 0.001, 0.001, 0.001, 0.001 // Collision detection threshold
.gravity_accel:         .float 0.0, -9.81, 0.0, 0.0       // Gravity acceleration

// Agent type constants
.agent_mass_citizen:    .float 70.0      // Average citizen mass (kg)
.agent_mass_vehicle:    .float 1500.0    // Average vehicle mass (kg)
.agent_radius_citizen:  .float 0.5       // Citizen collision radius (m)
.agent_radius_vehicle:  .float 2.0       // Vehicle collision radius (m)

.section .text
.align 4

//==============================================================================
// Agent Position and Velocity Updates
//==============================================================================

// agent_update_physics_batch: Update physics for multiple agents using NEON
// Args: x0 = agent_array, x1 = count, s0 = delta_time
// Agent structure: pos_x, pos_y, vel_x, vel_y, force_x, force_y, mass, radius (32 bytes)
// Returns: x0 = agent_array pointer
.global agent_update_physics_batch
agent_update_physics_batch:
    cbz     x1, physics_update_done
    
    // Broadcast delta_time to NEON register
    dup     v31.4s, v0.s[0]             // v31 = [dt, dt, dt, dt]
    
    // Load constants
    adrp    x2, .agent_friction
    add     x2, x2, :lo12:.agent_friction
    ld1     {v30.4s}, [x2]              // Friction coefficients
    
    adrp    x2, .agent_max_velocity
    add     x2, x2, :lo12:.agent_max_velocity
    ld1     {v29.4s}, [x2]              // Max velocity limits
    
    // Process 4 agents at a time (each agent is 32 bytes)
    lsr     x2, x1, #2                  // x2 = count / 4
    and     x3, x1, #3                  // x3 = count % 4
    
    cbz     x2, physics_batch_remainder

physics_batch_loop:
    // Load 4 agents worth of data (structure of arrays)
    // Load positions (x, y for 4 agents)
    ld2     {v0.4s, v1.4s}, [x0]        // pos_x[0-3], pos_y[0-3]
    
    // Load velocities (x, y for 4 agents)
    add     x4, x0, #32                 // Skip to velocity data
    ld2     {v2.4s, v3.4s}, [x4]        // vel_x[0-3], vel_y[0-3]
    
    // Load forces (x, y for 4 agents)
    add     x4, x0, #64                 // Skip to force data
    ld2     {v4.4s, v5.4s}, [x4]        // force_x[0-3], force_y[0-3]
    
    // Load masses (4 agents)
    add     x4, x0, #96                 // Skip to mass data
    ld1     {v6.4s}, [x4]               // mass[0-3]
    
    // Calculate acceleration: a = F / m
    fdiv    v7.4s, v4.4s, v6.4s         // accel_x = force_x / mass
    fdiv    v8.4s, v5.4s, v6.4s         // accel_y = force_y / mass
    
    // Update velocity: v = v + a * dt
    fmul    v9.4s, v7.4s, v31.4s        // accel_x * dt
    fmul    v10.4s, v8.4s, v31.4s       // accel_y * dt
    fadd    v2.4s, v2.4s, v9.4s         // vel_x += accel_x * dt
    fadd    v3.4s, v3.4s, v10.4s        // vel_y += accel_y * dt
    
    // Apply friction: v = v * friction
    fmul    v2.4s, v2.4s, v30.4s        // vel_x *= friction
    fmul    v3.4s, v3.4s, v30.4s        // vel_y *= friction
    
    // Clamp velocity to maximum
    fmax    v11.4s, v2.4s, v29.4s       // Clamp positive vel_x
    fneg    v12.4s, v29.4s               // -max_velocity
    fmax    v2.4s, v11.4s, v12.4s        // Clamp negative vel_x
    
    fmax    v11.4s, v3.4s, v29.4s       // Clamp positive vel_y
    fmax    v3.4s, v11.4s, v12.4s        // Clamp negative vel_y
    
    // Update position: pos = pos + vel * dt
    fmul    v11.4s, v2.4s, v31.4s       // vel_x * dt
    fmul    v12.4s, v3.4s, v31.4s       // vel_y * dt
    fadd    v0.4s, v0.4s, v11.4s        // pos_x += vel_x * dt
    fadd    v1.4s, v1.4s, v12.4s        // pos_y += vel_y * dt
    
    // Store updated data back to agents
    st2     {v0.4s, v1.4s}, [x0]        // Store positions
    add     x4, x0, #32
    st2     {v2.4s, v3.4s}, [x4]        // Store velocities
    
    // Clear forces (reset to zero for next frame)
    movi    v13.4s, #0
    add     x4, x0, #64
    st2     {v13.4s, v13.4s}, [x4]      // Clear forces
    
    // Advance to next batch of 4 agents
    add     x0, x0, #128                // 4 agents * 32 bytes each
    
    subs    x2, x2, #1
    b.ne    physics_batch_loop

physics_batch_remainder:
    // Handle remaining agents (< 4)
    cbz     x3, physics_update_done

physics_remainder_loop:
    // Load single agent data
    ldr     s0, [x0]                    // pos_x
    ldr     s1, [x0, #4]                // pos_y
    ldr     s2, [x0, #8]                // vel_x
    ldr     s3, [x0, #12]               // vel_y
    ldr     s4, [x0, #16]               // force_x
    ldr     s5, [x0, #20]               // force_y
    ldr     s6, [x0, #24]               // mass
    
    // Calculate acceleration
    fdiv    s7, s4, s6                  // accel_x = force_x / mass
    fdiv    s8, s5, s6                  // accel_y = force_y / mass
    
    // Update velocity
    fmul    s9, s7, s31.s[0]            // accel_x * dt
    fmul    s10, s8, s31.s[0]           // accel_y * dt
    fadd    s2, s2, s9                  // vel_x += accel_x * dt
    fadd    s3, s3, s10                 // vel_y += accel_y * dt
    
    // Apply friction
    fmul    s2, s2, s30.s[0]            // vel_x *= friction
    fmul    s3, s3, s30.s[0]            // vel_y *= friction
    
    // Clamp velocity
    fabs    s11, s2                     // abs(vel_x)
    fcmp    s11, s29.s[0]               // Compare with max_velocity
    b.le    vel_x_ok
    fcmp    s2, #0.0
    b.ge    vel_x_positive
    fneg    s2, s29.s[0]                // vel_x = -max_velocity
    b       vel_x_ok
vel_x_positive:
    mov     s2, s29.s[0]                // vel_x = max_velocity
vel_x_ok:
    
    fabs    s11, s3                     // abs(vel_y)
    fcmp    s11, s29.s[0]
    b.le    vel_y_ok
    fcmp    s3, #0.0
    b.ge    vel_y_positive
    fneg    s3, s29.s[0]                // vel_y = -max_velocity
    b       vel_y_ok
vel_y_positive:
    mov     s3, s29.s[0]                // vel_y = max_velocity
vel_y_ok:
    
    // Update position
    fmul    s11, s2, s31.s[0]           // vel_x * dt
    fmul    s12, s3, s31.s[0]           // vel_y * dt
    fadd    s0, s0, s11                 // pos_x += vel_x * dt
    fadd    s1, s1, s12                 // pos_y += vel_y * dt
    
    // Store updated data
    str     s0, [x0]                    // pos_x
    str     s1, [x0, #4]                // pos_y
    str     s2, [x0, #8]                // vel_x
    str     s3, [x0, #12]               // vel_y
    
    // Clear forces
    movi    v13.4s, #0
    str     s13, [x0, #16]              // force_x = 0
    str     s13, [x0, #20]              // force_y = 0
    
    // Advance to next agent
    add     x0, x0, #32
    subs    x3, x3, #1
    b.ne    physics_remainder_loop

physics_update_done:
    ret

//==============================================================================
// Collision Detection and Response
//==============================================================================

// agent_collision_check_batch: Check collisions between agents using NEON
// Args: x0 = agent_array, x1 = count, x2 = collision_results
// Returns: x0 = number of collisions detected
.global agent_collision_check_batch
agent_collision_check_batch:
    cbz     x1, collision_check_done
    
    mov     x3, #0                      // Collision counter
    mov     x4, x0                      // Save agent array start
    
    // Outer loop: for each agent
    mov     x5, #0                      // i = 0
outer_collision_loop:
    cmp     x5, x1
    b.ge    collision_check_done
    
    // Load agent i data
    add     x6, x4, x5, lsl #5          // agent_i = base + i * 32
    ldr     s0, [x6]                    // pos_x_i
    ldr     s1, [x6, #4]                // pos_y_i
    ldr     s7, [x6, #28]               // radius_i
    
    // Inner loop: check against agents j > i
    add     x7, x5, #1                  // j = i + 1
inner_collision_loop:
    cmp     x7, x1
    b.ge    next_outer_agent
    
    // Load agent j data
    add     x8, x4, x7, lsl #5          // agent_j = base + j * 32
    ldr     s2, [x8]                    // pos_x_j
    ldr     s3, [x8, #4]                // pos_y_j
    ldr     s8, [x8, #28]               // radius_j
    
    // Calculate distance between agents
    fsub    s4, s0, s2                  // dx = pos_x_i - pos_x_j
    fsub    s5, s1, s3                  // dy = pos_y_i - pos_y_j
    fmul    s4, s4, s4                  // dx²
    fmul    s5, s5, s5                  // dy²
    fadd    s6, s4, s5                  // distance² = dx² + dy²
    
    // Calculate collision threshold
    fadd    s9, s7, s8                  // radius_sum = radius_i + radius_j
    fmul    s9, s9, s9                  // radius_sum²
    
    // Check collision
    fcmp    s6, s9
    b.ge    no_collision
    
    // Collision detected - store collision pair
    lsl     x9, x3, #3                  // collision_index * 8 (2 ints per collision)
    add     x10, x2, x9
    str     w5, [x10]                   // Store agent i index
    str     w7, [x10, #4]               // Store agent j index
    add     x3, x3, #1                  // Increment collision counter

no_collision:
    add     x7, x7, #1                  // j++
    b       inner_collision_loop

next_outer_agent:
    add     x5, x5, #1                  // i++
    b       outer_collision_loop

collision_check_done:
    mov     x0, x3                      // Return collision count
    ret

//==============================================================================
// Spatial Partitioning for Collision Optimization
//==============================================================================

// agent_spatial_hash: Create spatial hash for efficient collision detection
// Args: x0 = agent_array, x1 = count, x2 = hash_table, x3 = grid_size
// Returns: x0 = hash_table pointer
.global agent_spatial_hash
agent_spatial_hash:
    cbz     x1, spatial_hash_done
    
    // Clear hash table first
    mov     x4, #0
    lsl     x5, x3, #2                  // grid_size² * 4 bytes per entry
clear_hash_loop:
    str     wzr, [x2, x4]
    add     x4, x4, #4
    cmp     x4, x5
    b.lt    clear_hash_loop
    
    // Hash each agent into spatial grid
    mov     x4, #0                      // Agent index
hash_agents_loop:
    cmp     x4, x1
    b.ge    spatial_hash_done
    
    // Load agent position
    lsl     x5, x4, #5                  // agent_offset = index * 32
    add     x6, x0, x5
    ldr     s0, [x6]                    // pos_x
    ldr     s1, [x6, #4]                // pos_y
    
    // Convert world position to grid coordinates
    fcvtzs  w7, s0                      // grid_x = (int)pos_x
    fcvtzs  w8, s1                      // grid_y = (int)pos_y
    
    // Clamp to grid bounds
    cmp     w7, #0
    csel    w7, w7, wzr, ge             // max(grid_x, 0)
    cmp     w7, w3
    csel    w7, w3, w7, lt              // min(grid_x, grid_size-1)
    
    cmp     w8, #0
    csel    w8, w8, wzr, ge             // max(grid_y, 0)
    cmp     w8, w3
    csel    w8, w3, w8, lt              // min(grid_y, grid_size-1)
    
    // Calculate hash table index
    mul     w9, w8, w3                  // grid_y * grid_size
    add     w9, w9, w7                  // grid_y * grid_size + grid_x
    
    // Store agent index in hash table (simple chaining with next agent)
    lsl     x10, x9, #2                 // hash_index * 4
    add     x11, x2, x10
    ldr     w12, [x11]                  // Load current head of chain
    str     w4, [x11]                   // Store current agent as new head
    
    // Store next pointer in agent data (reuse unused space)
    str     w12, [x6, #32]              // Store old head as next pointer
    
    add     x4, x4, #1                  // Next agent
    b       hash_agents_loop

spatial_hash_done:
    mov     x0, x2                      // Return hash table
    ret

//==============================================================================
// Pathfinding Cost Calculations
//==============================================================================

// agent_calculate_pathfind_costs: Calculate A* heuristic costs for agents
// Args: x0 = agent_positions, x1 = goal_positions, x2 = costs, x3 = count
// Returns: x0 = costs pointer
.global agent_calculate_pathfind_costs
agent_calculate_pathfind_costs:
    cbz     x3, pathfind_costs_done
    
    // Process 4 agents at a time using NEON
    lsr     x4, x3, #2                  // count / 4
    and     x5, x3, #3                  // count % 4
    
    cbz     x4, pathfind_costs_remainder

pathfind_costs_loop:
    // Load 4 agent positions
    ld2     {v0.4s, v1.4s}, [x0], #32   // agent_pos_x[0-3], agent_pos_y[0-3]
    
    // Load 4 goal positions
    ld2     {v2.4s, v3.4s}, [x1], #32   // goal_pos_x[0-3], goal_pos_y[0-3]
    
    // Calculate Manhattan distance (heuristic for A*)
    fsub    v4.4s, v0.4s, v2.4s         // dx = agent_x - goal_x
    fsub    v5.4s, v1.4s, v3.4s         // dy = agent_y - goal_y
    fabs    v4.4s, v4.4s                // abs(dx)
    fabs    v5.4s, v5.4s                // abs(dy)
    fadd    v6.4s, v4.4s, v5.4s         // Manhattan distance = abs(dx) + abs(dy)
    
    // Store costs
    st1     {v6.4s}, [x2], #16
    
    subs    x4, x4, #1
    b.ne    pathfind_costs_loop

pathfind_costs_remainder:
    cbz     x5, pathfind_costs_done

pathfind_remainder_loop:
    // Load single agent and goal positions
    ldr     s0, [x0], #4                // agent_x
    ldr     s1, [x0], #4                // agent_y
    ldr     s2, [x1], #4                // goal_x
    ldr     s3, [x1], #4                // goal_y
    
    // Calculate Manhattan distance
    fsub    s4, s0, s2                  // dx
    fsub    s5, s1, s3                  // dy
    fabs    s4, s4                      // abs(dx)
    fabs    s5, s5                      // abs(dy)
    fadd    s6, s4, s5                  // Manhattan distance
    
    // Store cost
    str     s6, [x2], #4
    
    subs    x5, x5, #1
    b.ne    pathfind_remainder_loop

pathfind_costs_done:
    ret

//==============================================================================
// Agent Steering Behaviors
//==============================================================================

// agent_apply_steering_forces: Apply steering behaviors to agents
// Args: x0 = agent_array, x1 = target_positions, x2 = count, s0 = max_force
// Returns: x0 = agent_array pointer
.global agent_apply_steering_forces
agent_apply_steering_forces:
    cbz     x2, steering_forces_done
    
    // Broadcast max_force to NEON register
    dup     v31.4s, v0.s[0]
    
    mov     x3, #0                      // Agent index
steering_loop:
    cmp     x3, x2
    b.ge    steering_forces_done
    
    // Load agent data
    lsl     x4, x3, #5                  // agent_offset = index * 32
    add     x5, x0, x4
    ldr     s0, [x5]                    // pos_x
    ldr     s1, [x5, #4]                // pos_y
    ldr     s2, [x5, #8]                // vel_x
    ldr     s3, [x5, #12]               // vel_y
    
    // Load target position
    lsl     x6, x3, #3                  // target_offset = index * 8
    add     x7, x1, x6
    ldr     s4, [x7]                    // target_x
    ldr     s5, [x7, #4]                // target_y
    
    // Calculate desired velocity (towards target)
    fsub    s6, s4, s0                  // desired_x = target_x - pos_x
    fsub    s7, s5, s1                  // desired_y = target_y - pos_y
    
    // Normalize desired velocity
    fmul    s8, s6, s6                  // desired_x²
    fmul    s9, s7, s7                  // desired_y²
    fadd    s10, s8, s9                 // length²
    fsqrt   s10, s10                    // length
    
    fcmp    s10, #0.001                 // Check for near-zero length
    b.lt    next_steering_agent
    
    fdiv    s6, s6, s10                 // normalized desired_x
    fdiv    s7, s7, s10                 // normalized desired_y
    
    // Scale to desired speed (max_force acts as max speed here)
    fmul    s6, s6, s31.s[0]            // desired_vel_x
    fmul    s7, s7, s31.s[0]            // desired_vel_y
    
    // Calculate steering force: steering = desired - current
    fsub    s8, s6, s2                  // steering_x = desired_vel_x - vel_x
    fsub    s9, s7, s3                  // steering_y = desired_vel_y - vel_y
    
    // Limit steering force magnitude
    fmul    s10, s8, s8                 // steering_x²
    fmul    s11, s9, s9                 // steering_y²
    fadd    s12, s10, s11               // steering_magnitude²
    fsqrt   s12, s12                    // steering_magnitude
    
    fcmp    s12, s31.s[0]               // Compare with max_force
    b.le    steering_force_ok
    
    // Limit steering force
    fdiv    s13, s31.s[0], s12          // scale = max_force / magnitude
    fmul    s8, s8, s13                 // steering_x *= scale
    fmul    s9, s9, s13                 // steering_y *= scale

steering_force_ok:
    // Add steering force to agent forces
    ldr     s14, [x5, #16]              // current force_x
    ldr     s15, [x5, #20]              // current force_y
    fadd    s14, s14, s8                // force_x += steering_x
    fadd    s15, s15, s9                // force_y += steering_y
    str     s14, [x5, #16]              // Store force_x
    str     s15, [x5, #20]              // Store force_y

next_steering_agent:
    add     x3, x3, #1                  // Next agent
    b       steering_loop

steering_forces_done:
    ret

//==============================================================================
// Performance Monitoring
//==============================================================================

// agent_math_benchmark: Benchmark agent math operations
// Args: x0 = agent_count, x1 = iterations
// Returns: x0 = time_per_iteration_ns
.global agent_math_benchmark
agent_math_benchmark:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0                     // Save agent count
    mov     x20, x1                     // Save iterations
    
    // Allocate test agent array
    lsl     x0, x19, #5                 // agent_count * 32 bytes
    bl      malloc
    mov     x21, x0                     // Save agent array
    
    // Initialize test agents
    mov     x22, #0
init_agents_loop:
    cmp     x22, x19
    b.ge    benchmark_start
    
    lsl     x0, x22, #5
    add     x0, x21, x0
    
    // Initialize with random-ish values
    scvtf   s0, w22
    str     s0, [x0]                    // pos_x
    str     s0, [x0, #4]                // pos_y
    fmov    s1, #1.0
    str     s1, [x0, #8]                // vel_x
    str     s1, [x0, #12]               // vel_y
    str     s1, [x0, #16]               // force_x
    str     s1, [x0, #20]               // force_y
    fmov    s2, #70.0
    str     s2, [x0, #24]               // mass
    fmov    s3, #0.5
    str     s3, [x0, #28]               // radius
    
    add     x22, x22, #1
    b       init_agents_loop

benchmark_start:
    // Start timing
    mrs     x22, cntvct_el0
    
    // Benchmark loop
    mov     x0, x20
benchmark_iteration:
    mov     x1, x21                     // agent_array
    mov     x2, x19                     // count
    fmov    s0, #0.016                  // delta_time (60 FPS)
    bl      agent_update_physics_batch
    
    subs    x0, x0, #1
    b.ne    benchmark_iteration
    
    // End timing
    mrs     x0, cntvct_el0
    sub     x0, x0, x22                 // Total time
    udiv    x0, x0, x20                 // Time per iteration
    
    // Free test data
    mov     x22, x0                     // Save result
    mov     x0, x21
    bl      free
    
    mov     x0, x22                     // Return result
    
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

.end