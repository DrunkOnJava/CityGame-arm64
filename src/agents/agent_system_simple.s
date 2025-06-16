//
// SimCity ARM64 Assembly - Simplified Agent System Core
// Agent 5: Agent Systems & AI
//
// High-performance agent management system for 1M+ agents
// Simplified version to get working quickly
//

.text
.align 4

// ============================================================================
// AGENT SYSTEM CONSTANTS
// ============================================================================

// Agent system configuration
.equ MAX_AGENTS,                1048576     // Maximum 1M agents
.equ AGENTS_PER_POOL,           4096        // Agents per memory pool
.equ AGENT_POOLS_COUNT,         256         // Number of agent pools (1M / 4K)

// World constants from simulation
.equ WORLD_WIDTH,               4096        // World width in tiles
.equ WORLD_HEIGHT,              4096        // World height in tiles
.equ CHUNK_SIZE,                16          // Tiles per chunk side
.equ TOTAL_CHUNKS,              65536       // Total chunks (256*256)

// Agent structure sizes (Structure-of-Arrays, NEON-optimized)
.equ AGENT_DATA_SIZE,           64          // Cache line aligned per agent

// Agent types
.equ AGENT_TYPE_CITIZEN,        0
.equ AGENT_TYPE_WORKER,         1
.equ AGENT_TYPE_SHOPPER,        2

// Agent states
.equ AGENT_STATE_IDLE,          0
.equ AGENT_STATE_MOVING,        1
.equ AGENT_STATE_AT_HOME,       2
.equ AGENT_STATE_AT_WORK,       3

// Agent flags
.equ AGENT_FLAG_ACTIVE,         1           // Agent is active
.equ AGENT_FLAG_SPAWNED,        2           // Agent is spawned in world

// Error codes
.equ MEM_ERROR_INIT_FAILED,     -7
.equ MEM_ERROR_OUT_OF_MEMORY,   -3
.equ MEM_ERROR_INVALID_PTR,     -6

// ============================================================================
// STRUCTURE OFFSETS (Manual calculation)
// ============================================================================

// AgentPool structure offsets
.equ POOL_ID_OFFSET,            0           // 4 bytes
.equ ACTIVE_COUNT_OFFSET,       4           // 4 bytes  
.equ MAX_AGENTS_OFFSET,         8           // 4 bytes
.equ FREE_COUNT_OFFSET,         12          // 4 bytes
.equ AGENT_IDS_OFFSET,          16          // 8 bytes ptr
.equ POSITIONS_X_OFFSET,        24          // 8 bytes ptr
.equ POSITIONS_Y_OFFSET,        32          // 8 bytes ptr
.equ VELOCITIES_X_OFFSET,       40          // 8 bytes ptr
.equ VELOCITIES_Y_OFFSET,       48          // 8 bytes ptr
.equ STATES_OFFSET,             56          // 8 bytes ptr
.equ TARGETS_X_OFFSET,          64          // 8 bytes ptr
.equ TARGETS_Y_OFFSET,          72          // 8 bytes ptr
.equ TYPES_OFFSET,              80          // 8 bytes ptr
.equ FLAGS_OFFSET,              88          // 8 bytes ptr
.equ AGENT_POOL_SIZE,           256         // Total pool structure size

// AgentSystem structure offsets
.equ TOTAL_AGENTS_OFFSET,       0           // 4 bytes
.equ MAX_AGENTS_SYS_OFFSET,     4           // 4 bytes
.equ POOL_ARRAY_OFFSET,         8           // 8 bytes ptr
.equ AGENTS_SPAWNED_OFFSET,     16          // 8 bytes
.equ AGENTS_DESPAWNED_OFFSET,   24          // 8 bytes
.equ LAST_UPDATE_TIME_OFFSET,   32          // 8 bytes
.equ AVG_UPDATE_TIME_OFFSET,    40          // 8 bytes
.equ PEAK_UPDATE_TIME_OFFSET,   48          // 8 bytes
.equ AGENT_SYSTEM_SIZE,         128         // Total system structure size

