/*
 * SimCity ARM64 - Build Pipeline Performance Optimizer
 * Agent 2: File Watcher & Build Pipeline - Week 2 Day 8
 * 
 * Build pipeline performance optimization system
 * Features:
 * - Parallel compilation limits based on CPU cores and memory
 * - Incremental linking for faster builds
 * - Build queue management and prioritization
 * - Build time prediction and optimization algorithms
 */

#include "build_optimizer.h"
#include "file_watcher_advanced.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <sys/resource.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <pthread.h>

// Build pipeline performance constants
#define PIPELINE_MAX_CONCURRENT_BUILDS 64
#define PIPELINE_MAX_QUEUE_SIZE 512
#define PIPELINE_MEMORY_OVERHEAD_MB 512
#define PIPELINE_LINK_CACHE_SIZE 1024

// Build job states
typedef enum {
    BUILD_JOB_QUEUED = 0,
    BUILD_JOB_RUNNING,
    BUILD_JOB_WAITING_DEPS,
    BUILD_JOB_COMPLETED,
    BUILD_JOB_FAILED,
    BUILD_JOB_CANCELLED
} build_job_state_t;

// Build job priority
typedef enum {
    BUILD_JOB_PRIORITY_CRITICAL = 0,    // Platform, core modules
    BUILD_JOB_PRIORITY_HIGH,            // Graphics, simulation
    BUILD_JOB_PRIORITY_NORMAL,          // Standard modules
    BUILD_JOB_PRIORITY_LOW,             // Tests, utilities
    BUILD_JOB_PRIORITY_BACKGROUND       // Documentation, assets
} build_job_priority_t;

// Build job definition
typedef struct {
    uint32_t job_id;
    char module_name[64];
    char source_path[1024];
    char output_path[1024];
    build_target_type_t target_type;
    build_job_priority_t priority;
    build_job_state_t state;
    
    // Dependencies
    uint32_t dependency_count;
    uint32_t dependencies[32];          // Job IDs this job depends on
    uint32_t dependent_count;
    uint32_t dependents[32];            // Job IDs that depend on this job
    
    // Performance data
    uint64_t queue_time_ns;
    uint64_t start_time_ns;
    uint64_t end_time_ns;
    uint64_t predicted_duration_ns;
    uint64_t actual_duration_ns;
    uint64_t memory_usage_kb;
    
    // Build configuration
    char build_flags[512];
    uint32_t optimization_level;
    bool enable_debug_symbols;
    bool enable_incremental;
    
    pthread_t worker_thread;
    bool is_thread_active;
} build_job_t;

// Incremental linking cache entry
typedef struct {
    char object_path[1024];
    char symbol_signature[256];
    uint64_t modification_time;
    uint64_t file_size;
    uint32_t symbol_count;
    bool needs_relink;
} link_cache_entry_t;

// Build pipeline performance state
typedef struct {
    // Job management
    build_job_t jobs[PIPELINE_MAX_QUEUE_SIZE];
    uint32_t job_count;
    uint32_t next_job_id;
    uint32_t running_jobs;
    uint32_t completed_jobs;
    uint32_t failed_jobs;
    
    // Queue management
    uint32_t queue_head;
    uint32_t queue_tail;
    uint32_t priority_queues[5][PIPELINE_MAX_QUEUE_SIZE]; // One queue per priority
    uint32_t priority_queue_sizes[5];
    
    // Performance configuration
    uint32_t max_parallel_jobs;
    uint32_t available_memory_gb;
    uint32_t memory_per_job_mb;
    uint32_t cpu_cores;
    float cpu_load_threshold;
    
    // Incremental linking
    link_cache_entry_t link_cache[PIPELINE_LINK_CACHE_SIZE];
    uint32_t link_cache_count;
    bool incremental_linking_enabled;
    
    // Performance metrics
    uint64_t total_build_time_ns;
    uint64_t total_queue_time_ns;
    uint64_t average_job_duration_ns;
    uint32_t throughput_jobs_per_minute;
    float cpu_utilization_percent;
    float memory_utilization_percent;
    
    // Prediction models
    uint64_t build_time_history[1000];  // Circular buffer
    uint32_t history_index;
    uint32_t history_count;
    
    // Threading
    pthread_mutex_t queue_mutex;
    pthread_cond_t queue_cond;
    pthread_t scheduler_thread;
    bool scheduler_running;
    
    // Error handling
    char last_error[512];
} build_pipeline_state_t;

static build_pipeline_state_t* g_pipeline = NULL;

// Initialize build pipeline performance system
int32_t build_pipeline_performance_init(void) {
    if (g_pipeline) {
        return BUILD_ERROR_ALREADY_EXISTS;
    }
    
    g_pipeline = calloc(1, sizeof(build_pipeline_state_t));
    if (!g_pipeline) {
        return BUILD_ERROR_OUT_OF_MEMORY;
    }
    
    // Get system information
    size_t size = sizeof(uint32_t);
    sysctlbyname("hw.ncpu", &g_pipeline->cpu_cores, &size, NULL, 0);
    
    uint64_t memory_bytes;
    size = sizeof(uint64_t);
    sysctlbyname("hw.memsize", &memory_bytes, &size, NULL, 0);
    g_pipeline->available_memory_gb = (uint32_t)(memory_bytes / (1024 * 1024 * 1024));
    
    // Configure defaults based on system capabilities
    g_pipeline->max_parallel_jobs = g_pipeline->cpu_cores > 4 ? g_pipeline->cpu_cores - 2 : 2;
    g_pipeline->memory_per_job_mb = (g_pipeline->available_memory_gb * 1024) / (g_pipeline->max_parallel_jobs * 2);
    g_pipeline->cpu_load_threshold = 0.85f; // 85% CPU utilization limit
    g_pipeline->incremental_linking_enabled = true;
    
    // Cap memory per job
    if (g_pipeline->memory_per_job_mb > 4096) {
        g_pipeline->memory_per_job_mb = 4096; // 4GB max per job
    }
    if (g_pipeline->memory_per_job_mb < 512) {
        g_pipeline->memory_per_job_mb = 512;  // 512MB min per job
    }
    
    // Initialize threading
    pthread_mutex_init(&g_pipeline->queue_mutex, NULL);
    pthread_cond_init(&g_pipeline->queue_cond, NULL);
    
    printf("Build Pipeline: Initialized - %u cores, %u GB RAM, %u max jobs, %u MB per job\n",
           g_pipeline->cpu_cores, g_pipeline->available_memory_gb,
           g_pipeline->max_parallel_jobs, g_pipeline->memory_per_job_mb);
    
    return BUILD_SUCCESS;
}

// Get current system load
static float get_cpu_load(void) {
    host_cpu_load_info_data_t cpu_info;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, 
                       (host_info_t)&cpu_info, &count) == KERN_SUCCESS) {
        
        uint32_t total_ticks = cpu_info.cpu_ticks[CPU_STATE_USER] +
                              cpu_info.cpu_ticks[CPU_STATE_SYSTEM] +
                              cpu_info.cpu_ticks[CPU_STATE_IDLE] +
                              cpu_info.cpu_ticks[CPU_STATE_NICE];
        
        uint32_t used_ticks = total_ticks - cpu_info.cpu_ticks[CPU_STATE_IDLE];
        
        return (float)used_ticks / (float)total_ticks;
    }
    
    return 0.5f; // Default assumption
}

// Get available memory
static uint64_t get_available_memory_mb(void) {
    vm_statistics64_data_t vm_stat;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    
    if (host_statistics64(mach_host_self(), HOST_VM_INFO64,
                         (host_info64_t)&vm_stat, &count) == KERN_SUCCESS) {
        
        uint64_t page_size = vm_page_size;
        uint64_t free_memory = vm_stat.free_count * page_size;
        uint64_t inactive_memory = vm_stat.inactive_count * page_size;
        
        return (free_memory + inactive_memory) / (1024 * 1024);
    }
    
    return 1024; // Default 1GB assumption
}

// Calculate optimal parallel job count based on current system state
uint32_t calculate_optimal_parallel_jobs(void) {
    if (!g_pipeline) return 1;
    
    float cpu_load = get_cpu_load();
    uint64_t available_memory_mb = get_available_memory_mb();
    
    // CPU-based limit
    uint32_t cpu_jobs = g_pipeline->max_parallel_jobs;
    if (cpu_load > g_pipeline->cpu_load_threshold) {
        cpu_jobs = cpu_jobs > 2 ? cpu_jobs - 1 : 1;
    }
    
    // Memory-based limit
    uint32_t memory_jobs = available_memory_mb / g_pipeline->memory_per_job_mb;
    if (memory_jobs == 0) memory_jobs = 1;
    
    // Conservative approach: take minimum and ensure at least 1
    uint32_t optimal_jobs = cpu_jobs < memory_jobs ? cpu_jobs : memory_jobs;
    return optimal_jobs > 0 ? optimal_jobs : 1;
}

// Predict build time for a module
uint64_t predict_build_time(const char* module_name, build_target_type_t target_type) {
    if (!g_pipeline || !module_name) return 5000000000ULL; // 5 second default
    
    // Base estimates by target type (in nanoseconds)
    uint64_t base_time = 0;
    switch (target_type) {
        case BUILD_TARGET_ASSEMBLY:
            base_time = 2000000000ULL; // 2 seconds
            break;
        case BUILD_TARGET_OBJECT:
            base_time = 1000000000ULL; // 1 second
            break;
        case BUILD_TARGET_LIBRARY:
            base_time = 5000000000ULL; // 5 seconds
            break;
        case BUILD_TARGET_EXECUTABLE:
            base_time = 10000000000ULL; // 10 seconds
            break;
        case BUILD_TARGET_SHADER:
            base_time = 3000000000ULL; // 3 seconds
            break;
        default:
            base_time = 5000000000ULL; // 5 seconds
    }
    
    // Adjust based on historical data if available
    if (g_pipeline->history_count > 0) {
        uint64_t avg_historical = 0;
        uint32_t count = g_pipeline->history_count < 1000 ? g_pipeline->history_count : 1000;
        
        for (uint32_t i = 0; i < count; i++) {
            avg_historical += g_pipeline->build_time_history[i];
        }
        avg_historical /= count;
        
        // Blend historical average with base estimate (70% historical, 30% base)
        base_time = (avg_historical * 7 + base_time * 3) / 10;
    }
    
    return base_time;
}

// Add build job to queue
int32_t build_pipeline_add_job(const char* module_name, const char* source_path,
                              const char* output_path, build_target_type_t target_type,
                              build_job_priority_t priority) {
    if (!g_pipeline || !module_name || !source_path || !output_path) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    pthread_mutex_lock(&g_pipeline->queue_mutex);
    
    if (g_pipeline->job_count >= PIPELINE_MAX_QUEUE_SIZE) {
        pthread_mutex_unlock(&g_pipeline->queue_mutex);
        return BUILD_ERROR_OUT_OF_MEMORY;
    }
    
    // Create new job
    build_job_t* job = &g_pipeline->jobs[g_pipeline->job_count];
    memset(job, 0, sizeof(build_job_t));
    
    job->job_id = g_pipeline->next_job_id++;
    strncpy(job->module_name, module_name, sizeof(job->module_name) - 1);
    strncpy(job->source_path, source_path, sizeof(job->source_path) - 1);
    strncpy(job->output_path, output_path, sizeof(job->output_path) - 1);
    job->target_type = target_type;
    job->priority = priority;
    job->state = BUILD_JOB_QUEUED;
    job->queue_time_ns = mach_absolute_time();
    job->predicted_duration_ns = predict_build_time(module_name, target_type);
    
    // Add to priority queue
    if (g_pipeline->priority_queue_sizes[priority] < PIPELINE_MAX_QUEUE_SIZE) {
        g_pipeline->priority_queues[priority][g_pipeline->priority_queue_sizes[priority]++] = g_pipeline->job_count;
    }
    
    g_pipeline->job_count++;
    
    pthread_cond_signal(&g_pipeline->queue_cond);
    pthread_mutex_unlock(&g_pipeline->queue_mutex);
    
    printf("Build Pipeline: Added job %u for %s (priority: %d, predicted: %.2f ms)\n",
           job->job_id, module_name, priority, job->predicted_duration_ns / 1000000.0);
    
    return job->job_id;
}

// Check if incremental linking is needed
bool needs_incremental_link(const char* output_path) {
    if (!g_pipeline || !g_pipeline->incremental_linking_enabled) {
        return false;
    }
    
    // Check if output exists
    struct stat output_stat;
    if (stat(output_path, &output_stat) != 0) {
        return false; // Output doesn't exist, full link needed
    }
    
    // Check link cache for changed dependencies
    for (uint32_t i = 0; i < g_pipeline->link_cache_count; i++) {
        link_cache_entry_t* entry = &g_pipeline->link_cache[i];
        
        struct stat obj_stat;
        if (stat(entry->object_path, &obj_stat) == 0) {
            if (obj_stat.st_mtime > entry->modification_time ||
                obj_stat.st_size != entry->file_size) {
                entry->needs_relink = true;
                return true;
            }
        }
    }
    
    return false;
}

// Update incremental linking cache
void update_link_cache(const char* object_path, const char* output_path) {
    if (!g_pipeline || !object_path) return;
    
    // Find existing entry or create new one
    link_cache_entry_t* entry = NULL;
    for (uint32_t i = 0; i < g_pipeline->link_cache_count; i++) {
        if (strcmp(g_pipeline->link_cache[i].object_path, object_path) == 0) {
            entry = &g_pipeline->link_cache[i];
            break;
        }
    }
    
    if (!entry && g_pipeline->link_cache_count < PIPELINE_LINK_CACHE_SIZE) {
        entry = &g_pipeline->link_cache[g_pipeline->link_cache_count++];
        strncpy(entry->object_path, object_path, sizeof(entry->object_path) - 1);
    }
    
    if (entry) {
        struct stat obj_stat;
        if (stat(object_path, &obj_stat) == 0) {
            entry->modification_time = obj_stat.st_mtime;
            entry->file_size = obj_stat.st_size;
            entry->needs_relink = false;
        }
    }
}

// Build job scheduler thread
void* build_scheduler_thread(void* arg) {
    (void)arg;
    
    while (g_pipeline && g_pipeline->scheduler_running) {
        pthread_mutex_lock(&g_pipeline->queue_mutex);
        
        // Wait for jobs or shutdown signal
        while (g_pipeline->scheduler_running && 
               g_pipeline->running_jobs >= calculate_optimal_parallel_jobs()) {
            pthread_cond_wait(&g_pipeline->queue_cond, &g_pipeline->queue_mutex);
        }
        
        if (!g_pipeline->scheduler_running) {
            pthread_mutex_unlock(&g_pipeline->queue_mutex);
            break;
        }
        
        // Find highest priority job to run
        build_job_t* next_job = NULL;
        for (int priority = 0; priority < 5; priority++) {
            if (g_pipeline->priority_queue_sizes[priority] > 0) {
                uint32_t job_index = g_pipeline->priority_queues[priority][0];
                next_job = &g_pipeline->jobs[job_index];
                
                // Remove from priority queue
                memmove(&g_pipeline->priority_queues[priority][0],
                       &g_pipeline->priority_queues[priority][1],
                       (--g_pipeline->priority_queue_sizes[priority]) * sizeof(uint32_t));
                break;
            }
        }
        
        if (next_job && next_job->state == BUILD_JOB_QUEUED) {
            next_job->state = BUILD_JOB_RUNNING;
            next_job->start_time_ns = mach_absolute_time();
            g_pipeline->running_jobs++;
            
            printf("Build Pipeline: Starting job %u (%s) - %u jobs running\n",
                   next_job->job_id, next_job->module_name, g_pipeline->running_jobs);
        }
        
        pthread_mutex_unlock(&g_pipeline->queue_mutex);
        
        // Small delay to prevent busy waiting
        usleep(10000); // 10ms
    }
    
    return NULL;
}

// Start build pipeline scheduler
int32_t build_pipeline_start_scheduler(void) {
    if (!g_pipeline) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    if (g_pipeline->scheduler_running) {
        return BUILD_ERROR_ALREADY_EXISTS;
    }
    
    g_pipeline->scheduler_running = true;
    
    if (pthread_create(&g_pipeline->scheduler_thread, NULL, build_scheduler_thread, NULL) != 0) {
        g_pipeline->scheduler_running = false;
        return BUILD_ERROR_SYSTEM_ERROR;
    }
    
    printf("Build Pipeline: Scheduler started\n");
    return BUILD_SUCCESS;
}

// Complete a build job
int32_t build_pipeline_complete_job(uint32_t job_id, bool success) {
    if (!g_pipeline) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    pthread_mutex_lock(&g_pipeline->queue_mutex);
    
    // Find job
    build_job_t* job = NULL;
    for (uint32_t i = 0; i < g_pipeline->job_count; i++) {
        if (g_pipeline->jobs[i].job_id == job_id) {
            job = &g_pipeline->jobs[i];
            break;
        }
    }
    
    if (!job || job->state != BUILD_JOB_RUNNING) {
        pthread_mutex_unlock(&g_pipeline->queue_mutex);
        return BUILD_ERROR_NOT_FOUND;
    }
    
    job->end_time_ns = mach_absolute_time();
    job->actual_duration_ns = job->end_time_ns - job->start_time_ns;
    job->state = success ? BUILD_JOB_COMPLETED : BUILD_JOB_FAILED;
    
    g_pipeline->running_jobs--;
    if (success) {
        g_pipeline->completed_jobs++;
    } else {
        g_pipeline->failed_jobs++;
    }
    
    // Update performance metrics
    g_pipeline->total_build_time_ns += job->actual_duration_ns;
    g_pipeline->total_queue_time_ns += job->start_time_ns - job->queue_time_ns;
    
    // Update build time history
    g_pipeline->build_time_history[g_pipeline->history_index] = job->actual_duration_ns;
    g_pipeline->history_index = (g_pipeline->history_index + 1) % 1000;
    if (g_pipeline->history_count < 1000) {
        g_pipeline->history_count++;
    }
    
    // Update incremental linking cache if successful
    if (success && job->target_type == BUILD_TARGET_OBJECT) {
        update_link_cache(job->source_path, job->output_path);
    }
    
    pthread_cond_signal(&g_pipeline->queue_cond);
    pthread_mutex_unlock(&g_pipeline->queue_mutex);
    
    printf("Build Pipeline: Completed job %u (%s) %s - %.2f ms (predicted: %.2f ms)\n",
           job_id, job->module_name, success ? "successfully" : "with errors",
           job->actual_duration_ns / 1000000.0, job->predicted_duration_ns / 1000000.0);
    
    return BUILD_SUCCESS;
}

