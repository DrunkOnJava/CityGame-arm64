#ifndef ORCHESTRATOR_H
#define ORCHESTRATOR_H

#include <stdint.h>
#include <stdbool.h>
#include <time.h>

// Agent IDs
typedef enum {
    AGENT_ORCHESTRATOR = 0,
    AGENT_CORE_ENGINE = 1,
    AGENT_SIMULATION = 2,
    AGENT_GRAPHICS = 3,
    AGENT_AI_BEHAVIOR = 4,
    AGENT_INFRASTRUCTURE = 5,
    AGENT_DATA_PERSISTENCE = 6,
    AGENT_UI_UX = 7,
    AGENT_AUDIO_ENV = 8,
    AGENT_QA_TESTING = 9,
    AGENT_COUNT = 10
} AgentID;

// Message types
typedef enum {
    MSG_TASK_ASSIGN,
    MSG_STATUS_UPDATE,
    MSG_RESOURCE_REQUEST,
    MSG_INTEGRATION_READY,
    MSG_CONFLICT_ALERT,
    MSG_BROADCAST,
    MSG_QUERY,
    MSG_RESPONSE,
    MSG_SYNC_REQUEST,
    MSG_HEARTBEAT
} MessageType;

// Priority levels
typedef enum {
    PRIORITY_CRITICAL = 0,
    PRIORITY_HIGH = 1,
    PRIORITY_NORMAL = 2,
    PRIORITY_LOW = 3
} MessagePriority;

// Task states
typedef enum {
    TASK_PENDING,
    TASK_IN_PROGRESS,
    TASK_BLOCKED,
    TASK_READY_FOR_REVIEW,
    TASK_COMPLETE,
    TASK_FAILED
} TaskState;

// Agent states
typedef enum {
    AGENT_IDLE,
    AGENT_WORKING,
    AGENT_BLOCKED,
    AGENT_SYNCING,
    AGENT_ERROR
} AgentState;

// Message structure
typedef struct {
    uint64_t timestamp;
    AgentID from;
    AgentID to;
    MessageType type;
    MessagePriority priority;
    uint32_t payload_size;
    void* payload;
    uint64_t correlation_id;  // For request/response matching
} Message;

// Task structure
typedef struct {
    uint32_t task_id;
    char name[256];
    AgentID assigned_to;
    TaskState state;
    uint64_t created_at;
    uint64_t updated_at;
    uint32_t dependencies[16];  // Task IDs this depends on
    uint32_t dependency_count;
    float progress;  // 0.0 to 1.0
    char blocked_reason[512];
} Task;

// Agent info structure
typedef struct {
    AgentID id;
    char name[64];
    AgentState state;
    uint32_t active_tasks;
    uint32_t completed_tasks;
    uint64_t last_heartbeat;
    float cpu_usage;
    float memory_usage;
    uint32_t messages_sent;
    uint32_t messages_received;
} AgentInfo;

// File ownership record
typedef struct {
    char filepath[512];
    AgentID owner;
    AgentID readers[AGENT_COUNT];
    uint32_t reader_count;
    uint64_t locked_at;
    bool is_locked;
} FileOwnership;

// Conflict record
typedef struct {
    uint32_t conflict_id;
    char description[1024];
    AgentID agents_involved[AGENT_COUNT];
    uint32_t agent_count;
    uint64_t detected_at;
    bool resolved;
    char resolution[1024];
} Conflict;

// Performance metrics
typedef struct {
    uint64_t messages_processed;
    uint64_t conflicts_detected;
    uint64_t conflicts_resolved;
    uint64_t integrations_completed;
    float average_response_time;
    float system_cpu_usage;
    float system_memory_usage;
    uint32_t active_agents;
} SystemMetrics;

// Orchestrator context
typedef struct {
    AgentInfo agents[AGENT_COUNT];
    Task* tasks;
    uint32_t task_count;
    uint32_t task_capacity;
    FileOwnership* file_registry;
    uint32_t file_count;
    uint32_t file_capacity;
    Conflict* conflicts;
    uint32_t conflict_count;
    uint32_t conflict_capacity;
    SystemMetrics metrics;
    void* message_queue;  // Platform-specific queue implementation
    void* lock;           // Platform-specific lock
} OrchestratorContext;

// Core functions
OrchestratorContext* orchestrator_init(void);
void orchestrator_shutdown(OrchestratorContext* ctx);

// Message handling
int orchestrator_send_message(OrchestratorContext* ctx, Message* msg);
Message* orchestrator_receive_message(OrchestratorContext* ctx, AgentID agent);
int orchestrator_broadcast(OrchestratorContext* ctx, Message* msg);

// Task management
uint32_t orchestrator_create_task(OrchestratorContext* ctx, const char* name, AgentID assignee);
int orchestrator_update_task(OrchestratorContext* ctx, uint32_t task_id, TaskState state, float progress);
Task* orchestrator_get_task(OrchestratorContext* ctx, uint32_t task_id);
int orchestrator_add_dependency(OrchestratorContext* ctx, uint32_t task_id, uint32_t dependency_id);

// Agent management
int orchestrator_register_agent(OrchestratorContext* ctx, AgentID id, const char* name);
int orchestrator_update_agent_state(OrchestratorContext* ctx, AgentID id, AgentState state);
AgentInfo* orchestrator_get_agent_info(OrchestratorContext* ctx, AgentID id);
int orchestrator_heartbeat(OrchestratorContext* ctx, AgentID id);

// File ownership
int orchestrator_claim_file(OrchestratorContext* ctx, const char* filepath, AgentID owner);
int orchestrator_request_file_access(OrchestratorContext* ctx, const char* filepath, AgentID requester, bool write_access);
int orchestrator_release_file(OrchestratorContext* ctx, const char* filepath, AgentID owner);
FileOwnership* orchestrator_check_file_ownership(OrchestratorContext* ctx, const char* filepath);

// Conflict management
uint32_t orchestrator_report_conflict(OrchestratorContext* ctx, const char* description, AgentID* agents, uint32_t agent_count);
int orchestrator_resolve_conflict(OrchestratorContext* ctx, uint32_t conflict_id, const char* resolution);
Conflict* orchestrator_get_conflict(OrchestratorContext* ctx, uint32_t conflict_id);

// Integration coordination
int orchestrator_request_integration(OrchestratorContext* ctx, AgentID requester, AgentID* participants, uint32_t count);
int orchestrator_approve_integration(OrchestratorContext* ctx, uint32_t integration_id);
int orchestrator_integration_complete(OrchestratorContext* ctx, uint32_t integration_id, bool success);

// Metrics and monitoring
SystemMetrics orchestrator_get_metrics(OrchestratorContext* ctx);
int orchestrator_log_performance(OrchestratorContext* ctx, const char* event, uint64_t duration_ns);
int orchestrator_check_system_health(OrchestratorContext* ctx);

// Utility functions
uint64_t orchestrator_get_timestamp(void);
const char* agent_id_to_string(AgentID id);
const char* task_state_to_string(TaskState state);
const char* agent_state_to_string(AgentState state);

#endif // ORCHESTRATOR_H