//
// SimCity ARM64 Assembly - Simulation Module ABI Definition
// Agent A1: Simulation Architect - Shared Application Binary Interface
//
// Defines the standard ABI for all simulation modules to ensure:
// - Consistent calling conventions
// - Register allocation strategy
// - Memory layout standards
// - Error handling protocols
// - Performance monitoring hooks
//

.ifndef SIMULATION_ABI_S
.equ SIMULATION_ABI_S, 1

//==============================================================================
// ARM64 Register Allocation Strategy for Simulation Hot Paths
//==============================================================================

// Preserved Registers (callee-saved) - Module State
// x19-x28: Reserved for module persistent state
// x19: Primary module state pointer
// x20: Secondary state/cache pointer  
// x21: Current entity/agent pointer
// x22: Performance counter/timer
// x23: Error state accumulator
// x24: Module configuration flags
// x25: Scratch register for hot paths
// x26: Reserved for future use
// x27: Stack frame/context pointer
// x28: Module ID for debugging

// Argument Registers (caller-saved) - Standard ARM64 AAPCS
// x0-x7: Function arguments and return values
// x8: Indirect return value pointer
// x9-x15: Temporary registers

// Special Purpose Registers
// x16-x17: IP0/IP1 - Intra-procedure call registers
// x18: Platform register (reserved)
// x29: Frame pointer (FP)
// x30: Link register (LR)
// SP: Stack pointer

// Floating Point Registers
// d0-d7: Arguments and return values
// d8-d15: Callee-saved (preserved across calls)
// d16-d31: Caller-saved (temporary)

//==============================================================================
// Standard Module Function Signatures
//==============================================================================

// Module Initialization Function
// Signature: module_init(module_id, config_ptr, memory_pool) -> error_code
// Parameters:
//   x0 = module_id (0-15)
//   x1 = config_ptr (pointer to module configuration)
//   x2 = memory_pool (pointer to module memory pool)
// Returns:
//   x0 = error_code (0 = success, negative = error)
// Preserved registers:
//   x19-x28 may be initialized with module state
.macro MODULE_INIT_SIGNATURE
    // Standard prologue for module init
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    // Store module ID in x28 for debugging
    and     x28, x0, #0xFF
    
    // Store configuration and memory pool
    mov     x19, x1                     // config_ptr -> x19
    mov     x20, x2                     // memory_pool -> x20
.endm

.macro MODULE_INIT_EPILOGUE
    // Standard epilogue for module init
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret
.endm