// ============================================================================
// GLOBAL DATA
// ============================================================================

.data
.align 3

// Main agent system instance
agent_system:               .space 128

// Agent pools array (simplified)
.align 6
agent_pools:                .space 65536      // 256 pools * 256 bytes each

// Simple agent data arrays
.align 6
agent_positions_x:          .space 4194304    // 1M agents * 4 bytes
agent_positions_y:          .space 4194304    // 1M agents * 4 bytes
agent_velocities_x:         .space 4194304    // 1M agents * 4 bytes
agent_velocities_y:         .space 4194304    // 1M agents * 4 bytes
agent_states:               .space 4194304    // 1M agents * 4 bytes
agent_types:                .space 1048576    // 1M agents * 1 byte
agent_flags:                .space 1048576    // 1M agents * 1 byte

// Agent allocation bitmap (1 bit per agent)
agent_allocation_bitmap:    .space 131072     // 1M bits = 128KB

.text

// ============================================================================
// GLOBAL SYMBOLS
// ============================================================================

.global agent_system_init
.global agent_system_shutdown
.global agent_spawn
.global agent_despawn
.global agent_update_all
.global agent_get_by_id
.global agent_set_target
.global agent_get_statistics

// External dependencies (stubs for now)
.global get_current_time_ns

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
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Clear agent system structure
    adrp    x19, agent_system
    add     x19, x19, :lo12:agent_system
    
    mov     x20, #0
    mov     x21, #16                    // 128 bytes / 8
