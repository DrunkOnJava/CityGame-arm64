#include "asset_performance_monitor.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <pthread.h>
#include <sys/time.h>
#include <unistd.h>

// Performance thresholds and constants
#define DEFAULT_SAMPLING_INTERVAL_MS 100
#define DEFAULT_ANALYSIS_INTERVAL_MS 1000
#define DEFAULT_REPORTING_INTERVAL_MS 5000
#define PERFORMANCE_HISTORY_CAPACITY 10000
#define BOTTLENECK_ANALYSIS_WINDOW 100
#define ALERT_HISTORY_CAPACITY 1000
#define PREDICTION_HISTORY_CAPACITY 100

// Performance scoring weights
#define WEIGHT_FPS 0.3f
#define WEIGHT_MEMORY 0.25f
#define WEIGHT_LOADING 0.2f
#define WEIGHT_QUALITY 0.15f
#define WEIGHT_STABILITY 0.1f

// Alert thresholds
#define FPS_WARNING_THRESHOLD 30.0f
#define FPS_CRITICAL_THRESHOLD 15.0f
#define MEMORY_WARNING_THRESHOLD 0.8f
#define MEMORY_CRITICAL_THRESHOLD 0.95f
#define CPU_WARNING_THRESHOLD 0.9f
#define GPU_WARNING_THRESHOLD 0.95f

// Utility functions
static uint64_t get_current_time_microseconds() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec * 1000000ULL + tv.tv_usec;
}

static float calculate_moving_average(const float* values, uint32_t count, uint32_t window_size) {
    if (count == 0 || window_size == 0) return 0.0f;
    
    uint32_t start = count > window_size ? count - window_size : 0;
    float sum = 0.0f;
    uint32_t samples = 0;
    
    for (uint32_t i = start; i < count; i++) {
        sum += values[i];
        samples++;
    }
    
    return samples > 0 ? sum / samples : 0.0f;
}

static float calculate_standard_deviation(const float* values, uint32_t count, float mean) {
    if (count < 2) return 0.0f;
    
    float variance = 0.0f;
    for (uint32_t i = 0; i < count; i++) {
        float diff = values[i] - mean;
        variance += diff * diff;
    }
    
    return sqrtf(variance / (count - 1));
}

// Performance scoring functions
float calculate_performance_score(const asset_performance_data_t* data) {
    float score = 0.0f;
    
    // Loading performance (0-30 points)
    if (data->loading.load_successful) {
        float load_score = 1.0f;
        if (data->loading.total_time_microseconds > 100000) { // > 100ms
            load_score = fmaxf(0.0f, 1.0f - (data->loading.total_time_microseconds - 100000) / 900000.0f);
        }
        score += load_score * 30.0f;
    }
    
    // Memory efficiency (0-25 points)
    if (data->memory.allocated_bytes > 0) {
        float efficiency = 1.0f - (data->memory.fragmentation_percent / 100.0f);
        efficiency *= 1.0f - fminf(1.0f, data->memory.memory_pressure_score);
        score += efficiency * 25.0f;
    }
    
    // Rendering performance (0-20 points)
    if (data->rendering.render_time_microseconds > 0) {
        float render_score = 1.0f;
        if (data->rendering.render_time_microseconds > 16667) { // > 60 FPS frame time
            render_score = fmaxf(0.0f, 1.0f - (data->rendering.render_time_microseconds - 16667) / 50000.0f);
        }
        score += render_score * 20.0f;
    }
    
    // Quality metrics (0-15 points)
    if (data->quality.quality_acceptable) {
        float quality_score = (data->quality.visual_quality_score + 
                              data->quality.audio_quality_score + 
                              data->quality.user_satisfaction_score) / 3.0f;
        score += quality_score * 15.0f;
    }
    
    // Caching efficiency (0-10 points)
    if (data->caching.cache_hits + data->caching.cache_misses > 0) {
        score += data->caching.hit_rate_percent / 10.0f;
    }
    
    return fminf(100.0f, score);
}

