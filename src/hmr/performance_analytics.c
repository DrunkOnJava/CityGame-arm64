/*
 * SimCity ARM64 - Performance Analytics System
 * Advanced performance monitoring and historical data analysis
 * 
 * Agent 4: Developer Tools & Debug Interface
 * Day 6: Enhanced Performance Analytics Dashboard
 */

#include "performance_analytics.h"
#include "dev_server.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>
#include <sys/time.h>
#include <mach/mach.h>
#include <mach/mach_time.h>

// Configuration
#define MAX_PERFORMANCE_SAMPLES 10000
#define MAX_PERFORMANCE_CATEGORIES 16
#define MAX_PROFILER_ENTRIES 512
#define ANALYTICS_UPDATE_INTERVAL_MS 100
#define HISTORY_RETENTION_HOURS 24

// Performance sample with extended metrics
typedef struct {
    uint64_t timestamp_us;  // Microsecond precision
    double fps;
    double frame_time_ms;
    double cpu_usage_percent;
    double memory_usage_mb;
    double gpu_usage_percent;
    double disk_io_mbps;
    double network_io_mbps;
    uint32_t thread_count;
    uint32_t heap_allocations;
    uint32_t stack_usage_kb;
    double temperature_celsius;
    uint32_t power_draw_watts;
    
    // Module-specific metrics
    struct {
        double load_time_ms;
        uint32_t call_count;
        double total_time_ms;
    } modules[8]; // platform, memory, graphics, simulation, ui, audio, ai, hmr
} hmr_performance_sample_t;

// Performance category tracking
typedef struct {
    char name[32];
    double min_value;
    double max_value;
    double avg_value;
    double current_value;
    uint32_t sample_count;
    double trend_slope; // Linear regression slope
    bool alert_triggered;
    double alert_threshold;
} hmr_performance_category_t;

// Function profiler entry
typedef struct {
    char function_name[64];
    char module_name[32];
    uint64_t call_count;
    uint64_t total_time_us;
    uint64_t min_time_us;
    uint64_t max_time_us;
    double avg_time_us;
    uint64_t last_call_timestamp;
    bool active;
} hmr_profiler_entry_t;

// Main analytics system state
typedef struct {
    hmr_performance_sample_t samples[MAX_PERFORMANCE_SAMPLES];
    hmr_performance_category_t categories[MAX_PERFORMANCE_CATEGORIES];
    hmr_profiler_entry_t profiler_entries[MAX_PROFILER_ENTRIES];
    
    uint32_t sample_index;
    uint32_t sample_count;
    uint32_t category_count;
    uint32_t profiler_entry_count;
    
    uint64_t start_time_us;
    uint64_t last_update_us;
    
    pthread_t analytics_thread;
    pthread_mutex_t analytics_mutex;
    bool running;
    
    // Performance thresholds
    double fps_warning_threshold;
    double fps_critical_threshold;
    double memory_warning_threshold;
    double memory_critical_threshold;
    double cpu_warning_threshold;
    double cpu_critical_threshold;
    
    // Statistics
    uint64_t total_samples_collected;
    uint64_t alerts_triggered;
    uint64_t performance_degradations;
    
} hmr_performance_analytics_t;

static hmr_performance_analytics_t g_analytics = {0};

// Forward declarations
static void* hmr_analytics_thread(void* arg);
static uint64_t hmr_get_current_time_us(void);
static void hmr_collect_system_metrics(hmr_performance_sample_t* sample);
static void hmr_update_categories(const hmr_performance_sample_t* sample);
static void hmr_calculate_trends(void);
static void hmr_check_alerts(void);
static double hmr_get_cpu_usage(void);
static double hmr_get_memory_usage_mb(void);
static double hmr_get_gpu_usage(void);
static void hmr_serialize_analytics_data(char* json_buffer, size_t max_len);

