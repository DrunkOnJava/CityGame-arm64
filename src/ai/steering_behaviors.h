// SimCity ARM64 Steering Behaviors
// Collision avoidance, flocking, and pathfinding for autonomous agents

#ifndef STEERING_BEHAVIORS_H
#define STEERING_BEHAVIORS_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Vector2 for 2D position and velocity
typedef struct {
    float x, y;
} Vector2;

// Agent types
typedef enum {
    AGENT_CITIZEN = 0,
    AGENT_VEHICLE = 1,
    AGENT_EMERGENCY = 2
} AgentType;

// Behavior weights for different steering behaviors
typedef struct {
    float seek;                 // Seek target weight
    float separation;           // Separation from neighbors weight
    float alignment;            // Alignment with neighbors weight
    float cohesion;             // Cohesion with neighbors weight
    float obstacle_avoidance;   // Obstacle avoidance weight
    float wander;               // Wandering behavior weight
    float path_following;       // Path following weight
} BehaviorWeights;

// Main steering agent structure
typedef struct {
    uint32_t entity_id;         // Associated entity ID
    AgentType type;             // Agent type
    
    // Physics
    Vector2 position;           // Current position
    Vector2 velocity;           // Current velocity
    Vector2 acceleration;       // Current acceleration
    float max_speed;            // Maximum speed
    float max_force;            // Maximum steering force
    float mass;                 // Agent mass
    float radius;               // Agent radius for collisions
    
    // Targeting
    bool has_target;            // Whether agent has a target
    Vector2 target;             // Current target position
    
    // Path following
    const Vector2* path;        // Current path waypoints
    uint32_t path_length;       // Number of waypoints
    uint32_t current_waypoint;  // Current waypoint index
    uint32_t current_path_index; // Current path index (alias)
    bool path_loop;             // Whether to loop the path
    
    // Wandering behavior state
    float wander_angle;         // Current wander angle
    float heading;              // Current heading angle
    
    // Behavior configuration
    BehaviorWeights behavior_weights;
    
    // State
    bool active;                // Whether agent is active
} SteeringAgent;

//==============================================================================
// SYSTEM MANAGEMENT
//==============================================================================

int steering_system_init(uint32_t max_agents);
void steering_system_shutdown(void);
void steering_system_update(float delta_time);

//==============================================================================
// AGENT MANAGEMENT
//==============================================================================

int steering_create_agent(uint32_t entity_id, AgentType type, Vector2 position, SteeringAgent** agent);
int steering_remove_agent(uint32_t entity_id);
SteeringAgent* steering_get_agent(uint32_t entity_id);

//==============================================================================
// BEHAVIOR CONTROL
//==============================================================================

int steering_set_agent_target(uint32_t entity_id, Vector2 target);
int steering_clear_agent_target(uint32_t entity_id);

//==============================================================================
// QUERY FUNCTIONS
//==============================================================================

Vector2 steering_get_agent_position(uint32_t entity_id);
Vector2 steering_get_agent_velocity(uint32_t entity_id);
uint32_t steering_get_active_agent_count(void);

//==============================================================================
// STATISTICS AND DEBUGGING
//==============================================================================

void steering_print_stats(void);

//==============================================================================
// VECTOR2 UTILITY FUNCTIONS (implemented as static functions)
//==============================================================================

#ifdef __cplusplus
}
#endif

#endif // STEERING_BEHAVIORS_H