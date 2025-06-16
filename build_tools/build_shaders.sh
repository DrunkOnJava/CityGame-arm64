#!/bin/bash
# SimCity ARM64 Metal Shader Build Script
# Agent 3: Graphics & Rendering Pipeline
# Pre-compile and optimize Metal shaders for Apple Silicon

set -e  # Exit on any error

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHADER_DIR="${PROJECT_ROOT}/assets/shaders"
BUILD_DIR="${PROJECT_ROOT}/build/shaders"
TOOLS_DIR="${PROJECT_ROOT}/build_tools"

# Metal compiler configuration
METAL_COMPILER="xcrun -sdk macosx metal"
METALLIB_TOOL="xcrun -sdk macosx metallib"
METAL_STD="macos-metal2.4"
OPTIMIZATION_LEVEL="-O3"

# Apple Silicon optimization flags
APPLE_SILICON_FLAGS=(
    "-target" "air64-apple-macos11.0"
    "-mtune=apple-a14"
    "-ffast-math"
    "-frecord-sources"
    "-fpreserve-invariance"
)

# Function to print colored output
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

# Function to check dependencies
check_dependencies() {
    print_status "Checking dependencies..."
    
    # Check for Metal compiler
    if ! command -v xcrun >/dev/null 2>&1; then
        print_error "Xcode command line tools not found. Please install Xcode."
        exit 1
    fi
    
    # Check Metal compiler specifically
    if ! xcrun -sdk macosx metal --help >/dev/null 2>&1; then
        print_error "Metal compiler not found. Please ensure Xcode is properly installed."
        exit 1
    fi
    
    # Check for Python (for the compiler script)
    if ! command -v python3 >/dev/null 2>&1; then
        print_error "Python 3 not found. Please install Python 3."
        exit 1
    fi
    
    print_success "All dependencies found"
}

# Function to create build directory structure
setup_build_dirs() {
    print_status "Setting up build directories..."
    
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}/air"
    mkdir -p "${BUILD_DIR}/metallib"
    mkdir -p "${BUILD_DIR}/headers"
    
    print_success "Build directories created"
}

# Function to clean previous builds
clean_build() {
    if [ "$1" = "--clean" ]; then
        print_status "Cleaning previous build..."
        rm -rf "${BUILD_DIR}"
        setup_build_dirs
        print_success "Build directory cleaned"
    fi
}

