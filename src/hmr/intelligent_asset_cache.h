#ifndef INTELLIGENT_ASSET_CACHE_H
#define INTELLIGENT_ASSET_CACHE_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

// Forward declarations
typedef struct intelligent_cache_t intelligent_cache_t;
typedef struct cache_entry_t cache_entry_t;
typedef struct usage_pattern_t usage_pattern_t;
typedef struct prediction_model_t prediction_model_t;

// Cache eviction policies
typedef enum {
    EVICTION_LRU = 0,           // Least Recently Used
    EVICTION_LFU = 1,           // Least Frequently Used
    EVICTION_ARC = 2,           // Adaptive Replacement Cache
    EVICTION_CLOCK = 3,         // Clock algorithm
    EVICTION_PREDICTIVE = 4,    // ML-based predictive eviction
    EVICTION_PRIORITY = 5,      // Priority-based eviction
    EVICTION_HYBRID = 6         // Hybrid algorithm combining multiple strategies
} cache_eviction_policy_t;

// Asset priority levels
typedef enum {
    ASSET_PRIORITY_CRITICAL = 0,    // Must always be cached (UI elements, core gameplay)
    ASSET_PRIORITY_HIGH = 1,        // Important for performance (frequently used textures)
    ASSET_PRIORITY_MEDIUM = 2,      // Normal priority (general game assets)
    ASSET_PRIORITY_LOW = 3,         // Low priority (background elements)
    ASSET_PRIORITY_MINIMAL = 4      // Can be evicted aggressively (rarely used)
} asset_priority_t;

// Cache access patterns
typedef enum {
    ACCESS_PATTERN_SEQUENTIAL = 0,   // Sequential access pattern
    ACCESS_PATTERN_RANDOM = 1,       // Random access pattern
    ACCESS_PATTERN_TEMPORAL = 2,     // Time-based clustering
    ACCESS_PATTERN_SPATIAL = 3,      // Spatial locality clustering
    ACCESS_PATTERN_LEVEL_BASED = 4,  // Game level/area based
    ACCESS_PATTERN_USER_DRIVEN = 5   // User behavior driven
} access_pattern_type_t;

// Predictive loading strategies
typedef enum {
    PREDICT_STRATEGY_NONE = 0,       // No predictive loading
    PREDICT_STRATEGY_SIMPLE = 1,     // Simple distance-based prediction
    PREDICT_STRATEGY_PATTERN = 2,    // Usage pattern based prediction
    PREDICT_STRATEGY_ML = 3,         // Machine learning prediction
    PREDICT_STRATEGY_HYBRID = 4,     // Combination of multiple strategies
    PREDICT_STRATEGY_ADAPTIVE = 5    // Adaptive strategy selection
} prediction_strategy_t;

// Cache entry state
typedef enum {
    CACHE_STATE_COLD = 0,           // Not accessed recently
    CACHE_STATE_WARM = 1,           // Accessed recently
    CACHE_STATE_HOT = 2,            // Frequently accessed
    CACHE_STATE_CRITICAL = 3,       // Critical for performance
    CACHE_STATE_PREDICTED = 4,      // Loaded based on prediction
    CACHE_STATE_PREFETCHED = 5      // Prefetched but not yet accessed
} cache_entry_state_t;

// Usage pattern analysis
typedef struct usage_pattern_t {
    char asset_path[256];
    
    // Access frequency metrics
    uint32_t total_accesses;
    uint32_t accesses_last_hour;
    uint32_t accesses_last_day;
    uint32_t accesses_last_week;
    float access_frequency_trend;    // Positive = increasing, negative = decreasing
    
    // Temporal patterns
    uint64_t first_access_time;
    uint64_t last_access_time;
    uint64_t average_access_interval;
    float access_regularity_score;   // 0.0-1.0, higher = more regular
    
    // Spatial patterns (for 3D games)
    struct {
        float x, y, z;              // Average access location
        float radius;               // Access radius
        bool has_spatial_locality;
    } spatial_pattern;
    
    // Contextual patterns
    struct {
        char game_level[64];
        char game_mode[64];
        char user_activity[64];
        uint32_t concurrent_assets[16];  // Assets typically loaded together
        uint32_t concurrent_count;
    } context;
    
    // Quality of Service requirements
    struct {
        uint32_t max_acceptable_load_time_ms;
        bool requires_instant_access;
        bool can_be_streamed;
        bool can_use_lower_quality;
    } qos_requirements;
    
    // Prediction confidence
    float pattern_confidence;       // 0.0-1.0, confidence in pattern analysis
    access_pattern_type_t dominant_pattern;
    
    // Machine learning features
    float ml_features[16];          // Features for ML prediction models
    float ml_prediction_score;      // Current ML prediction score
} usage_pattern_t;