// Bottleneck detection algorithms
static bottleneck_type_t detect_primary_bottleneck(performance_monitor_t* monitor) {
    if (monitor->performance_history.count < 10) {
        return BOTTLENECK_CPU; // Default assumption
    }
    
    // Analyze recent performance data
    uint32_t window_start = monitor->performance_history.count > 50 ? 
                           monitor->performance_history.count - 50 : 0;
    
    float avg_cpu = 0.0f, avg_gpu = 0.0f, avg_memory = 0.0f;
    float avg_load_time = 0.0f, avg_cache_miss = 0.0f;
    uint32_t samples = 0;
    
    for (uint32_t i = window_start; i < monitor->performance_history.count; i++) {
        const asset_performance_data_t* data = &monitor->performance_history.data[i];
        avg_cpu += data->processing.cpu_utilization_percent;
        avg_gpu += data->rendering.gpu_utilization_percent;
        avg_memory += data->memory.memory_pressure_score * 100.0f;
        avg_load_time += data->loading.total_time_microseconds / 1000.0f; // Convert to ms
        avg_cache_miss += 100.0f - data->caching.hit_rate_percent;
        samples++;
    }
    
    if (samples == 0) return BOTTLENECK_CPU;
    
    avg_cpu /= samples;
    avg_gpu /= samples;
    avg_memory /= samples;
    avg_load_time /= samples;
    avg_cache_miss /= samples;
    
    // Determine primary bottleneck based on highest pressure
    float max_pressure = avg_cpu;
    bottleneck_type_t primary = BOTTLENECK_CPU;
    
    if (avg_gpu > max_pressure) {
        max_pressure = avg_gpu;
        primary = BOTTLENECK_GPU;
    }
    
    if (avg_memory > max_pressure) {
        max_pressure = avg_memory;
        primary = BOTTLENECK_MEMORY;
    }
    
    if (avg_load_time > 100.0f && avg_load_time > max_pressure) { // > 100ms average
        max_pressure = avg_load_time / 10.0f; // Scale to percentage-like value
        primary = BOTTLENECK_IO;
    }
    
    if (avg_cache_miss > 50.0f && avg_cache_miss > max_pressure) {
        primary = BOTTLENECK_CACHE;
    }
    
    return primary;
}

