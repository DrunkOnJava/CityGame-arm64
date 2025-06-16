/*
 * SimCity ARM64 - Module Versioning System Header
 * Advanced semantic versioning with compatibility checking and migration
 * 
 * Created by Agent 1: Core Module System - Week 2 Day 6
 * Provides comprehensive version management for HMR modules
 */

#ifndef HMR_MODULE_VERSIONING_H
#define HMR_MODULE_VERSIONING_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

// Version structure - semantic versioning with extensions
typedef struct {
    uint32_t major;             // Major version - breaking changes increment this
    uint32_t minor;             // Minor version - new features increment this
    uint32_t patch;             // Patch version - bug fixes increment this
    uint32_t build;             // Build number - auto-incremented per build
    uint32_t flags;             // Version flags (stable, beta, etc.)
    uint64_t timestamp;         // Version creation timestamp
    uint64_t hash;              // Version hash for verification
} hmr_version_t;

// Version flags - describe version characteristics
typedef enum {
    HMR_VERSION_STABLE      = 0x0001,   // Stable release version
    HMR_VERSION_BETA        = 0x0002,   // Beta testing version
    HMR_VERSION_ALPHA       = 0x0004,   // Alpha testing version
    HMR_VERSION_DEVELOPMENT = 0x0008,   // Development version
    HMR_VERSION_HOTFIX      = 0x0010,   // Emergency hotfix
    HMR_VERSION_BREAKING    = 0x0020,   // Contains breaking changes
    HMR_VERSION_DEPRECATED  = 0x0040,   // Deprecated version
    HMR_VERSION_SECURITY    = 0x0080,   // Security update
    HMR_VERSION_EXPERIMENTAL = 0x0100,  // Experimental features
    HMR_VERSION_LTS         = 0x0200,   // Long-term support
    HMR_VERSION_PRERELEASE  = 0x0400,   // Pre-release version
    HMR_VERSION_SNAPSHOT    = 0x0800    // Development snapshot
} hmr_version_flags_t;

// Version compatibility results
typedef enum {
    HMR_COMPAT_COMPATIBLE       = 0,    // Versions are fully compatible
    HMR_COMPAT_MIGRATION_REQ    = 1,    // Migration required but possible
    HMR_COMPAT_MAJOR_BREAKING   = -1,   // Major version mismatch
    HMR_COMPAT_MINOR_INCOMP     = -2,   // Minor version incompatible
    HMR_COMPAT_PATCH_INVALID    = -3,   // Patch version invalid
    HMR_COMPAT_DEPRECATED       = -4,   // Version is deprecated
    HMR_COMPAT_SECURITY_RISK    = -5,   // Security vulnerability
    HMR_COMPAT_UNKNOWN_FLAGS    = -6,   // Unknown version flags
    HMR_COMPAT_HASH_MISMATCH    = -7,   // Version hash mismatch
    HMR_COMPAT_INVALID_INPUT    = -10   // Invalid parameters
} hmr_version_compatibility_t;

// Compatibility check result
typedef struct {
    hmr_version_compatibility_t result;    // Compatibility result
    char reason[128];                      // Human-readable reason
    uint32_t actions;                      // Recommended actions bitmask
    void* migration_data;                  // Migration data if needed
} hmr_version_compat_result_t;

// Migration strategies
typedef enum {
    HMR_MIGRATION_NONE      = 0,    // No migration needed
    HMR_MIGRATION_AUTO      = 1,    // Automatic migration
    HMR_MIGRATION_MANUAL    = 2,    // Manual migration required
    HMR_MIGRATION_ROLLBACK  = 3,    // Rollback to previous version
    HMR_MIGRATION_FORCE     = 4,    // Force upgrade (ignore compatibility)
    HMR_MIGRATION_CUSTOM    = 5     // Custom migration handler
} hmr_migration_strategy_t;

// Migration context
typedef struct {
    hmr_version_t from_version;         // Source version
    hmr_version_t to_version;           // Target version
    hmr_migration_strategy_t strategy;  // Migration strategy
    void* migration_data;               // Migration-specific data
    size_t data_size;                   // Size of migration data
    void* callback;                     // Migration callback function
    uint32_t timeout_ms;                // Migration timeout
    uint32_t retry_count;               // Number of retry attempts
} hmr_migration_context_t;

// Migration callback function type
typedef int32_t (*hmr_migration_callback_t)(
    const hmr_version_t* from_version,
    const hmr_version_t* to_version,
    void* module_data,
    void* migration_context
);

// Rollback state handle
typedef struct {
    uint64_t handle_id;                 // Unique handle identifier
    hmr_version_t version;              // Version being rolled back
    void* state_data;                   // Saved module state
    size_t state_size;                  // Size of saved state
    uint64_t timestamp;                 // When rollback state was created
    uint32_t flags;                     // Rollback flags
} hmr_rollback_handle_t;

// Version registry entry
typedef struct {
    char module_name[64];               // Module name
    hmr_version_t version;              // Module version
    char file_path[256];                // Path to module file
    uint64_t file_hash;                 // File content hash
    uint64_t registration_time;         // When version was registered
    uint32_t load_count;                // Number of times loaded
    uint32_t flags;                     // Registry entry flags
} hmr_version_registry_entry_t;

// Recommended actions bitmask
#define HMR_ACTION_NONE             0x0000
#define HMR_ACTION_BACKUP           0x0001  // Backup current state
#define HMR_ACTION_MIGRATE          0x0002  // Perform migration
#define HMR_ACTION_ROLLBACK         0x0004  // Prepare rollback
#define HMR_ACTION_NOTIFY_USER      0x0008  // Notify user of changes
#define HMR_ACTION_RESTART_REQUIRED 0x0010  // Restart required
#define HMR_ACTION_FORCE_COMPATIBLE 0x0020  // Force compatibility
#define HMR_ACTION_SKIP_VALIDATION  0x0040  // Skip validation checks
#define HMR_ACTION_LOG_WARNING      0x0080  // Log compatibility warning

// API Functions - Core Versioning
#ifdef __cplusplus
extern "C" {
#endif

// Version creation and management
hmr_version_t* hmr_version_create(uint32_t major, uint32_t minor, uint32_t patch, 
                                  uint32_t build, uint32_t flags);
void hmr_version_destroy(hmr_version_t* version);
hmr_version_t* hmr_version_copy(const hmr_version_t* source);
int32_t hmr_version_compare(const hmr_version_t* v1, const hmr_version_t* v2);

// Version string operations
char* hmr_version_to_string(const hmr_version_t* version);
hmr_version_t* hmr_version_from_string(const char* version_string);
bool hmr_version_parse(const char* version_string, hmr_version_t* version);
bool hmr_version_validate(const hmr_version_t* version);

// Compatibility checking
int32_t hmr_version_check_compatibility(const hmr_version_t* required,
                                        const hmr_version_t* available,
                                        hmr_version_compat_result_t* result);
bool hmr_version_is_compatible(const hmr_version_t* required,
                               const hmr_version_t* available);
bool hmr_version_is_newer(const hmr_version_t* v1, const hmr_version_t* v2);
bool hmr_version_satisfies_range(const hmr_version_t* version,
                                 const hmr_version_t* min_version,
                                 const hmr_version_t* max_version);

// Migration system
int32_t hmr_version_migrate(const hmr_version_t* from_version,
                           const hmr_version_t* to_version,
                           void* module_data,
                           hmr_migration_context_t* migration_context);
hmr_migration_strategy_t hmr_determine_migration_strategy(const hmr_version_t* from,
                                                         const hmr_version_t* to);
int32_t hmr_execute_migration(hmr_migration_context_t* context);
bool hmr_can_migrate(const hmr_version_t* from, const hmr_version_t* to);

// Rollback system
hmr_rollback_handle_t* hmr_save_rollback_state(const hmr_version_t* version,
                                               void* module_data);
int32_t hmr_restore_rollback_state(hmr_rollback_handle_t* handle);
int32_t hmr_version_rollback(hmr_rollback_handle_t* handle);
void hmr_cleanup_rollback_state(hmr_rollback_handle_t* handle);
int32_t hmr_list_rollback_points(hmr_rollback_handle_t** handles, uint32_t max_count);

// Version registry
int32_t hmr_version_registry_init(void);
void hmr_version_registry_shutdown(void);
int32_t hmr_register_version(const char* module_name, const hmr_version_t* version,
                            const char* file_path);
int32_t hmr_unregister_version(const char* module_name, const hmr_version_t* version);
hmr_version_t* hmr_find_latest_version(const char* module_name);
int32_t hmr_list_versions(const char* module_name, hmr_version_t** versions,
                         uint32_t max_count);

// Advanced version queries
hmr_version_t* hmr_find_compatible_version(const char* module_name,
                                          const hmr_version_t* required);
hmr_version_t* hmr_find_best_version(const char* module_name,
                                    hmr_version_flags_t preferred_flags);
int32_t hmr_get_version_history(const char* module_name,
                               hmr_version_t** versions,
                               uint32_t max_count);

// Utility functions
uint64_t hmr_version_hash(const hmr_version_t* version);
bool hmr_version_has_flag(const hmr_version_t* version, hmr_version_flags_t flag);
void hmr_version_set_flag(hmr_version_t* version, hmr_version_flags_t flag);
void hmr_version_clear_flag(hmr_version_t* version, hmr_version_flags_t flag);
const char* hmr_version_flag_string(hmr_version_flags_t flags);

// Performance monitoring
typedef struct {
    uint64_t total_version_checks;      // Total compatibility checks
    uint64_t successful_migrations;     // Successful migrations
    uint64_t failed_migrations;         // Failed migrations
    uint64_t rollbacks_performed;       // Rollbacks performed
    uint64_t avg_check_time_ns;         // Average check time
    uint64_t avg_migration_time_ns;     // Average migration time
    uint64_t registry_size;             // Current registry size
    uint64_t memory_usage;              // Memory usage in bytes
} hmr_version_metrics_t;

void hmr_version_get_metrics(hmr_version_metrics_t* metrics);
void hmr_version_reset_metrics(void);

// Version constraints for dependency resolution
typedef struct {
    char constraint_string[128];        // Constraint expression (e.g., ">=1.2.0 <2.0.0")
    hmr_version_t min_version;          // Minimum acceptable version
    hmr_version_t max_version;          // Maximum acceptable version
    hmr_version_flags_t required_flags; // Required version flags
    hmr_version_flags_t excluded_flags; // Excluded version flags
    bool allow_prerelease;              // Allow pre-release versions
    bool strict_mode;                   // Strict compatibility checking
} hmr_version_constraint_t;

// Constraint parsing and evaluation
bool hmr_parse_version_constraint(const char* constraint_string,
                                 hmr_version_constraint_t* constraint);
bool hmr_version_satisfies_constraint(const hmr_version_t* version,
                                     const hmr_version_constraint_t* constraint);
char* hmr_constraint_to_string(const hmr_version_constraint_t* constraint);

#ifdef __cplusplus
}
#endif

