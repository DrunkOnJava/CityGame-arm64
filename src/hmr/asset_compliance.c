/*
 * SimCity ARM64 - Asset Compliance Monitoring System Implementation
 * Enterprise license tracking and validation for game assets
 * 
 * Created by Agent 5: Asset Pipeline & Advanced Features - Week 3 Day 11
 * Comprehensive compliance monitoring with license tracking and validation
 */

#include "asset_compliance.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <pthread.h>
#include <dirent.h>
#include <sqlite3.h>

// Global metrics tracking
static compliance_metrics_t g_compliance_metrics = {0};
static pthread_mutex_t g_metrics_mutex = PTHREAD_MUTEX_INITIALIZER;

// License database with common game development licenses
static const license_info_t g_license_database[] = {
    {
        .type = LICENSE_MIT,
        .name = "MIT License",
        .version = "1.0",
        .identifier = "MIT",
        .url = "https://opensource.org/licenses/MIT",
        .restrictions = LICENSE_RESTRICT_ATTRIBUTION,
        .is_osi_approved = true,
        .is_fsf_libre = true,
        .allows_commercial = true,
        .allows_modification = true,
        .allows_distribution = true,
        .requires_attribution = true,
        .requires_share_alike = false,
        .is_copyleft = false
    },
    {
        .type = LICENSE_APACHE_2,
        .name = "Apache License 2.0",
        .version = "2.0",
        .identifier = "Apache-2.0",
        .url = "https://www.apache.org/licenses/LICENSE-2.0",
        .restrictions = LICENSE_RESTRICT_ATTRIBUTION | LICENSE_RESTRICT_PATENT,
        .is_osi_approved = true,
        .is_fsf_libre = true,
        .allows_commercial = true,
        .allows_modification = true,
        .allows_distribution = true,
        .requires_attribution = true,
        .requires_share_alike = false,
        .is_copyleft = false
    },
    {
        .type = LICENSE_CREATIVE_COMMONS_BY,
        .name = "Creative Commons Attribution 4.0",
        .version = "4.0",
        .identifier = "CC-BY-4.0",
        .url = "https://creativecommons.org/licenses/by/4.0/",
        .restrictions = LICENSE_RESTRICT_ATTRIBUTION,
        .is_osi_approved = false,
        .is_fsf_libre = true,
        .allows_commercial = true,
        .allows_modification = true,
        .allows_distribution = true,
        .requires_attribution = true,
        .requires_share_alike = false,
        .is_copyleft = false
    },
    {
        .type = LICENSE_CREATIVE_COMMONS_NC,
        .name = "Creative Commons Attribution-NonCommercial 4.0",
        .version = "4.0",
        .identifier = "CC-BY-NC-4.0",
        .url = "https://creativecommons.org/licenses/by-nc/4.0/",
        .restrictions = LICENSE_RESTRICT_ATTRIBUTION | LICENSE_RESTRICT_NON_COMMERCIAL,
        .is_osi_approved = false,
        .is_fsf_libre = false,
        .allows_commercial = false,
        .allows_modification = true,
        .allows_distribution = true,
        .requires_attribution = true,
        .requires_share_alike = false,
        .is_copyleft = false
    },
    {
        .type = LICENSE_UNITY_ASSET_STORE,
        .name = "Unity Asset Store License",
        .version = "1.0",
        .identifier = "Unity-Asset-Store",
        .url = "https://unity3d.com/legal/as_terms",
        .restrictions = LICENSE_RESTRICT_DISTRIBUTION | LICENSE_RESTRICT_MODIFICATION,
        .is_osi_approved = false,
        .is_fsf_libre = false,
        .allows_commercial = true,
        .allows_modification = false,
        .allows_distribution = false,
        .requires_attribution = false,
        .requires_share_alike = false,
        .is_copyleft = false
    },
    {
        .type = LICENSE_ROYALTY_FREE,
        .name = "Royalty-Free License",
        .version = "1.0",
        .identifier = "Royalty-Free",
        .url = "",
        .restrictions = LICENSE_RESTRICT_DISTRIBUTION,
        .is_osi_approved = false,
        .is_fsf_libre = false,
        .allows_commercial = true,
        .allows_modification = true,
        .allows_distribution = false,
        .requires_attribution = false,
        .requires_share_alike = false,
        .is_copyleft = false
    }
};

