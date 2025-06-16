# Sub-Agent 5: AI Systems Coordinator Plan

## Objective
Connect astar_core.s to all pathfinding clients, wire traffic_flow.s with citizen_behavior.s, link emergency_services.s dispatch system, integrate mass_transit.s with traffic.

## AI Architecture Overview

### Core AI Systems
1. **Pathfinding Core**
   - A* implementation (< 0.5ms per path)
   - Navigation mesh
   - Path caching
   - Dynamic obstacles

2. **Behavior Systems**
   - Citizen state machines
   - Vehicle controllers
   - Emergency dispatch
   - Transit scheduling

3. **Traffic Management**
   - Flow simulation
   - Congestion detection
   - Route optimization
   - Signal control

## Implementation Tasks

### Task 1: Unified Pathfinding Interface
```assembly
.global ai_pathfinding_request
ai_pathfinding_request:
    ; x0 = start position
    ; x1 = end position
    ; x2 = agent_type
    ; x3 = priority
    
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    
    ; Check path cache first
    bl check_path_cache
    cbnz x0, .cache_hit
    
    ; Allocate path request
    bl allocate_path_request
    mov x23, x0
    
    ; Fill request data
    str x19, [x23, #PATH_START_OFFSET]
    str x20, [x23, #PATH_END_OFFSET]
    str w21, [x23, #PATH_AGENT_TYPE]
    str w22, [x23, #PATH_PRIORITY]
    
    ; Submit to pathfinding queue
    mov x0, x23
    bl submit_path_request
    
    ; High priority = immediate
    cmp w22, #PRIORITY_EMERGENCY
    b.eq .compute_immediate
    
    ; Return async handle
    mov x0, x23
    b .done
    
.compute_immediate:
    mov x0, x19
    mov x1, x20
    bl astar_find_path_immediate
    
.cache_hit:
.done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
```

### Task 2: Citizen-Traffic Integration
```assembly
.global citizen_traffic_integration_update
citizen_traffic_integration_update:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    
    ; Process citizen movement requests
    bl get_moving_citizens
    mov x19, x0  ; citizen count
    mov x20, x1  ; citizen array
    
    mov x21, #0
.citizen_loop:
    cmp x21, x19
    b.ge .citizens_done
    
    ; Get citizen data
    lsl x22, x21, #6
    add x22, x20, x22
    
    ; Check if needs vehicle
    ldr w23, [x22, #CITIZEN_TRANSPORT_MODE]
    cmp w23, #TRANSPORT_CAR
    b.ne .check_transit
    
    ; Request traffic slot
    mov x0, x22
    bl traffic_request_vehicle_slot
    b .next_citizen
    
.check_transit:
    cmp w23, #TRANSPORT_TRANSIT
    b.ne .next_citizen
    
    ; Request transit route
    mov x0, x22
    bl mass_transit_request_route
    
.next_citizen:
    add x21, x21, #1
    b .citizen_loop
    
.citizens_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
```

### Task 3: Emergency Services Dispatch
```assembly
.global emergency_dispatch_integrated
emergency_dispatch_integrated:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    ; Check for emergencies
    bl check_emergency_queue
    cbz x0, .no_emergencies
    
    mov x19, x0  ; emergency count
    mov x20, x1  ; emergency array
    
.dispatch_loop:
    cbz x19, .done
    
    ; Get emergency
    ldr x21, [x20], #8
    
    ; Find nearest available unit
    ldr w0, [x21, #EMERGENCY_TYPE]
    ldr x1, [x21, #EMERGENCY_LOCATION]
    bl find_nearest_unit
    mov x22, x0
    
    cbz x22, .next_emergency
    
    ; Dispatch unit
    mov x0, x22
    mov x1, x21
    bl dispatch_emergency_unit
    
    ; Request priority path
    ldr x0, [x22, #UNIT_LOCATION]
    ldr x1, [x21, #EMERGENCY_LOCATION]
    mov x2, #AGENT_EMERGENCY
    mov x3, #PRIORITY_EMERGENCY
    bl ai_pathfinding_request
    
    ; Clear traffic along route
    mov x1, x0  ; path
    mov x0, x22  ; unit
    bl traffic_clear_emergency_route
    
.next_emergency:
    sub x19, x19, #1
    b .dispatch_loop
    
.no_emergencies:
.done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
```

