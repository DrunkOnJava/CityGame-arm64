/*
 * SimCity ARM64 - Advanced HMR State Management
 * Agent 3: Runtime Integration - Day 6 Implementation
 * 
 * Advanced state management system for hot module replacement
 * Features incremental updates, state diffing, validation, and compression
 * Optimized for 1M+ agents with <5ms state operations
 */

#ifndef HMR_STATE_MANAGER_H
#define HMR_STATE_MANAGER_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// =============================================================================
// Constants and Limits
// =============================================================================

#define HMR_STATE_MAX_MODULES          32          // Maximum tracked modules
#define HMR_STATE_MAX_AGENTS          1048576      // 1M agents maximum
#define HMR_STATE_CHUNK_SIZE          4096         // 4KB state chunks
#define HMR_STATE_DIFF_BATCH_SIZE     64           // Process 64 agents per diff batch
#define HMR_STATE_VALIDATION_INTERVAL 300          // Validate every 5 seconds at 60fps
#define HMR_STATE_COMPRESSION_THRESHOLD 8192       // Compress states >8KB

// =============================================================================
// Error Codes
// =============================================================================

#define HMR_STATE_SUCCESS                    0
#define HMR_STATE_ERROR_NULL_POINTER        -1
#define HMR_STATE_ERROR_INVALID_ARG         -2
#define HMR_STATE_ERROR_NOT_FOUND           -3
#define HMR_STATE_ERROR_OUT_OF_MEMORY       -9
#define HMR_STATE_ERROR_CORRUPTION_DETECTED -20
#define HMR_STATE_ERROR_VALIDATION_FAILED   -21
#define HMR_STATE_ERROR_COMPRESSION_FAILED  -22

// =============================================================================
// State Management Types
// =============================================================================

// State chunk metadata
typedef struct {
    uint32_t chunk_id;                  // Unique chunk identifier
    uint32_t agent_start;               // First agent in this chunk
    uint32_t agent_count;               // Number of agents in chunk
    uint32_t data_size;                 // Size of state data in bytes
    uint32_t compressed_size;           // Size when compressed (0 = not compressed)
    uint64_t checksum;                  // CRC64 checksum for validation
    uint64_t timestamp;                 // Last modification timestamp
    bool dirty;                         // Whether chunk needs updating
    bool compressed;                    // Whether chunk is compressed
} hmr_state_chunk_t;

// State difference entry
typedef struct {
    uint32_t agent_id;                  // Agent that changed
    uint32_t offset;                    // Offset within agent state
    uint32_t size;                      // Size of changed data
    uint8_t old_data[64];              // Previous data (up to 64 bytes)
    uint8_t new_data[64];              // New data (up to 64 bytes)
} hmr_state_diff_t;

// State validation result
typedef struct {
    uint32_t total_agents;              // Total agents validated
    uint32_t corrupted_agents;          // Number of corrupted agents found
    uint32_t checksum_failures;         // Checksum validation failures
    uint64_t validation_time_ns;        // Time spent validating
    bool validation_passed;             // Overall validation result
} hmr_state_validation_t;

// State compression statistics
typedef struct {
    uint64_t uncompressed_size;         // Original size in bytes
    uint64_t compressed_size;           // Compressed size in bytes
    uint64_t compression_time_ns;       // Time spent compressing
    float compression_ratio;            // Compression ratio (compressed/original)
    uint32_t compressed_chunks;         // Number of compressed chunks
} hmr_state_compression_stats_t;

// Module state descriptor
typedef struct {
    uint32_t module_id;                 // Module identifier
    char module_name[64];               // Module name
    uint32_t agent_size;                // Size of each agent state
    uint32_t agent_count;               // Current agent count
    uint32_t max_agents;                // Maximum agents for this module
    void* state_data;                   // Raw state data
    hmr_state_chunk_t* chunks;          // State chunks array
    uint32_t chunk_count;               // Number of chunks
    uint32_t dirty_chunks;              // Number of dirty chunks
    uint64_t last_update_time;          // Last update timestamp
    bool incremental_mode;              // Whether incremental updates are enabled
} hmr_state_module_t;

