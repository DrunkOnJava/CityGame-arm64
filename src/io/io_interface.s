# =============================================================================
# I/O & Serialization Interface Definitions
# SimCity ARM64 Assembly Project - Agent 8
# =============================================================================
# 
# This file defines the public interfaces and data structures for the I/O
# system. Other agents will use these definitions to interact with the I/O
# subsystem for save/load, asset management, configuration, and mods.
#
# Author: Agent 8 (I/O & Serialization)
# Target: ARM64 Apple Silicon
# =============================================================================

.section __DATA,__const

# =============================================================================
# Save System Data Structures
# =============================================================================

# Save file header structure (64 bytes, cache line aligned)
.struct 0
save_header_magic:          .struct . + 4       # Magic number "SIMC"
save_header_version_major:  .struct . + 2       # Major version
save_header_version_minor:  .struct . + 2       # Minor version
save_header_timestamp:      .struct . + 8       # Unix timestamp
save_header_file_size:      .struct . + 8       # Total file size
save_header_checksum:       .struct . + 4       # CRC32 checksum
save_header_compression:    .struct . + 4       # Compression type
save_header_sections:       .struct . + 4       # Section bitmask
save_header_world_offset:   .struct . + 8       # World data offset
save_header_agents_offset:  .struct . + 8       # Agents data offset
save_header_eco_offset:     .struct . + 8       # Economy data offset
save_header_infra_offset:   .struct . + 8       # Infrastructure data offset
save_header_reserved:       .struct . + 8       # Reserved for future use
SAVE_HEADER_SIZE = .

# Save section header (16 bytes)
.struct 0
section_id:                 .struct . + 4       # Section identifier
section_size:              .struct . + 8       # Uncompressed size
section_compressed_size:    .struct . + 4       # Compressed size
SECTION_HEADER_SIZE = .

# =============================================================================
# Asset System Data Structures
# =============================================================================

# Asset entry structure (128 bytes)
.struct 0
asset_id:                   .struct . + 4       # Unique asset ID
asset_type:                 .struct . + 4       # Asset type (texture, audio, etc)
asset_state:                .struct . + 4       # Loading state
asset_flags:                .struct . + 4       # Asset flags
asset_size:                 .struct . + 8       # Asset size in bytes
asset_offset:               .struct . + 8       # Offset in asset file
asset_checksum:             .struct . + 4       # Asset checksum
asset_ref_count:            .struct . + 4       # Reference count
asset_last_used:            .struct . + 8       # Last access timestamp
asset_data_ptr:             .struct . + 8       # Pointer to loaded data
asset_path:                 .struct . + 80      # Asset path (80 chars)
ASSET_ENTRY_SIZE = .

# Asset index header (32 bytes)
.struct 0
asset_index_magic:          .struct . + 4       # Magic number "ASST"
asset_index_version:        .struct . + 4       # Index version
asset_index_count:          .struct . + 4       # Number of assets
asset_index_size:           .struct . + 4       # Index size in bytes
asset_index_timestamp:      .struct . + 8       # Creation timestamp
asset_index_checksum:       .struct . + 4       # Index checksum
asset_index_reserved:       .struct . + 4       # Reserved
ASSET_INDEX_HEADER_SIZE = .

# =============================================================================
# Configuration System Data Structures
# =============================================================================

# Configuration entry (96 bytes)
.struct 0
config_key:                 .struct . + 64      # Configuration key
config_value:               .struct . + 24      # Configuration value
config_type:                .struct . + 4       # Value type
config_flags:               .struct . + 4       # Entry flags
CONFIG_ENTRY_SIZE = .

# Configuration section (32 bytes)
.struct 0
config_section_name:        .struct . + 24      # Section name
config_section_count:       .struct . + 4       # Entry count
config_section_offset:      .struct . + 4       # Offset to entries
CONFIG_SECTION_SIZE = .

# =============================================================================
# Mod System Data Structures
# =============================================================================

# Mod information structure (512 bytes)
.struct 0
mod_magic:                  .struct . + 4       # Magic number "MODS"
mod_version:                .struct . + 4       # Mod format version
mod_name:                   .struct . + 64      # Mod name
mod_version_string:         .struct . + 16      # Version string
mod_author:                 .struct . + 64      # Author name
mod_description:            .struct . + 256     # Description
mod_dependencies:           .struct . + 64      # Dependencies list
mod_hooks_count:            .struct . + 4       # Number of hooks
mod_hooks_offset:           .struct . + 4       # Offset to hooks
mod_state:                  .struct . + 4       # Current state
mod_flags:                  .struct . + 4       # Mod flags
mod_checksum:               .struct . + 4       # Mod checksum
mod_reserved:               .struct . + 24      # Reserved
MOD_INFO_SIZE = .

