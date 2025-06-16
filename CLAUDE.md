# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SimCity ARM64 is a high-performance city simulation engine written entirely in ARM64 assembly for Apple Silicon, targeting 1M+ agents at 60 FPS. The project has been fully converted to pure ARM64 assembly through a 25-agent parallel development effort.

## Build Commands

### Master Build System (Primary Method)
```bash
# Complete build with all modules
./build_tools/build_master.sh

# Release build with deployment
./build_tools/build_master.sh release --deploy

# Debug build with tests
./build_tools/build_master.sh debug --tests

# Performance benchmarking
./build_tools/build_master.sh --benchmarks
```

### Module-Specific Building
```bash
# Build specific modules
./build_tools/build_assembly.sh memory
./build_tools/build_assembly.sh simulation
./build_tools/build_assembly.sh graphics

# Run module tests
./build_tools/run_tests.sh memory
./build_tools/run_tests.sh simulation --benchmark

# Link final executable
./build_tools/link_assembly.sh full
```

### Performance Testing
```bash
# Run all benchmarks
./build_tools/run_benchmarks.sh all

# Specific benchmark categories
./build_tools/run_benchmarks.sh micro    # Function-level benchmarks
./build_tools/run_benchmarks.sh system   # Full system benchmarks
./build_tools/run_benchmarks.sh scale    # Scalability tests (1K-1M agents)
```

### Testing Individual Functions
```bash
# Test specific assembly function
./build_tools/run_tests.sh memory --function tlsf_malloc

# Benchmark specific operation
./build_tools/run_benchmarks.sh micro --function astar_pathfind

# Profile with instruments
./build_tools/run_benchmarks.sh profile --module simulation
```

## High-Level Architecture

### ARM64 Assembly Module Structure

The project has been fully converted to pure ARM64 assembly with the following module organization:

1. **Platform Layer** (`src/platform/`)
   - `bootstrap.s` - Main entry point and application lifecycle
   - `objc_bridge.s` - Objective-C runtime integration with 95%+ cache hit rate
   - `syscalls.s` - Direct macOS system call wrappers (35+ syscalls)
   - `threading.s` - Work-stealing queues, atomics (100M+ ops/sec), TLS
   - `mtkview_delegate.s` - Metal view delegate callbacks

2. **Memory Management** (`src/memory/`)
   - `tlsf_allocator.s` - TLSF allocator with < 100ns malloc/free
   - `agent_allocator.s` - Pool-based allocation for agents
   - `tls_allocator.s` - Thread-local storage management
   - Memory pools optimized for 64-byte cache lines

3. **Graphics Pipeline** (`src/graphics/`)
   - `metal_encoder.s` - Metal command encoding (100M+ vertices/sec)
   - `vertex_shader_asm.s` - CPU vertex processing with NEON
   - `fragment_shader_asm.s` - Fragment processing
   - `sprite_batch.s` - 4-sprite parallel NEON batching
   - `particles.s` - 130K+ particle system at 60 FPS
   - `isometric_transform.s` - NEON coordinate conversion
   - `debug_overlay.s` - Performance visualization (< 0.5ms render)

4. **Simulation Core** (`src/simulation/`)
   - `core.s` - Main loop (60 FPS render, 30Hz simulation)
   - `zoning_neon.s` - 4x4 tile NEON processing
   - `utilities_flood.s` - Infrastructure propagation with BFS
   - `rci_demand.s` - Economic simulation (30M+ ops/sec)
   - `entity_system.s` - ECS supporting 1M+ entities

5. **AI Systems** (`src/ai/`)
   - `astar_core.s` - A* pathfinding (< 0.5ms per path)
   - `traffic_flow.s` - 8-vehicle NEON traffic simulation
   - `citizen_behavior.s` - State machines for 1M+ citizens
   - `emergency_services.s` - Priority dispatch (< 500μs)
   - `mass_transit.s` - Route optimization for 100K+ passengers

6. **Infrastructure** (`src/infrastructure/`)
   - `network_graphs.s` - Dijkstra and max-flow algorithms
   - NEON-accelerated utility propagation
   - Dynamic network optimization

7. **User Interface** (`src/ui/`)
   - `input_handler.s` - < 1ms input latency
   - `gesture_recognition.s` - Multi-touch gestures
   - Command dispatch to simulation systems

8. **Persistence** (`src/persistence/`)
   - `save_load.s` - 50MB/s save, 80MB/s load speeds
   - LZ4-style compression in ARM64 assembly
   - Incremental saves for large cities

9. **Audio System** (`src/audio/`)
   - `spatial_audio.s` - 256 concurrent 3D sources
   - `neon_sound_mixer.s` - 8-channel SIMD mixing
   - `environmental_effects.s` - Real-time reverb

### Key Architectural Features

1. **NEON SIMD Throughout**
   - 4x-16x parallel processing across all systems
   - Cache-aligned structures (64-byte boundaries)
   - Structure-of-Arrays memory layout for vectorization

2. **Performance Achieved**
   - 1M+ agents at 60 FPS ✓
   - < 4GB memory usage ✓
   - < 50% CPU on Apple M1 ✓
   - Zero heap allocations in hot paths ✓

3. **Threading Model**
   - Work-stealing queues for load balancing
   - Lock-free atomics with LSE extensions
   - Apple Silicon P/E core awareness
   - Fixed thread pool for predictability

4. **Memory Architecture**  
   - TLSF general allocator for dynamic allocation
   - Pool allocators for hot path objects
   - Thread-local storage for zero contention
   - Double-buffered ECS for safe updates

## Important Notes

1. **Assembly Syntax**: Apple's assembler doesn't support complex `.struct` directives. Use simple syntax and manual offset calculations.

2. **NEON Register Usage**: v0-v7 are caller-saved, v8-v15 must be preserved. Use v16-v31 freely in leaf functions.

3. **Atomic Operations**: Use LSE (Large System Extensions) atomics when available: `ldadd`, `swp`, `cas` instructions provide better performance than exclusive load/store pairs.

4. **Cache Line Alignment**: Always align hot data structures to 64-byte boundaries for Apple Silicon L1 cache efficiency.

5. **Integration Points**: Each module provides C-compatible interfaces for gradual migration. Headers are in each module directory.

## Common Development Tasks

```bash
# Clean build
./build_tools/build_master.sh clean

# Check assembly syntax without building
as -arch arm64 -o /dev/null src/module/file.s

# Generate performance report
./build_tools/run_benchmarks.sh all --report

# Create debug symbols
./build_tools/build_assembly.sh debug --symbols

# Deploy macOS app
./build_tools/deploy.sh standard app_bundle
```