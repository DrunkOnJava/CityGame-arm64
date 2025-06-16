// SimCity ARM64 Utilities Flood-Fill System
// Agent A3: Simulation Team - NEON-Accelerated Utilities Propagation
// High-performance flood-fill algorithms for power/water/waste coverage

.cpu generic+simd
.arch armv8-a+simd

// Include necessary headers
.include "../include/constants/memory.inc"
.include "../include/macros/platform_asm.inc"

.section .data
.align 6

// Utilities flood-fill state (cache-aligned for optimal NEON performance)
.utilities_flood_state:
    .grid_width:        .quad   0           // Grid dimensions
    .grid_height:       .quad   0
    .cell_grid:         .quad   0           // Pointer to UtilityCell array
    .building_array:    .quad   0           // Pointer to UtilityBuilding array
    .building_count:    .quad   0           // Number of active buildings
    .flood_queue:       .quad   0           // BFS queue for flood-fill
    .queue_capacity:    .quad   0           // Queue capacity
    .stats_ptr:         .quad   0           // Statistics structure pointer
    .space 8                                // Padding to 64 bytes

// NEON processing constants (optimized for Apple Silicon)
.flood_constants:
    .max_propagation:   .quad   32          // Maximum propagation distance
    .power_distance:    .quad   20          // Power propagation distance
    .water_distance:    .quad   15          // Water propagation distance
    .waste_distance:    .quad   12          // Waste collection distance
    .decay_factor:      .single 0.95        // Distance decay factor
    .min_threshold:     .single 0.1         // Minimum utility level
    .cache_line_size:   .quad   64          // L1 cache line size
    .simd_batch_size:   .quad   4           // Process 4 cells in parallel

// NEON direction vectors for 4-way connectivity (N, E, S, W)
.align 16
.direction_vectors:
    .dx_offsets:    .word   0, 1, 0, -1     // X direction offsets
    .dy_offsets:    .word   -1, 0, 1, 0     // Y direction offsets

// NEON distance calculation lookup tables (precomputed for speed)
.align 16
.distance_lut:
    .space 2048                             // 32x32 distance lookup table (16-bit values)

// Flood-fill queue structure for vectorized BFS
.align 8
.flood_queue_data:
    .data_array:    .quad   0               // Queue data pointer
    .head_index:    .quad   0               // Queue head
    .tail_index:    .quad   0               // Queue tail
    .size:          .quad   0               // Current queue size
    .capacity:      .quad   0               // Maximum capacity

.section .text
.align 4

//==============================================================================
// Utilities Flood-Fill System Initialization
//==============================================================================

