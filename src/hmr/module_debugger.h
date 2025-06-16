/*
 * SimCity ARM64 - Module Debugging System
 * Comprehensive debugging capabilities with ARM64 assembly breakpoints
 * 
 * Created by Agent 1: Core Module System
 * Week 3, Day 13 - Development Productivity Enhancement
 */

#ifndef HMR_MODULE_DEBUGGER_H
#define HMR_MODULE_DEBUGGER_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <signal.h>
#include <sys/ptrace.h>
#include <mach/mach.h>

// Debugging system configuration
#define DEBUG_MAX_BREAKPOINTS           256
#define DEBUG_MAX_WATCHPOINTS           64
#define DEBUG_MAX_STACK_FRAMES          1024
#define DEBUG_MAX_VARIABLES             512
#define DEBUG_MAX_LOG_ENTRIES           10000
#define DEBUG_ASSEMBLY_CONTEXT_LINES    10

// Forward declarations
typedef struct hmr_debug_context hmr_debug_context_t;
typedef struct hmr_agent_module hmr_agent_module_t;

// Breakpoint types
typedef enum {
    BREAKPOINT_NONE = 0,
    BREAKPOINT_SOFTWARE,                // Software breakpoint (brk instruction)
    BREAKPOINT_HARDWARE,                // Hardware breakpoint (ARM debug registers)
    BREAKPOINT_WATCHPOINT_READ,         // Memory read watchpoint
    BREAKPOINT_WATCHPOINT_WRITE,        // Memory write watchpoint
    BREAKPOINT_WATCHPOINT_ACCESS,       // Memory access watchpoint
    BREAKPOINT_CONDITIONAL,             // Conditional breakpoint
    BREAKPOINT_TEMPORARY,               // One-time breakpoint
    BREAKPOINT_ASSEMBLY_STEP,           // Single assembly instruction step
    BREAKPOINT_FUNCTION_ENTRY,          // Function entry breakpoint
    BREAKPOINT_FUNCTION_EXIT            // Function exit breakpoint
} debug_breakpoint_type_t;

// Breakpoint condition types
typedef enum {
    CONDITION_NONE = 0,
    CONDITION_REGISTER_EQUALS,          // Register value equals
    CONDITION_REGISTER_NOT_EQUALS,      // Register value not equals
    CONDITION_REGISTER_GREATER,         // Register value greater than
    CONDITION_REGISTER_LESS,            // Register value less than
    CONDITION_MEMORY_EQUALS,            // Memory value equals
    CONDITION_MEMORY_CHANGED,           // Memory value changed
    CONDITION_CALL_COUNT,               // Function call count
    CONDITION_CUSTOM_EXPRESSION         // Custom expression evaluation
} debug_condition_type_t;

// ARM64 register identifiers
typedef enum {
    ARM64_REG_X0 = 0, ARM64_REG_X1, ARM64_REG_X2, ARM64_REG_X3,
    ARM64_REG_X4, ARM64_REG_X5, ARM64_REG_X6, ARM64_REG_X7,
    ARM64_REG_X8, ARM64_REG_X9, ARM64_REG_X10, ARM64_REG_X11,
    ARM64_REG_X12, ARM64_REG_X13, ARM64_REG_X14, ARM64_REG_X15,
    ARM64_REG_X16, ARM64_REG_X17, ARM64_REG_X18, ARM64_REG_X19,
    ARM64_REG_X20, ARM64_REG_X21, ARM64_REG_X22, ARM64_REG_X23,
    ARM64_REG_X24, ARM64_REG_X25, ARM64_REG_X26, ARM64_REG_X27,
    ARM64_REG_X28, ARM64_REG_X29, ARM64_REG_X30, ARM64_REG_SP,
    ARM64_REG_PC, ARM64_REG_PSTATE,
    ARM64_REG_V0, ARM64_REG_V1, ARM64_REG_V2, ARM64_REG_V3,
    ARM64_REG_V4, ARM64_REG_V5, ARM64_REG_V6, ARM64_REG_V7,
    ARM64_REG_V8, ARM64_REG_V9, ARM64_REG_V10, ARM64_REG_V11,
    ARM64_REG_V12, ARM64_REG_V13, ARM64_REG_V14, ARM64_REG_V15,
    ARM64_REG_V16, ARM64_REG_V17, ARM64_REG_V18, ARM64_REG_V19,
    ARM64_REG_V20, ARM64_REG_V21, ARM64_REG_V22, ARM64_REG_V23,
    ARM64_REG_V24, ARM64_REG_V25, ARM64_REG_V26, ARM64_REG_V27,
    ARM64_REG_V28, ARM64_REG_V29, ARM64_REG_V30, ARM64_REG_V31,
    ARM64_REG_COUNT
} arm64_register_t;

