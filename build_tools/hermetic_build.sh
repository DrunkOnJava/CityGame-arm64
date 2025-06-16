#!/bin/bash
# SimCity ARM64 Hermetic Build System
# Agent 2: File Watcher & Build Pipeline - Day 11: Build Reproducibility
# Hermetic builds with checksums and complete environment isolation

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
HERMETIC_DIR="${BUILD_DIR}/hermetic"

# Hermetic build configuration
HERMETIC_ENABLED=true
CONTAINER_RUNTIME="podman"  # podman or docker
CONTAINER_IMAGE="simcity-arm64-build:latest"
CHECKSUM_ALGORITHM="sha256"
REPRODUCIBLE_TIMESTAMPS=true
DETERMINISTIC_BUILDS=true
ISOLATED_NETWORK=true
EPHEMERAL_STORAGE=true
BUILD_VERIFICATION=true

# Build environment isolation
BUILD_ISOLATION_LEVEL="maximum"  # minimum, standard, maximum
ENVIRONMENT_SEED=""
FILESYSTEM_ISOLATION=true
NETWORK_ISOLATION=true
PROCESS_ISOLATION=true
MEMORY_ISOLATION=true

# Checksum tracking
CHECKSUM_DATABASE="${HERMETIC_DIR}/checksums.db"
BUILD_MANIFEST="${HERMETIC_DIR}/build_manifest.json"
VERIFICATION_LOG="${HERMETIC_DIR}/verification.log"

print_banner() {
    echo -e "${CYAN}${BOLD}================================================================${NC}"
    echo -e "${CYAN}${BOLD} SimCity ARM64 Hermetic Build System${NC}"
    echo -e "${CYAN}${BOLD} Reproducible Builds with Complete Isolation${NC}"
    echo -e "${CYAN}${BOLD}================================================================${NC}"
    echo ""
    echo -e "${BLUE}Build Reproducibility: Deterministic, verifiable builds${NC}"
    echo -e "${BLUE}Environment Isolation: Complete build environment control${NC}"
    echo -e "${BLUE}Checksum Verification: Cryptographic build integrity${NC}"
    echo ""
}

