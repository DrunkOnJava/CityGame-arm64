/*
 * SimCity ARM64 - Asset Collaboration System
 * Real-time team collaboration for asset development
 * 
 * Created by Agent 5: Asset Pipeline & Advanced Features - Week 3 Day 11
 * Provides sophisticated collaboration features for team asset development
 */

#ifndef HMR_ASSET_COLLABORATION_H
#define HMR_ASSET_COLLABORATION_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <time.h>
#include <pthread.h>

// Collaboration session types
typedef enum {
    COLLAB_SESSION_EXCLUSIVE = 0,   // Single editor at a time
    COLLAB_SESSION_SHARED,          // Multiple editors allowed
    COLLAB_SESSION_REVIEW,          // Review-only session
    COLLAB_SESSION_MERGE,           // Merge conflict resolution
    COLLAB_SESSION_WORKSHOP,        // Workshop/brainstorming session
    COLLAB_SESSION_STREAMING        // Live streaming session
} collab_session_type_t;

// User roles in collaboration
typedef enum {
    COLLAB_ROLE_OWNER = 0,          // Asset owner (full permissions)
    COLLAB_ROLE_EDITOR,             // Can edit and commit
    COLLAB_ROLE_REVIEWER,           // Can review and comment
    COLLAB_ROLE_VIEWER,             // View-only access
    COLLAB_ROLE_GUEST,              // Temporary access
    COLLAB_ROLE_MODERATOR           // Session moderator
} collab_user_role_t;

// Collaboration permission flags
typedef enum {
    COLLAB_PERM_READ        = 0x0001,   // Read asset
    COLLAB_PERM_WRITE       = 0x0002,   // Write/modify asset
    COLLAB_PERM_COMMIT      = 0x0004,   // Commit changes
    COLLAB_PERM_BRANCH      = 0x0008,   // Create branches
    COLLAB_PERM_MERGE       = 0x0010,   // Merge branches
    COLLAB_PERM_DELETE      = 0x0020,   // Delete asset
    COLLAB_PERM_ADMIN       = 0x0040,   // Administrative access
    COLLAB_PERM_LOCK        = 0x0080,   // Lock/unlock assets
    COLLAB_PERM_REVIEW      = 0x0100,   // Review and approve
    COLLAB_PERM_MODERATE    = 0x0200    // Moderate sessions
} collab_permission_t;

// Real-time synchronization modes
typedef enum {
    COLLAB_SYNC_NONE = 0,           // No synchronization
    COLLAB_SYNC_MANUAL,             // Manual sync on request
    COLLAB_SYNC_PERIODIC,           // Periodic sync (configurable interval)
    COLLAB_SYNC_REALTIME,           // Real-time sync on every change
    COLLAB_SYNC_OPERATIONAL         // Operational transform sync
} collab_sync_mode_t;

// Collaboration events
typedef enum {
    COLLAB_EVENT_USER_JOINED = 0,       // User joined session
    COLLAB_EVENT_USER_LEFT,             // User left session
    COLLAB_EVENT_ASSET_MODIFIED,        // Asset was modified
    COLLAB_EVENT_ASSET_SAVED,           // Asset was saved
    COLLAB_EVENT_COMMENT_ADDED,         // Comment added
    COLLAB_EVENT_REVIEW_REQUESTED,      // Review requested
    COLLAB_EVENT_REVIEW_COMPLETED,      // Review completed
    COLLAB_EVENT_CONFLICT_DETECTED,     // Merge conflict detected
    COLLAB_EVENT_CONFLICT_RESOLVED,     // Merge conflict resolved
    COLLAB_EVENT_LOCK_ACQUIRED,         // Lock acquired
    COLLAB_EVENT_LOCK_RELEASED,         // Lock released
    COLLAB_EVENT_SYNC_STARTED,          // Synchronization started
    COLLAB_EVENT_SYNC_COMPLETED,        // Synchronization completed
    COLLAB_EVENT_ERROR_OCCURRED         // Error occurred
} collab_event_type_t;

// User information in collaboration context
typedef struct {
    char user_id[64];               // Unique user identifier
    char username[128];             // Display name
    char email[256];                // Email address
    char avatar_url[512];           // Avatar image URL
    collab_user_role_t role;        // User role in session
    uint32_t permissions;           // Permission flags
    uint64_t join_time;             // When user joined session
    uint64_t last_activity;         // Last activity timestamp
    bool is_online;                 // Whether user is currently online
    bool is_typing;                 // Whether user is actively typing
    char current_file[512];         // Currently edited file
    uint32_t cursor_position;       // Current cursor position
    char status_message[256];       // User status message
} collab_user_t;

