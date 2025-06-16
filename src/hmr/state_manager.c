/*
 * SimCity ARM64 - Advanced HMR State Management Implementation
 * Agent 3: Runtime Integration - Day 6 Implementation
 * 
 * Advanced state management for hot module replacement
 * Features incremental updates, NEON-optimized diffing, validation, and compression
 * 
 * Performance Targets:
 * - Incremental update: <1ms for 1000 agents
 * - State diffing: <2ms with NEON SIMD
 * - Validation: <5ms for full system
 * - Compression: 50%+ ratio with <10ms overhead
 */

#include "state_manager.h"
#include <string.h>
#include <stdlib.h>
#include <mach/mach_time.h>
#include <stdatomic.h>
#include <arm_neon.h>

// =============================================================================
// Internal Constants and Structures
// =============================================================================

#define HMR_STATE_MAGIC_NUMBER      0x48535254      // "HSRT" - HMR State Runtime
#define HMR_STATE_CHECKSUM_SEED     0x9E3779B9      // Golden ratio for checksum
#define HMR_STATE_DIFF_BUFFER_SIZE  (1024 * 1024)   // 1MB diff buffer
#define HMR_STATE_CHUNK_ALIGNMENT   64              // 64-byte alignment for NEON

// Internal state chunk with full metadata
typedef struct __attribute__((aligned(64))) {
    hmr_state_chunk_t header;       // Public chunk header
    void* data;                     // Chunk data pointer
    void* compressed_data;          // Compressed data (if compressed)
    void* backup_data;              // Backup for rollback
    uint64_t crc64_table[256];      // CRC64 lookup table
    _Atomic uint32_t access_count;  // Access counter for LRU
    bool needs_backup;              // Whether backup is needed
} hmr_state_chunk_internal_t;

// Performance tracking structure
typedef struct {
    uint64_t total_update_time;     // Total time spent in updates
    uint64_t total_diff_time;       // Total time spent in diffing
    uint64_t total_validation_time; // Total time spent in validation
    uint64_t total_compression_time; // Total time spent in compression
    uint32_t update_count;          // Number of updates performed
    uint32_t diff_count;            // Number of diffs generated
    uint32_t validation_count;      // Number of validations performed
    uint32_t compression_count;     // Number of compressions performed
} hmr_state_performance_t;

// Global state manager instance
static hmr_state_manager_t g_state_manager = {0};
static hmr_state_performance_t g_performance = {0};
static mach_timebase_info_data_t g_timebase_info = {0};
static bool g_state_manager_initialized = false;
static uint32_t g_compression_threshold = HMR_STATE_COMPRESSION_THRESHOLD;

// =============================================================================
// Utility Functions
// =============================================================================

// Get high-resolution timestamp in nanoseconds
static inline uint64_t hmr_state_get_timestamp_ns(void) {
    uint64_t absolute_time = mach_absolute_time();
    return (absolute_time * g_timebase_info.numer) / g_timebase_info.denom;
}

// CRC64 calculation for checksums
static uint64_t hmr_state_crc64(const void* data, size_t length, uint64_t seed) {
    const uint8_t* bytes = (const uint8_t*)data;
    uint64_t crc = seed;
    
    // Process 8 bytes at a time using NEON when possible
    size_t chunks = length / 8;
    const uint64_t* chunks64 = (const uint64_t*)bytes;
    
    for (size_t i = 0; i < chunks; i++) {
        crc ^= chunks64[i];
        for (int j = 0; j < 8; j++) {
            crc = (crc >> 1) ^ ((crc & 1) ? 0xC96C5795D7870F42ULL : 0);
        }
    }
    
    // Process remaining bytes
    for (size_t i = chunks * 8; i < length; i++) {
        crc ^= bytes[i];
        for (int j = 0; j < 8; j++) {
            crc = (crc >> 1) ^ ((crc & 1) ? 0xC96C5795D7870F42ULL : 0);
        }
    }
    
    return crc;
}

// NEON-optimized memory comparison (16 bytes at a time)
static bool hmr_state_neon_compare(const void* a, const void* b, size_t size) {
    const uint8_t* ptr_a = (const uint8_t*)a;
    const uint8_t* ptr_b = (const uint8_t*)b;
    
    // Process 16-byte chunks with NEON
    size_t chunks = size / 16;
    for (size_t i = 0; i < chunks; i++) {
        uint8x16_t vec_a = vld1q_u8(ptr_a + i * 16);
        uint8x16_t vec_b = vld1q_u8(ptr_b + i * 16);
        uint8x16_t diff = veorq_u8(vec_a, vec_b);
        
        // Check if any bytes differ
        uint64x2_t diff64 = vreinterpretq_u64_u8(diff);
        uint64_t low = vgetq_lane_u64(diff64, 0);
        uint64_t high = vgetq_lane_u64(diff64, 1);
        
        if (low != 0 || high != 0) {
            return false; // Difference found
        }
    }
    
    // Process remaining bytes
    for (size_t i = chunks * 16; i < size; i++) {
        if (ptr_a[i] != ptr_b[i]) {
            return false;
        }
    }
    
    return true; // No differences found
}

// Find module by ID
static hmr_state_module_t* hmr_state_find_module(uint32_t module_id) {
    for (uint32_t i = 0; i < g_state_manager.active_modules; i++) {
        if (g_state_manager.modules[i].module_id == module_id) {
            return &g_state_manager.modules[i];
        }
    }
    return NULL;
}

// =============================================================================
// Core State Management Implementation
// =============================================================================

int hmr_state_init(void) {
    if (g_state_manager_initialized) {
        return HMR_STATE_SUCCESS;
    }
    
    // Initialize Mach timebase info
    if (mach_timebase_info(&g_timebase_info) != KERN_SUCCESS) {
        return HMR_STATE_ERROR_INVALID_ARG;
    }
    
    // Initialize state manager
    memset(&g_state_manager, 0, sizeof(g_state_manager));
    memset(&g_performance, 0, sizeof(g_performance));
    
    // Allocate diff buffer
    g_state_manager.diff_buffer = aligned_alloc(64, HMR_STATE_DIFF_BUFFER_SIZE);
    if (!g_state_manager.diff_buffer) {
        return HMR_STATE_ERROR_OUT_OF_MEMORY;
    }
    g_state_manager.diff_buffer_size = HMR_STATE_DIFF_BUFFER_SIZE;
    
    g_state_manager_initialized = true;
    return HMR_STATE_SUCCESS;
}

int hmr_state_shutdown(void) {
    if (!g_state_manager_initialized) {
        return HMR_STATE_SUCCESS;
    }
    
    // Free all module data
    for (uint32_t i = 0; i < g_state_manager.active_modules; i++) {
        hmr_state_module_t* module = &g_state_manager.modules[i];
        
        if (module->chunks) {
            for (uint32_t j = 0; j < module->chunk_count; j++) {
                hmr_state_chunk_internal_t* chunk = (hmr_state_chunk_internal_t*)&module->chunks[j];
                if (chunk->data) free(chunk->data);
                if (chunk->compressed_data) free(chunk->compressed_data);
                if (chunk->backup_data) free(chunk->backup_data);
            }
            free(module->chunks);
        }
        
        if (module->state_data) {
            free(module->state_data);
        }
    }
    
    // Free diff buffer
    if (g_state_manager.diff_buffer) {
        free(g_state_manager.diff_buffer);
    }
    
    g_state_manager_initialized = false;
    return HMR_STATE_SUCCESS;
}

int hmr_state_register_module(uint32_t module_id, const char* module_name,
                             uint32_t agent_size, uint32_t initial_agent_count,
                             uint32_t max_agents) {
    if (!g_state_manager_initialized) {
        return HMR_STATE_ERROR_INVALID_ARG;
    }
    
    if (!module_name || agent_size == 0 || max_agents == 0) {
        return HMR_STATE_ERROR_NULL_POINTER;
    }
    
    if (g_state_manager.active_modules >= HMR_STATE_MAX_MODULES) {
        return HMR_STATE_ERROR_OUT_OF_MEMORY;
    }
    
    // Check if module already exists
    if (hmr_state_find_module(module_id) != NULL) {
        return HMR_STATE_ERROR_INVALID_ARG;
    }
    
    // Initialize new module
    hmr_state_module_t* module = &g_state_manager.modules[g_state_manager.active_modules];
    memset(module, 0, sizeof(hmr_state_module_t));
    
    module->module_id = module_id;
    strncpy(module->module_name, module_name, sizeof(module->module_name) - 1);
    module->agent_size = agent_size;
    module->agent_count = initial_agent_count;
    module->max_agents = max_agents;
    module->incremental_mode = true;
    module->last_update_time = hmr_state_get_timestamp_ns();
    
    // Calculate chunk configuration
    uint32_t agents_per_chunk = HMR_STATE_CHUNK_SIZE / agent_size;
    if (agents_per_chunk == 0) agents_per_chunk = 1;
    
    module->chunk_count = (max_agents + agents_per_chunk - 1) / agents_per_chunk;
    
    // Allocate chunks
    module->chunks = calloc(module->chunk_count, sizeof(hmr_state_chunk_t));
    if (!module->chunks) {
        return HMR_STATE_ERROR_OUT_OF_MEMORY;
    }
    
    // Allocate main state data
    size_t total_size = (size_t)max_agents * agent_size;
    module->state_data = aligned_alloc(64, total_size);
    if (!module->state_data) {
        free(module->chunks);
        return HMR_STATE_ERROR_OUT_OF_MEMORY;
    }
    memset(module->state_data, 0, total_size);
    
    // Initialize chunks
    for (uint32_t i = 0; i < module->chunk_count; i++) {
        hmr_state_chunk_internal_t* chunk = (hmr_state_chunk_internal_t*)&module->chunks[i];
        chunk->header.chunk_id = i;
        chunk->header.agent_start = i * agents_per_chunk;
        chunk->header.agent_count = (i == module->chunk_count - 1) ? 
            (max_agents - chunk->header.agent_start) : agents_per_chunk;
        chunk->header.data_size = chunk->header.agent_count * agent_size;
        chunk->header.timestamp = module->last_update_time;
        chunk->header.dirty = false;
        chunk->header.compressed = false;
        
        // Point to section of main state data
        chunk->data = ((uint8_t*)module->state_data) + 
                     (chunk->header.agent_start * agent_size);
        
        // Calculate initial checksum
        chunk->header.checksum = hmr_state_crc64(chunk->data, 
                                                chunk->header.data_size, 
                                                HMR_STATE_CHECKSUM_SEED);
        
        atomic_store(&chunk->access_count, 0);
        chunk->needs_backup = false;
    }
    
    g_state_manager.active_modules++;
    g_state_manager.total_state_size += total_size;
    
    return HMR_STATE_SUCCESS;
}

