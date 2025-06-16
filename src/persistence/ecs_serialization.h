// SimCity ARM64 ECS Serialization Integration Header
// Sub-Agent 8: Save/Load Integration Specialist
// C interface for ECS serialization with entity_system.s

#ifndef ECS_SERIALIZATION_H
#define ECS_SERIALIZATION_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

//==============================================================================
// Constants and Configuration
//==============================================================================

#define ECS_SERIALIZATION_VERSION_MAJOR 1
#define ECS_SERIALIZATION_VERSION_MINOR 0

// Serialization flags
#define ECS_SERIALIZE_ALL_COMPONENTS    0x00000001
#define ECS_SERIALIZE_ACTIVE_ONLY       0x00000002
#define ECS_SERIALIZE_COMPRESSED        0x00000004
#define ECS_SERIALIZE_WITH_METADATA     0x00000008
#define ECS_SERIALIZE_INCREMENTAL       0x00000010

// Component types (must match entity_system.h)
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

//==============================================================================
// Error Codes
//==============================================================================

typedef enum {
    ECS_SERIALIZE_SUCCESS = 0,
    ECS_SERIALIZE_ERROR_NOT_INITIALIZED = -1,
    ECS_SERIALIZE_ERROR_IN_PROGRESS = -2,
    ECS_SERIALIZE_ERROR_BUFFER_TOO_SMALL = -3,
    ECS_SERIALIZE_ERROR_SERIALIZATION_FAILED = -4,
    ECS_SERIALIZE_ERROR_INVALID_HEADER = -5,
    ECS_SERIALIZE_ERROR_CHECKSUM_MISMATCH = -6,
    ECS_SERIALIZE_ERROR_VERSION_INCOMPATIBLE = -7,
    ECS_SERIALIZE_ERROR_ENTITY_SYSTEM_ERROR = -8
} ECSSerializationErrorCode;

//==============================================================================
// Statistics and Monitoring
//==============================================================================

typedef struct {
    uint64_t entities_serialized;       // Total entities serialized
    uint64_t components_serialized;     // Total components serialized
    uint64_t total_ecs_bytes_saved;     // Total ECS bytes saved
    uint64_t total_ecs_bytes_loaded;    // Total ECS bytes loaded
    uint64_t avg_entity_serialize_ns;   // Average entity serialization time
    uint64_t avg_component_serialize_ns;// Average component serialization time
    uint64_t compression_ratio_ecs;     // ECS-specific compression ratio * 1000
    uint64_t last_serialize_time;       // Timestamp of last serialization
} ECSSerializationStats;

//==============================================================================
// Core ECS Serialization API
//==============================================================================

/**
 * Initialize the ECS serialization system
 * @return ECS_SERIALIZE_SUCCESS on success, error code on failure
 */
int ecs_serialization_init(void);

/**
 * Shutdown the ECS serialization system
 */
void ecs_serialization_shutdown(void);

/**
 * Serialize complete entity system state to buffer
 * @param output_buffer Buffer to write serialized data
 * @param buffer_size Size of output buffer
 * @param serialize_flags Serialization configuration flags
 * @param serialized_size Pointer to store actual serialized size
 * @return ECS_SERIALIZE_SUCCESS on success, error code on failure
 */
int serialize_entity_system(void* output_buffer, size_t buffer_size, 
                            uint32_t serialize_flags, size_t* serialized_size);

/**
 * Deserialize entity system state from buffer
 * @param input_buffer Buffer containing serialized data
 * @param buffer_size Size of input buffer
 * @param deserialize_flags Deserialization configuration flags
 * @param entities_loaded Pointer to store number of entities loaded
 * @return ECS_SERIALIZE_SUCCESS on success, error code on failure
 */
int deserialize_entity_system(const void* input_buffer, size_t buffer_size,
                              uint32_t deserialize_flags, uint32_t* entities_loaded);

//==============================================================================
// Integration with save_load.s System
//==============================================================================

/**
 * Save entity system as incremental chunk (used by save_load.s)
 * @param save_file_fd File descriptor for save file
 * @param serialize_flags Serialization configuration flags
 * @return ECS_SERIALIZE_SUCCESS on success, error code on failure
 */
int save_entity_system_chunk(int save_file_fd, uint32_t serialize_flags);

/**
 * Load entity system from incremental chunk (used by save_load.s)
 * @param load_file_fd File descriptor for load file
 * @param deserialize_flags Deserialization configuration flags
 * @param entities_loaded Pointer to store number of entities loaded
 * @return ECS_SERIALIZE_SUCCESS on success, error code on failure
 */
int load_entity_system_chunk(int load_file_fd, uint32_t deserialize_flags,
                             uint32_t* entities_loaded);

//==============================================================================
// Component-Specific Serialization
//==============================================================================

/**
 * Serialize specific component type for all entities
 * @param component_type Component type to serialize
 * @param output_buffer Buffer to write serialized data
 * @param buffer_size Size of output buffer
 * @param serialized_size Pointer to store actual serialized size
 * @return ECS_SERIALIZE_SUCCESS on success, error code on failure
 */
int serialize_component_type_all(uint32_t component_type, void* output_buffer,
                                size_t buffer_size, size_t* serialized_size);

/**
 * Deserialize specific component type for all entities
 * @param component_type Component type to deserialize
 * @param input_buffer Buffer containing serialized data
 * @param buffer_size Size of input buffer
 * @param components_loaded Pointer to store number of components loaded
 * @return ECS_SERIALIZE_SUCCESS on success, error code on failure
 */
int deserialize_component_type_all(uint32_t component_type, const void* input_buffer,
                                  size_t buffer_size, uint32_t* components_loaded);

