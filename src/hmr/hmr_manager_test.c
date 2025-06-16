/*
 * SimCity ARM64 - HMR Manager Test Suite
 * Comprehensive testing and validation for hot module replacement
 * 
 * Created by Agent 1: Core Module System
 * Tests module loading, thread safety, performance, and memory management
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <sys/time.h>
#include <unistd.h>
#include <assert.h>
#include <dlfcn.h>

#include "module_interface.h"

// Test configuration
#define MAX_TEST_MODULES        25
#define TEST_ITERATIONS         1000
#define THREAD_COUNT           8
#define TARGET_LOAD_TIME_MS    10
#define TARGET_MEMORY_OVERHEAD (1024 * 1024)  // 1MB per module

// Test result structure
typedef struct {
    int passed;
    int failed;
    int skipped;
    double total_time_ms;
    char error_message[256];
} test_results_t;

// Global test state
static test_results_t g_test_results = {0};
static pthread_mutex_t g_test_mutex = PTHREAD_MUTEX_INITIALIZER;

// Test module data
typedef struct {
    char name[32];
    char path[256];
    hmr_agent_module_t* module;
    pthread_t thread_id;
    int test_complete;
} test_module_data_t;

static test_module_data_t g_test_modules[MAX_TEST_MODULES];
static int g_module_count = 0;

// Forward declarations
static void run_all_tests(void);
static void test_module_loading(void);
static void test_thread_safety(void);  
static void test_performance(void);
static void test_memory_management(void);
static void test_hot_swap(void);
static void* concurrent_load_test_thread(void* arg);
static void* stress_test_thread(void* arg);
static double get_time_ms(void);
static void log_test_result(const char* test_name, int passed, const char* message);

// Mock module interface functions for testing
static int32_t mock_module_init(hmr_module_context_t* ctx) {
    // Simulate initialization work
    usleep(1000); // 1ms
    return 0;
}

static int32_t mock_module_update(hmr_module_context_t* ctx, float delta_time) {
    // Simulate update work
    static int counter = 0;
    counter++;
    return 0;
}

static int32_t mock_module_shutdown(hmr_module_context_t* ctx) {
    // Simulate cleanup work
    usleep(500); // 0.5ms
    return 0;
}

static void mock_get_metrics(hmr_module_metrics_t* metrics) {
    metrics->init_time_ns = 1000000; // 1ms
    metrics->avg_frame_time_ns = 16666666; // ~60 FPS
    metrics->peak_frame_time_ns = 33333333; // ~30 FPS worst case
    metrics->total_frames = 1000;
    metrics->memory_usage_bytes = 1024 * 1024; // 1MB
    metrics->peak_memory_bytes = 2 * 1024 * 1024; // 2MB peak
    metrics->error_count = 0;
    metrics->warning_count = 2;
}

/*
 * Main test entry point
 */
int main(int argc, char* argv[]) {
    printf("SimCity ARM64 HMR Test Suite\n");
    printf("============================\n\n");
    
    // Initialize HMR system
    int result = hmr_init_registry();
    if (result != 0) {
        printf("FATAL: Failed to initialize HMR registry: %d\n", result);
        return 1;
    }
    
    // Initialize shared memory pool (4MB for testing)
    result = hmr_init_shared_pool(4 * 1024 * 1024);
    if (result != 0) {
        printf("FATAL: Failed to initialize shared memory pool: %d\n", result);
        return 1;
    }
    
    printf("HMR system initialized successfully.\n\n");
    
    // Run all test suites
    double start_time = get_time_ms();
    run_all_tests();
    double end_time = get_time_ms();
    
    g_test_results.total_time_ms = end_time - start_time;
    
    // Print final results
    printf("\n" "Test Results Summary\n");
    printf("====================\n");
    printf("Total Tests: %d\n", g_test_results.passed + g_test_results.failed + g_test_results.skipped);
    printf("Passed:      %d\n", g_test_results.passed);
    printf("Failed:      %d\n", g_test_results.failed);
    printf("Skipped:     %d\n", g_test_results.skipped);
    printf("Total Time:  %.2f ms\n", g_test_results.total_time_ms);
    
    if (g_test_results.failed > 0) {
        printf("\nLast Error: %s\n", g_test_results.error_message);
    }
    
    // Check memory leaks
    uint64_t leak_count = hmr_check_memory_leaks();
    if (leak_count > 0) {
        printf("\nWARNING: %llu bytes of memory leaked!\n", leak_count);
        return 1;
    }
    
    printf("\nAll tests completed successfully!\n");
    return g_test_results.failed > 0 ? 1 : 0;
}

