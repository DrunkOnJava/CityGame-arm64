// SimCity ARM64 Enhanced Prototype
// Full-scale simulation with performance monitoring and city layout

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

// Enhanced prototype configuration
#define INITIAL_CITIZEN_COUNT 800
#define INITIAL_VEHICLE_COUNT 200
#define CITY_WIDTH 100
#define CITY_HEIGHT 100
#define SIMULATION_DURATION_SECONDS 60
#define PERFORMANCE_REPORT_INTERVAL 120  // Every 2 seconds at 60 FPS

// City layout constants
#define ROAD_WIDTH 4
#define BLOCK_SIZE 20
#define BUILDING_DENSITY 0.6f

// Performance tracking
typedef struct {
    uint64_t total_frames;
    double total_time;
    float min_fps;
    float max_fps;
    float avg_fps;
    uint64_t frame_times[120];  // Last 2 seconds of frame times
    int frame_time_index;
} PerformanceStats;

// Global state
static struct {
    bool simulation_running;
    uint64_t frame_count;
    double last_time;
    uint32_t active_citizens;
    uint32_t active_vehicles;
    
    // City layout
    uint8_t* city_map;  // 0=empty, 1=road, 2=building, 3=spawn_point
    uint32_t spawn_points[20][2];  // [x,y] coordinates
    uint32_t num_spawn_points;
    
    // Performance monitoring
    PerformanceStats perf_stats;
} g_prototype_state = {0};

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

// City layout generation
static void generate_city_layout(void) {
    printf("Generating city layout %dx%d...\n", CITY_WIDTH, CITY_HEIGHT);
    fflush(stdout);
    
    // Allocate city map
    g_prototype_state.city_map = calloc(CITY_WIDTH * CITY_HEIGHT, sizeof(uint8_t));
    if (!g_prototype_state.city_map) {
        fprintf(stderr, "Failed to allocate city map\n");
        return;
    }
    
    // Generate road grid
    for (int y = 0; y < CITY_HEIGHT; y++) {
        for (int x = 0; x < CITY_WIDTH; x++) {
            int index = y * CITY_WIDTH + x;
            
            // Create roads every BLOCK_SIZE units
            if (x % BLOCK_SIZE < ROAD_WIDTH || y % BLOCK_SIZE < ROAD_WIDTH) {
                g_prototype_state.city_map[index] = 1; // Road
            } else {
                // Place buildings with some probability
                if ((rand() % 100) < (int)(BUILDING_DENSITY * 100)) {
                    g_prototype_state.city_map[index] = 2; // Building
                }
            }
        }
    }
    
    // Create spawn points at road intersections
    g_prototype_state.num_spawn_points = 0;
    for (int y = ROAD_WIDTH; y < CITY_HEIGHT - ROAD_WIDTH; y += BLOCK_SIZE) {
        for (int x = ROAD_WIDTH; x < CITY_WIDTH - ROAD_WIDTH; x += BLOCK_SIZE) {
            if (g_prototype_state.num_spawn_points < 20) {
                g_prototype_state.spawn_points[g_prototype_state.num_spawn_points][0] = x;
                g_prototype_state.spawn_points[g_prototype_state.num_spawn_points][1] = y;
                g_prototype_state.num_spawn_points++;
                
                // Mark as spawn point
                int index = y * CITY_WIDTH + x;
                g_prototype_state.city_map[index] = 3;
            }
        }
    }
    
    printf("City layout generated: %d roads, %d buildings, %d spawn points\n",
           CITY_WIDTH * CITY_HEIGHT / 5, // Rough estimate
           (int)(CITY_WIDTH * CITY_HEIGHT * BUILDING_DENSITY),
           g_prototype_state.num_spawn_points);
    fflush(stdout);
}

