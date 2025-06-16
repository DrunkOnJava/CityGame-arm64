// tlsf.s - Two-Level Segregated Fit Memory Allocator
// SimCity ARM64 Assembly Project - Agent 2: Memory Management
//
// High-performance O(1) memory allocator based on the TLSF algorithm
// Provides deterministic allocation and deallocation suitable for real-time systems
//
// References:
// - "TLSF: A New Dynamic Memory Allocator for Real-Time Systems" by M. Masmano et al.
// - ARM64 optimization techniques for cache efficiency

.text
.align 4

// Include our memory system definitions
.include "../include/constants/memory.inc"
.include "../include/types/memory.inc"
.include "../include/macros/memory.inc"

// ============================================================================
// GLOBAL SYMBOLS
// ============================================================================

.global tlsf_init
.global tlsf_alloc
.global tlsf_free
.global tlsf_realloc

// ============================================================================
// DATA SECTION
// ============================================================================

.data
.align 6                                // Cache-line aligned

// Main TLSF control structure (cache-aligned)
tlsf_control_block:
    .quad   0                           // fl_bitmap
    .fill   TLSF_FL_INDEX_COUNT, 8, 0   // sl_bitmap[31]
    .fill   992, 8, 0                   // blocks[31][32] = 992 pointers
                                        // Padding to cache line already included

// Global allocator state
allocator_base:         .quad   0       // Base address of heap
allocator_size:         .quad   0       // Total heap size
allocator_initialized: .quad   0       // Initialization flag
allocator_lock:         .quad   0       // Simple spinlock for thread safety

// Statistics (for performance monitoring)
.align 6
stats_total_allocs:     .quad   0
stats_total_frees:      .quad   0
stats_bytes_allocated:  .quad   0
stats_peak_usage:       .quad   0
stats_current_usage:    .quad   0

// ============================================================================
// TLSF INITIALIZATION
// ============================================================================

