// debug.s - Memory Debug and Tracking System
// SimCity ARM64 Assembly Project - Agent 2: Memory Management
//
// Advanced memory debugging features including:
// - Allocation tracking and leak detection
// - Memory corruption detection with guard bytes
// - Detailed statistics and reporting
// - Stack trace capture for allocations

.text
.align 4

// Include our memory system definitions
.include "../include/constants/memory.inc"
.include "../include/types/memory.inc"
.include "../include/macros/memory.inc"

// ============================================================================
// GLOBAL SYMBOLS
// ============================================================================

.global mem_debug_init
.global mem_debug_stats
.global mem_debug_check
.global mem_debug_dump
.global mem_debug_track_alloc
.global mem_debug_track_free
.global mem_debug_validate_ptr

// External dependencies
.extern tlsf_alloc
.extern tlsf_free

// ============================================================================
// DATA SECTION
// ============================================================================

.data
.align 6                                // Cache-line aligned

// Debug system state
debug_initialized:      .quad   0       // Initialization flag
debug_enabled:          .quad   1       // Enable/disable debugging
debug_lock:             .quad   0       // Debug system lock

// Allocation tracking table (hash table for fast lookup)
.equ ALLOC_TABLE_SIZE, 4096             // Must be power of 2
alloc_table:            .fill   ALLOC_TABLE_SIZE, 8, 0  // Hash table entries

// Free allocation entry pool
alloc_entry_pool:       .quad   0       // Pool of pre-allocated entries
alloc_entry_free_list:  .quad   0       // Free list head

// Debug statistics
debug_stats:
    total_allocs:           .quad   0   // Total allocations tracked
    total_frees:            .quad   0   // Total frees tracked
    current_allocs:         .quad   0   // Currently allocated blocks
    bytes_allocated:        .quad   0   // Total bytes allocated
    bytes_freed:            .quad   0   // Total bytes freed
    peak_allocs:            .quad   0   // Peak number of allocations
    peak_bytes:             .quad   0   // Peak bytes allocated
    leak_count:             .quad   0   // Number of leaks detected
    corruption_count:       .quad   0   // Number of corruptions detected
    double_free_count:      .quad   0   // Number of double frees

// Error reporting buffer
error_buffer:           .fill   1024, 1, 0

// ============================================================================
// DEBUG SYSTEM INITIALIZATION
// ============================================================================

// mem_debug_init: Initialize the memory debug system
// Returns:
//   x0 = error code (0 = success)
mem_debug_init:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Check if already initialized
    adrp    x0, debug_initialized
    add     x0, x0, :lo12:debug_initialized
    ldr     x1, [x0]
    cbnz    x1, .debug_init_already
    
    // Acquire debug lock
    adrp    x19, debug_lock
    add     x19, x19, :lo12:debug_lock
.debug_init_lock:
    ldaxr   x1, [x19]
    cbnz    x1, .debug_init_lock
    mov     x1, #1
    stlxr   w2, x1, [x19]
    cbnz    w2, .debug_init_lock
    
    // Allocate pool for allocation entries
    mov     x0, #DEBUG_MAX_ALLOCS
    mov     x1, #alloc_entry.struct_end
    mul     x0, x0, x1                  // Total size needed
    bl      tlsf_alloc
    cbz     x0, .debug_init_oom
    
    // Store pool address
    adrp    x1, alloc_entry_pool
    add     x1, x1, :lo12:alloc_entry_pool
    str     x0, [x1]
    
    // Initialize free list
    mov     x20, x0                     // Pool start
    mov     x1, #DEBUG_MAX_ALLOCS
    mov     x2, #alloc_entry.struct_end
    
.debug_init_free_list:
    cbz     x1, .debug_init_free_list_done
    add     x3, x20, x2                 // Next entry
    cmp     x1, #1
    csel    x3, xzr, x3, eq             // Last entry points to NULL
    str     x3, [x20]                   // Store next pointer
    mov     x20, x3
    sub     x1, x1, #1
    b       .debug_init_free_list

.debug_init_free_list_done:
    // Set free list head
    adrp    x1, alloc_entry_free_list
    add     x1, x1, :lo12:alloc_entry_free_list
    adrp    x2, alloc_entry_pool
    add     x2, x2, :lo12:alloc_entry_pool
    ldr     x2, [x2]
    str     x2, [x1]
    
    // Clear allocation table
    adrp    x0, alloc_table
    add     x0, x0, :lo12:alloc_table
    mov     x1, #ALLOC_TABLE_SIZE
