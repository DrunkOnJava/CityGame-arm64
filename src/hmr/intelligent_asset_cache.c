#include "intelligent_asset_cache.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <pthread.h>
#include <sys/time.h>
#include <unistd.h>

// Hash table and cache constants
#define DEFAULT_HASH_TABLE_SIZE 8192
#define PATTERN_ANALYSIS_INTERVAL_MS 5000
#define ADAPTATION_INTERVAL_MS 10000
#define MAX_PREDICTIVE_CONFIDENCE 0.95f
#define MIN_PREDICTIVE_CONFIDENCE 0.6f
#define EVICTION_BATCH_SIZE 16

// Usage pattern analysis constants
#define MIN_ACCESSES_FOR_PATTERN 5
#define PATTERN_CONFIDENCE_THRESHOLD 0.7f
#define TEMPORAL_LOCALITY_WINDOW_MS 60000  // 1 minute
#define SPATIAL_LOCALITY_RADIUS 10.0f

// Quality adaptation thresholds
#define MEMORY_PRESSURE_HIGH 0.85f
#define MEMORY_PRESSURE_CRITICAL 0.95f
#define PERFORMANCE_DEGRADATION_THRESHOLD 0.8f

// Utility functions
static uint64_t get_current_time_microseconds() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec * 1000000ULL + tv.tv_usec;
}

uint32_t intelligent_cache_hash(const char* asset_path) {
    if (!asset_path) return 0;
    
    uint32_t hash = 5381;
    const char* str = asset_path;
    
    while (*str) {
        hash = ((hash << 5) + hash) + *str;
        str++;
    }
    
    return hash;
}

static cache_entry_t* find_cache_entry(intelligent_cache_t* cache, const char* asset_path) {
    uint32_t hash = intelligent_cache_hash(asset_path);
    uint32_t index = hash % cache->hash_table_size;
    
    cache_entry_t* entry = cache->hash_table[index];
    while (entry) {
        if (strcmp(entry->asset_path, asset_path) == 0) {
            return entry;
        }
        entry = entry->next;
    }
    
    return NULL;
}

// LRU list management
static void move_to_front_lru(intelligent_cache_t* cache, cache_entry_t* entry) {
    if (cache->eviction_lists.lru_head == entry) {
        return; // Already at front
    }
    
    // Remove from current position
    if (entry->next) {
        // Not implemented - would need prev pointers for full LRU
    }
    
    // Add to front
    entry->next = cache->eviction_lists.lru_head;
    cache->eviction_lists.lru_head = entry;
    
    if (!cache->eviction_lists.lru_tail) {
        cache->eviction_lists.lru_tail = entry;
    }
}

// Usage pattern analysis
static void analyze_access_pattern(cache_entry_t* entry) {
    usage_pattern_t* pattern = &entry->usage_pattern;
    uint64_t current_time = get_current_time_microseconds();
    
    // Update basic access metrics
    pattern->total_accesses++;
    pattern->last_access_time = current_time;
    
    // Calculate access frequency
    if (pattern->first_access_time == 0) {
        pattern->first_access_time = current_time;
    } else {
        uint64_t time_span = current_time - pattern->first_access_time;
        if (time_span > 0) {
            pattern->access_frequency_trend = 
                (float)pattern->total_accesses / (time_span / 1000000.0f); // Accesses per second
        }
    }
    
    // Calculate access regularity
    if (pattern->total_accesses > 1) {
        uint64_t avg_interval = (current_time - pattern->first_access_time) / (pattern->total_accesses - 1);
        pattern->average_access_interval = avg_interval;
        
        // Simple regularity score based on variance from average
        // In production, would track all intervals and calculate proper variance
        pattern->access_regularity_score = fmaxf(0.0f, 1.0f - 0.1f); // Simplified
    }
    
    // Determine dominant pattern type
    if (pattern->access_regularity_score > 0.8f) {
        pattern->dominant_pattern = ACCESS_PATTERN_TEMPORAL;
    } else if (pattern->access_frequency_trend > 1.0f) {
        pattern->dominant_pattern = ACCESS_PATTERN_SEQUENTIAL;
    } else {
        pattern->dominant_pattern = ACCESS_PATTERN_RANDOM;
    }
    
    // Update pattern confidence
    pattern->pattern_confidence = fminf(1.0f, pattern->total_accesses / 20.0f);
    
    // Prepare ML features
    pattern->ml_features[0] = pattern->access_frequency_trend;
    pattern->ml_features[1] = pattern->access_regularity_score;
    pattern->ml_features[2] = (float)pattern->total_accesses / 100.0f;
    pattern->ml_features[3] = (current_time - pattern->last_access_time) / 1000000.0f; // Seconds since last access
    pattern->ml_features[4] = pattern->pattern_confidence;
    
    // Fill remaining features with contextual data
    for (int i = 5; i < 16; i++) {
        pattern->ml_features[i] = 0.5f; // Default neutral values
    }
}

