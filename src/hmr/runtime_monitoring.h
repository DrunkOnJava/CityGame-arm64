/*
 * SimCity ARM64 - Advanced Runtime Monitoring and Predictive Analytics
 * Agent 3: Runtime Integration - Day 11 Implementation
 * 
 * Enterprise-grade runtime monitoring with predictive failure detection
 * Machine learning-based anomaly detection and intelligent alerting
 * Performance target: <100μs monitoring overhead per frame
 */

#ifndef HMR_RUNTIME_MONITORING_H
#define HMR_RUNTIME_MONITORING_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// =============================================================================
// Monitoring Constants and Limits
// =============================================================================

#define HMR_MON_MAX_METRICS           64          // Maximum tracked metrics
#define HMR_MON_HISTORY_BUFFER_SIZE   1024        // Historical data points
#define HMR_MON_ALERT_BUFFER_SIZE     256         // Alert queue size
#define HMR_MON_ANOMALY_WINDOW        100         // Anomaly detection window
#define HMR_MON_PREDICTION_HORIZON    300         // Predict 300 frames ahead (5s at 60fps)
#define HMR_MON_FEATURE_VECTOR_SIZE   16          // ML feature vector size
#define HMR_MON_MODEL_COEFFICIENTS    32          // Linear model coefficients

// Alert severity levels
typedef enum {
    HMR_ALERT_INFO        = 1,    // Informational
    HMR_ALERT_WARNING     = 2,    // Warning condition
    HMR_ALERT_ERROR       = 3,    // Error condition
    HMR_ALERT_CRITICAL    = 4,    // Critical system condition
    HMR_ALERT_EMERGENCY   = 5     // Emergency - immediate action required
} hmr_alert_severity_t;

// Metric types for different monitoring categories
typedef enum {
    HMR_METRIC_PERFORMANCE    = 0,    // Performance metrics (frame time, etc.)
    HMR_METRIC_MEMORY         = 1,    // Memory usage metrics
    HMR_METRIC_SECURITY       = 2,    // Security-related metrics
    HMR_METRIC_RESOURCE       = 3,    // Resource utilization
    HMR_METRIC_ERROR          = 4,    // Error and failure rates
    HMR_METRIC_USER_DEFINED   = 5     // Custom user-defined metrics
} hmr_metric_type_t;

// Anomaly detection algorithms
typedef enum {
    HMR_ANOMALY_STATISTICAL   = 0,    // Statistical outlier detection
    HMR_ANOMALY_MOVING_AVG    = 1,    // Moving average deviation
    HMR_ANOMALY_ZSCORE        = 2,    // Z-score based detection
    HMR_ANOMALY_IQR           = 3,    // Interquartile range method
    HMR_ANOMALY_ML_LINEAR     = 4,    // Linear regression based
    HMR_ANOMALY_ML_ENSEMBLE   = 5     // Ensemble method
} hmr_anomaly_algorithm_t;

// =============================================================================
// Error Codes
// =============================================================================

#define HMR_MON_SUCCESS                    0
#define HMR_MON_ERROR_NULL_POINTER        -1
#define HMR_MON_ERROR_INVALID_ARG         -2
#define HMR_MON_ERROR_NOT_FOUND           -3
#define HMR_MON_ERROR_BUFFER_FULL         -4
#define HMR_MON_ERROR_INSUFFICIENT_DATA   -5
#define HMR_MON_ERROR_MODEL_NOT_TRAINED   -6
#define HMR_MON_ERROR_PREDICTION_FAILED   -7

// =============================================================================
// Data Structures
// =============================================================================

// Individual metric sample
typedef struct {
    uint64_t timestamp;                 // When sample was taken
    double value;                       // Metric value
    uint32_t quality;                   // Data quality indicator (0-100)
    bool is_anomaly;                    // Whether flagged as anomaly
} hmr_metric_sample_t;

// Metric statistics
typedef struct {
    double mean;                        // Current mean value
    double variance;                    // Current variance
    double std_deviation;               // Standard deviation
    double min_value;                   // Minimum observed value
    double max_value;                   // Maximum observed value
    double median;                      // Current median
    double percentile_95;               // 95th percentile
    double percentile_99;               // 99th percentile
    uint32_t sample_count;              // Number of samples
    double trend_slope;                 // Trend analysis slope
    double seasonal_component;          // Seasonal pattern component
} hmr_metric_statistics_t;

