#include "car_system.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <float.h>

static CarSystem g_car_system = {0};
static uint32_t g_grid_width = 0;
static uint32_t g_grid_height = 0;
static bool* g_road_tiles = NULL;

// A* pathfinding node
typedef struct {
    RoadNode* node;
    float g_cost;
    float h_cost;
    float f_cost;
    struct AStarNode* parent;
} AStarNode;

int car_system_init(uint32_t grid_width, uint32_t grid_height) {
    g_grid_width = grid_width;
    g_grid_height = grid_height;
    
    // Allocate road tile tracking
    g_road_tiles = calloc(grid_width * grid_height, sizeof(bool));
    if (!g_road_tiles) return -1;
    
    // Allocate road grid lookup
    g_car_system.road_grid = malloc(grid_width * grid_height * sizeof(uint32_t));
    if (!g_car_system.road_grid) {
        free(g_road_tiles);
        return -1;
    }
    
    // Initialize to no roads
    for (uint32_t i = 0; i < grid_width * grid_height; i++) {
        g_car_system.road_grid[i] = UINT32_MAX;
    }
    
    // Allocate space for road nodes
    g_car_system.road_nodes = malloc(grid_width * grid_height * sizeof(RoadNode));
    if (!g_car_system.road_nodes) {
        free(g_road_tiles);
        free(g_car_system.road_grid);
        return -1;
    }
    
    g_car_system.car_count = 0;
    g_car_system.node_count = 0;
    
    return 0;
}

bool car_system_has_road(uint32_t x, uint32_t y) {
    if (x >= g_grid_width || y >= g_grid_height) return false;
    return g_road_tiles[y * g_grid_width + x];
}

void car_system_set_road(uint32_t x, uint32_t y, bool has_road) {
    if (x >= g_grid_width || y >= g_grid_height) return;
    
    g_road_tiles[y * g_grid_width + x] = has_road;
    
    // Rebuild road graph when roads change
    car_system_build_road_graph();
}

void car_system_build_road_graph(void) {
    // Clear existing nodes
    g_car_system.node_count = 0;
    
    // Clear grid lookup
    for (uint32_t i = 0; i < g_grid_width * g_grid_height; i++) {
        g_car_system.road_grid[i] = UINT32_MAX;
    }
    
    // Create nodes for all road tiles
    for (uint32_t y = 0; y < g_grid_height; y++) {
        for (uint32_t x = 0; x < g_grid_width; x++) {
            if (g_road_tiles[y * g_grid_width + x]) {
                RoadNode* node = &g_car_system.road_nodes[g_car_system.node_count];
                node->x = x;
                node->y = y;
                node->id = g_car_system.node_count;
                node->neighbor_count = 0;
                
                // Store in grid lookup
                g_car_system.road_grid[y * g_grid_width + x] = node->id;
                
                g_car_system.node_count++;
            }
        }
    }
    
    // Connect neighbors
    for (uint32_t i = 0; i < g_car_system.node_count; i++) {
        RoadNode* node = &g_car_system.road_nodes[i];
        
        // Check 4 directions
        int dx[] = {0, 1, 0, -1};
        int dy[] = {-1, 0, 1, 0};
        
        for (int d = 0; d < 4; d++) {
            int nx = (int)node->x + dx[d];
            int ny = (int)node->y + dy[d];
            
            if (nx >= 0 && nx < (int)g_grid_width && 
                ny >= 0 && ny < (int)g_grid_height) {
                uint32_t neighbor_id = g_car_system.road_grid[ny * g_grid_width + nx];
                if (neighbor_id != UINT32_MAX) {
                    node->neighbors[node->neighbor_count++] = &g_car_system.road_nodes[neighbor_id];
                }
            }
        }
    }
}

// Manhattan distance heuristic
static float heuristic(RoadNode* a, RoadNode* b) {
    return (float)(abs((int)a->x - (int)b->x) + abs((int)a->y - (int)b->y));
}

