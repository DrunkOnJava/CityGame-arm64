//
// SimCity Agent Visual Demo
// Agent 5: Agent Systems & AI
//
// Simple visual demonstration of agents moving in the city
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <unistd.h>  // for usleep

#define MAX_AGENTS 100
#define WORLD_WIDTH 20
#define WORLD_HEIGHT 10
#define CELL_SIZE 1

#define AGENT_TYPE_CITIZEN 0
#define AGENT_STATE_IDLE 0
#define AGENT_STATE_MOVING 1
#define AGENT_FLAG_ACTIVE 1

// Simple agent structure for visualization
typedef struct {
    uint32_t id;
    uint8_t type;
    uint8_t state;
    uint8_t flags;
    float pos_x, pos_y;
    float vel_x, vel_y;
    float target_x, target_y;
    char symbol;
} Agent;

// Simple agent system
typedef struct {
    Agent agents[MAX_AGENTS];
    uint32_t agent_count;
    uint64_t frame_count;
} AgentSystem;

static AgentSystem g_agent_system;

// Initialize the agent system
int agent_system_init(void) {
    memset(&g_agent_system, 0, sizeof(AgentSystem));
    printf("Visual agent system initialized\n");
    return 0;
}

// Spawn an agent with a visual symbol
uint32_t agent_spawn(float spawn_x, float spawn_y, char symbol) {
    for (uint32_t i = 0; i < MAX_AGENTS; i++) {
        if (!(g_agent_system.agents[i].flags & AGENT_FLAG_ACTIVE)) {
            Agent* agent = &g_agent_system.agents[i];
            
            agent->id = i + 1;
            agent->type = AGENT_TYPE_CITIZEN;
            agent->state = AGENT_STATE_IDLE;
            agent->flags = AGENT_FLAG_ACTIVE;
            agent->pos_x = spawn_x;
            agent->pos_y = spawn_y;
            agent->vel_x = 0.0f;
            agent->vel_y = 0.0f;
            agent->target_x = spawn_x;
            agent->target_y = spawn_y;
            agent->symbol = symbol;
            
            g_agent_system.agent_count++;
            
            return agent->id;
        }
    }
    return 0;
}

// Set agent target
int agent_set_target(uint32_t agent_id, float target_x, float target_y) {
    if (agent_id == 0 || agent_id > MAX_AGENTS) return -1;
    
    Agent* agent = &g_agent_system.agents[agent_id - 1];
    if (!(agent->flags & AGENT_FLAG_ACTIVE)) return -1;
    
    agent->target_x = target_x;
    agent->target_y = target_y;
    agent->state = AGENT_STATE_MOVING;
    
    // Calculate velocity
    float dx = target_x - agent->pos_x;
    float dy = target_y - agent->pos_y;
    float dist = sqrt(dx*dx + dy*dy);
    
    if (dist > 0.1f) {
        float speed = 0.2f;  // Movement speed
        agent->vel_x = (dx / dist) * speed;
        agent->vel_y = (dy / dist) * speed;
    }
    
    return 0;
}

// Update all agents
void agent_update_all(void) {
    for (uint32_t i = 0; i < MAX_AGENTS; i++) {
        Agent* agent = &g_agent_system.agents[i];
        if (!(agent->flags & AGENT_FLAG_ACTIVE)) continue;
        
        if (agent->state == AGENT_STATE_MOVING) {
            // Update position
            agent->pos_x += agent->vel_x;
            agent->pos_y += agent->vel_y;
            
            // Check if reached target
            float dx = agent->target_x - agent->pos_x;
            float dy = agent->target_y - agent->pos_y;
            float dist = sqrt(dx*dx + dy*dy);
            
            if (dist < 0.3f) {
                agent->state = AGENT_STATE_IDLE;
                agent->vel_x = 0.0f;
                agent->vel_y = 0.0f;
                
                // Set a new random target after reaching current one
                agent->target_x = (float)(rand() % WORLD_WIDTH);
                agent->target_y = (float)(rand() % WORLD_HEIGHT);
                agent_set_target(agent->id, agent->target_x, agent->target_y);
            }
        }
        
        // Keep agents within bounds
        if (agent->pos_x < 0) agent->pos_x = 0;
        if (agent->pos_y < 0) agent->pos_y = 0;
        if (agent->pos_x >= WORLD_WIDTH) agent->pos_x = WORLD_WIDTH - 0.1f;
        if (agent->pos_y >= WORLD_HEIGHT) agent->pos_y = WORLD_HEIGHT - 0.1f;
    }
    
    g_agent_system.frame_count++;
}

