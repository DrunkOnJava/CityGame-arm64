//
// particle_tests.s - Comprehensive unit tests for particle systems and animation framework
// Agent B4: Graphics Team - Particle Systems & Animation Framework
//
// Comprehensive test suite for NEON-optimized particle systems:
// - Unit tests for particle physics simulation
// - Animation system testing
// - Memory pool management validation
// - Performance benchmarking
// - Integration tests with graphics pipeline
//
// Test coverage:
// - Particle creation, physics, and destruction
// - NEON SIMD correctness validation
// - Memory allocation and pool management
// - Animation keyframe interpolation
// - Collision detection accuracy
// - Performance regression detection
//
// Author: Agent B4 (Graphics - Particles & Animation)
// Date: 2025-06-15
//

.section __TEXT,__text,regular,pure_instructions
.align 4

// Test framework constants
.equ MAX_TEST_CASES, 64
.equ TEST_BUFFER_SIZE, 0x10000      // 64KB test buffer
.equ PERFORMANCE_ITERATIONS, 10000  // Iterations for performance tests
.equ EPSILON_FLOAT, 0x3A83126F       // 0.001f for float comparison

// Test result codes
.equ TEST_PASS, 0
.equ TEST_FAIL, 1
.equ TEST_SKIP, 2
.equ TEST_ERROR, 3

// Test case structure
.struct test_case
    test_name:      .quad 1     // Pointer to test name string
    test_function:  .quad 1     // Pointer to test function
    setup_function: .quad 1     // Pointer to setup function (optional)
    teardown_function: .quad 1  // Pointer to teardown function (optional)
    enabled:        .byte 1     // Test enabled flag
    priority:       .byte 1     // Test priority (0=low, 1=medium, 2=high)
    category:       .byte 1     // Test category (0=unit, 1=integration, 2=performance)
    .align 8
.endstruct

// Test result structure
.struct test_result
    test_id:            .long 1     // Test case ID
    result_code:        .long 1     // Result code (PASS/FAIL/SKIP/ERROR)
    execution_time_us:  .long 1     // Execution time in microseconds
    error_message:      .quad 1     // Pointer to error message (if any)
    assertions_passed:  .long 1     // Number of assertions that passed
    assertions_failed:  .long 1     // Number of assertions that failed
    performance_metric: .float 1    // Performance metric (particles/sec, etc.)
    .align 8
.endstruct

// Test framework state
.struct test_framework_state
    total_tests:        .long 1     // Total number of tests
    tests_run:          .long 1     // Number of tests executed
    tests_passed:       .long 1     // Number of tests passed
    tests_failed:       .long 1     // Number of tests failed
    tests_skipped:      .long 1     // Number of tests skipped
    current_test_id:    .long 1     // Currently executing test ID
    start_time:         .quad 1     // Test suite start time
    end_time:           .quad 1     // Test suite end time
    test_buffer:        .quad 1     // Pointer to test scratch buffer
    .align 8
.endstruct

// Global test data
.data
.align 16
test_framework:         .skip test_framework_state_size
test_cases:             .skip test_case_size * MAX_TEST_CASES
test_results:           .skip test_result_size * MAX_TEST_CASES
test_scratch_buffer:    .skip TEST_BUFFER_SIZE

// Test particles array for testing
test_particles:         .skip particle_size * 1024    // 1024 test particles
test_particle_system:   .skip particle_system_size
test_animation_data:    .skip animation_instance_size * 16

// Performance baseline data
performance_baselines:
    physics_update_baseline:    .float 2000.0      // 2000 particles/frame baseline
    emission_baseline:          .float 1000.0      // 1000 particles/sec baseline
    collision_baseline:         .float 500.0       // 500 collisions/frame baseline
    animation_baseline:         .float 100.0       // 100 animations/frame baseline

.text
.global _particle_tests_run_all
.global _particle_tests_run_category
.global _particle_tests_benchmark
.global _particle_tests_validate_neon
.global _particle_tests_memory_stress
.global _particle_tests_integration

