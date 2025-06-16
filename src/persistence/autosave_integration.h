// SimCity ARM64 Autosave Integration Header
// Sub-Agent 8: Save/Load Integration Specialist
// C interface for autosave integration with event bus

#ifndef AUTOSAVE_INTEGRATION_H
#define AUTOSAVE_INTEGRATION_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

//==============================================================================
// Constants and Configuration
//==============================================================================

// Autosave configuration flags
#define AUTOSAVE_ENABLE_BACKGROUND      0x00000001
#define AUTOSAVE_ENABLE_EVENT_TRIGGERS  0x00000002
#define AUTOSAVE_ENABLE_COMPRESSION     0x00000004
#define AUTOSAVE_ENABLE_ROTATION        0x00000008
#define AUTOSAVE_ENABLE_VALIDATION      0x00000010

// Autosave trigger events (matches event_bus.s)
#define EVENT_SIMULATION_MILESTONE      0x00000201
#define EVENT_CITY_GROWTH              0x00000202
#define EVENT_DISASTER_START           0x00000203
#define EVENT_MAJOR_CONSTRUCTION       0x00000204
#define EVENT_ECONOMIC_CHANGE          0x00000205
#define EVENT_USER_REQUEST             0x00000206
#define EVENT_SYSTEM_SHUTDOWN          0x00000207
#define EVENT_AUTOSAVE_COMPLETED       0x00000208
#define EVENT_AUTOSAVE_FAILED          0x00000209

// Default configuration values
#define DEFAULT_AUTOSAVE_INTERVAL_SEC   300     // 5 minutes
#define DEFAULT_MAX_AUTOSAVE_FILES      5       // Keep 5 rotating saves
#define DEFAULT_COMPRESSION_LEVEL       6       // Medium compression

//==============================================================================
// Error Codes
//==============================================================================

typedef enum {
    AUTOSAVE_SUCCESS = 0,
    AUTOSAVE_ERROR_NOT_INITIALIZED = -1,
    AUTOSAVE_ERROR_SAVE_IN_PROGRESS = -2,
    AUTOSAVE_ERROR_EVENT_REGISTRATION_FAILED = -3,
    AUTOSAVE_ERROR_THREAD_START_FAILED = -4,
    AUTOSAVE_ERROR_SAVE_FAILED = -5,
    AUTOSAVE_ERROR_DIRECTORY_CREATION_FAILED = -6,
    AUTOSAVE_ERROR_INVALID_CONFIG = -7
} AutosaveErrorCode;

//==============================================================================
// Statistics and Monitoring
//==============================================================================

typedef struct {
    uint64_t total_autosaves;           // Total autosaves performed
    uint64_t successful_autosaves;      // Successful autosaves
    uint64_t failed_autosaves;          // Failed autosaves
    uint64_t avg_autosave_time_ms;      // Average autosave time in milliseconds
    uint64_t total_autosave_size;       // Total bytes saved via autosave
    uint64_t last_autosave_duration;    // Last autosave duration in nanoseconds
    uint64_t background_saves;          // Background autosaves performed
    uint64_t event_triggered_saves;     // Event-triggered autosaves performed
} AutosaveStats;

typedef struct {
    bool is_enabled;                    // Autosave enabled/disabled
    uint32_t interval_seconds;          // Autosave interval in seconds
    uint32_t max_autosave_files;        // Maximum autosave files to keep
    uint32_t save_on_events;            // Bitmask of events that trigger saves
    bool background_save;               // Background saving enabled
    uint32_t compression_level;         // Compression level (1-9)
} AutosaveConfig;

//==============================================================================
// Core Autosave API
//==============================================================================

/**
 * Initialize autosave system and integrate with event bus
 * @param autosave_directory Directory to store autosave files
 * @param config_flags Configuration flags for autosave behavior
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int autosave_init(const char* autosave_directory, uint32_t config_flags);

/**
 * Shutdown autosave system and cleanup resources
 */
void autosave_shutdown(void);

/**
 * Perform immediate autosave (bypasses scheduling)
 * @param save_flags Save configuration flags
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int perform_autosave(uint32_t save_flags);

/**
 * Event handler for autosave-triggering events (called by event bus)
 * @param event_ptr Pointer to event structure (32 bytes)
 */
void autosave_event_handler(void* event_ptr);

//==============================================================================
// Configuration Management
//==============================================================================

/**
 * Get current autosave configuration
 * @param config_output Pointer to configuration structure
 */
void get_autosave_config(AutosaveConfig* config_output);

