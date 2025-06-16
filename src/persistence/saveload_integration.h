// SimCity ARM64 Save/Load Integration System Header
// Sub-Agent 8: Save/Load Integration Specialist
// Unified interface for complete save/load system integration

#ifndef SAVELOAD_INTEGRATION_H
#define SAVELOAD_INTEGRATION_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

// Include component headers
#include "save_load.h"
#include "ecs_serialization.h"
#include "autosave_integration.h"

#ifdef __cplusplus
extern "C" {
#endif

//==============================================================================
// Integration System Constants
//==============================================================================

#define SAVELOAD_INTEGRATION_VERSION_MAJOR  1
#define SAVELOAD_INTEGRATION_VERSION_MINOR  0
#define SAVELOAD_INTEGRATION_VERSION_PATCH  0

// Performance targets
#define TARGET_SAVE_SPEED_MBPS              50      // 50 MB/s save target
#define TARGET_LOAD_SPEED_MBPS              80      // 80 MB/s load target
#define TARGET_COMPRESSION_RATIO_X1000      3000    // 3.0x compression ratio
#define TARGET_ECS_ENTITIES_PER_SEC         50000   // 50K entities/sec

// Integration flags
#define INTEGRATION_ENABLE_ECS_SERIALIZATION    0x00000001
#define INTEGRATION_ENABLE_AUTOSAVE            0x00000002
#define INTEGRATION_ENABLE_COMPRESSION         0x00000004
#define INTEGRATION_ENABLE_VERSIONING          0x00000008
#define INTEGRATION_ENABLE_PERFORMANCE_MONITORING 0x00000010
#define INTEGRATION_ENABLE_EVENT_INTEGRATION   0x00000020

//==============================================================================
// Error Codes
//==============================================================================

typedef enum {
    SAVELOAD_INTEGRATION_SUCCESS = 0,
    SAVELOAD_INTEGRATION_ERROR_NOT_INITIALIZED = -1,
    SAVELOAD_INTEGRATION_ERROR_COMPONENT_INIT_FAILED = -2,
    SAVELOAD_INTEGRATION_ERROR_EVENT_REGISTRATION_FAILED = -3,
    SAVELOAD_INTEGRATION_ERROR_PERFORMANCE_TARGET_NOT_MET = -4,
    SAVELOAD_INTEGRATION_ERROR_MODULE_NOT_AVAILABLE = -5,
    SAVELOAD_INTEGRATION_ERROR_VALIDATION_FAILED = -6
} SaveLoadIntegrationErrorCode;

//==============================================================================
// Integration Status and Monitoring
//==============================================================================

typedef struct {
    // Component status
    bool save_load_initialized;
    bool ecs_serialization_initialized;
    bool autosave_initialized;
    bool compression_initialized;
    bool versioning_initialized;
    bool event_integration_active;
    
    // Performance metrics
    uint64_t total_saves_performed;
    uint64_t total_loads_performed;
    uint64_t total_autosaves_performed;
    double avg_save_speed_mbps;
    double avg_load_speed_mbps;
    double avg_compression_ratio;
    
    // System health
    uint32_t active_save_operations;
    uint32_t pending_autosaves;
    uint64_t total_memory_usage;
    uint32_t failed_operations;
    
    // Integration metrics
    uint64_t ecs_entities_serialized;
    uint64_t event_triggered_saves;
    uint32_t version_migrations_performed;
    uint32_t performance_tests_passed;
} SaveLoadIntegrationStatus;

//==============================================================================
// Core Integration API
//==============================================================================

/**
 * Initialize complete save/load integration system
 * @param save_directory Directory for save files
 * @param autosave_directory Directory for autosave files
 * @param integration_flags Bitmask of features to enable
 * @param config Optional configuration structure (NULL for defaults)
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int saveload_integration_init(const char* save_directory, 
                             const char* autosave_directory,
                             uint32_t integration_flags,
                             void* config);

/**
 * Shutdown and cleanup complete save/load integration system
 */
void saveload_integration_shutdown(void);

/**
 * Get integration system status and health information
 * @param status_output Pointer to status structure
 */
void get_saveload_integration_status(SaveLoadIntegrationStatus* status_output);

/**
 * Validate integration system health and performance
 * @return SAVELOAD_INTEGRATION_SUCCESS if healthy, error code if issues found
 */
int validate_saveload_integration_health(void);

//==============================================================================
// Unified Save/Load Operations
//==============================================================================

/**
 * Perform complete game save with all integrated systems
 * @param save_name Name for the save file
 * @param save_flags Configuration flags for save operation
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int unified_save_game(const char* save_name, uint32_t save_flags);

/**
 * Perform complete game load with all integrated systems
 * @param save_name Name of save file to load
 * @param load_flags Configuration flags for load operation
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int unified_load_game(const char* save_name, uint32_t load_flags);

/**
 * Save specific game systems incrementally
 * @param system_mask Bitmask of systems to save
 * @param save_name Base name for save files
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int save_game_systems(uint64_t system_mask, const char* save_name);

/**
 * Load specific game systems incrementally
 * @param system_mask Bitmask of systems to load
 * @param save_name Base name of save files
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int load_game_systems(uint64_t system_mask, const char* save_name);

//==============================================================================
// Performance Monitoring and Optimization
//==============================================================================

/**
 * Run comprehensive performance tests on save/load system
 * @param test_flags Configuration for performance tests
 * @return Number of failed tests (0 = all tests passed)
 */
int run_saveload_performance_tests(uint32_t test_flags);

/**
 * Get real-time performance metrics
 * @param metrics_output Buffer for performance data
 * @param buffer_size Size of metrics buffer
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int get_saveload_performance_metrics(void* metrics_output, size_t buffer_size);

/**
 * Optimize save/load system based on current usage patterns
 * @param optimization_flags Flags controlling optimization behavior
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int optimize_saveload_system(uint32_t optimization_flags);

/**
 * Set performance targets for save/load operations
 * @param save_speed_mbps Target save speed in MB/s
 * @param load_speed_mbps Target load speed in MB/s
 * @param compression_ratio_x1000 Target compression ratio * 1000
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int set_saveload_performance_targets(uint32_t save_speed_mbps, 
                                    uint32_t load_speed_mbps,
                                    uint32_t compression_ratio_x1000);

//==============================================================================
// Event System Integration
//==============================================================================

/**
 * Register save/load system with event bus
 * @param event_bus_handle Handle to event bus system
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int register_saveload_with_event_bus(void* event_bus_handle);

/**
 * Configure which events trigger autosave operations
 * @param event_type_mask Bitmask of event types
 * @param priority_threshold Minimum event priority to trigger save
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int configure_saveload_event_triggers(uint32_t event_type_mask, 
                                     uint32_t priority_threshold);

/**
 * Post save/load completion events to event bus
 * @param operation_type Type of operation completed
 * @param operation_data Data about the completed operation
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int post_saveload_completion_event(uint32_t operation_type, void* operation_data);

//==============================================================================
// Module Integration Management
//==============================================================================

/**
 * Register simulation module with save/load system
 * @param module_name Name of the module
 * @param save_handler Function to save module state
 * @param load_handler Function to load module state
 * @param module_data Module-specific data
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int register_simulation_module(const char* module_name,
                              int (*save_handler)(void*, size_t, void*),
                              int (*load_handler)(void*, size_t, void*),
                              void* module_data);

/**
 * Unregister simulation module from save/load system
 * @param module_name Name of the module to unregister
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int unregister_simulation_module(const char* module_name);

/**
 * Check if specific module is integrated with save/load system
 * @param module_name Name of the module to check
 * @return true if integrated, false otherwise
 */
bool is_module_integrated(const char* module_name);

/**
 * Get list of integrated modules
 * @param module_list Buffer to store module names
 * @param max_modules Maximum number of modules to list
 * @param actual_module_count Pointer to store actual number of modules
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int list_integrated_modules(char module_list[][64], uint32_t max_modules,
                           uint32_t* actual_module_count);

//==============================================================================
// Configuration and Tuning
//==============================================================================

/**
 * Configure save/load system parameters
 * @param parameter_name Name of parameter to configure
 * @param parameter_value New value for parameter
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int configure_saveload_parameter(const char* parameter_name, uint64_t parameter_value);

/**
 * Get current configuration parameter value
 * @param parameter_name Name of parameter to query
 * @param parameter_value Pointer to store parameter value
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int get_saveload_parameter(const char* parameter_name, uint64_t* parameter_value);

/**
 * Reset save/load system to default configuration
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int reset_saveload_configuration(void);

/**
 * Save current configuration to file
 * @param config_filename Name of configuration file
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int save_saveload_configuration(const char* config_filename);

/**
 * Load configuration from file
 * @param config_filename Name of configuration file
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int load_saveload_configuration(const char* config_filename);

//==============================================================================
// Debugging and Diagnostics
//==============================================================================

/**
 * Enable debug logging for save/load operations
 * @param log_level Debug log level (0=off, 1=errors, 2=warnings, 3=info, 4=verbose)
 * @param log_filename Optional log file (NULL for console output)
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int enable_saveload_debug_logging(int log_level, const char* log_filename);

/**
 * Generate diagnostic report for save/load system
 * @param report_filename Name of file to write report
 * @param report_flags Flags controlling report content
 * @return SAVELOAD_INTEGRATION_SUCCESS on success, error code on failure
 */
int generate_saveload_diagnostic_report(const char* report_filename, uint32_t report_flags);

/**
 * Validate save file integrity and structure
 * @param save_filename Name of save file to validate
 * @param validation_flags Flags controlling validation depth
 * @return SAVELOAD_INTEGRATION_SUCCESS if valid, error code if issues found
 */
int validate_save_file(const char* save_filename, uint32_t validation_flags);

/**
 * Run integration system self-tests
 * @param test_flags Flags controlling which tests to run
 * @return Number of failed tests (0 = all tests passed)
 */
int run_saveload_integration_tests(uint32_t test_flags);

//==============================================================================
// Utility Functions
//==============================================================================

/**
 * Get human-readable error message for integration error code
 * @param error_code Error code from integration operation
 * @return Pointer to error message string
 */
const char* get_saveload_integration_error_message(SaveLoadIntegrationErrorCode error_code);

/**
 * Get integration system version information
 * @param major_version Pointer to store major version
 * @param minor_version Pointer to store minor version
 * @param patch_version Pointer to store patch version
 */
void get_saveload_integration_version(uint32_t* major_version, 
                                     uint32_t* minor_version,
                                     uint32_t* patch_version);

/**
 * Check if integration system is properly initialized
 * @return true if initialized, false otherwise
 */
bool is_saveload_integration_initialized(void);

/**
 * Get total memory usage of integrated save/load system
 * @return Memory usage in bytes
 */
size_t get_saveload_integration_memory_usage(void);

/**
 * Force garbage collection of save/load system resources
 * @return Amount of memory freed in bytes
 */
size_t saveload_integration_garbage_collect(void);

#ifdef __cplusplus
}
#endif

#endif // SAVELOAD_INTEGRATION_H