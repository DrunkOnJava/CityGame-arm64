/*
 * SimCity ARM64 - HMR Module Memory Management
 * ARM64-optimized memory allocation for hot-swappable modules
 * 
 * Created by Agent 1: Core Module System
 * Provides shared memory pools, NEON-aligned allocation, and leak detection
 */

.section __TEXT,__text,regular,pure_instructions
.align 4

// Include memory management constants
.include "../../include/constants/memory.inc"
.include "../../include/macros/memory.inc"

// External memory functions
.extern _malloc
.extern _free
.extern _mmap
.extern _munmap
.extern _mprotect
.extern _pthread_mutex_lock
.extern _pthread_mutex_unlock

// Memory pool constants
.set POOL_HEADER_SIZE,          64      // Pool metadata size
.set BLOCK_HEADER_SIZE,         32      // Block metadata size
.set MIN_BLOCK_SIZE,            64      // Minimum allocation size
.set MAX_BLOCK_SIZE,            (16 * 1024 * 1024)  // 16MB max
.set ALIGNMENT_NEON,            16      // NEON vector alignment
.set ALIGNMENT_CACHE,           64      // Cache line alignment
.set ALIGNMENT_PAGE,            4096    // Page alignment

// Pool header offsets
.set POOL_MAGIC_OFFSET,         0
.set POOL_SIZE_OFFSET,          8
.set POOL_USED_OFFSET,          16
.set POOL_FREE_OFFSET,          24
.set POOL_MUTEX_OFFSET,         32
.set POOL_FREE_LIST_OFFSET,     56

// Block header offsets
.set BLOCK_MAGIC_OFFSET,        0
.set BLOCK_SIZE_OFFSET,         8
.set BLOCK_NEXT_OFFSET,         16
.set BLOCK_PREV_OFFSET,         24

// Magic numbers for corruption detection
.set POOL_MAGIC,                0x484D52504F4F4C00  // "HMRPOOL\0"
.set BLOCK_MAGIC,               0x484D52424C4B00    // "HMRBLK\0"
.set FREE_MAGIC,                0x484D52465245      // "HMRFREE"

.section __DATA,__data
.align 8

// Global shared memory pool
shared_memory_pool:
    .space 64                   // Pool header

// Module-specific pools (256 max modules)
module_pools:
    .space (256 * 8)           // Array of pool pointers

// Memory leak tracking
leak_tracker:
    .quad 0                    // total_allocated
    .quad 0                    // total_freed
    .quad 0                    // peak_usage
    .quad 0                    // current_usage
    .quad 0                    // allocation_count
    .quad 0                    // free_count
    .quad 0                    // leak_count

.section __TEXT,__text,regular,pure_instructions

/*
 * hmr_init_shared_pool - Initialize shared memory pool for modules
 * Input: x0 = pool size in bytes
 * Output: w0 = result code (0 = success)
 */
