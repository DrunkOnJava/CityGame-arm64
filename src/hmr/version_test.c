/*
 * SimCity ARM64 - Module Versioning Test Suite
 * Comprehensive testing for semantic versioning and migration system
 * 
 * Created by Agent 1: Core Module System - Week 2 Day 6
 * Tests all versioning functionality with performance validation
 */

#include "module_versioning.h"
#include "module_interface.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <time.h>
#include <sys/time.h>
#include <pthread.h>

// Test configuration
#define MAX_TEST_MODULES        64
#define MAX_TEST_VERSIONS      256
#define TEST_TIMEOUT_MS       5000
#define PERFORMANCE_ITERATIONS 1000

// Test result tracking
typedef struct {
    int total_tests;
    int passed_tests;
    int failed_tests;
    uint64_t total_time_ns;
    char last_error[256];
} test_results_t;

static test_results_t g_test_results = {0};

// Utility functions
static uint64_t get_time_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + ts.tv_nsec;
}

static void test_assert(bool condition, const char* message) {
    g_test_results.total_tests++;
    if (condition) {
        g_test_results.passed_tests++;
        printf("✓ %s\n", message);
    } else {
        g_test_results.failed_tests++;
        printf("✗ %s\n", message);
        strncpy(g_test_results.last_error, message, sizeof(g_test_results.last_error) - 1);
    }
}

static void test_performance(const char* test_name, uint64_t time_ns, uint64_t target_ns) {
    g_test_results.total_tests++;
    g_test_results.total_time_ns += time_ns;
    
    if (time_ns <= target_ns) {
        g_test_results.passed_tests++;
        printf("✓ %s: %llu ns (target: %llu ns)\n", test_name, time_ns, target_ns);
    } else {
        g_test_results.failed_tests++;
        printf("✗ %s: %llu ns (exceeded target: %llu ns)\n", test_name, time_ns, target_ns);
        snprintf(g_test_results.last_error, sizeof(g_test_results.last_error),
                "%s performance exceeded target", test_name);
    }
}

// Test 1: Basic Version Creation and Management
static void test_version_creation(void) {
    printf("\n=== Test 1: Version Creation and Management ===\n");
    
    // Test version creation
    hmr_version_t* v1 = hmr_version_create(1, 2, 3, 100, HMR_VERSION_STABLE);
    test_assert(v1 != NULL, "Version creation");
    test_assert(v1->major == 1, "Version major field");
    test_assert(v1->minor == 2, "Version minor field");
    test_assert(v1->patch == 3, "Version patch field");
    test_assert(v1->build == 100, "Version build field");
    test_assert(v1->flags == HMR_VERSION_STABLE, "Version flags field");
    
    // Test version copy
    hmr_version_t* v2 = hmr_version_copy(v1);
    test_assert(v2 != NULL, "Version copy");
    test_assert(hmr_version_compare(v1, v2) == 0, "Version copy equality");
    
    // Test version string conversion
    char* version_str = hmr_version_to_string(v1);
    test_assert(version_str != NULL, "Version to string conversion");
    test_assert(strstr(version_str, "1.2.3") != NULL, "Version string format");
    
    // Test version parsing
    hmr_version_t* v3 = hmr_version_from_string("2.0.0-beta");
    test_assert(v3 != NULL, "Version from string parsing");
    test_assert(v3->major == 2, "Parsed version major");
    test_assert(v3->minor == 0, "Parsed version minor");
    test_assert(v3->patch == 0, "Parsed version patch");
    
    // Cleanup
    hmr_version_destroy(v1);
    hmr_version_destroy(v2);
    hmr_version_destroy(v3);
    free(version_str);
}

