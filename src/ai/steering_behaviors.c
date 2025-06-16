// SimCity ARM64 Steering Behaviors
// Collision avoidance, flocking, and navigation for realistic agent movement

#include "steering_behaviors.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// Constants for steering behaviors
#define MAX_STEERING_FORCE 5.0f
#define SEPARATION_RADIUS 3.0f
#define ALIGNMENT_RADIUS 8.0f
#define COHESION_RADIUS 10.0f
#define OBSTACLE_AVOIDANCE_RADIUS 5.0f
#define WANDER_CIRCLE_RADIUS 2.0f
#define WANDER_CIRCLE_DISTANCE 4.0f
#define WANDER_ANGLE_CHANGE 0.3f
#define PATH_FOLLOWING_RADIUS 2.0f
#define ARRIVAL_RADIUS 3.0f
#define SLOWING_RADIUS 8.0f
#define MAX_NEIGHBORS 20

// Agent data (external from entity system)
static SteeringAgent* g_agents = NULL;
static uint32_t g_agent_count = 0;
static uint32_t g_max_agents = 0;

// Spatial grid for efficient neighbor finding
#define GRID_SIZE 16.0f
#define GRID_WIDTH 64
#define GRID_HEIGHT 64
static uint32_t g_spatial_grid[GRID_WIDTH][GRID_HEIGHT][32]; // Max 32 agents per cell
static uint32_t g_grid_counts[GRID_WIDTH][GRID_HEIGHT];

// Forward declarations
static Vector2 seek(const SteeringAgent* agent, Vector2 target);
static Vector2 flee(const SteeringAgent* agent, Vector2 target);
static Vector2 arrive(const SteeringAgent* agent, Vector2 target);
static Vector2 wander(SteeringAgent* agent);
static Vector2 separation(const SteeringAgent* agent, const SteeringAgent* neighbors[], uint32_t neighbor_count);
static Vector2 alignment(const SteeringAgent* agent, const SteeringAgent* neighbors[], uint32_t neighbor_count);
static Vector2 cohesion(const SteeringAgent* agent, const SteeringAgent* neighbors[], uint32_t neighbor_count);
static Vector2 obstacle_avoidance(const SteeringAgent* agent);
static Vector2 path_following(const SteeringAgent* agent);
static void find_neighbors(const SteeringAgent* agent, const SteeringAgent* neighbors[], uint32_t* neighbor_count);
static void update_spatial_grid(void);
static Vector2 vector2_add(Vector2 a, Vector2 b);
static Vector2 vector2_subtract(Vector2 a, Vector2 b);
static Vector2 vector2_multiply(Vector2 v, float scalar);
static Vector2 vector2_normalize(Vector2 v);
static float vector2_length(Vector2 v);
static float vector2_distance(Vector2 a, Vector2 b);
static Vector2 vector2_limit(Vector2 v, float max_length);
static Vector2 vector2_truncate(Vector2 v, float max_length);

//==============================================================================
// SYSTEM INITIALIZATION
//==============================================================================

int steering_system_init(uint32_t max_agents) {
    if (g_agents != NULL) {
        return 0; // Already initialized
    }
    
    g_max_agents = max_agents;
    g_agents = calloc(max_agents, sizeof(SteeringAgent));
    if (!g_agents) {
        printf("Failed to allocate steering agents\n");
        return -1;
    }
    
    g_agent_count = 0;
    
    // Clear spatial grid
    memset(g_grid_counts, 0, sizeof(g_grid_counts));
    
    printf("Steering system initialized for %u agents\n", max_agents);
    return 0;
}

void steering_system_shutdown(void) {
    if (g_agents) {
        free(g_agents);
        g_agents = NULL;
    }
    g_agent_count = 0;
    g_max_agents = 0;
    
    printf("Steering system shutdown\n");
}

//==============================================================================
// AGENT MANAGEMENT
//==============================================================================