static const uint32_t g_license_database_size = sizeof(g_license_database) / sizeof(license_info_t);

// Internal function declarations
static int32_t create_compliance_database(compliance_manager_t* manager);
static int32_t scan_directory_recursive(compliance_manager_t* manager, const char* path);
static int32_t analyze_asset_license(compliance_manager_t* manager, const char* asset_path);
static int32_t detect_license_from_file(const char* file_path, asset_license_type_t* type);
static bool is_asset_file(const char* file_path);
static uint64_t get_current_timestamp(void);
static void update_metrics_scan(uint64_t duration_ms, uint32_t assets_scanned);
static int32_t check_policy_compliance(compliance_manager_t* manager, 
                                      const asset_license_metadata_t* metadata);
static void create_violation(compliance_manager_t* manager, const char* asset_path,
                           const char* violation_type, const char* description,
                           compliance_risk_level_t risk);

// Manager initialization
int32_t compliance_manager_init(compliance_manager_t** manager, const char* database_path) {
    if (!manager) {
        return COMPLIANCE_ERROR_INVALID_INPUT;
    }
    
    *manager = calloc(1, sizeof(compliance_manager_t));
    if (!*manager) {
        return COMPLIANCE_ERROR_INVALID_INPUT;
    }
    
    compliance_manager_t* mgr = *manager;
    
    // Initialize manager
    if (database_path) {
        strncpy(mgr->database_path, database_path, sizeof(mgr->database_path) - 1);
    } else {
        strcpy(mgr->database_path, "./compliance.db");
    }
    
    // Allocate collections
    mgr->max_licenses = COMPLIANCE_MAX_LICENSES;
    mgr->licenses = calloc(mgr->max_licenses, sizeof(asset_license_metadata_t));
    
    mgr->max_rules = COMPLIANCE_MAX_RULES;
    mgr->rules = calloc(mgr->max_rules, sizeof(compliance_policy_rule_t));
    
    mgr->max_violations = COMPLIANCE_MAX_VIOLATIONS;
    mgr->violations = calloc(mgr->max_violations, sizeof(compliance_violation_t));
    
    mgr->max_audit_entries = COMPLIANCE_MAX_AUDIT_ENTRIES;
    mgr->audit_trail = calloc(mgr->max_audit_entries, sizeof(audit_trail_entry_t));
    
    if (!mgr->licenses || !mgr->rules || !mgr->violations || !mgr->audit_trail) {
        compliance_manager_shutdown(mgr);
        *manager = NULL;
        return COMPLIANCE_ERROR_INVALID_INPUT;
    }
    
    // Initialize configuration
    mgr->auto_scan_enabled = true;
    mgr->scan_interval_hours = COMPLIANCE_DEFAULT_SCAN_INTERVAL;
    mgr->email_notifications = true;
    mgr->slack_notifications = false;
    
    // Initialize synchronization
    if (pthread_mutex_init(&mgr->mutex, NULL) != 0) {
        compliance_manager_shutdown(mgr);
        *manager = NULL;
        return COMPLIANCE_ERROR_INVALID_INPUT;
    }
    
    // Create or load database
    int32_t result = compliance_manager_load_database(mgr);
    if (result != COMPLIANCE_SUCCESS) {
        result = create_compliance_database(mgr);
        if (result != COMPLIANCE_SUCCESS) {
            compliance_manager_shutdown(mgr);
            *manager = NULL;
            return result;
        }
    }
    
    return COMPLIANCE_SUCCESS;
}

