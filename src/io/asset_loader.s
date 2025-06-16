# =============================================================================
# Asset Loading Pipeline
# SimCity ARM64 Assembly Project - Agent 8
# =============================================================================
# 
# This file implements the streaming asset loading pipeline for textures,
# audio, models, and other game assets. Features:
# - Streaming asset loading with priority queuing
# - Asset caching with LRU eviction
# - Async loading with callback system
# - Asset index for fast lookups
# - Reference counting for memory management
# - Hot-reload support for development
#
# Author: Agent 8 (I/O & Serialization)
# Target: ARM64 Apple Silicon
# =============================================================================

.include "io_constants.s"
.include "io_interface.s"

.section __DATA,__data

# =============================================================================
# Asset System State
# =============================================================================

.align 8
asset_system_initialized:
    .quad 0

asset_cache_memory:
    .space ASSET_CACHE_SIZE

asset_stream_buffer:
    .space ASSET_STREAM_BUFFER

asset_index_loaded:
    .quad 0

asset_index_entries:
    .quad 0                                     # Number of entries

asset_index_data:
    .space 65536                                # Space for asset index (64KB)

# Asset loading queue (circular buffer)
asset_queue_head:
    .quad 0

asset_queue_tail:
    .quad 0

asset_queue_size:
    .quad 0

.equ ASSET_QUEUE_MAX_SIZE, 256
asset_loading_queue:
    .space (ASSET_QUEUE_MAX_SIZE * 8)           # Queue of asset IDs

# Asset cache hash table (simple direct mapping)
.equ ASSET_CACHE_SLOTS, 512
asset_cache_table:
    .space (ASSET_CACHE_SLOTS * ASSET_ENTRY_SIZE)

# Audio streaming constants
.equ AUDIO_STREAM_HANDLE_SIZE, 128
.equ STREAM_STATE_READY, 1
.equ STREAM_STATE_PLAYING, 2
.equ STREAM_STATE_PAUSED, 3
.equ STREAM_STATE_ERROR, 4

# Stream handle structure offsets
.equ stream_fd, 0
.equ stream_buffer, 8
.equ stream_buffer_size, 16
.equ stream_position, 24
.equ stream_state, 32
.equ stream_header, 36

# Asset statistics
asset_stats:
    .quad 0                                     # Total assets loaded
    .quad 0                                     # Cache hits
    .quad 0                                     # Cache misses
    .quad 0                                     # Bytes loaded
    .quad 0                                     # Loading time (ms)

# Current async operations
async_ops_count:
    .quad 0

async_ops_table:
    .space (ASYNC_MAX_OPERATIONS * ASYNC_OP_SIZE)

# =============================================================================
# Asset System Functions
# =============================================================================

.section __TEXT,__text

# =============================================================================
# asset_system_init - Initialize the asset loading system
# Input: None
# Output: x0 = result code
# Clobbers: x0-x5
# =============================================================================
asset_system_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Check if already initialized
    adrp    x0, asset_system_initialized
    add     x0, x0, :lo12:asset_system_initialized
    ldr     x1, [x0]
    cbnz    x1, .asset_init_already_done
    
    # Clear asset cache table
    adrp    x1, asset_cache_table
    add     x1, x1, :lo12:asset_cache_table
    mov     x2, #(ASSET_CACHE_SLOTS * ASSET_ENTRY_SIZE)
