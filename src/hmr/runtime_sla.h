/*
 * SimCity ARM64 - Runtime Performance SLA Enforcement
 * Agent 3: Runtime Integration - Day 11 Implementation
 * 
 * Service Level Agreement enforcement with performance guarantees
 * Automatic resource management and failover capabilities
 * Real-time SLA monitoring with contractual compliance tracking
 */

#ifndef HMR_RUNTIME_SLA_H
#define HMR_RUNTIME_SLA_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// =============================================================================
// SLA Constants and Limits
// =============================================================================

#define HMR_SLA_MAX_CONTRACTS         16          // Maximum SLA contracts
#define HMR_SLA_MAX_METRICS           32          // Maximum SLA metrics per contract
#define HMR_SLA_VIOLATION_HISTORY     1000        // SLA violation history size
#define HMR_SLA_REMEDIATION_ACTIONS   8           // Maximum remediation actions
#define HMR_SLA_MONITORING_WINDOW     3600        // 1 hour monitoring window (seconds)
#define HMR_SLA_AVAILABILITY_SAMPLES  1440        // 24 hours of minute samples

// SLA contract types
typedef enum {
    HMR_SLA_TYPE_PERFORMANCE      = 0,    // Performance-based SLA
    HMR_SLA_TYPE_AVAILABILITY     = 1,    // Availability-based SLA
    HMR_SLA_TYPE_THROUGHPUT       = 2,    // Throughput-based SLA
    HMR_SLA_TYPE_RESPONSE_TIME    = 3,    // Response time SLA
    HMR_SLA_TYPE_ERROR_RATE       = 4,    // Error rate SLA
    HMR_SLA_TYPE_RESOURCE_USAGE   = 5,    // Resource usage SLA
    HMR_SLA_TYPE_CUSTOM           = 6     // Custom SLA definition
} hmr_sla_type_t;

// SLA violation severity levels
typedef enum {
    HMR_SLA_VIOLATION_MINOR       = 1,    // Minor violation (warning)
    HMR_SLA_VIOLATION_MAJOR       = 2,    // Major violation (action required)
    HMR_SLA_VIOLATION_CRITICAL    = 3,    // Critical violation (immediate action)
    HMR_SLA_VIOLATION_BREACH      = 4     // SLA breach (contractual violation)
} hmr_sla_violation_severity_t;

// SLA enforcement actions
typedef enum {
    HMR_SLA_ACTION_NONE           = 0,    // No action
    HMR_SLA_ACTION_LOG            = 1,    // Log violation
    HMR_SLA_ACTION_ALERT          = 2,    // Send alert
    HMR_SLA_ACTION_THROTTLE       = 3,    // Throttle operations
    HMR_SLA_ACTION_SCALE_UP       = 4,    // Scale up resources
    HMR_SLA_ACTION_FAILOVER       = 5,    // Initiate failover
    HMR_SLA_ACTION_RESTART        = 6,    // Restart service
    HMR_SLA_ACTION_EMERGENCY_STOP = 7     // Emergency stop
} hmr_sla_action_t;

// SLA measurement periods
typedef enum {
    HMR_SLA_PERIOD_REALTIME       = 0,    // Real-time (per operation)
    HMR_SLA_PERIOD_SECOND         = 1,    // Per second
    HMR_SLA_PERIOD_MINUTE         = 2,    // Per minute
    HMR_SLA_PERIOD_5_MINUTES      = 3,    // Per 5 minutes
    HMR_SLA_PERIOD_15_MINUTES     = 4,    // Per 15 minutes
    HMR_SLA_PERIOD_HOUR           = 5,    // Per hour
    HMR_SLA_PERIOD_DAY            = 6     // Per day
} hmr_sla_period_t;

// =============================================================================
// Error Codes
// =============================================================================

#define HMR_SLA_SUCCESS                    0
#define HMR_SLA_ERROR_NULL_POINTER        -1
#define HMR_SLA_ERROR_INVALID_ARG         -2
#define HMR_SLA_ERROR_NOT_FOUND           -3
#define HMR_SLA_ERROR_CONTRACT_EXISTS     -4
#define HMR_SLA_ERROR_VIOLATION_BREACH    -5
#define HMR_SLA_ERROR_REMEDIATION_FAILED  -6
#define HMR_SLA_ERROR_RESOURCE_EXHAUSTED  -7

