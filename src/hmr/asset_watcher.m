/*
 * SimCity ARM64 - Asset Watcher for HMR System
 * Hot-Reload Asset Pipeline for Non-Code Files
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Day 1: Asset Watching System Implementation
 * 
 * Performance Targets:
 * - File watching latency: <10ms
 * - Asset validation: <5ms per file
 * - Memory overhead: <1MB for 10K assets
 * - Zero allocation in hot paths
 */

#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <mach/mach_time.h>
#include "module_interface.h"

// Asset type classification for routing
typedef enum {
    HMR_ASSET_UNKNOWN = 0,
    HMR_ASSET_METAL_SHADER,     // .metal files
    HMR_ASSET_TEXTURE_2D,       // .png, .jpg, .ktx, .dds
    HMR_ASSET_TEXTURE_CUBEMAP,  // cubemap textures
    HMR_ASSET_AUDIO,            // .wav, .mp3, .aac, .caf
    HMR_ASSET_CONFIG_JSON,      // .json configuration
    HMR_ASSET_CONFIG_PLIST,     // .plist configuration
    HMR_ASSET_MODEL_3D,         // .obj, .gltf, .fbx
    HMR_ASSET_FONT,             // .ttf, .otf fonts
    HMR_ASSET_ANIMATION,        // .anim animation data
    HMR_ASSET_PARTICLE_SYSTEM,  // .particles particle definitions
    HMR_ASSET_UI_LAYOUT,        // .layout UI definitions
    HMR_ASSET_COUNT
} hmr_asset_type_t;

// Asset file status for change detection
typedef enum {
    HMR_ASSET_STATUS_UNCHANGED = 0,
    HMR_ASSET_STATUS_MODIFIED,
    HMR_ASSET_STATUS_CREATED,
    HMR_ASSET_STATUS_DELETED,
    HMR_ASSET_STATUS_RENAMED,
    HMR_ASSET_STATUS_ERROR
} hmr_asset_status_t;

// Asset dependency descriptor
typedef struct {
    char path[256];                 // Dependency file path
    uint64_t hash;                  // Content hash for validation
    uint64_t timestamp;             // Last modification time
    hmr_asset_type_t type;          // Asset type
    bool is_critical;               // Whether failure blocks reload
} hmr_asset_dependency_t;

// Asset entry in the watching system
typedef struct {
    char path[256];                 // Full file path
    char name[64];                  // Asset name/identifier
    hmr_asset_type_t type;          // Asset classification
    uint64_t file_size;             // File size in bytes
    uint64_t modification_time;     // Last modification timestamp
    uint64_t content_hash;          // Content hash for change detection
    uint32_t dependency_count;      // Number of dependencies
    hmr_asset_dependency_t* dependencies; // Array of dependencies
    void* cached_data;              // Cached processed asset data
    size_t cached_size;             // Size of cached data
    bool needs_reload;              // Whether asset needs reloading
    bool validation_failed;         // Whether last validation failed
    uint32_t reload_count;          // Number of times reloaded
    uint64_t last_reload_time;      // Timestamp of last reload
    uint64_t validation_time_ns;    // Last validation time in nanoseconds
    uint64_t reload_time_ns;        // Last reload time in nanoseconds
} hmr_asset_entry_t;

// Asset watching configuration
typedef struct {
    char watch_path[256];           // Root path to watch
    char* extensions[32];           // File extensions to watch
    uint32_t extension_count;       // Number of extensions
    bool recursive;                 // Whether to watch subdirectories
    uint32_t poll_interval_ms;      // Polling interval in milliseconds
    uint32_t max_assets;            // Maximum number of assets to track
    bool enable_validation;         // Whether to validate assets
    bool enable_caching;            // Whether to cache processed assets
} hmr_asset_watcher_config_t;

