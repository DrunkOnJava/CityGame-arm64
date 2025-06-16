/*
 * SimCity ARM64 - Asset Compliance Monitoring System
 * Enterprise license tracking and validation for game assets
 * 
 * Created by Agent 5: Asset Pipeline & Advanced Features - Week 3 Day 11
 * Comprehensive compliance monitoring with license tracking and validation
 */

#ifndef HMR_ASSET_COMPLIANCE_H
#define HMR_ASSET_COMPLIANCE_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <time.h>

// License types commonly used in game development
typedef enum {
    LICENSE_PROPRIETARY = 0,        // Proprietary/custom license
    LICENSE_MIT,                    // MIT License
    LICENSE_APACHE_2,               // Apache License 2.0
    LICENSE_BSD_3_CLAUSE,           // BSD 3-Clause License
    LICENSE_GPL_V3,                 // GNU General Public License v3
    LICENSE_LGPL_V3,                // GNU Lesser General Public License v3
    LICENSE_CREATIVE_COMMONS_0,     // Creative Commons Zero (Public Domain)
    LICENSE_CREATIVE_COMMONS_BY,    // Creative Commons Attribution
    LICENSE_CREATIVE_COMMONS_SA,    // Creative Commons Share-Alike
    LICENSE_CREATIVE_COMMONS_NC,    // Creative Commons Non-Commercial
    LICENSE_UNITY_ASSET_STORE,      // Unity Asset Store License
    LICENSE_UNREAL_MARKETPLACE,     // Unreal Engine Marketplace License
    LICENSE_ROYALTY_FREE,           // Royalty-free license
    LICENSE_STOCK_PHOTO,            // Stock photo license
    LICENSE_MUSIC_SYNC,             // Music synchronization license
    LICENSE_SOUND_EFFECT,           // Sound effect license
    LICENSE_FONT_COMMERCIAL,        // Commercial font license
    LICENSE_TEXTURE_COMMERCIAL,     // Commercial texture license
    LICENSE_MODEL_COMMERCIAL,       // Commercial 3D model license
    LICENSE_UNKNOWN,                // Unknown license type
    LICENSE_RESTRICTED,             // Restricted use license
    LICENSE_EVALUATION_ONLY         // Evaluation/demo only
} asset_license_type_t;

// Compliance risk levels
typedef enum {
    COMPLIANCE_RISK_NONE = 0,       // No compliance risk
    COMPLIANCE_RISK_LOW,            // Low risk - minor issues
    COMPLIANCE_RISK_MEDIUM,         // Medium risk - requires attention
    COMPLIANCE_RISK_HIGH,           // High risk - immediate action needed
    COMPLIANCE_RISK_CRITICAL        // Critical risk - legal implications
} compliance_risk_level_t;

// License restriction flags
typedef enum {
    LICENSE_RESTRICT_NONE           = 0x0000,   // No restrictions
    LICENSE_RESTRICT_COMMERCIAL     = 0x0001,   // Commercial use restricted
    LICENSE_RESTRICT_DISTRIBUTION   = 0x0002,   // Distribution restricted
    LICENSE_RESTRICT_MODIFICATION   = 0x0004,   // Modification restricted
    LICENSE_RESTRICT_ATTRIBUTION    = 0x0008,   // Attribution required
    LICENSE_RESTRICT_SHARE_ALIKE    = 0x0010,   // Share-alike required
    LICENSE_RESTRICT_NON_COMMERCIAL = 0x0020,   // Non-commercial only
    LICENSE_RESTRICT_PERSONAL_USE   = 0x0040,   // Personal use only
    LICENSE_RESTRICT_EVALUATION     = 0x0080,   // Evaluation use only
    LICENSE_RESTRICT_TIME_LIMITED   = 0x0100,   // Time-limited usage
    LICENSE_RESTRICT_GEOGRAPHY      = 0x0200,   // Geographic restrictions
    LICENSE_RESTRICT_DERIVATIVE     = 0x0400,   // No derivative works
    LICENSE_RESTRICT_COPYLEFT       = 0x0800,   // Copyleft requirements
    LICENSE_RESTRICT_PATENT         = 0x1000    // Patent restrictions
} license_restriction_t;

