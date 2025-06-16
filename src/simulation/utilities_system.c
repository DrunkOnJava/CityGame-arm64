#include "utilities_system.h"
#include "zoning_system.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define MAX_UTILITY_BUILDINGS 100
#define POWER_PROPAGATION_DISTANCE 20
#define WATER_PROPAGATION_DISTANCE 15

// Power plant properties
static const struct {
    uint32_t capacity;  // MW
    float pollution;
    float cost;
} g_power_plant_info[] = {
    [POWER_COAL] = {150, 0.8f, 5000},
    [POWER_GAS] = {100, 0.5f, 4000},
    [POWER_NUCLEAR] = {300, 0.1f, 15000},
    [POWER_SOLAR] = {50, 0.0f, 8000},
    [POWER_WIND] = {40, 0.0f, 6000}
};

// Water source properties
static const struct {
    uint32_t capacity;  // Gallons per day
    float cost;
} g_water_source_info[] = {
    [WATER_PUMP] = {10000, 2000},
    [WATER_TOWER] = {50000, 5000},
    [WATER_TREATMENT] = {100000, 10000}
};

// Global utilities state
static struct {
    UtilityCell* grid;
    UtilityBuilding buildings[MAX_UTILITY_BUILDINGS];
    uint32_t building_count;
    uint32_t grid_width;
    uint32_t grid_height;
    UtilityStats stats;
} g_utilities_state = {0};

// Queue for flood-fill propagation
typedef struct {
    uint32_t* data;
    uint32_t capacity;
    uint32_t size;
    uint32_t front;
} Queue;

static Queue* queue_create(uint32_t capacity) {
    Queue* q = malloc(sizeof(Queue));
    q->data = malloc(capacity * sizeof(uint32_t));
    q->capacity = capacity;
    q->size = 0;
    q->front = 0;
    return q;
}

static void queue_destroy(Queue* q) {
    free(q->data);
    free(q);
}

static void queue_push(Queue* q, uint32_t value) {
    if (q->size < q->capacity) {
        q->data[(q->front + q->size) % q->capacity] = value;
        q->size++;
    }
}

static uint32_t queue_pop(Queue* q) {
    if (q->size > 0) {
        uint32_t value = q->data[q->front];
        q->front = (q->front + 1) % q->capacity;
        q->size--;
        return value;
    }
    return UINT32_MAX;
}

static bool queue_empty(Queue* q) {
    return q->size == 0;
}

int utilities_system_init(uint32_t grid_width, uint32_t grid_height) {
    g_utilities_state.grid_width = grid_width;
    g_utilities_state.grid_height = grid_height;
    
    g_utilities_state.grid = calloc(grid_width * grid_height, sizeof(UtilityCell));
    if (!g_utilities_state.grid) {
        return -1;
    }
    
    g_utilities_state.building_count = 0;
    memset(&g_utilities_state.stats, 0, sizeof(UtilityStats));
    
    return 0;
}

bool utilities_place_building(uint32_t x, uint32_t y, UtilityType utility_type, uint32_t subtype) {
    if (x >= g_utilities_state.grid_width || y >= g_utilities_state.grid_height) {
        return false;
    }
    
    if (g_utilities_state.building_count >= MAX_UTILITY_BUILDINGS) {
        return false;
    }
    
    UtilityBuilding* building = &g_utilities_state.buildings[g_utilities_state.building_count];
    building->x = x;
    building->y = y;
    building->current_load = 0;
    building->efficiency = 1.0f;
    building->operational = true;
    
    if (utility_type == UTILITY_POWER) {
        building->type.power_type = (PowerPlantType)subtype;
        building->capacity = g_power_plant_info[subtype].capacity;
    } else if (utility_type == UTILITY_WATER) {
        building->type.water_type = (WaterSourceType)subtype;
        building->capacity = g_water_source_info[subtype].capacity;
    }
    
    g_utilities_state.building_count++;
    
    // Trigger propagation
    utilities_propagate_power();
    utilities_propagate_water();
    
    return true;
}

void utilities_remove_building(uint32_t x, uint32_t y) {
    for (uint32_t i = 0; i < g_utilities_state.building_count; i++) {
        if (g_utilities_state.buildings[i].x == x && 
            g_utilities_state.buildings[i].y == y) {
            // Shift remaining buildings
            for (uint32_t j = i; j < g_utilities_state.building_count - 1; j++) {
                g_utilities_state.buildings[j] = g_utilities_state.buildings[j + 1];
            }
            g_utilities_state.building_count--;
            
            // Re-propagate utilities
            utilities_propagate_power();
            utilities_propagate_water();
            break;
        }
    }
}

static uint32_t get_cell_index(uint32_t x, uint32_t y) {
    return y * g_utilities_state.grid_width + x;
}

