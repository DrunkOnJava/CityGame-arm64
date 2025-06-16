/*
 * SimCity ARM64 - HMR Integration Example
 * Agent 3: Runtime Integration - Day 1 Integration
 * 
 * Demonstrates how to integrate HMR with the existing SimCity main loop
 * Shows proper setup, configuration, and integration patterns
 */

#include "runtime_integration.h"
#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>

// Example SimCity game state
typedef struct {
    bool running;
    uint32_t frame_count;
    float simulation_speed;
    
    // Example systems
    bool graphics_system_active;
    bool simulation_system_active;
    bool ai_system_active;
} simcity_state_t;

static simcity_state_t g_game_state = {0};
static volatile bool g_shutdown_requested = false;

// Signal handler for clean shutdown
void signal_handler(int sig) {
    printf("\nShutdown requested (signal %d)\n", sig);
    g_shutdown_requested = true;
}

// Initialize SimCity with HMR support
bool simcity_init_with_hmr(void) {
    printf("Initializing SimCity ARM64 with HMR support...\n");
    
    // Initialize HMR first
    int result = hmr_rt_init();
    if (result != HMR_RT_SUCCESS) {
        printf("ERROR: Failed to initialize HMR: %d\n", result);
        return false;
    }
    
    // Configure HMR for optimal performance
    hmr_rt_config_t hmr_config = {
        .check_interval_frames = 60,        // Check once per second at 60 FPS
        .max_frame_budget_ns = 100000ULL,   // 0.1ms budget
        .adaptive_budgeting = true          // Reduce budget under load
    };
    
    result = hmr_rt_set_config(&hmr_config);
    if (result != HMR_RT_SUCCESS) {
        printf("WARNING: Failed to configure HMR: %d\n", result);
    }
    
    // Add watches for key modules
    hmr_rt_add_watch("build/graphics/libgraphics.dylib", "build/graphics");
    hmr_rt_add_watch("build/simulation/libsimulation.dylib", "build/simulation");
    hmr_rt_add_watch("build/ai/libai.dylib", "build/ai");
    
    // Initialize game systems (stubs for example)
    g_game_state.graphics_system_active = true;
    g_game_state.simulation_system_active = true;
    g_game_state.ai_system_active = true;
    g_game_state.simulation_speed = 1.0f;
    g_game_state.running = true;
    
    printf("SimCity initialization complete\n");
    return true;
}

// Shutdown SimCity with HMR cleanup
void simcity_shutdown_with_hmr(void) {
    printf("Shutting down SimCity ARM64...\n");
    
    g_game_state.running = false;
    
    // Remove HMR watches
    hmr_rt_remove_watch("build/graphics/libgraphics.dylib");
    hmr_rt_remove_watch("build/simulation/libsimulation.dylib");
    hmr_rt_remove_watch("build/ai/libai.dylib");
    
    // Shutdown HMR
    hmr_rt_shutdown();
    
    printf("Shutdown complete\n");
}

// Example game update function
void simcity_update(float delta_time) {
    // Example update logic
    g_game_state.frame_count++;
    
    // Update simulation at configured speed
    float scaled_delta = delta_time * g_game_state.simulation_speed;
    
    // Update systems (stubs)
    if (g_game_state.simulation_system_active) {
        // simulation_system_update(scaled_delta);
    }
    
    if (g_game_state.ai_system_active) {
        // ai_system_update(scaled_delta);
    }
}

// Example rendering function
void simcity_render(void) {
    // Example rendering logic
    if (g_game_state.graphics_system_active) {
        // graphics_system_render();
        // ui_system_render();
    }
}

// Print HMR status periodically
void print_hmr_status(void) {
    static uint32_t last_status_frame = 0;
    
    // Print status every 5 seconds
    if (g_game_state.frame_count - last_status_frame >= 300) {
        hmr_rt_metrics_t metrics;
        hmr_rt_get_metrics(&metrics);
        
        printf("Frame %u - HMR Status:\n", g_game_state.frame_count);
        printf("  Active watches: %u\n", metrics.active_watches);
        printf("  Total reloads: %llu\n", metrics.total_reloads);
        printf("  Avg frame time: %.2f ms\n", metrics.avg_frame_time_ns / 1000000.0);
        printf("  HMR overhead: %.3f μs per frame\n", 
               metrics.hmr_overhead_ns / 1000.0 / g_game_state.frame_count);
        
        if (metrics.total_reloads > 0) {
            printf("  ✓ Hot-reload is working!\n");
        }
        
        last_status_frame = g_game_state.frame_count;
    }
}

