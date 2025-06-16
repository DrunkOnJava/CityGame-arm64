/*
 * SimCity ARM64 - Intelligent Build Optimizer Implementation
 * Agent 2: File Watcher & Build Pipeline - Week 2 Day 6
 * 
 * Smart dependency analysis and build optimization system
 * Features:
 * - Content-based hashing for cache invalidation
 * - Minimal rebuild scope calculation
 * - Parallel build scheduling with CPU/memory awareness
 * - Distributed build preparation
 * - Advanced build metrics and performance optimization
 */

#include "build_optimizer.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <mach/mach_time.h>
#include <CommonCrypto/CommonDigest.h>

// Build optimizer state
typedef struct {
    build_module_t modules[BUILD_MAX_MODULES];
    uint32_t module_count;
    
    build_cache_entry_t cache[BUILD_MAX_CACHE_ENTRIES];
    uint32_t cache_count;
    uint64_t cache_size_limit;
    
    build_optimizer_callbacks_t callbacks;
    build_metrics_t metrics;
    
    // Configuration
    uint32_t max_parallel_jobs;
    uint64_t build_timeout_ns;
    bool debug_mode;
    
    // Runtime state
    uint32_t active_builds;
    uint32_t build_job_counter;
    mach_timebase_info_data_t timebase_info;
    
    char error_message[512];
} build_optimizer_state_t;

static build_optimizer_state_t* g_build_optimizer = NULL;

// Helper function to get current time in nanoseconds
static uint64_t get_current_time_ns(void) {
    if (g_build_optimizer->timebase_info.denom == 0) {
        mach_timebase_info(&g_build_optimizer->timebase_info);
    }
    
    uint64_t mach_time = mach_absolute_time();
    return mach_time * g_build_optimizer->timebase_info.numer / g_build_optimizer->timebase_info.denom;
}

// Helper function to get system information
static void get_system_info(uint32_t* cpu_cores, uint64_t* memory_gb) {
    size_t size = sizeof(uint32_t);
    sysctlbyname("hw.ncpu", cpu_cores, &size, NULL, 0);
    
    uint64_t memory_bytes;
    size = sizeof(uint64_t);
    sysctlbyname("hw.memsize", &memory_bytes, &size, NULL, 0);
    *memory_gb = memory_bytes / (1024 * 1024 * 1024);
}

// Initialize build optimizer
int32_t build_optimizer_init(uint32_t max_modules, const build_optimizer_callbacks_t* callbacks) {
    if (g_build_optimizer) {
        return BUILD_ERROR_ALREADY_EXISTS;
    }
    
    if (max_modules > BUILD_MAX_MODULES) {
        return BUILD_ERROR_INVALID_ARG;
    }
    
    g_build_optimizer = calloc(1, sizeof(build_optimizer_state_t));
    if (!g_build_optimizer) {
        return BUILD_ERROR_OUT_OF_MEMORY;
    }
    
    // Initialize callbacks
    if (callbacks) {
        g_build_optimizer->callbacks = *callbacks;
    }
    
    // Initialize configuration with system-aware defaults
    uint32_t cpu_cores;
    uint64_t memory_gb;
    get_system_info(&cpu_cores, &memory_gb);
    
    g_build_optimizer->max_parallel_jobs = cpu_cores > 8 ? cpu_cores - 2 : cpu_cores;
    g_build_optimizer->cache_size_limit = memory_gb > 8 ? 2ULL * 1024 * 1024 * 1024 : 1ULL * 1024 * 1024 * 1024; // 2GB or 1GB
    g_build_optimizer->build_timeout_ns = 300ULL * 1000 * 1000 * 1000; // 5 minutes
    
    printf("Build Optimizer: Initialized with %u max modules, %u CPU cores, %llu GB RAM\n", 
           max_modules, cpu_cores, memory_gb);
    printf("Build Optimizer: Parallel jobs: %u, Cache limit: %llu MB\n",
           g_build_optimizer->max_parallel_jobs, g_build_optimizer->cache_size_limit / (1024 * 1024));
    
    return BUILD_SUCCESS;
}

