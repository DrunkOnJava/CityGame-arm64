/*
 * SimCity ARM64 - Advanced Shader Variant Manager Implementation
 * Intelligent Quality-Level Shader Hot-Swapping System
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Week 2 - Day 6: Advanced Shader Features
 * 
 * Performance Targets:
 * - Variant compilation: <100ms (improved from <200ms)
 * - Quality switching: <5ms
 * - Hot-swap with zero frame drops
 * - Adaptive quality response: <1 second
 */

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include <mach/mach_time.h>
#include <sys/stat.h>
#include "shader_variant_manager.h"
#include "shader_manager.h"
#include "module_interface.h"

// Maximum number of shader variant groups
#define MAX_SHADER_GROUPS 128

// Adaptive quality tuning constants
#define PERFORMANCE_SAMPLE_COUNT 16
#define QUALITY_ADAPTATION_HYSTERESIS 0.1f
#define GPU_UTILIZATION_THRESHOLD_UP 0.85f
#define GPU_UTILIZATION_THRESHOLD_DOWN 0.65f
#define FRAME_TIME_THRESHOLD_UP 1.1f
#define FRAME_TIME_THRESHOLD_DOWN 0.9f

// Variant manager state
typedef struct {
    hmr_variant_manager_config_t config;
    id<MTLDevice> device;
    id<MTLCommandQueue> command_queue;
    
    // Shader groups
    hmr_shader_variant_group_t shader_groups[MAX_SHADER_GROUPS];
    uint32_t group_count;
    
    // Global performance tracking
    hmr_performance_metrics_t current_metrics;
    hmr_performance_metrics_t metrics_history[PERFORMANCE_SAMPLE_COUNT];
    uint32_t metrics_history_index;
    
    // Adaptive quality state
    hmr_shader_quality_t global_quality;
    float adaptation_timer;
    bool is_adapting;
    
    // Compilation state
    dispatch_queue_t compile_queue;
    dispatch_group_t compile_group;
    uint32_t active_compilations;
    
    // Statistics
    uint64_t total_compilations;
    uint64_t cache_hits;
    uint64_t cache_misses;
    uint64_t quality_changes;
    
    // Callbacks
    void (*on_quality_changed)(const char* shader_name, hmr_shader_quality_t old_quality, hmr_shader_quality_t new_quality);
    void (*on_variant_compiled)(const char* shader_name, hmr_shader_quality_t quality, bool success, uint64_t compile_time_ns);
    void (*on_adaptive_change)(hmr_shader_quality_t new_global_quality, float performance_factor);
} hmr_variant_manager_t;

// Global manager instance
static hmr_variant_manager_t* g_variant_manager = NULL;

// Quality level configuration templates
static const struct {
    hmr_shader_quality_t quality;
    const char* defines;
    hmr_shader_variant_flags_t flags;
    float performance_weight;
    float quality_score;
    struct {
        uint32_t max_texture_size;
        uint32_t max_shadow_samples;
        uint32_t max_light_count;
        bool enable_reflections;
        bool enable_ambient_occlusion;
        bool enable_bloom;
        bool enable_antialiasing;
        float lod_bias;
    } params;
} g_quality_templates[] = {
    {
        HMR_QUALITY_LOW,
        "QUALITY_LOW=1;MAX_LIGHTS=4;SHADOW_SAMPLES=1;DISABLE_REFLECTIONS=1;DISABLE_AO=1;DISABLE_BLOOM=1",
        HMR_VARIANT_FLAG_FAST_MATH | HMR_VARIANT_FLAG_NO_BRANCHING | HMR_VARIANT_FLAG_REDUCED_PRECISION,
        0.25f, 0.3f,
        { 512, 1, 4, false, false, false, false, 1.0f }
    },
    {
        HMR_QUALITY_MEDIUM,
        "QUALITY_MEDIUM=1;MAX_LIGHTS=8;SHADOW_SAMPLES=4;ENABLE_BASIC_REFLECTIONS=1;DISABLE_AO=1",
        HMR_VARIANT_FLAG_FAST_MATH | HMR_VARIANT_FLAG_REDUCED_PRECISION,
        0.5f, 0.6f,
        { 1024, 4, 8, true, false, true, false, 0.5f }
    },
    {
        HMR_QUALITY_HIGH,
        "QUALITY_HIGH=1;MAX_LIGHTS=16;SHADOW_SAMPLES=9;ENABLE_REFLECTIONS=1;ENABLE_AO=1;ENABLE_BLOOM=1",
        HMR_VARIANT_FLAG_FAST_MATH,
        0.8f, 0.85f,
        { 2048, 9, 16, true, true, true, true, 0.0f }
    },
    {
        HMR_QUALITY_ULTRA,
        "QUALITY_ULTRA=1;MAX_LIGHTS=32;SHADOW_SAMPLES=16;ENABLE_REFLECTIONS=1;ENABLE_AO=1;ENABLE_BLOOM=1;ENABLE_ADVANCED_EFFECTS=1",
        HMR_VARIANT_FLAG_NONE,
        1.0f, 1.0f,
        { 4096, 16, 32, true, true, true, true, -0.5f }
    }
};