int hmr_state_unregister_module(uint32_t module_id) {
    hmr_state_module_t* module = hmr_state_find_module(module_id);
    if (!module) {
        return HMR_STATE_ERROR_NOT_FOUND;
    }
    
    // Free module resources
    if (module->chunks) {
        for (uint32_t i = 0; i < module->chunk_count; i++) {
            hmr_state_chunk_internal_t* chunk = (hmr_state_chunk_internal_t*)&module->chunks[i];
            if (chunk->compressed_data) free(chunk->compressed_data);
            if (chunk->backup_data) free(chunk->backup_data);
        }
        free(module->chunks);
    }
    
    if (module->state_data) {
        g_state_manager.total_state_size -= (size_t)module->max_agents * module->agent_size;
        free(module->state_data);
    }
    
    // Remove from active modules by shifting array
    uint32_t module_index = module - g_state_manager.modules;
    for (uint32_t i = module_index; i < g_state_manager.active_modules - 1; i++) {
        g_state_manager.modules[i] = g_state_manager.modules[i + 1];
    }
    g_state_manager.active_modules--;
    
    return HMR_STATE_SUCCESS;
}

// =============================================================================
// Incremental State Update Implementation
// =============================================================================

int hmr_state_begin_incremental_update(uint32_t module_id) {
    hmr_state_module_t* module = hmr_state_find_module(module_id);
    if (!module) {
        return HMR_STATE_ERROR_NOT_FOUND;
    }
    
    // Create backups for dirty chunks if needed
    for (uint32_t i = 0; i < module->chunk_count; i++) {
        hmr_state_chunk_internal_t* chunk = (hmr_state_chunk_internal_t*)&module->chunks[i];
        
        if (chunk->needs_backup && !chunk->backup_data) {
            chunk->backup_data = malloc(chunk->header.data_size);
            if (chunk->backup_data) {
                memcpy(chunk->backup_data, chunk->data, chunk->header.data_size);
            }
        }
        
        chunk->needs_backup = true;
    }
    
    module->incremental_mode = true;
    return HMR_STATE_SUCCESS;
}

int hmr_state_update_agent_incremental(uint32_t module_id, uint32_t agent_id,
                                      const void* new_state, uint32_t state_size) {
    uint64_t start_time = hmr_state_get_timestamp_ns();
    
    hmr_state_module_t* module = hmr_state_find_module(module_id);
    if (!module || !new_state) {
        return HMR_STATE_ERROR_NULL_POINTER;
    }
    
    if (agent_id >= module->agent_count || state_size != module->agent_size) {
        return HMR_STATE_ERROR_INVALID_ARG;
    }
    
    // Find the chunk containing this agent
    uint32_t agents_per_chunk = HMR_STATE_CHUNK_SIZE / module->agent_size;
    if (agents_per_chunk == 0) agents_per_chunk = 1;
    
    uint32_t chunk_index = agent_id / agents_per_chunk;
    if (chunk_index >= module->chunk_count) {
        return HMR_STATE_ERROR_INVALID_ARG;
    }
    
    hmr_state_chunk_internal_t* chunk = (hmr_state_chunk_internal_t*)&module->chunks[chunk_index];
    
    // Calculate agent offset within chunk
    uint32_t agent_offset_in_chunk = agent_id - chunk->header.agent_start;
    uint8_t* agent_data = ((uint8_t*)chunk->data) + (agent_offset_in_chunk * module->agent_size);
    
    // Check if update is actually needed using NEON comparison
    if (hmr_state_neon_compare(agent_data, new_state, state_size)) {
        // No change needed
        return HMR_STATE_SUCCESS;
    }
    
    // Update agent state
    memcpy(agent_data, new_state, state_size);
    
    // Mark chunk as dirty
    chunk->header.dirty = true;
    chunk->header.timestamp = hmr_state_get_timestamp_ns();
    module->dirty_chunks++;
    
    atomic_fetch_add(&chunk->access_count, 1);
    
    // Update performance metrics
    uint64_t end_time = hmr_state_get_timestamp_ns();
    g_performance.total_update_time += (end_time - start_time);
    g_performance.update_count++;
    
    return HMR_STATE_SUCCESS;
}

int hmr_state_commit_incremental_update(uint32_t module_id) {
    hmr_state_module_t* module = hmr_state_find_module(module_id);
    if (!module) {
        return HMR_STATE_ERROR_NOT_FOUND;
    }
    
    // Update checksums for all dirty chunks
    for (uint32_t i = 0; i < module->chunk_count; i++) {
        hmr_state_chunk_internal_t* chunk = (hmr_state_chunk_internal_t*)&module->chunks[i];
        
        if (chunk->header.dirty) {
            chunk->header.checksum = hmr_state_crc64(chunk->data, 
                                                    chunk->header.data_size, 
                                                    HMR_STATE_CHECKSUM_SEED);
            chunk->header.dirty = false;
        }
    }
    
    module->dirty_chunks = 0;
    module->last_update_time = hmr_state_get_timestamp_ns();
    
    return HMR_STATE_SUCCESS;
}

