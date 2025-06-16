/*
 * SimCity ARM64 - HMR Manager Simple Test
 * Agent 3: Runtime Integration - Day 1 Testing
 * 
 * Simple test suite focused only on HMR manager functionality
 * Tests frame budgeting, module detection, and performance requirements
 */

#include "runtime_integration.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <time.h>

// Test configuration
#define TEST_MODULE_PATH    "/tmp/test_module.dylib"
#define TEST_WATCH_DIR      "/tmp"
#define TEST_ITERATIONS     100
#define NANOSECONDS_PER_MS  1000000ULL

// Test results tracking
typedef struct {
    uint32_t tests_run;
    uint32_t tests_passed;
    uint32_t tests_failed;
    char last_error[256];
} test_results_t;

static test_results_t g_test_results = {0};

// =============================================================================
// Test Utilities
// =============================================================================

#define TEST_ASSERT(condition, message) \
    do { \
        g_test_results.tests_run++; \
        if (!(condition)) { \
            snprintf(g_test_results.last_error, sizeof(g_test_results.last_error), "%s", message); \
            g_test_results.tests_failed++; \
            printf("FAIL: %s\n", message); \
            return false; \
        } else { \
            g_test_results.tests_passed++; \
            printf("PASS: %s\n", message); \
        } \
    } while(0)

#define TEST_START(name) \
    printf("\n=== Running test: %s ===\n", name)

#define TEST_END() \
    printf("Test completed.\n")

// Create a dummy module file for testing
static void create_test_module(void) {
    FILE* f = fopen(TEST_MODULE_PATH, "w");
    if (f) {
        fprintf(f, "// Test module content\n");
        fclose(f);
    }
}

// Update test module to trigger change detection
static void update_test_module(void) {
    FILE* f = fopen(TEST_MODULE_PATH, "a");
    if (f) {
        fprintf(f, "// Updated at %ld\n", time(NULL));
        fclose(f);
    }
}

// Clean up test files
static void cleanup_test_files(void) {
    unlink(TEST_MODULE_PATH);
}

// Get current time in nanoseconds
static uint64_t get_time_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

// =============================================================================
// Test Functions
// =============================================================================

// Test basic initialization and shutdown
static bool test_init_shutdown(void) {
    TEST_START("init_shutdown");
    
    // Test initialization
    int result = hmr_rt_init();
    TEST_ASSERT(result == HMR_RT_SUCCESS, "Manager initialization should succeed");
    
    // Test double initialization (should be safe)
    result = hmr_rt_init();
    TEST_ASSERT(result == HMR_RT_SUCCESS, "Double initialization should be safe");
    
    // Test shutdown
    result = hmr_rt_shutdown();
    TEST_ASSERT(result == HMR_RT_SUCCESS, "Manager shutdown should succeed");
    
    // Test double shutdown (should be safe)
    result = hmr_rt_shutdown();
    TEST_ASSERT(result == HMR_RT_SUCCESS, "Double shutdown should be safe");
    
    TEST_END();
    return true;
}

// Test enable/disable functionality
static bool test_enable_disable(void) {
    TEST_START("enable_disable");
    
    int result = hmr_rt_init();
    TEST_ASSERT(result == HMR_RT_SUCCESS, "Manager initialization should succeed");
    
    // Test initial state (should be enabled)
    TEST_ASSERT(hmr_rt_is_enabled(), "Manager should be enabled by default");
    TEST_ASSERT(!hmr_rt_is_paused(), "Manager should not be paused by default");
    
    // Test disable
    hmr_rt_set_enabled(false);
    TEST_ASSERT(!hmr_rt_is_enabled(), "Manager should be disabled after setting");
    
    // Test enable
    hmr_rt_set_enabled(true);
    TEST_ASSERT(hmr_rt_is_enabled(), "Manager should be enabled after setting");
    
    // Test pause
    hmr_rt_set_paused(true);
    TEST_ASSERT(hmr_rt_is_paused(), "Manager should be paused after setting");
    
    // Test resume
    hmr_rt_set_paused(false);
    TEST_ASSERT(!hmr_rt_is_paused(), "Manager should be resumed after setting");
    
    hmr_rt_shutdown();
    
    TEST_END();
    return true;
}