.debug_clear_table:
    str     xzr, [x0], #8
    subs    x1, x1, #1
    b.ne    .debug_clear_table
    
    // Clear statistics
    adrp    x0, debug_stats
    add     x0, x0, :lo12:debug_stats
    mov     x1, #10                     // Number of stat fields
.debug_clear_stats:
    str     xzr, [x0], #8
    subs    x1, x1, #1
    b.ne    .debug_clear_stats
    
    // Mark as initialized
    adrp    x0, debug_initialized
    add     x0, x0, :lo12:debug_initialized
    mov     x1, #1
    str     x1, [x0]
    
    MEMORY_BARRIER_FULL
    
    // Release lock
    stlr    xzr, [x19]
    
    mov     x0, #MEM_SUCCESS
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.debug_init_already:
    mov     x0, #MEM_SUCCESS
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.debug_init_oom:
    stlr    xzr, [x19]                  // Release lock
    mov     x0, #MEM_ERROR_OUT_OF_MEMORY
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ============================================================================
// ALLOCATION TRACKING
// ============================================================================

// mem_debug_track_alloc: Track a memory allocation
// Arguments:
//   x0 = pointer to allocated memory
//   x1 = size of allocation
//   x2 = source file (optional, can be NULL)
//   x3 = source line (optional, can be 0)
// Returns:
//   x0 = error code
mem_debug_track_alloc:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // Save pointer
    mov     x20, x1                     // Save size
    mov     x21, x2                     // Save file
    mov     x22, x3                     // Save line
    
    // Check if debug system is enabled
    adrp    x0, debug_enabled
    add     x0, x0, :lo12:debug_enabled
    ldr     x0, [x0]
    cbz     x0, .debug_track_disabled
    
    // Acquire debug lock
    adrp    x0, debug_lock
    add     x0, x0, :lo12:debug_lock
.debug_track_lock:
    ldaxr   x1, [x0]
    cbnz    x1, .debug_track_lock
    mov     x1, #1
    stlxr   w2, x1, [x0]
    cbnz    w2, .debug_track_lock
    
    // Get free allocation entry
    adrp    x0, alloc_entry_free_list
    add     x0, x0, :lo12:alloc_entry_free_list
    ldr     x1, [x0]
    cbz     x1, .debug_track_no_entries
    
    // Remove from free list
    ldr     x2, [x1]                    // Next entry
    str     x2, [x0]                    // Update free list head
    
    // Fill allocation entry
    str     x19, [x1, #alloc_entry.ptr]
    str     x20, [x1, #alloc_entry.size]
    
    // Get current timestamp
    mrs     x0, cntvct_el0
    str     x0, [x1, #alloc_entry.timestamp]
    
    str     x21, [x1, #alloc_entry.file]
    str     x22, [x1, #alloc_entry.line]
    
    // Get thread ID (simplified)
    mrs     x0, tpidr_el0
    str     x0, [x1, #alloc_entry.thread_id]
    
    // Capture stack backtrace (simplified version)
    mov     x0, x29                     // Frame pointer
    add     x2, x1, #alloc_entry.backtrace
    mov     x3, #DEBUG_BACKTRACE_DEPTH
.debug_capture_backtrace:
    cbz     x3, .debug_backtrace_done
    cbz     x0, .debug_backtrace_done
    ldr     x4, [x0, #8]                // Return address
    str     x4, [x2], #8
    ldr     x0, [x0]                    // Previous frame
    sub     x3, x3, #1
    b       .debug_capture_backtrace

.debug_backtrace_done:
    // Insert into hash table
    mov     x0, x19                     // Pointer
    bl      .debug_hash_pointer
    mov     x2, x0                      // Hash index
    
    adrp    x0, alloc_table
    add     x0, x0, :lo12:alloc_table
    ldr     x3, [x0, x2, lsl #3]        // Current head
    str     x3, [x1]                    // entry->next = old head
    str     x1, [x0, x2, lsl #3]        // table[hash] = entry
    
    // Update statistics
    adrp    x0, debug_stats
    add     x0, x0, :lo12:debug_stats
    
    ATOMIC_INC x0, x2                   // total_allocs
    ATOMIC_INC x0 + 16, x2              // current_allocs
    
1:  ldxr    x2, [x0 + 24]               // bytes_allocated
    add     x3, x2, x20
    stxr    w4, x3, [x0 + 24]
    cbnz    w4, 1b
    
    // Update peak statistics
    ldr     x2, [x0 + 16]               // current_allocs
    ldr     x4, [x0 + 40]               // peak_allocs
    cmp     x2, x4
    b.le    2f
    str     x2, [x0 + 40]
2:
    
    ldr     x2, [x0 + 24]               // bytes_allocated
    ldr     x4, [x0 + 48]               // peak_bytes
    cmp     x2, x4
    b.le    3f
    str     x2, [x0 + 48]
3:
    
    // Release lock
    adrp    x0, debug_lock
    add     x0, x0, :lo12:debug_lock
    stlr    xzr, [x0]
    
    mov     x0, #MEM_SUCCESS
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.debug_track_disabled:
    mov     x0, #MEM_SUCCESS
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.debug_track_no_entries:
    // Release lock
    adrp    x0, debug_lock
    add     x0, x0, :lo12:debug_lock
    stlr    xzr, [x0]
    
    mov     x0, #MEM_ERROR_OUT_OF_MEMORY
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ============================================================================
// DEALLOCATION TRACKING
// ============================================================================

// mem_debug_track_free: Track a memory deallocation
// Arguments:
//   x0 = pointer being freed
// Returns:
//   x0 = error code
mem_debug_track_free:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save pointer
    
    // Check if debug system is enabled
    adrp    x0, debug_enabled
    add     x0, x0, :lo12:debug_enabled
    ldr     x0, [x0]
    cbz     x0, .debug_free_disabled
    
    // Acquire lock
    adrp    x0, debug_lock
    add     x0, x0, :lo12:debug_lock
.debug_free_lock:
    ldaxr   x1, [x0]
    cbnz    x1, .debug_free_lock
    mov     x1, #1
    stlxr   w2, x1, [x0]
    cbnz    w2, .debug_free_lock
    
    // Find allocation entry
    mov     x0, x19
    bl      .debug_find_alloc_entry
    cbz     x0, .debug_free_not_found
    mov     x20, x0                     // Save entry pointer
    
    // Remove from hash table
    mov     x0, x19
    bl      .debug_remove_alloc_entry
    
    // Update statistics
    adrp    x0, debug_stats
    add     x0, x0, :lo12:debug_stats
    
    ATOMIC_INC x0 + 8, x1               // total_frees
    
    ldr     x1, [x0 + 16]               // current_allocs
    sub     x1, x1, #1
    str     x1, [x0 + 16]
    
    ldr     x1, [x20, #alloc_entry.size]
2:  ldxr    x2, [x0 + 32]               // bytes_freed
    add     x3, x2, x1
    stxr    w4, x3, [x0 + 32]
    cbnz    w4, 2b
    
    // Return entry to free list
    adrp    x0, alloc_entry_free_list
    add     x0, x0, :lo12:alloc_entry_free_list
    ldr     x1, [x0]
    str     x1, [x20]                   // entry->next = old head
    str     x20, [x0]                   // free_list = entry
    
    // Release lock
    adrp    x0, debug_lock
    add     x0, x0, :lo12:debug_lock
    stlr    xzr, [x0]
    
    mov     x0, #MEM_SUCCESS
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.debug_free_disabled:
    mov     x0, #MEM_SUCCESS
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.debug_free_not_found:
    // This is a double-free or invalid pointer
    adrp    x0, debug_stats
    add     x0, x0, :lo12:debug_stats
    ATOMIC_INC x0 + 72, x1              // double_free_count
    
    // Release lock
    adrp    x0, debug_lock
    add     x0, x0, :lo12:debug_lock
    stlr    xzr, [x0]
    
    mov     x0, #MEM_ERROR_DOUBLE_FREE
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ============================================================================
// MEMORY VALIDATION AND CHECKING
// ============================================================================

// mem_debug_check: Perform comprehensive memory check
// Returns:
//   x0 = error code (0 = no issues found)
mem_debug_check:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, #0                     // Error count
    
    // Check if debug system is enabled
    adrp    x0, debug_enabled
    add     x0, x0, :lo12:debug_enabled
    ldr     x0, [x0]
    cbz     x0, .debug_check_disabled
    
    // Acquire lock
    adrp    x0, debug_lock
    add     x0, x0, :lo12:debug_lock
.debug_check_lock:
    ldaxr   x1, [x0]
    cbnz    x1, .debug_check_lock
    mov     x1, #1
    stlxr   w2, x1, [x0]
    cbnz    w2, .debug_check_lock
    
    // Walk through all allocation entries and validate them
    adrp    x20, alloc_table
    add     x20, x20, :lo12:alloc_table
    mov     x0, #ALLOC_TABLE_SIZE

.debug_check_table_loop:
    cbz     x0, .debug_check_done
    ldr     x1, [x20], #8               // Get table entry
    bl      .debug_check_chain          // Check this chain
    add     x19, x19, x0                // Add error count
    sub     x0, x0, #1
    b       .debug_check_table_loop

.debug_check_done:
    // Release lock
    adrp    x0, debug_lock
    add     x0, x0, :lo12:debug_lock
    stlr    xzr, [x0]
    
    // Return total error count
    mov     x0, x19
    cmp     x0, #0
    csel    x0, #MEM_ERROR_CORRUPTION, #MEM_SUCCESS, ne
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.debug_check_disabled:
    mov     x0, #MEM_SUCCESS
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ============================================================================
// STATISTICS AND REPORTING
// ============================================================================

// mem_debug_stats: Get debug statistics
// Arguments:
//   x0 = pointer to memory_stats structure
// Returns:
//   x0 = error code
mem_debug_stats:
    CHECK_NULL x0, .debug_stats_error
    
    adrp    x1, debug_stats
    add     x1, x1, :lo12:debug_stats
    
    // Copy statistics (10 quad words)
    ldp     x2, x3, [x1]
    stp     x2, x3, [x0]
    ldp     x2, x3, [x1, #16]
    stp     x2, x3, [x0, #16]
    ldp     x2, x3, [x1, #32]
    stp     x2, x3, [x0, #32]
    ldp     x2, x3, [x1, #48]
    stp     x2, x3, [x0, #48]
    ldp     x2, x3, [x1, #64]
    stp     x2, x3, [x0, #64]
    
    mov     x0, #MEM_SUCCESS
    ret

.debug_stats_error:
    mov     x0, #MEM_ERROR_NULL_PTR
    ret

// mem_debug_dump: Dump debug information to file descriptor
// Arguments:
//   x0 = file descriptor
// Returns:
//   x0 = error code
mem_debug_dump:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save file descriptor
    
    // Write header
    adrp    x1, .debug_dump_header
    add     x1, x1, :lo12:.debug_dump_header
    mov     x2, #(.debug_dump_header_end - .debug_dump_header)
    mov     x8, #64                     // sys_write
    svc     #0
    
    // Write statistics
    bl      .debug_dump_statistics
    
    // Write allocation list
    bl      .debug_dump_allocations
    
    mov     x0, #MEM_SUCCESS
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ============================================================================
// INTERNAL HELPER FUNCTIONS
// ============================================================================

// Hash a pointer for table lookup
.debug_hash_pointer:
    // Arguments: x0 = pointer
    // Returns: x0 = hash index
    lsr     x1, x0, #3                  // Remove low bits (alignment)
    mov     x2, #0x9e3779b9             // Golden ratio hash constant
    mul     x0, x1, x2
    and     x0, x0, #(ALLOC_TABLE_SIZE - 1)
    ret

// Find allocation entry for pointer
.debug_find_alloc_entry:
    // Arguments: x0 = pointer
    // Returns: x0 = entry pointer (NULL if not found)
    mov     x1, x0                      // Save pointer
    bl      .debug_hash_pointer
    
    adrp    x2, alloc_table
    add     x2, x2, :lo12:alloc_table
    ldr     x0, [x2, x0, lsl #3]        // Get chain head

.debug_find_loop:
    cbz     x0, .debug_find_not_found
    ldr     x2, [x0, #alloc_entry.ptr]
    cmp     x2, x1
    b.eq    .debug_find_found
    ldr     x0, [x0]                    // Next entry
    b       .debug_find_loop

.debug_find_found:
    ret

.debug_find_not_found:
    mov     x0, xzr
    ret

// Remove allocation entry from hash table
.debug_remove_alloc_entry:
    // Arguments: x0 = pointer
    // This is a simplified version - production code would need proper removal
    ret

// Check a chain of allocation entries
.debug_check_chain:
    // Arguments: x1 = chain head
    // Returns: x0 = number of errors found
    mov     x0, #0                      // Error count
    
.debug_check_chain_loop:
    cbz     x1, .debug_check_chain_done
    
    // Validate this entry
    ldr     x2, [x1, #alloc_entry.ptr]
    cbz     x2, .debug_check_chain_error
    
    // Add additional validation here...
    
    ldr     x1, [x1]                    // Next entry
    b       .debug_check_chain_loop

.debug_check_chain_error:
    add     x0, x0, #1
    ldr     x1, [x1]
    b       .debug_check_chain_loop

.debug_check_chain_done:
    ret

// Dump statistics to file
.debug_dump_statistics:
    // Implementation would format and write statistics
    ret

// Dump allocation list to file
.debug_dump_allocations:
    // Implementation would walk allocation table and dump entries
    ret

// ============================================================================
// CONSTANT DATA
// ============================================================================

.section .rodata
.debug_dump_header:
    .ascii "=== SimCity Memory Debug Report ===\n"
    .ascii "Generated at runtime\n\n"
.debug_dump_header_end: