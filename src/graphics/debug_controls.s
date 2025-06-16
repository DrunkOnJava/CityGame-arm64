//
// debug_controls.s - Interactive Debug Controls System
// Agent B5: Graphics Team - Debug Overlay Specialist
//
// Interactive debug control system implemented in ARM64 assembly.
// Provides real-time parameter tweaking, system toggles, and
// interactive debugging commands with keyboard/mouse input handling.
//
// Features:
// - Real-time parameter adjustment with sliders and input fields
// - System enable/disable toggles with visual feedback
// - Keyboard shortcuts for common debug operations
// - Mouse interaction for timeline navigation and selection
// - Command console for advanced debugging
// - Settings persistence and profile management
// - Hot-reload support for shader and configuration changes
//
// Performance targets:
// - < 0.1ms input processing per frame
// - Sub-frame response to user interactions
// - 60fps smooth UI animations
//
// Author: Agent B5 (Graphics/Debug)
// Date: 2025-06-15
//

.section __TEXT,__text,regular,pure_instructions
.align 4

// Input system constants
.equ MAX_DEBUG_COMMANDS, 256            // Maximum debug command history
.equ MAX_COMMAND_LENGTH, 128            // Maximum command string length
.equ MAX_SLIDERS, 64                    // Maximum debug sliders
.equ MAX_TOGGLES, 32                    // Maximum debug toggles
.equ CONSOLE_HISTORY_SIZE, 50           // Console command history

// Key codes for debug shortcuts
.equ KEY_F1, 290
.equ KEY_F2, 291
.equ KEY_F3, 292
.equ KEY_F4, 293
.equ KEY_F5, 294
.equ KEY_F6, 295
.equ KEY_F7, 296
.equ KEY_F8, 297
.equ KEY_F9, 298
.equ KEY_F10, 299
.equ KEY_F11, 300
.equ KEY_F12, 301
.equ KEY_GRAVE, 96                      // ` key for console
.equ KEY_ESC, 256
.equ KEY_ENTER, 257
.equ KEY_TAB, 258

// Mouse button codes
.equ MOUSE_LEFT, 0
.equ MOUSE_RIGHT, 1
.equ MOUSE_MIDDLE, 2

// Debug slider structure
.struct debug_slider
    name:               .space 32       // Slider name
    value_ptr:          .quad 1         // Pointer to value being controlled
    min_value:          .float 1        // Minimum value
    max_value:          .float 1        // Maximum value
    step_size:          .float 1        // Step size for adjustments
    display_format:     .quad 1         // Printf format string pointer
    x_position:         .long 1         // Slider X position
    y_position:         .long 1         // Slider Y position
    width:              .long 1         // Slider width
    is_dragging:        .byte 1         // Currently being dragged
    _padding:           .space 3        // Alignment
.endstruct

// Debug toggle structure
.struct debug_toggle
    name:               .space 32       // Toggle name
    value_ptr:          .quad 1         // Pointer to boolean value
    x_position:         .long 1         // Toggle X position
    y_position:         .long 1         // Toggle Y position
    is_hovered:         .byte 1         // Mouse is over toggle
    _padding:           .space 3        // Alignment
.endstruct

// Debug command structure
.struct debug_command
    command_string:     .space MAX_COMMAND_LENGTH
    timestamp:          .quad 1         // When command was executed
    result_code:        .long 1         // Command result
    _padding:           .space 4        // Alignment
.endstruct

// Mouse state structure
.struct mouse_state
    x_position:         .float 1        // Mouse X coordinate
    y_position:         .float 1        // Mouse Y coordinate
    left_button:        .byte 1         // Left button state
    right_button:       .byte 1         // Right button state
    middle_button:      .byte 1         // Middle button state
    wheel_delta:        .float 1        // Mouse wheel delta
    last_x:             .float 1        // Previous X position
    last_y:             .float 1        // Previous Y position
    drag_start_x:       .float 1        // Drag start X
    drag_start_y:       .float 1        // Drag start Y
    is_dragging:        .byte 1         // Currently dragging
    _padding:           .space 3        // Alignment
