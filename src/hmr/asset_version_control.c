/*
 * SimCity ARM64 - Asset Version Control System Implementation
 * Enterprise-grade Git-based asset versioning with LFS support
 * 
 * Created by Agent 5: Asset Pipeline & Advanced Features - Week 3 Day 11
 * Provides comprehensive version control for game assets with team collaboration
 */

#include "asset_version_control.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <dirent.h>
#include <fcntl.h>
#include <pthread.h>
#include <libgen.h>

// Global metrics tracking
static asset_vcs_metrics_t g_vcs_metrics = {0};
static pthread_mutex_t g_metrics_mutex = PTHREAD_MUTEX_INITIALIZER;

// Internal utility functions
static int32_t execute_git_command(const char* repo_path, const char* command, char* output, size_t output_size);
static bool file_exists(const char* path);
static bool directory_exists(const char* path);
static int32_t create_directory_recursive(const char* path);
static char* get_file_hash(const char* file_path);
static uint64_t get_file_size(const char* file_path);
static bool is_binary_file(const char* file_path);
static int32_t update_metrics(const char* operation, bool success, uint64_t duration_ms);

// Version control manager initialization
int32_t asset_vcs_init(const char* repository_path, asset_vcs_manager_t** manager) {
    if (!repository_path || !manager) {
        return ASSET_VCS_ERROR_INVALID_REPO;
    }
    
    *manager = calloc(1, sizeof(asset_vcs_manager_t));
    if (!*manager) {
        return ASSET_VCS_ERROR_INVALID_REPO;
    }
    
    asset_vcs_manager_t* mgr = *manager;
    
    // Initialize paths
    strncpy(mgr->repository_path, repository_path, sizeof(mgr->repository_path) - 1);
    snprintf(mgr->git_dir, sizeof(mgr->git_dir), "%s/.git", repository_path);
    snprintf(mgr->lfs_dir, sizeof(mgr->lfs_dir), "%s/.git/lfs", repository_path);
    
    // Check if it's a Git repository
    mgr->is_git_repo = directory_exists(mgr->git_dir);
    mgr->has_lfs = directory_exists(mgr->lfs_dir);
    
    if (mgr->is_git_repo) {
        // Get current branch
        char output[256];
        if (execute_git_command(repository_path, "rev-parse --abbrev-ref HEAD", output, sizeof(output)) == 0) {
            strncpy(mgr->current_branch, output, sizeof(mgr->current_branch) - 1);
        }
        
        // Get HEAD commit
        if (execute_git_command(repository_path, "rev-parse HEAD", output, sizeof(output)) == 0) {
            strncpy(mgr->head_commit, output, sizeof(mgr->head_commit) - 1);
        }
        
        // Check if bare repository
        if (execute_git_command(repository_path, "rev-parse --is-bare-repository", output, sizeof(output)) == 0) {
            mgr->is_bare_repo = (strcmp(output, "true") == 0);
        }
    }
    
    return ASSET_VCS_SUCCESS;
}

void asset_vcs_shutdown(asset_vcs_manager_t* manager) {
    if (manager) {
        free(manager);
    }
}

int32_t asset_vcs_validate_repository(const char* repository_path) {
    if (!repository_path) {
        return ASSET_VCS_ERROR_INVALID_REPO;
    }
    
    char git_dir[512];
    snprintf(git_dir, sizeof(git_dir), "%s/.git", repository_path);
    
    if (!directory_exists(git_dir)) {
        return ASSET_VCS_ERROR_INVALID_REPO;
    }
    
    // Validate Git repository integrity
    char output[256];
    if (execute_git_command(repository_path, "fsck --quiet", output, sizeof(output)) != 0) {
        return ASSET_VCS_ERROR_INVALID_REPO;
    }
    
    return ASSET_VCS_SUCCESS;
}

bool asset_vcs_is_git_repository(const char* path) {
    if (!path) return false;
    
    char git_dir[512];
    snprintf(git_dir, sizeof(git_dir), "%s/.git", path);
    return directory_exists(git_dir);
}

