# SimCity ARM64 Assembly Technical Whitepaper

## Executive Summary

This whitepaper outlines the technical architecture and implementation details for a high-performance city simulation engine written entirely in ARM64 assembly language for Apple Silicon. The project aims to support over 1 million simultaneous agents at 60 FPS while maintaining a memory footprint under 2GB.

## Technical Architecture

### Memory Layout

- **TLSF Allocator**: General purpose with O(1) operations
- **Slab Allocators**: Fixed-size objects (agents, tiles)
- **Pool Allocators**: Per-frame temporary memory
- **Cache-aligned structures**: 64-byte tile data

### Simulation Design

- **Fixed timestep**: 30Hz simulation, 60-120Hz rendering
- **Hierarchical world**: 4096x4096 tiles in 16x16 chunks
- **LOD agents**: Near (every frame), Medium (1/4), Far (1/16)
- **Job system**: Work-stealing with P/E core awareness

### Rendering Pipeline

- **Metal 3**: GPU-driven tile rendering
- **TBDR optimized**: Screen-space tile sorting
- **Isometric projection**: Efficient depth sorting
- **Dynamic batching**: Minimize draw calls

## Performance Targets

### CPU Performance
- Agent updates: < 10ms for 1M agents
- Tile updates: < 5ms for visible chunks
- Pathfinding: < 1ms per agent
- Economic simulation: < 3ms per tick

### Memory Usage
- Base engine: < 100MB
- Per agent: < 100 bytes
- Per tile: 64 bytes (1 cache line)
- Total for 1M agents: < 2GB

### GPU Performance
- Draw calls: < 1000 per frame
- Triangle count: < 5M visible
- Texture memory: < 500MB
- Frame time: < 16ms (60 FPS)

## Key Technical Decisions

1. **Assembly-only**: Maximum performance and control
2. **TLSF allocator**: Fast, deterministic allocation
3. **Fixed timestep**: Deterministic simulation
4. **TBDR optimization**: Efficient Apple GPU usage
5. **Agent LOD**: Scalable to millions of entities
6. **Job system**: Optimal P/E core utilization

## Implementation Strategy

The project utilizes a parallel development approach with 10 specialized agents, each responsible for a core system:

1. Platform & System Integration
2. Memory Management
3. Graphics & Rendering
4. Simulation Engine
5. Agent Systems & AI
6. Infrastructure Networks
7. User Interface
8. I/O & Serialization
9. Audio System
10. Tools & Debug

Each agent works independently on their module while adhering to clearly defined interfaces, enabling rapid parallel development while maintaining system coherence.