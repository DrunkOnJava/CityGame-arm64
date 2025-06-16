// SimCity ARM64 Assembly - Immediate Mode GUI Framework
// Agent 7: User Interface & Interaction
// 
// Provides IMGUI-style interface with widget management
// Target: <2ms UI update time, responsive 120Hz input
// Features: Efficient vertex generation and batch rendering

.global _ui_init
.global _ui_begin_frame
.global _ui_end_frame
.global _ui_button
.global _ui_slider
.global _ui_text
.global _ui_window_begin
.global _ui_window_end
.global _ui_get_context
.global _ui_set_mouse_pos
.global _ui_set_mouse_state
.global _ui_process_input
.global _ui_checkbox
.global _ui_radio_button
.global _ui_progress_bar
.global _ui_image_button
.global _ui_tooltip
.global _ui_menu_bar
.global _ui_separator

.align 2

// UI Constants
.equ UI_MAX_VERTICES, 65536
.equ UI_MAX_INDICES, 98304
.equ UI_MAX_DRAW_COMMANDS, 4096
.equ UI_MAX_WINDOWS, 64
.equ UI_VERTEX_SIZE, 32        // Position(8) + UV(8) + Color(4) + padding(12)
.equ UI_INDEX_SIZE, 2

// Widget types
.equ WIDGET_BUTTON, 1
.equ WIDGET_SLIDER, 2
.equ WIDGET_TEXT, 3
.equ WIDGET_WINDOW, 4

// Widget states
.equ WIDGET_STATE_NORMAL, 0
.equ WIDGET_STATE_HOVERED, 1
.equ WIDGET_STATE_PRESSED, 2
.equ WIDGET_STATE_FOCUSED, 3

// Colors (RGBA8888)
.equ COLOR_BUTTON_NORMAL, 0xFF404040
.equ COLOR_BUTTON_HOVERED, 0xFF505050
.equ COLOR_BUTTON_PRESSED, 0xFF606060
.equ COLOR_TEXT, 0xFFFFFFFF
.equ COLOR_WINDOW_BG, 0xE0202020
.equ COLOR_SLIDER_BG, 0xFF303030
.equ COLOR_SLIDER_GRAB, 0xFF808080

// UI Context Structure
.struct 0
ui_vertex_buffer:       .space 8    // Pointer to vertex buffer
ui_index_buffer:        .space 8    // Pointer to index buffer
ui_draw_commands:       .space 8    // Pointer to draw command buffer
ui_vertex_count:        .space 4    // Current vertex count
ui_index_count:         .space 4    // Current index count
ui_draw_command_count:  .space 4    // Current draw command count
ui_mouse_x:            .space 4     // Mouse X position
ui_mouse_y:            .space 4     // Mouse Y position
ui_mouse_down:         .space 4     // Mouse button states
ui_mouse_clicked:      .space 4     // Mouse click events
ui_hot_id:             .space 8     // Currently hot widget ID
ui_active_id:          .space 8     // Currently active widget ID
ui_current_window:     .space 8     // Current window context
ui_window_stack:       .space 8     // Window stack pointer
ui_font_texture:       .space 8     // Font texture handle
ui_white_texture:      .space 8     // White pixel texture
ui_frame_count:        .space 8     // Frame counter for animations
ui_delta_time:         .space 4     // Frame delta time
ui_context_size:       .space 0

// Draw Command Structure
.struct 0
draw_cmd_texture:      .space 8     // Texture handle
draw_cmd_clip_rect:    .space 16    // Clipping rectangle (x,y,w,h)
draw_cmd_vertex_offset: .space 4    // Vertex buffer offset
draw_cmd_index_offset:  .space 4    // Index buffer offset
draw_cmd_index_count:   .space 4    // Number of indices
draw_cmd_size:         .space 0

// Window Context Structure
.struct 0
window_id:             .space 8     // Window unique ID
window_pos:            .space 8     // Window position (x,y)
window_size:           .space 8     // Window size (w,h)
window_flags:          .space 4     // Window flags
window_cursor_pos:     .space 8     // Current cursor position
window_content_region: .space 16    // Content region bounds
window_scroll:         .space 8     // Scroll offset
window_size:           .space 0

