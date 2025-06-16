// SimCity ARM64 Assembly - Double Buffered ECS System
// Agent 2: Simulation Systems Developer
// Implements double buffering to decouple update vs render phases

.include "simulation_constants.s"

.text
.align 4

//==============================================================================
// Double Buffer ECS Structures
//==============================================================================

.struct DoubleBufferedWorld
    // Current active buffer (0 or 1)
    active_buffer       .word
    
    // Double buffered ECS worlds
    world_buffers       .space (ECSWorld_size * 2)
    
    // Synchronization and threading
    buffer_mutex        .quad       // Mutex for buffer swapping
    read_in_progress    .word       // Number of readers in progress
    write_pending       .word       // Write operation pending flag
    
    // Performance metrics
    buffer_swaps        .quad       // Total buffer swaps
    avg_swap_time_ns    .quad       // Average swap time in nanoseconds
    last_swap_time_ns   .quad       // Last swap timestamp
    
    // Memory management
    shared_allocator    .quad       // Shared allocator for both buffers
    temp_allocator      .quad       // Temporary allocator for swap operations
    
    _padding            .space 32   // Cache line alignment
.endstruct

.struct ComponentBuffer
    // Double buffered component arrays
    buffer_a            .quad       // Buffer A component data
    buffer_b            .quad       // Buffer B component data
    
    // Buffer metadata
    size                .word       // Size of each buffer
    element_count       .word       // Number of elements currently used
    capacity            .word       // Maximum number of elements
    element_size        .word       // Size of each component
    
    // Dirty tracking for optimization
    dirty_mask          .quad       // Bitmask of modified components
    last_modified_tick  .quad       // Last modification timestamp
    
    _padding            .space 16   // Alignment
.endstruct

//==============================================================================
// Global Double Buffered ECS State
//==============================================================================

.section .bss
.align 8

// Main double buffered world
double_buffered_ecs:    .space DoubleBufferedWorld_size

// Component buffers for each component type (16 max)
component_buffers:      .space (ComponentBuffer_size * 16)

// Buffer swap synchronization
.section .text

//==============================================================================
// Double Buffer ECS Initialization
//==============================================================================

