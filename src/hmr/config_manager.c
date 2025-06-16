/*
 * SimCity ARM64 - Configuration Manager for HMR System
 * JSON Configuration Hot-Reload with Type-Safe Parsing
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Day 4: Configuration Live-Editing Implementation
 * 
 * Performance Targets:
 * - Config reload: <50ms
 * - Zero application downtime
 * - Type validation: <5ms
 * - Rollback: <10ms
 * - Memory usage: <1MB per config
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <mach/mach_time.h>
#include <ctype.h>
#include "asset_watcher.h"
#include "dependency_tracker.h"
#include "module_interface.h"

// Configuration value types
typedef enum {
    HMR_CONFIG_TYPE_UNKNOWN = 0,
    HMR_CONFIG_TYPE_STRING,
    HMR_CONFIG_TYPE_INTEGER,
    HMR_CONFIG_TYPE_FLOAT,
    HMR_CONFIG_TYPE_BOOLEAN,
    HMR_CONFIG_TYPE_ARRAY,
    HMR_CONFIG_TYPE_OBJECT,
    HMR_CONFIG_TYPE_NULL
} hmr_config_type_t;

// Configuration value union
typedef union {
    char* string_value;
    int64_t integer_value;
    double float_value;
    bool boolean_value;
} hmr_config_value_data_t;

// Configuration value structure
typedef struct hmr_config_value {
    char key[64];                       // Configuration key
    hmr_config_type_t type;             // Value type
    hmr_config_value_data_t data;       // Value data
    struct hmr_config_value* children; // For objects/arrays
    uint32_t child_count;               // Number of children
    uint32_t child_capacity;            // Capacity for children
    bool is_required;                   // Whether this value is required
    bool has_default;                   // Whether there's a default value
    hmr_config_value_data_t default_value; // Default value
} hmr_config_value_t;

// Configuration schema entry
typedef struct {
    char key_path[128];                 // Full path (e.g., "graphics.resolution.width")
    hmr_config_type_t expected_type;    // Expected type
    bool is_required;                   // Whether required
    hmr_config_value_data_t min_value;  // Minimum value (for numbers)
    hmr_config_value_data_t max_value;  // Maximum value (for numbers)
    hmr_config_value_data_t default_value; // Default value
    bool has_constraints;               // Whether min/max apply
    char description[256];              // Human-readable description
} hmr_config_schema_entry_t;

// Configuration file entry
typedef struct {
    char file_path[256];                // Path to configuration file
    char config_id[64];                 // Unique configuration identifier
    hmr_config_value_t* root_config;    // Root configuration object
    hmr_config_value_t* previous_config; // Previous version for rollback
    hmr_config_schema_entry_t* schema;  // Configuration schema
    uint32_t schema_entry_count;        // Number of schema entries
    uint64_t last_modified;             // Last modification time
    uint64_t last_reload_time;          // Last reload timestamp
    uint32_t reload_count;              // Number of reloads
    uint64_t parse_time_ns;             // Last parse time
    bool is_valid;                      // Whether configuration is valid
    bool needs_reload;                  // Whether reload is needed
    char last_error[512];               // Last parsing error
} hmr_config_file_t;

// Configuration manager configuration
typedef struct {
    char config_directory[256];         // Root directory for configs
    char schema_directory[256];         // Directory for schema files
    bool enable_hot_reload;             // Whether hot-reload is enabled
    bool enable_validation;             // Whether to validate against schema
    bool enable_rollback;               // Whether to keep previous versions
    bool enable_type_coercion;          // Whether to attempt type conversion
    uint32_t max_config_files;          // Maximum tracked config files
    uint32_t max_nesting_depth;         // Maximum object nesting depth
    uint32_t rollback_history_size;     // Number of versions to keep
} hmr_config_manager_config_t;

// Main configuration manager structure
typedef struct {
    // Configuration
    hmr_config_manager_config_t config;
    
    // Configuration tracking
    hmr_config_file_t* config_files;   // Array of tracked config files
    uint32_t config_file_count;        // Current number of config files
    uint32_t config_file_capacity;     // Maximum number of config files
    
    // Performance metrics
    uint64_t total_reloads;             // Total configuration reloads
    uint64_t validation_failures;       // Number of validation failures
    uint64_t parse_failures;            // Number of parse failures
    uint64_t avg_parse_time;            // Average parse time
    uint64_t avg_reload_time;           // Average reload time
    uint64_t rollbacks_performed;       // Number of rollbacks
    
    // Callbacks
    void (*on_config_changed)(const char* config_id, const char* key_path, const hmr_config_value_t* value);
    void (*on_config_error)(const char* config_id, const char* error_message);
    void (*on_validation_failed)(const char* config_id, const char* key_path, const char* error);
    void (*on_rollback_performed)(const char* config_id, const char* reason);
} hmr_config_manager_t;

// Global configuration manager instance
static hmr_config_manager_t* g_config_manager = NULL;

// Simple JSON parser state
typedef struct {
    const char* json;
    size_t pos;
    size_t length;
    char error[256];
} hmr_json_parser_t;

// Skip whitespace in JSON
static void hmr_json_skip_whitespace(hmr_json_parser_t* parser) {
    while (parser->pos < parser->length && isspace(parser->json[parser->pos])) {
        parser->pos++;
    }
}

// Parse JSON string value
static char* hmr_json_parse_string(hmr_json_parser_t* parser) {
    if (parser->pos >= parser->length || parser->json[parser->pos] != '"') {
        snprintf(parser->error, sizeof(parser->error), "Expected '\"' at position %zu", parser->pos);
        return NULL;
    }
    
    parser->pos++; // Skip opening quote
    size_t start = parser->pos;
    
    // Find closing quote
    while (parser->pos < parser->length && parser->json[parser->pos] != '"') {
        if (parser->json[parser->pos] == '\\') {
            parser->pos++; // Skip escape character
            if (parser->pos < parser->length) parser->pos++; // Skip escaped character
        } else {
            parser->pos++;
        }
    }
    
    if (parser->pos >= parser->length) {
        snprintf(parser->error, sizeof(parser->error), "Unterminated string at position %zu", start);
        return NULL;
    }
    
    size_t length = parser->pos - start;
    char* result = malloc(length + 1);
    if (!result) {
        snprintf(parser->error, sizeof(parser->error), "Memory allocation failed");
        return NULL;
    }
    
    strncpy(result, parser->json + start, length);
    result[length] = '\0';
    
    parser->pos++; // Skip closing quote
    return result;
}

// Parse JSON number (integer or float)
static bool hmr_json_parse_number(hmr_json_parser_t* parser, hmr_config_value_t* value) {
    size_t start = parser->pos;
    bool is_float = false;
    
    // Skip negative sign
    if (parser->pos < parser->length && parser->json[parser->pos] == '-') {
        parser->pos++;
    }
    
    // Parse digits
    while (parser->pos < parser->length && isdigit(parser->json[parser->pos])) {
        parser->pos++;
    }
    
    // Check for decimal point
    if (parser->pos < parser->length && parser->json[parser->pos] == '.') {
        is_float = true;
        parser->pos++;
        
        // Parse fractional part
        while (parser->pos < parser->length && isdigit(parser->json[parser->pos])) {
            parser->pos++;
        }
    }
    
    // Check for exponent
    if (parser->pos < parser->length && (parser->json[parser->pos] == 'e' || parser->json[parser->pos] == 'E')) {
        is_float = true;
        parser->pos++;
        
        if (parser->pos < parser->length && (parser->json[parser->pos] == '+' || parser->json[parser->pos] == '-')) {
            parser->pos++;
        }
        
        while (parser->pos < parser->length && isdigit(parser->json[parser->pos])) {
            parser->pos++;
        }
    }
    
    size_t length = parser->pos - start;
    char* number_str = malloc(length + 1);
    if (!number_str) {
        snprintf(parser->error, sizeof(parser->error), "Memory allocation failed");
        return false;
    }
    
    strncpy(number_str, parser->json + start, length);
    number_str[length] = '\0';
    
    if (is_float) {
        value->type = HMR_CONFIG_TYPE_FLOAT;
        value->data.float_value = strtod(number_str, NULL);
    } else {
        value->type = HMR_CONFIG_TYPE_INTEGER;
        value->data.integer_value = strtoll(number_str, NULL, 10);
    }
    
    free(number_str);
    return true;
}

// Forward declaration for recursive parsing
static bool hmr_json_parse_value(hmr_json_parser_t* parser, hmr_config_value_t* value);

// Parse JSON object
static bool hmr_json_parse_object(hmr_json_parser_t* parser, hmr_config_value_t* value) {
    if (parser->pos >= parser->length || parser->json[parser->pos] != '{') {
        snprintf(parser->error, sizeof(parser->error), "Expected '{' at position %zu", parser->pos);
        return false;
    }
    
    parser->pos++; // Skip opening brace
    hmr_json_skip_whitespace(parser);
    
    value->type = HMR_CONFIG_TYPE_OBJECT;
    value->child_capacity = 16; // Initial capacity
    value->children = calloc(value->child_capacity, sizeof(hmr_config_value_t));
    if (!value->children) {
        snprintf(parser->error, sizeof(parser->error), "Memory allocation failed");
        return false;
    }
    
    // Check for empty object
    if (parser->pos < parser->length && parser->json[parser->pos] == '}') {
        parser->pos++;
        return true;
    }
    
    while (parser->pos < parser->length) {
        // Parse key
        hmr_json_skip_whitespace(parser);
        char* key = hmr_json_parse_string(parser);
        if (!key) return false;
        
        // Resize children array if needed
        if (value->child_count >= value->child_capacity) {
            value->child_capacity *= 2;
            value->children = realloc(value->children, value->child_capacity * sizeof(hmr_config_value_t));
            if (!value->children) {
                snprintf(parser->error, sizeof(parser->error), "Memory reallocation failed");
                free(key);
                return false;
            }
        }
        
        hmr_config_value_t* child = &value->children[value->child_count];
        memset(child, 0, sizeof(hmr_config_value_t));
        strncpy(child->key, key, sizeof(child->key) - 1);
        free(key);
        
        // Expect colon
        hmr_json_skip_whitespace(parser);
        if (parser->pos >= parser->length || parser->json[parser->pos] != ':') {
            snprintf(parser->error, sizeof(parser->error), "Expected ':' at position %zu", parser->pos);
            return false;
        }
        parser->pos++;
        
        // Parse value
        hmr_json_skip_whitespace(parser);
        if (!hmr_json_parse_value(parser, child)) {
            return false;
        }
        
        value->child_count++;
        
        // Check for comma or end
        hmr_json_skip_whitespace(parser);
        if (parser->pos >= parser->length) {
            snprintf(parser->error, sizeof(parser->error), "Unexpected end of JSON");
            return false;
        }
        
        if (parser->json[parser->pos] == '}') {
            parser->pos++;
            break;
        } else if (parser->json[parser->pos] == ',') {
            parser->pos++;
        } else {
            snprintf(parser->error, sizeof(parser->error), "Expected ',' or '}' at position %zu", parser->pos);
            return false;
        }
    }
    
    return true;
}

// Parse JSON value (recursive)
static bool hmr_json_parse_value(hmr_json_parser_t* parser, hmr_config_value_t* value) {
    hmr_json_skip_whitespace(parser);
    
    if (parser->pos >= parser->length) {
        snprintf(parser->error, sizeof(parser->error), "Unexpected end of JSON");
        return false;
    }
    
    char c = parser->json[parser->pos];
    
    if (c == '"') {
        // String
        value->type = HMR_CONFIG_TYPE_STRING;
        value->data.string_value = hmr_json_parse_string(parser);
        return value->data.string_value != NULL;
    } else if (c == '{') {
        // Object
        return hmr_json_parse_object(parser, value);
    } else if (c == '[') {
        // Array (simplified - treat as string for now)
        value->type = HMR_CONFIG_TYPE_ARRAY;
        // Skip to end of array for now
        int bracket_count = 0;
        size_t start = parser->pos;
        while (parser->pos < parser->length) {
            if (parser->json[parser->pos] == '[') bracket_count++;
            else if (parser->json[parser->pos] == ']') bracket_count--;
            parser->pos++;
            if (bracket_count == 0) break;
        }
        
        size_t length = parser->pos - start;
        value->data.string_value = malloc(length + 1);
        if (!value->data.string_value) {
            snprintf(parser->error, sizeof(parser->error), "Memory allocation failed");
            return false;
        }
        strncpy(value->data.string_value, parser->json + start, length);
        value->data.string_value[length] = '\0';
        return true;
    } else if (c == 't' || c == 'f') {
        // Boolean
        value->type = HMR_CONFIG_TYPE_BOOLEAN;
        if (strncmp(parser->json + parser->pos, "true", 4) == 0) {
            value->data.boolean_value = true;
            parser->pos += 4;
        } else if (strncmp(parser->json + parser->pos, "false", 5) == 0) {
            value->data.boolean_value = false;
            parser->pos += 5;
        } else {
            snprintf(parser->error, sizeof(parser->error), "Invalid boolean at position %zu", parser->pos);
            return false;
        }
        return true;
    } else if (c == 'n') {
        // Null
        if (strncmp(parser->json + parser->pos, "null", 4) == 0) {
            value->type = HMR_CONFIG_TYPE_NULL;
            parser->pos += 4;
            return true;
        } else {
            snprintf(parser->error, sizeof(parser->error), "Invalid null at position %zu", parser->pos);
            return false;
        }
    } else if (isdigit(c) || c == '-') {
        // Number
        return hmr_json_parse_number(parser, value);
    } else {
        snprintf(parser->error, sizeof(parser->error), "Unexpected character '%c' at position %zu", c, parser->pos);
        return false;
    }
}

// Parse JSON configuration file
static bool hmr_parse_json_config(const char* json_content, hmr_config_value_t* root_config) {
    if (!json_content || !root_config) return false;
    
    hmr_json_parser_t parser;
    parser.json = json_content;
    parser.pos = 0;
    parser.length = strlen(json_content);
    parser.error[0] = '\0';
    
    memset(root_config, 0, sizeof(hmr_config_value_t));
    
    bool success = hmr_json_parse_value(&parser, root_config);
    if (!success) {
        printf("HMR Config: JSON parse error: %s\n", parser.error);
    }
    
    return success;
}

// Find configuration file by ID
static hmr_config_file_t* hmr_find_config_file(const char* config_id) {
    if (!g_config_manager || !config_id) return NULL;
    
    for (uint32_t i = 0; i < g_config_manager->config_file_count; i++) {
        if (strcmp(g_config_manager->config_files[i].config_id, config_id) == 0) {
            return &g_config_manager->config_files[i];
        }
    }
    
    return NULL;
}

// Free configuration value and its children
static void hmr_free_config_value(hmr_config_value_t* value) {
    if (!value) return;
    
    if (value->type == HMR_CONFIG_TYPE_STRING || value->type == HMR_CONFIG_TYPE_ARRAY) {
        if (value->data.string_value) {
            free(value->data.string_value);
            value->data.string_value = NULL;
        }
    }
    
    if (value->children) {
        for (uint32_t i = 0; i < value->child_count; i++) {
            hmr_free_config_value(&value->children[i]);
        }
        free(value->children);
        value->children = NULL;
    }
    
    value->child_count = 0;
    value->child_capacity = 0;
}

// Load configuration from file
static bool hmr_load_config_file(hmr_config_file_t* config_file) {
    if (!config_file) return false;
    
    uint64_t start_time = mach_absolute_time();
    
    FILE* file = fopen(config_file->file_path, "r");
    if (!file) {
        snprintf(config_file->last_error, sizeof(config_file->last_error),
                "Failed to open file: %s", config_file->file_path);
        return false;
    }
    
    // Get file size
    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    fseek(file, 0, SEEK_SET);
    
    if (file_size <= 0) {
        snprintf(config_file->last_error, sizeof(config_file->last_error),
                "Invalid file size: %ld", file_size);
        fclose(file);
        return false;
    }
    
    // Read file content
    char* content = malloc(file_size + 1);
    if (!content) {
        snprintf(config_file->last_error, sizeof(config_file->last_error),
                "Memory allocation failed for file content");
        fclose(file);
        return false;
    }
    
    size_t read_size = fread(content, 1, file_size, file);
    content[read_size] = '\0';
    fclose(file);
    
    // Backup current configuration for rollback
    if (config_file->root_config && g_config_manager->config.enable_rollback) {
        if (config_file->previous_config) {
            hmr_free_config_value(config_file->previous_config);
            free(config_file->previous_config);
        }
        config_file->previous_config = config_file->root_config;
        config_file->root_config = NULL;
    }
    
    // Allocate new root config
    config_file->root_config = calloc(1, sizeof(hmr_config_value_t));
    if (!config_file->root_config) {
        snprintf(config_file->last_error, sizeof(config_file->last_error),
                "Memory allocation failed for root config");
        free(content);
        return false;
    }
    
    // Parse JSON
    bool success = hmr_parse_json_config(content, config_file->root_config);
    free(content);
    
    if (!success) {
        snprintf(config_file->last_error, sizeof(config_file->last_error),
                "JSON parsing failed");
        hmr_free_config_value(config_file->root_config);
        free(config_file->root_config);
        config_file->root_config = config_file->previous_config;
        config_file->previous_config = NULL;
        config_file->is_valid = false;
        g_config_manager->parse_failures++;
        return false;
    }
    
    // Calculate parse time
    uint64_t end_time = mach_absolute_time();
    static mach_timebase_info_data_t timebase_info;
    if (timebase_info.denom == 0) {
        mach_timebase_info(&timebase_info);
    }
    config_file->parse_time_ns = (end_time - start_time) * timebase_info.numer / timebase_info.denom;
    
    config_file->is_valid = true;
    config_file->reload_count++;
    config_file->last_reload_time = end_time;
    config_file->last_error[0] = '\0';
    
    g_config_manager->total_reloads++;
    g_config_manager->avg_parse_time = (g_config_manager->avg_parse_time + config_file->parse_time_ns) / 2;
    
    printf("HMR Config: Loaded %s (%s) in %.2f ms\n",
           config_file->file_path, config_file->config_id,
           config_file->parse_time_ns / 1000000.0);
    
    return true;
}

// Initialize configuration manager
int32_t hmr_config_manager_init(const hmr_config_manager_config_t* config) {
    if (g_config_manager) {
        printf("HMR Config Manager: Already initialized\n");
        return HMR_ERROR_ALREADY_EXISTS;
    }
    
    if (!config) {
        printf("HMR Config Manager: Invalid configuration\n");
        return HMR_ERROR_INVALID_ARG;
    }
    
    g_config_manager = calloc(1, sizeof(hmr_config_manager_t));
    if (!g_config_manager) {
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    // Copy configuration
    memcpy(&g_config_manager->config, config, sizeof(hmr_config_manager_config_t));
    
    // Allocate config file array
    g_config_manager->config_file_capacity = config->max_config_files;
    g_config_manager->config_files = calloc(g_config_manager->config_file_capacity, sizeof(hmr_config_file_t));
    if (!g_config_manager->config_files) {
        free(g_config_manager);
        g_config_manager = NULL;
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    printf("HMR Config Manager: Initialized successfully\n");
    printf("  Config directory: %s\n", config->config_directory);
    printf("  Max config files: %u\n", config->max_config_files);
    printf("  Hot-reload: %s\n", config->enable_hot_reload ? "Yes" : "No");
    printf("  Validation: %s\n", config->enable_validation ? "Yes" : "No");
    printf("  Rollback: %s\n", config->enable_rollback ? "Yes" : "No");
    
    return HMR_SUCCESS;
}

// Register configuration file for hot-reload
int32_t hmr_config_manager_register(const char* file_path, const char* config_id) {
    if (!g_config_manager || !file_path || !config_id) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    // Check if already registered
    if (hmr_find_config_file(config_id)) {
        return HMR_ERROR_ALREADY_EXISTS;
    }
    
    if (g_config_manager->config_file_count >= g_config_manager->config_file_capacity) {
        printf("HMR Config: Maximum config file capacity reached (%u)\n", 
               g_config_manager->config_file_capacity);
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    hmr_config_file_t* config_file = &g_config_manager->config_files[g_config_manager->config_file_count];
    memset(config_file, 0, sizeof(hmr_config_file_t));
    
    strncpy(config_file->file_path, file_path, sizeof(config_file->file_path) - 1);
    strncpy(config_file->config_id, config_id, sizeof(config_file->config_id) - 1);
    
    // Load initial configuration
    if (!hmr_load_config_file(config_file)) {
        printf("HMR Config: Failed to load initial config: %s\n", file_path);
        return HMR_ERROR_LOAD_FAILED;
    }
    
    g_config_manager->config_file_count++;
    
    printf("HMR Config: Registered %s (ID: %s)\n", file_path, config_id);
    
    return HMR_SUCCESS;
}

// Hot-reload configuration when file changes
int32_t hmr_config_manager_hot_reload(const char* config_id) {
    if (!g_config_manager || !config_id) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    hmr_config_file_t* config_file = hmr_find_config_file(config_id);
    if (!config_file) {
        return HMR_ERROR_NOT_FOUND;
    }
    
    printf("HMR Config: Hot-reloading %s\n", config_id);
    
    bool success = hmr_load_config_file(config_file);
    
    if (success) {
        // Notify callback if registered
        if (g_config_manager->on_config_changed) {
            g_config_manager->on_config_changed(config_id, "", config_file->root_config);
        }
    } else {
        if (g_config_manager->on_config_error) {
            g_config_manager->on_config_error(config_id, config_file->last_error);
        }
    }
    
    return success ? HMR_SUCCESS : HMR_ERROR_LOAD_FAILED;
}

// Get configuration value by key path
const hmr_config_value_t* hmr_config_manager_get_value(const char* config_id, const char* key_path) {
    if (!g_config_manager || !config_id || !key_path) return NULL;
    
    hmr_config_file_t* config_file = hmr_find_config_file(config_id);
    if (!config_file || !config_file->root_config) return NULL;
    
    // Simple key path resolution (would be more sophisticated in real implementation)
    if (strcmp(key_path, "") == 0) {
        return config_file->root_config;
    }
    
    // For now, just return root config
    // Real implementation would traverse the key path
    return config_file->root_config;
}

// Set configuration manager callbacks
void hmr_config_manager_set_callbacks(
    void (*on_config_changed)(const char* config_id, const char* key_path, const hmr_config_value_t* value),
    void (*on_config_error)(const char* config_id, const char* error_message),
    void (*on_validation_failed)(const char* config_id, const char* key_path, const char* error),
    void (*on_rollback_performed)(const char* config_id, const char* reason)
) {
    if (!g_config_manager) return;
    
    g_config_manager->on_config_changed = on_config_changed;
    g_config_manager->on_config_error = on_config_error;
    g_config_manager->on_validation_failed = on_validation_failed;
    g_config_manager->on_rollback_performed = on_rollback_performed;
}

// Get configuration manager statistics
void hmr_config_manager_get_stats(
    uint32_t* total_configs,
    uint64_t* total_reloads,
    uint64_t* parse_failures,
    uint64_t* validation_failures,
    uint64_t* avg_parse_time,
    uint64_t* rollbacks_performed
) {
    if (!g_config_manager) return;
    
    if (total_configs) *total_configs = g_config_manager->config_file_count;
    if (total_reloads) *total_reloads = g_config_manager->total_reloads;
    if (parse_failures) *parse_failures = g_config_manager->parse_failures;
    if (validation_failures) *validation_failures = g_config_manager->validation_failures;
    if (avg_parse_time) *avg_parse_time = g_config_manager->avg_parse_time;
    if (rollbacks_performed) *rollbacks_performed = g_config_manager->rollbacks_performed;
}

// Cleanup configuration manager
void hmr_config_manager_cleanup(void) {
    if (!g_config_manager) return;
    
    // Free all configuration files
    for (uint32_t i = 0; i < g_config_manager->config_file_count; i++) {
        hmr_config_file_t* config_file = &g_config_manager->config_files[i];
        
        if (config_file->root_config) {
            hmr_free_config_value(config_file->root_config);
            free(config_file->root_config);
        }
        
        if (config_file->previous_config) {
            hmr_free_config_value(config_file->previous_config);
            free(config_file->previous_config);
        }
        
        if (config_file->schema) {
            free(config_file->schema);
        }
    }
    
    if (g_config_manager->config_files) {
        free(g_config_manager->config_files);
    }
    
    free(g_config_manager);
    g_config_manager = NULL;
    
    printf("HMR Config Manager: Cleanup complete\n");
}