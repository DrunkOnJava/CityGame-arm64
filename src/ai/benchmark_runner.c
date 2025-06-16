/*
 * SimCity ARM64 Assembly - A* Pathfinding Benchmark Runner
 * Agent C1: AI Systems Architect
 * 
 * Comprehensive performance benchmarking for A* pathfinding
 * Tests various scenarios and measures performance characteristics
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>
#include <math.h>
#include <unistd.h>

// External assembly functions
extern int astar_init(uint32_t max_nodes, uint32_t max_path_length);
extern int astar_find_path(uint32_t start_node_id, uint32_t goal_node_id, int use_traffic_cost);
extern void astar_cleanup(void);
extern int astar_set_dynamic_cost(uint32_t node_id, uint8_t traffic_cost, uint8_t terrain_cost);
extern uint32_t astar_get_path_length(void);
extern uint32_t* astar_get_path_nodes(void);
extern void astar_get_statistics(void* stats_output);
extern uint64_t astar_benchmark(uint64_t num_iterations, uint32_t start_node, uint32_t goal_node);

// Agent allocator functions
extern int agent_allocator_init(uint64_t total_memory_size, uint64_t expected_agent_count);

// Benchmark configuration
#define BENCHMARK_GRID_SIZE 128
#define BENCHMARK_MAX_NODES (BENCHMARK_GRID_SIZE * BENCHMARK_GRID_SIZE)
#define BENCHMARK_MAX_PATH_LENGTH 1024
#define BENCHMARK_MEMORY_SIZE (256 * 1024 * 1024)  // 256MB for benchmarking
#define BENCHMARK_EXPECTED_AGENTS 1000000

#define NUM_WARMUP_ITERATIONS 100
#define NUM_BENCHMARK_ITERATIONS 1000
#define NUM_STRESS_ITERATIONS 10000

// Statistics structure
typedef struct {
    uint64_t total_searches;
    uint64_t successful_searches;
    uint64_t total_cycles;
    uint64_t max_iterations;
    uint64_t cache_hits;
    uint64_t cache_misses;
} astar_statistics_t;

// Benchmark results
typedef struct {
    const char* name;
    uint64_t iterations;
    double total_time_ms;
    double avg_time_ms;
    double min_time_ms;
    double max_time_ms;
    double std_deviation_ms;
    uint64_t avg_cycles;
    uint64_t successful_paths;
    double success_rate;
} benchmark_result_t;

// Global state
static struct timeval start_time, end_time;
static double* timing_samples = NULL;
static uint32_t current_sample = 0;

// Utility functions
static double get_time_diff_ms(struct timeval* start, struct timeval* end) {
    return (end->tv_sec - start->tv_sec) * 1000.0 + 
           (end->tv_usec - start->tv_usec) / 1000.0;
}

static uint64_t get_cycle_frequency(void) {
    return 24000000; // 24 MHz for Apple Silicon
}

static double cycles_to_ms(uint64_t cycles) {
    return (double)cycles / (get_cycle_frequency() / 1000.0);
}

static void start_timing(void) {
    gettimeofday(&start_time, NULL);
}

static double end_timing(void) {
    gettimeofday(&end_time, NULL);
    return get_time_diff_ms(&start_time, &end_time);
}

// Statistical calculations
static double calculate_mean(double* values, uint32_t count) {
    double sum = 0.0;
    for (uint32_t i = 0; i < count; i++) {
        sum += values[i];
    }
    return sum / count;
}

static double calculate_std_deviation(double* values, uint32_t count, double mean) {
    double sum_sq_diff = 0.0;
    for (uint32_t i = 0; i < count; i++) {
        double diff = values[i] - mean;
        sum_sq_diff += diff * diff;
    }
    return sqrt(sum_sq_diff / count);
}

static double find_min(double* values, uint32_t count) {
    double min_val = values[0];
    for (uint32_t i = 1; i < count; i++) {
        if (values[i] < min_val) {
            min_val = values[i];
        }
    }
    return min_val;
}

static double find_max(double* values, uint32_t count) {
    double max_val = values[0];
    for (uint32_t i = 1; i < count; i++) {
        if (values[i] > max_val) {
            max_val = values[i];
        }
    }
    return max_val;
}

// Random number generation for testing
static uint32_t random_seed = 12345;

static uint32_t fast_random(void) {
    random_seed = random_seed * 1103515245 + 12345;
    return random_seed;
}

static uint32_t random_node_id(void) {
    return fast_random() % BENCHMARK_MAX_NODES;
}

// Initialize benchmark environment
static int initialize_benchmark_environment(void) {
    printf("Initializing benchmark environment...\n");
    printf("  Grid size: %dx%d (%d nodes)\n", BENCHMARK_GRID_SIZE, BENCHMARK_GRID_SIZE, BENCHMARK_MAX_NODES);
    printf("  Memory allocation: %d MB\n", BENCHMARK_MEMORY_SIZE / (1024 * 1024));
    
    // Initialize memory allocator
    if (!agent_allocator_init(BENCHMARK_MEMORY_SIZE, BENCHMARK_EXPECTED_AGENTS)) {
        fprintf(stderr, "ERROR: Failed to initialize agent allocator\n");
        return 0;
    }
    
    // Initialize A* system
    if (!astar_init(BENCHMARK_MAX_NODES, BENCHMARK_MAX_PATH_LENGTH)) {
        fprintf(stderr, "ERROR: Failed to initialize A* pathfinding system\n");
        return 0;
    }
    
    // Allocate timing sample array
    timing_samples = malloc(NUM_STRESS_ITERATIONS * sizeof(double));
    if (!timing_samples) {
        fprintf(stderr, "ERROR: Failed to allocate timing sample array\n");
        return 0;
    }
    
    printf("Benchmark environment initialized successfully\n\n");
    return 1;
}

static void cleanup_benchmark_environment(void) {
    astar_cleanup();
    if (timing_samples) {
        free(timing_samples);
        timing_samples = NULL;
    }
    printf("Benchmark environment cleaned up\n");
}

// Benchmark scenarios
static benchmark_result_t benchmark_straight_line_paths(void) {
    printf("Benchmarking straight-line paths...\n");
    
    benchmark_result_t result = {
        .name = "Straight Line Paths",
        .iterations = NUM_BENCHMARK_ITERATIONS
    };
    
    current_sample = 0;
    uint64_t successful_paths = 0;
    
    start_timing();
    
    for (uint32_t i = 0; i < NUM_BENCHMARK_ITERATIONS; i++) {
        // Create horizontal straight-line path
        uint32_t y = (i % 64) + 32; // Keep in middle area
        uint32_t start_node = y * BENCHMARK_GRID_SIZE + 10;
        uint32_t goal_node = y * BENCHMARK_GRID_SIZE + 110;
        
        struct timeval iter_start, iter_end;
        gettimeofday(&iter_start, NULL);
        
        int path_result = astar_find_path(start_node, goal_node, 0);
        
        gettimeofday(&iter_end, NULL);
        
        if (path_result > 0) {
            successful_paths++;
        }
        
        if (current_sample < NUM_STRESS_ITERATIONS) {
            timing_samples[current_sample++] = get_time_diff_ms(&iter_start, &iter_end);
        }
    }
    
    result.total_time_ms = end_timing();
    result.successful_paths = successful_paths;
    result.success_rate = (double)successful_paths / NUM_BENCHMARK_ITERATIONS;
    
    if (current_sample > 0) {
        result.avg_time_ms = calculate_mean(timing_samples, current_sample);
        result.min_time_ms = find_min(timing_samples, current_sample);
        result.max_time_ms = find_max(timing_samples, current_sample);
        result.std_deviation_ms = calculate_std_deviation(timing_samples, current_sample, result.avg_time_ms);
    }
    
    return result;
}

static benchmark_result_t benchmark_diagonal_paths(void) {
    printf("Benchmarking diagonal paths...\n");
    
    benchmark_result_t result = {
        .name = "Diagonal Paths",
        .iterations = NUM_BENCHMARK_ITERATIONS
    };
    
    current_sample = 0;
    uint64_t successful_paths = 0;
    
    start_timing();
    
    for (uint32_t i = 0; i < NUM_BENCHMARK_ITERATIONS; i++) {
        // Create diagonal path
        uint32_t offset = i % 50;
        uint32_t start_node = (10 + offset) * BENCHMARK_GRID_SIZE + (10 + offset);
        uint32_t goal_node = (60 + offset) * BENCHMARK_GRID_SIZE + (60 + offset);
        
        struct timeval iter_start, iter_end;
        gettimeofday(&iter_start, NULL);
        
        int path_result = astar_find_path(start_node, goal_node, 0);
        
        gettimeofday(&iter_end, NULL);
        
        if (path_result > 0) {
            successful_paths++;
        }
        
        if (current_sample < NUM_STRESS_ITERATIONS) {
            timing_samples[current_sample++] = get_time_diff_ms(&iter_start, &iter_end);
        }
    }
    
    result.total_time_ms = end_timing();
    result.successful_paths = successful_paths;
    result.success_rate = (double)successful_paths / NUM_BENCHMARK_ITERATIONS;
    
    if (current_sample > 0) {
        result.avg_time_ms = calculate_mean(timing_samples, current_sample);
        result.min_time_ms = find_min(timing_samples, current_sample);
        result.max_time_ms = find_max(timing_samples, current_sample);
        result.std_deviation_ms = calculate_std_deviation(timing_samples, current_sample, result.avg_time_ms);
    }
    
    return result;
}

static benchmark_result_t benchmark_random_paths(void) {
    printf("Benchmarking random paths...\n");
    
    benchmark_result_t result = {
        .name = "Random Paths",
        .iterations = NUM_BENCHMARK_ITERATIONS
    };
    
    current_sample = 0;
    uint64_t successful_paths = 0;
    
    start_timing();
    
    for (uint32_t i = 0; i < NUM_BENCHMARK_ITERATIONS; i++) {
        uint32_t start_node = random_node_id();
        uint32_t goal_node = random_node_id();
        
        // Avoid trivial cases
        while (abs((int)start_node - (int)goal_node) < 100) {
            goal_node = random_node_id();
        }
        
        struct timeval iter_start, iter_end;
        gettimeofday(&iter_start, NULL);
        
        int path_result = astar_find_path(start_node, goal_node, 0);
        
        gettimeofday(&iter_end, NULL);
        
        if (path_result > 0) {
            successful_paths++;
        }
        
        if (current_sample < NUM_STRESS_ITERATIONS) {
            timing_samples[current_sample++] = get_time_diff_ms(&iter_start, &iter_end);
        }
    }
    
    result.total_time_ms = end_timing();
    result.successful_paths = successful_paths;
    result.success_rate = (double)successful_paths / NUM_BENCHMARK_ITERATIONS;
    
    if (current_sample > 0) {
        result.avg_time_ms = calculate_mean(timing_samples, current_sample);
        result.min_time_ms = find_min(timing_samples, current_sample);
        result.max_time_ms = find_max(timing_samples, current_sample);
        result.std_deviation_ms = calculate_std_deviation(timing_samples, current_sample, result.avg_time_ms);
    }
    
    return result;
}

static benchmark_result_t benchmark_obstacle_paths(void) {
    printf("Benchmarking paths with obstacles...\n");
    
    // Create scattered obstacles
    for (uint32_t i = 0; i < BENCHMARK_MAX_NODES / 20; i++) {
        uint32_t obstacle_node = random_node_id();
        astar_set_dynamic_cost(obstacle_node, 200, 200); // High cost obstacles
    }
    
    benchmark_result_t result = {
        .name = "Paths with Obstacles",
        .iterations = NUM_BENCHMARK_ITERATIONS
    };
    
    current_sample = 0;
    uint64_t successful_paths = 0;
    
    start_timing();
    
    for (uint32_t i = 0; i < NUM_BENCHMARK_ITERATIONS; i++) {
        uint32_t start_node = random_node_id();
        uint32_t goal_node = random_node_id();
        
        struct timeval iter_start, iter_end;
        gettimeofday(&iter_start, NULL);
        
        int path_result = astar_find_path(start_node, goal_node, 1); // Use traffic costs
        
        gettimeofday(&iter_end, NULL);
        
        if (path_result > 0) {
            successful_paths++;
        }
        
        if (current_sample < NUM_STRESS_ITERATIONS) {
            timing_samples[current_sample++] = get_time_diff_ms(&iter_start, &iter_end);
        }
    }
    
    result.total_time_ms = end_timing();
    result.successful_paths = successful_paths;
    result.success_rate = (double)successful_paths / NUM_BENCHMARK_ITERATIONS;
    
    if (current_sample > 0) {
        result.avg_time_ms = calculate_mean(timing_samples, current_sample);
        result.min_time_ms = find_min(timing_samples, current_sample);
        result.max_time_ms = find_max(timing_samples, current_sample);
        result.std_deviation_ms = calculate_std_deviation(timing_samples, current_sample, result.avg_time_ms);
    }
    
    return result;
}

static benchmark_result_t benchmark_stress_test(void) {
    printf("Running stress test with %d iterations...\n", NUM_STRESS_ITERATIONS);
    
    benchmark_result_t result = {
        .name = "Stress Test",
        .iterations = NUM_STRESS_ITERATIONS
    };
    
    current_sample = 0;
    uint64_t successful_paths = 0;
    
    start_timing();
    
    for (uint32_t i = 0; i < NUM_STRESS_ITERATIONS; i++) {
        uint32_t start_node = random_node_id();
        uint32_t goal_node = random_node_id();
        
        struct timeval iter_start, iter_end;
        gettimeofday(&iter_start, NULL);
        
        int path_result = astar_find_path(start_node, goal_node, 0);
        
        gettimeofday(&iter_end, NULL);
        
        if (path_result > 0) {
            successful_paths++;
        }
        
        timing_samples[current_sample++] = get_time_diff_ms(&iter_start, &iter_end);
        
        // Progress indicator
        if (i % 1000 == 0) {
            printf("  Progress: %d/%d (%.1f%%)\r", i, NUM_STRESS_ITERATIONS, 
                   (double)i / NUM_STRESS_ITERATIONS * 100.0);
            fflush(stdout);
        }
    }
    printf("\n");
    
    result.total_time_ms = end_timing();
    result.successful_paths = successful_paths;
    result.success_rate = (double)successful_paths / NUM_STRESS_ITERATIONS;
    
    result.avg_time_ms = calculate_mean(timing_samples, current_sample);
    result.min_time_ms = find_min(timing_samples, current_sample);
    result.max_time_ms = find_max(timing_samples, current_sample);
    result.std_deviation_ms = calculate_std_deviation(timing_samples, current_sample, result.avg_time_ms);
    
    return result;
}

// Print results
static void print_benchmark_result(const benchmark_result_t* result) {
    printf("\n--- %s ---\n", result->name);
    printf("Iterations: %llu\n", result->iterations);
    printf("Total time: %.2f ms\n", result->total_time_ms);
    printf("Average time: %.3f ms\n", result->avg_time_ms);
    printf("Min time: %.3f ms\n", result->min_time_ms);
    printf("Max time: %.3f ms\n", result->max_time_ms);
    printf("Std deviation: %.3f ms\n", result->std_deviation_ms);
    printf("Successful paths: %llu/%llu (%.1f%%)\n", 
           result->successful_paths, result->iterations, result->success_rate * 100.0);
    printf("Pathfinds per second: %.0f\n", 1000.0 / result->avg_time_ms);
    
    // Performance assessment
    if (result->avg_time_ms < 0.1) {
        printf("Performance: EXCELLENT (< 0.1ms)\n");
    } else if (result->avg_time_ms < 0.5) {
        printf("Performance: GOOD (< 0.5ms)\n");
    } else if (result->avg_time_ms < 1.0) {
        printf("Performance: ACCEPTABLE (< 1.0ms)\n");
    } else {
        printf("Performance: NEEDS OPTIMIZATION (> 1.0ms)\n");
    }
}

static void print_summary(benchmark_result_t* results, int num_results) {
    printf("\n=== BENCHMARK SUMMARY ===\n");
    
    double total_pathfinds = 0;
    double total_time = 0;
    double total_successful = 0;
    
    for (int i = 0; i < num_results; i++) {
        total_pathfinds += results[i].iterations;
        total_time += results[i].total_time_ms;
        total_successful += results[i].successful_paths;
    }
    
    printf("Overall statistics:\n");
    printf("  Total pathfinds: %.0f\n", total_pathfinds);
    printf("  Total time: %.2f ms\n", total_time);
    printf("  Overall average: %.3f ms per pathfind\n", total_time / total_pathfinds);
    printf("  Overall success rate: %.1f%%\n", total_successful / total_pathfinds * 100.0);
    printf("  Overall throughput: %.0f pathfinds/second\n", total_pathfinds / (total_time / 1000.0));
    
    // Get final A* statistics
    astar_statistics_t stats;
    astar_get_statistics(&stats);
    
    printf("\nA* Implementation Statistics:\n");
    printf("  Total searches: %llu\n", stats.total_searches);
    printf("  Successful searches: %llu\n", stats.successful_searches);
    printf("  Cache hit rate: %.1f%%\n", 
           (double)stats.cache_hits / (stats.cache_hits + stats.cache_misses) * 100.0);
    printf("  Average cycles per search: %llu\n", 
           stats.total_cycles / stats.total_searches);
    printf("  Max iterations observed: %llu\n", stats.max_iterations);
}

// Main benchmark runner
int main(int argc, char* argv[]) {
    printf("=== SimCity A* Pathfinding Benchmark Suite ===\n");
    printf("Agent C1: AI Systems Architect\n\n");
    
    // Parse command line arguments
    int run_stress_test = 0;
    if (argc > 1 && strcmp(argv[1], "--stress") == 0) {
        run_stress_test = 1;
        printf("Running in stress test mode\n\n");
    }
    
    // Initialize benchmark environment
    if (!initialize_benchmark_environment()) {
        return 1;
    }
    
    // Warmup phase
    printf("Warming up with %d iterations...\n", NUM_WARMUP_ITERATIONS);
    for (int i = 0; i < NUM_WARMUP_ITERATIONS; i++) {
        uint32_t start_node = random_node_id();
        uint32_t goal_node = random_node_id();
        astar_find_path(start_node, goal_node, 0);
    }
    printf("Warmup complete\n\n");
    
    // Run benchmarks
    benchmark_result_t results[5];
    int result_count = 0;
    
    results[result_count++] = benchmark_straight_line_paths();
    results[result_count++] = benchmark_diagonal_paths();
    results[result_count++] = benchmark_random_paths();
    results[result_count++] = benchmark_obstacle_paths();
    
    if (run_stress_test) {
        results[result_count++] = benchmark_stress_test();
    }
    
    // Print all results
    for (int i = 0; i < result_count; i++) {
        print_benchmark_result(&results[i]);
    }
    
    // Print summary
    print_summary(results, result_count);
    
    // Cleanup
    cleanup_benchmark_environment();
    
    printf("\n✅ Benchmark complete!\n");
    return 0;
}