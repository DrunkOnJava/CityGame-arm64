/*
 * SimCity ARM64 - HMR System Demonstration
 * Simple demonstration of HMR developer tools functionality
 * 
 * Agent 4: Developer Tools & Debug Interface
 * Day 5: Integration & Testing - Quick Demo
 */

#include "dev_server.h"
#include "metrics.h"
#include "visual_feedback.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>

static bool g_demo_running = false;

static void signal_handler(int sig) {
    (void)sig;
    printf("\n[HMR Demo] Shutting down...\n");
    g_demo_running = false;
}

int main(void) {
    printf("==============================================\n");
    printf("SimCity ARM64 - HMR System Demo\n");
    printf("Agent 4: Developer Tools & Debug Interface\n");
    printf("==============================================\n\n");
    
    // Set up signal handling
    signal(SIGINT, signal_handler);
    
    // Initialize systems
    printf("[HMR Demo] Initializing systems...\n");
    
    if (hmr_metrics_init() != HMR_SUCCESS) {
        printf("Failed to initialize metrics\n");
        return 1;
    }
    
    if (hmr_metrics_start() != HMR_SUCCESS) {
        printf("Failed to start metrics\n");
        return 1;
    }
    
    if (hmr_visual_feedback_init(1920, 1080) != HMR_SUCCESS) {
        printf("Failed to initialize visual feedback\n");
        return 1;
    }
    
    if (hmr_dev_server_init(8080) != HMR_SUCCESS) {
        printf("Failed to initialize dev server\n");
        return 1;
    }
    
    printf("✅ All systems initialized successfully!\n\n");
    
    // Register some test modules
    const char* modules[] = {"graphics", "simulation", "ai", "memory"};
    for (int i = 0; i < 4; i++) {
        hmr_metrics_register_module(modules[i]);
    }
    
    printf("Dashboard available at: http://localhost:8080/\n");
    printf("WebSocket endpoint: ws://localhost:8080/ws\n\n");
    
    printf("Running demo (press Ctrl+C to stop)...\n");
    g_demo_running = true;
    
    int cycle = 0;
    while (g_demo_running) {
        cycle++;
        printf("\n--- Demo Cycle %d ---\n", cycle);
        
        // Simulate build events
        for (int i = 0; i < 4; i++) {
            if (!g_demo_running) break;
            
            const char* module = modules[i];
            
            // Build start
            printf("Building %s...\n", module);
            hmr_metrics_build_start(module);
            hmr_visual_notify_build_start(module);
            
            sleep(1);
            
            // Build success (90% of the time)
            if (rand() % 10 < 9) {
                hmr_metrics_build_complete(module, true);
                hmr_visual_notify_build_success(module, 1000 + rand() % 2000);
                printf("✅ %s built successfully\n", module);
            } else {
                hmr_metrics_build_complete(module, false);
                hmr_visual_notify_build_error(module, "Simulated build error");
                printf("❌ %s build failed\n", module);
            }
            
            sleep(1);
        }
        
        // Update performance metrics
        hmr_metrics_record_frame_time(16666667); // ~60 FPS
        for (int i = 0; i < 4; i++) {
            hmr_metrics_record_memory_usage(modules[i], 64 * 1024 * 1024); // 64MB each
        }
        
        // Update visual feedback
        hmr_visual_feedback_update(0.016f);
        
        printf("Cycle %d complete\n", cycle);
        
        if (g_demo_running) {
            sleep(5);
        }
    }
    
    // Shutdown
    printf("\n[HMR Demo] Shutting down systems...\n");
    hmr_dev_server_shutdown();
    hmr_visual_feedback_shutdown();
    hmr_metrics_shutdown();
    
    printf("Demo complete!\n");
    return 0;
}