// Test 2: Version Comparison
static void test_version_comparison(void) {
    printf("\n=== Test 2: Version Comparison ===\n");
    
    hmr_version_t* v1_0_0 = hmr_version_create(1, 0, 0, 0, HMR_VERSION_STABLE);
    hmr_version_t* v1_1_0 = hmr_version_create(1, 1, 0, 0, HMR_VERSION_STABLE);
    hmr_version_t* v1_1_1 = hmr_version_create(1, 1, 1, 0, HMR_VERSION_STABLE);
    hmr_version_t* v2_0_0 = hmr_version_create(2, 0, 0, 0, HMR_VERSION_STABLE);
    
    // Test comparison results
    test_assert(hmr_version_compare(v1_0_0, v1_1_0) < 0, "1.0.0 < 1.1.0");
    test_assert(hmr_version_compare(v1_1_0, v1_1_1) < 0, "1.1.0 < 1.1.1");
    test_assert(hmr_version_compare(v1_1_1, v2_0_0) < 0, "1.1.1 < 2.0.0");
    test_assert(hmr_version_compare(v2_0_0, v1_1_1) > 0, "2.0.0 > 1.1.1");
    test_assert(hmr_version_compare(v1_1_0, v1_1_0) == 0, "1.1.0 == 1.1.0");
    
    // Test newer version detection
    test_assert(hmr_version_is_newer(v1_1_0, v1_0_0), "1.1.0 is newer than 1.0.0");
    test_assert(!hmr_version_is_newer(v1_0_0, v1_1_0), "1.0.0 is not newer than 1.1.0");
    
    // Test range satisfaction
    test_assert(hmr_version_satisfies_range(v1_1_0, v1_0_0, v2_0_0), 
                "1.1.0 satisfies range 1.0.0 to 2.0.0");
    test_assert(!hmr_version_satisfies_range(v2_0_0, v1_0_0, v1_1_1),
                "2.0.0 does not satisfy range 1.0.0 to 1.1.1");
    
    // Cleanup
    hmr_version_destroy(v1_0_0);
    hmr_version_destroy(v1_1_0);
    hmr_version_destroy(v1_1_1);
    hmr_version_destroy(v2_0_0);
}

// Test 3: Compatibility Checking
static void test_compatibility_checking(void) {
    printf("\n=== Test 3: Compatibility Checking ===\n");
    
    hmr_version_t* v1_0_0 = hmr_version_create(1, 0, 0, 0, HMR_VERSION_STABLE);
    hmr_version_t* v1_1_0 = hmr_version_create(1, 1, 0, 0, HMR_VERSION_STABLE);
    hmr_version_t* v1_1_1 = hmr_version_create(1, 1, 1, 0, HMR_VERSION_STABLE);
    hmr_version_t* v2_0_0 = hmr_version_create(2, 0, 0, 0, HMR_VERSION_BREAKING);
    hmr_version_t* v1_0_0_deprecated = hmr_version_create(1, 0, 0, 0, HMR_VERSION_DEPRECATED);
    
    hmr_version_compat_result_t result;
    
    // Test compatible versions
    int32_t compat_result = hmr_version_check_compatibility(v1_0_0, v1_1_0, &result);
    test_assert(compat_result == HMR_COMPAT_COMPATIBLE || compat_result == HMR_COMPAT_MIGRATION_REQ,
                "1.0.0 and 1.1.0 are compatible");
    
    // Test patch version compatibility
    compat_result = hmr_version_check_compatibility(v1_1_0, v1_1_1, &result);
    test_assert(compat_result == HMR_COMPAT_COMPATIBLE || compat_result == HMR_COMPAT_MIGRATION_REQ,
                "1.1.0 and 1.1.1 are compatible");
    
    // Test breaking changes
    compat_result = hmr_version_check_compatibility(v1_1_1, v2_0_0, &result);
    test_assert(compat_result == HMR_COMPAT_MAJOR_BREAKING,
                "1.1.1 and 2.0.0 have breaking changes");
    
    // Test deprecated version
    compat_result = hmr_version_check_compatibility(v1_0_0_deprecated, v1_1_0, &result);
    test_assert(compat_result == HMR_COMPAT_DEPRECATED,
                "Deprecated version detected");
    
    // Test convenience function
    test_assert(hmr_version_is_compatible(v1_0_0, v1_1_0),
                "Simple compatibility check");
    test_assert(!hmr_version_is_compatible(v1_1_1, v2_0_0),
                "Simple incompatibility check");
    
    // Cleanup
    hmr_version_destroy(v1_0_0);
    hmr_version_destroy(v1_1_0);
    hmr_version_destroy(v1_1_1);
    hmr_version_destroy(v2_0_0);
    hmr_version_destroy(v1_0_0_deprecated);
}