// Main asset watcher structure
typedef struct {
    // Configuration
    hmr_asset_watcher_config_t config;
    
    // Asset tracking
    hmr_asset_entry_t* assets;      // Array of tracked assets
    uint32_t asset_count;           // Current number of assets
    uint32_t asset_capacity;        // Maximum number of assets
    
    // File system watching
    FSEventStreamRef event_stream;  // macOS FSEvents stream
    CFRunLoopRef run_loop;          // Run loop for events
    NSThread* watcher_thread;       // Background watching thread
    
    // Performance metrics
    uint64_t total_watches;         // Total files being watched
    uint64_t total_events;          // Total events processed
    uint64_t total_reloads;         // Total successful reloads
    uint64_t total_errors;          // Total errors encountered
    uint64_t avg_validation_time;   // Average validation time
    uint64_t avg_reload_time;       // Average reload time
    
    // Thread safety
    dispatch_queue_t asset_queue;   // Serial queue for asset operations
    dispatch_semaphore_t semaphore; // Synchronization semaphore
    
    // Callbacks
    void (*on_asset_changed)(const char* path, hmr_asset_type_t type, hmr_asset_status_t status);
    void (*on_validation_failed)(const char* path, const char* error);
    void (*on_reload_complete)(const char* path, uint64_t reload_time_ns);
} hmr_asset_watcher_t;

// Global asset watcher instance
static hmr_asset_watcher_t* g_asset_watcher = NULL;

// Asset type detection based on file extension
static hmr_asset_type_t hmr_detect_asset_type(const char* file_path) {
    if (!file_path) return HMR_ASSET_UNKNOWN;
    
    const char* ext = strrchr(file_path, '.');
    if (!ext) return HMR_ASSET_UNKNOWN;
    
    ext++; // Skip the dot
    
    // Case-insensitive comparison
    if (strcasecmp(ext, "metal") == 0) {
        return HMR_ASSET_METAL_SHADER;
    } else if (strcasecmp(ext, "png") == 0 || strcasecmp(ext, "jpg") == 0 || 
               strcasecmp(ext, "jpeg") == 0 || strcasecmp(ext, "ktx") == 0 ||
               strcasecmp(ext, "dds") == 0) {
        return HMR_ASSET_TEXTURE_2D;
    } else if (strcasecmp(ext, "wav") == 0 || strcasecmp(ext, "mp3") == 0 ||
               strcasecmp(ext, "aac") == 0 || strcasecmp(ext, "caf") == 0) {
        return HMR_ASSET_AUDIO;
    } else if (strcasecmp(ext, "json") == 0) {
        return HMR_ASSET_CONFIG_JSON;
    } else if (strcasecmp(ext, "plist") == 0) {
        return HMR_ASSET_CONFIG_PLIST;
    } else if (strcasecmp(ext, "obj") == 0 || strcasecmp(ext, "gltf") == 0 ||
               strcasecmp(ext, "fbx") == 0) {
        return HMR_ASSET_MODEL_3D;
    } else if (strcasecmp(ext, "ttf") == 0 || strcasecmp(ext, "otf") == 0) {
        return HMR_ASSET_FONT;
    }
    
    return HMR_ASSET_UNKNOWN;
}

// Calculate content hash for file validation
static uint64_t hmr_calculate_file_hash(const char* file_path) {
    NSString* path = [NSString stringWithUTF8String:file_path];
    NSData* data = [NSData dataWithContentsOfFile:path];
    if (!data) return 0;
    
    // Simple FNV-1a hash for now (can be upgraded to more robust hashing)
    uint64_t hash = 14695981039346656037ULL; // FNV offset basis
    const uint8_t* bytes = (const uint8_t*)[data bytes];
    NSUInteger length = [data length];
    
    for (NSUInteger i = 0; i < length; i++) {
        hash ^= bytes[i];
        hash *= 1099511628211ULL; // FNV prime
    }
    
    return hash;
}

