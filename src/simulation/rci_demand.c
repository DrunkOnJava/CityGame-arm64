#include "rci_demand.h"
#include <math.h>
#include <string.h>
#include <stdlib.h>

// Global RCI demand state
static RCIDemand g_current_demand = {0};
static uint32_t g_simulation_tick = 0;

// Demand curve parameters (tunable)
static const struct {
    float base_demand;
    float tax_sensitivity;
    float unemployment_sensitivity;
    float commute_sensitivity;
    float education_requirement;
    float pollution_tolerance;
} g_zone_params[] = {
    [ZONE_RESIDENTIAL_LOW] = {
        .base_demand = 20.0f,
        .tax_sensitivity = -2.0f,
        .unemployment_sensitivity = -3.0f,
        .commute_sensitivity = -1.5f,
        .education_requirement = 0.0f,
        .pollution_tolerance = 0.6f
    },
    [ZONE_RESIDENTIAL_MEDIUM] = {
        .base_demand = 15.0f,
        .tax_sensitivity = -2.5f,
        .unemployment_sensitivity = -4.0f,
        .commute_sensitivity = -2.0f,
        .education_requirement = 0.3f,
        .pollution_tolerance = 0.3f
    },
    [ZONE_RESIDENTIAL_HIGH] = {
        .base_demand = 10.0f,
        .tax_sensitivity = -3.0f,
        .unemployment_sensitivity = -5.0f,
        .commute_sensitivity = -3.0f,
        .education_requirement = 0.6f,
        .pollution_tolerance = 0.1f
    },
    [ZONE_COMMERCIAL_LOW] = {
        .base_demand = 15.0f,
        .tax_sensitivity = -2.5f,
        .unemployment_sensitivity = 2.0f, // Benefits from workers
        .commute_sensitivity = -1.0f,
        .education_requirement = 0.2f,
        .pollution_tolerance = 0.5f
    },
    [ZONE_COMMERCIAL_HIGH] = {
        .base_demand = 10.0f,
        .tax_sensitivity = -3.5f,
        .unemployment_sensitivity = 1.5f,
        .commute_sensitivity = -2.0f,
        .education_requirement = 0.7f,
        .pollution_tolerance = 0.2f
    },
    [ZONE_INDUSTRIAL_AGRICULTURE] = {
        .base_demand = 12.0f,
        .tax_sensitivity = -1.5f,
        .unemployment_sensitivity = 3.0f,
        .commute_sensitivity = -0.5f,
        .education_requirement = 0.0f,
        .pollution_tolerance = 0.8f
    },
    [ZONE_INDUSTRIAL_DIRTY] = {
        .base_demand = 18.0f,
        .tax_sensitivity = -2.0f,
        .unemployment_sensitivity = 4.0f,
        .commute_sensitivity = -0.5f,
        .education_requirement = 0.1f,
        .pollution_tolerance = 1.0f
    },
    [ZONE_INDUSTRIAL_MANUFACTURING] = {
        .base_demand = 15.0f,
        .tax_sensitivity = -2.5f,
        .unemployment_sensitivity = 3.5f,
        .commute_sensitivity = -1.0f,
        .education_requirement = 0.4f,
        .pollution_tolerance = 0.7f
    },
    [ZONE_INDUSTRIAL_HIGHTECH] = {
        .base_demand = 8.0f,
        .tax_sensitivity = -3.0f,
        .unemployment_sensitivity = 2.5f,
        .commute_sensitivity = -2.0f,
        .education_requirement = 0.8f,
        .pollution_tolerance = 0.3f
    }
};

int rci_demand_init(void) {
    memset(&g_current_demand, 0, sizeof(g_current_demand));
    g_simulation_tick = 0;
    
    // Set initial demand values
    g_current_demand.residential = 20.0f;
    g_current_demand.commercial = 10.0f;
    g_current_demand.industrial = 15.0f;
    
    return 0;
}

// Helper: Clamp value between min and max
static float clamp(float value, float min, float max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
}

// Helper: Calculate demand for a specific zone type
static float calculate_zone_demand(ZoneType zone, const DemandFactors* factors) {
    if (zone <= ZONE_NONE || zone > ZONE_INDUSTRIAL_HIGHTECH) {
        return 0.0f;
    }
    
    const typeof(g_zone_params[0])* params = &g_zone_params[zone];
    
    // Start with base demand
    float demand = params->base_demand;
    
    // Tax impact (higher tax = lower demand)
    demand += params->tax_sensitivity * factors->tax_rate;
    
    // Unemployment impact (different for residential vs commercial/industrial)
    demand += params->unemployment_sensitivity * factors->unemployment_rate;
    
    // Commute time impact
    demand += params->commute_sensitivity * (factors->average_commute_time - 30.0f) / 10.0f;
    
    // Education impact (penalize if requirements not met)
    float education_gap = params->education_requirement - factors->education_level;
    if (education_gap > 0) {
        demand -= education_gap * 20.0f;
    }
    
    // Pollution impact
    float pollution_penalty = (factors->pollution_level - params->pollution_tolerance);
    if (pollution_penalty > 0) {
        demand -= pollution_penalty * 15.0f;
    }
    
    // Crime impact (everyone dislikes crime)
    demand -= factors->crime_rate * 10.0f;
    
    // Utility coverage boost
    demand += factors->utility_coverage * 5.0f;
    
    return clamp(demand, -100.0f, 100.0f);
}

