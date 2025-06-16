#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <unistd.h>
#include <time.h>
#include <signal.h>

// Camera state structure
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

// Debug state structure
typedef struct {
    uint64_t last_error;
    uint64_t frame_counter;
    uint64_t input_events;
    uint64_t physics_updates;
    uint64_t frame_start_time;
    uint64_t last_frame_time;
    uint64_t min_frame_time;
    uint64_t max_frame_time;
    uint64_t avg_frame_time;
    uint64_t performance_violations;
} DebugState;

// Input state structure
typedef struct {
    uint32_t keys;
    uint32_t _pad1, _pad2, _pad3;
    int32_t mouse_x, mouse_y;
    int32_t mouse_delta_x, mouse_delta_y;
    uint32_t mouse_buttons;
    int16_t scroll_y;
    uint16_t _pad4;
    uint32_t screen_width, screen_height;
} InputState;

// Performance stats
typedef struct {
    uint64_t frame_start;
    uint64_t last_time;
    uint64_t min_time;
    uint64_t max_time;
    uint64_t avg_time;
    uint64_t violations;
} PerfStats;

// External functions
extern void camera_update(InputState* input, float delta_time);
extern int camera_validate_state(void);
extern void camera_reset(void);
extern void camera_get_performance_stats(PerfStats* stats);
extern void camera_get_world_position(float* x, float* z, float* height);

// External data
extern CameraState camera_state;
extern DebugState camera_debug_state;

// ANSI colors
#define COLOR_GREEN  "\x1b[32m"
#define COLOR_YELLOW "\x1b[33m"
#define COLOR_RED    "\x1b[31m"
#define COLOR_CYAN   "\x1b[36m"
#define COLOR_RESET  "\x1b[0m"

// Test control
volatile int running = 1;
int verbose = 0;
int stress_test = 0;

void signal_handler(int sig) {
    running = 0;
}

// Convert timer ticks to microseconds
double ticks_to_us(uint64_t ticks) {
    // Assume 24MHz timer (typical for ARM)
    return (double)ticks / 24.0;
}

// Print performance report
void print_performance_report() {
    PerfStats stats;
    camera_get_performance_stats(&stats);
    
    printf("\n" COLOR_CYAN "=== Performance Report ===" COLOR_RESET "\n");
    printf("Frame Counter: %llu\n", camera_debug_state.frame_counter);
    printf("Input Events:  %llu\n", camera_debug_state.input_events);
    printf("Physics Updates: %llu\n", camera_debug_state.physics_updates);
    
    if (stats.min_time > 0) {
        printf("\nFrame Timing:\n");
        printf("  Last:  %.2f μs\n", ticks_to_us(stats.last_time));
        printf("  Min:   %.2f μs\n", ticks_to_us(stats.min_time));
        printf("  Max:   %.2f μs\n", ticks_to_us(stats.max_time));
        printf("  Target: 4166.67 μs (240Hz)\n");
        
        if (stats.violations > 0) {
            printf(COLOR_YELLOW "  Violations: %llu (%.1f%%)\n" COLOR_RESET,
                   stats.violations,
                   100.0 * stats.violations / camera_debug_state.frame_counter);
        }
    }
    
    printf("\nCamera State:\n");
    printf("  Position: (%.1f, %.1f, %.1f)\n",
           camera_state.world_x, camera_state.world_z, camera_state.height);
    printf("  Velocity: (%.2f, %.2f)\n",
           camera_state.vel_x, camera_state.vel_z);
    printf("  Edge Pan: (%.2f, %.2f)\n",
           camera_state.edge_pan_x, camera_state.edge_pan_z);
    
    // Validate state
    int validation = camera_validate_state();
    if (validation == 0) {
        printf(COLOR_GREEN "  State: Valid\n" COLOR_RESET);
    } else {
        printf(COLOR_RED "  State: Invalid (error %d)\n" COLOR_RESET, validation);
    }
}

