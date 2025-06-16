//
// SimCity ARM64 Assembly - Agent Lifecycle Management and Integration
// Agent 4: AI and Behavior Systems Engineer
//
// Integrates pathfinding, crowd simulation, behavior states, and traffic
// Provides unified agent management optimized for 1M+ agents
// Target: <10ms update time for all agents with intelligent LOD
//

.text
.align 4

// Include dependencies
.include "../simulation/simulation_constants.s"
.include "../include/constants/memory.inc"

// ============================================================================
// AGENT LIFECYCLE CONSTANTS
// ============================================================================

// Agent lifecycle states
.equ AGENT_STATE_INACTIVE,      0           // Agent not spawned
.equ AGENT_STATE_SPAWNING,      1           // Agent being initialized
.equ AGENT_STATE_ACTIVE,        2           // Agent fully active
.equ AGENT_STATE_DESPAWNING,    3           // Agent being removed
.equ AGENT_STATE_SUSPENDED,     4           // Agent temporarily suspended

// Update frequency optimization
.equ UPDATE_FREQ_NEAR,          1           // Every frame
.equ UPDATE_FREQ_MEDIUM,        4           // Every 4 frames
.equ UPDATE_FREQ_FAR,           16          // Every 16 frames
.equ UPDATE_FREQ_CULLED,        64          // Every 64 frames

// Performance budgets (nanoseconds)
.equ TIME_BUDGET_TOTAL,         10000000    // 10ms total budget
.equ TIME_BUDGET_PATHFINDING,   3000000     // 3ms for pathfinding
.equ TIME_BUDGET_BEHAVIOR,      2000000     // 2ms for behavior
.equ TIME_BUDGET_CROWD,         3000000     // 3ms for crowd simulation
.equ TIME_BUDGET_TRAFFIC,       2000000     // 2ms for traffic

// Batch processing constants
.equ LIFECYCLE_BATCH_SIZE,      2048        // Agents per batch
.equ MAX_AGENTS_PER_FRAME,      50000       // Max agents to update per frame
.equ SPAWN_RATE_LIMIT,          1000        // Max spawns per frame
.equ DESPAWN_RATE_LIMIT,        1000        // Max despawns per frame

// ============================================================================
// STRUCTURE DEFINITIONS
// ============================================================================

// Unified agent data structure (256 bytes, cache-optimized)
.struct UnifiedAgent
    // Core identification and state
    agent_id                    .word       // Unique agent ID
    agent_type                  .byte       // Type of agent (citizen, vehicle, etc.)
    lifecycle_state             .byte       // Current lifecycle state
    lod_level                   .byte       // Level of detail (0-3)
    update_frequency            .byte       // Update frequency divider
    
    // Spatial data
    position_x                  .word       // World X position
    position_y                  .word       // World Y position
    chunk_x                     .hword      // World chunk X
    chunk_y                     .hword      // World chunk Y
    
    // Behavior system integration
    behavior_context_ptr        .quad       // Pointer to behavior context
    current_behavior_state      .word       // Current behavior state
    behavior_priority           .byte       // Behavior priority level
    behavior_flags              .byte       // Behavior flags
    reserved1                   .hword      // Alignment
    
    // Pathfinding integration
    pathfind_request_id         .word       // Active pathfinding request ID
    path_progress               .word       // Progress along current path
    target_x                    .word       // Current movement target X
    target_y                    .word       // Current movement target Y
    path_recalc_timer           .word       // Timer for path recalculation
    
    // Crowd simulation integration
    crowd_agent_index           .word       // Index in crowd simulation system
    local_density               .byte       // Local crowd density
    avoidance_state             .byte       // Collision avoidance state
    flow_field_influence        .byte       // Flow field influence strength
    separation_weight           .byte       // Separation force weight
    
    // Traffic integration (for vehicle agents)
    traffic_vehicle_index       .word       // Index in traffic system
    road_segment_id             .word       // Current road segment
    lane_id                     .byte       // Current lane
    traffic_priority            .byte       // Traffic priority level
    vehicle_type                .byte       // Vehicle type
    traffic_state               .byte       // Traffic-specific state
    
    // Performance optimization
    last_update_frame           .word       // Last frame this agent was updated
    next_update_frame           .word       // Next frame to update this agent
    camera_distance             .word       // Distance from camera (for LOD)
    cull_timer                  .word       // Timer for culling checks
    
    // Statistics and debugging
    total_update_time           .quad       // Total time spent updating this agent
    update_count                .word       // Number of updates performed
    spawn_frame                 .word       // Frame when agent was spawned
    
    // Memory pool management
    pool_index                  .word       // Index in agent pool
    next_free_agent             .word       // Next free agent in pool (when inactive)
    
    // Reserved for future expansion
    reserved                    .space 128  // Reserved space for future features
