/*
 * SimCity ARM64 - Asset Security System
 * Enterprise-grade asset encryption and access control
 * 
 * Created by Agent 5: Asset Pipeline & Advanced Features - Week 3 Day 11
 * Comprehensive security features with encryption and role-based access control
 */

#ifndef HMR_ASSET_SECURITY_H
#define HMR_ASSET_SECURITY_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <time.h>

// Security levels for asset classification
typedef enum {
    SECURITY_LEVEL_PUBLIC = 0,      // Public assets, no restrictions
    SECURITY_LEVEL_INTERNAL,        // Internal use only
    SECURITY_LEVEL_CONFIDENTIAL,    // Confidential, restricted access
    SECURITY_LEVEL_SECRET,          // Secret, highly restricted
    SECURITY_LEVEL_TOP_SECRET       // Top secret, maximum security
} asset_security_level_t;

// Encryption algorithms supported
typedef enum {
    ENCRYPT_NONE = 0,               // No encryption
    ENCRYPT_AES_128_GCM,            // AES-128-GCM
    ENCRYPT_AES_256_GCM,            // AES-256-GCM
    ENCRYPT_CHACHA20_POLY1305,      // ChaCha20-Poly1305
    ENCRYPT_AES_128_CTR,            // AES-128-CTR
    ENCRYPT_AES_256_CTR,            // AES-256-CTR
    ENCRYPT_SALSA20,                // Salsa20
    ENCRYPT_XCHACHA20_POLY1305      // XChaCha20-Poly1305
} encryption_algorithm_t;

// Key derivation functions
typedef enum {
    KDF_PBKDF2_SHA256 = 0,          // PBKDF2 with SHA-256
    KDF_PBKDF2_SHA512,              // PBKDF2 with SHA-512
    KDF_SCRYPT,                     // scrypt
    KDF_ARGON2ID,                   // Argon2id
    KDF_HKDF_SHA256,                // HKDF with SHA-256
    KDF_BCRYPT                      // bcrypt
} key_derivation_function_t;

// Access permission flags
typedef enum {
    ASSET_PERM_NONE         = 0x0000,   // No permissions
    ASSET_PERM_READ         = 0x0001,   // Read asset
    ASSET_PERM_WRITE        = 0x0002,   // Modify asset
    ASSET_PERM_DELETE       = 0x0004,   // Delete asset
    ASSET_PERM_EXECUTE      = 0x0008,   // Execute/use asset
    ASSET_PERM_SHARE        = 0x0010,   // Share with others
    ASSET_PERM_EXPORT       = 0x0020,   // Export from system
    ASSET_PERM_DECRYPT      = 0x0040,   // Decrypt encrypted assets
    ASSET_PERM_ADMIN        = 0x0080,   // Administrative access
    ASSET_PERM_AUDIT        = 0x0100,   // View audit logs
    ASSET_PERM_BACKUP       = 0x0200,   // Create backups
    ASSET_PERM_RESTORE      = 0x0400,   // Restore from backups
    ASSET_PERM_METADATA     = 0x0800,   // Edit metadata
    ASSET_PERM_SECURITY     = 0x1000    // Modify security settings
} asset_permission_t;

// User authentication methods
typedef enum {
    AUTH_METHOD_NONE = 0,           // No authentication
    AUTH_METHOD_PASSWORD,           // Password-based
    AUTH_METHOD_KEY_FILE,           // Key file
    AUTH_METHOD_CERTIFICATE,        // X.509 certificate
    AUTH_METHOD_BIOMETRIC,          // Biometric (fingerprint, face)
    AUTH_METHOD_TOKEN,              // Hardware token
    AUTH_METHOD_SMART_CARD,         // Smart card
    AUTH_METHOD_MULTI_FACTOR        // Multi-factor authentication
} auth_method_t;

