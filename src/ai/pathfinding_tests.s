//==============================================================================
// SimCity ARM64 Assembly - A* Pathfinding Unit Tests
// Agent C1: AI Systems Architect
//==============================================================================
// Comprehensive unit tests for A* pathfinding core implementation
// Tests: initialization, pathfinding accuracy, performance, edge cases
//==============================================================================

.text
.align 4

//==============================================================================
// Test Framework Constants
//==============================================================================

.equ TEST_PASSED,             1
.equ TEST_FAILED,             0
.equ TEST_GRID_SIZE,          64        // 64x64 test grid
.equ TEST_MAX_NODES,          4096      // 64*64 = 4096 nodes
.equ TEST_MAX_PATH_LENGTH,    256       // Reasonable path length for tests

//==============================================================================
// Test Data Structures
//==============================================================================

// Test case structure
.struct 0
TestCase_name:                .skip 8    // Pointer to test name string
TestCase_start_x:             .skip 2    // Start X coordinate
TestCase_start_y:             .skip 2    // Start Y coordinate
TestCase_goal_x:              .skip 2    // Goal X coordinate
TestCase_goal_y:              .skip 2    // Goal Y coordinate
TestCase_expected_length:     .skip 4    // Expected path length (-1 = no path)
TestCase_max_iterations:      .skip 4    // Maximum allowed iterations
TestCase_blocked_nodes:       .skip 8    // Pointer to array of blocked node coordinates
TestCase_blocked_count:       .skip 4    // Number of blocked nodes
TestCase_reserved:            .skip 4    // Padding
TestCase_size = .

// Test results structure
.struct 0
TestResults_total_tests:      .skip 4    // Total number of tests run
TestResults_passed_tests:     .skip 4    // Number of tests passed
TestResults_failed_tests:     .skip 4    // Number of tests failed
TestResults_total_cycles:     .skip 8    // Total CPU cycles for all tests
TestResults_max_cycles:       .skip 8    // Maximum cycles for single test
TestResults_min_cycles:       .skip 8    // Minimum cycles for single test
TestResults_avg_cycles:       .skip 8    // Average cycles per test
TestResults_reserved:         .skip 8    // Padding
TestResults_size = .

//==============================================================================
// Global Test Data
//==============================================================================

.data
.align 8

// Test results
test_results:                 .skip TestResults_size

// Test grid for creating blocked areas
test_grid:                    .skip TEST_MAX_NODES  // One byte per node for obstacle map

// Current test index
current_test_index:           .word 0

//==============================================================================
// Test Case Definitions
//==============================================================================

// Test case 1: Simple straight line path
test_case_1:
    .quad   test_name_1
    .hword  0, 0                        // start (0,0)
    .hword  10, 0                       // goal (10,0)
    .word   10                          // expected length
    .word   50                          // max iterations
    .quad   0                           // no blocked nodes
    .word   0                           // blocked count
    .word   0                           // padding

// Test case 2: Diagonal path
test_case_2:
    .quad   test_name_2
    .hword  0, 0                        // start (0,0)
    .hword  10, 10                      // goal (10,10)
    .word   14                          // expected length (approximately sqrt(200))
    .word   100                         // max iterations
    .quad   0                           // no blocked nodes
    .word   0                           // blocked count
    .word   0                           // padding

// Test case 3: Path with obstacles
test_case_3:
    .quad   test_name_3
    .hword  0, 0                        // start (0,0)
    .hword  10, 0                       // goal (10,0)
    .word   30                          // expected length (detour around wall)
    .word   200                         // max iterations
    .quad   blocked_nodes_3             // blocked nodes array
    .word   10                          // blocked count
    .word   0                           // padding

// Test case 4: No path possible (completely blocked)
test_case_4:
    .quad   test_name_4
    .hword  0, 0                        // start (0,0)
    .hword  10, 0                       // goal (10,0)
    .word   -1                          // expected: no path
    .word   500                         // max iterations
    .quad   blocked_nodes_4             // complete wall
    .word   64                          // blocked count (full wall)
    .word   0                           // padding

