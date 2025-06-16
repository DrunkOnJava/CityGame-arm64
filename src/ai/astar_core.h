/*
 * SimCity ARM64 Assembly - A* Pathfinding Core Interface
 * Agent C1: AI Systems Architect
 * 
 * C header interface for ARM64 assembly A* pathfinding implementation
 * Provides type-safe wrappers and documentation for assembly functions
 */

#ifndef ASTAR_CORE_H
#define ASTAR_CORE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

//==============================================================================
// Constants and Configuration
//==============================================================================

// Maximum supported nodes and path lengths
#define ASTAR_MAX_NODES           1048576    // 1M nodes maximum
#define ASTAR_MAX_PATH_LENGTH     8192       // 8K nodes max path
#define ASTAR_DEFAULT_GRID_SIZE   1024       // Default grid dimensions

// Return codes
#define ASTAR_SUCCESS             1          // Operation successful
#define ASTAR_FAILURE             0          // Operation failed
#define ASTAR_NO_PATH_FOUND       -1         // No path exists
#define ASTAR_INVALID_PARAMETERS  -2         // Invalid input parameters
#define ASTAR_ITERATION_LIMIT     -3         // Exceeded iteration limit
#define ASTAR_OUT_OF_MEMORY       -4         // Memory allocation failed

// Node states
#define ASTAR_NODE_UNVISITED      0          // Node not yet processed
#define ASTAR_NODE_OPEN           1          // Node in open set
#define ASTAR_NODE_CLOSED         2          // Node in closed set
#define ASTAR_NODE_BLOCKED        3          // Node blocked/impassable

// Cost ranges
#define ASTAR_COST_MIN            0          // Minimum cost value
#define ASTAR_COST_MAX            255        // Maximum cost value (blocked)
#define ASTAR_COST_DEFAULT        10         // Default movement cost

//==============================================================================
// Type Definitions
//==============================================================================

// Node ID type (32-bit for large grids)
typedef uint32_t astar_node_id_t;

// Coordinate types
typedef uint16_t astar_coord_t;

// Cost types
typedef uint8_t astar_cost_t;

// Statistics structure for performance monitoring
typedef struct {
    uint64_t total_searches;         // Total pathfinding requests
    uint64_t successful_searches;    // Successful pathfinds
    uint64_t total_cycles;           // Total CPU cycles consumed
    uint64_t max_iterations;         // Maximum iterations in single search
    uint64_t cache_hits;             // Memory cache hits
    uint64_t cache_misses;           // Memory cache misses
} astar_statistics_t;

// Node coordinate structure
typedef struct {
    astar_coord_t x;                 // X coordinate
    astar_coord_t y;                 // Y coordinate
} astar_coordinate_t;

// Path result structure
typedef struct {
    astar_node_id_t* nodes;          // Array of node IDs in path
    uint32_t length;                 // Number of nodes in path
    uint32_t total_cost;             // Total cost of path
} astar_path_t;

//==============================================================================
// Core A* Functions
//==============================================================================

/**
 * Initialize the A* pathfinding system
 * 
 * @param max_nodes Maximum number of nodes in the graph
 * @param max_path_length Maximum length of paths to find
 * @return ASTAR_SUCCESS on success, ASTAR_FAILURE on failure
 */
int astar_init(uint32_t max_nodes, uint32_t max_path_length);

/**
 * Find optimal path between two nodes using A* algorithm
 * 
 * @param start_node_id Starting node ID
 * @param goal_node_id Goal node ID  
 * @param use_traffic_cost Whether to use dynamic traffic costs
 * @return Path length on success, negative error code on failure
 */
int astar_find_path(astar_node_id_t start_node_id, 
                    astar_node_id_t goal_node_id, 
                    int use_traffic_cost);

/**
 * Clean up A* system and free all allocated resources
 */
void astar_cleanup(void);

/**
 * Set dynamic cost modifiers for a node
 * 
 * @param node_id Node to modify
 * @param traffic_cost Traffic congestion cost (0-255)
 * @param terrain_cost Terrain difficulty cost (0-255)
 * @return ASTAR_SUCCESS on success, ASTAR_FAILURE on failure
 */
