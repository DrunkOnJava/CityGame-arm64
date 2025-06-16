//
// SimCity ARM64 Assembly - Simple Agent System Test
// Agent 5: Agent Systems & AI
//
// Basic test to validate agent system functionality
//

.text
.align 4

// External dependencies
.global agent_system_init
.global agent_spawn
.global agent_despawn
.global agent_update_all
.global agent_get_statistics

// ============================================================================
// MAIN TEST PROGRAM
// ============================================================================

.global _start

_start:
    // Set up stack
    mov     x29, sp
    
    // Initialize agent system
    bl      agent_system_init
    cbnz    x0, test_failed
    
    // Test 1: Spawn a few agents
    bl      test_spawn_agents
    cbnz    x0, test_failed
    
    // Test 2: Update agents
    bl      test_update_agents
    
    // Test 3: Despawn agents
    bl      test_despawn_agents
    
    // Test passed
    mov     x0, #0                      // Success exit code
    b       exit_program

test_failed:
    mov     x0, #1                      // Failure exit code

exit_program:
    // Exit system call
    mov     x8, #93                     // sys_exit
    svc     #0

//
// test_spawn_agents - Test spawning multiple agents
//
// Returns:
//   x0 = 0 on success, error on failure
//
test_spawn_agents:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, #0                     // Agent counter
    mov     x20, #10                    // Number of agents to spawn
    
spawn_loop:
    // Calculate spawn position
    mov     x0, x19                     // spawn_x = counter
    add     x0, x0, #100                // Offset spawn position
    mov     x1, x19                     // spawn_y = counter  
    add     x1, x1, #100                // Offset spawn position
    
    mov     x2, #0                      // AGENT_TYPE_CITIZEN
    mov     x3, x0                      // home_x = spawn_x
    mov     x4, x1                      // home_y = spawn_y
    add     x5, x0, #10                 // work_x
    add     x6, x1, #10                 // work_y
    
    bl      agent_spawn
    cbz     x0, spawn_failed            // Failed to spawn
    
    add     x19, x19, #1
    cmp     x19, x20
    b.lt    spawn_loop
    
    mov     x0, #0                      // Success
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

spawn_failed:
    mov     x0, #1                      // Failure
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// test_update_agents - Test updating agents
//
test_update_agents:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Update all agents a few times
    mov     x19, #0
    
update_loop:
    bl      agent_update_all
    add     x19, x19, #1
    cmp     x19, #5                     // 5 update cycles
    b.lt    update_loop
    
    ldp     x29, x30, [sp], #16
    ret

//
// test_despawn_agents - Test despawning agents
//
test_despawn_agents:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Despawn first 5 agents
    mov     x19, #1                     // Start with agent_id 1
    
despawn_loop:
    mov     x0, x19
    bl      agent_despawn
    add     x19, x19, #1
    cmp     x19, #6                     // Despawn agents 1-5
    b.lt    despawn_loop
    
    ldp     x29, x30, [sp], #16
    ret