// Main state manager structure
typedef struct {
    hmr_state_module_t modules[HMR_STATE_MAX_MODULES];
    uint32_t active_modules;            // Number of active modules
    uint64_t total_state_size;          // Total state memory usage
    uint64_t compressed_size;           // Total compressed size
    uint32_t validation_frame_counter;  // Frame counter for validation scheduling
    hmr_state_validation_t last_validation; // Last validation results
    hmr_state_compression_stats_t compression_stats; // Compression statistics
    void* diff_buffer;                  // Buffer for state diffs
    uint32_t diff_buffer_size;          // Size of diff buffer
} hmr_state_manager_t;

// =============================================================================
// Core State Management Functions
// =============================================================================

/**
 * Initialize the state manager
 * Sets up memory allocation and internal structures
 * 
 * @return HMR_STATE_SUCCESS on success, error code on failure
 */
int hmr_state_init(void);

/**
 * Shutdown the state manager
 * Frees all allocated memory and cleans up resources
 * 
 * @return HMR_STATE_SUCCESS on success, error code on failure
 */
int hmr_state_shutdown(void);

/**
 * Register a module for state management
 * 
 * @param module_id Unique module identifier
 * @param module_name Human-readable module name
 * @param agent_size Size of each agent's state in bytes
 * @param initial_agent_count Initial number of agents
 * @param max_agents Maximum number of agents this module can handle
 * @return HMR_STATE_SUCCESS on success, error code on failure
 */
int hmr_state_register_module(uint32_t module_id, const char* module_name,
                             uint32_t agent_size, uint32_t initial_agent_count,
                             uint32_t max_agents);

/**
 * Unregister a module from state management
 * 
 * @param module_id Module identifier to unregister
 * @return HMR_STATE_SUCCESS on success, error code on failure
 */
int hmr_state_unregister_module(uint32_t module_id);

// =============================================================================
// Incremental State Update Functions
// =============================================================================

/**
 * Begin incremental state update for a module
 * Prepares the module for receiving incremental updates
 * 
 * @param module_id Module to update
 * @return HMR_STATE_SUCCESS on success, error code on failure
 */
int hmr_state_begin_incremental_update(uint32_t module_id);

/**
 * Update state for a specific agent with minimal overhead
 * Only updates changed data to minimize memory allocation
 * 
 * @param module_id Module containing the agent
 * @param agent_id Agent to update
 * @param new_state Pointer to new agent state
 * @param state_size Size of state data
 * @return HMR_STATE_SUCCESS on success, error code on failure
 */
int hmr_state_update_agent_incremental(uint32_t module_id, uint32_t agent_id,
                                      const void* new_state, uint32_t state_size);

/**
 * Commit incremental state update
 * Finalizes all pending incremental updates for the module
 * 
 * @param module_id Module to commit updates for
 * @return HMR_STATE_SUCCESS on success, error code on failure
 */
int hmr_state_commit_incremental_update(uint32_t module_id);

/**
 * Add agents to a module (dynamic agent count support)
 * 
 * @param module_id Module to add agents to
 * @param agent_count Number of agents to add
 * @return HMR_STATE_SUCCESS on success, error code on failure
 */
int hmr_state_add_agents(uint32_t module_id, uint32_t agent_count);

// =============================================================================
// State Diffing Functions (NEON Optimized)
// =============================================================================

/**
 * Generate state differences between current and previous state
 * Uses NEON SIMD for fast 16-byte parallel comparison
 * 
 * @param module_id Module to diff
 * @param diffs Output array for state differences
 * @param max_diffs Maximum number of diffs to return
 * @param diff_count Output: actual number of diffs found
 * @return HMR_STATE_SUCCESS on success, error code on failure
 */
int hmr_state_generate_diff(uint32_t module_id, hmr_state_diff_t* diffs,
                           uint32_t max_diffs, uint32_t* diff_count);

/**
 * Apply state differences to restore previous state
 * Used for rollback operations during failed hot-reloads
 * 
 * @param module_id Module to apply diffs to
 * @param diffs Array of state differences
 * @param diff_count Number of diffs to apply
 * @return HMR_STATE_SUCCESS on success, error code on failure
 */
int hmr_state_apply_diff(uint32_t module_id, const hmr_state_diff_t* diffs,
                        uint32_t diff_count);

/**
 * Create a checkpoint of current state for rollback
 * 
 * @param module_id Module to checkpoint
 * @return HMR_STATE_SUCCESS on success, error code on failure
 */
int hmr_state_create_checkpoint(uint32_t module_id);

/**
 * Restore state from the most recent checkpoint
 * 
 * @param module_id Module to restore
 * @return HMR_STATE_SUCCESS on success, error code on failure
 */
