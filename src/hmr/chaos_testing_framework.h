/*
 * SimCity ARM64 - Comprehensive Hot-Reload Testing Framework
 * 
 * Advanced testing framework with chaos engineering, comprehensive
 * hot-reload testing, fault injection, stress testing, and automated
 * validation for production-ready hot-reload systems.
 * 
 * Features:
 * - Chaos engineering with fault injection
 * - Comprehensive hot-reload scenario testing
 * - Automated stress testing and load generation
 * - Real-time validation and monitoring
 * - Performance regression testing
 * - Reliability and resilience testing
 * 
 * Performance Targets:
 * - Test execution: <100ms per test case
 * - Chaos injection: <1ms fault injection latency
 * - Load generation: 10K+ operations/second
 * - Validation accuracy: >99.9% correctness detection
 * - Coverage: 100% code path coverage
 */

#ifndef CHAOS_TESTING_FRAMEWORK_H
#define CHAOS_TESTING_FRAMEWORK_H

#include <stdint.h>
#include <stdbool.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

// Forward declarations
typedef struct transaction_manager transaction_manager_t;
typedef struct conflict_resolution_engine conflict_resolution_engine_t;

// Test Case Types
typedef enum {
    TEST_TYPE_UNIT = 0,              // Unit tests for individual functions
    TEST_TYPE_INTEGRATION = 1,       // Integration tests for modules
    TEST_TYPE_STRESS = 2,            // Stress tests for performance
    TEST_TYPE_LOAD = 3,              // Load tests for scalability
    TEST_TYPE_CHAOS = 4,             // Chaos engineering tests
    TEST_TYPE_REGRESSION = 5,        // Regression tests for bugs
    TEST_TYPE_PERFORMANCE = 6,       // Performance benchmark tests
    TEST_TYPE_RELIABILITY = 7,       // Reliability and resilience tests
    TEST_TYPE_SECURITY = 8           // Security vulnerability tests
} test_type_t;

// Test Result Status
typedef enum {
    TEST_STATUS_PENDING = 0,         // Test not yet executed
    TEST_STATUS_RUNNING = 1,         // Test currently executing
    TEST_STATUS_PASSED = 2,          // Test passed successfully
    TEST_STATUS_FAILED = 3,          // Test failed
    TEST_STATUS_SKIPPED = 4,         // Test was skipped
    TEST_STATUS_TIMEOUT = 5,         // Test timed out
    TEST_STATUS_ERROR = 6            // Test execution error
} test_status_t;

// Chaos Engineering Fault Types
typedef enum {
    FAULT_TYPE_NONE = 0,
    FAULT_TYPE_MEMORY_CORRUPTION = 1,    // Memory corruption injection
    FAULT_TYPE_NETWORK_PARTITION = 2,    // Network partition simulation
    FAULT_TYPE_DISK_FAILURE = 3,         // Disk I/O failure
    FAULT_TYPE_CPU_SPIKE = 4,            // CPU spike simulation
    FAULT_TYPE_MEMORY_EXHAUSTION = 5,    // Memory exhaustion
    FAULT_TYPE_LATENCY_INJECTION = 6,    // Artificial latency
    FAULT_TYPE_CRASH_INJECTION = 7,      // Process crash simulation
    FAULT_TYPE_CORRUPTION_INJECTION = 8, // Data corruption
    FAULT_TYPE_DEADLOCK_INJECTION = 9,   // Deadlock simulation
    FAULT_TYPE_RACE_CONDITION = 10       // Race condition triggering
} fault_type_t;

// Test Severity Levels
typedef enum {
    TEST_SEVERITY_LOW = 0,       // Low impact tests
    TEST_SEVERITY_MEDIUM = 1,    // Medium impact tests
    TEST_SEVERITY_HIGH = 2,      // High impact tests
    TEST_SEVERITY_CRITICAL = 3   // Critical system tests
} test_severity_t;

