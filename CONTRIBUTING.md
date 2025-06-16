# Contributing to SimCity ARM64

Thank you for your interest in contributing to SimCity ARM64! This document provides guidelines and information for contributors.

## 🤝 Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for all contributors.

## 🚀 Getting Started

1. **Fork the Repository**
   - Create your own fork of the project
   - Clone your fork locally

2. **Set Up Development Environment**
   ```bash
   git clone https://github.com/yourusername/simcity-arm64.git
   cd simcity-arm64
   ./scripts/setup-environment.sh
   ```

3. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

## 📝 Development Guidelines

### Code Style
- Follow the assembly coding conventions in [GUIDELINES.md](GUIDELINES.md)
- Use meaningful variable and function names
- Comment complex algorithms and assembly routines
- Maintain consistent indentation (4 spaces)

### Commit Messages
Follow the conventional commit format:
```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `perf`: Performance improvement
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test additions/changes
- `chore`: Build/maintenance tasks

Example:
```
feat(agents): Add crowd pathfinding algorithm

Implement A* pathfinding optimized for ARM64 NEON instructions.
Achieves 3x performance improvement over previous implementation.

Closes #42
```

### Testing
- Write tests for new functionality
- Ensure all tests pass before submitting PR
- Include performance benchmarks for optimization PRs

## 🔄 Pull Request Process

1. **Before Submitting**
   - Update documentation for new features
   - Add/update tests as needed
   - Run linting and formatting tools
   - Test on Apple Silicon hardware

2. **PR Description**
   - Clearly describe the changes
   - Link to related issues
   - Include screenshots for UI changes
   - Provide performance metrics if applicable

3. **Review Process**
   - Address reviewer feedback promptly
   - Keep PR focused and atomic
   - Rebase on main if needed

## 🏗️ Architecture

When contributing, consider the modular agent architecture:
- Agent 0: Core Infrastructure & ECS
- Agent 1: Memory Management
- Agent 2: File I/O & Serialization
- Agent 3: Graphics & Rendering
- Agent 4: Simulation Engine
- Agent 5: Citizen & Vehicle Agents
- Agent 6: UI & HUD System
- Agent 7: Audio System
- Agent 8: Network Infrastructure
- Agent 9: Debug & Profiling Tools

## 🐛 Reporting Issues

### Bug Reports
Include:
- Clear description of the issue
- Steps to reproduce
- Expected vs actual behavior
- System information (macOS version, chip model)
- Screenshots/videos if applicable
- Relevant log output

### Feature Requests
Include:
- Clear use case description
- Proposed implementation approach
- Performance implications
- Mockups/diagrams if applicable

## 📚 Resources

- [ARM64 Assembly Reference](https://developer.arm.com/documentation/)
- [Apple Metal Documentation](https://developer.apple.com/metal/)
- [Project Architecture](docs/architecture/README.md)
- [Performance Guidelines](docs/guides/performance.md)

## 🎯 Priority Areas

Current areas where contributions are especially welcome:
1. ARM64 assembly optimization
2. Agent behavior implementation
3. Performance testing and benchmarking
4. Documentation improvements
5. Graphics enhancements

## 📄 License

By contributing, you agree that your contributions will be licensed under the project's MIT License.

## 🙏 Recognition

Contributors will be recognized in:
- Project README
- Release notes
- Contributors page

Thank you for helping make SimCity ARM64 better!