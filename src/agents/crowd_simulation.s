//
// SimCity ARM64 Assembly - Crowd Simulation with Flow Fields
// Agent 4: AI and Behavior Systems Engineer
//
// High-performance crowd simulation for 1M+ agents using flow fields
// Implements efficient agent movement, collision avoidance, and density management
// Target: <10ms update time for all agents with LOD optimization
//

.text
.align 4

// Include dependencies
.include "../simulation/simulation_constants.s"
.include "../include/constants/memory.inc"

// ============================================================================
// CROWD SIMULATION CONSTANTS
// ============================================================================

// Agent density management
.equ CROWD_DENSITY_THRESHOLD,   16          // Max agents per flow cell
.equ CROWD_CONGESTION_PENALTY,  50          // Movement penalty in crowded areas
.equ CROWD_AVOIDANCE_RADIUS,    3           // Collision avoidance radius (tiles)

// Flow field integration
.equ CROWD_FLOW_WEIGHT,         70          // Flow field influence (0-100)
.equ CROWD_GOAL_WEIGHT,         30          // Direct goal influence (0-100)
.equ CROWD_SEPARATION_WEIGHT,   80          // Agent separation force weight

// Performance optimization
.equ CROWD_UPDATE_BATCH_SIZE,   4096        // Agents processed per batch
.equ CROWD_LOD_NEAR_DISTANCE,   32          // Distance for near LOD
.equ CROWD_LOD_MEDIUM_DISTANCE, 128         // Distance for medium LOD
.equ CROWD_LOD_FAR_DISTANCE,    512         // Distance for far LOD

// Movement physics
.equ CROWD_MAX_VELOCITY,        100         // Maximum velocity (tiles/sec * 100)
.equ CROWD_MAX_ACCELERATION,    50          // Maximum acceleration
.equ CROWD_FRICTION_FACTOR,     90          // Friction coefficient (%)
.equ CROWD_COLLISION_DAMPING,   60          // Collision response damping

// ============================================================================
// STRUCTURE DEFINITIONS
// ============================================================================

// Crowd agent movement data (64 bytes, cache-friendly)
.struct CrowdAgent
    position_x              .word           // Current X position (fixed point)
    position_y              .word           // Current Y position (fixed point)
    velocity_x              .hword          // Current X velocity
    velocity_y              .hword          // Current Y velocity
    
    goal_x                  .word           // Target X position
    goal_y                  .word           // Target Y position
    
    flow_cell_x             .hword          // Current flow field cell X
    flow_cell_y             .hword          // Current flow field cell Y
    
    agent_id                .word           // Reference to main agent ID
    lod_level               .byte           // Level of detail (0=near, 3=culled)
    movement_state          .byte           // Movement state flags
    crowd_density           .byte           // Local crowd density
    avoidance_flags         .byte           // Collision avoidance flags
    
    desired_velocity_x      .hword          // Desired velocity from flow field
    desired_velocity_y      .hword          // Desired velocity from flow field
    
    separation_force_x      .hword          // Separation force from nearby agents
    separation_force_y      .hword          // Separation force from nearby agents
    
    last_update_frame       .word           // Last frame this agent was updated
    next_path_update        .word           // Next frame to update pathfinding
    
    reserved                .space 16       // Reserved for future use/alignment
.endstruct

// Crowd density cell (16 bytes)
.struct CrowdDensityCell
    agent_count             .hword          // Number of agents in this cell
    total_velocity_x        .word           // Sum of agent velocities X
    total_velocity_y        .word           // Sum of agent velocities Y
    congestion_level        .byte           // Congestion level (0-255)
    heat_map_value          .byte           // Heat map for visualization
    last_update_frame       .word           // Last frame this cell was updated
.endstruct

