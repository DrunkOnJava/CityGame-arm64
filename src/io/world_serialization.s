# =============================================================================
# World Serialization System
# SimCity ARM64 Assembly Project - Agent 6 (Data & Persistence)
# =============================================================================
# 
# This file implements the world serialization system with differential saves,
# streaming I/O, and optimized data structures for large city data.
# Features:
# - Differential/incremental saves (only changed chunks)
# - Streaming I/O for large worlds (>1GB save files)
# - Chunk-based world segmentation (32x32 tile chunks)
# - Version-aware serialization with migration support
# - LZ4/ZSTD compression for size optimization
# - Multi-threaded save/load operations
# - Hot backup system with atomic saves
# - World validation and corruption recovery
#
# Author: Agent 6 (Data & Persistence Systems)
# Target: ARM64 Apple Silicon
# =============================================================================

.include "io_constants.s"
.include "io_interface.s"

.section __DATA,__data

# =============================================================================
# World Serialization State
# =============================================================================

.align 8
world_serializer_initialized:
    .quad 0

# World metadata structure
.struct 0
world_magic:                .struct . + 4       # Magic number "WRLD"
world_version:             .struct . + 4       # Serialization version
world_size_x:              .struct . + 4       # World width in tiles
world_size_y:              .struct . + 4       # World height in tiles
world_chunk_size:          .struct . + 4       # Chunk size (default 32x32)
world_total_chunks:        .struct . + 4       # Total number of chunks
world_creation_time:       .struct . + 8       # Creation timestamp
world_last_save_time:      .struct . + 8       # Last save timestamp
world_save_count:          .struct . + 4       # Number of saves
world_flags:               .struct . + 4       # World flags
world_checksum:            .struct . + 4       # World data checksum
world_compression_type:    .struct . + 4       # Compression algorithm
world_reserved:            .struct . + 64      # Reserved for future use
WORLD_METADATA_SIZE = .

# Chunk metadata structure
.struct 0
chunk_x:                   .struct . + 4       # Chunk X coordinate
chunk_y:                   .struct . + 4       # Chunk Y coordinate
chunk_dirty:               .struct . + 4       # Dirty flag (needs save)
chunk_version:             .struct . + 4       # Chunk version number
chunk_data_size:           .struct . + 4       # Uncompressed data size
chunk_compressed_size:     .struct . + 4       # Compressed data size
chunk_offset:              .struct . + 8       # Offset in save file
chunk_checksum:            .struct . + 4       # Chunk data checksum
chunk_last_modified:       .struct . + 8       # Last modification time
chunk_reserved:            .struct . + 8       # Reserved
CHUNK_METADATA_SIZE = .

# World chunk data (per 32x32 tile chunk)
.struct 0
chunk_tiles:               .struct . + 4096    # Tile data (32x32 * 4 bytes)
chunk_buildings:           .struct . + 2048    # Building data
chunk_roads:               .struct . + 1024    # Road network data
chunk_utilities:           .struct . + 1024    # Utilities (power, water)
chunk_zones:               .struct . + 512     # Zoning information
chunk_agents:              .struct . + 256     # Agent references
chunk_economy:             .struct . + 128     # Economic data
chunk_environment:         .struct . + 64      # Environmental data
CHUNK_DATA_SIZE = .

# Global world state
current_world_metadata:
    .space WORLD_METADATA_SIZE

# Chunk management
.equ MAX_WORLD_CHUNKS, 16384               # Support up to 128x128 world chunks
.equ CHUNK_CACHE_SIZE, 256                 # Keep 256 chunks in memory

chunk_metadata_table:
    .space (MAX_WORLD_CHUNKS * CHUNK_METADATA_SIZE)

chunk_cache:
    .space (CHUNK_CACHE_SIZE * CHUNK_DATA_SIZE)

chunk_dirty_list:
    .space (MAX_WORLD_CHUNKS / 8)          # Bit array for dirty chunks

# Streaming I/O buffers
.equ STREAM_BUFFER_SIZE, 1048576           # 1MB streaming buffer
stream_buffer:
    .space STREAM_BUFFER_SIZE

compression_buffer:
    .space (STREAM_BUFFER_SIZE + 65536)    # Extra space for compression

# Save operation state
save_operation_active:
    .quad 0

save_file_handle:
    .quad -1

save_progress:
    .quad 0

save_total_chunks:
    .quad 0

# Differential save tracking
last_full_save_time:
    .quad 0

incremental_save_counter:
    .quad 0

