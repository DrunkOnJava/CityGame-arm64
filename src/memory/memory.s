// memory.s - Main Memory Management System
// SimCity ARM64 Assembly Project - Agent 2: Memory Management
//
// Main memory manager that coordinates all memory subsystems:
// - TLSF general purpose allocator
// - Slab allocators for fixed-size objects  
// - Memory pools for temporary allocations
// - Debug tracking and validation
// - Cache-aligned allocations and proper memory barriers

.text
.align 4

// Include our memory system definitions
.include "../include/constants/memory.inc"
.include "../include/types/memory.inc" 
.include "../include/macros/memory.inc"

// ============================================================================
// GLOBAL SYMBOLS
// ============================================================================

.global memory_init
.global memory_shutdown
.global memory_get_stats
.global mem_cache_flush
.global mem_cache_invalidate
.global mem_barrier_full
.global mem_barrier_load
.global mem_barrier_store

// External subsystem functions
.extern tlsf_init
.extern pool_init_system
.extern mem_debug_init
.extern agent_alloc
.extern agent_free
.extern tile_alloc
.extern tile_free
.extern building_alloc
.extern building_free

// ============================================================================
// DATA SECTION
// ============================================================================

.data
.align 6                                // Cache-line aligned

// Memory system state
memory_initialized:     .quad   0       // Initialization flag
memory_heap_base:       .quad   0       // Base of main heap
memory_heap_size:       .quad   0       // Size of main heap
memory_system_lock:     .quad   0       // System-wide memory lock

// Global memory statistics (cache-aligned)
.align 6
global_memory_stats:
    system_total_bytes:     .quad   0   // Total system memory
    heap_bytes_used:        .quad   0   // Heap memory in use
    slab_bytes_used:        .quad   0   // Slab memory in use
    pool_bytes_used:        .quad   0   // Pool memory in use
    peak_usage:             .quad   0   // Peak total usage
    allocation_count:       .quad   0   // Total allocations
    free_count:             .quad   0   // Total frees
    cache_flushes:          .quad   0   // Cache maintenance operations

// Performance counters (for monitoring)
perf_counters:
    alloc_time_total:       .quad   0   // Total allocation time (cycles)
    alloc_count:            .quad   0   // Number of timed allocations
    free_time_total:        .quad   0   // Total free time (cycles)
    free_count:             .quad   0   // Number of timed frees

// ============================================================================
// SYSTEM INITIALIZATION
// ============================================================================

