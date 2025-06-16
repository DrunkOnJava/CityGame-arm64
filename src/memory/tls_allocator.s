// SimCity ARM64 Thread-Local Storage Agent Allocator
// Agent 1: Core Engine Developer
// Cache-aligned thread-local allocation to avoid false sharing

.cpu generic+simd
.arch armv8-a+simd

// Thread-local storage keys
.section .data
.align 6

// Per-thread allocator state (cache-aligned)
.thread_allocator_key:
    .quad   0                               // pthread_key_t for TLS

// Cache line constants for Apple Silicon
.cache_constants:
    .cache_line_size:       .quad   64      // Apple M1/M2 L1 cache line
    .l2_cache_line_size:    .quad   128     // Apple M1/M2 L2 cache line  
    .allocation_alignment:  .quad   64      // Force 64-byte alignment
    .false_sharing_guard:   .quad   128     // 128-byte guard for hot data

// Thread-local allocator statistics
.tls_stats:
    .total_threads:         .quad   0
    .peak_threads:          .quad   0
    .total_tls_allocs:      .quad   0
    .cache_misses_avoided:  .quad   0

.section .text
.align 4

//==============================================================================
// Thread-Local Storage Initialization
//==============================================================================

// tls_allocator_init: Initialize thread-local storage system
// Returns: x0 = error_code (0 = success)
.global tls_allocator_init
tls_allocator_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Create pthread key for thread-local allocator state
    adrp    x0, .thread_allocator_key
    add     x0, x0, :lo12:.thread_allocator_key
    adrp    x1, tls_destructor
    add     x1, x1, :lo12:tls_destructor
    bl      pthread_key_create
    
    cmp     x0, #0
    b.ne    tls_init_failed
    
    // Initialize global statistics
    adrp    x1, .tls_stats
    add     x1, x1, :lo12:.tls_stats
    movi    v0.16b, #0
    stp     q0, q0, [x1]                    // Clear all stats
    
    mov     x0, #0                          // Success
    ldp     x29, x30, [sp], #16
    ret

tls_init_failed:
    mov     x0, #-1                         // Failed
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Thread-Local Agent Allocation
//==============================================================================

// Per-thread allocator state structure (cache-aligned)
// struct ThreadAllocatorState {
//     void*    free_lists[4];              // 32 bytes - per-pool free lists
//     uint64_t allocation_count;           // 8 bytes
//     uint64_t thread_id;                  // 8 bytes  
//     uint64_t cache_hits;                 // 8 bytes
//     uint64_t cache_misses;               // 8 bytes
//     char     padding[64];                // Pad to 128 bytes (2 cache lines)
// };

#define TLS_STATE_SIZE      128
#define TLS_FREE_LISTS      0
#define TLS_ALLOC_COUNT     32
#define TLS_THREAD_ID       40
#define TLS_CACHE_HITS      48
#define TLS_CACHE_MISSES    56

