# SimCity ARM64 Core Simulation Architecture
## Agent A1: Simulation Architect Implementation

### Overview

This implementation provides the foundational simulation core for SimCity ARM64, written entirely in pure ARM64 assembly language. The architecture is designed to support 1,000,000+ agents at 60 FPS with 30Hz simulation updates on Apple Silicon.

### Key Features

- **Fixed Timestep Simulation**: 30Hz simulation with 60 FPS rendering using interpolation
- **Module Dispatch System**: Clean ABI for all simulation subsystems (A2-A5)
- **Performance Monitoring**: Real-time performance tracking and adaptive quality control
- **Error Recovery**: Robust error handling with automatic recovery mechanisms
- **Memory Efficiency**: Optimized for Apple Silicon cache hierarchy

### Architecture Components

#### 1. Core Simulation Engine (`core.s`)

The heart of the simulation system that provides:

- **Module Management**: Registration, initialization, and lifecycle management
- **Tick Dispatcher**: Executes simulation modules in priority order
- **Performance Monitoring**: Tracks execution time and detects bottlenecks
- **Error Recovery**: Handles module failures and maintains system stability

**Key Functions:**
- `_simulation_init(flags, memory_size, agent_count)` → error_code
- `_simulation_tick()` → interpolation_alpha
- `_simulation_cleanup()` → error_code

#### 2. Frame Control System (`frame_control.s`)

Manages precise timing and frame rate control:

- **High-Precision Timing**: Uses `mach_absolute_time` for nanosecond precision
- **Fixed Timestep**: Maintains consistent 30Hz simulation regardless of frame rate
- **Interpolation**: Provides smooth 60 FPS rendering with interpolation values
- **Performance Pacing**: Adaptive frame pacing with vsync coordination

**Key Functions:**
- `frame_control_init(fps, simulation_hz)` → error_code
- `frame_control_update()` → (interpolation_alpha, simulation_steps)
- `frame_control_wait_for_vsync()`

#### 3. Shared ABI Definition (`simulation_abi.s`)

Defines the standard Application Binary Interface for all modules:

- **Register Allocation**: Optimized register usage for hot paths
- **Function Signatures**: Standardized calling conventions
- **Memory Layout**: Cache-aligned data structures
- **Error Handling**: Consistent error reporting across modules

**Module Interface:**
```assembly
// Standard module initialization
module_init(module_id, config_ptr, memory_pool) → error_code

// Per-tick update (called 30 times/second)
module_tick(module_id, delta_time_ns, world_context) → error_code

// Module cleanup
module_cleanup(module_id) → error_code
```

#### 4. Unit Test Suite (`core_tests.s`)

Comprehensive testing framework:

- **Initialization Testing**: Validates core setup and module registration
- **Timing Precision**: Verifies 30Hz/60FPS timing accuracy
- **Performance Stress Testing**: Tests system under high load
- **Error Recovery Testing**: Validates failure handling
- **ABI Compliance**: Ensures proper calling conventions

### Performance Targets

| Metric | Target | Implementation |
|--------|--------|----------------|
| Simulation Rate | 30 Hz | Fixed timestep with accumulator |
| Render Rate | 60 FPS | Variable timestep with interpolation |
| Agent Count | 1M+ | Optimized memory pools and batch processing |
| Memory Usage | < 4GB | TLSF allocator with compression |
| Frame Consistency | > 95% | Adaptive quality and spiral protection |

### Integration Points for Other Agents

#### Agent A2: Economic System
- **Module ID**: `MODULE_ECONOMIC_SYSTEM` (1)
- **Interface**: Economic calculations and market simulation
- **Dependencies**: Time system, population data
- **Frequency**: Every simulation tick (30Hz)

#### Agent A3: Population System  
- **Module ID**: `MODULE_POPULATION_SYSTEM` (2)
- **Interface**: Citizen lifecycle and demographics
- **Dependencies**: Economic system, building system
- **Frequency**: Every simulation tick (30Hz)

#### Agent A4: Agent System
- **Module ID**: `MODULE_AGENT_SYSTEM` (7)
- **Interface**: Individual agent AI and pathfinding
- **Dependencies**: Transport system, building system
- **Frequency**: LOD-based (1Hz to 30Hz depending on distance)

#### Agent A5: Transport System
- **Module ID**: `MODULE_TRANSPORT_SYSTEM` (3)
- **Interface**: Traffic simulation and routing
- **Dependencies**: Agent system, network topology
- **Frequency**: Every simulation tick (30Hz)

### Memory Management

#### Module Memory Pools
Each module receives a dedicated memory pool with:
- **Cache-aligned allocation** (64-byte boundaries)
- **TLSF allocator** for efficient variable-size allocation
- **Usage tracking** for performance monitoring
- **Automatic cleanup** on module shutdown

#### Register Allocation Strategy
```assembly
// Preserved registers (x19-x28) for module state
x19: Primary module state pointer
x20: Secondary state/cache pointer  
x21: Current entity/agent pointer
x22: Performance counter/timer
x23: Error state accumulator
x24: Module configuration flags
x25: Scratch register for hot paths
x28: Module ID for debugging
```

### Error Handling

#### Error Codes
- `SIM_SUCCESS` (0): Operation completed successfully
- `SIM_ERROR_INVALID_PARAM` (-1): Invalid input parameters
- `SIM_ERROR_OUT_OF_MEMORY` (-2): Memory allocation failed
- `SIM_ERROR_MODULE_NOT_INIT` (-3): Module not initialized
- `SIM_ERROR_MODULE_FAILED` (-4): Module execution failed
- `SIM_ERROR_PERFORMANCE` (-5): Performance degradation detected

#### Recovery Mechanisms
1. **Automatic Quality Reduction**: Reduces detail when performance drops
2. **Module Isolation**: Failed modules don't crash the entire system
3. **Graceful Degradation**: Non-critical modules can be disabled temporarily
4. **Performance Monitoring**: Real-time detection of bottlenecks

### Performance Monitoring

#### Real-time Metrics
- **Frame Time Consistency**: Rolling variance of frame times
- **Module Execution Time**: Per-module performance tracking
- **Memory Usage**: Real-time allocation monitoring
- **Quality Adaptation**: Automatic quality level adjustment

#### Profiling Hooks
```assembly
PROFILE_FUNCTION_ENTER module_id, function_id
// Function implementation
PROFILE_FUNCTION_EXIT module_id, function_id
```

### Building and Testing

#### Build Commands
```bash
# Assemble core simulation
as -arch arm64 -o core.o src/simulation/core.s
as -arch arm64 -o frame_control.o src/simulation/frame_control.s
as -arch arm64 -o core_tests.o src/simulation/core_tests.s

# Link with main application
clang -o simcity core.o frame_control.o core_tests.o main.o -arch arm64
```

#### Running Tests
```assembly
// Call from main application
bl run_core_tests              // Returns (passed_count, failed_count)
```

### Configuration

#### Compile-time Options
- `DEBUG_BUILD`: Enable debug logging and assertions
- `ENABLE_PROFILING`: Activate performance profiling hooks
- `ADAPTIVE_QUALITY`: Enable automatic quality reduction

#### Runtime Configuration
```c
struct CoreConfig {
    uint32_t target_fps;           // Default: 60
    uint32_t simulation_hz;        // Default: 30  
    uint32_t max_agents;           // Default: 1000000
    uint32_t memory_pool_size;     // Default: 4GB
    uint32_t enable_profiling;     // Default: 0
    uint32_t adaptive_quality;     // Default: 1
};
```

### Integration Checklist for Agents A2-A5

- [ ] Implement standard module interface functions
- [ ] Use provided ABI calling conventions
- [ ] Register with module dispatch system
- [ ] Handle error codes consistently
- [ ] Implement performance monitoring hooks
- [ ] Test module isolation and recovery
- [ ] Validate memory pool usage
- [ ] Ensure 30Hz tick rate compatibility

### File Structure

```
src/simulation/
├── core.s                      # Main simulation core
├── frame_control.s             # Timing and frame rate control
├── simulation_abi.s            # Shared ABI definitions
├── core_tests.s                # Unit test suite
├── simulation_constants.s      # Constants and macros
└── README_CORE_ARCHITECTURE.md # This documentation
```

### Future Enhancements

1. **Multi-threading**: Parallel module execution on M-series processors
2. **GPU Acceleration**: Offload suitable computations to Metal
3. **Network Synchronization**: Multi-player simulation support  
4. **Hot Reload**: Dynamic module loading/unloading
5. **Advanced Profiling**: GPU timeline integration

### Contact

This implementation was created by Agent A1 (Simulation Architect) as the foundation for Agents A2-A5 to build upon. The core provides all necessary infrastructure for economic systems, population dynamics, agent AI, and transport simulation.

For integration questions or ABI clarifications, refer to the detailed comments in each source file.