// Asset comment/annotation
typedef struct {
    char comment_id[64];            // Unique comment identifier
    char asset_path[512];           // Path to commented asset
    char author_id[64];             // Comment author
    char author_name[128];          // Author display name
    uint64_t timestamp;             // Comment timestamp
    char content[2048];             // Comment content
    uint32_t line_number;           // Line number (for text assets)
    uint32_t character_offset;      // Character offset
    float position_x;               // X position (for visual assets)
    float position_y;               // Y position (for visual assets)
    char reply_to[64];              // Parent comment ID (for replies)
    bool is_resolved;               // Whether comment is resolved
    char resolved_by[64];           // Who resolved the comment
    uint64_t resolved_time;         // When comment was resolved
    uint32_t upvotes;               // Number of upvotes
    uint32_t downvotes;             // Number of downvotes
} collab_comment_t;

// Asset review information
typedef struct {
    char review_id[64];             // Unique review identifier
    char asset_path[512];           // Path to reviewed asset
    char reviewer_id[64];           // Reviewer user ID
    char reviewer_name[128];        // Reviewer display name
    uint64_t requested_time;        // When review was requested
    uint64_t started_time;          // When review started
    uint64_t completed_time;        // When review completed
    char status[32];                // Review status (pending, in_progress, approved, rejected)
    char summary[1024];             // Review summary
    uint32_t score;                 // Review score (0-100)
    bool requires_changes;          // Whether changes are required
    char change_requests[10][512];  // Specific change requests
    uint32_t change_request_count;  // Number of change requests
    char approval_signature[256];   // Digital signature for approval
} collab_review_t;

// Real-time change operation
typedef struct {
    char operation_id[64];          // Unique operation identifier
    char user_id[64];               // User who made the change
    uint64_t timestamp;             // Operation timestamp
    uint32_t sequence_number;       // Sequence number for ordering
    char operation_type[32];        // Type of operation (insert, delete, replace, etc.)
    uint32_t start_position;        // Starting position
    uint32_t end_position;          // Ending position
    char content[4096];             // Content being inserted/replaced
    char context_before[256];       // Context before change
    char context_after[256];        // Context after change
    bool is_applied;                // Whether operation has been applied
    char conflict_resolution[64];   // Conflict resolution strategy if applicable
} collab_operation_t;

// Collaboration session
typedef struct {
    char session_id[64];            // Unique session identifier
    char session_name[128];         // Human-readable session name
    collab_session_type_t type;     // Session type
    char asset_path[512];           // Primary asset being collaborated on
    char owner_id[64];              // Session owner
    uint64_t created_time;          // Session creation time
    uint64_t last_activity;         // Last activity in session
    bool is_active;                 // Whether session is active
    collab_sync_mode_t sync_mode;   // Synchronization mode
    uint32_t sync_interval_ms;      // Sync interval for periodic mode
    
    collab_user_t users[32];        // Session participants
    uint32_t user_count;            // Number of participants
    
    collab_comment_t* comments;     // Session comments
    uint32_t comment_count;         // Number of comments
    uint32_t max_comments;          // Maximum comments allocated
    
    collab_operation_t* operations; // Real-time operations
    uint32_t operation_count;       // Number of operations
    uint32_t max_operations;        // Maximum operations allocated
    uint32_t last_sequence;         // Last sequence number
    
    char shared_state[8192];        // Shared session state
    uint64_t state_version;         // State version number
    
    pthread_mutex_t mutex;          // Session synchronization
    pthread_cond_t sync_condition;  // Sync condition variable
} collab_session_t;

// Collaboration manager
typedef struct {
    collab_session_t* sessions[256]; // Active sessions
    uint32_t session_count;          // Number of active sessions
    uint32_t max_sessions;           // Maximum sessions allowed
    
    char server_url[512];            // Collaboration server URL
    char auth_token[256];            // Authentication token
    bool is_connected;               // Whether connected to server
    uint64_t last_heartbeat;         // Last heartbeat timestamp
    
    collab_user_t current_user;      // Current user information
    
    pthread_t sync_thread;           // Synchronization thread
    pthread_t heartbeat_thread;      // Heartbeat thread
    pthread_mutex_t manager_mutex;   // Manager synchronization
    
    bool is_running;                 // Whether manager is running
    uint32_t total_sessions;         // Total sessions created
    uint64_t total_operations;       // Total operations processed
    uint64_t total_comments;         // Total comments created
} collab_manager_t;

