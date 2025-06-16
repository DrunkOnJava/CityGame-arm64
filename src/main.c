// SimCity ARM64 Main Demo Application
// Integrates all systems into a running city simulation

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <pthread.h>
#include <mach/mach_time.h>

// Core engine includes
#include "core/memory_manager.h"
#include "simulation/entity_system.h"
#include "ai/ai_integration.h"
#include "persistence/wal_save_system.h"
#include "audio/spatial_audio.h"

// TODO: Add graphics later when dependencies are resolved
// #include <GLFW/glfw3.h>
// #include <Metal/Metal.h>
// #include <MetalKit/MetalKit.h>

// Demo configuration
#define WINDOW_WIDTH 1920
#define WINDOW_HEIGHT 1080
#define TARGET_FPS 60.0f
#define MAX_FRAME_TIME (1.0f / TARGET_FPS)
#define INITIAL_CITIZEN_COUNT 800
#define INITIAL_VEHICLE_COUNT 200
#define CITY_WIDTH 100
#define CITY_HEIGHT 100
#define SIMULATION_SPEED 1.0f

// Global state
static struct {
    // Graphics removed for console demo
    // GLFWwindow* window;
    // id<MTLDevice> metal_device;
    
    // Simulation state
    bool simulation_running;
    bool simulation_paused;
    float simulation_time;
    uint64_t frame_count;
    
    // Performance tracking
    double last_time;
    double frame_times[60];
    int frame_time_index;
    float avg_frame_time;
    
    // City state
    uint32_t total_entities;
    uint32_t active_citizens;
    uint32_t active_vehicles;
    
    // Input state
    bool keys[GLFW_KEY_LAST];
    double mouse_x, mouse_y;
    bool mouse_dragging;
    
    // Camera state
    float camera_x, camera_y, camera_z;
    float camera_zoom;
    float camera_rotation;
} g_demo_state = {0};

// Forward declarations
static int init_systems(void);
static void shutdown_systems(void);
static int init_graphics(void);
static void shutdown_graphics(void);
static void generate_city_layout(void);
static void spawn_initial_population(void);
static void update_simulation(float delta_time);
static void render_frame(void);
static void handle_input(void);
static void update_performance_stats(void);
static uint64_t get_time_ns(void);
static float get_delta_time(void);

// Console demo - no callbacks needed

//==============================================================================
// MAIN ENTRY POINT
//==============================================================================

int main(int argc, char* argv[]) {
    printf("=== SimCity ARM64 Demo Starting ===\n");
    printf("Target: %d citizens, %d vehicles in %dx%d city\n", 
           INITIAL_CITIZEN_COUNT, INITIAL_VEHICLE_COUNT, CITY_WIDTH, CITY_HEIGHT);
    
    // Initialize all systems
    if (init_systems() != 0) {
        fprintf(stderr, "Failed to initialize systems\n");
        return -1;
    }
    
    // Skip graphics for now - console only demo
    printf("Running in console mode (no graphics)\n");
    
    // Generate city and spawn initial population
    generate_city_layout();
    spawn_initial_population();
    
    printf("Demo initialized successfully. Starting main loop...\n");
    
    // Initialize timing
    g_demo_state.last_time = (float)get_time_ns() / 1e9f;
    g_demo_state.simulation_running = true;
    
    // Console demo loop - run for 30 seconds
    int demo_frames = 30 * 60; // 30 seconds at 60 FPS
    for (int frame = 0; frame < demo_frames && g_demo_state.simulation_running; frame++) {
        // Calculate delta time
        float delta_time = get_delta_time();
        
        // Update simulation
        update_simulation(delta_time);
        
        // Update performance statistics every 60 frames
        if (frame % 60 == 0) {
            update_performance_stats();
            printf("Frame %d: %.1f FPS, %d active agents\n", 
                   frame, 1.0f / delta_time, g_demo_state.active_citizens + g_demo_state.active_vehicles);
        }
        
        g_demo_state.frame_count++;
        
        // Cap frame rate to 60 FPS
        usleep(16667); // ~16.67ms = 60 FPS
    }
    
    printf("Demo completed successfully!\n");
    
    // Print final stats
    ai_print_performance_stats();
    shutdown_systems();
    
    printf("=== SimCity ARM64 Demo Complete ===\n");
    printf("Final stats: %llu frames, %.2f avg FPS\n", 
           g_demo_state.frame_count, 1.0f / g_demo_state.avg_frame_time);
    
    return 0;
}

