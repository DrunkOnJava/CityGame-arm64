# Sub-Agent 3: Simulation Pipeline Coordinator Plan

## Objective
Connect simulation/core.s to all subsystems, wire entity_system.s to AI modules, link zoning → RCI demand → economics flow, set up utilities → services → happiness pipeline.

## Core Integration Architecture

### Simulation Update Pipeline
1. **Frame Control** (30Hz fixed timestep)
   - Time accumulation
   - Interpolation for 60 FPS rendering
   - Delta time distribution

2. **Entity System Updates**
   - Double-buffered ECS
   - Parallel component updates
   - Spatial indexing

3. **System Update Order**
   - Input processing
   - Time advancement
   - Weather updates
   - Zone management
   - RCI demand calculation
   - Economic simulation
   - Entity behavior
   - Infrastructure propagation
   - Service coverage
   - Happiness calculation

## Implementation Tasks

### Task 1: Core Simulation Loop Integration
```assembly
.global simulation_update
simulation_update:
    stp x29, x30, [sp, #-64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    
    ; Get delta time
    adrp x0, simulation_delta_time
    ldr w19, [x0, :lo12:simulation_delta_time]
    
    ; Update game time
    bl time_system_update
    
    ; Environmental systems
    mov w0, w19
    bl weather_system_update
    
    ; Zone management
    bl zone_management_update
    
    ; Economic simulation
    bl economic_update_pipeline
    
    ; Entity updates (parallel)
    bl entity_system_update
    
    ; Infrastructure
    bl infrastructure_update
    
    ; Services and happiness
    bl services_update
    bl happiness_calculate
    
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret
```

### Task 2: Entity-AI Integration Bridge
```assembly
.global entity_ai_bridge_update
entity_ai_bridge_update:
    ; Query active entities
    adrp x0, entity_query_active
    add x0, x0, :lo12:entity_query_active
    bl query_entities
    mov x19, x0  ; entity count
    mov x20, x1  ; entity array
    
    ; Process entities in batches
    mov x21, #0  ; index
.entity_loop:
    cmp x21, x19
    b.ge .done
    
    ; Load entity data
    lsl x22, x21, #6  ; entity_size = 64
    add x22, x20, x22
    
    ; Check entity type
    ldr w23, [x22, #ENTITY_TYPE_OFFSET]
    
    cmp w23, #ENTITY_TYPE_CITIZEN
    b.eq .process_citizen
    cmp w23, #ENTITY_TYPE_VEHICLE
    b.eq .process_vehicle
    b .next_entity
    
.process_citizen:
    mov x0, x22
    bl citizen_behavior_update
    b .next_entity
    
.process_vehicle:
    mov x0, x22
    bl traffic_flow_update
    
.next_entity:
    add x21, x21, #1
    b .entity_loop
    
.done:
    ret
```

### Task 3: Zoning → RCI → Economics Pipeline
```assembly
.global economic_update_pipeline
economic_update_pipeline:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    
    ; Step 1: Analyze zones
    bl zoning_neon_analyze_all
    mov x19, x0  ; zone statistics
    
    ; Step 2: Calculate RCI demand
    mov x0, x19
    bl rci_demand_calculate
    mov x20, x0  ; demand values
    
    ; Step 3: Update land values
    mov x0, x20
    bl update_land_values
    
    ; Step 4: Process taxes
    bl tax_collection_cycle
    
    ; Step 5: Update budgets
    bl budget_allocation_update
    
    ; Step 6: Trigger growth/decline
    mov x0, x20
    bl apply_growth_patterns
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
```

### Task 4: Infrastructure → Services Pipeline
```assembly
.global infrastructure_update
infrastructure_update:
    ; Update in dependency order
    
    ; Power grid first
    bl power_grid_propagate
    
    ; Water system (needs power)
    bl water_system_propagate
    
    ; Road network (independent)
    bl road_network_update
    
    ; Flood fill utilities
    bl utilities_flood_fill
    
    ; Update coverage maps
    bl update_coverage_maps
    
    ret
    
.global services_update
services_update:
    ; Emergency services
    bl emergency_dispatch_update
    
    ; Mass transit
    bl mass_transit_update
    
    ; Education
    bl education_coverage_update
    
    ; Healthcare
    bl healthcare_coverage_update
    
    ret
```

## Integration Points

### Memory Integration (Sub-Agent 2)
- Component arrays allocation
- Entity pool management
- Spatial grid memory
- Double-buffer allocation

### Graphics Integration (Sub-Agent 4)
- Entity position updates
- Sprite batch updates
- Particle effect triggers
- Debug visualization data

### AI Integration (Sub-Agent 5)
- Pathfinding requests
- Behavior state updates
- Traffic flow data
- Emergency dispatch

### Event System (Sub-Agent 6)
- Zone change events
- Economic events
- Service alerts
- Entity state changes

## Performance Considerations

### Parallel Processing
- Entity updates use work-stealing queues
- Zone processing uses NEON 4x4 tiles
- Infrastructure uses parallel BFS
- Services use spatial partitioning

### Cache Optimization
- Hot/cold data separation
- Component arrays are contiguous
- Spatial locality for queries
- Prefetch hints for iterations

## Success Metrics
1. 30Hz simulation tick stability
2. < 16ms total update time
3. 1M+ entities updated per tick
4. Zero frame drops
5. Accurate economic simulation

## Coordination Schedule
- Day 1: Core loop integration
- Day 2: Entity-AI bridge
- Day 3: Economic pipeline
- Day 4: Infrastructure pipeline
- Day 5: Testing and optimization