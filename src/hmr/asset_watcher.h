/*
 * SimCity ARM64 - Asset Watcher Header
 * Hot-Reload Asset Pipeline Interface
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Day 1: Asset Watching System Interface
 */

#ifndef HMR_ASSET_WATCHER_H
#define HMR_ASSET_WATCHER_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Forward declarations from asset_watcher.m
typedef enum {
    HMR_ASSET_UNKNOWN = 0,
    HMR_ASSET_METAL_SHADER,
    HMR_ASSET_TEXTURE_2D,
    HMR_ASSET_TEXTURE_CUBEMAP,
    HMR_ASSET_AUDIO,
    HMR_ASSET_CONFIG_JSON,
    HMR_ASSET_CONFIG_PLIST,
    HMR_ASSET_MODEL_3D,
    HMR_ASSET_FONT,
    HMR_ASSET_ANIMATION,
    HMR_ASSET_PARTICLE_SYSTEM,
    HMR_ASSET_UI_LAYOUT,
    HMR_ASSET_COUNT
} hmr_asset_type_t;

typedef enum {
    HMR_ASSET_STATUS_UNCHANGED = 0,
    HMR_ASSET_STATUS_MODIFIED,
    HMR_ASSET_STATUS_CREATED,
    HMR_ASSET_STATUS_DELETED,
    HMR_ASSET_STATUS_RENAMED,
    HMR_ASSET_STATUS_ERROR
} hmr_asset_status_t;

typedef struct {
    char watch_path[256];
    char* extensions[32];
    uint32_t extension_count;
    bool recursive;
    uint32_t poll_interval_ms;
    uint32_t max_assets;
    bool enable_validation;
    bool enable_caching;
} hmr_asset_watcher_config_t;

// Asset watcher API functions
int32_t hmr_asset_watcher_init(const hmr_asset_watcher_config_t* config);
int32_t hmr_asset_watcher_start(void);
int32_t hmr_asset_watcher_stop(void);
void hmr_asset_watcher_cleanup(void);

// Asset status management
int32_t hmr_asset_watcher_get_pending_reloads(const char** paths, uint32_t max_count, uint32_t* actual_count);
int32_t hmr_asset_watcher_mark_reloaded(const char* path, uint64_t reload_time_ns);

// Callback registration
void hmr_asset_watcher_set_callbacks(
    void (*on_changed)(const char* path, hmr_asset_type_t type, hmr_asset_status_t status),
    void (*on_validation_failed)(const char* path, const char* error),
    void (*on_reload_complete)(const char* path, uint64_t reload_time_ns)
);

// Statistics and monitoring
void hmr_asset_watcher_get_stats(
    uint32_t* total_assets,
    uint32_t* pending_reloads,
    uint64_t* total_events,
    uint64_t* avg_validation_time,
    uint64_t* avg_reload_time
);

#ifdef __cplusplus
}
#endif

#endif // HMR_ASSET_WATCHER_H