// Main game loop with HMR integration (using macro pattern)
void simcity_run_with_hmr_macros(void) {
    printf("Starting SimCity main loop (macro integration)...\n");
    printf("Press Ctrl+C to exit\n");
    
    const uint32_t target_fps = 60;
    const uint32_t frame_time_us = 1000000 / target_fps;
    
    while (g_game_state.running && !g_shutdown_requested) {
        // HMR-integrated frame loop
        HMR_RT_FRAME_SCOPE(g_game_state.frame_count + 1) {
            
            // Check for module reloads
            HMR_RT_CHECK_RELOADS_OR_CONTINUE();
            
            // Update game
            simcity_update(1.0f / target_fps);
            
            // Render frame
            simcity_render();
            
            // Print status
            print_hmr_status();
        }
        
        // Frame rate limiting
        usleep(frame_time_us);
    }
    
    printf("Game loop ended\n");
}

// Main game loop with manual HMR integration
void simcity_run_with_hmr_manual(void) {
    printf("Starting SimCity main loop (manual integration)...\n");
    printf("Press Ctrl+C to exit\n");
    
    const uint32_t target_fps = 60;
    const uint32_t frame_time_us = 1000000 / target_fps;
    
    while (g_game_state.running && !g_shutdown_requested) {
        g_game_state.frame_count++;
        
        // Manual HMR frame timing
        hmr_rt_frame_start(g_game_state.frame_count);
        
        // Check for module reloads with custom error handling
        int hmr_result = hmr_rt_check_reloads();
        if (hmr_result == HMR_RT_ERROR_BUDGET_EXCEEDED) {
            // Budget exceeded - normal under heavy load
            printf("Frame %u: HMR budget exceeded (system under load)\n", 
                   g_game_state.frame_count);
        } else if (hmr_result != HMR_RT_SUCCESS) {
            // Other error - log but continue
            printf("Frame %u: HMR error %d\n", g_game_state.frame_count, hmr_result);
        }
        
        // Game update and render
        simcity_update(1.0f / target_fps);
        simcity_render();
        print_hmr_status();
        
        // End HMR frame timing
        hmr_rt_frame_end();
        
        // Frame rate limiting
        usleep(frame_time_us);
    }
    
    printf("Game loop ended\n");
}

// HMR control functions for runtime management
void toggle_hmr(void) {
    bool enabled = hmr_rt_is_enabled();
    hmr_rt_set_enabled(!enabled);
    printf("HMR %s\n", !enabled ? "enabled" : "disabled");
}

void pause_hmr(void) {
    bool paused = hmr_rt_is_paused();
    hmr_rt_set_paused(!paused);
    printf("HMR %s\n", !paused ? "paused" : "resumed");
}

void print_hmr_configuration(void) {
    hmr_rt_config_t config;
    hmr_rt_get_config(&config);
    
    printf("Current HMR Configuration:\n");
    printf("  Check interval: %u frames (%.1f sec at 60 FPS)\n", 
           config.check_interval_frames, config.check_interval_frames / 60.0f);
    printf("  Frame budget: %llu ns (%.3f ms)\n", 
           config.max_frame_budget_ns, config.max_frame_budget_ns / 1000000.0);
    printf("  Adaptive budgeting: %s\n", config.adaptive_budgeting ? "enabled" : "disabled");
}

int main(int argc, char* argv[]) {
    printf("SimCity ARM64 - HMR Integration Example\n");
    printf("======================================\n");
    
    // Set up signal handling
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    // Initialize
    if (!simcity_init_with_hmr()) {
        printf("Failed to initialize SimCity with HMR\n");
        return 1;
    }
    
    // Print configuration
    print_hmr_configuration();
    
    // Choose integration pattern
    if (argc > 1 && strcmp(argv[1], "manual") == 0) {
        simcity_run_with_hmr_manual();
    } else {
        simcity_run_with_hmr_macros();
    }
    
    // Shutdown
    simcity_shutdown_with_hmr();
    
    return 0;
}

/*
 * USAGE GUIDE
 * ===========
 * 
 * Compile and run:
 *   clang -pthread runtime_integration.c simcity_hmr_integration_example.c -o simcity_hmr
 *   ./simcity_hmr
 *   ./simcity_hmr manual
 * 
 * Key Integration Points:
 * 1. Initialize HMR before any other systems
 * 2. Configure for your target frame rate and performance needs
 * 3. Add watches for modules you want to hot-reload
 * 4. Use either macro or manual integration in your main loop
 * 5. Clean up HMR during shutdown
 * 
 * Performance Tips:
 * - Use adaptive budgeting for variable frame rates
 * - Adjust check interval based on development vs. production needs
 * - Monitor metrics to ensure HMR isn't impacting performance
 * - Consider disabling HMR in final release builds
 * 
 * Integration with Existing SimCity Codebase:
 * 1. Add HMR initialization to main.c or main_window.m
 * 2. Add watches for core modules (graphics, simulation, ai)
 * 3. Integrate frame timing in main render loop
 * 4. Add HMR status to debug UI/overlay
 * 
 */