// Initialize UI system
_ui_init:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    // Allocate UI context
    mov x0, ui_context_size
    bl _malloc
    cbz x0, ui_init_fail
    
    adrp x19, ui_context@PAGE
    add x19, x19, ui_context@PAGEOFF
    str x0, [x19]
    mov x20, x0
    
    // Clear context
    mov x1, #0
    mov x2, ui_context_size
    bl _memset
    
    // Allocate vertex buffer
    mov x0, #UI_MAX_VERTICES
    mov x1, #UI_VERTEX_SIZE
    mul x0, x0, x1
    bl _malloc
    cbz x0, ui_init_fail
    str x0, [x20, ui_vertex_buffer]
    
    // Allocate index buffer
    mov x0, #UI_MAX_INDICES
    mov x1, #UI_INDEX_SIZE
    mul x0, x0, x1
    bl _malloc
    cbz x0, ui_init_fail
    str x0, [x20, ui_index_buffer]
    
    // Allocate draw command buffer
    mov x0, #UI_MAX_DRAW_COMMANDS
    mov x1, draw_cmd_size
    mul x0, x0, x1
    bl _malloc
    cbz x0, ui_init_fail
    str x0, [x20, ui_draw_commands]
    
    // Initialize default textures
    bl _ui_create_default_textures
    
    mov x0, #1
    b ui_init_done
    
ui_init_fail:
    mov x0, #0
    
ui_init_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Begin new frame
_ui_begin_frame:
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    bl _ui_get_context
    cbz x0, ui_begin_frame_done
    
    // Reset frame counters
    str wzr, [x0, ui_vertex_count]
    str wzr, [x0, ui_index_count]
    str wzr, [x0, ui_draw_command_count]
    
    // Update frame counter
    ldr x1, [x0, ui_frame_count]
    add x1, x1, #1
    str x1, [x0, ui_frame_count]
    
    // Clear hot/active states for this frame
    str xzr, [x0, ui_hot_id]
    
    // Update delta time (simplified - should get from system)
    mov w1, #16667      // ~16.67ms for 60fps
    str w1, [x0, ui_delta_time]
    
ui_begin_frame_done:
    ldp x29, x30, [sp], #16
    ret

// End frame and prepare for rendering
_ui_end_frame:
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    bl _ui_get_context
    cbz x0, ui_end_frame_done
    
    // Finalize draw commands
    bl _ui_finalize_draw_commands
    
    // Clear active state if no longer pressed
    ldr w1, [x0, ui_mouse_down]
    cbz w1, clear_active
    b ui_end_frame_done
    
clear_active:
    str xzr, [x0, ui_active_id]
    
ui_end_frame_done:
    ldp x29, x30, [sp], #16
    ret

// Button widget
// Parameters: x0 = ID hash, x1 = position (x,y), x2 = size (w,h), x3 = text
// Returns: w0 = 1 if pressed, 0 otherwise
_ui_button:
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    mov x19, x0         // ID
    mov x20, x1         // Position
    mov x21, x2         // Size
    mov x22, x3         // Text
    
    bl _ui_get_context
    cbz x0, button_done
    mov x23, x0
    
    // Check if mouse is over button
    bl _ui_is_mouse_over_rect
    mov w24, w0         // Store hover state
    
    // Determine button state
    mov w25, #WIDGET_STATE_NORMAL
    cbz w24, check_active
    mov w25, #WIDGET_STATE_HOVERED
    str x19, [x23, ui_hot_id]
    
check_active:
    ldr x0, [x23, ui_active_id]
    cmp x0, x19
    b.ne render_button
    mov w25, #WIDGET_STATE_PRESSED
    
render_button:
    // Choose color based on state
    mov w0, #COLOR_BUTTON_NORMAL
    cmp w25, #WIDGET_STATE_HOVERED
    csel w0, w0, #COLOR_BUTTON_HOVERED, ne
    cmp w25, #WIDGET_STATE_PRESSED
    csel w0, w0, #COLOR_BUTTON_PRESSED, eq
    
    // Render button background
    mov x1, x20         // Position
    mov x2, x21         // Size
    mov x3, x0          // Color
    bl _ui_draw_rect
    
    // Render button text
    cbz x22, check_click
    mov x0, x22         // Text
    mov x1, x20         // Position (will be centered)
    mov x2, x21         // Size for centering
    mov w3, #COLOR_TEXT
    bl _ui_draw_text_centered
    
check_click:
    // Check for click
    mov w0, #0
    cbz w24, button_done    // Not hovering
    
    ldr w1, [x23, ui_mouse_clicked]
    cbz w1, button_done     // No click
    
    // Handle click
    ldr w2, [x23, ui_mouse_down]
    cbnz w2, set_active
    
    // Mouse released - check if we were active
    ldr x1, [x23, ui_active_id]
    cmp x1, x19
    cset w0, eq             // Return 1 if button was pressed
    str xzr, [x23, ui_active_id]
    b button_done
    
set_active:
    str x19, [x23, ui_active_id]
    mov w0, #0
    