int hmr_state_add_agents(uint32_t module_id, uint32_t agent_count) {
    hmr_state_module_t* module = hmr_state_find_module(module_id);
    if (!module) {
        return HMR_STATE_ERROR_NOT_FOUND;
    }
    
    uint32_t new_agent_count = module->agent_count + agent_count;
    if (new_agent_count > module->max_agents) {
        return HMR_STATE_ERROR_OUT_OF_MEMORY;
    }
    
    // Initialize new agent states to zero
    uint8_t* new_agent_data = ((uint8_t*)module->state_data) + 
                             (module->agent_count * module->agent_size);
    memset(new_agent_data, 0, agent_count * module->agent_size);
    
    module->agent_count = new_agent_count;
    
    // Update affected chunks
    uint32_t agents_per_chunk = HMR_STATE_CHUNK_SIZE / module->agent_size;
    if (agents_per_chunk == 0) agents_per_chunk = 1;
    
    uint32_t first_affected_chunk = (module->agent_count - agent_count) / agents_per_chunk;
    
    for (uint32_t i = first_affected_chunk; i < module->chunk_count; i++) {
        hmr_state_chunk_internal_t* chunk = (hmr_state_chunk_internal_t*)&module->chunks[i];
        
        // Recalculate chunk agent count
        uint32_t chunk_start = i * agents_per_chunk;
        uint32_t chunk_end = chunk_start + agents_per_chunk;
        if (chunk_end > module->agent_count) {
            chunk_end = module->agent_count;
        }
        
        chunk->header.agent_count = chunk_end - chunk_start;
        chunk->header.data_size = chunk->header.agent_count * module->agent_size;
        
        // Update checksum
        chunk->header.checksum = hmr_state_crc64(chunk->data, 
                                                chunk->header.data_size, 
                                                HMR_STATE_CHECKSUM_SEED);
        chunk->header.timestamp = hmr_state_get_timestamp_ns();
    }
    
    return HMR_STATE_SUCCESS;
}

// =============================================================================
// External NEON Assembly Functions
// =============================================================================

// Declarations for NEON assembly functions
extern uint32_t hmr_state_diff_neon_compare_chunk(const void* old_data, const void* new_data,
                                                  uint32_t size, hmr_state_diff_t* diff_output,
                                                  uint32_t max_diffs, uint32_t* diff_count);

extern uint32_t hmr_state_diff_neon_batch_agents(const void* old_states, const void* new_states,
                                                 uint32_t agent_size, uint32_t agent_count,
                                                 hmr_state_diff_t* diff_results,
                                                 uint32_t max_diffs_per_agent);

extern uint64_t hmr_state_neon_crc64_chunk(const void* data, uint32_t size, uint64_t seed);
extern uint32_t hmr_state_neon_copy_with_diff(void* dest, const void* src, uint32_t size);

// =============================================================================
// State Diffing Functions Implementation
// =============================================================================

int hmr_state_generate_diff(uint32_t module_id, hmr_state_diff_t* diffs,
                           uint32_t max_diffs, uint32_t* diff_count) {
    uint64_t start_time = hmr_state_get_timestamp_ns();
    
    if (!diffs || !diff_count) {
        return HMR_STATE_ERROR_NULL_POINTER;
    }
    
    hmr_state_module_t* module = hmr_state_find_module(module_id);
    if (!module) {
        return HMR_STATE_ERROR_NOT_FOUND;
    }
    
    *diff_count = 0;
    uint32_t total_diffs = 0;
    
    // Process each chunk
    for (uint32_t i = 0; i < module->chunk_count && total_diffs < max_diffs; i++) {
        hmr_state_chunk_internal_t* chunk = (hmr_state_chunk_internal_t*)&module->chunks[i];
        
        // Skip chunks without backup data
        if (!chunk->backup_data) {
            continue;
        }
        
        // Use NEON-optimized comparison
        uint32_t chunk_diffs = 0;
        uint32_t remaining_space = max_diffs - total_diffs;
        
        hmr_state_diff_neon_compare_chunk(chunk->backup_data, chunk->data,
                                         chunk->header.data_size,
                                         &diffs[total_diffs], remaining_space,
                                         &chunk_diffs);
        
        // Adjust diff offsets to be relative to module start
        uint32_t chunk_start_offset = chunk->header.agent_start * module->agent_size;
        for (uint32_t j = total_diffs; j < total_diffs + chunk_diffs; j++) {
            diffs[j].agent_id = chunk->header.agent_start + (diffs[j].offset / module->agent_size);
            diffs[j].offset = chunk_start_offset + diffs[j].offset;
        }
        
        total_diffs += chunk_diffs;
    }
    
    *diff_count = total_diffs;
    
    // Update performance metrics
    uint64_t end_time = hmr_state_get_timestamp_ns();
    g_performance.total_diff_time += (end_time - start_time);
    g_performance.diff_count++;
    
    return HMR_STATE_SUCCESS;
}

