/*
 * SimCity ARM64 - System Performance Coordination Test
 * Comprehensive test suite for multi-agent performance orchestration
 * 
 * Agent 0: HMR Orchestrator - Day 11
 * Week 3: Advanced Features & Production Optimization
 */

#include "system_performance_orchestrator.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <pthread.h>
#include <unistd.h>
#include <assert.h>

// Test configuration
#define TEST_DURATION_SECONDS 30
#define LOAD_TEST_AGENTS 6
#define STRESS_TEST_DURATION_SECONDS 10
#define PERFORMANCE_SAMPLES_TO_COLLECT 1000
#define LATENCY_THRESHOLD_MS 100
#define MEMORY_THRESHOLD_MB 2048
#define CPU_THRESHOLD_PERCENT 80

// Test agent simulators
typedef struct {
    hmr_agent_id_t agent_id;
    pthread_t thread;
    bool active;
    
    // Simulated workload parameters
    double base_cpu_usage;
    double base_memory_usage;
    double base_latency;
    double workload_multiplier;
    bool simulate_bottleneck;
    bool simulate_degradation;
    
    // Performance metrics
    uint64_t operations_completed;
    uint64_t total_processing_time_us;
    double average_response_time_ms;
    
} test_agent_simulator_t;

// Test results
typedef struct {
    bool test_passed;
    char test_name[64];
    uint64_t test_duration_us;
    
    // Performance metrics
    double max_system_latency_ms;
    double avg_system_latency_ms;
    double max_memory_usage_mb;
    double min_fps;
    uint32_t bottlenecks_detected;
    uint32_t alerts_generated;
    uint32_t optimizations_suggested;
    
    // Coordination metrics
    double coordination_overhead_ms;
    uint32_t cross_agent_optimizations;
    bool regression_detected;
    bool anomaly_detected;
    
    // Error conditions
    uint32_t coordination_failures;
    uint32_t timeout_violations;
    uint32_t memory_leaks_detected;
    
} test_result_t;

static test_agent_simulator_t g_test_agents[LOAD_TEST_AGENTS];
static test_result_t g_test_results[8]; // Multiple test scenarios
static uint32_t g_test_count = 0;
static pthread_mutex_t g_test_mutex = PTHREAD_MUTEX_INITIALIZER;

// Forward declarations
static void* test_agent_simulator_thread(void* arg);
static void test_agent_performance_callback(hmr_agent_performance_t* performance);
static test_result_t run_basic_coordination_test(void);
static test_result_t run_stress_test(void);
static test_result_t run_bottleneck_detection_test(void);
static test_result_t run_optimization_coordination_test(void);
static test_result_t run_regression_detection_test(void);
static test_result_t run_scalability_test(void);
static test_result_t run_latency_validation_test(void);
static test_result_t run_memory_efficiency_test(void);
static void simulate_agent_workload(test_agent_simulator_t* agent);
static void print_test_result(const test_result_t* result);
static void print_test_summary(void);
static uint64_t get_current_time_us(void);
static double calculate_standard_deviation(double* values, uint32_t count, double mean);

// Main test function
int main(int argc, char* argv[]) {
    (void)argc;
    (void)argv;
    
    printf("╔══════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║           HMR SYSTEM PERFORMANCE COORDINATION TEST SUITE                    ║\n");
    printf("║                    Agent 0: HMR Orchestrator - Day 11                       ║\n");
    printf("╚══════════════════════════════════════════════════════════════════════════════╝\n\n");
    
    // Initialize orchestrator
    hmr_orchestrator_config_t config = {
        .collection_interval_ms = 50,
        .analysis_interval_ms = 100,
        .alert_check_interval_ms = 75,
        .cpu_warning_threshold = 60.0,
        .cpu_critical_threshold = 80.0,
        .memory_warning_threshold_mb = 1024.0,
        .memory_critical_threshold_mb = 1536.0,
        .latency_warning_threshold_ms = 50.0,
        .latency_critical_threshold_ms = 100.0,
        .auto_optimization_enabled = true,
        .predictive_analysis_enabled = true,
        .cross_agent_coordination_enabled = true,
        .max_alerts_per_minute = 20,
        .alert_aggregation_enabled = true
    };
    
    if (hmr_system_performance_orchestrator_init(&config) != 0) {
        printf("[ERROR] Failed to initialize performance orchestrator\n");
        return 1;
    }
    
    printf("[INFO] Performance Orchestrator initialized successfully\n");
    printf("  Collection interval: %u ms\n", config.collection_interval_ms);
    printf("  Analysis interval: %u ms\n", config.analysis_interval_ms);
    printf("  Latency threshold: %.1f ms\n", config.latency_critical_threshold_ms);
    printf("\n");
    
    // Initialize test agent simulators
    for (int i = 0; i < LOAD_TEST_AGENTS; i++) {
        test_agent_simulator_t* agent = &g_test_agents[i];
        agent->agent_id = (hmr_agent_id_t)i;
        agent->base_cpu_usage = 10.0 + (rand() % 20); // 10-30%
        agent->base_memory_usage = 50.0 + (rand() % 100); // 50-150MB
        agent->base_latency = 1.0 + (rand() % 10); // 1-11ms
        agent->workload_multiplier = 1.0;
        agent->simulate_bottleneck = false;
        agent->simulate_degradation = false;
        agent->active = false;
        
        // Register performance callback
        hmr_register_agent_performance_provider(agent->agent_id, test_agent_performance_callback);
    }
    
    printf("[INFO] Test agent simulators initialized\n\n");
    
    // Run test suite
    printf("Running comprehensive test suite...\n\n");
    
    g_test_results[g_test_count++] = run_basic_coordination_test();
    g_test_results[g_test_count++] = run_latency_validation_test();
    g_test_results[g_test_count++] = run_bottleneck_detection_test();
    g_test_results[g_test_count++] = run_optimization_coordination_test();
    g_test_results[g_test_count++] = run_memory_efficiency_test();
    g_test_results[g_test_count++] = run_regression_detection_test();
    g_test_results[g_test_count++] = run_scalability_test();
    g_test_results[g_test_count++] = run_stress_test();
    
    // Print results
    printf("\n");
    printf("╔══════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                            TEST RESULTS SUMMARY                             ║\n");
    printf("╚══════════════════════════════════════════════════════════════════════════════╝\n\n");
    
    for (uint32_t i = 0; i < g_test_count; i++) {
        print_test_result(&g_test_results[i]);
    }
    
    print_test_summary();
    
    // Cleanup
    hmr_system_performance_orchestrator_shutdown();
    
    printf("\n[INFO] System Performance Coordination Test Suite completed\n");
    
    // Return exit code based on test results
    for (uint32_t i = 0; i < g_test_count; i++) {
        if (!g_test_results[i].test_passed) {
            return 1; // Test failure
        }
    }
    
    return 0; // All tests passed
}

// Basic coordination test
static test_result_t run_basic_coordination_test(void) {
    test_result_t result = {0};
    strncpy(result.test_name, "Basic Coordination", sizeof(result.test_name) - 1);
    
    printf("┌─ Basic Coordination Test ─────────────────────────────────────────────────┐\n");
    printf("│ Testing basic system coordination with all agents running...              │\n");
    printf("└────────────────────────────────────────────────────────────────────────────┘\n");
    
    uint64_t start_time = get_current_time_us();
    
    // Start all agent simulators
    for (int i = 0; i < LOAD_TEST_AGENTS; i++) {
        g_test_agents[i].active = true;
        pthread_create(&g_test_agents[i].thread, NULL, test_agent_simulator_thread, &g_test_agents[i]);
    }
    
    // Run test for specified duration
    uint32_t samples_collected = 0;
    double latency_sum = 0.0;
    double max_latency = 0.0;
    double max_memory = 0.0;
    double min_fps = 60.0;
    
    for (int second = 0; second < TEST_DURATION_SECONDS; second++) {
        sleep(1);
        
        hmr_system_performance_t perf;
        if (hmr_get_system_performance(&perf) == 0) {
            samples_collected++;
            latency_sum += perf.system_latency_ms;
            
            if (perf.system_latency_ms > max_latency) {
                max_latency = perf.system_latency_ms;
            }
            if (perf.system_memory_usage_mb > max_memory) {
                max_memory = perf.system_memory_usage_mb;
            }
            if (perf.system_fps < min_fps) {
                min_fps = perf.system_fps;
            }
            
            printf("  Progress: %d/%d seconds - Latency: %.1fms, Memory: %.1fMB, FPS: %.1f\n",
                   second + 1, TEST_DURATION_SECONDS, perf.system_latency_ms, 
                   perf.system_memory_usage_mb, perf.system_fps);
        }
    }
    
    // Stop agent simulators
    for (int i = 0; i < LOAD_TEST_AGENTS; i++) {
        g_test_agents[i].active = false;
        pthread_join(g_test_agents[i].thread, NULL);
    }
    
    uint64_t end_time = get_current_time_us();
    result.test_duration_us = end_time - start_time;
    
    // Evaluate results
    result.max_system_latency_ms = max_latency;
    result.avg_system_latency_ms = samples_collected > 0 ? latency_sum / samples_collected : 0.0;
    result.max_memory_usage_mb = max_memory;
    result.min_fps = min_fps;
    
    // Test passes if latency < 100ms and memory < 2GB
    result.test_passed = (max_latency < LATENCY_THRESHOLD_MS) && 
                        (max_memory < MEMORY_THRESHOLD_MB) && 
                        (min_fps > 30.0);
    
    printf("  Test completed: %s\n", result.test_passed ? "PASSED" : "FAILED");
    printf("  Max latency: %.1fms (threshold: %dms)\n", max_latency, LATENCY_THRESHOLD_MS);
    printf("  Max memory: %.1fMB (threshold: %dMB)\n", max_memory, MEMORY_THRESHOLD_MB);
    printf("  Min FPS: %.1f (threshold: 30.0)\n\n", min_fps);
    
    return result;
}