// Security audit event types
typedef enum {
    AUDIT_EVENT_LOGIN = 0,          // User login
    AUDIT_EVENT_LOGOUT,             // User logout
    AUDIT_EVENT_ACCESS_GRANTED,     // Access granted
    AUDIT_EVENT_ACCESS_DENIED,      // Access denied
    AUDIT_EVENT_ASSET_DECRYPTED,    // Asset decrypted
    AUDIT_EVENT_ASSET_ENCRYPTED,    // Asset encrypted
    AUDIT_EVENT_PERMISSION_CHANGED, // Permission changed
    AUDIT_EVENT_KEY_GENERATED,      // Encryption key generated
    AUDIT_EVENT_KEY_ROTATED,        // Key rotated
    AUDIT_EVENT_SECURITY_VIOLATION, // Security violation
    AUDIT_EVENT_BACKUP_CREATED,     // Backup created
    AUDIT_EVENT_BACKUP_RESTORED,    // Backup restored
    AUDIT_EVENT_EXPORT_ATTEMPTED,   // Export attempted
    AUDIT_EVENT_ADMIN_ACTION        // Administrative action
} security_audit_event_t;

// Encryption key information
typedef struct {
    char key_id[64];                // Unique key identifier
    encryption_algorithm_t algorithm; // Encryption algorithm
    uint32_t key_size_bits;         // Key size in bits
    uint8_t key_data[64];           // Encrypted key data
    uint32_t key_data_size;         // Size of key data
    char salt[32];                  // Salt for key derivation
    uint32_t salt_size;             // Salt size
    key_derivation_function_t kdf;  // Key derivation function
    uint32_t iterations;            // KDF iterations
    uint64_t created_time;          // Key creation time
    uint64_t last_used;             // Last usage time
    uint64_t expiry_time;           // Key expiry time
    bool is_active;                 // Whether key is active
    char created_by[128];           // Who created the key
    uint32_t usage_count;           // Number of times used
} encryption_key_t;

// User security profile
typedef struct {
    char user_id[64];               // Unique user identifier
    char username[128];             // Username
    char display_name[256];         // Display name
    char email[256];                // Email address
    auth_method_t auth_method;      // Authentication method
    char password_hash[128];        // Hashed password
    char salt[32];                  // Password salt
    uint32_t permissions;           // Permission flags
    asset_security_level_t clearance; // Security clearance level
    bool is_active;                 // Whether account is active
    bool is_locked;                 // Whether account is locked
    uint64_t created_time;          // Account creation time
    uint64_t last_login;            // Last login time
    uint64_t last_activity;         // Last activity time
    uint32_t failed_login_attempts; // Failed login attempts
    uint64_t lockout_time;          // Account lockout time
    char certificate_thumbprint[128]; // Certificate thumbprint
    char public_key[512];           // Public key (for key-based auth)
    char mfa_secret[64];            // Multi-factor auth secret
    bool mfa_enabled;               // Whether MFA is enabled
    char session_tokens[10][64];    // Active session tokens
    uint32_t active_sessions;       // Number of active sessions
} security_user_t;

// Asset security metadata
typedef struct {
    char asset_path[512];           // Path to asset
    asset_security_level_t level;  // Security classification
    encryption_algorithm_t encryption; // Encryption algorithm
    char key_id[64];                // Encryption key ID
    uint8_t iv[16];                 // Initialization vector
    uint32_t iv_size;               // IV size
    char checksum[64];              // Asset integrity checksum
    char signature[256];            // Digital signature
    uint64_t encrypted_time;        // When asset was encrypted
    char encrypted_by[128];         // Who encrypted the asset
    uint32_t access_count;          // Number of accesses
    uint64_t last_access;           // Last access time
    char last_accessed_by[128];     // Who last accessed
    bool is_quarantined;            // Whether asset is quarantined
    char quarantine_reason[256];    // Quarantine reason
    uint32_t required_permissions;  // Required permissions
    char owner_id[64];              // Asset owner
    char backup_location[512];      // Secure backup location
    bool is_backed_up;              // Whether asset is backed up
} asset_security_metadata_t;

