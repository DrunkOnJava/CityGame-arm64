// SimCity ARM64 Entity System Demo
// Agent A5: Simulation Team - Demonstration of ECS functionality
// Simple C demo that uses the ARM64 assembly ECS implementation

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include "entity_system.h"

//==============================================================================
// Demo Configuration
//==============================================================================

#define DEMO_ENTITY_COUNT       1000
#define DEMO_QUERY_BUFFER_SIZE  500
#define DEMO_UPDATE_CYCLES      100

//==============================================================================
// Component Data Structures
//==============================================================================

// Position component (32 bytes, cache-aligned)
typedef struct {
    float x, y, z;          // 3D position
    float velocity_x;       // X velocity
    float velocity_y;       // Y velocity  
    float velocity_z;       // Z velocity
    uint32_t flags;         // Position flags
    uint32_t padding;       // Alignment padding
} position_component_t;

// Building component (64 bytes, cache-aligned)
typedef struct {
    uint32_t building_type; // Type of building
    uint32_t health;        // Building health
    uint32_t population;    // Population in building
    uint32_t power_usage;   // Power consumption
    uint32_t water_usage;   // Water consumption
    uint32_t pollution;     // Pollution generated
    uint32_t happiness;     // Happiness level
    uint32_t land_value;    // Land value
    uint64_t last_update;   // Last update timestamp
    uint64_t construction_time; // When built
    uint32_t level;         // Building level
    uint32_t padding[5];    // Pad to 64 bytes
} building_component_t;

//==============================================================================
// Demo Functions
//==============================================================================

// Print entity system statistics
void print_stats(const char* phase) {
    entity_system_stats_t stats;
    get_entity_system_stats(&stats);
    
    printf("\n=== Entity System Stats (%s) ===\n", phase);
    printf("Total Entities:     %llu\n", stats.total_entities);
    printf("Active Entities:    %llu\n", stats.active_entities);
    printf("Total Updates:      %llu\n", stats.total_updates);
    printf("Avg Update Time:    %llu ns\n", stats.avg_update_time_ns);
    printf("Cache Hit Rate:     %llu%%\n", stats.cache_hit_rate);
    printf("Memory Usage:       %llu bytes\n", stats.memory_usage_bytes);
    printf("=====================================\n");
}

// Create test entities with various component combinations
int create_test_entities(entity_id_t* entities, int count) {
    printf("Creating %d test entities...\n", count);
    
    int success_count = 0;
    
    for (int i = 0; i < count; i++) {
        uint64_t component_mask = 0;
        
        // Different entity types based on index
        if (i % 3 == 0) {
            // Position only entities (simple agents)
            component_mask = (1ULL << COMPONENT_POSITION);
        } else if (i % 3 == 1) {
            // Building entities with position
            component_mask = (1ULL << COMPONENT_POSITION) | 
                           (1ULL << COMPONENT_BUILDING);
        } else {
            // Complex entities with multiple components
            component_mask = (1ULL << COMPONENT_POSITION) | 
                           (1ULL << COMPONENT_BUILDING) |
                           (1ULL << COMPONENT_ECONOMIC);
        }
        
        entity_id_t entity = create_entity(component_mask);
        if (entity != 0) {
            entities[success_count] = entity;
            success_count++;
            
            // Add component data if entity was created successfully
            if (component_mask & (1ULL << COMPONENT_POSITION)) {
                position_component_t pos = {
                    .x = (float)(i % 100),
                    .y = (float)(i / 100),
                    .z = 0.0f,
                    .velocity_x = 0.1f,
                    .velocity_y = 0.1f,
                    .velocity_z = 0.0f,
                    .flags = 0,
                    .padding = 0
                };
                add_component(entity, COMPONENT_POSITION, &pos);
            }
            
            if (component_mask & (1ULL << COMPONENT_BUILDING)) {
                building_component_t building = {
                    .building_type = i % 5 + 1,
                    .health = 100,
                    .population = (i % 10) * 10,
                    .power_usage = 50,
                    .water_usage = 30,
                    .pollution = 5,
                    .happiness = 80,
                    .land_value = 1000 + (i % 500),
                    .last_update = 0,
                    .construction_time = time(NULL),
                    .level = 1
                };
                add_component(entity, COMPONENT_BUILDING, &building);
            }
        }
        
        if (i % 100 == 0) {
            printf("  Created %d entities...\n", i);
        }
    }
    
    printf("Successfully created %d out of %d entities\n", success_count, count);
    return success_count;
}