void rci_demand_update(const DemandFactors* factors) {
    // Calculate detailed demand for each zone type
    g_current_demand.residential_low = calculate_zone_demand(ZONE_RESIDENTIAL_LOW, factors);
    g_current_demand.residential_medium = calculate_zone_demand(ZONE_RESIDENTIAL_MEDIUM, factors);
    g_current_demand.residential_high = calculate_zone_demand(ZONE_RESIDENTIAL_HIGH, factors);
    
    g_current_demand.commercial_low = calculate_zone_demand(ZONE_COMMERCIAL_LOW, factors);
    g_current_demand.commercial_high = calculate_zone_demand(ZONE_COMMERCIAL_HIGH, factors);
    
    g_current_demand.industrial_agriculture = calculate_zone_demand(ZONE_INDUSTRIAL_AGRICULTURE, factors);
    g_current_demand.industrial_dirty = calculate_zone_demand(ZONE_INDUSTRIAL_DIRTY, factors);
    g_current_demand.industrial_manufacturing = calculate_zone_demand(ZONE_INDUSTRIAL_MANUFACTURING, factors);
    g_current_demand.industrial_hightech = calculate_zone_demand(ZONE_INDUSTRIAL_HIGHTECH, factors);
    
    // Calculate aggregate RCI values (weighted average)
    g_current_demand.residential = (
        g_current_demand.residential_low * 0.5f +
        g_current_demand.residential_medium * 0.3f +
        g_current_demand.residential_high * 0.2f
    );
    
    g_current_demand.commercial = (
        g_current_demand.commercial_low * 0.6f +
        g_current_demand.commercial_high * 0.4f
    );
    
    g_current_demand.industrial = (
        g_current_demand.industrial_agriculture * 0.2f +
        g_current_demand.industrial_dirty * 0.3f +
        g_current_demand.industrial_manufacturing * 0.3f +
        g_current_demand.industrial_hightech * 0.2f
    );
    
    g_simulation_tick++;
}

const RCIDemand* rci_demand_get(void) {
    return &g_current_demand;
}

float rci_calculate_lot_desirability(ZoneType zone, float land_value, 
                                    float commute_time, float services) {
    // Base desirability from zone demand
    float zone_demand = 0.0f;
    switch (zone) {
        case ZONE_RESIDENTIAL_LOW: zone_demand = g_current_demand.residential_low; break;
        case ZONE_RESIDENTIAL_MEDIUM: zone_demand = g_current_demand.residential_medium; break;
        case ZONE_RESIDENTIAL_HIGH: zone_demand = g_current_demand.residential_high; break;
        case ZONE_COMMERCIAL_LOW: zone_demand = g_current_demand.commercial_low; break;
        case ZONE_COMMERCIAL_HIGH: zone_demand = g_current_demand.commercial_high; break;
        case ZONE_INDUSTRIAL_AGRICULTURE: zone_demand = g_current_demand.industrial_agriculture; break;
        case ZONE_INDUSTRIAL_DIRTY: zone_demand = g_current_demand.industrial_dirty; break;
        case ZONE_INDUSTRIAL_MANUFACTURING: zone_demand = g_current_demand.industrial_manufacturing; break;
        case ZONE_INDUSTRIAL_HIGHTECH: zone_demand = g_current_demand.industrial_hightech; break;
        default: return 0.0f;
    }
    
    // Convert demand (-100 to +100) to desirability (0 to 1)
    float desirability = (zone_demand + 100.0f) / 200.0f;
    
    // Land value modifier
    float land_value_factor = 1.0f;
    if (zone >= ZONE_RESIDENTIAL_MEDIUM && zone <= ZONE_COMMERCIAL_HIGH) {
        land_value_factor = 0.5f + land_value * 0.5f;
    }
    
    // Commute time penalty
    float commute_factor = 1.0f - (commute_time / 120.0f); // 2 hour max
    commute_factor = clamp(commute_factor, 0.1f, 1.0f);
    
    // Service coverage boost
    float service_factor = 0.8f + services * 0.2f;
    
    return clamp(desirability * land_value_factor * commute_factor * service_factor, 0.0f, 1.0f);
}

void rci_process_lot_development(LotInfo* lot, const DemandFactors* local_factors) {
    // Calculate current desirability
    float current_desirability = rci_calculate_lot_desirability(
        lot->zone_type, 
        local_factors->land_value,
        local_factors->average_commute_time,
        local_factors->utility_coverage
    );
    
    // Update lot desirability (smoothed)
    lot->desirability = lot->desirability * 0.9f + current_desirability * 0.1f;
    
    // Growth threshold
    const float GROWTH_THRESHOLD = 0.6f;
    const float DECAY_THRESHOLD = 0.3f;
    
    if (lot->desirability > GROWTH_THRESHOLD) {
        // Lot grows
        lot->growth_rate = (lot->desirability - GROWTH_THRESHOLD) * 2.0f;
        
        // Update population/jobs based on zone type
        if (lot->zone_type >= ZONE_RESIDENTIAL_LOW && lot->zone_type <= ZONE_RESIDENTIAL_HIGH) {
            lot->population += (uint32_t)(lot->growth_rate * 10);
        } else {
            lot->jobs += (uint32_t)(lot->growth_rate * 5);
        }
    } else if (lot->desirability < DECAY_THRESHOLD) {
        // Lot decays
        lot->growth_rate = (lot->desirability - DECAY_THRESHOLD) * 1.5f;
        
        // Decrease population/jobs
        if (lot->population > 0) {
            uint32_t loss = (uint32_t)(-lot->growth_rate * 5);
            lot->population = (loss < lot->population) ? lot->population - loss : 0;
        }
        if (lot->jobs > 0) {
            uint32_t loss = (uint32_t)(-lot->growth_rate * 3);
            lot->jobs = (loss < lot->jobs) ? lot->jobs - loss : 0;
        }
    } else {
        // Stable
        lot->growth_rate = 0.0f;
    }
    
    lot->last_update_tick = g_simulation_tick;
}

void rci_demand_shutdown(void) {
    // Nothing to clean up for now
}