# =============================================================================
# I/O & Serialization Constants
# SimCity ARM64 Assembly Project - Agent 8
# =============================================================================
# 
# This file defines constants and data structures for the I/O system including
# save game formats, asset loading, configuration parsing, and mod support.
#
# Author: Agent 8 (I/O & Serialization)
# Target: ARM64 Apple Silicon
# =============================================================================

.section __DATA,__const

# =============================================================================
# Save System Constants
# =============================================================================

.equ SAVE_MAGIC_NUMBER,     0x53494D43          # "SIMC" magic number
.equ SAVE_VERSION_MAJOR,    1                   # Major version
.equ SAVE_VERSION_MINOR,    0                   # Minor version
.equ SAVE_HEADER_SIZE,      64                  # Header size in bytes
.equ SAVE_CHUNK_SIZE,       65536               # 64KB chunks for streaming
.equ SAVE_MAX_FILENAME,     256                 # Maximum filename length

# Save file compression types
.equ COMPRESS_NONE,         0
.equ COMPRESS_LZ4,          1
.equ COMPRESS_ZSTD,         2

# Save file sections
.equ SECTION_WORLD,         0x01
.equ SECTION_AGENTS,        0x02
.equ SECTION_ECONOMY,       0x04
.equ SECTION_INFRASTRUCTURE, 0x08
.equ SECTION_SETTINGS,      0x10

# =============================================================================
# Asset Loading Constants
# =============================================================================

.equ ASSET_MAGIC_NUMBER,    0x41535354          # "ASST" magic number
.equ ASSET_MAX_PATH,        512                 # Maximum asset path length
.equ ASSET_STREAM_BUFFER,   1048576             # 1MB streaming buffer
.equ ASSET_CACHE_SIZE,      16777216            # 16MB asset cache

# Asset types
.equ ASSET_TEXTURE,         1
.equ ASSET_AUDIO,           2
.equ ASSET_MODEL,           3
.equ ASSET_FONT,            4
.equ ASSET_SHADER,          5
.equ ASSET_DATA,            6

# Asset states
.equ ASSET_UNLOADED,        0
.equ ASSET_LOADING,         1
.equ ASSET_READY,           2
.equ ASSET_ERROR,           3

# =============================================================================
# Configuration Parser Constants
# =============================================================================

.equ CONFIG_MAX_KEY_LEN,    64                  # Maximum key length
.equ CONFIG_MAX_VALUE_LEN,  256                 # Maximum value length
.equ CONFIG_MAX_DEPTH,      8                   # Maximum nesting depth
.equ CONFIG_BUFFER_SIZE,    4096                # Parse buffer size

# JSON-like token types
.equ TOKEN_LBRACE,          1                   # {
.equ TOKEN_RBRACE,          2                   # }
.equ TOKEN_LBRACKET,        3                   # [
.equ TOKEN_RBRACKET,        4                   # ]
.equ TOKEN_COLON,           5                   # :
.equ TOKEN_COMMA,           6                   # ,
.equ TOKEN_STRING,          7                   # "string"
.equ TOKEN_NUMBER,          8                   # 123 or 123.456
.equ TOKEN_BOOLEAN,         9                   # true/false
.equ TOKEN_NULL,            10                  # null
.equ TOKEN_EOF,             11                  # End of file

# =============================================================================
# Mod Support Constants
# =============================================================================

.equ MOD_MAGIC_NUMBER,      0x4D4F4453          # "MODS" magic number
.equ MOD_MAX_NAME,          64                  # Maximum mod name length
.equ MOD_MAX_VERSION,       16                  # Maximum version string
.equ MOD_MAX_DESCRIPTION,   256                 # Maximum description
.equ MOD_MAX_HOOKS,         32                  # Maximum hook points

# Mod states
.equ MOD_DISABLED,          0
.equ MOD_ENABLED,           1
.equ MOD_LOADING,           2
.equ MOD_ERROR,             3

