/**
 * @file system_wide_integration_test.h
 * @brief Agent 0: HMR Orchestrator - Week 4 Day 16 System-Wide Integration Testing
 * 
 * Comprehensive integration testing framework for all 6 HMR agents under maximum stress.
 * Validates system-wide coordination, performance, and stability under production loads.
 * 
 * Week 4 Focus: Final Polish & Production Deployment
 * Day 16 Goal: Complete system validation with 1M+ agents at 60 FPS
 * 
 * Performance Targets:
 * - System-wide latency: <50ms for complete HMR cycle
 * - Memory usage: <1GB for full system with 25+ agents
 * - CPU efficiency: <15% on Apple M1/M2 under full production load
 * - Network efficiency: <1MB/min for team collaboration
 * - Uptime guarantee: 99.99% availability with automatic recovery
 * 
 * @author Claude (Assistant)
 * @date 2025-06-16
 */

#ifndef SYSTEM_WIDE_INTEGRATION_TEST_H
#define SYSTEM_WIDE_INTEGRATION_TEST_H

#include <stdint.h>
#include <stdbool.h>
#include <sys/time.h>
#include <pthread.h>

#ifdef __cplusplus
extern "C" {
#endif

// Forward declarations
typedef struct hmr_distributed_error_recovery hmr_distributed_error_recovery_t;
typedef struct hmr_system_performance_orchestrator hmr_system_performance_orchestrator_t;

// =============================================================================
// CONSTANTS & CONFIGURATION
// =============================================================================

// System-wide test configuration
#define HMR_MAX_AGENTS 25                    // Maximum agents for large-scale testing
#define HMR_MAX_CONCURRENT_OPERATIONS 1000   // Concurrent operations per test
#define HMR_MAX_STRESS_DURATION_SECONDS 300  // 5-minute stress test
#define HMR_PERFORMANCE_SAMPLES 10000        // Samples for statistical analysis
#define HMR_COMPATIBILITY_TESTS 50           // Compatibility test scenarios

// Performance targets (Week 4 production requirements)
#define HMR_TARGET_LATENCY_MS 50             // <50ms for complete HMR cycle
#define HMR_TARGET_MEMORY_MB 1024            // <1GB for full system
#define HMR_TARGET_CPU_PERCENT 15            // <15% CPU on Apple M1/M2
#define HMR_TARGET_NETWORK_MB_PER_MIN 1      // <1MB/min for collaboration
#define HMR_TARGET_UPTIME_PERCENT 99.99      // 99.99% availability

// Agent type definitions for comprehensive testing
typedef enum {
    HMR_AGENT_VERSIONING = 0,      // Agent 1: Module versioning and compatibility
    HMR_AGENT_BUILD_PIPELINE = 1,  // Agent 2: Build optimization and caching
    HMR_AGENT_RUNTIME = 2,         // Agent 3: Runtime integration and hot-swapping
    HMR_AGENT_DEVELOPER_TOOLS = 3, // Agent 4: Developer dashboard and tooling
    HMR_AGENT_SHADER_PIPELINE = 4, // Agent 5: Shader management and compilation
    HMR_AGENT_ORCHESTRATOR = 5,    // Agent 0: System orchestration and coordination
    HMR_AGENT_COUNT = 6
} hmr_agent_type_t;

// Test categories for comprehensive validation
typedef enum {
    HMR_TEST_CATEGORY_BASIC_FUNCTIONALITY = 0,
    HMR_TEST_CATEGORY_PERFORMANCE_VALIDATION,
    HMR_TEST_CATEGORY_STRESS_TESTING,
    HMR_TEST_CATEGORY_SECURITY_AUDIT,
    HMR_TEST_CATEGORY_COMPATIBILITY,
    HMR_TEST_CATEGORY_SCALABILITY,
    HMR_TEST_CATEGORY_RELIABILITY,
    HMR_TEST_CATEGORY_INTEGRATION,
    HMR_TEST_CATEGORY_COUNT
} hmr_test_category_t;

// Test severity levels
typedef enum {
    HMR_TEST_SEVERITY_CRITICAL = 0,    // Must pass for production deployment
    HMR_TEST_SEVERITY_HIGH,            // Important for production stability
    HMR_TEST_SEVERITY_MEDIUM,          // Affects user experience
    HMR_TEST_SEVERITY_LOW,             // Nice-to-have features
    HMR_TEST_SEVERITY_COUNT
} hmr_test_severity_t;

// =============================================================================
// PERFORMANCE METRICS & MONITORING
// =============================================================================

// Comprehensive performance metrics structure
typedef struct {
    // Latency metrics (microseconds)
    uint64_t min_latency_us;
    uint64_t max_latency_us;
    uint64_t avg_latency_us;
    uint64_t p95_latency_us;
    uint64_t p99_latency_us;
    
    // Memory metrics (bytes)
    uint64_t min_memory_bytes;
    uint64_t max_memory_bytes;
    uint64_t avg_memory_bytes;
    uint64_t peak_memory_bytes;
    
    // CPU metrics (percentage * 100)
    uint32_t min_cpu_percent;
    uint32_t max_cpu_percent;
    uint32_t avg_cpu_percent;
    
    // Network metrics (bytes)
    uint64_t total_network_bytes;
    uint64_t network_bytes_per_second;
    
    // Throughput metrics
    uint32_t operations_per_second;
    uint32_t total_operations;
    uint32_t successful_operations;
    uint32_t failed_operations;
    
    // Availability metrics
    uint64_t total_uptime_us;
    uint64_t total_downtime_us;
    double availability_percent;
    
    // Error metrics
    uint32_t total_errors;
    uint32_t critical_errors;
    uint32_t recovered_errors;
    double error_rate_percent;
    
    // Test timing
    uint64_t test_start_time_us;
    uint64_t test_end_time_us;
    uint64_t test_duration_us;
    
    // Statistical analysis
    double latency_std_dev;
    double memory_std_dev;
    double cpu_std_dev;
    
} hmr_performance_metrics_t;

// Real-time system monitoring
typedef struct {
    // Agent health status
    bool agent_healthy[HMR_AGENT_COUNT];
    uint64_t agent_last_heartbeat[HMR_AGENT_COUNT];
    uint32_t agent_error_count[HMR_AGENT_COUNT];
    
    // System resources
    uint64_t system_memory_total;
    uint64_t system_memory_available;
    uint64_t system_memory_used;
    double system_cpu_usage;
    
    // Network status
    uint64_t network_bytes_sent;
    uint64_t network_bytes_received;
    uint32_t network_connections_active;
    uint32_t network_connections_failed;
    
    // Performance counters
    uint64_t cache_hits;
    uint64_t cache_misses;
    uint64_t disk_reads;
    uint64_t disk_writes;
    
    // Timing information
    uint64_t last_update_time_us;
    uint64_t monitoring_start_time_us;
    
} hmr_system_monitoring_t;

// =============================================================================
// TEST EXECUTION FRAMEWORK
// =============================================================================

// Individual test case definition
typedef struct {
    char name[256];
    char description[512];
    hmr_test_category_t category;
    hmr_test_severity_t severity;
    
    // Test configuration
    uint32_t timeout_seconds;
    uint32_t max_retries;
    bool requires_agents[HMR_AGENT_COUNT];
    
    // Test function pointer
    bool (*test_function)(void* context);
    void* test_context;
    
    // Test results
    bool passed;
    bool executed;
    uint64_t execution_time_us;
    char failure_reason[1024];
    hmr_performance_metrics_t metrics;
    
} hmr_test_case_t;

// Test suite configuration
typedef struct {
    char name[256];
    char description[512];
    
    // Test cases
    hmr_test_case_t* test_cases;
    uint32_t num_test_cases;
    
    // Execution configuration
    bool parallel_execution;
    uint32_t max_parallel_tests;
    uint32_t global_timeout_seconds;
    
    // Reporting configuration
    bool generate_html_report;
    bool generate_json_report;
    bool generate_csv_report;
    char report_directory[512];
    
} hmr_test_suite_t;

// Global test context
typedef struct {
    // Test configuration
    hmr_test_suite_t* test_suites;
    uint32_t num_test_suites;
    
    // System state
    hmr_system_monitoring_t system_monitor;
    hmr_performance_metrics_t global_metrics;
    
    // Agent coordination
    hmr_distributed_error_recovery_t* error_recovery;
    hmr_system_performance_orchestrator_t* performance_orchestrator;
    
    // Test execution state
    bool test_running;
    uint64_t test_start_time;
    uint32_t tests_executed;
    uint32_t tests_passed;
    uint32_t tests_failed;
    
    // Concurrency control
    pthread_mutex_t test_mutex;
    pthread_cond_t test_condition;
    
    // Results storage
    char results_json[65536];
    char results_html[65536];
    char results_csv[16384];
    
} hmr_system_wide_test_context_t;

// =============================================================================
// STRESS TESTING FRAMEWORK
// =============================================================================

// Stress test configuration
typedef struct {
    // Load parameters
    uint32_t concurrent_agents;
    uint32_t operations_per_second;
    uint32_t total_operations;
    uint32_t duration_seconds;
    
    // Resource constraints
    uint64_t max_memory_bytes;
    uint32_t max_cpu_percent;
    uint32_t max_network_mbps;
    
    // Failure injection
    bool enable_failure_injection;
    double failure_rate_percent;
    uint32_t failure_types;
    
    // Monitoring
    uint32_t monitoring_interval_ms;
    bool continuous_monitoring;
    
} hmr_stress_test_config_t;

// Stress test results
typedef struct {
    // Test configuration
    hmr_stress_test_config_t config;
    
    // Performance results
    hmr_performance_metrics_t performance;
    
    // Stability metrics
    uint32_t system_crashes;
    uint32_t agent_restarts;
    uint32_t memory_leaks_detected;
    uint32_t deadlocks_detected;
    
    // Resource usage peaks
    uint64_t peak_memory_usage;
    uint32_t peak_cpu_usage;
    uint32_t peak_network_usage;
    
    // Failure handling
    uint32_t failures_injected;
    uint32_t failures_recovered;
    uint32_t failures_unrecovered;
    double recovery_success_rate;
    
    // Test execution info
    uint64_t test_start_time;
    uint64_t test_end_time;
    uint64_t actual_duration_us;
    bool test_completed;
    char termination_reason[512];
    
} hmr_stress_test_results_t;

// =============================================================================
// SECURITY AUDIT FRAMEWORK
// =============================================================================

// Security test types
typedef enum {
    HMR_SECURITY_TEST_AUTHENTICATION = 0,
    HMR_SECURITY_TEST_AUTHORIZATION,
    HMR_SECURITY_TEST_INPUT_VALIDATION,
    HMR_SECURITY_TEST_BUFFER_OVERFLOW,
    HMR_SECURITY_TEST_MEMORY_CORRUPTION,
    HMR_SECURITY_TEST_PRIVILEGE_ESCALATION,
    HMR_SECURITY_TEST_DENIAL_OF_SERVICE,
    HMR_SECURITY_TEST_INFORMATION_DISCLOSURE,
    HMR_SECURITY_TEST_COUNT
} hmr_security_test_type_t;

// Security vulnerability classification
typedef enum {
    HMR_VULNERABILITY_CRITICAL = 0,    // Immediate security risk
    HMR_VULNERABILITY_HIGH,            // Significant security risk
    HMR_VULNERABILITY_MEDIUM,          // Moderate security risk
    HMR_VULNERABILITY_LOW,             // Low security risk
    HMR_VULNERABILITY_INFORMATIONAL,   // No immediate risk
    HMR_VULNERABILITY_COUNT
} hmr_vulnerability_severity_t;

// Security test result
typedef struct {
    hmr_security_test_type_t test_type;
    hmr_vulnerability_severity_t severity;
    
    bool vulnerability_found;
    char vulnerability_description[1024];
    char remediation_steps[1024];
    
    // Test details
    char test_name[256];
    uint64_t test_duration_us;
    bool test_passed;
    
    // Context information
    hmr_agent_type_t affected_agent;
    char affected_component[256];
    
} hmr_security_test_result_t;

// =============================================================================
// COMPATIBILITY TESTING FRAMEWORK
// =============================================================================

// Platform compatibility targets
typedef struct {
    // macOS versions
    bool test_macos_13_ventura;
    bool test_macos_14_sonoma;
    bool test_macos_15_sequoia;
    
    // Hardware configurations
    bool test_m1_mac;
    bool test_m1_pro_mac;
    bool test_m1_max_mac;
    bool test_m2_mac;
    bool test_m2_pro_mac;
    bool test_m2_max_mac;
    bool test_m3_mac;
    
    // Memory configurations
    bool test_8gb_ram;
    bool test_16gb_ram;
    bool test_32gb_ram;
    bool test_64gb_ram;
    
    // Storage configurations
    bool test_256gb_ssd;
    bool test_512gb_ssd;
    bool test_1tb_ssd;
    bool test_2tb_ssd;
    
} hmr_compatibility_targets_t;

// Compatibility test result
typedef struct {
    char platform_name[256];
    char hardware_description[512];
    
    bool compatibility_passed;
    char compatibility_issues[1024];
    
    // Performance on this platform
    hmr_performance_metrics_t platform_performance;
    
    // Feature availability
    bool all_features_available;
    char missing_features[512];
    
} hmr_compatibility_result_t;

// =============================================================================
// FUNCTION DECLARATIONS
// =============================================================================

// System-wide integration testing
hmr_system_wide_test_context_t* hmr_create_system_wide_test_context(void);
void hmr_destroy_system_wide_test_context(hmr_system_wide_test_context_t* context);

// Test execution
bool hmr_run_system_wide_tests(hmr_system_wide_test_context_t* context);
bool hmr_run_test_suite(hmr_system_wide_test_context_t* context, hmr_test_suite_t* suite);
bool hmr_run_single_test(hmr_system_wide_test_context_t* context, hmr_test_case_t* test);

// Stress testing
hmr_stress_test_results_t* hmr_run_stress_test(const hmr_stress_test_config_t* config);
bool hmr_validate_stress_test_results(const hmr_stress_test_results_t* results);

// Security audit
hmr_security_test_result_t* hmr_run_security_audit(hmr_agent_type_t agent);
bool hmr_validate_security_results(const hmr_security_test_result_t* results, uint32_t num_results);

// Compatibility testing
hmr_compatibility_result_t* hmr_run_compatibility_tests(const hmr_compatibility_targets_t* targets);
bool hmr_validate_compatibility_results(const hmr_compatibility_result_t* results, uint32_t num_results);

// Performance validation
bool hmr_validate_performance_targets(const hmr_performance_metrics_t* metrics);
bool hmr_validate_production_readiness(hmr_system_wide_test_context_t* context);

// Reporting and analysis
bool hmr_generate_test_report(hmr_system_wide_test_context_t* context, const char* output_path);
bool hmr_generate_html_report(hmr_system_wide_test_context_t* context, const char* html_path);
bool hmr_generate_json_report(hmr_system_wide_test_context_t* context, const char* json_path);
bool hmr_generate_csv_report(hmr_system_wide_test_context_t* context, const char* csv_path);

// Monitoring and metrics
void hmr_update_system_monitoring(hmr_system_monitoring_t* monitor);
void hmr_collect_performance_metrics(hmr_performance_metrics_t* metrics);
void hmr_analyze_performance_trends(const hmr_performance_metrics_t* metrics, uint32_t num_samples);

// Utility functions
uint64_t hmr_get_current_time_us(void);
double hmr_calculate_standard_deviation(const double* values, uint32_t count);
bool hmr_check_resource_limits(uint64_t memory_limit, uint32_t cpu_limit);

#ifdef __cplusplus
}
#endif

#endif // SYSTEM_WIDE_INTEGRATION_TEST_H
