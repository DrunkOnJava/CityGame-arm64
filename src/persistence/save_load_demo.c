// SimCity ARM64 Save/Load System Demo
// Agent D3: Infrastructure Team - Save/load system & serialization
// Demo program showing save/load system usage

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>
#include "save_load.h"

//==============================================================================
// Demo Configuration
//==============================================================================

#define DEMO_SAVE_DIR "/tmp/simcity_saves"
#define DEMO_SAVE_FILE "demo_city.sim"
#define DEMO_AUTO_SAVE_FILE "auto_save.sim"
#define DEMO_ENTITY_COUNT 1000
#define DEMO_GRID_SIZE 100

//==============================================================================
// Demo Data Generation
//==============================================================================

// Generate sample game state for testing
GameState generate_sample_game_state(void) {
    GameState state = {0};
    
    state.simulation_tick = 123456;
    state.entity_count = DEMO_ENTITY_COUNT;
    state.building_count = 500;
    state.population = 75000;
    state.money = 1000000;
    state.happiness_avg = 85.5f;
    state.day_cycle = 15;
    state.weather_state = 2; // Sunny
    
    return state;
}

// Generate sample entity data
void generate_sample_entities(EntityData* entities, uint32_t count) {
    for (uint32_t i = 0; i < count; i++) {
        entities[i].entity_id = i + 1;
        entities[i].position_x = (float)(rand() % 1000);
        entities[i].position_y = (float)(rand() % 1000);
        entities[i].state = rand() % 4;
        entities[i].health = 80 + (rand() % 21); // 80-100
        entities[i].happiness = 60 + (rand() % 41); // 60-100
        entities[i].flags = rand();
    }
}

// Generate sample zoning grid
void generate_sample_zoning_grid(ZoneTileData* grid, uint32_t width, uint32_t height) {
    for (uint32_t y = 0; y < height; y++) {
        for (uint32_t x = 0; x < width; x++) {
            uint32_t index = y * width + x;
            ZoneTileData* tile = &grid[index];
            
            tile->zone_type = rand() % 4; // 0=none, 1=residential, 2=commercial, 3=industrial
            tile->building_type = (tile->zone_type == 0) ? 0 : (rand() % 5 + 1);
            tile->population = (tile->zone_type == 1) ? (rand() % 50) : 0;
            tile->jobs = (tile->zone_type > 1) ? (rand() % 30) : 0;
            tile->development_level = (float)(rand() % 100) / 100.0f;
            tile->desirability = (float)(rand() % 100) / 100.0f;
            tile->land_value = (float)(rand() % 1000) + 500.0f;
            tile->age_ticks = rand() % 10000;
            tile->flags = rand() % 16; // Various flags
        }
    }
}

//==============================================================================
// Demo Functions
//==============================================================================

void print_demo_header(void) {
    printf("\n");
    printf("==========================================\n");
    printf("  SimCity ARM64 Save/Load System Demo\n");
    printf("  Agent D3: Infrastructure Team\n");
    printf("==========================================\n\n");
}

void print_game_state(const GameState* state) {
    printf("Game State:\n");
    printf("  Simulation Tick: %llu\n", state->simulation_tick);
    printf("  Entities: %u\n", state->entity_count);
    printf("  Buildings: %u\n", state->building_count);
    printf("  Population: %llu\n", state->population);
    printf("  Money: $%llu\n", state->money);
    printf("  Happiness: %.1f%%\n", state->happiness_avg);
    printf("  Day: %u\n", state->day_cycle);
    printf("  Weather: %u\n", state->weather_state);
    printf("\n");
}

void print_statistics(const SaveLoadStatistics* stats) {
    printf("Performance Statistics:\n");
    printf("  Total Saves: %llu\n", stats->total_saves);
    printf("  Total Loads: %llu\n", stats->total_loads);
    printf("  Bytes Saved: %llu\n", stats->total_bytes_saved);
    printf("  Bytes Loaded: %llu\n", stats->total_bytes_loaded);
    printf("  Avg Save Time: %llu ns\n", stats->avg_save_time_ns);
    printf("  Avg Load Time: %llu ns\n", stats->avg_load_time_ns);
    printf("  Compression Ratio: %.2f%%\n", (float)stats->compression_ratio / 10.0f);
    printf("\n");
}

uint64_t get_time_microseconds(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec * 1000000ULL + tv.tv_usec;
}

//==============================================================================
// Demo Test Cases
//==============================================================================

