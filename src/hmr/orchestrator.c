//
// SimCity ARM64 Assembly - HMR Orchestrator Implementation
// Agent 0: HMR Orchestrator
//
// Central coordinator for Hot Module Replacement system
// Manages inter-agent communication and system state
//

#include "../../include/interfaces/hmr_interfaces.h"
#include "../../include/interfaces/platform.h"
#include <sys/mman.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <assert.h>

// =============================================================================
// Global State
// =============================================================================

static hmr_shared_control_t* g_shared_control = NULL;
static hmr_module_registry_t* g_module_registry = NULL;
static hmr_message_queue_t* g_message_queue = NULL;
static pthread_mutex_t g_orchestrator_mutex = PTHREAD_MUTEX_INITIALIZER;
static int g_orchestrator_initialized = 0;
static pthread_t g_message_processor_thread;
static volatile int g_shutdown_requested = 0;

// =============================================================================
// Internal Functions
// =============================================================================

static void* message_processor_thread(void* arg);
static int setup_shared_memory(void);
static int cleanup_shared_memory(void);
static int validate_agent_id(uint32_t agent_id);
static int process_message(hmr_message_t* message);
static uint64_t get_current_timestamp(void);

// =============================================================================
// Shared Memory Management
// =============================================================================

static int setup_shared_memory(void) {
    size_t control_size = sizeof(hmr_shared_control_t);
    size_t registry_size = sizeof(hmr_module_registry_t);
    size_t queue_size = sizeof(hmr_message_queue_t);
    
    // Create shared control block
    g_shared_control = (hmr_shared_control_t*)mmap(
        NULL, control_size,
        PROT_READ | PROT_WRITE,
        MAP_SHARED | MAP_ANONYMOUS,
        -1, 0
    );
    
    if (g_shared_control == MAP_FAILED) {
        HMR_LOG_ERROR_F("Failed to create shared control block: %s", strerror(errno));
        return HMR_ERROR_ORCHESTRATOR_INIT;
    }
    
    // Create module registry
    g_module_registry = (hmr_module_registry_t*)mmap(
        NULL, registry_size,
        PROT_READ | PROT_WRITE,
        MAP_SHARED | MAP_ANONYMOUS,
        -1, 0
    );
    
    if (g_module_registry == MAP_FAILED) {
        HMR_LOG_ERROR_F("Failed to create module registry: %s", strerror(errno));
        munmap(g_shared_control, control_size);
        return HMR_ERROR_ORCHESTRATOR_INIT;
    }
    
    // Create message queue
    g_message_queue = (hmr_message_queue_t*)mmap(
        NULL, queue_size,
        PROT_READ | PROT_WRITE,
        MAP_SHARED | MAP_ANONYMOUS,
        -1, 0
    );
    
    if (g_message_queue == MAP_FAILED) {
        HMR_LOG_ERROR_F("Failed to create message queue: %s", strerror(errno));
        munmap(g_shared_control, control_size);
        munmap(g_module_registry, registry_size);
        return HMR_ERROR_ORCHESTRATOR_INIT;
    }
    
    // Initialize shared control block
    memset(g_shared_control, 0, sizeof(hmr_shared_control_t));
    g_shared_control->magic = HMR_MAGIC_NUMBER;
    g_shared_control->version = HMR_VERSION;
    g_shared_control->initialization_time = get_current_timestamp();
    g_shared_control->last_activity = g_shared_control->initialization_time;
    g_shared_control->debug_enabled = 1;
    g_shared_control->profiling_enabled = 1;
    g_shared_control->auto_rebuild = 1;
    g_shared_control->safety_checks = 1;
    g_shared_control->max_build_time_ns = 30 * HMR_NANOSECONDS_PER_SECOND;  // 30 seconds
    g_shared_control->max_hotswap_time_ns = 1 * HMR_NANOSECONDS_PER_SECOND; // 1 second
    g_shared_control->max_concurrent_builds = 4;
    g_shared_control->max_module_size_mb = 100;
    
    // Initialize module registry
    memset(g_module_registry, 0, sizeof(hmr_module_registry_t));
    
    // Initialize message queue
    memset(g_message_queue, 0, sizeof(hmr_message_queue_t));
    
    return HMR_SUCCESS;
}

