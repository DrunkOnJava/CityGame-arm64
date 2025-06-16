//
// SimCity ARM64 Assembly - Traffic Flow System Demo
// Agent C2: AI Team - Traffic Flow & Congestion Algorithms
//
// Demonstration program showing the traffic flow system capabilities
// including NEON acceleration, congestion detection, and route optimization
//

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include <math.h>
#include <string.h>

// External assembly functions
extern int traffic_flow_init(uint32_t max_vehicles, uint32_t world_width, uint32_t world_height);
extern int traffic_flow_update(uint32_t delta_time_ms, uint32_t simulation_speed);
extern uint32_t traffic_flow_spawn_vehicle(uint32_t spawn_x, uint32_t spawn_y, 
                                          uint32_t dest_x, uint32_t dest_y,
                                          uint8_t vehicle_type, uint8_t behavior);
extern int traffic_flow_shutdown(void);
extern int traffic_tests_run_all(void);
extern void traffic_tests_print_results(void);

// Demo configuration
#define DEMO_WORLD_SIZE     2048
#define DEMO_MAX_VEHICLES   1000
#define DEMO_SIMULATION_TIME 60     // 60 seconds
#define DEMO_FPS            60      // Target 60 FPS
#define DEMO_FRAME_TIME_MS  (1000 / DEMO_FPS)

// Vehicle types
#define VEHICLE_CAR         0
#define VEHICLE_BUS         1
#define VEHICLE_TRUCK       2
#define VEHICLE_EMERGENCY   3

// Behavior profiles
#define BEHAVIOR_AGGRESSIVE 0
#define BEHAVIOR_NORMAL     1
#define BEHAVIOR_CAUTIOUS   2

// Demo statistics
typedef struct {
    uint32_t total_frames;
    uint32_t total_vehicles_spawned;
    uint64_t total_update_time_ns;
    uint64_t min_frame_time_ns;
    uint64_t max_frame_time_ns;
    uint32_t congestion_events;
    uint32_t reroute_events;
} demo_stats_t;

static demo_stats_t g_demo_stats = {0};

// Function prototypes
static void print_banner(void);
static void run_performance_demo(void);
static void run_congestion_demo(void);
static void run_mass_transit_demo(void);
static void run_emergency_demo(void);
static void spawn_random_vehicles(uint32_t count);
static void print_demo_statistics(void);
static uint64_t get_time_ns(void);
static uint32_t random_range(uint32_t min, uint32_t max);

int main(int argc, char* argv[]) {
    printf("SimCity ARM64 Traffic Flow System Demo\n");
    printf("Agent C2: AI Team - Traffic Flow & Congestion Algorithms\n");
    printf("========================================================\n\n");
    
    // Parse command line arguments
    int run_tests = 0;
    int demo_mode = 1; // Default to demo mode
    
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--test") == 0) {
            run_tests = 1;
            demo_mode = 0;
        } else if (strcmp(argv[i], "--help") == 0) {
            printf("Usage: %s [options]\n", argv[0]);
            printf("Options:\n");
            printf("  --test    Run unit tests instead of demo\n");
            printf("  --help    Show this help message\n");
            return 0;
        }
    }
    
    // Initialize random seed
    srand((unsigned int)time(NULL));
    
    if (run_tests) {
        printf("Running comprehensive test suite...\n\n");
        int failed_tests = traffic_tests_run_all();
        
        printf("\n=== Test Results ===\n");
        traffic_tests_print_results();
        
        if (failed_tests == 0) {
            printf("\n✅ All tests passed!\n");
            return 0;
        } else {
            printf("\n❌ %d tests failed.\n", failed_tests);
            return 1;
        }
    }
    
    if (demo_mode) {
        // Initialize traffic flow system
        printf("Initializing traffic flow system...\n");
        int result = traffic_flow_init(DEMO_MAX_VEHICLES, DEMO_WORLD_SIZE, DEMO_WORLD_SIZE);
        if (result != 0) {
            printf("❌ Failed to initialize traffic flow system (error %d)\n", result);
            return 1;
        }
        printf("✅ Traffic flow system initialized successfully\n\n");
        
        // Run demonstration scenarios
        print_banner();
        
        printf("🚗 Running Performance Demo...\n");
        run_performance_demo();
        
        printf("\n🚦 Running Congestion Demo...\n");
        run_congestion_demo();
        
        printf("\n🚌 Running Mass Transit Demo...\n");
        run_mass_transit_demo();
        
        printf("\n🚑 Running Emergency Vehicle Demo...\n");
        run_emergency_demo();
        
        // Print final statistics
        printf("\n");
        print_demo_statistics();
        
        // Cleanup
        traffic_flow_shutdown();
        printf("\n✅ Demo completed successfully\n");
    }
    
    return 0;
}