int hmr_state_apply_diff(uint32_t module_id, const hmr_state_diff_t* diffs,
                        uint32_t diff_count) {
    hmr_state_module_t* module = hmr_state_find_module(module_id);
    if (!module || !diffs) {
        return HMR_STATE_ERROR_NULL_POINTER;
    }
    
    uint64_t start_time = hmr_state_get_timestamp_ns();
    
    // Apply each diff
    for (uint32_t i = 0; i < diff_count; i++) {
        const hmr_state_diff_t* diff = &diffs[i];
        
        if (diff->agent_id >= module->agent_count) {
            continue; // Skip invalid agent IDs
        }
        
        // Calculate agent data pointer
        uint8_t* agent_data = ((uint8_t*)module->state_data) + 
                             (diff->agent_id * module->agent_size);
        
        // Verify offset is within agent bounds
        if (diff->offset + diff->size > module->agent_size) {
            continue; // Skip invalid diffs
        }
        
        // Apply the diff (restore old data)
        memcpy(agent_data + diff->offset, diff->old_data, diff->size);
    }
    
    // Update checksums for affected chunks
    hmr_state_commit_incremental_update(module_id);
    
    // Update performance metrics
    uint64_t end_time = hmr_state_get_timestamp_ns();
    g_performance.total_diff_time += (end_time - start_time);
    
    return HMR_STATE_SUCCESS;
}

int hmr_state_create_checkpoint(uint32_t module_id) {
    hmr_state_module_t* module = hmr_state_find_module(module_id);
    if (!module) {
        return HMR_STATE_ERROR_NOT_FOUND;
    }
    
    // Create backup data for all chunks
    for (uint32_t i = 0; i < module->chunk_count; i++) {
        hmr_state_chunk_internal_t* chunk = (hmr_state_chunk_internal_t*)&module->chunks[i];
        
        if (!chunk->backup_data) {
            chunk->backup_data = malloc(chunk->header.data_size);
            if (!chunk->backup_data) {
                return HMR_STATE_ERROR_OUT_OF_MEMORY;
            }
        }
        
        memcpy(chunk->backup_data, chunk->data, chunk->header.data_size);
    }
    
    return HMR_STATE_SUCCESS;
}

int hmr_state_restore_checkpoint(uint32_t module_id) {
    hmr_state_module_t* module = hmr_state_find_module(module_id);
    if (!module) {
        return HMR_STATE_ERROR_NOT_FOUND;
    }
    
    // Restore from backup data
    for (uint32_t i = 0; i < module->chunk_count; i++) {
        hmr_state_chunk_internal_t* chunk = (hmr_state_chunk_internal_t*)&module->chunks[i];
        
        if (chunk->backup_data) {
            memcpy(chunk->data, chunk->backup_data, chunk->header.data_size);
            
            // Update checksum
            chunk->header.checksum = hmr_state_crc64(chunk->data, 
                                                    chunk->header.data_size, 
                                                    HMR_STATE_CHECKSUM_SEED);
            chunk->header.timestamp = hmr_state_get_timestamp_ns();
        }
    }
    
    return HMR_STATE_SUCCESS;
}

// =============================================================================
// State Validation Implementation
// =============================================================================

int hmr_state_validate_all(hmr_state_validation_t* validation_result) {
    if (!validation_result) {
        return HMR_STATE_ERROR_NULL_POINTER;
    }
    
    uint64_t start_time = hmr_state_get_timestamp_ns();
    
    memset(validation_result, 0, sizeof(hmr_state_validation_t));
    
    // Validate each module
    for (uint32_t i = 0; i < g_state_manager.active_modules; i++) {
        hmr_state_validation_t module_result;
        int result = hmr_state_validate_module(g_state_manager.modules[i].module_id, &module_result);
        
        validation_result->total_agents += module_result.total_agents;
        validation_result->corrupted_agents += module_result.corrupted_agents;
        validation_result->checksum_failures += module_result.checksum_failures;
        
        if (result != HMR_STATE_SUCCESS) {
            validation_result->validation_passed = false;
        }
    }
    
    uint64_t end_time = hmr_state_get_timestamp_ns();
    validation_result->validation_time_ns = end_time - start_time;
    
    if (validation_result->corrupted_agents == 0 && validation_result->checksum_failures == 0) {
        validation_result->validation_passed = true;
    }
    
    // Update performance metrics
    g_performance.total_validation_time += validation_result->validation_time_ns;
    g_performance.validation_count++;
    
    return validation_result->validation_passed ? HMR_STATE_SUCCESS : HMR_STATE_ERROR_CORRUPTION_DETECTED;
}

int hmr_state_validate_module(uint32_t module_id, hmr_state_validation_t* validation_result) {
    if (!validation_result) {
        return HMR_STATE_ERROR_NULL_POINTER;
    }
    
    hmr_state_module_t* module = hmr_state_find_module(module_id);
    if (!module) {
        return HMR_STATE_ERROR_NOT_FOUND;
    }
    
    uint64_t start_time = hmr_state_get_timestamp_ns();
    
    memset(validation_result, 0, sizeof(hmr_state_validation_t));
    validation_result->total_agents = module->agent_count;
    validation_result->validation_passed = true;
    
    // Validate each chunk
    for (uint32_t i = 0; i < module->chunk_count; i++) {
        hmr_state_chunk_internal_t* chunk = (hmr_state_chunk_internal_t*)&module->chunks[i];
        
        // Calculate current checksum using NEON-optimized function
        uint64_t current_checksum = hmr_state_neon_crc64_chunk(chunk->data,
                                                              chunk->header.data_size,
                                                              HMR_STATE_CHECKSUM_SEED);
        
        if (current_checksum != chunk->header.checksum) {
            validation_result->checksum_failures++;
            validation_result->corrupted_agents += chunk->header.agent_count;
            validation_result->validation_passed = false;
        }
    }
    
    uint64_t end_time = hmr_state_get_timestamp_ns();
    validation_result->validation_time_ns = end_time - start_time;
    
    return validation_result->validation_passed ? HMR_STATE_SUCCESS : HMR_STATE_ERROR_CORRUPTION_DETECTED;
}

