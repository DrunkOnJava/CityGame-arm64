# SimCity ARM64: Pure Assembly Conversion Roadmap
## 25 Parallel Agent Architecture

This document outlines the complete transformation of our mixed C/Objective-C/GLSL SimCity implementation into a pure ARM64 assembly (.s) codebase, structured for execution by 25 parallel Claude Code agents.

## Agent Allocation Strategy

### Core Agent Groups (5 Groups × 5 Agents = 25 Total)

#### Group A: Simulation Core Team (Agents 1-5)
**Lead Agent**: A1 - Simulation Architect
- **A1**: Core tick dispatcher, ABI definition, module boundaries
- **A2**: Zoning system conversion & NEON optimization
- **A3**: Utilities system flood-fill & coverage calculations  
- **A4**: RCI demand & growth simulation
- **A5**: Entity/agent management system

#### Group B: Graphics Pipeline Team (Agents 6-10)
**Lead Agent**: B1 - Renderer Architect
- **B1**: Metal pipeline setup, shader → ASM conversion
- **B2**: Sprite batching & texture atlas management
- **B3**: Isometric transformation & depth sorting
- **B4**: Particle systems & animation framework
- **B5**: Debug overlay & performance visualization

#### Group C: AI & Pathfinding Team (Agents 11-15)
**Lead Agent**: C1 - AI Systems Architect
- **C1**: A* pathfinder core implementation
- **C2**: Traffic flow & congestion algorithms
- **C3**: Citizen behavior & daily routines
- **C4**: Emergency services pathfinding
- **C5**: Mass transit route optimization

#### Group D: Infrastructure Team (Agents 16-20)
**Lead Agent**: D1 - Infrastructure Architect
- **D1**: Memory allocator (TLSF) implementation
- **D2**: Network graph algorithms (power/water)
- **D3**: Save/load system & serialization
- **D4**: Audio system & spatial sound
- **D5**: Input handling & event dispatch

#### Group E: Platform Integration Team (Agents 21-25)
**Lead Agent**: E1 - Platform Architect
- **E1**: Cocoa/Metal bootstrap & main loop
- **E2**: Objective-C runtime bridge
- **E3**: System call wrappers & OS integration
- **E4**: Threading & synchronization primitives
- **E5**: Build system & toolchain integration

## Phase 1: Foundation Layer (Week 1)
**Critical Path**: Groups D & E must complete first

### D1: Memory Allocator Implementation
```asm
; src/memory/tlsf_allocator.s
.section __TEXT,__text,regular,pure_instructions
.align 4
.global _tlsf_init, _tlsf_malloc, _tlsf_free

; Constants
.equ BLOCK_HEADER_SIZE, 16
.equ MIN_BLOCK_SIZE, 32
.equ FL_INDEX_COUNT, 32
.equ SL_INDEX_COUNT, 32

; Data structures in .bss
.section __DATA,__bss
.align 4
_tlsf_control:
    .zero 8192  ; Control structure
_free_lists:
    .zero FL_INDEX_COUNT * SL_INDEX_COUNT * 8
```

**Deliverables**:
- Complete TLSF allocator with < 100ns malloc/free
- Thread-local allocation pools
- Debug heap validation routines

### E1-E3: Platform Bootstrap
```asm
; src/platform/bootstrap.s
.section __TEXT,__text,regular,pure_instructions
.align 4
.global _main

_main:
    ; Initialize stack frame
    sub sp, sp, #32
    stp x29, x30, [sp, #16]
    
    ; Create autorelease pool
    bl _objc_autoreleasePoolPush
    mov x19, x0  ; Save pool
    
    ; Get NSApplication class
    adrp x0, L_OBJC_CLASS_NSApplication@PAGE
    ldr x0, [x0, L_OBJC_CLASS_NSApplication@PAGEOFF]
    
    ; Get sharedApplication selector  
    adrp x1, L_sel_sharedApplication@PAGE
    ldr x1, [x1, L_sel_sharedApplication@PAGEOFF]
    
    ; Call [NSApplication sharedApplication]
    bl _objc_msgSend
    mov x20, x0  ; Save app instance
```

