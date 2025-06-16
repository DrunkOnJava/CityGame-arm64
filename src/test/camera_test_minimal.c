#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <unistd.h>
#include <time.h>

// Camera state structure (matches assembly)
typedef struct {
    float iso_x, iso_y;
    float world_x, world_z;
    float height;
    float rotation;
    float vel_x, vel_z;
    float zoom_vel;
    float rot_vel;
    float edge_pan_x, edge_pan_z;
    uint32_t bounce_timer;
    uint32_t _padding[3];
} CameraState;

// Input state structure
typedef struct {
    uint32_t keys;
    uint32_t _pad1, _pad2, _pad3;
    int32_t mouse_x, mouse_y;
    int32_t mouse_delta_x, mouse_delta_y;
    uint32_t mouse_buttons;
    int16_t scroll_y;
    uint16_t _pad4;
} InputState;

// External camera functions
extern void camera_update(InputState* input, float delta_time);
extern CameraState camera_state;

// ANSI colors
#define COLOR_GREEN "\x1b[32m"
#define COLOR_RED   "\x1b[31m"
#define COLOR_RESET "\x1b[0m"

// Test camera movement
void test_keyboard_movement() {
    printf("\n=== Testing Keyboard Movement ===\n");
    
    InputState input = {0};
    
    // Save initial position
    float initial_x = camera_state.world_x;
    float initial_z = camera_state.world_z;
    
    printf("Initial position: (%.1f, %.1f)\n", initial_x, initial_z);
    
    // Test Up arrow (forward)
    printf("\nTesting Up arrow (forward)...\n");
    input.keys = 0x01;  // Up arrow
    for (int i = 0; i < 30; i++) {
        camera_update(&input, 0.016667f);
    }
    
    printf("After Up: Position (%.1f, %.1f), Velocity (%.2f, %.2f)\n",
           camera_state.world_x, camera_state.world_z,
           camera_state.vel_x, camera_state.vel_z);
    
    if (camera_state.world_z > initial_z) {
        printf(COLOR_GREEN "✓ Forward movement works\n" COLOR_RESET);
    } else {
        printf(COLOR_RED "✗ Forward movement failed\n" COLOR_RESET);
    }
    
    // Let it come to rest
    input.keys = 0;
    for (int i = 0; i < 60; i++) {
        camera_update(&input, 0.016667f);
    }
    
    // Test Left arrow
    printf("\nTesting Left arrow...\n");
    initial_x = camera_state.world_x;
    input.keys = 0x04;  // Left arrow
    for (int i = 0; i < 30; i++) {
        camera_update(&input, 0.016667f);
    }
    
    printf("After Left: Position (%.1f, %.1f), Velocity (%.2f, %.2f)\n",
           camera_state.world_x, camera_state.world_z,
           camera_state.vel_x, camera_state.vel_z);
    
    if (camera_state.world_x < initial_x) {
        printf(COLOR_GREEN "✓ Left movement works\n" COLOR_RESET);
    } else {
        printf(COLOR_RED "✗ Left movement failed\n" COLOR_RESET);
    }
    
    // Test combined movement
    printf("\nTesting diagonal movement (Up + Right)...\n");
    input.keys = 0x09;  // Up + Right
    initial_x = camera_state.world_x;
    initial_z = camera_state.world_z;
    
    for (int i = 0; i < 30; i++) {
        camera_update(&input, 0.016667f);
    }
    
    printf("After diagonal: Position (%.1f, %.1f)\n",
           camera_state.world_x, camera_state.world_z);
    
    if (camera_state.world_x > initial_x && camera_state.world_z > initial_z) {
        printf(COLOR_GREEN "✓ Diagonal movement works\n" COLOR_RESET);
    } else {
        printf(COLOR_RED "✗ Diagonal movement failed\n" COLOR_RESET);
    }
}

