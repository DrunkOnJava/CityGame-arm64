// SimCity ARM64 Agent Memory Allocator
// Agent 1: Core Engine Developer
// Specialized high-performance allocator for 1M+ agents with NEON optimization

.cpu generic+simd
.arch armv8-a+simd

// Include platform constants
.include "../include/constants/platform_constants.h"
.include "../include/macros/platform_asm.inc"
.include "../include/constants/memory.inc"

.section .data
.align 6

// Agent memory pools (cache-aligned for optimal performance)
.agent_pools:
    // Pool 0: Active simulation agents (hot path)
    .quad   0                           // pool_base
    .quad   0                           // pool_size
    .quad   0                           // free_bitmap
    .quad   0                           // allocation_count
    .quad   0                           // peak_usage
    .quad   0                           // pool_lock
    .space  16                          // padding to 64 bytes
    
    // Pool 1: Background/idle agents (warm storage)
    .quad   0, 0, 0, 0, 0, 0
    .space  16
    
    // Pool 2: Temporary agents (pathfinding, spawning)
    .quad   0, 0, 0, 0, 0, 0
    .space  16
    
    // Pool 3: Agent behavior data (AI state)
    .quad   0, 0, 0, 0, 0, 0
    .space  16

// Agent allocation constants - Apple Silicon optimized
.agent_constants:
    .agent_size:            .quad   128     // Agent structure size (cache-aligned)
    .agents_per_chunk:      .quad   512     // Agents per memory chunk  
    .chunk_size:            .quad   65536   // 64KB chunks for cache efficiency
    .max_agents:            .quad   1048576 // 1M agents maximum
    .allocation_alignment:  .quad   64      // L1 cache line alignment (64 bytes)
    .l2_cache_alignment:    .quad   128     // L2 cache line alignment (128 bytes)
    .false_sharing_guard:   .quad   128     // Guard against false sharing

// Performance tracking
.agent_stats:
    .total_allocations:     .quad   0
    .total_deallocations:   .quad   0
    .active_agents:         .quad   0
    .peak_agents:           .quad   0
    .allocation_time_avg:   .quad   0       // Average allocation time (ns)
    .fragmentation_ratio:   .quad   0       // Fragmentation percentage * 100

// Free list management (LIFO stack for cache locality)
.free_lists:
    .pool0_free_head:       .quad   0
    .pool1_free_head:       .quad   0
    .pool2_free_head:       .quad   0
    .pool3_free_head:       .quad   0

.section .text
.align 4

//==============================================================================
// Agent Pool Initialization
//==============================================================================