// Collaboration event callback
typedef void (*collab_event_callback_t)(
    collab_session_t* session,
    collab_event_type_t event_type,
    void* event_data,
    void* user_data
);

// Collaboration conflict resolver
typedef int32_t (*collab_conflict_resolver_t)(
    const collab_operation_t* local_op,
    const collab_operation_t* remote_op,
    collab_operation_t* resolved_op,
    void* context
);

// API Functions - Collaboration Management
#ifdef __cplusplus
extern "C" {
#endif

// Manager initialization
int32_t collab_manager_init(collab_manager_t** manager, const char* server_url, const char* auth_token);
void collab_manager_shutdown(collab_manager_t* manager);
int32_t collab_manager_connect(collab_manager_t* manager);
int32_t collab_manager_disconnect(collab_manager_t* manager);
bool collab_manager_is_connected(collab_manager_t* manager);

// User management
int32_t collab_set_current_user(collab_manager_t* manager, const collab_user_t* user);
int32_t collab_get_user_info(collab_manager_t* manager, const char* user_id, collab_user_t* user);
int32_t collab_update_user_status(collab_manager_t* manager, const char* status_message);
int32_t collab_set_user_permissions(collab_manager_t* manager, const char* user_id, uint32_t permissions);

// Session management
int32_t collab_create_session(collab_manager_t* manager,
                             const char* session_name,
                             const char* asset_path,
                             collab_session_type_t type,
                             collab_session_t** session);
int32_t collab_join_session(collab_manager_t* manager, const char* session_id, collab_session_t** session);
int32_t collab_leave_session(collab_manager_t* manager, const char* session_id);
int32_t collab_close_session(collab_manager_t* manager, const char* session_id);
int32_t collab_list_sessions(collab_manager_t* manager, char session_ids[][64], uint32_t max_sessions);

// Real-time collaboration
int32_t collab_apply_operation(collab_session_t* session, const collab_operation_t* operation);
int32_t collab_create_operation(collab_session_t* session,
                               const char* operation_type,
                               uint32_t start_pos,
                               uint32_t end_pos,
                               const char* content,
                               collab_operation_t* operation);
int32_t collab_sync_session(collab_session_t* session);
int32_t collab_set_sync_mode(collab_session_t* session, collab_sync_mode_t mode, uint32_t interval_ms);

// Comments and annotations
int32_t collab_add_comment(collab_session_t* session,
                          const char* asset_path,
                          const char* content,
                          uint32_t line_number,
                          float pos_x,
                          float pos_y,
                          collab_comment_t** comment);
int32_t collab_reply_to_comment(collab_session_t* session,
                               const char* parent_comment_id,
                               const char* content,
                               collab_comment_t** reply);
int32_t collab_resolve_comment(collab_session_t* session, const char* comment_id);
int32_t collab_get_comments(collab_session_t* session,
                           const char* asset_path,
                           collab_comment_t* comments,
                           uint32_t max_comments);
int32_t collab_vote_comment(collab_session_t* session, const char* comment_id, bool upvote);

// Review system
int32_t collab_request_review(collab_session_t* session,
                             const char* asset_path,
                             const char* reviewer_id,
                             collab_review_t** review);
int32_t collab_start_review(collab_session_t* session, const char* review_id);
int32_t collab_complete_review(collab_session_t* session,
                              const char* review_id,
                              const char* status,
                              const char* summary,
                              uint32_t score);
int32_t collab_get_review_status(collab_session_t* session,
                                const char* asset_path,
                                collab_review_t* reviews,
                                uint32_t max_reviews);

// Conflict resolution
int32_t collab_detect_conflicts(collab_session_t* session,
                               collab_operation_t* conflicted_ops,
                               uint32_t max_conflicts);
int32_t collab_resolve_conflict(collab_session_t* session,
                               const collab_operation_t* local_op,
                               const collab_operation_t* remote_op,
                               collab_conflict_resolver_t resolver,
                               void* context);
int32_t collab_set_conflict_resolver(collab_session_t* session, collab_conflict_resolver_t resolver);

// Event handling
int32_t collab_set_event_callback(collab_session_t* session,
                                 collab_event_callback_t callback,
                                 void* user_data);
int32_t collab_emit_event(collab_session_t* session,
                         collab_event_type_t event_type,
                         void* event_data);

// Session state management
int32_t collab_save_session_state(collab_session_t* session, const char* state_data, size_t data_size);
int32_t collab_load_session_state(collab_session_t* session, char* state_data, size_t max_size);
int32_t collab_sync_session_state(collab_session_t* session);
uint64_t collab_get_state_version(collab_session_t* session);

// Utility functions
bool collab_has_permission(const collab_user_t* user, collab_permission_t permission);
const char* collab_get_role_name(collab_user_role_t role);
const char* collab_get_event_name(collab_event_type_t event);
uint32_t collab_get_user_count(collab_session_t* session);
bool collab_is_user_online(collab_session_t* session, const char* user_id);

// Performance monitoring
typedef struct {
    uint64_t total_sessions_created;    // Total sessions created
    uint64_t active_sessions;           // Currently active sessions
    uint64_t total_users;               // Total unique users
    uint64_t online_users;              // Currently online users
    uint64_t total_operations;          // Total operations processed
    uint64_t operations_per_second;     // Current operations per second
    uint64_t total_comments;            // Total comments created
    uint64_t total_reviews;             // Total reviews completed
    uint64_t avg_session_duration_ms;   // Average session duration
    uint64_t avg_sync_latency_ms;       // Average sync latency
    uint64_t conflicts_detected;        // Conflicts detected
    uint64_t conflicts_resolved;        // Conflicts resolved
    uint64_t network_bytes_sent;        // Network bytes sent
    uint64_t network_bytes_received;    // Network bytes received
} collab_metrics_t;

void collab_get_metrics(collab_manager_t* manager, collab_metrics_t* metrics);
void collab_reset_metrics(collab_manager_t* manager);

#ifdef __cplusplus
}
#endif