// Simple A* pathfinding
static RoadNode** find_path(RoadNode* start, RoadNode* goal, uint32_t* path_length) {
    if (!start || !goal) return NULL;
    
    // Simplified A* - for brevity, using static arrays
    AStarNode nodes[1000];
    bool closed[1000] = {0};
    bool open[1000] = {0};
    uint32_t open_count = 0;
    
    // Initialize start node
    nodes[start->id].node = start;
    nodes[start->id].g_cost = 0;
    nodes[start->id].h_cost = heuristic(start, goal);
    nodes[start->id].f_cost = nodes[start->id].h_cost;
    nodes[start->id].parent = NULL;
    open[start->id] = true;
    open_count++;
    
    while (open_count > 0) {
        // Find lowest f_cost in open set
        float lowest_f = FLT_MAX;
        uint32_t current_id = UINT32_MAX;
        
        for (uint32_t i = 0; i < g_car_system.node_count; i++) {
            if (open[i] && nodes[i].f_cost < lowest_f) {
                lowest_f = nodes[i].f_cost;
                current_id = i;
            }
        }
        
        if (current_id == UINT32_MAX) break;
        
        RoadNode* current = g_car_system.road_nodes[current_id].id == current_id ? 
                           &g_car_system.road_nodes[current_id] : NULL;
        if (!current) break;
        
        // Check if reached goal
        if (current->id == goal->id) {
            // Reconstruct path
            uint32_t count = 0;
            AStarNode* n = &nodes[current->id];
            while (n) {
                count++;
                n = n->parent;
            }
            
            RoadNode** path = malloc(count * sizeof(RoadNode*));
            n = &nodes[current->id];
            for (int i = count - 1; i >= 0; i--) {
                path[i] = n->node;
                n = n->parent;
            }
            
            *path_length = count;
            return path;
        }
        
        // Move to closed set
        open[current->id] = false;
        closed[current->id] = true;
        open_count--;
        
        // Check neighbors
        for (uint32_t i = 0; i < current->neighbor_count; i++) {
            RoadNode* neighbor = current->neighbors[i];
            if (closed[neighbor->id]) continue;
            
            float tentative_g = nodes[current->id].g_cost + 1.0f;
            
            if (!open[neighbor->id] || tentative_g < nodes[neighbor->id].g_cost) {
                nodes[neighbor->id].node = neighbor;
                nodes[neighbor->id].parent = &nodes[current->id];
                nodes[neighbor->id].g_cost = tentative_g;
                nodes[neighbor->id].h_cost = heuristic(neighbor, goal);
                nodes[neighbor->id].f_cost = tentative_g + nodes[neighbor->id].h_cost;
                
                if (!open[neighbor->id]) {
                    open[neighbor->id] = true;
                    open_count++;
                }
            }
        }
    }
    
    return NULL;
}

void car_system_spawn_car(void) {
    if (g_car_system.car_count >= MAX_CARS || g_car_system.node_count < 2) return;
    
    // Find inactive car slot
    Car* car = NULL;
    for (uint32_t i = 0; i < MAX_CARS; i++) {
        if (!g_car_system.cars[i].active) {
            car = &g_car_system.cars[i];
            break;
        }
    }
    
    if (!car) return;
    
    // Pick random start and end nodes
    uint32_t start_id = rand() % g_car_system.node_count;
    uint32_t end_id = rand() % g_car_system.node_count;
    
    if (start_id == end_id) return;
    
    RoadNode* start = &g_car_system.road_nodes[start_id];
    RoadNode* end = &g_car_system.road_nodes[end_id];
    
    // Find path
    uint32_t path_length;
    RoadNode** path = find_path(start, end, &path_length);
    
    if (!path || path_length < 2) {
        if (path) free(path);
        return;
    }
    
    // Initialize car
    car->active = true;
    car->path = path;
    car->path_length = path_length;
    car->path_index = 0;
    car->current_node = path[0];
    car->next_node = path[1];
    car->x = (float)(car->current_node->x * 40 + 20); // Center of tile
    car->y = (float)(car->current_node->y * 40 + 20);
    car->target_x = (float)(car->next_node->x * 40 + 20);
    car->target_y = (float)(car->next_node->y * 40 + 20);
    car->speed = CAR_SPEED;
    car->rotation = atan2f(car->target_y - car->y, car->target_x - car->x);
    
    g_car_system.car_count++;
}

void car_system_update(float delta_time) {
    for (uint32_t i = 0; i < MAX_CARS; i++) {
        Car* car = &g_car_system.cars[i];
        if (!car->active) continue;
        
        // Move toward target
        float dx = car->target_x - car->x;
        float dy = car->target_y - car->y;
        float dist = sqrtf(dx * dx + dy * dy);
        
        if (dist < 2.0f) {
            // Reached target node
            car->path_index++;
            
            if (car->path_index >= car->path_length - 1) {
                // Reached destination - deactivate
                car->active = false;
                g_car_system.car_count--;
                if (car->path) {
                    free(car->path);
                    car->path = NULL;
                }
            } else {
                // Move to next node
                car->current_node = car->next_node;
                car->next_node = car->path[car->path_index + 1];
                car->target_x = (float)(car->next_node->x * 40 + 20);
                car->target_y = (float)(car->next_node->y * 40 + 20);
                car->rotation = atan2f(car->target_y - car->y, car->target_x - car->x);
            }
        } else {
            // Move toward target
            float move_dist = car->speed * delta_time;
            car->x += (dx / dist) * move_dist;
            car->y += (dy / dist) * move_dist;
        }
    }
}

const Car* car_system_get_cars(uint32_t* count) {
    *count = 0;
    for (uint32_t i = 0; i < MAX_CARS; i++) {
        if (g_car_system.cars[i].active) (*count)++;
    }
    return g_car_system.cars;
}

void car_system_shutdown(void) {
    // Free paths
    for (uint32_t i = 0; i < MAX_CARS; i++) {
        if (g_car_system.cars[i].path) {
            free(g_car_system.cars[i].path);
        }
    }
    
    if (g_road_tiles) {
        free(g_road_tiles);
        g_road_tiles = NULL;
    }
    
    if (g_car_system.road_grid) {
        free(g_car_system.road_grid);
        g_car_system.road_grid = NULL;
    }
    
    if (g_car_system.road_nodes) {
        free(g_car_system.road_nodes);
        g_car_system.road_nodes = NULL;
    }
}