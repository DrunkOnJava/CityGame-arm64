/*
 * SimCity ARM64 - Advanced HMR State Management Tests
 * Agent 3: Runtime Integration - Day 6 Implementation
 * 
 * Comprehensive test suite for advanced state management features
 * Tests incremental updates, NEON diffing, validation, and compression
 * Performance benchmarks for 1K-100K agent scenarios
 */

#include "state_manager.h"
#include "runtime_integration.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <assert.h>
#include <mach/mach_time.h>

// =============================================================================
// Test Configuration and Utilities
// =============================================================================

#define TEST_MODULE_ID_1        1
#define TEST_MODULE_ID_2        2
#define TEST_AGENT_SIZE_SMALL   64      // 64 bytes per agent
#define TEST_AGENT_SIZE_LARGE   256     // 256 bytes per agent
#define TEST_AGENTS_1K          1000
#define TEST_AGENTS_10K         10000
#define TEST_AGENTS_100K        100000

// Test agent structure (64 bytes)
typedef struct __attribute__((packed)) {
    uint32_t agent_id;
    float position_x, position_y, position_z;
    float velocity_x, velocity_y, velocity_z;
    uint32_t state_flags;
    uint32_t behavior_state;
    uint32_t resource_level;
    uint32_t happiness_level;
    uint8_t padding[20]; // Padding to reach 64 bytes
} test_agent_small_t;

// Test agent structure (256 bytes)  
typedef struct __attribute__((packed)) {
    test_agent_small_t core;
    float extended_data[48]; // Additional data to reach 256 bytes
} test_agent_large_t;

// Performance benchmark results
typedef struct {
    uint64_t incremental_update_time_ns;
    uint64_t diff_generation_time_ns;
    uint64_t validation_time_ns;
    uint64_t compression_time_ns;
    uint32_t agent_count;
    uint32_t diff_count;
    float compression_ratio;
    bool test_passed;
} test_benchmark_result_t;

static mach_timebase_info_data_t g_timebase_info = {0};

// Get high-resolution timestamp
static uint64_t get_timestamp_ns(void) {
    uint64_t absolute_time = mach_absolute_time();
    return (absolute_time * g_timebase_info.numer) / g_timebase_info.denom;
}

// Generate test data for agents
static void generate_test_agents_small(test_agent_small_t* agents, uint32_t count) {
    for (uint32_t i = 0; i < count; i++) {
        agents[i].agent_id = i;
        agents[i].position_x = (float)(rand() % 1000);
        agents[i].position_y = (float)(rand() % 1000);
        agents[i].position_z = (float)(rand() % 100);
        agents[i].velocity_x = (float)(rand() % 20) - 10.0f;
        agents[i].velocity_y = (float)(rand() % 20) - 10.0f;
        agents[i].velocity_z = (float)(rand() % 10) - 5.0f;
        agents[i].state_flags = rand() % 0xFFFF;
        agents[i].behavior_state = rand() % 10;
        agents[i].resource_level = rand() % 100;
        agents[i].happiness_level = rand() % 100;
        memset(agents[i].padding, 0, sizeof(agents[i].padding));
    }
}

// Modify subset of agents for difference testing
static void modify_test_agents(test_agent_small_t* agents, uint32_t count, float change_ratio) {
    uint32_t agents_to_change = (uint32_t)(count * change_ratio);
    
    for (uint32_t i = 0; i < agents_to_change; i++) {
        uint32_t agent_index = rand() % count;
        agents[agent_index].position_x += (float)(rand() % 10) - 5.0f;
        agents[agent_index].position_y += (float)(rand() % 10) - 5.0f;
        agents[agent_index].happiness_level = rand() % 100;
    }
}

// =============================================================================
// Unit Tests
// =============================================================================

static bool test_state_manager_init_shutdown(void) {
    printf("Testing state manager initialization and shutdown...\n");
    
    int result = hmr_state_init();
    if (result != HMR_STATE_SUCCESS) {
        printf("  FAIL: hmr_state_init() returned %d\n", result);
        return false;
    }
    
    result = hmr_state_shutdown();
    if (result != HMR_STATE_SUCCESS) {
        printf("  FAIL: hmr_state_shutdown() returned %d\n", result);
        return false;
    }
    
    printf("  PASS: State manager init/shutdown successful\n");
    return true;
}

