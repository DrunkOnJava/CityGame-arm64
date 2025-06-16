/*
 * SimCity ARM64 - Comprehensive Error Recovery System
 * 
 * Advanced error recovery system with automatic rollback, self-healing
 * capabilities, intelligent error classification, and comprehensive
 * recovery strategies for production runtime stability.
 * 
 * Features:
 * - Comprehensive error detection and classification
 * - Automatic rollback with intelligent recovery strategies
 * - Self-healing capabilities with adaptive algorithms
 * - Circuit breaker patterns for fault isolation
 * - Real-time error monitoring and alerting
 * - Performance: <2ms automatic rollback latency
 * 
 * Performance Targets:
 * - Error detection: <100μs for critical errors
 * - Automatic rollback: <2ms for transaction rollback
 * - Recovery initiation: <500μs from error detection
 * - Self-healing: <5ms for automatic remediation
 * - Error isolation: <1ms for circuit breaker activation
 */

#ifndef ERROR_RECOVERY_H
#define ERROR_RECOVERY_H

#include <stdint.h>
#include <stdbool.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

// Forward declarations
typedef struct transaction_manager transaction_manager_t;
typedef struct analytics_engine analytics_engine_t;

// Error Categories
typedef enum {
    ERROR_CATEGORY_NONE = 0,
    ERROR_CATEGORY_MEMORY = 1,           // Memory-related errors
    ERROR_CATEGORY_TRANSACTION = 2,      // Transaction errors
    ERROR_CATEGORY_CONFLICT = 3,         // Conflict resolution errors
    ERROR_CATEGORY_IO = 4,               // I/O operation errors
    ERROR_CATEGORY_NETWORK = 5,          // Network communication errors
    ERROR_CATEGORY_RESOURCE = 6,         // Resource exhaustion errors
    ERROR_CATEGORY_CORRUPTION = 7,       // Data corruption errors
    ERROR_CATEGORY_DEADLOCK = 8,         // Deadlock detection
    ERROR_CATEGORY_TIMEOUT = 9,          // Timeout errors
    ERROR_CATEGORY_PERMISSION = 10,      // Permission/security errors
    ERROR_CATEGORY_SYSTEM = 11,          // System-level errors
    ERROR_CATEGORY_APPLICATION = 12      // Application logic errors
} error_category_t;

// Error Severity Levels
typedef enum {
    ERROR_SEVERITY_INFO = 0,      // Informational (recoverable)
    ERROR_SEVERITY_WARNING = 1,   // Warning (attention needed)
    ERROR_SEVERITY_ERROR = 2,     // Error (requires recovery)
    ERROR_SEVERITY_CRITICAL = 3,  // Critical (system instability)
    ERROR_SEVERITY_FATAL = 4      // Fatal (system failure imminent)
} error_severity_t;

// Recovery Strategy Types
typedef enum {
    RECOVERY_STRATEGY_NONE = 0,
    RECOVERY_STRATEGY_RETRY = 1,         // Simple retry operation
    RECOVERY_STRATEGY_ROLLBACK = 2,      // Transaction rollback
    RECOVERY_STRATEGY_CIRCUIT_BREAKER = 3, // Circuit breaker activation
    RECOVERY_STRATEGY_GRACEFUL_DEGRADATION = 4, // Graceful service degradation
    RECOVERY_STRATEGY_RESTART_MODULE = 5, // Module restart
    RECOVERY_STRATEGY_RESTART_COMPONENT = 6, // Component restart
    RECOVERY_STRATEGY_FAILOVER = 7,      // Failover to backup
    RECOVERY_STRATEGY_SELF_HEAL = 8,     // Automatic self-healing
    RECOVERY_STRATEGY_MANUAL_INTERVENTION = 9, // Requires manual intervention
    RECOVERY_STRATEGY_SYSTEM_SHUTDOWN = 10 // Controlled system shutdown
} recovery_strategy_t;

