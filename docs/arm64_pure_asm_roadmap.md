# SimCity ARM64: Pure Assembly Conversion Roadmap

## Executive Summary
This document outlines the complete transformation of our mixed C/Objective-C/GLSL SimCity implementation into a pure ARM64 assembly (.s) codebase. The conversion will be executed in 5 major phases, each with 5 detailed sub-projects.

## Architecture Overview

### Current State
- **Language Mix**: C (70%), Objective-C (20%), GLSL (10%)
- **Dependencies**: Cocoa, Metal/OpenGL, libc
- **Binary Size**: ~450KB
- **Performance**: 60 FPS @ 1080p

### Target State
- **Language**: 100% ARM64 Assembly
- **Dependencies**: None (direct syscalls)
- **Binary Size**: <64KB
- **Performance**: 120+ FPS @ 4K

---

## Phase 1: Simulation Core → Pure ARM64 ASM

### 1.1 Define ABI & Module Boundaries

#### Implementation Steps:
```asm
// asm/simulation_abi.s
.section __TEXT,__const
.align 3

// Function signature table for validation
simulation_signatures:
    .ascii "simulation_tick:f32->void\0"
    .ascii "zoning_update:f32->i32\0"
    .ascii "utilities_update:f32->i32\0"
    .align 3

.section __TEXT,__text
.global _simulation_tick
.global _zoning_system_update
.global _utilities_system_update
.global _commuter_system_update
.global _car_system_update

// AAPCS64 compliance markers
.type _simulation_tick, @function
.type _zoning_system_update, @function
```

#### Gotchas:
- Floating-point args must use v0-v7, not x0-x7
- Stack must remain 16-byte aligned
- Preserve x19-x28 and v8-v15 across calls

### 1.2 Hand-write the Tick Dispatcher

```asm
.text
.align 4
_simulation_tick:
    // Prologue - save frame
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    // Save dt for reuse
    str s0, [sp, #-16]!  // dt in float
    
    // Call subsystems in dependency order
    ldr s0, [sp]         // reload dt
    bl _utilities_system_update
    
    ldr s0, [sp]
    bl _zoning_system_update
    
    ldr s0, [sp]
    bl _commuter_system_update
    
    ldr s0, [sp]
    bl _car_system_update
    
    // Epilogue
    add sp, sp, #16
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Timing instrumentation stub
_simulation_tick_instrumented:
    mrs x19, CNTVCT_EL0  // Start cycle count
    bl _simulation_tick
    mrs x20, CNTVCT_EL0  // End cycle count
    sub x0, x20, x19     // Return cycle delta
    ret
```

### 1.3 Inline Critical Hotspots

#### Neighbor Tile Calculation (Unrolled)
```asm
// Compute all 8 neighbors in parallel
.macro CALC_NEIGHBORS base_x, base_y, out_ptr
    // North
    sub w0, \base_x, #1
    mov w1, \base_y
    str w0, [\out_ptr]
    str w1, [\out_ptr, #4]
    
    // Northeast (unrolled...)
    sub w0, \base_x, #1
    add w1, \base_y, #1
    str w0, [\out_ptr, #8]
    str w1, [\out_ptr, #12]
    
    // Continue for all 8...
.endm

// NEON vectorized land value sum
calc_neighbor_land_values:
    // x0 = tile_x, x1 = tile_y, x2 = grid_ptr
    sub sp, sp, #64      // 8 neighbors × 8 bytes
    mov x3, sp
    
    CALC_NEIGHBORS w0, w1, x3
    
    // Load all 8 land values at once
    movi v0.4s, #0       // accumulator
    mov x4, #0           // neighbor index
    
neighbor_loop:
    ldp w5, w6, [x3], #8 // x, y coords
    // bounds check...
    ldr s1, [x2, x5, lsl #2]  // land_value
    fadd s0, s0, s1
    add x4, x4, #1
    cmp x4, #8
    b.lt neighbor_loop
    
    add sp, sp, #64
    ret
```

### 1.4 Embed Inline Data Tables

```asm
.section __TEXT,__const
.align 4

// Zone growth multipliers by density
zone_growth_table:
    .float 0.25  // DENSITY_NONE
    .float 0.75  // DENSITY_LOW
    .float 1.00  // DENSITY_MEDIUM
    .float 1.25  // DENSITY_HIGH
    .float 1.50  // DENSITY_VERY_HIGH

// Utility decay by distance
utility_decay_table:
    .float 1.00, 0.90, 0.75, 0.50  // 0-3 tiles
    .float 0.35, 0.20, 0.10, 0.05  // 4-7 tiles
    .float 0.02, 0.01, 0.00, 0.00  // 8-11 tiles

// Usage in code:
adrp x0, zone_growth_table@PAGE
add x0, x0, zone_growth_table@PAGEOFF
ldr s0, [x0, w1, uxtw #2]  // w1 = density index
```

### 1.5 Validation & Benchmarking

```asm
// Test harness entry point
.global _run_simulation_benchmark
_run_simulation_benchmark:
    // x0 = iteration count
    mov x19, x0
    mov x20, #0          // total cycles
    
    // Fixed dt = 16.667ms
    mov w0, #0x41855555  // float 16.667
    fmov s0, w0
    
bench_loop:
    mrs x21, CNTVCT_EL0
    bl _simulation_tick
    mrs x22, CNTVCT_EL0
    sub x22, x22, x21
    add x20, x20, x22
    
    subs x19, x19, #1
    b.ne bench_loop
    
    // Return average cycles per tick
    udiv x0, x20, x0
    ret
```

