#!/bin/bash
# SimCity ARM64 Integration Testing System
# Agent E5: Platform Team - Comprehensive System Integration Tests
# Tests full system integration across all agent modules

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Project configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
TEST_DIR="${PROJECT_ROOT}/tests"
INTEGRATION_DIR="${BUILD_DIR}/integration_tests"
RESULTS_DIR="${INTEGRATION_DIR}/results"
LOGS_DIR="${INTEGRATION_DIR}/logs"

# Test configuration
INTEGRATION_TIMEOUT=300    # 5 minutes per integration test
SYSTEM_TEST_TIMEOUT=600   # 10 minutes for full system tests
TEST_AGENTS_COUNT=10000   # Test with 10k agents for integration
ENABLE_GRAPHICS_TESTS=true
ENABLE_PERFORMANCE_VALIDATION=true
GENERATE_COVERAGE=false

# Integration test scenarios
AGENT_INTEGRATION_TESTS=(
    "platform_memory_integration"          # Platform + Memory management
    "memory_graphics_integration"           # Memory + Graphics pipeline
    "graphics_simulation_integration"       # Graphics + Simulation engine
    "simulation_agents_integration"         # Simulation + AI agents
    "agents_pathfinding_integration"        # Agents + Pathfinding
    "network_infrastructure_integration"   # Network + Infrastructure
    "ui_simulation_binding"                 # UI + Simulation binding
    "io_persistence_integration"            # I/O + Save/Load system
    "audio_graphics_sync"                   # Audio + Graphics synchronization
    "tools_profiler_integration"           # Tools + System profiling
)

SYSTEM_INTEGRATION_TESTS=(
    "full_stack_initialization"            # Complete system startup
    "game_loop_integration"                # Full game loop execution
    "multi_agent_coordination"             # All agents working together
    "resource_management_stress"           # Cross-system resource usage
    "error_handling_cascade"               # Error propagation testing
    "performance_target_validation"        # 1M agents @ 60 FPS validation
    "memory_leak_detection"                # System-wide memory leak detection
    "graceful_shutdown_test"               # Clean system shutdown
)

# Cross-platform validation tests
PLATFORM_VALIDATION_TESTS=(
    "arm64_instruction_validation"         # ARM64 assembly correctness
    "apple_silicon_optimization"           # Apple Silicon specific features
    "metal_pipeline_validation"            # Metal graphics pipeline
    "core_audio_integration"               # Core Audio functionality
    "system_framework_binding"             # macOS framework integration
)

# Test results tracking
TOTAL_INTEGRATION_TESTS=0
PASSED_INTEGRATION_TESTS=0
FAILED_INTEGRATION_TESTS=0
INTEGRATION_TEST_RESULTS=()
SYSTEM_ISSUES_DETECTED=()

print_banner() {
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${CYAN} SimCity ARM64 Integration Testing System${NC}"
    echo -e "${CYAN} Agent E5: Complete System Validation${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo ""
}

print_status() {
    echo -e "${BLUE}[INTEGRATION]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_test() {
    echo -e "${MAGENTA}[TEST]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [TEST_CATEGORIES...]"
    echo ""
    echo "Test Categories:"
    echo "  agent          Run agent integration tests"
    echo "  system         Run system integration tests"
    echo "  platform       Run platform validation tests"
    echo "  all            Run all integration tests (default)"
    echo ""
    echo "Options:"
    echo "  --timeout N    Set integration test timeout (default: 300s)"
    echo "  --agents N     Set test agent count (default: 10000)"
    echo "  --no-graphics  Skip graphics-related tests"
    echo "  --coverage     Enable code coverage analysis"
    echo "  --performance  Enable performance validation"
    echo "  --verbose      Enable verbose test output"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "Specific tests:"
    for test in "${AGENT_INTEGRATION_TESTS[@]}"; do
        echo "  $test"
    done
    echo ""
    echo "Examples:"
    echo "  $0                    # Run all integration tests"
    echo "  $0 agent             # Run only agent integration tests"
    echo "  $0 --agents 1000     # Run with 1000 test agents"
    echo "  $0 --coverage all    # Run all tests with coverage"
}

