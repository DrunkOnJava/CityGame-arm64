#!/bin/bash
#
# SimCity ARM64 - HMR Continuous Integration Pipeline
# Agent 0: HMR Orchestrator - Week 2, Day 6
#
# Automated testing pipeline for HMR unified system integration
#

set -e  # Exit on any error

# Configuration
CI_DIR="/Volumes/My Shared Files/claudevm/projectsimcity/src/hmr"
BUILD_DIR="${CI_DIR}/build_ci"
TEST_DIR="${CI_DIR}/tests"
REPORTS_DIR="${CI_DIR}/reports"
LOG_FILE="${REPORTS_DIR}/ci_pipeline.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Initialize CI environment
init_ci_environment() {
    log_info "Initializing CI environment..."
    
    # Create directories
    mkdir -p "$BUILD_DIR" "$TEST_DIR" "$REPORTS_DIR"
    
    # Initialize log file
    echo "HMR CI Pipeline - $(date)" > "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
    
    log_success "CI environment initialized"
}

# Check system requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    # Check for required tools
    local required_tools=("clang" "make" "git" "python3")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    
    # Check for ARM64 architecture
    if [ "$(uname -m)" != "arm64" ]; then
        log_warning "Not running on ARM64 architecture - some tests may be skipped"
    fi
    
    log_success "System requirements check passed"
}

# Build HMR unified system
build_hmr_system() {
    log_info "Building HMR unified system..."
    
    cd "$CI_DIR"
    
    # Clean previous build
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"/*
    fi
    
    # Build with unified makefile
    if [ -f "Makefile.unified" ]; then
        make -f Makefile.unified clean 2>&1 | tee -a "$LOG_FILE"
        make -f Makefile.unified all 2>&1 | tee -a "$LOG_FILE"
    else
        # Fallback to standard makefile
        make clean 2>&1 | tee -a "$LOG_FILE"
        make all 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # Check if build succeeded
    if [ $? -eq 0 ]; then
        log_success "HMR system build completed"
    else
        log_error "HMR system build failed"
        return 1
    fi
}

# Run API compatibility tests
test_api_compatibility() {
    log_info "Running API compatibility tests..."
    
    # Test unified header compilation
    cat > "${BUILD_DIR}/api_test.c" << 'EOF'
#include "../include/interfaces/hmr_unified.h"
#include <stdio.h>

int main() {
    printf("API compatibility test - unified header included successfully\n");
    
    // Test basic type definitions
    hmr_module_state_t state = HMR_MODULE_STATE_ACTIVE;
    hmr_capability_flags_t caps = HMR_CAP_HOT_SWAPPABLE;
    hmr_asset_type_t asset = HMR_ASSET_METAL_SHADER;
    
    printf("Types: state=%d, caps=0x%x, asset=%d\n", state, caps, asset);
    
    return 0;
}
EOF
    
    cd "$BUILD_DIR"
    clang -I../../ -o api_test api_test.c 2>&1 | tee -a "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        ./api_test 2>&1 | tee -a "$LOG_FILE"
        if [ $? -eq 0 ]; then
            log_success "API compatibility test passed"
        else
            log_error "API compatibility test runtime failed"
            return 1
        fi
    else
        log_error "API compatibility test compilation failed"
        return 1
    fi
}

# Run integration tests
run_integration_tests() {
    log_info "Running integration tests..."
    
    cd "$CI_DIR"
    
    # Build integration test suite
    if [ -f "hmr_unified_integration_test.c" ]; then
        clang -I../../include -I. -o "${BUILD_DIR}/hmr_integration_test" \
              hmr_unified_integration_test.c \
              -lpthread 2>&1 | tee -a "$LOG_FILE"
        
        if [ $? -eq 0 ]; then
            log_info "Integration test binary built successfully"
            
            # Run integration tests
            "${BUILD_DIR}/hmr_integration_test" 2>&1 | tee "${REPORTS_DIR}/integration_test_results.txt"
            local test_result=$?
            
            if [ $test_result -eq 0 ]; then
                log_success "Integration tests passed"
            else
                log_error "Integration tests failed with exit code $test_result"
                return 1
            fi
        else
            log_error "Integration test compilation failed"
            return 1
        fi
    else
        log_warning "Integration test file not found - skipping"
    fi
}

