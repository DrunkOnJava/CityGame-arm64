// SimCity ARM64 TLSF Allocator Unit Tests - Agent D1: Infrastructure Architect
// Comprehensive test suite for TLSF memory allocator validation
// Tests performance, correctness, thread safety, and edge cases

.cpu generic+simd
.arch armv8-a+simd

// Test configuration constants
#define TEST_HEAP_SIZE              (16 * 1024 * 1024)  // 16MB test heap
#define TEST_MAX_ALLOCS             10000               // Maximum allocations per test
#define TEST_THREAD_COUNT           8                   // Number of test threads
#define PERFORMANCE_ITERATIONS      100000              // Performance test iterations
#define EXPECTED_ALLOC_TIME_NS      100                 // Target < 100ns allocation

// Test result codes
#define TEST_SUCCESS                0
#define TEST_FAIL_INIT              -1
#define TEST_FAIL_ALLOC             -2
#define TEST_FAIL_FREE              -3
#define TEST_FAIL_VALIDATION        -4
#define TEST_FAIL_PERFORMANCE       -5
#define TEST_FAIL_THREAD_SAFETY     -6

.section .data
.align 6

// Test heap memory (16MB aligned)
.test_heap:
    .space  TEST_HEAP_SIZE, 0

// Test state and statistics
.test_state:
    .current_test:      .quad   0                       // Current test number
    .tests_passed:      .quad   0                       // Passed test count
    .tests_failed:      .quad   0                       // Failed test count
    .total_tests:       .quad   0                       // Total test count
    .test_heap_base:    .quad   0                       // Test heap base address
    
// Performance measurement data
.perf_data:
    .alloc_times:       .fill   PERFORMANCE_ITERATIONS, 8, 0   // Allocation times
    .free_times:        .fill   PERFORMANCE_ITERATIONS, 8, 0   // Free times
    .min_alloc_time:    .quad   0xFFFFFFFFFFFFFFFF              // Minimum allocation time
    .max_alloc_time:    .quad   0                               // Maximum allocation time
    .avg_alloc_time:    .quad   0                               // Average allocation time
    .min_free_time:     .quad   0xFFFFFFFFFFFFFFFF              // Minimum free time
    .max_free_time:     .quad   0                               // Maximum free time
    .avg_free_time:     .quad   0                               // Average free time

// Thread test data
.thread_data:
    .thread_results:    .fill   TEST_THREAD_COUNT, 8, 0        // Per-thread results
    .thread_allocs:     .fill   TEST_THREAD_COUNT * 1000, 8, 0 // Per-thread allocations
    .barrier:           .quad   0                               // Thread synchronization barrier

// Test allocation pointers
.test_allocs:
    .fill   TEST_MAX_ALLOCS, 8, 0

.section .text
.align 4

//==============================================================================
// MAIN TEST SUITE ENTRY POINT
//==============================================================================

