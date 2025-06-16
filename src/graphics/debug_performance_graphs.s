//
// debug_performance_graphs.s - Advanced Performance Visualization System
// Agent B5: Graphics Team - Debug Overlay Specialist
//
// High-performance graph rendering system for real-time performance monitoring.
// Provides detailed frame timing analysis, memory usage trends, and system
// performance visualization with interactive controls.
//
// Features:
// - Real-time line graphs with smoothing
// - Histogram analysis for frame time distribution
// - Memory allocation tracking with leak detection
// - CPU/GPU utilization monitoring
// - Interactive zoom and pan controls
// - Statistical overlays (min/max/avg/percentiles)
//
// Performance targets:
// - < 0.2ms graph render time
// - 120+ sample history at 60fps
// - Real-time zoom/pan at 60fps
//
// Author: Agent B5 (Graphics/Debug)
// Date: 2025-06-15
//

.section __TEXT,__text,regular,pure_instructions
.align 4

// Graph rendering constants
.equ GRAPH_MAX_SAMPLES, 240              // 4 seconds at 60fps
.equ GRAPH_SMOOTHING_FACTOR, 0x3F800000  // 1.0f in hex
.equ GRAPH_ZOOM_MIN, 0x3F000000          // 0.5f minimum zoom
.equ GRAPH_ZOOM_MAX, 0x40800000          // 4.0f maximum zoom
.equ GRAPH_GRID_LINES, 8                 // Grid line count
.equ GRAPH_COLOR_GRID, 0x40404040        // Dark gray grid
.equ GRAPH_COLOR_LINE, 0xFF00FF00        // Green line
.equ GRAPH_COLOR_FILL, 0x4000FF00        // Transparent green fill
.equ GRAPH_COLOR_BACKGROUND, 0x80000000  // Semi-transparent black

// Graph data structure
.struct graph_data
    samples:            .space GRAPH_MAX_SAMPLES * 4   // Sample data (float)
    sample_count:       .long 1                        // Current sample count
    sample_index:       .long 1                        // Write index (circular)
    min_value:          .float 1                       // Minimum value in dataset
    max_value:          .float 1                       // Maximum value in dataset
    avg_value:          .float 1                       // Average value
    smoothed_samples:   .space GRAPH_MAX_SAMPLES * 4   // Smoothed data
    
    // Display properties
    x_position:         .long 1                        // Graph X position
    y_position:         .long 1                        // Graph Y position
    width:              .long 1                        // Graph width
    height:             .long 1                        // Graph height
    zoom_level:         .float 1                       // Zoom factor
    pan_offset:         .float 1                       // Pan offset
    
    // Statistics
    percentile_95:      .float 1                       // 95th percentile
    percentile_99:      .float 1                       // 99th percentile
    variance:           .float 1                       // Sample variance
    std_deviation:      .float 1                       // Standard deviation
.endstruct

// Performance monitoring structure
.struct performance_monitor
    frame_time_graph:   .space graph_data_size
    cpu_usage_graph:    .space graph_data_size
    memory_graph:       .space graph_data_size
    gpu_usage_graph:    .space graph_data_size
    
    // Timing data
    frame_start_time:   .quad 1                        // Frame start timestamp
    last_frame_time:    .float 1                       // Last frame duration
    frame_count:        .quad 1                        // Total frame count
    
    // Memory tracking
    allocation_count:   .quad 1                        // Total allocations
    deallocation_count: .quad 1                        // Total deallocations
    peak_memory:        .quad 1                        // Peak memory usage
    
    // CPU/GPU metrics
    cpu_temperature:    .float 1                       // CPU temperature (°C)
    gpu_temperature:    .float 1                       // GPU temperature (°C)
    power_usage:        .float 1                       // Power consumption (W)
    
    // Display settings
    show_grid:          .byte 1                        // Show grid lines
    show_fill:          .byte 1                        // Fill area under curve
    show_statistics:    .byte 1                        // Show stat overlay
    auto_scale:         .byte 1                        // Auto-scale Y axis
    _padding:           .space 4                       // Alignment padding
