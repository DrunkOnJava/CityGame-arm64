/*
 * SimCity ARM64 - Customizable Workspace Manager
 * Drag-and-drop workspace customization with layout persistence
 * 
 * Agent 4: Developer Tools & Debug Interface
 * Week 3 Day 11: Advanced UI Features & AI Integration
 */

#ifndef HMR_CUSTOMIZABLE_WORKSPACE_H
#define HMR_CUSTOMIZABLE_WORKSPACE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Panel Types
typedef enum {
    WORKSPACE_PANEL_CODE_EDITOR = 0,
    WORKSPACE_PANEL_FILE_EXPLORER,
    WORKSPACE_PANEL_TERMINAL,
    WORKSPACE_PANEL_PERFORMANCE_MONITOR,
    WORKSPACE_PANEL_BUILD_OUTPUT,
    WORKSPACE_PANEL_DEBUG_CONSOLE,
    WORKSPACE_PANEL_DEPENDENCY_GRAPH,
    WORKSPACE_PANEL_MEMORY_PROFILER,
    WORKSPACE_PANEL_ASSEMBLY_VIEWER,
    WORKSPACE_PANEL_DOCUMENTATION,
    WORKSPACE_PANEL_CHAT,
    WORKSPACE_PANEL_TASK_LIST,
    WORKSPACE_PANEL_GIT_STATUS,
    WORKSPACE_PANEL_SEARCH_RESULTS,
    WORKSPACE_PANEL_MINI_MAP,
    WORKSPACE_PANEL_CUSTOM_PLUGIN,
    WORKSPACE_PANEL_COUNT
} workspace_panel_type_t;

// Layout Types
typedef enum {
    WORKSPACE_LAYOUT_HORIZONTAL = 0,
    WORKSPACE_LAYOUT_VERTICAL,
    WORKSPACE_LAYOUT_GRID,
    WORKSPACE_LAYOUT_TABS,
    WORKSPACE_LAYOUT_FLOATING,
    WORKSPACE_LAYOUT_SPLIT_HORIZONTAL,
    WORKSPACE_LAYOUT_SPLIT_VERTICAL,
    WORKSPACE_LAYOUT_CUSTOM
} workspace_layout_type_t;

// Panel State
typedef enum {
    WORKSPACE_PANEL_VISIBLE = 0,
    WORKSPACE_PANEL_HIDDEN,
    WORKSPACE_PANEL_MINIMIZED,
    WORKSPACE_PANEL_MAXIMIZED,
    WORKSPACE_PANEL_FLOATING,
    WORKSPACE_PANEL_DOCKED
} workspace_panel_state_t;

// Theme Configuration
typedef enum {
    WORKSPACE_THEME_DARK = 0,
    WORKSPACE_THEME_LIGHT,
    WORKSPACE_THEME_HIGH_CONTRAST,
    WORKSPACE_THEME_CUSTOM,
    WORKSPACE_THEME_AUTO
} workspace_theme_t;

// Panel Configuration
typedef struct {
    char panel_id[64];
    workspace_panel_type_t type;
    char title[128];
    char icon_path[256];
    float x_position;           // 0.0 to 1.0 (relative to parent)
    float y_position;           // 0.0 to 1.0 (relative to parent)
    float width;                // 0.0 to 1.0 (relative to parent)
    float height;               // 0.0 to 1.0 (relative to parent)
    float min_width;
    float min_height;
    float max_width;
    float max_height;
    workspace_panel_state_t state;
    workspace_layout_type_t layout_type;
    bool is_resizable;
    bool is_draggable;
    bool is_closable;
    bool is_collapsible;
    bool is_dockable;
    bool is_floating;
    uint32_t z_index;
    char parent_panel_id[64];
    char css_class[128];
    char custom_properties[1024];
} workspace_panel_config_t;

// Workspace Layout
typedef struct {
    char layout_id[64];
    char layout_name[128];
    char description[256];
    workspace_theme_t theme;
    workspace_layout_type_t root_layout_type;
    uint32_t panel_count;
    workspace_panel_config_t panels[32];
    char custom_css[4096];
    char hotkeys[2048];
    bool is_default;
    bool is_locked;
    uint64_t last_modified_time;
    char author[128];
    char version[16];
} workspace_layout_t;

// Drag and Drop Configuration
typedef struct {
    char source_panel_id[64];
    char target_panel_id[64];
    float drop_x;
    float drop_y;
    bool is_valid_drop;
    bool create_new_container;
    workspace_layout_type_t target_layout_type;
    char preview_html[2048];
} workspace_drag_drop_t;

// Workspace Theme
typedef struct {
    char theme_name[64];
    char primary_color[8];
    char secondary_color[8];
    char accent_color[8];
    char background_color[8];
    char text_color[8];
    char border_color[8];
    char highlight_color[8];
    char error_color[8];
    char warning_color[8];
    char success_color[8];
    char font_family[128];
    uint32_t font_size;
    uint32_t line_height;
    float panel_opacity;
    uint32_t border_radius;
    uint32_t shadow_blur;
    char custom_css[4096];
} workspace_theme_config_t;

// Workspace Manager Functions
int32_t workspace_manager_init(const char* config_directory);
void workspace_manager_shutdown(void);

