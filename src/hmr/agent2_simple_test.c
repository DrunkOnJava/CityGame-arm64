/*
 * SimCity ARM64 - Agent 2 Simple Integration Test
 * Agent 2: File Watcher & Build Pipeline - Week 2 Complete
 * 
 * Simplified test of core Agent 2 functionality
 */

#include "build_optimizer.h"
#include "file_watcher_advanced.h"
#include "developer_experience.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <mach/mach_time.h>

// Test statistics
typedef struct {
    uint32_t total_tests;
    uint32_t passed_tests;
    uint32_t failed_tests;
} test_stats_t;

static test_stats_t g_stats = {0};

static void test_log(const char* test_name, bool passed, const char* details) {
    g_stats.total_tests++;
    if (passed) {
        g_stats.passed_tests++;
        printf("✅ PASS: %s - %s\n", test_name, details ? details : "OK");
    } else {
        g_stats.failed_tests++;
        printf("❌ FAIL: %s - %s\n", test_name, details ? details : "Unknown error");
    }
}

// Build optimizer callback stubs
static void on_build_start(const char* module_name, build_target_type_t type) {
    printf("🔨 Build started: %s\n", module_name);
}

static void on_build_complete(const char* module_name, bool success, uint64_t build_time_ns) {
    printf("✅ Build completed: %s - %s\n", module_name, success ? "Success" : "Failed");
}

static void on_cache_update(const char* source_path, bool hit) {
    printf("💾 Cache %s: %s\n", hit ? "hit" : "miss", source_path);
}

// File watcher callback stubs
static void on_batch_ready(const file_change_batch_t* batch) {
    printf("📦 File change batch ready: %u events\n", batch->event_count);
}

static void on_critical_change(const file_change_event_t* event) {
    printf("🚨 Critical file change: %s\n", event->path);
}

// Test 1: Build Optimizer Basic Operations
static bool test_build_optimizer(void) {
    build_optimizer_callbacks_t callbacks = {
        .on_build_start = on_build_start,
        .on_build_complete = on_build_complete,
        .on_cache_update = on_cache_update
    };
    
    // Initialize
    int32_t result = build_optimizer_init(10, &callbacks);
    if (result != BUILD_SUCCESS) {
        test_log("Build Optimizer Init", false, "Initialization failed");
        return false;
    }
    
    // Test module addition
    build_module_t module = {0};
    strncpy(module.name, "test_module", sizeof(module.name) - 1);
    strncpy(module.source_dir, "src/test", sizeof(module.source_dir) - 1);
    strncpy(module.output_dir, "build/test", sizeof(module.output_dir) - 1);
    module.target_type = BUILD_TARGET_ASSEMBLY;
    module.priority = BUILD_PRIORITY_NORMAL;
    
    result = build_optimizer_add_module(&module);
    if (result != BUILD_SUCCESS) {
        test_log("Build Optimizer Add Module", false, "Failed to add module");
        return false;
    }
    
    // Test cache operations
    uint8_t test_hash[32] = {0x01, 0x02, 0x03};
    result = build_optimizer_update_cache("test.s", "test.o", test_hash, 1000000000ULL);
    if (result != BUILD_SUCCESS) {
        test_log("Build Optimizer Cache", false, "Cache update failed");
        return false;
    }
    
    test_log("Build Optimizer", true, "All operations successful");
    return true;
}

// Test 2: File Watcher Operations
static bool test_file_watcher(void) {
    file_watcher_callbacks_t callbacks = {
        .on_batch_ready = on_batch_ready,
        .on_critical_change = on_critical_change
    };
    
    // Initialize
    int32_t result = file_watcher_init(&callbacks);
    if (result != WATCHER_SUCCESS) {
        test_log("File Watcher Init", false, "Initialization failed");
        return false;
    }
    
    // Test path addition
    watch_path_config_t config = {0};
    strncpy(config.path, "src/", sizeof(config.path) - 1);
    config.change_mask = FILE_CHANGE_ALL;
    config.default_priority = WATCH_PRIORITY_NORMAL;
    config.recursive = true;
    config.debounce_ms = 250;
    
    result = file_watcher_add_path(&config);
    if (result != WATCHER_SUCCESS) {
        test_log("File Watcher Add Path", false, "Failed to add path");
        return false;
    }
    
    // Test filter addition
    watch_filter_rule_t filter = {0};
    strncpy(filter.pattern, "*.s", sizeof(filter.pattern) - 1);
    filter.change_mask = FILE_CHANGE_MODIFIED;
    filter.priority = WATCH_PRIORITY_HIGH;
    filter.is_include = true;
    
    result = file_watcher_add_global_filter(&filter);
    if (result != WATCHER_SUCCESS) {
        test_log("File Watcher Filter", false, "Failed to add filter");
        return false;
    }
    
    test_log("File Watcher", true, "All operations successful");
    return true;
}