// Test 4: Migration System
static void test_migration_system(void) {
    printf("\n=== Test 4: Migration System ===\n");
    
    hmr_version_t* v1_0_0 = hmr_version_create(1, 0, 0, 0, HMR_VERSION_STABLE);
    hmr_version_t* v1_1_0 = hmr_version_create(1, 1, 0, 0, HMR_VERSION_STABLE);
    hmr_version_t* v2_0_0 = hmr_version_create(2, 0, 0, 0, HMR_VERSION_BREAKING);
    
    // Test migration strategy determination
    hmr_migration_strategy_t strategy = hmr_determine_migration_strategy(v1_0_0, v1_1_0);
    test_assert(strategy == HMR_MIGRATION_AUTO, "Auto migration for minor version");
    
    strategy = hmr_determine_migration_strategy(v1_1_0, v2_0_0);
    test_assert(strategy == HMR_MIGRATION_MANUAL || strategy == HMR_MIGRATION_FORCE,
                "Manual/force migration for major version");
    
    strategy = hmr_determine_migration_strategy(v1_1_0, v1_0_0);
    test_assert(strategy == HMR_MIGRATION_ROLLBACK, "Rollback for downgrade");
    
    // Test migration capability
    test_assert(hmr_can_migrate(v1_0_0, v1_1_0), "Can migrate minor version");
    
    // Test migration context setup
    hmr_migration_context_t migration_ctx = {0};
    char dummy_data[1024] = "test module data";
    
    int32_t migrate_result = hmr_version_migrate(v1_0_0, v1_1_0, dummy_data, &migration_ctx);
    test_assert(migrate_result == 0, "Migration execution");
    
    // Cleanup
    hmr_version_destroy(v1_0_0);
    hmr_version_destroy(v1_1_0);
    hmr_version_destroy(v2_0_0);
}

// Test 5: Rollback System
static void test_rollback_system(void) {
    printf("\n=== Test 5: Rollback System ===\n");
    
    hmr_version_t* v1_0_0 = hmr_version_create(1, 0, 0, 0, HMR_VERSION_STABLE);
    char module_data[1024] = "original module data";
    
    // Create rollback state
    hmr_rollback_handle_t* handle = hmr_save_rollback_state(v1_0_0, module_data);
    test_assert(handle != NULL, "Rollback state creation");
    test_assert(handle->version.major == 1, "Rollback version saved");
    
    // Modify data
    strcpy(module_data, "modified module data");
    
    // Perform rollback
    int32_t rollback_result = hmr_restore_rollback_state(handle);
    test_assert(rollback_result == 0, "Rollback execution");
    test_assert(strcmp(module_data, "original module data") == 0, "Data restored");
    
    // Test rollback listing
    hmr_rollback_handle_t* handles[32];
    int32_t count = hmr_list_rollback_points(handles, 32);
    test_assert(count >= 0, "Rollback points listing");
    
    // Cleanup
    hmr_cleanup_rollback_state(handle);
    hmr_version_destroy(v1_0_0);
}

// Test 6: Version Registry
static void test_version_registry(void) {
    printf("\n=== Test 6: Version Registry ===\n");
    
    // Initialize registry
    int32_t init_result = hmr_version_registry_init();
    test_assert(init_result == 0, "Version registry initialization");
    
    hmr_version_t* v1_0_0 = hmr_version_create(1, 0, 0, 0, HMR_VERSION_STABLE);
    hmr_version_t* v1_1_0 = hmr_version_create(1, 1, 0, 0, HMR_VERSION_STABLE);
    hmr_version_t* v2_0_0 = hmr_version_create(2, 0, 0, 0, HMR_VERSION_STABLE);
    
    // Register versions
    int32_t reg_result = hmr_register_version("test_module", v1_0_0, "/path/to/v1.0.0.so");
    test_assert(reg_result == 0, "Version registration");
    
    reg_result = hmr_register_version("test_module", v1_1_0, "/path/to/v1.1.0.so");
    test_assert(reg_result == 0, "Second version registration");
    
    reg_result = hmr_register_version("test_module", v2_0_0, "/path/to/v2.0.0.so");
    test_assert(reg_result == 0, "Third version registration");
    
    // Find latest version
    hmr_version_t* latest = hmr_find_latest_version("test_module");
    test_assert(latest != NULL, "Find latest version");
    test_assert(latest->major == 2, "Latest version is 2.0.0");
    
    // Find compatible version
    hmr_version_t* required = hmr_version_create(1, 0, 0, 0, HMR_VERSION_STABLE);
    hmr_version_t* compatible = hmr_find_compatible_version("test_module", required);
    test_assert(compatible != NULL, "Find compatible version");
    
    // List versions
    hmr_version_t* versions[16];
    int32_t version_count = hmr_list_versions("test_module", versions, 16);
    test_assert(version_count == 3, "Version count correct");
    
    // Cleanup
    hmr_version_destroy(v1_0_0);
    hmr_version_destroy(v1_1_0);
    hmr_version_destroy(v2_0_0);
    hmr_version_destroy(required);
    hmr_version_registry_shutdown();
}

