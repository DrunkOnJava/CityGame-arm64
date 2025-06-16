// SimCity ARM64 Secure Networking Layer
// Agent 5: Infrastructure & Networking
// TLS encryption and actor-model reliability for multi-agent communication

#ifndef SECURE_NETWORKING_H
#define SECURE_NETWORKING_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Forward declarations
typedef struct ActorContext ActorContext;
typedef struct ActorMessage ActorMessage;

// Message types for actor communication
typedef enum {
    MSG_TYPE_TASK_ASSIGNMENT = 1,
    MSG_TYPE_HEARTBEAT = 2,
    MSG_TYPE_RESOURCE_REQUEST = 3,
    MSG_TYPE_INTEGRATION_REQUEST = 4,
    MSG_TYPE_ERROR_REPORT = 5,
    MSG_TYPE_SHUTDOWN = 6
} MessageType;

// Actor state
typedef enum {
    ACTOR_STATE_IDLE = 0,
    ACTOR_STATE_RUNNING = 1,
    ACTOR_STATE_BLOCKED = 2,
    ACTOR_STATE_ERROR = 3,
    ACTOR_STATE_SHUTDOWN = 4
} ActorState;

//==============================================================================
// ACTOR SYSTEM API
//==============================================================================

/**
 * Initialize the actor system with TLS networking support
 * @return 0 on success, -1 on failure
 */
int actor_system_init(void);

/**
 * Shutdown the actor system and cleanup all resources
 */
void actor_system_shutdown(void);

/**
 * Create a new actor with custom message handler
 * @param actor_id Output parameter for the assigned actor ID
 * @param message_handler Function to handle incoming messages (NULL for default)
 * @param user_data User data passed to message handler
 * @return 0 on success, -1 on failure
 */
int actor_create(uint32_t* actor_id, 
                 void (*message_handler)(ActorContext*, ActorMessage*), 
                 void* user_data);

/**
 * Send a message from one actor to another
 * @param sender_id ID of sending actor
 * @param recipient_id ID of receiving actor
 * @param type Type of message
 * @param data Message payload data
 * @param size Size of payload data
 * @return 0 on success, -1 on failure
 */
int actor_send_message(uint32_t sender_id, uint32_t recipient_id, 
                       MessageType type, const void* data, uint32_t size);

/**
 * Get performance statistics for an actor
 * @param actor_id Actor to query
 * @param messages_processed Output for messages processed count
 * @param messages_sent Output for messages sent count  
 * @param error_count Output for error count
 * @return 0 on success, -1 on failure
 */
int actor_get_stats(uint32_t actor_id, uint64_t* messages_processed, 
                    uint64_t* messages_sent, uint32_t* error_count);

/**
 * Print system-wide actor statistics
 */
void actor_system_print_stats(void);

//==============================================================================
// NETWORK SERVER API
//==============================================================================

/**
 * Start the secure network server on specified port
 * @param port Port number to listen on
 * @return 0 on success, -1 on failure
 */
int network_server_start(uint16_t port);

/**
 * Send a secure message to a remote node
 * @param host Hostname or IP address
 * @param port Port number
 * @param msg Message to send
 * @return 0 on success, -1 on failure
 */
int network_send_secure_message(const char* host, uint16_t port, const ActorMessage* msg);

//==============================================================================
// HELPER FUNCTIONS FOR DEVACTOR INTEGRATION
//==============================================================================

/**
 * Create orchestrator actor for coordinating DevActors
 * @param orchestrator_id Output parameter for orchestrator actor ID
 * @return 0 on success, -1 on failure
 */
static inline int create_orchestrator_actor(uint32_t* orchestrator_id) {
    return actor_create(orchestrator_id, NULL, NULL);
}

/**
 * Create worker actor for DevActor tasks
 * @param worker_id Output parameter for worker actor ID
 * @param devactor_index Index of DevActor (0-9)
 * @return 0 on success, -1 on failure
 */
static inline int create_devactor_worker(uint32_t* worker_id, uint32_t devactor_index) {
    return actor_create(worker_id, NULL, (void*)(uintptr_t)devactor_index);
}

/**
 * Send task assignment to DevActor worker
 * @param orchestrator_id ID of orchestrator actor
 * @param worker_id ID of worker actor
 * @param task_data Task specification data
 * @param task_size Size of task data
 * @return 0 on success, -1 on failure
 */
static inline int assign_devactor_task(uint32_t orchestrator_id, uint32_t worker_id,
                                       const void* task_data, uint32_t task_size) {
    return actor_send_message(orchestrator_id, worker_id, MSG_TYPE_TASK_ASSIGNMENT, 
                             task_data, task_size);
}

/**
 * Send heartbeat to DevActor for health monitoring
 * @param orchestrator_id ID of orchestrator actor
 * @param worker_id ID of worker actor
 * @return 0 on success, -1 on failure
 */
static inline int send_devactor_heartbeat(uint32_t orchestrator_id, uint32_t worker_id) {
    return actor_send_message(orchestrator_id, worker_id, MSG_TYPE_HEARTBEAT, NULL, 0);
}

#ifdef __cplusplus
}
#endif

#endif // SECURE_NETWORKING_H