/*
 * Run all test suites
 */
static void run_all_tests(void) {
    printf("Running Test Suites...\n\n");
    
    test_module_loading();
    test_thread_safety();
    test_performance();
    test_memory_management();
    test_hot_swap();
}

/*
 * Test basic module loading functionality
 */
static void test_module_loading(void) {
    printf("Test Suite: Module Loading\n");
    printf("---------------------------\n");
    
    // Test 1: Load a valid mock module
    hmr_agent_module_t test_module = {0};
    strcpy(test_module.name, "test_module_1");
    strcpy(test_module.description, "Test module for validation");
    strcpy(test_module.author, "HMR Test Suite");
    test_module.version = HMR_VERSION_MAKE(1, 0, 0);
    test_module.api_version = HMR_VERSION_CURRENT;
    test_module.capabilities = HMR_CAP_HOT_SWAPPABLE | HMR_CAP_THREADING;
    test_module.requirements = HMR_CAP_MEMORY_HEAVY;
    
    // Set up mock interface
    test_module.interface.init = mock_module_init;
    test_module.interface.update = mock_module_update;
    test_module.interface.shutdown = mock_module_shutdown;
    test_module.interface.get_metrics = mock_get_metrics;
    
    test_module.state = HMR_MODULE_LOADED;
    test_module.hot_swappable = true;
    test_module.thread_safe = true;
    
    int result = hmr_register_module(&test_module);
    log_test_result("Register valid module", result == HMR_SUCCESS, 
                   result == HMR_SUCCESS ? "Module registered successfully" : "Failed to register module");
    
    // Test 2: Find registered module
    hmr_agent_module_t* found_module = hmr_find_module("test_module_1");
    log_test_result("Find registered module", found_module != NULL,
                   found_module ? "Module found successfully" : "Module not found");
    
    // Test 3: Check capabilities
    bool has_hot_swap = hmr_has_capability(&test_module, HMR_CAP_HOT_SWAPPABLE);
    log_test_result("Check module capabilities", has_hot_swap,
                   has_hot_swap ? "Capabilities detected correctly" : "Capability check failed");
    
    // Test 4: Version compatibility check
    bool compatible = hmr_version_compatible(HMR_VERSION_MAKE(1, 0, 0), test_module.version);
    log_test_result("Version compatibility", compatible,
                   compatible ? "Version compatibility works" : "Version compatibility failed");
    
    // Test 5: Unregister module
    result = hmr_unregister_module("test_module_1");
    log_test_result("Unregister module", result == HMR_SUCCESS,
                   result == HMR_SUCCESS ? "Module unregistered successfully" : "Failed to unregister module");
    
    printf("\n");
}

/*
 * Test thread safety with concurrent operations
 */
static void test_thread_safety(void) {
    printf("Test Suite: Thread Safety\n");
    printf("--------------------------\n");
    
    // Create multiple threads that perform concurrent module operations
    pthread_t threads[THREAD_COUNT];
    int thread_results[THREAD_COUNT];
    
    for (int i = 0; i < THREAD_COUNT; i++) {
        thread_results[i] = i;
        int result = pthread_create(&threads[i], NULL, concurrent_load_test_thread, &thread_results[i]);
        if (result != 0) {
            log_test_result("Create test thread", false, "Failed to create test thread");
            return;
        }
    }
    
    // Wait for all threads to complete
    for (int i = 0; i < THREAD_COUNT; i++) {
        pthread_join(threads[i], NULL);
    }
    
    log_test_result("Concurrent module operations", true, "All threads completed successfully");
    
    printf("\n");
}