void compliance_manager_shutdown(compliance_manager_t* manager) {
    if (!manager) return;
    
    pthread_mutex_lock(&manager->mutex);
    
    // Save database before shutdown
    compliance_manager_save_database(manager);
    
    // Free allocated memory
    if (manager->licenses) free(manager->licenses);
    if (manager->rules) free(manager->rules);
    if (manager->violations) free(manager->violations);
    if (manager->audit_trail) free(manager->audit_trail);
    
    pthread_mutex_unlock(&manager->mutex);
    pthread_mutex_destroy(&manager->mutex);
    
    free(manager);
}

int32_t compliance_manager_load_database(compliance_manager_t* manager) {
    if (!manager) {
        return COMPLIANCE_ERROR_INVALID_INPUT;
    }
    
    sqlite3* db;
    int rc = sqlite3_open(manager->database_path, &db);
    if (rc != SQLITE_OK) {
        return COMPLIANCE_ERROR_DATABASE;
    }
    
    // Load license metadata
    const char* sql = "SELECT * FROM asset_licenses ORDER BY asset_path";
    sqlite3_stmt* stmt;
    
    rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
    if (rc == SQLITE_OK) {
        pthread_mutex_lock(&manager->mutex);
        manager->license_count = 0;
        
        while (sqlite3_step(stmt) == SQLITE_ROW && manager->license_count < manager->max_licenses) {
            asset_license_metadata_t* metadata = &manager->licenses[manager->license_count];
            
            strncpy(metadata->asset_path, (char*)sqlite3_column_text(stmt, 0), 
                   sizeof(metadata->asset_path) - 1);
            metadata->license.type = sqlite3_column_int(stmt, 1);
            strncpy(metadata->copyright_holder, (char*)sqlite3_column_text(stmt, 2),
                   sizeof(metadata->copyright_holder) - 1);
            strncpy(metadata->source_url, (char*)sqlite3_column_text(stmt, 3),
                   sizeof(metadata->source_url) - 1);
            metadata->purchase_price = sqlite3_column_double(stmt, 4);
            metadata->expiry_date = sqlite3_column_int64(stmt, 5);
            metadata->is_verified = sqlite3_column_int(stmt, 6);
            
            manager->license_count++;
        }
        
        pthread_mutex_unlock(&manager->mutex);
    }
    
    sqlite3_finalize(stmt);
    sqlite3_close(db);
    
    return COMPLIANCE_SUCCESS;
}

int32_t compliance_manager_save_database(compliance_manager_t* manager) {
    if (!manager) {
        return COMPLIANCE_ERROR_INVALID_INPUT;
    }
    
    sqlite3* db;
    int rc = sqlite3_open(manager->database_path, &db);
    if (rc != SQLITE_OK) {
        return COMPLIANCE_ERROR_DATABASE;
    }
    
    // Begin transaction
    sqlite3_exec(db, "BEGIN TRANSACTION", NULL, NULL, NULL);
    
    // Clear existing data
    sqlite3_exec(db, "DELETE FROM asset_licenses", NULL, NULL, NULL);
    
    // Insert license metadata
    const char* sql = "INSERT INTO asset_licenses "
                     "(asset_path, license_type, copyright_holder, source_url, "
                     "purchase_price, expiry_date, is_verified) "
                     "VALUES (?, ?, ?, ?, ?, ?, ?)";
    
    sqlite3_stmt* stmt;
    rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
    
    if (rc == SQLITE_OK) {
        pthread_mutex_lock(&manager->mutex);
        
        for (uint32_t i = 0; i < manager->license_count; i++) {
            asset_license_metadata_t* metadata = &manager->licenses[i];
            
            sqlite3_bind_text(stmt, 1, metadata->asset_path, -1, SQLITE_STATIC);
            sqlite3_bind_int(stmt, 2, metadata->license.type);
            sqlite3_bind_text(stmt, 3, metadata->copyright_holder, -1, SQLITE_STATIC);
            sqlite3_bind_text(stmt, 4, metadata->source_url, -1, SQLITE_STATIC);
            sqlite3_bind_double(stmt, 5, metadata->purchase_price);
            sqlite3_bind_int64(stmt, 6, metadata->expiry_date);
            sqlite3_bind_int(stmt, 7, metadata->is_verified);
            
            sqlite3_step(stmt);
            sqlite3_reset(stmt);
        }
        
        pthread_mutex_unlock(&manager->mutex);
    }
    
    sqlite3_finalize(stmt);
    
    // Commit transaction
    sqlite3_exec(db, "COMMIT", NULL, NULL, NULL);
    sqlite3_close(db);
    
    return COMPLIANCE_SUCCESS;
}

