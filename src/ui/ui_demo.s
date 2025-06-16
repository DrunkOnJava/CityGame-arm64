// SimCity ARM64 Assembly - UI System Integration Demo
// Agent 7: User Interface & Experience Developer
//
// Complete UI demonstration showing HUD, tools, and placement systems
// Target: 120Hz responsive interface with <2ms update time
// Features: Interactive demo of all UI components

.global _ui_demo_init
.global _ui_demo_update
.global _ui_demo_render
.global _ui_demo_handle_input
.global _ui_demo_run

.align 2

// Demo state constants
.equ DEMO_STATE_MENU, 0
.equ DEMO_STATE_CITY, 1
.equ DEMO_STATE_BUILDING, 2
.equ DEMO_STATE_PAUSED, 3

// Demo Context Structure
.struct 0
demo_state:             .space 4    // Current demo state
demo_frame_count:       .space 8    // Frame counter
demo_fps_counter:       .space 4    // FPS calculation
demo_last_time:         .space 8    // Last frame time
demo_mouse_x:           .space 4    // Mouse position
demo_mouse_y:           .space 4
demo_mouse_buttons:     .space 4    // Mouse button state
demo_keys_pressed:      .space 4    // Keyboard state
demo_show_debug:        .space 4    // Show debug overlay
demo_performance_mode:  .space 4    // Performance monitoring
demo_tutorial_step:     .space 4    // Tutorial progression
demo_camera_speed:      .space 4    // Camera movement speed
demo_context_size:      .space 0

// Performance Metrics Structure
.struct 0
perf_frame_time:        .space 4    // Current frame time (ms)
perf_ui_time:           .space 4    // UI update time (ms)
perf_render_time:       .space 4    // Render time (ms)
perf_input_time:        .space 4    // Input processing time (ms)
perf_avg_frame_time:    .space 4    // Average frame time
perf_min_frame_time:    .space 4    // Minimum frame time
perf_max_frame_time:    .space 4    // Maximum frame time
perf_vertex_count:      .space 4    // UI vertices generated
perf_draw_calls:        .space 4    // Number of draw calls
perf_memory_used:       .space 4    // Memory usage
perf_metrics_size:      .space 0

// Initialize UI demo
_ui_demo_init:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    // Allocate demo context
    mov x0, demo_context_size
    bl _malloc
    cbz x0, demo_init_fail
    
    adrp x19, demo_context@PAGE
    add x19, x19, demo_context@PAGEOFF
    str x0, [x19]
    mov x20, x0
    
    // Clear context
    mov x1, #0
    mov x2, demo_context_size
    bl _memset
    
    // Initialize demo state
    mov w1, #DEMO_STATE_MENU
    str w1, [x20, demo_state]
    
    // Initialize performance monitoring
    mov w1, #1
    str w1, [x20, demo_performance_mode]
    str w1, [x20, demo_show_debug]
    
    // Set default camera speed
    mov w1, #5
    str w1, [x20, demo_camera_speed]
    
    // Initialize all UI subsystems
    bl _hud_init
    cbz x0, demo_init_fail
    
    bl _placement_init
    cbz x0, demo_init_fail
    
    // Initialize performance metrics
    bl _demo_init_performance_metrics
    
    // Show welcome notification
    mov w0, #NOTIFY_INFO
    adrp x1, welcome_message@PAGE
    add x1, x1, welcome_message@PAGEOFF
    bl _hud_show_notification
    
    mov x0, #1
    b demo_init_done
    
demo_init_fail:
    mov x0, #0
    
demo_init_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Update demo
_ui_demo_update:
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    // Start performance timing
    bl _platform_get_time_ms
    mov x19, x0                         // Frame start time
    
    bl _demo_get_context
    cbz x0, demo_update_done
    mov x20, x0
    
    // Update frame counter
    ldr x1, [x20, demo_frame_count]
    add x1, x1, #1
    str x1, [x20, demo_frame_count]
    
    // Calculate delta time
    ldr x2, [x20, demo_last_time]
    sub x21, x19, x2                    // Delta time
    str x19, [x20, demo_last_time]
    
    // Update based on demo state
    ldr w0, [x20, demo_state]
    
    cmp w0, #DEMO_STATE_MENU
    b.eq update_menu_state
    cmp w0, #DEMO_STATE_CITY
    b.eq update_city_state
    cmp w0, #DEMO_STATE_BUILDING
    b.eq update_building_state
    cmp w0, #DEMO_STATE_PAUSED
    b.eq update_paused_state
    
    b state_update_done
    
