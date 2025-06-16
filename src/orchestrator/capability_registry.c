// SimCity ARM64 DevActor Capability Registry
// Plugin-style worker capability registration and discovery system
// Supports dynamic capability registration, versioning, and hot-reloading

#include "capability_registry.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <dirent.h>
#include <sys/stat.h>
#include <pthread.h>
#include <stdatomic.h>
#include <uuid/uuid.h>
#include <time.h>

// Internal structures
typedef struct CapabilityNode {
    Capability capability;
    struct CapabilityNode* next;
    void* plugin_handle;  // dlopen handle for dynamic loading
    char* plugin_path;    // Path to plugin file
    time_t last_modified; // For hot-reloading detection
} CapabilityNode;

typedef struct WorkerNode {
    WorkerInfo worker;
    CapabilityNode* capabilities;
    struct WorkerNode* next;
    uint64_t last_heartbeat;
    uint32_t capability_count;
    WorkerState state;
} WorkerNode;

typedef struct {
    WorkerNode* workers;
    CapabilityNode* global_capabilities;
    pthread_rwlock_t registry_lock;
    atomic_uint total_workers;
    atomic_uint total_capabilities;
    char plugin_directory[256];
    pthread_t hot_reload_thread;
    atomic_bool hot_reload_enabled;
    uint32_t next_worker_id;
} CapabilityRegistry;

static CapabilityRegistry g_registry = {0};

// Forward declarations
static int load_plugin_capabilities(const char* plugin_path);
static int unload_plugin_capabilities(const char* plugin_path);
static void* hot_reload_monitor_thread(void* arg);
static int validate_capability(const Capability* cap);
static WorkerNode* find_worker_by_id(uint32_t worker_id);
static CapabilityNode* find_capability_by_name(const char* name);
static int capability_version_compare(const char* v1, const char* v2);
static void generate_capability_uuid(char* uuid_str);

//==============================================================================
// REGISTRY INITIALIZATION AND CLEANUP
//==============================================================================

int capability_registry_init(const char* plugin_dir) {
    if (g_registry.workers != NULL) {
        return 0; // Already initialized
    }
    
    printf("Initializing DevActor capability registry...\n");
    
    // Initialize locks
    if (pthread_rwlock_init(&g_registry.registry_lock, NULL) != 0) {
        printf("Failed to initialize registry lock\n");
        return -1;
    }
    
    // Set plugin directory
    if (plugin_dir) {
        strncpy(g_registry.plugin_directory, plugin_dir, sizeof(g_registry.plugin_directory) - 1);
        g_registry.plugin_directory[sizeof(g_registry.plugin_directory) - 1] = '\0';
    } else {
        strcpy(g_registry.plugin_directory, ".dev_actors");
    }
    
    // Initialize atomic counters
    atomic_store(&g_registry.total_workers, 0);
    atomic_store(&g_registry.total_capabilities, 0);
    g_registry.next_worker_id = 1;
    
    // Load built-in capabilities for core DevActors
    capability_registry_load_builtin_capabilities();
    
    // Start hot-reload monitoring if plugin directory exists
    struct stat st;
    if (stat(g_registry.plugin_directory, &st) == 0 && S_ISDIR(st.st_mode)) {
        g_registry.hot_reload_enabled = true;
        if (pthread_create(&g_registry.hot_reload_thread, NULL, hot_reload_monitor_thread, NULL) != 0) {
            printf("Warning: Failed to start hot-reload monitor\n");
            g_registry.hot_reload_enabled = false;
        }
    }
    
    printf("Capability registry initialized with plugin directory: %s\n", g_registry.plugin_directory);
    return 0;
}