---

## Phase 2: Utilities Flood-Fill → NEON-Accelerated ASM

### 2.1 Reorganize Grid in Memory

```asm
.section __DATA,__bss
.align 4

// Aligned grid storage
utility_grid:
    .zero GRID_WIDTH * GRID_HEIGHT * 16  // 16 bytes per tile

// Tile structure (16 bytes aligned):
// +0:  uint32_t flags
// +4:  float power_coverage  
// +8:  float water_coverage
// +12: uint32_t reserved

.macro TILE_OFFSET x, y, result
    mov \result, #GRID_WIDTH
    mul \result, \y, \result
    add \result, \result, \x
    lsl \result, \result, #4  // × 16 bytes
.endm
```

### 2.2 Vectorized Source Mask Scan

```asm
_utilities_flood_vectorized:
    // Find all source tiles using NEON
    adrp x0, utility_grid@PAGE
    add x0, x0, utility_grid@PAGEOFF
    
    mov x1, #0           // tile index
    mov x2, #GRID_SIZE/4 // process 4 at a time
    
scan_loop:
    ld1 {v0.4s}, [x0], #16    // load 4 flag words
    mov w3, #SOURCE_FLAG_MASK
    dup v1.4s, w3
    cmtst v2.4s, v0.4s, v1.4s // test source bit
    
    // Extract lanes with sources
    umov w4, v2.s[0]
    cbz w4, check_lane1
    bl flood_from_tile_0
    
check_lane1:
    umov w4, v2.s[1]
    cbz w4, check_lane2
    bl flood_from_tile_1
    
    // Continue for lanes 2,3...
    
    add x1, x1, #4
    subs x2, x2, #1
    b.ne scan_loop
    ret
```

### 2.3 Branchless Flood Distance Decay

```asm
// Queue-based flood with NEON
.section __DATA,__bss
.align 4
flood_queue:
    .zero 4096 * 12  // (x,y,dist) tuples

flood_from_source:
    // x0 = source_x, x1 = source_y
    adrp x10, flood_queue@PAGE
    add x10, x10, flood_queue@PAGEOFF
    
    // Initialize queue
    strb w0, [x10]       // x
    strb w1, [x10, #1]   // y  
    strb wzr, [x10, #2]  // dist = 0
    mov x11, #1          // queue size
    
process_queue:
    cbz x11, done
    sub x11, x11, #1
    
    // Pop from queue
    ldrb w0, [x10], #1   // x
    ldrb w1, [x10], #1   // y
    ldrb w2, [x10], #1   // dist
    
    // Process 4 neighbors in parallel
    mov x3, x0
    mov x4, x1
    
    // North, East, South, West offsets
    adr x5, neighbor_offsets
    ld1 {v0.4h, v1.4h}, [x5]  // dx, dy vectors
    
    dup v2.4h, w3        // broadcast x
    dup v3.4h, w4        // broadcast y
    add v4.4h, v2.4h, v0.4h  // neighbor x coords
    add v5.4h, v3.4h, v1.4h  // neighbor y coords
    
    // Bounds check with NEON
    movi v6.4h, #0
    movi v7.4h, #GRID_WIDTH
    cmge v8.4h, v4.4h, v6.4h     // x >= 0
    cmlt v9.4h, v4.4h, v7.4h     // x < width
    and v10.16b, v8.16b, v9.16b  // valid x
    
    // Similar for y bounds...
    
    // Continue flood for valid neighbors
    ret

neighbor_offsets:
    .short 0, 1, 0, -1   // dx
    .short -1, 0, 1, 0   // dy
```

### 2.4 Reduce Memory Traffic

```asm
// Batch update coverage values
update_coverage_batch:
    // x0 = tile_base, x1 = count
    
    // Prefetch next cache line
    prfm pldl1strm, [x0, #64]
    
batch_loop:
    // Load 2 tiles (32 bytes)
    ldp q0, q1, [x0]
    
    // Extract coverage floats
    mov v2.s[0], v0.s[1]  // power1
    mov v2.s[1], v0.s[2]  // water1
    mov v2.s[2], v1.s[1]  // power2
    mov v2.s[3], v1.s[2]  // water2
    
    // Apply decay
    adr x2, decay_factors
    ld1 {v3.4s}, [x2]
    fmul v2.4s, v2.4s, v3.4s
    
    // Pack back
    mov v0.s[1], v2.s[0]
    mov v0.s[2], v2.s[1]
    mov v1.s[1], v2.s[2]
    mov v1.s[2], v2.s[3]
    
    // Store updated tiles
    stp q0, q1, [x0], #32
    
    subs x1, x1, #2
    b.gt batch_loop
    ret

decay_factors:
    .float 0.95, 0.95, 0.95, 0.95
```

### 2.5 Integration & Testing

