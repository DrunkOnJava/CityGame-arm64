/*
 * SimCity ARM64 - Developer Experience Features
 * Agent 2: File Watcher & Build Pipeline - Week 2 Day 10
 * 
 * Developer experience enhancements for the build system
 * Features:
 * - Comprehensive build progress reporting
 * - Build error analysis and intelligent suggestions
 * - Detailed build performance analytics
 * - Per-developer build customization and preferences
 */

#include "build_optimizer.h"
#include "file_watcher_advanced.h"
#include "module_build_integration.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <mach/mach_time.h>
#include <CoreFoundation/CoreFoundation.h>

// Developer experience constants
#define DEV_MAX_ERROR_SUGGESTIONS 10
#define DEV_MAX_BUILD_HISTORY 1000
#define DEV_MAX_CUSTOM_RULES 64
#define DEV_MAX_NOTIFICATION_TYPES 16
#define DEV_CONFIG_FILE_SIZE 4096

// Build progress phases
typedef enum {
    BUILD_PHASE_STARTING = 0,
    BUILD_PHASE_DEPENDENCY_CHECK,
    BUILD_PHASE_PREPROCESSING,
    BUILD_PHASE_COMPILATION,
    BUILD_PHASE_LINKING,
    BUILD_PHASE_TESTING,
    BUILD_PHASE_VALIDATION,
    BUILD_PHASE_COMPLETE
} build_phase_t;

// Error classification
typedef enum {
    ERROR_TYPE_SYNTAX = 0,
    ERROR_TYPE_SEMANTIC,
    ERROR_TYPE_LINKER,
    ERROR_TYPE_DEPENDENCY,
    ERROR_TYPE_PERFORMANCE,
    ERROR_TYPE_RESOURCE,
    ERROR_TYPE_SYSTEM,
    ERROR_TYPE_UNKNOWN
} error_type_t;

// Error suggestion
typedef struct {
    char suggestion[512];
    char fix_command[256];
    float confidence;                 // 0.0 to 1.0
    error_type_t error_type;
    bool is_automated_fix;
} error_suggestion_t;

// Build error analysis
typedef struct {
    char error_message[1024];
    char file_path[1024];
    uint32_t line_number;
    uint32_t column_number;
    error_type_t error_type;
    float severity;                   // 0.0 to 1.0
    
    uint32_t suggestion_count;
    error_suggestion_t suggestions[DEV_MAX_ERROR_SUGGESTIONS];
    
    // Context information
    char function_name[128];
    char module_name[64];
    bool is_regression;               // Error appeared after recent change
    bool has_fix_available;
} build_error_analysis_t;

// Build progress information
typedef struct {
    char module_name[64];
    build_phase_t current_phase;
    uint32_t overall_progress;        // 0-100%
    uint32_t phase_progress;          // 0-100%
    
    uint64_t start_time_ns;
    uint64_t estimated_completion_ns;
    uint64_t elapsed_time_ns;
    
    char current_file[1024];
    uint32_t files_processed;
    uint32_t total_files;
    
    // Performance metrics
    uint32_t lines_per_second;
    uint32_t memory_usage_mb;
    float cpu_usage_percent;
    
    // Status information
    bool is_incremental;
    bool has_warnings;
    bool has_errors;
    uint32_t warning_count;
    uint32_t error_count;
} build_progress_info_t;

// Developer preference
typedef struct {
    char key[128];
    char value[512];
    char description[256];
    bool is_global;                   // Global vs per-project preference
} developer_preference_t;

// Build notification settings
typedef struct {
    bool enable_desktop_notifications;
    bool enable_sound_notifications;
    bool enable_email_notifications;
    bool notify_on_success;
    bool notify_on_failure;
    bool notify_on_warnings;
    bool notify_on_performance_regression;
    
    uint32_t min_build_time_for_notification_ms;
    float performance_regression_threshold;
} notification_settings_t;

// Build analytics
typedef struct {
    // Time-based metrics
    uint64_t total_build_time_today_ns;
    uint64_t total_build_time_week_ns;
    uint64_t fastest_build_time_ns;
    uint64_t slowest_build_time_ns;
    uint32_t builds_today;
    uint32_t builds_week;
    
    // Success/failure rates
    uint32_t successful_builds_today;
    uint32_t failed_builds_today;
    float success_rate_today;
    float success_rate_week;
    
    // Module-specific metrics
    char most_built_module[64];
    char most_problematic_module[64];
    uint32_t most_built_count;
    uint32_t most_error_count;
    
    // Performance trends
    float build_time_trend;           // Positive = getting slower, negative = getting faster
    float error_rate_trend;
    uint32_t cache_efficiency_percent;
    
    // Developer productivity
    uint32_t lines_built_today;
    uint32_t files_modified_today;
    float productivity_score;         // 0.0 to 1.0
} build_analytics_t;

