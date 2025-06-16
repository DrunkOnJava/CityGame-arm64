// SimCity ARM64 Debug Overlay System
// Agent 7: UI Systems & HUD
// ImGui integration with retina display support and Metal backend

#ifndef DEBUG_OVERLAY_H
#define DEBUG_OVERLAY_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Forward declarations for Objective-C types
#ifdef __OBJC__
@protocol MTLDevice;
@protocol MTLCommandQueue;
@protocol MTLRenderCommandEncoder;
#else
typedef struct objc_object* id;
#endif

// Forward declaration for GLFW
struct GLFWwindow;

//==============================================================================
// DEBUG OVERLAY API
//==============================================================================

/**
 * Initialize the debug overlay system
 * @param window GLFW window handle
 * @param device Metal device
 * @param queue Metal command queue
 * @return 0 on success, -1 on failure
 */
int debug_overlay_init(struct GLFWwindow* window, id device, id queue);

/**
 * Shutdown the debug overlay system
 */
void debug_overlay_shutdown(void);

/**
 * Begin a new frame for the debug overlay
 * Call this at the start of your render loop
 */
void debug_overlay_new_frame(void);

/**
 * Render the debug overlay
 * @param encoder Metal render command encoder (can be NULL)
 */
void debug_overlay_render(id encoder);

/**
 * Toggle performance window visibility
 */
void debug_overlay_toggle_performance(void);

/**
 * Toggle entities window visibility
 */
void debug_overlay_toggle_entities(void);

/**
 * Handle keyboard input for debug overlay hotkeys
 * @param key GLFW key code
 * @param action GLFW action (press/release)
 * @return true if input was handled, false otherwise
 */
bool debug_overlay_handle_input(int key, int action);

/**
 * Get the current display scale factor for retina displays
 * @return Scale factor (1.0 for standard displays, 2.0+ for retina)
 */
float debug_overlay_get_scale_factor(void);

//==============================================================================
// SYSTEM INTEGRATION API
//==============================================================================

/**
 * Update entity count display
 * @param count Current number of active entities
 */
void debug_overlay_set_entity_count(uint32_t count);

/**
 * Update draw call count display
 * @param count Number of draw calls in current frame
 */
void debug_overlay_set_draw_calls(uint32_t count);

/**
 * Update pathfinding statistics
 * @param active_paths Number of active pathfinding requests
 * @param completed_paths Number of completed paths this frame
 */
void debug_overlay_set_pathfinding_stats(uint32_t active_paths, uint32_t completed_paths);

/**
 * Update AI system statistics
 * @param behavior_trees Number of active behavior trees
 * @param decisions_per_second Number of AI decisions per second
 */
void debug_overlay_set_ai_stats(uint32_t behavior_trees, uint32_t decisions_per_second);

/**
 * Update networking statistics
 * @param connections Number of active network connections
 * @param messages_per_second Number of messages processed per second
 * @param bandwidth_kbps Current bandwidth usage in KB/s
 */
void debug_overlay_set_network_stats(uint32_t connections, uint32_t messages_per_second, float bandwidth_kbps);

/**
 * Update memory usage statistics
 * @param entity_memory Memory used by entity system in bytes
 * @param rendering_memory Memory used by rendering system in bytes
 * @param ai_memory Memory used by AI system in bytes
 * @param audio_memory Memory used by audio system in bytes
 */
void debug_overlay_set_memory_stats(uint64_t entity_memory, uint64_t rendering_memory, 
                                   uint64_t ai_memory, uint64_t audio_memory);

/**
 * Update DevActor status
 * @param actor_id DevActor ID (0-9)
 * @param status Status string ("HEALTHY", "BUSY", "ERROR", etc.)
 * @param messages_processed Number of messages processed by this actor
 */
void debug_overlay_set_devactor_status(uint32_t actor_id, const char* status, uint64_t messages_processed);

//==============================================================================
// CONVENIENCE MACROS
//==============================================================================

// Hotkey definitions (GLFW key codes)
#define DEBUG_OVERLAY_KEY_PERFORMANCE 290  // F1
#define DEBUG_OVERLAY_KEY_ENTITIES    291  // F2  
#define DEBUG_OVERLAY_KEY_RENDERING   292  // F3
#define DEBUG_OVERLAY_KEY_AI          293  // F4
#define DEBUG_OVERLAY_KEY_NETWORKING  294  // F5
#define DEBUG_OVERLAY_KEY_MEMORY      295  // F6
#define DEBUG_OVERLAY_KEY_DEVACTORS   296  // F7

// Macro to easily add debug overlay integration to systems
#define DEBUG_OVERLAY_FRAME_BEGIN() debug_overlay_new_frame()
#define DEBUG_OVERLAY_FRAME_END(encoder) debug_overlay_render(encoder)

// Macro for updating stats (no-op if debug overlay is disabled)
#ifdef DEBUG_OVERLAY_ENABLED
#define DEBUG_OVERLAY_UPDATE_ENTITIES(count) debug_overlay_set_entity_count(count)
#define DEBUG_OVERLAY_UPDATE_DRAW_CALLS(count) debug_overlay_set_draw_calls(count)
#define DEBUG_OVERLAY_UPDATE_AI_STATS(bt, dps) debug_overlay_set_ai_stats(bt, dps)
#else
#define DEBUG_OVERLAY_UPDATE_ENTITIES(count) ((void)0)
#define DEBUG_OVERLAY_UPDATE_DRAW_CALLS(count) ((void)0)
#define DEBUG_OVERLAY_UPDATE_AI_STATS(bt, dps) ((void)0)
#endif

#ifdef __cplusplus
}
#endif

#endif // DEBUG_OVERLAY_H