int hmr_state_repair_corruption(uint32_t module_id) {
    hmr_state_module_t* module = hmr_state_find_module(module_id);
    if (!module) {
        return HMR_STATE_ERROR_NOT_FOUND;
    }
    
    // For now, attempt repair by restoring from backup
    return hmr_state_restore_checkpoint(module_id);
}

int hmr_state_update_checksums(uint32_t module_id) {
    hmr_state_module_t* module = hmr_state_find_module(module_id);
    if (!module) {
        return HMR_STATE_ERROR_NOT_FOUND;
    }
    
    // Update checksums for all chunks
    for (uint32_t i = 0; i < module->chunk_count; i++) {
        hmr_state_chunk_internal_t* chunk = (hmr_state_chunk_internal_t*)&module->chunks[i];
        
        chunk->header.checksum = hmr_state_neon_crc64_chunk(chunk->data,
                                                           chunk->header.data_size,
                                                           HMR_STATE_CHECKSUM_SEED);
        chunk->header.timestamp = hmr_state_get_timestamp_ns();
    }
    
    return HMR_STATE_SUCCESS;
}

// =============================================================================
// LZ4-Style Compression Implementation
// =============================================================================

// Simple LZ4-inspired compression for state data
// Optimized for structured agent data with repetition
static uint32_t hmr_state_compress_lz4_style(const void* src, uint32_t src_size,
                                             void* dst, uint32_t dst_capacity) {
    const uint8_t* src_ptr = (const uint8_t*)src;
    uint8_t* dst_ptr = (uint8_t*)dst;
    const uint8_t* src_end = src_ptr + src_size;
    uint8_t* dst_end = dst_ptr + dst_capacity;
    
    const uint8_t* literal_start = src_ptr;
    
    while (src_ptr < src_end && dst_ptr < dst_end - 16) {
        // Look for matches
        const uint8_t* best_match = NULL;
        uint32_t best_match_length = 0;
        
        // Look back up to 64KB for matches
        const uint8_t* search_start = (src_ptr >= (const uint8_t*)src + 65536) ? 
                                     src_ptr - 65536 : (const uint8_t*)src;
        
        // Simple search for matches (4+ bytes minimum)
        if (src_ptr >= (const uint8_t*)src + 4) {
            for (const uint8_t* candidate = search_start; candidate <= src_ptr - 4; candidate++) {
                if (memcmp(candidate, src_ptr, 4) == 0) {
                    // Found a 4-byte match, extend it
                    uint32_t match_length = 4;
                    while (src_ptr + match_length < src_end &&
                           candidate + match_length < src_ptr &&
                           src_ptr[match_length] == candidate[match_length] &&
                           match_length < 65535) {
                        match_length++;
                    }
                    
                    if (match_length > best_match_length) {
                        best_match = candidate;
                        best_match_length = match_length;
                    }
                }
            }
        }
        
        if (best_match_length >= 4) {
            // Encode pending literals
            uint32_t literal_length = (uint32_t)(src_ptr - literal_start);
            if (literal_length > 0) {
                if (dst_ptr + literal_length + 1 >= dst_end) break;
                
                *dst_ptr++ = (uint8_t)literal_length;
                memcpy(dst_ptr, literal_start, literal_length);
                dst_ptr += literal_length;
            }
            
            // Encode the match
            if (dst_ptr + 5 >= dst_end) break;
            
            uint16_t offset = (uint16_t)(src_ptr - best_match);
            uint16_t length = (uint16_t)best_match_length;
            
            *dst_ptr++ = 0; // Special marker for match
            *dst_ptr++ = (uint8_t)(offset & 0xFF);
            *dst_ptr++ = (uint8_t)(offset >> 8);
            *dst_ptr++ = (uint8_t)(length & 0xFF);
            *dst_ptr++ = (uint8_t)(length >> 8);
            
            src_ptr += best_match_length;
            literal_start = src_ptr;
        } else {
            // No match found, continue with literals
            src_ptr++;
            
            // If literal run gets too long, flush it
            uint32_t literal_length = (uint32_t)(src_ptr - literal_start);
            if (literal_length >= 255) {
                if (dst_ptr + literal_length + 1 >= dst_end) break;
                
                *dst_ptr++ = (uint8_t)literal_length;
                memcpy(dst_ptr, literal_start, literal_length);
                dst_ptr += literal_length;
                literal_start = src_ptr;
            }
        }
    }
    
    // Flush final literals
    uint32_t final_literal_length = (uint32_t)(src_ptr - literal_start);
    if (final_literal_length > 0 && dst_ptr + final_literal_length + 1 < dst_end) {
        *dst_ptr++ = (uint8_t)final_literal_length;
        memcpy(dst_ptr, literal_start, final_literal_length);
        dst_ptr += final_literal_length;
    }
    
    return (uint32_t)(dst_ptr - (uint8_t*)dst);
}

// Decompress LZ4-style compressed data
static uint32_t hmr_state_decompress_lz4_style(const void* src, uint32_t src_size,
                                               void* dst, uint32_t dst_capacity) {
    const uint8_t* src_ptr = (const uint8_t*)src;
    uint8_t* dst_ptr = (uint8_t*)dst;
    const uint8_t* src_end = src_ptr + src_size;
    uint8_t* dst_end = dst_ptr + dst_capacity;
    
    while (src_ptr < src_end && dst_ptr < dst_end) {
        uint8_t token = *src_ptr++;
        
        if (token == 0) {
            // Match encoding
            if (src_ptr + 4 > src_end) break;
            
            uint16_t offset = src_ptr[0] | (src_ptr[1] << 8);
            uint16_t length = src_ptr[2] | (src_ptr[3] << 8);
            src_ptr += 4;
            
            if (dst_ptr + length > dst_end) break;
            if (dst_ptr - offset < (uint8_t*)dst) break;
            
            // Copy match
            const uint8_t* match_ptr = dst_ptr - offset;
            for (uint16_t i = 0; i < length; i++) {
                *dst_ptr++ = match_ptr[i];
            }
        } else {
            // Literal run
            uint32_t literal_length = token;
            if (src_ptr + literal_length > src_end) break;
            if (dst_ptr + literal_length > dst_end) break;
            
            memcpy(dst_ptr, src_ptr, literal_length);
            src_ptr += literal_length;
            dst_ptr += literal_length;
        }
    }
    
    return (uint32_t)(dst_ptr - (uint8_t*)dst);
}

// =============================================================================
// State Compression Functions Implementation
// =============================================================================

int hmr_state_compress_module(uint32_t module_id, hmr_state_compression_stats_t* stats) {
    if (!stats) {
        return HMR_STATE_ERROR_NULL_POINTER;
    }
    
    hmr_state_module_t* module = hmr_state_find_module(module_id);
    if (!module) {
        return HMR_STATE_ERROR_NOT_FOUND;
    }
    
    uint64_t start_time = hmr_state_get_timestamp_ns();
    
    memset(stats, 0, sizeof(hmr_state_compression_stats_t));
    
    // Compress each chunk
    for (uint32_t i = 0; i < module->chunk_count; i++) {
        hmr_state_chunk_internal_t* chunk = (hmr_state_chunk_internal_t*)&module->chunks[i];
        
        if (chunk->header.compressed || chunk->header.data_size < 1024) {
            continue; // Skip already compressed or small chunks
        }
        
        // Allocate compression buffer
        uint32_t max_compressed_size = chunk->header.data_size + (chunk->header.data_size / 8) + 64;
        void* compressed_buffer = malloc(max_compressed_size);
        if (!compressed_buffer) {
            continue; // Skip on allocation failure
        }
        
        // Compress the chunk data
        uint32_t compressed_size = hmr_state_compress_lz4_style(chunk->data,
                                                               chunk->header.data_size,
                                                               compressed_buffer,
                                                               max_compressed_size);
        
        // Only keep compression if it saves significant space
        if (compressed_size < chunk->header.data_size * 0.9) {
            // Compression was worthwhile
            chunk->compressed_data = compressed_buffer;
            chunk->header.compressed_size = compressed_size;
            chunk->header.compressed = true;
            
            stats->uncompressed_size += chunk->header.data_size;
            stats->compressed_size += compressed_size;
            stats->compressed_chunks++;
            
            g_state_manager.compressed_size += compressed_size;
        } else {
            // Compression not worthwhile, discard
            free(compressed_buffer);
        }
    }
    
    uint64_t end_time = hmr_state_get_timestamp_ns();
    stats->compression_time_ns = end_time - start_time;
    
    if (stats->uncompressed_size > 0) {
        stats->compression_ratio = (float)stats->compressed_size / (float)stats->uncompressed_size;
    }
    
    // Update performance metrics
    g_performance.total_compression_time += stats->compression_time_ns;
    g_performance.compression_count++;
    
    return HMR_STATE_SUCCESS;
}

int hmr_state_decompress_module(uint32_t module_id) {
    hmr_state_module_t* module = hmr_state_find_module(module_id);
    if (!module) {
        return HMR_STATE_ERROR_NOT_FOUND;
    }
    
    // Decompress all compressed chunks
    for (uint32_t i = 0; i < module->chunk_count; i++) {
        hmr_state_chunk_internal_t* chunk = (hmr_state_chunk_internal_t*)&module->chunks[i];
        
        if (!chunk->header.compressed || !chunk->compressed_data) {
            continue;
        }
        
        // Decompress back to original location
        uint32_t decompressed_size = hmr_state_decompress_lz4_style(chunk->compressed_data,
                                                                   chunk->header.compressed_size,
                                                                   chunk->data,
                                                                   chunk->header.data_size);
        
        if (decompressed_size != chunk->header.data_size) {
            return HMR_STATE_ERROR_COMPRESSION_FAILED;
        }
        
        // Free compressed data and update chunk
        free(chunk->compressed_data);
        chunk->compressed_data = NULL;
        chunk->header.compressed_size = 0;
        chunk->header.compressed = false;
        
        g_state_manager.compressed_size -= chunk->header.compressed_size;
        
        // Update checksum
        chunk->header.checksum = hmr_state_crc64(chunk->data,
                                                chunk->header.data_size,
                                                HMR_STATE_CHECKSUM_SEED);
    }
    
    return HMR_STATE_SUCCESS;
}

