/*
 * SimCity ARM64 - Asset Dependency Tracker
 * Tracks dependencies between assets for intelligent hot-reload
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Day 1: Dependency Tracking System Implementation
 * 
 * Features:
 * - Dependency graph resolution
 * - Circular dependency detection
 * - Integrity validation
 * - Cascade reload support
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <assert.h>
#include <mach/mach_time.h>
#include "asset_watcher.h"
#include "module_interface.h"

// Maximum dependency depth to prevent infinite recursion
#define HMR_MAX_DEPENDENCY_DEPTH 16

// Dependency graph node
typedef struct hmr_dependency_node {
    char asset_path[256];               // Path to the asset
    hmr_asset_type_t asset_type;        // Type of asset
    uint64_t content_hash;              // Current content hash
    uint32_t dependency_count;          // Number of direct dependencies
    struct hmr_dependency_node** dependencies; // Array of dependency pointers
    uint32_t dependent_count;           // Number of assets depending on this
    struct hmr_dependency_node** dependents; // Array of dependent pointers
    bool needs_reload;                  // Whether this asset needs reloading
    bool is_reloading;                  // Whether currently being reloaded
    uint32_t reload_order;              // Order in reload sequence
    uint64_t last_modified;             // Last modification timestamp
    bool is_critical;                   // Whether this asset is critical
    uint32_t reference_count;           // Reference counting for cleanup
} hmr_dependency_node_t;

// Dependency tracker state
typedef struct {
    hmr_dependency_node_t** nodes;     // Array of all nodes
    uint32_t node_count;               // Current number of nodes
    uint32_t node_capacity;            // Maximum number of nodes
    uint32_t reload_sequence_id;       // Current reload sequence identifier
    bool has_circular_dependency;      // Whether circular dependencies detected
    char error_message[512];           // Last error message
    
    // Performance metrics
    uint64_t total_dependency_checks;  // Total dependency validations
    uint64_t circular_checks_performed; // Circular dependency checks
    uint64_t cascade_reloads_triggered; // Number of cascade reloads
    uint64_t avg_resolution_time_ns;   // Average resolution time
} hmr_dependency_tracker_t;

// Global dependency tracker
static hmr_dependency_tracker_t* g_dependency_tracker = NULL;

// Initialize dependency tracker
int32_t hmr_dependency_tracker_init(uint32_t max_assets) {
    if (g_dependency_tracker) {
        return HMR_ERROR_ALREADY_EXISTS;
    }
    
    g_dependency_tracker = calloc(1, sizeof(hmr_dependency_tracker_t));
    if (!g_dependency_tracker) {
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    g_dependency_tracker->node_capacity = max_assets;
    g_dependency_tracker->nodes = calloc(max_assets, sizeof(hmr_dependency_node_t*));
    if (!g_dependency_tracker->nodes) {
        free(g_dependency_tracker);
        g_dependency_tracker = NULL;
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    printf("HMR Dependency Tracker: Initialized with capacity for %u assets\n", max_assets);
    return HMR_SUCCESS;
}

// Find dependency node by path
static hmr_dependency_node_t* hmr_find_dependency_node(const char* path) {
    if (!g_dependency_tracker || !path) return NULL;
    
    for (uint32_t i = 0; i < g_dependency_tracker->node_count; i++) {
        if (g_dependency_tracker->nodes[i] && 
            strcmp(g_dependency_tracker->nodes[i]->asset_path, path) == 0) {
            return g_dependency_tracker->nodes[i];
        }
    }
    
    return NULL;
}

// Create new dependency node
static hmr_dependency_node_t* hmr_create_dependency_node(const char* path, hmr_asset_type_t type) {
    if (!g_dependency_tracker || !path) return NULL;
    
    if (g_dependency_tracker->node_count >= g_dependency_tracker->node_capacity) {
        snprintf(g_dependency_tracker->error_message, sizeof(g_dependency_tracker->error_message),
                "Maximum dependency node capacity reached: %u", g_dependency_tracker->node_capacity);
        return NULL;
    }
    
    hmr_dependency_node_t* node = calloc(1, sizeof(hmr_dependency_node_t));
    if (!node) {
        snprintf(g_dependency_tracker->error_message, sizeof(g_dependency_tracker->error_message),
                "Failed to allocate memory for dependency node");
        return NULL;
    }
    
    strncpy(node->asset_path, path, sizeof(node->asset_path) - 1);
    node->asset_type = type;
    node->reference_count = 1;
    
    // Add to tracker
    g_dependency_tracker->nodes[g_dependency_tracker->node_count++] = node;
    
    printf("HMR Dependency: Created node for %s (type: %d)\n", path, type);
    return node;
}

// Add dependency relationship
int32_t hmr_dependency_add(const char* asset_path, const char* dependency_path, bool is_critical) {
    if (!g_dependency_tracker || !asset_path || !dependency_path) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    uint64_t start_time = mach_absolute_time();
    
    // Find or create asset node
    hmr_dependency_node_t* asset_node = hmr_find_dependency_node(asset_path);
    if (!asset_node) {
        asset_node = hmr_create_dependency_node(asset_path, HMR_ASSET_UNKNOWN);
        if (!asset_node) {
            return HMR_ERROR_OUT_OF_MEMORY;
        }
    }
    
    // Find or create dependency node
    hmr_dependency_node_t* dep_node = hmr_find_dependency_node(dependency_path);
    if (!dep_node) {
        dep_node = hmr_create_dependency_node(dependency_path, HMR_ASSET_UNKNOWN);
        if (!dep_node) {
            return HMR_ERROR_OUT_OF_MEMORY;
        }
    }
    
    // Check if dependency already exists
    for (uint32_t i = 0; i < asset_node->dependency_count; i++) {
        if (asset_node->dependencies[i] == dep_node) {
            // Dependency already exists
            return HMR_SUCCESS;
        }
    }
    
    // Add dependency to asset node
    hmr_dependency_node_t** new_deps = realloc(asset_node->dependencies, 
                                               (asset_node->dependency_count + 1) * sizeof(hmr_dependency_node_t*));
    if (!new_deps) {
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    asset_node->dependencies = new_deps;
    asset_node->dependencies[asset_node->dependency_count++] = dep_node;
    
    // Add dependent to dependency node
    hmr_dependency_node_t** new_dependents = realloc(dep_node->dependents,
                                                     (dep_node->dependent_count + 1) * sizeof(hmr_dependency_node_t*));
    if (!new_dependents) {
        // Rollback the dependency addition
        asset_node->dependency_count--;
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    dep_node->dependents = new_dependents;
    dep_node->dependents[dep_node->dependent_count++] = asset_node;
    dep_node->is_critical = is_critical;
    dep_node->reference_count++;
    
    // Calculate resolution time
    uint64_t end_time = mach_absolute_time();
    static mach_timebase_info_data_t timebase_info;
    if (timebase_info.denom == 0) {
        mach_timebase_info(&timebase_info);
    }
    uint64_t resolution_time = (end_time - start_time) * timebase_info.numer / timebase_info.denom;
    
    g_dependency_tracker->total_dependency_checks++;
    g_dependency_tracker->avg_resolution_time_ns = 
        (g_dependency_tracker->avg_resolution_time_ns + resolution_time) / 2;
    
    printf("HMR Dependency: Added %s -> %s (critical: %s)\n", 
           asset_path, dependency_path, is_critical ? "yes" : "no");
    
    return HMR_SUCCESS;
}

// Remove dependency relationship
int32_t hmr_dependency_remove(const char* asset_path, const char* dependency_path) {
    if (!g_dependency_tracker || !asset_path || !dependency_path) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    hmr_dependency_node_t* asset_node = hmr_find_dependency_node(asset_path);
    hmr_dependency_node_t* dep_node = hmr_find_dependency_node(dependency_path);
    
    if (!asset_node || !dep_node) {
        return HMR_ERROR_NOT_FOUND;
    }
    
    // Remove from asset's dependencies
    for (uint32_t i = 0; i < asset_node->dependency_count; i++) {
        if (asset_node->dependencies[i] == dep_node) {
            // Shift remaining dependencies
            memmove(&asset_node->dependencies[i], &asset_node->dependencies[i + 1],
                   (asset_node->dependency_count - i - 1) * sizeof(hmr_dependency_node_t*));
            asset_node->dependency_count--;
            break;
        }
    }
    
    // Remove from dependency's dependents
    for (uint32_t i = 0; i < dep_node->dependent_count; i++) {
        if (dep_node->dependents[i] == asset_node) {
            // Shift remaining dependents
            memmove(&dep_node->dependents[i], &dep_node->dependents[i + 1],
                   (dep_node->dependent_count - i - 1) * sizeof(hmr_dependency_node_t*));
            dep_node->dependent_count--;
            dep_node->reference_count--;
            break;
        }
    }
    
    printf("HMR Dependency: Removed %s -> %s\n", asset_path, dependency_path);
    return HMR_SUCCESS;
}

// Check for circular dependencies using DFS
static bool hmr_check_circular_dependency_recursive(hmr_dependency_node_t* node, 
                                                   hmr_dependency_node_t** visited_stack,
                                                   uint32_t stack_depth) {
    if (stack_depth >= HMR_MAX_DEPENDENCY_DEPTH) {
        return true; // Assume circular if too deep
    }
    
    // Check if node is already in the visited stack
    for (uint32_t i = 0; i < stack_depth; i++) {
        if (visited_stack[i] == node) {
            return true; // Circular dependency found
        }
    }
    
    // Add current node to stack
    visited_stack[stack_depth] = node;
    
    // Check all dependencies
    for (uint32_t i = 0; i < node->dependency_count; i++) {
        if (hmr_check_circular_dependency_recursive(node->dependencies[i], visited_stack, stack_depth + 1)) {
            return true;
        }
    }
    
    return false;
}

// Check for circular dependencies in the entire graph
bool hmr_dependency_check_circular(void) {
    if (!g_dependency_tracker) return false;
    
    g_dependency_tracker->circular_checks_performed++;
    
    hmr_dependency_node_t* visited_stack[HMR_MAX_DEPENDENCY_DEPTH];
    
    for (uint32_t i = 0; i < g_dependency_tracker->node_count; i++) {
        hmr_dependency_node_t* node = g_dependency_tracker->nodes[i];
        if (node && hmr_check_circular_dependency_recursive(node, visited_stack, 0)) {
            g_dependency_tracker->has_circular_dependency = true;
            snprintf(g_dependency_tracker->error_message, sizeof(g_dependency_tracker->error_message),
                    "Circular dependency detected involving asset: %s", node->asset_path);
            return true;
        }
    }
    
    g_dependency_tracker->has_circular_dependency = false;
    return false;
}

// Get assets that need to be reloaded due to dependency changes
int32_t hmr_dependency_get_reload_order(const char* changed_asset, const char** reload_list, 
                                       uint32_t max_count, uint32_t* actual_count) {
    if (!g_dependency_tracker || !changed_asset || !reload_list || !actual_count) {
        return HMR_ERROR_INVALID_ARG;
    }
    
    *actual_count = 0;
    
    hmr_dependency_node_t* changed_node = hmr_find_dependency_node(changed_asset);
    if (!changed_node) {
        return HMR_ERROR_NOT_FOUND;
    }
    
    // Mark the changed asset for reload
    changed_node->needs_reload = true;
    changed_node->reload_order = 0;
    
    // Use breadth-first traversal to determine reload order
    hmr_dependency_node_t* queue[1024]; // Simple queue for BFS
    uint32_t queue_head = 0, queue_tail = 0;
    uint32_t current_order = 1;
    
    // Add all direct dependents to queue
    for (uint32_t i = 0; i < changed_node->dependent_count; i++) {
        hmr_dependency_node_t* dependent = changed_node->dependents[i];
        if (!dependent->needs_reload) {
            dependent->needs_reload = true;
            dependent->reload_order = current_order;
            queue[queue_tail++] = dependent;
        }
    }
    
    // Process queue
    while (queue_head < queue_tail && current_order < max_count) {
        hmr_dependency_node_t* current = queue[queue_head++];
        
        // Add to reload list
        if (*actual_count < max_count) {
            reload_list[*actual_count] = current->asset_path;
            (*actual_count)++;
        }
        
        // Add dependents of current node
        current_order++;
        for (uint32_t i = 0; i < current->dependent_count; i++) {
            hmr_dependency_node_t* dependent = current->dependents[i];
            if (!dependent->needs_reload) {
                dependent->needs_reload = true;
                dependent->reload_order = current_order;
                if (queue_tail < sizeof(queue) / sizeof(queue[0])) {
                    queue[queue_tail++] = dependent;
                }
            }
        }
    }
    
    // Add the original changed asset at the beginning
    if (*actual_count < max_count) {
        // Shift all elements to make room
        memmove(&reload_list[1], &reload_list[0], (*actual_count) * sizeof(const char*));
        reload_list[0] = changed_asset;
        (*actual_count)++;
    }
    
    g_dependency_tracker->cascade_reloads_triggered++;
    
    printf("HMR Dependency: Cascade reload order determined for %s (%u assets affected)\n", 
           changed_asset, *actual_count);
    
    return HMR_SUCCESS;
}

// Validate integrity of all dependencies
int32_t hmr_dependency_validate_integrity(void) {
    if (!g_dependency_tracker) {
        return HMR_ERROR_NULL_POINTER;
    }
    
    uint32_t errors = 0;
    
    for (uint32_t i = 0; i < g_dependency_tracker->node_count; i++) {
        hmr_dependency_node_t* node = g_dependency_tracker->nodes[i];
        if (!node) continue;
        
        // Check that all dependency pointers are valid
        for (uint32_t j = 0; j < node->dependency_count; j++) {
            hmr_dependency_node_t* dep = node->dependencies[j];
            if (!dep) {
                printf("HMR Dependency: Invalid dependency pointer in %s\n", node->asset_path);
                errors++;
                continue;
            }
            
            // Check bidirectional relationship
            bool found_reverse = false;
            for (uint32_t k = 0; k < dep->dependent_count; k++) {
                if (dep->dependents[k] == node) {
                    found_reverse = true;
                    break;
                }
            }
            
            if (!found_reverse) {
                printf("HMR Dependency: Missing reverse dependency: %s -> %s\n", 
                       node->asset_path, dep->asset_path);
                errors++;
            }
        }
        
        // Check that all dependent pointers are valid
        for (uint32_t j = 0; j < node->dependent_count; j++) {
            hmr_dependency_node_t* dependent = node->dependents[j];
            if (!dependent) {
                printf("HMR Dependency: Invalid dependent pointer in %s\n", node->asset_path);
                errors++;
                continue;
            }
            
            // Check bidirectional relationship
            bool found_forward = false;
            for (uint32_t k = 0; k < dependent->dependency_count; k++) {
                if (dependent->dependencies[k] == node) {
                    found_forward = true;
                    break;
                }
            }
            
            if (!found_forward) {
                printf("HMR Dependency: Missing forward dependency: %s -> %s\n", 
                       dependent->asset_path, node->asset_path);
                errors++;
            }
        }
    }
    
    if (errors > 0) {
        snprintf(g_dependency_tracker->error_message, sizeof(g_dependency_tracker->error_message),
                "Dependency integrity validation failed with %u errors", errors);
        return HMR_ERROR_INVALID_ARG;
    }
    
    printf("HMR Dependency: Integrity validation passed for %u nodes\n", g_dependency_tracker->node_count);
    return HMR_SUCCESS;
}

// Get dependency tracker statistics
void hmr_dependency_get_stats(uint32_t* total_nodes, uint32_t* total_edges, 
                             bool* has_circular, uint64_t* avg_resolution_time) {
    if (!g_dependency_tracker) return;
    
    if (total_nodes) {
        *total_nodes = g_dependency_tracker->node_count;
    }
    
    if (total_edges) {
        uint32_t edges = 0;
        for (uint32_t i = 0; i < g_dependency_tracker->node_count; i++) {
            if (g_dependency_tracker->nodes[i]) {
                edges += g_dependency_tracker->nodes[i]->dependency_count;
            }
        }
        *total_edges = edges;
    }
    
    if (has_circular) {
        *has_circular = g_dependency_tracker->has_circular_dependency;
    }
    
    if (avg_resolution_time) {
        *avg_resolution_time = g_dependency_tracker->avg_resolution_time_ns;
    }
}

// Cleanup dependency tracker
void hmr_dependency_tracker_cleanup(void) {
    if (!g_dependency_tracker) return;
    
    // Free all nodes and their dependencies
    for (uint32_t i = 0; i < g_dependency_tracker->node_count; i++) {
        hmr_dependency_node_t* node = g_dependency_tracker->nodes[i];
        if (node) {
            if (node->dependencies) {
                free(node->dependencies);
            }
            if (node->dependents) {
                free(node->dependents);
            }
            free(node);
        }
    }
    
    if (g_dependency_tracker->nodes) {
        free(g_dependency_tracker->nodes);
    }
    
    free(g_dependency_tracker);
    g_dependency_tracker = NULL;
    
    printf("HMR Dependency Tracker: Cleanup complete\n");
}