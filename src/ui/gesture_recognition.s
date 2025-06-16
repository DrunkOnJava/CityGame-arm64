//
// SimCity ARM64 Assembly - Gesture Recognition System
// Agent D5: Infrastructure Team - Touch gesture recognition for trackpad
//
// Advanced trackpad gesture recognition in pure ARM64 assembly
//

.cpu generic+simd
.arch armv8-a+simd

// Include platform constants and macros
.include "../include/macros/platform_asm.inc"
.include "../include/constants/platform_constants.h"

.section .data
.align 3

//==============================================================================
// Gesture Recognition Constants and State
//==============================================================================

// Gesture types
.equ GESTURE_NONE,              0
.equ GESTURE_PAN,               1
.equ GESTURE_ZOOM,              2
.equ GESTURE_ROTATE,            3
.equ GESTURE_TAP,               4
.equ GESTURE_DOUBLE_TAP,        5
.equ GESTURE_SWIPE,             6

// Touch point structure offsets
.equ TOUCH_POINT_X,             0
.equ TOUCH_POINT_Y,             4
.equ TOUCH_POINT_PRESSURE,      8
.equ TOUCH_POINT_SIZE,          12
.equ TOUCH_POINT_ACTIVE,        16
.equ TOUCH_POINT_TIMESTAMP,     20
.equ TOUCH_POINT_STRUCT_SIZE,   28

// Gesture state structure offsets
.equ GESTURE_STATE_TYPE,        0
.equ GESTURE_STATE_ACTIVE,      4
.equ GESTURE_STATE_PHASE,       8       // 0=begin, 1=changed, 2=ended
.equ GESTURE_STATE_TOUCH_COUNT, 12
.equ GESTURE_STATE_START_TIME,  16
.equ GESTURE_STATE_DURATION,    24
.equ GESTURE_STATE_START_X,     32
.equ GESTURE_STATE_START_Y,     36
.equ GESTURE_STATE_CURRENT_X,   40
.equ GESTURE_STATE_CURRENT_Y,   44
.equ GESTURE_STATE_DELTA_X,     48
.equ GESTURE_STATE_DELTA_Y,     52
.equ GESTURE_STATE_VELOCITY_X,  56
.equ GESTURE_STATE_VELOCITY_Y,  60
.equ GESTURE_STATE_SCALE,       64
.equ GESTURE_STATE_ROTATION,    68
.equ GESTURE_STATE_DISTANCE,    72
.equ GESTURE_STATE_INITIAL_DISTANCE, 76
.equ GESTURE_STATE_STRUCT_SIZE, 80

// Configuration constants
.equ MAX_TOUCH_POINTS,          10
.equ PAN_THRESHOLD,             5       // Minimum pixels for pan
.equ TAP_THRESHOLD,             10      // Maximum pixels for tap
.equ ZOOM_THRESHOLD,            20      // Minimum distance change for zoom
.equ ROTATE_THRESHOLD,          0.1     // Minimum radians for rotation
.equ TAP_MAX_DURATION,          500000000   // 500ms in nanoseconds
.equ DOUBLE_TAP_MAX_INTERVAL,   300000000   // 300ms between taps
.equ SWIPE_MIN_VELOCITY,        100     // Minimum velocity for swipe

// Current gesture state
.gesture_current_state:
    .space GESTURE_STATE_STRUCT_SIZE

// Touch point tracking
.touch_points:
    .space MAX_TOUCH_POINTS * TOUCH_POINT_STRUCT_SIZE

// Touch tracking state
.touch_tracking_state:
    active_count:           .quad   0
    last_tap_time:          .quad   0
    last_tap_x:             .float  0.0
    last_tap_y:             .float  0.0
    gesture_recognized:     .byte   0
    gesture_in_progress:    .byte   0
    .align 3

// Gesture recognition thresholds (configurable)
.gesture_config:
    pan_threshold:          .float  5.0
    tap_threshold:          .float  10.0
    zoom_threshold:         .float  20.0
    rotate_threshold:       .float  0.1
    velocity_threshold:     .float  100.0
    tap_max_duration:       .quad   500000000
    double_tap_interval:    .quad   300000000

.section .text
.align 4

//==============================================================================
// Public Interface Functions
//==============================================================================

// gesture_system_init: Initialize gesture recognition system
// Returns: x0 = 0 on success, error code on failure
.global gesture_system_init
gesture_system_init:
    SAVE_REGS_LIGHT
    
    // Clear all state structures
    adrp    x0, gesture_current_state@PAGE
    add     x0, x0, gesture_current_state@PAGEOFF
    mov     x1, #GESTURE_STATE_STRUCT_SIZE
    bl      clear_memory_region
    
    adrp    x0, touch_points@PAGE
    add     x0, x0, touch_points@PAGEOFF
    mov     x1, #MAX_TOUCH_POINTS * TOUCH_POINT_STRUCT_SIZE
    bl      clear_memory_region
    
    adrp    x0, touch_tracking_state@PAGE
    add     x0, x0, touch_tracking_state@PAGEOFF
    mov     x1, #32                 // Size of tracking state
    bl      clear_memory_region
    
    mov     x0, #0                  // Success
    RESTORE_REGS_LIGHT
    ret

// gesture_process_touch_event: Process incoming touch event
// Args: x0 = touch_x, x1 = touch_y, x2 = pressure, x3 = touch_phase (0=begin, 1=moved, 2=ended)
// Returns: x0 = 0 on success, gesture type if gesture recognized
.global gesture_process_touch_event
gesture_process_touch_event:
    SAVE_REGS
    
    mov     x19, x0                 // Save touch_x
    mov     x20, x1                 // Save touch_y
    mov     x21, x2                 // Save pressure
    mov     x22, x3                 // Save touch_phase
    
    // Get current timestamp
    mrs     x23, cntvct_el0
    
    // Process based on touch phase
    cmp     x22, #0
    b.eq    process_touch_begin
    cmp     x22, #1
    b.eq    process_touch_moved
    cmp     x22, #2
    b.eq    process_touch_ended
    
    // Unknown phase
    mov     x0, #-1
    b       gesture_process_done

process_touch_begin:
    mov     x0, x19                 // touch_x
    mov     x1, x20                 // touch_y
    mov     x2, x21                 // pressure
    mov     x3, x23                 // timestamp
    bl      handle_touch_begin
    b       gesture_process_done

process_touch_moved:
    mov     x0, x19                 // touch_x
    mov     x1, x20                 // touch_y
    mov     x2, x21                 // pressure
    mov     x3, x23                 // timestamp
    bl      handle_touch_moved
    b       gesture_process_done

process_touch_ended:
    mov     x0, x19                 // touch_x
    mov     x1, x20                 // touch_y
    mov     x2, x21                 // pressure
    mov     x3, x23                 // timestamp
    bl      handle_touch_ended

gesture_process_done:
    RESTORE_REGS
    ret

// gesture_get_current_state: Get current gesture state
// Returns: x0 = pointer to gesture state structure
.global gesture_get_current_state
gesture_get_current_state:
    adrp    x0, gesture_current_state@PAGE
    add     x0, x0, gesture_current_state@PAGEOFF
    ret

//==============================================================================
// Touch Event Handlers
//==============================================================================

