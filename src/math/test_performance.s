// SimCity ARM64 Math Library - Performance Tests
// Agent 1: Core Engine Developer
// Comprehensive benchmarking and validation for 1M+ agent simulation

.cpu generic+simd
.arch armv8-a+simd

// Include platform constants
.include "../include/constants/platform_constants.h"
.include "../include/macros/platform_asm.inc"

.section .data
.align 4

// Test configuration
.test_config:
    .agent_counts:      .quad   1000, 10000, 100000, 1000000
    .iteration_counts:  .quad   100, 50, 10, 1
    .warm_up_iters:     .quad   10
    .tolerance:         .float  0.001

// Test results storage
.test_results:
    .vector_neon_time:      .quad   0
    .vector_scalar_time:    .quad   0
    .matrix_neon_time:      .quad   0
    .matrix_scalar_time:    .quad   0
    .fastmath_time:         .quad   0
    .stdlib_time:           .quad   0
    .agent_batch_time:      .quad   0
    .agent_single_time:     .quad   0

// Performance targets (nanoseconds)
.performance_targets:
    .vector_add_target:     .quad   50      // 50ns target for vector add
    .matrix_mul_target:     .quad   100     // 100ns target for 4x4 matrix multiply
    .agent_update_target:   .quad   80      // 80ns target per agent update
    .math_func_target:      .quad   20      // 20ns target for fast math functions

// Test data arrays
.align 6
.test_vectors_a:        .space  4096       // 512 vec2 structures
.test_vectors_b:        .space  4096
.test_vectors_result:   .space  4096
.test_matrices_a:       .space  1024       // 16 4x4 matrices
.test_matrices_b:       .space  1024
.test_matrices_result:  .space  1024
.test_agents:           .space  32768      // 256 agent structures

.section .text
.align 4

//==============================================================================
// Main Test Entry Point
//==============================================================================

.global main
main:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Print test header
    adrp    x0, test_header_msg
    add     x0, x0, :lo12:test_header_msg
    bl      printf
    
    // Initialize test data
    bl      init_test_data
    
    // Run vector operation tests
    bl      test_vector_operations
    
    // Run matrix operation tests
    bl      test_matrix_operations
    
    // Run fast math tests
    bl      test_fast_math_functions
    
    // Run agent math tests
    bl      test_agent_math_operations
    
    // Run scaling tests (1K to 1M agents)
    bl      test_scaling_performance
    
    // Generate performance report
    bl      generate_performance_report
    
    // Validate against performance targets
    bl      validate_performance_targets
    
    mov     x0, #0                      // Exit success
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Test Data Initialization
//==============================================================================

init_test_data:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Initialize random number generator with fixed seed for reproducibility
    mov     x0, #12345
    bl      rng_init
    
    // Initialize test vectors with random data
    adrp    x0, .test_vectors_a
    add     x0, x0, :lo12:.test_vectors_a
    mov     x1, #512                    // 512 vec2 structures
    bl      init_random_vectors
    
    adrp    x0, .test_vectors_b
    add     x0, x0, :lo12:.test_vectors_b
    mov     x1, #512
    bl      init_random_vectors
    
    // Initialize test matrices with random data
    adrp    x0, .test_matrices_a
    add     x0, x0, :lo12:.test_matrices_a
    mov     x1, #16                     // 16 4x4 matrices
    bl      init_random_matrices
    
    adrp    x0, .test_matrices_b
    add     x0, x0, :lo12:.test_matrices_b
    mov     x1, #16
    bl      init_random_matrices
    
    // Initialize test agents with random data
    adrp    x0, .test_agents
    add     x0, x0, :lo12:.test_agents
    mov     x1, #256                    // 256 agent structures
    bl      init_random_agents
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Vector Operations Performance Tests
//==============================================================================

test_vector_operations:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    adrp    x0, vector_test_msg
    add     x0, x0, :lo12:vector_test_msg
    bl      printf
    
    // Test NEON batch vector operations
    mov     x19, #10000                 // Iterations
    adrp    x0, .test_vectors_a
    add     x0, x0, :lo12:.test_vectors_a
    adrp    x1, .test_vectors_b
    add     x1, x1, :lo12:.test_vectors_b
    adrp    x2, .test_vectors_result
    add     x2, x2, :lo12:.test_vectors_result
    
    // Warm up
    mov     x20, #10
