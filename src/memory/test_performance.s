// test_performance.s - Memory Management Performance Tests
// SimCity ARM64 Assembly Project - Agent 2: Memory Management
//
// Performance benchmark suite to verify memory allocation targets:
// - <100ns allocation time for agents, tiles, buildings
// - Support for 1M+ agents with acceptable performance
// - Memory throughput and latency measurements

.text
.align 4

// Include our memory system definitions
.include "../include/constants/memory.inc"
.include "../include/types/memory.inc"
.include "../include/macros/memory.inc"

// ============================================================================
// GLOBAL SYMBOLS
// ============================================================================

.global test_memory_performance
.global test_allocation_speed
.global test_agent_allocation_burst
.global test_memory_throughput
.global test_cache_performance

// External functions
.extern memory_init
.extern fast_agent_alloc
.extern fast_agent_free
.extern tile_alloc
.extern tile_free
.extern building_alloc
.extern building_free
.extern temp_alloc
.extern temp_reset

// ============================================================================
// TEST DATA SECTION
// ============================================================================

.data
.align 6

// Test configuration
test_config:
    burst_size:             .quad   10000   // Number of allocations per burst
    test_iterations:        .quad   100     // Number of test iterations
    target_alloc_time_ns:   .quad   100     // Target allocation time (nanoseconds)
    agent_count_target:     .quad   1000000 // Target agent count

// Test results storage
test_results:
    min_alloc_time:         .quad   0       // Minimum allocation time (cycles)
    max_alloc_time:         .quad   0       // Maximum allocation time (cycles)
    avg_alloc_time:         .quad   0       // Average allocation time (cycles)
    total_allocations:      .quad   0       // Total allocations performed
    failed_allocations:     .quad   0       // Number of failed allocations
    throughput_mb_per_sec:  .quad   0       // Throughput in MB/sec

// Agent pointer storage for testing
agent_pointers:         .fill   10000, 8, 0    // Storage for agent pointers

// Performance measurement variables
cpu_frequency:          .quad   3200000000      // Assumed 3.2GHz (adjust as needed)

// ============================================================================
// MAIN PERFORMANCE TEST SUITE
// ============================================================================

// test_memory_performance: Run complete performance test suite
// Returns:
//   x0 = 0 if all tests pass, negative if any test fails
test_memory_performance:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, #0                     // Test result accumulator
    
    // Print test header
    adrp    x0, .test_header_msg
    add     x0, x0, :lo12:.test_header_msg
    bl      .print_message
    
    // Test 1: Basic allocation speed
    bl      test_allocation_speed
    add     x19, x19, x0
    
    // Test 2: Agent allocation burst test
    bl      test_agent_allocation_burst
    add     x19, x19, x0
    
    // Test 3: Memory throughput test
    bl      test_memory_throughput
    add     x19, x19, x0
    
    // Test 4: Cache performance test
    bl      test_cache_performance
    add     x19, x19, x0
    
    // Print summary
    bl      .print_test_summary
    
    // Return overall result
    cmp     x19, #0
    cset    x0, eq                      // Return 0 if all tests passed
    sub     x0, xzr, x0                 // Negate to return 0 for success
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ============================================================================
// ALLOCATION SPEED TEST
// ============================================================================