// Constants and configuration
#define COLLAB_MAX_SESSIONS             256
#define COLLAB_MAX_USERS_PER_SESSION    32
#define COLLAB_MAX_COMMENTS             10000
#define COLLAB_MAX_OPERATIONS           100000
#define COLLAB_MAX_SESSION_NAME         128
#define COLLAB_MAX_COMMENT_CONTENT      2048
#define COLLAB_MAX_REVIEW_SUMMARY       1024
#define COLLAB_MAX_OPERATION_CONTENT    4096
#define COLLAB_DEFAULT_SYNC_INTERVAL_MS 1000
#define COLLAB_HEARTBEAT_INTERVAL_MS    30000
#define COLLAB_SESSION_TIMEOUT_MS       3600000  // 1 hour
#define COLLAB_OPERATION_TIMEOUT_MS     5000
#define COLLAB_MAX_CONFLICT_ATTEMPTS    3

// Error codes
#define COLLAB_SUCCESS                  0
#define COLLAB_ERROR_INVALID_SESSION    -1
#define COLLAB_ERROR_PERMISSION_DENIED  -2
#define COLLAB_ERROR_USER_NOT_FOUND     -3
#define COLLAB_ERROR_NETWORK            -4
#define COLLAB_ERROR_CONFLICT           -5
#define COLLAB_ERROR_TIMEOUT            -6
#define COLLAB_ERROR_FULL               -7
#define COLLAB_ERROR_NOT_CONNECTED      -8
#define COLLAB_ERROR_INVALID_OPERATION  -9
#define COLLAB_ERROR_SYNC_FAILED        -10

// Role permission defaults
#define COLLAB_OWNER_PERMISSIONS    (COLLAB_PERM_READ | COLLAB_PERM_WRITE | COLLAB_PERM_COMMIT | \
                                     COLLAB_PERM_BRANCH | COLLAB_PERM_MERGE | COLLAB_PERM_DELETE | \
                                     COLLAB_PERM_ADMIN | COLLAB_PERM_LOCK | COLLAB_PERM_REVIEW | \
                                     COLLAB_PERM_MODERATE)
#define COLLAB_EDITOR_PERMISSIONS   (COLLAB_PERM_READ | COLLAB_PERM_WRITE | COLLAB_PERM_COMMIT | \
                                     COLLAB_PERM_BRANCH | COLLAB_PERM_REVIEW)
#define COLLAB_REVIEWER_PERMISSIONS (COLLAB_PERM_READ | COLLAB_PERM_REVIEW)
#define COLLAB_VIEWER_PERMISSIONS   (COLLAB_PERM_READ)

#endif // HMR_ASSET_COLLABORATION_H