//==============================================================================
// SYSTEM INITIALIZATION
//==============================================================================

static int init_systems(void) {
    printf("Initializing core systems...\n");
    
    // Initialize memory manager first
    if (memory_manager_init() != 0) {
        printf("Failed to initialize memory manager\n");
        return -1;
    }
    
    // Initialize entity system
    if (entity_system_init() != 0) {
        printf("Failed to initialize entity system\n");
        return -1;
    }
    
    // Initialize AI system with simple test world
    uint8_t test_world[CITY_WIDTH * CITY_HEIGHT];
    memset(test_world, 1, sizeof(test_world)); // All walkable for now
    
    if (ai_system_init(test_world, CITY_WIDTH, CITY_HEIGHT) != 0) {
        printf("Failed to initialize AI system\n");
        return -1;
    }
    
    // Initialize save system
    if (wal_system_init("./saves") != 0) {
        printf("Warning: Failed to initialize save system\n");
        // Non-critical, continue
    }
    
    // Initialize audio system
    if (audio_system_init() != 0) {
        printf("Warning: Failed to initialize audio system\n");
        // Non-critical, continue
    }
    
    printf("Core systems initialized successfully\n");
    return 0;
}

static void shutdown_systems(void) {
    printf("Shutting down systems...\n");
    
    audio_system_shutdown();
    wal_system_shutdown();
    ai_system_shutdown();
    entity_system_shutdown();
    memory_manager_shutdown();
    
    printf("Systems shutdown complete\n");
}

//==============================================================================
// GRAPHICS INITIALIZATION
//==============================================================================

static int init_graphics(void) {
    printf("Initializing graphics...\n");
    
    // Initialize GLFW
    glfwSetErrorCallback(error_callback);
    
    if (!glfwInit()) {
        printf("Failed to initialize GLFW\n");
        return -1;
    }
    
    // Configure GLFW for Metal
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE);
    
    // Create window
    g_demo_state.window = glfwCreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, 
                                          "SimCity ARM64 Demo", NULL, NULL);
    if (!g_demo_state.window) {
        printf("Failed to create window\n");
        glfwTerminate();
        return -1;
    }
    
    // Set up input callbacks
    glfwSetKeyCallback(g_demo_state.window, key_callback);
    glfwSetMouseButtonCallback(g_demo_state.window, mouse_button_callback);
    glfwSetCursorPosCallback(g_demo_state.window, cursor_pos_callback);
    glfwSetScrollCallback(g_demo_state.window, scroll_callback);
    glfwSetWindowSizeCallback(g_demo_state.window, window_size_callback);
    
    // Initialize Metal
    g_demo_state.metal_device = MTLCreateSystemDefaultDevice();
    if (!g_demo_state.metal_device) {
        printf("Failed to create Metal device\n");
        glfwDestroyWindow(g_demo_state.window);
        glfwTerminate();
        return -1;
    }
    
    g_demo_state.metal_queue = [g_demo_state.metal_device newCommandQueue];
    if (!g_demo_state.metal_queue) {
        printf("Failed to create Metal command queue\n");
        glfwDestroyWindow(g_demo_state.window);
        glfwTerminate();
        return -1;
    }
    
    // Create Metal view
    NSWindow* nswindow = glfwGetCocoaWindow(g_demo_state.window);
    g_demo_state.metal_view = [[MTKView alloc] initWithFrame:nswindow.contentView.bounds device:g_demo_state.metal_device];
    g_demo_state.metal_view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    g_demo_state.metal_view.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
    [nswindow.contentView addSubview:g_demo_state.metal_view];
    
    // Initialize camera
    g_demo_state.camera_x = CITY_WIDTH * 0.5f;
    g_demo_state.camera_y = 50.0f; // Elevated view
    g_demo_state.camera_z = CITY_HEIGHT * 0.5f;
    g_demo_state.camera_zoom = 1.0f;
    g_demo_state.camera_rotation = 0.0f;
    
