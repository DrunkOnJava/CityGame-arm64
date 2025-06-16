/*
 * SimCity ARM64 - Intelligent Shader Compilation Cache Implementation
 * High-Performance Binary Caching with Smart Invalidation
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Week 2 - Day 6: Advanced Shader Features
 * 
 * Performance Targets:
 * - Cache lookup: <1ms
 * - Binary load: <10ms
 * - Dependency validation: <5ms
 * - Cache hit rate: >85%
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <dirent.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <pthread.h>
#include <dispatch/dispatch.h>

#include "shader_compilation_cache.h"
#include "module_interface.h"

// Cache implementation constants
#define MAX_CACHE_ENTRIES 1024
#define CACHE_KEY_SIZE 64
#define CACHE_MAGIC_NUMBER 0x53484452  // "SHDR"
#define CACHE_VERSION 1
#define DEFAULT_CACHE_SIZE_MB 256
#define HASH_TABLE_SIZE 256

// Hash table entry for fast lookups
typedef struct cache_hash_entry {
    char cache_key[CACHE_KEY_SIZE];
    hmr_cache_entry_t* entry;
    struct cache_hash_entry* next;
} cache_hash_entry_t;

// Cache manager internal state
struct hmr_cache_manager {
    hmr_cache_config_t config;
    
    // Entry storage
    hmr_cache_entry_t entries[MAX_CACHE_ENTRIES];
    uint32_t entry_count;
    
    // Hash table for fast lookups
    cache_hash_entry_t* hash_table[HASH_TABLE_SIZE];
    cache_hash_entry_t hash_entries[MAX_CACHE_ENTRIES];
    uint32_t hash_entry_count;
    
    // Statistics
    hmr_cache_statistics_t stats;
    
    // Synchronization
    pthread_rwlock_t cache_lock;
    pthread_mutex_t stats_lock;
    
    // Background operations
    dispatch_queue_t validation_queue;
    dispatch_queue_t compilation_queue;
    dispatch_source_t validation_timer;
    bool background_validation_active;
    bool predictive_compilation_active;
    
    // Callbacks
    void (*on_cache_hit)(const char* cache_key, uint64_t saved_time_ns);
    void (*on_cache_miss)(const char* cache_key, const char* reason);
    void (*on_cache_eviction)(const char* cache_key, const char* reason);
    void (*on_validation_complete)(uint32_t validated_count, uint32_t invalidated_count);
};

// Global cache manager instance
static hmr_cache_manager_t* g_cache_manager = NULL;

// Utility functions
static uint64_t hmr_get_current_time_ns(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (uint64_t)tv.tv_sec * 1000000000ULL + (uint64_t)tv.tv_usec * 1000ULL;
}

static uint32_t hmr_hash_function(const char* key) {
    uint32_t hash = 5381;
    int c;
    while ((c = *key++)) {
        hash = ((hash << 5) + hash) + c;
    }
    return hash % HASH_TABLE_SIZE;
}

static cache_hash_entry_t* hmr_find_hash_entry(const char* cache_key) {
    uint32_t hash = hmr_hash_function(cache_key);
    cache_hash_entry_t* entry = g_cache_manager->hash_table[hash];
    
    while (entry) {
        if (strcmp(entry->cache_key, cache_key) == 0) {
            return entry;
        }
        entry = entry->next;
    }
    
    return NULL;
}

static void hmr_add_hash_entry(const char* cache_key, hmr_cache_entry_t* cache_entry) {
    if (g_cache_manager->hash_entry_count >= MAX_CACHE_ENTRIES) {
        return; // Hash table full
    }
    
    uint32_t hash = hmr_hash_function(cache_key);
    cache_hash_entry_t* hash_entry = &g_cache_manager->hash_entries[g_cache_manager->hash_entry_count++];
    
    strncpy(hash_entry->cache_key, cache_key, sizeof(hash_entry->cache_key) - 1);
    hash_entry->entry = cache_entry;
    hash_entry->next = g_cache_manager->hash_table[hash];
    g_cache_manager->hash_table[hash] = hash_entry;
}

static void hmr_remove_hash_entry(const char* cache_key) {
    uint32_t hash = hmr_hash_function(cache_key);
    cache_hash_entry_t** current = &g_cache_manager->hash_table[hash];
    
    while (*current) {
        if (strcmp((*current)->cache_key, cache_key) == 0) {
            cache_hash_entry_t* to_remove = *current;
            *current = to_remove->next;
            
            // Clear the removed entry
            memset(to_remove, 0, sizeof(cache_hash_entry_t));
            return;
        }
        current = &(*current)->next;
    }
}

// Create cache directory structure
static int32_t hmr_create_cache_directories(void) {
    char path[512];
    
    // Create main cache directory
    if (mkdir(g_cache_manager->config.cache_directory, 0755) != 0 && errno != EEXIST) {
        printf("HMR Cache: Failed to create cache directory: %s\n", strerror(errno));
        return HMR_ERROR_IO_ERROR;
    }
    
    // Create subdirectories
    snprintf(path, sizeof(path), "%s/binaries", g_cache_manager->config.cache_directory);
    if (mkdir(path, 0755) != 0 && errno != EEXIST) {
        printf("HMR Cache: Failed to create binaries directory\n");
        return HMR_ERROR_IO_ERROR;
    }
    
    snprintf(path, sizeof(path), "%s/metadata", g_cache_manager->config.cache_directory);
    if (mkdir(path, 0755) != 0 && errno != EEXIST) {
        printf("HMR Cache: Failed to create metadata directory\n");
        return HMR_ERROR_IO_ERROR;
    }
    
    return HMR_SUCCESS;
}

// Load cache entry metadata from disk
static int32_t hmr_load_cache_metadata(hmr_cache_entry_t* entry) {
    FILE* file = fopen(entry->metadata_cache_path, "rb");
    if (!file) {
        return HMR_ERROR_NOT_FOUND;
    }
    
    // Read magic number and version
    uint32_t magic, version;
    if (fread(&magic, sizeof(magic), 1, file) != 1 || magic != CACHE_MAGIC_NUMBER) {
        fclose(file);
        return HMR_ERROR_INVALID_FORMAT;
    }
    
    if (fread(&version, sizeof(version), 1, file) != 1 || version != CACHE_VERSION) {
        fclose(file);
        return HMR_ERROR_VERSION_MISMATCH;
    }
    
    // Read entry data
    if (fread(entry, sizeof(hmr_cache_entry_t), 1, file) != 1) {
        fclose(file);
        return HMR_ERROR_IO_ERROR;
    }
    
    fclose(file);
    return HMR_SUCCESS;
}

// Save cache entry metadata to disk
static int32_t hmr_save_cache_metadata(const hmr_cache_entry_t* entry) {
    FILE* file = fopen(entry->metadata_cache_path, "wb");
    if (!file) {
        return HMR_ERROR_IO_ERROR;
    }
    
    // Write magic number and version
    uint32_t magic = CACHE_MAGIC_NUMBER;
    uint32_t version = CACHE_VERSION;
    
    if (fwrite(&magic, sizeof(magic), 1, file) != 1 ||
        fwrite(&version, sizeof(version), 1, file) != 1 ||
        fwrite(entry, sizeof(hmr_cache_entry_t), 1, file) != 1) {
        fclose(file);
        return HMR_ERROR_IO_ERROR;
    }
    
    fclose(file);
    return HMR_SUCCESS;
}

// Validate cache entry dependencies
static bool hmr_validate_cache_dependencies(hmr_cache_entry_t* entry) {
    for (uint32_t i = 0; i < entry->dependency_count; i++) {
        hmr_cache_dependency_t* dep = &entry->dependencies[i];
        
        struct stat stat_buf;
        if (stat(dep->file_path, &stat_buf) != 0) {
            // Dependency file no longer exists
            return false;
        }
        
        // Check modification time
        uint64_t current_mtime = (uint64_t)stat_buf.st_mtime * 1000000000ULL;
        if (current_mtime > dep->last_modified_time) {
            return false;
        }
        
        // Check file size
        if ((uint64_t)stat_buf.st_size != dep->file_size) {
            return false;
        }
        
        // Optionally check content hash (expensive operation)
        if (g_cache_manager->config.enable_content_validation) {
            uint32_t current_hash = hmr_cache_hash_file(dep->file_path);
            if (current_hash != dep->content_hash) {
                return false;
            }
        }
    }
    
    return true;
}

// Background validation task
static void hmr_background_validation_task(void) {
    pthread_rwlock_rdlock(&g_cache_manager->cache_lock);
    
    uint32_t validated_count = 0;
    uint32_t invalidated_count = 0;
    
    for (uint32_t i = 0; i < g_cache_manager->entry_count; i++) {
        hmr_cache_entry_t* entry = &g_cache_manager->entries[i];
        
        if (entry->status == HMR_CACHE_STATUS_VALID) {
            uint64_t current_time = hmr_get_current_time_ns();
            uint64_t time_since_validation = current_time - entry->last_validated_time;
            
            // Check if entry needs validation
            if (time_since_validation > (uint64_t)g_cache_manager->config.validation_interval_sec * 1000000000ULL) {
                if (hmr_validate_cache_dependencies(entry)) {
                    entry->last_validated_time = current_time;
                    validated_count++;
                } else {
                    entry->status = HMR_CACHE_STATUS_STALE;
                    invalidated_count++;
                }
            }
        }
    }
    
    pthread_rwlock_unlock(&g_cache_manager->cache_lock);
    
    // Update statistics
    pthread_mutex_lock(&g_cache_manager->stats_lock);
    g_cache_manager->stats.valid_entries = g_cache_manager->entry_count - invalidated_count;
    g_cache_manager->stats.stale_entries += invalidated_count;
    pthread_mutex_unlock(&g_cache_manager->stats_lock);
    
    // Call callback
    if (g_cache_manager->on_validation_complete) {
        g_cache_manager->on_validation_complete(validated_count, invalidated_count);
    }
    
    printf("HMR Cache: Background validation complete - validated: %u, invalidated: %u\n", 
           validated_count, invalidated_count);
}

// Public API implementation

int32_t hmr_cache_manager_init(const hmr_cache_config_t* config) {
    if (g_cache_manager) {
        return HMR_ERROR_ALREADY_EXISTS;
    }
    
    if (!config) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    g_cache_manager = calloc(1, sizeof(hmr_cache_manager_t));
    if (!g_cache_manager) {
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    // Copy configuration with defaults
    memcpy(&g_cache_manager->config, config, sizeof(hmr_cache_config_t));
    
    if (g_cache_manager->config.max_cache_size_mb == 0) {
        g_cache_manager->config.max_cache_size_mb = DEFAULT_CACHE_SIZE_MB;
    }
    
    if (g_cache_manager->config.max_entries == 0) {
        g_cache_manager->config.max_entries = MAX_CACHE_ENTRIES;
    }
    
    // Initialize synchronization
    if (pthread_rwlock_init(&g_cache_manager->cache_lock, NULL) != 0) {
        free(g_cache_manager);
        g_cache_manager = NULL;
        return HMR_ERROR_SYSTEM_ERROR;
    }
    
    if (pthread_mutex_init(&g_cache_manager->stats_lock, NULL) != 0) {
        pthread_rwlock_destroy(&g_cache_manager->cache_lock);
        free(g_cache_manager);
        g_cache_manager = NULL;
        return HMR_ERROR_SYSTEM_ERROR;
    }
    
    // Create cache directories
    int32_t result = hmr_create_cache_directories();
    if (result != HMR_SUCCESS) {
        pthread_mutex_destroy(&g_cache_manager->stats_lock);
        pthread_rwlock_destroy(&g_cache_manager->cache_lock);
        free(g_cache_manager);
        g_cache_manager = NULL;
        return result;
    }
    
    // Create background queues
    g_cache_manager->validation_queue = dispatch_queue_create("com.simcity.hmr.cache_validation", 
                                                             DISPATCH_QUEUE_SERIAL);
    g_cache_manager->compilation_queue = dispatch_queue_create("com.simcity.hmr.cache_compilation", 
                                                              DISPATCH_QUEUE_CONCURRENT);
    
    // Initialize statistics
    g_cache_manager->stats.total_entries = 0;
    g_cache_manager->stats.hit_rate = 0.0f;
    
    printf("HMR Cache Manager: Initialized successfully\n");
    printf("  Cache directory: %s\n", config->cache_directory);
    printf("  Max cache size: %zu MB\n", config->max_cache_size_mb);
    printf("  Max entries: %u\n", config->max_entries);
    printf("  Dependency tracking: %s\n", config->enable_dependency_tracking ? "Yes" : "No");
    
    return HMR_SUCCESS;
}

void hmr_cache_generate_key(const char* source_path, const char* variant_name, 
                           const char* compilation_flags, char* cache_key, size_t key_size) {
    // Create a hash-based cache key
    uint32_t hash = 0;
    
    // Hash source path
    const char* str = source_path;
    while (*str) {
        hash = hash * 31 + *str++;
    }
    
    // Hash variant name
    if (variant_name) {
        str = variant_name;
        while (*str) {
            hash = hash * 31 + *str++;
        }
    }
    
    // Hash compilation flags
    if (compilation_flags) {
        str = compilation_flags;
        while (*str) {
            hash = hash * 31 + *str++;
        }
    }
    
    snprintf(cache_key, key_size, "shader_%08x", hash);
}

int32_t hmr_cache_get_entry(const char* cache_key, hmr_cache_entry_t** entry) {
    if (!g_cache_manager || !cache_key || !entry) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    pthread_rwlock_rdlock(&g_cache_manager->cache_lock);
    
    cache_hash_entry_t* hash_entry = hmr_find_hash_entry(cache_key);
    if (hash_entry && hash_entry->entry->status == HMR_CACHE_STATUS_VALID) {
        *entry = hash_entry->entry;
        
        // Update access statistics
        hash_entry->entry->last_accessed_time = hmr_get_current_time_ns();
        hash_entry->entry->access_count++;
        
        pthread_rwlock_unlock(&g_cache_manager->cache_lock);
        
        // Update statistics
        pthread_mutex_lock(&g_cache_manager->stats_lock);
        g_cache_manager->stats.cache_hits++;
        g_cache_manager->stats.hit_rate = (float)g_cache_manager->stats.cache_hits / 
                                         (g_cache_manager->stats.cache_hits + g_cache_manager->stats.cache_misses);
        pthread_mutex_unlock(&g_cache_manager->stats_lock);
        
        // Call callback
        if (g_cache_manager->on_cache_hit) {
            g_cache_manager->on_cache_hit(cache_key, hash_entry->entry->compile_time_ns);
        }
        
        return HMR_SUCCESS;
    }
    
    pthread_rwlock_unlock(&g_cache_manager->cache_lock);
    
    // Update miss statistics
    pthread_mutex_lock(&g_cache_manager->stats_lock);
    g_cache_manager->stats.cache_misses++;
    g_cache_manager->stats.hit_rate = (float)g_cache_manager->stats.cache_hits / 
                                     (g_cache_manager->stats.cache_hits + g_cache_manager->stats.cache_misses);
    pthread_mutex_unlock(&g_cache_manager->stats_lock);
    
    // Call callback
    if (g_cache_manager->on_cache_miss) {
        g_cache_manager->on_cache_miss(cache_key, hash_entry ? "stale" : "not_found");
    }
    
    return HMR_ERROR_NOT_FOUND;
}

int32_t hmr_cache_put_entry(const char* cache_key, const hmr_cache_entry_t* entry) {
    if (!g_cache_manager || !cache_key || !entry) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    pthread_rwlock_wrlock(&g_cache_manager->cache_lock);
    
    // Check if entry already exists
    cache_hash_entry_t* existing = hmr_find_hash_entry(cache_key);
    if (existing) {
        // Update existing entry
        memcpy(existing->entry, entry, sizeof(hmr_cache_entry_t));
        existing->entry->last_accessed_time = hmr_get_current_time_ns();
    } else {
        // Add new entry
        if (g_cache_manager->entry_count >= MAX_CACHE_ENTRIES) {
            pthread_rwlock_unlock(&g_cache_manager->cache_lock);
            return HMR_ERROR_OUT_OF_MEMORY;
        }
        
        hmr_cache_entry_t* new_entry = &g_cache_manager->entries[g_cache_manager->entry_count++];
        memcpy(new_entry, entry, sizeof(hmr_cache_entry_t));
        strncpy(new_entry->cache_key, cache_key, sizeof(new_entry->cache_key) - 1);
        new_entry->created_time = hmr_get_current_time_ns();
        new_entry->last_accessed_time = new_entry->created_time;
        
        // Generate cache file paths
        snprintf(new_entry->binary_cache_path, sizeof(new_entry->binary_cache_path),
                "%s/binaries/%s.bin", g_cache_manager->config.cache_directory, cache_key);
        snprintf(new_entry->metadata_cache_path, sizeof(new_entry->metadata_cache_path),
                "%s/metadata/%s.meta", g_cache_manager->config.cache_directory, cache_key);
        
        // Add to hash table
        hmr_add_hash_entry(cache_key, new_entry);
        
        // Save metadata to disk
        if (g_cache_manager->config.enable_persistent_cache) {
            hmr_save_cache_metadata(new_entry);
        }
    }
    
    pthread_rwlock_unlock(&g_cache_manager->cache_lock);
    
    // Update statistics
    pthread_mutex_lock(&g_cache_manager->stats_lock);
    g_cache_manager->stats.total_entries = g_cache_manager->entry_count;
    if (entry->status == HMR_CACHE_STATUS_VALID) {
        g_cache_manager->stats.valid_entries++;
    }
    pthread_mutex_unlock(&g_cache_manager->stats_lock);
    
    return HMR_SUCCESS;
}

uint32_t hmr_cache_hash_string(const char* str) {
    uint32_t hash = 5381;
    int c;
    while ((c = *str++)) {
        hash = ((hash << 5) + hash) + c;
    }
    return hash;
}

uint32_t hmr_cache_hash_file(const char* file_path) {
    FILE* file = fopen(file_path, "rb");
    if (!file) {
        return 0;
    }
    
    uint32_t hash = 5381;
    int c;
    while ((c = fgetc(file)) != EOF) {
        hash = ((hash << 5) + hash) + c;
    }
    
    fclose(file);
    return hash;
}

uint64_t hmr_cache_get_file_mtime(const char* file_path) {
    struct stat stat_buf;
    if (stat(file_path, &stat_buf) != 0) {
        return 0;
    }
    return (uint64_t)stat_buf.st_mtime * 1000000000ULL;
}

int32_t hmr_cache_start_background_validation(void) {
    if (!g_cache_manager || g_cache_manager->background_validation_active) {
        return HMR_ERROR_INVALID_STATE;
    }
    
    // Create validation timer
    g_cache_manager->validation_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, 
                                                              g_cache_manager->validation_queue);
    
    if (!g_cache_manager->validation_timer) {
        return HMR_ERROR_SYSTEM_ERROR;
    }
    
    // Set timer to fire every validation interval
    uint64_t interval = (uint64_t)g_cache_manager->config.validation_interval_sec * NSEC_PER_SEC;
    dispatch_source_set_timer(g_cache_manager->validation_timer, 
                             dispatch_time(DISPATCH_TIME_NOW, interval),
                             interval, 
                             NSEC_PER_SEC); // 1 second leeway
    
    dispatch_source_set_event_handler(g_cache_manager->validation_timer, ^{
        hmr_background_validation_task();
    });
    
    dispatch_resume(g_cache_manager->validation_timer);
    g_cache_manager->background_validation_active = true;
    
    printf("HMR Cache: Background validation started (interval: %us)\n", 
           g_cache_manager->config.validation_interval_sec);
    
    return HMR_SUCCESS;
}

void hmr_cache_get_statistics(hmr_cache_statistics_t* stats) {
    if (!g_cache_manager || !stats) return;
    
    pthread_mutex_lock(&g_cache_manager->stats_lock);
    memcpy(stats, &g_cache_manager->stats, sizeof(hmr_cache_statistics_t));
    pthread_mutex_unlock(&g_cache_manager->stats_lock);
}

void hmr_cache_set_callbacks(
    void (*on_cache_hit)(const char* cache_key, uint64_t saved_time_ns),
    void (*on_cache_miss)(const char* cache_key, const char* reason),
    void (*on_cache_eviction)(const char* cache_key, const char* reason),
    void (*on_validation_complete)(uint32_t validated_count, uint32_t invalidated_count)
) {
    if (!g_cache_manager) return;
    
    g_cache_manager->on_cache_hit = on_cache_hit;
    g_cache_manager->on_cache_miss = on_cache_miss;
    g_cache_manager->on_cache_eviction = on_cache_eviction;
    g_cache_manager->on_validation_complete = on_validation_complete;
}

void hmr_cache_manager_cleanup(void) {
    if (!g_cache_manager) return;
    
    // Stop background validation
    if (g_cache_manager->background_validation_active) {
        dispatch_source_cancel(g_cache_manager->validation_timer);
        g_cache_manager->background_validation_active = false;
    }
    
    // Release dispatch objects
    if (g_cache_manager->validation_queue) {
        dispatch_release(g_cache_manager->validation_queue);
    }
    if (g_cache_manager->compilation_queue) {
        dispatch_release(g_cache_manager->compilation_queue);
    }
    if (g_cache_manager->validation_timer) {
        dispatch_release(g_cache_manager->validation_timer);
    }
    
    // Destroy synchronization objects
    pthread_mutex_destroy(&g_cache_manager->stats_lock);
    pthread_rwlock_destroy(&g_cache_manager->cache_lock);
    
    free(g_cache_manager);
    g_cache_manager = NULL;
    
    printf("HMR Cache Manager: Cleanup complete\n");
}