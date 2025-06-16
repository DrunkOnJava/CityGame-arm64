/*
 * SimCity ARM64 - Runtime Compliance Framework
 * Agent 3: Runtime Integration - Day 11 Implementation
 * 
 * Enterprise compliance features for regulatory and audit requirements
 * SOX, GDPR, HIPAA, ISO 27001 compliance support with automated reporting
 * Immutable audit trails and real-time compliance monitoring
 */

#ifndef HMR_RUNTIME_COMPLIANCE_H
#define HMR_RUNTIME_COMPLIANCE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// =============================================================================
// Compliance Constants and Standards
// =============================================================================

#define HMR_COMPLIANCE_MAX_STANDARDS      16      // Maximum compliance standards
#define HMR_COMPLIANCE_MAX_CONTROLS       256     // Maximum compliance controls
#define HMR_COMPLIANCE_AUDIT_BUFFER_SIZE  8192    // Audit log buffer size
#define HMR_COMPLIANCE_EVIDENCE_SIZE      4096    // Evidence buffer size
#define HMR_COMPLIANCE_MAX_VIOLATIONS     1000    // Maximum violation records

// Compliance standards supported
typedef enum {
    HMR_COMPLIANCE_SOX             = 0x0001,   // Sarbanes-Oxley Act
    HMR_COMPLIANCE_GDPR            = 0x0002,   // General Data Protection Regulation
    HMR_COMPLIANCE_HIPAA           = 0x0004,   // Health Insurance Portability Act
    HMR_COMPLIANCE_ISO27001        = 0x0008,   // ISO 27001 Information Security
    HMR_COMPLIANCE_PCI_DSS         = 0x0010,   // Payment Card Industry DSS
    HMR_COMPLIANCE_FISMA           = 0x0020,   // Federal Information Security Management Act
    HMR_COMPLIANCE_NIST            = 0x0040,   // NIST Cybersecurity Framework
    HMR_COMPLIANCE_COBIT           = 0x0080,   // Control Objectives for IT
    HMR_COMPLIANCE_CUSTOM          = 0x8000    // Custom compliance requirements
} hmr_compliance_standard_t;

// Compliance control categories
typedef enum {
    HMR_CONTROL_ACCESS_CONTROL     = 0,    // Access control measures
    HMR_CONTROL_DATA_PROTECTION    = 1,    // Data protection and privacy
    HMR_CONTROL_AUDIT_LOGGING      = 2,    // Audit and logging requirements
    HMR_CONTROL_CHANGE_MANAGEMENT  = 3,    // Change management processes
    HMR_CONTROL_INCIDENT_RESPONSE  = 4,    // Incident response procedures
    HMR_CONTROL_BUSINESS_CONTINUITY = 5,   // Business continuity planning
    HMR_CONTROL_RISK_MANAGEMENT    = 6,    // Risk assessment and management
    HMR_CONTROL_VENDOR_MANAGEMENT  = 7,    // Third-party vendor management
    HMR_CONTROL_PHYSICAL_SECURITY  = 8,    // Physical security controls
    HMR_CONTROL_PERSONNEL_SECURITY = 9     // Personnel security measures
} hmr_compliance_control_category_t;

// Compliance status levels
typedef enum {
    HMR_COMPLIANCE_STATUS_COMPLIANT     = 0,   // Fully compliant
    HMR_COMPLIANCE_STATUS_WARNING       = 1,   // Warning - minor issues
    HMR_COMPLIANCE_STATUS_NON_COMPLIANT = 2,   // Non-compliant
    HMR_COMPLIANCE_STATUS_CRITICAL      = 3,   // Critical compliance failure
    HMR_COMPLIANCE_STATUS_UNKNOWN       = 4    // Status unknown/unassessed
} hmr_compliance_status_t;

// Evidence types for compliance verification
typedef enum {
    HMR_EVIDENCE_LOG_ENTRY         = 0,    // Log entry evidence
    HMR_EVIDENCE_CONFIGURATION     = 1,    // Configuration setting
    HMR_EVIDENCE_AUDIT_RESULT      = 2,    // Audit test result
    HMR_EVIDENCE_POLICY_DOCUMENT   = 3,    // Policy or procedure document
    HMR_EVIDENCE_TRAINING_RECORD   = 4,    // Training completion record
    HMR_EVIDENCE_INCIDENT_REPORT   = 5,    // Incident response record
    HMR_EVIDENCE_RISK_ASSESSMENT   = 6,    // Risk assessment result
    HMR_EVIDENCE_PENETRATION_TEST  = 7,    // Security test result
    HMR_EVIDENCE_CODE_REVIEW       = 8,    // Code review evidence
    HMR_EVIDENCE_EXTERNAL_AUDIT    = 9     // External audit result
} hmr_evidence_type_t;

