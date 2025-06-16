/*
 * SimCity ARM64 - Comprehensive Shader Debugging Integration
 * Advanced Shader Debugging and Visualization for Agent 4's UI Dashboard
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Week 2 - Day 6: Advanced Shader Features
 * 
 * Features:
 * - Real-time shader compilation error visualization
 * - Shader performance profiling and bottleneck detection
 * - Interactive shader parameter tweaking
 * - Shader dependency graph visualization
 * - GPU timeline and command buffer analysis
 * - Live shader metrics and memory usage
 */

#ifndef HMR_SHADER_DEBUG_INTEGRATION_H
#define HMR_SHADER_DEBUG_INTEGRATION_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __OBJC__
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Shader debug severity levels
typedef enum {
    HMR_DEBUG_SEVERITY_INFO = 0,
    HMR_DEBUG_SEVERITY_WARNING,
    HMR_DEBUG_SEVERITY_ERROR,
    HMR_DEBUG_SEVERITY_CRITICAL
} hmr_debug_severity_t;

// Shader debug message types
typedef enum {
    HMR_DEBUG_TYPE_COMPILATION = 0,
    HMR_DEBUG_TYPE_PERFORMANCE,
    HMR_DEBUG_TYPE_VALIDATION,
    HMR_DEBUG_TYPE_MEMORY,
    HMR_DEBUG_TYPE_GPU_TIMELINE,
    HMR_DEBUG_TYPE_DEPENDENCY,
    HMR_DEBUG_TYPE_PARAMETER
} hmr_debug_type_t;

// Shader performance metrics
typedef struct {
    char shader_name[64];               // Shader identifier
    uint64_t frame_number;              // Frame when measured
    
    // GPU timing
    uint64_t gpu_start_time_ns;         // GPU execution start time
    uint64_t gpu_end_time_ns;           // GPU execution end time
    uint64_t gpu_duration_ns;           // Total GPU execution time
    
    // Command buffer metrics
    uint32_t command_buffer_id;         // Command buffer identifier
    uint32_t encoder_count;             // Number of encoders in buffer
    uint32_t draw_call_count;           // Number of draw calls
    uint32_t compute_dispatch_count;    // Number of compute dispatches
    
    // Memory metrics
    size_t vertex_buffer_size;          // Vertex buffer memory usage
    size_t index_buffer_size;           // Index buffer memory usage
    size_t texture_memory_size;         // Texture memory usage
    size_t uniform_buffer_size;         // Uniform buffer memory usage
    
    // Performance counters
    uint64_t vertices_processed;        // Number of vertices processed
    uint64_t fragments_processed;       // Number of fragments processed
    uint64_t compute_threads_executed;  // Number of compute threads
    
    // Quality metrics
    float gpu_utilization;              // GPU utilization percentage
    float memory_bandwidth_utilization; // Memory bandwidth usage
    uint32_t cache_miss_count;          // Cache misses
    uint32_t stall_cycles;              // Pipeline stall cycles
    
    // Thermal and power
    float gpu_temperature;              // GPU temperature (if available)
    float power_consumption;            // Power consumption (if available)
} hmr_shader_performance_metrics_t;

// Shader debug message
typedef struct {
    uint64_t timestamp;                 // Message timestamp
    hmr_debug_severity_t severity;      // Message severity
    hmr_debug_type_t type;              // Message type
    char shader_name[64];               // Related shader name
    char message[512];                  // Debug message text
    char file_path[256];                // Source file path
    uint32_t line_number;               // Line number in source
    uint32_t column_number;             // Column number in source
    
    // Additional context
    union {
        struct {
            char compiler_error[256];   // Compiler error details
            char suggested_fix[256];    // Suggested fix
        } compilation;
        
        struct {
            float threshold_value;      // Performance threshold
            float actual_value;         // Actual measured value
            char bottleneck_type[64];   // Type of bottleneck
        } performance;
        
        struct {
            size_t memory_allocated;    // Memory allocated
            size_t memory_peak;         // Peak memory usage
            char allocation_type[32];   // Type of allocation
        } memory;
    } context;
} hmr_shader_debug_message_t;

