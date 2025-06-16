#include "commuter_system.h"
#include "zoning_system.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <float.h>

// A* pathfinding node
typedef struct {
    uint32_t x, y;
    float g_cost; // Distance from start
    float h_cost; // Heuristic to goal
    float f_cost; // Total cost
    uint32_t parent_index;
    bool in_open_set;
    bool in_closed_set;
} PathNode;

// Global state
static struct {
    TrafficFlow traffic_flow;
    CommuteStats stats;
    PathNode* path_nodes; // Reusable pathfinding grid
    uint32_t grid_width;
    uint32_t grid_height;
} g_commuter_state = {0};

// Transport speeds (tiles per minute)
static const float g_transport_speeds[] = {
    [TRANSPORT_WALK] = 0.5f,
    [TRANSPORT_CAR] = 2.0f,
    [TRANSPORT_BUS] = 1.5f,
    [TRANSPORT_SUBWAY] = 3.0f,
    [TRANSPORT_TRAIN] = 4.0f
};

int commuter_system_init(uint32_t grid_width, uint32_t grid_height) {
    g_commuter_state.grid_width = grid_width;
    g_commuter_state.grid_height = grid_height;
    
    // Initialize traffic flow grid
    g_commuter_state.traffic_flow.width = grid_width;
    g_commuter_state.traffic_flow.height = grid_height;
    g_commuter_state.traffic_flow.flow_grid = calloc(grid_width * grid_height, sizeof(float));
    
    // Initialize pathfinding nodes
    g_commuter_state.path_nodes = calloc(grid_width * grid_height, sizeof(PathNode));
    
    if (!g_commuter_state.traffic_flow.flow_grid || !g_commuter_state.path_nodes) {
        commuter_system_shutdown();
        return -1;
    }
    
    // Reset stats
    memset(&g_commuter_state.stats, 0, sizeof(CommuteStats));
    
    return 0;
}

// Manhattan distance heuristic
static float heuristic(uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2) {
    return (float)(abs((int)x1 - (int)x2) + abs((int)y1 - (int)y2));
}

// Get tile index
static uint32_t get_tile_index(uint32_t x, uint32_t y) {
    return y * g_commuter_state.grid_width + x;
}

// Check if tile is passable
static bool is_passable(uint32_t x, uint32_t y) {
    if (x >= g_commuter_state.grid_width || y >= g_commuter_state.grid_height) {
        return false;
    }
    
    const ZoneTile* tile = zoning_get_tile(x, y);
    // Can pass through any zoned tile or road (simplified)
    return tile != NULL;
}

// Get movement cost (affected by traffic)
static float get_movement_cost(uint32_t from_x, uint32_t from_y, uint32_t to_x, uint32_t to_y, TransportMode mode) {
    float base_cost = 1.0f;
    
    // Get traffic congestion at destination
    uint32_t index = get_tile_index(to_x, to_y);
    float congestion = g_commuter_state.traffic_flow.flow_grid[index];
    
    // Cars and buses affected more by congestion
    float congestion_penalty = 0.0f;
    if (mode == TRANSPORT_CAR || mode == TRANSPORT_BUS) {
        congestion_penalty = congestion * 2.0f;
    }
    
    return base_cost + congestion_penalty;
}