// =============================================================================
// SLA Data Structures
// =============================================================================

// SLA metric definition
typedef struct {
    uint32_t metric_id;                     // Unique metric identifier
    char name[64];                          // Metric name
    char description[128];                  // Metric description
    double target_value;                    // Target performance value
    double threshold_warning;               // Warning threshold
    double threshold_critical;              // Critical threshold
    double threshold_breach;                // Breach threshold
    hmr_sla_period_t measurement_period;    // Measurement period
    bool higher_is_better;                  // Whether higher values are better
    double weight;                          // Metric weight in overall SLA
    uint32_t grace_period_seconds;          // Grace period before violation
} hmr_sla_metric_t;

// SLA performance sample
typedef struct {
    uint64_t timestamp;                     // When sample was taken
    uint32_t metric_id;                     // Which metric
    double actual_value;                    // Actual measured value
    double target_value;                    // Target value at time of measurement
    bool meets_sla;                         // Whether sample meets SLA
    hmr_sla_violation_severity_t severity;  // Violation severity if any
} hmr_sla_sample_t;

// SLA violation record
typedef struct {
    uint64_t violation_id;                  // Unique violation ID
    uint64_t start_timestamp;               // When violation started
    uint64_t end_timestamp;                 // When violation ended (0 if ongoing)
    uint32_t contract_id;                   // Which SLA contract
    uint32_t metric_id;                     // Which metric violated
    hmr_sla_violation_severity_t severity;  // Violation severity
    double violation_magnitude;             // How much SLA was missed by
    uint32_t violation_duration_ms;         // Duration of violation
    hmr_sla_action_t remediation_action;    // Action taken to remediate
    bool remediation_successful;            // Whether remediation worked
    char description[256];                  // Human-readable description
} hmr_sla_violation_t;

// SLA remediation action
typedef struct {
    hmr_sla_action_t action_type;           // Type of remediation action
    char action_name[64];                   // Action name
    char action_description[128];           // Action description
    uint64_t execution_time_ns;             // Time to execute action
    bool requires_confirmation;             // Whether action needs confirmation
    uint32_t max_retries;                   // Maximum retry attempts
    uint32_t cooldown_seconds;              // Cooldown between actions
    void (*action_function)(uint32_t, void*); // Function to execute action
    void* action_context;                   // Context for action function
} hmr_sla_remediation_t;

// SLA contract definition
typedef struct {
    uint32_t contract_id;                   // Unique contract identifier
    char contract_name[64];                 // Contract name
    char description[256];                  // Contract description
    hmr_sla_type_t sla_type;                // Type of SLA
    
    // Metrics and targets
    hmr_sla_metric_t metrics[HMR_SLA_MAX_METRICS];
    uint32_t metric_count;                  // Number of metrics
    
    // Overall SLA targets
    double overall_availability_target;     // Overall availability target (%)
    double overall_performance_target;      // Overall performance target
    uint32_t max_violations_per_hour;       // Maximum violations per hour
    uint32_t max_violation_duration_ms;     // Maximum single violation duration
    
    // Measurement and reporting
    hmr_sla_period_t reporting_period;      // How often to calculate SLA
    uint64_t measurement_window_seconds;    // Measurement window size
    uint32_t required_samples;              // Minimum samples for valid measurement
    
    // Remediation
    hmr_sla_remediation_t remediation_actions[HMR_SLA_REMEDIATION_ACTIONS];
    uint32_t remediation_count;             // Number of remediation actions
    bool auto_remediation_enabled;          // Whether to auto-remediate
    uint32_t escalation_time_seconds;       // Time before escalation
    
    // Current state
    bool is_active;                         // Whether contract is active
    bool is_in_violation;                   // Whether currently in violation
    uint64_t last_measurement_time;         // Last measurement timestamp
    double current_sla_percentage;          // Current SLA achievement (%)
    uint32_t violations_this_period;        // Violations in current period
    uint64_t total_uptime_ms;               // Total uptime
    uint64_t total_downtime_ms;             // Total downtime
    
    // Performance tracking
    uint64_t measurements_taken;            // Total measurements
    uint64_t measurements_passed;           // Measurements that passed SLA
    uint64_t violations_total;              // Total violations ever
    uint64_t remediation_actions_taken;     // Total remediation actions
    uint64_t successful_remediations;       // Successful remediations
} hmr_sla_contract_t;