int steering_create_agent(uint32_t entity_id, AgentType type, Vector2 position, SteeringAgent** agent) {
    if (g_agent_count >= g_max_agents) {
        return -1; // No space
    }
    
    SteeringAgent* new_agent = &g_agents[g_agent_count];
    memset(new_agent, 0, sizeof(SteeringAgent));
    
    new_agent->entity_id = entity_id;
    new_agent->type = type;
    new_agent->position = position;
    new_agent->velocity = (Vector2){0, 0};
    new_agent->acceleration = (Vector2){0, 0};
    new_agent->target = position;
    new_agent->wander_angle = (float)(rand() % 360) * M_PI / 180.0f;
    
    // Set agent-specific properties
    switch (type) {
        case AGENT_CITIZEN:
            new_agent->max_speed = 1.5f + (rand() % 100) / 200.0f; // 1.5-2.0 m/s
            new_agent->max_force = 2.0f;
            new_agent->radius = 0.4f;
            new_agent->mass = 70.0f;
            break;
            
        case AGENT_VEHICLE:
            new_agent->max_speed = 8.0f + (rand() % 400) / 100.0f; // 8-12 m/s
            new_agent->max_force = 4.0f;
            new_agent->radius = 1.5f;
            new_agent->mass = 1500.0f;
            break;
            
        case AGENT_EMERGENCY:
            new_agent->max_speed = 4.0f + (rand() % 200) / 100.0f; // 4-6 m/s
            new_agent->max_force = 3.0f;
            new_agent->radius = 0.6f;
            new_agent->mass = 80.0f;
            break;
    }
    
    // Default behavior weights
    new_agent->behavior_weights.seek = 1.0f;
    new_agent->behavior_weights.separation = 2.0f;
    new_agent->behavior_weights.alignment = 0.5f;
    new_agent->behavior_weights.cohesion = 0.3f;
    new_agent->behavior_weights.obstacle_avoidance = 3.0f;
    new_agent->behavior_weights.wander = 1.0f;
    new_agent->behavior_weights.path_following = 2.0f;
    
    new_agent->active = true;
    
    if (agent) {
        *agent = new_agent;
    }
    
    g_agent_count++;
    return 0;
}

int steering_remove_agent(uint32_t entity_id) {
    for (uint32_t i = 0; i < g_agent_count; i++) {
        if (g_agents[i].entity_id == entity_id) {
            // Swap with last agent to maintain dense array
            if (i < g_agent_count - 1) {
                g_agents[i] = g_agents[g_agent_count - 1];
            }
            g_agent_count--;
            return 0;
        }
    }
    return -1; // Agent not found
}

SteeringAgent* steering_get_agent(uint32_t entity_id) {
    for (uint32_t i = 0; i < g_agent_count; i++) {
        if (g_agents[i].entity_id == entity_id) {
            return &g_agents[i];
        }
    }
    return NULL;
}

//==============================================================================
// MAIN UPDATE FUNCTION
//==============================================================================