// =============================================================================
// Error Codes
// =============================================================================

#define HMR_COMPLIANCE_SUCCESS                 0
#define HMR_COMPLIANCE_ERROR_NULL_POINTER     -1
#define HMR_COMPLIANCE_ERROR_INVALID_ARG      -2
#define HMR_COMPLIANCE_ERROR_NOT_FOUND        -3
#define HMR_COMPLIANCE_ERROR_ALREADY_EXISTS   -4
#define HMR_COMPLIANCE_ERROR_VIOLATION        -5
#define HMR_COMPLIANCE_ERROR_EVIDENCE_MISSING -6
#define HMR_COMPLIANCE_ERROR_AUDIT_FAILED     -7
#define HMR_COMPLIANCE_ERROR_ENCRYPTION       -8

// =============================================================================
// Compliance Data Structures
// =============================================================================

// Compliance control definition
typedef struct {
    uint32_t control_id;                    // Unique control identifier
    char control_name[128];                 // Control name
    char description[512];                  // Detailed description
    hmr_compliance_standard_t standards;    // Applicable standards (bitmask)
    hmr_compliance_control_category_t category; // Control category
    uint32_t priority_level;                // Priority (1-10, 10 = highest)
    bool is_automated;                      // Whether control is automated
    bool is_continuous;                     // Whether monitoring is continuous
    uint32_t assessment_frequency_days;     // How often to assess (days)
    
    // Implementation details
    char implementation_guide[1024];        // Implementation guidance
    char testing_procedure[512];            // How to test the control
    char remediation_steps[512];            // Steps to remediate failures
    
    // Current status
    hmr_compliance_status_t status;         // Current compliance status
    uint64_t last_assessment_time;          // When last assessed
    uint64_t next_assessment_time;          // When next assessment is due
    uint32_t consecutive_failures;          // Consecutive assessment failures
    double compliance_score;                // Compliance score (0.0-1.0)
    
    // Evidence tracking
    uint32_t evidence_count;                // Number of evidence items
    uint64_t evidence_last_updated;         // When evidence was last updated
    bool evidence_sufficient;               // Whether evidence is sufficient
} hmr_compliance_control_t;

// Compliance violation record
typedef struct {
    uint64_t violation_id;                  // Unique violation identifier
    uint64_t timestamp;                     // When violation occurred
    uint32_t control_id;                    // Which control was violated
    hmr_compliance_standard_t standards;    // Which standards are affected
    char violation_description[512];        // Description of violation
    char root_cause[256];                   // Root cause analysis
    char impact_assessment[256];            // Impact on business/compliance
    
    // Severity and classification
    uint32_t severity_level;                // Severity (1-10, 10 = critical)
    bool is_material_weakness;              // Whether this is a material weakness
    bool affects_financial_reporting;       // SOX-specific flag
    bool involves_personal_data;            // GDPR-specific flag
    
    // Remediation tracking
    char remediation_plan[512];             // Plan to fix the violation
    uint64_t target_resolution_time;        // When violation should be resolved
    uint64_t actual_resolution_time;        // When violation was actually resolved
    bool is_resolved;                       // Whether violation is resolved
    char resolution_evidence[256];          // Evidence of resolution
    
    // Reporting and escalation
    bool reported_to_management;            // Whether escalated to management
    bool reported_to_regulators;            // Whether reported to regulators
    bool reported_to_auditors;              // Whether reported to auditors
    uint64_t management_notification_time;  // When management was notified
    char assigned_responsible_party[128];   // Who is responsible for fixing
} hmr_compliance_violation_t;

// Evidence record for compliance verification
typedef struct {
    uint64_t evidence_id;                   // Unique evidence identifier
    uint32_t control_id;                    // Which control this supports
    hmr_evidence_type_t evidence_type;      // Type of evidence
    uint64_t collection_timestamp;          // When evidence was collected
    uint64_t evidence_date;                 // Date the evidence is from
    
    // Evidence content
    char evidence_description[512];         // Description of evidence
    char evidence_source[256];              // Source of evidence
    char collection_method[128];            // How evidence was collected
    uint32_t evidence_size;                 // Size of evidence data
    uint8_t evidence_hash[32];              // SHA-256 hash of evidence
    bool is_encrypted;                      // Whether evidence is encrypted
    bool is_digitally_signed;               // Whether evidence has digital signature
    
    // Validation and integrity
    bool integrity_verified;                // Whether integrity was verified
    uint64_t verification_timestamp;        // When integrity was last verified
    char verification_method[128];          // How integrity was verified
    uint32_t retention_period_days;         // How long to retain evidence
    uint64_t disposal_date;                 // When evidence can be disposed
    
    // Metadata
    char collector_id[64];                  // Who collected the evidence
    char reviewer_id[64];                   // Who reviewed the evidence
    bool is_sufficient;                     // Whether evidence is sufficient
    char sufficiency_notes[256];            // Notes on evidence sufficiency
} hmr_compliance_evidence_t;

// Compliance assessment result
typedef struct {
    uint64_t assessment_id;                 // Unique assessment identifier
    uint32_t control_id;                    // Control that was assessed
    uint64_t assessment_timestamp;          // When assessment was performed
    char assessor_id[64];                   // Who performed the assessment
    
    // Assessment results
    hmr_compliance_status_t result_status;  // Assessment result
    double compliance_score;                // Compliance score (0.0-1.0)
    char findings[1024];                    // Detailed findings
    char recommendations[512];              // Recommendations for improvement
    
    // Evidence reviewed
    uint32_t evidence_reviewed_count;       // Number of evidence items reviewed
    uint64_t evidence_review_timestamp;     // When evidence was reviewed
    bool all_evidence_present;              // Whether all required evidence present
    char missing_evidence[256];             // Description of missing evidence
    
    // Follow-up actions
    bool requires_remediation;              // Whether remediation is required
    char remediation_timeline[128];         // Timeline for remediation
    uint64_t next_assessment_date;          // When to reassess
    bool escalation_required;               // Whether escalation is needed
} hmr_compliance_assessment_t;

// Compliance report structure
typedef struct {
    uint64_t report_id;                     // Unique report identifier
    uint64_t report_timestamp;              // When report was generated
    uint64_t reporting_period_start;        // Start of reporting period
    uint64_t reporting_period_end;          // End of reporting period
    hmr_compliance_standard_t standards;    // Standards covered in report
    
    // Overall compliance metrics
    double overall_compliance_score;        // Overall compliance percentage
    uint32_t total_controls_assessed;       // Total controls assessed
    uint32_t compliant_controls;            // Number of compliant controls
    uint32_t non_compliant_controls;        // Number of non-compliant controls
    uint32_t total_violations;              // Total violations in period
    uint32_t resolved_violations;           // Violations resolved in period
    uint32_t open_violations;               // Still-open violations
    
    // By severity breakdown
    uint32_t critical_violations;           // Critical violations
    uint32_t high_violations;               // High severity violations
    uint32_t medium_violations;             // Medium severity violations
    uint32_t low_violations;                // Low severity violations
    
    // Trends and analysis
    double compliance_trend;                // Trend (improving/degrading)
    char key_findings[1024];                // Key findings summary
    char recommendations[1024];             // Recommendations for improvement
    char management_summary[512];           // Executive summary
    
    // Evidence and audit trail
    uint32_t evidence_items_collected;      // Evidence items in period
    uint32_t audit_log_entries;             // Audit log entries in period
    bool audit_trail_complete;              // Whether audit trail is complete
    char audit_trail_gaps[256];             // Any gaps in audit trail
} hmr_compliance_report_t;

