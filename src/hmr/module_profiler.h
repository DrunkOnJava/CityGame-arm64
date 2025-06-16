/*
 * SimCity ARM64 - Module Profiling Integration System
 * Integration with Agent 4's performance dashboard for real-time monitoring
 * 
 * Created by Agent 1: Core Module System
 * Week 3, Day 13 - Development Productivity Enhancement
 */

#ifndef HMR_MODULE_PROFILER_H
#define HMR_MODULE_PROFILER_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <pthread.h>
#include <mach/mach_time.h>

// Forward declarations
typedef struct hmr_agent_module hmr_agent_module_t;
typedef struct hmr_debug_context hmr_debug_context_t;

// Profiling configuration
#define PROFILER_MAX_MODULES            256
#define PROFILER_MAX_FUNCTIONS          2048
#define PROFILER_MAX_SAMPLES            100000
#define PROFILER_MAX_CALL_STACK_DEPTH   128
#define PROFILER_SAMPLE_INTERVAL_US     1000    // 1ms default sampling
#define PROFILER_DASHBOARD_UPDATE_MS    100     // 100ms dashboard updates

// Profiling modes
typedef enum {
    PROFILE_MODE_NONE = 0,
    PROFILE_MODE_SAMPLING,              // Statistical sampling profiler
    PROFILE_MODE_INSTRUMENTATION,       // Function instrumentation
    PROFILE_MODE_CALL_GRAPH,            // Call graph generation
    PROFILE_MODE_MEMORY,                // Memory allocation profiling
    PROFILE_MODE_CACHE,                 // Cache performance profiling
    PROFILE_MODE_THERMAL,               // Thermal profiling
    PROFILE_MODE_POWER,                 // Power consumption profiling
    PROFILE_MODE_COMPREHENSIVE          // All profiling modes
} profiler_mode_t;

// Performance metrics types
typedef enum {
    METRIC_EXECUTION_TIME = 0,
    METRIC_CPU_CYCLES,
    METRIC_CACHE_MISSES,
    METRIC_BRANCH_MISSES,
    METRIC_MEMORY_BANDWIDTH,
    METRIC_POWER_CONSUMPTION,
    METRIC_THERMAL_STATE,
    METRIC_FUNCTION_CALLS,
    METRIC_MEMORY_ALLOCATIONS,
    METRIC_NEON_UTILIZATION,
    METRIC_APPLE_AMX_USAGE,
    METRIC_NEURAL_ENGINE_USAGE,
    METRIC_COUNT
} performance_metric_type_t;

// Function profiling data
typedef struct {
    void* function_address;             // Function start address
    char function_name[128];            // Function name (if available)
    hmr_agent_module_t* module;         // Module containing this function
    uint64_t call_count;                // Number of calls
    uint64_t total_time_ns;             // Total execution time
    uint64_t min_time_ns;               // Minimum execution time
    uint64_t max_time_ns;               // Maximum execution time
    uint64_t avg_time_ns;               // Average execution time
    uint64_t total_cycles;              // Total CPU cycles
    uint64_t cache_misses;              // Cache misses
    uint64_t branch_misses;             // Branch mispredictions
    uint64_t memory_accesses;           // Memory access count
    uint64_t neon_operations;           // NEON SIMD operations
    float cpu_utilization;              // CPU utilization percentage
    float hotness_score;                // Computed hotness score
    bool is_hot_function;               // Whether function is hot
    uint32_t optimization_level;        // Applied optimization level
} function_profile_data_t;