.global _hmr_init_shared_pool
.align 4
_hmr_init_shared_pool:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0             // x19 = requested size
    
    // Align size to page boundary
    add     x19, x19, #4095
    and     x19, x19, #~4095
    
    // Allocate memory with mmap for better control
    mov     x0, #0              // addr = NULL (let system choose)
    mov     x1, x19             // length
    mov     x2, #0x3            // PROT_READ | PROT_WRITE
    mov     x3, #0x1002         // MAP_PRIVATE | MAP_ANONYMOUS
    mov     x4, #-1             // fd = -1 (anonymous)
    mov     x5, #0              // offset = 0
    mov     x8, #197            // SYS_mmap
    svc     #0
    
    // Check for mmap failure
    cmn     x0, #1
    b.eq    .Linit_pool_failed
    
    mov     x20, x0             // x20 = pool memory
    
    // Initialize pool header
    adrp    x1, shared_memory_pool@PAGE
    add     x1, x1, shared_memory_pool@PAGEOFF
    
    // Store magic number
    mov     x2, #POOL_MAGIC
    str     x2, [x1, #POOL_MAGIC_OFFSET]
    
    // Store size and usage
    str     x19, [x1, #POOL_SIZE_OFFSET]
    str     xzr, [x1, #POOL_USED_OFFSET]
    str     x19, [x1, #POOL_FREE_OFFSET]
    
    // Initialize mutex
    add     x0, x1, #POOL_MUTEX_OFFSET
    mov     x1, #0
    bl      _pthread_mutex_init
    
    // Initialize free list with single large block
    mov     x0, x20
    mov     x1, x19
    bl      _hmr_init_free_block
    
    // Store pool pointer in global
    adrp    x1, shared_memory_pool@PAGE
    add     x1, x1, shared_memory_pool@PAGEOFF
    str     x20, [x1, #POOL_FREE_LIST_OFFSET]
    
    mov     w0, #0              // Success
    b       .Linit_pool_return
    
.Linit_pool_failed:
    mov     w0, #-9             // HMR_ERROR_OUT_OF_MEMORY
    
.Linit_pool_return:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

/*
 * hmr_module_alloc - Allocate memory for a module with NEON alignment
 * Input: x0 = size, x1 = alignment, x2 = module_id
 * Output: x0 = allocated pointer (NULL on failure)
 */
.global _hmr_module_alloc
.align 4
_hmr_module_alloc:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0             // x19 = size
    mov     x20, x1             // x20 = alignment
    mov     x21, x2             // x21 = module_id
    
    // Validate parameters
    cbz     x19, .Lalloc_null_size
    cmp     x20, #8
    b.lt    .Lalloc_bad_align
    
    // Ensure minimum alignment for NEON operations
    cmp     x20, #ALIGNMENT_NEON
    csel    x20, x20, #ALIGNMENT_NEON, ge
    
    // Add space for block header and alignment padding
    add     x19, x19, #BLOCK_HEADER_SIZE
    add     x19, x19, x20
    
    // Lock shared pool
    adrp    x22, shared_memory_pool@PAGE
    add     x22, x22, shared_memory_pool@PAGEOFF
    add     x0, x22, #POOL_MUTEX_OFFSET
    bl      _pthread_mutex_lock
    
    // Find suitable free block
    ldr     x0, [x22, #POOL_FREE_LIST_OFFSET]
    mov     x1, x19             // required size
    mov     x2, x20             // alignment
    bl      _hmr_find_free_block
    mov     x21, x0             // x21 = found block
    
    cbz     x21, .Lalloc_no_space
    
    // Remove block from free list and split if necessary
    mov     x0, x21
    mov     x1, x19
    bl      _hmr_allocate_block
    
    // Update pool usage statistics
    ldr     x1, [x22, #POOL_USED_OFFSET]
    add     x1, x1, x19
    str     x1, [x22, #POOL_USED_OFFSET]
    
    ldr     x1, [x22, #POOL_FREE_OFFSET]
    sub     x1, x1, x19
    str     x1, [x22, #POOL_FREE_OFFSET]
    
    // Calculate aligned user pointer
    add     x0, x21, #BLOCK_HEADER_SIZE
    add     x0, x0, x20
    sub     x1, x0, #1
    bic     x0, x1, x20
    sub     x0, x0, #1
    
    // Update leak tracking
    bl      _hmr_track_allocation
    
    b       .Lalloc_unlock
    
.Lalloc_null_size:
.Lalloc_bad_align:
.Lalloc_no_space:
    mov     x0, #0              // Return NULL
    
.Lalloc_unlock:
    // Unlock shared pool
    push    x0                  // Save result
    add     x0, x22, #POOL_MUTEX_OFFSET
    bl      _pthread_mutex_unlock
    pop     x0                  // Restore result
    
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

/*
 * hmr_module_free - Free module memory with leak detection
 * Input: x0 = pointer to free
 * Output: w0 = result code
 */
.global _hmr_module_free
.align 4
_hmr_module_free:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0             // x19 = pointer
    cbz     x19, .Lfree_null_ptr
    
    // Find block header (scan backwards for header)
    mov     x0, x19
    bl      _hmr_find_block_header
    mov     x20, x0             // x20 = block header
    cbz     x20, .Lfree_bad_ptr
    
    // Validate block magic
    ldr     x1, [x20, #BLOCK_MAGIC_OFFSET]
    mov     x2, #BLOCK_MAGIC
    cmp     x1, x2
    b.ne    .Lfree_corrupted
    
    // Lock shared pool
    adrp    x1, shared_memory_pool@PAGE
    add     x1, x1, shared_memory_pool@PAGEOFF
    add     x0, x1, #POOL_MUTEX_OFFSET
    bl      _pthread_mutex_lock
    
    // Add block back to free list
    mov     x0, x20
    bl      _hmr_free_block
    
    // Update pool statistics
    adrp    x1, shared_memory_pool@PAGE
    add     x1, x1, shared_memory_pool@PAGEOFF
    ldr     x2, [x20, #BLOCK_SIZE_OFFSET]
    
    ldr     x3, [x1, #POOL_USED_OFFSET]
    sub     x3, x3, x2
    str     x3, [x1, #POOL_USED_OFFSET]
    
    ldr     x3, [x1, #POOL_FREE_OFFSET]
    add     x3, x3, x2
    str     x3, [x1, #POOL_FREE_OFFSET]
    
    // Update leak tracking
    mov     x0, x2              // block size
    bl      _hmr_track_free
    
    // Unlock shared pool
    adrp    x1, shared_memory_pool@PAGE
    add     x1, x1, shared_memory_pool@PAGEOFF
    add     x0, x1, #POOL_MUTEX_OFFSET
    bl      _pthread_mutex_unlock
    
    mov     w0, #0              // Success
    b       .Lfree_return
    
.Lfree_null_ptr:
    mov     w0, #-1             // HMR_ERROR_NULL_POINTER
    b       .Lfree_return
    
.Lfree_bad_ptr:
.Lfree_corrupted:
    mov     w0, #-2             // HMR_ERROR_INVALID_ARG
    
.Lfree_return:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

/*
 * hmr_init_free_block - Initialize a free block
 * Input: x0 = block pointer, x1 = size
 */
.align 4
_hmr_init_free_block:
    // Set magic number
    mov     x2, #BLOCK_MAGIC
    str     x2, [x0, #BLOCK_MAGIC_OFFSET]
    
    // Set size
    str     x1, [x0, #BLOCK_SIZE_OFFSET]
    
    // Clear next/prev pointers
    str     xzr, [x0, #BLOCK_NEXT_OFFSET]
    str     xzr, [x0, #BLOCK_PREV_OFFSET]
    
    ret

/*
 * hmr_find_free_block - Find suitable free block using first-fit algorithm
 * Input: x0 = free list head, x1 = required size, x2 = alignment
 * Output: x0 = block pointer (NULL if not found)
 */
.align 4
_hmr_find_free_block:
    mov     x3, x0              // x3 = current block
    
.Lfind_loop:
    cbz     x3, .Lfind_not_found
    
    // Check block size
    ldr     x4, [x3, #BLOCK_SIZE_OFFSET]
    cmp     x4, x1
    b.lt    .Lfind_next
    
    // Check alignment requirements
    add     x5, x3, #BLOCK_HEADER_SIZE
    add     x5, x5, x2
    sub     x6, x5, #1
    bic     x5, x6, x2
    sub     x5, x5, #1
    sub     x6, x5, x3
    sub     x6, x6, #BLOCK_HEADER_SIZE
    add     x6, x6, x1
    cmp     x6, x4
    b.gt    .Lfind_next
    
    // Found suitable block
    mov     x0, x3
    ret
    
.Lfind_next:
    ldr     x3, [x3, #BLOCK_NEXT_OFFSET]
    b       .Lfind_loop
    
.Lfind_not_found:
    mov     x0, #0
    ret

/*
 * hmr_track_allocation - Update allocation tracking statistics
 * Input: x0 = size allocated
 */
.align 4
_hmr_track_allocation:
    adrp    x1, leak_tracker@PAGE
    add     x1, x1, leak_tracker@PAGEOFF
    
    // Update total allocated
    ldr     x2, [x1, #0]
    add     x2, x2, x0
    str     x2, [x1, #0]
    
    // Update current usage
    ldr     x2, [x1, #24]
    add     x2, x2, x0
    str     x2, [x1, #24]
    
    // Update peak usage if necessary
    ldr     x3, [x1, #16]
    cmp     x2, x3
    csel    x3, x2, x3, gt
    str     x3, [x1, #16]
    
    // Increment allocation count
    ldr     x2, [x1, #32]
    add     x2, x2, #1
    str     x2, [x1, #32]
    
    ret

/*
 * hmr_track_free - Update free tracking statistics
 * Input: x0 = size freed
 */
.align 4
_hmr_track_free:
    adrp    x1, leak_tracker@PAGE
    add     x1, x1, leak_tracker@PAGEOFF
    
    // Update total freed
    ldr     x2, [x1, #8]
    add     x2, x2, x0
    str     x2, [x1, #8]
    
    // Update current usage
    ldr     x2, [x1, #24]
    sub     x2, x2, x0
    str     x2, [x1, #24]
    
    // Increment free count
    ldr     x2, [x1, #40]
    add     x2, x2, #1
    str     x2, [x1, #40]
    
    ret

/*
 * hmr_get_memory_stats - Get current memory usage statistics
 * Input: x0 = stats structure pointer
 */
.global _hmr_get_memory_stats
.align 4
_hmr_get_memory_stats:
    adrp    x1, leak_tracker@PAGE
    add     x1, x1, leak_tracker@PAGEOFF
    
    // Copy all statistics (6 * 8 bytes = 48 bytes)
    ldp     x2, x3, [x1, #0]     // total_allocated, total_freed
    stp     x2, x3, [x0, #0]
    
    ldp     x2, x3, [x1, #16]    // peak_usage, current_usage
    stp     x2, x3, [x0, #16]
    
    ldp     x2, x3, [x1, #32]    // allocation_count, free_count
    stp     x2, x3, [x0, #32]
    
    ret

/*
 * hmr_check_memory_leaks - Check for memory leaks
 * Output: x0 = number of leaks detected
 */
.global _hmr_check_memory_leaks
.align 4
_hmr_check_memory_leaks:
    adrp    x1, leak_tracker@PAGE
    add     x1, x1, leak_tracker@PAGEOFF
    
    // Get current usage (should be 0 if no leaks)
    ldr     x0, [x1, #24]       // current_usage
    
    // Update leak count
    str     x0, [x1, #48]       // leak_count
    
    ret