/*
 * SimCity ARM64 - HMR Main Loop Integration Example
 * Agent 3: Runtime Integration - Day 1 Integration Guide
 * 
 * Demonstrates how to integrate HMR manager with the main game loop
 * Shows proper frame timing, module watching, and error handling
 */

#include "hmr_manager.h"
#include "../include/interfaces/hmr_interfaces.h"
#include <stdio.h>
#include <stdbool.h>
#include <unistd.h>
#include <signal.h>

// =============================================================================
// Example Game State
// =============================================================================

typedef struct {
    bool running;
    uint32_t frame_count;
    float delta_time;
    
    // Example modules to watch
    char graphics_module_path[256];
    char simulation_module_path[256];
    char ai_module_path[256];
} game_state_t;

static game_state_t g_game_state = {0};
static volatile bool g_shutdown_requested = false;

// =============================================================================
// Signal Handling
// =============================================================================

void signal_handler(int sig) {
    printf("\nShutdown requested (signal %d)\n", sig);
    g_shutdown_requested = true;
}

// =============================================================================
// Game Loop Functions
// =============================================================================

bool initialize_game(void) {
    printf("Initializing SimCity ARM64...\n");
    
    // Initialize HMR manager first
    int result = hmr_manager_init();
    if (result != HMR_SUCCESS) {
        printf("ERROR: Failed to initialize HMR manager: %d\n", result);
        return false;
    }
    
    // Configure HMR for optimal performance
    hmr_manager_config_t hmr_config = {
        .check_interval_frames = 60,        // Check once per second at 60 FPS
        .max_frame_budget_ns = 100000ULL,   // 0.1ms budget per frame
        .adaptive_budgeting = true          // Reduce budget if frame times are high
    };
    
    result = hmr_manager_set_config(&hmr_config);
    if (result != HMR_SUCCESS) {
        printf("WARNING: Failed to configure HMR manager: %d\n", result);
    }
    
    // Set up module paths (these would be real paths in production)
    snprintf(g_game_state.graphics_module_path, sizeof(g_game_state.graphics_module_path),
             "build/graphics/libgraphics.dylib");
    snprintf(g_game_state.simulation_module_path, sizeof(g_game_state.simulation_module_path),
             "build/simulation/libsimulation.dylib");
    snprintf(g_game_state.ai_module_path, sizeof(g_game_state.ai_module_path),
             "build/ai/libai.dylib");
    
    // Add module watches
    hmr_manager_add_watch(g_game_state.graphics_module_path, "build/graphics");
    hmr_manager_add_watch(g_game_state.simulation_module_path, "build/simulation");
    hmr_manager_add_watch(g_game_state.ai_module_path, "build/ai");
    
    // Initialize other game systems here...
    // graphics_system_init();
    // simulation_system_init();
    // ai_system_init();
    
    g_game_state.running = true;
    g_game_state.frame_count = 0;
    
    printf("Game initialized successfully\n");
    return true;
}

void shutdown_game(void) {
    printf("Shutting down SimCity ARM64...\n");
    
    g_game_state.running = false;
    
    // Remove module watches
    hmr_manager_remove_watch(g_game_state.graphics_module_path);
    hmr_manager_remove_watch(g_game_state.simulation_module_path);
    hmr_manager_remove_watch(g_game_state.ai_module_path);
    
    // Shutdown HMR manager
    hmr_manager_shutdown();
    
    // Shutdown other game systems here...
    // ai_system_shutdown();
    // simulation_system_shutdown();
    // graphics_system_shutdown();
    
    printf("Game shutdown complete\n");
}

void update_game(float delta_time) {
    // Example game update logic
    g_game_state.delta_time = delta_time;
    
    // Update game systems here...
    // simulation_system_update(delta_time);
    // ai_system_update(delta_time);
    // physics_system_update(delta_time);
}

void render_game(void) {
    // Example rendering logic
    
    // graphics_system_render();
    // ui_system_render();
}

void print_hmr_status(void) {
    static uint32_t last_status_frame = 0;
    
    // Print status every 5 seconds
    if (g_game_state.frame_count - last_status_frame >= 300) {
        hmr_manager_metrics_t metrics;
        hmr_manager_get_metrics(&metrics);
        
        printf("HMR Status (Frame %u):\n", g_game_state.frame_count);
        printf("  Active watches: %u\n", metrics.active_watches);
        printf("  Total reloads: %llu\n", metrics.total_reloads);
        printf("  Average frame time: %.2f ms\n", metrics.avg_frame_time_ns / 1000000.0);
        printf("  HMR overhead: %.3f ms total\n", metrics.hmr_overhead_ns / 1000000.0);
        
        if (metrics.total_reloads > 0) {
            printf("  ✓ Hot-reload functionality is working!\n");
        }
        
        last_status_frame = g_game_state.frame_count;
    }
}

// =============================================================================
// Main Game Loop
// =============================================================================

void run_game_loop(void) {
    printf("Starting main game loop...\n");
    printf("Press Ctrl+C to exit\n");
    
    const uint32_t target_fps = 60;
    const uint32_t frame_time_us = 1000000 / target_fps; // 16.67ms in microseconds
    
    while (g_game_state.running && !g_shutdown_requested) {
        g_game_state.frame_count++;
        
        // Use HMR frame scope for automatic timing
        HMR_FRAME_SCOPE(g_game_state.frame_count) {
            
            // 1. Check for module reloads (within frame budget)
            HMR_CHECK_RELOADS_OR_CONTINUE();
            
            // 2. Update game logic
            update_game(1.0f / target_fps);
            
            // 3. Render frame
            render_game();
            
            // 4. Print periodic status
            print_hmr_status();
        }
        
        // Frame rate limiting (simple approach)
        usleep(frame_time_us);
    }
    
    printf("Game loop ended\n");
}