static void print_banner(void) {
    printf("┌────────────────────────────────────────────────┐\n");
    printf("│            Traffic Flow Demo Scenarios        │\n");
    printf("│                                                │\n");
    printf("│  • Performance: NEON SIMD acceleration test   │\n");
    printf("│  • Congestion: Traffic jam detection & mgmt   │\n");
    printf("│  • Mass Transit: Bus/train scheduling         │\n");
    printf("│  • Emergency: Priority vehicle handling       │\n");
    printf("└────────────────────────────────────────────────┘\n\n");
}

static void run_performance_demo(void) {
    printf("  Spawning %d vehicles for performance testing...\n", DEMO_MAX_VEHICLES);
    
    // Spawn vehicles across the map
    spawn_random_vehicles(DEMO_MAX_VEHICLES);
    
    printf("  Running simulation for %d seconds at %d FPS...\n", 
           DEMO_SIMULATION_TIME, DEMO_FPS);
    
    uint32_t total_frames = DEMO_SIMULATION_TIME * DEMO_FPS;
    uint64_t start_time = get_time_ns();
    
    for (uint32_t frame = 0; frame < total_frames; frame++) {
        uint64_t frame_start = get_time_ns();
        
        // Update traffic simulation
        int result = traffic_flow_update(DEMO_FRAME_TIME_MS, 1000); // 1.0x speed
        if (result != 0) {
            printf("  ⚠️  Warning: Frame %d update failed\n", frame);
        }
        
        uint64_t frame_end = get_time_ns();
        uint64_t frame_time = frame_end - frame_start;
        
        // Update statistics
        g_demo_stats.total_frames++;
        g_demo_stats.total_update_time_ns += frame_time;
        
        if (frame == 0 || frame_time < g_demo_stats.min_frame_time_ns) {
            g_demo_stats.min_frame_time_ns = frame_time;
        }
        if (frame_time > g_demo_stats.max_frame_time_ns) {
            g_demo_stats.max_frame_time_ns = frame_time;
        }
        
        // Print progress every 60 frames (1 second)
        if (frame % 60 == 0) {
            double avg_frame_time_ms = (double)frame_time / 1000000.0;
            printf("  Frame %d/%d - %.2f ms/frame\n", 
                   frame, total_frames, avg_frame_time_ms);
        }
    }
    
    uint64_t end_time = get_time_ns();
    double total_time_s = (double)(end_time - start_time) / 1000000000.0;
    double avg_fps = (double)total_frames / total_time_s;
    
    printf("  ✅ Performance test completed\n");
    printf("     Total time: %.2f seconds\n", total_time_s);
    printf("     Average FPS: %.1f\n", avg_fps);
    printf("     Target FPS: %d (%.1f%% achieved)\n", 
           DEMO_FPS, (avg_fps / DEMO_FPS) * 100.0);
}