# Run performance benchmarks
run_performance_tests() {
    log_info "Running performance benchmarks..."
    
    # Create performance test script
    cat > "${BUILD_DIR}/perf_test.py" << 'EOF'
#!/usr/bin/env python3
import time
import subprocess
import json

def run_benchmark(name, command, iterations=10):
    """Run a command multiple times and measure performance"""
    times = []
    for i in range(iterations):
        start = time.time()
        result = subprocess.run(command, shell=True, capture_output=True)
        end = time.time()
        if result.returncode == 0:
            times.append(end - start)
    
    if times:
        avg_time = sum(times) / len(times)
        min_time = min(times)
        max_time = max(times)
        return {
            "name": name,
            "avg_time": avg_time,
            "min_time": min_time,
            "max_time": max_time,
            "iterations": len(times)
        }
    return None

def main():
    benchmarks = []
    
    # API compilation benchmark
    result = run_benchmark("API Compilation", 
                          "clang -I../../ -c api_test.c -o /dev/null", 5)
    if result:
        benchmarks.append(result)
    
    # Integration test startup benchmark
    result = run_benchmark("Integration Test Startup", 
                          "./hmr_integration_test 2>/dev/null || true", 3)
    if result:
        benchmarks.append(result)
    
    # Generate report
    with open("../reports/performance_report.json", "w") as f:
        json.dump(benchmarks, f, indent=2)
    
    print("Performance benchmarks completed")
    for bench in benchmarks:
        print(f"  {bench['name']}: {bench['avg_time']:.3f}s avg")

if __name__ == "__main__":
    main()
EOF
    
    cd "$BUILD_DIR"
    python3 perf_test.py 2>&1 | tee -a "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        log_success "Performance benchmarks completed"
    else
        log_warning "Performance benchmarks had issues"
    fi
}

# Run static analysis
run_static_analysis() {
    log_info "Running static analysis..."
    
    cd "$CI_DIR"
    
    # Check for common issues in headers
    local issues=0
    
    # Check for include guards
    for header in *.h; do
        if [ -f "$header" ]; then
            if ! grep -q "#ifndef.*_H" "$header"; then
                log_warning "Missing include guard in $header"
                ((issues++))
            fi
        fi
    done
    
    # Check for trailing whitespace
    if find . -name "*.c" -o -name "*.h" | xargs grep -l '[[:space:]]$'; then
        log_warning "Files with trailing whitespace found"
        ((issues++))
    fi
    
    # Check for TODO/FIXME comments
    local todos=$(find . -name "*.c" -o -name "*.h" | xargs grep -c "TODO\|FIXME" | wc -l)
    if [ "$todos" -gt 0 ]; then
        log_info "Found $todos TODO/FIXME comments"
    fi
    
    if [ $issues -eq 0 ]; then
        log_success "Static analysis passed"
    else
        log_warning "Static analysis found $issues issues"
    fi
}

# Generate CI report
generate_report() {
    log_info "Generating CI report..."
    
    local report_file="${REPORTS_DIR}/ci_report.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>HMR CI Pipeline Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; }
        .section { margin: 20px 0; }
        .success { color: green; }
        .error { color: red; }
        .warning { color: orange; }
        pre { background-color: #f5f5f5; padding: 10px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="header">
        <h1>HMR CI Pipeline Report</h1>
        <p>Generated: $(date)</p>
        <p>Agent 0: HMR Orchestrator - Week 2, Day 6</p>
    </div>
    
    <div class="section">
        <h2>Test Results Summary</h2>
EOF
    
    # Add test results if available
    if [ -f "${REPORTS_DIR}/integration_test_results.txt" ]; then
        echo "<h3>Integration Tests</h3>" >> "$report_file"
        echo "<pre>" >> "$report_file"
        tail -20 "${REPORTS_DIR}/integration_test_results.txt" >> "$report_file"
        echo "</pre>" >> "$report_file"
    fi
    
    # Add performance results if available
    if [ -f "${REPORTS_DIR}/performance_report.json" ]; then
        echo "<h3>Performance Benchmarks</h3>" >> "$report_file"
        echo "<pre>" >> "$report_file"
        cat "${REPORTS_DIR}/performance_report.json" >> "$report_file"
        echo "</pre>" >> "$report_file"
    fi
    
    # Add build log
    echo "<h3>Build Log</h3>" >> "$report_file"
    echo "<pre>" >> "$report_file"
    tail -50 "$LOG_FILE" >> "$report_file"
    echo "</pre>" >> "$report_file"
    
    cat >> "$report_file" << EOF
    </div>
</body>
</html>
EOF
    
    log_success "CI report generated: $report_file"
}

# Main CI pipeline execution
main() {
    log_info "Starting HMR CI Pipeline"
    log_info "========================"
    
    # Initialize
    init_ci_environment
    
    # Check requirements
    if ! check_requirements; then
        log_error "Requirements check failed - aborting"
        exit 1
    fi
    
    # Build system
    if ! build_hmr_system; then
        log_error "Build failed - aborting"
        exit 1
    fi
    
    # Run tests
    local test_failures=0
    
    if ! test_api_compatibility; then
        ((test_failures++))
    fi
    
    if ! run_integration_tests; then
        ((test_failures++))
    fi
    
    # Run additional checks
    run_performance_tests
    run_static_analysis
    
    # Generate report
    generate_report
    
    # Final status
    log_info "========================"
    if [ $test_failures -eq 0 ]; then
        log_success "CI Pipeline completed successfully"
        exit 0
    else
        log_error "CI Pipeline completed with $test_failures test failures"
        exit 1
    fi
}

# Script entry point
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi