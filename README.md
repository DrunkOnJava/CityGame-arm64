# SimCity ARM64 - High-Performance City Simulation Engine

<div align="center">

[![Production Ready](https://img.shields.io/badge/Status-Production%20Ready-brightgreen.svg)](https://github.com/drunkonjava/simcity-arm64)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%2FM2%2FM3%2FM4-blue.svg)](https://developer.apple.com/silicon/)
[![ARM64 Assembly](https://img.shields.io/badge/Language-ARM64%20Assembly-red.svg)](https://developer.arm.com/architectures/instruction-sets/base-isas/a64)
[![Hot Module Replacement](https://img.shields.io/badge/HMR-Sub--millisecond-orange.svg)](https://github.com/drunkonjava/simcity-arm64)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**SimCity ARM64** is a revolutionary high-performance city simulation engine written entirely in ARM64 assembly for Apple Silicon, featuring an enterprise-grade Hot Module Replacement (HMR) system that delivers Vite-like development experience for native applications.

</div>

## 🎯 Overview

SimCity ARM64 is an ambitious project to create a cutting-edge city simulation using pure ARM64 assembly language optimized for Apple Silicon processors. The project demonstrates the power of low-level programming while maintaining modern software architecture principles.

### Key Features

- **🚀 Performance**: 1M+ simultaneous agents at 60 FPS
- **🏗️ Architecture**: Modular design with 10 specialized subsystems
- **🎨 Graphics**: Metal API integration with isometric rendering
- **🧠 AI**: Advanced agent behavior and pathfinding
- **🌐 Infrastructure**: Complete city services simulation
- **💰 Economics**: Realistic economic modeling
- **🎮 Interactive**: Full city-building gameplay

## 📋 Requirements

- macOS 11.0+ (Big Sur or later)
- Apple Silicon Mac (M1/M2/M3)
- Xcode Command Line Tools
- Metal-compatible GPU
- 8GB+ RAM recommended

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/simcity-arm64.git
cd simcity-arm64
```

### 2. Build the Project
```bash
# Using CMake (recommended)
mkdir build && cd build
cmake ..
make -j$(nproc)

# Or using the build script
./scripts/build/build_all.sh
```

### 3. Run the Interactive Demo
```bash
./build/release/integrated_simcity
```

## 🏗️ Project Structure

```
simcity-arm64/
├── src/                # Source code (ARM64 assembly)
│   ├── main.s         # Entry point
│   ├── simulation/    # Core simulation engine
│   ├── graphics/      # Rendering system
│   ├── agents/        # Agent management
│   ├── network/       # Infrastructure networks
│   └── ...           # Other subsystems
├── assets/            # Game assets
├── demos/             # Demo applications
├── docs/              # Documentation
└── tests/             # Test suites
```

## 🎮 Demo Applications

### Interactive City Builder
The main demo showcasing all features:
```bash
./demos/interactive/integrated_simcity
```

**Controls:**
- **Left Click**: Place building
- **Right Click**: Remove building
- **WASD**: Move camera
- **Scroll**: Zoom in/out
- **Space**: Pause/unpause
- **+/-**: Change game speed

### Graphics Demos
Various graphics feature demonstrations:
```bash
./demos/graphics/sprite_demo      # Sprite rendering
./demos/graphics/visual_demo      # Visual effects
./demos/graphics/building_demo    # Building assets
```

## 🛠️ Development

### Building from Source

1. **Install Dependencies**:
   ```bash
   # Install Xcode Command Line Tools
   xcode-select --install
   
   # Install Homebrew (if needed)
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   
   # Install CMake
   brew install cmake
   ```

2. **Configure Build**:
   ```bash
   cmake -B build -DCMAKE_BUILD_TYPE=Release
   ```

3. **Build Project**:
   ```bash
   cmake --build build -j$(nproc)
   ```

### Development Mode
For development with debug symbols:
```bash
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build
```

## 📊 Architecture

The project follows a modular architecture with 10 specialized agents:

1. **Agent 0**: Core Infrastructure & ECS
2. **Agent 1**: Memory Management (TLSF)
3. **Agent 2**: File I/O & Serialization
4. **Agent 3**: Graphics & Rendering (Metal)
5. **Agent 4**: Simulation Engine
6. **Agent 5**: Citizen & Vehicle Agents
7. **Agent 6**: UI & HUD System
8. **Agent 7**: Audio System
9. **Agent 8**: Network Infrastructure
10. **Agent 9**: Debug & Profiling Tools

Each agent is responsible for specific functionality and communicates through well-defined interfaces.

## 🧪 Testing

Run the test suite:
```bash
# All tests
make test

# Specific test category
./tests/unit/run_tests.sh
./tests/performance/benchmark.sh
```

## 📖 Documentation

- [Architecture Overview](docs/architecture/README.md)
- [Development Guidelines](GUIDELINES.md)
- [API Reference](docs/api/README.md)
- [Building Guide](docs/guides/building.md)
- [Contributing](docs/guides/contributing.md)

## 🤝 Contributing

We welcome contributions! Please read our [Contributing Guidelines](docs/guides/contributing.md) and [Code of Conduct](CODE_OF_CONDUCT.md) before submitting PRs.

### Development Process
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📊 Performance

Current performance metrics on Apple M1:
- **Agents**: 1M+ simultaneous
- **Frame Rate**: Stable 60 FPS
- **Memory**: ~2GB for full city
- **Load Time**: <5 seconds

## 🗺️ Roadmap

- [ ] Multiplayer support
- [ ] Mod system
- [ ] Terrain generation
- [ ] Advanced weather system
- [ ] VR/AR support
- [ ] iOS/iPadOS port

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Apple Developer Documentation
- ARM Architecture Reference Manual
- OpenGameArt.org community
- Contributors and testers

## 📞 Contact

- **Project Lead**: [Your Name]
- **Email**: your.email@example.com
- **Discord**: [Join our server](https://discord.gg/simcity-arm64)
- **Twitter**: [@simcity_arm64](https://twitter.com/simcity_arm64)

---

<div align="center">
Built with ❤️ using ARM64 Assembly on Apple Silicon
</div>