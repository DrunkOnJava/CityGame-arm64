#!/bin/bash
# SimCity ARM64 Build System Validation
# Agent E5: Platform Team - Build Infrastructure Verification
# Validates that all build system components are properly configured

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Project configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_TOOLS_DIR="${PROJECT_ROOT}/build_tools"

# Validation results
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
VALIDATION_RESULTS=()

print_banner() {
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${CYAN} SimCity ARM64 Build System Validation${NC}"
    echo -e "${CYAN} Agent E5: Infrastructure Verification${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo ""
}

print_check() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to run validation check
run_check() {
    local check_name="$1"
    local check_function="$2"
    
    print_check "Validating: $check_name"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if $check_function; then
        print_pass "$check_name"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        VALIDATION_RESULTS+=("$check_name:PASS")
        return 0
    else
        print_fail "$check_name"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        VALIDATION_RESULTS+=("$check_name:FAIL")
        return 1
    fi
}

# Validation functions
check_system_requirements() {
    # Check ARM64 architecture
    if [[ "$(uname -m)" != "arm64" ]]; then
        return 1
    fi
    
    # Check macOS version
    local version=$(sw_vers -productVersion)
    if [ "$(printf '%s\n' "11.0" "$version" | sort -V | head -n1)" != "11.0" ]; then
        return 1
    fi
    
    # Check memory
    local memory_gb=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
    if [ "$memory_gb" -lt 8 ]; then
        print_warn "Only ${memory_gb}GB RAM available (8GB+ recommended)"
    fi
    
    return 0
}

check_required_tools() {
    local tools=(as clang ar xcrun python3 make zip)
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            return 1
        fi
    done
    
    return 0
}

check_build_scripts() {
    local scripts=(
        "build_master.sh"
        "build_assembly.sh"
        "build_shaders.sh"
        "link_assembly.sh"
        "run_tests.sh"
        "run_benchmarks.sh"
        "integration_tests.sh"
        "deploy.sh"
    )
    
    for script in "${scripts[@]}"; do
        local script_path="${BUILD_TOOLS_DIR}/${script}"
        if [ ! -f "$script_path" ]; then
            return 1
        fi
        
        if [ ! -x "$script_path" ]; then
            return 1
        fi
    done
    
    return 0
}

check_project_structure() {
    local required_dirs=(
        "src"
        "include"
        "assets"
        "tests"
        "build_tools"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "${PROJECT_ROOT}/${dir}" ]; then
            return 1
        fi
    done
    
    return 0
}

