// SimCity ARM64 Steering Behaviors
// Collision avoidance, flocking, and navigation for realistic agent movement

#ifndef STEERING_BEHAVIORS_H
#define STEERING_BEHAVIORS_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Vector2 for 2D positions and velocities
typedef struct {
    float x, y;
} Vector2;

// Agent types
typedef enum {
    AGENT_TYPE_PEDESTRIAN = 0,
    AGENT_TYPE_VEHICLE = 1,
    AGENT_TYPE_CYCLIST = 2
} AgentType;

// Behavior weights for fine-tuning agent behavior
typedef struct {
    float seek;                 // Seeking target weight
    float separation;           // Collision avoidance weight
    float alignment;            // Velocity matching weight
    float cohesion;             // Group cohesion weight
    float obstacle_avoidance;   // Static obstacle avoidance weight
    float wander;               // Random wandering weight
    float path_following;       // Path following weight
} BehaviorWeights;

// Steering agent structure
typedef struct {
    uint32_t entity_id;         // Corresponding entity ID
    AgentType type;             // Agent type
    
    // Physics properties
    Vector2 position;           // Current position
    Vector2 velocity;           // Current velocity
    Vector2 acceleration;       // Current acceleration
    float heading;              // Current heading angle (radians)
    
    // Movement constraints
    float max_speed;            // Maximum speed
    float max_force;            // Maximum steering force
    float radius;               // Agent radius for collision
    float mass;                 // Agent mass
    
    // Target and navigation
    Vector2 target;             // Current target position
    bool has_target;            // Whether agent has a target
    const Vector2* path;        // Path waypoints (external data)
    uint32_t path_length;       // Number of waypoints
    uint32_t current_path_index; // Current waypoint index
    bool path_loop;             // Whether to loop the path
    
    // Wandering behavior state
    float wander_angle;         // Current wander angle
    
    // Behavior configuration
    BehaviorWeights behavior_weights;
    
    // State
    bool active;                // Whether agent is active
} SteeringAgent;\n\n//==============================================================================\n// SYSTEM MANAGEMENT\n//==============================================================================\n\n/**\n * Initialize the steering system\n * @param max_agents Maximum number of agents to support\n * @return 0 on success, -1 on failure\n */\nint steering_system_init(uint32_t max_agents);\n\n/**\n * Shutdown the steering system and cleanup resources\n */\nvoid steering_system_shutdown(void);\n\n/**\n * Update all steering agents\n * @param delta_time Time step in seconds\n */\nvoid steering_system_update(float delta_time);\n\n//==============================================================================\n// AGENT MANAGEMENT\n//==============================================================================\n\n/**\n * Create a new steering agent\n * @param entity_id Associated entity ID\n * @param type Agent type\n * @param position Initial position\n * @param agent Output parameter for created agent (optional)\n * @return 0 on success, -1 on failure\n */\nint steering_create_agent(uint32_t entity_id, AgentType type, Vector2 position, SteeringAgent** agent);\n\n/**\n * Remove a steering agent\n * @param entity_id Entity ID of agent to remove\n * @return 0 on success, -1 if not found\n */\nint steering_remove_agent(uint32_t entity_id);\n\n/**\n * Get steering agent by entity ID\n * @param entity_id Entity ID\n * @return Pointer to agent or NULL if not found\n */\nSteeringAgent* steering_get_agent(uint32_t entity_id);\n\n//==============================================================================\n// BEHAVIOR CONTROL\n//==============================================================================\n\n/**\n * Set target position for an agent\n * @param entity_id Entity ID\n * @param target Target position\n * @return 0 on success, -1 on failure\n */\nint steering_set_agent_target(uint32_t entity_id, Vector2 target);\n\n/**\n * Set path for an agent to follow\n * @param entity_id Entity ID\n * @param path Array of waypoint positions\n * @param path_length Number of waypoints\n * @param loop Whether to loop the path\n * @return 0 on success, -1 on failure\n */\nint steering_set_agent_path(uint32_t entity_id, const Vector2* path, uint32_t path_length, bool loop);\n\n/**\n * Set behavior weights for an agent\n * @param entity_id Entity ID\n * @param weights Behavior weights\n * @return 0 on success, -1 on failure\n */\nint steering_set_behavior_weights(uint32_t entity_id, const BehaviorWeights* weights);\n\n/**\n * Clear target for an agent (switches to wandering)\n * @param entity_id Entity ID\n * @return 0 on success, -1 on failure\n */\nint steering_clear_agent_target(uint32_t entity_id);\n\n//==============================================================================\n// QUERY FUNCTIONS\n//==============================================================================\n\n/**\n * Get agent position\n * @param entity_id Entity ID\n * @return Current position\n */\nVector2 steering_get_agent_position(uint32_t entity_id);\n\n/**\n * Get agent velocity\n * @param entity_id Entity ID\n * @return Current velocity\n */\nVector2 steering_get_agent_velocity(uint32_t entity_id);\n\n/**\n * Get agent heading\n * @param entity_id Entity ID\n * @return Current heading in radians\n */\nfloat steering_get_agent_heading(uint32_t entity_id);\n\n/**\n * Get number of active agents\n * @return Number of active agents\n */\nuint32_t steering_get_active_agent_count(void);\n\n//==============================================================================\n// STATISTICS AND DEBUGGING\n//==============================================================================\n\n/**\n * Print steering system statistics\n */\nvoid steering_print_stats(void);\n\n//==============================================================================\n// UTILITY FUNCTIONS\n//==============================================================================\n\n/**\n * Create default behavior weights for agent type\n * @param type Agent type\n * @return Default behavior weights\n */\nstatic inline BehaviorWeights steering_default_weights(AgentType type) {\n    BehaviorWeights weights;\n    \n    switch (type) {\n        case AGENT_TYPE_PEDESTRIAN:\n            weights.seek = 1.0f;\n            weights.separation = 2.0f;\n            weights.alignment = 0.5f;\n            weights.cohesion = 0.3f;\n            weights.obstacle_avoidance = 3.0f;\n            weights.wander = 1.0f;\n            weights.path_following = 2.0f;\n            break;\n            \n        case AGENT_TYPE_VEHICLE:\n            weights.seek = 1.5f;\n            weights.separation = 3.0f;\n            weights.alignment = 1.0f;\n            weights.cohesion = 0.1f;\n            weights.obstacle_avoidance = 4.0f;\n            weights.wander = 0.5f;\n            weights.path_following = 3.0f;\n            break;\n            \n        case AGENT_TYPE_CYCLIST:\n            weights.seek = 1.2f;\n            weights.separation = 2.5f;\n            weights.alignment = 0.8f;\n            weights.cohesion = 0.2f;\n            weights.obstacle_avoidance = 3.5f;\n            weights.wander = 0.8f;\n            weights.path_following = 2.5f;\n            break;\n    }\n    \n    return weights;\n}\n\n/**\n * Create Vector2 from coordinates\n * @param x X coordinate\n * @param y Y coordinate\n * @return Vector2 structure\n */\nstatic inline Vector2 vector2_make(float x, float y) {\n    return (Vector2){x, y};\n}\n\n/**\n * Calculate distance between two points\n * @param a First point\n * @param b Second point\n * @return Distance\n */\nstatic inline float vector2_distance_inline(Vector2 a, Vector2 b) {\n    float dx = a.x - b.x;\n    float dy = a.y - b.y;\n    return sqrtf(dx * dx + dy * dy);\n}\n\n/**\n * Check if agent is near target\n * @param entity_id Entity ID\n * @param target Target position\n * @param threshold Distance threshold\n * @return true if within threshold\n */\nstatic inline bool steering_agent_near_target(uint32_t entity_id, Vector2 target, float threshold) {\n    Vector2 pos = steering_get_agent_position(entity_id);\n    return vector2_distance_inline(pos, target) < threshold;\n}\n\n#ifdef __cplusplus\n}\n#endif\n\n#endif // STEERING_BEHAVIORS_H