/*
 * SimCity ARM64 - Collaborative Development Session Manager Header
 * Real-time collaborative coding and coordination features
 * 
 * Agent 4: Developer Tools & Debug Interface
 * Day 6: Enhanced Collaborative Development Features
 */

#ifndef HMR_COLLABORATIVE_SESSION_H
#define HMR_COLLABORATIVE_SESSION_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

// Error codes (assuming these are defined in module_interface.h)
#ifndef HMR_SUCCESS
#define HMR_SUCCESS 0
#define HMR_ERROR_THREADING 1
#define HMR_ERROR_NOT_FOUND 2
#define HMR_ERROR_OUT_OF_MEMORY 3
#define HMR_ERROR_INVALID_ARG 4
#endif

// Collaborative system lifecycle
int hmr_collaborative_init(void);
void hmr_collaborative_shutdown(void);

// Developer management
int hmr_register_developer(const char* display_name, const char* email, char* developer_id_out);
int hmr_update_developer_status(const char* developer_id, const char* status);
int hmr_set_developer_avatar(const char* developer_id, const char* avatar_url);

// Session management
int hmr_create_session(const char* session_name, const char* description, 
                      const char* leader_id, char* session_id_out);
int hmr_join_session(const char* session_id, const char* developer_id);
int hmr_leave_session(const char* session_id, const char* developer_id);
int hmr_close_session(const char* session_id, const char* leader_id);

// Code collaboration
int hmr_track_code_change(const char* developer_id, const char* file_path,
                         uint32_t start_line, uint32_t start_column,
                         uint32_t end_line, uint32_t end_column,
                         const char* operation, const char* content);
int hmr_update_cursor_position(const char* developer_id, const char* file_path,
                              uint32_t line, uint32_t column);
int hmr_share_file(const char* session_id, const char* file_path, const char* developer_id);
int hmr_unshare_file(const char* session_id, const char* file_path, const char* developer_id);

// Communication
int hmr_send_chat_message(const char* developer_id, const char* content, const char* message_type);
int hmr_pin_chat_message(const char* message_id, const char* developer_id);
int hmr_send_code_review_comment(const char* developer_id, const char* file_path, 
                                uint32_t line_number, const char* comment);

// Conflict resolution
typedef struct {
    char conflict_id[64];
    char file_path[512];
    uint32_t line_number;
    char developer1_id[64];
    char developer2_id[64];
    char conflict_type[32];
    time_t detected_time;
    bool resolved;
} hmr_conflict_info_t;

int hmr_get_active_conflicts(hmr_conflict_info_t* conflicts, uint32_t max_conflicts, uint32_t* conflict_count);
int hmr_resolve_conflict(const char* conflict_id, const char* resolution_strategy, const char* resolver_id);

// State management
void hmr_get_collaborative_state(char* json_buffer, size_t max_len);
void hmr_get_session_participants(const char* session_id, char* participants_json, size_t max_len);
void hmr_get_recent_chat_messages(const char* session_id, char* messages_json, size_t max_len);

// Statistics and monitoring
typedef struct {
    uint32_t active_developers;
    uint32_t active_sessions;
    uint64_t total_code_changes;
    uint64_t total_chat_messages;
    uint64_t conflicts_resolved;
    uint64_t session_time_seconds;
    bool is_running;
} hmr_collaborative_stats_t;

void hmr_get_collaborative_stats(hmr_collaborative_stats_t* stats);

// Event callbacks
typedef void (*hmr_collaborative_event_callback_t)(const char* event_type, const char* event_data);
void hmr_set_collaborative_event_callback(hmr_collaborative_event_callback_t callback);

// Real-time presence
typedef struct {
    char developer_id[64];
    char display_name[128];
    char current_file[512];
    uint32_t cursor_line;
    uint32_t cursor_column;
    char status[64];
    char color[8];
    time_t last_activity;
} hmr_developer_presence_t;

int hmr_get_active_developers(hmr_developer_presence_t* developers, uint32_t max_developers, uint32_t* developer_count);
int hmr_get_file_collaborators(const char* file_path, hmr_developer_presence_t* collaborators, 
                              uint32_t max_collaborators, uint32_t* collaborator_count);

#ifdef __cplusplus
}
#endif

#endif // HMR_COLLABORATIVE_SESSION_H