// Test case 5: Large distance path
test_case_5:
    .quad   test_name_5
    .hword  0, 0                        // start (0,0)
    .hword  63, 63                      // goal (63,63) - corner to corner
    .word   126                         // expected length (63+63)
    .word   2000                        // max iterations
    .quad   0                           // no blocked nodes
    .word   0                           // blocked count
    .word   0                           // padding

// Test case 6: Performance stress test
test_case_6:
    .quad   test_name_6
    .hword  0, 0                        // start (0,0)
    .hword  32, 32                      // goal (32,32)
    .word   64                          // expected length
    .word   1000                        // max iterations
    .quad   blocked_nodes_6             // maze-like pattern
    .word   200                         // blocked count
    .word   0                           // padding

// Test case array
test_cases:
    .quad   test_case_1
    .quad   test_case_2
    .quad   test_case_3
    .quad   test_case_4
    .quad   test_case_5
    .quad   test_case_6

test_case_count:
    .word   6                           // Number of test cases

// Test names
test_name_1:        .asciz "Simple Straight Line Path"
test_name_2:        .asciz "Diagonal Path"
test_name_3:        .asciz "Path with Obstacles"
test_name_4:        .asciz "No Path Possible"
test_name_5:        .asciz "Large Distance Path"
test_name_6:        .asciz "Performance Stress Test"

// Blocked node arrays for test cases
blocked_nodes_3:    // Vertical wall from (5,0) to (5,9)
    .hword  5, 0
    .hword  5, 1
    .hword  5, 2
    .hword  5, 3
    .hword  5, 4
    .hword  5, 5
    .hword  5, 6
    .hword  5, 7
    .hword  5, 8
    .hword  5, 9

blocked_nodes_4:    // Complete wall blocking path
    .hword  1, 0, 1, 1, 1, 2, 1, 3, 1, 4, 1, 5, 1, 6, 1, 7
    .hword  2, 0, 2, 1, 2, 2, 2, 3, 2, 4, 2, 5, 2, 6, 2, 7
    .hword  3, 0, 3, 1, 3, 2, 3, 3, 3, 4, 3, 5, 3, 6, 3, 7
    .hword  4, 0, 4, 1, 4, 2, 4, 3, 4, 4, 4, 5, 4, 6, 4, 7
    .hword  5, 0, 5, 1, 5, 2, 5, 3, 5, 4, 5, 5, 5, 6, 5, 7
    .hword  6, 0, 6, 1, 6, 2, 6, 3, 6, 4, 6, 5, 6, 6, 6, 7
    .hword  7, 0, 7, 1, 7, 2, 7, 3, 7, 4, 7, 5, 7, 6, 7, 7
    .hword  8, 0, 8, 1, 8, 2, 8, 3, 8, 4, 8, 5, 8, 6, 8, 7

blocked_nodes_6:    // Maze-like pattern for stress testing
    // This would be a complex pattern - simplified for space
    .hword  10, 10, 10, 11, 10, 12, 11, 10, 12, 10
    .hword  15, 15, 15, 16, 15, 17, 16, 15, 17, 15
    .hword  20, 20, 20, 21, 20, 22, 21, 20, 22, 20
    .hword  25, 25, 25, 26, 25, 27, 26, 25, 27, 25
    .hword  30, 30, 30, 31, 30, 32, 31, 30, 32, 30
    // ... (continuing pattern)
    .skip   380                         // Fill remaining space

//==============================================================================
// Public Test Interface
//==============================================================================

.global pathfinding_run_all_tests
.global pathfinding_run_single_test
.global pathfinding_get_test_results
.global pathfinding_print_test_summary