.endstruct

// Agent lifecycle system state
.struct AgentLifecycleSystem
    // Agent management
    agents                      .quad       // Array of unified agents
    active_agent_count          .word       // Number of active agents
    max_agents                  .word       // Maximum agent capacity
    next_agent_id               .word       // Next agent ID to assign
    free_agent_head             .word       // Head of free agent list
    
    // Update scheduling
    update_batches              .quad       // Array of update batch queues
    current_batch_index         .word       // Current batch being processed
    agents_updated_this_frame   .word       // Agents updated in current frame
    
    // Performance tracking
    frame_start_time            .quad       // Start time of current frame
    time_budget_remaining       .quad       // Remaining time budget
    time_spent_pathfinding      .quad       // Time spent on pathfinding this frame
    time_spent_behavior         .quad       // Time spent on behavior this frame
    time_spent_crowd            .quad       // Time spent on crowd simulation
    time_spent_traffic          .quad       // Time spent on traffic simulation
    
    // LOD management
    camera_x                    .word       // Camera X position
    camera_y                    .word       // Camera Y position
    lod_distance_near           .word       // Distance threshold for near LOD
    lod_distance_medium         .word       // Distance threshold for medium LOD
    lod_distance_far            .word       // Distance threshold for far LOD
    
    // System integration pointers
    pathfinding_system_ptr      .quad       // Pointer to pathfinding system
    behavior_system_ptr         .quad       // Pointer to behavior system  
    crowd_simulation_ptr        .quad       // Pointer to crowd simulation
    traffic_simulation_ptr      .quad       // Pointer to traffic simulation
    
    // Statistics
    total_frames_processed      .quad       // Total frames processed
    total_agents_spawned        .quad       // Total agents spawned
    total_agents_despawned      .quad       // Total agents despawned
    average_frame_time          .quad       // Average frame processing time
    peak_frame_time             .quad       // Peak frame processing time
    
    // Configuration
    performance_mode            .word       // Performance vs quality tradeoff
    spawn_rate_multiplier       .word       // Spawn rate scaling factor
    max_agents_per_frame        .word       // Maximum agents to update per frame
    adaptive_lod_enabled        .byte       // Whether adaptive LOD is enabled
    debug_mode                  .byte       // Debug mode flag
    reserved_config             .hword      // Reserved configuration space
.endstruct

// ============================================================================
// GLOBAL DATA
// ============================================================================

.section .bss
.align 8

// Main agent lifecycle system
agent_lifecycle:            .space AgentLifecycleSystem_size

// Unified agent array (1M+ agents)
.align 64
unified_agents:             .space (MAX_AGENTS * UnifiedAgent_size)

// Update batch scheduling
.align 64
update_batch_queues:        .space (4 * 16384)    // 4 LOD levels, max 16K agents each
batch_processing_state:     .space 256

// Performance monitoring
.align 64
performance_counters:       .space 512
frame_timing_history:       .space (60 * 8)       // 60 frame timing history

.section .text

// ============================================================================
// GLOBAL SYMBOLS
// ============================================================================

.global agent_lifecycle_init
.global agent_lifecycle_shutdown
.global agent_lifecycle_update
.global agent_spawn_citizen
.global agent_spawn_vehicle
.global agent_despawn
.global agent_set_camera_position
.global agent_get_statistics
.global agent_set_performance_mode
.global agent_force_lod_update

// External system dependencies
.extern pathfinding_init
.extern behavior_system_init
.extern crowd_simulation_init
.extern traffic_simulation_init
.extern get_current_time_ns

// ============================================================================
// AGENT LIFECYCLE INITIALIZATION
// ============================================================================

