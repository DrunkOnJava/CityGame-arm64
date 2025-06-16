/*
 * SimCity ARM64 - Comprehensive Shader Debugging Integration Implementation
 * Advanced Shader Debugging and Visualization for Agent 4's UI Dashboard
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Week 2 - Day 6: Advanced Shader Features
 * 
 * Performance Targets:
 * - Debug message logging: <0.1ms
 * - Performance metrics capture: <0.5ms
 * - Parameter updates: <1ms
 * - Timeline event recording: <0.2ms
 */

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include <mach/mach_time.h>
#include <sys/time.h>
#include <pthread.h>

#include "shader_debug_integration.h"
#include "module_interface.h"

// Maximum counts for various collections
#define MAX_DEBUG_MESSAGES 1000
#define MAX_TIMELINE_EVENTS 2000
#define MAX_DEPENDENCY_NODES 256
#define MAX_SHADER_PARAMETERS 128
#define MAX_PERFORMANCE_HISTORY 100

// Debug manager state
typedef struct {
    hmr_debug_config_t config;
    
    // Message logging
    hmr_shader_debug_message_t debug_messages[MAX_DEBUG_MESSAGES];
    uint32_t message_count;
    uint32_t message_write_index;
    
    // Performance tracking
    hmr_shader_performance_metrics_t performance_history[MAX_PERFORMANCE_HISTORY];
    uint32_t performance_count;
    uint32_t performance_write_index;
    
    // GPU timeline
    hmr_gpu_timeline_event_t timeline_events[MAX_TIMELINE_EVENTS];
    uint32_t timeline_count;
    uint32_t timeline_write_index;
    
    // Dependency graph
    hmr_shader_dependency_node_t dependency_nodes[MAX_DEPENDENCY_NODES];
    uint32_t dependency_count;
    
    // Shader parameters
    struct {
        char shader_name[64];
        hmr_shader_parameter_t parameters[32];
        uint32_t parameter_count;
    } shader_parameters[16];
    uint32_t shader_parameter_group_count;
    
    // Statistics
    hmr_debug_statistics_t statistics;
    
    // GPU capture state
    NSMutableDictionary* active_captures;  // Command buffer -> capture info
    
    // Synchronization
    pthread_rwlock_t data_lock;
    dispatch_queue_t debug_queue;
    
    // UI callbacks
    void (*on_message_logged)(const hmr_shader_debug_message_t* message);
    void (*on_performance_updated)(const hmr_shader_performance_metrics_t* metrics);
    void (*on_parameter_changed)(const char* shader_name, const char* parameter_name);
    void (*on_dependency_updated)(const char* node_id, bool is_compiled, bool has_errors);
} hmr_debug_manager_t;

// Global debug manager instance
static hmr_debug_manager_t* g_debug_manager = NULL;

// Utility functions
static uint64_t hmr_get_current_time_ns(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (uint64_t)tv.tv_sec * 1000000000ULL + (uint64_t)tv.tv_usec * 1000ULL;
}

static uint64_t hmr_mach_time_to_ns(uint64_t mach_time) {
    static mach_timebase_info_data_t timebase_info;
    if (timebase_info.denom == 0) {
        mach_timebase_info(&timebase_info);
    }
    return mach_time * timebase_info.numer / timebase_info.denom;
}

// Find shader parameter group
static int32_t hmr_find_shader_parameter_group(const char* shader_name) {
    for (uint32_t i = 0; i < g_debug_manager->shader_parameter_group_count; i++) {
        if (strcmp(g_debug_manager->shader_parameters[i].shader_name, shader_name) == 0) {
            return (int32_t)i;
        }
    }
    return -1;
}

// Create new shader parameter group
static int32_t hmr_create_shader_parameter_group(const char* shader_name) {
    if (g_debug_manager->shader_parameter_group_count >= 16) {
        return -1; // No space for new group
    }
    
    int32_t index = (int32_t)g_debug_manager->shader_parameter_group_count++;
    strncpy(g_debug_manager->shader_parameters[index].shader_name, shader_name, 
           sizeof(g_debug_manager->shader_parameters[index].shader_name) - 1);
    g_debug_manager->shader_parameters[index].parameter_count = 0;
    
    return index;
}

