#ifndef UTILITIES_SYSTEM_H
#define UTILITIES_SYSTEM_H

#include <stdint.h>
#include <stdbool.h>

// Utility types
typedef enum {
    UTILITY_POWER,
    UTILITY_WATER,
    UTILITY_SEWAGE,
    UTILITY_GARBAGE
} UtilityType;

// Power plant types
typedef enum {
    POWER_NONE = 0,
    POWER_COAL,
    POWER_GAS,
    POWER_NUCLEAR,
    POWER_SOLAR,
    POWER_WIND
} PowerPlantType;

// Water source types
typedef enum {
    WATER_NONE = 0,
    WATER_PUMP,
    WATER_TOWER,
    WATER_TREATMENT
} WaterSourceType;

// Utility building
typedef struct {
    uint32_t x, y;
    union {
        PowerPlantType power_type;
        WaterSourceType water_type;
    } type;
    uint32_t capacity;      // MW for power, gallons/day for water
    uint32_t current_load;  // Current usage
    float efficiency;       // 0.0 to 1.0
    bool operational;
} UtilityBuilding;

// Utility grid cell
typedef struct {
    bool has_power;
    bool has_water;
    bool has_sewage;
    float power_level;      // 0.0 to 1.0 (voltage drop with distance)
    float water_pressure;   // 0.0 to 1.0 (pressure drop with distance)
    uint32_t power_source_id;
    uint32_t water_source_id;
} UtilityCell;

// Utility network statistics
typedef struct {
    uint32_t total_power_capacity;
    uint32_t total_power_demand;
    uint32_t total_water_capacity;
    uint32_t total_water_demand;
    uint32_t powered_buildings;
    uint32_t unpowered_buildings;
    uint32_t watered_buildings;
    uint32_t unwatered_buildings;
    float grid_efficiency;
} UtilityStats;

// Initialize utilities system
int utilities_system_init(uint32_t grid_width, uint32_t grid_height);

// Place utility building
bool utilities_place_building(uint32_t x, uint32_t y, UtilityType utility_type, uint32_t subtype);

// Remove utility building
void utilities_remove_building(uint32_t x, uint32_t y);

// Propagate utilities through grid (flood-fill algorithm)
void utilities_propagate_power(void);
void utilities_propagate_water(void);

// Update utility simulation
void utilities_system_update(float delta_time);

// Check if tile has utilities
bool utilities_has_power(uint32_t x, uint32_t y);
bool utilities_has_water(uint32_t x, uint32_t y);

// Get utility statistics
const UtilityStats* utilities_get_stats(void);

// Get utility grid for visualization
const UtilityCell* utilities_get_grid(void);

// Power plant properties
uint32_t utilities_get_power_capacity(PowerPlantType type);
float utilities_get_power_pollution(PowerPlantType type);

// Cleanup
void utilities_system_shutdown(void);

#endif // UTILITIES_SYSTEM_H