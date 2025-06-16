# Sub-Agent 8: Save/Load Integration Specialist Plan

## Objective
Wire save_load.s to all stateful modules, implement serialization for ECS, create versioned save format, add autosave integration.

## Save System Architecture

### Core Components
1. **Serialization Engine**
   - Binary format (compact)
   - Versioning support
   - Compression (LZ4-style)
   - Incremental saves

2. **Module Integration**
   - State collection
   - Dependency ordering
   - Validation
   - Recovery

3. **Performance Goals**
   - 50MB/s save speed
   - 80MB/s load speed
   - < 100MB save size
   - < 2s full save

## Implementation Tasks

### Task 1: Save Format Definition
```assembly
.global save_format_v1
.align 4

; Save file header (64 bytes)
; +0:  Magic number "SCTY" (4 bytes)
; +4:  Version (4 bytes)
; +8:  Timestamp (8 bytes)
; +16: City name (32 bytes)
; +48: Checksum (8 bytes)
; +56: Compressed size (4 bytes)
; +60: Uncompressed size (4 bytes)

; Section header (32 bytes)
; +0:  Section ID (4 bytes)
; +4:  Section version (4 bytes)
; +8:  Compressed size (4 bytes)
; +12: Uncompressed size (4 bytes)
; +16: Offset in file (8 bytes)
; +24: Checksum (8 bytes)

.data
.align 3
save_sections:
    .word SECTION_METADATA
    .word SECTION_TERRAIN
    .word SECTION_ZONES
    .word SECTION_BUILDINGS
    .word SECTION_ENTITIES
    .word SECTION_INFRASTRUCTURE
    .word SECTION_ECONOMY
    .word SECTION_AI_STATE
    .word 0  ; Terminator

.text
.global create_save_file
create_save_file:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    ; Allocate save buffer (100MB)
    mov x0, #104857600
    bl allocate_save_buffer
    mov x19, x0  ; Buffer pointer
    mov x20, x0  ; Current position
    
    ; Write header
    mov w0, #0x53435459  ; "SCTY"
    str w0, [x20], #4
    
    mov w0, #1  ; Version 1
    str w0, [x20], #4
    
    ; Timestamp
    bl get_current_timestamp
    str x0, [x20], #8
    
    ; City name (32 bytes)
    adrp x0, city_name
    add x0, x0, :lo12:city_name
    mov x1, x20
    mov x2, #32
    bl memcpy
    add x20, x20, #32
    
    ; Skip checksum and sizes (filled later)
    add x20, x20, #16
    
    ; Save each section
    adrp x21, save_sections
    add x21, x21, :lo12:save_sections
    
.section_loop:
    ldr w22, [x21], #4
    cbz w22, .sections_done
    
    ; Save section
    mov x0, x19  ; Buffer
    mov x1, x20  ; Current position
    mov x2, w22  ; Section ID
    bl save_section
    
    add x20, x20, x0  ; Advance position
    b .section_loop
    
.sections_done:
    ; Calculate total size
    sub x21, x20, x19
    
    ; Compress entire save
    mov x0, x19
    mov x1, x21
    bl compress_save_data
    
    ; Update header with sizes
    str w0, [x19, #56]  ; Compressed size
    str w21, [x19, #60] ; Uncompressed size
    
    ; Calculate checksum
    mov x0, x19
    mov x1, x0   ; Compressed size
    bl calculate_checksum_neon
    str x0, [x19, #48]
    
    ; Write to disk
    mov x0, x19
    mov x1, x0   ; Compressed size
    bl write_save_to_disk
    
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
```