// ML model for predictive analytics
typedef struct {
    double coefficients[HMR_MON_MODEL_COEFFICIENTS];    // Model coefficients
    double intercept;                                   // Model intercept
    double r_squared;                                   // Model fit quality
    double prediction_error;                            // Current prediction error
    uint32_t training_samples;                          // Number of training samples
    uint64_t last_training_time;                        // When model was last trained
    bool is_trained;                                    // Whether model is trained
} hmr_ml_model_t;

// Metric definition and tracking
typedef struct {
    uint32_t metric_id;                                 // Unique metric ID
    char name[64];                                      // Human-readable name
    char description[128];                              // Metric description
    hmr_metric_type_t type;                             // Metric category
    hmr_anomaly_algorithm_t anomaly_algorithm;          // Detection algorithm
    
    // Historical data
    hmr_metric_sample_t samples[HMR_MON_HISTORY_BUFFER_SIZE];
    uint32_t sample_head;                               // Current write position
    uint32_t sample_count;                              // Number of samples stored
    
    // Statistics
    hmr_metric_statistics_t stats;                      // Current statistics
    
    // Anomaly detection parameters
    double anomaly_threshold;                           // Anomaly detection threshold
    uint32_t anomaly_window_size;                       // Window size for detection
    uint32_t recent_anomalies;                          // Recent anomaly count
    
    // Predictive model
    hmr_ml_model_t prediction_model;                    // ML model for predictions
    double predicted_values[HMR_MON_PREDICTION_HORIZON]; // Future predictions
    double prediction_confidence[HMR_MON_PREDICTION_HORIZON]; // Confidence levels
    
    // Alerting
    bool alerting_enabled;                              // Whether to generate alerts
    hmr_alert_severity_t alert_threshold;               // Minimum alert severity
    uint32_t consecutive_violations;                    // Consecutive threshold violations
    uint64_t last_alert_time;                           // When last alert was sent
    uint32_t alert_cooldown_ms;                         // Minimum time between alerts
    
    // Performance tracking
    uint64_t total_update_time_ns;                      // Total time spent updating
    uint64_t total_predictions;                         // Number of predictions made
    uint64_t correct_predictions;                       // Number of correct predictions
} hmr_metric_t;

// Alert message
typedef struct {
    uint64_t timestamp;                                 // When alert was generated
    uint32_t metric_id;                                 // Which metric triggered alert
    hmr_alert_severity_t severity;                      // Alert severity level
    char message[256];                                  // Alert message
    double current_value;                               // Current metric value
    double threshold_value;                             // Threshold that was exceeded
    double predicted_value;                             // Predicted future value
    bool requires_immediate_action;                     // Whether immediate action needed
    uint32_t correlation_id;                            // For grouping related alerts
} hmr_alert_t;

// Monitoring system state
typedef struct {
    hmr_metric_t metrics[HMR_MON_MAX_METRICS];         // All tracked metrics
    uint32_t active_metrics;                           // Number of active metrics
    
    // Alert system
    hmr_alert_t alert_queue[HMR_MON_ALERT_BUFFER_SIZE]; // Alert queue
    uint32_t alert_queue_head;                         // Queue write position
    uint32_t alert_queue_count;                        // Number of queued alerts
    uint32_t total_alerts_generated;                   // Total alerts ever generated
    
    // Global monitoring state
    bool monitoring_enabled;                           // Master enable/disable
    uint64_t monitoring_start_time;                    // When monitoring started
    uint32_t frame_counter;                            // Current frame number
    uint64_t total_monitoring_time_ns;                 // Total monitoring overhead
    
    // Predictive analytics state
    bool predictive_enabled;                           // Whether prediction is enabled
    uint32_t prediction_accuracy_percent;              // Overall prediction accuracy
    uint64_t next_model_training_time;                 // When to retrain models
    uint32_t model_training_interval_frames;           // How often to retrain
    
    // Performance optimization
    uint64_t max_frame_budget_ns;                      // Maximum time budget per frame
    uint32_t adaptive_sampling_rate;                   // Dynamic sampling rate
    bool background_processing;                        // Use background thread for heavy work
} hmr_monitoring_system_t;

// =============================================================================
// Core Monitoring Functions
// =============================================================================

