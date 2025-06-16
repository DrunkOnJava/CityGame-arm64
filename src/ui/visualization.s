// SimCity ARM64 Assembly - Data Visualization Systems
// Agent 7: User Interface & Interaction
//
// Real-time graphs and heat maps for city data
// Provides data overlays, charts, and statistical displays
// Optimized for smooth 60fps updates with large datasets

.global _viz_init
.global _viz_update
.global _viz_render
.global _viz_create_heatmap
.global _viz_create_graph
.global _viz_update_heatmap
.global _viz_update_graph
.global _viz_render_heatmap
.global _viz_render_graph
.global _viz_set_data_source
.global _viz_get_statistics
.global _viz_create_minimap
.global _viz_update_minimap
.global _viz_render_minimap
.global _viz_minimap_click

.align 2

// Visualization types
.equ VIZ_TYPE_HEATMAP, 0
.equ VIZ_TYPE_LINE_GRAPH, 1
.equ VIZ_TYPE_BAR_CHART, 2
.equ VIZ_TYPE_PIE_CHART, 3
.equ VIZ_TYPE_OVERLAY, 4
.equ VIZ_TYPE_MINIMAP, 5

// Data types for visualization
.equ DATA_POPULATION, 0
.equ DATA_HAPPINESS, 1
.equ DATA_POLLUTION, 2
.equ DATA_TRAFFIC, 3
.equ DATA_POWER, 4
.equ DATA_WATER, 5
.equ DATA_CRIME, 6
.equ DATA_FIRE_RISK, 7
.equ DATA_LAND_VALUE, 8
.equ DATA_MONEY, 9
.equ DATA_TAX_INCOME, 10
.equ DATA_EXPENSES, 11

// Heat map constants
.equ HEATMAP_MAX_WIDTH, 256
.equ HEATMAP_MAX_HEIGHT, 256
.equ HEATMAP_COLORS, 8
.equ HEATMAP_SMOOTH_RADIUS, 2

// Graph constants
.equ GRAPH_MAX_POINTS, 1000
.equ GRAPH_MAX_SERIES, 8
.equ GRAPH_HISTORY_SECONDS, 300  // 5 minutes

// Colors for heat maps (from cool to hot)
.equ COLOR_HEAT_0, 0xFF000080    // Dark blue (cold)
.equ COLOR_HEAT_1, 0xFF0040C0    // Blue
.equ COLOR_HEAT_2, 0xFF0080FF    // Light blue
.equ COLOR_HEAT_3, 0xFF00C080    // Cyan
.equ COLOR_HEAT_4, 0xFF40FF40    // Green
.equ COLOR_HEAT_5, 0xFF80FF00    // Yellow-green
.equ COLOR_HEAT_6, 0xFFFFFF00    // Yellow
.equ COLOR_HEAT_7, 0xFFFF8000    // Orange
.equ COLOR_HEAT_8, 0xFFFF0000    // Red (hot)

// Graph colors
.equ COLOR_GRAPH_BG, 0xE0202020
.equ COLOR_GRAPH_GRID, 0xFF404040
.equ COLOR_GRAPH_AXIS, 0xFF808080
.equ COLOR_GRAPH_LINE_1, 0xFF00FF00
.equ COLOR_GRAPH_LINE_2, 0xFF0080FF
.equ COLOR_GRAPH_LINE_3, 0xFFFF8000
.equ COLOR_GRAPH_LINE_4, 0xFFFF00FF

// Visualization Context Structure
.struct 0
viz_heatmaps:          .space 8     // Array of heatmap contexts
viz_graphs:            .space 8     // Array of graph contexts
viz_num_heatmaps:      .space 4     // Number of active heatmaps
viz_num_graphs:        .space 4     // Number of active graphs
viz_update_counter:    .space 4     // Frame counter for updates
viz_data_cache:        .space 8     // Cached data for performance
viz_render_targets:    .space 8     // Render target textures
viz_context_size:      .space 0

// Heatmap Structure
.struct 0
hm_id:                 .space 4     // Unique ID
hm_data_type:          .space 4     // Type of data to visualize
hm_width:              .space 4     // Width in data points
hm_height:             .space 4     // Height in data points
hm_world_x:            .space 4     // World X offset
hm_world_y:            .space 4     // World Y offset
hm_scale:              .space 4     // Scale factor
hm_data_buffer:        .space 8     // Float data buffer
hm_color_buffer:       .space 8     // Color buffer (RGBA)
hm_texture:           .space 8      // GPU texture handle
hm_min_value:         .space 4      // Data range minimum
hm_max_value:         .space 4      // Data range maximum
hm_smooth_enabled:    .space 4      // Enable smoothing
hm_update_rate:       .space 4      // Update frequency (frames)
hm_last_update:       .space 4      // Last update frame
hm_visible:           .space 4      // Visibility flag
hm_alpha:             .space 4      // Transparency
hm_struct_size:       .space 0

// Graph Structure
.struct 0
graph_id:             .space 4      // Unique ID
graph_type:           .space 4      // Graph type (line, bar, etc)
graph_data_types:     .space 32     // Data types (up to 8 series)
graph_num_series:     .space 4      // Number of data series
graph_max_points:     .space 4      // Maximum points to display
graph_time_window:    .space 4      // Time window in seconds
graph_position:       .space 8      // Screen position (x,y)
graph_size:           .space 8      // Size (w,h)
graph_data_buffer:    .space 8      // Data points buffer
graph_time_buffer:    .space 8      // Time stamps buffer
graph_current_index:  .space 4      // Current write index
graph_min_y:          .space 4      // Y-axis minimum
graph_max_y:          .space 4      // Y-axis maximum
graph_auto_scale:     .space 4      // Auto-scale Y axis
graph_grid_enabled:   .space 4      // Show grid
graph_legend_enabled: .space 4      // Show legend
graph_visible:        .space 4      // Visibility flag
graph_struct_size:    .space 0

// Mini-map Structure
.struct 0
minimap_id:           .space 4      // Unique ID
minimap_position:     .space 8      // Screen position (x,y)
minimap_size:         .space 8      // Size (w,h)
minimap_world_size:   .space 8      // World size covered (w,h)
minimap_scale:        .space 4      // Scale factor (world to minimap)
minimap_texture:      .space 8      // Main minimap texture
minimap_overlay_tex:  .space 8      // Overlay texture for data
minimap_camera_rect:  .space 16     // Camera viewport rectangle
minimap_visible:      .space 4      // Visibility flag
minimap_mode:         .space 4      // Display mode (city, zones, data)
minimap_last_update:  .space 4      // Last update frame
minimap_click_enabled: .space 4     // Enable click-to-move camera
minimap_struct_size:  .space 0

// Initialize visualization system
_viz_init:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    // Allocate visualization context
    mov x0, viz_context_size
    bl _malloc
    cbz x0, viz_init_fail
    
    adrp x19, viz_context@PAGE
    add x19, x19, viz_context@PAGEOFF
    str x0, [x19]
    mov x20, x0
    
    // Clear context
    mov x1, #0
    mov x2, viz_context_size
    bl _memset
    
    // Allocate heatmap array
    mov x0, #16             // Max 16 heatmaps
    mov x1, hm_struct_size
    mul x0, x0, x1
    bl _malloc
    cbz x0, viz_init_fail
    str x0, [x20, viz_heatmaps]
    
    // Allocate graph array
    mov x0, #16             // Max 16 graphs
    mov x1, graph_struct_size
    mul x0, x0, x1
    bl _malloc
    cbz x0, viz_init_fail
    str x0, [x20, viz_graphs]
    
    // Initialize default heat map colors
    bl _viz_init_color_tables
    
    mov x0, #1
    b viz_init_done
    
viz_init_fail:
    mov x0, #0
    
viz_init_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Update all visualizations
_viz_update:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _viz_get_context
    cbz x0, viz_update_done
    mov x19, x0
    
    // Increment update counter
    ldr w0, [x19, viz_update_counter]
    add w0, w0, #1
    str w0, [x19, viz_update_counter]
    
    // Update all heatmaps
    ldr w20, [x19, viz_num_heatmaps]
    mov w21, #0
    
update_heatmaps_loop:
    cmp w21, w20
    b.ge update_graphs
    
    mov w0, w21
    bl _viz_update_heatmap_by_index
    
    add w21, w21, #1
    b update_heatmaps_loop
    
update_graphs:
    // Update all graphs
    ldr w20, [x19, viz_num_graphs]
    mov w21, #0
    
update_graphs_loop:
    cmp w21, w20
    b.ge viz_update_done
    
    mov w0, w21
    bl _viz_update_graph_by_index
    
    add w21, w21, #1
    b update_graphs_loop
    
viz_update_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Render all visible visualizations
_viz_render:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _viz_get_context
    cbz x0, viz_render_done
    mov x19, x0
    
    // Render all visible heatmaps
    ldr w20, [x19, viz_num_heatmaps]
    mov w21, #0
    
render_heatmaps_loop:
    cmp w21, w20
    b.ge render_graphs
    
    mov w0, w21
    bl _viz_render_heatmap_by_index
    
    add w21, w21, #1
    b render_heatmaps_loop
    
render_graphs:
    // Render all visible graphs
    ldr w20, [x19, viz_num_graphs]
    mov w21, #0
    
render_graphs_loop:
    cmp w21, w20
    b.ge viz_render_done
    
    mov w0, w21
    bl _viz_render_graph_by_index
    
    add w21, w21, #1
    b render_graphs_loop
    