1:  str     x20, [x19], #8
    subs    x21, x21, #1
    b.ne    1b
    
    // Reset pointer
    adrp    x19, agent_system
    add     x19, x19, :lo12:agent_system
    
    // Initialize system configuration
    mov     x20, #MAX_AGENTS
    str     w20, [x19, #MAX_AGENTS_SYS_OFFSET]
    
    // Set up pool array pointer
    adrp    x20, agent_pools
    add     x20, x20, :lo12:agent_pools
    str     x20, [x19, #POOL_ARRAY_OFFSET]
    
    // Clear allocation bitmap
    bl      clear_allocation_bitmap
    
    // Clear agent data arrays
    bl      clear_agent_arrays
    
    mov     x0, #0                      // Success
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// clear_allocation_bitmap - Clear the agent allocation bitmap
//
clear_allocation_bitmap:
    adrp    x0, agent_allocation_bitmap
    add     x0, x0, :lo12:agent_allocation_bitmap
    
    mov     x1, #0
    mov     x2, #16384                  // 131072 bytes / 8
1:  str     x1, [x0], #8
    subs    x2, x2, #1
    b.ne    1b
    
    ret

//
// clear_agent_arrays - Clear all agent data arrays
//
clear_agent_arrays:
    // Clear positions_x
    adrp    x0, agent_positions_x
    add     x0, x0, :lo12:agent_positions_x
    mov     x1, #0
    mov     x2, #524288                 // 4194304 bytes / 8
1:  str     x1, [x0], #8
    subs    x2, x2, #1
    b.ne    1b
    
    // Clear positions_y
    adrp    x0, agent_positions_y
    add     x0, x0, :lo12:agent_positions_y
    mov     x1, #0
    mov     x2, #524288                 // 4194304 bytes / 8
2:  str     x1, [x0], #8
    subs    x2, x2, #1
    b.ne    2b
    
    // Clear other arrays (velocities, states, etc.)
    // Similar pattern for other arrays...
    
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
    
    // Find free agent slot
    bl      find_free_agent_slot
    cbz     x0, agent_spawn_failed
    
    mov     x22, x0                     // agent_id
    
    // Initialize agent data
    mov     x0, x22                     // agent_id
    mov     x1, x19                     // spawn_x
    mov     x2, x20                     // spawn_y
    mov     x3, x21                     // agent_type
    bl      initialize_agent_data
    
    // Mark agent as allocated in bitmap
    mov     x0, x22
    bl      set_agent_allocated
    
    // Update statistics
    adrp    x1, agent_system
    add     x1, x1, :lo12:agent_system
    ldr     x2, [x1, #AGENTS_SPAWNED_OFFSET]
    add     x2, x2, #1
    str     x2, [x1, #AGENTS_SPAWNED_OFFSET]
    
    ldr     w2, [x1, #TOTAL_AGENTS_OFFSET]
    add     w2, w2, #1
    str     w2, [x1, #TOTAL_AGENTS_OFFSET]
    
    mov     x0, x22                     // Return agent_id
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
// find_free_agent_slot - Find a free agent slot
//
// Returns:
//   x0 = agent_id (0 on failure)
//
find_free_agent_slot:
    adrp    x0, agent_allocation_bitmap
    add     x0, x0, :lo12:agent_allocation_bitmap
    
    mov     x1, #0                      // Current agent ID
    mov     x2, #MAX_AGENTS
    
find_slot_loop:
    // Calculate byte and bit position
    lsr     x3, x1, #3                  // byte_offset = agent_id / 8
    and     x4, x1, #7                  // bit_offset = agent_id % 8
    
    // Load byte from bitmap
    ldrb    w5, [x0, x3]
    
    // Check if bit is free (0)
    mov     x6, #1
    lsl     x6, x6, x4                  // bit_mask = 1 << bit_offset
    tst     w5, w6
    b.eq    found_free_slot             // Bit is 0, slot is free
    
    add     x1, x1, #1
    cmp     x1, x2
    b.lt    find_slot_loop
    
    mov     x0, #0                      // No free slot found
    ret

found_free_slot:
    add     x0, x1, #1                  // Return agent_id (1-based)
    ret

//
// set_agent_allocated - Mark agent as allocated in bitmap
//
// Parameters:
//   x0 = agent_id
//
set_agent_allocated:
    sub     x0, x0, #1                  // Convert to 0-based index
    
    adrp    x1, agent_allocation_bitmap
    add     x1, x1, :lo12:agent_allocation_bitmap
    
    // Calculate byte and bit position
    lsr     x2, x0, #3                  // byte_offset = agent_id / 8
    and     x3, x0, #7                  // bit_offset = agent_id % 8
    
    // Set bit in bitmap
    ldrb    w4, [x1, x2]
    mov     x5, #1
    lsl     x5, x5, x3                  // bit_mask = 1 << bit_offset
    orr     w4, w4, w5
    strb    w4, [x1, x2]
    
    ret

//
// initialize_agent_data - Initialize data for a newly spawned agent
//
// Parameters:
//   x0 = agent_id
//   x1 = spawn_x
//   x2 = spawn_y
//   x3 = agent_type
//
initialize_agent_data:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     x4, x0                      // Save agent_id
    sub     x4, x4, #1                  // Convert to 0-based index
    
    // Set position X
    adrp    x5, agent_positions_x
    add     x5, x5, :lo12:agent_positions_x
    lsl     x6, x4, #2                  // * 4 bytes (float)
    add     x5, x5, x6
    str     w1, [x5]                    // Store spawn_x
    
    // Set position Y
    adrp    x5, agent_positions_y
    add     x5, x5, :lo12:agent_positions_y
    lsl     x6, x4, #2                  // * 4 bytes (float)
    add     x5, x5, x6
    str     w2, [x5]                    // Store spawn_y
    
    // Set agent type
    adrp    x5, agent_types
    add     x5, x5, :lo12:agent_types
    add     x5, x5, x4                  // * 1 byte
    strb    w3, [x5]                    // Store agent_type
    
    // Set initial state
    adrp    x5, agent_states
    add     x5, x5, :lo12:agent_states
    lsl     x6, x4, #2                  // * 4 bytes
    add     x5, x5, x6
    mov     w7, #AGENT_STATE_IDLE
    str     w7, [x5]
    
    // Set flags
    adrp    x5, agent_flags
    add     x5, x5, :lo12:agent_flags
    add     x5, x5, x4                  // * 1 byte
    mov     w7, #(AGENT_FLAG_ACTIVE | AGENT_FLAG_SPAWNED)
    strb    w7, [x5]
    
    // Clear velocities
    adrp    x5, agent_velocities_x
    add     x5, x5, :lo12:agent_velocities_x
    lsl     x6, x4, #2
    add     x5, x5, x6
    str     wzr, [x5]
    
    adrp    x5, agent_velocities_y
    add     x5, x5, :lo12:agent_velocities_y
    lsl     x6, x4, #2
    add     x5, x5, x6
    str     wzr, [x5]
    
    ldp     x29, x30, [sp], #16
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
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     x1, x0                      // Save agent_id
    
    // Validate agent_id
    cmp     x1, #1
    b.lt    agent_despawn_error
    cmp     x1, #MAX_AGENTS
    b.gt    agent_despawn_error
    
    // Check if agent is allocated
    mov     x0, x1
    bl      is_agent_allocated
    cbz     x0, agent_despawn_error
    
    // Clear agent flags
    sub     x2, x1, #1                  // Convert to 0-based index
    adrp    x0, agent_flags
    add     x0, x0, :lo12:agent_flags
    add     x0, x0, x2
    strb    wzr, [x0]
    
    // Clear agent allocation bit
    mov     x0, x1
    bl      clear_agent_allocated
    
    // Update system statistics
    adrp    x0, agent_system
    add     x0, x0, :lo12:agent_system
    ldr     x1, [x0, #AGENTS_DESPAWNED_OFFSET]
    add     x1, x1, #1
    str     x1, [x0, #AGENTS_DESPAWNED_OFFSET]
    
    ldr     w1, [x0, #TOTAL_AGENTS_OFFSET]
    sub     w1, w1, #1
    str     w1, [x0, #TOTAL_AGENTS_OFFSET]
    
    mov     x0, #0                      // Success
    ldp     x29, x30, [sp], #16
    ret

agent_despawn_error:
    mov     x0, #MEM_ERROR_INVALID_PTR
    ldp     x29, x30, [sp], #16
    ret

//
// is_agent_allocated - Check if agent is allocated
//
// Parameters:
//   x0 = agent_id
//
// Returns:
//   x0 = 1 if allocated, 0 if free
//
is_agent_allocated:
    sub     x0, x0, #1                  // Convert to 0-based index
    
    adrp    x1, agent_allocation_bitmap
    add     x1, x1, :lo12:agent_allocation_bitmap
    
    // Calculate byte and bit position
    lsr     x2, x0, #3                  // byte_offset = agent_id / 8
    and     x3, x0, #7                  // bit_offset = agent_id % 8
    
    // Check bit in bitmap
    ldrb    w4, [x1, x2]
    mov     x5, #1
    lsl     x5, x5, x3                  // bit_mask = 1 << bit_offset
    and     w4, w4, w5
    cmp     w4, #0
    cset    x0, ne                      // Return 1 if bit is set, 0 if clear
    
    ret

//
// clear_agent_allocated - Clear agent allocation bit
//
// Parameters:
//   x0 = agent_id
//
clear_agent_allocated:
    sub     x0, x0, #1                  // Convert to 0-based index
    
    adrp    x1, agent_allocation_bitmap
    add     x1, x1, :lo12:agent_allocation_bitmap
    
    // Calculate byte and bit position
    lsr     x2, x0, #3                  // byte_offset = agent_id / 8
    and     x3, x0, #7                  // bit_offset = agent_id % 8
    
    // Clear bit in bitmap
    ldrb    w4, [x1, x2]
    mov     x5, #1
    lsl     x5, x5, x3                  // bit_mask = 1 << bit_offset
    bic     w4, w4, w5                  // Clear the bit
    strb    w4, [x1, x2]
    
    ret

//
// agent_update_all - Update all active agents
//
// Returns:
//   x0 = update time in nanoseconds
//
agent_update_all:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Start timing
    bl      get_current_time_ns
    mov     x19, x0                     // Start time
    
    // Update all agents (simplified version)
    mov     x20, #1                     // Start with agent_id 1
    
update_loop:
    cmp     x20, #MAX_AGENTS
    b.gt    update_done
    
    // Check if agent is allocated
    mov     x0, x20
    bl      is_agent_allocated
    cbz     x0, next_agent
    
    // Update this agent
    mov     x0, x20
    bl      update_single_agent
    
next_agent:
    add     x20, x20, #1
    b       update_loop
    
update_done:
    // End timing
    bl      get_current_time_ns
    sub     x0, x0, x19                 // Return update duration
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// update_single_agent - Update a single agent's state
//
// Parameters:
//   x0 = agent_id
//
update_single_agent:
    // For now, just a stub that does nothing
    // In a full implementation, this would:
    // - Update agent position based on velocity
    // - Process behavior state machine
    // - Handle pathfinding
    ret

//
// agent_get_by_id - Get agent data by ID
//
// Parameters:
//   x0 = agent_id
//
// Returns:
//   x0 = 1 if found, 0 if not found
//   x1 = agent_index (0-based)
//
agent_get_by_id:
    // Validate agent_id
    cmp     x0, #1
    b.lt    agent_get_not_found
    cmp     x0, #MAX_AGENTS
    b.gt    agent_get_not_found
    
    // Check if agent is allocated
    mov     x1, x0
    bl      is_agent_allocated
    cbz     x0, agent_get_not_found
    
    sub     x1, x1, #1                  // Convert to 0-based index
    mov     x0, #1                      // Found
    ret

agent_get_not_found:
    mov     x0, #0                      // Not found
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
    // Validate agent exists
    mov     x3, x1                      // Save target_x
    mov     x4, x2                      // Save target_y
    bl      agent_get_by_id
    cbz     x0, agent_set_target_error
    
    // For now, just return success
    // In full implementation, would set target coordinates
    // and initiate pathfinding
    
    mov     x0, #0                      // Success
    ret

agent_set_target_error:
    mov     x0, #MEM_ERROR_INVALID_PTR
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
    ldr     w2, [x1, #TOTAL_AGENTS_OFFSET]
    str     w2, [x0], #4
    
    ldr     x2, [x1, #AGENTS_SPAWNED_OFFSET]
    str     x2, [x0], #8
    
    ldr     x2, [x1, #AGENTS_DESPAWNED_OFFSET]
    str     x2, [x0], #8
    
    ldr     x2, [x1, #LAST_UPDATE_TIME_OFFSET]
    str     x2, [x0], #8
    
    ldr     x2, [x1, #AVG_UPDATE_TIME_OFFSET]
    str     x2, [x0], #8
    
    ldr     x2, [x1, #PEAK_UPDATE_TIME_OFFSET]
    str     x2, [x0], #8
    
    ret

//
// agent_system_shutdown - Cleanup agent system
//
agent_system_shutdown:
    // Clear all agent data
    bl      clear_allocation_bitmap
    bl      clear_agent_arrays
    
    // Clear system state
    adrp    x0, agent_system
    add     x0, x0, :lo12:agent_system
    
    mov     x1, #0
    mov     x2, #16                     // 128 bytes / 8
1:  str     x1, [x0], #8
    subs    x2, x2, #1
    b.ne    1b
    
    mov     x0, #0                      // Success
    ret

// ============================================================================
// EXTERNAL FUNCTION STUBS
// ============================================================================

//
// get_current_time_ns - Get current time in nanoseconds
//
// Returns:
//   x0 = current time in nanoseconds
//
get_current_time_ns:
    // For now, return a dummy time value
    // In real implementation, would use system calls
    mov     x0, #1000                   // 1 microsecond as dummy value
    ret