// Initialize performance analytics
int hmr_performance_analytics_init(void) {
    if (g_analytics.running) {
        printf("[HMR] Performance analytics already running\n");
        return HMR_SUCCESS;
    }
    
    // Initialize analytics state
    memset(&g_analytics, 0, sizeof(hmr_performance_analytics_t));
    g_analytics.start_time_us = hmr_get_current_time_us();
    
    // Set default thresholds
    g_analytics.fps_warning_threshold = 45.0;
    g_analytics.fps_critical_threshold = 30.0;
    g_analytics.memory_warning_threshold = 512.0; // MB
    g_analytics.memory_critical_threshold = 1024.0; // MB
    g_analytics.cpu_warning_threshold = 80.0; // %
    g_analytics.cpu_critical_threshold = 95.0; // %
    
    // Initialize categories
    const char* category_names[] = {
        "fps", "frame_time", "cpu_usage", "memory_usage", 
        "gpu_usage", "disk_io", "network_io", "temperature",
        "power_draw", "heap_allocations", "thread_count"
    };
    
    g_analytics.category_count = sizeof(category_names) / sizeof(category_names[0]);
    for (uint32_t i = 0; i < g_analytics.category_count; i++) {
        strncpy(g_analytics.categories[i].name, category_names[i], 
                sizeof(g_analytics.categories[i].name) - 1);
        g_analytics.categories[i].min_value = INFINITY;
        g_analytics.categories[i].max_value = -INFINITY;
    }
    
    // Initialize mutex
    if (pthread_mutex_init(&g_analytics.analytics_mutex, NULL) != 0) {
        printf("[HMR] Failed to initialize analytics mutex\n");
        return HMR_ERROR_THREADING;
    }
    
    // Start analytics thread
    g_analytics.running = true;
    if (pthread_create(&g_analytics.analytics_thread, NULL, hmr_analytics_thread, NULL) != 0) {
        printf("[HMR] Failed to create analytics thread\n");
        g_analytics.running = false;
        pthread_mutex_destroy(&g_analytics.analytics_mutex);
        return HMR_ERROR_THREADING;
    }
    
    printf("[HMR] Performance analytics initialized\n");
    return HMR_SUCCESS;
}

// Shutdown performance analytics
void hmr_performance_analytics_shutdown(void) {
    if (!g_analytics.running) {
        return;
    }
    
    printf("[HMR] Shutting down performance analytics...\n");
    
    g_analytics.running = false;
    pthread_join(g_analytics.analytics_thread, NULL);
    pthread_mutex_destroy(&g_analytics.analytics_mutex);
    
    printf("[HMR] Performance analytics shutdown complete\n");
    printf("[HMR] Analytics statistics:\n");
    printf("  Total samples collected: %llu\n", g_analytics.total_samples_collected);
    printf("  Alerts triggered: %llu\n", g_analytics.alerts_triggered);
    printf("  Performance degradations: %llu\n", g_analytics.performance_degradations);
}

// Get analytics data as JSON
void hmr_get_analytics_data(char* json_buffer, size_t max_len) {
    if (!json_buffer || max_len == 0) return;
    
    pthread_mutex_lock(&g_analytics.analytics_mutex);
    hmr_serialize_analytics_data(json_buffer, max_len);
    pthread_mutex_unlock(&g_analytics.analytics_mutex);
}

// Profile function execution
void hmr_profile_function_start(const char* function_name, const char* module_name) {
    if (!g_analytics.running) return;
    
    pthread_mutex_lock(&g_analytics.analytics_mutex);
    
    // Find or create profiler entry
    hmr_profiler_entry_t* entry = NULL;
    for (uint32_t i = 0; i < g_analytics.profiler_entry_count; i++) {
        if (strcmp(g_analytics.profiler_entries[i].function_name, function_name) == 0 &&
            strcmp(g_analytics.profiler_entries[i].module_name, module_name) == 0) {
            entry = &g_analytics.profiler_entries[i];
            break;
        }
    }
    
    if (!entry && g_analytics.profiler_entry_count < MAX_PROFILER_ENTRIES) {
        entry = &g_analytics.profiler_entries[g_analytics.profiler_entry_count++];
        strncpy(entry->function_name, function_name, sizeof(entry->function_name) - 1);
        strncpy(entry->module_name, module_name, sizeof(entry->module_name) - 1);
        entry->min_time_us = UINT64_MAX;
        entry->active = true;
    }
    
    if (entry) {
        entry->last_call_timestamp = hmr_get_current_time_us();
    }
    
    pthread_mutex_unlock(&g_analytics.analytics_mutex);
}