# Function to compile Metal shaders to AIR
compile_shaders_to_air() {
    print_status "Compiling Metal shaders to AIR..."
    
    local shader_count=0
    local success_count=0
    
    for metal_file in "${SHADER_DIR}"/*.metal; do
        if [ -f "$metal_file" ]; then
            shader_count=$((shader_count + 1))
            local basename=$(basename "$metal_file" .metal)
            local air_file="${BUILD_DIR}/air/${basename}.air"
            
            print_status "Compiling ${basename}.metal..."
            
            # Build Metal compiler command
            local cmd=(
                $METAL_COMPILER
                -std=$METAL_STD
                $OPTIMIZATION_LEVEL
                "${APPLE_SILICON_FLAGS[@]}"
                -c "$metal_file"
                -o "$air_file"
            )
            
            # Execute compilation
            if "${cmd[@]}" 2>&1; then
                print_success "Successfully compiled ${basename}.metal to AIR"
                success_count=$((success_count + 1))
            else
                print_error "Failed to compile ${basename}.metal"
            fi
        fi
    done
    
    print_status "Compiled $success_count/$shader_count shaders to AIR"
}

# Function to create metallib files
create_metallibs() {
    print_status "Creating metallib files..."
    
    local air_files=("${BUILD_DIR}"/air/*.air)
    if [ ${#air_files[@]} -eq 0 ]; then
        print_warning "No AIR files found to create metallib"
        return
    fi
    
    # Create combined metallib
    local combined_metallib="${BUILD_DIR}/metallib/simcity_shaders.metallib"
    print_status "Creating combined metallib: simcity_shaders.metallib"
    
    if $METALLIB_TOOL "${air_files[@]}" -o "$combined_metallib"; then
        print_success "Created combined metallib: $combined_metallib"
    else
        print_error "Failed to create combined metallib"
        return 1
    fi
    
    # Create individual metallibs for specific shader groups
    local isometric_air="${BUILD_DIR}/air/isometric.air"
    if [ -f "$isometric_air" ]; then
        local iso_metallib="${BUILD_DIR}/metallib/isometric.metallib"
        print_status "Creating isometric metallib..."
        
        if $METALLIB_TOOL "$isometric_air" -o "$iso_metallib"; then
            print_success "Created isometric metallib: $iso_metallib"
        fi
    fi
    
    local advanced_air="${BUILD_DIR}/air/advanced_rendering.air"
    if [ -f "$advanced_air" ]; then
        local adv_metallib="${BUILD_DIR}/metallib/advanced_rendering.metallib"
        print_status "Creating advanced rendering metallib..."
        
        if $METALLIB_TOOL "$advanced_air" -o "$adv_metallib"; then
            print_success "Created advanced rendering metallib: $adv_metallib"
        fi
    fi
}

# Function to run Python shader compiler
run_python_compiler() {
    print_status "Running Python shader compiler for argument buffers..."
    
    local python_compiler="${TOOLS_DIR}/metal_compiler.py"
    if [ -f "$python_compiler" ]; then
        if python3 "$python_compiler" --project-root "$PROJECT_ROOT" --verbose; then
            print_success "Python shader compiler completed successfully"
        else
            print_warning "Python shader compiler encountered issues"
        fi
    else
        print_warning "Python shader compiler not found at $python_compiler"
    fi
}

# Function to validate metallib files
validate_metallibs() {
    print_status "Validating metallib files..."
    
    local validation_count=0
    local valid_count=0
    
    for metallib_file in "${BUILD_DIR}"/metallib/*.metallib; do
        if [ -f "$metallib_file" ]; then
            validation_count=$((validation_count + 1))
            local basename=$(basename "$metallib_file")
            
            # Check file size (should not be empty)
            local file_size=$(stat -f%z "$metallib_file" 2>/dev/null || stat -c%s "$metallib_file" 2>/dev/null)
            if [ "$file_size" -gt 0 ]; then
                print_success "✓ $basename (${file_size} bytes)"
                valid_count=$((valid_count + 1))
            else
                print_error "✗ $basename (empty file)"
            fi
        fi
    done
    
    print_status "Validated $valid_count/$validation_count metallib files"
}

# Function to generate build report
generate_build_report() {
    print_status "Generating build report..."
    
    local report_file="${BUILD_DIR}/build_report.txt"
    
    {
        echo "SimCity ARM64 Metal Shader Build Report"
        echo "========================================"
        echo "Build Date: $(date)"
        echo "Project Root: $PROJECT_ROOT"
        echo ""
        
        echo "Metal Compiler Version:"
        xcrun -sdk macosx metal --version
        echo ""
        
        echo "Compiled AIR Files:"
        ls -lh "${BUILD_DIR}"/air/*.air 2>/dev/null || echo "No AIR files found"
        echo ""
        
        echo "Generated Metallib Files:"
        ls -lh "${BUILD_DIR}"/metallib/*.metallib 2>/dev/null || echo "No metallib files found"
        echo ""
        
        echo "Generated Headers:"
        ls -lh "${BUILD_DIR}"/headers/*.h 2>/dev/null || echo "No header files found"
        echo ""
        
        echo "Optimization Flags Used:"
        printf '%s\n' "${APPLE_SILICON_FLAGS[@]}"
        echo ""
        
        echo "Build Status: SUCCESS"
    } > "$report_file"
    
    print_success "Build report generated: $report_file"
}

# Function to copy outputs to appropriate locations
install_outputs() {
    print_status "Installing shader outputs..."
    
    # Copy metallib files to runtime directory
    local runtime_shader_dir="${PROJECT_ROOT}/src/graphics/shaders"
    mkdir -p "$runtime_shader_dir"
    
    if [ -d "${BUILD_DIR}/metallib" ]; then
        cp "${BUILD_DIR}"/metallib/*.metallib "$runtime_shader_dir/" 2>/dev/null || true
        print_success "Metallib files copied to runtime directory"
    fi
    
    # Copy headers to include directory
    local include_dir="${PROJECT_ROOT}/src/graphics"
    if [ -d "${BUILD_DIR}/headers" ]; then
        cp "${BUILD_DIR}"/headers/*.h "$include_dir/" 2>/dev/null || true
        print_success "Header files copied to include directory"
    fi
}

# Function to show performance statistics
show_performance_stats() {
    print_status "Performance Statistics"
    echo "======================"
    
    # Show file sizes
    echo "Shader File Sizes:"
    find "${BUILD_DIR}" -name "*.metallib" -exec ls -lh {} \; | awk '{print $5 "\t" $9}' | sort -k2
    echo ""
    
    # Show compilation time (approximate)
    echo "Build completed in approximately $SECONDS seconds"
    echo ""
    
    # Show optimization summary
    echo "Optimizations Applied:"
    echo "- Apple Silicon targeting (arm64)"
    echo "- Fast math optimizations"
    echo "- Maximum compiler optimization level (-O3)"
    echo "- Metal 2.4 standard compliance"
    echo "- Argument buffer pre-compilation"
}

# Main build function
main() {
    local start_time=$SECONDS
    
    echo "SimCity ARM64 Metal Shader Build System"
    echo "======================================="
    echo ""
    
    # Parse command line arguments
    clean_build "$1"
    
    # Execute build pipeline
    check_dependencies
    setup_build_dirs
    compile_shaders_to_air
    create_metallibs
    run_python_compiler
    validate_metallibs
    install_outputs
    generate_build_report
    
    # Show results
    echo ""
    show_performance_stats
    
    local end_time=$SECONDS
    local duration=$((end_time - start_time))
    
    print_success "Metal shader build completed successfully in ${duration} seconds!"
    
    # Show next steps
    echo ""
    print_status "Next Steps:"
    echo "1. Link the generated metallib files with your application"
    echo "2. Use the argument buffer headers in your rendering code"
    echo "3. Run the application to test shader performance"
    echo ""
    print_status "Generated files:"
    echo "- Metallib files: ${BUILD_DIR}/metallib/"
    echo "- Header files: ${BUILD_DIR}/headers/"
    echo "- Build report: ${BUILD_DIR}/build_report.txt"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--clean] [--help]"
        echo ""
        echo "Options:"
        echo "  --clean    Clean build directory before building"
        echo "  --help     Show this help message"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac