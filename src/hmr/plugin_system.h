/*
 * SimCity ARM64 - Extensible Plugin System
 * Third-party plugin integration with security and performance monitoring
 * 
 * Agent 4: Developer Tools & Debug Interface
 * Week 3 Day 11: Advanced UI Features & AI Integration
 */

#ifndef HMR_PLUGIN_SYSTEM_H
#define HMR_PLUGIN_SYSTEM_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Plugin Types
typedef enum {
    PLUGIN_TYPE_EDITOR_EXTENSION = 0,
    PLUGIN_TYPE_BUILD_TOOL,
    PLUGIN_TYPE_DEBUGGER_EXTENSION,
    PLUGIN_TYPE_PERFORMANCE_ANALYZER,
    PLUGIN_TYPE_CODE_FORMATTER,
    PLUGIN_TYPE_LANGUAGE_SERVER,
    PLUGIN_TYPE_UI_THEME,
    PLUGIN_TYPE_WORKSPACE_PANEL,
    PLUGIN_TYPE_NOTIFICATION_PROVIDER,
    PLUGIN_TYPE_VERSION_CONTROL,
    PLUGIN_TYPE_DEPLOYMENT_TOOL,
    PLUGIN_TYPE_TESTING_FRAMEWORK,
    PLUGIN_TYPE_DOCUMENTATION_GENERATOR,
    PLUGIN_TYPE_CODE_QUALITY_CHECKER,
    PLUGIN_TYPE_CUSTOM
} plugin_type_t;

// Plugin State
typedef enum {
    PLUGIN_STATE_UNLOADED = 0,
    PLUGIN_STATE_LOADING,
    PLUGIN_STATE_LOADED,
    PLUGIN_STATE_ACTIVE,
    PLUGIN_STATE_INACTIVE,
    PLUGIN_STATE_ERROR,
    PLUGIN_STATE_DISABLED,
    PLUGIN_STATE_UPDATING
} plugin_state_t;

// Plugin Permission System
typedef enum {
    PLUGIN_PERMISSION_READ_FILES = 1 << 0,
    PLUGIN_PERMISSION_WRITE_FILES = 1 << 1,
    PLUGIN_PERMISSION_EXECUTE_COMMANDS = 1 << 2,
    PLUGIN_PERMISSION_NETWORK_ACCESS = 1 << 3,
    PLUGIN_PERMISSION_SYSTEM_INTEGRATION = 1 << 4,
    PLUGIN_PERMISSION_UI_MODIFICATION = 1 << 5,
    PLUGIN_PERMISSION_PERFORMANCE_MONITORING = 1 << 6,
    PLUGIN_PERMISSION_DEBUG_ACCESS = 1 << 7,
    PLUGIN_PERMISSION_BUILD_INTEGRATION = 1 << 8,
    PLUGIN_PERMISSION_WORKSPACE_MODIFICATION = 1 << 9,
    PLUGIN_PERMISSION_USER_DATA_ACCESS = 1 << 10,
    PLUGIN_PERMISSION_ELEVATED_PRIVILEGES = 1 << 11
} plugin_permission_t;

// Plugin Metadata
typedef struct {
    char plugin_id[64];
    char name[128];
    char description[512];
    char version[32];
    char author[128];
    char website[256];
    char license[64];
    plugin_type_t type;
    uint32_t required_permissions;
    char supported_languages[256];
    char supported_platforms[128];
    char dependencies[1024];
    char min_engine_version[32];
    char max_engine_version[32];
    bool is_signed;
    char signature_hash[128];
    uint64_t file_size_bytes;
    uint64_t install_time;
    uint64_t last_update_time;
    bool is_beta;
    bool is_experimental;
    float rating;
    uint32_t download_count;
} plugin_metadata_t;

// Plugin Interface
typedef struct {
    char function_name[64];
    char description[256];
    char parameters[512];
    char return_type[64];
    uint32_t version;
    bool is_required;
    void* function_pointer;
} plugin_interface_function_t;

typedef struct {
    char interface_id[64];
    char interface_name[128];
    char version[16];
    uint32_t function_count;
    plugin_interface_function_t functions[32];
} plugin_interface_t;

