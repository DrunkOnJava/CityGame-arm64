// SimCity ARM64 Save/Load System & Serialization Header
// Agent D3: Infrastructure Team - Save/load system & serialization
// C interface for pure ARM64 assembly save/load implementation

#ifndef SAVE_LOAD_H
#define SAVE_LOAD_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

//==============================================================================
// Type Definitions and Constants
//==============================================================================

// Save file format version
#define SAVE_FORMAT_VERSION_MAJOR   1
#define SAVE_FORMAT_VERSION_MINOR   0
#define SAVE_FORMAT_VERSION_PATCH   0

// Save file magic number
#define SAVE_FILE_MAGIC             0x53494D4349545953ULL  // "SIMCITYS"

// Maximum save file size (1GB)
#define MAX_SAVE_FILE_SIZE          0x40000000ULL

// Chunk types for incremental saving
typedef enum {
    CHUNK_SIMULATION_STATE = 1,
    CHUNK_ENTITY_DATA = 2,
    CHUNK_ZONING_GRID = 3,
    CHUNK_ROAD_NETWORK = 4,
    CHUNK_BUILDING_DATA = 5,
    CHUNK_AGENT_DATA = 6,
    CHUNK_ECONOMY_DATA = 7,
    CHUNK_RESOURCE_DATA = 8,
    CHUNK_GRAPHICS_CACHE = 9,
    CHUNK_USER_PREFERENCES = 10
} ChunkType;

// Error codes
typedef enum {
    SAVE_SUCCESS = 0,
    SAVE_ERROR_INVALID_INPUT = -1,
    SAVE_ERROR_NOT_INITIALIZED = -2,
    SAVE_ERROR_IN_PROGRESS = -3,
    SAVE_ERROR_OPERATION_FAILED = -4,
    SAVE_ERROR_FILE_NOT_FOUND = -5,
    SAVE_ERROR_COMPRESSION_FAILED = -6,
    SAVE_ERROR_CHECKSUM_MISMATCH = -7,
    SAVE_ERROR_VERSION_INCOMPATIBLE = -8,
    SAVE_ERROR_BUFFER_TOO_SMALL = -9,
    SAVE_ERROR_CORRUPTED_DATA = -10
} SaveErrorCode;

// Save/Load performance statistics
typedef struct {
    uint64_t total_saves;               // Total number of saves performed
    uint64_t total_loads;               // Total number of loads performed
    uint64_t total_bytes_saved;         // Total bytes saved (compressed)
    uint64_t total_bytes_loaded;        // Total bytes loaded (uncompressed)
    uint64_t avg_save_time_ns;          // Average save time in nanoseconds
    uint64_t avg_load_time_ns;          // Average load time in nanoseconds
    uint64_t compression_ratio;         // Compression ratio * 1000
    uint64_t last_save_time;            // Timestamp of last save
    uint64_t last_load_time;            // Timestamp of last load
} SaveLoadStatistics;

// Game state structure for serialization
typedef struct {
    uint64_t simulation_tick;           // Current simulation tick
    uint32_t entity_count;              // Number of entities
    uint32_t building_count;            // Number of buildings
    uint64_t population;                // Total population
    uint64_t money;                     // Available money
    float happiness_avg;                // Average happiness (0.0-100.0)
    uint32_t day_cycle;                 // Current day in cycle
    uint8_t weather_state;              // Current weather
    uint8_t reserved[15];               // Alignment padding
} __attribute__((packed)) GameState;

// Entity data structure for incremental saves
typedef struct {
    uint32_t entity_id;                 // Unique entity identifier
    float position_x;                   // X position in world
    float position_y;                   // Y position in world
    uint32_t state;                     // Entity state flags
    uint16_t health;                    // Health value (0-100)
    uint16_t happiness;                 // Happiness value (0-100)
    uint32_t flags;                     // Additional status flags
} __attribute__((packed)) EntityData;

