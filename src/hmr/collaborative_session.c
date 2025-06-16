/*
 * SimCity ARM64 - Collaborative Development Session Manager
 * Real-time collaborative coding and coordination features
 * 
 * Agent 4: Developer Tools & Debug Interface
 * Day 6: Enhanced Collaborative Development Features
 */

#include "collaborative_session.h"
#include "dev_server.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <pthread.h>
#include <uuid/uuid.h>

// Configuration
#define MAX_DEVELOPERS 16
#define MAX_ACTIVE_SESSIONS 64
#define MAX_CODE_CHANGES 1000
#define MAX_CHAT_MESSAGES 200
#define MAX_SHARED_CURSORS 32
#define SESSION_TIMEOUT_MINUTES 30
#define CONFLICT_RESOLUTION_BUFFER 512

// Developer information
typedef struct {
    char developer_id[64];
    char display_name[128];
    char email[256];
    char avatar_url[512];
    char current_file[512];
    uint32_t cursor_line;
    uint32_t cursor_column;
    time_t last_activity;
    bool active;
    char status[64]; // "coding", "reviewing", "debugging", "idle"
    char color[8]; // Hex color for UI
} hmr_developer_t;

// Code change tracking
typedef struct {
    char change_id[64];
    char developer_id[64];
    char file_path[512];
    uint32_t start_line;
    uint32_t start_column;
    uint32_t end_line;
    uint32_t end_column;
    char operation[16]; // "insert", "delete", "replace"
    char content[2048];
    time_t timestamp;
    bool applied;
    bool conflicted;
} hmr_code_change_t;

// Chat message
typedef struct {
    char message_id[64];
    char developer_id[64];
    char content[1024];
    char message_type[32]; // "text", "code_snippet", "file_reference", "system"
    time_t timestamp;
    bool pinned;
} hmr_chat_message_t;

// Collaborative session
typedef struct {
    char session_id[64];
    char session_name[128];
    char description[512];
    time_t created_time;
    time_t last_activity;
    uint32_t developer_count;
    char developers[MAX_DEVELOPERS][64]; // Developer IDs
    char shared_files[32][512]; // Currently shared files
    uint32_t shared_file_count;
    bool active;
    char session_leader[64]; // Developer ID
} hmr_session_t;

// Conflict resolution
typedef struct {
    char conflict_id[64];
    char file_path[512];
    uint32_t line_number;
    char developer1_id[64];
    char developer2_id[64];
    char conflict_type[32]; // "concurrent_edit", "merge_conflict", "access_conflict"
    time_t detected_time;
    bool resolved;
    char resolution_strategy[64]; // "merge", "overwrite", "manual"
} hmr_conflict_t;

// Main collaborative system state
typedef struct {
    hmr_developer_t developers[MAX_DEVELOPERS];
    hmr_session_t sessions[MAX_ACTIVE_SESSIONS];
    hmr_code_change_t code_changes[MAX_CODE_CHANGES];
    hmr_chat_message_t chat_messages[MAX_CHAT_MESSAGES];
    hmr_conflict_t conflicts[64];
    
    uint32_t developer_count;
    uint32_t session_count;
    uint32_t code_change_count;
    uint32_t chat_message_count;
    uint32_t conflict_count;
    
    char current_session_id[64];
    
    pthread_mutex_t collaborative_mutex;
    pthread_t sync_thread;
    bool running;
    
    // Statistics
    uint64_t total_code_changes;
    uint64_t total_chat_messages;
    uint64_t conflicts_resolved;
    uint64_t session_time_seconds;
    
} hmr_collaborative_system_t;

static hmr_collaborative_system_t g_collab = {0};

// Forward declarations
static void* hmr_collaborative_sync_thread(void* arg);
static void hmr_generate_unique_id(char* buffer, size_t buffer_size);
static void hmr_broadcast_collaborative_event(const char* event_type, const char* data);
static void hmr_detect_and_resolve_conflicts(void);
static void hmr_cleanup_inactive_sessions(void);
static void hmr_serialize_session_state(char* json_buffer, size_t max_len);
static const char* hmr_get_random_color(void);
static bool hmr_is_developer_in_session(const char* session_id, const char* developer_id);