//==============================================================================
// Incremental/Streaming Serialization
//==============================================================================

/**
 * Begin incremental serialization session
 * @param max_entities_per_chunk Maximum entities per chunk
 * @param serialize_flags Serialization configuration flags
 * @return Session handle (NULL on error)
 */
void* begin_incremental_serialization(uint32_t max_entities_per_chunk, 
                                      uint32_t serialize_flags);

/**
 * Serialize next chunk of entities
 * @param session_handle Session from begin_incremental_serialization
 * @param output_buffer Buffer to write chunk data
 * @param buffer_size Size of output buffer
 * @param chunk_size Pointer to store actual chunk size
 * @param is_final_chunk Pointer to store if this is the final chunk
 * @return ECS_SERIALIZE_SUCCESS on success, error code on failure
 */
int serialize_next_chunk(void* session_handle, void* output_buffer,
                        size_t buffer_size, size_t* chunk_size, 
                        bool* is_final_chunk);

/**
 * End incremental serialization session
 * @param session_handle Session to end
 */
void end_incremental_serialization(void* session_handle);

//==============================================================================
// Entity Filtering and Selection
//==============================================================================

/**
 * Serialize only entities matching specific criteria
 * @param entity_filter_func Function to test if entity should be serialized
 * @param filter_context Context data for filter function
 * @param output_buffer Buffer to write serialized data
 * @param buffer_size Size of output buffer
 * @param serialized_size Pointer to store actual serialized size
 * @return ECS_SERIALIZE_SUCCESS on success, error code on failure
 */
int serialize_filtered_entities(bool (*entity_filter_func)(uint64_t entity_id, void* context),
                               void* filter_context, void* output_buffer,
                               size_t buffer_size, size_t* serialized_size);

/**
 * Serialize entities within specific spatial bounds
 * @param min_x Minimum X coordinate
 * @param min_y Minimum Y coordinate
 * @param max_x Maximum X coordinate
 * @param max_y Maximum Y coordinate
 * @param output_buffer Buffer to write serialized data
 * @param buffer_size Size of output buffer
 * @param serialized_size Pointer to store actual serialized size
 * @return ECS_SERIALIZE_SUCCESS on success, error code on failure
 */
int serialize_entities_in_bounds(float min_x, float min_y, float max_x, float max_y,
                                void* output_buffer, size_t buffer_size,
                                size_t* serialized_size);

//==============================================================================
// Statistics and Monitoring
//==============================================================================

/**
 * Get ECS serialization performance statistics
 * @param stats_output Pointer to statistics structure
 */
void get_ecs_serialization_stats(ECSSerializationStats* stats_output);

/**
 * Reset ECS serialization performance statistics
 */
void reset_ecs_serialization_stats(void);

/**
 * Estimate serialized size for current entity system state
 * @param serialize_flags Serialization configuration flags
 * @return Estimated size in bytes (0 on error)
 */
size_t estimate_serialized_ecs_size(uint32_t serialize_flags);

/**
 * Validate serialized ECS data without full deserialization
 * @param serialized_data Buffer containing serialized data
 * @param data_size Size of serialized data
 * @return ECS_SERIALIZE_SUCCESS if valid, error code if invalid
 */
int validate_serialized_ecs_data(const void* serialized_data, size_t data_size);

//==============================================================================
// Testing and Debugging
//==============================================================================

/**
 * Run comprehensive ECS serialization tests
 * @return Number of failed tests (0 = all tests passed)
 */
int run_ecs_serialization_tests(void);

/**
 * Generate test entity system state for testing
 * @param num_entities Number of test entities to create
 * @param component_mask Bitmask of components to add to entities
 * @return ECS_SERIALIZE_SUCCESS on success, error code on failure
 */
int generate_test_ecs_state(uint32_t num_entities, uint64_t component_mask);

/**
 * Compare two entity system states for equality
 * @param serialize_flags Serialization flags for comparison
 * @return true if states are identical, false otherwise
 */
bool compare_entity_system_states(uint32_t serialize_flags);

//==============================================================================
// Performance Optimization
//==============================================================================

/**
 * Enable/disable NEON acceleration for serialization
 * @param enable true to enable NEON acceleration
 * @return ECS_SERIALIZE_SUCCESS on success, error code on failure
 */
int set_ecs_neon_acceleration(bool enable);

/**
 * Set chunk size for incremental serialization
 * @param chunk_size_bytes Chunk size in bytes
 * @return ECS_SERIALIZE_SUCCESS on success, error code on failure
 */
int set_ecs_serialization_chunk_size(uint32_t chunk_size_bytes);

/**
 * Configure compression settings for ECS serialization
 * @param enable_compression true to enable compression
 * @param compression_level Compression level (1-9)
 * @return ECS_SERIALIZE_SUCCESS on success, error code on failure
 */
int configure_ecs_compression(bool enable_compression, int compression_level);

//==============================================================================
// Utility Functions
//==============================================================================

/**
 * Get human-readable error message for ECS serialization error code
 * @param error_code Error code from ECS serialization operation
 * @return Pointer to error message string
 */
const char* get_ecs_serialization_error_message(ECSSerializationErrorCode error_code);

/**
 * Get current memory usage of ECS serialization system
 * @return Memory usage in bytes
 */
size_t get_ecs_serialization_memory_usage(void);

/**
 * Check if ECS serialization system is initialized
 * @return true if initialized, false otherwise
 */
bool is_ecs_serialization_initialized(void);

#ifdef __cplusplus
}
#endif

#endif // ECS_SERIALIZATION_H