// Asset compliance status
typedef enum {
    COMPLIANCE_STATUS_COMPLIANT = 0,    // Fully compliant
    COMPLIANCE_STATUS_WARNING,          // Has warnings
    COMPLIANCE_STATUS_VIOLATION,        // License violation
    COMPLIANCE_STATUS_EXPIRED,          // License expired
    COMPLIANCE_STATUS_PENDING,          // Pending review
    COMPLIANCE_STATUS_UNKNOWN           // Unknown compliance status
} asset_compliance_status_t;

// License information
typedef struct {
    asset_license_type_t type;      // License type
    char name[128];                 // License name
    char version[32];               // License version
    char identifier[64];            // SPDX license identifier
    char url[512];                  // License URL
    char text[8192];                // License text (shortened)
    uint32_t restrictions;          // Restriction flags
    bool is_osi_approved;           // OSI approved license
    bool is_fsf_libre;              // FSF libre license
    bool allows_commercial;         // Commercial use allowed
    bool allows_modification;       // Modification allowed
    bool allows_distribution;       // Distribution allowed
    bool requires_attribution;      // Attribution required
    bool requires_share_alike;      // Share-alike required
    bool is_copyleft;              // Copyleft license
} license_info_t;

// Asset license metadata
typedef struct {
    char asset_path[512];           // Path to asset file
    license_info_t license;         // License information
    char copyright_holder[256];     // Copyright holder
    char copyright_year[32];        // Copyright year
    char source_url[512];           // Source URL where asset was obtained
    char purchase_date[32];         // Purchase date (YYYY-MM-DD)
    char license_key[128];          // License key/ID
    char invoice_number[64];        // Invoice number
    float purchase_price;           // Purchase price
    char currency[8];               // Currency code
    uint64_t expiry_date;           // License expiry date (timestamp)
    char vendor[256];               // Vendor/supplier name
    char vendor_contact[256];       // Vendor contact information
    char usage_rights[1024];       // Specific usage rights
    char attribution_text[512];     // Required attribution text
    char notes[1024];               // Additional notes
    bool is_verified;               // Whether license is verified
    uint64_t last_verified;         // Last verification timestamp
    char verified_by[128];          // Who verified the license
} asset_license_metadata_t;

// Compliance violation
typedef struct {
    char violation_id[64];          // Unique violation identifier
    char asset_path[512];           // Path to violating asset
    char violation_type[64];        // Type of violation
    char description[1024];         // Violation description
    compliance_risk_level_t risk;   // Risk level
    uint64_t detected_time;         // When violation was detected
    char detected_by[128];          // Who/what detected violation
    bool is_resolved;               // Whether violation is resolved
    uint64_t resolved_time;         // When violation was resolved
    char resolved_by[128];          // Who resolved violation
    char resolution[1024];          // Resolution description
    char recommended_action[512];   // Recommended action
    uint32_t severity_score;        // Severity score (0-100)
} compliance_violation_t;

// Asset audit trail entry
typedef struct {
    uint64_t timestamp;             // Audit timestamp
    char user_id[64];               // User who performed action
    char user_name[128];            // User display name
    char action[64];                // Action performed
    char asset_path[512];           // Asset path
    char old_value[512];            // Old value (if applicable)
    char new_value[512];            // New value (if applicable)
    char details[1024];             // Additional details
    char ip_address[64];            // IP address of user
    char session_id[64];            // Session identifier
} audit_trail_entry_t;