// Initialize collaborative system
int hmr_collaborative_init(void) {
    if (g_collab.running) {
        printf("[HMR] Collaborative system already running\n");
        return HMR_SUCCESS;
    }
    
    // Initialize collaborative state
    memset(&g_collab, 0, sizeof(hmr_collaborative_system_t));
    
    // Initialize mutex
    if (pthread_mutex_init(&g_collab.collaborative_mutex, NULL) != 0) {
        printf("[HMR] Failed to initialize collaborative mutex\n");
        return HMR_ERROR_THREADING;
    }
    
    // Start sync thread
    g_collab.running = true;
    if (pthread_create(&g_collab.sync_thread, NULL, hmr_collaborative_sync_thread, NULL) != 0) {
        printf("[HMR] Failed to create collaborative sync thread\n");
        g_collab.running = false;
        pthread_mutex_destroy(&g_collab.collaborative_mutex);
        return HMR_ERROR_THREADING;
    }
    
    printf("[HMR] Collaborative development system initialized\n");
    return HMR_SUCCESS;
}

// Shutdown collaborative system
void hmr_collaborative_shutdown(void) {
    if (!g_collab.running) {
        return;
    }
    
    printf("[HMR] Shutting down collaborative system...\n");
    
    g_collab.running = false;
    pthread_join(g_collab.sync_thread, NULL);
    pthread_mutex_destroy(&g_collab.collaborative_mutex);
    
    printf("[HMR] Collaborative system statistics:\n");
    printf("  Total developers: %u\n", g_collab.developer_count);
    printf("  Total sessions: %u\n", g_collab.session_count);
    printf("  Code changes: %llu\n", g_collab.total_code_changes);
    printf("  Chat messages: %llu\n", g_collab.total_chat_messages);
    printf("  Conflicts resolved: %llu\n", g_collab.conflicts_resolved);
    
    printf("[HMR] Collaborative system shutdown complete\n");
}