// Test smooth movement
void test_smooth_movement() {
    printf("\n" COLOR_CYAN "=== Testing Smooth Movement ===" COLOR_RESET "\n");
    
    InputState input = {0};
    input.screen_width = 800;
    input.screen_height = 600;
    
    camera_reset();
    
    // Record initial position
    float start_x = camera_state.world_x;
    float start_z = camera_state.world_z;
    
    printf("Starting at (%.1f, %.1f)\n", start_x, start_z);
    
    // Move forward smoothly
    printf("\nMoving forward...\n");
    input.keys = 0x01;  // Up arrow
    
    float positions[60];
    float velocities[60];
    
    for (int i = 0; i < 60; i++) {
        camera_update(&input, 0.016667f);
        positions[i] = camera_state.world_z;
        velocities[i] = camera_state.vel_z;
        
        if (verbose && i % 10 == 0) {
            printf("  Frame %2d: Z=%.2f, Vz=%.2f\n", i, positions[i], velocities[i]);
        }
    }
    
    // Check for smooth acceleration
    int smooth = 1;
    for (int i = 1; i < 30; i++) {
        float accel = velocities[i] - velocities[i-1];
        if (fabs(accel) > 5.0f) {
            smooth = 0;
            printf(COLOR_YELLOW "  Warning: Large acceleration spike at frame %d: %.2f\n" COLOR_RESET,
                   i, accel);
        }
    }
    
    if (smooth) {
        printf(COLOR_GREEN "✓ Smooth acceleration achieved\n" COLOR_RESET);
    } else {
        printf(COLOR_RED "✗ Acceleration not smooth\n" COLOR_RESET);
    }
    
    // Stop and check deceleration
    printf("\nStopping...\n");
    input.keys = 0;
    
    for (int i = 0; i < 60; i++) {
        camera_update(&input, 0.016667f);
        velocities[i] = camera_state.vel_z;
        
        if (verbose && i % 10 == 0) {
            printf("  Frame %2d: Vz=%.2f\n", i, velocities[i]);
        }
    }
    
    if (fabs(camera_state.vel_z) < 0.1f) {
        printf(COLOR_GREEN "✓ Smooth deceleration to stop\n" COLOR_RESET);
    } else {
        printf(COLOR_RED "✗ Still moving: Vz=%.2f\n" COLOR_RESET, camera_state.vel_z);
    }
}

// Test edge panning with hysteresis
void test_edge_panning() {
    printf("\n" COLOR_CYAN "=== Testing Edge Panning ===" COLOR_RESET "\n");
    
    InputState input = {0};
    input.screen_width = 800;
    input.screen_height = 600;
    
    camera_reset();
    
    // Test left edge
    printf("\nTesting left edge...\n");
    input.mouse_x = 10;  // Within threshold
    input.mouse_y = 300;
    
    float initial_x = camera_state.world_x;
    
    for (int i = 0; i < 30; i++) {
        camera_update(&input, 0.016667f);
    }
    
    if (camera_state.world_x < initial_x) {
        printf(COLOR_GREEN "✓ Left edge panning works\n" COLOR_RESET);
        printf("  Moved %.1f units\n", initial_x - camera_state.world_x);
    } else {
        printf(COLOR_RED "✗ Left edge panning failed\n" COLOR_RESET);
    }
    
    // Test hysteresis
    printf("\nTesting hysteresis...\n");
    input.mouse_x = 22;  // Just outside threshold
    
    float edge_vel = camera_state.edge_pan_x;
    for (int i = 0; i < 10; i++) {
        camera_update(&input, 0.016667f);
    }
    
    if (fabs(camera_state.edge_pan_x) < fabs(edge_vel)) {
        printf(COLOR_GREEN "✓ Edge hysteresis prevents flicker\n" COLOR_RESET);
    } else {
        printf(COLOR_YELLOW "⚠ Edge hysteresis may not be working\n" COLOR_RESET);
    }
    
    // Move away from edge
    input.mouse_x = 400;
    for (int i = 0; i < 30; i++) {
        camera_update(&input, 0.016667f);
    }
    
    if (fabs(camera_state.edge_pan_x) < 0.1f) {
        printf(COLOR_GREEN "✓ Edge panning stops when leaving edge\n" COLOR_RESET);
    }
}

