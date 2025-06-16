// SimCity ARM64 Assembly - Building and Zoning Tools
// Agent 7: User Interface & Interaction
//
// City building tools: bulldozer, zoning, placement
// Integrates with simulation engine for building placement and validation
// Provides tool state management and visual feedback

.global _tools_init
.global _tools_update
.global _tools_render
.global _tools_handle_input
.global _tools_set_active_tool
.global _tools_get_active_tool
.global _tools_get_cursor_info
.global _tools_validate_placement
.global _tools_place_building
.global _tools_bulldoze
.global _tools_zone_area

.align 2

// Tool types
.equ TOOL_NONE, 0
.equ TOOL_BULLDOZER, 1
.equ TOOL_ZONE_RESIDENTIAL, 2
.equ TOOL_ZONE_COMMERCIAL, 3
.equ TOOL_ZONE_INDUSTRIAL, 4
.equ TOOL_ROAD, 5
.equ TOOL_POWER, 6
.equ TOOL_WATER, 7
.equ TOOL_BUILDING_POLICE, 8
.equ TOOL_BUILDING_FIRE, 9
.equ TOOL_BUILDING_HOSPITAL, 10
.equ TOOL_BUILDING_SCHOOL, 11
.equ TOOL_BUILDING_PARK, 12
.equ TOOL_QUERY, 13

// Tool states
.equ TOOL_STATE_IDLE, 0
.equ TOOL_STATE_DRAGGING, 1
.equ TOOL_STATE_PLACING, 2
.equ TOOL_STATE_VALIDATING, 3

// Building sizes (in tiles)
.equ BUILDING_SIZE_1x1, 0x00010001
.equ BUILDING_SIZE_2x2, 0x00020002
.equ BUILDING_SIZE_3x3, 0x00030003
.equ BUILDING_SIZE_4x4, 0x00040004

// Colors for tool visualization
.equ COLOR_VALID_PLACEMENT, 0x8000FF00    // Semi-transparent green
.equ COLOR_INVALID_PLACEMENT, 0x80FF0000  // Semi-transparent red
.equ COLOR_ZONE_RESIDENTIAL, 0x8000AA00   // Semi-transparent green
.equ COLOR_ZONE_COMMERCIAL, 0x800000AA    // Semi-transparent blue
.equ COLOR_ZONE_INDUSTRIAL, 0x80AAAA00    // Semi-transparent yellow
.equ COLOR_BULLDOZER, 0x80FF4400          // Semi-transparent orange
.equ COLOR_TOOL_OUTLINE, 0xFFFFFFFF       // White outline

// Tool costs
.equ COST_BULLDOZER, 1
.equ COST_ROAD, 10
.equ COST_ZONE, 0
.equ COST_POWER_LINE, 5
.equ COST_WATER_PIPE, 5
.equ COST_POLICE_STATION, 500
.equ COST_FIRE_STATION, 500
.equ COST_HOSPITAL, 1000
.equ COST_SCHOOL, 750
.equ COST_PARK, 100

// Tool Context Structure
.struct 0
tool_active_tool:       .space 4    // Current active tool
tool_state:            .space 4     // Current tool state
tool_drag_start_x:     .space 4     // Drag start X coordinate
tool_drag_start_y:     .space 4     // Drag start Y coordinate
tool_drag_end_x:       .space 4     // Drag end X coordinate
tool_drag_end_y:       .space 4     // Drag end Y coordinate
tool_cursor_x:         .space 4     // World cursor X position
tool_cursor_y:         .space 4     // World cursor Y position
tool_cursor_valid:     .space 4     // Is current cursor position valid
tool_preview_visible:  .space 4     // Show placement preview
tool_last_placed_x:    .space 4     // Last successful placement X
tool_last_placed_y:    .space 4     // Last successful placement Y
tool_money_available:  .space 4     // Available money for purchases
tool_context_size:     .space 0

// Building definitions
.struct 0
building_type:         .space 4     // Building type ID
building_size_x:       .space 4     // Width in tiles
building_size_y:       .space 4     // Height in tiles
building_cost:         .space 4     // Construction cost
building_name:         .space 8     // Pointer to name string
building_texture:      .space 8     // Texture handle
building_def_size:     .space 0