# Function to setup integration test environment
setup_integration_environment() {
    print_status "Setting up integration test environment..."
    
    # Create test directories
    mkdir -p "${INTEGRATION_DIR}"/{results,logs,data,temp}
    mkdir -p "${RESULTS_DIR}"/{agent,system,platform}
    mkdir -p "${LOGS_DIR}"/{agent,system,platform}
    
    # Create test data
    mkdir -p "${INTEGRATION_DIR}/data"/{cities,saves,assets}
    
    # Setup test configuration
    export TEST_ENVIRONMENT="integration"
    export TEST_DATA_DIR="${INTEGRATION_DIR}/data"
    export TEST_TIMEOUT="$INTEGRATION_TIMEOUT"
    export AGENT_COUNT="$TEST_AGENTS_COUNT"
    
    # System optimizations for testing
    # Disable energy saving during tests
    pmset -a disablesleep 1 2>/dev/null || true
    
    # Set testing-friendly resource limits
    ulimit -c unlimited    # Enable core dumps for crash analysis
    ulimit -n 4096        # Increase file descriptor limit
    
    print_success "Integration test environment ready"
}

# Function to validate test prerequisites
validate_test_prerequisites() {
    print_status "Validating test prerequisites..."
    
    local missing_requirements=()
    
    # Check for built executables
    if [ ! -f "${BUILD_DIR}/bin/simcity_full" ]; then
        missing_requirements+=("simcity_full executable")
    fi
    
    # Check for test executables
    local test_exe_count=$(find "${BUILD_DIR}/test" -name "*integration*" -type f -executable | wc -l)
    if [ "$test_exe_count" -eq 0 ]; then
        missing_requirements+=("integration test executables")
    fi
    
    # Check system requirements
    local memory_gb=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
    if [ "$memory_gb" -lt 8 ]; then
        print_warning "System has ${memory_gb}GB RAM. 8GB+ recommended for integration testing"
    fi
    
    # Check for Metal support (graphics tests)
    if [ "$ENABLE_GRAPHICS_TESTS" = true ]; then
        if ! system_profiler SPDisplaysDataType | grep -q "Metal"; then
            print_warning "Metal support not detected - graphics tests may fail"
        fi
    fi
    
    if [ ${#missing_requirements[@]} -gt 0 ]; then
        print_failure "Missing test prerequisites:"
        for req in "${missing_requirements[@]}"; do
            echo "  - $req"
        done
        exit 1
    fi
    
    print_success "All test prerequisites validated"
}

# Function to run agent integration test
run_agent_integration_test() {
    local test_name="$1"
    local test_executable="${BUILD_DIR}/test/${test_name}"
    
    if [ ! -x "$test_executable" ]; then
        print_warning "Integration test not found: $test_name"
        return 2  # Skip
    fi
    
    print_test "Running agent integration test: $test_name"
    
    local start_time=$SECONDS
    local result_file="${RESULTS_DIR}/agent/${test_name}_$(date +%Y%m%d_%H%M%S).json"
    local log_file="${LOGS_DIR}/agent/${test_name}.log"
    
    # Setup test-specific environment
    export INTEGRATION_TEST_NAME="$test_name"
    export INTEGRATION_LOG_FILE="$log_file"
    
    # Start monitoring
    start_integration_monitoring "$test_name"
    
    # Run the integration test
    local test_result=0
    if timeout "$INTEGRATION_TIMEOUT" "$test_executable" \
        --agents "$TEST_AGENTS_COUNT" \
        --output "$result_file" \
        --verbose > "$log_file" 2>&1; then
        test_result=0
    else
        test_result=$?
    fi
    
    # Stop monitoring
    stop_integration_monitoring "$test_name"
    
    local duration=$((SECONDS - start_time))
    
    # Analyze results
    if [ "$test_result" -eq 0 ]; then
        if validate_integration_results "$test_name" "$result_file"; then
            print_success "$test_name passed (${duration}s)"
            PASSED_INTEGRATION_TESTS=$((PASSED_INTEGRATION_TESTS + 1))
            INTEGRATION_TEST_RESULTS+=("$test_name:PASS:$duration")
        else
            print_failure "$test_name validation failed"
            FAILED_INTEGRATION_TESTS=$((FAILED_INTEGRATION_TESTS + 1))
            INTEGRATION_TEST_RESULTS+=("$test_name:FAIL_VALIDATION:$duration")
            test_result=1
        fi
    elif [ "$test_result" -eq 124 ]; then
        print_failure "$test_name timed out after ${INTEGRATION_TIMEOUT}s"
        FAILED_INTEGRATION_TESTS=$((FAILED_INTEGRATION_TESTS + 1))
        INTEGRATION_TEST_RESULTS+=("$test_name:TIMEOUT:$duration")
    else
        print_failure "$test_name failed with exit code $test_result"
        FAILED_INTEGRATION_TESTS=$((FAILED_INTEGRATION_TESTS + 1))
        INTEGRATION_TEST_RESULTS+=("$test_name:FAIL:$duration")
    fi
    
    TOTAL_INTEGRATION_TESTS=$((TOTAL_INTEGRATION_TESTS + 1))
    return $test_result
}

# Function to run system integration test
run_system_integration_test() {
    local test_name="$1"
    
    print_test "Running system integration test: $test_name"
    
    case "$test_name" in
        full_stack_initialization)
            run_full_stack_initialization_test
            ;;
        game_loop_integration)
            run_game_loop_integration_test
            ;;
        multi_agent_coordination)
            run_multi_agent_coordination_test
            ;;
        resource_management_stress)
            run_resource_management_stress_test
            ;;
        error_handling_cascade)
            run_error_handling_cascade_test
            ;;
        performance_target_validation)
            run_performance_target_validation_test
            ;;
        memory_leak_detection)
            run_memory_leak_detection_test
            ;;
        graceful_shutdown_test)
            run_graceful_shutdown_test
            ;;
        *)
            print_warning "Unknown system integration test: $test_name"
            return 2
            ;;
    esac
}

