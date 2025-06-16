// Mock implementations for missing dependencies
#include "system_mocks.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Mock distributed error recovery
hmr_distributed_error_recovery_t* hmr_create_distributed_error_recovery(void) {
    return calloc(1, sizeof(hmr_distributed_error_recovery_t));
}

void hmr_destroy_distributed_error_recovery(hmr_distributed_error_recovery_t* recovery) {
    if (recovery) free(recovery);
}

// Mock system performance orchestrator
hmr_system_performance_orchestrator_t* hmr_create_system_performance_orchestrator(void) {
    return calloc(1, sizeof(hmr_system_performance_orchestrator_t));
}

void hmr_destroy_system_performance_orchestrator(hmr_system_performance_orchestrator_t* orchestrator) {
    if (orchestrator) free(orchestrator);
}

// Mock development server
bool hmr_dev_server_start(uint16_t port) {
    printf("Mock: Development server started on port %u\n", port);
    return true;
}

void hmr_dev_server_stop(void) {
    printf("Mock: Development server stopped\n");
}

// Mock metrics
void hmr_metrics_init(void) {
    printf("Mock: Metrics system initialized\n");
}

void hmr_metrics_cleanup(void) {
    printf("Mock: Metrics system cleaned up\n");
}

// Mock visual feedback
void hmr_visual_feedback_init(void) {
    printf("Mock: Visual feedback system initialized\n");
}

void hmr_visual_feedback_cleanup(void) {
    printf("Mock: Visual feedback system cleaned up\n");
}
