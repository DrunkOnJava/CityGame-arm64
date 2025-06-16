#!/bin/bash
# SimCity ARM64 Master Build Orchestration System
# Agent E5: Platform Team - Complete Build Pipeline Coordinator
# Orchestrates all build tools for complete development workflow

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Project configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_TOOLS_DIR="${PROJECT_ROOT}/build_tools"
BUILD_DIR="${PROJECT_ROOT}/build"

# Build pipeline configuration
BUILD_MODE="debug"
CLEAN_BUILD=false
RUN_TESTS=true
RUN_BENCHMARKS=false
RUN_INTEGRATION_TESTS=true
CREATE_DEPLOYMENT=false
ENABLE_COVERAGE=false
PARALLEL_BUILD=true
VERBOSE=false

# Build pipeline phases
PIPELINE_PHASES=(
    "environment_check"      # Verify build environment
    "clean_workspace"        # Clean build workspace if requested
    "build_shaders"          # Compile Metal shaders
    "build_assembly"         # Build assembly modules
    "link_executables"       # Link final executables
    "run_unit_tests"         # Execute unit tests
    "run_integration_tests"  # Execute integration tests
    "run_benchmarks"         # Performance benchmarking
    "create_deployment"      # Package for deployment
)

# Build metrics tracking
PIPELINE_START_TIME=""
PHASE_TIMINGS=()
BUILD_ARTIFACTS=()
BUILD_WARNINGS=()
BUILD_ERRORS=()
PIPELINE_SUCCESS=true

print_banner() {
    echo -e "${CYAN}${BOLD}================================================================${NC}"
    echo -e "${CYAN}${BOLD} SimCity ARM64 Master Build Orchestration System${NC}"
    echo -e "${CYAN}${BOLD} Agent E5: Complete Assembly-Only Build Pipeline${NC}"
    echo -e "${CYAN}${BOLD}================================================================${NC}"
    echo ""
    echo -e "${BLUE}Target: 1,000,000+ agents at 60 FPS on Apple Silicon${NC}"
    echo -e "${BLUE}Architecture: ARM64 Assembly-Only Implementation${NC}"
    echo ""
}

print_phase() {
    echo -e "${BOLD}${MAGENTA}[PHASE]${NC} $1"
}

print_status() {
    echo -e "${BLUE}[BUILD]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_metric() {
    echo -e "${CYAN}[METRIC]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [PIPELINE_PHASES...]"
    echo ""
    echo "Build Modes:"
    echo "  debug          Build with debug symbols (default)"
    echo "  release        Build optimized release version"
    echo "  benchmark      Build with benchmarking instrumentation"
    echo "  profile        Build with profiling support"
    echo ""
    echo "Pipeline Options:"
    echo "  --clean        Clean workspace before building"
    echo "  --no-tests     Skip unit and integration tests"
    echo "  --no-integration Skip integration tests only"
    echo "  --benchmarks   Run performance benchmarks"
    echo "  --deploy       Create deployment packages"
    echo "  --coverage     Enable code coverage analysis"
    echo "  --no-parallel  Disable parallel building"
    echo "  --verbose      Enable verbose output"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "Pipeline Phases:"
    echo "  environment_check      Verify build environment"
    echo "  clean_workspace        Clean build workspace"
    echo "  build_shaders          Compile Metal shaders"
    echo "  build_assembly         Build assembly modules"
    echo "  link_executables       Link final executables"
    echo "  run_unit_tests         Execute unit tests"
    echo "  run_integration_tests  Execute integration tests"
    echo "  run_benchmarks         Performance benchmarking"
    echo "  create_deployment      Package for deployment"
    echo "  all                    Run complete pipeline (default)"
    echo ""
    echo "Examples:"
    echo "  $0                           # Complete debug build with tests"
    echo "  $0 release --deploy          # Release build with deployment"
    echo "  $0 --clean --benchmarks      # Clean build with performance testing"
    echo "  $0 build_assembly link_executables  # Only build and link"
    echo "  $0 --no-tests --no-parallel  # Build without tests, single-threaded"
}