// Security policy rule
typedef struct {
    char rule_id[64];               // Unique rule identifier
    char name[128];                 // Rule name
    char description[512];          // Rule description
    bool is_active;                 // Whether rule is active
    uint32_t priority;              // Rule priority
    char asset_pattern[256];        // Asset path pattern
    asset_security_level_t min_level; // Minimum security level
    encryption_algorithm_t required_encryption; // Required encryption
    uint32_t required_permissions;  // Required permissions
    uint32_t max_access_count;      // Maximum access count
    uint64_t access_time_limit;     // Access time limit (seconds)
    bool require_mfa;               // Require multi-factor auth
    bool require_audit;             // Require audit logging
    char allowed_users[32][64];     // Allowed user IDs
    uint32_t allowed_user_count;    // Number of allowed users
    char restricted_locations[16][256]; // Restricted locations
    uint32_t restricted_location_count; // Number of restricted locations
    uint64_t effective_start;       // Rule effective start time
    uint64_t effective_end;         // Rule effective end time
} security_policy_rule_t;

// Security audit entry
typedef struct {
    char audit_id[64];              // Unique audit identifier
    uint64_t timestamp;             // Audit timestamp
    security_audit_event_t event;   // Event type
    char user_id[64];               // User ID
    char asset_path[512];           // Asset path (if applicable)
    char source_ip[64];             // Source IP address
    char user_agent[256];           // User agent string
    char session_id[64];            // Session identifier
    bool success;                   // Whether operation succeeded
    char error_message[256];        // Error message (if failed)
    char additional_data[1024];     // Additional event data
    uint32_t risk_score;            // Risk score (0-100)
    bool is_anomaly;                // Whether event is anomalous
    char geolocation[128];          // Geolocation data
    char device_fingerprint[128];   // Device fingerprint
} security_audit_entry_t;

// Security session information
typedef struct {
    char session_id[64];            // Unique session identifier
    char user_id[64];               // User ID
    uint64_t created_time;          // Session creation time
    uint64_t last_activity;         // Last activity time
    uint64_t expires_time;          // Session expiration time
    char source_ip[64];             // Source IP address
    char user_agent[256];           // User agent
    bool is_active;                 // Whether session is active
    bool is_elevated;               // Whether session has elevated privileges
    uint32_t access_count;          // Number of asset accesses
    char last_asset_accessed[512];  // Last asset accessed
    uint32_t permissions;           // Session permissions
    bool mfa_verified;              // Whether MFA was verified
    char geolocation[128];          // Session geolocation
    char device_id[128];            // Device identifier
} security_session_t;

// Security manager
typedef struct {
    char database_path[512];        // Security database path
    char key_store_path[512];       // Key store path
    
    encryption_key_t* keys;         // Encryption keys
    uint32_t key_count;             // Number of keys
    uint32_t max_keys;              // Maximum keys
    
    security_user_t* users;         // User accounts
    uint32_t user_count;            // Number of users
    uint32_t max_users;             // Maximum users
    
    asset_security_metadata_t* assets; // Asset security metadata
    uint32_t asset_count;           // Number of secured assets
    uint32_t max_assets;            // Maximum secured assets
    
    security_policy_rule_t* policies; // Security policies
    uint32_t policy_count;          // Number of policies
    uint32_t max_policies;          // Maximum policies
    
    security_audit_entry_t* audit_log; // Security audit log
    uint32_t audit_count;           // Number of audit entries
    uint32_t max_audit_entries;     // Maximum audit entries
    
    security_session_t* sessions;   // Active sessions
    uint32_t session_count;         // Number of active sessions
    uint32_t max_sessions;          // Maximum sessions
    
    bool encryption_enabled;        // Whether encryption is enabled
    encryption_algorithm_t default_algorithm; // Default encryption algorithm
    uint32_t key_rotation_interval; // Key rotation interval (days)
    uint32_t session_timeout;       // Session timeout (seconds)
    uint32_t max_failed_logins;     // Maximum failed login attempts
    uint32_t lockout_duration;      // Account lockout duration (seconds)
    
    pthread_mutex_t mutex;          // Synchronization mutex
    pthread_t cleanup_thread;       // Cleanup thread
    bool is_running;                // Whether manager is running
} security_manager_t;

