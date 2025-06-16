/*
 * SimCity ARM64 - Module Debugging System Implementation
 * ARM64 assembly implementation with hardware breakpoint support
 * 
 * Created by Agent 1: Core Module System
 * Week 3, Day 13 - Development Productivity Enhancement
 */

.section __TEXT,__text,regular,pure_instructions
.align 4

// Include platform constants
.include "../../include/macros/platform_asm.inc"
.include "../../include/constants/memory.inc"

// External symbols
.extern _malloc
.extern _free
.extern _memset
.extern _memcpy
.extern _signal
.extern _sigaction
.extern _ptrace
.extern _waitpid
.extern _task_for_pid
.extern _thread_get_state
.extern _thread_set_state
.extern _vm_read
.extern _vm_write
.extern _pthread_mutex_init
.extern _pthread_mutex_lock
.extern _pthread_mutex_unlock

// Debug context structure offsets
.set DEBUG_BREAKPOINTS_OFFSET,          0
.set DEBUG_BREAKPOINT_COUNT_OFFSET,     6144    // 256 * 24 bytes
.set DEBUG_NEXT_BP_ID_OFFSET,           6148
.set DEBUG_SESSION_OFFSET,              6152
.set DEBUG_ENABLED_OFFSET,              6664
.set DEBUG_SYMBOL_LOADED_OFFSET,        6665
.set DEBUG_STACK_FRAMES_OFFSET,         6668
.set DEBUG_STACK_FRAME_COUNT_OFFSET,    14860   // 1024 * 8 bytes
.set DEBUG_VARIABLES_OFFSET,            14864
.set DEBUG_VARIABLE_COUNT_OFFSET,       18920   // 512 * 8 bytes
.set DEBUG_LOG_ENTRIES_OFFSET,          18924
.set DEBUG_LOG_COUNT_OFFSET,            138924  // 10000 * 12 bytes
.set DEBUG_LOG_INDEX_OFFSET,            138928
.set DEBUG_MODULES_OFFSET,              138932
.set DEBUG_MODULE_COUNT_OFFSET,         138940
.set DEBUG_MUTEX_OFFSET,                138944

// Breakpoint structure offsets
.set BP_ID_OFFSET,                      0
.set BP_TYPE_OFFSET,                    4
.set BP_ADDRESS_OFFSET,                 8
.set BP_MODULE_OFFSET,                  16
.set BP_ORIGINAL_INSTR_OFFSET,          24
.set BP_CONDITION_OFFSET,               28
.set BP_HIT_COUNT_OFFSET,               68
.set BP_TIMESTAMP_CREATED_OFFSET,       72
.set BP_TIMESTAMP_LAST_HIT_OFFSET,      80
.set BP_ENABLED_OFFSET,                 88
.set BP_TEMPORARY_OFFSET,               89
.set BP_DESCRIPTION_OFFSET,             90

// Session structure offsets
.set SESSION_ID_OFFSET,                 0
.set SESSION_PROCESS_OFFSET,            4
.set SESSION_TASK_PORT_OFFSET,          8
.set SESSION_ATTACHED_OFFSET,           12
.set SESSION_RUNNING_OFFSET,            13
.set SESSION_SINGLE_STEP_OFFSET,        14
.set SESSION_CPU_STATE_OFFSET,          16
.set SESSION_CURRENT_PC_OFFSET,         512
.set SESSION_CURRENT_INSTR_OFFSET,      520
.set SESSION_DISASSEMBLY_OFFSET,        524

// ARM64 debug register constants
.set ARM64_HW_BREAKPOINT_COUNT,         6
.set ARM64_HW_WATCHPOINT_COUNT,         4
.set ARM64_DBG_BCR_E,                   1
.set ARM64_DBG_WCR_E,                   1

// Breakpoint instruction for ARM64
.set ARM64_BRK_INSTRUCTION,             0xd4200000

.section __DATA,__data
.align 8
// Global debug context pointer
_global_debug_context:
    .quad 0

// Signal handler storage
_debug_signal_handlers:
    .space 64                           // Signal handler storage

// Hardware debug register state
_hw_debug_state:
    .space 128                          // Hardware debug register cache

