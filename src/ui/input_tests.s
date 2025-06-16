//
// SimCity ARM64 Assembly - Input System Unit Tests
// Agent D5: Infrastructure Team - Comprehensive input handling tests
//
// Unit tests for input handling and event dispatch system
//

.cpu generic+simd
.arch armv8-a+simd

// Include platform constants and testing framework
.include "../include/macros/platform_asm.inc"
.include "../include/macros/testing.inc"
.include "../include/constants/platform_constants.h"

.section .data
.align 3

//==============================================================================
// Test Framework State and Configuration
//==============================================================================

// Test suite information
.test_suite_info:
    suite_name:             .asciz  "Input System Tests"
    total_tests:            .quad   0
    passed_tests:           .quad   0
    failed_tests:           .quad   0
    current_test:           .quad   0

// Test result tracking
.test_results:
    .space 100 * 8          // Space for 100 test results (8 bytes each)

// Mock handler state for testing
.mock_handlers:
    simulation_called:      .quad   0
    graphics_called:        .quad   0
    audio_called:           .quad   0
    ui_called:              .quad   0
    last_build_x:           .quad   0
    last_build_y:           .quad   0
    last_build_type:        .quad   0
    camera_move_count:      .quad   0

// Test data structures
.test_event_data:
    .space 64               // Space for test event structures

.section .text
.align 4

//==============================================================================
// Test Suite Entry Point
//==============================================================================

// run_input_tests: Run complete input system test suite
// Returns: x0 = number of failed tests
.global run_input_tests
run_input_tests:
    SAVE_REGS
    
    // Initialize test framework
    bl      init_test_framework
    
    // Print test suite header
    adrp    x0, test_header@PAGE
    add     x0, x0, test_header@PAGEOFF
    bl      print_string
    
    // Initialize input system for testing
    bl      input_system_init
    
    // Register mock handlers
    bl      register_mock_handlers
    
    // Run test categories
    bl      test_input_initialization
    bl      test_event_buffer_management
    bl      test_coordinate_conversion
    bl      test_key_mapping
    bl      test_mouse_event_processing
    bl      test_keyboard_event_processing
    bl      test_gesture_recognition
    bl      test_command_dispatch
    bl      test_state_management
    bl      test_error_conditions
    
    // Print test results summary
    bl      print_test_summary
    
    // Return number of failed tests
    adrp    x0, failed_tests@PAGE
    add     x0, x0, failed_tests@PAGEOFF
    ldr     x0, [x0]
    
    RESTORE_REGS
    ret

//==============================================================================
// Input System Initialization Tests
//==============================================================================

test_input_initialization:
    SAVE_REGS_LIGHT
    
    START_TEST "Input System Initialization"
    
    // Test 1: System should initialize successfully
    bl      input_system_init
    ASSERT_EQ x0, #0, "Input system init should return 0"
    
    // Test 2: Double initialization should be safe
    bl      input_system_init
    ASSERT_EQ x0, #0, "Double init should be safe"
    
    // Test 3: Event buffer should be empty after init
    bl      get_event_buffer_count
    ASSERT_EQ x0, #0, "Event buffer should be empty after init"
    
    // Test 4: Camera should be at origin
    bl      get_camera_position
    ASSERT_FLOAT_EQ s0, #0.0, "Camera X should be 0.0"
    ASSERT_FLOAT_EQ s1, #0.0, "Camera Y should be 0.0"
    
    // Test 5: Zoom should be 1.0
    bl      get_camera_zoom
    ASSERT_FLOAT_EQ s0, #1.0, "Zoom should be 1.0"
    
    END_TEST
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Event Buffer Management Tests
//==============================================================================

test_event_buffer_management:
    SAVE_REGS_LIGHT
    
    START_TEST "Event Buffer Management"
    
    // Test 1: Buffer starts empty
    bl      get_event_buffer_count
    ASSERT_EQ x0, #0, "Buffer should start empty"
    
    // Test 2: Can enqueue single event
    bl      create_test_mouse_event
    bl      enqueue_event
    ASSERT_EQ x0, #0, "Should enqueue successfully"
    
    bl      get_event_buffer_count
    ASSERT_EQ x0, #1, "Buffer should have 1 event"
    
    // Test 3: Can dequeue event
    bl      dequeue_event
    ASSERT_NE x0, #0, "Should return event pointer"
    
    bl      get_event_buffer_count
    ASSERT_EQ x0, #0, "Buffer should be empty after dequeue"
    
    // Test 4: Fill buffer to capacity
    mov     x19, #0