viz_render_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Create new heatmap
// Parameters: w0 = data_type, w1 = width, w2 = height, w3 = world_x, w4 = world_y
// Returns: x0 = heatmap ID (0 if failed)
_viz_create_heatmap:
    stp x29, x30, [sp, #64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x29, sp
    
    mov w19, w0         // data_type
    mov w20, w1         // width
    mov w21, w2         // height
    mov w22, w3         // world_x
    mov w23, w4         // world_y
    
    bl _viz_get_context
    cbz x0, create_heatmap_fail
    mov x24, x0
    
    // Check if we have space for another heatmap
    ldr w0, [x24, viz_num_heatmaps]
    cmp w0, #16
    b.ge create_heatmap_fail
    
    // Get pointer to new heatmap slot
    ldr x1, [x24, viz_heatmaps]
    mov x2, hm_struct_size
    mul x2, x0, x2
    add x25, x1, x2
    
    // Initialize heatmap structure
    add w1, w0, #1      // Generate ID
    str w1, [x25, hm_id]
    str w19, [x25, hm_data_type]
    str w20, [x25, hm_width]
    str w21, [x25, hm_height]
    str w22, [x25, hm_world_x]
    str w23, [x25, hm_world_y]
    
    // Set defaults
    mov w2, #1
    str w2, [x25, hm_scale]
    str w2, [x25, hm_visible]
    str w2, [x25, hm_smooth_enabled]
    
    mov w2, #60         // Update every 60 frames (1 second at 60fps)
    str w2, [x25, hm_update_rate]
    
    mov w2, #255        // Full opacity
    str w2, [x25, hm_alpha]
    
    // Allocate data buffer
    mul w2, w20, w21    // width * height
    mov w3, #4          // sizeof(float)
    mul w2, w2, w3
    mov x0, x2
    bl _malloc
    cbz x0, create_heatmap_fail
    str x0, [x25, hm_data_buffer]
    
    // Allocate color buffer
    mul w2, w20, w21    // width * height
    mov w3, #4          // sizeof(uint32_t) for RGBA
    mul w2, w2, w3
    mov x0, x2
    bl _malloc
    cbz x0, create_heatmap_fail
    str x0, [x25, hm_color_buffer]
    
    // Create GPU texture
    mov w0, w20         // width
    mov w1, w21         // height
    bl _gfx_create_texture_rgba8
    str x0, [x25, hm_texture]
    
    // Increment heatmap count
    ldr w0, [x24, viz_num_heatmaps]
    add w0, w0, #1
    str w0, [x24, viz_num_heatmaps]
    
    // Return heatmap ID
    ldr x0, [x25, hm_id]
    b create_heatmap_done
    
create_heatmap_fail:
    mov x0, #0
    
create_heatmap_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// Create new graph
// Parameters: w0 = graph_type, x1 = position, x2 = size, w3 = num_series
// Returns: x0 = graph ID (0 if failed)
_viz_create_graph:
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    mov w19, w0         // graph_type
    mov x20, x1         // position
    mov x21, x2         // size
    mov w22, w3         // num_series
    
    bl _viz_get_context
    cbz x0, create_graph_fail
    mov x23, x0
    
    // Check limits
    ldr w0, [x23, viz_num_graphs]
    cmp w0, #16
    b.ge create_graph_fail
    cmp w22, #8
    b.gt create_graph_fail
    
    // Get pointer to new graph slot
    ldr x1, [x23, viz_graphs]
    mov x2, graph_struct_size
    mul x2, x0, x2
    add x24, x1, x2
    
    // Initialize graph structure
    add w1, w0, #1      // Generate ID
    str w1, [x24, graph_id]
    str w19, [x24, graph_type]
    str x20, [x24, graph_position]
    str x21, [x24, graph_size]
    str w22, [x24, graph_num_series]
    
    // Set defaults
    mov w1, #GRAPH_MAX_POINTS
    str w1, [x24, graph_max_points]
    mov w1, #GRAPH_HISTORY_SECONDS
    str w1, [x24, graph_time_window]
    mov w1, #1
    str w1, [x24, graph_auto_scale]
    str w1, [x24, graph_grid_enabled]
    str w1, [x24, graph_legend_enabled]
    str w1, [x24, graph_visible]
    
    // Allocate data buffers
    mov w0, #GRAPH_MAX_POINTS
    mul w0, w0, w22     // max_points * num_series
    mov w1, #4          // sizeof(float)
    mul w0, w0, w1
    bl _malloc
    cbz x0, create_graph_fail
    str x0, [x24, graph_data_buffer]
    
    // Allocate time buffer
    mov w0, #GRAPH_MAX_POINTS
    mov w1, #8          // sizeof(uint64_t) for timestamps
    mul w0, w0, w1
    bl _malloc
    cbz x0, create_graph_fail
    str x0, [x24, graph_time_buffer]
    
    // Increment graph count
    ldr w0, [x23, viz_num_graphs]
    add w0, w0, #1
    str w0, [x23, viz_num_graphs]
    
    // Return graph ID
    ldr x0, [x24, graph_id]
    b create_graph_done
    
create_graph_fail:
    mov x0, #0
    
create_graph_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Update specific heatmap with new data
_viz_update_heatmap:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov w19, w0         // heatmap_id
    
    // Find heatmap by ID
    bl _viz_find_heatmap
    cbz x0, update_heatmap_done
    mov x20, x0
    
    // Check if update is needed
    bl _viz_get_context
    ldr w1, [x0, viz_update_counter]
    ldr w2, [x20, hm_last_update]
    ldr w3, [x20, hm_update_rate]
    sub w1, w1, w2
    cmp w1, w3
    b.lt update_heatmap_done
    
    // Update last update frame
    ldr w1, [x0, viz_update_counter]
    str w1, [x20, hm_last_update]
    
    // Get data from simulation
    ldr w0, [x20, hm_data_type]
    ldr w1, [x20, hm_world_x]
    ldr w2, [x20, hm_world_y]
    ldr w3, [x20, hm_width]
    ldr w4, [x20, hm_height]
    ldr x5, [x20, hm_data_buffer]
    bl _sim_get_heatmap_data
    
    // Convert data to colors
    mov x0, x20
    bl _viz_update_heatmap_colors
    
    // Update GPU texture
    mov x0, x20
    bl _viz_upload_heatmap_texture
    
update_heatmap_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Update specific graph with new data point
_viz_update_graph:
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    mov w19, w0         // graph_id
    mov x20, x1         // data values array
    
    // Find graph by ID
    bl _viz_find_graph
    cbz x0, update_graph_done
    mov x21, x0
    
    // Get current time
    bl _get_system_time_ms
    mov x22, x0
    
    // Add data point
    ldr w0, [x21, graph_current_index]
    ldr w1, [x21, graph_max_points]
    add w2, w0, #1
    cmp w2, w1
    csel w2, w2, #0, lt     // Wrap around if at max
    str w2, [x21, graph_current_index]
    
    // Store timestamp
    ldr x1, [x21, graph_time_buffer]
    mov x2, #8              // sizeof(uint64_t)
    mul x2, x0, x2
    str x22, [x1, x2]
    
    // Store data values for all series
    ldr x1, [x21, graph_data_buffer]
    ldr w2, [x21, graph_num_series]
    ldr w3, [x21, graph_max_points]
    
    // Calculate offset: index * max_points * num_series + series * max_points
    mul w4, w0, w2          // index * num_series
    mul w4, w4, w3          // * max_points
    mov w5, #0              // series counter
    
store_series_loop:
    cmp w5, w2
    b.ge update_graph_done
    
    // Load value from input array
    ldr w6, [x20, w5, lsl #2]   // data[series]
    
    // Calculate storage offset
    add w7, w4, w5          // base_offset + series
    mul w7, w7, w3          // * max_points
    add w7, w7, w0          // + index
    
    // Store value
    str w6, [x1, w7, lsl #2]
    
    add w5, w5, #1
    b store_series_loop
    
update_graph_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Render heatmap overlay
_viz_render_heatmap:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov w19, w0         // heatmap_id
    
    // Find heatmap by ID
    bl _viz_find_heatmap
    cbz x0, render_heatmap_done
    mov x20, x0
    
    // Check visibility
    ldr w0, [x20, hm_visible]
    cbz w0, render_heatmap_done
    
    // Get world-to-screen transformation
    ldr w0, [x20, hm_world_x]
    ldr w1, [x20, hm_world_y]
    ldr w2, [x20, hm_width]
    ldr w3, [x20, hm_height]
    bl _camera_world_to_screen
    
    // Render textured quad with heatmap
    ldr x4, [x20, hm_texture]
    ldr w5, [x20, hm_alpha]
    bl _gfx_render_textured_quad_alpha
    
render_heatmap_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Render graph
_viz_render_graph:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov w19, w0         // graph_id
    
    // Find graph by ID
    bl _viz_find_graph
    cbz x0, render_graph_done
    mov x20, x0
    
    // Check visibility
    ldr w0, [x20, graph_visible]
    cbz w0, render_graph_done
    
    // Render graph background
    ldr x0, [x20, graph_position]
    ldr x1, [x20, graph_size]
    mov w2, #COLOR_GRAPH_BG
    bl _ui_draw_rect
    
    // Render grid if enabled
    ldr w0, [x20, graph_grid_enabled]
    cbz w0, render_data_lines
    
    mov x0, x20
    bl _viz_render_graph_grid
    
render_data_lines:
    // Render data series
    mov x0, x20
    bl _viz_render_graph_data
    
    // Render legend if enabled
    ldr w0, [x20, graph_legend_enabled]
    cbz w0, render_graph_done
    
    mov x0, x20
    bl _viz_render_graph_legend
    
render_graph_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Helper functions
_viz_get_context:
    adrp x0, viz_context@PAGE
    add x0, x0, viz_context@PAGEOFF
    ldr x0, [x0]
    ret

_viz_find_heatmap:
    // Find heatmap by ID in w0
    // Returns pointer to heatmap structure or 0
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov w19, w0         // ID to find
    
    bl _viz_get_context
    cbz x0, find_heatmap_not_found
    
    ldr x20, [x0, viz_heatmaps]
    ldr w21, [x0, viz_num_heatmaps]
    mov w22, #0         // Index
    
find_heatmap_loop:
    cmp w22, w21
    b.ge find_heatmap_not_found
    
    // Calculate heatmap pointer
    mov x0, hm_struct_size
    mul x0, x22, x0
    add x0, x20, x0
    
    // Check ID
    ldr w1, [x0, hm_id]
    cmp w1, w19
    b.eq find_heatmap_found
    
    add w22, w22, #1
    b find_heatmap_loop
    
find_heatmap_found:
    // x0 already contains the heatmap pointer
    b find_heatmap_done
    
find_heatmap_not_found:
    mov x0, #0
    
find_heatmap_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_viz_find_graph:
    // Find graph by ID in w0
    // Returns pointer to graph structure or 0
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov w19, w0         // ID to find
    
    bl _viz_get_context
    cbz x0, find_graph_not_found
    
    ldr x20, [x0, viz_graphs]
    ldr w21, [x0, viz_num_graphs]
    mov w22, #0         // Index
    
find_graph_loop:
    cmp w22, w21
    b.ge find_graph_not_found
    
    // Calculate graph pointer
    mov x0, graph_struct_size
    mul x0, x22, x0
    add x0, x20, x0
    
    // Check ID
    ldr w1, [x0, graph_id]
    cmp w1, w19
    b.eq find_graph_found
    
    add w22, w22, #1
    b find_graph_loop
    
find_graph_found:
    // x0 already contains the graph pointer
    b find_graph_done
    
find_graph_not_found:
    mov x0, #0
    
find_graph_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_viz_update_heatmap_colors:
    // Convert float data to RGBA colors using heat map palette
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    mov x19, x0         // heatmap pointer
    
    ldr x20, [x19, hm_data_buffer]
    ldr x21, [x19, hm_color_buffer]
    ldr w22, [x19, hm_width]
    ldr w23, [x19, hm_height]
    mul w24, w22, w23   // total pixels
    
    // Get data range
    mov x0, x20
    mov w1, w24
    bl _viz_get_data_range
    // Returns: w0 = min_value, w1 = max_value (as fixed point)
    
    mov w25, w0         // min_value
    mov w26, w1         // max_value
    sub w27, w26, w25   // range
    
    mov w28, #0         // pixel index
    
color_conversion_loop:
    cmp w28, w24
    b.ge color_conversion_done
    
    // Load data value
    ldr w0, [x20, w28, lsl #2]
    
    // Normalize to 0-1 range
    sub w0, w0, w25     // value - min
    // Convert to color index (0-7)
    mov w1, #7
    mul w0, w0, w1
    udiv w0, w0, w27    // (value - min) * 7 / range
    
    // Clamp to valid range
    cmp w0, #7
    csel w0, w0, #7, le
    cmp w0, #0
    csel w0, w0, #0, ge
    
    // Get color from palette
    adrp x1, heat_color_palette@PAGE
    add x1, x1, heat_color_palette@PAGEOFF
    ldr w2, [x1, w0, lsl #2]
    
    // Store color
    str w2, [x21, w28, lsl #2]
    
    add w28, w28, #1
    b color_conversion_loop
    
color_conversion_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Additional helper functions (stubs for integration with other systems)
_viz_init_color_tables:
    ret

_viz_update_heatmap_by_index:
    // Update heatmap by array index
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov w19, w0         // Index
    
    bl _viz_get_context
    cbz x0, update_hm_idx_done
    
    // Calculate heatmap pointer
    ldr x20, [x0, viz_heatmaps]
    mov x1, hm_struct_size
    mul x1, x19, x1
    add x20, x20, x1
    
    // Get heatmap ID and update
    ldr w0, [x20, hm_id]
    bl _viz_update_heatmap
    
update_hm_idx_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_viz_update_graph_by_index:
    // Update graph by array index
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov w19, w0         // Index
    
    bl _viz_get_context
    cbz x0, update_gr_idx_done
    
    // Calculate graph pointer
    ldr x20, [x0, viz_graphs]
    mov x1, graph_struct_size
    mul x1, x19, x1
    add x20, x20, x1
    
    // Get current simulation data for graph
    bl _viz_sample_graph_data
    
    // Update graph with sampled data
    ldr w0, [x20, graph_id]
    mov x1, x0          // Use sampled data
    bl _viz_update_graph
    
update_gr_idx_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_viz_render_heatmap_by_index:
    // Render heatmap by array index
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov w19, w0         // Index
    
    bl _viz_get_context
    cbz x0, render_hm_idx_done
    
    // Calculate heatmap pointer
    ldr x20, [x0, viz_heatmaps]
    mov x1, hm_struct_size
    mul x1, x19, x1
    add x20, x20, x1
    
    // Get heatmap ID and render
    ldr w0, [x20, hm_id]
    bl _viz_render_heatmap
    
render_hm_idx_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_viz_render_graph_by_index:
    // Render graph by array index
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov w19, w0         // Index
    
    bl _viz_get_context
    cbz x0, render_gr_idx_done
    
    // Calculate graph pointer
    ldr x20, [x0, viz_graphs]
    mov x1, graph_struct_size
    mul x1, x19, x1
    add x20, x20, x1
    
    // Get graph ID and render
    ldr w0, [x20, graph_id]
    bl _viz_render_graph
    
render_gr_idx_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_viz_upload_heatmap_texture:
    // Upload heatmap color data to GPU texture
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov x19, x0         // Heatmap pointer
    
    // Get texture handle and color buffer
    ldr x0, [x19, hm_texture]
    ldr x1, [x19, hm_color_buffer]
    
    // Calculate data size
    ldr w2, [x19, hm_width]
    ldr w3, [x19, hm_height]
    mul w2, w2, w3
    mov w3, #4          // RGBA bytes per pixel
    mul w2, w2, w3
    
    bl _gfx_upload_texture_data
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_viz_render_graph_grid:
    // Render grid lines for graph
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    mov x19, x0         // Graph pointer
    
    // Get graph position and size
    ldr x20, [x19, graph_position]
    ldr x21, [x19, graph_size]
    
    // Draw horizontal grid lines
    mov w22, #5         // Number of horizontal lines
    ldr w23, [x21, #4]  // Graph height
    udiv w23, w23, w22  // Line spacing
    
    mov w24, #0         // Current line
grid_h_loop:
    cmp w24, w22
    b.ge draw_v_grid
    
    // Calculate line Y position
    mul w0, w24, w23
    ldr w1, [x20, #4]   // Graph Y
    add w1, w1, w0
    
    // Draw horizontal line
    ldr w0, [x20]       // Graph X
    stp w0, w1, [sp, #-16]!
    ldr w0, [x21]       // Graph width
    mov w1, #1          // Line height
    stp w0, w1, [sp, #-16]!
    
    mov x0, sp
    add x1, sp, #8
    mov w2, #COLOR_GRAPH_GRID
    bl _ui_draw_rect
    
    add sp, sp, #16
    add w24, w24, #1
    b grid_h_loop
    
draw_v_grid:
    // Draw vertical grid lines (similar pattern)
    mov w22, #5         // Number of vertical lines
    ldr w23, [x21]      // Graph width
    udiv w23, w23, w22  // Line spacing
    
    mov w24, #0         // Current line
grid_v_loop:
    cmp w24, w22
    b.ge grid_done
    
    // Calculate line X position
    mul w0, w24, w23
    ldr w1, [x20]       // Graph X
    add w0, w0, w1
    
    // Draw vertical line
    ldr w1, [x20, #4]   // Graph Y
    stp w0, w1, [sp, #-16]!
    mov w0, #1          // Line width
    ldr w1, [x21, #4]   // Graph height
    stp w0, w1, [sp, #-16]!
    
    mov x0, sp
    add x1, sp, #8
    mov w2, #COLOR_GRAPH_GRID
    bl _ui_draw_rect
    
    add sp, sp, #16
    add w24, w24, #1
    b grid_v_loop
    
grid_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

_viz_render_graph_data:
    // Render graph data lines
    stp x29, x30, [sp, #64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x29, sp
    
    mov x19, x0         // Graph pointer
    
    // Get data buffers and parameters
    ldr x20, [x19, graph_data_buffer]
    ldr x21, [x19, graph_time_buffer]
    ldr w22, [x19, graph_num_series]
    ldr w23, [x19, graph_max_points]
    ldr w24, [x19, graph_current_index]
    
    // Render each data series
    mov w25, #0         // Series counter
    
render_series_loop:
    cmp w25, w22
    b.ge data_render_done
    
    // Calculate series data offset
    mul w0, w25, w23    // series * max_points
    mov w1, #4          // sizeof(float)
    mul w0, w0, w1
    add x26, x20, x0    // Series data pointer
    
    // Get series color
    adrp x0, graph_line_colors@PAGE
    add x0, x0, graph_line_colors@PAGEOFF
    ldr w27, [x0, w25, lsl #2]
    
    // Render data points as connected lines
    bl _viz_render_data_series
    
    add w25, w25, #1
    b render_series_loop
    
data_render_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

_viz_render_graph_legend:
    // Render graph legend
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    mov x19, x0         // Graph pointer
    
    // Calculate legend position (top-right of graph)
    ldr x20, [x19, graph_position]
    ldr x21, [x19, graph_size]
    
    ldr w0, [x20]       // Graph X
    ldr w1, [x21]       // Graph width
    add w0, w0, w1      // Right edge
    sub w0, w0, #120    // Legend width
    ldr w1, [x20, #4]   // Graph Y
    add w1, w1, #10     // Offset from top
    stp w0, w1, [sp, #-16]!
    
    // Draw legend background
    mov w0, #120        // Legend width
    ldr w1, [x19, graph_num_series]
    mov w2, #20         // Height per series
    mul w1, w1, w2
    add w1, w1, #10     // Padding
    stp w0, w1, [sp, #-16]!
    
    mov x0, sp
    add x1, sp, #8
    mov w2, #COLOR_GRAPH_BG
    bl _ui_draw_rect
    
    // Draw legend entries
    ldr w22, [x19, graph_num_series]
    mov w23, #0         // Series counter
    
legend_loop:
    cmp w23, w22
    b.ge legend_done
    
    // Calculate entry position
    ldr w0, [sp]        // Legend X
    add w0, w0, #5      // Padding
    ldr w1, [sp, #4]    // Legend Y
    add w1, w1, #5      // Top padding
    mov w2, #20         // Entry height
    mul w2, w23, w2
    add w1, w1, w2      // Entry Y
    
    // Draw color indicator
    stp w0, w1, [sp, #-16]!
    mov w2, #16         // Color box size
    stp w2, w2, [sp, #-16]!
    
    // Get series color
    adrp x0, graph_line_colors@PAGE
    add x0, x0, graph_line_colors@PAGEOFF
    ldr w2, [x0, w23, lsl #2]
    
    mov x0, sp
    add x1, sp, #8
    bl _ui_draw_rect
    
    add sp, sp, #16
    
    add w23, w23, #1
    b legend_loop
    
legend_done:
    add sp, sp, #16     // Clean up stack
    
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

_viz_get_data_range:
    // Placeholder - analyze data array to find min/max
    mov w0, #0          // min
    mov w1, #100        // max
    ret

// Simulation interface stubs
_sim_get_heatmap_data:
    ret

// Graphics interface stubs
_gfx_create_texture_rgba8:
    mov x0, #1
    ret

_gfx_render_textured_quad_alpha:
    ret

// Camera interface stubs
_camera_world_to_screen:
    ret

// Performance optimization functions
_viz_set_data_source:
    // Set data source for visualization
    // Parameters: w0 = viz_id, w1 = data_type
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov w19, w0         // Viz ID
    mov w20, w1         // Data type
    
    bl _viz_get_context
    cbz x0, set_data_source_done
    
    // Find visualization and set data source
    mov w0, w19
    bl _viz_find_heatmap
    cbnz x0, set_heatmap_source
    
    mov w0, w19
    bl _viz_find_graph
    cbz x0, set_data_source_done
    
    // Set graph data source
    str w20, [x0, graph_data_types]
    b set_data_source_done
    
set_heatmap_source:
    str w20, [x0, hm_data_type]
    
set_data_source_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_viz_get_statistics:
    // Get statistics for data type
    // Parameters: w0 = data_type
    // Returns: w0 = min, w1 = max, w2 = average
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    mov w19, w0         // Data type
    
    // Get statistics from simulation
    bl _sim_get_data_statistics
    
    ldp x29, x30, [sp], #16
    ret

_viz_optimize_updates:
    // Optimize update frequency based on performance
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _viz_get_context
    cbz x0, optimize_done
    mov x19, x0
    
    // Measure update time
    bl _get_system_time_ms
    mov x20, x0         // Start time
    
    // Perform updates
    bl _viz_update
    
    // Measure end time
    bl _get_system_time_ms
    sub x0, x0, x20     // Update duration
    
    // Adjust update rates if too slow (>2ms target)
    cmp x0, #2
    b.le optimize_done
    
    // Reduce update frequency for performance
    bl _viz_reduce_update_frequency
    
optimize_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_viz_reduce_update_frequency:
    // Reduce update frequency for performance
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _viz_get_context
    cbz x0, reduce_freq_done
    mov x19, x0
    
    // Increase update intervals for all heatmaps
    ldr w20, [x19, viz_num_heatmaps]
    mov w21, #0
    
reduce_heatmap_loop:
    cmp w21, w20
    b.ge reduce_graph_freq
    
    // Get heatmap pointer
    ldr x22, [x19, viz_heatmaps]
    mov x0, hm_struct_size
    mul x0, x21, x0
    add x22, x22, x0
    
    // Double update rate (reduce frequency)
    ldr w0, [x22, hm_update_rate]
    lsl w0, w0, #1      // Multiply by 2
    cmp w0, #240        // Max 4 seconds at 60fps
    csel w0, w0, #240, le
    str w0, [x22, hm_update_rate]
    
    add w21, w21, #1
    b reduce_heatmap_loop
    
reduce_graph_freq:
    // Similar reduction for graphs
    
reduce_freq_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Additional helper functions
_viz_sample_graph_data:
    // Sample current simulation data for graphs
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    // Allocate temporary data array
    mov w0, #8          // Max 8 data series
    mov w1, #4          // sizeof(float)
    mul w0, w0, w1
    bl _malloc
    cbz x0, sample_data_fail
    mov x19, x0
    
    // Sample different data types
    bl _sim_get_population
    str w0, [x19]       // Series 0: Population
    
    bl _sim_get_happiness
    str w0, [x19, #4]   // Series 1: Happiness
    
    bl _sim_get_pollution
    str w0, [x19, #8]   // Series 2: Pollution
    
    bl _sim_get_money
    str w0, [x19, #12]  // Series 3: Money
    
    // Return data array
    mov x0, x19
    b sample_data_done
    
sample_data_fail:
    mov x0, #0
    
sample_data_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_viz_render_data_series:
    // Render a single data series as connected lines
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    // x26 = series data pointer
    // w27 = series color
    // x19 = graph pointer
    
    // Simplified line rendering - would need proper line drawing
    // This is a placeholder for actual line rendering
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Simulation interface stubs
_sim_get_population:
    mov w0, #50000      // Placeholder population
    ret

_sim_get_happiness:
    mov w0, #75         // Placeholder happiness (0-100)
    ret

_sim_get_pollution:
    mov w0, #25         // Placeholder pollution level
    ret

_sim_get_data_statistics:
    // Get statistics for data type
    // w0 = data_type
    // Returns: w0 = min, w1 = max, w2 = average
    mov w1, #0          // min
    mov w2, #100        // max
    mov w3, #50         // average
    ret

// Mini-map implementation
_viz_create_minimap:
    // Create mini-map
    // Parameters: x0 = position, x1 = size, w2 = world_width, w3 = world_height
    // Returns: x0 = minimap ID
    stp x29, x30, [sp, #64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x29, sp
    
    mov x19, x0         // Position
    mov x20, x1         // Size
    mov w21, w2         // World width
    mov w22, w3         // World height
    
    // Allocate minimap structure
    mov x0, minimap_struct_size
    bl _malloc
    cbz x0, create_minimap_fail
    mov x23, x0
    
    // Store global minimap reference
    adrp x24, global_minimap@PAGE
    add x24, x24, global_minimap@PAGEOFF
    str x23, [x24]
    
    // Initialize minimap
    mov w0, #1
    str w0, [x23, minimap_id]
    str x19, [x23, minimap_position]
    str x20, [x23, minimap_size]
    stp w21, w22, [x23, minimap_world_size]
    
    // Calculate scale factor
    ldr w0, [x20]       // Minimap width
    udiv w0, w0, w21    // minimap_width / world_width
    str w0, [x23, minimap_scale]
    
    // Create minimap texture
    ldr w0, [x20]       // Width
    ldr w1, [x20, #4]   // Height
    bl _gfx_create_texture_rgba8
    str x0, [x23, minimap_texture]
    
    // Set defaults
    mov w0, #1
    str w0, [x23, minimap_visible]
    str w0, [x23, minimap_click_enabled]
    
    // Return minimap ID
    ldr x0, [x23, minimap_id]
    b create_minimap_done
    
create_minimap_fail:
    mov x0, #0
    
create_minimap_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

_viz_update_minimap:
    // Update minimap with current city data
    // Parameters: w0 = minimap_id
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    // Get global minimap
    adrp x20, global_minimap@PAGE
    add x20, x20, global_minimap@PAGEOFF
    ldr x20, [x20]
    cbz x20, update_minimap_done
    
    // Update camera viewport indicator
    bl _camera_get_viewport
    
update_minimap_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_viz_render_minimap:
    // Render minimap to screen
    // Parameters: w0 = minimap_id
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    // Get global minimap
    adrp x20, global_minimap@PAGE
    add x20, x20, global_minimap@PAGEOFF
    ldr x20, [x20]
    cbz x20, render_minimap_done
    
    // Check visibility
    ldr w0, [x20, minimap_visible]
    cbz w0, render_minimap_done
    
    // Render minimap background
    ldr x0, [x20, minimap_position]
    ldr x1, [x20, minimap_size]
    mov w2, #0xFF202020  // Dark background
    bl _ui_draw_rect
    
render_minimap_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_viz_minimap_click:
    // Handle minimap click to move camera
    // Parameters: w0 = minimap_id, w1 = click_x, w2 = click_y
    // Returns: w0 = 1 if camera moved
    mov w0, #0          // Simplified - return not handled
    ret

// Camera interface stubs
_camera_get_viewport:
    // Returns camera viewport in world coordinates
    mov x0, #0          // x, y
    mov x1, #100        // width, height
    ret

_camera_center_on:
    // Center camera on world coordinates w0, w1
    ret

// System interface stubs
_get_system_time_ms:
    mov x0, #0
    ret

.data
.align 3

heat_color_palette:
    .word COLOR_HEAT_0
    .word COLOR_HEAT_1
    .word COLOR_HEAT_2
    .word COLOR_HEAT_3
    .word COLOR_HEAT_4
    .word COLOR_HEAT_5
    .word COLOR_HEAT_6
    .word COLOR_HEAT_7

graph_line_colors:
    .word COLOR_GRAPH_LINE_1
    .word COLOR_GRAPH_LINE_2
    .word COLOR_GRAPH_LINE_3
    .word COLOR_GRAPH_LINE_4

data_type_names:
    .quad name_population
    .quad name_happiness
    .quad name_pollution
    .quad name_traffic
    .quad name_power
    .quad name_water
    .quad name_crime
    .quad name_fire_risk
    .quad name_land_value
    .quad name_money
    .quad name_tax_income
    .quad name_expenses

name_population:    .asciz "Population"
name_happiness:     .asciz "Happiness"
name_pollution:     .asciz "Pollution"
name_traffic:       .asciz "Traffic"
name_power:         .asciz "Power"
name_water:         .asciz "Water"
name_crime:         .asciz "Crime"
name_fire_risk:     .asciz "Fire Risk"
name_land_value:    .asciz "Land Value"
name_money:         .asciz "Money"
name_tax_income:    .asciz "Tax Income"
name_expenses:      .asciz "Expenses"

.bss
.align 3
viz_context:
    .space 8    // Pointer to visualization context

global_minimap:
    .space 8    // Pointer to global minimap structure