/*
 * SimCity ARM64 - Real-time Performance Dashboard
 * Live visualization of system-wide performance with predictive analytics
 * 
 * Agent 0: HMR Orchestrator - Day 11
 * Week 3: Advanced Features & Production Optimization
 */

#include "system_performance_orchestrator.h"
#include "dev_server.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <pthread.h>
#include <unistd.h>

#define DASHBOARD_UPDATE_INTERVAL_MS 100
#define PERFORMANCE_HISTORY_POINTS 300  // 30 seconds at 100ms intervals
#define ALERT_DISPLAY_DURATION_MS 5000
#define CHART_WIDTH 80
#define CHART_HEIGHT 20

// Dashboard state
typedef struct {
    bool active;
    pthread_t dashboard_thread;
    pthread_mutex_t display_mutex;
    
    // Performance history for charts
    double fps_history[PERFORMANCE_HISTORY_POINTS];
    double cpu_history[PERFORMANCE_HISTORY_POINTS];
    double memory_history[PERFORMANCE_HISTORY_POINTS];
    double latency_history[PERFORMANCE_HISTORY_POINTS];
    uint32_t history_index;
    uint32_t history_count;
    
    // Alert display
    hmr_performance_alert_t recent_alerts[10];
    uint32_t recent_alert_count;
    uint64_t last_alert_time_us;
    
    // Display preferences
    bool show_agents_detail;
    bool show_predictions;
    bool show_recommendations;
    bool show_charts;
    bool compact_mode;
    
    // Statistics
    uint64_t dashboard_updates;
    uint64_t chart_renders;
    
} hmr_dashboard_state_t;

static hmr_dashboard_state_t g_dashboard = {0};

// Forward declarations
static void* hmr_dashboard_thread_func(void* arg);
static void hmr_render_dashboard(void);
static void hmr_render_system_overview(const hmr_system_performance_t* perf);
static void hmr_render_agent_details(const hmr_system_performance_t* perf);
static void hmr_render_performance_charts(void);
static void hmr_render_alerts(const hmr_system_performance_t* perf);
static void hmr_render_recommendations(void);
static void hmr_render_predictions(const hmr_system_performance_t* perf);
static void hmr_update_performance_history(const hmr_system_performance_t* perf);
static void hmr_render_ascii_chart(const double* data, uint32_t count, const char* title, const char* unit);
static void hmr_clear_screen(void);
static const char* hmr_get_health_indicator(bool healthy);
static const char* hmr_get_performance_bar(double score);
static const char* hmr_get_trend_indicator(double current, double previous);
static uint64_t hmr_get_current_time_us(void);

// Initialize real-time dashboard
int hmr_realtime_dashboard_init(void) {
    if (g_dashboard.active) {
        printf("[HMR Dashboard] Already initialized\n");
        return 0;
    }
    
    // Initialize dashboard state
    memset(&g_dashboard, 0, sizeof(hmr_dashboard_state_t));
    g_dashboard.show_agents_detail = true;
    g_dashboard.show_predictions = true;
    g_dashboard.show_recommendations = true;
    g_dashboard.show_charts = true;
    g_dashboard.compact_mode = false;
    
    // Initialize mutex
    if (pthread_mutex_init(&g_dashboard.display_mutex, NULL) != 0) {
        printf("[HMR Dashboard] Failed to initialize display mutex\n");
        return 1;
    }
    
    // Start dashboard thread
    g_dashboard.active = true;
    if (pthread_create(&g_dashboard.dashboard_thread, NULL, hmr_dashboard_thread_func, NULL) != 0) {
        printf("[HMR Dashboard] Failed to create dashboard thread\n");
        g_dashboard.active = false;
        pthread_mutex_destroy(&g_dashboard.display_mutex);
        return 1;
    }
    
    printf("[HMR Dashboard] Real-time Performance Dashboard initialized\n");
    printf("  Update interval: %d ms\n", DASHBOARD_UPDATE_INTERVAL_MS);
    printf("  History points: %d (%.1f seconds)\n", PERFORMANCE_HISTORY_POINTS, 
           PERFORMANCE_HISTORY_POINTS * DASHBOARD_UPDATE_INTERVAL_MS / 1000.0);
    
    return 0;
}

