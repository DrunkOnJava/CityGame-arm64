# HMR API Naming Conflicts Resolution
## Agent 0: HMR Orchestrator - Week 2, Day 6

This document tracks and resolves naming conflicts between HMR agent APIs discovered during unification.

## Identified Conflicts and Resolutions

### 1. Initialization Functions
**Conflict**: Multiple agents use `hmr_*_init()` pattern
- `hmr_rt_init()` (Agent 3: Runtime)
- `hmr_dev_server_init()` (Agent 4: Debug Tools)
- `hmr_asset_watcher_init()` (Agent 5: Assets)
- `hmr_shader_manager_init()` (Agent 5: Assets)
- `hmr_metrics_init()` (Agent 4: Debug Tools)

**Resolution**: Maintained descriptive naming in unified API:
- `hmr_runtime_init()` (was `hmr_rt_init()`)
- `hmr_debug_dev_server_init()` (was `hmr_dev_server_init()`)
- `hmr_asset_watcher_init()` (preserved)
- `hmr_shader_manager_init()` (preserved)
- Internal metrics integrated into debug system

### 2. Module State Management
**Conflict**: Different state enums between agents
- Agent 1: `HMR_MODULE_UNLOADED, LOADING, LOADED, ACTIVE, ERROR`
- Agent 0: `MODULE_STATE_UNKNOWN, DISCOVERED, BUILDING, BUILT, LOADING, LOADED, LINKING, LINKED, ACTIVE, HOT_SWAPPING, ERROR, UNLOADING, UNLOADED`

**Resolution**: Unified into comprehensive state machine in `hmr_module_state_t`:
```c
typedef enum {
    HMR_MODULE_STATE_UNKNOWN       = 0,
    HMR_MODULE_STATE_DISCOVERED    = 1,
    HMR_MODULE_STATE_BUILDING      = 2,
    HMR_MODULE_STATE_BUILT         = 3,
    HMR_MODULE_STATE_LOADING       = 4,
    HMR_MODULE_STATE_LOADED        = 5,
    HMR_MODULE_STATE_LINKING       = 6,
    HMR_MODULE_STATE_LINKED        = 7,
    HMR_MODULE_STATE_INITIALIZING  = 8,    // New unified state
    HMR_MODULE_STATE_ACTIVE        = 9,
    HMR_MODULE_STATE_HOT_SWAPPING  = 10,
    HMR_MODULE_STATE_PAUSING       = 11,   // From Agent 1
    HMR_MODULE_STATE_PAUSED        = 12,   // From Agent 1
    HMR_MODULE_STATE_RESUMING      = 13,   // From Agent 1
    HMR_MODULE_STATE_STOPPING      = 14,   // From Agent 1
    HMR_MODULE_STATE_ERROR         = 15,
    HMR_MODULE_STATE_UNLOADING     = 16,
    HMR_MODULE_STATE_UNLOADED      = 17
} hmr_module_state_t;
```

### 3. Error Code Ranges
**Conflict**: Overlapping error code definitions
**Resolution**: Maintained agent-specific ranges as defined in `hmr_interfaces.h`:
- Agent 0: 0x1000-0x1999
- Agent 1: 0x2000-0x2999
- Agent 2: 0x3000-0x3999
- Agent 3: 0x4000-0x4999
- Agent 4: 0x5000-0x5999
- Agent 5: 0x6000-0x6999

### 4. Performance Metrics Structures
**Conflict**: Multiple overlapping metric structures:
- `hmr_performance_metrics_t` (Agent 0)
- `hmr_module_metrics_t` (Agent 1)
- `hmr_rt_metrics_t` (Agent 3)
- Various agent-specific stats structures

**Resolution**: Created unified `hmr_unified_metrics_t` containing all metrics:
- Build and load metrics
- Runtime performance metrics
- Memory and resource metrics
- Asset pipeline metrics
- Shader system metrics
- Developer tools metrics

### 5. Configuration Structure Conflicts
**Conflict**: Multiple config structures with similar purposes
**Resolution**: Preserved agent-specific config structures but grouped in unified header:
- `hmr_runtime_config_t` (Agent 3)
- `hmr_asset_watcher_config_t` (Agent 5)
- `hmr_shader_config_t` (Agent 5, renamed from `hmr_shader_manager_config_t`)

### 6. Module Loading API Conflicts
**Conflict**: Agent 1 module interface vs Agent 0 orchestrator interface
- Agent 1: `hmr_load_module()`, `hmr_unload_module()`, `hmr_reload_module()`
- Agent 0: `hmr_load_module()`, `hmr_unload_module()`

**Resolution**: Unified with consistent `hmr_module_*` prefix:
- `hmr_module_load()` (primary interface)
- `hmr_module_unload()`
- `hmr_module_reload()`
- Legacy functions preserved for compatibility

### 7. Asset Management Conflicts
**Conflict**: Asset pipeline functions vs legacy asset interface
**Resolution**: New asset watcher API takes precedence, legacy functions mapped:
- Primary: `hmr_asset_watcher_*()` functions
- Legacy: `hmr_reload_shader()`, `hmr_reload_texture()` etc. mapped to new system

## Implementation Notes

1. **Backward Compatibility**: Legacy function names are preserved as macros or thin wrappers
2. **Function Prefixes**: Standardized prefixes for each agent:
   - `hmr_orchestrator_*` - Agent 0
   - `hmr_module_*` - Agent 1 
   - `hmr_build_*`, `hmr_file_*` - Agent 2
   - `hmr_runtime_*` - Agent 3
   - `hmr_debug_*` - Agent 4
   - `hmr_asset_*`, `hmr_shader_*` - Agent 5

3. **Error Handling**: All functions return standardized error codes from unified ranges

4. **Memory Layout**: Shared structures use consistent alignment and padding

## Testing Requirements

1. **API Compatibility Tests**: Verify legacy code compiles with unified header
2. **Cross-Agent Communication**: Test message passing between all agents
3. **State Synchronization**: Verify unified state machine transitions
4. **Performance Impact**: Measure overhead of unified metric collection

## Migration Guide

For existing code using individual agent headers:

1. Replace individual includes with `#include "hmr_unified.h"`
2. Update function calls to use new unified naming:
   - `hmr_rt_init()` → `hmr_runtime_init()`
   - `hmr_dev_server_init()` → `hmr_debug_dev_server_init()`
3. Update metric structure usage to `hmr_unified_metrics_t`
4. Verify error code handling for expanded ranges

## Next Steps

1. Create integration tests validating all agent interactions
2. Performance testing with unified metrics collection
3. Memory layout validation across agent boundaries
4. Documentation updates for unified API