// Constants and limits
#define HMR_VERSION_STRING_MAX      64      // Maximum version string length
#define HMR_MAX_ROLLBACK_STATES     32      // Maximum rollback states to keep
#define HMR_MAX_VERSION_HISTORY     128     // Maximum version history per module
#define HMR_MIGRATION_TIMEOUT_MS    30000   // Default migration timeout (30s)
#define HMR_VERSION_CACHE_SIZE      256     // Version cache size

// Macros for version creation and comparison
#define HMR_VERSION_MAKE(maj, min, pat) \
    ((uint32_t)((maj) << 16) | ((min) << 8) | (pat))
#define HMR_VERSION_MAJOR(v) (((v) >> 16) & 0xFF)
#define HMR_VERSION_MINOR(v) (((v) >> 8) & 0xFF)
#define HMR_VERSION_PATCH(v) ((v) & 0xFF)

#define HMR_VERSION_IS_STABLE(v) \
    (((v)->flags & HMR_VERSION_STABLE) != 0)
#define HMR_VERSION_IS_PRERELEASE(v) \
    (((v)->flags & (HMR_VERSION_ALPHA | HMR_VERSION_BETA | HMR_VERSION_PRERELEASE)) != 0)
#define HMR_VERSION_HAS_BREAKING_CHANGES(v) \
    (((v)->flags & HMR_VERSION_BREAKING) != 0)

// Error handling for version operations
#define HMR_VERSION_SUCCESS             0
#define HMR_VERSION_ERROR_INVALID      -1
#define HMR_VERSION_ERROR_INCOMPATIBLE -2
#define HMR_VERSION_ERROR_MIGRATION    -3
#define HMR_VERSION_ERROR_ROLLBACK     -4
#define HMR_VERSION_ERROR_REGISTRY     -5
#define HMR_VERSION_ERROR_MEMORY       -6
#define HMR_VERSION_ERROR_TIMEOUT      -7
#define HMR_VERSION_ERROR_NOT_FOUND    -8
#define HMR_VERSION_ERROR_ALREADY_EXISTS -9
#define HMR_VERSION_ERROR_CONSTRAINT   -10

#endif // HMR_MODULE_VERSIONING_H