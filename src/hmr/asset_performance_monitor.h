#ifndef ASSET_PERFORMANCE_MONITOR_H
#define ASSET_PERFORMANCE_MONITOR_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

// Forward declarations
typedef struct performance_monitor_t performance_monitor_t;
typedef struct asset_performance_data_t asset_performance_data_t;
typedef struct bottleneck_analysis_t bottleneck_analysis_t;
typedef struct performance_prediction_t performance_prediction_t;

// Performance monitoring modes
typedef enum {
    MONITOR_MODE_REALTIME = 0,     // Real-time monitoring with immediate alerts
    MONITOR_MODE_BACKGROUND = 1,   // Background monitoring with periodic reports
    MONITOR_MODE_PROFILING = 2,    // Detailed profiling for development
    MONITOR_MODE_PRODUCTION = 3,   // Production monitoring with minimal overhead
    MONITOR_MODE_BENCHMARK = 4     // Benchmarking mode for testing
} performance_monitor_mode_t;

// Asset performance categories
typedef enum {
    PERF_CATEGORY_LOADING = 0,     // Asset loading and initialization
    PERF_CATEGORY_MEMORY = 1,      // Memory usage and allocation
    PERF_CATEGORY_RENDERING = 2,   // Rendering and GPU performance
    PERF_CATEGORY_STREAMING = 3,   // Asset streaming and I/O
    PERF_CATEGORY_PROCESSING = 4,  // Asset processing and conversion
    PERF_CATEGORY_CACHING = 5,     // Cache performance and hit rates
    PERF_CATEGORY_NETWORK = 6,     // Network transfer performance
    PERF_CATEGORY_COMPRESSION = 7  // Compression and decompression
} performance_category_t;

// Bottleneck types
typedef enum {
    BOTTLENECK_CPU = 0,           // CPU processing bottleneck
    BOTTLENECK_MEMORY = 1,        // Memory bandwidth or capacity bottleneck
    BOTTLENECK_GPU = 2,           // GPU processing bottleneck
    BOTTLENECK_IO = 3,            // I/O subsystem bottleneck
    BOTTLENECK_NETWORK = 4,       // Network bandwidth bottleneck
    BOTTLENECK_CACHE = 5,         // Cache miss bottleneck
    BOTTLENECK_THERMAL = 6,       // Thermal throttling bottleneck
    BOTTLENECK_POWER = 7,         // Power limiting bottleneck
    BOTTLENECK_SYNCHRONIZATION = 8 // Thread synchronization bottleneck
} bottleneck_type_t;

// Performance alert levels
typedef enum {
    ALERT_LEVEL_INFO = 0,         // Informational alert
    ALERT_LEVEL_WARNING = 1,      // Performance warning
    ALERT_LEVEL_CRITICAL = 2,     // Critical performance issue
    ALERT_LEVEL_EMERGENCY = 3     // Emergency requiring immediate action
} performance_alert_level_t;

// Detailed asset performance metrics
typedef struct asset_performance_data_t {
    char asset_path[256];
    char asset_type[32];
    uint64_t asset_size;
    uint64_t timestamp_microseconds;
    
    // Loading performance
    struct {
        uint32_t load_time_microseconds;
        uint32_t decode_time_microseconds;
        uint32_t upload_time_microseconds;
        uint32_t initialization_time_microseconds;
        uint32_t total_time_microseconds;
        bool load_successful;
        char error_message[128];
    } loading;
    
    // Memory performance
    struct {
        uint64_t allocated_bytes;
        uint64_t peak_usage_bytes;
        uint64_t current_usage_bytes;
        uint32_t allocation_count;
        uint32_t deallocation_count;
        uint32_t fragmentation_percent;
        float memory_pressure_score;
    } memory;
    
    // Rendering performance
    struct {
        uint32_t draw_calls;
        uint32_t triangles_rendered;
        uint32_t vertices_processed;
        uint32_t texture_bindings;
        uint32_t shader_switches;
        uint32_t render_time_microseconds;
        float gpu_utilization_percent;
        uint64_t vram_usage_bytes;
    } rendering;
    
    // Streaming performance
    struct {
        uint32_t bytes_streamed;
        uint32_t stream_requests;
        uint32_t stream_failures;
        uint32_t average_bandwidth_kbps;
        uint32_t stream_latency_ms;
        float stream_efficiency_score;
        bool is_streaming_active;
    } streaming;
    
    // Processing performance
    struct {
        uint32_t compression_time_microseconds;
        uint32_t decompression_time_microseconds;
        uint32_t conversion_time_microseconds;
        uint32_t validation_time_microseconds;
        float compression_ratio;
        float processing_efficiency;
        uint32_t cpu_utilization_percent;
    } processing;
    
    // Caching performance
    struct {
        uint32_t cache_hits;
        uint32_t cache_misses;
        uint32_t cache_evictions;
        float hit_rate_percent;
        uint32_t cache_size_bytes;
        uint32_t access_frequency;
        float cache_efficiency_score;
    } caching;
    
    // Quality metrics
    struct {
        float visual_quality_score;
        float audio_quality_score;
        float user_satisfaction_score;
        uint32_t quality_degradation_events;
        bool quality_acceptable;
    } quality;
    
    // Predictive metrics
    struct {
        float predicted_load_time;
        float predicted_memory_usage;
        float confidence_score;
        bool needs_optimization;
        float optimization_potential;
    } predictions;
} asset_performance_data_t;

