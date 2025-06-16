#include "health_monitor.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sys/time.h>

// Default thresholds for worker health
#define DEFAULT_MAX_CPU_USAGE 80.0f
#define DEFAULT_MAX_MEMORY_MB 2048
#define DEFAULT_MAX_TASK_TIME_MS 5000.0f
#define DEFAULT_MAX_CONSECUTIVE_FAILURES 3
#define DEFAULT_MAX_MISSED_HEARTBEATS 3

#define DEFAULT_CIRCUIT_FAILURE_THRESHOLD 5
#define DEFAULT_CIRCUIT_TIMEOUT_MS 30000      // 30 seconds
#define DEFAULT_CIRCUIT_RETRY_INTERVAL_MS 5000 // 5 seconds
#define DEFAULT_HEARTBEAT_TIMEOUT_MS 10000     // 10 seconds
#define DEFAULT_HEALTH_CHECK_INTERVAL_MS 1000  // 1 second

HealthMonitor* health_monitor_create(void) {
    HealthMonitor* monitor = calloc(1, sizeof(HealthMonitor));
    if (!monitor) return NULL;
    
    // Initialize default configuration
    monitor->circuit_failure_threshold = DEFAULT_CIRCUIT_FAILURE_THRESHOLD;
    monitor->circuit_timeout_ms = DEFAULT_CIRCUIT_TIMEOUT_MS;
    monitor->circuit_retry_interval_ms = DEFAULT_CIRCUIT_RETRY_INTERVAL_MS;
    monitor->heartbeat_timeout_ms = DEFAULT_HEARTBEAT_TIMEOUT_MS;
    monitor->health_check_interval_ms = DEFAULT_HEALTH_CHECK_INTERVAL_MS;
    monitor->system_start_time_ms = health_monitor_get_current_time_ms();
    
    // Initialize all workers as unregistered
    for (int i = 0; i < 10; i++) {
        monitor->workers[i].worker_id[0] = '\0';
        monitor->workers[i].current_health = HEALTH_FAILED;
        monitor->workers[i].circuit_state = CIRCUIT_OPEN;
    }
    
    return monitor;
}

void health_monitor_destroy(HealthMonitor* monitor) {
    if (monitor) {
        free(monitor);
    }
}

int health_monitor_register_worker(HealthMonitor* monitor, const char* worker_id) {
    if (!monitor || !worker_id) return -1;
    
    // Find empty slot
    for (int i = 0; i < 10; i++) {
        if (monitor->workers[i].worker_id[0] == '\0') {
            strncpy(monitor->workers[i].worker_id, worker_id, 63);
            monitor->workers[i].worker_id[63] = '\0';
            
            // Set default thresholds
            monitor->workers[i].max_cpu_usage = DEFAULT_MAX_CPU_USAGE;
            monitor->workers[i].max_memory_mb = DEFAULT_MAX_MEMORY_MB;
            monitor->workers[i].max_avg_task_time_ms = DEFAULT_MAX_TASK_TIME_MS;
            monitor->workers[i].max_consecutive_failures = DEFAULT_MAX_CONSECUTIVE_FAILURES;
            monitor->workers[i].max_missed_heartbeats = DEFAULT_MAX_MISSED_HEARTBEATS;
            
            // Initialize health state
            monitor->workers[i].current_health = HEALTH_EXCELLENT;
            monitor->workers[i].circuit_state = CIRCUIT_CLOSED;
            monitor->workers[i].last_heartbeat_ms = health_monitor_get_current_time_ms();
            monitor->workers[i].heartbeat_interval_ms = 1000; // 1 second default
            
            monitor->active_worker_count++;
            
            if (monitor->on_worker_healthy) {
                monitor->on_worker_healthy(worker_id);
            }
            
            return i; // Return worker index
        }
    }
    
    return -1; // No slots available
}

int health_monitor_unregister_worker(HealthMonitor* monitor, const char* worker_id) {
    if (!monitor || !worker_id) return -1;
    
    for (int i = 0; i < 10; i++) {
        if (strcmp(monitor->workers[i].worker_id, worker_id) == 0) {
            monitor->workers[i].worker_id[0] = '\0';
            monitor->workers[i].current_health = HEALTH_FAILED;
            monitor->workers[i].circuit_state = CIRCUIT_OPEN;
            monitor->active_worker_count--;
            return 0;
        }
    }
    
    return -1; // Worker not found
}

