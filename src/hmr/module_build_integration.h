/*
 * SimCity ARM64 - Module Build Integration System
 * Agent 2: File Watcher & Build Pipeline - Week 2 Day 9
 * 
 * Integration with Agent 1's module system for seamless hot-reload
 * Features:
 * - Module-specific build optimization and caching
 * - Build output compatibility verification
 * - Automated testing and validation
 * - Intelligent build artifact management
 */

#ifndef MODULE_BUILD_INTEGRATION_H
#define MODULE_BUILD_INTEGRATION_H

#include "build_optimizer.h"
#include "module_interface.h"
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Module integration constants
#define MODULE_MAX_EXPORTS 256
#define MODULE_MAX_IMPORTS 256
#define MODULE_MAX_SYMBOLS 1024
#define MODULE_MAX_RELOCATIONS 512
#define MODULE_SIGNATURE_SIZE 64
#define MODULE_VERSION_STRING_SIZE 32

// Module build types
typedef enum {
    MODULE_BUILD_TYPE_STATIC = 0,
    MODULE_BUILD_TYPE_DYNAMIC,
    MODULE_BUILD_TYPE_HOTSWAP,
    MODULE_BUILD_TYPE_TEST,
    MODULE_BUILD_TYPE_BENCHMARK
} module_build_type_t;

// Module compatibility levels
typedef enum {
    MODULE_COMPAT_BINARY = 0,     // Binary compatible, can hot-swap
    MODULE_COMPAT_ABI,            // ABI compatible, requires restart
    MODULE_COMPAT_API,            // API compatible, requires rebuild
    MODULE_COMPAT_BREAKING        // Breaking change, requires full rebuild
} module_compat_level_t;

// Module symbol information
typedef struct {
    char name[128];
    uint64_t address;
    uint32_t size;
    uint32_t type;                // Symbol type (function, data, etc.)
    uint32_t binding;             // Symbol binding (local, global, weak)
    bool is_exported;
    bool is_imported;
    char signature[MODULE_SIGNATURE_SIZE];
} module_symbol_t;

// Module export information
typedef struct {
    char name[128];
    uint64_t address;
    uint32_t size;
    char signature[MODULE_SIGNATURE_SIZE];
    uint32_t version;
    bool is_critical;             // Critical for module loading
} module_export_t;

// Module import information
typedef struct {
    char name[128];
    char module_name[64];         // Which module provides this import
    char signature[MODULE_SIGNATURE_SIZE];
    uint32_t min_version;
    bool is_optional;
    bool is_resolved;
    uint64_t resolved_address;
} module_import_t;

// Module build artifact
typedef struct {
    char module_name[64];
    char build_path[1024];
    char output_path[1024];
    module_build_type_t build_type;
    
    // Version information
    uint32_t version_major;
    uint32_t version_minor;
    uint32_t version_patch;
    char version_string[MODULE_VERSION_STRING_SIZE];
    uint64_t build_timestamp;
    
    // Symbols and exports
    uint32_t symbol_count;
    module_symbol_t symbols[MODULE_MAX_SYMBOLS];
    uint32_t export_count;
    module_export_t exports[MODULE_MAX_EXPORTS];
    uint32_t import_count;
    module_import_t imports[MODULE_MAX_IMPORTS];
    
    // Build information
    uint8_t content_hash[32];
    uint64_t file_size;
    uint32_t build_flags;
    char compiler_version[64];
    
    // Hot-reload compatibility
    module_compat_level_t compat_level;
    bool supports_hot_reload;
    bool requires_dependency_rebuild;
    uint32_t hot_reload_version;
    
    // Performance data
    uint64_t load_time_ns;
    uint64_t init_time_ns;
    uint32_t memory_usage_kb;
    
    // Validation status
    bool is_valid;
    bool is_tested;
    bool is_compatible;
    char validation_error[256];
} module_build_artifact_t;

// Module dependency relationship
typedef struct {
    char dependent_module[64];
    char dependency_module[64];
    uint32_t min_version;
    uint32_t max_version;
    bool is_hard_dependency;      // Hard (required) vs soft (optional)
    bool is_runtime_dependency;   // Runtime vs build-time dependency
    module_compat_level_t required_compat;
} module_dependency_t;

// Build integration configuration
typedef struct {
    bool enable_hot_reload;
    bool enable_incremental_build;
    bool enable_dependency_tracking;
    bool enable_compatibility_checking;
    bool enable_automated_testing;
    bool enable_performance_profiling;
    
    // Build optimization settings
    uint32_t optimization_level;
    bool enable_debug_symbols;
    bool enable_dead_code_elimination;
    bool enable_link_time_optimization;
    
    // Hot-reload settings
    uint32_t hot_reload_timeout_ms;
    bool preserve_state_on_reload;
    bool validate_before_reload;
    
    // Testing configuration
    bool run_unit_tests;
    bool run_integration_tests;
    bool run_performance_tests;
    uint32_t test_timeout_ms;
} module_build_config_t;

// Build integration callbacks
typedef struct {
    // Called when module build starts
    void (*on_module_build_start)(const char* module_name, module_build_type_t type);
    
    // Called when module build completes
    void (*on_module_build_complete)(const char* module_name, bool success, 
                                   const module_build_artifact_t* artifact);
    
    // Called when compatibility check fails
    void (*on_compatibility_error)(const char* module_name, module_compat_level_t level,
                                 const char* error_message);
    
    // Called when module is ready for hot-reload
    void (*on_hot_reload_ready)(const char* module_name, const module_build_artifact_t* artifact);
    
    // Called when dependency resolution fails
    void (*on_dependency_error)(const char* module_name, const char* dependency_name,
                              const char* error_message);
    
    // Called for build progress updates
    void (*on_build_progress)(const char* module_name, uint32_t percent_complete,
                            const char* current_phase);
} module_build_callbacks_t;

