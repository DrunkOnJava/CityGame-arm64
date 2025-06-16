#include "dynamic_quality_optimizer.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <pthread.h>
#include <sys/time.h>
#include <unistd.h>

// Performance thresholds and constants
#define TARGET_FPS_STABILITY 0.9f
#define MEMORY_PRESSURE_THRESHOLD 0.8f
#define THERMAL_WARNING_THRESHOLD 85.0f
#define ADJUSTMENT_COOLDOWN_MS 2000
#define HISTORY_CAPACITY 1000
#define PERFORMANCE_SAMPLE_WINDOW 30

// Quality scoring weights
#define QUALITY_WEIGHT_VISUAL 0.4f
#define QUALITY_WEIGHT_AUDIO 0.2f
#define QUALITY_WEIGHT_PERFORMANCE 0.3f
#define QUALITY_WEIGHT_UX 0.1f

// Device assessment helpers
static float calculate_device_performance_tier(const device_capabilities_t* caps) {
    float tier = 0.0f;
    
    // Memory contribution (0-0.3)
    tier += (caps->total_system_memory / (16.0f * 1024 * 1024 * 1024)) * 0.15f; // Max 16GB
    tier += (caps->total_video_memory / (8.0f * 1024 * 1024 * 1024)) * 0.15f;   // Max 8GB
    
    // CPU contribution (0-0.3)
    tier += (caps->cpu_core_count / 16.0f) * 0.15f;  // Max 16 cores
    tier += (caps->cpu_max_frequency_mhz / 4000.0f) * 0.15f;  // Max 4GHz
    
    // GPU contribution (0-0.4)
    tier += caps->supports_compute_shaders ? 0.1f : 0.0f;
    tier += caps->supports_texture_compression ? 0.1f : 0.0f;
    tier += caps->supports_hdr ? 0.1f : 0.0f;
    tier += (caps->max_texture_size / 8192.0f) * 0.1f;  // Max 8K textures
    
    return fminf(tier, 1.0f);
}

static bool is_low_end_device(const device_capabilities_t* caps) {
    return caps->performance_tier < 0.3f ||
           caps->total_system_memory < (4ULL * 1024 * 1024 * 1024) ||  // < 4GB RAM
           caps->cpu_core_count < 4 ||
           caps->is_battery_powered;
}

static bool is_high_end_device(const device_capabilities_t* caps) {
    return caps->performance_tier > 0.7f &&
           caps->total_system_memory >= (16ULL * 1024 * 1024 * 1024) &&  // >= 16GB RAM
           caps->cpu_core_count >= 8 &&
           caps->supports_compute_shaders;
}

// Performance analysis functions
static float calculate_fps_stability(const performance_metrics_t* metrics_history, 
                                   uint32_t sample_count) {
    if (sample_count < 10) return 1.0f;
    
    float mean_fps = 0.0f;
    for (uint32_t i = 0; i < sample_count; i++) {
        mean_fps += metrics_history[i].current_fps;
    }
    mean_fps /= sample_count;
    
    float variance = 0.0f;
    for (uint32_t i = 0; i < sample_count; i++) {
        float diff = metrics_history[i].current_fps - mean_fps;
        variance += diff * diff;
    }
    variance /= sample_count;
    
    float coefficient_of_variation = sqrtf(variance) / mean_fps;
    return fmaxf(0.0f, 1.0f - coefficient_of_variation);
}

static float calculate_performance_score(const performance_metrics_t* metrics,
                                       const quality_profile_t* profile) {
    float score = 0.0f;
    
    // FPS score (0-0.4)
    float fps_ratio = metrics->current_fps / profile->minimum_fps_threshold;
    score += fminf(fps_ratio, 1.0f) * 0.4f;
    
    // Memory score (0-0.3)
    float memory_usage = (float)metrics->current_memory_usage / 
                        (metrics->current_memory_usage + metrics->available_memory);
    score += (1.0f - memory_usage) * 0.3f;
    
    // Thermal score (0-0.2)
    float thermal_ratio = metrics->system_temperature_celsius / profile->maximum_temperature_celsius;
    score += fmaxf(0.0f, 1.0f - thermal_ratio) * 0.2f;
    
    // Stability score (0-0.1)
    score += metrics->fps_stability_score * 0.1f;
    
    return fminf(score, 1.0f);
}

static float calculate_quality_score(const quality_profile_t* profile) {
    float score = 0.0f;
    
    // Asset quality contributions
    score += (profile->asset_quality_levels.textures / 4.0f) * 0.35f;
    score += (profile->asset_quality_levels.audio / 4.0f) * 0.15f;
    score += (profile->asset_quality_levels.meshes / 4.0f) * 0.25f;
    score += (profile->asset_quality_levels.shaders / 4.0f) * 0.15f;
    score += (profile->asset_quality_levels.effects / 4.0f) * 0.1f;
    
    return score;
}

