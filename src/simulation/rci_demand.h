#ifndef RCI_DEMAND_H
#define RCI_DEMAND_H

#include <stdint.h>

// Zone types
typedef enum {
    ZONE_NONE = 0,
    ZONE_RESIDENTIAL_LOW,
    ZONE_RESIDENTIAL_MEDIUM,
    ZONE_RESIDENTIAL_HIGH,
    ZONE_COMMERCIAL_LOW,
    ZONE_COMMERCIAL_HIGH,
    ZONE_INDUSTRIAL_AGRICULTURE,
    ZONE_INDUSTRIAL_DIRTY,
    ZONE_INDUSTRIAL_MANUFACTURING,
    ZONE_INDUSTRIAL_HIGHTECH
} ZoneType;

// RCI demand factors
typedef struct {
    float tax_rate;
    float unemployment_rate;
    float average_commute_time;
    float education_level;
    float pollution_level;
    float crime_rate;
    float land_value;
    float utility_coverage;
} DemandFactors;

// RCI demand values (-100 to +100)
typedef struct {
    float residential;
    float commercial;
    float industrial;
    
    // Detailed breakdown
    float residential_low;
    float residential_medium;
    float residential_high;
    float commercial_low;
    float commercial_high;
    float industrial_agriculture;
    float industrial_dirty;
    float industrial_manufacturing;
    float industrial_hightech;
} RCIDemand;

// Lot development info
typedef struct {
    ZoneType zone_type;
    uint32_t population;
    uint32_t jobs;
    float desirability;
    float growth_rate;
    uint32_t last_update_tick;
} LotInfo;

// Initialize RCI demand system
int rci_demand_init(void);

// Update demand calculations (called each simulation tick)
void rci_demand_update(const DemandFactors* factors);

// Get current demand values
const RCIDemand* rci_demand_get(void);

// Calculate lot desirability for development
float rci_calculate_lot_desirability(ZoneType zone, float land_value, 
                                    float commute_time, float services);

// Process lot growth/decay
void rci_process_lot_development(LotInfo* lot, const DemandFactors* local_factors);

// Cleanup
void rci_demand_shutdown(void);

#endif // RCI_DEMAND_H