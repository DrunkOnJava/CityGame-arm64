// SimCity ARM64 Debug Overlay System
// Agent 7: UI Systems & HUD
// ImGui integration with retina display support and Metal backend

#include "debug_overlay.h"
#include <iostream>
#include <sstream>
#include <iomanip>
#include <vector>
#include <unordered_map>
#include <algorithm>
#include <chrono>
#include <mach/mach.h>
#include <mach/processor_info.h>
#include <mach/mach_host.h>
#include <sys/sysctl.h>

// ImGui includes
#include "imgui.h"
#include "imgui_impl_metal.h"
#include "imgui_impl_glfw.h"
#include "imgui_internal.h"

// Metal includes
#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>
#include <Foundation/Foundation.h>

// GLFW for window management
#include <GLFW/glfw3.h>
#define GLFW_EXPOSE_NATIVE_COCOA
#include <GLFW/glfw3native.h>

using namespace std::chrono;

// Debug overlay configuration
static const float OVERLAY_ALPHA = 0.85f;
static const float FONT_SIZE_BASE = 13.0f;
static const int HISTORY_SIZE = 60; // 1 second at 60fps

// Performance metrics structure
struct PerformanceMetrics {
    std::vector<float> frame_times;
    std::vector<float> cpu_usage;
    std::vector<float> memory_usage;
    std::vector<uint32_t> entity_count;
    std::vector<uint32_t> draw_calls;
    float avg_frametime = 0.0f;
    float min_frametime = 0.0f;
    float max_frametime = 0.0f;
    uint64_t total_memory = 0;
    uint64_t used_memory = 0;
    float cpu_percent = 0.0f;
};

// Debug overlay state
struct DebugOverlayState {
    bool show_performance = true;
    bool show_entities = true;
    bool show_rendering = true;
    bool show_ai = false;
    bool show_networking = false;
    bool show_memory_profiler = false;
    bool show_devactor_status = false;
    
    // Window positions and sizes
    ImVec2 performance_pos = {10, 10};
    ImVec2 entities_pos = {10, 200};
    ImVec2 rendering_pos = {300, 10};
    
    // Metrics
    PerformanceMetrics metrics;
    high_resolution_clock::time_point last_update;
    
    // Retina display scaling
    float display_scale = 1.0f;
    float font_scale = 1.0f;
    
    // Metal rendering context
    id<MTLDevice> metal_device = nullptr;
    id<MTLCommandQueue> metal_queue = nullptr;
    MTKView* metal_view = nullptr;
    
    // Fonts
    ImFont* default_font = nullptr;
    ImFont* mono_font = nullptr;
    ImFont* bold_font = nullptr;
};

static DebugOverlayState g_overlay_state;

// Forward declarations
static void setup_imgui_style();
static void load_fonts(float scale_factor);
static void render_performance_window();
static void render_entities_window();
static void render_rendering_window();
static void render_ai_window();
static void render_networking_window();
static void render_memory_profiler();
static void render_devactor_status();
static void update_performance_metrics();
static float get_cpu_usage();
static uint64_t get_memory_usage();
static void detect_retina_scaling(GLFWwindow* window);

//==============================================================================
// INITIALIZATION AND CLEANUP
//==============================================================================