// Zoning grid tile data
typedef struct {
    uint8_t zone_type;                  // Zone type (residential/commercial/industrial)
    uint8_t building_type;              // Building type if developed
    uint16_t population;                // Population in this tile
    uint16_t jobs;                      // Jobs provided by this tile
    float development_level;            // Development level (0.0-1.0)
    float desirability;                 // Desirability factor
    float land_value;                   // Land value
    uint32_t age_ticks;                 // Age since zoned/built
    uint8_t flags;                      // Various flags (power, water, etc.)
    uint8_t reserved[3];                // Padding for alignment
} __attribute__((packed)) ZoneTileData;

//==============================================================================
// Core Save/Load System API
//==============================================================================

/**
 * Initialize the save/load system
 * @param save_directory Directory to store save files
 * @param max_memory_usage Maximum memory usage in bytes
 * @return SAVE_SUCCESS on success, error code on failure
 */
int save_system_init(const char* save_directory, uint64_t max_memory_usage);

/**
 * Shutdown the save/load system and cleanup resources
 */
void save_system_shutdown(void);

/**
 * Save complete game state to file
 * @param filename Name of save file
 * @param game_state Pointer to game state data
 * @param state_size Size of game state data in bytes
 * @return SAVE_SUCCESS on success, error code on failure
 */
int save_game_state(const char* filename, const void* game_state, size_t state_size);

/**
 * Load complete game state from file
 * @param filename Name of save file
 * @param game_state_buffer Buffer to load game state into
 * @param buffer_size Size of buffer in bytes
 * @param actual_size_loaded Pointer to store actual size loaded (optional)
 * @return SAVE_SUCCESS on success, error code on failure
 */
int load_game_state(const char* filename, void* game_state_buffer, 
                   size_t buffer_size, size_t* actual_size_loaded);

//==============================================================================
// Incremental Save System for Large Cities
//==============================================================================

/**
 * Save a specific data chunk incrementally
 * @param chunk_type Type of chunk being saved
 * @param data_ptr Pointer to chunk data
 * @param data_size Size of chunk data
 * @param save_file_fd File descriptor of open save file
 * @return SAVE_SUCCESS on success, error code on failure
 */
int save_incremental_chunk(ChunkType chunk_type, const void* data_ptr, 
                          size_t data_size, int save_file_fd);

/**
 * Load a specific data chunk
 * @param chunk_type Type of chunk to load
 * @param buffer_ptr Buffer to load chunk into
 * @param buffer_size Size of buffer
 * @param load_file_fd File descriptor of open save file
 * @param actual_size_loaded Pointer to store actual size loaded (optional)
 * @return SAVE_SUCCESS on success, error code on failure
 */
int load_incremental_chunk(ChunkType chunk_type, void* buffer_ptr, 
                          size_t buffer_size, int load_file_fd, 
                          size_t* actual_size_loaded);

//==============================================================================
// Fast Compression/Decompression
//==============================================================================

/**
 * Compress data using fast LZ4-style compression
 * @param input_buffer Source data to compress
 * @param input_size Size of source data
 * @param output_buffer Destination buffer for compressed data
 * @param output_buffer_size Size of destination buffer
 * @param compressed_size Pointer to store actual compressed size
 * @return SAVE_SUCCESS on success, error code on failure
 */
int compress_data_lz4(const void* input_buffer, size_t input_size,
                     void* output_buffer, size_t output_buffer_size,
                     size_t* compressed_size);

/**
 * Decompress LZ4-style compressed data
 * @param compressed_buffer Compressed source data
 * @param compressed_size Size of compressed data
 * @param output_buffer Destination buffer for decompressed data
 * @param output_buffer_size Size of destination buffer
 * @param decompressed_size Pointer to store actual decompressed size
 * @return SAVE_SUCCESS on success, error code on failure
 */
int decompress_data_lz4(const void* compressed_buffer, size_t compressed_size,
                       void* output_buffer, size_t output_buffer_size,
                       size_t* decompressed_size);