// Bottleneck analysis results
typedef struct bottleneck_analysis_t {
    bottleneck_type_t primary_bottleneck;
    bottleneck_type_t secondary_bottleneck;
    float severity_score;        // 0.0-1.0, higher is more severe
    float impact_score;          // 0.0-1.0, impact on overall performance
    
    // Detailed analysis
    struct {
        float cpu_utilization_percent;
        float memory_pressure_percent;
        float gpu_utilization_percent;
        float io_wait_percent;
        float network_utilization_percent;
        float cache_miss_rate_percent;
        float thermal_throttling_percent;
        float power_throttling_percent;
    } bottleneck_metrics;
    
    // Recommendations
    char primary_recommendation[256];
    char secondary_recommendation[256];
    float estimated_improvement_percent;
    uint32_t implementation_difficulty;  // 1-10 scale
    
    // Affected assets
    uint32_t affected_asset_count;
    char affected_assets[16][64];       // Up to 16 most affected assets
    
    // Time analysis
    uint64_t detection_timestamp;
    uint32_t duration_seconds;
    uint32_t frequency_per_hour;
    bool is_persistent;
    bool is_critical;
} bottleneck_analysis_t;

// Performance prediction structure
typedef struct performance_prediction_t {
    uint64_t prediction_timestamp;
    uint32_t prediction_horizon_seconds;
    
    // Predicted metrics
    struct {
        float predicted_fps;
        float predicted_memory_usage_percent;
        float predicted_gpu_utilization_percent;
        float predicted_cpu_utilization_percent;
        float predicted_load_time_ms;
        float predicted_quality_score;
    } predictions;
    
    // Confidence intervals
    struct {
        float fps_confidence;
        float memory_confidence;
        float gpu_confidence;
        float cpu_confidence;
        float load_time_confidence;
        float quality_confidence;
    } confidence;
    
    // Risk assessment
    struct {
        float bottleneck_risk;
        float quality_degradation_risk;
        float performance_regression_risk;
        float system_instability_risk;
        float user_experience_impact_risk;
    } risks;
    
    // Recommendations
    char optimization_recommendations[512];
    uint32_t recommended_actions_count;
    struct {
        char action[128];
        float expected_benefit;
        uint32_t implementation_cost;
        uint32_t priority;
    } recommended_actions[8];
} performance_prediction_t;

// Performance alert structure
typedef struct performance_alert_t {
    uint64_t alert_id;
    uint64_t timestamp;
    performance_alert_level_t level;
    performance_category_t category;
    
    char title[128];
    char description[512];
    char asset_path[256];
    
    // Alert metrics
    float severity_score;
    float urgency_score;
    uint32_t frequency_count;
    uint32_t duration_seconds;
    
    // Context information
    float current_fps;
    float memory_usage_percent;
    float cpu_utilization_percent;
    float gpu_utilization_percent;
    
    // Recommended actions
    char immediate_action[256];
    char long_term_solution[256];
    bool auto_fix_available;
    bool user_action_required;
    
    // Alert state
    bool acknowledged;
    bool resolved;
    uint64_t resolution_timestamp;
    char resolution_notes[256];
} performance_alert_t;

// Main performance monitor structure
typedef struct performance_monitor_t {
    // Configuration
    performance_monitor_mode_t mode;
    uint32_t sampling_interval_ms;
    uint32_t analysis_interval_ms;
    uint32_t reporting_interval_ms;
    
    // Monitoring state
    bool is_monitoring;
    bool is_profiling;
    uint64_t monitoring_start_time;
    uint64_t total_monitoring_time;
    
    // Performance data storage
    struct {
        uint32_t capacity;
        uint32_t count;
        uint32_t current_index;
        asset_performance_data_t* data;
        uint64_t* timestamps;
    } performance_history;
    
    // Bottleneck detection
    struct {
        uint32_t analysis_window_size;
        uint32_t detection_threshold;
        float severity_threshold;
        bottleneck_analysis_t current_analysis;
        bottleneck_analysis_t* analysis_history;
        uint32_t analysis_history_count;
    } bottleneck_detector;
    
    // Predictive analytics
    struct {
        bool enabled;
        uint32_t prediction_window_seconds;
        float model_accuracy;
        performance_prediction_t current_prediction;
        performance_prediction_t* prediction_history;
        uint32_t prediction_history_count;
    } predictor;
    
    // Alert management
    struct {
        uint32_t active_alert_count;
        uint32_t total_alert_count;
        performance_alert_t active_alerts[32];
        performance_alert_t* alert_history;
        uint32_t alert_history_capacity;
        uint32_t alert_history_count;
    } alerts;
    
    // Performance statistics
    struct {
        uint64_t total_assets_monitored;
        uint64_t total_performance_events;
        uint64_t total_bottlenecks_detected;
        uint64_t total_predictions_made;
        float average_prediction_accuracy;
        uint32_t critical_alerts_generated;
        uint32_t performance_improvements_suggested;
    } statistics;
    
    // Real-time metrics aggregation
    struct {
        float current_average_fps;
        float current_memory_usage_percent;
        float current_cpu_utilization;
        float current_gpu_utilization;
        uint32_t assets_loading;
        uint32_t assets_streaming;
        float overall_performance_score;
    } realtime_metrics;
    
    // Thread safety
    void* mutex;
    void* analysis_thread;
    bool analysis_thread_running;
    
    // Callbacks
    void (*on_performance_alert)(const performance_alert_t* alert);
    void (*on_bottleneck_detected)(const bottleneck_analysis_t* analysis);
    void (*on_prediction_update)(const performance_prediction_t* prediction);
    void (*on_performance_report)(const struct {
        uint64_t report_timestamp;
        float average_fps;
        float memory_efficiency;
        uint32_t bottleneck_count;
        float overall_score;
    } *report);
} performance_monitor_t;