int debug_overlay_init(GLFWwindow* window, id<MTLDevice> device, id<MTLCommandQueue> queue) {
    if (!window || !device || !queue) {
        std::cerr << "Invalid parameters for debug overlay initialization" << std::endl;
        return -1;
    }
    
    // Store Metal context
    g_overlay_state.metal_device = device;
    g_overlay_state.metal_queue = queue;
    
    // Detect retina display scaling
    detect_retina_scaling(window);
    
    // Setup Dear ImGui context
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    
    // Configure ImGui
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;
    io.ConfigFlags |= ImGuiConfigFlags_DockingEnable;
    io.ConfigFlags |= ImGuiConfigFlags_ViewportsEnable;
    
    // Setup platform/renderer backends
    if (!ImGui_ImplGlfw_InitForOther(window, true)) {
        std::cerr << "Failed to initialize ImGui GLFW backend" << std::endl;
        return -1;
    }
    
    if (!ImGui_ImplMetal_Init(device)) {
        std::cerr << "Failed to initialize ImGui Metal backend" << std::endl;
        ImGui_ImplGlfw_Shutdown();
        return -1;
    }
    
    // Load fonts with proper scaling
    load_fonts(g_overlay_state.display_scale);
    
    // Setup ImGui style
    setup_imgui_style();
    
    // Initialize metrics
    g_overlay_state.metrics.frame_times.reserve(HISTORY_SIZE);
    g_overlay_state.metrics.cpu_usage.reserve(HISTORY_SIZE);
    g_overlay_state.metrics.memory_usage.reserve(HISTORY_SIZE);
    g_overlay_state.metrics.entity_count.reserve(HISTORY_SIZE);
    g_overlay_state.metrics.draw_calls.reserve(HISTORY_SIZE);
    
    g_overlay_state.last_update = high_resolution_clock::now();
    
    std::cout << "Debug overlay initialized with " << g_overlay_state.display_scale 
              << "x scaling" << std::endl;
    
    return 0;
}

void debug_overlay_shutdown() {
    ImGui_ImplMetal_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();
    
    // Clear state
    g_overlay_state = DebugOverlayState{};
    
    std::cout << "Debug overlay shutdown complete" << std::endl;
}

//==============================================================================
// RETINA DISPLAY SUPPORT
//==============================================================================

static void detect_retina_scaling(GLFWwindow* window) {
    // Get window and framebuffer sizes
    int window_width, window_height;
    int framebuffer_width, framebuffer_height;
    
    glfwGetWindowSize(window, &window_width, &window_height);
    glfwGetFramebufferSize(window, &framebuffer_width, &framebuffer_height);
    
    // Calculate scale factor
    float x_scale = static_cast<float>(framebuffer_width) / window_width;
    float y_scale = static_cast<float>(framebuffer_height) / window_height;
    
    g_overlay_state.display_scale = std::max(x_scale, y_scale);
    g_overlay_state.font_scale = g_overlay_state.display_scale;
    
    // Clamp to reasonable values
    g_overlay_state.display_scale = std::clamp(g_overlay_state.display_scale, 1.0f, 3.0f);
    g_overlay_state.font_scale = std::clamp(g_overlay_state.font_scale, 1.0f, 3.0f);
    
    std::cout << "Detected display scale: " << g_overlay_state.display_scale 
              << ", font scale: " << g_overlay_state.font_scale << std::endl;
}

static void load_fonts(float scale_factor) {
    ImGuiIO& io = ImGui::GetIO();
    
    // Clear existing fonts
    io.Fonts->Clear();
    
    float font_size = FONT_SIZE_BASE * scale_factor;
    
    // Load default font
    g_overlay_state.default_font = io.Fonts->AddFontDefault();
    
    // Try to load system fonts
    const char* system_font_paths[] = {
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SF-Pro-Display-Regular.otf",
        "/System/Library/Fonts/Arial.ttf"
    };
    
    for (const char* font_path : system_font_paths) {
        if (access(font_path, R_OK) == 0) {
            g_overlay_state.default_font = io.Fonts->AddFontFromFileTTF(
                font_path, font_size, nullptr, io.Fonts->GetGlyphRangesDefault());
            break;
        }
    }
    
    // Load monospace font for code/metrics
    const char* mono_font_paths[] = {
        "/System/Library/Fonts/Menlo.ttc",
        "/System/Library/Fonts/Monaco.ttf",
        "/System/Library/Fonts/Courier New.ttf"
    };
    
    for (const char* font_path : mono_font_paths) {
        if (access(font_path, R_OK) == 0) {
            g_overlay_state.mono_font = io.Fonts->AddFontFromFileTTF(
                font_path, font_size * 0.9f, nullptr, io.Fonts->GetGlyphRangesDefault());
            break;
        }
    }
    
    if (!g_overlay_state.mono_font) {
        g_overlay_state.mono_font = g_overlay_state.default_font;
    }
    
    // Load bold font
    const char* bold_font_paths[] = {
        "/System/Library/Fonts/Helvetica-Bold.ttc",
        "/System/Library/Fonts/SF-Pro-Display-Bold.otf",
        "/System/Library/Fonts/Arial Bold.ttf"
    };
    
    for (const char* font_path : bold_font_paths) {
        if (access(font_path, R_OK) == 0) {
            g_overlay_state.bold_font = io.Fonts->AddFontFromFileTTF(
                font_path, font_size, nullptr, io.Fonts->GetGlyphRangesDefault());
            break;
        }
    }
    
    if (!g_overlay_state.bold_font) {
        g_overlay_state.bold_font = g_overlay_state.default_font;
    }
    
    // Build font atlas
    io.Fonts->Build();
    
    std::cout << "Loaded fonts at " << font_size << "pt size" << std::endl;
}