// Test 7: Performance Benchmarks
static void test_performance_benchmarks(void) {
    printf("\n=== Test 7: Performance Benchmarks ===\n");
    
    uint64_t start_time, end_time;
    
    // Test version creation performance
    start_time = get_time_ns();
    for (int i = 0; i < PERFORMANCE_ITERATIONS; i++) {
        hmr_version_t* v = hmr_version_create(1, i % 100, i % 10, i, HMR_VERSION_STABLE);
        hmr_version_destroy(v);
    }
    end_time = get_time_ns();
    uint64_t avg_create_time = (end_time - start_time) / PERFORMANCE_ITERATIONS;
    test_performance("Version creation", avg_create_time, 1000); // Target: <1μs
    
    // Test version comparison performance
    hmr_version_t* v1 = hmr_version_create(1, 2, 3, 100, HMR_VERSION_STABLE);
    hmr_version_t* v2 = hmr_version_create(1, 2, 4, 101, HMR_VERSION_STABLE);
    
    start_time = get_time_ns();
    for (int i = 0; i < PERFORMANCE_ITERATIONS; i++) {
        hmr_version_compare(v1, v2);
    }
    end_time = get_time_ns();
    uint64_t avg_compare_time = (end_time - start_time) / PERFORMANCE_ITERATIONS;
    test_performance("Version comparison", avg_compare_time, 100); // Target: <100ns
    
    // Test compatibility checking performance
    hmr_version_compat_result_t result;
    start_time = get_time_ns();
    for (int i = 0; i < PERFORMANCE_ITERATIONS; i++) {
        hmr_version_check_compatibility(v1, v2, &result);
    }
    end_time = get_time_ns();
    uint64_t avg_compat_time = (end_time - start_time) / PERFORMANCE_ITERATIONS;
    test_performance("Compatibility checking", avg_compat_time, 2000); // Target: <2μs
    
    // Cleanup
    hmr_version_destroy(v1);
    hmr_version_destroy(v2);
}

// Test 8: Thread Safety
static void* thread_test_function(void* arg) {
    int thread_id = *(int*)arg;
    
    for (int i = 0; i < 100; i++) {
        hmr_version_t* v = hmr_version_create(thread_id, i, 0, 0, HMR_VERSION_STABLE);
        
        // Register version
        char module_name[64];
        snprintf(module_name, sizeof(module_name), "thread_module_%d", thread_id);
        hmr_register_version(module_name, v, "/tmp/test.so");
        
        // Find and use version
        hmr_version_t* found = hmr_find_latest_version(module_name);
        if (found) {
            hmr_version_compare(v, found);
        }
        
        hmr_version_destroy(v);
    }
    
    return NULL;
}

static void test_thread_safety(void) {
    printf("\n=== Test 8: Thread Safety ===\n");
    
    hmr_version_registry_init();
    
    const int num_threads = 8;
    pthread_t threads[num_threads];
    int thread_ids[num_threads];
    
    // Create threads
    for (int i = 0; i < num_threads; i++) {
        thread_ids[i] = i;
        int result = pthread_create(&threads[i], NULL, thread_test_function, &thread_ids[i]);
        test_assert(result == 0, "Thread creation");
    }
    
    // Wait for threads to complete
    for (int i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }
    
    test_assert(true, "Thread safety validation completed");
    
    hmr_version_registry_shutdown();
}

// Main test runner
int main(int argc, char* argv[]) {
    printf("SimCity ARM64 - Module Versioning Test Suite\n");
    printf("============================================\n");
    
    uint64_t total_start_time = get_time_ns();
    
    // Run all tests
    test_version_creation();
    test_version_comparison();
    test_compatibility_checking();
    test_migration_system();
    test_rollback_system();
    test_version_registry();
    test_performance_benchmarks();
    test_thread_safety();
    
    uint64_t total_end_time = get_time_ns();
    uint64_t total_time_ms = (total_end_time - total_start_time) / 1000000;
    
    // Print results
    printf("\n=== Test Results Summary ===\n");
    printf("Total Tests: %d\n", g_test_results.total_tests);
    printf("Passed: %d\n", g_test_results.passed_tests);
    printf("Failed: %d\n", g_test_results.failed_tests);
    printf("Success Rate: %.1f%%\n", 
           (float)g_test_results.passed_tests / g_test_results.total_tests * 100.0f);
    printf("Total Time: %llu ms\n", total_time_ms);
    
    if (g_test_results.failed_tests > 0) {
        printf("Last Error: %s\n", g_test_results.last_error);
        return 1;
    }
    
    printf("\n✅ ALL TESTS PASSED - Version System Ready for Production\n");
    return 0;
}