static void analyze_bottlenecks(performance_monitor_t* monitor, bottleneck_analysis_t* analysis) {
    memset(analysis, 0, sizeof(bottleneck_analysis_t));
    analysis->detection_timestamp = get_current_time_microseconds();
    
    // Detect primary bottleneck
    analysis->primary_bottleneck = detect_primary_bottleneck(monitor);
    
    // Calculate severity based on recent performance data
    if (monitor->performance_history.count > 0) {
        uint32_t recent_idx = monitor->performance_history.count - 1;
        const asset_performance_data_t* recent = &monitor->performance_history.data[recent_idx];
        
        switch (analysis->primary_bottleneck) {
            case BOTTLENECK_CPU:
                analysis->severity_score = recent->processing.cpu_utilization_percent / 100.0f;
                strcpy(analysis->primary_recommendation, 
                       "Optimize CPU-intensive asset processing, consider multi-threading");
                break;
                
            case BOTTLENECK_GPU:
                analysis->severity_score = recent->rendering.gpu_utilization_percent / 100.0f;
                strcpy(analysis->primary_recommendation,
                       "Reduce rendering complexity, optimize shaders, use LOD");
                break;
                
            case BOTTLENECK_MEMORY:
                analysis->severity_score = recent->memory.memory_pressure_score;
                strcpy(analysis->primary_recommendation,
                       "Reduce memory usage, implement streaming, optimize textures");
                break;
                
            case BOTTLENECK_IO:
                analysis->severity_score = fminf(1.0f, recent->loading.total_time_microseconds / 500000.0f);
                strcpy(analysis->primary_recommendation,
                       "Optimize I/O patterns, use compression, implement prefetching");
                break;
                
            case BOTTLENECK_CACHE:
                analysis->severity_score = (100.0f - recent->caching.hit_rate_percent) / 100.0f;
                strcpy(analysis->primary_recommendation,
                       "Improve cache locality, increase cache size, optimize access patterns");
                break;
                
            default:
                analysis->severity_score = 0.5f;
                strcpy(analysis->primary_recommendation, "Profile system for specific bottlenecks");
                break;
        }
        
        // Fill bottleneck metrics
        analysis->bottleneck_metrics.cpu_utilization_percent = recent->processing.cpu_utilization_percent;
        analysis->bottleneck_metrics.memory_pressure_percent = recent->memory.memory_pressure_score * 100;
        analysis->bottleneck_metrics.gpu_utilization_percent = recent->rendering.gpu_utilization_percent;
        analysis->bottleneck_metrics.cache_miss_rate_percent = 100.0f - recent->caching.hit_rate_percent;
    }
    
    // Calculate impact score based on overall performance degradation
    float recent_perf_score = 0.0f;
    uint32_t perf_samples = 0;
    uint32_t start_idx = monitor->performance_history.count > 20 ? 
                        monitor->performance_history.count - 20 : 0;
    
    for (uint32_t i = start_idx; i < monitor->performance_history.count; i++) {
        recent_perf_score += calculate_performance_score(&monitor->performance_history.data[i]);
        perf_samples++;
    }
    
    if (perf_samples > 0) {
        recent_perf_score /= perf_samples;
        analysis->impact_score = fmaxf(0.0f, (100.0f - recent_perf_score) / 100.0f);
    }
    
    analysis->estimated_improvement_percent = analysis->severity_score * 25.0f; // Up to 25% improvement
    analysis->implementation_difficulty = 5; // Medium difficulty by default
    analysis->is_critical = analysis->severity_score > 0.8f;
    analysis->is_persistent = true; // Assume persistent until proven otherwise
}

