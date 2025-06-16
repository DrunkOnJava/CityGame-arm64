/*
 * SimCity ARM64 - Agent 1: Core Module System
 * Week 4, Day 16 - Comprehensive Testing Framework
 * 
 * Enterprise-grade testing infrastructure for production validation
 * - >99% code coverage across all module functions
 * - Integration testing with all 10 agents under maximum stress
 * - Performance testing under realistic production workloads
 * - Security testing with enterprise threat modeling
 * 
 * Performance Targets:
 * - Test execution: <100ms per test case
 * - Coverage analysis: <500ms total
 * - Stress testing: 1000+ concurrent modules
 * - Security validation: <200μs per module
 */

#ifndef TESTING_FRAMEWORK_H
#define TESTING_FRAMEWORK_H

#include <stdint.h>
#include <stdbool.h>
#include <sys/time.h>

// Test result status codes
typedef enum {
    TEST_STATUS_PENDING = 0,
    TEST_STATUS_RUNNING = 1,
    TEST_STATUS_PASSED = 2,
    TEST_STATUS_FAILED = 3,
    TEST_STATUS_SKIPPED = 4,
    TEST_STATUS_TIMEOUT = 5
} test_status_t;

// Test categories for comprehensive coverage
typedef enum {
    TEST_CATEGORY_UNIT = 0,
    TEST_CATEGORY_INTEGRATION = 1,
    TEST_CATEGORY_PERFORMANCE = 2,
    TEST_CATEGORY_SECURITY = 3,
    TEST_CATEGORY_STRESS = 4,
    TEST_CATEGORY_REGRESSION = 5,
    TEST_CATEGORY_COMPATIBILITY = 6,
    TEST_CATEGORY_END_TO_END = 7
} test_category_t;

// Performance metrics for test validation
typedef struct {
    uint64_t execution_time_ns;    // Test execution time in nanoseconds
    uint64_t memory_peak_bytes;    // Peak memory usage during test
    uint64_t memory_allocated;     // Total memory allocated
    uint64_t memory_freed;         // Total memory freed
    uint32_t cpu_utilization;      // CPU utilization percentage
    uint32_t cache_misses;         // L1/L2/L3 cache misses
    uint32_t branch_mispredicts;   // Branch misprediction count
    uint32_t page_faults;          // Memory page fault count
} test_performance_metrics_t;

// Code coverage tracking
typedef struct {
    uint32_t lines_total;          // Total lines of code
    uint32_t lines_covered;        // Lines covered by tests
    uint32_t branches_total;       // Total branches
    uint32_t branches_covered;     // Branches covered by tests
    uint32_t functions_total;      // Total functions
    uint32_t functions_covered;    // Functions covered by tests
    float coverage_percentage;     // Overall coverage percentage
} test_coverage_metrics_t;

// Security test results
typedef struct {
    bool buffer_overflow_safe;     // Buffer overflow protection
    bool memory_corruption_safe;   // Memory corruption protection
    bool privilege_escalation_safe; // Privilege escalation protection
    bool information_disclosure_safe; // Information disclosure protection
    bool denial_of_service_safe;   // DoS attack protection
    uint32_t vulnerabilities_found; // Number of vulnerabilities detected
    uint32_t security_score;       // Security score (0-100)
} test_security_metrics_t;

// Individual test case definition
typedef struct {
    char name[128];                // Test case name
    char description[256];         // Test case description
    test_category_t category;      // Test category
    test_status_t status;          // Current status
    
    // Function pointers for test execution
    bool (*setup_func)(void);      // Test setup function
    bool (*execute_func)(void);    // Test execution function
    void (*teardown_func)(void);   // Test cleanup function
    
    // Test configuration
    uint32_t timeout_ms;           // Test timeout in milliseconds
    uint32_t retry_count;          // Number of retries on failure
    bool is_critical;              // Critical test (must pass)
    
    // Test metrics
    test_performance_metrics_t performance;
    struct timeval start_time;
    struct timeval end_time;
    
    // Error information
    char error_message[512];       // Error message if failed
    uint32_t error_code;          // Error code
} test_case_t;

// Test suite definition
typedef struct {
    char name[128];                // Test suite name
    char description[256];         // Test suite description
    test_category_t category;      // Primary category
    
    test_case_t* test_cases;       // Array of test cases
    uint32_t test_count;          // Number of test cases
    uint32_t max_tests;           // Maximum test capacity
    
    // Suite-level metrics
    uint32_t passed_count;         // Number of passed tests
    uint32_t failed_count;         // Number of failed tests
    uint32_t skipped_count;        // Number of skipped tests
    
    // Coverage and performance
    test_coverage_metrics_t coverage;
    test_performance_metrics_t aggregate_performance;
    test_security_metrics_t security;
    
    // Timing
    struct timeval suite_start_time;
    struct timeval suite_end_time;
} test_suite_t;

// Test runner configuration
typedef struct {
    bool verbose_output;           // Verbose test output
    bool parallel_execution;       // Run tests in parallel
    uint32_t max_parallel_tests;   // Maximum parallel test count
    bool stop_on_first_failure;    // Stop on first failure
    bool generate_coverage_report; // Generate coverage report
    bool generate_performance_report; // Generate performance report
    bool generate_security_report; // Generate security report
    
    // Performance thresholds
    uint64_t max_execution_time_ns; // Maximum allowed execution time
    uint64_t max_memory_usage_bytes; // Maximum allowed memory usage
    float min_coverage_percentage;  // Minimum required coverage
    uint32_t min_security_score;   // Minimum required security score
    
    // Output configuration
    char report_directory[256];    // Directory for test reports
    char log_file[256];           // Log file path
    bool json_output;             // Generate JSON reports
    bool html_output;             // Generate HTML reports
} test_runner_config_t;

