/*
 * SimCity ARM64 Assembly - A* Pathfinding Test Runner
 * Agent C1: AI Systems Architect
 * 
 * C wrapper for running ARM64 assembly pathfinding tests
 * Provides integration with standard testing frameworks
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>
#include <assert.h>

// External assembly functions
extern int astar_init(uint32_t max_nodes, uint32_t max_path_length);
extern int astar_find_path(uint32_t start_node_id, uint32_t goal_node_id, int use_traffic_cost);
extern void astar_cleanup(void);
extern int astar_set_dynamic_cost(uint32_t node_id, uint8_t traffic_cost, uint8_t terrain_cost);
extern uint32_t astar_get_path_length(void);
extern uint32_t* astar_get_path_nodes(void);
extern void astar_get_statistics(void* stats_output);

// Test framework functions
extern int pathfinding_run_all_tests(void);
extern int pathfinding_run_single_test(uint32_t test_index);
extern void* pathfinding_get_test_results(void);
extern void pathfinding_print_test_summary(void);
extern uint64_t pathfinding_performance_test(uint64_t num_iterations);
extern int pathfinding_stress_test(void);

// Agent allocator functions (from memory system)
extern int fast_agent_alloc(int agent_type);
extern int fast_agent_free(void* agent_pointer);
extern int agent_allocator_init(uint64_t total_memory_size, uint64_t expected_agent_count);

// Test configuration
#define TEST_GRID_SIZE 64
#define TEST_MAX_NODES (TEST_GRID_SIZE * TEST_GRID_SIZE)
#define TEST_MAX_PATH_LENGTH 256
#define TEST_MEMORY_SIZE (64 * 1024 * 1024)  // 64MB for testing
#define TEST_EXPECTED_AGENTS 100000

// Statistics structure (matches assembly layout)
typedef struct {
    uint64_t total_searches;
    uint64_t successful_searches;
    uint64_t total_cycles;
    uint64_t max_iterations;
    uint64_t cache_hits;
    uint64_t cache_misses;
} astar_statistics_t;

// Test results structure (matches assembly layout)
typedef struct {
    uint32_t total_tests;
    uint32_t passed_tests;
    uint32_t failed_tests;
    uint64_t total_cycles;
    uint64_t max_cycles;
    uint64_t min_cycles;
    uint64_t avg_cycles;
} test_results_t;

// Global test state
static int tests_initialized = 0;
static struct timeval start_time, end_time;

// Helper functions
static double get_time_diff_ms(struct timeval* start, struct timeval* end) {
    return (end->tv_sec - start->tv_sec) * 1000.0 + 
           (end->tv_usec - start->tv_usec) / 1000.0;
}

static uint64_t get_cycle_frequency(void) {
    // For Apple Silicon M1/M2, the cycle counter runs at 24MHz
    // This is an approximation - in production, would read from system
    return 24000000; // 24 MHz
}

static double cycles_to_ms(uint64_t cycles) {
    return (double)cycles / (get_cycle_frequency() / 1000.0);
}

// Test initialization
static int initialize_test_environment(void) {
    printf("Initializing A* pathfinding test environment...\n");
    
    // Initialize memory allocator
    int result = agent_allocator_init(TEST_MEMORY_SIZE, TEST_EXPECTED_AGENTS);
    if (!result) {
        fprintf(stderr, "ERROR: Failed to initialize agent allocator\n");
        return 0;
    }
    
    // Initialize A* system
    result = astar_init(TEST_MAX_NODES, TEST_MAX_PATH_LENGTH);
    if (!result) {
        fprintf(stderr, "ERROR: Failed to initialize A* pathfinding system\n");
        return 0;
    }
    
    tests_initialized = 1;
    printf("Test environment initialized successfully\n");
    return 1;
}

static void cleanup_test_environment(void) {
    if (tests_initialized) {
        astar_cleanup();
        tests_initialized = 0;
        printf("Test environment cleaned up\n");
    }
}

// Individual test functions
static int test_basic_pathfinding(void) {
    printf("Running basic pathfinding test...\n");
    
    // Simple straight-line path from (0,0) to (10,0)
    uint32_t start_node = 0;                    // (0,0)
    uint32_t goal_node = 10;                   // (10,0)
    
    int result = astar_find_path(start_node, goal_node, 0);
    if (result <= 0) {
        printf("  FAILED: No path found for basic test\n");
        return 0;
    }
    
    uint32_t path_length = astar_get_path_length();
    if (path_length != 10) {
        printf("  FAILED: Expected path length 10, got %u\n", path_length);
        return 0;
    }
    
    printf("  PASSED: Basic pathfinding test\n");
    return 1;
}

static int test_diagonal_pathfinding(void) {
    printf("Running diagonal pathfinding test...\n");
    
    // Diagonal path from (0,0) to (10,10)
    uint32_t start_node = 0;                    // (0,0) = 0*64 + 0
    uint32_t goal_node = 10 * TEST_GRID_SIZE + 10; // (10,10) = 10*64 + 10
    
    int result = astar_find_path(start_node, goal_node, 0);
    if (result <= 0) {
        printf("  FAILED: No path found for diagonal test\n");
        return 0;
    }
    
    uint32_t path_length = astar_get_path_length();
    // Diagonal distance should be approximately 14 (10 * sqrt(2) ≈ 14.14)
    if (path_length < 10 || path_length > 20) {
        printf("  FAILED: Diagonal path length %u outside expected range [10,20]\n", path_length);
        return 0;
    }
    
    printf("  PASSED: Diagonal pathfinding test (length: %u)\n", path_length);
    return 1;
}

static int test_obstacle_avoidance(void) {
    printf("Running obstacle avoidance test...\n");
    
    // Create a vertical wall from (5,0) to (5,10)
    for (int y = 0; y <= 10; y++) {
        uint32_t obstacle_node = y * TEST_GRID_SIZE + 5;
        astar_set_dynamic_cost(obstacle_node, 255, 255); // Maximum cost (blocked)
    }
    
    // Path from (0,0) to (10,0) should go around the wall
    uint32_t start_node = 0;                    // (0,0)
    uint32_t goal_node = 10;                   // (10,0)
    
    int result = astar_find_path(start_node, goal_node, 1); // Use traffic costs
    if (result <= 0) {
        printf("  FAILED: No path found around obstacles\n");
        return 0;
    }
    
    uint32_t path_length = astar_get_path_length();
    // Path should be longer than direct route due to detour
    if (path_length <= 10) {
        printf("  FAILED: Path length %u too short, should detour around obstacles\n", path_length);
        return 0;
    }
    
    printf("  PASSED: Obstacle avoidance test (detour length: %u)\n", path_length);
    return 1;
}

static int test_no_path_scenario(void) {
    printf("Running no-path scenario test...\n");
    
    // Create complete vertical wall blocking path
    for (int y = 0; y < TEST_GRID_SIZE; y++) {
        for (int x = 5; x <= 7; x++) {
            uint32_t obstacle_node = y * TEST_GRID_SIZE + x;
            astar_set_dynamic_cost(obstacle_node, 255, 255);
        }
    }
    
    // Try to path from (0,0) to (10,0) - should be impossible
    uint32_t start_node = 0;
    uint32_t goal_node = 10;
    
    int result = astar_find_path(start_node, goal_node, 1);
    if (result > 0) {
        printf("  FAILED: Found path when none should exist\n");
        return 0;
    }
    
    if (result != -1) {
        printf("  FAILED: Expected -1 (no path), got %d\n", result);
        return 0;
    }
    
    printf("  PASSED: No-path scenario test\n");
    return 1;
}

// Performance test
static int test_performance_benchmark(void) {
    printf("Running performance benchmark...\n");
    
    const uint64_t num_iterations = 1000;
    gettimeofday(&start_time, NULL);
    
    uint64_t avg_cycles = pathfinding_performance_test(num_iterations);
    
    gettimeofday(&end_time, NULL);
    double elapsed_ms = get_time_diff_ms(&start_time, &end_time);
    double avg_time_ms = cycles_to_ms(avg_cycles);
    
    printf("  Performance results:\n");
    printf("    Total time: %.2f ms\n", elapsed_ms);
    printf("    Average cycles per pathfind: %llu\n", avg_cycles);
    printf("    Average time per pathfind: %.3f ms\n", avg_time_ms);
    printf("    Pathfinds per second: %.0f\n", 1000.0 / avg_time_ms);
    
    // Performance target: <1ms per pathfind for reasonable scenarios
    if (avg_time_ms > 1.0) {
        printf("  WARNING: Average pathfinding time %.3f ms exceeds 1ms target\n", avg_time_ms);
        return 0;
    }
    
    printf("  PASSED: Performance benchmark\n");
    return 1;
}

// Statistics test
static int test_statistics_collection(void) {
    printf("Running statistics collection test...\n");
    
    astar_statistics_t stats_before, stats_after;
    
    // Get initial statistics
    astar_get_statistics(&stats_before);
    
    // Perform several pathfinding operations
    for (int i = 0; i < 10; i++) {
        uint32_t start = i;
        uint32_t goal = (i + 32) * TEST_GRID_SIZE + i;
        astar_find_path(start, goal, 0);
    }
    
    // Get final statistics
    astar_get_statistics(&stats_after);
    
    // Verify statistics were updated
    if (stats_after.total_searches <= stats_before.total_searches) {
        printf("  FAILED: Total searches not incremented\n");
        return 0;
    }
    
    if (stats_after.total_cycles <= stats_before.total_cycles) {
        printf("  FAILED: Total cycles not incremented\n");
        return 0;
    }
    
    printf("  Statistics collected:\n");
    printf("    Total searches: %llu\n", stats_after.total_searches);
    printf("    Successful searches: %llu\n", stats_after.successful_searches);
    printf("    Total cycles: %llu\n", stats_after.total_cycles);
    printf("    Max iterations: %llu\n", stats_after.max_iterations);
    printf("    Cache hits: %llu\n", stats_after.cache_hits);
    printf("    Cache misses: %llu\n", stats_after.cache_misses);
    
    printf("  PASSED: Statistics collection test\n");
    return 1;
}

// Main test runner
int main(int argc, char* argv[]) {
    printf("=== SimCity A* Pathfinding Test Suite ===\n");
    printf("Agent C1: AI Systems Architect\n\n");
    
    // Initialize test environment
    if (!initialize_test_environment()) {
        return 1;
    }
    
    int total_tests = 0;
    int passed_tests = 0;
    
    // Run individual C tests
    struct {
        const char* name;
        int (*test_func)(void);
    } c_tests[] = {
        {"Basic Pathfinding", test_basic_pathfinding},
        {"Diagonal Pathfinding", test_diagonal_pathfinding},
        {"Obstacle Avoidance", test_obstacle_avoidance},
        {"No Path Scenario", test_no_path_scenario},
        {"Performance Benchmark", test_performance_benchmark},
        {"Statistics Collection", test_statistics_collection},
    };
    
    int num_c_tests = sizeof(c_tests) / sizeof(c_tests[0]);
    
    printf("Running %d C integration tests...\n\n", num_c_tests);
    
    for (int i = 0; i < num_c_tests; i++) {
        total_tests++;
        if (c_tests[i].test_func()) {
            passed_tests++;
        }
        
        // Reinitialize for each test to ensure clean state
        astar_cleanup();
        if (!astar_init(TEST_MAX_NODES, TEST_MAX_PATH_LENGTH)) {
            fprintf(stderr, "ERROR: Failed to reinitialize A* system\n");
            break;
        }
    }
    
    // Run assembly unit tests
    printf("\nRunning ARM64 assembly unit tests...\n");
    int assembly_tests_passed = pathfinding_run_all_tests();
    
    test_results_t* results = (test_results_t*)pathfinding_get_test_results();
    if (results) {
        total_tests += results->total_tests;
        passed_tests += results->passed_tests;
        
        printf("Assembly test results:\n");
        printf("  Total: %u, Passed: %u, Failed: %u\n", 
               results->total_tests, results->passed_tests, results->failed_tests);
        printf("  Average cycles: %llu (%.3f ms)\n", 
               results->avg_cycles, cycles_to_ms(results->avg_cycles));
    }
    
    // Run stress tests
    printf("\nRunning stress tests...\n");
    int stress_tests_passed = pathfinding_stress_test();
    total_tests += 3; // Stress test includes 3 sub-tests
    passed_tests += stress_tests_passed;
    
    // Print final summary
    printf("\n=== Test Summary ===\n");
    printf("Total tests: %d\n", total_tests);
    printf("Passed: %d\n", passed_tests);
    printf("Failed: %d\n", total_tests - passed_tests);
    printf("Success rate: %.1f%%\n", (double)passed_tests / total_tests * 100.0);
    
    // Print detailed assembly test summary
    pathfinding_print_test_summary();
    
    // Cleanup
    cleanup_test_environment();
    
    // Return non-zero if any tests failed
    int exit_code = (passed_tests == total_tests) ? 0 : 1;
    
    if (exit_code == 0) {
        printf("\n✅ All tests passed!\n");
    } else {
        printf("\n❌ Some tests failed!\n");
    }
    
    return exit_code;
}