// Module profiling data
typedef struct {
    hmr_agent_module_t* module;         // Module reference
    char module_name[64];               // Module name
    uint64_t total_execution_time_ns;   // Total module execution time
    uint64_t load_time_ns;              // Module load time
    uint64_t init_time_ns;              // Module initialization time
    uint32_t function_count;            // Number of functions
    function_profile_data_t* functions; // Function profiles
    uint64_t memory_usage_bytes;        // Current memory usage
    uint64_t peak_memory_bytes;         // Peak memory usage
    uint32_t allocation_count;          // Number of allocations
    uint32_t deallocation_count;        // Number of deallocations
    float cpu_usage_percent;            // CPU usage percentage
    float memory_fragmentation;         // Memory fragmentation ratio
    uint32_t cache_hit_rate;            // Cache hit rate percentage
    bool is_critical_path;              // Whether on critical performance path
} module_profile_data_t;

// Sample data for statistical profiling
typedef struct {
    uint64_t timestamp_ns;              // Sample timestamp
    void* pc;                           // Program counter
    void* sp;                           // Stack pointer
    hmr_agent_module_t* module;         // Module at PC
    uint32_t thread_id;                 // Thread ID
    uint32_t core_id;                   // CPU core ID
    uint32_t process_id;                // Process ID
    uint64_t instruction_count;         // Instructions since last sample
    uint64_t cycle_count;               // Cycles since last sample
    uint32_t cache_references;          // Cache references
    uint32_t cache_misses;              // Cache misses
    uint32_t branch_instructions;       // Branch instructions
    uint32_t branch_misses;             // Branch misses
    float cpu_frequency_mhz;            // Current CPU frequency
    float temperature_celsius;          // CPU temperature
    float power_watts;                  // Power consumption
} profile_sample_t;

// Call stack frame for call graph profiling
typedef struct {
    void* function_address;             // Function address
    char function_name[64];             // Function name
    hmr_agent_module_t* module;         // Module
    uint64_t entry_timestamp;           // Function entry time
    uint64_t accumulated_time;          // Accumulated time in this frame
    uint32_t call_count;                // Number of calls to this function
} call_stack_frame_t;

// Dashboard integration data
typedef struct {
    // Real-time metrics for dashboard
    float overall_cpu_usage;            // Overall CPU usage
    float memory_usage_mb;              // Memory usage in MB
    uint32_t active_modules;            // Number of active modules
    uint32_t hot_functions;             // Number of hot functions
    float average_frame_time_ms;        // Average frame time
    float peak_frame_time_ms;           // Peak frame time
    uint32_t total_function_calls;      // Total function calls per second
    
    // Performance trends
    float cpu_usage_trend[60];          // 60-second CPU usage history
    float memory_trend[60];             // 60-second memory usage history
    float frame_time_trend[60];         // 60-second frame time history
    
    // Module rankings
    module_profile_data_t* top_cpu_modules[10];      // Top CPU using modules
    module_profile_data_t* top_memory_modules[10];   // Top memory using modules
    function_profile_data_t* top_hot_functions[20];  // Top hot functions
    
    // System health indicators
    bool performance_warning;           // Performance degradation warning
    bool memory_pressure_warning;       // Memory pressure warning
    bool thermal_warning;               // Thermal throttling warning
    char status_message[256];           // Current status message
    
    // Dashboard update control
    uint64_t last_update_timestamp;     // Last dashboard update time
    bool auto_update_enabled;           // Auto-update enabled
    uint32_t update_interval_ms;        // Update interval
} dashboard_data_t;