// Debugging condition structure
typedef struct {
    debug_condition_type_t type;        // Condition type
    arm64_register_t register_id;       // Register to check (if applicable)
    void* memory_address;               // Memory address to watch
    uint64_t expected_value;            // Expected value for comparison
    uint64_t tolerance;                 // Tolerance for numeric comparisons
    uint32_t call_count_threshold;      // Call count threshold
    char custom_expression[256];        // Custom expression string
    bool is_active;                     // Whether condition is active
} debug_condition_t;

// Breakpoint structure
typedef struct {
    uint32_t id;                        // Unique breakpoint ID
    debug_breakpoint_type_t type;       // Breakpoint type
    void* address;                      // Target address
    hmr_agent_module_t* module;         // Associated module
    uint32_t original_instruction;      // Original instruction (for software BP)
    debug_condition_t condition;        // Breakpoint condition
    uint32_t hit_count;                 // Number of times hit
    uint64_t timestamp_created;         // When breakpoint was created
    uint64_t timestamp_last_hit;        // Last hit timestamp
    bool is_enabled;                    // Whether breakpoint is active
    bool is_temporary;                  // Remove after first hit
    char description[128];              // Human-readable description
} debug_breakpoint_t;

// Stack frame information
typedef struct {
    void* frame_pointer;                // Frame pointer (x29)
    void* return_address;               // Return address
    void* function_start;               // Function start address
    char function_name[64];             // Function name (if available)
    hmr_agent_module_t* module;         // Module containing this frame
    uint32_t frame_size;                // Frame size in bytes
    uint32_t local_variable_count;      // Number of local variables
} debug_stack_frame_t;

// Variable information
typedef struct {
    char name[64];                      // Variable name
    void* address;                      // Memory address
    uint32_t size;                      // Size in bytes
    uint32_t type;                      // Type identifier
    uint64_t value;                     // Current value
    char value_string[256];             // String representation
} debug_variable_t;

// Debug log entry
typedef struct {
    uint64_t timestamp;                 // Timestamp
    uint32_t level;                     // Log level (0=trace, 1=debug, 2=info, 3=warn, 4=error)
    hmr_agent_module_t* module;         // Source module
    void* address;                      // Code address
    char message[512];                  // Log message
} debug_log_entry_t;

// ARM64 processor state
typedef struct {
    uint64_t x_registers[31];           // X0-X30 general purpose registers
    uint64_t sp;                        // Stack pointer
    uint64_t pc;                        // Program counter
    uint64_t pstate;                    // Processor state
    __uint128_t v_registers[32];        // V0-V31 NEON registers
    uint64_t fpcr;                      // Floating-point control register
    uint64_t fpsr;                      // Floating-point status register
} arm64_processor_state_t;

// Debugging session information
typedef struct {
    uint32_t session_id;                // Unique session ID
    pid_t target_process;               // Target process ID
    mach_port_t task_port;              // Mach task port for debugging
    bool is_attached;                   // Whether debugger is attached
    bool is_running;                    // Whether target is running
    bool single_step_mode;              // Single step debugging mode
    arm64_processor_state_t cpu_state;  // Current CPU state
    void* current_pc;                   // Current program counter
    uint32_t current_instruction;       // Current instruction
    char disassembly[512];              // Disassembled current instruction
} debug_session_t;

// Main debugging context
typedef struct hmr_debug_context {
    // Breakpoint management
    debug_breakpoint_t breakpoints[DEBUG_MAX_BREAKPOINTS];
    uint32_t breakpoint_count;
    uint32_t next_breakpoint_id;
    
    // Session management
    debug_session_t session;
    bool debugging_enabled;
    bool symbol_info_loaded;
    
    // Stack and variable tracking
    debug_stack_frame_t stack_frames[DEBUG_MAX_STACK_FRAMES];
    uint32_t stack_frame_count;
    debug_variable_t variables[DEBUG_MAX_VARIABLES];
    uint32_t variable_count;
    
    // Logging
    debug_log_entry_t log_entries[DEBUG_MAX_LOG_ENTRIES];
    uint32_t log_entry_count;
    uint32_t log_entry_index;           // Circular buffer index
    
    // Module integration
    hmr_agent_module_t** debugged_modules;
    uint32_t debugged_module_count;
    
    // Signal handling
    struct sigaction old_sigtrap_handler;
    struct sigaction old_sigsegv_handler;
    
    // Performance monitoring
    uint64_t debug_overhead_ns;         // Debugging overhead
    uint64_t breakpoint_hit_count;      // Total breakpoint hits
    uint64_t single_steps_executed;     // Single steps executed
    
    // Configuration
    bool auto_symbol_resolution;       // Automatically resolve symbols
    bool trace_function_calls;         // Trace all function calls
    bool trace_memory_access;          // Trace memory access
    uint32_t max_stack_depth;          // Maximum stack trace depth
    
    // Threading
    pthread_mutex_t debug_mutex;       // Thread safety
    pthread_t debug_thread;            // Background debugging thread
    bool debug_thread_running;         // Debug thread status
} hmr_debug_context_t;