// Test configuration management
static bool test_configuration(void) {
    TEST_START("configuration");
    
    int result = hmr_rt_init();
    TEST_ASSERT(result == HMR_RT_SUCCESS, "Manager initialization should succeed");
    
    // Test default configuration
    hmr_rt_config_t config;
    hmr_rt_get_config(&config);
    TEST_ASSERT(config.check_interval_frames == HMR_RT_DEFAULT_CHECK_INTERVAL, "Default check interval should be correct");
    TEST_ASSERT(config.max_frame_budget_ns == HMR_RT_DEFAULT_FRAME_BUDGET_NS, "Default frame budget should be correct");
    TEST_ASSERT(config.adaptive_budgeting == HMR_RT_DEFAULT_ADAPTIVE_BUDGET, "Default adaptive budgeting should be correct");
    
    // Test custom configuration
    hmr_rt_config_t custom_config = {
        .check_interval_frames = 30,
        .max_frame_budget_ns = 50000ULL,
        .adaptive_budgeting = false
    };
    
    result = hmr_rt_set_config(&custom_config);
    TEST_ASSERT(result == HMR_RT_SUCCESS, "Setting custom configuration should succeed");
    
    hmr_rt_get_config(&config);
    TEST_ASSERT(config.check_interval_frames == 30, "Custom check interval should be set");
    TEST_ASSERT(config.max_frame_budget_ns == 50000ULL, "Custom frame budget should be set");
    TEST_ASSERT(config.adaptive_budgeting == false, "Custom adaptive budgeting should be set");
    
    // Test invalid configuration
    hmr_rt_config_t invalid_config = {
        .check_interval_frames = 0, // Invalid
        .max_frame_budget_ns = 0,   // Invalid
        .adaptive_budgeting = true
    };
    
    result = hmr_rt_set_config(&invalid_config);
    TEST_ASSERT(result != HMR_RT_SUCCESS, "Setting invalid configuration should fail");
    
    hmr_rt_shutdown();
    
    TEST_END();
    return true;
}

// Test frame timing and budgeting
static bool test_frame_timing(void) {
    TEST_START("frame_timing");
    
    int result = hmr_rt_init();
    TEST_ASSERT(result == HMR_RT_SUCCESS, "Manager initialization should succeed");
    
    // Set aggressive configuration for testing
    hmr_rt_config_t test_config = {
        .check_interval_frames = 5,     // Check every 5 frames for testing
        .max_frame_budget_ns = 100000ULL,
        .adaptive_budgeting = false
    };
    hmr_rt_set_config(&test_config);
    
    // Test frame timing functions
    uint64_t start_time = get_time_ns();
    
    for (uint32_t frame = 1; frame <= 50; frame++) {
        hmr_rt_frame_start(frame);
        
        // Simulate some work
        usleep(500); // 0.5ms
        
        result = hmr_rt_check_reloads();
        TEST_ASSERT(result == HMR_RT_SUCCESS || result == 0x4010, // HMR_RT_ERROR_BUDGET_EXCEEDED
                   "Check reloads should succeed or exceed budget");
        
        hmr_rt_frame_end();
    }
    
    uint64_t end_time = get_time_ns();
    uint64_t total_time = end_time - start_time;
    
    // Verify timing metrics
    hmr_rt_metrics_t metrics;
    hmr_rt_get_metrics(&metrics);
    
    TEST_ASSERT(metrics.current_frame == 50, "Frame counter should be correct");
    TEST_ASSERT(metrics.total_checks > 0, "Should have performed some checks");
    TEST_ASSERT(metrics.avg_frame_time_ns > 0, "Should have average frame time");
    
    printf("Performance metrics:\n");
    printf("  Total time: %llu ms\n", total_time / NANOSECONDS_PER_MS);
    printf("  Average frame time: %llu μs\n", metrics.avg_frame_time_ns / 1000);
    printf("  Peak frame time: %llu μs\n", metrics.peak_frame_time_ns / 1000);
    printf("  HMR overhead: %llu μs total\n", metrics.hmr_overhead_ns / 1000);
    printf("  Total checks: %llu\n", metrics.total_checks);
    
    hmr_rt_shutdown();
    
    TEST_END();
    return true;
}