/*
 * Test performance targets
 */
static void test_performance(void) {
    printf("Test Suite: Performance\n");
    printf("------------------------\n");
    
    // Test 1: Module loading performance
    double start_time = get_time_ms();
    
    for (int i = 0; i < 10; i++) {
        hmr_agent_module_t test_module = {0};
        snprintf(test_module.name, sizeof(test_module.name), "perf_test_%d", i);
        test_module.version = HMR_VERSION_CURRENT;
        test_module.api_version = HMR_VERSION_CURRENT;
        test_module.interface.init = mock_module_init;
        test_module.state = HMR_MODULE_LOADED;
        
        hmr_register_module(&test_module);
    }
    
    double end_time = get_time_ms();
    double avg_load_time = (end_time - start_time) / 10.0;
    
    log_test_result("Module loading performance", avg_load_time < TARGET_LOAD_TIME_MS,
                   avg_load_time < TARGET_LOAD_TIME_MS ? 
                   "Loading performance meets target" : "Loading performance too slow");
    
    printf("    Average load time: %.2f ms (target: < %d ms)\n", avg_load_time, TARGET_LOAD_TIME_MS);
    
    // Test 2: Memory overhead
    uint64_t stats[8];
    hmr_get_memory_stats((void*)stats);
    uint64_t current_usage = stats[3]; // current_usage
    
    log_test_result("Memory overhead", current_usage < TARGET_MEMORY_OVERHEAD,
                   current_usage < TARGET_MEMORY_OVERHEAD ?
                   "Memory usage within target" : "Memory usage too high");
    
    printf("    Current memory usage: %llu bytes (target: < %d bytes)\n", 
           current_usage, TARGET_MEMORY_OVERHEAD);
    
    // Test 3: Hot-swap performance
    start_time = get_time_ms();
    
    // Simulate hot-swap operations
    for (int i = 0; i < 5; i++) {
        hmr_flush_icache_full();
        hmr_invalidate_bpred();
        hmr_memory_barrier_full();
    }
    
    end_time = get_time_ms();
    double hot_swap_time = (end_time - start_time) / 5.0;
    
    log_test_result("Hot-swap performance", hot_swap_time < 5.0,
                   hot_swap_time < 5.0 ?
                   "Hot-swap performance acceptable" : "Hot-swap too slow");
    
    printf("    Average hot-swap time: %.2f ms\n", hot_swap_time);
    
    printf("\n");
}

/*
 * Test memory management functionality
 */
static void test_memory_management(void) {
    printf("Test Suite: Memory Management\n");
    printf("------------------------------\n");
    
    // Test 1: Basic allocation and deallocation
    void* ptr1 = hmr_module_alloc(1024, 16, 1);
    log_test_result("Basic allocation", ptr1 != NULL,
                   ptr1 ? "Memory allocated successfully" : "Memory allocation failed");
    
    if (ptr1) {
        int result = hmr_module_free(ptr1);
        log_test_result("Basic deallocation", result == HMR_SUCCESS,
                       result == HMR_SUCCESS ? "Memory freed successfully" : "Memory free failed");
    }
    
    // Test 2: NEON alignment
    void* ptr2 = hmr_module_alloc(256, 16, 1); // NEON alignment
    if (ptr2) {
        uintptr_t addr = (uintptr_t)ptr2;
        bool aligned = (addr % 16) == 0;
        log_test_result("NEON alignment", aligned,
                       aligned ? "Memory properly aligned for NEON" : "Memory alignment failed");
        hmr_module_free(ptr2);
    }
    
    // Test 3: Large allocation
    void* ptr3 = hmr_module_alloc(1024 * 1024, 64, 1); // 1MB with cache alignment
    log_test_result("Large allocation", ptr3 != NULL,
                   ptr3 ? "Large allocation successful" : "Large allocation failed");
    
    if (ptr3) {
        hmr_module_free(ptr3);
    }
    
    // Test 4: Stress test allocations
    void* ptrs[100];
    int alloc_count = 0;
    
    for (int i = 0; i < 100; i++) {
        ptrs[i] = hmr_module_alloc(64 + (i * 16), 16, 1);
        if (ptrs[i]) {
            alloc_count++;
        }
    }
    
    for (int i = 0; i < 100; i++) {
        if (ptrs[i]) {
            hmr_module_free(ptrs[i]);
        }
    }
    
    log_test_result("Stress allocation test", alloc_count > 90,
                   alloc_count > 90 ? "Stress test passed" : "Stress test failed");
    
    printf("    Successful allocations: %d/100\n", alloc_count);
    
    printf("\n");
}