// Quality adjustment logic
static void generate_quality_adjustment(quality_optimizer_t* optimizer,
                                       quality_adjustment_t* adjustment) {
    const performance_metrics_t* metrics = &optimizer->current_metrics;
    const quality_profile_t* profile = &optimizer->active_profile;
    
    memset(adjustment, 0, sizeof(quality_adjustment_t));
    
    // Check if adjustment is needed
    bool fps_below_threshold = metrics->current_fps < profile->minimum_fps_threshold;
    bool memory_pressure = metrics->memory_pressure_score > MEMORY_PRESSURE_THRESHOLD;
    bool thermal_warning = metrics->system_temperature_celsius > THERMAL_WARNING_THRESHOLD;
    bool stability_issue = metrics->fps_stability_score < TARGET_FPS_STABILITY;
    
    if (!fps_below_threshold && !memory_pressure && !thermal_warning && !stability_issue) {
        adjustment->should_adjust = false;
        strcpy(adjustment->reason, "Performance metrics within acceptable ranges");
        return;
    }
    
    adjustment->should_adjust = true;
    
    // Determine primary issue and generate reason
    if (fps_below_threshold) {
        snprintf(adjustment->reason, sizeof(adjustment->reason),
                "FPS below threshold: %.1f < %.1f", 
                metrics->current_fps, profile->minimum_fps_threshold);
    } else if (memory_pressure) {
        snprintf(adjustment->reason, sizeof(adjustment->reason),
                "High memory pressure: %.1f%%", metrics->memory_pressure_score * 100);
    } else if (thermal_warning) {
        snprintf(adjustment->reason, sizeof(adjustment->reason),
                "Thermal warning: %.1f°C", metrics->system_temperature_celsius);
    } else {
        strcpy(adjustment->reason, "FPS instability detected");
    }
    
    // Calculate adjustment severity (0.0-1.0)
    float severity = 0.0f;
    if (fps_below_threshold) {
        severity = fmaxf(severity, 1.0f - (metrics->current_fps / profile->minimum_fps_threshold));
    }
    if (memory_pressure) {
        severity = fmaxf(severity, metrics->memory_pressure_score - MEMORY_PRESSURE_THRESHOLD);
    }
    if (thermal_warning) {
        severity = fmaxf(severity, (metrics->system_temperature_celsius - THERMAL_WARNING_THRESHOLD) / 20.0f);
    }
    
    // Generate asset quality adjustments based on severity
    if (severity > 0.8f) {
        // Aggressive optimization needed
        adjustment->asset_adjustments.should_reduce_texture_quality = true;
        adjustment->asset_adjustments.should_reduce_mesh_quality = true;
        adjustment->asset_adjustments.should_reduce_effect_quality = true;
        adjustment->asset_adjustments.should_enable_streaming = true;
        adjustment->asset_adjustments.target_texture_quality = ASSET_QUALITY_LOW;
        adjustment->asset_adjustments.target_mesh_quality = ASSET_QUALITY_LOW;
        adjustment->recommended_mode = QUALITY_MODE_LOW;
    } else if (severity > 0.5f) {
        // Moderate optimization
        adjustment->asset_adjustments.should_reduce_texture_quality = true;
        adjustment->asset_adjustments.should_reduce_effect_quality = true;
        adjustment->asset_adjustments.target_texture_quality = ASSET_QUALITY_MEDIUM;
        adjustment->recommended_mode = QUALITY_MODE_MEDIUM;
    } else {
        // Light optimization
        adjustment->asset_adjustments.should_reduce_effect_quality = true;
        adjustment->recommended_mode = QUALITY_MODE_HIGH;
    }
    
    // Predict improvements
    float texture_reduction = adjustment->asset_adjustments.should_reduce_texture_quality ? 0.3f : 0.0f;
    float mesh_reduction = adjustment->asset_adjustments.should_reduce_mesh_quality ? 0.2f : 0.0f;
    float effect_reduction = adjustment->asset_adjustments.should_reduce_effect_quality ? 0.15f : 0.0f;
    
    adjustment->predicted_memory_reduction_percent = (texture_reduction + mesh_reduction) * 100;
    adjustment->predicted_fps_improvement = severity * 20.0f; // Up to 20 FPS improvement
    adjustment->predicted_thermal_improvement = thermal_warning ? 5.0f : 0.0f;
    adjustment->predicted_battery_life_extension_percent = severity * 15.0f;
    
    // Calculate quality impact
    adjustment->predicted_quality_loss = (texture_reduction + mesh_reduction + effect_reduction) / 3.0f;
    adjustment->user_experience_impact_score = adjustment->predicted_quality_loss * 0.7f +
                                              (1.0f - severity) * 0.3f;
    
    adjustment->confidence_score = 0.8f + (severity * 0.2f);
    adjustment->urgency_score = severity;
    adjustment->estimated_improvement_time_ms = 500 + (uint32_t)(severity * 1500);
    adjustment->reversible_adjustment = severity < 0.7f;
}