# Hook types
.equ HOOK_PRE_UPDATE,       1
.equ HOOK_POST_UPDATE,      2
.equ HOOK_PRE_RENDER,       3
.equ HOOK_POST_RENDER,      4
.equ HOOK_SAVE_GAME,        5
.equ HOOK_LOAD_GAME,        6

# =============================================================================
# Error Codes
# =============================================================================

.equ IO_SUCCESS,            0
.equ IO_ERROR_FILE_NOT_FOUND, -1
.equ IO_ERROR_PERMISSION,   -2
.equ IO_ERROR_OUT_OF_MEMORY, -3
.equ IO_ERROR_INVALID_FORMAT, -4
.equ IO_ERROR_COMPRESSION,  -5
.equ IO_ERROR_CHECKSUM,     -6
.equ IO_ERROR_VERSION,      -7
.equ IO_ERROR_TIMEOUT,      -8
.equ IO_ERROR_ASYNC,        -9
.equ IO_ERROR_BUFFER_FULL,  -10

# =============================================================================
# File System Constants
# =============================================================================

.equ MAX_PATH_LENGTH,       1024
.equ MAX_FILENAME_LENGTH,   255
.equ FILE_BUFFER_SIZE,      8192                # 8KB file buffer
.equ TEMP_BUFFER_SIZE,      4096                # 4KB temp buffer

# File access modes
.equ O_RDONLY,              0x0000
.equ O_WRONLY,              0x0001
.equ O_RDWR,                0x0002
.equ O_CREAT,               0x0040
.equ O_TRUNC,               0x0200
.equ O_APPEND,              0x0008

# File seek whence
.equ SEEK_SET,              0
.equ SEEK_CUR,              1
.equ SEEK_END,              2

# System call numbers (macOS ARM64)
.equ SYS_opendir,           344
.equ SYS_readdir,           345
.equ SYS_closedir,          346

# =============================================================================
# Performance Constants
# =============================================================================

.equ ASYNC_MAX_OPERATIONS,  64                  # Max concurrent operations
.equ ASYNC_TIMEOUT_MS,      5000                # 5 second timeout
.equ STREAM_CHUNK_SIZE,     32768               # 32KB streaming chunks
.equ COMPRESSION_LEVEL,     6                   # Default compression level

# =============================================================================
# Data Structure Sizes (bytes)
# =============================================================================

.equ SAVE_HEADER_STRUCT_SIZE,    64
.equ ASSET_ENTRY_STRUCT_SIZE,    128
.equ CONFIG_ENTRY_STRUCT_SIZE,   96
.equ MOD_INFO_STRUCT_SIZE,       512
.equ ASYNC_OP_STRUCT_SIZE,       64

# =============================================================================
# String Constants
# =============================================================================

.section __DATA,__data

save_file_extension:
    .asciz ".sav"

config_file_extension:
    .asciz ".cfg"

mod_file_extension:
    .asciz ".mod"

asset_index_filename:
    .asciz "assets.idx"

default_save_directory:
    .asciz "saves/"

default_config_directory:
    .asciz "config/"

default_mod_directory:
    .asciz "mods/"

default_asset_directory:
    .asciz "assets/"

# Error messages
error_file_not_found:
    .asciz "File not found"

error_permission_denied:
    .asciz "Permission denied"

error_out_of_memory:
    .asciz "Out of memory"

error_invalid_format:
    .asciz "Invalid file format"

error_compression_failed:
    .asciz "Compression failed"

error_checksum_mismatch:
    .asciz "Checksum mismatch"

error_version_mismatch:
    .asciz "Version mismatch"

error_timeout:
    .asciz "Operation timeout"

error_async_failed:
    .asciz "Async operation failed"

error_buffer_full:
    .asciz "Buffer full"

# =============================================================================
# Global Variables
# =============================================================================

.align 8
io_initialized:
    .quad 0                                     # IO system initialization flag

total_bytes_read:
    .quad 0                                     # Statistics

total_bytes_written:
    .quad 0

total_files_loaded:
    .quad 0

compression_ratio:
    .quad 0

# =============================================================================