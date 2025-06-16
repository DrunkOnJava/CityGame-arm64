//==============================================================================
// SimCity ARM64 Assembly - AI Systems Integration Coordinator
// Sub-Agent 5: AI Systems Coordinator
//==============================================================================
// Unified AI coordination system connecting:
// - astar_core.s pathfinding to all AI clients
// - traffic_flow.s with citizen_behavior.s
// - emergency_services.s dispatch system  
// - mass_transit.s with traffic systems
// - Unified AI update pipeline
//==============================================================================

#include "ai_integration.h"
#include "steering_behaviors.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>

// Forward declarations for assembly functions
extern int astar_pathfinding_init(const uint8_t* world_map, uint32_t width, uint32_t height);
extern void astar_pathfinding_shutdown(void);
extern uint32_t astar_pathfinding_request(uint32_t start_x, uint32_t start_y, 
                                         uint32_t end_x, uint32_t end_y,
                                         uint32_t agent_type, uint32_t priority);

extern int traffic_flow_init(void);
extern void traffic_flow_update(float delta_time);
extern void traffic_flow_shutdown(void);
extern uint32_t traffic_request_vehicle_slot(uint32_t citizen_id, uint32_t start_x, uint32_t start_y);

extern int citizen_behavior_init(void);
extern void citizen_behavior_update(float delta_time);
extern void citizen_behavior_shutdown(void);
extern void citizen_spawn(uint32_t citizen_id, uint32_t x, uint32_t y, uint32_t age, uint32_t profession);

extern int emergency_services_init(void);
extern void emergency_services_update(float delta_time);
extern void emergency_services_shutdown(void);
extern void emergency_dispatch_request(uint32_t emergency_type, uint32_t x, uint32_t y, uint32_t severity);

extern int mass_transit_init(void);
extern void mass_transit_update(float delta_time);
extern void mass_transit_shutdown(void);
extern uint32_t mass_transit_request_route(uint32_t passenger_id, uint32_t start_x, uint32_t start_y,
                                          uint32_t dest_x, uint32_t dest_y);

// AI system state
static bool ai_systems_initialized = false;
static uint32_t world_width = 0;
static uint32_t world_height = 0;
static const uint8_t* world_map = NULL;

// Performance counters
static uint64_t total_pathfinding_requests = 0;
static uint64_t total_vehicle_spawns = 0;
static uint64_t total_emergency_dispatches = 0;
static uint64_t total_transit_requests = 0;
static uint32_t total_citizens = 0;
static float average_update_time = 0.0f;

//==============================================================================
// AI System Initialization
//==============================================================================

int ai_system_init(const uint8_t* world_tiles, uint32_t width, uint32_t height) {
    printf("AI system initializing with world %dx%d\n", width, height);
    
    if (ai_systems_initialized) {
        printf("AI systems already initialized\n");
        return 0; // Already initialized
    }
    
    // Store world parameters
    world_map = world_tiles;
    world_width = width;
    world_height = height;
    
    // Initialize pathfinding system first (other systems depend on it)
    printf("Initializing A* pathfinding system...\n");
    if (astar_pathfinding_init(world_tiles, width, height) != 0) {
        printf("Failed to initialize pathfinding system\n");
        return -1;
    }
    
    // Initialize traffic flow system
    printf("Initializing traffic flow system...\n");
    if (traffic_flow_init() != 0) {
        printf("Failed to initialize traffic flow system\n");
        astar_pathfinding_shutdown();
        return -2;
    }
    
    // Initialize citizen behavior system
    printf("Initializing citizen behavior system...\n");
    if (citizen_behavior_init() != 0) {
        printf("Failed to initialize citizen behavior system\n");
        traffic_flow_shutdown();
        astar_pathfinding_shutdown();
        return -3;
    }
    
    // Initialize emergency services
    printf("Initializing emergency services...\n");
    if (emergency_services_init() != 0) {
        printf("Failed to initialize emergency services\n");
        citizen_behavior_shutdown();
        traffic_flow_shutdown();
        astar_pathfinding_shutdown();
        return -4;
    }
    
    // Initialize mass transit system
    printf("Initializing mass transit system...\n");
    if (mass_transit_init() != 0) {
        printf("Failed to initialize mass transit system\n");
        emergency_services_shutdown();
        citizen_behavior_shutdown();
        traffic_flow_shutdown();
        astar_pathfinding_shutdown();
        return -5;
    }
    
    // Initialize steering system for backward compatibility
    if (steering_system_init(100000) != 0) {  // Max 100K agents
        printf("Failed to initialize steering system\n");
        mass_transit_shutdown();
        emergency_services_shutdown();
        citizen_behavior_shutdown();
        traffic_flow_shutdown();
        astar_pathfinding_shutdown();
        return -6;
    }
    
    ai_systems_initialized = true;
    printf("AI systems initialized successfully\n");
    return 0;
}