int demo_basic_save_load(void) {
    printf("=== Basic Save/Load Test ===\n");
    
    // Generate sample game state
    GameState original_state = generate_sample_game_state();
    printf("Original ");
    print_game_state(&original_state);
    
    // Save game state
    printf("Saving game state...\n");
    uint64_t start_time = get_time_microseconds();
    
    int result = save_game_state(DEMO_SAVE_FILE, &original_state, sizeof(GameState));
    if (result != SAVE_SUCCESS) {
        printf("ERROR: Save failed with code %d: %s\n", result, get_save_error_message(result));
        return -1;
    }
    
    uint64_t save_time = get_time_microseconds() - start_time;
    printf("Save completed in %llu microseconds\n\n", save_time);
    
    // Load game state
    printf("Loading game state...\n");
    start_time = get_time_microseconds();
    
    GameState loaded_state = {0};
    size_t loaded_size = 0;
    result = load_game_state(DEMO_SAVE_FILE, &loaded_state, sizeof(GameState), &loaded_size);
    if (result != SAVE_SUCCESS) {
        printf("ERROR: Load failed with code %d: %s\n", result, get_save_error_message(result));
        return -1;
    }
    
    uint64_t load_time = get_time_microseconds() - start_time;
    printf("Load completed in %llu microseconds\n", load_time);
    printf("Loaded %zu bytes\n\n", loaded_size);
    
    printf("Loaded ");
    print_game_state(&loaded_state);
    
    // Verify data integrity
    if (memcmp(&original_state, &loaded_state, sizeof(GameState)) == 0) {
        printf("✓ Data integrity verified - loaded state matches original\n\n");
        return 0;
    } else {
        printf("✗ Data integrity check failed - loaded state differs from original\n\n");
        return -1;
    }
}

int demo_incremental_save_load(void) {
    printf("=== Incremental Save/Load Test ===\n");
    
    // Generate sample data
    EntityData* entities = malloc(sizeof(EntityData) * DEMO_ENTITY_COUNT);
    if (!entities) {
        printf("ERROR: Failed to allocate entity data\n");
        return -1;
    }
    
    ZoneTileData* zoning_grid = malloc(sizeof(ZoneTileData) * DEMO_GRID_SIZE * DEMO_GRID_SIZE);
    if (!zoning_grid) {
        printf("ERROR: Failed to allocate zoning grid\n");
        free(entities);
        return -1;
    }
    
    generate_sample_entities(entities, DEMO_ENTITY_COUNT);
    generate_sample_zoning_grid(zoning_grid, DEMO_GRID_SIZE, DEMO_GRID_SIZE);
    
    printf("Generated %u entities and %ux%u zoning grid\n", 
           DEMO_ENTITY_COUNT, DEMO_GRID_SIZE, DEMO_GRID_SIZE);
    
    // Save incremental chunks
    printf("Saving incremental chunks...\n");
    uint64_t start_time = get_time_microseconds();
    
    // Note: In a real implementation, we would open a file descriptor
    // For demo purposes, we'll simulate file operations
    int save_fd = 1; // Placeholder file descriptor
    
    int result = save_entity_system_state(entities, DEMO_ENTITY_COUNT, save_fd);
    if (result != SAVE_SUCCESS) {
        printf("ERROR: Entity save failed with code %d\n", result);
        free(entities);
        free(zoning_grid);
        return -1;
    }
    
    result = save_zoning_grid_state(zoning_grid, DEMO_GRID_SIZE, DEMO_GRID_SIZE, save_fd);
    if (result != SAVE_SUCCESS) {
        printf("ERROR: Zoning grid save failed with code %d\n", result);
        free(entities);
        free(zoning_grid);
        return -1;
    }
    
    uint64_t save_time = get_time_microseconds() - start_time;
    printf("Incremental save completed in %llu microseconds\n\n", save_time);
    
    // Load incremental chunks
    printf("Loading incremental chunks...\n");
    start_time = get_time_microseconds();
    
    EntityData* loaded_entities = malloc(sizeof(EntityData) * DEMO_ENTITY_COUNT);
    ZoneTileData* loaded_grid = malloc(sizeof(ZoneTileData) * DEMO_GRID_SIZE * DEMO_GRID_SIZE);
    
    if (!loaded_entities || !loaded_grid) {
        printf("ERROR: Failed to allocate load buffers\n");
        free(entities);
        free(zoning_grid);
        free(loaded_entities);
        free(loaded_grid);
        return -1;
    }
    
    int load_fd = 1; // Placeholder file descriptor
    uint32_t loaded_entity_count = 0;
    
    result = load_entity_system_state(loaded_entities, DEMO_ENTITY_COUNT, load_fd, &loaded_entity_count);
    if (result != SAVE_SUCCESS) {
        printf("ERROR: Entity load failed with code %d\n", result);
        free(entities);
        free(zoning_grid);
        free(loaded_entities);
        free(loaded_grid);
        return -1;
    }
    
    result = load_zoning_grid_state(loaded_grid, DEMO_GRID_SIZE, DEMO_GRID_SIZE, load_fd);
    if (result != SAVE_SUCCESS) {
        printf("ERROR: Zoning grid load failed with code %d\n", result);
        free(entities);
        free(zoning_grid);
        free(loaded_entities);
        free(loaded_grid);
        return -1;
    }
    
    uint64_t load_time = get_time_microseconds() - start_time;
    printf("Incremental load completed in %llu microseconds\n", load_time);
    printf("Loaded %u entities\n\n", loaded_entity_count);
    
    // Verify data integrity
    bool entities_match = (memcmp(entities, loaded_entities, sizeof(EntityData) * DEMO_ENTITY_COUNT) == 0);
    bool grid_matches = (memcmp(zoning_grid, loaded_grid, sizeof(ZoneTileData) * DEMO_GRID_SIZE * DEMO_GRID_SIZE) == 0);
    
    if (entities_match && grid_matches) {
        printf("✓ Incremental data integrity verified\n\n");
    } else {
        printf("✗ Incremental data integrity check failed\n");
        if (!entities_match) printf("  - Entity data mismatch\n");
        if (!grid_matches) printf("  - Zoning grid data mismatch\n");
        printf("\n");
    }
    
    // Cleanup
    free(entities);
    free(zoning_grid);
    free(loaded_entities);
    free(loaded_grid);
    
    return (entities_match && grid_matches) ? 0 : -1;
}