// Utility functions
static uint64_t hmr_get_time_ns(void) {
    static mach_timebase_info_data_t timebase_info;
    if (timebase_info.denom == 0) {
        mach_timebase_info(&timebase_info);
    }
    return mach_absolute_time() * timebase_info.numer / timebase_info.denom;
}

static hmr_shader_variant_group_t* hmr_find_shader_group(const char* shader_name) {
    if (!g_variant_manager || !shader_name) return NULL;
    
    for (uint32_t i = 0; i < g_variant_manager->group_count; i++) {
        if (strcmp(g_variant_manager->shader_groups[i].shader_name, shader_name) == 0) {
            return &g_variant_manager->shader_groups[i];
        }
    }
    
    return NULL;
}

static hmr_shader_variant_t* hmr_get_variant(hmr_shader_variant_group_t* group, hmr_shader_quality_t quality) {
    if (!group || quality >= HMR_QUALITY_COUNT) return NULL;
    return &group->variants[quality];
}

// Generate cache key for variant
static void hmr_generate_cache_key(const char* shader_name, hmr_shader_quality_t quality, 
                                   const char* defines, char* cache_key, size_t key_size) {
    // Create hash of shader name, quality, and defines
    uint32_t hash = 0;
    const char* str = shader_name;
    while (*str) {
        hash = hash * 31 + *str++;
    }
    hash = hash * 31 + (uint32_t)quality;
    str = defines;
    while (*str) {
        hash = hash * 31 + *str++;
    }
    
    snprintf(cache_key, key_size, "shader_%08x_q%d.metallib", hash, quality);
}

// Load cached variant from disk
static bool hmr_load_cached_variant(hmr_shader_variant_t* variant, const char* shader_name) {
    if (!g_variant_manager->config.enable_persistent_cache) return false;
    
    char cache_key[128];
    hmr_generate_cache_key(shader_name, variant->quality_level, variant->preprocessor_defines, 
                          cache_key, sizeof(cache_key));
    
    char cache_path[512];
    snprintf(cache_path, sizeof(cache_path), "%s/%s", g_variant_manager->config.cache_directory, cache_key);
    
    // Check if cache file exists and is newer than source
    struct stat cache_stat, source_stat;
    if (stat(cache_path, &cache_stat) != 0) {
        return false; // Cache file doesn't exist
    }
    
    // For now, assume source is newer - in real implementation, compare timestamps
    // stat(variant->base_path, &source_stat);
    // if (cache_stat.st_mtime < source_stat.st_mtime) return false;
    
    // Load cached binary
    NSString* cachePath = [NSString stringWithUTF8String:cache_path];
    NSError* error = nil;
    NSData* cachedData = [NSData dataWithContentsOfFile:cachePath options:0 error:&error];
    
    if (error || !cachedData) {
        return false;
    }
    
    // Create library from cached data
    variant->library = [g_variant_manager->device newLibraryWithData:cachedData error:&error];
    if (error || !variant->library) {
        return false;
    }
    
    // Extract function (assume function name matches variant name or is derived)
    NSString* functionName = [NSString stringWithUTF8String:variant->variant_name];
    variant->function = [variant->library newFunctionWithName:functionName];
    
    if (!variant->function) {
        // Try common function names
        variant->function = [variant->library newFunctionWithName:@"main_vertex"];
        if (!variant->function) {
            variant->function = [variant->library newFunctionWithName:@"main_fragment"];
        }
        if (!variant->function) {
            variant->function = [variant->library newFunctionWithName:@"main_compute"];
        }
    }
    
    if (variant->function) {
        variant->is_compiled = true;
        variant->binary_size = cachedData.length;
        g_variant_manager->cache_hits++;
        
        NSLog(@"HMR Variant: Loaded cached variant %s:%s (%zu bytes)", 
              shader_name, variant->variant_name, variant->binary_size);
        return true;
    }
    
    return false;
}