// Global test framework state
typedef struct {
    test_suite_t* suites;          // Array of test suites
    uint32_t suite_count;         // Number of test suites
    uint32_t max_suites;          // Maximum suite capacity
    
    test_runner_config_t config;   // Runner configuration
    
    // Global metrics
    uint32_t total_tests;          // Total number of tests
    uint32_t total_passed;         // Total passed tests
    uint32_t total_failed;         // Total failed tests
    uint32_t total_skipped;        // Total skipped tests
    
    test_coverage_metrics_t global_coverage;
    test_performance_metrics_t global_performance;
    test_security_metrics_t global_security;
    
    // Framework timing
    struct timeval framework_start_time;
    struct timeval framework_end_time;
    
    // Thread safety
    pthread_mutex_t framework_mutex;
    pthread_cond_t test_complete_cond;
} test_framework_t;

// Core API Functions
extern test_framework_t* test_framework_init(const test_runner_config_t* config);
extern void test_framework_destroy(test_framework_t* framework);

// Test suite management
extern test_suite_t* test_suite_create(const char* name, const char* description, test_category_t category);
extern bool test_suite_add_test(test_suite_t* suite, const test_case_t* test_case);
extern bool test_framework_add_suite(test_framework_t* framework, test_suite_t* suite);

// Test execution
extern bool test_framework_run_all(test_framework_t* framework);
extern bool test_framework_run_suite(test_framework_t* framework, const char* suite_name);
extern bool test_framework_run_category(test_framework_t* framework, test_category_t category);
extern bool test_case_execute(test_case_t* test_case);

// Coverage analysis
extern bool test_coverage_initialize(void);
extern bool test_coverage_start_tracking(void);
extern bool test_coverage_stop_tracking(void);
extern test_coverage_metrics_t test_coverage_get_metrics(void);
extern bool test_coverage_generate_report(const char* output_path);

// Performance monitoring
extern bool test_performance_start_monitoring(test_case_t* test_case);
extern bool test_performance_stop_monitoring(test_case_t* test_case);
extern test_performance_metrics_t test_performance_get_current_metrics(void);

// Security testing
extern bool test_security_initialize(void);
extern test_security_metrics_t test_security_run_vulnerability_scan(void);
extern bool test_security_validate_sandboxing(void);
extern bool test_security_test_privilege_escalation(void);
extern bool test_security_test_buffer_overflow_protection(void);

// Reporting and output
extern bool test_framework_generate_reports(test_framework_t* framework);
extern bool test_framework_generate_json_report(test_framework_t* framework, const char* output_path);
extern bool test_framework_generate_html_report(test_framework_t* framework, const char* output_path);
extern void test_framework_print_summary(test_framework_t* framework);

// Utility functions
extern double test_framework_get_execution_time_seconds(struct timeval start, struct timeval end);
extern const char* test_status_to_string(test_status_t status);
extern const char* test_category_to_string(test_category_t category);

// Test assertion macros
#define TEST_ASSERT(condition, message) \
    do { \
        if (!(condition)) { \
            snprintf(current_test->error_message, sizeof(current_test->error_message), \
                    "Assertion failed: %s at %s:%d", message, __FILE__, __LINE__); \
            return false; \
        } \
    } while(0)

#define TEST_ASSERT_EQ(expected, actual, message) \
    do { \
        if ((expected) != (actual)) { \
            snprintf(current_test->error_message, sizeof(current_test->error_message), \
                    "Assertion failed: %s - Expected: %ld, Actual: %ld at %s:%d", \
                    message, (long)(expected), (long)(actual), __FILE__, __LINE__); \
            return false; \
        } \
    } while(0)

#define TEST_ASSERT_LT(value, threshold, message) \
    do { \
        if ((value) >= (threshold)) { \
            snprintf(current_test->error_message, sizeof(current_test->error_message), \
                    "Assertion failed: %s - Value: %ld >= Threshold: %ld at %s:%d", \
                    message, (long)(value), (long)(threshold), __FILE__, __LINE__); \
            return false; \
        } \
    } while(0)

#define TEST_ASSERT_GT(value, threshold, message) \
    do { \
        if ((value) <= (threshold)) { \
            snprintf(current_test->error_message, sizeof(current_test->error_message), \
                    "Assertion failed: %s - Value: %ld <= Threshold: %ld at %s:%d", \
                    message, (long)(value), (long)(threshold), __FILE__, __LINE__); \
            return false; \
        } \
    } while(0)

#define TEST_ASSERT_NULL(pointer, message) \
    TEST_ASSERT((pointer) == NULL, message)

#define TEST_ASSERT_NOT_NULL(pointer, message) \
    TEST_ASSERT((pointer) != NULL, message)

// Performance assertion macros
#define TEST_ASSERT_PERFORMANCE_LT(metric, threshold, unit) \
    do { \
        if ((metric) >= (threshold)) { \
            snprintf(current_test->error_message, sizeof(current_test->error_message), \
                    "Performance assertion failed: %s %ld >= %ld %s at %s:%d", \
                    #metric, (long)(metric), (long)(threshold), unit, __FILE__, __LINE__); \
            return false; \
        } \
    } while(0)

// Thread-local storage for current test context
extern __thread test_case_t* current_test;

#endif // TESTING_FRAMEWORK_H