update_menu_state:
    bl _demo_update_menu
    b state_update_done
    
update_city_state:
    bl _demo_update_city_view
    b state_update_done
    
update_building_state:
    bl _demo_update_building_mode
    b state_update_done
    
update_paused_state:
    bl _demo_update_paused
    
state_update_done:
    // Update UI subsystems
    bl _platform_get_time_ms
    mov x22, x0                         // UI start time
    
    bl _hud_update
    bl _placement_update
    
    // Calculate UI update time
    bl _platform_get_time_ms
    sub x1, x0, x22
    bl _demo_record_ui_time
    
    // Update performance metrics
    ldr w0, [x20, demo_performance_mode]
    cbz w0, demo_update_done
    
    bl _platform_get_time_ms
    sub x0, x0, x19                     // Total frame time
    bl _demo_update_performance_metrics
    
demo_update_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Render demo
_ui_demo_render:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    // Start render timing
    bl _platform_get_time_ms
    mov x19, x0
    
    bl _demo_get_context
    cbz x0, demo_render_done
    mov x20, x0
    
    // Clear screen
    bl _graphics_clear_screen
    
    // Render based on demo state
    ldr w0, [x20, demo_state]
    
    cmp w0, #DEMO_STATE_MENU
    b.eq render_menu_state
    cmp w0, #DEMO_STATE_CITY
    b.eq render_city_state
    cmp w0, #DEMO_STATE_BUILDING
    b.eq render_building_state
    cmp w0, #DEMO_STATE_PAUSED
    b.eq render_paused_state
    
    b state_render_done
    
render_menu_state:
    bl _demo_render_main_menu
    b state_render_done
    
render_city_state:
    bl _demo_render_city_view
    b state_render_done
    
render_building_state:
    bl _demo_render_building_mode
    b state_render_done
    
render_paused_state:
    bl _demo_render_paused_overlay
    
state_render_done:
    // Render HUD system
    bl _hud_render
    
    // Render debug overlay if enabled
    ldr w0, [x20, demo_show_debug]
    cbz w0, skip_debug_render
    bl _demo_render_debug_overlay
    
skip_debug_render:
    // Calculate render time
    bl _platform_get_time_ms
    sub x0, x0, x19
    bl _demo_record_render_time
    