// Core implementation
int quality_optimizer_init(quality_optimizer_t** optimizer, const device_capabilities_t* device_caps) {
    if (!optimizer || !device_caps) return -1;
    
    *optimizer = calloc(1, sizeof(quality_optimizer_t));
    if (!*optimizer) return -1;
    
    quality_optimizer_t* opt = *optimizer;
    
    // Copy device capabilities
    opt->device_caps = *device_caps;
    
    // Calculate device characteristics
    opt->device_caps.performance_tier = calculate_device_performance_tier(device_caps);
    opt->device_caps.is_low_end_device = is_low_end_device(device_caps);
    opt->device_caps.is_high_end_device = is_high_end_device(device_caps);
    
    // Initialize default profile based on device capabilities
    quality_profile_t* profile = &opt->active_profile;
    strcpy(profile->profile_name, "Auto-Generated");
    
    if (opt->device_caps.is_high_end_device) {
        profile->mode = QUALITY_MODE_HIGH;
        profile->asset_quality_levels.textures = ASSET_QUALITY_HIGH;
        profile->asset_quality_levels.audio = ASSET_QUALITY_HIGH;
        profile->asset_quality_levels.meshes = ASSET_QUALITY_HIGH;
        profile->asset_quality_levels.shaders = ASSET_QUALITY_HIGH;
        profile->asset_quality_levels.effects = ASSET_QUALITY_HIGH;
        profile->minimum_fps_threshold = 60.0f;
    } else if (opt->device_caps.is_low_end_device) {
        profile->mode = QUALITY_MODE_MEDIUM;
        profile->asset_quality_levels.textures = ASSET_QUALITY_MEDIUM;
        profile->asset_quality_levels.audio = ASSET_QUALITY_MEDIUM;
        profile->asset_quality_levels.meshes = ASSET_QUALITY_MEDIUM;
        profile->asset_quality_levels.shaders = ASSET_QUALITY_MEDIUM;
        profile->asset_quality_levels.effects = ASSET_QUALITY_LOW;
        profile->minimum_fps_threshold = 30.0f;
    } else {
        profile->mode = QUALITY_MODE_MEDIUM;
        profile->asset_quality_levels.textures = ASSET_QUALITY_MEDIUM;
        profile->asset_quality_levels.audio = ASSET_QUALITY_HIGH;
        profile->asset_quality_levels.meshes = ASSET_QUALITY_MEDIUM;
        profile->asset_quality_levels.shaders = ASSET_QUALITY_MEDIUM;
        profile->asset_quality_levels.effects = ASSET_QUALITY_MEDIUM;
        profile->minimum_fps_threshold = 45.0f;
    }
    
    // Set common profile defaults
    profile->primary_target = PERF_TARGET_BALANCED;
    profile->maximum_memory_usage_percent = 0.8f;
    profile->maximum_gpu_utilization_percent = 0.9f;
    profile->maximum_cpu_utilization_percent = 0.8f;
    profile->maximum_temperature_celsius = 85.0f;
    
    profile->quality_weight = 0.6f;
    profile->performance_weight = 0.4f;
    profile->enable_automatic_adjustment = true;
    profile->adjustment_sensitivity = 0.7f;
    profile->adjustment_interval_ms = 1000;
    
    // Initialize history tracking
    opt->history.capacity = HISTORY_CAPACITY;
    opt->history.metrics_history = calloc(HISTORY_CAPACITY, sizeof(performance_metrics_t));
    opt->history.adjustment_history = calloc(HISTORY_CAPACITY, sizeof(quality_adjustment_t));
    opt->history.timestamps = calloc(HISTORY_CAPACITY, sizeof(uint64_t));
    
    // Initialize threading
    opt->mutex = malloc(sizeof(pthread_mutex_t));
    pthread_mutex_init((pthread_mutex_t*)opt->mutex, NULL);
    
    // Initialize ML predictor
    opt->ml_predictor.enabled = true;
    opt->ml_predictor.model_accuracy = 0.85f;
    opt->ml_predictor.prediction_confidence = 0.8f;
    
    opt->current_mode = profile->mode;
    opt->monitoring_interval_ms = 1000;
    opt->adjustment_cooldown_ms = ADJUSTMENT_COOLDOWN_MS;
    
    return 0;
}

