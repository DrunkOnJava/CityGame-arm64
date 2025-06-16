# SimCity ARM64 Assembly Project Master Plan

## Project Overview

This document integrates the comprehensive technical whitepaper, development methodology, and CLI workflow for building a city simulation engine entirely in ARM64 assembly language for Apple Silicon.

### Key Project Goals

1. **Performance**: Support 1 million+ agents at 60 FPS
2. **Efficiency**: Memory footprint under 2GB
3. **Determinism**: Frame-perfect reproducibility for multiplayer
4. **Maintainability**: Modular architecture with clear interfaces
5. **Innovation**: Parallel development using 10 Claude Code agents

## Project Structure

```
projectsimcity/
├── PROJECT_MASTER_PLAN.md (this file)
├── simcity_development_plan.md
├── simcity-ctl.sh (master control script)
├── manifest.json
├── CMakeLists.txt
│
├── docs/
│   ├── whitepaper/
│   │   └── simcity_technical_whitepaper.md
│   ├── architecture/
│   ├── api/
│   ├── guides/
│   └── decisions/
│
├── src/
│   ├── platform/     (Agent 1)
│   ├── memory/       (Agent 2)
│   ├── graphics/     (Agent 3)
│   ├── simulation/   (Agent 4)
│   ├── agents/       (Agent 5)
│   ├── network/      (Agent 6)
│   ├── ui/          (Agent 7)
│   ├── io/          (Agent 8)
│   ├── audio/       (Agent 9)
│   └── tools/       (Agent 10)
│
├── include/
│   ├── interfaces/
│   ├── constants/
│   ├── macros/
│   └── types/
│
├── scripts/
│   ├── setup-environment.sh
│   ├── init-project.sh
│   ├── asset-pipeline.sh
│   ├── build-all.sh
│   ├── test-runner.sh
│   ├── dev-tools.sh
│   ├── agent-coordinator.sh
│   └── utils/
│
├── tests/
│   ├── unit/
│   ├── integration/
│   ├── performance/
│   └── stress/
│
├── assets/
│   ├── tiles/
│   ├── ui/
│   ├── sfx/
│   └── data/
│
├── build/
│   ├── debug/
│   ├── release/
│   ├── profile/
│   └── test/
│
├── .agents/          (Agent workspaces)
├── .locks/          (Resource locks)
└── tmp/            (Temporary files)
```

## Development Phases

### Phase 1: Foundation (Weeks 1-2)
- [x] Project structure setup
- [x] Development environment configuration
- [x] Agent workspace initialization
- [ ] Core interface definitions
- [ ] Build system setup
- [ ] Basic memory allocator (TLSF)

### Phase 2: Core Systems (Weeks 3-6)
- [ ] Platform abstraction layer
- [ ] Graphics initialization (Metal)
- [ ] Basic simulation loop
- [ ] Tile system implementation
- [ ] Simple rendering pipeline
- [ ] Unit test framework

### Phase 3: Advanced Features (Weeks 7-10)
- [ ] Agent system with LOD
- [ ] Pathfinding algorithms
- [ ] Economic simulation
- [ ] Infrastructure networks
- [ ] UI system (IMGUI-style)
- [ ] Audio integration

### Phase 4: Optimization & Polish (Weeks 11-12)
- [ ] SIMD optimization
- [ ] Cache optimization
- [ ] GPU-driven rendering
- [ ] Performance profiling
- [ ] Integration testing
- [ ] Documentation

## Technical Architecture Summary

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

## Agent Responsibilities

### Agent 1: Platform & System Integration
- System calls and OS integration
- Thread management with P/E cores
- Metal device initialization
- Performance monitoring

### Agent 2: Memory Management
- TLSF allocator implementation
- Slab allocator for fixed objects
- Memory safety and debugging
- Cache optimization

### Agent 3: Graphics & Rendering
- Metal pipeline setup
- Isometric tile rendering
- Sprite batching system
- GPU optimization

### Agent 4: Simulation Engine
- Main game loop
- World chunk management
- Tile update logic
- Save/load system

### Agent 5: Agent Systems & AI
- Citizen/vehicle agents
- Pathfinding (A*, flow fields)
- Behavior state machines
- LOD-based updates

### Agent 6: Infrastructure Networks
- Road/rail networks
- Power grid simulation
- Water/sewage systems
- Graph algorithms

### Agent 7: User Interface
- Immediate mode GUI
- Tool systems
- Data visualization
- Input handling

### Agent 8: I/O & Serialization
- Save game system
- Asset loading
- Configuration files
- Mod support

### Agent 9: Audio System
- Core Audio integration
- 3D positional audio
- Music streaming
- Sound effects

### Agent 10: Tools & Debug
- Profiling tools
- Debug console
- Testing framework
- Development utilities

## Workflow Commands

### Quick Start
```bash
# Initial setup
./simcity-ctl.sh setup
./simcity-ctl.sh fetch-assets

# Development
./simcity-ctl.sh agent init
./simcity-ctl.sh build all
./simcity-ctl.sh test all

# Run simulation
./simcity-ctl.sh run
```

### Agent Development
```bash
# Initialize agent workspaces
./scripts/agent-coordinator.sh init

# Work on specific agent
./scripts/agent-coordinator.sh sync 1 platform

# Integration testing
./scripts/agent-coordinator.sh integrate
```

### Build Configurations
```bash
# Debug build with assertions
./scripts/build-all.sh build debug

# Optimized release build
./scripts/build-all.sh build release

# Profile-guided optimization
./scripts/build-all.sh build profile
```

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

## Testing Strategy

### Unit Tests
- Each function has dedicated tests
- Edge cases and error conditions
- Performance regression tests

### Integration Tests
- Cross-agent communication
- Full simulation scenarios
- Save/load verification

### Performance Tests
- Benchmark suite with hyperfine
- Profiling with Instruments
- Memory leak detection

### Stress Tests
- 1M+ agent simulations
- Memory allocation stress
- GPU saturation tests

## Development Guidelines

### Code Style
- Consistent assembly formatting
- Comprehensive documentation
- Clear register usage
- Meaningful labels

### Version Control
- Feature branches per agent
- Atomic commits
- Integration branch for testing
- Protected main branch

### Communication
- Daily agent sync meetings
- Interface change notifications
- Integration test results
- Performance tracking

## Key Technical Decisions

1. **Assembly-only**: Maximum performance and control
2. **TLSF allocator**: Fast, deterministic allocation
3. **Fixed timestep**: Deterministic simulation
4. **TBDR optimization**: Efficient Apple GPU usage
5. **Agent LOD**: Scalable to millions of entities
6. **Job system**: Optimal P/E core utilization

## Risk Mitigation

### Technical Risks
- **Complexity**: Modular design, clear interfaces
- **Debugging**: Comprehensive logging, assertions
- **Performance**: Early profiling, optimization
- **Integration**: Continuous testing, staging

### Process Risks
- **Coordination**: Lock system, clear ownership
- **Scope creep**: Fixed feature set, time boxing
- **Quality**: Automated testing, code review
- **Documentation**: Inline docs, wiki updates

## Success Metrics

1. **Performance**: Meet all target benchmarks
2. **Stability**: < 1 crash per 100 hours
3. **Features**: All planned systems implemented
4. **Code Quality**: 80%+ test coverage
5. **Documentation**: Complete API docs

## Next Steps

1. Complete environment setup for all agents
2. Define and document all interfaces
3. Implement core memory system
4. Create basic simulation loop
5. Begin agent development in parallel

---

*This master plan serves as the central coordination document for the SimCity ARM64 Assembly project. It should be updated as the project evolves.*