// Latency validation test
static test_result_t run_latency_validation_test(void) {
    test_result_t result = {0};
    strncpy(result.test_name, "Latency Validation", sizeof(result.test_name) - 1);
    
    printf("┌─ Latency Validation Test ─────────────────────────────────────────────────┐\n");
    printf("│ Testing system-wide latency under normal load conditions...               │\n");
    printf("└────────────────────────────────────────────────────────────────────────────┘\n");
    
    uint64_t start_time = get_current_time_us();
    
    // Start agents with normal workload
    for (int i = 0; i < LOAD_TEST_AGENTS; i++) {
        g_test_agents[i].workload_multiplier = 1.0;
        g_test_agents[i].active = true;
        pthread_create(&g_test_agents[i].thread, NULL, test_agent_simulator_thread, &g_test_agents[i]);
    }
    
    // Collect latency measurements
    double latency_measurements[PERFORMANCE_SAMPLES_TO_COLLECT];
    uint32_t measurement_count = 0;
    
    while (measurement_count < PERFORMANCE_SAMPLES_TO_COLLECT) {
        usleep(50000); // 50ms between measurements
        
        hmr_system_performance_t perf;
        if (hmr_get_system_performance(&perf) == 0) {
            latency_measurements[measurement_count] = perf.system_latency_ms;
            measurement_count++;
            
            if (measurement_count % 100 == 0) {
                printf("  Collected %u/%u latency measurements\n", measurement_count, PERFORMANCE_SAMPLES_TO_COLLECT);
            }
        }
    }
    
    // Stop agents
    for (int i = 0; i < LOAD_TEST_AGENTS; i++) {
        g_test_agents[i].active = false;
        pthread_join(g_test_agents[i].thread, NULL);
    }
    
    uint64_t end_time = get_current_time_us();
    result.test_duration_us = end_time - start_time;
    
    // Analyze latency statistics
    double sum = 0.0, max_latency = 0.0, min_latency = latency_measurements[0];
    for (uint32_t i = 0; i < measurement_count; i++) {
        sum += latency_measurements[i];
        if (latency_measurements[i] > max_latency) max_latency = latency_measurements[i];
        if (latency_measurements[i] < min_latency) min_latency = latency_measurements[i];
    }
    
    double avg_latency = sum / measurement_count;
    double std_dev = calculate_standard_deviation(latency_measurements, measurement_count, avg_latency);
    
    // Count violations
    uint32_t violations = 0;
    for (uint32_t i = 0; i < measurement_count; i++) {
        if (latency_measurements[i] > LATENCY_THRESHOLD_MS) {
            violations++;
        }
    }
    
    result.max_system_latency_ms = max_latency;
    result.avg_system_latency_ms = avg_latency;
    
    // Test passes if 95% of measurements are under threshold and max < 150ms
    double violation_rate = (double)violations / measurement_count;
    result.test_passed = (violation_rate < 0.05) && (max_latency < 150.0);
    
    printf("  Latency statistics:\n");
    printf("    Average: %.2fms\n", avg_latency);
    printf("    Min: %.2fms, Max: %.2fms\n", min_latency, max_latency);
    printf("    Standard deviation: %.2fms\n", std_dev);
    printf("    Violations: %u/%u (%.1f%%)\n", violations, measurement_count, violation_rate * 100.0);
    printf("  Test: %s\n\n", result.test_passed ? "PASSED" : "FAILED");
    
    return result;
}

// Bottleneck detection test
static test_result_t run_bottleneck_detection_test(void) {
    test_result_t result = {0};
    strncpy(result.test_name, "Bottleneck Detection", sizeof(result.test_name) - 1);
    
    printf("┌─ Bottleneck Detection Test ───────────────────────────────────────────────┐\n");
    printf("│ Testing automatic bottleneck detection and coordination...                │\n");
    printf("└────────────────────────────────────────────────────────────────────────────┘\n");
    
    uint64_t start_time = get_current_time_us();
    
    // Start agents with one simulated bottleneck
    for (int i = 0; i < LOAD_TEST_AGENTS; i++) {
        g_test_agents[i].workload_multiplier = 1.0;
        g_test_agents[i].simulate_bottleneck = (i == 2); // Agent 2 becomes bottleneck
        g_test_agents[i].active = true;
        pthread_create(&g_test_agents[i].thread, NULL, test_agent_simulator_thread, &g_test_agents[i]);
    }
    
    printf("  Simulating bottleneck on agent: %s\n", hmr_agent_id_to_string(HMR_AGENT_RUNTIME));
    
    // Monitor for bottleneck detection
    uint32_t bottlenecks_detected = 0;
    bool bottleneck_found = false;
    
    for (int second = 0; second < 15; second++) {
        sleep(1);
        
        hmr_system_performance_t perf;
        if (hmr_get_system_performance(&perf) == 0) {
            if (perf.primary_bottleneck != HMR_AGENT_COUNT) {
                bottlenecks_detected++;
                if (!bottleneck_found) {
                    printf("  Bottleneck detected: %s (severity: %.1f%%)\n", 
                           hmr_agent_id_to_string(perf.primary_bottleneck),
                           perf.bottleneck_severity * 100.0);
                    bottleneck_found = true;
                }
            }
            
            printf("    Second %d: Primary bottleneck: %s, System latency: %.1fms\n",
                   second + 1, 
                   perf.primary_bottleneck != HMR_AGENT_COUNT ? 
                   hmr_agent_id_to_string(perf.primary_bottleneck) : "None",
                   perf.system_latency_ms);
        }
    }
    
    // Stop agents
    for (int i = 0; i < LOAD_TEST_AGENTS; i++) {
        g_test_agents[i].active = false;
        g_test_agents[i].simulate_bottleneck = false;
        pthread_join(g_test_agents[i].thread, NULL);
    }
    
    uint64_t end_time = get_current_time_us();
    result.test_duration_us = end_time - start_time;
    result.bottlenecks_detected = bottlenecks_detected;
    
    // Test passes if bottleneck was detected within 10 seconds
    result.test_passed = bottleneck_found && (bottlenecks_detected >= 5);
    
    printf("  Bottleneck detection: %s\n", bottleneck_found ? "SUCCESS" : "FAILED");
    printf("  Total detections: %u\n", bottlenecks_detected);
    printf("  Test: %s\n\n", result.test_passed ? "PASSED" : "FAILED");
    
    return result;
}