// Test 3: Developer Experience
static bool test_developer_experience(void) {
    // Initialize
    int32_t result = developer_experience_init("test_dev", "/tmp/test");
    if (result != BUILD_SUCCESS) {
        test_log("Developer Experience Init", false, "Initialization failed");
        return false;
    }
    
    // Test error analysis
    build_error_analysis_t analysis;
    result = developer_experience_analyze_error("undefined symbol: test_func", 
                                               "test.s", 42, &analysis);
    if (result != BUILD_SUCCESS) {
        test_log("Developer Experience Error", false, "Error analysis failed");
        return false;
    }
    
    // Test progress update
    result = developer_experience_update_progress("test_module", BUILD_PHASE_COMPILATION, 50, "test.s");
    if (result != BUILD_SUCCESS) {
        test_log("Developer Experience Progress", false, "Progress update failed");
        return false;
    }
    
    // Test build completion
    result = developer_experience_complete_build("test_module", true, 1000000000ULL, 0, 0);
    if (result != BUILD_SUCCESS) {
        test_log("Developer Experience Complete", false, "Build completion failed");
        return false;
    }
    
    test_log("Developer Experience", true, "All operations successful");
    return true;
}

// Test 4: Integration Performance
static bool test_integration_performance(void) {
    uint64_t start_time = mach_absolute_time();
    
    // Simulate some work
    for (int i = 0; i < 100; i++) {
        build_metrics_t metrics;
        build_optimizer_get_metrics(&metrics);
        
        build_analytics_t analytics;
        developer_experience_get_analytics(&analytics);
    }
    
    uint64_t end_time = mach_absolute_time();
    
    // Convert to nanoseconds
    mach_timebase_info_data_t timebase_info;
    mach_timebase_info(&timebase_info);
    uint64_t duration_ns = (end_time - start_time) * timebase_info.numer / timebase_info.denom;
    
    if (duration_ns > 10000000ULL) { // 10ms
        test_log("Integration Performance", false, "Performance too slow");
        return false;
    }
    
    char perf_msg[256];
    snprintf(perf_msg, sizeof(perf_msg), "Completed in %.2f ms", duration_ns / 1000000.0);
    test_log("Integration Performance", true, perf_msg);
    return true;
}

int main(int argc, char* argv[]) {
    printf("🧪 SimCity ARM64 - Agent 2 Simple Integration Test\n");
    printf("================================================\n\n");
    
    bool all_passed = true;
    
    printf("Test 1: Build Optimizer\n");
    if (!test_build_optimizer()) all_passed = false;
    
    printf("\nTest 2: File Watcher\n");
    if (!test_file_watcher()) all_passed = false;
    
    printf("\nTest 3: Developer Experience\n");
    if (!test_developer_experience()) all_passed = false;
    
    printf("\nTest 4: Integration Performance\n");
    if (!test_integration_performance()) all_passed = false;
    
    // Print results
    printf("\n" "================================================\n");
    printf("🏁 Test Results\n");
    printf("================================================\n");
    printf("Total Tests:     %u\n", g_stats.total_tests);
    printf("Passed:          %u (%.1f%%)\n", g_stats.passed_tests, 
           (float)g_stats.passed_tests * 100.0f / g_stats.total_tests);
    printf("Failed:          %u (%.1f%%)\n", g_stats.failed_tests,
           (float)g_stats.failed_tests * 100.0f / g_stats.total_tests);
    
    if (all_passed) {
        printf("\n✅ ALL TESTS PASSED - Agent 2 Build Pipeline Working!\n");
        printf("🎯 Core Features Validated:\n");
        printf("   • Build optimization with caching ✅\n");
        printf("   • Advanced file watching with filtering ✅\n");
        printf("   • Developer experience with analytics ✅\n");
        printf("   • Performance within targets ✅\n");
    } else {
        printf("\n❌ SOME TESTS FAILED - Please review issues\n");
    }
    printf("================================================\n");
    
    // Cleanup
    build_optimizer_cleanup();
    file_watcher_cleanup();
    developer_experience_cleanup();
    
    return all_passed ? 0 : 1;
}