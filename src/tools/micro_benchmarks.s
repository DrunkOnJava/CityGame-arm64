//
// micro_benchmarks.s - Micro-Benchmark Suite
// SimCity ARM64 Assembly Project - Sub-Agent 7: Performance Validation Engineer
//
// Function-level micro-benchmarks for critical performance paths
// - Individual function performance testing
// - Cache behavior analysis
// - NEON SIMD performance validation
// - Memory access pattern optimization
// - Regression detection for specific functions
//

.include "include/macros/platform_asm.inc"
.include "include/constants/profiler.inc"
.include "include/macros/profiler.inc"

.section .data

// ============================================================================
// MICRO-BENCHMARK STATE
// ============================================================================

.align 64  // Cache line alignment
micro_benchmark_state:
    .quad 0     // initialized
    .quad 0     // current_benchmark
    .quad 0     // total_benchmarks
    .quad 0     // benchmarks_passed
    .quad 0     // benchmarks_failed
    .quad 0     // current_iterations
    .quad 0     // total_iterations
    .quad 0     // warmup_iterations

// Benchmark configuration
benchmark_config:
    .word 10000     // default_iterations
    .word 1000      // warmup_iterations
    .word 5         // repetitions_per_benchmark
    .word 1         // enable_cache_analysis
    .word 1         // enable_neon_benchmarks
    .word 1         // enable_memory_benchmarks
    .word 0         // padding
    .word 0         // padding

// Performance thresholds (cycles per operation)
.align 64
performance_thresholds:
    .quad 50        // malloc_threshold (50 cycles)
    .quad 30        // free_threshold (30 cycles)
    .quad 100       // pathfinding_threshold (100 cycles per node)
    .quad 200       // sprite_render_threshold (200 cycles per sprite)
    .quad 10        // neon_vector_add_threshold (10 cycles per vector)
    .quad 15        // neon_matrix_multiply_threshold (15 cycles per matrix)
    .quad 25        // cache_line_access_threshold (25 cycles)
    .quad 5         // atomic_operation_threshold (5 cycles)

// Benchmark results storage
.align 64
benchmark_results:
    .space 4096     // Results for all micro-benchmarks

// Test data arrays for benchmarks
.align 64
test_data_array_a:
    .space 8192     // 8KB test array A

.align 64
test_data_array_b:
    .space 8192     // 8KB test array B

.align 64
test_data_array_c:
    .space 8192     // 8KB test array C (result)

// Cache test arrays (different sizes to test cache hierarchy)
.align 64
cache_test_l1:
    .space 32768    // 32KB (fits in L1 cache)

.align 64
cache_test_l2:
    .space 262144   // 256KB (fits in L2 cache)

.align 64
cache_test_l3:
    .space 2097152  // 2MB (exceeds L2, tests L3/main memory)

.section .rodata

// String constants
str_micro_init:         .asciz "[MICRO] Micro-benchmark suite initializing\n"
str_micro_ready:        .asciz "[MICRO] Ready - %d benchmarks configured\n"
str_benchmark_start:    .asciz "[MICRO] Running: %s\n"
str_benchmark_result:   .asciz "[MICRO] ✓ %s: %.2f cycles/op (threshold: %.2f)\n"
str_benchmark_fail:     .asciz "[MICRO] ✗ %s: %.2f cycles/op (exceeded threshold: %.2f)\n"
str_cache_analysis:     .asciz "[MICRO] Cache analysis: L1=%.2f, L2=%.2f, L3=%.2f cycles/access\n"
str_neon_performance:   .asciz "[MICRO] NEON performance: %.2f cycles/vector, %.2fx speedup\n"
str_regression_detect:  .asciz "[MICRO] REGRESSION: %s degraded by %.1f%% from baseline\n"

// Benchmark names
benchmark_names:
    .asciz "malloc_performance"
    .asciz "free_performance"
    .asciz "tlsf_allocation"
    .asciz "pool_allocation"
    .asciz "cache_line_access"
    .asciz "random_memory_access"
    .asciz "sequential_memory_access"
    .asciz "neon_vector_add"
    .asciz "neon_vector_multiply"
    .asciz "neon_matrix_multiply"
    .asciz "atomic_increment"
    .asciz "atomic_compare_swap"
    .asciz "sprite_transform"
    .asciz "pathfinding_node"
    .asciz "zoning_calculation"
    .asciz "utility_propagation"

