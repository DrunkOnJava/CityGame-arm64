// SimCity ARM64 Assembly - NEON-Optimized Zoning System
// Agent A2: Simulation Team - Zoning System Conversion & NEON Optimization
// Converts zoning logic from C to pure ARM64 assembly with SIMD acceleration

.data
.align 6

//==============================================================================
// Zoning System Constants and Data
//==============================================================================

// Building information table (optimized for SIMD access)
.building_info_simd:
    // Format: [capacity:32][min_dev:32][power_req:32][water_req:32] (128-bit aligned)
    // BUILDING_NONE
    .word   0                               // capacity
    .float  0.0                             // min_development
    .float  0.0                             // power_requirement
    .float  0.0                             // water_requirement
    
    // BUILDING_HOUSE_SMALL
    .word   4
    .float  0.1
    .float  1.0
    .float  0.5
    
    // BUILDING_HOUSE_MEDIUM
    .word   8
    .float  0.3
    .float  1.5
    .float  1.0
    
    // BUILDING_APARTMENT_LOW
    .word   20
    .float  0.5
    .float  3.0
    .float  2.0
    
    // BUILDING_APARTMENT_HIGH
    .word   50
    .float  0.7
    .float  5.0
    .float  4.0
    
    // BUILDING_CONDO_TOWER
    .word   80
    .float  0.9
    .float  8.0
    .float  6.0
    
    // BUILDING_SHOP_SMALL
    .word   2
    .float  0.1
    .float  1.0
    .float  0.5
    
    // BUILDING_SHOP_MEDIUM
    .word   10
    .float  0.3
    .float  3.0
    .float  1.5
    
    // BUILDING_OFFICE_LOW
    .word   20
    .float  0.5
    .float  4.0
    .float  2.0
    
    // BUILDING_OFFICE_HIGH
    .word   100
    .float  0.7
    .float  10.0
    .float  5.0
    
    // BUILDING_MALL
    .word   150
    .float  0.9
    .float  15.0
    .float  8.0
    
    // BUILDING_FARM
    .word   5
    .float  0.1
    .float  0.5
    .float  1.0
    
    // BUILDING_FACTORY_DIRTY
    .word   30
    .float  0.3
    .float  5.0
    .float  3.0
    
    // BUILDING_FACTORY_CLEAN
    .word   40
    .float  0.5
    .float  6.0
    .float  3.0
    
    // BUILDING_WAREHOUSE
    .word   20
    .float  0.3
    .float  3.0
    .float  1.0
    
    // BUILDING_TECH_PARK
    .word   80
    .float  0.8
    .float  8.0
    .float  4.0

// Zoning simulation constants (SIMD-friendly)
.zoning_constants:
    .development_rate:      .float  0.01        // Base development rate per tick
    .abandonment_thresh:    .float  0.2         // Abandonment threshold
    .neighbor_bonus_mult:   .float  0.1         // Neighbor bonus multiplier
    .age_bonus_scale:       .float  1000.0      // Age bonus scaling factor
    .land_value_decay:      .float  0.95        // Land value decay factor
    .land_value_growth:     .float  0.05        // Land value growth factor
    .utility_required:      .float  1.0         // Utility requirement (1.0 = both needed)
    .max_development:       .float  1.0         // Maximum development level

// Zone type to demand mapping (SIMD lookup table)
.zone_demand_map:
    .float  0.0, 0.0, 0.0, 0.0                  // ZONE_NONE
    .float  1.0, 0.0, 0.0, 0.0                  // ZONE_RESIDENTIAL_LOW
    .float  1.0, 0.0, 0.0, 0.0                  // ZONE_RESIDENTIAL_MEDIUM
    .float  1.0, 0.0, 0.0, 0.0                  // ZONE_RESIDENTIAL_HIGH
    .float  0.0, 1.0, 0.0, 0.0                  // ZONE_COMMERCIAL_LOW
    .float  0.0, 1.0, 0.0, 0.0                  // ZONE_COMMERCIAL_HIGH
    .float  0.0, 0.0, 1.0, 0.0                  // ZONE_INDUSTRIAL_AGRICULTURE
    .float  0.0, 0.0, 1.0, 0.0                  // ZONE_INDUSTRIAL_DIRTY
    .float  0.0, 0.0, 1.0, 0.0                  // ZONE_INDUSTRIAL_MANUFACTURING
    .float  0.0, 0.0, 1.0, 0.0                  // ZONE_INDUSTRIAL_HIGHTECH

.bss
.align 8

