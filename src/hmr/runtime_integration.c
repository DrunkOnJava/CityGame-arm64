/*
 * SimCity ARM64 - HMR Runtime Integration Implementation  
 * Agent 3: Runtime Integration - Day 1 Implementation
 * 
 * Main loop integration with frame-time budget management
 * Module reload detection via timestamps with <0.1ms overhead
 * HMR enable/disable controls with atomic state management
 * 
 * Performance Requirements:
 * - Hot-reload latency: <50ms
 * - Frame time impact: <0.1ms
 * - No FPS drops during reload
 * - Zero crashes during module swapping
 */

#include "runtime_integration.h"
#include <string.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <stdatomic.h>
#include <unistd.h>

// =============================================================================
// Constants and Configuration
// =============================================================================

#define HMR_RT_MAX_FRAME_BUDGET_NS     100000ULL    // 0.1ms budget per frame
#define HMR_RT_CHECK_INTERVAL_FRAMES   60           // Check every 60 frames (1 second at 60 FPS)
#define HMR_RT_MAX_CONCURRENT_LOADS    4            // Maximum concurrent module loads
#define HMR_RT_MODULE_WATCH_DIRS       8            // Maximum watch directories
#define HMR_RT_FRAME_TIME_HISTORY      120          // 2 seconds of frame history at 60 FPS

// =============================================================================
// Internal State Structures
// =============================================================================

// Frame timing statistics (cache-aligned)
typedef struct __attribute__((aligned(64))) {
    uint64_t frame_start_time;          // Current frame start timestamp
    uint64_t frame_end_time;            // Current frame end timestamp  
    uint64_t hmr_check_time;            // Time spent on HMR checks this frame
    uint64_t frame_budget_ns;           // Frame time budget in nanoseconds
    uint32_t frame_number;              // Current frame counter
    uint32_t checks_this_frame;         // Number of HMR checks performed
    
    // Frame time history for adaptive budgeting
    uint64_t frame_times[HMR_RT_FRAME_TIME_HISTORY];
    uint32_t history_index;             // Current index in circular buffer
    uint64_t avg_frame_time;            // Rolling average frame time
    uint64_t peak_frame_time;           // Peak frame time in recent history
} hmr_rt_frame_timing_t;

// Module watch entry
typedef struct {
    char module_path[256];              // Path to module file
    char watch_dir[256];                // Directory being watched
    uint64_t last_mtime;                // Last modification time
    uint32_t module_id;                 // Associated module ID
    bool active;                        // Whether this watch is active
    void* file_handle;                  // Platform-specific file handle
} hmr_rt_module_watch_t;

// HMR Runtime Manager state (main structure)
typedef struct {
    // State control (atomic)
    _Atomic bool enabled;               // Whether HMR is enabled
    _Atomic bool paused;                // Whether HMR is temporarily paused
    _Atomic uint32_t state_lock;        // State change lock (0=unlocked, 1=locked)
    _Atomic uint32_t reload_in_progress; // Number of reloads in progress
    
    // Frame timing
    hmr_rt_frame_timing_t timing;       // Frame timing statistics
    
    // Module watching
    hmr_rt_module_watch_t watches[HMR_RT_MODULE_WATCH_DIRS];
    uint32_t active_watches;            // Number of active watches
    
    // Reload queue (lock-free)
    _Atomic uint32_t reload_queue_head;
    _Atomic uint32_t reload_queue_tail;
    char reload_queue[32][256];         // Queue of modules to reload
    
    // Statistics
    uint64_t total_checks;              // Total HMR checks performed
    uint64_t total_reloads;             // Total reloads performed
    uint64_t total_time_in_hmr;         // Total time spent in HMR operations
    uint32_t failed_reloads;            // Number of failed reload attempts
    
    // Configuration
    uint32_t check_interval_frames;     // How often to check for changes
    uint64_t max_frame_budget_ns;       // Maximum frame time budget
    bool adaptive_budgeting;            // Whether to use adaptive budgeting
    
    // Threading support
    pthread_mutex_t watch_mutex;        // Mutex for watch operations
    pthread_t watch_thread;             // Background file watching thread
    bool watch_thread_running;          // Whether watch thread is active
    
} hmr_rt_manager_state_t;

// =============================================================================
// Global State
// =============================================================================

static hmr_rt_manager_state_t g_hmr_rt_manager = {0};
static mach_timebase_info_data_t g_timebase_info = {0};
static bool g_manager_initialized = false;

// =============================================================================
// Utility Functions
// =============================================================================

// Get high-resolution timestamp in nanoseconds
static inline uint64_t hmr_rt_get_timestamp_ns(void) {
    uint64_t absolute_time = mach_absolute_time();
    return (absolute_time * g_timebase_info.numer) / g_timebase_info.denom;
}

// Update frame timing statistics
static void hmr_rt_update_frame_timing(hmr_rt_frame_timing_t* timing, uint64_t frame_start, uint64_t frame_end) {
    timing->frame_start_time = frame_start;
    timing->frame_end_time = frame_end;
    timing->frame_number++;
    
    uint64_t frame_time = frame_end - frame_start;
    
    // Update circular buffer
    timing->frame_times[timing->history_index] = frame_time;
    timing->history_index = (timing->history_index + 1) % HMR_RT_FRAME_TIME_HISTORY;
    
    // Calculate rolling average
    uint64_t total = 0;
    uint64_t peak = 0;
    for (int i = 0; i < HMR_RT_FRAME_TIME_HISTORY; i++) {
        total += timing->frame_times[i];
        if (timing->frame_times[i] > peak) {
            peak = timing->frame_times[i];
        }
    }
    
    timing->avg_frame_time = total / HMR_RT_FRAME_TIME_HISTORY;
    timing->peak_frame_time = peak;
    
    // Adaptive budgeting: reduce budget if frame times are high
    if (g_hmr_rt_manager.adaptive_budgeting) {
        if (timing->avg_frame_time > 16000000ULL) { // > 16ms (60 FPS threshold)
            timing->frame_budget_ns = HMR_RT_MAX_FRAME_BUDGET_NS / 2; // Reduce budget
        } else {
            timing->frame_budget_ns = HMR_RT_MAX_FRAME_BUDGET_NS;
        }
    }
}

// Get file modification time
static uint64_t hmr_rt_get_file_mtime(const char* path) {
    struct stat st;
    if (stat(path, &st) != 0) {
        return 0;
    }
    return (uint64_t)st.st_mtime * 1000000000ULL + (uint64_t)st.st_mtimespec.tv_nsec;
}

// Lock-free queue operations
static bool hmr_rt_enqueue_reload(const char* module_path) {
    uint32_t head = atomic_load(&g_hmr_rt_manager.reload_queue_head);
    uint32_t next_head = (head + 1) % 32;
    
    if (next_head == atomic_load(&g_hmr_rt_manager.reload_queue_tail)) {
        return false; // Queue full
    }
    
    strncpy(g_hmr_rt_manager.reload_queue[head], module_path, 255);
    g_hmr_rt_manager.reload_queue[head][255] = '\0';
    
    atomic_store(&g_hmr_rt_manager.reload_queue_head, next_head);
    return true;
}

static bool hmr_rt_dequeue_reload(char* module_path, size_t path_size) {
    uint32_t tail = atomic_load(&g_hmr_rt_manager.reload_queue_tail);
    
    if (tail == atomic_load(&g_hmr_rt_manager.reload_queue_head)) {
        return false; // Queue empty
    }
    
    strncpy(module_path, g_hmr_rt_manager.reload_queue[tail], path_size - 1);
    module_path[path_size - 1] = '\0';
    
    atomic_store(&g_hmr_rt_manager.reload_queue_tail, (tail + 1) % 32);
    return true;
}

// =============================================================================
// File Watching Thread
// =============================================================================

static void* hmr_rt_watch_thread_function(void* arg) {
    (void)arg;
    
    while (g_hmr_rt_manager.watch_thread_running) {
        pthread_mutex_lock(&g_hmr_rt_manager.watch_mutex);
        
        // Check all active watches
        for (uint32_t i = 0; i < HMR_RT_MODULE_WATCH_DIRS; i++) {
            hmr_rt_module_watch_t* watch = &g_hmr_rt_manager.watches[i];
            if (!watch->active) continue;
            
            uint64_t current_mtime = hmr_rt_get_file_mtime(watch->module_path);
            if (current_mtime > watch->last_mtime) {
                // File has been modified, queue for reload
                if (hmr_rt_enqueue_reload(watch->module_path)) {
                    watch->last_mtime = current_mtime;
                }
            }
        }
        
        pthread_mutex_unlock(&g_hmr_rt_manager.watch_mutex);
        
        // Sleep for 100ms before next check
        usleep(100000);
    }
    
    return NULL;
}

// =============================================================================
// Public Interface Implementation
// =============================================================================

int hmr_rt_init(void) {
    if (g_manager_initialized) {
        return HMR_RT_SUCCESS;
    }
    
    // Initialize Mach timebase info
    if (mach_timebase_info(&g_timebase_info) != KERN_SUCCESS) {
        return HMR_RT_ERROR_RUNTIME_SAFETY;
    }
    
    // Initialize state
    memset(&g_hmr_rt_manager, 0, sizeof(g_hmr_rt_manager));
    
    // Set initial configuration
    atomic_store(&g_hmr_rt_manager.enabled, true);
    atomic_store(&g_hmr_rt_manager.paused, false);
    atomic_store(&g_hmr_rt_manager.state_lock, 0);
    atomic_store(&g_hmr_rt_manager.reload_in_progress, 0);
    
    g_hmr_rt_manager.timing.frame_budget_ns = HMR_RT_MAX_FRAME_BUDGET_NS;
    g_hmr_rt_manager.check_interval_frames = HMR_RT_CHECK_INTERVAL_FRAMES;
    g_hmr_rt_manager.max_frame_budget_ns = HMR_RT_MAX_FRAME_BUDGET_NS;
    g_hmr_rt_manager.adaptive_budgeting = true;
    
    // Initialize threading
    if (pthread_mutex_init(&g_hmr_rt_manager.watch_mutex, NULL) != 0) {
        return HMR_RT_ERROR_THREADING;
    }
    
    // Start file watching thread
    g_hmr_rt_manager.watch_thread_running = true;
    if (pthread_create(&g_hmr_rt_manager.watch_thread, NULL, hmr_rt_watch_thread_function, NULL) != 0) {
        pthread_mutex_destroy(&g_hmr_rt_manager.watch_mutex);
        return HMR_RT_ERROR_THREADING;
    }
    
    g_manager_initialized = true;
    return HMR_RT_SUCCESS;
}

int hmr_rt_shutdown(void) {
    if (!g_manager_initialized) {
        return HMR_RT_SUCCESS;
    }
    
    // Stop file watching thread
    g_hmr_rt_manager.watch_thread_running = false;
    pthread_join(g_hmr_rt_manager.watch_thread, NULL);
    pthread_mutex_destroy(&g_hmr_rt_manager.watch_mutex);
    
    // Clear all watches
    for (uint32_t i = 0; i < HMR_RT_MODULE_WATCH_DIRS; i++) {
        g_hmr_rt_manager.watches[i].active = false;
    }
    
    g_manager_initialized = false;
    return HMR_RT_SUCCESS;
}

void hmr_rt_frame_start(uint32_t frame_number) {
    if (!g_manager_initialized || !atomic_load(&g_hmr_rt_manager.enabled)) {
        return;
    }
    
    uint64_t timestamp = hmr_rt_get_timestamp_ns();
    
    // Update previous frame timing if this isn't the first frame
    if (g_hmr_rt_manager.timing.frame_number > 0) {
        hmr_rt_update_frame_timing(&g_hmr_rt_manager.timing, 
                                   g_hmr_rt_manager.timing.frame_start_time, 
                                   timestamp);
    }
    
    // Set the frame number directly
    g_hmr_rt_manager.timing.frame_number = frame_number;
    
    // Initialize this frame
    g_hmr_rt_manager.timing.frame_start_time = timestamp;
    g_hmr_rt_manager.timing.hmr_check_time = 0;
    g_hmr_rt_manager.timing.checks_this_frame = 0;
}