// Developer experience state
typedef struct {
    // Preferences and configuration
    developer_preference_t preferences[DEV_MAX_CUSTOM_RULES];
    uint32_t preference_count;
    notification_settings_t notifications;
    
    // Build progress tracking
    build_progress_info_t current_builds[32];
    uint32_t active_build_count;
    
    // Error analysis
    build_error_analysis_t recent_errors[100];
    uint32_t error_history_count;
    uint32_t error_history_index;
    
    // Analytics
    build_analytics_t analytics;
    uint64_t analytics_last_update_ns;
    
    // Performance tracking
    uint64_t build_history[DEV_MAX_BUILD_HISTORY];
    uint32_t build_history_index;
    uint32_t build_history_count;
    
    // Configuration
    char developer_name[64];
    char project_root[1024];
    char config_file_path[1024];
    bool debug_mode;
    
    mach_timebase_info_data_t timebase_info;
} developer_experience_state_t;

static developer_experience_state_t* g_dev_experience = NULL;

// Helper function to get current time in nanoseconds
static uint64_t get_current_time_ns(void) {
    if (g_dev_experience->timebase_info.denom == 0) {
        mach_timebase_info(&g_dev_experience->timebase_info);
    }
    
    uint64_t mach_time = mach_absolute_time();
    return mach_time * g_dev_experience->timebase_info.numer / g_dev_experience->timebase_info.denom;
}

// Initialize developer experience system
int32_t developer_experience_init(const char* developer_name, const char* project_root) {
    if (g_dev_experience) {
        return BUILD_ERROR_ALREADY_EXISTS;
    }
    
    if (!developer_name || !project_root) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    g_dev_experience = calloc(1, sizeof(developer_experience_state_t));
    if (!g_dev_experience) {
        return BUILD_ERROR_OUT_OF_MEMORY;
    }
    
    // Initialize basic configuration
    strncpy(g_dev_experience->developer_name, developer_name, sizeof(g_dev_experience->developer_name) - 1);
    strncpy(g_dev_experience->project_root, project_root, sizeof(g_dev_experience->project_root) - 1);
    
    // Set up config file path
    snprintf(g_dev_experience->config_file_path, sizeof(g_dev_experience->config_file_path),
             "%s/.simcity_dev_config_%s", project_root, developer_name);
    
    // Initialize default notification settings
    g_dev_experience->notifications.enable_desktop_notifications = true;
    g_dev_experience->notifications.enable_sound_notifications = false;
    g_dev_experience->notifications.notify_on_failure = true;
    g_dev_experience->notifications.notify_on_performance_regression = true;
    g_dev_experience->notifications.min_build_time_for_notification_ms = 5000; // 5 seconds
    g_dev_experience->notifications.performance_regression_threshold = 0.2f;   // 20% slower
    
    // Initialize analytics timestamp
    g_dev_experience->analytics_last_update_ns = get_current_time_ns();
    
    // Load existing configuration if available
    FILE* config_file = fopen(g_dev_experience->config_file_path, "r");
    if (config_file) {
        // Simple key=value configuration loading
        char line[512];
        while (fgets(line, sizeof(line), config_file)) {
            char* equals = strchr(line, '=');
            if (equals && g_dev_experience->preference_count < DEV_MAX_CUSTOM_RULES) {
                *equals = '\0';
                developer_preference_t* pref = &g_dev_experience->preferences[g_dev_experience->preference_count++];
                strncpy(pref->key, line, sizeof(pref->key) - 1);
                strncpy(pref->value, equals + 1, sizeof(pref->value) - 1);
                
                // Remove newline from value
                char* newline = strchr(pref->value, '\n');
                if (newline) *newline = '\0';
            }
        }
        fclose(config_file);
    }
    
    printf("Developer Experience: Initialized for %s in %s\n", developer_name, project_root);
    printf("Developer Experience: Loaded %u preferences from config\n", g_dev_experience->preference_count);
    
    return BUILD_SUCCESS;
}

