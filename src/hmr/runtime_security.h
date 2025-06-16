/*
 * SimCity ARM64 - Enterprise Runtime Security
 * Agent 3: Runtime Integration - Day 11 Implementation
 * 
 * Comprehensive runtime security features with sandboxing and capability-based access control
 * Enterprise-grade security for production deployment with audit logging
 * Performance target: <50μs security validation overhead per operation
 */

#ifndef HMR_RUNTIME_SECURITY_H
#define HMR_RUNTIME_SECURITY_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// =============================================================================
// Security Constants and Limits
// =============================================================================

#define HMR_SEC_MAX_MODULES           32          // Maximum secured modules
#define HMR_SEC_MAX_CAPABILITIES      64          // Maximum capabilities per module
#define HMR_SEC_MAX_SANDBOX_SIZE      (1024*1024) // 1MB sandbox memory limit
#define HMR_SEC_AUDIT_BUFFER_SIZE     4096        // Audit log buffer size
#define HMR_SEC_MAX_VIOLATIONS        16          // Max violations before lockdown
#define HMR_SEC_VALIDATION_TIMEOUT_NS 50000ULL    // 50μs validation timeout

// Security levels
typedef enum {
    HMR_SEC_LEVEL_NONE        = 0,    // No security (development only)
    HMR_SEC_LEVEL_BASIC       = 1,    // Basic validation and logging
    HMR_SEC_LEVEL_STANDARD    = 2,    // Standard enterprise security
    HMR_SEC_LEVEL_HIGH        = 3,    // High security with full sandboxing
    HMR_SEC_LEVEL_CRITICAL    = 4     // Critical security with isolation
} hmr_security_level_t;

// Capability types for fine-grained access control
typedef enum {
    HMR_CAP_MODULE_LOAD       = 0x0001,   // Load new modules
    HMR_CAP_MODULE_UNLOAD     = 0x0002,   // Unload modules
    HMR_CAP_STATE_READ        = 0x0004,   // Read module state
    HMR_CAP_STATE_WRITE       = 0x0008,   // Write module state
    HMR_CAP_MEMORY_ALLOC      = 0x0010,   // Allocate memory
    HMR_CAP_MEMORY_FREE       = 0x0020,   // Free memory
    HMR_CAP_FILE_READ         = 0x0040,   // Read files
    HMR_CAP_FILE_WRITE        = 0x0080,   // Write files
    HMR_CAP_NETWORK_ACCESS    = 0x0100,   // Network operations
    HMR_CAP_SYSCALL_ACCESS    = 0x0200,   // System call access
    HMR_CAP_DEBUG_ACCESS      = 0x0400,   // Debugging operations
    HMR_CAP_ADMIN_ACCESS      = 0x0800,   // Administrative functions
    HMR_CAP_ALL               = 0xFFFF    // All capabilities (admin only)
} hmr_capability_t;

// Security violation types
typedef enum {
    HMR_VIOLATION_NONE             = 0,
    HMR_VIOLATION_CAPABILITY       = 1,    // Insufficient capabilities
    HMR_VIOLATION_SANDBOX_BREACH   = 2,    // Sandbox boundary violation
    HMR_VIOLATION_MEMORY_OVERFLOW  = 3,    // Memory limit exceeded
    HMR_VIOLATION_TIMEOUT          = 4,    // Operation timeout
    HMR_VIOLATION_INVALID_ACCESS   = 5,    // Invalid memory access
    HMR_VIOLATION_CORRUPTION       = 6,    // Data corruption detected
    HMR_VIOLATION_MALWARE          = 7     // Potential malware detected
} hmr_violation_type_t;

// =============================================================================
// Security Error Codes
// =============================================================================

#define HMR_SEC_SUCCESS                    0
#define HMR_SEC_ERROR_NULL_POINTER        -1
#define HMR_SEC_ERROR_INVALID_ARG         -2
#define HMR_SEC_ERROR_NOT_FOUND           -3
#define HMR_SEC_ERROR_ACCESS_DENIED       -10
#define HMR_SEC_ERROR_CAPABILITY_MISSING  -11
#define HMR_SEC_ERROR_SANDBOX_VIOLATION   -12
#define HMR_SEC_ERROR_MEMORY_LIMIT        -13
#define HMR_SEC_ERROR_VALIDATION_FAILED   -14
#define HMR_SEC_ERROR_SECURITY_LOCKDOWN   -15
#define HMR_SEC_ERROR_MALWARE_DETECTED    -16

