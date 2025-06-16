/*
 * SimCity ARM64 - System Performance Orchestrator
 * Coordinates performance monitoring across all HMR agents with <100ms latency
 * 
 * Agent 0: HMR Orchestrator - Day 11
 * Week 3: Advanced Features & Production Optimization
 */

#ifndef HMR_SYSTEM_PERFORMANCE_ORCHESTRATOR_H
#define HMR_SYSTEM_PERFORMANCE_ORCHESTRATOR_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <pthread.h>

#ifdef __cplusplus
extern "C" {
#endif

// Agent identification
typedef enum {
    HMR_AGENT_VERSIONING = 0,      // Agent 1: Module versioning
    HMR_AGENT_BUILD_PIPELINE = 1,  // Agent 2: Build optimization
    HMR_AGENT_RUNTIME = 2,         // Agent 3: Runtime integration
    HMR_AGENT_DEVELOPER_TOOLS = 3, // Agent 4: Developer dashboard
    HMR_AGENT_SHADER_PIPELINE = 4, // Agent 5: Shader management
    HMR_AGENT_ORCHESTRATOR = 5,    // Agent 0: System orchestration
    HMR_AGENT_COUNT = 6
} hmr_agent_id_t;

// Performance metrics per agent
typedef struct {
    hmr_agent_id_t agent_id;
    char agent_name[32];
    
    // Core performance metrics
    double cpu_usage_percent;
    double memory_usage_mb;
    double throughput_ops_per_sec;
    double latency_ms;
    double error_rate_percent;
    
    // Agent-specific metrics
    union {
        struct { // Agent 1: Versioning
            double version_load_time_ms;
            uint32_t active_versions;
            double migration_time_ms;
        } versioning;
        
        struct { // Agent 2: Build Pipeline
            double build_time_ms;
            double cache_hit_rate_percent;
            uint32_t concurrent_builds;
            double incremental_build_time_ms;
        } build_pipeline;
        
        struct { // Agent 3: Runtime
            double hot_reload_time_ms;
            double state_sync_time_ms;
            uint32_t active_modules;
            double neon_utilization_percent;
        } runtime;
        
        struct { // Agent 4: Developer Tools
            double dashboard_render_time_ms;
            uint32_t active_connections;
            double websocket_latency_ms;
            double ui_response_time_ms;
        } developer_tools;
        
        struct { // Agent 5: Shader Pipeline
            double shader_compile_time_ms;
            double shader_cache_hit_rate_percent;
            uint32_t active_shaders;
            double gpu_utilization_percent;
        } shader_pipeline;
        
        struct { // Agent 0: Orchestrator
            double coordination_overhead_ms;
            uint32_t active_agents;
            double system_sync_time_ms;
            double bottleneck_detection_time_ms;
        } orchestrator;
    } specific;
    
    // Performance health indicators
    bool is_healthy;
    bool has_bottleneck;
    bool needs_optimization;
    double performance_score; // 0.0 to 1.0
    
    // Timing information
    uint64_t last_update_timestamp_us;
    uint64_t measurement_duration_us;
    
} hmr_agent_performance_t;

// System-wide performance status
typedef struct {
    // Overall system metrics
    double system_fps;
    double system_cpu_usage_percent;
    double system_memory_usage_mb;
    double system_latency_ms;
    double system_throughput_ops_per_sec;
    
    // Agent performance data
    hmr_agent_performance_t agents[HMR_AGENT_COUNT];
    
    // Bottleneck analysis
    hmr_agent_id_t primary_bottleneck;
    hmr_agent_id_t secondary_bottleneck;
    double bottleneck_severity; // 0.0 to 1.0
    
    // System health
    bool system_healthy;
    uint32_t unhealthy_agents;
    uint32_t performance_alerts;
    
    // Predictive metrics
    double predicted_fps_next_minute;
    double predicted_memory_usage_mb;
    bool performance_degradation_detected;
    
    // Timing
    uint64_t measurement_timestamp_us;
    uint64_t system_uptime_us;
    
} hmr_system_performance_t;

// Performance optimization recommendations
typedef struct {
    hmr_agent_id_t target_agent;
    char optimization_type[64];
    char description[256];
    double expected_improvement_percent;
    uint32_t priority; // 1-10, 10 being highest
    bool auto_applicable;
    
} hmr_optimization_recommendation_t;

// Performance alert
typedef struct {
    hmr_agent_id_t source_agent;
    char alert_type[32]; // "WARNING", "CRITICAL", "DEGRADATION"
    char message[256];
    double severity; // 0.0 to 1.0
    uint64_t timestamp_us;
    bool acknowledged;
    
} hmr_performance_alert_t;

// Orchestrator configuration
typedef struct {
    // Monitoring intervals
    uint32_t collection_interval_ms;
    uint32_t analysis_interval_ms;
    uint32_t alert_check_interval_ms;
    
    // Performance thresholds
    double cpu_warning_threshold;
    double cpu_critical_threshold;
    double memory_warning_threshold_mb;
    double memory_critical_threshold_mb;
    double latency_warning_threshold_ms;
    double latency_critical_threshold_ms;
    
    // Optimization settings
    bool auto_optimization_enabled;
    bool predictive_analysis_enabled;
    bool cross_agent_coordination_enabled;
    
    // Alert settings
    uint32_t max_alerts_per_minute;
    bool alert_aggregation_enabled;
    
} hmr_orchestrator_config_t;

// Initialization and lifecycle
int hmr_system_performance_orchestrator_init(const hmr_orchestrator_config_t* config);
void hmr_system_performance_orchestrator_shutdown(void);

// Performance monitoring
int hmr_register_agent_performance_provider(hmr_agent_id_t agent_id, 
                                           void (*performance_callback)(hmr_agent_performance_t*));
int hmr_get_system_performance(hmr_system_performance_t* performance);
int hmr_get_agent_performance(hmr_agent_id_t agent_id, hmr_agent_performance_t* performance);

// Bottleneck detection and optimization
int hmr_analyze_bottlenecks(hmr_optimization_recommendation_t* recommendations, 
                           uint32_t max_recommendations, uint32_t* actual_count);
int hmr_apply_optimization(const hmr_optimization_recommendation_t* recommendation);

// Alert management
int hmr_get_performance_alerts(hmr_performance_alert_t* alerts, 
                              uint32_t max_alerts, uint32_t* actual_count);
int hmr_acknowledge_alert(uint32_t alert_id);
int hmr_clear_alerts(hmr_agent_id_t agent_id);

// Real-time dashboard support
int hmr_get_performance_json(char* json_buffer, size_t buffer_size);
void hmr_set_performance_update_callback(void (*callback)(const char* json_data));

// Predictive analytics
int hmr_predict_performance_trend(hmr_agent_id_t agent_id, uint32_t prediction_minutes,
                                 double* predicted_values, uint32_t value_count);
bool hmr_detect_performance_anomaly(hmr_agent_id_t agent_id);

// Performance regression detection
int hmr_create_performance_baseline(const char* baseline_name);
int hmr_compare_to_baseline(const char* baseline_name, double* regression_score);
int hmr_trigger_performance_regression_alert(double regression_threshold);

// System coordination
int hmr_coordinate_agent_optimization(hmr_agent_id_t* agents, uint32_t agent_count);
int hmr_trigger_system_performance_reset(void);

// Utilities
const char* hmr_agent_id_to_string(hmr_agent_id_t agent_id);
hmr_agent_id_t hmr_string_to_agent_id(const char* agent_name);
double hmr_calculate_performance_score(const hmr_agent_performance_t* performance);

#ifdef __cplusplus
}
#endif

#endif // HMR_SYSTEM_PERFORMANCE_ORCHESTRATOR_H