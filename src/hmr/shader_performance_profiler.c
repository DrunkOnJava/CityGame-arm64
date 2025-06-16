/*
 * SimCity ARM64 - Advanced Shader Performance Profiler Implementation
 * Real-time Shader Performance Analysis and Bottleneck Detection
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Week 2 - Day 6: Advanced Shader Features
 * 
 * Performance Targets:
 * - Profiling overhead: <2% GPU time
 * - Analysis latency: <5ms
 * - Bottleneck detection: <10ms
 * - Memory overhead: <16MB
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <sys/time.h>
#include <pthread.h>
#include <dispatch/dispatch.h>

#include "shader_performance_profiler.h"
#include "module_interface.h"

// Profiler constants
#define MAX_PROFILED_SHADERS 64
#define MAX_SAMPLES_PER_SHADER 1000
#define MAX_BASELINE_CONFIGS 8
#define PERFORMANCE_HISTORY_SIZE 100
#define ANALYSIS_WINDOW_SIZE 50

// Performance sample
typedef struct {
    uint64_t timestamp;
    hmr_gpu_metrics_t metrics;
    float performance_score;
    hmr_bottleneck_type_t detected_bottleneck;
} hmr_performance_sample_t;

// Shader profile data
typedef struct {
    char shader_name[64];
    bool is_active;
    
    // Sample data
    hmr_performance_sample_t samples[MAX_SAMPLES_PER_SHADER];
    uint32_t sample_count;
    uint32_t sample_write_index;
    
    // Analysis results
    hmr_performance_analysis_t latest_analysis;
    uint64_t last_analysis_time;
    
    // Baseline configurations
    struct {
        char name[32];
        hmr_performance_sample_t baseline_sample;
        bool is_valid;
    } baselines[MAX_BASELINE_CONFIGS];
    uint32_t baseline_count;
    
    // Trend tracking
    hmr_performance_trend_point_t trend_history[PERFORMANCE_HISTORY_SIZE];
    uint32_t trend_count;
    uint32_t trend_write_index;
    
    // Statistics
    float avg_gpu_time_ms;
    float min_gpu_time_ms;
    float max_gpu_time_ms;
    uint32_t bottleneck_counts[8];  // Count per bottleneck type
} hmr_shader_profile_t;

// Profiler state
typedef struct {
    hmr_profiler_config_t config;
    bool is_active;
    char current_session[64];
    
    // Shader profiles
    hmr_shader_profile_t shader_profiles[MAX_PROFILED_SHADERS];
    uint32_t profile_count;
    
    // Global statistics
    hmr_profiler_statistics_t statistics;
    
    // Analysis state
    dispatch_queue_t analysis_queue;
    dispatch_group_t analysis_group;
    
    // Synchronization
    pthread_rwlock_t data_lock;
    
    // Callbacks
    void (*on_bottleneck_detected)(const char* shader_name, hmr_bottleneck_type_t bottleneck, float severity);
    void (*on_regression_detected)(const char* shader_name, float regression_percent);
    void (*on_analysis_complete)(const char* shader_name, const hmr_performance_analysis_t* analysis);
    void (*on_optimization_suggested)(const char* shader_name, const char* suggestion);
} hmr_profiler_t;

// Global profiler instance
static hmr_profiler_t* g_profiler = NULL;

// Utility functions
static uint64_t hmr_get_current_time_ns(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (uint64_t)tv.tv_sec * 1000000000ULL + (uint64_t)tv.tv_usec * 1000ULL;
}

static hmr_shader_profile_t* hmr_find_shader_profile(const char* shader_name) {
    if (!shader_name) return NULL;
    
    for (uint32_t i = 0; i < g_profiler->profile_count; i++) {
        if (strcmp(g_profiler->shader_profiles[i].shader_name, shader_name) == 0) {
            return &g_profiler->shader_profiles[i];
        }
    }
    
    return NULL;
}

static hmr_shader_profile_t* hmr_create_shader_profile(const char* shader_name) {
    if (g_profiler->profile_count >= MAX_PROFILED_SHADERS) {
        return NULL;
    }
    
    hmr_shader_profile_t* profile = &g_profiler->shader_profiles[g_profiler->profile_count++];
    memset(profile, 0, sizeof(hmr_shader_profile_t));
    
    strncpy(profile->shader_name, shader_name, sizeof(profile->shader_name) - 1);
    profile->is_active = true;
    profile->min_gpu_time_ms = INFINITY;
    
    return profile;
}

// Calculate performance score based on metrics
static float hmr_calculate_performance_score_internal(const hmr_gpu_metrics_t* metrics) {
    if (!metrics) return 0.0f;
    
    float score = 1.0f;
    
    // GPU utilization factor (higher is better up to a point)
    float gpu_util_factor = fminf(1.0f, metrics->gpu_overall_utilization / 0.85f);
    score *= gpu_util_factor;
    
    // Memory efficiency factor
    float memory_efficiency = 1.0f - (metrics->memory_bandwidth_utilization * 0.3f);
    score *= fmaxf(0.1f, memory_efficiency);
    
    // Cache miss penalty
    float cache_penalty = 1.0f - (metrics->cache_miss_rate / 100.0f * 0.4f);
    score *= fmaxf(0.2f, cache_penalty);
    
    // Overdraw penalty
    if (metrics->overdraw_factor > 1) {
        float overdraw_penalty = 1.0f / (float)metrics->overdraw_factor;
        score *= fmaxf(0.3f, overdraw_penalty);
    }
    
    // Thermal throttling penalty
    score *= (1.0f - (1.0f - metrics->thermal_throttling_factor) * 0.5f);
    
    return fmaxf(0.0f, fminf(1.0f, score));
}

// Detect primary bottleneck from metrics
static hmr_bottleneck_type_t hmr_detect_bottleneck(const hmr_gpu_metrics_t* metrics) {
    if (!metrics) return HMR_BOTTLENECK_NONE;
    
    // Check thermal throttling first
    if (metrics->thermal_throttling_factor < 0.9f) {
        return HMR_BOTTLENECK_THERMAL_THROTTLING;
    }
    
    // Check memory bandwidth
    if (metrics->memory_bandwidth_utilization > 0.85f) {
        return HMR_BOTTLENECK_MEMORY_BANDWIDTH;
    }
    
    // Check texture cache misses
    if (metrics->cache_miss_rate > 15.0f) {
        return HMR_BOTTLENECK_TEXTURE_CACHE;
    }
    
    // Check fragment overdraw
    if (metrics->overdraw_factor > 3) {
        return HMR_BOTTLENECK_FRAGMENT_OVERDRAW;
    }
    
    // Check GPU utilization for ALU bottleneck
    if (metrics->fragment_shader_utilization > 0.9f || metrics->compute_utilization > 0.9f) {
        return HMR_BOTTLENECK_ALU;
    }
    
    // Check vertex processing
    if (metrics->vertex_shader_utilization > 0.85f) {
        return HMR_BOTTLENECK_VERTEX_FETCH;
    }
    
    return HMR_BOTTLENECK_NONE;
}

// Generate optimization recommendations
static void hmr_generate_recommendations(hmr_performance_analysis_t* analysis, 
                                        const hmr_gpu_metrics_t* metrics) {
    analysis->recommendation_count = 0;
    
    switch (analysis->primary_bottleneck) {
        case HMR_BOTTLENECK_MEMORY_BANDWIDTH:
            if (analysis->recommendation_count < 8) {
                auto* rec = &analysis->recommendations[analysis->recommendation_count++];
                rec->severity = HMR_PERF_SEVERITY_WARNING;
                strcpy(rec->title, "Memory Bandwidth Optimization");
                strcpy(rec->description, "High memory bandwidth utilization detected");
                strcpy(rec->suggested_action, "Reduce texture resolution or use compressed formats");
                rec->estimated_improvement = 0.25f;
                
                analysis->optimization_flags.reduce_texture_resolution = true;
                analysis->optimization_flags.reduce_memory_bandwidth = true;
            }
            break;
            
        case HMR_BOTTLENECK_FRAGMENT_OVERDRAW:
            if (analysis->recommendation_count < 8) {
                auto* rec = &analysis->recommendations[analysis->recommendation_count++];
                rec->severity = HMR_PERF_SEVERITY_WARNING;
                strcpy(rec->title, "Overdraw Reduction");
                strcpy(rec->description, "High fragment overdraw detected");
                strcpy(rec->suggested_action, "Implement depth pre-pass or sort geometry front-to-back");
                rec->estimated_improvement = 0.35f;
                
                analysis->optimization_flags.reduce_overdraw = true;
            }
            break;
            
        case HMR_BOTTLENECK_TEXTURE_CACHE:
            if (analysis->recommendation_count < 8) {
                auto* rec = &analysis->recommendations[analysis->recommendation_count++];
                rec->severity = HMR_PERF_SEVERITY_NOTICE;
                strcpy(rec->title, "Texture Cache Optimization");
                strcpy(rec->description, "High texture cache miss rate");
                strcpy(rec->suggested_action, "Improve texture coordinate locality or reduce texture count");
                rec->estimated_improvement = 0.20f;
                
                analysis->optimization_flags.improve_cache_locality = true;
            }
            break;
            
        case HMR_BOTTLENECK_ALU:
            if (analysis->recommendation_count < 8) {
                auto* rec = &analysis->recommendations[analysis->recommendation_count++];
                rec->severity = HMR_PERF_SEVERITY_INFO;
                strcpy(rec->title, "ALU Optimization");
                strcpy(rec->description, "Compute/fragment shader ALU bound");
                strcpy(rec->suggested_action, "Reduce shader complexity or optimize algorithms");
                rec->estimated_improvement = 0.30f;
                
                analysis->optimization_flags.optimize_branching = true;
                analysis->optimization_flags.reduce_register_pressure = true;
            }
            break;
            
        case HMR_BOTTLENECK_THERMAL_THROTTLING:
            if (analysis->recommendation_count < 8) {
                auto* rec = &analysis->recommendations[analysis->recommendation_count++];
                rec->severity = HMR_PERF_SEVERITY_CRITICAL;
                strcpy(rec->title, "Thermal Management");
                strcpy(rec->description, "GPU thermal throttling detected");
                strcpy(rec->suggested_action, "Reduce GPU workload or improve cooling");
                rec->estimated_improvement = 0.50f;
            }
            break;
            
        default:
            // General optimization suggestions
            if (metrics->gpu_overall_utilization < 0.6f && analysis->recommendation_count < 8) {
                auto* rec = &analysis->recommendations[analysis->recommendation_count++];
                rec->severity = HMR_PERF_SEVERITY_INFO;
                strcpy(rec->title, "GPU Underutilization");
                strcpy(rec->description, "GPU utilization is low");
                strcpy(rec->suggested_action, "Consider increasing quality settings or resolution");
                rec->estimated_improvement = -0.10f; // Negative because it's about increasing quality
            }
            break;
    }
}

// Perform detailed performance analysis
static void hmr_analyze_shader_performance(hmr_shader_profile_t* profile) {
    if (!profile || profile->sample_count == 0) return;
    
    hmr_performance_analysis_t* analysis = &profile->latest_analysis;
    memset(analysis, 0, sizeof(hmr_performance_analysis_t));
    
    strncpy(analysis->shader_name, profile->shader_name, sizeof(analysis->shader_name) - 1);
    analysis->analysis_timestamp = hmr_get_current_time_ns();
    
    // Analyze recent samples
    uint32_t analysis_samples = fminf(profile->sample_count, ANALYSIS_WINDOW_SIZE);
    uint32_t start_index = (profile->sample_write_index + MAX_SAMPLES_PER_SHADER - analysis_samples) % MAX_SAMPLES_PER_SHADER;
    
    float total_performance = 0.0f;
    uint32_t bottleneck_counts[8] = {0};
    hmr_gpu_metrics_t avg_metrics = {0};
    
    for (uint32_t i = 0; i < analysis_samples; i++) {
        uint32_t index = (start_index + i) % MAX_SAMPLES_PER_SHADER;
        hmr_performance_sample_t* sample = &profile->samples[index];
        
        total_performance += sample->performance_score;
        bottleneck_counts[sample->detected_bottleneck]++;
        
        // Accumulate metrics for averaging
        avg_metrics.gpu_overall_utilization += sample->metrics.gpu_overall_utilization;
        avg_metrics.memory_bandwidth_utilization += sample->metrics.memory_bandwidth_utilization;
        avg_metrics.cache_miss_rate += sample->metrics.cache_miss_rate;
        avg_metrics.overdraw_factor += sample->metrics.overdraw_factor;
        avg_metrics.thermal_throttling_factor += sample->metrics.thermal_throttling_factor;
    }
    
    // Calculate averages
    analysis->overall_performance_score = total_performance / analysis_samples;
    avg_metrics.gpu_overall_utilization /= analysis_samples;
    avg_metrics.memory_bandwidth_utilization /= analysis_samples;
    avg_metrics.cache_miss_rate /= analysis_samples;
    avg_metrics.overdraw_factor /= analysis_samples;
    avg_metrics.thermal_throttling_factor /= analysis_samples;
    
    // Determine primary bottleneck
    uint32_t max_bottleneck_count = 0;
    for (int i = 0; i < 8; i++) {
        if (bottleneck_counts[i] > max_bottleneck_count) {
            max_bottleneck_count = bottleneck_counts[i];
            analysis->primary_bottleneck = (hmr_bottleneck_type_t)i;
        }
    }
    
    analysis->bottleneck_severity = (float)max_bottleneck_count / analysis_samples;
    
    // Calculate efficiency scores
    analysis->efficiency_score = avg_metrics.gpu_overall_utilization;
    analysis->memory_efficiency_score = 1.0f - avg_metrics.memory_bandwidth_utilization;
    analysis->power_efficiency_score = avg_metrics.thermal_throttling_factor;
    
    // Generate bottleneck description
    switch (analysis->primary_bottleneck) {
        case HMR_BOTTLENECK_MEMORY_BANDWIDTH:
            snprintf(analysis->bottleneck_description, sizeof(analysis->bottleneck_description),
                    "Memory bandwidth limited (%.1f%% utilization)", 
                    avg_metrics.memory_bandwidth_utilization * 100.0f);
            break;
        case HMR_BOTTLENECK_FRAGMENT_OVERDRAW:
            snprintf(analysis->bottleneck_description, sizeof(analysis->bottleneck_description),
                    "Fragment overdraw bottleneck (%.1fx overdraw)", avg_metrics.overdraw_factor);
            break;
        case HMR_BOTTLENECK_TEXTURE_CACHE:
            snprintf(analysis->bottleneck_description, sizeof(analysis->bottleneck_description),
                    "Texture cache misses (%.1f%% miss rate)", avg_metrics.cache_miss_rate);
            break;
        case HMR_BOTTLENECK_THERMAL_THROTTLING:
            snprintf(analysis->bottleneck_description, sizeof(analysis->bottleneck_description),
                    "Thermal throttling (%.1f%% performance)", 
                    avg_metrics.thermal_throttling_factor * 100.0f);
            break;
        default:
            snprintf(analysis->bottleneck_description, sizeof(analysis->bottleneck_description),
                    "No significant bottleneck detected");
            break;
    }
    
    // Generate optimization recommendations
    hmr_generate_recommendations(analysis, &avg_metrics);
    
    profile->last_analysis_time = analysis->analysis_timestamp;
    
    // Call callback if registered
    if (g_profiler->on_analysis_complete) {
        g_profiler->on_analysis_complete(profile->shader_name, analysis);
    }
}

// Public API implementation

int32_t hmr_profiler_init(const hmr_profiler_config_t* config) {
    if (g_profiler) {
        return HMR_ERROR_ALREADY_EXISTS;
    }
    
    if (!config) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    g_profiler = calloc(1, sizeof(hmr_profiler_t));
    if (!g_profiler) {
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    // Copy configuration
    memcpy(&g_profiler->config, config, sizeof(hmr_profiler_config_t));
    
    // Initialize synchronization
    if (pthread_rwlock_init(&g_profiler->data_lock, NULL) != 0) {
        free(g_profiler);
        g_profiler = NULL;
        return HMR_ERROR_SYSTEM_ERROR;
    }
    
    // Create analysis queue
    g_profiler->analysis_queue = dispatch_queue_create("com.simcity.hmr.profiler_analysis", 
                                                      DISPATCH_QUEUE_CONCURRENT);
    g_profiler->analysis_group = dispatch_group_create();
    
    printf("HMR Shader Profiler: Initialized successfully\n");
    printf("  Mode: %d\n", config->mode);
    printf("  Sample frequency: %u Hz\n", config->sample_frequency_hz);
    printf("  Bottleneck detection: %s\n", config->enable_bottleneck_detection ? "Yes" : "No");
    
    return HMR_SUCCESS;
}

int32_t hmr_profiler_submit_metrics(const char* shader_name, const hmr_gpu_metrics_t* metrics) {
    if (!g_profiler || !shader_name || !metrics || !g_profiler->is_active) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    pthread_rwlock_wrlock(&g_profiler->data_lock);
    
    // Find or create shader profile
    hmr_shader_profile_t* profile = hmr_find_shader_profile(shader_name);
    if (!profile) {
        profile = hmr_create_shader_profile(shader_name);
        if (!profile) {
            pthread_rwlock_unlock(&g_profiler->data_lock);
            return HMR_ERROR_OUT_OF_MEMORY;
        }
    }
    
    // Create performance sample
    hmr_performance_sample_t sample;
    sample.timestamp = hmr_get_current_time_ns();
    memcpy(&sample.metrics, metrics, sizeof(hmr_gpu_metrics_t));
    sample.performance_score = hmr_calculate_performance_score_internal(metrics);
    sample.detected_bottleneck = hmr_detect_bottleneck(metrics);
    
    // Add sample to profile
    uint32_t index = profile->sample_write_index;
    memcpy(&profile->samples[index], &sample, sizeof(hmr_performance_sample_t));
    
    profile->sample_write_index = (profile->sample_write_index + 1) % MAX_SAMPLES_PER_SHADER;
    if (profile->sample_count < MAX_SAMPLES_PER_SHADER) {
        profile->sample_count++;
    }
    
    // Update statistics
    float gpu_time_ms = (metrics->gpu_end_time_ns - metrics->gpu_start_time_ns) / 1000000.0f;
    profile->avg_gpu_time_ms = (profile->avg_gpu_time_ms + gpu_time_ms) / 2.0f;
    profile->min_gpu_time_ms = fminf(profile->min_gpu_time_ms, gpu_time_ms);
    profile->max_gpu_time_ms = fmaxf(profile->max_gpu_time_ms, gpu_time_ms);
    profile->bottleneck_counts[sample.detected_bottleneck]++;
    
    g_profiler->statistics.total_samples_collected++;
    
    pthread_rwlock_unlock(&g_profiler->data_lock);
    
    // Trigger analysis if configured
    if (g_profiler->config.enable_bottleneck_detection) {
        dispatch_group_async(g_profiler->analysis_group, g_profiler->analysis_queue, ^{
            hmr_analyze_shader_performance(profile);
        });
    }
    
    // Check for bottleneck detection
    if (sample.detected_bottleneck != HMR_BOTTLENECK_NONE && g_profiler->on_bottleneck_detected) {
        float severity = 1.0f - sample.performance_score;
        g_profiler->on_bottleneck_detected(shader_name, sample.detected_bottleneck, severity);
    }
    
    return HMR_SUCCESS;
}

int32_t hmr_profiler_analyze_shader(const char* shader_name, hmr_performance_analysis_t* analysis) {
    if (!g_profiler || !shader_name || !analysis) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    pthread_rwlock_rdlock(&g_profiler->data_lock);
    
    hmr_shader_profile_t* profile = hmr_find_shader_profile(shader_name);
    if (!profile) {
        pthread_rwlock_unlock(&g_profiler->data_lock);
        return HMR_ERROR_NOT_FOUND;
    }
    
    // Return latest analysis if available
    if (profile->last_analysis_time > 0) {
        memcpy(analysis, &profile->latest_analysis, sizeof(hmr_performance_analysis_t));
        pthread_rwlock_unlock(&g_profiler->data_lock);
        return HMR_SUCCESS;
    }
    
    pthread_rwlock_unlock(&g_profiler->data_lock);
    
    // Trigger new analysis
    hmr_analyze_shader_performance(profile);
    
    pthread_rwlock_rdlock(&g_profiler->data_lock);
    memcpy(analysis, &profile->latest_analysis, sizeof(hmr_performance_analysis_t));
    pthread_rwlock_unlock(&g_profiler->data_lock);
    
    return HMR_SUCCESS;
}

float hmr_profiler_calculate_performance_score(const hmr_gpu_metrics_t* metrics) {
    return hmr_calculate_performance_score_internal(metrics);
}

const char* hmr_profiler_bottleneck_to_string(hmr_bottleneck_type_t bottleneck) {
    switch (bottleneck) {
        case HMR_BOTTLENECK_NONE: return "None";
        case HMR_BOTTLENECK_MEMORY_BANDWIDTH: return "Memory Bandwidth";
        case HMR_BOTTLENECK_ALU: return "ALU/Compute";
        case HMR_BOTTLENECK_TEXTURE_CACHE: return "Texture Cache";
        case HMR_BOTTLENECK_VERTEX_FETCH: return "Vertex Fetch";
        case HMR_BOTTLENECK_FRAGMENT_OVERDRAW: return "Fragment Overdraw";
        case HMR_BOTTLENECK_SYNCHRONIZATION: return "Synchronization";
        case HMR_BOTTLENECK_DRIVER_OVERHEAD: return "Driver Overhead";
        case HMR_BOTTLENECK_THERMAL_THROTTLING: return "Thermal Throttling";
        default: return "Unknown";
    }
}

void hmr_profiler_get_statistics(hmr_profiler_statistics_t* stats) {
    if (!g_profiler || !stats) return;
    
    pthread_rwlock_rdlock(&g_profiler->data_lock);
    memcpy(stats, &g_profiler->statistics, sizeof(hmr_profiler_statistics_t));
    pthread_rwlock_unlock(&g_profiler->data_lock);
}

void hmr_profiler_set_callbacks(
    void (*on_bottleneck_detected)(const char* shader_name, hmr_bottleneck_type_t bottleneck, float severity),
    void (*on_regression_detected)(const char* shader_name, float regression_percent),
    void (*on_analysis_complete)(const char* shader_name, const hmr_performance_analysis_t* analysis),
    void (*on_optimization_suggested)(const char* shader_name, const char* suggestion)
) {
    if (!g_profiler) return;
    
    g_profiler->on_bottleneck_detected = on_bottleneck_detected;
    g_profiler->on_regression_detected = on_regression_detected;
    g_profiler->on_analysis_complete = on_analysis_complete;
    g_profiler->on_optimization_suggested = on_optimization_suggested;
}

void hmr_profiler_cleanup(void) {
    if (!g_profiler) return;
    
    // Wait for pending analysis
    dispatch_group_wait(g_profiler->analysis_group, DISPATCH_TIME_FOREVER);
    
    // Release dispatch objects
    if (g_profiler->analysis_queue) {
        dispatch_release(g_profiler->analysis_queue);
    }
    if (g_profiler->analysis_group) {
        dispatch_release(g_profiler->analysis_group);
    }
    
    // Destroy synchronization objects
    pthread_rwlock_destroy(&g_profiler->data_lock);
    
    free(g_profiler);
    g_profiler = NULL;
    
    printf("HMR Shader Profiler: Cleanup complete\n");
}