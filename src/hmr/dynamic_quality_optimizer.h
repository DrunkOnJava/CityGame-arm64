#ifndef DYNAMIC_QUALITY_OPTIMIZER_H
#define DYNAMIC_QUALITY_OPTIMIZER_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

// Forward declarations
typedef struct quality_optimizer_t quality_optimizer_t;
typedef struct quality_profile_t quality_profile_t;
typedef struct performance_metrics_t performance_metrics_t;
typedef struct device_capabilities_t device_capabilities_t;

// Quality optimization modes
typedef enum {
    QUALITY_MODE_ULTRA = 0,      // Maximum quality, highest resource usage
    QUALITY_MODE_HIGH = 1,       // High quality, moderate resource usage
    QUALITY_MODE_MEDIUM = 2,     // Balanced quality and performance
    QUALITY_MODE_LOW = 3,        // Performance focused, reduced quality
    QUALITY_MODE_MINIMUM = 4,    // Minimum quality, maximum performance
    QUALITY_MODE_ADAPTIVE = 5,   // AI-driven adaptive quality
    QUALITY_MODE_CUSTOM = 6      // User-defined custom profile
} quality_mode_t;

// Asset quality levels
typedef enum {
    ASSET_QUALITY_ORIGINAL = 0,  // Original, unmodified assets
    ASSET_QUALITY_HIGH = 1,      // High quality (90-100% of original)
    ASSET_QUALITY_MEDIUM = 2,    // Medium quality (70-90% of original)
    ASSET_QUALITY_LOW = 3,       // Low quality (50-70% of original)
    ASSET_QUALITY_MINIMUM = 4    // Minimum quality (25-50% of original)
} asset_quality_level_t;

// Performance optimization targets
typedef enum {
    PERF_TARGET_FRAMERATE = 0,   // Optimize for consistent framerate
    PERF_TARGET_MEMORY = 1,      // Optimize for memory usage
    PERF_TARGET_BANDWIDTH = 2,   // Optimize for network bandwidth
    PERF_TARGET_BATTERY = 3,     // Optimize for battery life
    PERF_TARGET_THERMAL = 4,     // Optimize for thermal management
    PERF_TARGET_BALANCED = 5     // Balanced optimization
} performance_target_t;

// Real-time performance metrics
typedef struct performance_metrics_t {
    // Framerate metrics
    float current_fps;
    float average_fps;
    float minimum_fps;
    float target_fps;
    float fps_stability_score;  // 0.0-1.0, higher is more stable
    
    // Memory metrics
    uint64_t current_memory_usage;
    uint64_t peak_memory_usage;
    uint64_t available_memory;
    float memory_pressure_score;  // 0.0-1.0, higher is more pressure
    
    // GPU metrics
    float gpu_utilization_percent;
    float gpu_memory_utilization_percent;
    float gpu_temperature_celsius;
    uint32_t gpu_frequency_mhz;
    
    // CPU metrics
    float cpu_utilization_percent;
    float cpu_temperature_celsius;
    uint32_t active_cpu_cores;
    
    // Network metrics
    uint32_t download_bandwidth_kbps;
    uint32_t upload_bandwidth_kbps;
    uint32_t network_latency_ms;
    uint32_t packet_loss_percent;
    
    // Battery metrics (mobile devices)
    float battery_level_percent;
    float battery_temperature_celsius;
    bool is_charging;
    uint32_t estimated_battery_life_minutes;
    
    // Thermal metrics
    float system_temperature_celsius;
    bool thermal_throttling_active;
    float thermal_headroom_percent;
    
    // Asset loading metrics
    uint32_t assets_loading;
    uint32_t asset_load_queue_size;
    float average_asset_load_time_ms;
    uint64_t total_asset_memory_footprint;
    
    // Quality metrics
    float perceived_quality_score;
    uint32_t quality_degradation_events;
    float user_satisfaction_score;
} performance_metrics_t;

