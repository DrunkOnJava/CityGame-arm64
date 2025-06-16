/*
 * SimCity ARM64 - System Health Monitoring with ML Prediction
 * Day 12: Advanced Error Handling & Recovery - HMR Orchestrator
 * 
 * Agent 0: HMR Orchestrator
 * Week 3 - Days 12-15: Final Production Optimization
 * 
 * Comprehensive system health monitoring with:
 * - Real-time health metrics across all 6 agent boundaries
 * - Machine learning-based failure prediction
 * - Predictive analytics for system degradation
 * - Automated health checks and diagnostics
 * - Performance trending and capacity planning
 */

#ifndef HMR_SYSTEM_HEALTH_MONITORING_H
#define HMR_SYSTEM_HEALTH_MONITORING_H

#include <stdint.h>
#include <stdbool.h>
#include <pthread.h>
#include <sys/time.h>

#ifdef __cplusplus
extern "C" {
#endif

// Health monitoring performance targets
#define HMR_HEALTH_CHECK_INTERVAL_MS        1000    // 1-second health checks
#define HMR_HEALTH_PREDICTION_WINDOW_MS     30000   // 30-second prediction window
#define HMR_HEALTH_HISTORY_SAMPLES          1440    // 24 hours at 1-minute intervals
#define HMR_HEALTH_ML_FEATURES              64      // ML feature vector size
#define HMR_HEALTH_ALERT_THRESHOLD_COUNT    16      // Maximum concurrent alerts
#define HMR_HEALTH_METRIC_CATEGORIES        12      // Number of metric categories

// Agent types for health monitoring coordination
typedef enum {
    HMR_AGENT_VERSIONING = 0,      // Agent 1: Module versioning
    HMR_AGENT_BUILD_PIPELINE = 1,  // Agent 2: Build optimization  
    HMR_AGENT_RUNTIME = 2,         // Agent 3: Runtime integration
    HMR_AGENT_DEVELOPER_TOOLS = 3, // Agent 4: Developer dashboard
    HMR_AGENT_SHADER_PIPELINE = 4, // Agent 5: Shader management
    HMR_AGENT_ORCHESTRATOR = 5,    // Agent 0: System orchestration
    HMR_AGENT_COUNT = 6
} hmr_agent_type_t;

// Health status levels
typedef enum {
    HMR_HEALTH_STATUS_EXCELLENT = 0,    // >95% performance, no issues
    HMR_HEALTH_STATUS_GOOD,             // 85-95% performance, minor issues
    HMR_HEALTH_STATUS_FAIR,             // 70-85% performance, some concerns
    HMR_HEALTH_STATUS_POOR,             // 50-70% performance, significant issues
    HMR_HEALTH_STATUS_CRITICAL,         // <50% performance, critical issues
    HMR_HEALTH_STATUS_FAILED,           // System failure or unresponsive
    HMR_HEALTH_STATUS_COUNT
} hmr_health_status_t;

// Health metric categories for comprehensive monitoring
typedef enum {
    HMR_HEALTH_METRIC_CPU_USAGE = 0,    // CPU utilization percentage
    HMR_HEALTH_METRIC_MEMORY_USAGE,     // Memory utilization percentage
    HMR_HEALTH_METRIC_DISK_USAGE,       // Disk space utilization
    HMR_HEALTH_METRIC_NETWORK_LATENCY,  // Network latency metrics
    HMR_HEALTH_METRIC_ERROR_RATE,       // Error occurrence rate
    HMR_HEALTH_METRIC_RESPONSE_TIME,    // System response time
    HMR_HEALTH_METRIC_THROUGHPUT,       // Operations per second
    HMR_HEALTH_METRIC_AVAILABILITY,     // System availability percentage
    HMR_HEALTH_METRIC_TEMPERATURE,      // System temperature (thermal)
    HMR_HEALTH_METRIC_POWER_CONSUMPTION, // Power usage metrics
    HMR_HEALTH_METRIC_CACHE_HIT_RATE,   // Cache performance metrics
    HMR_HEALTH_METRIC_QUEUE_DEPTH,      // Queue depth and backlog
    HMR_HEALTH_METRIC_COUNT
} hmr_health_metric_category_t;

// Alert severity levels for health issues
typedef enum {
    HMR_HEALTH_ALERT_INFO = 0,          // Informational alert
    HMR_HEALTH_ALERT_WARNING,           // Warning condition
    HMR_HEALTH_ALERT_ERROR,             // Error condition
    HMR_HEALTH_ALERT_CRITICAL,          // Critical condition
    HMR_HEALTH_ALERT_EMERGENCY,         // Emergency condition
    HMR_HEALTH_ALERT_COUNT
} hmr_health_alert_severity_t;

// Health trend direction for predictive analysis
typedef enum {
    HMR_HEALTH_TREND_STABLE = 0,        // No significant change
    HMR_HEALTH_TREND_IMPROVING,         // Metrics improving
    HMR_HEALTH_TREND_DEGRADING,         // Metrics degrading
    HMR_HEALTH_TREND_VOLATILE,          // High variability
    HMR_HEALTH_TREND_UNKNOWN,           // Insufficient data
    HMR_HEALTH_TREND_COUNT
} hmr_health_trend_t;

// Individual health metric with statistical analysis
typedef struct {
    hmr_health_metric_category_t category;  // Metric category
    double current_value;                   // Current metric value
    double min_value;                       // Historical minimum
    double max_value;                       // Historical maximum
    double average_value;                   // Historical average
    double standard_deviation;              // Statistical variance
    double threshold_warning;               // Warning threshold
    double threshold_critical;              // Critical threshold
    double trend_slope;                     // Trend slope (change rate)
    hmr_health_trend_t trend_direction;     // Trend direction
    uint64_t last_updated_us;               // Last update timestamp
    uint32_t sample_count;                  // Number of samples collected
    bool threshold_exceeded;                // Current threshold status
    char metric_name[64];                   // Human-readable name
    char units[16];                         // Measurement units
} hmr_health_metric_t;

// Health alert with escalation management
typedef struct {
    char alert_id[64];                      // Unique alert identifier
    hmr_health_alert_severity_t severity;   // Alert severity level
    hmr_health_metric_category_t metric_category; // Related metric
    uint64_t alert_timestamp_us;            // Alert generation time
    uint64_t escalation_timestamp_us;       // Next escalation time
    uint32_t escalation_count;              // Number of escalations
    bool alert_active;                      // Alert active status
    bool requires_acknowledgment;           // Requires manual ack
    char alert_message[512];                // Detailed alert message
    char resolution_hint[256];              // Suggested resolution
    double trigger_value;                   // Value that triggered alert
    double threshold_value;                 // Threshold that was exceeded
} hmr_health_alert_t;

// Machine learning model for health prediction
typedef struct {
    double feature_weights[HMR_HEALTH_ML_FEATURES]; // ML model weights
    double bias;                            // ML model bias
    double learning_rate;                   // Learning rate for updates
    uint32_t training_samples;              // Number of training samples
    double prediction_accuracy;             // Current model accuracy
    uint64_t last_training_us;              // Last training timestamp
    bool model_trained;                     // Model training status
    char model_version[32];                 // Model version identifier
} hmr_health_ml_model_t;

// Health prediction result with confidence metrics
typedef struct {
    hmr_health_status_t predicted_status;   // Predicted health status
    double confidence_score;                // Prediction confidence (0-1)
    uint64_t prediction_window_us;          // Prediction time window
    hmr_health_metric_category_t critical_metric; // Most critical metric
    double failure_probability;             // Probability of failure
    uint64_t estimated_time_to_failure_us;  // Estimated time to failure
    char prediction_explanation[256];       // Human-readable explanation
    bool prediction_valid;                  // Prediction validity flag
    uint64_t prediction_timestamp_us;       // Prediction generation time
} hmr_health_prediction_t;

// Agent-specific health monitoring
typedef struct {
    hmr_agent_type_t agent_type;            // Agent type identifier
    hmr_health_status_t current_status;     // Current health status
    hmr_health_status_t predicted_status;   // Predicted health status
    hmr_health_metric_t metrics[HMR_HEALTH_METRIC_COUNT]; // Health metrics
    hmr_health_prediction_t prediction;     // Health prediction
    uint64_t last_heartbeat_us;             // Last heartbeat timestamp
    uint32_t consecutive_failures;          // Consecutive failure count
    uint32_t recovery_attempts;             // Recovery attempt count
    double uptime_percentage;               // Uptime percentage
    uint64_t total_downtime_us;             // Total downtime
    char status_message[256];               // Human-readable status
    bool monitoring_enabled;                // Monitoring enabled flag
} hmr_agent_health_monitoring_t;

// System-wide health monitoring configuration
typedef struct {
    bool enable_predictive_monitoring;      // Enable ML predictions
    bool enable_automated_alerts;           // Enable automatic alerts
    bool enable_trend_analysis;             // Enable trend analysis
    bool enable_capacity_planning;          // Enable capacity planning
    bool enable_performance_profiling;      // Enable performance profiling
    uint32_t health_check_interval_ms;      // Health check frequency
    uint32_t prediction_update_interval_ms; // Prediction update frequency
    uint32_t alert_escalation_interval_ms;  // Alert escalation interval
    uint32_t metric_retention_hours;        // Metric history retention
    double prediction_confidence_threshold; // Minimum prediction confidence
    uint32_t max_concurrent_alerts;         // Maximum concurrent alerts
    char health_log_path[512];              // Health log file path
    char metrics_export_path[512];          // Metrics export path
    char alert_notification_endpoint[256];  // Alert notification URL
} hmr_health_monitoring_config_t;

// Historical health data for trend analysis
typedef struct {
    uint64_t timestamp_us;                  // Sample timestamp
    hmr_health_status_t system_status;      // Overall system status
    double cpu_usage_percent;               // CPU usage at sample time
    double memory_usage_percent;            // Memory usage at sample time
    double error_rate_per_second;           // Error rate at sample time
    double response_time_ms;                // Response time at sample time
    uint32_t active_alerts;                 // Number of active alerts
    bool system_healthy;                    // Overall health flag
} hmr_health_history_sample_t;

// Main system health monitoring structure
typedef struct {
    hmr_health_monitoring_config_t config;  // System configuration
    hmr_agent_health_monitoring_t agents[HMR_AGENT_COUNT]; // Agent health
    hmr_health_alert_t active_alerts[HMR_HEALTH_ALERT_THRESHOLD_COUNT]; // Active alerts
    hmr_health_ml_model_t ml_model;         // ML prediction model
    hmr_health_history_sample_t history[HMR_HEALTH_HISTORY_SAMPLES]; // Historical data
    
    // Thread synchronization
    pthread_mutex_t monitoring_mutex;       // Monitoring system mutex
    pthread_cond_t alert_condition;         // Alert notification condition
    pthread_t monitoring_thread;            // Health monitoring thread
    pthread_t prediction_thread;            // Prediction analysis thread
    pthread_t alert_thread;                 // Alert management thread
    bool system_running;                    // System running status
    
    // Performance metrics
    uint64_t total_health_checks;           // Total health checks performed
    uint64_t total_predictions_generated;   // Total predictions generated
    uint64_t total_alerts_triggered;        // Total alerts triggered
    uint64_t fastest_health_check_us;       // Fastest health check time
    uint64_t slowest_health_check_us;       // Slowest health check time
    double average_health_check_time_us;    // Average health check time
    
    // System-wide health metrics
    hmr_health_status_t overall_system_status; // Overall system health
    double system_performance_score;        // Performance score (0-100)
    uint64_t system_uptime_us;              // Total system uptime
    uint64_t last_system_failure_us;        // Last system failure time
    uint32_t history_index;                 // Circular buffer index
    uint32_t active_alert_count;            // Number of active alerts
} hmr_system_health_monitoring_t;

// Global health monitoring system instance
extern hmr_system_health_monitoring_t g_hmr_health_monitoring;

// ============================================================================
// Core API Functions
// ============================================================================

// Initialize the system health monitoring
int32_t hmr_health_monitoring_init(const hmr_health_monitoring_config_t* config);

// Update health metrics for a specific agent
int32_t hmr_health_monitoring_update_agent_metrics(hmr_agent_type_t agent,
                                                   const hmr_health_metric_t* metrics,
                                                   uint32_t metric_count);

// Get current health status for an agent
int32_t hmr_health_monitoring_get_agent_status(hmr_agent_type_t agent,
                                              hmr_agent_health_monitoring_t* status);

// Get system-wide health status
int32_t hmr_health_monitoring_get_system_status(hmr_health_status_t* status,
                                               double* performance_score);

// Generate health prediction for an agent
int32_t hmr_health_monitoring_generate_prediction(hmr_agent_type_t agent,
                                                 hmr_health_prediction_t* prediction);

// Get active health alerts
int32_t hmr_health_monitoring_get_active_alerts(hmr_health_alert_t* alerts,
                                               uint32_t max_alerts,
                                               uint32_t* alert_count);

// Acknowledge a health alert
int32_t hmr_health_monitoring_acknowledge_alert(const char* alert_id);

// Export health metrics to file
int32_t hmr_health_monitoring_export_metrics(const char* output_path,
                                            const char* format);

// Shutdown the health monitoring system
int32_t hmr_health_monitoring_shutdown(void);

// ============================================================================
// Advanced Features
// ============================================================================

// Configure ML prediction model parameters
int32_t hmr_health_monitoring_configure_ml_model(double learning_rate,
                                                 double prediction_threshold,
                                                 uint32_t training_window);

// Train ML model with historical data
int32_t hmr_health_monitoring_train_ml_model(void);

// Set custom health thresholds for an agent
int32_t hmr_health_monitoring_set_agent_thresholds(hmr_agent_type_t agent,
                                                   hmr_health_metric_category_t metric,
                                                   double warning_threshold,
                                                   double critical_threshold);

// Register custom health metrics
int32_t hmr_health_monitoring_register_custom_metric(const char* metric_name,
                                                    const char* units,
                                                    double warning_threshold,
                                                    double critical_threshold);

// Generate capacity planning report
int32_t hmr_health_monitoring_generate_capacity_report(char* report_buffer,
                                                      size_t buffer_size);

// ============================================================================
// Callback Registration
// ============================================================================

// Health monitoring event callbacks
typedef struct {
    void (*on_health_status_changed)(hmr_agent_type_t agent, hmr_health_status_t old_status, hmr_health_status_t new_status);
    void (*on_alert_triggered)(const hmr_health_alert_t* alert);
    void (*on_alert_resolved)(const char* alert_id);
    void (*on_prediction_generated)(hmr_agent_type_t agent, const hmr_health_prediction_t* prediction);
    void (*on_threshold_exceeded)(hmr_agent_type_t agent, hmr_health_metric_category_t metric, double value, double threshold);
    void (*on_system_health_degraded)(hmr_health_status_t status, double performance_score);
    void (*on_capacity_warning)(hmr_health_metric_category_t metric, double usage_percent, uint64_t estimated_full_time_us);
} hmr_health_monitoring_callbacks_t;

// Register health monitoring callbacks
int32_t hmr_health_monitoring_register_callbacks(const hmr_health_monitoring_callbacks_t* callbacks);

// ============================================================================
// Monitoring and Diagnostics
// ============================================================================

// Get detailed health diagnostics
int32_t hmr_health_monitoring_get_diagnostics(char* diagnostics_buffer,
                                             size_t buffer_size);

// Get health trend analysis
int32_t hmr_health_monitoring_get_trend_analysis(hmr_agent_type_t agent,
                                                hmr_health_metric_category_t metric,
                                                hmr_health_trend_t* trend,
                                                double* trend_slope);

// Get performance bottleneck analysis
int32_t hmr_health_monitoring_get_bottleneck_analysis(char* analysis_buffer,
                                                     size_t buffer_size);

// Reset health statistics
int32_t hmr_health_monitoring_reset_statistics(void);

// ============================================================================
// Utility Functions
// ============================================================================

// Convert health status to string
const char* hmr_health_status_to_string(hmr_health_status_t status);

// Convert metric category to string
const char* hmr_health_metric_category_to_string(hmr_health_metric_category_t category);

// Convert alert severity to string
const char* hmr_health_alert_severity_to_string(hmr_health_alert_severity_t severity);

// Convert trend direction to string
const char* hmr_health_trend_to_string(hmr_health_trend_t trend);

// Calculate health score from metrics
double hmr_health_calculate_score(const hmr_health_metric_t* metrics, uint32_t metric_count);

// Validate health configuration
bool hmr_health_validate_config(const hmr_health_monitoring_config_t* config);

#ifdef __cplusplus
}
#endif

#endif // HMR_SYSTEM_HEALTH_MONITORING_H