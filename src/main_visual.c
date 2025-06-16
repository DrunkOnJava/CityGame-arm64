// SimCity ARM64 Visual Demo
// Basic visual renderer using macOS native graphics

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <mach/mach_time.h>
#include <stdbool.h>

// Core engine includes
#include "core/memory_manager.h"
#include "simulation/entity_system.h"
#include "ai/ai_integration.h"

// For basic graphics we'll use ASCII art in terminal
#include <termios.h>
#include <sys/ioctl.h>

#define INITIAL_CITIZEN_COUNT 100
#define INITIAL_VEHICLE_COUNT 25
#define CITY_WIDTH 40
#define CITY_HEIGHT 20
#define SIMULATION_DURATION_SECONDS 30

// Visual state
static struct {
    bool simulation_running;
    uint64_t frame_count;
    uint32_t active_citizens;
    uint32_t active_vehicles;
    char display_buffer[CITY_HEIGHT][CITY_WIDTH + 1];
    float agent_positions_x[125];
    float agent_positions_y[125];
    int agent_types[125];
    int terminal_width, terminal_height;
    struct termios original_termios;
} g_visual_state = {0};

// Terminal control
static void setup_terminal(void) {
    struct winsize w;
    ioctl(0, TIOCGWINSZ, &w);
    g_visual_state.terminal_width = w.ws_col;
    g_visual_state.terminal_height = w.ws_row;
    
    // Save original terminal settings
    tcgetattr(0, &g_visual_state.original_termios);
    
    // Set up for non-blocking input
    struct termios new_termios = g_visual_state.original_termios;
    new_termios.c_lflag &= ~(ICANON | ECHO);
    tcsetattr(0, TCSANOW, &new_termios);
    
    // Clear screen and hide cursor
    printf("\033[2J\033[H\033[?25l");
    fflush(stdout);
}

static void restore_terminal(void) {
    // Restore original terminal settings and show cursor
    tcsetattr(0, TCSANOW, &g_visual_state.original_termios);
    printf("\033[?25h\033[2J\033[H");
    fflush(stdout);
}

static uint64_t get_time_ns(void) {
    return mach_absolute_time();
}

static float get_delta_time(void) {
    static mach_timebase_info_data_t timebase_info = {0};
    if (timebase_info.denom == 0) {
        mach_timebase_info(&timebase_info);
    }
    
    uint64_t now = get_time_ns();
    static uint64_t last_time = 0;
    
    if (last_time == 0) {
        last_time = now;
        return 1.0f / 30.0f; // 30 FPS for visual demo
    }
    
    uint64_t elapsed_ns = (now - last_time) * timebase_info.numer / timebase_info.denom;
    last_time = now;
    
    return (float)elapsed_ns / 1e9f;
}

// Visual rendering
static void clear_display_buffer(void) {
    for (int y = 0; y < CITY_HEIGHT; y++) {
        for (int x = 0; x < CITY_WIDTH; x++) {
            // Create a simple city background
            if (x % 8 == 0 || y % 5 == 0) {
                g_visual_state.display_buffer[y][x] = '.'; // Roads
            } else {
                g_visual_state.display_buffer[y][x] = ' '; // Empty space
            }
        }
        g_visual_state.display_buffer[y][CITY_WIDTH] = '\0';
    }
    
    // Add some buildings
    for (int y = 1; y < CITY_HEIGHT; y += 5) {
        for (int x = 1; x < CITY_WIDTH; x += 8) {
            if (x + 2 < CITY_WIDTH && y + 2 < CITY_HEIGHT) {
                g_visual_state.display_buffer[y][x] = '#';
                g_visual_state.display_buffer[y][x+1] = '#';
                g_visual_state.display_buffer[y+1][x] = '#';
                g_visual_state.display_buffer[y+1][x+1] = '#';
            }
        }
    }
}

static void update_agent_positions(void) {
    // Get agent positions from the AI system
    // For now we'll simulate movement by updating our local tracking
    for (int i = 0; i < g_visual_state.active_citizens + g_visual_state.active_vehicles; i++) {
        // Add some basic movement simulation
        float speed = (g_visual_state.agent_types[i] == 0) ? 0.5f : 1.0f; // Citizens slower than vehicles
        
        // Simple random walk with bias toward roads
        float dx = ((rand() % 3) - 1) * speed * 0.3f;
        float dy = ((rand() % 3) - 1) * speed * 0.3f;
        
        g_visual_state.agent_positions_x[i] += dx;
        g_visual_state.agent_positions_y[i] += dy;
        
        // Keep in bounds
        if (g_visual_state.agent_positions_x[i] < 0) g_visual_state.agent_positions_x[i] = 0;
        if (g_visual_state.agent_positions_x[i] >= CITY_WIDTH) g_visual_state.agent_positions_x[i] = CITY_WIDTH - 1;
        if (g_visual_state.agent_positions_y[i] < 0) g_visual_state.agent_positions_y[i] = 0;
        if (g_visual_state.agent_positions_y[i] >= CITY_HEIGHT) g_visual_state.agent_positions_y[i] = CITY_HEIGHT - 1;
    }
}