// Debugging commands for interactive debugger
typedef enum {
    DEBUG_CMD_CONTINUE,                 // Continue execution
    DEBUG_CMD_STEP_OVER,                // Step over (single instruction)
    DEBUG_CMD_STEP_INTO,                // Step into function calls
    DEBUG_CMD_STEP_OUT,                 // Step out of current function
    DEBUG_CMD_SET_BREAKPOINT,           // Set breakpoint
    DEBUG_CMD_REMOVE_BREAKPOINT,        // Remove breakpoint
    DEBUG_CMD_LIST_BREAKPOINTS,         // List all breakpoints
    DEBUG_CMD_EXAMINE_MEMORY,           // Examine memory contents
    DEBUG_CMD_EXAMINE_REGISTERS,        // Examine CPU registers
    DEBUG_CMD_EXAMINE_STACK,            // Examine call stack
    DEBUG_CMD_EXAMINE_VARIABLES,        // Examine local variables
    DEBUG_CMD_DISASSEMBLE,              // Disassemble code
    DEBUG_CMD_PRINT_LOGS,               // Print debug logs
    DEBUG_CMD_SET_WATCHPOINT,           // Set memory watchpoint
    DEBUG_CMD_EVALUATE_EXPRESSION,      // Evaluate expression
    DEBUG_CMD_ATTACH_MODULE,            // Attach to specific module
    DEBUG_CMD_DETACH_MODULE             // Detach from module
} debug_command_t;

// API Functions
#ifdef __cplusplus
extern "C" {
#endif

// Debugger initialization and cleanup
int32_t debug_init_system(hmr_debug_context_t** ctx);
int32_t debug_shutdown_system(hmr_debug_context_t* ctx);
int32_t debug_attach_to_process(hmr_debug_context_t* ctx, pid_t pid);
int32_t debug_attach_to_module(hmr_debug_context_t* ctx, hmr_agent_module_t* module);
int32_t debug_detach(hmr_debug_context_t* ctx);

// Breakpoint management
int32_t debug_set_breakpoint(hmr_debug_context_t* ctx, void* address, 
                            debug_breakpoint_type_t type, const char* description);
int32_t debug_set_conditional_breakpoint(hmr_debug_context_t* ctx, void* address,
                                        debug_condition_t* condition, const char* description);
int32_t debug_remove_breakpoint(hmr_debug_context_t* ctx, uint32_t breakpoint_id);
int32_t debug_enable_breakpoint(hmr_debug_context_t* ctx, uint32_t breakpoint_id);
int32_t debug_disable_breakpoint(hmr_debug_context_t* ctx, uint32_t breakpoint_id);
int32_t debug_list_breakpoints(hmr_debug_context_t* ctx, debug_breakpoint_t** breakpoints,
                              uint32_t* count);

// Execution control
int32_t debug_continue_execution(hmr_debug_context_t* ctx);
int32_t debug_single_step(hmr_debug_context_t* ctx);
int32_t debug_step_over(hmr_debug_context_t* ctx);
int32_t debug_step_into(hmr_debug_context_t* ctx);
int32_t debug_step_out(hmr_debug_context_t* ctx);
int32_t debug_pause_execution(hmr_debug_context_t* ctx);

// State examination
int32_t debug_get_processor_state(hmr_debug_context_t* ctx, arm64_processor_state_t* state);
int32_t debug_set_register_value(hmr_debug_context_t* ctx, arm64_register_t reg, uint64_t value);
int32_t debug_get_register_value(hmr_debug_context_t* ctx, arm64_register_t reg, uint64_t* value);
int32_t debug_read_memory(hmr_debug_context_t* ctx, void* address, void* buffer, size_t size);
int32_t debug_write_memory(hmr_debug_context_t* ctx, void* address, const void* buffer, size_t size);

// Stack and variable inspection
int32_t debug_get_stack_trace(hmr_debug_context_t* ctx, debug_stack_frame_t** frames, uint32_t* count);
int32_t debug_get_local_variables(hmr_debug_context_t* ctx, uint32_t frame_index,
                                 debug_variable_t** variables, uint32_t* count);
int32_t debug_evaluate_variable(hmr_debug_context_t* ctx, const char* variable_name,
                               debug_variable_t* result);

// Code analysis
int32_t debug_disassemble_instruction(hmr_debug_context_t* ctx, void* address,
                                     char* disassembly, size_t buffer_size);
int32_t debug_disassemble_function(hmr_debug_context_t* ctx, void* function_start,
                                  char** disassembly, uint32_t* line_count);
int32_t debug_find_function_bounds(hmr_debug_context_t* ctx, void* address,
                                  void** start, void** end);

// Symbol resolution
int32_t debug_resolve_symbol(hmr_debug_context_t* ctx, void* address, char* symbol_name,
                            size_t buffer_size);
int32_t debug_find_symbol_address(hmr_debug_context_t* ctx, const char* symbol_name,
                                 void** address);
int32_t debug_load_symbol_information(hmr_debug_context_t* ctx, hmr_agent_module_t* module);

// Logging and tracing
int32_t debug_log_message(hmr_debug_context_t* ctx, uint32_t level, hmr_agent_module_t* module,
                         void* address, const char* format, ...);
int32_t debug_get_log_entries(hmr_debug_context_t* ctx, debug_log_entry_t** entries,
                             uint32_t* count);
int32_t debug_clear_log(hmr_debug_context_t* ctx);

// Interactive debugging
int32_t debug_execute_command(hmr_debug_context_t* ctx, debug_command_t command,
                             const char* parameters, char* result, size_t result_size);
int32_t debug_start_interactive_session(hmr_debug_context_t* ctx);

// Performance monitoring
int32_t debug_get_performance_metrics(hmr_debug_context_t* ctx, uint64_t* metrics,
                                     uint32_t metric_count);
void debug_reset_performance_counters(hmr_debug_context_t* ctx);

// Utility functions
const char* debug_breakpoint_type_to_string(debug_breakpoint_type_t type);
const char* debug_register_to_string(arm64_register_t reg);
bool debug_is_valid_address(hmr_debug_context_t* ctx, void* address);

#ifdef __cplusplus
}
#endif

