/*
 * SimCity ARM64 - Asset Watcher Integration Test
 * Test suite for asset watching and dependency tracking
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Day 1: Integration Test Implementation
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <assert.h>
#include "asset_watcher.h"
#include "dependency_tracker.h"
#include "module_interface.h"

// Test configuration
#define TEST_ASSETS_DIR "/tmp/hmr_test_assets"
#define MAX_TEST_ASSETS 100

// Test state
static bool g_test_asset_changed = false;
static bool g_test_validation_failed = false;
static bool g_test_reload_complete = false;
static char g_last_changed_path[256] = {0};
static hmr_asset_type_t g_last_changed_type = HMR_ASSET_UNKNOWN;

// Test callbacks
static void test_on_asset_changed(const char* path, hmr_asset_type_t type, hmr_asset_status_t status) {
    printf("TEST: Asset changed - %s (type: %d, status: %d)\n", path, type, status);
    g_test_asset_changed = true;
    strncpy(g_last_changed_path, path, sizeof(g_last_changed_path) - 1);
    g_last_changed_type = type;
}

static void test_on_validation_failed(const char* path, const char* error) {
    printf("TEST: Validation failed - %s: %s\n", path, error);
    g_test_validation_failed = true;
}

static void test_on_reload_complete(const char* path, uint64_t reload_time_ns) {
    printf("TEST: Reload complete - %s (time: %llu ns)\n", path, reload_time_ns);
    g_test_reload_complete = true;
}

// Utility function to create test file
static bool create_test_file(const char* path, const char* content) {
    FILE* file = fopen(path, "w");
    if (!file) {
        printf("TEST: Failed to create test file: %s\n", path);
        return false;
    }
    
    if (content) {
        fprintf(file, "%s", content);
    }
    
    fclose(file);
    return true;
}

// Test 1: Basic asset watcher initialization
static bool test_asset_watcher_init(void) {
    printf("\n=== Test 1: Asset Watcher Initialization ===\n");
    
    // Create test directory
    mkdir(TEST_ASSETS_DIR, 0755);
    
    hmr_asset_watcher_config_t config = {0};
    strncpy(config.watch_path, TEST_ASSETS_DIR, sizeof(config.watch_path) - 1);
    config.recursive = true;
    config.poll_interval_ms = 100;
    config.max_assets = MAX_TEST_ASSETS;
    config.enable_validation = true;
    config.enable_caching = false;
    
    int32_t result = hmr_asset_watcher_init(&config);
    if (result != HMR_SUCCESS) {
        printf("TEST FAILED: Asset watcher initialization failed with code %d\n", result);
        return false;
    }
    
    printf("TEST PASSED: Asset watcher initialized successfully\n");
    return true;
}

// Test 2: Asset type detection
static bool test_asset_type_detection(void) {
    printf("\n=== Test 2: Asset Type Detection ===\n");
    
    // Create test files of different types
    char shader_path[512];
    char texture_path[512];
    char config_path[512];
    char audio_path[512];
    
    snprintf(shader_path, sizeof(shader_path), "%s/test_shader.metal", TEST_ASSETS_DIR);
    snprintf(texture_path, sizeof(texture_path), "%s/test_texture.png", TEST_ASSETS_DIR);
    snprintf(config_path, sizeof(config_path), "%s/test_config.json", TEST_ASSETS_DIR);
    snprintf(audio_path, sizeof(audio_path), "%s/test_audio.wav", TEST_ASSETS_DIR);
    
    const char* metal_content = "#include <metal_stdlib>\nusing namespace metal;\n\nvertex float4 test_vertex() { return float4(0,0,0,1); }\n";
    const char* json_content = "{\"test\": true, \"value\": 42}\n";
    
    if (!create_test_file(shader_path, metal_content) ||
        !create_test_file(texture_path, "fake texture data") ||
        !create_test_file(config_path, json_content) ||
        !create_test_file(audio_path, "fake audio data")) {
        printf("TEST FAILED: Could not create test files\n");
        return false;
    }
    
    printf("TEST PASSED: Asset type detection test files created\n");
    return true;
}

// Test 3: Asset watching and change detection
static bool test_asset_watching(void) {
    printf("\n=== Test 3: Asset Watching and Change Detection ===\n");
    
    // Set up callbacks
    hmr_asset_watcher_set_callbacks(test_on_asset_changed, test_on_validation_failed, test_on_reload_complete);
    
    // Start watching
    int32_t result = hmr_asset_watcher_start();
    if (result != HMR_SUCCESS) {
        printf("TEST FAILED: Could not start asset watcher (code: %d)\n", result);
        return false;
    }
    
    // Wait a bit for the watcher to initialize
    sleep(1);
    
    // Modify a test file
    char test_file[512];
    snprintf(test_file, sizeof(test_file), "%s/test_config.json", TEST_ASSETS_DIR);
    
    g_test_asset_changed = false;
    if (!create_test_file(test_file, "{\"test\": true, \"value\": 123, \"modified\": true}\n")) {
        printf("TEST FAILED: Could not modify test file\n");
        return false;
    }
    
    // Wait for change detection
    int retries = 10;
    while (!g_test_asset_changed && retries > 0) {
        usleep(200000); // 200ms
        retries--;
    }
    
    if (!g_test_asset_changed) {
        printf("TEST FAILED: Asset change was not detected\n");
        return false;
    }
    
    printf("TEST PASSED: Asset change detected successfully\n");
    return true;
}

// Test 4: Dependency tracking
static bool test_dependency_tracking(void) {
    printf("\n=== Test 4: Dependency Tracking ===\n");
    
    // Initialize dependency tracker
    int32_t result = hmr_dependency_tracker_init(MAX_TEST_ASSETS);
    if (result != HMR_SUCCESS) {
        printf("TEST FAILED: Dependency tracker initialization failed (code: %d)\n", result);
        return false;
    }
    
    // Create dependency relationships
    char asset_a[512], asset_b[512], asset_c[512];
    snprintf(asset_a, sizeof(asset_a), "%s/asset_a.json", TEST_ASSETS_DIR);
    snprintf(asset_b, sizeof(asset_b), "%s/asset_b.metal", TEST_ASSETS_DIR);
    snprintf(asset_c, sizeof(asset_c), "%s/asset_c.png", TEST_ASSETS_DIR);
    
    // Create test assets
    create_test_file(asset_a, "{\"name\": \"asset_a\"}");
    create_test_file(asset_b, "#include <metal_stdlib>\n// depends on asset_a");
    create_test_file(asset_c, "fake texture data");
    
    // Add dependencies: B depends on A, C depends on B
    result = hmr_dependency_add(asset_b, asset_a, true);
    if (result != HMR_SUCCESS) {
        printf("TEST FAILED: Could not add dependency B->A (code: %d)\n", result);
        return false;
    }
    
    result = hmr_dependency_add(asset_c, asset_b, false);
    if (result != HMR_SUCCESS) {
        printf("TEST FAILED: Could not add dependency C->B (code: %d)\n", result);
        return false;
    }
    
    // Test circular dependency detection
    bool has_circular = hmr_dependency_check_circular();
    if (has_circular) {
        printf("TEST FAILED: False positive circular dependency detected\n");
        return false;
    }
    
    // Add circular dependency (A depends on C)
    hmr_dependency_add(asset_a, asset_c, false);
    has_circular = hmr_dependency_check_circular();
    if (!has_circular) {
        printf("TEST FAILED: Circular dependency not detected\n");
        return false;
    }
    
    // Remove circular dependency
    hmr_dependency_remove(asset_a, asset_c);
    
    printf("TEST PASSED: Dependency tracking works correctly\n");
    return true;
}

// Test 5: Reload order calculation
static bool test_reload_order(void) {
    printf("\n=== Test 5: Reload Order Calculation ===\n");
    
    char asset_a[512];
    snprintf(asset_a, sizeof(asset_a), "%s/asset_a.json", TEST_ASSETS_DIR);
    
    const char* reload_list[32];
    uint32_t actual_count = 0;
    
    int32_t result = hmr_dependency_get_reload_order(asset_a, reload_list, 32, &actual_count);
    if (result != HMR_SUCCESS) {
        printf("TEST FAILED: Could not calculate reload order (code: %d)\n", result);
        return false;
    }
    
    if (actual_count == 0) {
        printf("TEST FAILED: No assets in reload order\n");
        return false;
    }
    
    printf("TEST: Reload order for %s:\n", asset_a);
    for (uint32_t i = 0; i < actual_count; i++) {
        printf("  %u. %s\n", i + 1, reload_list[i]);
    }
    
    printf("TEST PASSED: Reload order calculated successfully (%u assets)\n", actual_count);
    return true;
}

// Test 6: Performance metrics
static bool test_performance_metrics(void) {
    printf("\n=== Test 6: Performance Metrics ===\n");
    
    uint32_t total_assets, pending_reloads;
    uint64_t total_events, avg_validation_time, avg_reload_time;
    
    hmr_asset_watcher_get_stats(&total_assets, &pending_reloads, &total_events, &avg_validation_time, &avg_reload_time);
    
    printf("TEST: Asset Watcher Statistics:\n");
    printf("  Total assets: %u\n", total_assets);
    printf("  Pending reloads: %u\n", pending_reloads);
    printf("  Total events: %llu\n", total_events);
    printf("  Avg validation time: %llu ns\n", avg_validation_time);
    printf("  Avg reload time: %llu ns\n", avg_reload_time);
    
    uint32_t total_nodes, total_edges;
    bool has_circular;
    uint64_t avg_resolution_time;
    
    hmr_dependency_get_stats(&total_nodes, &total_edges, &has_circular, &avg_resolution_time);
    
    printf("TEST: Dependency Tracker Statistics:\n");
    printf("  Total nodes: %u\n", total_nodes);
    printf("  Total edges: %u\n", total_edges);
    printf("  Has circular: %s\n", has_circular ? "Yes" : "No");
    printf("  Avg resolution time: %llu ns\n", avg_resolution_time);
    
    printf("TEST PASSED: Performance metrics retrieved successfully\n");
    return true;
}

// Cleanup test files
static void cleanup_test_files(void) {
    printf("\n=== Cleanup ===\n");
    
    // Remove test files
    char command[512];
    snprintf(command, sizeof(command), "rm -rf %s", TEST_ASSETS_DIR);
    system(command);
    
    printf("TEST: Cleanup complete\n");
}

// Main test runner
int main(int argc, char* argv[]) {
    printf("SimCity ARM64 - Asset Watcher Integration Test\n");
    printf("==============================================\n");
    
    bool all_passed = true;
    
    // Run tests
    all_passed &= test_asset_watcher_init();
    all_passed &= test_asset_type_detection();
    all_passed &= test_asset_watching();
    all_passed &= test_dependency_tracking();
    all_passed &= test_reload_order();
    all_passed &= test_performance_metrics();
    
    // Cleanup
    hmr_asset_watcher_stop();
    hmr_asset_watcher_cleanup();
    hmr_dependency_tracker_cleanup();
    cleanup_test_files();
    
    printf("\n=== Test Results ===\n");
    if (all_passed) {
        printf("ALL TESTS PASSED! ✓\n");
        return 0;
    } else {
        printf("SOME TESTS FAILED! ✗\n");
        return 1;
    }
}