// Analyze build error and provide suggestions
int32_t developer_experience_analyze_error(const char* error_message, const char* file_path,
                                          uint32_t line_number, build_error_analysis_t* analysis) {
    if (!g_dev_experience || !error_message || !analysis) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    memset(analysis, 0, sizeof(build_error_analysis_t));
    
    // Copy basic error information
    strncpy(analysis->error_message, error_message, sizeof(analysis->error_message) - 1);
    if (file_path) {
        strncpy(analysis->file_path, file_path, sizeof(analysis->file_path) - 1);
    }
    analysis->line_number = line_number;
    
    // Classify error type based on message content
    if (strstr(error_message, "syntax") || strstr(error_message, "parse") || strstr(error_message, "unexpected")) {
        analysis->error_type = ERROR_TYPE_SYNTAX;
        analysis->severity = 0.9f;
    } else if (strstr(error_message, "undefined") || strstr(error_message, "unresolved") || strstr(error_message, "symbol")) {
        analysis->error_type = ERROR_TYPE_LINKER;
        analysis->severity = 0.8f;
    } else if (strstr(error_message, "type") || strstr(error_message, "incompatible")) {
        analysis->error_type = ERROR_TYPE_SEMANTIC;
        analysis->severity = 0.7f;
    } else if (strstr(error_message, "memory") || strstr(error_message, "resource")) {
        analysis->error_type = ERROR_TYPE_RESOURCE;
        analysis->severity = 0.6f;
    } else {
        analysis->error_type = ERROR_TYPE_UNKNOWN;
        analysis->severity = 0.5f;
    }
    
    // Generate intelligent suggestions based on error type and content
    switch (analysis->error_type) {
        case ERROR_TYPE_SYNTAX:
            if (strstr(error_message, "expected")) {
                error_suggestion_t* suggestion = &analysis->suggestions[analysis->suggestion_count++];
                strcpy(suggestion->suggestion, "Check for missing semicolons, braces, or parentheses near the error location");
                strcpy(suggestion->fix_command, "");
                suggestion->confidence = 0.8f;
                suggestion->error_type = ERROR_TYPE_SYNTAX;
            }
            break;
            
        case ERROR_TYPE_LINKER:
            if (strstr(error_message, "undefined symbol")) {
                error_suggestion_t* suggestion = &analysis->suggestions[analysis->suggestion_count++];
                strcpy(suggestion->suggestion, "Add the missing symbol definition or check library dependencies");
                strcpy(suggestion->fix_command, "grep -r 'symbol_name' src/");
                suggestion->confidence = 0.9f;
                suggestion->error_type = ERROR_TYPE_LINKER;
            }
            break;
            
        case ERROR_TYPE_DEPENDENCY:
            {
                error_suggestion_t* suggestion = &analysis->suggestions[analysis->suggestion_count++];
                strcpy(suggestion->suggestion, "Update module dependencies or check include paths");
                strcpy(suggestion->fix_command, "./build_tools/build_master.sh --clean");
                suggestion->confidence = 0.7f;
                suggestion->error_type = ERROR_TYPE_DEPENDENCY;
            }
            break;
            
        default:
            {
                error_suggestion_t* suggestion = &analysis->suggestions[analysis->suggestion_count++];
                strcpy(suggestion->suggestion, "Try a clean build to resolve potential build system issues");
                strcpy(suggestion->fix_command, "./build_tools/build_master.sh --clean --verbose");
                suggestion->confidence = 0.5f;
                suggestion->error_type = ERROR_TYPE_UNKNOWN;
            }
            break;
    }
    
    // Add to error history
    if (g_dev_experience->error_history_count < 100) {
        g_dev_experience->recent_errors[g_dev_experience->error_history_count] = *analysis;
        g_dev_experience->error_history_count++;
    } else {
        g_dev_experience->recent_errors[g_dev_experience->error_history_index] = *analysis;
        g_dev_experience->error_history_index = (g_dev_experience->error_history_index + 1) % 100;
    }
    
    if (g_dev_experience->debug_mode) {
        printf("Developer Experience: Analyzed error (type: %d, severity: %.2f, %u suggestions)\n",
               analysis->error_type, analysis->severity, analysis->suggestion_count);
    }
    
    return BUILD_SUCCESS;
}

