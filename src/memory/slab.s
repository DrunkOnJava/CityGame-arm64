// slab.s - Slab Allocator for Fixed-Size Objects  
// SimCity ARM64 Assembly Project - Agent 2: Memory Management
//
// High-performance slab allocator optimized for fixed-size object allocation
// Provides O(1) allocation/deallocation for agents, tiles, and buildings
// Uses bitmaps for free object tracking and maintains cache-aligned structures

.text
.align 4

// Include our memory system definitions
.include "../include/constants/memory.inc"
.include "../include/types/memory.inc"
.include "../include/macros/memory.inc"

// ============================================================================
// GLOBAL SYMBOLS
// ============================================================================

.global slab_create
.global slab_alloc
.global slab_free
.global slab_destroy
.global agent_alloc
.global agent_free
.global tile_alloc
.global tile_free
.global building_alloc
.global building_free

// External dependencies
.extern tlsf_alloc
.extern tlsf_free

// ============================================================================
// DATA SECTION
// ============================================================================

.data
.align 6                                // Cache-line aligned

// Specialized slab caches for SimCity objects
agent_cache:        .quad   0           // Agent slab cache
tile_cache:         .quad   0           // Tile slab cache
building_small_cache: .quad 0           // Small building cache
building_large_cache: .quad 0           // Large building cache

// Global slab statistics
slab_stats:
    total_slabs:        .quad   0       // Total number of slabs
    total_objects:      .quad   0       // Total objects allocated
    cache_hits:         .quad   0       // Cache hit count
    cache_misses:       .quad   0       // Cache miss count

// Slab allocator lock
slab_lock:          .quad   0

// ============================================================================
// SLAB CACHE MANAGEMENT
// ============================================================================

