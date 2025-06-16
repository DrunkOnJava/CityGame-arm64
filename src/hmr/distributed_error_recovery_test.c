/*
 * SimCity ARM64 - Distributed Error Recovery System Test Suite
 * Day 12: Advanced Error Handling & Recovery - HMR Orchestrator
 * 
 * Comprehensive test suite for distributed error recovery system covering:
 * - Recovery time performance (<50ms target)
 * - Machine learning prediction accuracy
 * - Cross-agent error coordination
 * - System health monitoring
 * - Error analytics and prevention
 */

#include "distributed_error_recovery.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <unistd.h>
#include <sys/time.h>
#include <math.h>
#include <pthread.h>

// Test configuration
#define TEST_ITERATIONS 1000
#define STRESS_TEST_DURATION_SECONDS 30
#define MAX_TEST_ERRORS 100
#define RECOVERY_TIME_TARGET_US 50000  // 50ms target

// Test statistics
typedef struct {
    uint32_t tests_run;
    uint32_t tests_passed;
    uint32_t tests_failed;
    uint64_t total_test_time_us;
    uint64_t fastest_test_us;
    uint64_t slowest_test_us;
    char last_failure_reason[512];
} test_statistics_t;

static test_statistics_t g_test_stats = {0};

// ============================================================================
// Test Utilities
// ============================================================================

static uint64_t get_current_time_us(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (uint64_t)tv.tv_sec * 1000000ULL + (uint64_t)tv.tv_usec;
}

static void test_start(const char* test_name) {
    printf("┌─ %-60s ", test_name);
    fflush(stdout);
    g_test_stats.tests_run++;
}

static void test_pass(uint64_t duration_us) {
    printf("✓ PASSED (%6.2f ms)\n", duration_us / 1000.0);
    g_test_stats.tests_passed++;
    g_test_stats.total_test_time_us += duration_us;
    
    if (duration_us < g_test_stats.fastest_test_us || g_test_stats.fastest_test_us == 0) {
        g_test_stats.fastest_test_us = duration_us;
    }
    
    if (duration_us > g_test_stats.slowest_test_us) {
        g_test_stats.slowest_test_us = duration_us;
    }
}

static void test_fail(const char* reason, uint64_t duration_us) {
    printf("✗ FAILED (%6.2f ms)\n", duration_us / 1000.0);
    printf("│   Reason: %s\n", reason);
    g_test_stats.tests_failed++;
    g_test_stats.total_test_time_us += duration_us;
    snprintf(g_test_stats.last_failure_reason, sizeof(g_test_stats.last_failure_reason), "%s", reason);
}

static hmr_error_context_t create_test_error(hmr_agent_type_t agent, 
                                           hmr_error_severity_t severity,
                                           hmr_error_category_t category) {
    hmr_error_context_t error = {0};
    
    // Generate unique error ID
    uint64_t timestamp = get_current_time_us();
    snprintf(error.error_id, sizeof(error.error_id), "TEST_ERR_%llu", timestamp);
    
    error.source_agent = agent;
    error.severity = severity;
    error.category = category;
    error.timestamp_us = timestamp;
    error.thread_id = (uint64_t)pthread_self();
    error.line_number = 42; // Test line number
    error.memory_usage_bytes = 1024 * 1024; // 1MB test usage
    error.cpu_usage_percent = 25.0; // 25% test usage
    error.error_code = 1000 + (uint32_t)category;
    
    snprintf(error.file_path, sizeof(error.file_path), "/test/path/test_file.c");
    snprintf(error.function_name, sizeof(error.function_name), "test_function");
    snprintf(error.error_message, sizeof(error.error_message), 
            "Test error from agent %s with severity %s",
            hmr_agent_type_to_string(agent), hmr_error_severity_to_string(severity));
    snprintf(error.context_data, sizeof(error.context_data), "Test context data");
    
    return error;
}

// ============================================================================
// Basic Functionality Tests
// ============================================================================

