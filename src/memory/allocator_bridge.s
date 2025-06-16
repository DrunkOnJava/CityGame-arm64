// SimCity ARM64 Memory Allocator Bridge
// Agent 2: Memory Integration Engineer
// 
// This file provides unified C-compatible interfaces to all memory allocators

.cpu generic+simd
.arch armv8-a+simd

.include "../include/constants/memory.inc"
.include "../include/macros/memory.inc"

.section .text
.align 4

//==============================================================================
// UNIFIED MEMORY INTERFACE
//==============================================================================

// simcity_malloc: Unified memory allocation interface
// Args: x0 = size, x1 = flags (alignment, pool type, etc.)
// Returns: x0 = pointer (or NULL on failure)
.global simcity_malloc
simcity_malloc:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    mov x19, x0  // Save size
    mov x20, x1  // Save flags
    
    // Check allocation type based on flags
    tst x20, #0x1  // TLS flag
    b.ne .malloc_tls
    
    tst x20, #0x2  // Agent flag
    b.ne .malloc_agent
    
    tst x20, #0x4  // Graphics flag
    b.ne .malloc_graphics
    
    // Default: use TLSF allocator
    mov x0, x19
    bl tlsf_alloc
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

.malloc_tls:
    // Use thread-local allocator
    mov x0, #0  // Default agent type
    bl tls_agent_alloc
    mov x0, x0  // Return pointer from x0
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

.malloc_agent:
    // Use agent allocator
    and x0, x20, #0x18  // Extract agent type (bits 3-4)
    lsr x0, x0, #3
    bl fast_agent_alloc
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

.malloc_graphics:
    // Use graphics allocator (for now, use TLSF)
    mov x0, x19
    bl tlsf_alloc
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// simcity_free: Unified memory deallocation interface
// Args: x0 = pointer, x1 = flags (optional, for type hints)
// Returns: x0 = error code (0 = success)
.global simcity_free
simcity_free:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    cbz x0, .free_null_ok  // free(NULL) is valid
    
    // For now, route everything to TLSF free
    // In a more sophisticated implementation, we'd track allocation type
    bl tlsf_free
    
    ldp x29, x30, [sp], #16
    ret

.free_null_ok:
    mov x0, #0  // Success
    ldp x29, x30, [sp], #16
    ret

// simcity_realloc: Unified memory reallocation interface
// Args: x0 = old_ptr, x1 = new_size, x2 = flags
// Returns: x0 = new_pointer (or NULL on failure)
.global simcity_realloc
simcity_realloc:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    mov x19, x0  // old_ptr
    mov x20, x1  // new_size
    
    // If old_ptr is NULL, this is just malloc
    cbz x19, .realloc_malloc
    
    // If new_size is 0, this is just free
    cbz x20, .realloc_free
    
    // Use TLSF realloc for now
    mov x0, x19
    mov x1, x20
    bl tlsf_realloc
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

.realloc_malloc:
    mov x0, x20
    mov x1, #0  // Default flags
    bl simcity_malloc
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

.realloc_free:
    mov x0, x19
    mov x1, #0  // Default flags
    bl simcity_free
    mov x0, #0  // Return NULL
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

//==============================================================================
// MEMORY STATISTICS AND MONITORING
//==============================================================================

// get_memory_stats: Get comprehensive memory statistics
// Args: x0 = stats_buffer (at least 128 bytes)
// Returns: x0 = error_code
.global get_memory_stats
get_memory_stats:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    cbz x0, .stats_error
    
    // Clear the buffer first
    mov x1, #128
    mov x2, #0
    bl memset
    
    // Get TLSF stats (if available)
    // For now, just return success
    mov x0, #0
    
    ldp x29, x30, [sp], #16
    ret

.stats_error:
    mov x0, #-1
    ldp x29, x30, [sp], #16
    ret

// get_allocation_info: Get information about a specific allocation
// Args: x0 = pointer
// Returns: x0 = size (or 0 if invalid), x1 = type flags
.global get_allocation_info
get_allocation_info:
    // For now, we can't determine allocation info without metadata
    // This would require enhancement to store allocation metadata
    mov x0, #0
    mov x1, #0
    ret

//==============================================================================
// MEMORY POOL MANAGEMENT
//==============================================================================