// Test zoom with smoothing
void test_zoom_smoothing() {
    printf("\n" COLOR_CYAN "=== Testing Zoom Smoothing ===" COLOR_RESET "\n");
    
    InputState input = {0};
    input.screen_width = 800;
    input.screen_height = 600;
    
    camera_reset();
    
    float initial_height = camera_state.height;
    printf("Initial height: %.1f\n", initial_height);
    
    // Quick scroll input
    printf("\nApplying zoom impulse...\n");
    input.scroll_y = -20;
    camera_update(&input, 0.016667f);
    
    // Clear scroll and watch smoothing
    input.scroll_y = 0;
    
    float heights[30];
    for (int i = 0; i < 30; i++) {
        camera_update(&input, 0.016667f);
        heights[i] = camera_state.height;
    }
    
    // Check for smooth transition
    int smooth = 1;
    for (int i = 1; i < 30; i++) {
        float delta = fabs(heights[i] - heights[i-1]);
        if (delta > 0.01f && i > 5) {  // Still changing after initial frames
            smooth = 0;
        }
    }
    
    if (smooth) {
        printf(COLOR_GREEN "✓ Zoom smoothing works\n" COLOR_RESET);
    } else {
        printf(COLOR_YELLOW "⚠ Zoom may need more smoothing\n" COLOR_RESET);
    }
    
    // Test zoom limits
    printf("\nTesting zoom limits...\n");
    input.scroll_y = -100;
    for (int i = 0; i < 50; i++) {
        camera_update(&input, 0.016667f);
    }
    
    if (camera_state.height >= 5.0f) {
        printf(COLOR_GREEN "✓ Min zoom limit enforced: %.1f\n" COLOR_RESET, camera_state.height);
    } else {
        printf(COLOR_RED "✗ Min zoom limit violated: %.1f\n" COLOR_RESET, camera_state.height);
    }
    
    // Check bounce
    if (camera_state.bounce_timer > 0) {
        printf(COLOR_GREEN "✓ Elastic bounce triggered\n" COLOR_RESET);
    }
}

// Stress test
void run_stress_test() {
    printf("\n" COLOR_CYAN "=== Running Stress Test ===" COLOR_RESET "\n");
    
    InputState input = {0};
    input.screen_width = 800;
    input.screen_height = 600;
    
    camera_reset();
    
    int iterations = 10000;
    clock_t start = clock();
    
    // Random inputs
    for (int i = 0; i < iterations && running; i++) {
        // Random keys
        input.keys = rand() & 0x1F;
        
        // Random mouse position
        input.mouse_x = rand() % 800;
        input.mouse_y = rand() % 600;
        
        // Random mouse delta
        input.mouse_delta_x = (rand() % 100) - 50;
        input.mouse_delta_y = (rand() % 100) - 50;
        
        // Random scroll
        input.scroll_y = (rand() % 40) - 20;
        
        // Random mouse buttons
        input.mouse_buttons = rand() & 0x7;
        
        camera_update(&input, 0.016667f);
        
        // Validate state periodically
        if (i % 1000 == 0) {
            int valid = camera_validate_state();
            if (valid != 0) {
                printf(COLOR_RED "State validation failed at iteration %d: error %d\n" COLOR_RESET,
                       i, valid);
                break;
            }
            
            if (verbose) {
                printf("  %d iterations completed...\n", i);
            }
        }
    }
    
    clock_t end = clock();
    double elapsed = ((double)(end - start)) / CLOCKS_PER_SEC;
    
    printf("\nStress test completed:\n");
    printf("  Iterations: %d\n", iterations);
    printf("  Time: %.2f seconds\n", elapsed);
    printf("  Rate: %.0f updates/sec\n", iterations / elapsed);
    
    // Final validation
    int valid = camera_validate_state();
    if (valid == 0) {
        printf(COLOR_GREEN "✓ Camera state remained valid\n" COLOR_RESET);
    } else {
        printf(COLOR_RED "✗ Camera state corrupted: error %d\n" COLOR_RESET, valid);
    }
}