// Shutdown dashboard
void hmr_realtime_dashboard_shutdown(void) {
    if (!g_dashboard.active) {
        return;
    }
    
    printf("[HMR Dashboard] Shutting down Real-time Performance Dashboard...\n");
    
    g_dashboard.active = false;
    pthread_join(g_dashboard.dashboard_thread, NULL);
    pthread_mutex_destroy(&g_dashboard.display_mutex);
    
    printf("[HMR Dashboard] Dashboard statistics:\n");
    printf("  Total updates: %llu\n", g_dashboard.dashboard_updates);
    printf("  Chart renders: %llu\n", g_dashboard.chart_renders);
    
    printf("[HMR Dashboard] Shutdown complete\n");
}

// Toggle display options
void hmr_dashboard_toggle_agents_detail(void) {
    g_dashboard.show_agents_detail = !g_dashboard.show_agents_detail;
}

void hmr_dashboard_toggle_predictions(void) {
    g_dashboard.show_predictions = !g_dashboard.show_predictions;
}

void hmr_dashboard_toggle_charts(void) {
    g_dashboard.show_charts = !g_dashboard.show_charts;
}

void hmr_dashboard_toggle_compact_mode(void) {
    g_dashboard.compact_mode = !g_dashboard.compact_mode;
}

// Main dashboard thread
static void* hmr_dashboard_thread_func(void* arg) {
    (void)arg;
    
    printf("[HMR Dashboard] Real-time dashboard thread started\n");
    
    while (g_dashboard.active) {
        pthread_mutex_lock(&g_dashboard.display_mutex);
        hmr_render_dashboard();
        g_dashboard.dashboard_updates++;
        pthread_mutex_unlock(&g_dashboard.display_mutex);
        
        usleep(DASHBOARD_UPDATE_INTERVAL_MS * 1000);
    }
    
    printf("[HMR Dashboard] Dashboard thread exiting\n");
    return NULL;
}

// Render complete dashboard
static void hmr_render_dashboard(void) {
    hmr_system_performance_t perf;
    if (hmr_get_system_performance(&perf) != 0) {
        return;
    }
    
    // Update performance history
    hmr_update_performance_history(&perf);
    
    // Clear screen and render dashboard
    hmr_clear_screen();
    
    printf("\033[1;36m"); // Cyan bold
    printf("╔══════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                    HMR SYSTEM PERFORMANCE DASHBOARD                          ║\n");
    printf("║                          Real-time Monitoring                               ║\n");
    printf("╚══════════════════════════════════════════════════════════════════════════════╝\033[0m\n");
    printf("\n");
    
    // System overview
    hmr_render_system_overview(&perf);
    
    // Agent details
    if (g_dashboard.show_agents_detail) {
        hmr_render_agent_details(&perf);
    }
    
    // Performance charts
    if (g_dashboard.show_charts && g_dashboard.history_count > 10) {
        hmr_render_performance_charts();
    }
    
    // Alerts
    hmr_render_alerts(&perf);
    
    // Recommendations
    if (g_dashboard.show_recommendations) {
        hmr_render_recommendations();
    }
    
    // Predictions
    if (g_dashboard.show_predictions) {
        hmr_render_predictions(&perf);
    }
    
    // Footer with controls
    printf("\n\033[2;37m"); // Dim white
    printf("Controls: [a]gents [p]redictions [c]harts [m]compact [q]uit | Updates: %llu\033[0m\n", 
           g_dashboard.dashboard_updates);
}