void capability_registry_shutdown(void) {
    printf("Shutting down capability registry...\n");
    
    // Stop hot-reload monitoring
    if (g_registry.hot_reload_enabled) {
        g_registry.hot_reload_enabled = false;
        pthread_join(g_registry.hot_reload_thread, NULL);
    }
    
    pthread_rwlock_wrlock(&g_registry.registry_lock);
    
    // Cleanup workers and their capabilities
    WorkerNode* worker = g_registry.workers;
    while (worker) {
        WorkerNode* next_worker = worker->next;
        
        // Cleanup worker capabilities
        CapabilityNode* cap = worker->capabilities;
        while (cap) {
            CapabilityNode* next_cap = cap->next;
            
            // Unload plugin if needed
            if (cap->plugin_handle) {
                dlclose(cap->plugin_handle);
            }
            
            if (cap->plugin_path) {
                free(cap->plugin_path);
            }
            
            free(cap);
            cap = next_cap;
        }
        
        free(worker);
        worker = next_worker;
    }
    
    // Cleanup global capabilities
    CapabilityNode* cap = g_registry.global_capabilities;
    while (cap) {
        CapabilityNode* next_cap = cap->next;
        
        if (cap->plugin_handle) {
            dlclose(cap->plugin_handle);
        }
        
        if (cap->plugin_path) {
            free(cap->plugin_path);
        }
        
        free(cap);
        cap = next_cap;
    }
    
    pthread_rwlock_unlock(&g_registry.registry_lock);
    pthread_rwlock_destroy(&g_registry.registry_lock);
    
    memset(&g_registry, 0, sizeof(CapabilityRegistry));
    printf("Capability registry shutdown complete\n");
}

//==============================================================================
// WORKER REGISTRATION
//==============================================================================

int capability_registry_register_worker(const WorkerInfo* worker_info, uint32_t* worker_id) {
    if (!worker_info || !worker_id) {
        return CAPABILITY_ERROR_INVALID_PARAMS;
    }
    
    pthread_rwlock_wrlock(&g_registry.registry_lock);
    
    // Check for duplicate worker names
    WorkerNode* existing = g_registry.workers;
    while (existing) {
        if (strcmp(existing->worker.name, worker_info->name) == 0) {
            pthread_rwlock_unlock(&g_registry.registry_lock);
            return CAPABILITY_ERROR_DUPLICATE_NAME;
        }
        existing = existing->next;
    }
    
    // Create new worker node
    WorkerNode* new_worker = calloc(1, sizeof(WorkerNode));
    if (!new_worker) {
        pthread_rwlock_unlock(&g_registry.registry_lock);
        return CAPABILITY_ERROR_MEMORY;
    }
    
    // Copy worker info
    new_worker->worker = *worker_info;
    new_worker->worker.id = g_registry.next_worker_id++;
    new_worker->state = WORKER_STATE_IDLE;
    new_worker->last_heartbeat = time(NULL);
    new_worker->capability_count = 0;
    
    // Add to linked list
    new_worker->next = g_registry.workers;
    g_registry.workers = new_worker;
    
    *worker_id = new_worker->worker.id;
    atomic_fetch_add(&g_registry.total_workers, 1);
    
    pthread_rwlock_unlock(&g_registry.registry_lock);
    
    printf("Registered DevActor worker: %s (ID: %u)\n", worker_info->name, *worker_id);
    return CAPABILITY_SUCCESS;
}

int capability_registry_unregister_worker(uint32_t worker_id) {
    pthread_rwlock_wrlock(&g_registry.registry_lock);
    
    WorkerNode** current = &g_registry.workers;
    while (*current) {
        if ((*current)->worker.id == worker_id) {
            WorkerNode* to_remove = *current;
            *current = (*current)->next;
            
            // Cleanup capabilities
            CapabilityNode* cap = to_remove->capabilities;
            while (cap) {
                CapabilityNode* next_cap = cap->next;
                
                if (cap->plugin_handle) {
                    dlclose(cap->plugin_handle);
                }
                if (cap->plugin_path) {
                    free(cap->plugin_path);
                }
                
                atomic_fetch_sub(&g_registry.total_capabilities, 1);
                free(cap);
                cap = next_cap;
            }
            
            free(to_remove);
            atomic_fetch_sub(&g_registry.total_workers, 1);
            
            pthread_rwlock_unlock(&g_registry.registry_lock);
            printf("Unregistered DevActor worker ID: %u\n", worker_id);
            return CAPABILITY_SUCCESS;
        }
        current = &(*current)->next;
    }
    
    pthread_rwlock_unlock(&g_registry.registry_lock);
    return CAPABILITY_ERROR_NOT_FOUND;
}