// Error Context Information
typedef struct {
    uint64_t error_id;               // Unique error identifier
    uint64_t timestamp;              // When error occurred
    error_category_t category;       // Error category
    error_severity_t severity;       // Error severity
    
    // Error source information
    uint32_t module_id;              // Module where error occurred
    uint32_t thread_id;              // Thread ID
    uint32_t process_id;             // Process ID
    char function_name[128];         // Function where error occurred
    uint32_t line_number;            // Line number (if available)
    
    // Error details
    uint32_t error_code;             // Specific error code
    char error_message[512];         // Human-readable error message
    char technical_details[1024];    // Technical error details
    
    // Context at time of error
    uint64_t memory_usage;           // Memory usage when error occurred
    uint32_t cpu_usage_percent;      // CPU usage percentage
    uint32_t active_transactions;    // Number of active transactions
    uint32_t queue_depth;            // Operation queue depth
    
    // Stack trace information
    uint32_t stack_frame_count;      // Number of stack frames
    void* stack_frames[32];          // Stack frame addresses
    char stack_trace[2048];          // Human-readable stack trace
    
    // Related context
    uint64_t transaction_id;         // Associated transaction (if any)
    uint64_t operation_id;           // Associated operation (if any)
    uint32_t related_error_count;    // Number of related errors
    uint64_t* related_error_ids;     // Array of related error IDs
    
    // Recovery context
    recovery_strategy_t suggested_strategy; // Suggested recovery strategy
    bool auto_recoverable;           // Can be automatically recovered
    uint32_t max_retry_attempts;     // Maximum retry attempts
    uint32_t current_retry_attempt;  // Current retry attempt
    uint64_t last_recovery_attempt;  // Time of last recovery attempt
    
    // Impact assessment
    uint32_t affected_modules;       // Number of affected modules
    uint32_t affected_transactions;  // Number of affected transactions
    bool system_stability_impact;    // Does this impact system stability
    bool data_integrity_impact;      // Does this impact data integrity
} error_context_t;

// Recovery Action
typedef struct {
    uint64_t action_id;              // Unique action identifier
    uint64_t error_id;               // Associated error ID
    uint64_t start_time;             // Recovery action start time
    uint64_t end_time;               // Recovery action end time
    
    recovery_strategy_t strategy;    // Recovery strategy used
    uint32_t step_count;             // Number of recovery steps
    bool auto_executed;              // Was action automatically executed
    
    // Recovery steps
    struct {
        uint32_t step_id;            // Step identifier
        char step_description[256];   // Description of step
        uint64_t step_start_time;    // Step start time
        uint64_t step_end_time;      // Step end time
        bool step_success;           // Did step succeed
        char step_result[512];       // Step result details
    } steps[16];
    
    // Action results
    bool recovery_successful;        // Was recovery successful
    char recovery_result[512];       // Recovery result details
    uint32_t resources_recovered;    // Number of resources recovered
    uint32_t transactions_rolled_back; // Transactions rolled back
    
    // Performance impact
    uint64_t recovery_time_us;       // Total recovery time
    uint64_t downtime_us;           // Downtime during recovery
    uint32_t performance_impact_percent; // Performance impact percentage
    
    // Validation
    bool recovery_validated;         // Has recovery been validated
    uint64_t validation_time;        // When recovery was validated
    bool validation_successful;      // Was validation successful
} recovery_action_t;

