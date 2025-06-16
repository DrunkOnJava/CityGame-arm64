# Sub-Agent 6: Event System Architect Plan

## Objective
Create central event_bus.s, wire input → simulation → graphics events, set up inter-module messaging, implement event priority and filtering.

## Event System Architecture

### Core Components
1. **Event Bus**
   - Lock-free ring buffers
   - Per-thread queues
   - Priority handling
   - Event filtering

2. **Event Types**
   - Input events
   - Simulation events
   - Graphics events
   - System events
   - Debug events

3. **Event Flow**
   - Producers → Bus → Consumers
   - Async dispatch
   - Batch processing
   - Event coalescing

## Implementation Tasks

### Task 1: Create event_bus.s
```assembly
.global event_bus_init
.align 4

; Event structure (32 bytes)
; +0:  event_type (4 bytes)
; +4:  event_subtype (4 bytes)
; +8:  timestamp (8 bytes)
; +16: payload_ptr (8 bytes)
; +24: sender_id (4 bytes)
; +28: priority (4 bytes)

.data
.align 6
event_ring_buffer:
    .space 1048576  ; 1MB ring buffer (32K events)

event_read_index:
    .quad 0
event_write_index:
    .quad 0

.text
event_bus_init:
    stp x29, x30, [sp, #-16]!
    
    ; Initialize indices
    adrp x0, event_read_index
    str xzr, [x0, :lo12:event_read_index]
    
    adrp x0, event_write_index
    str xzr, [x0, :lo12:event_write_index]
    
    ; Initialize per-thread queues
    bl init_thread_local_queues
    
    ; Register event handlers
    bl register_default_handlers
    
    ldp x29, x30, [sp], #16
    ret

.global post_event
post_event:
    ; x0 = event_type
    ; x1 = event_subtype
    ; x2 = payload_ptr
    ; x3 = priority
    
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    
    ; Get timestamp
    bl get_high_precision_time
    mov x23, x0
    
    ; Atomic increment write index
    adrp x0, event_write_index
    add x0, x0, :lo12:event_write_index
.retry_increment:
    ldaxr x1, [x0]
    add x2, x1, #1
    stlxr w3, x2, [x0]
    cbnz w3, .retry_increment
    
    ; Calculate buffer position
    and x1, x1, #0x7FFF  ; Mask for 32K events
    lsl x1, x1, #5       ; * 32 bytes per event
    
    adrp x0, event_ring_buffer
    add x0, x0, :lo12:event_ring_buffer
    add x0, x0, x1
    
    ; Store event
    str w19, [x0, #0]    ; event_type
    str w20, [x0, #4]    ; event_subtype
    str x23, [x0, #8]    ; timestamp
    str x21, [x0, #16]   ; payload_ptr
    
    ; Get sender ID from TLS
    mrs x1, tpidr_el0
    ldr w1, [x1, #THREAD_ID_OFFSET]
    str w1, [x0, #24]    ; sender_id
    
    str w22, [x0, #28]   ; priority
    
    ; Signal waiting threads if high priority
    cmp w22, #PRIORITY_HIGH
    b.lt .done
    bl wake_event_processors
    
.done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
```

### Task 2: Event Routing System
```assembly
.global route_events
route_events:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    
    ; Process event queue
.process_loop:
    bl get_next_event
    cbz x0, .no_more_events
    
    mov x19, x0  ; event pointer
    
    ; Load event type
    ldr w20, [x19, #0]
    
    ; Route by type
    cmp w20, #EVENT_TYPE_INPUT
    b.eq .route_input
    cmp w20, #EVENT_TYPE_SIMULATION
    b.eq .route_simulation
    cmp w20, #EVENT_TYPE_GRAPHICS
    b.eq .route_graphics
    cmp w20, #EVENT_TYPE_SYSTEM
    b.eq .route_system
    
    ; Unknown event type
    b .next_event
    
.route_input:
    mov x0, x19
    bl dispatch_input_event
    b .next_event
    
.route_simulation:
    mov x0, x19
    bl dispatch_simulation_event
    b .next_event
    
.route_graphics:
    mov x0, x19
    bl dispatch_graphics_event
    b .next_event
    
.route_system:
    mov x0, x19
    bl dispatch_system_event
    
.next_event:
    ; Mark event as processed
    mov x0, x19
    bl release_event
    b .process_loop
    
.no_more_events:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
```

### Task 3: Input → Simulation Pipeline
```assembly
.global input_event_handler
input_event_handler:
    ; x0 = event pointer
    
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    
    mov x19, x0
    ldr w20, [x19, #4]  ; subtype
    
    ; Handle input types
    cmp w20, #INPUT_MOUSE_CLICK
    b.eq .handle_click
    cmp w20, #INPUT_KEY_PRESS
    b.eq .handle_key
    cmp w20, #INPUT_GESTURE
    b.eq .handle_gesture
    
.handle_click:
    ; Convert to world coordinates
    ldr x0, [x19, #16]  ; payload
    bl screen_to_world_coords
    
    ; Check what was clicked
    bl query_world_at_position
    
    ; Generate simulation event
    mov x0, #EVENT_TYPE_SIMULATION
    mov x1, #SIM_OBJECT_SELECTED
    mov x2, x0  ; query result
    mov x3, #PRIORITY_NORMAL
    bl post_event
    b .done
    
.handle_key:
    ldr x0, [x19, #16]
    ldr w0, [x0]  ; key code
    
    ; Map to simulation command
    bl map_key_to_command
    cbz x0, .done
    
    ; Post command event
    mov x1, x0
    mov x0, #EVENT_TYPE_SIMULATION
    mov x2, xzr
    mov x3, #PRIORITY_NORMAL
    bl post_event
    b .done
    
.handle_gesture:
    ; Process gesture
    ldr x0, [x19, #16]
    bl process_gesture
    
.done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
```

