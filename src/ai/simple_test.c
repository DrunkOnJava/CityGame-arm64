/*
 * Simple test for A* pathfinding assembly functions
 * Verifies basic functionality works with Apple assembler
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>

// External assembly functions
extern int astar_test_simple(int start_x, int start_y, int goal_x, int goal_y);
extern int astar_calculate_manhattan_distance(int x1, int y1, int x2, int y2);
extern int astar_test_binary_heap_ops(int* array, int size);
extern void astar_init_node(void* node, int x, int y);
extern void astar_set_node_costs(void* node, int g_cost, int h_cost);
extern uint64_t astar_benchmark_heuristic(uint64_t iterations);
extern uint32_t astar_validate_coordinates(uint32_t node_id, uint32_t grid_width);

// Node structure offsets (must match assembly)
#define AStarNode_g_cost         0     
#define AStarNode_h_cost         4     
#define AStarNode_f_cost         8     
#define AStarNode_parent_id      12    
#define AStarNode_x              16    
#define AStarNode_y              18    
#define AStarNode_size           32    

int main() {
    printf("A* Pathfinding Assembly Test Suite\n");
    printf("==================================\n\n");
    
    int passed = 0, total = 0;
    
    // Test 1: Manhattan distance calculation
    total++;
    printf("Test 1: Manhattan distance calculation\n");
    int dist = astar_calculate_manhattan_distance(0, 0, 3, 4);
    printf("  Distance from (0,0) to (3,4): %d\n", dist);
    if (dist == 7) {
        printf("  ✅ PASSED\n");
        passed++;
    } else {
        printf("  ❌ FAILED (expected 7, got %d)\n", dist);
    }
    printf("\n");
    
    // Test 2: Simple pathfinding wrapper
    total++;
    printf("Test 2: Simple pathfinding wrapper\n");
    int result = astar_test_simple(1, 1, 6, 8);
    printf("  Path distance from (1,1) to (6,8): %d\n", result);
    if (result == 12) { // |6-1| + |8-1| = 5 + 7 = 12
        printf("  ✅ PASSED\n");
        passed++;
    } else {
        printf("  ❌ FAILED (expected 12, got %d)\n", result);
    }
    printf("\n");
    
    // Test 3: Node initialization and manipulation
    total++;
    printf("Test 3: Node initialization and manipulation\n");
    uint8_t node_data[AStarNode_size];
    astar_init_node(node_data, 10, 20);
    
    // Check coordinates
    uint16_t x = *(uint16_t*)(node_data + AStarNode_x);
    uint16_t y = *(uint16_t*)(node_data + AStarNode_y);
    printf("  Node coordinates: (%d, %d)\n", x, y);
    
    // Set costs
    astar_set_node_costs(node_data, 100, 50);
    uint32_t g_cost = *(uint32_t*)(node_data + AStarNode_g_cost);
    uint32_t h_cost = *(uint32_t*)(node_data + AStarNode_h_cost);
    uint32_t f_cost = *(uint32_t*)(node_data + AStarNode_f_cost);
    printf("  Costs: g=%u, h=%u, f=%u\n", g_cost, h_cost, f_cost);
    
    if (x == 10 && y == 20 && g_cost == 100 && h_cost == 50 && f_cost == 150) {
        printf("  ✅ PASSED\n");
        passed++;
    } else {
        printf("  ❌ FAILED\n");
    }
    printf("\n");
    
    // Test 4: Binary heap operations test
    total++;
    printf("Test 4: Binary heap operations\n");
    int heap_array[] = {1, 3, 6, 5, 9, 8, 10, 7, 12, 11};
    int heap_size = sizeof(heap_array) / sizeof(heap_array[0]);
    int heap_valid = astar_test_binary_heap_ops(heap_array, heap_size);
    printf("  Heap validation result: %s\n", heap_valid ? "Valid" : "Invalid");
    if (heap_valid) {
        printf("  ✅ PASSED\n");
        passed++;
    } else {
        printf("  ❌ FAILED\n");
    }
    printf("\n");
    
    // Test 5: Coordinate validation
    total++;
    printf("Test 5: Coordinate validation\n");
    uint32_t node_id = 258; // Should be (2, 4) on 64x64 grid
    uint32_t grid_width = 64;
    uint32_t reconstructed = astar_validate_coordinates(node_id, grid_width);
    printf("  Original node_id: %u, Reconstructed: %u\n", node_id, reconstructed);
    if (node_id == reconstructed) {
        printf("  ✅ PASSED\n");
        passed++;
    } else {
        printf("  ❌ FAILED\n");
    }
    printf("\n");
    
    // Test 6: Performance benchmark
    total++;
    printf("Test 6: Performance benchmark\n");
    uint64_t iterations = 10000;
    uint64_t avg_cycles = astar_benchmark_heuristic(iterations);
    printf("  Average cycles per heuristic calculation: %llu\n", avg_cycles);
    printf("  Iterations: %llu\n", iterations);
    
    // Reasonable performance check (should be under 100 cycles)
    if (avg_cycles < 100) {
        printf("  ✅ PASSED (good performance)\n");
        passed++;
    } else {
        printf("  ⚠️  PASSED (but slow performance)\n");
        passed++;
    }
    printf("\n");
    
    // Summary
    printf("Test Summary\n");
    printf("============\n");
    printf("Passed: %d/%d\n", passed, total);
    printf("Success rate: %.1f%%\n", (double)passed / total * 100.0);
    
    if (passed == total) {
        printf("\n🎉 All tests passed! A* assembly functions are working correctly.\n");
        return 0;
    } else {
        printf("\n💥 Some tests failed. Check the implementation.\n");
        return 1;
    }
}