// License metadata management
int32_t compliance_add_asset_license(compliance_manager_t* manager, 
                                    const asset_license_metadata_t* metadata) {
    if (!manager || !metadata) {
        return COMPLIANCE_ERROR_INVALID_INPUT;
    }
    
    pthread_mutex_lock(&manager->mutex);
    
    if (manager->license_count >= manager->max_licenses) {
        pthread_mutex_unlock(&manager->mutex);
        return COMPLIANCE_ERROR_INVALID_INPUT;
    }
    
    // Check if asset already exists
    for (uint32_t i = 0; i < manager->license_count; i++) {
        if (strcmp(manager->licenses[i].asset_path, metadata->asset_path) == 0) {
            pthread_mutex_unlock(&manager->mutex);
            return COMPLIANCE_ERROR_ALREADY_EXISTS;
        }
    }
    
    // Add new license metadata
    manager->licenses[manager->license_count] = *metadata;
    manager->license_count++;
    
    pthread_mutex_unlock(&manager->mutex);
    
    // Add audit trail entry
    compliance_add_audit_entry(manager, "system", "add_license", 
                              metadata->asset_path, "License metadata added");
    
    // Check compliance with policies
    check_policy_compliance(manager, metadata);
    
    return COMPLIANCE_SUCCESS;
}

int32_t compliance_get_asset_license(compliance_manager_t* manager,
                                    const char* asset_path,
                                    asset_license_metadata_t* metadata) {
    if (!manager || !asset_path || !metadata) {
        return COMPLIANCE_ERROR_INVALID_INPUT;
    }
    
    pthread_mutex_lock(&manager->mutex);
    
    for (uint32_t i = 0; i < manager->license_count; i++) {
        if (strcmp(manager->licenses[i].asset_path, asset_path) == 0) {
            *metadata = manager->licenses[i];
            pthread_mutex_unlock(&manager->mutex);
            return COMPLIANCE_SUCCESS;
        }
    }
    
    pthread_mutex_unlock(&manager->mutex);
    return COMPLIANCE_ERROR_NOT_FOUND;
}