```asm
// Drop-in replacement stub
.global _utilities_system_update
_utilities_system_update:
    stp x29, x30, [sp, #-16]!
    
    // Clear coverage first
    bl clear_utility_coverage
    
    // Find and flood from all sources
    bl _utilities_flood_vectorized
    
    // Calculate stats
    bl compute_utility_stats
    
    ldp x29, x30, [sp], #16
    ret

// Validation dump for testing
dump_utility_sample:
    // Dump 8×8 corner for comparison
    adrp x0, utility_grid@PAGE
    add x0, x0, utility_grid@PAGEOFF
    
    mov x1, #8
dump_row:
    mov x2, #8
dump_col:
    ldr w3, [x0], #4     // flags
    ldr s0, [x0], #4     // power
    ldr s1, [x0], #4     // water
    add x0, x0, #4       // skip reserved
    
    // Print via semihosting or syscall
    bl debug_print_tile
    
    subs x2, x2, #1
    b.ne dump_col
    
    // Next row
    add x0, x0, #(GRID_WIDTH-8)*16
    subs x1, x1, #1
    b.ne dump_row
    ret
```

---

## Phase 3: A* Pathfinder Core → Assembly Heap & Search

### 3.1 Design a Fixed-Size Binary Heap in SRAM

```asm
.section __DATA,__bss
.align 4

// Static heap storage
astar_heap:
    .zero MAX_HEAP_SIZE * 16  // 16 bytes per node

// Node structure (16 bytes):
// +0:  uint16_t x
// +2:  uint16_t y  
// +4:  uint32_t g_cost (fixed-point)
// +8:  uint32_t f_cost (fixed-point)
// +12: uint32_t parent_idx

heap_size:
    .quad 0

// Register allocation convention:
// x10 = heap base
// x11 = heap size
// x12 = open set base
// x13 = closed set base
```

### 3.2 Branch-Optimized Insert/Extract

```asm
// Branchless heap insert
heap_insert:
    // x0 = x, x1 = y, x2 = g_cost, x3 = f_cost
    adrp x10, astar_heap@PAGE
    add x10, x10, astar_heap@PAGEOFF
    ldr x11, [x10, #:lo12:heap_size]
    
    // Store at end
    lsl x4, x11, #4      // offset = size * 16
    strh w0, [x10, x4]   // x
    strh w1, [x10, x4, #2] // y
    str w2, [x10, x4, #4]  // g_cost
    str w3, [x10, x4, #8]  // f_cost
    
    // Percolate up
    mov x5, x11          // child index
percolate_up:
    cbz x5, done_insert
    sub x6, x5, #1
    lsr x6, x6, #1       // parent = (child-1)/2
    
    // Load f_costs
    lsl x7, x5, #4
    lsl x8, x6, #4
    ldr w9, [x10, x7, #8]   // child f_cost
    ldr w12, [x10, x8, #8]  // parent f_cost
    
    // Conditional swap without branch
    cmp w9, w12
    csel x7, x8, x7, hs     // swap if child >= parent
    csel x8, x7, x8, hs
    
    // Load both nodes
    ldp q0, q1, [x10, x7]
    ldp q2, q3, [x10, x8]
    
    // Store swapped
    stp q2, q3, [x10, x7]
    stp q0, q1, [x10, x8]
    
    // Move to parent
    mov x5, x6
    b percolate_up
    
done_insert:
    add x11, x11, #1
    str x11, [x10, #:lo12:heap_size]
    ret

// Extract min with sift-down
heap_extract_min:
    // Returns x0=x, x1=y, x2=g_cost
    adrp x10, astar_heap@PAGE
    add x10, x10, astar_heap@PAGEOFF
    ldr x11, [x10, #:lo12:heap_size]
    
    cbz x11, heap_empty
    
    // Load root
    ldrh w0, [x10]
    ldrh w1, [x10, #2]
    ldr w2, [x10, #4]
    
    // Move last to root
    sub x11, x11, #1
    lsl x3, x11, #4
    ldp q0, q1, [x10, x3]
    stp q0, q1, [x10]
    
    str x11, [x10, #:lo12:heap_size]
    
    // Sift down
    mov x4, #0           // current index
sift_down:
    lsl x5, x4, #1
    add x5, x5, #1       // left child
    cmp x5, x11
    b.hs done_sift
    
    // Find smaller child
    add x6, x5, #1       // right child
    lsl x7, x5, #4
    ldr w8, [x10, x7, #8]  // left f_cost
    
    cmp x6, x11
    b.hs use_left
    
    lsl x9, x6, #4
    ldr w12, [x10, x9, #8] // right f_cost
    cmp w8, w12
    csel x5, x5, x6, ls   // choose smaller
    
use_left:
    // Compare with current
    lsl x7, x4, #4
    lsl x8, x5, #4
    ldr w9, [x10, x7, #8]
    ldr w12, [x10, x8, #8]
    
    cmp w9, w12
    b.ls done_sift
    
    // Swap
    ldp q0, q1, [x10, x7]
    ldp q2, q3, [x10, x8]
    stp q2, q3, [x10, x7]
    stp q0, q1, [x10, x8]
    
    mov x4, x5
    b sift_down
    
done_sift:
heap_empty:
    ret
```

### 3.3 Heuristic in Registers