// Circuit Breaker State
typedef struct {
    uint64_t breaker_id;             // Unique circuit breaker identifier
    char service_name[128];          // Name of protected service
    uint64_t creation_time;          // When breaker was created
    
    // State management
    enum {
        CIRCUIT_STATE_CLOSED = 0,    // Normal operation
        CIRCUIT_STATE_OPEN = 1,      // Circuit open (failing)
        CIRCUIT_STATE_HALF_OPEN = 2  // Testing recovery
    } state;
    
    // Configuration
    uint32_t failure_threshold;      // Failures before opening
    uint32_t timeout_ms;             // Timeout before half-open
    uint32_t success_threshold;      // Successes to close from half-open
    
    // Statistics
    uint32_t total_requests;         // Total requests processed
    uint32_t successful_requests;    // Successful requests
    uint32_t failed_requests;        // Failed requests
    uint32_t consecutive_failures;   // Consecutive failures
    uint32_t consecutive_successes;  // Consecutive successes in half-open
    
    // Timing
    uint64_t last_failure_time;      // Time of last failure
    uint64_t last_success_time;      // Time of last success
    uint64_t state_change_time;      // Time of last state change
    
    // Performance metrics
    uint64_t avg_response_time_us;   // Average response time
    uint64_t max_response_time_us;   // Maximum response time
    float failure_rate;              // Current failure rate
    
    // Callbacks
    void (*on_state_change)(uint64_t breaker_id, int old_state, int new_state);
    void (*on_failure)(uint64_t breaker_id, const error_context_t* error);
    void* callback_context;          // Context for callbacks
} circuit_breaker_t;

// Self-Healing Configuration
typedef struct {
    bool enable_self_healing;        // Enable self-healing capabilities
    uint32_t healing_interval_ms;    // Interval between healing attempts
    uint32_t max_healing_attempts;   // Maximum healing attempts per error
    
    // Healing strategies
    bool enable_memory_cleanup;      // Enable automatic memory cleanup
    bool enable_resource_recycling;  // Enable resource recycling
    bool enable_cache_refresh;       // Enable cache refresh
    bool enable_connection_reset;    // Enable connection reset
    bool enable_module_restart;      // Enable module restart
    
    // Thresholds
    uint32_t memory_threshold_percent; // Memory usage threshold for cleanup
    uint32_t cpu_threshold_percent;    // CPU usage threshold for intervention
    uint32_t error_rate_threshold;     // Error rate threshold for healing
    uint64_t response_time_threshold_us; // Response time threshold
    
    // Learning and adaptation
    bool enable_adaptive_healing;    // Enable adaptive healing strategies
    float healing_success_threshold; // Success threshold for strategy
    uint32_t strategy_evaluation_period; // Strategy evaluation period
} self_healing_config_t;

// Error Pattern
typedef struct {
    uint64_t pattern_id;             // Unique pattern identifier
    char pattern_name[128];          // Pattern name
    uint64_t first_occurrence;       // First time pattern was seen
    uint64_t last_occurrence;        // Last time pattern was seen
    uint32_t occurrence_count;       // Number of occurrences
    
    // Pattern characteristics
    error_category_t primary_category; // Primary error category
    error_severity_t severity_level;   // Typical severity level
    uint32_t typical_module_count;     // Typical number of affected modules
    
    // Pattern signature
    uint32_t signature_hash;         // Hash of error signature
    char signature_description[512]; // Human-readable signature
    
    // Recovery statistics
    recovery_strategy_t most_successful_strategy; // Most successful recovery
    float recovery_success_rate;     // Overall recovery success rate
    uint64_t avg_recovery_time_us;   // Average recovery time
    
    // Prediction data
    float prediction_confidence;     // Confidence in pattern recognition
    uint32_t prediction_window_ms;   // Time window for predictions
    bool is_preventable;            // Can this pattern be prevented
} error_pattern_t;

