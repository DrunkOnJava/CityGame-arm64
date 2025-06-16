/*
 * SimCity ARM64 - Distributed Error Recovery System
 * Day 12: Advanced Error Handling & Recovery - HMR Orchestrator
 * 
 * Agent 0: HMR Orchestrator
 * Week 3 - Days 12-15: Final Production Optimization
 * 
 * Comprehensive error recovery system with:
 * - Distributed error handling across all 6 agent boundaries
 * - Predictive failure detection using machine learning
 * - Automatic system recovery with intelligent rollback strategies
 * - <50ms recovery time for critical failures
 * - Error analytics and prevention patterns
 */

#ifndef HMR_DISTRIBUTED_ERROR_RECOVERY_H
#define HMR_DISTRIBUTED_ERROR_RECOVERY_H

#include <stdint.h>
#include <stdbool.h>
#include <pthread.h>
#include <sys/time.h>

#ifdef __cplusplus
extern "C" {
#endif

// Error recovery performance targets
#define HMR_ERROR_RECOVERY_TARGET_LATENCY_US    50000   // <50ms recovery time
#define HMR_ERROR_PREDICTION_WINDOW_MS          5000    // 5-second prediction window
#define HMR_MAX_CONCURRENT_RECOVERIES          16      // Maximum parallel recoveries
#define HMR_ERROR_HISTORY_BUFFER_SIZE          4096    // Error pattern history
#define HMR_AGENT_BOUNDARY_COUNT               6       // All 6 HMR agents
#define HMR_ML_PATTERN_FEATURES                32      // ML feature vector size

// Agent types for error recovery coordination
typedef enum {
    HMR_AGENT_VERSIONING = 0,      // Agent 1: Module versioning
    HMR_AGENT_BUILD_PIPELINE = 1,  // Agent 2: Build optimization  
    HMR_AGENT_RUNTIME = 2,         // Agent 3: Runtime integration
    HMR_AGENT_DEVELOPER_TOOLS = 3, // Agent 4: Developer dashboard
    HMR_AGENT_SHADER_PIPELINE = 4, // Agent 5: Shader management
    HMR_AGENT_ORCHESTRATOR = 5,    // Agent 0: System orchestration
    HMR_AGENT_COUNT = 6
} hmr_agent_type_t;

// Error severity levels for system-wide classification
typedef enum {
    HMR_ERROR_SEVERITY_INFO = 0,        // Informational, no action needed
    HMR_ERROR_SEVERITY_WARNING,         // Warning, monitor closely
    HMR_ERROR_SEVERITY_ERROR,           // Error, requires attention
    HMR_ERROR_SEVERITY_CRITICAL,        // Critical, immediate action
    HMR_ERROR_SEVERITY_FATAL,           // Fatal, system recovery required
    HMR_ERROR_SEVERITY_COUNT
} hmr_error_severity_t;

// Error categories for intelligent classification
typedef enum {
    HMR_ERROR_CATEGORY_COMPILATION = 0, // Build/compilation errors
    HMR_ERROR_CATEGORY_RUNTIME,         // Runtime execution errors
    HMR_ERROR_CATEGORY_MEMORY,          // Memory allocation/access errors
    HMR_ERROR_CATEGORY_NETWORK,         // Network communication errors
    HMR_ERROR_CATEGORY_IO,              // File I/O and storage errors
    HMR_ERROR_CATEGORY_PERFORMANCE,     // Performance degradation
    HMR_ERROR_CATEGORY_SECURITY,        // Security violations
    HMR_ERROR_CATEGORY_RESOURCE,        // Resource exhaustion
    HMR_ERROR_CATEGORY_CONFIGURATION,   // Configuration errors
    HMR_ERROR_CATEGORY_UNKNOWN,         // Unclassified errors
    HMR_ERROR_CATEGORY_COUNT
} hmr_error_category_t;

// Recovery strategies with intelligent selection
typedef enum {
    HMR_RECOVERY_STRATEGY_NONE = 0,     // No recovery needed
    HMR_RECOVERY_STRATEGY_RETRY,        // Simple retry with backoff
    HMR_RECOVERY_STRATEGY_FALLBACK,     // Use fallback mechanism
    HMR_RECOVERY_STRATEGY_ROLLBACK,     // Rollback to previous state
    HMR_RECOVERY_STRATEGY_ISOLATE,      // Isolate failing component
    HMR_RECOVERY_STRATEGY_RESTART,      // Restart component/agent
    HMR_RECOVERY_STRATEGY_SCALE_DOWN,   // Reduce load/complexity
    HMR_RECOVERY_STRATEGY_GRACEFUL_DEGRADATION, // Degrade functionality
    HMR_RECOVERY_STRATEGY_ESCALATE,     // Escalate to human intervention
    HMR_RECOVERY_STRATEGY_COUNT
} hmr_recovery_strategy_t;

// Failure prediction using machine learning patterns
typedef struct {
    double features[HMR_ML_PATTERN_FEATURES];  // Feature vector for ML
    double prediction_confidence;               // Confidence score (0.0-1.0)
    uint64_t time_to_failure_us;               // Predicted time to failure
    hmr_error_category_t predicted_category;   // Predicted error category
    hmr_recovery_strategy_t recommended_strategy; // Recommended recovery
    bool prediction_valid;                     // Prediction validity flag
} hmr_failure_prediction_t;

// Error context with comprehensive information
typedef struct {
    char error_id[64];                         // Unique error identifier
    hmr_agent_type_t source_agent;             // Agent that detected error
    hmr_error_severity_t severity;             // Error severity level
    hmr_error_category_t category;             // Error category
    uint64_t timestamp_us;                     // Microsecond timestamp
    uint64_t thread_id;                        // Thread that detected error
    char file_path[512];                       // Source file path
    uint32_t line_number;                      // Line number in source
    char function_name[128];                   // Function name
    char error_message[1024];                  // Detailed error message
    char stack_trace[2048];                    // Stack trace if available
    uint64_t memory_usage_bytes;               // Memory usage at error
    double cpu_usage_percent;                  // CPU usage at error
    uint32_t error_code;                       // Numeric error code
    char context_data[512];                    // Additional context
    hmr_failure_prediction_t prediction;       // Failure prediction data
} hmr_error_context_t;

// Recovery action result with detailed metrics
typedef struct {
    char recovery_id[64];                      // Unique recovery identifier
    hmr_recovery_strategy_t strategy_used;     // Strategy that was executed
    uint64_t recovery_start_time_us;           // Recovery start timestamp
    uint64_t recovery_end_time_us;             // Recovery completion timestamp
    uint64_t recovery_duration_us;             // Total recovery time
    bool recovery_successful;                  // Success/failure flag
    uint32_t retry_count;                      // Number of retry attempts
    char recovery_details[512];                // Detailed recovery information
    double success_probability;                // Estimated success probability
    uint64_t resources_recovered;              // Resources freed/recovered
    char rollback_checkpoint[256];             // Rollback checkpoint ID
} hmr_recovery_result_t;

// Agent boundary health monitoring
typedef struct {
    hmr_agent_type_t agent_type;               // Agent type
    bool agent_healthy;                        // Health status
    uint64_t last_heartbeat_us;                // Last heartbeat timestamp
    uint32_t error_count_last_minute;          // Recent error count
    uint32_t warning_count_last_minute;        // Recent warning count
    double error_rate_per_second;              // Current error rate
    uint64_t cumulative_errors;                // Total errors since start
    uint64_t cumulative_recoveries;            // Total recoveries performed
    double average_recovery_time_us;           // Average recovery time
    double success_rate_percent;               // Recovery success rate
    hmr_error_category_t most_common_error;    // Most frequent error category
    uint64_t memory_usage_bytes;               // Current memory usage
    double cpu_usage_percent;                  // Current CPU usage
    char status_message[256];                  // Human-readable status
} hmr_agent_health_t;

// System-wide error recovery configuration
typedef struct {
    bool enable_predictive_failure_detection;  // Enable ML-based prediction
    bool enable_automatic_recovery;            // Enable auto-recovery
    bool enable_cross_agent_coordination;      // Enable agent coordination
    bool enable_error_analytics;               // Enable error pattern analysis
    bool enable_rollback_checkpoints;          // Enable state checkpointing
    uint32_t max_recovery_attempts;            // Maximum recovery attempts
    uint32_t recovery_timeout_ms;              // Recovery operation timeout
    uint32_t heartbeat_interval_ms;            // Agent heartbeat interval
    uint32_t prediction_update_interval_ms;    // Prediction update frequency
    double failure_prediction_threshold;       // Prediction confidence threshold
    uint32_t error_history_retention_hours;    // Error history retention
    char checkpoint_storage_path[512];         // Checkpoint storage location
    char error_log_path[512];                  // Error log file path
    char analytics_output_path[512];           // Analytics output path
} hmr_error_recovery_config_t;

// Error analytics and pattern recognition
typedef struct {
    uint64_t total_errors;                     // Total errors detected
    uint64_t total_recoveries;                 // Total recoveries attempted
    uint64_t successful_recoveries;            // Successful recoveries
    uint64_t failed_recoveries;                // Failed recoveries
    double overall_success_rate;               // Overall success rate
    double average_recovery_time_us;           // Average recovery time
    uint64_t error_count_by_category[HMR_ERROR_CATEGORY_COUNT];
    uint64_t error_count_by_severity[HMR_ERROR_SEVERITY_COUNT];
    uint64_t error_count_by_agent[HMR_AGENT_COUNT];
    uint64_t recovery_count_by_strategy[HMR_RECOVERY_STRATEGY_COUNT];
    char most_common_error_pattern[256];       // Most common error pattern
    char recovery_trend_analysis[512];         // Trend analysis summary
    uint64_t prediction_accuracy_count;        // Prediction accuracy tracking
    double prediction_accuracy_percent;        // Prediction accuracy rate
} hmr_error_analytics_t;

// Main distributed error recovery system
typedef struct {
    hmr_error_recovery_config_t config;        // System configuration
    hmr_agent_health_t agent_health[HMR_AGENT_COUNT]; // Agent health monitoring
    hmr_error_analytics_t analytics;           // Error analytics
    
    // Thread synchronization
    pthread_mutex_t system_mutex;              // System-wide mutex
    pthread_cond_t recovery_condition;         // Recovery coordination
    pthread_t monitoring_thread;               // Health monitoring thread
    pthread_t analytics_thread;                // Analytics processing thread
    pthread_t prediction_thread;               // Failure prediction thread
    bool system_running;                       // System running flag
    
    // Error tracking and recovery queues
    hmr_error_context_t error_history[HMR_ERROR_HISTORY_BUFFER_SIZE];
    hmr_recovery_result_t recovery_history[HMR_ERROR_HISTORY_BUFFER_SIZE];
    uint32_t error_history_index;              // Circular buffer index
    uint32_t recovery_history_index;           // Recovery history index
    uint32_t active_recoveries;                // Currently active recoveries
    
    // Machine learning for failure prediction
    double ml_weights[HMR_ML_PATTERN_FEATURES]; // ML model weights
    double ml_bias;                            // ML model bias
    uint64_t ml_training_samples;              // Training sample count
    double ml_accuracy;                        // Current model accuracy
    
    // Performance metrics
    uint64_t fastest_recovery_us;              // Fastest recovery time
    uint64_t slowest_recovery_us;              // Slowest recovery time
    uint64_t total_recovery_time_us;           // Cumulative recovery time
    double system_availability_percent;        // System availability
    uint64_t last_major_failure_us;            // Last major failure timestamp
} hmr_distributed_error_recovery_t;

// Global error recovery system instance
extern hmr_distributed_error_recovery_t g_hmr_error_recovery;

// ============================================================================
// Core API Functions
// ============================================================================

// Initialize the distributed error recovery system
int32_t hmr_error_recovery_init(const hmr_error_recovery_config_t* config);

// Report an error from any agent boundary
int32_t hmr_error_recovery_report_error(const hmr_error_context_t* error_context);

// Request recovery for a specific error
int32_t hmr_error_recovery_request_recovery(const char* error_id, 
                                          hmr_recovery_strategy_t strategy);

// Update agent health status
int32_t hmr_error_recovery_update_agent_health(hmr_agent_type_t agent, 
                                             const hmr_agent_health_t* health);

// Get system-wide error analytics
int32_t hmr_error_recovery_get_analytics(hmr_error_analytics_t* analytics);

// Get failure prediction for an agent
int32_t hmr_error_recovery_get_prediction(hmr_agent_type_t agent, 
                                        hmr_failure_prediction_t* prediction);

// Create recovery checkpoint
int32_t hmr_error_recovery_create_checkpoint(const char* checkpoint_id, 
                                           const void* state_data, 
                                           size_t state_size);

// Rollback to recovery checkpoint
int32_t hmr_error_recovery_rollback_to_checkpoint(const char* checkpoint_id);

// Shutdown the distributed error recovery system
int32_t hmr_error_recovery_shutdown(void);

// ============================================================================
// Advanced Features
// ============================================================================

// Register custom recovery strategy
int32_t hmr_error_recovery_register_custom_strategy(
    const char* strategy_name,
    int32_t (*recovery_function)(const hmr_error_context_t* error, 
                                hmr_recovery_result_t* result)
);

// Configure machine learning parameters
int32_t hmr_error_recovery_configure_ml(
    double learning_rate,
    double regularization_factor,
    uint32_t training_epochs
);

// Export error analytics report
int32_t hmr_error_recovery_export_analytics_report(const char* output_path, 
                                                  const char* format);

// Import error patterns for training
int32_t hmr_error_recovery_import_error_patterns(const char* patterns_file);

// Set recovery strategy selection callback
void hmr_error_recovery_set_strategy_selector(
    hmr_recovery_strategy_t (*selector)(const hmr_error_context_t* error,
                                       const hmr_failure_prediction_t* prediction)
);

// ============================================================================
// Monitoring and Diagnostics
// ============================================================================

// Get real-time system health summary
int32_t hmr_error_recovery_get_system_health(char* health_summary, 
                                            size_t summary_size);

// Get detailed error recovery metrics
int32_t hmr_error_recovery_get_detailed_metrics(char* metrics_json, 
                                               size_t json_size);

// Enable/disable specific recovery strategies
int32_t hmr_error_recovery_configure_strategies(
    uint32_t enabled_strategies_mask
);

// Set recovery performance targets
int32_t hmr_error_recovery_set_performance_targets(
    uint64_t max_recovery_time_us,
    double min_success_rate_percent,
    uint32_t max_concurrent_recoveries
);

// ============================================================================
// Callback Registration
// ============================================================================

// Recovery event callbacks
typedef struct {
    void (*on_error_detected)(const hmr_error_context_t* error);
    void (*on_prediction_generated)(const hmr_failure_prediction_t* prediction);
    void (*on_recovery_started)(const char* recovery_id, hmr_recovery_strategy_t strategy);
    void (*on_recovery_completed)(const hmr_recovery_result_t* result);
    void (*on_recovery_failed)(const char* recovery_id, const char* failure_reason);
    void (*on_system_health_changed)(hmr_agent_type_t agent, bool healthy);
    void (*on_critical_failure)(const hmr_error_context_t* error);
    void (*on_analytics_updated)(const hmr_error_analytics_t* analytics);
} hmr_error_recovery_callbacks_t;

// Register event callbacks
int32_t hmr_error_recovery_register_callbacks(const hmr_error_recovery_callbacks_t* callbacks);

// ============================================================================
// Utility Functions
// ============================================================================

// Convert error severity to string
const char* hmr_error_severity_to_string(hmr_error_severity_t severity);

// Convert error category to string
const char* hmr_error_category_to_string(hmr_error_category_t category);

// Convert recovery strategy to string
const char* hmr_recovery_strategy_to_string(hmr_recovery_strategy_t strategy);

// Convert agent type to string
const char* hmr_agent_type_to_string(hmr_agent_type_t agent);

// Calculate recovery time statistics
void hmr_error_recovery_calculate_time_stats(double* mean_us, double* stddev_us, 
                                            uint64_t* min_us, uint64_t* max_us);

#ifdef __cplusplus
}
#endif

#endif // HMR_DISTRIBUTED_ERROR_RECOVERY_H