// Load Generation Patterns
typedef enum {
    LOAD_PATTERN_CONSTANT = 0,   // Constant load
    LOAD_PATTERN_RAMP_UP = 1,    // Gradual increase
    LOAD_PATTERN_SPIKE = 2,      // Sudden spikes
    LOAD_PATTERN_SINE_WAVE = 3,  // Sine wave pattern
    LOAD_PATTERN_RANDOM = 4,     // Random variations
    LOAD_PATTERN_BURST = 5       // Burst patterns
} load_pattern_t;

// Test Metrics
typedef struct {
    uint64_t start_time;         // Test start timestamp
    uint64_t end_time;           // Test end timestamp
    uint64_t execution_time_us;  // Execution time in microseconds
    
    uint32_t assertions_total;   // Total assertions made
    uint32_t assertions_passed;  // Assertions that passed
    uint32_t assertions_failed;  // Assertions that failed
    
    uint64_t memory_used;        // Peak memory usage
    uint64_t cpu_time_us;        // CPU time consumed
    uint32_t system_calls;       // Number of system calls
    uint32_t context_switches;   // Context switches during test
    
    // Performance metrics
    uint32_t operations_per_sec; // Operations per second
    uint32_t latency_p50_us;     // 50th percentile latency
    uint32_t latency_p95_us;     // 95th percentile latency
    uint32_t latency_p99_us;     // 99th percentile latency
    
    // Error metrics
    uint32_t errors_detected;    // Errors detected during test
    uint32_t warnings_generated; // Warnings generated
    uint32_t crashes_simulated;  // Crashes simulated
    uint32_t recoveries_tested;  // Recovery scenarios tested
} test_metrics_t;

// Chaos Engineering Configuration
typedef struct {
    fault_type_t fault_type;     // Type of fault to inject
    float fault_probability;     // Probability of fault injection (0.0-1.0)
    uint32_t fault_duration_ms;  // Duration of fault in milliseconds
    uint32_t fault_frequency_ms; // Frequency of fault injection
    
    // Fault-specific parameters
    union {
        struct {
            void* memory_address;    // Address for memory corruption
            size_t corruption_size;  // Size of corruption
        } memory_fault;
        
        struct {
            uint32_t latency_ms;     // Artificial latency to inject
            float packet_loss_rate;  // Packet loss rate (0.0-1.0)
        } network_fault;
        
        struct {
            uint32_t cpu_usage_percent; // CPU usage percentage
            uint32_t duration_ms;        // Duration of CPU spike
        } cpu_fault;
        
        struct {
            size_t memory_to_consume; // Memory to artificially consume
        } memory_exhaustion;
    } fault_params;
    
    // Monitoring and recovery
    bool enable_monitoring;      // Enable fault monitoring
    bool enable_auto_recovery;   // Enable automatic recovery
    uint32_t recovery_timeout_ms; // Recovery timeout
    
    // Targeting
    uint32_t target_module_id;   // Target module for fault injection
    char target_function[128];   // Target function name
    uint8_t target_all_modules;  // Target all modules
    uint8_t reserved[3];
} chaos_config_t;

// Test Case Definition
typedef struct {
    uint64_t test_id;            // Unique test identifier
    char test_name[256];         // Human-readable test name
    char description[512];       // Test description
    
    test_type_t type;            // Type of test
    test_severity_t severity;    // Test severity level
    uint32_t timeout_ms;         // Test timeout in milliseconds
    
    // Test function pointer
    int (*test_function)(void* context);
    
    // Setup and teardown
    int (*setup_function)(void* context);
    int (*teardown_function)(void* context);
    
    // Validation function
    bool (*validation_function)(const test_metrics_t* metrics);
    
    // Test context data
    void* test_context;          // Test-specific context
    size_t context_size;         // Size of context data
    
    // Dependencies
    uint32_t dependency_count;   // Number of test dependencies
    uint64_t* dependencies;      // Array of test IDs this test depends on
    
    // Chaos engineering
    chaos_config_t chaos_config; // Chaos engineering configuration
    bool enable_chaos;           // Enable chaos engineering for this test
    
    // Performance expectations
    uint32_t expected_max_latency_us; // Expected maximum latency
    uint32_t expected_min_throughput; // Expected minimum throughput
    uint64_t expected_max_memory;     // Expected maximum memory usage
    
    // Retry configuration
    uint32_t max_retries;        // Maximum number of retries
    uint32_t retry_delay_ms;     // Delay between retries
    bool retry_on_failure;       // Retry on failure
    
    // Tags and metadata
    char tags[10][64];           // Test tags for categorization
    uint32_t tag_count;          // Number of tags
    uint64_t creation_time;      // When test was created
    uint64_t last_modified;      // Last modification time
} test_case_t;

