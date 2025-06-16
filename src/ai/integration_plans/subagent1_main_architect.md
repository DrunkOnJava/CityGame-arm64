# Sub-Agent 1: Main Application Architect Integration Plan

## Objective
Create unified entry point and orchestrate initialization of all 25+ ARM64 assembly modules for SimCity.

## Key Responsibilities
1. Create src/main_unified.s as the master entry point
2. Design module initialization sequence respecting dependencies
3. Implement high-performance game loop
4. Integrate with platform bootstrap

## Module Dependencies Analysis

### Initialization Order
1. **Platform Layer** (Must be first)
   - bootstrap.s - System initialization
   - syscalls.s - OS interface
   - threads.s - Threading setup
   - objc_bridge.s - Objective-C runtime

2. **Memory Systems** (Required by all)
   - tlsf_allocator.s - Main allocator
   - tls_allocator.s - Thread-local storage
   - agent_allocator.s - Entity pools
   - memory.s, pool.s, slab.s - Support systems

3. **Core Systems**
   - ecs_core.s - Entity Component System
   - entity_system.s - Entity management
   - frame_control.s - Timing control
   - event_bus.s (to be created)

4. **Graphics Pipeline**
   - metal_init.s - GPU initialization
   - metal_pipeline.s - Render pipeline
   - shader_loader.s - Shader compilation
   - camera.s - View setup

5. **Simulation Systems**
   - simulation/core.s - Main simulation
   - time_system.s - Game time
   - weather_system.s - Environment
   - economic_system.s - Economy

6. **AI Systems**
   - astar_core.s - Pathfinding
   - citizen_behavior.s - Agent AI
   - traffic_flow.s - Traffic simulation
   - mass_transit.s - Public transport

7. **I/O and Persistence**
   - save_load.s - Save system
   - asset_loader.s - Resource loading
   - config_parser.s - Configuration

8. **Audio Systems**
   - core_audio.s - Audio engine
   - spatial_audio.s - 3D sound
   - streaming.s - Music/ambience

9. **UI Systems**
   - input_handler.s - Input processing
   - hud.s - User interface
   - debug_overlay.s - Debug UI

## Implementation Tasks

### Task 1: Create main_unified.s
```assembly
.global _main
.align 4

_main:
    ; Save frame pointer and link register
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    ; Initialize platform layer
    bl platform_init
    
    ; Initialize memory systems
    bl memory_systems_init
    
    ; Initialize core systems
    bl core_systems_init
    
    ; Initialize subsystems
    bl graphics_init
    bl simulation_init
    bl ai_systems_init
    bl io_systems_init
    bl audio_init
    bl ui_init
    
    ; Enter main game loop
    bl main_game_loop
    
    ; Cleanup
    bl shutdown_all_systems
    
    ; Return
    mov x0, #0
    ldp x29, x30, [sp], #16
    ret
```

### Task 2: Module Initialization Functions
Create initialization wrappers for each subsystem that:
- Check dependencies
- Allocate required memory
- Register with event system
- Initialize module state
- Report success/failure

### Task 3: Main Game Loop Design
```assembly
main_game_loop:
    ; Fixed timestep accumulator in x19
    mov x19, #0
    
.game_loop:
    ; Get frame start time
    bl get_current_time
    mov x20, x0  ; Store start time
    
    ; Process input
    bl process_input_events
    
    ; Fixed timestep simulation (30Hz)
    add x19, x19, x21  ; Add delta time
.simulation_loop:
    cmp x19, #33333  ; 33.333ms = 30Hz
    b.lt .render
    
    ; Run simulation tick
    bl simulation_update
    sub x19, x19, #33333
    b .simulation_loop
    
.render:
    ; Variable rate rendering
    bl render_frame
    
    ; Frame timing
    bl calculate_frame_time
    bl apply_frame_limiter
    
    ; Check exit condition
    bl should_exit
    cbnz x0, .exit_game_loop
    
    b .game_loop
    
.exit_game_loop:
    ret
```

### Task 4: Error Handling and Recovery
- Implement graceful degradation
- Module failure isolation
- Recovery mechanisms
- Debug logging

## Integration Points

### Memory Integration
- Coordinate with Sub-Agent 2 for memory pool setup
- Define memory budgets per subsystem
- Implement pressure callbacks

### Event System Integration
- Coordinate with Sub-Agent 6 for event bus
- Define event priorities
- Set up event routing

### Performance Integration
- Coordinate with Sub-Agent 7 for benchmarking
- Add profiling hooks
- Implement performance counters

## Success Metrics
1. Clean module initialization with dependency resolution
2. Stable 60 FPS with 1M+ agents
3. < 16ms frame time consistently
4. Graceful error handling
5. Clean shutdown sequence

## Timeline
- Day 1: Create main_unified.s structure
- Day 2: Implement initialization sequence
- Day 3: Main game loop implementation
- Day 4: Error handling and recovery
- Day 5: Integration testing with other sub-agents