// Add build module
int32_t build_optimizer_add_module(const build_module_t* module) {
    if (!g_build_optimizer || !module) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    if (g_build_optimizer->module_count >= BUILD_MAX_MODULES) {
        return BUILD_ERROR_OUT_OF_MEMORY;
    }
    
    // Check if module already exists
    for (uint32_t i = 0; i < g_build_optimizer->module_count; i++) {
        if (strcmp(g_build_optimizer->modules[i].name, module->name) == 0) {
            return BUILD_ERROR_ALREADY_EXISTS;
        }
    }
    
    // Add new module
    g_build_optimizer->modules[g_build_optimizer->module_count] = *module;
    g_build_optimizer->module_count++;
    
    if (g_build_optimizer->debug_mode) {
        printf("Build Optimizer: Added module '%s' (type: %d, priority: %d)\n",
               module->name, module->target_type, module->priority);
    }
    
    return BUILD_SUCCESS;
}

// Hash file content using SHA-256
int32_t build_optimizer_hash_file(const char* file_path, uint8_t* hash_out) {
    if (!file_path || !hash_out) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    FILE* file = fopen(file_path, "rb");
    if (!file) {
        return BUILD_ERROR_IO_ERROR;
    }
    
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    
    uint8_t buffer[8192];
    size_t bytes_read;
    
    while ((bytes_read = fread(buffer, 1, sizeof(buffer), file)) > 0) {
        CC_SHA256_Update(&context, buffer, (CC_LONG)bytes_read);
    }
    
    CC_SHA256_Final(hash_out, &context);
    fclose(file);
    
    return BUILD_SUCCESS;
}

// Hash module dependencies
int32_t build_optimizer_hash_dependencies(const char* module_name, uint8_t* hash_out) {
    if (!g_build_optimizer || !module_name || !hash_out) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    // Find module
    build_module_t* module = NULL;
    for (uint32_t i = 0; i < g_build_optimizer->module_count; i++) {
        if (strcmp(g_build_optimizer->modules[i].name, module_name) == 0) {
            module = &g_build_optimizer->modules[i];
            break;
        }
    }
    
    if (!module) {
        return BUILD_ERROR_NOT_FOUND;
    }
    
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    
    // Hash all dependency names and their modification times
    for (uint32_t i = 0; i < module->dependency_count; i++) {
        CC_SHA256_Update(&context, module->dependencies[i], strlen(module->dependencies[i]));
        
        // Try to hash the dependency file if it exists
        char dep_path[BUILD_MAX_PATH_LENGTH];
        snprintf(dep_path, sizeof(dep_path), "%s/%s", module->source_dir, module->dependencies[i]);
        
        struct stat file_stat;
        if (stat(dep_path, &file_stat) == 0) {
            CC_SHA256_Update(&context, &file_stat.st_mtime, sizeof(file_stat.st_mtime));
            CC_SHA256_Update(&context, &file_stat.st_size, sizeof(file_stat.st_size));
        }
    }
    
    CC_SHA256_Final(hash_out, &context);
    return BUILD_SUCCESS;
}

