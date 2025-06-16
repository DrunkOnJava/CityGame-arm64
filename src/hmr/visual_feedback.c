/*
 * SimCity ARM64 - HMR Visual Feedback System
 * On-screen notifications and visual feedback for HMR events
 * 
 * Agent 4: Developer Tools & Debug Interface
 * Day 4: Visual Feedback System Implementation
 */

#include "visual_feedback.h"
#include "metrics.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <pthread.h>

// Visual feedback configuration
#define HMR_MAX_NOTIFICATIONS    16
#define HMR_NOTIFICATION_DURATION_MS 5000
#define HMR_ANIMATION_DURATION_MS    300
#define HMR_OVERLAY_PADDING         20
#define HMR_NOTIFICATION_HEIGHT     60
#define HMR_NOTIFICATION_WIDTH      400

// Notification types with visual styling
typedef enum {
    HMR_NOTIF_BUILD_START,
    HMR_NOTIF_BUILD_SUCCESS,
    HMR_NOTIF_BUILD_ERROR,
    HMR_NOTIF_MODULE_RELOAD,
    HMR_NOTIF_MODULE_ERROR,
    HMR_NOTIF_PERFORMANCE_WARNING,
    HMR_NOTIF_INFO
} hmr_notification_type_t;

// Visual styling for different notification types
typedef struct {
    float background_color[4];  // RGBA
    float border_color[4];      // RGBA
    float text_color[4];        // RGBA
    const char* icon;           // Unicode icon
} hmr_notification_style_t;

// Individual notification state
typedef struct {
    bool active;
    hmr_notification_type_t type;
    char title[128];
    char message[256];
    char details[512];
    uint64_t creation_time;
    uint64_t show_duration_ms;
    float animation_progress;   // 0.0 to 1.0
    float position_y;          // Animated position
    float target_y;            // Target position
    int index;                 // Display order
} hmr_notification_t;

// Performance overlay state
typedef struct {
    bool enabled;
    bool show_fps;
    bool show_memory;
    bool show_build_status;
    bool show_module_count;
    float overlay_alpha;
    uint32_t update_interval_ms;
    uint64_t last_update;
} hmr_performance_overlay_t;

// Build status visualization
typedef struct {
    bool show_progress;
    float progress_value;       // 0.0 to 1.0
    char current_module[64];
    uint64_t build_start_time;
    bool build_in_progress;
} hmr_build_visualization_t;

// Global visual feedback state
typedef struct {
    bool initialized;
    bool enabled;
    pthread_mutex_t mutex;
    
    // Screen dimensions (set by graphics system)
    uint32_t screen_width;
    uint32_t screen_height;
    
    // Notifications
    hmr_notification_t notifications[HMR_MAX_NOTIFICATIONS];
    uint32_t notification_count;
    uint32_t next_notification_index;
    
    // Performance overlay
    hmr_performance_overlay_t overlay;
    
    // Build visualization
    hmr_build_visualization_t build_viz;
    
    // Animation timing
    uint64_t last_frame_time;
    
    // Style definitions
    hmr_notification_style_t styles[8];
    
} hmr_visual_feedback_t;

static hmr_visual_feedback_t g_visual_feedback = {0};

