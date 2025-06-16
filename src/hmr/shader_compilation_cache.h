/*
 * SimCity ARM64 - Intelligent Shader Compilation Cache
 * High-Performance Binary Caching with Smart Invalidation
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Week 2 - Day 6: Advanced Shader Features
 * 
 * Features:
 * - Persistent binary shader cache with LRU eviction
 * - Intelligent cache invalidation based on dependencies
 * - Compilation result memoization and prediction
 * - Cross-session cache sharing and validation
 * - Performance-aware cache management
 */

#ifndef HMR_SHADER_COMPILATION_CACHE_H
#define HMR_SHADER_COMPILATION_CACHE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __OBJC__
#import <Metal/Metal.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Cache entry status
typedef enum {
    HMR_CACHE_STATUS_INVALID = 0,
    HMR_CACHE_STATUS_VALID,
    HMR_CACHE_STATUS_STALE,
    HMR_CACHE_STATUS_COMPILING,
    HMR_CACHE_STATUS_FAILED
} hmr_cache_status_t;

// Cache statistics
typedef struct {
    uint64_t cache_hits;                // Number of cache hits
    uint64_t cache_misses;              // Number of cache misses
    uint64_t total_entries;             // Total cache entries
    uint64_t valid_entries;             // Valid cache entries
    uint64_t stale_entries;             // Stale entries pending update
    uint64_t failed_entries;            // Failed compilation entries
    
    size_t total_cache_size_bytes;      // Total cache size on disk
    size_t memory_cache_size_bytes;     // In-memory cache size
    
    uint64_t total_compile_time_saved_ns; // Time saved by cache hits
    uint64_t avg_compile_time_ns;       // Average compilation time
    
    float hit_rate;                     // Cache hit rate (0.0-1.0)
    float eviction_rate;                // Cache eviction rate
} hmr_cache_statistics_t;

// Dependency tracking
typedef struct {
    char file_path[256];                // Path to dependency file
    uint64_t last_modified_time;        // Last modification timestamp
    uint64_t file_size;                 // File size for additional validation
    uint32_t content_hash;              // Hash of file content
} hmr_cache_dependency_t;

// Cache entry metadata
typedef struct {
    char cache_key[64];                 // Unique cache key (hash-based)
    char source_path[256];              // Original shader source path
    char variant_name[64];              // Variant identifier
    char compilation_flags[256];        // Compilation flags used
    
    hmr_cache_status_t status;          // Current cache status
    uint64_t created_time;              // Creation timestamp
    uint64_t last_accessed_time;        // Last access timestamp
    uint64_t last_validated_time;       // Last validation timestamp
    
    // Compilation metadata
    uint64_t compile_time_ns;           // Original compilation time
    size_t binary_size;                 // Binary size in bytes
    uint32_t source_hash;               // Hash of original source
    uint32_t flags_hash;                // Hash of compilation flags
    
    // Dependencies
    uint32_t dependency_count;          // Number of dependencies
    hmr_cache_dependency_t dependencies[16]; // Dependency array
    
    // Performance metrics
    float gpu_compile_time_ms;          // GPU compilation time
    uint32_t access_count;              // Number of times accessed
    float performance_score;            // Performance rating (0.0-1.0)
    
    // Error tracking
    uint32_t compilation_failures;      // Number of compilation failures
    char last_error[256];               // Last compilation error
    
    // Cache file paths
    char binary_cache_path[512];        // Path to cached binary
    char metadata_cache_path[512];      // Path to metadata file
} hmr_cache_entry_t;

// Cache configuration
typedef struct {
    char cache_directory[256];          // Root cache directory
    size_t max_cache_size_mb;           // Maximum cache size in MB
    uint32_t max_entries;               // Maximum number of cache entries
    
    // Validation settings
    bool enable_content_validation;     // Validate file content hashes
    bool enable_dependency_tracking;    // Track include dependencies
    uint32_t validation_interval_sec;   // How often to validate entries
    
    // Performance settings
    uint32_t memory_cache_entries;      // Number of entries to keep in memory
    bool enable_async_validation;       // Validate cache entries asynchronously
    bool enable_predictive_compilation; // Pre-compile likely variants
    
    // Eviction policy
    bool enable_lru_eviction;           // Use LRU eviction policy
    float size_pressure_threshold;      // Size pressure threshold (0.0-1.0)
    uint32_t min_access_count;          // Minimum access count for retention
    
    // Cross-session settings
    bool enable_persistent_cache;       // Enable disk-based cache
    bool enable_cache_sharing;          // Share cache between processes
    char cache_version[16];             // Cache format version
} hmr_cache_config_t;