//==============================================================================
// Checksum Validation and Error Recovery
//==============================================================================

/**
 * Calculate CRC32 checksum of data
 * @param data_ptr Pointer to data
 * @param data_size Size of data in bytes
 * @return CRC32 checksum value
 */
uint32_t calculate_crc32(const void* data_ptr, size_t data_size);

/**
 * Verify save file integrity using checksums
 * @param file_fd File descriptor of open save file
 * @return SAVE_SUCCESS if file is valid, error code if corrupted
 */
int verify_file_integrity(int file_fd);

/**
 * Attempt to recover corrupted save file
 * @param filename Name of corrupted save file
 * @param recovery_filename Name for recovered file
 * @return SAVE_SUCCESS if recovery successful, error code on failure
 */
int recover_corrupted_save(const char* filename, const char* recovery_filename);

//==============================================================================
// Version Migration and Backward Compatibility
//==============================================================================

/**
 * Migrate save file from older version to current version
 * @param old_version Old save format version
 * @param new_version Target save format version
 * @param data_ptr Pointer to save data
 * @param data_size Size of save data
 * @param new_data_size Pointer to store new data size after migration
 * @return SAVE_SUCCESS on success, error code on failure
 */
int migrate_save_version(uint32_t old_version, uint32_t new_version,
                        void* data_ptr, size_t data_size, size_t* new_data_size);

/**
 * Check if save file version is compatible
 * @param filename Name of save file to check
 * @param file_version Pointer to store detected file version
 * @return true if compatible, false if migration needed
 */
bool is_save_version_compatible(const char* filename, uint32_t* file_version);

//==============================================================================
// Performance Statistics and Monitoring
//==============================================================================

/**
 * Get save/load system performance statistics
 * @param stats_output Pointer to statistics structure
 */
void get_save_load_statistics(SaveLoadStatistics* stats_output);

/**
 * Reset performance statistics
 */
void reset_save_load_statistics(void);

/**
 * Print detailed performance report to console
 */
void print_save_load_performance_report(void);

//==============================================================================
// High-Level Convenience Functions
//==============================================================================

/**
 * Quick save current game state
 * @param slot_number Save slot (0-9)
 * @param game_state Pointer to game state
 * @return SAVE_SUCCESS on success, error code on failure
 */
int quick_save(int slot_number, const GameState* game_state);

/**
 * Quick load game state from slot
 * @param slot_number Save slot (0-9)
 * @param game_state Pointer to load game state into
 * @return SAVE_SUCCESS on success, error code on failure
 */
int quick_load(int slot_number, GameState* game_state);

/**
 * Auto-save game state (called periodically by game loop)
 * @param game_state Pointer to current game state
 * @return SAVE_SUCCESS on success, error code on failure
 */
int auto_save(const GameState* game_state);

/**
 * Export save file to external format (for modding/debugging)
 * @param save_filename Input save file
 * @param export_filename Output export file
 * @param export_format Export format (0=JSON, 1=XML, 2=Binary)
 * @return SAVE_SUCCESS on success, error code on failure
 */
int export_save_file(const char* save_filename, const char* export_filename, 
                    int export_format);

//==============================================================================
// Simulation System Integration
//==============================================================================

/**
 * Save entity system state
 * @param entities Array of entity data
 * @param entity_count Number of entities
 * @param chunk_file_fd File descriptor for incremental save
 * @return SAVE_SUCCESS on success, error code on failure
 */
int save_entity_system_state(const EntityData* entities, uint32_t entity_count,
                             int chunk_file_fd);

/**
 * Load entity system state
 * @param entities Buffer for entity data
 * @param max_entities Maximum number of entities buffer can hold
 * @param chunk_file_fd File descriptor for incremental load
 * @param actual_entity_count Pointer to store actual entities loaded
 * @return SAVE_SUCCESS on success, error code on failure
 */
int load_entity_system_state(EntityData* entities, uint32_t max_entities,
                             int chunk_file_fd, uint32_t* actual_entity_count);