// Update build progress
int32_t developer_experience_update_progress(const char* module_name, build_phase_t phase,
                                            uint32_t progress_percent, const char* current_file) {
    if (!g_dev_experience || !module_name) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    // Find or create build progress entry
    build_progress_info_t* progress = NULL;
    for (uint32_t i = 0; i < g_dev_experience->active_build_count; i++) {
        if (strcmp(g_dev_experience->current_builds[i].module_name, module_name) == 0) {
            progress = &g_dev_experience->current_builds[i];
            break;
        }
    }
    
    if (!progress && g_dev_experience->active_build_count < 32) {
        progress = &g_dev_experience->current_builds[g_dev_experience->active_build_count++];
        strncpy(progress->module_name, module_name, sizeof(progress->module_name) - 1);
        progress->start_time_ns = get_current_time_ns();
    }
    
    if (!progress) {
        return BUILD_ERROR_OUT_OF_MEMORY;
    }
    
    // Update progress information
    progress->current_phase = phase;
    progress->phase_progress = progress_percent;
    progress->elapsed_time_ns = get_current_time_ns() - progress->start_time_ns;
    
    if (current_file) {
        strncpy(progress->current_file, current_file, sizeof(progress->current_file) - 1);
        progress->files_processed++;
    }
    
    // Calculate overall progress based on phase
    static const uint32_t phase_weights[] = {0, 10, 20, 50, 80, 90, 95, 100};
    progress->overall_progress = phase_weights[phase] + (progress_percent * (phase_weights[phase + 1] - phase_weights[phase])) / 100;
    
    // Estimate completion time based on current progress
    if (progress->overall_progress > 0) {
        uint64_t estimated_total_time = (progress->elapsed_time_ns * 100) / progress->overall_progress;
        progress->estimated_completion_ns = progress->start_time_ns + estimated_total_time;
    }
    
    if (g_dev_experience->debug_mode) {
        printf("Developer Experience: Progress update for %s - Phase: %d, Progress: %u%%, File: %s\n",
               module_name, phase, progress->overall_progress, current_file ? current_file : "N/A");
    }
    
    return BUILD_SUCCESS;
}

// Complete build and update analytics
int32_t developer_experience_complete_build(const char* module_name, bool success, 
                                           uint64_t build_time_ns, uint32_t warning_count,
                                           uint32_t error_count) {
    if (!g_dev_experience || !module_name) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    // Remove from active builds
    for (uint32_t i = 0; i < g_dev_experience->active_build_count; i++) {
        if (strcmp(g_dev_experience->current_builds[i].module_name, module_name) == 0) {
            // Shift remaining builds
            memmove(&g_dev_experience->current_builds[i], &g_dev_experience->current_builds[i + 1],
                   (g_dev_experience->active_build_count - i - 1) * sizeof(build_progress_info_t));
            g_dev_experience->active_build_count--;
            break;
        }
    }
    
    // Update build history
    g_dev_experience->build_history[g_dev_experience->build_history_index] = build_time_ns;
    g_dev_experience->build_history_index = (g_dev_experience->build_history_index + 1) % DEV_MAX_BUILD_HISTORY;
    if (g_dev_experience->build_history_count < DEV_MAX_BUILD_HISTORY) {
        g_dev_experience->build_history_count++;
    }
    
    // Update analytics
    uint64_t current_time = get_current_time_ns();
    uint64_t day_ns = 24ULL * 60 * 60 * 1000000000; // 24 hours in nanoseconds
    
    if (current_time - g_dev_experience->analytics_last_update_ns < day_ns) {
        // Same day, update daily metrics
        g_dev_experience->analytics.total_build_time_today_ns += build_time_ns;
        g_dev_experience->analytics.builds_today++;
        
        if (success) {
            g_dev_experience->analytics.successful_builds_today++;
        } else {
            g_dev_experience->analytics.failed_builds_today++;
        }
    } else {
        // New day, reset daily metrics
        g_dev_experience->analytics.total_build_time_today_ns = build_time_ns;
        g_dev_experience->analytics.builds_today = 1;
        g_dev_experience->analytics.successful_builds_today = success ? 1 : 0;
        g_dev_experience->analytics.failed_builds_today = success ? 0 : 1;
        g_dev_experience->analytics_last_update_ns = current_time;
    }
    
    // Update fastest/slowest build times
    if (build_time_ns < g_dev_experience->analytics.fastest_build_time_ns || 
        g_dev_experience->analytics.fastest_build_time_ns == 0) {
        g_dev_experience->analytics.fastest_build_time_ns = build_time_ns;
    }
    
    if (build_time_ns > g_dev_experience->analytics.slowest_build_time_ns) {
        g_dev_experience->analytics.slowest_build_time_ns = build_time_ns;
    }
    
    // Calculate success rates
    if (g_dev_experience->analytics.builds_today > 0) {
        g_dev_experience->analytics.success_rate_today = 
            (float)g_dev_experience->analytics.successful_builds_today / g_dev_experience->analytics.builds_today;
    }
    
    // Send notification if configured
    if (!success && g_dev_experience->notifications.notify_on_failure) {
        printf("🚨 Build Failed: %s (%u errors, %u warnings)\n", module_name, error_count, warning_count);
    } else if (success && build_time_ns > g_dev_experience->notifications.min_build_time_for_notification_ms * 1000000ULL) {
        printf("✅ Build Complete: %s (%.2f seconds)\n", module_name, build_time_ns / 1000000000.0);
    }
    
    if (g_dev_experience->debug_mode) {
        printf("Developer Experience: Build completed for %s - Success: %s, Time: %.2f ms, Analytics updated\n",
               module_name, success ? "Yes" : "No", build_time_ns / 1000000.0);
    }
    
    return BUILD_SUCCESS;
}

