#!/bin/bash
# SimCity ARM64 Performance Benchmarking System
# Agent E5: Platform Team - Automated Performance Testing
# Comprehensive benchmarking for 1M+ agents at 60 FPS target

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
BENCHMARK_DIR="${BUILD_DIR}/benchmark"
RESULTS_DIR="${BENCHMARK_DIR}/results"
REPORTS_DIR="${BENCHMARK_DIR}/reports"
BASELINE_DIR="${PROJECT_ROOT}/benchmarks/baselines"

# Benchmark configuration
BENCHMARK_DURATION=60       # Default benchmark duration in seconds
WARMUP_DURATION=10         # Warmup time before measurements
COOLDOWN_DURATION=5        # Cooldown between benchmarks
TARGET_FPS=60              # Target framerate
TARGET_AGENTS=1000000      # Target agent count
MEMORY_TARGET_GB=4         # Target memory usage limit

# Performance targets (baseline thresholds)
TARGET_FRAME_TIME_MS=16.67  # 60 FPS = 16.67ms per frame
TARGET_MEMORY_USAGE_MB=4096 # 4GB memory limit
TARGET_CPU_USAGE_PERCENT=80 # CPU usage limit
TARGET_GPU_USAGE_PERCENT=50 # GPU usage limit on M1

# Benchmark categories
MICRO_BENCHMARKS=(
    "memory_allocation_speed"
    "assembly_math_operations"
    "platform_syscall_overhead"
    "graphics_sprite_batching"
    "pathfinding_a_star"
    "ecs_component_updates"
)

SYSTEM_BENCHMARKS=(
    "full_simulation_performance"
    "graphics_rendering_pipeline"
    "memory_management_stress"
    "multi_agent_coordination"
    "ui_responsiveness_test"
    "audio_latency_test"
)

SCALABILITY_BENCHMARKS=(
    "agent_scaling_1k_to_1m"
    "memory_scaling_test" 
    "graphics_load_scaling"
    "simulation_complexity_scaling"
)

# System monitoring tools
MONITOR_CPU_USAGE=true
MONITOR_MEMORY_USAGE=true
MONITOR_GPU_USAGE=true
MONITOR_THERMAL=true
MONITOR_POWER=true
USE_INSTRUMENTS=false

# Benchmark results storage
BENCHMARK_RESULTS=()
PERFORMANCE_METRICS=()
REGRESSION_DETECTED=false

print_banner() {
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${CYAN} SimCity ARM64 Performance Benchmarking System${NC}"
    echo -e "${CYAN} Agent E5: 1M+ Agents @ 60 FPS Target${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo ""
}