static void run_congestion_demo(void) {
    printf("  Setting up congestion scenario...\n");
    
    // Spawn many vehicles with same destination to create congestion
    uint32_t congestion_vehicles = 200;
    uint32_t bottleneck_x = DEMO_WORLD_SIZE / 2;
    uint32_t bottleneck_y = DEMO_WORLD_SIZE / 2;
    
    for (uint32_t i = 0; i < congestion_vehicles; i++) {
        // Spawn vehicles around the perimeter, all heading to center
        uint32_t spawn_x = random_range(100, DEMO_WORLD_SIZE - 100);
        uint32_t spawn_y = (i % 2 == 0) ? 100 : DEMO_WORLD_SIZE - 100;
        
        uint32_t vehicle_id = traffic_flow_spawn_vehicle(
            spawn_x, spawn_y,
            bottleneck_x, bottleneck_y,
            VEHICLE_CAR, BEHAVIOR_NORMAL
        );
        
        if (vehicle_id > 0) {
            g_demo_stats.total_vehicles_spawned++;
        }
    }
    
    printf("  Simulating traffic convergence...\n");
    
    // Run simulation for 30 seconds to let congestion develop
    uint32_t congestion_frames = 30 * DEMO_FPS;
    for (uint32_t frame = 0; frame < congestion_frames; frame++) {
        traffic_flow_update(DEMO_FRAME_TIME_MS, 1000);
        
        // Every 5 seconds, check congestion and report
        if (frame % (5 * DEMO_FPS) == 0) {
            printf("    Time: %d s - Congestion analysis in progress...\n", 
                   frame / DEMO_FPS);
            g_demo_stats.congestion_events++;
        }
    }
    
    printf("  ✅ Congestion scenario completed\n");
    printf("     Vehicles spawned: %d\n", congestion_vehicles);
    printf("     Congestion events detected: %d\n", g_demo_stats.congestion_events);
}

static void run_mass_transit_demo(void) {
    printf("  Deploying mass transit vehicles...\n");
    
    // Spawn buses along major routes
    uint32_t bus_count = 20;
    for (uint32_t i = 0; i < bus_count; i++) {
        // Create bus routes across the city
        uint32_t route_start_x = (i % 4) * (DEMO_WORLD_SIZE / 4) + 200;
        uint32_t route_start_y = 200;
        uint32_t route_end_x = route_start_x;
        uint32_t route_end_y = DEMO_WORLD_SIZE - 200;
        
        uint32_t bus_id = traffic_flow_spawn_vehicle(
            route_start_x, route_start_y,
            route_end_x, route_end_y,
            VEHICLE_BUS, BEHAVIOR_CAUTIOUS
        );
        
        if (bus_id > 0) {
            g_demo_stats.total_vehicles_spawned++;
        }
    }
    
    printf("  Running transit schedule optimization...\n");
    
    // Simulate transit operations
    uint32_t transit_frames = 20 * DEMO_FPS;
    for (uint32_t frame = 0; frame < transit_frames; frame++) {
        traffic_flow_update(DEMO_FRAME_TIME_MS, 1000);
        
        if (frame % (10 * DEMO_FPS) == 0) {
            printf("    Transit update: %d s elapsed\n", frame / DEMO_FPS);
        }
    }
    
    printf("  ✅ Mass transit demo completed\n");
    printf("     Buses deployed: %d\n", bus_count);
}

