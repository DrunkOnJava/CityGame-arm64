/*
 * SimCity ARM64 - Asset Version Control System
 * Enterprise-grade Git-based asset versioning with LFS support
 * 
 * Created by Agent 5: Asset Pipeline & Advanced Features - Week 3 Day 11
 * Provides comprehensive version control for game assets with team collaboration
 */

#ifndef HMR_ASSET_VERSION_CONTROL_H
#define HMR_ASSET_VERSION_CONTROL_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <time.h>
#include "module_versioning.h"

// Asset version control state
typedef enum {
    ASSET_VCS_UNTRACKED = 0,        // Asset not in version control
    ASSET_VCS_CLEAN,                // Asset matches repository
    ASSET_VCS_MODIFIED,             // Asset has local modifications
    ASSET_VCS_STAGED,               // Asset staged for commit
    ASSET_VCS_CONFLICTED,           // Asset has merge conflicts
    ASSET_VCS_DELETED,              // Asset marked for deletion
    ASSET_VCS_ADDED,                // Asset newly added
    ASSET_VCS_RENAMED,              // Asset was renamed
    ASSET_VCS_COPIED,               // Asset was copied
    ASSET_VCS_IGNORED,              // Asset is ignored by VCS
    ASSET_VCS_LOCKED,               // Asset is locked for editing
    ASSET_VCS_OUTDATED              // Asset is behind remote version
} asset_vcs_state_t;

// Asset version information
typedef struct {
    char hash[64];                  // Git SHA hash of the asset
    char branch[64];                // Current branch
    char commit_hash[64];           // Commit hash where asset was last modified
    uint64_t timestamp;             // Last modification timestamp
    uint32_t version_number;        // Sequential version number
    char author[128];               // Last author to modify asset
    char commit_message[512];       // Last commit message
    asset_vcs_state_t state;        // Current VCS state
    bool is_lfs;                    // Whether asset uses Git LFS
    uint64_t file_size;             // File size in bytes
    char mime_type[64];             // Asset MIME type
} asset_version_info_t;

// Asset history entry
typedef struct {
    char commit_hash[64];           // Commit hash
    char author[128];               // Author name
    char email[128];                // Author email
    uint64_t timestamp;             // Commit timestamp
    char message[512];              // Commit message
    uint64_t file_size;             // File size at this version
    char diff_summary[256];         // Summary of changes
    bool is_merge;                  // Whether this is a merge commit
    char parent_hashes[256];        // Parent commit hashes
} asset_history_entry_t;

// Asset branch information
typedef struct {
    char name[64];                  // Branch name
    char upstream[128];             // Upstream branch reference
    char last_commit[64];           // Last commit hash
    uint64_t last_commit_time;      // Last commit timestamp
    int32_t commits_ahead;          // Commits ahead of upstream
    int32_t commits_behind;         // Commits behind upstream
    bool is_tracking;               // Whether tracking remote
    bool has_conflicts;             // Whether branch has conflicts
} asset_branch_info_t;

// Asset collaboration metadata
typedef struct {
    char locked_by[128];            // User who locked the asset
    uint64_t lock_timestamp;        // When asset was locked
    char lock_reason[256];          // Reason for locking
    uint32_t lock_duration_hours;   // Expected lock duration
    bool is_collaborative_edit;     // Whether multiple editors allowed
    char collaborators[10][128];    // List of collaborators
    uint32_t collaborator_count;    // Number of active collaborators
    uint64_t last_sync_time;        // Last synchronization time
} asset_collaboration_t;

// Asset conflict information
typedef struct {
    char conflict_type[32];         // Type of conflict (content, binary, etc.)
    char local_hash[64];            // Local version hash
    char remote_hash[64];           // Remote version hash
    char base_hash[64];             // Common ancestor hash
    char conflict_markers[1024];    // Conflict marker locations
    uint32_t conflict_count;        // Number of conflicts
    bool auto_resolvable;           // Whether conflicts can be auto-resolved
    char resolution_strategy[64];   // Suggested resolution strategy
} asset_conflict_info_t;