// Main profiler context
typedef struct {
    // Configuration
    profiler_mode_t mode;               // Current profiling mode
    bool profiling_enabled;             // Whether profiling is active
    uint32_t sample_interval_us;        // Sampling interval in microseconds
    
    // Module tracking
    module_profile_data_t modules[PROFILER_MAX_MODULES];
    uint32_t module_count;              // Number of tracked modules
    
    // Function tracking
    function_profile_data_t functions[PROFILER_MAX_FUNCTIONS];
    uint32_t function_count;            // Number of tracked functions
    
    // Sample data
    profile_sample_t* samples;          // Sample buffer
    uint32_t sample_count;              // Current sample count
    uint32_t sample_capacity;           // Sample buffer capacity
    uint32_t sample_write_index;        // Circular buffer write index
    
    // Call stack tracking
    call_stack_frame_t call_stacks[PROFILER_MAX_MODULES][PROFILER_MAX_CALL_STACK_DEPTH];
    uint32_t call_stack_depths[PROFILER_MAX_MODULES];
    
    // Dashboard integration
    dashboard_data_t dashboard;         // Dashboard data
    
    // Threading
    pthread_t profiler_thread;          // Background profiler thread
    pthread_t dashboard_thread;         // Dashboard update thread
    pthread_mutex_t profiler_mutex;     // Thread safety
    bool profiler_thread_running;       // Profiler thread status
    bool dashboard_thread_running;      // Dashboard thread status
    
    // Integration with debug system
    hmr_debug_context_t* debug_context; // Debug system integration
    
    // Apple Silicon specific
    bool has_performance_counters;      // Hardware performance counters available
    bool has_thermal_sensors;           // Thermal sensors available
    bool has_power_sensors;             // Power sensors available
    uint32_t apple_chip_generation;     // Apple chip generation (M1=1, M2=2, etc.)
    
    // Statistics
    uint64_t total_samples_collected;   // Total samples collected
    uint64_t total_functions_profiled;  // Total functions profiled
    uint64_t profiling_overhead_ns;     // Profiling overhead
    uint64_t dashboard_updates_sent;    // Dashboard updates sent
} module_profiler_context_t;

// Agent 4 Dashboard API Integration
typedef struct {
    // Dashboard connection
    void* dashboard_handle;             // Opaque dashboard handle
    char dashboard_endpoint[256];       // Dashboard HTTP endpoint
    uint16_t dashboard_port;            // Dashboard port
    
    // Data serialization
    char* json_buffer;                  // JSON serialization buffer
    size_t json_buffer_size;            // JSON buffer size
    
    // WebSocket connection for real-time updates
    void* websocket_handle;             // WebSocket handle
    bool websocket_connected;           // WebSocket connection status
    
    // HTTP client for REST API
    void* http_client;                  // HTTP client handle
    
    // Update batching
    uint32_t pending_updates;           // Number of pending updates
    uint32_t max_batch_size;            // Maximum batch size
} dashboard_integration_t;