//==============================================================================
// CAPABILITY REGISTRATION
//==============================================================================

int capability_registry_register_capability(uint32_t worker_id, const Capability* capability) {
    if (!capability) {
        return CAPABILITY_ERROR_INVALID_PARAMS;
    }
    
    // Validate capability
    if (validate_capability(capability) != 0) {
        return CAPABILITY_ERROR_INVALID_CAPABILITY;
    }
    
    pthread_rwlock_wrlock(&g_registry.registry_lock);
    
    // Find worker
    WorkerNode* worker = find_worker_by_id(worker_id);
    if (!worker) {
        pthread_rwlock_unlock(&g_registry.registry_lock);
        return CAPABILITY_ERROR_WORKER_NOT_FOUND;
    }
    
    // Check for duplicate capability names within worker
    CapabilityNode* existing = worker->capabilities;
    while (existing) {
        if (strcmp(existing->capability.name, capability->name) == 0) {
            pthread_rwlock_unlock(&g_registry.registry_lock);
            return CAPABILITY_ERROR_DUPLICATE_NAME;
        }
        existing = existing->next;
    }
    
    // Create new capability node
    CapabilityNode* new_cap = calloc(1, sizeof(CapabilityNode));
    if (!new_cap) {
        pthread_rwlock_unlock(&g_registry.registry_lock);
        return CAPABILITY_ERROR_MEMORY;
    }
    
    new_cap->capability = *capability;
    
    // Generate UUID if not provided
    if (strlen(new_cap->capability.uuid) == 0) {
        generate_capability_uuid(new_cap->capability.uuid);
    }
    
    // Add to worker's capability list
    new_cap->next = worker->capabilities;
    worker->capabilities = new_cap;
    worker->capability_count++;
    
    atomic_fetch_add(&g_registry.total_capabilities, 1);
    
    pthread_rwlock_unlock(&g_registry.registry_lock);
    
    printf("Registered capability '%s' for worker %u\n", capability->name, worker_id);
    return CAPABILITY_SUCCESS;
}

int capability_registry_unregister_capability(uint32_t worker_id, const char* capability_name) {
    if (!capability_name) {
        return CAPABILITY_ERROR_INVALID_PARAMS;
    }
    
    pthread_rwlock_wrlock(&g_registry.registry_lock);
    
    WorkerNode* worker = find_worker_by_id(worker_id);
    if (!worker) {
        pthread_rwlock_unlock(&g_registry.registry_lock);
        return CAPABILITY_ERROR_WORKER_NOT_FOUND;
    }
    
    CapabilityNode** current = &worker->capabilities;
    while (*current) {
        if (strcmp((*current)->capability.name, capability_name) == 0) {
            CapabilityNode* to_remove = *current;
            *current = (*current)->next;
            
            if (to_remove->plugin_handle) {
                dlclose(to_remove->plugin_handle);
            }
            if (to_remove->plugin_path) {
                free(to_remove->plugin_path);
            }
            
            free(to_remove);
            worker->capability_count--;
            atomic_fetch_sub(&g_registry.total_capabilities, 1);
            
            pthread_rwlock_unlock(&g_registry.registry_lock);
            printf("Unregistered capability '%s' from worker %u\n", capability_name, worker_id);
            return CAPABILITY_SUCCESS;
        }
        current = &(*current)->next;
    }
    
    pthread_rwlock_unlock(&g_registry.registry_lock);
    return CAPABILITY_ERROR_NOT_FOUND;
}

//==============================================================================
// CAPABILITY DISCOVERY AND MATCHING
//==============================================================================

