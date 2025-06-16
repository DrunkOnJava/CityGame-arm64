//
// SimCity ARM64 Assembly - Input Handler System
// Agent D5: Infrastructure Team - Input handling & event dispatch
//
// Pure ARM64 assembly input processing system
// Converts input processing from Cocoa callbacks to pure ARM64 assembly
//

.cpu generic+simd
.arch armv8-a+simd

// Include platform constants and macros
.include "../include/macros/platform_asm.inc"
.include "../include/constants/platform_constants.h"

.section .data
.align 3

//==============================================================================
// Input System State and Configuration
//==============================================================================

// Input system state
.input_system_state:
    input_initialized:          .byte   0
    input_enabled:              .byte   1
    debug_mode:                 .byte   0
    coordinate_debug:           .byte   0
    .align 3
    
    // Event buffer management
    event_buffer_head:          .quad   0
    event_buffer_tail:          .quad   0
    event_buffer_count:         .quad   0
    event_buffer_capacity:      .quad   INPUT_EVENT_BUFFER_SIZE
    
    // Current input state
    mouse_x:                    .float  0.0
    mouse_y:                    .float  0.0
    mouse_buttons:              .quad   0
    key_modifiers:              .quad   0
    
    // Camera control state
    camera_move_speed:          .float  0.05
    camera_zoom_speed:          .float  0.1
    camera_sensitivity:         .float  1.0
    
    // Building placement state
    current_building_type:      .quad   1       // Default to TILE_HOUSE
    placement_mode:             .byte   1       // 0=disabled, 1=place, 2=delete
    grid_snap:                  .byte   1       // Enable grid snapping
    .align 3

// Input event buffer (circular buffer)
.input_event_buffer:
    .space INPUT_EVENT_BUFFER_SIZE * INPUT_EVENT_SIZE

// Key mapping table (key code -> action)
.key_action_map:
    .space 256 * 4  // 256 possible key codes, 4 bytes per action

// Mouse button state tracking
.mouse_button_state:
    left_button_down:           .byte   0
    right_button_down:          .byte   0
    middle_button_down:         .byte   0
    button_4_down:              .byte   0
    .align 3
    
    // Button press timing
    left_button_time:           .quad   0
    right_button_time:          .quad   0
    double_click_threshold:     .quad   500000000   // 500ms in nanoseconds

// Touch gesture state
.gesture_state:
    gesture_active:             .byte   0
    gesture_type:               .byte   0       // 0=none, 1=pan, 2=zoom, 3=rotate
    gesture_start_x:            .float  0.0
    gesture_start_y:            .float  0.0
    gesture_current_x:          .float  0.0
    gesture_current_y:          .float  0.0
    gesture_scale:              .float  1.0
    gesture_rotation:           .float  0.0
    touch_count:                .quad   0
    .align 3

// Command dispatch targets
.dispatch_targets:
    simulation_handler:         .quad   0
    graphics_handler:           .quad   0
    audio_handler:              .quad   0
    ui_handler:                 .quad   0

//==============================================================================
// Input Event Structure Definitions
//==============================================================================

// Input event types
.equ INPUT_EVENT_NONE,          0
.equ INPUT_EVENT_MOUSE_DOWN,    1
.equ INPUT_EVENT_MOUSE_UP,      2
.equ INPUT_EVENT_MOUSE_MOVE,    3
.equ INPUT_EVENT_KEY_DOWN,      4
.equ INPUT_EVENT_KEY_UP,        5
.equ INPUT_EVENT_SCROLL,        6
.equ INPUT_EVENT_GESTURE,       7
.equ INPUT_EVENT_TOUCH,         8

// Input event structure offsets
.equ INPUT_EVENT_TYPE,          0
.equ INPUT_EVENT_TIMESTAMP,     4
.equ INPUT_EVENT_X,             12
.equ INPUT_EVENT_Y,             16
.equ INPUT_EVENT_BUTTON,        20
.equ INPUT_EVENT_KEY_CODE,      24
.equ INPUT_EVENT_MODIFIERS,     28
.equ INPUT_EVENT_DELTA_X,       32
.equ INPUT_EVENT_DELTA_Y,       36
.equ INPUT_EVENT_SIZE,          40

// Input event buffer configuration
.equ INPUT_EVENT_BUFFER_SIZE,   1024

// Mouse button flags
.equ MOUSE_BUTTON_LEFT,         1
.equ MOUSE_BUTTON_RIGHT,        2
.equ MOUSE_BUTTON_MIDDLE,       4

// Key modifier flags (matching NSEvent)
.equ KEY_MOD_SHIFT,             0x20000
.equ KEY_MOD_CONTROL,           0x40000
.equ KEY_MOD_OPTION,            0x80000
.equ KEY_MOD_COMMAND,           0x100000

// Action types for key mapping
.equ ACTION_NONE,               0
.equ ACTION_CAMERA_LEFT,        1
.equ ACTION_CAMERA_RIGHT,       2
.equ ACTION_CAMERA_UP,          3
.equ ACTION_CAMERA_DOWN,        4
.equ ACTION_BUILD_HOUSE,        5
.equ ACTION_BUILD_COMMERCIAL,   6
.equ ACTION_BUILD_INDUSTRIAL,   7
.equ ACTION_BUILD_PARK,         8
.equ ACTION_BUILD_ROAD,         9
.equ ACTION_TOGGLE_OVERLAY,     10
.equ ACTION_PAUSE_SIMULATION,   11
.equ ACTION_SPEED_UP,           12
.equ ACTION_SPEED_DOWN,         13

// Building types (matching CityTileType from demo)
.equ TILE_EMPTY,                0
.equ TILE_ROAD,                 1
.equ TILE_HOUSE,                2
.equ TILE_COMMERCIAL,           3
.equ TILE_INDUSTRIAL,           4
.equ TILE_PARK,                 5

.section .text
.align 4

//==============================================================================
// Public Interface Functions
//==============================================================================

// input_system_init: Initialize the input handling system
// Returns: x0 = 0 on success, error code on failure
.global input_system_init
input_system_init:
    SAVE_REGS
    
    // Check if already initialized
    adrp    x0, input_initialized@PAGE
    add     x0, x0, input_initialized@PAGEOFF
    ldrb    w1, [x0]
    cbnz    w1, input_already_initialized
    
    // Initialize event buffer
    bl      init_event_buffer
    cmp     x0, #0
    b.ne    input_init_error
    
    // Initialize key mapping table
    bl      init_key_mapping
    cmp     x0, #0
    b.ne    input_init_error
    
    // Initialize coordinate conversion system
    bl      init_coordinate_system
    cmp     x0, #0
    b.ne    input_init_error
    
    // Initialize gesture recognition
    bl      init_gesture_system
    cmp     x0, #0
    b.ne    input_init_error
    
    // Set initialized flag
    adrp    x0, input_initialized@PAGE
    add     x0, x0, input_initialized@PAGEOFF
    mov     w1, #1
    strb    w1, [x0]
    
    mov     x0, #0                  // Success
    RESTORE_REGS
    ret

input_already_initialized:
    mov     x0, #0                  // Success (already init)
    RESTORE_REGS
    ret

input_init_error:
    mov     x0, #-1                 // Error
    RESTORE_REGS
    ret

// input_system_shutdown: Shutdown input handling system
// Returns: none
.global input_system_shutdown
input_system_shutdown:
    SAVE_REGS_LIGHT
    
    // Disable input processing
    adrp    x0, input_enabled@PAGE
    add     x0, x0, input_enabled@PAGEOFF
    strb    wzr, [x0]
    
    // Clear event buffer
    bl      clear_event_buffer
    
    // Clear initialized flag
    adrp    x0, input_initialized@PAGE
    add     x0, x0, input_initialized@PAGEOFF
    strb    wzr, [x0]
    
    RESTORE_REGS_LIGHT
    ret

// input_process_events: Process queued input events
// Returns: x0 = number of events processed
.global input_process_events
input_process_events:
    SAVE_REGS
    
    mov     x19, #0                 // Event counter
    
    // Check if input is enabled
    adrp    x0, input_enabled@PAGE
    add     x0, x0, input_enabled@PAGEOFF
    ldrb    w0, [x0]
    cbz     w0, process_events_done
    
process_events_loop:
    // Try to dequeue next event
    bl      dequeue_event
    cbz     x0, process_events_done // No more events
    
    // Process the event
    mov     x1, x0                  // Event pointer
    bl      process_single_event
    
    // Increment counter
    add     x19, x19, #1
    
    // Continue processing
    b       process_events_loop

process_events_done:
    mov     x0, x19                 // Return event count
    RESTORE_REGS
    ret

//==============================================================================
// Cocoa Event Handlers (Called from Objective-C callbacks)
//==============================================================================

// input_handle_mouse_down: Handle mouse down event from Cocoa
// Args: x0 = x coordinate, x1 = y coordinate, x2 = button flags, x3 = modifiers
// Returns: none
.global input_handle_mouse_down
input_handle_mouse_down:
    SAVE_REGS_LIGHT
    
    // Create mouse down event
    mov     x4, #INPUT_EVENT_MOUSE_DOWN
    bl      create_mouse_event
    
    // Queue the event
    bl      enqueue_event
    
    // Update mouse button state
    mov     x0, x2                  // Button flags
    bl      update_mouse_button_state
    
    RESTORE_REGS_LIGHT
    ret

// input_handle_mouse_up: Handle mouse up event from Cocoa
// Args: x0 = x coordinate, x1 = y coordinate, x2 = button flags, x3 = modifiers
// Returns: none
.global input_handle_mouse_up
input_handle_mouse_up:
    SAVE_REGS_LIGHT
    
    // Create mouse up event
    mov     x4, #INPUT_EVENT_MOUSE_UP
    bl      create_mouse_event
    
    // Queue the event
    bl      enqueue_event
    
    // Update mouse button state
    mov     x0, x2                  // Button flags
    bl      clear_mouse_button_state
    
    RESTORE_REGS_LIGHT
    ret

// input_handle_mouse_move: Handle mouse move event from Cocoa
// Args: x0 = x coordinate, x1 = y coordinate, x2 = delta_x, x3 = delta_y
// Returns: none
.global input_handle_mouse_move
input_handle_mouse_move:
    SAVE_REGS_LIGHT
    
    // Update current mouse position
    adrp    x5, mouse_x@PAGE
    add     x5, x5, mouse_x@PAGEOFF
    scvtf   s0, w0
    str     s0, [x5]
    
    adrp    x5, mouse_y@PAGE
    add     x5, x5, mouse_y@PAGEOFF
    scvtf   s1, w1
    str     s1, [x5]
    
    // Create mouse move event
    mov     x4, #INPUT_EVENT_MOUSE_MOVE
    mov     x5, #0                  // No button
    bl      create_mouse_event_with_delta
    
    // Queue the event
    bl      enqueue_event
    
    RESTORE_REGS_LIGHT
    ret

// input_handle_key_down: Handle key down event from Cocoa
// Args: x0 = key code, x1 = modifiers
// Returns: none
.global input_handle_key_down
input_handle_key_down:
    SAVE_REGS_LIGHT
    
    // Create key down event
    mov     x2, #INPUT_EVENT_KEY_DOWN
    bl      create_key_event
    
    // Queue the event
    bl      enqueue_event
    
    RESTORE_REGS_LIGHT
    ret

// input_handle_key_up: Handle key up event from Cocoa
// Args: x0 = key code, x1 = modifiers
// Returns: none
.global input_handle_key_up
input_handle_key_up:
    SAVE_REGS_LIGHT
    
    // Create key up event
    mov     x2, #INPUT_EVENT_KEY_UP
    bl      create_key_event
    
    // Queue the event
    bl      enqueue_event
    
    RESTORE_REGS_LIGHT
    ret

// input_handle_scroll: Handle scroll wheel event from Cocoa
// Args: x0 = delta_x (fixed point), x1 = delta_y (fixed point), x2 = modifiers
// Returns: none
.global input_handle_scroll
input_handle_scroll:
    SAVE_REGS_LIGHT
    
    // Create scroll event
    mov     x3, #INPUT_EVENT_SCROLL
    bl      create_scroll_event
    
    // Queue the event
    bl      enqueue_event
    
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Event Buffer Management
//==============================================================================

// init_event_buffer: Initialize the circular event buffer
// Returns: x0 = 0 on success, error code on failure
init_event_buffer:
    SAVE_REGS_LIGHT
    
    // Clear buffer pointers
    adrp    x0, event_buffer_head@PAGE
    add     x0, x0, event_buffer_head@PAGEOFF
    str     xzr, [x0]
    
    adrp    x0, event_buffer_tail@PAGE
    add     x0, x0, event_buffer_tail@PAGEOFF
    str     xzr, [x0]
    
    adrp    x0, event_buffer_count@PAGE
    add     x0, x0, event_buffer_count@PAGEOFF
    str     xzr, [x0]
    
    // Clear the buffer memory
    adrp    x0, input_event_buffer@PAGE
    add     x0, x0, input_event_buffer@PAGEOFF
    mov     x1, #INPUT_EVENT_BUFFER_SIZE * INPUT_EVENT_SIZE
    bl      clear_memory_region
    
    mov     x0, #0                  // Success
    RESTORE_REGS_LIGHT
    ret

// enqueue_event: Add event to the buffer
// Args: x0 = event pointer
// Returns: x0 = 0 on success, -1 if buffer full
enqueue_event:
    SAVE_REGS_LIGHT
    
    mov     x19, x0                 // Save event pointer
    
    // Check if buffer is full
    adrp    x0, event_buffer_count@PAGE
    add     x0, x0, event_buffer_count@PAGEOFF
    ldr     x1, [x0]
    cmp     x1, #INPUT_EVENT_BUFFER_SIZE
    b.ge    enqueue_buffer_full
    
    // Get tail position
    adrp    x0, event_buffer_tail@PAGE
    add     x0, x0, event_buffer_tail@PAGEOFF
    ldr     x20, [x0]               // Tail index
    
    // Calculate buffer position
    adrp    x1, input_event_buffer@PAGE
    add     x1, x1, input_event_buffer@PAGEOFF
    mov     x2, #INPUT_EVENT_SIZE
    madd    x1, x20, x2, x1         // buffer + (tail * event_size)
    
    // Copy event data
    mov     x0, x1                  // Destination
    mov     x1, x19                 // Source (event)
    mov     x2, #INPUT_EVENT_SIZE   // Size
    bl      copy_memory
    
    // Update tail pointer
    add     x20, x20, #1
    cmp     x20, #INPUT_EVENT_BUFFER_SIZE
    csel    x20, xzr, x20, eq       // Wrap to 0 if at end
    
    adrp    x0, event_buffer_tail@PAGE
    add     x0, x0, event_buffer_tail@PAGEOFF
    str     x20, [x0]
    
    // Increment count
    adrp    x0, event_buffer_count@PAGE
    add     x0, x0, event_buffer_count@PAGEOFF
    ldr     x1, [x0]
    add     x1, x1, #1
    str     x1, [x0]
    
    mov     x0, #0                  // Success
    RESTORE_REGS_LIGHT
    ret

enqueue_buffer_full:
    mov     x0, #-1                 // Buffer full
    RESTORE_REGS_LIGHT
    ret

// dequeue_event: Remove event from the buffer
// Returns: x0 = event pointer, 0 if buffer empty
dequeue_event:
    SAVE_REGS_LIGHT
    
    // Check if buffer is empty
    adrp    x0, event_buffer_count@PAGE
    add     x0, x0, event_buffer_count@PAGEOFF
    ldr     x1, [x0]
    cbz     x1, dequeue_buffer_empty
    
    // Get head position
    adrp    x0, event_buffer_head@PAGE
    add     x0, x0, event_buffer_head@PAGEOFF
    ldr     x19, [x0]               // Head index
    
    // Calculate buffer position
    adrp    x0, input_event_buffer@PAGE
    add     x0, x0, input_event_buffer@PAGEOFF
    mov     x1, #INPUT_EVENT_SIZE
    madd    x20, x19, x1, x0        // buffer + (head * event_size)
    
    // Update head pointer
    add     x19, x19, #1
    cmp     x19, #INPUT_EVENT_BUFFER_SIZE
    csel    x19, xzr, x19, eq       // Wrap to 0 if at end
    
    adrp    x0, event_buffer_head@PAGE
    add     x0, x0, event_buffer_head@PAGEOFF
    str     x19, [x0]
    
    // Decrement count
    adrp    x0, event_buffer_count@PAGE
    add     x0, x0, event_buffer_count@PAGEOFF
    ldr     x1, [x0]
    sub     x1, x1, #1
    str     x1, [x0]
    
    mov     x0, x20                 // Return event pointer
    RESTORE_REGS_LIGHT
    ret

dequeue_buffer_empty:
    mov     x0, #0                  // Buffer empty
    RESTORE_REGS_LIGHT
    ret

// clear_event_buffer: Clear all events from buffer
// Returns: none
clear_event_buffer:
    SAVE_REGS_LIGHT
    
    // Reset all pointers
    adrp    x0, event_buffer_head@PAGE
    add     x0, x0, event_buffer_head@PAGEOFF
    str     xzr, [x0]
    
    adrp    x0, event_buffer_tail@PAGE
    add     x0, x0, event_buffer_tail@PAGEOFF
    str     xzr, [x0]
    
    adrp    x0, event_buffer_count@PAGE
    add     x0, x0, event_buffer_count@PAGEOFF
    str     xzr, [x0]
    
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Event Creation Functions
//==============================================================================