// Machine learning prediction
static float predict_next_access_probability(intelligent_cache_t* cache, cache_entry_t* entry) {
    if (!cache->predictor.enabled || cache->predictor.model_count == 0) {
        return 0.5f; // Default probability
    }
    
    prediction_model_t* model = &cache->predictor.models[0]; // Use first model
    usage_pattern_t* pattern = &entry->usage_pattern;
    
    if (!model->is_trained) {
        return 0.5f;
    }
    
    // Simple linear model prediction
    float prediction = 0.0f;
    for (uint32_t i = 0; i < model->feature_count && i < 16; i++) {
        prediction += pattern->ml_features[i] * model->weights[i];
    }
    prediction += model->biases[0];
    
    // Apply sigmoid activation
    prediction = 1.0f / (1.0f + expf(-prediction));
    
    return fmaxf(0.0f, fminf(1.0f, prediction));
}

// Eviction algorithms
static cache_entry_t* select_eviction_candidate_lru(intelligent_cache_t* cache) {
    return cache->eviction_lists.lru_tail;
}

static cache_entry_t* select_eviction_candidate_priority(intelligent_cache_t* cache) {
    cache_entry_t* candidate = NULL;
    float lowest_score = 2.0f; // Higher than max possible score
    
    // Simple linear search - in production would use more efficient data structure
    for (uint32_t i = 0; i < cache->hash_table_size; i++) {
        cache_entry_t* entry = cache->hash_table[i];
        while (entry) {
            if (!entry->is_pinned && !entry->in_use) {
                float score = entry->importance_score * (1.0f - entry->eviction_resistance);
                if (score < lowest_score) {
                    lowest_score = score;
                    candidate = entry;
                }
            }
            entry = entry->next;
        }
    }
    
    return candidate;
}

static cache_entry_t* select_eviction_candidate_predictive(intelligent_cache_t* cache) {
    cache_entry_t* candidate = NULL;
    float lowest_probability = 2.0f;
    
    for (uint32_t i = 0; i < cache->hash_table_size; i++) {
        cache_entry_t* entry = cache->hash_table[i];
        while (entry) {
            if (!entry->is_pinned && !entry->in_use) {
                float probability = predict_next_access_probability(cache, entry);
                if (probability < lowest_probability) {
                    lowest_probability = probability;
                    candidate = entry;
                }
            }
            entry = entry->next;
        }
    }
    
    return candidate;
}

static void evict_cache_entry(intelligent_cache_t* cache, cache_entry_t* entry) {
    if (!entry || entry->is_pinned || entry->in_use) return;
    
    // Update statistics
    cache->statistics.total_evictions++;
    
    // Check if this is a premature eviction
    uint64_t current_time = get_current_time_microseconds();
    if (current_time - entry->last_access_time < 300000000) { // 5 minutes
        cache->statistics.premature_evictions++;
    }
    
    // Remove from hash table
    uint32_t hash = intelligent_cache_hash(entry->asset_path);
    uint32_t index = hash % cache->hash_table_size;
    
    cache_entry_t** current = &cache->hash_table[index];
    while (*current) {
        if (*current == entry) {
            *current = entry->next;
            break;
        }
        current = &(*current)->next;
    }
    
    // Free memory
    cache->current_cache_size -= entry->data_size;
    cache->current_entry_count--;
    
    if (cache->on_eviction) {
        cache->on_eviction(entry->asset_path, entry->state);
    }
    
    // Free entry data
    free(entry->data);
    free(entry->quality_variants.high_quality_data);
    free(entry->quality_variants.medium_quality_data);
    free(entry->quality_variants.low_quality_data);
    free(entry);
}