// Check build cache
int32_t build_optimizer_check_cache(const char* source_path, const char* output_path, bool* needs_rebuild) {
    if (!g_build_optimizer || !source_path || !output_path || !needs_rebuild) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    *needs_rebuild = true;
    
    // Find cache entry
    build_cache_entry_t* entry = NULL;
    for (uint32_t i = 0; i < g_build_optimizer->cache_count; i++) {
        if (strcmp(g_build_optimizer->cache[i].source_path, source_path) == 0 &&
            strcmp(g_build_optimizer->cache[i].output_path, output_path) == 0 &&
            g_build_optimizer->cache[i].is_valid) {
            entry = &g_build_optimizer->cache[i];
            break;
        }
    }
    
    if (!entry) {
        g_build_optimizer->metrics.cache_misses++;
        if (g_build_optimizer->callbacks.on_cache_update) {
            g_build_optimizer->callbacks.on_cache_update(source_path, false);
        }
        return BUILD_SUCCESS;
    }
    
    // Check if source file exists and get its hash
    uint8_t current_hash[BUILD_HASH_SIZE];
    if (build_optimizer_hash_file(source_path, current_hash) != BUILD_SUCCESS) {
        return BUILD_SUCCESS; // File doesn't exist, needs rebuild
    }
    
    // Check if output file exists
    struct stat output_stat;
    if (stat(output_path, &output_stat) != 0) {
        return BUILD_SUCCESS; // Output doesn't exist, needs rebuild
    }
    
    // Compare hashes
    if (memcmp(entry->content_hash, current_hash, BUILD_HASH_SIZE) == 0) {
        *needs_rebuild = false;
        g_build_optimizer->metrics.cache_hits++;
        
        if (g_build_optimizer->callbacks.on_cache_update) {
            g_build_optimizer->callbacks.on_cache_update(source_path, true);
        }
        
        if (g_build_optimizer->debug_mode) {
            printf("Build Optimizer: Cache hit for %s -> %s\n", source_path, output_path);
        }
    } else {
        g_build_optimizer->metrics.cache_misses++;
        if (g_build_optimizer->callbacks.on_cache_update) {
            g_build_optimizer->callbacks.on_cache_update(source_path, false);
        }
    }
    
    return BUILD_SUCCESS;
}

// Update build cache
int32_t build_optimizer_update_cache(const char* source_path, const char* output_path,
                                    const uint8_t* content_hash, uint64_t build_time_ns) {
    if (!g_build_optimizer || !source_path || !output_path || !content_hash) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    // Find existing entry or create new one
    build_cache_entry_t* entry = NULL;
    for (uint32_t i = 0; i < g_build_optimizer->cache_count; i++) {
        if (strcmp(g_build_optimizer->cache[i].source_path, source_path) == 0 &&
            strcmp(g_build_optimizer->cache[i].output_path, output_path) == 0) {
            entry = &g_build_optimizer->cache[i];
            break;
        }
    }
    
    if (!entry && g_build_optimizer->cache_count < BUILD_MAX_CACHE_ENTRIES) {
        entry = &g_build_optimizer->cache[g_build_optimizer->cache_count++];
    }
    
    if (!entry) {
        return BUILD_ERROR_CACHE_FULL;
    }
    
    // Update cache entry
    strncpy(entry->source_path, source_path, sizeof(entry->source_path) - 1);
    strncpy(entry->output_path, output_path, sizeof(entry->output_path) - 1);
    memcpy(entry->content_hash, content_hash, BUILD_HASH_SIZE);
    entry->timestamp = get_current_time_ns();
    entry->build_time_ns = build_time_ns;
    entry->is_valid = true;
    
    if (g_build_optimizer->debug_mode) {
        printf("Build Optimizer: Updated cache for %s (build time: %.2f ms)\n",
               source_path, build_time_ns / 1000000.0);
    }
    
    return BUILD_SUCCESS;
}

