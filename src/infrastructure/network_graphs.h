// SimCity ARM64 Infrastructure Network Graph Algorithms
// Agent D2: Infrastructure Team - Network Graph Algorithm Interface
// Header file for coordination with other agents (D1 memory, A3 utilities)

#ifndef NETWORK_GRAPHS_H
#define NETWORK_GRAPHS_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

//==============================================================================
// NETWORK GRAPH TYPES AND CONSTANTS
//==============================================================================

// Network node types for infrastructure systems
typedef enum {
    NODE_TYPE_NONE      = 0,
    NODE_TYPE_POWER     = 1,    // Power grid node (wire junction, transformer)
    NODE_TYPE_WATER     = 2,    // Water network node (pipe junction, valve)
    NODE_TYPE_JUNCTION  = 3,    // Multi-utility junction
    NODE_TYPE_SOURCE    = 4,    // Utility source (power plant, water tower)
    NODE_TYPE_SINK      = 5     // Utility consumer (building, facility)
} NetworkNodeType;

// Edge types for different utility connections
typedef enum {
    EDGE_TYPE_NONE      = 0,
    EDGE_TYPE_WIRE      = 1,    // Electrical connection
    EDGE_TYPE_PIPE      = 2,    // Water/sewage connection
    EDGE_TYPE_JUNCTION  = 3     // Multi-utility connection
} NetworkEdgeType;

// Network failure types
typedef enum {
    FAILURE_TYPE_NONE           = 0,
    FAILURE_TYPE_NODE_FAILURE   = 1,    // Node completely fails
    FAILURE_TYPE_EDGE_FAILURE   = 2,    // Connection breaks
    FAILURE_TYPE_CAPACITY_OVERLOAD = 3, // Overloaded beyond capacity
    FAILURE_TYPE_MAINTENANCE    = 4     // Scheduled maintenance downtime
} NetworkFailureType;

// Optimization levels for capacity planning
typedef enum {
    OPTIMIZATION_BASIC      = 1,    // Basic capacity adjustments
    OPTIMIZATION_ADVANCED   = 2,    // Advanced flow balancing with NEON
    OPTIMIZATION_COMPLETE   = 3     // Complete network restructuring
} OptimizationLevel;

//==============================================================================
// NETWORK GRAPH STRUCTURES
//==============================================================================

// Network node structure (cache-aligned to 128 bytes)
typedef struct {
    uint32_t id;                    // Unique node identifier
    NetworkNodeType type;           // Node type (power/water/junction)
    uint32_t x, y;                  // Grid coordinates
    uint32_t capacity;              // Maximum flow capacity
    uint32_t current_flow;          // Current flow through node
    uint32_t source_id;             // Source building/utility ID
    float efficiency;               // Node efficiency (0.0-1.0)
    bool operational;               // Is node currently operational
    uint32_t edge_count;            // Number of outgoing edges
    uint32_t edges[24];             // Connected edge indices
    uint8_t padding[4];             // Padding to 128 bytes
} NetworkNode;

// Network edge structure (32 bytes)
typedef struct {
    uint32_t id;                    // Unique edge identifier
    NetworkEdgeType type;           // Edge type (wire/pipe/junction)
    uint32_t from_node;             // Source node ID
    uint32_t to_node;               // Destination node ID
    uint32_t capacity;              // Maximum flow capacity
    uint32_t current_flow;          // Current flow through edge
    float resistance;               // Flow resistance (0.0-1.0)
    bool operational;               // Is edge currently operational
} NetworkEdge;

// Path result structure for shortest path queries
typedef struct {
    uint32_t length;                // Path length (number of hops)
    uint32_t cost;                  // Total path cost
    uint32_t* nodes;                // Array of node IDs in path
    float efficiency;               // Overall path efficiency
} NetworkPath;

// Flow result structure for max flow calculations
typedef struct {
    uint32_t max_flow;              // Maximum flow value
    uint32_t path_count;            // Number of flow paths
    NetworkPath* paths;             // Array of flow paths
    float network_utilization;      // Overall network utilization
} FlowResult;

// Network statistics for monitoring and optimization
typedef struct {
    uint32_t total_nodes;           // Total number of nodes
    uint32_t active_nodes;          // Number of operational nodes
    uint32_t total_edges;           // Total number of edges
    uint32_t active_edges;          // Number of operational edges
    uint32_t total_capacity;        // Sum of all capacities
    uint32_t current_utilization;   // Current total utilization
    float average_efficiency;       // Average network efficiency
    uint32_t bottleneck_count;      // Number of bottlenecks detected
    uint32_t failure_count;         // Number of failed components
} NetworkStatistics;