// Initialize tools system
_tools_init:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    // Allocate tool context
    mov x0, tool_context_size
    bl _malloc
    cbz x0, tools_init_fail
    
    adrp x19, tool_context@PAGE
    add x19, x19, tool_context@PAGEOFF
    str x0, [x19]
    mov x20, x0
    
    // Clear context
    mov x1, #0
    mov x2, tool_context_size
    bl _memset
    
    // Initialize default tool state
    mov w1, #TOOL_NONE
    str w1, [x20, tool_active_tool]
    mov w1, #TOOL_STATE_IDLE
    str w1, [x20, tool_state]
    
    // Initialize building definitions
    bl _tools_init_building_defs
    
    mov x0, #1
    b tools_init_done
    
tools_init_fail:
    mov x0, #0
    
tools_init_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Update tools system
_tools_update:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _tools_get_context
    cbz x0, tools_update_done
    mov x19, x0
    
    // Get current mouse world position
    bl _tools_screen_to_world
    str w0, [x19, tool_cursor_x]
    str w1, [x19, tool_cursor_y]
    
    // Update tool state based on active tool
    ldr w0, [x19, tool_active_tool]
    
    cmp w0, #TOOL_BULLDOZER
    b.eq update_bulldozer
    cmp w0, #TOOL_ZONE_RESIDENTIAL
    b.eq update_zoning
    cmp w0, #TOOL_ZONE_COMMERCIAL
    b.eq update_zoning
    cmp w0, #TOOL_ZONE_INDUSTRIAL
    b.eq update_zoning
    cmp w0, #TOOL_ROAD
    b.eq update_road_tool
    
    // Check building tools
    cmp w0, #TOOL_BUILDING_POLICE
    b.ge update_building_tool
    
    b tools_update_done
    
update_bulldozer:
    bl _tools_update_bulldozer
    b tools_update_done
    
update_zoning:
    bl _tools_update_zoning
    b tools_update_done
    
update_road_tool:
    bl _tools_update_road
    b tools_update_done
    
update_building_tool:
    bl _tools_update_building
    
tools_update_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Render tool overlays and cursors
_tools_render:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _tools_get_context
    cbz x0, tools_render_done
    mov x19, x0
    
    // Check if preview should be visible
    ldr w0, [x19, tool_preview_visible]
    cbz w0, tools_render_done
    
    // Render based on active tool
    ldr w0, [x19, tool_active_tool]
    
    cmp w0, #TOOL_BULLDOZER
    b.eq render_bulldozer_cursor
    cmp w0, #TOOL_ZONE_RESIDENTIAL
    b.eq render_zone_cursor
    cmp w0, #TOOL_ZONE_COMMERCIAL
    b.eq render_zone_cursor
    cmp w0, #TOOL_ZONE_INDUSTRIAL
    b.eq render_zone_cursor
    cmp w0, #TOOL_ROAD
    b.eq render_road_cursor
    
    // Check building tools
    cmp w0, #TOOL_BUILDING_POLICE
    b.ge render_building_cursor
    
    b tools_render_done
    
render_bulldozer_cursor:
    bl _tools_render_bulldozer_cursor
    b tools_render_done
    
render_zone_cursor:
    bl _tools_render_zone_cursor
    b tools_render_done
    
render_road_cursor:
    bl _tools_render_road_cursor
    b tools_render_done
    
render_building_cursor:
    bl _tools_render_building_cursor
    
tools_render_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Handle input for tools
_tools_handle_input:
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    mov w19, w0         // Input type
    mov w20, w1         // Button/key
    mov w21, w2         // X coordinate
    mov w22, w3         // Y coordinate
    
    bl _tools_get_context
    cbz x0, tools_input_done
    mov x23, x0
    
    // Handle different input types
    cmp w19, #0         // Mouse button
    b.eq handle_mouse_input
    cmp w19, #1         // Keyboard
    b.eq handle_keyboard_input
    
    b tools_input_done
    
handle_mouse_input:
    cmp w20, #0         // Left mouse button
    b.eq handle_left_click
    cmp w20, #1         // Right mouse button
    b.eq handle_right_click
    b tools_input_done
    
handle_left_click:
    // Check tool state and handle accordingly
    ldr w0, [x23, tool_state]
    cmp w0, #TOOL_STATE_IDLE
    b.eq start_tool_action
    cmp w0, #TOOL_STATE_DRAGGING
    b.eq continue_drag
    b tools_input_done
    
start_tool_action:
    // Start tool action based on active tool
    ldr w0, [x23, tool_active_tool]
    
    // Store drag start position
    str w21, [x23, tool_drag_start_x]
    str w22, [x23, tool_drag_start_y]
    
    cmp w0, #TOOL_BULLDOZER
    b.eq start_bulldoze
    cmp w0, #TOOL_ZONE_RESIDENTIAL
    b.eq start_zone_drag
    cmp w0, #TOOL_ZONE_COMMERCIAL
    b.eq start_zone_drag
    cmp w0, #TOOL_ZONE_INDUSTRIAL
    b.eq start_zone_drag
    cmp w0, #TOOL_ROAD
    b.eq place_road
    
    // Building placement
    cmp w0, #TOOL_BUILDING_POLICE
    b.ge place_building
    
    b tools_input_done
    