// Optimization coordination test
static test_result_t run_optimization_coordination_test(void) {
    test_result_t result = {0};
    strncpy(result.test_name, "Optimization Coordination", sizeof(result.test_name) - 1);
    
    printf("┌─ Optimization Coordination Test ──────────────────────────────────────────┐\n");
    printf("│ Testing cross-agent optimization recommendations and coordination...       │\n");
    printf("└────────────────────────────────────────────────────────────────────────────┘\n");
    
    uint64_t start_time = get_current_time_us();
    
    // Start agents with degraded performance
    for (int i = 0; i < LOAD_TEST_AGENTS; i++) {
        g_test_agents[i].workload_multiplier = 1.5; // Increased load
        g_test_agents[i].simulate_degradation = (i % 2 == 0); // Half the agents degraded
        g_test_agents[i].active = true;
        pthread_create(&g_test_agents[i].thread, NULL, test_agent_simulator_thread, &g_test_agents[i]);
    }
    
    printf("  Simulating performance degradation on 50%% of agents\n");
    
    // Monitor optimization recommendations
    uint32_t total_recommendations = 0;
    bool optimizations_generated = false;
    
    for (int second = 0; second < 12; second++) {
        sleep(1);
        
        hmr_optimization_recommendation_t recommendations[20];
        uint32_t rec_count;
        
        if (hmr_analyze_bottlenecks(recommendations, 20, &rec_count) == 0) {
            if (rec_count > 0 && !optimizations_generated) {
                printf("  Optimization recommendations generated: %u\n", rec_count);
                for (uint32_t i = 0; i < rec_count && i < 3; i++) {
                    printf("    %s: %s (Priority: %u)\n",
                           hmr_agent_id_to_string(recommendations[i].target_agent),
                           recommendations[i].optimization_type,
                           recommendations[i].priority);
                }
                optimizations_generated = true;
            }
            total_recommendations += rec_count;
        }
        
        printf("    Second %d: Recommendations: %u\n", second + 1, rec_count);
    }
    
    // Stop agents
    for (int i = 0; i < LOAD_TEST_AGENTS; i++) {
        g_test_agents[i].active = false;
        g_test_agents[i].simulate_degradation = false;
        g_test_agents[i].workload_multiplier = 1.0;
        pthread_join(g_test_agents[i].thread, NULL);
    }
    
    uint64_t end_time = get_current_time_us();
    result.test_duration_us = end_time - start_time;
    result.optimizations_suggested = total_recommendations;
    
    // Test passes if optimization recommendations were generated
    result.test_passed = optimizations_generated && (total_recommendations >= 10);
    
    printf("  Optimization generation: %s\n", optimizations_generated ? "SUCCESS" : "FAILED");
    printf("  Total recommendations: %u\n", total_recommendations);
    printf("  Test: %s\n\n", result.test_passed ? "PASSED" : "FAILED");
    
    return result;
}

