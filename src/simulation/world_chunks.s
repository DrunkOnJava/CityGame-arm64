//
// SimCity ARM64 Assembly - World Chunk Management
// Agent 4: Simulation Engine
//
// Manages 4096x4096 world divided into 16x16 tile chunks
// Supports efficient spatial queries and LOD-based updates
//

.include "simulation_constants.s"

.text
.align 4

// Tile structure (64 bytes, cache-line aligned)
.struct Tile
    // Basic properties (8 bytes)
    type                .byte       // Building/terrain type
    zone                .byte       // R/C/I/special zone
    height              .byte       // Elevation level
    density             .byte       // Development density
    building_id         .hword      // Building instance ID
    flags               .hword      // State flags
    
    // Services (8 bytes)
    power               .byte       // Power availability (0-255)
    water               .byte       // Water availability (0-255)
    police              .byte       // Police coverage (0-255)
    fire                .byte       // Fire coverage (0-255)
    health              .byte       // Health coverage (0-255)
    education           .byte       // Education coverage (0-255)
    transport           .byte       // Transit access (0-255)
    _services_pad       .byte
    
    // Statistics (16 bytes)
    population          .hword      // Residents/workers
    jobs                .hword      // Available jobs
    land_value          .word       // Property value
    pollution           .hword      // Pollution level
    crime               .hword      // Crime rate
    happiness           .hword      // Resident satisfaction
    tax_revenue         .hword      // Tax generation
    
    // Traffic flow (8 bytes)
    flow_north          .hword      // Traffic volume N
    flow_east           .hword      // Traffic volume E
    flow_south          .hword      // Traffic volume S
    flow_west           .hword      // Traffic volume W
    
    // Reserved for future use (24 bytes)
    reserved            .space 24
.endstruct

// Chunk structure
.struct Chunk
    // Chunk metadata (128 bytes)
    chunk_x             .hword      // Chunk X coordinate
    chunk_y             .hword      // Chunk Y coordinate
    flags               .word       // Chunk state flags
    lod_level           .word       // Level of detail
    
    last_update         .quad       // Last update tick
    next_update         .quad       // Next scheduled update
    dirty_mask          .quad       // Bitmask of dirty tiles (first 64)
    dirty_mask2         .quad       // Bitmask of dirty tiles (next 64)
    dirty_mask3         .quad       // Bitmask of dirty tiles (next 64)
    dirty_mask4         .quad       // Bitmask of dirty tiles (last 64)
    
    // Statistics (32 bytes)
    total_population    .word       // Total population in chunk
    total_jobs          .word       // Total jobs in chunk
    avg_happiness       .hword      // Average happiness
    avg_land_value      .hword      // Average land value
    avg_pollution       .hword      // Average pollution
    avg_crime           .hword      // Average crime
    power_demand        .word       // Total power demand
    water_demand        .word       // Total water demand
    tax_revenue         .word       // Total tax revenue
    _stats_pad          .word
    
    // Neighbor pointers (64 bytes)
    neighbor_n          .quad       // North neighbor
    neighbor_ne         .quad       // Northeast neighbor
    neighbor_e          .quad       // East neighbor
    neighbor_se         .quad       // Southeast neighbor
    neighbor_s          .quad       // South neighbor
    neighbor_sw         .quad       // Southwest neighbor
    neighbor_w          .quad       // West neighbor
    neighbor_nw         .quad       // Northwest neighbor
    
    // Tile data (16384 bytes = 256 tiles * 64 bytes)
    tiles               .space (16 * 16 * 64)
.endstruct

// World management structure
.struct WorldState
    chunks              .quad       // Array of all chunks
    active_chunks       .quad       // List of active chunks
    visible_chunks      .quad       // List of visible chunks
    
    active_count        .word       // Number of active chunks
    visible_count       .word       // Number of visible chunks
    total_population    .word       // Total world population
    total_jobs          .word       // Total world jobs
    
    // Spatial indexing
    chunk_lookup        .quad       // 2D lookup table for chunks
    
    // Update scheduling
    update_queue_near   .quad       // Queue for near LOD updates
    update_queue_medium .quad       // Queue for medium LOD updates
    update_queue_far    .quad       // Queue for far LOD updates
    
    queue_size_near     .word       // Size of near queue
    queue_size_medium   .word       // Size of medium queue
    queue_size_far      .word       // Size of far queue
    queue_capacity      .word       // Max queue capacity
    
    // LOD scheduling state
    lod_schedule_tick   .quad       // Current scheduling tick
    near_update_mask    .quad       // Bitmask for near chunks to update
    medium_update_mask  .quad       // Bitmask for medium chunks to update
    far_update_mask     .quad       // Bitmask for far chunks to update
.endstruct

.section .bss
    .align 8
    world_state: .space WorldState_size
    
    // Chunk array - 65536 chunks * 16512 bytes each = ~1GB
    .align 4096
    world_chunks: .space (TOTAL_CHUNKS * Chunk_size)
    
    // Chunk lookup table - 256x256 pointers
    .align 8
    chunk_lookup_table: .space (CHUNK_COUNT_X * CHUNK_COUNT_Y * 8)
    
    // Active chunk list
    .align 8
    active_chunk_list: .space (TOTAL_CHUNKS * 8)
    
    // Visible chunk list
    .align 8
    visible_chunk_list: .space (TOTAL_CHUNKS * 8)

.section .text

//
// world_chunks_init - Initialize the world chunk system
//
// Returns:
//   x0 = 0 on success, error code on failure
//
.global world_chunks_init
world_chunks_init:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    // Initialize world state
    adrp    x19, world_state
    add     x19, x19, :lo12:world_state
    
    // Clear world state
    mov     x20, #0
    mov     x21, #(WorldState_size / 8)
