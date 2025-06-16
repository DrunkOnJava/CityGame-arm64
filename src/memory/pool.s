// pool.s - Memory Pool Allocator
// SimCity ARM64 Assembly Project - Agent 2: Memory Management
//
// Fast linear memory pools for temporary allocations and per-frame data
// Provides extremely fast allocation with bulk deallocation (reset)
// Optimized for short-lived objects and scratch memory

.text
.align 4

// Include our memory system definitions
.include "../include/constants/memory.inc"
.include "../include/types/memory.inc"
.include "../include/macros/memory.inc"

// ============================================================================
// GLOBAL SYMBOLS
// ============================================================================

.global pool_create
.global pool_alloc
.global pool_reset
.global pool_destroy
.global temp_alloc
.global temp_reset

// External dependencies
.extern tlsf_alloc
.extern tlsf_free

// ============================================================================
// DATA SECTION
// ============================================================================

.data
.align 6                                // Cache-line aligned

// Global memory pools for different purposes
temp_pool:          .quad   0           // Temporary allocation pool
frame_pool:         .quad   0           // Per-frame allocation pool
pathfind_pool:      .quad   0           // Pathfinding scratch pool

// Pool allocator statistics
pool_stats:
    total_pools:        .quad   0       // Total number of pools
    total_allocations:  .quad   0       // Total allocations made
    bytes_allocated:    .quad   0       // Total bytes allocated
    peak_usage:         .quad   0       // Peak memory usage
    resets_performed:   .quad   0       // Number of resets performed

// Pool allocator lock
pool_lock:          .quad   0

// ============================================================================
// MEMORY POOL CREATION
// ============================================================================