// Render system overview
static void hmr_render_system_overview(const hmr_system_performance_t* perf) {
    printf("\033[1;33m"); // Yellow bold
    printf("┌─ SYSTEM OVERVIEW ─────────────────────────────────────────────────────────┐\033[0m\n");
    
    // System health indicator
    const char* health_status = perf->system_healthy ? 
        "\033[1;32m● HEALTHY\033[0m" : "\033[1;31m● DEGRADED\033[0m";
    
    printf("│ Status: %s", health_status);
    if (perf->unhealthy_agents > 0) {
        printf(" (\033[1;31m%u agents degraded\033[0m)", perf->unhealthy_agents);
    }
    
    // Calculate padding for alignment
    int padding = 55 - (perf->system_healthy ? 14 : 16) - 
                  (perf->unhealthy_agents > 0 ? 20 : 0);
    for (int i = 0; i < padding; i++) printf(" ");
    
    printf("│\n");
    
    // System metrics
    printf("│ FPS: \033[1;36m%6.1f\033[0m %s", perf->system_fps, hmr_get_performance_bar(perf->system_fps / 60.0));
    printf("  CPU: \033[1;35m%5.1f%%\033[0m %s", perf->system_cpu_usage_percent, hmr_get_performance_bar(1.0 - perf->system_cpu_usage_percent / 100.0));
    printf(" │\n");
    
    printf("│ Memory: \033[1;34m%7.1f MB\033[0m %s", perf->system_memory_usage_mb, hmr_get_performance_bar(1.0 - perf->system_memory_usage_mb / 2048.0));
    printf("  Latency: \033[1;31m%5.1f ms\033[0m %s", perf->system_latency_ms, hmr_get_performance_bar(1.0 - perf->system_latency_ms / 100.0));
    printf(" │\n");
    
    printf("│ Throughput: \033[1;32m%8.0f ops/sec\033[0m", perf->system_throughput_ops_per_sec);
    if (perf->performance_alerts > 0) {
        printf("  \033[1;31mAlerts: %u\033[0m", perf->performance_alerts);
    }
    printf("%*s│\n", 35 - (perf->performance_alerts > 0 ? 12 : 0), "");
    
    // Bottleneck information
    if (perf->primary_bottleneck < HMR_AGENT_COUNT) {
        printf("│ \033[1;31mBottleneck\033[0m: %s", hmr_agent_id_to_string(perf->primary_bottleneck));
        printf("  \033[1;33mSeverity\033[0m: %.1f%%", perf->bottleneck_severity * 100.0);
        printf("%*s│\n", 40, "");
    }
    
    printf("\033[1;33m└───────────────────────────────────────────────────────────────────────────────┘\033[0m\n\n");
}

// Render agent details
static void hmr_render_agent_details(const hmr_system_performance_t* perf) {
    printf("\033[1;33m"); // Yellow bold
    printf("┌─ AGENT PERFORMANCE ───────────────────────────────────────────────────────┐\033[0m\n");
    
    if (g_dashboard.compact_mode) {
        // Compact view - one line per agent
        for (int i = 0; i < HMR_AGENT_COUNT; i++) {
            const hmr_agent_performance_t* agent = &perf->agents[i];
            printf("│ %-15s %s", agent->agent_name, hmr_get_health_indicator(agent->is_healthy));
            printf(" \033[36m%5.1fms\033[0m", agent->latency_ms);
            printf(" \033[35m%4.0f%%\033[0m", agent->cpu_usage_percent);
            printf(" \033[34m%6.1fMB\033[0m", agent->memory_usage_mb);
            printf(" %s", hmr_get_performance_bar(agent->performance_score));
            printf("│\n");
        }
    } else {
        // Detailed view - multiple lines per agent
        for (int i = 0; i < HMR_AGENT_COUNT; i++) {
            const hmr_agent_performance_t* agent = &perf->agents[i];
            
            printf("│ \033[1;37m%s\033[0m %s", agent->agent_name, hmr_get_health_indicator(agent->is_healthy));
            if (agent->has_bottleneck) {
                printf(" \033[1;31m[BOTTLENECK]\033[0m");
            }
            if (agent->needs_optimization) {
                printf(" \033[1;33m[OPTIMIZE]\033[0m");
            }
            printf("%*s│\n", 40, "");
            
            printf("│   Performance: %s \033[2;37m(%.3f)\033[0m", 
                   hmr_get_performance_bar(agent->performance_score), agent->performance_score);
            printf("   Latency: \033[36m%.1fms\033[0m", agent->latency_ms);
            printf("   Throughput: \033[32m%.0f ops/s\033[0m", agent->throughput_ops_per_sec);
            printf("%*s│\n", 20, "");
            
            printf("│   CPU: \033[35m%.1f%%\033[0m", agent->cpu_usage_percent);
            printf("   Memory: \033[34m%.1fMB\033[0m", agent->memory_usage_mb);
            printf("   Errors: \033[31m%.2f%%\033[0m", agent->error_rate_percent);
            printf("%*s│\n", 35, "");
            
            if (i < HMR_AGENT_COUNT - 1) {
                printf("│%*s│\n", 79, "");
            }
        }
    }
    
    printf("\033[1;33m└───────────────────────────────────────────────────────────────────────────────┘\033[0m\n\n");
}

// Render performance charts
static void hmr_render_performance_charts(void) {
    printf("\033[1;33m"); // Yellow bold
    printf("┌─ PERFORMANCE TRENDS (Last 30 seconds) ───────────────────────────────────┐\033[0m\n");
    
    // Render charts for key metrics
    hmr_render_ascii_chart(g_dashboard.fps_history, g_dashboard.history_count, "FPS", "");
    hmr_render_ascii_chart(g_dashboard.cpu_history, g_dashboard.history_count, "CPU %", "%");
    hmr_render_ascii_chart(g_dashboard.memory_history, g_dashboard.history_count, "Memory", "MB");
    hmr_render_ascii_chart(g_dashboard.latency_history, g_dashboard.history_count, "Latency", "ms");
    
    printf("\033[1;33m└───────────────────────────────────────────────────────────────────────────────┘\033[0m\n\n");
    
    g_dashboard.chart_renders++;
}

