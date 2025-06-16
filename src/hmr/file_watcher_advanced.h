/*
 * SimCity ARM64 - Advanced File Watcher
 * Agent 2: File Watcher & Build Pipeline - Week 2 Day 7
 * 
 * Advanced file watching with batching, debouncing, and intelligent filtering
 * - File change batching and debouncing to prevent build storms
 * - Comprehensive ignore patterns and filtering rules
 * - Watch priority system for critical files
 * - Network file system support for remote development
 */

#ifndef FILE_WATCHER_ADVANCED_H
#define FILE_WATCHER_ADVANCED_H

#include <stdint.h>
#include <stdbool.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

// File watcher constants
#define WATCHER_MAX_PATHS 512
#define WATCHER_MAX_IGNORE_PATTERNS 128
#define WATCHER_MAX_BATCH_SIZE 256
#define WATCHER_MAX_PATH_LENGTH 1024
#define WATCHER_DEBOUNCE_DEFAULT_MS 250
#define WATCHER_BATCH_TIMEOUT_DEFAULT_MS 1000

// File change types
typedef enum {
    FILE_CHANGE_CREATED = 1 << 0,
    FILE_CHANGE_MODIFIED = 1 << 1,
    FILE_CHANGE_DELETED = 1 << 2,
    FILE_CHANGE_RENAMED = 1 << 3,
    FILE_CHANGE_ATTRIBUTE = 1 << 4,
    FILE_CHANGE_ALL = 0xFF
} file_change_type_t;

// File watch priority levels
typedef enum {
    WATCH_PRIORITY_CRITICAL = 0,    // Core source files, build configs
    WATCH_PRIORITY_HIGH,            // Graphics shaders, main modules
    WATCH_PRIORITY_NORMAL,          // Standard source files
    WATCH_PRIORITY_LOW,             // Documentation, comments
    WATCH_PRIORITY_BACKGROUND,      // Logs, temporary files
    WATCH_PRIORITY_IGNORE           // Files to completely ignore
} watch_priority_t;

// File system types
typedef enum {
    FS_TYPE_LOCAL = 0,
    FS_TYPE_NETWORK,
    FS_TYPE_REMOTE,
    FS_TYPE_CLOUD,
    FS_TYPE_UNKNOWN
} fs_type_t;

// File change event
typedef struct {
    char path[WATCHER_MAX_PATH_LENGTH];
    file_change_type_t change_type;
    watch_priority_t priority;
    uint64_t timestamp_ns;
    uint64_t file_size;
    uint32_t batch_id;
    fs_type_t fs_type;
    bool is_directory;
    bool needs_debounce;
} file_change_event_t;

// File change batch
typedef struct {
    uint32_t batch_id;
    uint32_t event_count;
    file_change_event_t events[WATCHER_MAX_BATCH_SIZE];
    uint64_t first_event_time_ns;
    uint64_t last_event_time_ns;
    watch_priority_t highest_priority;
    bool is_ready;
    bool is_processing;
} file_change_batch_t;

// Watch filter rule
typedef struct {
    char pattern[256];              // Glob pattern or regex
    file_change_type_t change_mask; // Which change types to match
    watch_priority_t priority;      // Priority to assign
    bool is_regex;                  // Whether pattern is regex
    bool is_include;                // Include (true) or exclude (false)
    uint32_t debounce_ms;          // Custom debounce time
} watch_filter_rule_t;

// Watch path configuration
typedef struct {
    char path[WATCHER_MAX_PATH_LENGTH];
    file_change_type_t change_mask;
    watch_priority_t default_priority;
    bool recursive;
    bool follow_symlinks;
    uint32_t debounce_ms;
    fs_type_t fs_type;
    uint32_t filter_rule_count;
    watch_filter_rule_t filter_rules[32];
} watch_path_config_t;

// Network file system configuration
typedef struct {
    char mount_point[WATCHER_MAX_PATH_LENGTH];
    char remote_host[256];
    uint32_t polling_interval_ms;   // For NFS/remote systems
    uint32_t connection_timeout_ms;
    bool use_polling;               // Fallback to polling for network FS
    bool cache_enabled;             // Enable local caching
} network_fs_config_t;

// File watcher statistics
typedef struct {
    uint64_t total_events;
    uint64_t batched_events;
    uint64_t debounced_events;
    uint64_t filtered_events;
    uint64_t critical_events;
    uint64_t high_priority_events;
    uint64_t normal_priority_events;
    uint64_t low_priority_events;
    uint64_t ignored_events;
    uint64_t network_events;
    uint32_t active_batches;
    uint32_t completed_batches;
    uint64_t average_batch_size;
    uint64_t average_processing_time_ns;
    uint32_t current_watch_count;
} file_watcher_stats_t;

