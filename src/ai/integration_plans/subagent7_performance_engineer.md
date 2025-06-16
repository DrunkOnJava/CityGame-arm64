# Sub-Agent 7: Performance Validation Engineer Plan

## Objective
Create system-level benchmarks, profile integrated components, identify bottlenecks, validate 1M+ agents at 60 FPS.

## Performance Architecture

### Benchmarking Framework
1. **Micro Benchmarks**
   - Function-level timing
   - Instruction counting
   - Cache performance
   - Memory bandwidth

2. **System Benchmarks**
   - End-to-end latency
   - Throughput testing
   - Scalability analysis
   - Stress testing

3. **Profiling Tools**
   - CPU cycle counters
   - Cache miss tracking
   - Memory allocation
   - Thread contention

## Implementation Tasks

### Task 1: Performance Monitoring Framework
```assembly
.global perf_init
.align 4

.data
.align 6
perf_counters:
    .space 4096  ; 512 counters * 8 bytes

counter_names:
    .space 16384 ; Counter name strings

.text
perf_init:
    stp x29, x30, [sp, #-16]!
    
    ; Enable user-space counter access
    mrs x0, PMCR_EL0
    orr x0, x0, #0x1  ; Enable
    msr PMCR_EL0, x0
    
    ; Reset all counters
    mov x0, #0x8000001F
    msr PMCNTENSET_EL0, x0
    
    ; Initialize counter storage
    adrp x0, perf_counters
    add x0, x0, :lo12:perf_counters
    mov x1, #512
.clear_loop:
    str xzr, [x0], #8
    subs x1, x1, #1
    b.ne .clear_loop
    
    ldp x29, x30, [sp], #16
    ret

.global perf_start_timer
perf_start_timer:
    ; x0 = counter_id
    
    ; Read cycle counter
    mrs x1, PMCCNTR_EL0
    
    ; Store start time
    adrp x2, perf_counters
    add x2, x2, :lo12:perf_counters
    str x1, [x2, x0, lsl #3]
    
    ret

.global perf_end_timer
perf_end_timer:
    ; x0 = counter_id
    ; Returns cycles in x0
    
    ; Read cycle counter
    mrs x1, PMCCNTR_EL0
    
    ; Get start time
    adrp x2, perf_counters
    add x2, x2, :lo12:perf_counters
    ldr x3, [x2, x0, lsl #3]
    
    ; Calculate delta
    sub x0, x1, x3
    
    ; Update running average
    ldr x4, [x2, x0, lsl #3]
    add x4, x4, x0
    lsr x4, x4, #1
    str x4, [x2, x0, lsl #3]
    
    ret
```

### Task 2: System Benchmark Suite
```assembly
.global benchmark_full_frame
benchmark_full_frame:
    stp x29, x30, [sp, #-64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    
    ; Start frame timer
    mov x0, #COUNTER_FRAME_TIME
    bl perf_start_timer
    
    ; Input processing
    mov x0, #COUNTER_INPUT
    bl perf_start_timer
    bl process_all_input
    mov x0, #COUNTER_INPUT
    bl perf_end_timer
    
    ; Simulation update
    mov x0, #COUNTER_SIMULATION
    bl perf_start_timer
    bl simulation_update
    mov x0, #COUNTER_SIMULATION
    bl perf_end_timer
    
    ; AI updates
    mov x0, #COUNTER_AI
    bl perf_start_timer
    bl ai_system_update
    mov x0, #COUNTER_AI
    bl perf_end_timer
    
    ; Rendering
    mov x0, #COUNTER_RENDER
    bl perf_start_timer
    bl render_frame
    mov x0, #COUNTER_RENDER
    bl perf_end_timer
    
    ; Total frame time
    mov x0, #COUNTER_FRAME_TIME
    bl perf_end_timer
    
    ; Check if we hit target
    mov x19, x0
    mov x0, #16666  ; 60 FPS = 16.666ms
    cmp x19, x0
    b.gt .frame_miss
    
    mov x0, #1  ; Success
    b .done
    
.frame_miss:
    ; Log frame miss
    mov x0, x19
    bl log_frame_miss
    mov x0, #0  ; Failure
    
.done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret
```

### Task 3: Entity Scaling Benchmark
```assembly
.global benchmark_entity_scaling
benchmark_entity_scaling:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    ; Test with increasing entity counts
    mov x19, #1000   ; Start with 1K
    mov x20, #10     ; 10 iterations
    
.scale_loop:
    ; Spawn entities
    mov x0, x19
    bl spawn_test_entities
    
    ; Run 100 frames
    mov x21, #100
.frame_loop:
    bl benchmark_full_frame
    mov x22, x0  ; Save result
    
    subs x21, x21, #1
    b.ne .frame_loop
    
    ; Log results
    mov x0, x19  ; Entity count
    mov x1, x22  ; Success rate
    bl log_scaling_result
    
    ; Clean up entities
    bl destroy_all_test_entities
    
    ; Increase count
    lsl x19, x19, #1  ; Double
    
    ; Check if we've hit 1M
    mov x0, #1000000
    cmp x19, x0
    b.gt .done
    
    subs x20, x20, #1
    b.ne .scale_loop
    
.done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
```