// Render alerts
static void hmr_render_alerts(const hmr_system_performance_t* perf) {
    if (perf->performance_alerts == 0) {
        return;
    }
    
    printf("\033[1;31m"); // Red bold
    printf("┌─ PERFORMANCE ALERTS ──────────────────────────────────────────────────────┐\033[0m\n");
    
    hmr_performance_alert_t alerts[10];
    uint32_t alert_count;
    
    if (hmr_get_performance_alerts(alerts, 10, &alert_count) == 0) {
        for (uint32_t i = 0; i < alert_count && i < 5; i++) {
            const hmr_performance_alert_t* alert = &alerts[i];
            
            const char* severity_color = strcmp(alert->alert_type, "CRITICAL") == 0 ? 
                "\033[1;31m" : "\033[1;33m"; // Red for critical, yellow for warning
            
            printf("│ %s%s\033[0m: %s", severity_color, alert->alert_type, alert->message);
            printf("%*s│\n", 60 - (int)strlen(alert->message), "");
        }
        
        if (alert_count > 5) {
            printf("│ \033[2;37m... and %u more alerts\033[0m", alert_count - 5);
            printf("%*s│\n", 50, "");
        }
    }
    
    printf("\033[1;31m└───────────────────────────────────────────────────────────────────────────────┘\033[0m\n\n");
}

// Render optimization recommendations
static void hmr_render_recommendations(void) {
    hmr_optimization_recommendation_t recommendations[10];
    uint32_t rec_count;
    
    if (hmr_analyze_bottlenecks(recommendations, 10, &rec_count) != 0 || rec_count == 0) {
        return;
    }
    
    printf("\033[1;32m"); // Green bold
    printf("┌─ OPTIMIZATION RECOMMENDATIONS ────────────────────────────────────────────┐\033[0m\n");
    
    for (uint32_t i = 0; i < rec_count && i < 3; i++) {
        const hmr_optimization_recommendation_t* rec = &recommendations[i];
        
        printf("│ \033[1;37m%s\033[0m (\033[33mPriority: %u\033[0m)", 
               hmr_agent_id_to_string(rec->target_agent), rec->priority);
        printf("%*s│\n", 45, "");
        
        printf("│   %s: %s", rec->optimization_type, rec->description);
        printf("%*s│\n", 60 - (int)strlen(rec->description), "");
        
        printf("│   Expected improvement: \033[32m+%.1f%%\033[0m", rec->expected_improvement_percent);
        if (rec->auto_applicable) {
            printf("  \033[2;37m[Auto-applicable]\033[0m");
        }
        printf("%*s│\n", 35, "");
        
        if (i < rec_count - 1 && i < 2) {
            printf("│%*s│\n", 79, "");
        }
    }
    
    printf("\033[1;32m└───────────────────────────────────────────────────────────────────────────────┘\033[0m\n\n");
}

// Render predictions
static void hmr_render_predictions(const hmr_system_performance_t* perf) {
    if (perf->predicted_fps_next_minute == 0.0 && perf->predicted_memory_usage_mb == 0.0) {
        return;
    }
    
    printf("\033[1;34m"); // Blue bold
    printf("┌─ PREDICTIVE ANALYTICS (Next Minute) ──────────────────────────────────────┐\033[0m\n");
    
    if (perf->predicted_fps_next_minute > 0.0) {
        const char* fps_trend = hmr_get_trend_indicator(perf->predicted_fps_next_minute, perf->system_fps);
        printf("│ Predicted FPS: \033[1;36m%.1f\033[0m %s", perf->predicted_fps_next_minute, fps_trend);
        printf("  (Current: %.1f)", perf->system_fps);
        printf("%*s│\n", 35, "");
    }
    
    if (perf->predicted_memory_usage_mb > 0.0) {
        const char* mem_trend = hmr_get_trend_indicator(perf->predicted_memory_usage_mb, perf->system_memory_usage_mb);
        printf("│ Predicted Memory: \033[1;34m%.1f MB\033[0m %s", perf->predicted_memory_usage_mb, mem_trend);
        printf("  (Current: %.1f MB)", perf->system_memory_usage_mb);
        printf("%*s│\n", 25, "");
    }
    
    if (perf->performance_degradation_detected) {
        printf("│ \033[1;31mPerformance degradation detected\033[0m - Consider optimization");
        printf("%*s│\n", 25, "");
    }
    
    printf("\033[1;34m└───────────────────────────────────────────────────────────────────────────────┘\033[0m\n\n");
}