int astar_set_dynamic_cost(astar_node_id_t node_id, 
                           astar_cost_t traffic_cost, 
                           astar_cost_t terrain_cost);

/**
 * Get length of the most recently found path
 * 
 * @return Number of nodes in path, 0 if no path found
 */
uint32_t astar_get_path_length(void);

/**
 * Get pointer to array of node IDs in the most recently found path
 * 
 * @return Pointer to path node array, NULL if no path found
 */
astar_node_id_t* astar_get_path_nodes(void);

/**
 * Get performance statistics from A* system
 * 
 * @param stats_output Pointer to statistics structure to fill
 */
void astar_get_statistics(astar_statistics_t* stats_output);

//==============================================================================
// Utility Functions
//==============================================================================

/**
 * Convert 2D coordinates to node ID
 * 
 * @param x X coordinate
 * @param y Y coordinate
 * @param grid_width Width of the grid
 * @return Node ID
 */
static inline astar_node_id_t astar_coords_to_node_id(astar_coord_t x, 
                                                      astar_coord_t y, 
                                                      uint32_t grid_width) {
    return (uint32_t)y * grid_width + (uint32_t)x;
}

/**
 * Convert node ID to 2D coordinates
 * 
 * @param node_id Node ID to convert
 * @param grid_width Width of the grid
 * @return Coordinate structure
 */
static inline astar_coordinate_t astar_node_id_to_coords(astar_node_id_t node_id, 
                                                         uint32_t grid_width) {
    astar_coordinate_t coord;
    coord.y = (astar_coord_t)(node_id / grid_width);
    coord.x = (astar_coord_t)(node_id % grid_width);
    return coord;
}

/**
 * Calculate Manhattan distance between two coordinates
 * 
 * @param coord1 First coordinate
 * @param coord2 Second coordinate
 * @return Manhattan distance
 */
static inline uint32_t astar_manhattan_distance(astar_coordinate_t coord1, 
                                                astar_coordinate_t coord2) {
    uint32_t dx = (coord1.x > coord2.x) ? (coord1.x - coord2.x) : (coord2.x - coord1.x);
    uint32_t dy = (coord1.y > coord2.y) ? (coord1.y - coord2.y) : (coord2.y - coord1.y);
    return dx + dy;
}

/**
 * Check if coordinates are within grid bounds
 * 
 * @param coord Coordinate to check
 * @param grid_width Grid width
 * @param grid_height Grid height
 * @return true if within bounds, false otherwise
 */
static inline bool astar_coords_in_bounds(astar_coordinate_t coord, 
                                          uint32_t grid_width, 
                                          uint32_t grid_height) {
    return coord.x < grid_width && coord.y < grid_height;
}

//==============================================================================
// High-Level Interface Functions
//==============================================================================

/**
 * Find path between two coordinates (convenience function)
 * 
 * @param start_x Starting X coordinate
 * @param start_y Starting Y coordinate
 * @param goal_x Goal X coordinate
 * @param goal_y Goal Y coordinate
 * @param grid_width Grid width for coordinate conversion
 * @param use_traffic_cost Whether to use dynamic costs
 * @return Path length on success, negative error code on failure
 */
int astar_find_path_coords(astar_coord_t start_x, astar_coord_t start_y,
                           astar_coord_t goal_x, astar_coord_t goal_y,
                           uint32_t grid_width, int use_traffic_cost);

/**
 * Get the most recently found path as coordinate array
 * 
 * @param coords_output Array to store coordinates (must be pre-allocated)
 * @param max_coords Maximum number of coordinates to store
 * @param grid_width Grid width for coordinate conversion
 * @return Number of coordinates stored
 */
uint32_t astar_get_path_coords(astar_coordinate_t* coords_output, 
                               uint32_t max_coords, 
                               uint32_t grid_width);

/**
 * Set traffic cost for a coordinate area
 * 
 * @param x X coordinate
 * @param y Y coordinate
 * @param width Area width
 * @param height Area height
 * @param grid_width Grid width
 * @param traffic_cost Traffic cost to set
 * @return Number of nodes updated
 */
