/*
 * SimCity ARM64 - HMR Performance Metrics Collection
 * Real-time monitoring of module load times, memory usage, and performance
 * 
 * Agent 4: Developer Tools & Debug Interface
 * Day 2: Real-Time Monitoring Implementation
 */

#include "metrics.h"
#include "module_interface.h"
#include "dev_server.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/time.h>
#include <mach/mach.h>
#include <mach/mach_time.h>

// High-resolution timer functions for ARM64 macOS
static mach_timebase_info_data_t g_timebase_info = {0};

// Initialize high-resolution timing
static void hmr_init_timing(void) {
    if (g_timebase_info.denom == 0) {
        mach_timebase_info(&g_timebase_info);
    }
}

// Get current time in nanoseconds
static uint64_t hmr_get_time_ns(void) {
    hmr_init_timing();
    uint64_t mach_time = mach_absolute_time();
    return (mach_time * g_timebase_info.numer) / g_timebase_info.denom;
}

// Global metrics collection state
typedef struct {
    bool initialized;
    bool collecting;
    pthread_mutex_t mutex;
    pthread_t collector_thread;
    
    // Module metrics tracking
    hmr_module_metrics_entry_t modules[HMR_MAX_MODULES];
    uint32_t module_count;
    
    // System-wide metrics
    hmr_system_metrics_t system_metrics;
    
    // Performance history (circular buffer)
    hmr_performance_sample_t performance_history[HMR_PERFORMANCE_HISTORY_SIZE];
    uint32_t history_index;
    uint32_t history_count;
    
    // FPS tracking
    uint64_t last_frame_time;
    uint32_t frame_count;
    float current_fps;
    uint64_t fps_update_time;
    
    // Memory tracking
    uint64_t last_memory_check;
    uint64_t total_allocations;
    uint64_t total_deallocations;
    
    // Build metrics
    hmr_build_metrics_t build_metrics;
    
} hmr_metrics_state_t;

static hmr_metrics_state_t g_metrics = {0};

// Forward declarations
static void* hmr_metrics_collector_thread(void* arg);
static void hmr_collect_system_metrics(void);
static void hmr_collect_memory_metrics(void);
static void hmr_update_performance_history(void);
static void hmr_broadcast_metrics_update(void);

// Initialize metrics collection system
int hmr_metrics_init(void) {
    if (g_metrics.initialized) {
        return HMR_SUCCESS;
    }
    
    // Initialize mutex
    if (pthread_mutex_init(&g_metrics.mutex, NULL) != 0) {
        printf("[HMR Metrics] Failed to initialize mutex\n");
        return HMR_ERROR_THREADING;
    }
    
    // Initialize timing system
    hmr_init_timing();
    
    // Reset all metrics
    memset(&g_metrics, 0, sizeof(hmr_metrics_state_t));
    
    // Initialize module metrics array
    for (int i = 0; i < HMR_MAX_MODULES; i++) {
        g_metrics.modules[i].active = false;
        g_metrics.modules[i].module_name[0] = '\0';
    }
    
    // Set initial values
    g_metrics.initialized = true;
    g_metrics.collecting = false;
    g_metrics.last_frame_time = hmr_get_time_ns();
    g_metrics.fps_update_time = g_metrics.last_frame_time;
    g_metrics.last_memory_check = g_metrics.last_frame_time;
    
    printf("[HMR Metrics] Metrics collection system initialized\n");
    return HMR_SUCCESS;
}

// Start metrics collection
int hmr_metrics_start(void) {
    if (!g_metrics.initialized) {
        return HMR_ERROR_NOT_FOUND;
    }
    
    if (g_metrics.collecting) {
        return HMR_SUCCESS; // Already collecting
    }
    
    g_metrics.collecting = true;
    
    // Start collector thread
    if (pthread_create(&g_metrics.collector_thread, NULL, hmr_metrics_collector_thread, NULL) != 0) {
        printf("[HMR Metrics] Failed to create collector thread\n");
        g_metrics.collecting = false;
        return HMR_ERROR_THREADING;
    }
    
    printf("[HMR Metrics] Started metrics collection\n");
    return HMR_SUCCESS;
}

