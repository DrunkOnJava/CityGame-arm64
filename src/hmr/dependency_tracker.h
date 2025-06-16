/*
 * SimCity ARM64 - Asset Dependency Tracker Header
 * Dependency graph management for intelligent hot-reload
 * 
 * Agent 5: Asset Pipeline & Advanced Features
 * Day 1: Dependency Tracking Interface
 */

#ifndef HMR_DEPENDENCY_TRACKER_H
#define HMR_DEPENDENCY_TRACKER_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize dependency tracker system
int32_t hmr_dependency_tracker_init(uint32_t max_assets);

// Add/remove dependency relationships
int32_t hmr_dependency_add(const char* asset_path, const char* dependency_path, bool is_critical);
int32_t hmr_dependency_remove(const char* asset_path, const char* dependency_path);

// Dependency analysis
bool hmr_dependency_check_circular(void);
int32_t hmr_dependency_get_reload_order(const char* changed_asset, const char** reload_list, 
                                       uint32_t max_count, uint32_t* actual_count);

// Validation and maintenance
int32_t hmr_dependency_validate_integrity(void);

// Statistics and monitoring
void hmr_dependency_get_stats(uint32_t* total_nodes, uint32_t* total_edges, 
                             bool* has_circular, uint64_t* avg_resolution_time);

// Cleanup
void hmr_dependency_tracker_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif // HMR_DEPENDENCY_TRACKER_H