// =============================================================================
// Security Data Structures
// =============================================================================

// Security context for a module
typedef struct {
    uint32_t module_id;                     // Module identifier
    char module_name[64];                   // Module name for auditing
    hmr_security_level_t security_level;   // Required security level
    uint32_t capabilities;                  // Capability bitmask
    uint64_t memory_limit;                  // Memory usage limit
    uint64_t memory_used;                   // Current memory usage
    void* sandbox_base;                     // Sandbox memory base
    uint64_t sandbox_size;                  // Sandbox memory size
    uint32_t violation_count;               // Security violations count
    uint64_t last_validation_time;          // Last security validation
    bool is_trusted;                        // Trusted module flag
    bool is_locked_down;                    // Security lockdown active
} hmr_security_context_t;

// Security violation record
typedef struct {
    uint32_t module_id;                     // Module that violated security
    hmr_violation_type_t violation_type;    // Type of violation
    uint64_t timestamp;                     // When violation occurred
    uint64_t violation_address;             // Memory address if applicable
    uint32_t operation_id;                  // Operation being performed
    char description[128];                  // Human-readable description
    uint32_t severity_level;                // Violation severity (1-10)
    bool auto_resolved;                     // Whether violation was auto-resolved
} hmr_security_violation_t;

// Security audit entry
typedef struct {
    uint64_t timestamp;                     // Audit timestamp
    uint32_t module_id;                     // Module involved
    uint32_t operation_type;                // Type of operation
    uint32_t capability_used;               // Capability exercised
    bool operation_allowed;                 // Whether operation was allowed
    uint64_t execution_time_ns;             // Time taken for operation
    char details[256];                      // Additional details
} hmr_security_audit_entry_t;

// Security statistics
typedef struct {
    uint64_t total_validations;             // Total security validations performed
    uint64_t access_denials;                // Total access denials
    uint64_t sandbox_violations;            // Sandbox boundary violations
    uint64_t capability_violations;         // Capability violations
    uint64_t memory_violations;             // Memory limit violations
    uint64_t malware_detections;            // Potential malware detections
    uint64_t avg_validation_time_ns;        // Average validation time
    uint64_t peak_validation_time_ns;       // Peak validation time
    uint32_t active_lockdowns;              // Number of modules locked down
    uint32_t trusted_modules;               // Number of trusted modules
} hmr_security_stats_t;

// Main security manager
typedef struct {
    hmr_security_level_t global_security_level;    // Global security level
    hmr_security_context_t contexts[HMR_SEC_MAX_MODULES]; // Module contexts
    uint32_t active_contexts;                       // Number of active contexts
    hmr_security_violation_t violation_history[64]; // Recent violations
    uint32_t violation_history_count;               // Number of violations in history
    hmr_security_audit_entry_t* audit_log;         // Circular audit log buffer
    uint32_t audit_log_size;                        // Size of audit log
    uint32_t audit_log_head;                        // Current audit log position
    hmr_security_stats_t stats;                     // Security statistics
    bool audit_enabled;                             // Whether audit logging is enabled
    bool real_time_monitoring;                      // Real-time monitoring enabled
    void* sandbox_pool;                             // Sandbox memory pool
    uint64_t sandbox_pool_size;                     // Total sandbox pool size
} hmr_security_manager_t;

// =============================================================================
// Core Security Functions
// =============================================================================

/**
 * Initialize the security manager
 * Sets up sandboxing, capability management, and audit logging
 * 
 * @param security_level Global security level to enforce
 * @param audit_enabled Whether to enable audit logging
 * @return HMR_SEC_SUCCESS on success, error code on failure
 */
int hmr_sec_init(hmr_security_level_t security_level, bool audit_enabled);

/**
 * Shutdown the security manager
 * Cleans up resources and finalizes audit logs
 * 
 * @return HMR_SEC_SUCCESS on success, error code on failure
 */
int hmr_sec_shutdown(void);

/**
 * Register a module with the security system
 * Establishes security context and capabilities
 * 
 * @param module_id Unique module identifier
 * @param module_name Human-readable module name
 * @param required_capabilities Bitmask of required capabilities
 * @param memory_limit Maximum memory usage for this module
 * @param is_trusted Whether this is a trusted module
 * @return HMR_SEC_SUCCESS on success, error code on failure
 */
int hmr_sec_register_module(uint32_t module_id, const char* module_name,
                           uint32_t required_capabilities, uint64_t memory_limit,
                           bool is_trusted);