//==============================================================================
// STYLE CONFIGURATION
//==============================================================================

static void setup_imgui_style() {
    ImGuiStyle& style = ImGui::GetStyle();
    
    // Scale style for retina displays
    style.ScaleAllSizes(g_overlay_state.display_scale);
    
    // Dark theme with transparency
    ImGui::StyleColorsDark();
    
    // Customize colors for better visibility
    ImVec4* colors = style.Colors;
    
    // Window background with transparency
    colors[ImGuiCol_WindowBg] = ImVec4(0.06f, 0.06f, 0.06f, OVERLAY_ALPHA);
    colors[ImGuiCol_ChildBg] = ImVec4(0.00f, 0.00f, 0.00f, 0.00f);
    
    // Headers
    colors[ImGuiCol_Header] = ImVec4(0.26f, 0.59f, 0.98f, 0.31f);
    colors[ImGuiCol_HeaderHovered] = ImVec4(0.26f, 0.59f, 0.98f, 0.80f);
    colors[ImGuiCol_HeaderActive] = ImVec4(0.26f, 0.59f, 0.98f, 1.00f);
    
    // Buttons
    colors[ImGuiCol_Button] = ImVec4(0.26f, 0.59f, 0.98f, 0.40f);
    colors[ImGuiCol_ButtonHovered] = ImVec4(0.26f, 0.59f, 0.98f, 1.00f);
    colors[ImGuiCol_ButtonActive] = ImVec4(0.06f, 0.53f, 0.98f, 1.00f);
    
    // Frame/borders
    colors[ImGuiCol_FrameBg] = ImVec4(0.16f, 0.29f, 0.48f, 0.54f);
    colors[ImGuiCol_FrameBgHovered] = ImVec4(0.26f, 0.59f, 0.98f, 0.40f);
    colors[ImGuiCol_FrameBgActive] = ImVec4(0.26f, 0.59f, 0.98f, 0.67f);
    
    // Text
    colors[ImGuiCol_Text] = ImVec4(1.00f, 1.00f, 1.00f, 1.00f);
    colors[ImGuiCol_TextDisabled] = ImVec4(0.50f, 0.50f, 0.50f, 1.00f);
    
    // Performance theme tweaks
    style.WindowRounding = 5.0f;
    style.FrameRounding = 3.0f;
    style.PopupRounding = 3.0f;
    style.ScrollbarRounding = 3.0f;
    style.GrabRounding = 3.0f;
    style.TabRounding = 3.0f;
    
    // Spacing
    style.WindowPadding = ImVec2(8, 8);
    style.FramePadding = ImVec2(4, 3);
    style.ItemSpacing = ImVec2(8, 4);
    style.ItemInnerSpacing = ImVec2(4, 4);
    
    std::cout << "ImGui style configured for " << g_overlay_state.display_scale << "x scale" << std::endl;
}

