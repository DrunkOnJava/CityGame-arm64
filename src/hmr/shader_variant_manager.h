/*
 * SimCity ARM64 - Advanced Shader Variant Manager
 * Intelligent Quality-Level Shader Hot-Swapping System
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Week 2 - Day 6: Advanced Shader Features
 * 
 * Features:
 * - Multi-quality shader variants (Low/Medium/High/Ultra)
 * - Intelligent quality switching based on performance metrics
 * - Hot-swap between variants without frame drops
 * - Automatic LOD shader selection
 * - Variant-specific optimization flags
 */

#ifndef HMR_SHADER_VARIANT_MANAGER_H
#define HMR_SHADER_VARIANT_MANAGER_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __OBJC__
#import <Metal/Metal.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Quality levels for shader variants
typedef enum {
    HMR_QUALITY_LOW = 0,        // Minimal effects, maximum performance
    HMR_QUALITY_MEDIUM,         // Balanced quality/performance
    HMR_QUALITY_HIGH,           // High quality effects
    HMR_QUALITY_ULTRA,          // Maximum quality, all effects
    HMR_QUALITY_ADAPTIVE,       // Dynamic quality based on performance
    HMR_QUALITY_COUNT
} hmr_shader_quality_t;

// Shader variant flags
typedef enum {
    HMR_VARIANT_FLAG_NONE = 0,
    HMR_VARIANT_FLAG_FAST_MATH = 1 << 0,        // Enable fast math optimizations
    HMR_VARIANT_FLAG_NO_BRANCHING = 1 << 1,     // Unroll loops, minimize branches
    HMR_VARIANT_FLAG_REDUCED_PRECISION = 1 << 2, // Use half-precision where possible
    HMR_VARIANT_FLAG_OPTIMIZE_SIZE = 1 << 3,     // Optimize for binary size
    HMR_VARIANT_FLAG_DEBUG_INFO = 1 << 4,        // Include debug information
    HMR_VARIANT_FLAG_PROFILING = 1 << 5         // Include profiling hooks
} hmr_shader_variant_flags_t;

// Performance metrics for adaptive quality
typedef struct {
    float gpu_utilization;      // GPU utilization percentage (0.0-1.0)
    float frame_time_ms;        // Current frame time in milliseconds
    float target_frame_time_ms; // Target frame time (e.g., 16.67ms for 60fps)
    uint32_t dropped_frames;    // Number of dropped frames in last second
    float memory_pressure;      // GPU memory pressure (0.0-1.0)
    float thermal_state;        // Thermal throttling factor (0.0-1.0)
} hmr_performance_metrics_t;

// Shader variant definition
typedef struct {
    char variant_name[64];              // Human-readable variant name
    char preprocessor_defines[512];     // Preprocessor definitions for this variant
    hmr_shader_quality_t quality_level; // Quality level this variant targets
    hmr_shader_variant_flags_t flags;   // Compilation flags
    float performance_weight;           // Performance impact weight (1.0 = baseline)
    float quality_score;               // Visual quality score (1.0 = baseline)
    
    // Quality-specific parameters
    struct {
        uint32_t max_texture_size;      // Maximum texture resolution
        uint32_t max_shadow_samples;    // Maximum shadow map samples
        uint32_t max_light_count;       // Maximum dynamic lights
        bool enable_reflections;        // Enable reflection effects
        bool enable_ambient_occlusion;  // Enable SSAO
        bool enable_bloom;              // Enable bloom effect
        bool enable_antialiasing;       // Enable MSAA/FXAA
        float lod_bias;                 // LOD bias adjustment
    } quality_params;
    
    // Compilation state
    bool is_compiled;                   // Whether this variant is compiled
    uint64_t compile_time_ns;          // Compilation time
    size_t binary_size;                // Compiled binary size
    char last_error[256];              // Last compilation error
    
#ifdef __OBJC__
    // Metal objects for this variant
    id<MTLLibrary> library;            // Compiled Metal library
    id<MTLFunction> function;          // Shader function
    id<MTLRenderPipelineState> render_pipeline;
    id<MTLComputePipelineState> compute_pipeline;
#endif
} hmr_shader_variant_t;