// Plugin Configuration
typedef struct {
    char config_key[128];
    char config_value[512];
    char data_type[32];
    char description[256];
    char default_value[512];
    bool is_required;
    bool is_user_configurable;
    bool is_sensitive;
} plugin_config_entry_t;

typedef struct {
    char plugin_id[64];
    uint32_t config_count;
    plugin_config_entry_t configs[64];
    char config_file_path[1024];
    bool is_encrypted;
    uint64_t last_modified;
} plugin_configuration_t;

// Plugin Runtime Information
typedef struct {
    char plugin_id[64];
    plugin_state_t state;
    uint64_t load_time_us;
    uint64_t memory_usage_bytes;
    uint64_t cpu_time_us;
    uint32_t api_call_count;
    uint32_t error_count;
    uint32_t warning_count;
    char last_error[256];
    uint64_t last_activity_time;
    bool is_responsive;
    float performance_score;
} plugin_runtime_info_t;

// Plugin Security Context
typedef struct {
    char plugin_id[64];
    uint32_t granted_permissions;
    uint32_t requested_permissions;
    bool is_sandboxed;
    char sandbox_directory[1024];
    uint32_t file_access_count;
    uint32_t network_request_count;
    uint32_t suspicious_activity_count;
    char security_violations[10][256];
    uint32_t violation_count;
    bool is_trusted;
    char trust_level[32];
} plugin_security_context_t;

// Plugin Event System
typedef enum {
    PLUGIN_EVENT_LOADED = 0,
    PLUGIN_EVENT_UNLOADED,
    PLUGIN_EVENT_ACTIVATED,
    PLUGIN_EVENT_DEACTIVATED,
    PLUGIN_EVENT_ERROR,
    PLUGIN_EVENT_CONFIG_CHANGED,
    PLUGIN_EVENT_PERMISSION_REQUESTED,
    PLUGIN_EVENT_SECURITY_VIOLATION,
    PLUGIN_EVENT_UPDATE_AVAILABLE,
    PLUGIN_EVENT_PERFORMANCE_WARNING
} plugin_event_type_t;

typedef struct {
    plugin_event_type_t event_type;
    char plugin_id[64];
    char event_message[512];
    char event_data[2048];
    uint64_t timestamp_us;
    uint32_t severity_level;
} plugin_event_t;

// Plugin API Functions
typedef struct {
    // Core lifecycle
    int32_t (*plugin_init)(const char* config_path);
    void (*plugin_shutdown)(void);
    int32_t (*plugin_activate)(void);
    int32_t (*plugin_deactivate)(void);
    
    // Configuration
    int32_t (*plugin_get_config)(const char* key, char* value, size_t max_length);
    int32_t (*plugin_set_config)(const char* key, const char* value);
    
    // Event handling
    int32_t (*plugin_handle_event)(const plugin_event_t* event);
    
    // Custom functionality
    int32_t (*plugin_execute_command)(const char* command, const char* args, char* output, size_t max_output_length);
    
    // UI integration
    int32_t (*plugin_render_ui)(const char* container_id, const char* ui_data);
    int32_t (*plugin_handle_ui_event)(const char* event_type, const char* event_data);
    
    // Optional functions
    void* reserved[8];
} plugin_api_t;

// Plugin System Management
int32_t plugin_system_init(const char* plugin_directory, const char* config_directory);
void plugin_system_shutdown(void);

// Plugin Discovery and Installation
int32_t plugin_discover_available(plugin_metadata_t* plugins, uint32_t max_plugins, uint32_t* plugin_count);
int32_t plugin_install(const char* plugin_path, const char* plugin_id);
int32_t plugin_uninstall(const char* plugin_id);
int32_t plugin_update(const char* plugin_id, const char* new_version_path);

// Plugin Lifecycle Management
int32_t plugin_load(const char* plugin_id);
int32_t plugin_unload(const char* plugin_id);
int32_t plugin_activate(const char* plugin_id);
int32_t plugin_deactivate(const char* plugin_id);
int32_t plugin_reload(const char* plugin_id);

// Plugin Information
int32_t plugin_get_metadata(const char* plugin_id, plugin_metadata_t* metadata);
int32_t plugin_get_runtime_info(const char* plugin_id, plugin_runtime_info_t* runtime_info);
int32_t plugin_get_loaded_plugins(char* plugin_ids, uint32_t max_plugins, uint32_t* plugin_count);
int32_t plugin_get_active_plugins(char* plugin_ids, uint32_t max_plugins, uint32_t* plugin_count);

