// SimCity ARM64 Double Buffered ECS System
// Agent 2: Simulation Systems Developer
// Header definitions for double buffering interface

#ifndef DOUBLE_BUFFER_ECS_H
#define DOUBLE_BUFFER_ECS_H

#include <stdint.h>
#include <pthread.h>

//==============================================================================
// Type Definitions
//==============================================================================

typedef struct {
    uint32_t active_buffer;              // Current active buffer (0 or 1)
    uint8_t world_buffers[2 * 8192];     // Two ECS world buffers (placeholder size)
    
    // Synchronization
    pthread_mutex_t buffer_mutex;        // Mutex for buffer swapping
    volatile uint32_t read_in_progress;  // Number of readers in progress
    volatile uint32_t write_pending;     // Write operation pending flag
    
    // Performance metrics
    uint64_t buffer_swaps;               // Total buffer swaps
    uint64_t avg_swap_time_ns;           // Average swap time in nanoseconds
    uint64_t last_swap_time_ns;          // Last swap timestamp
    
    // Memory management
    void* shared_allocator;              // Shared allocator for both buffers
    void* temp_allocator;                // Temporary allocator for swap operations
    
    uint8_t padding[32];                 // Cache line alignment
} DoubleBufferedWorld;

typedef struct {
    // Double buffered component arrays
    void* buffer_a;                      // Buffer A component data
    void* buffer_b;                      // Buffer B component data
    
    // Buffer metadata
    uint32_t size;                       // Size of each buffer
    uint32_t element_count;              // Number of elements currently used
    uint32_t capacity;                   // Maximum number of elements
    uint32_t element_size;               // Size of each component
    
    // Dirty tracking for optimization
    uint64_t dirty_mask;                 // Bitmask of modified components
    uint64_t last_modified_tick;         // Last modification timestamp
    
    uint8_t padding[16];                 // Alignment
} ComponentBuffer;

//==============================================================================
// Core Functions
//==============================================================================

// Initialize double buffered ECS system
// Returns: 0 on success, error code on failure
int double_buffer_ecs_init(uint32_t max_entities, uint32_t max_archetypes);

// Get pointer to currently active ECS world (read-only access)
void* get_active_world(void);

// Get pointer to currently inactive ECS world (write access)
void* get_inactive_world(void);

// Atomically swap active and inactive buffers
// Returns: 0 on success, error code on failure
int swap_buffers(void);

//==============================================================================
// Thread-Safe Access
//==============================================================================

// Begin reading from active buffer (increments reader count)
// Returns: active world pointer, NULL on error
void* begin_read_access(void);

// End reading from active buffer (decrements reader count)
void end_read_access(void);

//==============================================================================
// Update and Render Interface
//==============================================================================

// Update simulation in background buffer
void double_buffer_update(uint64_t current_tick, float delta_time);

// Render from active buffer
// Returns: active world pointer for rendering (caller must call end_read_access)
void* double_buffer_render(void);

//==============================================================================
// Performance Monitoring
//==============================================================================

typedef struct {
    uint64_t total_swaps;                // Total buffer swaps performed
    uint64_t avg_swap_time_ns;           // Average swap time in nanoseconds
    uint64_t last_swap_time_ns;          // Last swap timestamp
    uint32_t active_readers;             // Current number of active readers
    uint32_t pending_writes;             // Number of pending write operations
    float swap_frequency_hz;             // Swaps per second
} BufferPerformanceStats;

// Get performance statistics for buffer system
BufferPerformanceStats get_buffer_performance_stats(void);

//==============================================================================
// Configuration
//==============================================================================

typedef struct {
    uint32_t max_concurrent_readers;     // Maximum simultaneous readers
    uint32_t swap_timeout_ms;            // Maximum time to wait for swap
    uint32_t component_buffer_size;      // Default component buffer size
    uint32_t enable_dirty_tracking;      // Enable dirty component tracking
    uint32_t enable_performance_monitoring; // Enable detailed performance stats
} DoubleBufferConfig;

// Configure double buffer system
int configure_double_buffer(const DoubleBufferConfig* config);

//==============================================================================
// Component Buffer Interface
//==============================================================================

// Get component buffer for specific component type
ComponentBuffer* get_component_buffer(uint32_t component_type);

// Mark component as dirty (needs synchronization)
void mark_component_dirty(uint32_t component_type, uint32_t entity_index);

// Synchronize specific component type between buffers
int sync_component_type(uint32_t component_type);

//==============================================================================
// Debug and Diagnostics
//==============================================================================

typedef struct {
    uint32_t world_a_entities;           // Entities in world A
    uint32_t world_b_entities;           // Entities in world B
    uint32_t dirty_components;           // Number of dirty component types
    uint64_t memory_usage_bytes;         // Total memory usage
    uint32_t buffer_coherency_errors;    // Buffer synchronization errors
} BufferDiagnostics;

// Get diagnostic information about buffer state
BufferDiagnostics get_buffer_diagnostics(void);

// Validate buffer coherency (debug builds only)
int validate_buffer_coherency(void);

// Dump buffer state to log for debugging
void dump_buffer_state(void);

#endif // DOUBLE_BUFFER_ECS_H