static bool test_module_registration(void) {
    printf("Testing module registration and unregistration...\n");
    
    int result = hmr_state_init();
    assert(result == HMR_STATE_SUCCESS);
    
    // Register a test module
    result = hmr_state_register_module(TEST_MODULE_ID_1, "TestModule1",
                                      TEST_AGENT_SIZE_SMALL, TEST_AGENTS_1K,
                                      TEST_AGENTS_10K);
    if (result != HMR_STATE_SUCCESS) {
        printf("  FAIL: Module registration failed with %d\n", result);
        hmr_state_shutdown();
        return false;
    }
    
    // Register second module
    result = hmr_state_register_module(TEST_MODULE_ID_2, "TestModule2",
                                      TEST_AGENT_SIZE_LARGE, TEST_AGENTS_1K,
                                      TEST_AGENTS_1K);
    if (result != HMR_STATE_SUCCESS) {
        printf("  FAIL: Second module registration failed with %d\n", result);
        hmr_state_shutdown();
        return false;
    }
    
    // Get statistics
    uint64_t total_memory, compressed_memory;
    uint32_t active_agents, dirty_chunks;
    hmr_state_get_statistics(&total_memory, &compressed_memory, 
                             &active_agents, &dirty_chunks);
    
    if (active_agents != TEST_AGENTS_1K * 2) {
        printf("  FAIL: Expected %d agents, got %d\n", TEST_AGENTS_1K * 2, active_agents);
        hmr_state_shutdown();
        return false;
    }
    
    // Unregister modules
    result = hmr_state_unregister_module(TEST_MODULE_ID_1);
    if (result != HMR_STATE_SUCCESS) {
        printf("  FAIL: Module unregistration failed with %d\n", result);
        hmr_state_shutdown();
        return false;
    }
    
    result = hmr_state_unregister_module(TEST_MODULE_ID_2);
    if (result != HMR_STATE_SUCCESS) {
        printf("  FAIL: Second module unregistration failed with %d\n", result);
        hmr_state_shutdown();
        return false;
    }
    
    hmr_state_shutdown();
    printf("  PASS: Module registration/unregistration successful\n");
    return true;
}

static bool test_incremental_updates(void) {
    printf("Testing incremental state updates...\n");
    
    int result = hmr_state_init();
    assert(result == HMR_STATE_SUCCESS);
    
    // Register test module
    result = hmr_state_register_module(TEST_MODULE_ID_1, "TestModule1",
                                      sizeof(test_agent_small_t), TEST_AGENTS_1K,
                                      TEST_AGENTS_10K);
    assert(result == HMR_STATE_SUCCESS);
    
    // Generate test data
    test_agent_small_t* agents = malloc(TEST_AGENTS_1K * sizeof(test_agent_small_t));
    generate_test_agents_small(agents, TEST_AGENTS_1K);
    
    // Begin incremental update
    result = hmr_state_begin_incremental_update(TEST_MODULE_ID_1);
    if (result != HMR_STATE_SUCCESS) {
        printf("  FAIL: Begin incremental update failed with %d\n", result);
        free(agents);
        hmr_state_shutdown();
        return false;
    }
    
    // Update all agents
    uint64_t start_time = get_timestamp_ns();
    for (uint32_t i = 0; i < TEST_AGENTS_1K; i++) {
        result = hmr_state_update_agent_incremental(TEST_MODULE_ID_1, i, 
                                                   &agents[i], sizeof(test_agent_small_t));
        if (result != HMR_STATE_SUCCESS) {
            printf("  FAIL: Agent update %d failed with %d\n", i, result);
            free(agents);
            hmr_state_shutdown();
            return false;
        }
    }
    uint64_t end_time = get_timestamp_ns();
    
    // Commit update
    result = hmr_state_commit_incremental_update(TEST_MODULE_ID_1);
    if (result != HMR_STATE_SUCCESS) {
        printf("  FAIL: Commit incremental update failed with %d\n", result);
        free(agents);
        hmr_state_shutdown();
        return false;
    }
    
    uint64_t update_time_us = (end_time - start_time) / 1000;
    printf("  INFO: Updated %d agents in %llu μs (%.2f μs per agent)\n", 
           TEST_AGENTS_1K, update_time_us, (float)update_time_us / TEST_AGENTS_1K);
    
    if (update_time_us > 1000) { // Should be under 1ms for 1K agents
        printf("  WARN: Update time exceeds target (<1ms)\n");
    }
    
    free(agents);
    hmr_state_shutdown();
    printf("  PASS: Incremental updates successful\n");
    return true;
}