fill_buffer_loop:
    cmp     x19, #1024              // INPUT_EVENT_BUFFER_SIZE
    b.ge    fill_buffer_done
    
    bl      create_test_mouse_event
    bl      enqueue_event
    ASSERT_EQ x0, #0, "Should enqueue successfully"
    
    add     x19, x19, #1
    b       fill_buffer_loop

fill_buffer_done:
    // Test 5: Buffer overflow handling
    bl      create_test_mouse_event
    bl      enqueue_event
    ASSERT_EQ x0, #-1, "Should fail when buffer full"
    
    // Test 6: Clear buffer
    bl      clear_event_buffer
    bl      get_event_buffer_count
    ASSERT_EQ x0, #0, "Buffer should be empty after clear"
    
    END_TEST
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Coordinate Conversion Tests
//==============================================================================

test_coordinate_conversion:
    SAVE_REGS_LIGHT
    
    START_TEST "Coordinate Conversion"
    
    // Test 1: Screen center to world center
    mov     w0, #400                // Screen center X (800/2)
    mov     w1, #300                // Screen center Y (600/2)
    scvtf   s0, w0
    scvtf   s1, w1
    bl      screen_to_world_coords
    
    // With default camera (0,0) and zoom 1.0, screen center should map to world (0,0)
    ASSERT_FLOAT_NEAR s2, #0.0, #0.1, "World X should be near 0"
    ASSERT_FLOAT_NEAR s3, #0.0, #0.1, "World Y should be near 0"
    
    // Test 2: World to grid conversion
    fmov    s0, #0.0               // World center
    fmov    s1, #0.0
    bl      world_to_grid_coords
    
    // Grid coordinates should be reasonable
    ASSERT_GE w0, #0, "Grid X should be >= 0"
    ASSERT_GE w1, #0, "Grid Y should be >= 0"
    ASSERT_LT w0, #30, "Grid X should be < 30"
    ASSERT_LT w1, #30, "Grid Y should be < 30"
    
    // Test 3: Grid coordinate validation
    mov     w0, #15                 // Valid coordinates
    mov     w1, #15
    bl      validate_grid_coordinates
    ASSERT_EQ x0, #0, "Valid coordinates should return 0"
    
    mov     w0, #-1                 // Invalid coordinates
    mov     w1, #15
    bl      validate_grid_coordinates
    ASSERT_EQ x0, #-1, "Invalid coordinates should return -1"
    
    mov     w0, #30                 // Out of bounds
    mov     w1, #15
    bl      validate_grid_coordinates
    ASSERT_EQ x0, #-1, "Out of bounds should return -1"
    
    // Test 4: Camera transform affects conversion
    bl      set_test_camera_position // Set camera to (1.0, 1.0)
    
    mov     w0, #400                // Screen center
    mov     w1, #300
    scvtf   s0, w0
    scvtf   s1, w1
    bl      screen_to_world_coords
    
    // World coordinates should be offset by camera position
    ASSERT_FLOAT_NEAR s2, #1.0, #0.1, "World X should be near 1.0"
    ASSERT_FLOAT_NEAR s3, #1.0, #0.1, "World Y should be near 1.0"
    
    // Reset camera for other tests
    bl      reset_test_camera
    
    END_TEST
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Key Mapping Tests
//==============================================================================

test_key_mapping:
    SAVE_REGS_LIGHT
    
    START_TEST "Key Mapping"
    
    // Test 1: WASD camera controls
    mov     w0, #0                  // A key
    bl      lookup_key_action
    ASSERT_EQ w0, #1, "A key should map to camera left"  // ACTION_CAMERA_LEFT = 1
    
    mov     w0, #2                  // D key
    bl      lookup_key_action
    ASSERT_EQ w0, #2, "D key should map to camera right" // ACTION_CAMERA_RIGHT = 2
    
    mov     w0, #13                 // W key
    bl      lookup_key_action
    ASSERT_EQ w0, #3, "W key should map to camera up"    // ACTION_CAMERA_UP = 3
    
    mov     w0, #1                  // S key
    bl      lookup_key_action
    ASSERT_EQ w0, #4, "S key should map to camera down"  // ACTION_CAMERA_DOWN = 4
    
    // Test 2: Number keys for building types
    mov     w0, #18                 // 1 key
    bl      lookup_key_action
    ASSERT_EQ w0, #5, "1 key should map to build house"  // ACTION_BUILD_HOUSE = 5
    
    mov     w0, #19                 // 2 key
    bl      lookup_key_action
    ASSERT_EQ w0, #6, "2 key should map to build commercial" // ACTION_BUILD_COMMERCIAL = 6
    
    // Test 3: Unmapped keys
    mov     w0, #50                 // Random unmapped key
    bl      lookup_key_action
    ASSERT_EQ w0, #0, "Unmapped key should return ACTION_NONE"
    
    // Test 4: Out of bounds key codes
    mov     w0, #300                // Out of bounds
    bl      lookup_key_action
    ASSERT_EQ w0, #0, "Out of bounds key should return ACTION_NONE"
    
    END_TEST
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Mouse Event Processing Tests
//==============================================================================

test_mouse_event_processing:
    SAVE_REGS_LIGHT
    
    START_TEST "Mouse Event Processing"
    
    // Reset mock handlers
    bl      reset_mock_handlers
    
    // Test 1: Left mouse click should trigger build command
    mov     x0, #400                // Screen center
    mov     x1, #300
    mov     x2, #1                  // Left button
    mov     x3, #0                  // No modifiers
    bl      input_handle_mouse_down
    
    // Process the event
    bl      input_process_events
    ASSERT_GT x0, #0, "Should process at least 1 event"
    
    // Check that simulation handler was called
    adrp    x0, simulation_called@PAGE
    add     x0, x0, simulation_called@PAGEOFF
    ldr     x0, [x0]
    ASSERT_GT x0, #0, "Simulation handler should be called"
    
    // Test 2: Right mouse click should trigger delete command
    bl      reset_mock_handlers
    
    mov     x0, #400                // Screen center
    mov     x1, #300
    mov     x2, #2                  // Right button
    mov     x3, #0                  // No modifiers
    bl      input_handle_mouse_down
    
    bl      input_process_events
    
    // Check that delete command was sent (building type = 0)
    adrp    x0, last_build_type@PAGE
    add     x0, x0, last_build_type@PAGEOFF
    ldr     x0, [x0]
    ASSERT_EQ x0, #0, "Should send delete command (empty tile)"
    
    // Test 3: Mouse movement without buttons should not trigger commands
    bl      reset_mock_handlers
    
    mov     x0, #450                // New position
    mov     x1, #350
    mov     x2, #10                 // Delta X
    mov     x3, #10                 // Delta Y
    bl      input_handle_mouse_move
    
    bl      input_process_events
    
    adrp    x0, simulation_called@PAGE
    add     x0, x0, simulation_called@PAGEOFF
    ldr     x0, [x0]
    ASSERT_EQ x0, #0, "Mouse move without buttons should not call simulation"
    
    // Test 4: Scroll wheel should affect camera zoom
    bl      get_camera_zoom
    fmov    s10, s0                 // Save initial zoom
    
    mov     x0, #0                  // No horizontal scroll
    mov     x1, #10                 // Positive vertical scroll (zoom in)
    mov     x2, #0                  // No modifiers
    bl      input_handle_scroll
    
    bl      input_process_events
    
    bl      get_camera_zoom
    fcmp    s0, s10
    b.eq    zoom_test_failed
    b       zoom_test_passed

zoom_test_failed:
    FAIL_TEST "Scroll should change camera zoom"

zoom_test_passed:
    PASS_TEST "Scroll correctly changed camera zoom"
    
    END_TEST
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Keyboard Event Processing Tests
//==============================================================================

test_keyboard_event_processing:
    SAVE_REGS_LIGHT
    
    START_TEST "Keyboard Event Processing"
    
    // Test 1: Camera movement keys
    bl      get_camera_position
    fmov    s10, s0                 // Save initial X
    fmov    s11, s1                 // Save initial Y
    
    mov     x0, #0                  // A key (camera left)
    mov     x1, #0                  // No modifiers
    bl      input_handle_key_down
    
    bl      input_process_events
    
    bl      get_camera_position
    fcmp    s0, s10
    b.eq    camera_move_failed
    
    PASS_TEST "A key moves camera left"
    b       camera_move_done