// SLA reporting data
typedef struct {
    uint32_t contract_id;                   // Contract this report is for
    uint64_t reporting_period_start;        // Start of reporting period
    uint64_t reporting_period_end;          // End of reporting period
    
    // Overall metrics
    double overall_availability;            // Overall availability (%)
    double overall_performance;             // Overall performance score
    uint32_t total_violations;              // Total violations in period
    uint32_t critical_violations;           // Critical violations in period
    uint64_t total_downtime_ms;             // Total downtime in period
    uint64_t mean_time_to_recovery_ms;      // MTTR in period
    
    // Per-metric breakdown
    double metric_achievements[HMR_SLA_MAX_METRICS]; // Achievement per metric (%)
    uint32_t metric_violations[HMR_SLA_MAX_METRICS]; // Violations per metric
    
    // Trends
    double availability_trend;              // Availability trend (improving/degrading)
    double performance_trend;               // Performance trend
    bool is_meeting_sla;                    // Whether SLA was met overall
    double sla_margin;                      // How much margin above/below SLA
} hmr_sla_report_t;

// Main SLA manager
typedef struct {
    hmr_sla_contract_t contracts[HMR_SLA_MAX_CONTRACTS];
    uint32_t active_contracts;              // Number of active contracts
    
    // Violation tracking
    hmr_sla_violation_t violation_history[HMR_SLA_VIOLATION_HISTORY];
    uint32_t violation_history_head;        // Circular buffer head
    uint32_t violation_history_count;       // Number of violations in history
    uint64_t next_violation_id;             // Next violation ID to assign
    
    // Sampling and measurement
    hmr_sla_sample_t* sample_buffer;        // Sample buffer
    uint32_t sample_buffer_size;            // Size of sample buffer
    uint32_t sample_buffer_head;            // Current sample position
    
    // System state
    bool sla_enforcement_enabled;           // Master enable/disable
    bool auto_remediation_enabled;          // Auto-remediation enable/disable
    bool real_time_monitoring;              // Real-time monitoring enabled
    uint64_t system_start_time;             // When SLA monitoring started
    uint64_t total_monitoring_time_ns;      // Total SLA monitoring overhead
    
    // Performance optimization
    uint64_t max_measurement_time_ns;       // Max time budget for SLA measurement
    uint32_t measurement_batch_size;        // Batch size for measurements
    bool background_reporting;              // Use background thread for reporting
    
    // Statistics
    uint64_t total_measurements;            // Total SLA measurements
    uint64_t total_violations;              // Total violations across all contracts
    uint64_t total_remediations;            // Total remediation actions
    uint64_t successful_remediations;       // Successful remediations
    double average_sla_achievement;         // Average SLA achievement across contracts
} hmr_sla_manager_t;

// =============================================================================
// Core SLA Functions
// =============================================================================