// Crowd simulation system state
.struct CrowdSimulation
    // Agent management
    crowd_agents            .quad           // Array of crowd agents
    active_agent_count      .word           // Number of active agents
    max_agents              .word           // Maximum agent capacity
    
    // Density tracking
    density_grid            .quad           // Grid of density cells
    grid_width              .word           // Density grid width
    grid_height             .word           // Density grid height
    cell_size               .word           // Size of each density cell
    
    // Performance tracking
    update_time_ns          .quad           // Last update time in nanoseconds
    total_updates           .quad           // Total number of updates
    agents_updated_count    .word           // Agents updated in last frame
    lod_distribution        .space 16       // Count of agents per LOD level
    
    // Flow field integration
    flow_field_pointer      .quad           // Pointer to pathfinding flow fields
    flow_field_update_freq  .word           // Frames between flow field updates
    
    // Spatial indexing for collision detection
    spatial_hash_table      .quad           // Hash table for spatial lookups
    spatial_hash_size       .word           // Size of spatial hash table
    collision_pairs         .quad           // Array of collision pairs
    max_collision_pairs     .word           // Maximum collision pairs per frame
    
    // Camera position for LOD calculations
    camera_x                .word           // Camera X position
    camera_y                .word           // Camera Y position
    lod_distance_scale      .word           // LOD distance scaling factor
.endstruct

// ============================================================================
// GLOBAL DATA
// ============================================================================

.section .bss
.align 8

// Main crowd simulation system
crowd_simulation:          .space CrowdSimulation_size

// Agent arrays (structured for cache efficiency)
.align 64
crowd_agents_array:        .space (MAX_AGENTS * CrowdAgent_size)

// Density grid (64x64 cells covering 4096x4096 world)
.align 64
crowd_density_grid:        .space (64 * 64 * CrowdDensityCell_size)

// Spatial hash table for collision detection
.align 64
spatial_hash_table:        .space (8192 * 8)     // Hash table entries
collision_pairs_array:     .space (16384 * 16)   // Collision pair data

// Performance measurement data
.align 64
performance_counters:      .space 128

.section .text

// ============================================================================
// GLOBAL SYMBOLS
// ============================================================================

.global crowd_simulation_init
.global crowd_simulation_shutdown
.global crowd_simulation_update
.global crowd_agent_add
.global crowd_agent_remove
.global crowd_agent_set_goal
.global crowd_agent_get_position
.global crowd_get_density_at
.global crowd_update_lod_levels
.global crowd_get_performance_stats

// External dependencies
.extern pathfinding_system
.extern flow_field_get_direction
.extern get_current_time_ns

// ============================================================================
// CROWD SIMULATION INITIALIZATION
// ============================================================================

//
// crowd_simulation_init - Initialize the crowd simulation system
//
// Parameters:
//   x0 = max_agents
//   x1 = world_width
//   x2 = world_height
//
// Returns:
//   x0 = 0 on success, error code on failure
//
crowd_simulation_init:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // max_agents
    mov     x20, x1                     // world_width
    mov     x21, x2                     // world_height
    
    // Initialize crowd simulation structure
    adrp    x22, crowd_simulation
    add     x22, x22, :lo12:crowd_simulation
    
    // Clear entire structure
    mov     x0, #0
    mov     x1, #(CrowdSimulation_size / 8)
