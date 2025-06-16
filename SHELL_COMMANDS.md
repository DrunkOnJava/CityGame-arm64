# SimCity ARM64 Shell Commands Quick Reference

## Navigation Commands
- `sc` - Go to project root
- `scb` - Go to build directory
- `scs` - Go to source directory
- `scagent <1-10>` - Switch to specific agent workspace
  - 1: platform, 2: memory, 3: graphics, 4: simulation, 5: agents
  - 6: network, 7: ui, 8: io, 9: audio, 10: tools

## Build Commands
- `scbuild` - Build project (auto-detects cores)
- `scbuild-debug` - Build with debug symbols
- `scbuild-release` - Build optimized release
- `scbuild-profile` - Build for profiling
- `scclean` - Clean build artifacts
- `screbuild` - Clean rebuild from scratch

## Test Commands
- `sctest` - Run all tests
- `sctest-verbose` - Run tests with detailed output
- `sctest-memory` - Run memory subsystem tests
- `sctest-agents` - Run agent system tests
- `sctest-graphics` - Run graphics tests

## Run Commands
- `scrun` - Run the simulator
- `scrun-debug` - Run under debugger (lldb)
- `scrun-profile` - Run with time profiler

## Development Tools
- `sctodo [agent#]` - Show TODO for specific agent (or all)
- `scgrep <pattern>` - Search in all assembly files
- `scasm <file.s>` - Assemble single file
- `scdisasm <file.o>` - Disassemble object file
- `scstats` - Show project statistics
- `scinfo` - Show environment information

## Profiling Commands
- `scprofile-cpu` - CPU profiling with Instruments
- `scprofile-memory` - Memory profiling with Instruments
- `scleaks [target]` - Check for memory leaks

## File Viewing
- `scat <file>` - View assembly file with syntax highlighting (if bat installed)

## Editor Commands
- `scedit` - Open project in $EDITOR
- `scmake` - Edit CMakeLists.txt
- `scplan` - Edit PROJECT_MASTER_PLAN.md

## Tips
1. All build commands use parallel compilation based on CPU cores
2. Profile outputs are timestamped and saved in build/profile/
3. Use `tree -L 2` to view project structure
4. Use `rg` (ripgrep) for fast code searching
5. Use `hyperfine` for benchmarking performance