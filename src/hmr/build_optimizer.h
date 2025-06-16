/*
 * SimCity ARM64 - Intelligent Build Optimizer
 * Agent 2: File Watcher & Build Pipeline - Week 2 Day 6
 * 
 * Smart dependency analysis and build optimization system
 * - Minimal rebuild scope calculation
 * - Content-based build cache with hashing
 * - Distributed build preparation
 * - Performance-optimized compilation scheduling
 */

#ifndef BUILD_OPTIMIZER_H
#define BUILD_OPTIMIZER_H

#include <stdint.h>
#include <stdbool.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

// Build optimization constants
#define BUILD_MAX_MODULES 64
#define BUILD_MAX_DEPENDENCIES 512
#define BUILD_MAX_CACHE_ENTRIES 2048
#define BUILD_HASH_SIZE 32
#define BUILD_MAX_PATH_LENGTH 1024
#define BUILD_MAX_PARALLEL_JOBS 32

// Build target types
typedef enum {
    BUILD_TARGET_ASSEMBLY = 0,
    BUILD_TARGET_OBJECT,
    BUILD_TARGET_LIBRARY,
    BUILD_TARGET_EXECUTABLE,
    BUILD_TARGET_SHADER,
    BUILD_TARGET_ASSET,
    BUILD_TARGET_TEST,
    BUILD_TARGET_BENCHMARK
} build_target_type_t;

// Build priority levels
typedef enum {
    BUILD_PRIORITY_CRITICAL = 0,  // Core system modules
    BUILD_PRIORITY_HIGH,          // Graphics, simulation
    BUILD_PRIORITY_NORMAL,        // Standard modules
    BUILD_PRIORITY_LOW,           // Documentation, tests
    BUILD_PRIORITY_BACKGROUND     // Non-essential assets
} build_priority_t;

// Build cache entry
typedef struct {
    char source_path[BUILD_MAX_PATH_LENGTH];
    char output_path[BUILD_MAX_PATH_LENGTH];
    uint8_t content_hash[BUILD_HASH_SIZE];
    uint8_t dependency_hash[BUILD_HASH_SIZE];
    uint64_t timestamp;
    uint64_t build_time_ns;
    build_target_type_t target_type;
    uint32_t flags;
    bool is_valid;
} build_cache_entry_t;

// Build module definition
typedef struct {
    char name[64];
    char source_dir[BUILD_MAX_PATH_LENGTH];
    char output_dir[BUILD_MAX_PATH_LENGTH];
    build_target_type_t target_type;
    build_priority_t priority;
    uint32_t dependency_count;
    char dependencies[BUILD_MAX_DEPENDENCIES][64];
    uint64_t last_build_time;
    bool needs_rebuild;
    bool is_building;
    uint32_t build_job_id;
} build_module_t;

// Build dependency analysis result
typedef struct {
    uint32_t module_count;
    uint32_t module_indices[BUILD_MAX_MODULES];
    uint32_t build_order[BUILD_MAX_MODULES];
    uint64_t estimated_time_ns;
    uint32_t parallel_job_count;
    bool has_circular_dependency;
} build_analysis_t;

// Build performance metrics
typedef struct {
    uint64_t total_builds;
    uint64_t cache_hits;
    uint64_t cache_misses;
    uint64_t total_build_time_ns;
    uint64_t average_build_time_ns;
    uint64_t fastest_build_time_ns;
    uint64_t slowest_build_time_ns;
    uint32_t parallel_efficiency_percent;
    uint32_t cache_hit_rate_percent;
} build_metrics_t;

// Build optimizer callbacks
typedef struct {
    // Called when a build starts
    void (*on_build_start)(const char* module_name, build_target_type_t type);
    
    // Called when a build completes
    void (*on_build_complete)(const char* module_name, bool success, uint64_t build_time_ns);
    
    // Called when build cache is updated
    void (*on_cache_update)(const char* source_path, bool hit);
    
    // Called for progress updates
    void (*on_progress)(uint32_t completed, uint32_t total, const char* current_module);
    
    // Called for error reporting
    void (*on_error)(const char* module_name, const char* error_message);
} build_optimizer_callbacks_t;