// Test Suite Definition
typedef struct {
    uint64_t suite_id;           // Unique suite identifier
    char suite_name[256];        // Suite name
    char description[512];       // Suite description
    
    uint32_t test_count;         // Number of tests in suite
    uint32_t max_tests;          // Maximum number of tests
    test_case_t* tests;          // Array of test cases
    
    // Execution configuration
    bool parallel_execution;     // Execute tests in parallel
    uint32_t max_parallel_tests; // Maximum parallel tests
    uint32_t suite_timeout_ms;   // Overall suite timeout
    
    // Setup and teardown for entire suite
    int (*suite_setup)(void* context);
    int (*suite_teardown)(void* context);
    void* suite_context;        // Suite-wide context
    
    // Reporting configuration
    bool generate_detailed_report; // Generate detailed reports
    bool enable_real_time_monitoring; // Real-time monitoring
    char report_output_path[512]; // Report output path
    
    // Performance thresholds
    uint32_t max_suite_execution_time_ms; // Maximum suite execution time
    float min_pass_rate;         // Minimum pass rate (0.0-1.0)
    uint32_t max_memory_usage_mb; // Maximum memory usage
} test_suite_t;

// Test Execution Context
typedef struct {
    uint64_t execution_id;       // Unique execution identifier
    uint64_t start_time;         // Execution start time
    uint64_t end_time;           // Execution end time
    
    test_suite_t* suite;         // Test suite being executed
    test_case_t* current_test;   // Currently executing test
    
    // Execution state
    uint32_t tests_executed;     // Number of tests executed
    uint32_t tests_passed;       // Number of tests passed
    uint32_t tests_failed;       // Number of tests failed
    uint32_t tests_skipped;      // Number of tests skipped
    
    // Performance tracking
    test_metrics_t overall_metrics; // Overall execution metrics
    test_metrics_t* test_metrics;   // Metrics for each test
    
    // Chaos engineering state
    bool chaos_active;           // Is chaos engineering active
    chaos_config_t active_chaos; // Currently active chaos configuration
    uint32_t faults_injected;    // Number of faults injected
    uint32_t recoveries_performed; // Number of recoveries performed
    
    // Resource monitoring
    uint64_t peak_memory_usage;  // Peak memory usage during execution
    uint32_t peak_cpu_usage;     // Peak CPU usage percentage
    uint32_t max_open_files;     // Maximum open file descriptors
    
    // Real-time monitoring
    void (*progress_callback)(const test_case_t* test, const test_metrics_t* metrics);
    void (*error_callback)(const test_case_t* test, const char* error_message);
    void* callback_context;      // Context for callbacks
    
    // Thread pool for parallel execution
    void* thread_pool;           // Thread pool for parallel tests
    uint32_t active_threads;     // Currently active threads
    
    // Output and logging
    void* log_context;           // Logging context
    bool verbose_output;         // Enable verbose output
    bool generate_junit_xml;     // Generate JUnit XML output
} test_execution_context_t;

// Load Generator Configuration
typedef struct {
    load_pattern_t pattern;      // Load generation pattern
    uint32_t target_ops_per_sec; // Target operations per second
    uint32_t duration_seconds;   // Duration of load test
    uint32_t ramp_up_seconds;    // Ramp-up time
    uint32_t ramp_down_seconds;  // Ramp-down time
    
    // Operation types to generate
    uint32_t hot_reload_percentage;  // Percentage of hot-reload operations
    uint32_t conflict_percentage;    // Percentage of conflict scenarios
    uint32_t transaction_percentage; // Percentage of transaction operations
    
    // Data generation
    uint32_t min_module_size;    // Minimum module size
    uint32_t max_module_size;    // Maximum module size
    uint32_t dependency_depth;   // Maximum dependency depth
    float conflict_probability;  // Probability of conflicts
    
    // Monitoring
    uint32_t metrics_interval_ms; // Metrics collection interval
    bool enable_latency_tracking; // Track latency percentiles
    bool enable_throughput_tracking; // Track throughput
} load_generator_config_t;

