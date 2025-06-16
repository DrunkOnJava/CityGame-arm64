/*
 * SimCity ARM64 - HMR Unified Integration Test Suite
 * Agent 0: HMR Orchestrator - Week 2, Day 6
 * 
 * Comprehensive test suite covering all 6 agent interactions
 * Tests cross-agent API compatibility and system integration
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <assert.h>
#include <sys/time.h>
#include <errno.h>

// Include unified HMR interface
#include "../../include/interfaces/hmr_unified.h"

// Test utilities and mocks
#include "mocks/agent_mocks.c"

// =============================================================================
// Test Framework
// =============================================================================

typedef struct {
    const char* name;
    int (*test_func)(void);
    bool agent_dependency[6];  // Which agents this test requires
} hmr_test_case_t;

typedef struct {
    int total_tests;
    int passed_tests;
    int failed_tests;
    int skipped_tests;
    uint64_t total_time_ns;
} hmr_test_results_t;

static hmr_test_results_t g_test_results = {0};

#define HMR_TEST(name, func, ...) \
    { .name = name, .test_func = func, .agent_dependency = {__VA_ARGS__} }

#define HMR_ASSERT(condition, message) \
    do { \
        if (!(condition)) { \
            printf("  FAIL: %s (line %d)\n", message, __LINE__); \
            return -1; \
        } \
    } while(0)

#define HMR_ASSERT_EQ(actual, expected, message) \
    do { \
        if ((actual) != (expected)) { \
            printf("  FAIL: %s - expected %d, got %d (line %d)\n", message, expected, actual, __LINE__); \
            return -1; \
        } \
    } while(0)

#define HMR_ASSERT_NE(actual, unexpected, message) \
    do { \
        if ((actual) == (unexpected)) { \
            printf("  FAIL: %s - got unexpected value %d (line %d)\n", message, unexpected, __LINE__); \
            return -1; \
        } \
    } while(0)

static uint64_t get_timestamp_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

// =============================================================================
// Mock Agent System
// =============================================================================

static bool g_agent_enabled[6] = {true, true, false, true, true, true}; // Agent 2 needs completion
static pthread_t g_agent_threads[6];
static volatile bool g_system_running = false;

// Simulate agent lifecycles for testing
static void* mock_agent_worker(void* arg) {
    int agent_id = *(int*)arg;
    
    while (g_system_running) {
        // Simulate agent heartbeat
        hmr_atomic_set_agent_status(agent_id, 2); // active
        usleep(10000); // 10ms
    }
    
    return NULL;
}

static int start_mock_agents(void) {
    g_system_running = true;
    
    for (int i = 0; i < 6; i++) {
        if (g_agent_enabled[i]) {
            static int agent_ids[6] = {0, 1, 2, 3, 4, 5};
            if (pthread_create(&g_agent_threads[i], NULL, mock_agent_worker, &agent_ids[i]) != 0) {
                return -1;
            }
        }
    }
    
    return 0;
}

static void stop_mock_agents(void) {
    g_system_running = false;
    
    for (int i = 0; i < 6; i++) {
        if (g_agent_enabled[i]) {
            pthread_join(g_agent_threads[i], NULL);
        }
    }
}

// =============================================================================
// Agent 0: Orchestrator Tests
// =============================================================================

static int test_orchestrator_init_shutdown(void) {
    printf("  Testing orchestrator initialization and shutdown...\n");
    
    int result = hmr_orchestrator_init();
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Orchestrator init should succeed");
    
    // Verify shared control block is initialized
    hmr_shared_control_t* control = hmr_get_shared_control();
    HMR_ASSERT(control != NULL, "Shared control block should be available");
    HMR_ASSERT_EQ(control->magic, HMR_MAGIC_NUMBER, "Magic number should be correct");
    HMR_ASSERT_EQ(control->version, HMR_VERSION, "Version should be correct");
    
    result = hmr_orchestrator_shutdown();
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Orchestrator shutdown should succeed");
    
    return 0;
}

static int test_agent_registration(void) {
    printf("  Testing agent registration...\n");
    
    int result = hmr_orchestrator_init();
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Orchestrator init should succeed");
    
    // Register all agents
    for (int i = 0; i < 6; i++) {
        if (g_agent_enabled[i]) {
            char agent_name[32];
            snprintf(agent_name, sizeof(agent_name), "agent_%d", i);
            result = hmr_register_agent(i, agent_name);
            HMR_ASSERT_EQ(result, HMR_SUCCESS, "Agent registration should succeed");
        }
    }
    
    hmr_orchestrator_shutdown();
    return 0;
}

static int test_message_system(void) {
    printf("  Testing inter-agent message system...\n");
    
    int result = hmr_orchestrator_init();
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Orchestrator init should succeed");
    
    // Create test message
    hmr_message_t message = {
        .type = HMR_MSG_MODULE_DISCOVERED,
        .sender_id = HMR_AGENT_ORCHESTRATOR,
        .recipient_id = 0, // broadcast
        .timestamp = HMR_GET_TIMESTAMP(),
        .data_size = 0,
        .priority = 1,
        .data = NULL,
        .correlation_id = 12345
    };
    
    result = hmr_broadcast_message(&message);
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Message broadcast should succeed");
    
    hmr_orchestrator_shutdown();
    return 0;
}

// =============================================================================
// Agent 1: Module System Tests
// =============================================================================

static int test_module_system_init(void) {
    printf("  Testing module system initialization...\n");
    
    int result = hmr_module_system_init();
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Module system init should succeed");
    
    // Verify module registry is available
    hmr_module_registry_t* registry = hmr_get_module_registry();
    HMR_ASSERT(registry != NULL, "Module registry should be available");
    
    return 0;
}

static int test_module_lifecycle(void) {
    printf("  Testing module lifecycle management...\n");
    
    hmr_module_system_init();
    
    // Create mock module info
    hmr_module_info_t module_info = {0};
    strncpy(module_info.name, "test_module", sizeof(module_info.name));
    strncpy(module_info.path, "/tmp/test_module.dylib", sizeof(module_info.path));
    module_info.version = HMR_UNIFIED_VERSION_CURRENT;
    module_info.agent_id = HMR_AGENT_MODULE_SYSTEM;
    module_info.state = HMR_MODULE_STATE_UNKNOWN;
    module_info.capabilities = HMR_CAP_HOT_SWAPPABLE;
    
    // Test module registration
    int result = hmr_module_register(&module_info);
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Module registration should succeed");
    
    // Test module lookup
    hmr_module_info_t* found = hmr_module_find("test_module");
    HMR_ASSERT(found != NULL, "Module should be found after registration");
    HMR_ASSERT(strcmp(found->name, "test_module") == 0, "Found module should have correct name");
    
    // Test state updates
    result = hmr_update_module_state("test_module", HMR_MODULE_STATE_LOADING);
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Module state update should succeed");
    
    // Test module unregistration
    result = hmr_module_unregister("test_module");
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Module unregistration should succeed");
    
    found = hmr_module_find("test_module");
    HMR_ASSERT(found == NULL, "Module should not be found after unregistration");
    
    return 0;
}

// =============================================================================
// Agent 3: Runtime Integration Tests
// =============================================================================

static int test_runtime_init_shutdown(void) {
    printf("  Testing runtime integration init/shutdown...\n");
    
    int result = hmr_runtime_init();
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Runtime init should succeed");
    
    HMR_ASSERT(hmr_runtime_is_enabled(), "Runtime should be enabled by default");
    HMR_ASSERT(!hmr_runtime_is_paused(), "Runtime should not be paused by default");
    
    result = hmr_runtime_shutdown();
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Runtime shutdown should succeed");
    
    return 0;
}

static int test_runtime_frame_integration(void) {
    printf("  Testing runtime frame integration...\n");
    
    hmr_runtime_init();
    
    // Test frame lifecycle
    for (uint32_t frame = 0; frame < 10; frame++) {
        hmr_runtime_frame_start(frame);
        
        // Simulate frame work
        usleep(1000); // 1ms
        
        // Check for reloads (should not exceed budget)
        int result = hmr_runtime_check_reloads();
        HMR_ASSERT(result == HMR_SUCCESS || result == HMR_ERROR_BUDGET_EXCEEDED, 
                   "Reload check should succeed or indicate budget exceeded");
        
        hmr_runtime_frame_end();
    }
    
    hmr_runtime_shutdown();
    return 0;
}

static int test_runtime_watch_system(void) {
    printf("  Testing runtime watch system...\n");
    
    hmr_runtime_init();
    
    // Add watch for test module
    int result = hmr_runtime_add_watch("/tmp/test_module.s", "/tmp");
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Adding watch should succeed");
    
    // Remove watch
    result = hmr_runtime_remove_watch("/tmp/test_module.s");
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Removing watch should succeed");
    
    hmr_runtime_shutdown();
    return 0;
}

// =============================================================================
// Agent 4: Developer Tools Tests
// =============================================================================

static int test_debug_system_init(void) {
    printf("  Testing debug system initialization...\n");
    
    int result = hmr_debug_init();
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Debug system init should succeed");
    
    return 0;
}

static int test_dev_server_lifecycle(void) {
    printf("  Testing development server lifecycle...\n");
    
    hmr_debug_init();
    
    // Start dev server on alternative port to avoid conflicts
    int result = hmr_debug_dev_server_init(8081);
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Dev server init should succeed");
    
    HMR_ASSERT(hmr_debug_dev_server_is_running(), "Dev server should be running");
    HMR_ASSERT_EQ(hmr_debug_get_client_count(), 0, "Should have no clients initially");
    
    // Test notifications
    hmr_debug_notify_build_start("test_module");
    hmr_debug_notify_build_success("test_module", 150);
    hmr_debug_notify_module_reload("test_module", true);
    
    hmr_debug_dev_server_shutdown();
    HMR_ASSERT(!hmr_debug_dev_server_is_running(), "Dev server should be stopped");
    
    return 0;
}

static int test_metrics_collection(void) {
    printf("  Testing unified metrics collection...\n");
    
    hmr_debug_init();
    
    // Start profiling
    int result = hmr_debug_profile_start();
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Profile start should succeed");
    
    // Simulate some activity
    usleep(5000); // 5ms
    
    // Stop profiling and get metrics
    hmr_unified_metrics_t metrics = {0};
    result = hmr_debug_profile_stop(&metrics);
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Profile stop should succeed");
    
    // Verify metrics were collected
    HMR_ASSERT(metrics.uptime_seconds > 0, "Uptime should be recorded");
    
    return 0;
}

// =============================================================================
// Agent 5: Asset Pipeline Tests
// =============================================================================

static int test_asset_pipeline_init(void) {
    printf("  Testing asset pipeline initialization...\n");
    
    int result = hmr_asset_pipeline_init();
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Asset pipeline init should succeed");
    
    return 0;
}

static int test_asset_watcher_lifecycle(void) {
    printf("  Testing asset watcher lifecycle...\n");
    
    hmr_asset_pipeline_init();
    
    // Configure asset watcher
    hmr_asset_watcher_config_t config = {
        .watch_path = "/tmp/assets",
        .extension_count = 0,
        .recursive = true,
        .poll_interval_ms = 100,
        .max_assets = 1000,
        .enable_validation = true,
        .enable_caching = true
    };
    
    int result = hmr_asset_watcher_init(&config);
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Asset watcher init should succeed");
    
    result = hmr_asset_watcher_start();
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Asset watcher start should succeed");
    
    // Get stats
    uint32_t total_assets, pending_reloads;
    uint64_t total_events, avg_validation_time, avg_reload_time;
    hmr_asset_watcher_get_stats(&total_assets, &pending_reloads, &total_events, 
                                &avg_validation_time, &avg_reload_time);
    
    result = hmr_asset_watcher_stop();
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Asset watcher stop should succeed");
    
    hmr_asset_watcher_cleanup();
    
    return 0;
}

// =============================================================================
// Cross-Agent Integration Tests
// =============================================================================

static int test_full_system_integration(void) {
    printf("  Testing full system integration...\n");
    
    // Initialize all available agents
    int result;
    
    result = hmr_orchestrator_init();
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Orchestrator init should succeed");
    
    result = hmr_module_system_init();
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Module system init should succeed");
    
    result = hmr_runtime_init();
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Runtime init should succeed");
    
    result = hmr_debug_init();
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Debug system init should succeed");
    
    result = hmr_asset_pipeline_init();
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Asset pipeline init should succeed");
    
    // Start mock agents
    start_mock_agents();
    
    // Simulate real HMR workflow: file change -> build -> reload -> notification
    printf("    Simulating HMR workflow...\n");
    
    // 1. Register test module
    hmr_module_info_t module = {0};
    strncpy(module.name, "integration_test_module", sizeof(module.name));
    strncpy(module.path, "/tmp/integration_test.s", sizeof(module.path));
    module.version = HMR_UNIFIED_VERSION_CURRENT;
    module.agent_id = HMR_AGENT_MODULE_SYSTEM;
    module.state = HMR_MODULE_STATE_DISCOVERED;
    module.capabilities = HMR_CAP_HOT_SWAPPABLE | HMR_CAP_ARM64_ONLY;
    
    result = hmr_module_register(&module);
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Module registration should succeed");
    
    // 2. Add runtime watch
    result = hmr_runtime_add_watch("/tmp/integration_test.s", "/tmp");
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Adding runtime watch should succeed");
    
    // 3. Simulate build process
    hmr_debug_notify_build_start("integration_test_module");
    usleep(1000); // Simulate build time
    hmr_debug_notify_build_success("integration_test_module", 1);
    
    // 4. Update module state through workflow
    result = hmr_update_module_state("integration_test_module", HMR_MODULE_STATE_BUILDING);
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "State update to BUILDING should succeed");
    
    result = hmr_update_module_state("integration_test_module", HMR_MODULE_STATE_BUILT);
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "State update to BUILT should succeed");
    
    result = hmr_update_module_state("integration_test_module", HMR_MODULE_STATE_ACTIVE);
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "State update to ACTIVE should succeed");
    
    // 5. Simulate hot-swap
    hmr_hotswap_context_t hotswap_ctx = {0};
    hotswap_ctx.operation_id = 1;
    hotswap_ctx.old_module_id = 1;
    hotswap_ctx.new_module_id = 2;
    hotswap_ctx.start_time = HMR_GET_TIMESTAMP();
    hotswap_ctx.flags = HMR_HOTSWAP_PRESERVE_STATE;
    
    result = hmr_runtime_prepare_hotswap("integration_test_module", &hotswap_ctx);
    HMR_ASSERT_EQ(result, HMR_SUCCESS, "Hotswap preparation should succeed");
    
    // 6. Notify successful reload
    hmr_debug_notify_module_reload("integration_test_module", true);
    
    // 7. Test unified metrics collection
    hmr_unified_metrics_t metrics = {0};
    hmr_get_unified_metrics(&metrics);
    
    // Verify cross-agent data consistency
    HMR_ASSERT(metrics.modules_loaded > 0, "Should have at least one module loaded");
    
    // Cleanup
    stop_mock_agents();
    
    hmr_runtime_remove_watch("/tmp/integration_test.s");
    hmr_module_unregister("integration_test_module");
    
    hmr_runtime_shutdown();
    hmr_orchestrator_shutdown();
    
    return 0;
}

static int test_error_propagation(void) {
    printf("  Testing error propagation across agents...\n");
    
    hmr_orchestrator_init();
    hmr_module_system_init();
    hmr_runtime_init();
    
    // Test error handling in module system
    hmr_module_info_t* nonexistent = hmr_module_find("nonexistent_module");
    HMR_ASSERT(nonexistent == NULL, "Should not find nonexistent module");
    
    int result = hmr_update_module_state("nonexistent_module", HMR_MODULE_STATE_ACTIVE);
    HMR_ASSERT_NE(result, HMR_SUCCESS, "Should fail to update nonexistent module state");
    
    // Test error handling in runtime system
    result = hmr_runtime_remove_watch("/nonexistent/path");
    HMR_ASSERT_NE(result, HMR_SUCCESS, "Should fail to remove nonexistent watch");
    
    hmr_runtime_shutdown();
    hmr_orchestrator_shutdown();
    
    return 0;
}

static int test_concurrent_operations(void) {
    printf("  Testing concurrent operations across agents...\n");
    
    hmr_orchestrator_init();
    hmr_module_system_init();
    hmr_runtime_init();
    
    start_mock_agents();
    
    // Simulate concurrent frame processing and module operations
    for (int i = 0; i < 5; i++) {
        hmr_runtime_frame_start(i);
        
        // Simulate concurrent module registration
        char module_name[32];
        snprintf(module_name, sizeof(module_name), "concurrent_module_%d", i);
        
        hmr_module_info_t module = {0};
        strncpy(module.name, module_name, sizeof(module.name));
        module.version = HMR_UNIFIED_VERSION_CURRENT;
        module.agent_id = HMR_AGENT_MODULE_SYSTEM;
        module.state = HMR_MODULE_STATE_DISCOVERED;
        
        int result = hmr_module_register(&module);
        HMR_ASSERT_EQ(result, HMR_SUCCESS, "Concurrent module registration should succeed");
        
        hmr_runtime_check_reloads();
        hmr_runtime_frame_end();
        
        // Cleanup
        hmr_module_unregister(module_name);
    }
    
    stop_mock_agents();
    
    hmr_runtime_shutdown();
    hmr_orchestrator_shutdown();
    
    return 0;
}

// =============================================================================
// Test Suite Definition
// =============================================================================

static hmr_test_case_t g_test_cases[] = {
    // Agent 0: Orchestrator tests
    HMR_TEST("orchestrator_init_shutdown", test_orchestrator_init_shutdown, true, false, false, false, false, false),
    HMR_TEST("agent_registration", test_agent_registration, true, false, false, false, false, false),
    HMR_TEST("message_system", test_message_system, true, false, false, false, false, false),
    
    // Agent 1: Module system tests
    HMR_TEST("module_system_init", test_module_system_init, false, true, false, false, false, false),
    HMR_TEST("module_lifecycle", test_module_lifecycle, false, true, false, false, false, false),
    
    // Agent 3: Runtime integration tests
    HMR_TEST("runtime_init_shutdown", test_runtime_init_shutdown, false, false, false, true, false, false),
    HMR_TEST("runtime_frame_integration", test_runtime_frame_integration, false, false, false, true, false, false),
    HMR_TEST("runtime_watch_system", test_runtime_watch_system, false, false, false, true, false, false),
    
    // Agent 4: Developer tools tests
    HMR_TEST("debug_system_init", test_debug_system_init, false, false, false, false, true, false),
    HMR_TEST("dev_server_lifecycle", test_dev_server_lifecycle, false, false, false, false, true, false),
    HMR_TEST("metrics_collection", test_metrics_collection, false, false, false, false, true, false),
    
    // Agent 5: Asset pipeline tests
    HMR_TEST("asset_pipeline_init", test_asset_pipeline_init, false, false, false, false, false, true),
    HMR_TEST("asset_watcher_lifecycle", test_asset_watcher_lifecycle, false, false, false, false, false, true),
    
    // Cross-agent integration tests
    HMR_TEST("full_system_integration", test_full_system_integration, true, true, false, true, true, true),
    HMR_TEST("error_propagation", test_error_propagation, true, true, false, true, false, false),
    HMR_TEST("concurrent_operations", test_concurrent_operations, true, true, false, true, false, false),
};

static const int g_num_tests = sizeof(g_test_cases) / sizeof(g_test_cases[0]);

// =============================================================================
// Test Runner
// =============================================================================

static bool check_agent_dependencies(const hmr_test_case_t* test) {
    for (int i = 0; i < 6; i++) {
        if (test->agent_dependency[i] && !g_agent_enabled[i]) {
            return false;
        }
    }
    return true;
}

static void run_test_case(const hmr_test_case_t* test) {
    printf("Running test: %s\n", test->name);
    
    if (!check_agent_dependencies(test)) {
        printf("  SKIP: Missing required agent dependencies\n");
        g_test_results.skipped_tests++;
        return;
    }
    
    uint64_t start_time = get_timestamp_ns();
    
    int result = test->test_func();
    
    uint64_t end_time = get_timestamp_ns();
    uint64_t test_time = end_time - start_time;
    g_test_results.total_time_ns += test_time;
    
    if (result == 0) {
        printf("  PASS (%llu µs)\n", test_time / 1000);
        g_test_results.passed_tests++;
    } else {
        printf("  FAIL (%llu µs)\n", test_time / 1000);
        g_test_results.failed_tests++;
    }
    
    g_test_results.total_tests++;
}

int main(int argc, char* argv[]) {
    printf("=============================================================================\n");
    printf("HMR Unified Integration Test Suite\n");
    printf("Agent 0: HMR Orchestrator - Week 2, Day 6\n");
    printf("=============================================================================\n");
    
    printf("\nAgent Availability:\n");
    const char* agent_names[] = {"Orchestrator", "Module System", "Build Pipeline", 
                                "Runtime", "Debug Tools", "Asset Pipeline"};
    for (int i = 0; i < 6; i++) {
        printf("  Agent %d (%s): %s\n", i, agent_names[i], 
               g_agent_enabled[i] ? "ENABLED" : "DISABLED");
    }
    
    printf("\nRunning %d test cases...\n\n", g_num_tests);
    
    // Run all test cases
    for (int i = 0; i < g_num_tests; i++) {
        run_test_case(&g_test_cases[i]);
        printf("\n");
    }
    
    // Print results summary
    printf("=============================================================================\n");
    printf("Test Results Summary:\n");
    printf("  Total Tests: %d\n", g_test_results.total_tests);
    printf("  Passed:      %d\n", g_test_results.passed_tests);
    printf("  Failed:      %d\n", g_test_results.failed_tests);
    printf("  Skipped:     %d\n", g_test_results.skipped_tests);
    printf("  Total Time:  %llu ms\n", g_test_results.total_time_ns / 1000000);
    
    if (g_test_results.failed_tests > 0) {
        printf("\nSTATUS: FAILED (%d failures)\n", g_test_results.failed_tests);
        return 1;
    } else {
        printf("\nSTATUS: ALL TESTS PASSED\n");
        return 0;
    }
}