// Save compiled variant to cache
static void hmr_save_cached_variant(const hmr_shader_variant_t* variant, const char* shader_name) {
    if (!g_variant_manager->config.enable_persistent_cache || !variant->library) return;
    
    char cache_key[128];
    hmr_generate_cache_key(shader_name, variant->quality_level, variant->preprocessor_defines,
                          cache_key, sizeof(cache_key));
    
    char cache_path[512];
    snprintf(cache_path, sizeof(cache_path), "%s/%s", g_variant_manager->config.cache_directory, cache_key);
    
    // Create cache directory if it doesn't exist
    NSString* cacheDir = [NSString stringWithUTF8String:g_variant_manager->config.cache_directory];
    [[NSFileManager defaultManager] createDirectoryAtPath:cacheDir 
                              withIntermediateDirectories:YES 
                                               attributes:nil 
                                                    error:nil];
    
    // Get library data (this is simplified - real implementation would need to serialize properly)
    NSString* cachePath = [NSString stringWithUTF8String:cache_path];
    // Note: MTLLibrary doesn't directly expose binary data in iOS/macOS
    // In a real implementation, you'd need to save the compiled source or use other methods
    NSLog(@"HMR Variant: Would save cached variant %s:%s to %s", 
          shader_name, variant->variant_name, cache_path);
}

// Compile a specific variant
static bool hmr_compile_variant(hmr_shader_variant_group_t* group, hmr_shader_quality_t quality) {
    hmr_shader_variant_t* variant = hmr_get_variant(group, quality);
    if (!variant) return false;
    
    uint64_t start_time = hmr_get_time_ns();
    
    // Try loading from cache first
    if (hmr_load_cached_variant(variant, group->shader_name)) {
        variant->compile_time_ns = hmr_get_time_ns() - start_time;
        return true;
    }
    
    g_variant_manager->cache_misses++;
    
    // Load shader source
    NSString* sourcePath = [NSString stringWithUTF8String:group->base_shader_path];
    NSError* error = nil;
    NSString* sourceCode = [NSString stringWithContentsOfFile:sourcePath 
                                                      encoding:NSUTF8StringEncoding 
                                                         error:&error];
    
    if (error || !sourceCode) {
        snprintf(variant->last_error, sizeof(variant->last_error), 
                "Failed to read source: %s", [error.localizedDescription UTF8String]);
        return false;
    }
    
    // Prepend preprocessor defines
    NSString* defines = [NSString stringWithUTF8String:variant->preprocessor_defines];
    NSMutableString* finalSource = [NSMutableString stringWithString:@"#version 300 es\n"];
    
    // Add defines
    NSArray* defineList = [defines componentsSeparatedByString:@";"];
    for (NSString* define in defineList) {
        if (define.length > 0) {
            [finalSource appendFormat:@"#define %@\n", define];
        }
    }
    
    [finalSource appendString:sourceCode];
    
    // Create compilation options
    MTLCompileOptions* options = [[MTLCompileOptions alloc] init];
    options.fastMathEnabled = (variant->flags & HMR_VARIANT_FLAG_FAST_MATH) != 0;
    
    // Compile Metal library
    variant->library = [g_variant_manager->device newLibraryWithSource:finalSource 
                                                               options:options 
                                                                 error:&error];
    
    if (error || !variant->library) {
        snprintf(variant->last_error, sizeof(variant->last_error),
                "Compilation failed: %s", [error.localizedDescription UTF8String]);
        return false;
    }
    
    // Get the main function (simplified - real implementation would parse for function names)
    variant->function = [variant->library newFunctionWithName:@"main_vertex"];
    if (!variant->function) {
        variant->function = [variant->library newFunctionWithName:@"main_fragment"];
    }
    if (!variant->function) {
        variant->function = [variant->library newFunctionWithName:@"main_compute"];
    }
    
    if (!variant->function) {
        snprintf(variant->last_error, sizeof(variant->last_error), "No valid entry point found");
        return false;
    }
    
    // Create pipeline states (simplified)
    if ([variant->function functionType] == MTLFunctionTypeVertex || 
        [variant->function functionType] == MTLFunctionTypeFragment) {
        
        MTLRenderPipelineDescriptor* pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineDesc.vertexFunction = variant->function;
        pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        
        variant->render_pipeline = [g_variant_manager->device newRenderPipelineStateWithDescriptor:pipelineDesc 
                                                                                              error:&error];
        if (error) {
            snprintf(variant->last_error, sizeof(variant->last_error),
                    "Pipeline creation failed: %s", [error.localizedDescription UTF8String]);
            return false;
        }
    } else if ([variant->function functionType] == MTLFunctionTypeKernel) {
        variant->compute_pipeline = [g_variant_manager->device newComputePipelineStateWithFunction:variant->function 
                                                                                               error:&error];
        if (error) {
            snprintf(variant->last_error, sizeof(variant->last_error),
                    "Compute pipeline creation failed: %s", [error.localizedDescription UTF8String]);
            return false;
        }
    }
    
    // Finalize compilation
    variant->compile_time_ns = hmr_get_time_ns() - start_time;
    variant->is_compiled = true;
    variant->last_error[0] = '\0';
    
    g_variant_manager->total_compilations++;
    
    // Save to cache
    hmr_save_cached_variant(variant, group->shader_name);
    
    NSLog(@"HMR Variant: Compiled %s:%s in %.2f ms", 
          group->shader_name, variant->variant_name, variant->compile_time_ns / 1000000.0);
    
    return true;
}