// Shader parameter definition for live tweaking
typedef struct {
    char parameter_name[64];            // Parameter name
    char display_name[64];              // Human-readable name
    char description[256];              // Parameter description
    
    enum {
        HMR_PARAM_TYPE_FLOAT = 0,
        HMR_PARAM_TYPE_VEC2,
        HMR_PARAM_TYPE_VEC3,
        HMR_PARAM_TYPE_VEC4,
        HMR_PARAM_TYPE_INT,
        HMR_PARAM_TYPE_BOOL,
        HMR_PARAM_TYPE_COLOR,
        HMR_PARAM_TYPE_TEXTURE_SLOT
    } type;
    
    union {
        struct { float value, min, max, step; } float_param;
        struct { float value[2], min[2], max[2], step[2]; } vec2_param;
        struct { float value[3], min[3], max[3], step[3]; } vec3_param;
        struct { float value[4], min[4], max[4], step[4]; } vec4_param;
        struct { int32_t value, min, max; } int_param;
        struct { bool value; } bool_param;
        struct { float r, g, b, a; } color_param;
        struct { uint32_t slot; char texture_path[256]; } texture_param;
    } data;
    
    bool is_dirty;                      // Whether parameter changed
    uint64_t last_modified_time;        // Last modification timestamp
} hmr_shader_parameter_t;

// Shader dependency node for graph visualization
typedef struct {
    char node_id[64];                   // Unique node identifier
    char display_name[64];              // Display name
    char file_path[256];                // File path
    
    enum {
        HMR_DEP_TYPE_SHADER = 0,
        HMR_DEP_TYPE_INCLUDE,
        HMR_DEP_TYPE_TEXTURE,
        HMR_DEP_TYPE_BUFFER,
        HMR_DEP_TYPE_UNIFORM
    } type;
    
    uint32_t dependency_count;          // Number of dependencies
    char dependencies[16][64];          // Array of dependency node IDs
    
    // Visual properties for graph rendering
    float position_x, position_y;       // Node position
    float size_x, size_y;               // Node size
    uint32_t color;                     // Node color (RGBA)
    bool is_selected;                   // Whether node is selected
    bool is_highlighted;                // Whether node is highlighted
    
    // Status information
    bool is_compiled;                   // Whether successfully compiled
    bool has_errors;                    // Whether has compilation errors
    uint64_t last_modified_time;        // Last modification time
} hmr_shader_dependency_node_t;

// GPU timeline event for visualization
typedef struct {
    uint64_t start_time_ns;             // Event start time
    uint64_t end_time_ns;               // Event end time
    char event_name[64];                // Event name
    char shader_name[64];               // Related shader
    
    enum {
        HMR_TIMELINE_VERTEX = 0,
        HMR_TIMELINE_FRAGMENT,
        HMR_TIMELINE_COMPUTE,
        HMR_TIMELINE_COPY,
        HMR_TIMELINE_BARRIER,
        HMR_TIMELINE_PRESENT
    } event_type;
    
    uint32_t thread_id;                 // GPU thread/queue ID
    uint32_t color;                     // Event color for visualization
    
    // Performance data
    uint64_t vertices_processed;
    uint64_t fragments_processed;
    size_t memory_transferred;
} hmr_gpu_timeline_event_t;

// Debug configuration
typedef struct {
    bool enable_performance_tracking;   // Track shader performance
    bool enable_memory_tracking;        // Track memory usage
    bool enable_gpu_timeline;           // Track GPU timeline
    bool enable_parameter_tweaking;     // Enable live parameter tweaking
    bool enable_dependency_tracking;    // Track shader dependencies
    
    // Performance thresholds
    uint64_t gpu_time_warning_ns;       // GPU time warning threshold
    uint64_t gpu_time_error_ns;         // GPU time error threshold
    size_t memory_warning_mb;           // Memory usage warning threshold
    size_t memory_error_mb;             // Memory usage error threshold
    
    // UI settings
    uint32_t max_debug_messages;        // Maximum debug messages to keep
    uint32_t max_timeline_events;       // Maximum timeline events to keep
    float timeline_zoom_level;          // Timeline zoom level
    uint64_t timeline_window_ns;        // Timeline window size
} hmr_debug_config_t;

// Debug integration API

// Initialization and configuration
int32_t hmr_debug_init(const hmr_debug_config_t* config);
void hmr_debug_cleanup(void);
int32_t hmr_debug_update_config(const hmr_debug_config_t* config);