void hmr_profile_function_end(const char* function_name, const char* module_name) {
    if (!g_analytics.running) return;
    
    uint64_t end_time = hmr_get_current_time_us();
    
    pthread_mutex_lock(&g_analytics.analytics_mutex);
    
    // Find profiler entry
    for (uint32_t i = 0; i < g_analytics.profiler_entry_count; i++) {
        hmr_profiler_entry_t* entry = &g_analytics.profiler_entries[i];
        if (strcmp(entry->function_name, function_name) == 0 &&
            strcmp(entry->module_name, module_name) == 0) {
            
            uint64_t execution_time = end_time - entry->last_call_timestamp;
            
            entry->call_count++;
            entry->total_time_us += execution_time;
            entry->avg_time_us = (double)entry->total_time_us / entry->call_count;
            
            if (execution_time < entry->min_time_us) {
                entry->min_time_us = execution_time;
            }
            if (execution_time > entry->max_time_us) {
                entry->max_time_us = execution_time;
            }
            
            break;
        }
    }
    
    pthread_mutex_unlock(&g_analytics.analytics_mutex);
}

// Add custom performance sample
void hmr_add_custom_sample(const char* category, double value) {
    if (!g_analytics.running) return;
    
    pthread_mutex_lock(&g_analytics.analytics_mutex);
    
    // Find category
    for (uint32_t i = 0; i < g_analytics.category_count; i++) {
        if (strcmp(g_analytics.categories[i].name, category) == 0) {
            g_analytics.categories[i].current_value = value;
            g_analytics.categories[i].sample_count++;
            
            if (value < g_analytics.categories[i].min_value) {
                g_analytics.categories[i].min_value = value;
            }
            if (value > g_analytics.categories[i].max_value) {
                g_analytics.categories[i].max_value = value;
            }
            
            break;
        }
    }
    
    pthread_mutex_unlock(&g_analytics.analytics_mutex);
}

// Main analytics thread
static void* hmr_analytics_thread(void* arg) {
    (void)arg;
    
    printf("[HMR] Performance analytics thread started\n");
    
    while (g_analytics.running) {
        uint64_t current_time = hmr_get_current_time_us();
        
        // Check if it's time for an update
        if (current_time - g_analytics.last_update_us >= ANALYTICS_UPDATE_INTERVAL_MS * 1000) {
            pthread_mutex_lock(&g_analytics.analytics_mutex);
            
            // Collect new performance sample
            hmr_performance_sample_t* sample = &g_analytics.samples[g_analytics.sample_index];
            memset(sample, 0, sizeof(hmr_performance_sample_t));
            
            sample->timestamp_us = current_time;
            hmr_collect_system_metrics(sample);
            
            // Update rolling buffer
            g_analytics.sample_index = (g_analytics.sample_index + 1) % MAX_PERFORMANCE_SAMPLES;
            if (g_analytics.sample_count < MAX_PERFORMANCE_SAMPLES) {
                g_analytics.sample_count++;
            }
            
            // Update categories and trends
            hmr_update_categories(sample);
            hmr_calculate_trends();
            hmr_check_alerts();
            
            g_analytics.last_update_us = current_time;
            g_analytics.total_samples_collected++;
            
            pthread_mutex_unlock(&g_analytics.analytics_mutex);
            
            // Broadcast performance update
            char analytics_json[4096];
            hmr_get_analytics_data(analytics_json, sizeof(analytics_json));
            hmr_notify_performance_update(analytics_json);
        }
        
        usleep(10000); // Sleep 10ms
    }
    
    printf("[HMR] Performance analytics thread exiting\n");
    return NULL;
}