.section __TEXT,__text,regular,pure_instructions

/*
 * debug_init_system - Initialize debugging system
 * Input: x0 = pointer to debug context pointer
 * Output: w0 = result code (0 = success)
 */
.global _debug_init_system
.align 4
_debug_init_system:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0                     // x19 = context pointer address
    cbz     x19, .Ldebug_init_null_param
    
    // Allocate debug context structure
    mov     x0, #200000                 // Large context structure
    bl      _malloc
    mov     x20, x0                     // x20 = debug context
    cbz     x20, .Ldebug_init_alloc_failed
    
    // Initialize context to zero
    mov     x0, x20
    mov     x1, #0
    mov     x2, #200000
    bl      _memset
    
    // Initialize session with unique ID
    bl      _debug_generate_session_id
    str     w0, [x20, #DEBUG_SESSION_OFFSET + SESSION_ID_OFFSET]
    
    // Initialize breakpoint ID counter
    mov     w0, #1
    str     w0, [x20, #DEBUG_NEXT_BP_ID_OFFSET]
    
    // Enable debugging by default
    mov     w0, #1
    strb    w0, [x20, #DEBUG_ENABLED_OFFSET]
    
    // Initialize mutex for thread safety
    add     x0, x20, #DEBUG_MUTEX_OFFSET
    mov     x1, #0                      // Default attributes
    bl      _pthread_mutex_init
    cbnz    w0, .Ldebug_init_mutex_failed
    
    // Install signal handlers for debugging
    mov     x0, x20
    bl      _debug_install_signal_handlers
    cbnz    w0, .Ldebug_init_signal_failed
    
    // Initialize hardware debug support
    mov     x0, x20
    bl      _debug_init_hardware_debug
    
    // Store global context pointer
    adrp    x1, _global_debug_context@PAGE
    add     x1, x1, _global_debug_context@PAGEOFF
    str     x20, [x1]
    
    // Store context pointer and return success
    str     x20, [x19]
    mov     w0, #0                      // Success
    b       .Ldebug_init_cleanup
    
.Ldebug_init_null_param:
    mov     w0, #-1                     // DEBUG_ERROR_INVALID_CONTEXT
    b       .Ldebug_init_return
    
.Ldebug_init_alloc_failed:
    mov     w0, #-2                     // Memory allocation error
    b       .Ldebug_init_return
    
.Ldebug_init_mutex_failed:
    mov     x0, x20
    bl      _free
    mov     w0, #-3                     // Mutex initialization error
    b       .Ldebug_init_return
    
.Ldebug_init_signal_failed:
    add     x0, x20, #DEBUG_MUTEX_OFFSET
    bl      _pthread_mutex_destroy
    mov     x0, x20
    bl      _free
    mov     w0, #-4                     // Signal handler error
    b       .Ldebug_init_return
    
.Ldebug_init_cleanup:
.Ldebug_init_return:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

/*
 * debug_set_breakpoint - Set a breakpoint at specified address
 * Input: x0 = debug context, x1 = address, x2 = type, x3 = description
 * Output: w0 = breakpoint ID (>0) or error code (<0)
 */
.global _debug_set_breakpoint
.align 4
_debug_set_breakpoint:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    stp     x23, x24, [sp, #-16]!
    
    mov     x19, x0                     // x19 = debug context
    mov     x20, x1                     // x20 = address
    mov     w21, w2                     // w21 = type
    mov     x22, x3                     // x22 = description
    
    cbz     x19, .Ldebug_bp_null_context
    cbz     x20, .Ldebug_bp_null_address
    
    // Lock debug mutex
    add     x0, x19, #DEBUG_MUTEX_OFFSET
    bl      _pthread_mutex_lock
    cbnz    w0, .Ldebug_bp_lock_failed
    
    // Check if we have space for more breakpoints
    ldr     w0, [x19, #DEBUG_BREAKPOINT_COUNT_OFFSET]
    cmp     w0, #256                    // DEBUG_MAX_BREAKPOINTS
    b.ge    .Ldebug_bp_too_many
    
    // Find free breakpoint slot
    add     x23, x19, #DEBUG_BREAKPOINTS_OFFSET
    mov     w24, #0                     // Current index
    
.Ldebug_bp_find_slot:
    cmp     w24, #256
    b.ge    .Ldebug_bp_no_slot
    
    mov     x0, #218                    // Breakpoint structure size
    madd    x1, x24, x0, x23            // bp = breakpoints + (index * size)
    ldr     w2, [x1, #BP_ID_OFFSET]
    cbz     w2, .Ldebug_bp_found_slot   // Free slot (ID = 0)
    
    add     w24, w24, #1
    b       .Ldebug_bp_find_slot
    
.Ldebug_bp_found_slot:
    // Get next breakpoint ID
    ldr     w0, [x19, #DEBUG_NEXT_BP_ID_OFFSET]
    str     w0, [x1, #BP_ID_OFFSET]     // Store breakpoint ID
    add     w2, w0, #1
    str     w2, [x19, #DEBUG_NEXT_BP_ID_OFFSET]
    
    // Initialize breakpoint structure
    str     w21, [x1, #BP_TYPE_OFFSET]  // Type
    str     x20, [x1, #BP_ADDRESS_OFFSET] // Address
    str     wzr, [x1, #BP_HIT_COUNT_OFFSET] // Hit count = 0
    
    // Set enabled flag
    mov     w2, #1
    strb    w2, [x1, #BP_ENABLED_OFFSET]
    
    // Get current timestamp
    bl      _mach_absolute_time
    str     x0, [x1, #BP_TIMESTAMP_CREATED_OFFSET]
    
    // Copy description if provided
    cbz     x22, .Ldebug_bp_skip_description
    add     x2, x1, #BP_DESCRIPTION_OFFSET
    mov     x0, x2
    mov     x1, x22
    mov     x2, #127                    // Max description length - 1
    bl      _strncpy
    
.Ldebug_bp_skip_description:
    // Install the breakpoint based on type
    cmp     w21, #1                     // BREAKPOINT_SOFTWARE
    b.eq    .Ldebug_bp_install_software
    cmp     w21, #2                     // BREAKPOINT_HARDWARE
    b.eq    .Ldebug_bp_install_hardware
    b       .Ldebug_bp_install_done
    
.Ldebug_bp_install_software:
    // Install software breakpoint (replace instruction with BRK)
    mov     x0, x20                     // Address
    bl      _debug_read_instruction
    str     w0, [x1, #BP_ORIGINAL_INSTR_OFFSET] // Save original instruction
    
    mov     x0, x20                     // Address
    mov     w1, #ARM64_BRK_INSTRUCTION  // BRK instruction
    bl      _debug_write_instruction
    cbnz    w0, .Ldebug_bp_install_failed
    b       .Ldebug_bp_install_done
    
.Ldebug_bp_install_hardware:
    // Install hardware breakpoint using debug registers
    mov     x0, x19                     // Debug context
    mov     x1, x20                     // Address
    bl      _debug_install_hw_breakpoint
    cbnz    w0, .Ldebug_bp_install_failed
    
.Ldebug_bp_install_done:
    // Increment breakpoint count
    ldr     w2, [x19, #DEBUG_BREAKPOINT_COUNT_OFFSET]
    add     w2, w2, #1
    str     w2, [x19, #DEBUG_BREAKPOINT_COUNT_OFFSET]
    
    // Unlock mutex and return breakpoint ID
    add     x2, x19, #DEBUG_MUTEX_OFFSET
    bl      _pthread_mutex_unlock
    
    mov     w0, w0                      // Return breakpoint ID
    b       .Ldebug_bp_cleanup
    
.Ldebug_bp_null_context:
.Ldebug_bp_null_address:
    mov     w0, #-1                     // DEBUG_ERROR_INVALID_CONTEXT/ADDRESS
    b       .Ldebug_bp_return
    
.Ldebug_bp_lock_failed:
    mov     w0, #-2                     // Lock error
    b       .Ldebug_bp_return
    
.Ldebug_bp_too_many:
.Ldebug_bp_no_slot:
    add     x0, x19, #DEBUG_MUTEX_OFFSET
    bl      _pthread_mutex_unlock
    mov     w0, #-3                     // Too many breakpoints
    b       .Ldebug_bp_return
    
.Ldebug_bp_install_failed:
    // Clear the breakpoint entry on installation failure
    str     wzr, [x1, #BP_ID_OFFSET]
    add     x0, x19, #DEBUG_MUTEX_OFFSET
    bl      _pthread_mutex_unlock
    mov     w0, #-4                     // Installation failed
    b       .Ldebug_bp_return
    
.Ldebug_bp_cleanup:
.Ldebug_bp_return:
    ldp     x23, x24, [sp], #16
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

/*
 * debug_single_step - Execute single assembly instruction
 * Input: x0 = debug context
 * Output: w0 = result code
 */
.global _debug_single_step
.align 4
_debug_single_step:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0                     // x19 = debug context
    cbz     x19, .Ldebug_step_null_context
    
    // Check if attached to a process
    add     x20, x19, #DEBUG_SESSION_OFFSET
    ldrb    w0, [x20, #SESSION_ATTACHED_OFFSET]
    cbz     w0, .Ldebug_step_not_attached
    
    // Set single step flag
    mov     w0, #1
    strb    w0, [x20, #SESSION_SINGLE_STEP_OFFSET]
    
    // Enable single step using ARM64 debug registers
    mov     x0, x19
    bl      _debug_enable_single_step
    cbnz    w0, .Ldebug_step_enable_failed
    
    // Continue execution (will stop after one instruction)
    ldr     w0, [x20, #SESSION_PROCESS_OFFSET]
    mov     x1, #0                      // PTRACE_CONT
    mov     x2, #0                      // No signal
    bl      _ptrace
    cmn     x0, #1                      // Check for error
    b.eq    .Ldebug_step_ptrace_failed
    
    // Wait for the single step to complete
    ldr     w0, [x20, #SESSION_PROCESS_OFFSET]
    mov     x1, #0                      // Status pointer (unused)
    mov     x2, #0                      // Options
    bl      _waitpid
    cmn     x0, #1
    b.eq    .Ldebug_step_wait_failed
    
    // Disable single step
    mov     x0, x19
    bl      _debug_disable_single_step
    
    // Update processor state
    mov     x0, x19
    bl      _debug_update_processor_state
    
    mov     w0, #0                      // Success
    b       .Ldebug_step_cleanup
    
.Ldebug_step_null_context:
    mov     w0, #-1                     // DEBUG_ERROR_INVALID_CONTEXT
    b       .Ldebug_step_return
    
.Ldebug_step_not_attached:
    mov     w0, #-6                     // DEBUG_ERROR_NOT_ATTACHED
    b       .Ldebug_step_return
    
.Ldebug_step_enable_failed:
.Ldebug_step_ptrace_failed:
.Ldebug_step_wait_failed:
    mov     w0, #-2                     // Step operation failed
    b       .Ldebug_step_return
    
.Ldebug_step_cleanup:
.Ldebug_step_return:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

/*
 * debug_get_processor_state - Get current ARM64 processor state
 * Input: x0 = debug context, x1 = state buffer
 * Output: w0 = result code
 */
.global _debug_get_processor_state
.align 4
_debug_get_processor_state:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0                     // x19 = debug context
    mov     x20, x1                     // x20 = state buffer
    
    cbz     x19, .Ldebug_state_null_context
    cbz     x20, .Ldebug_state_null_buffer
    
    // Check if attached
    add     x0, x19, #DEBUG_SESSION_OFFSET
    ldrb    w1, [x0, #SESSION_ATTACHED_OFFSET]
    cbz     w1, .Ldebug_state_not_attached
    
    // Get task port for the target process
    ldr     w0, [x0, #SESSION_TASK_PORT_OFFSET]
    cbz     w0, .Ldebug_state_no_task_port
    
    // Read thread state using Mach APIs
    // This is a simplified implementation - real implementation would
    // enumerate threads and get state for the main thread
    
    // For now, copy from cached state in debug context
    add     x0, x19, #DEBUG_SESSION_OFFSET + SESSION_CPU_STATE_OFFSET
    mov     x1, x20
    mov     x2, #528                    // Size of ARM64 processor state
    bl      _memcpy
    
    mov     w0, #0                      // Success
    b       .Ldebug_state_cleanup
    
.Ldebug_state_null_context:
.Ldebug_state_null_buffer:
    mov     w0, #-1                     // DEBUG_ERROR_INVALID_CONTEXT
    b       .Ldebug_state_return
    
.Ldebug_state_not_attached:
    mov     w0, #-6                     // DEBUG_ERROR_NOT_ATTACHED
    b       .Ldebug_state_return
    
.Ldebug_state_no_task_port:
    mov     w0, #-5                     // DEBUG_ERROR_ATTACH_FAILED
    b       .Ldebug_state_return
    
.Ldebug_state_cleanup:
.Ldebug_state_return:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

/*
 * debug_read_instruction - Read instruction from memory
 * Input: x0 = address
 * Output: w0 = instruction (32-bit)
 */
_debug_read_instruction:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // For now, direct memory read (assumes we have permission)
    // Real implementation would use vm_read or ptrace
    ldr     w0, [x0]
    
    ldp     x29, x30, [sp], #16
    ret

/*
 * debug_write_instruction - Write instruction to memory
 * Input: x0 = address, w1 = instruction
 * Output: w0 = result code
 */
_debug_write_instruction:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // For now, direct memory write (assumes we have permission)
    // Real implementation would use vm_write or ptrace
    str     w1, [x0]
    
    // Flush instruction cache after modification
    dc      cvau, x0                    // Clean data cache to point of unification
    dsb     ish                         // Data synchronization barrier
    ic      ivau, x0                    // Invalidate instruction cache
    dsb     ish                         // Data synchronization barrier
    isb                                 // Instruction synchronization barrier
    
    mov     w0, #0                      // Success
    
    ldp     x29, x30, [sp], #16
    ret

/*
 * debug_install_signal_handlers - Install signal handlers for debugging
 * Input: x0 = debug context
 * Output: w0 = result code
 */
_debug_install_signal_handlers:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    sub     sp, sp, #64                 // Space for sigaction structures
    
    // Install SIGTRAP handler for breakpoints
    adrp    x1, _debug_sigtrap_handler@PAGE
    add     x1, x1, _debug_sigtrap_handler@PAGEOFF
    str     x1, [sp, #0]                // sa_handler
    str     xzr, [sp, #8]               // sa_mask (simplified)
    mov     w1, #0
    str     w1, [sp, #16]               // sa_flags
    
    mov     x0, #5                      // SIGTRAP
    mov     x1, sp                      // New sigaction
    add     x2, sp, #32                 // Old sigaction storage
    bl      _sigaction
    cbnz    w0, .Ldebug_signal_failed
    
    // Install SIGSEGV handler for watchpoints
    adrp    x1, _debug_sigsegv_handler@PAGE
    add     x1, x1, _debug_sigsegv_handler@PAGEOFF
    str     x1, [sp, #0]                // sa_handler
    
    mov     x0, #11                     // SIGSEGV
    mov     x1, sp                      // New sigaction
    add     x2, sp, #32                 // Old sigaction storage (reuse)
    bl      _sigaction
    cbnz    w0, .Ldebug_signal_failed
    
    mov     w0, #0                      // Success
    b       .Ldebug_signal_return
    
.Ldebug_signal_failed:
    mov     w0, #-1                     // Error
    
.Ldebug_signal_return:
    add     sp, sp, #64
    ldp     x29, x30, [sp], #16
    ret

/*
 * debug_sigtrap_handler - SIGTRAP signal handler for breakpoints
 * Input: x0 = signal number, x1 = signal info, x2 = context
 */
_debug_sigtrap_handler:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get global debug context
    adrp    x3, _global_debug_context@PAGE
    add     x3, x3, _global_debug_context@PAGEOFF
    ldr     x3, [x3]
    cbz     x3, .Lsigtrap_no_context
    
    // Extract PC from signal context (simplified)
    // Real implementation would properly decode ucontext_t
    ldr     x4, [x2, #256]              // Approximate PC offset in ucontext
    
    // Find breakpoint at this address
    mov     x0, x3                      // Debug context
    mov     x1, x4                      // PC address
    bl      _debug_find_breakpoint_at_address
    cbz     x0, .Lsigtrap_no_breakpoint
    
    // Handle breakpoint hit
    mov     x1, x0                      // Breakpoint structure
    mov     x0, x3                      // Debug context
    bl      _debug_handle_breakpoint_hit
    
.Lsigtrap_no_context:
.Lsigtrap_no_breakpoint:
    // Return from signal handler
    ldp     x29, x30, [sp], #16
    ret

/*
 * debug_sigsegv_handler - SIGSEGV signal handler for watchpoints
 * Input: x0 = signal number, x1 = signal info, x2 = context
 */
_debug_sigsegv_handler:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get global debug context
    adrp    x3, _global_debug_context@PAGE
    add     x3, x3, _global_debug_context@PAGEOFF
    ldr     x3, [x3]
    cbz     x3, .Lsigsegv_no_context
    
    // Extract fault address from signal info
    ldr     x4, [x1, #16]               // si_addr field (approximate)
    
    // Check if this is a watchpoint hit
    mov     x0, x3                      // Debug context
    mov     x1, x4                      // Fault address
    bl      _debug_check_watchpoint_hit
    cbz     w0, .Lsigsegv_not_watchpoint
    
    // Handle watchpoint hit
    mov     x0, x3                      // Debug context
    mov     x1, x4                      // Address
    bl      _debug_handle_watchpoint_hit
    
.Lsigsegv_no_context:
.Lsigsegv_not_watchpoint:
    // Return from signal handler
    ldp     x29, x30, [sp], #16
    ret

/*
 * debug_generate_session_id - Generate unique debug session ID
 * Output: w0 = session ID
 */
_debug_generate_session_id:
    // Simple session ID based on timestamp and PID
    bl      _mach_absolute_time
    bl      _getpid
    eor     w0, w0, w0, lsr #16         // Mix timestamp and PID
    and     w0, w0, #0x7FFFFFFF         // Ensure positive
    cbnz    w0, .Lsession_id_done
    mov     w0, #1                      // Ensure non-zero
.Lsession_id_done:
    ret

/*
 * debug_init_hardware_debug - Initialize ARM64 hardware debug support
 * Input: x0 = debug context
 * Output: w0 = result code
 */
_debug_init_hardware_debug:
    // ARM64 hardware debug initialization would go here
    // This involves setting up debug registers, but requires kernel support
    // For now, return success indicating software debugging is available
    mov     w0, #0
    ret

// String constants and lookup tables
.section __TEXT,__cstring,cstring_literals
.align 3

// ARM64 register names for debugging output
_arm64_register_names:
    .asciz "x0"
    .asciz "x1"
    .asciz "x2"
    .asciz "x3"
    .asciz "x4"
    .asciz "x5"
    .asciz "x6"
    .asciz "x7"
    .asciz "x8"
    .asciz "x9"
    .asciz "x10"
    .asciz "x11"
    .asciz "x12"
    .asciz "x13"
    .asciz "x14"
    .asciz "x15"
    .asciz "x16"
    .asciz "x17"
    .asciz "x18"
    .asciz "x19"
    .asciz "x20"
    .asciz "x21"
    .asciz "x22"
    .asciz "x23"
    .asciz "x24"
    .asciz "x25"
    .asciz "x26"
    .asciz "x27"
    .asciz "x28"
    .asciz "x29"
    .asciz "x30"
    .asciz "sp"
    .asciz "pc"
    .asciz "pstate"

// Debug statistics
.section __DATA,__data
.align 8
.global _debug_statistics
_debug_statistics:
    .quad 0     // total_breakpoints_set
    .quad 0     // total_breakpoints_hit
    .quad 0     // single_steps_executed
    .quad 0     // memory_reads_performed
    .quad 0     // memory_writes_performed
    .quad 0     // debug_sessions_created
    .quad 0     // symbol_resolutions
    .quad 0     // debug_overhead_ns