// SimCity ARM64 Demo - Short Version for Display
// Same as enhanced but runs for only 10 seconds

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

#define INITIAL_CITIZEN_COUNT 800
#define INITIAL_VEHICLE_COUNT 200
#define CITY_WIDTH 100
#define CITY_HEIGHT 100
#define SIMULATION_DURATION_SECONDS 10  // Short demo
#define PERFORMANCE_REPORT_INTERVAL 60   // Every 1 second

// Same code as enhanced version but with shorter duration
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
        return 1.0f / 60.0f;
    }
    
    uint64_t elapsed_ns = (now - last_time) * timebase_info.numer / timebase_info.denom;
    last_time = now;
    
    return (float)elapsed_ns / 1e9f;
}

static struct {
    bool simulation_running;
    uint64_t frame_count;
    uint32_t active_citizens;
    uint32_t active_vehicles;
    float total_time;
    float min_fps, max_fps, total_fps_sum;
    int fps_samples;
} g_demo_state = {0};

static int init_systems(void) {
    printf("🔧 Initializing SimCity ARM64 systems...\n");
    
    if (memory_manager_init() != 0 || 
        entity_system_init() != 0 || 
        ai_system_init(NULL, CITY_WIDTH, CITY_HEIGHT) != 0) {
        return -1;
    }
    
    printf("✅ All systems initialized successfully\n");
    return 0;
}

static void spawn_population(void) {
    printf("👥 Spawning %d citizens and %d vehicles...\n", 
           INITIAL_CITIZEN_COUNT, INITIAL_VEHICLE_COUNT);
    
    // Spawn citizens
    for (int i = 0; i < INITIAL_CITIZEN_COUNT; i++) {
        float x = (rand() % (CITY_WIDTH * 10)) / 10.0f;
        float y = (rand() % (CITY_HEIGHT * 10)) / 10.0f;
        ai_spawn_agent(i, 0, x, y);
        g_demo_state.active_citizens++;
        
        if (i % 200 == 199) {
            printf("   📍 Spawned %d citizens...\n", i + 1);
        }
    }
    
    // Spawn vehicles  
    for (int i = INITIAL_CITIZEN_COUNT; i < INITIAL_CITIZEN_COUNT + INITIAL_VEHICLE_COUNT; i++) {
        float x = (rand() % (CITY_WIDTH * 10)) / 10.0f;
        float y = (rand() % (CITY_HEIGHT * 10)) / 10.0f;
        ai_spawn_agent(i, 1, x, y);
        g_demo_state.active_vehicles++;
        
        if ((i - INITIAL_CITIZEN_COUNT) % 50 == 49) {
            printf("   🚗 Spawned %d vehicles...\n", i - INITIAL_CITIZEN_COUNT + 1);
        }
    }
    
    printf("✅ Population complete: %d total agents active\n\n", 
           g_demo_state.active_citizens + g_demo_state.active_vehicles);
}

static void update_performance(float delta_time) {
    float fps = 1.0f / delta_time;
    
    if (g_demo_state.fps_samples == 0) {
        g_demo_state.min_fps = g_demo_state.max_fps = fps;
    } else {
        if (fps < g_demo_state.min_fps) g_demo_state.min_fps = fps;
        if (fps > g_demo_state.max_fps) g_demo_state.max_fps = fps;
    }
    
    g_demo_state.total_fps_sum += fps;
    g_demo_state.fps_samples++;
    g_demo_state.total_time += delta_time;
}

static void print_status(void) {
    float avg_fps = g_demo_state.total_fps_sum / g_demo_state.fps_samples;
    
    printf("🎮 Frame %-4llu | FPS: %5.1f | Avg: %5.1f | Range: %4.1f-%4.1f | Time: %4.1fs | Agents: %d\n",
           g_demo_state.frame_count, 1.0f / (g_demo_state.total_time / g_demo_state.fps_samples),
           avg_fps, g_demo_state.min_fps, g_demo_state.max_fps, g_demo_state.total_time,
           g_demo_state.active_citizens + g_demo_state.active_vehicles);
}

int main(void) {
    printf("🏙️  === SimCity ARM64 Live Demo === 🏙️ \n");
    printf("🎯 Target: 1000 agents (%d citizens + %d vehicles)\n", 
           INITIAL_CITIZEN_COUNT, INITIAL_VEHICLE_COUNT);
    printf("⏱️  Duration: %d seconds\n\n", SIMULATION_DURATION_SECONDS);
    
    srand((unsigned int)time(NULL));
    
    if (init_systems() != 0) {
        printf("❌ System initialization failed\n");
        return -1;
    }
    
    spawn_population();
    
    printf("🚀 Starting live simulation...\n\n");
    g_demo_state.simulation_running = true;
    
    int demo_frames = SIMULATION_DURATION_SECONDS * 60;
    for (int frame = 0; frame < demo_frames; frame++) {
        float delta_time = get_delta_time();
        
        // Update simulation
        entity_system_update(delta_time);
        ai_system_update(delta_time);
        
        // Track performance
        update_performance(delta_time);
        g_demo_state.frame_count++;
        
        // Print status every second
        if (frame % PERFORMANCE_REPORT_INTERVAL == 0 && frame > 0) {
            print_status();
        }
        
        usleep(16667); // 60 FPS target
    }
    
    printf("\n🎉 === SIMULATION COMPLETED! === 🎉\n\n");
    
    // Final statistics
    float avg_fps = g_demo_state.total_fps_sum / g_demo_state.fps_samples;
    printf("📊 FINAL PERFORMANCE SUMMARY:\n");
    printf("   ⚡ Total Frames: %llu\n", g_demo_state.frame_count);
    printf("   📈 Average FPS: %.1f\n", avg_fps);
    printf("   📉 FPS Range: %.1f - %.1f\n", g_demo_state.min_fps, g_demo_state.max_fps);
    printf("   ⏱️  Total Runtime: %.1f seconds\n", g_demo_state.total_time);
    printf("   👥 Active Agents: %d citizens + %d vehicles = %d total\n",
           g_demo_state.active_citizens, g_demo_state.active_vehicles,
           g_demo_state.active_citizens + g_demo_state.active_vehicles);
    
    printf("\n🧠 AI SYSTEM STATISTICS:\n");
    ai_print_performance_stats();
    
    // Cleanup
    ai_system_shutdown();
    entity_system_shutdown(); 
    memory_manager_shutdown();
    
    printf("\n✅ Demo completed successfully - all systems cleaned up!\n");
    printf("🏁 === SimCity ARM64 Demo Complete === 🏁\n");
    
    return 0;
}