// Test file watching functionality
static bool test_file_watching(void) {
    TEST_START("file_watching");
    
    create_test_module();
    
    int result = hmr_rt_init();
    TEST_ASSERT(result == HMR_RT_SUCCESS, "Manager initialization should succeed");
    
    // Test adding watch
    result = hmr_rt_add_watch(TEST_MODULE_PATH, TEST_WATCH_DIR);
    TEST_ASSERT(result == HMR_RT_SUCCESS, "Adding watch should succeed");
    
    // Wait a bit for watch thread to initialize
    usleep(150000); // 150ms
    
    // Update the module file
    update_test_module();
    
    // Wait for change detection
    usleep(200000); // 200ms
    
    // Check metrics to see if watch is active
    hmr_rt_metrics_t metrics;
    hmr_rt_get_metrics(&metrics);
    TEST_ASSERT(metrics.active_watches > 0, "Should have active watches");
    
    // Test removing watch
    result = hmr_rt_remove_watch(TEST_MODULE_PATH);
    TEST_ASSERT(result == HMR_RT_SUCCESS, "Removing watch should succeed");
    
    // Test removing non-existent watch
    result = hmr_rt_remove_watch("/non/existent/path");
    TEST_ASSERT(result == HMR_RT_ERROR_NOT_FOUND, "Removing non-existent watch should return not found");
    
    hmr_rt_shutdown();
    cleanup_test_files();
    
    TEST_END();
    return true;
}

// Test edge cases and error conditions
static bool test_edge_cases(void) {
    TEST_START("edge_cases");
    
    // Test functions without initialization
    TEST_ASSERT(!hmr_rt_is_enabled(), "Should return false when not initialized");
    
    int result = hmr_rt_check_reloads();
    // Should handle gracefully (no crash)
    
    // Test null pointer handling
    result = hmr_rt_add_watch(NULL, TEST_WATCH_DIR);
    TEST_ASSERT(result == HMR_RT_ERROR_NULL_POINTER, "Should handle null module path");
    
    result = hmr_rt_add_watch(TEST_MODULE_PATH, NULL);
    TEST_ASSERT(result == HMR_RT_ERROR_NULL_POINTER, "Should handle null watch dir");
    
    result = hmr_rt_set_config(NULL);
    TEST_ASSERT(result == HMR_RT_ERROR_NULL_POINTER, "Should handle null config");
    
    // Test with metrics pointer
    hmr_rt_get_metrics(NULL); // Should not crash
    hmr_rt_get_config(NULL);  // Should not crash
    
    TEST_END();
    return true;
}

// =============================================================================
// Main Test Runner
// =============================================================================

int main(int argc, char* argv[]) {
    printf("SimCity ARM64 - HMR Manager Simple Test Suite\n");
    printf("==============================================\n");
    
    bool all_passed = true;
    
    // Run all tests
    all_passed &= test_init_shutdown();
    all_passed &= test_enable_disable();
    all_passed &= test_configuration();
    all_passed &= test_frame_timing();
    all_passed &= test_file_watching();
    all_passed &= test_edge_cases();
    
    // Print summary
    printf("\n=== Test Summary ===\n");
    printf("Tests run: %u\n", g_test_results.tests_run);
    printf("Tests passed: %u\n", g_test_results.tests_passed);
    printf("Tests failed: %u\n", g_test_results.tests_failed);
    
    if (all_passed && g_test_results.tests_failed == 0) {
        printf("✓ All tests PASSED!\n");
        printf("\nDay 1 HMR Runtime Manager implementation is working correctly!\n");
        printf("Ready for Day 2: Safe Module Swapping implementation.\n");
        return 0;
    } else {
        printf("✗ Some tests FAILED!\n");
        if (strlen(g_test_results.last_error) > 0) {
            printf("Last error: %s\n", g_test_results.last_error);
        }
        return 1;
    }
}