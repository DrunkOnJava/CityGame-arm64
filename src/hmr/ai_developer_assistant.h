/*
 * SimCity ARM64 - AI-Powered Developer Assistant
 * Advanced AI integration for ARM64 assembly development
 * 
 * Agent 4: Developer Tools & Debug Interface
 * Week 3 Day 11: Advanced UI Features & AI Integration
 */

#ifndef HMR_AI_DEVELOPER_ASSISTANT_H
#define HMR_AI_DEVELOPER_ASSISTANT_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// AI Assistant Types
typedef enum {
    AI_CONTEXT_ARM64_ASSEMBLY = 0,
    AI_CONTEXT_C_INTERFACE,
    AI_CONTEXT_BUILD_SYSTEM,
    AI_CONTEXT_PERFORMANCE_OPTIMIZATION,
    AI_CONTEXT_DEBUGGING,
    AI_CONTEXT_ARCHITECTURE_DESIGN,
    AI_CONTEXT_CODE_REVIEW,
    AI_CONTEXT_UNKNOWN
} ai_context_type_t;

typedef enum {
    AI_SUGGESTION_COMPLETION = 0,
    AI_SUGGESTION_OPTIMIZATION,
    AI_SUGGESTION_BUG_FIX,
    AI_SUGGESTION_REFACTOR,
    AI_SUGGESTION_PERFORMANCE,
    AI_SUGGESTION_DOCUMENTATION,
    AI_SUGGESTION_ARCHITECTURE,
    AI_SUGGESTION_SECURITY
} ai_suggestion_type_t;

typedef enum {
    AI_CONFIDENCE_LOW = 0,      // 0-30%
    AI_CONFIDENCE_MEDIUM,       // 31-70%
    AI_CONFIDENCE_HIGH,         // 71-90%
    AI_CONFIDENCE_VERY_HIGH     // 91-100%
} ai_confidence_level_t;

// AI Code Completion Structure
typedef struct {
    char completion_text[2048];
    char display_text[512];
    char documentation[1024];
    ai_suggestion_type_t type;
    ai_confidence_level_t confidence;
    uint32_t cursor_offset;
    uint32_t replace_length;
    float priority_score;
    bool is_snippet;
    char snippet_placeholders[10][128];
    uint32_t placeholder_count;
} ai_code_completion_t;

// AI Pattern Recognition
typedef struct {
    char pattern_name[128];
    char pattern_description[512];
    char file_path[1024];
    uint32_t line_start;
    uint32_t line_end;
    ai_suggestion_type_t suggestion_type;
    float confidence;
    char suggested_fix[2048];
    bool is_critical;
    bool has_auto_fix;
} ai_pattern_match_t;

// AI Performance Analysis
typedef struct {
    char function_name[128];
    char module_name[64];
    char performance_issue[512];
    char optimization_suggestion[1024];
    char code_example[2048];
    float estimated_improvement_percent;
    uint32_t complexity_score;
    bool is_neon_optimizable;
    bool is_cache_sensitive;
    bool requires_architecture_change;
} ai_performance_analysis_t;

// AI Development Context
typedef struct {
    char current_file[1024];
    uint32_t cursor_line;
    uint32_t cursor_column;
    char selected_text[4096];
    char surrounding_context[8192];
    ai_context_type_t context_type;
    char active_function[128];
    char active_module[64];
    uint32_t indentation_level;
    bool is_in_comment;
    bool is_in_string;
    bool is_in_macro;
    uint64_t timestamp_us;
} ai_development_context_t;

// AI Learning Data
typedef struct {
    char interaction_type[64];
    char user_input[2048];
    char ai_response[4096];
    bool was_accepted;
    float user_satisfaction;
    uint64_t response_time_us;
    ai_context_type_t context;
    char feedback[512];
    uint64_t timestamp_us;
} ai_learning_data_t;

// Core AI Assistant Functions
int32_t ai_assistant_init(const char* model_path, const char* config_path);
void ai_assistant_shutdown(void);

// Code Completion & Suggestions
int32_t ai_get_code_completions(const ai_development_context_t* context,
                               ai_code_completion_t* completions,
                               uint32_t max_completions,
                               uint32_t* completion_count);