// Repository operations
int32_t asset_vcs_create_repository(const char* path, bool bare) {
    if (!path) {
        return ASSET_VCS_ERROR_INVALID_REPO;
    }
    
    if (!directory_exists(path)) {
        if (create_directory_recursive(path) != 0) {
            return ASSET_VCS_ERROR_PERMISSION;
        }
    }
    
    char command[512];
    char output[256];
    
    if (bare) {
        snprintf(command, sizeof(command), "init --bare");
    } else {
        snprintf(command, sizeof(command), "init");
    }
    
    uint64_t start_time = (uint64_t)time(NULL) * 1000;
    int32_t result = execute_git_command(path, command, output, sizeof(output));
    uint64_t duration = (uint64_t)time(NULL) * 1000 - start_time;
    
    update_metrics("create_repository", result == 0, duration);
    
    return (result == 0) ? ASSET_VCS_SUCCESS : ASSET_VCS_ERROR_INVALID_REPO;
}

int32_t asset_vcs_clone_repository(const char* url, const char* path, const char* branch) {
    if (!url || !path) {
        return ASSET_VCS_ERROR_INVALID_REPO;
    }
    
    char command[1024];
    char output[512];
    
    if (branch) {
        snprintf(command, sizeof(command), "clone --branch %s %s %s", branch, url, path);
    } else {
        snprintf(command, sizeof(command), "clone %s %s", url, path);
    }
    
    uint64_t start_time = (uint64_t)time(NULL) * 1000;
    int32_t result = system(command);  // Use system for clone as it needs different working directory
    uint64_t duration = (uint64_t)time(NULL) * 1000 - start_time;
    
    update_metrics("clone_repository", result == 0, duration);
    
    return (result == 0) ? ASSET_VCS_SUCCESS : ASSET_VCS_ERROR_NETWORK;
}

int32_t asset_vcs_init_lfs(asset_vcs_manager_t* manager, const asset_lfs_config_t* config) {
    if (!manager || !config) {
        return ASSET_VCS_ERROR_LFS;
    }
    
    char output[256];
    
    // Initialize LFS
    if (execute_git_command(manager->repository_path, "lfs install", output, sizeof(output)) != 0) {
        return ASSET_VCS_ERROR_LFS;
    }
    
    // Configure LFS patterns
    for (uint32_t i = 0; i < config->pattern_count && i < 32; i++) {
        char command[256];
        snprintf(command, sizeof(command), "lfs track \"%s\"", config->file_patterns[i]);
        execute_git_command(manager->repository_path, command, output, sizeof(output));
    }
    
    manager->has_lfs = true;
    return ASSET_VCS_SUCCESS;
}