// Device capability assessment
typedef struct device_capabilities_t {
    // Hardware specifications
    char device_model[64];
    char gpu_model[64];
    char cpu_model[64];
    
    // Memory capabilities
    uint64_t total_system_memory;
    uint64_t total_video_memory;
    uint64_t available_system_memory;
    uint64_t available_video_memory;
    
    // Processing capabilities
    uint32_t cpu_core_count;
    uint32_t cpu_max_frequency_mhz;
    bool supports_simd;
    bool supports_hardware_compression;
    
    // Graphics capabilities
    uint32_t max_texture_size;
    bool supports_texture_compression;
    bool supports_hdr;
    bool supports_high_refresh_rate;
    uint32_t max_render_targets;
    bool supports_compute_shaders;
    
    // Network capabilities
    bool has_wifi;
    bool has_cellular;
    uint32_t max_download_speed_mbps;
    bool is_metered_connection;
    
    // Power characteristics
    bool is_battery_powered;
    bool supports_power_management;
    uint32_t thermal_design_power;
    
    // Quality support levels
    asset_quality_level_t max_supported_texture_quality;
    asset_quality_level_t max_supported_audio_quality;
    asset_quality_level_t max_supported_mesh_quality;
    
    // Performance characteristics
    float performance_tier;  // 0.0-1.0, higher is more capable
    bool is_low_end_device;
    bool is_high_end_device;
    
    // Reliability metrics
    float stability_score;
    uint32_t crash_frequency;
    float thermal_reliability;
} device_capabilities_t;

// Quality profile configuration
typedef struct quality_profile_t {
    char profile_name[64];
    quality_mode_t mode;
    performance_target_t primary_target;
    
    // Quality settings per asset type
    struct {
        asset_quality_level_t textures;
        asset_quality_level_t audio;
        asset_quality_level_t meshes;
        asset_quality_level_t shaders;
        asset_quality_level_t effects;
    } asset_quality_levels;
    
    // Performance thresholds
    float minimum_fps_threshold;
    float maximum_memory_usage_percent;
    float maximum_gpu_utilization_percent;
    float maximum_cpu_utilization_percent;
    float maximum_temperature_celsius;
    
    // Optimization weights
    float quality_weight;          // 0.0-1.0, importance of visual quality
    float performance_weight;      // 0.0-1.0, importance of performance
    float memory_weight;           // 0.0-1.0, importance of memory efficiency
    float power_weight;           // 0.0-1.0, importance of power efficiency
    
    // Adaptive behavior
    bool enable_automatic_adjustment;
    float adjustment_sensitivity;   // 0.0-1.0, higher is more responsive
    uint32_t adjustment_interval_ms;
    bool enable_predictive_scaling;
    
    // Quality constraints
    asset_quality_level_t minimum_quality_floor;
    asset_quality_level_t maximum_quality_ceiling;
    bool allow_dynamic_resolution;
    bool allow_asset_streaming;
    
    // User preferences
    bool prioritize_visual_quality;
    bool prioritize_smooth_framerate;
    bool prioritize_battery_life;
    bool prioritize_thermal_management;
} quality_profile_t;

// Quality adjustment recommendation
typedef struct quality_adjustment_t {
    bool should_adjust;
    char reason[256];
    
    // Recommended changes
    quality_mode_t recommended_mode;
    quality_profile_t recommended_profile;
    
    // Specific asset adjustments
    struct {
        bool should_reduce_texture_quality;
        bool should_reduce_audio_quality;
        bool should_reduce_mesh_quality;
        bool should_reduce_effect_quality;
        bool should_enable_streaming;
        bool should_reduce_resolution;
        asset_quality_level_t target_texture_quality;
        asset_quality_level_t target_audio_quality;
        asset_quality_level_t target_mesh_quality;
    } asset_adjustments;
    
    // Performance predictions
    float predicted_fps_improvement;
    float predicted_memory_reduction_percent;
    float predicted_thermal_improvement;
    float predicted_battery_life_extension_percent;
    
    // Quality impact assessment
    float predicted_quality_loss;
    float user_experience_impact_score;
    bool reversible_adjustment;
    
    // Confidence and urgency
    float confidence_score;        // 0.0-1.0
    float urgency_score;          // 0.0-1.0, higher means more urgent
    uint32_t estimated_improvement_time_ms;
} quality_adjustment_t;

