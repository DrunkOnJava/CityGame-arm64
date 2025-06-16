/*
 * SimCity ARM64 - Texture Manager for HMR System
 * Texture Atlas Hot-Reload Pipeline with GPU Memory Management
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Day 3: Texture Hot-Swap Implementation
 * 
 * Performance Targets:
 * - Texture reload: <100ms
 * - GPU memory efficiency: >90%
 * - Zero frame drops during reload
 * - Atlas rebuild: <50ms
 * - Memory fragmentation: <5%
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <mach/mach_time.h>
#include <sys/stat.h>
#include "asset_watcher.h"
#include "dependency_tracker.h"
#include "module_interface.h"

// Texture format support
typedef enum {
    HMR_TEXTURE_FORMAT_UNKNOWN = 0,
    HMR_TEXTURE_FORMAT_RGBA8,       // 8-bit RGBA
    HMR_TEXTURE_FORMAT_BGRA8,       // 8-bit BGRA (Metal preferred)
    HMR_TEXTURE_FORMAT_RGB8,        // 8-bit RGB
    HMR_TEXTURE_FORMAT_RGBA16F,     // 16-bit float RGBA
    HMR_TEXTURE_FORMAT_RGBA32F,     // 32-bit float RGBA
    HMR_TEXTURE_FORMAT_BC1,         // DXT1/BC1 compression
    HMR_TEXTURE_FORMAT_BC3,         // DXT5/BC3 compression
    HMR_TEXTURE_FORMAT_BC7,         // BC7 compression
    HMR_TEXTURE_FORMAT_ASTC_4x4,    // ASTC 4x4 compression
    HMR_TEXTURE_FORMAT_ASTC_8x8,    // ASTC 8x8 compression
    HMR_TEXTURE_FORMAT_COUNT
} hmr_texture_format_t;

// Texture type classification
typedef enum {
    HMR_TEXTURE_TYPE_2D = 0,
    HMR_TEXTURE_TYPE_CUBEMAP,
    HMR_TEXTURE_TYPE_ARRAY,
    HMR_TEXTURE_TYPE_3D,
    HMR_TEXTURE_TYPE_COUNT
} hmr_texture_type_t;

// Texture compression options
typedef enum {
    HMR_COMPRESSION_NONE = 0,
    HMR_COMPRESSION_FAST,           // Fast compression for development
    HMR_COMPRESSION_BALANCED,       // Balanced quality/speed
    HMR_COMPRESSION_HIGH_QUALITY,   // High quality for release
    HMR_COMPRESSION_LOSSLESS        // Lossless compression
} hmr_texture_compression_t;

// Texture atlas entry
typedef struct {
    char source_path[256];          // Original texture file path
    char texture_id[64];            // Unique texture identifier
    uint32_t atlas_index;           // Which atlas this texture is in
    uint32_t x, y;                  // Position in atlas
    uint32_t width, height;         // Dimensions in atlas
    uint32_t original_width, original_height; // Original dimensions
    hmr_texture_format_t format;    // Texture format
    uint64_t file_size;             // Source file size
    uint64_t last_modified;         // Last modification time
    bool needs_reload;              // Whether texture needs reloading
    bool is_compressed;             // Whether texture is compressed
    uint32_t mip_levels;            // Number of mip levels
    float scale_factor;             // Scale applied during atlas packing
    
    // GPU memory info
    void* gpu_handle;               // Platform-specific GPU texture handle
    uint64_t gpu_memory_size;       // GPU memory usage in bytes
    bool is_resident;               // Whether texture is in GPU memory
} hmr_texture_entry_t;

// Texture atlas structure
typedef struct {
    uint32_t atlas_id;              // Unique atlas identifier
    uint32_t width, height;         // Atlas dimensions
    hmr_texture_format_t format;    // Atlas texture format
    uint32_t texture_count;         // Number of textures in atlas
    uint32_t max_textures;          // Maximum textures per atlas
    hmr_texture_entry_t* textures;  // Array of texture entries
    
    // GPU resources
    void* gpu_texture;              // Platform-specific GPU texture
    void* staging_buffer;           // Staging buffer for updates
    uint64_t gpu_memory_usage;      // Total GPU memory used by atlas
    
    // Atlas packing info
    bool needs_rebuild;             // Whether atlas needs rebuilding
    uint32_t free_space;            // Available space in atlas
    float fragmentation_ratio;      // Memory fragmentation ratio
    uint64_t last_rebuild_time;     // Last rebuild timestamp
    uint64_t rebuild_count;         // Number of rebuilds
} hmr_texture_atlas_t;

// Texture manager configuration
typedef struct {
    char texture_directory[256];    // Root directory for textures
    char cache_directory[256];      // Directory for cached textures
    uint32_t max_atlases;           // Maximum number of atlases
    uint32_t max_textures_per_atlas; // Maximum textures per atlas
    uint32_t atlas_width, atlas_height; // Default atlas dimensions
    hmr_texture_format_t default_format; // Default texture format
    hmr_texture_compression_t compression_level; // Compression level
    bool enable_hot_reload;         // Whether hot-reload is enabled
    bool enable_compression;        // Whether to compress textures
    bool enable_mip_generation;     // Whether to generate mipmaps
    uint32_t compression_threads;   // Number of compression threads
    float memory_budget_mb;         // GPU memory budget in MB
} hmr_texture_manager_config_t;

// Main texture manager structure
typedef struct {
    // Configuration
    hmr_texture_manager_config_t config;
    
    // Atlas management
    hmr_texture_atlas_t* atlases;   // Array of texture atlases
    uint32_t atlas_count;           // Current number of atlases
    uint32_t atlas_capacity;        // Maximum number of atlases
    
    // Texture tracking
    hmr_texture_entry_t* all_textures; // Flat array of all textures
    uint32_t texture_count;         // Total number of textures
    uint32_t texture_capacity;      // Maximum number of textures
    
    // GPU memory management
    uint64_t total_gpu_memory_used; // Total GPU memory usage
    uint64_t memory_budget_bytes;   // Memory budget in bytes
    float memory_usage_ratio;       // Current memory usage ratio
    uint32_t texture_evictions;     // Number of textures evicted
    
    // Performance metrics
    uint64_t total_reloads;         // Total texture reloads
    uint64_t total_atlas_rebuilds;  // Total atlas rebuilds
    uint64_t avg_reload_time;       // Average reload time
    uint64_t avg_rebuild_time;      // Average atlas rebuild time
    uint64_t compression_time_total; // Total compression time
    
    // Threading
    void* compress_queue;           // Compression thread queue
    void* upload_queue;             // GPU upload thread queue
    
    // Callbacks
    void (*on_texture_loaded)(const char* path, bool success, uint64_t load_time_ns);
    void (*on_atlas_rebuilt)(uint32_t atlas_id, uint64_t rebuild_time_ns);
    void (*on_memory_pressure)(float usage_ratio, uint64_t available_bytes);
} hmr_texture_manager_t;

// Global texture manager instance
static hmr_texture_manager_t* g_texture_manager = NULL;

// Texture format information
static const struct {
    hmr_texture_format_t format;
    uint32_t bytes_per_pixel;
    bool is_compressed;
    const char* name;
} g_texture_format_info[] = {
    {HMR_TEXTURE_FORMAT_RGBA8, 4, false, "RGBA8"},
    {HMR_TEXTURE_FORMAT_BGRA8, 4, false, "BGRA8"},
    {HMR_TEXTURE_FORMAT_RGB8, 3, false, "RGB8"},
    {HMR_TEXTURE_FORMAT_RGBA16F, 8, false, "RGBA16F"},
    {HMR_TEXTURE_FORMAT_RGBA32F, 16, false, "RGBA32F"},
    {HMR_TEXTURE_FORMAT_BC1, 0, true, "BC1"},
    {HMR_TEXTURE_FORMAT_BC3, 0, true, "BC3"},
    {HMR_TEXTURE_FORMAT_BC7, 0, true, "BC7"},
    {HMR_TEXTURE_FORMAT_ASTC_4x4, 0, true, "ASTC_4x4"},
    {HMR_TEXTURE_FORMAT_ASTC_8x8, 0, true, "ASTC_8x8"},
    {HMR_TEXTURE_FORMAT_UNKNOWN, 0, false, "UNKNOWN"}
};

// Get texture format info
static const char* hmr_get_format_name(hmr_texture_format_t format) {
    for (int i = 0; g_texture_format_info[i].format != HMR_TEXTURE_FORMAT_UNKNOWN; i++) {
        if (g_texture_format_info[i].format == format) {
            return g_texture_format_info[i].name;
        }
    }
    return "UNKNOWN";
}

// Calculate texture memory size
static uint64_t hmr_calculate_texture_memory_size(uint32_t width, uint32_t height, 
                                                 hmr_texture_format_t format, uint32_t mip_levels) {
    uint64_t size = 0;
    
    for (uint32_t i = 0; i < mip_levels; i++) {
        uint32_t mip_width = width >> i;
        uint32_t mip_height = height >> i;
        
        if (mip_width == 0) mip_width = 1;
        if (mip_height == 0) mip_height = 1;
        
        // Find format info
        for (int j = 0; g_texture_format_info[j].format != HMR_TEXTURE_FORMAT_UNKNOWN; j++) {
            if (g_texture_format_info[j].format == format) {
                if (g_texture_format_info[j].is_compressed) {
                    // Compressed formats have block-based sizes
                    // Simplified calculation for now
                    size += (mip_width * mip_height) / 2; // Rough estimate
                } else {
                    size += mip_width * mip_height * g_texture_format_info[j].bytes_per_pixel;
                }
                break;
            }
        }
    }
    
    return size;
}

// Find texture entry by path
static hmr_texture_entry_t* hmr_find_texture(const char* path) {
    if (!g_texture_manager || !path) return NULL;
    
    for (uint32_t i = 0; i < g_texture_manager->texture_count; i++) {
        if (strcmp(g_texture_manager->all_textures[i].source_path, path) == 0) {
            return &g_texture_manager->all_textures[i];
        }
    }
    
    return NULL;
}

// Load texture from file (stub implementation)
static bool hmr_load_texture_from_file(const char* file_path, hmr_texture_entry_t* texture) {
    if (!file_path || !texture) return false;
    
    uint64_t start_time = mach_absolute_time();
    
    // Get file info
    struct stat file_stat;
    if (stat(file_path, &file_stat) != 0) {
        printf("HMR Texture: Failed to stat file: %s\n", file_path);
        return false;
    }
    
    texture->file_size = file_stat.st_size;
    texture->last_modified = file_stat.st_mtime * 1000000000ULL; // Convert to nanoseconds
    
    // Simplified texture loading (would use actual image loading library)
    // For now, just set some default values
    texture->original_width = 256;  // Default size
    texture->original_height = 256;
    texture->format = g_texture_manager->config.default_format;
    texture->mip_levels = g_texture_manager->config.enable_mip_generation ? 8 : 1;
    
    // Calculate GPU memory usage
    texture->gpu_memory_size = hmr_calculate_texture_memory_size(
        texture->original_width, texture->original_height, 
        texture->format, texture->mip_levels);
    
    // Calculate load time
    uint64_t end_time = mach_absolute_time();
    static mach_timebase_info_data_t timebase_info;
    if (timebase_info.denom == 0) {
        mach_timebase_info(&timebase_info);
    }
    uint64_t load_time = (end_time - start_time) * timebase_info.numer / timebase_info.denom;
    
    printf("HMR Texture: Loaded %s (%ux%u, %s, %.2f KB, %.2f ms)\n",
           file_path, texture->original_width, texture->original_height,
           hmr_get_format_name(texture->format),
           texture->gpu_memory_size / 1024.0, load_time / 1000000.0);
    
    return true;
}

// Simple atlas packing algorithm (bin packing)
static bool hmr_pack_texture_in_atlas(hmr_texture_atlas_t* atlas, hmr_texture_entry_t* texture) {
    if (!atlas || !texture) return false;
    
    // Very simple algorithm - just try to fit in remaining space
    // Real implementation would use sophisticated bin packing
    
    uint32_t packed_width = texture->original_width;
    uint32_t packed_height = texture->original_height;
    
    // Find a spot in the atlas (simplified linear search)
    for (uint32_t y = 0; y <= atlas->height - packed_height; y += 32) {
        for (uint32_t x = 0; x <= atlas->width - packed_width; x += 32) {
            bool can_place = true;
            
            // Check if this spot overlaps with existing textures
            for (uint32_t i = 0; i < atlas->texture_count; i++) {
                hmr_texture_entry_t* existing = &atlas->textures[i];
                
                if (!(x >= existing->x + existing->width || 
                      x + packed_width <= existing->x ||
                      y >= existing->y + existing->height ||
                      y + packed_height <= existing->y)) {
                    can_place = false;
                    break;
                }
            }
            
            if (can_place) {
                // Place texture here
                texture->atlas_index = atlas->atlas_id;
                texture->x = x;
                texture->y = y;
                texture->width = packed_width;
                texture->height = packed_height;
                texture->scale_factor = 1.0f;
                
                // Add to atlas
                if (atlas->texture_count < atlas->max_textures) {
                    atlas->textures[atlas->texture_count] = *texture;
                    atlas->texture_count++;
                    
                    printf("HMR Texture: Packed %s in atlas %u at (%u, %u)\n",
                           texture->source_path, atlas->atlas_id, x, y);
                    
                    return true;
                }
            }
        }
    }
    
    return false;
}

// Rebuild texture atlas
static bool hmr_rebuild_texture_atlas(hmr_texture_atlas_t* atlas) {
    if (!atlas) return false;
    
    uint64_t start_time = mach_absolute_time();
    
    printf("HMR Texture: Rebuilding atlas %u with %u textures\n", 
           atlas->atlas_id, atlas->texture_count);
    
    // Mark as rebuilding
    atlas->needs_rebuild = false;
    
    // For now, just update the rebuild stats
    // Real implementation would:
    // 1. Create new atlas layout
    // 2. Copy texture data to new positions
    // 3. Update GPU texture
    // 4. Update texture coordinates
    
    uint64_t end_time = mach_absolute_time();
    static mach_timebase_info_data_t timebase_info;
    if (timebase_info.denom == 0) {
        mach_timebase_info(&timebase_info);
    }
    uint64_t rebuild_time = (end_time - start_time) * timebase_info.numer / timebase_info.denom;
    
    atlas->last_rebuild_time = end_time;
    atlas->rebuild_count++;
    
    g_texture_manager->total_atlas_rebuilds++;
    g_texture_manager->avg_rebuild_time = (g_texture_manager->avg_rebuild_time + rebuild_time) / 2;
    
    // Notify callback
    if (g_texture_manager->on_atlas_rebuilt) {
        g_texture_manager->on_atlas_rebuilt(atlas->atlas_id, rebuild_time);
    }
    
    printf("HMR Texture: Atlas %u rebuilt in %.2f ms\n", 
           atlas->atlas_id, rebuild_time / 1000000.0);
    
    return true;
}

// Create new texture atlas
static hmr_texture_atlas_t* hmr_create_texture_atlas(void) {
    if (!g_texture_manager) return NULL;
    
    if (g_texture_manager->atlas_count >= g_texture_manager->atlas_capacity) {
        printf("HMR Texture: Maximum atlas capacity reached (%u)\n", g_texture_manager->atlas_capacity);
        return NULL;
    }
    
    hmr_texture_atlas_t* atlas = &g_texture_manager->atlases[g_texture_manager->atlas_count];
    memset(atlas, 0, sizeof(hmr_texture_atlas_t));
    
    // Initialize atlas
    atlas->atlas_id = g_texture_manager->atlas_count;
    atlas->width = g_texture_manager->config.atlas_width;
    atlas->height = g_texture_manager->config.atlas_height;
    atlas->format = g_texture_manager->config.default_format;
    atlas->max_textures = g_texture_manager->config.max_textures_per_atlas;
    
    // Allocate texture array
    atlas->textures = calloc(atlas->max_textures, sizeof(hmr_texture_entry_t));
    if (!atlas->textures) {
        printf("HMR Texture: Failed to allocate texture array for atlas %u\n", atlas->atlas_id);
        return NULL;
    }
    
    // Calculate memory usage
    atlas->gpu_memory_usage = hmr_calculate_texture_memory_size(
        atlas->width, atlas->height, atlas->format, 1);
    
    g_texture_manager->atlas_count++;
    g_texture_manager->total_gpu_memory_used += atlas->gpu_memory_usage;
    
    printf("HMR Texture: Created atlas %u (%ux%u, %s, %.2f MB)\n",
           atlas->atlas_id, atlas->width, atlas->height,
           hmr_get_format_name(atlas->format),
           atlas->gpu_memory_usage / (1024.0 * 1024.0));
    
    return atlas;
}

// Initialize texture manager
int32_t hmr_texture_manager_init(const hmr_texture_manager_config_t* config) {
    if (g_texture_manager) {
        printf("HMR Texture Manager: Already initialized\n");
        return HMR_ERROR_ALREADY_EXISTS;
    }
    
    if (!config) {
        printf("HMR Texture Manager: Invalid configuration\n");
        return HMR_ERROR_INVALID_ARG;
    }
    
    // Allocate manager structure
    g_texture_manager = calloc(1, sizeof(hmr_texture_manager_t));
    if (!g_texture_manager) {
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    // Copy configuration
    memcpy(&g_texture_manager->config, config, sizeof(hmr_texture_manager_config_t));
    
    // Convert memory budget to bytes
    g_texture_manager->memory_budget_bytes = (uint64_t)(config->memory_budget_mb * 1024 * 1024);
    
    // Allocate atlas array
    g_texture_manager->atlas_capacity = config->max_atlases;
    g_texture_manager->atlases = calloc(g_texture_manager->atlas_capacity, sizeof(hmr_texture_atlas_t));
    if (!g_texture_manager->atlases) {
        free(g_texture_manager);
        g_texture_manager = NULL;
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    // Allocate texture array
    g_texture_manager->texture_capacity = config->max_atlases * config->max_textures_per_atlas;
    g_texture_manager->all_textures = calloc(g_texture_manager->texture_capacity, sizeof(hmr_texture_entry_t));
    if (!g_texture_manager->all_textures) {
        free(g_texture_manager->atlases);
        free(g_texture_manager);
        g_texture_manager = NULL;
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    printf("HMR Texture Manager: Initialized successfully\n");
    printf("  Texture directory: %s\n", config->texture_directory);
    printf("  Max atlases: %u\n", config->max_atlases);
    printf("  Atlas size: %ux%u\n", config->atlas_width, config->atlas_height);
    printf("  Memory budget: %.1f MB\n", config->memory_budget_mb);
    printf("  Hot-reload: %s\n", config->enable_hot_reload ? "Yes" : "No");
    printf("  Compression: %s\n", config->enable_compression ? "Yes" : "No");
    
    return HMR_SUCCESS;
}

// Register texture for tracking and atlas packing
int32_t hmr_texture_manager_register(const char* texture_path) {
    if (!g_texture_manager || !texture_path) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    // Check if already registered
    if (hmr_find_texture(texture_path)) {
        return HMR_ERROR_ALREADY_EXISTS;
    }
    
    if (g_texture_manager->texture_count >= g_texture_manager->texture_capacity) {
        printf("HMR Texture: Maximum texture capacity reached (%u)\n", g_texture_manager->texture_capacity);
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    hmr_texture_entry_t* texture = &g_texture_manager->all_textures[g_texture_manager->texture_count];
    memset(texture, 0, sizeof(hmr_texture_entry_t));
    
    // Initialize texture entry
    strncpy(texture->source_path, texture_path, sizeof(texture->source_path) - 1);
    
    // Generate texture ID from path
    const char* filename = strrchr(texture_path, '/');
    if (filename) {
        filename++; // Skip the slash
        strncpy(texture->texture_id, filename, sizeof(texture->texture_id) - 1);
        // Remove extension
        char* dot = strrchr(texture->texture_id, '.');
        if (dot) *dot = '\0';
    } else {
        strncpy(texture->texture_id, texture_path, sizeof(texture->texture_id) - 1);
    }
    
    // Load texture data
    if (!hmr_load_texture_from_file(texture_path, texture)) {
        printf("HMR Texture: Failed to load texture: %s\n", texture_path);
        return HMR_ERROR_LOAD_FAILED;
    }
    
    // Find or create atlas for this texture
    hmr_texture_atlas_t* target_atlas = NULL;
    for (uint32_t i = 0; i < g_texture_manager->atlas_count; i++) {
        hmr_texture_atlas_t* atlas = &g_texture_manager->atlases[i];
        if (atlas->texture_count < atlas->max_textures &&
            atlas->format == texture->format) {
            // Try to pack in this atlas
            if (hmr_pack_texture_in_atlas(atlas, texture)) {
                target_atlas = atlas;
                break;
            }
        }
    }
    
    // Create new atlas if needed
    if (!target_atlas) {
        target_atlas = hmr_create_texture_atlas();
        if (!target_atlas) {
            printf("HMR Texture: Failed to create atlas for texture: %s\n", texture_path);
            return HMR_ERROR_OUT_OF_MEMORY;
        }
        
        // Pack texture in new atlas
        if (!hmr_pack_texture_in_atlas(target_atlas, texture)) {
            printf("HMR Texture: Failed to pack texture in new atlas: %s\n", texture_path);
            return HMR_ERROR_NOT_SUPPORTED;
        }
    }
    
    g_texture_manager->texture_count++;
    g_texture_manager->total_gpu_memory_used += texture->gpu_memory_size;
    
    // Update memory usage ratio
    g_texture_manager->memory_usage_ratio = 
        (float)g_texture_manager->total_gpu_memory_used / g_texture_manager->memory_budget_bytes;
    
    // Check memory pressure
    if (g_texture_manager->memory_usage_ratio > 0.9f && g_texture_manager->on_memory_pressure) {
        uint64_t available = g_texture_manager->memory_budget_bytes - g_texture_manager->total_gpu_memory_used;
        g_texture_manager->on_memory_pressure(g_texture_manager->memory_usage_ratio, available);
    }
    
    printf("HMR Texture: Registered %s (ID: %s, Atlas: %u)\n", 
           texture_path, texture->texture_id, texture->atlas_index);
    
    return HMR_SUCCESS;
}

// Hot-swap texture when file changes
int32_t hmr_texture_manager_hot_swap(const char* texture_path) {
    if (!g_texture_manager || !texture_path) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    hmr_texture_entry_t* texture = hmr_find_texture(texture_path);
    if (!texture) {
        return HMR_ERROR_NOT_FOUND;
    }
    
    uint64_t start_time = mach_absolute_time();
    
    printf("HMR Texture: Hot-swapping %s\n", texture_path);
    
    // Reload texture data
    if (!hmr_load_texture_from_file(texture_path, texture)) {
        printf("HMR Texture: Failed to reload texture: %s\n", texture_path);
        return HMR_ERROR_LOAD_FAILED;
    }
    
    // Mark atlas for rebuild if texture size changed
    hmr_texture_atlas_t* atlas = &g_texture_manager->atlases[texture->atlas_index];
    if (texture->width != texture->original_width || texture->height != texture->original_height) {
        atlas->needs_rebuild = true;
        printf("HMR Texture: Atlas %u marked for rebuild due to size change\n", texture->atlas_index);
    }
    
    // Calculate reload time
    uint64_t end_time = mach_absolute_time();
    static mach_timebase_info_data_t timebase_info;
    if (timebase_info.denom == 0) {
        mach_timebase_info(&timebase_info);
    }
    uint64_t reload_time = (end_time - start_time) * timebase_info.numer / timebase_info.denom;
    
    g_texture_manager->total_reloads++;
    g_texture_manager->avg_reload_time = (g_texture_manager->avg_reload_time + reload_time) / 2;
    
    // Notify callback
    if (g_texture_manager->on_texture_loaded) {
        g_texture_manager->on_texture_loaded(texture_path, true, reload_time);
    }
    
    printf("HMR Texture: Hot-swap completed for %s (%.2f ms)\n", 
           texture_path, reload_time / 1000000.0);
    
    return HMR_SUCCESS;
}

// Process pending atlas rebuilds
int32_t hmr_texture_manager_process_rebuilds(void) {
    if (!g_texture_manager) return HMR_ERROR_NULL_POINTER;
    
    for (uint32_t i = 0; i < g_texture_manager->atlas_count; i++) {
        hmr_texture_atlas_t* atlas = &g_texture_manager->atlases[i];
        if (atlas->needs_rebuild) {
            hmr_rebuild_texture_atlas(atlas);
        }
    }
    
    return HMR_SUCCESS;
}

// Get texture atlas information
int32_t hmr_texture_manager_get_atlas_info(uint32_t atlas_id, uint32_t* width, uint32_t* height,
                                          uint32_t* texture_count, uint64_t* memory_usage) {
    if (!g_texture_manager || atlas_id >= g_texture_manager->atlas_count) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    hmr_texture_atlas_t* atlas = &g_texture_manager->atlases[atlas_id];
    
    if (width) *width = atlas->width;
    if (height) *height = atlas->height;
    if (texture_count) *texture_count = atlas->texture_count;
    if (memory_usage) *memory_usage = atlas->gpu_memory_usage;
    
    return HMR_SUCCESS;
}

// Set texture manager callbacks
void hmr_texture_manager_set_callbacks(
    void (*on_texture_loaded)(const char* path, bool success, uint64_t load_time_ns),
    void (*on_atlas_rebuilt)(uint32_t atlas_id, uint64_t rebuild_time_ns),
    void (*on_memory_pressure)(float usage_ratio, uint64_t available_bytes)
) {
    if (!g_texture_manager) return;
    
    g_texture_manager->on_texture_loaded = on_texture_loaded;
    g_texture_manager->on_atlas_rebuilt = on_atlas_rebuilt;
    g_texture_manager->on_memory_pressure = on_memory_pressure;
}

// Get texture manager statistics
void hmr_texture_manager_get_stats(
    uint32_t* total_textures,
    uint32_t* total_atlases,
    uint64_t* total_memory_used,
    float* memory_usage_ratio,
    uint64_t* total_reloads,
    uint64_t* avg_reload_time
) {
    if (!g_texture_manager) return;
    
    if (total_textures) *total_textures = g_texture_manager->texture_count;
    if (total_atlases) *total_atlases = g_texture_manager->atlas_count;
    if (total_memory_used) *total_memory_used = g_texture_manager->total_gpu_memory_used;
    if (memory_usage_ratio) *memory_usage_ratio = g_texture_manager->memory_usage_ratio;
    if (total_reloads) *total_reloads = g_texture_manager->total_reloads;
    if (avg_reload_time) *avg_reload_time = g_texture_manager->avg_reload_time;
}

// Cleanup texture manager
void hmr_texture_manager_cleanup(void) {
    if (!g_texture_manager) return;
    
    // Free atlas arrays
    for (uint32_t i = 0; i < g_texture_manager->atlas_count; i++) {
        hmr_texture_atlas_t* atlas = &g_texture_manager->atlases[i];
        if (atlas->textures) {
            free(atlas->textures);
        }
    }
    
    // Free arrays
    if (g_texture_manager->atlases) {
        free(g_texture_manager->atlases);
    }
    
    if (g_texture_manager->all_textures) {
        free(g_texture_manager->all_textures);
    }
    
    free(g_texture_manager);
    g_texture_manager = NULL;
    
    printf("HMR Texture Manager: Cleanup complete\n");
}