// Asset version information
int32_t asset_vcs_get_version_info(asset_vcs_manager_t* manager, 
                                  const char* asset_path, 
                                  asset_version_info_t* info) {
    if (!manager || !asset_path || !info) {
        return ASSET_VCS_ERROR_NOT_FOUND;
    }
    
    memset(info, 0, sizeof(asset_version_info_t));
    
    char command[512];
    char output[1024];
    
    // Get file hash
    snprintf(command, sizeof(command), "hash-object \"%s\"", asset_path);
    if (execute_git_command(manager->repository_path, command, output, sizeof(output)) == 0) {
        strncpy(info->hash, output, sizeof(info->hash) - 1);
    }
    
    // Get current branch
    strncpy(info->branch, manager->current_branch, sizeof(info->branch) - 1);
    
    // Get last commit that modified this file
    snprintf(command, sizeof(command), "log -n 1 --format=%%H -- \"%s\"", asset_path);
    if (execute_git_command(manager->repository_path, command, output, sizeof(output)) == 0) {
        strncpy(info->commit_hash, output, sizeof(info->commit_hash) - 1);
        
        // Get commit details
        snprintf(command, sizeof(command), 
                "log -n 1 --format=\"%%an|%%ct|%%s\" %s", info->commit_hash);
        if (execute_git_command(manager->repository_path, command, output, sizeof(output)) == 0) {
            char* author = strtok(output, "|");
            char* timestamp_str = strtok(NULL, "|");
            char* message = strtok(NULL, "|");
            
            if (author) strncpy(info->author, author, sizeof(info->author) - 1);
            if (timestamp_str) info->timestamp = strtoull(timestamp_str, NULL, 10);
            if (message) strncpy(info->commit_message, message, sizeof(info->commit_message) - 1);
        }
    }
    
    // Get file status
    snprintf(command, sizeof(command), "status --porcelain \"%s\"", asset_path);
    if (execute_git_command(manager->repository_path, command, output, sizeof(output)) == 0) {
        if (strlen(output) == 0) {
            info->state = ASSET_VCS_CLEAN;
        } else {
            switch (output[0]) {
                case 'M': info->state = ASSET_VCS_MODIFIED; break;
                case 'A': info->state = ASSET_VCS_ADDED; break;
                case 'D': info->state = ASSET_VCS_DELETED; break;
                case 'R': info->state = ASSET_VCS_RENAMED; break;
                case 'C': info->state = ASSET_VCS_COPIED; break;
                case 'U': info->state = ASSET_VCS_CONFLICTED; break;
                case '?': info->state = ASSET_VCS_UNTRACKED; break;
                default: info->state = ASSET_VCS_MODIFIED; break;
            }
        }
    }
    
    // Check if file is in LFS
    if (manager->has_lfs) {
        snprintf(command, sizeof(command), "lfs ls-files | grep \"%s\"", asset_path);
        if (execute_git_command(manager->repository_path, command, output, sizeof(output)) == 0) {
            info->is_lfs = (strlen(output) > 0);
        }
    }
    
    // Get file size and MIME type
    info->file_size = get_file_size(asset_path);
    
    // Determine MIME type based on file extension
    char* ext = strrchr(asset_path, '.');
    if (ext) {
        if (strcmp(ext, ".png") == 0 || strcmp(ext, ".jpg") == 0 || strcmp(ext, ".jpeg") == 0) {
            strcpy(info->mime_type, "image");
        } else if (strcmp(ext, ".wav") == 0 || strcmp(ext, ".ogg") == 0 || strcmp(ext, ".mp3") == 0) {
            strcpy(info->mime_type, "audio");
        } else if (strcmp(ext, ".glsl") == 0 || strcmp(ext, ".vert") == 0 || strcmp(ext, ".frag") == 0) {
            strcpy(info->mime_type, "shader");
        } else {
            strcpy(info->mime_type, "application/octet-stream");
        }
    }
    
    return ASSET_VCS_SUCCESS;
}