static int cleanup_shared_memory(void) {
    int result = HMR_SUCCESS;
    
    if (g_shared_control != NULL) {
        if (munmap(g_shared_control, sizeof(hmr_shared_control_t)) != 0) {
            HMR_LOG_ERROR_F("Failed to unmap shared control: %s", strerror(errno));
            result = HMR_ERROR_ORCHESTRATOR_STATE;
        }
        g_shared_control = NULL;
    }
    
    if (g_module_registry != NULL) {
        if (munmap(g_module_registry, sizeof(hmr_module_registry_t)) != 0) {
            HMR_LOG_ERROR_F("Failed to unmap module registry: %s", strerror(errno));
            result = HMR_ERROR_ORCHESTRATOR_STATE;
        }
        g_module_registry = NULL;
    }
    
    if (g_message_queue != NULL) {
        if (munmap(g_message_queue, sizeof(hmr_message_queue_t)) != 0) {
            HMR_LOG_ERROR_F("Failed to unmap message queue: %s", strerror(errno));
            result = HMR_ERROR_ORCHESTRATOR_STATE;
        }
        g_message_queue = NULL;
    }
    
    return result;
}

// =============================================================================
// Message Processing
// =============================================================================

static void* message_processor_thread(void* arg) {
    (void)arg;  // Unused parameter
    
    HMR_LOG_INFO_F("Message processor thread started");
    
    while (!g_shutdown_requested) {
        // Check for messages in the queue
        uint64_t head = g_message_queue->head;
        uint64_t tail = g_message_queue->tail;
        
        if (head != tail) {
            // Process messages
            while (tail != head && !g_shutdown_requested) {
                uint64_t index = tail % HMR_MESSAGE_QUEUE_SIZE;
                hmr_message_t* message = &g_message_queue->messages[index];
                
                if (process_message(message) != HMR_SUCCESS) {
                    HMR_LOG_ERROR_F("Failed to process message type %d from agent %d", 
                                   message->type, message->sender_id);
                }
                
                // Advance tail
                __atomic_add_fetch(&g_message_queue->tail, 1, __ATOMIC_SEQ_CST);
                tail = g_message_queue->tail;
            }
        }
        
        // Update last activity timestamp
        g_shared_control->last_activity = get_current_timestamp();
        
        // Sleep briefly to avoid busy waiting
        usleep(1000); // 1ms
    }
    
    HMR_LOG_INFO_F("Message processor thread shutting down");
    return NULL;
}

static int process_message(hmr_message_t* message) {
    if (message == NULL) {
        return HMR_ERROR_ORCHESTRATOR_STATE;
    }
    
    HMR_LOG_DEBUG_F("Processing message type %d from agent %d to agent %d",
                   message->type, message->sender_id, message->recipient_id);
    
    switch (message->type) {
        case HMR_MSG_MODULE_DISCOVERED:
            // Handle module discovery
            HMR_LOG_INFO_F("Module discovered by agent %d", message->sender_id);
            break;
            
        case HMR_MSG_BUILD_COMPLETED:
            // Handle build completion
            HMR_LOG_INFO_F("Build completed by agent %d", message->sender_id);
            __atomic_add_fetch(&g_shared_control->total_builds, 1, __ATOMIC_SEQ_CST);
            break;
            
        case HMR_MSG_BUILD_FAILED:
            // Handle build failure
            HMR_LOG_ERROR_F("Build failed in agent %d", message->sender_id);
            __atomic_add_fetch(&g_shared_control->total_errors, 1, __ATOMIC_SEQ_CST);
            break;
            
        case HMR_MSG_HOTSWAP_COMPLETE:
            // Handle hot-swap completion
            HMR_LOG_INFO_F("Hot-swap completed by agent %d", message->sender_id);
            __atomic_add_fetch(&g_shared_control->total_hotswaps, 1, __ATOMIC_SEQ_CST);
            break;
            
        case HMR_MSG_HOTSWAP_FAILED:
            // Handle hot-swap failure
            HMR_LOG_ERROR_F("Hot-swap failed in agent %d", message->sender_id);
            __atomic_add_fetch(&g_shared_control->total_errors, 1, __ATOMIC_SEQ_CST);
            break;
            
        case HMR_MSG_SHUTDOWN_REQUEST:
            // Handle shutdown request
            HMR_LOG_INFO_F("Shutdown request from agent %d", message->sender_id);
            g_shutdown_requested = 1;
            break;
            
        default:
            HMR_LOG_WARN_F("Unknown message type %d from agent %d", 
                          message->type, message->sender_id);
            return HMR_ERROR_ORCHESTRATOR_STATE;
    }
    
    return HMR_SUCCESS;
}

// =============================================================================
// Public API Implementation
// =============================================================================

