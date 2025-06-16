/*
 * SimCity ARM64 - Shader Manager for HMR System
 * Metal Shader Hot-Reload Pipeline
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Day 2: Shader Hot-Reload Implementation
 * 
 * Performance Targets:
 * - Shader compilation: <200ms
 * - Hot-swap latency: <50ms
 * - Zero frame drops during reload
 * - Fallback shader activation: <10ms
 */

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include <mach/mach_time.h>
#include "asset_watcher.h"
#include "dependency_tracker.h"
#include "module_interface.h"

// Shader compilation status
typedef enum {
    HMR_SHADER_STATUS_UNCOMPILED = 0,
    HMR_SHADER_STATUS_COMPILING,
    HMR_SHADER_STATUS_COMPILED,
    HMR_SHADER_STATUS_ERROR,
    HMR_SHADER_STATUS_FALLBACK_ACTIVE
} hmr_shader_status_t;

// Shader entry point types
typedef enum {
    HMR_SHADER_VERTEX = 0,
    HMR_SHADER_FRAGMENT,
    HMR_SHADER_COMPUTE,
    HMR_SHADER_KERNEL,
    HMR_SHADER_TYPE_COUNT
} hmr_shader_type_t;

// Compiled shader entry
typedef struct {
    char source_path[256];              // Path to .metal source file
    char function_name[64];             // Entry point function name
    hmr_shader_type_t type;             // Shader type
    hmr_shader_status_t status;         // Compilation status
    
    // Metal objects
    id<MTLLibrary> library;             // Compiled Metal library
    id<MTLFunction> function;           // Shader function
    id<MTLRenderPipelineState> render_pipeline; // Render pipeline (for vertex/fragment)
    id<MTLComputePipelineState> compute_pipeline; // Compute pipeline (for compute)
    
    // Fallback shader
    id<MTLLibrary> fallback_library;
    id<MTLFunction> fallback_function;
    id<MTLRenderPipelineState> fallback_render_pipeline;
    id<MTLComputePipelineState> fallback_compute_pipeline;
    
    // Performance metrics
    uint64_t compile_time_ns;           // Last compilation time
    uint64_t hot_swap_time_ns;          // Last hot-swap time
    uint32_t compile_count;             // Number of compilations
    uint32_t error_count;               // Number of compilation errors
    uint64_t last_modified;             // Source file modification time
    
    // Error tracking
    char last_error[512];               // Last compilation error
    bool has_fallback;                  // Whether fallback is available
    bool is_fallback_active;            // Whether currently using fallback
    
    // Dependencies
    uint32_t dependency_count;          // Number of include dependencies
    char dependencies[16][256];         // Array of dependency paths
} hmr_shader_entry_t;

// Shader manager configuration
typedef struct {
    char shader_directory[256];         // Root directory for shaders
    char include_directory[256];        // Directory for shader includes
    char cache_directory[256];          // Directory for cached binaries
    bool enable_hot_reload;             // Whether hot-reload is enabled
    bool enable_fallbacks;              // Whether to maintain fallback shaders
    bool enable_binary_cache;           // Whether to cache compiled binaries
    uint32_t max_shaders;               // Maximum number of tracked shaders
    uint32_t compile_timeout_ms;        // Compilation timeout in milliseconds
} hmr_shader_manager_config_t;