### Task 4: Mass Transit Integration
```assembly
.global mass_transit_ai_update
mass_transit_ai_update:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    
    ; Update all transit lines
    bl get_transit_lines
    mov x19, x0  ; line count
    mov x20, x1  ; line array
    
.line_loop:
    cbz x19, .done
    
    ; Get line data
    ldr x21, [x20], #8
    
    ; Update vehicle positions
    mov x0, x21
    bl update_transit_vehicles
    
    ; Check passenger requests
    mov x0, x21
    bl process_passenger_requests
    
    ; Optimize schedule if needed
    ldr w22, [x21, #LINE_CONGESTION]
    cmp w22, #CONGESTION_HIGH
    b.lt .next_line
    
    mov x0, x21
    bl optimize_transit_schedule
    
.next_line:
    sub x19, x19, #1
    b .line_loop
    
.done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
```

### Task 5: Traffic Flow Optimization
```assembly
.global traffic_flow_optimization
traffic_flow_optimization:
    ; NEON optimized traffic simulation
    
    ; Process intersections
    bl get_intersection_list
    mov x19, x0  ; count
    mov x20, x1  ; array
    
.intersection_loop:
    cbz x19, .done
    
    ; Load intersection data
    ld1 {v0.4s, v1.4s}, [x20]
    
    ; Calculate flow rates (NEON)
    ; v0 = north/south flows
    ; v1 = east/west flows
    
    ; Optimize signal timing
    fmul v2.4s, v0.4s, v0.4s
    fmul v3.4s, v1.4s, v1.4s
    fadd v4.4s, v2.4s, v3.4s
    
    ; Update signal phases
    fcmp s4, #FLOW_THRESHOLD
    b.gt .adjust_timing
    
.next_intersection:
    add x20, x20, #32
    sub x19, x19, #1
    b .intersection_loop
    
.adjust_timing:
    mov x0, x20
    bl adjust_signal_timing
    b .next_intersection
    
.done:
    ret
```

## Integration Architecture

### Shared Data Structures
```assembly
.data
.align 6  ; Cache line alignment

; Pathfinding cache (LRU)
path_cache:
    .space 65536  ; 64KB cache

; Active vehicles
vehicle_pool:
    .space 262144  ; 256KB for 2K vehicles

; Transit schedules
transit_data:
    .space 131072  ; 128KB

; Emergency units
emergency_units:
    .space 32768   ; 32KB
```

### Thread Safety
- Lock-free queues for path requests
- Atomic updates for traffic data
- Read-copy-update for schedules
- Per-thread work stealing

## Performance Optimizations

### Path Caching
- LRU cache for common routes
- Hierarchical pathfinding
- Dynamic path invalidation
- Precomputed highways

### SIMD Processing
- 8-vehicle traffic batches
- 4-way intersection flow
- Parallel behavior updates
- Vectorized collision detection

### Spatial Partitioning
- Quadtree for vehicles
- Grid for citizens
- Region-based dispatch
- LOD for distant agents

## Integration Points

### Simulation Integration (Sub-Agent 3)
- Entity position updates
- State machine triggers
- Event notifications
- Time synchronization

### Graphics Integration (Sub-Agent 4)
- Vehicle sprite updates
- Path visualization
- Traffic flow heat maps
- Debug overlays

### Event System (Sub-Agent 6)
- Movement events
- Emergency alerts
- Transit arrivals
- Traffic jams

## Success Metrics
1. < 0.5ms average pathfinding
2. 10K+ simultaneous paths
3. Real-time traffic simulation
4. < 500μs emergency dispatch
5. Smooth transit operations

## Timeline
- Day 1: Pathfinding integration
- Day 2: Citizen-traffic connection
- Day 3: Emergency dispatch
- Day 4: Mass transit integration
- Day 5: Performance optimization