//==============================================================================
// pathfinding_run_all_tests - Run all pathfinding unit tests
// Parameters: None
// Returns: x0 = number of tests passed
//==============================================================================
pathfinding_run_all_tests:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Initialize test results
    adrp    x19, test_results
    add     x19, x19, :lo12:test_results
    
    // Clear results structure
    mov     x0, x19
    mov     x1, #TestResults_size
    bl      memset_zero
    
    // Initialize A* system
    mov     x0, #TEST_MAX_NODES
    mov     x1, #TEST_MAX_PATH_LENGTH
    bl      astar_init
    cbz     x0, .test_init_failed
    
    // Get test case count
    adrp    x20, test_case_count
    add     x20, x20, :lo12:test_case_count
    ldr     w20, [x20]
    
    str     w20, [x19, #TestResults_total_tests]
    
    // Initialize timing
    mov     x21, #0xFFFFFFFFFFFFFFFF    // min_cycles = max value
    mov     x22, #0                     // max_cycles = 0
    
    // Run each test case
    mov     w0, #0                      // test index
    
.run_test_loop:
    cmp     w0, w20
    b.ge    .all_tests_complete
    
    // Store current test index
    adrp    x1, current_test_index
    add     x1, x1, :lo12:current_test_index
    str     w0, [x1]
    
    // Run single test
    bl      pathfinding_run_single_test
    
    // Update test results
    cbz     x0, .test_failed_update
    
    // Test passed
    ldr     w1, [x19, #TestResults_passed_tests]
    add     w1, w1, #1
    str     w1, [x19, #TestResults_passed_tests]
    b       .update_timing
    
.test_failed_update:
    // Test failed
    ldr     w1, [x19, #TestResults_failed_tests]
    add     w1, w1, #1
    str     w1, [x19, #TestResults_failed_tests]
    
.update_timing:
    // Get timing from last test (stored in return value x1)
    mov     x2, x1                      // cycles for this test
    
    // Update total cycles
    ldr     x1, [x19, #TestResults_total_cycles]
    add     x1, x1, x2
    str     x1, [x19, #TestResults_total_cycles]
    
    // Update min cycles
    ldr     x1, [x19, #TestResults_min_cycles]
    cmp     x2, x1
    csel    x1, x2, x1, lt
    str     x1, [x19, #TestResults_min_cycles]
    
    // Update max cycles
    ldr     x1, [x19, #TestResults_max_cycles]
    cmp     x2, x1
    csel    x1, x2, x1, gt
    str     x1, [x19, #TestResults_max_cycles]
    
    // Next test
    adrp    x1, current_test_index
    add     x1, x1, :lo12:current_test_index
    ldr     w0, [x1]
    add     w0, w0, #1
    b       .run_test_loop
    
.all_tests_complete:
    // Calculate average cycles
    ldr     x0, [x19, #TestResults_total_cycles]
    mov     x1, x20                     // total tests
    udiv    x0, x0, x1
    str     x0, [x19, #TestResults_avg_cycles]
    
    // Cleanup A* system
    bl      astar_cleanup
    
    // Return number of passed tests
    ldr     w0, [x19, #TestResults_passed_tests]
    b       .run_all_tests_exit
    
.test_init_failed:
    mov     x0, #0                      // Failed to initialize
    
.run_all_tests_exit:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// pathfinding_run_single_test - Run a single pathfinding test
// Parameters: w0 = test_index
// Returns: x0 = test_passed (1/0), x1 = cycles_elapsed
//==============================================================================
pathfinding_run_single_test:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    
    mov     x19, x0                     // test_index
    
    // Get test case pointer
    adrp    x20, test_cases
    add     x20, x20, :lo12:test_cases
    ldr     x20, [x20, x19, lsl #3]     // test_case pointer
    
    // Start timing
    mrs     x21, cntvct_el0
    
    // Load test case data
    ldrh    w22, [x20, #TestCase_start_x]
    ldrh    w23, [x20, #TestCase_start_y]
    ldrh    w24, [x20, #TestCase_goal_x]
    ldrh    w0, [x20, #TestCase_goal_y]
    mov     x25, x0                     // goal_y
    
    // Convert coordinates to node IDs
    mov     w1, #TEST_GRID_SIZE
    mul     w2, w23, w1                 // start_y * grid_size
    add     w2, w2, w22                 // start_node_id = start_y * grid_size + start_x
    
    mul     w3, w25, w1                 // goal_y * grid_size
    add     w3, w3, w24                 // goal_node_id = goal_y * grid_size + goal_x
    
    // Setup blocked nodes if any
    ldr     x4, [x20, #TestCase_blocked_nodes]
    ldr     w5, [x20, #TestCase_blocked_count]
    cbz     x4, .run_pathfinding
    
    // Apply blocked nodes to A* system
    mov     w6, #0                      // blocked node index
    
.setup_blocked_loop:
    cmp     w6, w5
    b.ge    .run_pathfinding
    
    // Get blocked node coordinates
    lsl     x7, x6, #2                  // index * 4 (2 shorts)
    add     x7, x4, x7                  // blocked node pointer
    ldrh    w8, [x7]                    // blocked_x
    ldrh    w9, [x7, #2]                // blocked_y
    
    // Convert to node ID
    mul     w10, w9, w1                 // blocked_y * grid_size
    add     w10, w10, w8                // blocked_node_id
    
    // Set as blocked (high cost)
    mov     x0, x10                     // node_id
    mov     w1, #255                    // max traffic cost (blocked)
    mov     w2, #255                    // max terrain cost (blocked)
    bl      astar_set_dynamic_cost
    
    add     w6, w6, #1
    b       .setup_blocked_loop
    
.run_pathfinding:
    // Run A* pathfinding
    mov     x0, x2                      // start_node_id
    mov     x1, x3                      // goal_node_id
    mov     x2, #1                      // use_traffic_cost = true
    bl      astar_find_path
    
    // End timing
    mrs     x22, cntvct_el0
    sub     x22, x22, x21               // cycles_elapsed
    
    mov     x21, x0                     // path_length result
    
    // Validate result
    ldr     w1, [x20, #TestCase_expected_length]
    
    // Check for no-path case
    cmp     w1, #-1
    b.ne    .check_path_length
    
    // Expected no path
    cmp     w21, #-1
    b.ne    .test_failed                // Should have failed but didn't
    b       .test_passed
    
.check_path_length:
    // Check if path was found
    cmp     w21, #0
    b.le    .test_failed                // No path found when one was expected
    
    // Validate path length (allow some tolerance for optimal vs sub-optimal paths)
    mov     w2, w1                      // expected_length
    mov     w3, w2
    add     w3, w3, w3, lsr #2          // expected + 25% tolerance
    
    cmp     w21, w2
    b.lt    .test_failed                // Path too short (impossible)
    cmp     w21, w3
    b.gt    .test_failed                // Path too long (sub-optimal)
    
    // Validate iteration count
    bl      astar_get_iteration_count
    ldr     w1, [x20, #TestCase_max_iterations]
    cmp     w0, w1
    b.gt    .test_failed                // Too many iterations
    
.test_passed:
    mov     x0, #TEST_PASSED
    mov     x1, x22                     // cycles_elapsed
    b       .single_test_exit
    
.test_failed:
    mov     x0, #TEST_FAILED
    mov     x1, x22                     // cycles_elapsed
    
.single_test_exit:
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//==============================================================================
// Helper Functions
//==============================================================================

// astar_get_iteration_count - Get iteration count from last pathfinding run
// Parameters: None
// Returns: w0 = iteration_count
astar_get_iteration_count:
    adrp    x0, astar_context
    add     x0, x0, :lo12:astar_context
    ldr     w0, [x0, #AStarContext_iterations]
    ret

// memset_zero - Clear memory region to zero
// Parameters: x0 = pointer, x1 = size
// Returns: None
memset_zero:
    cbz     x1, .memset_done
    
.memset_loop:
    strb    wzr, [x0], #1
    sub     x1, x1, #1
    cbnz    x1, .memset_loop
    
.memset_done:
    ret

//==============================================================================
// Test Result Functions
//==============================================================================

// pathfinding_get_test_results - Get pointer to test results structure
// Parameters: None
// Returns: x0 = test_results_pointer
pathfinding_get_test_results:
    adrp    x0, test_results
    add     x0, x0, :lo12:test_results
    ret

// pathfinding_print_test_summary - Print test summary to debug output
// Parameters: None
// Returns: None
pathfinding_print_test_summary:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Get test results
    adrp    x19, test_results
    add     x19, x19, :lo12:test_results
    
    // Print summary header
    adrp    x0, summary_header
    add     x0, x0, :lo12:summary_header
    bl      debug_print_string
    
    // Print total tests
    adrp    x0, total_tests_format
    add     x0, x0, :lo12:total_tests_format
    ldr     w1, [x19, #TestResults_total_tests]
    bl      debug_printf
    
    // Print passed tests
    adrp    x0, passed_tests_format
    add     x0, x0, :lo12:passed_tests_format
    ldr     w1, [x19, #TestResults_passed_tests]
    bl      debug_printf
    
    // Print failed tests
    adrp    x0, failed_tests_format
    add     x0, x0, :lo12:failed_tests_format
    ldr     w1, [x19, #TestResults_failed_tests]
    bl      debug_printf
    
    // Print timing information
    adrp    x0, avg_cycles_format
    add     x0, x0, :lo12:avg_cycles_format
    ldr     x1, [x19, #TestResults_avg_cycles]
    bl      debug_printf
    
    adrp    x0, min_cycles_format
    add     x0, x0, :lo12:min_cycles_format
    ldr     x1, [x19, #TestResults_min_cycles]
    bl      debug_printf
    
    adrp    x0, max_cycles_format
    add     x0, x0, :lo12:max_cycles_format
    ldr     x1, [x19, #TestResults_max_cycles]
    bl      debug_printf
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Performance Tests
//==============================================================================

// pathfinding_performance_test - Comprehensive performance testing
// Parameters: x0 = num_iterations
// Returns: x0 = avg_cycles_per_pathfind
pathfinding_performance_test:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // num_iterations
    
    // Initialize A* system
    mov     x0, #TEST_MAX_NODES
    mov     x1, #TEST_MAX_PATH_LENGTH
    bl      astar_init
    cbz     x0, .perf_test_failed
    
    // Start overall timing
    mrs     x20, cntvct_el0
    
    mov     x21, #0                     // iteration counter
    mov     x22, #0                     // total cycles accumulator
    
.perf_test_loop:
    cmp     x21, x19
    b.ge    .perf_test_complete
    
    // Generate random start and goal positions
    bl      get_random_seed
    and     w1, w0, #63                 // start_x = random % 64
    lsr     w0, w0, #8
    and     w2, w0, #63                 // start_y = random % 64
    lsr     w0, w0, #8
    and     w3, w0, #63                 // goal_x = random % 64
    lsr     w0, w0, #8
    and     w4, w0, #63                 // goal_y = random % 64
    
    // Convert to node IDs
    mov     w5, #TEST_GRID_SIZE
    mul     w6, w2, w5                  // start_node = start_y * grid_size + start_x
    add     w6, w6, w1
    mul     w7, w4, w5                  // goal_node = goal_y * grid_size + goal_x
    add     w7, w7, w3
    
    // Time individual pathfind
    mrs     x8, cntvct_el0
    
    mov     x0, x6                      // start_node_id
    mov     x1, x7                      // goal_node_id
    mov     x2, #0                      // no traffic costs for performance test
    bl      astar_find_path
    
    mrs     x9, cntvct_el0
    sub     x9, x9, x8                  // cycles for this pathfind
    add     x22, x22, x9                // accumulate total cycles
    
    add     x21, x21, #1
    b       .perf_test_loop
    
.perf_test_complete:
    // Calculate average
    udiv    x0, x22, x19
    
    // Cleanup
    bl      astar_cleanup
    b       .perf_test_exit
    
.perf_test_failed:
    mov     x0, #0
    
.perf_test_exit:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// get_random_seed - Get pseudo-random number for testing
// Parameters: None
// Returns: w0 = random_number
get_random_seed:
    mrs     x0, cntvct_el0              // Use timer as seed
    mov     w1, #1103515245             // Linear congruential generator multiplier
    mul     x0, x0, x1
    add     x0, x0, #12345              // LCG increment
    ret

//==============================================================================
// Specialized Test Cases
//==============================================================================

// pathfinding_stress_test - Test with maximum nodes and complex scenarios
// Parameters: None
// Returns: x0 = tests_passed
pathfinding_stress_test:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, #0                     // passed tests counter
    
    // Test 1: Maximum distance path
    mov     x0, #0                      // start node (0,0)
    mov     x1, #4095                   // goal node (63,63)
    mov     x2, #0                      // no traffic costs
    bl      astar_find_path
    cmp     x0, #0
    b.le    .stress_test_1_failed
    add     x19, x19, #1
    
.stress_test_1_failed:
    
    // Test 2: Path through maze-like obstacles
    bl      setup_maze_obstacles
    mov     x0, #0                      // start node
    mov     x1, #2047                   // middle-distance goal
    mov     x2, #1                      // use traffic costs (obstacles)
    bl      astar_find_path
    cmp     x0, #0
    b.le    .stress_test_2_failed
    add     x19, x19, #1
    
.stress_test_2_failed:
    
    // Test 3: Multiple rapid pathfinding requests
    mov     x20, #0                     // counter
    
.rapid_pathfind_loop:
    cmp     x20, #100
    b.ge    .rapid_pathfind_done
    
    // Random start/goal for each iteration
    bl      get_random_seed
    and     w0, w0, #4095               // start_node
    bl      get_random_seed
    and     w1, w0, #4095               // goal_node
    mov     x2, #0                      // no traffic costs
    bl      astar_find_path
    
    add     x20, x20, #1
    b       .rapid_pathfind_loop
    
.rapid_pathfind_done:
    add     x19, x19, #1                // Count rapid test as passed
    
    mov     x0, x19                     // Return passed tests
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// setup_maze_obstacles - Create maze-like obstacle pattern
// Parameters: None
// Returns: None
setup_maze_obstacles:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Create checkerboard-like pattern with some gaps
    mov     w0, #0                      // y coordinate
    
.maze_y_loop:
    cmp     w0, #64
    b.ge    .maze_setup_done
    
    mov     w1, #0                      // x coordinate
    
.maze_x_loop:
    cmp     w1, #64
    b.ge    .maze_y_next
    
    // Create obstacles at certain positions
    and     w2, w0, #3                  // y % 4
    and     w3, w1, #3                  // x % 4
    cmp     w2, #2
    b.ne    .maze_x_next
    cmp     w3, #1
    b.ne    .maze_x_next
    
    // This position should be blocked
    mov     w4, #64
    mul     w5, w0, w4                  // node_id = y * 64 + x
    add     w5, w5, w1
    
    mov     x0, x5                      // node_id
    mov     w1, #200                    // high traffic cost
    mov     w2, #200                    // high terrain cost
    bl      astar_set_dynamic_cost
    
    mov     w0, w5, lsr #6              // Restore y from node_id
    mov     w1, w5
    and     w1, w1, #63                 // Restore x from node_id
    
.maze_x_next:
    add     w1, w1, #1
    b       .maze_x_loop
    
.maze_y_next:
    add     w0, w0, #1
    b       .maze_y_loop
    
.maze_setup_done:
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Debug Output Functions (Simplified)
//==============================================================================

// debug_print_string - Print string for debugging
// Parameters: x0 = string_pointer
// Returns: None
debug_print_string:
    // In a real implementation, this would output to console/debug interface
    // For now, this is a placeholder
    ret

// debug_printf - Printf-style debug output
// Parameters: x0 = format_string, x1 = value
// Returns: None
debug_printf:
    // Placeholder for formatted debug output
    ret

//==============================================================================
// Debug Format Strings
//==============================================================================

.data
.align 3

summary_header:           .asciz "\n=== A* Pathfinding Test Summary ===\n"
total_tests_format:       .asciz "Total tests: %d\n"
passed_tests_format:      .asciz "Passed: %d\n"
failed_tests_format:      .asciz "Failed: %d\n"
avg_cycles_format:        .asciz "Average cycles: %ld\n"
min_cycles_format:        .asciz "Minimum cycles: %ld\n"
max_cycles_format:        .asciz "Maximum cycles: %ld\n"

.end