// Asset version control manager
typedef struct {
    char repository_path[512];      // Path to Git repository
    char git_dir[512];              // Path to .git directory
    char lfs_dir[512];              // Path to LFS storage
    bool is_git_repo;               // Whether directory is Git repo
    bool has_lfs;                   // Whether LFS is available
    bool is_bare_repo;              // Whether repository is bare
    char current_branch[64];        // Current branch name
    char head_commit[64];           // Current HEAD commit
    uint32_t tracked_assets;        // Number of tracked assets
    uint64_t total_repo_size;       // Total repository size
    uint64_t lfs_size;              // LFS storage size
} asset_vcs_manager_t;

// Git LFS configuration
typedef struct {
    bool enabled;                   // Whether LFS is enabled
    char storage_path[512];         // LFS storage path
    uint64_t size_threshold;        // Minimum size for LFS (bytes)
    char file_patterns[32][64];     // File patterns for LFS
    uint32_t pattern_count;         // Number of patterns
    uint64_t max_file_size;         // Maximum file size for LFS
    char remote_url[512];           // LFS remote URL
    bool use_ssh;                   // Whether to use SSH for LFS
} asset_lfs_config_t;

// Asset diff information
typedef struct {
    char old_hash[64];              // Old version hash
    char new_hash[64];              // New version hash
    uint32_t additions;             // Lines/blocks added
    uint32_t deletions;             // Lines/blocks deleted
    uint32_t modifications;         // Lines/blocks modified
    float similarity;               // Similarity percentage (0.0-1.0)
    bool is_binary;                 // Whether asset is binary
    char diff_text[8192];           // Text diff (if applicable)
    uint64_t old_size;              // Old file size
    uint64_t new_size;              // New file size
} asset_diff_info_t;

// Asset merge strategy
typedef enum {
    ASSET_MERGE_AUTO = 0,           // Automatic merge
    ASSET_MERGE_OURS,               // Use our version
    ASSET_MERGE_THEIRS,             // Use their version
    ASSET_MERGE_MANUAL,             // Manual merge required
    ASSET_MERGE_TOOL,               // Use external merge tool
    ASSET_MERGE_BINARY_OURS,        // Binary merge - use ours
    ASSET_MERGE_BINARY_THEIRS,      // Binary merge - use theirs
    ASSET_MERGE_SKIP                // Skip conflicted file
} asset_merge_strategy_t;

// Asset backup configuration
typedef struct {
    bool enabled;                   // Whether backups are enabled
    char backup_path[512];          // Path to backup directory
    uint32_t max_backups;           // Maximum number of backups
    uint32_t backup_interval_hours; // Hours between backups
    bool compress_backups;          // Whether to compress backups
    char compression_method[32];    // Compression method (gzip, lz4, etc.)
    uint64_t max_backup_size;       // Maximum backup size
} asset_backup_config_t;