// Memory efficiency test
static test_result_t run_memory_efficiency_test(void) {
    test_result_t result = {0};
    strncpy(result.test_name, "Memory Efficiency", sizeof(result.test_name) - 1);
    
    printf("┌─ Memory Efficiency Test ──────────────────────────────────────────────────┐\n");
    printf("│ Testing memory usage and leak detection across all agents...              │\n");
    printf("└────────────────────────────────────────────────────────────────────────────┘\n");
    
    uint64_t start_time = get_current_time_us();
    
    // Measure baseline memory
    hmr_system_performance_t baseline_perf;
    hmr_get_system_performance(&baseline_perf);
    double baseline_memory = baseline_perf.system_memory_usage_mb;
    
    printf("  Baseline memory usage: %.1f MB\n", baseline_memory);
    
    // Start agents with memory-intensive workload
    for (int i = 0; i < LOAD_TEST_AGENTS; i++) {
        g_test_agents[i].workload_multiplier = 2.0; // Memory intensive
        g_test_agents[i].active = true;
        pthread_create(&g_test_agents[i].thread, NULL, test_agent_simulator_thread, &g_test_agents[i]);
    }
    
    // Monitor memory usage over time
    double max_memory = 0.0;
    double memory_samples[20];
    uint32_t sample_count = 0;
    
    for (int second = 0; second < 20; second++) {
        sleep(1);
        
        hmr_system_performance_t perf;
        if (hmr_get_system_performance(&perf) == 0) {
            memory_samples[sample_count] = perf.system_memory_usage_mb;
            sample_count++;
            
            if (perf.system_memory_usage_mb > max_memory) {
                max_memory = perf.system_memory_usage_mb;
            }
            
            printf("    Second %d: Memory usage: %.1f MB\n", second + 1, perf.system_memory_usage_mb);
        }
    }
    
    // Stop agents
    for (int i = 0; i < LOAD_TEST_AGENTS; i++) {
        g_test_agents[i].active = false;
        g_test_agents[i].workload_multiplier = 1.0;
        pthread_join(g_test_agents[i].thread, NULL);
    }
    
    // Check for memory leaks after cleanup
    sleep(2);
    hmr_system_performance_t final_perf;
    hmr_get_system_performance(&final_perf);
    double final_memory = final_perf.system_memory_usage_mb;
    
    double memory_increase = final_memory - baseline_memory;
    bool memory_leak = memory_increase > 50.0; // 50MB threshold for leak detection
    
    uint64_t end_time = get_current_time_us();
    result.test_duration_us = end_time - start_time;
    result.max_memory_usage_mb = max_memory;
    result.memory_leaks_detected = memory_leak ? 1 : 0;
    
    // Test passes if memory usage stays within bounds and no significant leaks
    result.test_passed = (max_memory < MEMORY_THRESHOLD_MB) && !memory_leak;
    
    printf("  Final memory usage: %.1f MB\n", final_memory);
    printf("  Memory increase: %.1f MB\n", memory_increase);
    printf("  Max memory usage: %.1f MB (threshold: %d MB)\n", max_memory, MEMORY_THRESHOLD_MB);
    printf("  Memory leak detected: %s\n", memory_leak ? "YES" : "NO");
    printf("  Test: %s\n\n", result.test_passed ? "PASSED" : "FAILED");
    
    return result;
}

// Regression detection test
static test_result_t run_regression_detection_test(void) {
    test_result_t result = {0};
    strncpy(result.test_name, "Regression Detection", sizeof(result.test_name) - 1);
    
    printf("┌─ Regression Detection Test ───────────────────────────────────────────────┐\n");
    printf("│ Testing performance regression detection and alerting...                   │\n");
    printf("└────────────────────────────────────────────────────────────────────────────┘\n");
    
    uint64_t start_time = get_current_time_us();
    
    // Create baseline with normal performance
    printf("  Establishing performance baseline...\n");
    for (int i = 0; i < LOAD_TEST_AGENTS; i++) {
        g_test_agents[i].workload_multiplier = 1.0;
        g_test_agents[i].active = true;
        pthread_create(&g_test_agents[i].thread, NULL, test_agent_simulator_thread, &g_test_agents[i]);
    }
    
    sleep(5); // Collect baseline data
    
    // Simulate performance regression
    printf("  Simulating performance regression...\n");
    for (int i = 0; i < LOAD_TEST_AGENTS; i++) {
        g_test_agents[i].workload_multiplier = 3.0; // Significant degradation
        g_test_agents[i].simulate_degradation = true;
    }
    
    // Monitor for regression detection
    bool regression_detected = false;
    uint32_t alerts = 0;
    
    for (int second = 0; second < 10; second++) {
        sleep(1);
        
        hmr_system_performance_t perf;
        if (hmr_get_system_performance(&perf) == 0) {
            if (perf.performance_degradation_detected) {
                if (!regression_detected) {
                    printf("  Performance regression detected at second %d\n", second + 1);
                    regression_detected = true;
                }
            }
            
            hmr_performance_alert_t alert_buffer[10];
            uint32_t alert_count;
            if (hmr_get_performance_alerts(alert_buffer, 10, &alert_count) == 0) {
                alerts += alert_count;
            }
            
            printf("    Second %d: Regression detected: %s, System FPS: %.1f\n",
                   second + 1, perf.performance_degradation_detected ? "YES" : "NO", perf.system_fps);
        }
    }
    
    // Stop agents
    for (int i = 0; i < LOAD_TEST_AGENTS; i++) {
        g_test_agents[i].active = false;
        g_test_agents[i].simulate_degradation = false;
        g_test_agents[i].workload_multiplier = 1.0;
        pthread_join(g_test_agents[i].thread, NULL);
    }
    
    uint64_t end_time = get_current_time_us();
    result.test_duration_us = end_time - start_time;
    result.regression_detected = regression_detected;
    result.alerts_generated = alerts;
    
    // Test passes if regression was detected and alerts were generated
    result.test_passed = regression_detected && (alerts > 0);
    
    printf("  Regression detection: %s\n", regression_detected ? "SUCCESS" : "FAILED");
    printf("  Alerts generated: %u\n", alerts);
    printf("  Test: %s\n\n", result.test_passed ? "PASSED" : "FAILED");
    
    return result;
}