void hmr_rt_frame_end(void) {
    if (!atomic_load(&g_hmr_rt_manager.enabled)) {
        return;
    }
    
    g_hmr_rt_manager.timing.frame_end_time = hmr_rt_get_timestamp_ns();
}

int hmr_rt_check_reloads(void) {
    if (!atomic_load(&g_hmr_rt_manager.enabled) || atomic_load(&g_hmr_rt_manager.paused)) {
        return HMR_RT_SUCCESS;
    }
    
    uint64_t check_start = hmr_rt_get_timestamp_ns();
    
    // Check frame budget
    if (g_hmr_rt_manager.timing.hmr_check_time >= g_hmr_rt_manager.timing.frame_budget_ns) {
        return HMR_RT_ERROR_BUDGET_EXCEEDED;
    }
    
    // Only check every N frames to reduce overhead
    if (g_hmr_rt_manager.timing.frame_number % g_hmr_rt_manager.check_interval_frames != 0) {
        return HMR_RT_SUCCESS;
    }
    
    // Process reload queue
    char module_path[256];
    int reloads_processed = 0;
    const int max_reloads_per_frame = 1; // Process at most 1 reload per frame
    
    while (reloads_processed < max_reloads_per_frame && 
           hmr_rt_dequeue_reload(module_path, sizeof(module_path))) {
        
        // Check budget before processing reload
        uint64_t elapsed = hmr_rt_get_timestamp_ns() - check_start;
        if (elapsed >= g_hmr_rt_manager.timing.frame_budget_ns) {
            // Re-queue this module for next frame
            hmr_rt_enqueue_reload(module_path);
            break;
        }
        
        // Trigger module reload (this will be implemented in hot_swap.s)
        // For now, we just log the event
        atomic_fetch_add(&g_hmr_rt_manager.reload_in_progress, 1);
        
        // TODO: Call actual reload function
        // int result = hmr_execute_module_reload(module_path);
        
        atomic_fetch_sub(&g_hmr_rt_manager.reload_in_progress, 1);
        reloads_processed++;
        g_hmr_rt_manager.total_reloads++;
    }
    
    // Update timing statistics
    uint64_t check_end = hmr_rt_get_timestamp_ns();
    uint64_t check_duration = check_end - check_start;
    
    g_hmr_rt_manager.timing.hmr_check_time += check_duration;
    g_hmr_rt_manager.timing.checks_this_frame++;
    g_hmr_rt_manager.total_checks++;
    g_hmr_rt_manager.total_time_in_hmr += check_duration;
    
    return HMR_RT_SUCCESS;
}

int hmr_rt_add_watch(const char* module_path, const char* watch_dir) {
    if (!module_path || !watch_dir) {
        return HMR_RT_ERROR_NULL_POINTER;
    }
    
    pthread_mutex_lock(&g_hmr_rt_manager.watch_mutex);
    
    // Find free watch slot
    uint32_t slot = UINT32_MAX;
    for (uint32_t i = 0; i < HMR_RT_MODULE_WATCH_DIRS; i++) {
        if (!g_hmr_rt_manager.watches[i].active) {
            slot = i;
            break;
        }
    }
    
    if (slot == UINT32_MAX) {
        pthread_mutex_unlock(&g_hmr_rt_manager.watch_mutex);
        return HMR_RT_ERROR_OUT_OF_MEMORY;
    }
    
    // Initialize watch entry
    hmr_rt_module_watch_t* watch = &g_hmr_rt_manager.watches[slot];
    strncpy(watch->module_path, module_path, sizeof(watch->module_path) - 1);
    strncpy(watch->watch_dir, watch_dir, sizeof(watch->watch_dir) - 1);
    watch->module_path[sizeof(watch->module_path) - 1] = '\0';
    watch->watch_dir[sizeof(watch->watch_dir) - 1] = '\0';
    
    watch->last_mtime = hmr_rt_get_file_mtime(module_path);
    watch->module_id = slot; // Use slot as module ID for now
    watch->active = true;
    
    g_hmr_rt_manager.active_watches++;
    
    pthread_mutex_unlock(&g_hmr_rt_manager.watch_mutex);
    return HMR_RT_SUCCESS;
}

