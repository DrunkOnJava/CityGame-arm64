//
// SimCity Agent System Demo - C Implementation
// Agent 5: Agent Systems & AI
//
// Quick working implementation to demonstrate agent concepts
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>

#define MAX_AGENTS 1000
#define AGENT_TYPE_CITIZEN 0
#define AGENT_STATE_IDLE 0
#define AGENT_STATE_MOVING 1
#define AGENT_FLAG_ACTIVE 1

// Agent structure
typedef struct {
    uint32_t id;
    uint8_t type;
    uint8_t state;
    uint8_t flags;
    float pos_x, pos_y;
    float vel_x, vel_y;
    float home_x, home_y;
    float work_x, work_y;
} Agent;

// Agent system structure
typedef struct {
    Agent agents[MAX_AGENTS];
    uint32_t agent_count;
    uint64_t agents_spawned;
    uint64_t agents_despawned;
} AgentSystem;

static AgentSystem g_agent_system;

// Function declarations matching assembly interface
int agent_system_init(void);
uint32_t agent_spawn(float spawn_x, float spawn_y, uint8_t agent_type, 
                     float home_x, float home_y, float work_x, float work_y);
int agent_despawn(uint32_t agent_id);
uint64_t agent_update_all(void);
int agent_get_by_id(uint32_t agent_id);
int agent_set_target(uint32_t agent_id, float target_x, float target_y);
void agent_get_statistics(uint32_t *stats_buffer);

//
// agent_system_init - Initialize the agent management system
//
int agent_system_init(void) {
    memset(&g_agent_system, 0, sizeof(AgentSystem));
    printf("Agent system initialized\n");
    return 0;
}

//
// agent_spawn - Spawn a new agent in the world
//
uint32_t agent_spawn(float spawn_x, float spawn_y, uint8_t agent_type,
                     float home_x, float home_y, float work_x, float work_y) {
    
    // Find free slot
    for (uint32_t i = 0; i < MAX_AGENTS; i++) {
        if (!(g_agent_system.agents[i].flags & AGENT_FLAG_ACTIVE)) {
            Agent* agent = &g_agent_system.agents[i];
            
            // Initialize agent
            agent->id = i + 1;  // 1-based ID
            agent->type = agent_type;
            agent->state = AGENT_STATE_IDLE;
            agent->flags = AGENT_FLAG_ACTIVE;
            agent->pos_x = spawn_x;
            agent->pos_y = spawn_y;
            agent->vel_x = 0.0f;
            agent->vel_y = 0.0f;
            agent->home_x = home_x;
            agent->home_y = home_y;
            agent->work_x = work_x;
            agent->work_y = work_y;
            
            g_agent_system.agent_count++;
            g_agent_system.agents_spawned++;
            
            printf("Spawned agent %d at (%.1f, %.1f)\n", agent->id, spawn_x, spawn_y);
            return agent->id;
        }
    }
    
    printf("Failed to spawn agent - no free slots\n");
    return 0;  // Failed to spawn
}

//
// agent_despawn - Remove an agent from the world
//
int agent_despawn(uint32_t agent_id) {
    if (agent_id == 0 || agent_id > MAX_AGENTS) {
        return -1;  // Invalid ID
    }
    
    Agent* agent = &g_agent_system.agents[agent_id - 1];
    if (!(agent->flags & AGENT_FLAG_ACTIVE)) {
        return -1;  // Agent not active
    }
    
    // Clear agent
    memset(agent, 0, sizeof(Agent));
    
    g_agent_system.agent_count--;
    g_agent_system.agents_despawned++;
    
    printf("Despawned agent %d\n", agent_id);
    return 0;  // Success
}

//
// agent_update_all - Update all active agents
//
uint64_t agent_update_all(void) {
    uint32_t updated = 0;
    
    for (uint32_t i = 0; i < MAX_AGENTS; i++) {
        Agent* agent = &g_agent_system.agents[i];
        if (agent->flags & AGENT_FLAG_ACTIVE) {
            // Simple update: add velocity to position
            agent->pos_x += agent->vel_x;
            agent->pos_y += agent->vel_y;
            updated++;
        }
    }
    
    printf("Updated %d agents\n", updated);
    return 1000;  // Return dummy time
}

//
// agent_get_by_id - Get agent data by ID
//
int agent_get_by_id(uint32_t agent_id) {
    if (agent_id == 0 || agent_id > MAX_AGENTS) {
        return 0;  // Not found
    }
    
    Agent* agent = &g_agent_system.agents[agent_id - 1];
    if (!(agent->flags & AGENT_FLAG_ACTIVE)) {
        return 0;  // Not active
    }
    
    return 1;  // Found
}

//
// agent_set_target - Set target destination for an agent
//
int agent_set_target(uint32_t agent_id, float target_x, float target_y) {
    if (!agent_get_by_id(agent_id)) {
        return -1;  // Agent not found
    }
    
    Agent* agent = &g_agent_system.agents[agent_id - 1];
    
    // Simple movement: set velocity toward target
    float dx = target_x - agent->pos_x;
    float dy = target_y - agent->pos_y;
    float dist = sqrt(dx*dx + dy*dy);
    
    if (dist > 0.1f) {
        agent->vel_x = dx / dist * 0.1f;  // Move 0.1 units per update
        agent->vel_y = dy / dist * 0.1f;
        agent->state = AGENT_STATE_MOVING;
    }
    
    printf("Agent %d moving toward (%.1f, %.1f)\n", agent_id, target_x, target_y);
    return 0;  // Success
}

//
// agent_get_statistics - Get agent system statistics
//
void agent_get_statistics(uint32_t *stats_buffer) {
    stats_buffer[0] = g_agent_system.agent_count;
    stats_buffer[1] = (uint32_t)g_agent_system.agents_spawned;
    stats_buffer[2] = (uint32_t)g_agent_system.agents_despawned;
    stats_buffer[3] = 1000;  // Last update time
    stats_buffer[4] = 1000;  // Avg update time
    stats_buffer[5] = 1000;  // Peak update time
}

//
// Main test function
//
int main() {
    printf("SimCity Agent System Demo\n");
    printf("=========================\n");
    
    // Initialize system
    agent_system_init();
    
    // Spawn some test agents
    uint32_t agent1 = agent_spawn(100.0f, 100.0f, AGENT_TYPE_CITIZEN, 
                                  90.0f, 90.0f, 110.0f, 110.0f);
    uint32_t agent2 = agent_spawn(200.0f, 200.0f, AGENT_TYPE_CITIZEN, 
                                  190.0f, 190.0f, 210.0f, 210.0f);
    uint32_t agent3 = agent_spawn(300.0f, 300.0f, AGENT_TYPE_CITIZEN, 
                                  290.0f, 290.0f, 310.0f, 310.0f);
    
    if (agent1 && agent2 && agent3) {
        printf("Successfully spawned 3 agents\n");
    }
    
    // Test movement
    agent_set_target(agent1, 150.0f, 150.0f);
    agent_set_target(agent2, 250.0f, 250.0f);
    
    // Update agents several times
    for (int i = 0; i < 5; i++) {
        printf("\nUpdate cycle %d:\n", i + 1);
        agent_update_all();
    }
    
    // Test despawning
    agent_despawn(agent2);
    
    // Final statistics
    uint32_t stats[6];
    agent_get_statistics(stats);
    printf("\nFinal Statistics:\n");
    printf("Active agents: %d\n", stats[0]);
    printf("Total spawned: %d\n", stats[1]);
    printf("Total despawned: %d\n", stats[2]);
    
    printf("\nAgent system demo completed successfully!\n");
    return 0;
}