// agent_allocator_init: Initialize agent memory pools
// Args: x0 = total_memory_size, x1 = expected_agent_count
// Returns: x0 = error_code (0 = success)
.global agent_allocator_init
agent_allocator_init:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save total memory
    mov     x20, x1                     // Save expected agent count
    
    // Validate inputs
    cmp     x19, #1048576               // Minimum 1MB
    b.lt    init_error_size
    
    adrp    x1, .agent_constants
    add     x1, x1, :lo12:.agent_constants
    ldr     x2, [x1, #40]               // max_agents
    cmp     x20, x2
    b.gt    init_error_count
    
    // Calculate memory distribution across pools
    // Pool 0: 60% for active agents
    mov     x2, #60
    mul     x3, x19, x2
    mov     x4, #100
    udiv    x3, x3, x4                  // 60% of total memory
    
    // Pool 1: 25% for background agents
    mov     x2, #25
    mul     x4, x19, x2
    mov     x5, #100
    udiv    x4, x4, x5                  // 25% of total memory
    
    // Pool 2: 10% for temporary agents
    mov     x2, #10
    mul     x5, x19, x2
    mov     x6, #100
    udiv    x5, x5, x6                  // 10% of total memory
    
    // Pool 3: 5% for behavior data
    sub     x6, x19, x3                 // Remaining memory
    sub     x6, x6, x4
    sub     x6, x6, x5
    
    // Initialize each pool
    adrp    x7, .agent_pools
    add     x7, x7, :lo12:.agent_pools
    
    // Initialize Pool 0 (active agents)
    mov     x0, x3                      // size
    mov     x1, #0                      // pool_id
    bl      init_agent_pool
    cmp     x0, #0
    b.ne    init_error
    
    // Initialize Pool 1 (background agents)
    mov     x0, x4                      // size
    mov     x1, #1                      // pool_id
    bl      init_agent_pool
    cmp     x0, #0
    b.ne    init_error
    
    // Initialize Pool 2 (temporary agents)
    mov     x0, x5                      // size
    mov     x1, #2                      // pool_id
    bl      init_agent_pool
    cmp     x0, #0
    b.ne    init_error
    
    // Initialize Pool 3 (behavior data)
    mov     x0, x6                      // size
    mov     x1, #3                      // pool_id
    bl      init_agent_pool
    cmp     x0, #0
    b.ne    init_error
    
    // Initialize free lists with NEON optimization
    bl      init_free_lists_simd
    
    mov     x0, #0                      // Success
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

init_error_size:
    mov     x0, #-1                     // Invalid size
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

init_error_count:
    mov     x0, #-2                     // Invalid count
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

init_error:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// High-Performance Agent Allocation
//==============================================================================

// fast_agent_alloc: High-performance agent allocation with pool selection
// Args: x0 = agent_type (0=active, 1=background, 2=temporary, 3=behavior)
// Returns: x0 = agent_pointer, x1 = error_code
.global fast_agent_alloc
fast_agent_alloc:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Start performance timing
    mrs     x19, cntvct_el0             // Start cycle counter
    
    and     x0, x0, #3                  // Clamp to valid pool range
    mov     x20, x0                     // Save pool_id
    
    // Try fast path: get from free list
    adrp    x1, .free_lists
    add     x1, x1, :lo12:.free_lists
    ldr     x2, [x1, x0, lsl #3]        // Load free_head for pool
    
    cbz     x2, slow_path_alloc         // If no free blocks, use slow path
    
    // Fast path: pop from free list (LIFO for cache locality)
    ldr     x3, [x2]                    // Load next pointer
    str     x3, [x1, x0, lsl #3]        // Update free_head
    
    // Verify and enforce 64-byte cache alignment
    and     x4, x2, #63                 // Check alignment
    cbnz    x4, fix_alignment           // Branch if not aligned
    
aligned_continue:
    // Clear the agent memory using NEON (128 bytes = 8x 16-byte stores)
    movi    v0.16b, #0
    stp     q0, q0, [x2]                // Clear first 32 bytes
    stp     q0, q0, [x2, #32]           // Clear next 32 bytes
    stp     q0, q0, [x2, #64]           // Clear next 32 bytes
    stp     q0, q0, [x2, #96]           // Clear last 32 bytes
    
    // Update statistics atomically
    adrp    x3, .agent_stats
    add     x3, x3, :lo12:.agent_stats
    
    ldxr    x4, [x3]                    // Load total_allocations
    add     x4, x4, #1
    stxr    w5, x4, [x3]
    cbnz    w5, .-8                     // Retry if store failed
    
    ldxr    x4, [x3, #16]               // Load active_agents
    add     x4, x4, #1
    stxr    w5, x4, [x3, #16]
    cbnz    w5, .-8
    
    // Update peak if necessary
    ldr     x5, [x3, #24]               // peak_agents
    cmp     x4, x5
    b.le    no_peak_update
    str     x4, [x3, #24]
    
no_peak_update:
    // End performance timing and update average
    mrs     x4, cntvct_el0              // End cycle counter
    sub     x4, x4, x19                 // Calculate duration
    
    // Update running average (exponential moving average)
    ldr     x5, [x3, #32]               // Current average
    mov     x6, #15                     // Weight factor (15/16 old, 1/16 new)
    mul     x5, x5, x6
    add     x5, x5, x4
    lsr     x5, x5, #4                  // Divide by 16
    str     x5, [x3, #32]
    
    mov     x0, x2                      // Return agent pointer
    mov     x1, #0                      // Success
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

slow_path_alloc:
    // Slow path: allocate new chunk and populate free list
    mov     x0, x20                     // pool_id
    bl      allocate_agent_chunk
    cmp     x0, #0
    b.ne    alloc_failed
    
    // Retry fast path
    adrp    x1, .free_lists
    add     x1, x1, :lo12:.free_lists
    ldr     x2, [x1, x20, lsl #3]       // Load free_head for pool
    
    cbz     x2, alloc_failed            // Still no memory
    
    // Pop from free list
    ldr     x3, [x2]                    // Load next pointer
    str     x3, [x1, x20, lsl #3]       // Update free_head
    
    // Clear memory and update stats (same as fast path)
    movi    v0.16b, #0
    stp     q0, q0, [x2]
    stp     q0, q0, [x2, #32]
    stp     q0, q0, [x2, #64]
    stp     q0, q0, [x2, #96]
    
    mov     x0, x2                      // Return agent pointer
    mov     x1, #0                      // Success
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

fix_alignment:
    // Force proper cache alignment (this should be rare)
    add     x2, x2, #63                     // Add 63 to round up
    and     x2, x2, #~63                    // Clear low 6 bits for 64-byte alignment
    b       aligned_continue

alloc_failed:
    mov     x0, #0                      // NULL pointer
    mov     x1, #-1                     // Error code
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// High-Performance Agent Deallocation
//==============================================================================

// fast_agent_free: High-performance agent deallocation
// Args: x0 = agent_pointer
// Returns: x0 = error_code (0 = success)
.global fast_agent_free
fast_agent_free:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    cbz     x0, free_null_pointer       // Check for NULL
    
    // Determine which pool this agent belongs to
    bl      get_agent_pool_id
    mov     x1, x0                      // Save agent pointer
    mov     x2, x1                      // Save pool_id
    
    // Add to free list (LIFO for cache locality)
    adrp    x3, .free_lists
    add     x3, x3, :lo12:.free_lists
    ldr     x4, [x3, x2, lsl #3]        // Load current free_head
    str     x4, [x1]                    // Store old head as next pointer
    str     x1, [x3, x2, lsl #3]        // Set agent as new head
    
    // Optional: Clear sensitive data using NEON (first 64 bytes only for speed)
    movi    v0.16b, #0
    stp     q0, q0, [x1]                // Clear first 32 bytes
    stp     q0, q0, [x1, #32]           // Clear next 32 bytes
    
    // Update statistics atomically
    adrp    x3, .agent_stats
    add     x3, x3, :lo12:.agent_stats
    
    ldxr    x4, [x3, #8]                // Load total_deallocations
    add     x4, x4, #1
    stxr    w5, x4, [x3, #8]
    cbnz    w5, .-8
    
    ldxr    x4, [x3, #16]               // Load active_agents
    sub     x4, x4, #1
    stxr    w5, x4, [x3, #16]
    cbnz    w5, .-8
    
    mov     x0, #0                      // Success
    
    ldp     x29, x30, [sp], #16
    ret

free_null_pointer:
    mov     x0, #-1                     // Error: NULL pointer
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Batch Agent Operations (NEON Optimized)
//==============================================================================

// agent_alloc_batch: Allocate multiple agents efficiently using NEON
// Args: x0 = agent_pointers[], x1 = count, x2 = agent_type
// Returns: x0 = success_count, x1 = error_code
.global agent_alloc_batch
agent_alloc_batch:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save pointer array
    mov     x20, x1                     // Save count
    mov     x21, x2                     // Save agent_type
    
    // Process agents in batches of 4 for NEON optimization
    mov     x22, #0                     // Success counter
    mov     x23, #0                     // Index counter
    
batch_loop:
    cmp     x23, x20
    b.ge    batch_done
    
    // Check how many agents we can process in this batch
    sub     x24, x20, x23               // Remaining count
    cmp     x24, #4
    csel    x24, x24, #4, lt           // min(remaining, 4)
    
    // Allocate up to 4 agents
    mov     x25, #0                     // Batch index
batch_alloc_loop:
    cmp     x25, x24
    b.ge    next_batch
    
    mov     x0, x21                     // agent_type
    bl      fast_agent_alloc
    cbz     x0, batch_alloc_failed
    
    // Store pointer in array
    str     x0, [x19, x23, lsl #3]
    add     x22, x22, #1                // Increment success count
    
    add     x25, x25, #1                // Next in batch
    add     x23, x23, #1                // Next overall
    b       batch_alloc_loop

next_batch:
    b       batch_loop

batch_alloc_failed:
    // Set remaining pointers to NULL
    str     xzr, [x19, x23, lsl #3]
    add     x23, x23, #1
    b       batch_loop

batch_done:
    mov     x0, x22                     // Return success count
    mov     x1, #0                      // No error if any succeeded
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// agent_free_batch: Free multiple agents efficiently
// Args: x0 = agent_pointers[], x1 = count
// Returns: x0 = success_count
.global agent_free_batch
agent_free_batch:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     x2, x0                      // Save pointer array
    mov     x3, #0                      // Success counter
    mov     x4, #0                      // Index counter
    
free_batch_loop:
    cmp     x4, x1
    b.ge    free_batch_done
    
    ldr     x0, [x2, x4, lsl #3]        // Load agent pointer
    cbz     x0, skip_free               // Skip NULL pointers
    
    bl      fast_agent_free
    cbz     x0, increment_success       // If successful (returned 0)
    b       skip_free

increment_success:
    add     x3, x3, #1                  // Increment success count

skip_free:
    add     x4, x4, #1                  // Next agent
    b       free_batch_loop

free_batch_done:
    mov     x0, x3                      // Return success count
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Memory Pool Management
//==============================================================================

// init_agent_pool: Initialize a specific agent memory pool
// Args: x0 = pool_size, x1 = pool_id
// Returns: x0 = error_code
init_agent_pool:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save pool size
    mov     x20, x1                     // Save pool ID
    
    // Allocate memory for the pool
    mov     x0, x19
    bl      tlsf_alloc                  // Use main allocator
    cbz     x0, pool_init_failed
    
    // Store pool information
    adrp    x2, .agent_pools
    add     x2, x2, :lo12:.agent_pools
    mov     x3, #64                     // Pool structure size
    mul     x4, x20, x3                 // Pool offset
    add     x2, x2, x4                  // Pool structure address
    
    str     x0, [x2]                    // pool_base
    str     x19, [x2, #8]               // pool_size
    str     xzr, [x2, #16]              // free_bitmap (will be allocated)
    str     xzr, [x2, #24]              // allocation_count
    str     xzr, [x2, #32]              // peak_usage
    str     xzr, [x2, #40]              // pool_lock
    
    mov     x0, #0                      // Success
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

pool_init_failed:
    mov     x0, #-1                     // Allocation failed
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// allocate_agent_chunk: Allocate a new chunk of agents for a pool
// Args: x0 = pool_id
// Returns: x0 = error_code
allocate_agent_chunk:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save pool_id
    
    // Get chunk size and agent size
    adrp    x1, .agent_constants
    add     x1, x1, :lo12:.agent_constants
    ldr     x2, [x1, #16]               // chunk_size (64KB)
    ldr     x3, [x1]                    // agent_size (128 bytes)
    
    // Allocate chunk with proper cache alignment
    add     x0, x2, #127                    // Add alignment padding
    mov     x1, #128                        // 128-byte alignment for L2 cache
    bl      posix_memalign                  // Use aligned allocation
    cmp     x0, #0
    b.ne    chunk_alloc_failed
    
    mov     x20, x1                         // Save aligned chunk base
    
    // Calculate number of agents in chunk
    udiv    x4, x2, x3                  // agents_in_chunk = chunk_size / agent_size
    
    // Link agents in free list
    mov     x5, x20                     // Current agent
    mov     x6, #0                      // Agent index
    
link_agents_loop:
    add     x7, x6, #1                  // Next agent index
    cmp     x7, x4
    b.ge    link_last_agent
    
    // Link to next agent with cache alignment verification
    mul     x8, x7, x3                  // Next agent offset
    add     x8, x20, x8                 // Next agent address
    
    // Ensure each agent is 64-byte aligned within the chunk
    add     x8, x8, #63                 // Add 63 for rounding
    and     x8, x8, #~63                // Clear low 6 bits for alignment
    
    str     x8, [x5]                    // Store next pointer
    
    mov     x5, x8                      // Move to next agent
    mov     x6, x7                      // Update index
    b       link_agents_loop

link_last_agent:
    str     xzr, [x5]                   // Last agent points to NULL
    
    // Add chunk to free list
    adrp    x1, .free_lists
    add     x1, x1, :lo12:.free_lists
    ldr     x2, [x1, x19, lsl #3]       // Current free_head
    str     x2, [x20]                   // Link to existing free list
    str     x20, [x1, x19, lsl #3]      // Set chunk as new head
    
    mov     x0, #0                      // Success
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

chunk_alloc_failed:
    mov     x0, #-1                     // Allocation failed
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// get_agent_pool_id: Determine which pool an agent belongs to
// Args: x0 = agent_pointer
// Returns: x0 = pool_id, x1 = error_code
get_agent_pool_id:
    // For now, use a simple hash of the address
    // In a full implementation, this would check pool ranges
    lsr     x1, x0, #16                 // Rough hash
    and     x0, x1, #3                  // Map to pool 0-3
    mov     x1, #0                      // Success
    ret

// init_free_lists_simd: Initialize free lists with NEON optimization
// Returns: none
init_free_lists_simd:
    adrp    x0, .free_lists
    add     x0, x0, :lo12:.free_lists
    
    // Clear all free list heads using NEON
    movi    v0.16b, #0
    stp     q0, q0, [x0]                // Clear all 4 free list heads
    
    ret

//==============================================================================
// Performance Monitoring and Statistics
//==============================================================================

// agent_get_allocation_stats: Get current allocation statistics
// Args: x0 = stats_output_struct
// Returns: none
.global agent_get_allocation_stats
agent_get_allocation_stats:
    adrp    x1, .agent_stats
    add     x1, x1, :lo12:.agent_stats
    
    // Copy entire stats structure using NEON
    ld1     {v0.2d, v1.2d, v2.2d}, [x1]
    st1     {v0.2d, v1.2d, v2.2d}, [x0]
    
    ret

// agent_benchmark_allocation: Benchmark allocation performance
// Args: x0 = iterations, x1 = agent_type
// Returns: x0 = avg_time_ns, x1 = total_time_ns
.global agent_benchmark_allocation
agent_benchmark_allocation:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save iterations
    mov     x20, x1                     // Save agent_type
    
    // Start timing
    mrs     x21, cntvct_el0
    
    // Allocation benchmark loop
    mov     x22, #0                     // Counter
benchmark_alloc_loop:
    cmp     x22, x19
    b.ge    benchmark_alloc_done
    
    mov     x0, x20
    bl      fast_agent_alloc
    cbz     x0, benchmark_alloc_failed
    
    // Immediately free to avoid memory exhaustion
    bl      fast_agent_free
    
    add     x22, x22, #1
    b       benchmark_alloc_loop

benchmark_alloc_done:
    // End timing
    mrs     x0, cntvct_el0
    sub     x1, x0, x21                 // Total time
    udiv    x0, x1, x19                 // Average time
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

benchmark_alloc_failed:
    mov     x0, #0                      // Failed
    mov     x1, #0
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.end