/**
 * Save zoning grid state
 * @param grid_tiles Array of zone tile data
 * @param grid_width Width of zoning grid
 * @param grid_height Height of zoning grid
 * @param chunk_file_fd File descriptor for incremental save
 * @return SAVE_SUCCESS on success, error code on failure
 */
int save_zoning_grid_state(const ZoneTileData* grid_tiles, uint32_t grid_width,
                          uint32_t grid_height, int chunk_file_fd);

/**
 * Load zoning grid state
 * @param grid_tiles Buffer for zone tile data
 * @param grid_width Width of zoning grid
 * @param grid_height Height of zoning grid
 * @param chunk_file_fd File descriptor for incremental load
 * @return SAVE_SUCCESS on success, error code on failure
 */
int load_zoning_grid_state(ZoneTileData* grid_tiles, uint32_t grid_width,
                          uint32_t grid_height, int chunk_file_fd);

//==============================================================================
// Testing and Debugging Interface
//==============================================================================

/**
 * Run comprehensive save/load system unit tests
 * @return Number of failed tests (0 = all tests passed)
 */
int run_saveload_tests(void);

/**
 * Generate test save file with sample data
 * @param filename Name of test file to create
 * @param data_size Size of test data to generate
 * @return SAVE_SUCCESS on success, error code on failure
 */
int generate_test_save_file(const char* filename, size_t data_size);

/**
 * Validate save file format and structure
 * @param filename Name of save file to validate
 * @return SAVE_SUCCESS if valid, error code describing problem
 */
int validate_save_file_format(const char* filename);

//==============================================================================
// Configuration and Tuning
//==============================================================================

/**
 * Set compression level for saves
 * @param level Compression level (1=fastest, 9=best compression)
 * @return SAVE_SUCCESS on success, error code on failure
 */
int set_compression_level(int level);

/**
 * Set auto-save interval
 * @param interval_seconds Interval between auto-saves in seconds (0=disable)
 * @return SAVE_SUCCESS on success, error code on failure
 */
int set_auto_save_interval(uint32_t interval_seconds);

/**
 * Enable/disable save file encryption
 * @param enable true to enable encryption, false to disable
 * @param encryption_key Key for encryption (NULL for default)
 * @return SAVE_SUCCESS on success, error code on failure
 */
int set_save_encryption(bool enable, const char* encryption_key);

//==============================================================================
// Memory Management Integration
//==============================================================================

/**
 * Set custom allocator for save/load system
 * @param alloc_func Custom allocation function
 * @param free_func Custom deallocation function
 * @return SAVE_SUCCESS on success, error code on failure
 */
int set_save_allocator(void* (*alloc_func)(size_t), void (*free_func)(void*));

/**
 * Get current memory usage of save/load system
 * @return Memory usage in bytes
 */
size_t get_save_system_memory_usage(void);

//==============================================================================
// Utility Functions and Helpers
//==============================================================================

/**
 * Get human-readable error message for error code
 * @param error_code Error code from save/load operation
 * @return Pointer to error message string
 */
const char* get_save_error_message(SaveErrorCode error_code);

/**
 * Get save file info without loading entire file
 * @param filename Name of save file
 * @param creation_time Pointer to store creation time (optional)
 * @param file_size Pointer to store file size (optional)
 * @param version Pointer to store save format version (optional)
 * @return SAVE_SUCCESS on success, error code on failure
 */
int get_save_file_info(const char* filename, uint64_t* creation_time,
                      size_t* file_size, uint32_t* version);

/**
 * List all save files in save directory
 * @param save_list Buffer to store list of save filenames
 * @param max_saves Maximum number of saves to list
 * @param actual_save_count Pointer to store actual number found
 * @return SAVE_SUCCESS on success, error code on failure
 */
int list_save_files(char save_list[][256], uint32_t max_saves, 
                   uint32_t* actual_save_count);

#ifdef __cplusplus
}
#endif

#endif // SAVE_LOAD_H