// Get build analytics
int32_t developer_experience_get_analytics(build_analytics_t* analytics) {
    if (!g_dev_experience || !analytics) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    *analytics = g_dev_experience->analytics;
    return BUILD_SUCCESS;
}

// Set developer preference
int32_t developer_experience_set_preference(const char* key, const char* value, const char* description) {
    if (!g_dev_experience || !key || !value) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    // Find existing preference or create new one
    developer_preference_t* pref = NULL;
    for (uint32_t i = 0; i < g_dev_experience->preference_count; i++) {
        if (strcmp(g_dev_experience->preferences[i].key, key) == 0) {
            pref = &g_dev_experience->preferences[i];
            break;
        }
    }
    
    if (!pref && g_dev_experience->preference_count < DEV_MAX_CUSTOM_RULES) {
        pref = &g_dev_experience->preferences[g_dev_experience->preference_count++];
        strncpy(pref->key, key, sizeof(pref->key) - 1);
    }
    
    if (!pref) {
        return BUILD_ERROR_OUT_OF_MEMORY;
    }
    
    strncpy(pref->value, value, sizeof(pref->value) - 1);
    if (description) {
        strncpy(pref->description, description, sizeof(pref->description) - 1);
    }
    
    if (g_dev_experience->debug_mode) {
        printf("Developer Experience: Set preference %s = %s\n", key, value);
    }
    
    return BUILD_SUCCESS;
}

// Save configuration to file
int32_t developer_experience_save_config(void) {
    if (!g_dev_experience) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    FILE* config_file = fopen(g_dev_experience->config_file_path, "w");
    if (!config_file) {
        return BUILD_ERROR_IO_ERROR;
    }
    
    // Write preferences
    for (uint32_t i = 0; i < g_dev_experience->preference_count; i++) {
        developer_preference_t* pref = &g_dev_experience->preferences[i];
        fprintf(config_file, "%s=%s\n", pref->key, pref->value);
    }
    
    // Write notification settings
    fprintf(config_file, "notifications.desktop=%s\n", 
            g_dev_experience->notifications.enable_desktop_notifications ? "true" : "false");
    fprintf(config_file, "notifications.sound=%s\n",
            g_dev_experience->notifications.enable_sound_notifications ? "true" : "false");
    fprintf(config_file, "notifications.on_failure=%s\n",
            g_dev_experience->notifications.notify_on_failure ? "true" : "false");
    fprintf(config_file, "notifications.min_time_ms=%u\n",
            g_dev_experience->notifications.min_build_time_for_notification_ms);
    
    fclose(config_file);
    
    printf("Developer Experience: Configuration saved to %s\n", g_dev_experience->config_file_path);
    return BUILD_SUCCESS;
}

// Enable debug mode
int32_t developer_experience_enable_debug(bool enabled) {
    if (!g_dev_experience) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    g_dev_experience->debug_mode = enabled;
    printf("Developer Experience: Debug mode %s\n", enabled ? "enabled" : "disabled");
    
    return BUILD_SUCCESS;
}

// Cleanup developer experience system
void developer_experience_cleanup(void) {
    if (!g_dev_experience) return;
    
    // Save configuration before cleanup
    developer_experience_save_config();
    
    printf("Developer Experience: Cleanup complete for %s - %u builds today, %.1f%% success rate\n",
           g_dev_experience->developer_name,
           g_dev_experience->analytics.builds_today,
           g_dev_experience->analytics.success_rate_today * 100.0f);
    
    free(g_dev_experience);
    g_dev_experience = NULL;
}