// Style definitions for different notification types
static void hmr_init_notification_styles(void) {
    // Build start - Blue
    g_visual_feedback.styles[HMR_NOTIF_BUILD_START] = (hmr_notification_style_t){
        .background_color = {0.09f, 0.28f, 0.91f, 0.9f},  // Blue
        .border_color = {0.37f, 0.51f, 0.96f, 1.0f},
        .text_color = {1.0f, 1.0f, 1.0f, 1.0f},
        .icon = "🔨"
    };
    
    // Build success - Green
    g_visual_feedback.styles[HMR_NOTIF_BUILD_SUCCESS] = (hmr_notification_style_t){
        .background_color = {0.06f, 0.72f, 0.51f, 0.9f},  // Green
        .border_color = {0.34f, 0.8f, 0.61f, 1.0f},
        .text_color = {1.0f, 1.0f, 1.0f, 1.0f},
        .icon = "✅"
    };
    
    // Build error - Red
    g_visual_feedback.styles[HMR_NOTIF_BUILD_ERROR] = (hmr_notification_style_t){
        .background_color = {0.94f, 0.27f, 0.27f, 0.9f},  // Red
        .border_color = {0.96f, 0.4f, 0.4f, 1.0f},
        .text_color = {1.0f, 1.0f, 1.0f, 1.0f},
        .icon = "❌"
    };
    
    // Module reload - Purple
    g_visual_feedback.styles[HMR_NOTIF_MODULE_RELOAD] = (hmr_notification_style_t){
        .background_color = {0.55f, 0.27f, 0.91f, 0.9f},  // Purple
        .border_color = {0.67f, 0.4f, 0.96f, 1.0f},
        .text_color = {1.0f, 1.0f, 1.0f, 1.0f},
        .icon = "🔄"
    };
    
    // Module error - Orange
    g_visual_feedback.styles[HMR_NOTIF_MODULE_ERROR] = (hmr_notification_style_t){
        .background_color = {0.96f, 0.62f, 0.07f, 0.9f},  // Orange
        .border_color = {0.98f, 0.7f, 0.25f, 1.0f},
        .text_color = {1.0f, 1.0f, 1.0f, 1.0f},
        .icon = "⚠️"
    };
    
    // Performance warning - Yellow
    g_visual_feedback.styles[HMR_NOTIF_PERFORMANCE_WARNING] = (hmr_notification_style_t){
        .background_color = {0.91f, 0.78f, 0.04f, 0.9f},  // Yellow
        .border_color = {0.96f, 0.84f, 0.22f, 1.0f},
        .text_color = {0.0f, 0.0f, 0.0f, 1.0f},
        .icon = "⚡"
    };
    
    // Info - Gray
    g_visual_feedback.styles[HMR_NOTIF_INFO] = (hmr_notification_style_t){
        .background_color = {0.41f, 0.47f, 0.56f, 0.9f},  // Gray
        .border_color = {0.56f, 0.64f, 0.75f, 1.0f},
        .text_color = {1.0f, 1.0f, 1.0f, 1.0f},
        .icon = "ℹ️"
    };
}

// High-resolution timing
static uint64_t hmr_get_time_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)(ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
}

// Initialize visual feedback system
int hmr_visual_feedback_init(uint32_t screen_width, uint32_t screen_height) {
    if (g_visual_feedback.initialized) {
        return HMR_SUCCESS;
    }
    
    // Initialize mutex
    if (pthread_mutex_init(&g_visual_feedback.mutex, NULL) != 0) {
        printf("[HMR Visual] Failed to initialize mutex\n");
        return HMR_ERROR_THREADING;
    }
    
    // Initialize state
    memset(&g_visual_feedback, 0, sizeof(hmr_visual_feedback_t));
    g_visual_feedback.screen_width = screen_width;
    g_visual_feedback.screen_height = screen_height;
    g_visual_feedback.initialized = true;
    g_visual_feedback.enabled = true;
    
    // Initialize performance overlay
    g_visual_feedback.overlay.enabled = true;
    g_visual_feedback.overlay.show_fps = true;
    g_visual_feedback.overlay.show_memory = true;
    g_visual_feedback.overlay.show_build_status = true;
    g_visual_feedback.overlay.show_module_count = true;
    g_visual_feedback.overlay.overlay_alpha = 0.8f;
    g_visual_feedback.overlay.update_interval_ms = 100;
    
    // Initialize notification styles
    hmr_init_notification_styles();
    
    // Initialize all notifications as inactive
    for (int i = 0; i < HMR_MAX_NOTIFICATIONS; i++) {
        g_visual_feedback.notifications[i].active = false;
        g_visual_feedback.notifications[i].animation_progress = 0.0f;
    }
    
    g_visual_feedback.last_frame_time = hmr_get_time_ms();
    
    printf("[HMR Visual] Visual feedback system initialized (%ux%u)\n", screen_width, screen_height);
    return HMR_SUCCESS;
}

// Shutdown visual feedback system
void hmr_visual_feedback_shutdown(void) {
    if (!g_visual_feedback.initialized) {
        return;
    }
    
    pthread_mutex_destroy(&g_visual_feedback.mutex);
    memset(&g_visual_feedback, 0, sizeof(hmr_visual_feedback_t));
    
    printf("[HMR Visual] Visual feedback system shutdown\n");
}

// Update screen dimensions (called when window resizes)
void hmr_visual_feedback_set_screen_size(uint32_t width, uint32_t height) {
    if (!g_visual_feedback.initialized) {
        return;
    }
    
    pthread_mutex_lock(&g_visual_feedback.mutex);
    g_visual_feedback.screen_width = width;
    g_visual_feedback.screen_height = height;
    pthread_mutex_unlock(&g_visual_feedback.mutex);
}