// Compliance policy rule
typedef struct {
    char rule_id[64];               // Unique rule identifier
    char name[128];                 // Rule name
    char description[512];          // Rule description
    bool is_active;                 // Whether rule is active
    uint32_t priority;              // Rule priority (higher = more important)
    char asset_pattern[256];        // Asset path pattern to match
    license_restriction_t required_restrictions;  // Required restrictions
    license_restriction_t prohibited_restrictions; // Prohibited restrictions
    char allowed_licenses[32][64];  // List of allowed license types
    uint32_t allowed_license_count; // Number of allowed licenses
    char prohibited_licenses[32][64]; // List of prohibited license types
    uint32_t prohibited_license_count; // Number of prohibited licenses
    uint64_t max_asset_age_days;    // Maximum asset age in days
    float max_purchase_price;       // Maximum purchase price
    bool requires_approval;         // Whether manual approval required
    char approval_group[128];       // Approval group/role
    char violation_action[64];      // Action to take on violation
    bool auto_quarantine;           // Whether to auto-quarantine violations
} compliance_policy_rule_t;

// Compliance report
typedef struct {
    char report_id[64];             // Unique report identifier
    uint64_t generated_time;        // Report generation time
    char generated_by[128];         // Who generated report
    uint32_t total_assets;          // Total assets scanned
    uint32_t compliant_assets;      // Compliant assets
    uint32_t warning_assets;        // Assets with warnings
    uint32_t violation_assets;      // Assets with violations
    uint32_t unknown_assets;        // Assets with unknown status
    uint32_t expired_licenses;      // Expired licenses
    uint32_t expiring_soon;         // Licenses expiring soon
    float total_license_cost;       // Total license cost
    char cost_currency[8];          // Currency for costs
    compliance_violation_t* violations; // List of violations
    uint32_t violation_count;       // Number of violations
    char summary[2048];             // Report summary
    char recommendations[4096];     // Recommendations
} compliance_report_t;

// Compliance manager
typedef struct {
    char database_path[512];        // Path to compliance database
    asset_license_metadata_t* licenses; // Asset license metadata
    uint32_t license_count;         // Number of licensed assets
    uint32_t max_licenses;          // Maximum licenses allocated
    
    compliance_policy_rule_t* rules; // Compliance policy rules
    uint32_t rule_count;            // Number of rules
    uint32_t max_rules;             // Maximum rules allocated
    
    compliance_violation_t* violations; // Active violations
    uint32_t violation_count;       // Number of violations
    uint32_t max_violations;        // Maximum violations allocated
    
    audit_trail_entry_t* audit_trail; // Audit trail
    uint32_t audit_count;           // Number of audit entries
    uint32_t max_audit_entries;     // Maximum audit entries
    
    bool auto_scan_enabled;         // Automatic scanning enabled
    uint32_t scan_interval_hours;   // Scan interval in hours
    uint64_t last_scan_time;        // Last scan timestamp
    uint64_t next_scan_time;        // Next scheduled scan
    
    char notification_email[256];   // Email for notifications
    bool email_notifications;       // Whether to send email notifications
    bool slack_notifications;       // Whether to send Slack notifications
    char slack_webhook[512];        // Slack webhook URL
    
    pthread_mutex_t mutex;          // Synchronization mutex
    bool is_scanning;               // Whether currently scanning
    char scan_status[256];          // Current scan status
} compliance_manager_t;

// License validation result
typedef struct {
    bool is_valid;                  // Whether license is valid
    asset_compliance_status_t status; // Compliance status
    compliance_risk_level_t risk;   // Risk level
    char validation_message[512];   // Validation message
    uint32_t days_until_expiry;     // Days until license expires
    bool needs_renewal;             // Whether license needs renewal
    bool needs_review;              // Whether license needs manual review
    char issues[10][256];           // List of issues found
    uint32_t issue_count;           // Number of issues
} license_validation_result_t;