void steering_system_update(float delta_time) {
    // Update spatial grid for efficient neighbor queries
    update_spatial_grid();
    
    // Update each agent
    for (uint32_t i = 0; i < g_agent_count; i++) {
        SteeringAgent* agent = &g_agents[i];
        if (!agent->active) continue;
        
        // Find nearby agents
        const SteeringAgent* neighbors[MAX_NEIGHBORS];
        uint32_t neighbor_count = 0;
        find_neighbors(agent, neighbors, &neighbor_count);
        
        // Calculate steering forces
        Vector2 total_force = {0, 0};
        
        // Seek/Arrive behavior
        if (agent->has_target) {
            Vector2 seek_force = arrive(agent, agent->target);
            seek_force = vector2_multiply(seek_force, agent->behavior_weights.seek);
            total_force = vector2_add(total_force, seek_force);
        } else {
            // Wander when no target
            Vector2 wander_force = wander(agent);
            wander_force = vector2_multiply(wander_force, agent->behavior_weights.wander);
            total_force = vector2_add(total_force, wander_force);
        }
        
        // Separation (collision avoidance)
        Vector2 sep_force = separation(agent, neighbors, neighbor_count);
        sep_force = vector2_multiply(sep_force, agent->behavior_weights.separation);
        total_force = vector2_add(total_force, sep_force);
        
        // Alignment (match nearby agent velocities)
        Vector2 align_force = alignment(agent, neighbors, neighbor_count);
        align_force = vector2_multiply(align_force, agent->behavior_weights.alignment);
        total_force = vector2_add(total_force, align_force);
        
        // Cohesion (move towards group center)
        Vector2 cohes_force = cohesion(agent, neighbors, neighbor_count);
        cohes_force = vector2_multiply(cohes_force, agent->behavior_weights.cohesion);
        total_force = vector2_add(total_force, cohes_force);
        
        // Obstacle avoidance
        Vector2 avoid_force = obstacle_avoidance(agent);
        avoid_force = vector2_multiply(avoid_force, agent->behavior_weights.obstacle_avoidance);
        total_force = vector2_add(total_force, avoid_force);
        
        // Path following
        if (agent->path && agent->path_length > 0) {
            Vector2 path_force = path_following(agent);
            path_force = vector2_multiply(path_force, agent->behavior_weights.path_following);
            total_force = vector2_add(total_force, path_force);
        }
        
        // Limit steering force
        total_force = vector2_limit(total_force, agent->max_force);
        
        // Apply force (F = ma, so a = F/m)
        agent->acceleration = vector2_multiply(total_force, 1.0f / agent->mass);
        
        // Update velocity
        agent->velocity = vector2_add(agent->velocity, vector2_multiply(agent->acceleration, delta_time));
        agent->velocity = vector2_limit(agent->velocity, agent->max_speed);
        
        // Update position
        Vector2 displacement = vector2_multiply(agent->velocity, delta_time);
        agent->position = vector2_add(agent->position, displacement);
        
        // Update heading based on velocity
        if (vector2_length(agent->velocity) > 0.1f) {
            agent->heading = atan2f(agent->velocity.y, agent->velocity.x);
        }
        
        // Reset acceleration for next frame
        agent->acceleration = (Vector2){0, 0};
    }
}

//==============================================================================
// STEERING BEHAVIORS
//==============================================================================

static Vector2 seek(const SteeringAgent* agent, Vector2 target) {
    Vector2 desired = vector2_subtract(target, agent->position);
    desired = vector2_normalize(desired);
    desired = vector2_multiply(desired, agent->max_speed);
    
    Vector2 steer = vector2_subtract(desired, agent->velocity);
    return vector2_limit(steer, agent->max_force);
}

static Vector2 flee(const SteeringAgent* agent, Vector2 target) {
    Vector2 desired = vector2_subtract(agent->position, target);
    desired = vector2_normalize(desired);
    desired = vector2_multiply(desired, agent->max_speed);
    
    Vector2 steer = vector2_subtract(desired, agent->velocity);
    return vector2_limit(steer, agent->max_force);
}

static Vector2 arrive(const SteeringAgent* agent, Vector2 target) {
    Vector2 desired = vector2_subtract(target, agent->position);
    float distance = vector2_length(desired);
    
    if (distance < ARRIVAL_RADIUS) {
        return (Vector2){0, 0}; // Arrived
    }
    
    desired = vector2_normalize(desired);
    
    // Slow down when approaching target
    if (distance < SLOWING_RADIUS) {
        float speed = agent->max_speed * (distance / SLOWING_RADIUS);
        desired = vector2_multiply(desired, speed);
    } else {
        desired = vector2_multiply(desired, agent->max_speed);
    }
    
    Vector2 steer = vector2_subtract(desired, agent->velocity);
    return vector2_limit(steer, agent->max_force);
}

