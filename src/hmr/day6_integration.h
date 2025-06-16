/*
 * SimCity ARM64 - Day 6 Enhanced HMR Integration Header
 * Master integration for all Day 6 enhanced developer dashboard features
 * 
 * Agent 4: Developer Tools & Debug Interface
 * Day 6: Integration of all enhanced features
 */

#ifndef HMR_DAY6_INTEGRATION_H
#define HMR_DAY6_INTEGRATION_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

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

// Master initialization and shutdown
int hmr_day6_enhanced_init(const char* project_root, int server_port);
void hmr_day6_enhanced_shutdown(void);

// Integration status and monitoring
void hmr_get_integration_status(char* status_json, size_t max_len);
bool hmr_is_day6_enhanced_running(void);

// Cross-system operations
void hmr_trigger_comprehensive_scan(void);
void hmr_sync_all_systems(void);
void hmr_broadcast_system_event(const char* event_type, const char* event_data);

// Feature demonstrations and testing
void hmr_demonstrate_day6_features(void);
void hmr_run_day6_feature_tests(void);

// Enhanced dashboard endpoints
void hmr_serve_enhanced_dashboard(const char* client_ip, char* response_buffer, size_t max_len);
void hmr_handle_enhanced_api_request(const char* endpoint, const char* request_data, 
                                    char* response_buffer, size_t max_len);

// Integration statistics
typedef struct {
    bool all_systems_running;
    uint64_t total_events_processed;
    uint64_t performance_updates_sent;
    uint64_t dependency_updates_sent;
    uint64_t collaborative_events_sent;
    uint64_t uptime_seconds;
    
    struct {
        bool dev_server;
        bool dependency_analyzer;
        bool performance_analytics;
        bool collaborative_system;
    } component_status;
    
} hmr_day6_stats_t;

void hmr_get_day6_stats(hmr_day6_stats_t* stats);

// Day 6 Enhanced Features List
#define HMR_DAY6_FEATURE_COUNT 5

typedef enum {
    HMR_FEATURE_CODE_EDITOR,
    HMR_FEATURE_DEPENDENCY_GRAPH,
    HMR_FEATURE_PERFORMANCE_ANALYTICS,
    HMR_FEATURE_COLLABORATIVE_DEV,
    HMR_FEATURE_CROSS_INTEGRATION
} hmr_day6_feature_t;

const char* hmr_get_feature_name(hmr_day6_feature_t feature);
bool hmr_is_feature_enabled(hmr_day6_feature_t feature);
void hmr_enable_feature(hmr_day6_feature_t feature, bool enabled);

// Configuration
typedef struct {
    int server_port;
    char project_root[512];
    bool enable_code_editor;
    bool enable_dependency_graph;
    bool enable_performance_analytics;
    bool enable_collaborative_features;
    bool enable_debug_logging;
    
    struct {
        uint32_t max_performance_samples;
        uint32_t max_developers;
        uint32_t max_sessions;
        uint32_t dependency_scan_interval_seconds;
    } limits;
    
} hmr_day6_config_t;

void hmr_set_day6_config(const hmr_day6_config_t* config);
void hmr_get_day6_config(hmr_day6_config_t* config);

#ifdef __cplusplus
}
#endif

#endif // HMR_DAY6_INTEGRATION_H