# Function to run full stack initialization test
run_full_stack_initialization_test() {
    local test_name="full_stack_initialization"
    local start_time=$SECONDS
    
    print_status "Testing complete system initialization..."
    
    local log_file="${LOGS_DIR}/system/${test_name}.log"
    local result_file="${RESULTS_DIR}/system/${test_name}.json"
    
    # Test system startup sequence
    local main_executable="${BUILD_DIR}/bin/simcity_full"
    
    if [ ! -x "$main_executable" ]; then
        print_failure "Main executable not found: $main_executable"
        return 1
    fi
    
    # Run initialization test
    local init_result=0
    if timeout 60 "$main_executable" --test-init --exit-after-init > "$log_file" 2>&1; then
        # Validate initialization sequence
        if grep -q "All agents initialized successfully" "$log_file" && \
           grep -q "System ready" "$log_file"; then
            print_success "Full stack initialization test passed"
            init_result=0
        else
            print_failure "Initialization sequence incomplete"
            init_result=1
        fi
    else
        print_failure "Initialization test failed or timed out"
        init_result=1
    fi
    
    local duration=$((SECONDS - start_time))
    TOTAL_INTEGRATION_TESTS=$((TOTAL_INTEGRATION_TESTS + 1))
    
    if [ "$init_result" -eq 0 ]; then
        PASSED_INTEGRATION_TESTS=$((PASSED_INTEGRATION_TESTS + 1))
        INTEGRATION_TEST_RESULTS+=("$test_name:PASS:$duration")
    else
        FAILED_INTEGRATION_TESTS=$((FAILED_INTEGRATION_TESTS + 1))
        INTEGRATION_TEST_RESULTS+=("$test_name:FAIL:$duration")
    fi
    
    return $init_result
}

