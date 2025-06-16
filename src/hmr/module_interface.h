/*
 * SimCity ARM64 - HMR Module Interface
 * Hot Module Replacement system for ARM64 assembly agents
 * 
 * Created by Agent 1: Core Module System
 * Version: 1.2 - Week 3 Enterprise Features
 */

#ifndef HMR_MODULE_INTERFACE_H
#define HMR_MODULE_INTERFACE_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

// Version compatibility system - Enhanced for Week 3 Enterprise
#define HMR_VERSION_MAJOR    1
#define HMR_VERSION_MINOR    2
#define HMR_VERSION_PATCH    0
#define HMR_VERSION_MAKE(maj, min, pat) (((maj) << 16) | ((min) << 8) | (pat))
#define HMR_VERSION_CURRENT  HMR_VERSION_MAKE(HMR_VERSION_MAJOR, HMR_VERSION_MINOR, HMR_VERSION_PATCH)

// Include enhanced versioning and security systems
#include "module_versioning.h"
#include "module_security.h"

// Module capability flags - extensible system for agent features
typedef enum {
    HMR_CAP_NONE           = 0x0000,
    HMR_CAP_GRAPHICS       = 0x0001,    // Module uses graphics pipeline
    HMR_CAP_SIMULATION     = 0x0002,    // Module participates in simulation
    HMR_CAP_AI             = 0x0004,    // Module contains AI logic
    HMR_CAP_MEMORY_HEAVY   = 0x0008,    // Module requires large memory pools
    HMR_CAP_NEON_SIMD      = 0x0010,    // Module uses NEON vector operations
    HMR_CAP_THREADING      = 0x0020,    // Module spawns/manages threads
    HMR_CAP_NETWORKING     = 0x0040,    // Module handles network operations
    HMR_CAP_PERSISTENCE    = 0x0080,    // Module handles save/load
    HMR_CAP_AUDIO          = 0x0100,    // Module generates/processes audio
    HMR_CAP_PLATFORM       = 0x0200,    // Module directly accesses platform APIs
    HMR_CAP_CRITICAL       = 0x0400,    // Module is critical for system stability
    HMR_CAP_HOT_SWAPPABLE  = 0x0800,    // Module supports live hot-swapping
    HMR_CAP_DEPENDENCY     = 0x1000,    // Module is a dependency for others
    HMR_CAP_EXPERIMENTAL   = 0x2000,    // Module is experimental/beta
    HMR_CAP_ARM64_ONLY     = 0x4000,    // Module requires ARM64 architecture
    HMR_CAP_RESERVED       = 0x8000     // Reserved for future use
} hmr_capability_flags_t;

// Module lifecycle states
typedef enum {
    HMR_MODULE_UNLOADED = 0,
    HMR_MODULE_LOADING,
    HMR_MODULE_LOADED,
    HMR_MODULE_INITIALIZING,
    HMR_MODULE_ACTIVE,
    HMR_MODULE_PAUSING,
    HMR_MODULE_PAUSED,
    HMR_MODULE_RESUMING,
    HMR_MODULE_STOPPING,
    HMR_MODULE_UNLOADING,
    HMR_MODULE_ERROR
} hmr_module_state_t;

// Module performance metrics
typedef struct {
    uint64_t init_time_ns;          // Initialization time in nanoseconds
    uint64_t avg_frame_time_ns;     // Average frame processing time
    uint64_t peak_frame_time_ns;    // Peak frame processing time
    uint64_t total_frames;          // Total frames processed
    uint64_t memory_usage_bytes;    // Current memory usage
    uint64_t peak_memory_bytes;     // Peak memory usage
    uint32_t error_count;           // Number of errors encountered
    uint32_t warning_count;         // Number of warnings generated
} hmr_module_metrics_t;

// Forward declarations
typedef struct hmr_module_context hmr_module_context_t;
typedef struct hmr_agent_module hmr_agent_module_t;

