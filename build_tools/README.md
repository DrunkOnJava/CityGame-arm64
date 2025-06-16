# SimCity ARM64 Build System Documentation
**Agent E5: Platform Team - Complete Assembly-Only Build Pipeline**

## Overview

The SimCity ARM64 build system is a comprehensive, assembly-only build pipeline designed specifically for Apple Silicon (ARM64) architecture. It supports building a high-performance city simulation targeting 1,000,000+ agents at 60 FPS using pure ARM64 assembly code.

## Architecture

### Build Pipeline Components

1. **Metal Shader Compilation** (`build_shaders.sh`)
   - Pre-compiles Metal shaders to optimized .metallib files
   - Generates argument buffer configurations
   - Apple Silicon GPU optimization

2. **Assembly Module Compilation** (`build_assembly.sh`)
   - Compiles all ARM64 assembly modules
   - Creates static libraries for each agent component
   - Supports debug, release, and benchmark builds

3. **Advanced Linking** (`link_assembly.sh`)
   - Links multiple binary variants
   - Symbol ordering for performance
   - Creates optimized executables

4. **Automated Testing** (`run_tests.sh`)
   - Unit tests for all modules
   - Memory leak detection
   - Performance regression testing

5. **Performance Benchmarking** (`run_benchmarks.sh`)
   - Micro and system-level benchmarks
   - Scalability testing (1K to 1M agents)
   - Performance target validation

6. **Integration Testing** (`integration_tests.sh`)
   - Cross-module integration validation
   - Full system integration tests
   - Error propagation testing

7. **Deployment & Packaging** (`deploy.sh`)
   - Creates macOS app bundles
   - Generates PKG installers
   - Creates DMG disk images
   - Code signing and notarization support

8. **Master Orchestration** (`build_master.sh`)
   - Coordinates entire build pipeline
   - Comprehensive reporting
   - Error handling and recovery

## Quick Start

### Prerequisites

- **System**: Apple Silicon Mac (M1, M2, or later)
- **OS**: macOS 11.0 or later
- **Memory**: 8GB+ (16GB recommended)
- **Tools**: Xcode Command Line Tools

### Basic Usage

```bash
# Complete build with tests
./build_tools/build_master.sh

# Release build with deployment
./build_tools/build_master.sh release --deploy

# Clean debug build with benchmarks
./build_tools/build_master.sh --clean --benchmarks

# Quick build without tests
./build_tools/build_master.sh --no-tests
```

## Detailed Documentation

### Build System Scripts

#### 1. Master Build Orchestration (`build_master.sh`)

The primary entry point for the entire build system.

**Usage:**
```bash
./build_tools/build_master.sh [OPTIONS] [BUILD_MODE]
```

**Build Modes:**
- `debug` - Debug build with symbols (default)
- `release` - Optimized release build
- `benchmark` - Benchmarking instrumentation
- `profile` - Profiling support

**Options:**
- `--clean` - Clean workspace before building
- `--no-tests` - Skip all tests
- `--benchmarks` - Run performance benchmarks
- `--deploy` - Create deployment packages
- `--coverage` - Enable code coverage
- `--verbose` - Verbose output

**Pipeline Phases:**
1. Environment verification
2. Workspace cleanup (if requested)
3. Metal shader compilation
4. Assembly module compilation
5. Executable linking
6. Unit test execution
7. Integration test execution
8. Performance benchmarking
9. Deployment package creation

#### 2. Assembly Compilation (`build_assembly.sh`)

Compiles all ARM64 assembly modules into static libraries.

**Features:**
- Modular compilation by agent
- Parallel build support
- Debug symbol generation
- Warning-as-error compilation
- Build timing metrics

**Agent Modules:**
- Platform (system calls, threading)
- Memory (TLSF allocator, pools)
- Graphics (Metal pipeline, sprites)
- Simulation (game loop, ECS)
- Agents (AI, pathfinding)
- Network (infrastructure)
- UI (interface, tools)
- I/O (save/load, assets)
- Audio (Core Audio, 3D sound)
- Tools (profiling, debugging)

#### 3. Advanced Linking (`link_assembly.sh`)

Creates optimized executable variants with advanced linking features.

**Binary Variants:**
- `simcity_full` - Complete featured version
- `simcity_minimal` - Minimal runtime
- `simcity_debug` - Debug version with symbols
- `simcity_profile` - Profiling instrumentation

**Linking Features:**
- Symbol ordering for performance
- Dead code stripping
- Framework integration
- Architecture validation
- Symbol map generation

#### 4. Testing Pipeline (`run_tests.sh`)

Comprehensive testing system for quality assurance.

**Test Categories:**
- **Unit Tests** - Individual module testing
- **Integration Tests** - Cross-module validation
- **Memory Tests** - Leak detection
- **Performance Tests** - Regression testing

**Features:**
- Parallel test execution
- Timeout handling
- Coverage analysis
- HTML reporting
- Test result archiving

#### 5. Performance Benchmarking (`run_benchmarks.sh`)

Validates performance targets and identifies bottlenecks.

**Benchmark Types:**
- **Micro Benchmarks** - Individual function performance
- **System Benchmarks** - Full system performance
- **Scalability Tests** - Agent scaling (1K to 1M)

**Performance Targets:**
- 60 FPS minimum framerate
- 1,000,000+ agents simultaneously
- < 4GB memory usage
- < 80% CPU utilization

**Monitoring:**
- Real-time system resource usage
- GPU utilization tracking
- Thermal monitoring
- Performance regression detection

#### 6. Integration Testing (`integration_tests.sh`)

Validates complete system integration across all components.

**Integration Scenarios:**
- Full stack initialization
- Multi-agent coordination
- Resource management stress
- Error handling cascade
- Performance target validation
- Memory leak detection
- Graceful shutdown

#### 7. Deployment System (`deploy.sh`)

Creates distribution packages for end users.

**Package Formats:**
- **App Bundle** - macOS .app bundle
- **PKG Installer** - macOS installer package
- **DMG Image** - Disk image for distribution
- **Archive** - Compressed ZIP archive

**Deployment Features:**
- Code signing support
- Notarization workflow
- Multiple variants
- System requirement validation
- Installation scripts

## Build Configuration

### Environment Variables

```bash
# Build configuration
export BUILD_MODE="debug"          # debug, release, benchmark
export CLEAN_BUILD="false"         # Clean before build
export PARALLEL_BUILD="true"       # Enable parallel compilation
export VERBOSE_BUILD="false"       # Verbose output

# Test configuration
export RUN_TESTS="true"            # Run unit tests
export RUN_INTEGRATION="true"      # Run integration tests
export ENABLE_COVERAGE="false"     # Code coverage analysis

# Performance configuration
export TARGET_AGENTS="1000000"     # Target agent count
export TARGET_FPS="60"             # Target framerate
export MEMORY_LIMIT_GB="4"         # Memory usage limit
```

### Build Directories

```
build/
├── obj/                    # Object files by module
├── lib/                    # Static libraries
├── bin/                    # Executable binaries
├── test/                   # Test executables
├── test_reports/           # Test result reports
├── benchmark/              # Benchmark executables and results
├── shaders/                # Compiled Metal shaders
├── deploy/                 # Deployment packages
└── reports/                # Build reports
```

## Performance Optimization

### Apple Silicon Optimizations

The build system includes specific optimizations for Apple Silicon:

1. **Assembly Flags:**
   - `-arch arm64` - ARM64 architecture targeting
   - `--statistics` - Compilation statistics
   - `--fatal-warnings` - Treat warnings as errors

2. **Linking Optimizations:**
   - Symbol ordering for instruction cache efficiency
   - Dead code stripping
   - Compact unwind disabled for assembly compatibility

3. **Metal Shader Optimization:**
   - Apple GPU family targeting
   - Function constant specialization
   - Argument buffer pre-compilation

### Build Performance

