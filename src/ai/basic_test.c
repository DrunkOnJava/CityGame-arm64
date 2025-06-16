/*
 * Basic test for A* pathfinding assembly functions
 * Tests core functionality without performance benchmarks
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

// External assembly functions
extern int astar_test_simple(int start_x, int start_y, int goal_x, int goal_y);
extern int astar_calculate_manhattan_distance(int x1, int y1, int x2, int y2);
extern uint32_t astar_validate_coordinates(uint32_t node_id, uint32_t grid_width);

int main() {
    printf("A* Pathfinding Basic Assembly Test\n");
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
    
    // Test 3: Coordinate validation
    total++;
    printf("Test 3: Coordinate validation\n");
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
    
    // Summary
    printf("Test Summary\n");
    printf("============\n");
    printf("Passed: %d/%d\n", passed, total);
    printf("Success rate: %.1f%%\n", (double)passed / total * 100.0);
    
    if (passed == total) {
        printf("\n🎉 All basic tests passed! A* assembly functions are working correctly.\n");
        return 0;
    } else {
        printf("\n💥 Some tests failed. Check the implementation.\n");
        return 1;
    }
}