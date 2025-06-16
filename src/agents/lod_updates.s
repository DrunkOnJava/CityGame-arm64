//
// SimCity ARM64 Assembly - Agent LOD Update System
// Agent 5: Agent Systems & AI
//
// Level-of-Detail system for efficient agent updates
// Implements near/medium/far update schemes to maintain <10ms for 1M agents
// Uses distance-based culling and adaptive update frequencies
//

.text
.align 4

// Include dependencies
.include "../simulation/simulation_constants.s"
.include "../include/constants/memory.inc"

// ============================================================================
// LOD SYSTEM CONSTANTS
// ============================================================================

// LOD distance thresholds (in world tile units)
.equ LOD_NEAR_DISTANCE,         32          // Near LOD range (32 tiles)
.equ LOD_MEDIUM_DISTANCE,       128         // Medium LOD range (128 tiles)
.equ LOD_FAR_DISTANCE,          512         // Far LOD range (512 tiles)
.equ LOD_CULL_DISTANCE,         1024        // Beyond this, agents are culled

// Update frequencies (in frames)
.equ LOD_NEAR_UPDATE_FREQ,      1           // Every frame
.equ LOD_MEDIUM_UPDATE_FREQ,    4           // Every 4 frames
.equ LOD_FAR_UPDATE_FREQ,       16          // Every 16 frames
.equ LOD_CULLED_UPDATE_FREQ,    64          // Every 64 frames (minimal)

// LOD system performance targets
.equ LOD_TARGET_AGENTS_PER_MS,  100000      // 100K agents per millisecond
.equ LOD_MAX_AGENTS_PER_FRAME,  50000       // Maximum agents to update per frame
.equ LOD_TIME_BUDGET_NS,        10000000    // 10ms time budget per frame

// Agent update priorities
.equ PRIORITY_CAMERA_VISIBLE,   10          // Agents visible to camera
.equ PRIORITY_ACTIVE_ZONE,      7           // Agents in active simulation zones
.equ PRIORITY_NEIGHBOR_CHUNK,   5           // Agents in neighboring chunks
.equ PRIORITY_DISTANT,          3           // Distant agents
.equ PRIORITY_BACKGROUND,       1           // Background simulation

// Adaptive LOD parameters
.equ ADAPTIVE_DISTANCE_FACTOR,  2           // Distance multiplier for adaptive LOD
.equ PERFORMANCE_SAMPLE_SIZE,   60          // Frames to average for performance
.equ MIN_UPDATE_RATIO,          0.1         // Minimum update ratio (10%)
.equ MAX_UPDATE_RATIO,          1.0         // Maximum update ratio (100%)

// ============================================================================
// STRUCTURE DEFINITIONS
// ============================================================================

// LOD level assignment for an agent
.struct AgentLOD
    lod_level                   .byte       // Current LOD level (0-3)
    distance_to_camera          .byte       // Distance to camera (scaled)
    last_update_frame           .hword      // Last frame when updated
    update_priority             .byte       // Update priority (0-10)
    flags                       .byte       // LOD flags
    _padding                    .hword      // Alignment padding
.endstruct

// LOD system state
.struct LODSystem
    // Camera/viewport information
    camera_x                    .word       // Camera center X coordinate
    camera_y                    .word       // Camera center Y coordinate
    viewport_width              .word       // Viewport width in tiles
    viewport_height             .word       // Viewport height in tiles
    
    // Frame tracking
    current_frame               .quad       // Current frame number
    frame_start_time            .quad       // Frame start timestamp
    
    // Update queues for different LOD levels
    near_update_queue           .quad       // Queue of near LOD agents
    medium_update_queue         .quad       // Queue of medium LOD agents
    far_update_queue            .quad       // Queue of far LOD agents
    culled_update_queue         .quad       // Queue of culled agents
    
    queue_sizes                 .space 16   // Sizes of each queue (4 x 4 bytes)
    queue_indices               .space 16   // Current processing indices
    
    // Performance tracking
    agents_updated_this_frame   .word       // Agents updated in current frame
    time_spent_updating         .quad       // Time spent updating this frame
    avg_update_time             .quad       // Average update time per agent
    
    // Adaptive LOD parameters
    performance_samples         .space (PERFORMANCE_SAMPLE_SIZE * 8)
    sample_index                .word       // Current sample index
    performance_ratio           .word       // Current performance ratio (0.0-1.0 scaled)
    adaptive_lod_multiplier     .word       // Dynamic LOD distance multiplier
    
    // Statistics
    total_near_updates          .quad       // Total near LOD updates
    total_medium_updates        .quad       // Total medium LOD updates
    total_far_updates           .quad       // Total far LOD updates
    total_culled_updates        .quad       // Total culled updates