// create_mouse_event: Create a mouse event structure on stack
// Args: x0 = x coord, x1 = y coord, x2 = button, x3 = modifiers, x4 = event type
// Returns: x0 = event pointer (on stack)
create_mouse_event:
    SAVE_REGS_LIGHT
    
    // Allocate space on stack for event
    sub     sp, sp, #INPUT_EVENT_SIZE
    mov     x19, sp                 // Event pointer
    
    // Fill event structure
    str     w4, [x19, #INPUT_EVENT_TYPE]
    
    // Get current timestamp
    mrs     x5, cntvct_el0
    str     x5, [x19, #INPUT_EVENT_TIMESTAMP]
    
    // Convert coordinates to float and store
    scvtf   s0, w0
    str     s0, [x19, #INPUT_EVENT_X]
    scvtf   s1, w1
    str     s1, [x19, #INPUT_EVENT_Y]
    
    str     w2, [x19, #INPUT_EVENT_BUTTON]
    str     w3, [x19, #INPUT_EVENT_MODIFIERS]
    
    mov     x0, x19                 // Return event pointer
    RESTORE_REGS_LIGHT
    ret

// create_mouse_event_with_delta: Create mouse event with delta values
// Args: x0 = x, x1 = y, x2 = delta_x, x3 = delta_y, x4 = type, x5 = button
create_mouse_event_with_delta:
    SAVE_REGS_LIGHT
    
    // Allocate space on stack for event
    sub     sp, sp, #INPUT_EVENT_SIZE
    mov     x19, sp                 // Event pointer
    
    // Fill event structure
    str     w4, [x19, #INPUT_EVENT_TYPE]
    
    // Get current timestamp
    mrs     x6, cntvct_el0
    str     x6, [x19, #INPUT_EVENT_TIMESTAMP]
    
    // Store coordinates and deltas
    scvtf   s0, w0
    str     s0, [x19, #INPUT_EVENT_X]
    scvtf   s1, w1
    str     s1, [x19, #INPUT_EVENT_Y]
    scvtf   s2, w2
    str     s2, [x19, #INPUT_EVENT_DELTA_X]
    scvtf   s3, w3
    str     s3, [x19, #INPUT_EVENT_DELTA_Y]
    
    str     w5, [x19, #INPUT_EVENT_BUTTON]
    
    mov     x0, x19                 // Return event pointer
    RESTORE_REGS_LIGHT
    ret

// create_key_event: Create a keyboard event structure
// Args: x0 = key code, x1 = modifiers, x2 = event type
// Returns: x0 = event pointer (on stack)
create_key_event:
    SAVE_REGS_LIGHT
    
    // Allocate space on stack for event
    sub     sp, sp, #INPUT_EVENT_SIZE
    mov     x19, sp                 // Event pointer
    
    // Fill event structure
    str     w2, [x19, #INPUT_EVENT_TYPE]
    
    // Get current timestamp
    mrs     x3, cntvct_el0
    str     x3, [x19, #INPUT_EVENT_TIMESTAMP]
    
    str     w0, [x19, #INPUT_EVENT_KEY_CODE]
    str     w1, [x19, #INPUT_EVENT_MODIFIERS]
    
    mov     x0, x19                 // Return event pointer
    RESTORE_REGS_LIGHT
    ret

// create_scroll_event: Create a scroll event structure
// Args: x0 = delta_x, x1 = delta_y, x2 = modifiers, x3 = event type
// Returns: x0 = event pointer (on stack)
create_scroll_event:
    SAVE_REGS_LIGHT
    
    // Allocate space on stack for event
    sub     sp, sp, #INPUT_EVENT_SIZE
    mov     x19, sp                 // Event pointer
    
    // Fill event structure
    str     w3, [x19, #INPUT_EVENT_TYPE]
    
    // Get current timestamp
    mrs     x4, cntvct_el0
    str     x4, [x19, #INPUT_EVENT_TIMESTAMP]
    
    // Store scroll deltas as floats
    scvtf   s0, w0
    str     s0, [x19, #INPUT_EVENT_DELTA_X]
    scvtf   s1, w1
    str     s1, [x19, #INPUT_EVENT_DELTA_Y]
    
    str     w2, [x19, #INPUT_EVENT_MODIFIERS]
    
    mov     x0, x19                 // Return event pointer
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Event Processing Functions
//==============================================================================

// process_single_event: Process one input event
// Args: x0 = event pointer
// Returns: x0 = 0 on success, error code on failure
process_single_event:
    SAVE_REGS
    
    mov     x19, x0                 // Save event pointer
    
    // Load event type
    ldr     w0, [x19, #INPUT_EVENT_TYPE]
    
    // Dispatch based on event type
    cmp     w0, #INPUT_EVENT_MOUSE_DOWN
    b.eq    process_mouse_down
    cmp     w0, #INPUT_EVENT_MOUSE_UP
    b.eq    process_mouse_up
    cmp     w0, #INPUT_EVENT_MOUSE_MOVE
    b.eq    process_mouse_move
    cmp     w0, #INPUT_EVENT_KEY_DOWN
    b.eq    process_key_down
    cmp     w0, #INPUT_EVENT_KEY_UP
    b.eq    process_key_up
    cmp     w0, #INPUT_EVENT_SCROLL
    b.eq    process_scroll
    cmp     w0, #INPUT_EVENT_GESTURE
    b.eq    process_gesture
    
    // Unknown event type
    mov     x0, #-1
    b       process_event_done

process_mouse_down:
    mov     x0, x19
    bl      handle_mouse_down_event
    b       process_event_done

process_mouse_up:
    mov     x0, x19
    bl      handle_mouse_up_event
    b       process_event_done

process_mouse_move:
    mov     x0, x19
    bl      handle_mouse_move_event
    b       process_event_done

process_key_down:
    mov     x0, x19
    bl      handle_key_down_event
    b       process_event_done

process_key_up:
    mov     x0, x19
    bl      handle_key_up_event
    b       process_event_done

process_scroll:
    mov     x0, x19
    bl      handle_scroll_event
    b       process_event_done

process_gesture:
    mov     x0, x19
    bl      handle_gesture_event
    b       process_event_done

process_event_done:
    RESTORE_REGS
    ret

//==============================================================================
// Mouse Event Handlers
//==============================================================================

// handle_mouse_down_event: Process mouse button press
// Args: x0 = event pointer
// Returns: x0 = 0 on success
handle_mouse_down_event:
    SAVE_REGS
    
    mov     x19, x0                 // Save event pointer
    
    // Load event data
    ldr     s0, [x19, #INPUT_EVENT_X]       // Mouse X
    ldr     s1, [x19, #INPUT_EVENT_Y]       // Mouse Y
    ldr     w20, [x19, #INPUT_EVENT_BUTTON] // Button flags
    ldr     w21, [x19, #INPUT_EVENT_MODIFIERS] // Modifiers
    
    // Check for left button
    tst     w20, #MOUSE_BUTTON_LEFT
    b.eq    check_right_button
    
    // Handle left button press
    bl      handle_left_mouse_down
    b       mouse_down_done

check_right_button:
    // Check for right button
    tst     w20, #MOUSE_BUTTON_RIGHT
    b.eq    mouse_down_done
    
    // Handle right button press
    bl      handle_right_mouse_down

mouse_down_done:
    mov     x0, #0                  // Success
    RESTORE_REGS
    ret

// handle_left_mouse_down: Process left mouse button press
// Args: s0 = mouse_x, s1 = mouse_y, w21 = modifiers
// Returns: none
handle_left_mouse_down:
    SAVE_REGS
    
    // Convert screen coordinates to world coordinates
    bl      screen_to_world_coords
    // Returns: s2 = world_x, s3 = world_y
    
    // Convert world coordinates to grid coordinates
    fmov    s0, s2                  // world_x
    fmov    s1, s3                  // world_y
    bl      world_to_grid_coords
    // Returns: w0 = grid_x, w1 = grid_y
    
    mov     w19, w0                 // Save grid_x
    mov     w20, w1                 // Save grid_y
    
    // Check if coordinates are valid
    bl      validate_grid_coordinates
    cmp     x0, #0
    b.ne    left_click_done
    
    // Get current building type
    adrp    x0, current_building_type@PAGE
    add     x0, x0, current_building_type@PAGEOFF
    ldr     x21, [x0]               // Building type
    
    // Dispatch building placement command
    mov     w0, w19                 // grid_x
    mov     w1, w20                 // grid_y
    mov     x2, x21                 // building_type
    bl      dispatch_build_command

left_click_done:
    RESTORE_REGS
    ret

// handle_right_mouse_down: Process right mouse button press
// Args: s0 = mouse_x, s1 = mouse_y, w21 = modifiers
// Returns: none
handle_right_mouse_down:
    SAVE_REGS
    
    // Convert screen coordinates to world coordinates
    bl      screen_to_world_coords
    // Returns: s2 = world_x, s3 = world_y
    
    // Convert world coordinates to grid coordinates
    fmov    s0, s2                  // world_x
    fmov    s1, s3                  // world_y
    bl      world_to_grid_coords
    // Returns: w0 = grid_x, w1 = grid_y
    
    mov     w19, w0                 // Save grid_x
    mov     w20, w1                 // Save grid_y
    
    // Check if coordinates are valid
    bl      validate_grid_coordinates
    cmp     x0, #0
    b.ne    right_click_done
    
    // Check for modifier keys
    tst     w21, #KEY_MOD_OPTION
    b.ne    handle_pathfinding_click
    
    // Default: delete building
    mov     w0, w19                 // grid_x
    mov     w1, w20                 // grid_y
    mov     x2, #TILE_EMPTY         // Delete (empty tile)
    bl      dispatch_build_command
    b       right_click_done

handle_pathfinding_click:
    // Handle pathfinding start/end point selection
    mov     w0, w19                 // grid_x
    mov     w1, w20                 // grid_y
    bl      dispatch_pathfinding_command

right_click_done:
    RESTORE_REGS
    ret

// handle_mouse_up_event: Process mouse button release
// Args: x0 = event pointer
// Returns: x0 = 0 on success
handle_mouse_up_event:
    SAVE_REGS_LIGHT
    
    // Clear any drag operations
    bl      clear_drag_state
    
    mov     x0, #0                  // Success
    RESTORE_REGS_LIGHT
    ret

// handle_mouse_move_event: Process mouse movement
// Args: x0 = event pointer
// Returns: x0 = 0 on success
handle_mouse_move_event:
    SAVE_REGS_LIGHT
    
    // Check if any mouse buttons are down for dragging
    adrp    x1, left_button_down@PAGE
    add     x1, x1, left_button_down@PAGEOFF
    ldrb    w1, [x1]
    cbnz    w1, handle_mouse_drag
    
    // Just update cursor position for now
    mov     x0, #0                  // Success
    RESTORE_REGS_LIGHT
    ret

handle_mouse_drag:
    // Handle camera panning during drag
    ldr     s0, [x0, #INPUT_EVENT_DELTA_X]
    ldr     s1, [x0, #INPUT_EVENT_DELTA_Y]
    bl      handle_camera_pan
    
    mov     x0, #0                  // Success
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Keyboard Event Handlers
//==============================================================================

// handle_key_down_event: Process key press
// Args: x0 = event pointer
// Returns: x0 = 0 on success
handle_key_down_event:
    SAVE_REGS
    
    mov     x19, x0                 // Save event pointer
    
    // Load key code and modifiers
    ldr     w20, [x19, #INPUT_EVENT_KEY_CODE]
    ldr     w21, [x19, #INPUT_EVENT_MODIFIERS]
    
    // Look up action for this key
    mov     w0, w20                 // key_code
    bl      lookup_key_action
    mov     w22, w0                 // Save action
    
    // Dispatch based on action
    cmp     w22, #ACTION_CAMERA_LEFT
    b.eq    handle_camera_left
    cmp     w22, #ACTION_CAMERA_RIGHT
    b.eq    handle_camera_right
    cmp     w22, #ACTION_CAMERA_UP
    b.eq    handle_camera_up
    cmp     w22, #ACTION_CAMERA_DOWN
    b.eq    handle_camera_down
    cmp     w22, #ACTION_BUILD_HOUSE
    b.eq    handle_select_house
    cmp     w22, #ACTION_BUILD_COMMERCIAL
    b.eq    handle_select_commercial
    cmp     w22, #ACTION_BUILD_INDUSTRIAL
    b.eq    handle_select_industrial
    cmp     w22, #ACTION_BUILD_PARK
    b.eq    handle_select_park
    cmp     w22, #ACTION_BUILD_ROAD
    b.eq    handle_select_road
    cmp     w22, #ACTION_TOGGLE_OVERLAY
    b.eq    handle_toggle_overlay
    
    // Unknown action, ignore
    b       key_down_done

handle_camera_left:
    mov     x0, #-1                 // Direction: left
    mov     x1, #0                  // Axis: X
    bl      dispatch_camera_move
    b       key_down_done

handle_camera_right:
    mov     x0, #1                  // Direction: right
    mov     x1, #0                  // Axis: X
    bl      dispatch_camera_move
    b       key_down_done

handle_camera_up:
    mov     x0, #1                  // Direction: up
    mov     x1, #1                  // Axis: Y
    bl      dispatch_camera_move
    b       key_down_done

handle_camera_down:
    mov     x0, #-1                 // Direction: down
    mov     x1, #1                  // Axis: Y
    bl      dispatch_camera_move
    b       key_down_done

handle_select_house:
    mov     x0, #TILE_HOUSE
    bl      set_current_building_type
    b       key_down_done

handle_select_commercial:
    mov     x0, #TILE_COMMERCIAL
    bl      set_current_building_type
    b       key_down_done

handle_select_industrial:
    mov     x0, #TILE_INDUSTRIAL
    bl      set_current_building_type
    b       key_down_done

handle_select_park:
    mov     x0, #TILE_PARK
    bl      set_current_building_type
    b       key_down_done

handle_select_road:
    mov     x0, #TILE_ROAD
    bl      set_current_building_type
    b       key_down_done

handle_toggle_overlay:
    bl      dispatch_overlay_toggle
    b       key_down_done

key_down_done:
    mov     x0, #0                  // Success
    RESTORE_REGS
    ret

// handle_key_up_event: Process key release
// Args: x0 = event pointer
// Returns: x0 = 0 on success
handle_key_up_event:
    SAVE_REGS_LIGHT
    
    // For now, just ignore key up events
    // Could be used for continuous actions (camera movement)
    
    mov     x0, #0                  // Success
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Scroll and Gesture Handlers
//==============================================================================

// handle_scroll_event: Process scroll wheel input
// Args: x0 = event pointer
// Returns: x0 = 0 on success
handle_scroll_event:
    SAVE_REGS_LIGHT
    
    // Load scroll deltas
    ldr     s0, [x0, #INPUT_EVENT_DELTA_X]
    ldr     s1, [x0, #INPUT_EVENT_DELTA_Y]
    ldr     w1, [x0, #INPUT_EVENT_MODIFIERS]
    
    // Check if horizontal scroll
    fcmp    s0, #0.0
    b.eq    check_vertical_scroll
    
    // Handle horizontal camera movement
    bl      handle_horizontal_scroll
    b       scroll_done

check_vertical_scroll:
    fcmp    s1, #0.0
    b.eq    scroll_done
    
    // Handle zoom
    bl      handle_zoom_scroll

scroll_done:
    mov     x0, #0                  // Success
    RESTORE_REGS_LIGHT
    ret

// handle_gesture_event: Process touch gesture input
// Args: x0 = event pointer
// Returns: x0 = 0 on success
handle_gesture_event:
    SAVE_REGS_LIGHT
    
    // TODO: Implement trackpad gesture recognition
    // - Two-finger pan for camera movement
    // - Pinch for zoom
    // - Rotate for camera rotation (if supported)
    
    mov     x0, #0                  // Success
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Coordinate Conversion Functions
//==============================================================================

// init_coordinate_system: Initialize coordinate conversion parameters
// Returns: x0 = 0 on success
init_coordinate_system:
    SAVE_REGS_LIGHT
    
    // Initialize screen dimensions (will be updated by window resize)
    adrp    x0, screen_width@PAGE
    add     x0, x0, screen_width@PAGEOFF
    mov     w1, #800                // Default width
    str     w1, [x0]
    
    adrp    x0, screen_height@PAGE
    add     x0, x0, screen_height@PAGEOFF
    mov     w1, #600                // Default height
    str     w1, [x0]
    
    // Initialize camera parameters
    adrp    x0, camera_x@PAGE
    add     x0, x0, camera_x@PAGEOFF
    fmov    s0, wzr                 // 0.0
    str     s0, [x0]
    
    adrp    x0, camera_y@PAGE
    add     x0, x0, camera_y@PAGEOFF
    str     s0, [x0]
    
    adrp    x0, camera_zoom@PAGE
    add     x0, x0, camera_zoom@PAGEOFF
    fmov    s0, #1.0                // Default zoom
    str     s0, [x0]
    
    mov     x0, #0                  // Success
    RESTORE_REGS_LIGHT
    ret

// screen_to_world_coords: Convert screen coordinates to world coordinates
// Args: s0 = screen_x, s1 = screen_y
// Returns: s2 = world_x, s3 = world_y
screen_to_world_coords:
    SAVE_REGS_LIGHT
    
    // Load screen dimensions
    adrp    x0, screen_width@PAGE
    add     x0, x0, screen_width@PAGEOFF
    ldr     w0, [x0]
    ucvtf   s4, w0                  // screen_width as float
    
    adrp    x1, screen_height@PAGE
    add     x1, x1, screen_height@PAGEOFF
    ldr     w1, [x1]
    ucvtf   s5, w1                  // screen_height as float
    
    // Convert to normalized coordinates (-1 to 1)
    fmov    s6, #2.0
    fdiv    s2, s0, s4              // x / width
    fmul    s2, s2, s6              // * 2
    fmov    s7, #1.0
    fsub    s2, s2, s7              // - 1 (now -1 to 1)
    
    fdiv    s3, s1, s5              // y / height
    fmul    s3, s3, s6              // * 2
    fsub    s3, s3, s7              // - 1 (now -1 to 1)
    
    // Apply camera transform
    adrp    x0, camera_zoom@PAGE
    add     x0, x0, camera_zoom@PAGEOFF
    ldr     s6, [x0]                // zoom factor
    
    adrp    x0, camera_x@PAGE
    add     x0, x0, camera_x@PAGEOFF
    ldr     s7, [x0]                // camera_x
    
    adrp    x0, camera_y@PAGE
    add     x0, x0, camera_y@PAGEOFF
    ldr     s8, [x0]                // camera_y
    
    // Apply zoom and camera offset
    fdiv    s2, s2, s6              // screenX / zoom
    fadd    s2, s2, s7              // + camera_x
    
    fdiv    s3, s3, s6              // screenY / zoom
    fadd    s3, s3, s8              // + camera_y
    
    RESTORE_REGS_LIGHT
    ret

// world_to_grid_coords: Convert world coordinates to grid coordinates
// Args: s0 = world_x, s1 = world_y
// Returns: w0 = grid_x, w1 = grid_y
world_to_grid_coords:
    SAVE_REGS_LIGHT
    
    // Inverse isometric transformation
    // Original: isoX = (x - y) * 0.1f; isoY = (x + y) * 0.05f
    // Inverse: x = (isoX/0.1 + isoY/0.05) / 2; y = (isoY/0.05 - isoX/0.1) / 2
    
    fmov    s2, #0.1                // 0.1 constant
    fmov    s3, #0.05               // 0.05 constant
    fmov    s4, #0.5                // 0.5 constant
    
    fdiv    s5, s0, s2              // world_x / 0.1
    fdiv    s6, s1, s3              // world_y / 0.05
    
    fadd    s7, s5, s6              // (world_x/0.1 + world_y/0.05)
    fmul    s7, s7, s4              // / 2
    
    fsub    s8, s6, s5              // (world_y/0.05 - world_x/0.1)
    fmul    s8, s8, s4              // / 2
    
    // Round to nearest integer
    fcvtns  w0, s7                  // grid_x
    fcvtns  w1, s8                  // grid_y
    
    RESTORE_REGS_LIGHT
    ret

// validate_grid_coordinates: Check if grid coordinates are valid
// Args: w0 = grid_x, w1 = grid_y
// Returns: x0 = 0 if valid, -1 if invalid
validate_grid_coordinates:
    SAVE_REGS_LIGHT
    
    // Check bounds (assuming 30x30 grid from demo)
    cmp     w0, #0
    b.lt    grid_invalid
    cmp     w0, #30
    b.ge    grid_invalid
    cmp     w1, #0
    b.lt    grid_invalid
    cmp     w1, #30
    b.ge    grid_invalid
    
    mov     x0, #0                  // Valid
    RESTORE_REGS_LIGHT
    ret

grid_invalid:
    mov     x0, #-1                 // Invalid
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Key Mapping and Actions
//==============================================================================

// init_key_mapping: Initialize key action mapping table
// Returns: x0 = 0 on success
init_key_mapping:
    SAVE_REGS_LIGHT
    
    // Clear mapping table
    adrp    x0, key_action_map@PAGE
    add     x0, x0, key_action_map@PAGEOFF
    mov     x1, #256 * 4            // Size in bytes
    bl      clear_memory_region
    
    adrp    x19, key_action_map@PAGE
    add     x19, x19, key_action_map@PAGEOFF
    
    // Map WASD keys for camera movement
    mov     w0, #0                  // A key
    mov     w1, #ACTION_CAMERA_LEFT
    str     w1, [x19, x0, lsl #2]
    
    mov     w0, #2                  // D key
    mov     w1, #ACTION_CAMERA_RIGHT
    str     w1, [x19, x0, lsl #2]
    
    mov     w0, #13                 // W key
    mov     w1, #ACTION_CAMERA_UP
    str     w1, [x19, x0, lsl #2]
    
    mov     w0, #1                  // S key
    mov     w1, #ACTION_CAMERA_DOWN
    str     w1, [x19, x0, lsl #2]
    
    // Map number keys for building selection
    mov     w0, #18                 // 1 key
    mov     w1, #ACTION_BUILD_HOUSE
    str     w1, [x19, x0, lsl #2]
    
    mov     w0, #19                 // 2 key
    mov     w1, #ACTION_BUILD_COMMERCIAL
    str     w1, [x19, x0, lsl #2]
    
    mov     w0, #20                 // 3 key
    mov     w1, #ACTION_BUILD_INDUSTRIAL
    str     w1, [x19, x0, lsl #2]
    
    mov     w0, #21                 // 4 key
    mov     w1, #ACTION_BUILD_PARK
    str     w1, [x19, x0, lsl #2]
    
    mov     w0, #23                 // 5 key
    mov     w1, #ACTION_BUILD_ROAD
    str     w1, [x19, x0, lsl #2]
    
    // Map function keys
    mov     w0, #122                // F1 key
    mov     w1, #ACTION_TOGGLE_OVERLAY
    str     w1, [x19, x0, lsl #2]
    
    mov     x0, #0                  // Success
    RESTORE_REGS_LIGHT
    ret

// lookup_key_action: Look up action for key code
// Args: w0 = key code
// Returns: w0 = action (ACTION_NONE if not found)
lookup_key_action:
    SAVE_REGS_LIGHT
    
    // Bounds check
    cmp     w0, #256
    b.ge    key_not_found
    
    // Load from mapping table
    adrp    x1, key_action_map@PAGE
    add     x1, x1, key_action_map@PAGEOFF
    ldr     w0, [x1, x0, lsl #2]
    
    RESTORE_REGS_LIGHT
    ret

key_not_found:
    mov     w0, #ACTION_NONE
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Gesture Recognition System
//==============================================================================

// init_gesture_system: Initialize trackpad gesture recognition
// Returns: x0 = 0 on success
init_gesture_system:
    SAVE_REGS_LIGHT
    
    // Clear gesture state
    adrp    x0, gesture_state@PAGE
    add     x0, x0, gesture_state@PAGEOFF
    mov     x1, #64                 // Size of gesture_state structure
    bl      clear_memory_region
    
    mov     x0, #0                  // Success
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Command Dispatch System
//==============================================================================

// dispatch_build_command: Send building placement command to simulation
// Args: w0 = grid_x, w1 = grid_y, x2 = building_type
// Returns: none
dispatch_build_command:
    SAVE_REGS_LIGHT
    
    // TODO: Create command structure and send to simulation system
    // For now, just store the command parameters
    
    // Check if simulation handler is registered
    adrp    x3, simulation_handler@PAGE
    add     x3, x3, simulation_handler@PAGEOFF
    ldr     x3, [x3]
    cbz     x3, dispatch_build_done
    
    // Call simulation handler
    // Arguments are already in correct registers
    blr     x3

dispatch_build_done:
    RESTORE_REGS_LIGHT
    ret

// dispatch_camera_move: Send camera movement command
// Args: x0 = direction (-1 or 1), x1 = axis (0=X, 1=Y)
// Returns: none
dispatch_camera_move:
    SAVE_REGS_LIGHT
    
    // Load camera move speed
    adrp    x2, camera_move_speed@PAGE
    add     x2, x2, camera_move_speed@PAGEOFF
    ldr     s0, [x2]
    
    // Convert direction to float
    scvtf   s1, w0                  // direction as float
    fmul    s2, s0, s1              // move_speed * direction
    
    // Apply to appropriate axis
    cmp     x1, #0
    b.eq    move_camera_x
    
    // Move camera Y
    adrp    x2, camera_y@PAGE
    add     x2, x2, camera_y@PAGEOFF
    ldr     s3, [x2]
    fadd    s3, s3, s2
    str     s3, [x2]
    b       camera_move_done

move_camera_x:
    // Move camera X
    adrp    x2, camera_x@PAGE
    add     x2, x2, camera_x@PAGEOFF
    ldr     s3, [x2]
    fadd    s3, s3, s2
    str     s3, [x2]

camera_move_done:
    RESTORE_REGS_LIGHT
    ret

// dispatch_pathfinding_command: Send pathfinding command
// Args: w0 = grid_x, w1 = grid_y
// Returns: none
dispatch_pathfinding_command:
    SAVE_REGS_LIGHT
    
    // TODO: Implement pathfinding command dispatch
    // This would integrate with AI/pathfinding systems
    
    RESTORE_REGS_LIGHT
    ret

// dispatch_overlay_toggle: Toggle overlay display
// Returns: none
dispatch_overlay_toggle:
    SAVE_REGS_LIGHT
    
    // TODO: Send overlay toggle command to graphics system
    adrp    x0, graphics_handler@PAGE
    add     x0, x0, graphics_handler@PAGEOFF
    ldr     x0, [x0]
    cbz     x0, overlay_toggle_done
    
    // Call graphics handler for overlay toggle
    // No specific arguments needed for toggle
    blr     x0

overlay_toggle_done:
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// State Management Functions
//==============================================================================

// set_current_building_type: Set the current building type for placement
// Args: x0 = building type
// Returns: none
set_current_building_type:
    SAVE_REGS_LIGHT
    
    adrp    x1, current_building_type@PAGE
    add     x1, x1, current_building_type@PAGEOFF
    str     x0, [x1]
    
    // TODO: Send notification to UI system to update building type display
    
    RESTORE_REGS_LIGHT
    ret

// update_mouse_button_state: Update mouse button state tracking
// Args: x0 = button flags
// Returns: none
update_mouse_button_state:
    SAVE_REGS_LIGHT
    
    // Update button states
    adrp    x1, left_button_down@PAGE
    add     x1, x1, left_button_down@PAGEOFF
    
    tst     w0, #MOUSE_BUTTON_LEFT
    cset    w2, ne
    strb    w2, [x1]
    
    adrp    x1, right_button_down@PAGE
    add     x1, x1, right_button_down@PAGEOFF
    tst     w0, #MOUSE_BUTTON_RIGHT
    cset    w2, ne
    strb    w2, [x1]
    
    adrp    x1, middle_button_down@PAGE
    add     x1, x1, middle_button_down@PAGEOFF
    tst     w0, #MOUSE_BUTTON_MIDDLE
    cset    w2, ne
    strb    w2, [x1]
    
    RESTORE_REGS_LIGHT
    ret

// clear_mouse_button_state: Clear mouse button state on release
// Args: x0 = released button flags
// Returns: none
clear_mouse_button_state:
    SAVE_REGS_LIGHT
    
    // Clear released buttons
    adrp    x1, left_button_down@PAGE
    add     x1, x1, left_button_down@PAGEOFF
    
    tst     w0, #MOUSE_BUTTON_LEFT
    b.eq    check_clear_right
    strb    wzr, [x1]

check_clear_right:
    adrp    x1, right_button_down@PAGE
    add     x1, x1, right_button_down@PAGEOFF
    tst     w0, #MOUSE_BUTTON_RIGHT
    b.eq    check_clear_middle
    strb    wzr, [x1]

check_clear_middle:
    adrp    x1, middle_button_down@PAGE
    add     x1, x1, middle_button_down@PAGEOFF
    tst     w0, #MOUSE_BUTTON_MIDDLE
    b.eq    clear_buttons_done
    strb    wzr, [x1]

clear_buttons_done:
    RESTORE_REGS_LIGHT
    ret

// clear_drag_state: Clear any ongoing drag operations
// Returns: none
clear_drag_state:
    SAVE_REGS_LIGHT
    
    // TODO: Clear any drag-specific state
    // For now, this is a placeholder
    
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Camera Control Functions
//==============================================================================

// handle_camera_pan: Handle camera panning during mouse drag
// Args: s0 = delta_x, s1 = delta_y
// Returns: none
handle_camera_pan:
    SAVE_REGS_LIGHT
    
    // Load camera sensitivity
    adrp    x0, camera_sensitivity@PAGE
    add     x0, x0, camera_sensitivity@PAGEOFF
    ldr     s2, [x0]
    
    // Apply sensitivity to deltas
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    
    // Update camera position
    adrp    x0, camera_x@PAGE
    add     x0, x0, camera_x@PAGEOFF
    ldr     s3, [x0]
    fsub    s3, s3, s0              // Subtract for natural panning
    str     s3, [x0]
    
    adrp    x0, camera_y@PAGE
    add     x0, x0, camera_y@PAGEOFF
    ldr     s3, [x0]
    fadd    s3, s3, s1              // Add for natural panning
    str     s3, [x0]
    
    RESTORE_REGS_LIGHT
    ret

// handle_horizontal_scroll: Handle horizontal scroll for camera movement
// Args: s0 = delta_x
// Returns: none
handle_horizontal_scroll:
    SAVE_REGS_LIGHT
    
    // Load camera move speed
    adrp    x0, camera_move_speed@PAGE
    add     x0, x0, camera_move_speed@PAGEOFF
    ldr     s1, [x0]
    
    // Apply scroll delta
    fmul    s2, s0, s1
    
    // Update camera X position
    adrp    x0, camera_x@PAGE
    add     x0, x0, camera_x@PAGEOFF
    ldr     s3, [x0]
    fadd    s3, s3, s2
    str     s3, [x0]
    
    RESTORE_REGS_LIGHT
    ret

// handle_zoom_scroll: Handle zoom via scroll wheel
// Args: s1 = delta_y
// Returns: none
handle_zoom_scroll:
    SAVE_REGS_LIGHT
    
    // Load current zoom and zoom speed
    adrp    x0, camera_zoom@PAGE
    add     x0, x0, camera_zoom@PAGEOFF
    ldr     s2, [x0]                // current zoom
    
    adrp    x1, camera_zoom_speed@PAGE
    add     x1, x1, camera_zoom_speed@PAGEOFF
    ldr     s3, [x1]                // zoom speed
    
    // Calculate zoom factor
    fmul    s4, s1, s3              // delta_y * zoom_speed
    fmov    s5, #1.0
    fadd    s4, s5, s4              // 1.0 + (delta * speed)
    
    // Apply zoom
    fmul    s2, s2, s4
    
    // Clamp zoom to reasonable bounds (0.3 to 3.0)
    fmov    s5, #0.3
    fmax    s2, s2, s5
    fmov    s5, #3.0
    fmin    s2, s2, s5
    
    // Store updated zoom
    str     s2, [x0]
    
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Handler Registration Functions
//==============================================================================

// input_register_simulation_handler: Register simulation command handler
// Args: x0 = handler function pointer
// Returns: none
.global input_register_simulation_handler
input_register_simulation_handler:
    adrp    x1, simulation_handler@PAGE
    add     x1, x1, simulation_handler@PAGEOFF
    str     x0, [x1]
    ret

// input_register_graphics_handler: Register graphics command handler
// Args: x0 = handler function pointer
// Returns: none
.global input_register_graphics_handler
input_register_graphics_handler:
    adrp    x1, graphics_handler@PAGE
    add     x1, x1, graphics_handler@PAGEOFF
    str     x0, [x1]
    ret

// input_register_audio_handler: Register audio command handler
// Args: x0 = handler function pointer
// Returns: none
.global input_register_audio_handler
input_register_audio_handler:
    adrp    x1, audio_handler@PAGE
    add     x1, x1, audio_handler@PAGEOFF
    str     x0, [x1]
    ret

// input_register_ui_handler: Register UI command handler
// Args: x0 = handler function pointer
// Returns: none
.global input_register_ui_handler
input_register_ui_handler:
    adrp    x1, ui_handler@PAGE
    add     x1, x1, ui_handler@PAGEOFF
    str     x0, [x1]
    ret

//==============================================================================
// Utility Functions
//==============================================================================

// clear_memory_region: Clear a memory region to zero
// Args: x0 = address, x1 = size in bytes
// Returns: none
clear_memory_region:
    SAVE_REGS_LIGHT
    
    mov     x2, x0                  // Save start address
    add     x3, x0, x1              // End address
    
clear_loop:
    cmp     x2, x3
    b.ge    clear_done
    strb    wzr, [x2], #1
    b       clear_loop

clear_done:
    RESTORE_REGS_LIGHT
    ret

// copy_memory: Copy memory from source to destination
// Args: x0 = destination, x1 = source, x2 = size
// Returns: none
copy_memory:
    SAVE_REGS_LIGHT
    
    mov     x3, #0                  // Counter

copy_loop:
    cmp     x3, x2
    b.ge    copy_done
    ldrb    w4, [x1, x3]
    strb    w4, [x0, x3]
    add     x3, x3, #1
    b       copy_loop

copy_done:
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Additional State Variables
//==============================================================================

.section .data
.align 3

// Screen dimensions (updated by window resize events)
screen_width:               .word   800
screen_height:              .word   600

// Camera state
camera_x:                   .float  0.0
camera_y:                   .float  0.0
camera_zoom:                .float  1.0

.end