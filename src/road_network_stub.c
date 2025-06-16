// Temporary stub implementation for ARM64 road network functions
// This allows the project to compile and test the Objective-C integration
// while the ARM64 assembly is being linked

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Simple stub implementations that return basic success values
int road_network_init(int max_nodes, int max_edges) {
    printf("🔧 Stub: road_network_init(%d, %d)\n", max_nodes, max_edges);
    return 1; // Success
}

int road_network_add_node(int x_coord, int y_coord, int road_type, int capacity) {
    static int node_id_counter = 0;
    printf("🔧 Stub: road_network_add_node(%d, %d, %d, %d) -> %d\n", 
           x_coord, y_coord, road_type, capacity, node_id_counter);
    return node_id_counter++;
}

int road_network_add_edge(int from_node_id, int to_node_id, int weight, int capacity) {
    printf("🔧 Stub: road_network_add_edge(%d -> %d, weight=%d, capacity=%d)\n", 
           from_node_id, to_node_id, weight, capacity);
    return 1; // Success
}

long road_network_calculate_flow(void) {
    // Simulate some processing cycles
    return 1000; // Mock cycle count
}

long road_network_find_path(int start_node_id, int end_node_id) {
    printf("🔧 Stub: road_network_find_path(%d -> %d)\n", start_node_id, end_node_id);
    // Return mock path length
    return abs(end_node_id - start_node_id) * 10;
}

int road_network_get_congestion(int from_node_id, int to_node_id) {
    // Return random traffic level (0-4)
    return (from_node_id + to_node_id) % 5;
}

long road_network_update(int delta_time_ms) {
    // Simulate network update processing
    return 500 + (delta_time_ms % 100); // Mock processing cycles
}

int road_network_add_intersection(int x_coord, int y_coord, int intersection_type) {
    static int intersection_id_counter = 0;
    printf("🔧 Stub: road_network_add_intersection(%d, %d, type=%d) -> %d\n", 
           x_coord, y_coord, intersection_type, intersection_id_counter);
    return intersection_id_counter++;
}

int road_network_connect_intersection(int intersection_id, int road_from_id, int road_to_id) {
    printf("🔧 Stub: road_network_connect_intersection(%d, %d, %d)\n", 
           intersection_id, road_from_id, road_to_id);
    return 1; // Success
}

void road_network_get_intersection_state(int intersection_id, int *signal_phase, int *congestion_level, int *queue_total) {
    // Mock intersection state based on ID
    *signal_phase = intersection_id % 4;      // Cycle through phases
    *congestion_level = (intersection_id % 3) + 1; // 1-3 congestion
    *queue_total = (intersection_id * 7) % 20;      // 0-19 queue length
}

void road_network_cleanup(void) {
    printf("🔧 Stub: road_network_cleanup()\n");
    // Nothing to clean up in stub
}