//
// SimCity Agent System with Spatial Hashing
// Agent 5: Agent Systems & AI
//
// Enhanced agent system with spatial partitioning for fast queries
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>

#define MAX_AGENTS 10000
#define WORLD_WIDTH 4096
#define WORLD_HEIGHT 4096
#define SPATIAL_GRID_SIZE 64        // 64x64 spatial grid
#define CELL_SIZE (WORLD_WIDTH / SPATIAL_GRID_SIZE)
#define MAX_AGENTS_PER_CELL 32

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
    uint16_t spatial_cell;          // Current spatial cell
} Agent;

// Spatial cell structure
typedef struct {
    uint32_t agent_ids[MAX_AGENTS_PER_CELL];
    uint8_t agent_count;
} SpatialCell;

// Agent system structure
typedef struct {
    Agent agents[MAX_AGENTS];
    SpatialCell spatial_grid[SPATIAL_GRID_SIZE * SPATIAL_GRID_SIZE];
    uint32_t agent_count;
    uint64_t agents_spawned;
    uint64_t agents_despawned;
    uint64_t spatial_queries;
    uint64_t spatial_updates;
} AgentSystem;

static AgentSystem g_agent_system;

// Function declarations
int agent_system_init(void);
uint32_t agent_spawn(float spawn_x, float spawn_y, uint8_t agent_type, 
                     float home_x, float home_y, float work_x, float work_y);
int agent_despawn(uint32_t agent_id);
uint64_t agent_update_all(void);
int agent_get_by_id(uint32_t agent_id);
int agent_set_target(uint32_t agent_id, float target_x, float target_y);
void agent_get_statistics(uint32_t *stats_buffer);

// Spatial functions
uint16_t get_spatial_cell(float x, float y);
void add_agent_to_spatial_grid(uint32_t agent_id, float x, float y);
void remove_agent_from_spatial_grid(uint32_t agent_id, uint16_t cell_id);
void update_agent_spatial_position(uint32_t agent_id, float old_x, float old_y, float new_x, float new_y);
uint32_t query_agents_in_radius(float center_x, float center_y, float radius, uint32_t *result_buffer, uint32_t max_results);

//
// get_spatial_cell - Calculate spatial cell index from world coordinates
//
uint16_t get_spatial_cell(float x, float y) {
    // Clamp coordinates to world bounds
    if (x < 0) x = 0;
    if (y < 0) y = 0;
    if (x >= WORLD_WIDTH) x = WORLD_WIDTH - 1;
    if (y >= WORLD_HEIGHT) y = WORLD_HEIGHT - 1;
    
    uint16_t cell_x = (uint16_t)(x / CELL_SIZE);
    uint16_t cell_y = (uint16_t)(y / CELL_SIZE);
    
    if (cell_x >= SPATIAL_GRID_SIZE) cell_x = SPATIAL_GRID_SIZE - 1;
    if (cell_y >= SPATIAL_GRID_SIZE) cell_y = SPATIAL_GRID_SIZE - 1;
    
    return cell_y * SPATIAL_GRID_SIZE + cell_x;
}

//
// add_agent_to_spatial_grid - Add agent to spatial grid
//
void add_agent_to_spatial_grid(uint32_t agent_id, float x, float y) {
    uint16_t cell_id = get_spatial_cell(x, y);
    SpatialCell *cell = &g_agent_system.spatial_grid[cell_id];
    
    if (cell->agent_count < MAX_AGENTS_PER_CELL) {
        cell->agent_ids[cell->agent_count] = agent_id;
        cell->agent_count++;
        
        // Update agent's spatial cell reference
        if (agent_id > 0 && agent_id <= MAX_AGENTS) {
            g_agent_system.agents[agent_id - 1].spatial_cell = cell_id;
        }
    }
}

//
// remove_agent_from_spatial_grid - Remove agent from spatial grid
//
void remove_agent_from_spatial_grid(uint32_t agent_id, uint16_t cell_id) {
    if (cell_id >= SPATIAL_GRID_SIZE * SPATIAL_GRID_SIZE) return;
    
    SpatialCell *cell = &g_agent_system.spatial_grid[cell_id];
    
    for (uint8_t i = 0; i < cell->agent_count; i++) {
        if (cell->agent_ids[i] == agent_id) {
            // Swap with last agent and decrease count
            cell->agent_ids[i] = cell->agent_ids[cell->agent_count - 1];
            cell->agent_count--;
            break;
        }
    }
}