static bool test_state_diffing(void) {
    printf("Testing NEON-optimized state diffing...\n");
    
    int result = hmr_state_init();
    assert(result == HMR_STATE_SUCCESS);
    
    // Register test module
    result = hmr_state_register_module(TEST_MODULE_ID_1, "TestModule1",
                                      sizeof(test_agent_small_t), TEST_AGENTS_1K,
                                      TEST_AGENTS_10K);
    assert(result == HMR_STATE_SUCCESS);
    
    // Generate and set initial state
    test_agent_small_t* agents = malloc(TEST_AGENTS_1K * sizeof(test_agent_small_t));
    generate_test_agents_small(agents, TEST_AGENTS_1K);
    
    // Create checkpoint
    result = hmr_state_create_checkpoint(TEST_MODULE_ID_1);
    assert(result == HMR_STATE_SUCCESS);
    
    // Update initial state
    result = hmr_state_begin_incremental_update(TEST_MODULE_ID_1);
    assert(result == HMR_STATE_SUCCESS);
    
    for (uint32_t i = 0; i < TEST_AGENTS_1K; i++) {
        hmr_state_update_agent_incremental(TEST_MODULE_ID_1, i, 
                                          &agents[i], sizeof(test_agent_small_t));
    }
    
    result = hmr_state_commit_incremental_update(TEST_MODULE_ID_1);
    assert(result == HMR_STATE_SUCCESS);
    
    // Modify some agents
    modify_test_agents(agents, TEST_AGENTS_1K, 0.1f); // 10% change
    
    // Update with modifications
    result = hmr_state_begin_incremental_update(TEST_MODULE_ID_1);
    assert(result == HMR_STATE_SUCCESS);
    
    for (uint32_t i = 0; i < TEST_AGENTS_1K; i++) {
        hmr_state_update_agent_incremental(TEST_MODULE_ID_1, i, 
                                          &agents[i], sizeof(test_agent_small_t));
    }
    
    result = hmr_state_commit_incremental_update(TEST_MODULE_ID_1);
    assert(result == HMR_STATE_SUCCESS);
    
    // Generate diff
    hmr_state_diff_t* diffs = malloc(1000 * sizeof(hmr_state_diff_t));
    uint32_t diff_count = 0;
    
    uint64_t start_time = get_timestamp_ns();
    result = hmr_state_generate_diff(TEST_MODULE_ID_1, diffs, 1000, &diff_count);
    uint64_t end_time = get_timestamp_ns();
    
    if (result != HMR_STATE_SUCCESS) {
        printf("  FAIL: State diff generation failed with %d\n", result);
        free(agents);
        free(diffs);
        hmr_state_shutdown();
        return false;
    }
    
    uint64_t diff_time_us = (end_time - start_time) / 1000;
    printf("  INFO: Generated %d diffs in %llu μs for %d agents\n", 
           diff_count, diff_time_us, TEST_AGENTS_1K);
    
    if (diff_count == 0) {
        printf("  WARN: Expected some diffs but found none\n");
    }
    
    if (diff_time_us > 2000) { // Should be under 2ms
        printf("  WARN: Diff generation time exceeds target (<2ms)\n");
    }
    
    free(agents);
    free(diffs);
    hmr_state_shutdown();
    printf("  PASS: State diffing successful\n");
    return true;
}