1:  str     x0, [x22], #8
    subs    x1, x1, #1
    b.ne    1b
    
    // Reset pointer
    adrp    x22, crowd_simulation
    add     x22, x22, :lo12:crowd_simulation
    
    // Set up agent array
    adrp    x0, crowd_agents_array
    add     x0, x0, :lo12:crowd_agents_array
    str     x0, [x22, #CrowdSimulation.crowd_agents]
    str     w19, [x22, #CrowdSimulation.max_agents]
    str     wzr, [x22, #CrowdSimulation.active_agent_count]
    
    // Set up density grid
    adrp    x0, crowd_density_grid
    add     x0, x0, :lo12:crowd_density_grid
    str     x0, [x22, #CrowdSimulation.density_grid]
    
    // Calculate density grid dimensions
    lsr     w1, w20, #6                 // world_width / 64
    lsr     w2, w21, #6                 // world_height / 64
    str     w1, [x22, #CrowdSimulation.grid_width]
    str     w2, [x22, #CrowdSimulation.grid_height]
    mov     w0, #64                     // 64 tiles per cell
    str     w0, [x22, #CrowdSimulation.cell_size]
    
    // Set up spatial hash table
    adrp    x0, spatial_hash_table
    add     x0, x0, :lo12:spatial_hash_table
    str     x0, [x22, #CrowdSimulation.spatial_hash_table]
    mov     w0, #8192
    str     w0, [x22, #CrowdSimulation.spatial_hash_size]
    
    adrp    x0, collision_pairs_array
    add     x0, x0, :lo12:collision_pairs_array
    str     x0, [x22, #CrowdSimulation.collision_pairs]
    mov     w0, #16384
    str     w0, [x22, #CrowdSimulation.max_collision_pairs]
    
    // Initialize density grid
    bl      clear_density_grid
    
    // Initialize spatial hash table
    bl      clear_spatial_hash
    
    // Initialize all crowd agents to inactive state
    bl      clear_crowd_agents
    
    // Set default LOD settings
    mov     w0, #100                    // Default LOD distance scale
    str     w0, [x22, #CrowdSimulation.lod_distance_scale]
    
    // Connect to pathfinding flow fields
    adrp    x0, pathfinding_system
    add     x0, x0, :lo12:pathfinding_system
    str     x0, [x22, #CrowdSimulation.flow_field_pointer]
    mov     w0, #4                      // Update flow fields every 4 frames
    str     w0, [x22, #CrowdSimulation.flow_field_update_freq]
    
    mov     x0, #0                      // Success
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// clear_density_grid - Initialize density grid to default values
//
clear_density_grid:
    adrp    x0, crowd_density_grid
    add     x0, x0, :lo12:crowd_density_grid
    
    mov     x1, #0                      // cell_index
    mov     x2, #(64 * 64)              // total_cells
    
clear_density_loop:
    cmp     x1, x2
    b.ge    clear_density_done
    
    // Calculate cell address
    mov     x3, #CrowdDensityCell_size
    mul     x4, x1, x3
    add     x3, x0, x4                  // cell_ptr
    
    // Initialize cell
    strh    wzr, [x3, #CrowdDensityCell.agent_count]
    str     wzr, [x3, #CrowdDensityCell.total_velocity_x]
    str     wzr, [x3, #CrowdDensityCell.total_velocity_y]
    strb    wzr, [x3, #CrowdDensityCell.congestion_level]
    strb    wzr, [x3, #CrowdDensityCell.heat_map_value]
    str     wzr, [x3, #CrowdDensityCell.last_update_frame]
    
    add     x1, x1, #1
    b       clear_density_loop

clear_density_done:
    ret

//
// clear_spatial_hash - Initialize spatial hash table
//
clear_spatial_hash:
    adrp    x0, spatial_hash_table
    add     x0, x0, :lo12:spatial_hash_table
    
    mov     x1, #0
    mov     x2, #8192                   // hash_table_size
    
1:  str     x1, [x0], #8
    subs    x2, x2, #1
    b.ne    1b
    
    ret

//
// clear_crowd_agents - Initialize all crowd agents to inactive
//
clear_crowd_agents:
    adrp    x0, crowd_agents_array
    add     x0, x0, :lo12:crowd_agents_array
    
    mov     x1, #0                      // agent_index
    mov     x2, #MAX_AGENTS
    
clear_agents_loop:
    cmp     x1, x2
    b.ge    clear_agents_done
    
    // Calculate agent address
    mov     x3, #CrowdAgent_size
    mul     x4, x1, x3
    add     x3, x0, x4                  // agent_ptr
    
    // Initialize agent to inactive state
    mov     w4, #-1
    str     w4, [x3, #CrowdAgent.agent_id] // -1 = inactive
    str     wzr, [x3, #CrowdAgent.position_x]
    str     wzr, [x3, #CrowdAgent.position_y]
    strh    wzr, [x3, #CrowdAgent.velocity_x]
    strh    wzr, [x3, #CrowdAgent.velocity_y]
    mov     w4, #3                      // LOD_CULLED
    strb    w4, [x3, #CrowdAgent.lod_level]
    
    add     x1, x1, #1
    b       clear_agents_loop

clear_agents_done:
    ret

// ============================================================================
// CROWD AGENT MANAGEMENT
// ============================================================================

//
// crowd_agent_add - Add an agent to crowd simulation
//
// Parameters:
//   x0 = agent_id
//   x1 = position_x
//   x2 = position_y
//   x3 = goal_x
//   x4 = goal_y
//
// Returns:
//   x0 = crowd_agent_index (or -1 if failed)
//
crowd_agent_add:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    
    mov     x19, x0                     // agent_id
    mov     x20, x1                     // position_x
    mov     x21, x2                     // position_y
    mov     x22, x3                     // goal_x
    mov     x23, x4                     // goal_y
    
    // Find free crowd agent slot
    adrp    x24, crowd_agents_array
    add     x24, x24, :lo12:crowd_agents_array
    
    mov     x25, #0                     // search_index
    mov     x26, #MAX_AGENTS
    
find_free_slot:
    cmp     x25, x26
    b.ge    crowd_add_failed
    
    // Calculate agent address
    mov     x0, #CrowdAgent_size
    mul     x1, x25, x0
    add     x0, x24, x1                 // agent_ptr
    
    // Check if slot is free
    ldr     w1, [x0, #CrowdAgent.agent_id]
    cmp     w1, #-1                     // -1 = inactive
    b.eq    crowd_add_found_slot
    
    add     x25, x25, #1
    b       find_free_slot

crowd_add_found_slot:
    // Initialize new crowd agent
    str     w19, [x0, #CrowdAgent.agent_id]
    str     w20, [x0, #CrowdAgent.position_x]
    str     w21, [x0, #CrowdAgent.position_y]
    str     w22, [x0, #CrowdAgent.goal_x]
    str     w23, [x0, #CrowdAgent.goal_y]
    
    // Initialize movement state
    strh    wzr, [x0, #CrowdAgent.velocity_x]
    strh    wzr, [x0, #CrowdAgent.velocity_y]
    strh    wzr, [x0, #CrowdAgent.desired_velocity_x]
    strh    wzr, [x0, #CrowdAgent.desired_velocity_y]
    strh    wzr, [x0, #CrowdAgent.separation_force_x]
    strh    wzr, [x0, #CrowdAgent.separation_force_y]
    
    // Calculate flow field cell
    lsr     w1, w20, #6                 // position_x / 64
    lsr     w2, w21, #6                 // position_y / 64
    strh    w1, [x0, #CrowdAgent.flow_cell_x]
    strh    w2, [x0, #CrowdAgent.flow_cell_y]
    
    // Set initial LOD level based on distance to camera
    bl      calculate_agent_lod
    strb    w1, [x0, #CrowdAgent.lod_level]
    
    // Initialize timing
    bl      get_current_frame_number
    str     w0, [x0, #CrowdAgent.last_update_frame]
    add     w1, w0, #1
    str     w1, [x0, #CrowdAgent.next_path_update]
    
    // Update active agent count
    adrp    x1, crowd_simulation
    add     x1, x1, :lo12:crowd_simulation
    ldr     w2, [x1, #CrowdSimulation.active_agent_count]
    add     w2, w2, #1
    str     w2, [x1, #CrowdSimulation.active_agent_count]
    
    mov     x0, x25                     // Return agent index
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

crowd_add_failed:
    mov     x0, #-1                     // Failed
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//
// crowd_agent_set_goal - Update agent's movement goal
//
// Parameters:
//   x0 = crowd_agent_index
//   x1 = new_goal_x
//   x2 = new_goal_y
//
crowd_agent_set_goal:
    // Validate agent index
    cmp     x0, #MAX_AGENTS
    b.ge    crowd_set_goal_invalid
    
    // Calculate agent address
    adrp    x3, crowd_agents_array
    add     x3, x3, :lo12:crowd_agents_array
    mov     x4, #CrowdAgent_size
    mul     x5, x0, x4
    add     x3, x3, x5                  // agent_ptr
    
    // Check if agent is active
    ldr     w4, [x3, #CrowdAgent.agent_id]
    cmp     w4, #-1
    b.eq    crowd_set_goal_invalid
    
    // Update goal
    str     w1, [x3, #CrowdAgent.goal_x]
    str     w2, [x3, #CrowdAgent.goal_y]
    
    // Trigger path update on next frame
    bl      get_current_frame_number
    str     w0, [x3, #CrowdAgent.next_path_update]
    
    mov     x0, #0                      // Success
    ret

crowd_set_goal_invalid:
    mov     x0, #-1                     // Invalid
    ret

// ============================================================================
// CROWD SIMULATION UPDATE SYSTEM
// ============================================================================

//
// crowd_simulation_update - Main crowd simulation update function
//
// Parameters:
//   x0 = delta_time_ms
//   x1 = camera_x
//   x2 = camera_y
//
// Returns:
//   x0 = 0 on success
//
crowd_simulation_update:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    
    mov     x19, x0                     // delta_time_ms
    mov     x20, x1                     // camera_x
    mov     x21, x2                     // camera_y
    
    // Start performance timing
    bl      get_current_time_ns
    mov     x22, x0                     // start_time
    
    // Update camera position for LOD calculations
    adrp    x23, crowd_simulation
    add     x23, x23, :lo12:crowd_simulation
    str     w20, [x23, #CrowdSimulation.camera_x]
    str     w21, [x23, #CrowdSimulation.camera_y]
    
    // Clear density grid for this frame
    bl      clear_density_grid
    
    // Update LOD levels for all agents
    bl      crowd_update_lod_levels
    
    // Process agents in batches for cache efficiency
    mov     x24, #0                     // processed_count
    
update_batch_loop:
    // Process batch of agents
    mov     x0, x24                     // start_index
    mov     x1, #CROWD_UPDATE_BATCH_SIZE // batch_size
    mov     x2, x19                     // delta_time_ms
    bl      crowd_update_agent_batch
    
    add     x24, x24, #CROWD_UPDATE_BATCH_SIZE
    ldr     w0, [x23, #CrowdSimulation.active_agent_count]
    cmp     x24, x0
    b.lt    update_batch_loop
    
    // Update density grid statistics
    bl      crowd_update_density_stats
    
    // Handle collisions for near LOD agents
    bl      crowd_process_collisions
    
    // Update performance statistics
    bl      get_current_time_ns
    sub     x0, x0, x22                 // update_time_ns
    str     x0, [x23, #CrowdSimulation.update_time_ns]
    
    ldr     x1, [x23, #CrowdSimulation.total_updates]
    add     x1, x1, #1
    str     x1, [x23, #CrowdSimulation.total_updates]
    
    mov     x0, #0                      // Success
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//
// crowd_update_agent_batch - Update a batch of agents
//
// Parameters:
//   x0 = start_index
//   x1 = batch_size
//   x2 = delta_time_ms
//
crowd_update_agent_batch:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    
    mov     x19, x0                     // start_index
    mov     x20, x1                     // batch_size
    mov     x21, x2                     // delta_time_ms
    
    // Get agent array base
    adrp    x22, crowd_agents_array
    add     x22, x22, :lo12:crowd_agents_array
    
    mov     x23, x19                    // current_index
    add     x24, x19, x20               // end_index
    
agent_batch_loop:
    cmp     x23, x24
    b.ge    agent_batch_done
    cmp     x23, #MAX_AGENTS
    b.ge    agent_batch_done
    
    // Calculate agent address
    mov     x0, #CrowdAgent_size
    mul     x1, x23, x0
    add     x25, x22, x1                // agent_ptr
    
    // Check if agent is active
    ldr     w0, [x25, #CrowdAgent.agent_id]
    cmp     w0, #-1
    b.eq    agent_batch_next
    
    // Update this agent
    mov     x0, x25                     // agent_ptr
    mov     x1, x21                     // delta_time_ms
    bl      crowd_update_single_agent
    
agent_batch_next:
    add     x23, x23, #1
    b       agent_batch_loop

agent_batch_done:
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//
// crowd_update_single_agent - Update movement for a single agent
//
// Parameters:
//   x0 = agent_ptr
//   x1 = delta_time_ms
//
crowd_update_single_agent:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    
    mov     x19, x0                     // agent_ptr
    mov     x20, x1                     // delta_time_ms
    
    // Check LOD level - skip updates for far agents
    ldrb    w0, [x19, #CrowdAgent.lod_level]
    cmp     w0, #3                      // LOD_CULLED
    b.eq    agent_update_culled
    
    // Get current position
    ldr     w21, [x19, #CrowdAgent.position_x]
    ldr     w22, [x19, #CrowdAgent.position_y]
    
    // Update flow field cell
    lsr     w0, w21, #6                 // position_x / 64
    lsr     w1, w22, #6                 // position_y / 64
    strh    w0, [x19, #CrowdAgent.flow_cell_x]
    strh    w1, [x19, #CrowdAgent.flow_cell_y]
    
    // Get desired velocity from flow field
    mov     x0, x21                     // position_x
    mov     x1, x22                     // position_y
    bl      flow_field_get_direction
    
    // Scale flow field direction to desired velocity
    mov     w2, #CROWD_MAX_VELOCITY
    mul     w0, w0, w2                  // desired_velocity_x
    mul     w1, w1, w2                  // desired_velocity_y
    strh    w0, [x19, #CrowdAgent.desired_velocity_x]
    strh    w1, [x19, #CrowdAgent.desired_velocity_y]
    
    // Calculate separation forces from nearby agents
    mov     x0, x19                     // agent_ptr
    bl      crowd_calculate_separation_force
    
    // Integrate forces to update velocity (simplified physics)
    bl      crowd_integrate_forces
    
    // Update position based on velocity
    bl      crowd_update_position
    
    // Update density grid
    bl      crowd_update_agent_density

agent_update_culled:
    // Mark agent as updated this frame
    bl      get_current_frame_number
    str     w0, [x19, #CrowdAgent.last_update_frame]
    
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//
// crowd_calculate_separation_force - Calculate separation from nearby agents
//
// Parameters:
//   x0 = agent_ptr
//
crowd_calculate_separation_force:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // agent_ptr
    
    // Get agent position
    ldr     w20, [x19, #CrowdAgent.position_x]
    ldr     w21, [x19, #CrowdAgent.position_y]
    
    // Initialize separation force
    mov     w22, #0                     // separation_x
    mov     w23, #0                     // separation_y
    
    // Find nearby agents using spatial hash
    mov     x0, x20                     // position_x
    mov     x1, x21                     // position_y
    mov     x2, #CROWD_AVOIDANCE_RADIUS
    bl      find_nearby_agents
    
    // For each nearby agent, calculate separation force
    // (Implementation would iterate through nearby agents)
    // Simplified: just store zero separation for now
    strh    w22, [x19, #CrowdAgent.separation_force_x]
    strh    w23, [x19, #CrowdAgent.separation_force_y]
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// crowd_integrate_forces - Integrate forces to update velocity
//
crowd_integrate_forces:
    // Get current velocity
    ldrsh   w0, [x19, #CrowdAgent.velocity_x]
    ldrsh   w1, [x19, #CrowdAgent.velocity_y]
    
    // Get desired velocity from flow field
    ldrsh   w2, [x19, #CrowdAgent.desired_velocity_x]
    ldrsh   w3, [x19, #CrowdAgent.desired_velocity_y]
    
    // Get separation force
    ldrsh   w4, [x19, #CrowdAgent.separation_force_x]
    ldrsh   w5, [x19, #CrowdAgent.separation_force_y]
    
    // Simple steering behavior: blend flow field and separation
    // velocity = velocity + (desired - velocity) * flow_weight + separation * sep_weight
    sub     w6, w2, w0                  // desired_x - velocity_x
    sub     w7, w3, w1                  // desired_y - velocity_y
    
    // Apply flow field influence (70%)
    mov     w8, #CROWD_FLOW_WEIGHT
    mul     w6, w6, w8
    mul     w7, w7, w8
    asr     w6, w6, #7                  // /128 (approximate /100)
    asr     w7, w7, #7
    
    // Apply separation force influence (80%)
    mov     w8, #CROWD_SEPARATION_WEIGHT
    mul     w4, w4, w8
    mul     w5, w5, w8
    asr     w4, w4, #7                  // /128
    asr     w5, w5, #7
    
    // Update velocity
    add     w0, w0, w6                  // + flow_influence_x
    add     w1, w1, w7                  // + flow_influence_y
    add     w0, w0, w4                  // + separation_x
    add     w1, w1, w5                  // + separation_y
    
    // Clamp velocity to maximum
    mov     w2, #CROWD_MAX_VELOCITY
    neg     w3, w2                      // -CROWD_MAX_VELOCITY
    
    cmp     w0, w2
    csel    w0, w0, w2, le
    cmp     w0, w3
    csel    w0, w0, w3, ge
    
    cmp     w1, w2
    csel    w1, w1, w2, le
    cmp     w1, w3
    csel    w1, w1, w3, ge
    
    // Store updated velocity
    strh    w0, [x19, #CrowdAgent.velocity_x]
    strh    w1, [x19, #CrowdAgent.velocity_y]
    
    ret

//
// crowd_update_position - Update agent position based on velocity
//
crowd_update_position:
    // Get current position and velocity
    ldr     w0, [x19, #CrowdAgent.position_x]
    ldr     w1, [x19, #CrowdAgent.position_y]
    ldrsh   w2, [x19, #CrowdAgent.velocity_x]
    ldrsh   w3, [x19, #CrowdAgent.velocity_y]
    
    // Update position: position += velocity * delta_time / 1000
    mul     w2, w2, w20                 // velocity_x * delta_time_ms
    mul     w3, w3, w20                 // velocity_y * delta_time_ms
    
    // Convert from ms to seconds (divide by 1000)
    mov     w4, #1000
    sdiv    w2, w2, w4
    sdiv    w3, w3, w4
    
    add     w0, w0, w2                  // new_position_x
    add     w1, w1, w3                  // new_position_y
    
    // Clamp to world bounds
    cmp     w0, #0
    csel    w0, w0, #0, ge
    cmp     w0, #4096
    csel    w0, w0, #4095, le
    
    cmp     w1, #0
    csel    w1, w1, #0, ge
    cmp     w1, #4096
    csel    w1, w1, #4095, le
    
    // Store updated position
    str     w0, [x19, #CrowdAgent.position_x]
    str     w1, [x19, #CrowdAgent.position_y]
    
    ret

// ============================================================================
// LOD AND PERFORMANCE OPTIMIZATION
// ============================================================================

//
// crowd_update_lod_levels - Update LOD levels for all agents based on camera distance
//
crowd_update_lod_levels:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Get crowd simulation data
    adrp    x19, crowd_simulation
    add     x19, x19, :lo12:crowd_simulation
    ldr     w20, [x19, #CrowdSimulation.camera_x]
    ldr     w21, [x19, #CrowdSimulation.camera_y]
    
    // Clear LOD distribution counters
    add     x0, x19, #CrowdSimulation.lod_distribution
    str     xzr, [x0]
    str     xzr, [x0, #8]
    
    // Get agent array
    ldr     x22, [x19, #CrowdSimulation.crowd_agents]
    
    mov     x23, #0                     // agent_index
    
lod_update_loop:
    cmp     x23, #MAX_AGENTS
    b.ge    lod_update_done
    
    // Calculate agent address
    mov     x0, #CrowdAgent_size
    mul     x1, x23, x0
    add     x24, x22, x1                // agent_ptr
    
    // Check if agent is active
    ldr     w0, [x24, #CrowdAgent.agent_id]
    cmp     w0, #-1
    b.eq    lod_next_agent
    
    // Calculate distance to camera
    ldr     w0, [x24, #CrowdAgent.position_x]
    ldr     w1, [x24, #CrowdAgent.position_y]
    sub     w0, w0, w20                 // dx
    sub     w1, w1, w21                 // dy
    
    // Calculate Manhattan distance (simplified)
    cmp     w0, #0
    cneg    w0, w0, lt                  // abs(dx)
    cmp     w1, #0
    cneg    w1, w1, lt                  // abs(dy)
    add     w2, w0, w1                  // distance
    
    // Determine LOD level
    mov     w3, #0                      // LOD_NEAR
    cmp     w2, #CROWD_LOD_NEAR_DISTANCE
    b.le    lod_set_level
    
    mov     w3, #1                      // LOD_MEDIUM
    cmp     w2, #CROWD_LOD_MEDIUM_DISTANCE
    b.le    lod_set_level
    
    mov     w3, #2                      // LOD_FAR
    cmp     w2, #CROWD_LOD_FAR_DISTANCE
    b.le    lod_set_level
    
    mov     w3, #3                      // LOD_CULLED

lod_set_level:
    strb    w3, [x24, #CrowdAgent.lod_level]
    
    // Update LOD distribution counter
    add     x0, x19, #CrowdSimulation.lod_distribution
    lsl     x1, x3, #2                  // lod_level * 4
    add     x0, x0, x1
    ldr     w1, [x0]
    add     w1, w1, #1
    str     w1, [x0]

lod_next_agent:
    add     x23, x23, #1
    b       lod_update_loop

lod_update_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ============================================================================
// UTILITY FUNCTIONS AND STUBS
// ============================================================================

// Helper function stubs (would be implemented in full system)
calculate_agent_lod:
    mov     w1, #0                      // Default to near LOD
    ret

get_current_frame_number:
    mov     w0, #0                      // Stub frame number
    ret

crowd_update_agent_density:
    ret

crowd_update_density_stats:
    ret

crowd_process_collisions:
    ret

find_nearby_agents:
    ret

crowd_agent_remove:
    mov     x0, #0
    ret

crowd_agent_get_position:
    mov     x0, #0
    ret

crowd_get_density_at:
    mov     x0, #0
    ret

crowd_get_performance_stats:
    ret

crowd_simulation_shutdown:
    mov     x0, #0
    ret