### A1: Core Module Structure
```asm
; src/simulation/core.s
.section __TEXT,__text,regular,pure_instructions
.align 4

; Module dispatch table
.section __DATA,__const
.align 3
_simulation_modules:
    .quad _zoning_init,     _zoning_tick,     _zoning_cleanup
    .quad _utilities_init,  _utilities_tick,  _utilities_cleanup
    .quad _rci_init,        _rci_tick,        _rci_cleanup
    .quad _entity_init,     _entity_tick,     _entity_cleanup
    .quad 0  ; Sentinel

.global _simulation_init
_simulation_init:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    ; Initialize all modules
    adrp x19, _simulation_modules@PAGE
    add x19, x19, _simulation_modules@PAGEOFF
    
init_loop:
    ldr x0, [x19], #24  ; Load init function
    cbz x0, init_done
    blr x0              ; Call init
    b init_loop
    
init_done:
    ldp x29, x30, [sp], #16
    ret
```

## Phase 2: Core Systems (Week 2)
**Dependencies**: Phase 1 complete

### A2-A5: Simulation Systems

#### A2: Zoning System with NEON
```asm
; src/simulation/zoning_neon.s
.global _zoning_tick_neon
_zoning_tick_neon:
    ; x0 = grid_ptr, x1 = width, x2 = height
    
    ; Process 4x4 tile blocks with NEON
    mov x3, #0  ; row
row_loop:
    mov x4, #0  ; col
col_loop:
    ; Calculate base address for 4x4 block
    madd x5, x3, x1, x4  ; offset = row * width + col
    lsl x5, x5, #6       ; * sizeof(Tile)
    add x5, x0, x5       ; tile_ptr = grid_ptr + offset
    
    ; Load 4 tiles' zone types
    ld4 {v0.4s, v1.4s, v2.4s, v3.4s}, [x5]
    
    ; Check residential zones (type == 1)
    movi v16.4s, #1
    cmeq v4.4s, v0.4s, v16.4s
    
    ; Apply growth factors
    ld1 {v17.4s}, [x5, #16]  ; Load density
    fmul v17.4s, v17.4s, v18.4s  ; Growth multiplier
    
    ; Store back
    st1 {v17.4s}, [x5, #16]
    
    add x4, x4, #4
    cmp x4, x1
    b.lt col_loop
    
    add x3, x3, #4
    cmp x3, x2
    b.lt row_loop
    
    ret
```

#### A3: Flood-Fill Utilities
```asm
; src/simulation/utilities_flood.s
.global _flood_fill_power_neon
_flood_fill_power_neon:
    ; x0 = grid, x1 = queue, x2 = width, x3 = height
    
    ; Initialize queue pointers
    mov x4, #0  ; queue_head
    mov x5, #0  ; queue_tail
    
    ; Find all power sources
source_scan:
    ld1 {v0.16b}, [x0], #16
    movi v1.16b, #POWER_SOURCE
    cmeq v2.16b, v0.16b, v1.16b
    
    ; Extract lane mask
    umov x6, v2.d[0]
    cbz x6, next_chunk
    
    ; Add sources to queue
    rbit x6, x6  ; Reverse for ctz
    clz x7, x6   ; Count trailing zeros
    ; ... enqueue logic ...
    
next_chunk:
    subs x3, x3, #16
    b.gt source_scan
    
    ; BFS with distance decay
bfs_loop:
    cmp x4, x5
    b.eq done
    
    ; Dequeue
    ldr w8, [x1, x4, lsl #2]
    add x4, x4, #1
    
    ; Process 4 neighbors in parallel
    ; North, South, East, West offsets
    adrp x9, neighbor_offsets@PAGE
    add x9, x9, neighbor_offsets@PAGEOFF
    ld1 {v0.4s}, [x9]
    
    ; ... neighbor processing ...
    
    b bfs_loop
done:
    ret
```

### B1-B5: Graphics Pipeline