/**
 * Initialize the SLA enforcement system
 * 
 * @param enable_auto_remediation Whether to enable automatic remediation
 * @param max_measurement_time_ns Maximum time budget for SLA measurements
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_init(bool enable_auto_remediation, uint64_t max_measurement_time_ns);

/**
 * Shutdown the SLA enforcement system
 * Generates final reports and cleans up resources
 * 
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_shutdown(void);

/**
 * Create a new SLA contract
 * 
 * @param contract_id Unique identifier for the contract
 * @param contract_name Human-readable contract name
 * @param description Detailed contract description
 * @param sla_type Type of SLA contract
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_create_contract(uint32_t contract_id, const char* contract_name,
                           const char* description, hmr_sla_type_t sla_type);

/**
 * Delete an SLA contract
 * 
 * @param contract_id Contract to delete
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_delete_contract(uint32_t contract_id);

/**
 * Activate an SLA contract
 * 
 * @param contract_id Contract to activate
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_activate_contract(uint32_t contract_id);

/**
 * Deactivate an SLA contract
 * 
 * @param contract_id Contract to deactivate
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_deactivate_contract(uint32_t contract_id);

// =============================================================================
// SLA Metric Management
// =============================================================================

/**
 * Add a metric to an SLA contract
 * 
 * @param contract_id Contract to add metric to
 * @param metric_id Unique metric identifier
 * @param name Metric name
 * @param description Metric description
 * @param target_value Target performance value
 * @param threshold_warning Warning threshold
 * @param threshold_critical Critical threshold
 * @param threshold_breach Breach threshold
 * @param measurement_period How often to measure
 * @param higher_is_better Whether higher values are better
 * @param weight Metric weight in overall SLA
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_add_metric(uint32_t contract_id, uint32_t metric_id, const char* name,
                      const char* description, double target_value,
                      double threshold_warning, double threshold_critical,
                      double threshold_breach, hmr_sla_period_t measurement_period,
                      bool higher_is_better, double weight);

/**
 * Remove a metric from an SLA contract
 * 
 * @param contract_id Contract to remove metric from
 * @param metric_id Metric to remove
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_remove_metric(uint32_t contract_id, uint32_t metric_id);

/**
 * Update metric targets
 * 
 * @param contract_id Contract containing the metric
 * @param metric_id Metric to update
 * @param new_target_value New target value
 * @param new_thresholds Array of new thresholds [warning, critical, breach]
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_update_metric_targets(uint32_t contract_id, uint32_t metric_id,
                                 double new_target_value, const double* new_thresholds);

// =============================================================================
// SLA Measurement and Monitoring
// =============================================================================

/**
 * Record a performance measurement for SLA tracking
 * 
 * @param contract_id Contract to record measurement for
 * @param metric_id Metric being measured
 * @param actual_value Actual measured value
 * @param timestamp When measurement was taken (0 = current time)
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_record_measurement(uint32_t contract_id, uint32_t metric_id,
                              double actual_value, uint64_t timestamp);

/**
 * Perform SLA evaluation for a contract
 * Calculates current SLA achievement and detects violations
 * 
 * @param contract_id Contract to evaluate
 * @return HMR_SLA_SUCCESS if SLA is met, error code if violation detected
 */
int hmr_sla_evaluate_contract(uint32_t contract_id);

/**
 * Check if a contract is currently meeting its SLA
 * 
 * @param contract_id Contract to check
 * @param current_achievement Output: current SLA achievement percentage
 * @return true if meeting SLA, false if in violation
 */
bool hmr_sla_is_meeting_sla(uint32_t contract_id, double* current_achievement);

/**
 * Get current SLA status for all active contracts
 * 
 * @param statuses Output array for contract statuses
 * @param max_contracts Maximum number of contracts to return
 * @param actual_contracts Output: actual number of contracts returned
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_get_all_statuses(bool* statuses, uint32_t max_contracts, uint32_t* actual_contracts);

// =============================================================================
// SLA Violation Management
// =============================================================================

/**
 * Report an SLA violation
 * 
 * @param contract_id Contract that was violated
 * @param metric_id Metric that violated SLA
 * @param severity Violation severity
 * @param actual_value Actual measured value
 * @param target_value Target value that was missed
 * @param description Human-readable description
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_report_violation(uint32_t contract_id, uint32_t metric_id,
                            hmr_sla_violation_severity_t severity,
                            double actual_value, double target_value,
                            const char* description);

/**
 * Get recent violations for a contract
 * 
 * @param contract_id Contract to query
 * @param violations Output array for violations
 * @param max_violations Maximum number of violations to return
 * @param actual_violations Output: actual number of violations returned
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_get_recent_violations(uint32_t contract_id, hmr_sla_violation_t* violations,
                                 uint32_t max_violations, uint32_t* actual_violations);

/**
 * Clear violation history for a contract
 * 
 * @param contract_id Contract to clear violations for
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_clear_violations(uint32_t contract_id);

// =============================================================================
// SLA Remediation and Actions
// =============================================================================

/**
 * Add a remediation action to a contract
 * 
 * @param contract_id Contract to add action to
 * @param action_type Type of remediation action
 * @param action_name Action name
 * @param action_description Action description
 * @param action_function Function to execute the action
 * @param action_context Context for the action function
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_add_remediation_action(uint32_t contract_id, hmr_sla_action_t action_type,
                                  const char* action_name, const char* action_description,
                                  void (*action_function)(uint32_t, void*), void* action_context);

/**
 * Execute remediation actions for a violation
 * 
 * @param contract_id Contract with violation
 * @param violation_severity Severity of the violation
 * @param force_execution Whether to force execution even if cooldown active
 * @return HMR_SLA_SUCCESS if remediation succeeded, error code on failure
 */