int capability_registry_find_workers_with_capability(const char* capability_name, 
                                                    uint32_t* worker_ids, 
                                                    uint32_t max_workers, 
                                                    uint32_t* found_count) {
    if (!capability_name || !worker_ids || !found_count) {
        return CAPABILITY_ERROR_INVALID_PARAMS;
    }
    
    pthread_rwlock_rdlock(&g_registry.registry_lock);
    
    *found_count = 0;
    WorkerNode* worker = g_registry.workers;
    
    while (worker && *found_count < max_workers) {
        CapabilityNode* cap = worker->capabilities;
        while (cap) {
            if (strcmp(cap->capability.name, capability_name) == 0) {
                worker_ids[*found_count] = worker->worker.id;
                (*found_count)++;
                break;
            }
            cap = cap->next;
        }
        worker = worker->next;
    }
    
    pthread_rwlock_unlock(&g_registry.registry_lock);
    return CAPABILITY_SUCCESS;
}

int capability_registry_get_worker_capabilities(uint32_t worker_id, 
                                               Capability* capabilities, 
                                               uint32_t max_capabilities, 
                                               uint32_t* capability_count) {
    if (!capabilities || !capability_count) {
        return CAPABILITY_ERROR_INVALID_PARAMS;
    }
    
    pthread_rwlock_rdlock(&g_registry.registry_lock);
    
    WorkerNode* worker = find_worker_by_id(worker_id);
    if (!worker) {
        pthread_rwlock_unlock(&g_registry.registry_lock);
        return CAPABILITY_ERROR_WORKER_NOT_FOUND;
    }
    
    *capability_count = 0;
    CapabilityNode* cap = worker->capabilities;
    
    while (cap && *capability_count < max_capabilities) {
        capabilities[*capability_count] = cap->capability;
        (*capability_count)++;
        cap = cap->next;
    }
    
    pthread_rwlock_unlock(&g_registry.registry_lock);
    return CAPABILITY_SUCCESS;
}

int capability_registry_find_best_worker_for_task(const TaskRequirements* requirements, 
                                                 uint32_t* worker_id, 
                                                 float* compatibility_score) {
    if (!requirements || !worker_id) {
        return CAPABILITY_ERROR_INVALID_PARAMS;
    }
    
    pthread_rwlock_rdlock(&g_registry.registry_lock);
    
    float best_score = 0.0f;
    uint32_t best_worker = 0;
    bool found = false;
    
    WorkerNode* worker = g_registry.workers;
    while (worker) {
        if (worker->state != WORKER_STATE_BUSY) {
            float score = calculate_worker_compatibility(worker, requirements);
            if (score > best_score) {
                best_score = score;
                best_worker = worker->worker.id;
                found = true;
            }
        }
        worker = worker->next;
    }
    
    pthread_rwlock_unlock(&g_registry.registry_lock);
    
    if (found) {
        *worker_id = best_worker;
        if (compatibility_score) {
            *compatibility_score = best_score;
        }
        return CAPABILITY_SUCCESS;
    }
    
    return CAPABILITY_ERROR_NO_SUITABLE_WORKER;
}

//==============================================================================
// BUILT-IN CAPABILITIES
//==============================================================================

