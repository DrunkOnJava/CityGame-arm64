/*
 * SimCity ARM64 - HMR Visual Feedback Header
 * On-screen notifications and visual feedback for HMR events
 * 
 * Agent 4: Developer Tools & Debug Interface
 * Day 4: Visual Feedback System API
 */

#ifndef HMR_VISUAL_FEEDBACK_H
#define HMR_VISUAL_FEEDBACK_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Configuration constants
#define HMR_MAX_RENDER_NOTIFICATIONS 16

// Render data structures for graphics system integration

// Notification data for rendering
typedef struct {
    int type;                       // Notification type (maps to styling)
    float position_x, position_y;   // Screen position
    float width, height;            // Notification dimensions
    float alpha;                    // Transparency (0.0 to 1.0)
    
    char title[128];                // Notification title
    char message[256];              // Main message
    char details[512];              // Additional details
    char icon[8];                   // Unicode icon
    
    float background_color[4];      // RGBA background color
    float border_color[4];          // RGBA border color
    float text_color[4];            // RGBA text color
} hmr_render_notification_t;

// Performance overlay data for rendering
typedef struct {
    bool show_fps;
    bool show_memory;
    bool show_build_status;
    bool show_module_count;
    float alpha;
    
    // Current values
    float current_fps;
    float memory_usage_mb;
    uint32_t active_modules;
    
    // Build status
    bool build_in_progress;
    float build_progress;           // 0.0 to 1.0
    char current_module[64];
} hmr_render_overlay_t;

// Complete render data package
typedef struct {
    uint32_t screen_width;
    uint32_t screen_height;
    
    // Notifications
    hmr_render_notification_t notifications[HMR_MAX_RENDER_NOTIFICATIONS];
    uint32_t notification_count;
    
    // Performance overlay
    bool overlay_enabled;
    hmr_render_overlay_t overlay;
} hmr_render_data_t;

// System lifecycle
int hmr_visual_feedback_init(uint32_t screen_width, uint32_t screen_height);
void hmr_visual_feedback_shutdown(void);
void hmr_visual_feedback_update(float delta_time);

// Screen management
void hmr_visual_feedback_set_screen_size(uint32_t width, uint32_t height);

// Notification functions
void hmr_visual_notify_build_start(const char* module_name);
void hmr_visual_notify_build_success(const char* module_name, uint64_t build_time_ms);
void hmr_visual_notify_build_error(const char* module_name, const char* error_message);
void hmr_visual_notify_module_reload(const char* module_name, bool success);
void hmr_visual_notify_performance_warning(const char* warning_message);
void hmr_visual_notify_info(const char* title, const char* message);

// Overlay control
void hmr_visual_feedback_enable_overlay(bool enable);
void hmr_visual_feedback_set_overlay_components(bool fps, bool memory, bool build_status, bool module_count);

// System control
void hmr_visual_feedback_enable(bool enable);

// Render data access (for graphics system)
int hmr_visual_feedback_get_render_data(hmr_render_data_t* render_data);

// Utility functions for graphics integration
static inline void hmr_visual_apply_alpha(float* color, float alpha) {
    color[3] *= alpha;
}

static inline bool hmr_visual_is_point_in_rect(float x, float y, float rect_x, float rect_y, float rect_w, float rect_h) {
    return x >= rect_x && x <= rect_x + rect_w && y >= rect_y && y <= rect_y + rect_h;
}

#ifdef __cplusplus
}
#endif

#endif // HMR_VISUAL_FEEDBACK_H