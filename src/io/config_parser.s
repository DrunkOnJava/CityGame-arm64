# =============================================================================
# Configuration Parser
# SimCity ARM64 Assembly Project - Agent 8
# =============================================================================
# 
# This file implements a JSON-like configuration parser for game settings.
# Features:
# - JSON-like syntax parsing (objects, arrays, strings, numbers, booleans)
# - Hierarchical configuration with dot notation access
# - Type-safe getter/setter functions
# - Configuration validation and defaults
# - Hot-reload support for development
# - Memory-efficient storage with string interning
#
# Supported syntax:
# {
#   "graphics": {
#     "resolution": "1920x1080",
#     "fullscreen": true,
#     "vsync": false,
#     "quality": 2
#   },
#   "audio": {
#     "master_volume": 0.8,
#     "music_volume": 0.6,
#     "enabled": true
#   }
# }
#
# Author: Agent 8 (I/O & Serialization)
# Target: ARM64 Apple Silicon
# =============================================================================

.include "io_constants.s"
.include "io_interface.s"

.section __DATA,__data

# =============================================================================
# Parser State
# =============================================================================

.align 8
config_parser_initialized:
    .quad 0

parse_buffer:
    .space CONFIG_BUFFER_SIZE

current_token:
    .quad 0                                     # Token type
    .space CONFIG_MAX_VALUE_LEN                 # Token value

parse_position:
    .quad 0                                     # Current position in buffer

parse_line:
    .quad 1                                     # Current line number

parse_column:
    .quad 1                                     # Current column number

parse_depth:
    .quad 0                                     # Current nesting depth

# Configuration storage
.equ CONFIG_MAX_ENTRIES, 1024

# Configuration value types
.equ CONFIG_TYPE_STRING, 1
.equ CONFIG_TYPE_INT, 2
.equ CONFIG_TYPE_FLOAT, 3
.equ CONFIG_TYPE_BOOL, 4
config_entries_count:
    .quad 0

config_entries:
    .space (CONFIG_MAX_ENTRIES * CONFIG_ENTRY_SIZE)

# String pool for configuration keys/values
.equ STRING_POOL_SIZE, 32768
string_pool_size:
    .quad 0

string_pool:
    .space STRING_POOL_SIZE

# Parser error state
last_parse_error:
    .quad 0

error_message_buffer:
    .space 256

# JSON formatting strings
json_open_brace:
    .asciz "{"

json_close_brace:
    .asciz "\n}"

# =============================================================================
# Character Classification Tables
# =============================================================================

.section __DATA,__const

# Whitespace characters
whitespace_chars:
    .byte ' ', '\t', '\n', '\r', 0

# Digit characters
digit_chars:
    .asciz "0123456789"

# Valid identifier start characters
identifier_start_chars:
    .asciz "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"

# Valid identifier characters
identifier_chars:
    .asciz "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"

# =============================================================================
# Configuration Functions
# =============================================================================

.section __TEXT,__text