// API Functions - Asset Version Control
#ifdef __cplusplus
extern "C" {
#endif

// Version control manager initialization
int32_t asset_vcs_init(const char* repository_path, asset_vcs_manager_t** manager);
void asset_vcs_shutdown(asset_vcs_manager_t* manager);
int32_t asset_vcs_validate_repository(const char* repository_path);
bool asset_vcs_is_git_repository(const char* path);

// Repository operations
int32_t asset_vcs_create_repository(const char* path, bool bare);
int32_t asset_vcs_clone_repository(const char* url, const char* path, const char* branch);
int32_t asset_vcs_init_lfs(asset_vcs_manager_t* manager, const asset_lfs_config_t* config);
int32_t asset_vcs_configure_lfs_patterns(asset_vcs_manager_t* manager, 
                                        const char* patterns[], uint32_t count);

// Asset version information
int32_t asset_vcs_get_version_info(asset_vcs_manager_t* manager, 
                                  const char* asset_path, 
                                  asset_version_info_t* info);
int32_t asset_vcs_get_asset_history(asset_vcs_manager_t* manager,
                                   const char* asset_path,
                                   asset_history_entry_t* history,
                                   uint32_t max_entries);
int32_t asset_vcs_get_asset_diff(asset_vcs_manager_t* manager,
                                const char* asset_path,
                                const char* old_hash,
                                const char* new_hash,
                                asset_diff_info_t* diff);

// Branch operations
int32_t asset_vcs_list_branches(asset_vcs_manager_t* manager,
                               asset_branch_info_t* branches,
                               uint32_t max_branches);
int32_t asset_vcs_create_branch(asset_vcs_manager_t* manager,
                               const char* branch_name,
                               const char* start_point);
int32_t asset_vcs_switch_branch(asset_vcs_manager_t* manager, const char* branch_name);
int32_t asset_vcs_merge_branch(asset_vcs_manager_t* manager,
                              const char* branch_name,
                              asset_merge_strategy_t strategy);
int32_t asset_vcs_delete_branch(asset_vcs_manager_t* manager, const char* branch_name);

// Asset staging and committing
int32_t asset_vcs_stage_asset(asset_vcs_manager_t* manager, const char* asset_path);
int32_t asset_vcs_unstage_asset(asset_vcs_manager_t* manager, const char* asset_path);
int32_t asset_vcs_commit_assets(asset_vcs_manager_t* manager,
                               const char* message,
                               const char* author,
                               const char* email);
int32_t asset_vcs_commit_asset(asset_vcs_manager_t* manager,
                              const char* asset_path,
                              const char* message,
                              const char* author,
                              const char* email);

// Remote operations
int32_t asset_vcs_fetch_remote(asset_vcs_manager_t* manager, const char* remote);
int32_t asset_vcs_pull_remote(asset_vcs_manager_t* manager, const char* remote, const char* branch);
int32_t asset_vcs_push_remote(asset_vcs_manager_t* manager, const char* remote, const char* branch);
int32_t asset_vcs_add_remote(asset_vcs_manager_t* manager, const char* name, const char* url);
int32_t asset_vcs_remove_remote(asset_vcs_manager_t* manager, const char* name);

// Asset collaboration
int32_t asset_vcs_lock_asset(asset_vcs_manager_t* manager,
                            const char* asset_path,
                            const char* user,
                            const char* reason,
                            uint32_t duration_hours);
int32_t asset_vcs_unlock_asset(asset_vcs_manager_t* manager,
                              const char* asset_path,
                              const char* user);
int32_t asset_vcs_get_collaboration_info(asset_vcs_manager_t* manager,
                                        const char* asset_path,
                                        asset_collaboration_t* info);
int32_t asset_vcs_sync_collaboration(asset_vcs_manager_t* manager,
                                    const char* asset_path);

// Conflict resolution
int32_t asset_vcs_get_conflicts(asset_vcs_manager_t* manager,
                               char asset_paths[][512],
                               uint32_t max_paths);
int32_t asset_vcs_get_conflict_info(asset_vcs_manager_t* manager,
                                   const char* asset_path,
                                   asset_conflict_info_t* info);
int32_t asset_vcs_resolve_conflict(asset_vcs_manager_t* manager,
                                  const char* asset_path,
                                  asset_merge_strategy_t strategy);
int32_t asset_vcs_mark_resolved(asset_vcs_manager_t* manager, const char* asset_path);

// Asset restoration and rollback
int32_t asset_vcs_restore_asset(asset_vcs_manager_t* manager,
                               const char* asset_path,
                               const char* commit_hash);
int32_t asset_vcs_revert_asset(asset_vcs_manager_t* manager,
                              const char* asset_path,
                              const char* commit_hash);
int32_t asset_vcs_checkout_version(asset_vcs_manager_t* manager,
                                  const char* asset_path,
                                  const char* version);

// Asset backup system
int32_t asset_vcs_create_backup(asset_vcs_manager_t* manager,
                               const char* backup_name,
                               const asset_backup_config_t* config);
int32_t asset_vcs_restore_backup(asset_vcs_manager_t* manager,
                                const char* backup_name);
int32_t asset_vcs_list_backups(asset_vcs_manager_t* manager,
                              char backup_names[][128],
                              uint32_t max_backups);
int32_t asset_vcs_cleanup_backups(asset_vcs_manager_t* manager,
                                 const asset_backup_config_t* config);

// Utility functions
bool asset_vcs_is_tracked(asset_vcs_manager_t* manager, const char* asset_path);
bool asset_vcs_is_modified(asset_vcs_manager_t* manager, const char* asset_path);
bool asset_vcs_is_staged(asset_vcs_manager_t* manager, const char* asset_path);
bool asset_vcs_is_conflicted(asset_vcs_manager_t* manager, const char* asset_path);
bool asset_vcs_is_lfs_file(asset_vcs_manager_t* manager, const char* asset_path);

// Status and monitoring
int32_t asset_vcs_get_status(asset_vcs_manager_t* manager,
                            const char* asset_path,
                            asset_vcs_state_t* state);
int32_t asset_vcs_get_repository_status(asset_vcs_manager_t* manager,
                                       char status_summary[1024]);
int32_t asset_vcs_get_branch_status(asset_vcs_manager_t* manager,
                                   const char* branch_name,
                                   asset_branch_info_t* info);

// Performance monitoring
typedef struct {
    uint64_t total_operations;      // Total VCS operations
    uint64_t successful_commits;    // Successful commits
    uint64_t failed_commits;        // Failed commits
    uint64_t merge_conflicts;       // Merge conflicts encountered
    uint64_t lfs_uploads;           // LFS uploads performed
    uint64_t lfs_downloads;         // LFS downloads performed
    uint64_t avg_commit_time_ms;    // Average commit time
    uint64_t avg_checkout_time_ms;  // Average checkout time
    uint64_t repository_size;       // Total repository size
    uint64_t lfs_size;              // LFS storage size
    uint64_t backup_size;           // Backup storage size
} asset_vcs_metrics_t;

void asset_vcs_get_metrics(asset_vcs_manager_t* manager, asset_vcs_metrics_t* metrics);
void asset_vcs_reset_metrics(asset_vcs_manager_t* manager);

#ifdef __cplusplus
}
#endif