// Main shader manager structure
typedef struct {
    // Configuration
    hmr_shader_manager_config_t config;
    
    // Metal context
    id<MTLDevice> device;               // Metal device
    id<MTLCommandQueue> command_queue;  // Command queue for compilation
    
    // Shader tracking
    hmr_shader_entry_t* shaders;       // Array of tracked shaders
    uint32_t shader_count;              // Current number of shaders
    uint32_t shader_capacity;           // Maximum number of shaders
    
    // Compilation queue
    dispatch_queue_t compile_queue;     // Serial queue for compilation
    dispatch_group_t compile_group;     // Group for tracking compilations
    
    // Performance metrics
    uint64_t total_compilations;        // Total successful compilations
    uint64_t total_errors;              // Total compilation errors
    uint64_t avg_compile_time;          // Average compilation time
    uint64_t total_hot_swaps;           // Total hot-swaps performed
    uint64_t avg_hot_swap_time;         // Average hot-swap time
    
    // Callbacks
    void (*on_shader_compiled)(const char* path, bool success, uint64_t compile_time_ns);
    void (*on_shader_error)(const char* path, const char* error);
    void (*on_hot_swap_complete)(const char* path, uint64_t swap_time_ns);
} hmr_shader_manager_t;

// Global shader manager instance
static hmr_shader_manager_t* g_shader_manager = NULL;

// Default fallback shaders
static const char* g_fallback_vertex_shader = 
    "#include <metal_stdlib>\n"
    "using namespace metal;\n"
    "\n"
    "struct VertexOut {\n"
    "    float4 position [[position]];\n"
    "    float4 color;\n"
    "};\n"
    "\n"
    "vertex VertexOut fallback_vertex(uint vertexID [[vertex_id]]) {\n"
    "    VertexOut out;\n"
    "    // Simple triangle\n"
    "    float2 positions[3] = { float2(-0.5, -0.5), float2(0.5, -0.5), float2(0.0, 0.5) };\n"
    "    out.position = float4(positions[vertexID], 0.0, 1.0);\n"
    "    out.color = float4(1.0, 0.0, 1.0, 1.0); // Magenta to indicate fallback\n"
    "    return out;\n"
    "}\n";

static const char* g_fallback_fragment_shader =
    "#include <metal_stdlib>\n"
    "using namespace metal;\n"
    "\n"
    "struct VertexOut {\n"
    "    float4 position [[position]];\n"
    "    float4 color;\n"
    "};\n"
    "\n"
    "fragment float4 fallback_fragment(VertexOut in [[stage_in]]) {\n"
    "    return in.color;\n"
    "}\n";

// Find shader entry by path
static hmr_shader_entry_t* hmr_find_shader(const char* path) {
    if (!g_shader_manager || !path) return NULL;
    
    for (uint32_t i = 0; i < g_shader_manager->shader_count; i++) {
        if (strcmp(g_shader_manager->shaders[i].source_path, path) == 0) {
            return &g_shader_manager->shaders[i];
        }
    }
    
    return NULL;
}