// Plugin Configuration
int32_t plugin_get_configuration(const char* plugin_id, plugin_configuration_t* config);
int32_t plugin_set_configuration(const char* plugin_id, const plugin_configuration_t* config);
int32_t plugin_reset_configuration(const char* plugin_id);

// Plugin Security
int32_t plugin_request_permission(const char* plugin_id, plugin_permission_t permission, const char* reason);
int32_t plugin_grant_permission(const char* plugin_id, plugin_permission_t permission);
int32_t plugin_revoke_permission(const char* plugin_id, plugin_permission_t permission);
int32_t plugin_get_security_context(const char* plugin_id, plugin_security_context_t* context);
int32_t plugin_set_sandbox_mode(const char* plugin_id, bool enabled);

// Plugin Interface Registration
int32_t plugin_register_interface(const char* plugin_id, const plugin_interface_t* interface);
int32_t plugin_unregister_interface(const char* plugin_id, const char* interface_id);
int32_t plugin_get_interface(const char* plugin_id, const char* interface_id, plugin_interface_t* interface);
int32_t plugin_call_interface_function(const char* plugin_id, const char* interface_id, 
                                     const char* function_name, const char* args, char* result, size_t max_result_length);

// Plugin Event System
typedef void (*plugin_event_callback_t)(const plugin_event_t* event, void* user_data);
int32_t plugin_register_event_callback(plugin_event_callback_t callback, void* user_data);
int32_t plugin_unregister_event_callback(plugin_event_callback_t callback);
int32_t plugin_send_event(const plugin_event_t* event);

// Plugin Marketplace Integration
typedef struct {
    char marketplace_url[256];
    char api_key[128];
    char user_id[64];
    bool auto_update_enabled;
    bool beta_updates_enabled;
    uint32_t update_check_interval_hours;
} plugin_marketplace_config_t;

int32_t plugin_marketplace_init(const plugin_marketplace_config_t* config);
int32_t plugin_marketplace_search(const char* query, plugin_metadata_t* results, uint32_t max_results, uint32_t* result_count);
int32_t plugin_marketplace_download(const char* plugin_id, const char* download_path);
int32_t plugin_marketplace_check_updates(char* updated_plugin_ids, uint32_t max_plugins, uint32_t* update_count);

// Plugin Performance Monitoring
typedef struct {
    uint64_t total_load_time_us;
    uint64_t total_execution_time_us;
    uint64_t peak_memory_usage_bytes;
    uint32_t total_api_calls;
    uint32_t total_errors;
    uint32_t total_warnings;
    float average_response_time_ms;
    float cpu_usage_percent;
    uint32_t active_plugin_count;
    uint32_t total_plugin_count;
} plugin_system_stats_t;

void plugin_get_system_stats(plugin_system_stats_t* stats);
int32_t plugin_get_performance_report(char* report_json, size_t max_length);

// Plugin Debugging
int32_t plugin_enable_debug_mode(const char* plugin_id, bool enabled);
int32_t plugin_get_debug_info(const char* plugin_id, char* debug_info, size_t max_length);
int32_t plugin_set_log_level(const char* plugin_id, uint32_t log_level);

// Plugin Hot-Reloading
int32_t plugin_enable_hot_reload(const char* plugin_id, bool enabled);
int32_t plugin_watch_file_changes(const char* plugin_id, const char* file_path);
int32_t plugin_trigger_reload(const char* plugin_id);

// Plugin Dependency Management
typedef struct {
    char dependency_id[64];
    char min_version[32];
    char max_version[32];
    bool is_required;
    bool is_loaded;
} plugin_dependency_t;

int32_t plugin_get_dependencies(const char* plugin_id, plugin_dependency_t* dependencies, 
                               uint32_t max_dependencies, uint32_t* dependency_count);
int32_t plugin_resolve_dependencies(const char* plugin_id);
int32_t plugin_check_compatibility(const char* plugin_id, bool* is_compatible);

#ifdef __cplusplus
}
#endif

#endif // HMR_PLUGIN_SYSTEM_H