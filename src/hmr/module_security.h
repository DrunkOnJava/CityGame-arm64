/*
 * SimCity ARM64 - HMR Module Security
 * Enterprise-grade security features for production deployment
 * 
 * Created by Agent 1: Core Module System - Week 3, Day 11
 * Version: 1.2.0
 */

#ifndef HMR_MODULE_SECURITY_H
#define HMR_MODULE_SECURITY_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <sys/time.h>
#include "module_interface.h"

// Security configuration constants
#define HMR_SIGNATURE_SIZE           256     // RSA-2048 signature size
#define HMR_HASH_SIZE                32      // SHA-256 hash size
#define HMR_CERT_SIZE                2048    // Maximum certificate size
#define HMR_MAX_SYSCALLS             64      // Maximum allowed syscalls per sandbox
#define HMR_MAX_AUDIT_ENTRIES        10000   // Maximum audit log entries
#define HMR_SANDBOX_STACK_SIZE       (1024 * 1024)  // 1MB stack per sandbox

// Security levels
typedef enum {
    HMR_SECURITY_LEVEL_NONE = 0,        // No security (development only)
    HMR_SECURITY_LEVEL_BASIC,           // Basic validation
    HMR_SECURITY_LEVEL_STANDARD,        // Standard enterprise security
    HMR_SECURITY_LEVEL_HIGH,            // High security with full sandboxing
    HMR_SECURITY_LEVEL_CRITICAL         // Critical systems (government/financial)
} hmr_security_level_t;

// Code signature structure
typedef struct {
    uint8_t signature[HMR_SIGNATURE_SIZE];  // RSA-2048 signature
    uint8_t hash[HMR_HASH_SIZE];            // SHA-256 hash of module
    uint32_t cert_size;                     // Size of certificate data
    uint8_t certificate[HMR_CERT_SIZE];     // X.509 certificate
    uint64_t timestamp;                     // Signing timestamp
    uint32_t flags;                         // Signature flags
    char signer_id[64];                     // Signer identification
} hmr_code_signature_t;

// Resource limits structure
typedef struct {
    // Memory limits
    size_t max_heap_size;                   // Maximum heap allocation
    size_t max_stack_size;                  // Maximum stack size
    size_t max_total_memory;                // Maximum total memory usage
    
    // CPU limits
    uint32_t max_cpu_percent;               // Maximum CPU usage percentage
    uint64_t max_instructions_per_frame;    // Maximum instructions per frame
    uint32_t max_threads;                   // Maximum thread count
    
    // GPU limits (Apple Metal specific)
    size_t max_gpu_memory;                  // Maximum GPU memory
    uint32_t max_gpu_commands_per_frame;    // Maximum GPU commands per frame
    uint32_t max_compute_dispatches;        // Maximum compute dispatches
    
    // I/O limits
    size_t max_file_descriptors;            // Maximum open file descriptors
    size_t max_network_connections;         // Maximum network connections
    uint64_t max_disk_io_per_second;        // Maximum disk I/O per second
    
    // Time limits
    uint64_t max_frame_time_ns;             // Maximum frame processing time
    uint64_t max_init_time_ns;              // Maximum initialization time
} hmr_resource_limits_t;

// Sandbox configuration
typedef struct {
    // Allowed system calls (bitmap)
    uint64_t allowed_syscalls[HMR_MAX_SYSCALLS / 64];
    
    // File system access
    bool allow_file_read;                   // Allow file reading
    bool allow_file_write;                  // Allow file writing
    bool allow_file_create;                 // Allow file creation
    bool allow_directory_access;            // Allow directory operations
    
    // Network access
    bool allow_network_client;              // Allow outbound connections
    bool allow_network_server;              // Allow inbound connections
    bool allow_multicast;                   // Allow multicast operations
    
    // System access
    bool allow_process_creation;            // Allow process/thread creation
    bool allow_shared_memory;               // Allow shared memory access
    bool allow_kernel_modules;              // Allow kernel module loading
    bool allow_raw_sockets;                 // Allow raw socket access
    
    // Apple-specific restrictions
    bool allow_metal_access;                // Allow Metal GPU access
    bool allow_core_audio;                  // Allow Core Audio access
    bool allow_core_location;               // Allow Core Location access
    bool allow_keychain_access;             // Allow Keychain access
    
    // Resource isolation
    char chroot_path[256];                  // Chroot jail path (if applicable)
    uint32_t process_group_id;              // Process group for isolation
    uint32_t user_id;                       // User ID for privilege drop
    uint32_t group_id;                      // Group ID for privilege drop
} hmr_sandbox_config_t;