// License validation
int32_t compliance_validate_asset_license(compliance_manager_t* manager,
                                         const char* asset_path,
                                         license_validation_result_t* result) {
    if (!manager || !asset_path || !result) {
        return COMPLIANCE_ERROR_INVALID_INPUT;
    }
    
    memset(result, 0, sizeof(license_validation_result_t));
    
    asset_license_metadata_t metadata;
    int32_t get_result = compliance_get_asset_license(manager, asset_path, &metadata);
    
    if (get_result != COMPLIANCE_SUCCESS) {
        result->is_valid = false;
        result->status = COMPLIANCE_STATUS_UNKNOWN;
        result->risk = COMPLIANCE_RISK_MEDIUM;
        strcpy(result->validation_message, "No license information found for asset");
        result->needs_review = true;
        strcpy(result->issues[0], "Missing license metadata");
        result->issue_count = 1;
        return COMPLIANCE_SUCCESS;
    }
    
    uint64_t current_time = get_current_timestamp();
    
    // Check expiry
    if (metadata.expiry_date > 0 && metadata.expiry_date < current_time) {
        result->is_valid = false;
        result->status = COMPLIANCE_STATUS_EXPIRED;
        result->risk = COMPLIANCE_RISK_HIGH;
        strcpy(result->validation_message, "License has expired");
        result->needs_renewal = true;
        strcpy(result->issues[result->issue_count++], "License expired");
    } else if (metadata.expiry_date > 0) {
        uint64_t seconds_until_expiry = metadata.expiry_date - current_time;
        result->days_until_expiry = (uint32_t)(seconds_until_expiry / (24 * 3600));
        
        if (result->days_until_expiry <= COMPLIANCE_EXPIRY_WARNING_DAYS) {
            result->status = COMPLIANCE_STATUS_WARNING;
            result->risk = COMPLIANCE_RISK_MEDIUM;
            result->needs_renewal = true;
            snprintf(result->validation_message, sizeof(result->validation_message),
                    "License expires in %u days", result->days_until_expiry);
            strcpy(result->issues[result->issue_count++], "License expiring soon");
        }
    }
    
    // Check verification status
    if (!metadata.is_verified) {
        result->needs_review = true;
        result->risk = (result->risk < COMPLIANCE_RISK_MEDIUM) ? COMPLIANCE_RISK_MEDIUM : result->risk;
        strcpy(result->issues[result->issue_count++], "License not verified");
    }
    
    // Set default status if not already set
    if (result->status == 0 && result->issue_count == 0) {
        result->is_valid = true;
        result->status = COMPLIANCE_STATUS_COMPLIANT;
        result->risk = COMPLIANCE_RISK_NONE;
        strcpy(result->validation_message, "License is compliant");
    }
    
    pthread_mutex_lock(&g_metrics_mutex);
    g_compliance_metrics.total_assets_scanned++;
    pthread_mutex_unlock(&g_metrics_mutex);
    
    return COMPLIANCE_SUCCESS;
}

// Compliance scanning
int32_t compliance_start_scan(compliance_manager_t* manager, const char* scan_path) {
    if (!manager || !scan_path) {
        return COMPLIANCE_ERROR_INVALID_INPUT;
    }
    
    pthread_mutex_lock(&manager->mutex);
    
    if (manager->is_scanning) {
        pthread_mutex_unlock(&manager->mutex);
        return COMPLIANCE_ERROR_SCAN_ACTIVE;
    }
    
    manager->is_scanning = true;
    manager->last_scan_time = get_current_timestamp();
    strcpy(manager->scan_status, "Starting scan...");
    
    pthread_mutex_unlock(&manager->mutex);
    
    uint64_t start_time = get_current_timestamp();
    uint32_t assets_scanned = 0;
    
    // Recursively scan directory
    int32_t result = scan_directory_recursive(manager, scan_path);
    
    uint64_t end_time = get_current_timestamp();
    uint64_t duration_ms = (end_time - start_time) * 1000; // Convert to milliseconds
    
    pthread_mutex_lock(&manager->mutex);
    manager->is_scanning = false;
    strcpy(manager->scan_status, "Scan completed");
    manager->next_scan_time = get_current_timestamp() + (manager->scan_interval_hours * 3600);
    pthread_mutex_unlock(&manager->mutex);
    
    update_metrics_scan(duration_ms, assets_scanned);
    
    return result;
}

bool compliance_is_scanning(compliance_manager_t* manager) {
    if (!manager) return false;
    
    pthread_mutex_lock(&manager->mutex);
    bool scanning = manager->is_scanning;
    pthread_mutex_unlock(&manager->mutex);
    
    return scanning;
}

// Violation management
int32_t compliance_get_violations(compliance_manager_t* manager,
                                 compliance_violation_t* violations,
                                 uint32_t max_violations) {
    if (!manager || !violations || max_violations == 0) {
        return COMPLIANCE_ERROR_INVALID_INPUT;
    }
    
    pthread_mutex_lock(&manager->mutex);
    
    uint32_t copy_count = (manager->violation_count < max_violations) ? 
                         manager->violation_count : max_violations;
    
    for (uint32_t i = 0; i < copy_count; i++) {
        violations[i] = manager->violations[i];
    }
    
    pthread_mutex_unlock(&manager->mutex);
    
    return copy_count;
}