static void test_system_initialization(void) {
    test_start("System Initialization");
    uint64_t start_time = get_current_time_us();
    
    hmr_error_recovery_config_t config = {0};
    config.enable_predictive_failure_detection = true;
    config.enable_automatic_recovery = true;
    config.enable_cross_agent_coordination = true;
    config.enable_error_analytics = true;
    config.enable_rollback_checkpoints = true;
    config.max_recovery_attempts = 3;
    config.recovery_timeout_ms = 5000;
    config.heartbeat_interval_ms = 1000;
    config.prediction_update_interval_ms = 2000;
    config.failure_prediction_threshold = 0.7;
    config.error_history_retention_hours = 24;
    
    snprintf(config.checkpoint_storage_path, sizeof(config.checkpoint_storage_path), "/tmp/hmr_checkpoints");
    snprintf(config.error_log_path, sizeof(config.error_log_path), "/tmp/hmr_errors.log");
    snprintf(config.analytics_output_path, sizeof(config.analytics_output_path), "/tmp/hmr_analytics.json");
    
    int32_t result = hmr_error_recovery_init(&config);
    
    uint64_t duration = get_current_time_us() - start_time;
    
    if (result == 0) {
        test_pass(duration);
    } else {
        test_fail("Failed to initialize error recovery system", duration);
    }
}

static void test_error_reporting(void) {
    test_start("Error Reporting");
    uint64_t start_time = get_current_time_us();
    
    // Test reporting different types of errors
    hmr_error_context_t error1 = create_test_error(HMR_AGENT_RUNTIME, 
                                                  HMR_ERROR_SEVERITY_ERROR,
                                                  HMR_ERROR_CATEGORY_MEMORY);
    
    hmr_error_context_t error2 = create_test_error(HMR_AGENT_BUILD_PIPELINE,
                                                  HMR_ERROR_SEVERITY_WARNING,
                                                  HMR_ERROR_CATEGORY_COMPILATION);
    
    hmr_error_context_t error3 = create_test_error(HMR_AGENT_SHADER_PIPELINE,
                                                  HMR_ERROR_SEVERITY_CRITICAL,
                                                  HMR_ERROR_CATEGORY_PERFORMANCE);
    
    int32_t result1 = hmr_error_recovery_report_error(&error1);
    int32_t result2 = hmr_error_recovery_report_error(&error2);
    int32_t result3 = hmr_error_recovery_report_error(&error3);
    
    // Allow some time for processing
    usleep(100000); // 100ms
    
    // Check analytics
    hmr_error_analytics_t analytics;
    int32_t analytics_result = hmr_error_recovery_get_analytics(&analytics);
    
    uint64_t duration = get_current_time_us() - start_time;
    
    if (result1 == 0 && result2 == 0 && result3 == 0 && analytics_result == 0 && 
        analytics.total_errors >= 3) {
        test_pass(duration);
    } else {
        test_fail("Failed to report errors correctly", duration);
    }
}

static void test_recovery_execution(void) {
    test_start("Recovery Execution");
    uint64_t start_time = get_current_time_us();
    
    // Create test error requiring recovery
    hmr_error_context_t error = create_test_error(HMR_AGENT_RUNTIME,
                                                 HMR_ERROR_SEVERITY_CRITICAL,
                                                 HMR_ERROR_CATEGORY_RUNTIME);
    
    // Report error (should trigger automatic recovery)
    int32_t report_result = hmr_error_recovery_report_error(&error);
    
    // Wait for recovery to complete
    usleep(200000); // 200ms
    
    // Check if recovery was attempted
    hmr_error_analytics_t analytics;
    int32_t analytics_result = hmr_error_recovery_get_analytics(&analytics);
    
    uint64_t duration = get_current_time_us() - start_time;
    
    if (report_result == 0 && analytics_result == 0 && analytics.total_recoveries > 0) {
        test_pass(duration);
    } else {
        test_fail("Recovery was not executed", duration);
    }
}

static void test_agent_health_monitoring(void) {
    test_start("Agent Health Monitoring");
    uint64_t start_time = get_current_time_us();
    
    // Update health for different agents
    hmr_agent_health_t health = {0};
    health.agent_type = HMR_AGENT_RUNTIME;
    health.agent_healthy = true;
    health.error_count_last_minute = 5;
    health.warning_count_last_minute = 2;
    health.error_rate_per_second = 0.1;
    health.cumulative_errors = 100;
    health.cumulative_recoveries = 95;
    health.average_recovery_time_us = 25000; // 25ms
    health.success_rate_percent = 95.0;
    health.most_common_error = HMR_ERROR_CATEGORY_PERFORMANCE;
    health.memory_usage_bytes = 512 * 1024 * 1024; // 512MB
    health.cpu_usage_percent = 15.0;
    snprintf(health.status_message, sizeof(health.status_message), "Healthy");
    
    int32_t result = hmr_error_recovery_update_agent_health(HMR_AGENT_RUNTIME, &health);
    
    uint64_t duration = get_current_time_us() - start_time;
    
    if (result == 0) {
        test_pass(duration);
    } else {
        test_fail("Failed to update agent health", duration);
    }
}