// Quality management
static void adapt_quality_levels(intelligent_cache_t* cache) {
    if (!cache->quality_manager.dynamic_quality_enabled) return;
    
    float memory_utilization = (float)cache->current_cache_size / cache->max_cache_size;
    
    if (memory_utilization > cache->quality_manager.memory_pressure_threshold) {
        // Reduce quality of some entries to free memory
        uint32_t entries_processed = 0;
        uint32_t max_entries_to_process = cache->current_entry_count / 4; // Process 25% of entries
        
        for (uint32_t i = 0; i < cache->hash_table_size && entries_processed < max_entries_to_process; i++) {
            cache_entry_t* entry = cache->hash_table[i];
            while (entry && entries_processed < max_entries_to_process) {
                if (entry->quality_variants.current_quality_level == 0 && // Currently high quality
                    entry->priority > ASSET_PRIORITY_CRITICAL &&
                    entry->quality_variants.medium_quality_data) {
                    
                    // Switch to medium quality
                    free(entry->data);
                    entry->data = malloc(entry->quality_variants.medium_quality_size);
                    memcpy(entry->data, entry->quality_variants.medium_quality_data, 
                           entry->quality_variants.medium_quality_size);
                    
                    cache->current_cache_size -= (entry->data_size - entry->quality_variants.medium_quality_size);
                    entry->data_size = entry->quality_variants.medium_quality_size;
                    entry->quality_variants.current_quality_level = 1;
                    
                    entries_processed++;
                }
                entry = entry->next;
            }
        }
    }
}

// Predictive loading
static void perform_predictive_loading(intelligent_cache_t* cache) {
    if (!cache->predictor.enabled) return;
    
    // Simplified predictive loading - in production would be more sophisticated
    uint32_t predictions_made = 0;
    uint32_t max_predictions = cache->predictor.max_predictive_loads - 
                               cache->predictor.current_predictive_loads;
    
    for (uint32_t i = 0; i < cache->pattern_tracker.pattern_count && 
         predictions_made < max_predictions; i++) {
        
        usage_pattern_t* pattern = &cache->pattern_tracker.patterns[i];
        
        if (pattern->pattern_confidence > cache->predictor.prediction_threshold &&
            pattern->access_frequency_trend > 0.5f) { // Increasing access trend
            
            // Check if asset is not already cached
            if (!find_cache_entry(cache, pattern->asset_path)) {
                // This would trigger actual asset loading in production
                if (cache->on_prediction) {
                    cache->on_prediction(pattern->asset_path, pattern->pattern_confidence);
                }
                
                predictions_made++;
                cache->statistics.predictive_loads++;
            }
        }
    }
}