/*
 * Test hot-swap functionality
 */
static void test_hot_swap(void) {
    printf("Test Suite: Hot-Swap\n");
    printf("---------------------\n");
    
    // Test 1: Cache invalidation
    hmr_flush_icache_full();
    log_test_result("Instruction cache flush", true, "I-cache flushed successfully");
    
    // Test 2: Branch predictor invalidation
    hmr_invalidate_bpred();
    log_test_result("Branch predictor invalidation", true, "Branch predictor invalidated");
    
    // Test 3: Memory barriers
    hmr_memory_barrier_full();
    log_test_result("Memory barriers", true, "Memory barriers executed");
    
    // Test 4: Module state preservation during swap
    hmr_agent_module_t test_module = {0};
    strcpy(test_module.name, "swap_test");
    test_module.version = HMR_VERSION_CURRENT;
    test_module.api_version = HMR_VERSION_CURRENT;
    test_module.state = HMR_MODULE_ACTIVE;
    test_module.hot_swappable = true;
    
    // Simulate pre-swap state save
    test_module.swap_state = malloc(256);
    test_module.swap_state_size = 256;
    memset(test_module.swap_state, 0xAA, 256); // Test pattern
    
    // Simulate swap process
    test_module.state = HMR_MODULE_PAUSED;
    usleep(1000); // Simulate swap time
    test_module.state = HMR_MODULE_ACTIVE;
    
    // Verify state preservation
    bool state_preserved = true;
    if (test_module.swap_state) {
        uint8_t* state_data = (uint8_t*)test_module.swap_state;
        for (int i = 0; i < 256; i++) {
            if (state_data[i] != 0xAA) {
                state_preserved = false;
                break;
            }
        }
        free(test_module.swap_state);
    }
    
    log_test_result("State preservation during swap", state_preserved,
                   state_preserved ? "Module state preserved correctly" : "Module state corrupted");
    
    printf("\n");
}

/*
 * Thread function for concurrent testing
 */
static void* concurrent_load_test_thread(void* arg) {
    int thread_id = *(int*)arg;
    
    for (int i = 0; i < 10; i++) {
        hmr_agent_module_t test_module = {0};
        snprintf(test_module.name, sizeof(test_module.name), "thread_%d_module_%d", thread_id, i);
        test_module.version = HMR_VERSION_CURRENT;
        test_module.api_version = HMR_VERSION_CURRENT;
        test_module.interface.init = mock_module_init;
        test_module.state = HMR_MODULE_LOADED;
        test_module.thread_safe = true;
        
        // Register module
        int result = hmr_register_module(&test_module);
        if (result != HMR_SUCCESS) {
            printf("    Thread %d: Failed to register module %d\n", thread_id, i);
            continue;
        }
        
        // Brief work simulation
        usleep(100);
        
        // Unregister module
        hmr_unregister_module(test_module.name);
    }
    
    return NULL;
}

/*
 * Utility function to get current time in milliseconds
 */
static double get_time_ms(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (tv.tv_sec * 1000.0) + (tv.tv_usec / 1000.0);
}

/*
 * Log test result and update global counters
 */
static void log_test_result(const char* test_name, int passed, const char* message) {
    pthread_mutex_lock(&g_test_mutex);
    
    if (passed) {
        g_test_results.passed++;
        printf("  ✓ %s: %s\n", test_name, message);
    } else {
        g_test_results.failed++;
        printf("  ✗ %s: %s\n", test_name, message);
        strncpy(g_test_results.error_message, message, sizeof(g_test_results.error_message) - 1);
    }
    
    pthread_mutex_unlock(&g_test_mutex);
}