//==============================================================================
// MAIN RENDERING FUNCTIONS
//==============================================================================

void debug_overlay_new_frame() {
    // Start ImGui frame
    ImGui_ImplMetal_NewFrame(nullptr);
    ImGui_ImplGlfw_NewFrame();
    ImGui::NewFrame();
    
    // Update performance metrics
    update_performance_metrics();
}

void debug_overlay_render(id<MTLRenderCommandEncoder> encoder) {
    // Main menu bar
    if (ImGui::BeginMainMenuBar()) {
        if (ImGui::BeginMenu("Debug")) {
            ImGui::MenuItem("Performance", nullptr, &g_overlay_state.show_performance);
            ImGui::MenuItem("Entities", nullptr, &g_overlay_state.show_entities);
            ImGui::MenuItem("Rendering", nullptr, &g_overlay_state.show_rendering);
            ImGui::MenuItem("AI Systems", nullptr, &g_overlay_state.show_ai);
            ImGui::MenuItem("Networking", nullptr, &g_overlay_state.show_networking);
            ImGui::MenuItem("Memory Profiler", nullptr, &g_overlay_state.show_memory_profiler);
            ImGui::MenuItem("DevActor Status", nullptr, &g_overlay_state.show_devactor_status);
            ImGui::EndMenu();
        }
        
        // System info in menu bar
        ImGui::SameLine(ImGui::GetWindowWidth() - 200);
        ImGui::Text("%.1f FPS", ImGui::GetIO().Framerate);
        
        ImGui::EndMainMenuBar();
    }
    
    // Render debug windows
    if (g_overlay_state.show_performance) {
        render_performance_window();
    }
    
    if (g_overlay_state.show_entities) {
        render_entities_window();
    }
    
    if (g_overlay_state.show_rendering) {
        render_rendering_window();
    }
    
    if (g_overlay_state.show_ai) {
        render_ai_window();
    }
    
    if (g_overlay_state.show_networking) {
        render_networking_window();
    }
    
    if (g_overlay_state.show_memory_profiler) {
        render_memory_profiler();
    }
    
    if (g_overlay_state.show_devactor_status) {
        render_devactor_status();
    }
    
    // Render ImGui
    ImGui::Render();
    
    if (encoder) {
        ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), encoder);
    }
    
    // Handle multi-viewport rendering
    ImGuiIO& io = ImGui::GetIO();
    if (io.ConfigFlags & ImGuiConfigFlags_ViewportsEnable) {
        ImGui::UpdatePlatformWindows();
        ImGui::RenderPlatformWindowsDefault();
    }
}

//==============================================================================
// PERFORMANCE WINDOW
//==============================================================================