static Vector2 wander(SteeringAgent* agent) {
    // Calculate circle center ahead of agent
    Vector2 circle_center = vector2_normalize(agent->velocity);
    circle_center = vector2_multiply(circle_center, WANDER_CIRCLE_DISTANCE);
    circle_center = vector2_add(agent->position, circle_center);
    
    // Calculate target on circle
    Vector2 target;
    target.x = circle_center.x + WANDER_CIRCLE_RADIUS * cosf(agent->wander_angle);
    target.y = circle_center.y + WANDER_CIRCLE_RADIUS * sinf(agent->wander_angle);
    
    // Randomly change wander angle
    agent->wander_angle += (rand() % 200 - 100) / 100.0f * WANDER_ANGLE_CHANGE;
    
    return seek(agent, target);
}

static Vector2 separation(const SteeringAgent* agent, const SteeringAgent* neighbors[], uint32_t neighbor_count) {
    Vector2 steer = {0, 0};
    uint32_t count = 0;
    
    for (uint32_t i = 0; i < neighbor_count; i++) {
        const SteeringAgent* other = neighbors[i];
        if (other == agent) continue;
        
        float distance = vector2_distance(agent->position, other->position);
        float min_distance = agent->radius + other->radius + SEPARATION_RADIUS;
        
        if (distance < min_distance && distance > 0) {
            // Calculate repulsion force (inverse square law)
            Vector2 diff = vector2_subtract(agent->position, other->position);
            diff = vector2_normalize(diff);
            
            // Stronger force when closer
            float force_magnitude = min_distance / distance;
            diff = vector2_multiply(diff, force_magnitude);
            
            steer = vector2_add(steer, diff);
            count++;
        }
    }
    
    if (count > 0) {
        steer = vector2_multiply(steer, 1.0f / count);
        steer = vector2_normalize(steer);
        steer = vector2_multiply(steer, agent->max_speed);
        steer = vector2_subtract(steer, agent->velocity);
        steer = vector2_limit(steer, agent->max_force);
    }
    
    return steer;
}

static Vector2 alignment(const SteeringAgent* agent, const SteeringAgent* neighbors[], uint32_t neighbor_count) {
    Vector2 sum = {0, 0};
    uint32_t count = 0;
    
    for (uint32_t i = 0; i < neighbor_count; i++) {
        const SteeringAgent* other = neighbors[i];
        if (other == agent) continue;
        
        float distance = vector2_distance(agent->position, other->position);
        if (distance < ALIGNMENT_RADIUS) {
            sum = vector2_add(sum, other->velocity);
            count++;
        }
    }
    
    if (count > 0) {
        sum = vector2_multiply(sum, 1.0f / count);
        sum = vector2_normalize(sum);
        sum = vector2_multiply(sum, agent->max_speed);
        
        Vector2 steer = vector2_subtract(sum, agent->velocity);
        return vector2_limit(steer, agent->max_force);
    }
    
    return (Vector2){0, 0};
}

static Vector2 cohesion(const SteeringAgent* agent, const SteeringAgent* neighbors[], uint32_t neighbor_count) {
    Vector2 sum = {0, 0};
    uint32_t count = 0;
    
    for (uint32_t i = 0; i < neighbor_count; i++) {
        const SteeringAgent* other = neighbors[i];
        if (other == agent) continue;
        
        float distance = vector2_distance(agent->position, other->position);
        if (distance < COHESION_RADIUS) {
            sum = vector2_add(sum, other->position);
            count++;
        }
    }
    
    if (count > 0) {
        sum = vector2_multiply(sum, 1.0f / count);
        return seek(agent, sum);
    }
    
    return (Vector2){0, 0};
}