// Parse shader source to extract function names and dependencies
static bool hmr_parse_shader_source(const char* source_path, hmr_shader_entry_t* shader) {
    NSString* path = [NSString stringWithUTF8String:source_path];
    NSError* error = nil;
    NSString* content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    
    if (error || !content) {
        NSLog(@"HMR Shader: Failed to read shader source: %s", [error.localizedDescription UTF8String]);
        return false;
    }
    
    // Reset dependencies
    shader->dependency_count = 0;
    
    // Parse for #include statements
    NSArray* lines = [content componentsSeparatedByString:@"\n"];
    for (NSString* line in lines) {
        NSString* trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        if ([trimmed hasPrefix:@"#include"]) {
            // Extract include file
            NSRange start = [trimmed rangeOfString:@"\""];
            if (start.location != NSNotFound) {
                NSRange end = [trimmed rangeOfString:@"\"" options:0 range:NSMakeRange(start.location + 1, trimmed.length - start.location - 1)];
                if (end.location != NSNotFound) {
                    NSString* includePath = [trimmed substringWithRange:NSMakeRange(start.location + 1, end.location - start.location - 1)];
                    
                    if (shader->dependency_count < 16) {
                        strncpy(shader->dependencies[shader->dependency_count], [includePath UTF8String], 255);
                        shader->dependency_count++;
                    }
                }
            }
        }
        
        // Detect shader type from function signatures
        if ([trimmed containsString:@"vertex "] && shader->type == HMR_SHADER_VERTEX) {
            // Extract function name
            NSArray* tokens = [trimmed componentsSeparatedByString:@" "];
            if (tokens.count >= 3) {
                NSString* funcName = tokens[2];
                NSRange parenRange = [funcName rangeOfString:@"("];
                if (parenRange.location != NSNotFound) {
                    funcName = [funcName substringToIndex:parenRange.location];
                    strncpy(shader->function_name, [funcName UTF8String], sizeof(shader->function_name) - 1);
                }
            }
        } else if ([trimmed containsString:@"fragment "] && shader->type == HMR_SHADER_FRAGMENT) {
            // Extract function name
            NSArray* tokens = [trimmed componentsSeparatedByString:@" "];
            if (tokens.count >= 3) {
                NSString* funcName = tokens[2];
                NSRange parenRange = [funcName rangeOfString:@"("];
                if (parenRange.location != NSNotFound) {
                    funcName = [funcName substringToIndex:parenRange.location];
                    strncpy(shader->function_name, [funcName UTF8String], sizeof(shader->function_name) - 1);
                }
            }
        } else if ([trimmed containsString:@"kernel "] && shader->type == HMR_SHADER_COMPUTE) {
            // Extract function name
            NSArray* tokens = [trimmed componentsSeparatedByString:@" "];
            if (tokens.count >= 3) {
                NSString* funcName = tokens[2];
                NSRange parenRange = [funcName rangeOfString:@"("];
                if (parenRange.location != NSNotFound) {
                    funcName = [funcName substringToIndex:parenRange.location];
                    strncpy(shader->function_name, [funcName UTF8String], sizeof(shader->function_name) - 1);
                }
            }
        }
    }
    
    return true;
}

// Compile shader from source
static bool hmr_compile_shader(hmr_shader_entry_t* shader) {
    if (!g_shader_manager || !shader) return false;
    
    uint64_t start_time = mach_absolute_time();
    
    NSString* sourcePath = [NSString stringWithUTF8String:shader->source_path];
    NSError* error = nil;
    NSString* sourceCode = [NSString stringWithContentsOfFile:sourcePath encoding:NSUTF8StringEncoding error:&error];
    
    if (error || !sourceCode) {
        snprintf(shader->last_error, sizeof(shader->last_error), "Failed to read source file: %s", 
                [error.localizedDescription UTF8String]);
        shader->status = HMR_SHADER_STATUS_ERROR;
        shader->error_count++;
        return false;
    }
    
    // Create Metal library from source
    MTLCompileOptions* options = [[MTLCompileOptions alloc] init];
    options.fastMathEnabled = YES;
    
    shader->status = HMR_SHADER_STATUS_COMPILING;
    
    shader->library = [g_shader_manager->device newLibraryWithSource:sourceCode 
                                                             options:options 
                                                               error:&error];
    
    if (error || !shader->library) {
        snprintf(shader->last_error, sizeof(shader->last_error), "Metal compilation failed: %s", 
                [error.localizedDescription UTF8String]);
        shader->status = HMR_SHADER_STATUS_ERROR;
        shader->error_count++;
        g_shader_manager->total_errors++;
        return false;
    }
    
    // Get the shader function
    NSString* functionName = [NSString stringWithUTF8String:shader->function_name];
    shader->function = [shader->library newFunctionWithName:functionName];
    
    if (!shader->function) {
        snprintf(shader->last_error, sizeof(shader->last_error), "Function '%s' not found in compiled library", 
                shader->function_name);
        shader->status = HMR_SHADER_STATUS_ERROR;
        shader->error_count++;
        g_shader_manager->total_errors++;
        return false;
    }
    
    // Create pipeline state based on shader type
    if (shader->type == HMR_SHADER_VERTEX || shader->type == HMR_SHADER_FRAGMENT) {
        // For now, we'll create a simple render pipeline descriptor
        // In a real implementation, this would need more configuration
        MTLRenderPipelineDescriptor* pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        
        if (shader->type == HMR_SHADER_VERTEX) {
            pipelineDescriptor.vertexFunction = shader->function;
        } else {
            pipelineDescriptor.fragmentFunction = shader->function;
        }
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        
        error = nil;
        shader->render_pipeline = [g_shader_manager->device newRenderPipelineStateWithDescriptor:pipelineDescriptor 
                                                                                           error:&error];
        
        if (error || !shader->render_pipeline) {
            snprintf(shader->last_error, sizeof(shader->last_error), "Render pipeline creation failed: %s", 
                    [error.localizedDescription UTF8String]);
            shader->status = HMR_SHADER_STATUS_ERROR;
            shader->error_count++;
            g_shader_manager->total_errors++;
            return false;
        }
    } else if (shader->type == HMR_SHADER_COMPUTE) {
        error = nil;
        shader->compute_pipeline = [g_shader_manager->device newComputePipelineStateWithFunction:shader->function 
                                                                                           error:&error];
        
        if (error || !shader->compute_pipeline) {
            snprintf(shader->last_error, sizeof(shader->last_error), "Compute pipeline creation failed: %s", 
                    [error.localizedDescription UTF8String]);
            shader->status = HMR_SHADER_STATUS_ERROR;
            shader->error_count++;
            g_shader_manager->total_errors++;
            return false;
        }
    }
    
    // Calculate compilation time
    uint64_t end_time = mach_absolute_time();
    static mach_timebase_info_data_t timebase_info;
    if (timebase_info.denom == 0) {
        mach_timebase_info(&timebase_info);
    }
    shader->compile_time_ns = (end_time - start_time) * timebase_info.numer / timebase_info.denom;
    
    shader->status = HMR_SHADER_STATUS_COMPILED;
    shader->compile_count++;
    g_shader_manager->total_compilations++;
    g_shader_manager->avg_compile_time = (g_shader_manager->avg_compile_time + shader->compile_time_ns) / 2;
    
    // Clear error message on success
    shader->last_error[0] = '\0';
    
    NSLog(@"HMR Shader: Compiled %s (%s) in %.2f ms", 
          shader->source_path, shader->function_name, shader->compile_time_ns / 1000000.0);
    
    return true;
}