1:  str     x20, [x19], #8
    subs    x21, x21, #1
    b.ne    1b
    
    // Reset pointer
    adrp    x19, world_state
    add     x19, x19, :lo12:world_state
    
    // Set up chunk arrays
    adrp    x20, world_chunks
    add     x20, x20, :lo12:world_chunks
    str     x20, [x19, #WorldState.chunks]
    
    adrp    x20, chunk_lookup_table
    add     x20, x20, :lo12:chunk_lookup_table
    str     x20, [x19, #WorldState.chunk_lookup]
    
    adrp    x20, active_chunk_list
    add     x20, x20, :lo12:active_chunk_list
    str     x20, [x19, #WorldState.active_chunks]
    
    adrp    x20, visible_chunk_list
    add     x20, x20, :lo12:visible_chunk_list
    str     x20, [x19, #WorldState.visible_chunks]
    
    // Initialize all chunks
    bl      initialize_all_chunks
    
    // Build chunk lookup table
    bl      build_chunk_lookup_table
    
    // Link chunk neighbors
    bl      link_chunk_neighbors
    
    mov     x0, #0                  // Success
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// initialize_all_chunks - Initialize all chunk structures
//
initialize_all_chunks:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    // Get chunks array
    adrp    x19, world_chunks
    add     x19, x19, :lo12:world_chunks
    
    mov     x20, #0                 // chunk_index
    
chunk_init_loop:
    // Calculate chunk coordinates
    mov     x0, x20
    mov     x1, #CHUNK_COUNT_X
    udiv    x2, x0, x1              // chunk_y = index / width
    msub    x3, x2, x1, x0          // chunk_x = index % width
    
    // Calculate chunk address
    mov     x4, #Chunk_size
    mul     x5, x20, x4
    add     x5, x19, x5             // chunk_ptr
    
    // Clear chunk memory
    mov     x6, #0
    mov     x7, #(Chunk_size / 8)
clear_chunk_loop:
    str     x6, [x5], #8
    subs    x7, x7, #1
    b.ne    clear_chunk_loop
    
    // Reset chunk pointer
    mov     x4, #Chunk_size
    mul     x5, x20, x4
    add     x5, x19, x5
    
    // Set chunk coordinates
    str     w3, [x5, #Chunk.chunk_x]
    str     w2, [x5, #Chunk.chunk_y]
    
    // Set initial LOD level (far by default)
    mov     x6, #LOD_FAR
    str     w6, [x5, #Chunk.lod_level]
    
    // Initialize tiles in chunk
    add     x6, x5, #Chunk.tiles    // tiles_ptr
    mov     x7, #0                  // tile_index
    
tile_init_loop:
    // Calculate tile coordinates within chunk
    and     x8, x7, #15             // tile_x = index % 16
    lsr     x9, x7, #4              // tile_y = index / 16
    
    // Calculate world tile coordinates
    lsl     x10, x3, #4             // world_tile_x = chunk_x * 16
    add     x10, x10, x8            // + tile_x
    lsl     x11, x2, #4             // world_tile_y = chunk_y * 16
    add     x11, x11, x9            // + tile_y
    
    // Initialize tile (default empty)
    mov     x12, #TILE_TYPE_EMPTY
    str     w12, [x6, #Tile.type]
    
    // Set base land value
    mov     x12, #BASE_LAND_VALUE
    str     w12, [x6, #Tile.land_value]
    
    // Move to next tile
    add     x6, x6, #Tile_size
    add     x7, x7, #1
    cmp     x7, #TILES_PER_CHUNK
    b.lt    tile_init_loop
    
    // Move to next chunk
    add     x20, x20, #1
    cmp     x20, #TOTAL_CHUNKS
    b.lt    chunk_init_loop
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// build_chunk_lookup_table - Build 2D lookup table for chunks
//
build_chunk_lookup_table:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    adrp    x19, chunk_lookup_table
    add     x19, x19, :lo12:chunk_lookup_table
    
    adrp    x20, world_chunks
    add     x20, x20, :lo12:world_chunks
    
    mov     x0, #0                  // chunk_index
    
lookup_build_loop:
    // Calculate chunk address
    mov     x1, #Chunk_size
    mul     x2, x0, x1
    add     x2, x20, x2             // chunk_ptr
    
    // Calculate lookup table index
    mov     x1, x0
    lsl     x1, x1, #3              // * 8 (pointer size)
    add     x3, x19, x1             // lookup_entry_ptr
    
    // Store chunk pointer in lookup table
    str     x2, [x3]
    
    add     x0, x0, #1
    cmp     x0, #TOTAL_CHUNKS
    b.lt    lookup_build_loop
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// link_chunk_neighbors - Link all chunks to their neighbors
//
link_chunk_neighbors:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, #0                 // chunk_y
    
neighbor_y_loop:
    mov     x20, #0                 // chunk_x
    
neighbor_x_loop:
    // Get chunk pointer
    mov     x0, x20                 // chunk_x
    mov     x1, x19                 // chunk_y
    bl      get_chunk_at
    mov     x2, x0                  // current_chunk
    
    // Link north neighbor
    cmp     x19, #0
    b.eq    skip_north
    mov     x0, x20
    sub     x1, x19, #1
    bl      get_chunk_at
    str     x0, [x2, #Chunk.neighbor_n]
skip_north:
    
    // Link south neighbor
    mov     x0, #(CHUNK_COUNT_Y - 1)
    cmp     x19, x0
    b.eq    skip_south
    mov     x0, x20
    add     x1, x19, #1
    bl      get_chunk_at
    str     x0, [x2, #Chunk.neighbor_s]
skip_south:
    
    // Link east neighbor
    mov     x0, #(CHUNK_COUNT_X - 1)
    cmp     x20, x0
    b.eq    skip_east
    add     x0, x20, #1
    mov     x1, x19
    bl      get_chunk_at
    str     x0, [x2, #Chunk.neighbor_e]
skip_east:
    
    // Link west neighbor
    cmp     x20, #0
    b.eq    skip_west
    sub     x0, x20, #1
    mov     x1, x19
    bl      get_chunk_at
    str     x0, [x2, #Chunk.neighbor_w]
skip_west:
    
    // Link diagonal neighbors (NE, NW, SE, SW)
    // Northeast
    mov     x0, #(CHUNK_COUNT_X - 1)
    cmp     x20, x0
    b.eq    skip_ne
    cmp     x19, #0
    b.eq    skip_ne
    add     x0, x20, #1
    sub     x1, x19, #1
    bl      get_chunk_at
    str     x0, [x2, #Chunk.neighbor_ne]
skip_ne:
    
    // Northwest
    cmp     x20, #0
    b.eq    skip_nw
    cmp     x19, #0
    b.eq    skip_nw
    sub     x0, x20, #1
    sub     x1, x19, #1
    bl      get_chunk_at
    str     x0, [x2, #Chunk.neighbor_nw]
skip_nw:
    
    // Southeast
    mov     x0, #(CHUNK_COUNT_X - 1)
    cmp     x20, x0
    b.eq    skip_se
    mov     x0, #(CHUNK_COUNT_Y - 1)
    cmp     x19, x0
    b.eq    skip_se
    add     x0, x20, #1
    add     x1, x19, #1
    bl      get_chunk_at
    str     x0, [x2, #Chunk.neighbor_se]
skip_se:
    
    // Southwest
    cmp     x20, #0
    b.eq    skip_sw
    mov     x0, #(CHUNK_COUNT_Y - 1)
    cmp     x19, x0
    b.eq    skip_sw
    sub     x0, x20, #1
    add     x1, x19, #1
    bl      get_chunk_at
    str     x0, [x2, #Chunk.neighbor_sw]
skip_sw:
    
    add     x20, x20, #1
    cmp     x20, #CHUNK_COUNT_X
    b.lt    neighbor_x_loop
    
    add     x19, x19, #1
    cmp     x19, #CHUNK_COUNT_Y
    b.lt    neighbor_y_loop
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// get_chunk_at - Get chunk at specified coordinates
//
// Parameters:
//   x0 = chunk_x
//   x1 = chunk_y
//
// Returns:
//   x0 = chunk pointer, or 0 if out of bounds
//
.global get_chunk_at
get_chunk_at:
    // Bounds check
    cmp     x0, #CHUNK_COUNT_X
    b.ge    get_chunk_bounds_error
    cmp     x1, #CHUNK_COUNT_Y
    b.ge    get_chunk_bounds_error
    
    // Calculate chunk index
    mov     x2, #CHUNK_COUNT_X
    mul     x3, x1, x2              // y * width
    add     x3, x3, x0              // + x
    
    // Get chunk from lookup table
    adrp    x2, chunk_lookup_table
    add     x2, x2, :lo12:chunk_lookup_table
    lsl     x3, x3, #3              // * 8 (pointer size)
    add     x2, x2, x3
    ldr     x0, [x2]
    ret
    
get_chunk_bounds_error:
    mov     x0, #0
    ret

//
// get_tile_at - Get tile at specified world coordinates
//
// Parameters:
//   x0 = world_tile_x
//   x1 = world_tile_y
//
// Returns:
//   x0 = tile pointer, or 0 if out of bounds
//
.global get_tile_at
get_tile_at:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Bounds check
    cmp     x0, #WORLD_WIDTH
    b.ge    get_tile_bounds_error
    cmp     x1, #WORLD_HEIGHT
    b.ge    get_tile_bounds_error
    
    // Calculate chunk coordinates
    lsr     x2, x0, #4              // chunk_x = tile_x / 16
    lsr     x3, x1, #4              // chunk_y = tile_y / 16
    
    // Get chunk
    mov     x4, x0                  // Save tile coordinates
    mov     x5, x1
    mov     x0, x2
    mov     x1, x3
    bl      get_chunk_at
    cbz     x0, get_tile_bounds_error
    
    // Calculate tile offset within chunk
    and     x2, x4, #15             // tile_x_in_chunk = tile_x & 15
    and     x3, x5, #15             // tile_y_in_chunk = tile_y & 15
    
    // Calculate tile index within chunk
    lsl     x4, x3, #4              // tile_y_in_chunk * 16
    add     x4, x4, x2              // + tile_x_in_chunk
    
    // Calculate tile address
    mov     x5, #Tile_size
    mul     x4, x4, x5              // tile_index * tile_size
    add     x0, x0, #Chunk.tiles    // chunk.tiles
    add     x0, x0, x4              // + tile_offset
    
    ldp     x29, x30, [sp], #16
    ret
    
get_tile_bounds_error:
    mov     x0, #0
    ldp     x29, x30, [sp], #16
    ret

//
// mark_chunk_dirty - Mark a chunk as needing updates
//
// Parameters:
//   x0 = chunk pointer
//   x1 = tile index within chunk (0-255)
//
.global mark_chunk_dirty
mark_chunk_dirty:
    cbz     x0, mark_chunk_dirty_exit
    
    // Set chunk dirty flag
    ldr     w2, [x0, #Chunk.flags]
    orr     w2, w2, #CHUNK_FLAG_DIRTY
    str     w2, [x0, #Chunk.flags]
    
    // Set tile dirty bit
    cmp     x1, #64
    b.lt    dirty_mask_1
    cmp     x1, #128
    b.lt    dirty_mask_2
    cmp     x1, #192
    b.lt    dirty_mask_3
    b       dirty_mask_4
    
dirty_mask_1:
    mov     x3, #1
    lsl     x3, x3, x1
    ldr     x2, [x0, #Chunk.dirty_mask]
    orr     x2, x2, x3
    str     x2, [x0, #Chunk.dirty_mask]
    b       mark_chunk_dirty_exit
    
dirty_mask_2:
    sub     x1, x1, #64
    mov     x3, #1
    lsl     x3, x3, x1
    ldr     x2, [x0, #Chunk.dirty_mask2]
    orr     x2, x2, x3
    str     x2, [x0, #Chunk.dirty_mask2]
    b       mark_chunk_dirty_exit
    
dirty_mask_3:
    sub     x1, x1, #128
    mov     x3, #1
    lsl     x3, x3, x1
    ldr     x2, [x0, #Chunk.dirty_mask3]
    orr     x2, x2, x3
    str     x2, [x0, #Chunk.dirty_mask3]
    b       mark_chunk_dirty_exit
    
dirty_mask_4:
    sub     x1, x1, #192
    mov     x3, #1
    lsl     x3, x3, x1
    ldr     x2, [x0, #Chunk.dirty_mask4]
    orr     x2, x2, x3
    str     x2, [x0, #Chunk.dirty_mask4]
    
mark_chunk_dirty_exit:
    ret

//
// clear_chunk_dirty - Clear chunk dirty flags
//
// Parameters:
//   x0 = chunk pointer
//
.global clear_chunk_dirty
clear_chunk_dirty:
    cbz     x0, clear_chunk_dirty_exit
    
    // Clear chunk dirty flag
    ldr     w2, [x0, #Chunk.flags]
    bic     w2, w2, #CHUNK_FLAG_DIRTY
    str     w2, [x0, #Chunk.flags]
    
    // Clear all dirty masks
    str     xzr, [x0, #Chunk.dirty_mask]
    str     xzr, [x0, #Chunk.dirty_mask2]
    str     xzr, [x0, #Chunk.dirty_mask3]
    str     xzr, [x0, #Chunk.dirty_mask4]
    
clear_chunk_dirty_exit:
    ret

//
// set_chunk_lod - Set chunk level of detail
//
// Parameters:
//   x0 = chunk pointer
//   x1 = LOD level (0=near, 1=medium, 2=far, 3=inactive)
//
.global set_chunk_lod
set_chunk_lod:
    cbz     x0, set_chunk_lod_exit
    str     w1, [x0, #Chunk.lod_level]
set_chunk_lod_exit:
    ret

//
// tile_update_all_chunks - Update all active chunks based on LOD
//
// This is the main tile update function called from simulation loop
// Updates chunks based on their LOD level and visibility
//
.global tile_update_all_chunks
tile_update_all_chunks:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    // Get world state
    adrp    x19, world_state
    add     x19, x19, :lo12:world_state
    
    // Get current simulation tick for LOD scheduling
    bl      simulation_get_tick_count
    mov     x20, x0                 // current_tick
    
    // Get active chunks list
    ldr     x21, [x19, #WorldState.active_chunks]
    ldr     w22, [x19, #WorldState.active_count]
    
    mov     x0, #0                  // chunk_index
    
update_chunks_loop:
    cmp     x0, x22
    b.ge    update_chunks_done
    
    // Get chunk pointer from active list
    lsl     x1, x0, #3              // * 8 (pointer size)
    add     x1, x21, x1
    ldr     x1, [x1]                // chunk_ptr
    
    // Check if chunk needs update based on LOD
    ldr     w2, [x1, #Chunk.lod_level]
    mov     x3, x20                 // current_tick
    
    // Check update frequency based on LOD
    cmp     w2, #LOD_NEAR
    b.eq    update_chunk_now
    cmp     w2, #LOD_MEDIUM
    b.eq    check_medium_lod
    cmp     w2, #LOD_FAR
    b.eq    check_far_lod
    b       skip_chunk_update       // LOD_INACTIVE
    
check_medium_lod:
    and     x3, x3, #(UPDATE_FREQ_MEDIUM - 1)
    cbnz    x3, skip_chunk_update
    b       update_chunk_now
    
check_far_lod:
    and     x3, x3, #(UPDATE_FREQ_FAR - 1)
    cbnz    x3, skip_chunk_update
    
update_chunk_now:
    // Update this chunk
    stp     x0, x1, [sp, #-16]!     // Save loop variables
    mov     x0, x1                  // chunk_ptr
    bl      update_single_chunk
    ldp     x0, x1, [sp], #16       // Restore loop variables
    
skip_chunk_update:
    add     x0, x0, #1
    b       update_chunks_loop
    
update_chunks_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// update_single_chunk - Update a single chunk's tiles
//
// Parameters:
//   x0 = chunk pointer
//
update_single_chunk:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                 // chunk_ptr
    
    // Check if chunk is dirty
    ldr     w20, [x19, #Chunk.flags]
    tst     w20, #CHUNK_FLAG_DIRTY
    b.eq    single_chunk_done       // Skip if not dirty
    
    // Update chunk statistics
    bl      update_chunk_statistics
    
    // Update tiles that are marked dirty
    mov     x0, x19
    bl      update_dirty_tiles
    
    // Clear dirty flags
    mov     x0, x19  
    bl      clear_chunk_dirty
    
    // Update last update time
    bl      simulation_get_tick_count
    str     x0, [x19, #Chunk.last_update]
    
single_chunk_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// update_dirty_tiles - Update only dirty tiles in a chunk
//
// Parameters:
//   x0 = chunk pointer
//
update_dirty_tiles:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    mov     x19, x0                 // chunk_ptr
    
    // Process each dirty mask
    ldr     x20, [x19, #Chunk.dirty_mask]
    mov     x21, #0                 // tile_base_index = 0
    bl      process_dirty_mask
    
    ldr     x20, [x19, #Chunk.dirty_mask2]
    mov     x21, #64                // tile_base_index = 64
    bl      process_dirty_mask
    
    ldr     x20, [x19, #Chunk.dirty_mask3]
    mov     x21, #128               // tile_base_index = 128
    bl      process_dirty_mask
    
    ldr     x20, [x19, #Chunk.dirty_mask4]
    mov     x21, #192               // tile_base_index = 192
    bl      process_dirty_mask
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// process_dirty_mask - Process tiles marked in a dirty mask
//
// Parameters:
//   x19 = chunk pointer
//   x20 = dirty mask
//   x21 = base tile index
//
process_dirty_mask:
    stp     x29, x30, [sp, #-32]!
    stp     x22, x23, [sp, #16]
    mov     x29, sp
    
    cbz     x20, process_mask_done  // No dirty tiles
    
    mov     x22, #0                 // bit_index
    
process_mask_loop:
    cmp     x22, #64
    b.ge    process_mask_done
    
    // Check if bit is set
    mov     x23, #1
    lsl     x23, x23, x22
    tst     x20, x23
    b.eq    next_mask_bit
    
    // Update this tile
    add     x0, x21, x22            // tile_index = base + bit_index
    mov     x1, x19                 // chunk_ptr
    bl      update_single_tile
    
next_mask_bit:
    add     x22, x22, #1
    b       process_mask_loop
    
process_mask_done:
    ldp     x22, x23, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// update_single_tile - Update a single tile's simulation state
//
// Parameters:
//   x0 = tile index within chunk (0-255)
//   x1 = chunk pointer
//
update_single_tile:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                 // tile_index
    mov     x20, x1                 // chunk_ptr
    
    // Calculate tile address
    mov     x0, #Tile_size
    mul     x0, x19, x0
    add     x0, x20, #Chunk.tiles
    add     x0, x0, x0              // tile_ptr
    
    // Get tile type
    ldr     w1, [x0, #Tile.type]
    
    // Update based on tile type
    cmp     w1, #TILE_TYPE_RESIDENTIAL
    b.eq    update_residential_tile
    cmp     w1, #TILE_TYPE_COMMERCIAL  
    b.eq    update_commercial_tile
    cmp     w1, #TILE_TYPE_INDUSTRIAL
    b.eq    update_industrial_tile
    b       update_tile_done        // Empty or special tiles
    
update_residential_tile:
    bl      simulate_residential_growth
    b       update_tile_done
    
update_commercial_tile:
    bl      simulate_commercial_activity
    b       update_tile_done
    
update_industrial_tile:
    bl      simulate_industrial_production
    
update_tile_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// update_chunk_statistics - Update chunk-level statistics
//
// Parameters:
//   x0 = chunk pointer (preserved in x19)
//
update_chunk_statistics:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                 // chunk_ptr
    
    // Reset statistics
    str     wzr, [x19, #Chunk.total_population]
    str     wzr, [x19, #Chunk.total_jobs]
    str     wzr, [x19, #Chunk.power_demand]
    str     wzr, [x19, #Chunk.water_demand]
    str     wzr, [x19, #Chunk.tax_revenue]
    
    // Sum tile statistics
    add     x20, x19, #Chunk.tiles
    mov     x0, #0                  // tile_index
    
stats_loop:
    cmp     x0, #TILES_PER_CHUNK
    b.ge    stats_done
    
    // Get tile pointer
    mov     x1, #Tile_size
    mul     x1, x0, x1
    add     x1, x20, x1             // tile_ptr
    
    // Add population
    ldr     w2, [x19, #Chunk.total_population]
    ldrh    w3, [x1, #Tile.population]
    add     w2, w2, w3
    str     w2, [x19, #Chunk.total_population]
    
    // Add jobs
    ldr     w2, [x19, #Chunk.total_jobs]
    ldrh    w3, [x1, #Tile.jobs]
    add     w2, w2, w3
    str     w2, [x19, #Chunk.total_jobs]
    
    // Add tax revenue
    ldr     w2, [x19, #Chunk.tax_revenue]
    ldrh    w3, [x1, #Tile.tax_revenue]
    add     w2, w2, w3
    str     w2, [x19, #Chunk.tax_revenue]
    
    add     x0, x0, #1
    b       stats_loop
    
stats_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// Placeholder tile simulation functions
//
simulate_residential_growth:
    // TODO: Implement residential tile growth simulation
    ret

simulate_commercial_activity:
    // TODO: Implement commercial tile activity simulation
    ret

simulate_industrial_production:
    // TODO: Implement industrial tile production simulation
    ret

//
// update_chunk_visibility - Update chunk visibility and LOD based on camera
//
// Parameters:
//   x0 = camera world X position
//   x1 = camera world Y position  
//   x2 = view distance in tiles
//
.global update_chunk_visibility
update_chunk_visibility:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    // Convert camera position to chunk coordinates
    TILE_TO_CHUNK_X x0, x19         // camera_chunk_x
    TILE_TO_CHUNK_Y x1, x20         // camera_chunk_y
    
    // Calculate view distance in chunks
    add     x2, x2, #15             // Round up
    lsr     x21, x2, #4             // view_distance_chunks
    
    // Get world state
    adrp    x22, world_state
    add     x22, x22, :lo12:world_state
    
    // Clear current active and visible lists
    str     wzr, [x22, #WorldState.active_count]
    str     wzr, [x22, #WorldState.visible_count]
    
    // Calculate chunk bounds
    sub     x0, x19, x21            // min_chunk_x
    add     x1, x19, x21            // max_chunk_x
    sub     x2, x20, x21            // min_chunk_y
    add     x3, x20, x21            // max_chunk_y
    
    // Clamp to world bounds
    cmp     x0, #0
    csel    x0, x0, xzr, ge
    cmp     x1, #CHUNK_COUNT_X
    mov     x4, #CHUNK_COUNT_X
    csel    x1, x1, x4, lt
    cmp     x2, #0
    csel    x2, x2, xzr, ge
    cmp     x3, #CHUNK_COUNT_Y
    mov     x4, #CHUNK_COUNT_Y
    csel    x3, x3, x4, lt
    
    // Iterate through visible chunk area
    mov     x4, x2                  // current_y = min_chunk_y
    
visibility_y_loop:
    cmp     x4, x3
    b.ge    visibility_done
    
    mov     x5, x0                  // current_x = min_chunk_x
    
visibility_x_loop:
    cmp     x5, x1
    b.ge    next_visibility_y
    
    // Get chunk at (x5, x4)
    mov     x6, x5                  // chunk_x
    mov     x7, x4                  // chunk_y
    bl      get_chunk_at
    cbz     x0, next_visibility_x
    
    // Calculate distance from camera chunk
    sub     x8, x5, x19             // dx
    sub     x9, x4, x20             // dy
    mul     x8, x8, x8              // dx^2
    mul     x9, x9, x9              // dy^2
    add     x8, x8, x9              // distance_squared
    
    // Determine LOD level based on distance
    mul     x9, x21, x21            // view_distance_squared
    lsr     x10, x9, #2             // quarter_distance_squared (near)
    lsr     x11, x9, #1             // half_distance_squared (medium)
    
    cmp     x8, x10
    b.lt    set_near_lod
    cmp     x8, x11
    b.lt    set_medium_lod
    cmp     x8, x9
    b.lt    set_far_lod
    b       set_inactive_lod
    
set_near_lod:
    mov     x12, #LOD_NEAR
    bl      add_to_visible_list
    bl      add_to_active_list
    b       update_chunk_lod
    
set_medium_lod:
    mov     x12, #LOD_MEDIUM
    bl      add_to_active_list
    b       update_chunk_lod
    
set_far_lod:
    mov     x12, #LOD_FAR
    bl      add_to_active_list
    b       update_chunk_lod
    
set_inactive_lod:
    mov     x12, #LOD_INACTIVE
    
update_chunk_lod:
    // Set chunk LOD and flags
    mov     x1, x12
    bl      set_chunk_lod
    
    // Set visibility flag for near LOD
    ldr     w13, [x0, #Chunk.flags]
    bic     w13, w13, #CHUNK_FLAG_VISIBLE
    cmp     x12, #LOD_NEAR
    b.ne    1f
    orr     w13, w13, #CHUNK_FLAG_VISIBLE
1:  str     w13, [x0, #Chunk.flags]
    
next_visibility_x:
    add     x5, x5, #1
    b       visibility_x_loop
    
next_visibility_y:
    add     x4, x4, #1
    b       visibility_y_loop
    
visibility_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// add_to_active_list - Add chunk to active chunks list
//
// Parameters:
//   x0 = chunk pointer
//   x22 = world state pointer (preserved)
//
add_to_active_list:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get current active count
    ldr     w1, [x22, #WorldState.active_count]
    cmp     w1, #TOTAL_CHUNKS
    b.ge    add_active_done         // List full
    
    // Add to active list
    ldr     x2, [x22, #WorldState.active_chunks]
    lsl     x3, x1, #3              // * 8 (pointer size)
    add     x3, x2, x3
    str     x0, [x3]
    
    // Increment count
    add     w1, w1, #1
    str     w1, [x22, #WorldState.active_count]
    
    // Set active flag
    ldr     w1, [x0, #Chunk.flags]
    orr     w1, w1, #CHUNK_FLAG_ACTIVE
    str     w1, [x0, #Chunk.flags]
    
add_active_done:
    ldp     x29, x30, [sp], #16
    ret

//
// add_to_visible_list - Add chunk to visible chunks list
//
// Parameters:
//   x0 = chunk pointer
//   x22 = world state pointer (preserved)
//
add_to_visible_list:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get current visible count
    ldr     w1, [x22, #WorldState.visible_count]
    cmp     w1, #TOTAL_CHUNKS
    b.ge    add_visible_done        // List full
    
    // Add to visible list
    ldr     x2, [x22, #WorldState.visible_chunks]
    lsl     x3, x1, #3              // * 8 (pointer size)
    add     x3, x2, x3
    str     x0, [x3]
    
    // Increment count
    add     w1, w1, #1
    str     w1, [x22, #WorldState.visible_count]
    
add_visible_done:
    ldp     x29, x30, [sp], #16
    ret

//
// chunk_streaming_update - Asynchronously load/unload chunks
//
// Called periodically to manage chunk memory usage
//
.global chunk_streaming_update
chunk_streaming_update:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    // Get world state
    adrp    x19, world_state
    add     x19, x19, :lo12:world_state
    
    // Unload chunks that are far from camera
    bl      unload_distant_chunks
    
    // Load required chunk data
    bl      load_nearby_chunks
    
    // Update chunk streaming statistics
    bl      update_streaming_stats
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// unload_distant_chunks - Unload chunks that are too far from camera
//
unload_distant_chunks:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    // TODO: Implement chunk unloading
    // For now, just mark distant chunks as inactive
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// load_nearby_chunks - Load chunk data for nearby chunks
//
load_nearby_chunks:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    // TODO: Implement chunk loading from storage
    // For now, just mark chunks as loaded
    
    adrp    x19, world_state
    add     x19, x19, :lo12:world_state
    
    ldr     x20, [x19, #WorldState.active_chunks]
    ldr     w0, [x19, #WorldState.active_count]
    
    mov     w1, #0                  // chunk_index
    
load_chunks_loop:
    cmp     w1, w0
    b.ge    load_chunks_done
    
    // Get chunk pointer
    lsl     x2, x1, #3
    add     x2, x20, x2
    ldr     x2, [x2]
    
    // Mark as loaded
    ldr     w3, [x2, #Chunk.flags]
    orr     w3, w3, #CHUNK_FLAG_LOADED
    str     w3, [x2, #Chunk.flags]
    
    add     w1, w1, #1
    b       load_chunks_loop
    
load_chunks_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// update_streaming_stats - Update chunk streaming statistics
//
update_streaming_stats:
    // TODO: Implement streaming statistics tracking
    ret

//
// get_visible_chunks - Get list of visible chunks for rendering
//
// Parameters:
//   x0 = output buffer pointer
//   x1 = buffer size in entries
//
// Returns:
//   x0 = number of chunks written
//
.global get_visible_chunks
get_visible_chunks:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                 // output_buffer
    mov     w20, w1                 // buffer_size
    
    // Get world state
    adrp    x0, world_state
    add     x0, x0, :lo12:world_state
    
    ldr     x1, [x0, #WorldState.visible_chunks]
    ldr     w2, [x0, #WorldState.visible_count]
    
    // Copy visible chunks to output buffer
    cmp     w2, w20
    csel    w2, w2, w20, lt         // min(visible_count, buffer_size)
    
    mov     w0, #0                  // copy_index
    
copy_visible_loop:
    cmp     w0, w2
    b.ge    copy_visible_done
    
    // Copy chunk pointer
    lsl     x3, x0, #3
    add     x4, x1, x3              // source
    add     x5, x19, x3             // dest
    ldr     x6, [x4]
    str     x6, [x5]
    
    add     w0, w0, #1
    b       copy_visible_loop
    
copy_visible_done:
    mov     x0, x2                  // Return count
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// schedule_lod_updates - Smart LOD-based update scheduling
//
// Distributes chunk updates over multiple frames to maintain performance
// Uses round-robin scheduling for different LOD levels
//
.global schedule_lod_updates
schedule_lod_updates:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    // Get current tick
    bl      simulation_get_tick_count
    mov     x19, x0                 // current_tick
    
    // Get world state
    adrp    x20, world_state
    add     x20, x20, :lo12:world_state
    
    // Store current schedule tick
    str     x19, [x20, #WorldState.lod_schedule_tick]
    
    // Schedule near LOD updates (every frame)
    bl      schedule_near_lod_updates
    
    // Schedule medium LOD updates (every 4 frames)
    and     x0, x19, #3             // tick % 4
    cbnz    x0, skip_medium_lod
    bl      schedule_medium_lod_updates
skip_medium_lod:
    
    // Schedule far LOD updates (every 16 frames)
    and     x0, x19, #15            // tick % 16
    cbnz    x0, skip_far_lod
    bl      schedule_far_lod_updates
skip_far_lod:
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// schedule_near_lod_updates - Schedule updates for near LOD chunks
//
schedule_near_lod_updates:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    // Get world state (x20 preserved from caller)
    mov     x19, x20
    
    // Clear near update queue
    str     wzr, [x19, #WorldState.queue_size_near]
    
    // Get active chunks
    ldr     x20, [x19, #WorldState.active_chunks]
    ldr     w0, [x19, #WorldState.active_count]
    
    mov     w1, #0                  // chunk_index
    
near_schedule_loop:
    cmp     w1, w0
    b.ge    near_schedule_done
    
    // Get chunk pointer
    lsl     x2, x1, #3
    add     x2, x20, x2
    ldr     x2, [x2]
    
    // Check if near LOD
    ldr     w3, [x2, #Chunk.lod_level]
    cmp     w3, #LOD_NEAR
    b.ne    next_near_chunk
    
    // Add to near update queue
    bl      add_to_near_queue
    
next_near_chunk:
    add     w1, w1, #1
    b       near_schedule_loop
    
near_schedule_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// schedule_medium_lod_updates - Schedule updates for medium LOD chunks
//
schedule_medium_lod_updates:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x20                // world_state
    
    // Clear medium update queue
    str     wzr, [x19, #WorldState.queue_size_medium]
    
    // Get active chunks
    ldr     x20, [x19, #WorldState.active_chunks]
    ldr     w0, [x19, #WorldState.active_count]
    
    mov     w1, #0                  // chunk_index
    
medium_schedule_loop:
    cmp     w1, w0
    b.ge    medium_schedule_done
    
    // Get chunk pointer
    lsl     x2, x1, #3
    add     x2, x20, x2
    ldr     x2, [x2]
    
    // Check if medium LOD
    ldr     w3, [x2, #Chunk.lod_level]
    cmp     w3, #LOD_MEDIUM
    b.ne    next_medium_chunk
    
    // Add to medium update queue
    bl      add_to_medium_queue
    
next_medium_chunk:
    add     w1, w1, #1
    b       medium_schedule_loop
    
medium_schedule_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// schedule_far_lod_updates - Schedule updates for far LOD chunks
//
schedule_far_lod_updates:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x20                // world_state
    
    // Clear far update queue
    str     wzr, [x19, #WorldState.queue_size_far]
    
    // Get active chunks
    ldr     x20, [x19, #WorldState.active_chunks]
    ldr     w0, [x19, #WorldState.active_count]
    
    mov     w1, #0                  // chunk_index
    
far_schedule_loop:
    cmp     w1, w0
    b.ge    far_schedule_done
    
    // Get chunk pointer
    lsl     x2, x1, #3
    add     x2, x20, x2
    ldr     x2, [x2]
    
    // Check if far LOD
    ldr     w3, [x2, #Chunk.lod_level]
    cmp     w3, #LOD_FAR
    b.ne    next_far_chunk
    
    // Add to far update queue
    bl      add_to_far_queue
    
next_far_chunk:
    add     w1, w1, #1
    b       far_schedule_loop
    
far_schedule_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// add_to_near_queue - Add chunk to near LOD update queue
//
// Parameters:
//   x2 = chunk pointer
//   x19 = world state pointer
//
add_to_near_queue:
    // Get current queue size
    ldr     w3, [x19, #WorldState.queue_size_near]
    ldr     w4, [x19, #WorldState.queue_capacity]
    cmp     w3, w4
    b.ge    add_near_queue_full
    
    // Add to queue
    ldr     x4, [x19, #WorldState.update_queue_near]
    lsl     x5, x3, #3              // * 8 (pointer size)
    add     x5, x4, x5
    str     x2, [x5]
    
    // Increment size
    add     w3, w3, #1
    str     w3, [x19, #WorldState.queue_size_near]
    
add_near_queue_full:
    ret

//
// add_to_medium_queue - Add chunk to medium LOD update queue
//
add_to_medium_queue:
    // Get current queue size
    ldr     w3, [x19, #WorldState.queue_size_medium]
    ldr     w4, [x19, #WorldState.queue_capacity]
    cmp     w3, w4
    b.ge    add_medium_queue_full
    
    // Add to queue
    ldr     x4, [x19, #WorldState.update_queue_medium]
    lsl     x5, x3, #3              // * 8 (pointer size)
    add     x5, x4, x5
    str     x2, [x5]
    
    // Increment size
    add     w3, w3, #1
    str     w3, [x19, #WorldState.queue_size_medium]
    
add_medium_queue_full:
    ret

//
// add_to_far_queue - Add chunk to far LOD update queue
//
add_to_far_queue:
    // Get current queue size
    ldr     w3, [x19, #WorldState.queue_size_far]
    ldr     w4, [x19, #WorldState.queue_capacity]
    cmp     w3, w4
    b.ge    add_far_queue_full
    
    // Add to queue
    ldr     x4, [x19, #WorldState.update_queue_far]
    lsl     x5, x3, #3              // * 8 (pointer size)
    add     x5, x4, x5
    str     x2, [x5]
    
    // Increment size
    add     w3, w3, #1
    str     w3, [x19, #WorldState.queue_size_far]
    
add_far_queue_full:
    ret

//
// process_scheduled_updates - Process chunks from LOD update queues
//
.global process_scheduled_updates
process_scheduled_updates:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    // Get world state
    adrp    x19, world_state
    add     x19, x19, :lo12:world_state
    
    // Process near LOD queue
    bl      process_near_lod_queue
    
    // Process medium LOD queue
    bl      process_medium_lod_queue
    
    // Process far LOD queue
    bl      process_far_lod_queue
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// process_near_lod_queue - Process all chunks in near LOD queue
//
process_near_lod_queue:
    stp     x29, x30, [sp, #-32]!
    stp     x20, x21, [sp, #16]
    mov     x29, sp
    
    ldr     x20, [x19, #WorldState.update_queue_near]
    ldr     w21, [x19, #WorldState.queue_size_near]
    
    mov     w0, #0                  // queue_index
    
process_near_loop:
    cmp     w0, w21
    b.ge    process_near_done
    
    // Get chunk pointer
    lsl     x1, x0, #3
    add     x1, x20, x1
    ldr     x1, [x1]
    
    // Update chunk
    mov     x0, x1
    bl      update_single_chunk
    
    add     w0, w0, #1
    b       process_near_loop
    
process_near_done:
    ldp     x20, x21, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// process_medium_lod_queue - Process chunks in medium LOD queue
//
process_medium_lod_queue:
    stp     x29, x30, [sp, #-32]!
    stp     x20, x21, [sp, #16]
    mov     x29, sp
    
    ldr     x20, [x19, #WorldState.update_queue_medium]
    ldr     w21, [x19, #WorldState.queue_size_medium]
    
    mov     w0, #0                  // queue_index
    
process_medium_loop:
    cmp     w0, w21
    b.ge    process_medium_done
    
    // Get chunk pointer
    lsl     x1, x0, #3
    add     x1, x20, x1
    ldr     x1, [x1]
    
    // Update chunk
    mov     x0, x1
    bl      update_single_chunk
    
    add     w0, w0, #1
    b       process_medium_loop
    
process_medium_done:
    ldp     x20, x21, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// process_far_lod_queue - Process chunks in far LOD queue
//
process_far_lod_queue:
    stp     x29, x30, [sp, #-32]!
    stp     x20, x21, [sp, #16]
    mov     x29, sp
    
    ldr     x20, [x19, #WorldState.update_queue_far]
    ldr     w21, [x19, #WorldState.queue_size_far]
    
    mov     w0, #0                  // queue_index
    
process_far_loop:
    cmp     w0, w21
    b.ge    process_far_done
    
    // Get chunk pointer
    lsl     x1, x0, #3
    add     x1, x20, x1
    ldr     x1, [x1]
    
    // Update chunk
    mov     x0, x1
    bl      update_single_chunk
    
    add     w0, w0, #1
    b       process_far_loop
    
process_far_done:
    ldp     x20, x21, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// SIMD optimized tile processing functions
//

//
// update_tiles_simd - SIMD optimized tile batch updates  
//
// Parameters:
//   x0 = tile array pointer
//   x1 = tile count (must be multiple of 4)
//
.global update_tiles_simd
update_tiles_simd:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                 // tile_array
    mov     x20, x1                 // tile_count
    
    // Check alignment and count
    and     x0, x20, #3
    cbnz    x0, update_tiles_scalar // Fall back if not multiple of 4
    
    // NEON registers for parallel processing
    // v0-v3: tile data vectors
    // v4-v7: calculation vectors
    
    mov     x0, #0                  // tile_index
    
update_tiles_simd_loop:
    cmp     x0, x20
    b.ge    update_tiles_simd_done
    
    // Load 4 tiles worth of population data (16-bit values)
    add     x1, x19, x0, lsl #6     // tiles * 64 bytes per tile
    add     x1, x1, #Tile.population
    ld1     {v0.4h}, [x1]          // Load 4 population values
    
    // Load happiness data
    add     x1, x19, x0, lsl #6
    add     x1, x1, #Tile.happiness
    ld1     {v1.4h}, [x1]          // Load 4 happiness values
    
    // Load land value data
    add     x1, x19, x0, lsl #6
    add     x1, x1, #Tile.land_value
    ld1     {v2.s}, [x1]           // Load 4 land values (32-bit)
    
    // Parallel calculations
    // Happiness affects population growth
    mov     w2, #128               // Happiness threshold
    dup     v4.4h, w2
    cmhi    v5.4h, v1.4h, v4.4h    // happiness > 128
    
    // Population growth factor (simplified)
    mov     w2, #2
    dup     v6.4h, w2
    and     v7.8b, v5.8b, v6.8b    // Growth factor based on happiness
    
    // Apply growth to population (saturating add)
    uqadd   v0.4h, v0.4h, v7.4h
    
    // Store updated population
    add     x1, x19, x0, lsl #6
    add     x1, x1, #Tile.population
    st1     {v0.4h}, [x1]
    
    // Update tax revenue based on population and land value
    // Convert population to 32-bit for multiplication
    ushll   v8.4s, v0.4h, #0       // Zero-extend population to 32-bit
    
    // Tax rate calculation (population * land_value * tax_rate / 1000)
    mov     w2, #10                 // 1% tax rate
    dup     v9.4s, w2
    mul     v10.4s, v8.4s, v2.4s   // population * land_value
    mul     v10.4s, v10.4s, v9.4s  // * tax_rate
    
    // Divide by 1000 (approximate with shift)
    ushr    v10.4s, v10.4s, #10    // Divide by 1024 (close to 1000)
    
    // Store tax revenue (convert back to 16-bit)
    uqxtn   v11.4h, v10.4s
    add     x1, x19, x0, lsl #6
    add     x1, x1, #Tile.tax_revenue
    st1     {v11.4h}, [x1]
    
    add     x0, x0, #4             // Process next 4 tiles
    b       update_tiles_simd_loop
    
update_tiles_simd_done:
    mov     x0, #0                  // Success
    b       update_tiles_exit
    
update_tiles_scalar:
    // Fall back to scalar processing
    mov     x0, #0                  // tile_index
    
update_tiles_scalar_loop:
    cmp     x0, x20
    b.ge    update_tiles_simd_done
    
    // Process single tile
    add     x1, x19, x0, lsl #6     // tile address
    bl      update_single_tile_scalar
    
    add     x0, x0, #1
    b       update_tiles_scalar_loop
    
update_tiles_exit:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// update_single_tile_scalar - Scalar version of tile update
//
// Parameters:
//   x1 = tile pointer
//
update_single_tile_scalar:
    // Simple scalar implementation
    ldrh    w2, [x1, #Tile.population]
    ldrh    w3, [x1, #Tile.happiness]
    
    // Growth based on happiness
    cmp     w3, #128
    add.hi  w2, w2, #1              // Conditional increment
    
    // Cap population
    mov     w4, #MAX_TILE_POPULATION
    cmp     w2, w4
    csel    w2, w2, w4, lt
    
    strh    w2, [x1, #Tile.population]
    ret

//
// calculate_chunk_stats_simd - SIMD optimized chunk statistics
//
// Parameters:
//   x0 = chunk pointer
//
.global calculate_chunk_stats_simd
calculate_chunk_stats_simd:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                 // chunk_ptr
    
    // Initialize accumulator vectors
    movi    v16.4s, #0              // Population accumulator
    movi    v17.4s, #0              // Jobs accumulator 
    movi    v18.4s, #0              // Tax revenue accumulator
    
    add     x20, x19, #Chunk.tiles  // tiles_ptr
    mov     x0, #0                  // tile_index
    
chunk_stats_simd_loop:
    cmp     x0, #TILES_PER_CHUNK
    b.ge    chunk_stats_simd_done
    
    // Process 4 tiles at once
    add     x1, x20, x0, lsl #6     // tile address
    
    // Load population data (4 tiles)
    add     x2, x1, #Tile.population
    ld4     {v0.h, v1.h, v2.h, v3.h}[0], [x2], #64
    ld4     {v0.h, v1.h, v2.h, v3.h}[1], [x2], #64  
    ld4     {v0.h, v1.h, v2.h, v3.h}[2], [x2], #64
    ld4     {v0.h, v1.h, v2.h, v3.h}[3], [x2]
    
    // Extend to 32-bit and accumulate
    ushll   v4.4s, v0.4h, #0       // Population
    add     v16.4s, v16.4s, v4.4s
    
    ushll   v5.4s, v1.4h, #0       // Jobs
    add     v17.4s, v17.4s, v5.4s
    
    ushll   v6.4s, v2.4h, #0       // Tax revenue
    add     v18.4s, v18.4s, v6.4s
    
    add     x0, x0, #4
    b       chunk_stats_simd_loop
    
chunk_stats_simd_done:
    // Horizontal add to get final sums
    addv    s16, v16.4s             // Sum population
    addv    s17, v17.4s             // Sum jobs
    addv    s18, v18.4s             // Sum tax revenue
    
    // Store results in chunk
    fmov    w0, s16
    str     w0, [x19, #Chunk.total_population]
    
    fmov    w0, s17
    str     w0, [x19, #Chunk.total_jobs]
    
    fmov    w0, s18
    str     w0, [x19, #Chunk.tax_revenue]
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// memcpy_simd - SIMD optimized memory copy
//
// Parameters:
//   x0 = destination pointer
//   x1 = source pointer
//   x2 = number of bytes
//
.global memcpy_simd
memcpy_simd:
    // Check alignment and size for SIMD optimization
    cmp     x2, #64
    b.lt    memcpy_scalar
    
    // Check 16-byte alignment
    orr     x3, x0, x1
    and     x3, x3, #15
    cbnz    x3, memcpy_scalar
    
    // SIMD copy in 64-byte chunks
    mov     x3, x2
    lsr     x3, x3, #6              // Number of 64-byte chunks
    
memcpy_simd_loop:
    cbz     x3, memcpy_simd_remainder
    
    ld1     {v0.16b, v1.16b, v2.16b, v3.16b}, [x1], #64
    st1     {v0.16b, v1.16b, v2.16b, v3.16b}, [x0], #64
    
    sub     x3, x3, #1
    b       memcpy_simd_loop
    
memcpy_simd_remainder:
    // Handle remaining bytes
    and     x2, x2, #63
    
memcpy_scalar:
    cbz     x2, memcpy_simd_done
    
memcpy_scalar_loop:
    ldrb    w3, [x1], #1
    strb    w3, [x0], #1
    subs    x2, x2, #1
    b.ne    memcpy_scalar_loop
    
memcpy_simd_done:
    ret

// External function declarations
.extern get_current_time_ns
.extern simulation_get_tick_count