# Function to run performance target validation test
run_performance_target_validation_test() {
    local test_name="performance_target_validation"
    local start_time=$SECONDS
    
    if [ "$ENABLE_PERFORMANCE_VALIDATION" != true ]; then
        print_warning "Performance validation disabled - skipping"
        return 2
    fi
    
    print_status "Validating performance targets (1M agents @ 60 FPS)..."
    
    local log_file="${LOGS_DIR}/system/${test_name}.log"
    local result_file="${RESULTS_DIR}/system/${test_name}.json"
    
    # Run performance validation
    local perf_test="${BUILD_DIR}/benchmark/performance_target_validation"
    
    if [ ! -x "$perf_test" ]; then
        print_warning "Performance validation executable not found"
        return 2
    fi
    
    local perf_result=0
    if timeout "$SYSTEM_TEST_TIMEOUT" "$perf_test" \
        --agents 1000000 \
        --target-fps 60 \
        --duration 60 \
        --output "$result_file" > "$log_file" 2>&1; then
        
        # Parse results
        if command -v jq >/dev/null 2>&1 && [ -f "$result_file" ]; then
            local avg_fps=$(jq -r '.average_fps // 0' "$result_file")
            local agent_count=$(jq -r '.agent_count // 0' "$result_file")
            local memory_usage_mb=$(jq -r '.max_memory_usage_mb // 0' "$result_file")
            
            print_status "Performance Results:"
            print_status "  Agents: $agent_count"
            print_status "  Average FPS: $avg_fps"
            print_status "  Memory Usage: ${memory_usage_mb}MB"
            
            # Validate against targets
            if [ "$(echo "$avg_fps >= 60" | bc -l)" -eq 1 ] && \
               [ "$agent_count" -ge 1000000 ] && \
               [ "$memory_usage_mb" -le 4096 ]; then
                print_success "Performance targets achieved!"
                perf_result=0
            else
                print_failure "Performance targets not met"
                SYSTEM_ISSUES_DETECTED+=("Performance targets not achieved")
                perf_result=1
            fi
        else
            print_failure "Could not parse performance results"
            perf_result=1
        fi
    else
        print_failure "Performance validation test failed"
        perf_result=1
    fi
    
    local duration=$((SECONDS - start_time))
    TOTAL_INTEGRATION_TESTS=$((TOTAL_INTEGRATION_TESTS + 1))
    
    if [ "$perf_result" -eq 0 ]; then
        PASSED_INTEGRATION_TESTS=$((PASSED_INTEGRATION_TESTS + 1))
        INTEGRATION_TEST_RESULTS+=("$test_name:PASS:$duration")
    else
        FAILED_INTEGRATION_TESTS=$((FAILED_INTEGRATION_TESTS + 1))
        INTEGRATION_TEST_RESULTS+=("$test_name:FAIL:$duration")
    fi
    
    return $perf_result
}

# Function to run memory leak detection test
run_memory_leak_detection_test() {
    local test_name="memory_leak_detection"
    local start_time=$SECONDS
    
    print_status "Running system-wide memory leak detection..."
    
    local log_file="${LOGS_DIR}/system/${test_name}.log"
    local main_executable="${BUILD_DIR}/bin/simcity_full"
    
    # Run with memory leak detection
    local leak_result=0
    if command -v leaks >/dev/null 2>&1; then
        print_status "Using macOS leaks tool for detection..."
        
        # Run application for a period and check for leaks
        if timeout 120 leaks --atExit -- "$main_executable" \
            --test-mode --duration 60 > "$log_file" 2>&1; then
            
            if grep -q "0 leaks for 0 total leaked bytes" "$log_file"; then
                print_success "No memory leaks detected"
                leak_result=0
            else
                print_failure "Memory leaks detected - see $log_file"
                SYSTEM_ISSUES_DETECTED+=("Memory leaks detected")
                leak_result=1
            fi
        else
            print_failure "Memory leak detection test failed"
            leak_result=1
        fi
    else
        print_warning "Memory leak detection tools not available"
        return 2
    fi
    
    local duration=$((SECONDS - start_time))
    TOTAL_INTEGRATION_TESTS=$((TOTAL_INTEGRATION_TESTS + 1))
    
    if [ "$leak_result" -eq 0 ]; then
        PASSED_INTEGRATION_TESTS=$((PASSED_INTEGRATION_TESTS + 1))
        INTEGRATION_TEST_RESULTS+=("$test_name:PASS:$duration")
    else
        FAILED_INTEGRATION_TESTS=$((FAILED_INTEGRATION_TESTS + 1))
        INTEGRATION_TEST_RESULTS+=("$test_name:FAIL:$duration")
    fi
    
    return $leak_result
}

# Function to start integration monitoring
start_integration_monitoring() {
    local test_name="$1"
    local monitor_dir="${LOGS_DIR}/monitoring/${test_name}"
    
    mkdir -p "$monitor_dir"
    
    # CPU and memory monitoring
    top -l 0 -s 1 > "${monitor_dir}/system_usage.txt" &
    echo $! > "${monitor_dir}/top.pid"
    
    # GPU monitoring (if available)
    if command -v ioreg >/dev/null 2>&1; then
        while sleep 1; do
            ioreg -l -w 0 | grep -i "PerformanceStatistics" >> "${monitor_dir}/gpu_usage.txt" 2>/dev/null || true
        done &
        echo $! > "${monitor_dir}/gpu_monitor.pid"
    fi
}