// Core implementation
int intelligent_cache_init(intelligent_cache_t** cache, uint64_t max_size, uint32_t max_entries) {
    if (!cache) return -1;
    
    *cache = calloc(1, sizeof(intelligent_cache_t));
    if (!*cache) return -1;
    
    intelligent_cache_t* c = *cache;
    
    // Initialize basic configuration
    c->max_cache_size = max_size;
    c->max_entries = max_entries;
    c->hash_table_size = DEFAULT_HASH_TABLE_SIZE;
    c->eviction_policy = EVICTION_PREDICTIVE;
    
    // Initialize hash table
    c->hash_table = calloc(c->hash_table_size, sizeof(cache_entry_t*));
    if (!c->hash_table) {
        free(c);
        return -1;
    }
    
    // Initialize pattern tracker
    c->pattern_tracker.pattern_capacity = 1000;
    c->pattern_tracker.patterns = calloc(c->pattern_tracker.pattern_capacity, sizeof(usage_pattern_t));
    c->pattern_tracker.analysis_interval_ms = PATTERN_ANALYSIS_INTERVAL_MS;
    
    // Initialize predictor
    c->predictor.enabled = true;
    c->predictor.strategy = PREDICT_STRATEGY_ML;
    c->predictor.prediction_threshold = MIN_PREDICTIVE_CONFIDENCE;
    c->predictor.max_predictive_loads = 10;
    c->predictor.model_count = 1;
    c->predictor.models = calloc(1, sizeof(prediction_model_t));
    
    // Initialize first prediction model
    prediction_model_t* model = &c->predictor.models[0];
    strcpy(model->model_name, "AccessPredictor");
    model->strategy = PREDICT_STRATEGY_ML;
    model->feature_count = 16;
    model->weights = calloc(16, sizeof(float));
    model->biases = calloc(1, sizeof(float));
    model->learning_rate = 0.01f;
    
    // Initialize with random weights
    for (uint32_t i = 0; i < 16; i++) {
        model->weights[i] = ((rand() / (float)RAND_MAX) - 0.5f) * 0.1f;
    }
    model->biases[0] = 0.0f;
    model->is_trained = true; // Mark as trained for demo purposes
    
    // Initialize adaptation settings
    c->adaptation.adaptive_sizing = true;
    c->adaptation.adaptive_eviction = true;
    c->adaptation.adaptive_prediction = true;
    c->adaptation.adaptation_rate = 0.1f;
    c->adaptation.adaptation_interval_ms = ADAPTATION_INTERVAL_MS;
    
    // Initialize quality management
    c->quality_manager.dynamic_quality_enabled = true;
    c->quality_manager.memory_pressure_threshold = MEMORY_PRESSURE_HIGH;
    c->quality_manager.performance_threshold = PERFORMANCE_DEGRADATION_THRESHOLD;
    c->quality_manager.quality_reduction_factor = 2;
    
    // Initialize threading
    c->mutex = malloc(sizeof(pthread_mutex_t));
    pthread_mutex_init((pthread_mutex_t*)c->mutex, NULL);
    
    c->read_write_lock = malloc(sizeof(pthread_rwlock_t));
    pthread_rwlock_init((pthread_rwlock_t*)c->read_write_lock, NULL);
    
    return 0;
}

void intelligent_cache_destroy(intelligent_cache_t* cache) {
    if (!cache) return;
    
    // Stop worker thread if running
    if (cache->worker_thread_running) {
        cache->worker_thread_running = false;
        // Would join thread here
    }
    
    // Free all cache entries
    for (uint32_t i = 0; i < cache->hash_table_size; i++) {
        cache_entry_t* entry = cache->hash_table[i];
        while (entry) {
            cache_entry_t* next = entry->next;
            free(entry->data);
            free(entry->quality_variants.high_quality_data);
            free(entry->quality_variants.medium_quality_data);
            free(entry->quality_variants.low_quality_data);
            free(entry);
            entry = next;
        }
    }
    
    // Free data structures
    free(cache->hash_table);
    free(cache->pattern_tracker.patterns);
    
    // Free prediction models
    for (uint32_t i = 0; i < cache->predictor.model_count; i++) {
        free(cache->predictor.models[i].weights);
        free(cache->predictor.models[i].biases);
    }
    free(cache->predictor.models);
    
    // Free threading objects
    pthread_mutex_destroy((pthread_mutex_t*)cache->mutex);
    pthread_rwlock_destroy((pthread_rwlock_t*)cache->read_write_lock);
    free(cache->mutex);
    free(cache->read_write_lock);
    
    free(cache);
}

int intelligent_cache_get(intelligent_cache_t* cache, const char* asset_path, 
                         void** data, uint64_t* size) {
    if (!cache || !asset_path || !data || !size) return -1;
    
    pthread_rwlock_rdlock((pthread_rwlock_t*)cache->read_write_lock);
    
    cache_entry_t* entry = find_cache_entry(cache, asset_path);
    
    if (entry) {
        // Cache hit
        *data = entry->data;
        *size = entry->data_size;
        
        // Update access metrics
        entry->access_count++;
        entry->last_access_time = get_current_time_microseconds();
        entry->reference_count++;
        entry->in_use = true;
        
        // Analyze usage pattern
        analyze_access_pattern(entry);
        
        // Update cache order for LRU
        move_to_front_lru(cache, entry);
        
        // Update statistics
        cache->statistics.cache_hits++;
        cache->statistics.total_requests++;
        
        if (cache->on_cache_hit) {
            cache->on_cache_hit(asset_path, entry->state);
        }
        
        pthread_rwlock_unlock((pthread_rwlock_t*)cache->read_write_lock);
        return 0;
    } else {
        // Cache miss
        cache->statistics.cache_misses++;
        cache->statistics.total_requests++;
        
        if (cache->on_cache_miss) {
            cache->on_cache_miss(asset_path, 0); // Load time would be measured
        }
        
        pthread_rwlock_unlock((pthread_rwlock_t*)cache->read_write_lock);
        return -1;
    }
}