// Main compliance manager
typedef struct {
    // Controls and standards
    hmr_compliance_control_t controls[HMR_COMPLIANCE_MAX_CONTROLS];
    uint32_t active_controls;               // Number of active controls
    hmr_compliance_standard_t enabled_standards; // Enabled compliance standards
    
    // Violations and incidents
    hmr_compliance_violation_t violations[HMR_COMPLIANCE_MAX_VIOLATIONS];
    uint32_t violation_count;               // Current violation count
    uint32_t violation_head;                // Circular buffer head
    uint64_t next_violation_id;             // Next violation ID
    
    // Evidence management
    hmr_compliance_evidence_t* evidence_buffer; // Evidence buffer
    uint32_t evidence_buffer_size;          // Size of evidence buffer
    uint32_t evidence_count;                // Current evidence count
    uint32_t evidence_head;                 // Evidence buffer head
    uint64_t next_evidence_id;              // Next evidence ID
    
    // Assessment tracking
    hmr_compliance_assessment_t* assessment_buffer; // Assessment buffer
    uint32_t assessment_buffer_size;        // Size of assessment buffer
    uint32_t assessment_count;              // Current assessment count
    uint64_t next_assessment_id;            // Next assessment ID
    
    // System configuration
    bool compliance_enabled;                // Master enable/disable
    bool continuous_monitoring;             // Continuous monitoring enabled
    bool automated_reporting;               // Automated report generation
    uint32_t audit_log_retention_days;      // Audit log retention period
    uint32_t evidence_retention_days;       // Evidence retention period
    bool encryption_required;               // Whether encryption is required
    bool digital_signatures_required;       // Whether digital signatures required
    
    // Performance and statistics
    uint64_t total_assessments;             // Total assessments performed
    uint64_t total_evidence_collected;      // Total evidence items collected
    uint64_t total_violations_detected;     // Total violations detected
    uint64_t total_violations_resolved;     // Total violations resolved
    double average_compliance_score;        // Average compliance score
    uint64_t compliance_monitoring_time_ns; // Time spent on compliance monitoring
    
    // Reporting schedule
    uint32_t daily_report_time;             // Time for daily reports (minutes since midnight)
    uint32_t weekly_report_day;             // Day for weekly reports (0=Sunday)
    uint32_t monthly_report_day;            // Day for monthly reports
    uint32_t annual_report_month;           // Month for annual reports
    bool generate_real_time_alerts;         // Whether to generate real-time alerts
} hmr_compliance_manager_t;

// =============================================================================
// Core Compliance Functions
// =============================================================================

/**
 * Initialize the compliance management system
 * 
 * @param enabled_standards Bitmask of compliance standards to enable
 * @param continuous_monitoring Whether to enable continuous monitoring
 * @param encryption_required Whether encryption is required for evidence
 * @return HMR_COMPLIANCE_SUCCESS on success, error code on failure
 */
int hmr_compliance_init(hmr_compliance_standard_t enabled_standards,
                       bool continuous_monitoring, bool encryption_required);

/**
 * Shutdown the compliance management system
 * Generates final reports and secures all evidence
 * 
 * @return HMR_COMPLIANCE_SUCCESS on success, error code on failure
 */
int hmr_compliance_shutdown(void);

/**
 * Register a compliance control
 * 
 * @param control_id Unique control identifier
 * @param control_name Control name
 * @param description Detailed description
 * @param standards Applicable standards (bitmask)
 * @param category Control category
 * @param priority_level Priority (1-10)
 * @param is_automated Whether control is automated
 * @param assessment_frequency_days How often to assess
 * @return HMR_COMPLIANCE_SUCCESS on success, error code on failure
 */
int hmr_compliance_register_control(uint32_t control_id, const char* control_name,
                                   const char* description, hmr_compliance_standard_t standards,
                                   hmr_compliance_control_category_t category,
                                   uint32_t priority_level, bool is_automated,
                                   uint32_t assessment_frequency_days);

/**
 * Unregister a compliance control
 * 
 * @param control_id Control to unregister
 * @return HMR_COMPLIANCE_SUCCESS on success, error code on failure
 */
int hmr_compliance_unregister_control(uint32_t control_id);

// =============================================================================
// Evidence Management
// =============================================================================

/**
 * Collect evidence for compliance verification
 * 
 * @param control_id Control this evidence supports
 * @param evidence_type Type of evidence
 * @param evidence_description Description of evidence
 * @param evidence_source Source of evidence
 * @param evidence_data Raw evidence data
 * @param evidence_size Size of evidence data
 * @return HMR_COMPLIANCE_SUCCESS on success, error code on failure
 */