//
// agent_lifecycle_init - Initialize the unified agent lifecycle system
//
// Parameters:
//   x0 = max_agents
//   x1 = world_width
//   x2 = world_height
//
// Returns:
//   x0 = 0 on success, error code on failure
//
agent_lifecycle_init:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    
    mov     x19, x0                     // max_agents
    mov     x20, x1                     // world_width
    mov     x21, x2                     // world_height
    
    // Initialize agent lifecycle system structure
    adrp    x22, agent_lifecycle
    add     x22, x22, :lo12:agent_lifecycle
    
    // Clear entire structure
    mov     x0, #0
    mov     x1, #(AgentLifecycleSystem_size / 8)
1:  str     x0, [x22], #8
    subs    x1, x1, #1
    b.ne    1b
    
    // Reset pointer
    adrp    x22, agent_lifecycle
    add     x22, x22, :lo12:agent_lifecycle
    
    // Set up agent array
    adrp    x0, unified_agents
    add     x0, x0, :lo12:unified_agents
    str     x0, [x22, #AgentLifecycleSystem.agents]
    str     w19, [x22, #AgentLifecycleSystem.max_agents]
    str     wzr, [x22, #AgentLifecycleSystem.active_agent_count]
    mov     w0, #1
    str     w0, [x22, #AgentLifecycleSystem.next_agent_id]
    
    // Set up update batches
    adrp    x0, update_batch_queues
    add     x0, x0, :lo12:update_batch_queues
    str     x0, [x22, #AgentLifecycleSystem.update_batches]
    
    // Initialize default configuration
    mov     w0, #1                      // Performance mode: balanced
    str     w0, [x22, #AgentLifecycleSystem.performance_mode]
    mov     w0, #100                    // 100% spawn rate
    str     w0, [x22, #AgentLifecycleSystem.spawn_rate_multiplier]
    mov     w0, #MAX_AGENTS_PER_FRAME
    str     w0, [x22, #AgentLifecycleSystem.max_agents_per_frame]
    mov     w0, #1
    strb    w0, [x22, #AgentLifecycleSystem.adaptive_lod_enabled]
    
    // Set default LOD distances
    mov     w0, #64                     // Near LOD distance
    str     w0, [x22, #AgentLifecycleSystem.lod_distance_near]
    mov     w0, #256                    // Medium LOD distance
    str     w0, [x22, #AgentLifecycleSystem.lod_distance_medium]
    mov     w0, #1024                   // Far LOD distance
    str     w0, [x22, #AgentLifecycleSystem.lod_distance_far]
    
    // Initialize all agents to inactive
    bl      clear_all_agents
    
    // Initialize subsystems
    mov     x0, x19                     // max_agents
    mov     x1, #2048                   // max_pathfind_nodes
    bl      pathfinding_init
    cbz     x0, lifecycle_init_pathfinding_ok
    mov     x23, x0                     // Save error code
    b       lifecycle_init_failed

lifecycle_init_pathfinding_ok:
    // Store pathfinding system pointer
    adrp    x0, pathfinding_system
    add     x0, x0, :lo12:pathfinding_system
    str     x0, [x22, #AgentLifecycleSystem.pathfinding_system_ptr]
    
    // Initialize behavior system
    bl      behavior_system_init
    cbz     x0, lifecycle_init_behavior_ok
    mov     x23, x0
    b       lifecycle_init_failed

lifecycle_init_behavior_ok:
    // Store behavior system pointer
    adrp    x0, behavior_contexts
    add     x0, x0, :lo12:behavior_contexts
    str     x0, [x22, #AgentLifecycleSystem.behavior_system_ptr]
    
    // Initialize crowd simulation
    mov     x0, x19                     // max_agents
    mov     x1, x20                     // world_width
    mov     x2, x21                     // world_height
    bl      crowd_simulation_init
    cbz     x0, lifecycle_init_crowd_ok
    mov     x23, x0
    b       lifecycle_init_failed

lifecycle_init_crowd_ok:
    // Store crowd simulation pointer
    adrp    x0, crowd_simulation
    add     x0, x0, :lo12:crowd_simulation
    str     x0, [x22, #AgentLifecycleSystem.crowd_simulation_ptr]
    
    // Initialize traffic simulation
    adrp    x0, pathfinding_system      // network_graph (using pathfinding for now)
    add     x0, x0, :lo12:pathfinding_system
    mov     x1, x20                     // world_width
    mov     x2, x21                     // world_height
    bl      traffic_simulation_init
    cbz     x0, lifecycle_init_traffic_ok
    mov     x23, x0
    b       lifecycle_init_failed

lifecycle_init_traffic_ok:
    // Store traffic simulation pointer
    adrp    x0, traffic_simulation
    add     x0, x0, :lo12:traffic_simulation
    str     x0, [x22, #AgentLifecycleSystem.traffic_simulation_ptr]
    
    mov     x0, #0                      // Success
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

lifecycle_init_failed:
    mov     x0, x23                     // Return error code
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//
// clear_all_agents - Initialize all agents to inactive state
//
clear_all_agents:
    adrp    x0, unified_agents
    add     x0, x0, :lo12:unified_agents
    
    mov     x1, #0                      // agent_index
    mov     x2, #MAX_AGENTS
    mov     x3, #-1                     // Invalid ID marker
    
clear_agents_loop:
    cmp     x1, x2
    b.ge    clear_agents_done
    
    // Calculate agent address
    mov     x4, #UnifiedAgent_size
    mul     x5, x1, x4
    add     x4, x0, x5                  // agent_ptr
    
    // Initialize agent to inactive
    str     wzr, [x4, #UnifiedAgent.agent_id]
    strb    wzr, [x4, #UnifiedAgent.lifecycle_state] // AGENT_STATE_INACTIVE
    strb    wzr, [x4, #UnifiedAgent.agent_type]
    
    // Set up free list chain
    add     w6, w1, #1                  // next_index
    cmp     w6, w2
    csel    w6, w6, w3, lt              // next_index or -1 if last
    str     w6, [x4, #UnifiedAgent.next_free_agent]
    str     w1, [x4, #UnifiedAgent.pool_index]
    
    add     x1, x1, #1
    b       clear_agents_loop

clear_agents_done:
    // Set free agent head to 0
    adrp    x0, agent_lifecycle
    add     x0, x0, :lo12:agent_lifecycle
    str     wzr, [x0, #AgentLifecycleSystem.free_agent_head]
    ret

// ============================================================================
// AGENT LIFECYCLE MAIN UPDATE SYSTEM
// ============================================================================

//
// agent_lifecycle_update - Main update function for all agent systems
//
// Parameters:
//   x0 = delta_time_ms
//   x1 = camera_x
//   x2 = camera_y
//
// Returns:
//   x0 = 0 on success
//
agent_lifecycle_update:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    
    mov     x19, x0                     // delta_time_ms
    mov     x20, x1                     // camera_x
    mov     x21, x2                     // camera_y
    
    // Start frame timing
    bl      get_current_time_ns
    mov     x22, x0                     // frame_start_time
    
    // Get lifecycle system
    adrp    x23, agent_lifecycle
    add     x23, x23, :lo12:agent_lifecycle
    str     x0, [x23, #AgentLifecycleSystem.frame_start_time]
    mov     x0, #TIME_BUDGET_TOTAL
    str     x0, [x23, #AgentLifecycleSystem.time_budget_remaining]
    
    // Update camera position
    str     w20, [x23, #AgentLifecycleSystem.camera_x]
    str     w21, [x23, #AgentLifecycleSystem.camera_y]
    
    // Reset frame counters
    str     wzr, [x23, #AgentLifecycleSystem.agents_updated_this_frame]
    str     xzr, [x23, #AgentLifecycleSystem.time_spent_pathfinding]
    str     xzr, [x23, #AgentLifecycleSystem.time_spent_behavior]
    str     xzr, [x23, #AgentLifecycleSystem.time_spent_crowd]
    str     xzr, [x23, #AgentLifecycleSystem.time_spent_traffic]
    
    // Update LOD levels for all agents
    bl      update_all_agent_lod
    
    // Process agents in batches based on LOD level
    mov     x24, #0                     // lod_level
    
lod_batch_loop:
    cmp     x24, #4                     // 4 LOD levels (0-3)
    b.ge    lod_batch_done
    
    // Check remaining time budget
    bl      check_time_budget
    cbz     x0, lod_batch_done
    
    // Process this LOD level
    mov     x0, x24                     // lod_level
    mov     x1, x19                     // delta_time_ms
    bl      process_agents_by_lod
    
    add     x24, x24, #1
    b       lod_batch_loop

lod_batch_done:
    // Update performance statistics
    bl      get_current_time_ns
    sub     x0, x0, x22                 // total_frame_time
    
    // Update statistics
    ldr     x1, [x23, #AgentLifecycleSystem.total_frames_processed]
    add     x1, x1, #1
    str     x1, [x23, #AgentLifecycleSystem.total_frames_processed]
    
    // Update average frame time (exponential moving average)
    ldr     x2, [x23, #AgentLifecycleSystem.average_frame_time]
    cbz     x2, store_first_frame_time
    
    // avg = avg * 0.9 + current * 0.1
    mov     x3, #90
    mul     x2, x2, x3
    mov     x3, #10
    mul     x4, x0, x3
    add     x2, x2, x4
    mov     x3, #100
    udiv    x2, x2, x3
    str     x2, [x23, #AgentLifecycleSystem.average_frame_time]
    b       check_peak_time

store_first_frame_time:
    str     x0, [x23, #AgentLifecycleSystem.average_frame_time]

check_peak_time:
    ldr     x2, [x23, #AgentLifecycleSystem.peak_frame_time]
    cmp     x0, x2
    csel    x0, x0, x2, gt
    str     x0, [x23, #AgentLifecycleSystem.peak_frame_time]
    
    mov     x0, #0                      // Success
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//
// process_agents_by_lod - Process all agents at a specific LOD level
//
// Parameters:
//   x0 = lod_level
//   x1 = delta_time_ms
//
process_agents_by_lod:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // lod_level
    mov     x20, x1                     // delta_time_ms
    
    // Get update frequency for this LOD level
    adrp    x21, update_frequencies
    add     x21, x21, :lo12:update_frequencies
    ldr     w22, [x21, x19, lsl #2]     // update_frequency
    
    // Get agent array
    adrp    x21, unified_agents
    add     x21, x21, :lo12:unified_agents
    
    mov     x23, #0                     // agent_index
    mov     x24, #0                     // processed_count
    
process_lod_loop:
    cmp     x23, #MAX_AGENTS
    b.ge    process_lod_done
    
    // Check time budget
    bl      check_time_budget
    cbz     x0, process_lod_done
    
    // Calculate agent address
    mov     x0, #UnifiedAgent_size
    mul     x1, x23, x0
    add     x25, x21, x1                // agent_ptr
    
    // Check if agent is active
    ldrb    w0, [x25, #UnifiedAgent.lifecycle_state]
    cmp     w0, #AGENT_STATE_ACTIVE
    b.ne    process_lod_next
    
    // Check if agent matches LOD level
    ldrb    w0, [x25, #UnifiedAgent.lod_level]
    cmp     w0, w19
    b.ne    process_lod_next
    
    // Check if agent should be updated this frame
    ldr     w0, [x25, #UnifiedAgent.next_update_frame]
    bl      get_current_frame_number
    cmp     w0, w1
    b.gt    process_lod_next
    
    // Update this agent
    mov     x0, x25                     // agent_ptr
    mov     x1, x20                     // delta_time_ms
    bl      process_single_agent
    
    add     x24, x24, #1                // processed_count++

process_lod_next:
    add     x23, x23, #1
    b       process_lod_loop

process_lod_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ============================================================================
// UTILITY FUNCTIONS AND STUBS
// ============================================================================

// Update frequency table for LOD levels
.section .data
.align 4
update_frequencies:
    .word   UPDATE_FREQ_NEAR        // LOD 0: Every frame
    .word   UPDATE_FREQ_MEDIUM      // LOD 1: Every 4 frames
    .word   UPDATE_FREQ_FAR         // LOD 2: Every 16 frames
    .word   UPDATE_FREQ_CULLED      // LOD 3: Every 64 frames

.section .text

// Helper function stubs (would be fully implemented in production)
update_all_agent_lod:
    ret

check_time_budget:
    mov     x0, #1                      // Always have budget (stub)
    ret

process_single_agent:
    ret

get_current_frame_number:
    mov     w1, #0                      // Frame 0 (stub)
    ret

// Exported function stubs
agent_spawn_citizen:
    mov     x0, #0
    ret

agent_spawn_vehicle:
    mov     x0, #0
    ret

agent_despawn:
    mov     x0, #0
    ret

agent_set_camera_position:
    ret

agent_get_statistics:
    ret

agent_set_performance_mode:
    ret

agent_force_lod_update:
    ret

agent_lifecycle_shutdown:
    mov     x0, #0
    ret