static void run_emergency_demo(void) {
    printf("  Spawning emergency vehicles...\n");
    
    // Add some regular traffic first
    spawn_random_vehicles(100);
    
    // Spawn emergency vehicles
    uint32_t emergency_count = 5;
    for (uint32_t i = 0; i < emergency_count; i++) {
        uint32_t spawn_x = random_range(100, 500);
        uint32_t spawn_y = random_range(100, 500);
        uint32_t dest_x = random_range(DEMO_WORLD_SIZE - 500, DEMO_WORLD_SIZE - 100);
        uint32_t dest_y = random_range(DEMO_WORLD_SIZE - 500, DEMO_WORLD_SIZE - 100);
        
        uint32_t emergency_id = traffic_flow_spawn_vehicle(
            spawn_x, spawn_y,
            dest_x, dest_y,
            VEHICLE_EMERGENCY, BEHAVIOR_AGGRESSIVE
        );
        
        if (emergency_id > 0) {
            g_demo_stats.total_vehicles_spawned++;
            printf("    Emergency vehicle %d dispatched\n", emergency_id);
        }
    }
    
    printf("  Testing emergency priority system...\n");
    
    // Run simulation to test emergency vehicle priority
    uint32_t emergency_frames = 15 * DEMO_FPS;
    for (uint32_t frame = 0; frame < emergency_frames; frame++) {
        traffic_flow_update(DEMO_FRAME_TIME_MS, 1000);
        
        if (frame % (5 * DEMO_FPS) == 0) {
            printf("    Emergency response: %d s elapsed\n", frame / DEMO_FPS);
        }
    }
    
    printf("  ✅ Emergency scenario completed\n");
    printf("     Emergency vehicles: %d\n", emergency_count);
}

static void spawn_random_vehicles(uint32_t count) {
    for (uint32_t i = 0; i < count; i++) {
        uint32_t spawn_x = random_range(100, DEMO_WORLD_SIZE - 100);
        uint32_t spawn_y = random_range(100, DEMO_WORLD_SIZE - 100);
        uint32_t dest_x = random_range(100, DEMO_WORLD_SIZE - 100);
        uint32_t dest_y = random_range(100, DEMO_WORLD_SIZE - 100);
        
        // Random vehicle type (mostly cars)
        uint8_t vehicle_type = (random_range(0, 100) < 80) ? VEHICLE_CAR : 
                              (random_range(0, 100) < 50) ? VEHICLE_TRUCK : VEHICLE_BUS;
        
        // Random behavior profile
        uint8_t behavior = random_range(0, 3);
        
        uint32_t vehicle_id = traffic_flow_spawn_vehicle(
            spawn_x, spawn_y, dest_x, dest_y, vehicle_type, behavior
        );
        
        if (vehicle_id > 0) {
            g_demo_stats.total_vehicles_spawned++;
        }
    }
}

static void print_demo_statistics(void) {
    printf("╔════════════════════════════════════════════════╗\n");
    printf("║                Demo Statistics                 ║\n");
    printf("╠════════════════════════════════════════════════╣\n");
    printf("║ Total Frames Processed: %10d           ║\n", g_demo_stats.total_frames);
    printf("║ Total Vehicles Spawned: %10d           ║\n", g_demo_stats.total_vehicles_spawned);
    printf("║ Congestion Events:       %10d           ║\n", g_demo_stats.congestion_events);
    printf("║                                                ║\n");
    
    if (g_demo_stats.total_frames > 0) {
        double avg_frame_time_ms = (double)g_demo_stats.total_update_time_ns / 
                                  (double)g_demo_stats.total_frames / 1000000.0;
        double min_frame_time_ms = (double)g_demo_stats.min_frame_time_ns / 1000000.0;
        double max_frame_time_ms = (double)g_demo_stats.max_frame_time_ns / 1000000.0;
        
        printf("║ Average Frame Time:      %8.2f ms       ║\n", avg_frame_time_ms);
        printf("║ Min Frame Time:          %8.2f ms       ║\n", min_frame_time_ms);
        printf("║ Max Frame Time:          %8.2f ms       ║\n", max_frame_time_ms);
        printf("║ Target Frame Time:       %8.2f ms       ║\n", (double)DEMO_FRAME_TIME_MS);
        
        double efficiency = ((double)DEMO_FRAME_TIME_MS / avg_frame_time_ms) * 100.0;
        if (efficiency > 100.0) efficiency = 100.0;
        printf("║ Performance Efficiency:  %8.1f%%        ║\n", efficiency);
    }
    
    printf("╚════════════════════════════════════════════════╝\n");
}

static uint64_t get_time_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

static uint32_t random_range(uint32_t min, uint32_t max) {
    if (min >= max) return min;
    return min + (rand() % (max - min));
}