int hmr_state_compress_all(hmr_state_compression_stats_t* stats) {
    if (!stats) {
        return HMR_STATE_ERROR_NULL_POINTER;
    }
    
    memset(stats, 0, sizeof(hmr_state_compression_stats_t));
    
    uint64_t total_start_time = hmr_state_get_timestamp_ns();
    
    // Compress all modules
    for (uint32_t i = 0; i < g_state_manager.active_modules; i++) {
        hmr_state_compression_stats_t module_stats;
        int result = hmr_state_compress_module(g_state_manager.modules[i].module_id, &module_stats);
        
        if (result == HMR_STATE_SUCCESS) {
            stats->uncompressed_size += module_stats.uncompressed_size;
            stats->compressed_size += module_stats.compressed_size;
            stats->compressed_chunks += module_stats.compressed_chunks;
        }
    }
    
    uint64_t total_end_time = hmr_state_get_timestamp_ns();
    stats->compression_time_ns = total_end_time - total_start_time;
    
    if (stats->uncompressed_size > 0) {
        stats->compression_ratio = (float)stats->compressed_size / (float)stats->uncompressed_size;
    }
    
    return HMR_STATE_SUCCESS;
}

int hmr_state_set_compression_threshold(uint32_t threshold) {
    g_compression_threshold = threshold;
    return HMR_STATE_SUCCESS;
}

// =============================================================================
// State Statistics and Information
// =============================================================================

void hmr_state_get_statistics(uint64_t* total_memory_usage, uint64_t* compressed_memory,
                             uint32_t* active_agent_count, uint32_t* dirty_chunk_count) {
    if (total_memory_usage) {
        *total_memory_usage = g_state_manager.total_state_size;
    }
    
    if (compressed_memory) {
        *compressed_memory = g_state_manager.compressed_size;
    }
    
    if (active_agent_count) {
        uint32_t total_agents = 0;
        for (uint32_t i = 0; i < g_state_manager.active_modules; i++) {
            total_agents += g_state_manager.modules[i].agent_count;
        }
        *active_agent_count = total_agents;
    }
    
    if (dirty_chunk_count) {
        uint32_t dirty_chunks = 0;
        for (uint32_t i = 0; i < g_state_manager.active_modules; i++) {
            dirty_chunks += g_state_manager.modules[i].dirty_chunks;
        }
        *dirty_chunk_count = dirty_chunks;
    }
}

void hmr_state_get_performance_metrics(uint64_t* avg_update_time_ns, uint64_t* avg_diff_time_ns,
                                      uint64_t* avg_validation_time_ns, uint64_t* avg_compression_time_ns) {
    if (avg_update_time_ns) {
        *avg_update_time_ns = g_performance.update_count > 0 ? 
            g_performance.total_update_time / g_performance.update_count : 0;
    }
    
    if (avg_diff_time_ns) {
        *avg_diff_time_ns = g_performance.diff_count > 0 ? 
            g_performance.total_diff_time / g_performance.diff_count : 0;
    }
    
    if (avg_validation_time_ns) {
        *avg_validation_time_ns = g_performance.validation_count > 0 ? 
            g_performance.total_validation_time / g_performance.validation_count : 0;
    }
    
    if (avg_compression_time_ns) {
        *avg_compression_time_ns = g_performance.compression_count > 0 ? 
            g_performance.total_compression_time / g_performance.compression_count : 0;
    }
}

void hmr_state_reset_statistics(void) {
    memset(&g_performance, 0, sizeof(g_performance));
}

void hmr_state_schedule_validation(uint32_t frame_number) {
    g_state_manager.validation_frame_counter = frame_number;
    
    // Schedule validation every HMR_STATE_VALIDATION_INTERVAL frames
    if (frame_number % HMR_STATE_VALIDATION_INTERVAL == 0) {
        hmr_state_validate_all(&g_state_manager.last_validation);
    }
}

int hmr_state_perform_maintenance(uint64_t frame_budget_ns) {
    uint64_t start_time = hmr_state_get_timestamp_ns();
    
    // Perform automatic compression for large modules
    for (uint32_t i = 0; i < g_state_manager.active_modules; i++) {
        uint64_t elapsed = hmr_state_get_timestamp_ns() - start_time;
        if (elapsed >= frame_budget_ns) {
            break; // Budget exceeded
        }
        
        hmr_state_module_t* module = &g_state_manager.modules[i];
        size_t module_size = (size_t)module->agent_count * module->agent_size;
        
        if (module_size > g_compression_threshold) {
            hmr_state_compression_stats_t stats;
            hmr_state_compress_module(module->module_id, &stats);
        }
    }
    
    return HMR_STATE_SUCCESS;
}