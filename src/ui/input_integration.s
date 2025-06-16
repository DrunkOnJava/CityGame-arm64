//
// SimCity ARM64 Assembly - Input System Integration
// Agent D5: Infrastructure Team - Input system integration with platform bridge
//
// Integration layer between Cocoa event handling and pure assembly input system
//

.cpu generic+simd
.arch armv8-a+simd

// Include platform constants and macros
.include "../include/macros/platform_asm.inc"
.include "../include/constants/platform_constants.h"

.section .data
.align 3

//==============================================================================
// Integration State and Configuration
//==============================================================================

// Integration state
.integration_state:
    initialized:            .byte   0
    platform_connected:     .byte   0
    input_enabled:          .byte   1
    debug_enabled:          .byte   0
    .align 3
    
    // Performance metrics
    events_processed:       .quad   0
    total_processing_time:  .quad   0
    peak_processing_time:   .quad   0
    
    // Frame timing
    last_frame_time:        .quad   0
    frame_delta:            .quad   0
    target_frame_time:      .quad   16666667    // 60 FPS in nanoseconds

// Cocoa bridge function pointers (set by platform system)
.cocoa_bridge:
    nsview_bounds_func:     .quad   0
    nsview_convert_func:    .quad   0
    nswindow_scale_func:    .quad   0
    nsevent_location_func:  .quad   0

// Screen/window state (updated by platform)
.window_state:
    window_width:           .float  800.0
    window_height:          .float  600.0
    window_scale:           .float  1.0
    window_bounds_x:        .float  0.0
    window_bounds_y:        .float  0.0
    window_bounds_width:    .float  800.0
    window_bounds_height:   .float  600.0

// Event filtering configuration
.event_filter_config:
    min_mouse_delta:        .float  1.0
    key_repeat_delay:       .quad   500000000   // 500ms
    gesture_sensitivity:    .float  1.0
    scroll_acceleration:    .float  1.2

.section .text
.align 4

//==============================================================================
// Public Integration Interface
//==============================================================================

// input_integration_init: Initialize input system integration
// Returns: x0 = 0 on success, error code on failure
.global input_integration_init
input_integration_init:
    SAVE_REGS
    
    // Check if already initialized
    adrp    x0, initialized@PAGE
    add     x0, x0, initialized@PAGEOFF
    ldrb    w1, [x0]
    cbnz    w1, integration_already_init
    
    // Initialize core input system
    bl      input_system_init
    cmp     x0, #0
    b.ne    integration_init_error
    
    // Initialize gesture recognition
    bl      gesture_system_init
    cmp     x0, #0
    b.ne    integration_init_error
    
    // Set up default window state
    bl      init_default_window_state
    
    // Initialize event filtering
    bl      init_event_filtering
    
    // Set up performance monitoring
    bl      init_performance_monitoring
    
    // Mark as initialized
    adrp    x0, initialized@PAGE
    add     x0, x0, initialized@PAGEOFF
    mov     w1, #1
    strb    w1, [x0]
    
    mov     x0, #0                  // Success
    RESTORE_REGS
    ret

integration_already_init:
    mov     x0, #0                  // Success (already initialized)
    RESTORE_REGS
    ret

integration_init_error:
    mov     x0, #-1                 // Error
    RESTORE_REGS
    ret

// input_integration_update: Update input system each frame
// Returns: x0 = number of events processed
.global input_integration_update
input_integration_update:
    SAVE_REGS
    
    // Start performance timer
    mrs     x19, cntvct_el0
    
    // Update frame timing
    bl      update_frame_timing
    
    // Process queued input events
    bl      input_process_events
    mov     x20, x0                 // Save event count
    
    // Update gesture recognition
    bl      update_gesture_processing
    
    // Apply event filtering
    bl      apply_event_filtering
    
    // Update performance metrics
    mrs     x21, cntvct_el0
    sub     x21, x21, x19           // Processing time
    mov     x0, x21
    bl      update_performance_metrics
    
    mov     x0, x20                 // Return event count
    RESTORE_REGS
    ret