// Get current time in microseconds
static uint64_t hmr_get_current_time_us(void) {
    static mach_timebase_info_data_t timebase_info;
    static bool timebase_initialized = false;
    
    if (!timebase_initialized) {
        mach_timebase_info(&timebase_info);
        timebase_initialized = true;
    }
    
    uint64_t mach_time = mach_absolute_time();
    return (mach_time * timebase_info.numer) / (timebase_info.denom * 1000);
}

// Collect system metrics
static void hmr_collect_system_metrics(hmr_performance_sample_t* sample) {
    // Get basic metrics
    sample->cpu_usage_percent = hmr_get_cpu_usage();
    sample->memory_usage_mb = hmr_get_memory_usage_mb();
    sample->gpu_usage_percent = hmr_get_gpu_usage();
    
    // Simulate additional metrics (in a real implementation, these would be actual measurements)
    sample->fps = 58.0 + (rand() % 100) / 25.0; // 58-62 FPS
    sample->frame_time_ms = 1000.0 / sample->fps;
    sample->disk_io_mbps = 10.0 + (rand() % 100) / 10.0;
    sample->network_io_mbps = 1.0 + (rand() % 50) / 10.0;
    sample->thread_count = 8 + (rand() % 4);
    sample->heap_allocations = 1000 + (rand() % 500);
    sample->stack_usage_kb = 64 + (rand() % 32);
    sample->temperature_celsius = 35.0 + (rand() % 200) / 10.0; // 35-55°C
    sample->power_draw_watts = 15 + (rand() % 10);
    
    // Module-specific metrics (simulated)
    const char* module_names[] = {"platform", "memory", "graphics", "simulation", "ui", "audio", "ai", "hmr"};
    for (int i = 0; i < 8; i++) {
        sample->modules[i].load_time_ms = 1.0 + (rand() % 100) / 20.0;
        sample->modules[i].call_count = 100 + (rand() % 500);
        sample->modules[i].total_time_ms = 5.0 + (rand() % 200) / 10.0;
    }
}

// Get CPU usage percentage
static double hmr_get_cpu_usage(void) {
    host_cpu_load_info_data_t cpu_info;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, 
                       (host_info_t)&cpu_info, &count) == KERN_SUCCESS) {
        
        natural_t total_ticks = cpu_info.cpu_ticks[CPU_STATE_USER] +
                               cpu_info.cpu_ticks[CPU_STATE_SYSTEM] +
                               cpu_info.cpu_ticks[CPU_STATE_IDLE] +
                               cpu_info.cpu_ticks[CPU_STATE_NICE];
        
        natural_t idle_ticks = cpu_info.cpu_ticks[CPU_STATE_IDLE];
        
        if (total_ticks > 0) {
            return ((double)(total_ticks - idle_ticks) / total_ticks) * 100.0;
        }
    }
    
    return 0.0;
}

// Get memory usage in MB
static double hmr_get_memory_usage_mb(void) {
    vm_statistics64_data_t vm_stat;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    
    if (host_statistics64(mach_host_self(), HOST_VM_INFO64, 
                         (host_info64_t)&vm_stat, &count) == KERN_SUCCESS) {
        
        vm_size_t page_size;
        host_page_size(mach_host_self(), &page_size);
        
        uint64_t used_memory = (vm_stat.active_count + vm_stat.inactive_count + 
                               vm_stat.wire_count) * page_size;
        
        return (double)used_memory / (1024.0 * 1024.0);
    }
    
    return 0.0;
}

// Get GPU usage (simplified - would need Metal Performance Shaders in real implementation)
static double hmr_get_gpu_usage(void) {
    // Placeholder - real implementation would query GPU metrics
    return 25.0 + (rand() % 500) / 10.0; // 25-75%
}

