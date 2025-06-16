/*
 * SimCity ARM64 - Shader Error Handler Header
 * Advanced error handling and recovery interface
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Day 2: Shader Error Handling Interface
 */

#ifndef HMR_SHADER_ERROR_HANDLER_H
#define HMR_SHADER_ERROR_HANDLER_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Error severity levels
typedef enum {
    HMR_SHADER_ERROR_INFO = 0,
    HMR_SHADER_ERROR_WARNING,
    HMR_SHADER_ERROR_ERROR,
    HMR_SHADER_ERROR_FATAL
} hmr_shader_error_severity_t;

// Recovery strategies
typedef enum {
    HMR_RECOVERY_NONE = 0,
    HMR_RECOVERY_FALLBACK,
    HMR_RECOVERY_RETRY,
    HMR_RECOVERY_DISABLE,
    HMR_RECOVERY_PARTIAL_COMPILE
} hmr_shader_recovery_strategy_t;

// Parsed error information
typedef struct {
    char file_path[256];
    uint32_t line_number;
    uint32_t column_number;
    hmr_shader_error_severity_t severity;
    char error_code[32];
    char message[512];
    char context[256];
} hmr_shader_error_info_t;

// Error handler configuration
typedef struct {
    bool enable_detailed_parsing;
    bool enable_auto_recovery;
    bool enable_error_logging;
    uint32_t max_retry_attempts;
    uint32_t retry_delay_ms;
    char error_log_path[256];
} hmr_shader_error_config_t;

// Error handler API functions
int32_t hmr_shader_error_handler_init(const hmr_shader_error_config_t* config);
int32_t hmr_shader_error_handle(const char* shader_path, const char* error_message);

// Callback registration
void hmr_shader_error_handler_set_callbacks(
    void (*on_error_parsed)(const hmr_shader_error_info_t* error_info),
    void (*on_recovery_attempted)(const char* path, hmr_shader_recovery_strategy_t strategy),
    void (*on_recovery_success)(const char* path, hmr_shader_recovery_strategy_t strategy),
    void (*on_recovery_failed)(const char* path, hmr_shader_recovery_strategy_t strategy)
);

// Statistics and monitoring
void hmr_shader_error_handler_get_stats(
    uint64_t* total_errors,
    uint64_t* auto_recoveries,
    uint64_t* fallback_activations
);

// Cleanup
void hmr_shader_error_handler_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif // HMR_SHADER_ERROR_HANDLER_H