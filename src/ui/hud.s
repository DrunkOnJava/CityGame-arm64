// SimCity ARM64 Assembly - HUD Framework
// Agent 7: User Interface & Experience Developer
//
// Main HUD system managing all UI components:
// - Resource displays, building toolbar, minimap
// - Status indicators, notifications, popup dialogs
// - Optimized for 120Hz input and <2ms update time
// - Grid snapping and placement tools integration

.global _hud_init
.global _hud_update
.global _hud_render
.global _hud_handle_input
.global _hud_get_context
.global _hud_show_notification
.global _hud_update_resources
.global _hud_set_info_panel
.global _hud_toggle_panel
.global _hud_get_selected_tool

.align 2

// HUD Layout Constants
.equ HUD_TOP_BAR_HEIGHT, 64
.equ HUD_BOTTOM_BAR_HEIGHT, 128
.equ HUD_SIDE_PANEL_WIDTH, 256
.equ HUD_MINIMAP_SIZE, 200
.equ HUD_TOOLBAR_HEIGHT, 80
.equ HUD_INFO_PANEL_HEIGHT, 150

// HUD Panel IDs
.equ PANEL_NONE, 0
.equ PANEL_BUILDINGS, 1
.equ PANEL_ZONES, 2
.equ PANEL_UTILITIES, 3
.equ PANEL_SERVICES, 4
.equ PANEL_BUDGET, 5
.equ PANEL_GRAPHS, 6
.equ PANEL_OPTIONS, 7

// Resource Types
.equ RESOURCE_MONEY, 0
.equ RESOURCE_POPULATION, 1
.equ RESOURCE_HAPPINESS, 2
.equ RESOURCE_POWER, 3
.equ RESOURCE_WATER, 4
.equ RESOURCE_TRAFFIC, 5
.equ RESOURCE_POLLUTION, 6
.equ RESOURCE_CRIME, 7

// Notification Types
.equ NOTIFY_INFO, 0
.equ NOTIFY_WARNING, 1
.equ NOTIFY_ERROR, 2
.equ NOTIFY_SUCCESS, 3

// Colors
.equ COLOR_HUD_BG, 0xE0202020
.equ COLOR_PANEL_BG, 0xF0303030
.equ COLOR_BUTTON_NORMAL, 0xFF404040
.equ COLOR_BUTTON_SELECTED, 0xFF606060
.equ COLOR_TEXT_PRIMARY, 0xFFFFFFFF
.equ COLOR_TEXT_SECONDARY, 0xFFCCCCCC
.equ COLOR_MONEY_POSITIVE, 0xFF00FF00
.equ COLOR_MONEY_NEGATIVE, 0xFFFF0000
.equ COLOR_WARNING, 0xFFFFAA00
.equ COLOR_ERROR, 0xFFFF4444
.equ COLOR_SUCCESS, 0xFF44FF44

// HUD Context Structure
.struct 0
hud_screen_width:       .space 4    // Screen dimensions
hud_screen_height:      .space 4
hud_active_panel:       .space 4    // Currently active panel
hud_selected_tool:      .space 4    // Selected building/tool
hud_info_text:          .space 8    // Pointer to info text
hud_notification_queue: .space 8    // Notification queue
hud_notification_count: .space 4    // Number of active notifications
hud_minimap_visible:    .space 4    // Minimap visibility
hud_toolbar_visible:    .space 4    // Toolbar visibility
hud_resources:          .space 32   // Resource values (8 resources * 4 bytes)
hud_resource_history:   .space 8    // Pointer to resource history buffer
hud_animation_time:     .space 4    // Animation time for transitions
hud_layout_dirty:       .space 4    // Layout needs recalculation
hud_context_size:       .space 0

// Notification Structure
.struct 0
notify_type:           .space 4     // Notification type
notify_text:           .space 8     // Pointer to notification text
notify_timeout:        .space 4     // Time remaining (ms)
notify_x:              .space 4     // Screen position
notify_y:              .space 4
notify_alpha:          .space 4     // Transparency for fade
notify_size:           .space 0

// Building Tool Button Structure
.struct 0
tool_button_id:        .space 4     // Tool/building ID
tool_button_icon:      .space 8     // Icon texture
tool_button_tooltip:   .space 8     // Tooltip text pointer
tool_button_cost:      .space 4     // Building cost
tool_button_hotkey:    .space 4     // Keyboard shortcut
tool_button_size:      .space 0