// Add a new notification
static int hmr_add_notification(hmr_notification_type_t type, const char* title, const char* message, const char* details) {
    if (!g_visual_feedback.initialized || !g_visual_feedback.enabled) {
        return HMR_ERROR_NOT_FOUND;
    }
    
    pthread_mutex_lock(&g_visual_feedback.mutex);
    
    // Find available slot
    int slot = -1;
    for (int i = 0; i < HMR_MAX_NOTIFICATIONS; i++) {
        if (!g_visual_feedback.notifications[i].active) {
            slot = i;
            break;
        }
    }
    
    // If no slot available, replace oldest
    if (slot == -1) {
        uint64_t oldest_time = UINT64_MAX;
        for (int i = 0; i < HMR_MAX_NOTIFICATIONS; i++) {
            if (g_visual_feedback.notifications[i].creation_time < oldest_time) {
                oldest_time = g_visual_feedback.notifications[i].creation_time;
                slot = i;
            }
        }
    }
    
    if (slot == -1) {
        pthread_mutex_unlock(&g_visual_feedback.mutex);
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    // Initialize notification
    hmr_notification_t* notif = &g_visual_feedback.notifications[slot];
    memset(notif, 0, sizeof(hmr_notification_t));
    
    notif->active = true;
    notif->type = type;
    notif->creation_time = hmr_get_time_ms();
    notif->show_duration_ms = HMR_NOTIFICATION_DURATION_MS;
    notif->animation_progress = 0.0f;
    notif->index = g_visual_feedback.notification_count;
    
    // Copy strings safely
    if (title) {
        strncpy(notif->title, title, sizeof(notif->title) - 1);
    }
    if (message) {
        strncpy(notif->message, message, sizeof(notif->message) - 1);
    }
    if (details) {
        strncpy(notif->details, details, sizeof(notif->details) - 1);
    }
    
    // Calculate target position
    notif->target_y = HMR_OVERLAY_PADDING + (notif->index * (HMR_NOTIFICATION_HEIGHT + 10));
    notif->position_y = -HMR_NOTIFICATION_HEIGHT; // Start off-screen
    
    g_visual_feedback.notification_count++;
    
    pthread_mutex_unlock(&g_visual_feedback.mutex);
    
    printf("[HMR Visual] Added notification: %s - %s\n", title ? title : "Untitled", message ? message : "");
    return HMR_SUCCESS;
}

// Update notification animations
void hmr_visual_feedback_update(float delta_time) {
    if (!g_visual_feedback.initialized || !g_visual_feedback.enabled) {
        return;
    }
    
    uint64_t current_time = hmr_get_time_ms();
    
    pthread_mutex_lock(&g_visual_feedback.mutex);
    
    // Update all active notifications
    for (int i = 0; i < HMR_MAX_NOTIFICATIONS; i++) {
        hmr_notification_t* notif = &g_visual_feedback.notifications[i];
        
        if (!notif->active) {
            continue;
        }
        
        uint64_t age = current_time - notif->creation_time;
        
        // Check if notification should expire
        if (age > notif->show_duration_ms) {
            notif->active = false;
            g_visual_feedback.notification_count--;
            continue;
        }
        
        // Update animation progress
        if (age < HMR_ANIMATION_DURATION_MS) {
            // Slide in animation
            notif->animation_progress = (float)age / HMR_ANIMATION_DURATION_MS;
            
            // Ease-out animation curve
            float t = notif->animation_progress;
            float eased_t = 1.0f - (1.0f - t) * (1.0f - t);
            
            notif->position_y = -HMR_NOTIFICATION_HEIGHT + 
                               (notif->target_y + HMR_NOTIFICATION_HEIGHT) * eased_t;
        } else if (age > notif->show_duration_ms - HMR_ANIMATION_DURATION_MS) {
            // Slide out animation
            uint64_t fade_time = age - (notif->show_duration_ms - HMR_ANIMATION_DURATION_MS);
            float fade_progress = (float)fade_time / HMR_ANIMATION_DURATION_MS;
            
            // Ease-in animation curve
            float t = fade_progress;
            float eased_t = t * t;
            
            notif->position_y = notif->target_y - 
                               (notif->target_y + HMR_NOTIFICATION_HEIGHT) * eased_t;
            notif->animation_progress = 1.0f - fade_progress;
        } else {
            // Fully visible
            notif->position_y = notif->target_y;
            notif->animation_progress = 1.0f;
        }
    }
    
    // Update build visualization
    if (g_visual_feedback.build_viz.build_in_progress) {
        uint64_t build_duration = current_time - g_visual_feedback.build_viz.build_start_time;
        // Simulate build progress (in real implementation, this would come from actual build system)
        g_visual_feedback.build_viz.progress_value = fminf(1.0f, build_duration / 10000.0f); // 10 second max
    }
    
    g_visual_feedback.last_frame_time = current_time;
    
    pthread_mutex_unlock(&g_visual_feedback.mutex);
}

// Public notification functions

void hmr_visual_notify_build_start(const char* module_name) {
    char title[128];
    char message[256];
    
    snprintf(title, sizeof(title), "Build Started");
    if (module_name) {
        snprintf(message, sizeof(message), "Building module: %s", module_name);
    } else {
        snprintf(message, sizeof(message), "Building all modules");
    }
    
    hmr_add_notification(HMR_NOTIF_BUILD_START, title, message, NULL);
    
    // Update build visualization
    pthread_mutex_lock(&g_visual_feedback.mutex);
    g_visual_feedback.build_viz.build_in_progress = true;
    g_visual_feedback.build_viz.build_start_time = hmr_get_time_ms();
    g_visual_feedback.build_viz.progress_value = 0.0f;
    if (module_name) {
        strncpy(g_visual_feedback.build_viz.current_module, module_name, 
                sizeof(g_visual_feedback.build_viz.current_module) - 1);
    }
    pthread_mutex_unlock(&g_visual_feedback.mutex);
}

void hmr_visual_notify_build_success(const char* module_name, uint64_t build_time_ms) {
    char title[128];
    char message[256];
    char details[512];
    
    snprintf(title, sizeof(title), "Build Successful");
    if (module_name) {
        snprintf(message, sizeof(message), "Module %s built successfully", module_name);
    } else {
        snprintf(message, sizeof(message), "All modules built successfully");
    }
    snprintf(details, sizeof(details), "Build time: %llu ms", build_time_ms);
    
    hmr_add_notification(HMR_NOTIF_BUILD_SUCCESS, title, message, details);
    
    // Update build visualization
    pthread_mutex_lock(&g_visual_feedback.mutex);
    g_visual_feedback.build_viz.build_in_progress = false;
    g_visual_feedback.build_viz.progress_value = 1.0f;
    pthread_mutex_unlock(&g_visual_feedback.mutex);
}

void hmr_visual_notify_build_error(const char* module_name, const char* error_message) {
    char title[128];
    char message[256];
    
    snprintf(title, sizeof(title), "Build Error");
    if (module_name) {
        snprintf(message, sizeof(message), "Failed to build module: %s", module_name);
    } else {
        snprintf(message, sizeof(message), "Build failed");
    }
    
    hmr_add_notification(HMR_NOTIF_BUILD_ERROR, title, message, error_message);
    
    // Update build visualization
    pthread_mutex_lock(&g_visual_feedback.mutex);
    g_visual_feedback.build_viz.build_in_progress = false;
    pthread_mutex_unlock(&g_visual_feedback.mutex);
}

void hmr_visual_notify_module_reload(const char* module_name, bool success) {
    char title[128];
    char message[256];
    
    if (success) {
        snprintf(title, sizeof(title), "Module Reloaded");
        snprintf(message, sizeof(message), "Hot reload successful: %s", module_name ? module_name : "unknown");
        hmr_add_notification(HMR_NOTIF_MODULE_RELOAD, title, message, NULL);
    } else {
        snprintf(title, sizeof(title), "Reload Failed");
        snprintf(message, sizeof(message), "Hot reload failed: %s", module_name ? module_name : "unknown");
        hmr_add_notification(HMR_NOTIF_MODULE_ERROR, title, message, NULL);
    }
}

void hmr_visual_notify_performance_warning(const char* warning_message) {
    hmr_add_notification(HMR_NOTIF_PERFORMANCE_WARNING, "Performance Warning", warning_message, NULL);
}

void hmr_visual_notify_info(const char* title, const char* message) {
    hmr_add_notification(HMR_NOTIF_INFO, title, message, NULL);
}

// Performance overlay control
void hmr_visual_feedback_enable_overlay(bool enable) {
    if (!g_visual_feedback.initialized) {
        return;
    }
    
    pthread_mutex_lock(&g_visual_feedback.mutex);
    g_visual_feedback.overlay.enabled = enable;
    pthread_mutex_unlock(&g_visual_feedback.mutex);
}

void hmr_visual_feedback_set_overlay_components(bool fps, bool memory, bool build_status, bool module_count) {
    if (!g_visual_feedback.initialized) {
        return;
    }
    
    pthread_mutex_lock(&g_visual_feedback.mutex);
    g_visual_feedback.overlay.show_fps = fps;
    g_visual_feedback.overlay.show_memory = memory;
    g_visual_feedback.overlay.show_build_status = build_status;
    g_visual_feedback.overlay.show_module_count = module_count;
    pthread_mutex_unlock(&g_visual_feedback.mutex);
}

// Enable/disable visual feedback
void hmr_visual_feedback_enable(bool enable) {
    if (!g_visual_feedback.initialized) {
        return;
    }
    
    pthread_mutex_lock(&g_visual_feedback.mutex);
    g_visual_feedback.enabled = enable;
    pthread_mutex_unlock(&g_visual_feedback.mutex);
}

// Get current visual state for rendering
int hmr_visual_feedback_get_render_data(hmr_render_data_t* render_data) {
    if (!g_visual_feedback.initialized || !g_visual_feedback.enabled || !render_data) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    pthread_mutex_lock(&g_visual_feedback.mutex);
    
    memset(render_data, 0, sizeof(hmr_render_data_t));
    render_data->screen_width = g_visual_feedback.screen_width;
    render_data->screen_height = g_visual_feedback.screen_height;
    render_data->overlay_enabled = g_visual_feedback.overlay.enabled;
    
    // Copy active notifications
    render_data->notification_count = 0;
    for (int i = 0; i < HMR_MAX_NOTIFICATIONS && render_data->notification_count < HMR_MAX_RENDER_NOTIFICATIONS; i++) {
        if (g_visual_feedback.notifications[i].active) {
            hmr_render_notification_t* render_notif = &render_data->notifications[render_data->notification_count];
            hmr_notification_t* notif = &g_visual_feedback.notifications[i];
            
            render_notif->type = notif->type;
            render_notif->position_x = g_visual_feedback.screen_width - HMR_NOTIFICATION_WIDTH - HMR_OVERLAY_PADDING;
            render_notif->position_y = notif->position_y;
            render_notif->width = HMR_NOTIFICATION_WIDTH;
            render_notif->height = HMR_NOTIFICATION_HEIGHT;
            render_notif->alpha = notif->animation_progress;
            
            strncpy(render_notif->title, notif->title, sizeof(render_notif->title) - 1);
            strncpy(render_notif->message, notif->message, sizeof(render_notif->message) - 1);
            strncpy(render_notif->details, notif->details, sizeof(render_notif->details) - 1);
            
            // Copy style
            hmr_notification_style_t* style = &g_visual_feedback.styles[notif->type];
            memcpy(render_notif->background_color, style->background_color, sizeof(render_notif->background_color));
            memcpy(render_notif->border_color, style->border_color, sizeof(render_notif->border_color));
            memcpy(render_notif->text_color, style->text_color, sizeof(render_notif->text_color));
            strncpy(render_notif->icon, style->icon, sizeof(render_notif->icon) - 1);
            
            render_data->notification_count++;
        }
    }
    
    // Copy overlay data
    if (g_visual_feedback.overlay.enabled) {
        render_data->overlay.show_fps = g_visual_feedback.overlay.show_fps;
        render_data->overlay.show_memory = g_visual_feedback.overlay.show_memory;
        render_data->overlay.show_build_status = g_visual_feedback.overlay.show_build_status;
        render_data->overlay.show_module_count = g_visual_feedback.overlay.show_module_count;
        render_data->overlay.alpha = g_visual_feedback.overlay.overlay_alpha;
        
        // Get current metrics for overlay
        hmr_system_metrics_t metrics;
        hmr_metrics_get_system_metrics(&metrics);
        render_data->overlay.current_fps = metrics.current_fps;
        render_data->overlay.memory_usage_mb = metrics.memory_usage_bytes / (1024.0f * 1024.0f);
        render_data->overlay.active_modules = metrics.active_modules;
        
        // Build status
        render_data->overlay.build_in_progress = g_visual_feedback.build_viz.build_in_progress;
        render_data->overlay.build_progress = g_visual_feedback.build_viz.progress_value;
        strncpy(render_data->overlay.current_module, g_visual_feedback.build_viz.current_module,
                sizeof(render_data->overlay.current_module) - 1);
    }
    
    pthread_mutex_unlock(&g_visual_feedback.mutex);
    
    return HMR_SUCCESS;
}