print_status() {
    echo -e "${BLUE}[HERMETIC]${NC} $1"
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

print_verification() {
    echo -e "${MAGENTA}[VERIFY]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo ""
    echo "Hermetic Build Commands:"
    echo "  build              Run complete hermetic build"
    echo "  verify             Verify build reproducibility"
    echo "  checksum           Generate checksums for all artifacts"
    echo "  container-build    Build in isolated container"
    echo "  manifest           Generate build manifest"
    echo ""
    echo "Options:"
    echo "  --runtime RUNTIME        Container runtime (podman/docker)"
    echo "  --image IMAGE            Container image name"
    echo "  --algorithm ALGO         Checksum algorithm (sha256/sha512)"
    echo "  --isolation LEVEL        Isolation level (minimum/standard/maximum)"
    echo "  --no-timestamps          Disable reproducible timestamps"
    echo "  --no-deterministic       Disable deterministic builds"
    echo "  --no-network-isolation   Disable network isolation"
    echo "  --no-verification        Disable build verification"
    echo "  --seed SEED              Environment seed for reproducibility"
    echo "  --verbose                Enable verbose output"
    echo "  --help, -h               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 build                                    # Standard hermetic build"
    echo "  $0 build --isolation maximum               # Maximum isolation build"
    echo "  $0 verify                                   # Verify reproducibility"
    echo "  $0 container-build --runtime podman        # Build in Podman container"
    echo "  $0 checksum --algorithm sha512              # Generate SHA512 checksums"
}

# Function to initialize hermetic build environment
init_hermetic_environment() {
    print_status "Initializing hermetic build environment..."
    
    # Create hermetic build directories
    mkdir -p "${HERMETIC_DIR}"/{containers,manifests,checksums,verification,artifacts}
    mkdir -p "${HERMETIC_DIR}/environment"/{sources,tools,cache}
    
    # Initialize checksum database
    cat > "$CHECKSUM_DATABASE" << 'EOF'
# SimCity ARM64 Build Checksum Database
# Format: CHECKSUM_TYPE:CHECKSUM:FILENAME:BUILD_DATE:BUILD_VERSION
# Example: sha256:abc123...:libplatform.a:2025-06-16T10:30:00Z:1.0.0
EOF
    
    # Create build manifest template
    cat > "$BUILD_MANIFEST" << 'EOF'
{
    "build_info": {
        "project": "SimCity ARM64",
        "version": "",
        "build_date": "",
        "build_host": "",
        "build_user": "",
        "hermetic_enabled": true,
        "isolation_level": "",
        "container_runtime": "",
        "container_image": ""
    },
    "environment": {
        "os_version": "",
        "architecture": "",
        "compiler_version": "",
        "tools_versions": {},
        "environment_variables": {},
        "filesystem_state": {}
    },
    "source_code": {
        "git_commit": "",
        "git_branch": "",
        "git_dirty": false,
        "source_checksum": "",
        "source_files": []
    },
    "build_process": {
        "build_steps": [],
        "build_duration": 0,
        "build_success": false,
        "build_warnings": [],
        "build_errors": []
    },
    "artifacts": {
        "outputs": [],
        "checksums": {},
        "sizes": {},
        "dependencies": {}
    },
    "verification": {
        "reproducible": false,
        "verification_runs": [],
        "checksum_matches": true,
        "deterministic": true
    }
}
EOF
    
    print_success "Hermetic build environment initialized"
}

# Function to create container image for hermetic builds
create_container_image() {
    print_status "Creating hermetic build container image..."
    
    local dockerfile="${HERMETIC_DIR}/containers/Dockerfile.hermetic"
    
    cat > "$dockerfile" << 'EOF'
# SimCity ARM64 Hermetic Build Container
# Provides completely isolated build environment

FROM arm64v8/ubuntu:22.04

# Set build metadata
LABEL maintainer="SimCity ARM64 Build System"
LABEL description="Hermetic build environment for SimCity ARM64"
LABEL version="1.0"

# Set environment for reproducible builds
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PATH="/usr/local/bin:/usr/bin:/bin"

# Install build dependencies with pinned versions
RUN apt-get update && apt-get install -y \
    build-essential=12.9ubuntu3 \
    gcc=4:11.2.0-1ubuntu1 \
    g++=4:11.2.0-1ubuntu1 \
    clang=1:14.0-55~exp2 \
    llvm=1:14.0-55~exp2 \
    binutils=2.38-4ubuntu2 \
    make=4.3-4.1build1 \
    cmake=3.22.1-1ubuntu1 \
    git=1:2.34.1-1ubuntu1 \
    python3=3.10.6-1~22.04 \
    python3-pip=22.0.2+dfsg-1ubuntu0.2 \
    curl=7.81.0-1ubuntu1 \
    wget=1.21.2-2ubuntu1 \
    tar=1.34+dfsg-1ubuntu0.1 \
    gzip=1.10-4ubuntu4 \
    bzip2=1.0.8-5build1 \
    xz-utils=5.2.5-2ubuntu1 \
    unzip=6.0-26ubuntu3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Metal development tools (for macOS cross-compilation)
# Note: This would require additional setup for actual Metal compilation
RUN mkdir -p /usr/local/metal && \
    echo "# Metal tools placeholder" > /usr/local/metal/README.md

# Create reproducible user environment
RUN useradd -m -s /bin/bash builder && \
    echo "builder:builder" | chpasswd && \
    mkdir -p /home/builder/.cache && \
    chown -R builder:builder /home/builder

# Set up build workspace
RUN mkdir -p /workspace && \
    chown -R builder:builder /workspace

# Install additional build tools
RUN pip3 install --no-cache-dir \
    ninja==1.11.1 \
    meson==0.63.3 \
    conan==1.60.0

# Configure git for reproducible builds
RUN git config --global user.name "Hermetic Builder" && \
    git config --global user.email "builder@simcity.local" && \
    git config --global init.defaultBranch main

# Set up environment for deterministic builds
ENV SOURCE_DATE_EPOCH=1640995200
ENV FORCE_UNSAFE_CONFIGURE=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONHASHSEED=0

# Create build script
COPY build_hermetic.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/build_hermetic.sh

# Set working directory
WORKDIR /workspace

# Switch to builder user
USER builder

# Default command
CMD ["/usr/local/bin/build_hermetic.sh"]
EOF
    
    # Create container build script
    cat > "${HERMETIC_DIR}/containers/build_hermetic.sh" << 'EOF'
#!/bin/bash
# Hermetic build script for container execution

set -e

echo "Starting hermetic build in container..."

# Set reproducible environment
export SOURCE_DATE_EPOCH=1640995200
export BUILD_DATE=$(date -u -d "@$SOURCE_DATE_EPOCH" "+%Y-%m-%dT%H:%M:%SZ")
export PYTHONHASHSEED=0
export PYTHONDONTWRITEBYTECODE=1

# Change to workspace
cd /workspace

# Verify source integrity
if [ -f ".hermetic_checksum" ]; then
    echo "Verifying source integrity..."
    if ! sha256sum -c .hermetic_checksum; then
        echo "ERROR: Source integrity check failed"
        exit 1
    fi
fi

# Run the build
echo "Executing build pipeline..."
exec ./build_tools/build_master.sh "$@"
EOF
    
    chmod +x "${HERMETIC_DIR}/containers/build_hermetic.sh"
    
    # Build container image
    print_status "Building container image..."
    
    if command -v "$CONTAINER_RUNTIME" >/dev/null 2>&1; then
        cd "${HERMETIC_DIR}/containers"
        
        if $CONTAINER_RUNTIME build -t "$CONTAINER_IMAGE" -f Dockerfile.hermetic .; then
            print_success "Container image built successfully: $CONTAINER_IMAGE"
        else
            print_failure "Failed to build container image"
            return 1
        fi
    else
        print_warning "Container runtime '$CONTAINER_RUNTIME' not found. Install podman or docker."
        return 1
    fi
}

# Function to generate source checksum
generate_source_checksum() {
    print_status "Generating source code checksums..."
    
    local source_checksum_file="${HERMETIC_DIR}/checksums/source_checksum.txt"
    
    # Find all source files and generate checksums
    find "$PROJECT_ROOT/src" -type f \( -name "*.s" -o -name "*.c" -o -name "*.h" -o -name "*.m" \) | \
    sort | \
    xargs ${CHECKSUM_ALGORITHM}sum > "$source_checksum_file"
    
    # Add build scripts
    find "$BUILD_TOOLS_DIR" -type f -name "*.sh" | \
    sort | \
    xargs ${CHECKSUM_ALGORITHM}sum >> "$source_checksum_file"
    
    # Add configuration files
    find "$PROJECT_ROOT" -maxdepth 1 -type f \( -name "Makefile*" -o -name "*.json" -o -name "*.md" \) | \
    sort | \
    xargs ${CHECKSUM_ALGORITHM}sum >> "$source_checksum_file"
    
    # Generate overall source checksum
    local overall_checksum=$(${CHECKSUM_ALGORITHM}sum "$source_checksum_file" | awk '{print $1}')
    echo "$overall_checksum" > "${HERMETIC_DIR}/checksums/source_overall.checksum"
    
    print_success "Source checksums generated: $overall_checksum"
    return 0
}

# Function to run hermetic build
run_hermetic_build() {
    print_status "Starting hermetic build process..."
    
    local build_start_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local build_start_seconds=$SECONDS
    
    # Generate source checksums
    generate_source_checksum
    
    # Create build environment snapshot
    create_environment_snapshot
    
    if [ "$HERMETIC_ENABLED" = true ]; then
        # Run build in container
        run_container_build
    else
        # Run build with isolation
        run_isolated_build
    fi
    
    local build_end_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local build_duration=$((SECONDS - build_start_seconds))
    
    # Generate build artifacts checksums
    generate_artifact_checksums
    
    # Update build manifest
    update_build_manifest "$build_start_time" "$build_end_time" "$build_duration"
    
    print_success "Hermetic build completed in ${build_duration}s"
}

# Function to create environment snapshot
create_environment_snapshot() {
    print_status "Creating build environment snapshot..."
    
    local env_snapshot="${HERMETIC_DIR}/environment/snapshot.json"
    
    cat > "$env_snapshot" << EOF
{
    "system_info": {
        "hostname": "$(hostname)",
        "os_name": "$(uname -s)",
        "os_version": "$(uname -r)",
        "architecture": "$(uname -m)",
        "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    },
    "compiler_info": {
        "gcc_version": "$(gcc --version 2>/dev/null | head -1 || echo 'not found')",
        "clang_version": "$(clang --version 2>/dev/null | head -1 || echo 'not found')",
        "as_version": "$(as --version 2>/dev/null | head -1 || echo 'not found')",
        "ld_version": "$(ld -v 2>/dev/null || echo 'not found')"
    },
    "environment_variables": {
EOF
    
    # Add key environment variables
    local env_vars=("PATH" "HOME" "USER" "SHELL" "TERM" "LANG" "LC_ALL" "CC" "CXX" "CFLAGS" "CXXFLAGS" "LDFLAGS")
    local first=true
    
    for var in "${env_vars[@]}"; do
        if [ -n "${!var}" ]; then
            if [ "$first" = false ]; then
                echo "," >> "$env_snapshot"
            fi
            echo -n "        \"$var\": \"${!var}\"" >> "$env_snapshot"
            first=false
        fi
    done
    
    cat >> "$env_snapshot" << EOF

    },
    "tool_versions": {
        "make": "$(make --version 2>/dev/null | head -1 || echo 'not found')",
        "cmake": "$(cmake --version 2>/dev/null | head -1 || echo 'not found')",
        "python3": "$(python3 --version 2>/dev/null || echo 'not found')",
        "git": "$(git --version 2>/dev/null || echo 'not found')"
    },
    "git_info": {
        "commit": "$(git rev-parse HEAD 2>/dev/null || echo 'not a git repo')",
        "branch": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')",
        "dirty": $(git diff --quiet 2>/dev/null && echo 'false' || echo 'true')
    }
}
EOF
    
    print_success "Environment snapshot created"
}

# Function to run build in container
run_container_build() {
    print_status "Running hermetic build in container..."
    
    # Ensure container image exists
    if ! $CONTAINER_RUNTIME images | grep -q "$CONTAINER_IMAGE"; then
        create_container_image
    fi
    
    # Prepare container volumes
    local container_args=(
        "--rm"
        "--volume" "$PROJECT_ROOT:/workspace:ro"
        "--volume" "${HERMETIC_DIR}/artifacts:/workspace/build:rw"
        "--workdir" "/workspace"
    )
    
    # Add network isolation
    if [ "$NETWORK_ISOLATION" = true ]; then
        container_args+=("--network" "none")
    fi
    
    # Add memory limits
    if [ "$MEMORY_ISOLATION" = true ]; then
        container_args+=("--memory" "4g")
        container_args+=("--memory-swap" "4g")
    fi
    
    # Add CPU limits
    container_args+=("--cpus" "$(nproc)")
    
    # Set reproducible environment
    container_args+=("--env" "SOURCE_DATE_EPOCH=1640995200")
    container_args+=("--env" "PYTHONHASHSEED=0")
    container_args+=("--env" "PYTHONDONTWRITEBYTECODE=1")
    
    # Run build
    if $CONTAINER_RUNTIME run "${container_args[@]}" "$CONTAINER_IMAGE" \
        /usr/local/bin/build_hermetic.sh debug --no-tests; then
        print_success "Container build completed successfully"
    else
        print_failure "Container build failed"
        return 1
    fi
}

# Function to run isolated build
run_isolated_build() {
    print_status "Running isolated build..."
    
    # Create isolated environment
    local isolated_env=(
        "HOME=/tmp/hermetic_home"
        "TMPDIR=/tmp/hermetic_tmp"
        "PATH=/usr/local/bin:/usr/bin:/bin"
        "LANG=C.UTF-8"
        "LC_ALL=C.UTF-8"
    )
    
    # Set reproducible timestamp
    if [ "$REPRODUCIBLE_TIMESTAMPS" = true ]; then
        isolated_env+=("SOURCE_DATE_EPOCH=1640995200")
    fi
    
    # Create temporary directories
    mkdir -p /tmp/hermetic_home /tmp/hermetic_tmp
    
    # Run build with isolated environment
    if env -i "${isolated_env[@]}" \
        bash -c "cd '$PROJECT_ROOT' && ./build_tools/build_master.sh debug --no-tests"; then
        print_success "Isolated build completed successfully"
    else
        print_failure "Isolated build failed"
        return 1
    fi
    
    # Cleanup temporary directories
    rm -rf /tmp/hermetic_home /tmp/hermetic_tmp
}

# Function to generate artifact checksums
generate_artifact_checksums() {
    print_status "Generating build artifact checksums..."
    
    local artifact_checksum_file="${HERMETIC_DIR}/checksums/artifacts.txt"
    
    # Find all build artifacts
    if [ -d "$BUILD_DIR" ]; then
        find "$BUILD_DIR" -type f \( -name "*.a" -o -name "*.o" -o -name "*.so" -o -name "*.dylib" -o -name "simcity*" \) | \
        sort | \
        while read -r file; do
            if [ -f "$file" ]; then
                local checksum=$(${CHECKSUM_ALGORITHM}sum "$file" | awk '{print $1}')
                local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
                echo "$checksum:$size:$file" >> "$artifact_checksum_file"
                
                # Add to checksum database
                echo "${CHECKSUM_ALGORITHM}:$checksum:$(basename "$file"):$(date -u +"%Y-%m-%dT%H:%M:%SZ"):1.0.0" >> "$CHECKSUM_DATABASE"
            fi
        done
    fi
    
    # Find executables in project root
    find "$PROJECT_ROOT" -maxdepth 1 -type f -name "simcity*" -executable | \
    sort | \
    while read -r file; do
        if [ -f "$file" ]; then
            local checksum=$(${CHECKSUM_ALGORITHM}sum "$file" | awk '{print $1}')
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
            echo "$checksum:$size:$file" >> "$artifact_checksum_file"
            
            # Add to checksum database
            echo "${CHECKSUM_ALGORITHM}:$checksum:$(basename "$file"):$(date -u +"%Y-%m-%dT%H:%M:%SZ"):1.0.0" >> "$CHECKSUM_DATABASE"
        fi
    done
    
    print_success "Artifact checksums generated"
}

# Function to update build manifest
update_build_manifest() {
    local start_time="$1"
    local end_time="$2"
    local duration="$3"
    
    print_status "Updating build manifest..."
    
    # Get source checksum
    local source_checksum=""
    if [ -f "${HERMETIC_DIR}/checksums/source_overall.checksum" ]; then
        source_checksum=$(cat "${HERMETIC_DIR}/checksums/source_overall.checksum")
    fi
    
    # Get git info
    local git_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    local git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    local git_dirty=$(git diff --quiet 2>/dev/null && echo "false" || echo "true")
    
    # Update manifest
    cat > "$BUILD_MANIFEST" << EOF
{
    "build_info": {
        "project": "SimCity ARM64",
        "version": "1.0.0",
        "build_date": "$start_time",
        "build_end_date": "$end_time",
        "build_duration": $duration,
        "build_host": "$(hostname)",
        "build_user": "$(whoami)",
        "hermetic_enabled": $HERMETIC_ENABLED,
        "isolation_level": "$BUILD_ISOLATION_LEVEL",
        "container_runtime": "$CONTAINER_RUNTIME",
        "container_image": "$CONTAINER_IMAGE"
    },
    "environment": {
        "os_version": "$(uname -r)",
        "architecture": "$(uname -m)",
        "compiler_version": "$(gcc --version 2>/dev/null | head -1 || echo 'unknown')",
        "checksum_algorithm": "$CHECKSUM_ALGORITHM"
    },
    "source_code": {
        "git_commit": "$git_commit",
        "git_branch": "$git_branch",
        "git_dirty": $git_dirty,
        "source_checksum": "$source_checksum"
    },
    "build_process": {
        "build_success": true,
        "deterministic": $DETERMINISTIC_BUILDS,
        "reproducible_timestamps": $REPRODUCIBLE_TIMESTAMPS,
        "network_isolation": $NETWORK_ISOLATION,
        "filesystem_isolation": $FILESYSTEM_ISOLATION
    },
    "verification": {
        "build_verification": $BUILD_VERIFICATION,
        "checksum_algorithm": "$CHECKSUM_ALGORITHM",
        "manifest_version": "1.0"
    }
}
EOF
    
    print_success "Build manifest updated"
}

# Function to verify build reproducibility
verify_reproducibility() {
    print_status "Verifying build reproducibility..."
    
    local verification_start_time=$SECONDS
    
    # Create verification directory
    local verify_dir="${HERMETIC_DIR}/verification/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$verify_dir"
    
    # Run first build
    print_verification "Running first verification build..."
    run_hermetic_build > "${verify_dir}/build1.log" 2>&1
    
    # Copy first build artifacts
    if [ -d "$BUILD_DIR" ]; then
        cp -r "$BUILD_DIR" "${verify_dir}/build1_artifacts"
    fi
    
    # Clean build directory
    rm -rf "$BUILD_DIR"
    
    # Run second build
    print_verification "Running second verification build..."
    run_hermetic_build > "${verify_dir}/build2.log" 2>&1
    
    # Copy second build artifacts
    if [ -d "$BUILD_DIR" ]; then
        cp -r "$BUILD_DIR" "${verify_dir}/build2_artifacts"
    fi
    
    # Compare builds
    print_verification "Comparing build results..."
    
    local comparison_report="${verify_dir}/comparison_report.txt"
    echo "SimCity ARM64 Build Reproducibility Verification Report" > "$comparison_report"
    echo "Generated: $(date)" >> "$comparison_report"
    echo "=============================================" >> "$comparison_report"
    echo "" >> "$comparison_report"
    
    # Compare checksums
    local reproducible=true
    
    if [ -f "${verify_dir}/build1_artifacts/checksums/artifacts.txt" ] && 
       [ -f "${verify_dir}/build2_artifacts/checksums/artifacts.txt" ]; then
        
        if diff "${verify_dir}/build1_artifacts/checksums/artifacts.txt" \
                "${verify_dir}/build2_artifacts/checksums/artifacts.txt" > /dev/null; then
            echo "✅ Build artifacts are identical" >> "$comparison_report"
            print_success "Build artifacts are reproducible"
        else
            echo "❌ Build artifacts differ between runs" >> "$comparison_report"
            print_failure "Build artifacts are NOT reproducible"
            reproducible=false
            
            # Show differences
            echo "" >> "$comparison_report"
            echo "Checksum differences:" >> "$comparison_report"
            diff "${verify_dir}/build1_artifacts/checksums/artifacts.txt" \
                 "${verify_dir}/build2_artifacts/checksums/artifacts.txt" >> "$comparison_report" || true
        fi
    else
        echo "❌ Unable to compare checksums - missing checksum files" >> "$comparison_report"
        reproducible=false
    fi
    
    local verification_duration=$((SECONDS - verification_start_time))
    
    echo "" >> "$comparison_report"
    echo "Verification completed in ${verification_duration}s" >> "$comparison_report"
    echo "Reproducible: $([ "$reproducible" = true ] && echo "YES" || echo "NO")" >> "$comparison_report"
    
    # Log to verification log
    echo "$(date): Reproducibility verification: $([ "$reproducible" = true ] && echo "PASS" || echo "FAIL")" >> "$VERIFICATION_LOG"
    
    print_success "Reproducibility verification completed in ${verification_duration}s"
    
    if [ "$reproducible" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to generate checksum report
generate_checksum_report() {
    print_status "Generating comprehensive checksum report..."
    
    local report_file="${HERMETIC_DIR}/checksum_report_$(date +%Y%m%d_%H%M%S).html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>SimCity ARM64 Hermetic Build Checksum Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f8f9fa; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007bff; }
        .checksum { font-family: monospace; font-size: 12px; word-break: break-all; }
        .success { color: #28a745; }
        .warning { color: #ffc107; }
        .error { color: #dc3545; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f8f9fa; }
    </style>
</head>
<body>
    <div class="header">
        <h1>SimCity ARM64 Hermetic Build Checksum Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Algorithm:</strong> $CHECKSUM_ALGORITHM</p>
        <p><strong>Hermetic Enabled:</strong> $HERMETIC_ENABLED</p>
        <p><strong>Isolation Level:</strong> $BUILD_ISOLATION_LEVEL</p>
    </div>
    
    <div class="section">
        <h2>Build Configuration</h2>
        <p><strong>Container Runtime:</strong> $CONTAINER_RUNTIME</p>
        <p><strong>Container Image:</strong> $CONTAINER_IMAGE</p>
        <p><strong>Reproducible Timestamps:</strong> $REPRODUCIBLE_TIMESTAMPS</p>
        <p><strong>Deterministic Builds:</strong> $DETERMINISTIC_BUILDS</p>
        <p><strong>Network Isolation:</strong> $NETWORK_ISOLATION</p>
        <p><strong>Filesystem Isolation:</strong> $FILESYSTEM_ISOLATION</p>
    </div>
EOF
    
    # Add source checksums
    if [ -f "${HERMETIC_DIR}/checksums/source_checksum.txt" ]; then
        cat >> "$report_file" << EOF
    
    <div class="section">
        <h2>Source Code Checksums</h2>
        <table>
            <tr><th>File</th><th>Checksum</th></tr>
EOF
        
        while IFS= read -r line; do
            local checksum=$(echo "$line" | awk '{print $1}')
            local file=$(echo "$line" | awk '{print $2}')
            echo "            <tr><td>$file</td><td class=\"checksum\">$checksum</td></tr>" >> "$report_file"
        done < "${HERMETIC_DIR}/checksums/source_checksum.txt"
        
        echo "        </table>" >> "$report_file"
        echo "    </div>" >> "$report_file"
    fi
    
    # Add artifact checksums
    if [ -f "${HERMETIC_DIR}/checksums/artifacts.txt" ]; then
        cat >> "$report_file" << EOF
    
    <div class="section">
        <h2>Build Artifact Checksums</h2>
        <table>
            <tr><th>File</th><th>Checksum</th><th>Size</th></tr>
EOF
        
        while IFS=':' read -r checksum size file; do
            echo "            <tr><td>$file</td><td class=\"checksum\">$checksum</td><td>$size bytes</td></tr>" >> "$report_file"
        done < "${HERMETIC_DIR}/checksums/artifacts.txt"
        
        echo "        </table>" >> "$report_file"
        echo "    </div>" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF
    
    <div class="section">
        <h2>Verification Status</h2>
        <p>Build verification: <span class="$([ "$BUILD_VERIFICATION" = true ] && echo "success" || echo "warning")">$([ "$BUILD_VERIFICATION" = true ] && echo "ENABLED" || echo "DISABLED")</span></p>
        <p>Latest verification result: <span id="verification-status">Pending</span></p>
    </div>
    
    <div class="section">
        <h2>Checksum Database</h2>
        <p>Database location: $CHECKSUM_DATABASE</p>
        <p>Total entries: $(grep -c "^[^#]" "$CHECKSUM_DATABASE" 2>/dev/null || echo "0")</p>
    </div>
</body>
</html>
EOF
    
    print_success "Checksum report generated: $report_file"
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            build|verify|checksum|container-build|manifest)
                COMMAND="$1"
                shift
                ;;
            --runtime)
                CONTAINER_RUNTIME="$2"
                shift 2
                ;;
            --image)
                CONTAINER_IMAGE="$2"
                shift 2
                ;;
            --algorithm)
                CHECKSUM_ALGORITHM="$2"
                shift 2
                ;;
            --isolation)
                case "$2" in
                    minimum|standard|maximum)
                        BUILD_ISOLATION_LEVEL="$2"
                        ;;
                    *)
                        print_failure "Invalid isolation level: $2"
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            --no-timestamps)
                REPRODUCIBLE_TIMESTAMPS=false
                shift
                ;;
            --no-deterministic)
                DETERMINISTIC_BUILDS=false
                shift
                ;;
            --no-network-isolation)
                NETWORK_ISOLATION=false
                shift
                ;;
            --no-verification)
                BUILD_VERIFICATION=false
                shift
                ;;
            --seed)
                ENVIRONMENT_SEED="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                print_failure "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Function to execute command