// Validate asset file integrity and format
static bool hmr_validate_asset(hmr_asset_entry_t* asset) {
    if (!asset || !asset->path[0]) return false;
    
    uint64_t start_time = mach_absolute_time();
    
    NSString* path = [NSString stringWithUTF8String:asset->path];
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    // Check if file exists
    if (![fileManager fileExistsAtPath:path]) {
        asset->validation_failed = true;
        return false;
    }
    
    // Get file attributes
    NSError* error = nil;
    NSDictionary* attributes = [fileManager attributesOfItemAtPath:path error:&error];
    if (error) {
        asset->validation_failed = true;
        return false;
    }
    
    // Update file metadata
    asset->file_size = [attributes fileSize];
    asset->modification_time = [[attributes fileModificationDate] timeIntervalSince1970] * 1000000000ULL; // nanoseconds
    
    // Type-specific validation
    bool valid = true;
    switch (asset->type) {
        case HMR_ASSET_METAL_SHADER: {
            // Validate Metal shader syntax
            NSString* content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
            if (error || !content) {
                valid = false;
            } else {
                // Basic syntax validation
                valid = [content containsString:@"#include <metal_stdlib>"] || 
                       [content containsString:@"using namespace metal"];
            }
            break;
        }
        
        case HMR_ASSET_TEXTURE_2D: {
            // Validate image format
            NSImage* image = [[NSImage alloc] initWithContentsOfFile:path];
            valid = (image != nil && image.size.width > 0 && image.size.height > 0);
            break;
        }
        
        case HMR_ASSET_CONFIG_JSON: {
            // Validate JSON syntax
            NSData* jsonData = [NSData dataWithContentsOfFile:path];
            if (jsonData) {
                NSError* jsonError = nil;
                [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
                valid = (jsonError == nil);
            } else {
                valid = false;
            }
            break;
        }
        
        case HMR_ASSET_CONFIG_PLIST: {
            // Validate plist format
            NSDictionary* plist = [NSDictionary dictionaryWithContentsOfFile:path];
            valid = (plist != nil);
            break;
        }
        
        case HMR_ASSET_AUDIO: {
            // Basic audio file validation
            NSURL* audioURL = [NSURL fileURLWithPath:path];
            valid = (audioURL != nil);
            break;
        }
        
        default:
            // For unknown types, just check file existence
            valid = true;
            break;
    }
    
    asset->validation_failed = !valid;
    
    // Calculate validation time
    uint64_t end_time = mach_absolute_time();
    static mach_timebase_info_data_t timebase_info;
    if (timebase_info.denom == 0) {
        mach_timebase_info(&timebase_info);
    }
    asset->validation_time_ns = (end_time - start_time) * timebase_info.numer / timebase_info.denom;
    
    return valid;
}

// Find asset entry by path
static hmr_asset_entry_t* hmr_find_asset(const char* path) {
    if (!g_asset_watcher || !path) return NULL;
    
    for (uint32_t i = 0; i < g_asset_watcher->asset_count; i++) {
        if (strcmp(g_asset_watcher->assets[i].path, path) == 0) {
            return &g_asset_watcher->assets[i];
        }
    }
    
    return NULL;
}

// Add new asset to tracking system
static hmr_asset_entry_t* hmr_add_asset(const char* path) {
    if (!g_asset_watcher || !path) return NULL;
    
    if (g_asset_watcher->asset_count >= g_asset_watcher->asset_capacity) {
        NSLog(@"HMR Asset Watcher: Maximum asset capacity reached (%u)", g_asset_watcher->asset_capacity);
        return NULL;
    }
    
    hmr_asset_entry_t* asset = &g_asset_watcher->assets[g_asset_watcher->asset_count++];
    memset(asset, 0, sizeof(hmr_asset_entry_t));
    
    // Initialize asset entry
    strncpy(asset->path, path, sizeof(asset->path) - 1);
    
    // Extract asset name from path
    const char* name = strrchr(path, '/');
    if (name) {
        name++; // Skip the slash
        strncpy(asset->name, name, sizeof(asset->name) - 1);
    } else {
        strncpy(asset->name, path, sizeof(asset->name) - 1);
    }
    
    // Detect asset type
    asset->type = hmr_detect_asset_type(path);
    
    // Calculate initial content hash
    asset->content_hash = hmr_calculate_file_hash(path);
    
    // Validate asset
    hmr_validate_asset(asset);
    
    return asset;
}

// FSEvents callback for file system changes
static void hmr_fsevent_callback(
    ConstFSEventStreamRef streamRef,
    void* clientCallBackInfo,
    size_t numEvents,
    void* eventPaths,
    const FSEventStreamEventFlags eventFlags[],
    const FSEventStreamEventId eventIds[]
) {
    if (!g_asset_watcher) return;
    
    char** paths = (char**)eventPaths;
    
    for (size_t i = 0; i < numEvents; i++) {
        const char* path = paths[i];
        FSEventStreamEventFlags flags = eventFlags[i];
        
        // Skip non-relevant events
        if (flags & kFSEventStreamEventFlagHistoryDone) continue;
        
        // Detect asset type to see if we should track it
        hmr_asset_type_t type = hmr_detect_asset_type(path);
        if (type == HMR_ASSET_UNKNOWN) continue;
        
        // Determine status
        hmr_asset_status_t status = HMR_ASSET_STATUS_UNCHANGED;
        if (flags & kFSEventStreamEventFlagItemCreated) {
            status = HMR_ASSET_STATUS_CREATED;
        } else if (flags & kFSEventStreamEventFlagItemRemoved) {
            status = HMR_ASSET_STATUS_DELETED;
        } else if (flags & kFSEventStreamEventFlagItemRenamed) {
            status = HMR_ASSET_STATUS_RENAMED;
        } else if (flags & kFSEventStreamEventFlagItemModified) {
            status = HMR_ASSET_STATUS_MODIFIED;
        }
        
        // Process the change on the asset queue
        dispatch_async(g_asset_watcher->asset_queue, ^{
            hmr_asset_entry_t* asset = hmr_find_asset(path);
            
            if (status == HMR_ASSET_STATUS_CREATED && !asset) {
                // Add new asset
                asset = hmr_add_asset(path);
                if (asset) {
                    NSLog(@"HMR: New asset detected: %s (type: %d)", path, type);
                }
            } else if (status == HMR_ASSET_STATUS_DELETED && asset) {
                // Mark asset as needing cleanup
                asset->needs_reload = false;
                NSLog(@"HMR: Asset deleted: %s", path);
            } else if (asset) {
                // Check if content actually changed
                uint64_t new_hash = hmr_calculate_file_hash(path);
                if (new_hash != asset->content_hash) {
                    asset->content_hash = new_hash;
                    asset->needs_reload = true;
                    
                    // Validate the changed asset
                    if (hmr_validate_asset(asset)) {
                        NSLog(@"HMR: Asset changed and validated: %s", path);
                    } else {
                        NSLog(@"HMR: Asset changed but validation failed: %s", path);
                    }
                }
            }
            
            // Notify callback if registered
            if (g_asset_watcher->on_asset_changed) {
                g_asset_watcher->on_asset_changed(path, type, status);
            }
            
            g_asset_watcher->total_events++;
        });
    }
}

// Initialize asset watcher system
int32_t hmr_asset_watcher_init(const hmr_asset_watcher_config_t* config) {
    if (g_asset_watcher) {
        NSLog(@"HMR Asset Watcher: Already initialized");
        return HMR_ERROR_ALREADY_EXISTS;
    }
    
    if (!config) {
        NSLog(@"HMR Asset Watcher: Invalid configuration");
        return HMR_ERROR_INVALID_ARG;
    }
    
    // Allocate watcher structure
    g_asset_watcher = calloc(1, sizeof(hmr_asset_watcher_t));
    if (!g_asset_watcher) {
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    // Copy configuration
    memcpy(&g_asset_watcher->config, config, sizeof(hmr_asset_watcher_config_t));
    
    // Allocate asset array
    g_asset_watcher->asset_capacity = config->max_assets;
    g_asset_watcher->assets = calloc(g_asset_watcher->asset_capacity, sizeof(hmr_asset_entry_t));
    if (!g_asset_watcher->assets) {
        free(g_asset_watcher);
        g_asset_watcher = NULL;
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    // Create dispatch queue for thread safety
    g_asset_watcher->asset_queue = dispatch_queue_create("com.simcity.hmr.assets", DISPATCH_QUEUE_SERIAL);
    g_asset_watcher->semaphore = dispatch_semaphore_create(1);
    
    NSLog(@"HMR Asset Watcher: Initialized successfully");
    NSLog(@"  Watch path: %s", config->watch_path);
    NSLog(@"  Max assets: %u", config->max_assets);
    NSLog(@"  Recursive: %s", config->recursive ? "Yes" : "No");
    
    return HMR_SUCCESS;
}

// Start watching for file changes
int32_t hmr_asset_watcher_start(void) {
    if (!g_asset_watcher) {
        return HMR_ERROR_NULL_POINTER;
    }
    
    NSString* watchPath = [NSString stringWithUTF8String:g_asset_watcher->config.watch_path];
    NSArray* pathsToWatch = @[watchPath];
    
    // Create FSEvent stream
    FSEventStreamContext context = {0, NULL, NULL, NULL, NULL};
    g_asset_watcher->event_stream = FSEventStreamCreate(
        NULL,
        &hmr_fsevent_callback,
        &context,
        (__bridge CFArrayRef)pathsToWatch,
        kFSEventStreamEventIdSinceNow,
        0.1, // 100ms latency
        kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes
    );
    
    if (!g_asset_watcher->event_stream) {
        NSLog(@"HMR Asset Watcher: Failed to create FSEvent stream");
        return HMR_ERROR_NOT_SUPPORTED;
    }
    
    // Start watching on background thread
    g_asset_watcher->watcher_thread = [[NSThread alloc] initWithTarget:[NSBlockOperation blockOperationWithBlock:^{
        g_asset_watcher->run_loop = CFRunLoopGetCurrent();
        FSEventStreamScheduleWithRunLoop(g_asset_watcher->event_stream, g_asset_watcher->run_loop, kCFRunLoopDefaultMode);
        FSEventStreamStart(g_asset_watcher->event_stream);
        CFRunLoopRun();
    }] selector:@selector(main) object:nil];
    
    [g_asset_watcher->watcher_thread start];
    
    NSLog(@"HMR Asset Watcher: Started watching %s", g_asset_watcher->config.watch_path);
    return HMR_SUCCESS;
}

// Stop asset watching
int32_t hmr_asset_watcher_stop(void) {
    if (!g_asset_watcher) {
        return HMR_ERROR_NULL_POINTER;
    }
    
    if (g_asset_watcher->event_stream) {
        FSEventStreamStop(g_asset_watcher->event_stream);
        FSEventStreamInvalidate(g_asset_watcher->event_stream);
        FSEventStreamRelease(g_asset_watcher->event_stream);
        g_asset_watcher->event_stream = NULL;
    }
    
    if (g_asset_watcher->run_loop) {
        CFRunLoopStop(g_asset_watcher->run_loop);
        g_asset_watcher->run_loop = NULL;
    }
    
    if (g_asset_watcher->watcher_thread) {
        [g_asset_watcher->watcher_thread cancel];
        g_asset_watcher->watcher_thread = nil;
    }
    
    NSLog(@"HMR Asset Watcher: Stopped");
    return HMR_SUCCESS;
}

// Cleanup asset watcher
void hmr_asset_watcher_cleanup(void) {
    if (!g_asset_watcher) return;
    
    hmr_asset_watcher_stop();
    
    // Cleanup assets
    for (uint32_t i = 0; i < g_asset_watcher->asset_count; i++) {
        hmr_asset_entry_t* asset = &g_asset_watcher->assets[i];
        if (asset->dependencies) {
            free(asset->dependencies);
        }
        if (asset->cached_data) {
            free(asset->cached_data);
        }
    }
    
    if (g_asset_watcher->assets) {
        free(g_asset_watcher->assets);
    }
    
    if (g_asset_watcher->asset_queue) {
        // Note: dispatch queues are ARC managed in modern Objective-C
        g_asset_watcher->asset_queue = nil;
    }
    
    if (g_asset_watcher->semaphore) {
        // Note: dispatch semaphores are ARC managed in modern Objective-C
        g_asset_watcher->semaphore = nil;
    }
    
    free(g_asset_watcher);
    g_asset_watcher = NULL;
    
    NSLog(@"HMR Asset Watcher: Cleanup complete");
}

// Get list of assets that need reloading
int32_t hmr_asset_watcher_get_pending_reloads(const char** paths, uint32_t max_count, uint32_t* actual_count) {
    if (!g_asset_watcher || !paths || !actual_count) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    *actual_count = 0;
    
    for (uint32_t i = 0; i < g_asset_watcher->asset_count && *actual_count < max_count; i++) {
        if (g_asset_watcher->assets[i].needs_reload && !g_asset_watcher->assets[i].validation_failed) {
            paths[*actual_count] = g_asset_watcher->assets[i].path;
            (*actual_count)++;
        }
    }
    
    return HMR_SUCCESS;
}

// Mark asset as reloaded
int32_t hmr_asset_watcher_mark_reloaded(const char* path, uint64_t reload_time_ns) {
    if (!g_asset_watcher || !path) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    hmr_asset_entry_t* asset = hmr_find_asset(path);
    if (!asset) {
        return HMR_ERROR_NOT_FOUND;
    }
    
    asset->needs_reload = false;
    asset->reload_count++;
    asset->last_reload_time = mach_absolute_time();
    asset->reload_time_ns = reload_time_ns;
    
    // Update global statistics
    g_asset_watcher->total_reloads++;
    g_asset_watcher->avg_reload_time = (g_asset_watcher->avg_reload_time + reload_time_ns) / 2;
    
    // Notify callback if registered
    if (g_asset_watcher->on_reload_complete) {
        g_asset_watcher->on_reload_complete(path, reload_time_ns);
    }
    
    return HMR_SUCCESS;
}

// Register callbacks for asset events
void hmr_asset_watcher_set_callbacks(
    void (*on_changed)(const char* path, hmr_asset_type_t type, hmr_asset_status_t status),
    void (*on_validation_failed)(const char* path, const char* error),
    void (*on_reload_complete)(const char* path, uint64_t reload_time_ns)
) {
    if (!g_asset_watcher) return;
    
    g_asset_watcher->on_asset_changed = on_changed;
    g_asset_watcher->on_validation_failed = on_validation_failed;
    g_asset_watcher->on_reload_complete = on_reload_complete;
}

// Get asset watcher statistics
void hmr_asset_watcher_get_stats(
    uint32_t* total_assets,
    uint32_t* pending_reloads,
    uint64_t* total_events,
    uint64_t* avg_validation_time,
    uint64_t* avg_reload_time
) {
    if (!g_asset_watcher) return;
    
    if (total_assets) {
        *total_assets = g_asset_watcher->asset_count;
    }
    
    if (pending_reloads) {
        uint32_t count = 0;
        for (uint32_t i = 0; i < g_asset_watcher->asset_count; i++) {
            if (g_asset_watcher->assets[i].needs_reload) {
                count++;
            }
        }
        *pending_reloads = count;
    }
    
    if (total_events) {
        *total_events = g_asset_watcher->total_events;
    }
    
    if (avg_validation_time) {
        *avg_validation_time = g_asset_watcher->avg_validation_time;
    }
    
    if (avg_reload_time) {
        *avg_reload_time = g_asset_watcher->avg_reload_time;
    }
}