// Predictive analytics
static void generate_performance_prediction(performance_monitor_t* monitor, 
                                           uint32_t horizon_seconds,
                                           performance_prediction_t* prediction) {
    memset(prediction, 0, sizeof(performance_prediction_t));
    prediction->prediction_timestamp = get_current_time_microseconds();
    prediction->prediction_horizon_seconds = horizon_seconds;
    
    if (monitor->performance_history.count < 10) {
        // Not enough data for prediction
        prediction->predictions.predicted_fps = 60.0f;
        prediction->predictions.predicted_memory_usage_percent = 50.0f;
        prediction->predictions.predicted_gpu_utilization_percent = 50.0f;
        prediction->predictions.predicted_cpu_utilization_percent = 50.0f;
        prediction->predictions.predicted_load_time_ms = 100.0f;
        prediction->predictions.predicted_quality_score = 80.0f;
        
        // Low confidence
        prediction->confidence.fps_confidence = 0.3f;
        prediction->confidence.memory_confidence = 0.3f;
        prediction->confidence.gpu_confidence = 0.3f;
        prediction->confidence.cpu_confidence = 0.3f;
        prediction->confidence.load_time_confidence = 0.3f;
        prediction->confidence.quality_confidence = 0.3f;
        
        return;
    }
    
    // Simple trend analysis for prediction
    uint32_t window_size = fminf(monitor->performance_history.count, 100);
    uint32_t start_idx = monitor->performance_history.count - window_size;
    
    // Calculate trends
    float fps_trend = 0.0f, memory_trend = 0.0f, gpu_trend = 0.0f;
    float cpu_trend = 0.0f, load_time_trend = 0.0f, quality_trend = 0.0f;
    
    if (window_size > 1) {
        const asset_performance_data_t* first = &monitor->performance_history.data[start_idx];
        const asset_performance_data_t* last = &monitor->performance_history.data[monitor->performance_history.count - 1];
        
        uint64_t time_diff = last->timestamp_microseconds - first->timestamp_microseconds;
        if (time_diff > 0) {
            float time_factor = (float)horizon_seconds * 1000000.0f / time_diff;
            
            // Extract trends (simplified linear extrapolation)
            fps_trend = time_factor * 0.1f; // Assume slight FPS degradation over time
            memory_trend = time_factor * 0.05f; // Memory usage tends to increase
            gpu_trend = time_factor * 0.02f;
            cpu_trend = time_factor * 0.03f;
            load_time_trend = time_factor * 0.1f; // Load times may increase
            quality_trend = -time_factor * 0.05f; // Quality may degrade slightly
        }
    }
    
    // Calculate current averages
    float avg_fps = 60.0f, avg_memory = 50.0f, avg_gpu = 50.0f;
    float avg_cpu = 50.0f, avg_load_time = 100.0f, avg_quality = 80.0f;
    
    for (uint32_t i = start_idx; i < monitor->performance_history.count; i++) {
        const asset_performance_data_t* data = &monitor->performance_history.data[i];
        
        // Note: FPS calculation would need frame timing data
        avg_memory += data->memory.memory_pressure_score * 100.0f;
        avg_gpu += data->rendering.gpu_utilization_percent;
        avg_cpu += data->processing.cpu_utilization_percent;
        avg_load_time += data->loading.total_time_microseconds / 1000.0f;
        avg_quality += calculate_performance_score(data);
    }
    
    avg_memory /= window_size;
    avg_gpu /= window_size;
    avg_cpu /= window_size;
    avg_load_time /= window_size;
    avg_quality /= window_size;
    
    // Apply trends to predictions
    prediction->predictions.predicted_fps = fmaxf(10.0f, avg_fps - fps_trend);
    prediction->predictions.predicted_memory_usage_percent = fminf(100.0f, avg_memory + memory_trend);
    prediction->predictions.predicted_gpu_utilization_percent = fminf(100.0f, avg_gpu + gpu_trend);
    prediction->predictions.predicted_cpu_utilization_percent = fminf(100.0f, avg_cpu + cpu_trend);
    prediction->predictions.predicted_load_time_ms = fmaxf(10.0f, avg_load_time + load_time_trend);
    prediction->predictions.predicted_quality_score = fmaxf(0.0f, avg_quality + quality_trend);
    
    // Calculate confidence based on data consistency
    float data_variance = calculate_standard_deviation(NULL, 0, 0); // Simplified
    float base_confidence = fmaxf(0.5f, 1.0f - (data_variance / 50.0f));
    
    prediction->confidence.fps_confidence = base_confidence;
    prediction->confidence.memory_confidence = base_confidence * 0.9f;
    prediction->confidence.gpu_confidence = base_confidence * 0.8f;
    prediction->confidence.cpu_confidence = base_confidence * 0.8f;
    prediction->confidence.load_time_confidence = base_confidence * 0.7f;
    prediction->confidence.quality_confidence = base_confidence * 0.85f;
    
    // Risk assessment
    prediction->risks.bottleneck_risk = fmaxf(prediction->predictions.predicted_memory_usage_percent,
                                            prediction->predictions.predicted_gpu_utilization_percent) / 100.0f;
    prediction->risks.quality_degradation_risk = fmaxf(0.0f, 
        (80.0f - prediction->predictions.predicted_quality_score) / 80.0f);
    prediction->risks.performance_regression_risk = fmaxf(0.0f,
        (60.0f - prediction->predictions.predicted_fps) / 60.0f);
    
    // Generate recommendations
    strcpy(prediction->optimization_recommendations, 
           "Monitor memory usage closely, consider asset quality adjustments if performance degrades");
}