static Vector2 obstacle_avoidance(const SteeringAgent* agent) {
    // Simple obstacle avoidance - avoid world boundaries
    Vector2 force = {0, 0};
    
    // Avoid left boundary
    if (agent->position.x < OBSTACLE_AVOIDANCE_RADIUS) {
        force.x = OBSTACLE_AVOIDANCE_RADIUS - agent->position.x;
    }
    
    // Avoid right boundary (assuming world width of 100)
    if (agent->position.x > 100.0f - OBSTACLE_AVOIDANCE_RADIUS) {
        force.x = (100.0f - OBSTACLE_AVOIDANCE_RADIUS) - agent->position.x;
    }
    
    // Avoid top boundary
    if (agent->position.y < OBSTACLE_AVOIDANCE_RADIUS) {
        force.y = OBSTACLE_AVOIDANCE_RADIUS - agent->position.y;
    }
    
    // Avoid bottom boundary (assuming world height of 100)
    if (agent->position.y > 100.0f - OBSTACLE_AVOIDANCE_RADIUS) {
        force.y = (100.0f - OBSTACLE_AVOIDANCE_RADIUS) - agent->position.y;
    }
    
    if (vector2_length(force) > 0) {
        force = vector2_normalize(force);
        force = vector2_multiply(force, agent->max_speed);
        force = vector2_subtract(force, agent->velocity);
        force = vector2_limit(force, agent->max_force * 2.0f); // Stronger force for obstacles
    }
    
    return force;
}

static Vector2 path_following(const SteeringAgent* agent) {
    if (!agent->path || agent->path_length == 0) {
        return (Vector2){0, 0};
    }
    
    // Find closest point on path
    Vector2 target = agent->path[agent->current_path_index];
    float distance_to_target = vector2_distance(agent->position, target);
    
    // Move to next waypoint if close enough
    if (distance_to_target < PATH_FOLLOWING_RADIUS) {
        SteeringAgent* mutable_agent = (SteeringAgent*)agent;
        mutable_agent->current_path_index++;
        
        if (agent->current_path_index >= agent->path_length) {
            // Path completed
            if (agent->path_loop) {
                mutable_agent->current_path_index = 0;
            } else {
                mutable_agent->current_path_index = agent->path_length - 1;
                return (Vector2){0, 0};
            }
        }
        
        target = agent->path[agent->current_path_index];
    }
    
    return seek(agent, target);
}

//==============================================================================
// SPATIAL GRID FOR NEIGHBOR FINDING
//==============================================================================

static void update_spatial_grid(void) {
    // Clear grid
    memset(g_grid_counts, 0, sizeof(g_grid_counts));
    
    // Add agents to grid
    for (uint32_t i = 0; i < g_agent_count; i++) {
        if (!g_agents[i].active) continue;
        
        int grid_x = (int)(g_agents[i].position.x / GRID_SIZE);
        int grid_y = (int)(g_agents[i].position.y / GRID_SIZE);
        
        // Clamp to grid bounds
        grid_x = (grid_x < 0) ? 0 : (grid_x >= GRID_WIDTH) ? GRID_WIDTH - 1 : grid_x;
        grid_y = (grid_y < 0) ? 0 : (grid_y >= GRID_HEIGHT) ? GRID_HEIGHT - 1 : grid_y;
        
        // Add to grid cell if space available
        if (g_grid_counts[grid_x][grid_y] < 32) {
            g_spatial_grid[grid_x][grid_y][g_grid_counts[grid_x][grid_y]] = i;
            g_grid_counts[grid_x][grid_y]++;
        }
    }
}

static void find_neighbors(const SteeringAgent* agent, const SteeringAgent* neighbors[], uint32_t* neighbor_count) {
    *neighbor_count = 0;
    
    int grid_x = (int)(agent->position.x / GRID_SIZE);
    int grid_y = (int)(agent->position.y / GRID_SIZE);
    
    // Check 3x3 grid around agent
    for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
            int check_x = grid_x + dx;
            int check_y = grid_y + dy;
            
            if (check_x < 0 || check_x >= GRID_WIDTH || 
                check_y < 0 || check_y >= GRID_HEIGHT) continue;
            
            // Check all agents in this grid cell
            for (uint32_t i = 0; i < g_grid_counts[check_x][check_y]; i++) {
                uint32_t agent_index = g_spatial_grid[check_x][check_y][i];
                const SteeringAgent* other = &g_agents[agent_index];
                
                if (other == agent || !other->active) continue;
                
                float distance = vector2_distance(agent->position, other->position);
                if (distance < COHESION_RADIUS && *neighbor_count < MAX_NEIGHBORS) {
                    neighbors[*neighbor_count] = other;
                    (*neighbor_count)++;
                }
            }
        }
    }
}