// License information
int32_t compliance_get_license_info(asset_license_type_t license_type, license_info_t* info) {
    if (!info) {
        return COMPLIANCE_ERROR_INVALID_INPUT;
    }
    
    for (uint32_t i = 0; i < g_license_database_size; i++) {
        if (g_license_database[i].type == license_type) {
            *info = g_license_database[i];
            return COMPLIANCE_SUCCESS;
        }
    }
    
    return COMPLIANCE_ERROR_NOT_FOUND;
}

const char* compliance_get_license_name(asset_license_type_t license_type) {
    for (uint32_t i = 0; i < g_license_database_size; i++) {
        if (g_license_database[i].type == license_type) {
            return g_license_database[i].name;
        }
    }
    return "Unknown License";
}

// Utility functions
const char* compliance_get_risk_level_name(compliance_risk_level_t risk) {
    switch (risk) {
        case COMPLIANCE_RISK_NONE: return "None";
        case COMPLIANCE_RISK_LOW: return "Low";
        case COMPLIANCE_RISK_MEDIUM: return "Medium";
        case COMPLIANCE_RISK_HIGH: return "High";
        case COMPLIANCE_RISK_CRITICAL: return "Critical";
        default: return "Unknown";
    }
}

const char* compliance_get_compliance_status_name(asset_compliance_status_t status) {
    switch (status) {
        case COMPLIANCE_STATUS_COMPLIANT: return "Compliant";
        case COMPLIANCE_STATUS_WARNING: return "Warning";
        case COMPLIANCE_STATUS_VIOLATION: return "Violation";
        case COMPLIANCE_STATUS_EXPIRED: return "Expired";
        case COMPLIANCE_STATUS_PENDING: return "Pending";
        case COMPLIANCE_STATUS_UNKNOWN: return "Unknown";
        default: return "Invalid";
    }
}

bool compliance_is_license_expired(const asset_license_metadata_t* metadata) {
    if (!metadata || metadata->expiry_date == 0) {
        return false;
    }
    
    return metadata->expiry_date < get_current_timestamp();
}

// Performance monitoring
void compliance_get_metrics(compliance_manager_t* manager, compliance_metrics_t* metrics) {
    if (!metrics) return;
    
    pthread_mutex_lock(&g_metrics_mutex);
    *metrics = g_compliance_metrics;
    pthread_mutex_unlock(&g_metrics_mutex);
    
    if (manager) {
        pthread_mutex_lock(&manager->mutex);
        metrics->license_types_tracked = manager->license_count;
        
        // Calculate compliance rate
        uint32_t compliant_count = 0;
        for (uint32_t i = 0; i < manager->license_count; i++) {
            if (!compliance_is_license_expired(&manager->licenses[i])) {
                compliant_count++;
            }
        }
        
        if (manager->license_count > 0) {
            metrics->current_compliance_rate = (compliant_count * 100) / manager->license_count;
        }
        
        pthread_mutex_unlock(&manager->mutex);
    }
}

void compliance_reset_metrics(compliance_manager_t* manager) {
    pthread_mutex_lock(&g_metrics_mutex);
    memset(&g_compliance_metrics, 0, sizeof(g_compliance_metrics));
    pthread_mutex_unlock(&g_metrics_mutex);
}

