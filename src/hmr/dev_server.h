/*
 * SimCity ARM64 - HMR Development Server Header
 * WebSocket-based development server for real-time HMR communication
 * 
 * Agent 4: Developer Tools & Debug Interface
 * Day 1: WebSocket Development Server API
 */

#ifndef HMR_DEV_SERVER_H
#define HMR_DEV_SERVER_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Server configuration
#define HMR_DEV_SERVER_DEFAULT_PORT  8080
#define HMR_DEV_SERVER_MAX_CLIENTS   32

// Server lifecycle functions
int hmr_dev_server_init(int port);
void hmr_dev_server_shutdown(void);

// Notification functions for HMR events
void hmr_notify_build_start(const char* module_name);
void hmr_notify_build_success(const char* module_name, uint64_t build_time_ms);
void hmr_notify_build_error(const char* module_name, const char* error_message);
void hmr_notify_module_reload(const char* module_name, bool success);
void hmr_notify_module_error(const char* module_name, const char* error_message);
void hmr_notify_performance_update(const char* performance_json);
void hmr_notify_dependency_update(const char* dependency_json);

// Server status and monitoring
void hmr_get_server_status(char* status_json, size_t max_len);
bool hmr_dev_server_is_running(void);
uint32_t hmr_get_client_count(void);

// Statistics
typedef struct {
    uint32_t client_count;
    uint32_t total_connections;
    uint64_t messages_sent;
    uint64_t messages_received;
    uint64_t bytes_sent;
    uint64_t bytes_received;
    uint64_t uptime_seconds;
} hmr_server_stats_t;

void hmr_get_server_stats(hmr_server_stats_t* stats);

// Day 6: Enhanced Dashboard API
void hmr_notify_code_change(const char* file_path, const char* content, const char* author);
void hmr_notify_dependency_change(const char* module_name, const char* dependencies_json);
void hmr_serve_file_content(const char* file_path, char* content_buffer, size_t max_len);
void hmr_save_file_content(const char* file_path, const char* content, const char* author);
void hmr_get_module_dependencies(const char* module_name, char* deps_json, size_t max_len);
void hmr_get_performance_history(char* history_json, size_t max_len);
void hmr_add_performance_sample(double fps, double frame_time_ms, double memory_mb, uint64_t timestamp);

// Collaborative features
typedef struct {
    char author[64];
    char file_path[256];
    uint64_t timestamp;
    char action[32]; // "edit", "save", "view"
} hmr_collaborative_event_t;

void hmr_notify_collaborative_event(const hmr_collaborative_event_t* event);
void hmr_get_active_collaborators(char* collaborators_json, size_t max_len);

#ifdef __cplusplus
}
#endif

#endif // HMR_DEV_SERVER_H