// =============================================================================
// Alternative Integration Pattern (Manual)
// =============================================================================

void run_game_loop_manual(void) {
    printf("Starting manual integration game loop...\n");
    
    const uint32_t target_fps = 60;
    const uint32_t frame_time_us = 1000000 / target_fps;
    
    while (g_game_state.running && !g_shutdown_requested) {
        g_game_state.frame_count++;
        
        // Manual frame timing
        hmr_manager_frame_start(g_game_state.frame_count);
        
        // Check for module reloads with error handling
        int hmr_result = hmr_manager_check_reloads();
        if (hmr_result == HMR_ERROR_BUDGET_EXCEEDED) {
            // Budget exceeded - this is normal under heavy load
            printf("Frame %u: HMR budget exceeded\n", g_game_state.frame_count);
        } else if (hmr_result != HMR_SUCCESS) {
            // Other error - log but continue
            printf("Frame %u: HMR error %d\n", g_game_state.frame_count, hmr_result);
        }
        
        // Game update and render
        update_game(1.0f / target_fps);
        render_game();
        print_hmr_status();
        
        // End frame timing
        hmr_manager_frame_end();
        
        // Frame rate limiting
        usleep(frame_time_us);
    }
    
    printf("Manual game loop ended\n");
}

// =============================================================================
// HMR Control Functions
// =============================================================================

void toggle_hmr(void) {
    bool enabled = hmr_manager_is_enabled();
    hmr_manager_set_enabled(!enabled);
    printf("HMR %s\n", !enabled ? "enabled" : "disabled");
}

void pause_hmr(void) {
    bool paused = hmr_manager_is_paused();
    hmr_manager_set_paused(!paused);
    printf("HMR %s\n", !paused ? "paused" : "resumed");
}

void print_hmr_config(void) {
    hmr_manager_config_t config;
    hmr_manager_get_config(&config);
    
    printf("HMR Configuration:\n");
    printf("  Check interval: %u frames\n", config.check_interval_frames);
    printf("  Frame budget: %llu ns (%.3f ms)\n", 
           config.max_frame_budget_ns, config.max_frame_budget_ns / 1000000.0);
    printf("  Adaptive budgeting: %s\n", config.adaptive_budgeting ? "enabled" : "disabled");
}

// =============================================================================
// Main Function
// =============================================================================

int main(int argc, char* argv[]) {
    printf("SimCity ARM64 - HMR Integration Example\n");
    printf("======================================\n");
    
    // Set up signal handling
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    // Initialize game
    if (!initialize_game()) {
        printf("Failed to initialize game\n");
        return 1;
    }
    
    // Print initial configuration
    print_hmr_config();
    
    // Choose integration pattern based on command line argument
    if (argc > 1 && strcmp(argv[1], "manual") == 0) {
        printf("Using manual integration pattern\n");
        run_game_loop_manual();
    } else {
        printf("Using macro integration pattern\n");
        run_game_loop();
    }
    
    // Shutdown
    shutdown_game();
    
    return 0;
}

// =============================================================================
// Usage Examples and Documentation
// =============================================================================

/*
 * INTEGRATION PATTERNS
 * ====================
 * 
 * Pattern 1: Macro-based (Recommended)
 * -------------------------------------
 * HMR_FRAME_SCOPE(frame_number) {
 *     HMR_CHECK_RELOADS_OR_CONTINUE();
 *     // ... game logic ...
 * }
 * 
 * Benefits:
 * - Automatic frame timing
 * - Exception-safe cleanup
 * - Minimal boilerplate
 * 
 * Pattern 2: Manual Control
 * -------------------------
 * hmr_manager_frame_start(frame_number);
 * int result = hmr_manager_check_reloads();
 * // ... handle result ...
 * // ... game logic ...
 * hmr_manager_frame_end();
 * 
 * Benefits:
 * - Full control over error handling
 * - Custom frame timing logic
 * - Better for complex scenarios
 * 
 * PERFORMANCE CONSIDERATIONS
 * ==========================
 * 
 * 1. Frame Budget: Set appropriate budget based on target FPS
 *    - 60 FPS: 0.1ms budget (100,000 ns)
 *    - 30 FPS: 0.2ms budget (200,000 ns)
 * 
 * 2. Check Interval: Balance responsiveness vs. overhead
 *    - Responsive: Every 30 frames (0.5 sec at 60 FPS)
 *    - Conservative: Every 120 frames (2 sec at 60 FPS)
 * 
 * 3. Adaptive Budgeting: Enable for variable frame rates
 *    - Automatically reduces budget under load
 *    - Prevents HMR from affecting performance
 * 
 * DEBUGGING TIPS
 * ==============
 * 
 * 1. Use hmr_manager_get_metrics() to monitor performance
 * 2. Watch for budget exceeded errors (normal under load)
 * 3. Monitor avg_frame_time_ns to ensure 60+ FPS
 * 4. Check active_watches to verify file monitoring
 * 
 */