void utilities_propagate_power(void) {
    // Clear existing power grid
    for (uint32_t i = 0; i < g_utilities_state.grid_width * g_utilities_state.grid_height; i++) {
        g_utilities_state.grid[i].has_power = false;
        g_utilities_state.grid[i].power_level = 0.0f;
        g_utilities_state.grid[i].power_source_id = UINT32_MAX;
    }
    
    Queue* q = queue_create(g_utilities_state.grid_width * g_utilities_state.grid_height);
    
    // Start propagation from each power plant
    for (uint32_t b = 0; b < g_utilities_state.building_count; b++) {
        UtilityBuilding* building = &g_utilities_state.buildings[b];
        if (building->type.power_type == POWER_NONE || !building->operational) continue;
        
        uint32_t start_index = get_cell_index(building->x, building->y);
        g_utilities_state.grid[start_index].has_power = true;
        g_utilities_state.grid[start_index].power_level = 1.0f;
        g_utilities_state.grid[start_index].power_source_id = b;
        
        // BFS flood-fill
        queue_push(q, start_index);
        
        while (!queue_empty(q)) {
            uint32_t current = queue_pop(q);
            uint32_t cx = current % g_utilities_state.grid_width;
            uint32_t cy = current / g_utilities_state.grid_width;
            
            float current_power = g_utilities_state.grid[current].power_level;
            
            // Check 4 neighbors
            int dx[] = {0, 1, 0, -1};
            int dy[] = {-1, 0, 1, 0};
            
            for (int i = 0; i < 4; i++) {
                int nx = (int)cx + dx[i];
                int ny = (int)cy + dy[i];
                
                if (nx >= 0 && nx < (int)g_utilities_state.grid_width &&
                    ny >= 0 && ny < (int)g_utilities_state.grid_height) {
                    
                    uint32_t neighbor_index = get_cell_index(nx, ny);
                    
                    // Check if can propagate through this tile
                    const ZoneTile* tile = zoning_get_tile(nx, ny);
                    if (!tile || tile->zone_type == ZONE_NONE) continue;
                    
                    // Calculate power drop with distance
                    float distance = sqrtf((nx - building->x) * (nx - building->x) + 
                                         (ny - building->y) * (ny - building->y));
                    float power_drop = 1.0f - (distance / POWER_PROPAGATION_DISTANCE);
                    
                    if (power_drop > 0.1f && power_drop > g_utilities_state.grid[neighbor_index].power_level) {
                        g_utilities_state.grid[neighbor_index].has_power = true;
                        g_utilities_state.grid[neighbor_index].power_level = power_drop;
                        g_utilities_state.grid[neighbor_index].power_source_id = b;
                        
                        if (distance < POWER_PROPAGATION_DISTANCE - 1) {
                            queue_push(q, neighbor_index);
                        }
                    }
                }
            }
        }
    }
    
    queue_destroy(q);
}

void utilities_propagate_water(void) {
    // Similar to power but for water
    for (uint32_t i = 0; i < g_utilities_state.grid_width * g_utilities_state.grid_height; i++) {
        g_utilities_state.grid[i].has_water = false;
        g_utilities_state.grid[i].water_pressure = 0.0f;
        g_utilities_state.grid[i].water_source_id = UINT32_MAX;
    }
    
    Queue* q = queue_create(g_utilities_state.grid_width * g_utilities_state.grid_height);
    
    for (uint32_t b = 0; b < g_utilities_state.building_count; b++) {
        UtilityBuilding* building = &g_utilities_state.buildings[b];
        if (building->type.water_type == WATER_NONE || !building->operational) continue;
        
        uint32_t start_index = get_cell_index(building->x, building->y);
        g_utilities_state.grid[start_index].has_water = true;
        g_utilities_state.grid[start_index].water_pressure = 1.0f;
        g_utilities_state.grid[start_index].water_source_id = b;
        
        queue_push(q, start_index);
        
        while (!queue_empty(q)) {
            uint32_t current = queue_pop(q);
            uint32_t cx = current % g_utilities_state.grid_width;
            uint32_t cy = current / g_utilities_state.grid_width;
            
            int dx[] = {0, 1, 0, -1};
            int dy[] = {-1, 0, 1, 0};
            
            for (int i = 0; i < 4; i++) {
                int nx = (int)cx + dx[i];
                int ny = (int)cy + dy[i];
                
                if (nx >= 0 && nx < (int)g_utilities_state.grid_width &&
                    ny >= 0 && ny < (int)g_utilities_state.grid_height) {
                    
                    uint32_t neighbor_index = get_cell_index(nx, ny);
                    const ZoneTile* tile = zoning_get_tile(nx, ny);
                    if (!tile || tile->zone_type == ZONE_NONE) continue;
                    
                    float distance = sqrtf((nx - building->x) * (nx - building->x) + 
                                         (ny - building->y) * (ny - building->y));
                    float pressure_drop = 1.0f - (distance / WATER_PROPAGATION_DISTANCE);
                    
                    if (pressure_drop > 0.1f && pressure_drop > g_utilities_state.grid[neighbor_index].water_pressure) {
                        g_utilities_state.grid[neighbor_index].has_water = true;
                        g_utilities_state.grid[neighbor_index].water_pressure = pressure_drop;
                        g_utilities_state.grid[neighbor_index].water_source_id = b;
                        
                        if (distance < WATER_PROPAGATION_DISTANCE - 1) {
                            queue_push(q, neighbor_index);
                        }
                    }
                }
            }
        }
    }
    
    queue_destroy(q);
}

