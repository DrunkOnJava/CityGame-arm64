// SimCity ARM64 Entity System
// High-performance ECS implementation in pure ARM64 assembly
// Agent A5: Simulation Team - Entity/Agent Management System

#ifndef ENTITY_SYSTEM_H
#define ENTITY_SYSTEM_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

//==============================================================================
// Core System Functions
//==============================================================================

// Initialize the Entity Component System
// Returns: 0 on success, error code on failure
int entity_system_init(void);

// Update all entities and systems
// Parameters: delta_time in seconds
void entity_system_update(float delta_time);

// Shutdown and cleanup the ECS
void entity_system_shutdown(void);

//==============================================================================
// Entity Management
//==============================================================================

// Entity ID type - unique identifier for entities
typedef uint64_t entity_id_t;

// Create a new entity with specified components
// Parameters: component_mask - bitmask of components to add
// Returns: entity_id (0 on failure)
entity_id_t create_entity(uint64_t component_mask);

// Destroy an entity and clean up its components
// Parameters: entity_id - entity to destroy
// Returns: 0 on success, error code on failure
int destroy_entity(entity_id_t entity_id);

// Check if an entity ID is valid
// Parameters: entity_id - entity to validate
// Returns: 0 if valid, error code if invalid
int validate_entity_id(entity_id_t entity_id);

//==============================================================================
// Component Management
//==============================================================================

// Component type constants
#define COMPONENT_POSITION          0
#define COMPONENT_BUILDING          1
#define COMPONENT_ECONOMIC          2
#define COMPONENT_POPULATION        3
#define COMPONENT_TRANSPORT         4
#define COMPONENT_UTILITY           5
#define COMPONENT_ZONE              6
#define COMPONENT_RENDER            7
#define COMPONENT_AGENT             8
#define COMPONENT_ENVIRONMENT       9
#define COMPONENT_TIME_BASED        10
#define COMPONENT_RESOURCE          11
#define COMPONENT_SERVICE           12
#define COMPONENT_INFRASTRUCTURE    13
#define COMPONENT_CLIMATE           14
#define COMPONENT_TRAFFIC           15

// Add a component to an existing entity
// Parameters: entity_id, component_type, component_data_ptr (optional)
// Returns: 0 on success, error code on failure
int add_component(entity_id_t entity_id, uint32_t component_type, void* component_data);

// Remove a component from an entity
// Parameters: entity_id, component_type
// Returns: 0 on success, error code on failure
int remove_component(entity_id_t entity_id, uint32_t component_type);

// Get pointer to entity's component data
// Parameters: entity_id, component_type
// Returns: component_data_ptr (NULL if not found)
void* get_component(entity_id_t entity_id, uint32_t component_type);

//==============================================================================
// Query System
//==============================================================================

// Query builder handle
typedef void* query_builder_t;

// Create a new query builder
// Returns: query_builder_handle
query_builder_t query_builder_create(void);

// Add a required component to query
// Parameters: query_builder, component_type
// Returns: query_builder (for chaining)
query_builder_t query_with_component(query_builder_t builder, uint32_t component_type);

// Exclude a component from query
// Parameters: query_builder, component_type
// Returns: query_builder (for chaining)
query_builder_t query_without_component(query_builder_t builder, uint32_t component_type);

// Add optional component to query
// Parameters: query_builder, component_type
// Returns: query_builder (for chaining)
query_builder_t query_maybe_component(query_builder_t builder, uint32_t component_type);

// Execute the built query and return matching entities
// Parameters: query_builder, result_buffer, max_results
// Returns: number of matching entities found
uint32_t execute_query(query_builder_t builder, entity_id_t* result_buffer, uint32_t max_results);

//==============================================================================
// Specialized Query Functions
//==============================================================================

// Quick query for entities with position component
// Parameters: result_buffer, max_results
// Returns: number of entities found
uint32_t query_entities_with_position(entity_id_t* result_buffer, uint32_t max_results);

// Quick query for entities with building component
// Parameters: result_buffer, max_results
// Returns: number of entities found
uint32_t query_entities_with_building(entity_id_t* result_buffer, uint32_t max_results);

// Query for entities with both building and position
// Parameters: result_buffer, max_results
// Returns: number of entities found
uint32_t query_buildings_with_position(entity_id_t* result_buffer, uint32_t max_results);

//==============================================================================
// Query Result Iteration
//==============================================================================

// Query iterator handle
typedef void* query_iterator_t;

// Create iterator for query results
// Parameters: query_results_buffer, result_count
// Returns: iterator_handle
query_iterator_t query_iterator_create(entity_id_t* results, uint32_t count);

// Get next entity from query results
// Parameters: iterator_handle
// Returns: entity_id (0 if no more entities)
entity_id_t query_iterator_next(query_iterator_t iterator);

//==============================================================================
// Performance and Testing
//==============================================================================

// Performance statistics structure
typedef struct {
    uint64_t total_entities;
    uint64_t active_entities;
    uint64_t total_updates;
    uint64_t avg_update_time_ns;
    uint64_t cache_hit_rate;
    uint64_t memory_usage_bytes;
} entity_system_stats_t;

// Get entity system performance statistics
// Parameters: stats_output_buffer
void get_entity_system_stats(entity_system_stats_t* stats);

// Run entity system unit tests
// Returns: 0 on success, error count on failure
int run_entity_tests(void);

// Run only basic functionality tests
// Returns: 0 on success, error count on failure
int run_basic_tests(void);

// Run only performance tests
// Returns: 0 on success, error count on failure
int run_performance_tests(void);

//==============================================================================
// Integration with Agent A1 Core Framework
//==============================================================================

// Register entity system with core framework
// Called by Agent A1 during system initialization
int register_entity_system_with_core(void);

// Get entity system module info for Agent A1
// Returns: module information structure
void* get_entity_system_module_info(void);

//==============================================================================
// Integration with Agent D1 Memory Allocation
//==============================================================================

// Set custom allocator for entity system
// Parameters: allocator function pointers
int set_entity_allocator(void* (*alloc_func)(size_t), void (*free_func)(void*));

// Get memory usage statistics for Agent D1 monitoring
// Parameters: memory_stats_output
void get_entity_memory_stats(void* memory_stats);

#ifdef __cplusplus
}
#endif

#endif // ENTITY_SYSTEM_H