// Error Recovery Engine
typedef struct {
    uint64_t engine_id;              // Unique engine identifier
    uint64_t initialization_time;    // Engine initialization time
    
    // Configuration
    uint32_t max_concurrent_errors;  // Maximum concurrent errors to handle
    uint32_t error_history_size;     // Size of error history buffer
    uint32_t recovery_timeout_ms;    // Default recovery timeout
    
    // Component integration
    transaction_manager_t* txn_manager; // Transaction manager
    analytics_engine_t* analytics;   // Analytics engine
    void* hmr_runtime;               // HMR runtime system
    
    // Error tracking
    uint32_t active_error_count;     // Currently active errors
    uint32_t max_errors;             // Maximum errors to track
    error_context_t* active_errors;  // Array of active errors
    
    // Recovery tracking
    uint32_t active_recovery_count;  // Currently active recoveries
    recovery_action_t* active_recoveries; // Array of active recoveries
    
    // Circuit breakers
    uint32_t circuit_breaker_count;  // Number of circuit breakers
    uint32_t max_circuit_breakers;   // Maximum circuit breakers
    circuit_breaker_t* circuit_breakers; // Array of circuit breakers
    
    // Error patterns
    uint32_t error_pattern_count;    // Number of recognized patterns
    uint32_t max_error_patterns;     // Maximum patterns to track
    error_pattern_t* error_patterns; // Array of error patterns
    
    // Self-healing
    self_healing_config_t self_healing; // Self-healing configuration
    uint64_t last_healing_attempt;   // Time of last healing attempt
    uint32_t healing_attempts_count; // Number of healing attempts
    uint32_t successful_healings;    // Number of successful healings
    
    // Performance metrics
    uint64_t total_errors_handled;   // Total errors handled
    uint64_t total_recoveries_attempted; // Total recovery attempts
    uint64_t successful_recoveries;  // Successful recoveries
    uint64_t total_recovery_time_us; // Total time spent on recovery
    
    // Real-time monitoring
    bool enable_real_time_monitoring; // Enable real-time monitoring
    void (*error_callback)(const error_context_t* error);
    void (*recovery_callback)(const recovery_action_t* action);
    void* callback_context;          // Context for callbacks
    
    // Memory management
    void* memory_pool;               // Memory pool for error recovery
    size_t pool_size;                // Size of memory pool
    size_t pool_used;                // Currently used memory
    
    // Thread safety
    void* error_mutex;               // Mutex for error operations
    void* recovery_mutex;            // Mutex for recovery operations
    bool thread_safe_mode;           // Enable thread-safe operations
} error_recovery_engine_t;

// ============================================================================
// Core Error Recovery API
// ============================================================================

/*
 * Initialize error recovery engine
 * 
 * @param max_concurrent_errors Maximum concurrent errors to handle
 * @param memory_pool_size Memory pool size for error recovery
 * @param enable_self_healing Enable self-healing capabilities
 * @return Error recovery engine or NULL on failure
 */
error_recovery_engine_t* error_recovery_init_engine(
    uint32_t max_concurrent_errors,
    size_t memory_pool_size,
    bool enable_self_healing
);

/*
 * Shutdown error recovery engine
 * 
 * @param engine Error recovery engine to shutdown
 * @return 0 on success, -1 on failure
 */
int error_recovery_shutdown_engine(error_recovery_engine_t* engine);

/*
 * Integrate systems for error recovery
 * 
 * @param engine Error recovery engine
 * @param txn_manager Transaction manager
 * @param analytics Analytics engine
 * @param hmr_runtime HMR runtime system
 * @return 0 on success, -1 on failure
 */
int error_recovery_integrate_systems(
    error_recovery_engine_t* engine,
    transaction_manager_t* txn_manager,
    analytics_engine_t* analytics,
    void* hmr_runtime
);

// ============================================================================
// Error Detection and Reporting
// ============================================================================

/*
 * Report an error to the recovery engine
 * 
 * @param engine Error recovery engine
 * @param error_context Error context information
 * @return Error ID or 0 on failure
 */
uint64_t error_recovery_report_error(
    error_recovery_engine_t* engine,
    const error_context_t* error_context
);

/*
 * Classify error automatically
 * 
 * @param engine Error recovery engine
 * @param error_code Error code
 * @param error_message Error message
 * @param context_data Additional context data
 * @return Error context structure
 */
