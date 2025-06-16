/*
 * SimCity ARM64 - Shader Error Handler
 * Advanced error handling and recovery for shader compilation
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Day 2: Shader Error Handling Implementation
 * 
 * Features:
 * - Detailed error parsing and reporting
 * - Automatic fallback activation
 * - Error recovery strategies
 * - Compilation diagnostics
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <time.h>
#include <unistd.h>
#include <mach/mach_time.h>
#include "shader_manager.h"
#include "asset_watcher.h"
#include "module_interface.h"

// Error severity levels
typedef enum {
    HMR_SHADER_ERROR_INFO = 0,
    HMR_SHADER_ERROR_WARNING,
    HMR_SHADER_ERROR_ERROR,
    HMR_SHADER_ERROR_FATAL
} hmr_shader_error_severity_t;

// Parsed error information
typedef struct {
    char file_path[256];                // Source file path
    uint32_t line_number;               // Line number of error
    uint32_t column_number;             // Column number of error
    hmr_shader_error_severity_t severity; // Error severity
    char error_code[32];                // Metal error code
    char message[512];                  // Error message
    char context[256];                  // Surrounding context
} hmr_shader_error_info_t;

// Error recovery strategy
typedef enum {
    HMR_RECOVERY_NONE = 0,
    HMR_RECOVERY_FALLBACK,              // Use fallback shader
    HMR_RECOVERY_RETRY,                 // Retry compilation
    HMR_RECOVERY_DISABLE,               // Disable shader temporarily
    HMR_RECOVERY_PARTIAL_COMPILE        // Try to compile partial shader
} hmr_shader_recovery_strategy_t;

// Error handling configuration
typedef struct {
    bool enable_detailed_parsing;       // Whether to parse error details
    bool enable_auto_recovery;          // Whether to attempt automatic recovery
    bool enable_error_logging;          // Whether to log errors to file
    uint32_t max_retry_attempts;        // Maximum retry attempts
    uint32_t retry_delay_ms;            // Delay between retries
    char error_log_path[256];           // Path for error log file
} hmr_shader_error_config_t;

// Error handler state
typedef struct {
    hmr_shader_error_config_t config;
    FILE* error_log_file;               // Error log file handle
    uint64_t total_errors;              // Total errors encountered
    uint64_t auto_recoveries;           // Successful auto-recoveries
    uint64_t fallback_activations;      // Fallback activations
    
    // Error callbacks
    void (*on_error_parsed)(const hmr_shader_error_info_t* error_info);
    void (*on_recovery_attempted)(const char* path, hmr_shader_recovery_strategy_t strategy);
    void (*on_recovery_success)(const char* path, hmr_shader_recovery_strategy_t strategy);
    void (*on_recovery_failed)(const char* path, hmr_shader_recovery_strategy_t strategy);
} hmr_shader_error_handler_t;

// Global error handler
static hmr_shader_error_handler_t* g_error_handler = NULL;

// Common Metal error patterns for parsing
static const struct {
    const char* pattern;
    hmr_shader_error_severity_t severity;
    const char* description;
} g_metal_error_patterns[] = {
    {"error:", HMR_SHADER_ERROR_ERROR, "Compilation error"},
    {"warning:", HMR_SHADER_ERROR_WARNING, "Compilation warning"},
    {"note:", HMR_SHADER_ERROR_INFO, "Additional information"},
    {"fatal error:", HMR_SHADER_ERROR_FATAL, "Fatal compilation error"},
    {"undeclared identifier", HMR_SHADER_ERROR_ERROR, "Undeclared identifier"},
    {"use of undeclared type", HMR_SHADER_ERROR_ERROR, "Unknown type"},
    {"no matching function", HMR_SHADER_ERROR_ERROR, "Function not found"},
    {"invalid operands", HMR_SHADER_ERROR_ERROR, "Type mismatch"},
    {"syntax error", HMR_SHADER_ERROR_ERROR, "Syntax error"},
    {NULL, HMR_SHADER_ERROR_ERROR, NULL}
};

// Parse Metal compiler error message
static bool hmr_parse_metal_error(const char* error_message, hmr_shader_error_info_t* error_info) {
    if (!error_message || !error_info) return false;
    
    memset(error_info, 0, sizeof(hmr_shader_error_info_t));
    
    // Example Metal error format:
    // "shader.metal:15:23: error: use of undeclared identifier 'unknown_var'"
    
    const char* current = error_message;
    
    // Extract file path
    const char* colon = strchr(current, ':');
    if (colon && (colon - current) < sizeof(error_info->file_path)) {
        strncpy(error_info->file_path, current, colon - current);
        current = colon + 1;
    }
    
    // Extract line number
    if (current && *current) {
        error_info->line_number = strtoul(current, (char**)&current, 10);
        if (*current == ':') current++;
    }
    
    // Extract column number
    if (current && *current) {
        error_info->column_number = strtoul(current, (char**)&current, 10);
        if (*current == ':') current++;
    }
    
    // Skip whitespace
    while (current && *current == ' ') current++;
    
    // Determine severity and extract error code
    error_info->severity = HMR_SHADER_ERROR_ERROR; // Default
    for (int i = 0; g_metal_error_patterns[i].pattern; i++) {
        if (strncmp(current, g_metal_error_patterns[i].pattern, strlen(g_metal_error_patterns[i].pattern)) == 0) {
            error_info->severity = g_metal_error_patterns[i].severity;
            strncpy(error_info->error_code, g_metal_error_patterns[i].pattern, sizeof(error_info->error_code) - 1);
            current += strlen(g_metal_error_patterns[i].pattern);
            break;
        }
    }
    
    // Skip whitespace
    while (current && *current == ' ') current++;
    
    // Extract error message
    if (current && *current) {
        strncpy(error_info->message, current, sizeof(error_info->message) - 1);
        
        // Remove newline if present
        char* newline = strchr(error_info->message, '\n');
        if (newline) *newline = '\0';
    }
    
    return true;
}

// Log error to file if logging is enabled
static void hmr_log_error(const hmr_shader_error_info_t* error_info) {
    if (!g_error_handler || !error_info || !g_error_handler->config.enable_error_logging) return;
    
    if (!g_error_handler->error_log_file) {
        g_error_handler->error_log_file = fopen(g_error_handler->config.error_log_path, "a");
        if (!g_error_handler->error_log_file) {
            printf("HMR Shader Error: Failed to open error log file: %s\n", g_error_handler->config.error_log_path);
            return;
        }
    }
    
    // Get current timestamp
    time_t now = time(NULL);
    struct tm* local_time = localtime(&now);
    char timestamp[64];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", local_time);
    
    // Write error to log
    fprintf(g_error_handler->error_log_file, 
            "[%s] %s:%u:%u %s: %s\n",
            timestamp,
            error_info->file_path,
            error_info->line_number,
            error_info->column_number,
            error_info->error_code,
            error_info->message);
    
    fflush(g_error_handler->error_log_file);
}

// Determine recovery strategy based on error type
static hmr_shader_recovery_strategy_t hmr_determine_recovery_strategy(const hmr_shader_error_info_t* error_info) {
    if (!error_info) return HMR_RECOVERY_NONE;
    
    // Fatal errors require fallback
    if (error_info->severity == HMR_SHADER_ERROR_FATAL) {
        return HMR_RECOVERY_FALLBACK;
    }
    
    // Check error patterns for recovery strategies
    if (strstr(error_info->message, "undeclared identifier") ||
        strstr(error_info->message, "undeclared type") ||
        strstr(error_info->message, "no matching function")) {
        // Missing dependencies might be resolved with retry
        return HMR_RECOVERY_RETRY;
    }
    
    if (strstr(error_info->message, "syntax error")) {
        // Syntax errors are likely permanent, use fallback
        return HMR_RECOVERY_FALLBACK;
    }
    
    if (strstr(error_info->message, "invalid operands") ||
        strstr(error_info->message, "type mismatch")) {
        // Type errors are likely permanent, use fallback
        return HMR_RECOVERY_FALLBACK;
    }
    
    // Default to retry for other errors
    return HMR_RECOVERY_RETRY;
}

// Execute recovery strategy
static bool hmr_execute_recovery_strategy(const char* shader_path, hmr_shader_recovery_strategy_t strategy) {
    if (!g_error_handler || !shader_path) return false;
    
    bool success = false;
    
    // Notify callback
    if (g_error_handler->on_recovery_attempted) {
        g_error_handler->on_recovery_attempted(shader_path, strategy);
    }
    
    switch (strategy) {
        case HMR_RECOVERY_FALLBACK: {
            // Fallback is handled automatically by shader manager
            printf("HMR Shader Error: Activating fallback shader for %s\n", shader_path);
            g_error_handler->fallback_activations++;
            success = true;
            break;
        }
        
        case HMR_RECOVERY_RETRY: {
            printf("HMR Shader Error: Retrying compilation for %s\n", shader_path);
            
            // Wait before retry
            if (g_error_handler->config.retry_delay_ms > 0) {
                usleep(g_error_handler->config.retry_delay_ms * 1000);
            }
            
            // Attempt recompilation
            int32_t result = hmr_shader_manager_compile_async(shader_path);
            success = (result == HMR_SUCCESS);
            break;
        }
        
        case HMR_RECOVERY_DISABLE: {
            printf("HMR Shader Error: Disabling shader %s temporarily\n", shader_path);
            // Implementation would mark shader as disabled
            success = true;
            break;
        }
        
        case HMR_RECOVERY_PARTIAL_COMPILE: {
            printf("HMR Shader Error: Attempting partial compilation for %s\n", shader_path);
            // Implementation would try to compile simplified version
            success = false; // Not implemented yet
            break;
        }
        
        default:
            success = false;
            break;
    }
    
    // Notify callback
    if (success && g_error_handler->on_recovery_success) {
        g_error_handler->on_recovery_success(shader_path, strategy);
        g_error_handler->auto_recoveries++;
    } else if (!success && g_error_handler->on_recovery_failed) {
        g_error_handler->on_recovery_failed(shader_path, strategy);
    }
    
    return success;
}

// Initialize shader error handler
int32_t hmr_shader_error_handler_init(const hmr_shader_error_config_t* config) {
    if (g_error_handler) {
        return HMR_ERROR_ALREADY_EXISTS;
    }
    
    if (!config) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    g_error_handler = calloc(1, sizeof(hmr_shader_error_handler_t));
    if (!g_error_handler) {
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    // Copy configuration
    memcpy(&g_error_handler->config, config, sizeof(hmr_shader_error_config_t));
    
    printf("HMR Shader Error Handler: Initialized successfully\n");
    printf("  Detailed parsing: %s\n", config->enable_detailed_parsing ? "Yes" : "No");
    printf("  Auto recovery: %s\n", config->enable_auto_recovery ? "Yes" : "No");
    printf("  Error logging: %s\n", config->enable_error_logging ? "Yes" : "No");
    printf("  Max retries: %u\n", config->max_retry_attempts);
    
    return HMR_SUCCESS;
}

// Handle shader compilation error
int32_t hmr_shader_error_handle(const char* shader_path, const char* error_message) {
    if (!g_error_handler || !shader_path || !error_message) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    g_error_handler->total_errors++;
    
    printf("HMR Shader Error: Handling error for %s\n", shader_path);
    printf("  Error: %s\n", error_message);
    
    hmr_shader_error_info_t error_info;
    
    // Parse error details if enabled
    if (g_error_handler->config.enable_detailed_parsing) {
        if (hmr_parse_metal_error(error_message, &error_info)) {
            printf("  Parsed: %s:%u:%u [%s] %s\n",
                   error_info.file_path,
                   error_info.line_number,
                   error_info.column_number,
                   error_info.error_code,
                   error_info.message);
            
            // Log error if enabled
            hmr_log_error(&error_info);
            
            // Notify callback
            if (g_error_handler->on_error_parsed) {
                g_error_handler->on_error_parsed(&error_info);
            }
        } else {
            // Fallback to basic error info
            strncpy(error_info.file_path, shader_path, sizeof(error_info.file_path) - 1);
            strncpy(error_info.message, error_message, sizeof(error_info.message) - 1);
            error_info.severity = HMR_SHADER_ERROR_ERROR;
        }
    } else {
        // Basic error info
        strncpy(error_info.file_path, shader_path, sizeof(error_info.file_path) - 1);
        strncpy(error_info.message, error_message, sizeof(error_info.message) - 1);
        error_info.severity = HMR_SHADER_ERROR_ERROR;
    }
    
    // Attempt automatic recovery if enabled
    if (g_error_handler->config.enable_auto_recovery) {
        hmr_shader_recovery_strategy_t strategy = hmr_determine_recovery_strategy(&error_info);
        
        if (strategy != HMR_RECOVERY_NONE) {
            printf("HMR Shader Error: Attempting recovery strategy: %d\n", strategy);
            hmr_execute_recovery_strategy(shader_path, strategy);
        }
    }
    
    return HMR_SUCCESS;
}

// Set error handler callbacks
void hmr_shader_error_handler_set_callbacks(
    void (*on_error_parsed)(const hmr_shader_error_info_t* error_info),
    void (*on_recovery_attempted)(const char* path, hmr_shader_recovery_strategy_t strategy),
    void (*on_recovery_success)(const char* path, hmr_shader_recovery_strategy_t strategy),
    void (*on_recovery_failed)(const char* path, hmr_shader_recovery_strategy_t strategy)
) {
    if (!g_error_handler) return;
    
    g_error_handler->on_error_parsed = on_error_parsed;
    g_error_handler->on_recovery_attempted = on_recovery_attempted;
    g_error_handler->on_recovery_success = on_recovery_success;
    g_error_handler->on_recovery_failed = on_recovery_failed;
}

// Get error handler statistics
void hmr_shader_error_handler_get_stats(
    uint64_t* total_errors,
    uint64_t* auto_recoveries,
    uint64_t* fallback_activations
) {
    if (!g_error_handler) return;
    
    if (total_errors) {
        *total_errors = g_error_handler->total_errors;
    }
    
    if (auto_recoveries) {
        *auto_recoveries = g_error_handler->auto_recoveries;
    }
    
    if (fallback_activations) {
        *fallback_activations = g_error_handler->fallback_activations;
    }
}

// Cleanup error handler
void hmr_shader_error_handler_cleanup(void) {
    if (!g_error_handler) return;
    
    // Close error log file
    if (g_error_handler->error_log_file) {
        fclose(g_error_handler->error_log_file);
        g_error_handler->error_log_file = NULL;
    }
    
    free(g_error_handler);
    g_error_handler = NULL;
    
    printf("HMR Shader Error Handler: Cleanup complete\n");
}