// Clear screen and position cursor at top
void clear_screen(void) {
    printf("\033[2J\033[H");
}

// Draw the world with agents
void draw_world(void) {
    char world[WORLD_HEIGHT][WORLD_WIDTH];
    
    // Initialize world with empty spaces
    for (int y = 0; y < WORLD_HEIGHT; y++) {
        for (int x = 0; x < WORLD_WIDTH; x++) {
            world[y][x] = '.';
        }
    }
    
    // Add some simple "buildings"
    world[2][5] = '#';
    world[2][6] = '#';
    world[2][15] = '#';
    world[2][16] = '#';
    world[7][3] = '#';
    world[7][4] = '#';
    world[7][12] = '#';
    world[7][13] = '#';
    
    // Place agents in world
    for (uint32_t i = 0; i < MAX_AGENTS; i++) {
        Agent* agent = &g_agent_system.agents[i];
        if (!(agent->flags & AGENT_FLAG_ACTIVE)) continue;
        
        int x = (int)(agent->pos_x);
        int y = (int)(agent->pos_y);
        
        if (x >= 0 && x < WORLD_WIDTH && y >= 0 && y < WORLD_HEIGHT) {
            world[y][x] = agent->symbol;
        }
    }
    
    // Draw world
    printf("╔");
    for (int x = 0; x < WORLD_WIDTH; x++) printf("═");
    printf("╗\n");
    
    for (int y = 0; y < WORLD_HEIGHT; y++) {
        printf("║");
        for (int x = 0; x < WORLD_WIDTH; x++) {
            printf("%c", world[y][x]);
        }
        printf("║\n");
    }
    
    printf("╚");
    for (int x = 0; x < WORLD_WIDTH; x++) printf("═");
    printf("╝\n");
}

// Display stats
void display_stats(void) {
    printf("\nSimCity Agent System Demo - Frame %llu\n", g_agent_system.frame_count);
    printf("Active Agents: %d\n", g_agent_system.agent_count);
    printf("Legend: C=Citizens, W=Workers, V=Visitors, #=Buildings, .=Empty\n");
    printf("Press Ctrl+C to exit\n");
}

int main() {
    printf("SimCity Visual Agent Demo\n");
    printf("=========================\n");
    
    // Initialize system
    agent_system_init();
    
    // Spawn some agents with different symbols
    agent_spawn(2.0f, 3.0f, 'C');   // Citizen
    agent_spawn(8.0f, 5.0f, 'C');   // Citizen
    agent_spawn(15.0f, 2.0f, 'W');  // Worker
    agent_spawn(1.0f, 8.0f, 'V');   // Visitor
    agent_spawn(18.0f, 6.0f, 'C');  // Citizen
    agent_spawn(10.0f, 1.0f, 'W');  // Worker
    agent_spawn(5.0f, 9.0f, 'V');   // Visitor
    
    // Set initial targets for all agents
    for (uint32_t i = 1; i <= g_agent_system.agent_count; i++) {
        float target_x = (float)(rand() % WORLD_WIDTH);
        float target_y = (float)(rand() % WORLD_HEIGHT);
        agent_set_target(i, target_x, target_y);
    }
    
    // Main animation loop
    for (int frame = 0; frame < 200; frame++) {
        clear_screen();
        
        // Update agents
        agent_update_all();
        
        // Draw world
        draw_world();
        
        // Display stats
        display_stats();
        
        // Sleep for animation timing (100ms)
        usleep(100000);
    }
    
    printf("\nDemo completed!\n");
    return 0;
}