// API Functions - Compliance Management
#ifdef __cplusplus
extern "C" {
#endif

// Manager initialization
int32_t compliance_manager_init(compliance_manager_t** manager, const char* database_path);
void compliance_manager_shutdown(compliance_manager_t* manager);
int32_t compliance_manager_load_database(compliance_manager_t* manager);
int32_t compliance_manager_save_database(compliance_manager_t* manager);

// License metadata management
int32_t compliance_add_asset_license(compliance_manager_t* manager, 
                                    const asset_license_metadata_t* metadata);
int32_t compliance_update_asset_license(compliance_manager_t* manager,
                                       const char* asset_path,
                                       const asset_license_metadata_t* metadata);
int32_t compliance_remove_asset_license(compliance_manager_t* manager, const char* asset_path);
int32_t compliance_get_asset_license(compliance_manager_t* manager,
                                    const char* asset_path,
                                    asset_license_metadata_t* metadata);

// License validation
int32_t compliance_validate_asset_license(compliance_manager_t* manager,
                                         const char* asset_path,
                                         license_validation_result_t* result);
int32_t compliance_validate_all_licenses(compliance_manager_t* manager);
int32_t compliance_check_license_expiry(compliance_manager_t* manager,
                                       uint32_t days_ahead,
                                       char expiring_assets[][512],
                                       uint32_t max_assets);

// Policy management
int32_t compliance_add_policy_rule(compliance_manager_t* manager,
                                  const compliance_policy_rule_t* rule);
int32_t compliance_update_policy_rule(compliance_manager_t* manager,
                                     const char* rule_id,
                                     const compliance_policy_rule_t* rule);
int32_t compliance_remove_policy_rule(compliance_manager_t* manager, const char* rule_id);
int32_t compliance_get_policy_rules(compliance_manager_t* manager,
                                   compliance_policy_rule_t* rules,
                                   uint32_t max_rules);

// Compliance scanning
int32_t compliance_start_scan(compliance_manager_t* manager, const char* scan_path);
int32_t compliance_stop_scan(compliance_manager_t* manager);
bool compliance_is_scanning(compliance_manager_t* manager);
int32_t compliance_get_scan_progress(compliance_manager_t* manager, float* progress);
int32_t compliance_schedule_scan(compliance_manager_t* manager, uint32_t interval_hours);

// Violation management
int32_t compliance_get_violations(compliance_manager_t* manager,
                                 compliance_violation_t* violations,
                                 uint32_t max_violations);
int32_t compliance_resolve_violation(compliance_manager_t* manager,
                                    const char* violation_id,
                                    const char* resolution,
                                    const char* resolved_by);
int32_t compliance_quarantine_asset(compliance_manager_t* manager, const char* asset_path);
int32_t compliance_unquarantine_asset(compliance_manager_t* manager, const char* asset_path);

// Reporting
int32_t compliance_generate_report(compliance_manager_t* manager,
                                  const char* report_type,
                                  compliance_report_t* report);
int32_t compliance_export_report(compliance_manager_t* manager,
                                const compliance_report_t* report,
                                const char* format,
                                const char* output_path);
int32_t compliance_get_compliance_summary(compliance_manager_t* manager,
                                         char summary[2048]);

// Audit trail
int32_t compliance_add_audit_entry(compliance_manager_t* manager,
                                  const char* user_id,
                                  const char* action,
                                  const char* asset_path,
                                  const char* details);
int32_t compliance_get_audit_trail(compliance_manager_t* manager,
                                  const char* asset_path,
                                  audit_trail_entry_t* entries,
                                  uint32_t max_entries);
int32_t compliance_export_audit_trail(compliance_manager_t* manager,
                                     const char* start_date,
                                     const char* end_date,
                                     const char* output_path);

// License information
int32_t compliance_get_license_info(asset_license_type_t license_type, license_info_t* info);
const char* compliance_get_license_name(asset_license_type_t license_type);
bool compliance_is_license_compatible(asset_license_type_t license1, asset_license_type_t license2);
int32_t compliance_detect_license_from_text(const char* license_text, asset_license_type_t* type);

// Utility functions
const char* compliance_get_risk_level_name(compliance_risk_level_t risk);
const char* compliance_get_compliance_status_name(asset_compliance_status_t status);
uint32_t compliance_calculate_risk_score(const asset_license_metadata_t* metadata);
bool compliance_is_license_expired(const asset_license_metadata_t* metadata);
uint32_t compliance_days_until_expiry(const asset_license_metadata_t* metadata);

// Notification system
int32_t compliance_send_notification(compliance_manager_t* manager,
                                    const char* subject,
                                    const char* message,
                                    const char* recipient);
int32_t compliance_configure_notifications(compliance_manager_t* manager,
                                          bool email_enabled,
                                          const char* email,
                                          bool slack_enabled,
                                          const char* slack_webhook);

// Integration with external systems
int32_t compliance_import_from_csv(compliance_manager_t* manager, const char* csv_path);
int32_t compliance_export_to_csv(compliance_manager_t* manager, const char* csv_path);
int32_t compliance_sync_with_asset_store(compliance_manager_t* manager, const char* store_type);
int32_t compliance_verify_with_spdx(compliance_manager_t* manager, const char* spdx_file);

// Performance monitoring
typedef struct {
    uint64_t total_scans_performed;     // Total scans performed
    uint64_t total_assets_scanned;      // Total assets scanned
    uint64_t total_violations_found;    // Total violations found
    uint64_t total_violations_resolved; // Total violations resolved
    uint64_t avg_scan_time_ms;          // Average scan time
    uint64_t avg_validation_time_ms;    // Average validation time
    uint32_t current_compliance_rate;   // Current compliance rate (0-100%)
    uint32_t license_types_tracked;     // Number of license types tracked
    float total_license_value;          // Total value of tracked licenses
    uint64_t last_scan_duration_ms;     // Last scan duration
} compliance_metrics_t;

void compliance_get_metrics(compliance_manager_t* manager, compliance_metrics_t* metrics);
void compliance_reset_metrics(compliance_manager_t* manager);

#ifdef __cplusplus
}
#endif

