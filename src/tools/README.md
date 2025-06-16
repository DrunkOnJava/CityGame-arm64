# SimCity ARM64 Assembly - Tools & Debug System (Agent 10)

## Overview

Agent 10 provides comprehensive debugging, profiling, and testing infrastructure for the SimCity ARM64 assembly project. This system enables real-time performance monitoring, comprehensive testing, interactive debugging, and system inspection capabilities.

## Core Components

### 1. Performance Profiler (`profiler.s`)
High-performance profiling system with <1% overhead targeting:

**Features:**
- CPU performance monitoring (cycles, instructions, cache misses)
- GPU performance tracking (utilization, memory, draw calls)
- Memory usage monitoring and leak detection
- Real-time bottleneck identification
- Performance regression detection

**Key Functions:**
- `profiler_init()` - Initialize profiler system
- `profiler_frame_start()` - Mark frame beginning
- `profiler_frame_end()` - Mark frame end and analyze
- `profiler_sample_cpu()` - Sample CPU metrics
- `profiler_sample_gpu()` - Sample GPU metrics
- `profiler_sample_memory()` - Sample memory metrics
- `profiler_detect_bottlenecks()` - Identify performance bottlenecks

### 2. Real-time Visualization (`profiler_viz.s`)
Live performance visualization system providing:

**Features:**
- Real-time performance graphs
- Bottleneck identification with visual indicators
- Performance heat maps
- Historical trend analysis
- Configurable display modes

**Key Functions:**
- `profiler_viz_init()` - Initialize visualization
- `profiler_viz_update_graphs()` - Update real-time graphs
- `profiler_viz_render_heatmap()` - Render performance heat map
- `profiler_viz_set_mode()` - Change visualization mode

### 3. Testing Framework (`testing.s`)
Comprehensive testing framework for assembly code:

**Features:**
- Unit test framework with assertion macros
- Integration test automation
- Performance regression detection
- Memory leak detection
- Test result reporting and analysis

**Key Functions:**
- `test_framework_init()` - Initialize testing framework
- `test_run_all()` - Execute all registered tests
- `test_register_suite()` - Register test suite
- `test_register()` - Register individual test
- Various assertion functions (`test_assert_eq`, `test_assert_null`, etc.)

### 4. Integration Testing (`integration_test.s`)
Advanced integration testing system:

**Features:**
- Multi-agent system testing
- End-to-end workflow validation
- Stress testing and load validation
- Performance baseline management
- Automated scenario execution

**Key Functions:**
- `integration_test_init()` - Initialize integration testing
- `integration_run_all_scenarios()` - Run all test scenarios
- `integration_run_stress_test()` - Execute stress tests
- `integration_check_performance_regression()` - Detect regressions

### 5. Debug Console (`console.s`)
Interactive runtime debug console:

**Features:**
- Command line interface for system inspection
- Live parameter adjustment and tuning
- Real-time system state monitoring
- Built-in command system with help
- Variable watching and modification

**Key Functions:**
- `console_init()` - Initialize debug console
- `console_toggle()` - Activate/deactivate console
- `console_handle_key_input()` - Process keyboard input
- `console_execute_command()` - Execute console commands
- Variable management functions

**Built-in Commands:**
- `help` - Show available commands
- `status` - Display system status
- `profiler [start|stop|report]` - Control profiler
- `memory` - Memory system information
- `set <var> <value>` - Set variable value
- `get <var>` - Get variable value
- `watch <var>` - Watch variable changes
- `test` - Run test suite

### 6. System Inspector (`system_inspector.s`)
Advanced system inspection and live tuning:

**Features:**
- Real-time system state monitoring
- Live parameter adjustment and tuning
- Memory inspection and debugging
- Performance analysis with optimization hints
- Automated issue detection and recommendations

**Key Functions:**
- `inspector_init()` - Initialize system inspector
- `inspector_analyze_memory()` - Analyze memory usage
- `inspector_analyze_performance()` - Analyze performance
- `inspector_analyze_parameters()` - Analyze parameter optimality
- `inspector_run_full_analysis()` - Comprehensive system analysis

### 7. Tools Coordination (`tools_main.s`)
Main coordination system for all debug tools:

**Features:**
- Unified initialization and shutdown
- Development/production mode switching
- Performance overlay rendering
- Hotkey handling for tool activation
- Statistics aggregation and reporting

**Key Functions:**
- `tools_init()` - Initialize all tools
- `tools_update()` - Coordinate tool updates
- `tools_handle_hotkey()` - Process hotkeys
- `tools_set_development_mode()` - Switch modes
- `tools_print_statistics()` - Generate reports

## Constants and Macros

### Profiler Constants (`include/constants/profiler.inc`)
- Performance thresholds and limits
- Sample buffer sizes and structures
- PMU event selectors for ARM64
- Metal GPU profiling constants
- Regression detection parameters

### Profiler Macros (`include/macros/profiler.inc`)
- `PROFILE_START/END` - Time measurement
- `PROFILE_FUNCTION_ENTER/EXIT` - Function profiling
- `PROFILE_MEMORY_CHECKPOINT` - Memory usage tracking
- `PROFILE_CHECK_BOTTLENECKS` - Bottleneck detection
- Performance counter access macros