// Internal utility functions
static int32_t create_compliance_database(compliance_manager_t* manager) {
    sqlite3* db;
    int rc = sqlite3_open(manager->database_path, &db);
    if (rc != SQLITE_OK) {
        return COMPLIANCE_ERROR_DATABASE;
    }
    
    // Create tables
    const char* create_licenses_table = 
        "CREATE TABLE IF NOT EXISTS asset_licenses ("
        "asset_path TEXT PRIMARY KEY,"
        "license_type INTEGER,"
        "copyright_holder TEXT,"
        "source_url TEXT,"
        "purchase_price REAL,"
        "expiry_date INTEGER,"
        "is_verified INTEGER,"
        "created_time INTEGER DEFAULT CURRENT_TIMESTAMP)";
    
    const char* create_violations_table = 
        "CREATE TABLE IF NOT EXISTS violations ("
        "violation_id TEXT PRIMARY KEY,"
        "asset_path TEXT,"
        "violation_type TEXT,"
        "description TEXT,"
        "risk_level INTEGER,"
        "detected_time INTEGER,"
        "is_resolved INTEGER DEFAULT 0)";
    
    sqlite3_exec(db, create_licenses_table, NULL, NULL, NULL);
    sqlite3_exec(db, create_violations_table, NULL, NULL, NULL);
    
    sqlite3_close(db);
    return COMPLIANCE_SUCCESS;
}

static int32_t scan_directory_recursive(compliance_manager_t* manager, const char* path) {
    DIR* dir = opendir(path);
    if (!dir) {
        return COMPLIANCE_ERROR_PERMISSION;
    }
    
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }
        
        char full_path[1024];
        snprintf(full_path, sizeof(full_path), "%s/%s", path, entry->d_name);
        
        struct stat st;
        if (stat(full_path, &st) == 0) {
            if (S_ISDIR(st.st_mode)) {
                scan_directory_recursive(manager, full_path);
            } else if (is_asset_file(full_path)) {
                analyze_asset_license(manager, full_path);
            }
        }
    }
    
    closedir(dir);
    return COMPLIANCE_SUCCESS;
}

static int32_t analyze_asset_license(compliance_manager_t* manager, const char* asset_path) {
    // Check if license metadata already exists
    asset_license_metadata_t existing_metadata;
    if (compliance_get_asset_license(manager, asset_path, &existing_metadata) == COMPLIANCE_SUCCESS) {
        return COMPLIANCE_SUCCESS;
    }
    
    // Try to detect license automatically
    asset_license_type_t detected_type;
    if (detect_license_from_file(asset_path, &detected_type) == COMPLIANCE_SUCCESS) {
        asset_license_metadata_t new_metadata = {0};
        strncpy(new_metadata.asset_path, asset_path, sizeof(new_metadata.asset_path) - 1);
        new_metadata.license.type = detected_type;
        new_metadata.is_verified = false;
        
        compliance_add_asset_license(manager, &new_metadata);
    } else {
        // Create violation for unknown license
        create_violation(manager, asset_path, "unknown_license", 
                        "Asset license could not be determined", COMPLIANCE_RISK_MEDIUM);
    }
    
    return COMPLIANCE_SUCCESS;
}

static int32_t detect_license_from_file(const char* file_path, asset_license_type_t* type) {
    // Simple license detection based on file extension and common patterns
    const char* ext = strrchr(file_path, '.');
    if (!ext) {
        return COMPLIANCE_ERROR_NOT_FOUND;
    }
    
    // Default assumptions based on file types
    if (strcmp(ext, ".png") == 0 || strcmp(ext, ".jpg") == 0 || strcmp(ext, ".jpeg") == 0) {
        *type = LICENSE_ROYALTY_FREE; // Assume royalty-free for images
    } else if (strcmp(ext, ".wav") == 0 || strcmp(ext, ".ogg") == 0) {
        *type = LICENSE_ROYALTY_FREE; // Assume royalty-free for audio
    } else if (strcmp(ext, ".glsl") == 0 || strcmp(ext, ".hlsl") == 0) {
        *type = LICENSE_MIT; // Assume MIT for shader code
    } else {
        return COMPLIANCE_ERROR_NOT_FOUND;
    }
    
    return COMPLIANCE_SUCCESS;
}