void quality_optimizer_destroy(quality_optimizer_t* optimizer) {
    if (!optimizer) return;
    
    if (optimizer->is_monitoring) {
        quality_optimizer_stop_monitoring(optimizer);
    }
    
    free(optimizer->history.metrics_history);
    free(optimizer->history.adjustment_history);
    free(optimizer->history.timestamps);
    
    pthread_mutex_destroy((pthread_mutex_t*)optimizer->mutex);
    free(optimizer->mutex);
    
    free(optimizer);
}

int quality_optimizer_update_metrics(quality_optimizer_t* optimizer,
                                    const performance_metrics_t* metrics) {
    if (!optimizer || !metrics) return -1;
    
    pthread_mutex_lock((pthread_mutex_t*)optimizer->mutex);
    
    // Update current metrics
    optimizer->current_metrics = *metrics;
    
    // Calculate stability score
    if (optimizer->history.sample_count > 0) {
        optimizer->current_metrics.fps_stability_score = 
            calculate_fps_stability(optimizer->history.metrics_history,
                                   fminf(optimizer->history.sample_count, PERFORMANCE_SAMPLE_WINDOW));
    }
    
    // Add to history
    if (optimizer->history.sample_count < optimizer->history.capacity) {
        uint32_t idx = optimizer->history.sample_count++;
        optimizer->history.metrics_history[idx] = *metrics;
        
        struct timeval tv;
        gettimeofday(&tv, NULL);
        optimizer->history.timestamps[idx] = tv.tv_sec * 1000000 + tv.tv_usec;
    } else {
        // Circular buffer
        memmove(optimizer->history.metrics_history,
                optimizer->history.metrics_history + 1,
                (optimizer->history.capacity - 1) * sizeof(performance_metrics_t));
        memmove(optimizer->history.timestamps,
                optimizer->history.timestamps + 1,
                (optimizer->history.capacity - 1) * sizeof(uint64_t));
        
        optimizer->history.metrics_history[optimizer->history.capacity - 1] = *metrics;
        
        struct timeval tv;
        gettimeofday(&tv, NULL);
        optimizer->history.timestamps[optimizer->history.capacity - 1] = 
            tv.tv_sec * 1000000 + tv.tv_usec;
    }
    
    pthread_mutex_unlock((pthread_mutex_t*)optimizer->mutex);
    
    return 0;
}

int quality_optimizer_evaluate_adjustment(quality_optimizer_t* optimizer,
                                         quality_adjustment_t* adjustment) {
    if (!optimizer || !adjustment) return -1;
    
    pthread_mutex_lock((pthread_mutex_t*)optimizer->mutex);
    
    generate_quality_adjustment(optimizer, adjustment);
    
    pthread_mutex_unlock((pthread_mutex_t*)optimizer->mutex);
    
    return 0;
}

int quality_optimizer_apply_adjustment(quality_optimizer_t* optimizer,
                                      const quality_adjustment_t* adjustment) {
    if (!optimizer || !adjustment || !adjustment->should_adjust) return -1;
    
    pthread_mutex_lock((pthread_mutex_t*)optimizer->mutex);
    
    // Check cooldown period
    struct timeval tv;
    gettimeofday(&tv, NULL);
    uint32_t current_time = tv.tv_sec * 1000 + tv.tv_usec / 1000;
    
    if (current_time - optimizer->last_adjustment_timestamp < optimizer->adjustment_cooldown_ms) {
        pthread_mutex_unlock((pthread_mutex_t*)optimizer->mutex);
        return -2; // Cooldown active
    }
    
    // Apply profile changes
    quality_mode_t old_mode = optimizer->current_mode;
    optimizer->current_mode = adjustment->recommended_mode;
    
    // Update quality profile based on recommendations
    if (adjustment->asset_adjustments.should_reduce_texture_quality) {
        optimizer->active_profile.asset_quality_levels.textures = 
            adjustment->asset_adjustments.target_texture_quality;
    }
    if (adjustment->asset_adjustments.should_reduce_mesh_quality) {
        optimizer->active_profile.asset_quality_levels.meshes = 
            adjustment->asset_adjustments.target_mesh_quality;
    }
    if (adjustment->asset_adjustments.should_reduce_effect_quality) {
        optimizer->active_profile.asset_quality_levels.effects = ASSET_QUALITY_LOW;
    }
    
    // Update statistics
    optimizer->total_adjustments++;
    optimizer->last_adjustment_timestamp = current_time;
    
    // Store adjustment in history
    if (optimizer->history.sample_count < optimizer->history.capacity) {
        optimizer->history.adjustment_history[optimizer->total_adjustments % optimizer->history.capacity] = 
            *adjustment;
    }
    
    // Trigger callbacks
    if (optimizer->on_profile_change && old_mode != optimizer->current_mode) {
        optimizer->on_profile_change(old_mode, optimizer->current_mode);
    }
    
    if (optimizer->on_quality_adjustment) {
        optimizer->on_quality_adjustment(adjustment);
    }
    
    pthread_mutex_unlock((pthread_mutex_t*)optimizer->mutex);
    
    return 0;
}