// Get build pipeline performance metrics
int32_t build_pipeline_get_performance_metrics(uint32_t* queued_jobs, uint32_t* running_jobs,
                                              uint32_t* completed_jobs, uint32_t* failed_jobs,
                                              uint64_t* avg_build_time_ns, float* cpu_utilization,
                                              uint32_t* jobs_per_minute) {
    if (!g_pipeline) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    if (queued_jobs) {
        uint32_t total_queued = 0;
        for (int i = 0; i < 5; i++) {
            total_queued += g_pipeline->priority_queue_sizes[i];
        }
        *queued_jobs = total_queued;
    }
    
    if (running_jobs) *running_jobs = g_pipeline->running_jobs;
    if (completed_jobs) *completed_jobs = g_pipeline->completed_jobs;
    if (failed_jobs) *failed_jobs = g_pipeline->failed_jobs;
    
    if (avg_build_time_ns) {
        *avg_build_time_ns = g_pipeline->completed_jobs > 0 ? 
            g_pipeline->total_build_time_ns / g_pipeline->completed_jobs : 0;
    }
    
    if (cpu_utilization) {
        *cpu_utilization = get_cpu_load() * 100.0f;
    }
    
    if (jobs_per_minute) {
        // Simple throughput calculation based on recent history
        *jobs_per_minute = g_pipeline->completed_jobs > 0 ? 
            (g_pipeline->completed_jobs * 60) / (g_pipeline->total_build_time_ns / 1000000000ULL) : 0;
    }
    
    return BUILD_SUCCESS;
}

// Optimize build flags for a module
int32_t build_pipeline_optimize_flags(const char* module_name, build_target_type_t target_type,
                                     char* flags_out, size_t flags_size) {
    if (!module_name || !flags_out) {
        return BUILD_ERROR_NULL_POINTER;
    }
    
    // Base optimization flags for ARM64 assembly
    const char* base_flags = "-arch arm64 -O2";
    const char* debug_flags = "-g -DDEBUG";
    const char* release_flags = "-DNDEBUG -fomit-frame-pointer";
    
    // Module-specific optimizations
    const char* module_specific = "";
    if (strstr(module_name, "graphics") != NULL) {
        module_specific = "-DVECTOR_OPTIMIZED -mfpu=neon";
    } else if (strstr(module_name, "simulation") != NULL) {
        module_specific = "-DSIMD_OPTIMIZED -funroll-loops";
    } else if (strstr(module_name, "memory") != NULL) {
        module_specific = "-DMEMORY_OPTIMIZED -falign-functions=16";
    }
    
    // System load adaptive optimization
    float cpu_load = get_cpu_load();
    const char* load_flags = cpu_load > 0.8f ? "-j1" : "-j4"; // Reduce parallelism under high load
    
    snprintf(flags_out, flags_size, "%s %s %s %s",
             base_flags, release_flags, module_specific, load_flags);
    
    return BUILD_SUCCESS;
}

// Cleanup build pipeline
void build_pipeline_cleanup(void) {
    if (!g_pipeline) return;
    
    // Stop scheduler
    if (g_pipeline->scheduler_running) {
        g_pipeline->scheduler_running = false;
        pthread_cond_broadcast(&g_pipeline->queue_cond);
        pthread_join(g_pipeline->scheduler_thread, NULL);
    }
    
    // Cleanup threading
    pthread_mutex_destroy(&g_pipeline->queue_mutex);
    pthread_cond_destroy(&g_pipeline->queue_cond);
    
    printf("Build Pipeline: Cleanup complete - %u jobs completed, %u failed\n",
           g_pipeline->completed_jobs, g_pipeline->failed_jobs);
    
    free(g_pipeline);
    g_pipeline = NULL;
}