// Message logging
void hmr_debug_log_message(hmr_debug_severity_t severity, hmr_debug_type_t type,
                          const char* shader_name, const char* message);
void hmr_debug_log_compilation_error(const char* shader_name, const char* file_path,
                                    uint32_t line, uint32_t column, const char* error,
                                    const char* suggested_fix);
void hmr_debug_log_performance_warning(const char* shader_name, const char* bottleneck_type,
                                      float threshold, float actual_value);

// Performance tracking
#ifdef __OBJC__
int32_t hmr_debug_start_gpu_capture(id<MTLCommandBuffer> command_buffer, const char* shader_name);
int32_t hmr_debug_end_gpu_capture(id<MTLCommandBuffer> command_buffer);
#endif

void hmr_debug_record_performance_metrics(const hmr_shader_performance_metrics_t* metrics);
void hmr_debug_add_timeline_event(const hmr_gpu_timeline_event_t* event);

// Parameter tweaking
int32_t hmr_debug_register_parameter(const char* shader_name, const hmr_shader_parameter_t* parameter);
int32_t hmr_debug_update_parameter(const char* shader_name, const char* parameter_name, const void* value);
int32_t hmr_debug_get_parameter(const char* shader_name, const char* parameter_name, hmr_shader_parameter_t* parameter);
int32_t hmr_debug_get_dirty_parameters(const char* shader_name, hmr_shader_parameter_t* parameters, 
                                      uint32_t max_count, uint32_t* actual_count);

// Dependency tracking
int32_t hmr_debug_add_dependency_node(const hmr_shader_dependency_node_t* node);
int32_t hmr_debug_update_dependency_status(const char* node_id, bool is_compiled, bool has_errors);
int32_t hmr_debug_get_dependency_graph(hmr_shader_dependency_node_t* nodes, uint32_t max_count, 
                                      uint32_t* actual_count);

// Data retrieval for UI
int32_t hmr_debug_get_messages(hmr_debug_severity_t min_severity, hmr_shader_debug_message_t* messages,
                              uint32_t max_count, uint32_t* actual_count);
int32_t hmr_debug_get_performance_history(const char* shader_name, hmr_shader_performance_metrics_t* metrics,
                                         uint32_t max_count, uint32_t* actual_count);
int32_t hmr_debug_get_timeline_events(uint64_t start_time_ns, uint64_t end_time_ns,
                                     hmr_gpu_timeline_event_t* events, uint32_t max_count, 
                                     uint32_t* actual_count);

// Statistics and summaries
typedef struct {
    uint32_t total_shaders;             // Total number of shaders
    uint32_t compiled_shaders;          // Successfully compiled shaders
    uint32_t failed_shaders;            // Failed compilations
    uint32_t active_parameters;         // Active tweakable parameters
    
    uint64_t total_gpu_time_ns;         // Total GPU time this frame
    float avg_gpu_utilization;          // Average GPU utilization
    size_t total_memory_usage_mb;       // Total GPU memory usage
    
    uint32_t debug_message_count;       // Number of debug messages
    uint32_t warning_count;             // Number of warnings
    uint32_t error_count;               // Number of errors
    
    uint64_t last_update_time;          // Last statistics update time
} hmr_debug_statistics_t;

void hmr_debug_get_statistics(hmr_debug_statistics_t* stats);
void hmr_debug_reset_statistics(void);

// UI integration callbacks
void hmr_debug_set_ui_callbacks(
    void (*on_message_logged)(const hmr_shader_debug_message_t* message),
    void (*on_performance_updated)(const hmr_shader_performance_metrics_t* metrics),
    void (*on_parameter_changed)(const char* shader_name, const char* parameter_name),
    void (*on_dependency_updated)(const char* node_id, bool is_compiled, bool has_errors)
);

// Export/Import for external tools
int32_t hmr_debug_export_timeline(const char* file_path, uint64_t start_time_ns, uint64_t end_time_ns);
int32_t hmr_debug_export_performance_report(const char* file_path);
int32_t hmr_debug_import_parameter_preset(const char* file_path, const char* shader_name);
int32_t hmr_debug_export_parameter_preset(const char* file_path, const char* shader_name);

#ifdef __cplusplus
}
#endif

#endif // HMR_SHADER_DEBUG_INTEGRATION_H