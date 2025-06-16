/*
 * SimCity ARM64 - Texture Validator Header
 * Texture format validation and compression pipeline interface
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Day 3: Texture Validation Interface
 */

#ifndef HMR_TEXTURE_VALIDATOR_H
#define HMR_TEXTURE_VALIDATOR_H

#include <stdint.h>
#include <stdbool.h>
#include "texture_manager.h"

#ifdef __cplusplus
extern "C" {
#endif

// Texture validation results
typedef enum {
    HMR_TEXTURE_VALID = 0,
    HMR_TEXTURE_INVALID_FORMAT,
    HMR_TEXTURE_INVALID_SIZE,
    HMR_TEXTURE_CORRUPTED_DATA,
    HMR_TEXTURE_UNSUPPORTED_COMPRESSION,
    HMR_TEXTURE_MEMORY_TOO_LARGE,
    HMR_TEXTURE_INVALID_DIMENSIONS
} hmr_texture_validation_result_t;

// Texture quality metrics
typedef struct {
    float psnr;
    float ssim;
    uint64_t file_size_bytes;
    uint64_t memory_size_bytes;
    float compression_ratio;
    uint32_t width, height;
    hmr_texture_format_t format;
    bool has_alpha;
    bool is_power_of_two;
} hmr_texture_quality_metrics_t;

// Validator configuration
typedef struct {
    uint32_t max_texture_width;
    uint32_t max_texture_height;
    uint64_t max_memory_size_mb;
    bool require_power_of_two;
    bool enable_auto_compression;
    bool enable_quality_analysis;
    float min_quality_threshold;
    uint32_t compression_threads;
} hmr_texture_validator_config_t;

// Validator API functions
int32_t hmr_texture_validator_init(const hmr_texture_validator_config_t* config);
hmr_texture_validation_result_t hmr_validate_texture_file(const char* file_path, 
                                                         hmr_texture_quality_metrics_t* metrics);

// Compression pipeline
int32_t hmr_texture_validator_compress_async(const char* source_path,
                                            hmr_texture_format_t output_format,
                                            hmr_texture_compression_t compression_level);

// Callback registration
void hmr_texture_validator_set_callbacks(
    void (*on_validation_complete)(const char* path, hmr_texture_validation_result_t result),
    void (*on_compression_complete)(const char* path, const hmr_texture_quality_metrics_t* metrics),
    void (*on_quality_warning)(const char* path, float quality_score, const char* warning)
);

// Statistics and monitoring
void hmr_texture_validator_get_stats(
    uint64_t* total_validations,
    uint64_t* validation_failures,
    uint64_t* total_compressions,
    uint64_t* compression_failures,
    uint64_t* avg_compression_time,
    uint64_t* bytes_saved
);

// Cleanup
void hmr_texture_validator_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif // HMR_TEXTURE_VALIDATOR_H