int hmr_orchestrator_init(void) {
    pthread_mutex_lock(&g_orchestrator_mutex);
    
    if (g_orchestrator_initialized) {
        pthread_mutex_unlock(&g_orchestrator_mutex);
        return HMR_SUCCESS;
    }
    
    HMR_LOG_INFO_F("Initializing HMR Orchestrator");
    
    // Set up shared memory
    int result = setup_shared_memory();
    if (result != HMR_SUCCESS) {
        pthread_mutex_unlock(&g_orchestrator_mutex);
        return result;
    }
    
    // Register orchestrator as agent 0
    result = hmr_register_agent(HMR_AGENT_ORCHESTRATOR, "orchestrator");
    if (result != HMR_SUCCESS) {
        cleanup_shared_memory();
        pthread_mutex_unlock(&g_orchestrator_mutex);
        return result;
    }
    
    // Start message processor thread
    if (pthread_create(&g_message_processor_thread, NULL, message_processor_thread, NULL) != 0) {
        HMR_LOG_ERROR_F("Failed to create message processor thread: %s", strerror(errno));
        cleanup_shared_memory();
        pthread_mutex_unlock(&g_orchestrator_mutex);
        return HMR_ERROR_ORCHESTRATOR_INIT;
    }
    
    g_orchestrator_initialized = 1;
    
    HMR_LOG_INFO_F("HMR Orchestrator initialized successfully");
    pthread_mutex_unlock(&g_orchestrator_mutex);
    return HMR_SUCCESS;
}

int hmr_orchestrator_shutdown(void) {
    pthread_mutex_lock(&g_orchestrator_mutex);
    
    if (!g_orchestrator_initialized) {
        pthread_mutex_unlock(&g_orchestrator_mutex);
        return HMR_SUCCESS;
    }
    
    HMR_LOG_INFO_F("Shutting down HMR Orchestrator");
    
    // Signal shutdown to message processor
    g_shutdown_requested = 1;
    
    // Wait for message processor thread to complete
    if (pthread_join(g_message_processor_thread, NULL) != 0) {
        HMR_LOG_ERROR_F("Failed to join message processor thread: %s", strerror(errno));
    }
    
    // Clean up shared memory
    int result = cleanup_shared_memory();
    
    g_orchestrator_initialized = 0;
    
    HMR_LOG_INFO_F("HMR Orchestrator shutdown complete");
    pthread_mutex_unlock(&g_orchestrator_mutex);
    return result;
}

int hmr_register_agent(uint32_t agent_id, const char* name) {
    if (!validate_agent_id(agent_id)) {
        return HMR_ERROR_ORCHESTRATOR_STATE;
    }
    
    if (g_shared_control == NULL) {
        return HMR_ERROR_ORCHESTRATOR_STATE;
    }
    
    // Update agent status in shared control
    if (agent_id < 8) {  // Bounds check
        g_shared_control->agents[agent_id].agent_id = agent_id;
        g_shared_control->agents[agent_id].status = 2; // Active
        g_shared_control->agents[agent_id].last_heartbeat = get_current_timestamp();
        g_shared_control->agents[agent_id].message_queue_depth = 0;
        
        // Update agent count if this is a new agent
        if (agent_id >= g_shared_control->agent_count) {
            g_shared_control->agent_count = agent_id + 1;
        }
    }
    
    HMR_LOG_INFO_F("Registered agent %d (%s)", agent_id, name ? name : "unknown");
    return HMR_SUCCESS;
}

int hmr_send_message(hmr_message_t* message) {
    if (message == NULL || g_message_queue == NULL) {
        return HMR_ERROR_ORCHESTRATOR_STATE;
    }
    
    // Validate sender and recipient
    if (!validate_agent_id(message->sender_id)) {
        return HMR_ERROR_AGENT_COMM;
    }
    
    if (message->recipient_id != 0 && !validate_agent_id(message->recipient_id)) {
        return HMR_ERROR_AGENT_COMM;
    }
    
    // Get current queue position
    uint64_t head = __atomic_load_n(&g_message_queue->head, __ATOMIC_SEQ_CST);
    uint64_t tail = __atomic_load_n(&g_message_queue->tail, __ATOMIC_SEQ_CST);
    
    // Check if queue is full
    if (head - tail >= HMR_MESSAGE_QUEUE_SIZE) {
        HMR_LOG_ERROR_F("Message queue full, dropping message from agent %d", message->sender_id);
        return HMR_ERROR_AGENT_COMM;
    }
    
    // Add message to queue
    uint64_t index = head % HMR_MESSAGE_QUEUE_SIZE;
    memcpy(&g_message_queue->messages[index], message, sizeof(hmr_message_t));
    
    // Advance head
    __atomic_add_fetch(&g_message_queue->head, 1, __ATOMIC_SEQ_CST);
    
    // Update sender's message queue depth
    if (message->sender_id < 8) {
        __atomic_add_fetch(&g_shared_control->agents[message->sender_id].message_queue_depth, 1, __ATOMIC_SEQ_CST);
    }
    
    return HMR_SUCCESS;
}