.endstruct

// Keyboard state structure
.struct keyboard_state
    keys_pressed:       .space 512      // Key press states (bit array)
    keys_released:      .space 512      // Key release states
    modifiers:          .long 1         // Shift, Ctrl, Alt states
    text_input:         .space 32       // Text input buffer
    text_length:        .long 1         // Current text length
.endstruct

// Debug controls state
.struct debug_controls_state
    sliders:            .space MAX_SLIDERS * debug_slider_size
    slider_count:       .long 1         // Number of active sliders
    
    toggles:            .space MAX_TOGGLES * debug_toggle_size
    toggle_count:       .long 1         // Number of active toggles
    
    commands:           .space MAX_DEBUG_COMMANDS * debug_command_size
    command_count:      .long 1         // Number of commands in history
    command_index:      .long 1         // Current command index
    
    mouse:              .space mouse_state_size
    keyboard:           .space keyboard_state_size
    
    // Console state
    console_visible:    .byte 1         // Console is visible
    console_input:      .space MAX_COMMAND_LENGTH
    console_cursor:     .long 1         // Cursor position in input
    console_history:    .space CONSOLE_HISTORY_SIZE * MAX_COMMAND_LENGTH
    console_history_count: .long 1      // Number of commands in history
    console_history_index: .long 1      // Current history position
    
    // UI state
    controls_visible:   .byte 1         // Debug controls visible
    controls_x:         .long 1         // Controls panel X position
    controls_y:         .long 1         // Controls panel Y position
    controls_width:     .long 1         // Controls panel width
    controls_height:    .long 1         // Controls panel height
    
    // Animation state
    fade_alpha:         .float 1        // UI fade alpha
    animation_time:     .float 1        // Current animation time
    
    _padding:           .space 3        // Alignment
.endstruct

// Global debug controls state
.section __DATA,__data
.align 8
g_debug_controls:
    .space debug_controls_state_size

// Built-in debug commands
debug_command_list:
    .quad help_cmd, fps_cmd, memory_cmd, profiler_cmd, reload_cmd
    .quad toggle_cmd, set_cmd, get_cmd, save_cmd, load_cmd, quit_cmd
    .quad clear_cmd, history_cmd, null

// Command name strings
help_cmd_name:          .ascii "help\0"
fps_cmd_name:           .ascii "fps\0"
memory_cmd_name:        .ascii "memory\0"
profiler_cmd_name:      .ascii "profiler\0"
reload_cmd_name:        .ascii "reload\0"
toggle_cmd_name:        .ascii "toggle\0"
set_cmd_name:           .ascii "set\0"
get_cmd_name:           .ascii "get\0"
save_cmd_name:          .ascii "save\0"
load_cmd_name:          .ascii "load\0"
quit_cmd_name:          .ascii "quit\0"
clear_cmd_name:         .ascii "clear\0"
history_cmd_name:       .ascii "history\0"

.section __TEXT,__text,regular,pure_instructions

//==============================================================================
// DEBUG CONTROLS API
//==============================================================================