```asm
// Manhattan distance with octile optimization
compute_heuristic:
    // x0 = x1, x1 = y1, x2 = x2, x3 = y2
    // Returns x0 = heuristic (fixed-point)
    
    sub x4, x0, x2
    sub x5, x1, x3
    
    // Absolute values without branch
    eor x6, x4, x4, asr #63
    sub x4, x6, x4, asr #63
    
    eor x6, x5, x5, asr #63
    sub x5, x6, x5, asr #63
    
    // Octile distance: D × max + (D√2 - D) × min
    // Where D = 1.0, D√2 ≈ 1.414
    cmp x4, x5
    csel x6, x4, x5, gt   // max
    csel x7, x5, x4, gt   // min
    
    // Fixed-point math (16.16)
    mov x8, #0x16A0A      // ≈1.414 in 16.16
    mov x9, #0x10000      // 1.0 in 16.16
    sub x8, x8, x9        // 0.414
    
    mul x7, x7, x8
    lsr x7, x7, #16       // min × 0.414
    add x0, x6, x7        // max + min×0.414
    
    ret

// Tie-breaking heuristic for smoother paths
compute_heuristic_tiebreak:
    // x0-x3 = coords, x4 = goal_x, x5 = goal_y
    bl compute_heuristic
    
    // Add small cross-product tie breaker
    sub x6, x0, x4        // dx1
    sub x7, x1, x5        // dy1
    sub x8, x2, x4        // dx2
    sub x9, x3, x5        // dy2
    
    // cross = abs(dx1×dy2 - dx2×dy1)
    mul x10, x6, x9
    mul x11, x8, x7
    sub x10, x10, x11
    
    // Absolute value
    eor x11, x10, x10, asr #63
    sub x10, x11, x10, asr #63
    
    // Scale down and add
    lsr x10, x10, #10
    add x0, x0, x10
    
    ret
```

### 3.4 Open/Closed Set Masks

```asm
.section __DATA,__bss
.align 4

// Bitsets for 64×64 grid
open_set:
    .zero 512   // 4096 bits

closed_set:
    .zero 512   // 4096 bits

// NEON operations on bitsets
.text
set_open_bit:
    // x0 = x, x1 = y
    adrp x2, open_set@PAGE
    add x2, x2, open_set@PAGEOFF
    
    // Calculate bit index
    lsl x3, x1, #6        // y × 64
    add x3, x3, x0        // + x
    
    // Set bit using atomic operations
    lsr x4, x3, #6        // qword index
    and x5, x3, #63       // bit index
    mov x6, #1
    lsl x6, x6, x5        // bit mask
    
    ldr x7, [x2, x4, lsl #3]
    orr x7, x7, x6
    str x7, [x2, x4, lsl #3]
    ret

check_closed_batch:
    // x0 = coord array, x1 = count
    // Uses NEON to check 4 tiles at once
    adrp x2, closed_set@PAGE
    add x2, x2, closed_set@PAGEOFF
    
    movi v0.16b, #0       // results
    
check_loop:
    ldp w3, w4, [x0], #8  // x1,y1
    ldp w5, w6, [x0], #8  // x2,y2
    
    // Calculate indices
    lsl x3, x3, #6
    add x3, x3, w4
    lsl x5, x5, #6
    add x5, x5, w6
    
    // Load bits
    lsr x7, x3, #6
    ldr x8, [x2, x7, lsl #3]
    and x9, x3, #63
    lsr x8, x8, x9
    and w8, w8, #1
    
    mov v0.h[0], w8
    // Repeat for other coords...
    
    subs x1, x1, #4
    b.gt check_loop
    
    // v0 now contains closed flags
    ret
```

### 3.5 Path Reconstruction In-Place

```asm
// Path buffer in static memory
.section __DATA,__bss
.align 4
path_buffer:
    .zero MAX_PATH_LENGTH * 4  // x,y pairs

reconstruct_path:
    // x0 = goal_idx in heap
    // Returns x0 = path_buffer, x1 = length
    
    adrp x10, astar_heap@PAGE
    add x10, x10, astar_heap@PAGEOFF
    adrp x11, path_buffer@PAGE
    add x11, x11, path_buffer@PAGEOFF
    
    // Walk backwards
    mov x2, #MAX_PATH_LENGTH
    sub x2, x2, #1
    lsl x2, x2, #2        // end of buffer
    add x3, x11, x2
    
    mov x4, x0            // current index
walk_back:
    // Load node
    lsl x5, x4, #4
    ldrh w6, [x10, x5]    // x
    ldrh w7, [x10, x5, #2] // y
    
    // Store in buffer (backwards)
    strh w6, [x3], #-2
    strh w7, [x3], #-2
    
    // Get parent
    ldr w4, [x10, x5, #12]
    cmp w4, #0xFFFFFFFF   // no parent marker
    b.ne walk_back
    
    // Calculate path start and length
    add x3, x3, #4        // adjust for last decrement
    sub x1, x11, x3
    add x1, x1, x2
    lsr x1, x1, #2        // length in coord pairs
    
    // Shift path to beginning if needed
    cmp x3, x11
    b.eq done_reconstruct
    
    // Copy to start
    mov x0, x11
copy_loop:
    ldrh w4, [x3], #2
    strh w4, [x0], #2
    cmp x3, x11
    add x3, x3, x2
    b.lt copy_loop
    
done_reconstruct:
    mov x0, x11           // return buffer
    ret
```

---

## Phase 4: Renderer & Overlays → ASM Batch Draw

### 4.1 Vertex Data Generation in ASM

```asm
.section __DATA,__bss
.align 4

// Vertex buffer for all tiles
vertex_buffer:
    .zero MAX_TILES * 24  // 6 floats per tile (2 triangles)

color_buffer:
    .zero MAX_TILES * 16  // 4 floats RGBA per tile

generate_tile_vertices:
    // x0 = grid_ptr, x1 = visible_rect
    adrp x10, vertex_buffer@PAGE
    add x10, x10, vertex_buffer@PAGEOFF
    adrp x11, color_buffer@PAGE
    add x11, x11, color_buffer@PAGEOFF
    
    // Extract visible bounds
    ldp w2, w3, [x1]      // min_x, min_y
    ldp w4, w5, [x1, #8]  // max_x, max_y
    
    mov x6, #0            // vertex count
    
    // Tile size in pixels
    mov w7, #40
    fmov s4, w7
    scvtf s4, s4          // float tile_size
    
tile_loop_y:
    mov w8, w2            // x = min_x
tile_loop_x:
    // Calculate pixel coords
    mul w9, w8, w7        // x0 = tile_x × size
    mul w10, w3, w7       // y0 = tile_y × size
    add w11, w9, w7       // x1 = x0 + size
    add w12, w10, w7      // y1 = y0 + size
    
    // Convert to float and normalize
    scvtf s0, w9
    scvtf s1, w10
    scvtf s2, w11
    scvtf s3, w12
    
    mov w13, #WINDOW_WIDTH
    mov w14, #WINDOW_HEIGHT
    scvtf s5, w13
    scvtf s6, w14
    
    fdiv s0, s0, s5       // normalize x0
    fdiv s1, s1, s6       // normalize y0
    fdiv s2, s2, s5       // normalize x1
    fdiv s3, s3, s6       // normalize y1
    
    // Generate two triangles
    // Triangle 1: (x0,y0), (x1,y0), (x0,y1)
    str s0, [x10], #4     // x0
    str s1, [x10], #4     // y0
    str s2, [x10], #4     // x1
    str s1, [x10], #4     // y0
    str s0, [x10], #4     // x0
    str s3, [x10], #4     // y1
    
    // Triangle 2: (x1,y0), (x1,y1), (x0,y1)
    str s2, [x10], #4     // x1
    str s1, [x10], #4     // y0
    str s2, [x10], #4     // x1
    str s3, [x10], #4     // y1
    str s0, [x10], #4     // x0
    str s3, [x10], #4     // y1
    
    add x6, x6, #6        // 6 vertices added
    
    // Next tile
    add w8, w8, #1
    cmp w8, w4
    b.lt tile_loop_x
    
    add w3, w3, #1
    cmp w3, w5
    b.lt tile_loop_y
    
    mov x0, x6            // return vertex count
    ret
```

### 4.2 Batch Loop Unrolling

```asm
// Process 8 tiles per iteration
batch_draw_tiles:
    // x0 = tile_array, x1 = count
    
    // Align to 8-tile boundary
    and x2, x1, #7        // remainder
    lsr x3, x1, #3        // batches of 8
    
batch_8_loop:
    cbz x3, handle_remainder
    
    // Prefetch next batch
    prfm pldl1keep, [x0, #128]
    
    // Unrolled tile processing
    .irp tile_idx, 0, 1, 2, 3, 4, 5, 6, 7
        ldr x4, [x0, #\tile_idx * 16]      // tile ptr
        ldr w5, [x4]                        // tile type
        ldr s0, [x4, #4]                    // tile value
        
        // Calculate color
        adr x6, tile_color_table
        ldr w7, [x6, w5, lsl #2]            // base color
        
        // Generate vertices
        bl generate_single_tile_vertices
    .endr
    
    add x0, x0, #128      // 8 tiles × 16 bytes
    sub x3, x3, #1
    b batch_8_loop
    
handle_remainder:
    // Process remaining tiles
    cbz x2, done
remainder_loop:
    ldr x4, [x0], #16
    bl process_single_tile
    subs x2, x2, #1
    b.ne remainder_loop
    
done:
    ret
```

### 4.3 Overlay Color Computation

```asm
.section __TEXT,__const
.align 4

// HSV to RGB lookup table (256 entries)
hsv_to_rgb_table:
    .word 0xFF0000FF  // 0: Red
    .word 0xFF0400FF  // 1: 
    .word 0xFF0800FF  // 2:
    // ... 256 entries total
    .word 0xFF00FF00  // 255: Green

// Fast overlay color lookup
compute_overlay_color:
    // s0 = overlay value [0,1]
    // Returns w0 = RGBA color
    
    // Scale to 0-255
    mov w1, #255
    scvtf s1, w1
    fmul s0, s0, s1
    fcvtzs w1, s0
    
    // Clamp
    cmp w1, #255
    csel w1, w1, #255, lt
    cmp w1, #0
    csel w1, w1, wzr, gt
    
    // Table lookup
    adrp x2, hsv_to_rgb_table@PAGE
    add x2, x2, hsv_to_rgb_table@PAGEOFF
    ldr w0, [x2, w1, lsl #2]
    ret

// Batch color generation with NEON
generate_overlay_colors_neon:
    // x0 = value_array, x1 = color_array, x2 = count
    
    lsr x3, x2, #2        // batches of 4
color_batch_loop:
    cbz x3, done_colors
    
    // Load 4 values
    ld1 {v0.4s}, [x0], #16
    
    // Scale to 0-255
    movi v1.4s, #255
    scvtf v1.4s, v1.4s
    fmul v0.4s, v0.4s, v1.4s
    fcvtzs v0.4s, v0.4s
    
    // Clamp (simplified - assumes input in [0,1])
    movi v1.4s, #0
    smax v0.4s, v0.4s, v1.4s
    movi v1.4s, #255
    smin v0.4s, v0.4s, v1.4s
    
    // Extract and lookup
    umov w4, v0.s[0]
    umov w5, v0.s[1]
    umov w6, v0.s[2]
    umov w7, v0.s[3]
    
    adrp x8, hsv_to_rgb_table@PAGE
    add x8, x8, hsv_to_rgb_table@PAGEOFF
    
    ldr w4, [x8, w4, lsl #2]
    ldr w5, [x8, w5, lsl #2]
    ldr w6, [x8, w6, lsl #2]
    ldr w7, [x8, w7, lsl #2]
    
    // Store colors
    stp w4, w5, [x1], #8
    stp w6, w7, [x1], #8
    
    sub x3, x3, #1
    b color_batch_loop
    
done_colors:
    ret
```