#ifdef DEBUG_OVERLAY_ENABLED
    // Initialize debug overlay
    if (debug_overlay_init(g_demo_state.window, g_demo_state.metal_device, g_demo_state.metal_queue) != 0) {
        printf("Warning: Failed to initialize debug overlay\n");
    }
#endif
    
    printf("Graphics initialized successfully\n");
    return 0;
}

static void shutdown_graphics(void) {
    printf("Shutting down graphics...\n");
    
#ifdef DEBUG_OVERLAY_ENABLED
    debug_overlay_shutdown();
#endif
    
    if (g_demo_state.window) {
        glfwDestroyWindow(g_demo_state.window);
    }
    
    glfwTerminate();
    
    printf("Graphics shutdown complete\n");
}

//==============================================================================
// CITY GENERATION
//==============================================================================

static void generate_city_layout(void) {
    printf("Generating city layout (%dx%d)...\n", CITY_WIDTH, CITY_HEIGHT);
    
    // Simple grid-based city layout
    // For now, just create a basic road network
    
    // Create main roads every 10 units
    for (int x = 0; x < CITY_WIDTH; x += 10) {
        for (int y = 0; y < CITY_HEIGHT; y++) {
            // Vertical road
            // Would set tile type to road here
        }
    }
    
    for (int y = 0; y < CITY_HEIGHT; y += 10) {
        for (int x = 0; x < CITY_WIDTH; x++) {
            // Horizontal road
            // Would set tile type to road here
        }
    }
    
    // Add some buildings between roads
    for (int x = 2; x < CITY_WIDTH; x += 10) {
        for (int y = 2; y < CITY_HEIGHT; y += 10) {
            // Add buildings in a pattern
            if ((x + y) % 20 < 6) {
                // Residential building
                // Would spawn building entity here
            } else if ((x + y) % 20 < 8) {
                // Commercial building
                // Would spawn building entity here
            }
        }
    }
    
    printf("City layout generated\n");
}

static void spawn_initial_population(void) {
    printf("Spawning initial population...\n");
    
    srand((unsigned int)time(NULL));
    
    // Spawn citizens
    for (int i = 0; i < INITIAL_CITIZEN_COUNT; i++) {
        float x = (rand() % (CITY_WIDTH * 10)) / 10.0f;
        float y = (rand() % (CITY_HEIGHT * 10)) / 10.0f;
        
        // Spawn citizen entity
        ai_spawn_agent(i, 0, x, y); // Agent type 0 = citizen
        g_demo_state.active_citizens++;
    }
    
    // Spawn vehicles
    for (int i = 0; i < INITIAL_VEHICLE_COUNT; i++) {
        float x = (rand() % (CITY_WIDTH * 10)) / 10.0f;
        float y = (rand() % (CITY_HEIGHT * 10)) / 10.0f;
        
        // Spawn vehicle entity
        ai_spawn_agent(INITIAL_CITIZEN_COUNT + i, 1, x, y); // Agent type 1 = vehicle
        g_demo_state.active_vehicles++;
    }
    
    g_demo_state.total_entities = INITIAL_CITIZEN_COUNT + INITIAL_VEHICLE_COUNT;
    
    printf("Spawned %d citizens and %d vehicles (%d total entities)\n", 
           INITIAL_CITIZEN_COUNT, INITIAL_VEHICLE_COUNT, g_demo_state.total_entities);
}

//==============================================================================
// SIMULATION UPDATE
//==============================================================================