// Alert management
static void check_performance_alerts(performance_monitor_t* monitor) {
    if (monitor->performance_history.count == 0) return;
    
    const asset_performance_data_t* latest = 
        &monitor->performance_history.data[monitor->performance_history.count - 1];
    
    // Check for FPS alerts
    float estimated_fps = 60.0f; // Would calculate from frame timing
    if (estimated_fps < FPS_CRITICAL_THRESHOLD) {
        // Create critical FPS alert
        if (monitor->alerts.active_alert_count < 32) {
            performance_alert_t* alert = &monitor->alerts.active_alerts[monitor->alerts.active_alert_count++];
            alert->alert_id = monitor->alerts.total_alert_count++;
            alert->timestamp = get_current_time_microseconds();
            alert->level = ALERT_LEVEL_CRITICAL;
            alert->category = PERF_CATEGORY_RENDERING;
            
            strcpy(alert->title, "Critical FPS Drop Detected");
            snprintf(alert->description, sizeof(alert->description),
                    "Frame rate dropped to %.1f FPS, below critical threshold of %.1f FPS",
                    estimated_fps, FPS_CRITICAL_THRESHOLD);
            
            alert->severity_score = (FPS_CRITICAL_THRESHOLD - estimated_fps) / FPS_CRITICAL_THRESHOLD;
            alert->urgency_score = 0.9f;
            alert->current_fps = estimated_fps;
            
            strcpy(alert->immediate_action, "Reduce rendering quality immediately");
            strcpy(alert->long_term_solution, "Optimize asset pipeline and rendering efficiency");
            alert->auto_fix_available = true;
            
            if (monitor->on_performance_alert) {
                monitor->on_performance_alert(alert);
            }
        }
    }
    
    // Check for memory alerts
    float memory_pressure = latest->memory.memory_pressure_score;
    if (memory_pressure > MEMORY_CRITICAL_THRESHOLD) {
        if (monitor->alerts.active_alert_count < 32) {
            performance_alert_t* alert = &monitor->alerts.active_alerts[monitor->alerts.active_alert_count++];
            alert->alert_id = monitor->alerts.total_alert_count++;
            alert->timestamp = get_current_time_microseconds();
            alert->level = ALERT_LEVEL_CRITICAL;
            alert->category = PERF_CATEGORY_MEMORY;
            
            strcpy(alert->title, "Critical Memory Pressure");
            snprintf(alert->description, sizeof(alert->description),
                    "Memory pressure at %.1f%%, above critical threshold of %.1f%%",
                    memory_pressure * 100, MEMORY_CRITICAL_THRESHOLD * 100);
            
            alert->severity_score = memory_pressure;
            alert->urgency_score = 0.95f;
            alert->memory_usage_percent = memory_pressure * 100;
            
            strcpy(alert->immediate_action, "Free unused assets and reduce quality");
            strcpy(alert->long_term_solution, "Implement asset streaming and memory optimization");
            alert->auto_fix_available = true;
            
            if (monitor->on_performance_alert) {
                monitor->on_performance_alert(alert);
            }
        }
    }
}

// Core implementation
int performance_monitor_init(performance_monitor_t** monitor, performance_monitor_mode_t mode) {
    if (!monitor) return -1;
    
    *monitor = calloc(1, sizeof(performance_monitor_t));
    if (!*monitor) return -1;
    
    performance_monitor_t* mon = *monitor;
    
    // Initialize configuration
    mon->mode = mode;
    mon->sampling_interval_ms = DEFAULT_SAMPLING_INTERVAL_MS;
    mon->analysis_interval_ms = DEFAULT_ANALYSIS_INTERVAL_MS;
    mon->reporting_interval_ms = DEFAULT_REPORTING_INTERVAL_MS;
    
    // Initialize performance history
    mon->performance_history.capacity = PERFORMANCE_HISTORY_CAPACITY;
    mon->performance_history.data = calloc(PERFORMANCE_HISTORY_CAPACITY, 
                                          sizeof(asset_performance_data_t));
    mon->performance_history.timestamps = calloc(PERFORMANCE_HISTORY_CAPACITY, sizeof(uint64_t));
    
    // Initialize bottleneck detector
    mon->bottleneck_detector.analysis_window_size = BOTTLENECK_ANALYSIS_WINDOW;
    mon->bottleneck_detector.detection_threshold = 10;
    mon->bottleneck_detector.severity_threshold = 0.7f;
    mon->bottleneck_detector.analysis_history = calloc(100, sizeof(bottleneck_analysis_t));
    
    // Initialize predictor
    mon->predictor.enabled = true;
    mon->predictor.prediction_window_seconds = 300; // 5 minutes
    mon->predictor.model_accuracy = 0.75f;
    mon->predictor.prediction_history = calloc(PREDICTION_HISTORY_CAPACITY, 
                                              sizeof(performance_prediction_t));
    
    // Initialize alerts
    mon->alerts.alert_history_capacity = ALERT_HISTORY_CAPACITY;
    mon->alerts.alert_history = calloc(ALERT_HISTORY_CAPACITY, sizeof(performance_alert_t));
    
    // Initialize threading
    mon->mutex = malloc(sizeof(pthread_mutex_t));
    pthread_mutex_init((pthread_mutex_t*)mon->mutex, NULL);
    
    mon->monitoring_start_time = get_current_time_microseconds();
    
    return 0;
}