// Update performance categories
static void hmr_update_categories(const hmr_performance_sample_t* sample) {
    double values[] = {
        sample->fps,
        sample->frame_time_ms,
        sample->cpu_usage_percent,
        sample->memory_usage_mb,
        sample->gpu_usage_percent,
        sample->disk_io_mbps,
        sample->network_io_mbps,
        sample->temperature_celsius,
        (double)sample->power_draw_watts,
        (double)sample->heap_allocations,
        (double)sample->thread_count
    };
    
    for (uint32_t i = 0; i < g_analytics.category_count && i < 11; i++) {
        hmr_performance_category_t* cat = &g_analytics.categories[i];
        
        cat->current_value = values[i];
        cat->sample_count++;
        
        if (values[i] < cat->min_value) cat->min_value = values[i];
        if (values[i] > cat->max_value) cat->max_value = values[i];
        
        // Update average (exponential moving average)
        if (cat->sample_count == 1) {
            cat->avg_value = values[i];
        } else {
            cat->avg_value = 0.9 * cat->avg_value + 0.1 * values[i];
        }
    }
}

// Calculate performance trends
static void hmr_calculate_trends(void) {
    // Simple linear regression for trend analysis
    for (uint32_t cat_idx = 0; cat_idx < g_analytics.category_count; cat_idx++) {
        if (g_analytics.sample_count < 10) continue; // Need enough data
        
        hmr_performance_category_t* cat = &g_analytics.categories[cat_idx];
        
        // Calculate slope using last 50 samples
        uint32_t samples_to_use = g_analytics.sample_count < 50 ? g_analytics.sample_count : 50;
        uint32_t start_idx = (g_analytics.sample_index + MAX_PERFORMANCE_SAMPLES - samples_to_use) % MAX_PERFORMANCE_SAMPLES;
        
        double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;
        
        for (uint32_t i = 0; i < samples_to_use; i++) {
            uint32_t idx = (start_idx + i) % MAX_PERFORMANCE_SAMPLES;
            double x = (double)i;
            double y = 0.0;
            
            // Get the value for this category from the sample
            const hmr_performance_sample_t* sample = &g_analytics.samples[idx];
            switch (cat_idx) {
                case 0: y = sample->fps; break;
                case 1: y = sample->frame_time_ms; break;
                case 2: y = sample->cpu_usage_percent; break;
                case 3: y = sample->memory_usage_mb; break;
                case 4: y = sample->gpu_usage_percent; break;
                default: y = cat->current_value; break;
            }
            
            sum_x += x;
            sum_y += y;
            sum_xy += x * y;
            sum_x2 += x * x;
        }
        
        // Calculate slope
        double n = (double)samples_to_use;
        if (n * sum_x2 - sum_x * sum_x != 0) {
            cat->trend_slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x);
        }
    }
}

// Check for performance alerts
static void hmr_check_alerts(void) {
    // Check FPS
    if (g_analytics.categories[0].current_value < g_analytics.fps_critical_threshold) {
        if (!g_analytics.categories[0].alert_triggered) {
            g_analytics.categories[0].alert_triggered = true;
            g_analytics.alerts_triggered++;
            printf("[HMR] CRITICAL: FPS dropped to %.1f\n", g_analytics.categories[0].current_value);
        }
    } else if (g_analytics.categories[0].current_value < g_analytics.fps_warning_threshold) {
        printf("[HMR] WARNING: Low FPS: %.1f\n", g_analytics.categories[0].current_value);
    } else {
        g_analytics.categories[0].alert_triggered = false;
    }
    
    // Check memory usage
    if (g_analytics.categories[3].current_value > g_analytics.memory_critical_threshold) {
        if (!g_analytics.categories[3].alert_triggered) {
            g_analytics.categories[3].alert_triggered = true;
            g_analytics.alerts_triggered++;
            printf("[HMR] CRITICAL: Memory usage at %.1f MB\n", g_analytics.categories[3].current_value);
        }
    } else if (g_analytics.categories[3].current_value > g_analytics.memory_warning_threshold) {
        printf("[HMR] WARNING: High memory usage: %.1f MB\n", g_analytics.categories[3].current_value);
    } else {
        g_analytics.categories[3].alert_triggered = false;
    }
    
    // Check CPU usage
    if (g_analytics.categories[2].current_value > g_analytics.cpu_critical_threshold) {
        if (!g_analytics.categories[2].alert_triggered) {
            g_analytics.categories[2].alert_triggered = true;
            g_analytics.alerts_triggered++;
            printf("[HMR] CRITICAL: CPU usage at %.1f%%\n", g_analytics.categories[2].current_value);
        }
    } else if (g_analytics.categories[2].current_value > g_analytics.cpu_warning_threshold) {
        printf("[HMR] WARNING: High CPU usage: %.1f%%\n", g_analytics.categories[2].current_value);
    } else {
        g_analytics.categories[2].alert_triggered = false;
    }
}