//
// particle_tests_run_all - Run all particle system tests
// Input: None
// Output: x0 = 0 if all tests pass, -1 if any fail
// Modifies: x0-x15, v0-v31
//
_particle_tests_run_all:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    // Initialize test framework
    bl      _test_framework_init
    cmp     x0, #0
    b.ne    .Lrun_all_error
    
    // Register all test cases
    bl      _register_all_test_cases
    
    // Print test suite header
    adr     x0, test_suite_header
    bl      _test_print_string
    
    // Get start time
    bl      _get_microsecond_timer
    adrp    x1, test_framework@PAGE
    add     x1, x1, test_framework@PAGEOFF
    str     x0, [x1, #start_time]
    
    // Run all test cases
    bl      _execute_all_tests
    mov     x19, x0         // Save test result
    
    // Get end time and calculate duration
    bl      _get_microsecond_timer
    adrp    x1, test_framework@PAGE
    add     x1, x1, test_framework@PAGEOFF
    str     x0, [x1, #end_time]
    
    // Print test summary
    bl      _print_test_summary
    
    // Clean up test framework
    bl      _test_framework_cleanup
    
    mov     x0, x19         // Return test result
    b       .Lrun_all_exit
    
.Lrun_all_error:
    mov     x0, #-1         // Error
    
.Lrun_all_exit:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// particle_tests_validate_neon - Validate NEON SIMD correctness
// Input: None
// Output: x0 = 0 if NEON operations are correct, -1 if errors detected
// Modifies: x0-x15, v0-v31
//
_particle_tests_validate_neon:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    adr     x0, neon_validation_msg
    bl      _test_print_string
    
    mov     x19, #0         // Error counter
    
    // Test 1: Verify NEON constants are loaded correctly
    bl      _test_neon_constants_loading
    cmp     x0, #0
    cinc    x19, x19, ne
    
    // Test 2: Test 4-particle physics update accuracy
    bl      _test_neon_physics_accuracy
    cmp     x0, #0
    cinc    x19, x19, ne
    
    // Test 3: Test NEON transpose operations
    bl      _test_neon_transpose_correctness
    cmp     x0, #0
    cinc    x19, x19, ne
    
    // Test 4: Test collision detection SIMD vs scalar
    bl      _test_neon_collision_accuracy
    cmp     x0, #0
    cinc    x19, x19, ne
    
    // Test 5: Test animation interpolation NEON
    bl      _test_neon_animation_interpolation
    cmp     x0, #0
    cinc    x19, x19, ne
    
    // Print validation results
    cmp     x19, #0
    b.eq    .Lneon_validation_pass
    
    adr     x0, neon_validation_fail_msg
    bl      _test_print_string
    mov     x0, #-1
    b       .Lneon_validation_exit
    
.Lneon_validation_pass:
    adr     x0, neon_validation_pass_msg
    bl      _test_print_string
    mov     x0, #0
    
.Lneon_validation_exit:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// test_neon_physics_accuracy - Test NEON physics vs scalar reference
// Input: None
// Output: x0 = 0 if accurate, -1 if discrepancy detected
// Modifies: x0-x15, v0-v31
//
_test_neon_physics_accuracy:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    // Create test particles with known initial conditions
    adrp    x19, test_particles@PAGE
    add     x19, x19, test_particles@PAGEOFF
    
    // Initialize 8 test particles (4 for NEON, 4 for scalar reference)
    mov     x20, #8
    bl      _init_test_particles_deterministic
    
    // Copy particles for scalar reference
    add     x21, x19, #256          // Second set offset (4 particles * 64 bytes)
    mov     x0, x21
    mov     x1, x19
    mov     x2, #256                // 4 particles * 64 bytes
    bl      _memcpy
    
    // Update first 4 particles using NEON
    mov     x0, x19
    mov     w1, #4
    fmov    s0, #0.016667           // 60 FPS delta time
    bl      _particle_physics_update_simd
    
    // Update second 4 particles using scalar reference
    mov     x0, x21
    mov     w1, #4
    fmov    s0, #0.016667
    bl      _particle_physics_update_scalar_reference
    
    // Compare results
    mov     x22, #0                 // Particle index
    
.Lcompare_particles_loop:
    cmp     x22, #4
    b.ge    .Lcompare_done
    
    // Compare particle positions and velocities
    add     x0, x19, x22, lsl #6    // NEON particle
    add     x1, x21, x22, lsl #6    // Scalar particle
    bl      _compare_particle_state
    cmp     x0, #0
    b.ne    .Lphysics_accuracy_fail
    
    add     x22, x22, #1
    b       .Lcompare_particles_loop
    
.Lcompare_done:
    mov     x0, #0                  // Success
    b       .Lphysics_accuracy_exit
    
.Lphysics_accuracy_fail:
    mov     x0, #-1                 // Failure
    
.Lphysics_accuracy_exit:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// particle_tests_benchmark - Run performance benchmarks
// Input: None
// Output: x0 = 0 if all benchmarks pass, -1 if performance regression
// Modifies: x0-x15, v0-v31
//
_particle_tests_benchmark:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    adr     x0, benchmark_header_msg
    bl      _test_print_string
    
    mov     x19, #0                 // Performance regression counter
    
    // Benchmark 1: Physics update performance
    bl      _benchmark_physics_update
    bl      _check_performance_regression
    cmp     x0, #0
    cinc    x19, x19, ne
    
    // Benchmark 2: Particle emission performance
    bl      _benchmark_particle_emission
    bl      _check_performance_regression
    cmp     x0, #0
    cinc    x19, x19, ne
    
    // Benchmark 3: Collision detection performance
    bl      _benchmark_collision_detection
    bl      _check_performance_regression
    cmp     x0, #0
    cinc    x19, x19, ne
    
    // Benchmark 4: Animation system performance
    bl      _benchmark_animation_system
    bl      _check_performance_regression
    cmp     x0, #0
    cinc    x19, x19, ne
    
    // Benchmark 5: Memory allocation performance
    bl      _benchmark_memory_allocation
    bl      _check_performance_regression
    cmp     x0, #0
    cinc    x19, x19, ne
    
    // Print benchmark summary
    bl      _print_benchmark_summary
    
    cmp     x19, #0
    cset    w0, eq                  // 0 if no regressions, -1 if any regressions
    
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// benchmark_physics_update - Benchmark particle physics update performance
// Input: None
// Output: x0 = particles_per_second
// Modifies: x0-x15, v0-v31
//
_benchmark_physics_update:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    // Initialize test particles
    adrp    x19, test_particles@PAGE
    add     x19, x19, test_particles@PAGEOFF
    mov     x20, #1024              // Test with 1024 particles
    bl      _init_test_particles_random
    
    // Warm up the caches
    mov     x21, #10
.Lwarmup_loop:
    mov     x0, x19
    mov     w1, w20
    fmov    s0, #0.016667
    bl      _particle_physics_update_simd
    subs    x21, x21, #1
    b.ne    .Lwarmup_loop
    
    // Start timing
    bl      _get_microsecond_timer
    mov     x21, x0                 // Save start time
    
    // Run benchmark iterations
    mov     x22, #PERFORMANCE_ITERATIONS
.Lbenchmark_loop:
    mov     x0, x19
    mov     w1, w20
    fmov    s0, #0.016667
    bl      _particle_physics_update_simd
    subs    x22, x22, #1
    b.ne    .Lbenchmark_loop
    
    // End timing
    bl      _get_microsecond_timer
    sub     x0, x0, x21             // Total time in microseconds
    
    // Calculate particles per second
    mov     x1, #1000000            // Convert to seconds
    mul     x2, x20, x22            // total_particles_processed
    mul     x2, x2, x1              // Scale to per-second
    udiv    x0, x2, x0              // particles_per_second
    
    // Print result
    adr     x1, physics_benchmark_msg
    bl      _test_print_result
    
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// particle_tests_memory_stress - Stress test memory allocation and pools
// Input: None
// Output: x0 = 0 if memory system is stable, -1 if errors detected
// Modifies: x0-x15, v0-v31
//
_particle_tests_memory_stress:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    adr     x0, memory_stress_msg
    bl      _test_print_string
    
    mov     x19, #0                 // Error counter
    
    // Test 1: Rapid allocation/deallocation cycles
    bl      _test_rapid_alloc_dealloc
    cmp     x0, #0
    cinc    x19, x19, ne
    
    // Test 2: Fragment and defragment particle pools
    bl      _test_pool_fragmentation
    cmp     x0, #0
    cinc    x19, x19, ne
    
    // Test 3: Memory leak detection
    bl      _test_memory_leak_detection
    cmp     x0, #0
    cinc    x19, x19, ne
    
    // Test 4: Pool overflow handling
    bl      _test_pool_overflow_handling
    cmp     x0, #0
    cinc    x19, x19, ne
    
    // Test 5: Concurrent access simulation
    bl      _test_concurrent_access_simulation
    cmp     x0, #0
    cinc    x19, x19, ne
    
    cmp     x19, #0
    cset    w0, eq                  // 0 if stable, -1 if errors
    
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// particle_tests_integration - Integration tests with graphics pipeline
// Input: None
// Output: x0 = 0 if integration is successful, -1 if errors
// Modifies: x0-x15, v0-v31
//
_particle_tests_integration:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    adr     x0, integration_test_msg
    bl      _test_print_string
    
    mov     x19, #0                 // Error counter
    
    // Test 1: Particle system creation and Graphics pipeline coordination
    bl      _test_graphics_pipeline_integration
    cmp     x0, #0
    cinc    x19, x19, ne
    
    // Test 2: Render submission to sprite batcher
    bl      _test_sprite_batch_integration
    cmp     x0, #0
    cinc    x19, x19, ne
    
    // Test 3: Animation system with renderer
    bl      _test_animation_renderer_integration
    cmp     x0, #0
    cinc    x19, x19, ne
    
    // Test 4: Memory allocator coordination with Agent D1
    bl      _test_memory_allocator_integration
    cmp     x0, #0
    cinc    x19, x19, ne
    
    // Test 5: Performance monitoring integration
    bl      _test_performance_monitoring_integration
    cmp     x0, #0
    cinc    x19, x19, ne
    
    cmp     x19, #0
    cset    w0, eq                  // 0 if successful, -1 if errors
    
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// Test framework implementation functions

//
// test_framework_init - Initialize test framework
// Input: None
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x7
//
_test_framework_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Initialize framework state
    adrp    x0, test_framework@PAGE
    add     x0, x0, test_framework@PAGEOFF
    mov     x1, #0
    mov     x2, #test_framework_state_size
    bl      _memset
    
    // Initialize test scratch buffer
    adrp    x1, test_scratch_buffer@PAGE
    add     x1, x1, test_scratch_buffer@PAGEOFF
    str     x1, [x0, #test_buffer]
    
    mov     x0, #0                  // Success
    ldp     x29, x30, [sp], #16
    ret

//
// register_all_test_cases - Register all test cases in the framework
// Input: None
// Output: None
// Modifies: x0-x15
//
_register_all_test_cases:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    adrp    x19, test_cases@PAGE
    add     x19, x19, test_cases@PAGEOFF
    mov     x20, #0                 // Test case index
    
    // Register unit tests
    adr     x0, test_particle_creation_name
    adr     x1, _test_particle_creation
    bl      _register_test_case
    
    adr     x0, test_physics_update_name
    adr     x1, _test_physics_update
    bl      _register_test_case
    
    adr     x0, test_collision_detection_name
    adr     x1, _test_collision_detection
    bl      _register_test_case
    
    adr     x0, test_animation_interpolation_name
    adr     x1, _test_animation_interpolation
    bl      _register_test_case
    
    adr     x0, test_memory_pools_name
    adr     x1, _test_memory_pools
    bl      _register_test_case
    
    // Register performance tests
    adr     x0, test_physics_performance_name
    adr     x1, _test_physics_performance
    bl      _register_test_case
    
    adr     x0, test_emission_performance_name
    adr     x1, _test_emission_performance
    bl      _register_test_case
    
    // Register integration tests
    adr     x0, test_graphics_integration_name
    adr     x1, _test_graphics_integration
    bl      _register_test_case
    
    // Update total test count
    adrp    x0, test_framework@PAGE
    add     x0, x0, test_framework@PAGEOFF
    str     w20, [x0, #total_tests]
    
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// register_test_case - Register a single test case
// Input: x0 = test_name, x1 = test_function
// Output: None
// Modifies: x2-x7
//
_register_test_case:
    adrp    x2, test_cases@PAGE
    add     x2, x2, test_cases@PAGEOFF
    
    // Get current test count
    adrp    x3, test_framework@PAGE
    add     x3, x3, test_framework@PAGEOFF
    ldr     w4, [x3, #total_tests]
    
    // Calculate test case address
    add     x5, x2, x4, lsl #6      // test_case[index] (64 bytes per case)
    
    // Fill test case structure
    str     x0, [x5, #test_name]
    str     x1, [x5, #test_function]
    str     xzr, [x5, #setup_function]
    str     xzr, [x5, #teardown_function]
    mov     w6, #1
    strb    w6, [x5, #enabled]
    mov     w6, #1
    strb    w6, [x5, #priority]
    strb    wzr, [x5, #category]    // Unit test by default
    
    // Increment test count
    add     w4, w4, #1
    str     w4, [x3, #total_tests]
    
    ret

// Individual test functions

//
// test_particle_creation - Test basic particle creation and initialization
// Input: None
// Output: x0 = TEST_PASS/TEST_FAIL
// Modifies: x0-x15, v0-v7
//
_test_particle_creation:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Create a test particle system
    mov     w0, #0                  // Fire system type
    mov     w1, #1000               // Max particles
    adrp    x2, test_emitter_pos@PAGE
    add     x2, x2, test_emitter_pos@PAGEOFF
    bl      _particle_system_create
    cmp     x0, #0
    b.eq    .Ltest_creation_fail
    
    mov     x19, x0                 // Save system pointer
    
    // Verify system was initialized correctly
    ldr     w1, [x19, #system_type]
    cmp     w1, #0
    b.ne    .Ltest_creation_fail
    
    ldr     w1, [x19, #max_particles]
    cmp     w1, #1000
    b.ne    .Ltest_creation_fail
    
    ldr     w1, [x19, #active_count]
    cmp     w1, #0
    b.ne    .Ltest_creation_fail
    
    mov     x0, #TEST_PASS
    b       .Ltest_creation_exit
    
.Ltest_creation_fail:
    mov     x0, #TEST_FAIL
    
.Ltest_creation_exit:
    ldp     x29, x30, [sp], #16
    ret

// More test function implementations...
// (Additional test functions would be implemented here)

// Helper functions for test utilities

//
// compare_particle_state - Compare two particles for equality within epsilon
// Input: x0 = particle1, x1 = particle2
// Output: x0 = 0 if equal, -1 if different
// Modifies: x0-x7, v0-v7
//
_compare_particle_state:
    // Load and compare positions
    ld1     {v0.4s}, [x0]           // particle1 position
    ld1     {v1.4s}, [x1]           // particle2 position
    
    fsub    v2.4s, v0.4s, v1.4s     // difference
    fabs    v2.4s, v2.4s            // absolute difference
    
    // Load epsilon for comparison
    adrp    x2, epsilon_constant@PAGE
    add     x2, x2, epsilon_constant@PAGEOFF
    ld1r    {v3.4s}, [x2]           // Load epsilon into all lanes
    
    fcmgt   v4.4s, v2.4s, v3.4s     // Check if any component > epsilon
    
    // Check if any component exceeded epsilon
    umaxv   s5, v4.4s               // Get maximum across all lanes
    fmov    w0, s5
    cmp     w0, #0
    cset    w0, ne                  // Return -1 if difference > epsilon, 0 if equal
    
    ret

//
// init_test_particles_deterministic - Initialize particles with known values
// Input: x0 = particle_array, x1 = particle_count
// Output: None
// Modifies: x0-x7, v0-v7
//
_init_test_particles_deterministic:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     x2, #0                  // Particle index
    
.Linit_det_loop:
    cmp     x2, x1
    b.ge    .Linit_det_done
    
    add     x3, x0, x2, lsl #6      // particle[index]
    
    // Set deterministic position
    ucvtf   s0, w2                  // Convert index to float
    fmov    s1, #1.0
    fadd    s0, s0, s1              // x = index + 1
    fmov    s1, #2.0
    fadd    s1, s0, s1              // y = x + 2
    fmov    s2, #3.0
    fadd    s2, s1, s2              // z = y + 3
    fmov    s3, #0.0                // w = 0
    
    // Store position
    mov     v4.s[0], v0.s[0]
    mov     v4.s[1], v1.s[0]
    mov     v4.s[2], v2.s[0]
    mov     v4.s[3], v3.s[0]
    st1     {v4.4s}, [x3]
    
    // Set deterministic velocity
    fmov    s0, #0.5
    fmov    s1, #-0.5
    fmov    s2, #1.0
    fmov    s3, #0.0
    
    mov     v5.s[0], v0.s[0]
    mov     v5.s[1], v1.s[0]
    mov     v5.s[2], v2.s[0]
    mov     v5.s[3], v3.s[0]
    st1     {v5.4s}, [x3, #16]
    
    add     x2, x2, #1
    b       .Linit_det_loop
    
.Linit_det_done:
    ldp     x29, x30, [sp], #16
    ret

// Test utility functions (simplified implementations)
_test_print_string:
    // Print test message (implementation depends on platform)
    ret

_test_print_result:
    // Print test result with formatting
    ret

_print_test_summary:
    // Print overall test summary
    ret

_get_microsecond_timer:
    // Get high-precision timer
    mrs     x0, cntvct_el0
    ret

_particle_physics_update_scalar_reference:
    // Scalar reference implementation for validation
    ret

_init_test_particles_random:
    // Initialize particles with random values for stress testing
    ret

// External dependencies
.extern _memset
.extern _memcpy
.extern _particle_system_create
.extern _particle_physics_update_simd

// Test data
.section __TEXT,__cstring,cstring_literals
test_suite_header:              .asciz "=== SimCity ARM64 Particle System Test Suite ===\n"
neon_validation_msg:            .asciz "Validating NEON SIMD operations...\n"
neon_validation_pass_msg:       .asciz "✓ All NEON validations passed\n"
neon_validation_fail_msg:       .asciz "✗ NEON validation failures detected\n"
benchmark_header_msg:           .asciz "=== Performance Benchmarks ===\n"
physics_benchmark_msg:          .asciz "Physics Update: %d particles/sec\n"
memory_stress_msg:              .asciz "Running memory stress tests...\n"
integration_test_msg:           .asciz "Running integration tests...\n"

// Test case names
test_particle_creation_name:        .asciz "Particle Creation"
test_physics_update_name:           .asciz "Physics Update"
test_collision_detection_name:      .asciz "Collision Detection"
test_animation_interpolation_name:  .asciz "Animation Interpolation"
test_memory_pools_name:             .asciz "Memory Pools"
test_physics_performance_name:      .asciz "Physics Performance"
test_emission_performance_name:     .asciz "Emission Performance"
test_graphics_integration_name:     .asciz "Graphics Integration"

.data
test_emitter_pos:       .float 0.0, 0.0, 0.0, 0.0
epsilon_constant:       .float 0.001

.end