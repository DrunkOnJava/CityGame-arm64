/**
 * Enterprise Analytics Dashboard - Advanced Team Productivity & Security Monitoring
 * 
 * SimCity ARM64 - Agent 4: Developer Tools & Debug Interface
 * Week 3, Day 12: Enterprise Analytics Dashboard Implementation
 * 
 * Provides comprehensive analytics for enterprise development teams including:
 * - Team productivity metrics and performance tracking
 * - Advanced performance regression detection with ML algorithms
 * - Compliance monitoring with real-time audit trail visualization
 * - Security threat detection and incident response analytics
 * - Developer efficiency analysis and optimization recommendations
 * 
 * Performance Targets:
 * - Dashboard responsiveness: <5ms (120+ FPS UI updates)
 * - Real-time data processing: <15ms latency
 * - Memory usage: <50MB for full analytics dashboard
 * - Network efficiency: <300KB/min for real-time streaming
 * - Analytics computation: <100ms for complex queries
 */

#ifndef ENTERPRISE_ANALYTICS_H
#define ENTERPRISE_ANALYTICS_H

#include <stdint.h>
#include <stdbool.h>
#include <sys/time.h>
#include "runtime_security.h"
#include "runtime_monitoring.h"
#include "runtime_compliance.h"

#ifdef __cplusplus
extern "C" {
#endif

// =============================================================================
// ENTERPRISE ANALYTICS CONFIGURATION
// =============================================================================

#define MAX_DEVELOPERS              64      // Maximum team size
#define MAX_PROJECTS                32      // Maximum concurrent projects
#define MAX_MODULES_TRACKED         512     // Maximum modules per project
#define MAX_PRODUCTIVITY_METRICS    128     // Productivity KPIs tracked
#define MAX_REGRESSION_TESTS        256     // Performance regression tests
#define MAX_SECURITY_EVENTS         1024    // Security events buffer size
#define MAX_COMPLIANCE_CONTROLS     512     // Compliance controls monitored
#define MAX_ANALYTICS_HISTORY       8192    // Historical data points
#define MAX_ALERT_RULES             128     // Custom alert configurations
#define MAX_DASHBOARD_WIDGETS       64      // Maximum dashboard widgets

// Analytics processing performance targets
#define TARGET_DASHBOARD_LATENCY_US 5000    // 5ms dashboard update latency
#define TARGET_REALTIME_LATENCY_US  15000   // 15ms real-time data latency
#define TARGET_ANALYTICS_LATENCY_US 100000  // 100ms complex analytics
#define TARGET_MEMORY_LIMIT_MB      50      // 50MB total memory usage
#define TARGET_NETWORK_KB_MIN       300     // 300KB/min network usage

// =============================================================================
// TEAM PRODUCTIVITY ANALYTICS
// =============================================================================

typedef enum {
    PRODUCTIVITY_BUILD_SUCCESS_RATE,
    PRODUCTIVITY_BUILD_TIME_AVERAGE,
    PRODUCTIVITY_BUILD_TIME_P95,
    PRODUCTIVITY_BUILD_TIME_P99,
    PRODUCTIVITY_HOT_RELOAD_FREQUENCY,
    PRODUCTIVITY_HOT_RELOAD_SUCCESS_RATE,
    PRODUCTIVITY_DEBUG_SESSION_COUNT,
    PRODUCTIVITY_DEBUG_SESSION_DURATION,
    PRODUCTIVITY_CODE_COVERAGE_PERCENTAGE,
    PRODUCTIVITY_TEST_SUCCESS_RATE,
    PRODUCTIVITY_DEFECT_DENSITY,
    PRODUCTIVITY_CYCLOMATIC_COMPLEXITY,
    PRODUCTIVITY_TECHNICAL_DEBT_RATIO,
    PRODUCTIVITY_VELOCITY_STORY_POINTS,
    PRODUCTIVITY_LEAD_TIME_DAYS,
    PRODUCTIVITY_DEPLOYMENT_FREQUENCY,
    PRODUCTIVITY_MEAN_TIME_TO_RECOVERY,
    PRODUCTIVITY_CHANGE_FAILURE_RATE,
    PRODUCTIVITY_FEATURE_DELIVERY_TIME,
    PRODUCTIVITY_COLLABORATION_INDEX,
    PRODUCTIVITY_KNOWLEDGE_SHARING_SCORE,
    PRODUCTIVITY_CODE_REVIEW_EFFICIENCY,
    PRODUCTIVITY_CONTINUOUS_LEARNING_HOURS,
    PRODUCTIVITY_INNOVATION_TIME_PERCENTAGE,
    PRODUCTIVITY_FOCUS_TIME_HOURS,
    PRODUCTIVITY_CONTEXT_SWITCHING_COUNT,
    PRODUCTIVITY_TOOL_USAGE_EFFICIENCY,
    PRODUCTIVITY_AUTOMATION_COVERAGE,
    PRODUCTIVITY_PERFORMANCE_OPTIMIZATION_COUNT,
    PRODUCTIVITY_SECURITY_VULNERABILITY_FIXES,
    PRODUCTIVITY_DOCUMENTATION_COVERAGE,
    PRODUCTIVITY_API_DESIGN_QUALITY_SCORE
} productivity_metric_type_t;

typedef struct {
    productivity_metric_type_t type;
    uint64_t timestamp_us;
    double value;
    double target_value;
    double threshold_warning;
    double threshold_critical;
    uint32_t developer_id;
    uint32_t project_id;
    char description[256];
    bool is_trending_up;
    double trend_velocity;
    double confidence_interval;
} productivity_metric_t;

typedef struct {
    uint32_t developer_id;
    char name[128];
    char email[256];
    char role[64];
    char team[64];
    uint64_t active_since_us;
    uint64_t last_activity_us;
    
    // Productivity scores (0.0 - 1.0)
    double overall_productivity_score;
    double code_quality_score;
    double collaboration_score;
    double innovation_score;
    double efficiency_score;
    double learning_velocity_score;
    
    // Performance metrics
    uint32_t builds_per_day;
    uint32_t successful_builds_percentage;
    uint32_t hot_reloads_per_hour;
    uint32_t debug_sessions_per_day;
    double average_build_time_ms;
    double average_debug_time_ms;
    
    // Quality metrics
    uint32_t code_coverage_percentage;
    uint32_t test_success_rate;
    double defect_density;
    double technical_debt_hours;
    uint32_t security_issues_found;
    uint32_t performance_optimizations;
    
    // Collaboration metrics
    uint32_t code_reviews_given;
    uint32_t code_reviews_received;
    uint32_t knowledge_sharing_sessions;
    uint32_t pair_programming_hours;
    double communication_frequency;
    
    // Efficiency metrics
    double focus_time_percentage;
    uint32_t context_switches_per_day;
    double tool_mastery_score;
    uint32_t automation_scripts_created;
    double workflow_optimization_score;
    
    productivity_metric_t metrics[MAX_PRODUCTIVITY_METRICS];
    uint32_t metric_count;
} developer_profile_t;

typedef struct {
    uint32_t project_id;
    char name[128];
    char description[512];
    uint64_t created_timestamp_us;
    uint64_t last_updated_us;
    
    // Team composition
    uint32_t developer_ids[MAX_DEVELOPERS];
    uint32_t developer_count;
    
    // Project health metrics
    double overall_health_score;
    double velocity_trend;
    double quality_trend;
    double efficiency_trend;
    double risk_score;
    
    // Performance metrics
    uint32_t total_builds;
    uint32_t successful_builds;
    uint32_t failed_builds;
    double average_build_time_ms;
    double build_time_trend;
    
    // Quality metrics
    uint32_t total_tests;
    uint32_t passing_tests;
    double code_coverage_percentage;
    uint32_t open_defects;
    uint32_t resolved_defects;
    double defect_resolution_time_hours;
    
    // Deployment metrics
    uint32_t deployments_this_month;
    double deployment_success_rate;
    double mean_time_to_recovery_hours;
    double change_failure_rate;
    
    productivity_metric_t project_metrics[MAX_PRODUCTIVITY_METRICS];
    uint32_t project_metric_count;
} project_analytics_t;

// =============================================================================
// PERFORMANCE REGRESSION DETECTION
// =============================================================================

typedef enum {
    REGRESSION_TEST_BUILD_TIME,
    REGRESSION_TEST_STARTUP_TIME,
    REGRESSION_TEST_MEMORY_USAGE,
    REGRESSION_TEST_CPU_USAGE,  
    REGRESSION_TEST_FRAME_RATE,
    REGRESSION_TEST_RENDER_TIME,
    REGRESSION_TEST_LOAD_TIME,
    REGRESSION_TEST_RESPONSE_TIME,
    REGRESSION_TEST_THROUGHPUT,
    REGRESSION_TEST_LATENCY,
    REGRESSION_TEST_CACHE_HIT_RATE,
    REGRESSION_TEST_GARBAGE_COLLECTION,
    REGRESSION_TEST_THREAD_CONTENTION,
    REGRESSION_TEST_IO_WAIT_TIME,
    REGRESSION_TEST_NETWORK_LATENCY,
    REGRESSION_TEST_DATABASE_QUERY_TIME,
    REGRESSION_TEST_API_RESPONSE_TIME,
    REGRESSION_TEST_USER_INTERFACE_LAG,
    REGRESSION_TEST_BATTERY_USAGE,
    REGRESSION_TEST_HEAT_GENERATION,
    REGRESSION_TEST_SECURITY_SCAN_TIME,
    REGRESSION_TEST_COMPLIANCE_CHECK_TIME,
    REGRESSION_TEST_BACKUP_TIME,
    REGRESSION_TEST_RESTORE_TIME
} regression_test_type_t;

typedef enum {
    REGRESSION_SEVERITY_NONE,
    REGRESSION_SEVERITY_MINOR,      // 5-15% performance degradation
    REGRESSION_SEVERITY_MODERATE,   // 15-30% performance degradation  
    REGRESSION_SEVERITY_MAJOR,      // 30-50% performance degradation
    REGRESSION_SEVERITY_CRITICAL    // >50% performance degradation
} regression_severity_t;

typedef enum {
    REGRESSION_ALGORITHM_STATISTICAL,    // Statistical analysis (mean, std dev, percentiles)
    REGRESSION_ALGORITHM_MACHINE_LEARNING, // ML-based anomaly detection
    REGRESSION_ALGORITHM_TREND_ANALYSIS,   // Trend analysis and forecasting
    REGRESSION_ALGORITHM_CHANGE_POINT,     // Change point detection
    REGRESSION_ALGORITHM_ENSEMBLE          // Ensemble of multiple algorithms
} regression_algorithm_t;

typedef struct {
    regression_test_type_t test_type;
    uint64_t timestamp_us;
    double value;
    double baseline_value;
    double regression_percentage;
    regression_severity_t severity;
    char commit_hash[64];
    char branch_name[128];
    uint32_t build_number;
    char test_environment[64];
    char affected_components[512];
    char root_cause_analysis[1024];
    bool is_false_positive;
    bool is_resolved;
    uint64_t resolution_timestamp_us;
} regression_detection_t;

typedef struct {
    regression_test_type_t test_type;
    char test_name[128];
    char description[256];
    regression_algorithm_t algorithm;
    
    // Baseline and thresholds
    double baseline_value;
    double warning_threshold_percentage;    // % degradation for warning
    double critical_threshold_percentage;   // % degradation for critical alert
    uint32_t minimum_samples;              // Minimum samples for baseline
    uint32_t confidence_interval_percentage; // Statistical confidence level
    
    // Historical data for ML algorithms
    double historical_values[MAX_ANALYTICS_HISTORY];
    uint64_t historical_timestamps[MAX_ANALYTICS_HISTORY];
    uint32_t historical_count;
    
    // Machine learning model parameters
    double ml_model_weights[16];           // Neural network weights
    double ml_feature_means[8];            // Feature normalization means
    double ml_feature_stds[8];             // Feature normalization standard deviations
    double ml_anomaly_threshold;           // ML anomaly detection threshold
    double ml_model_accuracy;              // Model accuracy score
    
    // Statistical parameters
    double statistical_mean;
    double statistical_std_dev;
    double statistical_p95;
    double statistical_p99;
    
    regression_detection_t recent_regressions[32];
    uint32_t regression_count;
    
    bool is_enabled;
    uint64_t last_check_timestamp_us;
    uint32_t check_frequency_seconds;
} regression_test_config_t;

// =============================================================================
// COMPLIANCE MONITORING & AUDIT VISUALIZATION
// =============================================================================

typedef enum {
    COMPLIANCE_EVENT_ACCESS_CONTROL,
    COMPLIANCE_EVENT_DATA_ENCRYPTION,
    COMPLIANCE_EVENT_AUDIT_LOG,
    COMPLIANCE_EVENT_PRIVACY_PROTECTION,
    COMPLIANCE_EVENT_VULNERABILITY_SCAN,
    COMPLIANCE_EVENT_SECURITY_INCIDENT,
    COMPLIANCE_EVENT_BACKUP_VERIFICATION,
    COMPLIANCE_EVENT_DISASTER_RECOVERY,
    COMPLIANCE_EVENT_USER_TRAINING,
    COMPLIANCE_EVENT_POLICY_UPDATE,
    COMPLIANCE_EVENT_RISK_ASSESSMENT,
    COMPLIANCE_EVENT_THIRD_PARTY_AUDIT,
    COMPLIANCE_EVENT_PENETRATION_TEST,
    COMPLIANCE_EVENT_CERTIFICATION_RENEWAL,
    COMPLIANCE_EVENT_BREACH_NOTIFICATION,
    COMPLIANCE_EVENT_DATA_RETENTION,
    COMPLIANCE_EVENT_RIGHT_TO_ERASURE,
    COMPLIANCE_EVENT_CONSENT_MANAGEMENT,
    COMPLIANCE_EVENT_IMPACT_ASSESSMENT,
    COMPLIANCE_EVENT_VENDOR_ASSESSMENT
} compliance_event_type_t;

typedef struct {
    compliance_event_type_t event_type;
    uint64_t timestamp_us;
    compliance_standard_t standard;
    compliance_control_id_t control_id;
    compliance_status_t status;
    char description[512];
    char responsible_party[128];
    char evidence_location[256];
    double compliance_score;
    bool requires_remediation;
    uint64_t remediation_due_date_us;
    char remediation_plan[1024];
} compliance_audit_event_t;

typedef struct {
    compliance_standard_t standard;
    char standard_name[128];
    char version[64];
    uint64_t effective_date_us;
    
    // Compliance status overview
    uint32_t total_controls;
    uint32_t compliant_controls;
    uint32_t non_compliant_controls;
    uint32_t controls_in_remediation;
    double overall_compliance_percentage;
    
    // Risk assessment
    double risk_score;
    uint32_t high_risk_controls;
    uint32_t medium_risk_controls;
    uint32_t low_risk_controls;
    
    // Audit trail
    compliance_audit_event_t audit_events[MAX_COMPLIANCE_CONTROLS];
    uint32_t audit_event_count;
    
    // Remediation tracking
    uint32_t open_findings;
    uint32_t overdue_remediations;
    double average_remediation_time_days;
    
    // Certification status
    bool is_certified;
    uint64_t certification_date_us;
    uint64_t certification_expiry_us;
    char certification_body[128];
} compliance_dashboard_t;

// =============================================================================
// SECURITY THREAT DETECTION & INCIDENT ANALYTICS
// =============================================================================

typedef enum {
    THREAT_TYPE_MALWARE,
    THREAT_TYPE_PHISHING,
    THREAT_TYPE_BRUTE_FORCE,
    THREAT_TYPE_SQL_INJECTION,
    THREAT_TYPE_XSS,
    THREAT_TYPE_CSRF,
    THREAT_TYPE_DDoS,
    THREAT_TYPE_INSIDER_THREAT,
    THREAT_TYPE_DATA_EXFILTRATION,
    THREAT_TYPE_PRIVILEGE_ESCALATION,
    THREAT_TYPE_LATERAL_MOVEMENT,
    THREAT_TYPE_PERSISTENCE,
    THREAT_TYPE_COMMAND_CONTROL,
    THREAT_TYPE_VULNERABILITY_EXPLOIT,
    THREAT_TYPE_SOCIAL_ENGINEERING,
    THREAT_TYPE_PHYSICAL_SECURITY,
    THREAT_TYPE_SUPPLY_CHAIN,
    THREAT_TYPE_RANSOMWARE,
    THREAT_TYPE_CRYPTO_MINING,
    THREAT_TYPE_APT // Advanced Persistent Threat
} security_threat_type_t;

typedef enum {
    THREAT_SEVERITY_INFO,
    THREAT_SEVERITY_LOW,
    THREAT_SEVERITY_MEDIUM, 
    THREAT_SEVERITY_HIGH,
    THREAT_SEVERITY_CRITICAL
} security_threat_severity_t;

typedef enum {
    INCIDENT_STATUS_DETECTED,
    INCIDENT_STATUS_INVESTIGATING,
    INCIDENT_STATUS_CONTAINING,
    INCIDENT_STATUS_ERADICATING,
    INCIDENT_STATUS_RECOVERING,
    INCIDENT_STATUS_RESOLVED,
    INCIDENT_STATUS_CLOSED
} security_incident_status_t;

typedef struct {
    uint32_t threat_id;
    security_threat_type_t threat_type;
    security_threat_severity_t severity;
    uint64_t detected_timestamp_us;
    uint64_t resolved_timestamp_us;
    
    // Threat details
    char threat_name[128];
    char description[512];
    char source_ip[64];
    char target_ip[64];
    uint32_t affected_user_id;
    char affected_system[128];
    
    // Attack vector information
    char attack_vector[256];
    char indicators_of_compromise[1024];
    char tactics_techniques_procedures[512];
    
    // Impact assessment
    double business_impact_score;
    uint32_t affected_users_count;
    uint32_t affected_systems_count;
    double estimated_damage_cost;
    
    // Response metrics
    security_incident_status_t status;
    uint64_t time_to_detect_us;
    uint64_t time_to_respond_us;
    uint64_t time_to_contain_us;
    uint64_t time_to_resolve_us;
    
    // Investigation details
    char assigned_analyst[128];
    char investigation_notes[2048];
    char remediation_actions[1024];
    char lessons_learned[1024];
    
    bool is_false_positive;
    double confidence_score;
} security_threat_event_t;

typedef struct {
    // Threat landscape overview
    uint32_t total_threats_detected;
    uint32_t active_threats;
    uint32_t resolved_threats;
    uint32_t false_positives;
    double threat_detection_rate;
    
    // Severity distribution
    uint32_t critical_threats;
    uint32_t high_threats;
    uint32_t medium_threats;
    uint32_t low_threats;
    uint32_t info_threats;
    
    // Response performance
    double average_time_to_detect_minutes;
    double average_time_to_respond_minutes;
    double average_time_to_contain_hours;
    double average_time_to_resolve_hours;
    
    // Threat intelligence
    security_threat_event_t recent_threats[MAX_SECURITY_EVENTS];
    uint32_t threat_event_count;
    
    // Risk scoring
    double overall_security_posture_score;
    double threat_landscape_risk_score;
    double incident_response_readiness_score;
    
    // Trends and analytics
    double threat_trend_7_days;
    double threat_trend_30_days;
    double seasonal_threat_patterns[12]; // Monthly threat patterns
    
} security_analytics_dashboard_t;

// =============================================================================
// ENTERPRISE ANALYTICS CORE ENGINE
// =============================================================================

typedef struct {
    // System identification
    uint32_t analytics_engine_id;
    char deployment_environment[64];    // Development, Staging, Production
    uint64_t startup_timestamp_us;
    uint64_t last_update_timestamp_us;
    
    // Team and project management
    developer_profile_t developers[MAX_DEVELOPERS];
    uint32_t developer_count;
    project_analytics_t projects[MAX_PROJECTS];
    uint32_t project_count;
    
    // Performance regression system
    regression_test_config_t regression_tests[MAX_REGRESSION_TESTS];
    uint32_t regression_test_count;
    
    // Compliance monitoring
    compliance_dashboard_t compliance_dashboards[8]; // Major compliance standards
    uint32_t compliance_dashboard_count;
    
    // Security analytics
    security_analytics_dashboard_t security_dashboard;
    
    // Analytics performance metrics
    uint64_t dashboard_update_latency_us;
    uint64_t analytics_computation_latency_us;
    uint64_t realtime_data_latency_us;
    uint32_t memory_usage_mb;
    uint32_t network_usage_kb_per_minute;
    
    // Real-time processing state
    bool is_realtime_enabled;
    uint32_t update_frequency_hz;
    uint64_t last_performance_check_us;
    
    // Alert and notification system
    uint32_t active_alerts_count;
    uint32_t resolved_alerts_count;
    double alert_false_positive_rate;
    
    // Configuration
    bool enable_team_productivity_tracking;
    bool enable_regression_detection;
    bool enable_compliance_monitoring;
    bool enable_security_analytics;
    bool enable_predictive_analytics;
    bool enable_automated_remediation;
    
} enterprise_analytics_engine_t;

// =============================================================================
// ENTERPRISE ANALYTICS API
// =============================================================================

/**
 * Initialize the enterprise analytics engine
 * 
 * @param engine Pointer to analytics engine structure
 * @param deployment_env Deployment environment (dev/staging/prod)
 * @return true on success, false on failure
 */
bool enterprise_analytics_init(enterprise_analytics_engine_t* engine, 
                              const char* deployment_environment);

/**
 * Shutdown and cleanup the analytics engine
 * 
 * @param engine Pointer to analytics engine structure
 */
void enterprise_analytics_shutdown(enterprise_analytics_engine_t* engine);

/**
 * Update analytics data in real-time
 * Called at high frequency (60+ Hz) for real-time dashboard updates
 * 
 * @param engine Pointer to analytics engine structure
 * @return true on success, false on failure
 */
bool enterprise_analytics_update_realtime(enterprise_analytics_engine_t* engine);

/**
 * Process comprehensive analytics computation
 * Called less frequently for complex analytics (every 10-60 seconds)
 * 
 * @param engine Pointer to analytics engine structure
 * @return true on success, false on failure
 */
bool enterprise_analytics_process_comprehensive(enterprise_analytics_engine_t* engine);

// =============================================================================
// TEAM PRODUCTIVITY ANALYTICS API
// =============================================================================

/**
 * Register a new developer in the analytics system
 * 
 * @param engine Pointer to analytics engine structure
 * @param developer_id Unique developer identifier
 * @param name Developer full name
 * @param email Developer email address
 * @param role Developer role (e.g., "Senior Developer", "Team Lead")
 * @param team Team name
 * @return true on success, false on failure
 */
bool analytics_register_developer(enterprise_analytics_engine_t* engine,
                                 uint32_t developer_id,
                                 const char* name,
                                 const char* email, 
                                 const char* role,
                                 const char* team);

/**
 * Record a productivity metric for a developer
 * 
 * @param engine Pointer to analytics engine structure
 * @param developer_id Developer identifier
 * @param metric_type Type of productivity metric
 * @param value Metric value
 * @param target_value Target/expected value for this metric
 * @return true on success, false on failure
 */
bool analytics_record_productivity_metric(enterprise_analytics_engine_t* engine,
                                         uint32_t developer_id,
                                         productivity_metric_type_t metric_type,
                                         double value,
                                         double target_value);

/**
 * Calculate team productivity scores and trends
 * 
 * @param engine Pointer to analytics engine structure
 * @param team_name Team name to analyze (NULL for all teams)
 * @return Overall team productivity score (0.0 - 1.0)
 */
double analytics_calculate_team_productivity(enterprise_analytics_engine_t* engine,
                                           const char* team_name);

/**
 * Generate productivity optimization recommendations
 * 
 * @param engine Pointer to analytics engine structure
 * @param developer_id Developer to analyze (0 for team-wide recommendations)
 * @param recommendations Output buffer for recommendations
 * @param recommendations_size Size of recommendations buffer
 * @return Number of recommendations generated
 */
uint32_t analytics_generate_productivity_recommendations(enterprise_analytics_engine_t* engine,
                                                       uint32_t developer_id,
                                                       char* recommendations,
                                                       uint32_t recommendations_size);

// =============================================================================
// PERFORMANCE REGRESSION DETECTION API
// =============================================================================

/**
 * Configure a performance regression test
 * 
 * @param engine Pointer to analytics engine structure
 * @param test_type Type of regression test
 * @param test_name Human-readable test name
 * @param algorithm Algorithm to use for regression detection
 * @param warning_threshold Warning threshold percentage
 * @param critical_threshold Critical threshold percentage
 * @return true on success, false on failure
 */
bool analytics_configure_regression_test(enterprise_analytics_engine_t* engine,
                                        regression_test_type_t test_type,
                                        const char* test_name,
                                        regression_algorithm_t algorithm,
                                        double warning_threshold_percentage,
                                        double critical_threshold_percentage);

/**
 * Record a performance measurement for regression analysis
 * 
 * @param engine Pointer to analytics engine structure
 * @param test_type Type of performance test
 * @param value Measured performance value
 * @param commit_hash Git commit hash for the measurement
 * @param build_number Build number
 * @return true on success, false on failure
 */
bool analytics_record_performance_measurement(enterprise_analytics_engine_t* engine,
                                             regression_test_type_t test_type,
                                             double value,
                                             const char* commit_hash,
                                             uint32_t build_number);

/**
 * Run regression detection analysis
 * Uses configured algorithms to detect performance regressions
 * 
 * @param engine Pointer to analytics engine structure
 * @return Number of regressions detected
 */
uint32_t analytics_detect_performance_regressions(enterprise_analytics_engine_t* engine);

/**
 * Get latest regression detection results
 * 
 * @param engine Pointer to analytics engine structure
 * @param regressions Output buffer for regression results
 * @param max_regressions Maximum number of regressions to return
 * @return Number of regressions returned
 */
uint32_t analytics_get_regression_results(enterprise_analytics_engine_t* engine,
                                         regression_detection_t* regressions,
                                         uint32_t max_regressions);

// =============================================================================
// COMPLIANCE MONITORING API
// =============================================================================

/**
 * Initialize compliance monitoring for a specific standard
 * 
 * @param engine Pointer to analytics engine structure
 * @param standard Compliance standard to monitor
 * @param version Standard version
 * @return true on success, false on failure
 */
bool analytics_init_compliance_monitoring(enterprise_analytics_engine_t* engine,
                                         compliance_standard_t standard,
                                         const char* version);

/**
 * Record a compliance audit event
 * 
 * @param engine Pointer to analytics engine structure
 * @param standard Compliance standard
 * @param control_id Control identifier
 * @param status Compliance status
 * @param description Event description
 * @param evidence_location Location of compliance evidence
 * @return true on success, false on failure
 */
bool analytics_record_compliance_event(enterprise_analytics_engine_t* engine,
                                      compliance_standard_t standard,
                                      compliance_control_id_t control_id,
                                      compliance_status_t status,
                                      const char* description,
                                      const char* evidence_location);

/**
 * Calculate overall compliance score for a standard
 * 
 * @param engine Pointer to analytics engine structure
 * @param standard Compliance standard to evaluate
 * @return Compliance score (0.0 - 1.0)
 */
double analytics_calculate_compliance_score(enterprise_analytics_engine_t* engine,
                                           compliance_standard_t standard);

/**
 * Generate compliance dashboard data
 * 
 * @param engine Pointer to analytics engine structure
 * @param standard Compliance standard (or COMPLIANCE_STANDARD_ALL for all)
 * @param dashboard Output dashboard data
 * @return true on success, false on failure
 */
bool analytics_generate_compliance_dashboard(enterprise_analytics_engine_t* engine,
                                            compliance_standard_t standard,
                                            compliance_dashboard_t* dashboard);

// =============================================================================
// SECURITY ANALYTICS API
// =============================================================================

/**
 * Record a security threat event
 * 
 * @param engine Pointer to analytics engine structure
 * @param threat_type Type of security threat
 * @param severity Threat severity level
 * @param description Threat description
 * @param source_ip Source IP address (if applicable)
 * @param target_ip Target IP address (if applicable)
 * @return Unique threat ID, or 0 on failure
 */
uint32_t analytics_record_security_threat(enterprise_analytics_engine_t* engine,
                                         security_threat_type_t threat_type,
                                         security_threat_severity_t severity,
                                         const char* description,
                                         const char* source_ip,
                                         const char* target_ip);

/**
 * Update security incident status
 * 
 * @param engine Pointer to analytics engine structure
 * @param threat_id Threat identifier
 * @param status New incident status
 * @param notes Investigation notes
 * @param assigned_analyst Analyst handling the incident
 * @return true on success, false on failure
 */
bool analytics_update_security_incident(enterprise_analytics_engine_t* engine,
                                       uint32_t threat_id,
                                       security_incident_status_t status,
                                       const char* notes,
                                       const char* assigned_analyst);

/**
 * Calculate security posture score
 * 
 * @param engine Pointer to analytics engine structure
 * @return Security posture score (0.0 - 1.0)
 */
double analytics_calculate_security_posture(enterprise_analytics_engine_t* engine);

/**
 * Generate security analytics dashboard
 * 
 * @param engine Pointer to analytics engine structure
 * @param dashboard Output dashboard data
 * @return true on success, false on failure
 */
bool analytics_generate_security_dashboard(enterprise_analytics_engine_t* engine,
                                          security_analytics_dashboard_t* dashboard);

// =============================================================================
// DASHBOARD DATA EXPORT API
// =============================================================================

/**
 * Export analytics data as JSON for web dashboard
 * 
 * @param engine Pointer to analytics engine structure
 * @param json_buffer Output buffer for JSON data
 * @param buffer_size Size of JSON buffer
 * @return Number of bytes written to buffer, or 0 on failure
 */
uint32_t analytics_export_dashboard_json(enterprise_analytics_engine_t* engine,
                                        char* json_buffer,
                                        uint32_t buffer_size);

/**
 * Export specific analytics section as JSON
 * 
 * @param engine Pointer to analytics engine structure
 * @param section Section to export ("productivity", "regression", "compliance", "security")
 * @param json_buffer Output buffer for JSON data
 * @param buffer_size Size of JSON buffer
 * @return Number of bytes written to buffer, or 0 on failure
 */
uint32_t analytics_export_section_json(enterprise_analytics_engine_t* engine,
                                      const char* section,
                                      char* json_buffer,
                                      uint32_t buffer_size);

/**
 * Get analytics performance metrics
 * 
 * @param engine Pointer to analytics engine structure
 * @param dashboard_latency_us Output: dashboard update latency
 * @param analytics_latency_us Output: analytics computation latency
 * @param memory_usage_mb Output: memory usage in MB
 * @param network_usage_kb_min Output: network usage in KB/min
 * @return true on success, false on failure
 */
bool analytics_get_performance_metrics(enterprise_analytics_engine_t* engine,
                                      uint64_t* dashboard_latency_us,
                                      uint64_t* analytics_latency_us,
                                      uint32_t* memory_usage_mb,
                                      uint32_t* network_usage_kb_min);

#ifdef __cplusplus
}
#endif

#endif // ENTERPRISE_ANALYTICS_H