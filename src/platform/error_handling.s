//
// SimCity ARM64 Assembly - Error Handling and Logging System
// Sub-Agent 1: Main Application Architect
//
// Comprehensive error handling and logging for the main application
//

.include "../include/macros/platform_asm.inc"

.section .data
.align 4

// Error logging state
error_log_state:
    log_initialized:        .word 0
    log_level:              .word 2         // 0=error, 1=warn, 2=info, 3=debug
    error_count:            .word 0
    last_error_code:        .word 0
    stdout_fd:              .word 1
    stderr_fd:              .word 2

// Error message templates
error_messages:
    platform_init_fail:     .asciz "PLATFORM_INIT_FAILED: "
    memory_init_fail:        .asciz "MEMORY_INIT_FAILED: "
    graphics_init_fail:      .asciz "GRAPHICS_INIT_FAILED: "
    simulation_init_fail:    .asciz "SIMULATION_INIT_FAILED: "
    ai_init_fail:           .asciz "AI_INIT_FAILED: "
    io_init_fail:           .asciz "IO_INIT_FAILED: "
    audio_init_fail:        .asciz "AUDIO_INIT_FAILED: "
    ui_init_fail:           .asciz "UI_INIT_FAILED: "
    core_init_fail:         .asciz "CORE_INIT_FAILED: "
    unknown_error:          .asciz "UNKNOWN_ERROR: "

// Log level strings
log_level_strings:
    error_str:              .asciz "[ERROR] "
    warn_str:               .asciz "[WARN]  "
    info_str:               .asciz "[INFO]  "
    debug_str:              .asciz "[DEBUG] "

// Newline and formatting
newline:                    .asciz "\n"
separator:                  .asciz " - "
timestamp_buffer:           .space 32
message_buffer:             .space 256

.section .text
.align 4

//==============================================================================
// Error Handling System Initialization
//==============================================================================