// Main quality optimizer structure
typedef struct quality_optimizer_t {
    // Configuration
    quality_profile_t active_profile;
    device_capabilities_t device_caps;
    performance_target_t primary_target;
    
    // Current state
    performance_metrics_t current_metrics;
    performance_metrics_t baseline_metrics;
    quality_mode_t current_mode;
    
    // Historical data
    struct {
        uint32_t sample_count;
        uint32_t capacity;
        performance_metrics_t* metrics_history;
        quality_adjustment_t* adjustment_history;
        uint64_t* timestamps;
    } history;
    
    // Optimization statistics
    uint64_t total_adjustments;
    uint64_t successful_adjustments;
    float average_quality_score;
    float average_performance_score;
    uint32_t thermal_events_prevented;
    
    // Machine learning components
    struct {
        bool enabled;
        float model_accuracy;
        uint32_t training_samples;
        float prediction_confidence;
        bool needs_retraining;
    } ml_predictor;
    
    // Real-time monitoring
    bool is_monitoring;
    uint32_t monitoring_interval_ms;
    uint32_t last_adjustment_timestamp;
    uint32_t adjustment_cooldown_ms;
    
    // Thread safety
    void* mutex;
    
    // Callbacks
    void (*on_quality_adjustment)(const quality_adjustment_t* adjustment);
    void (*on_performance_warning)(const performance_metrics_t* metrics, const char* warning);
    void (*on_profile_change)(quality_mode_t old_mode, quality_mode_t new_mode);
    void (*on_error)(const char* error_message);
} quality_optimizer_t;

// Core quality optimization functions
int quality_optimizer_init(quality_optimizer_t** optimizer, const device_capabilities_t* device_caps);
void quality_optimizer_destroy(quality_optimizer_t* optimizer);

// Profile management
int quality_optimizer_set_profile(quality_optimizer_t* optimizer, const quality_profile_t* profile);
int quality_optimizer_get_profile(quality_optimizer_t* optimizer, quality_profile_t* profile);
int quality_optimizer_set_mode(quality_optimizer_t* optimizer, quality_mode_t mode);

// Performance monitoring
int quality_optimizer_update_metrics(quality_optimizer_t* optimizer, 
                                    const performance_metrics_t* metrics);
int quality_optimizer_start_monitoring(quality_optimizer_t* optimizer, uint32_t interval_ms);
int quality_optimizer_stop_monitoring(quality_optimizer_t* optimizer);

// Quality adjustment
int quality_optimizer_evaluate_adjustment(quality_optimizer_t* optimizer, 
                                         quality_adjustment_t* adjustment);
int quality_optimizer_apply_adjustment(quality_optimizer_t* optimizer, 
                                      const quality_adjustment_t* adjustment);
int quality_optimizer_auto_optimize(quality_optimizer_t* optimizer);

// Device capability assessment
int quality_optimizer_assess_device(device_capabilities_t* capabilities);
int quality_optimizer_update_device_caps(quality_optimizer_t* optimizer, 
                                        const device_capabilities_t* caps);

// Performance prediction
int quality_optimizer_predict_performance(quality_optimizer_t* optimizer,
                                         const quality_profile_t* proposed_profile,
                                         performance_metrics_t* predicted_metrics);

// Statistics and reporting
int quality_optimizer_get_statistics(quality_optimizer_t* optimizer, struct {
    uint64_t total_runtime_ms;
    float average_fps;
    float average_quality_score;
    uint32_t adjustment_count;
    float optimization_effectiveness;
    uint32_t thermal_events_prevented;
    float battery_life_extension_percent;
} *stats);

// Utility functions
const char* quality_mode_to_string(quality_mode_t mode);
const char* asset_quality_level_to_string(asset_quality_level_t level);
const char* performance_target_to_string(performance_target_t target);

// Advanced features
int quality_optimizer_enable_predictive_scaling(quality_optimizer_t* optimizer, bool enable);
int quality_optimizer_set_ml_prediction(quality_optimizer_t* optimizer, bool enable);
int quality_optimizer_calibrate_device(quality_optimizer_t* optimizer, uint32_t duration_ms);

// Integration helpers
int quality_optimizer_get_recommended_asset_quality(quality_optimizer_t* optimizer,
                                                   const char* asset_type,
                                                   asset_quality_level_t* quality);
int quality_optimizer_should_stream_asset(quality_optimizer_t* optimizer,
                                         const char* asset_path,
                                         uint64_t asset_size,
                                         bool* should_stream);

#endif // DYNAMIC_QUALITY_OPTIMIZER_H