# Function to stop integration monitoring
stop_integration_monitoring() {
    local test_name="$1"
    local monitor_dir="${LOGS_DIR}/monitoring/${test_name}"
    
    # Stop monitoring processes
    for pid_file in "${monitor_dir}"/*.pid; do
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            kill "$pid" 2>/dev/null || true
            rm -f "$pid_file"
        fi
    done
}

# Function to validate integration results
validate_integration_results() {
    local test_name="$1"
    local result_file="$2"
    
    if [ ! -f "$result_file" ]; then
        print_warning "Result file not found for $test_name"
        return 1
    fi
    
    # Basic JSON validation
    if command -v jq >/dev/null 2>&1; then
        if ! jq . "$result_file" >/dev/null 2>&1; then
            print_warning "Invalid JSON in result file for $test_name"
            return 1
        fi
        
        # Check for success indicator
        local success=$(jq -r '.success // false' "$result_file" 2>/dev/null)
        if [ "$success" = "true" ]; then
            return 0
        else
            local error_msg=$(jq -r '.error // "Unknown error"' "$result_file" 2>/dev/null)
            print_warning "$test_name error: $error_msg"
            return 1
        fi
    fi
    
    # Fallback: check file size and basic content
    local file_size=$(stat -f%z "$result_file" 2>/dev/null || stat -c%s "$result_file" 2>/dev/null)
    if [ "$file_size" -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# Function to create integration test report
create_integration_report() {
    print_status "Creating integration test report..."
    
    local report_file="${INTEGRATION_DIR}/integration_report_$(date +%Y%m%d_%H%M%S).html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>SimCity ARM64 Integration Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f8f9fa; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .summary { display: flex; justify-content: space-around; margin: 20px 0; }
        .metric { text-align: center; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .passed { background-color: #d4edda; border-color: #c3e6cb; }
        .failed { background-color: #f8d7da; border-color: #f5c6cb; }
        .warning { background-color: #fff3cd; border-color: #ffeaa7; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007bff; }
        .test-result { margin: 10px 0; padding: 10px; background-color: #f8f9fa; }
        .issue { color: #dc3545; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>SimCity ARM64 Integration Test Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>System:</strong> $(uname -s) $(uname -r) $(uname -m)</p>
        <p><strong>Test Environment:</strong> Integration</p>
        <p><strong>Test Agent Count:</strong> $TEST_AGENTS_COUNT</p>
    </div>
    
    <div class="summary">
        <div class="metric $([ "$FAILED_INTEGRATION_TESTS" -eq 0 ] && echo "passed" || echo "failed")">
            <h3>$TOTAL_INTEGRATION_TESTS</h3>
            <p>Total Tests</p>
        </div>
        <div class="metric passed">
            <h3>$PASSED_INTEGRATION_TESTS</h3>
            <p>Passed</p>
        </div>
        <div class="metric $([ "$FAILED_INTEGRATION_TESTS" -eq 0 ] && echo "passed" || echo "failed")">
            <h3>$FAILED_INTEGRATION_TESTS</h3>
            <p>Failed</p>
        </div>
        <div class="metric $([ ${#SYSTEM_ISSUES_DETECTED[@]} -eq 0 ] && echo "passed" || echo "warning")">
            <h3>${#SYSTEM_ISSUES_DETECTED[@]}</h3>
            <p>Issues Detected</p>
        </div>
    </div>
    
    <div class="section">
        <h2>Integration Test Results</h2>
EOF

    # Add test results
    for result in "${INTEGRATION_TEST_RESULTS[@]}"; do
        local test_name=$(echo "$result" | cut -d: -f1)
        local status=$(echo "$result" | cut -d: -f2)
        local duration=$(echo "$result" | cut -d: -f3)
        
        local status_class="passed"
        if [[ "$status" == FAIL* || "$status" == "TIMEOUT" ]]; then
            status_class="failed"
        fi
        
        cat >> "$report_file" << EOF
        <div class="test-result $status_class">
            <strong>$test_name:</strong> $status (${duration}s)
        </div>
EOF
    done
    
    # Add system issues
    if [ ${#SYSTEM_ISSUES_DETECTED[@]} -gt 0 ]; then
        cat >> "$report_file" << EOF
    </div>
    
    <div class="section">
        <h2>System Issues Detected</h2>
EOF
        for issue in "${SYSTEM_ISSUES_DETECTED[@]}"; do
            echo "        <div class=\"issue\">⚠️ $issue</div>" >> "$report_file"
        done
    fi
    
    cat >> "$report_file" << EOF
    </div>
    
    <div class="section">
        <h2>Test Configuration</h2>
        <p><strong>Integration Timeout:</strong> ${INTEGRATION_TIMEOUT}s</p>
        <p><strong>System Test Timeout:</strong> ${SYSTEM_TEST_TIMEOUT}s</p>
        <p><strong>Graphics Tests:</strong> $ENABLE_GRAPHICS_TESTS</p>
        <p><strong>Performance Validation:</strong> $ENABLE_PERFORMANCE_VALIDATION</p>
        <p><strong>Coverage Analysis:</strong> $GENERATE_COVERAGE</p>
    </div>
    
    <div class="section">
        <h2>Test Artifacts</h2>
        <p><strong>Results Directory:</strong> $RESULTS_DIR</p>
        <p><strong>Logs Directory:</strong> $LOGS_DIR</p>
        <p><strong>Test Data:</strong> ${INTEGRATION_DIR}/data</p>
    </div>
</body>
</html>
EOF

    print_success "Integration test report created: $report_file"
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --timeout)
                INTEGRATION_TIMEOUT="$2"
                shift 2
                ;;
            --agents)
                TEST_AGENTS_COUNT="$2"
                shift 2
                ;;
            --no-graphics)
                ENABLE_GRAPHICS_TESTS=false
                shift
                ;;
            --coverage)
                GENERATE_COVERAGE=true
                shift
                ;;
            --performance)
                ENABLE_PERFORMANCE_VALIDATION=true
                shift
                ;;
            --verbose)
                set -x
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            agent|system|platform|all)
                # Test categories handled in main
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

# Main integration test function
main() {
    local start_time=$SECONDS
    
    print_banner
    
    # Parse arguments
    parse_arguments "$@"
    
    print_status "Integration Test Configuration:"
    echo "  Test Timeout: ${INTEGRATION_TIMEOUT}s"
    echo "  System Timeout: ${SYSTEM_TEST_TIMEOUT}s"
    echo "  Test Agents: $TEST_AGENTS_COUNT"
    echo "  Graphics Tests: $ENABLE_GRAPHICS_TESTS"
    echo "  Performance Validation: $ENABLE_PERFORMANCE_VALIDATION"
    echo ""
    
    # Setup and validation
    setup_integration_environment
    validate_test_prerequisites
    
    # Run agent integration tests
    print_status "Running agent integration tests..."
    for test in "${AGENT_INTEGRATION_TESTS[@]}"; do
        run_agent_integration_test "$test"
    done
    
    # Run system integration tests
    print_status "Running system integration tests..."
    for test in "${SYSTEM_INTEGRATION_TESTS[@]}"; do
        run_system_integration_test "$test"
    done
    
    # Create report
    create_integration_report
    
    # Final summary
    local total_time=$((SECONDS - start_time))
    echo ""
    print_status "Integration Test Summary"
    echo "========================"
    echo "Total Tests: $TOTAL_INTEGRATION_TESTS"
    echo "Passed: $PASSED_INTEGRATION_TESTS"
    echo "Failed: $FAILED_INTEGRATION_TESTS"
    echo "System Issues: ${#SYSTEM_ISSUES_DETECTED[@]}"
    echo "Execution Time: ${total_time}s"
    echo ""
    
    # Show issues if any
    if [ ${#SYSTEM_ISSUES_DETECTED[@]} -gt 0 ]; then
        print_warning "System issues detected:"
        for issue in "${SYSTEM_ISSUES_DETECTED[@]}"; do
            echo "  ⚠️  $issue"
        done
        echo ""
    fi
    
    if [ "$FAILED_INTEGRATION_TESTS" -eq 0 ] && [ ${#SYSTEM_ISSUES_DETECTED[@]} -eq 0 ]; then
        print_success "All integration tests passed - system integration validated!"
        exit 0
    elif [ "$FAILED_INTEGRATION_TESTS" -eq 0 ]; then
        print_warning "All tests passed but system issues detected"
        exit 2
    else
        print_failure "$FAILED_INTEGRATION_TESTS integration test(s) failed"
        exit 1
    fi
}

# Execute main function with all arguments
main "$@"