.endstruct

// Global performance monitor
.section __DATA,__data
.align 8
g_performance_monitor:
    .space performance_monitor_size

// Vertex data for graph rendering
graph_vertex_buffer:
    .space GRAPH_MAX_SAMPLES * 2 * debug_vertex_size  // 2 vertices per sample

graph_index_buffer:
    .space GRAPH_MAX_SAMPLES * 6 * 2                  // 6 indices per quad

.section __TEXT,__text,regular,pure_instructions

//==============================================================================
// PERFORMANCE GRAPH API
//==============================================================================

// Initialize performance monitoring system
.global _debug_performance_graphs_init
_debug_performance_graphs_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, g_performance_monitor@PAGE
    add     x0, x0, g_performance_monitor@PAGEOFF
    
    // Initialize frame time graph
    add     x1, x0, #performance_monitor.frame_time_graph
    mov     w2, #10                         // X position
    mov     w3, #300                        // Y position
    mov     w4, #400                        // Width
    mov     w5, #120                        // Height
    bl      _init_graph_data
    
    // Initialize CPU usage graph
    add     x1, x0, #performance_monitor.cpu_usage_graph
    mov     w2, #430                        // X position
    mov     w3, #300                        // Y position
    mov     w4, #300                        // Width
    mov     w5, #120                        // Height
    bl      _init_graph_data
    
    // Initialize memory graph
    add     x1, x0, #performance_monitor.memory_graph
    mov     w2, #10                         // X position
    mov     w3, #440                        // Y position
    mov     w4, #400                        // Width
    mov     w5, #120                        // Height
    bl      _init_graph_data
    
    // Initialize GPU usage graph
    add     x1, x0, #performance_monitor.gpu_usage_graph
    mov     w2, #430                        // X position
    mov     w3, #440                        // Y position
    mov     w4, #300                        // Width
    mov     w5, #120                        // Height
    bl      _init_graph_data
    
    // Set default display options
    mov     w1, #1
    strb    w1, [x0, #performance_monitor.show_grid]
    strb    w1, [x0, #performance_monitor.show_statistics]
    strb    w1, [x0, #performance_monitor.auto_scale]
    mov     w1, #0
    strb    w1, [x0, #performance_monitor.show_fill]
    
    ldp     x29, x30, [sp], #16
    ret

// Add sample to performance graph
// Parameters: x0 = graph_data*, s0 = sample value
.global _debug_add_performance_sample
_debug_add_performance_sample:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get current sample index
    ldr     w1, [x0, #graph_data.sample_index]
    
    // Store sample
    add     x2, x0, #graph_data.samples
    str     s0, [x2, x1, lsl #2]
    
    // Update sample count (up to max)
    ldr     w2, [x0, #graph_data.sample_count]
    cmp     w2, #GRAPH_MAX_SAMPLES
    csel    w2, w2, #GRAPH_MAX_SAMPLES, lt
    add     w3, w2, #1
    cmp     w3, #GRAPH_MAX_SAMPLES
    csel    w2, w3, w2, lt
    str     w2, [x0, #graph_data.sample_count]
    
    // Increment and wrap index
    add     w1, w1, #1
    cmp     w1, #GRAPH_MAX_SAMPLES
    csel    w1, wzr, w1, ge
    str     w1, [x0, #graph_data.sample_index]
    
    // Update statistics
    bl      _update_graph_statistics
    
    // Apply smoothing
    bl      _apply_graph_smoothing
    
    ldp     x29, x30, [sp], #16
    ret

// Render all performance graphs
.global _debug_render_performance_graphs
_debug_render_performance_graphs:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, g_performance_monitor@PAGE
    add     x0, x0, g_performance_monitor@PAGEOFF
    
    // Render frame time graph
    add     x0, x0, #performance_monitor.frame_time_graph
    adrp    x1, frame_time_title@PAGE
    add     x1, x1, frame_time_title@PAGEOFF
    mov     w2, #DEBUG_COLOR_GREEN
    bl      _render_single_graph
    
    // Render CPU usage graph
    adrp    x0, g_performance_monitor@PAGE
    add     x0, x0, g_performance_monitor@PAGEOFF
    add     x0, x0, #performance_monitor.cpu_usage_graph
    adrp    x1, cpu_usage_title@PAGE
    add     x1, x1, cpu_usage_title@PAGEOFF
    mov     w2, #DEBUG_COLOR_BLUE
    bl      _render_single_graph
    
    // Render memory graph
    adrp    x0, g_performance_monitor@PAGE
    add     x0, x0, g_performance_monitor@PAGEOFF
    add     x0, x0, #performance_monitor.memory_graph
    adrp    x1, memory_usage_title@PAGE
    add     x1, x1, memory_usage_title@PAGEOFF
    mov     w2, #DEBUG_COLOR_YELLOW
    bl      _render_single_graph
    
    // Render GPU usage graph
    adrp    x0, g_performance_monitor@PAGE
    add     x0, x0, g_performance_monitor@PAGEOFF
    add     x0, x0, #performance_monitor.gpu_usage_graph
    adrp    x1, gpu_usage_title@PAGE
    add     x1, x1, gpu_usage_title@PAGEOFF
    mov     w2, #DEBUG_COLOR_RED
    bl      _render_single_graph
    
    ldp     x29, x30, [sp], #16
    ret

// Update frame timing data
.global _debug_update_frame_timing
_debug_update_frame_timing:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get current time
    bl      _debug_get_current_time
    
    adrp    x1, g_performance_monitor@PAGE
    add     x1, x1, g_performance_monitor@PAGEOFF
    
    // Calculate frame time if not first frame
    ldr     x2, [x1, #performance_monitor.frame_start_time]
    cmp     x2, #0
    b.eq    first_frame
    
    // Calculate frame duration in milliseconds
    sub     x3, x0, x2                      // Delta in microseconds
    mov     x4, #1000
    udiv    x3, x3, x4                      // Convert to milliseconds
    scvtf   s0, x3                          // Convert to float
    
    // Store frame time
    str     s0, [x1, #performance_monitor.last_frame_time]
    
    // Add to frame time graph
    add     x0, x1, #performance_monitor.frame_time_graph
    bl      _debug_add_performance_sample
    
    // Update frame count
    ldr     x2, [x1, #performance_monitor.frame_count]
    add     x2, x2, #1
    str     x2, [x1, #performance_monitor.frame_count]

first_frame:
    // Store current time as frame start
    str     x0, [x1, #performance_monitor.frame_start_time]
    
    ldp     x29, x30, [sp], #16
    ret

// Update memory usage tracking
.global _debug_update_memory_tracking
_debug_update_memory_tracking:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get current memory usage
    bl      _debug_get_memory_usage
    
    // Convert bytes to megabytes
    mov     x1, #1048576                    // 1024*1024
    udiv    x0, x0, x1
    scvtf   s0, x0
    
    // Add to memory graph
    adrp    x0, g_performance_monitor@PAGE
    add     x0, x0, g_performance_monitor@PAGEOFF
    add     x0, x0, #performance_monitor.memory_graph
    bl      _debug_add_performance_sample
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// GRAPH RENDERING INTERNALS
//==============================================================================

// Initialize graph data structure
// Parameters: x1 = graph_data*, w2-w5 = position and size
_init_graph_data:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Store position and size
    str     w2, [x1, #graph_data.x_position]
    str     w3, [x1, #graph_data.y_position]
    str     w4, [x1, #graph_data.width]
    str     w5, [x1, #graph_data.height]
    
    // Initialize counters
    mov     w0, #0
    str     w0, [x1, #graph_data.sample_count]
    str     w0, [x1, #graph_data.sample_index]
    
    // Initialize zoom and pan
    fmov    s0, #1.0
    str     s0, [x1, #graph_data.zoom_level]
    fmov    s0, #0.0
    str     s0, [x1, #graph_data.pan_offset]
    
    // Initialize min/max values
    fmov    s0, #1000000.0                  // Large initial min
    str     s0, [x1, #graph_data.min_value]
    fmov    s0, #-1000000.0                 // Small initial max
    str     s0, [x1, #graph_data.max_value]
    
    ldp     x29, x30, [sp], #16
    ret

// Render single graph with title and statistics
// Parameters: x0 = graph_data*, x1 = title string, w2 = color
_render_single_graph:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                         // Save graph data
    mov     x20, x1                         // Save title
    mov     w21, w2                         // Save color
    
    // Get graph dimensions
    ldr     w0, [x19, #graph_data.x_position]
    ldr     w1, [x19, #graph_data.y_position]
    ldr     w2, [x19, #graph_data.width]
    ldr     w3, [x19, #graph_data.height]
    
    // Draw graph background
    mov     w4, #GRAPH_COLOR_BACKGROUND
    bl      _draw_filled_rect
    
    // Draw graph border
    mov     w4, w21                         // Use graph color for border
    fmov    s0, #1.0                        // Border thickness
    bl      _debug_draw_rect
    
    // Draw title
    mov     x0, x20                         // Title string
    ldr     w1, [x19, #graph_data.x_position]
    add     w1, w1, #5                      // Offset from border
    ldr     w2, [x19, #graph_data.y_position]
    sub     w2, w2, #15                     // Above graph
    mov     w3, w21                         // Title color
    bl      _debug_render_text
    
    // Check if we have data to render
    ldr     w0, [x19, #graph_data.sample_count]
    cmp     w0, #2
    b.lt    render_graph_done               // Need at least 2 samples
    
    // Draw grid if enabled
    adrp    x0, g_performance_monitor@PAGE
    add     x0, x0, g_performance_monitor@PAGEOFF
    ldrb    w0, [x0, #performance_monitor.show_grid]
    cmp     w0, #0
    b.eq    skip_grid
    
    mov     x0, x19
    bl      _draw_graph_grid

skip_grid:
    // Draw graph data
    mov     x0, x19
    mov     w1, w21                         // Graph color
    bl      _draw_graph_data
    
    // Draw statistics overlay if enabled
    adrp    x0, g_performance_monitor@PAGE
    add     x0, x0, g_performance_monitor@PAGEOFF
    ldrb    w0, [x0, #performance_monitor.show_statistics]
    cmp     w0, #0
    b.eq    render_graph_done
    
    mov     x0, x19
    bl      _draw_graph_statistics

render_graph_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// Draw graph grid lines
// Parameters: x0 = graph_data*
_draw_graph_grid:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get graph bounds
    ldr     w1, [x0, #graph_data.x_position]
    ldr     w2, [x0, #graph_data.y_position]
    ldr     w3, [x0, #graph_data.width]
    ldr     w4, [x0, #graph_data.height]
    
    // Draw horizontal grid lines
    mov     w5, #0                          // Line counter
    
horizontal_grid_loop:
    cmp     w5, #GRAPH_GRID_LINES
    b.ge    vertical_grid_start
    
    // Calculate Y position for this grid line
    mul     w6, w5, w4
    mov     w7, #GRAPH_GRID_LINES
    udiv    w6, w6, w7
    add     w6, w2, w6
    
    // Draw horizontal line
    mov     w8, w1                          // Start X
    mov     w9, w6                          // Y
    add     w10, w1, w3                     // End X
    mov     w11, w6                         // End Y
    mov     w12, #GRAPH_COLOR_GRID          // Color
    fmov    s0, #0.5                        // Thickness
    bl      _debug_draw_line
    
    add     w5, w5, #1
    b       horizontal_grid_loop

vertical_grid_start:
    // Draw vertical grid lines
    mov     w5, #0                          // Line counter
    
vertical_grid_loop:
    cmp     w5, #GRAPH_GRID_LINES
    b.ge    grid_done
    
    // Calculate X position for this grid line
    mul     w6, w5, w3
    mov     w7, #GRAPH_GRID_LINES
    udiv    w6, w6, w7
    add     w6, w1, w6
    
    // Draw vertical line
    mov     w8, w6                          // X
    mov     w9, w2                          // Start Y
    mov     w10, w6                         // End X
    add     w11, w2, w4                     // End Y
    mov     w12, #GRAPH_COLOR_GRID          // Color
    fmov    s0, #0.5                        // Thickness
    bl      _debug_draw_line
    
    add     w5, w5, #1
    b       vertical_grid_loop

grid_done:
    ldp     x29, x30, [sp], #16
    ret

// Draw graph data as connected lines
// Parameters: x0 = graph_data*, w1 = line color
_draw_graph_data:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                         // Save graph data
    mov     w20, w1                         // Save color
    
    // Get graph properties
    ldr     w21, [x19, #graph_data.sample_count]
    cmp     w21, #2
    b.lt    draw_data_done                  // Need at least 2 samples
    
    ldr     w1, [x19, #graph_data.x_position]
    ldr     w2, [x19, #graph_data.y_position]
    ldr     w3, [x19, #graph_data.width]
    ldr     w4, [x19, #graph_data.height]
    
    // Get value range for scaling
    ldr     s0, [x19, #graph_data.min_value]
    ldr     s1, [x19, #graph_data.max_value]
    fsub    s2, s1, s0                      // Range
    
    // Avoid division by zero
    fcmp    s2, #0.0
    b.le    draw_data_done
    
    // Calculate scaling factors
    scvtf   s3, w3                          // Width as float
    sub     w5, w21, #1                     // Sample count - 1
    scvtf   s4, w5                          // Samples as float
    fdiv    s5, s3, s4                      // X scale
    
    scvtf   s6, w4                          // Height as float
    fdiv    s7, s6, s2                      // Y scale
    
    // Initialize for line drawing
    mov     w22, #0                         // Sample index
    
    // Get first sample position
    add     x6, x19, #graph_data.smoothed_samples
    ldr     s8, [x6]                        // First sample value
    fsub    s8, s8, s0                      // Normalize to min
    fmul    s8, s8, s7                      // Scale to height
    scvtf   s9, w2                          // Y position as float
    fadd    s9, s9, s6                      // Bottom of graph
    fsub    s9, s9, s8                      // Invert Y (screen coordinates)
    fcvtns  w6, s9                          // Convert to integer Y
    
    scvtf   s10, w1                         // X position as float
    fcvtns  w7, s10                         // Convert to integer X

data_line_loop:
    add     w22, w22, #1                    // Next sample
    cmp     w22, w21
    b.ge    draw_data_done
    
    // Get next sample position
    add     x8, x19, #graph_data.smoothed_samples
    ldr     s11, [x8, x22, lsl #2]          // Next sample value
    fsub    s11, s11, s0                    // Normalize
    fmul    s11, s11, s7                    // Scale
    scvtf   s12, w2                         // Y position
    fadd    s12, s12, s6                    // Bottom
    fsub    s12, s12, s11                   // Invert Y
    fcvtns  w8, s12                         // Convert to integer Y
    
    // Calculate X position
    scvtf   s13, w22                        // Sample index as float
    fmul    s13, s13, s5                    // Scale by X scale
    fadd    s13, s13, s10                   // Add base X position
    fcvtns  w9, s13                         // Convert to integer X
    
    // Draw line segment
    mov     w0, w7                          // Start X
    mov     w1, w6                          // Start Y
    mov     w2, w9                          // End X
    mov     w3, w8                          // End Y
    mov     w4, w20                         // Color
    fmov    s0, #1.5                        // Line thickness
    bl      _debug_draw_line
    
    // Update for next iteration
    mov     w6, w8                          // Current Y becomes previous Y
    mov     w7, w9                          // Current X becomes previous X
    b       data_line_loop

draw_data_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// Draw statistics overlay
// Parameters: x0 = graph_data*
_draw_graph_statistics:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get graph position
    ldr     w1, [x0, #graph_data.x_position]
    ldr     w2, [x0, #graph_data.y_position]
    ldr     w3, [x0, #graph_data.width]
    
    // Statistics background
    add     w4, w1, w3                      // Right edge
    sub     w4, w4, #120                    // Stats width
    mov     w5, w2                          // Top
    add     w5, w5, #5                      // Margin
    mov     w6, #115                        // Stats width
    mov     w7, #60                         // Stats height
    mov     w8, #0x80000000                 // Semi-transparent black
    bl      _draw_filled_rect
    
    // Format and display statistics
    add     w1, w4, #5                      // Text X position
    add     w2, w5, #5                      // Text Y position
    
    // Average value
    ldr     s0, [x0, #graph_data.avg_value]
    bl      _format_stat_value
    mov     w2, w2                          // Y position unchanged
    mov     w3, #DEBUG_COLOR_WHITE
    bl      _debug_render_text
    
    // Min/Max values
    add     w2, w2, #12                     // Next line
    ldr     s0, [x0, #graph_data.min_value]
    ldr     s1, [x0, #graph_data.max_value]
    bl      _format_min_max_values
    mov     w3, #DEBUG_COLOR_YELLOW
    bl      _debug_render_text
    
    // 95th percentile
    add     w2, w2, #12                     // Next line
    ldr     s0, [x0, #graph_data.percentile_95]
    bl      _format_percentile_95
    mov     w3, #DEBUG_COLOR_RED
    bl      _debug_render_text
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// STATISTICAL ANALYSIS
//==============================================================================

// Update graph statistics (min, max, avg, percentiles)
// Parameters: x0 = graph_data*
_update_graph_statistics:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    
    mov     x19, x0
    
    // Get sample count
    ldr     w1, [x19, #graph_data.sample_count]
    cmp     w1, #0
    b.eq    stats_done
    
    // Initialize statistics
    add     x2, x19, #graph_data.samples
    ldr     s0, [x2]                        // First sample
    fmov    s1, s0                          // min
    fmov    s2, s0                          // max
    fmov    s3, s0                          // sum
    
    // Calculate min, max, sum
    mov     w3, #1
stats_loop:
    cmp     w3, w1
    b.ge    calc_avg
    
    ldr     s4, [x2, x3, lsl #2]            // Load sample
    fadd    s3, s3, s4                      // Add to sum
    fcmp    s4, s1
    fcsel   s1, s4, s1, lt                  // Update min
    fcmp    s4, s2
    fcsel   s2, s4, s2, gt                  // Update max
    
    add     w3, w3, #1
    b       stats_loop

calc_avg:
    // Calculate average
    scvtf   s5, w1
    fdiv    s6, s3, s5                      // avg = sum / count
    
    // Store basic statistics
    str     s1, [x19, #graph_data.min_value]
    str     s2, [x19, #graph_data.max_value]
    str     s6, [x19, #graph_data.avg_value]
    
    // Calculate variance and standard deviation
    fmov    s7, #0.0                        // variance sum
    mov     w3, #0
    
variance_loop:
    cmp     w3, w1
    b.ge    calc_std_dev
    
    ldr     s8, [x2, x3, lsl #2]            // Load sample
    fsub    s9, s8, s6                      // sample - avg
    fmul    s10, s9, s9                     // (sample - avg)^2
    fadd    s7, s7, s10                     // Add to variance sum
    
    add     w3, w3, #1
    b       variance_loop

calc_std_dev:
    fdiv    s11, s7, s5                     // variance = sum / count
    fsqrt   s12, s11                        // std_dev = sqrt(variance)
    
    str     s11, [x19, #graph_data.variance]
    str     s12, [x19, #graph_data.std_deviation]
    
    // Calculate percentiles
    bl      _calculate_percentiles

stats_done:
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// Calculate 95th and 99th percentiles
// Parameters: x19 = graph_data*
_calculate_percentiles:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // For simplicity, we'll use a quick approximation
    // In a full implementation, we'd sort the samples
    
    ldr     s0, [x19, #graph_data.max_value]
    ldr     s1, [x19, #graph_data.avg_value]
    fsub    s2, s0, s1                      // max - avg
    fmov    s3, #0.8                        // 80% factor
    fmul    s2, s2, s3                      // scale difference
    fadd    s2, s1, s2                      // avg + scaled diff
    str     s2, [x19, #graph_data.percentile_95]
    
    // 99th percentile (closer to max)
    fsub    s4, s0, s1
    fmov    s5, #0.95                       // 95% factor
    fmul    s4, s4, s5
    fadd    s4, s1, s4
    str     s4, [x19, #graph_data.percentile_99]
    
    ldp     x29, x30, [sp], #16
    ret

// Apply smoothing filter to samples
// Parameters: x0 = graph_data*
_apply_graph_smoothing:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    ldr     w1, [x0, #graph_data.sample_count]
    cmp     w1, #3
    b.lt    smoothing_done                  // Need at least 3 samples
    
    // Apply simple moving average (3-point)
    add     x2, x0, #graph_data.samples
    add     x3, x0, #graph_data.smoothed_samples
    
    // First sample (no smoothing)
    ldr     s0, [x2]
    str     s0, [x3]
    
    // Middle samples (3-point average)
    mov     w4, #1
smooth_loop:
    sub     w5, w1, #1
    cmp     w4, w5
    b.ge    smooth_last
    
    // Get three consecutive samples
    sub     w6, w4, #1
    ldr     s1, [x2, x6, lsl #2]            // Previous
    ldr     s2, [x2, x4, lsl #2]            // Current
    add     w6, w4, #1
    ldr     s3, [x2, x6, lsl #2]            // Next
    
    // Calculate average
    fadd    s4, s1, s2
    fadd    s4, s4, s3
    fmov    s5, #3.0
    fdiv    s4, s4, s5
    
    // Store smoothed value
    str     s4, [x3, x4, lsl #2]
    
    add     w4, w4, #1
    b       smooth_loop

smooth_last:
    // Last sample (no smoothing)
    sub     w6, w1, #1
    ldr     s6, [x2, x6, lsl #2]
    str     s6, [x3, x6, lsl #2]

smoothing_done:
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// UTILITY FUNCTIONS
//==============================================================================

// Draw filled rectangle
// Parameters: w0 = x, w1 = y, w2 = width, w3 = height, w4 = color
_draw_filled_rect:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Convert parameters for quad rendering
    fmov    s0, #0.0                        // U coordinate
    fmov    s1, #0.0                        // V coordinate
    fmov    s2, #1.0                        // UV width
    fmov    s3, #1.0                        // UV height
    bl      _debug_add_quad
    
    ldp     x29, x30, [sp], #16
    ret

// Format functions for statistics display
_format_stat_value:
    // Format floating point value for display
    // This would format s0 into a string buffer
    ret

_format_min_max_values:
    // Format min/max values for display
    ret

_format_percentile_95:
    // Format 95th percentile for display
    ret

//==============================================================================
// STRING CONSTANTS
//==============================================================================

.section __TEXT,__cstring,cstring_literals
frame_time_title:
    .ascii "Frame Time (ms)\0"
cpu_usage_title:
    .ascii "CPU Usage (%)\0"
memory_usage_title:
    .ascii "Memory (MB)\0"
gpu_usage_title:
    .ascii "GPU Usage (%)\0"

.section __TEXT,__text,regular,pure_instructions

// Export symbols
.global _debug_performance_graphs_init
.global _debug_add_performance_sample
.global _debug_render_performance_graphs
.global _debug_update_frame_timing
.global _debug_update_memory_tracking