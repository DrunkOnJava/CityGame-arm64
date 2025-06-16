#ifndef AI_ASSET_OPTIMIZER_H
#define AI_ASSET_OPTIMIZER_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

// Forward declarations
typedef struct ai_optimizer_t ai_optimizer_t;
typedef struct optimization_result_t optimization_result_t;
typedef struct asset_metrics_t asset_metrics_t;
typedef struct ml_model_t ml_model_t;

// AI optimization strategies
typedef enum {
    AI_STRATEGY_QUALITY_BALANCED = 0,
    AI_STRATEGY_SIZE_OPTIMIZED = 1,
    AI_STRATEGY_PERFORMANCE_FOCUSED = 2,
    AI_STRATEGY_ADAPTIVE = 3,
    AI_STRATEGY_CUSTOM = 4
} ai_optimization_strategy_t;

// Asset type classifications for ML
typedef enum {
    ASSET_CLASS_TEXTURE_DIFFUSE = 0,
    ASSET_CLASS_TEXTURE_NORMAL = 1,
    ASSET_CLASS_TEXTURE_SPECULAR = 2,
    ASSET_CLASS_TEXTURE_UI = 3,
    ASSET_CLASS_AUDIO_MUSIC = 4,
    ASSET_CLASS_AUDIO_SFX = 5,
    ASSET_CLASS_AUDIO_VOICE = 6,
    ASSET_CLASS_MESH_STATIC = 7,
    ASSET_CLASS_MESH_ANIMATED = 8,
    ASSET_CLASS_SHADER_VERTEX = 9,
    ASSET_CLASS_SHADER_FRAGMENT = 10,
    ASSET_CLASS_CONFIG_GAMEPLAY = 11,
    ASSET_CLASS_CONFIG_UI = 12
} asset_classification_t;

// ML model types
typedef enum {
    ML_MODEL_COMPRESSION_PREDICTOR = 0,
    ML_MODEL_QUALITY_ESTIMATOR = 1,
    ML_MODEL_PERFORMANCE_PREDICTOR = 2,
    ML_MODEL_USAGE_PREDICTOR = 3,
    ML_MODEL_ARTIFACT_DETECTOR = 4
} ml_model_type_t;

// Asset optimization metrics
typedef struct asset_metrics_t {
    // File metrics
    uint64_t original_size;
    uint64_t compressed_size;
    float compression_ratio;
    
    // Quality metrics
    float visual_quality_score;     // 0.0-1.0, SSIM/PSNR based
    float perceptual_quality_score; // 0.0-1.0, perceptual hash based
    float audio_quality_score;      // 0.0-1.0, spectral analysis based
    
    // Performance metrics
    uint32_t load_time_microseconds;
    uint32_t decode_time_microseconds;
    uint32_t gpu_upload_time_microseconds;
    uint64_t memory_footprint;
    
    // Usage patterns
    uint32_t access_frequency;
    uint32_t cache_hits;
    uint32_t cache_misses;
    float average_view_time;
    
    // Device compatibility
    bool supports_low_end_devices;
    bool supports_high_refresh_rate;
    bool supports_hdr;
    
    // ML confidence scores
    float ml_prediction_confidence;
    float optimization_confidence;
} asset_metrics_t;

// Optimization result structure
typedef struct optimization_result_t {
    // Optimization success
    bool success;
    char error_message[256];
    
    // Before/after metrics
    asset_metrics_t original_metrics;
    asset_metrics_t optimized_metrics;
    
    // Optimization details
    ai_optimization_strategy_t strategy_used;
    asset_classification_t detected_class;
    float confidence_score;
    
    // Recommended settings
    uint32_t recommended_width;
    uint32_t recommended_height;
    uint32_t recommended_compression_level;
    float recommended_quality_factor;
    
    // Performance predictions
    float predicted_load_time_improvement;
    float predicted_memory_reduction;
    float predicted_quality_retention;
    
    // Alternative optimizations
    uint32_t alternative_count;
    struct {
        ai_optimization_strategy_t strategy;
        float quality_score;
        float size_reduction;
        float performance_gain;
    } alternatives[8];
} optimization_result_t;

// Neural network layer structure (simplified)
typedef struct nn_layer_t {
    uint32_t input_size;
    uint32_t output_size;
    float* weights;
    float* biases;
    
    // Activation function
    enum {
        ACTIVATION_RELU,
        ACTIVATION_SIGMOID,
        ACTIVATION_TANH,
        ACTIVATION_SOFTMAX
    } activation;
} nn_layer_t;

// Machine learning model structure
typedef struct ml_model_t {
    ml_model_type_t type;
    char model_name[64];
    char version[16];
    
    // Neural network architecture
    uint32_t layer_count;
    nn_layer_t* layers;
    
    // Training metadata
    uint64_t training_samples;
    float accuracy;
    float validation_loss;
    uint64_t last_trained_timestamp;
    
    // Performance metrics
    uint32_t inference_time_microseconds;
    uint64_t memory_usage;
    
    // Model state
    bool is_loaded;
    bool needs_retraining;
    uint32_t prediction_count;
} ml_model_t;