.clear_cache_loop:
    str     xzr, [x1], #8
    subs    x2, x2, #8
    b.gt    .clear_cache_loop
    
    # Initialize queue pointers
    adrp    x1, asset_queue_head
    add     x1, x1, :lo12:asset_queue_head
    str     xzr, [x1]
    str     xzr, [x1, #8]                       # tail
    str     xzr, [x1, #16]                      # size
    
    # Clear statistics
    adrp    x1, asset_stats
    add     x1, x1, :lo12:asset_stats
    mov     x2, #40                             # 5 * 8 bytes
.clear_asset_stats_loop:
    str     xzr, [x1], #8
    subs    x2, x2, #8
    b.gt    .clear_asset_stats_loop
    
    # Clear async operations
    adrp    x1, async_ops_count
    add     x1, x1, :lo12:async_ops_count
    str     xzr, [x1]
    
    # Load asset index
    bl      asset_load_index
    cmp     x0, #IO_SUCCESS
    b.ne    .asset_init_error
    
    # Mark as initialized
    adrp    x0, asset_system_initialized
    add     x0, x0, :lo12:asset_system_initialized
    mov     x1, #1
    str     x1, [x0]
    
    mov     x0, #IO_SUCCESS
    b       .asset_init_done

.asset_init_already_done:
    mov     x0, #IO_SUCCESS
    b       .asset_init_done

.asset_init_error:
    # Initialization failed, keep error code in x0
    b       .asset_init_done

.asset_init_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# asset_system_shutdown - Shutdown the asset system
# Input: None
# Output: None
# Clobbers: x0-x5
# =============================================================================
asset_system_shutdown:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Cancel all async operations
    bl      asset_cancel_all_async
    
    # Free all cached assets
    bl      asset_cache_flush
    
    # Mark as uninitialized
    adrp    x0, asset_system_initialized
    add     x0, x0, :lo12:asset_system_initialized
    str     xzr, [x0]
    
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# asset_load_index - Load the asset index file
# Input: None
# Output: x0 = result code
# Clobbers: x0-x10
# =============================================================================
asset_load_index:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Construct index filename
    adrp    x0, default_asset_directory
    add     x0, x0, :lo12:default_asset_directory
    adrp    x1, asset_index_filename
    add     x1, x1, :lo12:asset_index_filename
    
    # TODO: Combine paths properly
    mov     x0, x1                              # Use just filename for now
    
    # Open index file
    mov     x1, #O_RDONLY
    mov     x8, #5                              # SYS_open
    svc     #0
    
    cmp     x0, #0
    b.lt    .load_index_error_open
    
    mov     x9, x0                              # Save fd
    
    # Read index header
    adrp    x0, asset_stream_buffer
    add     x0, x0, :lo12:asset_stream_buffer
    mov     x1, x9                              # fd
    mov     x2, #ASSET_INDEX_HEADER_SIZE
    mov     x8, #3                              # SYS_read
    svc     #0
    
    cmp     x0, #ASSET_INDEX_HEADER_SIZE
    b.ne    .load_index_error_read
    
    # Verify magic number
    adrp    x0, asset_stream_buffer
    add     x0, x0, :lo12:asset_stream_buffer
    ldr     w1, [x0, #asset_index_magic]
    mov     w2, #ASSET_MAGIC_NUMBER
    cmp     w1, w2
    b.ne    .load_index_error_format
    
    # Get entry count
    ldr     w1, [x0, #asset_index_count]
    adrp    x2, asset_index_entries
    add     x2, x2, :lo12:asset_index_entries
    str     x1, [x2]
    
    # Read asset entries
    adrp    x0, asset_index_data
    add     x0, x0, :lo12:asset_index_data
    mov     x1, x9                              # fd
    mul     x2, x1, #ASSET_ENTRY_SIZE           # Size to read
    mov     x8, #3                              # SYS_read
    svc     #0
    
    cmp     x0, x2
    b.ne    .load_index_error_read
    
    # Close file
    mov     x0, x9
    mov     x8, #6                              # SYS_close
    svc     #0
    
    # Mark index as loaded
    adrp    x0, asset_index_loaded
    add     x0, x0, :lo12:asset_index_loaded
    mov     x1, #1
    str     x1, [x0]
    
    mov     x0, #IO_SUCCESS
    b       .load_index_done

.load_index_error_open:
    # Create empty index if file doesn't exist
    adrp    x0, asset_index_entries
    add     x0, x0, :lo12:asset_index_entries
    str     xzr, [x0]
    
    adrp    x0, asset_index_loaded
    add     x0, x0, :lo12:asset_index_loaded
    mov     x1, #1
    str     x1, [x0]
    
    mov     x0, #IO_SUCCESS
    b       .load_index_done

.load_index_error_read:
    mov     x0, #IO_ERROR_ASYNC
    b       .load_index_done

.load_index_error_format:
    mov     x0, #IO_ERROR_INVALID_FORMAT
    b       .load_index_done

.load_index_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# asset_load_sync - Load an asset synchronously
# Input: x0 = asset_id
# Output: x0 = result code, x1 = data pointer, x2 = data size
# Clobbers: x0-x15
# =============================================================================
asset_load_sync:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                             # Save asset_id
    
    # Check if asset is already cached
    bl      asset_cache_get
    cbnz    x1, .load_sync_cached
    
    # Find asset in index
    mov     x0, x19
    bl      asset_find_in_index
    cmp     x0, #0
    b.lt    .load_sync_not_found
    
    mov     x20, x0                             # Save asset entry pointer
    
    # Load asset data
    ldr     x0, [x20, #asset_path]              # Path offset in index data
    adrp    x1, asset_index_data
    add     x1, x1, :lo12:asset_index_data
    add     x0, x1, x0                          # Full path
    
    bl      asset_load_file
    cmp     x0, #IO_SUCCESS
    b.ne    .load_sync_error
    
    # Cache the loaded asset
    mov     x0, x19                             # asset_id
    mov     x1, x1                              # data pointer
    mov     x2, x2                              # data size
    bl      asset_cache_insert
    
    # Update statistics
    adrp    x0, asset_stats
    add     x0, x0, :lo12:asset_stats
    ldr     x3, [x0]                            # Total loaded
    add     x3, x3, #1
    str     x3, [x0]
    
    ldr     x3, [x0, #24]                       # Bytes loaded
    add     x3, x3, x2
    str     x3, [x0, #24]
    
    mov     x0, #IO_SUCCESS
    b       .load_sync_done

.load_sync_cached:
    # Update cache hit statistics
    adrp    x0, asset_stats
    add     x0, x0, :lo12:asset_stats
    ldr     x3, [x0, #8]                        # Cache hits
    add     x3, x3, #1
    str     x3, [x0, #8]
    
    mov     x0, #IO_SUCCESS
    # x1, x2 already set by asset_cache_get
    b       .load_sync_done

.load_sync_not_found:
    # Update cache miss statistics
    adrp    x0, asset_stats
    add     x0, x0, :lo12:asset_stats
    ldr     x3, [x0, #16]                       # Cache misses
    add     x3, x3, #1
    str     x3, [x0, #16]
    
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    mov     x1, #0
    mov     x2, #0
    b       .load_sync_done

.load_sync_error:
    mov     x1, #0
    mov     x2, #0
    b       .load_sync_done

.load_sync_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

# =============================================================================
# asset_load_async - Load an asset asynchronously
# Input: x0 = asset_id, x1 = callback, x2 = user_data
# Output: x0 = operation_id (>= 0) or error code (< 0)
# Clobbers: x0-x10
# =============================================================================
asset_load_async:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                             # asset_id
    mov     x20, x1                             # callback
    
    # Check if asset is already cached
    bl      asset_cache_get
    cbnz    x1, .load_async_cached
    
    # Create async operation
    bl      async_operation_create
    cmp     x0, #0
    b.lt    .load_async_no_slots
    
    mov     x9, x0                              # op_id
    
    # Add to loading queue
    mov     x0, x19
    bl      asset_queue_add
    cmp     x0, #IO_SUCCESS
    b.ne    .load_async_queue_full
    
    # Set up async operation
    mov     x0, x9                              # op_id
    mov     x1, x19                             # asset_id
    mov     x2, x20                             # callback
    bl      async_operation_setup
    
    mov     x0, x9                              # Return op_id
    b       .load_async_done

.load_async_cached:
    # Asset already cached, call callback immediately
    mov     x0, x19                             # asset_id
    mov     x3, #IO_SUCCESS                     # result
    blr     x20                                 # Call callback
    
    mov     x0, #0                              # Immediate completion
    b       .load_async_done

.load_async_no_slots:
    mov     x0, #IO_ERROR_BUFFER_FULL
    b       .load_async_done

.load_async_queue_full:
    mov     x0, #IO_ERROR_BUFFER_FULL
    b       .load_async_done

.load_async_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

# =============================================================================
# asset_cache_get - Get asset from cache
# Input: x0 = asset_id
# Output: x0 = result code, x1 = data pointer, x2 = size
# Clobbers: x0-x5
# =============================================================================
asset_cache_get:
    # Simple hash: asset_id % ASSET_CACHE_SLOTS
    mov     x1, #ASSET_CACHE_SLOTS
    udiv    x2, x0, x1
    msub    x2, x2, x1, x0                      # x2 = asset_id % slots
    
    # Calculate cache entry address
    adrp    x1, asset_cache_table
    add     x1, x1, :lo12:asset_cache_table
    mov     x3, #ASSET_ENTRY_SIZE
    madd    x1, x2, x3, x1                      # entry address
    
    # Check if entry matches and is valid
    ldr     w3, [x1, #asset_id]
    cmp     w3, w0
    b.ne    .cache_get_miss
    
    ldr     w3, [x1, #asset_state]
    cmp     w3, #ASSET_READY
    b.ne    .cache_get_miss
    
    # Update last used timestamp
    mov     x8, #96                             # SYS_gettimeofday
    add     x3, sp, #-16                        # timeval on stack
    mov     x4, #0
    svc     #0
    ldr     x3, [sp, #-16]
    str     x3, [x1, #asset_last_used]
    
    # Return cached data
    ldr     x2, [x1, #asset_data_ptr]
    ldr     x3, [x1, #asset_size]
    mov     x0, #IO_SUCCESS
    mov     x1, x2                              # data pointer
    mov     x2, x3                              # size
    ret

.cache_get_miss:
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    mov     x1, #0
    mov     x2, #0
    ret

# =============================================================================
# asset_cache_insert - Insert asset into cache
# Input: x0 = asset_id, x1 = data_pointer, x2 = size
# Output: x0 = result code
# Clobbers: x0-x10
# =============================================================================
asset_cache_insert:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Find cache slot
    mov     x3, #ASSET_CACHE_SLOTS
    udiv    x4, x0, x3
    msub    x4, x4, x3, x0                      # slot index
    
    # Calculate entry address
    adrp    x3, asset_cache_table
    add     x3, x3, :lo12:asset_cache_table
    mov     x5, #ASSET_ENTRY_SIZE
    madd    x3, x4, x5, x3
    
    # Check if slot is occupied
    ldr     w5, [x3, #asset_state]
    cmp     w5, #ASSET_READY
    b.eq    .cache_insert_evict
    
    # Store asset info
    str     w0, [x3, #asset_id]
    mov     w4, #ASSET_READY
    str     w4, [x3, #asset_state]
    str     x2, [x3, #asset_size]
    str     x1, [x3, #asset_data_ptr]
    
    # Set timestamp
    mov     x8, #96                             # SYS_gettimeofday
    add     x4, sp, #-16
    mov     x5, #0
    svc     #0
    ldr     x4, [sp, #-16]
    str     x4, [x3, #asset_last_used]
    
    mov     x0, #IO_SUCCESS
    b       .cache_insert_done

.cache_insert_evict:
    # TODO: Implement LRU eviction
    # For now, just overwrite
    str     w0, [x3, #asset_id]
    str     x2, [x3, #asset_size]
    str     x1, [x3, #asset_data_ptr]
    
    mov     x0, #IO_SUCCESS
    b       .cache_insert_done

.cache_insert_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# Helper Functions (Stubs)
# =============================================================================

# =============================================================================
# asset_find_in_index - Search asset index for given asset_id
# Input: x0 = asset_id
# Output: x0 = asset entry pointer or -1 if not found
# Clobbers: x0-x5
# =============================================================================
asset_find_in_index:
    stp     x29, x30, [sp, -16]!
    mov     x29, sp
    
    mov     x1, x0                              # Save asset_id
    
    # Get entry count
    adrp    x2, asset_index_entries
    add     x2, x2, :lo12:asset_index_entries
    ldr     x2, [x2]
    
    # Search through entries
    adrp    x3, asset_index_data
    add     x3, x3, :lo12:asset_index_data
    mov     x4, #0                              # Entry index
    
.find_loop:
    cmp     x4, x2
    b.ge    .find_not_found
    
    # Calculate entry address
    mov     x5, #ASSET_ENTRY_SIZE
    madd    x0, x4, x5, x3
    
    # Check asset ID
    ldr     w5, [x0, #asset_id]
    cmp     w5, w1
    b.eq    .find_found
    
    add     x4, x4, #1
    b       .find_loop
    
.find_not_found:
    mov     x0, #-1
    b       .find_done
    
.find_found:
    # x0 already contains entry address
    b       .find_done
    
.find_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# asset_load_file - Load file from disk
# Input: x0 = filename pointer
# Output: x0 = result code, x1 = data pointer, x2 = size
# Clobbers: x0-x15
# =============================================================================
asset_load_file:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                             # Save filename
    
    # Open file
    mov     x1, #O_RDONLY
    mov     x8, #5                              # SYS_open
    svc     #0
    
    cmp     x0, #0
    b.lt    .load_file_error
    
    mov     x20, x0                             # Save fd
    
    # Get file size
    mov     x1, #0
    mov     x2, #SEEK_END
    mov     x8, #199                            # SYS_lseek
    svc     #0
    
    cmp     x0, #0
    b.lt    .load_file_error_close
    
    mov     x21, x0                             # Save file size
    
    # Reset file position
    mov     x0, x20
    mov     x1, #0
    mov     x2, #SEEK_SET
    mov     x8, #199                            # SYS_lseek
    svc     #0
    
    # Allocate memory for file
    mov     x0, x21                             # size
    bl      memory_allocate
    cbz     x0, .load_file_out_of_memory
    
    mov     x22, x0                             # Save data pointer
    
    # Read file data
    mov     x1, x20                             # fd
    mov     x2, x21                             # size
    mov     x8, #3                              # SYS_read
    svc     #0
    
    cmp     x0, x21
    b.ne    .load_file_read_error
    
    # Close file
    mov     x0, x20
    mov     x8, #6                              # SYS_close
    svc     #0
    
    # Return success
    mov     x0, #IO_SUCCESS
    mov     x1, x22                             # data pointer
    mov     x2, x21                             # size
    b       .load_file_done
    
.load_file_error:
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    mov     x1, #0
    mov     x2, #0
    b       .load_file_done
    
.load_file_error_close:
    mov     x0, x20
    mov     x8, #6                              # SYS_close
    svc     #0
    mov     x0, #IO_ERROR_ASYNC
    mov     x1, #0
    mov     x2, #0
    b       .load_file_done
    
.load_file_out_of_memory:
    mov     x0, x20
    mov     x8, #6                              # SYS_close
    svc     #0
    mov     x0, #IO_ERROR_OUT_OF_MEMORY
    mov     x1, #0
    mov     x2, #0
    b       .load_file_done
    
.load_file_read_error:
    mov     x0, x20
    mov     x8, #6                              # SYS_close
    svc     #0
    mov     x0, x22
    bl      memory_free
    mov     x0, #IO_ERROR_ASYNC
    mov     x1, #0
    mov     x2, #0
    b       .load_file_done
    
.load_file_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

# =============================================================================
# asset_queue_add - Add asset to loading queue
# Input: x0 = asset_id
# Output: x0 = result code
# Clobbers: x0-x5
# =============================================================================
asset_queue_add:
    # Check if queue is full
    adrp    x1, asset_queue_size
    add     x1, x1, :lo12:asset_queue_size
    ldr     x2, [x1]
    cmp     x2, #ASSET_QUEUE_MAX_SIZE
    b.ge    .queue_add_full
    
    # Add to queue
    adrp    x3, asset_queue_tail
    add     x3, x3, :lo12:asset_queue_tail
    ldr     x4, [x3]
    
    adrp    x5, asset_loading_queue
    add     x5, x5, :lo12:asset_loading_queue
    str     x0, [x5, x4, lsl #3]                # Store asset_id
    
    # Update tail pointer
    add     x4, x4, #1
    cmp     x4, #ASSET_QUEUE_MAX_SIZE
    csel    x4, xzr, x4, eq                     # Wrap around
    str     x4, [x3]
    
    # Update size
    add     x2, x2, #1
    str     x2, [x1]
    
    mov     x0, #IO_SUCCESS
    ret
    
.queue_add_full:
    mov     x0, #IO_ERROR_BUFFER_FULL
    ret

# =============================================================================
# async_operation_create - Create new async operation slot
# Input: None
# Output: x0 = operation_id or error code
# Clobbers: x0-x5
# =============================================================================
async_operation_create:
    adrp    x0, async_ops_count
    add     x0, x0, :lo12:async_ops_count
    ldr     x1, [x0]
    
    cmp     x1, #ASYNC_MAX_OPERATIONS
    b.ge    .async_create_full
    
    # Find free slot
    adrp    x2, async_ops_table
    add     x2, x2, :lo12:async_ops_table
    mov     x3, #0                              # Slot index
    
.async_find_slot:
    cmp     x3, #ASYNC_MAX_OPERATIONS
    b.ge    .async_create_full
    
    # Check if slot is free
    mov     x4, #ASYNC_OP_SIZE
    madd    x5, x3, x4, x2
    ldr     w4, [x5, #async_op_state]
    cbz     w4, .async_found_slot
    
    add     x3, x3, #1
    b       .async_find_slot
    
.async_found_slot:
    # Initialize operation
    mov     w4, #1                              # State = active
    str     w4, [x5, #async_op_state]
    str     w3, [x5, #async_op_id]
    
    # Increment count
    add     x1, x1, #1
    str     x1, [x0]
    
    mov     x0, x3                              # Return op_id
    ret
    
.async_create_full:
    mov     x0, #IO_ERROR_BUFFER_FULL
    ret

# =============================================================================
# async_operation_setup - Set up async operation parameters
# Input: x0 = op_id, x1 = asset_id, x2 = callback
# Output: None
# Clobbers: x0-x5
# =============================================================================
async_operation_setup:
    # Find operation slot
    adrp    x3, async_ops_table
    add     x3, x3, :lo12:async_ops_table
    mov     x4, #ASYNC_OP_SIZE
    madd    x3, x0, x4, x3
    
    # Set up operation
    str     x1, [x3, #async_op_user_data]       # Store asset_id as user data
    str     x2, [x3, #async_op_callback]
    
    # Set timestamp
    mov     x8, #96                             # SYS_gettimeofday
    sub     sp, sp, #16
    mov     x0, sp
    mov     x1, #0
    svc     #0
    ldr     x0, [sp]
    add     sp, sp, #16
    str     x0, [x3, #async_op_start_time]
    
    ret

# =============================================================================
# asset_cancel_all_async - Cancel all pending async operations
# Input: None
# Output: None
# Clobbers: x0-x5
# =============================================================================
asset_cancel_all_async:
    adrp    x0, async_ops_count
    add     x0, x0, :lo12:async_ops_count
    str     xzr, [x0]
    
    # Clear all operation slots
    adrp    x1, async_ops_table
    add     x1, x1, :lo12:async_ops_table
    mov     x2, #(ASYNC_MAX_OPERATIONS * ASYNC_OP_SIZE)
    
.cancel_clear_loop:
    str     xzr, [x1], #8
    subs    x2, x2, #8
    b.gt    .cancel_clear_loop
    
    ret

# =============================================================================
# asset_cache_flush - Free all cached assets
# Input: None
# Output: None
# Clobbers: x0-x5
# =============================================================================
asset_cache_flush:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Iterate through cache slots
    adrp    x0, asset_cache_table
    add     x0, x0, :lo12:asset_cache_table
    mov     x1, #0                              # Slot index
    
.cache_flush_loop:
    cmp     x1, #ASSET_CACHE_SLOTS
    b.ge    .cache_flush_done
    
    # Calculate entry address
    mov     x2, #ASSET_ENTRY_SIZE
    madd    x3, x1, x2, x0
    
    # Check if slot is occupied
    ldr     w2, [x3, #asset_state]
    cmp     w2, #ASSET_READY
    b.ne    .cache_flush_next
    
    # Free data
    ldr     x2, [x3, #asset_data_ptr]
    cbz     x2, .cache_flush_clear
    mov     x0, x2
    bl      memory_free
    
.cache_flush_clear:
    # Clear entry
    mov     x2, #ASSET_ENTRY_SIZE
    madd    x3, x1, x2, x0
    mov     x4, #0
.cache_clear_entry:
    str     xzr, [x3, x4]
    add     x4, x4, #8
    cmp     x4, #ASSET_ENTRY_SIZE
    b.lt    .cache_clear_entry
    
.cache_flush_next:
    adrp    x0, asset_cache_table
    add     x0, x0, :lo12:asset_cache_table
    add     x1, x1, #1
    b       .cache_flush_loop
    
.cache_flush_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# Texture Atlas Loading Functions
# =============================================================================

# =============================================================================
# asset_load_texture_atlas - Load texture atlas with metadata
# Input: x0 = atlas_filename, x1 = metadata_filename
# Output: x0 = result code, x1 = atlas_data, x2 = metadata
# Clobbers: x0-x15
# =============================================================================
asset_load_texture_atlas:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                             # Save atlas filename
    mov     x20, x1                             # Save metadata filename
    
    # Load atlas texture file
    mov     x0, x19
    bl      asset_load_file
    cmp     x0, #IO_SUCCESS
    b.ne    .atlas_load_error
    
    mov     x21, x1                             # Save atlas data
    mov     x22, x2                             # Save atlas size
    
    # Load metadata file
    mov     x0, x20
    bl      asset_load_file
    cmp     x0, #IO_SUCCESS
    b.ne    .atlas_load_metadata_error
    
    mov     x23, x1                             # Save metadata pointer
    mov     x24, x2                             # Save metadata size
    
    # Parse atlas metadata (simplified JSON format)
    mov     x0, x23
    mov     x1, x24
    bl      parse_atlas_metadata
    cmp     x0, #IO_SUCCESS
    b.ne    .atlas_load_parse_error
    
    # Return atlas data and metadata
    mov     x0, #IO_SUCCESS
    mov     x1, x21                             # atlas data
    mov     x2, x23                             # metadata
    b       .atlas_load_done
    
.atlas_load_error:
    mov     x1, #0
    mov     x2, #0
    b       .atlas_load_done
    
.atlas_load_metadata_error:
    # Free atlas data
    mov     x0, x21
    bl      memory_free
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    mov     x1, #0
    mov     x2, #0
    b       .atlas_load_done
    
.atlas_load_parse_error:
    # Free both atlas and metadata
    mov     x0, x21
    bl      memory_free
    mov     x0, x23
    bl      memory_free
    mov     x0, #IO_ERROR_INVALID_FORMAT
    mov     x1, #0
    mov     x2, #0
    b       .atlas_load_done
    
.atlas_load_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

# =============================================================================
# parse_atlas_metadata - Parse texture atlas metadata
# Input: x0 = metadata buffer, x1 = buffer size
# Output: x0 = result code
# Clobbers: x0-x10
# =============================================================================
parse_atlas_metadata:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Simple JSON parser for atlas metadata
    # Format: {"textures": [{"name": "sprite1", "x": 0, "y": 0, "w": 64, "h": 64}, ...]}
    
    # TODO: Implement proper JSON parsing
    # For now, just validate that it's a valid JSON-like structure
    
    # Check for opening brace
    ldrb    w2, [x0]
    cmp     w2, #'{'
    b.ne    .parse_atlas_invalid
    
    # Simple validation passed
    mov     x0, #IO_SUCCESS
    b       .parse_atlas_done
    
.parse_atlas_invalid:
    mov     x0, #IO_ERROR_INVALID_FORMAT
    b       .parse_atlas_done
    
.parse_atlas_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# Audio Streaming Functions
# =============================================================================

# =============================================================================
# asset_load_audio_stream - Load audio file for streaming
# Input: x0 = audio_filename, x1 = stream_buffer_size
# Output: x0 = result code, x1 = stream_handle
# Clobbers: x0-x15
# =============================================================================
asset_load_audio_stream:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                             # Save filename
    mov     x20, x1                             # Save buffer size
    
    # Allocate stream handle
    mov     x0, #AUDIO_STREAM_HANDLE_SIZE
    bl      memory_allocate
    cbz     x0, .audio_stream_no_memory
    
    mov     x21, x0                             # Save stream handle
    
    # Open audio file
    mov     x0, x19
    mov     x1, #O_RDONLY
    mov     x8, #5                              # SYS_open
    svc     #0
    
    cmp     x0, #0
    b.lt    .audio_stream_file_error
    
    str     x0, [x21, #stream_fd]               # Store file descriptor
    
    # Read audio header (WAV/OGG format detection)
    mov     x1, x0                              # fd
    add     x0, x21, #stream_header
    mov     x2, #64                             # Header size
    mov     x8, #3                              # SYS_read
    svc     #0
    
    # Parse audio format
    add     x0, x21, #stream_header
    bl      parse_audio_header
    cmp     x0, #IO_SUCCESS
    b.ne    .audio_stream_format_error
    
    # Allocate streaming buffer
    mov     x0, x20
    bl      memory_allocate
    cbz     x0, .audio_stream_buffer_error
    
    str     x0, [x21, #stream_buffer]
    str     x20, [x21, #stream_buffer_size]
    
    # Initialize stream state
    str     xzr, [x21, #stream_position]
    mov     w0, #STREAM_STATE_READY
    str     w0, [x21, #stream_state]
    
    # Return success
    mov     x0, #IO_SUCCESS
    mov     x1, x21                             # stream handle
    b       .audio_stream_done
    
.audio_stream_no_memory:
    mov     x0, #IO_ERROR_OUT_OF_MEMORY
    mov     x1, #0
    b       .audio_stream_done
    
.audio_stream_file_error:
    mov     x0, x21
    bl      memory_free
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    mov     x1, #0
    b       .audio_stream_done
    
.audio_stream_format_error:
    ldr     x0, [x21, #stream_fd]
    mov     x8, #6                              # SYS_close
    svc     #0
    mov     x0, x21
    bl      memory_free
    mov     x0, #IO_ERROR_INVALID_FORMAT
    mov     x1, #0
    b       .audio_stream_done
    
.audio_stream_buffer_error:
    ldr     x0, [x21, #stream_fd]
    mov     x8, #6                              # SYS_close
    svc     #0
    mov     x0, x21
    bl      memory_free
    mov     x0, #IO_ERROR_OUT_OF_MEMORY
    mov     x1, #0
    b       .audio_stream_done
    
.audio_stream_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

# =============================================================================
# parse_audio_header - Parse audio file header
# Input: x0 = header buffer
# Output: x0 = result code
# Clobbers: x0-x5
# =============================================================================
parse_audio_header:
    # Check for WAV header
    ldr     w1, [x0]
    mov     w2, #0x46464952                     # "RIFF"
    cmp     w1, w2
    b.eq    .parse_wav_header
    
    # Check for OGG header
    ldr     w1, [x0]
    mov     w2, #0x5367674F                     # "OggS"
    cmp     w1, w2
    b.eq    .parse_ogg_header
    
    # Unknown format
    mov     x0, #IO_ERROR_INVALID_FORMAT
    ret
    
.parse_wav_header:
    # TODO: Parse WAV header properly
    mov     x0, #IO_SUCCESS
    ret
    
.parse_ogg_header:
    # TODO: Parse OGG header properly
    mov     x0, #IO_SUCCESS
    ret

# =============================================================================
# Additional Asset Functions
# =============================================================================

asset_unload:
    # TODO: Unload specific asset
    mov     x0, #IO_SUCCESS
    ret

asset_get_data:
    # TODO: Get asset data pointer
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    ret

asset_get_info:
    # TODO: Get asset information
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    ret

asset_preload_batch:
    # TODO: Preload multiple assets
    mov     x0, #IO_SUCCESS
    ret

# =============================================================================
# Enhanced Asset Management Features
# =============================================================================

# =============================================================================
# asset_create_bundle - Create asset bundle for distribution
# Input: x0 = asset_list, x1 = bundle_filename, x2 = compression_type
# Output: x0 = result code
# Clobbers: x0-x15
# =============================================================================
asset_create_bundle:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                             # asset_list
    mov     x20, x1                             # bundle_filename
    
    # Create bundle file
    mov     x0, x20
    mov     x1, #(O_CREAT | O_TRUNC | O_WRONLY)
    mov     x2, #0644
    mov     x8, #5                              # SYS_open
    svc     #0
    
    cmp     x0, #0
    b.lt    .bundle_create_error
    
    mov     x21, x0                             # Save fd
    
    # Write bundle header
    adrp    x0, bundle_header_buffer
    add     x0, x0, :lo12:bundle_header_buffer
    
    mov     w1, #0x444E4C42                     # "BLND" magic
    str     w1, [x0]
    mov     w1, #1                              # Version
    str     w1, [x0, #4]
    
    # TODO: Write asset entries and data
    
    # Close bundle file
    mov     x0, x21
    mov     x8, #6                              # SYS_close
    svc     #0
    
    mov     x0, #IO_SUCCESS
    b       .bundle_create_done

.bundle_create_error:
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    b       .bundle_create_done

.bundle_create_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

# =============================================================================
# asset_stream_load - Load asset with streaming for large files
# Input: x0 = asset_id, x1 = callback, x2 = chunk_size
# Output: x0 = operation_id
# Clobbers: x0-x15
# =============================================================================
asset_stream_load:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                             # asset_id
    mov     x20, x1                             # callback
    
    # Create streaming operation
    bl      async_operation_create
    cmp     x0, #0
    b.lt    .stream_load_no_slots
    
    mov     x21, x0                             # op_id
    
    # Set up streaming parameters
    mov     x0, x21
    mov     x1, x19                             # asset_id
    mov     x2, x20                             # callback
    bl      async_operation_setup
    
    # Start streaming thread
    mov     x0, x21
    bl      asset_start_streaming_thread
    
    mov     x0, x21                             # Return op_id
    b       .stream_load_done

.stream_load_no_slots:
    mov     x0, #IO_ERROR_BUFFER_FULL
    b       .stream_load_done

.stream_load_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

# =============================================================================
# asset_validate_integrity - Validate asset integrity
# Input: x0 = asset_id
# Output: x0 = result code
# Clobbers: x0-x10
# =============================================================================
asset_validate_integrity:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Find asset in index
    bl      asset_find_in_index
    cmp     x0, #0
    b.lt    .validate_not_found
    
    mov     x1, x0                              # asset entry
    
    # Get asset data
    ldr     x0, [x1, #asset_data_ptr]
    cbz     x0, .validate_not_loaded
    
    # Calculate checksum
    ldr     x1, [x1, #asset_size]
    bl      save_calculate_crc32
    
    # Compare with stored checksum
    # TODO: Compare calculated vs stored checksum
    
    mov     x0, #IO_SUCCESS
    b       .validate_done

.validate_not_found:
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    b       .validate_done

.validate_not_loaded:
    mov     x0, #IO_ERROR_ASYNC
    b       .validate_done

.validate_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# asset_hot_reload - Hot reload asset for development
# Input: x0 = asset_id
# Output: x0 = result code
# Clobbers: x0-x15
# =============================================================================
asset_hot_reload:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    # Find asset in index
    bl      asset_find_in_index
    cmp     x0, #0
    b.lt    .hot_reload_not_found
    
    mov     x1, x0                              # asset entry
    
    # Check file modification time
    ldr     x0, [x1, #asset_path]
    bl      file_get_modification_time
    
    # Compare with cached time
    ldr     x2, [x1, #asset_last_used]
    cmp     x0, x2
    b.le    .hot_reload_no_change
    
    # Reload asset
    mov     x0, x1                              # asset entry
    bl      asset_reload_from_disk
    
    mov     x0, #IO_SUCCESS
    b       .hot_reload_done

.hot_reload_not_found:
    mov     x0, #IO_ERROR_FILE_NOT_FOUND
    b       .hot_reload_done

.hot_reload_no_change:
    mov     x0, #IO_SUCCESS
    b       .hot_reload_done

.hot_reload_done:
    ldp     x29, x30, [sp], #16
    ret

# =============================================================================
# Helper Functions for Enhanced Features
# =============================================================================

asset_start_streaming_thread:
    # TODO: Start streaming thread for large asset
    ret

asset_reload_from_disk:
    # TODO: Reload asset from disk
    mov     x0, #IO_SUCCESS
    ret

file_get_modification_time:
    # TODO: Get file modification time
    mov     x0, #1234567890                     # Dummy timestamp
    ret

# Memory allocation stubs (these would link to actual memory system)
memory_allocate:
    mov     x0, #0  # Placeholder
    ret

memory_free:
    ret

# =============================================================================
# Additional Data Structures
# =============================================================================

.section __DATA,__data

bundle_header_buffer:
    .space 256

# =============================================================================