// create_memory_pool: Create a dedicated memory pool
// Args: x0 = pool_size, x1 = object_size, x2 = flags
// Returns: x0 = pool_handle (or NULL on failure)
.global create_memory_pool
create_memory_pool:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    // For now, allocate pool metadata from main allocator
    mov x19, x0  // Save pool_size
    mov x20, x1  // Save object_size
    
    // Allocate pool descriptor (64 bytes)
    mov x0, #64
    bl tlsf_alloc
    cbz x0, .pool_create_failed
    
    // Initialize pool descriptor
    str x19, [x0, #0]   // pool_size
    str x20, [x0, #8]   // object_size
    str xzr, [x0, #16]  // allocated_count
    str xzr, [x0, #24]  // free_list
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

.pool_create_failed:
    mov x0, #0
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// destroy_memory_pool: Destroy a memory pool
// Args: x0 = pool_handle
// Returns: x0 = error_code
.global destroy_memory_pool
destroy_memory_pool:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    cbz x0, .pool_destroy_error
    
    // Free the pool descriptor
    bl tlsf_free
    mov x0, #0  // Success
    
    ldp x29, x30, [sp], #16
    ret

.pool_destroy_error:
    mov x0, #-1
    ldp x29, x30, [sp], #16
    ret

//==============================================================================
// CACHE-OPTIMIZED MEMORY OPERATIONS
//==============================================================================

// fast_memset: Cache-optimized memory clear using NEON
// Args: x0 = dst, x1 = value, x2 = size
// Returns: x0 = dst
.global fast_memset
fast_memset:
    mov x3, x0          // Save original dst
    
    // Duplicate value to fill entire register
    and w1, w1, #0xFF
    orr w1, w1, w1, lsl #8
    orr w1, w1, w1, lsl #16
    orr x1, x1, x1, lsl #32
    
    // Fill NEON register with value
    dup v0.2d, x1
    
    // Handle small sizes
    cmp x2, #64
    b.lt .memset_small
    
    // Large size: use NEON for 64-byte chunks
    and x4, x2, #~63    // Round down to 64-byte boundary
    add x5, x0, x4      // End of NEON copy
    
.memset_neon_loop:
    stp q0, q0, [x0], #32
    stp q0, q0, [x0], #32
    cmp x0, x5
    b.lt .memset_neon_loop
    
    and x2, x2, #63     // Remaining bytes
    
.memset_small:
    // Handle remaining bytes with regular stores
    cmp x2, #8
    b.lt .memset_bytes
    
    str x1, [x0], #8
    sub x2, x2, #8
    b .memset_small
    
.memset_bytes:
    cbz x2, .memset_done
    strb w1, [x0], #1
    sub x2, x2, #1
    b .memset_bytes
    
.memset_done:
    mov x0, x3          // Return original dst
    ret

// fast_memcpy: Cache-optimized memory copy using NEON
// Args: x0 = dst, x1 = src, x2 = size
// Returns: x0 = dst
.global fast_memcpy
fast_memcpy:
    mov x3, x0          // Save original dst
    
    // Handle small sizes
    cmp x2, #64
    b.lt .memcpy_small
    
    // Large size: use NEON for 64-byte chunks
    and x4, x2, #~63    // Round down to 64-byte boundary
    add x5, x1, x4      // End of NEON copy
    
.memcpy_neon_loop:
    ldp q0, q1, [x1], #32
    ldp q2, q3, [x1], #32
    stp q0, q1, [x0], #32
    stp q2, q3, [x0], #32
    cmp x1, x5
    b.lt .memcpy_neon_loop
    
    and x2, x2, #63     // Remaining bytes
    
.memcpy_small:
    // Handle remaining bytes
    cmp x2, #8
    b.lt .memcpy_bytes
    
    ldr x4, [x1], #8
    str x4, [x0], #8
    sub x2, x2, #8
    b .memcpy_small
    
.memcpy_bytes:
    cbz x2, .memcpy_done
    ldrb w4, [x1], #1
    strb w4, [x0], #1
    sub x2, x2, #1
    b .memcpy_bytes
    
.memcpy_done:
    mov x0, x3          // Return original dst
    ret

//==============================================================================
// EXTERNAL FUNCTION REFERENCES
//==============================================================================

.extern tlsf_alloc
.extern tlsf_free
.extern tlsf_realloc
.extern tls_agent_alloc
.extern fast_agent_alloc
.extern memset

.end