#### B1: Metal Command Encoder
```asm
; src/graphics/metal_encoder.s
.global _encode_draw_commands
_encode_draw_commands:
    ; x0 = command_buffer, x1 = render_encoder
    ; x2 = vertex_buffer, x3 = index_buffer
    
    ; Set render pipeline state
    adrp x4, _pipeline_state@PAGE
    ldr x4, [x4, _pipeline_state@PAGEOFF]
    
    adrp x5, L_sel_setRenderPipelineState@PAGE
    ldr x5, [x5, L_sel_setRenderPipelineState@PAGEOFF]
    
    mov x0, x1  ; encoder
    mov x1, x5  ; selector
    mov x2, x4  ; pipeline
    bl _objc_msgSend
    
    ; Set vertex buffer
    adrp x5, L_sel_setVertexBuffer_offset_atIndex@PAGE
    ldr x5, [x5, L_sel_setVertexBuffer_offset_atIndex@PAGEOFF]
    
    mov x0, x1  ; encoder
    mov x1, x5  ; selector
    mov x2, x2  ; vertex_buffer
    mov x3, #0  ; offset
    mov x4, #0  ; index
    bl _objc_msgSend
    
    ret
```

#### B2: Sprite Batching System
```asm
; src/graphics/sprite_batch.s
.global _batch_sprites
_batch_sprites:
    ; x0 = sprite_list, x1 = count, x2 = vertex_out
    
    ; Process 4 sprites at once
    lsr x3, x1, #2  ; count / 4
    
batch_loop:
    cbz x3, done
    
    ; Load 4 sprite descriptors
    ld4 {v0.4s, v1.4s, v2.4s, v3.4s}, [x0], #64
    
    ; Extract x, y positions
    uzp1 v4.4s, v0.4s, v1.4s  ; x0,x1,x2,x3
    uzp2 v5.4s, v0.4s, v1.4s  ; y0,y1,y2,y3
    
    ; Convert to isometric
    fsub v6.4s, v4.4s, v5.4s  ; x - y
    fadd v7.4s, v4.4s, v5.4s  ; x + y
    
    fmov v8.4s, #0.1
    fmov v9.4s, #0.05
    fmul v6.4s, v6.4s, v8.4s  ; isoX
    fmul v7.4s, v7.4s, v9.4s  ; isoY
    
    ; Generate 6 vertices per sprite (2 triangles)
    ; ... vertex generation ...
    
    sub x3, x3, #1
    b batch_loop
    
done:
    ret
```

### C1-C5: AI & Pathfinding

#### C1: A* Core Implementation
```asm
; src/ai/astar_core.s
.section __DATA,__bss
.align 4
_heap_nodes:
    .zero 65536 * 16  ; {x,y,g,f} for each node
_heap_size:
    .zero 8
_parent_map:
    .zero 1024 * 1024 * 2  ; 1024x1024 grid parent pointers

.section __TEXT,__text,regular,pure_instructions
.global _astar_find_path
_astar_find_path:
    ; x0 = start_x, x1 = start_y
    ; x2 = goal_x, x3 = goal_y
    ; x4 = grid_ptr, x5 = out_path
    
    stp x29, x30, [sp, #-64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    
    ; Initialize heap
    adrp x19, _heap_size@PAGE
    str xzr, [x19, _heap_size@PAGEOFF]
    
    ; Push start node
    mov x20, x0  ; start_x
    mov x21, x1  ; start_y
    mov x22, x2  ; goal_x  
    mov x23, x3  ; goal_y
    
    ; Calculate heuristic
    sub x6, x22, x20
    sub x7, x23, x21
    
    ; Absolute values
    cmp x6, #0
    cneg x6, x6, lt
    cmp x7, #0
    cneg x7, x7, lt
    
    ; Manhattan distance
    add x8, x6, x7
    
    ; Push to heap
    bl _heap_push
    
search_loop:
    ; Pop best node
    bl _heap_pop
    cbz x0, no_path
    
    ; Check if goal
    cmp x0, x22
    ccmp x1, x23, #0, eq
    b.eq found_path
    
    ; Explore neighbors (unrolled)
    ; North
    sub x1, x1, #1
    bl _process_neighbor
    add x1, x1, #1
    
    ; South  
    add x1, x1, #1
    bl _process_neighbor
    sub x1, x1, #1
    
    ; East
    add x0, x0, #1
    bl _process_neighbor
    sub x0, x0, #1
    
    ; West
    sub x0, x0, #1
    bl _process_neighbor
    add x0, x0, #1
    
    b search_loop
    
found_path:
    ; Reconstruct path
    bl _reconstruct_path
    
no_path:
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x23, x24, [sp, #48]
    ldp x29, x30, [sp], #64
    ret
```