int capability_registry_load_builtin_capabilities(void) {
    printf("Loading built-in DevActor capabilities...\n");
    
    // DevActor 0: Orchestrator capabilities
    Capability orchestrator_caps[] = {
        {
            .name = "task_orchestration",
            .version = "1.0.0",
            .description = "Coordinate and delegate tasks across DevActors",
            .category = CAPABILITY_CATEGORY_COORDINATION,
            .priority = CAPABILITY_PRIORITY_CRITICAL,
            .resource_requirements = {.cpu_usage = 0.1f, .memory_mb = 64, .network_bandwidth_mbps = 10},
            .dependencies_count = 0
        },
        {
            .name = "health_monitoring",
            .version = "1.0.0",
            .description = "Monitor DevActor health and implement circuit breakers",
            .category = CAPABILITY_CATEGORY_MONITORING,
            .priority = CAPABILITY_PRIORITY_HIGH,
            .resource_requirements = {.cpu_usage = 0.05f, .memory_mb = 32, .network_bandwidth_mbps = 5},
            .dependencies_count = 0
        }
    };
    
    // DevActor 1: Core Engine capabilities
    Capability core_engine_caps[] = {
        {
            .name = "memory_management",
            .version = "1.0.0",
            .description = "Cache-aligned memory allocation for Apple Silicon",
            .category = CAPABILITY_CATEGORY_CORE,
            .priority = CAPABILITY_PRIORITY_CRITICAL,
            .resource_requirements = {.cpu_usage = 0.2f, .memory_mb = 128, .network_bandwidth_mbps = 0},
            .dependencies_count = 0
        },
        {
            .name = "thread_pool_management",
            .version = "1.0.0",
            .description = "High-performance thread pool with work stealing",
            .category = CAPABILITY_CATEGORY_CORE,
            .priority = CAPABILITY_PRIORITY_HIGH,
            .resource_requirements = {.cpu_usage = 0.3f, .memory_mb = 64, .network_bandwidth_mbps = 0},
            .dependencies_count = 1,
            .dependencies = {"memory_management"}
        }
    };
    
    // DevActor 2: Simulation capabilities
    Capability simulation_caps[] = {
        {
            .name = "entity_component_system",
            .version = "1.0.0",
            .description = "Double-buffered ECS for 1M+ entities",
            .category = CAPABILITY_CATEGORY_SIMULATION,
            .priority = CAPABILITY_PRIORITY_CRITICAL,
            .resource_requirements = {.cpu_usage = 0.4f, .memory_mb = 256, .network_bandwidth_mbps = 0},
            .dependencies_count = 1,
            .dependencies = {"memory_management"}
        },
        {
            .name = "physics_simulation",
            .version = "1.0.0",
            .description = "Optimized physics for city simulation",
            .category = CAPABILITY_CATEGORY_SIMULATION,
            .priority = CAPABILITY_PRIORITY_HIGH,
            .resource_requirements = {.cpu_usage = 0.3f, .memory_mb = 128, .network_bandwidth_mbps = 0},
            .dependencies_count = 1,
            .dependencies = {"entity_component_system"}
        }
    };
    
    // DevActor 3: Graphics capabilities
    Capability graphics_caps[] = {
        {
            .name = "metal_rendering",
            .version = "1.0.0",
            .description = "Apple Silicon optimized Metal rendering",
            .category = CAPABILITY_CATEGORY_RENDERING,
            .priority = CAPABILITY_PRIORITY_CRITICAL,
            .resource_requirements = {.cpu_usage = 0.2f, .memory_mb = 512, .network_bandwidth_mbps = 0},
            .dependencies_count = 0
        },
        {
            .name = "shader_compilation",
            .version = "1.0.0",
            .description = "Pre-compiled Metal shaders with argument buffers",
            .category = CAPABILITY_CATEGORY_RENDERING,
            .priority = CAPABILITY_PRIORITY_HIGH,
            .resource_requirements = {.cpu_usage = 0.1f, .memory_mb = 64, .network_bandwidth_mbps = 0},
            .dependencies_count = 1,
            .dependencies = {"metal_rendering"}
        }
    };
    
    // DevActor 4: AI capabilities
    Capability ai_caps[] = {
        {
            .name = "navmesh_generation",
            .version = "1.0.0",
            .description = "Real-time navmesh generation and pathfinding",
            .category = CAPABILITY_CATEGORY_AI,
            .priority = CAPABILITY_PRIORITY_HIGH,
            .resource_requirements = {.cpu_usage = 0.3f, .memory_mb = 128, .network_bandwidth_mbps = 0},
            .dependencies_count = 1,
            .dependencies = {"entity_component_system"}
        },
        {
            .name = "behavior_trees",
            .version = "1.0.0",
            .description = "Blackboard-based behavior trees for AI agents",
            .category = CAPABILITY_CATEGORY_AI,
            .priority = CAPABILITY_PRIORITY_HIGH,
            .resource_requirements = {.cpu_usage = 0.2f, .memory_mb = 96, .network_bandwidth_mbps = 0},
            .dependencies_count = 1,
            .dependencies = {"navmesh_generation"}
        }
    };
    
    // Register built-in workers and capabilities
    struct {
        const char* name;
        Capability* caps;
        uint32_t cap_count;
    } builtin_workers[] = {
        {"DevActor_0_Orchestrator", orchestrator_caps, 2},
        {"DevActor_1_CoreEngine", core_engine_caps, 2},
        {"DevActor_2_Simulation", simulation_caps, 2},
        {"DevActor_3_Graphics", graphics_caps, 2},
        {"DevActor_4_AI", ai_caps, 2}
    };
    
    for (int i = 0; i < 5; i++) {
        WorkerInfo worker_info = {
            .name = "",
            .version = "1.0.0",
            .description = "Built-in DevActor worker",
            .max_concurrent_tasks = 4,
            .heartbeat_interval_ms = 1000
        };
        strncpy(worker_info.name, builtin_workers[i].name, sizeof(worker_info.name) - 1);
        
        uint32_t worker_id;
        if (capability_registry_register_worker(&worker_info, &worker_id) == CAPABILITY_SUCCESS) {
            for (uint32_t j = 0; j < builtin_workers[i].cap_count; j++) {
                capability_registry_register_capability(worker_id, &builtin_workers[i].caps[j]);
            }
        }
    }
    
    printf("Loaded built-in capabilities for 5 core DevActors\n");
    return CAPABILITY_SUCCESS;
}