// Calculate performance score for quality adaptation
static float hmr_calculate_performance_score(const hmr_performance_metrics_t* metrics) {
    float score = 1.0f;
    
    // Frame time impact (higher is worse)
    if (metrics->target_frame_time_ms > 0) {
        float frame_time_ratio = metrics->frame_time_ms / metrics->target_frame_time_ms;
        score *= (2.0f - frame_time_ratio); // Score decreases as frame time increases
    }
    
    // GPU utilization impact
    score *= (1.0f - metrics->gpu_utilization * 0.5f); // Reduce score with high GPU usage
    
    // Memory pressure impact
    score *= (1.0f - metrics->memory_pressure * 0.3f);
    
    // Thermal throttling impact
    score *= (1.0f - (1.0f - metrics->thermal_state) * 0.4f);
    
    // Dropped frames penalty
    if (metrics->dropped_frames > 0) {
        score *= (1.0f - metrics->dropped_frames * 0.1f);
    }
    
    return fmaxf(0.0f, score);
}

// Update adaptive quality based on performance
static void hmr_update_adaptive_quality(void) {
    if (!g_variant_manager->config.enable_adaptive_quality) return;
    
    hmr_performance_metrics_t* current = &g_variant_manager->current_metrics;
    float performance_score = hmr_calculate_performance_score(current);
    
    hmr_shader_quality_t target_quality = g_variant_manager->global_quality;
    
    // Determine if we should change quality
    if (performance_score < 0.7f && target_quality > g_variant_manager->config.min_quality) {
        // Performance is poor, consider downgrading
        target_quality = (hmr_shader_quality_t)(target_quality - 1);
    } else if (performance_score > 0.9f && target_quality < g_variant_manager->config.max_quality) {
        // Performance is good, consider upgrading
        target_quality = (hmr_shader_quality_t)(target_quality + 1);
    }
    
    // Apply quality change if needed
    if (target_quality != g_variant_manager->global_quality) {
        hmr_shader_quality_t old_quality = g_variant_manager->global_quality;
        g_variant_manager->global_quality = target_quality;
        g_variant_manager->quality_changes++;
        
        // Update all shader groups to new quality
        for (uint32_t i = 0; i < g_variant_manager->group_count; i++) {
            hmr_shader_variant_group_t* group = &g_variant_manager->shader_groups[i];
            if (group->active_quality != target_quality) {
                group->target_quality = target_quality;
                group->is_transitioning = true;
            }
        }
        
        // Call callback if registered
        if (g_variant_manager->on_adaptive_change) {
            g_variant_manager->on_adaptive_change(target_quality, performance_score);
        }
        
        NSLog(@"HMR Variant: Adaptive quality changed from %s to %s (score: %.2f)",
              hmr_variant_quality_to_string(old_quality),
              hmr_variant_quality_to_string(target_quality),
              performance_score);
    }
}

// Public API implementation