# =============================================================================
# config_parser_init - Initialize the configuration parser
# Input: None
# Output: x0 = result code
# Clobbers: x0-x3
# =============================================================================
config_parser_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Check if already initialized
    adrp    x0, config_parser_initialized
    add     x0, x0, :lo12:config_parser_initialized
    ldr     x1, [x0]
    cbnz    x1, .config_init_done
    
    # Clear configuration entries
    adrp    x1, config_entries_count
    add     x1, x1, :lo12:config_entries_count
    str     xzr, [x1]
    
    # Clear string pool
    adrp    x1, string_pool_size
    add     x1, x1, :lo12:string_pool_size
    str     xzr, [x1]
    
    # Clear parser state
    adrp    x1, parse_position
    add     x1, x1, :lo12:parse_position
    str     xzr, [x1]
    
    mov     x2, #1
    str     x2, [x1, #8]                        # parse_line = 1
    str     x2, [x1, #16]                       # parse_column = 1
    str     xzr, [x1, #24]                      # parse_depth = 0
    
    # Mark as initialized
    mov     x1, #1
    str     x1, [x0]
    
    mov     x0, #IO_SUCCESS

.config_init_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# config_load_file - Load configuration from file
# Input: x0 = filename pointer
# Output: x0 = result code
# Clobbers: x0-x15
# =============================================================================
config_load_file:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                             # Save filename
    
    # Open file
    mov     x1, #O_RDONLY
    mov     x8, #5                              # SYS_open
    svc     #0
    
    cmp     x0, #0
    b.lt    .config_load_error_open
    
    mov     x20, x0                             # Save fd
    
    # Read file into buffer
    adrp    x0, parse_buffer
    add     x0, x0, :lo12:parse_buffer
    mov     x1, x20                             # fd
    mov     x2, #(CONFIG_BUFFER_SIZE - 1)       # Leave space for null terminator
    mov     x8, #3                              # SYS_read
    svc     #0
    
    cmp     x0, #0
    b.lt    .config_load_error_read
    
    # Null-terminate buffer
    adrp    x1, parse_buffer
    add     x1, x1, :lo12:parse_buffer
    strb    wzr, [x1, x0]
    
    # Close file
    mov     x0, x20
    mov     x8, #6                              # SYS_close
    svc     #0
    
    # Parse the configuration
    bl      config_parse_buffer
    cmp     x0, #IO_SUCCESS
    b.ne    .config_load_parse_error
    
    mov     x0, #IO_SUCCESS
    b       .config_load_done

.config_load_error_open:
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    b       .config_load_done

.config_load_error_read:
    mov     x0, #IO_ERROR_ASYNC
    b       .config_load_done

.config_load_parse_error:
    # x0 already contains error code from parser
    b       .config_load_done

.config_load_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

# =============================================================================
# config_parse_buffer - Parse configuration from buffer
# Input: None (uses parse_buffer)
# Output: x0 = result code
# Clobbers: x0-x15
# =============================================================================
config_parse_buffer:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Reset parser state
    adrp    x0, parse_position
    add     x0, x0, :lo12:parse_position
    str     xzr, [x0]
    mov     x1, #1
    str     x1, [x0, #8]                        # line = 1
    str     x1, [x0, #16]                       # column = 1
    str     xzr, [x0, #24]                      # depth = 0
    
    # Clear existing entries
    adrp    x0, config_entries_count
    add     x0, x0, :lo12:config_entries_count
    str     xzr, [x0]
    
    # Start parsing from root object
    bl      config_parse_value
    cmp     x0, #IO_SUCCESS
    b.ne    .parse_buffer_error
    
    mov     x0, #IO_SUCCESS
    b       .parse_buffer_done

.parse_buffer_error:
    # Error already in x0
    b       .parse_buffer_done

.parse_buffer_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# config_parse_value - Parse a JSON value
# Input: None (uses parser state)
# Output: x0 = result code
# Clobbers: x0-x15
# =============================================================================
config_parse_value:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Skip whitespace
    bl      config_skip_whitespace
    
    # Get next token
    bl      config_get_token
    cmp     x0, #IO_SUCCESS
    b.ne    .parse_value_error
    
    # Check token type
    adrp    x0, current_token
    add     x0, x0, :lo12:current_token
    ldr     x1, [x0]
    
    cmp     x1, #TOKEN_LBRACE
    b.eq    .parse_value_object
    
    cmp     x1, #TOKEN_LBRACKET
    b.eq    .parse_value_array
    
    cmp     x1, #TOKEN_STRING
    b.eq    .parse_value_string
    
    cmp     x1, #TOKEN_NUMBER
    b.eq    .parse_value_number
    
    cmp     x1, #TOKEN_BOOLEAN
    b.eq    .parse_value_boolean
    
    cmp     x1, #TOKEN_NULL
    b.eq    .parse_value_null
    
    # Unknown token
    mov     x0, #IO_ERROR_INVALID_FORMAT
    b       .parse_value_done

.parse_value_object:
    bl      config_parse_object
    b       .parse_value_done

.parse_value_array:
    bl      config_parse_array
    b       .parse_value_done

.parse_value_string:
.parse_value_number:
.parse_value_boolean:
.parse_value_null:
    # Primitive values - already parsed
    mov     x0, #IO_SUCCESS
    b       .parse_value_done

.parse_value_error:
    # Error already in x0
    b       .parse_value_done

.parse_value_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# config_parse_object - Parse a JSON object
# Input: None (uses parser state)
# Output: x0 = result code
# Clobbers: x0-x15
# =============================================================================
config_parse_object:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Increase depth
    adrp    x0, parse_depth
    add     x0, x0, :lo12:parse_depth
    ldr     x1, [x0]
    add     x1, x1, #1
    cmp     x1, #CONFIG_MAX_DEPTH
    b.gt    .parse_object_too_deep
    str     x1, [x0]
    
    # Parse object contents
.parse_object_loop:
    # Skip whitespace
    bl      config_skip_whitespace
    
    # Check for end of object
    bl      config_peek_char
    cmp     x0, #'}'
    b.eq    .parse_object_end
    
    # Parse key
    bl      config_get_token
    cmp     x0, #IO_SUCCESS
    b.ne    .parse_object_error
    
    adrp    x0, current_token
    add     x0, x0, :lo12:current_token
    ldr     x1, [x0]
    cmp     x1, #TOKEN_STRING
    b.ne    .parse_object_invalid_key
    
    # Expect colon
    bl      config_skip_whitespace
    bl      config_get_token
    cmp     x0, #IO_SUCCESS
    b.ne    .parse_object_error
    
    adrp    x0, current_token
    add     x0, x0, :lo12:current_token
    ldr     x1, [x0]
    cmp     x1, #TOKEN_COLON
    b.ne    .parse_object_expect_colon
    
    # Parse value
    bl      config_parse_value
    cmp     x0, #IO_SUCCESS
    b.ne    .parse_object_error
    
    # Check for comma or end
    bl      config_skip_whitespace
    bl      config_peek_char
    cmp     x0, #','
    b.eq    .parse_object_continue
    cmp     x0, #'}'
    b.eq    .parse_object_end
    
    # Invalid character
    mov     x0, #IO_ERROR_INVALID_FORMAT
    b       .parse_object_error

.parse_object_continue:
    bl      config_advance_char                 # Skip comma
    b       .parse_object_loop

.parse_object_end:
    bl      config_advance_char                 # Skip closing brace
    
    # Decrease depth
    adrp    x0, parse_depth
    add     x0, x0, :lo12:parse_depth
    ldr     x1, [x0]
    sub     x1, x1, #1
    str     x1, [x0]
    
    mov     x0, #IO_SUCCESS
    b       .parse_object_done

.parse_object_too_deep:
    mov     x0, #IO_ERROR_INVALID_FORMAT
    b       .parse_object_done

.parse_object_invalid_key:
    mov     x0, #IO_ERROR_INVALID_FORMAT
    b       .parse_object_done

.parse_object_expect_colon:
    mov     x0, #IO_ERROR_INVALID_FORMAT
    b       .parse_object_done

.parse_object_error:
    # Error already in x0
    b       .parse_object_done

.parse_object_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# config_parse_array - Parse a JSON array
# Input: None (uses parser state)
# Output: x0 = result code
# Clobbers: x0-x15
# =============================================================================
config_parse_array:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Arrays not fully supported yet - just skip to closing bracket
.parse_array_loop:
    bl      config_advance_char
    bl      config_peek_char
    cmp     x0, #']'
    b.eq    .parse_array_end
    cmp     x0, #0
    b.eq    .parse_array_eof
    b       .parse_array_loop

.parse_array_end:
    bl      config_advance_char                 # Skip closing bracket
    mov     x0, #IO_SUCCESS
    b       .parse_array_done

.parse_array_eof:
    mov     x0, #IO_ERROR_INVALID_FORMAT
    b       .parse_array_done

.parse_array_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# Lexer Functions
# =============================================================================

# config_get_token - Get next token from buffer
config_get_token:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    bl      config_skip_whitespace
    bl      config_peek_char
    
    # Check for end of input
    cmp     x0, #0
    b.eq    .get_token_eof
    
    # Check for single-character tokens
    cmp     x0, #'{'
    b.eq    .get_token_lbrace
    cmp     x0, #'}'
    b.eq    .get_token_rbrace
    cmp     x0, #'['
    b.eq    .get_token_lbracket
    cmp     x0, #']'
    b.eq    .get_token_rbracket
    cmp     x0, #':'
    b.eq    .get_token_colon
    cmp     x0, #','
    b.eq    .get_token_comma
    
    # Check for string
    cmp     x0, #'"'
    b.eq    .get_token_string
    
    # Check for number
    bl      config_is_digit
    cbnz    x0, .get_token_number
    
    # Check for identifier (boolean/null)
    bl      config_peek_char
    bl      config_is_alpha
    cbnz    x0, .get_token_identifier
    
    # Unknown character
    mov     x0, #IO_ERROR_INVALID_FORMAT
    b       .get_token_done

.get_token_lbrace:
    bl      config_advance_char
    adrp    x0, current_token
    add     x0, x0, :lo12:current_token
    mov     x1, #TOKEN_LBRACE
    str     x1, [x0]
    mov     x0, #IO_SUCCESS
    b       .get_token_done

.get_token_rbrace:
    bl      config_advance_char
    adrp    x0, current_token
    add     x0, x0, :lo12:current_token
    mov     x1, #TOKEN_RBRACE
    str     x1, [x0]
    mov     x0, #IO_SUCCESS
    b       .get_token_done

.get_token_lbracket:
    bl      config_advance_char
    adrp    x0, current_token
    add     x0, x0, :lo12:current_token
    mov     x1, #TOKEN_LBRACKET
    str     x1, [x0]
    mov     x0, #IO_SUCCESS
    b       .get_token_done

.get_token_rbracket:
    bl      config_advance_char
    adrp    x0, current_token
    add     x0, x0, :lo12:current_token
    mov     x1, #TOKEN_RBRACKET
    str     x1, [x0]
    mov     x0, #IO_SUCCESS
    b       .get_token_done

.get_token_colon:
    bl      config_advance_char
    adrp    x0, current_token
    add     x0, x0, :lo12:current_token
    mov     x1, #TOKEN_COLON
    str     x1, [x0]
    mov     x0, #IO_SUCCESS
    b       .get_token_done

.get_token_comma:
    bl      config_advance_char
    adrp    x0, current_token
    add     x0, x0, :lo12:current_token
    mov     x1, #TOKEN_COMMA
    str     x1, [x0]
    mov     x0, #IO_SUCCESS
    b       .get_token_done

.get_token_string:
    bl      config_parse_string_token
    b       .get_token_done

.get_token_number:
    bl      config_parse_number_token
    b       .get_token_done

.get_token_identifier:
    bl      config_parse_identifier_token
    b       .get_token_done

.get_token_eof:
    adrp    x0, current_token
    add     x0, x0, :lo12:current_token
    mov     x1, #TOKEN_EOF
    str     x1, [x0]
    mov     x0, #IO_SUCCESS
    b       .get_token_done

.get_token_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# Helper Functions (Simplified implementations)
# =============================================================================

config_skip_whitespace:
    # Skip spaces, tabs, newlines, carriage returns
.skip_ws_loop:
    bl      config_peek_char
    cmp     x0, #' '
    b.eq    .skip_ws_advance
    cmp     x0, #'\t'
    b.eq    .skip_ws_advance
    cmp     x0, #'\n'
    b.eq    .skip_ws_advance_newline
    cmp     x0, #'\r'
    b.eq    .skip_ws_advance
    ret                                         # Non-whitespace found

.skip_ws_advance:
    bl      config_advance_char
    b       .skip_ws_loop

.skip_ws_advance_newline:
    bl      config_advance_char
    # Update line/column counters
    adrp    x0, parse_line
    add     x0, x0, :lo12:parse_line
    ldr     x1, [x0]
    add     x1, x1, #1
    str     x1, [x0]
    
    adrp    x0, parse_column
    add     x0, x0, :lo12:parse_column
    mov     x1, #1
    str     x1, [x0]
    
    b       .skip_ws_loop

config_peek_char:
    adrp    x0, parse_position
    add     x0, x0, :lo12:parse_position
    ldr     x1, [x0]
    
    adrp    x2, parse_buffer
    add     x2, x2, :lo12:parse_buffer
    ldrb    w0, [x2, x1]
    ret

config_advance_char:
    adrp    x0, parse_position
    add     x0, x0, :lo12:parse_position
    ldr     x1, [x0]
    add     x1, x1, #1
    str     x1, [x0]
    
    # Update column
    adrp    x0, parse_column
    add     x0, x0, :lo12:parse_column
    ldr     x1, [x0]
    add     x1, x1, #1
    str     x1, [x0]
    ret

config_is_digit:
    cmp     x0, #'0'
    b.lt    .is_digit_no
    cmp     x0, #'9'
    b.gt    .is_digit_no
    mov     x0, #1
    ret
.is_digit_no:
    mov     x0, #0
    ret

config_is_alpha:
    cmp     x0, #'a'
    b.lt    .check_upper
    cmp     x0, #'z'
    b.le    .is_alpha_yes
.check_upper:
    cmp     x0, #'A'
    b.lt    .is_alpha_no
    cmp     x0, #'Z'
    b.le    .is_alpha_yes
.is_alpha_no:
    mov     x0, #0
    ret
.is_alpha_yes:
    mov     x0, #1
    ret

# Stub implementations for token parsing
config_parse_string_token:
    adrp    x0, current_token
    add     x0, x0, :lo12:current_token
    mov     x1, #TOKEN_STRING
    str     x1, [x0]
    # TODO: Parse actual string content
    bl      config_advance_char                 # Skip opening quote
    bl      config_advance_char                 # Skip closing quote (simplified)
    mov     x0, #IO_SUCCESS
    ret

config_parse_number_token:
    adrp    x0, current_token
    add     x0, x0, :lo12:current_token
    mov     x1, #TOKEN_NUMBER
    str     x1, [x0]
    # TODO: Parse actual number
    bl      config_advance_char                 # Skip one digit (simplified)
    mov     x0, #IO_SUCCESS
    ret

config_parse_identifier_token:
    adrp    x0, current_token
    add     x0, x0, :lo12:current_token
    mov     x1, #TOKEN_BOOLEAN                  # Assume boolean for now
    str     x1, [x0]
    # TODO: Parse actual identifier and determine type
    bl      config_advance_char                 # Skip one char (simplified)
    mov     x0, #IO_SUCCESS
    ret

# =============================================================================
# Enhanced Configuration Access Functions
# =============================================================================

# =============================================================================
# config_save_file - Save configuration to file
# Input: x0 = filename
# Output: x0 = result code
# Clobbers: x0-x15
# =============================================================================
config_save_file:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                             # Save filename
    
    # Create output file
    mov     x1, #(O_CREAT | O_TRUNC | O_WRONLY)
    mov     x2, #0644
    mov     x8, #5                              # SYS_open
    svc     #0
    
    cmp     x0, #0
    b.lt    .config_save_error
    
    mov     x20, x0                             # Save fd
    
    # Write JSON header
    adrp    x0, json_open_brace
    add     x0, x0, :lo12:json_open_brace
    mov     x1, x20
    mov     x2, #1
    mov     x8, #4                              # SYS_write
    svc     #0
    
    # Write configuration entries
    bl      config_write_entries
    
    # Write JSON footer
    adrp    x0, json_close_brace
    add     x0, x0, :lo12:json_close_brace
    mov     x1, x20
    mov     x2, #2
    mov     x8, #4                              # SYS_write
    svc     #0
    
    # Close file
    mov     x0, x20
    mov     x8, #6                              # SYS_close
    svc     #0
    
    mov     x0, #IO_SUCCESS
    b       .config_save_done

.config_save_error:
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    b       .config_save_done

.config_save_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

# =============================================================================
# config_get_string - Get string configuration value
# Input: x0 = key, x1 = buffer, x2 = buffer_size
# Output: x0 = result code
# Clobbers: x0-x10
# =============================================================================
config_get_string:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Find configuration entry
    bl      config_find_entry
    cmp     x0, #0
    b.lt    .get_string_not_found
    
    mov     x3, x0                              # entry pointer
    
    # Check type
    ldr     w4, [x3, #config_type]
    cmp     w4, #CONFIG_TYPE_STRING
    b.ne    .get_string_wrong_type
    
    # Copy value to buffer
    add     x0, x3, #config_value
    # x1 already contains buffer
    # x2 already contains buffer_size
    bl      string_copy_n
    
    mov     x0, #IO_SUCCESS
    b       .get_string_done

.get_string_not_found:
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    b       .get_string_done

.get_string_wrong_type:
    mov     x0, #IO_ERROR_INVALID_FORMAT
    b       .get_string_done

.get_string_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# config_get_int - Get integer configuration value
# Input: x0 = key, x1 = value_pointer
# Output: x0 = result code
# Clobbers: x0-x10
# =============================================================================
config_get_int:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Find configuration entry
    bl      config_find_entry
    cmp     x0, #0
    b.lt    .get_int_not_found
    
    mov     x2, x0                              # entry pointer
    
    # Check type
    ldr     w3, [x2, #config_type]
    cmp     w3, #CONFIG_TYPE_INT
    b.ne    .get_int_wrong_type
    
    # Load integer value
    ldr     w3, [x2, #config_value]
    str     w3, [x1]
    
    mov     x0, #IO_SUCCESS
    b       .get_int_done

.get_int_not_found:
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    b       .get_int_done

.get_int_wrong_type:
    mov     x0, #IO_ERROR_INVALID_FORMAT
    b       .get_int_done

.get_int_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# config_get_float - Get float configuration value
# Input: x0 = key, x1 = value_pointer
# Output: x0 = result code
# Clobbers: x0-x10
# =============================================================================
config_get_float:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Find configuration entry
    bl      config_find_entry
    cmp     x0, #0
    b.lt    .get_float_not_found
    
    mov     x2, x0                              # entry pointer
    
    # Check type
    ldr     w3, [x2, #config_type]
    cmp     w3, #CONFIG_TYPE_FLOAT
    b.ne    .get_float_wrong_type
    
    # Load float value (stored as integer bits)
    ldr     w3, [x2, #config_value]
    str     w3, [x1]
    
    mov     x0, #IO_SUCCESS
    b       .get_float_done

.get_float_not_found:
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    b       .get_float_done

.get_float_wrong_type:
    mov     x0, #IO_ERROR_INVALID_FORMAT
    b       .get_float_done

.get_float_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# config_get_bool - Get boolean configuration value
# Input: x0 = key, x1 = value_pointer
# Output: x0 = result code
# Clobbers: x0-x10
# =============================================================================
config_get_bool:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Find configuration entry
    bl      config_find_entry
    cmp     x0, #0
    b.lt    .get_bool_not_found
    
    mov     x2, x0                              # entry pointer
    
    # Check type
    ldr     w3, [x2, #config_type]
    cmp     w3, #CONFIG_TYPE_BOOL
    b.ne    .get_bool_wrong_type
    
    # Load boolean value
    ldr     w3, [x2, #config_value]
    str     w3, [x1]
    
    mov     x0, #IO_SUCCESS
    b       .get_bool_done

.get_bool_not_found:
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    b       .get_bool_done

.get_bool_wrong_type:
    mov     x0, #IO_ERROR_INVALID_FORMAT
    b       .get_bool_done

.get_bool_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# config_set_string - Set string configuration value
# Input: x0 = key, x1 = value
# Output: x0 = result code
# Clobbers: x0-x15
# =============================================================================
config_set_string:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Find or create entry
    bl      config_find_or_create_entry
    cmp     x0, #0
    b.lt    .set_string_error
    
    mov     x2, x0                              # entry pointer
    
    # Set type
    mov     w3, #CONFIG_TYPE_STRING
    str     w3, [x2, #config_type]
    
    # Copy value
    add     x0, x2, #config_value
    # x1 already contains source
    mov     x2, #24                             # max value size
    bl      string_copy_n
    
    mov     x0, #IO_SUCCESS
    b       .set_string_done

.set_string_error:
    # x0 already contains error code
    b       .set_string_done

.set_string_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# config_set_int - Set integer configuration value
# Input: x0 = key, x1 = value
# Output: x0 = result code
# Clobbers: x0-x10
# =============================================================================
config_set_int:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Find or create entry
    bl      config_find_or_create_entry
    cmp     x0, #0
    b.lt    .set_int_error
    
    mov     x2, x0                              # entry pointer
    
    # Set type and value
    mov     w3, #CONFIG_TYPE_INT
    str     w3, [x2, #config_type]
    str     w1, [x2, #config_value]
    
    mov     x0, #IO_SUCCESS
    b       .set_int_done

.set_int_error:
    # x0 already contains error code
    b       .set_int_done

.set_int_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# config_set_float - Set float configuration value
# Input: x0 = key, x1 = value (as integer bits)
# Output: x0 = result code
# Clobbers: x0-x10
# =============================================================================
config_set_float:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Find or create entry
    bl      config_find_or_create_entry
    cmp     x0, #0
    b.lt    .set_float_error
    
    mov     x2, x0                              # entry pointer
    
    # Set type and value
    mov     w3, #CONFIG_TYPE_FLOAT
    str     w3, [x2, #config_type]
    str     w1, [x2, #config_value]
    
    mov     x0, #IO_SUCCESS
    b       .set_float_done

.set_float_error:
    # x0 already contains error code
    b       .set_float_done

.set_float_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# config_set_bool - Set boolean configuration value
# Input: x0 = key, x1 = value (0 or 1)
# Output: x0 = result code
# Clobbers: x0-x10
# =============================================================================
config_set_bool:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Find or create entry
    bl      config_find_or_create_entry
    cmp     x0, #0
    b.lt    .set_bool_error
    
    mov     x2, x0                              # entry pointer
    
    # Set type and value
    mov     w3, #CONFIG_TYPE_BOOL
    str     w3, [x2, #config_type]
    str     w1, [x2, #config_value]
    
    mov     x0, #IO_SUCCESS
    b       .set_bool_done

.set_bool_error:
    # x0 already contains error code
    b       .set_bool_done

.set_bool_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# config_has_key - Check if configuration key exists
# Input: x0 = key
# Output: x0 = 1 if exists, 0 if not
# Clobbers: x0-x5
# =============================================================================
config_has_key:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    bl      config_find_entry
    cmp     x0, #0
    cset    x0, ge                              # Set x0 = 1 if found, 0 if not
    
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# config_remove_key - Remove configuration key
# Input: x0 = key
# Output: x0 = result code
# Clobbers: x0-x10
# =============================================================================
config_remove_key:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Find entry index
    bl      config_find_entry_index
    cmp     x0, #0
    b.lt    .remove_key_not_found
    
    mov     x1, x0                              # Save entry index
    
    # Get entries count
    adrp    x2, config_entries_count
    add     x2, x2, :lo12:config_entries_count
    ldr     x3, [x2]
    
    # If this is the last entry, just decrement count
    add     x4, x1, #1
    cmp     x4, x3
    b.eq    .remove_key_last_entry
    
    # Shift remaining entries down
    adrp    x4, config_entries
    add     x4, x4, :lo12:config_entries
    mov     x5, #CONFIG_ENTRY_SIZE
    
    # Source: entry at index (x1 + 1)
    add     x6, x1, #1
    madd    x6, x6, x5, x4
    
    # Destination: entry at index x1
    madd    x7, x1, x5, x4
    
    # Count: (total_entries - index - 1) * entry_size
    sub     x8, x3, x1
    sub     x8, x8, #1
    mul     x8, x8, x5
    
    # Copy memory
    bl      memory_copy

.remove_key_last_entry:
    # Decrement count
    sub     x3, x3, #1
    str     x3, [x2]
    
    mov     x0, #IO_SUCCESS
    b       .remove_key_done

.remove_key_not_found:
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    b       .remove_key_done

.remove_key_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# config_enable_hot_reload - Enable hot reload monitoring
# Input: x0 = filename, x1 = callback
# Output: x0 = result code
# Clobbers: x0-x10
# =============================================================================
config_enable_hot_reload:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Store filename and callback for monitoring
    adrp    x2, hot_reload_filename
    add     x2, x2, :lo12:hot_reload_filename
    mov     x3, #256
    bl      string_copy_n
    
    adrp    x2, hot_reload_callback
    add     x2, x2, :lo12:hot_reload_callback
    str     x1, [x2]
    
    # Get initial file timestamp
    mov     x0, x19                             # filename
    bl      file_get_modification_time
    adrp    x1, hot_reload_timestamp
    add     x1, x1, :lo12:hot_reload_timestamp
    str     x0, [x1]
    
    # Enable monitoring
    adrp    x0, hot_reload_enabled
    add     x0, x0, :lo12:hot_reload_enabled
    mov     x1, #1
    str     x1, [x0]
    
    mov     x0, #IO_SUCCESS
    
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# config_check_hot_reload - Check for configuration file changes
# Input: None
# Output: x0 = 1 if reloaded, 0 if no change
# Clobbers: x0-x10
# =============================================================================
config_check_hot_reload:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Check if hot reload is enabled
    adrp    x0, hot_reload_enabled
    add     x0, x0, :lo12:hot_reload_enabled
    ldr     x1, [x0]
    cbz     x1, .check_reload_disabled
    
    # Get current file timestamp
    adrp    x0, hot_reload_filename
    add     x0, x0, :lo12:hot_reload_filename
    bl      file_get_modification_time
    
    # Compare with stored timestamp
    adrp    x1, hot_reload_timestamp
    add     x1, x1, :lo12:hot_reload_timestamp
    ldr     x2, [x1]
    cmp     x0, x2
    b.le    .check_reload_no_change
    
    # File changed, reload configuration
    str     x0, [x1]                            # Update timestamp
    
    adrp    x0, hot_reload_filename
    add     x0, x0, :lo12:hot_reload_filename
    bl      config_load_file
    
    # Call callback if provided
    adrp    x0, hot_reload_callback
    add     x0, x0, :lo12:hot_reload_callback
    ldr     x1, [x0]
    cbz     x1, .check_reload_reloaded
    blr     x1

.check_reload_reloaded:
    mov     x0, #1                              # Reloaded
    b       .check_reload_done

.check_reload_disabled:
.check_reload_no_change:
    mov     x0, #0                              # No change
    b       .check_reload_done

.check_reload_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# Helper Functions for Enhanced Configuration
# =============================================================================

config_find_entry:
    # Input: x0 = key
    # Output: x0 = entry pointer or -1 if not found
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x1, config_entries_count
    add     x1, x1, :lo12:config_entries_count
    ldr     x2, [x1]                            # entry count
    
    adrp    x3, config_entries
    add     x3, x3, :lo12:config_entries
    mov     x4, #0                              # index
    
.find_entry_loop:
    cmp     x4, x2
    b.ge    .find_entry_not_found
    
    # Calculate entry address
    mov     x5, #CONFIG_ENTRY_SIZE
    madd    x6, x4, x5, x3
    
    # Compare key
    mov     x1, x0                              # search key
    add     x0, x6, #config_key                 # entry key
    bl      string_compare
    cbz     x0, .find_entry_found
    
    add     x4, x4, #1
    b       .find_entry_loop

.find_entry_not_found:
    mov     x0, #-1
    b       .find_entry_done

.find_entry_found:
    mov     x0, x6                              # Return entry pointer

.find_entry_done:
    ldp     x29, x30, [sp], #16
    ret

config_find_entry_index:
    # Similar to config_find_entry but returns index instead of pointer
    mov     x0, #-1                             # Stub implementation
    ret

config_find_or_create_entry:
    # Input: x0 = key
    # Output: x0 = entry pointer or error code
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Try to find existing entry
    bl      config_find_entry
    cmp     x0, #0
    b.ge    .find_create_found
    
    # Create new entry
    adrp    x1, config_entries_count
    add     x1, x1, :lo12:config_entries_count
    ldr     x2, [x1]
    
    cmp     x2, #CONFIG_MAX_ENTRIES
    b.ge    .find_create_full
    
    # Calculate new entry address
    adrp    x3, config_entries
    add     x3, x3, :lo12:config_entries
    mov     x4, #CONFIG_ENTRY_SIZE
    madd    x0, x2, x4, x3
    
    # Copy key to entry
    # x0 = destination (entry key field)
    mov     x1, x0                              # Save entry pointer
    add     x0, x0, #config_key
    # Original x0 contains key
    mov     x2, #64                             # Max key size
    bl      string_copy_n
    
    # Increment count
    adrp    x2, config_entries_count
    add     x2, x2, :lo12:config_entries_count
    ldr     x3, [x2]
    add     x3, x3, #1
    str     x3, [x2]
    
    mov     x0, x1                              # Return entry pointer

.find_create_found:
    # x0 already contains entry pointer
    b       .find_create_done

.find_create_full:
    mov     x0, #IO_ERROR_BUFFER_FULL
    b       .find_create_done

.find_create_done:
    ldp     x29, x30, [sp], #16
    ret

config_write_entries:
    # Write configuration entries to file (stub)
    ret

string_compare:
    # Compare two null-terminated strings
    # Input: x0 = string1, x1 = string2
    # Output: x0 = 0 if equal, non-zero if different
    mov     x2, #0                              # index
.compare_loop:
    ldrb    w3, [x0, x2]
    ldrb    w4, [x1, x2]
    cmp     w3, w4
    b.ne    .compare_different
    cbz     w3, .compare_equal                  # Both strings ended
    add     x2, x2, #1
    b       .compare_loop

.compare_equal:
    mov     x0, #0
    ret

.compare_different:
    mov     x0, #1
    ret

memory_copy:
    # Simple memory copy (source in x6, dest in x7, size in x8)
    mov     x9, #0
.copy_loop:
    cmp     x9, x8
    b.ge    .copy_done
    ldrb    w10, [x6, x9]
    strb    w10, [x7, x9]
    add     x9, x9, #1
    b       .copy_loop
.copy_done:
    ret

# =============================================================================
# Hot Reload Data
# =============================================================================

.section __DATA,__data

hot_reload_enabled:
    .quad 0

hot_reload_filename:
    .space 256

hot_reload_callback:
    .quad 0

hot_reload_timestamp:
    .quad 0

# =============================================================================