// pool_create: Create a new memory pool
// Arguments:
//   x0 = pool_size (size of pool in bytes)
// Returns:
//   x0 = pool pointer (NULL on failure)
//   x1 = error code
pool_create:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save pool size
    
    // Validate pool size
    CHECK_SIZE x19, .pool_create_error
    cmp     x19, #4096                  // Minimum 4KB pool
    b.lt    .pool_create_error
    
    // Align pool size to page boundary for better performance
    PAGE_ALIGN x19
    
    // Allocate memory for pool structure + data
    add     x0, x19, #memory_pool.struct_end
    bl      tlsf_alloc
    cbz     x0, .pool_create_oom
    mov     x20, x0                     // Save pool pointer
    
    // Calculate base address (after pool header)
    add     x1, x20, #memory_pool.struct_end
    CACHE_ALIGN x1
    
    // Initialize pool structure
    str     x1, [x20, #memory_pool.base_addr]
    str     x1, [x20, #memory_pool.current_ptr]
    add     x2, x1, x19
    str     x2, [x20, #memory_pool.end_addr]
    str     x19, [x20, #memory_pool.pool_size]
    str     xzr, [x20, #memory_pool.bytes_used]
    mov     x3, #CACHE_LINE_SIZE
    str     x3, [x20, #memory_pool.alignment]
    str     xzr, [x20, #memory_pool.flags]
    
    // Update global statistics
    adrp    x0, pool_stats
    add     x0, x0, :lo12:pool_stats
    ATOMIC_INC x0, x1                   // total_pools
    
    MEMORY_BARRIER_FULL
    
    mov     x0, x20                     // Return pool pointer
    mov     x1, #MEM_SUCCESS
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.pool_create_error:
    mov     x0, xzr
    mov     x1, #MEM_ERROR_INVALID_SIZE
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.pool_create_oom:
    mov     x0, xzr
    mov     x1, #MEM_ERROR_OUT_OF_MEMORY
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ============================================================================
// MEMORY POOL ALLOCATION
// ============================================================================

// pool_alloc: Allocate memory from a pool
// Arguments:
//   x0 = pool pointer
//   x1 = size (requested size in bytes)
// Returns:
//   x0 = allocated pointer (NULL on failure)
//   x1 = error code
pool_alloc:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save pool pointer
    mov     x20, x1                     // Save requested size
    
    // Validate parameters
    CHECK_NULL x19, .pool_alloc_error
    CHECK_SIZE x20, .pool_alloc_error
    
    // Acquire pool lock (for thread safety)
    adrp    x0, pool_lock
    add     x0, x0, :lo12:pool_lock
.pool_alloc_lock:
    ldaxr   x1, [x0]
    cbnz    x1, .pool_alloc_lock
    mov     x1, #1
    stlxr   w2, x1, [x0]
    cbnz    w2, .pool_alloc_lock
    
    // Get current allocation pointer
    ldr     x0, [x19, #memory_pool.current_ptr]
    
    // Align allocation size
    ldr     x1, [x19, #memory_pool.alignment]
    add     x2, x20, x1
    sub     x2, x2, #1
    udiv    x3, x2, x1
    mul     x20, x3, x1                 // Aligned size
    
    // Check if enough space remains
    ldr     x1, [x19, #memory_pool.end_addr]
    add     x2, x0, x20                 // New current pointer
    cmp     x2, x1
    b.gt    .pool_alloc_oom
    
    // Update current pointer
    str     x2, [x19, #memory_pool.current_ptr]
    
    // Update bytes used
    ldr     x1, [x19, #memory_pool.bytes_used]
    add     x1, x1, x20
    str     x1, [x19, #memory_pool.bytes_used]
    
    // Update global statistics
    adrp    x3, pool_stats
    add     x3, x3, :lo12:pool_stats
    ATOMIC_INC x3 + 8, x4               // total_allocations
    
1:  ldxr    x4, [x3 + 16]               // bytes_allocated
    add     x5, x4, x20
    stxr    w6, x5, [x3 + 16]
    cbnz    w6, 1b
    
    // Update peak usage if needed
    ldr     x4, [x3 + 24]               // peak_usage
    cmp     x5, x4
    b.le    2f
    str     x5, [x3 + 24]
2:
    
    // Clear allocated memory (optional, for debug builds)
    .ifdef DEBUG_MEMORY
    mov     x1, x0                      // Destination
    mov     x2, x20                     // Size
    bl      .pool_clear_memory
    .endif
    
    // Release lock
    adrp    x1, pool_lock
    add     x1, x1, :lo12:pool_lock
    stlr    xzr, [x1]
    
    mov     x1, #MEM_SUCCESS
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.pool_alloc_error:
    mov     x0, xzr
    mov     x1, #MEM_ERROR_INVALID_PTR
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.pool_alloc_oom:
    // Release lock
    adrp    x1, pool_lock
    add     x1, x1, :lo12:pool_lock
    stlr    xzr, [x1]
    
    mov     x0, xzr
    mov     x1, #MEM_ERROR_OUT_OF_MEMORY
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ============================================================================
// MEMORY POOL RESET
// ============================================================================

// pool_reset: Reset pool to empty state (fast bulk deallocation)
// Arguments:
//   x0 = pool pointer
// Returns:
//   x0 = error code
pool_reset:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    CHECK_NULL x0, .pool_reset_error
    
    // Acquire lock
    adrp    x1, pool_lock
    add     x1, x1, :lo12:pool_lock
.pool_reset_lock:
    ldaxr   x2, [x1]
    cbnz    x2, .pool_reset_lock
    mov     x2, #1
    stlxr   w3, x2, [x1]
    cbnz    w3, .pool_reset_lock
    
    // Reset current pointer to base
    ldr     x1, [x0, #memory_pool.base_addr]
    str     x1, [x0, #memory_pool.current_ptr]
    
    // Reset bytes used
    str     xzr, [x0, #memory_pool.bytes_used]
    
    // Update global statistics
    adrp    x1, pool_stats
    add     x1, x1, :lo12:pool_stats
    ATOMIC_INC x1 + 32, x2              // resets_performed
    
    // Optional: Clear pool memory for security/debugging
    .ifdef DEBUG_MEMORY
    ldr     x1, [x0, #memory_pool.base_addr]
    ldr     x2, [x0, #memory_pool.pool_size]
    bl      .pool_clear_memory
    .endif
    
    MEMORY_BARRIER_FULL
    
    // Release lock
    adrp    x1, pool_lock
    add     x1, x1, :lo12:pool_lock
    stlr    xzr, [x1]
    
    mov     x0, #MEM_SUCCESS
    ldp     x29, x30, [sp], #16
    ret

.pool_reset_error:
    mov     x0, #MEM_ERROR_NULL_PTR
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// MEMORY POOL DESTRUCTION
// ============================================================================

// pool_destroy: Destroy a memory pool and free its memory
// Arguments:
//   x0 = pool pointer
// Returns:
//   x0 = error code
pool_destroy:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    CHECK_NULL x0, .pool_destroy_error
    
    // Update global statistics
    adrp    x1, pool_stats
    add     x1, x1, :lo12:pool_stats
    ldr     x2, [x1]                    // total_pools
    sub     x2, x2, #1
    str     x2, [x1]
    
    // Free the pool memory
    bl      tlsf_free
    
    ldp     x29, x30, [sp], #16
    ret

.pool_destroy_error:
    mov     x0, #MEM_ERROR_NULL_PTR
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// GLOBAL TEMPORARY ALLOCATION FUNCTIONS
// ============================================================================

// temp_alloc: Allocate temporary memory (convenience function)
// Arguments:
//   x0 = size (requested size in bytes)
// Returns:
//   x0 = allocated pointer (NULL on failure)
//   x1 = error code
temp_alloc:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     x1, x0                      // Save size
    
    // Get or create temporary pool
    adrp    x0, temp_pool
    add     x0, x0, :lo12:temp_pool
    ldr     x2, [x0]
    cbnz    x2, .temp_alloc_from_pool
    
    // Create temporary pool
    mov     x0, #POOL_TEMP_SIZE
    bl      pool_create
    cbz     x0, .temp_alloc_failed
    
    adrp    x2, temp_pool
    add     x2, x2, :lo12:temp_pool
    str     x0, [x2]
    mov     x2, x0

.temp_alloc_from_pool:
    mov     x0, x2                      // Pool pointer
    // x1 already contains size
    bl      pool_alloc
    
    ldp     x29, x30, [sp], #16
    ret

.temp_alloc_failed:
    mov     x1, #MEM_ERROR_OUT_OF_MEMORY
    ldp     x29, x30, [sp], #16
    ret

// temp_reset: Reset temporary memory pool
// Returns:
//   void
temp_reset:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, temp_pool
    add     x0, x0, :lo12:temp_pool
    ldr     x0, [x0]
    cbz     x0, .temp_reset_done
    
    bl      pool_reset

.temp_reset_done:
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// SPECIALIZED POOL FUNCTIONS FOR SIMCITY
// ============================================================================

// Initialize all global pools used by SimCity
// This should be called during system initialization
.global pool_init_system
pool_init_system:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Create temporary pool
    mov     x0, #POOL_TEMP_SIZE
    bl      pool_create
    cbz     x0, .pool_init_failed
    adrp    x1, temp_pool
    add     x1, x1, :lo12:temp_pool
    str     x0, [x1]
    
    // Create frame pool
    mov     x0, #POOL_FRAME_SIZE
    bl      pool_create
    cbz     x0, .pool_init_failed
    adrp    x1, frame_pool
    add     x1, x1, :lo12:frame_pool
    str     x0, [x1]
    
    // Create pathfinding pool
    mov     x0, #POOL_PATHFIND_SIZE
    bl      pool_create
    cbz     x0, .pool_init_failed
    adrp    x1, pathfind_pool
    add     x1, x1, :lo12:pathfind_pool
    str     x0, [x1]
    
    mov     x0, #MEM_SUCCESS
    ldp     x29, x30, [sp], #16
    ret

.pool_init_failed:
    mov     x0, #MEM_ERROR_OUT_OF_MEMORY
    ldp     x29, x30, [sp], #16
    ret

// Get frame allocation pool (reset every frame)
.global pool_get_frame
pool_get_frame:
    adrp    x0, frame_pool
    add     x0, x0, :lo12:frame_pool
    ldr     x0, [x0]
    ret

// Get pathfinding pool (for A* and flow field calculations)
.global pool_get_pathfind
pool_get_pathfind:
    adrp    x0, pathfind_pool
    add     x0, x0, :lo12:pathfind_pool
    ldr     x0, [x0]
    ret

// Reset frame pool (called every frame)
.global pool_reset_frame
pool_reset_frame:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, frame_pool
    add     x0, x0, :lo12:frame_pool
    ldr     x0, [x0]
    cbz     x0, .pool_reset_frame_done
    
    bl      pool_reset

.pool_reset_frame_done:
    ldp     x29, x30, [sp], #16
    ret

// Reset pathfinding pool (called after pathfinding calculations)
.global pool_reset_pathfind
pool_reset_pathfind:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, pathfind_pool
    add     x0, x0, :lo12:pathfind_pool
    ldr     x0, [x0]
    cbz     x0, .pool_reset_pathfind_done
    
    bl      pool_reset

.pool_reset_pathfind_done:
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// POOL UTILITIES
// ============================================================================

// Get pool statistics
.global pool_get_stats
pool_get_stats:
    // Arguments: x0 = stats buffer pointer
    // Copy pool statistics to provided buffer
    adrp    x1, pool_stats
    add     x1, x1, :lo12:pool_stats
    
    ldp     x2, x3, [x1]
    stp     x2, x3, [x0]
    ldp     x2, x3, [x1, #16]
    stp     x2, x3, [x0, #16]
    ldr     x2, [x1, #32]
    str     x2, [x0, #32]
    
    ret

// Get pool utilization (returns percentage * 100)
.global pool_get_utilization
pool_get_utilization:
    // Arguments: x0 = pool pointer
    // Returns: x0 = utilization percentage * 100 (0-10000)
    CHECK_NULL x0, .pool_util_error
    
    ldr     x1, [x0, #memory_pool.bytes_used]
    ldr     x2, [x0, #memory_pool.pool_size]
    
    cbz     x2, .pool_util_error
    
    mov     x3, #10000
    mul     x1, x1, x3
    udiv    x0, x1, x2
    ret

.pool_util_error:
    mov     x0, #0
    ret

// ============================================================================
// INTERNAL HELPER FUNCTIONS
// ============================================================================

// Clear memory (for debugging/security)
.pool_clear_memory:
    // Arguments: x0 = address, x1 = size
    cbz     x1, .pool_clear_done
    
    // Use SIMD for fast clearing
    mov     x2, x1
    movi    v0.16b, #0
    
    cmp     x2, #64
    b.lt    .pool_clear_small
    
    // Clear 64-byte chunks
    and     x3, x2, #~63
    add     x4, x0, x3
    
.pool_clear_simd_loop:
    stp     q0, q0, [x0], #32
    stp     q0, q0, [x0], #32
    cmp     x0, x4
    b.lt    .pool_clear_simd_loop
    
    and     x2, x2, #63

.pool_clear_small:
    tbz     x2, #5, 1f
    stp     q0, q0, [x0], #32
1:  tbz     x2, #4, 2f
    str     q0, [x0], #16
2:  tbz     x2, #3, 3f
    str     d0, [x0], #8
3:  tbz     x2, #2, 4f
    str     s0, [x0], #4
4:  tbz     x2, #1, 5f
    strh    w2, [x0], #2
5:  tbz     x2, #0, .pool_clear_done
    strb    w2, [x0]

.pool_clear_done:
    ret