//==============================================================================
// CORE GRAPH ALGORITHM API
//==============================================================================

/**
 * Initialize the infrastructure network graph system
 * Coordinates with Agent D1 for memory allocation
 * 
 * @param grid_width Width of the city grid
 * @param grid_height Height of the city grid  
 * @param max_utilities Maximum number of utility buildings
 * @return 0 on success, negative on error
 */
int network_graph_init(uint32_t grid_width, uint32_t grid_height, uint32_t max_utilities);

/**
 * Shutdown and cleanup network graph system
 */
void network_graph_shutdown(void);

/**
 * Compute shortest path between two points in utility network
 * Uses Dijkstra's algorithm optimized with NEON SIMD
 * 
 * @param from_x Source X coordinate
 * @param from_y Source Y coordinate
 * @param to_x Destination X coordinate
 * @param to_y Destination Y coordinate
 * @param network_type Type of network (power/water)
 * @return Path length, 0 if no path exists
 */
uint32_t network_get_shortest_path(uint32_t from_x, uint32_t from_y, 
                                   uint32_t to_x, uint32_t to_y,
                                   NetworkNodeType network_type);

/**
 * Compute maximum flow in utility network
 * Uses Ford-Fulkerson algorithm with NEON optimization
 * 
 * @param source_count Number of source nodes
 * @param sources Array of source node IDs
 * @param sink_count Number of sink nodes
 * @param sinks Array of sink node IDs
 * @param network_type Type of network (power/water)
 * @return Maximum flow value
 */
uint32_t network_compute_flow(uint32_t source_count, const uint32_t* sources,
                              uint32_t sink_count, const uint32_t* sinks,
                              NetworkNodeType network_type);

/**
 * Optimize network capacity for improved efficiency
 * 
 * @param network_type Type of network to optimize
 * @param optimization_level Level of optimization (1-3)
 * @param[out] efficiency_improvement Efficiency improvement achieved
 * @param[out] capacity_changes Number of capacity changes made
 * @return 0 on success, negative on error
 */
int network_optimize_capacity(NetworkNodeType network_type, 
                              OptimizationLevel optimization_level,
                              float* efficiency_improvement,
                              uint32_t* capacity_changes);

/**
 * Handle network failures and attempt rerouting
 * 
 * @param failed_node_id ID of failed node
 * @param failure_type Type of failure
 * @param network_type Network type affected
 * @param[out] affected_nodes Number of nodes affected
 * @return true if rerouting successful, false otherwise
 */
bool network_handle_failure(uint32_t failed_node_id, 
                            NetworkFailureType failure_type,
                            NetworkNodeType network_type,
                            uint32_t* affected_nodes);

/**
 * Propagate utilities through network using NEON optimization
 * High-performance propagation for 1M+ agents
 * 
 * @param network_type Type of network (power/water)
 * @param source_nodes Array of source node IDs
 * @param source_count Number of source nodes
 * @return Number of nodes reached by propagation
 */
uint32_t network_propagate_utilities(NetworkNodeType network_type,
                                     const uint32_t* source_nodes,
                                     uint32_t source_count);

//==============================================================================
// NETWORK MANAGEMENT API
//==============================================================================

/**
 * Add a network node at specified coordinates
 * 
 * @param x Grid X coordinate
 * @param y Grid Y coordinate
 * @param type Node type
 * @param capacity Node capacity
 * @return Node ID on success, UINT32_MAX on error
 */
uint32_t network_add_node(uint32_t x, uint32_t y, 
                          NetworkNodeType type, uint32_t capacity);

/**
 * Remove a network node
 * 
 * @param node_id ID of node to remove
 * @return true on success, false on error
 */
bool network_remove_node(uint32_t node_id);

/**
 * Add an edge between two nodes
 * 
 * @param from_node Source node ID
 * @param to_node Destination node ID
 * @param type Edge type
 * @param capacity Edge capacity
 * @return Edge ID on success, UINT32_MAX on error
 */
uint32_t network_add_edge(uint32_t from_node, uint32_t to_node,
                          NetworkEdgeType type, uint32_t capacity);

/**
 * Remove an edge from the network
 * 
 * @param edge_id ID of edge to remove
 * @return true on success, false on error
 */
bool network_remove_edge(uint32_t edge_id);

/**
 * Update node capacity
 * 
 * @param node_id Node to update
 * @param new_capacity New capacity value
 * @return true on success, false on error
 */
bool network_update_node_capacity(uint32_t node_id, uint32_t new_capacity);