int demo_compression_test(void) {
    printf("=== Compression Test ===\n");
    
    // Generate test data with patterns that should compress well
    const size_t test_size = 8192;
    uint8_t* test_data = malloc(test_size);
    uint8_t* compressed_data = malloc(test_size);
    uint8_t* decompressed_data = malloc(test_size);
    
    if (!test_data || !compressed_data || !decompressed_data) {
        printf("ERROR: Failed to allocate test buffers\n");
        free(test_data);
        free(compressed_data);
        free(decompressed_data);
        return -1;
    }
    
    // Fill with repeating pattern for good compression
    for (size_t i = 0; i < test_size; i++) {
        test_data[i] = (uint8_t)(i % 256);
    }
    
    printf("Original data size: %zu bytes\n", test_size);
    
    // Test compression
    size_t compressed_size = 0;
    uint64_t start_time = get_time_microseconds();
    
    int result = compress_data_lz4(test_data, test_size, compressed_data, test_size, &compressed_size);
    if (result != SAVE_SUCCESS) {
        printf("ERROR: Compression failed with code %d\n", result);
        free(test_data);
        free(compressed_data);
        free(decompressed_data);
        return -1;
    }
    
    uint64_t compress_time = get_time_microseconds() - start_time;
    printf("Compressed to %zu bytes in %llu microseconds\n", compressed_size, compress_time);
    printf("Compression ratio: %.2f%%\n", (float)compressed_size * 100.0f / test_size);
    
    // Test decompression
    size_t decompressed_size = 0;
    start_time = get_time_microseconds();
    
    result = decompress_data_lz4(compressed_data, compressed_size, decompressed_data, test_size, &decompressed_size);
    if (result != SAVE_SUCCESS) {
        printf("ERROR: Decompression failed with code %d\n", result);
        free(test_data);
        free(compressed_data);
        free(decompressed_data);
        return -1;
    }
    
    uint64_t decompress_time = get_time_microseconds() - start_time;
    printf("Decompressed to %zu bytes in %llu microseconds\n", decompressed_size, decompress_time);
    
    // Verify data integrity
    if (decompressed_size == test_size && memcmp(test_data, decompressed_data, test_size) == 0) {
        printf("✓ Compression round-trip integrity verified\n\n");
    } else {
        printf("✗ Compression round-trip integrity check failed\n");
        printf("  Original size: %zu, Decompressed size: %zu\n\n", test_size, decompressed_size);
    }
    
    // Cleanup
    free(test_data);
    free(compressed_data);
    free(decompressed_data);
    
    return 0;
}

