/*
 * SimCity ARM64 - Performance Regression Detection System
 * Automated detection and CI integration for performance regressions
 * 
 * Agent 0: HMR Orchestrator - Day 11
 * Week 3: Advanced Features & Production Optimization
 */

#include "system_performance_orchestrator.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <sys/stat.h>
#include <dirent.h>
#include <unistd.h>

#define MAX_BASELINES 50
#define MAX_REGRESSION_ALERTS 100
#define BASELINE_STORAGE_PATH "/tmp/hmr_baselines"
#define REGRESSION_LOG_PATH "/tmp/hmr_regression.log"
#define CI_REPORT_PATH "/tmp/hmr_ci_report.json"

// Performance baseline storage
typedef struct {
    char name[64];
    char description[256];
    char git_commit[64];
    char build_config[128];
    uint64_t creation_timestamp_us;
    
    // Performance metrics
    double avg_system_latency_ms;
    double avg_system_memory_mb;
    double avg_system_fps;
    double avg_cpu_usage_percent;
    
    // Agent-specific baselines
    struct {
        double avg_latency_ms;
        double avg_memory_mb;
        double avg_cpu_percent;
        double performance_score;
    } agents[HMR_AGENT_COUNT];
    
    // Statistical data
    double latency_std_dev;
    double memory_std_dev;
    double fps_std_dev;
    
    // Metadata
    uint32_t samples_collected;
    uint32_t test_duration_seconds;
    bool validated;
    
} hmr_performance_baseline_t;

// Regression detection result
typedef struct {
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
    
} hmr_regression_result_t;

// CI integration configuration
typedef struct {
    // Thresholds for CI blocking
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

// Global state
static hmr_performance_baseline_t g_baselines[MAX_BASELINES];
static uint32_t g_baseline_count = 0;
static hmr_regression_result_t g_recent_regressions[MAX_REGRESSION_ALERTS];
static uint32_t g_regression_count = 0;
static hmr_ci_config_t g_ci_config = {0};
static FILE* g_regression_log = NULL;

// Forward declarations
static int hmr_create_baseline_directory(void);
static int hmr_save_baseline_to_disk(const hmr_performance_baseline_t* baseline);
static int hmr_load_baselines_from_disk(void);
static int hmr_collect_baseline_data(hmr_performance_baseline_t* baseline, uint32_t duration_seconds);
static hmr_regression_result_t hmr_compare_with_baseline(const hmr_performance_baseline_t* baseline);
static void hmr_log_regression(const hmr_regression_result_t* regression);
static void hmr_generate_ci_report(const hmr_regression_result_t* regressions, uint32_t count);
static double hmr_calculate_statistical_significance(double baseline_mean, double baseline_std,
                                                   double current_mean, uint32_t samples);
static uint64_t hmr_get_current_time_us(void);
static void hmr_get_git_commit_hash(char* buffer, size_t buffer_size);
static void hmr_get_build_config(char* buffer, size_t buffer_size);

// Initialize performance regression detector
int hmr_performance_regression_detector_init(const hmr_ci_config_t* config) {
    // Set default configuration if none provided
    if (config) {
        g_ci_config = *config;
    } else {
        g_ci_config.max_latency_degradation_percent = 20.0;
        g_ci_config.max_memory_degradation_percent = 15.0;
        g_ci_config.max_fps_degradation_percent = 10.0;
        g_ci_config.max_overall_degradation_percent = 25.0;
        g_ci_config.test_duration_seconds = 30;
        g_ci_config.warmup_seconds = 5;
        g_ci_config.samples_required = 100;
        g_ci_config.generate_json_report = true;
        g_ci_config.verbose_logging = true;
        g_ci_config.fail_on_regression = true;
    }
    
    // Create baseline storage directory
    if (hmr_create_baseline_directory() != 0) {
        printf("[Regression Detector] Failed to create baseline directory\n");
        return 1;
    }
    
    // Load existing baselines
    if (hmr_load_baselines_from_disk() != 0) {
        printf("[Regression Detector] Warning: Failed to load existing baselines\n");
    }
    
    // Open regression log
    g_regression_log = fopen(REGRESSION_LOG_PATH, "a");
    if (!g_regression_log) {
        printf("[Regression Detector] Warning: Failed to open regression log\n");
    }
    
    printf("[Regression Detector] Performance Regression Detector initialized\n");
    printf("  Baseline directory: %s\n", BASELINE_STORAGE_PATH);
    printf("  Loaded baselines: %u\n", g_baseline_count);
    printf("  Latency threshold: %.1f%%\n", g_ci_config.max_latency_degradation_percent);
    printf("  Memory threshold: %.1f%%\n", g_ci_config.max_memory_degradation_percent);
    printf("  FPS threshold: %.1f%%\n", g_ci_config.max_fps_degradation_percent);
    
    return 0;
}

// Shutdown regression detector
void hmr_performance_regression_detector_shutdown(void) {
    if (g_regression_log) {
        fclose(g_regression_log);
        g_regression_log = NULL;
    }
    
    printf("[Regression Detector] Shutdown complete\n");
    printf("  Total baselines: %u\n", g_baseline_count);
    printf("  Regressions detected: %u\n", g_regression_count);
}

// Create performance baseline
int hmr_create_performance_baseline(const char* name, const char* description) {
    if (!name || g_baseline_count >= MAX_BASELINES) {
        return 1; // Error
    }
    
    printf("[Regression Detector] Creating performance baseline: %s\n", name);
    
    hmr_performance_baseline_t baseline = {0};
    strncpy(baseline.name, name, sizeof(baseline.name) - 1);
    if (description) {
        strncpy(baseline.description, description, sizeof(baseline.description) - 1);
    }
    
    // Get current git commit and build config
    hmr_get_git_commit_hash(baseline.git_commit, sizeof(baseline.git_commit));
    hmr_get_build_config(baseline.build_config, sizeof(baseline.build_config));
    
    baseline.creation_timestamp_us = hmr_get_current_time_us();
    baseline.test_duration_seconds = g_ci_config.test_duration_seconds;
    
    // Collect baseline performance data
    if (hmr_collect_baseline_data(&baseline, g_ci_config.test_duration_seconds) != 0) {
        printf("[Regression Detector] Failed to collect baseline data\n");
        return 1;
    }
    
    // Validate baseline
    if (baseline.avg_system_latency_ms > 0.0 && baseline.samples_collected >= g_ci_config.samples_required) {
        baseline.validated = true;
        
        // Store baseline
        g_baselines[g_baseline_count] = baseline;
        g_baseline_count++;
        
        // Save to disk
        if (hmr_save_baseline_to_disk(&baseline) != 0) {
            printf("[Regression Detector] Warning: Failed to save baseline to disk\n");
        }
        
        printf("[Regression Detector] Baseline created successfully\n");
        printf("  Samples collected: %u\n", baseline.samples_collected);
        printf("  Average latency: %.2f ms\n", baseline.avg_system_latency_ms);
        printf("  Average memory: %.1f MB\n", baseline.avg_system_memory_mb);
        printf("  Average FPS: %.1f\n", baseline.avg_system_fps);
        
        return 0;
    } else {
        printf("[Regression Detector] Baseline validation failed\n");
        return 1;
    }
}

// Run regression detection against all baselines
int hmr_run_regression_detection(hmr_regression_result_t* results, uint32_t max_results, uint32_t* actual_count) {
    if (!results || !actual_count) {
        return 1;
    }
    
    *actual_count = 0;
    
    if (g_baseline_count == 0) {
        printf("[Regression Detector] No baselines available for comparison\n");
        return 0;
    }
    
    printf("[Regression Detector] Running regression detection against %u baselines\n", g_baseline_count);
    
    // Test against each validated baseline
    for (uint32_t i = 0; i < g_baseline_count && *actual_count < max_results; i++) {
        if (!g_baselines[i].validated) {
            continue;
        }
        
        printf("  Testing against baseline: %s\n", g_baselines[i].name);
        
        hmr_regression_result_t regression = hmr_compare_with_baseline(&g_baselines[i]);
        
        if (regression.regression_detected) {
            results[*actual_count] = regression;
            (*actual_count)++;
            
            // Log regression
            hmr_log_regression(&regression);
            
            printf("    ⚠️  Regression detected: %s (severity: %.1f%%)\n", 
                   regression.regression_type, regression.severity_score * 100.0);
        } else {
            printf("    ✅ No regression detected\n");
        }
    }
    
    // Generate CI report if enabled
    if (g_ci_config.generate_json_report && *actual_count > 0) {
        hmr_generate_ci_report(results, *actual_count);
    }
    
    printf("[Regression Detector] Regression detection completed: %u regressions found\n", *actual_count);
    
    return 0;
}

// CI integration function
int hmr_ci_performance_check(bool* should_block_ci) {
    if (!should_block_ci) {
        return 1;
    }
    
    *should_block_ci = false;
    
    printf("[Regression Detector] Running CI performance check\n");
    
    hmr_regression_result_t regressions[10];
    uint32_t regression_count;
    
    if (hmr_run_regression_detection(regressions, 10, &regression_count) != 0) {
        printf("[Regression Detector] Failed to run regression detection\n");
        return 1;
    }
    
    // Check if any regressions should block CI
    bool blocking_regression_found = false;
    for (uint32_t i = 0; i < regression_count; i++) {
        if (regressions[i].blocking_for_ci) {
            blocking_regression_found = true;
            *should_block_ci = true;
            
            printf("[Regression Detector] 🚫 CI-blocking regression detected:\n");
            printf("  Type: %s\n", regressions[i].regression_type);
            printf("  Degradation: %.1f%%\n", regressions[i].degradation_percent);
            printf("  Affected agents: %s\n", regressions[i].affected_agents);
            printf("  Recommendations: %s\n", regressions[i].recommendations);
        }
    }
    
    if (!blocking_regression_found) {
        printf("[Regression Detector] ✅ CI performance check passed\n");
    }
    
    return 0;
}

// Get available baselines
int hmr_get_available_baselines(char* baseline_names, size_t buffer_size) {
    if (!baseline_names || buffer_size == 0) {
        return 1;
    }
    
    size_t pos = 0;
    for (uint32_t i = 0; i < g_baseline_count && pos < buffer_size - 1; i++) {
        if (g_baselines[i].validated) {
            int written = snprintf(baseline_names + pos, buffer_size - pos, 
                                 "%s (%s)\n", g_baselines[i].name, g_baselines[i].description);
            if (written > 0) {
                pos += written;
            }
        }
    }
    
    return 0;
}

// Collect baseline performance data
static int hmr_collect_baseline_data(hmr_performance_baseline_t* baseline, uint32_t duration_seconds) {
    printf("  Collecting baseline data for %u seconds...\n", duration_seconds);
    
    // Arrays to collect statistics
    double latency_samples[1000];
    double memory_samples[1000];
    double fps_samples[1000];
    double cpu_samples[1000];
    uint32_t sample_count = 0;
    
    // Warmup period
    printf("  Warmup period: %u seconds\n", g_ci_config.warmup_seconds);
    sleep(g_ci_config.warmup_seconds);
    
    // Collection period
    for (uint32_t second = 0; second < duration_seconds && sample_count < 1000; second++) {
        sleep(1);
        
        hmr_system_performance_t perf;
        if (hmr_get_system_performance(&perf) == 0) {
            latency_samples[sample_count] = perf.system_latency_ms;
            memory_samples[sample_count] = perf.system_memory_usage_mb;
            fps_samples[sample_count] = perf.system_fps;
            cpu_samples[sample_count] = perf.system_cpu_usage_percent;
            sample_count++;
            
            if (g_ci_config.verbose_logging && second % 5 == 0) {
                printf("    Progress: %u/%u seconds, samples: %u\n", 
                       second + 1, duration_seconds, sample_count);
            }
        }
    }
    
    if (sample_count < g_ci_config.samples_required) {
        printf("  Insufficient samples collected: %u < %u\n", sample_count, g_ci_config.samples_required);
        return 1;
    }
    
    // Calculate statistics
    double latency_sum = 0.0, memory_sum = 0.0, fps_sum = 0.0, cpu_sum = 0.0;
    for (uint32_t i = 0; i < sample_count; i++) {
        latency_sum += latency_samples[i];
        memory_sum += memory_samples[i];
        fps_sum += fps_samples[i];
        cpu_sum += cpu_samples[i];
    }
    
    baseline->avg_system_latency_ms = latency_sum / sample_count;
    baseline->avg_system_memory_mb = memory_sum / sample_count;
    baseline->avg_system_fps = fps_sum / sample_count;
    baseline->avg_cpu_usage_percent = cpu_sum / sample_count;
    baseline->samples_collected = sample_count;
    
    // Calculate standard deviations
    double latency_var = 0.0, memory_var = 0.0, fps_var = 0.0;
    for (uint32_t i = 0; i < sample_count; i++) {
        double lat_diff = latency_samples[i] - baseline->avg_system_latency_ms;
        double mem_diff = memory_samples[i] - baseline->avg_system_memory_mb;
        double fps_diff = fps_samples[i] - baseline->avg_system_fps;
        
        latency_var += lat_diff * lat_diff;
        memory_var += mem_diff * mem_diff;
        fps_var += fps_diff * fps_diff;
    }
    
    baseline->latency_std_dev = sqrt(latency_var / (sample_count - 1));
    baseline->memory_std_dev = sqrt(memory_var / (sample_count - 1));
    baseline->fps_std_dev = sqrt(fps_var / (sample_count - 1));
    
    // Collect agent-specific data
    for (int agent_id = 0; agent_id < HMR_AGENT_COUNT; agent_id++) {
        hmr_agent_performance_t agent_perf;
        if (hmr_get_agent_performance((hmr_agent_id_t)agent_id, &agent_perf) == 0) {
            baseline->agents[agent_id].avg_latency_ms = agent_perf.latency_ms;
            baseline->agents[agent_id].avg_memory_mb = agent_perf.memory_usage_mb;
            baseline->agents[agent_id].avg_cpu_percent = agent_perf.cpu_usage_percent;
            baseline->agents[agent_id].performance_score = agent_perf.performance_score;
        }
    }
    
    printf("  Baseline data collection completed\n");
    return 0;
}

// Compare current performance with baseline
static hmr_regression_result_t hmr_compare_with_baseline(const hmr_performance_baseline_t* baseline) {
    hmr_regression_result_t result = {0};
    result.detection_timestamp_us = hmr_get_current_time_us();
    
    // Get current performance
    hmr_system_performance_t current_perf;
    if (hmr_get_system_performance(&current_perf) != 0) {
        return result; // No regression if can't get current data
    }
    
    // Compare latency
    double latency_degradation = ((current_perf.system_latency_ms - baseline->avg_system_latency_ms) / 
                                 baseline->avg_system_latency_ms) * 100.0;
    
    // Compare memory
    double memory_degradation = ((current_perf.system_memory_usage_mb - baseline->avg_system_memory_mb) / 
                                baseline->avg_system_memory_mb) * 100.0;
    
    // Compare FPS
    double fps_degradation = ((baseline->avg_system_fps - current_perf.system_fps) / 
                             baseline->avg_system_fps) * 100.0;
    
    // Determine most significant regression
    double max_degradation = 0.0;
    if (latency_degradation > g_ci_config.max_latency_degradation_percent && 
        latency_degradation > max_degradation) {
        max_degradation = latency_degradation;
        strncpy(result.regression_type, "latency", sizeof(result.regression_type) - 1);
        result.baseline_value = baseline->avg_system_latency_ms;
        result.current_value = current_perf.system_latency_ms;
        result.degradation_percent = latency_degradation;
        result.blocking_for_ci = g_ci_config.fail_on_regression;
        snprintf(result.recommendations, sizeof(result.recommendations),
                "System latency increased by %.1f%%. Check for CPU bottlenecks and optimize hot paths.",
                latency_degradation);
    }
    
    if (memory_degradation > g_ci_config.max_memory_degradation_percent && 
        memory_degradation > max_degradation) {
        max_degradation = memory_degradation;
        strncpy(result.regression_type, "memory", sizeof(result.regression_type) - 1);
        result.baseline_value = baseline->avg_system_memory_mb;
        result.current_value = current_perf.system_memory_usage_mb;
        result.degradation_percent = memory_degradation;
        result.blocking_for_ci = g_ci_config.fail_on_regression;
        snprintf(result.recommendations, sizeof(result.recommendations),
                "Memory usage increased by %.1f%%. Check for memory leaks and optimize allocations.",
                memory_degradation);
    }
    
    if (fps_degradation > g_ci_config.max_fps_degradation_percent && 
        fps_degradation > max_degradation) {
        max_degradation = fps_degradation;
        strncpy(result.regression_type, "fps", sizeof(result.regression_type) - 1);
        result.baseline_value = baseline->avg_system_fps;
        result.current_value = current_perf.system_fps;
        result.degradation_percent = fps_degradation;
        result.blocking_for_ci = g_ci_config.fail_on_regression;
        snprintf(result.recommendations, sizeof(result.recommendations),
                "Frame rate decreased by %.1f%%. Optimize rendering pipeline and reduce frame time.",
                fps_degradation);
    }
    
    // Check agent-specific regressions
    char affected_agents[256] = {0};
    size_t affected_pos = 0;
    for (int i = 0; i < HMR_AGENT_COUNT; i++) {
        hmr_agent_performance_t agent_perf;
        if (hmr_get_agent_performance((hmr_agent_id_t)i, &agent_perf) == 0) {
            double agent_degradation = ((agent_perf.latency_ms - baseline->agents[i].avg_latency_ms) / 
                                       baseline->agents[i].avg_latency_ms) * 100.0;
            
            if (agent_degradation > 30.0) { // 30% agent-specific threshold
                if (affected_pos > 0) {
                    affected_pos += snprintf(affected_agents + affected_pos, 
                                           sizeof(affected_agents) - affected_pos, ", ");
                }
                affected_pos += snprintf(affected_agents + affected_pos, 
                                       sizeof(affected_agents) - affected_pos, 
                                       "%s", hmr_agent_id_to_string((hmr_agent_id_t)i));
            }
        }
    }
    
    if (strlen(affected_agents) > 0) {
        strncpy(result.affected_agents, affected_agents, sizeof(result.affected_agents) - 1);
    }
    
    // Set overall result
    if (max_degradation > 0.0) {
        result.regression_detected = true;
        result.severity_score = max_degradation / 100.0;
        
        // Store in global list
        if (g_regression_count < MAX_REGRESSION_ALERTS) {
            g_recent_regressions[g_regression_count] = result;
            g_regression_count++;
        }
    }
    
    return result;
}

// Log regression to file
static void hmr_log_regression(const hmr_regression_result_t* regression) {
    if (!g_regression_log || !regression) {
        return;
    }
    
    time_t now = time(NULL);
    struct tm* tm_info = localtime(&now);
    char timestamp[64];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", tm_info);
    
    fprintf(g_regression_log, "[%s] REGRESSION DETECTED\n", timestamp);
    fprintf(g_regression_log, "  Type: %s\n", regression->regression_type);
    fprintf(g_regression_log, "  Severity: %.1f%%\n", regression->severity_score * 100.0);
    fprintf(g_regression_log, "  Baseline: %.2f, Current: %.2f\n", 
            regression->baseline_value, regression->current_value);
    fprintf(g_regression_log, "  Degradation: %.1f%%\n", regression->degradation_percent);
    fprintf(g_regression_log, "  Affected Agents: %s\n", regression->affected_agents);
    fprintf(g_regression_log, "  CI Blocking: %s\n", regression->blocking_for_ci ? "YES" : "NO");
    fprintf(g_regression_log, "  Recommendations: %s\n", regression->recommendations);
    fprintf(g_regression_log, "\n");
    
    fflush(g_regression_log);
}

// Generate CI report in JSON format
static void hmr_generate_ci_report(const hmr_regression_result_t* regressions, uint32_t count) {
    FILE* report_file = fopen(CI_REPORT_PATH, "w");
    if (!report_file) {
        printf("[Regression Detector] Failed to create CI report file\n");
        return;
    }
    
    fprintf(report_file, "{\n");
    fprintf(report_file, "  \"performance_regression_report\": {\n");
    fprintf(report_file, "    \"timestamp\": %llu,\n", hmr_get_current_time_us());
    fprintf(report_file, "    \"regression_count\": %u,\n", count);
    fprintf(report_file, "    \"ci_blocking\": %s,\n", 
            count > 0 && regressions[0].blocking_for_ci ? "true" : "false");
    fprintf(report_file, "    \"regressions\": [\n");
    
    for (uint32_t i = 0; i < count; i++) {
        const hmr_regression_result_t* reg = &regressions[i];
        
        fprintf(report_file, "      {\n");
        fprintf(report_file, "        \"type\": \"%s\",\n", reg->regression_type);
        fprintf(report_file, "        \"severity_score\": %.3f,\n", reg->severity_score);
        fprintf(report_file, "        \"degradation_percent\": %.1f,\n", reg->degradation_percent);
        fprintf(report_file, "        \"baseline_value\": %.2f,\n", reg->baseline_value);
        fprintf(report_file, "        \"current_value\": %.2f,\n", reg->current_value);
        fprintf(report_file, "        \"affected_agents\": \"%s\",\n", reg->affected_agents);
        fprintf(report_file, "        \"blocking_for_ci\": %s,\n", reg->blocking_for_ci ? "true" : "false");
        fprintf(report_file, "        \"recommendations\": \"%s\"\n", reg->recommendations);
        fprintf(report_file, "      }%s\n", i < count - 1 ? "," : "");
    }
    
    fprintf(report_file, "    ]\n");
    fprintf(report_file, "  }\n");
    fprintf(report_file, "}\n");
    
    fclose(report_file);
    
    printf("[Regression Detector] CI report generated: %s\n", CI_REPORT_PATH);
}

// Helper functions
static int hmr_create_baseline_directory(void) {
    struct stat st = {0};
    if (stat(BASELINE_STORAGE_PATH, &st) == -1) {
        if (mkdir(BASELINE_STORAGE_PATH, 0755) != 0) {
            return 1;
        }
    }
    return 0;
}

static int hmr_save_baseline_to_disk(const hmr_performance_baseline_t* baseline) {
    char filepath[512];
    snprintf(filepath, sizeof(filepath), "%s/%s.baseline", BASELINE_STORAGE_PATH, baseline->name);
    
    FILE* file = fopen(filepath, "wb");
    if (!file) {
        return 1;
    }
    
    fwrite(baseline, sizeof(hmr_performance_baseline_t), 1, file);
    fclose(file);
    
    return 0;
}

static int hmr_load_baselines_from_disk(void) {
    DIR* dir = opendir(BASELINE_STORAGE_PATH);
    if (!dir) {
        return 1;
    }
    
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL && g_baseline_count < MAX_BASELINES) {
        if (strstr(entry->d_name, ".baseline") != NULL) {
            char filepath[512];
            snprintf(filepath, sizeof(filepath), "%s/%s", BASELINE_STORAGE_PATH, entry->d_name);
            
            FILE* file = fopen(filepath, "rb");
            if (file) {
                hmr_performance_baseline_t baseline;
                if (fread(&baseline, sizeof(hmr_performance_baseline_t), 1, file) == 1) {
                    g_baselines[g_baseline_count] = baseline;
                    g_baseline_count++;
                }
                fclose(file);
            }
        }
    }
    
    closedir(dir);
    return 0;
}

static uint64_t hmr_get_current_time_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
}

static void hmr_get_git_commit_hash(char* buffer, size_t buffer_size) {
    FILE* pipe = popen("git rev-parse HEAD 2>/dev/null", "r");
    if (pipe) {
        if (fgets(buffer, buffer_size, pipe) != NULL) {
            // Remove newline
            char* newline = strchr(buffer, '\n');
            if (newline) *newline = '\0';
        }
        pclose(pipe);
    } else {
        strncpy(buffer, "unknown", buffer_size - 1);
    }
}

static void hmr_get_build_config(char* buffer, size_t buffer_size) {
    snprintf(buffer, buffer_size, "clang -O2 -march=armv8.5-a+crypto+sha3");
}