// Constants and configuration
#define COMPLIANCE_MAX_LICENSES         10000
#define COMPLIANCE_MAX_RULES            1000
#define COMPLIANCE_MAX_VIOLATIONS       5000
#define COMPLIANCE_MAX_AUDIT_ENTRIES    50000
#define COMPLIANCE_DEFAULT_SCAN_INTERVAL 24    // 24 hours
#define COMPLIANCE_EXPIRY_WARNING_DAYS   30    // Warn 30 days before expiry
#define COMPLIANCE_DATABASE_VERSION     1
#define COMPLIANCE_MAX_ASSET_PATH       512
#define COMPLIANCE_MAX_LICENSE_TEXT     8192

// Error codes
#define COMPLIANCE_SUCCESS              0
#define COMPLIANCE_ERROR_INVALID_INPUT  -1
#define COMPLIANCE_ERROR_NOT_FOUND      -2
#define COMPLIANCE_ERROR_ALREADY_EXISTS -3
#define COMPLIANCE_ERROR_DATABASE       -4
#define COMPLIANCE_ERROR_SCAN_ACTIVE    -5
#define COMPLIANCE_ERROR_VALIDATION     -6
#define COMPLIANCE_ERROR_PERMISSION     -7
#define COMPLIANCE_ERROR_NETWORK        -8
#define COMPLIANCE_ERROR_FORMAT         -9
#define COMPLIANCE_ERROR_EXPIRED        -10

// Default policy configurations
#define COMPLIANCE_DEFAULT_RISK_THRESHOLD    50
#define COMPLIANCE_DEFAULT_EXPIRY_THRESHOLD  30
#define COMPLIANCE_AUTO_QUARANTINE_ENABLED   true
#define COMPLIANCE_NOTIFICATION_ENABLED      true

#endif // HMR_ASSET_COMPLIANCE_H