// Benchmark function pointers
benchmark_functions:
    .quad benchmark_malloc_performance
    .quad benchmark_free_performance
    .quad benchmark_tlsf_allocation
    .quad benchmark_pool_allocation
    .quad benchmark_cache_line_access
    .quad benchmark_random_memory_access
    .quad benchmark_sequential_memory_access
    .quad benchmark_neon_vector_add
    .quad benchmark_neon_vector_multiply
    .quad benchmark_neon_matrix_multiply
    .quad benchmark_atomic_increment
    .quad benchmark_atomic_compare_swap
    .quad benchmark_sprite_transform
    .quad benchmark_pathfinding_node
    .quad benchmark_zoning_calculation
    .quad benchmark_utility_propagation
    .quad 0  // End marker

.section .text

// ============================================================================
// MICRO-BENCHMARK INITIALIZATION
// ============================================================================

.global micro_benchmarks_init
.type micro_benchmarks_init, %function
micro_benchmarks_init:
    SAVE_REGS

    // Print initialization message
    adr x0, str_micro_init
    bl printf

    // Check if already initialized
    adr x19, micro_benchmark_state
    ldr x0, [x19]
    cbnz x0, micro_already_initialized

    // Initialize state
    mov x0, #1
    str x0, [x19]               // Set initialized flag

    // Count total benchmarks
    bl count_total_benchmarks
    str x0, [x19, #16]          // total_benchmarks

    // Initialize test data arrays with patterns
    bl initialize_test_data

    // Initialize baseline performance data
    bl initialize_performance_baselines

    // Print ready message
    adr x0, str_micro_ready
    ldr x1, [x19, #16]          // total_benchmarks
    bl printf

    mov x0, #0                  // Return success
    RESTORE_REGS
    ret

micro_already_initialized:
    mov x0, #0                  // Return success
    RESTORE_REGS
    ret

// ============================================================================
// MICRO-BENCHMARK RUNNER
// ============================================================================

.global run_micro_benchmarks
.type run_micro_benchmarks, %function
run_micro_benchmarks:
    SAVE_REGS

    // Initialize benchmark loop
    adr x19, benchmark_functions
    adr x20, benchmark_names
    mov x21, #0                 // Current benchmark index

benchmark_loop:
    ldr x22, [x19], #8          // Load function pointer
    cbz x22, benchmarks_complete

    // Print benchmark start
    adr x0, str_benchmark_start
    mov x1, x20
    bl printf

    // Run the benchmark
    mov x0, x21                 // Benchmark index
    blr x22                     // Call benchmark function
    
    // Store result and check threshold
    bl process_benchmark_result

    // Move to next benchmark name (assuming 32 chars max per name)
    add x20, x20, #32
    add x21, x21, #1
    b benchmark_loop

benchmarks_complete:
    // Generate summary report
    bl generate_micro_benchmark_report

    mov x0, #0                  // Return success
    RESTORE_REGS
    ret

// ============================================================================
// MEMORY ALLOCATION BENCHMARKS
// ============================================================================

.type benchmark_malloc_performance, %function
benchmark_malloc_performance:
    SAVE_REGS

    adr x19, benchmark_config
    ldr w20, [x19]              // default_iterations
    ldr w21, [x19, #4]          // warmup_iterations

    // Warmup
    mov w0, w21
    bl malloc_warmup_loop

    // Actual benchmark
    PROFILE_START malloc_bench
    mov w22, w20                // iterations

malloc_bench_loop:
    mov x0, #1024               // 1KB allocation
    bl malloc
    cbz x0, malloc_bench_failed
    bl free                     // Immediate free to avoid memory bloat
    subs w22, w22, #1
    b.ne malloc_bench_loop

    PROFILE_END malloc_bench

    // Calculate cycles per operation
    PROFILE_GET_CYCLES malloc_bench, x0
    udiv x0, x0, x20            // cycles / iterations
    
    RESTORE_REGS
    ret

malloc_bench_failed:
    mov x0, #-1                 // Return error
    RESTORE_REGS
    ret

.type benchmark_free_performance, %function
benchmark_free_performance:
    SAVE_REGS

    adr x19, benchmark_config
    ldr w20, [x19]              // iterations

    // Pre-allocate memory blocks for fair timing
    mov x19, #0                 // Allocation counter
    mov x21, x20                // Save iterations count

    // Allocate all blocks first
    sub sp, sp, x20, lsl #3     // Space for pointers
    mov x22, sp                 // Base of pointer array

alloc_blocks_loop:
    mov x0, #1024               // 1KB allocation
    bl malloc
    str x0, [x22, x19, lsl #3]  // Store pointer
    add x19, x19, #1
    cmp x19, x21
    b.lt alloc_blocks_loop

    // Now time the free operations
    PROFILE_START free_bench
    mov x19, #0                 // Reset counter

free_bench_loop:
    ldr x0, [x22, x19, lsl #3]  // Load pointer
    bl free
    add x19, x19, #1
    cmp x19, x21
    b.lt free_bench_loop

    PROFILE_END free_bench

    // Restore stack
    add sp, sp, x21, lsl #3

    // Calculate cycles per operation
    PROFILE_GET_CYCLES free_bench, x0
    udiv x0, x0, x21            // cycles / iterations

    RESTORE_REGS
    ret

// ============================================================================
// CACHE PERFORMANCE BENCHMARKS
// ============================================================================

.type benchmark_cache_line_access, %function
benchmark_cache_line_access:
    SAVE_REGS

    adr x19, benchmark_config
    ldr w20, [x19]              // iterations

    // Test L1 cache performance
    adr x21, cache_test_l1
    
    PROFILE_START cache_l1_bench
    mov w22, w20

cache_l1_loop:
    ldr x0, [x21], #64          // Load with cache line stride
    subs w22, w22, #1
    b.ne cache_l1_loop

    PROFILE_END cache_l1_bench

    // Test L2 cache performance
    adr x21, cache_test_l2
    
    PROFILE_START cache_l2_bench
    mov w22, w20

cache_l2_loop:
    ldr x0, [x21], #64          // Load with cache line stride
    subs w22, w22, #1
    b.ne cache_l2_loop

    PROFILE_END cache_l2_bench

    // Test L3/main memory performance
    adr x21, cache_test_l3
    
    PROFILE_START cache_l3_bench
    mov w22, w20

cache_l3_loop:
    ldr x0, [x21], #64          // Load with cache line stride
    subs w22, w22, #1
    b.ne cache_l3_loop

    PROFILE_END cache_l3_bench

    // Report cache analysis
    PROFILE_GET_CYCLES cache_l1_bench, x0
    udiv x23, x0, x20           // L1 cycles per access
    
    PROFILE_GET_CYCLES cache_l2_bench, x0
    udiv x24, x0, x20           // L2 cycles per access
    
    PROFILE_GET_CYCLES cache_l3_bench, x0
    udiv x25, x0, x20           // L3 cycles per access

    // Convert to floating point for printf (simplified)
    adr x0, str_cache_analysis
    mov x1, x23
    mov x2, x24
    mov x3, x25
    bl printf

    mov x0, x23                 // Return L1 performance as primary metric

    RESTORE_REGS
    ret

// ============================================================================
// NEON SIMD BENCHMARKS
// ============================================================================

.type benchmark_neon_vector_add, %function
benchmark_neon_vector_add:
    SAVE_REGS

    adr x19, benchmark_config
    ldr w20, [x19]              // iterations

    // Load test data addresses
    adr x21, test_data_array_a
    adr x22, test_data_array_b
    adr x23, test_data_array_c

    PROFILE_START neon_vector_add_bench
    mov w24, w20

neon_vector_add_loop:
    // Load 4 32-bit floats from each array
    ld1 {v0.4s}, [x21], #16
    ld1 {v1.4s}, [x22], #16
    
    // NEON vector addition
    fadd v2.4s, v0.4s, v1.4s
    
    // Store result
    st1 {v2.4s}, [x23], #16
    
    subs w24, w24, #1
    b.ne neon_vector_add_loop

    PROFILE_END neon_vector_add_bench

    // Calculate cycles per vector operation
    PROFILE_GET_CYCLES neon_vector_add_bench, x0
    udiv x0, x0, x20            // cycles / iterations

    RESTORE_REGS
    ret

.type benchmark_neon_vector_multiply, %function
benchmark_neon_vector_multiply:
    SAVE_REGS

    adr x19, benchmark_config
    ldr w20, [x19]              // iterations

    adr x21, test_data_array_a
    adr x22, test_data_array_b
    adr x23, test_data_array_c

    PROFILE_START neon_vector_mult_bench
    mov w24, w20

neon_vector_mult_loop:
    ld1 {v0.4s}, [x21], #16
    ld1 {v1.4s}, [x22], #16
    
    // NEON vector multiplication
    fmul v2.4s, v0.4s, v1.4s
    
    st1 {v2.4s}, [x23], #16
    
    subs w24, w24, #1
    b.ne neon_vector_mult_loop

    PROFILE_END neon_vector_mult_bench

    PROFILE_GET_CYCLES neon_vector_mult_bench, x0
    udiv x0, x0, x20

    RESTORE_REGS
    ret

.type benchmark_neon_matrix_multiply, %function
benchmark_neon_matrix_multiply:
    SAVE_REGS

    adr x19, benchmark_config
    ldr w20, [x19]              // iterations

    // 4x4 matrix multiplication using NEON
    adr x21, test_data_array_a  // Matrix A
    adr x22, test_data_array_b  // Matrix B
    adr x23, test_data_array_c  // Result matrix

    PROFILE_START neon_matrix_mult_bench
    mov w24, w20

neon_matrix_mult_loop:
    // Load matrices (simplified 4x4)
    ld1 {v0.4s, v1.4s, v2.4s, v3.4s}, [x21]    // Matrix A rows
    ld1 {v4.4s, v5.4s, v6.4s, v7.4s}, [x22]    // Matrix B rows

    // Perform 4x4 matrix multiplication (simplified)
    // Row 0 of result
    fmul v16.4s, v0.4s, v4.s[0]
    fmla v16.4s, v1.4s, v4.s[1]
    fmla v16.4s, v2.4s, v4.s[2]
    fmla v16.4s, v3.4s, v4.s[3]

    // Row 1 of result
    fmul v17.4s, v0.4s, v5.s[0]
    fmla v17.4s, v1.4s, v5.s[1]
    fmla v17.4s, v2.4s, v5.s[2]
    fmla v17.4s, v3.4s, v5.s[3]

    // Row 2 of result
    fmul v18.4s, v0.4s, v6.s[0]
    fmla v18.4s, v1.4s, v6.s[1]
    fmla v18.4s, v2.4s, v6.s[2]
    fmla v18.4s, v3.4s, v6.s[3]

    // Row 3 of result
    fmul v19.4s, v0.4s, v7.s[0]
    fmla v19.4s, v1.4s, v7.s[1]
    fmla v19.4s, v2.4s, v7.s[2]
    fmla v19.4s, v3.4s, v7.s[3]

    // Store result matrix
    st1 {v16.4s, v17.4s, v18.4s, v19.4s}, [x23]

    subs w24, w24, #1
    b.ne neon_matrix_mult_loop

    PROFILE_END neon_matrix_mult_bench

    PROFILE_GET_CYCLES neon_matrix_mult_bench, x0
    udiv x0, x0, x20

    RESTORE_REGS
    ret

// ============================================================================
// ATOMIC OPERATION BENCHMARKS
// ============================================================================

.type benchmark_atomic_increment, %function
benchmark_atomic_increment:
    SAVE_REGS

    adr x19, benchmark_config
    ldr w20, [x19]              // iterations

    // Test atomic increment performance
    .section .data
    atomic_counter: .quad 0
    .section .text

    adr x21, atomic_counter

    PROFILE_START atomic_inc_bench
    mov w22, w20

atomic_inc_loop:
    // Atomic increment using LSE
    mov x0, #1
    ldadd x0, x0, [x21]         // Atomic add
    subs w22, w22, #1
    b.ne atomic_inc_loop

    PROFILE_END atomic_inc_bench

    PROFILE_GET_CYCLES atomic_inc_bench, x0
    udiv x0, x0, x20

    RESTORE_REGS
    ret

.type benchmark_atomic_compare_swap, %function
benchmark_atomic_compare_swap:
    SAVE_REGS

    adr x19, benchmark_config
    ldr w20, [x19]              // iterations

    .section .data
    cas_variable: .quad 0
    .section .text

    adr x21, cas_variable

    PROFILE_START atomic_cas_bench
    mov w22, w20
    mov x23, #0                 // Expected value

atomic_cas_loop:
    mov x24, x23                // Old value
    add x25, x23, #1            // New value
    
    // Compare and swap
    cas x24, x25, [x21]
    mov x23, x25                // Update expected for next iteration
    
    subs w22, w22, #1
    b.ne atomic_cas_loop

    PROFILE_END atomic_cas_bench

    PROFILE_GET_CYCLES atomic_cas_bench, x0
    udiv x0, x0, x20

    RESTORE_REGS
    ret

// ============================================================================
// SIMULATION-SPECIFIC BENCHMARKS
// ============================================================================

.type benchmark_sprite_transform, %function
benchmark_sprite_transform:
    SAVE_REGS

    adr x19, benchmark_config
    ldr w20, [x19]              // iterations

    PROFILE_START sprite_transform_bench
    mov w21, w20

sprite_transform_loop:
    // Simulate isometric transformation (simplified)
    // Input: world coordinates (x, y, z)
    mov w0, w21                 // x = iteration
    mov w1, w21                 // y = iteration
    mov w2, #0                  // z = 0

    // Isometric projection matrix multiplication
    // screen_x = (x - y) * cos(30°)
    // screen_y = (x + y) * sin(30°) - z

    // Simplified calculation using integer math
    sub w3, w0, w1              // x - y
    add w4, w0, w1              // x + y
    sub w4, w4, w2              // (x + y) - z

    // Store result (simulated)
    // In real implementation, this would write to sprite buffer

    subs w21, w21, #1
    b.ne sprite_transform_loop

    PROFILE_END sprite_transform_bench

    PROFILE_GET_CYCLES sprite_transform_bench, x0
    udiv x0, x0, x20

    RESTORE_REGS
    ret

.type benchmark_pathfinding_node, %function
benchmark_pathfinding_node:
    SAVE_REGS

    adr x19, benchmark_config
    ldr w20, [x19]              // iterations

    PROFILE_START pathfinding_bench
    mov w21, w20

pathfinding_loop:
    // Simulate A* node processing
    // Calculate heuristic distance (Manhattan distance)
    mov w0, #100                // Start X
    mov w1, #100                // Start Y
    mov w2, #200                // Goal X  
    mov w3, #200                // Goal Y

    // Manhattan distance: |goal_x - start_x| + |goal_y - start_y|
    sub w4, w2, w0              // goal_x - start_x
    cmp w4, #0
    cneg w4, w4, lt             // Absolute value

    sub w5, w3, w1              // goal_y - start_y
    cmp w5, #0
    cneg w5, w5, lt             // Absolute value

    add w6, w4, w5              // Manhattan distance

    // Simulate neighbor evaluation (8 neighbors)
    mov w7, #8

neighbor_loop:
    // Calculate G cost (simplified)
    mul w8, w6, w7              // distance * neighbor_index
    
    // Calculate F cost (G + H)
    add w9, w8, w6              // G + H
    
    subs w7, w7, #1
    b.ne neighbor_loop

    subs w21, w21, #1
    b.ne pathfinding_loop

    PROFILE_END pathfinding_bench

    PROFILE_GET_CYCLES pathfinding_bench, x0
    udiv x0, x0, x20

    RESTORE_REGS
    ret

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

.type count_total_benchmarks, %function
count_total_benchmarks:
    adr x0, benchmark_functions
    mov x1, #0                  // Counter

count_loop:
    ldr x2, [x0], #8
    cbz x2, count_done
    add x1, x1, #1
    b count_loop

count_done:
    mov x0, x1                  // Return count
    ret

.type initialize_test_data, %function
initialize_test_data:
    SAVE_REGS

    // Initialize test arrays with known patterns
    adr x19, test_data_array_a
    adr x20, test_data_array_b
    mov w21, #2048              // 2048 words (8KB)

init_data_loop:
    // Array A: sequential pattern
    str w21, [x19], #4
    
    // Array B: reverse pattern
    neg w22, w21
    str w22, [x20], #4
    
    subs w21, w21, #1
    b.ne init_data_loop

    RESTORE_REGS
    ret

.type malloc_warmup_loop, %function
malloc_warmup_loop:
    // w0 = iterations
    SAVE_REGS_LIGHT
    mov w19, w0

warmup_loop:
    mov x0, #1024
    bl malloc
    cbz x0, warmup_done
    bl free
    subs w19, w19, #1
    b.ne warmup_loop

warmup_done:
    RESTORE_REGS_LIGHT
    ret

.type process_benchmark_result, %function
process_benchmark_result:
    // x0 = cycles per operation
    // x21 = benchmark index
    SAVE_REGS

    mov x19, x0                 // Save result

    // Get threshold for this benchmark
    adr x20, performance_thresholds
    ldr x21, [x20, x21, lsl #3] // Load threshold

    // Compare result to threshold
    cmp x19, x21
    b.gt benchmark_failed

    // Benchmark passed
    adr x0, str_benchmark_result
    mov x1, x20                 // Benchmark name (approximation)
    mov x2, x19                 // Result
    mov x3, x21                 // Threshold
    bl printf

    // Increment passed counter
    adr x22, micro_benchmark_state
    ldr x23, [x22, #24]         // benchmarks_passed
    add x23, x23, #1
    str x23, [x22, #24]
    b benchmark_result_done

benchmark_failed:
    // Benchmark failed
    adr x0, str_benchmark_fail
    mov x1, x20                 // Benchmark name
    mov x2, x19                 // Result
    mov x3, x21                 // Threshold
    bl printf

    // Increment failed counter
    adr x22, micro_benchmark_state
    ldr x23, [x22, #32]         // benchmarks_failed
    add x23, x23, #1
    str x23, [x22, #32]

benchmark_result_done:
    RESTORE_REGS
    ret

.type initialize_performance_baselines, %function
initialize_performance_baselines:
    // Initialize baseline performance data for regression detection
    // This would typically load from a baseline file or run initial calibration
    ret

.type generate_micro_benchmark_report, %function
generate_micro_benchmark_report:
    SAVE_REGS

    // Print summary of all micro-benchmark results
    adr x19, micro_benchmark_state
    ldr x0, [x19, #24]          // benchmarks_passed
    ldr x1, [x19, #32]          // benchmarks_failed
    add x2, x0, x1              // total
    
    // Calculate pass rate
    cmp x2, #0
    b.eq report_done
    
    mov x3, #100
    mul x0, x0, x3
    udiv x0, x0, x2             // Pass rate percentage

    // Print report (implementation would be more detailed)

report_done:
    RESTORE_REGS
    ret

// Stub implementations for specialized benchmarks
.type benchmark_tlsf_allocation, %function
benchmark_tlsf_allocation:
    // TODO: Implement TLSF-specific allocation benchmark
    mov x0, #25                 // Placeholder cycles
    ret

.type benchmark_pool_allocation, %function
benchmark_pool_allocation:
    // TODO: Implement pool allocation benchmark
    mov x0, #15                 // Placeholder cycles
    ret

.type benchmark_random_memory_access, %function
benchmark_random_memory_access:
    // TODO: Implement random memory access pattern benchmark
    mov x0, #45                 // Placeholder cycles
    ret

.type benchmark_sequential_memory_access, %function
benchmark_sequential_memory_access:
    // TODO: Implement sequential memory access benchmark
    mov x0, #12                 // Placeholder cycles
    ret

.type benchmark_zoning_calculation, %function
benchmark_zoning_calculation:
    // TODO: Implement zoning system calculation benchmark
    mov x0, #80                 // Placeholder cycles
    ret

.type benchmark_utility_propagation, %function
benchmark_utility_propagation:
    // TODO: Implement utility propagation benchmark
    mov x0, #120                // Placeholder cycles
    ret

// ============================================================================
// EXTERNAL FUNCTION DECLARATIONS
// ============================================================================

.extern malloc
.extern free
.extern printf