static void update_simulation(float delta_time) {
    // Scale delta time by simulation speed
    float scaled_delta = delta_time * SIMULATION_SPEED;
    g_demo_state.simulation_time += scaled_delta;
    
    // Update entity system
    entity_system_update(scaled_delta);
    
    // Update AI system
    ai_system_update(scaled_delta);
    
    // Update audio listener position (follow camera)
    audio_set_listener_position(g_demo_state.camera_x, g_demo_state.camera_y, g_demo_state.camera_z);
    audio_set_listener_orientation(0, 0, -1, 0, 1, 0); // Looking down Z-axis
    
    // Save state periodically (every 30 seconds)
    static float last_save_time = 0.0f;
    if (g_demo_state.simulation_time - last_save_time > 30.0f) {
        SimulationState state = create_simulation_state(
            g_demo_state.frame_count,
            g_demo_state.total_entities,
            0, // building count
            g_demo_state.active_citizens,
            100000, // money
            0.75f, // happiness
            (uint32_t)(g_demo_state.simulation_time / 86400), // day
            0 // weather
        );
        
        wal_save_simulation_state(&state);
        last_save_time = g_demo_state.simulation_time;
    }
}

//==============================================================================
// RENDERING
//==============================================================================

static void render_frame(void) {
    // Get current drawable
    id<CAMetalDrawable> drawable = [g_demo_state.metal_view currentDrawable];
    if (!drawable) return;
    
    // Create command buffer
    id<MTLCommandBuffer> command_buffer = [g_demo_state.metal_queue commandBuffer];
    
    // Set up render pass
    MTLRenderPassDescriptor* render_pass = [MTLRenderPassDescriptor renderPassDescriptor];
    render_pass.colorAttachments[0].texture = drawable.texture;
    render_pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    render_pass.colorAttachments[0].clearColor = MTLClearColorMake(0.2, 0.4, 0.6, 1.0); // Sky blue
    render_pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    // Create render encoder
    id<MTLRenderCommandEncoder> render_encoder = [command_buffer renderCommandEncoderWithDescriptor:render_pass];
    
    // TODO: Render city geometry, entities, etc.
    // For now, just clear to sky blue
    
    // Render simple ground plane
    // TODO: Add actual geometry rendering
    
    // Render entities as colored dots for now
    // TODO: Add proper entity rendering
    
#ifdef DEBUG_OVERLAY_ENABLED
    // Update debug overlay with current stats
    debug_overlay_set_entity_count(g_demo_state.total_entities);
    debug_overlay_set_draw_calls(1); // Placeholder
    
    // Render debug overlay
    debug_overlay_new_frame();
    debug_overlay_render(render_encoder);
#endif
    
    [render_encoder endEncoding];
    
    // Present drawable
    [command_buffer presentDrawable:drawable];
    [command_buffer commit];
}

//==============================================================================
// INPUT HANDLING
//==============================================================================

static void handle_input(void) {
    // Camera movement with WASD
    float move_speed = 10.0f * get_delta_time();
    
    if (g_demo_state.keys[GLFW_KEY_W]) {
        g_demo_state.camera_z -= move_speed;
    }
    if (g_demo_state.keys[GLFW_KEY_S]) {
        g_demo_state.camera_z += move_speed;
    }
    if (g_demo_state.keys[GLFW_KEY_A]) {
        g_demo_state.camera_x -= move_speed;
    }
    if (g_demo_state.keys[GLFW_KEY_D]) {
        g_demo_state.camera_x += move_speed;
    }
    
    // Camera zoom with Q/E
    if (g_demo_state.keys[GLFW_KEY_Q]) {
        g_demo_state.camera_zoom *= 1.01f;
    }
    if (g_demo_state.keys[GLFW_KEY_E]) {
        g_demo_state.camera_zoom *= 0.99f;
    }
    
    // Clamp camera position
    g_demo_state.camera_x = fmaxf(0, fminf(CITY_WIDTH, g_demo_state.camera_x));
    g_demo_state.camera_z = fmaxf(0, fminf(CITY_HEIGHT, g_demo_state.camera_z));
    g_demo_state.camera_zoom = fmaxf(0.1f, fminf(5.0f, g_demo_state.camera_zoom));
}