int quality_optimizer_auto_optimize(quality_optimizer_t* optimizer) {
    if (!optimizer) return -1;
    
    quality_adjustment_t adjustment;
    
    // Evaluate current performance
    int result = quality_optimizer_evaluate_adjustment(optimizer, &adjustment);
    if (result != 0) return result;
    
    // Apply adjustment if needed
    if (adjustment.should_adjust && adjustment.urgency_score > 0.3f) {
        return quality_optimizer_apply_adjustment(optimizer, &adjustment);
    }
    
    return 0;
}

int quality_optimizer_get_statistics(quality_optimizer_t* optimizer, struct {
    uint64_t total_runtime_ms;
    float average_fps;
    float average_quality_score;
    uint32_t adjustment_count;
    float optimization_effectiveness;
    uint32_t thermal_events_prevented;
    float battery_life_extension_percent;
} *stats) {
    if (!optimizer || !stats) return -1;
    
    pthread_mutex_lock((pthread_mutex_t*)optimizer->mutex);
    
    // Calculate runtime
    stats->total_runtime_ms = 0;
    if (optimizer->history.sample_count > 1) {
        stats->total_runtime_ms = (optimizer->history.timestamps[optimizer->history.sample_count - 1] -
                                 optimizer->history.timestamps[0]) / 1000;
    }
    
    // Calculate average FPS
    stats->average_fps = 0.0f;
    for (uint32_t i = 0; i < optimizer->history.sample_count; i++) {
        stats->average_fps += optimizer->history.metrics_history[i].current_fps;
    }
    if (optimizer->history.sample_count > 0) {
        stats->average_fps /= optimizer->history.sample_count;
    }
    
    // Calculate average quality score
    stats->average_quality_score = calculate_quality_score(&optimizer->active_profile);
    
    stats->adjustment_count = (uint32_t)optimizer->total_adjustments;
    stats->optimization_effectiveness = optimizer->total_adjustments > 0 ? 
        (float)optimizer->successful_adjustments / optimizer->total_adjustments : 0.0f;
    stats->thermal_events_prevented = optimizer->thermal_events_prevented;
    stats->battery_life_extension_percent = 0.0f; // Would be calculated from power measurements
    
    pthread_mutex_unlock((pthread_mutex_t*)optimizer->mutex);
    
    return 0;
}

const char* quality_mode_to_string(quality_mode_t mode) {
    switch (mode) {
        case QUALITY_MODE_ULTRA: return "Ultra";
        case QUALITY_MODE_HIGH: return "High";
        case QUALITY_MODE_MEDIUM: return "Medium";
        case QUALITY_MODE_LOW: return "Low";
        case QUALITY_MODE_MINIMUM: return "Minimum";
        case QUALITY_MODE_ADAPTIVE: return "Adaptive";
        case QUALITY_MODE_CUSTOM: return "Custom";
        default: return "Unknown";
    }
}

const char* asset_quality_level_to_string(asset_quality_level_t level) {
    switch (level) {
        case ASSET_QUALITY_ORIGINAL: return "Original";
        case ASSET_QUALITY_HIGH: return "High";
        case ASSET_QUALITY_MEDIUM: return "Medium";
        case ASSET_QUALITY_LOW: return "Low";
        case ASSET_QUALITY_MINIMUM: return "Minimum";
        default: return "Unknown";
    }
}

const char* performance_target_to_string(performance_target_t target) {
    switch (target) {
        case PERF_TARGET_FRAMERATE: return "Framerate";
        case PERF_TARGET_MEMORY: return "Memory";
        case PERF_TARGET_BANDWIDTH: return "Bandwidth";
        case PERF_TARGET_BATTERY: return "Battery";
        case PERF_TARGET_THERMAL: return "Thermal";
        case PERF_TARGET_BALANCED: return "Balanced";
        default: return "Unknown";
    }
}