// SimCity ARM64 Metal Argument Buffer System
// Agent 3: Graphics & Rendering Pipeline
// Header definitions for Metal argument buffers

#ifndef METAL_ARGUMENT_BUFFERS_H
#define METAL_ARGUMENT_BUFFERS_H

#include <simd/simd.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

//==============================================================================
// Uniform Buffer Structures (matching Metal shaders)
//==============================================================================

// Scene-wide uniforms (rarely changes)
typedef struct {
    simd_float4x4 viewProjectionMatrix;
    simd_float4x4 isometricMatrix;
    simd_float3 cameraPosition;
    float time;
    simd_float4 fogColor;
    simd_float2 fogRange;          // near, far
    simd_float2 screenSize;
    simd_float4 lightDirection;
    simd_float4 lightColor;
    simd_float4 ambientColor;
} SceneUniforms;

// Per-tile uniforms (changes per tile)
typedef struct {
    simd_float2 tilePosition;
    float elevation;
    float tileType;
    simd_float4 tileColor;
    float animationPhase;
    float _padding[3];             // Align to 16 bytes
} TileUniforms;

// Weather and environmental effects
typedef struct {
    float rainIntensity;
    float fogDensity;
    float windSpeed;
    float windDirection;
    simd_float4 rainColor;
    simd_float4 fogTint;
} WeatherUniforms;

// Lighting system uniforms
typedef struct {
    simd_float4 sunDirection;
    simd_float4 sunColor;
    simd_float4 skyColor;
    simd_float4 ambientColor;
    float timeOfDay;               // 0.0 = midnight, 0.5 = noon
    float shadowIntensity;
    float _padding[2];
} LightingUniforms;

// Material properties for advanced rendering
typedef struct {
    simd_float4 albedo;
    float roughness;
    float metallic;
    float specular;
    float emissive;
    simd_float2 uvScale;
    simd_float2 uvOffset;
} MaterialUniforms;

// Instancing data for sprite batching
typedef struct {
    simd_float4x4 transform;
    simd_float4 colorMultiplier;
    simd_float2 uvOffset;
    simd_float2 uvScale;
    uint32_t textureIndex;
    uint32_t instanceFlags;
    float _padding[2];
} InstanceData;

// GPU culling uniforms
typedef struct {
    simd_float4x4 viewProjectionMatrix;
    simd_float3 cameraPosition;
    float nearPlane;
    float farPlane;
    uint32_t objectCount;
    uint32_t currentFrame;
    uint32_t enableTemporalCoherence;
    uint32_t enableOcclusionCulling;
} CullingUniforms;

// Post-processing uniforms
typedef struct {
    simd_float2 screenSize;
    simd_float2 invScreenSize;
    float gamma;
    float exposure;
    float bloomIntensity;
    float vignetteStrength;
    simd_float4 colorGrading;      // saturation, contrast, brightness, hue
} PostProcessUniforms;

//==============================================================================
// Argument Buffer Management Functions
//==============================================================================

// Initialize the argument buffer system with Metal device
void metal_argument_buffers_init(void* device);

// Create argument buffers for different uniform types
void* metal_create_scene_argument_buffer(SceneUniforms* uniforms);
void* metal_create_tile_argument_buffer(TileUniforms* uniforms);
void* metal_create_weather_argument_buffer(WeatherUniforms* uniforms);
void* metal_create_lighting_argument_buffer(LightingUniforms* uniforms);
void* metal_create_material_argument_buffer(MaterialUniforms* uniforms);
void* metal_create_culling_argument_buffer(CullingUniforms* uniforms);
void* metal_create_postprocess_argument_buffer(PostProcessUniforms* uniforms);

// Combined argument buffer for multiple uniform types
void* metal_create_combined_argument_buffer(SceneUniforms* scene,
                                          TileUniforms* tile,
                                          WeatherUniforms* weather);

// Release argument buffer
void metal_argument_buffer_release(void* buffer);

//==============================================================================
// Buffer Pool Management
//==============================================================================

// Pre-allocate argument buffer pool for performance
void metal_argument_buffers_preallocate_pool(uint32_t pool_size);

// Get buffer from pool (for high-frequency allocations)
void* metal_argument_buffer_pool_acquire(void);

// Return buffer to pool
void metal_argument_buffer_pool_release(void* buffer);

// Flush unused buffers from pool
void metal_argument_buffer_pool_flush(void);

//==============================================================================
// Performance and Debugging
//==============================================================================

// Print performance statistics
void metal_argument_buffers_print_stats(void);

// Validate argument buffer layout (debug builds only)
int metal_argument_buffer_validate_layout(void* buffer, const char* structure_name);

// Get memory usage statistics
typedef struct {
    uint64_t total_memory_used;
    uint64_t active_buffers;
    uint64_t pool_size;
    uint64_t cache_hits;
    uint64_t cache_misses;
    float cache_hit_ratio;
} ArgumentBufferStats;

ArgumentBufferStats metal_argument_buffers_get_stats(void);

//==============================================================================
// Advanced Features
//==============================================================================

// Enable/disable argument buffer optimization
void metal_argument_buffers_set_optimization_enabled(int enabled);

// Set GPU family for optimal buffer layout
void metal_argument_buffers_set_gpu_family(int apple_gpu_family);

// Prefetch argument buffers for next frame
void metal_argument_buffers_prefetch_frame(void);

// Synchronize argument buffers with GPU
void metal_argument_buffers_sync_gpu(void);

//==============================================================================
// Constants and Limits
//==============================================================================

// Maximum argument buffer size (Apple Silicon limit)
#define METAL_MAX_ARGUMENT_BUFFER_SIZE (64 * 1024)

// Argument buffer alignment requirement
#define METAL_ARGUMENT_BUFFER_ALIGNMENT 256

// Maximum number of textures in argument buffer
#define METAL_MAX_TEXTURES_PER_BUFFER 128

// Maximum number of samplers in argument buffer
#define METAL_MAX_SAMPLERS_PER_BUFFER 16

// Maximum number of buffers in argument buffer
#define METAL_MAX_BUFFERS_PER_BUFFER 31

// GPU family identifiers
#define METAL_GPU_FAMILY_APPLE_7 7    // A15 Bionic
#define METAL_GPU_FAMILY_APPLE_8 8    // M1, M1 Pro, M1 Max
#define METAL_GPU_FAMILY_APPLE_9 9    // M2, M2 Pro, M2 Max

//==============================================================================
// Error Codes
//==============================================================================

#define METAL_ARG_BUFFER_SUCCESS 0
#define METAL_ARG_BUFFER_ERROR_INVALID_DEVICE -1
#define METAL_ARG_BUFFER_ERROR_OUT_OF_MEMORY -2
#define METAL_ARG_BUFFER_ERROR_INVALID_STRUCTURE -3
#define METAL_ARG_BUFFER_ERROR_BUFFER_TOO_LARGE -4
#define METAL_ARG_BUFFER_ERROR_ENCODING_FAILED -5

#ifdef __cplusplus
}
#endif

#endif // METAL_ARGUMENT_BUFFERS_H