bool commuter_find_path(Commuter* commuter) {
    // Reset pathfinding grid
    memset(g_commuter_state.path_nodes, 0, 
           g_commuter_state.grid_width * g_commuter_state.grid_height * sizeof(PathNode));
    
    // Initialize nodes
    for (uint32_t y = 0; y < g_commuter_state.grid_height; y++) {
        for (uint32_t x = 0; x < g_commuter_state.grid_width; x++) {
            uint32_t index = get_tile_index(x, y);
            g_commuter_state.path_nodes[index].x = x;
            g_commuter_state.path_nodes[index].y = y;
            g_commuter_state.path_nodes[index].g_cost = FLT_MAX;
            g_commuter_state.path_nodes[index].h_cost = 0;
            g_commuter_state.path_nodes[index].f_cost = FLT_MAX;
        }
    }
    
    // Start node
    uint32_t start_index = get_tile_index(commuter->origin_tile_x, commuter->origin_tile_y);
    uint32_t goal_index = get_tile_index(commuter->dest_tile_x, commuter->dest_tile_y);
    
    PathNode* start_node = &g_commuter_state.path_nodes[start_index];
    start_node->g_cost = 0;
    start_node->h_cost = heuristic(commuter->origin_tile_x, commuter->origin_tile_y,
                                   commuter->dest_tile_x, commuter->dest_tile_y);
    start_node->f_cost = start_node->h_cost;
    start_node->in_open_set = true;
    
    // A* pathfinding
    while (commuter->attempts_remaining > 0) {
        commuter->attempts_remaining--;
        
        // Find node with lowest f_cost in open set
        PathNode* current = NULL;
        float lowest_f = FLT_MAX;
        
        for (uint32_t i = 0; i < g_commuter_state.grid_width * g_commuter_state.grid_height; i++) {
            if (g_commuter_state.path_nodes[i].in_open_set && 
                g_commuter_state.path_nodes[i].f_cost < lowest_f) {
                current = &g_commuter_state.path_nodes[i];
                lowest_f = current->f_cost;
            }
        }
        
        if (!current) {
            // No path found
            return false;
        }
        
        uint32_t current_index = get_tile_index(current->x, current->y);
        
        // Check if reached goal
        if (current_index == goal_index) {
            // Reconstruct path
            uint32_t path_length = 0;
            uint32_t temp_path[256]; // Max path length
            
            uint32_t index = current_index;
            while (index != start_index && path_length < 256) {
                temp_path[path_length++] = index;
                index = g_commuter_state.path_nodes[index].parent_index;
            }
            temp_path[path_length++] = start_index;
            
            // Store path in commuter
            commuter->path_length = path_length;
            commuter->path_tiles = malloc(path_length * sizeof(uint32_t));
            
            // Reverse path to get start->goal order
            for (uint32_t i = 0; i < path_length; i++) {
                commuter->path_tiles[i] = temp_path[path_length - 1 - i];
            }
            
            commuter->successful = true;
            return true;
        }
        
        // Move current to closed set
        current->in_open_set = false;
        current->in_closed_set = true;
        
        // Check neighbors
        int dx[] = {0, 1, 0, -1};
        int dy[] = {-1, 0, 1, 0};
        
        for (int i = 0; i < 4; i++) {
            int nx = (int)current->x + dx[i];
            int ny = (int)current->y + dy[i];
            
            if (nx >= 0 && nx < (int)g_commuter_state.grid_width &&
                ny >= 0 && ny < (int)g_commuter_state.grid_height &&
                is_passable(nx, ny)) {
                
                uint32_t neighbor_index = get_tile_index(nx, ny);
                PathNode* neighbor = &g_commuter_state.path_nodes[neighbor_index];
                
                if (neighbor->in_closed_set) continue;
                
                float tentative_g = current->g_cost + 
                    get_movement_cost(current->x, current->y, nx, ny, commuter->transport_mode);
                
                if (!neighbor->in_open_set || tentative_g < neighbor->g_cost) {
                    neighbor->parent_index = current_index;
                    neighbor->g_cost = tentative_g;
                    neighbor->h_cost = heuristic(nx, ny, commuter->dest_tile_x, commuter->dest_tile_y);
                    neighbor->f_cost = neighbor->g_cost + neighbor->h_cost;
                    neighbor->in_open_set = true;
                }
            }
        }
    }
    
    // Failed to find path within attempt limit
    commuter->successful = false;
    return false;
}

float commuter_calculate_time(Commuter* commuter) {
    if (!commuter->successful || !commuter->path_tiles) {
        return MAX_COMMUTE_DISTANCE;
    }
    
    float total_time = 0.0f;
    float speed = g_transport_speeds[commuter->transport_mode];
    
    // Calculate time based on path and traffic
    for (uint32_t i = 1; i < commuter->path_length; i++) {
        uint32_t from_tile = commuter->path_tiles[i-1];
        uint32_t to_tile = commuter->path_tiles[i];
        
        // Get congestion factor
        float congestion = g_commuter_state.traffic_flow.flow_grid[to_tile];
        float congestion_factor = 1.0f + congestion;
        
        // Time = distance / (speed / congestion)
        total_time += 1.0f / (speed / congestion_factor);
    }
    
    commuter->commute_time = total_time;
    return total_time;
}

void commuter_update_traffic_flow(const Commuter* commuter) {
    if (!commuter->successful || !commuter->path_tiles) return;
    
    // Add traffic to each tile in path
    float traffic_increment = 0.01f;
    if (commuter->transport_mode == TRANSPORT_CAR) {
        traffic_increment = 0.02f;
    } else if (commuter->transport_mode == TRANSPORT_BUS) {
        traffic_increment = 0.015f;
    }
    
    for (uint32_t i = 0; i < commuter->path_length; i++) {
        g_commuter_state.traffic_flow.flow_grid[commuter->path_tiles[i]] += traffic_increment;
        
        // Cap at 1.0 (maximum congestion)
        if (g_commuter_state.traffic_flow.flow_grid[commuter->path_tiles[i]] > 1.0f) {
            g_commuter_state.traffic_flow.flow_grid[commuter->path_tiles[i]] = 1.0f;
        }
    }
}