// API Functions - Security Management
#ifdef __cplusplus
extern "C" {
#endif

// Manager initialization
int32_t security_manager_init(security_manager_t** manager, 
                             const char* database_path,
                             const char* key_store_path);
void security_manager_shutdown(security_manager_t* manager);
int32_t security_manager_load_database(security_manager_t* manager);
int32_t security_manager_save_database(security_manager_t* manager);

// User management
int32_t security_create_user(security_manager_t* manager,
                            const char* username,
                            const char* password,
                            const char* email,
                            uint32_t permissions,
                            asset_security_level_t clearance);
int32_t security_authenticate_user(security_manager_t* manager,
                                  const char* username,
                                  const char* password,
                                  const char* mfa_token,
                                  security_session_t** session);
int32_t security_logout_user(security_manager_t* manager, const char* session_id);
int32_t security_change_password(security_manager_t* manager,
                                const char* user_id,
                                const char* old_password,
                                const char* new_password);
int32_t security_lock_user_account(security_manager_t* manager, const char* user_id);
int32_t security_unlock_user_account(security_manager_t* manager, const char* user_id);

// Session management
int32_t security_validate_session(security_manager_t* manager, const char* session_id);
int32_t security_extend_session(security_manager_t* manager, const char* session_id);
int32_t security_elevate_session(security_manager_t* manager,
                                const char* session_id,
                                const char* password);
int32_t security_get_session_info(security_manager_t* manager,
                                 const char* session_id,
                                 security_session_t* session);

// Asset encryption
int32_t security_encrypt_asset(security_manager_t* manager,
                              const char* asset_path,
                              const char* user_id,
                              encryption_algorithm_t algorithm,
                              asset_security_level_t level);
int32_t security_decrypt_asset(security_manager_t* manager,
                              const char* asset_path,
                              const char* session_id,
                              uint8_t** decrypted_data,
                              size_t* data_size);
int32_t security_verify_asset_integrity(security_manager_t* manager, const char* asset_path);
int32_t security_sign_asset(security_manager_t* manager,
                           const char* asset_path,
                           const char* user_id);

// Access control
int32_t security_check_asset_access(security_manager_t* manager,
                                   const char* asset_path,
                                   const char* session_id,
                                   asset_permission_t permission);
int32_t security_grant_asset_access(security_manager_t* manager,
                                   const char* asset_path,
                                   const char* user_id,
                                   uint32_t permissions);
int32_t security_revoke_asset_access(security_manager_t* manager,
                                    const char* asset_path,
                                    const char* user_id);
int32_t security_quarantine_asset(security_manager_t* manager,
                                 const char* asset_path,
                                 const char* reason);
int32_t security_unquarantine_asset(security_manager_t* manager, const char* asset_path);

// Key management
int32_t security_generate_key(security_manager_t* manager,
                             encryption_algorithm_t algorithm,
                             const char* user_id,
                             encryption_key_t** key);
int32_t security_rotate_keys(security_manager_t* manager);
int32_t security_backup_keys(security_manager_t* manager, const char* backup_path);
int32_t security_restore_keys(security_manager_t* manager, const char* backup_path);
int32_t security_destroy_key(security_manager_t* manager, const char* key_id);

// Policy management
int32_t security_add_policy(security_manager_t* manager, const security_policy_rule_t* policy);
int32_t security_remove_policy(security_manager_t* manager, const char* policy_id);
int32_t security_update_policy(security_manager_t* manager,
                              const char* policy_id,
                              const security_policy_rule_t* policy);
int32_t security_evaluate_policies(security_manager_t* manager,
                                  const char* asset_path,
                                  const char* user_id);

// Audit and monitoring
int32_t security_log_audit_event(security_manager_t* manager,
                                 security_audit_event_t event,
                                 const char* user_id,
                                 const char* asset_path,
                                 bool success,
                                 const char* details);
int32_t security_get_audit_log(security_manager_t* manager,
                              uint64_t start_time,
                              uint64_t end_time,
                              security_audit_entry_t* entries,
                              uint32_t max_entries);
int32_t security_detect_anomalies(security_manager_t* manager,
                                 const char* user_id,
                                 bool* anomaly_detected);
int32_t security_generate_security_report(security_manager_t* manager,
                                         char* report,
                                         size_t report_size);

// Utility functions
const char* security_get_level_name(asset_security_level_t level);
const char* security_get_algorithm_name(encryption_algorithm_t algorithm);
const char* security_get_audit_event_name(security_audit_event_t event);
bool security_has_permission(uint32_t user_permissions, asset_permission_t permission);
uint32_t security_calculate_risk_score(const security_audit_entry_t* entry);

// Performance monitoring
typedef struct {
    uint64_t total_authentications;     // Total authentication attempts
    uint64_t successful_authentications; // Successful authentications
    uint64_t failed_authentications;    // Failed authentications
    uint64_t total_encryptions;         // Total encryptions performed
    uint64_t total_decryptions;         // Total decryptions performed
    uint64_t access_checks_performed;   // Access checks performed
    uint64_t access_denied_count;       // Access denied count
    uint64_t policy_violations;         // Policy violations detected
    uint64_t security_incidents;        // Security incidents
    uint64_t avg_encryption_time_ms;    // Average encryption time
    uint64_t avg_decryption_time_ms;    // Average decryption time
    uint64_t avg_access_check_time_ms;  // Average access check time
    uint32_t active_sessions;           // Currently active sessions
    uint32_t encrypted_assets;          // Number of encrypted assets
} security_metrics_t;

void security_get_metrics(security_manager_t* manager, security_metrics_t* metrics);
void security_reset_metrics(security_manager_t* manager);

#ifdef __cplusplus
}
#endif