// Add debug message (thread-safe)
static void hmr_add_debug_message_internal(const hmr_shader_debug_message_t* message) {
    pthread_rwlock_wrlock(&g_debug_manager->data_lock);
    
    // Add message to circular buffer
    uint32_t index = g_debug_manager->message_write_index;
    memcpy(&g_debug_manager->debug_messages[index], message, sizeof(hmr_shader_debug_message_t));
    
    g_debug_manager->message_write_index = (g_debug_manager->message_write_index + 1) % MAX_DEBUG_MESSAGES;
    if (g_debug_manager->message_count < MAX_DEBUG_MESSAGES) {
        g_debug_manager->message_count++;
    }
    
    // Update statistics
    g_debug_manager->statistics.debug_message_count++;
    switch (message->severity) {
        case HMR_DEBUG_SEVERITY_WARNING:
            g_debug_manager->statistics.warning_count++;
            break;
        case HMR_DEBUG_SEVERITY_ERROR:
        case HMR_DEBUG_SEVERITY_CRITICAL:
            g_debug_manager->statistics.error_count++;
            break;
        default:
            break;
    }
    
    pthread_rwlock_unlock(&g_debug_manager->data_lock);
    
    // Call UI callback
    if (g_debug_manager->on_message_logged) {
        g_debug_manager->on_message_logged(message);
    }
}

// Public API implementation