/**
 * Update edge capacity
 * 
 * @param edge_id Edge to update
 * @param new_capacity New capacity value
 * @return true on success, false on error
 */
bool network_update_edge_capacity(uint32_t edge_id, uint32_t new_capacity);

//==============================================================================
// STATISTICS AND MONITORING API
//==============================================================================

/**
 * Get current network statistics
 * 
 * @param network_type Type of network to query
 * @param[out] stats Statistics structure to fill
 * @return true on success, false on error
 */
bool network_get_statistics(NetworkNodeType network_type, NetworkStatistics* stats);

/**
 * Get detailed path information
 * 
 * @param from_node Source node ID
 * @param to_node Destination node ID
 * @param network_type Network type
 * @param[out] path Path structure to fill
 * @return true if path exists, false otherwise
 */
bool network_get_path_details(uint32_t from_node, uint32_t to_node,
                              NetworkNodeType network_type, NetworkPath* path);

/**
 * Get detailed flow information
 * 
 * @param source_nodes Array of source node IDs
 * @param source_count Number of sources
 * @param sink_nodes Array of sink node IDs
 * @param sink_count Number of sinks
 * @param network_type Network type
 * @param[out] flow_result Flow result structure to fill
 * @return true on success, false on error
 */
bool network_get_flow_details(const uint32_t* source_nodes, uint32_t source_count,
                              const uint32_t* sink_nodes, uint32_t sink_count,
                              NetworkNodeType network_type, FlowResult* flow_result);

/**
 * Detect network bottlenecks
 * 
 * @param network_type Network type to analyze
 * @param[out] bottleneck_nodes Array to store bottleneck node IDs
 * @param max_bottlenecks Maximum number of bottlenecks to return
 * @return Number of bottlenecks found
 */
uint32_t network_detect_bottlenecks(NetworkNodeType network_type,
                                    uint32_t* bottleneck_nodes,
                                    uint32_t max_bottlenecks);

//==============================================================================
// COORDINATION INTERFACE WITH OTHER AGENTS
//==============================================================================

/**
 * Interface for Agent A3 (Utilities) coordination
 * Called when utility buildings are placed/removed
 * 
 * @param building_x X coordinate of utility building
 * @param building_y Y coordinate of utility building
 * @param utility_type Type of utility (power plant, water tower, etc.)
 * @param capacity Building capacity
 * @param is_placement true for placement, false for removal
 * @return true on success, false on error
 */
bool network_notify_utility_change(uint32_t building_x, uint32_t building_y,
                                   uint32_t utility_type, uint32_t capacity,
                                   bool is_placement);

/**
 * Interface for Agent D1 (Memory) coordination
 * Request memory allocation for network expansion
 * 
 * @param additional_nodes Number of additional nodes needed
 * @param additional_edges Number of additional edges needed
 * @return true if memory available, false otherwise
 */
bool network_request_memory_expansion(uint32_t additional_nodes, 
                                      uint32_t additional_edges);

/**
 * Performance monitoring interface
 * Get algorithm performance statistics
 * 
 * @param[out] dijkstra_avg_ns Average Dijkstra time in nanoseconds
 * @param[out] flow_avg_ns Average max flow time in nanoseconds
 * @param[out] propagation_avg_ns Average propagation time in nanoseconds
 */
void network_get_performance_stats(uint64_t* dijkstra_avg_ns,
                                  uint64_t* flow_avg_ns,
                                  uint64_t* propagation_avg_ns);

//==============================================================================
// TESTING AND VALIDATION INTERFACE
//==============================================================================

/**
 * Run comprehensive network algorithm tests
 * 
 * @param[out] total_tests Total number of tests run
 * @param[out] passed_tests Number of tests passed
 * @param[out] failed_tests Number of tests failed
 * @return 0 if all tests passed, negative if any failed
 */
int network_run_tests(uint32_t* total_tests, uint32_t* passed_tests, uint32_t* failed_tests);

/**
 * Validate network integrity
 * Check for consistency, reachability, and capacity constraints
 * 
 * @param network_type Network type to validate
 * @return true if network is valid, false if issues found
 */
bool network_validate_integrity(NetworkNodeType network_type);

/**
 * Benchmark network algorithms performance
 * 
 * @param iterations Number of benchmark iterations
 * @param network_type Network type to benchmark
 * @return Average operation time in CPU cycles
 */
uint64_t network_benchmark_performance(uint32_t iterations, NetworkNodeType network_type);

#ifdef __cplusplus
}
#endif

#endif // NETWORK_GRAPHS_H