// Module Tick Function
// Signature: module_tick(module_id, delta_time_ns, world_context) -> error_code
// Parameters:
//   x0 = module_id (0-15)
//   x1 = delta_time_ns (nanoseconds since last tick)
//   x2 = world_context (pointer to shared world state)
// Returns:
//   x0 = error_code (0 = success, negative = error)
// Performance critical: This function is called 30 times per second
.macro MODULE_TICK_SIGNATURE
    // Minimal prologue for hot path
    stp     x29, x30, [sp, #-32]!
    stp     x21, x22, [sp, #16]
    mov     x29, sp
    
    // Load module state (should be cached in preserved registers)
    // x19-x20 should already contain module state from init
    
    // Store parameters in volatile registers
    mov     x21, x1                     // delta_time_ns -> x21
    mov     x22, x2                     // world_context -> x22
.endm

.macro MODULE_TICK_EPILOGUE
    // Minimal epilogue for hot path
    ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
.endm

// Module Cleanup Function
// Signature: module_cleanup(module_id) -> error_code
// Parameters:
//   x0 = module_id (0-15)
// Returns:
//   x0 = error_code (0 = success, negative = error)
.macro MODULE_CLEANUP_SIGNATURE
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    and     x28, x0, #0xFF              // Store module ID
.endm

.macro MODULE_CLEANUP_EPILOGUE
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret
.endm

//==============================================================================
// Standard Error Codes
//==============================================================================

.equ SIM_SUCCESS,                   0
.equ SIM_ERROR_INVALID_PARAM,      -1
.equ SIM_ERROR_OUT_OF_MEMORY,       -2
.equ SIM_ERROR_MODULE_NOT_INIT,     -3
.equ SIM_ERROR_MODULE_FAILED,       -4
.equ SIM_ERROR_INVALID_STATE,       -5
.equ SIM_ERROR_TIMEOUT,             -6
.equ SIM_ERROR_RESOURCE_EXHAUSTED,  -7
.equ SIM_ERROR_DEPENDENCY_FAILED,   -8
.equ SIM_ERROR_CONFIG_ERROR,        -9
.equ SIM_ERROR_INTERNAL_ERROR,      -10

//==============================================================================
// Memory Layout Standards
//==============================================================================

// Module State Structure Alignment
.equ MODULE_STATE_ALIGN,    64          // Cache line alignment
.equ MODULE_CACHE_ALIGN,    64          // L1 cache line size
.equ MODULE_L2_ALIGN,       128         // L2 cache line size

// Memory Pool Layout for Modules
.struct ModuleMemoryPool
    // Pool header (64-byte aligned)
    pool_id                 .word       // Unique pool identifier
    module_id               .word       // Owner module ID
    total_size              .quad       // Total pool size in bytes
    used_size               .quad       // Currently used bytes
    free_size               .quad       // Available bytes
    allocation_count        .word       // Number of allocations
    fragmentation_ratio     .word       // Fragmentation percentage
    
    // Allocation tracking (64-byte aligned)
    free_list_head          .quad       // Head of free list
    used_list_head          .quad       // Head of used list
    large_alloc_threshold   .word       // Threshold for large allocations
    alignment_requirement   .word       // Required alignment
    
    // Performance statistics (64-byte aligned)
    total_allocations       .quad       // Total allocation count
    total_deallocations     .quad       // Total deallocation count
    peak_usage              .quad       // Peak memory usage
    avg_allocation_size     .word       // Average allocation size
    _padding                .space 20   // Pad to 64 bytes
.endstruct

//==============================================================================
// Performance Monitoring Hook Macros
//==============================================================================

// Performance timing macros for hot paths
.macro START_PERF_TIMER reg
    mrs     \reg, cntvct_el0            // Read cycle counter
.endm

.macro END_PERF_TIMER start_reg, result_reg
    mrs     \result_reg, cntvct_el0     // Read end cycle counter
    sub     \result_reg, \result_reg, \start_reg
.endm

// Profile function entry/exit
.macro PROFILE_FUNCTION_ENTER module_id, function_id
    .ifdef ENABLE_PROFILING
    mov     x25, lr                     // Save link register
    mov     x0, #\module_id
    mov     x1, #\function_id
    bl      profile_function_enter
    mov     lr, x25                     // Restore link register
    .endif
.endm

.macro PROFILE_FUNCTION_EXIT module_id, function_id
    .ifdef ENABLE_PROFILING
    mov     x25, lr                     // Save link register
    mov     x0, #\module_id
    mov     x1, #\function_id
    bl      profile_function_exit
    mov     lr, x25                     // Restore link register
    .endif
.endm

//==============================================================================
// Inter-Module Communication Protocol
//==============================================================================

// Message passing structure for module communication
.struct ModuleMessage
    // Header (32-byte aligned)
    source_module           .word       // Source module ID
    target_module           .word       // Target module ID
    message_type            .word       // Message type identifier
    priority                .word       // Message priority (0=highest)
    timestamp               .quad       // Message timestamp
    data_size               .word       // Size of message data
    _padding1               .word       // Alignment padding
    
    // Message data (variable size, 32-byte aligned)
    data                    .quad       // Pointer to message data
    
    // Internal use (32-byte aligned)
    next_message            .quad       // Next message in queue
    processing_time         .quad       // Time spent processing
.endstruct

// Standard message types
.equ MSG_TYPE_SYSTEM_INIT,          0
.equ MSG_TYPE_SYSTEM_SHUTDOWN,      1
.equ MSG_TYPE_SYSTEM_PAUSE,         2
.equ MSG_TYPE_SYSTEM_RESUME,        3
.equ MSG_TYPE_DATA_UPDATE,          10
.equ MSG_TYPE_STATE_CHANGE,         11
.equ MSG_TYPE_ERROR_REPORT,         20
.equ MSG_TYPE_PERFORMANCE_WARN,     21
.equ MSG_TYPE_RESOURCE_REQUEST,     30
.equ MSG_TYPE_RESOURCE_RESPONSE,    31

//==============================================================================
// Module Configuration Structure
//==============================================================================

.struct ModuleConfig
    // Basic configuration (64-byte aligned)
    module_id               .word       // Module identifier
    module_version          .word       // Module version
    enable_profiling        .word       // Enable performance profiling
    enable_debugging        .word       // Enable debug output
    log_level               .word       // Logging level (0-5)
    update_frequency        .word       // Update frequency divisor
    priority_level          .word       // Execution priority
    _padding1               .word       // Alignment
    
    // Memory configuration (64-byte aligned)
    memory_pool_size        .quad       // Requested memory pool size
    max_allocations         .word       // Maximum number of allocations
    alignment_requirement   .word       // Required memory alignment
    enable_memory_tracking  .word       // Track memory usage
    _padding2               .word       // Alignment
    
    // Module-specific configuration data pointer
    specific_config         .quad       // Pointer to module-specific config
    config_data_size        .quad       // Size of specific config data
    
    // Performance limits (64-byte aligned)
    max_execution_time      .quad       // Maximum execution time (ns)
    performance_threshold   .quad       // Performance warning threshold
    adaptive_quality        .word       // Enable adaptive quality reduction
    _padding3               .space 20   // Pad to 64 bytes
.endstruct

//==============================================================================
// Shared World State Access Protocol
//==============================================================================

// World context structure for module access to shared state
.struct WorldContext
    // Core world state (64-byte aligned)
    world_width             .word       // World width in tiles
    world_height            .word       // World height in tiles
    current_tick            .quad       // Current simulation tick
    total_population        .word       // Total world population
    total_wealth            .word       // Total economic wealth
    
    // Time information (64-byte aligned)
    game_year               .word       // Current game year
    game_month              .word       // Current game month
    game_day                .word       // Current game day
    game_hour               .word       // Current game hour
    season                  .word       // Current season (0-3)
    weather_state           .word       // Current weather
    temperature             .word       // Current temperature
    _padding1               .word       // Alignment
    
    // Shared data structure pointers (64-byte aligned)
    tile_data               .quad       // Pointer to tile data array
    chunk_data              .quad       // Pointer to chunk data array
    agent_data              .quad       // Pointer to agent data array
    network_data            .quad       // Pointer to network data array
    
    // Synchronization (64-byte aligned)
    read_lock               .quad       // Read lock for concurrent access
    write_lock              .quad       // Write lock for exclusive access
    access_count            .word       // Number of active readers
    _padding2               .space 20   // Pad to 64 bytes
.endstruct

//==============================================================================
// Standard Utility Macros
//==============================================================================

// Safe memory access macros with bounds checking
.macro SAFE_LOAD_WORD dest, base, offset, bounds
    add     x25, \base, \offset
    cmp     x25, \bounds
    b.ge    .Lbounds_error_\@
    ldr     \dest, [x25]
    b       .Lsafe_load_done_\@
.Lbounds_error_\@:
    mov     \dest, #0                   // Safe default value
.Lsafe_load_done_\@:
.endm

.macro SAFE_STORE_WORD src, base, offset, bounds
    add     x25, \base, \offset
    cmp     x25, \bounds
    b.ge    .Lstore_bounds_error_\@
    str     \src, [x25]
.Lstore_bounds_error_\@:
.endm

// Error handling macros
.macro CHECK_NULL_PTR ptr, error_label
    cbz     \ptr, \error_label
.endm

.macro CHECK_MODULE_INIT module_state, error_label
    cbz     \module_state, \error_label
    ldr     w25, [\module_state]        // Load init flag
    cbz     w25, \error_label
.endm

.macro RETURN_ERROR error_code
    mov     x0, #\error_code
    b       function_exit
.endm

//==============================================================================
// Cache and Memory Optimization Macros
//==============================================================================

// Data prefetching for hot loops
.macro PREFETCH_DATA ptr, offset
    add     x25, \ptr, #\offset
    prfm    pldl1keep, [x25]
.endm

.macro PREFETCH_INSTRUCTION ptr
    prfm    pldl1keep, [\ptr]
.endm

// Cache line alignment
.macro ALIGN_TO_CACHE_LINE reg
    add     \reg, \reg, #63
    and     \reg, \reg, #~63
.endm

// Memory barriers for synchronization
.macro MEMORY_BARRIER_ACQUIRE
    dmb     ishld                       // Load-acquire barrier
.endm

.macro MEMORY_BARRIER_RELEASE
    dmb     ishst                       // Store-release barrier
.endm

.macro MEMORY_BARRIER_FULL
    dmb     ish                         // Full memory barrier
.endm

//==============================================================================
// Debug and Logging Support
//==============================================================================

.ifdef DEBUG_BUILD
.macro DEBUG_LOG module_id, log_level, message
    mov     x25, lr
    mov     x0, #\module_id
    mov     x1, #\log_level
    adrp    x2, \message
    add     x2, x2, :lo12:\message
    bl      debug_log_message
    mov     lr, x25
.endm
.else
.macro DEBUG_LOG module_id, log_level, message
    // No-op in release build
.endm
.endif

//==============================================================================
// Standard Structure Sizes
//==============================================================================

.equ ModuleMemoryPool_size,     128
.equ ModuleMessage_size,        64
.equ ModuleConfig_size,         192
.equ WorldContext_size,         256

.endif // SIMULATION_ABI_S