// tlsf_init: Initialize the TLSF allocator
// Arguments:
//   x0 = heap_start (base address of heap)
//   x1 = heap_size (size of heap in bytes)
// Returns:
//   x0 = error code (0 = success, negative = error)
tlsf_init:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Validate input parameters
    CHECK_NULL x0, .init_error_null
    CHECK_SIZE x1, .init_error_size
    
    // Check minimum heap size (must be at least 64KB)
    cmp     x1, #65536
    b.lt    .init_error_size
    
    // Store heap parameters
    adrp    x19, allocator_base
    add     x19, x19, :lo12:allocator_base
    str     x0, [x19]                   // Store base address
    str     x1, [x19, #8]               // Store size
    
    // Align heap start to cache line boundary
    mov     x2, x0
    CACHE_ALIGN x2
    
    // Calculate aligned heap size
    sub     x3, x0, x2                  // Alignment overhead
    sub     x1, x1, x3                  // Adjust size
    mov     x0, x2                      // Use aligned base
    
    // Initialize control structure
    adrp    x20, tlsf_control_block
    add     x20, x20, :lo12:tlsf_control_block
    
    // Clear all bitmaps
    str     xzr, [x20]                  // Clear fl_bitmap
    add     x2, x20, #8
    mov     x3, #TLSF_FL_INDEX_COUNT
.clear_sl_bitmaps:
    str     xzr, [x2], #8
    subs    x3, x3, #1
    b.ne    .clear_sl_bitmaps
    
    // Clear all block pointers (992 entries)
    add     x2, x20, #8 + (TLSF_FL_INDEX_COUNT * 8)
    mov     x3, #992
.clear_blocks:
    str     xzr, [x2], #8
    subs    x3, x3, #1
    b.ne    .clear_blocks
    
    // Create initial free block covering entire heap
    mov     x2, x0                      // Block address
    sub     x3, x1, #TLSF_BLOCK_HEADER_SIZE  // Block size
    orr     x3, x3, #TLSF_BLOCK_FREE    // Mark as free
    str     x3, [x2]                    // Store size + flags
    str     xzr, [x2, #8]               // No previous physical block
    str     xzr, [x2, #16]              // No next free block
    str     xzr, [x2, #24]              // No previous free block
    
    // Insert initial block into free lists
    bl      .insert_free_block
    
    // Mark allocator as initialized
    mov     x0, #1
    str     x0, [x19, #16]              // Set initialized flag
    
    MEMORY_BARRIER_FULL
    
    mov     x0, #MEM_SUCCESS
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.init_error_null:
    mov     x0, #MEM_ERROR_NULL_PTR
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.init_error_size:
    mov     x0, #MEM_ERROR_INVALID_SIZE
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ============================================================================
// TLSF ALLOCATION
// ============================================================================

// tlsf_alloc: Allocate memory block
// Arguments:
//   x0 = size (requested size in bytes)
// Returns:
//   x0 = pointer to allocated memory (NULL on failure)
//   x1 = error code (0 = success, negative = error)
tlsf_alloc:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // Save requested size
    
    // Check if allocator is initialized
    adrp    x1, allocator_initialized
    add     x1, x1, :lo12:allocator_initialized
    ldr     x2, [x1]
    cbz     x2, .alloc_not_initialized
    
    // Validate size parameter
    CHECK_SIZE x19, .alloc_error_size
    
    // Acquire allocator lock (simple spinlock)
    adrp    x1, allocator_lock
    add     x1, x1, :lo12:allocator_lock
.acquire_lock:
    ldaxr   x2, [x1]
    cbnz    x2, .acquire_lock
    mov     x2, #1
    stlxr   w3, x2, [x1]
    cbnz    w3, .acquire_lock
    
    // Adjust size for alignment and minimum requirements
    add     x19, x19, #TLSF_ALIGN_SIZE - 1
    and     x19, x19, #~(TLSF_ALIGN_SIZE - 1)
    cmp     x19, #TLSF_MIN_ALLOC
    csel    x19, x19, #TLSF_MIN_ALLOC, hi
    
    // Map size to TLSF indices
    TLSF_MAPPING x19, x20, x21          // x20 = fli, x21 = sli
    
    // Find suitable free block
    bl      .find_suitable_block
    cbz     x0, .alloc_out_of_memory
    
    mov     x22, x0                     // Save block pointer
    
    // Remove block from free list
    mov     x0, x22
    bl      .remove_free_block
    
    // Split block if necessary
    mov     x0, x22
    mov     x1, x19
    bl      .split_block
    
    // Mark block as allocated
    ldr     x1, [x22]
    bic     x1, x1, #TLSF_BLOCK_FREE
    str     x1, [x22]
    
    // Update statistics
    adrp    x1, stats_total_allocs
    add     x1, x1, :lo12:stats_total_allocs
    ATOMIC_INC x1, x2
    
    adrp    x1, stats_bytes_allocated
    add     x1, x1, :lo12:stats_bytes_allocated
1:  ldxr    x2, [x1]
    add     x3, x2, x19
    stxr    w4, x3, [x1]
    cbnz    w4, 1b
    
    adrp    x1, stats_current_usage
    add     x1, x1, :lo12:stats_current_usage
2:  ldxr    x2, [x1]
    add     x3, x2, x19
    stxr    w4, x3, [x1]
    cbnz    w4, 2b
    
    // Update peak usage
    adrp    x1, stats_peak_usage
    add     x1, x1, :lo12:stats_peak_usage
    ldr     x4, [x1]
    cmp     x3, x4
    b.le    3f
    str     x3, [x1]
3:
    
    // Release lock
    adrp    x1, allocator_lock
    add     x1, x1, :lo12:allocator_lock
    stlr    xzr, [x1]
    
    // Return pointer to data (after header)
    add     x0, x22, #TLSF_BLOCK_HEADER_SIZE
    mov     x1, #MEM_SUCCESS
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.alloc_not_initialized:
    mov     x0, xzr
    mov     x1, #MEM_ERROR_INIT_FAILED
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.alloc_error_size:
    // Release lock if held
    adrp    x1, allocator_lock
    add     x1, x1, :lo12:allocator_lock
    stlr    xzr, [x1]
    
    mov     x0, xzr
    mov     x1, #MEM_ERROR_INVALID_SIZE
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.alloc_out_of_memory:
    // Release lock
    adrp    x1, allocator_lock
    add     x1, x1, :lo12:allocator_lock
    stlr    xzr, [x1]
    
    mov     x0, xzr
    mov     x1, #MEM_ERROR_OUT_OF_MEMORY
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ============================================================================
// TLSF DEALLOCATION
// ============================================================================

// tlsf_free: Free memory block
// Arguments:
//   x0 = pointer to memory block
// Returns:
//   x0 = error code (0 = success, negative = error)
tlsf_free:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save pointer
    
    // Check for null pointer
    CHECK_NULL x19, .free_error_null
    
    // Get block header
    sub     x20, x19, #TLSF_BLOCK_HEADER_SIZE
    
    // Validate block (basic checks)
    ldr     x1, [x20]
    tst     x1, #TLSF_BLOCK_FREE
    b.ne    .free_error_double_free     // Already free
    
    // Acquire lock
    adrp    x1, allocator_lock
    add     x1, x1, :lo12:allocator_lock
.free_acquire_lock:
    ldaxr   x2, [x1]
    cbnz    x2, .free_acquire_lock
    mov     x2, #1
    stlxr   w3, x2, [x1]
    cbnz    w3, .free_acquire_lock
    
    // Mark block as free
    ldr     x1, [x20]
    orr     x1, x1, #TLSF_BLOCK_FREE
    str     x1, [x20]
    
    // Coalesce with adjacent free blocks
    mov     x0, x20
    bl      .coalesce_block
    mov     x20, x0                     // Update block pointer after coalescing
    
    // Insert into free list
    mov     x0, x20
    bl      .insert_free_block
    
    // Update statistics
    ldr     x1, [x20]
    and     x1, x1, #TLSF_BLOCK_SIZE_MASK
    
    adrp    x2, stats_total_frees
    add     x2, x2, :lo12:stats_total_frees
    ATOMIC_INC x2, x3
    
    adrp    x2, stats_current_usage
    add     x2, x2, :lo12:stats_current_usage
1:  ldxr    x3, [x2]
    sub     x4, x3, x1
    stxr    w5, x4, [x2]
    cbnz    w5, 1b
    
    // Release lock
    adrp    x1, allocator_lock
    add     x1, x1, :lo12:allocator_lock
    stlr    xzr, [x1]
    
    mov     x0, #MEM_SUCCESS
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.free_error_null:
    mov     x0, #MEM_ERROR_NULL_PTR
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.free_error_double_free:
    mov     x0, #MEM_ERROR_DOUBLE_FREE
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ============================================================================
// TLSF REALLOCATION
// ============================================================================

// tlsf_realloc: Reallocate memory block
// Arguments:
//   x0 = pointer to existing block (can be NULL)
//   x1 = new size
// Returns:
//   x0 = pointer to reallocated memory
//   x1 = error code
tlsf_realloc:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save old pointer
    mov     x20, x1                     // Save new size
    
    // If old pointer is NULL, this is just malloc
    cbz     x19, .realloc_malloc
    
    // If new size is 0, this is just free
    cbz     x20, .realloc_free
    
    // Get current block size
    sub     x0, x19, #TLSF_BLOCK_HEADER_SIZE
    ldr     x1, [x0]
    and     x1, x1, #TLSF_BLOCK_SIZE_MASK
    
    // If new size fits in current block, return as-is
    cmp     x20, x1
    b.le    .realloc_fits
    
    // Allocate new block
    mov     x0, x20
    bl      tlsf_alloc
    cbz     x0, .realloc_failed
    
    // Copy old data to new block
    mov     x2, x0                      // Save new pointer
    mov     x1, x19                     // Source
    mov     x0, x2                      // Destination
    
    // Determine copy size (minimum of old and new sizes)
    sub     x3, x19, #TLSF_BLOCK_HEADER_SIZE
    ldr     x3, [x3]
    and     x3, x3, #TLSF_BLOCK_SIZE_MASK
    cmp     x20, x3
    csel    x3, x20, x3, lo
    
    // Copy data
    bl      .memcpy_fast
    
    // Free old block
    mov     x0, x19
    bl      tlsf_free
    
    mov     x0, x2                      // Return new pointer
    mov     x1, #MEM_SUCCESS
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.realloc_malloc:
    mov     x0, x20
    bl      tlsf_alloc
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.realloc_free:
    mov     x0, x19
    bl      tlsf_free
    mov     x0, xzr
    mov     x1, #MEM_SUCCESS
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.realloc_fits:
    mov     x0, x19
    mov     x1, #MEM_SUCCESS
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.realloc_failed:
    mov     x1, #MEM_ERROR_OUT_OF_MEMORY
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ============================================================================
// INTERNAL HELPER FUNCTIONS
// ============================================================================

// Find suitable free block for allocation
// Arguments: x20 = fli, x21 = sli
// Returns: x0 = block pointer (or NULL if not found)
.find_suitable_block:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, tlsf_control_block
    add     x0, x0, :lo12:tlsf_control_block
    
    // Check if exact size class has free blocks
    add     x1, x0, #8                  // sl_bitmap array
    ldr     x2, [x1, x20, lsl #3]       // sl_bitmap[fli]
    mov     x3, #1
    lsl     x3, x3, x21
    tst     x2, x3
    b.ne    .found_block
    
    // Look for larger blocks in same first level
    neg     x3, x3
    and     x2, x2, x3                  // Mask off smaller sizes
    cbnz    x2, .found_larger_sl
    
    // Look in higher first levels
    ldr     x2, [x0]                    // fl_bitmap
    add     x3, x20, #1
    mov     x4, #1
    lsl     x4, x4, x3
    neg     x4, x4
    and     x2, x2, x4
    cbz     x2, .no_block_found
    
    // Find first set bit in fl_bitmap
    BITMAP_FFS x2, x20
    
    // Find first set bit in sl_bitmap[fli]
    ldr     x2, [x1, x20, lsl #3]
    BITMAP_FFS x2, x21

.found_larger_sl:
    BITMAP_FFS x2, x21

.found_block:
    // Calculate block array index
    lsl     x2, x20, #5                 // fli * 32
    add     x2, x2, x21                 // + sli
    
    // Get block pointer
    add     x3, x0, #8 + (TLSF_FL_INDEX_COUNT * 8)  // blocks array
    ldr     x0, [x3, x2, lsl #3]
    
    ldp     x29, x30, [sp], #16
    ret

.no_block_found:
    mov     x0, xzr
    ldp     x29, x30, [sp], #16
    ret

// Insert free block into appropriate list
// Arguments: x0 = block pointer
.insert_free_block:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save block pointer
    
    // Get block size
    ldr     x1, [x19]
    and     x1, x1, #TLSF_BLOCK_SIZE_MASK
    
    // Map to indices
    TLSF_MAPPING x1, x2, x3             // x2 = fli, x3 = sli
    
    // Get control block
    adrp    x0, tlsf_control_block
    add     x0, x0, :lo12:tlsf_control_block
    
    // Set bits in bitmaps
    ldr     x4, [x0]                    // fl_bitmap
    BITMAP_SET x4, x2
    str     x4, [x0]
    
    add     x5, x0, #8                  // sl_bitmap array
    ldr     x4, [x5, x2, lsl #3]
    BITMAP_SET x4, x3
    str     x4, [x5, x2, lsl #3]
    
    // Insert at head of list
    lsl     x4, x2, #5                  // fli * 32
    add     x4, x4, x3                  // + sli
    add     x5, x0, #8 + (TLSF_FL_INDEX_COUNT * 8)  // blocks array
    ldr     x6, [x5, x4, lsl #3]        // Current head
    
    str     x19, [x5, x4, lsl #3]       // Set new head
    str     xzr, [x19, #24]             // prev_free = NULL
    str     x6, [x19, #16]              // next_free = old head
    
    cbz     x6, 1f
    str     x19, [x6, #24]              // old head->prev_free = new block
1:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// Remove free block from list
// Arguments: x0 = block pointer
.remove_free_block:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save block pointer
    
    // Get next and previous pointers
    ldr     x1, [x19, #16]              // next_free
    ldr     x2, [x19, #24]              // prev_free
    
    // Update links
    cbz     x2, .remove_head
    str     x1, [x2, #16]               // prev->next = next
    b       .check_next
    
.remove_head:
    // This is the head of the list, update list head
    ldr     x3, [x19]
    and     x3, x3, #TLSF_BLOCK_SIZE_MASK
    TLSF_MAPPING x3, x4, x5             // x4 = fli, x5 = sli
    
    adrp    x6, tlsf_control_block
    add     x6, x6, :lo12:tlsf_control_block
    lsl     x7, x4, #5
    add     x7, x7, x5
    add     x8, x6, #8 + (TLSF_FL_INDEX_COUNT * 8)
    str     x1, [x8, x7, lsl #3]
    
    // Clear bitmap bits if list becomes empty
    cbz     x1, .clear_bitmaps

.check_next:
    cbz     x1, .done_remove
    str     x2, [x1, #24]               // next->prev = prev

.done_remove:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.clear_bitmaps:
    // Clear sl_bitmap bit
    add     x8, x6, #8                  // sl_bitmap array
    ldr     x9, [x8, x4, lsl #3]
    BITMAP_CLEAR x9, x5
    str     x9, [x8, x4, lsl #3]
    
    // If sl_bitmap becomes zero, clear fl_bitmap bit
    cbnz    x9, .check_next
    ldr     x9, [x6]                    // fl_bitmap
    BITMAP_CLEAR x9, x4
    str     x9, [x6]
    b       .check_next

// Split block if it's larger than needed
// Arguments: x0 = block pointer, x1 = required size
.split_block:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    ldr     x2, [x0]                    // Current block size + flags
    and     x3, x2, #TLSF_BLOCK_SIZE_MASK  // Just the size
    
    // Calculate remaining size after split
    add     x4, x1, #TLSF_BLOCK_HEADER_SIZE  // Required size + header
    sub     x5, x3, x4                  // Remaining size
    
    // Only split if remaining size is large enough for a block
    cmp     x5, #TLSF_MIN_ALLOC + TLSF_BLOCK_HEADER_SIZE
    b.lt    .no_split
    
    // Update current block size
    bic     x2, x2, #TLSF_BLOCK_SIZE_MASK
    orr     x2, x2, x1
    str     x2, [x0]
    
    // Create new free block
    add     x6, x0, x4                  // New block address
    orr     x5, x5, #TLSF_BLOCK_FREE    // Mark as free
    str     x5, [x6]                    // Store size + flags
    str     x0, [x6, #8]                // prev_phys_block
    
    // Insert new block into free list
    stp     x0, x1, [sp, #-16]!
    mov     x0, x6
    bl      .insert_free_block
    ldp     x0, x1, [sp], #16

.no_split:
    ldp     x29, x30, [sp], #16
    ret

// Coalesce block with adjacent free blocks
// Arguments: x0 = block pointer
// Returns: x0 = coalesced block pointer
.coalesce_block:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     x1, x0                      // Current block
    
    // Try to coalesce with previous block
    ldr     x2, [x1]                    // Current block header
    tst     x2, #TLSF_BLOCK_PREV_FREE
    b.eq    .check_next_block
    
    ldr     x3, [x1, #8]                // prev_phys_block
    
    // Remove previous block from free list
    stp     x0, x1, [sp, #-16]!
    mov     x0, x3
    bl      .remove_free_block
    ldp     x0, x1, [sp], #16
    
    // Merge blocks
    ldr     x4, [x3]                    // Previous block size
    and     x4, x4, #TLSF_BLOCK_SIZE_MASK
    ldr     x5, [x1]                    // Current block size
    and     x5, x5, #TLSF_BLOCK_SIZE_MASK
    add     x4, x4, x5                  // Combined size
    
    orr     x4, x4, #TLSF_BLOCK_FREE
    str     x4, [x3]                    // Update size
    mov     x1, x3                      // Use previous block as current

.check_next_block:
    // Try to coalesce with next block
    ldr     x2, [x1]
    and     x2, x2, #TLSF_BLOCK_SIZE_MASK
    add     x3, x1, x2                  // Next block address
    
    // Check if next block is free
    ldr     x4, [x3]
    tst     x4, #TLSF_BLOCK_FREE
    b.eq    .coalesce_done
    
    // Remove next block from free list
    stp     x0, x1, [sp, #-16]!
    mov     x0, x3
    bl      .remove_free_block
    ldp     x0, x1, [sp], #16
    
    // Merge blocks
    and     x4, x4, #TLSF_BLOCK_SIZE_MASK
    add     x2, x2, x4                  // Combined size
    orr     x2, x2, #TLSF_BLOCK_FREE
    str     x2, [x1]

.coalesce_done:
    mov     x0, x1                      // Return coalesced block
    ldp     x29, x30, [sp], #16
    ret

// Fast memory copy optimized for ARM64
// Arguments: x0 = dest, x1 = src, x2 = size
.memcpy_fast:
    cmp     x2, #64
    b.lt    .memcpy_small
    
    // Large copy with SIMD
    and     x3, x2, #~63               // Round down to 64-byte boundary
    add     x4, x1, x3                 // End of SIMD copy
    
.memcpy_simd_loop:
    ldp     q0, q1, [x1], #32
    ldp     q2, q3, [x1], #32
    stp     q0, q1, [x0], #32
    stp     q2, q3, [x0], #32
    cmp     x1, x4
    b.lt    .memcpy_simd_loop
    
    and     x2, x2, #63                // Remaining bytes
    
.memcpy_small:
    tbz     x2, #5, 1f
    ldp     x3, x4, [x1], #16
    ldp     x5, x6, [x1], #16
    stp     x3, x4, [x0], #16
    stp     x5, x6, [x0], #16
1:  tbz     x2, #4, 2f
    ldp     x3, x4, [x1], #16
    stp     x3, x4, [x0], #16
2:  tbz     x2, #3, 3f
    ldr     x3, [x1], #8
    str     x3, [x0], #8
3:  tbz     x2, #2, 4f
    ldr     w3, [x1], #4
    str     w3, [x0], #4
4:  tbz     x2, #1, 5f
    ldrh    w3, [x1], #2
    strh    w3, [x0], #2
5:  tbz     x2, #0, 6f
    ldrb    w3, [x1]
    strb    w3, [x0]
6:  ret