- **Parallel Compilation** - Utilizes all available CPU cores
- **Incremental Builds** - Only rebuilds changed modules
- **Cached Artifacts** - Reuses previous build outputs
- **Fast Linking** - Optimized symbol resolution

## Troubleshooting

### Common Issues

1. **"ARM64 architecture required"**
   - Solution: Build system only supports Apple Silicon Macs

2. **"Missing required tools"**
   - Solution: Install Xcode Command Line Tools
   - Command: `xcode-select --install`

3. **"Insufficient memory"**
   - Solution: Close other applications, use 16GB+ RAM system

4. **"Metal compiler not found"**
   - Solution: Ensure Xcode is properly installed

5. **"Test executables not found"**
   - Solution: Run full build before running tests separately

### Debug Build Issues

For debug builds that fail:

```bash
# Enable verbose output
./build_tools/build_master.sh debug --verbose

# Check specific module
./build_tools/build_assembly.sh debug --verbose platform

# Run specific test
./build_tools/run_tests.sh memory --verbose
```

### Performance Issues

If performance targets are not met:

```bash
# Run performance analysis
./build_tools/run_benchmarks.sh --instruments

# Check system requirements
system_profiler SPHardwareDataType
sysctl hw.memsize
```

## Advanced Usage

### Custom Build Workflows

#### Development Workflow
```bash
# Quick development build
./build_tools/build_assembly.sh debug
./build_tools/link_assembly.sh
./build_tools/run_tests.sh unit --quick
```

#### Release Workflow
```bash
# Complete release with deployment
./build_tools/build_master.sh release --clean --deploy --benchmarks
```

#### Performance Analysis Workflow
```bash
# Performance-focused build
./build_tools/build_master.sh benchmark --benchmarks --no-tests
./build_tools/run_benchmarks.sh --stress --instruments
```

### Continuous Integration

For CI/CD integration:

```bash
# CI build script
#!/bin/bash
set -e

# Environment setup
export CI=true
export BUILD_MODE=release

# Execute build pipeline
./build_tools/build_master.sh \
    --clean \
    --no-benchmarks \
    --coverage \
    --verbose

# Archive artifacts
tar -czf build-artifacts.tar.gz build/
```

## Integration with Other Tools

### IDE Integration

The build system can be integrated with IDEs:

1. **Xcode** - Use build phases to call scripts
2. **CLion** - Custom build configurations
3. **VS Code** - Task configurations

### Profiling Tools

- **Instruments** - Use `--instruments` flag
- **Xcode Profiler** - Profile generated executables
- **Activity Monitor** - System resource monitoring

## Contributing

### Adding New Modules

1. Create module directory in `src/`
2. Add module to `AGENT_MODULES` array in `build_assembly.sh`
3. Update linking dependencies in `link_assembly.sh`
4. Add module tests to testing pipeline

### Modifying Build Pipeline

1. Update relevant build script
2. Test with multiple build modes
3. Update documentation
4. Add error handling

## Support

For build system issues:

1. Check this documentation
2. Review build logs in `build/reports/`
3. Run with `--verbose` flag for detailed output
4. Check system requirements

## Performance Targets

The build system is designed to create executables that achieve:

- **Agent Count**: 1,000,000+ simultaneous agents
- **Framerate**: 60 FPS minimum, 120 FPS target
- **Memory Usage**: < 4GB total system memory
- **CPU Usage**: < 80% on Apple Silicon
- **GPU Usage**: < 50% on integrated GPUs
- **Startup Time**: < 5 seconds to full simulation

## Future Enhancements

Planned improvements to the build system:

1. **Cross-compilation** - Support for different ARM64 variants
2. **Distributed Building** - Network-based compilation
3. **Advanced Profiling** - Built-in performance analysis
4. **Module Versioning** - Version tracking for modules
5. **Dependency Management** - Automatic dependency resolution

---

**Agent E5 Platform Team Build System - Complete Assembly-Only Pipeline for SimCity ARM64**

*Targeting 1,000,000+ agents at 60 FPS on Apple Silicon*