// input_integration_shutdown: Shutdown input integration
// Returns: none
.global input_integration_shutdown
input_integration_shutdown:
    SAVE_REGS_LIGHT
    
    // Disable input processing
    adrp    x0, input_enabled@PAGE
    add     x0, x0, input_enabled@PAGEOFF
    strb    wzr, [x0]
    
    // Shutdown core systems
    bl      input_system_shutdown
    
    // Clear integration state
    adrp    x0, integration_state@PAGE
    add     x0, x0, integration_state@PAGEOFF
    mov     x1, #64                 // Size of integration state
    bl      clear_memory_region
    
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Cocoa Event Bridge Functions
//==============================================================================

// These functions are called directly from Objective-C MTKView delegate methods

// cocoa_mouse_down: Handle mouse down from Cocoa
// Args: x0 = NSEvent pointer
// Returns: none
.global cocoa_mouse_down
cocoa_mouse_down:
    SAVE_REGS
    
    mov     x19, x0                 // Save NSEvent pointer
    
    // Check if input is enabled
    adrp    x0, input_enabled@PAGE
    add     x0, x0, input_enabled@PAGEOFF
    ldrb    w0, [x0]
    cbz     w0, cocoa_mouse_done
    
    // Extract event data from NSEvent
    mov     x0, x19
    bl      extract_mouse_event_data
    // Returns: w0 = x, w1 = y, w2 = button_flags, w3 = modifiers
    
    // Convert to our coordinate system
    bl      convert_cocoa_coordinates
    // Returns: w0 = adjusted_x, w1 = adjusted_y
    
    // Send to input handler
    mov     x2, w2                  // button_flags (from extract_mouse_event_data)
    mov     x3, w3                  // modifiers (from extract_mouse_event_data)
    bl      input_handle_mouse_down

cocoa_mouse_done:
    RESTORE_REGS
    ret

// cocoa_mouse_up: Handle mouse up from Cocoa
// Args: x0 = NSEvent pointer
// Returns: none
.global cocoa_mouse_up
cocoa_mouse_up:
    SAVE_REGS
    
    mov     x19, x0                 // Save NSEvent pointer
    
    // Check if input is enabled
    adrp    x0, input_enabled@PAGE
    add     x0, x0, input_enabled@PAGEOFF
    ldrb    w0, [x0]
    cbz     w0, cocoa_mouse_up_done
    
    // Extract event data
    mov     x0, x19
    bl      extract_mouse_event_data
    
    // Convert coordinates
    bl      convert_cocoa_coordinates
    
    // Send to input handler
    mov     x2, w2                  // button_flags
    mov     x3, w3                  // modifiers
    bl      input_handle_mouse_up

cocoa_mouse_up_done:
    RESTORE_REGS
    ret

// cocoa_mouse_moved: Handle mouse movement from Cocoa
// Args: x0 = NSEvent pointer
// Returns: none
.global cocoa_mouse_moved
cocoa_mouse_moved:
    SAVE_REGS
    
    mov     x19, x0                 // Save NSEvent pointer
    
    // Check if input is enabled
    adrp    x0, input_enabled@PAGE
    add     x0, x0, input_enabled@PAGEOFF
    ldrb    w0, [x0]
    cbz     w0, cocoa_mouse_moved_done
    
    // Extract event data and delta
    mov     x0, x19
    bl      extract_mouse_move_data
    // Returns: w0 = x, w1 = y, w2 = delta_x, w3 = delta_y
    
    // Apply movement filtering
    mov     x4, w2                  // Save delta_x
    mov     x5, w3                  // Save delta_y
    bl      filter_mouse_movement
    cmp     x0, #0
    b.eq    cocoa_mouse_moved_done  // Movement filtered out
    
    // Convert coordinates
    bl      convert_cocoa_coordinates
    
    // Send to input handler
    mov     x2, x4                  // delta_x
    mov     x3, x5                  // delta_y
    bl      input_handle_mouse_move

cocoa_mouse_moved_done:
    RESTORE_REGS
    ret

// cocoa_key_down: Handle key down from Cocoa
// Args: x0 = NSEvent pointer
// Returns: none
.global cocoa_key_down
cocoa_key_down:
    SAVE_REGS
    
    mov     x19, x0                 // Save NSEvent pointer
    
    // Check if input is enabled
    adrp    x0, input_enabled@PAGE
    add     x0, x0, input_enabled@PAGEOFF
    ldrb    w0, [x0]
    cbz     w0, cocoa_key_down_done
    
    // Extract key event data
    mov     x0, x19
    bl      extract_key_event_data
    // Returns: w0 = key_code, w1 = modifiers
    
    // Apply key repeat filtering
    bl      filter_key_repeat
    cmp     x0, #0
    b.eq    cocoa_key_down_done     // Key repeat filtered out
    
    // Send to input handler
    mov     x1, w1                  // modifiers
    bl      input_handle_key_down

cocoa_key_down_done:
    RESTORE_REGS
    ret

// cocoa_key_up: Handle key up from Cocoa
// Args: x0 = NSEvent pointer
// Returns: none
.global cocoa_key_up
cocoa_key_up:
    SAVE_REGS
    
    mov     x19, x0                 // Save NSEvent pointer
    
    // Check if input is enabled
    adrp    x0, input_enabled@PAGE
    add     x0, x0, input_enabled@PAGEOFF
    ldrb    w0, [x0]
    cbz     w0, cocoa_key_up_done
    
    // Extract key event data
    mov     x0, x19
    bl      extract_key_event_data
    
    // Send to input handler
    mov     x1, w1                  // modifiers
    bl      input_handle_key_up

cocoa_key_up_done:
    RESTORE_REGS
    ret

// cocoa_scroll_wheel: Handle scroll wheel from Cocoa
// Args: x0 = NSEvent pointer
// Returns: none
.global cocoa_scroll_wheel
cocoa_scroll_wheel:
    SAVE_REGS
    
    mov     x19, x0                 // Save NSEvent pointer
    
    // Check if input is enabled
    adrp    x0, input_enabled@PAGE
    add     x0, x0, input_enabled@PAGEOFF
    ldrb    w0, [x0]
    cbz     w0, cocoa_scroll_done
    
    // Extract scroll data
    mov     x0, x19
    bl      extract_scroll_event_data
    // Returns: w0 = delta_x, w1 = delta_y, w2 = modifiers
    
    // Apply scroll acceleration
    bl      apply_scroll_acceleration
    
    // Send to input handler
    mov     x2, w2                  // modifiers
    bl      input_handle_scroll

cocoa_scroll_done:
    RESTORE_REGS
    ret

// cocoa_magnify: Handle trackpad magnify gesture from Cocoa
// Args: x0 = NSEvent pointer
// Returns: none
.global cocoa_magnify
cocoa_magnify:
    SAVE_REGS
    
    mov     x19, x0                 // Save NSEvent pointer
    
    // Check if input is enabled
    adrp    x0, input_enabled@PAGE
    add     x0, x0, input_enabled@PAGEOFF
    ldrb    w0, [x0]
    cbz     w0, cocoa_magnify_done
    
    // Extract magnification data
    mov     x0, x19
    bl      extract_magnify_data
    // Returns: s0 = magnification, w1 = phase
    
    // Convert to touch gesture event
    bl      convert_magnify_to_gesture
    
    // Send to gesture system
    bl      process_gesture_event

cocoa_magnify_done:
    RESTORE_REGS
    ret

//==============================================================================
// NSEvent Data Extraction Functions
//==============================================================================

// extract_mouse_event_data: Extract data from NSEvent for mouse events
// Args: x0 = NSEvent pointer
// Returns: w0 = x, w1 = y, w2 = button_flags, w3 = modifiers
extract_mouse_event_data:
    SAVE_REGS
    
    mov     x19, x0                 // Save NSEvent pointer
    
    // Call Cocoa bridge to get location in window
    adrp    x0, nsevent_location_func@PAGE
    add     x0, x0, nsevent_location_func@PAGEOFF
    ldr     x0, [x0]
    cbz     x0, extract_mouse_error
    
    mov     x1, x19                 // NSEvent
    blr     x0
    // Returns coordinates in s0, s1
    
    // Convert to integers
    fcvtzs  w20, s0                 // x coordinate
    fcvtzs  w21, s1                 // y coordinate
    
    // Extract button flags (simplified - would use actual NSEvent methods)
    mov     w22, #1                 // Assume left button for now
    
    // Extract modifiers (simplified)
    mov     w23, #0                 // No modifiers for now
    
    mov     w0, w20                 // Return x
    mov     w1, w21                 // Return y
    mov     w2, w22                 // Return button_flags
    mov     w3, w23                 // Return modifiers
    
    RESTORE_REGS
    ret

extract_mouse_error:
    mov     w0, #0
    mov     w1, #0
    mov     w2, #0
    mov     w3, #0
    RESTORE_REGS
    ret

// extract_mouse_move_data: Extract movement data from NSEvent
// Args: x0 = NSEvent pointer
// Returns: w0 = x, w1 = y, w2 = delta_x, w3 = delta_y
extract_mouse_move_data:
    SAVE_REGS
    
    // For now, use simplified extraction
    // In real implementation, this would call NSEvent deltaX/deltaY methods
    
    bl      extract_mouse_event_data
    mov     w24, w0                 // Save x
    mov     w25, w1                 // Save y
    
    // Calculate deltas (simplified - would track previous position)
    mov     w26, #1                 // delta_x
    mov     w27, #1                 // delta_y
    
    mov     w0, w24                 // Return x
    mov     w1, w25                 // Return y
    mov     w2, w26                 // Return delta_x
    mov     w3, w27                 // Return delta_y
    
    RESTORE_REGS
    ret

// extract_key_event_data: Extract data from NSEvent for key events
// Args: x0 = NSEvent pointer
// Returns: w0 = key_code, w1 = modifiers
extract_key_event_data:
    SAVE_REGS
    
    // Simplified key extraction - would use actual NSEvent keyCode method
    mov     w0, #13                 // Default to 'W' key
    mov     w1, #0                  // No modifiers
    
    RESTORE_REGS
    ret

// extract_scroll_event_data: Extract scroll data from NSEvent
// Args: x0 = NSEvent pointer
// Returns: w0 = delta_x, w1 = delta_y, w2 = modifiers
extract_scroll_event_data:
    SAVE_REGS
    
    // Simplified scroll extraction - would use actual NSEvent deltaX/deltaY
    mov     w0, #0                  // delta_x
    mov     w1, #10                 // delta_y (zoom in)
    mov     w2, #0                  // modifiers
    
    RESTORE_REGS
    ret

// extract_magnify_data: Extract magnification data from NSEvent
// Args: x0 = NSEvent pointer
// Returns: s0 = magnification, w1 = phase
extract_magnify_data:
    SAVE_REGS
    
    // Simplified magnification extraction
    fmov    s0, #0.1                // 10% magnification
    mov     w1, #1                  // Changed phase
    
    RESTORE_REGS
    ret

//==============================================================================
// Coordinate System Conversion
//==============================================================================