int hmr_broadcast_message(hmr_message_t* message) {
    if (message == NULL) {
        return HMR_ERROR_ORCHESTRATOR_STATE;
    }
    
    // Set recipient to 0 for broadcast
    message->recipient_id = 0;
    
    return hmr_send_message(message);
}

int hmr_get_module_info(const char* name, hmr_module_info_t* info) {
    if (name == NULL || info == NULL || g_module_registry == NULL) {
        return HMR_ERROR_ORCHESTRATOR_STATE;
    }
    
    // Search for module by name
    for (uint32_t i = 0; i < g_module_registry->module_count; i++) {
        if (strncmp(g_module_registry->modules[i].name, name, sizeof(g_module_registry->modules[i].name)) == 0) {
            memcpy(info, &g_module_registry->modules[i], sizeof(hmr_module_info_t));
            return HMR_SUCCESS;
        }
    }
    
    return HMR_ERROR_MODULE_LOAD; // Module not found
}

int hmr_update_module_state(const char* name, hmr_module_state_t state) {
    if (name == NULL || g_module_registry == NULL) {
        return HMR_ERROR_ORCHESTRATOR_STATE;
    }
    
    // Search for module by name and update state
    for (uint32_t i = 0; i < g_module_registry->module_count; i++) {
        if (strncmp(g_module_registry->modules[i].name, name, sizeof(g_module_registry->modules[i].name)) == 0) {
            g_module_registry->modules[i].state = state;
            HMR_LOG_DEBUG_F("Updated module %s state to %d", name, state);
            return HMR_SUCCESS;
        }
    }
    
    return HMR_ERROR_MODULE_LOAD; // Module not found
}

// =============================================================================
// Utility Functions
// =============================================================================

static uint64_t get_current_timestamp(void) {
    return platform_get_timestamp();
}

static int validate_agent_id(uint32_t agent_id) {
    return (agent_id <= 5); // Agents 0-5 are valid
}

// =============================================================================
// Global State Access Functions
// =============================================================================

hmr_shared_control_t* hmr_get_shared_control(void) {
    return g_shared_control;
}

hmr_module_registry_t* hmr_get_module_registry(void) {
    return g_module_registry;
}

hmr_message_queue_t* hmr_get_message_queue(void) {
    return g_message_queue;
}

// =============================================================================
// Thread-Safe Operations
// =============================================================================

int hmr_atomic_update_module_state(uint32_t module_id, hmr_module_state_t old_state, hmr_module_state_t new_state) {
    if (g_module_registry == NULL || module_id >= g_module_registry->module_count) {
        return HMR_ERROR_ORCHESTRATOR_STATE;
    }
    
    // Use compare-and-swap to atomically update state
    hmr_module_state_t* state_ptr = &g_module_registry->modules[module_id].state;
    return __atomic_compare_exchange_n(state_ptr, &old_state, new_state, 0, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST) ? HMR_SUCCESS : HMR_ERROR_ORCHESTRATOR_STATE;
}

int hmr_atomic_increment_counter(volatile uint64_t* counter) {
    if (counter == NULL) {
        return HMR_ERROR_ORCHESTRATOR_STATE;
    }
    
    __atomic_add_fetch(counter, 1, __ATOMIC_SEQ_CST);
    return HMR_SUCCESS;
}

int hmr_atomic_set_agent_status(uint32_t agent_id, uint32_t status) {
    if (g_shared_control == NULL || agent_id >= 8) {
        return HMR_ERROR_ORCHESTRATOR_STATE;
    }
    
    g_shared_control->agents[agent_id].status = status;
    g_shared_control->agents[agent_id].last_heartbeat = get_current_timestamp();
    
    return HMR_SUCCESS;
}

// Stub implementation for logging (to be implemented by Agent 4)
int hmr_log_event(uint32_t level, const char* format, ...) {
    (void)level;
    (void)format;
    // This will be implemented by Agent 4: Developer Tools
    return HMR_SUCCESS;
}