// Shader variant group (all variants of a single shader)
typedef struct {
    char base_shader_path[256];         // Path to base shader source
    char shader_name[64];               // Shader identifier
    uint32_t variant_count;             // Number of variants
    hmr_shader_variant_t variants[HMR_QUALITY_COUNT]; // Variant array
    
    hmr_shader_quality_t active_quality; // Currently active quality level
    hmr_shader_quality_t target_quality; // Target quality for next frame
    bool is_transitioning;               // Whether currently transitioning
    
    // Performance tracking
    uint64_t frame_count;               // Frames rendered with this shader
    uint64_t total_gpu_time_ns;         // Total GPU time for this shader
    float avg_gpu_time_ns;              // Average GPU time per frame
    
    // Adaptive quality state
    float quality_adaptation_timer;     // Timer for quality adaptation
    float performance_history[16];      // Recent performance samples
    uint32_t history_index;             // Current index in history buffer
} hmr_shader_variant_group_t;

// Variant manager configuration
typedef struct {
    bool enable_adaptive_quality;       // Auto-adjust quality based on performance
    float adaptation_interval_sec;      // How often to check for quality changes
    float quality_change_threshold;     // Performance change threshold for quality switch
    hmr_shader_quality_t min_quality;   // Minimum allowed quality level
    hmr_shader_quality_t max_quality;   // Maximum allowed quality level
    hmr_shader_quality_t default_quality; // Default quality level
    
    // Performance targets
    float target_frame_time_ms;         // Target frame time
    float performance_headroom;         // Performance headroom factor (0.1 = 10%)
    
    // Hot-swap settings
    bool enable_hot_swap;               // Enable hot-swapping between variants
    uint32_t max_concurrent_compiles;   // Max variants compiling simultaneously
    
    // Cache settings
    char cache_directory[256];          // Directory for variant cache
    bool enable_persistent_cache;       // Enable disk-based cache
} hmr_variant_manager_config_t;

// Variant manager API
#ifdef __OBJC__
int32_t hmr_variant_manager_init(const hmr_variant_manager_config_t* config, id<MTLDevice> device);
#endif

// Shader registration and variant creation
int32_t hmr_variant_register_shader(const char* shader_path, const char* shader_name);
int32_t hmr_variant_create_variant(const char* shader_name, hmr_shader_quality_t quality,
                                   const char* defines, hmr_shader_variant_flags_t flags);
int32_t hmr_variant_compile_all(const char* shader_name);
int32_t hmr_variant_compile_quality(const char* shader_name, hmr_shader_quality_t quality);

// Quality management
int32_t hmr_variant_set_quality(const char* shader_name, hmr_shader_quality_t quality);
hmr_shader_quality_t hmr_variant_get_active_quality(const char* shader_name);
int32_t hmr_variant_update_performance_metrics(const hmr_performance_metrics_t* metrics);
void hmr_variant_tick_adaptive_quality(float delta_time_sec);

// Pipeline access
#ifdef __OBJC__
id<MTLRenderPipelineState> hmr_variant_get_render_pipeline(const char* shader_name);
id<MTLComputePipelineState> hmr_variant_get_compute_pipeline(const char* shader_name);
id<MTLFunction> hmr_variant_get_function(const char* shader_name);
#endif

// Hot-swap functionality
int32_t hmr_variant_hot_swap_all(const char* shader_name);
int32_t hmr_variant_hot_swap_quality(const char* shader_name, hmr_shader_quality_t quality);

// Statistics and monitoring
void hmr_variant_get_shader_stats(const char* shader_name,
                                  uint32_t* variant_count,
                                  uint32_t* compiled_variants,
                                  hmr_shader_quality_t* active_quality,
                                  float* avg_gpu_time_ms);

void hmr_variant_get_global_stats(uint32_t* total_shaders,
                                  uint32_t* total_variants,
                                  uint64_t* total_compilations,
                                  uint64_t* cache_hits,
                                  uint64_t* cache_misses);

// Callbacks for variant events
void hmr_variant_set_callbacks(
    void (*on_quality_changed)(const char* shader_name, hmr_shader_quality_t old_quality, hmr_shader_quality_t new_quality),
    void (*on_variant_compiled)(const char* shader_name, hmr_shader_quality_t quality, bool success, uint64_t compile_time_ns),
    void (*on_adaptive_change)(hmr_shader_quality_t new_global_quality, float performance_factor)
);

// Cleanup
void hmr_variant_manager_cleanup(void);

// Utility functions
const char* hmr_variant_quality_to_string(hmr_shader_quality_t quality);
hmr_shader_quality_t hmr_variant_string_to_quality(const char* quality_str);
float hmr_variant_estimate_performance_impact(hmr_shader_quality_t from_quality, hmr_shader_quality_t to_quality);

#ifdef __cplusplus
}
#endif

#endif // HMR_SHADER_VARIANT_MANAGER_H