// Test component queries
void test_component_queries() {
    printf("\n=== Testing Component Queries ===\n");
    
    entity_id_t query_results[DEMO_QUERY_BUFFER_SIZE];
    
    // Query entities with position components
    uint32_t position_count = query_entities_with_position(query_results, DEMO_QUERY_BUFFER_SIZE);
    printf("Entities with position: %u\n", position_count);
    
    // Query entities with building components
    uint32_t building_count = query_entities_with_building(query_results, DEMO_QUERY_BUFFER_SIZE);
    printf("Entities with buildings: %u\n", building_count);
    
    // Query entities with both building and position
    uint32_t both_count = query_buildings_with_position(query_results, DEMO_QUERY_BUFFER_SIZE);
    printf("Entities with both: %u\n", both_count);
    
    // Test query builder for more complex queries
    query_builder_t builder = query_builder_create();
    builder = query_with_component(builder, COMPONENT_POSITION);
    builder = query_with_component(builder, COMPONENT_BUILDING);
    builder = query_without_component(builder, COMPONENT_ECONOMIC);
    
    uint32_t complex_count = execute_query(builder, query_results, DEMO_QUERY_BUFFER_SIZE);
    printf("Complex query results: %u\n", complex_count);
    
    // Test query iteration
    if (complex_count > 0) {
        printf("Iterating through complex query results:\n");
        query_iterator_t iterator = query_iterator_create(query_results, complex_count);
        
        int count = 0;
        entity_id_t entity;
        while ((entity = query_iterator_next(iterator)) != 0 && count < 5) {
            printf("  Entity ID: %llu\n", entity);
            count++;
        }
        if (complex_count > 5) {
            printf("  ... and %u more entities\n", complex_count - 5);
        }
    }
}

// Test component manipulation
void test_component_manipulation(entity_id_t* entities, int count) {
    printf("\n=== Testing Component Manipulation ===\n");
    
    if (count < 10) {
        printf("Need at least 10 entities for component tests\n");
        return;
    }
    
    // Test adding components to existing entities
    printf("Adding economic component to first 5 entities...\n");
    for (int i = 0; i < 5; i++) {
        int result = add_component(entities[i], COMPONENT_ECONOMIC, NULL);
        if (result == 0) {
            printf("  Added economic component to entity %llu\n", entities[i]);
        } else {
            printf("  Failed to add economic component to entity %llu\n", entities[i]);
        }
    }
    
    // Test removing components
    printf("Removing position component from entities 5-9...\n");
    for (int i = 5; i < 10; i++) {
        int result = remove_component(entities[i], COMPONENT_POSITION);
        if (result == 0) {
            printf("  Removed position component from entity %llu\n", entities[i]);
        } else {
            printf("  Failed to remove position component from entity %llu\n", entities[i]);
        }
    }
    
    // Test getting component data
    printf("Testing component data retrieval...\n");
    void* component_data = get_component(entities[0], COMPONENT_POSITION);
    if (component_data != NULL) {
        position_component_t* pos = (position_component_t*)component_data;
        printf("  Entity %llu position: (%.2f, %.2f, %.2f)\n", 
               entities[0], pos->x, pos->y, pos->z);
    } else {
        printf("  Could not retrieve position component for entity %llu\n", entities[0]);
    }
}

// Performance test with system updates
void test_performance(int update_cycles) {
    printf("\n=== Performance Testing ===\n");
    printf("Running %d update cycles...\n", update_cycles);
    
    clock_t start_time = clock();
    
    for (int i = 0; i < update_cycles; i++) {
        // Simulate 60 FPS (16.67ms per frame)
        entity_system_update(1.0f / 60.0f);
        
        if (i % 10 == 0) {
            printf("  Completed %d update cycles\n", i);
        }
    }
    
    clock_t end_time = clock();
    double total_time = ((double)(end_time - start_time)) / CLOCKS_PER_SEC;
    double avg_time_per_update = (total_time * 1000.0) / update_cycles;
    
    printf("Performance Results:\n");
    printf("  Total time: %.3f seconds\n", total_time);
    printf("  Average time per update: %.3f ms\n", avg_time_per_update);
    printf("  Target time per update: 16.67 ms (60 FPS)\n");
    
    if (avg_time_per_update < 16.67) {
        printf("  PERFORMANCE: GOOD (meeting 60 FPS target)\n");
    } else {
        printf("  PERFORMANCE: NEEDS OPTIMIZATION (below 60 FPS)\n");
    }
}