static bool is_asset_file(const char* file_path) {
    const char* ext = strrchr(file_path, '.');
    if (!ext) return false;
    
    const char* asset_extensions[] = {
        ".png", ".jpg", ".jpeg", ".tga", ".bmp", ".gif", ".tiff",
        ".wav", ".ogg", ".mp3", ".flac", ".aiff",
        ".glsl", ".hlsl", ".vert", ".frag", ".geom",
        ".obj", ".fbx", ".dae", ".3ds", ".blend",
        ".ttf", ".otf", ".woff", ".woff2"
    };
    
    for (size_t i = 0; i < sizeof(asset_extensions) / sizeof(char*); i++) {
        if (strcasecmp(ext, asset_extensions[i]) == 0) {
            return true;
        }
    }
    
    return false;
}

static uint64_t get_current_timestamp(void) {
    return (uint64_t)time(NULL);
}

static void update_metrics_scan(uint64_t duration_ms, uint32_t assets_scanned) {
    pthread_mutex_lock(&g_metrics_mutex);
    g_compliance_metrics.total_scans_performed++;
    g_compliance_metrics.total_assets_scanned += assets_scanned;
    g_compliance_metrics.last_scan_duration_ms = duration_ms;
    g_compliance_metrics.avg_scan_time_ms = 
        (g_compliance_metrics.avg_scan_time_ms + duration_ms) / 2;
    pthread_mutex_unlock(&g_metrics_mutex);
}

static int32_t check_policy_compliance(compliance_manager_t* manager, 
                                      const asset_license_metadata_t* metadata) {
    // Policy compliance checking would be implemented here
    // For now, just basic checks
    if (compliance_is_license_expired(metadata)) {
        create_violation(manager, metadata->asset_path, "expired_license",
                        "Asset license has expired", COMPLIANCE_RISK_HIGH);
    }
    
    return COMPLIANCE_SUCCESS;
}

static void create_violation(compliance_manager_t* manager, const char* asset_path,
                           const char* violation_type, const char* description,
                           compliance_risk_level_t risk) {
    pthread_mutex_lock(&manager->mutex);
    
    if (manager->violation_count < manager->max_violations) {
        compliance_violation_t* violation = &manager->violations[manager->violation_count];
        
        snprintf(violation->violation_id, sizeof(violation->violation_id), 
                "V%lu", get_current_timestamp());
        strncpy(violation->asset_path, asset_path, sizeof(violation->asset_path) - 1);
        strncpy(violation->violation_type, violation_type, sizeof(violation->violation_type) - 1);
        strncpy(violation->description, description, sizeof(violation->description) - 1);
        violation->risk = risk;
        violation->detected_time = get_current_timestamp();
        violation->is_resolved = false;
        
        manager->violation_count++;
        
        pthread_mutex_lock(&g_metrics_mutex);
        g_compliance_metrics.total_violations_found++;
        pthread_mutex_unlock(&g_metrics_mutex);
    }
    
    pthread_mutex_unlock(&manager->mutex);
}

// Stub implementations for remaining functions
int32_t compliance_add_audit_entry(compliance_manager_t* manager,
                                  const char* user_id,
                                  const char* action,
                                  const char* asset_path,
                                  const char* details) {
    if (!manager || !user_id || !action) {
        return COMPLIANCE_ERROR_INVALID_INPUT;
    }
    
    pthread_mutex_lock(&manager->mutex);
    
    if (manager->audit_count < manager->max_audit_entries) {
        audit_trail_entry_t* entry = &manager->audit_trail[manager->audit_count];
        entry->timestamp = get_current_timestamp();
        strncpy(entry->user_id, user_id, sizeof(entry->user_id) - 1);
        strncpy(entry->action, action, sizeof(entry->action) - 1);
        if (asset_path) {
            strncpy(entry->asset_path, asset_path, sizeof(entry->asset_path) - 1);
        }
        if (details) {
            strncpy(entry->details, details, sizeof(entry->details) - 1);
        }
        
        manager->audit_count++;
    }
    
    pthread_mutex_unlock(&manager->mutex);
    
    return COMPLIANCE_SUCCESS;
}