// Serialize analytics data to JSON
static void hmr_serialize_analytics_data(char* json_buffer, size_t max_len) {
    size_t pos = 0;
    
    pos += snprintf(json_buffer + pos, max_len - pos,
        "{"
        "\"timestamp\":%llu,"
        "\"uptime_seconds\":%llu,"
        "\"total_samples\":%llu,"
        "\"alerts_triggered\":%llu,"
        "\"categories\":[",
        hmr_get_current_time_us() / 1000000,
        (hmr_get_current_time_us() - g_analytics.start_time_us) / 1000000,
        g_analytics.total_samples_collected,
        g_analytics.alerts_triggered);
    
    // Serialize categories
    for (uint32_t i = 0; i < g_analytics.category_count && pos < max_len - 1000; i++) {
        hmr_performance_category_t* cat = &g_analytics.categories[i];
        
        if (i > 0) {
            pos += snprintf(json_buffer + pos, max_len - pos, ",");
        }
        
        pos += snprintf(json_buffer + pos, max_len - pos,
            "{"
            "\"name\":\"%s\","
            "\"current\":%.3f,"
            "\"min\":%.3f,"
            "\"max\":%.3f,"
            "\"avg\":%.3f,"
            "\"trend\":%.6f,"
            "\"samples\":%u,"
            "\"alert\":%s"
            "}",
            cat->name,
            cat->current_value,
            cat->min_value == INFINITY ? 0.0 : cat->min_value,
            cat->max_value == -INFINITY ? 0.0 : cat->max_value,
            cat->avg_value,
            cat->trend_slope,
            cat->sample_count,
            cat->alert_triggered ? "true" : "false");
    }
    
    pos += snprintf(json_buffer + pos, max_len - pos,
        "],"
        "\"profiler\":[");
    
    // Serialize top 10 profiler entries
    uint32_t profiler_entries_to_show = g_analytics.profiler_entry_count < 10 ? 
                                       g_analytics.profiler_entry_count : 10;
    
    for (uint32_t i = 0; i < profiler_entries_to_show && pos < max_len - 500; i++) {
        hmr_profiler_entry_t* entry = &g_analytics.profiler_entries[i];
        
        if (i > 0) {
            pos += snprintf(json_buffer + pos, max_len - pos, ",");
        }
        
        pos += snprintf(json_buffer + pos, max_len - pos,
            "{"
            "\"function\":\"%s\","
            "\"module\":\"%s\","
            "\"calls\":%llu,"
            "\"total_time_us\":%llu,"
            "\"avg_time_us\":%.3f,"
            "\"min_time_us\":%llu,"
            "\"max_time_us\":%llu"
            "}",
            entry->function_name,
            entry->module_name,
            entry->call_count,
            entry->total_time_us,
            entry->avg_time_us,
            entry->min_time_us == UINT64_MAX ? 0 : entry->min_time_us,
            entry->max_time_us);
    }
    
    snprintf(json_buffer + pos, max_len - pos, "]}");
}