error_context_t error_recovery_classify_error(
    error_recovery_engine_t* engine,
    uint32_t error_code,
    const char* error_message,
    const void* context_data
);

/*
 * Get error severity assessment
 * 
 * @param engine Error recovery engine
 * @param error_id Error identifier
 * @return Error severity level
 */
error_severity_t error_recovery_assess_severity(
    error_recovery_engine_t* engine,
    uint64_t error_id
);

// ============================================================================
// Recovery Strategy Selection and Execution
// ============================================================================

/*
 * Select optimal recovery strategy for error
 * 
 * @param engine Error recovery engine
 * @param error_id Error identifier
 * @return Recommended recovery strategy
 */
recovery_strategy_t error_recovery_select_strategy(
    error_recovery_engine_t* engine,
    uint64_t error_id
);

/*
 * Execute recovery strategy
 * 
 * @param engine Error recovery engine
 * @param error_id Error identifier
 * @param strategy Recovery strategy to execute
 * @return Recovery action ID or 0 on failure
 */
uint64_t error_recovery_execute_strategy(
    error_recovery_engine_t* engine,
    uint64_t error_id,
    recovery_strategy_t strategy
);

/*
 * Perform automatic rollback
 * 
 * @param engine Error recovery engine
 * @param transaction_id Transaction to rollback
 * @param rollback_point Rollback point (checkpoint)
 * @return 0 on success, -1 on failure
 */
int error_recovery_automatic_rollback(
    error_recovery_engine_t* engine,
    uint64_t transaction_id,
    uint64_t rollback_point
);

/*
 * Wait for recovery completion
 * 
 * @param engine Error recovery engine
 * @param recovery_action_id Recovery action ID
 * @param timeout_ms Maximum time to wait
 * @return 0 on success, -1 on timeout or failure
 */
int error_recovery_wait_completion(
    error_recovery_engine_t* engine,
    uint64_t recovery_action_id,
    uint32_t timeout_ms
);

// ============================================================================
// Circuit Breaker Pattern
// ============================================================================

/*
 * Create circuit breaker for service protection
 * 
 * @param engine Error recovery engine
 * @param service_name Name of service to protect
 * @param failure_threshold Failures before opening circuit
 * @param timeout_ms Timeout before half-open state
 * @return Circuit breaker ID or 0 on failure
 */
uint64_t error_recovery_create_circuit_breaker(
    error_recovery_engine_t* engine,
    const char* service_name,
    uint32_t failure_threshold,
    uint32_t timeout_ms
);

/*
 * Check if circuit breaker allows operation
 * 
 * @param engine Error recovery engine
 * @param breaker_id Circuit breaker ID
 * @return true if operation allowed, false if blocked
 */
bool error_recovery_circuit_breaker_allow(
    error_recovery_engine_t* engine,
    uint64_t breaker_id
);

/*
 * Record operation result for circuit breaker
 * 
 * @param engine Error recovery engine
 * @param breaker_id Circuit breaker ID
 * @param success Was operation successful
 * @param response_time_us Operation response time
 * @return 0 on success, -1 on failure
 */
int error_recovery_circuit_breaker_record(
    error_recovery_engine_t* engine,
    uint64_t breaker_id,
    bool success,
    uint64_t response_time_us
);

/*
 * Get circuit breaker state
 * 
 * @param engine Error recovery engine
 * @param breaker_id Circuit breaker ID
 * @return Circuit breaker structure or NULL if not found
 */
const circuit_breaker_t* error_recovery_get_circuit_breaker(
    error_recovery_engine_t* engine,
    uint64_t breaker_id
);

// ============================================================================
// Self-Healing Capabilities
// ============================================================================

/*
 * Configure self-healing parameters
 * 
 * @param engine Error recovery engine
 * @param config Self-healing configuration
 * @return 0 on success, -1 on failure
 */
int error_recovery_configure_self_healing(
    error_recovery_engine_t* engine,
    const self_healing_config_t* config
);

