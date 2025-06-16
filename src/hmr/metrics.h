/*
 * SimCity ARM64 - HMR Performance Metrics Header
 * Real-time monitoring of module load times, memory usage, and performance
 * 
 * Agent 4: Developer Tools & Debug Interface
 * Day 2: Real-Time Monitoring API
 */

#ifndef HMR_METRICS_H
#define HMR_METRICS_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "module_interface.h"

#ifdef __cplusplus
extern "C" {
#endif

// Configuration constants
#define HMR_PERFORMANCE_HISTORY_SIZE 1000
#define HMR_MODULE_NAME_MAX         32

// System-wide performance metrics
typedef struct {
    float current_fps;
    uint64_t avg_frame_time_ns;
    uint64_t peak_frame_time_ns;
    uint64_t total_frames;
    uint64_t memory_usage_bytes;
    uint64_t peak_memory_bytes;
    uint32_t active_modules;
} hmr_system_metrics_t;

// Note: hmr_module_metrics_t is defined in module_interface.h

// Module metrics entry with tracking info
typedef struct {
    char module_name[HMR_MODULE_NAME_MAX];
    bool active;
    uint64_t registration_time;
    uint64_t last_load_time;
    uint32_t load_count;
    hmr_module_metrics_t metrics;
} hmr_module_metrics_entry_t;

// Performance sample for historical tracking
typedef struct {
    uint64_t timestamp;
    float fps;
    uint64_t frame_time_ns;
    uint64_t memory_usage_bytes;
} hmr_performance_sample_t;

// Build system metrics
typedef struct {
    uint64_t builds_started;
    uint64_t builds_succeeded;
    uint64_t builds_failed;
    uint64_t total_build_time_ns;
    uint64_t longest_build_time_ns;
    uint64_t shortest_build_time_ns;
    uint64_t build_start_time;
    char current_module[HMR_MODULE_NAME_MAX];
} hmr_build_metrics_t;

// Metrics system lifecycle
int hmr_metrics_init(void);
int hmr_metrics_start(void);
void hmr_metrics_stop(void);
void hmr_metrics_shutdown(void);

// Module registration for tracking
int hmr_metrics_register_module(const char* module_name);
void hmr_metrics_unregister_module(const char* module_name);

// Performance recording functions
void hmr_metrics_record_load_time(const char* module_name, uint64_t load_time_ns);
void hmr_metrics_record_frame_time(uint64_t frame_time_ns);
void hmr_metrics_record_memory_usage(const char* module_name, uint64_t memory_bytes);

// Build metrics recording
void hmr_metrics_build_start(const char* module_name);
void hmr_metrics_build_complete(const char* module_name, bool success);

// Metrics retrieval
void hmr_metrics_get_system_metrics(hmr_system_metrics_t* metrics);
int hmr_metrics_get_module_metrics(const char* module_name, hmr_module_metrics_t* metrics);
void hmr_metrics_get_build_metrics(hmr_build_metrics_t* metrics);

// JSON reporting for web dashboard
void hmr_metrics_generate_json(char* json_buffer, size_t buffer_size);

// Performance history access
int hmr_metrics_get_performance_history(hmr_performance_sample_t* samples, uint32_t max_samples);

// Utility functions
static inline uint64_t hmr_metrics_ns_to_ms(uint64_t nanoseconds) {
    return nanoseconds / 1000000;
}

static inline float hmr_metrics_ns_to_ms_float(uint64_t nanoseconds) {
    return nanoseconds / 1000000.0f;
}

static inline uint64_t hmr_metrics_bytes_to_mb(uint64_t bytes) {
    return bytes / (1024 * 1024);
}

static inline float hmr_metrics_bytes_to_mb_float(uint64_t bytes) {
    return bytes / (1024.0f * 1024.0f);
}

#ifdef __cplusplus
}
#endif

#endif // HMR_METRICS_H