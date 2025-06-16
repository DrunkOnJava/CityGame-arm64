#ifndef ZONING_SYSTEM_H
#define ZONING_SYSTEM_H

#include <stdint.h>
#include <stdbool.h>
#include "rci_demand.h"

// Tile size in world units
#define TILE_SIZE 10.0f

// Building types that can develop on zones
typedef enum {
    BUILDING_NONE = 0,
    // Residential
    BUILDING_HOUSE_SMALL,
    BUILDING_HOUSE_MEDIUM,
    BUILDING_APARTMENT_LOW,
    BUILDING_APARTMENT_HIGH,
    BUILDING_CONDO_TOWER,
    // Commercial
    BUILDING_SHOP_SMALL,
    BUILDING_SHOP_MEDIUM,
    BUILDING_OFFICE_LOW,
    BUILDING_OFFICE_HIGH,
    BUILDING_MALL,
    // Industrial
    BUILDING_FARM,
    BUILDING_FACTORY_DIRTY,
    BUILDING_FACTORY_CLEAN,
    BUILDING_WAREHOUSE,
    BUILDING_TECH_PARK
} BuildingType;

// Zone tile information
typedef struct {
    ZoneType zone_type;
    BuildingType building_type;
    uint32_t population;
    uint32_t jobs;
    float development_level; // 0.0 to 1.0
    float desirability;
    float land_value;
    uint32_t age_ticks; // How long since zoned/built
    bool has_power;
    bool has_water;
    bool is_abandoned;
} ZoneTile;

// Zoning grid
typedef struct {
    uint32_t width;
    uint32_t height;
    ZoneTile* tiles;
} ZoningGrid;

// Initialize zoning system
int zoning_system_init(uint32_t grid_width, uint32_t grid_height);

// Zone a tile
void zoning_set_tile(uint32_t x, uint32_t y, ZoneType zone_type);

// Get zone info
const ZoneTile* zoning_get_tile(uint32_t x, uint32_t y);

// Update zoning simulation (growth/decay)
void zoning_system_update(float delta_time);

// Calculate development potential for a tile
float zoning_calculate_development_potential(uint32_t x, uint32_t y);

// Get building info
const char* zoning_get_building_name(BuildingType type);
uint32_t zoning_get_building_capacity(BuildingType type);

// Query functions
uint32_t zoning_get_total_population(void);
uint32_t zoning_get_total_jobs(void);
uint32_t zoning_get_zone_count(ZoneType type);

// Cleanup
void zoning_system_shutdown(void);

#endif // ZONING_SYSTEM_H