# Mod hook structure (32 bytes)
.struct 0
hook_type:                  .struct . + 4       # Hook type
hook_priority:              .struct . + 4       # Execution priority
hook_function_offset:       .struct . + 8       # Function offset
hook_name:                  .struct . + 16      # Hook name
MOD_HOOK_SIZE = .

# =============================================================================
# Async I/O Data Structures
# =============================================================================

# Async operation structure (64 bytes)
.struct 0
async_op_id:                .struct . + 4       # Operation ID
async_op_type:              .struct . + 4       # Operation type
async_op_state:             .struct . + 4       # Current state
async_op_error:             .struct . + 4       # Error code
async_op_progress:          .struct . + 4       # Progress (0-100)
async_op_total_size:        .struct . + 8       # Total size
async_op_completed_size:    .struct . + 8       # Completed size
async_op_callback:          .struct . + 8       # Callback function
async_op_user_data:         .struct . + 8       # User data pointer
async_op_start_time:        .struct . + 8       # Start timestamp
async_op_reserved:          .struct . + 8       # Reserved
ASYNC_OP_SIZE = .

# =============================================================================
# Function Pointer Types
# =============================================================================

# Callback function types
.typedef progress_callback, void (*)(int op_id, int progress, void* user_data)
.typedef completion_callback, void (*)(int op_id, int result, void* user_data)
.typedef error_callback, void (*)(int op_id, int error_code, const char* message, void* user_data)

# Asset loader callback
.typedef asset_loaded_callback, void (*)(int asset_id, void* data, size_t size, void* user_data)

# Mod hook function
.typedef mod_hook_function, int (*)(void* context, void* data)

# =============================================================================
# Public Interface Functions
# =============================================================================

.section __TEXT,__text

# =============================================================================
# Core I/O System Functions
# =============================================================================

.global io_system_init
.global io_system_shutdown
.global io_system_update
.global io_get_error_string

# =============================================================================
# Save System Functions
# =============================================================================

.global save_game_create
.global save_game_load
.global save_game_verify
.global save_game_compress
.global save_game_decompress
.global save_get_info
.global save_list_files

# =============================================================================
# Asset Loading Functions
# =============================================================================

.global asset_system_init
.global asset_system_shutdown
.global asset_load_sync
.global asset_load_async
.global asset_unload
.global asset_get_data
.global asset_get_info
.global asset_cache_flush
.global asset_preload_batch

# =============================================================================
# Configuration Functions
# =============================================================================

.global config_load_file
.global config_save_file
.global config_get_string
.global config_get_int
.global config_get_float
.global config_get_bool
.global config_set_string
.global config_set_int
.global config_set_float
.global config_set_bool
.global config_has_key
.global config_remove_key

# =============================================================================
# Mod Support Functions
# =============================================================================

.global mod_system_init
.global mod_system_shutdown
.global mod_load
.global mod_unload
.global mod_enable
.global mod_disable
.global mod_get_info
.global mod_list_available
.global mod_register_hook
.global mod_call_hooks

# =============================================================================
# Compression Functions
# =============================================================================

.global lz4_compress
.global lz4_decompress
.global lz4_compress_bound
.global zstd_compress
.global zstd_decompress
.global zstd_compress_bound

# =============================================================================
# Utility Functions
# =============================================================================

.global crc32_calculate
.global file_exists
.global file_size
.global file_copy
.global file_delete
.global directory_create
.global directory_list
.global path_combine
.global path_get_extension
.global path_get_filename

# =============================================================================
# Async I/O Functions
# =============================================================================

.global async_read_file
.global async_write_file
.global async_operation_wait
.global async_operation_cancel
.global async_operation_get_progress
.global async_operation_is_complete

# =============================================================================
# Function Signatures (for documentation)
# =============================================================================

# int io_system_init(void)
# Initialize the I/O system
# Returns: IO_SUCCESS on success, error code on failure

# void io_system_shutdown(void)
# Shutdown the I/O system and cleanup resources

# void io_system_update(void)
# Update async operations and handle callbacks

# const char* io_get_error_string(int error_code)
# Get human-readable error message for error code
# Parameters: error_code - Error code from IO operation
# Returns: Pointer to error string

# int save_game_create(const char* filename, int sections, int compression)
# Create a new save game file
# Parameters: filename - Output filename, sections - Sections to save, compression - Compression type
# Returns: IO_SUCCESS on success, error code on failure

# int save_game_load(const char* filename, int* sections)
# Load a save game file
# Parameters: filename - Input filename, sections - Output sections loaded
# Returns: IO_SUCCESS on success, error code on failure

# int asset_load_async(int asset_id, asset_loaded_callback callback, void* user_data)
# Load an asset asynchronously
# Parameters: asset_id - Asset to load, callback - Completion callback, user_data - User data
# Returns: Operation ID on success, negative error code on failure

# =============================================================================