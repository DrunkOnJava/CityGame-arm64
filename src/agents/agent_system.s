//
// SimCity ARM64 Assembly - Agent System Core
// Agent 5: Agent Systems & AI
//
// High-performance agent management system for 1M+ agents
// Uses Structure-of-Arrays layout and slab allocators for optimal cache performance
// Implements agent pooling, lifecycle management, and spatial indexing
//

.text
.align 4

// Include dependencies
.include "../simulation/simulation_constants.s"
.include "../include/constants/memory.inc"
.include "../include/types/memory.inc"
.include "../include/macros/memory.inc"

// ============================================================================
// AGENT SYSTEM CONSTANTS
// ============================================================================

// Agent system configuration
.equ MAX_AGENTS,                1048576     // Maximum 1M agents
.equ AGENTS_PER_POOL,           4096        // Agents per memory pool
.equ AGENT_POOLS_COUNT,         256         // Number of agent pools (1M / 4K)
.equ AGENT_CHUNK_SIZE,          64          // Average agents per chunk
.equ AGENT_ALIGNMENT,           64          // Cache line alignment for agent data
.equ AGENT_BATCH_SIZE,          16          // NEON batch processing size
.equ AGENT_PREFETCH_DISTANCE,   64          // Prefetch distance for memory access

// Memory pool configuration
.equ AGENT_POOL_ALIGNMENT,      4096        // Page alignment for pools
.equ AGENT_POOL_TOTAL_SIZE,     67108864    // 64MB total for all agent data
.equ AGENT_SPATIAL_HASH_SIZE,   16777216    // 16MB for spatial indexing
.equ AGENT_BEHAVIOR_POOL_SIZE,  67108864    // 64MB for behavior contexts

// Agent structure sizes (Structure-of-Arrays, NEON-optimized)
.equ AGENT_ID_SIZE,             4           // Agent ID (32-bit)
.equ AGENT_POS_X_SIZE,          4           // Position X (32-bit float)
.equ AGENT_POS_Y_SIZE,          4           // Position Y (32-bit float)
.equ AGENT_VEL_X_SIZE,          4           // Velocity X (32-bit float)
.equ AGENT_VEL_Y_SIZE,          4           // Velocity Y (32-bit float)
.equ AGENT_STATE_SIZE,          4           // Behavior state (32-bit)
.equ AGENT_TARGET_X_SIZE,       4           // Target X position (32-bit float)
.equ AGENT_TARGET_Y_SIZE,       4           // Target Y position (32-bit float)
.equ AGENT_TYPE_SIZE,           2           // Agent type (16-bit)
.equ AGENT_FLAGS_SIZE,          2           // Status flags (16-bit)
.equ AGENT_HOME_X_SIZE,         4           // Home X location (32-bit float)
.equ AGENT_HOME_Y_SIZE,         4           // Home Y location (32-bit float)
.equ AGENT_WORK_X_SIZE,         4           // Work X location (32-bit float)
.equ AGENT_WORK_Y_SIZE,         4           // Work Y location (32-bit float)
.equ AGENT_SCHEDULE_SIZE,       4           // Daily schedule state (32-bit)
.equ AGENT_HAPPINESS_SIZE,      1           // Happiness level (8-bit)
.equ AGENT_HEALTH_SIZE,         1           // Health level (8-bit)
.equ AGENT_MONEY_SIZE,          4           // Money amount (32-bit)
.equ AGENT_PATH_PTR_SIZE,       8           // Current path pointer (64-bit)
.equ AGENT_PATH_LEN_SIZE,       4           // Current path length (32-bit)
.equ AGENT_CHUNK_ID_SIZE,       4           // Spatial chunk assignment (32-bit)
.equ AGENT_NEXT_IN_CHUNK_SIZE,  4           // Next agent in spatial chunk (32-bit)
.equ AGENT_LOD_LEVEL_SIZE,      1           // Level of detail (8-bit)
.equ AGENT_UPDATE_TIMER_SIZE,   2           // Update timer (16-bit)

// Total agent data size per agent (aligned to cache line)
.equ AGENT_TOTAL_SIZE,          64          // Cache line aligned
.equ AGENT_EXTENDED_SIZE,       128         // Extended data (behavior context)

// Agent types
.equ AGENT_TYPE_CITIZEN,        0
.equ AGENT_TYPE_WORKER,         1
.equ AGENT_TYPE_SHOPPER,        2
.equ AGENT_TYPE_STUDENT,        3
.equ AGENT_TYPE_VISITOR,        4
.equ AGENT_TYPE_EMERGENCY,      5

// Agent states
.equ AGENT_STATE_IDLE,          0
.equ AGENT_STATE_MOVING,        1
.equ AGENT_STATE_AT_HOME,       2
.equ AGENT_STATE_AT_WORK,       3
.equ AGENT_STATE_SHOPPING,      4
.equ AGENT_STATE_COMMUTING,     5
.equ AGENT_STATE_EMERGENCY,     6