start_bulldoze:
    bl _tools_execute_bulldoze
    b tools_input_done
    
start_zone_drag:
    mov w0, #TOOL_STATE_DRAGGING
    str w0, [x23, tool_state]
    b tools_input_done
    
place_road:
    bl _tools_place_road_tile
    b tools_input_done
    
place_building:
    bl _tools_execute_building_placement
    b tools_input_done
    
continue_drag:
    // Update drag end position
    str w21, [x23, tool_drag_end_x]
    str w22, [x23, tool_drag_end_y]
    
    // Check if mouse released to complete drag
    ldr w0, [x23, ui_mouse_down]
    cbnz w0, tools_input_done
    
    // Mouse released - complete zone painting
    ldr w0, [x23, tool_state]
    cmp w0, #TOOL_STATE_DRAGGING
    b.ne tools_input_done
    
    // Execute zone area painting
    ldr w0, [x23, tool_active_tool]
    ldr w1, [x23, tool_drag_start_x]
    ldr w2, [x23, tool_drag_start_y]
    ldr w3, [x23, tool_drag_end_x]
    ldr w4, [x23, tool_drag_end_y]
    bl _tools_zone_area
    
    // Reset tool state
    mov w0, #TOOL_STATE_IDLE
    str w0, [x23, tool_state]
    
    b tools_input_done
    
handle_right_click:
    // Cancel current tool action
    mov w0, #TOOL_STATE_IDLE
    str w0, [x23, tool_state]
    b tools_input_done
    
handle_keyboard_input:
    // Handle keyboard shortcuts for tool selection
    cmp w20, #'b'       // Bulldozer
    b.eq set_bulldozer
    cmp w20, #'r'       // Road
    b.eq set_road_tool
    cmp w20, #'1'       // Residential zone
    b.eq set_residential_zone
    cmp w20, #'2'       // Commercial zone
    b.eq set_commercial_zone
    cmp w20, #'3'       // Industrial zone
    b.eq set_industrial_zone
    
    b tools_input_done
    
set_bulldozer:
    mov w0, #TOOL_BULLDOZER
    bl _tools_set_active_tool
    b tools_input_done
    
set_road_tool:
    mov w0, #TOOL_ROAD
    bl _tools_set_active_tool
    b tools_input_done
    
set_residential_zone:
    mov w0, #TOOL_ZONE_RESIDENTIAL
    bl _tools_set_active_tool
    b tools_input_done
    
set_commercial_zone:
    mov w0, #TOOL_ZONE_COMMERCIAL
    bl _tools_set_active_tool
    b tools_input_done
    
set_industrial_zone:
    mov w0, #TOOL_ZONE_INDUSTRIAL
    bl _tools_set_active_tool
    
tools_input_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Set active tool
_tools_set_active_tool:
    bl _tools_get_context
    cbz x0, set_tool_done
    
    str w0, [x0, tool_active_tool]
    
    // Reset tool state
    mov w1, #TOOL_STATE_IDLE
    str w1, [x0, tool_state]
    
    // Enable preview for appropriate tools
    mov w1, #1
    str w1, [x0, tool_preview_visible]
    
set_tool_done:
    ret

// Get active tool
_tools_get_active_tool:
    bl _tools_get_context
    cbz x0, get_tool_fail
    
    ldr w0, [x0, tool_active_tool]
    ret
    
get_tool_fail:
    mov w0, #TOOL_NONE
    ret

// Validate placement at current cursor position
_tools_validate_placement:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov w19, w0         // Tool type
    mov w20, w1         // X coordinate
    mov w21, w2         // Y coordinate
    
    // Check basic bounds
    cmp w20, #0
    b.lt placement_invalid
    cmp w21, #0
    b.lt placement_invalid
    
    // Get world dimensions (should come from simulation)
    mov w22, #4096      // Max world width
    mov w23, #4096      // Max world height
    
    cmp w20, w22
    b.ge placement_invalid
    cmp w21, w23
    b.ge placement_invalid
    
    // Tool-specific validation
    cmp w19, #TOOL_BULLDOZER
    b.eq validate_bulldozer
    cmp w19, #TOOL_ROAD
    b.eq validate_road
    cmp w19, #TOOL_ZONE_RESIDENTIAL
    b.eq validate_zone
    cmp w19, #TOOL_ZONE_COMMERCIAL
    b.eq validate_zone
    cmp w19, #TOOL_ZONE_INDUSTRIAL
    b.eq validate_zone
    
    // Building validation
    cmp w19, #TOOL_BUILDING_POLICE
    b.ge validate_building
    
    b placement_invalid
    