uint32_t astar_set_area_traffic_cost(astar_coord_t x, astar_coord_t y,
                                     uint32_t width, uint32_t height,
                                     uint32_t grid_width,
                                     astar_cost_t traffic_cost);

//==============================================================================
// Testing and Benchmarking Functions
//==============================================================================

/**
 * Run A* pathfinding benchmark
 * 
 * @param num_iterations Number of pathfinding operations to perform
 * @param start_node Starting node ID
 * @param goal_node Goal node ID
 * @return Average CPU cycles per pathfinding operation
 */
uint64_t astar_benchmark(uint64_t num_iterations, 
                         astar_node_id_t start_node, 
                         astar_node_id_t goal_node);

/**
 * Validate A* implementation with comprehensive tests
 * 
 * @return Number of tests passed
 */
int astar_run_validation_tests(void);

//==============================================================================
// Configuration Functions
//==============================================================================

/**
 * Set heuristic scaling factor for A* algorithm
 * 
 * @param scale_factor Scaling factor (typically 10-20)
 */
void astar_set_heuristic_scale(uint32_t scale_factor);

/**
 * Enable or disable diagonal movement
 * 
 * @param allow_diagonal true to allow diagonal movement, false for 4-connected
 */
void astar_set_diagonal_movement(bool allow_diagonal);

/**
 * Set maximum iterations before pathfinding gives up
 * 
 * @param max_iterations Maximum iterations (0 for no limit)
 */
void astar_set_iteration_limit(uint32_t max_iterations);

//==============================================================================
// Memory Management Integration
//==============================================================================

/**
 * Get current memory usage of A* system
 * 
 * @return Memory usage in bytes
 */
uint64_t astar_get_memory_usage(void);

/**
 * Get peak memory usage since initialization
 * 
 * @return Peak memory usage in bytes
 */
uint64_t astar_get_peak_memory_usage(void);

/**
 * Force garbage collection of unused pathfinding data
 */
void astar_garbage_collect(void);

//==============================================================================
// Debug and Profiling Functions
//==============================================================================

/**
 * Enable or disable debug tracing
 * 
 * @param enable true to enable debug output
 */
void astar_set_debug_mode(bool enable);

/**
 * Get detailed timing breakdown of last pathfinding operation
 * 
 * @param init_time_ns Time spent in initialization (nanoseconds)
 * @param search_time_ns Time spent in main search loop (nanoseconds)
 * @param reconstruct_time_ns Time spent reconstructing path (nanoseconds)
 */
void astar_get_timing_breakdown(uint64_t* init_time_ns,
                                uint64_t* search_time_ns,
                                uint64_t* reconstruct_time_ns);

/**
 * Export current open and closed sets for visualization
 * 
 * @param open_nodes Output array for open set nodes
 * @param open_count Maximum nodes to store in open_nodes
 * @param closed_nodes Output array for closed set nodes  
 * @param closed_count Maximum nodes to store in closed_nodes
 * @return Number of nodes actually stored in each array (packed as (open << 16) | closed)
 */
uint32_t astar_export_search_state(astar_node_id_t* open_nodes, uint32_t open_count,
                                   astar_node_id_t* closed_nodes, uint32_t closed_count);

//==============================================================================
// Version and Compatibility
//==============================================================================

// Version information
#define ASTAR_VERSION_MAJOR       1
#define ASTAR_VERSION_MINOR       0
#define ASTAR_VERSION_PATCH       0
#define ASTAR_VERSION_STRING      "1.0.0"

/**
 * Get A* implementation version
 * 
 * @return Version as packed integer (major << 16 | minor << 8 | patch)
 */
uint32_t astar_get_version(void);

/**
 * Check if A* system supports a specific feature
 * 
 * @param feature_name Feature name string
 * @return true if supported, false otherwise
 */
bool astar_supports_feature(const char* feature_name);

#ifdef __cplusplus
}
#endif

#endif // ASTAR_CORE_H