// Scalability test
static test_result_t run_scalability_test(void) {
    test_result_t result = {0};
    strncpy(result.test_name, "Scalability", sizeof(result.test_name) - 1);
    
    printf("┌─ Scalability Test ────────────────────────────────────────────────────────┐\n");
    printf("│ Testing system performance with increasing agent load...                  │\n");
    printf("└────────────────────────────────────────────────────────────────────────────┘\n");
    
    uint64_t start_time = get_current_time_us();
    
    double latency_measurements[LOAD_TEST_AGENTS];
    double memory_measurements[LOAD_TEST_AGENTS];
    
    // Test with incremental agent load
    for (int agent_count = 1; agent_count <= LOAD_TEST_AGENTS; agent_count++) {
        printf("  Testing with %d agents...\n", agent_count);
        
        // Start agents up to current count
        for (int i = 0; i < agent_count; i++) {
            g_test_agents[i].workload_multiplier = 1.0;
            g_test_agents[i].active = true;
            pthread_create(&g_test_agents[i].thread, NULL, test_agent_simulator_thread, &g_test_agents[i]);
        }
        
        // Let system stabilize
        sleep(2);
        
        // Measure performance
        hmr_system_performance_t perf;
        if (hmr_get_system_performance(&perf) == 0) {
            latency_measurements[agent_count - 1] = perf.system_latency_ms;
            memory_measurements[agent_count - 1] = perf.system_memory_usage_mb;
            
            printf("    %d agents: Latency %.1fms, Memory %.1fMB\n",
                   agent_count, perf.system_latency_ms, perf.system_memory_usage_mb);
        }
        
        // Stop agents
        for (int i = 0; i < agent_count; i++) {
            g_test_agents[i].active = false;
            pthread_join(g_test_agents[i].thread, NULL);
        }
        
        sleep(1); // Cool down between tests
    }
    
    uint64_t end_time = get_current_time_us();
    result.test_duration_us = end_time - start_time;
    
    // Analyze scalability characteristics
    double max_latency = latency_measurements[LOAD_TEST_AGENTS - 1];
    double max_memory = memory_measurements[LOAD_TEST_AGENTS - 1];
    
    // Check for linear scaling (latency should not grow exponentially)
    double latency_growth_factor = latency_measurements[LOAD_TEST_AGENTS - 1] / latency_measurements[0];
    bool good_scaling = latency_growth_factor < (double)LOAD_TEST_AGENTS * 1.5; // Allow 1.5x per agent
    
    result.max_system_latency_ms = max_latency;
    result.max_memory_usage_mb = max_memory;
    
    // Test passes if system scales reasonably with agent count
    result.test_passed = good_scaling && (max_latency < LATENCY_THRESHOLD_MS * 1.5);
    
    printf("  Scalability analysis:\n");
    printf("    Latency growth factor: %.2fx\n", latency_growth_factor);
    printf("    Final latency: %.1fms (threshold: %.1fms)\n", max_latency, LATENCY_THRESHOLD_MS * 1.5);
    printf("    Final memory: %.1fMB\n", max_memory);
    printf("    Good scaling: %s\n", good_scaling ? "YES" : "NO");
    printf("  Test: %s\n\n", result.test_passed ? "PASSED" : "FAILED");
    
    return result;
}