//==============================================================================
// WORKER COMPATIBILITY SCORING
//==============================================================================

float calculate_worker_compatibility(const WorkerNode* worker, const TaskRequirements* requirements) {
    if (!worker || !requirements) {
        return 0.0f;
    }
    
    float score = 0.0f;
    float max_score = 0.0f;
    
    // Check capability matches
    for (uint32_t i = 0; i < requirements->required_capabilities_count; i++) {
        max_score += 1.0f;
        
        CapabilityNode* cap = worker->capabilities;
        while (cap) {
            if (strcmp(cap->capability.name, requirements->required_capabilities[i]) == 0) {
                score += 1.0f;
                break;
            }
            cap = cap->next;
        }
    }
    
    // Check resource availability
    max_score += 3.0f; // CPU, memory, network
    
    // Simple resource scoring (would be more sophisticated in practice)
    if (requirements->min_cpu_cores <= worker->worker.max_concurrent_tasks) {
        score += 1.0f;
    }
    
    if (requirements->min_memory_mb <= 1024) { // Assume workers have 1GB available
        score += 1.0f;
    }
    
    if (requirements->min_network_bandwidth_mbps <= 100) { // Assume 100Mbps available
        score += 1.0f;
    }
    
    // Normalize score
    return max_score > 0.0f ? (score / max_score) : 0.0f;
}

//==============================================================================
// UTILITY FUNCTIONS
//==============================================================================

static int validate_capability(const Capability* cap) {
    if (!cap->name[0] || !cap->version[0]) {
        return -1;
    }
    
    if (cap->category >= CAPABILITY_CATEGORY_COUNT) {
        return -1;
    }
    
    if (cap->priority >= CAPABILITY_PRIORITY_COUNT) {
        return -1;
    }
    
    if (cap->dependencies_count > MAX_CAPABILITY_DEPENDENCIES) {
        return -1;
    }
    
    return 0;
}

static WorkerNode* find_worker_by_id(uint32_t worker_id) {
    WorkerNode* worker = g_registry.workers;
    while (worker) {
        if (worker->worker.id == worker_id) {
            return worker;
        }
        worker = worker->next;
    }
    return NULL;
}

static void generate_capability_uuid(char* uuid_str) {
    uuid_t uuid;
    uuid_generate(uuid);
    uuid_unparse(uuid, uuid_str);
}

static int capability_version_compare(const char* v1, const char* v2) {
    // Simple version comparison (major.minor.patch)
    int major1, minor1, patch1;
    int major2, minor2, patch2;
    
    sscanf(v1, "%d.%d.%d", &major1, &minor1, &patch1);
    sscanf(v2, "%d.%d.%d", &major2, &minor2, &patch2);
    
    if (major1 != major2) return major1 - major2;
    if (minor1 != minor2) return minor1 - minor2;
    return patch1 - patch2;
}

//==============================================================================
// HOT-RELOAD MONITORING
//==============================================================================