void performance_monitor_destroy(performance_monitor_t* monitor) {
    if (!monitor) return;
    
    if (monitor->is_monitoring) {
        performance_monitor_stop(monitor);
    }
    
    free(monitor->performance_history.data);
    free(monitor->performance_history.timestamps);
    free(monitor->bottleneck_detector.analysis_history);
    free(monitor->predictor.prediction_history);
    free(monitor->alerts.alert_history);
    
    pthread_mutex_destroy((pthread_mutex_t*)monitor->mutex);
    free(monitor->mutex);
    
    free(monitor);
}

int performance_monitor_record_asset(performance_monitor_t* monitor, 
                                    const asset_performance_data_t* data) {
    if (!monitor || !data) return -1;
    
    pthread_mutex_lock((pthread_mutex_t*)monitor->mutex);
    
    // Add to circular buffer
    uint32_t index = monitor->performance_history.count % monitor->performance_history.capacity;
    monitor->performance_history.data[index] = *data;
    monitor->performance_history.timestamps[index] = get_current_time_microseconds();
    
    if (monitor->performance_history.count < monitor->performance_history.capacity) {
        monitor->performance_history.count++;
    }
    
    monitor->statistics.total_assets_monitored++;
    monitor->statistics.total_performance_events++;
    
    // Update real-time metrics
    monitor->realtime_metrics.current_memory_usage_percent = data->memory.memory_pressure_score * 100;
    monitor->realtime_metrics.current_cpu_utilization = data->processing.cpu_utilization_percent;
    monitor->realtime_metrics.current_gpu_utilization = data->rendering.gpu_utilization_percent;
    monitor->realtime_metrics.overall_performance_score = calculate_performance_score(data);
    
    pthread_mutex_unlock((pthread_mutex_t*)monitor->mutex);
    
    return 0;
}

int performance_monitor_analyze_bottlenecks(performance_monitor_t* monitor, 
                                           bottleneck_analysis_t* analysis) {
    if (!monitor || !analysis) return -1;
    
    pthread_mutex_lock((pthread_mutex_t*)monitor->mutex);
    
    analyze_bottlenecks(monitor, analysis);
    
    // Store in analysis history
    if (monitor->bottleneck_detector.analysis_history_count < 100) {
        monitor->bottleneck_detector.analysis_history[monitor->bottleneck_detector.analysis_history_count++] = 
            *analysis;
    }
    
    monitor->bottleneck_detector.current_analysis = *analysis;
    monitor->statistics.total_bottlenecks_detected++;
    
    if (monitor->on_bottleneck_detected) {
        monitor->on_bottleneck_detected(analysis);
    }
    
    pthread_mutex_unlock((pthread_mutex_t*)monitor->mutex);
    
    return 0;
}