// Interactive test mode
void run_interactive_test() {
    printf("\n" COLOR_CYAN "=== Interactive Test Mode ===" COLOR_RESET "\n");
    printf("Controls:\n");
    printf("  Arrow Keys: Move camera\n");
    printf("  Shift: Speed boost\n");
    printf("  Mouse Drag: Pan\n");
    printf("  Scroll: Zoom\n");
    printf("  R: Reset camera\n");
    printf("  P: Performance report\n");
    printf("  V: Toggle verbose\n");
    printf("  Q: Quit\n\n");
    
    InputState input = {0};
    input.screen_width = 800;
    input.screen_height = 600;
    
    camera_reset();
    
    // Simulate interactive session
    const struct {
        const char* action;
        uint32_t keys;
        int16_t scroll;
        int mouse_drag;
        int duration;
    } script[] = {
        {"Moving forward", 0x01, 0, 0, 30},
        {"Turning right", 0x08, 0, 0, 20},
        {"Diagonal movement", 0x09, 0, 0, 25},
        {"Speed boost", 0x11, 0, 0, 20},
        {"Zooming in", 0, -10, 0, 15},
        {"Mouse pan", 0, 0, 1, 20},
        {"Edge pan test", 0, 0, 0, 30},
        {NULL, 0, 0, 0, 0}
    };
    
    for (int s = 0; script[s].action && running; s++) {
        printf("\n%s...\n", script[s].action);
        
        input.keys = script[s].keys;
        input.scroll_y = script[s].scroll;
        
        if (script[s].mouse_drag) {
            input.mouse_buttons = 1;
            input.mouse_delta_x = 5;
            input.mouse_delta_y = -3;
        } else {
            input.mouse_buttons = 0;
            input.mouse_delta_x = 0;
            input.mouse_delta_y = 0;
        }
        
        // Special case for edge pan
        if (strcmp(script[s].action, "Edge pan test") == 0) {
            input.mouse_x = 5;
            input.mouse_y = 300;
        }
        
        for (int i = 0; i < script[s].duration && running; i++) {
            camera_update(&input, 0.016667f);
            
            if (verbose && i % 10 == 0) {
                printf("  Pos: (%.1f, %.1f, %.1f) Vel: (%.2f, %.2f)\n",
                       camera_state.world_x, camera_state.world_z, camera_state.height,
                       camera_state.vel_x, camera_state.vel_z);
            }
        }
        
        // Brief pause between actions
        usleep(100000);  // 100ms
    }
}

int main(int argc, char* argv[]) {
    // Parse arguments
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-v") == 0) {
            verbose = 1;
        } else if (strcmp(argv[i], "-s") == 0) {
            stress_test = 1;
        } else if (strcmp(argv[i], "-h") == 0) {
            printf("Usage: %s [-v] [-s]\n", argv[0]);
            printf("  -v  Verbose output\n");
            printf("  -s  Run stress test\n");
            return 0;
        }
    }
    
    // Setup signal handler
    signal(SIGINT, signal_handler);
    
    printf("====================================\n");
    printf("   Camera Debug Test Suite\n");
    printf("====================================\n");
    
    // Initialize
    srand(time(NULL));
    camera_reset();
    
    // Run tests
    if (!stress_test) {
        test_smooth_movement();
        test_edge_panning();
        test_zoom_smoothing();
        run_interactive_test();
    } else {
        run_stress_test();
    }
    
    // Final report
    print_performance_report();
    
    printf("\n====================================\n");
    printf("         Test Complete\n");
    printf("====================================\n");
    
    return 0;
}