// slab_create: Create a new slab cache for objects of specified size
// Arguments:
//   x0 = object_size (size of each object in bytes)
//   x1 = objects_per_slab (number of objects per slab)
// Returns:
//   x0 = slab cache pointer (NULL on failure)
//   x1 = error code
slab_create:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // Save object size
    mov     x20, x1                     // Save objects per slab
    
    // Validate parameters
    CHECK_SIZE x19, .slab_create_error
    cbz     x20, .slab_create_error
    cmp     x20, #SLAB_MAX_OBJECTS
    b.gt    .slab_create_error
    
    // Align object size to 8-byte boundary
    add     x19, x19, #7
    and     x19, x19, #~7
    
    // Allocate memory for slab cache structure
    mov     x0, #slab_cache.struct_end
    bl      tlsf_alloc
    cbz     x0, .slab_create_oom
    mov     x21, x0                     // Save cache pointer
    
    // Initialize slab cache structure
    str     xzr, [x21, #slab_cache.name]
    str     x19, [x21, #slab_cache.object_size]
    str     x20, [x21, #slab_cache.objects_per_slab]
    str     xzr, [x21, #slab_cache.full_slabs]
    str     xzr, [x21, #slab_cache.partial_slabs]
    str     xzr, [x21, #slab_cache.empty_slabs]
    str     xzr, [x21, #slab_cache.total_slabs]
    
    MEMORY_BARRIER_FULL
    
    mov     x0, x21                     // Return cache pointer
    mov     x1, #MEM_SUCCESS
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.slab_create_error:
    mov     x0, xzr
    mov     x1, #MEM_ERROR_INVALID_SIZE
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.slab_create_oom:
    mov     x0, xzr
    mov     x1, #MEM_ERROR_OUT_OF_MEMORY
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ============================================================================
// SLAB ALLOCATION
// ============================================================================

// slab_alloc: Allocate an object from a slab cache
// Arguments:
//   x0 = slab cache pointer
// Returns:
//   x0 = object pointer (NULL on failure)
//   x1 = error code
slab_alloc:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // Save cache pointer
    
    CHECK_NULL x19, .slab_alloc_error
    
    // Acquire slab lock
    adrp    x0, slab_lock
    add     x0, x0, :lo12:slab_lock
.slab_alloc_lock:
    ldaxr   x1, [x0]
    cbnz    x1, .slab_alloc_lock
    mov     x1, #1
    stlxr   w2, x1, [x0]
    cbnz    w2, .slab_alloc_lock
    
    // Try to allocate from partial slabs first
    ldr     x20, [x19, #slab_cache.partial_slabs]
    cbnz    x20, .slab_alloc_from_partial
    
    // Try to get empty slab
    ldr     x20, [x19, #slab_cache.empty_slabs]
    cbnz    x20, .slab_use_empty
    
    // Need to create new slab
    mov     x0, x19
    bl      .slab_create_new
    cbz     x0, .slab_alloc_oom
    mov     x20, x0

.slab_use_empty:
    // Move empty slab to partial list
    ldr     x0, [x20, #slab_descriptor.next]
    str     x0, [x19, #slab_cache.empty_slabs]
    cbz     x0, 1f
    str     xzr, [x0, #slab_descriptor.prev]
1:
    ldr     x0, [x19, #slab_cache.partial_slabs]
    str     x0, [x20, #slab_descriptor.next]
    str     xzr, [x20, #slab_descriptor.prev]
    str     x20, [x19, #slab_cache.partial_slabs]
    cbz     x0, .slab_alloc_from_partial
    str     x20, [x0, #slab_descriptor.prev]

.slab_alloc_from_partial:
    // Find first free object in slab
    mov     x0, x20
    bl      .slab_find_free_object
    cbz     x0, .slab_alloc_error
    mov     x21, x0                     // Save object pointer
    
    // Mark object as allocated
    mov     x0, x20
    mov     x1, x21
    bl      .slab_mark_allocated
    
    // Update slab free count
    ldr     x0, [x20, #slab_descriptor.free_objects]
    sub     x0, x0, #1
    str     x0, [x20, #slab_descriptor.free_objects]
    
    // If slab is now full, move to full list
    cbz     x0, .slab_move_to_full
    
    // Update statistics
    adrp    x0, slab_stats
    add     x0, x0, :lo12:slab_stats
    ATOMIC_INC x0 + 8, x1               // total_objects
    ATOMIC_INC x0 + 16, x1              // cache_hits
    
    // Release lock
    adrp    x0, slab_lock
    add     x0, x0, :lo12:slab_lock
    stlr    xzr, [x0]
    
    mov     x0, x21                     // Return object pointer
    mov     x1, #MEM_SUCCESS
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.slab_move_to_full:
    // Remove from partial list
    ldr     x0, [x20, #slab_descriptor.next]
    ldr     x1, [x20, #slab_descriptor.prev]
    
    cbz     x1, 1f
    str     x0, [x1, #slab_descriptor.next]
    b       2f
1:  str     x0, [x19, #slab_cache.partial_slabs]
2:  cbz     x0, 3f
    str     x1, [x0, #slab_descriptor.prev]
3:
    
    // Add to full list
    ldr     x0, [x19, #slab_cache.full_slabs]
    str     x0, [x20, #slab_descriptor.next]
    str     xzr, [x20, #slab_descriptor.prev]
    str     x20, [x19, #slab_cache.full_slabs]
    cbz     x0, 4f
    str     x20, [x0, #slab_descriptor.prev]
4:
    
    // Update statistics and release lock
    adrp    x0, slab_stats
    add     x0, x0, :lo12:slab_stats
    ATOMIC_INC x0 + 8, x1               // total_objects
    ATOMIC_INC x0 + 16, x1              // cache_hits
    
    adrp    x0, slab_lock
    add     x0, x0, :lo12:slab_lock
    stlr    xzr, [x0]
    
    mov     x0, x21
    mov     x1, #MEM_SUCCESS
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.slab_alloc_error:
    adrp    x0, slab_lock
    add     x0, x0, :lo12:slab_lock
    stlr    xzr, [x0]
    
    mov     x0, xzr
    mov     x1, #MEM_ERROR_INVALID_PTR
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.slab_alloc_oom:
    adrp    x0, slab_lock
    add     x0, x0, :lo12:slab_lock
    stlr    xzr, [x0]
    
    adrp    x0, slab_stats
    add     x0, x0, :lo12:slab_stats
    ATOMIC_INC x0 + 24, x1              // cache_misses
    
    mov     x0, xzr
    mov     x1, #MEM_ERROR_OUT_OF_MEMORY
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ============================================================================
// SLAB DEALLOCATION
// ============================================================================

// slab_free: Free an object back to its slab
// Arguments:
//   x0 = slab cache pointer
//   x1 = object pointer
// Returns:
//   x0 = error code
slab_free:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // Save cache pointer
    mov     x20, x1                     // Save object pointer
    
    CHECK_NULL x19, .slab_free_error
    CHECK_NULL x20, .slab_free_error
    
    // Find which slab this object belongs to
    mov     x0, x19
    mov     x1, x20
    bl      .slab_find_object_slab
    cbz     x0, .slab_free_error
    mov     x21, x0                     // Save slab pointer
    
    // Acquire lock
    adrp    x0, slab_lock
    add     x0, x0, :lo12:slab_lock
.slab_free_lock:
    ldaxr   x1, [x0]
    cbnz    x1, .slab_free_lock
    mov     x1, #1
    stlxr   w2, x1, [x0]
    cbnz    w2, .slab_free_lock
    
    // Check if object is already free (double-free detection)
    mov     x0, x21
    mov     x1, x20
    bl      .slab_is_object_free
    cbnz    x0, .slab_double_free
    
    // Mark object as free
    mov     x0, x21
    mov     x1, x20
    bl      .slab_mark_free
    
    // Update free count
    ldr     x0, [x21, #slab_descriptor.free_objects]
    add     x0, x0, #1
    str     x0, [x21, #slab_descriptor.free_objects]
    
    // Check if slab was full (move from full to partial)
    cmp     x0, #1
    b.ne    .slab_check_empty
    
    // Move from full to partial list
    bl      .slab_move_full_to_partial
    b       .slab_free_done

.slab_check_empty:
    // Check if slab is now empty
    ldr     x1, [x21, #slab_descriptor.total_objects]
    cmp     x0, x1
    b.ne    .slab_free_done
    
    // Move to empty list (or destroy if too many empty slabs)
    bl      .slab_move_to_empty

.slab_free_done:
    // Update statistics
    adrp    x0, slab_stats
    add     x0, x0, :lo12:slab_stats
    ldr     x1, [x0, #8]                // total_objects
    sub     x1, x1, #1
    str     x1, [x0, #8]
    
    // Release lock
    adrp    x0, slab_lock
    add     x0, x0, :lo12:slab_lock
    stlr    xzr, [x0]
    
    mov     x0, #MEM_SUCCESS
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.slab_free_error:
    mov     x0, #MEM_ERROR_INVALID_PTR
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.slab_double_free:
    adrp    x0, slab_lock
    add     x0, x0, :lo12:slab_lock
    stlr    xzr, [x0]
    
    mov     x0, #MEM_ERROR_DOUBLE_FREE
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ============================================================================
// SPECIALIZED ALLOCATORS FOR SIMCITY OBJECTS
// ============================================================================

// agent_alloc: Allocate an agent structure
// Returns: x0 = agent pointer, x1 = error code
agent_alloc:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get or create agent cache
    adrp    x0, agent_cache
    add     x0, x0, :lo12:agent_cache
    ldr     x1, [x0]
    cbnz    x1, .agent_alloc_from_cache
    
    // Create agent cache
    mov     x0, #SLAB_AGENT_SIZE
    mov     x1, #64                     // 64 agents per slab
    bl      slab_create
    cbz     x0, .agent_alloc_failed
    
    adrp    x1, agent_cache
    add     x1, x1, :lo12:agent_cache
    str     x0, [x1]
    mov     x1, x0

.agent_alloc_from_cache:
    mov     x0, x1
    bl      slab_alloc
    
    ldp     x29, x30, [sp], #16
    ret

.agent_alloc_failed:
    mov     x1, #MEM_ERROR_OUT_OF_MEMORY
    ldp     x29, x30, [sp], #16
    ret

// agent_free: Free an agent structure
// Arguments: x0 = agent pointer
// Returns: x0 = error code
agent_free:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x1, agent_cache
    add     x1, x1, :lo12:agent_cache
    ldr     x1, [x1]
    cbz     x1, .agent_free_error
    
    mov     x2, x0                      // Save object pointer
    mov     x0, x1                      // Cache pointer
    mov     x1, x2                      // Object pointer
    bl      slab_free
    
    ldp     x29, x30, [sp], #16
    ret

.agent_free_error:
    mov     x0, #MEM_ERROR_INVALID_PTR
    ldp     x29, x30, [sp], #16
    ret

// tile_alloc: Allocate a tile structure
// Returns: x0 = tile pointer, x1 = error code
tile_alloc:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, tile_cache
    add     x0, x0, :lo12:tile_cache
    ldr     x1, [x0]
    cbnz    x1, .tile_alloc_from_cache
    
    mov     x0, #SLAB_TILE_SIZE
    mov     x1, #128                    // 128 tiles per slab
    bl      slab_create
    cbz     x0, .tile_alloc_failed
    
    adrp    x1, tile_cache
    add     x1, x1, :lo12:tile_cache
    str     x0, [x1]
    mov     x1, x0

.tile_alloc_from_cache:
    mov     x0, x1
    bl      slab_alloc
    
    ldp     x29, x30, [sp], #16
    ret

.tile_alloc_failed:
    mov     x1, #MEM_ERROR_OUT_OF_MEMORY
    ldp     x29, x30, [sp], #16
    ret

// tile_free: Free a tile structure
// Arguments: x0 = tile pointer
// Returns: x0 = error code
tile_free:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x1, tile_cache
    add     x1, x1, :lo12:tile_cache
    ldr     x1, [x1]
    cbz     x1, .tile_free_error
    
    mov     x2, x0
    mov     x0, x1
    mov     x1, x2
    bl      slab_free
    
    ldp     x29, x30, [sp], #16
    ret

.tile_free_error:
    mov     x0, #MEM_ERROR_INVALID_PTR
    ldp     x29, x30, [sp], #16
    ret

// building_alloc: Allocate a building structure
// Arguments: x0 = building_type (0 = small, 1 = large)
// Returns: x0 = building pointer, x1 = error code
building_alloc:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    cmp     x0, #0
    b.eq    .building_alloc_small
    
    // Large building allocation
    adrp    x0, building_large_cache
    add     x0, x0, :lo12:building_large_cache
    ldr     x1, [x0]
    cbnz    x1, .building_large_from_cache
    
    mov     x0, #SLAB_BUILDING_LARGE_SIZE
    mov     x1, #16                     // 16 large buildings per slab
    bl      slab_create
    cbz     x0, .building_alloc_failed
    
    adrp    x1, building_large_cache
    add     x1, x1, :lo12:building_large_cache
    str     x0, [x1]
    mov     x1, x0

.building_large_from_cache:
    mov     x0, x1
    bl      slab_alloc
    ldp     x29, x30, [sp], #16
    ret

.building_alloc_small:
    adrp    x0, building_small_cache
    add     x0, x0, :lo12:building_small_cache
    ldr     x1, [x0]
    cbnz    x1, .building_small_from_cache
    
    mov     x0, #SLAB_BUILDING_SMALL_SIZE
    mov     x1, #32                     // 32 small buildings per slab
    bl      slab_create
    cbz     x0, .building_alloc_failed
    
    adrp    x1, building_small_cache
    add     x1, x1, :lo12:building_small_cache
    str     x0, [x1]
    mov     x1, x0

.building_small_from_cache:
    mov     x0, x1
    bl      slab_alloc
    ldp     x29, x30, [sp], #16
    ret

.building_alloc_failed:
    mov     x1, #MEM_ERROR_OUT_OF_MEMORY
    ldp     x29, x30, [sp], #16
    ret

// building_free: Free a building structure
// Arguments: x0 = building pointer
// Returns: x0 = error code
building_free:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save building pointer
    
    // Determine building size by checking which cache it belongs to
    adrp    x0, building_small_cache
    add     x0, x0, :lo12:building_small_cache
    ldr     x0, [x0]
    cbz     x0, .try_large_building
    
    mov     x1, x19
    bl      .slab_find_object_slab
    cbnz    x0, .free_small_building

.try_large_building:
    adrp    x0, building_large_cache
    add     x0, x0, :lo12:building_large_cache
    ldr     x0, [x0]
    cbz     x0, .building_free_error
    
    mov     x1, x19
    bl      .slab_find_object_slab
    cbz     x0, .building_free_error
    
    adrp    x0, building_large_cache
    add     x0, x0, :lo12:building_large_cache
    ldr     x0, [x0]
    mov     x1, x19
    bl      slab_free
    b       .building_free_done

.free_small_building:
    adrp    x0, building_small_cache
    add     x0, x0, :lo12:building_small_cache
    ldr     x0, [x0]
    mov     x1, x19
    bl      slab_free

.building_free_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.building_free_error:
    mov     x0, #MEM_ERROR_INVALID_PTR
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ============================================================================
// INTERNAL HELPER FUNCTIONS
// ============================================================================

// Create a new slab for the cache
// Arguments: x0 = cache pointer
// Returns: x0 = slab pointer (NULL on failure)
.slab_create_new:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save cache pointer
    
    // Calculate slab size
    ldr     x1, [x19, #slab_cache.object_size]      // Object size
    ldr     x2, [x19, #slab_cache.objects_per_slab] // Objects per slab
    mul     x3, x1, x2                              // Total object space
    add     x3, x3, #slab_descriptor.struct_end     // Add header
    add     x3, x3, #SLAB_BITMAP_SIZE               // Add bitmap
    
    // Align to cache line
    CACHE_ALIGN x3
    
    // Allocate slab memory
    mov     x0, x3
    bl      tlsf_alloc
    cbz     x0, .slab_create_new_failed
    mov     x20, x0                     // Save slab pointer
    
    // Initialize slab descriptor
    str     xzr, [x20, #slab_descriptor.next]
    str     xzr, [x20, #slab_descriptor.prev]
    ldr     x1, [x19, #slab_cache.objects_per_slab]
    str     x1, [x20, #slab_descriptor.free_objects]
    str     x1, [x20, #slab_descriptor.total_objects]
    ldr     x1, [x19, #slab_cache.object_size]
    str     x1, [x20, #slab_descriptor.object_size]
    str     xzr, [x20, #slab_descriptor.first_free]
    add     x1, x20, #slab_descriptor.struct_end
    add     x1, x1, #SLAB_BITMAP_SIZE
    str     x1, [x20, #slab_descriptor.data_start]
    
    // Initialize bitmap (all objects free)
    add     x1, x20, #slab_descriptor.struct_end
    mov     x2, #SLAB_BITMAP_SIZE
1:  strb    wzr, [x1], #1
    subs    x2, x2, #1
    b.ne    1b
    
    // Update cache statistics
    ldr     x1, [x19, #slab_cache.total_slabs]
    add     x1, x1, #1
    str     x1, [x19, #slab_cache.total_slabs]
    
    // Update global statistics
    adrp    x1, slab_stats
    add     x1, x1, :lo12:slab_stats
    ATOMIC_INC x1, x2                   // total_slabs
    
    mov     x0, x20                     // Return slab pointer
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.slab_create_new_failed:
    mov     x0, xzr
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// Find first free object in slab
// Arguments: x0 = slab pointer
// Returns: x0 = object pointer (NULL if no free objects)
.slab_find_free_object:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Check if any objects are free
    ldr     x1, [x0, #slab_descriptor.free_objects]
    cbz     x1, .slab_no_free_object
    
    // Scan bitmap for first free object
    add     x2, x0, #slab_descriptor.struct_end    // Bitmap start
    ldr     x3, [x0, #slab_descriptor.total_objects]
    mov     x4, #0                      // Object index
    
.slab_scan_bitmap:
    lsr     x5, x4, #3                  // Byte offset
    and     x6, x4, #7                  // Bit offset
    ldrb    w7, [x2, x5]
    lsr     x7, x7, x6
    tst     x7, #1
    b.eq    .slab_found_free_object
    
    add     x4, x4, #1
    cmp     x4, x3
    b.lt    .slab_scan_bitmap

.slab_no_free_object:
    mov     x0, xzr
    ldp     x29, x30, [sp], #16
    ret

.slab_found_free_object:
    // Calculate object address
    ldr     x1, [x0, #slab_descriptor.object_size]
    ldr     x2, [x0, #slab_descriptor.data_start]
    mul     x3, x4, x1
    add     x0, x2, x3
    
    ldp     x29, x30, [sp], #16
    ret

// Mark object as allocated in bitmap
// Arguments: x0 = slab pointer, x1 = object pointer
.slab_mark_allocated:
    // Calculate object index
    ldr     x2, [x0, #slab_descriptor.data_start]
    sub     x3, x1, x2                  // Offset from start
    ldr     x4, [x0, #slab_descriptor.object_size]
    udiv    x3, x3, x4                  // Object index
    
    // Set bit in bitmap (1 = allocated)
    add     x2, x0, #slab_descriptor.struct_end
    lsr     x4, x3, #3                  // Byte offset
    and     x5, x3, #7                  // Bit offset
    ldrb    w6, [x2, x4]
    mov     x7, #1
    lsl     x7, x7, x5
    orr     x6, x6, x7
    strb    w6, [x2, x4]
    
    ret

// Mark object as free in bitmap
// Arguments: x0 = slab pointer, x1 = object pointer
.slab_mark_free:
    // Calculate object index
    ldr     x2, [x0, #slab_descriptor.data_start]
    sub     x3, x1, x2
    ldr     x4, [x0, #slab_descriptor.object_size]
    udiv    x3, x3, x4
    
    // Clear bit in bitmap (0 = free)
    add     x2, x0, #slab_descriptor.struct_end
    lsr     x4, x3, #3
    and     x5, x3, #7
    ldrb    w6, [x2, x4]
    mov     x7, #1
    lsl     x7, x7, x5
    bic     x6, x6, x7
    strb    w6, [x2, x4]
    
    ret

// Check if object is free
// Arguments: x0 = slab pointer, x1 = object pointer
// Returns: x0 = 1 if free, 0 if allocated
.slab_is_object_free:
    ldr     x2, [x0, #slab_descriptor.data_start]
    sub     x3, x1, x2
    ldr     x4, [x0, #slab_descriptor.object_size]
    udiv    x3, x3, x4
    
    add     x2, x0, #slab_descriptor.struct_end
    lsr     x4, x3, #3
    and     x5, x3, #7
    ldrb    w6, [x2, x4]
    lsr     x6, x6, x5
    and     x0, x6, #1
    eor     x0, x0, #1                  // Invert (1 = free, 0 = allocated)
    
    ret

// Find which slab an object belongs to
// Arguments: x0 = cache pointer, x1 = object pointer
// Returns: x0 = slab pointer (NULL if not found)
.slab_find_object_slab:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Cache pointer
    mov     x20, x1                     // Object pointer
    
    // Search partial slabs
    ldr     x0, [x19, #slab_cache.partial_slabs]
    bl      .slab_search_list
    cbnz    x0, .slab_find_done
    
    // Search full slabs
    ldr     x0, [x19, #slab_cache.full_slabs]
    bl      .slab_search_list

.slab_find_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// Search slab list for object
// Arguments: x0 = slab list head, [x20 = object pointer]
// Returns: x0 = slab pointer (NULL if not found)
.slab_search_list:
    cbz     x0, .slab_search_not_found
    
    // Check if object is in range of this slab
    ldr     x1, [x0, #slab_descriptor.data_start]
    cmp     x20, x1
    b.lt    .slab_search_next
    
    ldr     x2, [x0, #slab_descriptor.object_size]
    ldr     x3, [x0, #slab_descriptor.total_objects]
    mul     x2, x2, x3
    add     x2, x1, x2                  // End of slab data
    cmp     x20, x2
    b.lt    .slab_search_found

.slab_search_next:
    ldr     x0, [x0, #slab_descriptor.next]
    b       .slab_search_list

.slab_search_found:
    ret

.slab_search_not_found:
    mov     x0, xzr
    ret

// Move slab from full to partial list
.slab_move_full_to_partial:
    // Implementation of list manipulation
    // This would move the slab between the cache's lists
    ret

// Move slab to empty list
.slab_move_to_empty:
    // Implementation of moving slab to empty list
    // May destroy slab if too many empty slabs exist
    ret