warmup_vector_neon:
    bl      vec2_add_batch
    subs    x20, x20, #1
    b.ne    warmup_vector_neon
    
    // Time NEON batch operations
    mrs     x20, cntvct_el0             // Start time
    
    mov     x3, x19
vector_neon_loop:
    bl      vec2_add_batch
    subs    x3, x3, #1
    b.ne    vector_neon_loop
    
    mrs     x1, cntvct_el0              // End time
    sub     x20, x1, x20                // NEON time
    
    // Time scalar operations for comparison
    mrs     x21, cntvct_el0             // Start time
    
    mov     x3, x19
vector_scalar_loop:
    mov     x4, #512                    // Vector count
    mov     x5, x0                      // Reset pointers
    mov     x6, x1
    mov     x7, x2
    
scalar_inner_loop:
    bl      vec2_add
    add     x5, x5, #8                  // Next vec2_a
    add     x6, x6, #8                  // Next vec2_b
    add     x7, x7, #8                  // Next result
    subs    x4, x4, #1
    b.ne    scalar_inner_loop
    
    subs    x3, x3, #1
    b.ne    vector_scalar_loop
    
    mrs     x1, cntvct_el0              // End time
    sub     x21, x1, x21                // Scalar time
    
    // Store results
    adrp    x0, .test_results
    add     x0, x0, :lo12:.test_results
    str     x20, [x0]                   // NEON time
    str     x21, [x0, #8]               // Scalar time
    
    // Calculate and print speedup
    ucvtf   d0, x20                     // NEON time as float
    ucvtf   d1, x21                     // Scalar time as float
    fdiv    d2, d1, d0                  // Speedup = scalar/neon
    
    adrp    x0, vector_speedup_msg
    add     x0, x0, :lo12:vector_speedup_msg
    bl      printf
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Matrix Operations Performance Tests
//==============================================================================

test_matrix_operations:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    adrp    x0, matrix_test_msg
    add     x0, x0, :lo12:matrix_test_msg
    bl      printf
    
    // Test 4x4 matrix multiplication performance
    mov     x19, #1000                  // Iterations
    adrp    x0, .test_matrices_a
    add     x0, x0, :lo12:.test_matrices_a
    adrp    x1, .test_matrices_b
    add     x1, x1, :lo12:.test_matrices_b
    adrp    x2, .test_matrices_result
    add     x2, x2, :lo12:.test_matrices_result
    
    // Time NEON-optimized matrix multiplication
    mrs     x20, cntvct_el0             // Start time
    
    mov     x3, x19
matrix_neon_loop:
    mov     x4, #16                     // Matrix count
    mov     x5, x0                      // Reset pointers
    mov     x6, x1
    mov     x7, x2
    
matrix_mul_loop:
    stp     x0, x1, [sp, #-16]!
    stp     x2, x3, [sp, #-16]!
    stp     x4, x5, [sp, #-16]!
    stp     x6, x7, [sp, #-16]!
    
    mov     x0, x7                      // result
    mov     x1, x5                      // matrix_a
    mov     x2, x6                      // matrix_b
    bl      mat4_multiply
    
    ldp     x6, x7, [sp], #16
    ldp     x4, x5, [sp], #16
    ldp     x2, x3, [sp], #16
    ldp     x0, x1, [sp], #16
    
    add     x5, x5, #64                 // Next matrix_a
    add     x6, x6, #64                 // Next matrix_b
    add     x7, x7, #64                 // Next result
    subs    x4, x4, #1
    b.ne    matrix_mul_loop
    
    subs    x3, x3, #1
    b.ne    matrix_neon_loop
    
    mrs     x1, cntvct_el0              // End time
    sub     x20, x1, x20                // Matrix time
    
    // Store result
    adrp    x0, .test_results
    add     x0, x0, :lo12:.test_results
    str     x20, [x0, #16]              // Matrix NEON time
    
    // Calculate average time per matrix multiply
    udiv    x1, x20, x19                // Total time / iterations
    mov     x2, #16                     // Matrices per iteration
    udiv    x1, x1, x2                  // Time per matrix
    
    adrp    x0, matrix_time_msg
    add     x0, x0, :lo12:matrix_time_msg
    bl      printf
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Fast Math Functions Performance Tests
//==============================================================================

test_fast_math_functions:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    adrp    x0, fastmath_test_msg
    add     x0, x0, :lo12:fastmath_test_msg
    bl      printf
    
    // Test fast trigonometric functions
    mov     x19, #100000                // Iterations
    
    // Test fast_sin performance
    mrs     x20, cntvct_el0             // Start time
    
    mov     x1, x19
    fmov    s0, #1.0                    // Test angle
fastsin_loop:
    bl      fast_sin
    subs    x1, x1, #1
    b.ne    fastsin_loop
    
    mrs     x1, cntvct_el0              // End time
    sub     x20, x1, x20                // Fast sin time
    
    // Test standard sinf for comparison
    mrs     x21, cntvct_el0             // Start time
    
    mov     x1, x19
    fmov    s0, #1.0                    // Test angle
stdsin_loop:
    bl      sinf
    subs    x1, x1, #1
    b.ne    stdsin_loop
    
    mrs     x1, cntvct_el0              // End time
    sub     x21, x1, x21                // Standard sin time
    
    // Store results
    adrp    x0, .test_results
    add     x0, x0, :lo12:.test_results
    str     x20, [x0, #32]              // Fast math time
    str     x21, [x0, #40]              // Standard math time
    
    // Calculate speedup
    ucvtf   d0, x20
    ucvtf   d1, x21
    fdiv    d2, d1, d0
    
    adrp    x0, fastmath_speedup_msg
    add     x0, x0, :lo12:fastmath_speedup_msg
    bl      printf
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Agent Math Operations Performance Tests
//==============================================================================

test_agent_math_operations:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    adrp    x0, agent_test_msg
    add     x0, x0, :lo12:agent_test_msg
    bl      printf
    
    // Test agent physics update performance
    mov     x19, #10000                 // Iterations
    adrp    x0, .test_agents
    add     x0, x0, :lo12:.test_agents
    mov     x1, #256                    // Agent count
    fmov    s0, #0.016                  // Delta time (60 FPS)
    
    // Time batch agent updates
    mrs     x20, cntvct_el0             // Start time
    
    mov     x2, x19
agent_batch_loop:
    bl      agent_update_physics_batch
    subs    x2, x2, #1
    b.ne    agent_batch_loop
    
    mrs     x1, cntvct_el0              // End time
    sub     x20, x1, x20                // Batch time
    
    // Store result
    adrp    x0, .test_results
    add     x0, x0, :lo12:.test_results
    str     x20, [x0, #48]              // Agent batch time
    
    // Calculate time per agent update
    mov     x2, #256                    // Agents per iteration
    mul     x3, x2, x19                 // Total agent updates
    udiv    x1, x20, x3                 // Time per agent
    
    adrp    x0, agent_time_msg
    add     x0, x0, :lo12:agent_time_msg
    bl      printf
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Scaling Performance Tests (1K to 1M agents)
//==============================================================================

test_scaling_performance:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    adrp    x0, scaling_test_msg
    add     x0, x0, :lo12:scaling_test_msg
    bl      printf
    
    // Test different agent counts
    adrp    x19, .test_config
    add     x19, x19, :lo12:.test_config
    
    mov     x20, #0                     // Test index
scaling_loop:
    cmp     x20, #4                     // 4 test configurations
    b.ge    scaling_done
    
    // Load test configuration
    ldr     x1, [x19, x20, lsl #3]      // agent_count
    add     x2, x19, #32                // iteration_counts array
    ldr     x2, [x2, x20, lsl #3]       // iterations for this test
    
    // Allocate memory for agents
    mov     x0, #128                    // Agent size
    mul     x0, x0, x1                  // Total memory needed
    bl      malloc
    cbz     x0, scaling_next
    
    mov     x3, x0                      // Save agent array
    
    // Run performance test
    fmov    s0, #0.016                  // Delta time
    
    mrs     x4, cntvct_el0              // Start time
    
    mov     x5, x2                      // Iteration counter
scaling_inner_loop:
    mov     x0, x3                      // agent_array
    // Note: x1 already has agent_count
    bl      agent_update_physics_batch
    subs    x5, x5, #1
    b.ne    scaling_inner_loop
    
    mrs     x5, cntvct_el0              // End time
    sub     x4, x5, x4                  // Total time
    
    // Calculate average time per agent
    mul     x5, x1, x2                  // Total agent updates
    udiv    x4, x4, x5                  // Time per agent update
    
    // Print results
    adrp    x0, scaling_result_msg
    add     x0, x0, :lo12:scaling_result_msg
    // x1 already has agent_count
    mov     x2, x4                      // time_per_agent
    bl      printf
    
    // Free agent array
    mov     x0, x3
    bl      free

scaling_next:
    add     x20, x20, #1
    b       scaling_loop

scaling_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Performance Report Generation
//==============================================================================

generate_performance_report:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, report_header_msg
    add     x0, x0, :lo12:report_header_msg
    bl      printf
    
    // Load test results
    adrp    x19, .test_results
    add     x19, x19, :lo12:.test_results
    
    // Vector operations report
    ldr     x1, [x19]                   // NEON time
    ldr     x2, [x19, #8]               // Scalar time
    ucvtf   d0, x1
    ucvtf   d1, x2
    fdiv    d2, d1, d0                  // Speedup
    adrp    x0, vector_report_msg
    add     x0, x0, :lo12:vector_report_msg
    bl      printf
    
    // Matrix operations report
    ldr     x1, [x19, #16]              // Matrix time
    adrp    x0, matrix_report_msg
    add     x0, x0, :lo12:matrix_report_msg
    bl      printf
    
    // Fast math report
    ldr     x1, [x19, #32]              // Fast math time
    ldr     x2, [x19, #40]              // Standard math time
    ucvtf   d0, x1
    ucvtf   d1, x2
    fdiv    d2, d1, d0                  // Speedup
    adrp    x0, fastmath_report_msg
    add     x0, x0, :lo12:fastmath_report_msg
    bl      printf
    
    // Agent math report
    ldr     x1, [x19, #48]              // Agent batch time
    adrp    x0, agent_report_msg
    add     x0, x0, :lo12:agent_report_msg
    bl      printf
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Performance Target Validation
//==============================================================================

validate_performance_targets:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, validation_header_msg
    add     x0, x0, :lo12:validation_header_msg
    bl      printf
    
    // Load test results and targets
    adrp    x19, .test_results
    add     x19, x19, :lo12:.test_results
    adrp    x20, .performance_targets
    add     x20, x20, :lo12:.performance_targets
    
    mov     x21, #0                     // Pass counter
    mov     x22, #0                     // Test counter
    
    // Validate vector operations (time per operation)
    ldr     x1, [x19]                   // NEON time
    mov     x2, #10000                  // Iterations
    mov     x3, #512                    // Operations per iteration
    mul     x2, x2, x3
    udiv    x1, x1, x2                  // Time per operation
    ldr     x2, [x20]                   // Target time
    cmp     x1, x2
    b.gt    vector_target_fail
    add     x21, x21, #1                // Pass
vector_target_fail:
    add     x22, x22, #1                // Total tests
    
    adrp    x0, vector_target_msg
    add     x0, x0, :lo12:vector_target_msg
    mov     x3, x2                      // target
    bl      printf
    
    // Print final validation results
    adrp    x0, validation_summary_msg
    add     x0, x0, :lo12:validation_summary_msg
    mov     x1, x21                     // Passed
    mov     x2, x22                     // Total
    bl      printf
    
    // Return exit code based on results
    cmp     x21, x22
    cset    x0, eq                      // 0 if all passed, 1 if any failed
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Helper Functions
//==============================================================================

init_random_vectors:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     x2, #0                      // Counter
init_vec_loop:
    cmp     x2, x1
    b.ge    init_vec_done
    
    bl      rng_uniform_float
    str     s0, [x0, x2, lsl #3]        // x component
    bl      rng_uniform_float
    str     s0, [x0, x2, lsl #3, #4]    // y component
    
    add     x2, x2, #1
    b       init_vec_loop

init_vec_done:
    ldp     x29, x30, [sp], #16
    ret

init_random_matrices:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     x2, #0                      // Matrix counter
init_mat_loop:
    cmp     x2, x1
    b.ge    init_mat_done
    
    // Initialize each matrix element
    mov     x3, #0                      // Element counter
init_elem_loop:
    cmp     x3, #16                     // 16 elements per matrix
    b.ge    next_matrix
    
    bl      rng_uniform_float
    lsl     x4, x2, #6                  // Matrix offset (64 bytes)
    lsl     x5, x3, #2                  // Element offset (4 bytes)
    add     x4, x4, x5
    str     s0, [x0, x4]
    
    add     x3, x3, #1
    b       init_elem_loop

next_matrix:
    add     x2, x2, #1
    b       init_mat_loop

init_mat_done:
    ldp     x29, x30, [sp], #16
    ret

init_random_agents:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     x2, #0                      // Agent counter
init_agent_loop:
    cmp     x2, x1
    b.ge    init_agent_done
    
    lsl     x3, x2, #7                  // Agent offset (128 bytes)
    add     x3, x0, x3                  // Agent address
    
    // Initialize position
    bl      rng_uniform_float
    str     s0, [x3]                    // pos_x
    bl      rng_uniform_float
    str     s0, [x3, #4]                // pos_y
    
    // Initialize velocity
    bl      rng_uniform_float
    str     s0, [x3, #8]                // vel_x
    bl      rng_uniform_float
    str     s0, [x3, #12]               // vel_y
    
    // Initialize forces
    bl      rng_uniform_float
    str     s0, [x3, #16]               // force_x
    bl      rng_uniform_float
    str     s0, [x3, #20]               // force_y
    
    // Initialize mass and radius
    fmov    s0, #70.0                   // Default mass
    str     s0, [x3, #24]
    fmov    s0, #0.5                    // Default radius
    str     s0, [x3, #28]
    
    add     x2, x2, #1
    b       init_agent_loop

init_agent_done:
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// String Constants
//==============================================================================

.section .rodata
.align 3

test_header_msg:
    .asciz "=== SimCity ARM64 Math Library Performance Tests ===\n"

vector_test_msg:
    .asciz "Testing vector operations (NEON vs Scalar)...\n"

vector_speedup_msg:
    .asciz "Vector NEON speedup: %.2fx\n"

matrix_test_msg:
    .asciz "Testing matrix operations...\n"

matrix_time_msg:
    .asciz "Matrix multiplication time: %llu cycles\n"

fastmath_test_msg:
    .asciz "Testing fast math functions...\n"

fastmath_speedup_msg:
    .asciz "Fast math speedup: %.2fx\n"

agent_test_msg:
    .asciz "Testing agent math operations...\n"

agent_time_msg:
    .asciz "Agent update time: %llu cycles per agent\n"

scaling_test_msg:
    .asciz "Testing scaling performance (1K to 1M agents)...\n"

scaling_result_msg:
    .asciz "Agents: %llu, Time per agent: %llu cycles\n"

report_header_msg:
    .asciz "\n=== Performance Report ===\n"

vector_report_msg:
    .asciz "Vector ops - NEON: %llu cycles, Scalar: %llu cycles, Speedup: %.2fx\n"

matrix_report_msg:
    .asciz "Matrix ops - Total time: %llu cycles\n"

fastmath_report_msg:
    .asciz "Fast math - Fast: %llu cycles, Standard: %llu cycles, Speedup: %.2fx\n"

agent_report_msg:
    .asciz "Agent math - Batch time: %llu cycles\n"

validation_header_msg:
    .asciz "\n=== Performance Target Validation ===\n"

vector_target_msg:
    .asciz "Vector operations: %llu cycles (target: %llu) - %s\n"

validation_summary_msg:
    .asciz "\nValidation Summary: %llu/%llu tests passed\n"

.end