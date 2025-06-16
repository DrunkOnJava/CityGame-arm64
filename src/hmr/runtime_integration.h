/*
 * SimCity ARM64 - HMR Runtime Integration Header
 * Agent 3: Runtime Integration - Day 1 Implementation
 * 
 * Public interface for the hot-reload runtime manager
 * Provides frame-time budgeted module reload detection
 * Maintains 60+ FPS performance during hot-reload operations
 */

#ifndef HMR_RUNTIME_INTEGRATION_H
#define HMR_RUNTIME_INTEGRATION_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// =============================================================================
// Error Codes
// =============================================================================

#define HMR_RT_SUCCESS                    0
#define HMR_RT_ERROR_NULL_POINTER        -1
#define HMR_RT_ERROR_INVALID_ARG         -2
#define HMR_RT_ERROR_NOT_FOUND           -3
#define HMR_RT_ERROR_OUT_OF_MEMORY       -9
#define HMR_RT_ERROR_THREADING           -10
#define HMR_RT_ERROR_RUNTIME_SAFETY      0x4004
#define HMR_RT_ERROR_BUDGET_EXCEEDED     0x4010

// =============================================================================
// Configuration Structure
// =============================================================================

typedef struct {
    uint32_t check_interval_frames;     // How often to check for module changes (frames)
    uint64_t max_frame_budget_ns;       // Maximum time budget per frame (nanoseconds)
    bool adaptive_budgeting;            // Whether to adapt budget based on frame timing
} hmr_rt_config_t;

// =============================================================================
// Metrics Structure
// =============================================================================

typedef struct {
    // Reload statistics
    uint64_t total_checks;              // Total HMR checks performed
    uint64_t total_reloads;             // Total reloads performed  
    uint32_t failed_reloads;            // Number of failed reload attempts
    uint32_t active_watches;            // Number of active file watches
    uint32_t reload_in_progress;        // Number of reloads currently in progress
    
    // Performance metrics
    uint64_t avg_frame_time_ns;         // Average frame time
    uint64_t peak_frame_time_ns;        // Peak frame time in recent history
    uint64_t hmr_overhead_ns;           // Total time spent in HMR operations
    uint64_t frame_budget_ns;           // Current frame time budget
    
    // Current state
    uint32_t current_frame;             // Current frame number
    uint32_t checks_this_frame;         // HMR checks performed this frame
} hmr_rt_metrics_t;

// =============================================================================
// Core Interface Functions
// =============================================================================

/**
 * Initialize the HMR runtime manager
 * Sets up file watching, timing systems, and threading
 * 
 * @return HMR_RT_SUCCESS on success, error code on failure
 */
int hmr_rt_init(void);

/**
 * Shutdown the HMR runtime manager
 * Cleans up resources and stops all background threads
 * 
 * @return HMR_RT_SUCCESS on success, error code on failure
 */
int hmr_rt_shutdown(void);

// =============================================================================
// Frame Integration Functions
// =============================================================================

/**
 * Call at the start of each frame
 * Updates frame timing and prepares for HMR checks
 * 
 * @param frame_number Current frame number
 */
void hmr_rt_frame_start(uint32_t frame_number);

/**
 * Call at the end of each frame
 * Finalizes frame timing statistics
 */
void hmr_rt_frame_end(void);

/**
 * Check for pending module reloads within frame budget
 * Should be called once per frame during main loop
 * 
 * @return HMR_RT_SUCCESS if budget maintained, HMR_RT_ERROR_BUDGET_EXCEEDED if over budget
 */
int hmr_rt_check_reloads(void);

// =============================================================================
// Module Watching Functions
// =============================================================================

/**
 * Add a module to the watch list
 * The manager will monitor the module file for changes
 * 
 * @param module_path Path to the module file to watch
 * @param watch_dir Directory containing the module (for optimization)
 * @return HMR_RT_SUCCESS on success, error code on failure
 */
int hmr_rt_add_watch(const char* module_path, const char* watch_dir);

/**
 * Remove a module from the watch list
 * 
 * @param module_path Path to the module file to stop watching
 * @return HMR_RT_SUCCESS on success, HMR_RT_ERROR_NOT_FOUND if not found
 */
int hmr_rt_remove_watch(const char* module_path);

// =============================================================================
// Control Functions
// =============================================================================

/**
 * Check if HMR is currently enabled
 * 
 * @return true if enabled, false if disabled
 */
bool hmr_rt_is_enabled(void);

/**
 * Enable or disable HMR globally
 * When disabled, no module checks or reloads will occur
 * 
 * @param enabled true to enable, false to disable
 */
void hmr_rt_set_enabled(bool enabled);

/**
 * Check if HMR is currently paused
 * 
 * @return true if paused, false if active
 */
bool hmr_rt_is_paused(void);

/**
 * Pause or resume HMR operations
 * When paused, watches continue but reloads are deferred
 * 
 * @param paused true to pause, false to resume
 */
void hmr_rt_set_paused(bool paused);

// =============================================================================
// Configuration and Metrics
// =============================================================================

/**
 * Get current performance metrics
 * 
 * @param metrics Pointer to metrics structure to fill
 */
void hmr_rt_get_metrics(hmr_rt_metrics_t* metrics);

/**
 * Update HMR manager configuration
 * 
 * @param config New configuration settings
 * @return HMR_RT_SUCCESS on success, error code on failure
 */
int hmr_rt_set_config(const hmr_rt_config_t* config);

/**
 * Get current HMR manager configuration
 * 
 * @param config Pointer to configuration structure to fill
 */
void hmr_rt_get_config(hmr_rt_config_t* config);

// =============================================================================
// Integration Helpers
// =============================================================================

/**
 * Convenience macro for main loop integration
 * Usage: HMR_RT_FRAME_SCOPE(frame_number) { ... main loop code ... }
 */
#define HMR_RT_FRAME_SCOPE(frame_num) \
    for (bool _hmr_first = (hmr_rt_frame_start(frame_num), true); \
         _hmr_first; \
         _hmr_first = false, hmr_rt_frame_end())

/**
 * Convenience macro for checking reloads with error handling
 * Usage: HMR_RT_CHECK_RELOADS_OR_CONTINUE();
 */
#define HMR_RT_CHECK_RELOADS_OR_CONTINUE() \
    do { \
        int _hmr_result = hmr_rt_check_reloads(); \
        if (_hmr_result != HMR_RT_SUCCESS && _hmr_result != HMR_RT_ERROR_BUDGET_EXCEEDED) { \
            /* Log error but continue */ \
        } \
    } while(0)

// =============================================================================
// Default Configuration Values
// =============================================================================

#define HMR_RT_DEFAULT_CHECK_INTERVAL      60          // Check every 60 frames (1 sec at 60 FPS)
#define HMR_RT_DEFAULT_FRAME_BUDGET_NS     100000ULL   // 0.1ms budget per frame
#define HMR_RT_DEFAULT_ADAPTIVE_BUDGET     true        // Enable adaptive budgeting

// Convenience initializer for default configuration
#define HMR_RT_DEFAULT_CONFIG() { \
    .check_interval_frames = HMR_RT_DEFAULT_CHECK_INTERVAL, \
    .max_frame_budget_ns = HMR_RT_DEFAULT_FRAME_BUDGET_NS, \
    .adaptive_budgeting = HMR_RT_DEFAULT_ADAPTIVE_BUDGET \
}

#ifdef __cplusplus
}
#endif

#endif // HMR_RUNTIME_INTEGRATION_H