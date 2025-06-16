//
// SimCity ARM64 Assembly - Memory Allocator Integration
// Agent E1: Platform Architect
//
// Integration layer between bootstrap system and Agent D1's memory allocator
// Provides standard C library memory interface using high-performance assembly allocators
//

.cpu generic+simd
.arch armv8-a+simd

// Include platform constants
.include "../include/macros/platform_asm.inc"
.include "../include/constants/memory.inc"

.section .data
.align 3

//==============================================================================
// Memory Integration State
//==============================================================================

.memory_integration_state:
    allocator_initialized:      .byte   0
    tlsf_initialized:           .byte   0
    agent_allocator_ready:      .byte   0
    total_allocated:            .quad   0
    total_freed:                .quad   0
    peak_usage:                 .quad   0
    allocation_count:           .quad   0
    .align 3

// Memory pool assignments for different allocation types
.memory_pools:
    cocoa_pool_id:              .quad   0       // Pool for Cocoa objects
    metal_pool_id:              .quad   1       // Pool for Metal resources
    temp_pool_id:               .quad   2       // Pool for temporary allocations
    string_pool_id:             .quad   3       // Pool for string objects

// Allocation size thresholds
.allocation_thresholds:
    small_alloc_threshold:      .quad   256     // <= 256 bytes: use agent allocator
    medium_alloc_threshold:     .quad   4096    // <= 4KB: use pool allocator
    large_alloc_threshold:      .quad   65536   // <= 64KB: use TLSF
    // > 64KB: use system mmap

.section .text
.align 4

//==============================================================================
// Memory Integration Initialization
//==============================================================================