### 4.4 Draw Call Trampolines

```asm
// Metal draw call wrapper
.global _metal_draw_tiles
_metal_draw_tiles:
    // x0 = command_encoder
    // x1 = vertex_count
    
    stp x29, x30, [sp, #-64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    mov x19, x0           // save encoder
    mov x20, x1           // save count
    
    // Set vertex buffer
    adrp x0, vertex_buffer@PAGE
    add x0, x0, vertex_buffer@PAGEOFF
    mov x1, x19           // encoder
    mov x2, #0            // offset
    mov x3, #0            // index
    bl _mtlSetVertexBuffer
    
    // Set color buffer
    adrp x0, color_buffer@PAGE
    add x0, x0, color_buffer@PAGEOFF
    mov x1, x19
    mov x2, #0
    mov x3, #1            // index 1
    bl _mtlSetVertexBuffer
    
    // Draw call
    mov x0, x19           // encoder
    mov x1, #3            // MTLPrimitiveTypeTriangle
    mov x2, #0            // vertex start
    mov x3, x20           // vertex count
    bl _mtlDrawPrimitives
    
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// OpenGL wrapper (similar structure)
.global _gl_draw_tiles
_gl_draw_tiles:
    // x0 = vertex_count
    stp x29, x30, [sp, #-16]!
    
    // Bind vertex array
    mov x0, #1            // VAO id
    bl _glBindVertexArray
    
    // Update vertex buffer
    mov x0, #0x8892       // GL_ARRAY_BUFFER
    mov x1, #1            // VBO id
    bl _glBindBuffer
    
    adrp x0, vertex_buffer@PAGE
    add x0, x0, vertex_buffer@PAGEOFF
    mov x1, x20
    lsl x1, x1, #2        // size = count × 4
    mov x2, #0x88E4       // GL_DYNAMIC_DRAW
    bl _glBufferData
    
    // Draw
    mov x0, #4            // GL_TRIANGLES
    mov x1, #0            // first
    mov x2, x20           // count
    bl _glDrawArrays
    
    ldp x29, x30, [sp], #16
    ret
```

### 4.5 Debug Overlays via Serial Print

```asm
// Minimal semihosting print for debugging
debug_print:
    // x0 = string pointer
    // Uses semihosting SYS_WRITE0
    
    mov x1, x0
    mov x0, #0x04         // SYS_WRITE0
    hlt #0xF000           // Angel semihosting trap
    ret

// Direct syscall print (macOS)
debug_print_syscall:
    // x0 = string, x1 = length
    stp x29, x30, [sp, #-16]!
    
    mov x2, x1            // length
    mov x1, x0            // buffer
    mov x0, #1            // stdout
    mov x16, #4           // write syscall
    svc #0x80
    
    ldp x29, x30, [sp], #16
    ret

// Print tile coverage for debugging
print_coverage_value:
    // s0 = coverage float
    
    // Convert to integer percentage
    mov w0, #100
    scvtf s1, w0
    fmul s0, s0, s1
    fcvtzs w0, s0
    
    // Convert to string
    adr x1, debug_buffer
    mov x2, #100
    udiv w3, w0, x2
    add w3, w3, #'0'
    strb w3, [x1], #1
    
    msub w0, w2, w3, w0   // remainder
    mov x2, #10
    udiv w3, w0, x2
    add w3, w3, #'0'
    strb w3, [x1], #1
    
    msub w0, w2, w3, w0
    add w0, w0, #'0'
    strb w0, [x1], #1
    
    mov w0, #'%'
    strb w0, [x1], #1
    mov w0, #'\n'
    strb w0, [x1], #1
    strb wzr, [x1]
    
    adr x0, debug_buffer
    mov x1, #5
    bl debug_print_syscall
    ret

.section __DATA,__bss
debug_buffer:
    .zero 64
```

---

## Phase 5: Cocoa Event Loop & Obj-C → ASM

### 5.1 Class & Selector Symbols

