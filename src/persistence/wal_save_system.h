// SimCity ARM64 Write-Ahead Logging Save System
// Agent 6: Save System & Persistence
// Memory-mapped WAL for crash-safe incremental saves with Apple Silicon optimization

#ifndef WAL_SAVE_SYSTEM_H
#define WAL_SAVE_SYSTEM_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Save state structure
typedef struct SimulationState {
    uint64_t simulation_tick;         // Current simulation tick
    uint32_t entity_count;            // Number of entities
    uint32_t building_count;          // Number of buildings
    uint64_t population;              // Total population
    uint64_t money;                   // Available money
    float happiness_avg;              // Average happiness
    uint32_t day_cycle;               // Current day in cycle
    uint8_t weather_state;            // Current weather
    uint8_t reserved[15];             // Alignment padding
} __attribute__((packed)) SimulationState;

// Entity update record
typedef struct EntityUpdate {
    uint32_t entity_id;               // Entity identifier
    float position_x;                 // X position
    float position_y;                 // Y position
    uint32_t state;                   // Entity state
    uint16_t health;                  // Health value
    uint16_t happiness;               // Happiness value
    uint32_t flags;                   // Status flags
} __attribute__((packed)) EntityUpdate;

//==============================================================================
// WAL SYSTEM API
//==============================================================================

/**
 * Initialize the Write-Ahead Logging system
 * @param save_dir Directory to store WAL files
 * @return 0 on success, -1 on failure
 */
int wal_system_init(const char* save_dir);

/**
 * Shutdown the WAL system and perform final checkpoint
 */
void wal_system_shutdown(void);

/**
 * Save simulation state to WAL
 * @param state Simulation state to save
 * @return 0 on success, -1 on failure
 */
int wal_save_simulation_state(const SimulationState* state);

/**
 * Save entity update to WAL
 * @param update Entity update to save
 * @return 0 on success, -1 on failure
 */
int wal_save_entity_update(const EntityUpdate* update);

/**
 * Save batch of entity updates to WAL (more efficient than individual saves)
 * @param updates Array of entity updates
 * @param count Number of updates in array
 * @return 0 on success, -1 on failure
 */
int wal_save_batch_entity_updates(const EntityUpdate* updates, uint32_t count);

/**
 * Force an immediate checkpoint (flush WAL to stable storage)
 * @return 0 on success, -1 on failure
 */
int wal_force_checkpoint(void);

/**
 * Get WAL system performance statistics
 * @param records_written Output for total records written
 * @param bytes_written Output for total bytes written
 * @param checkpoints_completed Output for total checkpoints completed
 */
void wal_get_statistics(uint64_t* records_written, uint64_t* bytes_written, 
                       uint64_t* checkpoints_completed);

/**
 * Print WAL system statistics to stdout
 */
void wal_print_statistics(void);

//==============================================================================
// CONVENIENCE MACROS FOR DEVACTOR INTEGRATION
//==============================================================================

// Macro for saving simulation state with error checking
#define WAL_SAVE_SIM_STATE(state) do { \
    if (wal_save_simulation_state(state) != 0) { \
        printf("Failed to save simulation state at tick %llu\n", (state)->simulation_tick); \
    } \
} while(0)

// Macro for saving entity update with error checking
#define WAL_SAVE_ENTITY(update) do { \
    if (wal_save_entity_update(update) != 0) { \
        printf("Failed to save entity update for ID %u\n", (update)->entity_id); \
    } \
} while(0)

// Macro for batch saving entities
#define WAL_SAVE_ENTITY_BATCH(updates, count) do { \
    if (wal_save_batch_entity_updates(updates, count) != 0) { \
        printf("Failed to save batch of %u entity updates\n", count); \
    } \
} while(0)

//==============================================================================
// INTEGRATION HELPERS FOR SIMCITY CORE SYSTEMS
//==============================================================================

/**
 * Helper function to create simulation state from core game state
 * @param tick Current simulation tick
 * @param entities Entity count
 * @param buildings Building count
 * @param pop Population
 * @param money Available money
 * @param happiness Average happiness
 * @param day Day cycle
 * @param weather Weather state
 * @return Populated SimulationState structure
 */
static inline SimulationState create_simulation_state(
    uint64_t tick, uint32_t entities, uint32_t buildings, 
    uint64_t pop, uint64_t money, float happiness, 
    uint32_t day, uint8_t weather) 
{
    SimulationState state = {0};
    state.simulation_tick = tick;
    state.entity_count = entities;
    state.building_count = buildings;
    state.population = pop;
    state.money = money;
    state.happiness_avg = happiness;
    state.day_cycle = day;
    state.weather_state = weather;
    return state;
}

/**
 * Helper function to create entity update from core entity data
 * @param id Entity ID
 * @param x X position
 * @param y Y position
 * @param state Entity state
 * @param health Health value
 * @param happiness Happiness value
 * @param flags Status flags
 * @return Populated EntityUpdate structure
 */
static inline EntityUpdate create_entity_update(
    uint32_t id, float x, float y, uint32_t state, 
    uint16_t health, uint16_t happiness, uint32_t flags)
{
    EntityUpdate update = {0};
    update.entity_id = id;
    update.position_x = x;
    update.position_y = y;
    update.state = state;
    update.health = health;
    update.happiness = happiness;
    update.flags = flags;
    return update;
}

#ifdef __cplusplus
}
#endif

#endif // WAL_SAVE_SYSTEM_H