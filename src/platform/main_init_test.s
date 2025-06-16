//
// SimCity ARM64 Assembly - Main Initialization Test
// Sub-Agent 1: Main Application Architect
//
// Test suite for verifying main application initialization sequence
//

.include "../include/macros/platform_asm.inc"

.section .data
.align 4

test_results:
    platform_test_result:       .word 0
    memory_test_result:         .word 0
    core_test_result:           .word 0
    graphics_test_result:       .word 0
    simulation_test_result:     .word 0
    ai_test_result:             .word 0
    io_test_result:             .word 0
    audio_test_result:          .word 0
    ui_test_result:             .word 0
    integration_test_result:    .word 0

test_messages:
    test_start_msg:             .asciz "Starting main initialization tests...\n"
    test_complete_msg:          .asciz "Main initialization tests complete\n"
    test_pass_msg:              .asciz "PASS\n"
    test_fail_msg:              .asciz "FAIL\n"
    platform_test_msg:          .asciz "Platform initialization test: "
    memory_test_msg:            .asciz "Memory system test: "
    core_test_msg:              .asciz "Core systems test: "
    graphics_test_msg:          .asciz "Graphics system test: "
    simulation_test_msg:        .asciz "Simulation system test: "
    ai_test_msg:                .asciz "AI system test: "
    io_test_msg:                .asciz "I/O system test: "
    audio_test_msg:             .asciz "Audio system test: "
    ui_test_msg:                .asciz "UI system test: "
    integration_msg:            .asciz "Full integration test: "

.section .text
.align 4

//==============================================================================
// Main Integration Test Entry Point
//==============================================================================

.global run_main_init_tests
run_main_init_tests:
    SAVE_REGS
    
    // Initialize error handling first
    bl error_system_init
    
    // Log test start
    adrp x0, test_start_msg
    add x0, x0, :lo12:test_start_msg
    bl output_string
    
    // Run individual system tests
    bl test_platform_initialization
    bl test_memory_systems
    bl test_core_systems
    bl test_graphics_systems
    bl test_simulation_systems
    bl test_ai_systems
    bl test_io_systems
    bl test_audio_systems
    bl test_ui_systems
    
    // Run full integration test
    bl test_full_integration
    
    // Display results
    bl display_test_results
    
    // Check overall success
    bl check_overall_success
    
    RESTORE_REGS
    ret

//==============================================================================
// Individual System Tests
//==============================================================================

test_platform_initialization:
    SAVE_REGS_LIGHT
    
    // Test platform init
    bl platform_init
    mov x1, x0  // Save result
    
    // Store result
    adrp x0, platform_test_result
    add x0, x0, :lo12:platform_test_result
    str w1, [x0]
    
    // Log result
    adrp x0, platform_test_msg
    add x0, x0, :lo12:platform_test_msg
    bl log_test_result_with_message
    
    RESTORE_REGS_LIGHT
    ret

test_memory_systems:
    SAVE_REGS_LIGHT
    
    // Test memory init
    bl memory_systems_init
    mov x1, x0
    
    adrp x0, memory_test_result
    add x0, x0, :lo12:memory_test_result
    str w1, [x0]
    
    adrp x0, memory_test_msg
    add x0, x0, :lo12:memory_test_msg
    bl log_test_result_with_message
    
    RESTORE_REGS_LIGHT
    ret

test_core_systems:
    SAVE_REGS_LIGHT
    
    bl core_systems_init
    mov x1, x0
    
    adrp x0, core_test_result
    add x0, x0, :lo12:core_test_result
    str w1, [x0]
    
    adrp x0, core_test_msg
    add x0, x0, :lo12:core_test_msg
    bl log_test_result_with_message
    
    RESTORE_REGS_LIGHT
    ret

test_graphics_systems:
    SAVE_REGS_LIGHT
    
    bl graphics_init
    mov x1, x0
    
    adrp x0, graphics_test_result
    add x0, x0, :lo12:graphics_test_result
    str w1, [x0]
    
    adrp x0, graphics_test_msg
    add x0, x0, :lo12:graphics_test_msg
    bl log_test_result_with_message
    
    RESTORE_REGS_LIGHT
    ret

test_simulation_systems:
    SAVE_REGS_LIGHT
    
    bl simulation_init
    mov x1, x0
    
    adrp x0, simulation_test_result
    add x0, x0, :lo12:simulation_test_result
    str w1, [x0]
    
    adrp x0, simulation_test_msg
    add x0, x0, :lo12:simulation_test_msg
    bl log_test_result_with_message
    
    RESTORE_REGS_LIGHT
    ret

test_ai_systems:
    SAVE_REGS_LIGHT
    
    bl ai_systems_init
    mov x1, x0
    
    adrp x0, ai_test_result
    add x0, x0, :lo12:ai_test_result
    str w1, [x0]
    
    adrp x0, ai_test_msg
    add x0, x0, :lo12:ai_test_msg
    bl log_test_result_with_message
    
    RESTORE_REGS_LIGHT
    ret

test_io_systems:
    SAVE_REGS_LIGHT
    
    bl io_systems_init
    mov x1, x0
    
    adrp x0, io_test_result
    add x0, x0, :lo12:io_test_result
    str w1, [x0]
    
    adrp x0, io_test_msg
    add x0, x0, :lo12:io_test_msg
    bl log_test_result_with_message
    
    RESTORE_REGS_LIGHT
    ret

test_audio_systems:
    SAVE_REGS_LIGHT
    
    bl audio_init
    mov x1, x0
    
    adrp x0, audio_test_result
    add x0, x0, :lo12:audio_test_result
    str w1, [x0]
    
    adrp x0, audio_test_msg
    add x0, x0, :lo12:audio_test_msg
    bl log_test_result_with_message
    
    RESTORE_REGS_LIGHT
    ret

test_ui_systems:
    SAVE_REGS_LIGHT
    
    bl ui_init
    mov x1, x0
    
    adrp x0, ui_test_result
    add x0, x0, :lo12:ui_test_result
    str w1, [x0]
    
    adrp x0, ui_test_msg
    add x0, x0, :lo12:ui_test_msg
    bl log_test_result_with_message
    
    RESTORE_REGS_LIGHT
    ret

test_full_integration:
    SAVE_REGS_LIGHT
    
    // Test a minimal game loop iteration
    bl test_game_loop_iteration
    mov x1, x0
    
    adrp x0, integration_test_result
    add x0, x0, :lo12:integration_test_result
    str w1, [x0]
    
    adrp x0, integration_msg
    add x0, x0, :lo12:integration_msg
    bl log_test_result_with_message
    
    RESTORE_REGS_LIGHT
    ret

test_game_loop_iteration:
    SAVE_REGS_LIGHT
    
    // Test one iteration of key game loop functions
    bl process_input_events
    bl simulation_update
    bl ai_update
    bl audio_update
    bl render_frame
    bl ui_update
    bl calculate_frame_time
    
    // If we got here without crashing, it's a success
    mov x0, #0
    
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Test Result Utilities
//==============================================================================

log_test_result_with_message:
    // Args: x0 = message, x1 = result (0=pass, non-zero=fail)
    SAVE_REGS_LIGHT
    
    mov x19, x0  // Save message
    mov x20, x1  // Save result
    
    // Output message
    mov x0, x19
    bl output_string
    
    // Output result
    cbnz x20, log_fail_result
    
    // Log PASS
    adrp x0, test_pass_msg
    add x0, x0, :lo12:test_pass_msg
    bl output_string
    b log_result_done

log_fail_result:
    // Log FAIL
    adrp x0, test_fail_msg
    add x0, x0, :lo12:test_fail_msg
    bl output_string

log_result_done:
    RESTORE_REGS_LIGHT
    ret

display_test_results:
    SAVE_REGS_LIGHT
    
    // Count passed tests
    bl count_passed_tests
    mov x19, x0  // Save passed count
    
    // Count total tests
    mov x20, #9  // Total number of tests
    
    // Log summary
    adrp x0, test_complete_msg
    add x0, x0, :lo12:test_complete_msg
    bl output_string
    
    RESTORE_REGS_LIGHT
    ret

count_passed_tests:
    SAVE_REGS_LIGHT
    
    mov x19, #0  // Counter
    
    // Check each test result
    adrp x0, test_results
    add x0, x0, :lo12:test_results
    
    mov x1, #9  // Number of tests
count_loop:
    ldr w2, [x0], #4
    cbnz w2, count_skip
    add x19, x19, #1  // Increment if passed (0)
count_skip:
    subs x1, x1, #1
    b.ne count_loop
    
    mov x0, x19  // Return count
    RESTORE_REGS_LIGHT
    ret

check_overall_success:
    SAVE_REGS_LIGHT
    
    bl count_passed_tests
    cmp x0, #9  // All tests must pass
    b.eq all_tests_passed
    
    // Some tests failed
    mov x0, #1
    b check_success_done

all_tests_passed:
    mov x0, #0

check_success_done:
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Test Entry Point for External Use
//==============================================================================

.global test_main_initialization
test_main_initialization:
    // Entry point that can be called from build system
    SAVE_REGS
    
    bl run_main_init_tests
    bl check_overall_success
    
    // Return 0 for success, 1 for failure
    RESTORE_REGS
    ret