// memory_init: Initialize the complete memory management system
// Arguments:
//   x0 = heap_base (base address for memory heap)
//   x1 = heap_size (total size available for memory management)
// Returns:
//   x0 = error code (0 = success)
memory_init:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // Save heap base
    mov     x20, x1                     // Save heap size
    
    // Check if already initialized
    adrp    x0, memory_initialized
    add     x0, x0, :lo12:memory_initialized
    ldr     x1, [x0]
    cbnz    x1, .memory_init_already
    
    // Validate parameters
    CHECK_NULL x19, .memory_init_error
    CHECK_SIZE x20, .memory_init_error
    
    // Ensure minimum heap size (128MB)
    mov     x1, #134217728              // 128MB
    cmp     x20, x1  
    b.lt    .memory_init_error
    
    // Align heap base to page boundary
    mov     x21, x19
    PAGE_ALIGN x21
    sub     x22, x19, x21               // Alignment adjustment
    sub     x20, x20, x22               // Adjust size
    mov     x19, x21                    // Use aligned base
    
    // Store heap parameters
    adrp    x0, memory_heap_base
    add     x0, x0, :lo12:memory_heap_base
    str     x19, [x0]
    str     x20, [x0, #8]
    
    // Reserve memory for different subsystems
    // TLSF gets 60% of heap, pools get 30%, debug gets 10%
    mov     x1, #60
    mul     x21, x20, x1
    mov     x1, #100
    udiv    x21, x21, x1                // TLSF allocation size
    
    mov     x1, #30
    mul     x22, x20, x1
    mov     x1, #100
    udiv    x22, x22, x1                // Pool system size
    
    // Initialize TLSF allocator
    mov     x0, x19
    mov     x1, x21
    bl      tlsf_init
    cbnz    x0, .memory_init_tlsf_failed
    
    // Initialize memory pools
    bl      pool_init_system
    cbnz    x0, .memory_init_pool_failed
    
    // Initialize debug system
    bl      mem_debug_init
    cbnz    x0, .memory_init_debug_failed
    
    // Initialize global statistics
    adrp    x0, global_memory_stats
    add     x0, x0, :lo12:global_memory_stats
    str     x20, [x0]                   // system_total_bytes
    
    // Clear performance counters
    adrp    x0, perf_counters
    add     x0, x0, :lo12:perf_counters
    stp     xzr, xzr, [x0]
    stp     xzr, xzr, [x0, #16]
    
    // Mark system as initialized
    adrp    x0, memory_initialized
    add     x0, x0, :lo12:memory_initialized
    mov     x1, #1
    str     x1, [x0]
    
    // Full memory barrier to ensure initialization is visible
    MEMORY_BARRIER_FULL
    
    mov     x0, #MEM_SUCCESS
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.memory_init_already:
    mov     x0, #MEM_SUCCESS
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.memory_init_error:
    mov     x0, #MEM_ERROR_INVALID_SIZE
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.memory_init_tlsf_failed:
    mov     x0, #MEM_ERROR_INIT_FAILED
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.memory_init_pool_failed:
    mov     x0, #MEM_ERROR_INIT_FAILED
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.memory_init_debug_failed:
    // Debug failure is not critical, continue with warning
    mov     x0, #MEM_SUCCESS
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ============================================================================
// SYSTEM SHUTDOWN
// ============================================================================

// memory_shutdown: Shutdown memory management system
// Returns:
//   x0 = error code
memory_shutdown:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Check if initialized
    adrp    x0, memory_initialized
    add     x0, x0, :lo12:memory_initialized
    ldr     x1, [x0]
    cbz     x1, .memory_shutdown_not_init
    
    // Perform memory leak check
    bl      mem_debug_check
    
    // Mark as not initialized
    str     xzr, [x0]
    
    MEMORY_BARRIER_FULL
    
    mov     x0, #MEM_SUCCESS
    ldp     x29, x30, [sp], #16
    ret

.memory_shutdown_not_init:
    mov     x0, #MEM_ERROR_INIT_FAILED
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// CACHE MANAGEMENT FUNCTIONS
// ============================================================================

// mem_cache_flush: Flush data cache for memory range
// Arguments:
//   x0 = address
//   x1 = size
mem_cache_flush:
    cbz     x1, .cache_flush_done
    
    add     x2, x0, x1                  // End address
    mov     x3, #CACHE_LINE_SIZE
    
    // Align start address down to cache line
    and     x0, x0, #~(CACHE_LINE_SIZE - 1)
    
.cache_flush_loop:
    dc      civac, x0                   // Clean and invalidate by VA to PoC
    add     x0, x0, x3
    cmp     x0, x2
    b.lt    .cache_flush_loop
    
    dsb     sy                          // Ensure completion
    
    // Update statistics
    adrp    x0, global_memory_stats
    add     x0, x0, :lo12:global_memory_stats
    ldr     x1, [x0, #56]               // cache_flushes
    add     x1, x1, #1
    str     x1, [x0, #56]

.cache_flush_done:
    ret

// mem_cache_invalidate: Invalidate data cache for memory range
// Arguments:
//   x0 = address  
//   x1 = size
mem_cache_invalidate:
    cbz     x1, .cache_invalidate_done
    
    add     x2, x0, x1                  // End address
    mov     x3, #CACHE_LINE_SIZE
    
    // Align start address down to cache line
    and     x0, x0, #~(CACHE_LINE_SIZE - 1)
    
.cache_invalidate_loop:
    dc      ivac, x0                    // Invalidate by VA to PoC
    add     x0, x0, x3
    cmp     x0, x2
    b.lt    .cache_invalidate_loop
    
    dsb     sy                          // Ensure completion

.cache_invalidate_done:
    ret

// ============================================================================
// MEMORY BARRIER FUNCTIONS  
// ============================================================================

// mem_barrier_full: Full memory barrier
mem_barrier_full:
    MEMORY_BARRIER_FULL
    ret

// mem_barrier_load: Load memory barrier
mem_barrier_load:
    MEMORY_BARRIER_LOAD
    ret

// mem_barrier_store: Store memory barrier
mem_barrier_store:
    MEMORY_BARRIER_STORE
    ret

// ============================================================================
// STATISTICS AND MONITORING
// ============================================================================

// memory_get_stats: Get comprehensive memory statistics
// Arguments:
//   x0 = buffer to store statistics (at least 64 bytes)
// Returns:
//   x0 = error code
memory_get_stats:
    CHECK_NULL x0, .memory_stats_error
    
    // Copy global statistics
    adrp    x1, global_memory_stats
    add     x1, x1, :lo12:global_memory_stats
    
    ldp     x2, x3, [x1]
    stp     x2, x3, [x0]
    ldp     x2, x3, [x1, #16]
    stp     x2, x3, [x0, #16]
    ldp     x2, x3, [x1, #32]
    stp     x2, x3, [x0, #32]
    ldp     x2, x3, [x1, #48]
    stp     x2, x3, [x0, #48]
    
    mov     x0, #MEM_SUCCESS
    ret

.memory_stats_error:
    mov     x0, #MEM_ERROR_NULL_PTR
    ret

// ============================================================================
// HIGH-LEVEL ALLOCATION WRAPPERS WITH PERFORMANCE MONITORING
// ============================================================================

// Optimized agent allocation with performance tracking
.global fast_agent_alloc
fast_agent_alloc:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Start performance timer
    mrs     x19, cntvct_el0
    
    // Allocate agent
    bl      agent_alloc
    mov     x20, x0                     // Save result
    
    // End performance timer
    mrs     x1, cntvct_el0
    sub     x1, x1, x19                 // Calculate duration
    
    // Update performance counters
    adrp    x2, perf_counters
    add     x2, x2, :lo12:perf_counters
    
    // Add to total time
1:  ldxr    x3, [x2]                    // alloc_time_total
    add     x4, x3, x1
    stxr    w5, x4, [x2]
    cbnz    w5, 1b
    
    // Increment count
    ATOMIC_INC x2 + 8, x3               // alloc_count
    
    mov     x0, x20                     // Restore result
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// Optimized agent free with performance tracking
.global fast_agent_free
fast_agent_free:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x20, x0                     // Save pointer
    
    // Start performance timer
    mrs     x19, cntvct_el0
    
    // Free agent
    mov     x0, x20
    bl      agent_free
    
    // End performance timer
    mrs     x1, cntvct_el0
    sub     x1, x1, x19
    
    // Update performance counters
    adrp    x2, perf_counters
    add     x2, x2, :lo12:perf_counters
    
    // Add to total free time
2:  ldxr    x3, [x2, #16]               // free_time_total
    add     x4, x3, x1
    stxr    w5, x4, [x2, #16]
    cbnz    w5, 2b
    
    // Increment free count
    ATOMIC_INC x2 + 24, x3              // free_count
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ============================================================================
// CACHE-ALIGNED ALLOCATION FUNCTIONS
// ============================================================================

// Allocate cache-aligned memory
.global mem_alloc_aligned
mem_alloc_aligned:
    // Arguments: x0 = size, x1 = alignment
    // Returns: x0 = aligned pointer, x1 = error code
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save size
    mov     x20, x1                     // Save alignment
    
    // Validate alignment (must be power of 2)
    tst     x20, x20
    b.eq    .mem_aligned_error
    sub     x1, x20, #1
    tst     x20, x1
    b.ne    .mem_aligned_error
    
    // Allocate extra space for alignment
    add     x0, x19, x20
    add     x0, x0, #8                  // Space for original pointer
    bl      tlsf_alloc
    cbz     x0, .mem_aligned_oom
    
    // Calculate aligned address
    add     x1, x0, #8                  // Skip original pointer storage
    add     x2, x1, x20
    sub     x2, x2, #1
    udiv    x3, x2, x20
    mul     x2, x3, x20                 // Aligned address
    
    // Store original pointer before aligned address
    str     x0, [x2, #-8]
    
    mov     x0, x2                      // Return aligned pointer
    mov     x1, #MEM_SUCCESS
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.mem_aligned_error:
    mov     x0, xzr
    mov     x1, #MEM_ERROR_INVALID_SIZE
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.mem_aligned_oom:
    mov     x0, xzr
    mov     x1, #MEM_ERROR_OUT_OF_MEMORY
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// Free cache-aligned memory
.global mem_free_aligned
mem_free_aligned:
    // Arguments: x0 = aligned pointer
    // Returns: x0 = error code
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    CHECK_NULL x0, .mem_free_aligned_error
    
    // Get original pointer
    ldr     x0, [x0, #-8]
    bl      tlsf_free
    
    ldp     x29, x30, [sp], #16
    ret

.mem_free_aligned_error:
    mov     x0, #MEM_ERROR_NULL_PTR
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// PERFORMANCE ANALYSIS FUNCTIONS
// ============================================================================

// Get average allocation time in nanoseconds
.global mem_get_avg_alloc_time
mem_get_avg_alloc_time:
    adrp    x0, perf_counters
    add     x0, x0, :lo12:perf_counters
    
    ldr     x1, [x0]                    // total_time
    ldr     x2, [x0, #8]                // count
    
    cbz     x2, .mem_avg_alloc_zero
    
    // Convert cycles to nanoseconds (assuming 3.2GHz)
    mov     x3, #3200000000             // 3.2GHz in Hz
    mov     x4, #1000000000             // 1 billion (for nanoseconds)
    mul     x1, x1, x4
    udiv    x0, x1, x3                  // Nanoseconds total
    udiv    x0, x0, x2                  // Average
    ret

.mem_avg_alloc_zero:
    mov     x0, #0
    ret

// Check if allocation performance meets target (<100ns)
.global mem_check_performance_target
mem_check_performance_target:
    bl      mem_get_avg_alloc_time
    cmp     x0, #100                    // 100ns target
    cset    x0, le                      // Return 1 if <= 100ns, 0 otherwise
    ret