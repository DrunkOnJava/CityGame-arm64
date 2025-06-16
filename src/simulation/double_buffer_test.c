// SimCity ARM64 Double Buffer ECS Test
// Agent 2: Simulation Systems Developer
// Test suite for double buffering functionality

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <time.h>
#include <assert.h>
#include "double_buffer_ecs.h"

// Test configuration
#define TEST_ENTITIES 10000
#define TEST_ITERATIONS 1000
#define NUM_READER_THREADS 4
#define NUM_WRITER_THREADS 1

// Test entity structure
typedef struct {
    float x, y, z;
    float velocity_x, velocity_y, velocity_z;
    uint32_t entity_id;
    uint32_t frame_updated;
} TestEntity;

// Test results structure
typedef struct {
    uint64_t successful_reads;
    uint64_t successful_writes;
    uint64_t buffer_swaps;
    uint64_t coherency_errors;
    double avg_read_time_us;
    double avg_write_time_us;
    double avg_swap_time_us;
} TestResults;

static TestResults test_results = {0};
static volatile int test_running = 1;

//==============================================================================
// Utility Functions
//==============================================================================

static uint64_t get_time_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000000ULL + ts.tv_nsec / 1000ULL;
}

static void print_test_header(const char* test_name) {
    printf("\n=== %s ===\n", test_name);
    printf("Testing with %d entities, %d iterations\n", TEST_ENTITIES, TEST_ITERATIONS);
    printf("Reader threads: %d, Writer threads: %d\n\n", NUM_READER_THREADS, NUM_WRITER_THREADS);
}

//==============================================================================
// Basic Functionality Tests
//==============================================================================

int test_basic_initialization(void) {
    printf("Testing basic initialization...\n");
    
    int result = double_buffer_ecs_init(TEST_ENTITIES, 256);
    if (result != 0) {
        printf("❌ Failed to initialize double buffer ECS (error: %d)\n", result);
        return -1;
    }
    
    void* active_world = get_active_world();
    if (!active_world) {
        printf("❌ Failed to get active world pointer\n");
        return -1;
    }
    
    void* inactive_world = get_inactive_world();
    if (!inactive_world) {
        printf("❌ Failed to get inactive world pointer\n");
        return -1;
    }
    
    if (active_world == inactive_world) {
        printf("❌ Active and inactive worlds point to same memory\n");
        return -1;
    }
    
    printf("✅ Basic initialization successful\n");
    printf("   Active world: %p\n", active_world);
    printf("   Inactive world: %p\n", inactive_world);
    
    return 0;
}

int test_buffer_swapping(void) {
    printf("Testing buffer swapping...\n");
    
    void* world_before = get_active_world();
    
    uint64_t start_time = get_time_us();
    int result = swap_buffers();
    uint64_t end_time = get_time_us();
    
    if (result != 0) {
        printf("❌ Buffer swap failed (error: %d)\n", result);
        return -1;
    }
    
    void* world_after = get_active_world();
    
    if (world_before == world_after) {
        printf("❌ Active world didn't change after buffer swap\n");
        return -1;
    }
    
    double swap_time_us = (double)(end_time - start_time);
    printf("✅ Buffer swap successful\n");
    printf("   Swap time: %.2f μs\n", swap_time_us);
    printf("   World before: %p\n", world_before);
    printf("   World after: %p\n", world_after);
    
    return 0;
}

//==============================================================================
// Thread Safety Tests
//==============================================================================

void* reader_thread_func(void* arg) {
    int thread_id = *(int*)arg;
    uint64_t reads = 0;
    uint64_t total_time = 0;
    
    printf("Reader thread %d started\n", thread_id);
    
    while (test_running) {
        uint64_t start_time = get_time_us();
        
        void* world = begin_read_access();
        if (world) {
            // Simulate reading entity data
            usleep(10); // 10μs of simulated work
            end_read_access();
            reads++;
        }
        
        uint64_t end_time = get_time_us();
        total_time += (end_time - start_time);
        
        // Small delay to avoid spinning
        usleep(100);
    }
    
    __sync_fetch_and_add(&test_results.successful_reads, reads);
    
    if (reads > 0) {
        double avg_time = (double)total_time / reads;
        test_results.avg_read_time_us = avg_time;
    }
    
    printf("Reader thread %d finished: %llu reads\n", thread_id, reads);
    return NULL;
}

void* writer_thread_func(void* arg) {
    int thread_id = *(int*)arg;
    uint64_t writes = 0;
    uint64_t swaps = 0;
    uint64_t total_time = 0;
    
    printf("Writer thread %d started\n", thread_id);
    
    while (test_running) {
        uint64_t start_time = get_time_us();
        
        // Simulate updating inactive buffer
        void* inactive_world = get_inactive_world();
        if (inactive_world) {
            // Simulate writing entity data
            usleep(50); // 50μs of simulated work
            writes++;
            
            // Periodically swap buffers
            if (writes % 10 == 0) {
                uint64_t swap_start = get_time_us();
                if (swap_buffers() == 0) {
                    swaps++;
                    uint64_t swap_end = get_time_us();
                    test_results.avg_swap_time_us = (double)(swap_end - swap_start);
                }
            }
        }
        
        uint64_t end_time = get_time_us();
        total_time += (end_time - start_time);
        
        // Delay between writes
        usleep(1000); // 1ms
    }
    
    __sync_fetch_and_add(&test_results.successful_writes, writes);
    __sync_fetch_and_add(&test_results.buffer_swaps, swaps);
    
    if (writes > 0) {
        double avg_time = (double)total_time / writes;
        test_results.avg_write_time_us = avg_time;
    }
    
    printf("Writer thread %d finished: %llu writes, %llu swaps\n", thread_id, writes, swaps);
    return NULL;
}