int32_t asset_vcs_get_asset_history(asset_vcs_manager_t* manager,
                                   const char* asset_path,
                                   asset_history_entry_t* history,
                                   uint32_t max_entries) {
    if (!manager || !asset_path || !history || max_entries == 0) {
        return ASSET_VCS_ERROR_NOT_FOUND;
    }
    
    char command[512];
    char output[8192];
    
    snprintf(command, sizeof(command), 
             "log --follow --format=\"%%H|%%an|%%ae|%%ct|%%s|%%P\" -n %u -- \"%s\"",
             max_entries, asset_path);
    
    if (execute_git_command(manager->repository_path, command, output, sizeof(output)) != 0) {
        return ASSET_VCS_ERROR_NOT_FOUND;
    }
    
    char* line = strtok(output, "\n");
    uint32_t count = 0;
    
    while (line && count < max_entries) {
        asset_history_entry_t* entry = &history[count];
        memset(entry, 0, sizeof(asset_history_entry_t));
        
        char* hash = strtok(line, "|");
        char* author = strtok(NULL, "|");
        char* email = strtok(NULL, "|");
        char* timestamp_str = strtok(NULL, "|");
        char* message = strtok(NULL, "|");
        char* parents = strtok(NULL, "|");
        
        if (hash) strncpy(entry->commit_hash, hash, sizeof(entry->commit_hash) - 1);
        if (author) strncpy(entry->author, author, sizeof(entry->author) - 1);
        if (email) strncpy(entry->email, email, sizeof(entry->email) - 1);
        if (timestamp_str) entry->timestamp = strtoull(timestamp_str, NULL, 10);
        if (message) strncpy(entry->message, message, sizeof(entry->message) - 1);
        if (parents) {
            strncpy(entry->parent_hashes, parents, sizeof(entry->parent_hashes) - 1);
            entry->is_merge = (strchr(parents, ' ') != NULL);
        }
        
        // Get file size at this commit
        char size_command[512];
        char size_output[256];
        snprintf(size_command, sizeof(size_command), 
                 "show %s:\"%s\" | wc -c", hash, asset_path);
        if (execute_git_command(manager->repository_path, size_command, size_output, sizeof(size_output)) == 0) {
            entry->file_size = strtoull(size_output, NULL, 10);
        }
        
        count++;
        line = strtok(NULL, "\n");
    }
    
    return count;
}

// Asset staging and committing
int32_t asset_vcs_stage_asset(asset_vcs_manager_t* manager, const char* asset_path) {
    if (!manager || !asset_path) {
        return ASSET_VCS_ERROR_NOT_FOUND;
    }
    
    char command[512];
    char output[256];
    
    snprintf(command, sizeof(command), "add \"%s\"", asset_path);
    
    uint64_t start_time = (uint64_t)time(NULL) * 1000;
    int32_t result = execute_git_command(manager->repository_path, command, output, sizeof(output));
    uint64_t duration = (uint64_t)time(NULL) * 1000 - start_time;
    
    update_metrics("stage_asset", result == 0, duration);
    
    return (result == 0) ? ASSET_VCS_SUCCESS : ASSET_VCS_ERROR_INVALID_REPO;
}

int32_t asset_vcs_commit_assets(asset_vcs_manager_t* manager,
                               const char* message,
                               const char* author,
                               const char* email) {
    if (!manager || !message) {
        return ASSET_VCS_ERROR_INVALID_REPO;
    }
    
    char command[1024];
    char output[512];
    
    if (author && email) {
        snprintf(command, sizeof(command), 
                 "commit -m \"%s\" --author=\"%s <%s>\"", message, author, email);
    } else {
        snprintf(command, sizeof(command), "commit -m \"%s\"", message);
    }
    
    uint64_t start_time = (uint64_t)time(NULL) * 1000;
    int32_t result = execute_git_command(manager->repository_path, command, output, sizeof(output));
    uint64_t duration = (uint64_t)time(NULL) * 1000 - start_time;
    
    pthread_mutex_lock(&g_metrics_mutex);
    if (result == 0) {
        g_vcs_metrics.successful_commits++;
    } else {
        g_vcs_metrics.failed_commits++;
    }
    g_vcs_metrics.avg_commit_time_ms = 
        (g_vcs_metrics.avg_commit_time_ms + duration) / 2;
    pthread_mutex_unlock(&g_metrics_mutex);
    
    return (result == 0) ? ASSET_VCS_SUCCESS : ASSET_VCS_ERROR_INVALID_REPO;
}

// Utility functions
bool asset_vcs_is_tracked(asset_vcs_manager_t* manager, const char* asset_path) {
    if (!manager || !asset_path) return false;
    
    char command[512];
    char output[256];
    
    snprintf(command, sizeof(command), "ls-files \"%s\"", asset_path);
    if (execute_git_command(manager->repository_path, command, output, sizeof(output)) == 0) {
        return (strlen(output) > 0);
    }
    
    return false;
}

