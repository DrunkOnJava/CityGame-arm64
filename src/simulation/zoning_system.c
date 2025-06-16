#include "zoning_system.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

// Global zoning grid
static ZoningGrid g_zoning_grid = {0};
static uint32_t g_update_tick = 0;

// Building properties
static const struct {
    const char* name;
    uint32_t capacity; // Population or jobs
    float min_development; // Minimum development level to appear
    float power_requirement;
    float water_requirement;
} g_building_info[] = {
    [BUILDING_NONE] = {"Empty Lot", 0, 0.0f, 0.0f, 0.0f},
    // Residential
    [BUILDING_HOUSE_SMALL] = {"Small House", 4, 0.1f, 1.0f, 0.5f},
    [BUILDING_HOUSE_MEDIUM] = {"Medium House", 8, 0.3f, 1.5f, 1.0f},
    [BUILDING_APARTMENT_LOW] = {"Low-Rise Apartments", 20, 0.5f, 3.0f, 2.0f},
    [BUILDING_APARTMENT_HIGH] = {"High-Rise Apartments", 50, 0.7f, 5.0f, 4.0f},
    [BUILDING_CONDO_TOWER] = {"Luxury Condos", 80, 0.9f, 8.0f, 6.0f},
    // Commercial
    [BUILDING_SHOP_SMALL] = {"Corner Store", 2, 0.1f, 1.0f, 0.5f},
    [BUILDING_SHOP_MEDIUM] = {"Shopping Center", 10, 0.3f, 3.0f, 1.5f},
    [BUILDING_OFFICE_LOW] = {"Small Office", 20, 0.5f, 4.0f, 2.0f},
    [BUILDING_OFFICE_HIGH] = {"Office Tower", 100, 0.7f, 10.0f, 5.0f},
    [BUILDING_MALL] = {"Shopping Mall", 150, 0.9f, 15.0f, 8.0f},
    // Industrial
    [BUILDING_FARM] = {"Farm", 5, 0.1f, 0.5f, 1.0f},
    [BUILDING_FACTORY_DIRTY] = {"Heavy Industry", 30, 0.3f, 5.0f, 3.0f},
    [BUILDING_FACTORY_CLEAN] = {"Light Manufacturing", 40, 0.5f, 6.0f, 3.0f},
    [BUILDING_WAREHOUSE] = {"Warehouse", 20, 0.3f, 3.0f, 1.0f},
    [BUILDING_TECH_PARK] = {"Tech Campus", 80, 0.8f, 8.0f, 4.0f}
};

// Zone to building type mapping based on development level
static BuildingType get_building_for_zone(ZoneType zone, float development) {
    switch (zone) {
        case ZONE_RESIDENTIAL_LOW:
            if (development < 0.5f) return BUILDING_HOUSE_SMALL;
            return BUILDING_HOUSE_MEDIUM;
            
        case ZONE_RESIDENTIAL_MEDIUM:
            if (development < 0.3f) return BUILDING_HOUSE_MEDIUM;
            if (development < 0.7f) return BUILDING_APARTMENT_LOW;
            return BUILDING_APARTMENT_HIGH;
            
        case ZONE_RESIDENTIAL_HIGH:
            if (development < 0.5f) return BUILDING_APARTMENT_HIGH;
            return BUILDING_CONDO_TOWER;
            
        case ZONE_COMMERCIAL_LOW:
            if (development < 0.5f) return BUILDING_SHOP_SMALL;
            return BUILDING_SHOP_MEDIUM;
            
        case ZONE_COMMERCIAL_HIGH:
            if (development < 0.3f) return BUILDING_OFFICE_LOW;
            if (development < 0.7f) return BUILDING_OFFICE_HIGH;
            return BUILDING_MALL;
            
        case ZONE_INDUSTRIAL_AGRICULTURE:
            return BUILDING_FARM;
            
        case ZONE_INDUSTRIAL_DIRTY:
            return BUILDING_FACTORY_DIRTY;
            
        case ZONE_INDUSTRIAL_MANUFACTURING:
            if (development < 0.5f) return BUILDING_WAREHOUSE;
            return BUILDING_FACTORY_CLEAN;
            
        case ZONE_INDUSTRIAL_HIGHTECH:
            return BUILDING_TECH_PARK;
            
        default:
            return BUILDING_NONE;
    }
}