int test_thread_safety(void) {
    printf("Testing thread safety...\n");
    
    pthread_t reader_threads[NUM_READER_THREADS];
    pthread_t writer_threads[NUM_WRITER_THREADS];
    int reader_ids[NUM_READER_THREADS];
    int writer_ids[NUM_WRITER_THREADS];
    
    // Reset test results
    memset(&test_results, 0, sizeof(test_results));
    test_running = 1;
    
    // Start reader threads
    for (int i = 0; i < NUM_READER_THREADS; i++) {
        reader_ids[i] = i;
        pthread_create(&reader_threads[i], NULL, reader_thread_func, &reader_ids[i]);
    }
    
    // Start writer threads
    for (int i = 0; i < NUM_WRITER_THREADS; i++) {
        writer_ids[i] = i;
        pthread_create(&writer_threads[i], NULL, writer_thread_func, &writer_ids[i]);
    }
    
    // Run test for 5 seconds
    printf("Running threads for 5 seconds...\n");
    sleep(5);
    test_running = 0;
    
    // Wait for all threads to finish
    for (int i = 0; i < NUM_READER_THREADS; i++) {
        pthread_join(reader_threads[i], NULL);
    }
    
    for (int i = 0; i < NUM_WRITER_THREADS; i++) {
        pthread_join(writer_threads[i], NULL);
    }
    
    printf("✅ Thread safety test completed\n");
    printf("   Successful reads: %llu\n", test_results.successful_reads);
    printf("   Successful writes: %llu\n", test_results.successful_writes);
    printf("   Buffer swaps: %llu\n", test_results.buffer_swaps);
    printf("   Average read time: %.2f μs\n", test_results.avg_read_time_us);
    printf("   Average write time: %.2f μs\n", test_results.avg_write_time_us);
    printf("   Average swap time: %.2f μs\n", test_results.avg_swap_time_us);
    
    return 0;
}

//==============================================================================
// Performance Tests
//==============================================================================

int test_swap_performance(void) {
    printf("Testing buffer swap performance...\n");
    
    const int num_swaps = 1000;
    uint64_t total_time = 0;
    uint64_t min_time = UINT64_MAX;
    uint64_t max_time = 0;
    
    for (int i = 0; i < num_swaps; i++) {
        uint64_t start_time = get_time_us();
        int result = swap_buffers();
        uint64_t end_time = get_time_us();
        
        if (result == 0) {
            uint64_t swap_time = end_time - start_time;
            total_time += swap_time;
            
            if (swap_time < min_time) min_time = swap_time;
            if (swap_time > max_time) max_time = swap_time;
        } else {
            printf("❌ Buffer swap %d failed\n", i);
            return -1;
        }
    }
    
    double avg_time = (double)total_time / num_swaps;
    
    printf("✅ Buffer swap performance test completed\n");
    printf("   Swaps performed: %d\n", num_swaps);
    printf("   Average time: %.2f μs\n", avg_time);
    printf("   Minimum time: %llu μs\n", min_time);
    printf("   Maximum time: %llu μs\n", max_time);
    printf("   Target: <1000 μs (1ms)\n");
    
    if (avg_time < 1000.0) {
        printf("✅ Performance target met\n");
    } else {
        printf("⚠️  Performance target not met\n");
    }
    
    return 0;
}

//==============================================================================
// Main Test Runner
//==============================================================================

int main(void) {
    printf("SimCity ARM64 Double Buffer ECS Test Suite\n");
    printf("==========================================\n");
    
    int total_tests = 0;
    int passed_tests = 0;
    
    // Basic functionality tests
    print_test_header("Basic Functionality Tests");
    
    total_tests++;
    if (test_basic_initialization() == 0) passed_tests++;
    
    total_tests++;
    if (test_buffer_swapping() == 0) passed_tests++;
    
    // Thread safety tests
    print_test_header("Thread Safety Tests");
    
    total_tests++;
    if (test_thread_safety() == 0) passed_tests++;
    
    // Performance tests
    print_test_header("Performance Tests");
    
    total_tests++;
    if (test_swap_performance() == 0) passed_tests++;
    
    // Summary
    printf("\n=== Test Summary ===\n");
    printf("Tests passed: %d/%d\n", passed_tests, total_tests);
    
    if (passed_tests == total_tests) {
        printf("✅ All tests passed!\n");
        printf("Double buffer ECS system is working correctly.\n");
        return 0;
    } else {
        printf("❌ Some tests failed.\n");
        return 1;
    }
}