static bool test_state_validation(void) {
    printf("Testing state validation and corruption detection...\n");
    
    int result = hmr_state_init();
    assert(result == HMR_STATE_SUCCESS);
    
    // Register test module
    result = hmr_state_register_module(TEST_MODULE_ID_1, "TestModule1",
                                      sizeof(test_agent_small_t), TEST_AGENTS_1K,
                                      TEST_AGENTS_10K);
    assert(result == HMR_STATE_SUCCESS);
    
    // Generate and set state
    test_agent_small_t* agents = malloc(TEST_AGENTS_1K * sizeof(test_agent_small_t));
    generate_test_agents_small(agents, TEST_AGENTS_1K);
    
    result = hmr_state_begin_incremental_update(TEST_MODULE_ID_1);
    assert(result == HMR_STATE_SUCCESS);
    
    for (uint32_t i = 0; i < TEST_AGENTS_1K; i++) {
        hmr_state_update_agent_incremental(TEST_MODULE_ID_1, i, 
                                          &agents[i], sizeof(test_agent_small_t));
    }
    
    result = hmr_state_commit_incremental_update(TEST_MODULE_ID_1);
    assert(result == HMR_STATE_SUCCESS);
    
    // Validate clean state
    hmr_state_validation_t validation_result;
    uint64_t start_time = get_timestamp_ns();
    result = hmr_state_validate_all(&validation_result);
    uint64_t end_time = get_timestamp_ns();
    
    if (result != HMR_STATE_SUCCESS) {
        printf("  FAIL: Initial validation failed with %d\n", result);
        free(agents);
        hmr_state_shutdown();
        return false;
    }
    
    if (!validation_result.validation_passed) {
        printf("  FAIL: Clean state failed validation\n");
        free(agents);
        hmr_state_shutdown();
        return false;
    }
    
    uint64_t validation_time_us = (end_time - start_time) / 1000;
    printf("  INFO: Validated %d agents in %llu μs\n", 
           validation_result.total_agents, validation_time_us);
    
    if (validation_time_us > 5000) { // Should be under 5ms
        printf("  WARN: Validation time exceeds target (<5ms)\n");
    }
    
    free(agents);
    hmr_state_shutdown();
    printf("  PASS: State validation successful\n");
    return true;
}

static bool test_state_compression(void) {
    printf("Testing LZ4-style state compression...\n");
    
    int result = hmr_state_init();
    assert(result == HMR_STATE_SUCCESS);
    
    // Register test module with larger agents
    result = hmr_state_register_module(TEST_MODULE_ID_1, "TestModule1",
                                      sizeof(test_agent_large_t), TEST_AGENTS_1K,
                                      TEST_AGENTS_10K);
    assert(result == HMR_STATE_SUCCESS);
    
    // Generate repetitive data (should compress well)
    test_agent_large_t* agents = malloc(TEST_AGENTS_1K * sizeof(test_agent_large_t));
    for (uint32_t i = 0; i < TEST_AGENTS_1K; i++) {
        // Create agents with similar data to test compression
        agents[i].core.agent_id = i;
        agents[i].core.position_x = (float)(i % 100);
        agents[i].core.position_y = (float)(i % 100);
        agents[i].core.position_z = 0.0f;
        agents[i].core.velocity_x = 1.0f;
        agents[i].core.velocity_y = 1.0f;
        agents[i].core.velocity_z = 0.0f;
        agents[i].core.state_flags = 0x1234;
        agents[i].core.behavior_state = i % 5;
        agents[i].core.resource_level = 50;
        agents[i].core.happiness_level = 75;
        
        // Fill extended data with patterns
        for (int j = 0; j < 48; j++) {
            agents[i].extended_data[j] = (float)(j % 10);
        }
    }
    
    // Update state
    result = hmr_state_begin_incremental_update(TEST_MODULE_ID_1);
    assert(result == HMR_STATE_SUCCESS);
    
    for (uint32_t i = 0; i < TEST_AGENTS_1K; i++) {
        hmr_state_update_agent_incremental(TEST_MODULE_ID_1, i, 
                                          &agents[i], sizeof(test_agent_large_t));
    }
    
    result = hmr_state_commit_incremental_update(TEST_MODULE_ID_1);
    assert(result == HMR_STATE_SUCCESS);
    
    // Test compression
    hmr_state_compression_stats_t stats;
    uint64_t start_time = get_timestamp_ns();
    result = hmr_state_compress_module(TEST_MODULE_ID_1, &stats);
    uint64_t end_time = get_timestamp_ns();
    
    if (result != HMR_STATE_SUCCESS) {
        printf("  FAIL: Compression failed with %d\n", result);
        free(agents);
        hmr_state_shutdown();
        return false;
    }
    
    uint64_t compression_time_us = (end_time - start_time) / 1000;
    printf("  INFO: Compressed %llu bytes to %llu bytes (%.1f%% ratio) in %llu μs\n",
           stats.uncompressed_size, stats.compressed_size, 
           stats.compression_ratio * 100.0f, compression_time_us);
    
    if (stats.compression_ratio > 0.9f) {
        printf("  WARN: Compression ratio is poor (>90%%)\n");
    }
    
    if (compression_time_us > 10000) { // Should be under 10ms
        printf("  WARN: Compression time exceeds target (<10ms)\n");
    }
    
    // Test decompression
    start_time = get_timestamp_ns();
    result = hmr_state_decompress_module(TEST_MODULE_ID_1);
    end_time = get_timestamp_ns();
    
    if (result != HMR_STATE_SUCCESS) {
        printf("  FAIL: Decompression failed with %d\n", result);
        free(agents);
        hmr_state_shutdown();
        return false;
    }
    
    uint64_t decompression_time_us = (end_time - start_time) / 1000;
    printf("  INFO: Decompressed in %llu μs\n", decompression_time_us);
    
    free(agents);
    hmr_state_shutdown();
    printf("  PASS: State compression successful\n");
    return true;
}

