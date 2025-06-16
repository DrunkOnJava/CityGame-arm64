//
// Minimal Agent System Test
//

.text
.align 4

.global _start

// External functions
.global agent_system_init
.global agent_spawn
.global agent_despawn

_start:
    // Initialize agent system
    bl      agent_system_init
    
    // Test spawning an agent
    mov     x0, #100                    // spawn_x
    mov     x1, #100                    // spawn_y
    mov     x2, #0                      // agent_type
    mov     x3, #90                     // home_x
    mov     x4, #90                     // home_y
    mov     x5, #110                    // work_x
    mov     x6, #110                    // work_y
    bl      agent_spawn
    
    // Check if spawn succeeded
    cbz     x0, test_failed
    
    // Test spawning another agent
    mov     x0, #200                    // spawn_x
    mov     x1, #200                    // spawn_y
    mov     x2, #0                      // agent_type
    mov     x3, #190                    // home_x
    mov     x4, #190                    // home_y
    mov     x5, #210                    // work_x
    mov     x6, #210                    // work_y
    bl      agent_spawn
    
    // Check if spawn succeeded
    cbz     x0, test_failed
    
    // Test despawning first agent
    mov     x0, #1                      // agent_id
    bl      agent_despawn
    cbnz    x0, test_failed
    
    // Test passed
    mov     x0, #0                      // Success exit code
    b       exit_program

test_failed:
    mov     x0, #1                      // Failure exit code

exit_program:
    // Exit system call
    mov     x8, #93                     // sys_exit
    svc     #0