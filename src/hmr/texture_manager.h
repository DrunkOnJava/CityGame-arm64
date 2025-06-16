/*
 * SimCity ARM64 - Texture Manager Header
 * Texture Atlas Hot-Reload Pipeline Interface
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Day 3: Texture Hot-Swap Interface
 */

#ifndef HMR_TEXTURE_MANAGER_H
#define HMR_TEXTURE_MANAGER_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Texture formats supported by the system
typedef enum {
    HMR_TEXTURE_FORMAT_UNKNOWN = 0,
    HMR_TEXTURE_FORMAT_RGBA8,
    HMR_TEXTURE_FORMAT_BGRA8,
    HMR_TEXTURE_FORMAT_RGB8,
    HMR_TEXTURE_FORMAT_RGBA16F,
    HMR_TEXTURE_FORMAT_RGBA32F,
    HMR_TEXTURE_FORMAT_BC1,
    HMR_TEXTURE_FORMAT_BC3,
    HMR_TEXTURE_FORMAT_BC7,
    HMR_TEXTURE_FORMAT_ASTC_4x4,
    HMR_TEXTURE_FORMAT_ASTC_8x8,
    HMR_TEXTURE_FORMAT_COUNT
} hmr_texture_format_t;

// Texture compression levels
typedef enum {
    HMR_COMPRESSION_NONE = 0,
    HMR_COMPRESSION_FAST,
    HMR_COMPRESSION_BALANCED,
    HMR_COMPRESSION_HIGH_QUALITY,
    HMR_COMPRESSION_LOSSLESS
} hmr_texture_compression_t;

// Texture manager configuration
typedef struct {
    char texture_directory[256];
    char cache_directory[256];
    uint32_t max_atlases;
    uint32_t max_textures_per_atlas;
    uint32_t atlas_width, atlas_height;
    hmr_texture_format_t default_format;
    hmr_texture_compression_t compression_level;
    bool enable_hot_reload;
    bool enable_compression;
    bool enable_mip_generation;
    uint32_t compression_threads;
    float memory_budget_mb;
} hmr_texture_manager_config_t;

// Texture manager API functions
int32_t hmr_texture_manager_init(const hmr_texture_manager_config_t* config);
int32_t hmr_texture_manager_register(const char* texture_path);
int32_t hmr_texture_manager_hot_swap(const char* texture_path);
int32_t hmr_texture_manager_process_rebuilds(void);

// Atlas information
int32_t hmr_texture_manager_get_atlas_info(uint32_t atlas_id, uint32_t* width, uint32_t* height,
                                          uint32_t* texture_count, uint64_t* memory_usage);

// Callback registration
void hmr_texture_manager_set_callbacks(
    void (*on_texture_loaded)(const char* path, bool success, uint64_t load_time_ns),
    void (*on_atlas_rebuilt)(uint32_t atlas_id, uint64_t rebuild_time_ns),
    void (*on_memory_pressure)(float usage_ratio, uint64_t available_bytes)
);

// Statistics and monitoring
void hmr_texture_manager_get_stats(
    uint32_t* total_textures,
    uint32_t* total_atlases,
    uint64_t* total_memory_used,
    float* memory_usage_ratio,
    uint64_t* total_reloads,
    uint64_t* avg_reload_time
);

// Cleanup
void hmr_texture_manager_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif // HMR_TEXTURE_MANAGER_H