/**
 * Update autosave configuration
 * @param new_config Pointer to new configuration
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int set_autosave_config(const AutosaveConfig* new_config);

/**
 * Enable or disable autosave system
 * @param enable true to enable, false to disable
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int set_autosave_enabled(bool enable);

/**
 * Set autosave interval
 * @param interval_seconds Interval between autosaves in seconds (0 = disable)
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int set_autosave_interval(uint32_t interval_seconds);

/**
 * Set maximum number of autosave files to keep
 * @param max_files Maximum autosave files (1-20)
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int set_max_autosave_files(uint32_t max_files);

//==============================================================================
// Event Integration
//==============================================================================

/**
 * Register autosave event handlers with event bus
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int register_autosave_event_handlers(void);

/**
 * Unregister autosave event handlers from event bus
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int unregister_autosave_event_handlers(void);

/**
 * Configure which events should trigger autosave
 * @param event_mask Bitmask of events that should trigger saves
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int set_autosave_event_triggers(uint32_t event_mask);

/**
 * Manually trigger autosave based on specific event
 * @param event_type Type of event triggering the save
 * @param event_subtype Subtype of event
 * @param priority Event priority (0-3)
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int trigger_event_autosave(uint32_t event_type, uint32_t event_subtype, uint32_t priority);

//==============================================================================
// Background Autosave
//==============================================================================

/**
 * Start background autosave thread
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int start_background_autosave_thread(void);

/**
 * Stop background autosave thread
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int stop_background_autosave_thread(void);

/**
 * Check if background autosave thread is running
 * @return true if running, false otherwise
 */
bool is_background_autosave_active(void);

/**
 * Schedule next autosave for specific time
 * @param timestamp_seconds Unix timestamp when to perform next autosave
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int schedule_autosave_at(uint64_t timestamp_seconds);

//==============================================================================
// File Management
//==============================================================================

/**
 * Get list of current autosave files
 * @param file_list Buffer to store list of autosave filenames
 * @param max_files Maximum number of files to list
 * @param actual_file_count Pointer to store actual number of files found
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int list_autosave_files(char file_list[][256], uint32_t max_files, 
                       uint32_t* actual_file_count);

/**
 * Restore from specific autosave file
 * @param autosave_filename Name of autosave file to restore
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int restore_from_autosave(const char* autosave_filename);

/**
 * Delete specific autosave file
 * @param autosave_filename Name of autosave file to delete
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int delete_autosave_file(const char* autosave_filename);

/**
 * Clean up old autosave files (based on max_autosave_files setting)
 * @return Number of files deleted
 */
int cleanup_old_autosaves(void);

//==============================================================================
// Statistics and Monitoring
//==============================================================================

/**
 * Get autosave performance statistics
 * @param stats_output Pointer to statistics structure
 */
void get_autosave_stats(AutosaveStats* stats_output);

/**
 * Reset autosave performance statistics
 */
void reset_autosave_stats(void);

/**
 * Get timestamp of last successful autosave
 * @return Unix timestamp of last autosave (0 if none)
 */
uint64_t get_last_autosave_timestamp(void);

/**
 * Get timestamp of next scheduled autosave
 * @return Unix timestamp of next autosave (0 if none scheduled)
 */
uint64_t get_next_autosave_timestamp(void);

/**
 * Check if autosave is currently in progress
 * @return true if save in progress, false otherwise
 */
bool is_autosave_in_progress(void);

//==============================================================================
// Testing and Debugging
//==============================================================================

/**
 * Run comprehensive autosave system tests
 * @return Number of failed tests (0 = all tests passed)
 */
int run_autosave_tests(void);

/**
 * Force autosave for testing purposes (ignores normal conditions)
 * @param test_filename Filename for test autosave
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int force_test_autosave(const char* test_filename);

/**
 * Simulate autosave-triggering event for testing
 * @param event_type Event type to simulate
 * @param event_subtype Event subtype to simulate
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int simulate_autosave_event(uint32_t event_type, uint32_t event_subtype);

//==============================================================================
// Performance Optimization
//==============================================================================

/**
 * Enable/disable autosave compression
 * @param enable true to enable compression
 * @param compression_level Compression level (1-9, 1=fastest, 9=best)
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int set_autosave_compression(bool enable, int compression_level);

/**
 * Set autosave priority for background thread
 * @param priority Thread priority (0=low, 1=normal, 2=high)
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int set_autosave_thread_priority(int priority);

/**
 * Configure autosave memory usage limits
 * @param max_memory_bytes Maximum memory for autosave operations
 * @return AUTOSAVE_SUCCESS on success, error code on failure
 */
int set_autosave_memory_limit(size_t max_memory_bytes);

//==============================================================================
// Integration Status
//==============================================================================

/**
 * Check if autosave system is properly initialized
 * @return true if initialized, false otherwise
 */
bool is_autosave_initialized(void);

/**
 * Get autosave system health status
 * @return 0 = healthy, positive = warnings, negative = errors
 */
int get_autosave_health_status(void);

/**
 * Validate autosave system integration with other modules
 * @return AUTOSAVE_SUCCESS if all integrations working, error code otherwise
 */
int validate_autosave_integrations(void);

//==============================================================================
// Utility Functions
//==============================================================================

/**
 * Get human-readable error message for autosave error code
 * @param error_code Error code from autosave operation
 * @return Pointer to error message string
 */
const char* get_autosave_error_message(AutosaveErrorCode error_code);

/**
 * Get current memory usage of autosave system
 * @return Memory usage in bytes
 */
size_t get_autosave_memory_usage(void);

/**
 * Convert autosave timestamp to human-readable string
 * @param timestamp Unix timestamp
 * @param buffer Buffer to store formatted string
 * @param buffer_size Size of buffer
 * @return Pointer to formatted string
 */
const char* format_autosave_timestamp(uint64_t timestamp, char* buffer, size_t buffer_size);

#ifdef __cplusplus
}
#endif

#endif // AUTOSAVE_INTEGRATION_H