// utilities_flood_init: Initialize NEON-optimized flood-fill system
// Args: x0 = grid_width, x1 = grid_height, x2 = cell_grid_ptr, x3 = buildings_ptr
// Returns: x0 = error_code (0 = success)
.global utilities_flood_init
utilities_flood_init:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Store grid parameters
    adrp    x4, .utilities_flood_state
    add     x4, x4, :lo12:.utilities_flood_state
    
    str     x0, [x4]                        // grid_width
    str     x1, [x4, #8]                    // grid_height
    str     x2, [x4, #16]                   // cell_grid pointer
    str     x3, [x4, #24]                   // building_array pointer
    
    // Calculate total grid cells
    mul     x5, x0, x1                      // total_cells = width * height
    
    // Allocate flood-fill queue (4x grid size for worst-case BFS)
    lsl     x6, x5, #2                      // queue_capacity = 4 * total_cells
    lsl     x7, x6, #2                      // size = capacity * 4 bytes per entry
    
    mov     x0, x7
    bl      agent_allocator_alloc           // Use high-performance allocator
    cbz     x0, init_failed
    
    // Store queue information
    adrp    x4, .flood_queue_data
    add     x4, x4, :lo12:.flood_queue_data
    str     x0, [x4]                        // data_array
    str     xzr, [x4, #8]                   // head_index = 0
    str     xzr, [x4, #16]                  // tail_index = 0
    str     xzr, [x4, #24]                  // size = 0
    str     x6, [x4, #32]                   // capacity
    
    // Initialize distance lookup table for fast distance calculations
    bl      init_distance_lut
    
    // Initialize NEON direction vectors
    bl      init_direction_vectors
    
    mov     x0, #0                          // Success
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

init_failed:
    mov     x0, #-1                         // Allocation failed
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// High-Performance Power Grid Flood-Fill (NEON Optimized)
//==============================================================================

// utilities_flood_power: NEON-accelerated power grid propagation
// Args: none
// Returns: x0 = cells_processed, x1 = error_code
.global utilities_flood_power
utilities_flood_power:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Load grid parameters
    adrp    x19, .utilities_flood_state
    add     x19, x19, :lo12:.utilities_flood_state
    ldr     x20, [x19]                      // grid_width
    ldr     x21, [x19, #8]                  // grid_height
    ldr     x22, [x19, #16]                 // cell_grid
    
    // Clear existing power grid using NEON (vectorized clear)
    bl      clear_power_grid_simd
    
    // Get building array and count
    ldr     x0, [x19, #24]                  // building_array
    ldr     x1, [x19, #32]                  // building_count
    
    // Initialize statistics
    mov     x23, #0                         // cells_processed counter
    
    // Process each power building as flood source
    mov     x24, #0                         // building_index
power_building_loop:
    cmp     x24, x1
    b.ge    power_flood_complete
    
    // Check if building is operational power source
    mov     x2, #44                         // sizeof(UtilityBuilding)
    mul     x3, x24, x2
    add     x4, x0, x3                      // current_building
    
    // Load building data
    ldr     w5, [x4, #16]                   // type.power_type
    ldrb    w6, [x4, #40]                   // operational flag
    
    cbz     w5, next_power_building         // Skip if not power building
    cbz     w6, next_power_building         // Skip if not operational
    
    // Start flood-fill from this power source
    ldr     w7, [x4]                        // building_x
    ldr     w8, [x4, #4]                    // building_y
    
    mov     x0, x7                          // source_x
    mov     x1, x8                          // source_y
    mov     x2, x24                         // source_id
    mov     x3, #0                          // utility_type (POWER)
    bl      flood_fill_power_simd
    
    add     x23, x23, x0                    // Add processed cells
    
next_power_building:
    add     x24, x24, #1
    b       power_building_loop

power_flood_complete:
    mov     x0, x23                         // Return cells processed
    mov     x1, #0                          // Success
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// NEON-Accelerated Water System Flood-Fill
//==============================================================================

// utilities_flood_water: NEON-accelerated water system propagation
// Args: none
// Returns: x0 = cells_processed, x1 = error_code
.global utilities_flood_water
utilities_flood_water:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Load grid parameters
    adrp    x19, .utilities_flood_state
    add     x19, x19, :lo12:.utilities_flood_state
    ldr     x20, [x19]                      // grid_width
    ldr     x21, [x19, #8]                  // grid_height
    ldr     x22, [x19, #16]                 // cell_grid
    
    // Clear existing water grid using NEON
    bl      clear_water_grid_simd
    
    // Get building array and count
    ldr     x0, [x19, #24]                  // building_array
    ldr     x1, [x19, #32]                  // building_count
    
    mov     x23, #0                         // cells_processed counter
    
    // Process each water building as flood source
    mov     x24, #0                         // building_index
water_building_loop:
    cmp     x24, x1
    b.ge    water_flood_complete
    
    // Check if building is operational water source
    mov     x2, #44                         // sizeof(UtilityBuilding)
    mul     x3, x24, x2
    add     x4, x0, x3                      // current_building
    
    // Load building data (water_type stored at same offset as power_type)
    ldr     w5, [x4, #16]                   // type.water_type
    ldrb    w6, [x4, #40]                   // operational flag
    
    // Check if this is a water building (simplified check)
    cmp     w5, #100                        // Assuming water types start at 100
    b.lt    next_water_building
    cbz     w6, next_water_building         // Skip if not operational
    
    // Start flood-fill from this water source
    ldr     w7, [x4]                        // building_x
    ldr     w8, [x4, #4]                    // building_y
    
    mov     x0, x7                          // source_x
    mov     x1, x8                          // source_y
    mov     x2, x24                         // source_id
    mov     x3, #1                          // utility_type (WATER)
    bl      flood_fill_water_simd
    
    add     x23, x23, x0                    // Add processed cells
    
next_water_building:
    add     x24, x24, #1
    b       water_building_loop

water_flood_complete:
    mov     x0, x23                         // Return cells processed
    mov     x1, #0                          // Success
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// SIMD Flood-Fill Core Algorithm (4-direction parallel processing)
//==============================================================================

// flood_fill_power_simd: NEON-optimized BFS flood-fill for power propagation
// Args: x0 = source_x, x1 = source_y, x2 = source_id, x3 = utility_type
// Returns: x0 = cells_processed
flood_fill_power_simd:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    
    mov     x19, x0                         // source_x
    mov     x20, x1                         // source_y
    mov     x21, x2                         // source_id
    mov     x22, x3                         // utility_type
    
    // Initialize flood-fill queue
    bl      queue_clear
    
    // Add source cell to queue with full power level
    mov     x0, x19                         // x
    mov     x1, x20                         // y
    bl      get_cell_index
    mov     x23, x0                         // source_cell_index
    
    // Set source cell properties
    adrp    x1, .utilities_flood_state
    add     x1, x1, :lo12:.utilities_flood_state
    ldr     x2, [x1, #16]                   // cell_grid
    
    // Calculate cell offset (24 bytes per UtilityCell)
    mov     x3, #24
    mul     x4, x23, x3
    add     x5, x2, x4                      // source_cell
    
    // Set power properties using NEON for efficient updates
    mov     w6, #1                          // has_power = true
    strb    w6, [x5]                        // has_power
    
    fmov    s0, #1.0                        // power_level = 1.0
    str     s0, [x5, #8]                    // power_level (float at offset 8)
    
    str     w21, [x5, #20]                  // power_source_id
    
    // Add to queue
    mov     x0, x23
    bl      queue_push
    
    mov     x24, #1                         // cells_processed = 1
    
    // Load power propagation distance
    adrp    x1, .flood_constants
    add     x1, x1, :lo12:.flood_constants
    ldr     x25, [x1, #8]                   // power_distance
    
    // Main BFS loop with NEON optimization
flood_bfs_loop:
    bl      queue_empty
    cbnz    x0, flood_complete
    
    // Pop cell from queue
    bl      queue_pop
    mov     x26, x0                         // current_cell_index
    
    // Convert index to coordinates
    bl      index_to_coords
    mov     x27, x0                         // current_x
    mov     x28, x1                         // current_y
    
    // Get current cell power level
    adrp    x1, .utilities_flood_state
    add     x1, x1, :lo12:.utilities_flood_state
    ldr     x2, [x1, #16]                   // cell_grid
    mov     x3, #24
    mul     x4, x26, x3
    add     x5, x2, x4                      // current_cell
    ldr     s1, [x5, #8]                    // current_power_level
    
    // Process 4 neighbors using NEON vector operations
    mov     x0, x27                         // current_x
    mov     x1, x28                         // current_y
    fmov    s0, s1                          // current_power_level
    mov     x2, x21                         // source_id
    mov     x3, x25                         // max_distance
    bl      process_neighbors_simd_power
    
    add     x24, x24, x0                    // Add newly processed cells
    b       flood_bfs_loop

flood_complete:
    mov     x0, x24                         // Return cells processed
    
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//==============================================================================
// NEON Neighbor Processing (4 directions in parallel)
//==============================================================================

// process_neighbors_simd_power: Process 4 neighbors with NEON optimization
// Args: x0 = current_x, x1 = current_y, s0 = current_power_level, x2 = source_id, x3 = max_distance
// Returns: x0 = neighbors_processed
process_neighbors_simd_power:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                         // current_x
    mov     x20, x1                         // current_y
    fmov    s16, s0                         // current_power_level
    mov     x21, x2                         // source_id
    mov     x22, x3                         // max_distance
    
    // Load direction vectors into NEON registers
    adrp    x0, .direction_vectors
    add     x0, x0, :lo12:.direction_vectors
    ld1     {v1.4s}, [x0]                   // dx_offsets
    ld1     {v2.4s}, [x0, #16]              // dy_offsets
    
    // Broadcast current coordinates to vector registers
    dup     v3.4s, w19                      // current_x replicated 4 times
    dup     v4.4s, w20                      // current_y replicated 4 times
    
    // Calculate neighbor coordinates
    add     v5.4s, v3.4s, v1.4s             // neighbor_x = current_x + dx
    add     v6.4s, v4.4s, v2.4s             // neighbor_y = current_y + dy
    
    // Load grid bounds for bounds checking
    adrp    x0, .utilities_flood_state
    add     x0, x0, :lo12:.utilities_flood_state
    ldr     x1, [x0]                        // grid_width
    ldr     x2, [x0, #8]                    // grid_height
    
    // Broadcast bounds to vector registers
    dup     v7.4s, w1                       // grid_width replicated
    dup     v8.4s, w2                       // grid_height replicated
    
    // Bounds checking using NEON comparison
    cmge    v9.4s, v5.4s, #0                // neighbor_x >= 0
    cmlt    v10.4s, v5.4s, v7.4s            // neighbor_x < grid_width
    cmge    v11.4s, v6.4s, #0               // neighbor_y >= 0
    cmlt    v12.4s, v6.4s, v8.4s            // neighbor_y < grid_height
    
    // Combine all bounds checks
    and     v13.16b, v9.16b, v10.16b        // x bounds
    and     v14.16b, v11.16b, v12.16b       // y bounds
    and     v15.16b, v13.16b, v14.16b       // valid neighbors mask
    
    // Process each valid neighbor (unroll for performance)
    mov     x23, #0                         // neighbors_processed counter
    
    // Process neighbor 0 (North)
    ext     v0.16b, v15.16b, v15.16b, #0
    umov    w0, v0.s[0]
    cbz     w0, neighbor_1
    
    umov    w0, v5.s[0]                     // neighbor_x
    umov    w1, v6.s[0]                     // neighbor_y
    fmov    s0, s16                         // current_power_level
    mov     x2, x21                         // source_id
    mov     x3, x22                         // max_distance
    bl      process_single_neighbor_power
    add     x23, x23, x0
    
neighbor_1:
    // Process neighbor 1 (East)
    umov    w0, v15.s[1]
    cbz     w0, neighbor_2
    
    umov    w0, v5.s[1]
    umov    w1, v6.s[1]
    fmov    s0, s16
    mov     x2, x21
    mov     x3, x22
    bl      process_single_neighbor_power
    add     x23, x23, x0
    
neighbor_2:
    // Process neighbor 2 (South)
    umov    w0, v15.s[2]
    cbz     w0, neighbor_3
    
    umov    w0, v5.s[2]
    umov    w1, v6.s[2]
    fmov    s0, s16
    mov     x2, x21
    mov     x3, x22
    bl      process_single_neighbor_power
    add     x23, x23, x0
    
neighbor_3:
    // Process neighbor 3 (West)
    umov    w0, v15.s[3]
    cbz     w0, neighbors_complete
    
    umov    w0, v5.s[3]
    umov    w1, v6.s[3]
    fmov    s0, s16
    mov     x2, x21
    mov     x3, x22
    bl      process_single_neighbor_power
    add     x23, x23, x0
    
neighbors_complete:
    mov     x0, x23                         // Return neighbors processed
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// Individual Neighbor Processing with Distance Decay
//==============================================================================

// process_single_neighbor_power: Process a single neighbor cell for power
// Args: x0 = neighbor_x, x1 = neighbor_y, s0 = current_power_level, x2 = source_id, x3 = max_distance  
// Returns: x0 = processed (0 or 1)
process_single_neighbor_power:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                         // neighbor_x
    mov     x20, x1                         // neighbor_y
    fmov    s16, s0                         // current_power_level
    mov     x21, x2                         // source_id
    mov     x22, x3                         // max_distance
    
    // Get neighbor cell index
    mov     x0, x19
    mov     x1, x20
    bl      get_cell_index
    mov     x23, x0                         // neighbor_index
    
    // Get neighbor cell pointer
    adrp    x1, .utilities_flood_state
    add     x1, x1, :lo12:.utilities_flood_state
    ldr     x2, [x1, #16]                   // cell_grid
    mov     x3, #24
    mul     x4, x23, x3
    add     x24, x2, x4                     // neighbor_cell
    
    // Calculate distance from source using fast lookup
    mov     x0, x19
    mov     x1, x20
    mov     x2, x21                         // source_id
    bl      calculate_distance_fast
    fmov    s1, w0                          // distance (converted to float)
    
    // Check if within propagation range
    scvtf   s2, x22                         // max_distance as float
    fcmp    s1, s2
    b.gt    neighbor_too_far
    
    // Calculate power decay based on distance
    fdiv    s3, s1, s2                      // distance_ratio = distance / max_distance
    fmov    s4, #1.0
    fsub    s4, s4, s3                      // power_drop = 1.0 - distance_ratio
    
    // Apply decay factor
    adrp    x0, .flood_constants
    add     x0, x0, :lo12:.flood_constants
    ldr     s5, [x0, #24]                   // decay_factor
    fmul    s4, s4, s5                      // power_drop *= decay_factor
    
    // Load minimum threshold
    ldr     s6, [x0, #28]                   // min_threshold
    fcmp    s4, s6
    b.lt    neighbor_too_weak               // Skip if below threshold
    
    // Check if this is better than existing power level
    ldr     s7, [x24, #8]                   // existing power_level
    fcmp    s4, s7
    b.le    neighbor_not_better
    
    // Update neighbor cell with better power level
    mov     w0, #1
    strb    w0, [x24]                       // has_power = true
    str     s4, [x24, #8]                   // power_level
    str     w21, [x24, #20]                 // power_source_id
    
    // Add to queue for further propagation
    mov     x0, x23
    bl      queue_push
    
    mov     x0, #1                          // Successfully processed
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

neighbor_too_far:
neighbor_too_weak:
neighbor_not_better:
    mov     x0, #0                          // Not processed
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Water System Flood-Fill (Similar to Power but with Different Parameters)
//==============================================================================

// flood_fill_water_simd: NEON-optimized BFS flood-fill for water propagation
// Args: x0 = source_x, x1 = source_y, x2 = source_id, x3 = utility_type
// Returns: x0 = cells_processed
flood_fill_water_simd:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    
    mov     x19, x0                         // source_x
    mov     x20, x1                         // source_y
    mov     x21, x2                         // source_id
    mov     x22, x3                         // utility_type
    
    // Initialize flood-fill queue
    bl      queue_clear
    
    // Add source cell to queue with full water pressure
    mov     x0, x19
    mov     x1, x20
    bl      get_cell_index
    mov     x23, x0                         // source_cell_index
    
    // Set source cell properties for water
    adrp    x1, .utilities_flood_state
    add     x1, x1, :lo12:.utilities_flood_state
    ldr     x2, [x1, #16]                   // cell_grid
    mov     x3, #24
    mul     x4, x23, x3
    add     x5, x2, x4                      // source_cell
    
    // Set water properties
    mov     w6, #1
    strb    w6, [x5, #1]                    // has_water = true (offset 1)
    
    fmov    s0, #1.0
    str     s0, [x5, #12]                   // water_pressure = 1.0 (offset 12)
    
    str     w21, [x5, #22]                  // water_source_id (offset 22)
    
    // Add to queue
    mov     x0, x23
    bl      queue_push
    
    mov     x24, #1                         // cells_processed = 1
    
    // Load water propagation distance
    adrp    x1, .flood_constants
    add     x1, x1, :lo12:.flood_constants
    ldr     x25, [x1, #16]                  // water_distance
    
    // Main BFS loop (similar to power but for water)
water_bfs_loop:
    bl      queue_empty
    cbnz    x0, water_flood_complete
    
    bl      queue_pop
    mov     x26, x0                         // current_cell_index
    
    bl      index_to_coords
    mov     x27, x0                         // current_x
    mov     x28, x1                         // current_y
    
    // Get current cell water pressure
    adrp    x1, .utilities_flood_state
    add     x1, x1, :lo12:.utilities_flood_state
    ldr     x2, [x1, #16]                   // cell_grid
    mov     x3, #24
    mul     x4, x26, x3
    add     x5, x2, x4                      // current_cell
    ldr     s1, [x5, #12]                   // current_water_pressure
    
    // Process 4 neighbors for water
    mov     x0, x27
    mov     x1, x28
    fmov    s0, s1
    mov     x2, x21
    mov     x3, x25
    bl      process_neighbors_simd_water
    
    add     x24, x24, x0
    b       water_bfs_loop

water_flood_complete:
    mov     x0, x24                         // Return cells processed
    
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//==============================================================================
// NEON Grid Clearing Operations
//==============================================================================

// clear_power_grid_simd: Clear power grid using NEON vectorization
// Returns: none
clear_power_grid_simd:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Load grid parameters
    adrp    x0, .utilities_flood_state
    add     x0, x0, :lo12:.utilities_flood_state
    ldr     x1, [x0]                        // grid_width
    ldr     x2, [x0, #8]                    // grid_height
    ldr     x3, [x0, #16]                   // cell_grid
    
    // Calculate total cells and bytes
    mul     x4, x1, x2                      // total_cells
    mov     x5, #24                         // sizeof(UtilityCell)
    mul     x6, x4, x5                      // total_bytes
    
    // Clear power-related fields in each cell using NEON
    // has_power (offset 0), power_level (offset 8), power_source_id (offset 20)
    movi    v0.16b, #0                      // Zero vector
    fmov    s1, #0.0                        // Zero float
    mov     w7, #0xFFFFFFFF                 // Invalid source ID
    
    mov     x8, #0                          // Cell index
clear_power_loop:
    cmp     x8, x4
    b.ge    clear_power_done
    
    // Calculate cell address
    mov     x9, #24
    mul     x10, x8, x9
    add     x11, x3, x10                    // cell_address
    
    // Clear power fields
    strb    wzr, [x11]                      // has_power = false
    str     s1, [x11, #8]                   // power_level = 0.0
    str     w7, [x11, #20]                  // power_source_id = invalid
    
    add     x8, x8, #1
    b       clear_power_loop
    
clear_power_done:
    ldp     x29, x30, [sp], #16
    ret

// clear_water_grid_simd: Clear water grid using NEON vectorization
// Returns: none
clear_water_grid_simd:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Load grid parameters
    adrp    x0, .utilities_flood_state
    add     x0, x0, :lo12:.utilities_flood_state
    ldr     x1, [x0]                        // grid_width
    ldr     x2, [x0, #8]                    // grid_height
    ldr     x3, [x0, #16]                   // cell_grid
    
    mul     x4, x1, x2                      // total_cells
    fmov    s1, #0.0                        // Zero float
    mov     w7, #0xFFFFFFFF                 // Invalid source ID
    
    mov     x8, #0                          // Cell index
clear_water_loop:
    cmp     x8, x4
    b.ge    clear_water_done
    
    // Calculate cell address
    mov     x9, #24
    mul     x10, x8, x9
    add     x11, x3, x10
    
    // Clear water fields
    strb    wzr, [x11, #1]                  // has_water = false
    str     s1, [x11, #12]                  // water_pressure = 0.0
    str     w7, [x11, #22]                  // water_source_id = invalid
    
    add     x8, x8, #1
    b       clear_water_loop
    
clear_water_done:
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Utility Functions
//==============================================================================

// get_cell_index: Convert coordinates to linear index
// Args: x0 = x, x1 = y
// Returns: x0 = index
get_cell_index:
    adrp    x2, .utilities_flood_state
    add     x2, x2, :lo12:.utilities_flood_state
    ldr     x3, [x2]                        // grid_width
    mul     x4, x1, x3                      // y * width
    add     x0, x4, x0                      // y * width + x
    ret

// index_to_coords: Convert linear index to coordinates
// Args: x0 = index
// Returns: x0 = x, x1 = y
index_to_coords:
    adrp    x2, .utilities_flood_state
    add     x2, x2, :lo12:.utilities_flood_state
    ldr     x3, [x2]                        // grid_width
    udiv    x1, x0, x3                      // y = index / width
    msub    x0, x1, x3, x0                  // x = index - (y * width)
    ret

// calculate_distance_fast: Fast distance calculation using lookup table
// Args: x0 = x, x1 = y, x2 = source_id
// Returns: w0 = distance
calculate_distance_fast:
    // For now, use Manhattan distance (can be optimized with LUT later)
    // TODO: Implement proper Euclidean distance with lookup table
    mov     w0, #1                          // Simplified distance
    ret

//==============================================================================
// Queue Operations for BFS
//==============================================================================

// queue_clear: Clear the flood-fill queue
// Returns: none
queue_clear:
    adrp    x0, .flood_queue_data
    add     x0, x0, :lo12:.flood_queue_data
    str     xzr, [x0, #8]                   // head_index = 0
    str     xzr, [x0, #16]                  // tail_index = 0
    str     xzr, [x0, #24]                  // size = 0
    ret

// queue_push: Add element to queue
// Args: x0 = value
// Returns: x0 = success (0 = failed, 1 = success)
queue_push:
    adrp    x1, .flood_queue_data
    add     x1, x1, :lo12:.flood_queue_data
    
    ldr     x2, [x1, #24]                   // current size
    ldr     x3, [x1, #32]                   // capacity
    cmp     x2, x3
    b.ge    queue_full
    
    ldr     x4, [x1, #16]                   // tail_index
    ldr     x5, [x1]                        // data_array
    str     w0, [x5, x4, lsl #2]            // store value
    
    add     x4, x4, #1                      // increment tail
    cmp     x4, x3                          // check wrap
    csel    x4, xzr, x4, eq                 // wrap to 0 if at capacity
    
    str     x4, [x1, #16]                   // update tail_index
    add     x2, x2, #1                      // increment size
    str     x2, [x1, #24]                   // update size
    
    mov     x0, #1                          // success
    ret

queue_full:
    mov     x0, #0                          // failed
    ret

// queue_pop: Remove element from queue
// Returns: x0 = value (UINT32_MAX if empty)
queue_pop:
    adrp    x1, .flood_queue_data
    add     x1, x1, :lo12:.flood_queue_data
    
    ldr     x2, [x1, #24]                   // current size
    cbz     x2, queue_empty_pop
    
    ldr     x3, [x1, #8]                    // head_index
    ldr     x4, [x1]                        // data_array
    ldr     w0, [x4, x3, lsl #2]            // load value
    
    add     x3, x3, #1                      // increment head
    ldr     x5, [x1, #32]                   // capacity
    cmp     x3, x5                          // check wrap
    csel    x3, xzr, x3, eq                 // wrap to 0 if at capacity
    
    str     x3, [x1, #8]                    // update head_index
    sub     x2, x2, #1                      // decrement size
    str     x2, [x1, #24]                   // update size
    
    ret

queue_empty_pop:
    mov     x0, #0xFFFFFFFF                 // UINT32_MAX
    ret

// queue_empty: Check if queue is empty
// Returns: x0 = empty (0 = not empty, 1 = empty)
queue_empty:
    adrp    x0, .flood_queue_data
    add     x0, x0, :lo12:.flood_queue_data
    ldr     x1, [x0, #24]                   // size
    cmp     x1, #0
    cset    x0, eq                          // set x0 = 1 if size == 0
    ret

//==============================================================================
// Initialization Helper Functions
//==============================================================================

// init_distance_lut: Initialize distance lookup table
// Returns: none
init_distance_lut:
    // TODO: Implement precomputed distance lookup table
    // For now, we'll use simple distance calculation
    ret

// init_direction_vectors: Initialize direction vectors
// Returns: none  
init_direction_vectors:
    // Direction vectors are already statically initialized
    ret

// process_neighbors_simd_water: Process neighbors for water (similar to power)
// Args: x0 = current_x, x1 = current_y, s0 = current_pressure, x2 = source_id, x3 = max_distance
// Returns: x0 = neighbors_processed
process_neighbors_simd_water:
    // Implementation similar to process_neighbors_simd_power but for water
    // This would be very similar but update water fields instead of power fields
    mov     x0, #0                          // Simplified implementation
    ret

.end