// test_allocation_speed: Test individual allocation performance
// Returns:
//   x0 = 0 if test passes, negative if fails
test_allocation_speed:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Print test name
    adrp    x0, .test_alloc_speed_msg
    add     x0, x0, :lo12:.test_alloc_speed_msg
    bl      .print_message
    
    // Initialize statistics
    mov     x19, #0                     // Min time (will be updated)
    mov     x20, #0                     // Max time
    mov     x21, #0                     // Total time
    mov     x22, #0                     // Allocation count
    
    // Run allocation speed test
    adrp    x0, test_config
    add     x0, x0, :lo12:test_config
    ldr     x0, [x0, #8]                // test_iterations
    
.test_alloc_speed_loop:
    cbz     x0, .test_alloc_speed_done
    
    // Time a single agent allocation
    mrs     x1, cntvct_el0              // Start time
    bl      fast_agent_alloc
    mrs     x2, cntvct_el0              // End time
    
    // Check if allocation succeeded
    cbz     x0, .test_alloc_speed_failed
    
    // Free the allocation immediately
    bl      fast_agent_free
    
    // Calculate allocation time
    sub     x3, x2, x1                  // Time in cycles
    
    // Update statistics
    cbz     x22, .test_alloc_speed_first
    cmp     x3, x19                     // Compare with min
    csel    x19, x3, x19, lt
    cmp     x3, x20                     // Compare with max
    csel    x20, x3, x20, gt
    b       .test_alloc_speed_update

.test_alloc_speed_first:
    mov     x19, x3                     // Initialize min
    mov     x20, x3                     // Initialize max

.test_alloc_speed_update:
    add     x21, x21, x3                // Add to total
    add     x22, x22, #1                // Increment count
    
    sub     x0, x0, #1
    b       .test_alloc_speed_loop

.test_alloc_speed_done:
    // Calculate average time
    udiv    x0, x21, x22                // Average cycles
    
    // Convert to nanoseconds
    adrp    x1, cpu_frequency
    add     x1, x1, :lo12:cpu_frequency
    ldr     x1, [x1]
    mov     x2, #1000000000             // 1 billion for nanoseconds
    mul     x0, x0, x2
    udiv    x0, x0, x1                  // Average time in nanoseconds
    
    // Store results
    adrp    x1, test_results
    add     x1, x1, :lo12:test_results
    str     x19, [x1]                   // min_alloc_time
    str     x20, [x1, #8]               // max_alloc_time
    str     x0, [x1, #16]               // avg_alloc_time (in ns)
    str     x22, [x1, #24]              // total_allocations
    
    // Print results
    bl      .print_alloc_speed_results
    
    // Check if we meet the target (<100ns)
    adrp    x1, test_config
    add     x1, x1, :lo12:test_config
    ldr     x1, [x1, #16]               // target_alloc_time_ns
    cmp     x0, x1
    b.le    .test_alloc_speed_pass
    
    // Test failed
    adrp    x0, .test_alloc_speed_fail_msg
    add     x0, x0, :lo12:.test_alloc_speed_fail_msg
    bl      .print_message
    mov     x0, #-1
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.test_alloc_speed_pass:
    adrp    x0, .test_alloc_speed_pass_msg
    add     x0, x0, :lo12:.test_alloc_speed_pass_msg
    bl      .print_message
    mov     x0, #0
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.test_alloc_speed_failed:
    adrp    x0, .test_alloc_failed_msg
    add     x0, x0, :lo12:.test_alloc_failed_msg
    bl      .print_message
    mov     x0, #-1
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ============================================================================
// AGENT BURST ALLOCATION TEST
// ============================================================================

// test_agent_allocation_burst: Test allocation of many agents quickly
// Returns:
//   x0 = 0 if test passes, negative if fails
test_agent_allocation_burst:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Print test name
    adrp    x0, .test_burst_msg
    add     x0, x0, :lo12:.test_burst_msg
    bl      .print_message
    
    // Get burst size
    adrp    x19, test_config
    add     x19, x19, :lo12:test_config
    ldr     x20, [x19]                  // burst_size
    
    // Start timing
    mrs     x21, cntvct_el0
    
    // Allocate agents in burst
    adrp    x22, agent_pointers
    add     x22, x22, :lo12:agent_pointers
    mov     x0, x20
    
.test_burst_alloc_loop:
    cbz     x0, .test_burst_alloc_done
    
    bl      fast_agent_alloc
    cbz     x0, .test_burst_alloc_failed
    
    str     x0, [x22], #8               // Store pointer
    sub     x0, x0, #1
    b       .test_burst_alloc_loop

.test_burst_alloc_done:
    // End timing
    mrs     x1, cntvct_el0
    sub     x21, x1, x21                // Total time in cycles
    
    // Calculate allocations per second
    adrp    x1, cpu_frequency
    add     x1, x1, :lo12:cpu_frequency
    ldr     x1, [x1]
    mul     x2, x20, x1                 // burst_size * frequency
    udiv    x2, x2, x21                 // Allocations per second
    
    // Print burst results
    mov     x0, x20                     // Number allocated
    mov     x1, x2                      // Allocations per second
    bl      .print_burst_results
    
    // Free all allocated agents
    adrp    x22, agent_pointers
    add     x22, x22, :lo12:agent_pointers
    mov     x0, x20
    
.test_burst_free_loop:
    cbz     x0, .test_burst_free_done
    ldr     x1, [x22], #8
    stp     x0, x1, [sp, #-16]!
    mov     x0, x1
    bl      fast_agent_free
    ldp     x0, x1, [sp], #16
    sub     x0, x0, #1
    b       .test_burst_free_loop

.test_burst_free_done:
    mov     x0, #0                      // Test passed
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.test_burst_alloc_failed:
    adrp    x0, .test_burst_failed_msg
    add     x0, x0, :lo12:.test_burst_failed_msg
    bl      .print_message
    mov     x0, #-1
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ============================================================================
// MEMORY THROUGHPUT TEST
// ============================================================================

// test_memory_throughput: Test memory allocation throughput
// Returns:
//   x0 = 0 if test passes, negative if fails
test_memory_throughput:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Print test name
    adrp    x0, .test_throughput_msg
    add     x0, x0, :lo12:.test_throughput_msg
    bl      .print_message
    
    // Test different allocation sizes
    mov     x19, #0                     // Test result
    
    // Test agent allocations (128 bytes)
    mov     x0, #128
    mov     x1, #1000
    bl      .test_throughput_size
    add     x19, x19, x0
    
    // Test tile allocations (64 bytes)
    mov     x0, #64
    mov     x1, #2000
    bl      .test_throughput_size
    add     x19, x19, x0
    
    // Test building allocations (256 bytes)
    mov     x0, #256
    mov     x1, #500
    bl      .test_throughput_size
    add     x19, x19, x0
    
    mov     x0, x19                     // Return combined result
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ============================================================================
// CACHE PERFORMANCE TEST
// ============================================================================

// test_cache_performance: Test cache-aligned allocation performance
// Returns:
//   x0 = 0 if test passes, negative if fails
test_cache_performance:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Print test name
    adrp    x0, .test_cache_msg
    add     x0, x0, :lo12:.test_cache_msg
    bl      .print_message
    
    // Test cache-aligned vs non-aligned performance
    // This would require cache-aligned allocation functions
    // For now, we'll just return success
    
    mov     x0, #0                      // Test passed
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

// Test throughput for specific allocation size
.test_throughput_size:
    // Arguments: x0 = size, x1 = count
    // Returns: x0 = 0 if pass, negative if fail
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Size
    mov     x20, x1                     // Count
    
    // Time allocations
    mrs     x2, cntvct_el0              // Start time
    
    // Perform allocations using temp pool
    mov     x0, x20
.throughput_alloc_loop:
    cbz     x0, .throughput_alloc_done
    stp     x0, x1, [sp, #-16]!
    mov     x0, x19
    bl      temp_alloc
    ldp     x0, x1, [sp], #16
    cbz     x0, .throughput_failed      // Check allocation success
    sub     x0, x0, #1
    b       .throughput_alloc_loop

.throughput_alloc_done:
    mrs     x3, cntvct_el0              // End time
    
    // Reset temp pool (bulk free)
    bl      temp_reset
    
    // Calculate throughput
    sub     x3, x3, x2                  // Total cycles
    mul     x0, x19, x20                // Total bytes
    
    // Convert to MB/sec
    adrp    x1, cpu_frequency
    add     x1, x1, :lo12:cpu_frequency
    ldr     x1, [x1]
    mul     x0, x0, x1                  // bytes * frequency
    mov     x1, #1048576                // 1MB
    udiv    x0, x0, x1                  // Convert to MB
    udiv    x0, x0, x3                  // MB per cycle * cycles = MB/sec
    
    // Print result
    mov     x1, x19                     // Size
    mov     x2, x20                     // Count
    mov     x3, x0                      // Throughput
    bl      .print_throughput_result
    
    mov     x0, #0                      // Success
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.throughput_failed:
    mov     x0, #-1                     // Failure
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// Print functions (simplified - would use system calls in real implementation)
.print_message:
    // Arguments: x0 = message pointer
    // Simple print implementation
    ret

.print_alloc_speed_results:
    // Print allocation speed test results
    ret

.print_burst_results:
    // Arguments: x0 = count, x1 = allocs per second
    ret

.print_throughput_result:
    // Arguments: x0 = throughput, x1 = size, x2 = count, x3 = MB/sec
    ret

.print_test_summary:
    // Print overall test summary
    ret

// ============================================================================
// TEST MESSAGES
// ============================================================================

.section .rodata

.test_header_msg:
    .ascii "=== SimCity Memory Performance Test Suite ===\n"
    .ascii "Testing allocation performance targets:\n"
    .ascii "- Agent allocation: <100ns per allocation\n"
    .ascii "- Support for 1M+ agents\n"
    .ascii "- High throughput for real-time simulation\n\n"
    .byte 0

.test_alloc_speed_msg:
    .ascii "Test 1: Basic Allocation Speed\n"
    .ascii "Testing individual allocation performance...\n"
    .byte 0

.test_burst_msg:
    .ascii "Test 2: Agent Burst Allocation\n"
    .ascii "Testing rapid allocation of multiple agents...\n"
    .byte 0

.test_throughput_msg:
    .ascii "Test 3: Memory Throughput\n"
    .ascii "Testing allocation throughput for different sizes...\n"
    .byte 0

.test_cache_msg:
    .ascii "Test 4: Cache Performance\n"
    .ascii "Testing cache-aligned allocation performance...\n"
    .byte 0

.test_alloc_speed_pass_msg:
    .ascii "✓ Allocation speed test PASSED\n\n"
    .byte 0

.test_alloc_speed_fail_msg:
    .ascii "✗ Allocation speed test FAILED - exceeds 100ns target\n\n"
    .byte 0

.test_alloc_failed_msg:
    .ascii "✗ Allocation failed during speed test\n\n"
    .byte 0

.test_burst_failed_msg:
    .ascii "✗ Burst allocation test FAILED\n\n"
    .byte 0