int hmr_rt_remove_watch(const char* module_path) {
    if (!module_path) {
        return HMR_RT_ERROR_NULL_POINTER;
    }
    
    pthread_mutex_lock(&g_hmr_rt_manager.watch_mutex);
    
    // Find and remove watch
    bool found = false;
    for (uint32_t i = 0; i < HMR_RT_MODULE_WATCH_DIRS; i++) {
        if (g_hmr_rt_manager.watches[i].active && 
            strcmp(g_hmr_rt_manager.watches[i].module_path, module_path) == 0) {
            g_hmr_rt_manager.watches[i].active = false;
            g_hmr_rt_manager.active_watches--;
            found = true;
            break;
        }
    }
    
    pthread_mutex_unlock(&g_hmr_rt_manager.watch_mutex);
    return found ? HMR_RT_SUCCESS : HMR_RT_ERROR_NOT_FOUND;
}

bool hmr_rt_is_enabled(void) {
    if (!g_manager_initialized) {
        return false;
    }
    return atomic_load(&g_hmr_rt_manager.enabled);
}

void hmr_rt_set_enabled(bool enabled) {
    atomic_store(&g_hmr_rt_manager.enabled, enabled);
}

bool hmr_rt_is_paused(void) {
    return atomic_load(&g_hmr_rt_manager.paused);
}

void hmr_rt_set_paused(bool paused) {
    atomic_store(&g_hmr_rt_manager.paused, paused);
}

void hmr_rt_get_metrics(hmr_rt_metrics_t* metrics) {
    if (!metrics) return;
    
    metrics->total_checks = g_hmr_rt_manager.total_checks;
    metrics->total_reloads = g_hmr_rt_manager.total_reloads;
    metrics->failed_reloads = g_hmr_rt_manager.failed_reloads;
    metrics->active_watches = g_hmr_rt_manager.active_watches;
    metrics->reload_in_progress = atomic_load(&g_hmr_rt_manager.reload_in_progress);
    
    metrics->avg_frame_time_ns = g_hmr_rt_manager.timing.avg_frame_time;
    metrics->peak_frame_time_ns = g_hmr_rt_manager.timing.peak_frame_time;
    metrics->hmr_overhead_ns = g_hmr_rt_manager.total_time_in_hmr;
    metrics->frame_budget_ns = g_hmr_rt_manager.timing.frame_budget_ns;
    
    metrics->current_frame = g_hmr_rt_manager.timing.frame_number;
    metrics->checks_this_frame = g_hmr_rt_manager.timing.checks_this_frame;
}

int hmr_rt_set_config(const hmr_rt_config_t* config) {
    if (!config) {
        return HMR_RT_ERROR_NULL_POINTER;
    }
    
    // Validate configuration
    if (config->check_interval_frames == 0 || config->max_frame_budget_ns == 0) {
        return HMR_RT_ERROR_INVALID_ARG;
    }
    
    g_hmr_rt_manager.check_interval_frames = config->check_interval_frames;
    g_hmr_rt_manager.max_frame_budget_ns = config->max_frame_budget_ns;
    g_hmr_rt_manager.timing.frame_budget_ns = config->max_frame_budget_ns;
    g_hmr_rt_manager.adaptive_budgeting = config->adaptive_budgeting;
    
    return HMR_RT_SUCCESS;
}

void hmr_rt_get_config(hmr_rt_config_t* config) {
    if (!config) return;
    
    config->check_interval_frames = g_hmr_rt_manager.check_interval_frames;
    config->max_frame_budget_ns = g_hmr_rt_manager.max_frame_budget_ns;
    config->adaptive_budgeting = g_hmr_rt_manager.adaptive_budgeting;
}