bool asset_vcs_is_modified(asset_vcs_manager_t* manager, const char* asset_path) {
    if (!manager || !asset_path) return false;
    
    char command[512];
    char output[256];
    
    snprintf(command, sizeof(command), "diff --name-only \"%s\"", asset_path);
    if (execute_git_command(manager->repository_path, command, output, sizeof(output)) == 0) {
        return (strlen(output) > 0);
    }
    
    return false;
}

// Performance monitoring
void asset_vcs_get_metrics(asset_vcs_manager_t* manager, asset_vcs_metrics_t* metrics) {
    if (!metrics) return;
    
    pthread_mutex_lock(&g_metrics_mutex);
    *metrics = g_vcs_metrics;
    pthread_mutex_unlock(&g_metrics_mutex);
    
    if (manager) {
        // Update repository-specific metrics
        char command[512];
        char output[256];
        
        // Get repository size
        snprintf(command, sizeof(command), "count-objects -vH");
        if (execute_git_command(manager->repository_path, command, output, sizeof(output)) == 0) {
            char* size_line = strstr(output, "size-pack");
            if (size_line) {
                metrics->repository_size = strtoull(strchr(size_line, ' '), NULL, 10);
            }
        }
        
        // Get LFS size if available
        if (manager->has_lfs) {
            if (execute_git_command(manager->repository_path, "lfs ls-files -s", output, sizeof(output)) == 0) {
                // Simple approximation - count lines and estimate
                uint32_t file_count = 0;
                char* line = strtok(output, "\n");
                while (line) {
                    file_count++;
                    line = strtok(NULL, "\n");
                }
                metrics->lfs_size = file_count * 1024 * 1024; // Rough estimate
            }
        }
    }
}

void asset_vcs_reset_metrics(asset_vcs_manager_t* manager) {
    pthread_mutex_lock(&g_metrics_mutex);
    memset(&g_vcs_metrics, 0, sizeof(g_vcs_metrics));
    pthread_mutex_unlock(&g_metrics_mutex);
}

// Internal utility functions implementation
static int32_t execute_git_command(const char* repo_path, const char* command, char* output, size_t output_size) {
    if (!repo_path || !command || !output) {
        return -1;
    }
    
    char full_command[1024];
    snprintf(full_command, sizeof(full_command), "cd \"%s\" && git %s 2>/dev/null", repo_path, command);
    
    FILE* pipe = popen(full_command, "r");
    if (!pipe) {
        return -1;
    }
    
    size_t bytes_read = fread(output, 1, output_size - 1, pipe);
    output[bytes_read] = '\0';
    
    // Remove trailing newline
    if (bytes_read > 0 && output[bytes_read - 1] == '\n') {
        output[bytes_read - 1] = '\0';
    }
    
    int32_t result = pclose(pipe);
    
    pthread_mutex_lock(&g_metrics_mutex);
    g_vcs_metrics.total_operations++;
    pthread_mutex_unlock(&g_metrics_mutex);
    
    return WEXITSTATUS(result);
}

static bool file_exists(const char* path) {
    return (access(path, F_OK) == 0);
}

static bool directory_exists(const char* path) {
    struct stat st;
    return (stat(path, &st) == 0 && S_ISDIR(st.st_mode));
}

static int32_t create_directory_recursive(const char* path) {
    char* path_copy = strdup(path);
    char* dir = dirname(path_copy);
    
    if (!directory_exists(dir)) {
        create_directory_recursive(dir);
    }
    
    int32_t result = mkdir(path, 0755);
    free(path_copy);
    
    return result;
}

static uint64_t get_file_size(const char* file_path) {
    struct stat st;
    if (stat(file_path, &st) == 0) {
        return st.st_size;
    }
    return 0;
}

static int32_t update_metrics(const char* operation, bool success, uint64_t duration_ms) {
    pthread_mutex_lock(&g_metrics_mutex);
    g_vcs_metrics.total_operations++;
    // Update operation-specific metrics based on operation type
    pthread_mutex_unlock(&g_metrics_mutex);
    return 0;
}