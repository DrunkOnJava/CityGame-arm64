#ifndef SYSTEM_MOCKS_H
#define SYSTEM_MOCKS_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Mock type definitions
typedef struct hmr_distributed_error_recovery {
    int placeholder;
} hmr_distributed_error_recovery_t;

typedef struct hmr_system_performance_orchestrator {
    int placeholder;
} hmr_system_performance_orchestrator_t;

// Mock function declarations
hmr_distributed_error_recovery_t* hmr_create_distributed_error_recovery(void);
void hmr_destroy_distributed_error_recovery(hmr_distributed_error_recovery_t* recovery);

hmr_system_performance_orchestrator_t* hmr_create_system_performance_orchestrator(void);
void hmr_destroy_system_performance_orchestrator(hmr_system_performance_orchestrator_t* orchestrator);

bool hmr_dev_server_start(uint16_t port);
void hmr_dev_server_stop(void);

void hmr_metrics_init(void);
void hmr_metrics_cleanup(void);

void hmr_visual_feedback_init(void);
void hmr_visual_feedback_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif // SYSTEM_MOCKS_H