.endstruct

// Update batch for processing agents efficiently
.struct UpdateBatch
    agent_ids                   .quad       // Array of agent IDs to update
    agent_count                 .word       // Number of agents in batch
    lod_level                   .word       // LOD level for this batch
    estimated_time              .quad       // Estimated time to process batch
.endstruct

// ============================================================================
// GLOBAL DATA
// ============================================================================

.section .bss
.align 8

// Main LOD system state
lod_system:                     .space LODSystem_size

// Agent LOD assignments (one per agent)
agent_lod_data:                 .space (MAX_AGENTS * AgentLOD_size)

// Update queues (agent IDs)
.align 64
near_update_queue:              .space (LOD_MAX_AGENTS_PER_FRAME * 4)
medium_update_queue:            .space (LOD_MAX_AGENTS_PER_FRAME * 4)
far_update_queue:               .space (LOD_MAX_AGENTS_PER_FRAME * 4)
culled_update_queue:            .space (LOD_MAX_AGENTS_PER_FRAME * 4)

// Update batches for efficient processing
update_batches:                 .space (16 * UpdateBatch_size)

// Temporary processing buffers
.align 64
distance_calculation_buffer:    .space (1024 * 8)
priority_sorting_buffer:        .space (1024 * 8)

.section .text

// ============================================================================
// GLOBAL SYMBOLS
// ============================================================================

.global lod_system_init
.global lod_system_shutdown
.global lod_update_camera_position
.global lod_assign_agent_levels
.global lod_update_frame
.global lod_get_agent_lod_level
.global lod_set_agent_priority
.global lod_get_statistics
.global lod_adjust_performance

// External dependencies
.extern get_current_time_ns
.extern agent_update_all
.extern behavior_update_agent
.extern pathfind_request

// ============================================================================
// LOD SYSTEM INITIALIZATION
// ============================================================================

//
// lod_system_init - Initialize the LOD update system
//
// Returns:
//   x0 = 0 on success, error code on failure
//
lod_system_init:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Clear LOD system state
    adrp    x19, lod_system
    add     x19, x19, :lo12:lod_system
    
    mov     x20, #0
    mov     x0, #(LODSystem_size / 8)