int demo_checksum_validation(void) {
    printf("=== Checksum Validation Test ===\n");
    
    // Generate test data
    const size_t test_size = 1024;
    uint8_t* test_data = malloc(test_size);
    if (!test_data) {
        printf("ERROR: Failed to allocate test data\n");
        return -1;
    }
    
    // Fill with known pattern
    for (size_t i = 0; i < test_size; i++) {
        test_data[i] = (uint8_t)(i & 0xFF);
    }
    
    // Calculate checksum
    uint64_t start_time = get_time_microseconds();
    uint32_t checksum1 = calculate_crc32(test_data, test_size);
    uint64_t checksum_time = get_time_microseconds() - start_time;
    
    printf("CRC32 checksum: 0x%08X (calculated in %llu microseconds)\n", checksum1, checksum_time);
    
    // Verify consistency
    uint32_t checksum2 = calculate_crc32(test_data, test_size);
    if (checksum1 == checksum2) {
        printf("✓ Checksum consistency verified\n");
    } else {
        printf("✗ Checksum consistency failed\n");
    }
    
    // Test with modified data
    test_data[100] ^= 0xFF; // Flip some bits
    uint32_t checksum3 = calculate_crc32(test_data, test_size);
    
    if (checksum1 != checksum3) {
        printf("✓ Checksum detects data modification\n");
        printf("  Original: 0x%08X, Modified: 0x%08X\n\n", checksum1, checksum3);
    } else {
        printf("✗ Checksum failed to detect data modification\n\n");
    }
    
    free(test_data);
    return 0;
}

int demo_quick_save_load(void) {
    printf("=== Quick Save/Load Test ===\n");
    
    GameState state = generate_sample_game_state();
    printf("Testing quick save to slot 1...\n");
    
    int result = quick_save(1, &state);
    if (result != SAVE_SUCCESS) {
        printf("ERROR: Quick save failed with code %d\n", result);
        return -1;
    }
    printf("✓ Quick save completed\n");
    
    // Modify state to test loading
    state.simulation_tick = 0;
    state.money = 0;
    
    printf("Testing quick load from slot 1...\n");
    result = quick_load(1, &state);
    if (result != SAVE_SUCCESS) {
        printf("ERROR: Quick load failed with code %d\n", result);
        return -1;
    }
    printf("✓ Quick load completed\n");
    
    // Verify loaded state
    if (state.simulation_tick == 123456 && state.money == 1000000) {
        printf("✓ Quick save/load data integrity verified\n\n");
        return 0;
    } else {
        printf("✗ Quick save/load data integrity failed\n\n");
        return -1;
    }
}

//==============================================================================
// Main Demo Program
//==============================================================================

int main(int argc, char* argv[]) {
    print_demo_header();
    
    // Initialize save system
    printf("Initializing save/load system...\n");
    int result = save_system_init(DEMO_SAVE_DIR, 16 * 1024 * 1024); // 16MB max
    if (result != SAVE_SUCCESS) {
        printf("ERROR: Failed to initialize save system: %s\n", get_save_error_message(result));
        return 1;
    }
    printf("✓ Save system initialized\n\n");
    
    // Run demo tests
    int failed_tests = 0;
    
    failed_tests += (demo_basic_save_load() != 0) ? 1 : 0;
    failed_tests += (demo_incremental_save_load() != 0) ? 1 : 0;
    failed_tests += (demo_compression_test() != 0) ? 1 : 0;
    failed_tests += (demo_checksum_validation() != 0) ? 1 : 0;
    failed_tests += (demo_quick_save_load() != 0) ? 1 : 0;
    
    // Show performance statistics
    printf("=== Performance Statistics ===\n");
    SaveLoadStatistics stats;
    get_save_load_statistics(&stats);
    print_statistics(&stats);
    
    // Run unit tests
    printf("=== Running Unit Tests ===\n");
    int test_failures = run_saveload_tests();
    printf("Unit tests completed: %d failures\n\n", test_failures);
    
    // Print final results
    printf("=== Demo Results ===\n");
    printf("Demo tests: %d failed\n", failed_tests);
    printf("Unit tests: %d failed\n", test_failures);
    
    if (failed_tests == 0 && test_failures == 0) {
        printf("✓ All tests passed successfully!\n");
    } else {
        printf("✗ Some tests failed\n");
    }
    
    // Cleanup
    save_system_shutdown();
    printf("\nSave system shut down.\n");
    printf("Demo completed.\n\n");
    
    return (failed_tests + test_failures > 0) ? 1 : 0;
}