```asm
// Objective-C runtime imports
.section __DATA,__objc_classrefs,regular,no_dead_strip
.align 3
L_OBJC_CLASS_NSApplication:
    .quad _OBJC_CLASS_$_NSApplication
L_OBJC_CLASS_NSWindow:
    .quad _OBJC_CLASS_$_NSWindow
L_OBJC_CLASS_NSView:
    .quad _OBJC_CLASS_$_NSView

.section __DATA,__objc_selrefs,literal_pointers,no_dead_strip
.align 3
L_sel_alloc:
    .quad _sel_alloc
L_sel_init:
    .quad _sel_init
L_sel_sharedApplication:
    .quad _sel_sharedApplication
L_sel_setDelegate:
    .quad _sel_setDelegate
L_sel_run:
    .quad _sel_run

// Method registration
.section __DATA,__objc_methname,cstring_literals
.align 1
L_applicationDidFinishLaunching_name:
    .asciz "applicationDidFinishLaunching:"
L_drawRect_name:
    .asciz "drawRect:"
L_mouseDown_name:
    .asciz "mouseDown:"
L_keyDown_name:
    .asciz "keyDown:"
```

### 5.2 Bootstrap _main in ASM

```asm
.text
.global _main
_main:
    // Standard C main prologue
    stp x29, x30, [sp, #-32]!
    stp x20, x21, [sp, #16]
    mov x29, sp
    
    // Save argc/argv if needed
    mov x20, x0
    mov x21, x1
    
    // Create autorelease pool
    bl _objc_autoreleasePoolPush
    mov x19, x0           // save pool
    
    // Get NSApplication class
    adr x0, L_OBJC_CLASS_NSApplication
    ldr x0, [x0]
    
    // [NSApplication sharedApplication]
    adr x1, L_sel_sharedApplication
    ldr x1, [x1]
    bl _objc_msgSend
    mov x20, x0           // save app instance
    
    // Create our delegate
    bl create_app_delegate
    mov x21, x0
    
    // [app setDelegate:delegate]
    mov x0, x20
    adr x1, L_sel_setDelegate
    ldr x1, [x1]
    mov x2, x21
    bl _objc_msgSend
    
    // [app run]
    mov x0, x20
    adr x1, L_sel_run
    ldr x1, [x1]
    bl _objc_msgSend
    
    // Cleanup
    mov x0, x19
    bl _objc_autoreleasePoolPop
    
    mov x0, #0            // return 0
    ldp x20, x21, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Create minimal delegate
create_app_delegate:
    stp x29, x30, [sp, #-16]!
    
    // Get our custom delegate class
    adr x0, SimCityDelegate_class
    ldr x0, [x0]
    
    // alloc
    adr x1, L_sel_alloc
    ldr x1, [x1]
    bl _objc_msgSend
    
    // init
    adr x1, L_sel_init
    ldr x1, [x1]
    bl _objc_msgSend
    
    ldp x29, x30, [sp], #16
    ret
```

### 5.3 Implement Delegate Callbacks

```asm
// Application delegate implementation
.align 4
_applicationDidFinishLaunching_impl:
    // IMP: id self, SEL _cmd, NSNotification *note
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    // Create window
    bl create_main_window
    mov x19, x0
    
    // Create game view
    bl create_game_view
    mov x20, x0
    
    // [window setContentView:view]
    mov x0, x19
    adr x1, L_sel_setContentView
    ldr x1, [x1]
    mov x2, x20
    bl _objc_msgSend
    
    // [window makeKeyAndOrderFront:nil]
    mov x0, x19
    adr x1, L_sel_makeKeyAndOrderFront
    ldr x1, [x1]
    mov x2, #0
    bl _objc_msgSend
    
    // Initialize game systems
    bl _initSystems
    
    // Start game timer
    bl start_game_timer
    
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// View's drawRect implementation
.align 4
_drawRect_impl:
    // IMP: id self, SEL _cmd, NSRect rect
    stp x29, x30, [sp, #-32]!
    stp d0, d1, [sp, #16]   // save rect
    
    // Get current graphics context
    adr x0, L_OBJC_CLASS_NSGraphicsContext
    ldr x0, [x0]
    adr x1, L_sel_currentContext
    ldr x1, [x1]
    bl _objc_msgSend
    
    // Clear background
    bl clear_background
    
    // Draw grid
    bl draw_city_grid
    
    // Draw zones
    bl draw_zones_asm
    
    // Draw overlays
    bl draw_overlays_asm
    
    // Draw UI
    bl draw_ui_asm
    
    ldp d0, d1, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Register custom class with runtime
.section __DATA,__objc_data
.align 3
SimCityDelegate_class:
    .quad 0  // Will be filled by runtime

.section __TEXT,__objc_classlist,regular,no_dead_strip
.align 3
    .quad SimCityDelegate_meta

.section __DATA,__objc_const
.align 3
SimCityDelegate_meta:
    .quad 0                          // isa (filled by runtime)
    .quad _OBJC_CLASS_$_NSObject     // superclass
    .quad 0                          // cache
    .quad 0                          // vtable
    .quad SimCityDelegate_ro         // data

SimCityDelegate_ro:
    .long 0x0                        // flags
    .long 0x0                        // instance start
    .long 0x8                        // instance size
    .quad 0                          // ivar layout
    .quad SimCityDelegate_name       // name
    .quad SimCityDelegate_methods    // methods
    .quad 0                          // protocols
    .quad 0                          // ivars
    .quad 0                          // weak ivar layout
    .quad 0                          // properties

SimCityDelegate_name:
    .asciz "SimCityDelegate"

SimCityDelegate_methods:
    .long 24                         // entsize
    .long 1                          // count
    .quad L_applicationDidFinishLaunching_name
    .quad 0                          // types
    .quad _applicationDidFinishLaunching_impl
```