// Create fallback shader for error recovery
static bool hmr_create_fallback_shader(hmr_shader_entry_t* shader) {
    if (!g_shader_manager || !shader) return false;
    
    const char* fallback_source = NULL;
    const char* fallback_function = NULL;
    
    switch (shader->type) {
        case HMR_SHADER_VERTEX:
            fallback_source = g_fallback_vertex_shader;
            fallback_function = "fallback_vertex";
            break;
        case HMR_SHADER_FRAGMENT:
            fallback_source = g_fallback_fragment_shader;
            fallback_function = "fallback_fragment";
            break;
        default:
            // No fallback for compute shaders yet
            return false;
    }
    
    NSString* sourceCode = [NSString stringWithUTF8String:fallback_source];
    NSError* error = nil;
    
    shader->fallback_library = [g_shader_manager->device newLibraryWithSource:sourceCode 
                                                                      options:nil 
                                                                        error:&error];
    
    if (error || !shader->fallback_library) {
        NSLog(@"HMR Shader: Failed to create fallback library: %s", [error.localizedDescription UTF8String]);
        return false;
    }
    
    NSString* functionName = [NSString stringWithUTF8String:fallback_function];
    shader->fallback_function = [shader->fallback_library newFunctionWithName:functionName];
    
    if (!shader->fallback_function) {
        NSLog(@"HMR Shader: Failed to create fallback function");
        return false;
    }
    
    // Create fallback pipeline
    if (shader->type == HMR_SHADER_VERTEX || shader->type == HMR_SHADER_FRAGMENT) {
        MTLRenderPipelineDescriptor* pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        
        if (shader->type == HMR_SHADER_VERTEX) {
            pipelineDescriptor.vertexFunction = shader->fallback_function;
        } else {
            pipelineDescriptor.fragmentFunction = shader->fallback_function;
        }
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        
        error = nil;
        shader->fallback_render_pipeline = [g_shader_manager->device newRenderPipelineStateWithDescriptor:pipelineDescriptor 
                                                                                                      error:&error];
        
        if (error || !shader->fallback_render_pipeline) {
            NSLog(@"HMR Shader: Failed to create fallback render pipeline: %s", [error.localizedDescription UTF8String]);
            return false;
        }
    }
    
    shader->has_fallback = true;
    NSLog(@"HMR Shader: Created fallback for %s", shader->source_path);
    
    return true;
}