// Initialize HUD system
_hud_init:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    // Initialize UI system first
    bl _ui_init
    cbz x0, hud_init_fail
    
    // Initialize camera system
    bl _camera_init
    cbz x0, hud_init_fail
    
    // Initialize tools system
    bl _tools_init
    cbz x0, hud_init_fail
    
    // Allocate HUD context
    mov x0, hud_context_size
    bl _malloc
    cbz x0, hud_init_fail
    
    adrp x19, hud_context@PAGE
    add x19, x19, hud_context@PAGEOFF
    str x0, [x19]
    mov x20, x0
    
    // Clear context
    mov x1, #0
    mov x2, hud_context_size
    bl _memset
    
    // Initialize default values
    mov w1, #1920           // Default screen width
    str w1, [x20, hud_screen_width]
    mov w1, #1080           // Default screen height
    str w1, [x20, hud_screen_height]
    
    // Enable default UI elements
    mov w1, #1
    str w1, [x20, hud_minimap_visible]
    str w1, [x20, hud_toolbar_visible]
    
    // Initialize resources with default values
    mov w1, #10000          // Starting money
    str w1, [x20, hud_resources + (RESOURCE_MONEY * 4)]
    mov w1, #100            // Starting population
    str w1, [x20, hud_resources + (RESOURCE_POPULATION * 4)]
    mov w1, #75             // Starting happiness
    str w1, [x20, hud_resources + (RESOURCE_HAPPINESS * 4)]
    
    // Allocate notification queue
    mov x0, #16             // Max 16 notifications
    mov x1, notify_size
    mul x0, x0, x1
    bl _malloc
    str x0, [x20, hud_notification_queue]
    
    // Allocate resource history buffer (for graphs)
    mov x0, #8              // 8 resources
    mov x1, #100            // 100 history points each
    mul x0, x0, x1
    mov x1, #4              // 4 bytes per value
    mul x0, x0, x1
    bl _malloc
    str x0, [x20, hud_resource_history]
    
    // Initialize building toolbar
    bl _hud_init_toolbar
    
    mov x0, #1
    b hud_init_done
    
hud_init_fail:
    mov x0, #0
    
hud_init_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Update HUD system
_hud_update:
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    // Get frame delta time
    bl _platform_get_delta_time
    mov w19, w0
    
    bl _hud_get_context
    cbz x0, hud_update_done
    mov x20, x0
    
    // Update animation time
    ldr w0, [x20, hud_animation_time]
    add w0, w0, w19
    str w0, [x20, hud_animation_time]
    
    // Update UI framework
    bl _ui_begin_frame
    
    // Update camera controls
    bl _camera_update
    
    // Update building tools
    bl _tools_update
    
    // Update notifications
    bl _hud_update_notifications
    
    // Update resource displays
    bl _hud_update_resource_displays
    
    // Handle input
    bl _hud_process_input
    
    // Check for layout changes
    ldr w0, [x20, hud_layout_dirty]
    cbz w0, hud_update_done
    
    bl _hud_recalculate_layout
    str wzr, [x20, hud_layout_dirty]
    
hud_update_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Render HUD system
_hud_render:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _hud_get_context
    cbz x0, hud_render_done
    mov x19, x0
    
    // Render main HUD elements
    bl _hud_render_top_bar
    bl _hud_render_bottom_toolbar
    
    // Render active side panel
    ldr w0, [x19, hud_active_panel]
    cbz w0, render_minimap
    bl _hud_render_side_panel
    
render_minimap:
    // Render minimap if visible
    ldr w0, [x19, hud_minimap_visible]
    cbz w0, render_notifications
    bl _hud_render_minimap
    
render_notifications:
    // Render notifications
    bl _hud_render_notifications
    
    // Render tool overlays
    bl _tools_render
    
    // Finalize UI rendering
    bl _ui_end_frame
    