execute_command() {
    case "${COMMAND:-build}" in
        build)
            init_hermetic_environment
            run_hermetic_build
            ;;
        verify)
            init_hermetic_environment
            verify_reproducibility
            ;;
        checksum)
            init_hermetic_environment
            generate_source_checksum
            generate_artifact_checksums
            generate_checksum_report
            ;;
        container-build)
            init_hermetic_environment
            create_container_image
            run_container_build
            ;;
        manifest)
            init_hermetic_environment
            create_environment_snapshot
            update_build_manifest "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "0"
            ;;
        *)
            print_failure "Unknown command: $COMMAND"
            show_usage
            exit 1
            ;;
    esac
}

# Main function
main() {
    print_banner
    
    # Parse arguments
    parse_arguments "$@"
    
    print_status "Hermetic Build Configuration:"
    echo "  Command: ${COMMAND:-build}"
    echo "  Hermetic Enabled: $HERMETIC_ENABLED"
    echo "  Container Runtime: $CONTAINER_RUNTIME"
    echo "  Container Image: $CONTAINER_IMAGE"
    echo "  Checksum Algorithm: $CHECKSUM_ALGORITHM"
    echo "  Isolation Level: $BUILD_ISOLATION_LEVEL"
    echo "  Reproducible Timestamps: $REPRODUCIBLE_TIMESTAMPS"
    echo "  Deterministic Builds: $DETERMINISTIC_BUILDS"
    echo "  Network Isolation: $NETWORK_ISOLATION"
    echo "  Build Verification: $BUILD_VERIFICATION"
    echo ""
    
    # Execute command
    execute_command
}

# Execute main function with all arguments
main "$@"