// Layout Management
int32_t workspace_create_layout(const char* layout_name, const char* description, char* layout_id);
int32_t workspace_load_layout(const char* layout_id);
int32_t workspace_save_layout(const char* layout_id);
int32_t workspace_delete_layout(const char* layout_id);
int32_t workspace_duplicate_layout(const char* source_layout_id, const char* new_name, char* new_layout_id);
int32_t workspace_set_default_layout(const char* layout_id);

// Panel Management
int32_t workspace_add_panel(workspace_panel_type_t type, const char* title, const char* parent_id, char* panel_id);
int32_t workspace_remove_panel(const char* panel_id);
int32_t workspace_move_panel(const char* panel_id, float x, float y);
int32_t workspace_resize_panel(const char* panel_id, float width, float height);
int32_t workspace_set_panel_state(const char* panel_id, workspace_panel_state_t state);
int32_t workspace_get_panel_config(const char* panel_id, workspace_panel_config_t* config);
int32_t workspace_update_panel_config(const char* panel_id, const workspace_panel_config_t* config);

// Drag and Drop
int32_t workspace_start_drag(const char* panel_id, float start_x, float start_y);
int32_t workspace_update_drag(float current_x, float current_y, workspace_drag_drop_t* drag_info);
int32_t workspace_complete_drop(const workspace_drag_drop_t* drag_info);
int32_t workspace_cancel_drag(void);

// Theme Management
int32_t workspace_set_theme(const workspace_theme_config_t* theme);
int32_t workspace_get_theme(workspace_theme_config_t* theme);
int32_t workspace_load_theme_from_file(const char* theme_file_path);
int32_t workspace_save_theme_to_file(const char* theme_file_path);

// Layout Serialization
int32_t workspace_export_layout(const char* layout_id, char* json_output, size_t max_length);
int32_t workspace_import_layout(const char* json_input, char* layout_id);

// Responsive Design
typedef struct {
    uint32_t screen_width;
    uint32_t screen_height;
    float dpi_scale;
    bool is_mobile;
    bool is_tablet;
    bool is_desktop;
    bool is_touch_enabled;
} workspace_screen_info_t;

int32_t workspace_update_screen_info(const workspace_screen_info_t* screen_info);
int32_t workspace_get_responsive_layout(const char* base_layout_id, const workspace_screen_info_t* screen_info, char* responsive_layout_id);

// Keyboard Shortcuts
typedef struct {
    char action_name[64];
    char key_combination[32];
    char description[128];
    bool is_global;
    bool is_enabled;
} workspace_hotkey_t;

int32_t workspace_register_hotkey(const workspace_hotkey_t* hotkey);
int32_t workspace_unregister_hotkey(const char* action_name);
int32_t workspace_get_hotkeys(workspace_hotkey_t* hotkeys, uint32_t max_hotkeys, uint32_t* hotkey_count);

// Workspace Templates
typedef struct {
    char template_id[64];
    char template_name[128];
    char description[256];
    char category[64];
    workspace_layout_t layout;
    char preview_image_path[256];
    uint32_t usage_count;
    float rating;
    bool is_built_in;
} workspace_template_t;

int32_t workspace_get_templates(workspace_template_t* templates, uint32_t max_templates, uint32_t* template_count);
int32_t workspace_create_from_template(const char* template_id, const char* layout_name, char* layout_id);
int32_t workspace_save_as_template(const char* layout_id, const char* template_name, const char* category);

// Auto-save and Recovery
int32_t workspace_enable_auto_save(bool enabled, uint32_t interval_seconds);
int32_t workspace_recover_layout(const char* layout_id);
int32_t workspace_get_recovery_layouts(char* layout_ids, uint32_t max_layouts, uint32_t* layout_count);

// Statistics and Analytics
typedef struct {
    uint32_t total_layouts_created;
    uint32_t total_panels_created;
    uint32_t total_drag_operations;
    uint32_t total_theme_changes;
    uint64_t total_usage_time_seconds;
    char most_used_panel_type[64];
    char most_used_layout[64];
    float average_panels_per_layout;
    uint32_t crash_recovery_count;
} workspace_usage_stats_t;

void workspace_get_usage_stats(workspace_usage_stats_t* stats);

// Event Callbacks
typedef enum {
    WORKSPACE_EVENT_LAYOUT_CHANGED = 0,
    WORKSPACE_EVENT_PANEL_ADDED,
    WORKSPACE_EVENT_PANEL_REMOVED,
    WORKSPACE_EVENT_PANEL_MOVED,
    WORKSPACE_EVENT_PANEL_RESIZED,
    WORKSPACE_EVENT_THEME_CHANGED,
    WORKSPACE_EVENT_DRAG_STARTED,
    WORKSPACE_EVENT_DRAG_COMPLETED,
    WORKSPACE_EVENT_LAYOUT_SAVED,
    WORKSPACE_EVENT_ERROR
} workspace_event_type_t;

typedef void (*workspace_event_callback_t)(workspace_event_type_t event_type, const char* event_data, void* user_data);
int32_t workspace_set_event_callback(workspace_event_callback_t callback, void* user_data);

// Workspace State
typedef struct {
    char active_layout_id[64];
    uint32_t panel_count;
    uint32_t visible_panel_count;
    workspace_theme_t current_theme;
    bool is_in_drag_mode;
    bool is_auto_save_enabled;
    uint32_t auto_save_interval;
    uint64_t last_save_time;
    bool has_unsaved_changes;
} workspace_state_t;

void workspace_get_state(workspace_state_t* state);

#ifdef __cplusplus
}
#endif

#endif // HMR_CUSTOMIZABLE_WORKSPACE_H