int32_t hmr_debug_init(const hmr_debug_config_t* config) {
    if (g_debug_manager) {
        return HMR_ERROR_ALREADY_EXISTS;
    }
    
    if (!config) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    g_debug_manager = calloc(1, sizeof(hmr_debug_manager_t));
    if (!g_debug_manager) {
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    // Copy configuration
    memcpy(&g_debug_manager->config, config, sizeof(hmr_debug_config_t));
    
    // Initialize synchronization
    if (pthread_rwlock_init(&g_debug_manager->data_lock, NULL) != 0) {
        free(g_debug_manager);
        g_debug_manager = NULL;
        return HMR_ERROR_SYSTEM_ERROR;
    }
    
    // Create debug queue
    g_debug_manager->debug_queue = dispatch_queue_create("com.simcity.hmr.shader_debug", 
                                                        DISPATCH_QUEUE_SERIAL);
    
    // Initialize capture tracking
    g_debug_manager->active_captures = [[NSMutableDictionary alloc] init];
    
    NSLog(@"HMR Shader Debug: Initialized successfully");
    NSLog(@"  Performance tracking: %s", config->enable_performance_tracking ? "Yes" : "No");
    NSLog(@"  Memory tracking: %s", config->enable_memory_tracking ? "Yes" : "No");
    NSLog(@"  GPU timeline: %s", config->enable_gpu_timeline ? "Yes" : "No");
    NSLog(@"  Parameter tweaking: %s", config->enable_parameter_tweaking ? "Yes" : "No");
    
    return HMR_SUCCESS;
}

void hmr_debug_log_message(hmr_debug_severity_t severity, hmr_debug_type_t type,
                          const char* shader_name, const char* message) {
    if (!g_debug_manager || !message) return;
    
    hmr_shader_debug_message_t debug_msg;
    memset(&debug_msg, 0, sizeof(debug_msg));
    
    debug_msg.timestamp = hmr_get_current_time_ns();
    debug_msg.severity = severity;
    debug_msg.type = type;
    
    if (shader_name) {
        strncpy(debug_msg.shader_name, shader_name, sizeof(debug_msg.shader_name) - 1);
    }
    
    strncpy(debug_msg.message, message, sizeof(debug_msg.message) - 1);
    
    hmr_add_debug_message_internal(&debug_msg);
}

void hmr_debug_log_compilation_error(const char* shader_name, const char* file_path,
                                    uint32_t line, uint32_t column, const char* error,
                                    const char* suggested_fix) {
    if (!g_debug_manager) return;
    
    hmr_shader_debug_message_t debug_msg;
    memset(&debug_msg, 0, sizeof(debug_msg));
    
    debug_msg.timestamp = hmr_get_current_time_ns();
    debug_msg.severity = HMR_DEBUG_SEVERITY_ERROR;
    debug_msg.type = HMR_DEBUG_TYPE_COMPILATION;
    debug_msg.line_number = line;
    debug_msg.column_number = column;
    
    if (shader_name) {
        strncpy(debug_msg.shader_name, shader_name, sizeof(debug_msg.shader_name) - 1);
    }
    
    if (file_path) {
        strncpy(debug_msg.file_path, file_path, sizeof(debug_msg.file_path) - 1);
    }
    
    snprintf(debug_msg.message, sizeof(debug_msg.message), "Compilation error at line %u: %s", 
             line, error ? error : "Unknown error");
    
    if (error) {
        strncpy(debug_msg.context.compilation.compiler_error, error,
               sizeof(debug_msg.context.compilation.compiler_error) - 1);
    }
    
    if (suggested_fix) {
        strncpy(debug_msg.context.compilation.suggested_fix, suggested_fix,
               sizeof(debug_msg.context.compilation.suggested_fix) - 1);
    }
    
    hmr_add_debug_message_internal(&debug_msg);
}

void hmr_debug_log_performance_warning(const char* shader_name, const char* bottleneck_type,
                                      float threshold, float actual_value) {
    if (!g_debug_manager) return;
    
    hmr_shader_debug_message_t debug_msg;
    memset(&debug_msg, 0, sizeof(debug_msg));
    
    debug_msg.timestamp = hmr_get_current_time_ns();
    debug_msg.severity = HMR_DEBUG_SEVERITY_WARNING;
    debug_msg.type = HMR_DEBUG_TYPE_PERFORMANCE;
    
    if (shader_name) {
        strncpy(debug_msg.shader_name, shader_name, sizeof(debug_msg.shader_name) - 1);
    }
    
    snprintf(debug_msg.message, sizeof(debug_msg.message), 
             "Performance warning - %s: %.2f (threshold: %.2f)", 
             bottleneck_type ? bottleneck_type : "Unknown", actual_value, threshold);
    
    debug_msg.context.performance.threshold_value = threshold;
    debug_msg.context.performance.actual_value = actual_value;
    
    if (bottleneck_type) {
        strncpy(debug_msg.context.performance.bottleneck_type, bottleneck_type,
               sizeof(debug_msg.context.performance.bottleneck_type) - 1);
    }
    
    hmr_add_debug_message_internal(&debug_msg);
}

int32_t hmr_debug_start_gpu_capture(id<MTLCommandBuffer> command_buffer, const char* shader_name) {
    if (!g_debug_manager || !command_buffer || !g_debug_manager->config.enable_gpu_timeline) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    // Create capture info
    NSMutableDictionary* captureInfo = [NSMutableDictionary dictionary];
    captureInfo[@"shader_name"] = shader_name ? [NSString stringWithUTF8String:shader_name] : @"unknown";
    captureInfo[@"start_time"] = @(hmr_mach_time_to_ns(mach_absolute_time()));
    
    // Store capture info
    NSString* bufferKey = [NSString stringWithFormat:@"%p", command_buffer];
    g_debug_manager->active_captures[bufferKey] = captureInfo;
    
    return HMR_SUCCESS;
}

int32_t hmr_debug_end_gpu_capture(id<MTLCommandBuffer> command_buffer) {
    if (!g_debug_manager || !command_buffer) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    NSString* bufferKey = [NSString stringWithFormat:@"%p", command_buffer];
    NSMutableDictionary* captureInfo = g_debug_manager->active_captures[bufferKey];
    
    if (!captureInfo) {
        return HMR_ERROR_NOT_FOUND;
    }
    
    uint64_t end_time = hmr_mach_time_to_ns(mach_absolute_time());
    uint64_t start_time = [captureInfo[@"start_time"] unsignedLongLongValue];
    
    // Create timeline event
    hmr_gpu_timeline_event_t event;
    memset(&event, 0, sizeof(event));
    
    event.start_time_ns = start_time;
    event.end_time_ns = end_time;
    event.event_type = HMR_TIMELINE_VERTEX; // Default type
    event.thread_id = 0; // Main GPU queue
    event.color = 0xFF4CAF50; // Green color
    
    NSString* shaderName = captureInfo[@"shader_name"];
    strncpy(event.shader_name, [shaderName UTF8String], sizeof(event.shader_name) - 1);
    snprintf(event.event_name, sizeof(event.event_name), "GPU_%s", [shaderName UTF8String]);
    
    // Add to timeline
    hmr_debug_add_timeline_event(&event);
    
    // Remove from active captures
    [g_debug_manager->active_captures removeObjectForKey:bufferKey];
    
    return HMR_SUCCESS;
}

void hmr_debug_record_performance_metrics(const hmr_shader_performance_metrics_t* metrics) {
    if (!g_debug_manager || !metrics || !g_debug_manager->config.enable_performance_tracking) {
        return;
    }
    
    pthread_rwlock_wrlock(&g_debug_manager->data_lock);
    
    // Add to performance history
    uint32_t index = g_debug_manager->performance_write_index;
    memcpy(&g_debug_manager->performance_history[index], metrics, sizeof(hmr_shader_performance_metrics_t));
    
    g_debug_manager->performance_write_index = (g_debug_manager->performance_write_index + 1) % MAX_PERFORMANCE_HISTORY;
    if (g_debug_manager->performance_count < MAX_PERFORMANCE_HISTORY) {
        g_debug_manager->performance_count++;
    }
    
    // Update statistics
    g_debug_manager->statistics.total_gpu_time_ns += metrics->gpu_duration_ns;
    g_debug_manager->statistics.avg_gpu_utilization = 
        (g_debug_manager->statistics.avg_gpu_utilization + metrics->gpu_utilization) / 2.0f;
    
    pthread_rwlock_unlock(&g_debug_manager->data_lock);
    
    // Check for performance warnings
    if (metrics->gpu_duration_ns > g_debug_manager->config.gpu_time_warning_ns) {
        hmr_debug_log_performance_warning(metrics->shader_name, "GPU time",
                                         g_debug_manager->config.gpu_time_warning_ns / 1000000.0f,
                                         metrics->gpu_duration_ns / 1000000.0f);
    }
    
    // Call UI callback
    if (g_debug_manager->on_performance_updated) {
        g_debug_manager->on_performance_updated(metrics);
    }
}

void hmr_debug_add_timeline_event(const hmr_gpu_timeline_event_t* event) {
    if (!g_debug_manager || !event || !g_debug_manager->config.enable_gpu_timeline) {
        return;
    }
    
    pthread_rwlock_wrlock(&g_debug_manager->data_lock);
    
    // Add to timeline events
    uint32_t index = g_debug_manager->timeline_write_index;
    memcpy(&g_debug_manager->timeline_events[index], event, sizeof(hmr_gpu_timeline_event_t));
    
    g_debug_manager->timeline_write_index = (g_debug_manager->timeline_write_index + 1) % MAX_TIMELINE_EVENTS;
    if (g_debug_manager->timeline_count < MAX_TIMELINE_EVENTS) {
        g_debug_manager->timeline_count++;
    }
    
    pthread_rwlock_unlock(&g_debug_manager->data_lock);
}

int32_t hmr_debug_register_parameter(const char* shader_name, const hmr_shader_parameter_t* parameter) {
    if (!g_debug_manager || !shader_name || !parameter || 
        !g_debug_manager->config.enable_parameter_tweaking) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    pthread_rwlock_wrlock(&g_debug_manager->data_lock);
    
    // Find or create shader parameter group
    int32_t group_index = hmr_find_shader_parameter_group(shader_name);
    if (group_index < 0) {
        group_index = hmr_create_shader_parameter_group(shader_name);
        if (group_index < 0) {
            pthread_rwlock_unlock(&g_debug_manager->data_lock);
            return HMR_ERROR_OUT_OF_MEMORY;
        }
    }
    
    // Add parameter to group
    if (g_debug_manager->shader_parameters[group_index].parameter_count >= 32) {
        pthread_rwlock_unlock(&g_debug_manager->data_lock);
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    uint32_t param_index = g_debug_manager->shader_parameters[group_index].parameter_count++;
    memcpy(&g_debug_manager->shader_parameters[group_index].parameters[param_index], 
           parameter, sizeof(hmr_shader_parameter_t));
    
    g_debug_manager->statistics.active_parameters++;
    
    pthread_rwlock_unlock(&g_debug_manager->data_lock);
    
    return HMR_SUCCESS;
}

int32_t hmr_debug_update_parameter(const char* shader_name, const char* parameter_name, const void* value) {
    if (!g_debug_manager || !shader_name || !parameter_name || !value) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    pthread_rwlock_wrlock(&g_debug_manager->data_lock);
    
    int32_t group_index = hmr_find_shader_parameter_group(shader_name);
    if (group_index < 0) {
        pthread_rwlock_unlock(&g_debug_manager->data_lock);
        return HMR_ERROR_NOT_FOUND;
    }
    
    // Find parameter
    for (uint32_t i = 0; i < g_debug_manager->shader_parameters[group_index].parameter_count; i++) {
        hmr_shader_parameter_t* param = &g_debug_manager->shader_parameters[group_index].parameters[i];
        
        if (strcmp(param->parameter_name, parameter_name) == 0) {
            // Update parameter value based on type
            switch (param->type) {
                case HMR_PARAM_TYPE_FLOAT:
                    param->data.float_param.value = *(float*)value;
                    break;
                case HMR_PARAM_TYPE_VEC2:
                    memcpy(param->data.vec2_param.value, value, sizeof(float) * 2);
                    break;
                case HMR_PARAM_TYPE_VEC3:
                    memcpy(param->data.vec3_param.value, value, sizeof(float) * 3);
                    break;
                case HMR_PARAM_TYPE_VEC4:
                    memcpy(param->data.vec4_param.value, value, sizeof(float) * 4);
                    break;
                case HMR_PARAM_TYPE_INT:
                    param->data.int_param.value = *(int32_t*)value;
                    break;
                case HMR_PARAM_TYPE_BOOL:
                    param->data.bool_param.value = *(bool*)value;
                    break;
                default:
                    pthread_rwlock_unlock(&g_debug_manager->data_lock);
                    return HMR_ERROR_INVALID_ARG;
            }
            
            param->is_dirty = true;
            param->last_modified_time = hmr_get_current_time_ns();
            
            pthread_rwlock_unlock(&g_debug_manager->data_lock);
            
            // Call UI callback
            if (g_debug_manager->on_parameter_changed) {
                g_debug_manager->on_parameter_changed(shader_name, parameter_name);
            }
            
            return HMR_SUCCESS;
        }
    }
    
    pthread_rwlock_unlock(&g_debug_manager->data_lock);
    return HMR_ERROR_NOT_FOUND;
}

int32_t hmr_debug_get_messages(hmr_debug_severity_t min_severity, hmr_shader_debug_message_t* messages,
                              uint32_t max_count, uint32_t* actual_count) {
    if (!g_debug_manager || !messages || !actual_count) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    pthread_rwlock_rdlock(&g_debug_manager->data_lock);
    
    uint32_t count = 0;
    uint32_t start_index = (g_debug_manager->message_write_index + MAX_DEBUG_MESSAGES - g_debug_manager->message_count) % MAX_DEBUG_MESSAGES;
    
    for (uint32_t i = 0; i < g_debug_manager->message_count && count < max_count; i++) {
        uint32_t index = (start_index + i) % MAX_DEBUG_MESSAGES;
        hmr_shader_debug_message_t* msg = &g_debug_manager->debug_messages[index];
        
        if (msg->severity >= min_severity) {
            memcpy(&messages[count], msg, sizeof(hmr_shader_debug_message_t));
            count++;
        }
    }
    
    *actual_count = count;
    
    pthread_rwlock_unlock(&g_debug_manager->data_lock);
    
    return HMR_SUCCESS;
}

void hmr_debug_get_statistics(hmr_debug_statistics_t* stats) {
    if (!g_debug_manager || !stats) return;
    
    pthread_rwlock_rdlock(&g_debug_manager->data_lock);
    
    memcpy(stats, &g_debug_manager->statistics, sizeof(hmr_debug_statistics_t));
    stats->last_update_time = hmr_get_current_time_ns();
    
    pthread_rwlock_unlock(&g_debug_manager->data_lock);
}

void hmr_debug_set_ui_callbacks(
    void (*on_message_logged)(const hmr_shader_debug_message_t* message),
    void (*on_performance_updated)(const hmr_shader_performance_metrics_t* metrics),
    void (*on_parameter_changed)(const char* shader_name, const char* parameter_name),
    void (*on_dependency_updated)(const char* node_id, bool is_compiled, bool has_errors)
) {
    if (!g_debug_manager) return;
    
    g_debug_manager->on_message_logged = on_message_logged;
    g_debug_manager->on_performance_updated = on_performance_updated;
    g_debug_manager->on_parameter_changed = on_parameter_changed;
    g_debug_manager->on_dependency_updated = on_dependency_updated;
}

void hmr_debug_cleanup(void) {
    if (!g_debug_manager) return;
    
    // Release Metal objects
    g_debug_manager->active_captures = nil;
    
    // Release dispatch objects
    if (g_debug_manager->debug_queue) {
        dispatch_release(g_debug_manager->debug_queue);
    }
    
    // Destroy synchronization objects
    pthread_rwlock_destroy(&g_debug_manager->data_lock);
    
    free(g_debug_manager);
    g_debug_manager = NULL;
    
    NSLog(@"HMR Shader Debug: Cleanup complete");
}