.global error_system_init
error_system_init:
    SAVE_REGS_LIGHT
    
    // Initialize error logging system
    adrp x0, error_log_state
    add x0, x0, :lo12:error_log_state
    
    // Check if already initialized
    ldr w1, [x0]
    cbnz w1, error_init_done
    
    // Mark as initialized
    mov w1, #1
    str w1, [x0]
    
    // Reset error counters
    str wzr, [x0, #8]   // error_count = 0
    str wzr, [x0, #12]  // last_error_code = 0
    
    // Log initialization
    mov x0, #2  // Info level
    adrp x1, init_message
    add x1, x1, :lo12:init_message
    bl log_message
    
error_init_done:
    mov x0, #0  // Success
    RESTORE_REGS_LIGHT
    ret

init_message: .asciz "Error handling system initialized"

//==============================================================================
// Core Error Logging Functions
//==============================================================================

.global log_error
log_error:
    // Args: x0 = error_code, x1 = message
    mov x2, #0  // Error level
    b log_with_level

.global log_warning
log_warning:
    // Args: x0 = message
    mov x1, x0
    mov x0, #0
    mov x2, #1  // Warning level
    b log_with_level

.global log_info
log_info:
    // Args: x0 = message
    mov x1, x0
    mov x0, #0
    mov x2, #2  // Info level
    b log_with_level

.global log_debug
log_debug:
    // Args: x0 = message
    mov x1, x0
    mov x0, #0
    mov x2, #3  // Debug level
    b log_with_level

log_with_level:
    // Args: x0 = error_code, x1 = message, x2 = level
    SAVE_REGS
    
    mov x19, x0  // Save error_code
    mov x20, x1  // Save message
    mov x21, x2  // Save level
    
    // Check if we should log this level
    adrp x0, error_log_state
    add x0, x0, :lo12:error_log_state
    ldr w0, [x0, #4]  // Load log_level
    cmp w21, w0
    b.gt log_skip  // Skip if message level > configured level
    
    // Update error count if this is an error
    cbnz w21, skip_error_count
    adrp x0, error_log_state
    add x0, x0, :lo12:error_log_state
    ldr w1, [x0, #8]  // Load error_count
    add w1, w1, #1
    str w1, [x0, #8]  // Store incremented count
    str w19, [x0, #12]  // Store last_error_code

skip_error_count:
    // Format and output log message
    mov x0, x21  // level
    mov x1, x19  // error_code
    mov x2, x20  // message
    bl format_and_output_log

log_skip:
    RESTORE_REGS
    ret

//==============================================================================
// Message Formatting and Output
//==============================================================================

format_and_output_log:
    // Args: x0 = level, x1 = error_code, x2 = message
    SAVE_REGS
    
    mov x19, x0  // Save level
    mov x20, x1  // Save error_code
    mov x21, x2  // Save message
    
    // Output level prefix
    mov x0, x19
    bl output_level_prefix
    
    // Output timestamp
    bl output_timestamp
    
    // Output separator
    adrp x0, separator
    add x0, x0, :lo12:separator
    bl output_string
    
    // Output error code if non-zero
    cbnz x20, output_error_code
    b output_message_part

output_error_code:
    mov x0, x20
    bl output_hex_number
    
    adrp x0, separator
    add x0, x0, :lo12:separator
    bl output_string

output_message_part:
    // Output the message
    mov x0, x21
    bl output_string
    
    // Output newline
    adrp x0, newline
    add x0, x0, :lo12:newline
    bl output_string
    
    RESTORE_REGS
    ret

output_level_prefix:
    // Args: x0 = level (0=error, 1=warn, 2=info, 3=debug)
    SAVE_REGS_LIGHT
    
    cmp x0, #3
    b.gt use_debug_prefix
    
    // Calculate offset into level strings
    mov x1, #8  // Each string is 8 bytes
    mul x0, x0, x1
    adrp x1, log_level_strings
    add x1, x1, :lo12:log_level_strings
    add x0, x1, x0
    
    bl output_string
    b level_prefix_done

use_debug_prefix:
    adrp x0, debug_str
    add x0, x0, :lo12:debug_str
    bl output_string

level_prefix_done:
    RESTORE_REGS_LIGHT
    ret

output_timestamp:
    // Simple timestamp - just use cycle counter for now
    SAVE_REGS_LIGHT
    
    mrs x0, cntvct_el0
    bl output_hex_number
    
    RESTORE_REGS_LIGHT
    ret

output_string:
    // Args: x0 = string pointer
    SAVE_REGS_LIGHT
    
    mov x19, x0  // Save string pointer
    
    // Calculate string length
    bl strlen
    mov x2, x0   // length
    mov x1, x19  // string
    
    // Choose output descriptor based on level
    adrp x0, error_log_state
    add x0, x0, :lo12:error_log_state
    ldr w0, [x0, #20]  // Load stderr_fd (use stderr for all logs for now)
    
    // Write to descriptor
    SYSCALL SYS_WRITE
    
    RESTORE_REGS_LIGHT
    ret

output_hex_number:
    // Args: x0 = number to output in hex
    SAVE_REGS
    
    mov x19, x0  // Save number
    
    // Convert to hex string in message_buffer
    adrp x20, message_buffer
    add x20, x20, :lo12:message_buffer
    
    // Add "0x" prefix
    mov w0, #'0'
    strb w0, [x20]
    mov w0, #'x'
    strb w0, [x20, #1]
    add x20, x20, #2
    
    // Convert 16 hex digits
    mov x21, #16
    mov x22, #60  // Start with bit 60 (16*4-4)

hex_digit_loop:
    lsr x0, x19, x22
    and x0, x0, #0xF
    
    cmp x0, #10
    b.lt hex_digit_numeric
    
    // Hex digit A-F
    add x0, x0, #('A' - 10)
    b store_hex_digit

hex_digit_numeric:
    // Hex digit 0-9
    add x0, x0, #'0'

store_hex_digit:
    strb w0, [x20], #1
    sub x22, x22, #4
    subs x21, x21, #1
    b.ne hex_digit_loop
    
    // Null terminate and output
    strb wzr, [x20]
    
    adrp x0, message_buffer
    add x0, x0, :lo12:message_buffer
    bl output_string
    
    RESTORE_REGS
    ret

strlen:
    // Args: x0 = string pointer
    // Returns: x0 = length
    mov x1, x0
    mov x0, #0

strlen_loop:
    ldrb w2, [x1, x0]
    cbz w2, strlen_done
    add x0, x0, #1
    b strlen_loop

strlen_done:
    ret

//==============================================================================
// Specialized Error Handlers
//==============================================================================

.global handle_platform_error
handle_platform_error:
    // Args: x0 = specific error code
    SAVE_REGS_LIGHT
    
    mov x1, x0  // Save specific error
    mov x0, #0x1000  // Platform error base
    add x0, x0, x1   // Combined error code
    
    adrp x1, platform_init_fail
    add x1, x1, :lo12:platform_init_fail
    bl log_error
    
    RESTORE_REGS_LIGHT
    ret

.global handle_memory_error
handle_memory_error:
    SAVE_REGS_LIGHT
    
    mov x1, x0
    mov x0, #0x2000
    add x0, x0, x1
    
    adrp x1, memory_init_fail
    add x1, x1, :lo12:memory_init_fail
    bl log_error
    
    RESTORE_REGS_LIGHT
    ret

.global handle_graphics_error
handle_graphics_error:
    SAVE_REGS_LIGHT
    
    mov x1, x0
    mov x0, #0x3000
    add x0, x0, x1
    
    adrp x1, graphics_init_fail
    add x1, x1, :lo12:graphics_init_fail
    bl log_error
    
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Error Recovery Functions
//==============================================================================

.global attempt_error_recovery
attempt_error_recovery:
    // Args: x0 = error_type, x1 = error_code
    SAVE_REGS_LIGHT
    
    // For now, just log the recovery attempt
    mov x2, x1
    mov x1, x0
    mov x0, #0x9000  // Recovery attempt base
    add x0, x0, x1
    
    adrp x1, recovery_message
    add x1, x1, :lo12:recovery_message
    bl log_info
    
    // Always return failure for now (no actual recovery)
    mov x0, #1
    
    RESTORE_REGS_LIGHT
    ret

recovery_message: .asciz "Attempting error recovery"

.global get_error_count
get_error_count:
    adrp x0, error_log_state
    add x0, x0, :lo12:error_log_state
    ldr w0, [x0, #8]  // Load error_count
    ret

.global get_last_error
get_last_error:
    adrp x0, error_log_state
    add x0, x0, :lo12:error_log_state
    ldr w0, [x0, #12]  // Load last_error_code
    ret

.global clear_error_state
clear_error_state:
    adrp x0, error_log_state
    add x0, x0, :lo12:error_log_state
    str wzr, [x0, #8]   // error_count = 0
    str wzr, [x0, #12]  // last_error_code = 0
    ret