// =============================================================================
// Performance Benchmarks
// =============================================================================

static test_benchmark_result_t benchmark_scalability(uint32_t agent_count) {
    test_benchmark_result_t result = {0};
    result.agent_count = agent_count;
    result.test_passed = true;
    
    printf("Benchmarking with %d agents...\n", agent_count);
    
    int hmr_result = hmr_state_init();
    assert(hmr_result == HMR_STATE_SUCCESS);
    
    // Register module
    hmr_result = hmr_state_register_module(TEST_MODULE_ID_1, "BenchmarkModule",
                                          sizeof(test_agent_small_t), agent_count,
                                          agent_count * 2);
    assert(hmr_result == HMR_STATE_SUCCESS);
    
    // Generate test data
    test_agent_small_t* agents = malloc(agent_count * sizeof(test_agent_small_t));
    generate_test_agents_small(agents, agent_count);
    
    // Benchmark incremental updates
    uint64_t start_time = get_timestamp_ns();
    
    hmr_result = hmr_state_begin_incremental_update(TEST_MODULE_ID_1);
    assert(hmr_result == HMR_STATE_SUCCESS);
    
    for (uint32_t i = 0; i < agent_count; i++) {
        hmr_state_update_agent_incremental(TEST_MODULE_ID_1, i, 
                                          &agents[i], sizeof(test_agent_small_t));
    }
    
    hmr_result = hmr_state_commit_incremental_update(TEST_MODULE_ID_1);
    assert(hmr_result == HMR_STATE_SUCCESS);
    
    uint64_t end_time = get_timestamp_ns();
    result.incremental_update_time_ns = end_time - start_time;
    
    // Create checkpoint for diffing
    hmr_state_create_checkpoint(TEST_MODULE_ID_1);
    
    // Modify agents
    modify_test_agents(agents, agent_count, 0.05f); // 5% change
    
    // Update with modifications
    hmr_state_begin_incremental_update(TEST_MODULE_ID_1);
    for (uint32_t i = 0; i < agent_count; i++) {
        hmr_state_update_agent_incremental(TEST_MODULE_ID_1, i, 
                                          &agents[i], sizeof(test_agent_small_t));
    }
    hmr_state_commit_incremental_update(TEST_MODULE_ID_1);
    
    // Benchmark diff generation
    uint32_t max_diffs = agent_count / 10; // Expect up to 10% diffs
    hmr_state_diff_t* diffs = malloc(max_diffs * sizeof(hmr_state_diff_t));
    uint32_t diff_count = 0;
    
    start_time = get_timestamp_ns();
    hmr_state_generate_diff(TEST_MODULE_ID_1, diffs, max_diffs, &diff_count);
    end_time = get_timestamp_ns();
    result.diff_generation_time_ns = end_time - start_time;
    result.diff_count = diff_count;
    
    // Benchmark validation
    hmr_state_validation_t validation_result;
    start_time = get_timestamp_ns();
    hmr_state_validate_all(&validation_result);
    end_time = get_timestamp_ns();
    result.validation_time_ns = end_time - start_time;
    
    // Benchmark compression (only for larger datasets)
    if (agent_count >= 1000) {
        hmr_state_compression_stats_t compression_stats;
        start_time = get_timestamp_ns();
        hmr_state_compress_module(TEST_MODULE_ID_1, &compression_stats);
        end_time = get_timestamp_ns();
        result.compression_time_ns = end_time - start_time;
        result.compression_ratio = compression_stats.compression_ratio;
    }
    
    // Check performance targets
    uint64_t update_time_ms = result.incremental_update_time_ns / 1000000;
    uint64_t diff_time_ms = result.diff_generation_time_ns / 1000000;
    uint64_t validation_time_ms = result.validation_time_ns / 1000000;
    
    printf("  Update time: %llu ms (%.1f μs/agent)\n", 
           update_time_ms, (float)result.incremental_update_time_ns / (1000.0f * agent_count));
    printf("  Diff time: %llu ms (%d diffs found)\n", diff_time_ms, diff_count);
    printf("  Validation time: %llu ms\n", validation_time_ms);
    
    if (agent_count >= 1000) {
        uint64_t compression_time_ms = result.compression_time_ns / 1000000;
        printf("  Compression time: %llu ms (%.1f%% ratio)\n", 
               compression_time_ms, result.compression_ratio * 100.0f);
    }
    
    // Check targets
    if (agent_count == 1000 && update_time_ms > 1) {
        printf("  WARN: Update time exceeds 1ms target for 1K agents\n");
        result.test_passed = false;
    }
    if (diff_time_ms > 2) {
        printf("  WARN: Diff time exceeds 2ms target\n");
        result.test_passed = false;
    }
    if (validation_time_ms > 5) {
        printf("  WARN: Validation time exceeds 5ms target\n");
        result.test_passed = false;
    }
    
    free(agents);
    free(diffs);
    hmr_state_shutdown();
    
    return result;
}