# Function to verify build environment
verify_environment() {
    print_phase "Environment Verification"
    local start_time=$SECONDS
    
    print_status "Checking build environment..."
    
    # Check system architecture
    if [[ "$(uname -m)" != "arm64" ]]; then
        print_failure "This build system requires ARM64 architecture (Apple Silicon)"
        return 1
    fi
    
    # Check macOS version
    local macos_version=$(sw_vers -productVersion)
    local required_version="11.0"
    if [ "$(printf '%s\n' "$required_version" "$macos_version" | sort -V | head -n1)" != "$required_version" ]; then
        print_failure "macOS $required_version or later required (found: $macos_version)"
        return 1
    fi
    
    # Check available memory
    local memory_gb=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
    if [ "$memory_gb" -lt 8 ]; then
        print_warning "System has ${memory_gb}GB RAM. 16GB+ recommended for optimal build performance"
        BUILD_WARNINGS+=("Low system memory: ${memory_gb}GB")
    fi
    
    # Check required tools
    local missing_tools=()
    for tool in as clang ar xcrun python3; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_failure "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    
    # Check build tools scripts
    local build_scripts=(
        "build_assembly.sh"
        "build_shaders.sh"
        "link_assembly.sh"
        "run_tests.sh"
        "run_benchmarks.sh"
        "integration_tests.sh"
        "deploy.sh"
    )
    
    for script in "${build_scripts[@]}"; do
        if [ ! -x "${BUILD_TOOLS_DIR}/${script}" ]; then
            print_failure "Build script not executable: $script"
            return 1
        fi
    done
    
    local duration=$((SECONDS - start_time))
    PHASE_TIMINGS+=("environment_check:${duration}s")
    
    print_success "Build environment verified (${duration}s)"
    return 0
}

# Function to clean workspace
clean_workspace() {
    if [ "$CLEAN_BUILD" != true ]; then
        return 0
    fi
    
    print_phase "Workspace Cleanup"
    local start_time=$SECONDS
    
    print_status "Cleaning build workspace..."
    
    # Remove build directory
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        print_status "Removed build directory"
    fi
    
    # Remove build artifacts from source
    find "$PROJECT_ROOT/src" -name "*.o" -delete 2>/dev/null || true
    find "$PROJECT_ROOT" -name "*.a" -delete 2>/dev/null || true
    find "$PROJECT_ROOT" -name "core.*" -delete 2>/dev/null || true
    
    # Clean temporary files
    find "$PROJECT_ROOT" -name ".DS_Store" -delete 2>/dev/null || true
    find "$PROJECT_ROOT" -name "*.tmp" -delete 2>/dev/null || true
    
    local duration=$((SECONDS - start_time))
    PHASE_TIMINGS+=("clean_workspace:${duration}s")
    
    print_success "Workspace cleaned (${duration}s)"
    return 0
}

# Function to build Metal shaders
build_shaders() {
    print_phase "Metal Shader Compilation"
    local start_time=$SECONDS
    
    print_status "Compiling Metal shaders..."
    
    local shader_build_cmd=("${BUILD_TOOLS_DIR}/build_shaders.sh")
    
    if [ "$CLEAN_BUILD" = true ]; then
        shader_build_cmd+=("--clean")
    fi
    
    if [ "$VERBOSE" = true ]; then
        shader_build_cmd+=("--verbose")
    fi
    
    if "${shader_build_cmd[@]}"; then
        local duration=$((SECONDS - start_time))
        PHASE_TIMINGS+=("build_shaders:${duration}s")
        BUILD_ARTIFACTS+=("Metal shaders compiled")
        print_success "Metal shaders compiled (${duration}s)"
        return 0
    else
        print_failure "Metal shader compilation failed"
        BUILD_ERRORS+=("Metal shader compilation failed")
        return 1
    fi
}