// Cache entry structure
typedef struct cache_entry_t {
    char asset_path[256];
    char asset_type[32];
    
    // Asset data
    void* data;
    uint64_t data_size;
    uint64_t compressed_size;
    bool is_compressed;
    
    // Cache metadata
    uint64_t cache_timestamp;
    uint64_t last_access_time;
    uint32_t access_count;
    uint32_t access_frequency;      // Accesses per hour
    
    // Priority and state
    asset_priority_t priority;
    cache_entry_state_t state;
    float importance_score;         // 0.0-1.0, higher = more important
    
    // Performance metrics
    uint32_t load_time_microseconds;
    uint32_t last_load_time;
    float load_performance_trend;
    
    // Usage pattern
    usage_pattern_t usage_pattern;
    
    // Eviction resistance
    float eviction_resistance;      // 0.0-1.0, higher = harder to evict
    bool is_pinned;                // Cannot be evicted
    uint64_t pin_expiry_time;      // When pin expires (0 = permanent)
    
    // Predictive data
    float next_access_probability;  // 0.0-1.0, probability of next access
    uint64_t predicted_next_access; // Predicted time of next access
    bool was_predicted_load;        // Whether this was a predictive load
    
    // Quality variants
    struct {
        void* high_quality_data;
        void* medium_quality_data;
        void* low_quality_data;
        uint64_t high_quality_size;
        uint64_t medium_quality_size;
        uint64_t low_quality_size;
        uint32_t current_quality_level; // 0=high, 1=medium, 2=low
    } quality_variants;
    
    // Reference counting
    uint32_t reference_count;
    bool in_use;
    
    // Hash chain for collision resolution
    struct cache_entry_t* next;
} cache_entry_t;

// Machine learning prediction model
typedef struct prediction_model_t {
    char model_name[64];
    prediction_strategy_t strategy;
    
    // Model parameters
    uint32_t feature_count;
    float* weights;
    float* biases;
    float learning_rate;
    
    // Training data
    uint32_t training_samples;
    float accuracy;
    float precision;
    float recall;
    uint64_t last_training_time;
    
    // Prediction history
    uint32_t predictions_made;
    uint32_t predictions_correct;
    float prediction_accuracy;
    
    // Model state
    bool is_trained;
    bool needs_retraining;
    uint32_t update_frequency;
} prediction_model_t;

// Cache statistics
typedef struct cache_statistics_t {
    // Hit/miss statistics
    uint64_t total_requests;
    uint64_t cache_hits;
    uint64_t cache_misses;
    uint64_t false_positives;       // Predicted loads that weren't used
    uint64_t false_negatives;       // Unpredicted loads that were needed
    
    // Performance metrics
    float average_hit_rate;
    float current_hit_rate;
    uint32_t average_access_time_microseconds;
    uint32_t cache_efficiency_score;
    
    // Memory utilization
    uint64_t total_cache_size;
    uint64_t used_cache_size;
    uint64_t available_cache_size;
    float memory_utilization_percent;
    uint32_t fragmentation_percent;
    
    // Eviction statistics
    uint64_t total_evictions;
    uint64_t premature_evictions;   // Evicted items that were soon requested again
    float eviction_efficiency;
    
    // Prediction statistics
    uint64_t predictive_loads;
    uint64_t successful_predictions;
    uint64_t failed_predictions;
    float prediction_accuracy;
    float prediction_value;         // How much prediction helps performance
    
    // Pattern analysis
    uint32_t patterns_detected;
    uint32_t patterns_applied;
    float pattern_effectiveness;
} cache_statistics_t;

// Main intelligent cache structure
typedef struct intelligent_cache_t {
    // Cache configuration
    uint64_t max_cache_size;
    uint64_t current_cache_size;
    uint32_t max_entries;
    uint32_t current_entry_count;
    cache_eviction_policy_t eviction_policy;
    
    // Hash table for fast lookups
    uint32_t hash_table_size;
    cache_entry_t** hash_table;
    
    // Eviction lists for different algorithms
    struct {
        cache_entry_t* lru_head;
        cache_entry_t* lru_tail;
        cache_entry_t* lfu_head;
        cache_entry_t* clock_hand;
        uint32_t clock_size;
    } eviction_lists;
    
    // Usage pattern tracking
    struct {
        uint32_t pattern_count;
        uint32_t pattern_capacity;
        usage_pattern_t* patterns;
        uint64_t analysis_interval_ms;
        uint64_t last_analysis_time;
    } pattern_tracker;
    
    // Predictive loading
    struct {
        prediction_strategy_t strategy;
        prediction_model_t* models;
        uint32_t model_count;
        bool enabled;
        float prediction_threshold;    // Minimum confidence for predictive load
        uint32_t max_predictive_loads; // Maximum concurrent predictive loads
        uint32_t current_predictive_loads;
    } predictor;
    
    // Performance monitoring
    cache_statistics_t statistics;
    
    // Real-time adaptation
    struct {
        bool adaptive_sizing;
        bool adaptive_eviction;
        bool adaptive_prediction;
        float adaptation_rate;        // How quickly to adapt (0.0-1.0)
        uint32_t adaptation_interval_ms;
        uint64_t last_adaptation_time;
    } adaptation;
    
    // Quality management
    struct {
        bool dynamic_quality_enabled;
        float memory_pressure_threshold;
        float performance_threshold;
        uint32_t quality_reduction_factor; // How aggressively to reduce quality
    } quality_manager;
    
    // Thread safety
    void* mutex;
    void* read_write_lock;
    
    // Background processing
    void* worker_thread;
    bool worker_thread_running;
    
    // Callbacks
    void (*on_cache_miss)(const char* asset_path, uint64_t load_time);
    void (*on_cache_hit)(const char* asset_path, cache_entry_state_t state);
    void (*on_eviction)(const char* asset_path, cache_entry_state_t state);
    void (*on_prediction)(const char* asset_path, float confidence);
    void (*on_pattern_detected)(const usage_pattern_t* pattern);
    void (*on_performance_change)(float old_hit_rate, float new_hit_rate);
} intelligent_cache_t;