int zoning_system_init(uint32_t grid_width, uint32_t grid_height) {
    g_zoning_grid.width = grid_width;
    g_zoning_grid.height = grid_height;
    g_zoning_grid.tiles = calloc(grid_width * grid_height, sizeof(ZoneTile));
    
    if (!g_zoning_grid.tiles) {
        return -1;
    }
    
    // Initialize all tiles as empty
    for (uint32_t i = 0; i < grid_width * grid_height; i++) {
        g_zoning_grid.tiles[i].zone_type = ZONE_NONE;
        g_zoning_grid.tiles[i].building_type = BUILDING_NONE;
        g_zoning_grid.tiles[i].land_value = 0.5f; // Medium land value
    }
    
    g_update_tick = 0;
    return 0;
}

void zoning_set_tile(uint32_t x, uint32_t y, ZoneType zone_type) {
    if (x >= g_zoning_grid.width || y >= g_zoning_grid.height) return;
    
    uint32_t index = y * g_zoning_grid.width + x;
    ZoneTile* tile = &g_zoning_grid.tiles[index];
    
    // Clear existing development if changing zone type
    if (tile->zone_type != zone_type) {
        tile->zone_type = zone_type;
        tile->building_type = BUILDING_NONE;
        tile->population = 0;
        tile->jobs = 0;
        tile->development_level = 0.0f;
        tile->age_ticks = 0;
        tile->is_abandoned = false;
    }
}

const ZoneTile* zoning_get_tile(uint32_t x, uint32_t y) {
    if (x >= g_zoning_grid.width || y >= g_zoning_grid.height) return NULL;
    return &g_zoning_grid.tiles[y * g_zoning_grid.width + x];
}

// Calculate neighbor bonus for development
static float calculate_neighbor_bonus(uint32_t x, uint32_t y) {
    float bonus = 0.0f;
    int developed_neighbors = 0;
    
    // Check 8 surrounding tiles
    for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
            if (dx == 0 && dy == 0) continue;
            
            int nx = (int)x + dx;
            int ny = (int)y + dy;
            
            if (nx >= 0 && nx < (int)g_zoning_grid.width && 
                ny >= 0 && ny < (int)g_zoning_grid.height) {
                const ZoneTile* neighbor = &g_zoning_grid.tiles[ny * g_zoning_grid.width + nx];
                if (neighbor->building_type != BUILDING_NONE) {
                    developed_neighbors++;
                    bonus += neighbor->development_level * 0.1f;
                }
            }
        }
    }
    
    return bonus;
}

float zoning_calculate_development_potential(uint32_t x, uint32_t y) {
    const ZoneTile* tile = zoning_get_tile(x, y);
    if (!tile || tile->zone_type == ZONE_NONE) return 0.0f;
    
    // Base potential from RCI demand
    const RCIDemand* demand = rci_demand_get();
    float zone_demand = 0.0f;
    
    switch (tile->zone_type) {
        case ZONE_RESIDENTIAL_LOW:
        case ZONE_RESIDENTIAL_MEDIUM:
        case ZONE_RESIDENTIAL_HIGH:
            zone_demand = demand->residential / 100.0f;
            break;
        case ZONE_COMMERCIAL_LOW:
        case ZONE_COMMERCIAL_HIGH:
            zone_demand = demand->commercial / 100.0f;
            break;
        case ZONE_INDUSTRIAL_AGRICULTURE:
        case ZONE_INDUSTRIAL_DIRTY:
        case ZONE_INDUSTRIAL_MANUFACTURING:
        case ZONE_INDUSTRIAL_HIGHTECH:
            zone_demand = demand->industrial / 100.0f;
            break;
        default:
            break;
    }
    
    // Factors affecting development
    // CRITICAL: No development without utilities!
    if (!tile->has_power || !tile->has_water) {
        return 0.0f; // Cannot develop without basic utilities
    }
    
    float utility_factor = 1.0f; // Full factor when both utilities present
    float land_value_factor = tile->land_value;
    float neighbor_bonus = calculate_neighbor_bonus(x, y);
    float age_bonus = fminf(tile->age_ticks / 1000.0f, 1.0f); // Older zones more likely to develop
    
    // Calculate final potential
    float potential = (zone_demand + 1.0f) * 0.5f * utility_factor * 
                     (0.5f + land_value_factor * 0.5f) * 
                     (1.0f + neighbor_bonus) * 
                     (0.5f + age_bonus * 0.5f);
    
    return fminf(fmaxf(potential, 0.0f), 1.0f);
}

