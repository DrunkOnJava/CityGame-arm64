/*
 * SimCity ARM64 - Performance Regression Detection System Header
 * Automated detection and CI integration for performance regressions
 * 
 * Agent 0: HMR Orchestrator - Day 11
 * Week 3: Advanced Features & Production Optimization
 */

#ifndef HMR_PERFORMANCE_REGRESSION_DETECTOR_H
#define HMR_PERFORMANCE_REGRESSION_DETECTOR_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Forward declarations
typedef struct hmr_regression_result_t hmr_regression_result_t;

// CI integration configuration
typedef struct {
    // Thresholds for CI blocking (percentage degradation)
    double max_latency_degradation_percent;
    double max_memory_degradation_percent;
    double max_fps_degradation_percent;
    double max_overall_degradation_percent;
    
    // Test configuration
    uint32_t test_duration_seconds;
    uint32_t warmup_seconds;
    uint32_t samples_required;
    
    // Output configuration
    bool generate_json_report;
    bool verbose_logging;
    bool fail_on_regression;
    
} hmr_ci_config_t;

// Regression detection result
struct hmr_regression_result_t {
    bool regression_detected;
    double severity_score; // 0.0 to 1.0
    char regression_type[64]; // "latency", "memory", "fps", "stability"
    char affected_agents[256];
    
    // Comparison metrics
    double baseline_value;
    double current_value;
    double degradation_percent;
    
    // Recommendations
    char recommendations[512];
    bool blocking_for_ci;
    
    uint64_t detection_timestamp_us;
};

// Initialization and lifecycle
int hmr_performance_regression_detector_init(const hmr_ci_config_t* config);
void hmr_performance_regression_detector_shutdown(void);

// Baseline management
int hmr_create_performance_baseline(const char* name, const char* description);
int hmr_get_available_baselines(char* baseline_names, size_t buffer_size);

// Regression detection
int hmr_run_regression_detection(hmr_regression_result_t* results, 
                                uint32_t max_results, uint32_t* actual_count);

// CI integration
int hmr_ci_performance_check(bool* should_block_ci);

// Utility functions
const char* hmr_regression_severity_to_string(double severity_score);
bool hmr_is_regression_blocking(const hmr_regression_result_t* regression);

// Configuration helpers
hmr_ci_config_t hmr_get_default_ci_config(void);
hmr_ci_config_t hmr_get_strict_ci_config(void);
hmr_ci_config_t hmr_get_development_ci_config(void);

#ifdef __cplusplus
}
#endif

#endif // HMR_PERFORMANCE_REGRESSION_DETECTOR_H