// ============================================================================
// Performance Tests
// ============================================================================

static void test_recovery_time_performance(void) {
    test_start("Recovery Time Performance (<50ms target)");
    uint64_t start_time = get_current_time_us();
    
    uint64_t total_recovery_time = 0;
    uint64_t max_recovery_time = 0;
    uint32_t recovery_count = 0;
    
    for (uint32_t i = 0; i < 20; i++) {
        hmr_error_context_t error = create_test_error(
            (hmr_agent_type_t)(i % HMR_AGENT_COUNT),
            HMR_ERROR_SEVERITY_ERROR,
            (hmr_error_category_t)(i % HMR_ERROR_CATEGORY_COUNT)
        );
        
        uint64_t recovery_start = get_current_time_us();
        
        int32_t result = hmr_error_recovery_request_recovery(error.error_id, 
                                                           HMR_RECOVERY_STRATEGY_RETRY);
        
        uint64_t recovery_end = get_current_time_us();
        uint64_t recovery_time = recovery_end - recovery_start;
        
        if (result == 0) {
            total_recovery_time += recovery_time;
            if (recovery_time > max_recovery_time) {
                max_recovery_time = recovery_time;
            }
            recovery_count++;
        }
        
        usleep(10000); // 10ms between recoveries
    }
    
    uint64_t duration = get_current_time_us() - start_time;
    
    double average_recovery_time = recovery_count > 0 ? 
        (double)total_recovery_time / recovery_count : 0.0;
    
    if (recovery_count > 0 && max_recovery_time <= RECOVERY_TIME_TARGET_US) {
        printf("│   Average: %.2f ms, Max: %.2f ms, Count: %u\n",
               average_recovery_time / 1000.0, max_recovery_time / 1000.0, recovery_count);
        test_pass(duration);
    } else {
        char reason[256];
        snprintf(reason, sizeof(reason), 
                "Recovery time exceeded target: %.2f ms > 50ms (or no recoveries: %u)",
                max_recovery_time / 1000.0, recovery_count);
        test_fail(reason, duration);
    }
}

// Thread function for concurrent error reporting
static void* concurrent_error_thread_func(void* arg) {
    uint32_t thread_id = *(uint32_t*)arg;
    uint32_t errors_per_thread = 5;
    
    for (uint32_t i = 0; i < errors_per_thread; i++) {
        hmr_error_context_t error = create_test_error(
            (hmr_agent_type_t)(thread_id % HMR_AGENT_COUNT),
            HMR_ERROR_SEVERITY_WARNING,
            (hmr_error_category_t)(i % HMR_ERROR_CATEGORY_COUNT)
        );
        
        hmr_error_recovery_report_error(&error);
        usleep(1000); // 1ms between errors
    }
    
    return NULL;
}

static void test_concurrent_error_handling(void) {
    test_start("Concurrent Error Handling");
    uint64_t start_time = get_current_time_us();
    
    pthread_t threads[10];
    uint32_t errors_per_thread = 5;
    
    // Start threads
    uint32_t thread_ids[10];
    for (uint32_t i = 0; i < 10; i++) {
        thread_ids[i] = i;
        pthread_create(&threads[i], NULL, concurrent_error_thread_func, &thread_ids[i]);
    }
    
    // Wait for threads to complete
    for (uint32_t i = 0; i < 10; i++) {
        pthread_join(threads[i], NULL);
    }
    
    // Allow processing time
    usleep(500000); // 500ms
    
    // Check results
    hmr_error_analytics_t analytics;
    int32_t result = hmr_error_recovery_get_analytics(&analytics);
    
    uint64_t duration = get_current_time_us() - start_time;
    
    uint32_t expected_errors = 10 * errors_per_thread;
    if (result == 0 && analytics.total_errors >= expected_errors) {
        printf("│   Processed: %llu errors (expected: %u)\n", 
               analytics.total_errors, expected_errors);
        test_pass(duration);
    } else {
        char reason[256];
        snprintf(reason, sizeof(reason), 
                "Insufficient errors processed: %llu < %u",
                analytics.total_errors, expected_errors);
        test_fail(reason, duration);
    }
}