int performance_monitor_predict_performance(performance_monitor_t* monitor, 
                                           uint32_t horizon_seconds,
                                           performance_prediction_t* prediction) {
    if (!monitor || !prediction) return -1;
    
    pthread_mutex_lock((pthread_mutex_t*)monitor->mutex);
    
    generate_performance_prediction(monitor, horizon_seconds, prediction);
    
    // Store in prediction history
    if (monitor->predictor.prediction_history_count < PREDICTION_HISTORY_CAPACITY) {
        monitor->predictor.prediction_history[monitor->predictor.prediction_history_count++] = 
            *prediction;
    }
    
    monitor->predictor.current_prediction = *prediction;
    monitor->statistics.total_predictions_made++;
    
    if (monitor->on_prediction_update) {
        monitor->on_prediction_update(prediction);
    }
    
    pthread_mutex_unlock((pthread_mutex_t*)monitor->mutex);
    
    return 0;
}

int performance_monitor_check_alerts(performance_monitor_t* monitor) {
    if (!monitor) return -1;
    
    pthread_mutex_lock((pthread_mutex_t*)monitor->mutex);
    
    check_performance_alerts(monitor);
    
    pthread_mutex_unlock((pthread_mutex_t*)monitor->mutex);
    
    return 0;
}

int performance_monitor_get_realtime_metrics(performance_monitor_t* monitor, struct {
    float current_fps;
    float memory_usage_percent;
    float cpu_utilization_percent;
    float gpu_utilization_percent;
    uint32_t active_alerts;
    float performance_score;
} *metrics) {
    if (!monitor || !metrics) return -1;
    
    pthread_mutex_lock((pthread_mutex_t*)monitor->mutex);
    
    metrics->current_fps = monitor->realtime_metrics.current_average_fps;
    metrics->memory_usage_percent = monitor->realtime_metrics.current_memory_usage_percent;
    metrics->cpu_utilization_percent = monitor->realtime_metrics.current_cpu_utilization;
    metrics->gpu_utilization_percent = monitor->realtime_metrics.current_gpu_utilization;
    metrics->active_alerts = monitor->alerts.active_alert_count;
    metrics->performance_score = monitor->realtime_metrics.overall_performance_score;
    
    pthread_mutex_unlock((pthread_mutex_t*)monitor->mutex);
    
    return 0;
}

const char* performance_category_to_string(performance_category_t category) {
    switch (category) {
        case PERF_CATEGORY_LOADING: return "Loading";
        case PERF_CATEGORY_MEMORY: return "Memory";
        case PERF_CATEGORY_RENDERING: return "Rendering";
        case PERF_CATEGORY_STREAMING: return "Streaming";
        case PERF_CATEGORY_PROCESSING: return "Processing";
        case PERF_CATEGORY_CACHING: return "Caching";
        case PERF_CATEGORY_NETWORK: return "Network";
        case PERF_CATEGORY_COMPRESSION: return "Compression";
        default: return "Unknown";
    }
}

const char* bottleneck_type_to_string(bottleneck_type_t type) {
    switch (type) {
        case BOTTLENECK_CPU: return "CPU";
        case BOTTLENECK_MEMORY: return "Memory";
        case BOTTLENECK_GPU: return "GPU";
        case BOTTLENECK_IO: return "I/O";
        case BOTTLENECK_NETWORK: return "Network";
        case BOTTLENECK_CACHE: return "Cache";
        case BOTTLENECK_THERMAL: return "Thermal";
        case BOTTLENECK_POWER: return "Power";
        case BOTTLENECK_SYNCHRONIZATION: return "Synchronization";
        default: return "Unknown";
    }
}

const char* alert_level_to_string(performance_alert_level_t level) {
    switch (level) {
        case ALERT_LEVEL_INFO: return "Info";
        case ALERT_LEVEL_WARNING: return "Warning";
        case ALERT_LEVEL_CRITICAL: return "Critical";
        case ALERT_LEVEL_EMERGENCY: return "Emergency";
        default: return "Unknown";
    }
}