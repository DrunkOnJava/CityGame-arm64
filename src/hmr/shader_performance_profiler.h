/*
 * SimCity ARM64 - Advanced Shader Performance Profiler
 * Real-time Shader Performance Analysis and Bottleneck Detection
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Week 2 - Day 6: Advanced Shader Features
 * 
 * Features:
 * - Real-time GPU performance monitoring
 * - Automated bottleneck detection and classification
 * - Performance regression tracking
 * - Optimization suggestions and recommendations
 * - Comparative performance analysis across variants
 * - Predictive performance modeling
 */

#ifndef HMR_SHADER_PERFORMANCE_PROFILER_H
#define HMR_SHADER_PERFORMANCE_PROFILER_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __OBJC__
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Performance profiling modes
typedef enum {
    HMR_PROFILE_MODE_DISABLED = 0,      // No profiling
    HMR_PROFILE_MODE_BASIC,             // Basic timing only
    HMR_PROFILE_MODE_DETAILED,          // Detailed metrics
    HMR_PROFILE_MODE_COMPREHENSIVE,     // Full analysis with suggestions
    HMR_PROFILE_MODE_REGRESSION         // Regression detection mode
} hmr_profile_mode_t;

// Bottleneck types
typedef enum {
    HMR_BOTTLENECK_NONE = 0,
    HMR_BOTTLENECK_MEMORY_BANDWIDTH,    // Memory bandwidth limited
    HMR_BOTTLENECK_ALU,                 // ALU/compute limited
    HMR_BOTTLENECK_TEXTURE_CACHE,       // Texture cache misses
    HMR_BOTTLENECK_VERTEX_FETCH,        // Vertex fetch limited
    HMR_BOTTLENECK_FRAGMENT_OVERDRAW,   // Fragment overdraw
    HMR_BOTTLENECK_SYNCHRONIZATION,     // GPU synchronization
    HMR_BOTTLENECK_DRIVER_OVERHEAD,     // Driver/CPU overhead
    HMR_BOTTLENECK_THERMAL_THROTTLING   // Thermal throttling
} hmr_bottleneck_type_t;

// Performance severity levels
typedef enum {
    HMR_PERF_SEVERITY_INFO = 0,
    HMR_PERF_SEVERITY_NOTICE,
    HMR_PERF_SEVERITY_WARNING,
    HMR_PERF_SEVERITY_CRITICAL
} hmr_performance_severity_t;

// Detailed GPU metrics
typedef struct {
    // Basic timing
    uint64_t gpu_start_time_ns;         // GPU execution start
    uint64_t gpu_end_time_ns;           // GPU execution end
    uint64_t cpu_overhead_ns;           // CPU-side overhead
    
    // Throughput metrics
    uint64_t vertices_per_second;       // Vertex processing rate
    uint64_t fragments_per_second;      // Fragment processing rate
    uint64_t pixels_per_second;         // Pixel fill rate
    
    // Memory metrics
    uint64_t memory_reads_bytes;        // Memory read volume
    uint64_t memory_writes_bytes;       // Memory write volume
    float memory_bandwidth_utilization; // Memory bandwidth usage (0.0-1.0)
    uint32_t cache_miss_rate;           // Cache miss percentage
    
    // GPU utilization
    float vertex_shader_utilization;    // Vertex shader usage
    float fragment_shader_utilization;  // Fragment shader usage
    float compute_utilization;          // Compute shader usage
    float gpu_overall_utilization;      // Overall GPU utilization
    
    // Power and thermal
    float power_consumption_watts;      // Power consumption
    float gpu_temperature_celsius;      // GPU temperature
    float thermal_throttling_factor;    // Throttling factor (0.0-1.0)
    
    // Quality metrics
    uint32_t overdraw_factor;           // Average overdraw factor
    uint32_t wasted_fragments;          // Fragments killed by depth test
    uint32_t texture_cache_misses;      // Texture cache miss count
    
    // Frame context
    uint64_t frame_number;              // Frame number
    uint32_t draw_call_index;           // Draw call within frame
    uint32_t pass_index;                // Render pass index
} hmr_gpu_metrics_t;