### Task 2: ECS Serialization
```assembly
.global serialize_ecs_state
serialize_ecs_state:
    ; x0 = buffer
    ; x1 = buffer_size
    ; Returns bytes written
    
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    mov x19, x0  ; Buffer
    mov x20, x1  ; Size
    mov x21, x0  ; Current position
    
    ; Write entity count
    bl get_total_entity_count
    str w0, [x21], #4
    mov x22, x0  ; Save count
    
    ; Get entity arrays
    bl get_all_entity_arrays
    ; x0 = array of arrays
    ; x1 = array count
    
    mov x23, x0
    mov x24, x1
    
    ; Serialize each entity type
.type_loop:
    cbz x24, .entities_done
    
    ldr x0, [x23], #8  ; Entity array
    ldr w1, [x23], #4  ; Count
    ldr w2, [x23], #4  ; Type ID
    
    ; Write type header
    str w2, [x21], #4   ; Type ID
    str w1, [x21], #4   ; Count
    
    ; Serialize entities of this type
    mov x3, x21         ; Destination
    bl serialize_entity_array
    add x21, x21, x0    ; Advance
    
    sub x24, x24, #1
    b .type_loop
    
.entities_done:
    ; Serialize component data
    bl serialize_all_components
    
    ; Calculate bytes written
    sub x0, x21, x19
    
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

.global serialize_entity_array
serialize_entity_array:
    ; x0 = entity array
    ; x1 = count
    ; x2 = type_id
    ; x3 = destination
    
    ; Use NEON for fast copying
    mov x4, #0
.copy_loop:
    cmp x4, x1
    b.ge .copy_done
    
    ; Load 4 entities at once (256 bytes)
    ld1 {v0.2d, v1.2d, v2.2d, v3.2d}, [x0], #64
    ld1 {v4.2d, v5.2d, v6.2d, v7.2d}, [x0], #64
    ld1 {v8.2d, v9.2d, v10.2d, v11.2d}, [x0], #64
    ld1 {v12.2d, v13.2d, v14.2d, v15.2d}, [x0], #64
    
    ; Store to save buffer
    st1 {v0.2d, v1.2d, v2.2d, v3.2d}, [x3], #64
    st1 {v4.2d, v5.2d, v6.2d, v7.2d}, [x3], #64
    st1 {v8.2d, v9.2d, v10.2d, v11.2d}, [x3], #64
    st1 {v12.2d, v13.2d, v14.2d, v15.2d}, [x3], #64
    
    add x4, x4, #4
    b .copy_loop
    
.copy_done:
    ; Return bytes written
    mov x0, x1
    lsl x0, x0, #6  ; * 64 bytes per entity
    ret
```

### Task 3: Module State Collection
```assembly
.global collect_module_states
collect_module_states:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    
    ; Allocate state collection buffer
    mov x0, #1048576  ; 1MB
    bl allocate_temp_buffer
    mov x19, x0
    
    ; Collect simulation state
    mov x0, x19
    mov x1, #MODULE_SIMULATION
    bl collect_simulation_state
    
    ; Collect graphics state
    add x0, x19, #65536
    mov x1, #MODULE_GRAPHICS
    bl collect_graphics_state
    
    ; Collect AI state
    add x0, x19, #131072
    mov x1, #MODULE_AI
    bl collect_ai_state
    
    ; Collect economy state
    add x0, x19, #196608
    mov x1, #MODULE_ECONOMY
    bl collect_economy_state
    
    mov x0, x19
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

; Example: Collect simulation state
.global collect_simulation_state
collect_simulation_state:
    ; x0 = buffer
    ; x1 = module_id
    
    mov x2, x0  ; Save buffer start
    
    ; Save time state
    adrp x3, game_time
    ldr x3, [x3, :lo12:game_time]
    str x3, [x0], #8
    
    adrp x3, day_night_cycle
    ldr w3, [x3, :lo12:day_night_cycle]
    str w3, [x0], #4
    
    ; Save weather state
    adrp x3, weather_state
    add x3, x3, :lo12:weather_state
    mov x1, #64  ; Weather struct size
    bl memcpy_neon
    add x0, x0, #64
    
    ; Save zone data
    bl save_zone_grid
    
    ; Return bytes used
    sub x0, x0, x2
    ret
```

### Task 4: Incremental Save System
```assembly
.global incremental_save_init
incremental_save_init:
    ; Set up dirty tracking
    
    adrp x0, dirty_chunks
    add x0, x0, :lo12:dirty_chunks
    
    ; Clear all dirty flags (512 chunks)
    mov x1, #64  ; 512 bits / 8
    mov x2, #0
.clear_loop:
    str x2, [x0], #8
    subs x1, x1, #1
    b.ne .clear_loop
    
    ret

.global mark_chunk_dirty
mark_chunk_dirty:
    ; x0 = chunk_id
    
    ; Calculate bit position
    lsr x1, x0, #6      ; / 64
    and x2, x0, #63     ; % 64
    
    ; Set bit
    adrp x3, dirty_chunks
    add x3, x3, :lo12:dirty_chunks
    ldr x4, [x3, x1, lsl #3]
    
    mov x5, #1
    lsl x5, x5, x2
    orr x4, x4, x5
    
    str x4, [x3, x1, lsl #3]
    ret

.global incremental_save
incremental_save:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    
    ; Count dirty chunks
    bl count_dirty_chunks
    cbz x0, .nothing_to_save
    
    mov x19, x0  ; Dirty count
    
    ; Allocate delta buffer
    lsl x0, x19, #16  ; 64KB per chunk
    bl allocate_temp_buffer
    mov x20, x0
    
    ; Save only dirty chunks
    bl save_dirty_chunks
    
    ; Compress delta
    mov x0, x20
    mov x1, x19, lsl #16
    bl compress_delta
    
    ; Append to save file
    bl append_delta_to_save
    
    ; Clear dirty flags
    bl clear_dirty_flags
    
.nothing_to_save:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
```