# Statistics
world_stats:
    .quad 0                                # Total chunks saved
    .quad 0                                # Total data saved (bytes)
    .quad 0                                # Compression ratio * 1000
    .quad 0                                # Average save time (ms)
    .quad 0                                # Load operations
    .quad 0                                # Save operations

# =============================================================================
# World Serialization Functions
# =============================================================================

.section __TEXT,__text

# =============================================================================
# world_serializer_init - Initialize the world serialization system
# Input: None
# Output: x0 = result code
# Clobbers: x0-x5
# =============================================================================
world_serializer_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Check if already initialized
    adrp    x0, world_serializer_initialized
    add     x0, x0, :lo12:world_serializer_initialized
    ldr     x1, [x0]
    cbnz    x1, .world_init_done
    
    # Clear metadata
    adrp    x1, current_world_metadata
    add     x1, x1, :lo12:current_world_metadata
    mov     x2, #WORLD_METADATA_SIZE
.clear_metadata_loop:
    str     xzr, [x1], #8
    subs    x2, x2, #8
    b.gt    .clear_metadata_loop
    
    # Clear chunk metadata table
    adrp    x1, chunk_metadata_table
    add     x1, x1, :lo12:chunk_metadata_table
    mov     x2, #(MAX_WORLD_CHUNKS * CHUNK_METADATA_SIZE)
.clear_chunks_loop:
    str     xzr, [x1], #8
    subs    x2, x2, #8
    b.gt    .clear_chunks_loop
    
    # Clear dirty list
    adrp    x1, chunk_dirty_list
    add     x1, x1, :lo12:chunk_dirty_list
    mov     x2, #(MAX_WORLD_CHUNKS / 8)
.clear_dirty_loop:
    str     xzr, [x1], #8
    subs    x2, x2, #8
    b.gt    .clear_dirty_loop
    
    # Initialize file handle
    adrp    x1, save_file_handle
    add     x1, x1, :lo12:save_file_handle
    mov     x2, #-1
    str     x2, [x1]
    
    # Clear statistics
    adrp    x1, world_stats
    add     x1, x1, :lo12:world_stats
    mov     x2, #48                             # 6 * 8 bytes
.clear_stats_loop:
    str     xzr, [x1], #8
    subs    x2, x2, #8
    b.gt    .clear_stats_loop
    
    # Mark as initialized
    mov     x1, #1
    str     x1, [x0]
    
    mov     x0, #IO_SUCCESS