// Initialize shader manager
int32_t hmr_shader_manager_init(const hmr_shader_manager_config_t* config, id<MTLDevice> device) {
    if (g_shader_manager) {
        NSLog(@"HMR Shader Manager: Already initialized");
        return HMR_ERROR_ALREADY_EXISTS;
    }
    
    if (!config || !device) {
        NSLog(@"HMR Shader Manager: Invalid parameters");
        return HMR_ERROR_INVALID_ARG;
    }
    
    // Allocate manager structure
    g_shader_manager = calloc(1, sizeof(hmr_shader_manager_t));
    if (!g_shader_manager) {
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    // Copy configuration
    memcpy(&g_shader_manager->config, config, sizeof(hmr_shader_manager_config_t));
    
    // Set Metal context
    g_shader_manager->device = device;
    g_shader_manager->command_queue = [device newCommandQueue];
    
    // Allocate shader array
    g_shader_manager->shader_capacity = config->max_shaders;
    g_shader_manager->shaders = calloc(g_shader_manager->shader_capacity, sizeof(hmr_shader_entry_t));
    if (!g_shader_manager->shaders) {
        free(g_shader_manager);
        g_shader_manager = NULL;
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    // Create dispatch queues
    g_shader_manager->compile_queue = dispatch_queue_create("com.simcity.hmr.shader_compile", DISPATCH_QUEUE_SERIAL);
    g_shader_manager->compile_group = dispatch_group_create();
    
    NSLog(@"HMR Shader Manager: Initialized successfully");
    NSLog(@"  Shader directory: %s", config->shader_directory);
    NSLog(@"  Max shaders: %u", config->max_shaders);
    NSLog(@"  Hot-reload: %s", config->enable_hot_reload ? "Yes" : "No");
    NSLog(@"  Fallbacks: %s", config->enable_fallbacks ? "Yes" : "No");
    
    return HMR_SUCCESS;
}

// Register shader for hot-reload tracking
int32_t hmr_shader_manager_register(const char* source_path, hmr_shader_type_t type) {
    if (!g_shader_manager || !source_path) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    // Check if already registered
    if (hmr_find_shader(source_path)) {
        return HMR_ERROR_ALREADY_EXISTS;
    }
    
    if (g_shader_manager->shader_count >= g_shader_manager->shader_capacity) {
        NSLog(@"HMR Shader Manager: Maximum shader capacity reached (%u)", g_shader_manager->shader_capacity);
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    hmr_shader_entry_t* shader = &g_shader_manager->shaders[g_shader_manager->shader_count++];
    memset(shader, 0, sizeof(hmr_shader_entry_t));
    
    // Initialize shader entry
    strncpy(shader->source_path, source_path, sizeof(shader->source_path) - 1);
    shader->type = type;
    shader->status = HMR_SHADER_STATUS_UNCOMPILED;
    
    // Parse shader source for metadata
    hmr_parse_shader_source(source_path, shader);
    
    // Create fallback if enabled
    if (g_shader_manager->config.enable_fallbacks) {
        hmr_create_fallback_shader(shader);
    }
    
    // Register for asset watching
    if (g_shader_manager->config.enable_hot_reload) {
        // Add dependency tracking for include files
        for (uint32_t i = 0; i < shader->dependency_count; i++) {
            hmr_dependency_add(source_path, shader->dependencies[i], false);
        }
    }
    
    NSLog(@"HMR Shader: Registered %s (type: %d, function: %s)", 
          source_path, type, shader->function_name);
    
    return HMR_SUCCESS;
}

// Compile shader asynchronously
int32_t hmr_shader_manager_compile_async(const char* source_path) {
    if (!g_shader_manager || !source_path) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    hmr_shader_entry_t* shader = hmr_find_shader(source_path);
    if (!shader) {
        return HMR_ERROR_NOT_FOUND;
    }
    
    dispatch_group_enter(g_shader_manager->compile_group);
    dispatch_async(g_shader_manager->compile_queue, ^{
        bool success = hmr_compile_shader(shader);
        
        // Notify callback if registered
        if (g_shader_manager->on_shader_compiled) {
            g_shader_manager->on_shader_compiled(source_path, success, shader->compile_time_ns);
        }
        
        if (!success && g_shader_manager->on_shader_error) {
            g_shader_manager->on_shader_error(source_path, shader->last_error);
        }
        
        dispatch_group_leave(g_shader_manager->compile_group);
    });
    
    return HMR_SUCCESS;
}

// Get shader pipeline state (with fallback if needed)
id<MTLRenderPipelineState> hmr_shader_manager_get_render_pipeline(const char* source_path) {
    if (!g_shader_manager || !source_path) return nil;
    
    hmr_shader_entry_t* shader = hmr_find_shader(source_path);
    if (!shader) return nil;
    
    if (shader->status == HMR_SHADER_STATUS_COMPILED && shader->render_pipeline) {
        shader->is_fallback_active = false;
        return shader->render_pipeline;
    } else if (shader->has_fallback && shader->fallback_render_pipeline) {
        if (!shader->is_fallback_active) {
            NSLog(@"HMR Shader: Activating fallback for %s", source_path);
            shader->is_fallback_active = true;
        }
        return shader->fallback_render_pipeline;
    }
    
    return nil;
}

// Get compute pipeline state
id<MTLComputePipelineState> hmr_shader_manager_get_compute_pipeline(const char* source_path) {
    if (!g_shader_manager || !source_path) return nil;
    
    hmr_shader_entry_t* shader = hmr_find_shader(source_path);
    if (!shader) return nil;
    
    if (shader->status == HMR_SHADER_STATUS_COMPILED && shader->compute_pipeline) {
        shader->is_fallback_active = false;
        return shader->compute_pipeline;
    } else if (shader->has_fallback && shader->fallback_compute_pipeline) {
        if (!shader->is_fallback_active) {
            NSLog(@"HMR Shader: Activating fallback for %s", source_path);
            shader->is_fallback_active = true;
        }
        return shader->fallback_compute_pipeline;
    }
    
    return nil;
}

// Hot-swap shader (called when source file changes)
int32_t hmr_shader_manager_hot_swap(const char* source_path) {
    if (!g_shader_manager || !source_path) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    hmr_shader_entry_t* shader = hmr_find_shader(source_path);
    if (!shader) {
        return HMR_ERROR_NOT_FOUND;
    }
    
    uint64_t start_time = mach_absolute_time();
    
    // Activate fallback immediately to prevent rendering issues
    if (shader->has_fallback) {
        shader->is_fallback_active = true;
        shader->status = HMR_SHADER_STATUS_FALLBACK_ACTIVE;
    }
    
    // Trigger asynchronous recompilation
    int32_t result = hmr_shader_manager_compile_async(source_path);
    
    // Calculate hot-swap time
    uint64_t end_time = mach_absolute_time();
    static mach_timebase_info_data_t timebase_info;
    if (timebase_info.denom == 0) {
        mach_timebase_info(&timebase_info);
    }
    shader->hot_swap_time_ns = (end_time - start_time) * timebase_info.numer / timebase_info.denom;
    
    g_shader_manager->total_hot_swaps++;
    g_shader_manager->avg_hot_swap_time = (g_shader_manager->avg_hot_swap_time + shader->hot_swap_time_ns) / 2;
    
    // Notify callback
    if (g_shader_manager->on_hot_swap_complete) {
        g_shader_manager->on_hot_swap_complete(source_path, shader->hot_swap_time_ns);
    }
    
    NSLog(@"HMR Shader: Hot-swap initiated for %s (%.2f ms)", 
          source_path, shader->hot_swap_time_ns / 1000000.0);
    
    return result;
}

// Set callbacks for shader events
void hmr_shader_manager_set_callbacks(
    void (*on_compiled)(const char* path, bool success, uint64_t compile_time_ns),
    void (*on_error)(const char* path, const char* error),
    void (*on_hot_swap)(const char* path, uint64_t swap_time_ns)
) {
    if (!g_shader_manager) return;
    
    g_shader_manager->on_shader_compiled = on_compiled;
    g_shader_manager->on_shader_error = on_error;
    g_shader_manager->on_hot_swap_complete = on_hot_swap;
}

// Get shader manager statistics
void hmr_shader_manager_get_stats(
    uint32_t* total_shaders,
    uint32_t* compiled_shaders,
    uint64_t* total_compilations,
    uint64_t* avg_compile_time,
    uint64_t* total_hot_swaps,
    uint64_t* avg_hot_swap_time
) {
    if (!g_shader_manager) return;
    
    if (total_shaders) {
        *total_shaders = g_shader_manager->shader_count;
    }
    
    if (compiled_shaders) {
        uint32_t count = 0;
        for (uint32_t i = 0; i < g_shader_manager->shader_count; i++) {
            if (g_shader_manager->shaders[i].status == HMR_SHADER_STATUS_COMPILED) {
                count++;
            }
        }
        *compiled_shaders = count;
    }
    
    if (total_compilations) {
        *total_compilations = g_shader_manager->total_compilations;
    }
    
    if (avg_compile_time) {
        *avg_compile_time = g_shader_manager->avg_compile_time;
    }
    
    if (total_hot_swaps) {
        *total_hot_swaps = g_shader_manager->total_hot_swaps;
    }
    
    if (avg_hot_swap_time) {
        *avg_hot_swap_time = g_shader_manager->avg_hot_swap_time;
    }
}

// Cleanup shader manager
void hmr_shader_manager_cleanup(void) {
    if (!g_shader_manager) return;
    
    // Wait for any pending compilations
    dispatch_group_wait(g_shader_manager->compile_group, DISPATCH_TIME_FOREVER);
    
    // Release Metal objects
    for (uint32_t i = 0; i < g_shader_manager->shader_count; i++) {
        hmr_shader_entry_t* shader = &g_shader_manager->shaders[i];
        
        // Release main objects
        if (shader->library) shader->library = nil;
        if (shader->function) shader->function = nil;
        if (shader->render_pipeline) shader->render_pipeline = nil;
        if (shader->compute_pipeline) shader->compute_pipeline = nil;
        
        // Release fallback objects
        if (shader->fallback_library) shader->fallback_library = nil;
        if (shader->fallback_function) shader->fallback_function = nil;
        if (shader->fallback_render_pipeline) shader->fallback_render_pipeline = nil;
        if (shader->fallback_compute_pipeline) shader->fallback_compute_pipeline = nil;
    }
    
    // Release Metal context
    if (g_shader_manager->command_queue) g_shader_manager->command_queue = nil;
    g_shader_manager->device = nil;
    
    // Free arrays
    if (g_shader_manager->shaders) {
        free(g_shader_manager->shaders);
    }
    
    // Release dispatch objects (ARC managed)
    g_shader_manager->compile_queue = nil;
    g_shader_manager->compile_group = nil;
    
    free(g_shader_manager);
    g_shader_manager = NULL;
    
    NSLog(@"HMR Shader Manager: Cleanup complete");
}