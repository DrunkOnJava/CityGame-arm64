#!/bin/bash
# SimCity ARM64 Assembly-Only Build System
# Agent E5: Platform Team - Build System & Toolchain Integration
# Complete assembly compilation pipeline for all agent modules

set -e  # Exit on any error

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
SRC_DIR="${PROJECT_ROOT}/src"
INCLUDE_DIR="${PROJECT_ROOT}/include"
TEST_DIR="${PROJECT_ROOT}/tests"
TOOLS_DIR="${PROJECT_ROOT}/build_tools"

# Build configuration
ASSEMBLER="as"
LINKER="clang"
ARCHIVER="ar"
STRIP="strip"

# ARM64 assembly compilation flags
ASM_FLAGS=(
    "-arch" "arm64"
    "-W"                    # Enable warnings
    "--statistics"          # Show compilation statistics
    "--fatal-warnings"      # Treat warnings as errors
)

# Debug build flags
ASM_DEBUG_FLAGS=(
    "-g"                    # Debug symbols
    "--debug"               # Additional debug info
)

# Release build flags  
ASM_RELEASE_FLAGS=(
    "--strip-local-absolute"    # Strip local absolute symbols
)

# Linker flags for ARM64
LINK_FLAGS=(
    "-arch" "arm64"
    "-Wl,-no_compact_unwind"    # Disable compact unwind (assembly compatibility)
    "-Wl,-no_eh_labels"         # No exception handling labels
    "-static-libgcc"            # Static link gcc runtime
)

# System libraries
SYSTEM_LIBS=(
    "-lc"                   # Standard C library
    "-lm"                   # Math library
    "-lpthread"             # POSIX threads
    "-framework" "CoreFoundation"   # Core Foundation
    "-framework" "Foundation"       # Foundation
    "-framework" "CoreGraphics"     # Core Graphics
    "-framework" "Metal"            # Metal framework
    "-framework" "MetalKit"         # MetalKit
    "-framework" "Cocoa"            # Cocoa framework
    "-framework" "QuartzCore"       # QuartzCore
)

# Agent module directories
AGENT_MODULES=(
    "platform"      # Agent 1: Platform & system calls
    "memory"        # Agent 2: Memory management
    "graphics"      # Agent 3: Graphics & rendering
    "simulation"    # Agent 4: Simulation engine
    "agents"        # Agent 5: AI agents & behavior
    "network"       # Agent 6: Infrastructure networks
    "ui"            # Agent 7: User interface
    "io"            # Agent 8: I/O operations
    "audio"         # Agent 9: Audio system
    "tools"         # Agent 10: Development tools
)

# Build modes
BUILD_MODE="debug"  # Default to debug
CLEAN_BUILD=false
VERBOSE=false
PARALLEL_BUILD=true
BUILD_TESTS=true
RUN_BENCHMARKS=false

# Performance tracking
BUILD_START_TIME=""
MODULE_BUILD_TIMES=()

# Function to print colored output
print_banner() {
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${CYAN} SimCity ARM64 Assembly Build System${NC}"
    echo -e "${CYAN} Agent E5: Platform Team Build Pipeline${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo ""
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_module() {
    echo -e "${CYAN}[MODULE]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [TARGETS...]"
    echo ""
    echo "Build Modes:"
    echo "  debug      Build with debug symbols (default)"
    echo "  release    Build optimized release version"
    echo "  test       Build test executables"
    echo "  benchmark  Build with performance benchmarking"
    echo ""
    echo "Options:"
    echo "  --clean        Clean build directory before building"
    echo "  --verbose      Enable verbose output"
    echo "  --no-parallel  Disable parallel building"
    echo "  --no-tests     Skip building tests"
    echo "  --benchmark    Enable benchmarking build"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "Targets:"
    echo "  all           Build all modules (default)"
    echo "  agent[1-10]   Build specific agent module"
    echo "  platform      Build platform module"
    echo "  memory        Build memory module"
    echo "  graphics      Build graphics module"
    echo "  simulation    Build simulation module"
    echo "  agents        Build agents module"
    echo "  network       Build network module"
    echo "  ui            Build UI module"
    echo "  io            Build I/O module"
    echo "  audio         Build audio module"
    echo "  tools         Build tools module"
    echo "  tests         Build all tests"
    echo "  clean         Clean all build artifacts"
    echo ""
    echo "Examples:"
    echo "  $0                    # Build all modules in debug mode"
    echo "  $0 release            # Build all modules in release mode"
    echo "  $0 --clean debug      # Clean build all in debug mode"
    echo "  $0 platform memory    # Build only platform and memory modules"
    echo "  $0 --benchmark all    # Build with performance benchmarking"
}

# Function to check build dependencies
check_dependencies() {
    print_status "Checking build dependencies..."
    
    local missing_deps=()
    
    # Check for ARM64 assembler
    if ! command -v as >/dev/null 2>&1; then
        missing_deps+=("GNU Assembler (as)")
    fi
    
    # Check for clang
    if ! command -v clang >/dev/null 2>&1; then
        missing_deps+=("Clang compiler")
    fi
    
    # Check for archiver
    if ! command -v ar >/dev/null 2>&1; then
        missing_deps+=("Archiver (ar)")
    fi
    
    # Check for make for parallel builds
    if ! command -v make >/dev/null 2>&1; then
        missing_deps+=("Make utility")
    fi
    
    # Check platform
    if [[ "$(uname -m)" != "arm64" ]]; then
        print_error "This build system requires ARM64 architecture (Apple Silicon)"
        exit 1
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
    
    print_success "All build dependencies found"
}

# Function to setup build directory structure
setup_build_dirs() {
    print_status "Setting up build directory structure..."
    
    mkdir -p "${BUILD_DIR}"/{obj,lib,bin,test,benchmark,reports}
    
    # Create module-specific directories
    for module in "${AGENT_MODULES[@]}"; do
        mkdir -p "${BUILD_DIR}/obj/${module}"
        mkdir -p "${BUILD_DIR}/lib/${module}"
        mkdir -p "${BUILD_DIR}/test/${module}"
    done
    
    # Create unified binary directory
    mkdir -p "${BUILD_DIR}/unified"
    
    print_success "Build directory structure created"
}

# Function to clean build directory
clean_build() {
    if [ "$CLEAN_BUILD" = true ]; then
        print_status "Cleaning build directory..."
        rm -rf "${BUILD_DIR}"
        setup_build_dirs
        print_success "Build directory cleaned"
    fi
}

# Function to get assembly flags based on build mode
get_asm_flags() {
    local flags=("${ASM_FLAGS[@]}")
    
    case "$BUILD_MODE" in
        debug)
            flags+=("${ASM_DEBUG_FLAGS[@]}")
            ;;
        release)
            flags+=("${ASM_RELEASE_FLAGS[@]}")
            ;;
        test)
            flags+=("${ASM_DEBUG_FLAGS[@]}")
            flags+=("-DTEST_BUILD=1")
            ;;
        benchmark)
            flags+=("${ASM_RELEASE_FLAGS[@]}")
            flags+=("-DBENCHMARK_BUILD=1")
            ;;
    esac
    
    echo "${flags[@]}"
}

# Function to compile single assembly file
compile_assembly_file() {
    local src_file="$1"
    local obj_file="$2"
    local module="$3"
    
    local flags
    read -ra flags <<< "$(get_asm_flags)"
    
    # Add include paths
    local include_paths=(
        "-I" "${INCLUDE_DIR}"
        "-I" "${INCLUDE_DIR}/constants"
        "-I" "${INCLUDE_DIR}/interfaces" 
        "-I" "${INCLUDE_DIR}/macros"
        "-I" "${INCLUDE_DIR}/types"
        "-I" "${SRC_DIR}/${module}"
    )
    
    if [ "$VERBOSE" = true ]; then
        print_status "Compiling: $(basename "$src_file")"
        echo "Command: $ASSEMBLER ${flags[*]} ${include_paths[*]} -o $obj_file $src_file"
    fi
    
    # Compile assembly file
    if $ASSEMBLER "${flags[@]}" "${include_paths[@]}" -o "$obj_file" "$src_file" 2>&1; then
        return 0
    else
        print_error "Failed to compile $src_file"
        return 1
    fi
}

# Function to build module library
build_module_library() {
    local module="$1"
    local module_dir="${SRC_DIR}/${module}"
    local obj_dir="${BUILD_DIR}/obj/${module}"
    local lib_dir="${BUILD_DIR}/lib/${module}"
    
    if [ ! -d "$module_dir" ]; then
        print_warning "Module directory not found: $module_dir"
        return 0
    fi
    
    print_module "Building $module module..."
    local start_time=$SECONDS
    
    # Find all assembly files in module
    local asm_files=()
    while IFS= read -r -d '' file; do
        asm_files+=("$file")
    done < <(find "$module_dir" -name "*.s" -type f -print0)
    
    if [ ${#asm_files[@]} -eq 0 ]; then
        print_warning "No assembly files found in $module module"
        return 0
    fi
    
    print_status "Found ${#asm_files[@]} assembly files in $module"
    
    # Compile each assembly file
    local obj_files=()
    local failed_files=()
    
    for asm_file in "${asm_files[@]}"; do
        local base_name=$(basename "$asm_file" .s)
        local obj_file="${obj_dir}/${base_name}.o"
        
        if compile_assembly_file "$asm_file" "$obj_file" "$module"; then
            obj_files+=("$obj_file")
        else
            failed_files+=("$asm_file")
        fi
    done
    
    # Report compilation results
    if [ ${#failed_files[@]} -gt 0 ]; then
        print_error "Failed to compile ${#failed_files[@]} files in $module:"
        for file in "${failed_files[@]}"; do
            echo "  - $(basename "$file")"
        done
    fi
    
    if [ ${#obj_files[@]} -eq 0 ]; then
        print_error "No object files generated for $module module"
        return 1
    fi
    
    # Create static library
    local lib_file="${lib_dir}/lib${module}.a"
    print_status "Creating library: $(basename "$lib_file")"
    
    if $ARCHIVER rcs "$lib_file" "${obj_files[@]}" 2>&1; then
        print_success "Created library: $lib_file"
    else
        print_error "Failed to create library for $module"
        return 1
    fi
    
    # Calculate build time
    local end_time=$SECONDS
    local duration=$((end_time - start_time))
    MODULE_BUILD_TIMES+=("$module:${duration}s")
    
    print_success "$module module built successfully (${duration}s)"
    return 0
}

# Function to build all modules
build_all_modules() {
    print_status "Building all agent modules..."
    
    local failed_modules=()
    local successful_modules=()
    
    for module in "${AGENT_MODULES[@]}"; do
        if build_module_library "$module"; then
            successful_modules+=("$module")
        else
            failed_modules+=("$module")
        fi
    done
    
    # Report module build results
    echo ""
    print_status "Module Build Summary:"
    echo "======================"
    
    if [ ${#successful_modules[@]} -gt 0 ]; then
        print_success "Successfully built modules:"
        for module in "${successful_modules[@]}"; do
            echo "  ✓ $module"
        done
    fi
    
    if [ ${#failed_modules[@]} -gt 0 ]; then
        print_error "Failed to build modules:"
        for module in "${failed_modules[@]}"; do
            echo "  ✗ $module"
        done
        return 1
    fi
    
    print_success "All modules built successfully!"
    return 0
}

# Function to create unified executable
create_unified_executable() {
    print_status "Creating unified SimCity executable..."
    
    local lib_files=()
    local main_obj="${BUILD_DIR}/obj/main.o"
    local unified_exe="${BUILD_DIR}/bin/simcity_unified"
    
    # Find main assembly file
    local main_asm="${SRC_DIR}/main.s"
    if [ ! -f "$main_asm" ]; then
        print_error "Main assembly file not found: $main_asm"
        return 1
    fi
    
    # Compile main file
    print_status "Compiling main assembly file..."
    if ! compile_assembly_file "$main_asm" "$main_obj" ""; then
        print_error "Failed to compile main assembly file"
        return 1
    fi
    
    # Collect all module libraries
    for module in "${AGENT_MODULES[@]}"; do
        local lib_file="${BUILD_DIR}/lib/${module}/lib${module}.a"
        if [ -f "$lib_file" ]; then
            lib_files+=("$lib_file")
        fi
    done
    
    if [ ${#lib_files[@]} -eq 0 ]; then
        print_error "No module libraries found for linking"
        return 1
    fi
    
    print_status "Linking unified executable with ${#lib_files[@]} modules..."
    
    # Link everything together
    local link_cmd=(
        "$LINKER"
        "${LINK_FLAGS[@]}"
        "$main_obj"
        "${lib_files[@]}"
        "${SYSTEM_LIBS[@]}"
        "-o" "$unified_exe"
    )
    
    if [ "$VERBOSE" = true ]; then
        echo "Link command: ${link_cmd[*]}"
    fi
    
    if "${link_cmd[@]}" 2>&1; then
        print_success "Created unified executable: $unified_exe"
        
        # Show executable info
        local exe_size=$(stat -f%z "$unified_exe" 2>/dev/null || stat -c%s "$unified_exe" 2>/dev/null)
        print_status "Executable size: $((exe_size / 1024)) KB"
        
        return 0
    else
        print_error "Failed to link unified executable"
        return 1
    fi
}

# Function to build tests
build_tests() {
    if [ "$BUILD_TESTS" != true ]; then
        return 0
    fi
    
    print_status "Building test suite..."
    
    # Find test files
    local test_files=()
    while IFS= read -r -d '' file; do
        test_files+=("$file")
    done < <(find "$TEST_DIR" -name "*.s" -type f -print0)
    
    if [ ${#test_files[@]} -eq 0 ]; then
        print_warning "No test files found"
        return 0
    fi
    
    print_status "Found ${#test_files[@]} test files"
    
    # Build each test
    local test_executables=()
    for test_file in "${test_files[@]}"; do
        local test_name=$(basename "$test_file" .s)
        local test_obj="${BUILD_DIR}/test/${test_name}.o"
        local test_exe="${BUILD_DIR}/test/${test_name}"
        
        # Compile test
        if compile_assembly_file "$test_file" "$test_obj" "test"; then
            # Link test with required modules
            local test_libs=()
            
            # Determine which modules this test needs (basic heuristic)
            if grep -q "memory" "$test_file"; then
                test_libs+=("${BUILD_DIR}/lib/memory/libmemory.a")
            fi
            if grep -q "graphics" "$test_file"; then
                test_libs+=("${BUILD_DIR}/lib/graphics/libgraphics.a")
            fi
            
            # Link test executable
            if $LINKER "${LINK_FLAGS[@]}" "$test_obj" "${test_libs[@]}" "${SYSTEM_LIBS[@]}" -o "$test_exe" 2>&1; then
                test_executables+=("$test_exe")
                print_success "Built test: $test_name"
            else
                print_error "Failed to link test: $test_name"
            fi
        fi
    done
    
    print_success "Built ${#test_executables[@]} test executables"
    return 0
}

# Function to generate build report
generate_build_report() {
    print_status "Generating build report..."
    
    local report_file="${BUILD_DIR}/reports/build_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "SimCity ARM64 Assembly Build Report"
        echo "=================================="
        echo "Build Date: $(date)"
        echo "Build Mode: $BUILD_MODE"
        echo "Project Root: $PROJECT_ROOT"
        echo "Host Architecture: $(uname -m)"
        echo "Host OS: $(uname -s) $(uname -r)"
        echo ""
        
        echo "Build Configuration:"
        echo "-------------------"
        echo "Assembler: $ASSEMBLER"
        echo "Linker: $LINKER"
        echo "Assembly Flags: $(get_asm_flags)"
        echo "Link Flags: ${LINK_FLAGS[*]}"
        echo "Clean Build: $CLEAN_BUILD"
        echo "Verbose Mode: $VERBOSE"
        echo "Parallel Build: $PARALLEL_BUILD"
        echo "Build Tests: $BUILD_TESTS"
        echo ""
        
        echo "Agent Modules Built:"
        echo "-------------------"
        for module in "${AGENT_MODULES[@]}"; do
            local lib_file="${BUILD_DIR}/lib/${module}/lib${module}.a"
            if [ -f "$lib_file" ]; then
                local lib_size=$(stat -f%z "$lib_file" 2>/dev/null || stat -c%s "$lib_file" 2>/dev/null)
                echo "✓ $module ($(basename "$lib_file"), $((lib_size / 1024)) KB)"
            else
                echo "✗ $module (not built)"
            fi
        done
        echo ""
        
        echo "Build Timings:"
        echo "-------------"
        for timing in "${MODULE_BUILD_TIMES[@]}"; do
            echo "$timing"
        done
        echo ""
        
        echo "Generated Files:"
        echo "---------------"
        echo "Object files: $(find "${BUILD_DIR}/obj" -name "*.o" | wc -l)"
        echo "Library files: $(find "${BUILD_DIR}/lib" -name "*.a" | wc -l)"
        echo "Test executables: $(find "${BUILD_DIR}/test" -type f -executable | wc -l)"
        
        local unified_exe="${BUILD_DIR}/bin/simcity_unified"
        if [ -f "$unified_exe" ]; then
            local exe_size=$(stat -f%z "$unified_exe" 2>/dev/null || stat -c%s "$unified_exe" 2>/dev/null)
            echo "Unified executable: $(basename "$unified_exe") ($((exe_size / 1024)) KB)"
        fi
        echo ""
        
        local total_time=$((SECONDS - BUILD_START_TIME))
        echo "Total Build Time: ${total_time}s"
        echo ""
        echo "Build Status: SUCCESS"
    } > "$report_file"
    
    print_success "Build report generated: $report_file"
}

# Function to show build statistics
show_build_statistics() {
    echo ""
    print_status "Build Statistics"
    echo "================"
    
    # Show file counts
    local obj_count=$(find "${BUILD_DIR}/obj" -name "*.o" 2>/dev/null | wc -l)
    local lib_count=$(find "${BUILD_DIR}/lib" -name "*.a" 2>/dev/null | wc -l)
    
    echo "Object files compiled: $obj_count"
    echo "Libraries created: $lib_count"
    
    # Show total size
    local total_size=0
    while IFS= read -r -d '' file; do
        if [[ "$OSTYPE" == "darwin"* ]]; then
            size=$(stat -f%z "$file" 2>/dev/null || echo 0)
        else
            size=$(stat -c%s "$file" 2>/dev/null || echo 0)
        fi
        total_size=$((total_size + size))
    done < <(find "${BUILD_DIR}" -name "*.a" -o -name "*.o" -o -name "simcity_unified" -print0 2>/dev/null)
    
    echo "Total build artifacts size: $((total_size / 1024)) KB"
    
    # Show build time breakdown
    if [ ${#MODULE_BUILD_TIMES[@]} -gt 0 ]; then
        echo ""
        echo "Module build times:"
        for timing in "${MODULE_BUILD_TIMES[@]}"; do
            echo "  $timing"
        done
    fi
    
    local total_time=$((SECONDS - BUILD_START_TIME))
    echo ""
    echo "Total build time: ${total_time}s"
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                CLEAN_BUILD=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --no-parallel)
                PARALLEL_BUILD=false
                shift
                ;;
            --no-tests)
                BUILD_TESTS=false
                shift
                ;;
            --benchmark)
                RUN_BENCHMARKS=true
                BUILD_MODE="benchmark"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            debug|release|test|benchmark)
                BUILD_MODE="$1"
                shift
                ;;
            clean)
                CLEAN_BUILD=true
                shift
                ;;
            all|"")
                # Build all modules (default)
                shift
                ;;
            platform|memory|graphics|simulation|agents|network|ui|io|audio|tools)
                # Specific module targets will be handled later
                shift
                ;;
            tests)
                BUILD_TESTS=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main build function
main() {
    BUILD_START_TIME=$SECONDS
    
    print_banner
    
    # Parse command line arguments
    parse_arguments "$@"
    
    print_status "Build mode: $BUILD_MODE"
    print_status "Clean build: $CLEAN_BUILD"
    print_status "Verbose output: $VERBOSE"
    print_status "Build tests: $BUILD_TESTS"
    echo ""
    
    # Execute build pipeline
    check_dependencies
    setup_build_dirs
    clean_build
    
    # Build all modules
    if ! build_all_modules; then
        print_error "Module build failed"
        exit 1
    fi
    
    # Create unified executable
    if ! create_unified_executable; then
        print_error "Failed to create unified executable"
        exit 1
    fi
    
    # Build tests
    build_tests
    
    # Generate reports
    generate_build_report
    show_build_statistics
    
    echo ""
    print_success "SimCity ARM64 assembly build completed successfully!"
    
    # Show next steps
    echo ""
    print_status "Build Outputs:"
    echo "- Unified executable: ${BUILD_DIR}/bin/simcity_unified"
    echo "- Module libraries: ${BUILD_DIR}/lib/"
    echo "- Test executables: ${BUILD_DIR}/test/"
    echo "- Build reports: ${BUILD_DIR}/reports/"
    echo ""
    print_status "Next steps:"
    echo "1. Run tests: ./build_tools/run_tests.sh"
    echo "2. Run benchmarks: ./build_tools/run_benchmarks.sh" 
    echo "3. Deploy: ./build_tools/deploy.sh"
}

# Execute main function with all arguments
main "$@"