// Constants and configuration
#define SECURITY_MAX_USERS              1000
#define SECURITY_MAX_ASSETS             100000
#define SECURITY_MAX_KEYS               1000
#define SECURITY_MAX_POLICIES           100
#define SECURITY_MAX_AUDIT_ENTRIES      1000000
#define SECURITY_MAX_SESSIONS           500
#define SECURITY_DEFAULT_SESSION_TIMEOUT 3600    // 1 hour
#define SECURITY_DEFAULT_KEY_SIZE       256      // 256-bit keys
#define SECURITY_DEFAULT_KDF_ITERATIONS 100000   // PBKDF2 iterations
#define SECURITY_MAX_FAILED_LOGINS      5        // Max failed attempts
#define SECURITY_LOCKOUT_DURATION       1800     // 30 minutes
#define SECURITY_KEY_ROTATION_DAYS      90       // 90 days
#define SECURITY_SESSION_CLEANUP_INTERVAL 300   // 5 minutes

// Error codes
#define SECURITY_SUCCESS                0
#define SECURITY_ERROR_INVALID_INPUT    -1
#define SECURITY_ERROR_ACCESS_DENIED    -2
#define SECURITY_ERROR_USER_NOT_FOUND   -3
#define SECURITY_ERROR_INVALID_SESSION  -4
#define SECURITY_ERROR_ENCRYPTION_FAILED -5
#define SECURITY_ERROR_DECRYPTION_FAILED -6
#define SECURITY_ERROR_KEY_NOT_FOUND    -7
#define SECURITY_ERROR_POLICY_VIOLATION -8
#define SECURITY_ERROR_ACCOUNT_LOCKED   -9
#define SECURITY_ERROR_WEAK_PASSWORD    -10
#define SECURITY_ERROR_EXPIRED_SESSION  -11
#define SECURITY_ERROR_MFA_REQUIRED     -12
#define SECURITY_ERROR_INSUFFICIENT_CLEARANCE -13
#define SECURITY_ERROR_QUARANTINED      -14
#define SECURITY_ERROR_DATABASE         -15

// Permission combinations
#define SECURITY_ADMIN_PERMISSIONS  (ASSET_PERM_READ | ASSET_PERM_WRITE | ASSET_PERM_DELETE | \
                                     ASSET_PERM_EXECUTE | ASSET_PERM_SHARE | ASSET_PERM_EXPORT | \
                                     ASSET_PERM_DECRYPT | ASSET_PERM_ADMIN | ASSET_PERM_AUDIT | \
                                     ASSET_PERM_BACKUP | ASSET_PERM_RESTORE | ASSET_PERM_METADATA | \
                                     ASSET_PERM_SECURITY)
#define SECURITY_USER_PERMISSIONS   (ASSET_PERM_READ | ASSET_PERM_WRITE | ASSET_PERM_EXECUTE | \
                                     ASSET_PERM_DECRYPT | ASSET_PERM_METADATA)
#define SECURITY_VIEWER_PERMISSIONS (ASSET_PERM_READ | ASSET_PERM_EXECUTE)

#endif // HMR_ASSET_SECURITY_H