/**
 * Unregister a module from security system
 * 
 * @param module_id Module to unregister
 * @return HMR_SEC_SUCCESS on success, error code on failure
 */
int hmr_sec_unregister_module(uint32_t module_id);

// =============================================================================
// Capability-Based Access Control
// =============================================================================

/**
 * Validate that a module has required capability for an operation
 * Fast capability checking with <50μs overhead
 * 
 * @param module_id Module requesting access
 * @param required_capability Capability required for operation
 * @param operation_description Description for audit logging
 * @return HMR_SEC_SUCCESS if allowed, HMR_SEC_ERROR_ACCESS_DENIED if denied
 */
int hmr_sec_validate_capability(uint32_t module_id, hmr_capability_t required_capability,
                               const char* operation_description);

/**
 * Grant additional capabilities to a module
 * 
 * @param module_id Module to grant capabilities to
 * @param additional_capabilities Capabilities to add
 * @return HMR_SEC_SUCCESS on success, error code on failure
 */
int hmr_sec_grant_capabilities(uint32_t module_id, uint32_t additional_capabilities);

/**
 * Revoke capabilities from a module
 * 
 * @param module_id Module to revoke capabilities from
 * @param capabilities_to_revoke Capabilities to remove
 * @return HMR_SEC_SUCCESS on success, error code on failure
 */
int hmr_sec_revoke_capabilities(uint32_t module_id, uint32_t capabilities_to_revoke);

/**
 * Check if a module has specific capabilities
 * 
 * @param module_id Module to check
 * @param capabilities Capabilities to check for
 * @return true if module has all capabilities, false otherwise
 */
bool hmr_sec_has_capabilities(uint32_t module_id, uint32_t capabilities);

// =============================================================================
// Sandboxing Functions
// =============================================================================

/**
 * Allocate sandboxed memory for a module
 * Memory is isolated and bounded within the module's limits
 * 
 * @param module_id Module requesting memory
 * @param size Size of memory to allocate
 * @param alignment Memory alignment requirement
 * @return Pointer to allocated memory, NULL on failure
 */
void* hmr_sec_sandbox_alloc(uint32_t module_id, size_t size, size_t alignment);

/**
 * Free sandboxed memory
 * 
 * @param module_id Module freeing memory
 * @param ptr Pointer to memory to free
 * @return HMR_SEC_SUCCESS on success, error code on failure
 */
int hmr_sec_sandbox_free(uint32_t module_id, void* ptr);

/**
 * Validate memory access within sandbox boundaries
 * 
 * @param module_id Module attempting access
 * @param ptr Memory pointer to validate
 * @param size Size of access
 * @param write_access Whether this is a write operation
 * @return HMR_SEC_SUCCESS if valid, error code if violation
 */
int hmr_sec_validate_memory_access(uint32_t module_id, const void* ptr, 
                                  size_t size, bool write_access);

/**
 * Get sandbox memory usage statistics
 * 
 * @param module_id Module to query
 * @param used_memory Output: current memory usage
 * @param memory_limit Output: memory limit
 * @param peak_usage Output: peak memory usage
 * @return HMR_SEC_SUCCESS on success, error code on failure
 */
int hmr_sec_get_memory_stats(uint32_t module_id, uint64_t* used_memory,
                            uint64_t* memory_limit, uint64_t* peak_usage);

// =============================================================================
// Security Violation and Monitoring
// =============================================================================

/**
 * Report a security violation
 * Records violation and takes appropriate action
 * 
 * @param module_id Module that violated security
 * @param violation_type Type of violation
 * @param violation_address Memory address if applicable
 * @param description Human-readable description
 * @param severity Severity level (1-10)
 * @return HMR_SEC_SUCCESS on success, error code on failure
 */
int hmr_sec_report_violation(uint32_t module_id, hmr_violation_type_t violation_type,
                            uint64_t violation_address, const char* description,
                            uint32_t severity);

/**
 * Check if a module is currently locked down due to security violations
 * 
 * @param module_id Module to check
 * @return true if locked down, false if operating normally
 */
bool hmr_sec_is_locked_down(uint32_t module_id);

/**
 * Manually lock down a module for security reasons
 * 
 * @param module_id Module to lock down
 * @param reason Reason for lockdown
 * @return HMR_SEC_SUCCESS on success, error code on failure
 */
int hmr_sec_lockdown_module(uint32_t module_id, const char* reason);