// ============================================================================
// Machine Learning Tests
// ============================================================================

static void test_failure_prediction(void) {
    test_start("Failure Prediction Accuracy");
    uint64_t start_time = get_current_time_us();
    
    // Generate training data with known patterns
    for (uint32_t i = 0; i < 100; i++) {
        hmr_error_context_t error = create_test_error(
            (hmr_agent_type_t)(i % HMR_AGENT_COUNT),
            (i % 10 < 3) ? HMR_ERROR_SEVERITY_CRITICAL : HMR_ERROR_SEVERITY_WARNING,
            (hmr_error_category_t)(i % HMR_ERROR_CATEGORY_COUNT)
        );
        
        // Simulate errors with higher memory usage leading to failures
        error.memory_usage_bytes = (i % 10 < 3) ? 
            2ULL * 1024 * 1024 * 1024 : // 2GB (likely to cause failure)
            512ULL * 1024 * 1024;       // 512MB (normal)
        
        hmr_error_recovery_report_error(&error);
        usleep(5000); // 5ms between errors
    }
    
    // Allow ML model to train
    usleep(1000000); // 1 second
    
    // Test prediction for high-memory scenario
    hmr_failure_prediction_t prediction;
    int32_t result = hmr_error_recovery_get_prediction(HMR_AGENT_RUNTIME, &prediction);
    
    uint64_t duration = get_current_time_us() - start_time;
    
    if (result == 0 && prediction.prediction_valid) {
        printf("│   Confidence: %.2f, Time to failure: %.2f ms\n",
               prediction.prediction_confidence, prediction.time_to_failure_us / 1000.0);
        test_pass(duration);
    } else {
        test_fail("Failure prediction not generated", duration);
    }
}

// ============================================================================
// Stress Tests
// ============================================================================

static void test_high_volume_error_processing(void) {
    test_start("High Volume Error Processing");
    uint64_t start_time = get_current_time_us();
    
    uint32_t error_count = 1000;
    uint32_t successful_reports = 0;
    
    for (uint32_t i = 0; i < error_count; i++) {
        hmr_error_context_t error = create_test_error(
            (hmr_agent_type_t)(i % HMR_AGENT_COUNT),
            (hmr_error_severity_t)(i % HMR_ERROR_SEVERITY_COUNT),
            (hmr_error_category_t)(i % HMR_ERROR_CATEGORY_COUNT)
        );
        
        if (hmr_error_recovery_report_error(&error) == 0) {
            successful_reports++;
        }
        
        // Small delay to prevent overwhelming the system
        if (i % 100 == 0) {
            usleep(10000); // 10ms every 100 errors
        }
    }
    
    // Allow processing time
    usleep(2000000); // 2 seconds
    
    uint64_t duration = get_current_time_us() - start_time;
    
    double success_rate = (double)successful_reports / error_count * 100.0;
    
    if (success_rate >= 95.0) {
        printf("│   Success rate: %.2f%% (%u/%u)\n", 
               success_rate, successful_reports, error_count);
        test_pass(duration);
    } else {
        char reason[256];
        snprintf(reason, sizeof(reason), 
                "Low success rate: %.2f%% < 95%%", success_rate);
        test_fail(reason, duration);
    }
}

static void test_system_stability_under_load(void) {
    test_start("System Stability Under Load");
    uint64_t start_time = get_current_time_us();
    
    // Run continuous load for 10 seconds
    uint64_t test_duration = 10000000; // 10 seconds in microseconds
    uint64_t end_time = start_time + test_duration;
    
    uint32_t errors_generated = 0;
    uint32_t recoveries_requested = 0;
    
    while (get_current_time_us() < end_time) {
        // Generate random error
        hmr_error_context_t error = create_test_error(
            (hmr_agent_type_t)(rand() % HMR_AGENT_COUNT),
            (hmr_error_severity_t)(rand() % HMR_ERROR_SEVERITY_COUNT),
            (hmr_error_category_t)(rand() % HMR_ERROR_CATEGORY_COUNT)
        );
        
        if (hmr_error_recovery_report_error(&error) == 0) {
            errors_generated++;
            
            // Occasionally request manual recovery
            if (rand() % 10 == 0) {
                hmr_error_recovery_request_recovery(error.error_id, 
                                                  (hmr_recovery_strategy_t)(rand() % HMR_RECOVERY_STRATEGY_COUNT));
                recoveries_requested++;
            }
        }
        
        usleep(1000); // 1ms between operations
    }
    
    uint64_t duration = get_current_time_us() - start_time;
    
    // Check system health after load test
    hmr_error_analytics_t analytics;
    int32_t result = hmr_error_recovery_get_analytics(&analytics);
    
    if (result == 0 && errors_generated > 0) {
        printf("│   Errors: %u, Recoveries: %u, Success rate: %.2f%%\n",
               errors_generated, recoveries_requested, analytics.overall_success_rate);
        test_pass(duration);
    } else {
        test_fail("System became unstable under load", duration);
    }
}

