/*
 * SimCity ARM64 - Developer Experience Features Header
 * Agent 2: File Watcher & Build Pipeline - Week 2 Day 10
 */

#ifndef DEVELOPER_EXPERIENCE_H
#define DEVELOPER_EXPERIENCE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Error types for analysis
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

// Build phases
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

// Build analytics structure
typedef struct {
    uint64_t total_build_time_today_ns;
    uint64_t total_build_time_week_ns;
    uint64_t fastest_build_time_ns;
    uint64_t slowest_build_time_ns;
    uint32_t builds_today;
    uint32_t builds_week;
    uint32_t successful_builds_today;
    uint32_t failed_builds_today;
    float success_rate_today;
    float success_rate_week;
    char most_built_module[64];
    char most_problematic_module[64];
    uint32_t most_built_count;
    uint32_t most_error_count;
    float build_time_trend;
    float error_rate_trend;
    uint32_t cache_efficiency_percent;
    uint32_t lines_built_today;
    uint32_t files_modified_today;
    float productivity_score;
} build_analytics_t;

// Error suggestion structure  
typedef struct {
    char suggestion[512];
    char fix_command[256];
    float confidence;
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
    float severity;
    uint32_t suggestion_count;
    error_suggestion_t suggestions[10];
    char function_name[128];
    char module_name[64];
    bool is_regression;
    bool has_fix_available;
} build_error_analysis_t;

// Function declarations
int32_t developer_experience_init(const char* developer_name, const char* project_root);
int32_t developer_experience_analyze_error(const char* error_message, const char* file_path,
                                          uint32_t line_number, build_error_analysis_t* analysis);
int32_t developer_experience_update_progress(const char* module_name, build_phase_t phase,
                                            uint32_t progress_percent, const char* current_file);
int32_t developer_experience_complete_build(const char* module_name, bool success, 
                                           uint64_t build_time_ns, uint32_t warning_count,
                                           uint32_t error_count);
int32_t developer_experience_get_analytics(build_analytics_t* analytics);
int32_t developer_experience_set_preference(const char* key, const char* value, const char* description);
int32_t developer_experience_enable_debug(bool enabled);
void developer_experience_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif // DEVELOPER_EXPERIENCE_H