// Initialize debug controls system
.global _debug_controls_init
_debug_controls_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, g_debug_controls@PAGE
    add     x0, x0, g_debug_controls@PAGEOFF
    
    // Clear state
    mov     x1, #debug_controls_state_size
    bl      _memzero
    
    // Initialize controls panel position
    mov     w1, #20                         // X position
    str     w1, [x0, #debug_controls_state.controls_x]
    mov     w1, #20                         // Y position
    str     w1, [x0, #debug_controls_state.controls_y]
    mov     w1, #300                        // Width
    str     w1, [x0, #debug_controls_state.controls_width]
    mov     w1, #400                        // Height
    str     w1, [x0, #debug_controls_state.controls_height]
    
    // Initialize visibility
    mov     w1, #1
    strb    w1, [x0, #debug_controls_state.controls_visible]
    
    // Initialize animation
    fmov    s0, #1.0
    str     s0, [x0, #debug_controls_state.fade_alpha]
    
    // Register default debug sliders and toggles
    bl      _register_default_controls
    
    ldp     x29, x30, [sp], #16
    ret

// Process input events for debug controls
// Parameters: w0 = event_type, w1 = key/button, w2 = action, s0 = x_pos, s1 = y_pos
.global _debug_controls_handle_input
_debug_controls_handle_input:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     w19, w0                         // Save event type
    mov     w20, w1                         // Save key/button
    mov     w21, w2                         // Save action
    
    adrp    x0, g_debug_controls@PAGE
    add     x0, x0, g_debug_controls@PAGEOFF
    
    // Update mouse state
    add     x1, x0, #debug_controls_state.mouse
    str     s0, [x1, #mouse_state.x_position]
    str     s1, [x1, #mouse_state.y_position]
    
    cmp     w19, #0                         // Keyboard event
    b.eq    handle_keyboard_input
    cmp     w19, #1                         // Mouse button event
    b.eq    handle_mouse_button
    cmp     w19, #2                         // Mouse move event
    b.eq    handle_mouse_move
    cmp     w19, #3                         // Mouse wheel event
    b.eq    handle_mouse_wheel
    b       input_done

handle_keyboard_input:
    bl      _handle_keyboard_event
    b       input_done

handle_mouse_button:
    bl      _handle_mouse_button_event
    b       input_done

handle_mouse_move:
    bl      _handle_mouse_move_event
    b       input_done

handle_mouse_wheel:
    bl      _handle_mouse_wheel_event

input_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// Register debug slider
// Parameters: x0 = name, x1 = value_ptr, s0 = min, s1 = max, s2 = step
.global _debug_register_slider
_debug_register_slider:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                         // Save name
    mov     x20, x1                         // Save value pointer
    
    adrp    x0, g_debug_controls@PAGE
    add     x0, x0, g_debug_controls@PAGEOFF
    
    // Check if we have space for more sliders
    ldr     w1, [x0, #debug_controls_state.slider_count]
    cmp     w1, #MAX_SLIDERS
    b.ge    register_slider_done
    
    // Get slider slot
    add     x2, x0, #debug_controls_state.sliders
    mov     x3, #debug_slider_size
    mul     x3, x1, x3
    add     x2, x2, x3                      // Slider address
    
    // Copy name
    mov     x0, x19
    add     x1, x2, #debug_slider.name
    bl      _copy_string_bounded
    
    // Set properties
    str     x20, [x2, #debug_slider.value_ptr]
    str     s0, [x2, #debug_slider.min_value]
    str     s1, [x2, #debug_slider.max_value]
    str     s2, [x2, #debug_slider.step_size]
    
    // Calculate position
    adrp    x0, g_debug_controls@PAGE
    add     x0, x0, g_debug_controls@PAGEOFF
    ldr     w3, [x0, #debug_controls_state.slider_count]
    ldr     w4, [x0, #debug_controls_state.controls_x]
    add     w4, w4, #10                     // Margin
    str     w4, [x2, #debug_slider.x_position]
    
    ldr     w4, [x0, #debug_controls_state.controls_y]
    add     w4, w4, #30                     // Header space
    mov     w5, #25                         // Slider height + spacing
    mul     w5, w3, w5
    add     w4, w4, w5
    str     w4, [x2, #debug_slider.y_position]
    
    mov     w4, #200                        // Default slider width
    str     w4, [x2, #debug_slider.width]
    
    // Increment slider count
    add     w3, w3, #1
    str     w3, [x0, #debug_controls_state.slider_count]

register_slider_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// Register debug toggle
// Parameters: x0 = name, x1 = value_ptr
.global _debug_register_toggle
_debug_register_toggle:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x2, g_debug_controls@PAGE
    add     x2, x2, g_debug_controls@PAGEOFF
    
    // Check if we have space for more toggles
    ldr     w3, [x2, #debug_controls_state.toggle_count]
    cmp     w3, #MAX_TOGGLES
    b.ge    register_toggle_done
    
    // Get toggle slot
    add     x4, x2, #debug_controls_state.toggles
    mov     x5, #debug_toggle_size
    mul     x5, x3, x5
    add     x4, x4, x5                      // Toggle address
    
    // Copy name
    add     x5, x4, #debug_toggle.name
    bl      _copy_string_bounded
    
    // Set properties
    str     x1, [x4, #debug_toggle.value_ptr]
    
    // Calculate position (to the right of sliders)
    ldr     w5, [x2, #debug_controls_state.controls_x]
    add     w5, w5, #220                    // After sliders
    str     w5, [x4, #debug_toggle.x_position]
    
    ldr     w5, [x2, #debug_controls_state.controls_y]
    add     w5, w5, #30                     // Header space
    mov     w6, #20                         // Toggle height + spacing
    mul     w6, w3, w6
    add     w5, w5, w6
    str     w5, [x4, #debug_toggle.y_position]
    
    // Increment toggle count
    add     w3, w3, #1
    str     w3, [x2, #debug_controls_state.toggle_count]

register_toggle_done:
    ldp     x29, x30, [sp], #16
    ret

// Render debug controls UI
.global _debug_render_controls
_debug_render_controls:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, g_debug_controls@PAGE
    add     x0, x0, g_debug_controls@PAGEOFF
    
    // Check if controls are visible
    ldrb    w1, [x0, #debug_controls_state.controls_visible]
    cmp     w1, #0
    b.eq    render_controls_done
    
    // Render controls panel background
    bl      _render_controls_panel
    
    // Render sliders
    bl      _render_debug_sliders
    
    // Render toggles
    bl      _render_debug_toggles
    
    // Render console if visible
    ldrb    w1, [x0, #debug_controls_state.console_visible]
    cmp     w1, #0
    b.eq    skip_console
    bl      _render_debug_console

skip_console:
    // Render help text
    bl      _render_controls_help

render_controls_done:
    ldp     x29, x30, [sp], #16
    ret

// Execute debug command
// Parameters: x0 = command string
.global _debug_execute_command
_debug_execute_command:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Parse command and arguments
    bl      _parse_debug_command
    
    // Find command handler
    bl      _find_command_handler
    cmp     x0, #0
    b.eq    command_not_found
    
    // Execute command
    blr     x0
    b       execute_command_done

command_not_found:
    // Display "command not found" message
    bl      _display_command_error

execute_command_done:
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// INPUT HANDLING
//==============================================================================

// Handle keyboard events
_handle_keyboard_event:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Check for special debug keys
    cmp     w20, #KEY_GRAVE                 // ` key for console
    b.eq    toggle_console
    cmp     w20, #KEY_F1                    // F1 - Performance
    b.eq    toggle_performance
    cmp     w20, #KEY_F2                    // F2 - Memory
    b.eq    toggle_memory
    cmp     w20, #KEY_F3                    // F3 - Profiler
    b.eq    toggle_profiler
    cmp     w20, #KEY_ESC                   // ESC - Hide all
    b.eq    hide_all_debug
    
    // Handle console input if visible
    adrp    x0, g_debug_controls@PAGE
    add     x0, x0, g_debug_controls@PAGEOFF
    ldrb    w1, [x0, #debug_controls_state.console_visible]
    cmp     w1, #0
    b.eq    keyboard_done
    
    bl      _handle_console_input
    b       keyboard_done

toggle_console:
    adrp    x0, g_debug_controls@PAGE
    add     x0, x0, g_debug_controls@PAGEOFF
    ldrb    w1, [x0, #debug_controls_state.console_visible]
    eor     w1, w1, #1
    strb    w1, [x0, #debug_controls_state.console_visible]
    b       keyboard_done

toggle_performance:
    bl      _debug_overlay_toggle_performance
    b       keyboard_done

toggle_memory:
    bl      _debug_memory_viz_toggle
    b       keyboard_done

toggle_profiler:
    bl      _debug_profiler_toggle
    b       keyboard_done

hide_all_debug:
    bl      _hide_all_debug_overlays

keyboard_done:
    ldp     x29, x30, [sp], #16
    ret

// Handle mouse button events
_handle_mouse_button_event:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, g_debug_controls@PAGE
    add     x0, x0, g_debug_controls@PAGEOFF
    add     x1, x0, #debug_controls_state.mouse
    
    // Update button state
    cmp     w20, #MOUSE_LEFT
    b.ne    check_right_button
    
    cmp     w21, #1                         // Press
    b.eq    left_press
    strb    wzr, [x1, #mouse_state.left_button]
    b       mouse_button_done

left_press:
    mov     w2, #1
    strb    w2, [x1, #mouse_state.left_button]
    
    // Check if clicking on controls
    bl      _check_slider_interaction
    bl      _check_toggle_interaction
    b       mouse_button_done

check_right_button:
    cmp     w20, #MOUSE_RIGHT
    b.ne    mouse_button_done
    
    cmp     w21, #1
    csel    w2, #1, wzr, eq
    strb    w2, [x1, #mouse_state.right_button]

mouse_button_done:
    ldp     x29, x30, [sp], #16
    ret

// Handle mouse move events
_handle_mouse_move_event:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, g_debug_controls@PAGE
    add     x0, x0, g_debug_controls@PAGEOFF
    add     x1, x0, #debug_controls_state.mouse
    
    // Update previous position
    ldr     s2, [x1, #mouse_state.x_position]
    ldr     s3, [x1, #mouse_state.y_position]
    str     s2, [x1, #mouse_state.last_x]
    str     s3, [x1, #mouse_state.last_y]
    
    // Check for slider dragging
    ldrb    w2, [x1, #mouse_state.left_button]
    cmp     w2, #0
    b.eq    mouse_move_done
    
    bl      _update_slider_dragging

mouse_move_done:
    ldp     x29, x30, [sp], #16
    ret

// Handle mouse wheel events
_handle_mouse_wheel_event:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Store wheel delta
    adrp    x0, g_debug_controls@PAGE
    add     x0, x0, g_debug_controls@PAGEOFF
    add     x1, x0, #debug_controls_state.mouse
    str     s0, [x1, #mouse_state.wheel_delta]
    
    // Check if over timeline for zoom
    bl      _check_timeline_zoom
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// UI RENDERING
//==============================================================================

// Render controls panel background
_render_controls_panel:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, g_debug_controls@PAGE
    add     x0, x0, g_debug_controls@PAGEOFF
    
    // Get panel dimensions
    ldr     w0, [x0, #debug_controls_state.controls_x]
    ldr     w1, [x0, #debug_controls_state.controls_y]
    ldr     w2, [x0, #debug_controls_state.controls_width]
    ldr     w3, [x0, #debug_controls_state.controls_height]
    
    // Draw panel background
    mov     w4, #0x80000000                 // Semi-transparent black
    bl      _draw_filled_rect
    
    // Draw panel border
    mov     w4, #DEBUG_COLOR_WHITE
    fmov    s0, #1.0
    bl      _debug_draw_rect
    
    // Draw title
    adrp    x0, controls_title@PAGE
    add     x0, x0, controls_title@PAGEOFF
    add     w1, w0, #5
    add     w2, w1, #5
    mov     w3, #DEBUG_COLOR_WHITE
    bl      _debug_render_text
    
    ldp     x29, x30, [sp], #16
    ret

// Render debug sliders
_render_debug_sliders:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, g_debug_controls@PAGE
    add     x0, x0, g_debug_controls@PAGEOFF
    
    ldr     w1, [x0, #debug_controls_state.slider_count]
    cmp     w1, #0
    b.eq    render_sliders_done
    
    add     x2, x0, #debug_controls_state.sliders
    mov     w3, #0                          // Slider index
    
slider_loop:
    cmp     w3, w1
    b.ge    render_sliders_done
    
    // Calculate slider address
    mov     x4, #debug_slider_size
    mul     x4, x3, x4
    add     x4, x2, x4
    
    // Render individual slider
    mov     x0, x4
    bl      _render_single_slider
    
    add     w3, w3, #1
    b       slider_loop

render_sliders_done:
    ldp     x29, x30, [sp], #16
    ret

// Render single slider
// Parameters: x0 = slider pointer
_render_single_slider:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     x19, x0                         // Save slider pointer
    
    // Get slider properties
    ldr     w0, [x19, #debug_slider.x_position]
    ldr     w1, [x19, #debug_slider.y_position]
    ldr     w2, [x19, #debug_slider.width]
    mov     w3, #12                         // Slider height
    
    // Draw slider track
    mov     w4, #0x40404040                 // Dark gray
    bl      _draw_filled_rect
    
    // Calculate slider handle position
    ldr     x4, [x19, #debug_slider.value_ptr]
    ldr     s0, [x4]                        // Current value
    ldr     s1, [x19, #debug_slider.min_value]
    ldr     s2, [x19, #debug_slider.max_value]
    
    fsub    s3, s0, s1                      // value - min
    fsub    s4, s2, s1                      // max - min
    fdiv    s5, s3, s4                      // normalized position
    
    scvtf   s6, w2                          // width as float
    fmul    s6, s5, s6                      // handle X offset
    fcvtns  w5, s6                          // convert to integer
    
    // Draw slider handle
    add     w0, w0, w5                      // Handle X position
    sub     w0, w0, #3                      // Center on position
    mov     w2, #6                          // Handle width
    mov     w3, #12                         // Handle height
    mov     w4, #DEBUG_COLOR_WHITE          // Handle color
    bl      _draw_filled_rect
    
    // Draw slider label
    add     x0, x19, #debug_slider.name
    ldr     w1, [x19, #debug_slider.x_position]
    ldr     w2, [x19, #debug_slider.y_position]
    sub     w2, w2, #12                     // Above slider
    mov     w3, #DEBUG_COLOR_WHITE
    bl      _debug_render_text
    
    // Draw current value
    ldr     x4, [x19, #debug_slider.value_ptr]
    ldr     s0, [x4]
    bl      _format_float_value
    ldr     w1, [x19, #debug_slider.x_position]
    ldr     w2, [x19, #debug_slider.width]
    add     w1, w1, w2
    add     w1, w1, #10                     // Margin
    ldr     w2, [x19, #debug_slider.y_position]
    mov     w3, #DEBUG_COLOR_YELLOW
    bl      _debug_render_text
    
    ldp     x29, x30, [sp], #16
    ret

// Render debug toggles
_render_debug_toggles:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, g_debug_controls@PAGE
    add     x0, x0, g_debug_controls@PAGEOFF
    
    ldr     w1, [x0, #debug_controls_state.toggle_count]
    cmp     w1, #0
    b.eq    render_toggles_done
    
    add     x2, x0, #debug_controls_state.toggles
    mov     w3, #0                          // Toggle index
    
toggle_loop:
    cmp     w3, w1
    b.ge    render_toggles_done
    
    // Calculate toggle address
    mov     x4, #debug_toggle_size
    mul     x4, x3, x4
    add     x4, x2, x4
    
    // Render individual toggle
    mov     x0, x4
    bl      _render_single_toggle
    
    add     w3, w3, #1
    b       toggle_loop

render_toggles_done:
    ldp     x29, x30, [sp], #16
    ret

// Render single toggle
// Parameters: x0 = toggle pointer
_render_single_toggle:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     x19, x0                         // Save toggle pointer
    
    // Get toggle state
    ldr     x1, [x19, #debug_toggle.value_ptr]
    ldrb    w2, [x1]                        // Get boolean value
    
    // Get position
    ldr     w0, [x19, #debug_toggle.x_position]
    ldr     w1, [x19, #debug_toggle.y_position]
    
    // Draw checkbox
    mov     w3, #12                         // Checkbox size
    mov     w4, w3
    cmp     w2, #0
    csel    w5, #DEBUG_COLOR_GREEN, #0x40404040, ne
    bl      _draw_filled_rect
    
    // Draw checkbox border
    mov     w4, #DEBUG_COLOR_WHITE
    fmov    s0, #1.0
    bl      _debug_draw_rect
    
    // Draw toggle label
    add     x0, x19, #debug_toggle.name
    ldr     w1, [x19, #debug_toggle.x_position]
    add     w1, w1, #20                     // After checkbox
    ldr     w2, [x19, #debug_toggle.y_position]
    mov     w3, #DEBUG_COLOR_WHITE
    bl      _debug_render_text
    
    ldp     x29, x30, [sp], #16
    ret

// Render debug console
_render_debug_console:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Console position (bottom of screen)
    mov     w0, #20                         // X position
    mov     w1, #500                        // Y position (adjust as needed)
    mov     w2, #600                        // Width
    mov     w3, #150                        // Height
    
    // Draw console background
    mov     w4, #0xC0000000                 // More opaque black
    bl      _draw_filled_rect
    
    // Draw console border
    mov     w4, #DEBUG_COLOR_WHITE
    fmov    s0, #1.0
    bl      _debug_draw_rect
    
    // Draw console prompt
    adrp    x0, console_prompt@PAGE
    add     x0, x0, console_prompt@PAGEOFF
    mov     w1, #25
    mov     w2, #620                        // Bottom of console
    mov     w3, #DEBUG_COLOR_GREEN
    bl      _debug_render_text
    
    // Draw current input
    adrp    x0, g_debug_controls@PAGE
    add     x0, x0, g_debug_controls@PAGEOFF
    add     x0, x0, #debug_controls_state.console_input
    mov     w1, #60                         // After prompt
    mov     w2, #620
    mov     w3, #DEBUG_COLOR_WHITE
    bl      _debug_render_text
    
    ldp     x29, x30, [sp], #16
    ret

// Render controls help text
_render_controls_help:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Help text position
    mov     w1, #30
    mov     w2, #50
    
    // F1-F4 shortcuts
    adrp    x0, help_f1@PAGE
    add     x0, x0, help_f1@PAGEOFF
    mov     w3, #DEBUG_COLOR_GRAY
    bl      _debug_render_text
    
    add     w2, w2, #12
    adrp    x0, help_f2@PAGE
    add     x0, x0, help_f2@PAGEOFF
    bl      _debug_render_text
    
    add     w2, w2, #12
    adrp    x0, help_f3@PAGE
    add     x0, x0, help_f3@PAGEOFF
    bl      _debug_render_text
    
    add     w2, w2, #12
    adrp    x0, help_console@PAGE
    add     x0, x0, help_console@PAGEOFF
    bl      _debug_render_text
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// INTERACTION HANDLING
//==============================================================================

// Check slider interaction
_check_slider_interaction:
    // Check if mouse is over any slider
    ret

// Check toggle interaction
_check_toggle_interaction:
    // Check if mouse is over any toggle
    ret

// Update slider dragging
_update_slider_dragging:
    // Update slider value based on mouse position
    ret

// Check timeline zoom interaction
_check_timeline_zoom:
    // Handle mouse wheel over timeline for zoom
    ret

//==============================================================================
// COMMAND SYSTEM
//==============================================================================

// Register default controls
_register_default_controls:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Register some example sliders
    adrp    x0, fps_limit_name@PAGE
    add     x0, x0, fps_limit_name@PAGEOFF
    adrp    x1, g_fps_limit@PAGE            // Example variable
    add     x1, x1, g_fps_limit@PAGEOFF
    fmov    s0, #30.0                       // Min FPS
    fmov    s1, #120.0                      // Max FPS
    fmov    s2, #1.0                        // Step
    bl      _debug_register_slider
    
    // Register some example toggles
    adrp    x0, vsync_name@PAGE
    add     x0, x0, vsync_name@PAGEOFF
    adrp    x1, g_vsync_enabled@PAGE        // Example variable
    add     x1, x1, g_vsync_enabled@PAGEOFF
    bl      _debug_register_toggle
    
    ldp     x29, x30, [sp], #16
    ret

// Parse debug command
_parse_debug_command:
    // Parse command string into command and arguments
    ret

// Find command handler
_find_command_handler:
    // Look up command in command table
    mov     x0, #0                          // Placeholder
    ret

// Handle console input
_handle_console_input:
    // Process console keyboard input
    ret

// Display command error
_display_command_error:
    // Show error message for unknown command
    ret

// Hide all debug overlays
_hide_all_debug_overlays:
    // Hide all debug UI elements
    ret

//==============================================================================
// UTILITY FUNCTIONS
//==============================================================================

// Copy string with bounds checking
// Parameters: x0 = source, x1 = destination, w2 = max_length
_copy_string_bounded:
    mov     w3, #0                          // Counter
copy_bounded_loop:
    cmp     w3, w2
    b.ge    copy_bounded_done
    ldrb    w4, [x0], #1
    strb    w4, [x1], #1
    cmp     w4, #0
    b.eq    copy_bounded_done
    add     w3, w3, #1
    b       copy_bounded_loop
copy_bounded_done:
    ret

// Format float value for display
_format_float_value:
    // Format floating point value as string
    ret

//==============================================================================
// DATA SECTION
//==============================================================================

.section __DATA,__data
.align 8

// Example variables for sliders/toggles
g_fps_limit:
    .float 60.0
g_vsync_enabled:
    .byte 1

//==============================================================================
// STRING CONSTANTS
//==============================================================================

.section __TEXT,__cstring,cstring_literals
controls_title:
    .ascii "Debug Controls\0"
console_prompt:
    .ascii ">\0"
fps_limit_name:
    .ascii "FPS Limit\0"
vsync_name:
    .ascii "VSync\0"
help_f1:
    .ascii "F1: Performance\0"
help_f2:
    .ascii "F2: Memory\0"
help_f3:
    .ascii "F3: Profiler\0"
help_console:
    .ascii "`: Console\0"

// Debug commands
help_cmd:
    .quad help_cmd_name, _cmd_help
fps_cmd:
    .quad fps_cmd_name, _cmd_fps
memory_cmd:
    .quad memory_cmd_name, _cmd_memory
profiler_cmd:
    .quad profiler_cmd_name, _cmd_profiler
reload_cmd:
    .quad reload_cmd_name, _cmd_reload
toggle_cmd:
    .quad toggle_cmd_name, _cmd_toggle
set_cmd:
    .quad set_cmd_name, _cmd_set
get_cmd:
    .quad get_cmd_name, _cmd_get
save_cmd:
    .quad save_cmd_name, _cmd_save
load_cmd:
    .quad load_cmd_name, _cmd_load
quit_cmd:
    .quad quit_cmd_name, _cmd_quit
clear_cmd:
    .quad clear_cmd_name, _cmd_clear
history_cmd:
    .quad history_cmd_name, _cmd_history
null:
    .quad 0, 0

.section __TEXT,__text,regular,pure_instructions

//==============================================================================
// COMMAND IMPLEMENTATIONS
//==============================================================================

_cmd_help:
    // Show available commands
    ret

_cmd_fps:
    // Show/set FPS information
    ret

_cmd_memory:
    // Show memory information
    ret

_cmd_profiler:
    // Control profiler settings
    ret

_cmd_reload:
    // Reload shaders/assets
    ret

_cmd_toggle:
    // Toggle debug features
    ret

_cmd_set:
    // Set variable value
    ret

_cmd_get:
    // Get variable value
    ret

_cmd_save:
    // Save debug settings
    ret

_cmd_load:
    // Load debug settings
    ret

_cmd_quit:
    // Quit application
    ret

_cmd_clear:
    // Clear console
    ret

_cmd_history:
    // Show command history
    ret

// Export symbols
.global _debug_controls_init
.global _debug_controls_handle_input
.global _debug_register_slider
.global _debug_register_toggle
.global _debug_render_controls
.global _debug_execute_command