// Performance analysis result
typedef struct {
    char shader_name[64];               // Shader being analyzed
    uint64_t analysis_timestamp;        // When analysis was performed
    
    // Primary bottleneck
    hmr_bottleneck_type_t primary_bottleneck;
    float bottleneck_severity;          // Severity (0.0-1.0)
    char bottleneck_description[256];   // Human-readable description
    
    // Performance score
    float overall_performance_score;    // Overall score (0.0-1.0)
    float efficiency_score;             // GPU efficiency score
    float memory_efficiency_score;      // Memory efficiency score
    float power_efficiency_score;       // Power efficiency score
    
    // Optimization opportunities
    struct {
        bool reduce_texture_resolution;
        bool optimize_vertex_count;
        bool reduce_overdraw;
        bool improve_cache_locality;
        bool reduce_memory_bandwidth;
        bool optimize_branching;
        bool reduce_register_pressure;
        bool improve_occupancy;
    } optimization_flags;
    
    // Recommendations
    uint32_t recommendation_count;
    struct {
        hmr_performance_severity_t severity;
        char title[64];
        char description[256];
        char suggested_action[256];
        float estimated_improvement;    // Estimated performance gain
    } recommendations[8];
    
    // Comparative analysis
    struct {
        bool has_baseline;
        float performance_change_percent; // Change from baseline
        float regression_severity;       // Regression severity if negative
        char comparison_notes[256];
    } comparison;
} hmr_performance_analysis_t;

// Performance trend data
typedef struct {
    uint64_t timestamp;                 // Measurement timestamp
    float gpu_time_ms;                  // GPU execution time
    float performance_score;            // Overall performance score
    float memory_usage_mb;              // Memory usage
    float power_consumption_watts;      // Power consumption
    hmr_bottleneck_type_t bottleneck;   // Primary bottleneck
} hmr_performance_trend_point_t;

// Profiler configuration
typedef struct {
    hmr_profile_mode_t mode;            // Profiling mode
    
    // Sampling settings
    uint32_t sample_frequency_hz;       // Sampling frequency
    uint32_t sample_window_size;        // Number of samples to keep
    bool enable_continuous_profiling;   // Continuous vs on-demand
    
    // Analysis settings
    bool enable_bottleneck_detection;   // Enable bottleneck analysis
    bool enable_optimization_suggestions; // Enable optimization advice
    bool enable_regression_tracking;    // Track performance regressions
    bool enable_comparative_analysis;   // Compare with baselines
    
    // Thresholds
    float performance_warning_threshold; // Performance warning threshold
    float regression_threshold_percent; // Regression detection threshold
    uint64_t gpu_time_warning_ns;       // GPU time warning threshold
    float memory_usage_warning_mb;      // Memory usage warning
    
    // Filtering
    float min_frame_time_ms;            // Minimum frame time to profile
    float max_frame_time_ms;            // Maximum frame time to profile
    bool filter_outliers;               // Filter statistical outliers
    
    // Output settings
    bool enable_real_time_feedback;     // Real-time performance feedback
    bool enable_detailed_logging;       // Detailed performance logging
    char output_directory[256];         // Directory for detailed reports
} hmr_profiler_config_t;

// Performance profiler API

// Initialization and configuration
int32_t hmr_profiler_init(const hmr_profiler_config_t* config);
void hmr_profiler_cleanup(void);
int32_t hmr_profiler_update_config(const hmr_profiler_config_t* config);
void hmr_profiler_set_mode(hmr_profile_mode_t mode);

// Profiling control
int32_t hmr_profiler_start_session(const char* session_name);
int32_t hmr_profiler_end_session(void);
int32_t hmr_profiler_pause_profiling(void);
int32_t hmr_profiler_resume_profiling(void);

// Shader profiling
#ifdef __OBJC__
int32_t hmr_profiler_begin_shader_capture(id<MTLCommandBuffer> command_buffer, 
                                          const char* shader_name);