int intelligent_cache_put(intelligent_cache_t* cache, const char* asset_path, 
                         const void* data, uint64_t size, asset_priority_t priority) {
    if (!cache || !asset_path || !data || size == 0) return -1;
    
    pthread_rwlock_wrlock((pthread_rwlock_t*)cache->read_write_lock);
    
    // Check if entry already exists
    cache_entry_t* existing = find_cache_entry(cache, asset_path);
    if (existing) {
        // Update existing entry
        free(existing->data);
        existing->data = malloc(size);
        memcpy(existing->data, data, size);
        existing->data_size = size;
        existing->cache_timestamp = get_current_time_microseconds();
        
        pthread_rwlock_unlock((pthread_rwlock_t*)cache->read_write_lock);
        return 0;
    }
    
    // Check if we need to evict entries to make space
    while (cache->current_cache_size + size > cache->max_cache_size && 
           cache->current_entry_count > 0) {
        
        cache_entry_t* victim = NULL;
        switch (cache->eviction_policy) {
            case EVICTION_LRU:
                victim = select_eviction_candidate_lru(cache);
                break;
            case EVICTION_PRIORITY:
                victim = select_eviction_candidate_priority(cache);
                break;
            case EVICTION_PREDICTIVE:
                victim = select_eviction_candidate_predictive(cache);
                break;
            default:
                victim = select_eviction_candidate_lru(cache);
                break;
        }
        
        if (victim) {
            evict_cache_entry(cache, victim);
        } else {
            // Cannot evict anything, cache full
            pthread_rwlock_unlock((pthread_rwlock_t*)cache->read_write_lock);
            return -2;
        }
    }
    
    // Create new cache entry
    cache_entry_t* entry = calloc(1, sizeof(cache_entry_t));
    if (!entry) {
        pthread_rwlock_unlock((pthread_rwlock_t*)cache->read_write_lock);
        return -1;
    }
    
    // Initialize entry
    strncpy(entry->asset_path, asset_path, sizeof(entry->asset_path) - 1);
    entry->data = malloc(size);
    memcpy(entry->data, data, size);
    entry->data_size = size;
    entry->priority = priority;
    entry->state = CACHE_STATE_WARM;
    entry->cache_timestamp = get_current_time_microseconds();
    entry->last_access_time = entry->cache_timestamp;
    entry->access_count = 1;
    entry->reference_count = 0;
    
    // Calculate importance score
    entry->importance_score = calculate_importance_score(entry);
    
    // Add to hash table
    uint32_t hash = intelligent_cache_hash(asset_path);
    uint32_t index = hash % cache->hash_table_size;
    entry->next = cache->hash_table[index];
    cache->hash_table[index] = entry;
    
    // Update cache statistics
    cache->current_cache_size += size;
    cache->current_entry_count++;
    
    // Add to LRU list
    move_to_front_lru(cache, entry);
    
    pthread_rwlock_unlock((pthread_rwlock_t*)cache->read_write_lock);
    
    return 0;
}

int intelligent_cache_analyze_patterns(intelligent_cache_t* cache) {
    if (!cache) return -1;
    
    pthread_mutex_lock((pthread_mutex_t*)cache->mutex);
    
    uint64_t current_time = get_current_time_microseconds();
    
    // Only analyze if enough time has passed
    if (current_time - cache->pattern_tracker.last_analysis_time < 
        cache->pattern_tracker.analysis_interval_ms * 1000) {
        pthread_mutex_unlock((pthread_mutex_t*)cache->mutex);
        return 0;
    }
    
    // Collect patterns from cache entries
    cache->pattern_tracker.pattern_count = 0;
    
    for (uint32_t i = 0; i < cache->hash_table_size; i++) {
        cache_entry_t* entry = cache->hash_table[i];
        while (entry && cache->pattern_tracker.pattern_count < cache->pattern_tracker.pattern_capacity) {
            if (entry->usage_pattern.total_accesses >= MIN_ACCESSES_FOR_PATTERN) {
                cache->pattern_tracker.patterns[cache->pattern_tracker.pattern_count] = 
                    entry->usage_pattern;
                cache->pattern_tracker.pattern_count++;
            }
            entry = entry->next;
        }
    }
    
    cache->pattern_tracker.last_analysis_time = current_time;
    cache->statistics.patterns_detected = cache->pattern_tracker.pattern_count;
    
    pthread_mutex_unlock((pthread_mutex_t*)cache->mutex);
    
    return 0;
}