int32_t hmr_variant_manager_init(const hmr_variant_manager_config_t* config, id<MTLDevice> device) {
    if (g_variant_manager) {
        return HMR_ERROR_ALREADY_EXISTS;
    }
    
    if (!config || !device) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    g_variant_manager = calloc(1, sizeof(hmr_variant_manager_t));
    if (!g_variant_manager) {
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    // Copy configuration
    memcpy(&g_variant_manager->config, config, sizeof(hmr_variant_manager_config_t));
    
    // Set Metal context
    g_variant_manager->device = device;
    g_variant_manager->command_queue = [device newCommandQueue];
    
    // Initialize state
    g_variant_manager->global_quality = config->default_quality;
    g_variant_manager->adaptation_timer = 0.0f;
    
    // Create dispatch queues
    g_variant_manager->compile_queue = dispatch_queue_create("com.simcity.hmr.variant_compile", 
                                                            DISPATCH_QUEUE_CONCURRENT);
    g_variant_manager->compile_group = dispatch_group_create();
    
    NSLog(@"HMR Variant Manager: Initialized successfully");
    NSLog(@"  Default quality: %s", hmr_variant_quality_to_string(config->default_quality));
    NSLog(@"  Adaptive quality: %s", config->enable_adaptive_quality ? "Yes" : "No");
    NSLog(@"  Cache directory: %s", config->cache_directory);
    
    return HMR_SUCCESS;
}

int32_t hmr_variant_register_shader(const char* shader_path, const char* shader_name) {
    if (!g_variant_manager || !shader_path || !shader_name) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    if (hmr_find_shader_group(shader_name)) {
        return HMR_ERROR_ALREADY_EXISTS;
    }
    
    if (g_variant_manager->group_count >= MAX_SHADER_GROUPS) {
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    hmr_shader_variant_group_t* group = &g_variant_manager->shader_groups[g_variant_manager->group_count++];
    memset(group, 0, sizeof(hmr_shader_variant_group_t));
    
    // Initialize group
    strncpy(group->base_shader_path, shader_path, sizeof(group->base_shader_path) - 1);
    strncpy(group->shader_name, shader_name, sizeof(group->shader_name) - 1);
    group->active_quality = g_variant_manager->global_quality;
    group->target_quality = g_variant_manager->global_quality;
    
    // Create variants for all quality levels using templates
    for (int i = 0; i < sizeof(g_quality_templates) / sizeof(g_quality_templates[0]); i++) {
        hmr_shader_variant_t* variant = &group->variants[g_quality_templates[i].quality];
        
        snprintf(variant->variant_name, sizeof(variant->variant_name), "%s_%s", 
                shader_name, hmr_variant_quality_to_string(g_quality_templates[i].quality));
        
        strncpy(variant->preprocessor_defines, g_quality_templates[i].defines, 
               sizeof(variant->preprocessor_defines) - 1);
        
        variant->quality_level = g_quality_templates[i].quality;
        variant->flags = g_quality_templates[i].flags;
        variant->performance_weight = g_quality_templates[i].performance_weight;
        variant->quality_score = g_quality_templates[i].quality_score;
        variant->quality_params = g_quality_templates[i].params;
        
        group->variant_count++;
    }
    
    NSLog(@"HMR Variant: Registered shader '%s' with %u variants", shader_name, group->variant_count);
    
    return HMR_SUCCESS;
}

int32_t hmr_variant_compile_all(const char* shader_name) {
    hmr_shader_variant_group_t* group = hmr_find_shader_group(shader_name);
    if (!group) {
        return HMR_ERROR_NOT_FOUND;
    }
    
    bool all_success = true;
    
    for (hmr_shader_quality_t quality = 0; quality < HMR_QUALITY_COUNT; quality++) {
        if (quality == HMR_QUALITY_ADAPTIVE) continue; // Skip adaptive pseudo-quality
        
        hmr_shader_variant_t* variant = hmr_get_variant(group, quality);
        if (variant && !variant->is_compiled) {
            if (!hmr_compile_variant(group, quality)) {
                all_success = false;
            }
        }
    }
    
    return all_success ? HMR_SUCCESS : HMR_ERROR_COMPILATION_FAILED;
}

int32_t hmr_variant_set_quality(const char* shader_name, hmr_shader_quality_t quality) {
    hmr_shader_variant_group_t* group = hmr_find_shader_group(shader_name);
    if (!group) {
        return HMR_ERROR_NOT_FOUND;
    }
    
    if (quality >= HMR_QUALITY_COUNT || quality == HMR_QUALITY_ADAPTIVE) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    hmr_shader_quality_t old_quality = group->active_quality;
    group->target_quality = quality;
    
    // Compile variant if not already compiled
    hmr_shader_variant_t* variant = hmr_get_variant(group, quality);
    if (variant && !variant->is_compiled) {
        hmr_compile_variant(group, quality);
    }
    
    // Switch immediately if compiled
    if (variant && variant->is_compiled) {
        group->active_quality = quality;
        group->is_transitioning = false;
        
        // Call callback if registered
        if (g_variant_manager->on_quality_changed) {
            g_variant_manager->on_quality_changed(shader_name, old_quality, quality);
        }
    } else {
        group->is_transitioning = true;
    }
    
    return HMR_SUCCESS;
}

id<MTLRenderPipelineState> hmr_variant_get_render_pipeline(const char* shader_name) {
    hmr_shader_variant_group_t* group = hmr_find_shader_group(shader_name);
    if (!group) return nil;
    
    hmr_shader_variant_t* variant = hmr_get_variant(group, group->active_quality);
    if (variant && variant->is_compiled) {
        return variant->render_pipeline;
    }
    
    return nil;
}

void hmr_variant_tick_adaptive_quality(float delta_time_sec) {
    if (!g_variant_manager || !g_variant_manager->config.enable_adaptive_quality) return;
    
    g_variant_manager->adaptation_timer += delta_time_sec;
    
    if (g_variant_manager->adaptation_timer >= g_variant_manager->config.adaptation_interval_sec) {
        g_variant_manager->adaptation_timer = 0.0f;
        hmr_update_adaptive_quality();
    }
    
    // Process any pending quality transitions
    for (uint32_t i = 0; i < g_variant_manager->group_count; i++) {
        hmr_shader_variant_group_t* group = &g_variant_manager->shader_groups[i];
        
        if (group->is_transitioning) {
            hmr_shader_variant_t* target_variant = hmr_get_variant(group, group->target_quality);
            
            if (target_variant && target_variant->is_compiled) {
                hmr_shader_quality_t old_quality = group->active_quality;
                group->active_quality = group->target_quality;
                group->is_transitioning = false;
                
                // Call callback if registered
                if (g_variant_manager->on_quality_changed) {
                    g_variant_manager->on_quality_changed(group->shader_name, old_quality, group->target_quality);
                }
            }
        }
    }
}

int32_t hmr_variant_update_performance_metrics(const hmr_performance_metrics_t* metrics) {
    if (!g_variant_manager || !metrics) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    // Update current metrics
    g_variant_manager->current_metrics = *metrics;
    
    // Add to history
    g_variant_manager->metrics_history[g_variant_manager->metrics_history_index] = *metrics;
    g_variant_manager->metrics_history_index = (g_variant_manager->metrics_history_index + 1) % PERFORMANCE_SAMPLE_COUNT;
    
    return HMR_SUCCESS;
}

const char* hmr_variant_quality_to_string(hmr_shader_quality_t quality) {
    switch (quality) {
        case HMR_QUALITY_LOW: return "Low";
        case HMR_QUALITY_MEDIUM: return "Medium";
        case HMR_QUALITY_HIGH: return "High";
        case HMR_QUALITY_ULTRA: return "Ultra";
        case HMR_QUALITY_ADAPTIVE: return "Adaptive";
        default: return "Unknown";
    }
}

void hmr_variant_manager_cleanup(void) {
    if (!g_variant_manager) return;
    
    // Wait for pending compilations
    dispatch_group_wait(g_variant_manager->compile_group, DISPATCH_TIME_FOREVER);
    
    // Release Metal objects for all variants
    for (uint32_t i = 0; i < g_variant_manager->group_count; i++) {
        hmr_shader_variant_group_t* group = &g_variant_manager->shader_groups[i];
        
        for (hmr_shader_quality_t quality = 0; quality < HMR_QUALITY_COUNT; quality++) {
            hmr_shader_variant_t* variant = hmr_get_variant(group, quality);
            if (variant) {
                if (variant->library) variant->library = nil;
                if (variant->function) variant->function = nil;
                if (variant->render_pipeline) variant->render_pipeline = nil;
                if (variant->compute_pipeline) variant->compute_pipeline = nil;
            }
        }
    }
    
    // Release Metal context
    if (g_variant_manager->command_queue) g_variant_manager->command_queue = nil;
    g_variant_manager->device = nil;
    
    // Release dispatch objects
    g_variant_manager->compile_queue = nil;
    g_variant_manager->compile_group = nil;
    
    free(g_variant_manager);
    g_variant_manager = NULL;
    
    NSLog(@"HMR Variant Manager: Cleanup complete");
}