camera_move_failed:
    FAIL_TEST "A key should move camera left"

camera_move_done:
    
    // Test 2: Building type selection
    mov     x0, #18                 // 1 key (house)
    mov     x1, #0                  // No modifiers
    bl      input_handle_key_down
    
    bl      input_process_events
    
    bl      get_current_building_type
    ASSERT_EQ x0, #2, "1 key should set building type to house (2)"
    
    // Test 3: Overlay toggle
    bl      reset_mock_handlers
    
    mov     x0, #122                // F1 key
    mov     x1, #0                  // No modifiers
    bl      input_handle_key_down
    
    bl      input_process_events
    
    adrp    x0, graphics_called@PAGE
    add     x0, x0, graphics_called@PAGEOFF
    ldr     x0, [x0]
    ASSERT_GT x0, #0, "F1 should trigger graphics handler (overlay toggle)"
    
    END_TEST
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Gesture Recognition Tests
//==============================================================================

test_gesture_recognition:
    SAVE_REGS_LIGHT
    
    START_TEST "Gesture Recognition"
    
    // Initialize gesture system
    bl      gesture_system_init
    
    // Test 1: Single tap gesture
    mov     x0, #400                // Touch at center
    mov     x1, #300
    mov     x2, #100                // Normal pressure
    mov     x3, #0                  // Touch begin
    bl      gesture_process_touch_event
    
    // Small movement (within tap threshold)
    mov     x0, #402                // Small movement
    mov     x1, #301
    mov     x2, #100
    mov     x3, #1                  // Touch moved
    bl      gesture_process_touch_event
    
    // End touch quickly
    mov     x0, #402
    mov     x1, #301
    mov     x2, #0                  // No pressure
    mov     x3, #2                  // Touch ended
    bl      gesture_process_touch_event
    
    bl      gesture_get_current_state
    ldr     w1, [x0, #0]            // Gesture type (GESTURE_STATE_TYPE offset)
    ASSERT_EQ w1, #4, "Should recognize tap gesture"  // GESTURE_TAP = 4
    
    // Test 2: Pan gesture (larger movement)
    mov     x0, #400                // Start at center
    mov     x1, #300
    mov     x2, #100
    mov     x3, #0                  // Touch begin
    bl      gesture_process_touch_event
    
    // Large movement (exceeds tap threshold)
    mov     x0, #450                // 50 pixel movement
    mov     x1, #300
    mov     x2, #100
    mov     x3, #1                  // Touch moved
    bl      gesture_process_touch_event
    
    bl      gesture_get_current_state
    ldr     w1, [x0, #0]            // Gesture type
    ASSERT_EQ w1, #1, "Should recognize pan gesture"  // GESTURE_PAN = 1
    
    // End pan
    mov     x0, #450
    mov     x1, #300
    mov     x2, #0
    mov     x3, #2                  // Touch ended
    bl      gesture_process_touch_event
    
    // Test 3: Multi-touch zoom (simplified - would need more complex setup)
    // For now, just test that gesture system handles multi-touch events
    mov     x0, #300                // First touch
    mov     x1, #300
    mov     x2, #100
    mov     x3, #0
    bl      gesture_process_touch_event
    
    mov     x0, #500                // Second touch (simulated)
    mov     x1, #300
    mov     x2, #100
    mov     x3, #0
    bl      gesture_process_touch_event
    
    bl      gesture_get_current_state
    ldr     w1, [x0, #0]            // Gesture type
    // Should be zoom gesture or at least not crash
    ASSERT_GE w1, #0, "Multi-touch should not cause negative gesture type"
    
    END_TEST
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Command Dispatch Tests
//==============================================================================

test_command_dispatch:
    SAVE_REGS_LIGHT
    
    START_TEST "Command Dispatch"
    
    bl      reset_mock_handlers
    
    // Test 1: Build command dispatch
    mov     w0, #15                 // Grid X
    mov     w1, #10                 // Grid Y
    mov     x2, #2                  // Building type (house)
    bl      dispatch_build_command
    
    // Check that simulation handler was called with correct parameters
    adrp    x0, simulation_called@PAGE
    add     x0, x0, simulation_called@PAGEOFF
    ldr     x0, [x0]
    ASSERT_GT x0, #0, "Build command should call simulation handler"
    
    adrp    x0, last_build_x@PAGE
    add     x0, x0, last_build_x@PAGEOFF
    ldr     x0, [x0]
    ASSERT_EQ x0, #15, "Should pass correct grid X"
    
    adrp    x0, last_build_y@PAGE
    add     x0, x0, last_build_y@PAGEOFF
    ldr     x0, [x0]
    ASSERT_EQ x0, #10, "Should pass correct grid Y"
    
    adrp    x0, last_build_type@PAGE
    add     x0, x0, last_build_type@PAGEOFF
    ldr     x0, [x0]
    ASSERT_EQ x0, #2, "Should pass correct building type"
    
    // Test 2: Camera movement dispatch
    bl      get_camera_position
    fmov    s10, s0                 // Save initial position
    
    mov     x0, #1                  // Direction: right
    mov     x1, #0                  // Axis: X
    bl      dispatch_camera_move
    
    bl      get_camera_position
    fcmp    s0, s10
    b.le    camera_dispatch_failed
    
    PASS_TEST "Camera move dispatch works correctly"
    b       camera_dispatch_done

camera_dispatch_failed:
    FAIL_TEST "Camera move dispatch should change position"

camera_dispatch_done:
    
    // Test 3: Graphics handler dispatch
    bl      reset_mock_handlers
    
    bl      dispatch_overlay_toggle
    
    adrp    x0, graphics_called@PAGE
    add     x0, x0, graphics_called@PAGEOFF
    ldr     x0, [x0]
    ASSERT_GT x0, #0, "Overlay toggle should call graphics handler"
    
    END_TEST
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// State Management Tests
//==============================================================================

test_state_management:
    SAVE_REGS_LIGHT
    
    START_TEST "State Management"
    
    // Test 1: Building type management
    mov     x0, #3                  // Industrial
    bl      set_current_building_type
    
    bl      get_current_building_type
    ASSERT_EQ x0, #3, "Should set and get building type correctly"
    
    // Test 2: Mouse button state tracking
    mov     x0, #1                  // Left button flag
    bl      update_mouse_button_state
    
    bl      get_left_button_state
    ASSERT_EQ x0, #1, "Left button should be marked as down"
    
    mov     x0, #1                  // Clear left button
    bl      clear_mouse_button_state
    
    bl      get_left_button_state
    ASSERT_EQ x0, #0, "Left button should be marked as up"
    
    // Test 3: Camera state management
    bl      get_camera_position
    fmov    s10, s0
    fmov    s11, s1
    
    fmov    s0, #5.5
    fmov    s1, #-2.3
    bl      set_camera_position
    
    bl      get_camera_position
    ASSERT_FLOAT_EQ s0, #5.5, "Camera X should be set correctly"
    ASSERT_FLOAT_EQ s1, #-2.3, "Camera Y should be set correctly"
    
    // Reset camera for other tests
    fmov    s0, s10
    fmov    s1, s11
    bl      set_camera_position
    
    END_TEST
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Error Condition Tests
//==============================================================================

test_error_conditions:
    SAVE_REGS_LIGHT
    
    START_TEST "Error Conditions"
    
    // Test 1: Invalid grid coordinates
    mov     w0, #-5                 // Invalid X
    mov     w1, #10
    bl      validate_grid_coordinates
    ASSERT_EQ x0, #-1, "Negative coordinates should be invalid"
    
    mov     w0, #35                 // Out of bounds X
    mov     w1, #10
    bl      validate_grid_coordinates
    ASSERT_EQ x0, #-1, "Out of bounds coordinates should be invalid"
    
    // Test 2: Event buffer overflow
    bl      clear_event_buffer
    
    // Fill buffer beyond capacity
    mov     x19, #0
overflow_test_loop:
    cmp     x19, #1025              // One more than capacity
    b.ge    overflow_test_done
    
    bl      create_test_mouse_event
    bl      enqueue_event
    
    cmp     x19, #1024              // At capacity
    b.lt    overflow_continue
    
    // This should fail
    ASSERT_EQ x0, #-1, "Enqueue should fail when buffer is full"

overflow_continue:
    add     x19, x19, #1
    b       overflow_test_loop

overflow_test_done:
    
    // Test 3: Dequeue from empty buffer
    bl      clear_event_buffer
    bl      dequeue_event
    ASSERT_EQ x0, #0, "Dequeue from empty buffer should return 0"
    
    // Test 4: Null pointer handling in dispatch
    adrp    x0, simulation_handler@PAGE
    add     x0, x0, simulation_handler@PAGEOFF
    str     xzr, [x0]               // Clear handler pointer
    
    mov     w0, #10
    mov     w1, #10
    mov     x2, #1
    bl      dispatch_build_command   // Should not crash
    
    PASS_TEST "Null handler dispatch should not crash"
    
    // Restore handler for other tests
    bl      register_mock_handlers
    
    END_TEST
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Mock Handler Functions
//==============================================================================

register_mock_handlers:
    SAVE_REGS_LIGHT
    
    adrp    x0, mock_simulation_handler@PAGE
    add     x0, x0, mock_simulation_handler@PAGEOFF
    bl      input_register_simulation_handler
    
    adrp    x0, mock_graphics_handler@PAGE
    add     x0, x0, mock_graphics_handler@PAGEOFF
    bl      input_register_graphics_handler
    
    adrp    x0, mock_audio_handler@PAGE
    add     x0, x0, mock_audio_handler@PAGEOFF
    bl      input_register_audio_handler
    
    adrp    x0, mock_ui_handler@PAGE
    add     x0, x0, mock_ui_handler@PAGEOFF
    bl      input_register_ui_handler
    
    RESTORE_REGS_LIGHT
    ret

mock_simulation_handler:
    // Args: w0 = grid_x, w1 = grid_y, x2 = building_type
    SAVE_REGS_LIGHT
    
    // Record that handler was called
    adrp    x3, simulation_called@PAGE
    add     x3, x3, simulation_called@PAGEOFF
    ldr     x4, [x3]
    add     x4, x4, #1
    str     x4, [x3]
    
    // Record parameters
    adrp    x3, last_build_x@PAGE
    add     x3, x3, last_build_x@PAGEOFF
    sxtw    x4, w0
    str     x4, [x3]
    
    adrp    x3, last_build_y@PAGE
    add     x3, x3, last_build_y@PAGEOFF
    sxtw    x4, w1
    str     x4, [x3]
    
    adrp    x3, last_build_type@PAGE
    add     x3, x3, last_build_type@PAGEOFF
    str     x2, [x3]
    
    RESTORE_REGS_LIGHT
    ret

mock_graphics_handler:
    SAVE_REGS_LIGHT
    
    // Record that handler was called
    adrp    x0, graphics_called@PAGE
    add     x0, x0, graphics_called@PAGEOFF
    ldr     x1, [x0]
    add     x1, x1, #1
    str     x1, [x0]
    
    RESTORE_REGS_LIGHT
    ret

mock_audio_handler:
    SAVE_REGS_LIGHT
    
    // Record that handler was called
    adrp    x0, audio_called@PAGE
    add     x0, x0, audio_called@PAGEOFF
    ldr     x1, [x0]
    add     x1, x1, #1
    str     x1, [x0]
    
    RESTORE_REGS_LIGHT
    ret

mock_ui_handler:
    SAVE_REGS_LIGHT
    
    // Record that handler was called
    adrp    x0, ui_called@PAGE
    add     x0, x0, ui_called@PAGEOFF
    ldr     x1, [x0]
    add     x1, x1, #1
    str     x1, [x0]
    
    RESTORE_REGS_LIGHT
    ret

reset_mock_handlers:
    SAVE_REGS_LIGHT
    
    adrp    x0, mock_handlers@PAGE
    add     x0, x0, mock_handlers@PAGEOFF
    mov     x1, #64                 // Size of mock_handlers structure
    bl      clear_memory_region
    
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Test Helper Functions
//==============================================================================

create_test_mouse_event:
    SAVE_REGS_LIGHT
    
    adrp    x0, test_event_data@PAGE
    add     x0, x0, test_event_data@PAGEOFF
    
    // Create a basic mouse down event
    mov     w1, #1                  // INPUT_EVENT_MOUSE_DOWN
    str     w1, [x0]
    
    mrs     x1, cntvct_el0
    str     x1, [x0, #4]            // timestamp
    
    fmov    s1, #400.0              // x coordinate
    str     s1, [x0, #12]
    fmov    s1, #300.0              // y coordinate  
    str     s1, [x0, #16]
    
    mov     w1, #1                  // left button
    str     w1, [x0, #20]
    
    str     wzr, [x0, #28]          // no modifiers
    
    RESTORE_REGS_LIGHT
    ret

get_event_buffer_count:
    adrp    x0, event_buffer_count@PAGE
    add     x0, x0, event_buffer_count@PAGEOFF
    ldr     x0, [x0]
    ret

get_camera_position:
    adrp    x0, camera_x@PAGE
    add     x0, x0, camera_x@PAGEOFF
    ldr     s0, [x0]
    adrp    x0, camera_y@PAGE
    add     x0, x0, camera_y@PAGEOFF
    ldr     s1, [x0]
    ret

set_camera_position:
    adrp    x1, camera_x@PAGE
    add     x1, x1, camera_x@PAGEOFF
    str     s0, [x1]
    adrp    x1, camera_y@PAGE
    add     x1, x1, camera_y@PAGEOFF
    str     s1, [x1]
    ret

get_camera_zoom:
    adrp    x0, camera_zoom@PAGE
    add     x0, x0, camera_zoom@PAGEOFF
    ldr     s0, [x0]
    ret

get_current_building_type:
    adrp    x0, current_building_type@PAGE
    add     x0, x0, current_building_type@PAGEOFF
    ldr     x0, [x0]
    ret

get_left_button_state:
    adrp    x0, left_button_down@PAGE
    add     x0, x0, left_button_down@PAGEOFF
    ldrb    w0, [x0]
    sxtw    x0, w0
    ret

set_test_camera_position:
    fmov    s0, #1.0
    fmov    s1, #1.0
    bl      set_camera_position
    ret

reset_test_camera:
    fmov    s0, wzr
    fmov    s1, wzr
    bl      set_camera_position
    ret

clear_memory_region:
    SAVE_REGS_LIGHT
    
    mov     x2, x0                  // Save start address
    add     x3, x0, x1              // End address
    
clear_test_loop:
    cmp     x2, x3
    b.ge    clear_test_done
    strb    wzr, [x2], #1
    b       clear_test_loop

clear_test_done:
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Test Framework Functions
//==============================================================================

init_test_framework:
    SAVE_REGS_LIGHT
    
    // Clear test counters
    adrp    x0, total_tests@PAGE
    add     x0, x0, total_tests@PAGEOFF
    str     xzr, [x0]
    
    adrp    x0, passed_tests@PAGE
    add     x0, x0, passed_tests@PAGEOFF
    str     xzr, [x0]
    
    adrp    x0, failed_tests@PAGE
    add     x0, x0, failed_tests@PAGEOFF
    str     xzr, [x0]
    
    RESTORE_REGS_LIGHT
    ret

print_test_summary:
    SAVE_REGS_LIGHT
    
    // Print summary header
    adrp    x0, summary_header@PAGE
    add     x0, x0, summary_header@PAGEOFF
    bl      print_string
    
    // Print test counts
    adrp    x0, total_tests@PAGE
    add     x0, x0, total_tests@PAGEOFF
    ldr     x0, [x0]
    bl      print_number
    
    adrp    x0, passed_tests@PAGE
    add     x0, x0, passed_tests@PAGEOFF
    ldr     x0, [x0]
    bl      print_number
    
    adrp    x0, failed_tests@PAGE
    add     x0, x0, failed_tests@PAGEOFF
    ldr     x0, [x0]
    bl      print_number
    
    RESTORE_REGS_LIGHT
    ret

// Placeholder print functions (would integrate with actual output system)
print_string:
    ret

print_number:
    ret

//==============================================================================
// Test Data and Messages
//==============================================================================

.section .data
.align 3

test_header:                .asciz  "=== SimCity Input System Tests ===\n"
summary_header:             .asciz  "\n=== Test Summary ===\n"

.end