//==============================================================================
// PERFORMANCE TRACKING
//==============================================================================

static void update_performance_stats(void) {
    double current_time = glfwGetTime();
    float frame_time = (float)(current_time - g_demo_state.last_time);
    g_demo_state.last_time = current_time;
    
    // Update rolling average
    g_demo_state.frame_times[g_demo_state.frame_time_index] = frame_time;
    g_demo_state.frame_time_index = (g_demo_state.frame_time_index + 1) % 60;
    
    float total = 0.0f;
    for (int i = 0; i < 60; i++) {
        total += g_demo_state.frame_times[i];
    }
    g_demo_state.avg_frame_time = total / 60.0f;
    
    // Print stats every 5 seconds
    static double last_stats_time = 0.0;
    if (current_time - last_stats_time > 5.0) {
        printf("FPS: %.1f | Entities: %u | Sim Time: %.1fs\n", 
               1.0f / g_demo_state.avg_frame_time, 
               g_demo_state.total_entities,
               g_demo_state.simulation_time);
        last_stats_time = current_time;
        
        // Print AI performance stats
        ai_print_performance_stats();
    }
}

static uint64_t get_time_ns(void) {
    return mach_absolute_time();
}

static float get_delta_time(void) {
    double current_time = glfwGetTime();
    float delta = (float)(current_time - g_demo_state.last_time);
    return fminf(delta, 0.1f); // Cap at 100ms to prevent large jumps
}

//==============================================================================
// GLFW CALLBACKS
//==============================================================================

static void error_callback(int error, const char* description) {
    fprintf(stderr, "GLFW Error %d: %s\n", error, description);
}

static void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods) {
    if (key >= 0 && key < GLFW_KEY_LAST) {
        g_demo_state.keys[key] = (action != GLFW_RELEASE);
    }
    
#ifdef DEBUG_OVERLAY_ENABLED
    if (debug_overlay_handle_input(key, action)) {
        return; // Input was handled by debug overlay
    }
#endif
    
    if (action == GLFW_PRESS) {
        switch (key) {
            case GLFW_KEY_ESCAPE:
                g_demo_state.simulation_running = false;
                break;
            case GLFW_KEY_SPACE:
                g_demo_state.simulation_paused = !g_demo_state.simulation_paused;
                printf("Simulation %s\n", g_demo_state.simulation_paused ? "paused" : "resumed");
                break;
            case GLFW_KEY_R:
                // Restart simulation
                printf("Restarting simulation...\n");
                g_demo_state.simulation_time = 0.0f;
                g_demo_state.frame_count = 0;
                // Would respawn entities here
                break;
        }
    }
}

static void mouse_button_callback(GLFWwindow* window, int button, int action, int mods) {
    if (button == GLFW_MOUSE_BUTTON_LEFT) {
        g_demo_state.mouse_dragging = (action == GLFW_PRESS);
    }
}

static void cursor_pos_callback(GLFWwindow* window, double xpos, double ypos) {
    if (g_demo_state.mouse_dragging) {
        double dx = xpos - g_demo_state.mouse_x;
        double dy = ypos - g_demo_state.mouse_y;
        
        // Pan camera
        g_demo_state.camera_x -= (float)dx * 0.1f;
        g_demo_state.camera_z -= (float)dy * 0.1f;
    }
    
    g_demo_state.mouse_x = xpos;
    g_demo_state.mouse_y = ypos;
}

static void scroll_callback(GLFWwindow* window, double xoffset, double yoffset) {
    // Zoom with scroll wheel
    g_demo_state.camera_zoom *= (yoffset > 0) ? 0.9f : 1.1f;
    g_demo_state.camera_zoom = fmaxf(0.1f, fminf(5.0f, g_demo_state.camera_zoom));
}

static void window_size_callback(GLFWwindow* window, int width, int height) {
    // Update metal view size
    if (g_demo_state.metal_view) {
        NSWindow* nswindow = glfwGetCocoaWindow(window);
        g_demo_state.metal_view.frame = nswindow.contentView.bounds;
    }
}