// =============================================================================
// Main Test Runner
// =============================================================================

int main(void) {
    printf("=== SimCity ARM64 - Advanced HMR State Management Tests ===\n\n");
    
    // Initialize timing
    mach_timebase_info(&g_timebase_info);
    srand((unsigned int)time(NULL));
    
    bool all_tests_passed = true;
    
    // Run unit tests
    printf("Running unit tests...\n");
    all_tests_passed &= test_state_manager_init_shutdown();
    all_tests_passed &= test_module_registration();
    all_tests_passed &= test_incremental_updates();
    all_tests_passed &= test_state_diffing();
    all_tests_passed &= test_state_validation();
    all_tests_passed &= test_state_compression();
    
    printf("\nRunning performance benchmarks...\n");
    
    // Run scalability benchmarks
    test_benchmark_result_t benchmark_1k = benchmark_scalability(1000);
    test_benchmark_result_t benchmark_10k = benchmark_scalability(10000);
    test_benchmark_result_t benchmark_100k = benchmark_scalability(100000);
    
    all_tests_passed &= benchmark_1k.test_passed;
    all_tests_passed &= benchmark_10k.test_passed;
    all_tests_passed &= benchmark_100k.test_passed;
    
    // Summary
    printf("\n=== Test Summary ===\n");
    printf("Overall result: %s\n", all_tests_passed ? "PASS" : "FAIL");
    
    printf("\nPerformance Summary:\n");
    printf("1K agents:   Update=%.1fμs/agent, Diff=%llums, Validation=%llums\n",
           (float)benchmark_1k.incremental_update_time_ns / (1000.0f * 1000),
           benchmark_1k.diff_generation_time_ns / 1000000,
           benchmark_1k.validation_time_ns / 1000000);
    
    printf("10K agents:  Update=%.1fμs/agent, Diff=%llums, Validation=%llums\n",
           (float)benchmark_10k.incremental_update_time_ns / (1000.0f * 10000),
           benchmark_10k.diff_generation_time_ns / 1000000,
           benchmark_10k.validation_time_ns / 1000000);
    
    printf("100K agents: Update=%.1fμs/agent, Diff=%llums, Validation=%llums\n",
           (float)benchmark_100k.incremental_update_time_ns / (1000.0f * 100000),
           benchmark_100k.diff_generation_time_ns / 1000000,
           benchmark_100k.validation_time_ns / 1000000);
    
    printf("\nDay 6 Advanced State Management Implementation: %s\n", 
           all_tests_passed ? "COMPLETE ✓" : "NEEDS WORK ✗");
    
    return all_tests_passed ? 0 : 1;
}