// convert_cocoa_coordinates: Convert Cocoa coordinates to our system
// Args: w0 = cocoa_x, w1 = cocoa_y
// Returns: w0 = adjusted_x, w1 = adjusted_y
convert_cocoa_coordinates:
    SAVE_REGS_LIGHT
    
    // Load window bounds
    adrp    x2, window_bounds_height@PAGE
    add     x2, x2, window_bounds_height@PAGEOFF
    ldr     s2, [x2]                // window height
    
    // Convert Y coordinate (Cocoa has inverted Y)
    scvtf   s0, w0                  // x to float
    scvtf   s1, w1                  // y to float
    fsub    s1, s2, s1              // invert Y: height - y
    
    // Apply window scale if needed
    adrp    x2, window_scale@PAGE
    add     x2, x2, window_scale@PAGEOFF
    ldr     s3, [x2]
    fmul    s0, s0, s3
    fmul    s1, s1, s3
    
    // Convert back to integers
    fcvtzs  w0, s0
    fcvtzs  w1, s1
    
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Event Filtering and Processing
//==============================================================================

// init_event_filtering: Initialize event filtering system
// Returns: none
init_event_filtering:
    SAVE_REGS_LIGHT
    
    // Set default filter values
    adrp    x0, min_mouse_delta@PAGE
    add     x0, x0, min_mouse_delta@PAGEOFF
    fmov    s0, #1.0
    str     s0, [x0]
    
    adrp    x0, gesture_sensitivity@PAGE
    add     x0, x0, gesture_sensitivity@PAGEOFF
    fmov    s0, #1.0
    str     s0, [x0]
    
    adrp    x0, scroll_acceleration@PAGE
    add     x0, x0, scroll_acceleration@PAGEOFF
    fmov    s0, #1.2
    str     s0, [x0]
    
    RESTORE_REGS_LIGHT
    ret

// filter_mouse_movement: Filter mouse movement to reduce noise
// Args: w2 = delta_x, w3 = delta_y
// Returns: x0 = 1 if movement should be processed, 0 if filtered
filter_mouse_movement:
    SAVE_REGS_LIGHT
    
    // Calculate movement magnitude
    scvtf   s0, w2                  // delta_x
    scvtf   s1, w3                  // delta_y
    fmul    s2, s0, s0              // delta_x²
    fmul    s3, s1, s1              // delta_y²
    fadd    s4, s2, s3              // delta_x² + delta_y²
    fsqrt   s4, s4                  // magnitude
    
    // Check against minimum threshold
    adrp    x0, min_mouse_delta@PAGE
    add     x0, x0, min_mouse_delta@PAGEOFF
    ldr     s5, [x0]
    
    fcmp    s4, s5
    b.lt    filter_movement_out
    
    mov     x0, #1                  // Allow movement
    RESTORE_REGS_LIGHT
    ret

filter_movement_out:
    mov     x0, #0                  // Filter out movement
    RESTORE_REGS_LIGHT
    ret

// filter_key_repeat: Filter key repeat events
// Args: w0 = key_code
// Returns: x0 = 1 if key should be processed, 0 if filtered
filter_key_repeat:
    SAVE_REGS_LIGHT
    
    // For now, allow all key events
    // In full implementation, would track key repeat timing
    mov     x0, #1
    
    RESTORE_REGS_LIGHT
    ret

// apply_scroll_acceleration: Apply acceleration to scroll events
// Args: w0 = delta_x, w1 = delta_y
// Returns: w0 = adjusted_delta_x, w1 = adjusted_delta_y
apply_scroll_acceleration:
    SAVE_REGS_LIGHT
    
    // Load acceleration factor
    adrp    x2, scroll_acceleration@PAGE
    add     x2, x2, scroll_acceleration@PAGEOFF
    ldr     s2, [x2]
    
    // Apply acceleration
    scvtf   s0, w0                  // delta_x to float
    scvtf   s1, w1                  // delta_y to float
    fmul    s0, s0, s2              // apply acceleration
    fmul    s1, s1, s2
    
    // Convert back to integers
    fcvtzs  w0, s0
    fcvtzs  w1, s1
    
    RESTORE_REGS_LIGHT
    ret

// apply_event_filtering: Apply post-processing event filtering
// Returns: none
apply_event_filtering:
    SAVE_REGS_LIGHT
    
    // TODO: Implement advanced event filtering
    // - Gesture conflict resolution
    // - Input prediction
    // - Smoothing algorithms
    
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Performance Monitoring and Frame Timing
//==============================================================================

// init_performance_monitoring: Initialize performance tracking
// Returns: none
init_performance_monitoring:
    SAVE_REGS_LIGHT
    
    // Clear performance counters
    adrp    x0, events_processed@PAGE
    add     x0, x0, events_processed@PAGEOFF
    str     xzr, [x0]
    
    adrp    x0, total_processing_time@PAGE
    add     x0, x0, total_processing_time@PAGEOFF
    str     xzr, [x0]
    
    adrp    x0, peak_processing_time@PAGE
    add     x0, x0, peak_processing_time@PAGEOFF
    str     xzr, [x0]
    
    // Initialize frame timing
    mrs     x1, cntvct_el0
    adrp    x0, last_frame_time@PAGE
    add     x0, x0, last_frame_time@PAGEOFF
    str     x1, [x0]
    
    RESTORE_REGS_LIGHT
    ret

// update_frame_timing: Update frame timing information
// Returns: none
update_frame_timing:
    SAVE_REGS_LIGHT
    
    mrs     x0, cntvct_el0          // Current time
    
    adrp    x1, last_frame_time@PAGE
    add     x1, x1, last_frame_time@PAGEOFF
    ldr     x2, [x1]                // Previous frame time
    str     x0, [x1]                // Store current time
    
    sub     x3, x0, x2              // Frame delta
    adrp    x1, frame_delta@PAGE
    add     x1, x1, frame_delta@PAGEOFF
    str     x3, [x1]
    
    RESTORE_REGS_LIGHT
    ret

// update_performance_metrics: Update performance tracking
// Args: x0 = processing_time
// Returns: none
update_performance_metrics:
    SAVE_REGS_LIGHT
    
    mov     x19, x0                 // Save processing time
    
    // Increment event count
    adrp    x0, events_processed@PAGE
    add     x0, x0, events_processed@PAGEOFF
    ldr     x1, [x0]
    add     x1, x1, #1
    str     x1, [x0]
    
    // Add to total processing time
    adrp    x0, total_processing_time@PAGE
    add     x0, x0, total_processing_time@PAGEOFF
    ldr     x1, [x0]
    add     x1, x1, x19
    str     x1, [x0]
    
    // Check for new peak
    adrp    x0, peak_processing_time@PAGE
    add     x0, x0, peak_processing_time@PAGEOFF
    ldr     x1, [x0]
    cmp     x19, x1
    b.le    update_metrics_done
    str     x19, [x0]               // New peak

update_metrics_done:
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Window State Management
//==============================================================================

// init_default_window_state: Initialize default window configuration
// Returns: none
init_default_window_state:
    SAVE_REGS_LIGHT
    
    // Set default window dimensions
    adrp    x0, window_width@PAGE
    add     x0, x0, window_width@PAGEOFF
    fmov    s0, #800.0
    str     s0, [x0]
    
    adrp    x0, window_height@PAGE
    add     x0, x0, window_height@PAGEOFF
    fmov    s0, #600.0
    str     s0, [x0]
    
    adrp    x0, window_scale@PAGE
    add     x0, x0, window_scale@PAGEOFF
    fmov    s0, #1.0
    str     s0, [x0]
    
    // Set default bounds
    adrp    x0, window_bounds_width@PAGE
    add     x0, x0, window_bounds_width@PAGEOFF
    fmov    s0, #800.0
    str     s0, [x0]
    
    adrp    x0, window_bounds_height@PAGE
    add     x0, x0, window_bounds_height@PAGEOFF
    fmov    s0, #600.0
    str     s0, [x0]
    
    RESTORE_REGS_LIGHT
    ret