// Cache manager state
typedef struct hmr_cache_manager hmr_cache_manager_t;

// Cache manager API

// Initialization and cleanup
int32_t hmr_cache_manager_init(const hmr_cache_config_t* config);
void hmr_cache_manager_cleanup(void);

// Cache operations
int32_t hmr_cache_get_entry(const char* cache_key, hmr_cache_entry_t** entry);
int32_t hmr_cache_put_entry(const char* cache_key, const hmr_cache_entry_t* entry);
int32_t hmr_cache_remove_entry(const char* cache_key);
int32_t hmr_cache_invalidate_entry(const char* cache_key);

// Binary data operations
#ifdef __OBJC__
int32_t hmr_cache_store_binary(const char* cache_key, id<MTLLibrary> library);
id<MTLLibrary> hmr_cache_load_binary(const char* cache_key, id<MTLDevice> device);
#endif

int32_t hmr_cache_store_binary_data(const char* cache_key, const void* data, size_t size);
int32_t hmr_cache_load_binary_data(const char* cache_key, void** data, size_t* size);

// Dependency tracking
int32_t hmr_cache_add_dependency(const char* cache_key, const char* dependency_path);
int32_t hmr_cache_validate_dependencies(const char* cache_key, bool* is_valid);
int32_t hmr_cache_update_dependency_timestamps(const char* cache_key);

// Cache validation and maintenance
int32_t hmr_cache_validate_entry(const char* cache_key, bool* is_valid);
int32_t hmr_cache_validate_all_entries(uint32_t* validated_count, uint32_t* invalidated_count);
int32_t hmr_cache_compact_cache(size_t* bytes_freed);
int32_t hmr_cache_evict_stale_entries(uint32_t max_age_seconds, uint32_t* evicted_count);

// Key generation and utilities
void hmr_cache_generate_key(const char* source_path, const char* variant_name, 
                           const char* compilation_flags, char* cache_key, size_t key_size);
uint32_t hmr_cache_hash_string(const char* str);
uint32_t hmr_cache_hash_file(const char* file_path);
uint64_t hmr_cache_get_file_mtime(const char* file_path);

// Performance optimization
int32_t hmr_cache_precompile_variants(const char* source_path, const char** variant_names, 
                                     uint32_t variant_count);
int32_t hmr_cache_predict_needed_variants(const char* source_path, char** predicted_variants, 
                                         uint32_t max_variants, uint32_t* actual_count);

// Statistics and monitoring
void hmr_cache_get_statistics(hmr_cache_statistics_t* stats);
void hmr_cache_reset_statistics(void);
void hmr_cache_print_statistics(void);

// Configuration management
int32_t hmr_cache_update_config(const hmr_cache_config_t* new_config);
void hmr_cache_get_config(hmr_cache_config_t* config);

// Background operations
int32_t hmr_cache_start_background_validation(void);
int32_t hmr_cache_stop_background_validation(void);
int32_t hmr_cache_start_predictive_compilation(void);
int32_t hmr_cache_stop_predictive_compilation(void);

// Callback registration
void hmr_cache_set_callbacks(
    void (*on_cache_hit)(const char* cache_key, uint64_t saved_time_ns),
    void (*on_cache_miss)(const char* cache_key, const char* reason),
    void (*on_cache_eviction)(const char* cache_key, const char* reason),
    void (*on_validation_complete)(uint32_t validated_count, uint32_t invalidated_count)
);

// Import/Export functionality
int32_t hmr_cache_export_to_file(const char* export_path);
int32_t hmr_cache_import_from_file(const char* import_path);
int32_t hmr_cache_merge_from_cache(const char* other_cache_directory);

// Debug and introspection
void hmr_cache_dump_entry_info(const char* cache_key);
void hmr_cache_dump_all_entries(void);
int32_t hmr_cache_verify_integrity(bool* is_healthy);

#ifdef __cplusplus
}
#endif

#endif // HMR_SHADER_COMPILATION_CACHE_H