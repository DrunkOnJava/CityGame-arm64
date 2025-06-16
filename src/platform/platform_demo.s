//
// SimCity ARM64 Assembly - Platform Demonstration
// Agent 1: Platform & System Integration
//
// Demonstration of platform initialization and basic functionality
// Shows how other agents should interact with platform services
//

.global platform_demo_main
.global platform_demo_test

.align 2

// Platform demonstration main function
// Input: none
// Output: x0 = 0 on success, error code on failure
platform_demo_main:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp

    // Initialize platform
    bl platform_init
    cmp x0, #0
    b.ne demo_error

    // Print initialization success message
    adrp x0, init_success_msg@PAGE
    add x0, x0, init_success_msg@PAGEOFF
    mov x1, #init_success_msg_len
    bl platform_write_string

    // Test memory allocation
    bl demo_test_memory
    cmp x0, #0
    b.ne demo_error

    // Test thread system
    bl demo_test_threads
    cmp x0, #0
    b.ne demo_error

    // Test Metal system
    bl demo_test_metal
    cmp x0, #0
    b.ne demo_error

    // Get and display platform information
    bl demo_show_platform_info
    cmp x0, #0
    b.ne demo_error

    // Clean shutdown
    bl platform_shutdown
    cmp x0, #0
    b.ne demo_error

    // Print shutdown success message
    adrp x0, shutdown_success_msg@PAGE
    add x0, x0, shutdown_success_msg@PAGEOFF
    mov x1, #shutdown_success_msg_len
    bl platform_write_string

    // Success
    mov x0, #0
    b demo_done

demo_error:
    // Print error message
    adrp x1, error_msg@PAGE
    add x1, x1, error_msg@PAGEOFF
    mov x2, #error_msg_len
    bl platform_write_string
    
    // Attempt cleanup
    bl platform_shutdown

demo_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Test memory allocation functionality
// Output: x0 = 0 on success, error code on failure
demo_test_memory:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp

    // Allocate 1KB of memory
    mov x0, #1024
    bl platform_alloc_memory
    cbz x0, memory_test_error
    mov x19, x0              // Save allocated address

    // Write test pattern to memory
    mov x1, #0xDEADBEEF
    str x1, [x19]
    str x1, [x19, #8]

    // Verify pattern
    ldr x2, [x19]
    cmp x2, x1
    b.ne memory_test_error

    // Free memory
    mov x0, x19
    mov x1, #1024
    bl platform_free_memory
    cmp x0, #0
    b.ne memory_test_error

    // Print success message
    adrp x0, memory_test_msg@PAGE
    add x0, x0, memory_test_msg@PAGEOFF
    mov x1, #memory_test_msg_len
    bl platform_write_string

    mov x0, #0
    b memory_test_done

memory_test_error:
    mov x0, #-1

memory_test_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Test thread system functionality
// Output: x0 = 0 on success, error code on failure
demo_test_threads:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Get worker count
    bl thread_get_worker_count
    mov x1, x0

    // Print thread info
    adrp x0, thread_test_msg@PAGE
    add x0, x0, thread_test_msg@PAGEOFF
    mov x2, #thread_test_msg_len
    bl platform_write_string

    mov x0, #0
    ldp x29, x30, [sp], #16
    ret

// Test Metal system functionality
// Output: x0 = 0 on success, error code on failure
demo_test_metal:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Get Metal device
    bl metal_get_device
    cbz x0, metal_test_error

    // Print Metal success message
    adrp x0, metal_test_msg@PAGE
    add x0, x0, metal_test_msg@PAGEOFF
    mov x1, #metal_test_msg_len
    bl platform_write_string

    mov x0, #0
    b metal_test_done

metal_test_error:
    mov x0, #-1

metal_test_done:
    ldp x29, x30, [sp], #16
    ret

// Display platform information
// Output: x0 = 0 on success, error code on failure
demo_show_platform_info:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    mov x29, sp

    // Allocate space for platform info on stack
    sub sp, sp, #32
    mov x19, sp

    // Get platform information
    mov x0, x19
    bl platform_get_info
    cmp x0, #0
    b.ne info_error

    // Print platform info header
    adrp x0, info_header_msg@PAGE
    add x0, x0, info_header_msg@PAGEOFF
    mov x1, #info_header_msg_len
    bl platform_write_string

    // Print P-core count
    adrp x0, p_cores_msg@PAGE
    add x0, x0, p_cores_msg@PAGEOFF
    mov x1, #p_cores_msg_len
    bl platform_write_string

    // Print E-core count
    adrp x0, e_cores_msg@PAGE
    add x0, x0, e_cores_msg@PAGEOFF
    mov x1, #e_cores_msg_len
    bl platform_write_string

    mov x0, #0
    b info_done

info_error:
    mov x0, #-1

info_done:
    add sp, sp, #32
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Simple test function for external agents
// Input: none
// Output: x0 = 42 (magic number for testing)
platform_demo_test:
    mov x0, #42
    ret

.section .data
.align 3

init_success_msg:
    .ascii "Platform initialized successfully\n"
init_success_msg_len = . - init_success_msg

shutdown_success_msg:
    .ascii "Platform shutdown successfully\n"
shutdown_success_msg_len = . - shutdown_success_msg

error_msg:
    .ascii "Platform demo encountered an error\n"
error_msg_len = . - error_msg

memory_test_msg:
    .ascii "Memory allocation test passed\n"
memory_test_msg_len = . - memory_test_msg

thread_test_msg:
    .ascii "Thread system test passed\n"
thread_test_msg_len = . - thread_test_msg

metal_test_msg:
    .ascii "Metal system test passed\n"
metal_test_msg_len = . - metal_test_msg

info_header_msg:
    .ascii "Platform Information:\n"
info_header_msg_len = . - info_header_msg

p_cores_msg:
    .ascii "P-cores available\n"
p_cores_msg_len = . - p_cores_msg

e_cores_msg:
    .ascii "E-cores available\n"
e_cores_msg_len = . - e_cores_msg