// AI optimizer configuration
typedef struct ai_optimizer_config_t {
    // Model configuration
    char models_directory[256];
    bool enable_online_learning;
    bool enable_model_updates;
    uint32_t retraining_threshold;
    
    // Optimization thresholds
    float minimum_quality_threshold;
    float maximum_compression_ratio;
    uint32_t maximum_processing_time_ms;
    
    // Performance targets
    uint32_t target_load_time_ms;
    uint64_t target_memory_usage;
    float target_quality_score;
    
    // Hardware constraints
    bool optimize_for_mobile;
    bool optimize_for_bandwidth;
    bool optimize_for_storage;
    
    // Advanced features
    bool enable_perceptual_optimization;
    bool enable_content_aware_compression;
    bool enable_temporal_consistency;
    bool enable_multi_resolution_generation;
} ai_optimizer_config_t;

// Main AI optimizer structure
typedef struct ai_optimizer_t {
    ai_optimizer_config_t config;
    
    // ML models
    ml_model_t compression_model;
    ml_model_t quality_model;
    ml_model_t performance_model;
    ml_model_t usage_model;
    ml_model_t artifact_model;
    
    // Optimization statistics
    uint64_t assets_processed;
    uint64_t total_size_saved;
    float average_quality_retention;
    float average_performance_improvement;
    
    // Real-time metrics
    uint32_t current_queue_size;
    uint32_t processing_threads;
    float cpu_usage_percent;
    uint64_t memory_usage;
    
    // Learning data
    struct {
        uint32_t sample_count;
        uint32_t capacity;
        asset_metrics_t* samples;
        optimization_result_t* results;
    } training_data;
    
    // Thread safety
    void* mutex;
    bool is_processing;
    
    // Callbacks
    void (*on_optimization_complete)(const char* asset_path, const optimization_result_t* result);
    void (*on_model_update)(ml_model_type_t model_type, float new_accuracy);
    void (*on_error)(const char* error_message);
} ai_optimizer_t;

// Core AI optimization functions
int ai_optimizer_init(ai_optimizer_t** optimizer, const ai_optimizer_config_t* config);
void ai_optimizer_destroy(ai_optimizer_t* optimizer);

// Asset optimization
int ai_optimize_asset(ai_optimizer_t* optimizer, const char* asset_path, 
                     ai_optimization_strategy_t strategy, optimization_result_t* result);
int ai_optimize_asset_batch(ai_optimizer_t* optimizer, const char** asset_paths, 
                           uint32_t count, ai_optimization_strategy_t strategy);

// ML model management
int ai_optimizer_load_models(ai_optimizer_t* optimizer);
int ai_optimizer_train_model(ai_optimizer_t* optimizer, ml_model_type_t model_type);
int ai_optimizer_update_model(ai_optimizer_t* optimizer, ml_model_type_t model_type, 
                             const asset_metrics_t* samples, uint32_t sample_count);

// Asset analysis and prediction
int ai_analyze_asset(ai_optimizer_t* optimizer, const char* asset_path, asset_metrics_t* metrics);
int ai_predict_optimization(ai_optimizer_t* optimizer, const asset_metrics_t* current_metrics,
                           ai_optimization_strategy_t strategy, optimization_result_t* prediction);

// Performance monitoring
int ai_optimizer_get_stats(ai_optimizer_t* optimizer, struct {
    uint64_t total_optimizations;
    float average_size_reduction;
    float average_quality_retention;
    float average_processing_time;
    uint32_t model_accuracy_percent;
} *stats);

// Configuration and tuning
int ai_optimizer_set_strategy(ai_optimizer_t* optimizer, ai_optimization_strategy_t strategy);
int ai_optimizer_configure_thresholds(ai_optimizer_t* optimizer, float quality_threshold,
                                     float compression_threshold, uint32_t time_threshold);

// Advanced features
int ai_optimizer_enable_content_aware(ai_optimizer_t* optimizer, bool enable);
int ai_optimizer_enable_perceptual_optimization(ai_optimizer_t* optimizer, bool enable);
int ai_optimizer_enable_online_learning(ai_optimizer_t* optimizer, bool enable);

// Utility functions
const char* ai_optimization_strategy_to_string(ai_optimization_strategy_t strategy);
const char* asset_classification_to_string(asset_classification_t classification);
bool ai_optimizer_is_processing(ai_optimizer_t* optimizer);

// Performance benchmarking
int ai_optimizer_benchmark(ai_optimizer_t* optimizer, const char* test_assets_dir,
                          struct {
                              float processing_time_ms;
                              float size_reduction_percent;
                              float quality_retention_percent;
                              uint32_t successful_optimizations;
                              uint32_t failed_optimizations;
                          } *benchmark_results);

#endif // AI_ASSET_OPTIMIZER_H