// Core cache functions
int intelligent_cache_init(intelligent_cache_t** cache, uint64_t max_size, uint32_t max_entries);
void intelligent_cache_destroy(intelligent_cache_t* cache);

// Cache operations
int intelligent_cache_get(intelligent_cache_t* cache, const char* asset_path, 
                         void** data, uint64_t* size);
int intelligent_cache_put(intelligent_cache_t* cache, const char* asset_path, 
                         const void* data, uint64_t size, asset_priority_t priority);
int intelligent_cache_remove(intelligent_cache_t* cache, const char* asset_path);
bool intelligent_cache_contains(intelligent_cache_t* cache, const char* asset_path);

// Advanced cache operations
int intelligent_cache_get_with_quality(intelligent_cache_t* cache, const char* asset_path,
                                      uint32_t quality_level, void** data, uint64_t* size);
int intelligent_cache_put_with_variants(intelligent_cache_t* cache, const char* asset_path,
                                       const void* high_quality, uint64_t high_size,
                                       const void* medium_quality, uint64_t medium_size,
                                       const void* low_quality, uint64_t low_size,
                                       asset_priority_t priority);

// Pattern analysis
int intelligent_cache_analyze_patterns(intelligent_cache_t* cache);
int intelligent_cache_get_usage_pattern(intelligent_cache_t* cache, const char* asset_path,
                                       usage_pattern_t* pattern);

// Predictive loading
int intelligent_cache_predict_and_load(intelligent_cache_t* cache);
int intelligent_cache_set_prediction_strategy(intelligent_cache_t* cache, 
                                             prediction_strategy_t strategy);
int intelligent_cache_train_prediction_model(intelligent_cache_t* cache);

// Cache management
int intelligent_cache_evict_entries(intelligent_cache_t* cache, uint64_t target_size);
int intelligent_cache_pin_asset(intelligent_cache_t* cache, const char* asset_path, 
                               uint64_t duration_ms);
int intelligent_cache_unpin_asset(intelligent_cache_t* cache, const char* asset_path);

// Configuration and tuning
int intelligent_cache_set_eviction_policy(intelligent_cache_t* cache, 
                                         cache_eviction_policy_t policy);
int intelligent_cache_set_adaptive_mode(intelligent_cache_t* cache, bool enabled);
int intelligent_cache_configure_quality_management(intelligent_cache_t* cache,
                                                  float memory_threshold,
                                                  float performance_threshold);

// Statistics and monitoring
int intelligent_cache_get_statistics(intelligent_cache_t* cache, cache_statistics_t* stats);
int intelligent_cache_get_hit_rate(intelligent_cache_t* cache, float* hit_rate);
int intelligent_cache_get_memory_usage(intelligent_cache_t* cache, uint64_t* used, 
                                      uint64_t* total);

// Maintenance operations
int intelligent_cache_cleanup(intelligent_cache_t* cache);
int intelligent_cache_defragment(intelligent_cache_t* cache);
int intelligent_cache_validate_integrity(intelligent_cache_t* cache);

// Export/import for persistence
int intelligent_cache_export_patterns(intelligent_cache_t* cache, const char* file_path);
int intelligent_cache_import_patterns(intelligent_cache_t* cache, const char* file_path);
int intelligent_cache_save_state(intelligent_cache_t* cache, const char* file_path);
int intelligent_cache_load_state(intelligent_cache_t* cache, const char* file_path);

// Utility functions
const char* cache_eviction_policy_to_string(cache_eviction_policy_t policy);
const char* asset_priority_to_string(asset_priority_t priority);
const char* cache_entry_state_to_string(cache_entry_state_t state);
const char* access_pattern_type_to_string(access_pattern_type_t pattern);
const char* prediction_strategy_to_string(prediction_strategy_t strategy);

uint32_t intelligent_cache_hash(const char* asset_path);
float calculate_importance_score(const cache_entry_t* entry);

#endif // INTELLIGENT_ASSET_CACHE_H