// Stress test
static test_result_t run_stress_test(void) {
    test_result_t result = {0};
    strncpy(result.test_name, "Stress Test", sizeof(result.test_name) - 1);
    
    printf("┌─ Stress Test ─────────────────────────────────────────────────────────────┐\n");
    printf("│ Testing system stability under maximum load conditions...                 │\n");
    printf("└────────────────────────────────────────────────────────────────────────────┘\n");
    
    uint64_t start_time = get_current_time_us();
    
    // Start all agents with maximum stress workload
    for (int i = 0; i < LOAD_TEST_AGENTS; i++) {
        g_test_agents[i].workload_multiplier = 4.0; // Maximum stress
        g_test_agents[i].simulate_bottleneck = (i % 3 == 0); // Some bottlenecks
        g_test_agents[i].simulate_degradation = (i % 2 == 0); // Some degradation
        g_test_agents[i].active = true;
        pthread_create(&g_test_agents[i].thread, NULL, test_agent_simulator_thread, &g_test_agents[i]);
    }
    
    printf("  Running maximum stress test for %d seconds...\n", STRESS_TEST_DURATION_SECONDS);
    
    // Monitor system under stress
    double max_latency = 0.0;
    double max_memory = 0.0;
    double min_fps = 60.0;
    uint32_t timeout_violations = 0;
    uint32_t coordination_failures = 0;
    
    for (int second = 0; second < STRESS_TEST_DURATION_SECONDS; second++) {
        sleep(1);
        
        hmr_system_performance_t perf;
        if (hmr_get_system_performance(&perf) == 0) {
            if (perf.system_latency_ms > max_latency) {
                max_latency = perf.system_latency_ms;
            }
            if (perf.system_memory_usage_mb > max_memory) {
                max_memory = perf.system_memory_usage_mb;
            }
            if (perf.system_fps < min_fps) {
                min_fps = perf.system_fps;
            }
            
            // Check for violations
            if (perf.system_latency_ms > LATENCY_THRESHOLD_MS * 2) {
                timeout_violations++;
            }
            if (!perf.system_healthy) {
                coordination_failures++;
            }
            
            printf("    Second %d: Latency %.1fms, Memory %.1fMB, FPS %.1f, Healthy: %s\n",
                   second + 1, perf.system_latency_ms, perf.system_memory_usage_mb, 
                   perf.system_fps, perf.system_healthy ? "YES" : "NO");
        } else {
            coordination_failures++;
        }
    }
    
    // Stop agents
    for (int i = 0; i < LOAD_TEST_AGENTS; i++) {
        g_test_agents[i].active = false;
        g_test_agents[i].simulate_bottleneck = false;
        g_test_agents[i].simulate_degradation = false;
        g_test_agents[i].workload_multiplier = 1.0;
        pthread_join(g_test_agents[i].thread, NULL);
    }
    
    uint64_t end_time = get_current_time_us();
    result.test_duration_us = end_time - start_time;
    result.max_system_latency_ms = max_latency;
    result.max_memory_usage_mb = max_memory;
    result.min_fps = min_fps;
    result.timeout_violations = timeout_violations;
    result.coordination_failures = coordination_failures;
    
    // Test passes if system remains stable under stress
    result.test_passed = (coordination_failures < STRESS_TEST_DURATION_SECONDS / 2) && 
                        (max_memory < MEMORY_THRESHOLD_MB * 1.5) &&
                        (min_fps > 15.0); // Reduced threshold under stress
    
    printf("  Stress test results:\n");
    printf("    Max latency: %.1fms\n", max_latency);
    printf("    Max memory: %.1fMB (threshold: %.1fMB)\n", max_memory, MEMORY_THRESHOLD_MB * 1.5);
    printf("    Min FPS: %.1f (threshold: 15.0)\n", min_fps);
    printf("    Timeout violations: %u\n", timeout_violations);
    printf("    Coordination failures: %u/%d\n", coordination_failures, STRESS_TEST_DURATION_SECONDS);
    printf("  Test: %s\n\n", result.test_passed ? "PASSED" : "FAILED");
    
    return result;
}

// Agent simulator thread
static void* test_agent_simulator_thread(void* arg) {
    test_agent_simulator_t* agent = (test_agent_simulator_t*)arg;
    
    while (agent->active) {
        simulate_agent_workload(agent);
        
        // Simulate processing time based on workload
        usleep((10 + rand() % 20) * agent->workload_multiplier * 1000); // 10-30ms base
        
        agent->operations_completed++;
    }
    
    return NULL;
}

// Simulate agent workload
static void simulate_agent_workload(test_agent_simulator_t* agent) {
    uint64_t start_time = get_current_time_us();
    
    // Simulate CPU-intensive work
    double result = 0.0;
    int iterations = (int)(1000 * agent->workload_multiplier);
    for (int i = 0; i < iterations; i++) {
        result += sin(i) * cos(i);
    }
    
    // Simulate memory allocation/deallocation
    if (agent->workload_multiplier > 1.0) {
        void* temp_memory = malloc(1024 * (int)agent->workload_multiplier);
        if (temp_memory) {
            memset(temp_memory, 0, 1024 * (int)agent->workload_multiplier);
            free(temp_memory);
        }
    }
    
    uint64_t end_time = get_current_time_us();
    agent->total_processing_time_us += (end_time - start_time);
    
    if (agent->operations_completed > 0) {
        agent->average_response_time_ms = 
            (double)agent->total_processing_time_us / (agent->operations_completed * 1000.0);
    }
}