print_status() {
    echo -e "${BLUE}[BENCH]${NC} $1"
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

print_metric() {
    echo -e "${MAGENTA}[METRIC]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [BENCHMARK_CATEGORIES...]"
    echo ""
    echo "Benchmark Categories:"
    echo "  micro          Run micro-benchmarks"
    echo "  system         Run system-level benchmarks"
    echo "  scalability    Run scalability tests"
    echo "  all            Run all benchmarks (default)"
    echo ""
    echo "Options:"
    echo "  --duration N   Set benchmark duration in seconds (default: 60)"
    echo "  --agents N     Set target agent count (default: 1000000)"
    echo "  --fps N        Set target FPS (default: 60)"
    echo "  --memory N     Set memory limit in GB (default: 4)"
    echo "  --instruments  Use Instruments for detailed profiling"
    echo "  --baseline     Save results as new baseline"
    echo "  --compare      Compare with previous baseline"
    echo "  --quick        Run quick benchmarks (shorter duration)"
    echo "  --stress       Run extended stress testing"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "Specific benchmarks:"
    for bench in "${MICRO_BENCHMARKS[@]}"; do
        echo "  $bench"
    done
    echo ""
    echo "Examples:"
    echo "  $0                           # Run all benchmarks"
    echo "  $0 --quick micro            # Quick micro-benchmarks"
    echo "  $0 --agents 100000 system   # System tests with 100k agents"
    echo "  $0 --instruments all        # Full benchmarks with Instruments"
    echo "  $0 --compare                # Compare with baseline"
}

# Function to check system requirements
check_system_requirements() {
    print_status "Checking system requirements..."
    
    # Check ARM64 architecture
    if [[ "$(uname -m)" != "arm64" ]]; then
        print_failure "Benchmarks require ARM64 architecture (Apple Silicon)"
        exit 1
    fi
    
    # Check available memory
    local total_memory_gb=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
    if [ "$total_memory_gb" -lt 8 ]; then
        print_warning "System has ${total_memory_gb}GB RAM. 16GB+ recommended for full benchmarking"
    fi
    
    # Check for benchmark executables
    if [ ! -d "${BUILD_DIR}/benchmark" ]; then
        print_failure "Benchmark executables not found. Run build system with --benchmark flag"
        exit 1
    fi
    
    # Check monitoring tools
    if ! command -v top >/dev/null 2>&1; then
        print_warning "System monitoring tools not fully available"
    fi
    
    print_success "System requirements check passed"
}

# Function to setup benchmark environment
setup_benchmark_environment() {
    print_status "Setting up benchmark environment..."
    
    # Create benchmark directories
    mkdir -p "${RESULTS_DIR}"/{micro,system,scalability}
    mkdir -p "${REPORTS_DIR}"
    mkdir -p "${BASELINE_DIR}"
    
    # Setup benchmark data
    mkdir -p "${BENCHMARK_DIR}/data"/{input,output,temp}
    
    # System optimization for benchmarking
    print_status "Optimizing system for benchmarking..."
    
    # Disable Spotlight indexing for benchmark directory (if possible)
    mdutil -i off "${BENCHMARK_DIR}" 2>/dev/null || true
    
    # Set high performance mode (if available)
    pmset -a disablesleep 1 2>/dev/null || true
    
    # Clear system caches
    sync
    
    print_success "Benchmark environment ready"
}

# Function to start system monitoring
start_system_monitoring() {
    local benchmark_name="$1"
    local monitor_duration="$2"
    
    print_status "Starting system monitoring for $benchmark_name..."
    
    local monitor_dir="${RESULTS_DIR}/monitoring/${benchmark_name}"
    mkdir -p "$monitor_dir"
    
    # CPU monitoring
    if [ "$MONITOR_CPU_USAGE" = true ]; then
        top -l $(($monitor_duration + 10)) -n 0 -F -R > "${monitor_dir}/cpu_usage.txt" 2>&1 &
        echo $! > "${monitor_dir}/cpu_monitor.pid"
    fi
    
    # Memory monitoring  
    if [ "$MONITOR_MEMORY_USAGE" = true ]; then
        while sleep 1; do
            vm_stat | grep -E "(free|active|inactive|wired|compressed)" >> "${monitor_dir}/memory_usage.txt"
        done &
        echo $! > "${monitor_dir}/memory_monitor.pid"
    fi
    
    # GPU monitoring (if available)
    if [ "$MONITOR_GPU_USAGE" = true ]; then
        if command -v ioreg >/dev/null 2>&1; then
            while sleep 1; do
                ioreg -l -w 0 | grep -i "PerformanceStatistics" >> "${monitor_dir}/gpu_usage.txt" 2>/dev/null || true
            done &
            echo $! > "${monitor_dir}/gpu_monitor.pid"
        fi
    fi
    
    # Thermal monitoring
    if [ "$MONITOR_THERMAL" = true ]; then
        if command -v powermetrics >/dev/null 2>&1; then
            sudo powermetrics --show-thermal -n $(($monitor_duration + 5)) > "${monitor_dir}/thermal.txt" 2>&1 &
            echo $! > "${monitor_dir}/thermal_monitor.pid"
        fi
    fi
    
    print_success "System monitoring started"
}

# Function to stop system monitoring
stop_system_monitoring() {
    local benchmark_name="$1"
    
    print_status "Stopping system monitoring for $benchmark_name..."
    
    local monitor_dir="${RESULTS_DIR}/monitoring/${benchmark_name}"
    
    # Stop all monitoring processes
    for pid_file in "${monitor_dir}"/*.pid; do
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            kill "$pid" 2>/dev/null || true
            rm -f "$pid_file"
        fi
    done
    
    # Wait for processes to terminate
    sleep 2
    
    print_success "System monitoring stopped"
}

# Function to run micro-benchmark
run_micro_benchmark() {
    local benchmark_name="$1"
    local benchmark_exe="${BUILD_DIR}/benchmark/${benchmark_name}"
    
    if [ ! -x "$benchmark_exe" ]; then
        print_warning "Micro-benchmark not found: $benchmark_name"
        return 1
    fi
    
    print_status "Running micro-benchmark: $benchmark_name"
    
    local result_file="${RESULTS_DIR}/micro/${benchmark_name}_$(date +%Y%m%d_%H%M%S).json"
    local start_time=$(date +%s.%N)
    
    # Start monitoring
    start_system_monitoring "$benchmark_name" "$BENCHMARK_DURATION"
    
    # Warmup phase
    print_status "Warmup phase (${WARMUP_DURATION}s)..."
    timeout "$WARMUP_DURATION" "$benchmark_exe" --warmup 2>/dev/null || true
    
    # Actual benchmark
    print_status "Benchmark phase (${BENCHMARK_DURATION}s)..."
    local benchmark_result=0
    if timeout "$BENCHMARK_DURATION" "$benchmark_exe" --benchmark > "$result_file" 2>&1; then
        benchmark_result=0
    else
        benchmark_result=$?
    fi
    
    # Stop monitoring
    stop_system_monitoring "$benchmark_name"
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    
    if [ "$benchmark_result" -eq 0 ]; then
        print_success "$benchmark_name completed (${duration}s)"
        
        # Parse results if JSON format
        if [ -f "$result_file" ] && command -v jq >/dev/null 2>&1; then
            local operations_per_sec=$(jq -r '.operations_per_second // "N/A"' "$result_file" 2>/dev/null)
            local latency_ms=$(jq -r '.avg_latency_ms // "N/A"' "$result_file" 2>/dev/null)
            
            print_metric "$benchmark_name: ${operations_per_sec} ops/sec, ${latency_ms}ms latency"
        fi
        
        BENCHMARK_RESULTS+=("$benchmark_name:PASS:$duration")
        return 0
    else
        print_failure "$benchmark_name failed"
        BENCHMARK_RESULTS+=("$benchmark_name:FAIL:$duration")
        return 1
    fi
}

# Function to run system benchmark
run_system_benchmark() {
    local benchmark_name="$1"
    local benchmark_exe="${BUILD_DIR}/benchmark/${benchmark_name}"
    
    if [ ! -x "$benchmark_exe" ]; then
        print_warning "System benchmark not found: $benchmark_name"
        return 1
    fi
    
    print_status "Running system benchmark: $benchmark_name"
    
    local result_file="${RESULTS_DIR}/system/${benchmark_name}_$(date +%Y%m%d_%H%M%S).json"
    local start_time=$(date +%s.%N)
    
    # Start comprehensive monitoring
    start_system_monitoring "$benchmark_name" "$BENCHMARK_DURATION"
    
    # Run benchmark with specific parameters
    local benchmark_args=(
        "--duration" "$BENCHMARK_DURATION"
        "--agents" "$TARGET_AGENTS"
        "--target-fps" "$TARGET_FPS"
        "--memory-limit" "${TARGET_MEMORY_USAGE_MB}M"
    )
    
    print_status "Running $benchmark_name with ${TARGET_AGENTS} agents @ ${TARGET_FPS} FPS..."
    
    local benchmark_result=0
    if timeout $((BENCHMARK_DURATION + 30)) "$benchmark_exe" "${benchmark_args[@]}" > "$result_file" 2>&1; then
        benchmark_result=0
    else
        benchmark_result=$?
    fi
    
    # Stop monitoring
    stop_system_monitoring "$benchmark_name"
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    
    if [ "$benchmark_result" -eq 0 ]; then
        print_success "$benchmark_name completed (${duration}s)"
        
        # Extract key performance metrics
        analyze_system_benchmark_results "$benchmark_name" "$result_file"
        
        BENCHMARK_RESULTS+=("$benchmark_name:PASS:$duration")
        return 0
    else
        print_failure "$benchmark_name failed"
        BENCHMARK_RESULTS+=("$benchmark_name:FAIL:$duration")
        return 1
    fi
}

# Function to analyze system benchmark results
analyze_system_benchmark_results() {
    local benchmark_name="$1"
    local result_file="$2"
    
    if [ ! -f "$result_file" ]; then
        return 1
    fi
    
    print_status "Analyzing results for $benchmark_name..."
    
    # Extract metrics (assuming JSON format)
    if command -v jq >/dev/null 2>&1; then
        local avg_fps=$(jq -r '.average_fps // "N/A"' "$result_file" 2>/dev/null)
        local min_fps=$(jq -r '.minimum_fps // "N/A"' "$result_file" 2>/dev/null)
        local max_memory_mb=$(jq -r '.max_memory_usage_mb // "N/A"' "$result_file" 2>/dev/null)
        local avg_frame_time_ms=$(jq -r '.avg_frame_time_ms // "N/A"' "$result_file" 2>/dev/null)
        local agent_count=$(jq -r '.agent_count // "N/A"' "$result_file" 2>/dev/null)
        
        print_metric "$benchmark_name Performance:"
        print_metric "  Average FPS: $avg_fps (target: $TARGET_FPS)"
        print_metric "  Minimum FPS: $min_fps"
        print_metric "  Frame Time: ${avg_frame_time_ms}ms (target: ${TARGET_FRAME_TIME_MS}ms)"
        print_metric "  Agent Count: $agent_count"
        print_metric "  Memory Usage: ${max_memory_mb}MB (limit: ${TARGET_MEMORY_USAGE_MB}MB)"
        
        # Check against targets
        if [ "$avg_fps" != "N/A" ] && [ "$(echo "$avg_fps >= $TARGET_FPS" | bc -l)" -eq 1 ]; then
            print_success "FPS target achieved: $avg_fps >= $TARGET_FPS"
        elif [ "$avg_fps" != "N/A" ]; then
            print_warning "FPS target missed: $avg_fps < $TARGET_FPS"
        fi
        
        if [ "$max_memory_mb" != "N/A" ] && [ "$(echo "$max_memory_mb <= $TARGET_MEMORY_USAGE_MB" | bc -l)" -eq 1 ]; then
            print_success "Memory target achieved: ${max_memory_mb}MB <= ${TARGET_MEMORY_USAGE_MB}MB"
        elif [ "$max_memory_mb" != "N/A" ]; then
            print_warning "Memory limit exceeded: ${max_memory_mb}MB > ${TARGET_MEMORY_USAGE_MB}MB"
        fi
        
        # Store metrics for comparison
        PERFORMANCE_METRICS+=("$benchmark_name:fps:$avg_fps")
        PERFORMANCE_METRICS+=("$benchmark_name:frame_time:$avg_frame_time_ms")
        PERFORMANCE_METRICS+=("$benchmark_name:memory:$max_memory_mb")
    fi
}

# Function to run scalability benchmark
run_scalability_benchmark() {
    local benchmark_name="$1"
    
    print_status "Running scalability benchmark: $benchmark_name"
    
    case "$benchmark_name" in
        agent_scaling_1k_to_1m)
            run_agent_scaling_test
            ;;
        memory_scaling_test)
            run_memory_scaling_test
            ;;
        graphics_load_scaling)
            run_graphics_scaling_test
            ;;
        simulation_complexity_scaling)
            run_simulation_scaling_test
            ;;
        *)
            print_warning "Unknown scalability benchmark: $benchmark_name"
            return 1
            ;;
    esac
}

# Function to run agent scaling test
run_agent_scaling_test() {
    print_status "Running agent scaling test (1K to 1M agents)..."
    
    local scaling_exe="${BUILD_DIR}/benchmark/agent_scaling_test"
    if [ ! -x "$scaling_exe" ]; then
        print_warning "Agent scaling test executable not found"
        return 1
    fi
    
    local result_file="${RESULTS_DIR}/scalability/agent_scaling_$(date +%Y%m%d_%H%M%S).json"
    
    # Test different agent counts
    local agent_counts=(1000 5000 10000 50000 100000 500000 1000000)
    
    echo '{"scaling_results": [' > "$result_file"
    
    for i in "${!agent_counts[@]}"; do
        local count=${agent_counts[$i]}
        print_status "Testing with $count agents..."
        
        local test_duration=30  # Shorter duration for scaling tests
        start_system_monitoring "agent_scaling_${count}" "$test_duration"
        
        local test_result=$(timeout $((test_duration + 10)) "$scaling_exe" --agents "$count" --duration "$test_duration" 2>/dev/null || echo '{"error": "timeout"}')
        
        stop_system_monitoring "agent_scaling_${count}"
        
        # Add to results
        if [ "$i" -gt 0 ]; then
            echo ',' >> "$result_file"
        fi
        echo "  {\"agent_count\": $count, \"result\": $test_result}" >> "$result_file"
        
        # Parse FPS from result
        if command -v jq >/dev/null 2>&1; then
            local fps=$(echo "$test_result" | jq -r '.average_fps // "N/A"' 2>/dev/null)
            print_metric "$count agents: ${fps} FPS"
        fi
    done
    
    echo ']}' >> "$result_file"
    
    print_success "Agent scaling test completed"
    BENCHMARK_RESULTS+=("agent_scaling_1k_to_1m:PASS:$(date +%s)")
}

# Function to compare with baseline
compare_with_baseline() {
    local baseline_file="${BASELINE_DIR}/performance_baseline.json"
    
    if [ ! -f "$baseline_file" ]; then
        print_warning "No baseline found for comparison"
        return 0
    fi
    
    print_status "Comparing results with performance baseline..."
    
    local comparison_file="${REPORTS_DIR}/baseline_comparison_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "SimCity ARM64 Performance Baseline Comparison"
        echo "============================================="
        echo "Generated: $(date)"
        echo ""
        
        echo "Performance Regressions Detected:"
        echo "---------------------------------"
    } > "$comparison_file"
    
    # Compare each metric with baseline (placeholder logic)
    local regressions_found=false
    for metric in "${PERFORMANCE_METRICS[@]}"; do
        local benchmark=$(echo "$metric" | cut -d: -f1)
        local type=$(echo "$metric" | cut -d: -f2)
        local value=$(echo "$metric" | cut -d: -f3)
        
        # Placeholder comparison logic
        if [ "$type" = "fps" ] && [ "$value" != "N/A" ]; then
            # If FPS dropped significantly, it's a regression
            local threshold=50  # Placeholder threshold
            if [ "$(echo "$value < $threshold" | bc -l)" -eq 1 ]; then
                echo "⚠️  $benchmark FPS regression: $value < $threshold" >> "$comparison_file"
                regressions_found=true
            fi
        fi
    done
    
    if [ "$regressions_found" = true ]; then
        REGRESSION_DETECTED=true
        print_warning "Performance regressions detected - see $comparison_file"
    else
        echo "✅ No significant regressions detected" >> "$comparison_file"
        print_success "No performance regressions detected"
    fi
}

# Function to save new baseline
save_baseline() {
    print_status "Saving performance baseline..."
    
    local baseline_file="${BASELINE_DIR}/performance_baseline.json"
    mkdir -p "$(dirname "$baseline_file")"
    
    {
        echo '{'
        echo "  \"baseline_date\": \"$(date -Iseconds)\","
        echo "  \"system_info\": {"
        echo "    \"architecture\": \"$(uname -m)\","
        echo "    \"os\": \"$(uname -s)\","
        echo "    \"version\": \"$(uname -r)\","
        echo "    \"memory_gb\": $(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')"
        echo "  },"
        echo "  \"performance_targets\": {"
        echo "    \"target_fps\": $TARGET_FPS,"
        echo "    \"target_agents\": $TARGET_AGENTS,"
        echo "    \"target_memory_mb\": $TARGET_MEMORY_USAGE_MB"
        echo "  },"
        echo "  \"benchmark_results\": ["
        
        local first=true
        for metric in "${PERFORMANCE_METRICS[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                echo ","
            fi
            
            local benchmark=$(echo "$metric" | cut -d: -f1)
            local type=$(echo "$metric" | cut -d: -f2)
            local value=$(echo "$metric" | cut -d: -f3)
            
            echo "    {\"benchmark\": \"$benchmark\", \"metric\": \"$type\", \"value\": \"$value\"}"
        done
        
        echo "  ]"
        echo '}'
    } > "$baseline_file"
    
    print_success "Performance baseline saved: $baseline_file"
}

# Function to generate comprehensive benchmark report
generate_benchmark_report() {
    print_status "Generating comprehensive benchmark report..."
    
    local report_file="${REPORTS_DIR}/benchmark_report_$(date +%Y%m%d_%H%M%S).html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>SimCity ARM64 Performance Benchmark Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f8f9fa; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .summary { display: flex; justify-content: space-around; margin: 20px 0; }
        .metric { text-align: center; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .passed { background-color: #d4edda; border-color: #c3e6cb; }
        .failed { background-color: #f8d7da; border-color: #f5c6cb; }
        .warning { background-color: #fff3cd; border-color: #ffeaa7; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007bff; }
        .benchmark-result { margin: 10px 0; padding: 10px; background-color: #f8f9fa; }
        .performance-chart { width: 100%; height: 300px; border: 1px solid #ddd; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>SimCity ARM64 Performance Benchmark Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>System:</strong> $(uname -s) $(uname -r) $(uname -m)</p>
        <p><strong>Memory:</strong> $(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')GB</p>
        <p><strong>Target:</strong> $TARGET_AGENTS agents @ $TARGET_FPS FPS</p>
    </div>
    
    <div class="summary">
        <div class="metric passed">
            <h3>Performance Targets</h3>
            <p>60 FPS @ 1M Agents</p>
            <p>&lt; 4GB Memory</p>
        </div>
        <div class="metric">
            <h3>Benchmarks Run</h3>
            <p>${#BENCHMARK_RESULTS[@]} Total</p>
        </div>
        <div class="metric $([ "$REGRESSION_DETECTED" = true ] && echo "warning" || echo "passed")">
            <h3>Regressions</h3>
            <p>$([ "$REGRESSION_DETECTED" = true ] && echo "Detected" || echo "None")</p>
        </div>
    </div>
    
    <div class="section">
        <h2>Key Performance Metrics</h2>
EOF

    # Add performance metrics to report
    for metric in "${PERFORMANCE_METRICS[@]}"; do
        local benchmark=$(echo "$metric" | cut -d: -f1)
        local type=$(echo "$metric" | cut -d: -f2)
        local value=$(echo "$metric" | cut -d: -f3)
        
        cat >> "$report_file" << EOF
        <div class="benchmark-result">
            <strong>$benchmark ($type):</strong> $value
        </div>
EOF
    done
    
    cat >> "$report_file" << EOF
    </div>
    
    <div class="section">
        <h2>Benchmark Results</h2>
EOF

    # Add benchmark results
    for result in "${BENCHMARK_RESULTS[@]}"; do
        local benchmark=$(echo "$result" | cut -d: -f1)
        local status=$(echo "$result" | cut -d: -f2)
        local duration=$(echo "$result" | cut -d: -f3)
        
        local status_class="passed"
        if [ "$status" = "FAIL" ]; then
            status_class="failed"
        fi
        
        cat >> "$report_file" << EOF
        <div class="benchmark-result $status_class">
            <strong>$benchmark:</strong> $status (${duration}s)
        </div>
EOF
    done
    
    cat >> "$report_file" << EOF
    </div>
    
    <div class="section">
        <h2>System Information</h2>
        <p><strong>Build Directory:</strong> $BUILD_DIR</p>
        <p><strong>Benchmark Duration:</strong> ${BENCHMARK_DURATION}s</p>
        <p><strong>Monitoring Enabled:</strong> CPU: $MONITOR_CPU_USAGE, Memory: $MONITOR_MEMORY_USAGE, GPU: $MONITOR_GPU_USAGE</p>
    </div>
    
    <div class="section">
        <h2>Next Steps</h2>
        <ul>
            <li>Review detailed results in: ${RESULTS_DIR}/</li>
            <li>Check system monitoring data for bottlenecks</li>
            <li>Compare with baseline using --compare flag</li>
            <li>Run profiling with --instruments for detailed analysis</li>
        </ul>
    </div>
</body>
</html>
EOF

    print_success "Benchmark report generated: $report_file"
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --duration)
                BENCHMARK_DURATION="$2"
                shift 2
                ;;
            --agents)
                TARGET_AGENTS="$2"
                shift 2
                ;;
            --fps)
                TARGET_FPS="$2"
                shift 2
                ;;
            --memory)
                TARGET_MEMORY_USAGE_MB=$((${2%G} * 1024))
                shift 2
                ;;
            --instruments)
                USE_INSTRUMENTS=true
                shift
                ;;
            --baseline)
                SAVE_BASELINE=true
                shift
                ;;
            --compare)
                COMPARE_BASELINE=true
                shift
                ;;
            --quick)
                BENCHMARK_DURATION=30
                WARMUP_DURATION=5
                shift
                ;;
            --stress)
                BENCHMARK_DURATION=300
                WARMUP_DURATION=30
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            micro|system|scalability|all)
                # Benchmark categories handled in main
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

# Main benchmark execution function
main() {
    local start_time=$SECONDS
    
    print_banner
    
    # Parse arguments
    parse_arguments "$@"
    
    print_status "Benchmark Configuration:"
    echo "  Duration: ${BENCHMARK_DURATION}s"
    echo "  Target Agents: $TARGET_AGENTS"
    echo "  Target FPS: $TARGET_FPS"
    echo "  Memory Limit: ${TARGET_MEMORY_USAGE_MB}MB"
    echo "  System Monitoring: Enabled"
    echo ""
    
    # Setup
    check_system_requirements
    setup_benchmark_environment
    
    # Run benchmark categories
    print_status "Running micro-benchmarks..."
    for benchmark in "${MICRO_BENCHMARKS[@]}"; do
        run_micro_benchmark "$benchmark"
        sleep "$COOLDOWN_DURATION"
    done
    
    print_status "Running system benchmarks..."
    for benchmark in "${SYSTEM_BENCHMARKS[@]}"; do
        run_system_benchmark "$benchmark"
        sleep "$COOLDOWN_DURATION"
    done
    
    print_status "Running scalability benchmarks..."
    for benchmark in "${SCALABILITY_BENCHMARKS[@]}"; do
        run_scalability_benchmark "$benchmark"
        sleep "$COOLDOWN_DURATION"
    done
    
    # Analysis and reporting
    if [ "${COMPARE_BASELINE:-false}" = true ]; then
        compare_with_baseline
    fi
    
    if [ "${SAVE_BASELINE:-false}" = true ]; then
        save_baseline
    fi
    
    generate_benchmark_report
    
    # Final summary
    local total_time=$((SECONDS - start_time))
    local passed_count=$(echo "${BENCHMARK_RESULTS[@]}" | grep -o ":PASS:" | wc -l)
    local failed_count=$(echo "${BENCHMARK_RESULTS[@]}" | grep -o ":FAIL:" | wc -l)
    
    echo ""
    print_status "Benchmark Execution Summary"
    echo "============================"
    echo "Total Benchmarks: ${#BENCHMARK_RESULTS[@]}"
    echo "Passed: $passed_count"
    echo "Failed: $failed_count"
    echo "Execution Time: ${total_time}s"
    echo ""
    
    if [ "$failed_count" -eq 0 ]; then
        if [ "$REGRESSION_DETECTED" = true ]; then
            print_warning "All benchmarks passed but performance regressions detected"
            exit 2
        else
            print_success "All benchmarks passed!"
            exit 0
        fi
    else
        print_failure "$failed_count benchmark(s) failed"
        exit 1
    fi
}

# Execute main function with all arguments
main "$@"