### Task 4: Simulation → Graphics Pipeline
```assembly
.global simulation_to_graphics_events
simulation_to_graphics_events:
    ; Called after simulation update
    
    stp x29, x30, [sp, #-16]!
    
    ; Check for visual changes
    bl get_dirty_entities
    cbz x0, .no_updates
    
    mov x19, x0  ; count
    mov x20, x1  ; array
    
    ; Batch graphics updates
    mov x0, #EVENT_TYPE_GRAPHICS
    mov x1, #GFX_ENTITY_UPDATE
    mov x2, x20
    mov x3, #PRIORITY_HIGH
    bl post_event
    
.no_updates:
    ; Check for effect triggers
    bl get_triggered_effects
    cbz x0, .no_effects
    
    mov x0, #EVENT_TYPE_GRAPHICS
    mov x1, #GFX_PARTICLE_SPAWN
    mov x2, x1
    mov x3, #PRIORITY_NORMAL
    bl post_event
    
.no_effects:
    ldp x29, x30, [sp], #16
    ret
```

### Task 5: Event Filtering and Priority
```assembly
.data
.align 3
event_filters:
    .space 256  ; 32 filter slots * 8 bytes

filter_count:
    .word 0

.text
.global register_event_filter
register_event_filter:
    ; x0 = event_type_mask
    ; x1 = filter_function
    
    adrp x2, filter_count
    ldr w3, [x2, :lo12:filter_count]
    
    cmp w3, #32
    b.ge .filter_full
    
    ; Store filter
    adrp x4, event_filters
    add x4, x4, :lo12:event_filters
    add x4, x4, x3, lsl #4
    
    str x0, [x4]      ; mask
    str x1, [x4, #8]  ; function
    
    ; Increment count
    add w3, w3, #1
    str w3, [x2, :lo12:filter_count]
    
    mov x0, #0  ; success
    ret
    
.filter_full:
    mov x0, #-1  ; error
    ret

.global apply_event_filters
apply_event_filters:
    ; x0 = event pointer
    ; Returns: 1 if event should be processed, 0 if filtered
    
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    
    mov x19, x0
    ldr w20, [x19]  ; event type
    
    ; Check all filters
    adrp x0, filter_count
    ldr w21, [x0, :lo12:filter_count]
    
    adrp x22, event_filters
    add x22, x22, :lo12:event_filters
    
.filter_loop:
    cbz w21, .not_filtered
    
    ; Check mask
    ldr x0, [x22]
    tst x0, x20
    b.eq .next_filter
    
    ; Call filter function
    ldr x1, [x22, #8]
    mov x0, x19
    blr x1
    
    ; If filtered (returns 0), exit
    cbz x0, .filtered
    
.next_filter:
    add x22, x22, #16
    sub w21, w21, #1
    b .filter_loop
    
.not_filtered:
    mov x0, #1
    b .done
    
.filtered:
    mov x0, #0
    
.done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
```

## Event Type Definitions

```assembly
; Event type constants
.equ EVENT_TYPE_INPUT,      0x00000001
.equ EVENT_TYPE_SIMULATION, 0x00000002
.equ EVENT_TYPE_GRAPHICS,   0x00000004
.equ EVENT_TYPE_SYSTEM,     0x00000008
.equ EVENT_TYPE_AUDIO,      0x00000010
.equ EVENT_TYPE_NETWORK,    0x00000020
.equ EVENT_TYPE_DEBUG,      0x00000040

; Input subtypes
.equ INPUT_MOUSE_CLICK,     0x00000001
.equ INPUT_MOUSE_MOVE,      0x00000002
.equ INPUT_KEY_PRESS,       0x00000004
.equ INPUT_GESTURE,         0x00000008

; Simulation subtypes
.equ SIM_ENTITY_SPAWN,      0x00000001
.equ SIM_ENTITY_DESTROY,    0x00000002
.equ SIM_ZONE_CHANGE,       0x00000004
.equ SIM_ECONOMY_UPDATE,    0x00000008

; Priority levels
.equ PRIORITY_CRITICAL,     3
.equ PRIORITY_HIGH,         2
.equ PRIORITY_NORMAL,       1
.equ PRIORITY_LOW,          0
```

## Performance Considerations

### Lock-Free Design
- Compare-and-swap operations
- Memory barriers for ordering
- Per-thread event pools
- Wait-free readers

### Batch Processing
- Coalesce similar events
- Process in priority order
- Amortize dispatch overhead
- Cache-friendly iteration

### Memory Management
- Pre-allocated event pools
- Ring buffer recycling
- Payload lifetime tracking
- Zero-copy where possible

## Integration Points

### All Modules
- Standard event posting API
- Handler registration
- Filter installation
- Performance monitoring

## Success Metrics
1. < 100ns event post latency
2. 1M+ events/second throughput
3. Zero event loss
4. Minimal memory overhead
5. Clean module decoupling

## Timeline
- Day 1: Core event bus
- Day 2: Event routing
- Day 3: Input pipeline
- Day 4: Inter-module wiring
- Day 5: Testing and optimization