// Analyze dependencies for a changed file
int32_t build_optimizer_analyze_dependencies(const char* changed_file, build_analysis_t* analysis) {
    if (!g_build_optimizer || !changed_file || !analysis) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    memset(analysis, 0, sizeof(build_analysis_t));
    
    uint64_t start_time = get_current_time_ns();
    
    // Find all modules that depend on the changed file
    for (uint32_t i = 0; i < g_build_optimizer->module_count; i++) {
        build_module_t* module = &g_build_optimizer->modules[i];
        bool depends_on_file = false;
        
        // Check if the changed file is in the module's source directory
        if (strstr(changed_file, module->source_dir) == changed_file) {
            depends_on_file = true;
        } else {
            // Check dependencies
            for (uint32_t j = 0; j < module->dependency_count; j++) {
                if (strstr(changed_file, module->dependencies[j]) != NULL) {
                    depends_on_file = true;
                    break;
                }
            }
        }
        
        if (depends_on_file && analysis->module_count < BUILD_MAX_MODULES) {
            analysis->module_indices[analysis->module_count++] = i;
            module->needs_rebuild = true;
        }
    }
    
    // Calculate build order based on dependencies and priorities
    for (uint32_t i = 0; i < analysis->module_count; i++) {
        uint32_t module_idx = analysis->module_indices[i];
        build_module_t* module = &g_build_optimizer->modules[module_idx];
        
        // Priority-based ordering (critical first)
        uint32_t insert_pos = 0;
        for (uint32_t j = 0; j < i; j++) {
            uint32_t existing_idx = analysis->module_indices[analysis->build_order[j]];
            build_module_t* existing = &g_build_optimizer->modules[existing_idx];
            if (module->priority <= existing->priority) {
                insert_pos = j + 1;
            }
        }
        
        // Shift elements to make room
        for (uint32_t j = i; j > insert_pos; j--) {
            analysis->build_order[j] = analysis->build_order[j - 1];
        }
        analysis->build_order[insert_pos] = i;
    }
    
    // Estimate total build time
    for (uint32_t i = 0; i < analysis->module_count; i++) {
        uint32_t module_idx = analysis->module_indices[i];
        build_module_t* module = &g_build_optimizer->modules[module_idx];
        analysis->estimated_time_ns += module->last_build_time > 0 ? module->last_build_time : 5000000000ULL; // 5s default
    }
    
    // Calculate parallel job opportunities
    analysis->parallel_job_count = analysis->module_count > g_build_optimizer->max_parallel_jobs ? 
                                  g_build_optimizer->max_parallel_jobs : analysis->module_count;
    
    uint64_t end_time = get_current_time_ns();
    
    if (g_build_optimizer->debug_mode) {
        printf("Build Optimizer: Dependency analysis for '%s' found %u modules (%.2f ms)\n",
               changed_file, analysis->module_count, (end_time - start_time) / 1000000.0);
    }
    
    return BUILD_SUCCESS;
}

// Calculate optimal parallel job count
int32_t build_optimizer_calculate_parallel_jobs(uint32_t available_cores, uint32_t memory_gb,
                                               uint32_t* recommended_jobs) {
    if (!recommended_jobs) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    // Conservative approach: leave 1-2 cores free for system
    uint32_t max_cpu_jobs = available_cores > 2 ? available_cores - 1 : 1;
    
    // Memory constraint: assume 2GB per compile job for ARM64 assembly
    uint32_t max_memory_jobs = memory_gb >= 2 ? memory_gb / 2 : 1;
    
    // Take the minimum of CPU and memory constraints
    *recommended_jobs = max_cpu_jobs < max_memory_jobs ? max_cpu_jobs : max_memory_jobs;
    
    // Cap at system maximum
    if (*recommended_jobs > BUILD_MAX_PARALLEL_JOBS) {
        *recommended_jobs = BUILD_MAX_PARALLEL_JOBS;
    }
    
    return BUILD_SUCCESS;
}

// Start a build
int32_t build_optimizer_start_build(const char* module_name, uint32_t job_id) {
    if (!g_build_optimizer || !module_name) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    // Find module
    build_module_t* module = NULL;
    for (uint32_t i = 0; i < g_build_optimizer->module_count; i++) {
        if (strcmp(g_build_optimizer->modules[i].name, module_name) == 0) {
            module = &g_build_optimizer->modules[i];
            break;
        }
    }
    
    if (!module) {
        return BUILD_ERROR_NOT_FOUND;
    }
    
    if (module->is_building) {
        return BUILD_ERROR_ALREADY_EXISTS;
    }
    
    module->is_building = true;
    module->build_job_id = job_id;
    g_build_optimizer->active_builds++;
    
    if (g_build_optimizer->callbacks.on_build_start) {
        g_build_optimizer->callbacks.on_build_start(module_name, module->target_type);
    }
    
    if (g_build_optimizer->debug_mode) {
        printf("Build Optimizer: Started build for module '%s' (job %u)\n", module_name, job_id);
    }
    
    return BUILD_SUCCESS;
}