// update_window_state: Update window state from platform
// Args: s0 = width, s1 = height, s2 = scale
// Returns: none
.global update_window_state
update_window_state:
    SAVE_REGS_LIGHT
    
    // Update window dimensions
    adrp    x0, window_width@PAGE
    add     x0, x0, window_width@PAGEOFF
    str     s0, [x0]
    
    adrp    x0, window_height@PAGE
    add     x0, x0, window_height@PAGEOFF
    str     s1, [x0]
    
    adrp    x0, window_scale@PAGE
    add     x0, x0, window_scale@PAGEOFF
    str     s2, [x0]
    
    // Update bounds
    adrp    x0, window_bounds_width@PAGE
    add     x0, x0, window_bounds_width@PAGEOFF
    str     s0, [x0]
    
    adrp    x0, window_bounds_height@PAGE
    add     x0, x0, window_bounds_height@PAGEOFF
    str     s1, [x0]
    
    // Notify input system of dimension changes
    ucvtf   w0, s0                  // Convert to integer width
    ucvtf   w1, s1                  // Convert to integer height
    bl      input_update_screen_dimensions
    
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Gesture Integration Functions
//==============================================================================

// update_gesture_processing: Update gesture recognition system
// Returns: none
update_gesture_processing:
    SAVE_REGS_LIGHT
    
    // TODO: Update gesture state machine
    // - Process multi-touch combinations
    // - Update gesture timing
    // - Resolve gesture conflicts
    
    RESTORE_REGS_LIGHT
    ret

// convert_magnify_to_gesture: Convert Cocoa magnify to gesture event
// Args: s0 = magnification, w1 = phase
// Returns: none
convert_magnify_to_gesture:
    SAVE_REGS_LIGHT
    
    // TODO: Convert magnification to zoom gesture
    // This would create appropriate touch events for the gesture system
    
    RESTORE_REGS_LIGHT
    ret

// process_gesture_event: Process gesture event
// Returns: none
process_gesture_event:
    SAVE_REGS_LIGHT
    
    // TODO: Send gesture to appropriate handler
    
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Debug and Diagnostics
//==============================================================================

// input_enable_debug: Enable debug output for input system
// Returns: none
.global input_enable_debug
input_enable_debug:
    adrp    x0, debug_enabled@PAGE
    add     x0, x0, debug_enabled@PAGEOFF
    mov     w1, #1
    strb    w1, [x0]
    ret

// input_disable_debug: Disable debug output
// Returns: none
.global input_disable_debug
input_disable_debug:
    adrp    x0, debug_enabled@PAGE
    add     x0, x0, debug_enabled@PAGEOFF
    strb    wzr, [x0]
    ret

// input_get_performance_stats: Get performance statistics
// Returns: x0 = events_processed, x1 = avg_processing_time, x2 = peak_time
.global input_get_performance_stats
input_get_performance_stats:
    SAVE_REGS_LIGHT
    
    adrp    x0, events_processed@PAGE
    add     x0, x0, events_processed@PAGEOFF
    ldr     x19, [x0]               // events_processed
    
    adrp    x0, total_processing_time@PAGE
    add     x0, x0, total_processing_time@PAGEOFF
    ldr     x20, [x0]               // total_time
    
    adrp    x0, peak_processing_time@PAGE
    add     x0, x0, peak_processing_time@PAGEOFF
    ldr     x21, [x0]               // peak_time
    
    // Calculate average (avoid division by zero)
    cbz     x19, stats_done
    udiv    x20, x20, x19           // avg = total / count

stats_done:
    mov     x0, x19                 // Return events_processed
    mov     x1, x20                 // Return avg_processing_time
    mov     x2, x21                 // Return peak_time
    
    RESTORE_REGS_LIGHT
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
    
clear_integration_loop:
    cmp     x2, x3
    b.ge    clear_integration_done
    strb    wzr, [x2], #1
    b       clear_integration_loop

clear_integration_done:
    RESTORE_REGS_LIGHT
    ret

.end