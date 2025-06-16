# SimCity ARM64 Math Library

**Agent 1: Core Engine Developer**  
**ARM64 Assembly with NEON SIMD Optimization**

## Overview

This directory contains the high-performance math library for SimCity ARM64, designed to handle the computational demands of 1M+ agent simulation using NEON SIMD instructions and cache-optimized algorithms.

## Performance Targets

- **Vector Operations**: 4x float32 operations per instruction (NEON quad)
- **Matrix Operations**: <100ns for 4x4 matrix multiplication
- **Agent Math**: <50ns per agent position/rotation update
- **Pathfinding**: <1μs per A* node evaluation
- **Physics**: 60fps with 1M+ agents using SIMD batching

## Core Components

### 1. Vector Math (`vector.s`)
- **NEON SIMD optimized** 2D/3D vector operations
- **Batch processing** for agent positions (4 agents per instruction)
- Cache-friendly data layouts for optimal performance
- Specialized functions for common SimCity operations

### 2. Matrix Math (`matrix.s`)
- **4x4 matrix operations** for transformations
- **NEON-optimized** matrix multiplication
- Camera projection and view matrices
- Isometric projection for city rendering

### 3. Fast Math Functions (`fastmath.s`)
- **Approximation algorithms** for trigonometric functions
- **Look-up tables** with NEON interpolation
- **SIMD sqrt, rsqrt** for distance calculations
- Optimized for real-time simulation requirements

### 4. Agent Math (`agentmath.s`)
- **Batch agent updates** using NEON
- Position, velocity, and acceleration calculations
- Collision detection with spatial optimization
- Pathfinding cost calculations

### 5. Random Number Generation (`random.s`)
- **Deterministic PRNG** for reproducible simulation
- **NEON-accelerated** batch random generation
- Multiple independent streams for threading
- Statistical distributions for agent behavior

## API Reference

### Vector Operations
```assembly
// Single vector operations
vec2_add:           // Add two 2D vectors
vec2_sub:           // Subtract two 2D vectors  
vec2_mul_scalar:    // Multiply vector by scalar
vec2_dot:           // Dot product
vec2_length:        // Vector length
vec2_normalize:     // Normalize vector

// NEON batch operations (4 vectors at once)
vec2_add_batch:     // Add 4 pairs of 2D vectors
vec2_sub_batch:     // Subtract 4 pairs of 2D vectors
vec2_mul_scalar_batch: // Multiply 4 vectors by scalars
vec2_length_batch:  // Length of 4 vectors
```

### Matrix Operations
```assembly
mat4_identity:      // Create identity matrix
mat4_multiply:      // Multiply two 4x4 matrices
mat4_translate:     // Create translation matrix
mat4_scale:         // Create scale matrix
mat4_rotate:        // Create rotation matrix
mat4_perspective:   // Create perspective projection
mat4_orthographic:  // Create orthographic projection
```

### Fast Math
```assembly
fast_sin:           // Fast sine approximation
fast_cos:           // Fast cosine approximation
fast_sqrt:          // Fast square root
fast_rsqrt:         // Fast reciprocal square root
fast_atan2:         // Fast arctangent2
```

### Agent Math
```assembly
agent_update_positions:    // Batch update agent positions
  // Args: x0 = agent_array, x1 = count, x2 = delta_time
  // Updates positions using NEON (4 agents per iteration)

agent_calculate_distances: // Batch calculate distances
  // Args: x0 = from_array, x1 = to_array, x2 = count
  // Returns: x0 = distance_array

agent_apply_forces:       // Apply forces to agents
  // Args: x0 = agent_array, x1 = force_array, x2 = count
```

## Data Structures

### Vector Types
```assembly
.struct 0
vec2_x:     .space 4    // float32 x coordinate
vec2_y:     .space 4    // float32 y coordinate
vec2_size:

.struct 0
vec3_x:     .space 4    // float32 x coordinate
vec3_y:     .space 4    // float32 y coordinate
vec3_z:     .space 4    // float32 z coordinate
vec3_size:

// NEON-optimized batch structure (4 vectors)
.struct 0
vec2_batch_x:   .space 16   // 4x float32 x coordinates
vec2_batch_y:   .space 16   // 4x float32 y coordinates
vec2_batch_size:
```

### Matrix Types
```assembly
.struct 0
mat4_data:  .space 64   // 16x float32 (4x4 matrix)
mat4_size:
```

### Agent Math Types
```assembly
.struct 0
agent_pos_x:    .space 4    // Position X
agent_pos_y:    .space 4    // Position Y
agent_vel_x:    .space 4    // Velocity X
agent_vel_y:    .space 4    // Velocity Y
agent_force_x:  .space 4    // Force X
agent_force_y:  .space 4    // Force Y
agent_mass:     .space 4    // Mass
agent_radius:   .space 4    // Collision radius
agent_math_size:
```