//==============================================================================
// VECTOR MATH UTILITIES
//==============================================================================

static Vector2 vector2_add(Vector2 a, Vector2 b) {
    return (Vector2){a.x + b.x, a.y + b.y};
}

static Vector2 vector2_subtract(Vector2 a, Vector2 b) {
    return (Vector2){a.x - b.x, a.y - b.y};
}

static Vector2 vector2_multiply(Vector2 v, float scalar) {
    return (Vector2){v.x * scalar, v.y * scalar};
}

static Vector2 vector2_normalize(Vector2 v) {
    float length = vector2_length(v);
    if (length > 0) {
        return vector2_multiply(v, 1.0f / length);
    }
    return (Vector2){0, 0};
}

static float vector2_length(Vector2 v) {
    return sqrtf(v.x * v.x + v.y * v.y);
}

static float vector2_distance(Vector2 a, Vector2 b) {
    Vector2 diff = vector2_subtract(a, b);
    return vector2_length(diff);
}

static Vector2 vector2_limit(Vector2 v, float max_length) {
    float length = vector2_length(v);
    if (length > max_length) {
        return vector2_multiply(vector2_normalize(v), max_length);
    }
    return v;
}

static Vector2 vector2_truncate(Vector2 v, float max_length) {
    return vector2_limit(v, max_length);
}

//==============================================================================
// PUBLIC API
//==============================================================================

int steering_set_agent_target(uint32_t entity_id, Vector2 target) {
    SteeringAgent* agent = steering_get_agent(entity_id);
    if (!agent) return -1;
    
    agent->target = target;
    agent->has_target = true;
    return 0;
}

int steering_set_agent_path(uint32_t entity_id, const Vector2* path, uint32_t path_length, bool loop) {
    SteeringAgent* agent = steering_get_agent(entity_id);
    if (!agent) return -1;
    
    agent->path = path;
    agent->path_length = path_length;
    agent->current_path_index = 0;
    agent->path_loop = loop;
    return 0;
}

int steering_set_behavior_weights(uint32_t entity_id, const BehaviorWeights* weights) {
    SteeringAgent* agent = steering_get_agent(entity_id);
    if (!agent || !weights) return -1;
    
    agent->behavior_weights = *weights;
    return 0;
}

Vector2 steering_get_agent_position(uint32_t entity_id) {
    SteeringAgent* agent = steering_get_agent(entity_id);
    if (!agent) return (Vector2){0, 0};
    
    return agent->position;
}

Vector2 steering_get_agent_velocity(uint32_t entity_id) {
    SteeringAgent* agent = steering_get_agent(entity_id);
    if (!agent) return (Vector2){0, 0};
    
    return agent->velocity;
}

float steering_get_agent_heading(uint32_t entity_id) {
    SteeringAgent* agent = steering_get_agent(entity_id);
    if (!agent) return 0.0f;
    
    return agent->heading;
}

void steering_print_stats(void) {
    printf("\n=== Steering System Statistics ===\n");
    printf("Active Agents: %u / %u\n", g_agent_count, g_max_agents);
    
    uint32_t pedestrians = 0, vehicles = 0, cyclists = 0;
    float avg_speed = 0.0f;
    
    for (uint32_t i = 0; i < g_agent_count; i++) {
        if (!g_agents[i].active) continue;
        
        switch (g_agents[i].type) {
            case AGENT_CITIZEN: pedestrians++; break;
            case AGENT_VEHICLE: vehicles++; break;
            case AGENT_EMERGENCY: cyclists++; break;
        }
        
        avg_speed += vector2_length(g_agents[i].velocity);
    }
    
    if (g_agent_count > 0) {
        avg_speed /= g_agent_count;
    }
    
    printf("Pedestrians: %u, Vehicles: %u, Cyclists: %u\n", pedestrians, vehicles, cyclists);
    printf("Average Speed: %.2f m/s\n", avg_speed);
    printf("==================================\n\n");
}