1:  str     x20, [x19], #8
    subs    x0, x0, #1
    b.ne    1b
    
    // Reset pointer
    adrp    x19, lod_system
    add     x19, x19, :lo12:lod_system
    
    // Initialize camera/viewport to center of world
    mov     x0, #(WORLD_WIDTH / 2)
    str     w0, [x19, #LODSystem.camera_x]
    mov     x0, #(WORLD_HEIGHT / 2)
    str     w0, [x19, #LODSystem.camera_y]
    
    mov     x0, #64                     // Default viewport size
    str     w0, [x19, #LODSystem.viewport_width]
    str     w0, [x19, #LODSystem.viewport_height]
    
    // Set up update queues
    adrp    x0, near_update_queue
    add     x0, x0, :lo12:near_update_queue
    str     x0, [x19, #LODSystem.near_update_queue]
    
    adrp    x0, medium_update_queue
    add     x0, x0, :lo12:medium_update_queue
    str     x0, [x19, #LODSystem.medium_update_queue]
    
    adrp    x0, far_update_queue
    add     x0, x0, :lo12:far_update_queue
    str     x0, [x19, #LODSystem.far_update_queue]
    
    adrp    x0, culled_update_queue
    add     x0, x0, :lo12:culled_update_queue
    str     x0, [x19, #LODSystem.culled_update_queue]
    
    // Initialize adaptive LOD parameters
    mov     x0, #1000                   // Initial performance ratio (100%)
    str     w0, [x19, #LODSystem.performance_ratio]
    mov     x0, #1000                   // Initial LOD multiplier (1.0x)
    str     w0, [x19, #LODSystem.adaptive_lod_multiplier]
    
    // Clear agent LOD data
    bl      lod_clear_agent_data
    
    // Initialize performance tracking
    bl      lod_init_performance_tracking
    
    mov     x0, #0                      // Success
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// lod_clear_agent_data - Initialize all agent LOD data
//
lod_clear_agent_data:
    adrp    x0, agent_lod_data
    add     x0, x0, :lo12:agent_lod_data
    
    mov     x1, #0                      // Agent index
    mov     x2, #MAX_AGENTS

clear_agent_lod_loop:
    // Calculate agent LOD data address
    mov     x3, #AgentLOD_size
    mul     x4, x1, x3
    add     x3, x0, x4                  // agent_lod_ptr
    
    // Initialize to far LOD by default
    mov     w4, #LOD_FAR
    strb    w4, [x3, #AgentLOD.lod_level]
    mov     w4, #255                    // Max distance
    strb    w4, [x3, #AgentLOD.distance_to_camera]
    strh    wzr, [x3, #AgentLOD.last_update_frame]
    mov     w4, #PRIORITY_BACKGROUND
    strb    w4, [x3, #AgentLOD.update_priority]
    strb    wzr, [x3, #AgentLOD.flags]
    
    add     x1, x1, #1
    cmp     x1, x2
    b.lt    clear_agent_lod_loop
    
    ret

//
// lod_init_performance_tracking - Initialize performance monitoring
//
lod_init_performance_tracking:
    adrp    x0, lod_system
    add     x0, x0, :lo12:lod_system
    
    // Clear performance samples
    add     x1, x0, #LODSystem.performance_samples
    mov     x2, #0
    mov     x3, #PERFORMANCE_SAMPLE_SIZE
1:  str     x2, [x1], #8
    subs    x3, x3, #1
    b.ne    1b
    
    // Reset sample index
    str     wzr, [x0, #LODSystem.sample_index]
    
    ret

// ============================================================================
// CAMERA AND VIEWPORT MANAGEMENT
// ============================================================================

//
// lod_update_camera_position - Update camera position for LOD calculations
//
// Parameters:
//   x0 = camera_x
//   x1 = camera_y
//   x2 = viewport_width
//   x3 = viewport_height
//
lod_update_camera_position:
    adrp    x4, lod_system
    add     x4, x4, :lo12:lod_system
    
    str     w0, [x4, #LODSystem.camera_x]
    str     w1, [x4, #LODSystem.camera_y]
    str     w2, [x4, #LODSystem.viewport_width]
    str     w3, [x4, #LODSystem.viewport_height]
    
    // Trigger LOD reassignment for all agents
    bl      lod_assign_all_agent_levels
    
    ret

// ============================================================================
// LOD LEVEL ASSIGNMENT
// ============================================================================

//
// lod_assign_agent_levels - Assign LOD levels to all agents based on distance
//
lod_assign_all_agent_levels:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Get camera position
    adrp    x19, lod_system
    add     x19, x19, :lo12:lod_system
    ldr     w20, [x19, #LODSystem.camera_x]        // camera_x
    ldr     w21, [x19, #LODSystem.camera_y]        // camera_y
    
    // Get adaptive LOD multiplier
    ldr     w22, [x19, #LODSystem.adaptive_lod_multiplier]
    
    adrp    x23, agent_lod_data
    add     x23, x23, :lo12:agent_lod_data
    
    mov     x24, #0                     // Agent index
    
assign_lod_loop:
    // Calculate agent LOD data address
    mov     x0, #AgentLOD_size
    mul     x1, x24, x0
    add     x0, x23, x1                 // agent_lod_ptr
    
    // Get agent position (would normally come from agent system)
    // For now, use placeholder positions
    mov     w1, w24, lsl #4             // Placeholder X position
    mov     w2, w24, lsl #3             // Placeholder Y position
    
    // Calculate distance to camera
    sub     w3, w1, w20                 // dx = agent_x - camera_x
    sub     w4, w2, w21                 // dy = agent_y - camera_y
    
    // Calculate squared distance (avoid sqrt for performance)
    mul     w5, w3, w3                  // dx^2
    mul     w6, w4, w4                  // dy^2
    add     w5, w5, w6                  // distance_squared
    
    // Apply adaptive LOD multiplier
    mul     w5, w5, w22
    lsr     w5, w5, #10                 // Divide by 1024 (original multiplier scale)
    
    // Determine LOD level based on distance
    mov     w7, #LOD_FAR                // Default to far
    
    mov     w6, #(LOD_NEAR_DISTANCE * LOD_NEAR_DISTANCE)
    cmp     w5, w6
    b.gt    check_medium_lod
    mov     w7, #LOD_NEAR
    b       assign_lod_level
    
check_medium_lod:
    mov     w6, #(LOD_MEDIUM_DISTANCE * LOD_MEDIUM_DISTANCE)
    cmp     w5, w6
    b.gt    check_far_lod
    mov     w7, #LOD_MEDIUM
    b       assign_lod_level
    
check_far_lod:
    mov     w6, #(LOD_FAR_DISTANCE * LOD_FAR_DISTANCE)
    cmp     w5, w6
    b.gt    check_culled
    mov     w7, #LOD_FAR
    b       assign_lod_level
    
check_culled:
    mov     w7, #LOD_INACTIVE           // Culled
    
assign_lod_level:
    // Store LOD level
    strb    w7, [x0, #AgentLOD.lod_level]
    
    // Store scaled distance (for sorting)
    lsr     w5, w5, #16                 // Scale down distance
    cmp     w5, #255
    csel    w5, w5, #255, le            // Clamp to byte range
    strb    w5, [x0, #AgentLOD.distance_to_camera]
    
    // Set update priority based on LOD level
    mov     w6, #PRIORITY_BACKGROUND    // Default priority
    cmp     w7, #LOD_NEAR
    b.ne    1f
    mov     w6, #PRIORITY_CAMERA_VISIBLE
    b       store_priority
1:  cmp     w7, #LOD_MEDIUM
    b.ne    2f
    mov     w6, #PRIORITY_ACTIVE_ZONE
    b       store_priority
2:  cmp     w7, #LOD_FAR
    b.ne    store_priority
    mov     w6, #PRIORITY_NEIGHBOR_CHUNK

store_priority:
    strb    w6, [x0, #AgentLOD.update_priority]
    
    add     x24, x24, #1
    cmp     x24, #MAX_AGENTS
    b.lt    assign_lod_loop
    
    // Rebuild update queues
    bl      lod_rebuild_update_queues
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// lod_rebuild_update_queues - Rebuild update queues based on LOD assignments
//
lod_rebuild_update_queues:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Clear queue sizes
    adrp    x19, lod_system
    add     x19, x19, :lo12:lod_system
    add     x20, x19, #LODSystem.queue_sizes
    str     wzr, [x20]                  // near queue size
    str     wzr, [x20, #4]              // medium queue size
    str     wzr, [x20, #8]              // far queue size
    str     wzr, [x20, #12]             // culled queue size
    
    // Get queue pointers
    ldr     x21, [x19, #LODSystem.near_update_queue]
    ldr     x22, [x19, #LODSystem.medium_update_queue]
    ldr     x23, [x19, #LODSystem.far_update_queue]
    ldr     x24, [x19, #LODSystem.culled_update_queue]
    
    adrp    x25, agent_lod_data
    add     x25, x25, :lo12:agent_lod_data
    
    mov     x26, #0                     // Agent index
    mov     x27, #0                     // Near queue index
    mov     x28, #0                     // Medium queue index
    mov     x29, #0                     // Far queue index
    mov     x30, #0                     // Culled queue index
    
rebuild_queue_loop:
    // Calculate agent LOD data address
    mov     x0, #AgentLOD_size
    mul     x1, x26, x0
    add     x0, x25, x1                 // agent_lod_ptr
    
    // Get LOD level
    ldrb    w1, [x0, #AgentLOD.lod_level]
    
    // Add to appropriate queue
    cmp     w1, #LOD_NEAR
    b.ne    check_medium_queue
    
    // Add to near queue
    cmp     x27, #LOD_MAX_AGENTS_PER_FRAME
    b.ge    next_agent
    lsl     x2, x27, #2                 // * 4 bytes
    add     x2, x21, x2
    str     w26, [x2]                   // Store agent ID
    add     x27, x27, #1
    str     w27, [x20]                  // Update near queue size
    b       next_agent
    
check_medium_queue:
    cmp     w1, #LOD_MEDIUM
    b.ne    check_far_queue
    
    // Add to medium queue
    cmp     x28, #LOD_MAX_AGENTS_PER_FRAME
    b.ge    next_agent
    lsl     x2, x28, #2
    add     x2, x22, x2
    str     w26, [x2]
    add     x28, x28, #1
    str     w28, [x20, #4]              // Update medium queue size
    b       next_agent
    
check_far_queue:
    cmp     w1, #LOD_FAR
    b.ne    check_culled_queue
    
    // Add to far queue
    cmp     x29, #LOD_MAX_AGENTS_PER_FRAME
    b.ge    next_agent
    lsl     x2, x29, #2
    add     x2, x23, x2
    str     w26, [x2]
    add     x29, x29, #1
    str     w29, [x20, #8]              // Update far queue size
    b       next_agent
    
check_culled_queue:
    // Add to culled queue
    cmp     x30, #LOD_MAX_AGENTS_PER_FRAME
    b.ge    next_agent
    lsl     x2, x30, #2
    add     x2, x24, x2
    str     w26, [x2]
    add     x30, x30, #1
    str     w30, [x20, #12]             // Update culled queue size
    
next_agent:
    add     x26, x26, #1
    cmp     x26, #MAX_AGENTS
    b.lt    rebuild_queue_loop
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ============================================================================
// FRAME UPDATE PROCESSING
// ============================================================================

//
// lod_update_frame - Process agent updates for current frame
//
// Returns:
//   x0 = number of agents updated
//
lod_update_frame:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Start frame timing
    bl      get_current_time_ns
    mov     x19, x0                     // frame_start_time
    
    adrp    x20, lod_system
    add     x20, x20, :lo12:lod_system
    str     x0, [x20, #LODSystem.frame_start_time]
    
    // Increment frame counter
    ldr     x0, [x20, #LODSystem.current_frame]
    add     x0, x0, #1
    str     x0, [x20, #LODSystem.current_frame]
    mov     x21, x0                     // current_frame
    
    // Reset agents updated counter
    str     wzr, [x20, #LODSystem.agents_updated_this_frame]
    
    mov     x22, #0                     // Total agents updated
    
    // Process near LOD agents (every frame)
    mov     x0, #LOD_NEAR
    mov     x1, x21                     // current_frame
    bl      lod_process_queue
    add     x22, x22, x0
    
    // Process medium LOD agents (every 4 frames)
    and     x0, x21, #3                 // frame % 4
    cbnz    x0, skip_medium_lod
    mov     x0, #LOD_MEDIUM
    mov     x1, x21
    bl      lod_process_queue
    add     x22, x22, x0

skip_medium_lod:
    // Process far LOD agents (every 16 frames)
    and     x0, x21, #15                // frame % 16
    cbnz    x0, skip_far_lod
    mov     x0, #LOD_FAR
    mov     x1, x21
    bl      lod_process_queue
    add     x22, x22, x0

skip_far_lod:
    // Process culled agents (every 64 frames)
    and     x0, x21, #63                // frame % 64
    cbnz    x0, skip_culled_lod
    mov     x0, #LOD_INACTIVE
    mov     x1, x21
    bl      lod_process_queue
    add     x22, x22, x0

skip_culled_lod:
    // Update performance statistics
    bl      get_current_time_ns
    sub     x0, x0, x19                 // frame_duration
    str     x0, [x20, #LODSystem.time_spent_updating]
    
    // Check if we're exceeding time budget
    mov     x1, #LOD_TIME_BUDGET_NS
    cmp     x0, x1
    b.le    lod_frame_done
    
    // Exceeded time budget - adjust LOD parameters
    bl      lod_adjust_for_performance
    
lod_frame_done:
    mov     x0, x22                     // Return total agents updated
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// lod_process_queue - Process agents in a specific LOD queue
//
// Parameters:
//   x0 = lod_level
//   x1 = current_frame
//
// Returns:
//   x0 = number of agents processed
//
lod_process_queue:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // lod_level
    mov     x20, x1                     // current_frame
    
    // Get queue for this LOD level
    adrp    x21, lod_system
    add     x21, x21, :lo12:lod_system
    
    // Get queue pointer and size
    cmp     x19, #LOD_NEAR
    b.ne    check_medium_queue_process
    ldr     x22, [x21, #LODSystem.near_update_queue]
    ldr     w23, [x21, #LODSystem.queue_sizes]
    b       process_queue_agents
    
check_medium_queue_process:
    cmp     x19, #LOD_MEDIUM
    b.ne    check_far_queue_process
    ldr     x22, [x21, #LODSystem.medium_update_queue]
    ldr     w23, [x21, #LODSystem.queue_sizes + 4]
    b       process_queue_agents
    
check_far_queue_process:
    cmp     x19, #LOD_FAR
    b.ne    check_culled_queue_process
    ldr     x22, [x21, #LODSystem.far_update_queue]
    ldr     w23, [x21, #LODSystem.queue_sizes + 8]
    b       process_queue_agents
    
check_culled_queue_process:
    ldr     x22, [x21, #LODSystem.culled_update_queue]
    ldr     w23, [x21, #LODSystem.queue_sizes + 12]
    
process_queue_agents:
    mov     x24, #0                     // Agent index in queue
    mov     x25, #0                     // Agents processed count
    
process_agent_loop:
    cmp     w24, w23                    // Check if we've processed all agents
    b.ge    process_queue_done
    
    // Check time budget
    bl      get_current_time_ns
    ldr     x0, [x21, #LODSystem.frame_start_time]
    sub     x1, x0, x0                  // Time elapsed TODO: fix this
    mov     x2, #LOD_TIME_BUDGET_NS
    cmp     x1, x2
    b.ge    process_queue_done          // Time budget exceeded
    
    // Get agent ID from queue
    lsl     x0, x24, #2                 // * 4 bytes
    add     x0, x22, x0
    ldr     w26, [x0]                   // agent_id
    
    // Update this agent
    mov     x0, x26                     // agent_id
    mov     x1, x19                     // lod_level
    bl      lod_update_single_agent
    
    add     x25, x25, #1                // Increment processed count
    add     x24, x24, #1                // Move to next agent
    b       process_agent_loop

process_queue_done:
    // Update statistics
    cmp     x19, #LOD_NEAR
    b.ne    1f
    ldr     x0, [x21, #LODSystem.total_near_updates]
    add     x0, x0, x25
    str     x0, [x21, #LODSystem.total_near_updates]
    b       process_stats_done
1:  cmp     x19, #LOD_MEDIUM
    b.ne    2f
    ldr     x0, [x21, #LODSystem.total_medium_updates]
    add     x0, x0, x25
    str     x0, [x21, #LODSystem.total_medium_updates]
    b       process_stats_done
2:  cmp     x19, #LOD_FAR
    b.ne    3f
    ldr     x0, [x21, #LODSystem.total_far_updates]
    add     x0, x0, x25
    str     x0, [x21, #LODSystem.total_far_updates]
    b       process_stats_done
3:  ldr     x0, [x21, #LODSystem.total_culled_updates]
    add     x0, x0, x25
    str     x0, [x21, #LODSystem.total_culled_updates]

process_stats_done:
    mov     x0, x25                     // Return agents processed
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// lod_update_single_agent - Update a single agent based on LOD level
//
// Parameters:
//   x0 = agent_id
//   x1 = lod_level
//
lod_update_single_agent:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // agent_id
    mov     x20, x1                     // lod_level
    
    // Different update complexity based on LOD level
    cmp     x20, #LOD_NEAR
    b.eq    update_near_lod_agent
    cmp     x20, #LOD_MEDIUM
    b.eq    update_medium_lod_agent
    cmp     x20, #LOD_FAR
    b.eq    update_far_lod_agent
    b       update_culled_agent

update_near_lod_agent:
    // Full update: movement, behavior, pathfinding, rendering
    mov     x0, x19                     // agent_id
    bl      behavior_update_agent       // Full behavior update
    b       update_agent_done

update_medium_lod_agent:
    // Reduced update: behavior only, simplified movement
    mov     x0, x19                     // agent_id
    bl      behavior_update_agent       // Behavior update only
    b       update_agent_done

update_far_lod_agent:
    // Minimal update: state transitions only
    mov     x0, x19                     // agent_id
    bl      lod_minimal_agent_update
    b       update_agent_done

update_culled_agent:
    // Background simulation: very minimal updates
    mov     x0, x19                     // agent_id
    bl      lod_background_agent_update

update_agent_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ============================================================================
// PERFORMANCE ADAPTATION
// ============================================================================

//
// lod_adjust_for_performance - Adjust LOD parameters based on performance
//
lod_adjust_for_performance:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    adrp    x19, lod_system
    add     x19, x19, :lo12:lod_system
    
    // Get current performance ratio
    ldr     x0, [x19, #LODSystem.time_spent_updating]
    mov     x1, #LOD_TIME_BUDGET_NS
    udiv    x2, x0, x1                  // ratio = actual_time / budget_time
    
    // Update adaptive LOD multiplier
    ldr     w3, [x19, #LODSystem.adaptive_lod_multiplier]
    
    // If we're over budget, increase LOD distances (reduce detail)
    cmp     x2, #1000                   // 1.0 in scaled format
    b.le    performance_good
    
    // Performance is poor - reduce detail
    add     w3, w3, #100                // Increase LOD multiplier by 10%
    mov     w4, #2000                   // Max multiplier (2.0x)
    cmp     w3, w4
    csel    w3, w3, w4, le
    b       store_multiplier
    
performance_good:
    // Performance is good - can afford more detail
    cmp     x2, #800                    // 0.8 in scaled format
    b.ge    store_multiplier
    
    sub     w3, w3, #50                 // Decrease LOD multiplier by 5%
    mov     w4, #1000                   // Min multiplier (1.0x)
    cmp     w3, w4
    csel    w3, w3, w4, ge

store_multiplier:
    str     w3, [x19, #LODSystem.adaptive_lod_multiplier]
    
    // Store performance sample
    add     x0, x19, #LODSystem.performance_samples
    ldr     w1, [x19, #LODSystem.sample_index]
    lsl     x2, x1, #3                  // * 8 bytes
    add     x0, x0, x2
    ldr     x2, [x19, #LODSystem.time_spent_updating]
    str     x2, [x0]
    
    // Update sample index
    add     w1, w1, #1
    cmp     w1, #PERFORMANCE_SAMPLE_SIZE
    csel    w1, w1, #0, lt              // Wrap around
    str     w1, [x19, #LODSystem.sample_index]
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

//
// lod_get_agent_lod_level - Get LOD level for a specific agent
//
// Parameters:
//   x0 = agent_id
//
// Returns:
//   x0 = lod_level
//
lod_get_agent_lod_level:
    // Simple mapping for demo: agent_id % MAX_AGENTS
    and     x1, x0, #(MAX_AGENTS - 1)
    
    adrp    x0, agent_lod_data
    add     x0, x0, :lo12:agent_lod_data
    mov     x2, #AgentLOD_size
    mul     x3, x1, x2
    add     x0, x0, x3
    ldrb    w0, [x0, #AgentLOD.lod_level]
    
    ret

//
// lod_set_agent_priority - Set update priority for an agent
//
// Parameters:
//   x0 = agent_id
//   x1 = priority (0-10)
//
lod_set_agent_priority:
    // Simple mapping for demo: agent_id % MAX_AGENTS
    and     x2, x0, #(MAX_AGENTS - 1)
    
    adrp    x0, agent_lod_data
    add     x0, x0, :lo12:agent_lod_data
    mov     x3, #AgentLOD_size
    mul     x4, x2, x3
    add     x0, x0, x4
    strb    w1, [x0, #AgentLOD.update_priority]
    
    ret

// ============================================================================
// STUB IMPLEMENTATIONS
// ============================================================================

lod_minimal_agent_update:
    // Minimal agent update for far LOD
    ret

lod_background_agent_update:
    // Background simulation for culled agents
    ret

lod_get_statistics:
    // Get LOD system statistics
    ret

lod_adjust_performance:
    // Manual performance adjustment
    ret

lod_system_shutdown:
    mov     x0, #0
    ret