void commuter_simulate_morning(void) {
    // Reset daily traffic (decay overnight)
    for (uint32_t i = 0; i < g_commuter_state.grid_width * g_commuter_state.grid_height; i++) {
        g_commuter_state.traffic_flow.flow_grid[i] *= 0.1f;
    }
    
    g_commuter_state.stats.total_commutes = 0;
    g_commuter_state.stats.successful_commutes = 0;
    g_commuter_state.stats.failed_commutes = 0;
    g_commuter_state.stats.jobs_filled = 0;
    g_commuter_state.stats.jobs_vacant = 0;
    
    float total_time = 0.0f;
    
    // For each residential tile, try to find jobs
    for (uint32_t y = 0; y < g_commuter_state.grid_height; y++) {
        for (uint32_t x = 0; x < g_commuter_state.grid_width; x++) {
            const ZoneTile* res_tile = zoning_get_tile(x, y);
            if (!res_tile || res_tile->population == 0) continue;
            if (res_tile->zone_type < ZONE_RESIDENTIAL_LOW || 
                res_tile->zone_type > ZONE_RESIDENTIAL_HIGH) continue;
            
            // Each resident tries to find work
            uint32_t workers = res_tile->population / 2; // Assume 50% are workers
            
            for (uint32_t w = 0; w < workers; w++) {
                Commuter commuter = {
                    .origin_tile_x = x,
                    .origin_tile_y = y,
                    .commute_type = COMMUTE_HOME_TO_WORK,
                    .transport_mode = (rand() % 100 < 70) ? TRANSPORT_CAR : TRANSPORT_BUS,
                    .attempts_remaining = MAX_COMMUTE_ATTEMPTS,
                    .successful = false
                };
                
                // Try to find nearest job
                bool found_job = false;
                float best_distance = FLT_MAX;
                
                for (uint32_t jy = 0; jy < g_commuter_state.grid_height; jy++) {
                    for (uint32_t jx = 0; jx < g_commuter_state.grid_width; jx++) {
                        const ZoneTile* job_tile = zoning_get_tile(jx, jy);
                        if (!job_tile || job_tile->jobs == 0) continue;
                        if (job_tile->zone_type < ZONE_COMMERCIAL_LOW) continue;
                        
                        float distance = heuristic(x, y, jx, jy);
                        if (distance < best_distance && distance < MAX_COMMUTE_DISTANCE) {
                            commuter.dest_tile_x = jx;
                            commuter.dest_tile_y = jy;
                            best_distance = distance;
                            found_job = true;
                        }
                    }
                }
                
                if (found_job && commuter_find_path(&commuter)) {
                    float time = commuter_calculate_time(&commuter);
                    
                    if (time < MAX_COMMUTE_DISTANCE) {
                        commuter_update_traffic_flow(&commuter);
                        g_commuter_state.stats.successful_commutes++;
                        g_commuter_state.stats.jobs_filled++;
                        total_time += time;
                    } else {
                        g_commuter_state.stats.failed_commutes++;
                    }
                    
                    if (commuter.path_tiles) free(commuter.path_tiles);
                } else {
                    g_commuter_state.stats.failed_commutes++;
                }
                
                g_commuter_state.stats.total_commutes++;
            }
        }
    }
    
    // Update average commute time
    if (g_commuter_state.stats.successful_commutes > 0) {
        g_commuter_state.stats.average_commute_time = 
            total_time / g_commuter_state.stats.successful_commutes;
    }
    
    // Calculate congestion level
    float total_congestion = 0.0f;
    uint32_t congested_tiles = 0;
    for (uint32_t i = 0; i < g_commuter_state.grid_width * g_commuter_state.grid_height; i++) {
        if (g_commuter_state.traffic_flow.flow_grid[i] > 0.1f) {
            total_congestion += g_commuter_state.traffic_flow.flow_grid[i];
            congested_tiles++;
        }
    }
    
    if (congested_tiles > 0) {
        g_commuter_state.stats.congestion_level = total_congestion / congested_tiles;
    }
}

void commuter_simulate_evening(void) {
    // Similar to morning but reversed direction
    // For brevity, just decay traffic
    for (uint32_t i = 0; i < g_commuter_state.grid_width * g_commuter_state.grid_height; i++) {
        g_commuter_state.traffic_flow.flow_grid[i] *= 0.8f;
    }
}

const CommuteStats* commuter_get_stats(void) {
    return &g_commuter_state.stats;
}

const TrafficFlow* commuter_get_traffic_flow(void) {
    return &g_commuter_state.traffic_flow;
}

void commuter_system_shutdown(void) {
    if (g_commuter_state.traffic_flow.flow_grid) {
        free(g_commuter_state.traffic_flow.flow_grid);
        g_commuter_state.traffic_flow.flow_grid = NULL;
    }
    
    if (g_commuter_state.path_nodes) {
        free(g_commuter_state.path_nodes);
        g_commuter_state.path_nodes = NULL;
    }
}