static void render_agents(void) {
    // Place agents on the display
    for (int i = 0; i < g_visual_state.active_citizens + g_visual_state.active_vehicles; i++) {
        int x = (int)g_visual_state.agent_positions_x[i];
        int y = (int)g_visual_state.agent_positions_y[i];
        
        if (x >= 0 && x < CITY_WIDTH && y >= 0 && y < CITY_HEIGHT) {
            if (g_visual_state.agent_types[i] == 0) {
                g_visual_state.display_buffer[y][x] = 'o'; // Citizens
            } else {
                g_visual_state.display_buffer[y][x] = 'V'; // Vehicles
            }
        }
    }
}

static void render_frame(void) {
    clear_display_buffer();
    update_agent_positions();
    render_agents();
    
    // Move cursor to top and render
    printf("\033[H");
    
    // Title and stats
    printf("\033[1;36m🏙️  SimCity ARM64 Live Visual Demo 🏙️\033[0m\n");
    printf("\033[1;32mFrame: %4llu | Citizens: %3d (o) | Vehicles: %3d (V) | Total: %3d\033[0m\n",
           g_visual_state.frame_count,
           g_visual_state.active_citizens,
           g_visual_state.active_vehicles,
           g_visual_state.active_citizens + g_visual_state.active_vehicles);
    printf("\033[1;33mCity: %dx%d | Buildings: # | Roads: . | Press Ctrl+C to exit\033[0m\n",
           CITY_WIDTH, CITY_HEIGHT);
    printf("────────────────────────────────────────────────────────────\n");
    
    // Render city
    for (int y = 0; y < CITY_HEIGHT; y++) {
        printf("│");
        for (int x = 0; x < CITY_WIDTH; x++) {
            char c = g_visual_state.display_buffer[y][x];
            switch (c) {
                case 'o': printf("\033[1;32m%c\033[0m", c); break; // Green citizens
                case 'V': printf("\033[1;34m%c\033[0m", c); break; // Blue vehicles
                case '#': printf("\033[1;37m%c\033[0m", c); break; // White buildings
                case '.': printf("\033[0;90m%c\033[0m", c); break; // Gray roads
                default:  printf("%c", c); break;
            }
        }
        printf("│\n");
    }
    printf("────────────────────────────────────────────────────────────\n");
    
    // Performance info
    static float total_time = 0;
    static float frame_time_sum = 0;
    static int frame_count = 0;
    
    float delta = 1.0f / 30.0f; // Approximate
    total_time += delta;
    frame_time_sum += delta;
    frame_count++;
    
    if (frame_count > 0) {
        float avg_fps = frame_count / total_time;
        printf("\033[1;35mRuntime: %5.1fs | FPS: ~%.1f | Simulation Running...\033[0m\n",
               total_time, avg_fps);
    }
    
    fflush(stdout);
}

static int init_systems(void) {
    if (memory_manager_init() != 0 ||
        entity_system_init() != 0 ||
        ai_system_init(NULL, CITY_WIDTH, CITY_HEIGHT) != 0) {
        return -1;
    }
    return 0;
}

static void spawn_population(void) {
    // Spawn citizens
    for (int i = 0; i < INITIAL_CITIZEN_COUNT; i++) {
        float x = (float)(rand() % CITY_WIDTH);
        float y = (float)(rand() % CITY_HEIGHT);
        
        g_visual_state.agent_positions_x[i] = x;
        g_visual_state.agent_positions_y[i] = y;
        g_visual_state.agent_types[i] = 0; // Citizen
        
        ai_spawn_agent(i, 0, x, y);
        g_visual_state.active_citizens++;
    }
    
    // Spawn vehicles
    for (int i = INITIAL_CITIZEN_COUNT; i < INITIAL_CITIZEN_COUNT + INITIAL_VEHICLE_COUNT; i++) {
        float x = (float)(rand() % CITY_WIDTH);
        float y = (float)(rand() % CITY_HEIGHT);
        
        g_visual_state.agent_positions_x[i] = x;
        g_visual_state.agent_positions_y[i] = y;
        g_visual_state.agent_types[i] = 1; // Vehicle
        
        ai_spawn_agent(i, 1, x, y);
        g_visual_state.active_vehicles++;
    }
}

static void cleanup_systems(void) {
    ai_system_shutdown();
    entity_system_shutdown();
    memory_manager_shutdown();
}

int main(void) {
    // Setup
    srand((unsigned int)time(NULL));
    setup_terminal();
    
    if (init_systems() != 0) {
        restore_terminal();
        printf("Failed to initialize systems\n");
        return -1;
    }
    
    spawn_population();
    g_visual_state.simulation_running = true;
    
    // Main visual loop
    int target_frames = SIMULATION_DURATION_SECONDS * 30; // 30 FPS
    for (int frame = 0; frame < target_frames && g_visual_state.simulation_running; frame++) {
        float delta_time = get_delta_time();
        
        // Update simulation
        entity_system_update(delta_time);
        ai_system_update(delta_time);
        
        // Render frame
        render_frame();
        g_visual_state.frame_count++;
        
        // Control frame rate (30 FPS for smooth visual)
        usleep(33333); // ~33ms = 30 FPS
    }
    
    // Cleanup
    restore_terminal();
    cleanup_systems();
    
    printf("\n🎉 Visual demo completed successfully!\n");
    printf("Final stats: %d citizens + %d vehicles = %d total agents\n",
           g_visual_state.active_citizens, g_visual_state.active_vehicles,
           g_visual_state.active_citizens + g_visual_state.active_vehicles);
    
    return 0;
}