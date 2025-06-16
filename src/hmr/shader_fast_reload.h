/*
 * SimCity ARM64 - High-Performance Shader Fast Reload System
 * Ultra-Fast Shader Hot-Reload with <100ms Target Performance
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Week 2 - Day 6: Advanced Shader Features - Final Optimization
 * 
 * Performance Targets:
 * - Shader reload: <100ms (improved from <200ms baseline)
 * - Cache-enabled reload: <25ms
 * - Background compilation: <50ms
 * - Zero frame drops during reload
 * - Memory allocation optimization: <1ms
 */

#ifndef HMR_SHADER_FAST_RELOAD_H
#define HMR_SHADER_FAST_RELOAD_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __OBJC__
#import <Metal/Metal.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Fast reload optimization flags
typedef enum {
    HMR_FAST_RELOAD_NONE = 0,
    HMR_FAST_RELOAD_ASYNC_COMPILE = 1 << 0,     // Asynchronous compilation
    HMR_FAST_RELOAD_BINARY_CACHE = 1 << 1,      // Binary cache utilization
    HMR_FAST_RELOAD_PREDICTIVE = 1 << 2,        // Predictive compilation
    HMR_FAST_RELOAD_MEMORY_POOL = 1 << 3,       // Pre-allocated memory pools
    HMR_FAST_RELOAD_PARALLEL = 1 << 4,          // Parallel compilation
    HMR_FAST_RELOAD_INCREMENTAL = 1 << 5,       // Incremental updates
    HMR_FAST_RELOAD_GPU_ASYNC = 1 << 6,         // GPU-side async operations
    HMR_FAST_RELOAD_ALL = 0xFF                  // All optimizations enabled
} hmr_fast_reload_flags_t;

// Reload performance metrics
typedef struct {
    uint64_t total_reload_time_ns;      // Total reload time
    uint64_t compilation_time_ns;       // Compilation phase time
    uint64_t cache_lookup_time_ns;      // Cache lookup time
    uint64_t gpu_upload_time_ns;        // GPU resource upload time
    uint64_t pipeline_creation_time_ns; // Pipeline state creation time
    uint64_t memory_allocation_time_ns; // Memory allocation time
    
    bool used_cache;                    // Whether cache was used
    bool used_predictive;               // Whether predictive compilation was used
    bool was_background_compiled;       // Whether compiled in background
    
    size_t memory_allocated_bytes;      // Memory allocated during reload
    uint32_t compilation_threads_used;  // Number of compilation threads
    
    float performance_improvement_factor; // Performance improvement vs baseline
} hmr_fast_reload_metrics_t;

// Fast reload configuration
typedef struct {
    hmr_fast_reload_flags_t optimization_flags; // Enabled optimizations
    
    // Compilation settings
    uint32_t max_parallel_compilations;  // Max parallel compilation jobs
    uint32_t compilation_thread_priority; // Thread priority for compilation
    uint64_t compilation_timeout_ns;     // Compilation timeout
    
    // Cache settings
    size_t binary_cache_size_mb;        // Binary cache size limit
    uint32_t cache_prediction_depth;    // Cache prediction lookahead
    bool enable_cache_warming;          // Pre-warm frequently used shaders
    
    // Memory management
    size_t memory_pool_size_mb;         // Pre-allocated memory pool size
    uint32_t max_cached_pipelines;      // Maximum cached pipeline states
    bool enable_memory_recycling;       // Recycle memory allocations
    
    // Background compilation
    bool enable_background_compilation;  // Enable background pre-compilation
    uint32_t background_compile_lookahead; // Frames to look ahead for compilation
    float cpu_usage_limit;              // CPU usage limit for background work
    
    // Performance tuning
    uint64_t target_reload_time_ns;     // Target reload time (default: 100ms)
    bool enable_frame_pacing;           // Maintain frame rate during reload
    bool enable_adaptive_quality;       // Temporarily reduce quality during reload
    
    // Debug and monitoring
    bool enable_performance_logging;    // Log detailed performance metrics
    bool enable_regression_detection;   // Detect performance regressions
    char performance_log_path[256];     // Path for performance logs
} hmr_fast_reload_config_t;

// Compilation job for async processing
typedef struct {
    char shader_path[256];              // Shader source path
    char variant_name[64];              // Shader variant name
    char compilation_flags[256];        // Compilation flags
    uint32_t priority;                  // Job priority (0 = highest)
    uint64_t submission_time;           // When job was submitted
    
    // Completion callback
    void (*on_complete)(const char* shader_path, bool success, uint64_t compile_time_ns);
    
    // Job state
    bool is_completed;                  // Whether job is completed
    bool is_successful;                 // Whether compilation succeeded
    uint64_t completion_time;           // When job completed
    
#ifdef __OBJC__
    // Compiled results
    id<MTLLibrary> compiled_library;    // Compiled Metal library
    id<MTLFunction> compiled_function;  // Compiled function
#endif
} hmr_compilation_job_t;

// Memory pool for fast allocations
typedef struct {
    void* memory_base;                  // Base memory address
    size_t total_size;                  // Total pool size
    size_t used_size;                   // Currently used size
    size_t peak_usage;                  // Peak usage recorded
    
    // Allocation tracking
    struct {
        void* ptr;
        size_t size;
        bool is_free;
    } allocations[256];
    uint32_t allocation_count;
    
    // Performance metrics
    uint64_t total_allocations;         // Total allocations made
    uint64_t total_frees;               // Total frees made
    uint64_t allocation_time_ns;        // Time spent allocating
} hmr_memory_pool_t;