// Resource usage tracking
typedef struct {
    // Current usage
    size_t current_heap_size;
    size_t current_stack_size;
    size_t current_total_memory;
    uint32_t current_cpu_percent;
    uint32_t current_thread_count;
    size_t current_gpu_memory;
    size_t current_file_descriptors;
    size_t current_network_connections;
    
    // Peak usage
    size_t peak_heap_size;
    size_t peak_stack_size;
    size_t peak_total_memory;
    uint32_t peak_cpu_percent;
    uint32_t peak_thread_count;
    size_t peak_gpu_memory;
    
    // Violations
    uint32_t memory_violations;
    uint32_t cpu_violations;
    uint32_t gpu_violations;
    uint32_t io_violations;
    uint32_t time_violations;
    
    // Enforcement actions
    uint32_t warnings_issued;
    uint32_t throttling_events;
    uint32_t termination_events;
} hmr_resource_usage_t;

// Audit log entry types
typedef enum {
    HMR_AUDIT_MODULE_LOADED = 1,
    HMR_AUDIT_MODULE_UNLOADED,
    HMR_AUDIT_MODULE_VERIFIED,
    HMR_AUDIT_MODULE_REJECTED,
    HMR_AUDIT_SECURITY_VIOLATION,
    HMR_AUDIT_RESOURCE_VIOLATION,
    HMR_AUDIT_SANDBOX_VIOLATION,
    HMR_AUDIT_PRIVILEGE_ESCALATION,
    HMR_AUDIT_UNAUTHORIZED_ACCESS,
    HMR_AUDIT_PERFORMANCE_DEGRADATION,
    HMR_AUDIT_SYSTEM_INTEGRITY_CHECK,
    HMR_AUDIT_CERTIFICATE_VALIDATION
} hmr_audit_event_type_t;

// Audit log entry
typedef struct {
    uint64_t timestamp_ns;                  // Nanosecond timestamp
    hmr_audit_event_type_t event_type;      // Type of event
    uint32_t module_id;                     // Module identifier
    char module_name[32];                   // Module name
    uint32_t severity;                      // Severity level (0-4)
    char message[256];                      // Human-readable message
    char details[512];                      // Additional details
    uint32_t user_id;                       // User ID if applicable
    uint32_t process_id;                    // Process ID
    uint32_t thread_id;                     // Thread ID
    uint64_t memory_usage;                  // Memory usage at time of event
    uint32_t cpu_usage;                     // CPU usage at time of event
} hmr_audit_entry_t;

// Module security context
typedef struct {
    hmr_security_level_t security_level;   // Current security level
    hmr_code_signature_t signature;        // Code signature
    hmr_resource_limits_t limits;           // Resource limits
    hmr_sandbox_config_t sandbox;           // Sandbox configuration
    hmr_resource_usage_t usage;             // Resource usage tracking
    
    // Validation state
    bool signature_verified;                // Whether signature is valid
    bool certificate_valid;                 // Whether certificate is valid
    bool sandbox_active;                    // Whether sandbox is active
    uint64_t last_validation_ns;            // Last validation timestamp
    
    // Security tokens
    uint64_t security_token;                // Security token for this module
    uint64_t parent_token;                  // Parent security token
    uint32_t privilege_level;               // Current privilege level
    
    // Monitoring
    uint64_t last_resource_check_ns;        // Last resource usage check
    uint32_t security_violations;           // Total security violations
    uint32_t resource_violations;           // Total resource violations
} hmr_module_security_context_t;