## Phase 3: Integration Layer (Week 3)
**Dependencies**: Phases 1-2 complete

### Integration Points

#### Inter-Agent Communication Protocol
```asm
; src/ipc/agent_comm.s
.section __DATA,__data
.align 4
_agent_mailboxes:
    .zero 25 * 1024  ; 1KB per agent

.global _agent_send_message
_agent_send_message:
    ; x0 = target_agent, x1 = message_ptr, x2 = size
    
    ; Calculate mailbox address
    lsl x3, x0, #10  ; agent * 1024
    adrp x4, _agent_mailboxes@PAGE
    add x4, x4, _agent_mailboxes@PAGEOFF
    add x4, x4, x3
    
    ; Atomic write message
    ldaxr x5, [x4]      ; Load exclusive
    cbnz x5, retry      ; Mailbox full, retry
    stlxr w6, x1, [x4]  ; Store exclusive
    cbnz w6, retry
    
    ret
    
retry:
    yield
    b _agent_send_message
```

#### Synchronization Barriers
```asm
; src/sync/barriers.s
.section __DATA,__bss
.align 4
_phase_barriers:
    .zero 5 * 8  ; 5 phases

.global _agent_barrier_wait
_agent_barrier_wait:
    ; x0 = phase_id, x1 = agent_id
    
    ; Get barrier address
    adrp x2, _phase_barriers@PAGE
    add x2, x2, _phase_barriers@PAGEOFF
    add x2, x2, x0, lsl #3
    
    ; Atomic decrement
    ldaxr x3, [x2]
    sub x3, x3, #1
    stlxr w4, x3, [x2]
    cbnz w4, _agent_barrier_wait
    
    ; Check if last agent
    cbnz x3, wait_loop
    
    ; Last agent, reset barrier
    mov x3, #25
    str x3, [x2]
    ret
    
wait_loop:
    ; Spin wait
    ldar x3, [x2]
    cmp x3, #25
    b.ne wait_loop
    ret
```

## Phase 4: Optimization & Testing (Week 4)
**All agents participate**

### Performance Optimization Checklist

#### Per-Agent Optimization Tasks
1. **Instruction Scheduling**
   - Reorder instructions to avoid pipeline stalls
   - Interleave memory loads with computation
   - Use load-pair/store-pair instructions

2. **Cache Optimization**
   - Align hot data structures to cache lines (64B)
   - Prefetch next iteration data
   - Pack related data together

3. **NEON Vectorization**
   - Convert scalar loops to NEON where possible
   - Use horizontal operations sparingly
   - Prefer integer SIMD for control flow

4. **Branch Prediction**
   - Use conditional select (csel) over branches
   - Unroll small loops completely
   - Add likely/unlikely hints

### Testing Framework
```asm
; src/test/framework.s
.global _run_unit_tests
_run_unit_tests:
    ; Each agent runs its own test suite
    mov x19, x0  ; agent_id
    
    ; Get test table for agent
    adrp x20, _agent_test_tables@PAGE
    add x20, x20, _agent_test_tables@PAGEOFF
    ldr x20, [x20, x19, lsl #3]
    
test_loop:
    ldr x21, [x20], #16  ; Test function
    cbz x21, tests_done
    
    ldr x22, [x20], #16  ; Expected result
    
    ; Run test
    blr x21
    
    ; Check result
    cmp x0, x22
    b.ne test_failed
    
    b test_loop
    
test_failed:
    ; Log failure
    mov x0, x19  ; agent_id
    mov x1, x21  ; test_ptr
    bl _log_test_failure
    
tests_done:
    ret
```