### Testing Constants (`include/constants/testing.inc`)
- Test framework configuration
- Test result codes and structures
- Assertion types and flags
- Performance benchmarking constants
- Integration test parameters

### Testing Macros (`include/macros/testing.inc`)
- `TEST_SUITE/TEST_CASE` - Test definition
- `ASSERT_EQ/NE/NULL/TRUE/FALSE` - Assertions
- `PERF_TEST_START/END` - Performance testing
- `BENCHMARK_START/END` - Benchmarking
- `MEMORY_TEST_START/END` - Memory leak detection

## Usage Examples

### Basic Profiling
```assembly
// Initialize profiler
bl profiler_init

// Start frame profiling
PROFILE_FRAME_START

// Your game loop code here
bl simulation_step
bl graphics_render

// End frame profiling
PROFILE_FRAME_END

// Check for bottlenecks
PROFILE_CHECK_BOTTLENECKS x0
cbnz x0, handle_bottleneck
```

### Function Profiling
```assembly
my_function:
    PROFILE_FUNCTION_ENTER my_function
    
    // Function implementation
    // ...
    
    PROFILE_FUNCTION_EXIT my_function
    ret
```

### Writing Tests
```assembly
TEST_SUITE memory_tests, memory_setup, memory_teardown

TEST_CASE memory_tests, allocation_test, "Test memory allocation"
    // Allocate memory
    mov x0, #1024
    bl malloc
    
    // Assert allocation succeeded
    ASSERT_NOT_NULL x0, "Allocation should succeed"
    
    // Use memory
    mov x1, #0xFF
    mov x2, #1024
    bl memset
    
    // Free memory
    bl free
TEST_CASE_END memory_tests, allocation_test
```

### Console Integration
```assembly
// Initialize console
bl console_init

// In main loop
bl console_update

// Handle input (called from input system)
mov x0, key_code
bl console_handle_key_input
```

## Performance Targets

- **Profiler Overhead**: <1% of total frame time
- **Memory Tracking**: Support for 1M+ tracked allocations
- **Test Execution**: 1000+ tests per second
- **Console Response**: <1ms command execution time
- **Real-time Updates**: 60Hz visualization updates

## Integration Points

### With Other Agents
- **Memory Management**: Hooks for allocation tracking
- **Graphics System**: GPU performance monitoring
- **Simulation Engine**: Frame timing and bottleneck detection
- **Agent Systems**: Performance profiling for pathfinding
- **Platform Layer**: Hardware counter access
- **Audio System**: Performance monitoring integration

### Build System Integration
```makefile
# Add to main Makefile
TOOLS_SOURCES = src/tools/profiler.s \
                src/tools/profiler_viz.s \
                src/tools/testing.s \
                src/tools/integration_test.s \
                src/tools/console.s \
                src/tools/system_inspector.s \
                src/tools/tools_main.s

INCLUDES += -I include/constants -I include/macros

# Development build with full debugging
debug: CFLAGS += -DDEBUG -DTOOLS_ENABLED
debug: $(TARGET)

# Production build with minimal tools
release: CFLAGS += -DRELEASE -DTOOLS_MINIMAL
release: $(TARGET)
```

## Configuration

### Development Mode
```assembly
// Enable full debugging features
mov x0, #1
bl tools_set_development_mode
```

### Production Mode
```assembly
// Minimal overhead debugging
mov x0, #0
bl tools_set_development_mode
```

## Hotkeys (Development Mode)

- **`~`** - Toggle debug console
- **`F1`** - Toggle detailed profiler mode
- **`F2`** - Run full system analysis
- **`F3`** - Toggle performance overlay

## Dependencies

### External Libraries
- Standard C library functions (printf, malloc, free, memset)
- Platform-specific APIs for hardware counter access
- Metal framework for GPU profiling on macOS/iOS

### Internal Dependencies
- Memory management system for allocation tracking
- Graphics system for GPU metrics
- Platform layer for hardware access
- All other agents for comprehensive profiling

## Future Enhancements

1. **Advanced Visualization**
   - 3D performance visualization
   - Interactive performance graphs
   - Real-time shader debugging

2. **AI-Powered Analysis**
   - Machine learning for performance prediction
   - Automated optimization suggestions
   - Intelligent test case generation

3. **Remote Debugging**
   - Network-based debug console
   - Remote profiling capabilities
   - Distributed testing framework

4. **Advanced Testing**
   - Fuzzing framework for assembly code
   - Property-based testing
   - Mutation testing capabilities

## Files Structure

```
src/tools/
├── profiler.s              # Core profiler implementation
├── profiler_viz.s          # Real-time visualization
├── testing.s               # Testing framework
├── integration_test.s      # Integration testing
├── console.s               # Debug console
├── system_inspector.s      # System inspection
├── tools_main.s            # Main coordination
└── README.md               # This documentation

include/constants/
├── profiler.inc            # Profiler constants
└── testing.inc             # Testing constants

include/macros/
├── profiler.inc            # Profiler macros
└── testing.inc             # Testing macros
```

This comprehensive tools and debug system provides the foundation for maintaining code quality, performance optimization, and rapid development in the SimCity ARM64 assembly project.