int32_t hmr_profiler_end_shader_capture(id<MTLCommandBuffer> command_buffer,
                                       const hmr_gpu_metrics_t* metrics);
#endif

// Manual metrics submission
int32_t hmr_profiler_submit_metrics(const char* shader_name, const hmr_gpu_metrics_t* metrics);
int32_t hmr_profiler_submit_frame_metrics(uint64_t frame_number, float frame_time_ms);

// Analysis and results
int32_t hmr_profiler_analyze_shader(const char* shader_name, hmr_performance_analysis_t* analysis);
int32_t hmr_profiler_get_bottleneck_summary(hmr_bottleneck_type_t* bottlenecks, 
                                           float* severities, uint32_t max_count, 
                                           uint32_t* actual_count);

// Trend analysis
int32_t hmr_profiler_get_performance_trend(const char* shader_name, 
                                          hmr_performance_trend_point_t* trend_points,
                                          uint32_t max_points, uint32_t* actual_points);
int32_t hmr_profiler_detect_regressions(const char* shader_name, bool* has_regression,
                                       float* regression_severity);

// Baseline management
int32_t hmr_profiler_set_baseline(const char* shader_name, const char* baseline_name);
int32_t hmr_profiler_compare_with_baseline(const char* shader_name, const char* baseline_name,
                                          float* performance_change_percent);
int32_t hmr_profiler_list_baselines(const char* shader_name, char baselines[][64], 
                                   uint32_t max_count, uint32_t* actual_count);

// Optimization suggestions
int32_t hmr_profiler_get_optimization_suggestions(const char* shader_name,
                                                 hmr_performance_analysis_t* suggestions);
int32_t hmr_profiler_estimate_optimization_impact(const char* shader_name, 
                                                 const char* optimization_type,
                                                 float* estimated_improvement);

// Statistics and reporting
typedef struct {
    uint32_t total_shaders_profiled;    // Total number of shaders profiled
    uint64_t total_samples_collected;   // Total performance samples
    uint32_t bottlenecks_detected;      // Total bottlenecks detected
    uint32_t regressions_detected;      // Total regressions detected
    
    float avg_profiling_overhead;       // Average profiling overhead
    float total_profiling_time_hours;   // Total profiling time
    
    struct {
        uint32_t memory_bandwidth;      // Memory bandwidth bottlenecks
        uint32_t alu_limited;          // ALU-limited bottlenecks
        uint32_t texture_cache;        // Texture cache bottlenecks
        uint32_t overdraw;             // Overdraw bottlenecks
        uint32_t thermal;              // Thermal throttling events
    } bottleneck_counts;
} hmr_profiler_statistics_t;

void hmr_profiler_get_statistics(hmr_profiler_statistics_t* stats);
void hmr_profiler_reset_statistics(void);

// Report generation
int32_t hmr_profiler_generate_report(const char* output_path, const char* format);
int32_t hmr_profiler_export_metrics(const char* output_path, const char* shader_name);
int32_t hmr_profiler_export_trends(const char* output_path, uint64_t start_time, uint64_t end_time);

// Callback registration
void hmr_profiler_set_callbacks(
    void (*on_bottleneck_detected)(const char* shader_name, hmr_bottleneck_type_t bottleneck, float severity),
    void (*on_regression_detected)(const char* shader_name, float regression_percent),
    void (*on_analysis_complete)(const char* shader_name, const hmr_performance_analysis_t* analysis),
    void (*on_optimization_suggested)(const char* shader_name, const char* suggestion)
);

// Utility functions
const char* hmr_profiler_bottleneck_to_string(hmr_bottleneck_type_t bottleneck);
const char* hmr_profiler_severity_to_string(hmr_performance_severity_t severity);
float hmr_profiler_calculate_performance_score(const hmr_gpu_metrics_t* metrics);
bool hmr_profiler_is_thermal_throttling(float temperature, float throttling_factor);

#ifdef __cplusplus
}
#endif

#endif // HMR_SHADER_PERFORMANCE_PROFILER_H