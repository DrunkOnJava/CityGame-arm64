/*
 * SimCity ARM64 - Module Dependency Analyzer Header
 * Real-time dependency tracking and visualization for HMR Dashboard
 * 
 * Agent 4: Developer Tools & Debug Interface
 * Day 6: Enhanced Module Dependency Visualization
 */

#ifndef HMR_DEPENDENCY_ANALYZER_H
#define HMR_DEPENDENCY_ANALYZER_H

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

// Analyzer lifecycle functions
int hmr_dependency_analyzer_init(const char* project_root);
void hmr_dependency_analyzer_shutdown(void);

// Control functions
void hmr_trigger_dependency_scan(void);
void hmr_get_dependency_data(char* json_buffer, size_t max_len);

// Monitoring functions
typedef struct {
    uint32_t module_count;
    uint32_t dependency_count;
    time_t last_scan_time;
    bool is_running;
} hmr_dependency_stats_t;

void hmr_get_dependency_stats(hmr_dependency_stats_t* stats);

// Notification callback (to be called when dependencies change)
typedef void (*hmr_dependency_change_callback_t)(const char* json_data);
void hmr_set_dependency_change_callback(hmr_dependency_change_callback_t callback);

#ifdef __cplusplus
}
#endif

#endif // HMR_DEPENDENCY_ANALYZER_H