// tls_agent_alloc: Thread-local agent allocation with cache alignment
// Args: x0 = agent_type (0-3)
// Returns: x0 = agent_pointer, x1 = error_code
.global tls_agent_alloc
tls_agent_alloc:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    and     x19, x0, #3                     // Clamp agent_type to 0-3
    
    // Get thread-local state
    bl      get_thread_allocator_state
    cbz     x0, tls_alloc_failed
    mov     x20, x0                         // Save TLS state pointer
    
    // Try thread-local free list first
    ldr     x1, [x20, x19, lsl #3]          // Load free_list[agent_type]
    cbz     x1, tls_slow_path               // No free blocks in TLS
    
    // Fast path: pop from thread-local free list
    ldr     x2, [x1]                        // Load next pointer
    str     x2, [x20, x19, lsl #3]          // Update free_list[agent_type]
    
    // Cache alignment verification and adjustment
    and     x3, x1, #63                     // Check 64-byte alignment
    cbz     x3, tls_aligned                 // Already aligned
    
    // Force alignment (this shouldn't happen with proper allocation)
    add     x1, x1, #63                     // Add 63
    and     x1, x1, #~63                    // Clear low 6 bits
    
tls_aligned:
    // Clear agent memory with NEON (128 bytes)
    movi    v0.16b, #0
    stp     q0, q0, [x1]                    // 0-31
    stp     q0, q0, [x1, #32]               // 32-63
    stp     q0, q0, [x1, #64]               // 64-95
    stp     q0, q0, [x1, #96]               // 96-127
    
    // Update thread-local statistics
    ldr     x2, [x20, #TLS_ALLOC_COUNT]
    add     x2, x2, #1
    str     x2, [x20, #TLS_ALLOC_COUNT]
    
    ldr     x2, [x20, #TLS_CACHE_HITS]
    add     x2, x2, #1
    str     x2, [x20, #TLS_CACHE_HITS]
    
    mov     x0, x1                          // Return aligned pointer
    mov     x1, #0                          // Success
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

tls_slow_path:
    // Allocate from global pool and populate TLS cache
    mov     x0, x19                         // agent_type
    bl      allocate_tls_cache_block
    cmp     x0, #0
    b.le    tls_alloc_failed
    
    // Retry from TLS cache
    ldr     x1, [x20, x19, lsl #3]
    cbz     x1, tls_alloc_failed
    
    // Pop from refreshed TLS cache
    ldr     x2, [x1]
    str     x2, [x20, x19, lsl #3]
    
    // Ensure cache alignment
    and     x3, x1, #63
    cbz     x3, tls_slow_aligned
    add     x1, x1, #63
    and     x1, x1, #~63
    
tls_slow_aligned:
    // Clear memory
    movi    v0.16b, #0
    stp     q0, q0, [x1]
    stp     q0, q0, [x1, #32]
    stp     q0, q0, [x1, #64]
    stp     q0, q0, [x1, #96]
    
    // Update cache miss statistics
    ldr     x2, [x20, #TLS_CACHE_MISSES]
    add     x2, x2, #1
    str     x2, [x20, #TLS_CACHE_MISSES]
    
    mov     x0, x1                          // Return pointer
    mov     x1, #0                          // Success
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

tls_alloc_failed:
    mov     x0, #0                          // NULL pointer
    mov     x1, #-1                         // Error
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Thread-Local Agent Deallocation
//==============================================================================

// tls_agent_free: Thread-local agent deallocation
// Args: x0 = agent_pointer
// Returns: x0 = error_code (0 = success)
.global tls_agent_free
tls_agent_free:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    cbz     x0, tls_free_null               // Check for NULL
    
    // Verify cache alignment
    and     x1, x0, #63
    cbnz    x1, tls_free_unaligned          // Pointer not cache-aligned
    
    // Get thread-local state
    bl      get_thread_allocator_state
    cbz     x0, tls_free_failed
    mov     x2, x0                          // Save TLS state
    
    // Determine agent type (simplified - use address hash)
    mov     x1, x0                          // agent_pointer
    lsr     x3, x1, #7                      // Divide by 128 (agent size)
    and     x3, x3, #3                      // Map to pool 0-3
    
    // Add to thread-local free list (LIFO)
    ldr     x4, [x2, x3, lsl #3]            // Current free_list[type]
    str     x4, [x1]                        // Store old head as next
    str     x1, [x2, x3, lsl #3]            // Set agent as new head
    
    // Optional: Clear sensitive data (first cache line only)
    movi    v0.16b, #0
    stp     q0, q0, [x1]                    // Clear 0-31
    stp     q0, q0, [x1, #32]               // Clear 32-63
    
    mov     x0, #0                          // Success
    ldp     x29, x30, [sp], #16
    ret

tls_free_null:
    mov     x0, #-1                         // NULL pointer error
    ldp     x29, x30, [sp], #16
    ret

tls_free_unaligned:
    mov     x0, #-2                         // Alignment error
    ldp     x29, x30, [sp], #16
    ret

tls_free_failed:
    mov     x0, #-3                         // TLS error
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Thread-Local State Management
//==============================================================================

// get_thread_allocator_state: Get or create thread-local allocator state
// Returns: x0 = tls_state_pointer (or 0 on error)
get_thread_allocator_state:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get TLS key
    adrp    x0, .thread_allocator_key
    add     x0, x0, :lo12:.thread_allocator_key
    ldr     x0, [x0]                        // Load pthread_key_t
    bl      pthread_getspecific
    
    cbnz    x0, tls_state_found             // Already initialized
    
    // Create new thread-local state
    mov     x0, #TLS_STATE_SIZE
    bl      aligned_alloc_128               // Allocate 128-byte aligned
    cbz     x0, tls_create_failed
    
    mov     x1, x0                          // Save state pointer
    
    // Initialize TLS state
    movi    v0.16b, #0
    stp     q0, q0, [x1]                    // Clear free_lists
    stp     q0, q0, [x1, #32]               // Clear counters
    stp     q0, q0, [x1, #64]               // Clear padding
    stp     q0, q0, [x1, #96]               // Clear more padding
    
    // Store thread ID
    bl      pthread_self
    str     x0, [x1, #TLS_THREAD_ID]
    
    // Set in TLS
    adrp    x2, .thread_allocator_key
    add     x2, x2, :lo12:.thread_allocator_key
    ldr     x0, [x2]                        // pthread_key_t
    bl      pthread_setspecific
    
    cmp     x0, #0
    b.ne    tls_set_failed
    
    // Update global thread count
    adrp    x2, .tls_stats
    add     x2, x2, :lo12:.tls_stats
    ldxr    x3, [x2]                        // total_threads
    add     x3, x3, #1
    stxr    w4, x3, [x2]
    cbnz    w4, .-8                         // Retry on failure
    
    // Update peak threads if necessary
    ldr     x4, [x2, #8]                    // peak_threads
    cmp     x3, x4
    b.le    no_peak_update
    str     x3, [x2, #8]
    
no_peak_update:
    mov     x0, x1                          // Return state pointer
    ldp     x29, x30, [sp], #16
    ret

tls_state_found:
    ldp     x29, x30, [sp], #16
    ret

tls_create_failed:
tls_set_failed:
    mov     x0, #0                          // Failed
    ldp     x29, x30, [sp], #16
    ret

// allocate_tls_cache_block: Allocate agents from global pool for TLS cache
// Args: x0 = agent_type
// Returns: x0 = allocated_count
allocate_tls_cache_block:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                         // Save agent_type
    
    // Allocate a cache-line worth of agents (8 agents = 1024 bytes)
    mov     x21, #8                         // Agents per cache block
    mov     x22, #0                         // Success counter
    
    // Get TLS state
    bl      get_thread_allocator_state
    cbz     x0, cache_alloc_failed
    mov     x20, x0                         // Save TLS state
    
cache_populate_loop:
    cmp     x22, x21
    b.ge    cache_populate_done
    
    // Allocate from global pool
    mov     x0, x19                         // agent_type
    bl      fast_agent_alloc                // Use global allocator
    cbz     x0, cache_populate_done         // Stop on failure
    
    // Add to TLS free list
    ldr     x1, [x20, x19, lsl #3]          // Current free_list head
    str     x1, [x0]                        // Link to existing list
    str     x0, [x20, x19, lsl #3]          // Set as new head
    
    add     x22, x22, #1                    // Increment success count
    b       cache_populate_loop

cache_populate_done:
    mov     x0, x22                         // Return allocated count
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

cache_alloc_failed:
    mov     x0, #0                          // Failed
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// aligned_alloc_128: Allocate 128-byte aligned memory
// Args: x0 = size
// Returns: x0 = aligned_pointer (or 0 on error)
aligned_alloc_128:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    add     x0, x0, #127                    // Add alignment - 1
    mov     x1, #128                        // 128-byte alignment
    bl      posix_memalign
    
    ldp     x29, x30, [sp], #16
    ret

// tls_destructor: Called when thread exits to clean up TLS state
// Args: x0 = tls_state_pointer
tls_destructor:
    cbz     x0, destructor_done             // Nothing to free
    
    // Free the TLS state memory
    bl      free
    
    // Decrement global thread count
    adrp    x1, .tls_stats
    add     x1, x1, :lo12:.tls_stats
    ldxr    x2, [x1]                        // total_threads
    sub     x2, x2, #1
    stxr    w3, x2, [x1]
    cbnz    w3, .-8                         // Retry on failure

destructor_done:
    ret

//==============================================================================
// Cache Performance Monitoring
//==============================================================================

// tls_get_cache_stats: Get thread-local cache performance statistics
// Args: x0 = output_stats_struct
// Returns: none
.global tls_get_cache_stats
tls_get_cache_stats:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     x1, x0                          // Save output pointer
    
    // Get TLS state
    bl      get_thread_allocator_state
    cbz     x0, no_tls_stats
    
    // Copy relevant statistics
    ldr     x2, [x0, #TLS_ALLOC_COUNT]      // allocation_count
    str     x2, [x1]
    
    ldr     x2, [x0, #TLS_CACHE_HITS]       // cache_hits
    str     x2, [x1, #8]
    
    ldr     x2, [x0, #TLS_CACHE_MISSES]     // cache_misses
    str     x2, [x1, #16]
    
    ldr     x2, [x0, #TLS_THREAD_ID]        // thread_id
    str     x2, [x1, #24]
    
    ldp     x29, x30, [sp], #16
    ret

no_tls_stats:
    // Zero out stats if no TLS state
    movi    v0.16b, #0
    stp     q0, q0, [x1]
    
    ldp     x29, x30, [sp], #16
    ret

.end