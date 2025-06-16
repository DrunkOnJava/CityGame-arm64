/*
 * SimCity ARM64 - Shader Manager Header
 * Metal Shader Hot-Reload Pipeline Interface
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Day 2: Shader Hot-Reload Interface
 */

#ifndef HMR_SHADER_MANAGER_H
#define HMR_SHADER_MANAGER_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __OBJC__
#import <Metal/Metal.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Shader types supported by the system
typedef enum {
    HMR_SHADER_VERTEX = 0,
    HMR_SHADER_FRAGMENT,
    HMR_SHADER_COMPUTE,
    HMR_SHADER_KERNEL,
    HMR_SHADER_TYPE_COUNT
} hmr_shader_type_t;

// Shader manager configuration
typedef struct {
    char shader_directory[256];
    char include_directory[256];
    char cache_directory[256];
    bool enable_hot_reload;
    bool enable_fallbacks;
    bool enable_binary_cache;
    uint32_t max_shaders;
    uint32_t compile_timeout_ms;
} hmr_shader_manager_config_t;

// Shader manager API functions
#ifdef __OBJC__
int32_t hmr_shader_manager_init(const hmr_shader_manager_config_t* config, id<MTLDevice> device);
#endif

int32_t hmr_shader_manager_register(const char* source_path, hmr_shader_type_t type);
int32_t hmr_shader_manager_compile_async(const char* source_path);
int32_t hmr_shader_manager_hot_swap(const char* source_path);

// Pipeline state access
#ifdef __OBJC__
id<MTLRenderPipelineState> hmr_shader_manager_get_render_pipeline(const char* source_path);
id<MTLComputePipelineState> hmr_shader_manager_get_compute_pipeline(const char* source_path);
#endif

// Callback registration
void hmr_shader_manager_set_callbacks(
    void (*on_compiled)(const char* path, bool success, uint64_t compile_time_ns),
    void (*on_error)(const char* path, const char* error),
    void (*on_hot_swap)(const char* path, uint64_t swap_time_ns)
);

// Statistics and monitoring
void hmr_shader_manager_get_stats(
    uint32_t* total_shaders,
    uint32_t* compiled_shaders,
    uint64_t* total_compilations,
    uint64_t* avg_compile_time,
    uint64_t* total_hot_swaps,
    uint64_t* avg_hot_swap_time
);

// Cleanup
void hmr_shader_manager_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif // HMR_SHADER_MANAGER_H