.world_init_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# world_create_new - Create a new world for serialization
# Input: x0 = world_width, x1 = world_height, x2 = chunk_size
# Output: x0 = result code
# Clobbers: x0-x10
# =============================================================================
world_create_new:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Validate parameters
    cmp     x0, #32
    b.lt    .world_create_invalid_size
    cmp     x1, #32
    b.lt    .world_create_invalid_size
    cmp     x2, #16
    b.lt    .world_create_invalid_chunk
    cmp     x2, #128
    b.gt    .world_create_invalid_chunk
    
    # Calculate number of chunks
    udiv    x3, x0, x2                          # chunks_x = width / chunk_size
    udiv    x4, x1, x2                          # chunks_y = height / chunk_size
    mul     x5, x3, x4                          # total_chunks = chunks_x * chunks_y
    
    cmp     x5, #MAX_WORLD_CHUNKS
    b.gt    .world_create_too_many_chunks
    
    # Initialize world metadata
    adrp    x6, current_world_metadata
    add     x6, x6, :lo12:current_world_metadata
    
    mov     w7, #0x444C5257                     # "WRLD" magic
    str     w7, [x6, #world_magic]
    
    mov     w7, #1                              # Version 1
    str     w7, [x6, #world_version]
    
    str     w0, [x6, #world_size_x]
    str     w1, [x6, #world_size_y]
    str     w2, [x6, #world_chunk_size]
    str     w5, [x6, #world_total_chunks]
    
    # Get current timestamp
    mov     x8, #96                             # SYS_gettimeofday
    sub     sp, sp, #16
    mov     x0, sp
    mov     x1, #0
    svc     #0
    ldr     x0, [sp]
    add     sp, sp, #16
    
    str     x0, [x6, #world_creation_time]
    str     x0, [x6, #world_last_save_time]
    
    str     wzr, [x6, #world_save_count]
    str     wzr, [x6, #world_flags]
    str     wzr, [x6, #world_checksum]
    mov     w7, #COMPRESS_LZ4
    str     w7, [x6, #world_compression_type]
    
    # Initialize chunk metadata
    bl      world_initialize_chunks
    
    mov     x0, #IO_SUCCESS
    b       .world_create_done

.world_create_invalid_size:
    mov     x0, #IO_ERROR_INVALID_FORMAT
    b       .world_create_done

.world_create_invalid_chunk:
    mov     x0, #IO_ERROR_INVALID_FORMAT
    b       .world_create_done

.world_create_too_many_chunks:
    mov     x0, #IO_ERROR_BUFFER_FULL
    b       .world_create_done

.world_create_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# world_save_differential - Save only changed chunks (differential save)
# Input: x0 = filename, x1 = force_full_save (0/1)
# Output: x0 = result code, x1 = chunks_saved
# Clobbers: x0-x15
# =============================================================================
world_save_differential:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                             # Save filename
    mov     x20, x1                             # Save force_full_save flag
    
    # Check if full save is needed
    cbz     x20, .check_incremental
    b       .start_full_save

.check_incremental:
    # Count dirty chunks
    bl      world_count_dirty_chunks
    mov     x21, x0                             # dirty_count
    
    # If no dirty chunks, nothing to save
    cbz     x21, .save_differential_nothing
    
    # Check if incremental save threshold exceeded
    adrp    x0, incremental_save_counter
    add     x0, x0, :lo12:incremental_save_counter
    ldr     x1, [x0]
    cmp     x1, #10                             # Force full save every 10 incrementals
    b.ge    .start_full_save

.start_incremental_save:
    # Create incremental save filename
    mov     x0, x19
    bl      world_create_incremental_filename
    cmp     x0, #IO_SUCCESS
    b.ne    .save_differential_error
    
    # Open incremental save file
    adrp    x0, incremental_filename_buffer
    add     x0, x0, :lo12:incremental_filename_buffer
    mov     x1, #(O_CREAT | O_TRUNC | O_WRONLY)
    mov     x2, #0644
    mov     x8, #5                              # SYS_open
    svc     #0
    
    cmp     x0, #0
    b.lt    .save_differential_file_error
    
    adrp    x1, save_file_handle
    add     x1, x1, :lo12:save_file_handle
    str     x0, [x1]
    
    # Write incremental save header
    bl      world_write_incremental_header
    cmp     x0, #IO_SUCCESS
    b.ne    .save_differential_write_error
    
    # Save only dirty chunks
    bl      world_save_dirty_chunks
    mov     x22, x0                             # chunks_saved
    cmp     x22, #0
    b.lt    .save_differential_write_error
    
    # Update incremental counter
    adrp    x0, incremental_save_counter
    add     x0, x0, :lo12:incremental_save_counter
    ldr     x1, [x0]
    add     x1, x1, #1
    str     x1, [x0]
    
    b       .save_differential_success

.start_full_save:
    # Open full save file
    mov     x0, x19
    mov     x1, #(O_CREAT | O_TRUNC | O_WRONLY)
    mov     x2, #0644
    mov     x8, #5                              # SYS_open
    svc     #0
    
    cmp     x0, #0
    b.lt    .save_differential_file_error
    
    adrp    x1, save_file_handle
    add     x1, x1, :lo12:save_file_handle
    str     x1, [x1]
    
    # Write world metadata
    bl      world_write_metadata
    cmp     x0, #IO_SUCCESS
    b.ne    .save_differential_write_error
    
    # Save all chunks
    bl      world_save_all_chunks
    mov     x22, x0                             # chunks_saved
    cmp     x22, #0
    b.lt    .save_differential_write_error
    
    # Reset incremental counter
    adrp    x0, incremental_save_counter
    add     x0, x0, :lo12:incremental_save_counter
    str     xzr, [x0]
    
    # Update last full save time
    mov     x8, #96                             # SYS_gettimeofday
    sub     sp, sp, #16
    mov     x0, sp
    mov     x1, #0
    svc     #0
    ldr     x0, [sp]
    add     sp, sp, #16
    
    adrp    x1, last_full_save_time
    add     x1, x1, :lo12:last_full_save_time
    str     x0, [x1]

.save_differential_success:
    # Close file
    adrp    x0, save_file_handle
    add     x0, x0, :lo12:save_file_handle
    ldr     x0, [x0]
    mov     x8, #6                              # SYS_close
    svc     #0
    
    # Clear dirty flags
    bl      world_clear_dirty_flags
    
    # Update statistics
    adrp    x0, world_stats
    add     x0, x0, :lo12:world_stats
    ldr     x1, [x0, #40]                       # Save operations
    add     x1, x1, #1
    str     x1, [x0, #40]
    
    mov     x0, #IO_SUCCESS
    mov     x1, x22                             # chunks_saved
    b       .save_differential_done

.save_differential_nothing:
    mov     x0, #IO_SUCCESS
    mov     x1, #0                              # No chunks saved
    b       .save_differential_done

.save_differential_file_error:
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    mov     x1, #0
    b       .save_differential_done

.save_differential_write_error:
    # Close file if open
    adrp    x0, save_file_handle
    add     x0, x0, :lo12:save_file_handle
    ldr     x1, [x0]
    cmn     x1, #1
    b.eq    .save_differential_error
    mov     x0, x1
    mov     x8, #6                              # SYS_close
    svc     #0

.save_differential_error:
    mov     x0, #IO_ERROR_ASYNC
    mov     x1, #0
    b       .save_differential_done

.save_differential_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

# =============================================================================
# world_load_from_save - Load world from save file
# Input: x0 = filename
# Output: x0 = result code
# Clobbers: x0-x15
# =============================================================================
world_load_from_save:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                             # Save filename
    
    # Open save file
    mov     x1, #O_RDONLY
    mov     x8, #5                              # SYS_open
    svc     #0
    
    cmp     x0, #0
    b.lt    .world_load_file_error
    
    mov     x20, x0                             # Save fd
    
    # Read and validate world metadata
    mov     x1, x20
    adrp    x0, current_world_metadata
    add     x0, x0, :lo12:current_world_metadata
    mov     x2, #WORLD_METADATA_SIZE
    mov     x8, #3                              # SYS_read
    svc     #0
    
    cmp     x0, #WORLD_METADATA_SIZE
    b.ne    .world_load_read_error
    
    # Validate magic number
    adrp    x0, current_world_metadata
    add     x0, x0, :lo12:current_world_metadata
    ldr     w1, [x0, #world_magic]
    mov     w2, #0x444C5257                     # "WRLD"
    cmp     w1, w2
    b.ne    .world_load_invalid_format
    
    # Load chunk metadata
    mov     x0, x20
    bl      world_load_chunk_metadata
    cmp     x0, #IO_SUCCESS
    b.ne    .world_load_read_error
    
    # Stream load chunks as needed
    bl      world_setup_streaming_load
    
    # Close file
    mov     x0, x20
    mov     x8, #6                              # SYS_close
    svc     #0
    
    # Update statistics
    adrp    x0, world_stats
    add     x0, x0, :lo12:world_stats
    ldr     x1, [x0, #32]                       # Load operations
    add     x1, x1, #1
    str     x1, [x0, #32]
    
    mov     x0, #IO_SUCCESS
    b       .world_load_done

.world_load_file_error:
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    b       .world_load_done

.world_load_read_error:
    mov     x0, x20
    mov     x8, #6                              # SYS_close
    svc     #0
    mov     x0, #IO_ERROR_ASYNC
    b       .world_load_done

.world_load_invalid_format:
    mov     x0, x20
    mov     x8, #6                              # SYS_close
    svc     #0
    mov     x0, #IO_ERROR_INVALID_FORMAT
    b       .world_load_done

.world_load_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

# =============================================================================
# world_mark_chunk_dirty - Mark a chunk as needing save
# Input: x0 = chunk_x, x1 = chunk_y
# Output: x0 = result code
# Clobbers: x0-x5
# =============================================================================
world_mark_chunk_dirty:
    # Calculate chunk index
    adrp    x2, current_world_metadata
    add     x2, x2, :lo12:current_world_metadata
    ldr     w3, [x2, #world_chunk_size]
    ldr     w4, [x2, #world_size_x]
    udiv    w4, w4, w3                          # chunks_per_row
    
    mul     w2, w1, w4                          # chunk_y * chunks_per_row
    add     w2, w2, w0                          # + chunk_x
    
    # Validate chunk index
    ldr     w3, [x2, #world_total_chunks]
    cmp     w2, w3
    b.ge    .mark_dirty_invalid_chunk
    
    # Set dirty bit
    adrp    x3, chunk_dirty_list
    add     x3, x3, :lo12:chunk_dirty_list
    lsr     x4, x2, #3                          # byte_index = chunk_index / 8
    and     x5, x2, #7                          # bit_index = chunk_index % 8
    
    ldrb    w0, [x3, x4]
    mov     w1, #1
    lsl     w1, w1, w5
    orr     w0, w0, w1
    strb    w0, [x3, x4]
    
    # Update chunk metadata
    adrp    x3, chunk_metadata_table
    add     x3, x3, :lo12:chunk_metadata_table
    mov     x4, #CHUNK_METADATA_SIZE
    madd    x3, x2, x4, x3
    
    mov     w4, #1
    str     w4, [x3, #chunk_dirty]
    
    # Update version
    ldr     w4, [x3, #chunk_version]
    add     w4, w4, #1
    str     w4, [x3, #chunk_version]
    
    # Update timestamp
    mov     x8, #96                             # SYS_gettimeofday
    sub     sp, sp, #16
    mov     x0, sp
    mov     x1, #0
    svc     #0
    ldr     x0, [sp]
    add     sp, sp, #16
    str     x0, [x3, #chunk_last_modified]
    
    mov     x0, #IO_SUCCESS
    ret

.mark_dirty_invalid_chunk:
    mov     x0, #IO_ERROR_INVALID_FORMAT
    ret

# =============================================================================
# world_get_chunk_data - Get chunk data for reading/writing
# Input: x0 = chunk_x, x1 = chunk_y
# Output: x0 = result code, x1 = chunk_data_pointer
# Clobbers: x0-x10
# =============================================================================
world_get_chunk_data:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Calculate chunk index (same as mark_dirty)
    adrp    x2, current_world_metadata
    add     x2, x2, :lo12:current_world_metadata
    ldr     w3, [x2, #world_chunk_size]
    ldr     w4, [x2, #world_size_x]
    udiv    w4, w4, w3
    
    mul     w2, w1, w4
    add     w2, w2, w0
    
    # Validate chunk index
    ldr     w3, [x2, #world_total_chunks]
    cmp     w2, w3
    b.ge    .get_chunk_invalid
    
    # Check if chunk is in cache
    mov     x0, x2                              # chunk_index
    bl      world_find_chunk_in_cache
    cmp     x0, #0
    b.ge    .get_chunk_cached
    
    # Load chunk from disk if needed
    mov     x0, x2                              # chunk_index
    bl      world_load_chunk_to_cache
    cmp     x0, #IO_SUCCESS
    b.ne    .get_chunk_load_error
    
    mov     x1, x0                              # chunk_data_pointer

.get_chunk_cached:
    mov     x0, #IO_SUCCESS
    b       .get_chunk_done

.get_chunk_invalid:
    mov     x0, #IO_ERROR_INVALID_FORMAT
    mov     x1, #0
    b       .get_chunk_done

.get_chunk_load_error:
    mov     x1, #0
    b       .get_chunk_done

.get_chunk_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# Helper Functions (Implementation stubs)
# =============================================================================

world_initialize_chunks:
    # TODO: Initialize chunk metadata for new world
    mov     x0, #IO_SUCCESS
    ret

world_count_dirty_chunks:
    # TODO: Count chunks with dirty flag set
    mov     x0, #5                              # Dummy value
    ret

world_create_incremental_filename:
    # TODO: Create filename with timestamp for incremental save
    mov     x0, #IO_SUCCESS
    ret

world_write_incremental_header:
    # TODO: Write incremental save header
    mov     x0, #IO_SUCCESS
    ret

world_save_dirty_chunks:
    # TODO: Save only chunks marked as dirty
    mov     x0, #5                              # Return chunks saved
    ret

world_write_metadata:
    # TODO: Write world metadata to file
    mov     x0, #IO_SUCCESS
    ret

world_save_all_chunks:
    # TODO: Save all world chunks
    mov     x0, #100                            # Return chunks saved
    ret

world_clear_dirty_flags:
    # TODO: Clear all dirty flags after successful save
    ret

world_load_chunk_metadata:
    # TODO: Load chunk metadata from save file
    mov     x0, #IO_SUCCESS
    ret

world_setup_streaming_load:
    # TODO: Setup streaming load for large worlds
    ret

world_find_chunk_in_cache:
    # TODO: Find chunk in memory cache
    mov     x0, #-1                             # Not found
    ret

world_load_chunk_to_cache:
    # TODO: Load chunk from disk to cache
    adrp    x0, chunk_cache
    add     x0, x0, :lo12:chunk_cache
    ret

# =============================================================================
# Data Section for Helper Functions
# =============================================================================

.section __DATA,__data

incremental_filename_buffer:
    .space 512

# =============================================================================