validate_bulldozer:
    // Bulldozer can work on any non-empty tile
    mov x0, x20
    mov x1, x21
    bl _sim_get_tile_type
    cmp w0, #0          // Empty tile
    cset w0, ne         // Valid if not empty
    b validate_done
    
validate_road:
    // Road can be placed on empty tiles
    mov x0, x20
    mov x1, x21
    bl _sim_get_tile_type
    cmp w0, #0          // Empty tile
    cset w0, eq         // Valid if empty
    b validate_done
    
validate_zone:
    // Zones can be placed on empty flat land
    mov x0, x20
    mov x1, x21
    bl _sim_validate_zone_placement
    b validate_done
    
validate_building:
    // Buildings need specific validation
    mov x0, x19
    mov x1, x20
    mov x2, x21
    bl _sim_validate_building_placement
    b validate_done
    
placement_invalid:
    mov w0, #0
    
validate_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Execute building placement
_tools_place_building:
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    mov w19, w0         // Building type
    mov w20, w1         // X position
    mov w21, w2         // Y position
    
    // Validate placement first
    mov w0, w19
    mov w1, w20
    mov w2, w21
    bl _tools_validate_placement
    cbz w0, placement_failed
    
    // Check cost
    bl _tools_get_building_cost
    mov w22, w0
    bl _sim_get_money
    cmp w0, w22
    b.lt insufficient_funds
    
    // Deduct cost
    mov w0, w22
    bl _sim_deduct_money
    
    // Place building in simulation
    mov w0, w19
    mov w1, w20
    mov w2, w21
    bl _sim_place_building
    
    mov w0, #1          // Success
    b place_building_done
    
placement_failed:
insufficient_funds:
    mov w0, #0          // Failure
    
place_building_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Execute bulldozer action
_tools_bulldoze:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov w19, w0         // X position
    mov w20, w1         // Y position
    
    // Check if there's something to bulldoze
    mov x0, x19
    mov x1, x20
    bl _sim_get_tile_type
    cbz w0, bulldoze_nothing
    
    // Deduct bulldozer cost
    mov w0, #COST_BULLDOZER
    bl _sim_deduct_money
    
    // Remove from simulation
    mov x0, x19
    mov x1, x20
    bl _sim_remove_tile
    
    mov w0, #1          // Success
    b bulldoze_done
    
bulldoze_nothing:
    mov w0, #0          // Nothing to bulldoze
    