// double_buffer_ecs_init - Initialize double buffered ECS system
// Parameters:
//   x0 = max_entities
//   x1 = max_archetypes
// Returns:
//   x0 = 0 on success, error code on failure
.global double_buffer_ecs_init
double_buffer_ecs_init:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    mov     x19, x0                     // max_entities
    mov     x20, x1                     // max_archetypes
    
    // Get double buffered world pointer
    adrp    x21, double_buffered_ecs
    add     x21, x21, :lo12:double_buffered_ecs
    
    // Initialize world structure
    mov     x0, x21
    mov     x1, #DoubleBufferedWorld_size
    bl      memset
    
    // Set initial active buffer to 0
    str     wzr, [x21, #DoubleBufferedWorld.active_buffer]
    
    // Initialize both ECS world buffers
    add     x22, x21, #DoubleBufferedWorld.world_buffers
    
    // Initialize buffer A (world 0)
    mov     x0, x19                     // max_entities
    mov     x1, x20                     // max_archetypes
    mov     x2, x22                     // world_ptr
    bl      init_ecs_world_buffer
    cmp     x0, #0
    b.ne    db_ecs_init_error
    
    // Initialize buffer B (world 1)
    add     x22, x22, #ECSWorld_size
    mov     x0, x19                     // max_entities
    mov     x1, x20                     // max_archetypes
    mov     x2, x22                     // world_ptr
    bl      init_ecs_world_buffer
    cmp     x0, #0
    b.ne    db_ecs_init_error
    
    // Initialize component buffers
    bl      init_component_buffers
    cmp     x0, #0
    b.ne    db_ecs_init_error
    
    // Initialize synchronization primitives
    add     x0, x21, #DoubleBufferedWorld.buffer_mutex
    bl      pthread_mutex_init
    cmp     x0, #0
    b.ne    db_ecs_init_error
    
    // Initialize performance tracking
    str     xzr, [x21, #DoubleBufferedWorld.buffer_swaps]
    str     xzr, [x21, #DoubleBufferedWorld.avg_swap_time_ns]
    bl      get_nanoseconds
    str     x0, [x21, #DoubleBufferedWorld.last_swap_time_ns]
    
    mov     x0, #0                      // Success
    b       db_ecs_init_done
    
db_ecs_init_error:
    mov     x0, #-1                     // Error
    
db_ecs_init_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// Buffer Management
//==============================================================================

// get_active_world - Get pointer to currently active ECS world
// Returns: x0 = active world pointer
.global get_active_world
get_active_world:
    adrp    x0, double_buffered_ecs
    add     x0, x0, :lo12:double_buffered_ecs
    
    ldr     w1, [x0, #DoubleBufferedWorld.active_buffer]
    add     x0, x0, #DoubleBufferedWorld.world_buffers
    
    // Calculate buffer offset: active_buffer * ECSWorld_size
    mov     x2, #ECSWorld_size
    madd    x0, x1, x2, x0
    
    ret

// get_inactive_world - Get pointer to currently inactive ECS world  
// Returns: x0 = inactive world pointer
.global get_inactive_world
get_inactive_world:
    adrp    x0, double_buffered_ecs
    add     x0, x0, :lo12:double_buffered_ecs
    
    ldr     w1, [x0, #DoubleBufferedWorld.active_buffer]
    eor     w1, w1, #1                  // Flip buffer index
    add     x0, x0, #DoubleBufferedWorld.world_buffers
    
    // Calculate buffer offset: inactive_buffer * ECSWorld_size
    mov     x2, #ECSWorld_size
    madd    x0, x1, x2, x0
    
    ret

// swap_buffers - Atomically swap active and inactive buffers
// Returns: x0 = 0 on success, error code on failure
.global swap_buffers
swap_buffers:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    // Start timing the swap operation
    bl      get_nanoseconds
    mov     x19, x0                     // Start time
    
    adrp    x20, double_buffered_ecs
    add     x20, x20, :lo12:double_buffered_ecs
    
    // Acquire buffer mutex
    add     x0, x20, #DoubleBufferedWorld.buffer_mutex
    bl      pthread_mutex_lock
    cmp     x0, #0
    b.ne    swap_buffers_error
    
    // Wait for all readers to finish
wait_for_readers:
    ldr     w0, [x20, #DoubleBufferedWorld.read_in_progress]
    cbnz    w0, wait_for_readers
    
    // Set write pending flag
    mov     w0, #1
    str     w0, [x20, #DoubleBufferedWorld.write_pending]
    
    // Perform the actual buffer swap
    ldr     w0, [x20, #DoubleBufferedWorld.active_buffer]
    eor     w0, w0, #1                  // Flip buffer index
    str     w0, [x20, #DoubleBufferedWorld.active_buffer]
    
    // Copy dirty components from old buffer to new buffer
    bl      sync_component_buffers
    
    // Clear write pending flag
    str     wzr, [x20, #DoubleBufferedWorld.write_pending]
    
    // Release buffer mutex
    add     x0, x20, #DoubleBufferedWorld.buffer_mutex
    bl      pthread_mutex_unlock
    
    // Update performance metrics
    bl      get_nanoseconds
    sub     x1, x0, x19                 // Swap duration
    ldr     x2, [x20, #DoubleBufferedWorld.buffer_swaps]
    add     x2, x2, #1
    str     x2, [x20, #DoubleBufferedWorld.buffer_swaps]
    
    // Update moving average of swap time
    ldr     x3, [x20, #DoubleBufferedWorld.avg_swap_time_ns]
    cbnz    x3, update_average
    str     x1, [x20, #DoubleBufferedWorld.avg_swap_time_ns]
    b       swap_done
    
update_average:
    // Exponential moving average: new_avg = (old_avg * 7 + new_time) / 8
    lsl     x4, x3, #3                  // old_avg * 8
    sub     x4, x4, x3                  // old_avg * 7
    add     x4, x4, x1                  // + new_time
    lsr     x4, x4, #3                  // / 8
    str     x4, [x20, #DoubleBufferedWorld.avg_swap_time_ns]
    
swap_done:
    str     x0, [x20, #DoubleBufferedWorld.last_swap_time_ns]
    mov     x0, #0                      // Success
    b       swap_buffers_done
    
swap_buffers_error:
    mov     x0, #-1                     // Error
    
swap_buffers_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Thread-Safe Access Functions
//==============================================================================

// begin_read_access - Begin reading from active buffer
// Returns: x0 = active world pointer, 0 on error
.global begin_read_access
begin_read_access:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x1, double_buffered_ecs
    add     x1, x1, :lo12:double_buffered_ecs
    
    // Check if write is pending
    ldr     w0, [x1, #DoubleBufferedWorld.write_pending]
    cbnz    w0, read_access_blocked
    
    // Atomically increment reader count
    add     x2, x1, #DoubleBufferedWorld.read_in_progress
read_increment_retry:
    ldxr    w0, [x2]
    add     w0, w0, #1
    stxr    w3, w0, [x2]
    cbnz    w3, read_increment_retry
    
    // Double-check write is not pending after incrementing
    ldr     w0, [x1, #DoubleBufferedWorld.write_pending]
    cbnz    w0, read_access_abort
    
    // Get active world pointer
    bl      get_active_world
    b       begin_read_done
    
read_access_abort:
    // Decrement reader count and return error
    add     x2, x1, #DoubleBufferedWorld.read_in_progress
read_decrement_retry:
    ldxr    w0, [x2]
    sub     w0, w0, #1
    stxr    w3, w0, [x2]
    cbnz    w3, read_decrement_retry
    
read_access_blocked:
    mov     x0, #0                      // Error - write pending
    
begin_read_done:
    ldp     x29, x30, [sp], #16
    ret

// end_read_access - End reading from active buffer
.global end_read_access
end_read_access:
    adrp    x1, double_buffered_ecs
    add     x1, x1, :lo12:double_buffered_ecs
    
    // Atomically decrement reader count
    add     x1, x1, #DoubleBufferedWorld.read_in_progress
end_read_retry:
    ldxr    w0, [x1]
    sub     w0, w0, #1
    stxr    w2, w0, [x1]
    cbnz    w2, end_read_retry
    
    ret

//==============================================================================
// Component Buffer Management
//==============================================================================

// init_component_buffers - Initialize double buffered component storage
init_component_buffers:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    adrp    x19, component_buffers
    add     x19, x19, :lo12:component_buffers
    
    // Initialize 16 component buffers
    mov     w20, #0                     // component_index
    
component_buffer_loop:
    cmp     w20, #16
    b.ge    component_buffer_done
    
    // Calculate buffer offset
    mov     x0, #ComponentBuffer_size
    mul     x0, x20, x0
    add     x21, x19, x0                // component_buffer_ptr
    
    // Initialize component buffer structure
    mov     x0, x21
    mov     x1, #ComponentBuffer_size
    bl      memset
    
    // Allocate double buffers for this component type
    mov     x0, #4096                   // Default 4KB per buffer
    bl      aligned_alloc_64
    str     x0, [x21, #ComponentBuffer.buffer_a]
    
    mov     x0, #4096
    bl      aligned_alloc_64
    str     x0, [x21, #ComponentBuffer.buffer_b]
    
    // Set default parameters
    mov     w0, #4096
    str     w0, [x21, #ComponentBuffer.size]
    str     wzr, [x21, #ComponentBuffer.element_count]
    mov     w0, #64                     // Default element size
    str     w0, [x21, #ComponentBuffer.element_size]
    udiv    w0, w0, #64                 // capacity = size / element_size
    str     w0, [x21, #ComponentBuffer.capacity]
    
    add     w20, w20, #1
    b       component_buffer_loop
    
component_buffer_done:
    mov     x0, #0                      // Success
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// sync_component_buffers - Synchronize dirty components between buffers
sync_component_buffers:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    adrp    x19, component_buffers
    add     x19, x19, :lo12:component_buffers
    
    // Get active buffer index
    adrp    x0, double_buffered_ecs
    add     x0, x0, :lo12:double_buffered_ecs
    ldr     w20, [x0, #DoubleBufferedWorld.active_buffer]
    
    // Sync all component types
    mov     w21, #0                     // component_index
    
sync_loop:
    cmp     w21, #16
    b.ge    sync_done
    
    // Get component buffer
    mov     x0, #ComponentBuffer_size
    mul     x0, x21, x0
    add     x22, x19, x0                // component_buffer_ptr
    
    // Check if this component type has dirty data
    ldr     x0, [x22, #ComponentBuffer.dirty_mask]
    cbz     x0, next_component
    
    // Determine source and destination buffers
    cbnz    w20, sync_b_to_a
    
    // Copy A to B
    ldr     x0, [x22, #ComponentBuffer.buffer_a]
    ldr     x1, [x22, #ComponentBuffer.buffer_b]
    b       do_sync
    
sync_b_to_a:
    // Copy B to A
    ldr     x0, [x22, #ComponentBuffer.buffer_b]
    ldr     x1, [x22, #ComponentBuffer.buffer_a]
    
do_sync:
    ldr     w2, [x22, #ComponentBuffer.size]
    bl      memcpy
    
    // Clear dirty mask
    str     xzr, [x22, #ComponentBuffer.dirty_mask]
    
next_component:
    add     w21, w21, #1
    b       sync_loop
    
sync_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// High-Level Update Functions
//==============================================================================

// double_buffer_update - Update simulation in background buffer
// Parameters:
//   x0 = current_tick
//   d0 = delta_time
.global double_buffer_update
double_buffer_update:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                     // current_tick
    fmov    s20, s0                     // delta_time
    
    // Get inactive world for updating
    bl      get_inactive_world
    mov     x21, x0                     // inactive_world_ptr
    
    // Update all systems on inactive buffer
    mov     x0, x19                     // current_tick
    fmov    s0, s20                     // delta_time
    mov     x2, x21                     // world_ptr
    bl      ecs_update_systems_on_world
    
    // Mark frame as ready for swap
    bl      mark_frame_ready
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// double_buffer_render - Render from active buffer
// Returns: x0 = active world pointer for rendering
.global double_buffer_render
double_buffer_render:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Begin read access to active buffer
    bl      begin_read_access
    
    // Return active world pointer (caller must call end_read_access)
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Utility Functions
//==============================================================================

// init_ecs_world_buffer - Initialize a single ECS world buffer
// Parameters: x0 = max_entities, x1 = max_archetypes, x2 = world_ptr
init_ecs_world_buffer:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Save world pointer and call standard ECS init
    mov     x3, x2                      // Save world_ptr
    bl      ecs_init_with_world         // Custom init function
    
    ldp     x29, x30, [sp], #16
    ret

// mark_frame_ready - Mark current frame as ready for buffer swap
mark_frame_ready:
    // Could set a flag or send a signal to rendering thread
    // For now, just return
    ret

// get_nanoseconds - Get current time in nanoseconds
get_nanoseconds:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Use ARM generic timer
    mrs     x0, cntvct_el0              // Get virtual count
    mrs     x1, cntfrq_el0              // Get frequency
    
    // Convert to nanoseconds: (count * 1000000000) / frequency
    mov     x2, #1000000000
    mul     x0, x0, x2
    udiv    x0, x0, x1
    
    ldp     x29, x30, [sp], #16
    ret

// aligned_alloc_64 - Allocate 64-byte aligned memory
// Parameters: x0 = size
aligned_alloc_64:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    add     x0, x0, #63                 // Add alignment - 1
    mov     x1, #64                     // 64-byte alignment
    bl      posix_memalign
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// External Function Declarations
//==============================================================================

.extern memset
.extern memcpy
.extern posix_memalign
.extern pthread_mutex_init
.extern pthread_mutex_lock  
.extern pthread_mutex_unlock
.extern ecs_init_with_world
.extern ecs_update_systems_on_world

.end