// Test Framework Engine
typedef struct {
    uint64_t framework_id;       // Unique framework identifier
    uint64_t initialization_time; // Framework initialization time
    
    // Configuration
    uint32_t max_concurrent_suites; // Maximum concurrent test suites
    uint32_t max_test_duration_ms;  // Maximum test duration
    uint32_t default_timeout_ms;    // Default test timeout
    
    // Component integration
    transaction_manager_t* txn_manager; // Transaction manager to test
    conflict_resolution_engine_t* conflict_engine; // Conflict engine to test
    void* hmr_runtime;           // HMR runtime system to test
    
    // Test registry
    uint32_t registered_suites;  // Number of registered test suites
    uint32_t max_suites;         // Maximum number of suites
    test_suite_t* test_suites;   // Array of test suites
    
    // Execution tracking
    uint32_t active_executions;  // Currently active executions
    test_execution_context_t* executions; // Array of execution contexts
    
    // Chaos engineering
    bool chaos_enabled;          // Global chaos engineering enable
    chaos_config_t default_chaos; // Default chaos configuration
    uint32_t chaos_sessions_active; // Active chaos sessions
    
    // Load generation
    load_generator_config_t load_config; // Load generator configuration
    bool load_generation_active; // Is load generation active
    uint64_t operations_generated; // Total operations generated
    
    // Performance monitoring
    uint64_t total_tests_executed; // Total tests executed
    uint64_t total_execution_time_us; // Total execution time
    float average_pass_rate;     // Average pass rate
    uint32_t regression_count;   // Number of regressions detected
    
    // Resource management
    void* memory_pool;           // Memory pool for test framework
    size_t pool_size;            // Size of memory pool
    size_t pool_used;            // Currently used memory
    
    // Reporting and output
    char output_directory[512];  // Output directory for reports
    bool generate_html_reports;  // Generate HTML reports
    bool generate_csv_data;      // Generate CSV data files
    bool enable_real_time_dashboard; // Enable real-time dashboard
} test_framework_t;

// ============================================================================
// Core Test Framework API
// ============================================================================

/*
 * Initialize the testing framework
 * 
 * @param max_concurrent_suites Maximum concurrent test suites
 * @param memory_pool_size Memory pool size for testing
 * @param output_directory Directory for test outputs
 * @return Test framework instance or NULL on failure
 */
test_framework_t* test_framework_init(
    uint32_t max_concurrent_suites,
    size_t memory_pool_size,
    const char* output_directory
);

/*
 * Shutdown the testing framework
 * 
 * @param framework Test framework to shutdown
 * @return 0 on success, -1 on failure
 */
int test_framework_shutdown(test_framework_t* framework);

/*
 * Integrate systems to be tested
 * 
 * @param framework Test framework
 * @param txn_manager Transaction manager to test
 * @param conflict_engine Conflict resolution engine to test
 * @param hmr_runtime HMR runtime system to test
 * @return 0 on success, -1 on failure
 */
int test_framework_integrate_systems(
    test_framework_t* framework,
    transaction_manager_t* txn_manager,
    conflict_resolution_engine_t* conflict_engine,
    void* hmr_runtime
);

// ============================================================================
// Test Suite Management
// ============================================================================

/*
 * Create a new test suite
 * 
 * @param framework Test framework
 * @param suite_name Name of the test suite
 * @param description Description of the test suite
 * @return Test suite ID or 0 on failure
 */
uint64_t test_suite_create(
    test_framework_t* framework,
    const char* suite_name,
    const char* description
);

/*
 * Add a test case to a suite
 * 
 * @param framework Test framework
 * @param suite_id Test suite ID
 * @param test_case Test case to add
 * @return 0 on success, -1 on failure
 */
int test_suite_add_test(
    test_framework_t* framework,
    uint64_t suite_id,
    const test_case_t* test_case
);

/*
 * Execute a test suite
 * 
 * @param framework Test framework
 * @param suite_id Test suite ID to execute
 * @param parallel_execution Execute tests in parallel
 * @return Execution context or NULL on failure
 */
test_execution_context_t* test_suite_execute(
    test_framework_t* framework,
    uint64_t suite_id,
    bool parallel_execution
);

/*
 * Wait for test suite execution to complete
 * 
 * @param execution_context Execution context to wait for
 * @param timeout_ms Maximum time to wait in milliseconds
 * @return 0 on completion, -1 on timeout or error
 */
int test_suite_wait_completion(
    test_execution_context_t* execution_context,
    uint32_t timeout_ms
);

// ============================================================================
// Chaos Engineering
// ============================================================================

/*
 * Configure chaos engineering
 * 
 * @param framework Test framework
 * @param chaos_config Chaos engineering configuration
 * @return 0 on success, -1 on failure
 */
int test_chaos_configure(
    test_framework_t* framework,
    const chaos_config_t* chaos_config
);

/*
 * Start chaos engineering session
 * 
 * @param framework Test framework
 * @param duration_seconds Duration of chaos session
 * @return Chaos session ID or 0 on failure
 */
uint64_t test_chaos_start_session(
    test_framework_t* framework,
    uint32_t duration_seconds
);

/*
 * Inject specific fault
 * 
 * @param framework Test framework
 * @param fault_type Type of fault to inject
 * @param target_module Target module ID
 * @param duration_ms Duration of fault
 * @return 0 on success, -1 on failure
 */
int test_chaos_inject_fault(
    test_framework_t* framework,
    fault_type_t fault_type,
    uint32_t target_module,
    uint32_t duration_ms
);

/*
 * Stop chaos engineering session
 * 
 * @param framework Test framework
 * @param session_id Chaos session ID
 * @return 0 on success, -1 on failure
 */
int test_chaos_stop_session(
    test_framework_t* framework,
    uint64_t session_id
);

// ============================================================================
// Load Generation and Stress Testing
// ============================================================================

/*
 * Configure load generator
 * 
 * @param framework Test framework
 * @param load_config Load generation configuration
 * @return 0 on success, -1 on failure
 */
int test_load_configure(
    test_framework_t* framework,
    const load_generator_config_t* load_config
);

/*
 * Start load generation
 * 
 * @param framework Test framework
 * @param duration_seconds Duration of load test
 * @return Load session ID or 0 on failure
 */
uint64_t test_load_start_generation(
    test_framework_t* framework,
    uint32_t duration_seconds
);

/*
 * Generate specific load pattern
 * 
 * @param framework Test framework
 * @param pattern Load pattern to generate
 * @param intensity Load intensity (0.0-1.0)
 * @param duration_seconds Duration of load
 * @return 0 on success, -1 on failure
 */
int test_load_generate_pattern(
    test_framework_t* framework,
    load_pattern_t pattern,
    float intensity,
    uint32_t duration_seconds
);

/*
 * Stop load generation
 * 
 * @param framework Test framework
 * @param session_id Load session ID
 * @return 0 on success, -1 on failure
 */
int test_load_stop_generation(
    test_framework_t* framework,
    uint64_t session_id
);

// ============================================================================
// Built-in Test Cases
// ============================================================================

/*
 * Register built-in hot-reload test cases
 * 
 * @param framework Test framework
 * @return Number of test cases registered, -1 on failure
 */
int test_register_builtin_hotreload_tests(test_framework_t* framework);

/*
 * Register built-in transaction test cases
 * 
 * @param framework Test framework
 * @return Number of test cases registered, -1 on failure
 */
int test_register_builtin_transaction_tests(test_framework_t* framework);

/*
 * Register built-in conflict resolution test cases
 * 
 * @param framework Test framework
 * @return Number of test cases registered, -1 on failure
 */
