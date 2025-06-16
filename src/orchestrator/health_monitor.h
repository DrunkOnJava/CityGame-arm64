#ifndef HEALTH_MONITOR_H
#define HEALTH_MONITOR_H

#include <stdint.h>
#include <stdbool.h>
#include <time.h>

// Circuit breaker states for worker health management
typedef enum {
    CIRCUIT_CLOSED = 0,     // Normal operation
    CIRCUIT_OPEN = 1,       // Circuit tripped, worker isolated
    CIRCUIT_HALF_OPEN = 2   // Testing if worker recovered
} CircuitState;

// Worker health status levels
typedef enum {
    HEALTH_EXCELLENT = 0,   // All metrics green
    HEALTH_GOOD = 1,        // Minor issues
    HEALTH_DEGRADED = 2,    // Performance issues
    HEALTH_CRITICAL = 3,    // Major problems
    HEALTH_FAILED = 4       // Worker non-responsive
} HealthLevel;

// Health metrics for a single worker
typedef struct {
    char worker_id[64];
    uint64_t last_heartbeat_ms;
    uint64_t heartbeat_interval_ms;
    uint32_t missed_heartbeats;
    
    // Performance metrics
    float cpu_usage_percent;
    uint64_t memory_usage_mb;
    uint32_t active_tasks;
    uint32_t completed_tasks;
    uint32_t failed_tasks;
    float avg_task_time_ms;
    
    // Health assessment
    HealthLevel current_health;
    CircuitState circuit_state;
    uint64_t circuit_opened_at_ms;
    uint32_t consecutive_failures;
    
    // Thresholds (configurable per worker)
    uint32_t max_missed_heartbeats;
    float max_cpu_usage;
    uint64_t max_memory_mb;
    float max_avg_task_time_ms;
    uint32_t max_consecutive_failures;
} WorkerHealthMetrics;

// System-wide health monitoring
typedef struct {
    WorkerHealthMetrics workers[10];    // DevActor 0-9
    uint32_t active_worker_count;
    uint64_t system_start_time_ms;
    
    // Circuit breaker configuration
    uint32_t circuit_failure_threshold;  // Failures before opening
    uint64_t circuit_timeout_ms;         // How long circuit stays open
    uint64_t circuit_retry_interval_ms;  // Half-open retry frequency
    
    // Health check configuration
    uint64_t heartbeat_timeout_ms;       // When to consider worker dead
    uint32_t health_check_interval_ms;   // How often to assess health
    
    // Callbacks for health state changes
    void (*on_worker_healthy)(const char* worker_id);
    void (*on_worker_degraded)(const char* worker_id, HealthLevel level);
    void (*on_worker_failed)(const char* worker_id);
    void (*on_circuit_opened)(const char* worker_id);
    void (*on_circuit_closed)(const char* worker_id);
} HealthMonitor;

// Initialize health monitoring system
HealthMonitor* health_monitor_create(void);
void health_monitor_destroy(HealthMonitor* monitor);

// Worker registration and lifecycle
int health_monitor_register_worker(HealthMonitor* monitor, const char* worker_id);
int health_monitor_unregister_worker(HealthMonitor* monitor, const char* worker_id);

// Heartbeat processing
int health_monitor_process_heartbeat(HealthMonitor* monitor, const char* worker_id,
                                   float cpu_usage, uint64_t memory_usage,
                                   uint32_t active_tasks, float avg_task_time);

// Health assessment
HealthLevel health_monitor_assess_worker(HealthMonitor* monitor, const char* worker_id);
bool health_monitor_is_worker_available(HealthMonitor* monitor, const char* worker_id);
CircuitState health_monitor_get_circuit_state(HealthMonitor* monitor, const char* worker_id);

// Circuit breaker operations
int health_monitor_trip_circuit(HealthMonitor* monitor, const char* worker_id);
int health_monitor_test_circuit(HealthMonitor* monitor, const char* worker_id);
int health_monitor_close_circuit(HealthMonitor* monitor, const char* worker_id);

// System health overview
typedef struct {
    uint32_t healthy_workers;
    uint32_t degraded_workers;
    uint32_t failed_workers;
    uint32_t circuits_open;
    float system_cpu_average;
    uint64_t system_memory_total;
    uint32_t total_active_tasks;
} SystemHealthSummary;

SystemHealthSummary health_monitor_get_system_summary(HealthMonitor* monitor);

// Periodic health check (call every frame or timer)
void health_monitor_periodic_check(HealthMonitor* monitor);

// Configuration
int health_monitor_set_thresholds(HealthMonitor* monitor, const char* worker_id,
                                float max_cpu, uint64_t max_memory,
                                float max_task_time, uint32_t max_failures);

// Utility functions
uint64_t health_monitor_get_current_time_ms(void);
const char* health_level_to_string(HealthLevel level);
const char* circuit_state_to_string(CircuitState state);

#endif // HEALTH_MONITOR_H