void zoning_system_update(float delta_time) {
    const float DEVELOPMENT_RATE = 0.01f;
    const float ABANDONMENT_THRESHOLD = 0.2f;
    
    for (uint32_t y = 0; y < g_zoning_grid.height; y++) {
        for (uint32_t x = 0; x < g_zoning_grid.width; x++) {
            ZoneTile* tile = &g_zoning_grid.tiles[y * g_zoning_grid.width + x];
            
            if (tile->zone_type == ZONE_NONE) continue;
            
            tile->age_ticks++;
            
            // Calculate development potential
            float potential = zoning_calculate_development_potential(x, y);
            tile->desirability = potential;
            
            // Update development level
            if (potential > 0.5f && !tile->is_abandoned) {
                // Growth
                tile->development_level += DEVELOPMENT_RATE * potential * delta_time;
                tile->development_level = fminf(tile->development_level, 1.0f);
                
                // Update building type based on development
                BuildingType new_building = get_building_for_zone(tile->zone_type, tile->development_level);
                if (new_building != tile->building_type) {
                    tile->building_type = new_building;
                    
                    // Update population/jobs
                    if (tile->zone_type >= ZONE_RESIDENTIAL_LOW && tile->zone_type <= ZONE_RESIDENTIAL_HIGH) {
                        tile->population = g_building_info[new_building].capacity;
                        tile->jobs = 0;
                    } else {
                        tile->jobs = g_building_info[new_building].capacity;
                        tile->population = 0;
                    }
                }
            } else if (potential < ABANDONMENT_THRESHOLD && tile->building_type != BUILDING_NONE) {
                // Decay/Abandonment
                tile->development_level -= DEVELOPMENT_RATE * 2.0f * delta_time;
                
                if (tile->development_level <= 0.0f) {
                    tile->is_abandoned = true;
                    tile->population = 0;
                    tile->jobs = 0;
                }
            }
            
            // Update land value based on surroundings
            tile->land_value = tile->land_value * 0.95f + calculate_neighbor_bonus(x, y) * 0.05f;
            tile->land_value = fminf(fmaxf(tile->land_value, 0.0f), 1.0f);
        }
    }
    
    g_update_tick++;
}

const char* zoning_get_building_name(BuildingType type) {
    if (type >= 0 && type < sizeof(g_building_info) / sizeof(g_building_info[0])) {
        return g_building_info[type].name;
    }
    return "Unknown";
}

uint32_t zoning_get_building_capacity(BuildingType type) {
    if (type >= 0 && type < sizeof(g_building_info) / sizeof(g_building_info[0])) {
        return g_building_info[type].capacity;
    }
    return 0;
}

uint32_t zoning_get_total_population(void) {
    uint32_t total = 0;
    for (uint32_t i = 0; i < g_zoning_grid.width * g_zoning_grid.height; i++) {
        total += g_zoning_grid.tiles[i].population;
    }
    return total;
}

uint32_t zoning_get_total_jobs(void) {
    uint32_t total = 0;
    for (uint32_t i = 0; i < g_zoning_grid.width * g_zoning_grid.height; i++) {
        total += g_zoning_grid.tiles[i].jobs;
    }
    return total;
}

uint32_t zoning_get_zone_count(ZoneType type) {
    uint32_t count = 0;
    for (uint32_t i = 0; i < g_zoning_grid.width * g_zoning_grid.height; i++) {
        if (g_zoning_grid.tiles[i].zone_type == type) {
            count++;
        }
    }
    return count;
}

void zoning_system_shutdown(void) {
    if (g_zoning_grid.tiles) {
        free(g_zoning_grid.tiles);
        g_zoning_grid.tiles = NULL;
    }
    g_zoning_grid.width = 0;
    g_zoning_grid.height = 0;
}