int32_t ai_get_smart_suggestions(const ai_development_context_t* context,
                               const char* user_intent,
                               ai_code_completion_t* suggestions,
                               uint32_t max_suggestions,
                               uint32_t* suggestion_count);

// Pattern Recognition & Bug Detection
int32_t ai_analyze_code_patterns(const char* file_path,
                               const char* code_content,
                               ai_pattern_match_t* patterns,
                               uint32_t max_patterns,
                               uint32_t* pattern_count);

int32_t ai_detect_potential_bugs(const char* file_path,
                               const char* code_content,
                               ai_pattern_match_t* bugs,
                               uint32_t max_bugs,
                               uint32_t* bug_count);

// Performance Analysis
int32_t ai_analyze_performance_hotspots(const char* file_path,
                                      const char* code_content,
                                      const char* profile_data,
                                      ai_performance_analysis_t* analyses,
                                      uint32_t max_analyses,
                                      uint32_t* analysis_count);

int32_t ai_suggest_neon_optimizations(const char* function_name,
                                    const char* code_content,
                                    ai_performance_analysis_t* optimizations,
                                    uint32_t max_optimizations,
                                    uint32_t* optimization_count);

// Documentation & Code Explanation
int32_t ai_generate_documentation(const char* function_name,
                                const char* code_content,
                                char* documentation,
                                size_t max_doc_length);

int32_t ai_explain_code_section(const char* code_content,
                              uint32_t start_line,
                              uint32_t end_line,
                              char* explanation,
                              size_t max_explanation_length);

// Refactoring Assistance
int32_t ai_suggest_refactoring(const char* file_path,
                             const char* code_content,
                             const char* refactor_goal,
                             char* refactored_code,
                             size_t max_code_length,
                             char* explanation,
                             size_t max_explanation_length);

// Context Management
int32_t ai_update_development_context(const ai_development_context_t* context);
int32_t ai_get_current_context(ai_development_context_t* context);

// Learning & Adaptation
int32_t ai_record_interaction(const ai_learning_data_t* interaction);
int32_t ai_update_user_preferences(const char* preference_key,
                                 const char* preference_value);
int32_t ai_get_user_preferences(const char* preference_key,
                              char* preference_value,
                              size_t max_value_length);

// Advanced Features
int32_t ai_generate_unit_tests(const char* function_name,
                             const char* code_content,
                             char* test_code,
                             size_t max_test_length);

int32_t ai_suggest_architecture_improvements(const char* module_name,
                                           const char* current_architecture,
                                           char* improvements,
                                           size_t max_improvements_length);

int32_t ai_validate_code_quality(const char* file_path,
                               const char* code_content,
                               ai_pattern_match_t* quality_issues,
                               uint32_t max_issues,
                               uint32_t* issue_count);

// Real-time Analysis
typedef void (*ai_analysis_callback_t)(const ai_pattern_match_t* pattern, void* user_data);
int32_t ai_start_realtime_analysis(const char* file_path, ai_analysis_callback_t callback, void* user_data);
int32_t ai_stop_realtime_analysis(const char* file_path);

// Statistics
typedef struct {
    uint64_t total_completions_provided;
    uint64_t total_suggestions_accepted;
    uint64_t total_patterns_detected;
    uint64_t total_bugs_found;
    uint64_t total_optimizations_suggested;
    float average_response_time_ms;
    float user_satisfaction_score;
    uint32_t active_analysis_sessions;
    bool is_learning_enabled;
} ai_assistant_stats_t;

void ai_get_assistant_stats(ai_assistant_stats_t* stats);

// Configuration
typedef struct {
    bool enable_completions;
    bool enable_pattern_detection;
    bool enable_performance_analysis;
    bool enable_real_time_analysis;
    bool enable_learning;
    float completion_confidence_threshold;
    uint32_t max_completions_per_request;
    uint32_t analysis_update_interval_ms;
    char language_model_path[1024];
    char user_profile_path[1024];
} ai_assistant_config_t;

int32_t ai_set_configuration(const ai_assistant_config_t* config);
int32_t ai_get_configuration(ai_assistant_config_t* config);

#ifdef __cplusplus
}
#endif

#endif // HMR_AI_DEVELOPER_ASSISTANT_H