// File watcher callbacks
typedef struct {
    // Called when a batch of changes is ready
    void (*on_batch_ready)(const file_change_batch_t* batch);
    
    // Called for individual high-priority events that bypass batching
    void (*on_critical_change)(const file_change_event_t* event);
    
    // Called when network file system status changes
    void (*on_network_status)(const char* mount_point, bool connected);
    
    // Called for filter rule matches (debug purposes)
    void (*on_filter_match)(const char* path, const char* pattern, watch_priority_t priority);
    
    // Called for errors
    void (*on_error)(const char* path, const char* error_message);
} file_watcher_callbacks_t;

// Initialize advanced file watcher
int32_t file_watcher_init(const file_watcher_callbacks_t* callbacks);

// Path management
int32_t file_watcher_add_path(const watch_path_config_t* config);
int32_t file_watcher_remove_path(const char* path);
int32_t file_watcher_update_path_config(const char* path, const watch_path_config_t* config);
int32_t file_watcher_get_path_config(const char* path, watch_path_config_t* config);

// Filter management
int32_t file_watcher_add_global_filter(const watch_filter_rule_t* rule);
int32_t file_watcher_remove_global_filter(const char* pattern);
int32_t file_watcher_clear_global_filters(void);
int32_t file_watcher_load_ignore_file(const char* ignore_file_path);

// Batching and debouncing configuration
int32_t file_watcher_set_batch_timeout(uint32_t timeout_ms);
int32_t file_watcher_set_global_debounce(uint32_t debounce_ms);
int32_t file_watcher_set_max_batch_size(uint32_t max_size);
int32_t file_watcher_force_batch_processing(void);

// Priority system
int32_t file_watcher_set_priority_debounce(watch_priority_t priority, uint32_t debounce_ms);
int32_t file_watcher_enable_priority_bypass(watch_priority_t min_priority);
int32_t file_watcher_get_priority_for_path(const char* path, watch_priority_t* priority);

// Network file system support
int32_t file_watcher_add_network_fs(const network_fs_config_t* config);
int32_t file_watcher_remove_network_fs(const char* mount_point);
int32_t file_watcher_check_network_status(const char* mount_point, bool* is_connected);
int32_t file_watcher_refresh_network_fs(const char* mount_point);

// Batch management
int32_t file_watcher_get_pending_batches(uint32_t* batch_count);
int32_t file_watcher_get_batch_info(uint32_t batch_id, file_change_batch_t* batch);
int32_t file_watcher_mark_batch_processed(uint32_t batch_id);
int32_t file_watcher_cancel_batch(uint32_t batch_id);

// Manual file checking
int32_t file_watcher_check_file_changes(const char* path, file_change_event_t* event);
int32_t file_watcher_scan_directory(const char* directory, bool recursive,
                                   file_change_event_t* events, uint32_t max_events,
                                   uint32_t* actual_count);

// Performance optimization
int32_t file_watcher_enable_burst_mode(bool enabled);
int32_t file_watcher_set_polling_interval(uint32_t interval_ms);
int32_t file_watcher_optimize_for_build_system(bool enabled);
int32_t file_watcher_preload_directory_cache(const char* directory);

// Statistics and monitoring
int32_t file_watcher_get_statistics(file_watcher_stats_t* stats);
int32_t file_watcher_reset_statistics(void);
int32_t file_watcher_get_performance_metrics(uint64_t* avg_event_processing_ns,
                                           uint32_t* events_per_second,
                                           uint32_t* memory_usage_kb);

// Control operations
int32_t file_watcher_start(void);
int32_t file_watcher_stop(void);
int32_t file_watcher_pause(void);
int32_t file_watcher_resume(void);
int32_t file_watcher_is_running(bool* is_running);

// Debug and testing
int32_t file_watcher_enable_debug_mode(bool enabled);
int32_t file_watcher_simulate_file_change(const char* path, file_change_type_t change_type);
int32_t file_watcher_dump_filter_rules(char* output, size_t output_size);
int32_t file_watcher_validate_configuration(void);

// Cleanup
void file_watcher_cleanup(void);

// Error codes
#define WATCHER_SUCCESS 0
#define WATCHER_ERROR_NULL_POINTER -1
#define WATCHER_ERROR_OUT_OF_MEMORY -2
#define WATCHER_ERROR_INVALID_ARG -3
#define WATCHER_ERROR_NOT_FOUND -4
#define WATCHER_ERROR_ALREADY_EXISTS -5
#define WATCHER_ERROR_IO_ERROR -6
#define WATCHER_ERROR_PERMISSION_DENIED -7
#define WATCHER_ERROR_NETWORK_ERROR -8
#define WATCHER_ERROR_TIMEOUT -9
#define WATCHER_ERROR_SYSTEM_ERROR -10

#ifdef __cplusplus
}
#endif

#endif // FILE_WATCHER_ADVANCED_H