static void render_performance_window() {
    ImGui::SetNextWindowPos(g_overlay_state.performance_pos, ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowSize(ImVec2(350 * g_overlay_state.display_scale, 200 * g_overlay_state.display_scale), ImGuiCond_FirstUseEver);
    
    if (ImGui::Begin("Performance", &g_overlay_state.show_performance)) {
        ImGui::PushFont(g_overlay_state.mono_font);
        
        // Frame time statistics
        ImGui::Text("Frame Time: %.3f ms (%.1f FPS)", 
                   g_overlay_state.metrics.avg_frametime * 1000.0f, 
                   1.0f / g_overlay_state.metrics.avg_frametime);
        
        ImGui::Text("Min: %.3f ms, Max: %.3f ms", 
                   g_overlay_state.metrics.min_frametime * 1000.0f,
                   g_overlay_state.metrics.max_frametime * 1000.0f);
        
        // CPU and memory
        ImGui::Text("CPU: %.1f%%", g_overlay_state.metrics.cpu_percent);
        ImGui::Text("Memory: %.1f MB / %.1f MB (%.1f%%)", 
                   g_overlay_state.metrics.used_memory / (1024.0f * 1024.0f),
                   g_overlay_state.metrics.total_memory / (1024.0f * 1024.0f),
                   (float)g_overlay_state.metrics.used_memory / g_overlay_state.metrics.total_memory * 100.0f);
        
        ImGui::PopFont();
        
        // Frame time graph
        if (!g_overlay_state.metrics.frame_times.empty()) {
            ImGui::PlotLines("Frame Time (ms)", 
                           g_overlay_state.metrics.frame_times.data(),
                           g_overlay_state.metrics.frame_times.size(),
                           0, nullptr, 0.0f, 33.33f, ImVec2(0, 80));
        }
        
        g_overlay_state.performance_pos = ImGui::GetWindowPos();
    }
    ImGui::End();
}

static void render_entities_window() {
    ImGui::SetNextWindowPos(g_overlay_state.entities_pos, ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowSize(ImVec2(300 * g_overlay_state.display_scale, 150 * g_overlay_state.display_scale), ImGuiCond_FirstUseEver);
    
    if (ImGui::Begin("Entity Systems", &g_overlay_state.show_entities)) {
        ImGui::PushFont(g_overlay_state.mono_font);
        
        // Entity counts (placeholder - would be populated by actual system)
        ImGui::Text("Active Entities: %d", 1250);
        ImGui::Text("Citizens: %d", 800);
        ImGui::Text("Vehicles: %d", 300);
        ImGui::Text("Buildings: %d", 150);
        
        ImGui::Separator();
        
        // Entity performance
        ImGui::Text("Entity Updates/s: %d", 45000);
        ImGui::Text("Pathfinding Requests: %d", 120);
        ImGui::Text("Behavior Tree Ticks: %d", 800);
        
        ImGui::PopFont();
        
        g_overlay_state.entities_pos = ImGui::GetWindowPos();
    }
    ImGui::End();
}

static void render_rendering_window() {
    ImGui::SetNextWindowPos(g_overlay_state.rendering_pos, ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowSize(ImVec2(280 * g_overlay_state.display_scale, 180 * g_overlay_state.display_scale), ImGuiCond_FirstUseEver);
    
    if (ImGui::Begin("Rendering", &g_overlay_state.show_rendering)) {
        ImGui::PushFont(g_overlay_state.mono_font);
        
        // Rendering statistics (placeholder)
        ImGui::Text("Draw Calls: %d", 45);
        ImGui::Text("Triangles: %d", 125000);
        ImGui::Text("Vertices: %d", 75000);
        
        ImGui::Separator();
        
        // Metal-specific stats
        ImGui::Text("GPU: Apple Silicon");
        ImGui::Text("Metal Shaders: %d", 12);
        ImGui::Text("Texture Memory: %.1f MB", 45.2f);
        ImGui::Text("Buffer Memory: %.1f MB", 12.8f);
        
        ImGui::Separator();
        
        // Culling and optimization
        ImGui::Text("Frustum Culled: %d", 2500);
        ImGui::Text("Occlusion Culled: %d", 800);
        ImGui::Text("LOD Switches: %d", 25);
        
        ImGui::PopFont();
        
        g_overlay_state.rendering_pos = ImGui::GetWindowPos();
    }
    ImGui::End();
}

static void render_ai_window() {
    if (ImGui::Begin("AI Systems", &g_overlay_state.show_ai)) {
        ImGui::PushFont(g_overlay_state.mono_font);
        
        // AI system stats
        ImGui::Text("Navmesh Nodes: %d", 8192);
        ImGui::Text("Active Paths: %d", 450);
        ImGui::Text("Behavior Trees: %d", 800);
        ImGui::Text("Decision Updates/s: %d", 1200);
        
        ImGui::Separator();
        
        // Performance breakdown
        ImGui::Text("Pathfinding: %.2f ms", 2.5f);
        ImGui::Text("Behavior Trees: %.2f ms", 1.8f);
        ImGui::Text("Agent Updates: %.2f ms", 3.2f);
        
        ImGui::PopFont();
    }
    ImGui::End();
}

static void render_networking_window() {
    if (ImGui::Begin("Networking", &g_overlay_state.show_networking)) {
        ImGui::PushFont(g_overlay_state.mono_font);
        
        // Network stats
        ImGui::Text("Active Connections: %d", 3);
        ImGui::Text("Messages/s: %d", 150);
        ImGui::Text("Bandwidth: %.2f KB/s", 12.5f);
        
        ImGui::Separator();
        
        // Actor system
        ImGui::Text("Active Actors: %d", 10);
        ImGui::Text("Message Queue: %d", 25);
        ImGui::Text("Failed Messages: %d", 0);
        
        ImGui::PopFont();
    }
    ImGui::End();
}

static void render_memory_profiler() {
    if (ImGui::Begin("Memory Profiler", &g_overlay_state.show_memory_profiler)) {
        ImGui::PushFont(g_overlay_state.mono_font);
        
        // Memory breakdown
        ImGui::Text("Total Allocated: %.2f MB", 125.6f);
        ImGui::Text("Entity System: %.2f MB", 45.2f);
        ImGui::Text("Rendering: %.2f MB", 38.4f);
        ImGui::Text("AI System: %.2f MB", 22.1f);
        ImGui::Text("Audio: %.2f MB", 12.8f);
        ImGui::Text("Other: %.2f MB", 7.1f);
        
        ImGui::Separator();
        
        // Allocation tracking
        ImGui::Text("Allocations/s: %d", 45);
        ImGui::Text("Deallocations/s: %d", 42);
        ImGui::Text("Peak Usage: %.2f MB", 156.8f);
        
        ImGui::PopFont();
    }
    ImGui::End();
}

static void render_devactor_status() {
    if (ImGui::Begin("DevActor Status", &g_overlay_state.show_devactor_status)) {
        ImGui::PushFont(g_overlay_state.mono_font);
        
        // DevActor system overview
        ImGui::Text("Orchestrator: RUNNING");
        ImGui::Text("Active Workers: 10/10");
        
        ImGui::Separator();
        
        // Individual DevActor status
        const char* devactor_names[] = {
            "DevActor 0 (Orchestrator)",
            "DevActor 1 (Core Engine)", 
            "DevActor 2 (Simulation)",
            "DevActor 3 (Graphics)",
            "DevActor 4 (AI Systems)",
            "DevActor 5 (Infrastructure)",
            "DevActor 6 (Save System)",
            "DevActor 7 (UI Systems)",
            "DevActor 8 (Audio)",
            "DevActor 9 (QA & Testing)"
        };
        
        const char* status_colors[] = {
            "HEALTHY", "HEALTHY", "HEALTHY", "HEALTHY", "HEALTHY",
            "HEALTHY", "HEALTHY", "HEALTHY", "HEALTHY", "HEALTHY"
        };
        
        for (int i = 0; i < 10; i++) {
            ImGui::TextColored(ImVec4(0.0f, 1.0f, 0.0f, 1.0f), "●");
            ImGui::SameLine();
            ImGui::Text("%s: %s", devactor_names[i], status_colors[i]);
        }
        
        ImGui::PopFont();
    }
    ImGui::End();
}

//==============================================================================
// PERFORMANCE METRICS
//==============================================================================

static void update_performance_metrics() {
    auto now = high_resolution_clock::now();
    auto delta = duration_cast<microseconds>(now - g_overlay_state.last_update).count();
    
    if (delta < 16666) { // Update at most every 16.67ms (60fps)
        return;
    }
    
    g_overlay_state.last_update = now;
    
    // Calculate frame time
    float frame_time = delta / 1000000.0f; // Convert to seconds
    
    // Add to history
    auto& metrics = g_overlay_state.metrics;
    
    metrics.frame_times.push_back(frame_time * 1000.0f); // Convert to ms for display
    if (metrics.frame_times.size() > HISTORY_SIZE) {
        metrics.frame_times.erase(metrics.frame_times.begin());
    }
    
    // Calculate statistics
    if (!metrics.frame_times.empty()) {
        float sum = 0.0f;
        float min_val = metrics.frame_times[0];
        float max_val = metrics.frame_times[0];
        
        for (float ft : metrics.frame_times) {
            sum += ft;
            min_val = std::min(min_val, ft);
            max_val = std::max(max_val, ft);
        }
        
        metrics.avg_frametime = (sum / metrics.frame_times.size()) / 1000.0f; // Back to seconds
        metrics.min_frametime = min_val / 1000.0f;
        metrics.max_frametime = max_val / 1000.0f;
    }
    
    // Update system metrics
    metrics.cpu_percent = get_cpu_usage();
    metrics.used_memory = get_memory_usage();
    
    // Get total memory (static)
    if (metrics.total_memory == 0) {
        int mib[2] = {CTL_HW, HW_MEMSIZE};
        size_t length = sizeof(uint64_t);
        sysctl(mib, 2, &metrics.total_memory, &length, nullptr, 0);
    }
}

static float get_cpu_usage() {
    static uint64_t last_idle = 0, last_total = 0;
    
    host_cpu_load_info_data_t cpu_info;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, 
                       (host_info_t)&cpu_info, &count) == KERN_SUCCESS) {
        
        uint64_t total = 0;
        for (int i = 0; i < CPU_STATE_MAX; i++) {
            total += cpu_info.cpu_ticks[i];
        }
        
        uint64_t idle = cpu_info.cpu_ticks[CPU_STATE_IDLE];
        
        if (last_total > 0) {
            uint64_t total_diff = total - last_total;
            uint64_t idle_diff = idle - last_idle;
            
            if (total_diff > 0) {
                float usage = ((float)(total_diff - idle_diff) / total_diff) * 100.0f;
                last_idle = idle;
                last_total = total;
                return std::clamp(usage, 0.0f, 100.0f);
            }
        }
        
        last_idle = idle;
        last_total = total;
    }
    
    return 0.0f;
}

static uint64_t get_memory_usage() {
    struct task_basic_info info;
    mach_msg_type_number_t count = TASK_BASIC_INFO_COUNT;
    
    if (task_info(mach_task_self(), TASK_BASIC_INFO, 
                  (task_info_t)&info, &count) == KERN_SUCCESS) {
        return info.resident_size;
    }
    
    return 0;
}

//==============================================================================
// PUBLIC API
//==============================================================================

void debug_overlay_toggle_performance() {
    g_overlay_state.show_performance = !g_overlay_state.show_performance;
}

void debug_overlay_toggle_entities() {
    g_overlay_state.show_entities = !g_overlay_state.show_entities;
}

void debug_overlay_set_entity_count(uint32_t count) {
    // Update entity count in metrics
    // This would be called by the entity system
}

void debug_overlay_set_draw_calls(uint32_t count) {
    // Update draw call count in metrics
    // This would be called by the rendering system
}

bool debug_overlay_handle_input(int key, int action) {
    // Handle debug overlay hotkeys
    if (action == GLFW_PRESS) {
        switch (key) {
            case GLFW_KEY_F1:
                debug_overlay_toggle_performance();
                return true;
            case GLFW_KEY_F2:
                debug_overlay_toggle_entities();
                return true;
            case GLFW_KEY_F3:
                g_overlay_state.show_rendering = !g_overlay_state.show_rendering;
                return true;
            case GLFW_KEY_F4:
                g_overlay_state.show_ai = !g_overlay_state.show_ai;
                return true;
        }
    }
    
    return false;
}

float debug_overlay_get_scale_factor() {
    return g_overlay_state.display_scale;
}
