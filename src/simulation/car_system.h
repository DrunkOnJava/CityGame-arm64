#ifndef CAR_SYSTEM_H
#define CAR_SYSTEM_H

#include <stdint.h>
#include <stdbool.h>

#define MAX_CARS 100
#define CAR_SPEED 20.0f // pixels per second

// Road graph node
typedef struct RoadNode {
    uint32_t x, y;
    struct RoadNode* neighbors[4]; // N, E, S, W
    uint32_t neighbor_count;
    uint32_t id;
} RoadNode;

// Car agent
typedef struct {
    float x, y;           // World position
    float target_x, target_y; // Next node position
    RoadNode* current_node;
    RoadNode* next_node;
    RoadNode** path;      // Array of nodes
    uint32_t path_length;
    uint32_t path_index;
    float speed;
    float rotation;       // In radians
    bool active;
} Car;

// Car system state
typedef struct {
    Car cars[MAX_CARS];
    uint32_t car_count;
    RoadNode* road_nodes;
    uint32_t node_count;
    uint32_t* road_grid;  // Quick lookup: grid[y*width+x] = node_id or UINT32_MAX
} CarSystem;

// Initialize car system
int car_system_init(uint32_t grid_width, uint32_t grid_height);

// Build road graph from current road tiles
void car_system_build_road_graph(void);

// Spawn a new car at random road location
void car_system_spawn_car(void);

// Update all cars
void car_system_update(float delta_time);

// Get car data for rendering
const Car* car_system_get_cars(uint32_t* count);

// Check if tile has road
bool car_system_has_road(uint32_t x, uint32_t y);

// Place/remove road
void car_system_set_road(uint32_t x, uint32_t y, bool has_road);

// Cleanup
void car_system_shutdown(void);

#endif // CAR_SYSTEM_H