int intelligent_cache_predict_and_load(intelligent_cache_t* cache) {
    if (!cache) return -1;
    
    pthread_mutex_lock((pthread_mutex_t*)cache->mutex);
    
    perform_predictive_loading(cache);
    
    pthread_mutex_unlock((pthread_mutex_t*)cache->mutex);
    
    return 0;
}

int intelligent_cache_get_statistics(intelligent_cache_t* cache, cache_statistics_t* stats) {
    if (!cache || !stats) return -1;
    
    pthread_rwlock_rdlock((pthread_rwlock_t*)cache->read_write_lock);
    
    *stats = cache->statistics;
    
    // Calculate derived statistics
    if (stats->total_requests > 0) {
        stats->average_hit_rate = (float)stats->cache_hits / stats->total_requests;
        stats->current_hit_rate = stats->average_hit_rate; // Simplified
    }
    
    stats->total_cache_size = cache->max_cache_size;
    stats->used_cache_size = cache->current_cache_size;
    stats->available_cache_size = cache->max_cache_size - cache->current_cache_size;
    stats->memory_utilization_percent = (float)cache->current_cache_size / cache->max_cache_size * 100;
    
    if (stats->predictive_loads > 0) {
        stats->prediction_accuracy = (float)stats->successful_predictions / stats->predictive_loads;
    }
    
    pthread_rwlock_unlock((pthread_rwlock_t*)cache->read_write_lock);
    
    return 0;
}

float calculate_importance_score(const cache_entry_t* entry) {
    if (!entry) return 0.0f;
    
    float score = 0.0f;
    
    // Priority contributes 40%
    score += (4 - entry->priority) / 4.0f * 0.4f;
    
    // Access frequency contributes 30%
    float freq_score = fminf(1.0f, entry->access_count / 100.0f);
    score += freq_score * 0.3f;
    
    // Recency contributes 20%
    uint64_t current_time = get_current_time_microseconds();
    uint64_t time_since_access = current_time - entry->last_access_time;
    float recency_score = fmaxf(0.0f, 1.0f - (time_since_access / 3600000000.0f)); // 1 hour decay
    score += recency_score * 0.2f;
    
    // Pattern confidence contributes 10%
    score += entry->usage_pattern.pattern_confidence * 0.1f;
    
    return fminf(1.0f, score);
}

// Utility functions
const char* cache_eviction_policy_to_string(cache_eviction_policy_t policy) {
    switch (policy) {
        case EVICTION_LRU: return "LRU";
        case EVICTION_LFU: return "LFU";
        case EVICTION_ARC: return "ARC";
        case EVICTION_CLOCK: return "Clock";
        case EVICTION_PREDICTIVE: return "Predictive";
        case EVICTION_PRIORITY: return "Priority";
        case EVICTION_HYBRID: return "Hybrid";
        default: return "Unknown";
    }
}

const char* asset_priority_to_string(asset_priority_t priority) {
    switch (priority) {
        case ASSET_PRIORITY_CRITICAL: return "Critical";
        case ASSET_PRIORITY_HIGH: return "High";
        case ASSET_PRIORITY_MEDIUM: return "Medium";
        case ASSET_PRIORITY_LOW: return "Low";
        case ASSET_PRIORITY_MINIMAL: return "Minimal";
        default: return "Unknown";
    }
}

const char* cache_entry_state_to_string(cache_entry_state_t state) {
    switch (state) {
        case CACHE_STATE_COLD: return "Cold";
        case CACHE_STATE_WARM: return "Warm";
        case CACHE_STATE_HOT: return "Hot";
        case CACHE_STATE_CRITICAL: return "Critical";
        case CACHE_STATE_PREDICTED: return "Predicted";
        case CACHE_STATE_PREFETCHED: return "Prefetched";
        default: return "Unknown";
    }
}