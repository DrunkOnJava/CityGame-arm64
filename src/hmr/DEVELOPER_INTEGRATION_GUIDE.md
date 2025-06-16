# SimCity ARM64 Developer Integration Guide

**SimCity ARM64 - Hot-Reload Integration & State Management**  
**Agent 3: Runtime Integration - Day 17 Documentation**  
**Version: 1.0.0 Production Ready**

## Table of Contents

- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Hot-Reload Integration](#hot-reload-integration)
- [State Management](#state-management)
- [Advanced Patterns](#advanced-patterns)
- [Testing and Debugging](#testing-and-debugging)
- [Performance Optimization](#performance-optimization)
- [Common Patterns](#common-patterns)
- [Troubleshooting](#troubleshooting)

## Getting Started

### Prerequisites

- **Development Environment**: Xcode 14+ or clang with ARM64 support
- **Target Platform**: macOS 11+ with Apple Silicon (M1/M2/M3)
- **Runtime Version**: SimCity ARM64 Runtime 1.0.0+
- **Build System**: Make or CMake with ARM64 configuration

### Quick Setup

1. **Include Runtime Headers**
```c
#include "runtime_api.h"
#include "hot_reload.h"
#include "state_manager.h"
```

2. **Link Runtime Libraries**
```makefile
LDFLAGS += -lsimcity_runtime -lhot_reload -lstate_manager
```

3. **Initialize Runtime**
```c
int main(void) {
    runtime_config_t config = {
        .hot_reload_threads = 4,
        .enable_transactions = true,
        .enable_performance_monitoring = true
    };
    
    if (runtime_init(&config) != 0) {
        fprintf(stderr, "Failed to initialize runtime\n");
        return -1;
    }
    
    // Your application code here
    
    runtime_shutdown();
    return 0;
}
```

## Development Workflow

### Recommended Development Cycle

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Code Change   │───▶│   Build Module  │───▶│   Hot-Reload    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                        │                        │
         │                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Fix Issues    │◀───│   Validate      │◀───│   Test & Debug  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Live Development Setup

1. **Enable Development Mode**
```c
runtime_config_t dev_config = {
    .hot_reload_threads = 8,
    .enable_transactions = true,
    .enable_debug_output = true,
    .log_level = LOG_LEVEL_DEBUG,
    .enable_auto_recovery = true
};

runtime_init(&dev_config);
```

2. **Setup File Watching**
```c
// Enable automatic file watching for development
file_watcher_config_t watcher_config = {
    .watch_directories = {
        "/project/src/modules/",
        "/project/build/modules/"
    },
    .watch_extensions = {".so", ".dylib", ".a"},
    .auto_reload_on_change = true,
    .validation_before_reload = true
};

file_watcher_start(&watcher_config);
```

3. **Development Build Script**
```bash
#!/bin/bash
# dev_build.sh - Continuous development build

MODULE_NAME=$1
SRC_DIR="/project/src/modules/${MODULE_NAME}"
BUILD_DIR="/project/build/modules"

# Watch for changes and rebuild
fswatch -o "${SRC_DIR}" | while read f; do
    echo "Rebuilding ${MODULE_NAME}..."
    
    # Build module with debug symbols
    clang -shared -fPIC -g -O0 \
        -target arm64-apple-macos11 \
        -I/project/include \
        -o "${BUILD_DIR}/${MODULE_NAME}.so" \
        "${SRC_DIR}"/*.c
    
    # Trigger hot-reload if build successful
    if [ $? -eq 0 ]; then
        echo "Hot-reloading ${MODULE_NAME}..."
        /project/tools/hot_reload_trigger "${BUILD_DIR}/${MODULE_NAME}.so"
    else
        echo "Build failed for ${MODULE_NAME}"
    fi
done
```

## Hot-Reload Integration

### Module Structure for Hot-Reload

#### 1. Module Interface Definition

```c
// module_interface.h
#ifndef MODULE_INTERFACE_H
#define MODULE_INTERFACE_H

#include <stdint.h>

// Module metadata
typedef struct {
    const char* name;
    const char* version;
    uint32_t api_version;
    uint64_t build_timestamp;
} module_info_t;

// Module function table
typedef struct {
    // Lifecycle functions
    int (*init)(void* config);
    int (*shutdown)(void);
    int (*update)(double delta_time);
    
    // State management
    int (*save_state)(void** state_data, size_t* state_size);
    int (*load_state)(const void* state_data, size_t state_size);
    int (*migrate_state)(uint32_t from_version, uint32_t to_version, 
                        void** state_data, size_t* state_size);
    
    // Hot-reload support
    int (*prepare_reload)(void);
    int (*complete_reload)(void);
    int (*rollback_reload)(void);
    
    // Module-specific functions
    void* function_table;
} module_vtable_t;

// Module entry point
typedef struct {
    module_info_t info;
    module_vtable_t vtable;
} module_interface_t;

// Export function that runtime will call
extern module_interface_t* get_module_interface(void);

#endif
```

#### 2. Example Module Implementation

```c
// graphics_module.c
#include "module_interface.h"
#include "graphics_api.h"

// Module state structure
typedef struct {
    graphics_context_t* context;
    render_pipeline_t* pipeline;
    uint32_t frame_count;
    bool initialized;
} graphics_state_t;

static graphics_state_t g_graphics_state = {0};

// Module lifecycle functions
static int graphics_init(void* config) {
    graphics_config_t* gfx_config = (graphics_config_t*)config;
    
    g_graphics_state.context = graphics_create_context(gfx_config);
    if (!g_graphics_state.context) {
        return -1;
    }
    
    g_graphics_state.pipeline = graphics_create_pipeline(g_graphics_state.context);
    if (!g_graphics_state.pipeline) {
        graphics_destroy_context(g_graphics_state.context);
        return -1;
    }
    
    g_graphics_state.frame_count = 0;
    g_graphics_state.initialized = true;
    
    printf("Graphics module initialized (version 1.2.0)\n");
    return 0;
}

static int graphics_shutdown(void) {
    if (g_graphics_state.initialized) {
        graphics_destroy_pipeline(g_graphics_state.pipeline);
        graphics_destroy_context(g_graphics_state.context);
        memset(&g_graphics_state, 0, sizeof(graphics_state_t));
    }
    
    printf("Graphics module shutdown\n");
    return 0;
}

static int graphics_update(double delta_time) {
    if (!g_graphics_state.initialized) {
        return -1;
    }
    
    // Update graphics system
    graphics_begin_frame(g_graphics_state.context);
    graphics_render_frame(g_graphics_state.pipeline, delta_time);
    graphics_end_frame(g_graphics_state.context);
    
    g_graphics_state.frame_count++;
    return 0;
}

// State management functions
static int graphics_save_state(void** state_data, size_t* state_size) {
    *state_size = sizeof(graphics_state_t);
    *state_data = malloc(*state_size);
    
    if (!*state_data) {
        return -1;
    }
    
    memcpy(*state_data, &g_graphics_state, *state_size);
    printf("Graphics state saved (%zu bytes)\n", *state_size);
    return 0;
}

static int graphics_load_state(const void* state_data, size_t state_size) {
    if (state_size != sizeof(graphics_state_t)) {
        printf("Graphics state size mismatch: expected %zu, got %zu\n", 
               sizeof(graphics_state_t), state_size);
        return -1;
    }
    
    memcpy(&g_graphics_state, state_data, state_size);
    printf("Graphics state loaded (%zu bytes)\n", state_size);
    return 0;
}

static int graphics_migrate_state(uint32_t from_version, uint32_t to_version,
                                 void** state_data, size_t* state_size) {
    printf("Migrating graphics state from version %u to %u\n", from_version, to_version);
    
    // Handle version-specific migration logic
    if (from_version == 1 && to_version == 2) {
        // Add new fields, migrate data structure
        // ... migration logic here ...
        return 0;
    }
    
    return -1; // Unsupported migration
}

// Hot-reload support functions
static int graphics_prepare_reload(void) {
    printf("Preparing graphics module for reload...\n");
    
    // Pause rendering, save critical state
    graphics_pause_rendering(g_graphics_state.context);
    
    return 0;
}

static int graphics_complete_reload(void) {
    printf("Completing graphics module reload...\n");
    
    // Resume rendering, validate state
    graphics_resume_rendering(g_graphics_state.context);
    
    return 0;
}

static int graphics_rollback_reload(void) {
    printf("Rolling back graphics module reload...\n");
    
    // Restore previous state
    graphics_resume_rendering(g_graphics_state.context);
    
    return 0;
}

// Graphics-specific API functions
static graphics_api_t graphics_api = {
    .render_sprite = graphics_render_sprite,
    .create_texture = graphics_create_texture,
    .destroy_texture = graphics_destroy_texture,
    .set_camera = graphics_set_camera
};

// Module interface export
static module_interface_t graphics_interface = {
    .info = {
        .name = "graphics",
        .version = "1.2.0",
        .api_version = 1,
        .build_timestamp = __TIMESTAMP__
    },
    .vtable = {
        .init = graphics_init,
        .shutdown = graphics_shutdown,
        .update = graphics_update,
        .save_state = graphics_save_state,
        .load_state = graphics_load_state,
        .migrate_state = graphics_migrate_state,
        .prepare_reload = graphics_prepare_reload,
        .complete_reload = graphics_complete_reload,
        .rollback_reload = graphics_rollback_reload,
        .function_table = &graphics_api
    }
};

// Entry point for runtime
module_interface_t* get_module_interface(void) {
    return &graphics_interface;
}
```

### Hot-Reload Integration in Host Application

```c
// main_application.c
#include "runtime_api.h"
#include "module_loader.h"

typedef struct {
    module_interface_t* graphics_module;
    module_interface_t* audio_module;
    module_interface_t* simulation_module;
    // ... other modules
} application_modules_t;

static application_modules_t g_modules = {0};

int application_load_modules(void) {
    // Load graphics module
    module_load_info_t graphics_load = {
        .module_path = "/app/modules/graphics.so",
        .config_data = &graphics_config,
        .config_size = sizeof(graphics_config),
        .enable_hot_reload = true
    };
    
    g_modules.graphics_module = module_loader_load(&graphics_load);
    if (!g_modules.graphics_module) {
        printf("Failed to load graphics module\n");
        return -1;
    }
    
    // Initialize module
    if (g_modules.graphics_module->vtable.init(&graphics_config) != 0) {
        printf("Failed to initialize graphics module\n");
        return -1;
    }
    
    // Load other modules similarly...
    
    printf("All modules loaded successfully\n");
    return 0;
}

int application_hot_reload_module(const char* module_name, const char* module_path) {
    printf("Hot-reloading module: %s\n", module_name);
    
    // Setup hot-reload configuration
    hot_reload_config_t reload_config = {
        .validate_before_reload = true,
        .backup_current_state = true,
        .use_transactions = true,
        .rollback_on_failure = true,
        .progress_callback = hot_reload_progress_callback
    };
    
    // Begin transaction for safe reload
    transaction_id_t tx_id;
    if (transaction_begin(&tx_id, ISOLATION_SERIALIZABLE) != 0) {
        printf("Failed to begin hot-reload transaction\n");
        return -1;
    }
    
    // Perform hot-reload
    int result = hot_reload_module(module_path, &reload_config);
    
    if (result == 0) {
        // Commit successful reload
        if (transaction_commit(tx_id) != 0) {
            printf("Failed to commit hot-reload transaction\n");
            return -1;
        }
        printf("Hot-reload successful: %s\n", module_name);
    } else {
        // Rollback failed reload
        transaction_rollback(tx_id);
        printf("Hot-reload failed, rolled back: %s\n", module_name);
        return -1;
    }
    
    return 0;
}

void hot_reload_progress_callback(const char* module_path, uint32_t progress_percent) {
    printf("Hot-reload progress for %s: %u%%\n", module_path, progress_percent);
}

int application_main_loop(void) {
    double last_time = get_current_time();
    
    while (application_is_running()) {
        double current_time = get_current_time();
        double delta_time = current_time - last_time;
        last_time = current_time;
        
        // Update all modules
        if (g_modules.graphics_module) {
            g_modules.graphics_module->vtable.update(delta_time);
        }
        
        if (g_modules.audio_module) {
            g_modules.audio_module->vtable.update(delta_time);
        }
        
        if (g_modules.simulation_module) {
            g_modules.simulation_module->vtable.update(delta_time);
        }
        
        // Process runtime events (including hot-reload requests)
        runtime_process_events();
        
        // Sleep to maintain target frame rate
        usleep(16667); // ~60 FPS
    }
    
    return 0;
}
```

## State Management

### Advanced State Management Patterns

#### 1. Hierarchical State Management

```c
// state_manager.h
typedef struct state_node state_node_t;

struct state_node {
    const char* name;
    void* data;
    size_t data_size;
    uint32_t version;
    uint64_t timestamp;
    
    state_node_t* parent;
    state_node_t* children;
    state_node_t* next_sibling;
    
    // State callbacks
    int (*serialize)(const state_node_t* node, void** data, size_t* size);
    int (*deserialize)(state_node_t* node, const void* data, size_t size);
    int (*validate)(const state_node_t* node);
    int (*migrate)(state_node_t* node, uint32_t from_version, uint32_t to_version);
};

typedef struct {
    state_node_t* root;
    pthread_rwlock_t lock;
    uint64_t generation;
} state_tree_t;

// State management API
int state_tree_create(state_tree_t** tree);
int state_tree_destroy(state_tree_t* tree);
int state_tree_add_node(state_tree_t* tree, const char* path, 
                       const state_node_t* node_template);
int state_tree_remove_node(state_tree_t* tree, const char* path);
int state_tree_get_node(state_tree_t* tree, const char* path, state_node_t** node);
int state_tree_save_snapshot(state_tree_t* tree, const char* snapshot_path);
int state_tree_load_snapshot(state_tree_t* tree, const char* snapshot_path);
```

#### 2. State Versioning and Migration

```c
// state_versioning.c
typedef struct {
    uint32_t from_version;
    uint32_t to_version;
    int (*migrate_func)(void** data, size_t* size);
} state_migration_t;

typedef struct {
    const char* module_name;
    state_migration_t* migrations;
    uint32_t migration_count;
    uint32_t current_version;
} state_migration_table_t;

// Example migration table for graphics module
static int graphics_migrate_v1_to_v2(void** data, size_t* size) {
    // Migrate graphics state from version 1 to 2
    graphics_state_v1_t* old_state = (graphics_state_v1_t*)*data;
    
    graphics_state_v2_t* new_state = malloc(sizeof(graphics_state_v2_t));
    if (!new_state) {
        return -1;
    }
    
    // Copy existing fields
    new_state->context = old_state->context;
    new_state->pipeline = old_state->pipeline;
    new_state->frame_count = old_state->frame_count;
    
    // Initialize new fields
    new_state->render_quality = RENDER_QUALITY_HIGH;
    new_state->vsync_enabled = true;
    
    // Update data pointer and size
    free(*data);
    *data = new_state;
    *size = sizeof(graphics_state_v2_t);
    
    return 0;
}

static state_migration_t graphics_migrations[] = {
    { .from_version = 1, .to_version = 2, .migrate_func = graphics_migrate_v1_to_v2 }
};

static state_migration_table_t graphics_migration_table = {
    .module_name = "graphics",
    .migrations = graphics_migrations,
    .migration_count = 1,
    .current_version = 2
};

int state_migrate_module(const char* module_name, void** state_data, 
                        size_t* state_size, uint32_t from_version) {
    // Find migration table for module
    state_migration_table_t* table = find_migration_table(module_name);
    if (!table) {
        return -1;
    }
    
    uint32_t current_version = from_version;
    
    // Apply migrations sequentially
    while (current_version < table->current_version) {
        state_migration_t* migration = find_migration(table, current_version, current_version + 1);
        if (!migration) {
            printf("No migration path from version %u to %u\n", 
                   current_version, current_version + 1);
            return -1;
        }
        
        int result = migration->migrate_func(state_data, state_size);
        if (result != 0) {
            printf("Migration failed from version %u to %u\n", 
                   current_version, current_version + 1);
            return result;
        }
        
        current_version++;
        printf("Migrated %s state from version %u to %u\n", 
               module_name, current_version - 1, current_version);
    }
    
    return 0;
}
```

#### 3. Transactional State Management

```c
// transactional_state.c
typedef struct {
    state_tree_t* original_state;
    state_tree_t* working_state;
    transaction_id_t transaction_id;
    uint64_t start_time;
    bool is_active;
} state_transaction_t;

static state_transaction_t g_state_transactions[MAX_CONCURRENT_TRANSACTIONS];
static pthread_mutex_t g_transaction_mutex = PTHREAD_MUTEX_INITIALIZER;

int state_transaction_begin(transaction_id_t* tx_id, isolation_level_t isolation) {
    pthread_mutex_lock(&g_transaction_mutex);
    
    // Find available transaction slot
    int slot = -1;
    for (int i = 0; i < MAX_CONCURRENT_TRANSACTIONS; i++) {
        if (!g_state_transactions[i].is_active) {
            slot = i;
            break;
        }
    }
    
    if (slot == -1) {
        pthread_mutex_unlock(&g_transaction_mutex);
        return -1; // No available transaction slots
    }
    
    // Begin transaction with runtime
    int result = transaction_begin(tx_id, isolation);
    if (result != 0) {
        pthread_mutex_unlock(&g_transaction_mutex);
        return result;
    }
    
    // Initialize state transaction
    state_transaction_t* tx = &g_state_transactions[slot];
    tx->transaction_id = *tx_id;
    tx->start_time = get_timestamp_ns();
    tx->is_active = true;
    
    // Create working copy of state tree
    state_tree_snapshot(get_global_state_tree(), &tx->working_state);
    
    pthread_mutex_unlock(&g_transaction_mutex);
    
    return 0;
}

int state_transaction_commit(transaction_id_t tx_id) {
    pthread_mutex_lock(&g_transaction_mutex);
    
    state_transaction_t* tx = find_transaction(tx_id);
    if (!tx || !tx->is_active) {
        pthread_mutex_unlock(&g_transaction_mutex);
        return -1;
    }
    
    // Validate state consistency
    if (state_tree_validate(tx->working_state) != 0) {
        pthread_mutex_unlock(&g_transaction_mutex);
        return -1;
    }
    
    // Commit transaction with runtime
    int result = transaction_commit(tx_id);
    if (result != 0) {
        pthread_mutex_unlock(&g_transaction_mutex);
        return result;
    }
    
    // Apply working state to global state
    state_tree_replace(get_global_state_tree(), tx->working_state);
    
    // Cleanup transaction
    state_tree_destroy(tx->working_state);
    memset(tx, 0, sizeof(state_transaction_t));
    
    pthread_mutex_unlock(&g_transaction_mutex);
    
    return 0;
}

int state_transaction_rollback(transaction_id_t tx_id) {
    pthread_mutex_lock(&g_transaction_mutex);
    
    state_transaction_t* tx = find_transaction(tx_id);
    if (!tx || !tx->is_active) {
        pthread_mutex_unlock(&g_transaction_mutex);
        return -1;
    }
    
    // Rollback transaction with runtime
    transaction_rollback(tx_id);
    
    // Cleanup transaction (working state is discarded)
    state_tree_destroy(tx->working_state);
    memset(tx, 0, sizeof(state_transaction_t));
    
    pthread_mutex_unlock(&g_transaction_mutex);
    
    return 0;
}
```

## Advanced Patterns

### 1. Module Dependency Management

```c
// dependency_manager.h
typedef struct {
    const char* module_name;
    const char* required_version; // Can be range like ">=1.2.0,<2.0.0"
    bool optional;
} module_dependency_t;

typedef struct {
    const char* module_name;
    const char* version;
    module_dependency_t* dependencies;
    uint32_t dependency_count;
    module_interface_t* interface;
    bool loaded;
    bool hot_reload_safe;
} module_descriptor_t;

// Dependency resolution
int dependency_resolve_load_order(module_descriptor_t* modules, uint32_t module_count,
                                 module_descriptor_t** load_order);
int dependency_check_hot_reload_safety(const char* module_name,
                                      module_descriptor_t* modules, uint32_t module_count);
```

### 2. Hot-Reload Safety Validation

```c
// hot_reload_safety.c
typedef enum {
    SAFETY_SAFE,
    SAFETY_WARNING,
    SAFETY_UNSAFE,
    SAFETY_BLOCKED
} safety_level_t;

typedef struct {
    safety_level_t level;
    const char* reason;
    const char* recommendation;
    uint32_t affected_modules_count;
    const char** affected_modules;
} safety_assessment_t;

int hot_reload_assess_safety(const char* module_path, 
                            safety_assessment_t* assessment) {
    // Check module compatibility
    module_compatibility_t compatibility;
    int compat_result = hot_reload_check_compatibility(module_path, &compatibility);
    
    if (compat_result != 0) {
        assessment->level = SAFETY_UNSAFE;
        assessment->reason = "Module compatibility check failed";
        return 0;
    }
    
    // Check ABI compatibility
    if (!compatibility.abi_compatible) {
        assessment->level = SAFETY_UNSAFE;
        assessment->reason = "ABI incompatibility detected";
        assessment->recommendation = "Restart application required";
        return 0;
    }
    
    // Check dependent modules
    uint32_t dependent_count = 0;
    const char** dependents = find_dependent_modules(module_path, &dependent_count);
    
    if (dependent_count > 0) {
        assessment->level = SAFETY_WARNING;
        assessment->reason = "Module has active dependents";
        assessment->recommendation = "Consider reloading dependents as well";
        assessment->affected_modules_count = dependent_count;
        assessment->affected_modules = dependents;
        return 0;
    }
    
    // Check active state
    if (module_has_active_state(module_path)) {
        assessment->level = SAFETY_WARNING;
        assessment->reason = "Module has active state that will be preserved";
        assessment->recommendation = "Verify state compatibility";
        return 0;
    }
    
    assessment->level = SAFETY_SAFE;
    assessment->reason = "No safety concerns detected";
    return 0;
}
```

### 3. Performance-Aware Hot-Reload

```c
// performance_aware_reload.c
typedef struct {
    double cpu_usage_threshold;
    double memory_usage_threshold;
    uint32_t active_frame_threshold;
    bool defer_during_critical_sections;
} reload_performance_config_t;

int hot_reload_with_performance_awareness(const char* module_path,
                                         const hot_reload_config_t* reload_config,
                                         const reload_performance_config_t* perf_config) {
    // Check current system performance
    performance_metrics_t metrics;
    performance_monitor_get_metrics(&metrics);
    
    if (metrics.cpu_usage_percent > perf_config->cpu_usage_threshold) {
        printf("Deferring hot-reload due to high CPU usage: %.1f%%\n", 
               metrics.cpu_usage_percent);
        return schedule_deferred_reload(module_path, reload_config);
    }
    
    if (metrics.memory_usage_percent > perf_config->memory_usage_threshold) {
        printf("Deferring hot-reload due to high memory usage: %.1f%%\n", 
               metrics.memory_usage_percent);
        return schedule_deferred_reload(module_path, reload_config);
    }
    
    // Check if we're in a critical rendering section
    if (perf_config->defer_during_critical_sections && is_in_critical_section()) {
        printf("Deferring hot-reload during critical section\n");
        return schedule_deferred_reload(module_path, reload_config);
    }
    
    // Proceed with immediate hot-reload
    return hot_reload_module(module_path, reload_config);
}

int schedule_deferred_reload(const char* module_path, 
                           const hot_reload_config_t* reload_config) {
    // Add to deferred reload queue
    deferred_reload_t deferred = {
        .module_path = strdup(module_path),
        .config = *reload_config,
        .scheduled_time = get_timestamp_ns(),
        .retry_count = 0
    };
    
    return deferred_reload_queue_add(&deferred);
}
```

## Testing and Debugging

### Hot-Reload Testing Framework

```c
// hot_reload_test.c
typedef struct {
    const char* test_name;
    const char* module_path;
    const char* initial_version;
    const char* target_version;
    bool expect_success;
    uint32_t max_duration_ms;
} hot_reload_test_case_t;

static hot_reload_test_case_t test_cases[] = {
    {
        .test_name = "graphics_minor_update",
        .module_path = "/test/modules/graphics.so",
        .initial_version = "1.0.0",
        .target_version = "1.0.1",
        .expect_success = true,
        .max_duration_ms = 50
    },
    {
        .test_name = "graphics_major_update",
        .module_path = "/test/modules/graphics.so",
        .initial_version = "1.0.0",
        .target_version = "2.0.0",
        .expect_success = false, // Should fail due to ABI break
        .max_duration_ms = 100
    }
};

int run_hot_reload_tests(void) {
    int passed = 0;
    int failed = 0;
    
    for (size_t i = 0; i < sizeof(test_cases) / sizeof(test_cases[0]); i++) {
        hot_reload_test_case_t* test = &test_cases[i];
        
        printf("Running test: %s\n", test->test_name);
        
        // Setup test environment
        test_environment_t env;
        setup_test_environment(&env, test->initial_version);
        
        // Measure reload time
        uint64_t start_time = get_timestamp_ns();
        
        hot_reload_config_t config = {
            .validate_before_reload = true,
            .rollback_on_failure = true
        };
        
        int result = hot_reload_module(test->module_path, &config);
        
        uint64_t end_time = get_timestamp_ns();
        uint32_t duration_ms = (end_time - start_time) / 1000000;
        
        // Validate results
        bool test_passed = true;
        
        if (test->expect_success && result != 0) {
            printf("  FAIL: Expected success but got error %d\n", result);
            test_passed = false;
        }
        
        if (!test->expect_success && result == 0) {
            printf("  FAIL: Expected failure but got success\n");
            test_passed = false;
        }
        
        if (duration_ms > test->max_duration_ms) {
            printf("  FAIL: Duration %ums exceeded maximum %ums\n", 
                   duration_ms, test->max_duration_ms);
            test_passed = false;
        }
        
        if (test_passed) {
            printf("  PASS: Duration %ums\n", duration_ms);
            passed++;
        } else {
            failed++;
        }
        
        cleanup_test_environment(&env);
    }
    
    printf("Test results: %d passed, %d failed\n", passed, failed);
    return failed == 0 ? 0 : -1;
}
```

### Debugging Hot-Reload Issues

```c
// hot_reload_debug.c
typedef struct {
    const char* module_path;
    uint64_t start_time;
    uint64_t end_time;
    int result_code;
    const char* error_message;
    
    // State information
    size_t state_size_before;
    size_t state_size_after;
    bool state_preserved;
    
    // Performance information
    uint64_t load_time_ns;
    uint64_t validation_time_ns;
    uint64_t state_transfer_time_ns;
    
    // Memory information
    uint64_t memory_before;
    uint64_t memory_after;
    int64_t memory_delta;
} hot_reload_debug_info_t;

void hot_reload_debug_enable(bool enable) {
    g_debug_enabled = enable;
    
    if (enable) {
        printf("Hot-reload debugging enabled\n");
    }
}

void hot_reload_debug_callback(const hot_reload_debug_info_t* debug_info) {
    if (!g_debug_enabled) {
        return;
    }
    
    printf("=== Hot-Reload Debug Info ===\n");
    printf("Module: %s\n", debug_info->module_path);
    printf("Result: %s (%d)\n", 
           debug_info->result_code == 0 ? "SUCCESS" : "FAILED", 
           debug_info->result_code);
    
    if (debug_info->error_message) {
        printf("Error: %s\n", debug_info->error_message);
    }
    
    printf("Timing:\n");
    printf("  Total: %.2f ms\n", 
           (debug_info->end_time - debug_info->start_time) / 1000000.0);
    printf("  Load: %.2f ms\n", debug_info->load_time_ns / 1000000.0);
    printf("  Validation: %.2f ms\n", debug_info->validation_time_ns / 1000000.0);
    printf("  State Transfer: %.2f ms\n", debug_info->state_transfer_time_ns / 1000000.0);
    
    printf("State:\n");
    printf("  Size Before: %zu bytes\n", debug_info->state_size_before);
    printf("  Size After: %zu bytes\n", debug_info->state_size_after);
    printf("  Preserved: %s\n", debug_info->state_preserved ? "YES" : "NO");
    
    printf("Memory:\n");
    printf("  Before: %zu bytes\n", debug_info->memory_before);
    printf("  After: %zu bytes\n", debug_info->memory_after);
    printf("  Delta: %+ld bytes\n", debug_info->memory_delta);
    
    printf("============================\n");
}
```

## Performance Optimization

### Hot-Reload Performance Tuning

```c
// performance_tuning.c

// 1. Module Preloading
int preload_modules_for_development(void) {
    const char* dev_modules[] = {
        "/dev/modules/graphics.so",
        "/dev/modules/audio.so",
        "/dev/modules/simulation.so"
    };
    
    preload_config_t config = {
        .validate_on_preload = true,
        .keep_in_memory = true,
        .enable_fast_reload = true
    };
    
    for (size_t i = 0; i < sizeof(dev_modules) / sizeof(dev_modules[0]); i++) {
        int result = module_preload(dev_modules[i], &config);
        if (result != 0) {
            printf("Failed to preload module: %s\n", dev_modules[i]);
            return result;
        }
    }
    
    printf("Preloaded %zu modules for fast development reloading\n", 
           sizeof(dev_modules) / sizeof(dev_modules[0]));
    return 0;
}

// 2. Incremental State Transfer
int optimize_state_transfer(void) {
    state_transfer_config_t config = {
        .use_incremental_transfer = true,
        .enable_compression = true,
        .parallel_transfer = true,
        .max_transfer_threads = 4
    };
    
    return state_manager_configure_transfer(&config);
}

// 3. Parallel Module Loading
int enable_parallel_hot_reload(void) {
    hot_reload_optimization_t opt = {
        .enable_parallel_loading = true,
        .max_parallel_modules = 8,
        .use_worker_pool = true,
        .enable_load_balancing = true
    };
    
    return hot_reload_configure_optimization(&opt);
}
```

## Common Patterns

### 1. Graceful Module Replacement

```c
// graceful_replacement.c
int graceful_module_replacement(const char* old_module, const char* new_module) {
    // 1. Load new module without activating it
    module_interface_t* new_interface = module_load_inactive(new_module);
    if (!new_interface) {
        return -1;
    }
    
    // 2. Validate compatibility
    compatibility_result_t compat;
    if (check_module_compatibility(old_module, new_module, &compat) != 0) {
        module_unload(new_interface);
        return -1;
    }
    
    // 3. Prepare state transfer
    void* state_data;
    size_t state_size;
    module_interface_t* old_interface = module_get_interface(old_module);
    
    if (old_interface->vtable.save_state(&state_data, &state_size) != 0) {
        module_unload(new_interface);
        return -1;
    }
    
    // 4. Begin atomic replacement
    transaction_id_t tx_id;
    transaction_begin(&tx_id, ISOLATION_SERIALIZABLE);
    
    // 5. Deactivate old module
    old_interface->vtable.prepare_reload();
    
    // 6. Activate new module
    if (new_interface->vtable.init(NULL) != 0) {
        // Rollback on failure
        old_interface->vtable.rollback_reload();
        transaction_rollback(tx_id);
        free(state_data);
        module_unload(new_interface);
        return -1;
    }
    
    // 7. Transfer state
    if (new_interface->vtable.load_state(state_data, state_size) != 0) {
        // Rollback on failure
        new_interface->vtable.shutdown();
        old_interface->vtable.rollback_reload();
        transaction_rollback(tx_id);
        free(state_data);
        module_unload(new_interface);
        return -1;
    }
    
    // 8. Complete replacement
    old_interface->vtable.shutdown();
    module_unload_by_name(old_module);
    module_register(new_module, new_interface);
    
    transaction_commit(tx_id);
    free(state_data);
    
    printf("Graceful module replacement completed: %s -> %s\n", old_module, new_module);
    return 0;
}
```

### 2. Development Hot-Reload Workflow

```c
// dev_workflow.c
typedef struct {
    const char* watch_directory;
    const char* build_command;
    const char* module_pattern;
    bool auto_reload;
    uint32_t debounce_ms;
} dev_workflow_config_t;

int setup_development_workflow(const dev_workflow_config_t* config) {
    // Setup file watcher
    file_watcher_config_t watcher_config = {
        .watch_directories = { config->watch_directory },
        .auto_reload_on_change = config->auto_reload,
        .debounce_ms = config->debounce_ms,
        .build_command = config->build_command
    };
    
    file_watcher_start(&watcher_config);
    
    // Setup development optimizations
    hot_reload_config_t reload_config = {
        .validate_before_reload = true,
        .backup_current_state = true,
        .rollback_on_failure = true,
        .enable_fast_mode = true // Skip some validations in dev mode
    };
    
    hot_reload_set_default_config(&reload_config);
    
    printf("Development workflow active:\n");
    printf("  Watching: %s\n", config->watch_directory);
    printf("  Auto-reload: %s\n", config->auto_reload ? "enabled" : "disabled");
    printf("  Debounce: %ums\n", config->debounce_ms);
    
    return 0;
}
```

## Troubleshooting

### Common Issues and Solutions

#### 1. State Transfer Failures

**Problem**: State transfer fails during hot-reload
```
Error: State transfer failed - size mismatch
```

**Diagnosis**:
```c
void diagnose_state_transfer_failure(const char* module_name) {
    module_interface_t* interface = module_get_interface(module_name);
    
    void* state_data;
    size_t state_size;
    
    // Test state serialization
    int save_result = interface->vtable.save_state(&state_data, &state_size);
    printf("State save result: %d, size: %zu\n", save_result, state_size);
    
    if (save_result == 0) {
        // Test state deserialization
        int load_result = interface->vtable.load_state(state_data, state_size);
        printf("State load result: %d\n", load_result);
        
        free(state_data);
    }
}
```

**Solution**:
```c
// Implement robust state versioning
static int save_state_with_version(void** state_data, size_t* state_size) {
    versioned_state_t* versioned_state = malloc(sizeof(versioned_state_t));
    versioned_state->version = CURRENT_STATE_VERSION;
    versioned_state->magic = STATE_MAGIC_NUMBER;
    versioned_state->actual_state = current_module_state;
    versioned_state->checksum = calculate_checksum(&current_module_state);
    
    *state_data = versioned_state;
    *state_size = sizeof(versioned_state_t);
    
    return 0;
}

static int load_state_with_validation(const void* state_data, size_t state_size) {
    if (state_size < sizeof(versioned_state_t)) {
        return -1; // Invalid size
    }
    
    const versioned_state_t* versioned_state = (const versioned_state_t*)state_data;
    
    if (versioned_state->magic != STATE_MAGIC_NUMBER) {
        return -1; // Invalid magic number
    }
    
    if (versioned_state->version != CURRENT_STATE_VERSION) {
        // Attempt migration
        return migrate_state_version(versioned_state);
    }
    
    // Validate checksum
    uint32_t expected_checksum = calculate_checksum(&versioned_state->actual_state);
    if (versioned_state->checksum != expected_checksum) {
        return -1; // Checksum mismatch
    }
    
    current_module_state = versioned_state->actual_state;
    return 0;
}
```

#### 2. Module Loading Failures

**Problem**: Module fails to load with symbol errors
```
Error: Undefined symbol 'graphics_render_frame'
```

**Solution**:
```c
// Implement symbol validation
int validate_module_symbols(const char* module_path) {
    const char* required_symbols[] = {
        "get_module_interface",
        "graphics_render_frame",
        "graphics_init",
        "graphics_shutdown"
    };
    
    for (size_t i = 0; i < sizeof(required_symbols) / sizeof(required_symbols[0]); i++) {
        if (!dlsym_check(module_path, required_symbols[i])) {
            printf("Missing required symbol: %s\n", required_symbols[i]);
            return -1;
        }
    }
    
    return 0;
}
```

#### 3. Performance Degradation

**Problem**: Hot-reload becomes slow over time
```
Warning: Hot-reload latency increased to 150ms (target: <50ms)
```

**Diagnosis and Solution**:
```c
void analyze_hot_reload_performance(void) {
    hot_reload_stats_t stats;
    hot_reload_get_statistics(&stats);
    
    printf("Hot-reload performance analysis:\n");
    printf("  Average time: %.2f ms\n", stats.avg_reload_time_ms);
    printf("  P95 time: %.2f ms\n", stats.p95_reload_time_ms);
    printf("  P99 time: %.2f ms\n", stats.p99_reload_time_ms);
    printf("  Memory usage: %zu MB\n", stats.memory_usage_mb);
    printf("  Cache hit rate: %.2f%%\n", stats.cache_hit_rate * 100.0);
    
    if (stats.cache_hit_rate < 0.8) {
        printf("Recommendation: Clear and rebuild module cache\n");
        hot_reload_clear_cache();
    }
    
    if (stats.memory_usage_mb > 500) {
        printf("Recommendation: Enable aggressive garbage collection\n");
        runtime_gc_enable_aggressive();
    }
}
```

---

**Developer Integration Guide**  
**Version 1.0.0 Production Ready**  
**© 2025 SimCity ARM64 Runtime Team**