// Complete a build
int32_t build_optimizer_complete_build(const char* module_name, bool success, uint64_t build_time_ns) {
    if (!g_build_optimizer || !module_name) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    // Find module
    build_module_t* module = NULL;
    for (uint32_t i = 0; i < g_build_optimizer->module_count; i++) {
        if (strcmp(g_build_optimizer->modules[i].name, module_name) == 0) {
            module = &g_build_optimizer->modules[i];
            break;
        }
    }
    
    if (!module || !module->is_building) {
        return BUILD_ERROR_NOT_FOUND;
    }
    
    module->is_building = false;
    module->needs_rebuild = false;
    module->last_build_time = build_time_ns;
    g_build_optimizer->active_builds--;
    
    // Update metrics
    g_build_optimizer->metrics.total_builds++;
    g_build_optimizer->metrics.total_build_time_ns += build_time_ns;
    g_build_optimizer->metrics.average_build_time_ns = 
        g_build_optimizer->metrics.total_build_time_ns / g_build_optimizer->metrics.total_builds;
    
    if (build_time_ns < g_build_optimizer->metrics.fastest_build_time_ns || 
        g_build_optimizer->metrics.fastest_build_time_ns == 0) {
        g_build_optimizer->metrics.fastest_build_time_ns = build_time_ns;
    }
    
    if (build_time_ns > g_build_optimizer->metrics.slowest_build_time_ns) {
        g_build_optimizer->metrics.slowest_build_time_ns = build_time_ns;
    }
    
    // Calculate cache hit rate
    uint64_t total_cache_ops = g_build_optimizer->metrics.cache_hits + g_build_optimizer->metrics.cache_misses;
    if (total_cache_ops > 0) {
        g_build_optimizer->metrics.cache_hit_rate_percent = 
            (g_build_optimizer->metrics.cache_hits * 100) / total_cache_ops;
    }
    
    if (g_build_optimizer->callbacks.on_build_complete) {
        g_build_optimizer->callbacks.on_build_complete(module_name, success, build_time_ns);
    }
    
    if (g_build_optimizer->debug_mode) {
        printf("Build Optimizer: Completed build for module '%s' %s (%.2f ms)\n",
               module_name, success ? "successfully" : "with errors", build_time_ns / 1000000.0);
    }
    
    return BUILD_SUCCESS;
}

// Get build metrics
int32_t build_optimizer_get_metrics(build_metrics_t* metrics) {
    if (!g_build_optimizer || !metrics) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    *metrics = g_build_optimizer->metrics;
    return BUILD_SUCCESS;
}

// Get cache statistics
int32_t build_optimizer_get_cache_stats(uint32_t* total_entries, uint32_t* valid_entries,
                                       uint64_t* cache_size_bytes, uint32_t* hit_rate_percent) {
    if (!g_build_optimizer) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    if (total_entries) {
        *total_entries = g_build_optimizer->cache_count;
    }
    
    if (valid_entries) {
        uint32_t valid = 0;
        for (uint32_t i = 0; i < g_build_optimizer->cache_count; i++) {
            if (g_build_optimizer->cache[i].is_valid) {
                valid++;
            }
        }
        *valid_entries = valid;
    }
    
    if (cache_size_bytes) {
        *cache_size_bytes = g_build_optimizer->cache_count * sizeof(build_cache_entry_t);
    }
    
    if (hit_rate_percent) {
        *hit_rate_percent = g_build_optimizer->metrics.cache_hit_rate_percent;
    }
    
    return BUILD_SUCCESS;
}

// Enable debug mode
int32_t build_optimizer_enable_debug_mode(bool enabled) {
    if (!g_build_optimizer) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    g_build_optimizer->debug_mode = enabled;
    printf("Build Optimizer: Debug mode %s\n", enabled ? "enabled" : "disabled");
    
    return BUILD_SUCCESS;
}

// Cleanup build optimizer
void build_optimizer_cleanup(void) {
    if (!g_build_optimizer) {
        return;
    }
    
    printf("Build Optimizer: Cleanup complete - %llu total builds, %.1f%% cache hit rate\n",
           g_build_optimizer->metrics.total_builds,
           g_build_optimizer->metrics.cache_hit_rate_percent / 100.0);
    
    free(g_build_optimizer);
    g_build_optimizer = NULL;
}