int health_monitor_process_heartbeat(HealthMonitor* monitor, const char* worker_id,
                                   float cpu_usage, uint64_t memory_usage,
                                   uint32_t active_tasks, float avg_task_time) {
    if (!monitor || !worker_id) return -1;
    
    // Find worker
    WorkerHealthMetrics* worker = NULL;
    for (int i = 0; i < 10; i++) {
        if (strcmp(monitor->workers[i].worker_id, worker_id) == 0) {
            worker = &monitor->workers[i];
            break;
        }
    }
    
    if (!worker) return -1; // Worker not found
    
    uint64_t now = health_monitor_get_current_time_ms();
    
    // Update heartbeat timing
    worker->last_heartbeat_ms = now;
    worker->missed_heartbeats = 0; // Reset missed count
    
    // Update performance metrics
    worker->cpu_usage_percent = cpu_usage;
    worker->memory_usage_mb = memory_usage;
    worker->active_tasks = active_tasks;
    
    // Update running averages
    if (worker->completed_tasks > 0) {
        worker->avg_task_time_ms = (worker->avg_task_time_ms * 0.9f) + (avg_task_time * 0.1f);
    } else {
        worker->avg_task_time_ms = avg_task_time;
    }
    
    // Assess health based on metrics
    HealthLevel old_health = worker->current_health;
    worker->current_health = health_monitor_assess_worker(monitor, worker_id);
    
    // Handle health state changes
    if (old_health != worker->current_health) {
        if (worker->current_health <= HEALTH_GOOD && old_health > HEALTH_GOOD) {
            // Worker recovered
            if (monitor->on_worker_healthy) {
                monitor->on_worker_healthy(worker_id);
            }
            // Try to close circuit if it was open
            if (worker->circuit_state != CIRCUIT_CLOSED) {
                health_monitor_close_circuit(monitor, worker_id);
            }
        } else if (worker->current_health > HEALTH_GOOD) {
            // Worker degraded
            if (monitor->on_worker_degraded) {
                monitor->on_worker_degraded(worker_id, worker->current_health);
            }
        }
    }
    
    return 0;
}

HealthLevel health_monitor_assess_worker(HealthMonitor* monitor, const char* worker_id) {
    if (!monitor || !worker_id) return HEALTH_FAILED;
    
    WorkerHealthMetrics* worker = NULL;
    for (int i = 0; i < 10; i++) {
        if (strcmp(monitor->workers[i].worker_id, worker_id) == 0) {
            worker = &monitor->workers[i];
            break;
        }
    }
    
    if (!worker) return HEALTH_FAILED;
    
    uint64_t now = health_monitor_get_current_time_ms();
    uint64_t time_since_heartbeat = now - worker->last_heartbeat_ms;
    
    // Check if worker is responsive
    if (time_since_heartbeat > monitor->heartbeat_timeout_ms) {
        return HEALTH_FAILED;
    }
    
    // Count health violations
    int violations = 0;
    
    if (worker->cpu_usage_percent > worker->max_cpu_usage) violations++;
    if (worker->memory_usage_mb > worker->max_memory_mb) violations++;
    if (worker->avg_task_time_ms > worker->max_avg_task_time_ms) violations++;
    if (worker->consecutive_failures >= worker->max_consecutive_failures) violations++;
    
    // Assess based on violation count
    if (violations == 0) return HEALTH_EXCELLENT;
    if (violations == 1) return HEALTH_GOOD;
    if (violations == 2) return HEALTH_DEGRADED;
    return HEALTH_CRITICAL;
}

bool health_monitor_is_worker_available(HealthMonitor* monitor, const char* worker_id) {
    if (!monitor || !worker_id) return false;
    
    HealthLevel health = health_monitor_assess_worker(monitor, worker_id);
    CircuitState circuit = health_monitor_get_circuit_state(monitor, worker_id);
    
    // Worker is available if healthy and circuit is closed
    return (health <= HEALTH_DEGRADED) && (circuit == CIRCUIT_CLOSED);
}

CircuitState health_monitor_get_circuit_state(HealthMonitor* monitor, const char* worker_id) {
    if (!monitor || !worker_id) return CIRCUIT_OPEN;
    
    for (int i = 0; i < 10; i++) {
        if (strcmp(monitor->workers[i].worker_id, worker_id) == 0) {
            return monitor->workers[i].circuit_state;
        }
    }
    
    return CIRCUIT_OPEN;
}

int health_monitor_trip_circuit(HealthMonitor* monitor, const char* worker_id) {
    if (!monitor || !worker_id) return -1;
    
    for (int i = 0; i < 10; i++) {
        if (strcmp(monitor->workers[i].worker_id, worker_id) == 0) {
            monitor->workers[i].circuit_state = CIRCUIT_OPEN;
            monitor->workers[i].circuit_opened_at_ms = health_monitor_get_current_time_ms();
            
            if (monitor->on_circuit_opened) {
                monitor->on_circuit_opened(worker_id);
            }
            
            return 0;
        }
    }
    
    return -1;
}

int health_monitor_test_circuit(HealthMonitor* monitor, const char* worker_id) {
    if (!monitor || !worker_id) return -1;
    
    for (int i = 0; i < 10; i++) {
        if (strcmp(monitor->workers[i].worker_id, worker_id) == 0) {
            if (monitor->workers[i].circuit_state == CIRCUIT_HALF_OPEN) {
                monitor->workers[i].circuit_state = CIRCUIT_HALF_OPEN;
                return 0;
            }
            return -1; // Can only test if half-open
        }
    }
    
    return -1;
}