// Initialize build optimizer
int32_t build_optimizer_init(uint32_t max_modules, const build_optimizer_callbacks_t* callbacks);

// Module management
int32_t build_optimizer_add_module(const build_module_t* module);
int32_t build_optimizer_remove_module(const char* module_name);
int32_t build_optimizer_update_module(const char* module_name, const build_module_t* module);

// Dependency analysis
int32_t build_optimizer_analyze_dependencies(const char* changed_file, build_analysis_t* analysis);
int32_t build_optimizer_check_circular_dependencies(bool* has_circular);
int32_t build_optimizer_calculate_build_order(const char** module_names, uint32_t count, 
                                             uint32_t* build_order, uint32_t* parallel_groups);

// Cache management
int32_t build_optimizer_check_cache(const char* source_path, const char* output_path, 
                                   bool* needs_rebuild);
int32_t build_optimizer_update_cache(const char* source_path, const char* output_path,
                                    const uint8_t* content_hash, uint64_t build_time_ns);
int32_t build_optimizer_invalidate_cache(const char* source_path);
int32_t build_optimizer_clear_cache(void);

// Content hashing
int32_t build_optimizer_hash_file(const char* file_path, uint8_t* hash_out);
int32_t build_optimizer_hash_dependencies(const char* module_name, uint8_t* hash_out);
int32_t build_optimizer_compare_hashes(const uint8_t* hash1, const uint8_t* hash2);

// Build execution
int32_t build_optimizer_start_build(const char* module_name, uint32_t job_id);
int32_t build_optimizer_complete_build(const char* module_name, bool success, uint64_t build_time_ns);
int32_t build_optimizer_cancel_build(const char* module_name);

// Parallel build management
int32_t build_optimizer_calculate_parallel_jobs(uint32_t available_cores, uint32_t memory_gb,
                                               uint32_t* recommended_jobs);
int32_t build_optimizer_schedule_parallel_builds(const build_analysis_t* analysis, 
                                                uint32_t max_jobs, uint32_t* job_assignments);

// Performance optimization
int32_t build_optimizer_estimate_build_time(const char* module_name, uint64_t* estimated_time_ns);
int32_t build_optimizer_optimize_build_flags(const char* module_name, char* flags_out, 
                                            size_t flags_size);
int32_t build_optimizer_predict_memory_usage(const build_analysis_t* analysis, 
                                            uint64_t* memory_bytes);

// Distributed build preparation
int32_t build_optimizer_prepare_distributed_build(const build_analysis_t* analysis,
                                                 char* build_manifest, size_t manifest_size);
int32_t build_optimizer_validate_distributed_cache(const char* remote_cache_path);

// Statistics and monitoring
int32_t build_optimizer_get_metrics(build_metrics_t* metrics);
int32_t build_optimizer_get_module_status(const char* module_name, build_module_t* status);
int32_t build_optimizer_get_cache_stats(uint32_t* total_entries, uint32_t* valid_entries,
                                       uint64_t* cache_size_bytes, uint32_t* hit_rate_percent);

// Configuration
int32_t build_optimizer_set_cache_size_limit(uint64_t max_bytes);
int32_t build_optimizer_set_parallel_limit(uint32_t max_jobs);
int32_t build_optimizer_set_build_timeout(uint64_t timeout_ns);
int32_t build_optimizer_enable_debug_mode(bool enabled);

// Cleanup
void build_optimizer_cleanup(void);

// Error codes
#define BUILD_SUCCESS 0
#define BUILD_ERROR_NULL_POINTER -1
#define BUILD_ERROR_OUT_OF_MEMORY -2
#define BUILD_ERROR_INVALID_ARG -3
#define BUILD_ERROR_NOT_FOUND -4
#define BUILD_ERROR_ALREADY_EXISTS -5
#define BUILD_ERROR_CIRCULAR_DEPENDENCY -6
#define BUILD_ERROR_BUILD_FAILED -7
#define BUILD_ERROR_CACHE_FULL -8
#define BUILD_ERROR_TIMEOUT -9
#define BUILD_ERROR_IO_ERROR -10

#ifdef __cplusplus
}
#endif

#endif // BUILD_OPTIMIZER_H