// Register developer
int hmr_register_developer(const char* display_name, const char* email, char* developer_id_out) {
    if (!display_name || !email || !developer_id_out) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    pthread_mutex_lock(&g_collab.collaborative_mutex);
    
    if (g_collab.developer_count >= MAX_DEVELOPERS) {
        pthread_mutex_unlock(&g_collab.collaborative_mutex);
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    hmr_developer_t* dev = &g_collab.developers[g_collab.developer_count];
    memset(dev, 0, sizeof(hmr_developer_t));
    
    // Generate unique developer ID
    hmr_generate_unique_id(dev->developer_id, sizeof(dev->developer_id));
    strncpy(dev->display_name, display_name, sizeof(dev->display_name) - 1);
    strncpy(dev->email, email, sizeof(dev->email) - 1);
    strncpy(dev->status, "idle", sizeof(dev->status) - 1);
    strncpy(dev->color, hmr_get_random_color(), sizeof(dev->color) - 1);
    dev->last_activity = time(NULL);
    dev->active = true;
    
    strcpy(developer_id_out, dev->developer_id);
    g_collab.developer_count++;
    
    pthread_mutex_unlock(&g_collab.collaborative_mutex);
    
    printf("[HMR] Developer registered: %s (%s)\n", display_name, dev->developer_id);
    
    // Broadcast developer joined event
    char event_data[512];
    snprintf(event_data, sizeof(event_data),
        "{\"developer_id\":\"%s\",\"display_name\":\"%s\",\"color\":\"%s\"}",
        dev->developer_id, dev->display_name, dev->color);
    hmr_broadcast_collaborative_event("developer_joined", event_data);
    
    return HMR_SUCCESS;
}

// Create collaborative session
int hmr_create_session(const char* session_name, const char* description, 
                      const char* leader_id, char* session_id_out) {
    if (!session_name || !leader_id || !session_id_out) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    pthread_mutex_lock(&g_collab.collaborative_mutex);
    
    if (g_collab.session_count >= MAX_ACTIVE_SESSIONS) {
        pthread_mutex_unlock(&g_collab.collaborative_mutex);
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    hmr_session_t* session = &g_collab.sessions[g_collab.session_count];
    memset(session, 0, sizeof(hmr_session_t));
    
    // Generate unique session ID
    hmr_generate_unique_id(session->session_id, sizeof(session->session_id));
    strncpy(session->session_name, session_name, sizeof(session->session_name) - 1);
    if (description) {
        strncpy(session->description, description, sizeof(session->description) - 1);
    }
    strncpy(session->session_leader, leader_id, sizeof(session->session_leader) - 1);
    
    session->created_time = time(NULL);
    session->last_activity = time(NULL);
    session->active = true;
    
    // Add leader to session
    strncpy(session->developers[0], leader_id, sizeof(session->developers[0]) - 1);
    session->developer_count = 1;
    
    strcpy(session_id_out, session->session_id);
    g_collab.session_count++;
    
    pthread_mutex_unlock(&g_collab.collaborative_mutex);
    
    printf("[HMR] Collaborative session created: %s (%s)\n", session_name, session->session_id);
    
    // Broadcast session created event
    char event_data[512];
    snprintf(event_data, sizeof(event_data),
        "{\"session_id\":\"%s\",\"session_name\":\"%s\",\"leader_id\":\"%s\"}",
        session->session_id, session->session_name, leader_id);
    hmr_broadcast_collaborative_event("session_created", event_data);
    
    return HMR_SUCCESS;
}

// Join collaborative session
int hmr_join_session(const char* session_id, const char* developer_id) {
    if (!session_id || !developer_id) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    pthread_mutex_lock(&g_collab.collaborative_mutex);
    
    // Find session
    hmr_session_t* session = NULL;
    for (uint32_t i = 0; i < g_collab.session_count; i++) {
        if (strcmp(g_collab.sessions[i].session_id, session_id) == 0 && 
            g_collab.sessions[i].active) {
            session = &g_collab.sessions[i];
            break;
        }
    }
    
    if (!session) {
        pthread_mutex_unlock(&g_collab.collaborative_mutex);
        return HMR_ERROR_NOT_FOUND;
    }
    
    // Check if developer is already in session
    if (hmr_is_developer_in_session(session_id, developer_id)) {
        pthread_mutex_unlock(&g_collab.collaborative_mutex);
        return HMR_SUCCESS; // Already in session
    }
    
    // Add developer to session
    if (session->developer_count >= MAX_DEVELOPERS) {
        pthread_mutex_unlock(&g_collab.collaborative_mutex);
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    strncpy(session->developers[session->developer_count], developer_id, 
            sizeof(session->developers[0]) - 1);
    session->developer_count++;
    session->last_activity = time(NULL);
    
    pthread_mutex_unlock(&g_collab.collaborative_mutex);
    
    printf("[HMR] Developer %s joined session %s\n", developer_id, session_id);
    
    // Broadcast developer joined session event
    char event_data[512];
    snprintf(event_data, sizeof(event_data),
        "{\"session_id\":\"%s\",\"developer_id\":\"%s\"}",
        session_id, developer_id);
    hmr_broadcast_collaborative_event("developer_joined_session", event_data);
    
    return HMR_SUCCESS;
}

// Track code change
int hmr_track_code_change(const char* developer_id, const char* file_path,
                         uint32_t start_line, uint32_t start_column,
                         uint32_t end_line, uint32_t end_column,
                         const char* operation, const char* content) {
    if (!developer_id || !file_path || !operation) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    pthread_mutex_lock(&g_collab.collaborative_mutex);
    
    if (g_collab.code_change_count >= MAX_CODE_CHANGES) {
        // Remove oldest change to make room
        memmove(&g_collab.code_changes[0], &g_collab.code_changes[1],
                (MAX_CODE_CHANGES - 1) * sizeof(hmr_code_change_t));
        g_collab.code_change_count--;
    }
    
    hmr_code_change_t* change = &g_collab.code_changes[g_collab.code_change_count];
    memset(change, 0, sizeof(hmr_code_change_t));
    
    hmr_generate_unique_id(change->change_id, sizeof(change->change_id));
    strncpy(change->developer_id, developer_id, sizeof(change->developer_id) - 1);
    strncpy(change->file_path, file_path, sizeof(change->file_path) - 1);
    strncpy(change->operation, operation, sizeof(change->operation) - 1);
    if (content) {
        strncpy(change->content, content, sizeof(change->content) - 1);
    }
    
    change->start_line = start_line;
    change->start_column = start_column;
    change->end_line = end_line;
    change->end_column = end_column;
    change->timestamp = time(NULL);
    change->applied = true;
    
    g_collab.code_change_count++;
    g_collab.total_code_changes++;
    
    pthread_mutex_unlock(&g_collab.collaborative_mutex);
    
    // Broadcast code change event
    char event_data[1024];
    snprintf(event_data, sizeof(event_data),
        "{"
        "\"change_id\":\"%s\","
        "\"developer_id\":\"%s\","
        "\"file_path\":\"%s\","
        "\"operation\":\"%s\","
        "\"start_line\":%u,"
        "\"start_column\":%u,"
        "\"end_line\":%u,"
        "\"end_column\":%u"
        "}",
        change->change_id, change->developer_id, change->file_path,
        change->operation, change->start_line, change->start_column,
        change->end_line, change->end_column);
    hmr_broadcast_collaborative_event("code_change", event_data);
    
    return HMR_SUCCESS;
}

// Update developer cursor position
int hmr_update_cursor_position(const char* developer_id, const char* file_path,
                              uint32_t line, uint32_t column) {
    if (!developer_id || !file_path) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    pthread_mutex_lock(&g_collab.collaborative_mutex);
    
    // Find developer
    hmr_developer_t* developer = NULL;
    for (uint32_t i = 0; i < g_collab.developer_count; i++) {
        if (strcmp(g_collab.developers[i].developer_id, developer_id) == 0) {
            developer = &g_collab.developers[i];
            break;
        }
    }
    
    if (developer) {
        strncpy(developer->current_file, file_path, sizeof(developer->current_file) - 1);
        developer->cursor_line = line;
        developer->cursor_column = column;
        developer->last_activity = time(NULL);
    }
    
    pthread_mutex_unlock(&g_collab.collaborative_mutex);
    
    // Broadcast cursor position update
    char event_data[512];
    snprintf(event_data, sizeof(event_data),
        "{"
        "\"developer_id\":\"%s\","
        "\"file_path\":\"%s\","
        "\"line\":%u,"
        "\"column\":%u"
        "}",
        developer_id, file_path, line, column);
    hmr_broadcast_collaborative_event("cursor_update", event_data);
    
    return HMR_SUCCESS;
}

// Send chat message
int hmr_send_chat_message(const char* developer_id, const char* content, const char* message_type) {
    if (!developer_id || !content) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    pthread_mutex_lock(&g_collab.collaborative_mutex);
    
    if (g_collab.chat_message_count >= MAX_CHAT_MESSAGES) {
        // Remove oldest message to make room
        memmove(&g_collab.chat_messages[0], &g_collab.chat_messages[1],
                (MAX_CHAT_MESSAGES - 1) * sizeof(hmr_chat_message_t));
        g_collab.chat_message_count--;
    }
    
    hmr_chat_message_t* message = &g_collab.chat_messages[g_collab.chat_message_count];
    memset(message, 0, sizeof(hmr_chat_message_t));
    
    hmr_generate_unique_id(message->message_id, sizeof(message->message_id));
    strncpy(message->developer_id, developer_id, sizeof(message->developer_id) - 1);
    strncpy(message->content, content, sizeof(message->content) - 1);
    strncpy(message->message_type, message_type ? message_type : "text", 
            sizeof(message->message_type) - 1);
    message->timestamp = time(NULL);
    
    g_collab.chat_message_count++;
    g_collab.total_chat_messages++;
    
    pthread_mutex_unlock(&g_collab.collaborative_mutex);
    
    // Broadcast chat message
    char event_data[1200];
    snprintf(event_data, sizeof(event_data),
        "{"
        "\"message_id\":\"%s\","
        "\"developer_id\":\"%s\","
        "\"content\":\"%s\","
        "\"message_type\":\"%s\","
        "\"timestamp\":%ld"
        "}",
        message->message_id, message->developer_id, message->content,
        message->message_type, message->timestamp);
    hmr_broadcast_collaborative_event("chat_message", event_data);
    
    return HMR_SUCCESS;
}

// Get collaborative state as JSON
void hmr_get_collaborative_state(char* json_buffer, size_t max_len) {
    if (!json_buffer || max_len == 0) return;
    
    pthread_mutex_lock(&g_collab.collaborative_mutex);
    hmr_serialize_session_state(json_buffer, max_len);
    pthread_mutex_unlock(&g_collab.collaborative_mutex);
}

// Main sync thread
static void* hmr_collaborative_sync_thread(void* arg) {
    (void)arg;
    
    printf("[HMR] Collaborative sync thread started\n");
    
    while (g_collab.running) {
        pthread_mutex_lock(&g_collab.collaborative_mutex);
        
        // Detect and resolve conflicts
        hmr_detect_and_resolve_conflicts();
        
        // Clean up inactive sessions
        hmr_cleanup_inactive_sessions();
        
        // Update session activity time
        g_collab.session_time_seconds += 5;
        
        pthread_mutex_unlock(&g_collab.collaborative_mutex);
        
        sleep(5); // Sync every 5 seconds
    }
    
    printf("[HMR] Collaborative sync thread exiting\n");
    return NULL;
}

// Helper function implementations
static void hmr_generate_unique_id(char* buffer, size_t buffer_size) {
    uuid_t uuid;
    uuid_generate(uuid);
    uuid_unparse_lower(uuid, buffer);
}

static void hmr_broadcast_collaborative_event(const char* event_type, const char* data) {
    char full_event[2048];
    snprintf(full_event, sizeof(full_event),
        "{"
        "\"type\":\"collaborative_event\","
        "\"event_type\":\"%s\","
        "\"data\":%s,"
        "\"timestamp\":%ld"
        "}",
        event_type, data, time(NULL));
    
    // In real implementation, this would use the HMR broadcast system
    printf("[HMR] Collaborative event: %s\n", event_type);
}

static void hmr_detect_and_resolve_conflicts(void) {
    // Simple conflict detection: check for concurrent edits to same lines
    for (uint32_t i = 0; i < g_collab.code_change_count; i++) {
        for (uint32_t j = i + 1; j < g_collab.code_change_count; j++) {
            hmr_code_change_t* change1 = &g_collab.code_changes[i];
            hmr_code_change_t* change2 = &g_collab.code_changes[j];
            
            // Check for overlapping changes in same file
            if (strcmp(change1->file_path, change2->file_path) == 0 &&
                strcmp(change1->developer_id, change2->developer_id) != 0 &&
                abs((int)(change1->timestamp - change2->timestamp)) < 10 &&
                change1->start_line <= change2->end_line &&
                change2->start_line <= change1->end_line) {
                
                // Conflict detected
                if (g_collab.conflict_count < 64) {
                    hmr_conflict_t* conflict = &g_collab.conflicts[g_collab.conflict_count];
                    hmr_generate_unique_id(conflict->conflict_id, sizeof(conflict->conflict_id));
                    strncpy(conflict->file_path, change1->file_path, sizeof(conflict->file_path) - 1);
                    strncpy(conflict->developer1_id, change1->developer_id, sizeof(conflict->developer1_id) - 1);
                    strncpy(conflict->developer2_id, change2->developer_id, sizeof(conflict->developer2_id) - 1);
                    strncpy(conflict->conflict_type, "concurrent_edit", sizeof(conflict->conflict_type) - 1);
                    conflict->line_number = change1->start_line;
                    conflict->detected_time = time(NULL);
                    conflict->resolved = false;
                    
                    g_collab.conflict_count++;
                    
                    printf("[HMR] Conflict detected: %s (line %u)\n", 
                           conflict->file_path, conflict->line_number);
                }
            }
        }
    }
}

static void hmr_cleanup_inactive_sessions(void) {
    time_t current_time = time(NULL);
    
    for (uint32_t i = 0; i < g_collab.session_count; i++) {
        hmr_session_t* session = &g_collab.sessions[i];
        
        // Mark session as inactive if no activity for 30 minutes
        if (session->active && 
            (current_time - session->last_activity) > (SESSION_TIMEOUT_MINUTES * 60)) {
            session->active = false;
            printf("[HMR] Session timed out: %s\n", session->session_name);
        }
    }
    
    // Clean up inactive developers
    for (uint32_t i = 0; i < g_collab.developer_count; i++) {
        hmr_developer_t* dev = &g_collab.developers[i];
        
        if (dev->active && 
            (current_time - dev->last_activity) > (SESSION_TIMEOUT_MINUTES * 60)) {
            dev->active = false;
            printf("[HMR] Developer inactive: %s\n", dev->display_name);
        }
    }
}

static void hmr_serialize_session_state(char* json_buffer, size_t max_len) {
    size_t pos = 0;
    
    pos += snprintf(json_buffer + pos, max_len - pos,
        "{"
        "\"developers\":[");
    
    // Serialize active developers
    bool first_dev = true;
    for (uint32_t i = 0; i < g_collab.developer_count && pos < max_len - 1000; i++) {
        hmr_developer_t* dev = &g_collab.developers[i];
        if (!dev->active) continue;
        
        if (!first_dev) {
            pos += snprintf(json_buffer + pos, max_len - pos, ",");
        }
        first_dev = false;
        
        pos += snprintf(json_buffer + pos, max_len - pos,
            "{"
            "\"id\":\"%s\","
            "\"name\":\"%s\","
            "\"status\":\"%s\","
            "\"color\":\"%s\","
            "\"current_file\":\"%s\","
            "\"cursor_line\":%u,"
            "\"cursor_column\":%u"
            "}",
            dev->developer_id, dev->display_name, dev->status, dev->color,
            dev->current_file, dev->cursor_line, dev->cursor_column);
    }
    
    pos += snprintf(json_buffer + pos, max_len - pos,
        "],"
        "\"sessions\":[");
    
    // Serialize active sessions
    bool first_session = true;
    for (uint32_t i = 0; i < g_collab.session_count && pos < max_len - 500; i++) {
        hmr_session_t* session = &g_collab.sessions[i];
        if (!session->active) continue;
        
        if (!first_session) {
            pos += snprintf(json_buffer + pos, max_len - pos, ",");
        }
        first_session = false;
        
        pos += snprintf(json_buffer + pos, max_len - pos,
            "{"
            "\"id\":\"%s\","
            "\"name\":\"%s\","
            "\"developer_count\":%u,"
            "\"leader\":\"%s\""
            "}",
            session->session_id, session->session_name,
            session->developer_count, session->session_leader);
    }
    
    pos += snprintf(json_buffer + pos, max_len - pos,
        "],"
        "\"stats\":{"
        "\"total_developers\":%u,"
        "\"active_sessions\":%u,"
        "\"total_changes\":%llu,"
        "\"total_messages\":%llu,"
        "\"conflicts_resolved\":%llu"
        "}"
        "}",
        g_collab.developer_count,
        g_collab.session_count,
        g_collab.total_code_changes,
        g_collab.total_chat_messages,
        g_collab.conflicts_resolved);
}

static const char* hmr_get_random_color(void) {
    const char* colors[] = {
        "#60a5fa", "#34d399", "#a78bfa", "#fbbf24",
        "#f87171", "#fb7185", "#38bdf8", "#4ade80",
        "#818cf8", "#fbbf24", "#fb923c", "#c084fc"
    };
    return colors[rand() % (sizeof(colors) / sizeof(colors[0]))];
}

static bool hmr_is_developer_in_session(const char* session_id, const char* developer_id) {
    for (uint32_t i = 0; i < g_collab.session_count; i++) {
        hmr_session_t* session = &g_collab.sessions[i];
        if (strcmp(session->session_id, session_id) == 0) {
            for (uint32_t j = 0; j < session->developer_count; j++) {
                if (strcmp(session->developers[j], developer_id) == 0) {
                    return true;
                }
            }
            break;
        }
    }
    return false;
}