// API Functions
#ifdef __cplusplus
extern "C" {
#endif

// Profiler initialization and control
int32_t profiler_init_system(module_profiler_context_t** ctx);
int32_t profiler_shutdown_system(module_profiler_context_t* ctx);
int32_t profiler_start_profiling(module_profiler_context_t* ctx, profiler_mode_t mode);
int32_t profiler_stop_profiling(module_profiler_context_t* ctx);
int32_t profiler_pause_profiling(module_profiler_context_t* ctx);
int32_t profiler_resume_profiling(module_profiler_context_t* ctx);

// Module registration and tracking
int32_t profiler_register_module(module_profiler_context_t* ctx, hmr_agent_module_t* module);
int32_t profiler_unregister_module(module_profiler_context_t* ctx, hmr_agent_module_t* module);
int32_t profiler_update_module_metrics(module_profiler_context_t* ctx, hmr_agent_module_t* module);

// Function profiling
int32_t profiler_enter_function(module_profiler_context_t* ctx, void* function_address,
                               hmr_agent_module_t* module);
int32_t profiler_exit_function(module_profiler_context_t* ctx, void* function_address,
                              uint64_t execution_time_ns);
int32_t profiler_sample_function_call(module_profiler_context_t* ctx, void* pc,
                                     hmr_agent_module_t* module);

// Data collection and analysis
int32_t profiler_collect_sample(module_profiler_context_t* ctx);
int32_t profiler_analyze_hot_functions(module_profiler_context_t* ctx);
int32_t profiler_generate_call_graph(module_profiler_context_t* ctx, char** graph_data);
int32_t profiler_export_profile_data(module_profiler_context_t* ctx, const char* filename);

// Dashboard integration
int32_t profiler_init_dashboard_integration(module_profiler_context_t* ctx, 
                                           const char* dashboard_endpoint, uint16_t port);
int32_t profiler_update_dashboard(module_profiler_context_t* ctx);
int32_t profiler_send_realtime_metrics(module_profiler_context_t* ctx);
int32_t profiler_register_dashboard_callbacks(module_profiler_context_t* ctx);

// Performance metrics
int32_t profiler_get_module_metrics(module_profiler_context_t* ctx, hmr_agent_module_t* module,
                                   module_profile_data_t* metrics);
int32_t profiler_get_function_metrics(module_profiler_context_t* ctx, void* function_address,
                                     function_profile_data_t* metrics);
int32_t profiler_get_system_metrics(module_profiler_context_t* ctx, dashboard_data_t* dashboard);

// Apple Silicon specific profiling
int32_t profiler_init_apple_silicon_counters(module_profiler_context_t* ctx);
int32_t profiler_read_performance_counters(module_profiler_context_t* ctx, 
                                          uint64_t* counters, uint32_t count);
int32_t profiler_read_thermal_state(module_profiler_context_t* ctx, float* temperature);
int32_t profiler_read_power_consumption(module_profiler_context_t* ctx, float* watts);

// Configuration
int32_t profiler_set_sampling_interval(module_profiler_context_t* ctx, uint32_t interval_us);
int32_t profiler_set_dashboard_update_interval(module_profiler_context_t* ctx, uint32_t interval_ms);
int32_t profiler_enable_function_instrumentation(module_profiler_context_t* ctx, bool enable);
int32_t profiler_enable_memory_profiling(module_profiler_context_t* ctx, bool enable);

// Utility functions
const char* profiler_mode_to_string(profiler_mode_t mode);
const char* profiler_metric_type_to_string(performance_metric_type_t type);
uint64_t profiler_get_timestamp_ns(void);
float profiler_calculate_cpu_usage(uint64_t cycles, uint64_t time_ns);

#ifdef __cplusplus
}
#endif

// Profiling macros for easy instrumentation
#define PROFILE_FUNCTION_ENTRY(ctx, module) \
    profiler_enter_function(ctx, __builtin_return_address(0), module)

#define PROFILE_FUNCTION_EXIT(ctx) \
    do { \
        static uint64_t _prof_start = 0; \
        if (_prof_start == 0) _prof_start = profiler_get_timestamp_ns(); \
        uint64_t _prof_end = profiler_get_timestamp_ns(); \
        profiler_exit_function(ctx, __builtin_return_address(0), _prof_end - _prof_start); \
    } while(0)

#define PROFILE_SCOPE(ctx, module, name) \
    uint64_t _prof_scope_start = profiler_get_timestamp_ns(); \
    profiler_enter_function(ctx, (void*)&_prof_scope_start, module); \
    /* Scope ends with automatic cleanup */

// Dashboard update triggers
#define PROFILER_TRIGGER_DASHBOARD_UPDATE(ctx) \
    profiler_update_dashboard(ctx)

// Error codes
#define PROFILER_SUCCESS                    0
#define PROFILER_ERROR_INVALID_CONTEXT      -1
#define PROFILER_ERROR_INVALID_MODULE       -2
#define PROFILER_ERROR_PROFILING_DISABLED   -3
#define PROFILER_ERROR_BUFFER_FULL          -4
#define PROFILER_ERROR_DASHBOARD_CONNECTION -5
#define PROFILER_ERROR_INSUFFICIENT_MEMORY  -6
#define PROFILER_ERROR_THREAD_CREATE        -7
#define PROFILER_ERROR_UNSUPPORTED_MODE     -8
#define PROFILER_ERROR_PERMISSION_DENIED    -9
#define PROFILER_ERROR_HARDWARE_UNAVAILABLE -10

#endif // HMR_MODULE_PROFILER_H