int hmr_sla_execute_remediation(uint32_t contract_id, hmr_sla_violation_severity_t violation_severity,
                               bool force_execution);

/**
 * Enable or disable automatic remediation for a contract
 * 
 * @param contract_id Contract to configure
 * @param enabled Whether to enable auto-remediation
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_set_auto_remediation(uint32_t contract_id, bool enabled);

// =============================================================================
// SLA Reporting and Analytics
// =============================================================================

/**
 * Generate SLA report for a contract
 * 
 * @param contract_id Contract to generate report for
 * @param report_start_time Start of reporting period
 * @param report_end_time End of reporting period
 * @param report Output: generated SLA report
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_generate_report(uint32_t contract_id, uint64_t report_start_time,
                           uint64_t report_end_time, hmr_sla_report_t* report);

/**
 * Export SLA data to external format
 * 
 * @param contract_id Contract to export (0 = all contracts)
 * @param format Export format (JSON, CSV, etc.)
 * @param buffer Output buffer
 * @param buffer_size Size of output buffer
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_export_data(uint32_t contract_id, const char* format,
                       char* buffer, size_t buffer_size);

/**
 * Get SLA trends and predictions
 * 
 * @param contract_id Contract to analyze
 * @param prediction_horizon_hours How far ahead to predict
 * @param predicted_availability Output: predicted availability
 * @param predicted_violations Output: predicted number of violations
 * @param confidence_level Output: confidence in predictions (0.0-1.0)
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_get_predictions(uint32_t contract_id, uint32_t prediction_horizon_hours,
                           double* predicted_availability, uint32_t* predicted_violations,
                           double* confidence_level);

// =============================================================================
// Frame Integration and Performance
// =============================================================================

/**
 * Perform per-frame SLA monitoring tasks
 * Call once per frame to update SLA measurements and detect violations
 * 
 * @param frame_number Current frame number
 * @param frame_budget_ns Time budget for SLA monitoring this frame
 * @return HMR_SLA_SUCCESS on success, error code if budget exceeded
 */
int hmr_sla_frame_update(uint32_t frame_number, uint64_t frame_budget_ns);

/**
 * Get SLA monitoring performance metrics
 * 
 * @param monitoring_overhead_ns Output: time spent on SLA monitoring
 * @param measurement_rate Output: measurements per second
 * @param violation_detection_latency Output: time to detect violations
 * @return HMR_SLA_SUCCESS on success, error code on failure
 */
int hmr_sla_get_performance_metrics(uint64_t* monitoring_overhead_ns,
                                   uint32_t* measurement_rate,
                                   uint64_t* violation_detection_latency);

// =============================================================================
// Convenience Macros
// =============================================================================

/**
 * Quick SLA measurement recording
 */
#define HMR_SLA_RECORD(contract_id, metric_id, value) \
    hmr_sla_record_measurement(contract_id, metric_id, value, 0)

/**
 * Quick SLA status check
 */
#define HMR_SLA_CHECK(contract_id) \
    hmr_sla_is_meeting_sla(contract_id, NULL)

/**
 * Emergency SLA violation reporting
 */
#define HMR_SLA_EMERGENCY_VIOLATION(contract_id, metric_id, actual, target, desc) \
    hmr_sla_report_violation(contract_id, metric_id, HMR_SLA_VIOLATION_BREACH, actual, target, desc)

#ifdef __cplusplus
}
#endif

#endif // HMR_RUNTIME_SLA_H