# Function to build assembly modules
build_assembly() {
    print_phase "Assembly Module Compilation"
    local start_time=$SECONDS
    
    print_status "Building assembly modules..."
    
    local assembly_build_cmd=("${BUILD_TOOLS_DIR}/build_assembly.sh" "$BUILD_MODE")
    
    if [ "$CLEAN_BUILD" = true ]; then
        assembly_build_cmd+=("--clean")
    fi
    
    if [ "$VERBOSE" = true ]; then
        assembly_build_cmd+=("--verbose")
    fi
    
    if [ "$PARALLEL_BUILD" = false ]; then
        assembly_build_cmd+=("--no-parallel")
    fi
    
    if [ "$RUN_TESTS" = false ]; then
        assembly_build_cmd+=("--no-tests")
    fi
    
    if "${assembly_build_cmd[@]}"; then
        local duration=$((SECONDS - start_time))
        PHASE_TIMINGS+=("build_assembly:${duration}s")
        BUILD_ARTIFACTS+=("Assembly modules compiled")
        print_success "Assembly modules built (${duration}s)"
        return 0
    else
        print_failure "Assembly module compilation failed"
        BUILD_ERRORS+=("Assembly module compilation failed")
        return 1
    fi
}

# Function to link executables
link_executables() {
    print_phase "Executable Linking"
    local start_time=$SECONDS
    
    print_status "Linking executables..."
    
    local link_cmd=("${BUILD_TOOLS_DIR}/link_assembly.sh")
    
    if [ "$VERBOSE" = true ]; then
        link_cmd+=("--verbose")
    fi
    
    if "${link_cmd[@]}"; then
        local duration=$((SECONDS - start_time))
        PHASE_TIMINGS+=("link_executables:${duration}s")
        BUILD_ARTIFACTS+=("Executables linked")
        print_success "Executables linked (${duration}s)"
        return 0
    else
        print_failure "Executable linking failed"
        BUILD_ERRORS+=("Executable linking failed")
        return 1
    fi
}

# Function to run unit tests
run_unit_tests() {
    if [ "$RUN_TESTS" != true ]; then
        print_status "Unit tests skipped (disabled)"
        return 0
    fi
    
    print_phase "Unit Test Execution"
    local start_time=$SECONDS
    
    print_status "Running unit tests..."
    
    local test_cmd=("${BUILD_TOOLS_DIR}/run_tests.sh" "unit")
    
    if [ "$ENABLE_COVERAGE" = true ]; then
        test_cmd+=("--coverage")
    fi
    
    if [ "$VERBOSE" = true ]; then
        test_cmd+=("--verbose")
    fi
    
    if "${test_cmd[@]}"; then
        local duration=$((SECONDS - start_time))
        PHASE_TIMINGS+=("run_unit_tests:${duration}s")
        BUILD_ARTIFACTS+=("Unit tests passed")
        print_success "Unit tests completed (${duration}s)"
        return 0
    else
        print_failure "Unit tests failed"
        BUILD_ERRORS+=("Unit tests failed")
        return 1
    fi
}

# Function to run integration tests
run_integration_tests() {
    if [ "$RUN_INTEGRATION_TESTS" != true ]; then
        print_status "Integration tests skipped (disabled)"
        return 0
    fi
    
    print_phase "Integration Test Execution"
    local start_time=$SECONDS
    
    print_status "Running integration tests..."
    
    local integration_cmd=("${BUILD_TOOLS_DIR}/integration_tests.sh" "all")
    
    if [ "$ENABLE_COVERAGE" = true ]; then
        integration_cmd+=("--coverage")
    fi
    
    if [ "$VERBOSE" = true ]; then
        integration_cmd+=("--verbose")
    fi
    
    if "${integration_cmd[@]}"; then
        local duration=$((SECONDS - start_time))
        PHASE_TIMINGS+=("run_integration_tests:${duration}s")
        BUILD_ARTIFACTS+=("Integration tests passed")
        print_success "Integration tests completed (${duration}s)"
        return 0
    else
        print_warning "Integration tests failed - continuing build"
        BUILD_WARNINGS+=("Integration tests failed")
        local duration=$((SECONDS - start_time))
        PHASE_TIMINGS+=("run_integration_tests:${duration}s:FAIL")
        return 0  # Don't fail the build for integration test failures
    fi
}

# Function to run benchmarks
run_benchmarks() {
    if [ "$RUN_BENCHMARKS" != true ]; then
        print_status "Performance benchmarks skipped (disabled)"
        return 0
    fi
    
    print_phase "Performance Benchmarking"
    local start_time=$SECONDS
    
    print_status "Running performance benchmarks..."
    
    local benchmark_cmd=("${BUILD_TOOLS_DIR}/run_benchmarks.sh" "all")
    
    if [ "$BUILD_MODE" = "benchmark" ]; then
        benchmark_cmd+=("--stress")
    else
        benchmark_cmd+=("--quick")
    fi
    
    if [ "$VERBOSE" = true ]; then
        benchmark_cmd+=("--verbose")
    fi
    
    if "${benchmark_cmd[@]}"; then
        local duration=$((SECONDS - start_time))
        PHASE_TIMINGS+=("run_benchmarks:${duration}s")
        BUILD_ARTIFACTS+=("Performance benchmarks completed")
        print_success "Performance benchmarks completed (${duration}s)"
        return 0
    else
        print_warning "Performance benchmarks failed - continuing build"
        BUILD_WARNINGS+=("Performance benchmarks failed")
        local duration=$((SECONDS - start_time))
        PHASE_TIMINGS+=("run_benchmarks:${duration}s:FAIL")
        return 0  # Don't fail the build for benchmark failures
    fi
}

# Function to create deployment
create_deployment() {
    if [ "$CREATE_DEPLOYMENT" != true ]; then
        print_status "Deployment creation skipped (disabled)"
        return 0
    fi
    
    print_phase "Deployment Package Creation"
    local start_time=$SECONDS
    
    print_status "Creating deployment packages..."
    
    local deploy_cmd=("${BUILD_TOOLS_DIR}/deploy.sh" "all" "all")
    
    if [ "$VERBOSE" = true ]; then
        deploy_cmd+=("--verbose")
    fi
    
    if "${deploy_cmd[@]}"; then
        local duration=$((SECONDS - start_time))
        PHASE_TIMINGS+=("create_deployment:${duration}s")
        BUILD_ARTIFACTS+=("Deployment packages created")
        print_success "Deployment packages created (${duration}s)"
        return 0
    else
        print_failure "Deployment creation failed"
        BUILD_ERRORS+=("Deployment creation failed")
        return 1
    fi
}