// Test zoom functionality
void test_zoom() {
    printf("\n=== Testing Zoom ===\n");
    
    InputState input = {0};
    float initial_height = camera_state.height;
    
    printf("Initial height: %.1f\n", initial_height);
    
    // Test zoom in
    input.scroll_y = -10;
    camera_update(&input, 0.016667f);
    
    printf("After zoom in: Height %.1f\n", camera_state.height);
    
    if (camera_state.height < initial_height) {
        printf(COLOR_GREEN "✓ Zoom in works\n" COLOR_RESET);
    } else {
        printf(COLOR_RED "✗ Zoom in failed\n" COLOR_RESET);
    }
    
    // Test zoom out
    input.scroll_y = 10;
    camera_update(&input, 0.016667f);
    camera_update(&input, 0.016667f);
    
    printf("After zoom out: Height %.1f\n", camera_state.height);
    
    if (camera_state.height > initial_height) {
        printf(COLOR_GREEN "✓ Zoom out works\n" COLOR_RESET);
    } else {
        printf(COLOR_RED "✗ Zoom out failed\n" COLOR_RESET);
    }
    
    // Test zoom limits
    input.scroll_y = -100;
    for (int i = 0; i < 20; i++) {
        camera_update(&input, 0.016667f);
    }
    
    printf("Min zoom test: Height %.1f (should be >= 5.0)\n", camera_state.height);
    
    if (camera_state.height >= 5.0f) {
        printf(COLOR_GREEN "✓ Min zoom limit works\n" COLOR_RESET);
    } else {
        printf(COLOR_RED "✗ Min zoom limit failed\n" COLOR_RESET);
    }
}

// Test mouse panning
void test_mouse_pan() {
    printf("\n=== Testing Mouse Pan ===\n");
    
    InputState input = {0};
    float initial_x = camera_state.world_x;
    float initial_z = camera_state.world_z;
    
    printf("Initial position: (%.1f, %.1f)\n", initial_x, initial_z);
    
    // Simulate mouse drag
    input.mouse_buttons = 1;  // Left button
    input.mouse_delta_x = 50;
    input.mouse_delta_y = -30;
    
    camera_update(&input, 0.016667f);
    
    printf("After mouse pan: Position (%.1f, %.1f)\n",
           camera_state.world_x, camera_state.world_z);
    
    if (camera_state.world_x != initial_x || camera_state.world_z != initial_z) {
        printf(COLOR_GREEN "✓ Mouse pan works\n" COLOR_RESET);
    } else {
        printf(COLOR_RED "✗ Mouse pan failed\n" COLOR_RESET);
    }
}

// Performance test
void test_performance() {
    printf("\n=== Testing Performance ===\n");
    
    InputState input = {0};
    const int iterations = 10000;
    
    // Time the updates
    clock_t start = clock();
    
    for (int i = 0; i < iterations; i++) {
        input.keys = (i % 16);  // Cycle through different inputs
        camera_update(&input, 0.016667f);
    }
    
    clock_t end = clock();
    double elapsed = ((double)(end - start)) / CLOCKS_PER_SEC * 1000.0;
    double per_frame = elapsed / iterations;
    
    printf("Processed %d frames in %.2fms\n", iterations, elapsed);
    printf("Average time per frame: %.3fms\n", per_frame);
    
    if (per_frame < 1.0) {
        printf(COLOR_GREEN "✓ Performance target met (<1ms)\n" COLOR_RESET);
    } else {
        printf(COLOR_RED "✗ Performance target missed (%.3fms > 1ms)\n" COLOR_RESET, per_frame);
    }
}

int main() {
    printf("====================================\n");
    printf("   Camera Controller Test Suite\n");
    printf("====================================\n");
    
    // Initialize camera to known state
    camera_state.world_x = 50.0f;
    camera_state.world_z = 50.0f;
    camera_state.height = 100.0f;
    camera_state.vel_x = 0.0f;
    camera_state.vel_z = 0.0f;
    
    // Run tests
    test_keyboard_movement();
    test_zoom();
    test_mouse_pan();
    test_performance();
    
    printf("\n====================================\n");
    printf("         Test Complete\n");
    printf("====================================\n");
    
    return 0;
}