static void* hot_reload_monitor_thread(void* arg) {
    printf("Hot-reload monitor thread started for %s\n", g_registry.plugin_directory);
    
    while (g_registry.hot_reload_enabled) {
        DIR* dir = opendir(g_registry.plugin_directory);
        if (dir) {
            struct dirent* entry;
            while ((entry = readdir(dir)) != NULL) {
                if (strstr(entry->d_name, ".so") || strstr(entry->d_name, ".dylib")) {
                    char full_path[512];
                    snprintf(full_path, sizeof(full_path), "%s/%s", 
                            g_registry.plugin_directory, entry->d_name);
                    
                    struct stat st;
                    if (stat(full_path, &st) == 0) {
                        // Check if plugin needs reloading
                        pthread_rwlock_rdlock(&g_registry.registry_lock);
                        
                        CapabilityNode* cap = g_registry.global_capabilities;
                        while (cap) {
                            if (cap->plugin_path && strcmp(cap->plugin_path, full_path) == 0) {
                                if (st.st_mtime > cap->last_modified) {
                                    printf("Plugin modified, reloading: %s\n", full_path);
                                    // Schedule reload (would be implemented)
                                }
                                break;
                            }
                            cap = cap->next;
                        }
                        
                        pthread_rwlock_unlock(&g_registry.registry_lock);
                    }
                }
            }
            closedir(dir);
        }
        
        sleep(5); // Check every 5 seconds
    }
    
    printf("Hot-reload monitor thread shutting down\n");
    return NULL;
}

//==============================================================================
// STATISTICS AND DEBUGGING
//==============================================================================

void capability_registry_print_stats(void) {
    pthread_rwlock_rdlock(&g_registry.registry_lock);
    
    printf("\n=== DevActor Capability Registry Statistics ===\n");
    printf("Total Workers: %u\n", atomic_load(&g_registry.total_workers));
    printf("Total Capabilities: %u\n", atomic_load(&g_registry.total_capabilities));
    printf("Plugin Directory: %s\n", g_registry.plugin_directory);
    printf("Hot-reload Enabled: %s\n", g_registry.hot_reload_enabled ? "Yes" : "No");
    
    printf("\nWorker Details:\n");
    WorkerNode* worker = g_registry.workers;
    while (worker) {
        printf("  %s (ID: %u, Capabilities: %u, State: %d)\n", 
               worker->worker.name, worker->worker.id, 
               worker->capability_count, worker->state);
        
        CapabilityNode* cap = worker->capabilities;
        while (cap) {
            printf("    - %s v%s (%s)\n", 
                   cap->capability.name, cap->capability.version, 
                   cap->capability.description);
            cap = cap->next;
        }
        worker = worker->next;
    }
    
    pthread_rwlock_unlock(&g_registry.registry_lock);
    printf("============================================\n\n");
}

int capability_registry_get_stats(RegistryStats* stats) {
    if (!stats) {
        return CAPABILITY_ERROR_INVALID_PARAMS;
    }
    
    pthread_rwlock_rdlock(&g_registry.registry_lock);
    
    stats->total_workers = atomic_load(&g_registry.total_workers);
    stats->total_capabilities = atomic_load(&g_registry.total_capabilities);
    stats->hot_reload_enabled = g_registry.hot_reload_enabled;
    
    strncpy(stats->plugin_directory, g_registry.plugin_directory, 
            sizeof(stats->plugin_directory) - 1);
    stats->plugin_directory[sizeof(stats->plugin_directory) - 1] = '\0';
    
    // Count workers by state
    stats->idle_workers = 0;
    stats->busy_workers = 0;
    stats->error_workers = 0;
    
    WorkerNode* worker = g_registry.workers;
    while (worker) {
        switch (worker->state) {
            case WORKER_STATE_IDLE:
                stats->idle_workers++;
                break;
            case WORKER_STATE_BUSY:
                stats->busy_workers++;
                break;
            case WORKER_STATE_ERROR:
                stats->error_workers++;
                break;
        }
        worker = worker->next;
    }
    
    pthread_rwlock_unlock(&g_registry.registry_lock);
    return CAPABILITY_SUCCESS;
}
