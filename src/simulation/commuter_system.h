#ifndef COMMUTER_SYSTEM_H
#define COMMUTER_SYSTEM_H

#include <stdint.h>
#include <stdbool.h>

// Maximum pathfinding attempts per commuter (SimCity 4 rule)
#define MAX_COMMUTE_ATTEMPTS 6
#define MAX_COMMUTE_DISTANCE 60.0f // minutes

// Commute types
typedef enum {
    COMMUTE_HOME_TO_WORK,
    COMMUTE_WORK_TO_HOME,
    COMMUTE_HOME_TO_SHOP,
    COMMUTE_HOME_TO_SCHOOL
} CommuteType;

// Transport modes
typedef enum {
    TRANSPORT_WALK,
    TRANSPORT_CAR,
    TRANSPORT_BUS,
    TRANSPORT_SUBWAY,
    TRANSPORT_TRAIN
} TransportMode;

// Commuter agent (represents abstract trip, not persistent sim)
typedef struct {
    uint32_t origin_tile_x, origin_tile_y;
    uint32_t dest_tile_x, dest_tile_y;
    CommuteType commute_type;
    TransportMode transport_mode;
    float commute_time;
    uint8_t attempts_remaining;
    bool successful;
    uint32_t path_length;
    uint32_t* path_tiles; // Array of tile indices
} Commuter;

// Commute statistics
typedef struct {
    uint32_t total_commutes;
    uint32_t successful_commutes;
    uint32_t failed_commutes;
    float average_commute_time;
    float congestion_level;
    uint32_t jobs_filled;
    uint32_t jobs_vacant;
} CommuteStats;

// Traffic flow data
typedef struct {
    float* flow_grid; // Traffic volume per tile
    uint32_t width;
    uint32_t height;
} TrafficFlow;

// Initialize commuter system
int commuter_system_init(uint32_t grid_width, uint32_t grid_height);

// Simulate morning commute (residential -> commercial/industrial)
void commuter_simulate_morning(void);

// Simulate evening commute (commercial/industrial -> residential)
void commuter_simulate_evening(void);

// Find path from origin to destination
bool commuter_find_path(Commuter* commuter);

// Calculate commute time with traffic
float commuter_calculate_time(Commuter* commuter);

// Update traffic flow based on commutes
void commuter_update_traffic_flow(const Commuter* commuter);

// Get commute statistics
const CommuteStats* commuter_get_stats(void);

// Get traffic flow data
const TrafficFlow* commuter_get_traffic_flow(void);

// Cleanup
void commuter_system_shutdown(void);

#endif // COMMUTER_SYSTEM_H