// Global security configuration
typedef struct {
    hmr_security_level_t global_security_level;
    bool require_signatures;                // Whether signatures are required
    bool enforce_sandboxing;                // Whether sandboxing is enforced
    bool enforce_resource_limits;           // Whether resource limits are enforced
    bool enable_audit_logging;              // Whether audit logging is enabled
    
    // Certificate validation
    uint8_t trusted_ca_certs[10][HMR_CERT_SIZE];  // Trusted CA certificates
    uint32_t trusted_ca_count;              // Number of trusted CAs
    
    // Default limits
    hmr_resource_limits_t default_limits;   // Default resource limits
    hmr_sandbox_config_t default_sandbox;   // Default sandbox configuration
    
    // Audit configuration
    char audit_log_path[256];               // Path to audit log file
    uint32_t max_audit_entries;             // Maximum audit entries
    bool audit_to_syslog;                   // Whether to log to syslog
    
    // Performance
    uint64_t max_validation_time_ns;        // Maximum signature validation time
    uint32_t resource_check_interval_ms;    // Resource check interval
} hmr_global_security_config_t;

// API Functions
#ifdef __cplusplus
extern "C" {
#endif

// Security initialization
int32_t hmr_security_init(const hmr_global_security_config_t* config);
int32_t hmr_security_shutdown(void);

// Module signature verification
int32_t hmr_verify_module_signature(const char* module_path, hmr_code_signature_t* signature);
int32_t hmr_validate_certificate(const hmr_code_signature_t* signature);
int32_t hmr_check_code_integrity(const void* code, size_t code_size, const hmr_code_signature_t* signature);

// Sandbox management
int32_t hmr_create_sandbox(hmr_agent_module_t* module, const hmr_sandbox_config_t* config);
int32_t hmr_destroy_sandbox(hmr_agent_module_t* module);
int32_t hmr_enter_sandbox(hmr_agent_module_t* module);
int32_t hmr_exit_sandbox(hmr_agent_module_t* module);
bool hmr_is_syscall_allowed(hmr_agent_module_t* module, uint32_t syscall_number);

// Resource management
int32_t hmr_set_resource_limits(hmr_agent_module_t* module, const hmr_resource_limits_t* limits);
int32_t hmr_check_resource_usage(hmr_agent_module_t* module);
int32_t hmr_enforce_resource_limits(hmr_agent_module_t* module);
void hmr_update_resource_usage(hmr_agent_module_t* module);

// Audit logging
int32_t hmr_audit_log(hmr_audit_event_type_t event_type, hmr_agent_module_t* module, 
                      uint32_t severity, const char* message, const char* details);
int32_t hmr_audit_flush(void);
int32_t hmr_audit_rotate_log(void);
const hmr_audit_entry_t* hmr_audit_get_entries(uint32_t* count);

// Security monitoring
int32_t hmr_security_monitor_start(void);
int32_t hmr_security_monitor_stop(void);
void hmr_security_monitor_update(void);

// Privilege management
int32_t hmr_drop_privileges(hmr_agent_module_t* module);
int32_t hmr_escalate_privileges(hmr_agent_module_t* module, uint64_t security_token);
bool hmr_check_privilege_level(hmr_agent_module_t* module, uint32_t required_level);

// Integrity checking
int32_t hmr_verify_system_integrity(void);
int32_t hmr_verify_module_integrity(hmr_agent_module_t* module);
uint64_t hmr_compute_module_hash(const void* code, size_t code_size);

// Apple-specific security
int32_t hmr_enable_app_sandbox(hmr_agent_module_t* module);
int32_t hmr_configure_metal_security(hmr_agent_module_t* module, bool allow_gpu_access);
int32_t hmr_configure_coreaudio_security(hmr_agent_module_t* module, bool allow_audio_access);

#ifdef __cplusplus
}
#endif

// Security error codes
#define HMR_SECURITY_SUCCESS                0
#define HMR_SECURITY_ERROR_INVALID_SIGNATURE -100
#define HMR_SECURITY_ERROR_INVALID_CERTIFICATE -101
#define HMR_SECURITY_ERROR_UNTRUSTED_CA     -102
#define HMR_SECURITY_ERROR_EXPIRED_CERT     -103
#define HMR_SECURITY_ERROR_REVOKED_CERT     -104
#define HMR_SECURITY_ERROR_SANDBOX_VIOLATION -105
#define HMR_SECURITY_ERROR_RESOURCE_VIOLATION -106
#define HMR_SECURITY_ERROR_PRIVILEGE_VIOLATION -107
#define HMR_SECURITY_ERROR_INTEGRITY_VIOLATION -108
#define HMR_SECURITY_ERROR_AUDIT_FAILURE    -109
#define HMR_SECURITY_ERROR_CRYPTO_FAILURE   -110

#endif // HMR_MODULE_SECURITY_H