.global memory_integration_init
// memory_integration_init: Initialize memory integration layer
// Returns: x0 = 0 on success, error code on failure
memory_integration_init:
    SAVE_REGS_LIGHT
    
    // Check if already initialized
    adrp    x19, memory_integration_state@PAGE
    add     x19, x19, memory_integration_state@PAGEOFF
    ldrb    w0, [x19]
    cbnz    w0, memory_init_already_done
    
    // Verify Agent D1's allocator is ready
    ldrb    w0, [x19, #2]           // agent_allocator_ready
    cbz     w0, memory_init_error
    
    // Initialize allocation tracking
    str     xzr, [x19, #8]          // total_allocated = 0
    str     xzr, [x19, #16]         // total_freed = 0
    str     xzr, [x19, #24]         // peak_usage = 0
    str     xzr, [x19, #32]         // allocation_count = 0
    
    // Mark as initialized
    mov     w0, #1
    strb    w0, [x19]               // allocator_initialized = true
    
memory_init_already_done:
    mov     x0, #0                  // Success
    RESTORE_REGS_LIGHT
    ret

memory_init_error:
    mov     x0, #-1                 // Error
    RESTORE_REGS_LIGHT
    ret

.global memory_integration_shutdown
// memory_integration_shutdown: Shutdown memory integration
// Returns: none
memory_integration_shutdown:
    SAVE_REGS_LIGHT
    
    // Get integration state
    adrp    x19, memory_integration_state@PAGE
    add     x19, x19, memory_integration_state@PAGEOFF
    
    // Print final statistics if debug enabled
    bl      print_memory_statistics
    
    // Mark as uninitialized
    strb    wzr, [x19]              // allocator_initialized = false
    
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Standard C Library Memory Interface
//==============================================================================

.global malloc
// malloc: Allocate memory block
// Args: x0 = size
// Returns: x0 = pointer or 0 on failure
malloc:
    SAVE_REGS_LIGHT
    
    mov     x19, x0                 // Save size
    
    // Check if integration is initialized
    adrp    x20, memory_integration_state@PAGE
    add     x20, x20, memory_integration_state@PAGEOFF
    ldrb    w0, [x20]
    cbz     w0, malloc_fallback
    
    // Choose allocation strategy based on size
    bl      choose_allocation_strategy
    mov     x21, x0                 // Save strategy
    
    // Dispatch to appropriate allocator
    cmp     x21, #0
    b.eq    malloc_agent_allocator
    cmp     x21, #1
    b.eq    malloc_pool_allocator
    cmp     x21, #2
    b.eq    malloc_tlsf_allocator
    b       malloc_system_allocator

malloc_agent_allocator:
    // Use Agent D1's high-performance agent allocator
    mov     x0, #0                  // Agent type: general purpose
    bl      fast_agent_alloc
    // x0 already contains pointer
    b       malloc_update_stats

malloc_pool_allocator:
    // Use pool allocator for medium-sized objects
    mov     x0, x19                 // size
    bl      pool_alloc
    b       malloc_update_stats

malloc_tlsf_allocator:
    // Use TLSF allocator for large objects
    mov     x0, x19                 // size
    bl      tlsf_alloc
    b       malloc_update_stats

malloc_system_allocator:
    // Use system mmap for very large allocations
    mov     x0, x19                 // size
    bl      system_mmap_alloc
    b       malloc_update_stats

malloc_update_stats:
    cbz     x0, malloc_done         // Skip stats if allocation failed
    
    // Update allocation statistics atomically
    ldxr    x1, [x20, #8]           // total_allocated
    add     x1, x1, x19             // Add size
    stxr    w2, x1, [x20, #8]
    cbnz    w2, .-8                 // Retry if store failed
    
    ldxr    x1, [x20, #32]          // allocation_count
    add     x1, x1, #1
    stxr    w2, x1, [x20, #32]
    cbnz    w2, .-8
    
    // Update peak usage if necessary
    ldr     x1, [x20, #8]           // total_allocated
    ldr     x2, [x20, #16]          // total_freed
    sub     x3, x1, x2              // current_usage
    ldr     x4, [x20, #24]          // peak_usage
    cmp     x3, x4
    b.le    malloc_done
    str     x3, [x20, #24]          // Update peak

malloc_done:
    RESTORE_REGS_LIGHT
    ret

malloc_fallback:
    // Fallback to simple system allocation if integration not ready
    mov     x0, x19                 // size
    bl      simple_system_malloc
    RESTORE_REGS_LIGHT
    ret

.global free
// free: Free memory block
// Args: x0 = pointer
// Returns: none
free:
    SAVE_REGS_LIGHT
    
    cbz     x0, free_done           // Handle NULL pointer
    mov     x19, x0                 // Save pointer
    
    // Check if integration is initialized
    adrp    x20, memory_integration_state@PAGE
    add     x20, x20, memory_integration_state@PAGEOFF
    ldrb    w0, [x20]
    cbz     w0, free_fallback
    
    // Determine which allocator owns this pointer
    mov     x0, x19
    bl      identify_allocator_for_pointer
    mov     x21, x0                 // Save allocator type
    
    // Dispatch to appropriate free function
    cmp     x21, #0
    b.eq    free_agent_allocator
    cmp     x21, #1
    b.eq    free_pool_allocator
    cmp     x21, #2
    b.eq    free_tlsf_allocator
    b       free_system_allocator

free_agent_allocator:
    mov     x0, x19
    bl      fast_agent_free
    b       free_update_stats

free_pool_allocator:
    mov     x0, x19
    bl      pool_free
    b       free_update_stats

free_tlsf_allocator:
    mov     x0, x19
    bl      tlsf_free
    b       free_update_stats

free_system_allocator:
    mov     x0, x19
    bl      system_munmap_free
    b       free_update_stats

free_update_stats:
    // Update free statistics (size tracking requires metadata)
    // For now, just increment free count
    ldxr    x1, [x20, #32]          // allocation_count
    sub     x1, x1, #1
    stxr    w2, x1, [x20, #32]
    cbnz    w2, .-8

free_done:
    RESTORE_REGS_LIGHT
    ret

free_fallback:
    mov     x0, x19
    bl      simple_system_free
    RESTORE_REGS_LIGHT
    ret

.global realloc
// realloc: Reallocate memory block
// Args: x0 = old_ptr, x1 = new_size
// Returns: x0 = new_pointer or 0 on failure
realloc:
    SAVE_REGS_LIGHT
    
    mov     x19, x0                 // Save old_ptr
    mov     x20, x1                 // Save new_size
    
    // Handle special cases
    cbz     x19, realloc_as_malloc  // realloc(NULL, size) == malloc(size)
    cbz     x20, realloc_as_free    // realloc(ptr, 0) == free(ptr); return NULL
    
    // Allocate new block
    mov     x0, x20                 // new_size
    bl      malloc
    cbz     x0, realloc_failed      // Allocation failed
    mov     x21, x0                 // Save new_ptr
    
    // Copy data from old to new
    mov     x0, x21                 // dest
    mov     x1, x19                 // src
    bl      get_allocation_size     // Get size of old allocation
    mov     x2, x0                  // copy_size
    cmp     x2, x20                 // min(old_size, new_size)
    csel    x2, x2, x20, lt
    bl      fast_memcpy
    
    // Free old block
    mov     x0, x19
    bl      free
    
    mov     x0, x21                 // Return new_ptr
    RESTORE_REGS_LIGHT
    ret

realloc_as_malloc:
    mov     x0, x20                 // new_size
    bl      malloc
    RESTORE_REGS_LIGHT
    ret

realloc_as_free:
    mov     x0, x19                 // old_ptr
    bl      free
    mov     x0, #0                  // Return NULL
    RESTORE_REGS_LIGHT
    ret

realloc_failed:
    mov     x0, #0                  // Return NULL on failure
    RESTORE_REGS_LIGHT
    ret

.global calloc
// calloc: Allocate and zero memory
// Args: x0 = count, x1 = size
// Returns: x0 = pointer or 0 on failure
calloc:
    SAVE_REGS_LIGHT
    
    // Calculate total size (count * size)
    mul     x19, x0, x1             // total_size
    
    // Check for overflow
    cmp     x1, #0
    b.eq    calloc_zero_size
    udiv    x2, x19, x1             // total_size / size
    cmp     x2, x0                  // Should equal count
    b.ne    calloc_overflow
    
    // Allocate memory
    mov     x0, x19                 // total_size
    bl      malloc
    cbz     x0, calloc_failed
    
    // Zero the memory using NEON for efficiency
    mov     x1, x0                  // Save pointer
    mov     x2, x19                 // size
    bl      fast_memzero
    
    mov     x0, x1                  // Return pointer
    RESTORE_REGS_LIGHT
    ret

calloc_zero_size:
calloc_overflow:
calloc_failed:
    mov     x0, #0                  // Return NULL
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Allocation Strategy Selection
//==============================================================================

// choose_allocation_strategy: Choose best allocator for given size
// Args: x19 = size
// Returns: x0 = strategy (0=agent, 1=pool, 2=tlsf, 3=system)
choose_allocation_strategy:
    adrp    x1, allocation_thresholds@PAGE
    add     x1, x1, allocation_thresholds@PAGEOFF
    
    ldr     x2, [x1]                // small_alloc_threshold
    cmp     x19, x2
    b.le    strategy_agent
    
    ldr     x2, [x1, #8]            // medium_alloc_threshold
    cmp     x19, x2
    b.le    strategy_pool
    
    ldr     x2, [x1, #16]           // large_alloc_threshold
    cmp     x19, x2
    b.le    strategy_tlsf
    
    mov     x0, #3                  // system
    ret

strategy_agent:
    mov     x0, #0                  // agent allocator
    ret

strategy_pool:
    mov     x0, #1                  // pool allocator
    ret

strategy_tlsf:
    mov     x0, #2                  // tlsf allocator
    ret

// identify_allocator_for_pointer: Determine which allocator owns a pointer
// Args: x0 = pointer
// Returns: x0 = allocator_type (0=agent, 1=pool, 2=tlsf, 3=system)
identify_allocator_for_pointer:
    SAVE_REGS_LIGHT
    
    mov     x19, x0                 // Save pointer
    
    // Check if pointer is in agent allocator range
    bl      is_agent_allocator_pointer
    cbnz    x0, identify_agent
    
    // Check if pointer is in pool allocator range
    mov     x0, x19
    bl      is_pool_allocator_pointer
    cbnz    x0, identify_pool
    
    // Check if pointer is in TLSF allocator range
    mov     x0, x19
    bl      is_tlsf_allocator_pointer
    cbnz    x0, identify_tlsf
    
    // Must be system allocation
    mov     x0, #3
    RESTORE_REGS_LIGHT
    ret

identify_agent:
    mov     x0, #0
    RESTORE_REGS_LIGHT
    ret

identify_pool:
    mov     x0, #1
    RESTORE_REGS_LIGHT
    ret

identify_tlsf:
    mov     x0, #2
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Memory Utility Functions
//==============================================================================

// fast_memcpy: High-performance memory copy using NEON
// Args: x0 = dest, x1 = src, x2 = size
// Returns: none
fast_memcpy:
    SAVE_REGS_LIGHT
    
    mov     x3, x0                  // Save dest
    
    // Handle small copies with regular loads/stores
    cmp     x2, #64
    b.lt    memcpy_small
    
    // Use NEON for larger copies
memcpy_neon_loop:
    cmp     x2, #64
    b.lt    memcpy_remainder
    
    // Copy 64 bytes at a time using NEON
    ld1     {v0.16b, v1.16b, v2.16b, v3.16b}, [x1], #64
    st1     {v0.16b, v1.16b, v2.16b, v3.16b}, [x0], #64
    sub     x2, x2, #64
    b       memcpy_neon_loop

memcpy_remainder:
    // Handle remaining bytes
    cbz     x2, memcpy_done
    
memcpy_byte_loop:
    ldrb    w4, [x1], #1
    strb    w4, [x0], #1
    subs    x2, x2, #1
    b.ne    memcpy_byte_loop
    b       memcpy_done

memcpy_small:
    // Small copy optimization
    cbz     x2, memcpy_done
    
memcpy_small_loop:
    ldrb    w4, [x1], #1
    strb    w4, [x0], #1
    subs    x2, x2, #1
    b.ne    memcpy_small_loop

memcpy_done:
    mov     x0, x3                  // Return dest
    RESTORE_REGS_LIGHT
    ret

// fast_memzero: High-performance memory zeroing using NEON
// Args: x0 = ptr, x1 = size
// Returns: none
fast_memzero:
    // Zero vector registers
    movi    v0.16b, #0
    movi    v1.16b, #0
    movi    v2.16b, #0
    movi    v3.16b, #0
    
    // Handle large blocks with NEON
memzero_neon_loop:
    cmp     x1, #64
    b.lt    memzero_remainder
    
    st1     {v0.16b, v1.16b, v2.16b, v3.16b}, [x0], #64
    sub     x1, x1, #64
    b       memzero_neon_loop

memzero_remainder:
    // Handle remaining bytes
    cbz     x1, memzero_done
    
memzero_byte_loop:
    strb    wzr, [x0], #1
    subs    x1, x1, #1
    b.ne    memzero_byte_loop

memzero_done:
    ret

//==============================================================================
// System Memory Functions (Fallback)
//==============================================================================

// simple_system_malloc: Simple system malloc fallback
// Args: x0 = size
// Returns: x0 = pointer or 0
simple_system_malloc:
    // This would call system malloc() in a real implementation
    // For now, return NULL to indicate failure
    mov     x0, #0
    ret

// simple_system_free: Simple system free fallback
// Args: x0 = pointer
// Returns: none
simple_system_free:
    // This would call system free() in a real implementation
    ret

// system_mmap_alloc: Large allocation using mmap
// Args: x0 = size
// Returns: x0 = pointer or 0
system_mmap_alloc:
    SAVE_REGS_LIGHT
    
    mov     x19, x0                 // Save size
    
    // Round up to page boundary
    add     x0, x19, #4095
    and     x0, x0, #~4095          // Page-aligned size
    
    // mmap(NULL, size, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANON, -1, 0)
    mov     x1, x0                  // size
    mov     x0, #0                  // addr = NULL
    mov     x2, #3                  // prot = PROT_READ|PROT_WRITE
    mov     x3, #0x1002             // flags = MAP_PRIVATE|MAP_ANON
    mov     x4, #-1                 // fd = -1
    mov     x5, #0                  // offset = 0
    
    mov     x16, #197               // SYS_mmap
    svc     #0x80
    
    // Check for error
    cmp     x0, #-1
    b.eq    mmap_alloc_error
    
    RESTORE_REGS_LIGHT
    ret

mmap_alloc_error:
    mov     x0, #0                  // Return NULL on error
    RESTORE_REGS_LIGHT
    ret

// system_munmap_free: Free mmap allocation
// Args: x0 = pointer
// Returns: none
system_munmap_free:
    SAVE_REGS_LIGHT
    
    // Note: This requires knowing the size of the original allocation
    // In a real implementation, we'd store this information
    // For now, this is a stub
    
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Debugging and Statistics
//==============================================================================

// print_memory_statistics: Print current memory usage statistics
// Returns: none
print_memory_statistics:
    SAVE_REGS_LIGHT
    
    adrp    x19, memory_integration_state@PAGE
    add     x19, x19, memory_integration_state@PAGEOFF
    
    // TODO: Implement printf-style output for statistics
    // This would show:
    // - Total allocated bytes
    // - Total freed bytes
    // - Current usage
    // - Peak usage
    // - Allocation count
    
    RESTORE_REGS_LIGHT
    ret

// get_allocation_size: Get size of allocated block (stub)
// Args: x0 = pointer
// Returns: x0 = size
get_allocation_size:
    // This is a stub - real implementation would track allocation sizes
    mov     x0, #128                // Default size
    ret

//==============================================================================
// Allocator Pointer Identification (Stubs)
//==============================================================================

// These functions would check if a pointer belongs to a specific allocator
// by checking address ranges. Implementation depends on allocator internals.

is_agent_allocator_pointer:
    mov     x0, #0                  // Stub: return false
    ret

is_pool_allocator_pointer:
    mov     x0, #0                  // Stub: return false
    ret

is_tlsf_allocator_pointer:
    mov     x0, #0                  // Stub: return false
    ret

.end