int health_monitor_close_circuit(HealthMonitor* monitor, const char* worker_id) {
    if (!monitor || !worker_id) return -1;
    
    for (int i = 0; i < 10; i++) {
        if (strcmp(monitor->workers[i].worker_id, worker_id) == 0) {
            monitor->workers[i].circuit_state = CIRCUIT_CLOSED;
            monitor->workers[i].consecutive_failures = 0;
            
            if (monitor->on_circuit_closed) {
                monitor->on_circuit_closed(worker_id);
            }
            
            return 0;
        }
    }
    
    return -1;
}

void health_monitor_periodic_check(HealthMonitor* monitor) {
    if (!monitor) return;
    
    uint64_t now = health_monitor_get_current_time_ms();
    
    for (int i = 0; i < 10; i++) {
        WorkerHealthMetrics* worker = &monitor->workers[i];
        if (worker->worker_id[0] == '\0') continue; // Unregistered worker
        
        uint64_t time_since_heartbeat = now - worker->last_heartbeat_ms;
        
        // Check for missed heartbeats
        if (time_since_heartbeat > worker->heartbeat_interval_ms * 2) {
            worker->missed_heartbeats++;
            
            if (worker->missed_heartbeats >= worker->max_missed_heartbeats) {
                // Worker failed - trip circuit
                if (worker->circuit_state != CIRCUIT_OPEN) {
                    health_monitor_trip_circuit(monitor, worker->worker_id);
                    if (monitor->on_worker_failed) {
                        monitor->on_worker_failed(worker->worker_id);
                    }
                }
            }
        }
        
        // Handle circuit breaker state transitions
        if (worker->circuit_state == CIRCUIT_OPEN) {
            uint64_t time_since_opened = now - worker->circuit_opened_at_ms;
            if (time_since_opened > monitor->circuit_timeout_ms) {
                // Try half-open state
                worker->circuit_state = CIRCUIT_HALF_OPEN;
            }
        }
    }
}

SystemHealthSummary health_monitor_get_system_summary(HealthMonitor* monitor) {
    SystemHealthSummary summary = {0};
    
    if (!monitor) return summary;
    
    float total_cpu = 0.0f;
    uint32_t cpu_samples = 0;
    
    for (int i = 0; i < 10; i++) {
        WorkerHealthMetrics* worker = &monitor->workers[i];
        if (worker->worker_id[0] == '\0') continue;
        
        HealthLevel health = health_monitor_assess_worker(monitor, worker->worker_id);
        
        switch (health) {
            case HEALTH_EXCELLENT:
            case HEALTH_GOOD:
                summary.healthy_workers++;
                break;
            case HEALTH_DEGRADED:
                summary.degraded_workers++;
                break;
            case HEALTH_CRITICAL:
            case HEALTH_FAILED:
                summary.failed_workers++;
                break;
        }
        
        if (worker->circuit_state == CIRCUIT_OPEN) {
            summary.circuits_open++;
        }
        
        summary.system_memory_total += worker->memory_usage_mb;
        summary.total_active_tasks += worker->active_tasks;
        
        if (health <= HEALTH_DEGRADED) { // Only count responsive workers
            total_cpu += worker->cpu_usage_percent;
            cpu_samples++;
        }
    }
    
    summary.system_cpu_average = cpu_samples > 0 ? (total_cpu / cpu_samples) : 0.0f;
    
    return summary;
}

uint64_t health_monitor_get_current_time_ms(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (uint64_t)(tv.tv_sec) * 1000 + (uint64_t)(tv.tv_usec) / 1000;
}

const char* health_level_to_string(HealthLevel level) {
    switch (level) {
        case HEALTH_EXCELLENT: return "EXCELLENT";
        case HEALTH_GOOD: return "GOOD";
        case HEALTH_DEGRADED: return "DEGRADED";
        case HEALTH_CRITICAL: return "CRITICAL";
        case HEALTH_FAILED: return "FAILED";
        default: return "UNKNOWN";
    }
}

int health_monitor_set_thresholds(HealthMonitor* monitor, const char* worker_id,
                                float max_cpu, uint64_t max_memory,
                                float max_task_time, uint32_t max_failures) {
    if (!monitor || !worker_id) return -1;
    
    for (int i = 0; i < 10; i++) {
        if (strcmp(monitor->workers[i].worker_id, worker_id) == 0) {
            monitor->workers[i].max_cpu_usage = max_cpu;
            monitor->workers[i].max_memory_mb = max_memory;
            monitor->workers[i].max_avg_task_time_ms = max_task_time;
            monitor->workers[i].max_consecutive_failures = max_failures;
            return 0;
        }
    }
    
    return -1;
}

const char* circuit_state_to_string(CircuitState state) {
    switch (state) {
        case CIRCUIT_CLOSED: return "CLOSED";
        case CIRCUIT_OPEN: return "OPEN";
        case CIRCUIT_HALF_OPEN: return "HALF_OPEN";
        default: return "UNKNOWN";
    }
}