// Clean up test entities
void cleanup_test_entities(entity_id_t* entities, int count) {
    printf("\nCleaning up %d test entities...\n", count);
    
    int destroyed_count = 0;
    for (int i = 0; i < count; i++) {
        if (destroy_entity(entities[i]) == 0) {
            destroyed_count++;
        }
        
        if (i % 100 == 0) {
            printf("  Destroyed %d entities...\n", i);
        }
    }
    
    printf("Successfully destroyed %d out of %d entities\n", destroyed_count, count);
}

//==============================================================================
// Main Demo Function
//==============================================================================

int main(int argc, char* argv[]) {
    printf("SimCity ARM64 Entity System Demo\n");
    printf("Agent A5: Simulation Team - ECS Demonstration\n");
    printf("===============================================\n");
    
    // Initialize entity system
    printf("Initializing entity system...\n");
    int init_result = entity_system_init();
    if (init_result != 0) {
        printf("ERROR: Failed to initialize entity system (code: %d)\n", init_result);
        return 1;
    }
    printf("Entity system initialized successfully\n");
    
    // Register with core framework (if available)
    printf("Registering with core framework...\n");
    int register_result = register_entity_system_with_core();
    if (register_result == 0) {
        printf("Successfully registered with core framework\n");
    } else {
        printf("Core framework registration failed (code: %d)\n", register_result);
    }
    
    // Show initial stats
    print_stats("Initial");
    
    // Allocate entity storage
    entity_id_t* test_entities = malloc(DEMO_ENTITY_COUNT * sizeof(entity_id_t));
    if (!test_entities) {
        printf("ERROR: Failed to allocate entity storage\n");
        entity_system_shutdown();
        return 1;
    }
    
    // Create test entities
    int created_count = create_test_entities(test_entities, DEMO_ENTITY_COUNT);
    if (created_count == 0) {
        printf("ERROR: Failed to create any test entities\n");
        free(test_entities);
        entity_system_shutdown();
        return 1;
    }
    
    print_stats("After Entity Creation");
    
    // Test component queries
    test_component_queries();
    
    // Test component manipulation
    test_component_manipulation(test_entities, created_count);
    
    print_stats("After Component Tests");
    
    // Performance testing
    test_performance(DEMO_UPDATE_CYCLES);
    
    print_stats("After Performance Test");
    
    // Run unit tests
    printf("\n=== Running Unit Tests ===\n");
    int test_result = run_basic_tests();
    if (test_result == 0) {
        printf("All basic tests passed!\n");
    } else {
        printf("Some tests failed (error count: %d)\n", test_result);
    }
    
    // Cleanup
    cleanup_test_entities(test_entities, created_count);
    free(test_entities);
    
    print_stats("After Cleanup");
    
    // Show memory statistics
    printf("\n=== Memory Usage Statistics ===\n");
    uint64_t memory_stats[5];
    get_entity_memory_stats(memory_stats);
    printf("Total Allocated:    %llu bytes\n", memory_stats[0]);
    printf("Peak Usage:         %llu bytes\n", memory_stats[1]);
    printf("Allocation Count:   %llu\n", memory_stats[2]);
    printf("Deallocation Count: %llu\n", memory_stats[3]);
    printf("Fragmentation:      %llu%%\n", memory_stats[4]);
    
    // Shutdown entity system
    printf("\nShutting down entity system...\n");
    entity_system_shutdown();
    
    printf("\nDemo completed successfully!\n");
    return 0;
}

//==============================================================================
// Build Instructions
//==============================================================================

/*
To build this demo:

# Assemble the ARM64 assembly files
as -arch arm64 -o entity_system.o src/simulation/entity_system.s
as -arch arm64 -o entity_query.o src/simulation/entity_query.s  
as -arch arm64 -o entity_integration.o src/simulation/entity_integration.s
as -arch arm64 -o entity_tests.o src/simulation/entity_tests.s

# Compile the demo
clang -o entity_demo src/simulation/entity_demo.c entity_system.o entity_query.o entity_integration.o entity_tests.o -arch arm64

# Run the demo
./entity_demo

Expected Output:
- Entity creation and management
- Component query demonstrations
- Performance measurements
- Memory usage statistics
- Unit test results

The demo should demonstrate:
1. Creating 1000+ entities with various component combinations
2. Querying entities by component types
3. Adding/removing components dynamically
4. System update performance (targeting 60 FPS)
5. Memory efficiency and cleanup
*/