demo_render_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Handle demo input
_ui_demo_handle_input:
    stp x29, x30, [sp, #64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x29, sp
    
    mov w19, w0                         // Input type
    mov w20, w1                         // Key/button code
    mov w21, w2                         // State
    mov w22, w3                         // X coordinate
    mov w23, w4                         // Y coordinate
    
    // Start input timing
    bl _platform_get_time_ms
    mov x24, x0
    
    bl _demo_get_context
    cbz x0, demo_input_done
    
    // Update input state
    cmp w19, #0                         // Mouse input
    b.eq handle_demo_mouse
    cmp w19, #1                         // Keyboard input
    b.eq handle_demo_keyboard
    b pass_to_hud
    
handle_demo_mouse:
    // Store mouse position and button state
    str w22, [x0, demo_mouse_x]
    str w23, [x0, demo_mouse_y]
    str w20, [x0, demo_mouse_buttons]
    b pass_to_hud
    
handle_demo_keyboard:
    // Handle demo-specific hotkeys
    cmp w20, #'`'                       // Backquote key
    b.eq toggle_debug_overlay
    cmp w20, #'p'                       // P key
    b.eq toggle_pause
    cmp w20, #'1'                       // Number keys for demo states
    b.eq switch_to_menu
    cmp w20, #'2'
    b.eq switch_to_city
    cmp w20, #'3'
    b.eq switch_to_building
    cmp w20, #'f'                       // F key for performance
    b.eq toggle_performance_mode
    b pass_to_hud
    
toggle_debug_overlay:
    ldr w1, [x0, demo_show_debug]
    eor w1, w1, #1
    str w1, [x0, demo_show_debug]
    b demo_input_done
    
toggle_pause:
    ldr w1, [x0, demo_state]
    cmp w1, #DEMO_STATE_PAUSED
    mov w2, #DEMO_STATE_CITY
    csel w1, w2, #DEMO_STATE_PAUSED, eq
    str w1, [x0, demo_state]
    b demo_input_done
    
switch_to_menu:
    mov w1, #DEMO_STATE_MENU
    str w1, [x0, demo_state]
    b demo_input_done
    
switch_to_city:
    mov w1, #DEMO_STATE_CITY
    str w1, [x0, demo_state]
    b demo_input_done
    
switch_to_building:
    mov w1, #DEMO_STATE_BUILDING
    str w1, [x0, demo_state]
    bl _placement_start
    b demo_input_done
    
toggle_performance_mode:
    ldr w1, [x0, demo_performance_mode]
    eor w1, w1, #1
    str w1, [x0, demo_performance_mode]
    b demo_input_done
    
pass_to_hud:
    // Pass input to HUD system
    mov w0, w19
    mov w1, w20
    mov w2, w21
    mov w3, w22
    mov w4, w23
    bl _hud_handle_input
    
    // Calculate input processing time
    bl _platform_get_time_ms
    sub x0, x0, x24
    bl _demo_record_input_time
    
demo_input_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// Main demo run loop
_ui_demo_run:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _demo_get_context
    cbz x0, demo_run_done
    mov x19, x0
    
    // Initialize timing
    bl _platform_get_time_ms
    str x0, [x19, demo_last_time]
    
demo_main_loop:
    // Poll for events
    bl _platform_poll_events
    
    // Check for exit condition
    bl _platform_should_exit
    cbnz w0, demo_run_done
    
    // Update demo
    bl _ui_demo_update
    
    // Render demo
    bl _ui_demo_render
    
    // Present frame
    bl _platform_present_frame
    
    // Maintain target frame rate (120Hz = 8.33ms per frame)
    bl _demo_limit_frame_rate
    
    b demo_main_loop
    
demo_run_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Demo state update functions
_demo_update_menu:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _demo_get_context
    cbz x0, update_menu_done
    mov x19, x0
    
    // Check for menu interactions
    // This would typically handle UI button presses to switch states
    
update_menu_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_demo_update_city_view:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _demo_get_context
    cbz x0, update_city_done
    mov x19, x0
    
    // Update camera based on input
    bl _demo_update_camera_controls
    
    // Simulate city growth/changes
    bl _demo_simulate_city_activity
    
    // Update resource displays
    bl _demo_update_city_resources
    
update_city_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_demo_update_building_mode:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _demo_get_context
    cbz x0, update_building_done
    mov x19, x0
    
    // Handle building placement
    ldr w0, [x19, demo_mouse_buttons]
    and w0, w0, #1                      // Left mouse button
    cbnz w0, attempt_building_placement
    
    // Handle rotation with R key
    ldr w0, [x19, demo_keys_pressed]
    and w0, w0, #(1 << 18)              // R key bit
    cbnz w0, rotate_building
    
    b update_building_done
    
attempt_building_placement:
    bl _placement_is_active
    cbz w0, update_building_done
    
    bl _placement_confirm
    cbnz w0, placement_successful
    
    // Show error notification
    mov w0, #NOTIFY_ERROR
    adrp x1, placement_failed_msg@PAGE
    add x1, x1, placement_failed_msg@PAGEOFF
    bl _hud_show_notification
    b update_building_done
    
placement_successful:
    mov w0, #NOTIFY_SUCCESS
    adrp x1, placement_success_msg@PAGE
    add x1, x1, placement_success_msg@PAGEOFF
    bl _hud_show_notification
    b update_building_done
    
rotate_building:
    bl _placement_rotate_building
    
update_building_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_demo_update_paused:
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // Minimal updates when paused
    // Still process UI but not simulation
    
    ldp x29, x30, [sp], #16
    ret

// Demo rendering functions
_demo_render_main_menu:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    // Create main menu window
    mov x0, #0x1000                     // Menu window ID
    mov w1, #400                        // X position (centered)
    mov w2, #300                        // Y position (centered)
    stp w1, w2, [sp, #-16]!
    
    mov w1, #320                        // Width
    mov w2, #280                        // Height
    stp w1, w2, [sp, #-16]!
    
    adrp x3, menu_title@PAGE
    add x3, x3, menu_title@PAGEOFF
    mov x1, sp                          // Position
    add x2, sp, #8                      // Size
    bl _ui_window_begin
    
    cbz w0, menu_window_done
    
    // Start City button
    mov x0, #0x1001
    mov w1, #50                         // X offset in window
    mov w2, #60                         // Y offset in window
    stp w1, w2, [sp, #-16]!
    
    mov w1, #220                        // Button width
    mov w2, #40                         // Button height
    stp w1, w2, [sp, #-16]!
    
    adrp x3, start_city_label@PAGE
    add x3, x3, start_city_label@PAGEOFF
    mov x1, sp
    add x2, sp, #8
    bl _ui_button
    
    cbnz w0, start_city_clicked
    
    // Building Mode button
    mov x0, #0x1002
    mov w1, #50
    mov w2, #110
    stp w1, w2, [sp, #-16]!
    
    mov w1, #220
    mov w2, #40
    stp w1, w2, [sp, #-16]!
    
    adrp x3, building_mode_label@PAGE
    add x3, x3, building_mode_label@PAGEOFF
    mov x1, sp
    add x2, sp, #8
    bl _ui_button
    
    cbnz w0, building_mode_clicked
    
    // Exit button
    mov x0, #0x1003
    mov w1, #50
    mov w2, #160
    stp w1, w2, [sp, #-16]!
    
    mov w1, #220
    mov w2, #40
    stp w1, w2, [sp, #-16]!
    
    adrp x3, exit_label@PAGE
    add x3, x3, exit_label@PAGEOFF
    mov x1, sp
    add x2, sp, #8
    bl _ui_button
    
    cbnz w0, exit_clicked
    
    add sp, sp, #48                     // Clean up button allocations
    bl _ui_window_end
    b menu_render_done
    
start_city_clicked:
    bl _demo_get_context
    mov w1, #DEMO_STATE_CITY
    str w1, [x0, demo_state]
    add sp, sp, #48
    bl _ui_window_end
    b menu_render_done
    
building_mode_clicked:
    bl _demo_get_context
    mov w1, #DEMO_STATE_BUILDING
    str w1, [x0, demo_state]
    mov w0, #TOOL_BUILDING_POLICE
    bl _placement_start
    add sp, sp, #48
    bl _ui_window_end
    b menu_render_done
    
exit_clicked:
    bl _platform_request_exit
    add sp, sp, #48
    bl _ui_window_end
    b menu_render_done
    
menu_window_done:
    add sp, sp, #16                     // Clean up window position/size
    
menu_render_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_demo_render_city_view:
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // Render city background/world
    bl _demo_render_city_background
    
    // Render city buildings and infrastructure
    bl _demo_render_city_buildings
    
    ldp x29, x30, [sp], #16
    ret

_demo_render_building_mode:
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // Render city view as background
    bl _demo_render_city_view
    
    // Render building placement overlay
    bl _placement_render
    
    ldp x29, x30, [sp], #16
    ret

_demo_render_paused_overlay:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    // Render semi-transparent overlay
    mov w0, #0                          // Full screen
    mov w1, #0
    stp w0, w1, [sp, #-16]!
    
    mov w0, #1920                       // Screen size
    mov w1, #1080
    stp w0, w1, [sp, #-16]!
    
    mov x0, sp
    add x1, sp, #8
    mov w2, #0x80000000                 // Semi-transparent black
    bl _ui_draw_rect
    
    // Render "PAUSED" text
    adrp x0, paused_text@PAGE
    add x0, x0, paused_text@PAGEOFF
    mov w1, #860                        // Centered X
    mov w2, #500                        // Centered Y
    stp w1, w2, [sp, #-16]!
    mov x1, sp
    mov w2, #COLOR_TEXT_PRIMARY
    bl _ui_text
    
    add sp, sp, #32                     // Clean up stack
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_demo_render_debug_overlay:
    stp x29, x30, [sp, #64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x29, sp
    
    // Create debug window
    mov x0, #0x2000                     // Debug window ID
    mov w1, #10                         // Top-left position
    mov w2, #10
    stp w1, w2, [sp, #-16]!
    
    mov w1, #300                        // Size
    mov w2, #400
    stp w1, w2, [sp, #-16]!
    
    adrp x3, debug_title@PAGE
    add x3, x3, debug_title@PAGEOFF
    mov x1, sp
    add x2, sp, #8
    bl _ui_window_begin
    
    cbz w0, debug_window_done
    
    // Get performance metrics
    bl _demo_get_performance_metrics
    mov x19, x0
    
    // Display frame time
    adrp x0, frame_time_label@PAGE
    add x0, x0, frame_time_label@PAGEOFF
    mov w1, #20                         // Window-relative position
    mov w2, #60
    stp w1, w2, [sp, #-16]!
    mov x1, sp
    mov w2, #COLOR_TEXT_PRIMARY
    bl _ui_text
    
    // Display FPS
    ldr w0, [x19, perf_avg_frame_time]
    bl _demo_calculate_fps
    bl _demo_format_fps
    mov x20, x0                         // Formatted FPS string
    
    mov x0, x20
    mov w1, #150
    mov w2, #60
    stp w1, w2, [sp, #-16]!
    mov x1, sp
    mov w2, #COLOR_TEXT_PRIMARY
    bl _ui_text
    
    // Display UI update time
    adrp x0, ui_time_label@PAGE
    add x0, x0, ui_time_label@PAGEOFF
    mov w1, #20
    mov w2, #85
    stp w1, w2, [sp, #-16]!
    mov x1, sp
    mov w2, #COLOR_TEXT_PRIMARY
    bl _ui_text
    
    ldr w0, [x19, perf_ui_time]
    bl _demo_format_time
    mov x20, x0
    
    mov x0, x20
    mov w1, #150
    mov w2, #85
    stp w1, w2, [sp, #-16]!
    mov x1, sp
    mov w2, #COLOR_TEXT_PRIMARY
    bl _ui_text
    
    // Display render time
    adrp x0, render_time_label@PAGE
    add x0, x0, render_time_label@PAGEOFF
    mov w1, #20
    mov w2, #110
    stp w1, w2, [sp, #-16]!
    mov x1, sp
    mov w2, #COLOR_TEXT_PRIMARY
    bl _ui_text
    
    ldr w0, [x19, perf_render_time]
    bl _demo_format_time
    mov x20, x0
    
    mov x0, x20
    mov w1, #150
    mov w2, #110
    stp w1, w2, [sp, #-16]!
    mov x1, sp
    mov w2, #COLOR_TEXT_PRIMARY
    bl _ui_text
    
    // Display vertex count
    adrp x0, vertex_count_label@PAGE
    add x0, x0, vertex_count_label@PAGEOFF
    mov w1, #20
    mov w2, #135
    stp w1, w2, [sp, #-16]!
    mov x1, sp
    mov w2, #COLOR_TEXT_PRIMARY
    bl _ui_text
    
    ldr w0, [x19, perf_vertex_count]
    bl _demo_format_number
    mov x20, x0
    
    mov x0, x20
    mov w1, #150
    mov w2, #135
    stp w1, w2, [sp, #-16]!
    mov x1, sp
    mov w2, #COLOR_TEXT_PRIMARY
    bl _ui_text
    
    // Performance graph
    mov w1, #20                         // Graph position
    mov w2, #170
    stp w1, w2, [sp, #-16]!
    
    mov w1, #260                        // Graph size
    mov w2, #100
    stp w1, w2, [sp, #-16]!
    
    mov x0, sp                          // Position
    add x1, sp, #8                      // Size
    bl _demo_render_performance_graph
    
    add sp, sp, #80                     // Clean up debug text allocations
    bl _ui_window_end
    b debug_render_done
    
debug_window_done:
    add sp, sp, #16                     // Clean up window rect
    
debug_render_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// Helper functions
_demo_get_context:
    adrp x0, demo_context@PAGE
    add x0, x0, demo_context@PAGEOFF
    ldr x0, [x0]
    ret

_demo_get_performance_metrics:
    adrp x0, performance_metrics@PAGE
    add x0, x0, performance_metrics@PAGEOFF
    ret

// Performance monitoring functions
_demo_init_performance_metrics:
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // Initialize performance metrics with default values
    bl _demo_get_performance_metrics
    mov x1, #perf_metrics_size
    mov x2, #0
    bl _memset
    
    ldp x29, x30, [sp], #16
    ret

_demo_update_performance_metrics:
    // x0 = frame_time_ms
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov w19, w0                         // Frame time
    
    bl _demo_get_performance_metrics
    mov x20, x0
    
    // Update current frame time
    str w19, [x20, perf_frame_time]
    
    // Update min/max frame times
    ldr w1, [x20, perf_min_frame_time]
    cbz w1, set_initial_min
    cmp w19, w1
    csel w1, w19, w1, lt
    str w1, [x20, perf_min_frame_time]
    b check_max
    
set_initial_min:
    str w19, [x20, perf_min_frame_time]
    
check_max:
    ldr w1, [x20, perf_max_frame_time]
    cmp w19, w1
    csel w1, w19, w1, gt
    str w1, [x20, perf_max_frame_time]
    
    // Simple moving average for average frame time
    ldr w1, [x20, perf_avg_frame_time]
    cbz w1, set_initial_avg
    
    // avg = (avg * 15 + new) / 16  (simple filter)
    mov w2, #15
    mul w1, w1, w2
    add w1, w1, w19
    lsr w1, w1, #4                      // Divide by 16
    str w1, [x20, perf_avg_frame_time]
    b update_perf_done
    
set_initial_avg:
    str w19, [x20, perf_avg_frame_time]
    
update_perf_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_demo_record_ui_time:
    // x0 = ui_time_ms
    bl _demo_get_performance_metrics
    str w0, [x0, perf_ui_time]
    ret

_demo_record_render_time:
    // x0 = render_time_ms
    bl _demo_get_performance_metrics
    str w0, [x0, perf_render_time]
    ret

_demo_record_input_time:
    // x0 = input_time_ms
    bl _demo_get_performance_metrics
    str w0, [x0, perf_input_time]
    ret

// Utility functions
_demo_update_camera_controls:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _demo_get_context
    mov x19, x0
    
    // Get mouse delta for camera panning
    ldr w0, [x19, demo_mouse_buttons]
    and w0, w0, #2                      // Right mouse button
    cbz w0, camera_controls_done
    
    // Pan camera based on mouse movement
    // This would calculate mouse delta and call camera pan functions
    
camera_controls_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_demo_simulate_city_activity:
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // Simulate random city events for demonstration
    // Update population, money, happiness, etc.
    
    ldp x29, x30, [sp], #16
    ret

_demo_update_city_resources:
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // Update resource displays with simulated values
    // This would interface with the simulation system
    
    ldp x29, x30, [sp], #16
    ret

_demo_render_city_background:
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // Render a simple grid background
    mov w0, #0x00404040                 // Dark gray
    bl _graphics_clear_color
    
    ldp x29, x30, [sp], #16
    ret

_demo_render_city_buildings:
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // Render some example buildings for demonstration
    // This would integrate with the graphics/sprite system
    
    ldp x29, x30, [sp], #16
    ret

_demo_render_performance_graph:
    // x0 = position, x1 = size
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov x19, x0                         // Graph position
    mov x20, x1                         // Graph size
    
    // Draw graph background
    mov x0, x19
    mov x1, x20
    mov w2, #0xFF202020                 // Dark background
    bl _ui_draw_rect
    
    // Draw frame time history (simplified)
    bl _demo_get_performance_metrics
    
    // Draw target frame time line (8.33ms for 120Hz)
    ldr w0, [x19]                       // Graph X
    mov w1, #8                          // 8ms target
    ldr w2, [x20, #4]                   // Graph height
    mul w1, w1, w2
    mov w3, #20                         // 20ms scale
    udiv w1, w1, w3                     // Scale to graph
    ldr w3, [x19, #4]                   // Graph Y
    add w1, w3, w1                      // Final Y position
    
    ldr w2, [x20]                       // Graph width
    add w2, w0, w2                      // End X
    
    mov w3, #COLOR_WARNING              // Orange line
    bl _graphics_draw_line
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_demo_limit_frame_rate:
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // Target 120Hz = 8.33ms per frame
    bl _platform_get_time_ms
    mov x1, x0
    
    bl _demo_get_context
    ldr x2, [x0, demo_last_time]
    sub x1, x1, x2                      // Elapsed time
    
    cmp x1, #8                          // Target frame time
    b.ge frame_rate_ok
    
    // Sleep for remaining time
    mov x0, #8
    sub x0, x0, x1
    bl _platform_sleep_ms
    
frame_rate_ok:
    ldp x29, x30, [sp], #16
    ret

// Formatting functions
_demo_calculate_fps:
    // w0 = frame_time_ms
    // Returns: w0 = fps
    cbz w0, fps_div_zero
    mov w1, #1000
    udiv w0, w1, w0
    ret
    
fps_div_zero:
    mov w0, #0
    ret

_demo_format_fps:
    // w0 = fps value
    // Returns: x0 = formatted string
    adrp x0, fps_buffer@PAGE
    add x0, x0, fps_buffer@PAGEOFF
    ret

_demo_format_time:
    // w0 = time in ms
    // Returns: x0 = formatted string
    adrp x0, time_buffer@PAGE
    add x0, x0, time_buffer@PAGEOFF
    ret

_demo_format_number:
    // w0 = number
    // Returns: x0 = formatted string
    adrp x0, number_buffer@PAGE
    add x0, x0, number_buffer@PAGEOFF
    ret

// Platform interface stubs
_platform_get_time_ms:
    // Returns current time in milliseconds
    mov x0, #1000
    ret

_platform_poll_events:
    // Poll for system events
    ret

_platform_should_exit:
    // Check if application should exit
    mov w0, #0
    ret

_platform_present_frame:
    // Present the rendered frame
    ret

_platform_request_exit:
    // Request application exit
    ret

_platform_sleep_ms:
    // x0 = milliseconds to sleep
    ret

_graphics_clear_screen:
    // Clear the screen
    ret

_graphics_clear_color:
    // w0 = color
    ret

.data
.align 3

// UI text strings
welcome_message:        .asciz "Welcome to SimCity ARM64 Demo!"
menu_title:            .asciz "SimCity Demo"
start_city_label:      .asciz "Start City View"
building_mode_label:   .asciz "Building Mode"
exit_label:            .asciz "Exit Demo"
paused_text:           .asciz "PAUSED"
debug_title:           .asciz "Debug Info"
frame_time_label:      .asciz "Frame Time:"
ui_time_label:         .asciz "UI Time:"
render_time_label:     .asciz "Render Time:"
vertex_count_label:    .asciz "Vertices:"
placement_failed_msg:  .asciz "Cannot place building here"
placement_success_msg: .asciz "Building placed successfully"

.bss
.align 3

demo_context:
    .space 8    // Pointer to demo context

performance_metrics:
    .space perf_metrics_size

// String formatting buffers
fps_buffer:
    .space 32
time_buffer:
    .space 32
number_buffer:
    .space 32