// Constants and configuration
#define ASSET_VCS_MAX_PATH_LENGTH       512
#define ASSET_VCS_MAX_COMMIT_MESSAGE    512
#define ASSET_VCS_MAX_AUTHOR_NAME       128
#define ASSET_VCS_MAX_BRANCH_NAME       64
#define ASSET_VCS_MAX_REMOTE_NAME       64
#define ASSET_VCS_MAX_HASH_LENGTH       64
#define ASSET_VCS_MAX_HISTORY_ENTRIES   1000
#define ASSET_VCS_MAX_COLLABORATORS     10
#define ASSET_VCS_MAX_BACKUPS           50
#define ASSET_VCS_LFS_THRESHOLD_MB      10
#define ASSET_VCS_LOCK_TIMEOUT_HOURS    8
#define ASSET_VCS_SYNC_INTERVAL_MINUTES 5

// Error codes
#define ASSET_VCS_SUCCESS               0
#define ASSET_VCS_ERROR_INVALID_REPO    -1
#define ASSET_VCS_ERROR_NOT_FOUND       -2
#define ASSET_VCS_ERROR_PERMISSION      -3
#define ASSET_VCS_ERROR_CONFLICT        -4
#define ASSET_VCS_ERROR_NETWORK         -5
#define ASSET_VCS_ERROR_LFS             -6
#define ASSET_VCS_ERROR_LOCKED          -7
#define ASSET_VCS_ERROR_DIRTY           -8
#define ASSET_VCS_ERROR_DETACHED        -9
#define ASSET_VCS_ERROR_MERGE           -10
#define ASSET_VCS_ERROR_BACKUP          -11

// Macros for common operations
#define ASSET_VCS_IS_CLEAN(state) \
    ((state) == ASSET_VCS_CLEAN)
#define ASSET_VCS_HAS_CHANGES(state) \
    ((state) == ASSET_VCS_MODIFIED || (state) == ASSET_VCS_STAGED)
#define ASSET_VCS_NEEDS_ATTENTION(state) \
    ((state) == ASSET_VCS_CONFLICTED || (state) == ASSET_VCS_OUTDATED)

#endif // HMR_ASSET_VERSION_CONTROL_H