/*
 * SimCity ARM64 - Performance Analytics System Header
 * Advanced performance monitoring and historical data analysis
 * 
 * Agent 4: Developer Tools & Debug Interface
 * Day 6: Enhanced Performance Analytics Dashboard
 */

#ifndef HMR_PERFORMANCE_ANALYTICS_H
#define HMR_PERFORMANCE_ANALYTICS_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <pthread.h>

#ifdef __cplusplus
extern "C" {
#endif

// Error codes (assuming these are defined in module_interface.h)
#ifndef HMR_SUCCESS
#define HMR_SUCCESS 0
#define HMR_ERROR_THREADING 1
#define HMR_ERROR_NOT_FOUND 2
#define HMR_ERROR_OUT_OF_MEMORY 3
#define HMR_ERROR_INVALID_ARG 4
#endif

// Analytics lifecycle functions
int hmr_performance_analytics_init(void);
void hmr_performance_analytics_shutdown(void);

// Data collection functions
void hmr_get_analytics_data(char* json_buffer, size_t max_len);
void hmr_add_custom_sample(const char* category, double value);

// Function profiling macros and functions
#define HMR_PROFILE_FUNCTION_START(module) \
    hmr_profile_function_start(__FUNCTION__, module)

#define HMR_PROFILE_FUNCTION_END(module) \
    hmr_profile_function_end(__FUNCTION__, module)

void hmr_profile_function_start(const char* function_name, const char* module_name);
void hmr_profile_function_end(const char* function_name, const char* module_name);

// Performance monitoring utilities
typedef struct {
    double fps_warning_threshold;
    double fps_critical_threshold;
    double memory_warning_threshold_mb;
    double memory_critical_threshold_mb;
    double cpu_warning_threshold_percent;
    double cpu_critical_threshold_percent;
} hmr_performance_thresholds_t;

void hmr_set_performance_thresholds(const hmr_performance_thresholds_t* thresholds);
void hmr_get_performance_thresholds(hmr_performance_thresholds_t* thresholds);

// Analytics statistics
typedef struct {
    uint64_t total_samples_collected;
    uint64_t alerts_triggered;
    uint64_t performance_degradations;
    uint32_t active_profiler_entries;
    uint64_t uptime_seconds;
    bool is_running;
} hmr_analytics_stats_t;

void hmr_get_analytics_stats(hmr_analytics_stats_t* stats);

// Real-time performance snapshot
typedef struct {
    double current_fps;
    double current_frame_time_ms;
    double current_cpu_usage_percent;
    double current_memory_usage_mb;
    double current_gpu_usage_percent;
    uint32_t current_thread_count;
    uint64_t timestamp_us;
} hmr_performance_snapshot_t;

void hmr_get_performance_snapshot(hmr_performance_snapshot_t* snapshot);

#ifdef __cplusplus
}
#endif

#endif // HMR_PERFORMANCE_ANALYTICS_H