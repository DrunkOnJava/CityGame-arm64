//==============================================================================
// SimCity ARM64 Assembly - AI Systems Integration Header
// Sub-Agent 5: AI Systems Coordinator
//==============================================================================
// Unified AI coordination system interface
//==============================================================================

#ifndef AI_INTEGRATION_H
#define AI_INTEGRATION_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

//==============================================================================
// Agent Types
//==============================================================================
#define AGENT_TYPE_CITIZEN          0
#define AGENT_TYPE_VEHICLE          1
#define AGENT_TYPE_EMERGENCY        2

//==============================================================================
// Priority Levels
//==============================================================================
#define PRIORITY_LOW                1
#define PRIORITY_NORMAL             2
#define PRIORITY_HIGH               3
#define PRIORITY_EMERGENCY          4

//==============================================================================
// Core AI System Interface
//==============================================================================

// System lifecycle
int ai_system_init(const uint8_t* world_tiles, uint32_t width, uint32_t height);
void ai_system_shutdown(void);
void ai_system_update(float delta_time);

// Agent management
void ai_spawn_agent(uint32_t agent_id, uint32_t agent_type, float x, float y);

// System interfaces
uint32_t ai_request_pathfinding(uint32_t start_x, uint32_t start_y, 
                               uint32_t end_x, uint32_t end_y,
                               uint32_t agent_type, uint32_t priority);

uint32_t ai_request_transit_route(uint32_t passenger_id, uint32_t start_x, uint32_t start_y,
                                 uint32_t dest_x, uint32_t dest_y);

// Performance monitoring
void ai_print_performance_stats(void);

#ifdef __cplusplus
}
#endif

#endif // AI_INTEGRATION_H