void utilities_system_update(float delta_time) {
    // Reset stats
    memset(&g_utilities_state.stats, 0, sizeof(UtilityStats));
    
    // Calculate total capacities
    for (uint32_t i = 0; i < g_utilities_state.building_count; i++) {
        UtilityBuilding* building = &g_utilities_state.buildings[i];
        if (building->operational) {
            if (building->type.power_type != POWER_NONE) {
                g_utilities_state.stats.total_power_capacity += building->capacity;
            } else if (building->type.water_type != WATER_NONE) {
                g_utilities_state.stats.total_water_capacity += building->capacity;
            }
        }
    }
    
    // Calculate demand and coverage
    for (uint32_t y = 0; y < g_utilities_state.grid_height; y++) {
        for (uint32_t x = 0; x < g_utilities_state.grid_width; x++) {
            const ZoneTile* tile = zoning_get_tile(x, y);
            if (!tile || tile->building_type == BUILDING_NONE) continue;
            
            uint32_t index = get_cell_index(x, y);
            
            // Power demand (simplified)
            uint32_t power_demand = (tile->population + tile->jobs) / 10;
            g_utilities_state.stats.total_power_demand += power_demand;
            
            if (g_utilities_state.grid[index].has_power) {
                g_utilities_state.stats.powered_buildings++;
                
                // Update zone tile utility status
                ZoneTile* mutable_tile = (ZoneTile*)tile;
                mutable_tile->has_power = true;
            } else {
                g_utilities_state.stats.unpowered_buildings++;
                ZoneTile* mutable_tile = (ZoneTile*)tile;
                mutable_tile->has_power = false;
            }
            
            // Water demand
            uint32_t water_demand = (tile->population + tile->jobs) * 100;
            g_utilities_state.stats.total_water_demand += water_demand;
            
            if (g_utilities_state.grid[index].has_water) {
                g_utilities_state.stats.watered_buildings++;
                ZoneTile* mutable_tile = (ZoneTile*)tile;
                mutable_tile->has_water = true;
            } else {
                g_utilities_state.stats.unwatered_buildings++;
                ZoneTile* mutable_tile = (ZoneTile*)tile;
                mutable_tile->has_water = false;
            }
        }
    }
    
    // Calculate grid efficiency
    uint32_t total_buildings = g_utilities_state.stats.powered_buildings + 
                              g_utilities_state.stats.unpowered_buildings;
    if (total_buildings > 0) {
        g_utilities_state.stats.grid_efficiency = 
            (float)g_utilities_state.stats.powered_buildings / total_buildings;
    }
    
    // Update building loads
    for (uint32_t i = 0; i < g_utilities_state.building_count; i++) {
        UtilityBuilding* building = &g_utilities_state.buildings[i];
        building->current_load = 0;
        
        // Calculate load from connected buildings
        for (uint32_t j = 0; j < g_utilities_state.grid_width * g_utilities_state.grid_height; j++) {
            if (g_utilities_state.grid[j].power_source_id == i) {
                building->current_load += 10; // Simplified
            }
        }
        
        // Check if overloaded
        if (building->current_load > building->capacity) {
            building->efficiency = (float)building->capacity / building->current_load;
        } else {
            building->efficiency = 1.0f;
        }
    }
}

bool utilities_has_power(uint32_t x, uint32_t y) {
    if (x >= g_utilities_state.grid_width || y >= g_utilities_state.grid_height) {
        return false;
    }
    return g_utilities_state.grid[get_cell_index(x, y)].has_power;
}

bool utilities_has_water(uint32_t x, uint32_t y) {
    if (x >= g_utilities_state.grid_width || y >= g_utilities_state.grid_height) {
        return false;
    }
    return g_utilities_state.grid[get_cell_index(x, y)].has_water;
}

const UtilityStats* utilities_get_stats(void) {
    return &g_utilities_state.stats;
}

const UtilityCell* utilities_get_grid(void) {
    return g_utilities_state.grid;
}

uint32_t utilities_get_power_capacity(PowerPlantType type) {
    if (type > 0 && type < sizeof(g_power_plant_info) / sizeof(g_power_plant_info[0])) {
        return g_power_plant_info[type].capacity;
    }
    return 0;
}

float utilities_get_power_pollution(PowerPlantType type) {
    if (type > 0 && type < sizeof(g_power_plant_info) / sizeof(g_power_plant_info[0])) {
        return g_power_plant_info[type].pollution;
    }
    return 0.0f;
}

void utilities_system_shutdown(void) {
    if (g_utilities_state.grid) {
        free(g_utilities_state.grid);
        g_utilities_state.grid = NULL;
    }
    g_utilities_state.building_count = 0;
}