bulldoze_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Zone area between two points
_tools_zone_area:
    stp x29, x30, [sp, #64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x29, sp
    
    mov w19, w0         // Zone type
    mov w20, w1         // Start X
    mov w21, w2         // Start Y
    mov w22, w3         // End X
    mov w23, w4         // End Y
    
    // Normalize coordinates
    cmp w20, w22
    csel w24, w20, w22, le  // min_x
    csel w25, w22, w20, le  // max_x
    cmp w21, w23
    csel w26, w21, w23, le  // min_y
    csel w27, w23, w21, le  // max_y
    
    // Zone each tile in the rectangle
    mov w28, w26        // current_y
    
zone_y_loop:
    mov w29, w24        // current_x
    
zone_x_loop:
    // Validate and place zone
    mov w0, w19
    mov w1, w29
    mov w2, w28
    bl _tools_validate_placement
    cbz w0, skip_zone_tile
    
    // Place zone tile
    mov w0, w19
    mov w1, w29
    mov w2, w28
    bl _sim_place_zone
    
skip_zone_tile:
    add w29, w29, #1
    cmp w29, w25
    b.le zone_x_loop
    
    add w28, w28, #1
    cmp w28, w27
    b.le zone_y_loop
    
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// Tool-specific update functions
_tools_update_bulldozer:
    // Update bulldozer cursor and preview
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _tools_get_context
    cbz x0, update_bulldozer_done
    mov x19, x0
    
    // Get cursor position
    ldr w0, [x19, tool_cursor_x]
    ldr w1, [x19, tool_cursor_y]
    
    // Validate bulldozer target
    mov w2, #TOOL_BULLDOZER
    bl _tools_validate_placement
    str w0, [x19, tool_cursor_valid]
    
    // Enable preview for valid targets
    str w0, [x19, tool_preview_visible]
    
update_bulldozer_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_tools_update_zoning:
    // Update zoning preview based on drag state
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _tools_get_context
    cbz x0, update_zoning_done
    mov x19, x0
    
    // Check if we're in dragging state
    ldr w0, [x19, tool_state]
    cmp w0, #TOOL_STATE_DRAGGING
    b.ne check_single_zone
    
    // Update drag end position
    ldr w0, [x19, tool_cursor_x]
    ldr w1, [x19, tool_cursor_y]
    str w0, [x19, tool_drag_end_x]
    str w1, [x19, tool_drag_end_y]
    
    // Validate zone area
    bl _tools_validate_zone_area
    str w0, [x19, tool_cursor_valid]
    b update_zoning_done
    
check_single_zone:
    // Validate single zone tile
    ldr w0, [x19, tool_active_tool]
    ldr w1, [x19, tool_cursor_x]
    ldr w2, [x19, tool_cursor_y]
    bl _tools_validate_placement
    str w0, [x19, tool_cursor_valid]
    
    // Always show preview for zones
    mov w0, #1
    str w0, [x19, tool_preview_visible]
    
update_zoning_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_tools_update_road:
    // Update road placement cursor and connectivity preview
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _tools_get_context
    cbz x0, update_road_done
    mov x19, x0
    
    // Get cursor position
    ldr w0, [x19, tool_cursor_x]
    ldr w1, [x19, tool_cursor_y]
    
    // Validate road placement
    mov w2, #TOOL_ROAD
    bl _tools_validate_placement
    str w0, [x19, tool_cursor_valid]
    
    // Check road connectivity for preview
    cbz w0, update_road_done
    
    // Analyze surrounding roads for connection preview
    bl _tools_analyze_road_connections
    
    // Enable preview
    mov w0, #1
    str w0, [x19, tool_preview_visible]
    
update_road_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_tools_update_building:
    // Update building placement cursor and validation
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _tools_get_context
    cbz x0, update_building_done
    mov x19, x0
    
    // Get building type and position
    ldr w0, [x19, tool_active_tool]
    ldr w1, [x19, tool_cursor_x]
    ldr w2, [x19, tool_cursor_y]
    
    // Validate building placement
    bl _tools_validate_placement
    str w0, [x19, tool_cursor_valid]
    
    // Check if player has enough money
    cbz w0, no_building_preview
    
    ldr w0, [x19, tool_active_tool]
    bl _tools_get_building_cost
    mov w20, w0
    
    bl _sim_get_money
    cmp w0, w20
    b.lt insufficient_funds_building
    
    // Enable preview for valid, affordable placement
    mov w0, #1
    str w0, [x19, tool_preview_visible]
    b update_building_done
    
insufficient_funds_building:
no_building_preview:
    str wzr, [x19, tool_preview_visible]
    
update_building_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Tool-specific render functions
_tools_render_bulldozer_cursor:
    // Render bulldozer cursor overlay
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _tools_get_context
    cbz x0, render_bulldozer_done
    mov x19, x0
    
    // Get cursor world position
    ldr w0, [x19, tool_cursor_x]
    ldr w1, [x19, tool_cursor_y]
    
    // Convert to screen coordinates
    bl _camera_world_to_screen
    mov w20, w0         // Screen X
    mov w21, w1         // Screen Y
    
    // Create tile-sized cursor
    mov w2, #32         // Tile width
    mov w3, #32         // Tile height
    stp w20, w21, [sp, #-16]!
    stp w2, w3, [sp, #-16]!
    
    // Choose color based on validity
    ldr w0, [x19, tool_cursor_valid]
    mov w2, #COLOR_INVALID_PLACEMENT
    cbz w0, draw_bulldozer_cursor
    mov w2, #COLOR_BULLDOZER
    
draw_bulldozer_cursor:
    mov x0, sp          // Position
    add x1, sp, #8      // Size
    bl _ui_draw_rect
    
    add sp, sp, #16
    
render_bulldozer_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_tools_render_zone_cursor:
    // Render zone selection area
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    bl _tools_get_context
    cbz x0, render_zone_done
    mov x19, x0
    
    // Check if dragging
    ldr w0, [x19, tool_state]
    cmp w0, #TOOL_STATE_DRAGGING
    b.eq render_zone_area
    
    // Render single tile cursor
    ldr w0, [x19, tool_cursor_x]
    ldr w1, [x19, tool_cursor_y]
    bl _camera_world_to_screen
    
    mov w2, #32         // Tile size
    stp w0, w1, [sp, #-16]!
    stp w2, w2, [sp, #-16]!
    
    // Get zone color
    ldr w0, [x19, tool_active_tool]
    bl _tools_get_zone_color
    mov w2, w0
    
    mov x0, sp
    add x1, sp, #8
    bl _ui_draw_rect
    
    add sp, sp, #16
    b render_zone_done
    
render_zone_area:
    // Render dragged area
    ldr w0, [x19, tool_drag_start_x]
    ldr w1, [x19, tool_drag_start_y]
    ldr w2, [x19, tool_drag_end_x]
    ldr w3, [x19, tool_drag_end_y]
    
    // Calculate area bounds
    cmp w0, w2
    csel w20, w0, w2, le    // min_x
    csel w21, w2, w0, le    // max_x
    cmp w1, w3
    csel w22, w1, w3, le    // min_y
    csel w23, w3, w1, le    // max_y
    
    // Convert to screen coordinates
    mov w0, w20
    mov w1, w22
    bl _camera_world_to_screen
    mov w24, w0         // Screen start X
    mov w25, w1         // Screen start Y
    
    // Calculate size
    sub w0, w21, w20    // Width in tiles
    add w0, w0, #1      // Include end tile
    mov w1, #32
    mul w0, w0, w1      // Screen width
    
    sub w1, w23, w22    // Height in tiles
    add w1, w1, #1      // Include end tile
    mov w2, #32
    mul w1, w1, w2      // Screen height
    
    stp w24, w25, [sp, #-16]!
    stp w0, w1, [sp, #-16]!
    
    // Get zone color
    ldr w0, [x19, tool_active_tool]
    bl _tools_get_zone_color
    mov w2, w0
    
    mov x0, sp
    add x1, sp, #8
    bl _ui_draw_rect
    
    add sp, sp, #16
    
render_zone_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

_tools_render_road_cursor:
    // Render road placement cursor
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _tools_get_context
    cbz x0, render_road_done
    mov x19, x0
    
    // Get cursor position
    ldr w0, [x19, tool_cursor_x]
    ldr w1, [x19, tool_cursor_y]
    bl _camera_world_to_screen
    
    mov w2, #32         // Tile size
    stp w0, w1, [sp, #-16]!
    stp w2, w2, [sp, #-16]!
    
    // Choose color based on validity
    ldr w0, [x19, tool_cursor_valid]
    mov w2, #COLOR_INVALID_PLACEMENT
    cbz w0, draw_road_cursor
    mov w2, #0x808080FF  // Gray for roads
    
draw_road_cursor:
    mov x0, sp
    add x1, sp, #8
    bl _ui_draw_rect
    
    add sp, sp, #16
    
render_road_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_tools_render_building_cursor:
    // Render building placement preview
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    bl _tools_get_context
    cbz x0, render_building_done
    mov x19, x0
    
    // Get building type and size
    ldr w0, [x19, tool_active_tool]
    bl _tools_get_building_size
    mov w20, w0         // Width
    mov w21, w1         // Height
    
    // Get cursor position
    ldr w0, [x19, tool_cursor_x]
    ldr w1, [x19, tool_cursor_y]
    bl _camera_world_to_screen
    
    // Calculate building size in pixels
    mov w2, #32
    mul w20, w20, w2    // Pixel width
    mul w21, w21, w2    // Pixel height
    
    stp w0, w1, [sp, #-16]!
    stp w20, w21, [sp, #-16]!
    
    // Choose color based on validity and affordability
    ldr w0, [x19, tool_cursor_valid]
    mov w2, #COLOR_INVALID_PLACEMENT
    cbz w0, draw_building_cursor
    
    // Check if affordable
    ldr w0, [x19, tool_active_tool]
    bl _tools_get_building_cost
    mov w22, w0
    bl _sim_get_money
    cmp w0, w22
    mov w2, #COLOR_INVALID_PLACEMENT
    b.lt draw_building_cursor
    mov w2, #COLOR_VALID_PLACEMENT
    
draw_building_cursor:
    mov x0, sp
    add x1, sp, #8
    bl _ui_draw_rect
    
    add sp, sp, #16
    
render_building_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Helper functions
_tools_get_context:
    adrp x0, tool_context@PAGE
    add x0, x0, tool_context@PAGEOFF
    ldr x0, [x0]
    ret

_tools_screen_to_world:
    // Convert screen coordinates to world tile coordinates
    // This would interact with the camera/viewport system
    // Placeholder implementation
    mov w0, #0
    mov w1, #0
    ret

_tools_get_building_cost:
    // Get cost for building type in w0
    adrp x1, building_costs@PAGE
    add x1, x1, building_costs@PAGEOFF
    ldr w0, [x1, w0, lsl #2]
    ret

_tools_init_building_defs:
    // Initialize building definition tables
    ret

// Additional helper functions
_tools_validate_zone_area:
    // Validate an area for zone placement
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    bl _tools_get_context
    cbz x0, validate_area_fail
    mov x19, x0
    
    // Get drag bounds
    ldr w0, [x19, tool_drag_start_x]
    ldr w1, [x19, tool_drag_start_y]
    ldr w2, [x19, tool_drag_end_x]
    ldr w3, [x19, tool_drag_end_y]
    
    // Normalize coordinates
    cmp w0, w2
    csel w20, w0, w2, le    // min_x
    csel w21, w2, w0, le    // max_x
    cmp w1, w3
    csel w22, w1, w3, le    // min_y
    csel w23, w3, w1, le    // max_y
    
    // Check each tile in the area
    mov w24, w22        // current_y
    
validate_area_y_loop:
    cmp w24, w23
    b.gt validate_area_success
    
    mov w25, w20        // current_x
    
validate_area_x_loop:
    cmp w25, w21
    b.gt next_area_y
    
    // Validate individual tile
    ldr w0, [x19, tool_active_tool]
    mov w1, w25
    mov w2, w24
    bl _tools_validate_placement
    cbz w0, validate_area_fail
    
    add w25, w25, #1
    b validate_area_x_loop
    
next_area_y:
    add w24, w24, #1
    b validate_area_y_loop
    
validate_area_success:
    mov w0, #1
    b validate_area_done
    
validate_area_fail:
    mov w0, #0
    
validate_area_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

_tools_analyze_road_connections:
    // Analyze surrounding tiles for road connectivity
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _tools_get_context
    cbz x0, analyze_roads_done
    mov x19, x0
    
    // Get cursor position
    ldr w0, [x19, tool_cursor_x]
    ldr w1, [x19, tool_cursor_y]
    
    // Check adjacent tiles for existing roads
    // North
    sub w2, w1, #1
    bl _sim_get_tile_type
    cmp w0, #5      // TILE_ROAD
    
    // East
    ldr w0, [x19, tool_cursor_x]
    ldr w1, [x19, tool_cursor_y]
    add w0, w0, #1
    bl _sim_get_tile_type
    
    // South, West - similar checks
    // Store connection information for rendering
    
analyze_roads_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_tools_get_zone_color:
    // Get color for zone type in w0
    cmp w0, #TOOL_ZONE_RESIDENTIAL
    b.eq return_residential_color
    cmp w0, #TOOL_ZONE_COMMERCIAL
    b.eq return_commercial_color
    cmp w0, #TOOL_ZONE_INDUSTRIAL
    b.eq return_industrial_color
    
    mov w0, #COLOR_INVALID_PLACEMENT
    ret
    
return_residential_color:
    mov w0, #COLOR_ZONE_RESIDENTIAL
    ret
    
return_commercial_color:
    mov w0, #COLOR_ZONE_COMMERCIAL
    ret
    
return_industrial_color:
    mov w0, #COLOR_ZONE_INDUSTRIAL
    ret

_tools_get_building_size:
    // Get building size for building type in w0
    // Returns: w0 = width, w1 = height
    cmp w0, #TOOL_BUILDING_POLICE
    b.eq return_2x2_building
    cmp w0, #TOOL_BUILDING_FIRE
    b.eq return_2x2_building
    cmp w0, #TOOL_BUILDING_HOSPITAL
    b.eq return_3x3_building
    cmp w0, #TOOL_BUILDING_SCHOOL
    b.eq return_3x3_building
    cmp w0, #TOOL_BUILDING_PARK
    b.eq return_1x1_building
    
    // Default 1x1
return_1x1_building:
    mov w0, #1
    mov w1, #1
    ret
    
return_2x2_building:
    mov w0, #2
    mov w1, #2
    ret
    
return_3x3_building:
    mov w0, #3
    mov w1, #3
    ret

// Camera interface stub
_camera_world_to_screen:
    // Convert world coordinates to screen coordinates
    // w0 = world_x, w1 = world_y
    // Returns: w0 = screen_x, w1 = screen_y
    
    // Simple implementation - multiply by tile size
    mov w2, #32     // Tile size in pixels
    mul w0, w0, w2
    mul w1, w1, w2
    
    // Add camera offset (simplified)
    add w0, w0, #100
    add w1, w1, #100
    
    ret

// Tool execution functions
_tools_execute_bulldoze:
    // Execute bulldozer action at cursor position
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _tools_get_context
    cbz x0, execute_bulldoze_done
    mov x19, x0
    
    // Get cursor position
    ldr w0, [x19, tool_cursor_x]
    ldr w1, [x19, tool_cursor_y]
    
    // Execute bulldoze operation
    bl _tools_bulldoze
    
execute_bulldoze_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_tools_execute_building_placement:
    // Execute building placement at cursor position
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _tools_get_context
    cbz x0, execute_building_done
    mov x19, x0
    
    // Get building type and position
    ldr w0, [x19, tool_active_tool]
    ldr w1, [x19, tool_cursor_x]
    ldr w2, [x19, tool_cursor_y]
    
    // Execute building placement
    bl _tools_place_building
    
execute_building_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_tools_place_road_tile:
    // Place a single road tile at cursor position
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _tools_get_context
    cbz x0, place_road_tile_done
    mov x19, x0
    
    // Get cursor position
    ldr w0, [x19, tool_cursor_x]
    ldr w1, [x19, tool_cursor_y]
    
    // Validate placement
    mov w2, #TOOL_ROAD
    bl _tools_validate_placement
    cbz w0, place_road_tile_done
    
    // Check cost
    mov w0, #COST_ROAD
    bl _sim_get_money
    cmp w0, #COST_ROAD
    b.lt place_road_tile_done
    
    // Deduct cost
    mov w0, #COST_ROAD
    bl _sim_deduct_money
    
    // Place road in simulation
    ldr w0, [x19, tool_cursor_x]
    ldr w1, [x19, tool_cursor_y]
    mov w2, #5          // TILE_ROAD
    bl _sim_place_tile
    
place_road_tile_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Simulation interface stubs (these would be implemented by Agent 4)
_sim_get_tile_type:
    mov w0, #0
    ret

_sim_get_money:
    mov w0, #10000
    ret

_sim_deduct_money:
    ret

_sim_place_building:
    ret

_sim_remove_tile:
    ret

_sim_place_zone:
    ret

_sim_validate_zone_placement:
    mov w0, #1
    ret

_sim_validate_building_placement:
    mov w0, #1
    ret

_sim_place_tile:
    ret

.data
.align 3

building_costs:
    .word 0                 // TOOL_NONE
    .word COST_BULLDOZER    // TOOL_BULLDOZER
    .word COST_ZONE         // TOOL_ZONE_RESIDENTIAL
    .word COST_ZONE         // TOOL_ZONE_COMMERCIAL
    .word COST_ZONE         // TOOL_ZONE_INDUSTRIAL
    .word COST_ROAD         // TOOL_ROAD
    .word COST_POWER_LINE   // TOOL_POWER
    .word COST_WATER_PIPE   // TOOL_WATER
    .word COST_POLICE_STATION   // TOOL_BUILDING_POLICE
    .word COST_FIRE_STATION     // TOOL_BUILDING_FIRE
    .word COST_HOSPITAL         // TOOL_BUILDING_HOSPITAL
    .word COST_SCHOOL           // TOOL_BUILDING_SCHOOL
    .word COST_PARK             // TOOL_BUILDING_PARK

tool_names:
    .quad tool_name_none
    .quad tool_name_bulldozer
    .quad tool_name_res_zone
    .quad tool_name_com_zone
    .quad tool_name_ind_zone
    .quad tool_name_road
    .quad tool_name_power
    .quad tool_name_water
    .quad tool_name_police
    .quad tool_name_fire
    .quad tool_name_hospital
    .quad tool_name_school
    .quad tool_name_park

tool_name_none:        .asciz "None"
tool_name_bulldozer:   .asciz "Bulldozer"
tool_name_res_zone:    .asciz "Residential Zone"
tool_name_com_zone:    .asciz "Commercial Zone"
tool_name_ind_zone:    .asciz "Industrial Zone"
tool_name_road:        .asciz "Road"
tool_name_power:       .asciz "Power Lines"
tool_name_water:       .asciz "Water Pipes"
tool_name_police:      .asciz "Police Station"
tool_name_fire:        .asciz "Fire Station"
tool_name_hospital:    .asciz "Hospital"
tool_name_school:      .asciz "School"
tool_name_park:        .asciz "Park"

.bss
.align 3
tool_context:
    .space 8    // Pointer to tool context