/**
 * Release a module from security lockdown
 * 
 * @param module_id Module to release
 * @param authorization_code Authorization code for release
 * @return HMR_SEC_SUCCESS on success, error code on failure
 */
int hmr_sec_release_lockdown(uint32_t module_id, uint64_t authorization_code);

// =============================================================================
// Audit Logging and Compliance
// =============================================================================

/**
 * Log a security event for audit purposes
 * 
 * @param module_id Module involved in event
 * @param operation_type Type of operation
 * @param capability_used Capability that was used
 * @param operation_allowed Whether operation was allowed
 * @param details Additional details
 * @return HMR_SEC_SUCCESS on success, error code on failure
 */
int hmr_sec_audit_log(uint32_t module_id, uint32_t operation_type,
                     uint32_t capability_used, bool operation_allowed,
                     const char* details);

/**
 * Export audit log to external system
 * 
 * @param buffer Buffer to write audit log to
 * @param buffer_size Size of output buffer
 * @param entries_exported Output: number of entries exported
 * @return HMR_SEC_SUCCESS on success, error code on failure
 */
int hmr_sec_export_audit_log(char* buffer, size_t buffer_size, uint32_t* entries_exported);

/**
 * Generate security compliance report
 * 
 * @param report_buffer Buffer for compliance report
 * @param buffer_size Size of report buffer
 * @return HMR_SEC_SUCCESS on success, error code on failure
 */
int hmr_sec_generate_compliance_report(char* report_buffer, size_t buffer_size);

/**
 * Clear audit log (requires admin capabilities)
 * 
 * @param authorization_code Authorization code for clearing
 * @return HMR_SEC_SUCCESS on success, error code on failure
 */
int hmr_sec_clear_audit_log(uint64_t authorization_code);

// =============================================================================
// Performance and Statistics
// =============================================================================

/**
 * Get comprehensive security statistics
 * 
 * @param stats Output: security statistics structure
 */
void hmr_sec_get_statistics(hmr_security_stats_t* stats);

/**
 * Reset security statistics and counters
 * 
 * @param authorization_code Authorization code for reset
 * @return HMR_SEC_SUCCESS on success, error code on failure
 */
int hmr_sec_reset_statistics(uint64_t authorization_code);

/**
 * Perform real-time security monitoring
 * Call periodically to detect anomalies and threats
 * 
 * @param frame_budget_ns Maximum time budget for monitoring
 * @return HMR_SEC_SUCCESS on success, error code if threats detected
 */
int hmr_sec_monitor_real_time(uint64_t frame_budget_ns);

// =============================================================================
// Security Configuration
// =============================================================================

/**
 * Update global security level
 * 
 * @param new_level New security level to enforce
 * @param authorization_code Authorization code for change
 * @return HMR_SEC_SUCCESS on success, error code on failure
 */
int hmr_sec_set_security_level(hmr_security_level_t new_level, uint64_t authorization_code);

/**
 * Get current security level
 * 
 * @return Current security level
 */
hmr_security_level_t hmr_sec_get_security_level(void);

/**
 * Enable or disable real-time monitoring
 * 
 * @param enabled Whether to enable real-time monitoring
 * @return HMR_SEC_SUCCESS on success, error code on failure
 */
int hmr_sec_set_monitoring_enabled(bool enabled);

// =============================================================================
// Integration Macros
// =============================================================================

/**
 * Convenience macro for capability validation with automatic audit
 */
#define HMR_SEC_VALIDATE_OR_DENY(module_id, capability, operation) \
    do { \
        int _sec_result = hmr_sec_validate_capability(module_id, capability, operation); \
        if (_sec_result != HMR_SEC_SUCCESS) { \
            return _sec_result; \
        } \
    } while(0)

/**
 * Convenience macro for secure memory access validation
 */
#define HMR_SEC_VALIDATE_MEMORY_OR_FAIL(module_id, ptr, size, write) \
    do { \
        int _mem_result = hmr_sec_validate_memory_access(module_id, ptr, size, write); \
        if (_mem_result != HMR_SEC_SUCCESS) { \
            hmr_sec_report_violation(module_id, HMR_VIOLATION_INVALID_ACCESS, \
                                   (uint64_t)(ptr), "Invalid memory access", 7); \
            return _mem_result; \
        } \
    } while(0)

#ifdef __cplusplus
}
#endif

#endif // HMR_RUNTIME_SECURITY_H