// Update performance history for charts
static void hmr_update_performance_history(const hmr_system_performance_t* perf) {
    uint32_t idx = g_dashboard.history_index;
    
    g_dashboard.fps_history[idx] = perf->system_fps;
    g_dashboard.cpu_history[idx] = perf->system_cpu_usage_percent;
    g_dashboard.memory_history[idx] = perf->system_memory_usage_mb;
    g_dashboard.latency_history[idx] = perf->system_latency_ms;
    
    g_dashboard.history_index = (g_dashboard.history_index + 1) % PERFORMANCE_HISTORY_POINTS;
    if (g_dashboard.history_count < PERFORMANCE_HISTORY_POINTS) {
        g_dashboard.history_count++;
    }
}

// Render ASCII chart
static void hmr_render_ascii_chart(const double* data, uint32_t count, const char* title, const char* unit) {
    if (count < 2) return;
    
    // Find min/max values
    double min_val = data[0], max_val = data[0];
    for (uint32_t i = 1; i < count; i++) {
        if (data[i] < min_val) min_val = data[i];
        if (data[i] > max_val) max_val = data[i];
    }
    
    if (max_val == min_val) max_val = min_val + 1.0; // Avoid division by zero
    
    printf("│ \033[1;37m%s\033[0m", title);
    printf("  Min: \033[32m%.1f%s\033[0m", min_val, unit);
    printf("  Max: \033[31m%.1f%s\033[0m", max_val, unit);
    printf("  Current: \033[36m%.1f%s\033[0m", data[(g_dashboard.history_index + PERFORMANCE_HISTORY_POINTS - 1) % PERFORMANCE_HISTORY_POINTS], unit);
    printf("%*s│\n", 25, "");
    
    // Render mini chart (simplified)
    printf("│ ");
    uint32_t chart_width = 75;
    uint32_t step = count > chart_width ? count / chart_width : 1;
    
    for (uint32_t i = 0; i < chart_width && i * step < count; i++) {
        uint32_t data_idx = i * step;
        if (data_idx >= count) data_idx = count - 1;
        
        double normalized = (data[data_idx] - min_val) / (max_val - min_val);
        
        if (normalized < 0.2) printf("\033[32m▁\033[0m");      // Green - low
        else if (normalized < 0.4) printf("\033[32m▂\033[0m");  // Green - low-medium
        else if (normalized < 0.6) printf("\033[33m▄\033[0m");  // Yellow - medium
        else if (normalized < 0.8) printf("\033[31m▆\033[0m");  // Red - high
        else printf("\033[31m█\033[0m");                        // Red - very high
    }
    printf("│\n");
}

// Utility functions
static void hmr_clear_screen(void) {
    printf("\033[2J\033[H"); // Clear screen and move cursor to top
}

static const char* hmr_get_health_indicator(bool healthy) {
    return healthy ? "\033[1;32m●\033[0m" : "\033[1;31m●\033[0m";
}

static const char* hmr_get_performance_bar(double score) {
    if (score >= 0.9) return "\033[32m████████████\033[0m"; // Green
    if (score >= 0.8) return "\033[32m██████████\033[2;32m██\033[0m";
    if (score >= 0.7) return "\033[32m████████\033[2;32m████\033[0m";
    if (score >= 0.6) return "\033[33m██████\033[2;33m██████\033[0m"; // Yellow
    if (score >= 0.5) return "\033[33m████\033[2;33m████████\033[0m";
    if (score >= 0.3) return "\033[31m██\033[2;31m██████████\033[0m"; // Red
    return "\033[2;31m████████████\033[0m"; // Dim red
}

static const char* hmr_get_trend_indicator(double current, double previous) {
    if (current > previous * 1.05) return "\033[32m↗\033[0m";  // Green up
    if (current < previous * 0.95) return "\033[31m↘\033[0m";  // Red down
    return "\033[37m→\033[0m";  // Gray stable
}

static uint64_t hmr_get_current_time_us(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (uint64_t)tv.tv_sec * 1000000 + tv.tv_usec;
}