/**
 * Initialize the runtime monitoring system
 * Sets up metric tracking, predictive models, and alerting
 * 
 * @param enable_predictive Whether to enable predictive analytics
 * @param frame_budget_ns Maximum time budget per frame for monitoring
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_init(bool enable_predictive, uint64_t frame_budget_ns);

/**
 * Shutdown the monitoring system
 * Cleans up resources and saves final statistics
 * 
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_shutdown(void);

/**
 * Register a new metric for monitoring
 * 
 * @param metric_id Unique identifier for this metric
 * @param name Human-readable metric name
 * @param description Detailed metric description
 * @param type Metric category type
 * @param anomaly_algorithm Algorithm to use for anomaly detection
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_register_metric(uint32_t metric_id, const char* name, const char* description,
                           hmr_metric_type_t type, hmr_anomaly_algorithm_t anomaly_algorithm);

/**
 * Unregister a metric from monitoring
 * 
 * @param metric_id Metric to unregister
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_unregister_metric(uint32_t metric_id);

// =============================================================================
// Metric Data Collection
// =============================================================================

/**
 * Record a new metric sample
 * Updates statistics, checks for anomalies, and triggers predictions
 * 
 * @param metric_id Metric to update
 * @param value New metric value
 * @param quality Data quality indicator (0-100, 100 = highest quality)
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_record_sample(uint32_t metric_id, double value, uint32_t quality);

/**
 * Record multiple metric samples efficiently
 * Batch processing for better performance
 * 
 * @param samples Array of metric samples to record
 * @param sample_count Number of samples in array
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_record_samples_batch(const hmr_metric_sample_t* samples, uint32_t sample_count);

/**
 * Get current statistics for a metric
 * 
 * @param metric_id Metric to query
 * @param stats Output: current statistics
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_get_metric_stats(uint32_t metric_id, hmr_metric_statistics_t* stats);

/**
 * Get historical samples for a metric
 * 
 * @param metric_id Metric to query
 * @param samples Output buffer for samples
 * @param max_samples Maximum number of samples to return
 * @param actual_samples Output: actual number of samples returned
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_get_metric_history(uint32_t metric_id, hmr_metric_sample_t* samples,
                              uint32_t max_samples, uint32_t* actual_samples);

// =============================================================================
// Anomaly Detection
// =============================================================================

/**
 * Configure anomaly detection for a metric
 * 
 * @param metric_id Metric to configure
 * @param algorithm Anomaly detection algorithm to use
 * @param threshold Detection threshold (algorithm-specific)
 * @param window_size Window size for detection
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_configure_anomaly_detection(uint32_t metric_id, hmr_anomaly_algorithm_t algorithm,
                                       double threshold, uint32_t window_size);

/**
 * Manually trigger anomaly detection for a metric
 * 
 * @param metric_id Metric to analyze
 * @param anomaly_detected Output: whether anomaly was detected
 * @param anomaly_score Output: anomaly score (0.0-1.0)
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_detect_anomalies(uint32_t metric_id, bool* anomaly_detected, double* anomaly_score);

/**
 * Get recent anomalies for a metric
 * 
 * @param metric_id Metric to query
 * @param lookback_samples How many recent samples to consider
 * @return Number of anomalies detected in the lookback window
 */
uint32_t hmr_mon_get_recent_anomaly_count(uint32_t metric_id, uint32_t lookback_samples);

// =============================================================================
// Predictive Analytics
// =============================================================================