// System initialization
static int init_systems(void) {
    printf("Initializing enhanced prototype systems...\n");
    fflush(stdout);
    
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
    
    // Initialize AI system with city layout
    generate_city_layout();
    
    if (ai_system_init(g_prototype_state.city_map, CITY_WIDTH, CITY_HEIGHT) != 0) {
        printf("Failed to initialize AI system\n");
        return -1;
    }
    
    printf("All systems initialized successfully\n");
    fflush(stdout);
    return 0;
}

static void shutdown_systems(void) {
    printf("Shutting down enhanced prototype systems...\n");
    fflush(stdout);
    
    ai_system_shutdown();
    entity_system_shutdown();
    memory_manager_shutdown();
    
    if (g_prototype_state.city_map) {
        free(g_prototype_state.city_map);
        g_prototype_state.city_map = NULL;
    }
}

// Enhanced population spawning with city layout awareness
static void spawn_initial_population(void) {
    printf("Spawning enhanced population: %d citizens, %d vehicles...\n",
           INITIAL_CITIZEN_COUNT, INITIAL_VEHICLE_COUNT);
    fflush(stdout);
    
    // Spawn citizens at spawn points and road locations
    for (int i = 0; i < INITIAL_CITIZEN_COUNT; i++) {
        float x, y;
        
        // 70% spawn at designated spawn points, 30% on random roads
        if ((rand() % 100) < 70 && g_prototype_state.num_spawn_points > 0) {
            int spawn_idx = rand() % g_prototype_state.num_spawn_points;
            x = (float)g_prototype_state.spawn_points[spawn_idx][0] + (rand() % 5 - 2);
            y = (float)g_prototype_state.spawn_points[spawn_idx][1] + (rand() % 5 - 2);
        } else {
            // Find a road location
            int index;
            do {
                x = (float)(rand() % CITY_WIDTH);
                y = (float)(rand() % CITY_HEIGHT);
                index = (int)y * CITY_WIDTH + (int)x;
            } while (g_prototype_state.city_map[index] != 1); // Must be on road
        }
        
        ai_spawn_agent(i, 0, x, y); // Agent type 0 = citizen
        g_prototype_state.active_citizens++;
    }
    
    // Spawn vehicles on roads
    for (int i = INITIAL_CITIZEN_COUNT; i < INITIAL_CITIZEN_COUNT + INITIAL_VEHICLE_COUNT; i++) {
        float x, y;
        
        // Vehicles always spawn on roads
        int index;
        do {
            x = (float)(rand() % CITY_WIDTH);
            y = (float)(rand() % CITY_HEIGHT);
            index = (int)y * CITY_WIDTH + (int)x;
        } while (g_prototype_state.city_map[index] != 1); // Must be on road
        
        ai_spawn_agent(i, 1, x, y); // Agent type 1 = vehicle
        g_prototype_state.active_vehicles++;
    }
    
    printf("Population spawned: %d citizens, %d vehicles (total: %d agents)\n",
           g_prototype_state.active_citizens, g_prototype_state.active_vehicles,
           g_prototype_state.active_citizens + g_prototype_state.active_vehicles);
    fflush(stdout);
}

// Performance monitoring
static void update_performance_stats(float delta_time) {
    PerformanceStats* stats = &g_prototype_state.perf_stats;
    
    float current_fps = 1.0f / delta_time;
    
    // Update frame times ring buffer
    stats->frame_times[stats->frame_time_index] = (uint64_t)(delta_time * 1e9f);
    stats->frame_time_index = (stats->frame_time_index + 1) % 120;
    
    // Update min/max FPS
    if (stats->total_frames == 0) {
        stats->min_fps = stats->max_fps = current_fps;
    } else {
        if (current_fps < stats->min_fps) stats->min_fps = current_fps;
        if (current_fps > stats->max_fps) stats->max_fps = current_fps;
    }
    
    // Update running averages
    stats->total_frames++;
    stats->total_time += delta_time;
    stats->avg_fps = stats->total_frames / stats->total_time;
}

static void print_performance_report(void) {
    PerformanceStats* stats = &g_prototype_state.perf_stats;
    
    // Calculate recent FPS (last 2 seconds)
    float recent_total_time = 0.0f;
    for (int i = 0; i < 120; i++) {
        recent_total_time += stats->frame_times[i] / 1e9f;
    }
    float recent_fps = 120.0f / recent_total_time;
    
    printf("\n=== Performance Report (Frame %llu) ===\n", g_prototype_state.frame_count);
    printf("Current FPS: %.1f | Recent FPS: %.1f | Average FPS: %.1f\n",
           1.0f / (recent_total_time / 120.0f), recent_fps, stats->avg_fps);
    printf("FPS Range: %.1f - %.1f | Total Runtime: %.1fs\n",
           stats->min_fps, stats->max_fps, stats->total_time);
    printf("Active Agents: %d citizens + %d vehicles = %d total\n",
           g_prototype_state.active_citizens, g_prototype_state.active_vehicles,
           g_prototype_state.active_citizens + g_prototype_state.active_vehicles);
    printf("==========================================\n");
    fflush(stdout);
}

static void update_simulation(float delta_time) {
    // Update entity system
    entity_system_update(delta_time);
    
    // Update AI system
    ai_system_update(delta_time);
    
    // Update performance monitoring
    update_performance_stats(delta_time);
}

//==============================================================================
// MAIN ENTRY POINT
//==============================================================================

int main(void) {
    printf("=== SimCity ARM64 Enhanced Prototype ===\n");
    printf("Target: %d citizens, %d vehicles in %dx%d city\n", 
           INITIAL_CITIZEN_COUNT, INITIAL_VEHICLE_COUNT, CITY_WIDTH, CITY_HEIGHT);
    printf("Simulation Duration: %d seconds\n", SIMULATION_DURATION_SECONDS);
    fflush(stdout);
    
    // Seed random number generator
    srand((unsigned int)time(NULL));
    
    // Initialize all systems
    if (init_systems() != 0) {
        fprintf(stderr, "Failed to initialize systems\n");
        fflush(stderr);
        return -1;
    }
    
    // Spawn initial population with city layout awareness
    spawn_initial_population();
    
    printf("\nStarting enhanced simulation...\n");
    fflush(stdout);
    
    // Initialize timing
    g_prototype_state.simulation_running = true;
    
    // Enhanced simulation loop
    int demo_frames = SIMULATION_DURATION_SECONDS * 60; // Target 60 FPS
    for (int frame = 0; frame < demo_frames && g_prototype_state.simulation_running; frame++) {
        // Calculate delta time
        float delta_time = get_delta_time();
        
        // Update simulation
        update_simulation(delta_time);
        
        // Print performance reports periodically
        if (frame % PERFORMANCE_REPORT_INTERVAL == 0 && frame > 0) {
            print_performance_report();
        }
        
        g_prototype_state.frame_count++;
        
        // Cap frame rate to 60 FPS
        usleep(16667); // ~16.67ms = 60 FPS
    }
    
    printf("\n=== Enhanced Prototype Completed Successfully! ===\n");
    
    // Print final comprehensive statistics
    printf("\nFinal Performance Summary:\n");
    print_performance_report();
    
    printf("\nAI System Statistics:\n");
    ai_print_performance_stats();
    
    printf("\nCity Layout Summary:\n");
    printf("Map size: %dx%d (%d total cells)\n", CITY_WIDTH, CITY_HEIGHT, CITY_WIDTH * CITY_HEIGHT);
    printf("Spawn points: %d\n", g_prototype_state.num_spawn_points);
    printf("Population density: %.2f agents per cell\n",
           (float)(g_prototype_state.active_citizens + g_prototype_state.active_vehicles) / (CITY_WIDTH * CITY_HEIGHT));
    
    // Cleanup
    shutdown_systems();
    
    printf("\n=== Enhanced Prototype Complete ===\n");
    return 0;
}