int hmr_compliance_collect_evidence(uint32_t control_id, hmr_evidence_type_t evidence_type,
                                   const char* evidence_description, const char* evidence_source,
                                   const void* evidence_data, uint32_t evidence_size);

/**
 * Verify evidence integrity
 * 
 * @param evidence_id Evidence to verify
 * @param verification_method Method used for verification
 * @return HMR_COMPLIANCE_SUCCESS if integrity verified, error code if compromised
 */
int hmr_compliance_verify_evidence_integrity(uint64_t evidence_id, const char* verification_method);

/**
 * Get evidence for a control
 * 
 * @param control_id Control to get evidence for
 * @param evidence_items Output array for evidence
 * @param max_items Maximum number of evidence items to return
 * @param actual_items Output: actual number of items returned
 * @return HMR_COMPLIANCE_SUCCESS on success, error code on failure
 */
int hmr_compliance_get_evidence(uint32_t control_id, hmr_compliance_evidence_t* evidence_items,
                               uint32_t max_items, uint32_t* actual_items);

// =============================================================================
// Compliance Assessment
// =============================================================================

/**
 * Perform compliance assessment for a control
 * 
 * @param control_id Control to assess
 * @param assessor_id Who is performing the assessment
 * @param assessment_notes Additional notes for the assessment
 * @return HMR_COMPLIANCE_SUCCESS on success, error code if control fails
 */
int hmr_compliance_assess_control(uint32_t control_id, const char* assessor_id,
                                 const char* assessment_notes);

/**
 * Perform comprehensive compliance assessment for all controls
 * 
 * @param standards Standards to assess (bitmask, 0 = all enabled standards)
 * @param assessor_id Who is performing the assessment
 * @return HMR_COMPLIANCE_SUCCESS on success, error code if any controls fail
 */
int hmr_compliance_assess_all_controls(hmr_compliance_standard_t standards, const char* assessor_id);

/**
 * Get compliance status for a control
 * 
 * @param control_id Control to check
 * @param status Output: current compliance status
 * @param score Output: current compliance score
 * @param last_assessment Output: timestamp of last assessment
 * @return HMR_COMPLIANCE_SUCCESS on success, error code on failure
 */
int hmr_compliance_get_control_status(uint32_t control_id, hmr_compliance_status_t* status,
                                     double* score, uint64_t* last_assessment);

// =============================================================================
// Violation Management
// =============================================================================

/**
 * Report a compliance violation
 * 
 * @param control_id Control that was violated
 * @param standards Which standards are affected
 * @param violation_description Description of the violation
 * @param severity_level Severity (1-10)
 * @param is_material_weakness Whether this is a material weakness
 * @return HMR_COMPLIANCE_SUCCESS on success, error code on failure
 */
int hmr_compliance_report_violation(uint32_t control_id, hmr_compliance_standard_t standards,
                                   const char* violation_description, uint32_t severity_level,
                                   bool is_material_weakness);

/**
 * Resolve a compliance violation
 * 
 * @param violation_id Violation to resolve
 * @param resolution_evidence Evidence that violation was resolved
 * @param resolver_id Who resolved the violation
 * @return HMR_COMPLIANCE_SUCCESS on success, error code on failure
 */
int hmr_compliance_resolve_violation(uint64_t violation_id, const char* resolution_evidence,
                                    const char* resolver_id);

/**
 * Get open violations
 * 
 * @param violations Output array for violations
 * @param max_violations Maximum number of violations to return
 * @param actual_violations Output: actual number of violations returned
 * @return HMR_COMPLIANCE_SUCCESS on success, error code on failure
 */
int hmr_compliance_get_open_violations(hmr_compliance_violation_t* violations,
                                      uint32_t max_violations, uint32_t* actual_violations);

// =============================================================================
// Reporting and Documentation
// =============================================================================

/**
 * Generate compliance report
 * 
 * @param standards Standards to include in report (bitmask)
 * @param report_start_time Start of reporting period
 * @param report_end_time End of reporting period
 * @param report Output: generated compliance report
 * @return HMR_COMPLIANCE_SUCCESS on success, error code on failure
 */
int hmr_compliance_generate_report(hmr_compliance_standard_t standards,
                                  uint64_t report_start_time, uint64_t report_end_time,
                                  hmr_compliance_report_t* report);

