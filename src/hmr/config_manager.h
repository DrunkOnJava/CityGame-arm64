/*
 * SimCity ARM64 - Configuration Manager Header
 * JSON Configuration Hot-Reload Interface
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Day 4: Configuration Live-Editing Interface
 */

#ifndef HMR_CONFIG_MANAGER_H
#define HMR_CONFIG_MANAGER_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

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

// Configuration value data union
typedef union {
    char* string_value;
    int64_t integer_value;
    double float_value;
    bool boolean_value;
} hmr_config_value_data_t;

// Configuration value structure
typedef struct hmr_config_value {
    char key[64];
    hmr_config_type_t type;
    hmr_config_value_data_t data;
    struct hmr_config_value* children;
    uint32_t child_count;
    uint32_t child_capacity;
    bool is_required;
    bool has_default;
    hmr_config_value_data_t default_value;
} hmr_config_value_t;

// Configuration manager configuration
typedef struct {
    char config_directory[256];
    char schema_directory[256];
    bool enable_hot_reload;
    bool enable_validation;
    bool enable_rollback;
    bool enable_type_coercion;
    uint32_t max_config_files;
    uint32_t max_nesting_depth;
    uint32_t rollback_history_size;
} hmr_config_manager_config_t;

// Configuration manager API functions
int32_t hmr_config_manager_init(const hmr_config_manager_config_t* config);
int32_t hmr_config_manager_register(const char* file_path, const char* config_id);
int32_t hmr_config_manager_hot_reload(const char* config_id);

// Configuration access
const hmr_config_value_t* hmr_config_manager_get_value(const char* config_id, const char* key_path);

// Callback registration
void hmr_config_manager_set_callbacks(
    void (*on_config_changed)(const char* config_id, const char* key_path, const hmr_config_value_t* value),
    void (*on_config_error)(const char* config_id, const char* error_message),
    void (*on_validation_failed)(const char* config_id, const char* key_path, const char* error),
    void (*on_rollback_performed)(const char* config_id, const char* reason)
);

// Statistics and monitoring
void hmr_config_manager_get_stats(
    uint32_t* total_configs,
    uint64_t* total_reloads,
    uint64_t* parse_failures,
    uint64_t* validation_failures,
    uint64_t* avg_parse_time,
    uint64_t* rollbacks_performed
);

// Cleanup
void hmr_config_manager_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif // HMR_CONFIG_MANAGER_H