check_source_modules() {
    local modules=(
        "platform"
        "memory"
        "graphics"
        "simulation"
        "agents"
        "network"
        "ui"
        "io"
        "audio"
        "tools"
    )
    
    for module in "${modules[@]}"; do
        local module_dir="${PROJECT_ROOT}/src/${module}"
        if [ ! -d "$module_dir" ]; then
            return 1
        fi
        
        # Check for at least one assembly file
        if [ ! -f "${module_dir}"/*.s ] 2>/dev/null; then
            local asm_count=$(find "$module_dir" -name "*.s" | wc -l)
            if [ "$asm_count" -eq 0 ]; then
                print_warn "No assembly files found in $module module"
            fi
        fi
    done
    
    return 0
}

check_metal_shaders() {
    local shader_dir="${PROJECT_ROOT}/assets/shaders"
    
    if [ ! -d "$shader_dir" ]; then
        return 1
    fi
    
    # Check for Metal shader files
    local metal_count=$(find "$shader_dir" -name "*.metal" | wc -l)
    if [ "$metal_count" -eq 0 ]; then
        print_warn "No Metal shader files found"
    fi
    
    return 0
}

check_python_compiler() {
    local python_compiler="${BUILD_TOOLS_DIR}/metal_compiler.py"
    
    if [ ! -f "$python_compiler" ]; then
        return 1
    fi
    
    # Test Python syntax
    if ! python3 -m py_compile "$python_compiler" 2>/dev/null; then
        return 1
    fi
    
    return 0
}

check_build_permissions() {
    # Check write permissions in project directory
    if [ ! -w "$PROJECT_ROOT" ]; then
        return 1
    fi
    
    # Test creating build directory
    local test_build_dir="${PROJECT_ROOT}/build_test_$$"
    if ! mkdir -p "$test_build_dir" 2>/dev/null; then
        return 1
    fi
    
    # Cleanup test directory
    rmdir "$test_build_dir" 2>/dev/null || true
    
    return 0
}

check_xcode_tools() {
    # Check for Xcode command line tools
    if ! xcode-select -p >/dev/null 2>&1; then
        return 1
    fi
    
    # Check Metal compiler
    if ! xcrun -sdk macosx metal --help >/dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

check_framework_access() {
    # Test Metal framework access
    local test_program="
#import <Metal/Metal.h>
int main() { 
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    return device ? 0 : 1;
}"
    
    if echo "$test_program" | clang -x objective-c -framework Metal -o /tmp/metal_test$$ - 2>/dev/null; then
        rm -f "/tmp/metal_test$$"
        return 0
    else
        return 1
    fi
}

# Function to test basic build functionality
test_basic_build() {
    print_check "Testing basic build functionality..."
    
    # Test shader build (dry run)
    if ! "${BUILD_TOOLS_DIR}/build_shaders.sh" --help >/dev/null 2>&1; then
        return 1
    fi
    
    # Test assembly build (dry run)
    if ! "${BUILD_TOOLS_DIR}/build_assembly.sh" --help >/dev/null 2>&1; then
        return 1
    fi
    
    # Test master build (dry run)
    if ! "${BUILD_TOOLS_DIR}/build_master.sh" --help >/dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

# Function to validate configuration files
check_configuration_files() {
    local config_files=(
        "build_tools/shader_config.json"
        "CMakeLists.txt"
        "Makefile"
    )
    
    for config_file in "${config_files[@]}"; do
        local file_path="${PROJECT_ROOT}/${config_file}"
        if [ ! -f "$file_path" ]; then
            print_warn "Configuration file missing: $config_file"
        fi
    done
    
    return 0
}

# Main validation function
main() {
    print_banner
    
    print_check "Starting build system validation..."
    echo ""
    
    # Core system checks
    run_check "System Requirements" check_system_requirements
    run_check "Required Tools" check_required_tools
    run_check "Xcode Tools" check_xcode_tools
    run_check "Framework Access" check_framework_access
    
    # Project structure checks
    run_check "Project Structure" check_project_structure
    run_check "Source Modules" check_source_modules
    run_check "Metal Shaders" check_metal_shaders
    run_check "Configuration Files" check_configuration_files
    
    # Build system checks
    run_check "Build Scripts" check_build_scripts
    run_check "Python Compiler" check_python_compiler
    run_check "Build Permissions" check_build_permissions
    
    # Functionality tests
    run_check "Basic Build Test" test_basic_build
    
    # Summary
    echo ""
    echo "Validation Summary:"
    echo "=================="
    echo "Total Checks: $TOTAL_CHECKS"
    echo "Passed: $PASSED_CHECKS"
    echo "Failed: $FAILED_CHECKS"
    echo ""
    
    if [ "$FAILED_CHECKS" -eq 0 ]; then
        print_pass "Build system validation completed successfully!"
        echo ""
        echo "Ready to build:"
        echo "  ./build_tools/build_master.sh"
        echo ""
        exit 0
    else
        print_fail "Build system validation failed!"
        echo ""
        echo "Failed checks:"
        for result in "${VALIDATION_RESULTS[@]}"; do
            if [[ "$result" == *":FAIL" ]]; then
                local check_name=$(echo "$result" | cut -d: -f1)
                echo "  ❌ $check_name"
            fi
        done
        echo ""
        echo "Please resolve the issues above before building."
        exit 1
    fi
}

# Execute main function
main "$@"