// handle_touch_begin: Handle touch begin event
// Args: x0 = touch_x, x1 = touch_y, x2 = pressure, x3 = timestamp
// Returns: x0 = gesture type if recognized, 0 otherwise
handle_touch_begin:
    SAVE_REGS
    
    mov     x19, x0                 // Save touch_x
    mov     x20, x1                 // Save touch_y
    mov     x21, x2                 // Save pressure
    mov     x22, x3                 // Save timestamp
    
    // Find available touch point slot
    bl      find_available_touch_slot
    mov     x23, x0                 // Save slot index
    cmp     x23, #-1
    b.eq    touch_begin_done        // No available slots
    
    // Store touch point data
    adrp    x0, touch_points@PAGE
    add     x0, x0, touch_points@PAGEOFF
    mov     x1, #TOUCH_POINT_STRUCT_SIZE
    madd    x24, x23, x1, x0        // touch_point address
    
    // Fill touch point structure
    scvtf   s0, w19
    str     s0, [x24, #TOUCH_POINT_X]
    scvtf   s1, w20
    str     s1, [x24, #TOUCH_POINT_Y]
    scvtf   s2, w21
    str     s2, [x24, #TOUCH_POINT_PRESSURE]
    mov     w0, #1
    strb    w0, [x24, #TOUCH_POINT_ACTIVE]
    str     x22, [x24, #TOUCH_POINT_TIMESTAMP]
    
    // Increment active touch count
    adrp    x0, active_count@PAGE
    add     x0, x0, active_count@PAGEOFF
    ldr     x1, [x0]
    add     x1, x1, #1
    str     x1, [x0]
    
    // Initialize gesture state based on touch count
    cmp     x1, #1
    b.eq    init_single_touch_gesture
    cmp     x1, #2
    b.eq    init_multi_touch_gesture
    
    // More than 2 touches - complex gesture
    b       touch_begin_done

init_single_touch_gesture:
    // Initialize potential tap or pan gesture
    adrp    x0, gesture_current_state@PAGE
    add     x0, x0, gesture_current_state@PAGEOFF
    
    mov     w1, #GESTURE_TAP        // Assume tap initially
    str     w1, [x0, #GESTURE_STATE_TYPE]
    mov     w1, #1
    strb    w1, [x0, #GESTURE_STATE_ACTIVE]
    strb    wzr, [x0, #GESTURE_STATE_PHASE]  // Begin phase
    mov     x1, #1
    str     x1, [x0, #GESTURE_STATE_TOUCH_COUNT]
    str     x22, [x0, #GESTURE_STATE_START_TIME]
    
    scvtf   s0, w19
    str     s0, [x0, #GESTURE_STATE_START_X]
    str     s0, [x0, #GESTURE_STATE_CURRENT_X]
    scvtf   s1, w20
    str     s1, [x0, #GESTURE_STATE_START_Y]
    str     s1, [x0, #GESTURE_STATE_CURRENT_Y]
    
    b       touch_begin_done

init_multi_touch_gesture:
    // Initialize potential zoom or rotate gesture
    bl      calculate_touch_center_and_distance
    // Returns: s0 = center_x, s1 = center_y, s2 = distance
    
    adrp    x0, gesture_current_state@PAGE
    add     x0, x0, gesture_current_state@PAGEOFF
    
    mov     w1, #GESTURE_ZOOM       // Assume zoom initially
    str     w1, [x0, #GESTURE_STATE_TYPE]
    mov     w1, #1
    strb    w1, [x0, #GESTURE_STATE_ACTIVE]
    strb    wzr, [x0, #GESTURE_STATE_PHASE]  // Begin phase
    mov     x1, #2
    str     x1, [x0, #GESTURE_STATE_TOUCH_COUNT]
    str     x22, [x0, #GESTURE_STATE_START_TIME]
    
    str     s0, [x0, #GESTURE_STATE_START_X]
    str     s0, [x0, #GESTURE_STATE_CURRENT_X]
    str     s1, [x0, #GESTURE_STATE_START_Y]
    str     s1, [x0, #GESTURE_STATE_CURRENT_Y]
    str     s2, [x0, #GESTURE_STATE_INITIAL_DISTANCE]
    fmov    s3, #1.0
    str     s3, [x0, #GESTURE_STATE_SCALE]

touch_begin_done:
    mov     x0, #0                  // No gesture recognized yet
    RESTORE_REGS
    ret

// handle_touch_moved: Handle touch move event
// Args: x0 = touch_x, x1 = touch_y, x2 = pressure, x3 = timestamp
// Returns: x0 = gesture type if recognized, 0 otherwise
handle_touch_moved:
    SAVE_REGS
    
    mov     x19, x0                 // Save touch_x
    mov     x20, x1                 // Save touch_y
    mov     x21, x2                 // Save pressure
    mov     x22, x3                 // Save timestamp
    
    // Find the touch point to update
    bl      find_nearest_active_touch
    mov     x23, x0                 // Save touch index
    cmp     x23, #-1
    b.eq    touch_moved_done        // No active touch found
    
    // Update touch point data
    adrp    x0, touch_points@PAGE
    add     x0, x0, touch_points@PAGEOFF
    mov     x1, #TOUCH_POINT_STRUCT_SIZE
    madd    x24, x23, x1, x0        // touch_point address
    
    // Store previous position for velocity calculation
    ldr     s4, [x24, #TOUCH_POINT_X]       // prev_x
    ldr     s5, [x24, #TOUCH_POINT_Y]       // prev_y
    ldr     x4, [x24, #TOUCH_POINT_TIMESTAMP] // prev_time
    
    // Update position
    scvtf   s0, w19
    str     s0, [x24, #TOUCH_POINT_X]
    scvtf   s1, w20
    str     s1, [x24, #TOUCH_POINT_Y]
    str     x22, [x24, #TOUCH_POINT_TIMESTAMP]
    
    // Calculate velocity
    sub     x5, x22, x4             // time_delta
    ucvtf   d6, x5                  // time_delta as double
    fmov    d7, #1000000000.0       // nanoseconds per second
    fdiv    d6, d7, d6              // 1/time_delta (frequency)
    
    fsub    s2, s0, s4              // dx
    fsub    s3, s1, s5              // dy
    fcvt    d2, s2                  // dx as double
    fcvt    d3, s3                  // dy as double
    fmul    d2, d2, d6              // velocity_x
    fmul    d3, d3, d6              // velocity_y
    fcvt    s2, d2                  // back to single precision
    fcvt    s3, d3
    
    // Update gesture state based on current gesture type
    adrp    x0, gesture_current_state@PAGE
    add     x0, x0, gesture_current_state@PAGEOFF
    ldr     w1, [x0, #GESTURE_STATE_TYPE]
    
    cmp     w1, #GESTURE_TAP
    b.eq    update_tap_gesture
    cmp     w1, #GESTURE_PAN
    b.eq    update_pan_gesture
    cmp     w1, #GESTURE_ZOOM
    b.eq    update_zoom_gesture
    
    b       touch_moved_done

update_tap_gesture:
    // Check if movement exceeds tap threshold
    ldr     s6, [x0, #GESTURE_STATE_START_X]
    ldr     s7, [x0, #GESTURE_STATE_START_Y]
    fsub    s8, s0, s6              // dx from start
    fsub    s9, s1, s7              // dy from start
    
    // Calculate distance from start
    fmul    s8, s8, s8              // dx²
    fmul    s9, s9, s9              // dy²
    fadd    s8, s8, s9              // dx² + dy²
    fsqrt   s8, s8                  // distance
    
    adrp    x1, tap_threshold@PAGE
    add     x1, x1, tap_threshold@PAGEOFF
    ldr     s10, [x1]
    
    fcmp    s8, s10
    b.le    tap_gesture_update_done
    
    // Movement exceeds threshold - convert to pan
    mov     w1, #GESTURE_PAN
    str     w1, [x0, #GESTURE_STATE_TYPE]
    
tap_gesture_update_done:
    b       update_gesture_common

update_pan_gesture:
    // Update pan delta and velocity
    str     s2, [x0, #GESTURE_STATE_VELOCITY_X]
    str     s3, [x0, #GESTURE_STATE_VELOCITY_Y]
    b       update_gesture_common

update_zoom_gesture:
    // Recalculate center and distance for zoom/scale
    bl      calculate_touch_center_and_distance
    // Returns: s10 = center_x, s11 = center_y, s12 = current_distance
    
    ldr     s13, [x0, #GESTURE_STATE_INITIAL_DISTANCE]
    fdiv    s14, s12, s13           // scale = current_distance / initial_distance
    str     s14, [x0, #GESTURE_STATE_SCALE]
    str     s10, [x0, #GESTURE_STATE_CURRENT_X]
    str     s11, [x0, #GESTURE_STATE_CURRENT_Y]
    
    b       update_gesture_common

update_gesture_common:
    // Common gesture state updates
    str     s0, [x0, #GESTURE_STATE_CURRENT_X]
    str     s1, [x0, #GESTURE_STATE_CURRENT_Y]
    
    // Update phase to "changed"
    mov     w1, #1
    strb    w1, [x0, #GESTURE_STATE_PHASE]
    
    // Calculate deltas from start
    ldr     s6, [x0, #GESTURE_STATE_START_X]
    ldr     s7, [x0, #GESTURE_STATE_START_Y]
    fsub    s8, s0, s6
    fsub    s9, s1, s7
    str     s8, [x0, #GESTURE_STATE_DELTA_X]
    str     s9, [x0, #GESTURE_STATE_DELTA_Y]

touch_moved_done:
    // Return current gesture type
    adrp    x0, gesture_current_state@PAGE
    add     x0, x0, gesture_current_state@PAGEOFF
    ldr     w0, [x0, #GESTURE_STATE_TYPE]
    RESTORE_REGS
    ret

// handle_touch_ended: Handle touch end event
// Args: x0 = touch_x, x1 = touch_y, x2 = pressure, x3 = timestamp
// Returns: x0 = gesture type if recognized, 0 otherwise
handle_touch_ended:
    SAVE_REGS
    
    mov     x19, x0                 // Save touch_x
    mov     x20, x1                 // Save touch_y
    mov     x21, x2                 // Save pressure
    mov     x22, x3                 // Save timestamp
    
    // Find and deactivate the touch point
    bl      find_nearest_active_touch
    mov     x23, x0                 // Save touch index
    cmp     x23, #-1
    b.eq    touch_ended_done        // No active touch found
    
    // Deactivate touch point
    adrp    x0, touch_points@PAGE
    add     x0, x0, touch_points@PAGEOFF
    mov     x1, #TOUCH_POINT_STRUCT_SIZE
    madd    x24, x23, x1, x0        // touch_point address
    strb    wzr, [x24, #TOUCH_POINT_ACTIVE]
    
    // Decrement active touch count
    adrp    x0, active_count@PAGE
    add     x0, x0, active_count@PAGEOFF
    ldr     x1, [x0]
    sub     x1, x1, #1
    str     x1, [x0]
    
    // Finalize gesture based on current state
    adrp    x25, gesture_current_state@PAGE
    add     x25, x25, gesture_current_state@PAGEOFF
    ldr     w26, [x25, #GESTURE_STATE_TYPE]
    
    cmp     w26, #GESTURE_TAP
    b.eq    finalize_tap_gesture
    cmp     w26, #GESTURE_PAN
    b.eq    finalize_pan_gesture
    cmp     w26, #GESTURE_ZOOM
    b.eq    finalize_zoom_gesture
    
    b       touch_ended_done

finalize_tap_gesture:
    // Check if it's a valid tap (time and distance)
    ldr     x0, [x25, #GESTURE_STATE_START_TIME]
    sub     x1, x22, x0             // duration
    adrp    x2, tap_max_duration@PAGE
    add     x2, x2, tap_max_duration@PAGEOFF
    ldr     x2, [x2]
    
    cmp     x1, x2
    b.gt    finalize_tap_done       // Too long for tap
    
    // Check for double tap
    bl      check_double_tap
    cmp     x0, #1
    b.eq    recognize_double_tap
    
    // Single tap recognized
    mov     w26, #GESTURE_TAP
    b       finalize_gesture_common

recognize_double_tap:
    mov     w26, #GESTURE_DOUBLE_TAP
    b       finalize_gesture_common

finalize_tap_done:
    mov     w26, #GESTURE_NONE
    b       finalize_gesture_common

finalize_pan_gesture:
    // Calculate final velocity for potential swipe detection
    ldr     s0, [x25, #GESTURE_STATE_VELOCITY_X]
    ldr     s1, [x25, #GESTURE_STATE_VELOCITY_Y]
    
    // Calculate velocity magnitude
    fmul    s2, s0, s0              // vx²
    fmul    s3, s1, s1              // vy²
    fadd    s2, s2, s3              // vx² + vy²
    fsqrt   s2, s2                  // velocity magnitude
    
    adrp    x0, velocity_threshold@PAGE
    add     x0, x0, velocity_threshold@PAGEOFF
    ldr     s3, [x0]
    
    fcmp    s2, s3
    b.ge    recognize_swipe
    
    // Regular pan gesture
    mov     w26, #GESTURE_PAN
    b       finalize_gesture_common

recognize_swipe:
    mov     w26, #GESTURE_SWIPE
    b       finalize_gesture_common

finalize_zoom_gesture:
    // Zoom gesture is complete
    mov     w26, #GESTURE_ZOOM
    b       finalize_gesture_common

finalize_gesture_common:
    // Set final gesture state
    str     w26, [x25, #GESTURE_STATE_TYPE]
    mov     w0, #2
    strb    w0, [x25, #GESTURE_STATE_PHASE]  // Ended phase
    
    // If no active touches, clear gesture state
    adrp    x0, active_count@PAGE
    add     x0, x0, active_count@PAGEOFF
    ldr     x0, [x0]
    cbnz    x0, touch_ended_done
    
    // No active touches - clear gesture
    strb    wzr, [x25, #GESTURE_STATE_ACTIVE]

touch_ended_done:
    mov     x0, x26                 // Return recognized gesture type
    RESTORE_REGS
    ret

//==============================================================================
// Helper Functions
//==============================================================================

// find_available_touch_slot: Find available touch point slot
// Returns: x0 = slot index, -1 if none available
find_available_touch_slot:
    SAVE_REGS_LIGHT
    
    adrp    x0, touch_points@PAGE
    add     x0, x0, touch_points@PAGEOFF
    mov     x1, #0                  // Index counter
    
find_slot_loop:
    cmp     x1, #MAX_TOUCH_POINTS
    b.ge    no_slot_available
    
    mov     x2, #TOUCH_POINT_STRUCT_SIZE
    madd    x3, x1, x2, x0          // touch_point address
    ldrb    w4, [x3, #TOUCH_POINT_ACTIVE]
    cbz     w4, slot_found
    
    add     x1, x1, #1
    b       find_slot_loop

no_slot_available:
    mov     x0, #-1
    RESTORE_REGS_LIGHT
    ret

slot_found:
    mov     x0, x1                  // Return slot index
    RESTORE_REGS_LIGHT
    ret

// find_nearest_active_touch: Find nearest active touch point
// Args: x0 = target_x, x1 = target_y
// Returns: x0 = touch index, -1 if none found
find_nearest_active_touch:
    SAVE_REGS
    
    mov     x19, x0                 // Save target_x
    mov     x20, x1                 // Save target_y
    scvtf   s0, w19                 // target_x as float
    scvtf   s1, w20                 // target_y as float
    
    adrp    x21, touch_points@PAGE
    add     x21, x21, touch_points@PAGEOFF
    mov     x22, #-1                // Best match index
    fmov    s2, #1000000.0          // Best distance (very large)
    mov     x23, #0                 // Current index
    
find_nearest_loop:
    cmp     x23, #MAX_TOUCH_POINTS
    b.ge    find_nearest_done
    
    mov     x0, #TOUCH_POINT_STRUCT_SIZE
    madd    x24, x23, x0, x21       // touch_point address
    ldrb    w0, [x24, #TOUCH_POINT_ACTIVE]
    cbz     w0, find_nearest_next   // Skip inactive touches
    
    // Calculate distance
    ldr     s3, [x24, #TOUCH_POINT_X]
    ldr     s4, [x24, #TOUCH_POINT_Y]
    fsub    s5, s0, s3              // dx
    fsub    s6, s1, s4              // dy
    fmul    s5, s5, s5              // dx²
    fmul    s6, s6, s6              // dy²
    fadd    s7, s5, s6              // distance²
    fsqrt   s7, s7                  // distance
    
    fcmp    s7, s2
    b.ge    find_nearest_next
    
    // New best match
    fmov    s2, s7
    mov     x22, x23

find_nearest_next:
    add     x23, x23, #1
    b       find_nearest_loop

find_nearest_done:
    mov     x0, x22                 // Return best match index
    RESTORE_REGS
    ret

// calculate_touch_center_and_distance: Calculate center and distance for multi-touch
// Returns: s0 = center_x, s1 = center_y, s2 = distance between first two active touches
calculate_touch_center_and_distance:
    SAVE_REGS
    
    adrp    x19, touch_points@PAGE
    add     x19, x19, touch_points@PAGEOFF
    mov     x20, #0                 // Index counter
    mov     x21, #0                 // Active touch counter
    fmov    s0, wzr                 // sum_x
    fmov    s1, wzr                 // sum_y
    fmov    s10, wzr                // first_x
    fmov    s11, wzr                // first_y
    fmov    s12, wzr                // second_x
    fmov    s13, wzr                // second_y
    
calc_center_loop:
    cmp     x20, #MAX_TOUCH_POINTS
    b.ge    calc_center_done
    
    mov     x0, #TOUCH_POINT_STRUCT_SIZE
    madd    x22, x20, x0, x19       // touch_point address
    ldrb    w0, [x22, #TOUCH_POINT_ACTIVE]
    cbz     w0, calc_center_next    // Skip inactive touches
    
    ldr     s3, [x22, #TOUCH_POINT_X]
    ldr     s4, [x22, #TOUCH_POINT_Y]
    
    // Add to sum
    fadd    s0, s0, s3
    fadd    s1, s1, s4
    
    // Store first two touches for distance calculation
    cmp     x21, #0
    b.eq    store_first_touch
    cmp     x21, #1
    b.eq    store_second_touch
    b       calc_center_next

store_first_touch:
    fmov    s10, s3
    fmov    s11, s4
    b       calc_center_next

store_second_touch:
    fmov    s12, s3
    fmov    s13, s4

calc_center_next:
    add     x21, x21, #1
    add     x20, x20, #1
    b       calc_center_loop

calc_center_done:
    // Calculate center (average position)
    cbz     x21, calc_center_error
    ucvtf   s5, w21                 // active_touch_count as float
    fdiv    s0, s0, s5              // center_x
    fdiv    s1, s1, s5              // center_y
    
    // Calculate distance between first two touches
    fsub    s6, s12, s10            // dx
    fsub    s7, s13, s11            // dy
    fmul    s6, s6, s6              // dx²
    fmul    s7, s7, s7              // dy²
    fadd    s8, s6, s7              // dx² + dy²
    fsqrt   s2, s8                  // distance
    
    RESTORE_REGS
    ret

calc_center_error:
    fmov    s0, wzr
    fmov    s1, wzr
    fmov    s2, wzr
    RESTORE_REGS
    ret

// check_double_tap: Check if current tap is part of double tap
// Returns: x0 = 1 if double tap, 0 otherwise
check_double_tap:
    SAVE_REGS_LIGHT
    
    // Get current gesture state
    adrp    x19, gesture_current_state@PAGE
    add     x19, x19, gesture_current_state@PAGEOFF
    
    // Get last tap info
    adrp    x20, last_tap_time@PAGE
    add     x20, x20, last_tap_time@PAGEOFF
    ldr     x0, [x20]               // last_tap_time
    
    cbz     x0, not_double_tap      // No previous tap
    
    // Check time interval
    ldr     x1, [x19, #GESTURE_STATE_START_TIME]  // current_tap_time
    sub     x2, x1, x0              // time_interval
    adrp    x3, double_tap_interval@PAGE
    add     x3, x3, double_tap_interval@PAGEOFF
    ldr     x3, [x3]
    
    cmp     x2, x3
    b.gt    not_double_tap          // Too long interval
    
    // Check position proximity
    adrp    x4, last_tap_x@PAGE
    add     x4, x4, last_tap_x@PAGEOFF
    ldr     s0, [x4]                // last_tap_x
    adrp    x4, last_tap_y@PAGE
    add     x4, x4, last_tap_y@PAGEOFF
    ldr     s1, [x4]                // last_tap_y
    
    ldr     s2, [x19, #GESTURE_STATE_START_X]  // current_tap_x
    ldr     s3, [x19, #GESTURE_STATE_START_Y]  // current_tap_y
    
    fsub    s4, s2, s0              // dx
    fsub    s5, s3, s1              // dy
    fmul    s4, s4, s4              // dx²
    fmul    s5, s5, s5              // dy²
    fadd    s6, s4, s5              // distance²
    fsqrt   s6, s6                  // distance
    
    adrp    x5, tap_threshold@PAGE
    add     x5, x5, tap_threshold@PAGEOFF
    ldr     s7, [x5]
    
    fcmp    s6, s7
    b.gt    not_double_tap          // Too far apart
    
    // It's a double tap - clear last tap time
    str     xzr, [x20]
    mov     x0, #1
    RESTORE_REGS_LIGHT
    ret

not_double_tap:
    // Update last tap info for potential future double tap
    str     x1, [x20]               // Store current time as last_tap_time
    adrp    x6, last_tap_x@PAGE
    add     x6, x6, last_tap_x@PAGEOFF
    str     s2, [x6]
    adrp    x6, last_tap_y@PAGE
    add     x6, x6, last_tap_y@PAGEOFF
    str     s3, [x6]
    
    mov     x0, #0
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
    
clear_loop:
    cmp     x2, x3
    b.ge    clear_done
    strb    wzr, [x2], #1
    b       clear_loop

clear_done:
    RESTORE_REGS_LIGHT
    ret

.end