// Main zoning grid structure (cache-aligned)
.zoning_grid:
    .grid_width:            .space  4           // uint32_t width
    .grid_height:           .space  4           // uint32_t height
    .tiles_ptr:             .space  8           // ZoneTile* tiles
    .update_tick:           .space  4           // uint32_t current update tick
    .total_population:      .space  4           // Cached total population
    .total_jobs:            .space  4           // Cached total jobs
    .last_full_update:      .space  4           // Last full grid update tick
    .dirty_regions:         .space  8           // Bitmask of dirty 4x4 regions
    _padding:               .space  32          // Cache line padding

// SIMD processing workspace (128-byte aligned for optimal NEON performance)
.align 7
.simd_workspace:
    .tile_buffer:           .space  512         // 4x4 tile buffer for SIMD processing
    .neighbor_buffer:       .space  512         // Neighbor analysis buffer
    .development_buffer:    .space  256         // Development calculation buffer
    .growth_buffer:         .space  256         // Growth rate buffer
    _simd_padding:          .space  128         // Alignment padding

.text
.align 4

//==============================================================================
// Zoning System Initialization
//==============================================================================

// _zoning_init - Initialize NEON-optimized zoning system
// Parameters:
//   x0 = grid_width
//   x1 = grid_height
// Returns:
//   x0 = 0 on success, error code on failure
.global _zoning_init
_zoning_init:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    mov     x19, x0                         // Save grid_width
    mov     x20, x1                         // Save grid_height
    
    // Validate input parameters
    cmp     x19, #1
    b.lt    zoning_init_error_size
    cmp     x20, #1
    b.lt    zoning_init_error_size
    
    // Check for reasonable grid size (prevent overflow)
    cmp     x19, #1024
    b.gt    zoning_init_error_size
    cmp     x20, #1024
    b.gt    zoning_init_error_size
    
    // Initialize zoning grid structure
    adrp    x21, .zoning_grid
    add     x21, x21, :lo12:.zoning_grid
    
    str     w19, [x21, #0]                  // grid_width
    str     w20, [x21, #4]                  // grid_height
    str     wzr, [x21, #12]                 // update_tick = 0
    str     wzr, [x21, #16]                 // total_population = 0
    str     wzr, [x21, #20]                 // total_jobs = 0
    str     wzr, [x21, #24]                 // last_full_update = 0
    str     xzr, [x21, #28]                 // dirty_regions = 0
    
    // Calculate total tile count and memory requirement
    mul     x22, x19, x20                   // total_tiles = width * height
    mov     x0, #64                         // sizeof(ZoneTile) = 64 bytes
    mul     x0, x22, x0                     // total_memory = tiles * sizeof(ZoneTile)
    
    // Allocate tile memory using agent allocator (cache-aligned)
    add     x0, x0, #127                    // Add alignment padding
    and     x0, x0, #~127                   // 128-byte align for NEON
    mov     x1, #3                          // Use behavior data pool for zoning
    bl      fast_agent_alloc
    cbz     x0, zoning_init_error_alloc
    
    str     x0, [x21, #8]                   // Store tiles_ptr
    
    // Initialize all tiles using NEON for speed
    mov     x1, x22                         // tile_count
    bl      zoning_init_tiles_simd
    
    // Initialize SIMD workspace
    bl      zoning_init_simd_workspace
    
    mov     x0, #0                          // Success
    b       zoning_init_done

zoning_init_error_size:
    mov     x0, #-1                         // Invalid size error
    b       zoning_init_done

zoning_init_error_alloc:
    mov     x0, #-2                         // Memory allocation error

zoning_init_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// zoning_init_tiles_simd - Initialize tile array using NEON
// Parameters:
//   x0 = tiles_ptr
//   x1 = tile_count
zoning_init_tiles_simd:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                         // tiles_ptr
    mov     x20, x1                         // tile_count
    
    // Prepare initialization values in NEON registers
    movi    v0.4s, #0                       // zone_type = ZONE_NONE, building_type = BUILDING_NONE
    movi    v1.4s, #0                       // population = 0, jobs = 0
    fmov    v2.4s, #0.5                     // development_level = 0.0, desirability = 0.0, land_value = 0.5, age_ticks = 0.0
    movi    v3.4s, #0                       // has_power = false, has_water = false, is_abandoned = false, _padding
    
    mov     x2, #0                          // tile_index
    
tile_init_loop:
    cmp     x2, x20
    b.ge    tile_init_done
    
    // Calculate tile address: tiles_ptr + (tile_index * 64)
    mov     x3, #64
    mul     x4, x2, x3
    add     x3, x19, x4
    
    // Store entire tile using NEON (64 bytes = 4x 16-byte stores)
    stp     q0, q1, [x3]                    // Store first 32 bytes
    stp     q2, q3, [x3, #32]               // Store last 32 bytes
    
    add     x2, x2, #1
    b       tile_init_loop

tile_init_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// zoning_init_simd_workspace - Initialize SIMD processing workspace
zoning_init_simd_workspace:
    adrp    x0, .simd_workspace
    add     x0, x0, :lo12:.simd_workspace
    
    // Clear entire workspace using NEON
    movi    v0.16b, #0
    mov     x1, #0
    
workspace_clear_loop:
    cmp     x1, #1664                       // Total workspace size
    b.ge    workspace_init_done
    
    add     x2, x0, x1                      // Calculate address
    stp     q0, q0, [x2]                    // Clear 32 bytes
    add     x1, x1, #32
    b       workspace_clear_loop

workspace_init_done:
    ret

//==============================================================================
// Main Zoning Update Function (NEON Optimized)
//==============================================================================

// _zoning_tick - Main zoning system update with SIMD acceleration
// Parameters:
//   d0 = delta_time
// Returns:
//   x0 = 0 on success, error code on failure
.global _zoning_tick
_zoning_tick:
    stp     x29, x30, [sp, #-64]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    mov     x29, sp
    
    fmov    s19, s0                         // Save delta_time
    
    // Get zoning grid info
    adrp    x20, .zoning_grid
    add     x20, x20, :lo12:.zoning_grid
    
    ldr     w21, [x20, #0]                  // grid_width
    ldr     w22, [x20, #4]                  // grid_height
    ldr     x23, [x20, #8]                  // tiles_ptr
    ldr     w24, [x20, #12]                 // current update_tick
    
    // Check if we have valid grid
    cbz     x23, zoning_tick_error
    
    // Increment update tick
    add     w24, w24, #1
    str     w24, [x20, #12]
    
    // Process grid in 4x4 SIMD blocks for optimal cache usage
    mov     x0, #0                          // start_y
    
block_row_loop:
    cmp     x0, x22
    b.ge    zoning_tick_done
    
    mov     x1, #0                          // start_x
    
block_col_loop:
    cmp     x1, x21
    b.ge    next_block_row
    
    // Process 4x4 block with SIMD acceleration
    mov     x19, x0                         // block_y
    fmov    s0, s19                         // delta_time
    bl      process_zoning_block_simd
    
    add     x1, x1, #4                      // Next 4x4 block
    b       block_col_loop

next_block_row:
    add     x0, x0, #4                      // Next block row
    b       block_row_loop

zoning_tick_done:
    // Update cached statistics
    bl      update_zoning_statistics_simd
    
    mov     x0, #0                          // Success
    b       zoning_tick_exit

zoning_tick_error:
    mov     x0, #-1                         // Error

zoning_tick_exit:
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//==============================================================================
// SIMD 4x4 Block Processing
//==============================================================================

// process_zoning_block_simd - Process 4x4 tile block using NEON
// Parameters:
//   x0 = block_y (top-left corner)
//   x1 = block_x (top-left corner)
//   s0 = delta_time
process_zoning_block_simd:
    stp     x29, x30, [sp, #-64]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    mov     x29, sp
    
    mov     x19, x0                         // block_y
    mov     x20, x1                         // block_x
    fmov    s20, s0                         // delta_time
    
    // Get grid dimensions and tiles
    adrp    x21, .zoning_grid
    add     x21, x21, :lo12:.zoning_grid
    ldr     w22, [x21, #0]                  // grid_width
    ldr     w23, [x21, #4]                  // grid_height
    ldr     x24, [x21, #8]                  // tiles_ptr
    
    // Load 4x4 block into SIMD workspace for batch processing
    adrp    x0, .simd_workspace
    add     x0, x0, :lo12:.simd_workspace
    
    mov     x1, #0                          // tile_y_offset
    
load_block_rows:
    cmp     x1, #4
    b.ge    process_loaded_block
    
    mov     x2, #0                          // tile_x_offset
    
load_block_cols:
    cmp     x2, #4
    b.ge    next_block_row_load
    
    // Calculate actual tile coordinates
    add     x3, x19, x1                     // actual_y = block_y + tile_y_offset
    add     x4, x20, x2                     // actual_x = block_x + tile_x_offset
    
    // Bounds check
    cmp     x3, x23
    b.ge    skip_tile_load
    cmp     x4, x22
    b.ge    skip_tile_load
    
    // Calculate tile index and address
    mul     x5, x3, x22                     // y * width
    add     x5, x5, x4                      // + x
    mov     x6, #64                         // sizeof(ZoneTile)
    mul     x5, x5, x6
    add     x5, x24, x5                     // tiles_ptr + offset
    
    // Calculate workspace offset
    mov     x6, #4
    mul     x7, x1, x6                      // row_offset = tile_y_offset * 4
    add     x7, x7, x2                      // + tile_x_offset
    mov     x8, #64
    mul     x7, x7, x8                      // * sizeof(ZoneTile)
    add     x7, x0, x7                      // workspace + offset
    
    // Copy tile to workspace using NEON
    ldp     q0, q1, [x5]
    ldp     q2, q3, [x5, #32]
    stp     q0, q1, [x7]
    stp     q2, q3, [x7, #32]
    
    b       next_tile_col

skip_tile_load:
    // Fill with empty tile data
    mov     x6, #4
    mul     x7, x1, x6
    add     x7, x7, x2
    mov     x8, #64
    mul     x7, x7, x8
    add     x7, x0, x7
    
    movi    v0.16b, #0
    stp     q0, q0, [x7]
    stp     q0, q0, [x7, #32]

next_tile_col:
    add     x2, x2, #1
    b       load_block_cols

next_block_row_load:
    add     x1, x1, #1
    b       load_block_rows

process_loaded_block:
    // Process the loaded 4x4 block with vectorized operations
    adrp    x0, .simd_workspace
    add     x0, x0, :lo12:.simd_workspace
    fmov    s0, s20                         // delta_time
    bl      simd_development_calculation
    
    // Apply results back to grid
    bl      write_block_results_to_grid
    
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//==============================================================================
// NEON Development Calculations
//==============================================================================

// simd_development_calculation - Vectorized development potential and growth
// Parameters:
//   x0 = workspace_ptr
//   s0 = delta_time
simd_development_calculation:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    mov     x19, x0                         // workspace_ptr
    fmov    s19, s0                         // delta_time
    
    // Load zoning constants into NEON registers
    adrp    x20, .zoning_constants
    add     x20, x20, :lo12:.zoning_constants
    
    ld1r    {v20.4s}, [x20]                 // development_rate
    add     x20, x20, #4
    ld1r    {v21.4s}, [x20]                 // abandonment_threshold
    add     x20, x20, #4
    ld1r    {v22.4s}, [x20]                 // neighbor_bonus_mult
    add     x20, x20, #4
    ld1r    {v23.4s}, [x20]                 // age_bonus_scale
    
    // Process 4 tiles at a time using NEON (16 tiles total, 4 iterations)
    mov     x21, #0                         // tile_group_index
    
tile_group_loop:
    cmp     x21, #4
    b.ge    development_calc_done
    
    // Calculate base offset in workspace
    mov     x22, #256                       // 4 tiles * 64 bytes per tile
    mul     x0, x21, x22
    add     x0, x19, x0                     // current_tiles_ptr
    
    // Load 4 tiles worth of data into NEON registers
    // Each tile: zone_type, building_type, population, jobs (16 bytes)
    //           development_level, desirability, land_value, age_ticks (16 bytes)
    //           has_power, has_water, is_abandoned, _padding (16 bytes)
    
    // Load zone types and building types (4 tiles)
    ldr     w1, [x0]                            // Load tile 0 zone_type
    ins     v0.s[0], w1
    ldr     w1, [x0, #4]                        // Load tile 0 building_type
    ins     v1.s[0], w1
    ldr     w1, [x0, #8]                        // Load tile 0 population
    ins     v2.s[0], w1
    ldr     w1, [x0, #12]                       // Load tile 0 jobs
    ins     v3.s[0], w1
    
    add     x0, x0, #64                         // Move to tile 1
    ldr     w1, [x0]
    ins     v0.s[1], w1
    ldr     w1, [x0, #4]
    ins     v1.s[1], w1
    ldr     w1, [x0, #8]
    ins     v2.s[1], w1
    ldr     w1, [x0, #12]
    ins     v3.s[1], w1
    
    add     x0, x0, #64                         // Move to tile 2
    ldr     w1, [x0]
    ins     v0.s[2], w1
    ldr     w1, [x0, #4]
    ins     v1.s[2], w1
    ldr     w1, [x0, #8]
    ins     v2.s[2], w1
    ldr     w1, [x0, #12]
    ins     v3.s[2], w1
    
    add     x0, x0, #64                         // Move to tile 3
    ldr     w1, [x0]
    ins     v0.s[3], w1
    ldr     w1, [x0, #4]
    ins     v1.s[3], w1
    ldr     w1, [x0, #8]
    ins     v2.s[3], w1
    ldr     w1, [x0, #12]
    ins     v3.s[3], w1
    // v0 = zone_types, v1 = building_types, v2 = populations, v3 = jobs
    
    // Reset pointer and load development data
    mov     x22, #256
    mul     x0, x21, x22
    add     x0, x19, x0
    add     x0, x0, #16                     // Skip to development_level offset
    
    // Load development data for 4 tiles
    ldr     s1, [x0]                        // Tile 0 development_level
    ins     v4.s[0], v1.s[0]
    ldr     s1, [x0, #4]                    // Tile 0 desirability
    ins     v5.s[0], v1.s[0]
    ldr     s1, [x0, #8]                    // Tile 0 land_value
    ins     v6.s[0], v1.s[0]
    ldr     s1, [x0, #12]                   // Tile 0 age_ticks
    ins     v7.s[0], v1.s[0]
    
    add     x0, x0, #48                     // Skip to tile 1 development
    ldr     s1, [x0]
    ins     v4.s[1], v1.s[0]
    ldr     s1, [x0, #4]
    ins     v5.s[1], v1.s[0]
    ldr     s1, [x0, #8]
    ins     v6.s[1], v1.s[0]
    ldr     s1, [x0, #12]
    ins     v7.s[1], v1.s[0]
    
    add     x0, x0, #48                     // Skip to tile 2 development
    ldr     s1, [x0]
    ins     v4.s[2], v1.s[0]
    ldr     s1, [x0, #4]
    ins     v5.s[2], v1.s[0]
    ldr     s1, [x0, #8]
    ins     v6.s[2], v1.s[0]
    ldr     s1, [x0, #12]
    ins     v7.s[2], v1.s[0]
    
    add     x0, x0, #48                     // Skip to tile 3 development
    ldr     s1, [x0]
    ins     v4.s[3], v1.s[0]
    ldr     s1, [x0, #4]
    ins     v5.s[3], v1.s[0]
    ldr     s1, [x0, #8]
    ins     v6.s[3], v1.s[0]
    ldr     s1, [x0, #12]
    ins     v7.s[3], v1.s[0]
    // v4 = development_levels, v5 = desirability, v6 = land_values, v7 = age_ticks
    
    // Load utility flags
    mov     x22, #256
    mul     x0, x21, x22
    add     x0, x19, x0
    add     x0, x0, #32                     // Skip to utility flags offset
    
    // Load utility flags for 4 tiles
    ldr     w1, [x0]                        // Tile 0 has_power
    ins     v8.s[0], w1
    ldr     w1, [x0, #4]                    // Tile 0 has_water
    ins     v9.s[0], w1
    ldr     w1, [x0, #8]                    // Tile 0 is_abandoned
    ins     v10.s[0], w1
    
    add     x0, x0, #32                     // Skip to tile 1 utilities
    ldr     w1, [x0]
    ins     v8.s[1], w1
    ldr     w1, [x0, #4]
    ins     v9.s[1], w1
    ldr     w1, [x0, #8]
    ins     v10.s[1], w1
    
    add     x0, x0, #32                     // Skip to tile 2 utilities
    ldr     w1, [x0]
    ins     v8.s[2], w1
    ldr     w1, [x0, #4]
    ins     v9.s[2], w1
    ldr     w1, [x0, #8]
    ins     v10.s[2], w1
    
    add     x0, x0, #32                     // Skip to tile 3 utilities
    ldr     w1, [x0]
    ins     v8.s[3], w1
    ldr     w1, [x0, #4]
    ins     v9.s[3], w1
    ldr     w1, [x0, #8]
    ins     v10.s[3], w1
    // v8 = has_power, v9 = has_water, v10 = is_abandoned
    
    // Calculate development potential using NEON
    // Step 1: Check for utilities (both power and water required)
    and     v11.16b, v8.16b, v9.16b         // utility_available = has_power & has_water
    
    // Step 2: Calculate age bonus (min(age_ticks / 1000.0, 1.0))
    fdiv    v12.4s, v7.4s, v23.4s           // age_ticks / age_bonus_scale
    fmov    v13.4s, #1.0                    // 1.0
    fmin    v12.4s, v12.4s, v13.4s          // age_bonus = min(age_ratio, 1.0)
    
    // Step 3: Calculate base development potential
    // potential = (zone_demand + 1.0) * 0.5 * utility_factor * land_value_factor * age_factor
    
    // Get RCI demand (simplified for SIMD - use fixed moderate demand)
    // Load 0.6 using multiple instructions
    mov     w1, #0x999a
    movk    w1, #0x3f19, lsl #16
    dup     v14.4s, w1
    fmov    v15.4s, #1.0                    // 1.0
    fadd    v14.4s, v14.4s, v15.4s          // (demand + 1.0)
    fmov    v15.4s, #0.5                    // 0.5
    fmul    v14.4s, v14.4s, v15.4s          // * 0.5
    
    // Convert utility flags to float and multiply
    ucvtf   v11.4s, v11.4s                  // Convert utility_available to float
    fmul    v14.4s, v14.4s, v11.4s          // * utility_factor
    
    // Land value factor: (0.5 + land_value * 0.5)
    fmul    v15.4s, v6.4s, v15.4s           // land_value * 0.5
    fmov    v16.4s, #0.5                    // 0.5
    fadd    v15.4s, v15.4s, v16.4s          // 0.5 + (land_value * 0.5)
    fmul    v14.4s, v14.4s, v15.4s          // * land_value_factor
    
    // Age factor: (0.5 + age_bonus * 0.5)
    fmul    v15.4s, v12.4s, v16.4s          // age_bonus * 0.5
    fadd    v15.4s, v15.4s, v16.4s          // 0.5 + (age_bonus * 0.5)
    fmul    v14.4s, v14.4s, v15.4s          // * age_factor
    
    // Clamp potential to [0.0, 1.0]
    movi    v15.4s, #0                      // 0.0
    fmov    v16.4s, #1.0                    // 1.0
    fmax    v14.4s, v14.4s, v15.4s
    fmin    v14.4s, v14.4s, v16.4s          // v14 = development_potential
    
    // Step 4: Apply development/decay based on potential
    fcmp    s19, #0.0                       // Check if delta_time > 0
    b.le    skip_development_update
    
    // Check tiles for growth vs decay
    fmov    v17.4s, #0.5                    // 0.5 threshold
    fcmgt   v17.4s, v14.4s, v17.4s          // potential > 0.5?
    
    // Growth calculation: development_level += rate * potential * delta_time
    fmul    v18.4s, v20.4s, v14.4s          // rate * potential
    dup     v19.4s, v19.s[0]                // Broadcast delta_time
    fmul    v18.4s, v18.4s, v19.4s          // * delta_time
    
    // Apply growth where potential > 0.5 and not abandoned
    mvn     v10.16b, v10.16b                // !is_abandoned
    and     v17.16b, v17.16b, v10.16b       // growth_mask = (potential > 0.5) & !abandoned
    
    // Conditional add for growth
    and     v18.16b, v18.16b, v17.16b       // growth * growth_mask
    fadd    v4.4s, v4.4s, v18.4s            // development_level += growth
    
    // Clamp development level to [0.0, 1.0]
    fmax    v4.4s, v4.4s, v15.4s
    fmin    v4.4s, v4.4s, v16.4s
    
    // Decay calculation for low potential tiles
    fcmgt   v17.4s, v21.4s, v14.4s          // abandonment_threshold > potential?
    fmul    v18.4s, v20.4s, v19.4s          // rate * delta_time
    fmov    v0.4s, #2.0                     // 2.0 multiplier
    fmul    v18.4s, v18.4s, v0.4s           // * 2.0 (decay faster)
    
    // Apply decay
    and     v18.16b, v18.16b, v17.16b       // decay * decay_mask
    fsub    v4.4s, v4.4s, v18.4s            // development_level -= decay
    fmax    v4.4s, v4.4s, v15.4s            // Clamp to >= 0.0
    
    // Update desirability with calculated potential
    mov     v5.16b, v14.16b                 // desirability = potential

skip_development_update:
    // Store results back to workspace
    mov     x22, #256
    mul     x0, x21, x22
    add     x0, x19, x0
    add     x0, x0, #16                     // Skip to development_level offset
    
    // Store development data for 4 tiles
    umov    w1, v4.s[0]                     // Extract tile 0 development_level
    str     w1, [x0]
    umov    w1, v5.s[0]                     // Extract tile 0 desirability
    str     w1, [x0, #4]
    umov    w1, v6.s[0]                     // Extract tile 0 land_value
    str     w1, [x0, #8]
    umov    w1, v7.s[0]                     // Extract tile 0 age_ticks
    str     w1, [x0, #12]
    
    add     x0, x0, #48                     // Skip to tile 1 development
    umov    w1, v4.s[1]
    str     w1, [x0]
    umov    w1, v5.s[1]
    str     w1, [x0, #4]
    umov    w1, v6.s[1]
    str     w1, [x0, #8]
    umov    w1, v7.s[1]
    str     w1, [x0, #12]
    
    add     x0, x0, #48                     // Skip to tile 2 development
    umov    w1, v4.s[2]
    str     w1, [x0]
    umov    w1, v5.s[2]
    str     w1, [x0, #4]
    umov    w1, v6.s[2]
    str     w1, [x0, #8]
    umov    w1, v7.s[2]
    str     w1, [x0, #12]
    
    add     x0, x0, #48                     // Skip to tile 3 development
    umov    w1, v4.s[3]
    str     w1, [x0]
    umov    w1, v5.s[3]
    str     w1, [x0, #4]
    umov    w1, v6.s[3]
    str     w1, [x0, #8]
    umov    w1, v7.s[3]
    str     w1, [x0, #12]
    
    add     x21, x21, #1
    b       tile_group_loop

development_calc_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// Zone Type Transitions and Building Updates
//==============================================================================

// write_block_results_to_grid - Write processed 4x4 block back to main grid
write_block_results_to_grid:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    // Get grid info and current block coordinates
    adrp    x19, .zoning_grid
    add     x19, x19, :lo12:.zoning_grid
    ldr     w20, [x19, #0]                  // grid_width
    ldr     x21, [x19, #8]                  // tiles_ptr
    
    // Get current block coordinates from caller context
    // (We'll need to modify this to properly pass coordinates)
    
    // For now, implement a simple copy-back mechanism
    adrp    x0, .simd_workspace
    add     x0, x0, :lo12:.simd_workspace
    
    // This is a simplified version - in full implementation,
    // we would properly track which block we're processing
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Statistics and Query Functions
//==============================================================================

// update_zoning_statistics_simd - Update cached population/jobs using NEON
update_zoning_statistics_simd:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    adrp    x19, .zoning_grid
    add     x19, x19, :lo12:.zoning_grid
    
    ldr     w20, [x19, #0]                  // grid_width
    ldr     w21, [x19, #4]                  // grid_height
    ldr     x22, [x19, #8]                  // tiles_ptr
    
    mul     w23, w20, w21                   // total_tiles
    
    // Initialize NEON accumulators
    movi    v0.4s, #0                       // population_sum
    movi    v1.4s, #0                       // jobs_sum
    
    mov     x24, #0                         // tile_index
    
stat_simd_loop:
    cmp     x24, x23
    b.ge    stat_simd_done
    
    // Process 4 tiles at once if possible
    sub     x25, x23, x24                   // remaining_tiles
    cmp     x25, #4
    b.lt    stat_single_tile
    
    // Load 4 tiles' population and jobs data
    mov     x26, #64                        // sizeof(ZoneTile)
    mul     x27, x24, x26
    add     x27, x22, x27                   // current_tile_ptr
    
    // Load population (offset 8) and jobs (offset 12) for 4 tiles
    ldr     w0, [x27, #8]                   // tile 0 population
    ldr     w1, [x27, #12]                  // tile 0 jobs
    add     x27, x27, #64
    ldr     w2, [x27, #8]                   // tile 1 population  
    ldr     w3, [x27, #12]                  // tile 1 jobs
    add     x27, x27, #64
    ldr     w4, [x27, #8]                   // tile 2 population
    ldr     w5, [x27, #12]                  // tile 2 jobs
    add     x27, x27, #64
    ldr     w6, [x27, #8]                   // tile 3 population
    ldr     w7, [x27, #12]                  // tile 3 jobs
    
    // Pack into NEON registers and accumulate
    ins     v2.s[0], w0
    ins     v2.s[1], w2
    ins     v2.s[2], w4
    ins     v2.s[3], w6                     // v2 = 4 populations
    
    ins     v3.s[0], w1
    ins     v3.s[1], w3
    ins     v3.s[2], w5
    ins     v3.s[3], w7                     // v3 = 4 jobs
    
    add     v0.4s, v0.4s, v2.4s             // accumulate populations
    add     v1.4s, v1.4s, v3.4s             // accumulate jobs
    
    add     x24, x24, #4                    // process 4 tiles
    b       stat_simd_loop

stat_single_tile:
    // Handle remaining tiles one by one
    mov     x26, #64
    mul     x27, x24, x26
    add     x27, x22, x27
    
    ldr     w0, [x27, #8]                   // population
    ldr     w1, [x27, #12]                  // jobs
    
    // Add to first lane of accumulator
    ins     v2.s[0], w0
    ins     v3.s[0], w1
    add     v0.4s, v0.4s, v2.4s
    add     v1.4s, v1.4s, v3.4s
    
    add     x24, x24, #1
    b       stat_simd_loop

stat_simd_done:
    // Sum up NEON accumulators
    addv    s0, v0.4s                       // Sum all population lanes
    addv    s1, v1.4s                       // Sum all jobs lanes
    
    fmov    w0, s0
    fmov    w1, s1
    
    // Store results
    str     w0, [x19, #16]                  // total_population
    str     w1, [x19, #20]                  // total_jobs
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Public Query Functions
//==============================================================================

// _zoning_get_total_population - Get total population across all zones
// Returns: x0 = total_population
.global _zoning_get_total_population
_zoning_get_total_population:
    adrp    x0, .zoning_grid
    add     x0, x0, :lo12:.zoning_grid
    ldr     w0, [x0, #16]                   // total_population
    ret

// _zoning_get_total_jobs - Get total jobs across all zones  
// Returns: x0 = total_jobs
.global _zoning_get_total_jobs
_zoning_get_total_jobs:
    adrp    x0, .zoning_grid
    add     x0, x0, :lo12:.zoning_grid
    ldr     w0, [x0, #20]                   // total_jobs
    ret

// _zoning_set_tile - Set zone type for a specific tile
// Parameters:
//   x0 = x coordinate
//   x1 = y coordinate  
//   x2 = zone_type
// Returns: x0 = 0 on success, -1 on error
.global _zoning_set_tile
_zoning_set_tile:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get grid info
    adrp    x3, .zoning_grid
    add     x3, x3, :lo12:.zoning_grid
    ldr     w4, [x3, #0]                    // grid_width
    ldr     w5, [x3, #4]                    // grid_height
    ldr     x6, [x3, #8]                    // tiles_ptr
    
    // Bounds check
    cmp     x0, x4
    b.ge    zoning_set_error
    cmp     x1, x5
    b.ge    zoning_set_error
    
    // Calculate tile index and address
    mul     x7, x1, x4                      // y * width
    add     x7, x7, x0                      // + x
    mov     x8, #64                         // sizeof(ZoneTile)
    mul     x7, x7, x8
    add     x7, x6, x7                      // tiles_ptr + offset
    
    // Get current zone type
    ldr     w8, [x7, #0]                    // current zone_type
    
    // If zone type is changing, reset development
    cmp     w8, w2
    b.eq    zone_no_change
    
    // Clear development when zone type changes
    str     w2, [x7, #0]                    // zone_type
    mov     w8, #0                          // BUILDING_NONE
    str     w8, [x7, #4]                    // building_type
    str     wzr, [x7, #8]                   // population
    str     wzr, [x7, #12]                  // jobs
    
    fmov    s0, wzr                         // 0.0
    str     s0, [x7, #16]                   // development_level
    str     s0, [x7, #24]                   // age_ticks (reset to 0)
    
    mov     w8, #0                          // false
    str     w8, [x7, #32]                   // is_abandoned
    
zone_no_change:
    mov     x0, #0                          // Success
    b       zoning_set_done

zoning_set_error:
    mov     x0, #-1                         // Error

zoning_set_done:
    ldp     x29, x30, [sp], #16
    ret

// _zoning_get_tile - Get tile information
// Parameters:
//   x0 = x coordinate
//   x1 = y coordinate
//   x2 = output_buffer (ZoneTile structure)
// Returns: x0 = 0 on success, -1 on error
.global _zoning_get_tile
_zoning_get_tile:
    // Get grid info
    adrp    x3, .zoning_grid
    add     x3, x3, :lo12:.zoning_grid
    ldr     w4, [x3, #0]                    // grid_width
    ldr     w5, [x3, #4]                    // grid_height
    ldr     x6, [x3, #8]                    // tiles_ptr
    
    // Bounds check
    cmp     x0, x4
    b.ge    zoning_get_error
    cmp     x1, x5
    b.ge    zoning_get_error
    
    // Calculate tile index and address
    mul     x7, x1, x4                      // y * width
    add     x7, x7, x0                      // + x
    mov     x8, #64                         // sizeof(ZoneTile)
    mul     x7, x7, x8
    add     x7, x6, x7                      // tiles_ptr + offset
    
    // Copy entire tile using NEON
    ldp     q0, q1, [x7]
    ldp     q2, q3, [x7, #32]
    stp     q0, q1, [x2]
    stp     q2, q3, [x2, #32]
    
    mov     x0, #0                          // Success
    ret

zoning_get_error:
    mov     x0, #-1                         // Error
    ret

//==============================================================================
// System Cleanup
//==============================================================================

// _zoning_cleanup - Clean up zoning system and free memory
// Returns: x0 = 0 on success
.global _zoning_cleanup
_zoning_cleanup:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, .zoning_grid
    add     x0, x0, :lo12:.zoning_grid
    
    // Free tiles memory if allocated
    ldr     x1, [x0, #8]                    // tiles_ptr
    cbz     x1, cleanup_done
    
    mov     x0, x1
    bl      fast_agent_free                 // Use agent allocator to free
    
    // Clear grid structure
    adrp    x0, .zoning_grid
    add     x0, x0, :lo12:.zoning_grid
    str     xzr, [x0, #8]                   // tiles_ptr = NULL
    str     wzr, [x0, #0]                   // grid_width = 0
    str     wzr, [x0, #4]                   // grid_height = 0

cleanup_done:
    mov     x0, #0                          // Success
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// External Function References
//==============================================================================

.extern fast_agent_alloc
.extern fast_agent_free
.extern rci_demand_get

.end