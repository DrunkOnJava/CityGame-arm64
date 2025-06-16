// SimCity ARM64 Minimal Console Demo
// Core simulation without graphics

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <mach/mach_time.h>
#include <stdbool.h>

// Core engine includes
#include "core/memory_manager.h"
#include "simulation/entity_system.h"
#include "ai/ai_integration.h"

// Demo configuration  
#define INITIAL_CITIZEN_COUNT 100
#define INITIAL_VEHICLE_COUNT 50
#define CITY_WIDTH 100
#define CITY_HEIGHT 100

// Global state
static struct {
    bool simulation_running;
    uint64_t frame_count;
    double last_time;
    uint32_t active_citizens;
    uint32_t active_vehicles;
} g_demo_state = {0};

// Timing utilities
static uint64_t get_time_ns(void) {
    return mach_absolute_time();
}

static float get_delta_time(void) {
    static mach_timebase_info_data_t timebase_info = {0};
    if (timebase_info.denom == 0) {
        mach_timebase_info(&timebase_info);
    }
    
    uint64_t now = get_time_ns();
    static uint64_t last_time = 0;
    
    if (last_time == 0) {
        last_time = now;
        return 1.0f / 60.0f; // First frame default
    }
    
    uint64_t elapsed_ns = (now - last_time) * timebase_info.numer / timebase_info.denom;
    last_time = now;
    
    return (float)elapsed_ns / 1e9f;
}

// System initialization
static int init_systems(void) {
    printf("Initializing core systems...\n");
    
    // Initialize memory manager
    if (memory_manager_init() != 0) {
        printf("Failed to initialize memory manager\n");
        return -1;
    }
    
    // Initialize entity system
    if (entity_system_init() != 0) {
        printf("Failed to initialize entity system\n");
        return -1;
    }
    
    // Initialize AI system with dummy world data
    uint8_t world_tiles[CITY_WIDTH * CITY_HEIGHT];
    memset(world_tiles, 0, sizeof(world_tiles));
    
    if (ai_system_init(world_tiles, CITY_WIDTH, CITY_HEIGHT) != 0) {
        printf("Failed to initialize AI system\n");
        return -1;
    }
    
    printf("All systems initialized successfully\n");
    return 0;
}

static void shutdown_systems(void) {
    printf("Shutting down systems...\n");
    ai_system_shutdown();
    entity_system_shutdown();
    memory_manager_shutdown();
}

static void spawn_initial_population(void) {
    printf("Spawning initial population...\n");
    
    // Spawn citizens
    for (int i = 0; i < INITIAL_CITIZEN_COUNT; i++) {
        float x = (rand() % (CITY_WIDTH * 10)) / 10.0f;
        float y = (rand() % (CITY_HEIGHT * 10)) / 10.0f;
        ai_spawn_agent(i, 0, x, y); // Agent type 0 = citizen
        g_demo_state.active_citizens++;
    }
    
    // Spawn vehicles
    for (int i = INITIAL_CITIZEN_COUNT; i < INITIAL_CITIZEN_COUNT + INITIAL_VEHICLE_COUNT; i++) {
        float x = (rand() % (CITY_WIDTH * 10)) / 10.0f;
        float y = (rand() % (CITY_HEIGHT * 10)) / 10.0f;
        ai_spawn_agent(i, 1, x, y); // Agent type 1 = vehicle
        g_demo_state.active_vehicles++;
    }
    
    printf("Spawned %d citizens and %d vehicles\n", 
           g_demo_state.active_citizens, g_demo_state.active_vehicles);
}

static void update_simulation(float delta_time) {
    // Update entity system
    entity_system_update(delta_time);
    
    // Update AI system
    ai_system_update(delta_time);
}

//==============================================================================
// MAIN ENTRY POINT
//==============================================================================

int main(void) {
    printf("=== SimCity ARM64 Console Demo ===\n");
    fflush(stdout);
    printf("Target: %d citizens, %d vehicles in %dx%d city\n", 
           INITIAL_CITIZEN_COUNT, INITIAL_VEHICLE_COUNT, CITY_WIDTH, CITY_HEIGHT);
    fflush(stdout);
    
    // Seed random number generator
    srand((unsigned int)time(NULL));
    printf("Random seed initialized\n");
    fflush(stdout);
    
    // Initialize all systems
    printf("About to initialize systems...\n");
    fflush(stdout);
    if (init_systems() != 0) {
        fprintf(stderr, "Failed to initialize systems\n");
        fflush(stderr);
        return -1;
    }
    printf("Systems initialized successfully\n");
    fflush(stdout);
    
    // Spawn initial population
    printf("About to spawn population...\n");
    fflush(stdout);
    spawn_initial_population();
    printf("Population spawned successfully\n");
    fflush(stdout);
    
    printf("Demo initialized. Running simulation for 30 seconds...\n");
    fflush(stdout);
    
    // Initialize timing
    g_demo_state.simulation_running = true;
    
    // Console demo loop - run for 30 seconds
    int demo_frames = 30 * 60; // 30 seconds at 60 FPS
    for (int frame = 0; frame < demo_frames && g_demo_state.simulation_running; frame++) {
        // Calculate delta time
        float delta_time = get_delta_time();
        
        // Update simulation
        update_simulation(delta_time);
        
        // Print stats every 60 frames (1 second)
        if (frame % 60 == 0) {
            float fps = 1.0f / delta_time;
            int total_agents = g_demo_state.active_citizens + g_demo_state.active_vehicles;
            printf("Frame %d: %.1f FPS, %d active agents (%.1fs elapsed)\n", 
                   frame, fps, total_agents, frame / 60.0f);
        }
        
        g_demo_state.frame_count++;
        
        // Cap frame rate to 60 FPS
        usleep(16667); // ~16.67ms = 60 FPS
    }
    
    printf("\nDemo completed successfully!\n");
    
    // Print final performance stats
    printf("\nFinal Performance Statistics:\n");
    printf("Total frames: %llu\n", g_demo_state.frame_count);
    printf("Average FPS: %.1f\n", g_demo_state.frame_count / 30.0f);
    printf("Total agents: %d\n", g_demo_state.active_citizens + g_demo_state.active_vehicles);
    
    ai_print_performance_stats();
    
    // Cleanup
    shutdown_systems();
    
    printf("=== Demo Complete ===\n");
    return 0;
}