// Initialize module build integration
int32_t module_build_integration_init(const module_build_config_t* config,
                                     const module_build_callbacks_t* callbacks);

// Module management
int32_t module_build_register_module(const char* module_name, const char* source_path,
                                    module_build_type_t build_type);
int32_t module_build_unregister_module(const char* module_name);
int32_t module_build_update_module_config(const char* module_name, const module_build_config_t* config);

// Dependency management
int32_t module_build_add_dependency(const module_dependency_t* dependency);
int32_t module_build_remove_dependency(const char* dependent_module, const char* dependency_module);
int32_t module_build_resolve_dependencies(const char* module_name, char** missing_deps,
                                         uint32_t max_deps, uint32_t* actual_count);
int32_t module_build_check_circular_dependencies(const char* module_name, bool* has_circular);

// Build operations
int32_t module_build_start_build(const char* module_name, bool force_rebuild);
int32_t module_build_cancel_build(const char* module_name);
int32_t module_build_get_build_status(const char* module_name, build_job_state_t* state,
                                     uint32_t* progress_percent);

// Artifact management
int32_t module_build_get_artifact(const char* module_name, module_build_artifact_t* artifact);
int32_t module_build_validate_artifact(const module_build_artifact_t* artifact, bool* is_valid,
                                      char* validation_errors, size_t error_size);
int32_t module_build_install_artifact(const char* module_name, const char* install_path);
int32_t module_build_backup_artifact(const char* module_name, const char* backup_path);

// Compatibility checking
int32_t module_build_check_compatibility(const char* module_name, const char* other_module,
                                        module_compat_level_t* compat_level);
int32_t module_build_analyze_api_changes(const module_build_artifact_t* old_artifact,
                                        const module_build_artifact_t* new_artifact,
                                        module_compat_level_t* compat_level);
int32_t module_build_validate_hot_reload_safety(const char* module_name, bool* is_safe);

// Symbol management
int32_t module_build_extract_symbols(const char* module_path, module_symbol_t* symbols,
                                    uint32_t max_symbols, uint32_t* actual_count);
int32_t module_build_resolve_symbol(const char* module_name, const char* symbol_name,
                                   uint64_t* address, char* signature, size_t sig_size);
int32_t module_build_check_symbol_conflicts(const char* module_name, bool* has_conflicts);

// Hot-reload integration
int32_t module_build_prepare_hot_reload(const char* module_name, uint32_t* reload_token);
int32_t module_build_execute_hot_reload(const char* module_name, uint32_t reload_token);
int32_t module_build_rollback_hot_reload(const char* module_name, uint32_t reload_token);
int32_t module_build_get_hot_reload_status(const char* module_name, bool* is_reloading,
                                         uint32_t* progress_percent);

// Testing integration
int32_t module_build_run_module_tests(const char* module_name, bool unit_tests, bool integration_tests);
int32_t module_build_get_test_results(const char* module_name, uint32_t* tests_passed,
                                     uint32_t* tests_failed, char* test_output, size_t output_size);
int32_t module_build_benchmark_module(const char* module_name, uint64_t* load_time_ns,
                                     uint64_t* init_time_ns, uint32_t* memory_usage_kb);

// Cache management
int32_t module_build_enable_artifact_cache(bool enabled, const char* cache_path);
int32_t module_build_invalidate_cache(const char* module_name);
int32_t module_build_clear_all_cache(void);
int32_t module_build_get_cache_stats(uint32_t* cached_artifacts, uint64_t* cache_size_bytes,
                                    uint32_t* hit_rate_percent);

// Performance optimization
int32_t module_build_optimize_for_hot_reload(const char* module_name, bool enabled);
int32_t module_build_enable_incremental_linking(const char* module_name, bool enabled);
int32_t module_build_set_build_priority(const char* module_name, build_job_priority_t priority);
int32_t module_build_estimate_build_time(const char* module_name, uint64_t* estimated_time_ns);

// Monitoring and statistics
int32_t module_build_get_statistics(uint32_t* total_builds, uint32_t* successful_builds,
                                   uint32_t* failed_builds, uint64_t* total_build_time_ns,
                                   uint32_t* hot_reloads_performed);

int32_t module_build_get_module_metrics(const char* module_name, uint64_t* avg_build_time_ns,
                                       uint32_t* build_count, uint32_t* hot_reload_count,
                                       module_compat_level_t* typical_compat_level);

// Configuration
int32_t module_build_set_compiler_path(const char* compiler_path);
int32_t module_build_set_linker_path(const char* linker_path);
int32_t module_build_set_build_flags(const char* module_name, const char* flags);
int32_t module_build_enable_debug_output(bool enabled);

// Cleanup
void module_build_integration_cleanup(void);

// Error codes (extending build optimizer error codes)
#define MODULE_BUILD_SUCCESS 0
#define MODULE_BUILD_ERROR_INVALID_MODULE -100
#define MODULE_BUILD_ERROR_DEPENDENCY_FAILED -101
#define MODULE_BUILD_ERROR_COMPATIBILITY_ERROR -102
#define MODULE_BUILD_ERROR_SYMBOL_NOT_FOUND -103
#define MODULE_BUILD_ERROR_HOT_RELOAD_FAILED -104
#define MODULE_BUILD_ERROR_TEST_FAILED -105
#define MODULE_BUILD_ERROR_VALIDATION_FAILED -106

#ifdef __cplusplus
}
#endif

#endif // MODULE_BUILD_INTEGRATION_H