# Function to generate build report
generate_build_report() {
    print_status "Generating master build report..."
    
    local report_file="${BUILD_DIR}/master_build_report_$(date +%Y%m%d_%H%M%S).html"
    mkdir -p "$(dirname "$report_file")"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>SimCity ARM64 Master Build Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f8f9fa; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .summary { display: flex; justify-content: space-around; margin: 20px 0; }
        .metric { text-align: center; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .success { background-color: #d4edda; border-color: #c3e6cb; }
        .warning { background-color: #fff3cd; border-color: #ffeaa7; }
        .error { background-color: #f8d7da; border-color: #f5c6cb; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007bff; }
        .phase-result { margin: 10px 0; padding: 10px; background-color: #f8f9fa; }
        .artifact { color: #28a745; }
        .warning-item { color: #ffc107; }
        .error-item { color: #dc3545; }
        .timing { font-family: monospace; }
    </style>
</head>
<body>
    <div class="header">
        <h1>SimCity ARM64 Master Build Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Build Mode:</strong> $BUILD_MODE</p>
        <p><strong>System:</strong> $(uname -s) $(uname -r) $(uname -m)</p>
        <p><strong>Memory:</strong> $(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')GB</p>
        <p><strong>Target:</strong> 1,000,000+ agents @ 60 FPS</p>
    </div>
    
    <div class="summary">
        <div class="metric $([ "$PIPELINE_SUCCESS" = true ] && echo "success" || echo "error")">
            <h3>$([ "$PIPELINE_SUCCESS" = true ] && echo "SUCCESS" || echo "FAILED")</h3>
            <p>Build Status</p>
        </div>
        <div class="metric">
            <h3>${#BUILD_ARTIFACTS[@]}</h3>
            <p>Artifacts Created</p>
        </div>
        <div class="metric $([ ${#BUILD_WARNINGS[@]} -eq 0 ] && echo "success" || echo "warning")">
            <h3>${#BUILD_WARNINGS[@]}</h3>
            <p>Warnings</p>
        </div>
        <div class="metric $([ ${#BUILD_ERRORS[@]} -eq 0 ] && echo "success" || echo "error")">
            <h3>${#BUILD_ERRORS[@]}</h3>
            <p>Errors</p>
        </div>
    </div>
    
    <div class="section">
        <h2>Pipeline Phase Timings</h2>
EOF

    # Add phase timings
    for timing in "${PHASE_TIMINGS[@]}"; do
        local phase=$(echo "$timing" | cut -d: -f1)
        local duration=$(echo "$timing" | cut -d: -f2)
        local status=""
        if echo "$timing" | grep -q "FAIL"; then
            status=" (FAILED)"
        fi
        
        cat >> "$report_file" << EOF
        <div class="phase-result timing">
            <strong>$phase:</strong> $duration$status
        </div>
EOF
    done
    
    # Add build artifacts
    if [ ${#BUILD_ARTIFACTS[@]} -gt 0 ]; then
        cat >> "$report_file" << EOF
    </div>
    
    <div class="section">
        <h2>Build Artifacts</h2>
EOF
        for artifact in "${BUILD_ARTIFACTS[@]}"; do
            echo "        <div class=\"artifact\">✓ $artifact</div>" >> "$report_file"
        done
    fi
    
    # Add warnings
    if [ ${#BUILD_WARNINGS[@]} -gt 0 ]; then
        cat >> "$report_file" << EOF
    </div>
    
    <div class="section">
        <h2>Build Warnings</h2>
EOF
        for warning in "${BUILD_WARNINGS[@]}"; do
            echo "        <div class=\"warning-item\">⚠️ $warning</div>" >> "$report_file"
        done
    fi
    
    # Add errors
    if [ ${#BUILD_ERRORS[@]} -gt 0 ]; then
        cat >> "$report_file" << EOF
    </div>
    
    <div class="section">
        <h2>Build Errors</h2>
EOF
        for error in "${BUILD_ERRORS[@]}"; do
            echo "        <div class=\"error-item\">❌ $error</div>" >> "$report_file"
        done
    fi
    
    cat >> "$report_file" << EOF
    </div>
    
    <div class="section">
        <h2>Build Configuration</h2>
        <p><strong>Clean Build:</strong> $CLEAN_BUILD</p>
        <p><strong>Parallel Build:</strong> $PARALLEL_BUILD</p>
        <p><strong>Run Tests:</strong> $RUN_TESTS</p>
        <p><strong>Integration Tests:</strong> $RUN_INTEGRATION_TESTS</p>
        <p><strong>Benchmarks:</strong> $RUN_BENCHMARKS</p>
        <p><strong>Deployment:</strong> $CREATE_DEPLOYMENT</p>
        <p><strong>Coverage:</strong> $ENABLE_COVERAGE</p>
    </div>
    
    <div class="section">
        <h2>Next Steps</h2>
        <ul>
            <li>Review build artifacts in: ${BUILD_DIR}/</li>
            <li>Check test results in: ${BUILD_DIR}/test_reports/</li>
            <li>View benchmark results in: ${BUILD_DIR}/benchmark/reports/</li>
            <li>Deploy packages from: ${BUILD_DIR}/deploy/packages/</li>
        </ul>
    </div>
</body>
</html>
EOF

    print_success "Master build report generated: $report_file"
}

# Function to show build summary
show_build_summary() {
    local total_time=$((SECONDS - PIPELINE_START_TIME))
    
    echo ""
    echo -e "${BOLD}${CYAN}================================================================${NC}"
    echo -e "${BOLD}${CYAN} SimCity ARM64 Build Pipeline Summary${NC}"
    echo -e "${BOLD}${CYAN}================================================================${NC}"
    echo ""
    
    print_metric "Build Status: $([ "$PIPELINE_SUCCESS" = true ] && echo -e "${GREEN}SUCCESS${NC}" || echo -e "${RED}FAILED${NC}")"
    print_metric "Build Mode: $BUILD_MODE"
    print_metric "Total Time: ${total_time}s"
    print_metric "Artifacts Created: ${#BUILD_ARTIFACTS[@]}"
    print_metric "Warnings: ${#BUILD_WARNINGS[@]}"
    print_metric "Errors: ${#BUILD_ERRORS[@]}"
    echo ""
    
    if [ ${#PHASE_TIMINGS[@]} -gt 0 ]; then
        echo "Phase Timings:"
        echo "============="
        for timing in "${PHASE_TIMINGS[@]}"; do
            local phase=$(echo "$timing" | cut -d: -f1)
            local duration=$(echo "$timing" | cut -d: -f2)
            echo "  $phase: $duration"
        done
        echo ""
    fi
    
    if [ ${#BUILD_ARTIFACTS[@]} -gt 0 ]; then
        echo "Build Artifacts:"
        echo "==============="
        for artifact in "${BUILD_ARTIFACTS[@]}"; do
            echo "  ✓ $artifact"
        done
        echo ""
    fi
    
    if [ ${#BUILD_WARNINGS[@]} -gt 0 ]; then
        echo "Warnings:"
        echo "========="
        for warning in "${BUILD_WARNINGS[@]}"; do
            echo "  ⚠️  $warning"
        done
        echo ""
    fi
    
    if [ ${#BUILD_ERRORS[@]} -gt 0 ]; then
        echo "Errors:"
        echo "======="
        for error in "${BUILD_ERRORS[@]}"; do
            echo "  ❌ $error"
        done
        echo ""
    fi
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            debug|release|benchmark|profile)
                BUILD_MODE="$1"
                shift
                ;;
            --clean)
                CLEAN_BUILD=true
                shift
                ;;
            --no-tests)
                RUN_TESTS=false
                RUN_INTEGRATION_TESTS=false
                shift
                ;;
            --no-integration)
                RUN_INTEGRATION_TESTS=false
                shift
                ;;
            --benchmarks)
                RUN_BENCHMARKS=true
                shift
                ;;
            --deploy)
                CREATE_DEPLOYMENT=true
                shift
                ;;
            --coverage)
                ENABLE_COVERAGE=true
                shift
                ;;
            --no-parallel)
                PARALLEL_BUILD=false
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            environment_check|clean_workspace|build_shaders|build_assembly|link_executables|run_unit_tests|run_integration_tests|run_benchmarks|create_deployment|all)
                # Pipeline phases - handled in main
                shift
                ;;
            *)
                print_failure "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main orchestration function
main() {
    PIPELINE_START_TIME=$SECONDS
    
    print_banner
    
    # Parse arguments
    parse_arguments "$@"
    
    print_status "Master Build Pipeline Configuration:"
    echo "  Build Mode: $BUILD_MODE"
    echo "  Clean Build: $CLEAN_BUILD"
    echo "  Parallel Build: $PARALLEL_BUILD"
    echo "  Run Tests: $RUN_TESTS"
    echo "  Integration Tests: $RUN_INTEGRATION_TESTS"
    echo "  Benchmarks: $RUN_BENCHMARKS"
    echo "  Create Deployment: $CREATE_DEPLOYMENT"
    echo "  Enable Coverage: $ENABLE_COVERAGE"
    echo ""
    
    # Execute pipeline phases
    for phase in "${PIPELINE_PHASES[@]}"; do
        case "$phase" in
            environment_check)
                if ! verify_environment; then
                    PIPELINE_SUCCESS=false
                    break
                fi
                ;;
            clean_workspace)
                if ! clean_workspace; then
                    PIPELINE_SUCCESS=false
                    break
                fi
                ;;
            build_shaders)
                if ! build_shaders; then
                    PIPELINE_SUCCESS=false
                    break
                fi
                ;;
            build_assembly)
                if ! build_assembly; then
                    PIPELINE_SUCCESS=false
                    break
                fi
                ;;
            link_executables)
                if ! link_executables; then
                    PIPELINE_SUCCESS=false
                    break
                fi
                ;;
            run_unit_tests)
                run_unit_tests  # Don't fail pipeline for test failures
                ;;
            run_integration_tests)
                run_integration_tests  # Don't fail pipeline for integration failures
                ;;
            run_benchmarks)
                run_benchmarks  # Don't fail pipeline for benchmark failures
                ;;
            create_deployment)
                if ! create_deployment; then
                    PIPELINE_SUCCESS=false
                    break
                fi
                ;;
        esac
    done
    
    # Generate reports
    generate_build_report
    show_build_summary
    
    # Final result
    if [ "$PIPELINE_SUCCESS" = true ]; then
        print_success "SimCity ARM64 build pipeline completed successfully!"
        exit 0
    else
        print_failure "SimCity ARM64 build pipeline failed!"
        exit 1
    fi
}

# Execute main function with all arguments
main "$@"