// Fast reload manager API

// Initialization and configuration
int32_t hmr_fast_reload_init(const hmr_fast_reload_config_t* config);
void hmr_fast_reload_cleanup(void);
int32_t hmr_fast_reload_update_config(const hmr_fast_reload_config_t* config);

// Fast reload operations
int32_t hmr_fast_reload_shader(const char* shader_path, const char* variant_name,
                              hmr_fast_reload_metrics_t* metrics);
int32_t hmr_fast_reload_shader_async(const char* shader_path, const char* variant_name,
                                    void (*on_complete)(const char* path, bool success, 
                                                       const hmr_fast_reload_metrics_t* metrics));

// Background compilation management
int32_t hmr_fast_reload_start_background_compilation(void);
int32_t hmr_fast_reload_stop_background_compilation(void);
int32_t hmr_fast_reload_queue_compilation(const char* shader_path, const char* variant_name,
                                         uint32_t priority);
int32_t hmr_fast_reload_get_compilation_queue_size(uint32_t* queue_size);

// Cache management for fast access
int32_t hmr_fast_reload_warm_cache(const char** shader_paths, uint32_t count);
int32_t hmr_fast_reload_precompile_variants(const char* shader_path);
int32_t hmr_fast_reload_predict_needed_shaders(char shader_paths[][256], uint32_t max_count,
                                              uint32_t* actual_count);

// Memory pool management
#ifdef __OBJC__
void* hmr_fast_reload_alloc(size_t size);
void hmr_fast_reload_free(void* ptr);
id<MTLBuffer> hmr_fast_reload_create_buffer(id<MTLDevice> device, size_t size);
#endif

// Performance optimization
int32_t hmr_fast_reload_optimize_for_scene(const char* scene_name);
int32_t hmr_fast_reload_set_quality_temporarily(float quality_factor);
int32_t hmr_fast_reload_enable_frame_pacing(bool enable);

// Performance monitoring and analysis
void hmr_fast_reload_get_performance_stats(
    uint32_t* total_reloads,
    uint64_t* avg_reload_time_ns,
    float* cache_hit_rate,
    float* background_compile_rate
);

void hmr_fast_reload_get_detailed_metrics(
    hmr_fast_reload_metrics_t* last_reload_metrics,
    uint64_t* fastest_reload_time_ns,
    uint64_t* slowest_reload_time_ns,
    float* performance_regression_factor
);

// Regression detection and alerting
int32_t hmr_fast_reload_check_performance_regression(const char* shader_path,
                                                   bool* has_regression,
                                                   float* regression_factor);
int32_t hmr_fast_reload_set_performance_baseline(const char* baseline_name);

// Advanced optimization techniques
int32_t hmr_fast_reload_enable_incremental_compilation(bool enable);
int32_t hmr_fast_reload_enable_gpu_async_uploads(bool enable);
int32_t hmr_fast_reload_optimize_memory_layout(void);

// Statistics and reporting
typedef struct {
    // Timing statistics
    uint64_t total_reloads;             // Total shader reloads performed
    uint64_t avg_reload_time_ns;        // Average reload time
    uint64_t min_reload_time_ns;        // Fastest reload time
    uint64_t max_reload_time_ns;        // Slowest reload time
    uint64_t total_time_saved_ns;       // Time saved by optimizations
    
    // Cache statistics
    uint64_t cache_hits;                // Cache hits
    uint64_t cache_misses;              // Cache misses
    float cache_hit_rate;               // Cache hit rate
    size_t cache_size_bytes;            // Current cache size
    
    // Background compilation
    uint64_t background_compilations;   // Background compilations completed
    uint32_t active_background_jobs;    // Currently active background jobs
    float background_compile_rate;      // Background compilation success rate
    
    // Memory statistics
    size_t peak_memory_usage_bytes;     // Peak memory usage
    uint64_t memory_allocations;        // Total memory allocations
    uint64_t memory_pool_hits;          // Memory pool allocation hits
    float memory_efficiency;            // Memory usage efficiency
    
    // Performance impact
    float frame_rate_impact_percent;    // Frame rate impact during reloads
    uint32_t frame_drops_prevented;     // Frame drops prevented by optimizations
    float cpu_usage_during_reload;      // CPU usage during reload operations
    
    // Regression tracking
    uint32_t performance_regressions;   // Number of performance regressions detected
    float avg_regression_factor;        // Average regression severity
} hmr_fast_reload_statistics_t;

void hmr_fast_reload_get_statistics(hmr_fast_reload_statistics_t* stats);
void hmr_fast_reload_reset_statistics(void);
void hmr_fast_reload_export_performance_report(const char* file_path);

// Callback registration
void hmr_fast_reload_set_callbacks(
    void (*on_reload_start)(const char* shader_path),
    void (*on_reload_complete)(const char* shader_path, const hmr_fast_reload_metrics_t* metrics),
    void (*on_performance_regression)(const char* shader_path, float regression_factor),
    void (*on_cache_miss)(const char* shader_path, const char* reason)
);

// Utility functions
bool hmr_fast_reload_is_optimization_available(hmr_fast_reload_flags_t optimization);
uint64_t hmr_fast_reload_estimate_reload_time(const char* shader_path, const char* variant_name);
float hmr_fast_reload_get_optimization_impact(hmr_fast_reload_flags_t optimization);

#ifdef __cplusplus
}
#endif

#endif // HMR_SHADER_FAST_RELOAD_H