//
// update_agent_spatial_position - Update agent's position in spatial grid
//
void update_agent_spatial_position(uint32_t agent_id, float old_x, float old_y, float new_x, float new_y) {
    uint16_t old_cell = get_spatial_cell(old_x, old_y);
    uint16_t new_cell = get_spatial_cell(new_x, new_y);
    
    if (old_cell != new_cell) {
        remove_agent_from_spatial_grid(agent_id, old_cell);
        add_agent_to_spatial_grid(agent_id, new_x, new_y);
        g_agent_system.spatial_updates++;
    }
}

//
// query_agents_in_radius - Find all agents within a radius
//
uint32_t query_agents_in_radius(float center_x, float center_y, float radius, uint32_t *result_buffer, uint32_t max_results) {
    uint32_t result_count = 0;
    g_agent_system.spatial_queries++;
    
    // Calculate cells to check (simple bounding box approach)
    float min_x = center_x - radius;
    float max_x = center_x + radius;
    float min_y = center_y - radius;
    float max_y = center_y + radius;
    
    uint16_t min_cell_x = (uint16_t)(min_x / CELL_SIZE);
    uint16_t max_cell_x = (uint16_t)(max_x / CELL_SIZE);
    uint16_t min_cell_y = (uint16_t)(min_y / CELL_SIZE);
    uint16_t max_cell_y = (uint16_t)(max_y / CELL_SIZE);
    
    // Clamp to grid bounds
    if (min_cell_x >= SPATIAL_GRID_SIZE) min_cell_x = SPATIAL_GRID_SIZE - 1;
    if (max_cell_x >= SPATIAL_GRID_SIZE) max_cell_x = SPATIAL_GRID_SIZE - 1;
    if (min_cell_y >= SPATIAL_GRID_SIZE) min_cell_y = SPATIAL_GRID_SIZE - 1;
    if (max_cell_y >= SPATIAL_GRID_SIZE) max_cell_y = SPATIAL_GRID_SIZE - 1;
    
    float radius_squared = radius * radius;
    
    // Check each cell in the bounding box
    for (uint16_t cell_y = min_cell_y; cell_y <= max_cell_y; cell_y++) {
        for (uint16_t cell_x = min_cell_x; cell_x <= max_cell_x; cell_x++) {
            uint16_t cell_id = cell_y * SPATIAL_GRID_SIZE + cell_x;
            SpatialCell *cell = &g_agent_system.spatial_grid[cell_id];
            
            // Check each agent in this cell
            for (uint8_t i = 0; i < cell->agent_count && result_count < max_results; i++) {
                uint32_t agent_id = cell->agent_ids[i];
                if (agent_id > 0 && agent_id <= MAX_AGENTS) {
                    Agent *agent = &g_agent_system.agents[agent_id - 1];
                    if (agent->flags & AGENT_FLAG_ACTIVE) {
                        float dx = agent->pos_x - center_x;
                        float dy = agent->pos_y - center_y;
                        float dist_squared = dx * dx + dy * dy;
                        
                        if (dist_squared <= radius_squared) {
                            result_buffer[result_count] = agent_id;
                            result_count++;
                        }
                    }
                }
            }
        }
    }
    
    return result_count;
}