/**
 * Export compliance data for external audit
 * 
 * @param standards Standards to export (bitmask)
 * @param format Export format ("xml", "json", "csv")
 * @param include_evidence Whether to include evidence data
 * @param buffer Output buffer
 * @param buffer_size Size of output buffer
 * @return HMR_COMPLIANCE_SUCCESS on success, error code on failure
 */
int hmr_compliance_export_audit_data(hmr_compliance_standard_t standards, const char* format,
                                     bool include_evidence, char* buffer, size_t buffer_size);

/**
 * Generate executive summary report
 * 
 * @param summary_buffer Buffer for executive summary
 * @param buffer_size Size of summary buffer
 * @return HMR_COMPLIANCE_SUCCESS on success, error code on failure
 */
int hmr_compliance_generate_executive_summary(char* summary_buffer, size_t buffer_size);

// =============================================================================
// Continuous Monitoring
// =============================================================================

/**
 * Perform continuous compliance monitoring
 * Call periodically to monitor compliance in real-time
 * 
 * @param frame_budget_ns Maximum time budget for monitoring
 * @return HMR_COMPLIANCE_SUCCESS on success, error code if violations detected
 */
int hmr_compliance_continuous_monitor(uint64_t frame_budget_ns);

/**
 * Enable or disable continuous monitoring for a control
 * 
 * @param control_id Control to configure
 * @param enabled Whether to enable continuous monitoring
 * @return HMR_COMPLIANCE_SUCCESS on success, error code on failure
 */
int hmr_compliance_set_continuous_monitoring(uint32_t control_id, bool enabled);

/**
 * Set up automated compliance alerts
 * 
 * @param standards Standards to monitor (bitmask)
 * @param alert_threshold Minimum severity to generate alerts
 * @param notification_recipients Who to notify
 * @return HMR_COMPLIANCE_SUCCESS on success, error code on failure
 */
int hmr_compliance_setup_automated_alerts(hmr_compliance_standard_t standards,
                                         uint32_t alert_threshold,
                                         const char* notification_recipients);

// =============================================================================
// Audit Trail and Immutable Logging
// =============================================================================

/**
 * Log compliance event to immutable audit trail
 * 
 * @param event_type Type of compliance event
 * @param control_id Control involved (0 if not control-specific)
 * @param event_description Description of event
 * @param actor_id Who performed the action
 * @return HMR_COMPLIANCE_SUCCESS on success, error code on failure
 */
int hmr_compliance_log_audit_event(const char* event_type, uint32_t control_id,
                                  const char* event_description, const char* actor_id);

/**
 * Verify audit trail integrity
 * 
 * @param start_time Start of period to verify
 * @param end_time End of period to verify
 * @param integrity_verified Output: whether integrity is intact
 * @return HMR_COMPLIANCE_SUCCESS on success, error code if integrity compromised
 */
int hmr_compliance_verify_audit_trail(uint64_t start_time, uint64_t end_time,
                                     bool* integrity_verified);

/**
 * Export audit trail for external review
 * 
 * @param start_time Start of period to export
 * @param end_time End of period to export
 * @param format Export format
 * @param buffer Output buffer
 * @param buffer_size Size of output buffer
 * @return HMR_COMPLIANCE_SUCCESS on success, error code on failure
 */
int hmr_compliance_export_audit_trail(uint64_t start_time, uint64_t end_time,
                                     const char* format, char* buffer, size_t buffer_size);

// =============================================================================
// Convenience Macros
// =============================================================================

/**
 * Quick compliance violation reporting
 */
#define HMR_COMPLIANCE_REPORT_VIOLATION(control_id, standards, desc, severity) \
    hmr_compliance_report_violation(control_id, standards, desc, severity, false)

/**
 * Report material weakness (SOX compliance)
 */
#define HMR_COMPLIANCE_REPORT_MATERIAL_WEAKNESS(control_id, desc) \
    hmr_compliance_report_violation(control_id, HMR_COMPLIANCE_SOX, desc, 10, true)

/**
 * Log audit event with current timestamp
 */
#define HMR_COMPLIANCE_LOG_EVENT(event_type, control_id, desc, actor) \
    hmr_compliance_log_audit_event(event_type, control_id, desc, actor)

#ifdef __cplusplus
}
#endif

#endif // HMR_RUNTIME_COMPLIANCE_H