button_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Slider widget
// Parameters: x0 = ID, x1 = position, x2 = size, x3 = value ptr, x4 = min, x5 = max
// Returns: w0 = 1 if value changed
_ui_slider:
    stp x29, x30, [sp, #64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x29, sp
    
    mov x19, x0         // ID
    mov x20, x1         // Position
    mov x21, x2         // Size
    mov x22, x3         // Value pointer
    mov w23, w4         // Min value
    mov w24, w5         // Max value
    
    bl _ui_get_context
    cbz x0, slider_done
    mov x25, x0
    
    // Draw slider background
    mov x0, x20
    mov x1, x21
    mov w2, #COLOR_SLIDER_BG
    bl _ui_draw_rect
    
    // Calculate slider position
    ldr w0, [x22]       // Current value
    sub w0, w0, w23     // value - min
    sub w1, w24, w23    // max - min
    ldr w2, [x21, #4]   // Width
    sub w2, w2, #20     // Account for grab size
    mul w0, w0, w2
    udiv w0, w0, w1     // (value-min) * width / (max-min)
    add w0, w0, #10     // Center grab
    
    // Draw slider grab
    ldr w1, [x20]       // X position
    add w1, w1, w0      // Add slider offset
    ldr w2, [x20, #4]   // Y position
    mov w3, #20         // Grab width
    ldr w4, [x21, #4]   // Grab height
    
    // Check for interaction with slider grab
    stp w1, w2, [sp, #-16]!     // Create grab rect
    stp w3, w4, [sp, #-16]!
    mov x20, sp                  // Grab position
    add x21, sp, #8             // Grab size
    
    bl _ui_is_mouse_over_rect
    mov w26, w0         // Store hover state
    
    // Handle slider interaction
    mov w27, #0         // Changed flag
    cbz w26, render_slider_grab
    
    // Mouse is over grab - check for drag
    ldr w0, [x25, ui_mouse_down]
    cbz w0, set_hot
    
    // Mouse is down - dragging
    str x19, [x25, ui_active_id]
    
    // Calculate new value based on mouse position
    ldr w0, [x25, ui_mouse_x]
    ldr w1, [x20]               // Slider start X
    sub w0, w0, w1              // Mouse offset from start
    sub w0, w0, #10             // Account for grab center
    
    // Clamp to slider range
    cmp w0, #0
    csel w0, w0, #0, ge
    ldr w1, [x21]               // Slider width
    sub w1, w1, #20             // Account for grab size
    cmp w0, w1
    csel w0, w0, w1, le
    
    // Convert to value range
    sub w1, w24, w23            // max - min
    mul w0, w0, w1
    ldr w2, [x21]               // Slider width
    sub w2, w2, #20
    udiv w0, w0, w2             // Normalize
    add w0, w0, w23             // Add min value
    
    // Check if value changed
    ldr w1, [x22]
    cmp w0, w1
    cset w27, ne
    str w0, [x22]               // Store new value
    
    b render_slider_grab
    
set_hot:
    str x19, [x25, ui_hot_id]
    
render_slider_grab:
    // Draw slider grab
    mov w0, #COLOR_SLIDER_GRAB
    ldr x1, [x25, ui_hot_id]
    cmp x1, x19
    b.ne draw_grab
    mov w0, #COLOR_BUTTON_HOVERED
    
draw_grab:
    mov x1, x20         // Grab position
    add x2, sp, #8      // Grab size
    mov w3, w0          // Color
    bl _ui_draw_rect
    
    add sp, sp, #16     // Clean up stack
    mov w0, w27         // Return changed flag
    
slider_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// Text rendering
// Parameters: x0 = text, x1 = position, w2 = color
_ui_text:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov x19, x0         // Text
    mov x20, x1         // Position
    mov w21, w2         // Color
    
    bl _ui_get_context
    cbz x0, text_done
    
    // Simple text rendering - will be expanded with proper font system
    mov x0, x19
    mov x1, x20
    mov w2, w21
    bl _ui_draw_text_simple
    
text_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Window management
// Parameters: x0 = window_id, x1 = position, x2 = size, x3 = title
// Returns: w0 = 1 if window is open
_ui_window_begin:
    stp x29, x30, [sp, #64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x29, sp
    
    mov x19, x0         // window_id
    mov x20, x1         // position
    mov x21, x2         // size
    mov x22, x3         // title
    
    bl _ui_get_context
    cbz x0, window_begin_fail
    mov x23, x0
    
    // Allocate window context if needed
    ldr x24, [x23, ui_current_window]
    cbnz x24, use_existing_window
    
    // Allocate new window context
    mov x0, window_size
    bl _malloc
    cbz x0, window_begin_fail
    str x0, [x23, ui_current_window]
    mov x24, x0
    
use_existing_window:
    // Initialize window
    str x19, [x24, window_id]
    str x20, [x24, window_pos]
    str x21, [x24, window_size]
    str xzr, [x24, window_flags]
    
    // Set content region (account for title bar)
    ldr w0, [x20]       // x
    ldr w1, [x20, #4]   // y
    add w1, w1, #24     // Add title bar height
    stp w0, w1, [x24, window_content_region]
    
    ldr w0, [x21]       // width
    ldr w1, [x21, #4]   // height
    sub w1, w1, #24     // Subtract title bar height
    stp w0, w1, [x24, window_content_region+8]
    
    // Set cursor to content region start
    ldr w0, [x24, window_content_region]
    ldr w1, [x24, window_content_region+4]
    stp w0, w1, [x24, window_cursor_pos]
    
    // Draw window background
    mov x0, x20         // position
    mov x1, x21         // size
    mov w2, #COLOR_WINDOW_BG
    bl _ui_draw_rect
    
    // Draw title bar if title provided
    cbz x22, window_begin_success
    
    // Title bar background
    ldr w0, [x20]       // x
    ldr w1, [x20, #4]   // y
    stp w0, w1, [sp, #-16]!
    ldr w0, [x21]       // width
    mov w1, #24         // title bar height
    stp w0, w1, [sp, #-16]!
    
    mov x0, sp          // title bar position
    add x1, sp, #8      // title bar size
    mov w2, #COLOR_BUTTON_NORMAL
    bl _ui_draw_rect
    
    // Title text
    mov x0, x22         // title
    mov x1, sp          // position
    add x2, sp, #8      // size
    mov w3, #COLOR_TEXT
    bl _ui_draw_text_centered
    
    add sp, sp, #16
    
window_begin_success:
    mov w0, #1          // Window is open
    b window_begin_done
    
window_begin_fail:
    mov w0, #0          // Window failed to open
    
window_begin_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

_ui_window_end:
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    bl _ui_get_context
    cbz x0, window_end_done
    
    // Clear current window context
    str xzr, [x0, ui_current_window]
    
window_end_done:
    ldp x29, x30, [sp], #16
    ret

// Get UI context
_ui_get_context:
    adrp x0, ui_context@PAGE
    add x0, x0, ui_context@PAGEOFF
    ldr x0, [x0]
    ret

// Input handling
_ui_set_mouse_pos:
    // x0 = x, x1 = y
    bl _ui_get_context
    cbz x0, set_mouse_pos_done
    
    str w0, [x0, ui_mouse_x]
    str w1, [x0, ui_mouse_y]
    
set_mouse_pos_done:
    ret

_ui_set_mouse_state:
    // w0 = button mask
    bl _ui_get_context
    cbz x0, set_mouse_state_done
    
    ldr w1, [x0, ui_mouse_down]
    eor w2, w0, w1          // XOR to find changes
    and w2, w2, w0          // Clicks are new buttons down
    str w2, [x0, ui_mouse_clicked]
    str w0, [x0, ui_mouse_down]
    
set_mouse_state_done:
    ret

_ui_process_input:
    // Process input events and update UI state
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _ui_get_context
    cbz x0, process_input_done
    mov x19, x0
    
    // Process high-frequency input polling for 120Hz responsiveness
    bl _platform_poll_mouse_events
    bl _platform_poll_keyboard_events
    
    // Update mouse state with smoothing for high refresh rates
    bl _ui_update_mouse_smoothing
    
    // Process accumulated input events
    bl _ui_process_mouse_events
    bl _ui_process_keyboard_events
    
    // Clear click events at end of frame
    str wzr, [x19, ui_mouse_clicked]
    
process_input_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Helper functions for rendering
_ui_draw_rect:
    // x0 = position, x1 = size, w2 = color
    stp x29, x30, [sp, #64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x29, sp
    
    mov x19, x0         // Position
    mov x20, x1         // Size
    mov w21, w2         // Color
    
    // Generate vertices for rectangle
    bl _ui_get_context
    cbz x0, draw_rect_done
    mov x22, x0
    
    // Check vertex buffer space
    ldr w0, [x22, ui_vertex_count]
    add w1, w0, #4      // Need 4 vertices
    cmp w1, #UI_MAX_VERTICES
    b.ge draw_rect_done
    
    // Get vertex buffer pointer
    ldr x23, [x22, ui_vertex_buffer]
    mov x1, #UI_VERTEX_SIZE
    mul x1, x0, x1
    add x23, x23, x1
    
    // Extract position and size
    ldr w1, [x19]       // x
    ldr w2, [x19, #4]   // y
    ldr w3, [x20]       // width
    ldr w4, [x20, #4]   // height
    
    // Generate 4 vertices (x, y, u, v, color)
    // Vertex 0: top-left
    str w1, [x23]           // x
    str w2, [x23, #4]       // y
    str wzr, [x23, #8]      // u = 0
    str wzr, [x23, #12]     // v = 0
    str w21, [x23, #16]     // color
    
    // Vertex 1: top-right
    add w5, w1, w3          // x + width
    str w5, [x23, #32]      // x
    str w2, [x23, #36]      // y
    mov w6, #0x3F800000     // 1.0f
    str w6, [x23, #40]      // u = 1
    str wzr, [x23, #44]     // v = 0
    str w21, [x23, #48]     // color
    
    // Vertex 2: bottom-left
    str w1, [x23, #64]      // x
    add w5, w2, w4          // y + height
    str w5, [x23, #68]      // y
    str wzr, [x23, #72]     // u = 0
    str w6, [x23, #76]      // v = 1
    str w21, [x23, #80]     // color
    
    // Vertex 3: bottom-right
    add w5, w1, w3          // x + width
    str w5, [x23, #96]      // x
    add w5, w2, w4          // y + height
    str w5, [x23, #100]     // y
    str w6, [x23, #104]     // u = 1
    str w6, [x23, #108]     // v = 1
    str w21, [x23, #112]    // color
    
    // Generate indices for two triangles
    ldr w0, [x22, ui_vertex_count]
    ldr w1, [x22, ui_index_count]
    ldr x24, [x22, ui_index_buffer]
    
    // Triangle 1: 0, 1, 2
    strh w0, [x24, w1, lsl #1]      // index 0
    add w1, w1, #1
    add w2, w0, #1
    strh w2, [x24, w1, lsl #1]      // index 1
    add w1, w1, #1
    add w2, w0, #2
    strh w2, [x24, w1, lsl #1]      // index 2
    add w1, w1, #1
    
    // Triangle 2: 1, 2, 3
    add w2, w0, #1
    strh w2, [x24, w1, lsl #1]      // index 1
    add w1, w1, #1
    add w2, w0, #2
    strh w2, [x24, w1, lsl #1]      // index 2
    add w1, w1, #1
    add w2, w0, #3
    strh w2, [x24, w1, lsl #1]      // index 3
    add w1, w1, #1
    
    // Update counters
    add w0, w0, #4
    str w0, [x22, ui_vertex_count]
    str w1, [x22, ui_index_count]
    
draw_rect_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

_ui_draw_text_simple:
    // x0 = text, x1 = position, w2 = color
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    mov x19, x0         // Text string
    mov x20, x1         // Position
    mov w21, w2         // Color
    
    cbz x19, draw_text_done
    
    bl _ui_get_context
    cbz x0, draw_text_done
    mov x22, x0
    
    // Get font texture (placeholder)
    ldr x23, [x22, ui_font_texture]
    cbz x23, draw_text_done
    
    // Simple character rendering loop
    mov x24, x19        // Current character pointer
    ldr w25, [x20]      // Current X position
    ldr w26, [x20, #4]  // Y position
    mov w27, #16        // Character width
    mov w28, #16        // Character height
    
draw_char_loop:
    ldrb w0, [x24]      // Load character
    cbz w0, draw_text_done
    
    // Skip non-printable characters
    cmp w0, #32
    b.lt next_char
    cmp w0, #126
    b.gt next_char
    
    // Calculate UV coordinates for character in font atlas
    sub w0, w0, #32     // Normalize to printable range
    and w1, w0, #15     // Column (0-15)
    lsr w2, w0, #4      // Row (0-5)
    
    // UV coordinates (normalized)
    mov w3, #0x3C800000 // 1/16 = 0.0625
    mul w4, w1, w3      // u = column * (1/16)
    mul w5, w2, w3      // v = row * (1/16)
    
    // Generate character quad
    bl _ui_draw_char_quad
    
next_char:
    add x24, x24, #1    // Next character
    add w25, w25, w27   // Advance X position
    b draw_char_loop
    
draw_text_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

_ui_draw_text_centered:
    // x0 = text, x1 = position, x2 = size, w3 = color
    stp x29, x30, [sp, #48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    mov x19, x0         // Text
    mov x20, x1         // Position
    mov x21, x2         // Size
    mov w22, w3         // Color
    
    cbz x19, draw_centered_done
    
    // Calculate text length
    mov x0, x19
    bl _ui_get_text_width
    mov w23, w0         // Text width in pixels
    
    // Calculate centered position
    ldr w0, [x21]       // Rect width
    sub w0, w0, w23     // Rect width - text width
    lsr w0, w0, #1      // Divide by 2
    ldr w1, [x20]       // Original X
    add w0, w1, w0      // Centered X
    
    ldr w1, [x21, #4]   // Rect height
    mov w2, #16         // Font height
    sub w1, w1, w2      // Rect height - font height
    lsr w1, w1, #1      // Divide by 2
    ldr w2, [x20, #4]   // Original Y
    add w1, w2, w1      // Centered Y
    
    // Create centered position
    stp w0, w1, [sp, #-16]!
    mov x1, sp
    
    // Draw text at centered position
    mov x0, x19
    mov w2, w22
    bl _ui_draw_text_simple
    
    add sp, sp, #16
    
draw_centered_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

_ui_is_mouse_over_rect:
    // Check if mouse is over rectangle defined by x20 (pos) and x21 (size)
    bl _ui_get_context
    cbz x0, mouse_over_false
    
    ldr w1, [x0, ui_mouse_x]    // Mouse X
    ldr w2, [x0, ui_mouse_y]    // Mouse Y
    
    ldr w3, [x20]               // Rect X
    ldr w4, [x20, #4]           // Rect Y
    ldr w5, [x21]               // Rect Width
    ldr w6, [x21, #4]           // Rect Height
    
    // Check X bounds
    cmp w1, w3
    b.lt mouse_over_false
    add w7, w3, w5
    cmp w1, w7
    b.ge mouse_over_false
    
    // Check Y bounds
    cmp w2, w4
    b.lt mouse_over_false
    add w7, w4, w6
    cmp w2, w7
    b.ge mouse_over_false
    
    mov w0, #1
    ret
    
mouse_over_false:
    mov w0, #0
    ret

_ui_create_default_textures:
    // Create white pixel texture and basic font atlas
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _ui_get_context
    cbz x0, create_textures_done
    mov x19, x0
    
    // Create 1x1 white pixel texture
    mov w0, #1          // width
    mov w1, #1          // height
    bl _gfx_create_texture_rgba8
    str x0, [x19, ui_white_texture]
    
    // Upload white pixel data
    mov w1, #0xFFFFFFFF // White color
    stp w1, w1, [sp, #-16]!
    mov x1, sp
    mov w2, #4          // 4 bytes
    bl _gfx_upload_texture_data
    add sp, sp, #16
    
    // Create basic font atlas (8x16 bitmap font)
    mov w0, #128        // width (8 chars * 16 pixels)
    mov w1, #96         // height (6 rows * 16 pixels)
    bl _gfx_create_texture_rgba8
    str x0, [x19, ui_font_texture]
    
    // Generate basic font bitmap data
    bl _ui_generate_font_atlas
    
create_textures_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_ui_finalize_draw_commands:
    // Prepare final draw commands for rendering
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _ui_get_context
    cbz x0, finalize_done
    mov x19, x0
    
    // Check if we have any vertices to render
    ldr w0, [x19, ui_vertex_count]
    cbz w0, finalize_done
    
    // Create a single draw command for all UI elements
    ldr x20, [x19, ui_draw_commands]
    ldr w1, [x19, ui_draw_command_count]
    
    // Check space for new draw command
    cmp w1, #UI_MAX_DRAW_COMMANDS
    b.ge finalize_done
    
    // Calculate draw command offset
    mov x2, draw_cmd_size
    mul x2, x1, x2
    add x20, x20, x2
    
    // Set up draw command
    ldr x0, [x19, ui_white_texture]
    str x0, [x20, draw_cmd_texture]
    
    // Set full screen clip rect
    mov w0, #0
    str w0, [x20, draw_cmd_clip_rect]    // x
    str w0, [x20, draw_cmd_clip_rect+4]  // y
    mov w0, #4096
    str w0, [x20, draw_cmd_clip_rect+8]  // width
    str w0, [x20, draw_cmd_clip_rect+12] // height
    
    // Set vertex and index info
    str wzr, [x20, draw_cmd_vertex_offset]
    str wzr, [x20, draw_cmd_index_offset]
    ldr w0, [x19, ui_index_count]
    str w0, [x20, draw_cmd_index_count]
    
    // Increment draw command count
    add w1, w1, #1
    str w1, [x19, ui_draw_command_count]
    
finalize_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Additional helper functions
_ui_draw_char_quad:
    // Draw a single character quad with UV coordinates
    // w25 = x, w26 = y, w27 = width, w28 = height
    // w4 = u, w5 = v, w21 = color
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // Create position and size for character
    stp w25, w26, [sp, #-16]!
    stp w27, w28, [sp, #-16]!
    
    mov x0, sp          // Position
    add x1, sp, #8      // Size
    mov w2, w21         // Color
    bl _ui_draw_rect
    
    add sp, sp, #16
    
    ldp x29, x30, [sp], #16
    ret

_ui_get_text_width:
    // Calculate text width in pixels
    // x0 = text string
    // Returns: w0 = width in pixels
    mov w1, #0          // width counter
    mov w2, #16         // character width
    
text_width_loop:
    ldrb w3, [x0]
    cbz w3, text_width_done
    
    add w1, w1, w2      // Add character width
    add x0, x0, #1      // Next character
    b text_width_loop
    
text_width_done:
    mov w0, w1
    ret

_ui_generate_font_atlas:
    // Generate basic bitmap font data
    // This is a simplified implementation
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // Allocate font bitmap data (128x96 RGBA)
    mov w0, #128
    mov w1, #96
    mul w0, w0, w1
    mov w1, #4          // RGBA
    mul w0, w0, w1
    bl _malloc
    cbz x0, gen_font_done
    
    // Fill with basic character patterns (simplified)
    mov x1, x0
    mov w2, #0xFF000000 // Black background
    mov w3, #0xFFFFFFFF // White foreground
    
    // This would contain actual font data generation
    // For now, create a simple pattern
    
    // Upload to GPU texture
    bl _ui_get_context
    ldr x4, [x0, ui_font_texture]
    mov x0, x4
    mov w2, #49152      // 128*96*4
    bl _gfx_upload_texture_data
    
gen_font_done:
    ldp x29, x30, [sp], #16
    ret

// Graphics system interface stubs
_gfx_create_texture_rgba8:
    // w0 = width, w1 = height
    // Returns: x0 = texture handle
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // Placeholder: return non-zero handle
    mov x0, #1
    
    ldp x29, x30, [sp], #16
    ret

_gfx_upload_texture_data:
    // x0 = texture handle, x1 = data, w2 = size
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // Placeholder implementation
    
    ldp x29, x30, [sp], #16
    ret

// Additional widget implementations

// Checkbox widget
// Parameters: x0 = ID, x1 = position, x2 = size, x3 = checked_ptr, x4 = label
// Returns: w0 = 1 if state changed
_ui_checkbox:
    stp x29, x30, [sp, #64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x29, sp
    
    mov x19, x0         // ID
    mov x20, x1         // Position
    mov x21, x2         // Size
    mov x22, x3         // Checked pointer
    mov x23, x4         // Label
    
    bl _ui_get_context
    cbz x0, checkbox_done
    mov x24, x0
    
    // Draw checkbox box
    ldr w0, [x21]       // Box size (square)
    mov w1, w0
    stp w0, w1, [sp, #-16]!
    
    mov x0, x20         // Position
    mov x1, sp          // Box size
    mov w2, #COLOR_BUTTON_NORMAL
    bl _ui_draw_rect
    
    // Draw checkmark if checked
    ldr w0, [x22]
    cbz w0, draw_checkbox_label
    
    // Simple checkmark (X pattern)
    mov w2, #COLOR_TEXT
    bl _ui_draw_checkmark
    
draw_checkbox_label:
    // Draw label next to checkbox
    cbz x23, check_checkbox_click
    
    ldr w0, [x20]       // Checkbox X
    ldr w1, [x21]       // Box width
    add w0, w0, w1      // X + box width
    add w0, w0, #8      // Add padding
    ldr w1, [x20, #4]   // Y position
    stp w0, w1, [sp, #-16]!
    
    mov x0, x23         // Label text
    mov x1, sp          // Position
    mov w2, #COLOR_TEXT
    bl _ui_draw_text_simple
    
    add sp, sp, #16
    
check_checkbox_click:
    // Check for mouse interaction
    bl _ui_is_mouse_over_rect
    mov w25, w0
    
    mov w0, #0          // Changed flag
    cbz w25, checkbox_done
    
    ldr w1, [x24, ui_mouse_clicked]
    cbz w1, checkbox_done
    
    // Toggle checkbox state
    ldr w1, [x22]
    eor w1, w1, #1
    str w1, [x22]
    mov w0, #1          // State changed
    
    add sp, sp, #16     // Clean up box size
    
checkbox_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// Progress bar widget
// Parameters: x0 = position, x1 = size, w2 = progress (0-100)
_ui_progress_bar:
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov x19, x0         // Position
    mov x20, x1         // Size
    mov w21, w2         // Progress value
    
    // Draw background
    mov x0, x19
    mov x1, x20
    mov w2, #COLOR_SLIDER_BG
    bl _ui_draw_rect
    
    // Calculate progress width
    ldr w0, [x20]       // Total width
    mul w0, w0, w21     // width * progress
    mov w1, #100
    udiv w0, w0, w1     // / 100
    
    // Draw progress bar
    cbz w0, progress_done
    
    mov w1, w0          // Progress width
    ldr w2, [x20, #4]   // Height
    stp w1, w2, [sp, #-16]!
    
    mov x0, x19         // Position
    mov x1, sp          // Progress size
    mov w2, #COLOR_GRAPH_LINE_1
    bl _ui_draw_rect
    
    add sp, sp, #16
    
progress_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Separator line
// Parameters: x0 = position, x1 = width
_ui_separator:
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    mov x19, x0         // Position
    mov w20, w1         // Width
    
    // Create separator size (width x 2 pixels)
    mov w0, #2
    stp w20, w0, [sp, #-16]!
    
    mov x0, x19         // Position
    mov x1, sp          // Size
    mov w2, #COLOR_GRAPH_GRID
    bl _ui_draw_rect
    
    add sp, sp, #16
    
    ldp x29, x30, [sp], #16
    ret

// Helper functions
_ui_draw_checkmark:
    // Draw simple checkmark pattern
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // This would draw actual checkmark lines
    // Simplified implementation
    
    ldp x29, x30, [sp], #16
    ret

// Enhanced input handling functions
_ui_update_mouse_smoothing:
    // Smooth mouse movement for high refresh rate displays
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _ui_get_context
    cbz x0, mouse_smooth_done
    mov x19, x0
    
    // Get raw mouse position
    bl _platform_get_mouse_position
    mov w20, w0         // Raw X
    mov w21, w1         // Raw Y
    
    // Apply smoothing for sub-pixel precision
    ldr w2, [x19, ui_mouse_x]
    ldr w3, [x19, ui_mouse_y]
    
    // Simple linear interpolation for smoothing
    sub w4, w20, w2     // Delta X
    sub w5, w21, w3     // Delta Y
    
    // Apply 90% of movement for smoothness
    mov w6, #9
    mul w4, w4, w6
    mul w5, w5, w6
    mov w6, #10
    udiv w4, w4, w6     // 90% of delta X
    udiv w5, w5, w6     // 90% of delta Y
    
    add w2, w2, w4      // Smoothed X
    add w3, w3, w5      // Smoothed Y
    
    str w2, [x19, ui_mouse_x]
    str w3, [x19, ui_mouse_y]
    
mouse_smooth_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_ui_process_mouse_events:
    // Process accumulated mouse events
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    bl _ui_get_context
    cbz x0, mouse_events_done
    
    // Check for multi-click detection
    bl _ui_detect_double_click
    
    // Update hover states with priority queue
    bl _ui_update_hover_priority
    
mouse_events_done:
    ldp x29, x30, [sp], #16
    ret

_ui_process_keyboard_events:
    // Process keyboard events with repeat handling
    stp x29, x30, [sp, #32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    bl _ui_get_context
    cbz x0, keyboard_events_done
    mov x19, x0
    
    // Process key repeat for held keys
    bl _ui_process_key_repeat
    
    // Handle text input for focused widgets
    bl _ui_process_text_input
    
    // Process navigation keys (Tab, arrows)
    bl _ui_process_navigation
    
keyboard_events_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

_ui_detect_double_click:
    // Detect double-click events
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // Implementation for double-click detection
    // Track timing and position between clicks
    
    ldp x29, x30, [sp], #16
    ret

_ui_update_hover_priority:
    // Update hover states with Z-order priority
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // Ensure topmost widgets get hover priority
    
    ldp x29, x30, [sp], #16
    ret

_ui_process_key_repeat:
    // Handle key repeat for held keys
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // Implementation for key repeat timing
    
    ldp x29, x30, [sp], #16
    ret

_ui_process_text_input:
    // Process text input for focused widgets
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // Handle character input, backspace, etc.
    
    ldp x29, x30, [sp], #16
    ret

_ui_process_navigation:
    // Process navigation keys (Tab, arrows)
    stp x29, x30, [sp, #16]!
    mov x29, sp
    
    // Handle focus navigation between widgets
    
    ldp x29, x30, [sp], #16
    ret

// Platform interface stubs
_platform_poll_mouse_events:
    ret

_platform_poll_keyboard_events:
    ret

_platform_get_mouse_position:
    mov w0, #0
    mov w1, #0
    ret

.data
.align 3

.bss
.align 3
ui_context:
    .space 8    // Pointer to UI context

// Temporary storage for calculations
temp_rect_pos:
    .space 8
temp_rect_size:
    .space 8