### 5.4 Autorelease Pool Management

```asm
// Wrap every callback with pool management
.macro AUTORELEASE_WRAPPER name, impl
.align 4
_\name\()_wrapper:
    stp x29, x30, [sp, #-32]!
    stp x0, x1, [sp, #16]    // save self, _cmd
    
    // Push pool
    bl _objc_autoreleasePoolPush
    mov x19, x0
    
    // Restore args and call implementation
    ldp x0, x1, [sp, #16]
    bl _\impl
    
    // Pop pool
    mov x0, x19
    bl _objc_autoreleasePoolPop
    
    ldp x29, x30, [sp], #32
    ret
.endm

// Generate wrappers
AUTORELEASE_WRAPPER drawRect, drawRect_impl
AUTORELEASE_WRAPPER mouseDown, mouseDown_impl
AUTORELEASE_WRAPPER keyDown, keyDown_impl

// Timer callback with pool
timer_callback:
    stp x29, x30, [sp, #-16]!
    
    bl _objc_autoreleasePoolPush
    mov x19, x0
    
    // Update simulation
    mov w0, #0x3c888889      // 1/60.0 in float
    fmov s0, w0
    bl _simulation_tick
    
    // Request redraw
    adr x0, g_game_view
    ldr x0, [x0]
    adr x1, L_sel_setNeedsDisplay
    ldr x1, [x1]
    mov x2, #1
    bl _objc_msgSend
    
    mov x0, x19
    bl _objc_autoreleasePoolPop
    
    ldp x29, x30, [sp], #16
    ret
```

### 5.5 Event Dispatch Loop

```asm
// Custom run loop implementation
.global _custom_run_loop
_custom_run_loop:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    
    // Get run loop
    bl _CFRunLoopGetCurrent
    mov x19, x0
    
    // Create timer source
    adr x0, timer_callback
    mov x1, #0                // context
    mov x2, #16666667         // 60 Hz in nanoseconds
    bl create_timer_source
    mov x20, x0
    
    // Add to run loop
    mov x0, x19
    mov x1, x20
    adr x2, kCFRunLoopCommonModes
    ldr x2, [x2]
    bl _CFRunLoopAddSource
    
run_loop:
    // Run for 0.1 seconds at a time
    mov x0, #0x3dcccccd      // 0.1 in float
    fmov d0, x0
    adr x1, kCFRunLoopDefaultMode
    ldr x1, [x1]
    mov x2, #0               // return after source handled
    mov x3, #0               // no timeout
    bl _CFRunLoopRunInMode
    
    // Check result
    cmp x0, #2               // kCFRunLoopRunStopped
    b.eq exit_loop
    
    // Check for quit flag
    adr x1, g_quit_flag
    ldr w1, [x1]
    cbz w1, run_loop
    
exit_loop:
    // Cleanup
    mov x0, x19
    mov x1, x20
    adr x2, kCFRunLoopCommonModes
    ldr x2, [x2]
    bl _CFRunLoopRemoveSource
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Direct NSEvent processing
process_event_queue:
    stp x29, x30, [sp, #-16]!
    
event_loop:
    // [NSApp nextEventMatchingMask:untilDate:inMode:dequeue:]
    adr x0, g_app_instance
    ldr x0, [x0]
    adr x1, L_sel_nextEventMatchingMask
    ldr x1, [x1]
    mov x2, #-1              // NSAnyEventMask
    mov x3, #0               // untilDate: nil
    adr x4, NSDefaultRunLoopMode
    ldr x4, [x4]
    mov x5, #1               // dequeue: YES
    bl _objc_msgSend
    
    cbz x0, no_event
    
    // [NSApp sendEvent:event]
    mov x2, x0               // event
    adr x0, g_app_instance
    ldr x0, [x0]
    adr x1, L_sel_sendEvent
    ldr x1, [x1]
    bl _objc_msgSend
    
    b event_loop
    
no_event:
    ldp x29, x30, [sp], #16
    ret

.section __DATA,__bss
.align 3
g_app_instance:
    .quad 0
g_game_view:
    .quad 0
g_quit_flag:
    .long 0
```

---

## Implementation Strategy

### Phase Order
1. **Phase 3 First**: A* pathfinder provides immediate visible results
2. **Phase 2 Next**: Utilities system shows dramatic NEON speedup
3. **Phase 1**: Core simulation ties everything together
4. **Phase 4**: Renderer makes everything pretty
5. **Phase 5**: Final Cocoa replacement completes pure ASM

### Testing Approach
- Each phase has standalone test harness
- Bit-exact validation against C implementation
- Performance benchmarks at each step
- Visual regression tests via screenshots

### Optimization Targets
- 10× speedup on flood-fill (NEON)
- 5× speedup on pathfinding (heap)
- 3× speedup on simulation tick
- 2× speedup on rendering
- 50% reduction in binary size

### Key Techniques
- NEON for all parallel operations
- Branchless code where possible
- Inline critical loops
- Static memory allocation
- Direct syscalls bypass libc

This roadmap provides a clear path from your current mixed implementation to a pure ARM64 assembly city simulator that will run blazingly fast on Apple Silicon!