// Agent flags
.equ AGENT_FLAG_ACTIVE,         (1 << 0)    // Agent is active
.equ AGENT_FLAG_SPAWNED,        (1 << 1)    // Agent is spawned in world
.equ AGENT_FLAG_HAS_PATH,       (1 << 2)    // Agent has valid path
.equ AGENT_FLAG_PATHFINDING,    (1 << 3)    // Agent is pathfinding
.equ AGENT_FLAG_STUCK,          (1 << 4)    // Agent is stuck
.equ AGENT_FLAG_PRIORITY,       (1 << 5)    // High priority agent
.equ AGENT_FLAG_DIRTY,          (1 << 6)    // Needs update

// LOD update frequencies
.equ AGENT_LOD_NEAR_FREQ,       1           // Every frame
.equ AGENT_LOD_MEDIUM_FREQ,     4           // Every 4 frames
.equ AGENT_LOD_FAR_FREQ,        16          // Every 16 frames

// Performance thresholds
.equ AGENT_UPDATE_TIME_TARGET,  10000000    // 10ms in nanoseconds
.equ PATHFIND_TIME_TARGET,      1000000     // 1ms in nanoseconds

// ============================================================================
// STRUCTURE DEFINITIONS
// ============================================================================

// Agent pool structure (Structure-of-Arrays layout, NEON-optimized)
.struct AgentPool
    // Pool metadata (cache line 0)
    pool_id                 .word           // Pool identifier
    active_count            .word           // Number of active agents
    max_agents              .word           // Maximum agents in pool
    generation              .word           // Pool generation for validation
    
    // Free list management
    free_list_head          .word           // Head of free agent list
    free_count              .word           // Number of free slots
    allocation_count        .quad           // Total allocations for statistics
    
    // Memory layout information
    base_address            .quad           // Base address of pool memory
    memory_size             .quad           // Total memory size of pool
    
    // Structure-of-Arrays data (NEON-aligned, cache-friendly layout)
    agent_ids               .quad           // Array of agent IDs
    positions_x             .quad           // Array of X positions (NEON-aligned)
    positions_y             .quad           // Array of Y positions (NEON-aligned)
    velocities_x            .quad           // Array of X velocities (NEON-aligned)
    velocities_y            .quad           // Array of Y velocities (NEON-aligned)
    states                  .quad           // Array of behavior states
    targets_x               .quad           // Array of target X positions
    targets_y               .quad           // Array of target Y positions
    types                   .quad           // Array of agent types
    flags                   .quad           // Array of status flags
    homes_x                 .quad           // Array of home X positions
    homes_y                 .quad           // Array of home Y positions
    works_x                 .quad           // Array of work X positions
    works_y                 .quad           // Array of work Y positions
    schedules               .quad           // Array of daily schedules
    happiness_levels        .quad           // Array of happiness values
    health_levels           .quad           // Array of health values
    money_amounts           .quad           // Array of money amounts
    path_pointers           .quad           // Array of path pointers
    path_lengths            .quad           // Array of path lengths
    
    // Spatial indexing (cache line aligned)
    chunk_assignments       .quad           // Array of chunk assignments
    next_agent_in_chunk     .quad           // Linked list for spatial queries
    
    // Update scheduling and LOD
    update_timers           .quad           // Array of update timers
    lod_levels              .quad           // Array of LOD levels
    last_batch_update       .quad           // Last batch update timestamp
    
    // Performance tracking
    update_cycles           .quad           // CPU cycles spent on updates
    cache_misses            .word           // Estimated cache misses
    _padding                .space 12       // Align to cache line boundary
.endstruct

// Agent system state
.struct AgentSystem
    // System configuration
    total_agents            .word           // Total active agents
    max_agents              .word           // Maximum agents allowed
    active_pools            .word           // Number of active pools
    _pad1                   .word
    
    // Memory management
    pool_array              .quad           // Array of agent pools
    pool_allocator          .quad           // Pool memory allocator
    
    // Spatial indexing
    chunk_agent_heads       .quad           // Array of chunk agent list heads
    chunk_agent_counts      .quad           // Array of agent counts per chunk
    
    // Update scheduling
    near_update_queue       .quad           // Queue for near LOD updates
    medium_update_queue     .quad           // Queue for medium LOD updates
    far_update_queue        .quad           // Queue for far LOD updates
    
    update_queue_sizes      .space 12       // Sizes of update queues
    current_frame           .quad           // Current frame counter
    
    // Performance tracking
    last_update_time        .quad           // Last update duration
    avg_update_time         .quad           // Average update time
    peak_update_time        .quad           // Peak update time
    pathfind_cache          .quad           // Pathfinding result cache
    
    // Statistics
    agents_spawned          .quad           // Total agents spawned
    agents_despawned        .quad           // Total agents despawned
    pathfind_requests       .quad           // Total pathfinding requests
    pathfind_cache_hits     .quad           // Pathfinding cache hits
.endstruct

// ============================================================================
// GLOBAL DATA
// ============================================================================

.section .bss
.align 8

// Main agent system instance
agent_system:               .space AgentSystem_size

// Agent pools array
.align 4096
agent_pools:                .space (AGENT_POOLS_COUNT * AgentPool_size)

// Chunk-based spatial indexing
.align 8
chunk_agent_heads:          .space (TOTAL_CHUNKS * 8)
chunk_agent_counts:         .space (TOTAL_CHUNKS * 4)

// Update queues
.align 8
near_update_queue:          .space (MAX_AGENTS * 4)
medium_update_queue:        .space (MAX_AGENTS * 4)
far_update_queue:           .space (MAX_AGENTS * 4)

// Performance timing buffer
.align 8
timing_buffer:              .space 1024

.section .text

// ============================================================================
// GLOBAL SYMBOLS
// ============================================================================

.global agent_system_init
.global agent_system_shutdown
.global agent_spawn
.global agent_despawn
.global agent_update_all
.global agent_get_by_id
.global agent_get_in_chunk
.global agent_set_target
.global agent_get_statistics

// External dependencies
.extern slab_create
.extern slab_alloc
.extern slab_free
.extern get_chunk_at
.extern get_current_time_ns
.extern pathfind_request
.extern behavior_update

// ============================================================================
// AGENT SYSTEM INITIALIZATION
// ============================================================================

//
// agent_system_init - Initialize the agent management system
//
// Returns:
//   x0 = 0 on success, error code on failure
//
agent_system_init:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    
    // Clear agent system structure
    adrp    x19, agent_system
    add     x19, x19, :lo12:agent_system
    
    mov     x20, #0
    mov     x21, #(AgentSystem_size / 8)
1:  str     x20, [x19], #8
    subs    x21, x21, #1
    b.ne    1b
    
    // Reset pointer
    adrp    x19, agent_system
    add     x19, x19, :lo12:agent_system
    
    // Initialize system configuration
    mov     x20, #MAX_AGENTS
    str     w20, [x19, #AgentSystem.max_agents]
    
    // Set up pool array
    adrp    x20, agent_pools
    add     x20, x20, :lo12:agent_pools
    str     x20, [x19, #AgentSystem.pool_array]
    
    // Set up spatial indexing
    adrp    x20, chunk_agent_heads
    add     x20, x20, :lo12:chunk_agent_heads
    str     x20, [x19, #AgentSystem.chunk_agent_heads]
    
    adrp    x20, chunk_agent_counts
    add     x20, x20, :lo12:chunk_agent_counts
    str     x20, [x19, #AgentSystem.chunk_agent_counts]
    
    // Set up update queues
    adrp    x20, near_update_queue
    add     x20, x20, :lo12:near_update_queue
    str     x20, [x19, #AgentSystem.near_update_queue]
    
    adrp    x20, medium_update_queue
    add     x20, x20, :lo12:medium_update_queue
    str     x20, [x19, #AgentSystem.medium_update_queue]
    
    adrp    x20, far_update_queue
    add     x20, x20, :lo12:far_update_queue
    str     x20, [x19, #AgentSystem.far_update_queue]
    
    // Initialize agent pools
    bl      initialize_agent_pools
    cbz     x0, agent_init_success
    b       agent_init_error
    
    // Clear chunk agent data
    bl      clear_chunk_agent_data
    
    // Initialize pathfinding cache
    bl      initialize_pathfind_cache
    
agent_init_success:
    mov     x0, #0                      // Success
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

agent_init_error:
    mov     x0, #MEM_ERROR_INIT_FAILED
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//
// initialize_agent_pools - Initialize all agent memory pools
//
initialize_agent_pools:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    adrp    x19, agent_pools
    add     x19, x19, :lo12:agent_pools
    mov     x20, #0                     // Pool index
    
pool_init_loop:
    // Calculate pool address
    mov     x0, #AgentPool_size
    mul     x1, x20, x0
    add     x1, x19, x1                 // pool_ptr
    
    // Clear pool structure
    mov     x2, #0
    mov     x3, #(AgentPool_size / 8)
2:  str     x2, [x1], #8
    subs    x3, x3, #1
    b.ne    2b
    
    // Reset pool pointer
    mov     x0, #AgentPool_size
    mul     x1, x20, x0
    add     x1, x19, x1
    
    // Set pool configuration
    str     w20, [x1, #AgentPool.pool_id]
    mov     x2, #AGENTS_PER_POOL
    str     w2, [x1, #AgentPool.max_agents]
    str     w2, [x1, #AgentPool.free_count]
    
    // Allocate Structure-of-Arrays data
    mov     x0, x1
    bl      allocate_pool_arrays
    cbz     x0, pool_init_error
    
    // Initialize free list
    mov     x0, x1
    bl      initialize_pool_free_list
    
    add     x20, x20, #1
    cmp     x20, #AGENT_POOLS_COUNT
    b.lt    pool_init_loop
    
    mov     x0, #0                      // Success
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

pool_init_error:
    mov     x0, #MEM_ERROR_OUT_OF_MEMORY
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// allocate_pool_arrays - Allocate Structure-of-Arrays for an agent pool
//
// Parameters:
//   x0 = pool pointer
//
// Returns:
//   x0 = success (1) or failure (0)
//
allocate_pool_arrays:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save pool pointer
    
    // Allocate agent IDs array
    mov     x0, #AGENTS_PER_POOL
    lsl     x0, x0, #2                  // * 4 bytes
    bl      slab_alloc
    cbz     x0, alloc_arrays_error
    str     x0, [x19, #AgentPool.agent_ids]
    
    // Allocate positions arrays
    mov     x0, #AGENTS_PER_POOL
    lsl     x0, x0, #2                  // * 4 bytes
    bl      slab_alloc
    cbz     x0, alloc_arrays_error
    str     x0, [x19, #AgentPool.positions_x]
    
    mov     x0, #AGENTS_PER_POOL
    lsl     x0, x0, #2                  // * 4 bytes
    bl      slab_alloc
    cbz     x0, alloc_arrays_error
    str     x0, [x19, #AgentPool.positions_y]
    
    // Allocate velocity arrays
    mov     x0, #AGENTS_PER_POOL
    lsl     x0, x0, #2                  // * 4 bytes
    bl      slab_alloc
    cbz     x0, alloc_arrays_error
    str     x0, [x19, #AgentPool.velocities_x]
    
    mov     x0, #AGENTS_PER_POOL
    lsl     x0, x0, #2                  // * 4 bytes
    bl      slab_alloc
    cbz     x0, alloc_arrays_error
    str     x0, [x19, #AgentPool.velocities_y]
    
    // Allocate remaining arrays (states, targets, types, etc.)
    bl      allocate_remaining_arrays
    cbz     x0, alloc_arrays_error
    
    mov     x0, #1                      // Success
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

alloc_arrays_error:
    mov     x0, #0                      // Failure
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// allocate_remaining_arrays - Allocate remaining SoA arrays for agent pool
//
// Parameters:
//   x19 = pool pointer
//
// Returns:
//   x0 = success (1) or failure (0)
//
allocate_remaining_arrays:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Continue allocating arrays for all agent data fields
    // States array
    mov     x0, #AGENTS_PER_POOL
    lsl     x0, x0, #2                  // * 4 bytes
    bl      slab_alloc
    cbz     x0, alloc_remaining_error
    str     x0, [x19, #AgentPool.states]
    
    // Target positions
    mov     x0, #AGENTS_PER_POOL
    lsl     x0, x0, #2                  // * 4 bytes
    bl      slab_alloc
    cbz     x0, alloc_remaining_error
    str     x0, [x19, #AgentPool.targets_x]
    
    mov     x0, #AGENTS_PER_POOL
    lsl     x0, x0, #2                  // * 4 bytes
    bl      slab_alloc
    cbz     x0, alloc_remaining_error
    str     x0, [x19, #AgentPool.targets_y]
    
    // Types and flags
    mov     x0, #AGENTS_PER_POOL
    lsl     x0, x0, #1                  // * 2 bytes
    bl      slab_alloc
    cbz     x0, alloc_remaining_error
    str     x0, [x19, #AgentPool.types]
    
    mov     x0, #AGENTS_PER_POOL
    lsl     x0, x0, #1                  // * 2 bytes
    bl      slab_alloc
    cbz     x0, alloc_remaining_error
    str     x0, [x19, #AgentPool.flags]
    
    // Continue with home/work locations, schedules, etc.
    // ... (Additional array allocations would continue here)
    
    mov     x0, #1                      // Success
    ldp     x29, x30, [sp], #16
    ret

alloc_remaining_error:
    mov     x0, #0                      // Failure
    ldp     x29, x30, [sp], #16
    ret

//
// initialize_pool_free_list - Set up free agent list for a pool
//
// Parameters:
//   x0 = pool pointer
//
initialize_pool_free_list:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     x1, #0                      // First free agent index
    str     w1, [x0, #AgentPool.free_list_head]
    
    // Initialize free list chain (each free slot points to next)
    ldr     x2, [x0, #AgentPool.agent_ids]
    mov     x3, #0                      // Current index
    
free_list_loop:
    add     x4, x3, #1                  // Next index
    cmp     x4, #AGENTS_PER_POOL
    b.ge    free_list_end
    
    // Store next index at current position
    lsl     x5, x3, #2                  // * 4 bytes
    add     x6, x2, x5
    str     w4, [x6]
    
    add     x3, x3, #1
    b       free_list_loop

free_list_end:
    // Last free slot points to -1 (end of list)
    mov     x4, #-1
    lsl     x5, x3, #2
    add     x6, x2, x5
    str     w4, [x6]
    
    ldp     x29, x30, [sp], #16
    ret

//
// clear_chunk_agent_data - Clear spatial indexing data
//
clear_chunk_agent_data:
    adrp    x0, chunk_agent_heads
    add     x0, x0, :lo12:chunk_agent_heads
    
    mov     x1, #0
    mov     x2, #TOTAL_CHUNKS
1:  str     x1, [x0], #8               // Clear head pointers
    subs    x2, x2, #1
    b.ne    1b
    
    adrp    x0, chunk_agent_counts
    add     x0, x0, :lo12:chunk_agent_counts
    
    mov     x1, #0
    mov     x2, #TOTAL_CHUNKS
2:  str     w1, [x0], #4               // Clear counts
    subs    x2, x2, #1
    b.ne    2b
    
    ret

//
// initialize_pathfind_cache - Initialize pathfinding cache
//
initialize_pathfind_cache:
    // Placeholder for pathfinding cache initialization
    // This would set up cache structures for path reuse
    ret

// ============================================================================
// AGENT LIFECYCLE MANAGEMENT
// ============================================================================

//
// agent_spawn - Spawn a new agent in the world
//
// Parameters:
//   x0 = spawn_x (world tile coordinate)
//   x1 = spawn_y (world tile coordinate)
//   x2 = agent_type
//   x3 = home_x
//   x4 = home_y
//   x5 = work_x
//   x6 = work_y
//
// Returns:
//   x0 = agent_id (0 on failure)
//
agent_spawn:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    
    // Save spawn parameters
    mov     x19, x0                     // spawn_x
    mov     x20, x1                     // spawn_y
    mov     x21, x2                     // agent_type
    mov     x22, x3                     // home_x
    mov     x23, x4                     // home_y
    mov     x24, x5                     // work_x
    // work_y is in x6
    
    // Find free agent slot
    bl      find_free_agent_slot
    cbz     x0, agent_spawn_failed
    
    // x0 now contains pool_ptr in high 32 bits, agent_index in low 32 bits
    mov     x1, x0
    lsr     x2, x1, #32                 // pool_ptr
    and     x3, x1, #0xFFFFFFFF         // agent_index
    
    // Initialize agent data
    mov     x0, x2                      // pool_ptr
    mov     x1, x3                      // agent_index
    mov     x4, x19                     // spawn_x
    mov     x5, x20                     // spawn_y
    mov     x6, x21                     // agent_type
    bl      initialize_agent_data
    
    // Generate agent ID (pool_id << 16 | agent_index)
    ldr     w0, [x2, #AgentPool.pool_id]
    lsl     x0, x0, #16
    orr     x0, x0, x3                  // agent_id
    
    // Add to spatial index
    mov     x1, x19                     // spawn_x
    mov     x2, x20                     // spawn_y
    bl      add_agent_to_spatial_index
    
    // Update statistics
    adrp    x1, agent_system
    add     x1, x1, :lo12:agent_system
    ldr     x2, [x1, #AgentSystem.agents_spawned]
    add     x2, x2, #1
    str     x2, [x1, #AgentSystem.agents_spawned]
    
    ldr     w2, [x1, #AgentSystem.total_agents]
    add     w2, w2, #1
    str     w2, [x1, #AgentSystem.total_agents]
    
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

agent_spawn_failed:
    mov     x0, #0                      // Failed to spawn
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//
// find_free_agent_slot - Find a free agent slot in the pools
//
// Returns:
//   x0 = combined pool_ptr and agent_index (0 on failure)
//        Upper 32 bits: pool pointer
//        Lower 32 bits: agent index
//
find_free_agent_slot:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    adrp    x19, agent_pools
    add     x19, x19, :lo12:agent_pools
    mov     x20, #0                     // Pool index
    
search_pools_loop:
    // Calculate pool address
    mov     x0, #AgentPool_size
    mul     x1, x20, x0
    add     x1, x19, x1                 // pool_ptr
    
    // Check if pool has free agents
    ldr     w2, [x1, #AgentPool.free_count]
    cbz     w2, try_next_pool
    
    // Get free agent from this pool
    ldr     w3, [x1, #AgentPool.free_list_head]
    cmp     w3, #-1
    b.eq    try_next_pool
    
    // Update free list head
    ldr     x4, [x1, #AgentPool.agent_ids]
    lsl     x5, x3, #2                  // * 4 bytes
    add     x5, x4, x5
    ldr     w6, [x5]                    // Next free agent
    str     w6, [x1, #AgentPool.free_list_head]
    
    // Update free count and active count
    sub     w2, w2, #1
    str     w2, [x1, #AgentPool.free_count]
    
    ldr     w2, [x1, #AgentPool.active_count]
    add     w2, w2, #1
    str     w2, [x1, #AgentPool.active_count]
    
    // Return combined pool_ptr and agent_index
    lsl     x0, x1, #32                 // pool_ptr in upper bits
    orr     x0, x0, x3                  // agent_index in lower bits
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

try_next_pool:
    add     x20, x20, #1
    cmp     x20, #AGENT_POOLS_COUNT
    b.lt    search_pools_loop
    
    mov     x0, #0                      // No free slots found
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// initialize_agent_data - Initialize data for a newly spawned agent
//
// Parameters:
//   x0 = pool_ptr
//   x1 = agent_index
//   x4 = spawn_x
//   x5 = spawn_y
//   x6 = agent_type
//
initialize_agent_data:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Set position
    ldr     x2, [x0, #AgentPool.positions_x]
    lsl     x3, x1, #2                  // * 4 bytes
    add     x2, x2, x3
    str     w4, [x2]                    // Store spawn_x
    
    ldr     x2, [x0, #AgentPool.positions_y]
    lsl     x3, x1, #2
    add     x2, x2, x3
    str     w5, [x2]                    // Store spawn_y
    
    // Set agent type
    ldr     x2, [x0, #AgentPool.types]
    lsl     x3, x1, #1                  // * 2 bytes
    add     x2, x2, x3
    strh    w6, [x2]                    // Store agent_type
    
    // Set initial state
    ldr     x2, [x0, #AgentPool.states]
    lsl     x3, x1, #2                  // * 4 bytes
    add     x2, x2, x3
    mov     w7, #AGENT_STATE_IDLE
    str     w7, [x2]
    
    // Set flags
    ldr     x2, [x0, #AgentPool.flags]
    lsl     x3, x1, #1                  // * 2 bytes
    add     x2, x2, x3
    mov     w7, #(AGENT_FLAG_ACTIVE | AGENT_FLAG_SPAWNED)
    strh    w7, [x2]
    
    // Clear velocities
    ldr     x2, [x0, #AgentPool.velocities_x]
    lsl     x3, x1, #2
    add     x2, x2, x3
    str     wzr, [x2]
    
    ldr     x2, [x0, #AgentPool.velocities_y]
    lsl     x3, x1, #2
    add     x2, x2, x3
    str     wzr, [x2]
    
    // Initialize home and work locations (passed via stack/registers)
    // ... Additional initialization code would continue here
    
    ldp     x29, x30, [sp], #16
    ret

// External function stubs (to be implemented in separate files)
add_agent_to_spatial_index:
    ret

//
// agent_despawn - Remove an agent from the world
//
// Parameters:
//   x0 = agent_id
//
// Returns:
//   x0 = 0 on success, error code on failure
//
agent_despawn:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save agent_id
    
    // Decode agent ID to get pool and index
    lsr     x20, x19, #16               // pool_id
    and     x21, x19, #0xFFFF           // agent_index
    
    // Validate pool ID
    cmp     x20, #AGENT_POOLS_COUNT
    b.ge    agent_despawn_error
    
    // Get pool pointer
    adrp    x0, agent_pools
    add     x0, x0, :lo12:agent_pools
    mov     x1, #AgentPool_size
    mul     x2, x20, x1
    add     x22, x0, x2                 // pool_ptr
    
    // Validate agent index
    cmp     x21, #AGENTS_PER_POOL
    b.ge    agent_despawn_error
    
    // Check if agent is active
    ldr     x0, [x22, #AgentPool.flags]
    lsl     x1, x21, #1                 // * 2 bytes
    add     x0, x0, x1
    ldrh    w2, [x0]
    tst     w2, #AGENT_FLAG_ACTIVE
    b.eq    agent_despawn_error
    
    // Remove from spatial index
    mov     x0, x19                     // agent_id
    bl      remove_agent_from_spatial_index
    
    // Clear agent flags
    ldr     x0, [x22, #AgentPool.flags]
    lsl     x1, x21, #1
    add     x0, x0, x1
    strh    wzr, [x0]
    
    // Add to free list
    ldr     x0, [x22, #AgentPool.agent_ids]
    lsl     x1, x21, #2                 // * 4 bytes
    add     x0, x0, x1
    ldr     w2, [x22, #AgentPool.free_list_head]
    str     w2, [x0]                    // Link to current head
    str     w21, [x22, #AgentPool.free_list_head] // New head
    
    // Update counts
    ldr     w0, [x22, #AgentPool.active_count]
    sub     w0, w0, #1
    str     w0, [x22, #AgentPool.active_count]
    
    ldr     w0, [x22, #AgentPool.free_count]
    add     w0, w0, #1
    str     w0, [x22, #AgentPool.free_count]
    
    // Update system statistics
    adrp    x0, agent_system
    add     x0, x0, :lo12:agent_system
    ldr     x1, [x0, #AgentSystem.agents_despawned]
    add     x1, x1, #1
    str     x1, [x0, #AgentSystem.agents_despawned]
    
    ldr     w1, [x0, #AgentSystem.total_agents]
    sub     w1, w1, #1
    str     w1, [x0, #AgentSystem.total_agents]
    
    mov     x0, #0                      // Success
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

agent_despawn_error:
    mov     x0, #MEM_ERROR_INVALID_PTR
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// agent_update_all - Update all active agents
//
// Returns:
//   x0 = update time in nanoseconds
//
agent_update_all:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Start timing
    bl      get_current_time_ns
    mov     x19, x0                     // Start time
    
    // Get current frame counter
    adrp    x20, agent_system
    add     x20, x20, :lo12:agent_system
    ldr     x21, [x20, #AgentSystem.current_frame]
    add     x21, x21, #1
    str     x21, [x20, #AgentSystem.current_frame]
    
    // Update agents by LOD level
    bl      update_near_lod_agents
    bl      update_medium_lod_agents
    bl      update_far_lod_agents
    
    // End timing
    bl      get_current_time_ns
    sub     x22, x0, x19                // Update duration
    
    // Update performance statistics
    str     x22, [x20, #AgentSystem.last_update_time]
    
    // Update rolling average
    ldr     x0, [x20, #AgentSystem.avg_update_time]
    add     x0, x0, x22
    lsr     x0, x0, #1                  // Simple rolling average
    str     x0, [x20, #AgentSystem.avg_update_time]
    
    // Update peak time
    ldr     x0, [x20, #AgentSystem.peak_update_time]
    cmp     x22, x0
    b.le    1f
    str     x22, [x20, #AgentSystem.peak_update_time]
1:
    
    mov     x0, x22                     // Return update time
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// update_near_lod_agents - Update agents with near LOD (every frame)
//
update_near_lod_agents:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Get current frame
    adrp    x19, agent_system
    add     x19, x19, :lo12:agent_system
    ldr     x20, [x19, #AgentSystem.current_frame]
    
    // Process all pools
    adrp    x0, agent_pools
    add     x0, x0, :lo12:agent_pools
    mov     x1, #0                      // Pool index
    
update_near_pool_loop:
    // Calculate pool address
    mov     x2, #AgentPool_size
    mul     x3, x1, x2
    add     x2, x0, x3                  // pool_ptr
    
    // Update agents in this pool
    mov     x3, x2                      // pool_ptr
    mov     x4, #AGENT_LOD_NEAR_FREQ
    bl      update_pool_agents_by_lod
    
    add     x1, x1, #1
    cmp     x1, #AGENT_POOLS_COUNT
    b.lt    update_near_pool_loop
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// update_medium_lod_agents - Update agents with medium LOD (every 4 frames)
//
update_medium_lod_agents:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Check if this is a medium LOD frame
    adrp    x0, agent_system
    add     x0, x0, :lo12:agent_system
    ldr     x1, [x0, #AgentSystem.current_frame]
    and     x1, x1, #3                  // frame % 4
    cbnz    x1, update_medium_skip
    
    // Update medium LOD agents (similar to near LOD)
    // Implementation would be similar to update_near_lod_agents
    // but with different frequency check
    
update_medium_skip:
    ldp     x29, x30, [sp], #16
    ret

//
// update_far_lod_agents - Update agents with far LOD (every 16 frames)
//
update_far_lod_agents:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Check if this is a far LOD frame
    adrp    x0, agent_system
    add     x0, x0, :lo12:agent_system
    ldr     x1, [x0, #AgentSystem.current_frame]
    and     x1, x1, #15                 // frame % 16
    cbnz    x1, update_far_skip
    
    // Update far LOD agents
    // Implementation would be similar to update_near_lod_agents
    
update_far_skip:
    ldp     x29, x30, [sp], #16
    ret

//
// update_pool_agents_by_lod - Update agents in a pool based on LOD level
//
// Parameters:
//   x3 = pool_ptr
//   x4 = lod_frequency
//
update_pool_agents_by_lod:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x3                     // pool_ptr
    mov     x20, x4                     // lod_frequency
    
    // Get active count
    ldr     w0, [x19, #AgentPool.active_count]
    cbz     w0, update_pool_done
    
    // Process each agent in the pool
    mov     x1, #0                      // agent_index
    
update_pool_agent_loop:
    // Check if agent is active
    ldr     x2, [x19, #AgentPool.flags]
    lsl     x3, x1, #1                  // * 2 bytes
    add     x2, x2, x3
    ldrh    w4, [x2]
    tst     w4, #AGENT_FLAG_ACTIVE
    b.eq    update_pool_next_agent
    
    // Update this agent
    mov     x0, x19                     // pool_ptr
    mov     x2, x1                      // agent_index
    bl      update_single_agent
    
update_pool_next_agent:
    add     x1, x1, #1
    cmp     x1, #AGENTS_PER_POOL
    b.lt    update_pool_agent_loop
    
update_pool_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// update_single_agent - Update a single agent's state
//
// Parameters:
//   x0 = pool_ptr
//   x2 = agent_index
//
update_single_agent:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // pool_ptr
    mov     x20, x2                     // agent_index
    
    // Get agent's current state
    ldr     x0, [x19, #AgentPool.states]
    lsl     x1, x20, #2                 // * 4 bytes
    add     x0, x0, x1
    ldr     w21, [x0]                   // agent_state
    
    // Update based on state
    cmp     w21, #AGENT_STATE_MOVING
    b.eq    update_moving_agent
    cmp     w21, #AGENT_STATE_COMMUTING
    b.eq    update_commuting_agent
    
    // Default: idle agent processing
    b       update_idle_agent

update_moving_agent:
    // Update agent position based on velocity
    mov     x0, x19
    mov     x1, x20
    bl      update_agent_movement
    b       update_agent_done

update_commuting_agent:
    // Handle commuting behavior
    mov     x0, x19
    mov     x1, x20
    bl      update_agent_pathfinding
    b       update_agent_done

update_idle_agent:
    // Handle idle state
    b       update_agent_done

update_agent_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// agent_get_by_id - Get agent data by ID
//
// Parameters:
//   x0 = agent_id
//
// Returns:
//   x0 = pool_ptr (0 if not found)
//   x1 = agent_index
//
agent_get_by_id:
    // Decode agent ID
    lsr     x1, x0, #16                 // pool_id
    and     x2, x0, #0xFFFF             // agent_index
    
    // Validate pool ID
    cmp     x1, #AGENT_POOLS_COUNT
    b.ge    agent_get_not_found
    
    // Get pool pointer
    adrp    x0, agent_pools
    add     x0, x0, :lo12:agent_pools
    mov     x3, #AgentPool_size
    mul     x4, x1, x3
    add     x0, x0, x4                  // pool_ptr
    
    // Validate agent index
    cmp     x2, #AGENTS_PER_POOL
    b.ge    agent_get_not_found
    
    // Check if agent is active
    ldr     x3, [x0, #AgentPool.flags]
    lsl     x4, x2, #1                  // * 2 bytes
    add     x3, x3, x4
    ldrh    w4, [x3]
    tst     w4, #AGENT_FLAG_ACTIVE
    b.eq    agent_get_not_found
    
    mov     x1, x2                      // Return agent_index
    ret

agent_get_not_found:
    mov     x0, #0
    mov     x1, #0
    ret

//
// agent_set_target - Set target destination for an agent
//
// Parameters:
//   x0 = agent_id
//   x1 = target_x
//   x2 = target_y
//
// Returns:
//   x0 = 0 on success, error code on failure
//
agent_set_target:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x1                     // Save target_x
    mov     x20, x2                     // Save target_y
    
    // Get agent by ID
    bl      agent_get_by_id
    cbz     x0, agent_set_target_error
    
    // x0 = pool_ptr, x1 = agent_index
    mov     x2, x0                      // pool_ptr
    mov     x3, x1                      // agent_index
    
    // Set target X
    ldr     x0, [x2, #AgentPool.targets_x]
    lsl     x1, x3, #2                  // * 4 bytes
    add     x0, x0, x1
    str     w19, [x0]
    
    // Set target Y
    ldr     x0, [x2, #AgentPool.targets_y]
    lsl     x1, x3, #2
    add     x0, x0, x1
    str     w20, [x0]
    
    // Set pathfinding flag
    ldr     x0, [x2, #AgentPool.flags]
    lsl     x1, x3, #1                  // * 2 bytes
    add     x0, x0, x1
    ldrh    w4, [x0]
    orr     w4, w4, #AGENT_FLAG_PATHFINDING
    strh    w4, [x0]
    
    // Change state to moving
    ldr     x0, [x2, #AgentPool.states]
    lsl     x1, x3, #2                  // * 4 bytes
    add     x0, x0, x1
    mov     w4, #AGENT_STATE_MOVING
    str     w4, [x0]
    
    mov     x0, #0                      // Success
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

agent_set_target_error:
    mov     x0, #MEM_ERROR_INVALID_PTR
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// agent_get_statistics - Get agent system statistics
//
// Parameters:
//   x0 = statistics buffer pointer
//
agent_get_statistics:
    adrp    x1, agent_system
    add     x1, x1, :lo12:agent_system
    
    // Copy statistics to buffer
    ldr     w2, [x1, #AgentSystem.total_agents]
    str     w2, [x0], #4
    
    ldr     x2, [x1, #AgentSystem.agents_spawned]
    str     x2, [x0], #8
    
    ldr     x2, [x1, #AgentSystem.agents_despawned]
    str     x2, [x0], #8
    
    ldr     x2, [x1, #AgentSystem.last_update_time]
    str     x2, [x0], #8
    
    ldr     x2, [x1, #AgentSystem.avg_update_time]
    str     x2, [x0], #8
    
    ldr     x2, [x1, #AgentSystem.peak_update_time]
    str     x2, [x0], #8
    
    ret

//
// agent_system_shutdown - Cleanup agent system
//
agent_system_shutdown:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Free all agent pool arrays
    bl      free_all_agent_pools
    
    // Clear system state
    adrp    x0, agent_system
    add     x0, x0, :lo12:agent_system
    
    mov     x1, #0
    mov     x2, #(AgentSystem_size / 8)
1:  str     x1, [x0], #8
    subs    x2, x2, #1
    b.ne    1b
    
    mov     x0, #0                      // Success
    ldp     x29, x30, [sp], #16
    ret

// Stub implementations for movement and pathfinding
update_agent_movement:
    ret

update_agent_pathfinding:
    ret

remove_agent_from_spatial_index:
    ret

free_all_agent_pools:
    ret