/**
 * Train predictive model for a metric
 * Uses historical data to build prediction capability
 * 
 * @param metric_id Metric to train model for
 * @param force_retrain Whether to force retraining even if model exists
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_train_predictive_model(uint32_t metric_id, bool force_retrain);

/**
 * Generate predictions for a metric
 * Predicts future values based on trained model
 * 
 * @param metric_id Metric to predict
 * @param prediction_steps Number of steps ahead to predict
 * @param predictions Output: array of predicted values
 * @param confidence_levels Output: confidence levels for predictions
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_predict_values(uint32_t metric_id, uint32_t prediction_steps,
                          double* predictions, double* confidence_levels);

/**
 * Evaluate prediction accuracy for a metric
 * Compares past predictions with actual values
 * 
 * @param metric_id Metric to evaluate
 * @param accuracy_percent Output: prediction accuracy percentage
 * @param mean_absolute_error Output: mean absolute prediction error
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_evaluate_prediction_accuracy(uint32_t metric_id, uint32_t* accuracy_percent,
                                        double* mean_absolute_error);

// =============================================================================
// Alert System
// =============================================================================

/**
 * Configure alerting for a metric
 * 
 * @param metric_id Metric to configure alerting for
 * @param enabled Whether alerting is enabled
 * @param severity_threshold Minimum severity to generate alerts
 * @param consecutive_violations Number of consecutive violations to trigger alert
 * @param cooldown_ms Minimum time between alerts in milliseconds
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_configure_alerting(uint32_t metric_id, bool enabled,
                              hmr_alert_severity_t severity_threshold,
                              uint32_t consecutive_violations, uint32_t cooldown_ms);

/**
 * Get pending alerts from the alert queue
 * 
 * @param alerts Output buffer for alerts
 * @param max_alerts Maximum number of alerts to return
 * @param actual_alerts Output: actual number of alerts returned
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_get_pending_alerts(hmr_alert_t* alerts, uint32_t max_alerts, uint32_t* actual_alerts);

/**
 * Clear all pending alerts
 * 
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_clear_alerts(void);

/**
 * Manually generate an alert
 * 
 * @param metric_id Metric that triggered the alert
 * @param severity Alert severity level
 * @param message Alert message
 * @param current_value Current metric value
 * @param threshold_value Threshold that was exceeded
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_generate_alert(uint32_t metric_id, hmr_alert_severity_t severity,
                          const char* message, double current_value, double threshold_value);

// =============================================================================
// Frame Integration Functions
// =============================================================================

/**
 * Perform per-frame monitoring tasks
 * Call once per frame to update monitoring, detect anomalies, and generate predictions
 * 
 * @param frame_number Current frame number
 * @param frame_budget_ns Time budget for monitoring tasks this frame
 * @return HMR_MON_SUCCESS on success, error code if budget exceeded
 */
int hmr_mon_frame_update(uint32_t frame_number, uint64_t frame_budget_ns);

/**
 * Perform background monitoring tasks
 * Heavy computational tasks that can be deferred to background processing
 * 
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_background_update(void);

// =============================================================================
// System Health and Performance
// =============================================================================

/**
 * Get overall monitoring system health
 * 
 * @param cpu_usage_percent Output: CPU usage by monitoring system
 * @param memory_usage_bytes Output: Memory usage by monitoring system
 * @param alert_queue_utilization Output: Alert queue utilization percentage
 * @param prediction_accuracy Output: Overall prediction accuracy
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_get_system_health(uint32_t* cpu_usage_percent, uint64_t* memory_usage_bytes,
                             uint32_t* alert_queue_utilization, uint32_t* prediction_accuracy);

/**
 * Optimize monitoring performance
 * Adjusts sampling rates and algorithms based on current system load
 * 
 * @param target_overhead_percent Target monitoring overhead as percentage of frame time
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_optimize_performance(uint32_t target_overhead_percent);

/**
 * Generate monitoring system report
 * 
 * @param report_buffer Buffer for the report
 * @param buffer_size Size of the report buffer
 * @return HMR_MON_SUCCESS on success, error code on failure
 */
int hmr_mon_generate_report(char* report_buffer, size_t buffer_size);

// =============================================================================
// Convenience Macros
// =============================================================================

/**
 * Record a metric sample with automatic timestamp and quality
 */
#define HMR_MON_RECORD(metric_id, value) \
    hmr_mon_record_sample(metric_id, value, 100)

/**
 * Record a metric sample with quality indicator
 */
#define HMR_MON_RECORD_QUALITY(metric_id, value, quality) \
    hmr_mon_record_sample(metric_id, value, quality)

/**
 * Generate an informational alert
 */
#define HMR_MON_ALERT_INFO(metric_id, message, value, threshold) \
    hmr_mon_generate_alert(metric_id, HMR_ALERT_INFO, message, value, threshold)

/**
 * Generate a critical alert
 */
#define HMR_MON_ALERT_CRITICAL(metric_id, message, value, threshold) \
    hmr_mon_generate_alert(metric_id, HMR_ALERT_CRITICAL, message, value, threshold)

#ifdef __cplusplus
}
#endif

#endif // HMR_RUNTIME_MONITORING_H