## Phase 5: Final Integration (Week 5)

### Master Control Program
```asm
; src/master/control.s
.global _simcity_main
_simcity_main:
    ; Initialize all 25 agents
    mov x19, #0
agent_init_loop:
    mov x0, x19
    bl _agent_spawn
    add x19, x19, #1
    cmp x19, #25
    b.lt agent_init_loop
    
    ; Wait for initialization
    mov x0, #0  ; PHASE_INIT
    mov x1, #0  ; master thread
    bl _agent_barrier_wait
    
    ; Main simulation loop
main_loop:
    ; Update simulation (agents 1-5)
    mov x0, #1  ; PHASE_SIMULATE
    bl _trigger_phase
    
    ; Update graphics (agents 6-10)
    mov x0, #2  ; PHASE_RENDER
    bl _trigger_phase
    
    ; Update AI (agents 11-15)
    mov x0, #3  ; PHASE_AI
    bl _trigger_phase
    
    ; Check exit condition
    bl _should_exit
    cbnz x0, shutdown
    
    b main_loop
    
shutdown:
    ; Cleanup all agents
    mov x0, #4  ; PHASE_SHUTDOWN
    bl _trigger_phase
    
    ret
```

## Deliverables per Agent

### Agent Output Structure
Each agent produces:
```
/src/agent_XX/
├── core.s          # Main implementation
├── tests.s         # Unit tests
├── benchmarks.s    # Performance tests
├── interface.s     # Public API
└── README.md       # Documentation
```

### Communication Artifacts
```
/src/shared/
├── abi.s           # Shared ABI definitions
├── constants.s     # Global constants
├── macros.s        # Common macros
└── sync.s          # Synchronization primitives
```

## Timeline & Milestones

### Week 1: Foundation (Agents 16-25)
- Day 1-2: Memory allocator, platform bootstrap
- Day 3-4: Threading, system calls
- Day 5: Integration testing

### Week 2: Core Systems (Agents 1-15)
- Day 1-2: Simulation core
- Day 3-4: Graphics pipeline
- Day 5: AI pathfinding

### Week 3: Integration (All Agents)
- Day 1-2: Communication setup
- Day 3-4: Synchronization testing
- Day 5: Performance baseline

### Week 4: Optimization (All Agents)
- Day 1-3: NEON vectorization
- Day 4-5: Cache optimization

### Week 5: Polish & Ship (All Agents)
- Day 1-2: Final integration
- Day 3-4: Stress testing
- Day 5: Documentation

## Success Metrics

### Performance Targets
- 1M+ agents at 60 FPS
- < 4GB memory usage
- < 50% CPU usage on M1
- Zero heap allocations in hot path

### Code Quality Metrics
- 100% pure ARM64 assembly
- Zero external dependencies
- < 100KB binary size
- All tests passing

## Agent Coordination Rules

1. **No Direct File Access**: Agents only modify their assigned files
2. **Message Passing Only**: No shared memory between agents
3. **Atomic Operations**: All cross-agent data uses atomics
4. **Barrier Synchronization**: Wait at phase boundaries
5. **Test Independence**: Each agent's tests run in isolation

## Risk Mitigation

### Technical Risks
1. **Register Pressure**: Use x19-x28 carefully
2. **Stack Overflow**: Fixed 64KB stacks per agent
3. **Race Conditions**: Extensive barrier testing
4. **ABI Mismatches**: Strict validation tools

### Process Risks
1. **Agent Failure**: Automatic restart with checkpoint
2. **Integration Conflicts**: Daily merge windows
3. **Performance Regression**: Continuous benchmarking
4. **Documentation Lag**: Inline assembly comments

This comprehensive plan enables 25 parallel agents to transform the entire SimCity codebase into pure ARM64 assembly in 5 weeks, with clear ownership, dependencies, and deliverables for each agent.