int hmr_state_restore_checkpoint(uint32_t module_id);

// =============================================================================
// State Validation and Corruption Detection
// =============================================================================

/**
 * Validate state integrity for all modules
 * Performs comprehensive checksum and structure validation
 * 
 * @param validation_result Output: detailed validation results
 * @return HMR_STATE_SUCCESS if validation passed, error code if corruption detected
 */
int hmr_state_validate_all(hmr_state_validation_t* validation_result);

/**
 * Validate state integrity for a specific module
 * 
 * @param module_id Module to validate
 * @param validation_result Output: validation results for this module
 * @return HMR_STATE_SUCCESS if validation passed, error code if corruption detected
 */
int hmr_state_validate_module(uint32_t module_id, hmr_state_validation_t* validation_result);

/**
 * Repair detected state corruption
 * Attempts to fix corrupted state using checksums and redundancy
 * 
 * @param module_id Module with corruption
 * @return HMR_STATE_SUCCESS if repair succeeded, error code if repair failed
 */
int hmr_state_repair_corruption(uint32_t module_id);

/**
 * Update checksums for all state chunks
 * Call after manual state modifications to maintain integrity
 * 
 * @param module_id Module to update checksums for
 * @return HMR_STATE_SUCCESS on success, error code on failure
 */
int hmr_state_update_checksums(uint32_t module_id);

// =============================================================================
// State Compression Functions
// =============================================================================

/**
 * Compress state data using LZ4-style algorithm
 * Reduces memory usage for large agent populations
 * 
 * @param module_id Module to compress
 * @param stats Output: compression statistics
 * @return HMR_STATE_SUCCESS on success, error code on failure
 */
int hmr_state_compress_module(uint32_t module_id, hmr_state_compression_stats_t* stats);

/**
 * Decompress state data for active use
 * 
 * @param module_id Module to decompress
 * @return HMR_STATE_SUCCESS on success, error code on failure
 */
int hmr_state_decompress_module(uint32_t module_id);

/**
 * Compress all eligible modules based on size threshold
 * 
 * @param stats Output: overall compression statistics
 * @return HMR_STATE_SUCCESS on success, error code on failure
 */
int hmr_state_compress_all(hmr_state_compression_stats_t* stats);

/**
 * Set compression threshold for automatic compression
 * 
 * @param threshold Size threshold in bytes (modules larger than this get compressed)
 * @return HMR_STATE_SUCCESS on success, error code on failure
 */
int hmr_state_set_compression_threshold(uint32_t threshold);

// =============================================================================
// Performance and Statistics Functions
// =============================================================================

/**
 * Get comprehensive state manager statistics
 * 
 * @param total_memory_usage Output: total memory used by state manager
 * @param compressed_memory Output: memory saved through compression
 * @param active_agent_count Output: total number of active agents
 * @param dirty_chunk_count Output: number of chunks needing updates
 */
void hmr_state_get_statistics(uint64_t* total_memory_usage, uint64_t* compressed_memory,
                             uint32_t* active_agent_count, uint32_t* dirty_chunk_count);

/**
 * Get performance metrics for state operations
 * 
 * @param avg_update_time_ns Output: average time for incremental updates
 * @param avg_diff_time_ns Output: average time for state diffing
 * @param avg_validation_time_ns Output: average time for validation
 * @param avg_compression_time_ns Output: average time for compression
 */
void hmr_state_get_performance_metrics(uint64_t* avg_update_time_ns, uint64_t* avg_diff_time_ns,
                                      uint64_t* avg_validation_time_ns, uint64_t* avg_compression_time_ns);

/**
 * Reset all performance counters and statistics
 */
void hmr_state_reset_statistics(void);

// =============================================================================
// Integration Functions
// =============================================================================

/**
 * Schedule automatic validation based on frame counter
 * Call once per frame to schedule periodic validation
 * 
 * @param frame_number Current frame number
 */
void hmr_state_schedule_validation(uint32_t frame_number);

/**
 * Perform maintenance operations (compression, validation)
 * Call periodically to maintain optimal state manager performance
 * 
 * @param frame_budget_ns Maximum time budget for maintenance operations
 * @return HMR_STATE_SUCCESS on success, error code on failure
 */
int hmr_state_perform_maintenance(uint64_t frame_budget_ns);

#ifdef __cplusplus
}
#endif

#endif // HMR_STATE_MANAGER_H