// Core monitoring functions
int performance_monitor_init(performance_monitor_t** monitor, performance_monitor_mode_t mode);
void performance_monitor_destroy(performance_monitor_t* monitor);

// Monitoring control
int performance_monitor_start(performance_monitor_t* monitor);
int performance_monitor_stop(performance_monitor_t* monitor);
int performance_monitor_pause(performance_monitor_t* monitor);
int performance_monitor_resume(performance_monitor_t* monitor);

// Data collection
int performance_monitor_record_asset(performance_monitor_t* monitor, 
                                    const asset_performance_data_t* data);
int performance_monitor_record_loading(performance_monitor_t* monitor, 
                                      const char* asset_path, uint32_t load_time_us);
int performance_monitor_record_memory(performance_monitor_t* monitor, 
                                     const char* asset_path, uint64_t memory_usage);
int performance_monitor_record_rendering(performance_monitor_t* monitor, 
                                        const char* asset_path, uint32_t render_time_us);

// Analysis functions
int performance_monitor_analyze_bottlenecks(performance_monitor_t* monitor, 
                                           bottleneck_analysis_t* analysis);
int performance_monitor_predict_performance(performance_monitor_t* monitor, 
                                           uint32_t horizon_seconds,
                                           performance_prediction_t* prediction);

// Alert management
int performance_monitor_check_alerts(performance_monitor_t* monitor);
int performance_monitor_acknowledge_alert(performance_monitor_t* monitor, uint64_t alert_id);
int performance_monitor_resolve_alert(performance_monitor_t* monitor, uint64_t alert_id, 
                                     const char* resolution_notes);

// Reporting
int performance_monitor_generate_report(performance_monitor_t* monitor, struct {
    uint64_t report_period_start;
    uint64_t report_period_end;
    float average_fps;
    float memory_efficiency_score;
    uint32_t total_bottlenecks;
    uint32_t critical_alerts;
    float overall_performance_score;
    char recommendations[1024];
} *report);

// Configuration
int performance_monitor_set_sampling_rate(performance_monitor_t* monitor, uint32_t interval_ms);
int performance_monitor_set_alert_thresholds(performance_monitor_t* monitor, 
                                            float fps_threshold, 
                                            float memory_threshold,
                                            float cpu_threshold);
int performance_monitor_enable_prediction(performance_monitor_t* monitor, bool enable);

// Statistics and queries
int performance_monitor_get_realtime_metrics(performance_monitor_t* monitor, struct {
    float current_fps;
    float memory_usage_percent;
    float cpu_utilization_percent;
    float gpu_utilization_percent;
    uint32_t active_alerts;
    float performance_score;
} *metrics);

int performance_monitor_get_asset_performance(performance_monitor_t* monitor, 
                                             const char* asset_path,
                                             asset_performance_data_t* data);

// Utility functions
const char* performance_category_to_string(performance_category_t category);
const char* bottleneck_type_to_string(bottleneck_type_t type);
const char* alert_level_to_string(performance_alert_level_t level);
float calculate_performance_score(const asset_performance_data_t* data);

// Advanced analytics
int performance_monitor_export_data(performance_monitor_t* monitor, 
                                   const char* export_path, 
                                   const char* format); // "json", "csv", "binary"
int performance_monitor_import_baseline(performance_monitor_t* monitor, 
                                       const char* baseline_path);
int performance_monitor_compare_with_baseline(performance_monitor_t* monitor, 
                                             struct {
                                                 float fps_delta_percent;
                                                 float memory_delta_percent;
                                                 uint32_t new_bottlenecks;
                                                 float regression_score;
                                             } *comparison);

#endif // ASSET_PERFORMANCE_MONITOR_H