### Task 5: Autosave Integration
```assembly
.global autosave_init
autosave_init:
    ; Set up autosave timer
    
    mov x0, #300  ; 5 minutes in seconds
    bl set_autosave_interval
    
    ; Register with event system
    mov x0, #EVENT_TYPE_SYSTEM
    mov x1, #autosave_handler
    bl register_event_handler
    
    ret

.global autosave_handler
autosave_handler:
    stp x29, x30, [sp, #-16]!
    
    ; Check if enough time passed
    bl get_time_since_last_save
    mov x1, #300  ; 5 minutes
    cmp x0, x1
    b.lt .skip_save
    
    ; Check if game is paused
    bl is_game_paused
    cbnz x0, .skip_save
    
    ; Perform incremental save
    bl incremental_save
    
    ; Update last save time
    bl update_last_save_time
    
.skip_save:
    ldp x29, x30, [sp], #16
    ret
```

## Compression Implementation

### LZ4-Style Compression
```assembly
.global compress_save_data
compress_save_data:
    ; x0 = input buffer
    ; x1 = input size
    ; Returns compressed size
    
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    mov x19, x0  ; Input
    mov x20, x1  ; Size
    
    ; Allocate output buffer
    add x0, x1, x1, lsr #3  ; Size + 12.5%
    bl allocate_compression_buffer
    mov x21, x0  ; Output
    mov x22, x0  ; Current position
    
    ; LZ4 compression loop
    mov x23, x19  ; Input position
    add x24, x19, x20  ; End position
    
.compress_loop:
    ; Find match
    mov x0, x23
    sub x1, x24, x23
    bl find_match_neon
    
    cbz x0, .no_match
    
    ; Encode match
    ; x0 = match offset
    ; x1 = match length
    
    ; Write literal length
    sub x2, x23, x19
    strb w2, [x22], #1
    
    ; Copy literals
    mov x0, x19
    mov x1, x22
    mov x2, x2
    bl memcpy_neon
    add x22, x22, x2
    
    ; Write match
    strh w0, [x22], #2  ; Offset
    strb w1, [x22], #1  ; Length
    
    ; Advance input
    add x23, x23, x1
    mov x19, x23
    
    cmp x23, x24
    b.lt .compress_loop
    
.no_match:
    ; Copy remaining literals
    sub x2, x24, x19
    cbz x2, .done
    
    strb w2, [x22], #1
    mov x0, x19
    mov x1, x22
    bl memcpy_neon
    add x22, x22, x2
    
.done:
    ; Return compressed size
    sub x0, x22, x21
    
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
```

## Load System Integration

### Fast Loading
```assembly
.global load_save_file
load_save_file:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    
    ; Memory map save file
    bl mmap_save_file
    mov x19, x0  ; Mapped address
    mov x20, x1  ; File size
    
    ; Verify header
    ldr w0, [x19]
    mov w1, #0x53435459  ; "SCTY"
    cmp w0, w1
    b.ne .invalid_save
    
    ; Check version
    ldr w0, [x19, #4]
    cmp w0, #1
    b.gt .unsupported_version
    
    ; Verify checksum
    mov x0, x19
    ldr w1, [x19, #56]  ; Compressed size
    bl verify_checksum_neon
    cbz x0, .checksum_failed
    
    ; Decompress in parallel
    mov x0, x19
    ldr w1, [x19, #56]  ; Compressed size
    ldr w2, [x19, #60]  ; Uncompressed size
    bl decompress_parallel
    
    ; Load sections
    bl load_all_sections
    
    ; Success
    mov x0, #1
    b .cleanup
    
.invalid_save:
.unsupported_version:
.checksum_failed:
    mov x0, #0
    
.cleanup:
    mov x1, x19
    mov x2, x20
    bl munmap_save_file
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
```

## Integration Points

### All Stateful Modules
- State serialization functions
- Dirty tracking hooks
- Version migration
- Validation routines

### Event System (Sub-Agent 6)
- Save/load events
- Progress updates
- Error notifications
- Completion callbacks

### Performance (Sub-Agent 7)
- I/O benchmarking
- Compression profiling
- Memory usage tracking
- Load time optimization

## Success Metrics
1. < 100MB save file size
2. < 2s full save time
3. < 3s load time
4. Zero data corruption
5. Backward compatibility

## Timeline
- Day 1: Save format design
- Day 2: ECS serialization
- Day 3: Module integration
- Day 4: Compression/decompression
- Day 5: Autosave and testing