int test_register_builtin_conflict_tests(test_framework_t* framework);

/*
 * Register built-in performance test cases
 * 
 * @param framework Test framework
 * @return Number of test cases registered, -1 on failure
 */
int test_register_builtin_performance_tests(test_framework_t* framework);

/*
 * Register built-in reliability test cases
 * 
 * @param framework Test framework
 * @return Number of test cases registered, -1 on failure
 */
int test_register_builtin_reliability_tests(test_framework_t* framework);

// ============================================================================
// Test Validation and Assertions
// ============================================================================

/*
 * Assert that a condition is true
 * 
 * @param condition Condition to check
 * @param message Error message if assertion fails
 * @return true if assertion passed, false if failed
 */
bool test_assert_true(bool condition, const char* message);

/*
 * Assert that two values are equal
 * 
 * @param expected Expected value
 * @param actual Actual value
 * @param message Error message if assertion fails
 * @return true if assertion passed, false if failed
 */
bool test_assert_equal(uint64_t expected, uint64_t actual, const char* message);

/*
 * Assert that a latency is within acceptable range
 * 
 * @param actual_latency_us Actual latency in microseconds
 * @param max_acceptable_us Maximum acceptable latency
 * @param message Error message if assertion fails
 * @return true if assertion passed, false if failed
 */
bool test_assert_latency(
    uint64_t actual_latency_us,
    uint64_t max_acceptable_us,
    const char* message
);

/*
 * Assert that throughput meets minimum requirements
 * 
 * @param actual_throughput Actual throughput (ops/sec)
 * @param min_required Minimum required throughput
 * @param message Error message if assertion fails
 * @return true if assertion passed, false if failed
 */
bool test_assert_throughput(
    uint32_t actual_throughput,
    uint32_t min_required,
    const char* message
);

// ============================================================================
// Performance Analysis and Reporting
// ============================================================================

/*
 * Generate comprehensive test report
 * 
 * @param framework Test framework
 * @param execution_context Execution context
 * @param output_path Path for report output
 * @return 0 on success, -1 on failure
 */
int test_generate_report(
    test_framework_t* framework,
    const test_execution_context_t* execution_context,
    const char* output_path
);

/*
 * Generate performance regression report
 * 
 * @param framework Test framework
 * @param baseline_metrics Baseline performance metrics
 * @param current_metrics Current performance metrics
 * @param output_path Path for report output
 * @return Number of regressions detected, -1 on failure
 */
int test_generate_regression_report(
    test_framework_t* framework,
    const test_metrics_t* baseline_metrics,
    const test_metrics_t* current_metrics,
    const char* output_path
);

/*
 * Analyze test execution patterns
 * 
 * @param framework Test framework
 * @param execution_history Array of execution contexts
 * @param history_count Number of execution contexts
 * @return Analysis result structure, NULL on failure
 */
void* test_analyze_execution_patterns(
    test_framework_t* framework,
    const test_execution_context_t* execution_history,
    uint32_t history_count
);

/*
 * Get framework performance statistics
 * 
 * @param framework Test framework
 * @return Performance statistics structure
 */
const void* test_get_framework_statistics(const test_framework_t* framework);

// ============================================================================
// Utility Functions
// ============================================================================

/*
 * Create a simple test case
 * 
 * @param test_name Name of the test
 * @param test_function Function to execute
 * @param timeout_ms Test timeout
 * @return Test case structure, NULL on failure
 */
test_case_t* test_create_simple_case(
    const char* test_name,
    int (*test_function)(void* context),
    uint32_t timeout_ms
);

/*
 * Validate test execution environment
 * 
 * @param framework Test framework
 * @return true if environment is valid, false otherwise
 */
bool test_validate_environment(test_framework_t* framework);

/*
 * Cleanup test execution resources
 * 
 * @param execution_context Execution context to cleanup
 * @return 0 on success, -1 on failure
 */
int test_cleanup_execution(test_execution_context_t* execution_context);

#ifdef __cplusplus
}
#endif

#endif // CHAOS_TESTING_FRAMEWORK_H