/*
 * Trigger self-healing process
 * 
 * @param engine Error recovery engine
 * @param target_module Module to heal (0 for system-wide)
 * @param healing_strategies Bitfield of healing strategies to use
 * @return Number of healing actions performed, -1 on failure
 */
int error_recovery_trigger_self_healing(
    error_recovery_engine_t* engine,
    uint32_t target_module,
    uint32_t healing_strategies
);

/*
 * Get self-healing statistics
 * 
 * @param engine Error recovery engine
 * @param stats Output buffer for statistics
 * @return 0 on success, -1 on failure
 */
int error_recovery_get_self_healing_stats(
    error_recovery_engine_t* engine,
    void* stats
);

// ============================================================================
// Error Pattern Recognition
// ============================================================================

/*
 * Analyze error patterns
 * 
 * @param engine Error recovery engine
 * @param time_window_us Time window for pattern analysis
 * @return Number of patterns detected, -1 on failure
 */
int error_recovery_analyze_patterns(
    error_recovery_engine_t* engine,
    uint64_t time_window_us
);

/*
 * Get recognized error patterns
 * 
 * @param engine Error recovery engine
 * @param category Error category filter
 * @param max_patterns Maximum number of patterns to return
 * @return Array of error patterns, NULL on failure
 */
const error_pattern_t* error_recovery_get_patterns(
    error_recovery_engine_t* engine,
    error_category_t category,
    uint32_t max_patterns
);

/*
 * Predict potential errors based on patterns
 * 
 * @param engine Error recovery engine
 * @param prediction_window_us Time window for prediction
 * @param confidence_threshold Minimum confidence threshold
 * @return Number of predicted errors, -1 on failure
 */
int error_recovery_predict_errors(
    error_recovery_engine_t* engine,
    uint64_t prediction_window_us,
    float confidence_threshold
);

// ============================================================================
// Monitoring and Alerting
// ============================================================================

/*
 * Set error monitoring callbacks
 * 
 * @param engine Error recovery engine
 * @param error_callback Callback for error events
 * @param recovery_callback Callback for recovery events
 * @param context User context for callbacks
 * @return 0 on success, -1 on failure
 */
int error_recovery_set_monitoring_callbacks(
    error_recovery_engine_t* engine,
    void (*error_callback)(const error_context_t* error),
    void (*recovery_callback)(const recovery_action_t* action),
    void* context
);

/*
 * Generate error recovery report
 * 
 * @param engine Error recovery engine
 * @param start_time Start time for report
 * @param end_time End time for report
 * @param output_path Path for report output
 * @return 0 on success, -1 on failure
 */
int error_recovery_generate_report(
    error_recovery_engine_t* engine,
    uint64_t start_time,
    uint64_t end_time,
    const char* output_path
);

/*
 * Get recovery engine statistics
 * 
 * @param engine Error recovery engine
 * @return Statistics structure
 */
const void* error_recovery_get_statistics(const error_recovery_engine_t* engine);

// ============================================================================
// Utility Functions
// ============================================================================

/*
 * Create error context from exception
 * 
 * @param error_code Error code
 * @param message Error message
 * @param function_name Function where error occurred
 * @param line_number Line number
 * @return Error context structure
 */
error_context_t error_recovery_create_context(
    uint32_t error_code,
    const char* message,
    const char* function_name,
    uint32_t line_number
);

/*
 * Check system health status
 * 
 * @param engine Error recovery engine
 * @return Health score (0.0-1.0), -1.0 on error
 */
float error_recovery_check_system_health(error_recovery_engine_t* engine);

/*
 * Validate recovery engine integrity
 * 
 * @param engine Error recovery engine
 * @return true if valid, false if corrupted
 */
bool error_recovery_validate_integrity(const error_recovery_engine_t* engine);

#ifdef __cplusplus
}
#endif

#endif // ERROR_RECOVERY_H