### Task 4: Memory Profiling
```assembly
.global profile_memory_usage
profile_memory_usage:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    
    ; Get current allocations
    bl tlsf_get_stats
    mov x19, x0  ; Total allocated
    mov x20, x1  ; Peak allocated
    
    ; Get per-module breakdown
    adrp x0, module_memory_stats
    add x0, x0, :lo12:module_memory_stats
    
    ; Graphics memory
    mov x1, #MODULE_GRAPHICS
    bl get_module_memory
    str x0, [x0, #0]
    
    ; Simulation memory
    mov x1, #MODULE_SIMULATION
    bl get_module_memory
    str x0, [x0, #8]
    
    ; AI memory
    mov x1, #MODULE_AI
    bl get_module_memory
    str x0, [x0, #16]
    
    ; Check against budget (4GB)
    mov x0, #0x100000000
    cmp x19, x0
    b.gt .over_budget
    
    ; Calculate percentage
    lsl x0, x19, #8  ; * 256
    lsr x0, x0, #32  ; / 4GB
    
    ; Log usage
    bl log_memory_usage
    
    mov x0, #1  ; Within budget
    b .done
    
.over_budget:
    mov x0, #0  ; Over budget
    
.done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
```

### Task 5: Bottleneck Analysis
```assembly
.global analyze_bottlenecks
analyze_bottlenecks:
    stp x29, x30, [sp, #-16]!
    
    ; Collect all counter data
    bl collect_perf_counters
    
    ; Find slowest component
    adrp x0, perf_counters
    add x0, x0, :lo12:perf_counters
    
    mov x1, #0     ; Max time
    mov x2, #0     ; Max index
    mov x3, #NUM_COUNTERS
    
.find_max:
    ldr x4, [x0], #8
    cmp x4, x1
    b.le .next
    
    mov x1, x4
    sub x4, x3, #NUM_COUNTERS
    neg x2, x4
    
.next:
    subs x3, x3, #1
    b.ne .find_max
    
    ; Generate report
    mov x0, x2
    mov x1, x1
    bl generate_bottleneck_report
    
    ; Suggest optimizations
    mov x0, x2
    bl suggest_optimizations
    
    ldp x29, x30, [sp], #16
    ret
```

## Profiling Integration

### Per-Module Hooks
```assembly
; Macro for profiling any function
.macro PROFILE_START name
    mov x0, #\name
    bl perf_start_timer
.endm

.macro PROFILE_END name
    mov x0, #\name
    bl perf_end_timer
.endm

; Example usage in simulation
simulation_update_profiled:
    PROFILE_START COUNTER_SIM_TOTAL
    
    PROFILE_START COUNTER_SIM_ENTITIES
    bl update_entities
    PROFILE_END COUNTER_SIM_ENTITIES
    
    PROFILE_START COUNTER_SIM_PHYSICS
    bl update_physics
    PROFILE_END COUNTER_SIM_PHYSICS
    
    PROFILE_END COUNTER_SIM_TOTAL
    ret
```

### Cache Performance Monitoring
```assembly
.global monitor_cache_performance
monitor_cache_performance:
    ; Read L1 cache miss counter
    mov x0, #0x03  ; L1D_CACHE_REFILL
    msr PMEVTYPER0_EL0, x0
    
    ; Read L2 cache miss counter
    mov x0, #0x17  ; L2D_CACHE_REFILL
    msr PMEVTYPER1_EL0, x0
    
    ; Enable counters
    mov x0, #0x3
    msr PMCNTENSET_EL0, x0
    
    ret
```

## Performance Targets

### Frame Budget (16.67ms)
- Input: < 0.5ms
- Simulation: < 8ms
- AI: < 3ms
- Graphics: < 4ms
- Audio: < 0.5ms
- Overhead: < 0.67ms

### Memory Targets
- Total: < 4GB
- Per-agent: < 1KB
- Cache misses: < 5%
- Allocation rate: < 10MB/s

### Scalability Targets
- 1K agents: 120 FPS
- 10K agents: 90 FPS
- 100K agents: 60 FPS
- 1M agents: 60 FPS

## Optimization Strategies

### CPU Optimization
- NEON vectorization
- Instruction scheduling
- Branch prediction
- Prefetching

### Memory Optimization
- Cache-friendly layouts
- Memory pooling
- Compression
- Lazy allocation

### Parallelization
- Work distribution
- Lock-free algorithms
- SIMD processing
- GPU offloading

## Success Metrics
1. Consistent 60 FPS with 1M agents
2. < 50% CPU usage on M1
3. < 4GB memory footprint
4. Zero frame drops
5. < 100ms load time

## Timeline
- Day 1: Performance framework
- Day 2: System benchmarks
- Day 3: Profiling tools
- Day 4: Bottleneck analysis
- Day 5: Optimization implementation