//
// agent_system_init - Initialize the agent management system
//
int agent_system_init(void) {
    memset(&g_agent_system, 0, sizeof(AgentSystem));
    printf("Agent system with spatial hashing initialized\n");
    printf("Spatial grid: %dx%d cells, cell size: %d units\n", 
           SPATIAL_GRID_SIZE, SPATIAL_GRID_SIZE, CELL_SIZE);
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
            
            // Add to spatial grid
            add_agent_to_spatial_grid(agent->id, spawn_x, spawn_y);
            
            g_agent_system.agent_count++;
            g_agent_system.agents_spawned++;
            
            printf("Spawned agent %d at (%.1f, %.1f) in cell %d\n", 
                   agent->id, spawn_x, spawn_y, agent->spatial_cell);
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
    
    // Remove from spatial grid
    remove_agent_from_spatial_grid(agent_id, agent->spatial_cell);
    
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
            float old_x = agent->pos_x;
            float old_y = agent->pos_y;
            
            // Simple update: add velocity to position
            agent->pos_x += agent->vel_x;
            agent->pos_y += agent->vel_y;
            
            // Update spatial position if moved
            if (old_x != agent->pos_x || old_y != agent->pos_y) {
                update_agent_spatial_position(agent->id, old_x, old_y, agent->pos_x, agent->pos_y);
            }
            
            updated++;
        }
    }
    
    printf("Updated %d agents (%llu spatial updates)\n", updated, g_agent_system.spatial_updates);
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
        agent->vel_x = dx / dist * 1.0f;  // Move 1.0 units per update
        agent->vel_y = dy / dist * 1.0f;
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
    stats_buffer[3] = (uint32_t)g_agent_system.spatial_queries;
    stats_buffer[4] = (uint32_t)g_agent_system.spatial_updates;
    stats_buffer[5] = 1000;  // Dummy time
}

//
// Main test function
//
int main() {
    printf("SimCity Agent System with Spatial Hashing Demo\n");
    printf("===============================================\n");
    
    // Initialize system
    agent_system_init();
    
    // Spawn agents in different areas
    printf("\nSpawning agents across the world...\n");
    uint32_t agents[20];
    for (int i = 0; i < 20; i++) {
        float x = (float)((i % 5) * 200 + 100);
        float y = (float)((i / 5) * 200 + 100);
        agents[i] = agent_spawn(x, y, AGENT_TYPE_CITIZEN, x-10, y-10, x+10, y+10);
    }
    
    // Test spatial queries
    printf("\nTesting spatial queries...\n");
    uint32_t nearby_agents[50];
    
    // Find agents near (300, 300) within radius 150
    uint32_t found = query_agents_in_radius(300.0f, 300.0f, 150.0f, nearby_agents, 50);
    printf("Found %d agents within 150 units of (300, 300):\n", found);
    for (uint32_t i = 0; i < found; i++) {
        Agent *agent = &g_agent_system.agents[nearby_agents[i] - 1];
        printf("  Agent %d at (%.1f, %.1f)\n", agent->id, agent->pos_x, agent->pos_y);
    }
    
    // Set some agents moving
    printf("\nSetting agents to move...\n");
    for (int i = 0; i < 5; i++) {
        if (agents[i] != 0) {
            agent_set_target(agents[i], 500.0f + i * 20, 500.0f + i * 20);
        }
    }
    
    // Update agents several times to test spatial updates
    printf("\nUpdating agents to test spatial movement...\n");
    for (int i = 0; i < 10; i++) {
        printf("\nUpdate cycle %d:\n", i + 1);
        agent_update_all();
        
        // Query agents again every few updates
        if (i % 3 == 0) {
            found = query_agents_in_radius(500.0f, 500.0f, 100.0f, nearby_agents, 50);
            printf("Agents near (500, 500): %d\n", found);
        }
    }
    
    // Final statistics
    uint32_t stats[6];
    agent_get_statistics(stats);
    printf("\nFinal Statistics:\n");
    printf("Active agents: %d\n", stats[0]);
    printf("Total spawned: %d\n", stats[1]);
    printf("Total despawned: %d\n", stats[2]);
    printf("Spatial queries: %d\n", stats[3]);
    printf("Spatial updates: %d\n", stats[4]);
    
    // Test performance with more agents
    printf("\nTesting performance with 1000 agents...\n");
    for (int i = 0; i < 1000; i++) {
        float x = (float)(rand() % WORLD_WIDTH);
        float y = (float)(rand() % WORLD_HEIGHT);
        agent_spawn(x, y, AGENT_TYPE_CITIZEN, x, y, x, y);
    }
    
    // Time a large spatial query
    printf("Performing large spatial query...\n");
    found = query_agents_in_radius(WORLD_WIDTH/2, WORLD_HEIGHT/2, 500.0f, nearby_agents, 50);
    printf("Found %d agents within 500 units of world center\n", found);
    
    agent_get_statistics(stats);
    printf("Total spatial queries performed: %d\n", stats[3]);
    
    printf("\nSpatial agent system demo completed successfully!\n");
    return 0;
}