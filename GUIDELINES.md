# SimCity ARM64 Development Guidelines

## 📋 Table of Contents

1. [Project Philosophy](#project-philosophy)
2. [Code Style](#code-style)
3. [Assembly Guidelines](#assembly-guidelines)
4. [Architecture Principles](#architecture-principles)
5. [Development Workflow](#development-workflow)
6. [Testing Standards](#testing-standards)
7. [Documentation Requirements](#documentation-requirements)
8. [Performance Guidelines](#performance-guidelines)
9. [Security Considerations](#security-considerations)
10. [Contributing Process](#contributing-process)

## 🎯 Project Philosophy

### Core Principles

1. **Performance First**: Every decision should consider performance impact
2. **Modular Design**: Clear separation of concerns between agents
3. **Clean Code**: Readable, maintainable assembly code
4. **Documentation**: Code should be self-documenting with clear comments
5. **Testing**: Comprehensive testing at all levels

### Design Goals

- Target 1M+ agents at 60 FPS minimum
- Memory efficiency (< 4GB for full simulation)
- Real-time responsiveness (< 16ms frame time)
- Scalable architecture for future features

## 📝 Code Style

### Assembly Code Conventions

#### File Structure
```assembly
//
// filename.s - Brief description
// Agent X: Agent Name
//
// Detailed description of module functionality
// 
// Author: Your Name
// Date: YYYY-MM-DD
//

.include "constants.s"
.include "macros.s"

.section __TEXT,__text,regular,pure_instructions
.align 4

// Constants specific to this module
.equ LOCAL_CONSTANT, 42

// Global exports
.global _function_name

// Function implementation
_function_name:
    // Function prologue
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Function body
    
    // Function epilogue
    ldp     x29, x30, [sp], #16
    ret
```

#### Naming Conventions

1. **Functions**: `lowercase_with_underscores`
   ```assembly
   _calculate_agent_position:
   _render_sprite_batch:
   ```

2. **Constants**: `UPPERCASE_WITH_UNDERSCORES`
   ```assembly
   .equ MAX_AGENTS, 1000000
   .equ TILE_SIZE, 64
   ```

3. **Labels**: `descriptive_lowercase`
   ```assembly
   loop_start:
   error_handler:
   ```

4. **Structures**: `PascalCase`
   ```assembly
   .struct AgentData
       position:   .float 3
       velocity:   .float 3
       state:      .word 1
   .endstruct
   ```

#### Register Usage

- **x0-x7**: Function arguments and return values
- **x8**: Indirect result location
- **x9-x15**: Temporary registers
- **x16-x17**: Intra-procedure-call temporary
- **x18**: Platform reserved
- **x19-x28**: Callee-saved registers
- **x29**: Frame pointer
- **x30**: Link register
- **sp**: Stack pointer

#### Comments

1. **Function Headers**:
   ```assembly
   //
   // function_name - Brief description
   // 
   // Parameters:
   //   x0 = parameter description
   //   x1 = parameter description
   //
   // Returns:
   //   x0 = return value description
   //
   // Modifies:
   //   List of modified registers
   //
   ```

2. **Inline Comments**:
   ```assembly
   ldr     x0, [x1, #16]   // Load agent position
   add     x0, x0, #1      // Increment counter
   ```

3. **Block Comments**:
   ```assembly
   // Calculate isometric projection
   // This transforms 3D world coordinates to 2D screen coordinates
   // using the standard isometric transformation matrix
   ```

### Objective-C/Metal Code Conventions

Follow standard Apple coding guidelines with these additions:

1. **Method Names**: Descriptive camelCase
2. **Properties**: Use modern property syntax
3. **Error Handling**: Always check Metal API returns
4. **Memory Management**: Use ARC appropriately

## 🏗️ Architecture Principles

### Agent System Design

Each agent (0-9) should:

1. **Single Responsibility**: Focus on one aspect of the system
2. **Clear Interfaces**: Well-defined communication protocols
3. **Minimal Dependencies**: Reduce coupling between agents
4. **Performance Aware**: Optimize for cache and parallelism

### Memory Layout

1. **Structure of Arrays (SoA)**: Preferred over Array of Structures
2. **Cache Line Alignment**: Align hot data to 64-byte boundaries
3. **Memory Pools**: Use pooling for frequent allocations
4. **NUMA Awareness**: Consider memory locality

### Concurrency Model

1. **Thread Safety**: Document thread-safe functions
2. **Lock-Free Design**: Prefer atomic operations
3. **Work Distribution**: Balance load across cores
4. **Synchronization**: Minimize synchronization points

## 🔄 Development Workflow

### Git Workflow

1. **Branching Strategy**:
   - `main`: Stable release branch
   - `develop`: Integration branch
   - `feature/*`: Feature branches
   - `fix/*`: Bug fix branches
   - `perf/*`: Performance improvement branches

2. **Commit Messages**:
   ```
   <type>(<scope>): <subject>
   
   <body>
   
   <footer>
   ```
   
   Types: feat, fix, docs, style, refactor, perf, test, chore
   
   Example:
   ```
   feat(agents): Add pathfinding for citizen agents
   
   Implement A* pathfinding algorithm optimized for ARM64 NEON.
   Performance tested with 100k agents simultaneously.
   
   Closes #123
   ```

3. **Pull Request Process**:
   - Create feature branch from `develop`
   - Write code following guidelines
   - Add tests for new functionality
   - Update documentation
   - Submit PR with description
   - Address review feedback
   - Squash and merge

### Code Review Checklist

- [ ] Follows assembly coding conventions
- [ ] Includes appropriate comments
- [ ] Has unit tests
- [ ] Performance impact assessed
- [ ] Documentation updated
- [ ] No debug code left
- [ ] Error handling implemented
- [ ] Memory leaks checked

## 🧪 Testing Standards

### Test Categories

1. **Unit Tests**: Individual function testing
2. **Integration Tests**: Agent interaction testing
3. **Performance Tests**: Benchmark critical paths
4. **Stress Tests**: Test with maximum load
5. **Regression Tests**: Prevent feature breakage

### Writing Tests

```assembly
// test_agent_movement.s
test_agent_movement:
    // Setup
    bl      setup_test_environment
    
    // Execute
    mov     x0, #TEST_AGENT_ID
    bl      update_agent_position
    
    // Verify
    ldr     x1, [x0, #AgentData.position]
    cmp     x1, #EXPECTED_POSITION
    b.ne    test_failed
    
    // Cleanup
    bl      cleanup_test_environment
    mov     x0, #TEST_PASSED
    ret
```

### Performance Testing

Always benchmark performance-critical code:

```assembly
    // Start timing
    mrs     x0, CNTVCT_EL0
    str     x0, [sp, #-16]!
    
    // Code to benchmark
    bl      critical_function
    
    // End timing
    mrs     x1, CNTVCT_EL0
    ldr     x0, [sp], #16
    sub     x0, x1, x0
    
    // Report results
    bl      report_performance
```

## 📚 Documentation Requirements

### Code Documentation

1. **Every File**: Must have header with description
2. **Every Function**: Must have parameter/return documentation
3. **Complex Algorithms**: Must have detailed explanation
4. **Performance Notes**: Document optimization decisions

### External Documentation

1. **API Documentation**: Generate from code comments
2. **Architecture Docs**: Keep design documents updated
3. **User Guides**: Maintain end-user documentation
4. **Developer Guides**: Document setup and workflows

## ⚡ Performance Guidelines

### Optimization Priorities

1. **Algorithm First**: Choose optimal algorithms
2. **Data Layout**: Optimize for cache efficiency
3. **Parallelism**: Utilize all CPU cores
4. **SIMD**: Use NEON instructions where applicable
5. **Memory Access**: Minimize memory bandwidth

### ARM64 Specific Optimizations

1. **Use NEON for Vector Operations**:
   ```assembly
   // Process 4 floats at once
   ld1     {v0.4s}, [x0]
   ld1     {v1.4s}, [x1]
   fadd    v2.4s, v0.4s, v1.4s
   st1     {v2.4s}, [x2]
   ```

2. **Prefetch Data**:
   ```assembly
   prfm    pldl1keep, [x0, #64]
   ```

3. **Align Critical Loops**:
   ```assembly
   .align 6  // Align to cache line
   critical_loop:
   ```

### Performance Monitoring

1. **Use Performance Counters**: Monitor cache misses, branch mispredictions
2. **Profile Regularly**: Run profiling on each major change
3. **Set Performance Budgets**: Each frame should complete in < 16ms
4. **Track Metrics**: Log and graph performance over time

## 🔒 Security Considerations

### Input Validation

1. **Bounds Checking**: Always validate array indices
2. **Integer Overflow**: Check for overflow in calculations
3. **Buffer Sizes**: Verify buffer sizes before operations
4. **User Input**: Sanitize all user input

### Memory Safety

1. **Stack Protection**: Use stack canaries where appropriate
2. **ASLR**: Support address space layout randomization
3. **DEP/NX**: Ensure data execution prevention
4. **Secure Coding**: Follow ARM security guidelines

## 🤝 Contributing Process

### Before Contributing

1. Read these guidelines completely
2. Check existing issues and PRs
3. Set up development environment
4. Run existing tests successfully

### Making Changes

1. **Small Changes**: Direct PR to `develop`
2. **Large Features**: Discuss in issue first
3. **Breaking Changes**: Require RFC process
4. **Performance Impact**: Include benchmarks

### Submission Checklist

- [ ] Code follows style guidelines
- [ ] Tests pass locally
- [ ] Documentation updated
- [ ] Performance impact measured
- [ ] PR description complete
- [ ] Linked to relevant issues

### Review Process

1. **Automated Checks**: CI must pass
2. **Code Review**: At least one approval required
3. **Performance Review**: For performance-critical changes
4. **Architecture Review**: For significant changes

## 📋 Additional Resources

### Recommended Reading

1. [ARM Architecture Reference Manual](https://developer.arm.com/documentation/)
2. [Apple Metal Programming Guide](https://developer.apple.com/metal/)
3. [ARM64 Assembly Language](https://modexp.wordpress.com/2018/10/30/arm64-assembly/)
4. [Performance Optimization Guide](https://developer.apple.com/documentation/apple-silicon/tuning-your-code-s-performance-on-apple-silicon)

### Tools

1. **Instruments**: For profiling on macOS
2. **lldb**: For debugging assembly
3. **objdump**: For examining object files
4. **nm**: For symbol inspection
5. **otool**: For Mach-O file analysis

### Community

- **Discord**: Development discussions
- **GitHub Issues**: Bug reports and features
- **Wiki**: Extended documentation
- **Forum**: General discussions

---

Remember: These guidelines are living documents. Propose changes through the RFC process if you identify improvements.