// Stop metrics collection
void hmr_metrics_stop(void) {
    if (!g_metrics.collecting) {
        return;
    }
    
    g_metrics.collecting = false;
    
    // Wait for collector thread to finish
    pthread_join(g_metrics.collector_thread, NULL);
    
    printf("[HMR Metrics] Stopped metrics collection\n");
}

// Shutdown metrics system
void hmr_metrics_shutdown(void) {
    if (!g_metrics.initialized) {
        return;
    }
    
    hmr_metrics_stop();
    
    // Clean up mutex
    pthread_mutex_destroy(&g_metrics.mutex);
    
    // Reset state
    memset(&g_metrics, 0, sizeof(hmr_metrics_state_t));
    
    printf("[HMR Metrics] Metrics system shutdown complete\n");
}

// Register module for metrics tracking
int hmr_metrics_register_module(const char* module_name) {
    if (!g_metrics.initialized || !module_name) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    pthread_mutex_lock(&g_metrics.mutex);
    
    // Check if module already registered
    for (uint32_t i = 0; i < g_metrics.module_count; i++) {
        if (strcmp(g_metrics.modules[i].module_name, module_name) == 0) {
            pthread_mutex_unlock(&g_metrics.mutex);
            return HMR_SUCCESS; // Already registered
        }
    }
    
    // Find empty slot
    int slot = -1;
    for (int i = 0; i < HMR_MAX_MODULES; i++) {
        if (!g_metrics.modules[i].active) {
            slot = i;
            break;
        }
    }
    
    if (slot == -1) {
        pthread_mutex_unlock(&g_metrics.mutex);
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    // Initialize module entry
    hmr_module_metrics_entry_t* entry = &g_metrics.modules[slot];
    memset(entry, 0, sizeof(hmr_module_metrics_entry_t));
    strncpy(entry->module_name, module_name, sizeof(entry->module_name) - 1);
    entry->active = true;
    entry->registration_time = hmr_get_time_ns();
    
    g_metrics.module_count++;
    
    pthread_mutex_unlock(&g_metrics.mutex);
    
    printf("[HMR Metrics] Registered module: %s (slot %d)\n", module_name, slot);
    return HMR_SUCCESS;
}

// Unregister module from metrics tracking
void hmr_metrics_unregister_module(const char* module_name) {
    if (!g_metrics.initialized || !module_name) {
        return;
    }
    
    pthread_mutex_lock(&g_metrics.mutex);
    
    for (uint32_t i = 0; i < HMR_MAX_MODULES; i++) {
        if (g_metrics.modules[i].active && strcmp(g_metrics.modules[i].module_name, module_name) == 0) {
            g_metrics.modules[i].active = false;
            g_metrics.module_count--;
            printf("[HMR Metrics] Unregistered module: %s\n", module_name);
            break;
        }
    }
    
    pthread_mutex_unlock(&g_metrics.mutex);
}

// Record module load time
void hmr_metrics_record_load_time(const char* module_name, uint64_t load_time_ns) {
    if (!g_metrics.initialized || !module_name) {
        return;
    }
    
    pthread_mutex_lock(&g_metrics.mutex);
    
    for (uint32_t i = 0; i < HMR_MAX_MODULES; i++) {
        if (g_metrics.modules[i].active && strcmp(g_metrics.modules[i].module_name, module_name) == 0) {
            hmr_module_metrics_entry_t* entry = &g_metrics.modules[i];
            entry->metrics.init_time_ns = load_time_ns;
            entry->last_load_time = hmr_get_time_ns();
            entry->load_count++;
            
            // Update averages
            if (entry->load_count > 1) {
                entry->metrics.avg_load_time_ns = 
                    (entry->metrics.avg_load_time_ns * (entry->load_count - 1) + load_time_ns) / entry->load_count;
            } else {
                entry->metrics.avg_load_time_ns = load_time_ns;
            }
            
            if (load_time_ns > entry->metrics.peak_load_time_ns) {
                entry->metrics.peak_load_time_ns = load_time_ns;
            }
            
            break;
        }
    }
    
    pthread_mutex_unlock(&g_metrics.mutex);
    
    printf("[HMR Metrics] Module %s load time: %.2f ms\n", module_name, load_time_ns / 1000000.0);
}

// Record frame time
void hmr_metrics_record_frame_time(uint64_t frame_time_ns) {
    if (!g_metrics.initialized) {
        return;
    }
    
    uint64_t current_time = hmr_get_time_ns();
    
    pthread_mutex_lock(&g_metrics.mutex);
    
    g_metrics.frame_count++;
    
    // Update system frame metrics
    g_metrics.system_metrics.total_frames++;
    if (frame_time_ns > g_metrics.system_metrics.peak_frame_time_ns) {
        g_metrics.system_metrics.peak_frame_time_ns = frame_time_ns;
    }
    
    // Calculate rolling average
    if (g_metrics.system_metrics.total_frames > 1) {
        g_metrics.system_metrics.avg_frame_time_ns = 
            (g_metrics.system_metrics.avg_frame_time_ns * (g_metrics.system_metrics.total_frames - 1) + frame_time_ns) 
            / g_metrics.system_metrics.total_frames;
    } else {
        g_metrics.system_metrics.avg_frame_time_ns = frame_time_ns;
    }
    
    // Update FPS calculation every second
    if (current_time - g_metrics.fps_update_time >= 1000000000ULL) { // 1 second in nanoseconds
        uint64_t elapsed_ns = current_time - g_metrics.fps_update_time;
        g_metrics.current_fps = (float)g_metrics.frame_count * 1000000000.0f / elapsed_ns;
        g_metrics.system_metrics.current_fps = g_metrics.current_fps;
        
        g_metrics.frame_count = 0;
        g_metrics.fps_update_time = current_time;
    }
    
    g_metrics.last_frame_time = current_time;
    
    pthread_mutex_unlock(&g_metrics.mutex);
}

// Record memory usage for a module
void hmr_metrics_record_memory_usage(const char* module_name, uint64_t memory_bytes) {
    if (!g_metrics.initialized || !module_name) {
        return;
    }
    
    pthread_mutex_lock(&g_metrics.mutex);
    
    for (uint32_t i = 0; i < HMR_MAX_MODULES; i++) {
        if (g_metrics.modules[i].active && strcmp(g_metrics.modules[i].module_name, module_name) == 0) {
            hmr_module_metrics_entry_t* entry = &g_metrics.modules[i];
            entry->metrics.memory_usage_bytes = memory_bytes;
            
            if (memory_bytes > entry->metrics.peak_memory_bytes) {
                entry->metrics.peak_memory_bytes = memory_bytes;
            }
            
            break;
        }
    }
    
    pthread_mutex_unlock(&g_metrics.mutex);
}

// Get system metrics
void hmr_metrics_get_system_metrics(hmr_system_metrics_t* metrics) {
    if (!g_metrics.initialized || !metrics) {
        return;
    }
    
    pthread_mutex_lock(&g_metrics.mutex);
    *metrics = g_metrics.system_metrics;
    pthread_mutex_unlock(&g_metrics.mutex);
}

// Get module metrics
int hmr_metrics_get_module_metrics(const char* module_name, hmr_module_metrics_t* metrics) {
    if (!g_metrics.initialized || !module_name || !metrics) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    pthread_mutex_lock(&g_metrics.mutex);
    
    for (uint32_t i = 0; i < HMR_MAX_MODULES; i++) {
        if (g_metrics.modules[i].active && strcmp(g_metrics.modules[i].module_name, module_name) == 0) {
            *metrics = g_metrics.modules[i].metrics;
            pthread_mutex_unlock(&g_metrics.mutex);
            return HMR_SUCCESS;
        }
    }
    
    pthread_mutex_unlock(&g_metrics.mutex);
    return HMR_ERROR_NOT_FOUND;
}

// Generate JSON metrics report
void hmr_metrics_generate_json(char* json_buffer, size_t buffer_size) {
    if (!g_metrics.initialized || !json_buffer || buffer_size == 0) {
        return;
    }
    
    pthread_mutex_lock(&g_metrics.mutex);
    
    char* ptr = json_buffer;
    size_t remaining = buffer_size - 1; // Leave space for null terminator
    int written = 0;
    
    // Start JSON object
    written = snprintf(ptr, remaining, "{"
        "\"timestamp\":%llu,"
        "\"system\":{"
            "\"fps\":%.2f,"
            "\"avg_frame_time_ms\":%.3f,"
            "\"peak_frame_time_ms\":%.3f,"
            "\"total_frames\":%llu,"
            "\"memory_usage_mb\":%.2f,"
            "\"memory_peak_mb\":%.2f"
        "},",
        hmr_get_time_ns(),
        g_metrics.system_metrics.current_fps,
        g_metrics.system_metrics.avg_frame_time_ns / 1000000.0,
        g_metrics.system_metrics.peak_frame_time_ns / 1000000.0,
        g_metrics.system_metrics.total_frames,
        g_metrics.system_metrics.memory_usage_bytes / (1024.0 * 1024.0),
        g_metrics.system_metrics.peak_memory_bytes / (1024.0 * 1024.0));
    
    if (written > 0 && written < (int)remaining) {
        ptr += written;
        remaining -= written;
    }
    
    // Add modules array
    written = snprintf(ptr, remaining, "\"modules\":[");
    if (written > 0 && written < (int)remaining) {
        ptr += written;
        remaining -= written;
    }
    
    bool first_module = true;
    for (uint32_t i = 0; i < HMR_MAX_MODULES && remaining > 100; i++) {
        if (!g_metrics.modules[i].active) continue;
        
        hmr_module_metrics_entry_t* entry = &g_metrics.modules[i];
        
        written = snprintf(ptr, remaining, "%s{"
            "\"name\":\"%s\","
            "\"load_time_ms\":%.3f,"
            "\"avg_load_time_ms\":%.3f,"
            "\"peak_load_time_ms\":%.3f,"
            "\"memory_mb\":%.2f,"
            "\"peak_memory_mb\":%.2f,"
            "\"load_count\":%u"
            "}",
            first_module ? "" : ",",
            entry->module_name,
            entry->metrics.init_time_ns / 1000000.0,
            entry->metrics.avg_load_time_ns / 1000000.0,
            entry->metrics.peak_load_time_ns / 1000000.0,
            entry->metrics.memory_usage_bytes / (1024.0 * 1024.0),
            entry->metrics.peak_memory_bytes / (1024.0 * 1024.0),
            entry->load_count);
        
        if (written > 0 && written < (int)remaining) {
            ptr += written;
            remaining -= written;
            first_module = false;
        }
    }
    
    // Close JSON
    written = snprintf(ptr, remaining, "]}");
    if (written > 0 && written < (int)remaining) {
        ptr += written;
        remaining -= written;
    }
    
    pthread_mutex_unlock(&g_metrics.mutex);
    
    // Ensure null termination
    json_buffer[buffer_size - 1] = '\0';
}

// Metrics collector thread
static void* hmr_metrics_collector_thread(void* arg) {
    (void)arg;
    
    printf("[HMR Metrics] Collector thread started\n");
    
    while (g_metrics.collecting) {
        // Collect system metrics every 100ms
        hmr_collect_system_metrics();
        
        // Collect memory metrics every 500ms
        uint64_t current_time = hmr_get_time_ns();
        if (current_time - g_metrics.last_memory_check >= 500000000ULL) {
            hmr_collect_memory_metrics();
            g_metrics.last_memory_check = current_time;
        }
        
        // Update performance history
        hmr_update_performance_history();
        
        // Broadcast metrics update to connected clients
        hmr_broadcast_metrics_update();
        
        // Sleep for 100ms
        usleep(100000);
    }
    
    printf("[HMR Metrics] Collector thread exiting\n");
    return NULL;
}

// Collect system-wide metrics
static void hmr_collect_system_metrics(void) {
    // Get task info for memory usage
    task_t task = mach_task_self();
    struct task_basic_info_64 info;
    mach_msg_type_number_t count = TASK_BASIC_INFO_64_COUNT;
    
    if (task_info(task, TASK_BASIC_INFO_64, (task_info_t)&info, &count) == KERN_SUCCESS) {
        pthread_mutex_lock(&g_metrics.mutex);
        
        g_metrics.system_metrics.memory_usage_bytes = info.resident_size;
        if (info.resident_size > g_metrics.system_metrics.peak_memory_bytes) {
            g_metrics.system_metrics.peak_memory_bytes = info.resident_size;
        }
        
        pthread_mutex_unlock(&g_metrics.mutex);
    }
}

// Collect memory-specific metrics
static void hmr_collect_memory_metrics(void) {
    // This could be expanded to collect more detailed memory metrics
    // For now, system metrics collection handles basic memory info
}

// Update performance history
static void hmr_update_performance_history(void) {
    pthread_mutex_lock(&g_metrics.mutex);
    
    hmr_performance_sample_t* sample = &g_metrics.performance_history[g_metrics.history_index];
    sample->timestamp = hmr_get_time_ns();
    sample->fps = g_metrics.current_fps;
    sample->frame_time_ns = g_metrics.system_metrics.avg_frame_time_ns;
    sample->memory_usage_bytes = g_metrics.system_metrics.memory_usage_bytes;
    
    g_metrics.history_index = (g_metrics.history_index + 1) % HMR_PERFORMANCE_HISTORY_SIZE;
    if (g_metrics.history_count < HMR_PERFORMANCE_HISTORY_SIZE) {
        g_metrics.history_count++;
    }
    
    pthread_mutex_unlock(&g_metrics.mutex);
}

// Broadcast metrics update to development server
static void hmr_broadcast_metrics_update(void) {
    char json_buffer[4096];
    hmr_metrics_generate_json(json_buffer, sizeof(json_buffer));
    hmr_notify_performance_update(json_buffer);
}

// Record build start
void hmr_metrics_build_start(const char* module_name) {
    if (!g_metrics.initialized) {
        return;
    }
    
    pthread_mutex_lock(&g_metrics.mutex);
    
    g_metrics.build_metrics.build_start_time = hmr_get_time_ns();
    g_metrics.build_metrics.builds_started++;
    
    if (module_name) {
        strncpy(g_metrics.build_metrics.current_module, module_name, sizeof(g_metrics.build_metrics.current_module) - 1);
    }
    
    pthread_mutex_unlock(&g_metrics.mutex);
    
    hmr_notify_build_start(module_name);
}

// Record build completion
void hmr_metrics_build_complete(const char* module_name, bool success) {
    if (!g_metrics.initialized) {
        return;
    }
    
    uint64_t current_time = hmr_get_time_ns();
    uint64_t build_time = 0;
    
    pthread_mutex_lock(&g_metrics.mutex);
    
    if (g_metrics.build_metrics.build_start_time > 0) {
        build_time = current_time - g_metrics.build_metrics.build_start_time;
        
        if (success) {
            g_metrics.build_metrics.builds_succeeded++;
            g_metrics.build_metrics.total_build_time_ns += build_time;
            
            if (build_time > g_metrics.build_metrics.longest_build_time_ns) {
                g_metrics.build_metrics.longest_build_time_ns = build_time;
            }
            
            if (g_metrics.build_metrics.shortest_build_time_ns == 0 || build_time < g_metrics.build_metrics.shortest_build_time_ns) {
                g_metrics.build_metrics.shortest_build_time_ns = build_time;
            }
        } else {
            g_metrics.build_metrics.builds_failed++;
        }
        
        g_metrics.build_metrics.build_start_time = 0;
    }
    
    pthread_mutex_unlock(&g_metrics.mutex);
    
    if (success) {
        hmr_notify_build_success(module_name, build_time / 1000000); // Convert to milliseconds
    } else {
        hmr_notify_build_error(module_name, "Build failed");
    }
}

// Get build metrics
void hmr_metrics_get_build_metrics(hmr_build_metrics_t* metrics) {
    if (!g_metrics.initialized || !metrics) {
        return;
    }
    
    pthread_mutex_lock(&g_metrics.mutex);
    *metrics = g_metrics.build_metrics;
    pthread_mutex_unlock(&g_metrics.mutex);
}