// Debugging macros for module development
#define DEBUG_BREAK_HERE(ctx) \
    debug_set_breakpoint(ctx, __builtin_return_address(0), BREAKPOINT_SOFTWARE, __func__)

#define DEBUG_LOG_TRACE(ctx, module, ...) \
    debug_log_message(ctx, 0, module, __builtin_return_address(0), __VA_ARGS__)

#define DEBUG_LOG_DEBUG(ctx, module, ...) \
    debug_log_message(ctx, 1, module, __builtin_return_address(0), __VA_ARGS__)

#define DEBUG_LOG_INFO(ctx, module, ...) \
    debug_log_message(ctx, 2, module, __builtin_return_address(0), __VA_ARGS__)

#define DEBUG_LOG_WARN(ctx, module, ...) \
    debug_log_message(ctx, 3, module, __builtin_return_address(0), __VA_ARGS__)

#define DEBUG_LOG_ERROR(ctx, module, ...) \
    debug_log_message(ctx, 4, module, __builtin_return_address(0), __VA_ARGS__)

#define DEBUG_ASSERT(ctx, condition, module, ...) \
    do { \
        if (!(condition)) { \
            debug_log_message(ctx, 4, module, __builtin_return_address(0), \
                            "Assertion failed: %s - " __VA_ARGS__, #condition); \
            debug_set_breakpoint(ctx, __builtin_return_address(0), BREAKPOINT_SOFTWARE, \
                                "Assertion failure"); \
        } \
    } while(0)

// Error codes
#define DEBUG_SUCCESS                   0
#define DEBUG_ERROR_INVALID_CONTEXT     -1
#define DEBUG_ERROR_INVALID_ADDRESS     -2
#define DEBUG_ERROR_BREAKPOINT_EXISTS   -3
#define DEBUG_ERROR_BREAKPOINT_NOT_FOUND -4
#define DEBUG_ERROR_ATTACH_FAILED       -5
#define DEBUG_ERROR_NOT_ATTACHED        -6
#define DEBUG_ERROR_INVALID_REGISTER    -7
#define DEBUG_ERROR_MEMORY_ACCESS       -8
#define DEBUG_ERROR_SYMBOL_NOT_FOUND    -9
#define DEBUG_ERROR_INSUFFICIENT_BUFFER -10
#define DEBUG_ERROR_UNSUPPORTED_ARCH    -11
#define DEBUG_ERROR_PERMISSION_DENIED   -12

#endif // HMR_MODULE_DEBUGGER_H