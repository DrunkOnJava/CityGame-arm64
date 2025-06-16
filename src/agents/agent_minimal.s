//
// SimCity ARM64 Assembly - Minimal Agent System
// Agent 5: Agent Systems & AI
//
// Minimal agent system to demonstrate basic functionality
//

.text
.align 4

// ============================================================================
// CONSTANTS
// ============================================================================

.equ MAX_AGENTS,                100         // Reduced for testing
.equ AGENT_TYPE_CITIZEN,        0
.equ AGENT_STATE_IDLE,          0
.equ AGENT_STATE_MOVING,        1
.equ AGENT_FLAG_ACTIVE,         1

// ============================================================================
// DATA SECTION
// ============================================================================

.data
.align 3

// Agent system state
agent_count:        .word 0
agents_spawned:     .quad 0

// Simple agent arrays (reduced size)
agent_positions_x:  .space 400      // 100 agents * 4 bytes
agent_positions_y:  .space 400      // 100 agents * 4 bytes
agent_states:       .space 400      // 100 agents * 4 bytes
agent_flags:        .space 100      // 100 agents * 1 byte

.text

// ============================================================================
// GLOBAL SYMBOLS
// ============================================================================

.global agent_system_init
.global agent_spawn
.global agent_despawn
.global agent_update_all
.global get_current_time_ns

//
// agent_system_init - Initialize the agent management system
//
agent_system_init:
    // Clear agent count
    adr     x0, agent_count
    str     wzr, [x0]
    
    // Clear spawned count
    adr     x0, agents_spawned
    str     xzr, [x0]
    
    // Clear all agent data
    bl      clear_agent_data
    
    mov     x0, #0                      // Success
    ret

//
// clear_agent_data - Clear all agent arrays
//
clear_agent_data:
    // Clear positions_x
    adr     x0, agent_positions_x
    mov     x1, #0
    mov     x2, #100                    // 400 bytes / 4
1:  str     w1, [x0], #4
    subs    x2, x2, #1
    b.ne    1b
    
    // Clear positions_y
    adr     x0, agent_positions_y
    mov     x1, #0
    mov     x2, #100                    // 400 bytes / 4
2:  str     w1, [x0], #4
    subs    x2, x2, #1
    b.ne    2b
    
    // Clear states
    adr     x0, agent_states
    mov     x1, #0
    mov     x2, #100                    // 400 bytes / 4
3:  str     w1, [x0], #4
    subs    x2, x2, #1
    b.ne    3b
    
    // Clear flags
    adr     x0, agent_flags
    mov     x1, #0
    mov     x2, #100                    // 100 bytes
4:  strb    w1, [x0], #1
    subs    x2, x2, #1
    b.ne    4b
    
    ret

//
// agent_spawn - Spawn a new agent
//
// Parameters:
//   x0 = spawn_x
//   x1 = spawn_y
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
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Save spawn parameters
    mov     x19, x0                     // spawn_x
    mov     x20, x1                     // spawn_y
    
    // Find free agent slot
    bl      find_free_slot
    cbz     x0, spawn_failed
    
    mov     x21, x0                     // agent_id
    
    // Initialize agent data
    sub     x22, x21, #1                // Convert to 0-based index
    
    // Set position X
    adr     x0, agent_positions_x
    lsl     x1, x22, #2                 // * 4 bytes
    add     x0, x0, x1
    str     w19, [x0]
    
    // Set position Y
    adr     x0, agent_positions_y
    lsl     x1, x22, #2                 // * 4 bytes
    add     x0, x0, x1
    str     w20, [x0]
    
    // Set state
    adr     x0, agent_states
    lsl     x1, x22, #2                 // * 4 bytes
    add     x0, x0, x1
    mov     w2, #AGENT_STATE_IDLE
    str     w2, [x0]
    
    // Set flags
    adr     x0, agent_flags
    add     x0, x0, x22                 // * 1 byte
    mov     w2, #AGENT_FLAG_ACTIVE
    strb    w2, [x0]
    
    // Update counts
    adr     x0, agent_count
    ldr     w1, [x0]
    add     w1, w1, #1
    str     w1, [x0]
    
    adr     x0, agents_spawned
    ldr     x1, [x0]
    add     x1, x1, #1
    str     x1, [x0]
    
    mov     x0, x21                     // Return agent_id
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

spawn_failed:
    mov     x0, #0
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// find_free_slot - Find a free agent slot
//
// Returns:
//   x0 = agent_id (1-based, 0 on failure)
//
find_free_slot:
    mov     x1, #1                      // Start with agent_id 1
    
find_loop:
    cmp     x1, #MAX_AGENTS
    b.gt    no_free_slot
    
    // Check if slot is free
    sub     x2, x1, #1                  // Convert to 0-based index
    adr     x3, agent_flags
    ldrb    w4, [x3, x2]
    cbz     w4, found_slot              // Flag is 0, slot is free
    
    add     x1, x1, #1
    b       find_loop

found_slot:
    mov     x0, x1                      // Return agent_id
    ret

no_free_slot:
    mov     x0, #0                      // No free slot
    ret

//
// agent_despawn - Remove an agent
//
// Parameters:
//   x0 = agent_id
//
// Returns:
//   x0 = 0 on success, -1 on failure
//
agent_despawn:
    // Validate agent_id
    cmp     x0, #1
    b.lt    despawn_error
    cmp     x0, #MAX_AGENTS
    b.gt    despawn_error
    
    sub     x1, x0, #1                  // Convert to 0-based index
    
    // Check if agent is active
    adr     x2, agent_flags
    ldrb    w3, [x2, x1]
    cbz     w3, despawn_error           // Agent not active
    
    // Clear flag
    strb    wzr, [x2, x1]
    
    // Update count
    adr     x0, agent_count
    ldr     w1, [x0]
    sub     w1, w1, #1
    str     w1, [x0]
    
    mov     x0, #0                      // Success
    ret

despawn_error:
    mov     x0, #-1                     // Error
    ret

//
// agent_update_all - Update all active agents
//
// Returns:
//   x0 = update time (dummy)
//
agent_update_all:
    mov     x0, #1000                   // Return dummy time
    ret

//
// get_current_time_ns - Get current time
//
// Returns:
//   x0 = time in nanoseconds (dummy)
//
get_current_time_ns:
    mov     x0, #1000                   // Return dummy time
    ret