// Module interface function pointers - standardized entry points
typedef struct {
    // Core lifecycle functions
    int32_t (*init)(hmr_module_context_t* ctx);
    int32_t (*update)(hmr_module_context_t* ctx, float delta_time);
    int32_t (*pause)(hmr_module_context_t* ctx);
    int32_t (*resume)(hmr_module_context_t* ctx);
    int32_t (*shutdown)(hmr_module_context_t* ctx);
    
    // Hot-swap functions
    int32_t (*pre_swap)(hmr_module_context_t* ctx);
    int32_t (*post_swap)(hmr_module_context_t* ctx);
    int32_t (*validate_state)(hmr_module_context_t* ctx);
    
    // Memory management
    void* (*allocate)(size_t size, size_t alignment);
    void (*deallocate)(void* ptr);
    int32_t (*compact_memory)(hmr_module_context_t* ctx);
    
    // Debug/profiling
    void (*get_metrics)(hmr_module_metrics_t* metrics);
    void (*debug_dump)(hmr_module_context_t* ctx, void* output_buffer, size_t buffer_size);
    
    // ARM64 specific functions
    void (*flush_instruction_cache)(void* start, size_t size);
    void (*invalidate_branch_predictor)(void);
    void (*memory_barrier)(void);
} hmr_module_interface_t;

// Module dependency descriptor
typedef struct {
    char name[32];                  // Dependency module name
    uint32_t min_version;           // Minimum required version
    uint32_t max_version;           // Maximum compatible version
    hmr_capability_flags_t required_caps; // Required capabilities
    bool optional;                  // Whether dependency is optional
} hmr_module_dependency_t;

// AgentModule struct - main module descriptor
typedef struct hmr_agent_module {
    // Module identification
    char name[32];                  // Module name (unique identifier)
    char description[128];          // Human-readable description
    char author[64];                // Module author
    uint32_t version;               // Module version (packed) - DEPRECATED, use semantic_version
    uint32_t api_version;           // HMR API version this module targets
    
    // Enhanced versioning (Week 2)
    hmr_version_t semantic_version;         // Full semantic version
    hmr_version_t min_api_version;          // Minimum required API version
    hmr_version_t max_api_version;          // Maximum supported API version
    hmr_version_constraint_t* constraints;  // Version constraints for dependencies
    uint32_t constraint_count;              // Number of version constraints
    
    // Module capabilities and requirements
    hmr_capability_flags_t capabilities;    // What this module provides
    hmr_capability_flags_t requirements;    // What this module needs
    
    // Dependencies
    hmr_module_dependency_t* dependencies;  // Array of dependencies
    uint32_t dependency_count;              // Number of dependencies
    
    // Module interface
    hmr_module_interface_t interface;       // Function pointers
    
    // Runtime state
    hmr_module_state_t state;               // Current lifecycle state
    uint32_t reference_count;               // Reference counter for safe unloading
    void* module_handle;                    // Platform-specific module handle (dlopen)
    void* private_data;                     // Module-private data pointer
    
    // Performance and debugging
    hmr_module_metrics_t metrics;           // Performance metrics
    uint64_t load_time_ns;                  // When module was loaded
    uint64_t last_update_ns;                // Last update timestamp
    
    // Memory management
    void* memory_pool;                      // Module-specific memory pool
    size_t memory_pool_size;                // Size of memory pool
    size_t memory_used;                     // Currently used memory
    
    // ARM64 specific
    void* code_section;                     // Pointer to executable code
    size_t code_size;                       // Size of code section
    void* data_section;                     // Pointer to data section
    size_t data_size;                       // Size of data section
    
    // Threading support
    uint32_t thread_id;                     // Primary thread ID
    uint32_t thread_affinity;               // CPU core affinity mask
    bool thread_safe;                       // Whether module is thread-safe
    
    // Hot-swap support
    bool hot_swappable;                     // Whether module supports hot-swapping
    void* swap_state;                       // State to preserve during swap
    size_t swap_state_size;                 // Size of swap state
    
    // Week 3 Enterprise Security Features
    hmr_module_security_context_t* security_context;  // Security and enforcement context
    bool security_verified;                 // Whether module passed security verification
    bool sandbox_enabled;                   // Whether module is running in sandbox
    uint64_t security_violations;           // Total security violations
    uint64_t last_security_check;           // Last security validation timestamp
} hmr_agent_module_t;