//==============================================================================
// AI System Shutdown
//==============================================================================

void ai_system_shutdown(void) {
    if (!ai_systems_initialized) {
        return;
    }
    
    printf("AI system shutting down\n");
    
    // Shutdown in reverse order
    steering_system_shutdown();
    mass_transit_shutdown();
    emergency_services_shutdown();
    citizen_behavior_shutdown();
    traffic_flow_shutdown();
    astar_pathfinding_shutdown();
    
    ai_systems_initialized = false;
    total_citizens = 0;
}

//==============================================================================
// Unified AI Update Pipeline
//==============================================================================

void ai_system_update(float delta_time) {
    if (!ai_systems_initialized) {
        return;
    }
    
    // Update systems in dependency order:
    
    // 1. Update citizen behaviors (generates movement requests)
    citizen_behavior_update(delta_time);
    
    // 2. Update traffic flow (processes movement requests, spawns vehicles)
    traffic_flow_update(delta_time);
    
    // 3. Update emergency services (high priority pathfinding)
    emergency_services_update(delta_time);
    
    // 4. Update mass transit (optimizes routes based on demand)
    mass_transit_update(delta_time);
    
    // 5. Update steering system for backward compatibility
    steering_system_update(delta_time);
}

//==============================================================================
// Agent Spawning Interface
//==============================================================================

void ai_spawn_agent(uint32_t agent_id, uint32_t agent_type, float x, float y) {
    if (!ai_systems_initialized) {
        return;
    }
    
    switch (agent_type) {
        case 0: // AGENT_TYPE_CITIZEN
            citizen_spawn(agent_id, (uint32_t)x, (uint32_t)y, 25, 1); // Default adult office worker
            total_citizens++;
            
            // Also create in steering system for backward compatibility
            AgentType steer_type = AGENT_CITIZEN;
            Vector2 position = {x, y};
            steering_create_agent(agent_id, steer_type, position, NULL);
            break;
            
        case 1: // AGENT_TYPE_VEHICLE
            traffic_request_vehicle_slot(agent_id, (uint32_t)x, (uint32_t)y);
            total_vehicle_spawns++;
            
            // Also create in steering system
            AgentType vehicle_type = AGENT_VEHICLE;
            Vector2 vehicle_pos = {x, y};
            steering_create_agent(agent_id, vehicle_type, vehicle_pos, NULL);
            break;
            
        case 2: // AGENT_TYPE_EMERGENCY
            emergency_dispatch_request(1, (uint32_t)x, (uint32_t)y, 2); // Default fire emergency
            total_emergency_dispatches++;
            break;
            
        default:
            // Unknown agent type - create in steering system as citizen
            AgentType default_type = AGENT_CITIZEN;
            Vector2 default_pos = {x, y};
            steering_create_agent(agent_id, default_type, default_pos, NULL);
            break;
    }
    
    if ((total_citizens + total_vehicle_spawns) % 1000 == 0) {
        printf("AI agents spawned: %d citizens, %d vehicles, %d emergencies\n", 
               total_citizens, total_vehicle_spawns, total_emergency_dispatches);
    }
}

//==============================================================================
// Pathfinding Request Interface (for external systems)
//==============================================================================

uint32_t ai_request_pathfinding(uint32_t start_x, uint32_t start_y, 
                                uint32_t end_x, uint32_t end_y,
                                uint32_t agent_type, uint32_t priority) {
    if (!ai_systems_initialized) {
        return 0;
    }
    
    total_pathfinding_requests++;
    return astar_pathfinding_request(start_x, start_y, end_x, end_y, agent_type, priority);
}

//==============================================================================
// Mass Transit Interface (for external systems)
//==============================================================================

uint32_t ai_request_transit_route(uint32_t passenger_id, uint32_t start_x, uint32_t start_y,
                                  uint32_t dest_x, uint32_t dest_y) {
    if (!ai_systems_initialized) {
        return 0;
    }
    
    total_transit_requests++;
    return mass_transit_request_route(passenger_id, start_x, start_y, dest_x, dest_y);
}

//==============================================================================
// Performance Statistics
//==============================================================================

void ai_print_performance_stats(void) {
    printf("=== AI Systems Performance Stats ===\n");
    printf("Systems Initialized: %s\n", ai_systems_initialized ? "Yes" : "No");
    printf("World Size: %dx%d\n", world_width, world_height);
    printf("Total Citizens: %d\n", total_citizens);
    printf("Total Vehicle Spawns: %llu\n", total_vehicle_spawns);
    printf("Total Pathfinding Requests: %llu\n", total_pathfinding_requests);
    printf("Total Emergency Dispatches: %llu\n", total_emergency_dispatches);
    printf("Total Transit Requests: %llu\n", total_transit_requests);
    printf("Average Update Time: %.3f ms\n", average_update_time);
    
    // Print steering system stats for backward compatibility
    steering_print_stats();
}