hud_render_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Handle HUD input
_hud_handle_input:
    stp x29, x30, [sp, #64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x29, sp
    
    mov w19, w0         // Input type
    mov w20, w1         // Key/button code
    mov w21, w2         // State
    mov w22, w3         // X coordinate
    mov w23, w4         // Y coordinate
    
    bl _hud_get_context
    cbz x0, hud_input_done
    mov x24, x0
    
    // Update UI input state
    cmp w19, #0         // Mouse input
    b.eq handle_mouse_input
    cmp w19, #1         // Keyboard input
    b.eq handle_keyboard_input
    b hud_input_done
    
handle_mouse_input:
    // Update mouse position for UI
    mov x0, x22
    mov x1, x23
    bl _ui_set_mouse_pos
    
    // Update mouse button state
    mov w0, w20
    bl _ui_set_mouse_state
    
    // Check if input is consumed by UI
    bl _hud_check_ui_hit
    cbnz w0, hud_input_done
    
    // Pass to camera controls
    mov w0, w19
    mov w1, w20
    mov w2, w21
    mov w3, w22
    mov w4, w23
    bl _camera_handle_input
    
    // Pass to tools system
    bl _tools_handle_input
    b hud_input_done
    
handle_keyboard_input:
    // Handle HUD-specific hotkeys first
    bl _hud_handle_hotkeys
    cbnz w0, hud_input_done
    
    // Pass to tools system
    mov w0, w19
    mov w1, w20
    mov w2, w21
    mov w3, w22
    mov w4, w23
    bl _tools_handle_input
    
    // Pass to camera controls
    bl _camera_handle_input
    
hud_input_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// Render top bar with resources
_hud_render_top_bar:
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    bl _hud_get_context
    cbz x0, render_top_bar_done
    mov x19, x0
    
    // Create top bar rectangle
    mov w0, #0              // X position
    mov w1, #0              // Y position
    stp w0, w1, [sp, #-16]!
    
    ldr w0, [x19, hud_screen_width]
    mov w1, #HUD_TOP_BAR_HEIGHT
    stp w0, w1, [sp, #-16]!
    
    // Draw top bar background
    mov x0, sp              // Position
    add x1, sp, #8          // Size
    mov w2, #COLOR_HUD_BG
    bl _ui_draw_rect
    
    // Render money display
    mov w0, #20             // X position
    mov w1, #20             // Y position
    stp w0, w1, [sp, #-16]!
    
    ldr w0, [x19, hud_resources + (RESOURCE_MONEY * 4)]
    bl _hud_format_money
    mov x1, x0              // Formatted money string
    
    adrp x0, money_label@PAGE
    add x0, x0, money_label@PAGEOFF
    mov x2, sp              // Position
    mov w3, #COLOR_TEXT_PRIMARY
    bl _hud_render_resource_item
    
    // Render population display
    mov w0, #200            // X position
    mov w1, #20             // Y position
    stp w0, w1, [sp, #-16]!
    
    ldr w0, [x19, hud_resources + (RESOURCE_POPULATION * 4)]
    bl _hud_format_number
    mov x1, x0
    
    adrp x0, population_label@PAGE
    add x0, x0, population_label@PAGEOFF
    mov x2, sp
    mov w3, #COLOR_TEXT_PRIMARY
    bl _hud_render_resource_item
    
    // Render happiness meter
    mov w0, #400            // X position
    mov w1, #20             // Y position
    stp w0, w1, [sp, #-16]!
    
    mov w0, #100            // Progress bar width
    mov w1, #24             // Progress bar height
    stp w0, w1, [sp, #-16]!
    
    ldr w2, [x19, hud_resources + (RESOURCE_HAPPINESS * 4)]
    mov x0, sp              // Position
    add x1, sp, #8          // Size
    bl _ui_progress_bar
    
    // Add clock/date display
    ldr w0, [x19, hud_screen_width]
    sub w0, w0, #150        // Right align
    mov w1, #20
    stp w0, w1, [sp, #-16]!
    
    bl _sim_get_date_string
    mov x1, x0
    adrp x0, time_label@PAGE
    add x0, x0, time_label@PAGEOFF
    mov x2, sp
    mov w3, #COLOR_TEXT_SECONDARY
    bl _hud_render_resource_item
    
    add sp, sp, #48         // Clean up stack allocations
    
render_top_bar_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Render bottom toolbar
_hud_render_bottom_toolbar:
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    bl _hud_get_context
    cbz x0, render_toolbar_done
    mov x19, x0
    
    // Check if toolbar is visible
    ldr w0, [x19, hud_toolbar_visible]
    cbz w0, render_toolbar_done
    
    // Create toolbar rectangle
    mov w0, #0              // X position
    ldr w1, [x19, hud_screen_height]
    sub w1, w1, #HUD_BOTTOM_BAR_HEIGHT  // Y position
    stp w0, w1, [sp, #-16]!
    
    ldr w0, [x19, hud_screen_width]
    mov w1, #HUD_BOTTOM_BAR_HEIGHT
    stp w0, w1, [sp, #-16]!
    
    // Draw toolbar background
    mov x0, sp              // Position
    add x1, sp, #8          // Size
    mov w2, #COLOR_HUD_BG
    bl _ui_draw_rect
    
    // Render tool category buttons
    mov w20, #20            // Start X position
    mov w21, #20            // Button spacing
    
    // Zones button
    mov x0, #0x1001         // Button ID
    mov w1, w20             // X position
    ldr w2, [x19, hud_screen_height]
    sub w2, w2, #100        // Y position
    stp w1, w2, [sp, #-16]!
    
    mov w1, #60             // Button width
    mov w2, #60             // Button height
    stp w1, w2, [sp, #-16]!
    
    adrp x3, zones_label@PAGE
    add x3, x3, zones_label@PAGEOFF
    mov x1, sp              // Position
    add x2, sp, #8          // Size
    bl _ui_button
    
    // Check if zones button was pressed
    cbnz w0, open_zones_panel
    
    add w20, w20, #80       // Next button position
    
    // Buildings button
    mov x0, #0x1002
    mov w1, w20
    ldr w2, [x19, hud_screen_height]
    sub w2, w2, #100
    stp w1, w2, [sp, #-16]!
    
    mov w1, #60
    mov w2, #60
    stp w1, w2, [sp, #-16]!
    
    adrp x3, buildings_label@PAGE
    add x3, x3, buildings_label@PAGEOFF
    mov x1, sp
    add x2, sp, #8
    bl _ui_button
    
    cbnz w0, open_buildings_panel
    
    add w20, w20, #80
    
    // Utilities button
    mov x0, #0x1003
    mov w1, w20
    ldr w2, [x19, hud_screen_height]
    sub w2, w2, #100
    stp w1, w2, [sp, #-16]!
    
    mov w1, #60
    mov w2, #60
    stp w1, w2, [sp, #-16]!
    
    adrp x3, utilities_label@PAGE
    add x3, x3, utilities_label@PAGEOFF
    mov x1, sp
    add x2, sp, #8
    bl _ui_button
    
    cbnz w0, open_utilities_panel
    
    b toolbar_buttons_done
    
open_zones_panel:
    mov w0, #PANEL_ZONES
    str w0, [x19, hud_active_panel]
    b toolbar_buttons_done
    
open_buildings_panel:
    mov w0, #PANEL_BUILDINGS
    str w0, [x19, hud_active_panel]
    b toolbar_buttons_done
    
open_utilities_panel:
    mov w0, #PANEL_UTILITIES
    str w0, [x19, hud_active_panel]
    
toolbar_buttons_done:
    add sp, sp, #32         // Clean up stack
    
render_toolbar_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Render side panel based on active panel
_hud_render_side_panel:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _hud_get_context
    cbz x0, render_panel_done
    mov x19, x0
    
    // Get active panel type
    ldr w0, [x19, hud_active_panel]
    
    cmp w0, #PANEL_ZONES
    b.eq render_zones_panel
    cmp w0, #PANEL_BUILDINGS
    b.eq render_buildings_panel
    cmp w0, #PANEL_UTILITIES
    b.eq render_utilities_panel
    cmp w0, #PANEL_BUDGET
    b.eq render_budget_panel
    b render_panel_done
    
render_zones_panel:
    bl _hud_render_zones_panel
    b render_panel_done
    
render_buildings_panel:
    bl _hud_render_buildings_panel
    b render_panel_done
    
render_utilities_panel:
    bl _hud_render_utilities_panel
    b render_panel_done
    
render_budget_panel:
    bl _hud_render_budget_panel
    
render_panel_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Render zones panel
_hud_render_zones_panel:
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    bl _hud_get_context
    cbz x0, zones_panel_done
    mov x19, x0
    
    // Create panel background
    ldr w0, [x19, hud_screen_width]
    sub w0, w0, #HUD_SIDE_PANEL_WIDTH   // X position (right side)
    mov w1, #HUD_TOP_BAR_HEIGHT         // Y position
    stp w0, w1, [sp, #-16]!
    
    mov w0, #HUD_SIDE_PANEL_WIDTH       // Width
    ldr w1, [x19, hud_screen_height]
    sub w1, w1, #HUD_TOP_BAR_HEIGHT
    sub w1, w1, #HUD_BOTTOM_BAR_HEIGHT  // Height
    stp w0, w1, [sp, #-16]!
    
    mov x0, sp                          // Position
    add x1, sp, #8                      // Size
    mov w2, #COLOR_PANEL_BG
    bl _ui_draw_rect
    
    // Panel title
    adrp x0, zones_title@PAGE
    add x0, x0, zones_title@PAGEOFF
    ldr w1, [x19, hud_screen_width]
    sub w1, w1, #230                    // X position
    mov w2, #100                        // Y position
    stp w1, w2, [sp, #-16]!
    mov x1, sp
    mov w2, #COLOR_TEXT_PRIMARY
    bl _ui_text
    
    // Residential zone button
    mov x0, #0x2001                     // Button ID
    ldr w1, [x19, hud_screen_width]
    sub w1, w1, #200                    // X position
    mov w2, #140                        // Y position
    stp w1, w2, [sp, #-16]!
    
    mov w1, #150                        // Width
    mov w2, #40                         // Height
    stp w1, w2, [sp, #-16]!
    
    adrp x3, residential_label@PAGE
    add x3, x3, residential_label@PAGEOFF
    mov x1, sp                          // Position
    add x2, sp, #8                      // Size
    bl _ui_button
    
    cbnz w0, select_residential
    
    // Commercial zone button
    mov x0, #0x2002
    ldr w1, [x19, hud_screen_width]
    sub w1, w1, #200
    mov w2, #190
    stp w1, w2, [sp, #-16]!
    
    mov w1, #150
    mov w2, #40
    stp w1, w2, [sp, #-16]!
    
    adrp x3, commercial_label@PAGE
    add x3, x3, commercial_label@PAGEOFF
    mov x1, sp
    add x2, sp, #8
    bl _ui_button
    
    cbnz w0, select_commercial
    
    // Industrial zone button
    mov x0, #0x2003
    ldr w1, [x19, hud_screen_width]
    sub w1, w1, #200
    mov w2, #240
    stp w1, w2, [sp, #-16]!
    
    mov w1, #150
    mov w2, #40
    stp w1, w2, [sp, #-16]!
    
    adrp x3, industrial_label@PAGE
    add x3, x3, industrial_label@PAGEOFF
    mov x1, sp
    add x2, sp, #8
    bl _ui_button
    
    cbnz w0, select_industrial
    
    b zones_panel_buttons_done
    
select_residential:
    mov w0, #TOOL_ZONE_RESIDENTIAL
    bl _tools_set_active_tool
    b zones_panel_buttons_done
    
select_commercial:
    mov w0, #TOOL_ZONE_COMMERCIAL
    bl _tools_set_active_tool
    b zones_panel_buttons_done
    
select_industrial:
    mov w0, #TOOL_ZONE_INDUSTRIAL
    bl _tools_set_active_tool
    
zones_panel_buttons_done:
    add sp, sp, #48                     // Clean up stack
    
zones_panel_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Render buildings panel
_hud_render_buildings_panel:
    stp x29, x30, [sp, #64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x29, sp
    
    bl _hud_get_context
    cbz x0, buildings_panel_done
    mov x19, x0
    
    // Similar panel setup as zones
    ldr w0, [x19, hud_screen_width]
    sub w0, w0, #HUD_SIDE_PANEL_WIDTH
    mov w1, #HUD_TOP_BAR_HEIGHT
    stp w0, w1, [sp, #-16]!
    
    mov w0, #HUD_SIDE_PANEL_WIDTH
    ldr w1, [x19, hud_screen_height]
    sub w1, w1, #HUD_TOP_BAR_HEIGHT
    sub w1, w1, #HUD_BOTTOM_BAR_HEIGHT
    stp w0, w1, [sp, #-16]!
    
    mov x0, sp
    add x1, sp, #8
    mov w2, #COLOR_PANEL_BG
    bl _ui_draw_rect
    
    // Panel title
    adrp x0, buildings_title@PAGE
    add x0, x0, buildings_title@PAGEOFF
    ldr w1, [x19, hud_screen_width]
    sub w1, w1, #230
    mov w2, #100
    stp w1, w2, [sp, #-16]!
    mov x1, sp
    mov w2, #COLOR_TEXT_PRIMARY
    bl _ui_text
    
    // Building buttons with grid layout
    mov w20, #140                       // Start Y position
    mov w21, #0                         // Button index
    
buildings_button_loop:
    cmp w21, #5                         // Max 5 building types
    b.ge buildings_panel_buttons_done
    
    // Calculate button position
    and w22, w21, #1                    // Column (0 or 1)
    lsr w23, w21, #1                    // Row
    
    mov w0, #70                         // Button width
    mul w0, w22, w0                     // Column offset
    ldr w1, [x19, hud_screen_width]
    sub w1, w1, #200
    add w0, w1, w0                      // Final X position
    
    mov w1, #50                         // Button height
    mul w1, w23, w1                     // Row offset
    add w1, w20, w1                     // Final Y position
    
    stp w0, w1, [sp, #-16]!
    
    mov w0, #60                         // Button size
    mov w1, #40
    stp w0, w1, [sp, #-16]!
    
    // Get building info for this index
    mov w0, w21
    bl _hud_get_building_info
    mov x22, x0                         // Building info
    
    // Create button ID
    mov x0, #0x3000
    add x0, x0, x21                     // Building button ID
    
    mov x1, sp                          // Position
    add x2, sp, #8                      // Size
    ldr x3, [x22, #8]                   // Building name
    bl _ui_button
    
    cbnz w0, building_selected
    
next_building_button:
    add w21, w21, #1                    // Next building
    add sp, sp, #16                     // Clean up position/size
    b buildings_button_loop
    
building_selected:
    // Set selected building tool
    ldr w0, [x22]                       // Building type/tool ID
    bl _tools_set_active_tool
    b next_building_button
    
buildings_panel_buttons_done:
    add sp, sp, #16                     // Clean up panel rect
    
buildings_panel_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// Render minimap
_hud_render_minimap:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _hud_get_context
    cbz x0, minimap_done
    mov x19, x0
    
    // Position minimap in bottom-right corner
    ldr w0, [x19, hud_screen_width]
    sub w0, w0, #HUD_MINIMAP_SIZE
    sub w0, w0, #20                     // Margin
    
    ldr w1, [x19, hud_screen_height]
    sub w1, w1, #HUD_MINIMAP_SIZE
    sub w1, w1, #HUD_BOTTOM_BAR_HEIGHT
    sub w1, w1, #20                     // Margin
    
    stp w0, w1, [sp, #-16]!
    
    mov w0, #HUD_MINIMAP_SIZE
    mov w1, #HUD_MINIMAP_SIZE
    stp w0, w1, [sp, #-16]!
    
    // Draw minimap background
    mov x0, sp                          // Position
    add x1, sp, #8                      // Size
    mov w2, #0xFF000000                 // Black background
    bl _ui_draw_rect
    
    // Draw world overview (simplified)
    bl _hud_render_minimap_world
    
    // Draw camera viewport indicator
    bl _hud_render_minimap_viewport
    
    add sp, sp, #16                     // Clean up
    
minimap_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Render notifications
_hud_render_notifications:
    stp x29, x30, [sp, #64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x29, sp
    
    bl _hud_get_context
    cbz x0, notifications_done
    mov x19, x0
    
    ldr w20, [x19, hud_notification_count]
    cbz w20, notifications_done
    
    ldr x21, [x19, hud_notification_queue]
    mov w22, #0                         // Notification index
    mov w23, #50                        // Start Y position
    
notification_loop:
    cmp w22, w20
    b.ge notifications_done
    
    // Calculate notification offset
    mov x0, notify_size
    mul x0, x22, x0
    add x24, x21, x0                    // Current notification
    
    // Check if notification is still active
    ldr w0, [x24, notify_timeout]
    cbz w0, next_notification
    
    // Get notification position
    ldr w0, [x24, notify_x]
    ldr w1, [x24, notify_y]
    
    // Use default position if not set
    cbz w0, use_default_position
    cbz w1, use_default_position
    b draw_notification
    
use_default_position:
    ldr w0, [x19, hud_screen_width]
    sub w0, w0, #300                    // Right side
    mov w1, w23                         // Stacked vertically
    
draw_notification:
    stp w0, w1, [sp, #-16]!
    
    mov w0, #280                        // Notification width
    mov w1, #60                         // Notification height
    stp w0, w1, [sp, #-16]!
    
    // Choose color based on notification type
    ldr w2, [x24, notify_type]
    cmp w2, #NOTIFY_ERROR
    mov w0, #COLOR_ERROR
    b.eq draw_notification_bg
    cmp w2, #NOTIFY_WARNING
    mov w0, #COLOR_WARNING
    b.eq draw_notification_bg
    cmp w2, #NOTIFY_SUCCESS
    mov w0, #COLOR_SUCCESS
    b.eq draw_notification_bg
    mov w0, #COLOR_PANEL_BG             // Default info color
    
draw_notification_bg:
    // Apply alpha for fade effect
    ldr w1, [x24, notify_alpha]
    and w0, w0, #0x00FFFFFF             // Clear alpha
    lsl w1, w1, #24                     // Shift alpha to top bits
    orr w2, w0, w1                      // Combine color and alpha
    
    mov x0, sp                          // Position
    add x1, sp, #8                      // Size
    bl _ui_draw_rect
    
    // Draw notification text
    ldr x0, [x24, notify_text]
    mov x1, sp                          // Position
    add x2, sp, #8                      // Size for centering
    mov w3, #COLOR_TEXT_PRIMARY
    bl _ui_draw_text_centered
    
    add sp, sp, #16                     // Clean up position/size
    add w23, w23, #70                   // Next notification Y position
    
next_notification:
    add w22, w22, #1
    b notification_loop
    
notifications_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// Helper functions

_hud_get_context:
    adrp x0, hud_context@PAGE
    add x0, x0, hud_context@PAGEOFF
    ldr x0, [x0]
    ret

// Show notification
_hud_show_notification:
    // w0 = type, x1 = text pointer
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov w19, w0                         // Notification type
    mov x20, x1                         // Text
    
    bl _hud_get_context
    cbz x0, show_notification_done
    mov x21, x0
    
    // Find free notification slot
    ldr w0, [x21, hud_notification_count]
    cmp w0, #16                         // Max notifications
    b.ge show_notification_done
    
    ldr x1, [x21, hud_notification_queue]
    mov x2, notify_size
    mul x2, x0, x2
    add x22, x1, x2                     // Free notification slot
    
    // Fill notification data
    str w19, [x22, notify_type]
    str x20, [x22, notify_text]
    mov w1, #5000                       // 5 second timeout
    str w1, [x22, notify_timeout]
    str wzr, [x22, notify_x]            // Use default position
    str wzr, [x22, notify_y]
    mov w1, #255                        // Full alpha
    str w1, [x22, notify_alpha]
    
    // Increment notification count
    add w0, w0, #1
    str w0, [x21, hud_notification_count]
    
show_notification_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Update notifications (timeouts and fading)
_hud_update_notifications:
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    bl _hud_get_context
    cbz x0, update_notifications_done
    mov x19, x0
    
    bl _platform_get_delta_time
    mov w20, w0                         // Frame delta time
    
    ldr w21, [x19, hud_notification_count]
    cbz w21, update_notifications_done
    
    ldr x22, [x19, hud_notification_queue]
    mov w23, #0                         // Index
    
update_notification_loop:
    cmp w23, w21
    b.ge update_notifications_done
    
    // Get notification
    mov x0, notify_size
    mul x0, x23, x0
    add x24, x22, x0
    
    // Update timeout
    ldr w0, [x24, notify_timeout]
    cbz w0, next_update_notification
    
    sub w0, w0, w20                     // Subtract delta time
    cmp w0, #0
    csel w0, w0, wzr, gt                // Clamp to 0
    str w0, [x24, notify_timeout]
    
    // Update alpha for fade effect
    cmp w0, #1000                       // Start fading in last second
    b.gt next_update_notification
    
    // Calculate fade alpha
    mov w1, #255
    mul w1, w0, w1
    mov w2, #1000
    udiv w1, w1, w2                     // (timeout / 1000) * 255
    str w1, [x24, notify_alpha]
    
next_update_notification:
    add w23, w23, #1
    b update_notification_loop
    
update_notifications_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Resource formatting functions
_hud_format_money:
    // w0 = money value
    // Returns: x0 = formatted string pointer
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    adrp x1, money_buffer@PAGE
    add x1, x1, money_buffer@PAGEOFF
    
    // Simple formatting - just convert to string
    bl _format_number_string
    
    adrp x0, money_buffer@PAGE
    add x0, x0, money_buffer@PAGEOFF
    
    ldp x29, x30, [sp], #16
    ret

_hud_format_number:
    // w0 = number value
    // Returns: x0 = formatted string pointer
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    adrp x1, number_buffer@PAGE
    add x1, x1, number_buffer@PAGEOFF
    
    bl _format_number_string
    
    adrp x0, number_buffer@PAGE
    add x0, x0, number_buffer@PAGEOFF
    
    ldp x29, x30, [sp], #16
    ret

// Additional helper functions and stubs

_hud_init_toolbar:
    // Initialize building toolbar with icons and tooltips
    ret

_hud_process_input:
    // Process HUD-specific input
    ret

_hud_handle_hotkeys:
    // Handle keyboard shortcuts for HUD panels
    // Returns w0 = 1 if handled, 0 if not
    mov w0, #0
    ret

_hud_check_ui_hit:
    // Check if mouse is over UI element
    // Returns w0 = 1 if over UI, 0 if not
    mov w0, #0
    ret

_hud_recalculate_layout:
    // Recalculate UI layout after screen resize
    ret

_hud_update_resource_displays:
    // Update resource counters and history
    ret

_hud_render_resource_item:
    // x0 = label, x1 = value, x2 = position, w3 = color
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    // Draw label
    mov x19, x0         // Label
    mov x20, x1         // Value
    mov x21, x2         // Position
    mov w22, w3         // Color
    
    mov x0, x19
    mov x1, x21
    mov w2, w22
    bl _ui_text
    
    // Draw value next to label
    ldr w0, [x21]       // X position
    add w0, w0, #80     // Offset for value
    ldr w1, [x21, #4]   // Y position
    stp w0, w1, [sp, #-16]!
    
    mov x0, x20
    mov x1, sp
    mov w2, w22
    bl _ui_text
    
    add sp, sp, #16
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_hud_render_utilities_panel:
    // Render utilities panel (roads, power, water)
    ret

_hud_render_budget_panel:
    // Render budget and financial information
    ret

_hud_render_minimap_world:
    // Render simplified world view in minimap
    ret

_hud_render_minimap_viewport:
    // Render camera viewport indicator on minimap
    ret

_hud_get_building_info:
    // w0 = building index
    // Returns: x0 = building info structure
    adrp x0, building_info_table@PAGE
    add x0, x0, building_info_table@PAGEOFF
    mov x1, #24             // Size of building info structure
    mul x1, x0, x1
    add x0, x0, x1
    ret

// Platform interface stubs
_platform_get_delta_time:
    mov w0, #16             // 16ms for 60fps
    ret

_format_number_string:
    // w0 = number, x1 = buffer
    // Simple number to string conversion
    ret

_sim_get_date_string:
    // Returns: x0 = date string
    adrp x0, date_string@PAGE
    add x0, x0, date_string@PAGEOFF
    ret

.data
.align 3

// UI Text Labels
money_label:        .asciz "Money: $"
population_label:   .asciz "Population: "
time_label:         .asciz "Time: "
zones_label:        .asciz "Zones"
buildings_label:    .asciz "Buildings"
utilities_label:    .asciz "Utilities"
zones_title:        .asciz "Zone Tools"
buildings_title:    .asciz "Buildings"
residential_label:  .asciz "Residential"
commercial_label:   .asciz "Commercial"
industrial_label:   .asciz "Industrial"

// Building information table
building_info_table:
    .word TOOL_BUILDING_POLICE      // Police Station
    .word 500                       // Cost
    .quad police_name
    
    .word TOOL_BUILDING_FIRE        // Fire Station
    .word 500                       // Cost
    .quad fire_name
    
    .word TOOL_BUILDING_HOSPITAL    // Hospital
    .word 1000                      // Cost
    .quad hospital_name
    
    .word TOOL_BUILDING_SCHOOL      // School
    .word 750                       // Cost
    .quad school_name
    
    .word TOOL_BUILDING_PARK        // Park
    .word 100                       // Cost
    .quad park_name

police_name:        .asciz "Police"
fire_name:          .asciz "Fire"
hospital_name:      .asciz "Hospital"
school_name:        .asciz "School"
park_name:          .asciz "Park"

date_string:        .asciz "Jan 2025"

.bss
.align 3

hud_context:
    .space 8    // Pointer to HUD context

// String formatting buffers
money_buffer:
    .space 32
number_buffer:
    .space 32