// Module context - passed to all module functions
typedef struct hmr_module_context {
    hmr_agent_module_t* module;             // Pointer to module descriptor
    void* system_context;                   // System-wide context
    void* shared_memory;                    // Shared memory pool
    size_t shared_memory_size;              // Size of shared memory
    
    // System interfaces
    void* graphics_system;                  // Graphics system interface
    void* simulation_system;                // Simulation system interface
    void* ai_system;                        // AI system interface
    void* memory_system;                    // Memory system interface
    void* platform_system;                  // Platform system interface
    
    // Performance monitoring
    uint64_t frame_start_time;              // Current frame start time
    uint64_t frame_budget_ns;               // Frame time budget
    uint32_t current_frame;                 // Current frame number
    
    // Debug flags
    bool debug_mode;                        // Whether in debug mode
    bool profiling_enabled;                 // Whether profiling is active
    uint32_t log_level;                     // Current log level
} hmr_module_context_t;

// Module registry entry
typedef struct {
    hmr_agent_module_t* module;             // Pointer to module
    char file_path[256];                    // Path to module file
    uint64_t file_mtime;                    // File modification time
    uint32_t load_order;                    // Load order priority
    bool auto_reload;                       // Whether to auto-reload on change
} hmr_module_registry_entry_t;

// API Functions - implemented in module_loader.s
#ifdef __cplusplus
extern "C" {
#endif

// Module lifecycle management
int32_t hmr_load_module(const char* path, hmr_agent_module_t** module);
int32_t hmr_unload_module(hmr_agent_module_t* module);
int32_t hmr_reload_module(hmr_agent_module_t* module);

// Module registry operations
int32_t hmr_register_module(hmr_agent_module_t* module);
int32_t hmr_unregister_module(const char* name);
hmr_agent_module_t* hmr_find_module(const char* name);
int32_t hmr_list_modules(hmr_agent_module_t** modules, uint32_t max_count);

// Dependency resolution
int32_t hmr_resolve_dependencies(hmr_agent_module_t* module);
int32_t hmr_check_compatibility(hmr_agent_module_t* module);

// Version compatibility
bool hmr_version_compatible(uint32_t required, uint32_t available);
const char* hmr_version_string(uint32_t version);

// Capability system
bool hmr_has_capability(hmr_agent_module_t* module, hmr_capability_flags_t caps);
const char* hmr_capability_string(hmr_capability_flags_t caps);

// Performance monitoring
void hmr_update_metrics(hmr_agent_module_t* module);
void hmr_reset_metrics(hmr_agent_module_t* module);

// ARM64 specific utilities
void hmr_flush_icache(void* start, size_t size);
void hmr_invalidate_bpred(void);
void hmr_memory_barrier_full(void);

#ifdef __cplusplus
}
#endif

// Error codes
#define HMR_SUCCESS              0
#define HMR_ERROR_NULL_POINTER  -1
#define HMR_ERROR_INVALID_ARG   -2
#define HMR_ERROR_NOT_FOUND     -3
#define HMR_ERROR_ALREADY_EXISTS -4
#define HMR_ERROR_LOAD_FAILED   -5
#define HMR_ERROR_SYMBOL_NOT_FOUND -6
#define HMR_ERROR_VERSION_MISMATCH -7
#define HMR_ERROR_DEPENDENCY_FAILED -8
#define HMR_ERROR_OUT_OF_MEMORY -9
#define HMR_ERROR_THREADING     -10
#define HMR_ERROR_NOT_SUPPORTED -11
#define HMR_ERROR_TIMEOUT       -12

// Configuration constants
#define HMR_MAX_MODULES         256
#define HMR_MAX_DEPENDENCIES    32
#define HMR_MODULE_NAME_MAX     32
#define HMR_PATH_MAX           256
#define HMR_DEFAULT_POOL_SIZE  (4 * 1024 * 1024)  // 4MB default pool per module

#endif // HMR_MODULE_INTERFACE_H