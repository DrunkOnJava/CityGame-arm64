# Sub-Agent 2: Memory Integration Engineer Plan

## Objective
Wire TLSF allocator to all modules, set up thread-local pools, configure agent allocator for 1M+ entities, implement memory pressure handling.

## Memory Architecture Overview

### Hierarchical Memory System
1. **TLSF Main Allocator** (tlsf_allocator.s)
   - Global heap management
   - O(1) allocation/deallocation
   - 4GB total budget
   - Fragmentation resistant

2. **Thread-Local Allocators** (tls_allocator.s)
   - Per-thread memory pools
   - Lock-free allocation
   - Cache-line aligned
   - 64MB per thread

3. **Agent Pool Allocator** (agent_allocator.s)
   - Fixed-size pools for entities
   - Zero-fragmentation
   - Bulk allocation support
   - 1M+ agent capacity

4. **Specialized Allocators**
   - Slab allocator for small objects
   - Pool allocator for graphics
   - Ring buffers for streaming

## Integration Tasks

### Task 1: Global Memory Layout
```assembly
; Memory map for 4GB budget
; 0x000000000 - 0x040000000: TLSF main heap (1GB)
; 0x040000000 - 0x080000000: Agent pools (1GB)
; 0x080000000 - 0x0C0000000: Graphics buffers (1GB)
; 0x0C0000000 - 0x100000000: Thread-local + misc (1GB)

.global memory_layout
memory_layout:
    .quad 0x000000000  ; tlsf_base
    .quad 0x040000000  ; tlsf_size
    .quad 0x040000000  ; agent_pool_base
    .quad 0x040000000  ; agent_pool_size
    .quad 0x080000000  ; graphics_base
    .quad 0x040000000  ; graphics_size
    .quad 0x0C0000000  ; tls_base
    .quad 0x040000000  ; tls_size
```

### Task 2: Module Memory Interface
```assembly
; Standard memory interface for all modules
.global module_memory_init
module_memory_init:
    ; x0 = module_id
    ; x1 = requested_size
    ; x2 = flags (TLS, CACHED, etc)
    
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    mov x19, x0  ; Save module_id
    mov x20, x1  ; Save size
    mov x21, x2  ; Save flags
    
    ; Check if TLS requested
    tst x21, #MODULE_FLAG_TLS
    b.ne .allocate_tls
    
    ; Standard TLSF allocation
    mov x0, x20
    bl tlsf_malloc
    cbz x0, .allocation_failed
    
    ; Register allocation
    mov x1, x0
    mov x0, x19
    mov x2, x20
    bl register_module_memory
    
    b .init_complete
    
.allocate_tls:
    ; Get current thread ID
    mrs x0, tpidr_el0
    bl get_thread_local_pool
    
    ; Allocate from TLS pool
    mov x1, x20
    bl tls_allocate
    
.init_complete:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
```

### Task 3: Agent Pool Configuration
```assembly
; Configure pools for 1M+ agents
.global configure_agent_pools
configure_agent_pools:
    ; Agent sizes and counts
    ; Citizens: 256 bytes × 500,000
    ; Vehicles: 128 bytes × 200,000
    ; Buildings: 512 bytes × 300,000
    ; Roads: 64 bytes × 100,000
    
    ; Initialize citizen pool
    adrp x0, agent_pool_base
    ldr x0, [x0, :lo12:agent_pool_base]
    mov x1, #256        ; size
    mov x2, #500000     ; count
    bl init_pool
    
    ; Initialize vehicle pool
    add x0, x0, #(256 * 500000)
    mov x1, #128
    mov x2, #200000
    bl init_pool
    
    ; Continue for other entity types...
    ret
```

### Task 4: Memory Pressure System
```assembly
.global memory_pressure_monitor
memory_pressure_monitor:
    ; Check memory usage every frame
    bl get_total_allocated
    mov x19, x0
    
    ; Calculate percentage (x19 / 4GB * 100)
    lsr x0, x19, #30  ; Rough percentage
    
    ; Pressure levels
    cmp x0, #90
    b.ge .critical_pressure
    cmp x0, #75
    b.ge .high_pressure
    cmp x0, #50
    b.ge .medium_pressure
    
    ; Normal operation
    mov x0, #PRESSURE_NORMAL
    ret
    
.critical_pressure:
    ; Trigger emergency GC
    bl emergency_garbage_collect
    bl reduce_agent_spawn_rate
    bl disable_particle_effects
    mov x0, #PRESSURE_CRITICAL
    ret
    
.high_pressure:
    ; Reduce allocations
    bl compact_memory_pools
    bl reduce_texture_quality
    mov x0, #PRESSURE_HIGH
    ret
    
.medium_pressure:
    ; Preventive measures
    bl defragment_pools
    mov x0, #PRESSURE_MEDIUM
    ret
```

### Task 5: Module Integration Points

#### Graphics Integration
```assembly
; Vertex buffer allocation
.global alloc_vertex_buffer
alloc_vertex_buffer:
    ; x0 = vertex count
    ; Returns buffer pointer
    
    ; Calculate size (vertex_count * vertex_size)
    mov x1, #48  ; sizeof(vertex)
    mul x0, x0, x1
    
    ; Align to page boundary
    add x0, x0, #4095
    and x0, x0, #~4095
    
    ; Allocate from graphics pool
    adrp x1, graphics_pool
    ldr x1, [x1, :lo12:graphics_pool]
    bl pool_alloc_aligned
    
    ret
```

#### Simulation Integration
```assembly
; ECS component allocation
.global alloc_component_array
alloc_component_array:
    ; x0 = component_type
    ; x1 = entity_count
    
    ; Get component size
    bl get_component_size
    mul x1, x1, x0
    
    ; Allocate contiguous array
    mov x0, x1
    bl tlsf_malloc
    
    ret
```

## Memory Budgets

### Per-Subsystem Allocation
- **Simulation**: 1.5GB
  - Entities: 500MB
  - Components: 500MB
  - Spatial grid: 300MB
  - Pathfinding: 200MB

- **Graphics**: 1GB
  - Vertex buffers: 400MB
  - Texture cache: 300MB
  - Command buffers: 200MB
  - Particles: 100MB

- **AI**: 800MB
  - Behavior trees: 200MB
  - Navigation mesh: 300MB
  - Path cache: 200MB
  - Decision data: 100MB

- **Audio**: 200MB
  - Sample buffers: 150MB
  - Spatial data: 50MB

- **System**: 500MB
  - Save data: 200MB
  - Temp buffers: 200MB
  - Debug: 100MB

## Performance Optimizations

### Cache-Friendly Allocation
- Align allocations to cache lines (64 bytes)
- Group related data together
- Use memory pools for hot data
- Minimize pointer chasing

### NUMA Awareness
- Detect CPU topology
- Allocate thread-local data on same NUMA node
- Balance memory access across nodes

### Zero-Copy Strategies
- Share buffers between subsystems
- Use memory mapping for large data
- Implement copy-on-write for saves

## Success Metrics
1. < 10ns average allocation time
2. < 5% memory fragmentation
3. Zero allocation failures under pressure
4. Stable 60 FPS with full memory usage
5. < 100ms for full GC cycle

## Coordination Points
- **Sub-Agent 1**: Memory init sequence
- **Sub-Agent 3**: ECS memory layout
- **Sub-Agent 4**: Graphics buffer management
- **Sub-Agent 7**: Memory profiling hooks