// Agent performance callback
static void test_agent_performance_callback(hmr_agent_performance_t* performance) {
    if (!performance || performance->agent_id >= LOAD_TEST_AGENTS) {
        return;
    }
    
    test_agent_simulator_t* agent = &g_test_agents[performance->agent_id];
    
    // Update performance metrics based on simulated workload
    performance->cpu_usage_percent = agent->base_cpu_usage * agent->workload_multiplier;
    performance->memory_usage_mb = agent->base_memory_usage * agent->workload_multiplier;
    performance->latency_ms = agent->base_latency * agent->workload_multiplier;
    performance->throughput_ops_per_sec = 1000.0 / agent->workload_multiplier;
    performance->error_rate_percent = agent->simulate_degradation ? 2.0 : 0.1;
    
    // Apply bottleneck simulation
    if (agent->simulate_bottleneck) {
        performance->cpu_usage_percent *= 2.0;
        performance->latency_ms *= 3.0;
        performance->throughput_ops_per_sec /= 4.0;
    }
    
    // Apply degradation simulation
    if (agent->simulate_degradation) {
        performance->latency_ms *= 1.5;
        performance->error_rate_percent += 1.0;
        performance->throughput_ops_per_sec *= 0.7;
    }
    
    // Calculate health and performance score
    performance->is_healthy = (performance->latency_ms < 50.0) && 
                             (performance->error_rate_percent < 5.0) &&
                             (performance->cpu_usage_percent < 80.0);
    
    performance->has_bottleneck = agent->simulate_bottleneck;
    performance->needs_optimization = agent->simulate_degradation || 
                                    (performance->latency_ms > 30.0);
    
    // Calculate performance score
    double latency_score = 1.0 - (performance->latency_ms / 100.0);
    double cpu_score = 1.0 - (performance->cpu_usage_percent / 100.0);
    double error_score = 1.0 - (performance->error_rate_percent / 100.0);
    double throughput_score = performance->throughput_ops_per_sec / 1000.0;
    
    // Clamp scores
    latency_score = latency_score < 0.0 ? 0.0 : (latency_score > 1.0 ? 1.0 : latency_score);
    cpu_score = cpu_score < 0.0 ? 0.0 : (cpu_score > 1.0 ? 1.0 : cpu_score);
    error_score = error_score < 0.0 ? 0.0 : (error_score > 1.0 ? 1.0 : error_score);
    throughput_score = throughput_score < 0.0 ? 0.0 : (throughput_score > 1.0 ? 1.0 : throughput_score);
    
    performance->performance_score = (latency_score * 0.4 + error_score * 0.3 + 
                                     cpu_score * 0.2 + throughput_score * 0.1);
    
    performance->last_update_timestamp_us = get_current_time_us();
}

// Print test result
static void print_test_result(const test_result_t* result) {
    printf("┌─ %s %s\n", result->test_name, result->test_passed ? "✓ PASSED" : "✗ FAILED");
    printf("│ Duration: %.2f seconds\n", result->test_duration_us / 1000000.0);
    
    if (result->max_system_latency_ms > 0.0) {
        printf("│ Max Latency: %.1fms", result->max_system_latency_ms);
        if (result->avg_system_latency_ms > 0.0) {
            printf(" (Avg: %.1fms)", result->avg_system_latency_ms);
        }
        printf("\n");
    }
    
    if (result->max_memory_usage_mb > 0.0) {
        printf("│ Max Memory: %.1f MB\n", result->max_memory_usage_mb);
    }
    
    if (result->min_fps > 0.0) {
        printf("│ Min FPS: %.1f\n", result->min_fps);
    }
    
    if (result->bottlenecks_detected > 0) {
        printf("│ Bottlenecks Detected: %u\n", result->bottlenecks_detected);
    }
    
    if (result->alerts_generated > 0) {
        printf("│ Alerts Generated: %u\n", result->alerts_generated);
    }
    
    if (result->optimizations_suggested > 0) {
        printf("│ Optimizations Suggested: %u\n", result->optimizations_suggested);
    }
    
    if (result->timeout_violations > 0) {
        printf("│ Timeout Violations: %u\n", result->timeout_violations);
    }
    
    if (result->coordination_failures > 0) {
        printf("│ Coordination Failures: %u\n", result->coordination_failures);
    }
    
    if (result->memory_leaks_detected > 0) {
        printf("│ Memory Leaks: %u\n", result->memory_leaks_detected);
    }
    
    printf("└────────────────────────────────────────────────────────────────────────────\n\n");
}

// Print test summary
static void print_test_summary(void) {
    uint32_t passed_tests = 0;
    uint32_t failed_tests = 0;
    double total_duration = 0.0;
    
    for (uint32_t i = 0; i < g_test_count; i++) {
        if (g_test_results[i].test_passed) {
            passed_tests++;
        } else {
            failed_tests++;
        }
        total_duration += g_test_results[i].test_duration_us / 1000000.0;
    }
    
    printf("╔══════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                              FINAL RESULTS                                  ║\n");
    printf("╠══════════════════════════════════════════════════════════════════════════════╣\n");
    printf("║ Tests Passed: %2u/%u                                                        ║\n", passed_tests, g_test_count);
    printf("║ Tests Failed: %2u/%u                                                        ║\n", failed_tests, g_test_count);
    printf("║ Total Duration: %.1f seconds                                               ║\n", total_duration);
    printf("║                                                                              ║\n");
    
    if (failed_tests == 0) {
        printf("║ ✓ ALL TESTS PASSED - System Performance Coordination is PRODUCTION READY   ║\n");
    } else {
        printf("║ ✗ SOME TESTS FAILED - System needs optimization before production          ║\n");
    }
    
    printf("╚══════════════════════════════════════════════════════════════════════════════╝\n");
}

// Utility functions
static uint64_t get_current_time_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
}

static double calculate_standard_deviation(double* values, uint32_t count, double mean) {
    if (count <= 1) return 0.0;
    
    double sum_squared_diff = 0.0;
    for (uint32_t i = 0; i < count; i++) {
        double diff = values[i] - mean;
        sum_squared_diff += diff * diff;
    }
    
    return sqrt(sum_squared_diff / (count - 1));
}