## NEON SIMD Usage

### Loading Data
```assembly
// Load 4 float32 values into NEON register
ld1     {v0.4s}, [x0]       // Load 4 floats from x0
ld1     {v1.4s}, [x1]       // Load 4 floats from x1

// Load interleaved data (structure of arrays)
ld4     {v0.4s, v1.4s, v2.4s, v3.4s}, [x0]  // Load 4 vectors
```

### Vector Operations
```assembly
// Add 4 pairs of vectors simultaneously
fadd    v0.4s, v0.4s, v1.4s    // v0 = v0 + v1 (4 operations)

// Multiply by scalar (broadcast)
fmul    v0.4s, v0.4s, v2.s[0]  // v0 = v0 * scalar (4 operations)

// Dot product using NEON
fmul    v0.4s, v0.4s, v1.4s    // Component-wise multiply
faddp   v0.4s, v0.4s, v0.4s    // Pairwise add
faddp   v0.4s, v0.4s, v0.4s    // Final sum in v0.s[0]
```

### Storing Results
```assembly
// Store 4 results
st1     {v0.4s}, [x0]          // Store 4 floats to x0

// Store interleaved results
st4     {v0.4s, v1.4s, v2.4s, v3.4s}, [x0]  // Store 4 vectors
```

## Performance Optimizations

### Cache Optimization
- **64-byte alignment** for critical data structures
- **Sequential access patterns** for NEON loads
- **Prefetching** for large batch operations
- **Structure of Arrays** layout for SIMD efficiency

### Loop Unrolling
```assembly
// Process 16 agents at once (4 batches of 4)
math_update_agents_unrolled:
    // Batch 1: agents 0-3
    ld4     {v0.4s, v1.4s, v2.4s, v3.4s}, [x0], #64
    // ... math operations ...
    st4     {v0.4s, v1.4s, v2.4s, v3.4s}, [x2], #64
    
    // Batch 2: agents 4-7
    ld4     {v4.4s, v5.4s, v6.4s, v7.4s}, [x0], #64
    // ... math operations ...
    st4     {v4.4s, v5.4s, v6.4s, v7.4s}, [x2], #64
    
    // Continue for remaining batches...
```

### Branch Prediction
- **Minimize branches** in inner loops
- **Use conditional instructions** instead of branches
- **Vectorized comparisons** using NEON

## Integration with SimCity Systems

### Agent System Integration
```assembly
// Update 1M agents efficiently
agent_system_update:
    ldr     x0, =agent_positions    // Structure of arrays
    ldr     x1, =agent_velocities
    ldr     x2, =agent_count
    mov     x3, x4                  // delta_time
    bl      agent_update_positions  // NEON batch update
```

### Graphics System Integration
```assembly
// Transform vertices for isometric projection
graphics_transform_batch:
    ldr     x0, =world_positions
    ldr     x1, =screen_positions
    ldr     x2, =transform_matrix
    bl      mat4_transform_points_batch
```

### Pathfinding Integration
```assembly
// Calculate heuristic costs for A*
pathfind_calculate_costs:
    ldr     x0, =node_positions
    ldr     x1, =goal_position
    ldr     x2, =node_count
    bl      agent_calculate_distances
```

## Build Configuration

### Compiler Flags
```makefile
NEON_FLAGS = -march=armv8-a+simd -mtune=apple-a14
MATH_FLAGS = -ffast-math -fno-math-errno
OPT_FLAGS = -O3 -flto -fomit-frame-pointer
```

### Assembly Directives
```assembly
.cpu generic+simd       // Enable NEON instructions
.arch armv8-a+simd     // Target ARM64 with SIMD
```

## Testing and Validation

### Unit Tests
- **Correctness tests** against reference implementations
- **Precision tests** for approximation functions
- **Edge case handling** (NaN, infinity, denormals)

### Performance Tests
- **Throughput benchmarks** (operations per second)
- **Latency measurements** for critical operations
- **Cache miss analysis** using performance counters

### Stress Tests
- **1M+ agent simulation** with full math pipeline
- **Sustained performance** over extended periods
- **Memory pressure** scenarios

## Future Enhancements

- **SVE support** for future ARM processors
- **Fixed-point math** for deterministic simulation
- **GPU compute shaders** for massive parallelism
- **Auto-vectorization** hints for compiler optimization

---

**Author**: Agent 1 - Core Engine Developer  
**Version**: 1.0  
**Last Updated**: June 2025