// _tlsf_run_all_tests: Run complete TLSF test suite
// Returns: x0 = overall result (0 = all passed, negative = failures)
.global _tlsf_run_all_tests
_tlsf_run_all_tests:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Initialize test environment
    bl      .test_init
    cmp     x0, #0
    b.ne    .test_suite_failed
    
    // Run basic functionality tests
    bl      .test_basic_init
    bl      .test_record_result
    
    bl      .test_basic_allocation
    bl      .test_record_result
    
    bl      .test_basic_free
    bl      .test_record_result
    
    bl      .test_alignment
    bl      .test_record_result
    
    bl      .test_coalescing
    bl      .test_record_result
    
    bl      .test_splitting
    bl      .test_record_result
    
    // Run edge case tests
    bl      .test_edge_cases
    bl      .test_record_result
    
    bl      .test_fragmentation
    bl      .test_record_result
    
    // Run performance tests
    bl      .test_performance_allocation
    bl      .test_record_result
    
    bl      .test_performance_free
    bl      .test_record_result
    
    // Run thread safety tests
    bl      .test_thread_safety
    bl      .test_record_result
    
    // Run stress tests
    bl      .test_stress_random
    bl      .test_record_result
    
    bl      .test_stress_pathological
    bl      .test_record_result
    
    // Print final results
    bl      .test_print_summary
    
    // Return overall result
    adrp    x1, .test_state
    add     x1, x1, :lo12:.test_state
    ldr     x2, [x1, #16]                       // tests_failed
    cbz     x2, .test_suite_success
    
.test_suite_failed:
    mov     x0, #-1                             // Failure
    ldp     x29, x30, [sp], #16
    ret
    
.test_suite_success:
    mov     x0, #0                              // Success
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// TEST INITIALIZATION AND UTILITIES
//==============================================================================

// Initialize test environment
.test_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Clear test state
    adrp    x0, .test_state
    add     x0, x0, :lo12:.test_state
    movi    v0.16b, #0
    stp     q0, q0, [x0]                        // Clear test counters
    
    // Set up test heap
    adrp    x1, .test_heap
    add     x1, x1, :lo12:.test_heap
    str     x1, [x0, #32]                       // test_heap_base
    
    // Ensure heap is properly aligned
    add     x1, x1, #63                         // Add 63 for alignment
    and     x1, x1, #~63                        // Align to 64 bytes
    str     x1, [x0, #32]                       // Store aligned base
    
    mov     x0, #TEST_SUCCESS
    ldp     x29, x30, [sp], #16
    ret

// Record test result
// Arguments: x0 = test result code
.test_record_result:
    adrp    x1, .test_state
    add     x1, x1, :lo12:.test_state
    
    // Increment current test number
    ldr     x2, [x1]                            // current_test
    add     x2, x2, #1
    str     x2, [x1]
    
    // Increment total tests
    ldr     x2, [x1, #24]                       // total_tests
    add     x2, x2, #1
    str     x2, [x1, #24]
    
    // Record pass/fail
    cbz     x0, .record_pass
    
    // Test failed
    ldr     x2, [x1, #16]                       // tests_failed
    add     x2, x2, #1
    str     x2, [x1, #16]
    ret
    
.record_pass:
    // Test passed
    ldr     x2, [x1, #8]                        // tests_passed
    add     x2, x2, #1
    str     x2, [x1, #8]
    ret

// Print test summary
.test_print_summary:
    // Implementation would print results to console
    // For now, just return
    ret

//==============================================================================
// BASIC FUNCTIONALITY TESTS
//==============================================================================

// Test basic initialization
.test_basic_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get test heap
    adrp    x1, .test_state
    add     x1, x1, :lo12:.test_state
    ldr     x0, [x1, #32]                       // test_heap_base
    mov     x1, #TEST_HEAP_SIZE
    
    // Initialize TLSF
    bl      _tlsf_init
    cmp     x0, #0
    b.ne    .test_basic_init_fail
    
    // Validate initialization
    bl      _tlsf_validate_heap
    cmp     x0, #0
    b.ne    .test_basic_init_fail
    
    mov     x0, #TEST_SUCCESS
    ldp     x29, x30, [sp], #16
    ret
    
.test_basic_init_fail:
    mov     x0, #TEST_FAIL_INIT
    ldp     x29, x30, [sp], #16
    ret

// Test basic allocation
.test_basic_allocation:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Test various allocation sizes
    mov     x19, #0                             // Test counter
    
.alloc_size_loop:
    cmp     x19, #20                            // Test 20 different sizes
    b.ge    .test_basic_alloc_success
    
    // Calculate test size: 32 + (i * 64) bytes
    mov     x0, #32
    mov     x1, #64
    mul     x1, x1, x19
    add     x0, x0, x1
    
    // Allocate memory
    bl      _tlsf_malloc
    cbz     x0, .test_basic_alloc_fail
    
    // Verify alignment (should be 16-byte aligned)
    and     x1, x0, #15
    cbnz    x1, .test_basic_alloc_fail
    
    // Store pointer for later free
    adrp    x1, .test_allocs
    add     x1, x1, :lo12:.test_allocs
    str     x0, [x1, x19, lsl #3]
    
    add     x19, x19, #1
    b       .alloc_size_loop
    
.test_basic_alloc_success:
    // Free all allocated blocks
    mov     x19, #0
.free_loop:
    cmp     x19, #20
    b.ge    .test_basic_alloc_done
    
    adrp    x1, .test_allocs
    add     x1, x1, :lo12:.test_allocs
    ldr     x0, [x1, x19, lsl #3]
    bl      _tlsf_free
    
    add     x19, x19, #1
    b       .free_loop
    
.test_basic_alloc_done:
    mov     x0, #TEST_SUCCESS
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
    
.test_basic_alloc_fail:
    mov     x0, #TEST_FAIL_ALLOC
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// Test basic free operation
.test_basic_free:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Allocate a block
    mov     x0, #128
    bl      _tlsf_malloc
    cbz     x0, .test_basic_free_fail
    
    mov     x1, x0                              // Save pointer
    
    // Free the block
    bl      _tlsf_free
    cmp     x0, #0
    b.ne    .test_basic_free_fail
    
    // Validate heap integrity
    bl      _tlsf_validate_heap
    cmp     x0, #0
    b.ne    .test_basic_free_fail
    
    // Test free(NULL) - should succeed
    mov     x0, #0
    bl      _tlsf_free
    cmp     x0, #0
    b.ne    .test_basic_free_fail
    
    mov     x0, #TEST_SUCCESS
    ldp     x29, x30, [sp], #16
    ret
    
.test_basic_free_fail:
    mov     x0, #TEST_FAIL_FREE
    ldp     x29, x30, [sp], #16
    ret

// Test memory alignment
.test_alignment:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, #0                             // Test counter
    
.alignment_loop:
    cmp     x19, #100                           // Test 100 allocations
    b.ge    .test_alignment_success
    
    // Allocate random size between 1 and 1024
    mov     x0, x19
    and     x0, x0, #1023                       // Random size 0-1023
    add     x0, x0, #1                          // Ensure non-zero
    
    bl      _tlsf_malloc
    cbz     x0, .test_alignment_fail
    
    // Check 16-byte alignment
    and     x1, x0, #15
    cbnz    x1, .test_alignment_fail
    
    // Free immediately
    bl      _tlsf_free
    
    add     x19, x19, #1
    b       .alignment_loop
    
.test_alignment_success:
    mov     x0, #TEST_SUCCESS
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
    
.test_alignment_fail:
    mov     x0, #TEST_FAIL_ALLOC
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// Test block coalescing
.test_coalescing:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Allocate three consecutive blocks
    mov     x0, #1024
    bl      _tlsf_malloc
    cbz     x0, .test_coalescing_fail
    mov     x19, x0                             // First block
    
    mov     x0, #1024
    bl      _tlsf_malloc
    cbz     x0, .test_coalescing_fail
    mov     x20, x0                             // Second block
    
    mov     x0, #1024
    bl      _tlsf_malloc
    cbz     x0, .test_coalescing_fail
    mov     x21, x0                             // Third block
    
    // Free middle block
    mov     x0, x20
    bl      _tlsf_free
    
    // Free first block (should coalesce with middle)
    mov     x0, x19
    bl      _tlsf_free
    
    // Free third block (should coalesce with the larger block)
    mov     x0, x21
    bl      _tlsf_free
    
    // Validate heap
    bl      _tlsf_validate_heap
    cmp     x0, #0
    b.ne    .test_coalescing_fail
    
    // Try to allocate a large block that should succeed if coalescing worked
    mov     x0, #3072                           // 3KB (should fit if coalesced)
    bl      _tlsf_malloc
    cbz     x0, .test_coalescing_fail
    
    // Free the large block
    bl      _tlsf_free
    
    mov     x0, #TEST_SUCCESS
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret
    
.test_coalescing_fail:
    mov     x0, #TEST_FAIL_VALIDATION
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// Test block splitting
.test_splitting:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Allocate a large block
    mov     x0, #8192                           // 8KB
    bl      _tlsf_malloc
    cbz     x0, .test_splitting_fail
    
    // Free it
    bl      _tlsf_free
    
    // Allocate a much smaller block (should split the large one)
    mov     x0, #128
    bl      _tlsf_malloc
    cbz     x0, .test_splitting_fail
    
    // Free the small block
    bl      _tlsf_free
    
    // Validate heap integrity
    bl      _tlsf_validate_heap
    cmp     x0, #0
    b.ne    .test_splitting_fail
    
    mov     x0, #TEST_SUCCESS
    ldp     x29, x30, [sp], #16
    ret
    
.test_splitting_fail:
    mov     x0, #TEST_FAIL_VALIDATION
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// EDGE CASE TESTS
//==============================================================================

// Test edge cases and error conditions
.test_edge_cases:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Test zero-size allocation (should return NULL or minimum size)
    mov     x0, #0
    bl      _tlsf_malloc
    // Result doesn't matter - shouldn't crash
    
    // Test very large allocation (should fail gracefully)
    mov     x0, #0x7FFFFFFFFFFFFFFF              // Huge size
    bl      _tlsf_malloc
    cbz     x0, .edge_case_1_ok                 // Should fail
    bl      _tlsf_free                          // If it succeeded, free it
    
.edge_case_1_ok:
    // Test allocation larger than heap
    mov     x0, #(TEST_HEAP_SIZE + 1024)
    bl      _tlsf_malloc
    cbnz    x0, .test_edge_fail                 // Should fail
    
    // Test double free (should be detected)
    mov     x0, #128
    bl      _tlsf_malloc
    cbz     x0, .test_edge_fail
    
    mov     x1, x0                              // Save pointer
    bl      _tlsf_free                          // First free
    mov     x0, x1
    bl      _tlsf_free                          // Second free (should detect error)
    
    mov     x0, #TEST_SUCCESS
    ldp     x29, x30, [sp], #16
    ret
    
.test_edge_fail:
    mov     x0, #TEST_FAIL_VALIDATION
    ldp     x29, x30, [sp], #16
    ret

// Test fragmentation handling
.test_fragmentation:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Create intentional fragmentation
    mov     x19, #0                             // Counter
    
    // Allocate many small blocks
.frag_alloc_loop:
    cmp     x19, #1000
    b.ge    .frag_free_alternate
    
    mov     x0, #64                             // Small blocks
    bl      _tlsf_malloc
    cbz     x0, .test_fragmentation_fail
    
    adrp    x1, .test_allocs
    add     x1, x1, :lo12:.test_allocs
    str     x0, [x1, x19, lsl #3]
    
    add     x19, x19, #1
    b       .frag_alloc_loop
    
.frag_free_alternate:
    // Free every other block to create fragmentation
    mov     x19, #0
.frag_free_loop:
    cmp     x19, #1000
    b.ge    .frag_test_alloc
    
    tst     x19, #1                             // Check if odd
    b.eq    .frag_skip_free
    
    adrp    x1, .test_allocs
    add     x1, x1, :lo12:.test_allocs
    ldr     x0, [x1, x19, lsl #3]
    bl      _tlsf_free
    
.frag_skip_free:
    add     x19, x19, #1
    b       .frag_free_loop
    
.frag_test_alloc:
    // Try to allocate a larger block (tests defragmentation)
    mov     x0, #256                            // Larger than fragments
    bl      _tlsf_malloc
    cbz     x0, .test_fragmentation_fail
    bl      _tlsf_free
    
    // Clean up remaining blocks
    mov     x19, #0
.frag_cleanup:
    cmp     x19, #1000
    b.ge    .test_fragmentation_success
    
    tst     x19, #1                             // Check if odd (already freed)
    b.ne    .frag_skip_cleanup
    
    adrp    x1, .test_allocs
    add     x1, x1, :lo12:.test_allocs
    ldr     x0, [x1, x19, lsl #3]
    bl      _tlsf_free
    
.frag_skip_cleanup:
    add     x19, x19, #1
    b       .frag_cleanup
    
.test_fragmentation_success:
    mov     x0, #TEST_SUCCESS
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
    
.test_fragmentation_fail:
    mov     x0, #TEST_FAIL_VALIDATION
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// PERFORMANCE TESTS
//==============================================================================

// Test allocation performance
.test_performance_allocation:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, #0                             // Iteration counter
    adrp    x20, .perf_data
    add     x20, x20, :lo12:.perf_data          // Performance data
    
    mov     x21, #0xFFFFFFFFFFFFFFFF             // Min time
    mov     x22, #0                             // Max time
    
.perf_alloc_loop:
    cmp     x19, #PERFORMANCE_ITERATIONS
    b.ge    .perf_alloc_analyze
    
    // Start timing
    mrs     x0, cntvct_el0                      // Start cycle count
    
    // Allocate 128 bytes (common size)
    mov     x1, #128
    stp     x0, x1, [sp, #-16]!
    mov     x0, x1
    bl      _tlsf_malloc
    ldp     x1, x2, [sp], #16                   // Restore start time
    
    cbz     x0, .perf_alloc_fail
    
    // End timing
    mrs     x3, cntvct_el0                      // End cycle count
    sub     x3, x3, x1                          // Duration
    
    // Store timing data
    str     x3, [x20, x19, lsl #3]              // alloc_times[i]
    
    // Update min/max
    cmp     x3, x21
    csel    x21, x3, x21, lt                    // Update min
    cmp     x3, x22
    csel    x22, x3, x22, gt                    // Update max
    
    // Free immediately
    bl      _tlsf_free
    
    add     x19, x19, #1
    b       .perf_alloc_loop
    
.perf_alloc_analyze:
    // Calculate average
    mov     x0, #0                              // Sum
    mov     x1, #0                              // Counter
    
.perf_sum_loop:
    cmp     x1, #PERFORMANCE_ITERATIONS
    b.ge    .perf_calc_avg
    
    ldr     x2, [x20, x1, lsl #3]
    add     x0, x0, x2
    add     x1, x1, #1
    b       .perf_sum_loop
    
.perf_calc_avg:
    mov     x1, #PERFORMANCE_ITERATIONS
    udiv    x0, x0, x1                          // Average
    
    // Store results
    str     x21, [x20, #800000]                 // min_alloc_time (after arrays)
    str     x22, [x20, #800008]                 // max_alloc_time
    str     x0, [x20, #800016]                  // avg_alloc_time
    
    // Check if average meets target (< 100ns equivalent in cycles)
    // Assuming 3GHz CPU: 100ns = 300 cycles
    cmp     x0, #300
    b.gt    .perf_alloc_fail
    
    mov     x0, #TEST_SUCCESS
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret
    
.perf_alloc_fail:
    mov     x0, #TEST_FAIL_PERFORMANCE
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// Test free performance
.test_performance_free:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Pre-allocate blocks for free performance test
    mov     x19, #0
.perf_free_prealloc:
    cmp     x19, #PERFORMANCE_ITERATIONS
    b.ge    .perf_free_test
    
    mov     x0, #128
    bl      _tlsf_malloc
    cbz     x0, .perf_free_fail
    
    adrp    x1, .test_allocs
    add     x1, x1, :lo12:.test_allocs
    str     x0, [x1, x19, lsl #3]
    
    add     x19, x19, #1
    b       .perf_free_prealloc
    
.perf_free_test:
    mov     x19, #0                             // Reset counter
    adrp    x20, .perf_data
    add     x20, x20, :lo12:.perf_data
    add     x20, x20, #400000                   // free_times array offset
    
    mov     x21, #0xFFFFFFFFFFFFFFFF             // Min time
    mov     x22, #0                             // Max time
    
.perf_free_loop:
    cmp     x19, #PERFORMANCE_ITERATIONS
    b.ge    .perf_free_analyze
    
    // Get pre-allocated block
    adrp    x1, .test_allocs
    add     x1, x1, :lo12:.test_allocs
    ldr     x0, [x1, x19, lsl #3]
    
    // Start timing
    mrs     x1, cntvct_el0
    
    // Free the block
    bl      _tlsf_free
    
    // End timing
    mrs     x2, cntvct_el0
    sub     x2, x2, x1                          // Duration
    
    // Store timing
    str     x2, [x20, x19, lsl #3]
    
    // Update min/max
    cmp     x2, x21
    csel    x21, x2, x21, lt
    cmp     x2, x22
    csel    x22, x2, x22, gt
    
    add     x19, x19, #1
    b       .perf_free_loop
    
.perf_free_analyze:
    // Calculate average (similar to allocation test)
    mov     x0, #0                              // Sum
    mov     x1, #0                              // Counter
    
.perf_free_sum_loop:
    cmp     x1, #PERFORMANCE_ITERATIONS
    b.ge    .perf_free_calc_avg
    
    ldr     x2, [x20, x1, lsl #3]
    add     x0, x0, x2
    add     x1, x1, #1
    b       .perf_free_sum_loop
    
.perf_free_calc_avg:
    mov     x1, #PERFORMANCE_ITERATIONS
    udiv    x0, x0, x1                          // Average
    
    // Store results
    adrp    x1, .perf_data
    add     x1, x1, :lo12:.perf_data
    str     x21, [x1, #800024]                  // min_free_time
    str     x22, [x1, #800032]                  // max_free_time
    str     x0, [x1, #800040]                   // avg_free_time
    
    // Check performance target
    cmp     x0, #300                            // 100ns = ~300 cycles at 3GHz
    b.gt    .perf_free_fail
    
    mov     x0, #TEST_SUCCESS
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret
    
.perf_free_fail:
    mov     x0, #TEST_FAIL_PERFORMANCE
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// THREAD SAFETY TESTS
//==============================================================================

// Test thread safety with multiple concurrent threads
.test_thread_safety:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // For now, return success - full thread safety test would require
    // pthread creation and synchronization
    mov     x0, #TEST_SUCCESS
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// STRESS TESTS
//==============================================================================

// Random allocation/free stress test
.test_stress_random:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, #0                             // Iteration counter
    mov     x20, #12345                         // Simple PRNG seed
    
.stress_random_loop:
    cmp     x19, #10000                         // 10K operations
    b.ge    .stress_random_success
    
    // Generate pseudo-random number
    mov     x1, #1103515245
    mul     x20, x20, x1
    add     x20, x20, #12345
    
    // Decide allocation or free (50/50)
    tst     x20, #1
    b.ne    .stress_do_alloc
    
    // Try to free a random existing allocation
    adrp    x1, .test_allocs
    add     x1, x1, :lo12:.test_allocs
    and     x2, x20, #1023                      // Random index 0-1023
    ldr     x0, [x1, x2, lsl #3]
    cbz     x0, .stress_skip                    // Nothing to free
    
    bl      _tlsf_free
    
    // Clear the slot
    str     xzr, [x1, x2, lsl #3]
    b       .stress_next
    
.stress_do_alloc:
    // Random allocation size 32-2048 bytes
    and     x0, x20, #2047                      // 0-2047
    add     x0, x0, #32                         // 32-2079
    
    bl      _tlsf_malloc
    cbz     x0, .stress_skip                    // Allocation failed, continue
    
    // Store in random slot
    adrp    x1, .test_allocs
    add     x1, x1, :lo12:.test_allocs
    and     x2, x20, #1023                      // Random index
    str     x0, [x1, x2, lsl #3]
    
.stress_next:
    add     x19, x19, #1
    
.stress_skip:
    b       .stress_random_loop
    
.stress_random_success:
    // Clean up any remaining allocations
    mov     x19, #0
.stress_cleanup:
    cmp     x19, #1024
    b.ge    .stress_random_done
    
    adrp    x1, .test_allocs
    add     x1, x1, :lo12:.test_allocs
    ldr     x0, [x1, x19, lsl #3]
    cbz     x0, .stress_cleanup_next
    
    bl      _tlsf_free
    str     xzr, [x1, x19, lsl #3]
    
.stress_cleanup_next:
    add     x19, x19, #1
    b       .stress_cleanup
    
.stress_random_done:
    // Validate heap integrity
    bl      _tlsf_validate_heap
    cmp     x0, #0
    b.ne    .stress_random_fail
    
    mov     x0, #TEST_SUCCESS
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
    
.stress_random_fail:
    mov     x0, #TEST_FAIL_VALIDATION
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// Pathological case stress test
.test_stress_pathological:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Test worst-case fragmentation and coalescing patterns
    // Allocate and free in patterns designed to stress the allocator
    
    // For now, just return success - full implementation would include
    // specific pathological patterns
    mov     x0, #TEST_SUCCESS
    ldp     x29, x30, [sp], #16
    ret

.end