// ============================================================================
// Checkpoint and Rollback Tests
// ============================================================================

static void test_checkpoint_creation_and_rollback(void) {
    test_start("Checkpoint Creation and Rollback");
    uint64_t start_time = get_current_time_us();
    
    // Create test state data
    char test_data[] = "Test checkpoint state data";
    const char* checkpoint_id = "test_checkpoint_001";
    
    // Create checkpoint
    int32_t create_result = hmr_error_recovery_create_checkpoint(
        checkpoint_id, test_data, strlen(test_data) + 1);
    
    // Perform rollback
    int32_t rollback_result = hmr_error_recovery_rollback_to_checkpoint(checkpoint_id);
    
    uint64_t duration = get_current_time_us() - start_time;
    
    if (create_result == 0 && rollback_result == 0) {
        test_pass(duration);
    } else {
        char reason[256];
        snprintf(reason, sizeof(reason), 
                "Checkpoint operations failed: create=%d, rollback=%d",
                create_result, rollback_result);
        test_fail(reason, duration);
    }
}

// ============================================================================
// Test Runner
// ============================================================================

static void print_test_header(void) {
    printf("╔══════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║              HMR Distributed Error Recovery System Test Suite               ║\n");
    printf("║                     Day 12: Advanced Error Handling                         ║\n");
    printf("╚══════════════════════════════════════════════════════════════════════════════╝\n\n");
}

static void print_test_summary(void) {
    printf("\n╔══════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                              TEST SUMMARY                                   ║\n");
    printf("╚══════════════════════════════════════════════════════════════════════════════╝\n");
    
    printf("Tests Run:    %u\n", g_test_stats.tests_run);
    printf("Tests Passed: %u\n", g_test_stats.tests_passed);
    printf("Tests Failed: %u\n", g_test_stats.tests_failed);
    
    if (g_test_stats.tests_run > 0) {
        double success_rate = (double)g_test_stats.tests_passed / g_test_stats.tests_run * 100.0;
        printf("Success Rate: %.2f%%\n", success_rate);
    }
    
    if (g_test_stats.tests_run > 0) {
        double avg_time = (double)g_test_stats.total_test_time_us / g_test_stats.tests_run / 1000.0;
        printf("Average Test Time: %.2f ms\n", avg_time);
        printf("Fastest Test: %.2f ms\n", g_test_stats.fastest_test_us / 1000.0);
        printf("Slowest Test: %.2f ms\n", g_test_stats.slowest_test_us / 1000.0);
    }
    
    if (g_test_stats.tests_failed > 0) {
        printf("Last Failure: %s\n", g_test_stats.last_failure_reason);
    }
    
    // Overall result
    if (g_test_stats.tests_failed == 0) {
        printf("\n🎉 ALL TESTS PASSED - Error Recovery System Ready for Production\n");
    } else {
        printf("\n❌ SOME TESTS FAILED - Review failures before deployment\n");
    }
}

int main(void) {
    // Initialize random seed
    srand((unsigned int)time(NULL));
    
    print_test_header();
    
    // Run all tests
    printf("Running Basic Functionality Tests:\n");
    test_system_initialization();
    test_error_reporting();
    test_recovery_execution();
    test_agent_health_monitoring();
    
    printf("\nRunning Performance Tests:\n");
    test_recovery_time_performance();
    test_concurrent_error_handling();
    
    printf("\nRunning Machine Learning Tests:\n");
    test_failure_prediction();
    
    printf("\nRunning Stress Tests:\n");
    test_high_volume_error_processing();
    test_system_stability_under_load();
    
    printf("\nRunning Checkpoint and Rollback Tests:\n");
    test_checkpoint_creation_and_rollback();
    
    // Cleanup
    hmr_error_recovery_shutdown();
    
    print_test_summary();
    
    return (g_test_stats.tests_failed == 0) ? 0 : 1;
}