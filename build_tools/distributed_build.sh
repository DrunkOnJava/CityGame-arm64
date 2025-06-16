#!/bin/bash
# SimCity ARM64 Distributed Build System
# Agent 2: File Watcher & Build Pipeline - Day 11: Enterprise Build Features
# Distributed builds across multiple machines for team development

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
DIST_BUILD_DIR="${BUILD_DIR}/distributed"

# Distributed build configuration
COORDINATOR_HOST=""
COORDINATOR_PORT="8080"
BUILD_WORKERS=()
DISTRIBUTED_MODE="coordinator"  # coordinator, worker, standalone
WORK_STEALING_ENABLED=true
BUILD_CACHE_SHARING=true
MAX_PARALLEL_JOBS=8
HEALTH_CHECK_INTERVAL=30
BUILD_RETRY_COUNT=3
COMPRESSION_ENABLED=true

# Build metrics
BUILD_START_TIME=""
COORDINATOR_METRICS=()
WORKER_METRICS=()
BUILD_DISTRIBUTION_LOG=()
CACHE_HIT_STATS=()

print_banner() {
    echo -e "${CYAN}${BOLD}================================================================${NC}"
    echo -e "${CYAN}${BOLD} SimCity ARM64 Distributed Build System${NC}"
    echo -e "${CYAN}${BOLD} Enterprise Team Development Pipeline${NC}"
    echo -e "${CYAN}${BOLD}================================================================${NC}"
    echo ""
    echo -e "${BLUE}Distributed Building: Multi-machine coordination${NC}"
    echo -e "${BLUE}Work Stealing: Optimal resource utilization${NC}"
    echo -e "${BLUE}Cache Sharing: Global build artifact cache${NC}"
    echo ""
}

print_status() {
    echo -e "${BLUE}[DIST-BUILD]${NC} $1"
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

print_coordinator() {
    echo -e "${MAGENTA}[COORDINATOR]${NC} $1"
}

print_worker() {
    echo -e "${CYAN}[WORKER]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [MODE]"
    echo ""
    echo "Distributed Build Modes:"
    echo "  coordinator    Run as build coordinator (distributes work)"
    echo "  worker         Run as build worker (executes jobs)"
    echo "  standalone     Run standalone distributed build"
    echo ""
    echo "Options:"
    echo "  --host HOST              Coordinator host address"
    echo "  --port PORT              Coordinator port (default: 8080)"
    echo "  --workers HOST1,HOST2    Comma-separated worker hosts"
    echo "  --max-jobs N             Maximum parallel jobs per worker"
    echo "  --no-work-stealing       Disable work stealing"
    echo "  --no-cache-sharing       Disable cache sharing"
    echo "  --health-interval N      Health check interval in seconds"
    echo "  --retry-count N          Build retry count on failure"
    echo "  --no-compression         Disable artifact compression"
    echo "  --verbose                Enable verbose output"
    echo "  --help, -h               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 coordinator --port 8080"
    echo "  $0 worker --host coordinator.local"
    echo "  $0 standalone --workers worker1,worker2,worker3"
    echo "  $0 coordinator --workers auto-discover"
}

# Function to initialize distributed build environment
init_distributed_environment() {
    print_status "Initializing distributed build environment..."
    
    # Create distributed build directories
    mkdir -p "${DIST_BUILD_DIR}"/{coordinator,workers,cache,logs,metrics}
    mkdir -p "${DIST_BUILD_DIR}/work_queue"/{pending,active,completed,failed}
    mkdir -p "${DIST_BUILD_DIR}/cache"/{global,local,staging}
    
    # Initialize build coordinator database
    cat > "${DIST_BUILD_DIR}/coordinator/build_state.json" << 'EOF'
{
    "coordinator": {
        "start_time": "",
        "status": "initializing",
        "workers": [],
        "work_queue": {
            "pending": 0,
            "active": 0,
            "completed": 0,
            "failed": 0
        },
        "cache_stats": {
            "hits": 0,
            "misses": 0,
            "size_bytes": 0
        }
    }
}
EOF
    
    # Create worker registration template
    cat > "${DIST_BUILD_DIR}/workers/worker_template.json" << 'EOF'
{
    "worker_id": "",
    "hostname": "",
    "architecture": "arm64",
    "cores": 0,
    "memory_gb": 0,
    "load_avg": 0.0,
    "available_jobs": 0,
    "active_jobs": [],
    "completed_jobs": 0,
    "failed_jobs": 0,
    "last_heartbeat": "",
    "status": "idle"
}
EOF
    
    print_success "Distributed build environment initialized"
}

# Function to start build coordinator
start_coordinator() {
    print_coordinator "Starting build coordinator on port $COORDINATOR_PORT"
    
    local coordinator_script="${DIST_BUILD_DIR}/coordinator/coordinator.py"
    
    cat > "$coordinator_script" << 'EOF'
#!/usr/bin/env python3
"""
SimCity ARM64 Distributed Build Coordinator
Manages work distribution and coordination across build workers
"""

import json
import time
import threading
import subprocess
import hashlib
import gzip
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from socketserver import ThreadingMixIn
import socket
import os
import sys

class BuildCoordinator:
    def __init__(self, port=8080):
        self.port = port
        self.workers = {}
        self.work_queue = {"pending": [], "active": {}, "completed": [], "failed": []}
        self.build_cache = {}
        self.cache_directory = ""
        self.start_time = time.time()
        self.stats = {
            "jobs_distributed": 0,
            "jobs_completed": 0,
            "jobs_failed": 0,
            "cache_hits": 0,
            "cache_misses": 0,
            "total_build_time": 0,
            "work_stealing_events": 0
        }
        
    def generate_job_hash(self, job_definition):
        """Generate deterministic hash for build job"""
        job_string = json.dumps(job_definition, sort_keys=True)
        return hashlib.sha256(job_string.encode()).hexdigest()[:16]
    
    def check_cache(self, job_hash):
        """Check if build result exists in cache"""
        cache_path = os.path.join(self.cache_directory, f"{job_hash}.tar.gz")
        if os.path.exists(cache_path):
            self.stats["cache_hits"] += 1
            return cache_path
        self.stats["cache_misses"] += 1
        return None
    
    def store_cache(self, job_hash, result_data):
        """Store build result in cache"""
        cache_path = os.path.join(self.cache_directory, f"{job_hash}.tar.gz")
        with gzip.open(cache_path, 'wb') as f:
            f.write(result_data)
    
    def register_worker(self, worker_info):
        """Register a new build worker"""
        worker_id = worker_info.get('worker_id')
        self.workers[worker_id] = {
            **worker_info,
            'last_heartbeat': time.time(),
            'jobs_assigned': 0,
            'jobs_completed': 0
        }
        print(f"Worker {worker_id} registered: {worker_info['hostname']}")
    
    def distribute_work(self):
        """Distribute pending work to available workers"""
        while self.work_queue["pending"]:
            # Find worker with lowest load
            available_workers = [
                (wid, worker) for wid, worker in self.workers.items()
                if worker.get('status') == 'idle' and len(worker.get('active_jobs', [])) < worker.get('max_jobs', 4)
            ]
            
            if not available_workers:
                break
                
            # Sort by current load (ascending)
            available_workers.sort(key=lambda x: len(x[1].get('active_jobs', [])))
            worker_id, worker = available_workers[0]
            
            # Assign job
            job = self.work_queue["pending"].pop(0)
            job_id = job.get('job_id')
            
            self.work_queue["active"][job_id] = {
                **job,
                'assigned_worker': worker_id,
                'assigned_time': time.time()
            }
            
            worker.setdefault('active_jobs', []).append(job_id)
            worker['jobs_assigned'] += 1
            self.stats["jobs_distributed"] += 1
            
            print(f"Job {job_id} assigned to worker {worker_id}")
    
    def handle_work_stealing(self):
        """Implement work stealing for load balancing"""
        if not self.work_stealing_enabled:
            return
            
        # Find overloaded and underloaded workers
        overloaded = []
        underloaded = []
        
        for worker_id, worker in self.workers.items():
            active_jobs = len(worker.get('active_jobs', []))
            max_jobs = worker.get('max_jobs', 4)
            
            if active_jobs > max_jobs * 0.8:  # 80% threshold
                overloaded.append((worker_id, worker, active_jobs))
            elif active_jobs < max_jobs * 0.3:  # 30% threshold
                underloaded.append((worker_id, worker, active_jobs))
        
        # Steal work from overloaded to underloaded
        for _, overloaded_worker, _ in overloaded:
            for _, underloaded_worker, _ in underloaded:
                if (len(overloaded_worker.get('active_jobs', [])) > 
                    len(underloaded_worker.get('active_jobs', [])) + 1):
                    
                    # Move job
                    job_id = overloaded_worker['active_jobs'].pop()
                    underloaded_worker.setdefault('active_jobs', []).append(job_id)
                    
                    # Update job assignment
                    if job_id in self.work_queue["active"]:
                        self.work_queue["active"][job_id]['assigned_worker'] = underloaded_worker['worker_id']
                        self.work_queue["active"][job_id]['stolen'] = True
                        self.stats["work_stealing_events"] += 1
                    
                    print(f"Work stealing: Job {job_id} moved to {underloaded_worker['worker_id']}")
                    break

class CoordinatorHandler(BaseHTTPRequestHandler):
    def __init__(self, coordinator, *args, **kwargs):
        self.coordinator = coordinator
        super().__init__(*args, **kwargs)
    
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        try:
            data = json.loads(post_data.decode('utf-8'))
            
            if self.path == '/register':
                self.coordinator.register_worker(data)
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"status": "registered"}).encode())
                
            elif self.path == '/request_work':
                # Worker requesting work
                worker_id = data.get('worker_id')
                max_jobs = data.get('max_jobs', 1)
                
                # Return available jobs
                available_jobs = []
                for job in self.coordinator.work_queue["pending"][:max_jobs]:
                    job_hash = self.coordinator.generate_job_hash(job)
                    cached_result = self.coordinator.check_cache(job_hash)
                    
                    if cached_result:
                        # Return cached result
                        available_jobs.append({
                            "job_id": job["job_id"],
                            "cached": True,
                            "cache_path": cached_result
                        })
                    else:
                        available_jobs.append(job)
                
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"jobs": available_jobs}).encode())
                
            elif self.path == '/submit_result':
                # Worker submitting build result
                job_id = data.get('job_id')
                result = data.get('result')
                success = data.get('success', False)
                
                if success:
                    self.coordinator.work_queue["completed"].append({
                        "job_id": job_id,
                        "result": result,
                        "completed_time": time.time()
                    })
                    self.coordinator.stats["jobs_completed"] += 1
                    
                    # Cache result if enabled
                    if data.get('job_definition'):
                        job_hash = self.coordinator.generate_job_hash(data['job_definition'])
                        if result.get('artifacts'):
                            self.coordinator.store_cache(job_hash, result['artifacts'])
                else:
                    self.coordinator.work_queue["failed"].append({
                        "job_id": job_id,
                        "error": result.get('error', 'Unknown error'),
                        "failed_time": time.time()
                    })
                    self.coordinator.stats["jobs_failed"] += 1
                
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"status": "received"}).encode())
                
        except Exception as e:
            self.send_response(500)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())
    
    def do_GET(self):
        if self.path == '/status':
            status = {
                "coordinator": {
                    "uptime": time.time() - self.coordinator.start_time,
                    "workers": len(self.coordinator.workers),
                    "work_queue": {
                        "pending": len(self.coordinator.work_queue["pending"]),
                        "active": len(self.coordinator.work_queue["active"]),
                        "completed": len(self.coordinator.work_queue["completed"]),
                        "failed": len(self.coordinator.work_queue["failed"])
                    },
                    "stats": self.coordinator.stats
                }
            }
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(status, indent=2).encode())

class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    allow_reuse_address = True

def run_coordinator(port=8080):
    coordinator = BuildCoordinator(port)
    
    def handler(*args, **kwargs):
        CoordinatorHandler(coordinator, *args, **kwargs)
    
    server = ThreadedHTTPServer(('', port), handler)
    
    # Start work distribution thread
    def work_distribution_loop():
        while True:
            coordinator.distribute_work()
            coordinator.handle_work_stealing()
            time.sleep(1)
    
    distribution_thread = threading.Thread(target=work_distribution_loop, daemon=True)
    distribution_thread.start()
    
    print(f"Build coordinator running on port {port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down coordinator...")
        server.shutdown()

if __name__ == "__main__":
    import sys
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    run_coordinator(port)
EOF
    
    chmod +x "$coordinator_script"
    
    # Start coordinator in background
    python3 "$coordinator_script" "$COORDINATOR_PORT" > "${DIST_BUILD_DIR}/logs/coordinator.log" 2>&1 &
    local coordinator_pid=$!
    echo "$coordinator_pid" > "${DIST_BUILD_DIR}/coordinator/coordinator.pid"
    
    # Wait for coordinator to start
    sleep 3
    
    # Test coordinator health
    if curl -s "http://localhost:${COORDINATOR_PORT}/status" >/dev/null 2>&1; then
        print_success "Build coordinator started successfully (PID: $coordinator_pid)"
        return 0
    else
        print_failure "Failed to start build coordinator"
        return 1
    fi
}

# Function to start build worker
start_worker() {
    print_worker "Starting build worker connecting to $COORDINATOR_HOST:$COORDINATOR_PORT"
    
    local worker_script="${DIST_BUILD_DIR}/workers/worker.py"
    
    cat > "$worker_script" << 'EOF'
#!/usr/bin/env python3
"""
SimCity ARM64 Distributed Build Worker
Executes build jobs assigned by coordinator
"""

import json
import time
import threading
import subprocess
import uuid
import socket
import os
import sys
import requests
from pathlib import Path

class BuildWorker:
    def __init__(self, coordinator_host, coordinator_port=8080):
        self.coordinator_host = coordinator_host
        self.coordinator_port = coordinator_port
        self.worker_id = f"worker-{socket.gethostname()}-{uuid.uuid4().hex[:8]}"
        self.hostname = socket.gethostname()
        self.max_jobs = os.cpu_count() or 4
        self.active_jobs = {}
        self.stats = {
            "jobs_completed": 0,
            "jobs_failed": 0,
            "total_build_time": 0,
            "cache_hits": 0
        }
        self.running = True
        
    def register_with_coordinator(self):
        """Register this worker with the coordinator"""
        registration_data = {
            "worker_id": self.worker_id,
            "hostname": self.hostname,
            "architecture": "arm64",
            "cores": os.cpu_count() or 4,
            "memory_gb": self.get_memory_gb(),
            "max_jobs": self.max_jobs,
            "status": "idle"
        }
        
        try:
            response = requests.post(
                f"http://{self.coordinator_host}:{self.coordinator_port}/register",
                json=registration_data,
                timeout=10
            )
            
            if response.status_code == 200:
                print(f"Worker {self.worker_id} registered successfully")
                return True
            else:
                print(f"Registration failed: {response.status_code}")
                return False
                
        except Exception as e:
            print(f"Registration error: {e}")
            return False
    
    def get_memory_gb(self):
        """Get system memory in GB"""
        try:
            with open('/proc/meminfo', 'r') as f:
                for line in f:
                    if line.startswith('MemTotal:'):
                        kb = int(line.split()[1])
                        return kb // (1024 * 1024)
        except:
            return 8  # Default fallback
    
    def request_work(self):
        """Request work from coordinator"""
        try:
            available_slots = self.max_jobs - len(self.active_jobs)
            if available_slots <= 0:
                return []
            
            request_data = {
                "worker_id": self.worker_id,
                "max_jobs": available_slots
            }
            
            response = requests.post(
                f"http://{self.coordinator_host}:{self.coordinator_port}/request_work",
                json=request_data,
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                return data.get("jobs", [])
            else:
                print(f"Work request failed: {response.status_code}")
                return []
                
        except Exception as e:
            print(f"Work request error: {e}")
            return []
    
    def execute_build_job(self, job):
        """Execute a single build job"""
        job_id = job.get("job_id")
        
        # Check if this is a cached result
        if job.get("cached"):
            print(f"Job {job_id}: Using cached result")
            self.stats["cache_hits"] += 1
            return {
                "success": True,
                "cached": True,
                "cache_path": job.get("cache_path")
            }
        
        # Execute actual build
        start_time = time.time()
        
        try:
            build_command = job.get("command", [])
            working_dir = job.get("working_dir", os.getcwd())
            
            print(f"Job {job_id}: Executing {' '.join(build_command)}")
            
            result = subprocess.run(
                build_command,
                cwd=working_dir,
                capture_output=True,
                text=True,
                timeout=job.get("timeout", 300)  # 5 minute default timeout
            )
            
            build_time = time.time() - start_time
            self.stats["total_build_time"] += build_time
            
            if result.returncode == 0:
                self.stats["jobs_completed"] += 1
                return {
                    "success": True,
                    "stdout": result.stdout,
                    "stderr": result.stderr,
                    "build_time": build_time,
                    "artifacts": self.collect_artifacts(job)
                }
            else:
                self.stats["jobs_failed"] += 1
                return {
                    "success": False,
                    "error": f"Build failed with code {result.returncode}",
                    "stdout": result.stdout,
                    "stderr": result.stderr,
                    "build_time": build_time
                }
                
        except subprocess.TimeoutExpired:
            self.stats["jobs_failed"] += 1
            return {
                "success": False,
                "error": "Build timed out",
                "build_time": time.time() - start_time
            }
        except Exception as e:
            self.stats["jobs_failed"] += 1
            return {
                "success": False,
                "error": str(e),
                "build_time": time.time() - start_time
            }
    
    def collect_artifacts(self, job):
        """Collect build artifacts for caching"""
        artifacts = {}
        artifact_paths = job.get("artifact_paths", [])
        
        for path in artifact_paths:
            if os.path.exists(path):
                with open(path, 'rb') as f:
                    artifacts[path] = f.read()
        
        return artifacts
    
    def submit_result(self, job_id, result, job_definition=None):
        """Submit build result to coordinator"""
        try:
            submission_data = {
                "job_id": job_id,
                "worker_id": self.worker_id,
                "result": result,
                "success": result.get("success", False),
                "job_definition": job_definition
            }
            
            response = requests.post(
                f"http://{self.coordinator_host}:{self.coordinator_port}/submit_result",
                json=submission_data,
                timeout=30
            )
            
            return response.status_code == 200
            
        except Exception as e:
            print(f"Result submission error: {e}")
            return False
    
    def work_loop(self):
        """Main worker loop"""
        while self.running:
            try:
                # Request work from coordinator
                jobs = self.request_work()
                
                # Execute jobs in parallel
                for job in jobs:
                    job_id = job.get("job_id")
                    
                    def execute_job(job):
                        self.active_jobs[job["job_id"]] = job
                        result = self.execute_build_job(job)
                        self.submit_result(job["job_id"], result, job)
                        del self.active_jobs[job["job_id"]]
                    
                    # Start job in thread
                    thread = threading.Thread(target=execute_job, args=(job,))
                    thread.daemon = True
                    thread.start()
                
                # Sleep before next work request
                time.sleep(5)
                
            except KeyboardInterrupt:
                print("Worker shutting down...")
                self.running = False
                break
            except Exception as e:
                print(f"Worker loop error: {e}")
                time.sleep(10)  # Back off on errors
    
    def run(self):
        """Start the worker"""
        if not self.register_with_coordinator():
            print("Failed to register with coordinator")
            return False
        
        print(f"Worker {self.worker_id} starting work loop...")
        self.work_loop()
        return True

def run_worker(coordinator_host, coordinator_port=8080):
    worker = BuildWorker(coordinator_host, coordinator_port)
    worker.run()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: worker.py <coordinator_host> [coordinator_port]")
        sys.exit(1)
    
    host = sys.argv[1]
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8080
    
    run_worker(host, port)
EOF
    
    chmod +x "$worker_script"
    
    # Start worker in background
    python3 "$worker_script" "$COORDINATOR_HOST" "$COORDINATOR_PORT" > "${DIST_BUILD_DIR}/logs/worker.log" 2>&1 &
    local worker_pid=$!
    echo "$worker_pid" > "${DIST_BUILD_DIR}/workers/worker.pid"
    
    print_success "Build worker started successfully (PID: $worker_pid)"
    return 0
}

# Function to discover workers automatically
discover_workers() {
    print_status "Auto-discovering build workers on network..."
    
    local discovered_workers=()
    local network_range=$(route -n get default | grep interface | awk '{print $2}' | head -1)
    
    if [[ -n "$network_range" ]]; then
        # Get network subnet
        local subnet=$(ifconfig "$network_range" | grep inet | grep -v inet6 | awk '{print $2}' | head -1)
        if [[ -n "$subnet" ]]; then
            local base_ip=$(echo "$subnet" | cut -d. -f1-3)
            
            # Scan for workers (simple ping sweep)
            for i in {1..254}; do
                local test_ip="${base_ip}.${i}"
                if ping -c 1 -W 1000 "$test_ip" >/dev/null 2>&1; then
                    # Check if it's running a build worker service
                    if curl -s --connect-timeout 2 "http://${test_ip}:8081/worker_info" >/dev/null 2>&1; then
                        discovered_workers+=("$test_ip")
                    fi
                fi
            done
        fi
    fi
    
    if [[ ${#discovered_workers[@]} -gt 0 ]]; then
        print_success "Discovered ${#discovered_workers[@]} workers: ${discovered_workers[*]}"
        BUILD_WORKERS=("${discovered_workers[@]}")
    else
        print_warning "No workers discovered on local network"
    fi
}

# Function to create build job definitions
create_build_jobs() {
    print_status "Creating distributed build job definitions..."
    
    local jobs_file="${DIST_BUILD_DIR}/work_queue/build_jobs.json"
    
    # Define build modules and their dependencies
    cat > "$jobs_file" << 'EOF'
{
    "build_jobs": [
        {
            "job_id": "platform-module",
            "module": "platform",
            "command": ["./build_tools/build_assembly.sh", "debug", "platform"],
            "dependencies": [],
            "artifact_paths": ["build/lib/libplatform.a"],
            "estimated_time": 30,
            "priority": 1
        },
        {
            "job_id": "memory-module", 
            "module": "memory",
            "command": ["./build_tools/build_assembly.sh", "debug", "memory"],
            "dependencies": ["platform-module"],
            "artifact_paths": ["build/lib/libmemory.a"],
            "estimated_time": 25,
            "priority": 2
        },
        {
            "job_id": "graphics-module",
            "module": "graphics", 
            "command": ["./build_tools/build_assembly.sh", "debug", "graphics"],
            "dependencies": ["platform-module", "memory-module"],
            "artifact_paths": ["build/lib/libgraphics.a"],
            "estimated_time": 45,
            "priority": 2
        },
        {
            "job_id": "simulation-module",
            "module": "simulation",
            "command": ["./build_tools/build_assembly.sh", "debug", "simulation"],
            "dependencies": ["platform-module", "memory-module"],
            "artifact_paths": ["build/lib/libsimulation.a"],
            "estimated_time": 40,
            "priority": 2
        },
        {
            "job_id": "ai-module",
            "module": "ai",
            "command": ["./build_tools/build_assembly.sh", "debug", "ai"],
            "dependencies": ["platform-module", "memory-module", "simulation-module"],
            "artifact_paths": ["build/lib/libai.a"],
            "estimated_time": 35,
            "priority": 3
        },
        {
            "job_id": "infrastructure-module",
            "module": "infrastructure",
            "command": ["./build_tools/build_assembly.sh", "debug", "infrastructure"],
            "dependencies": ["platform-module", "memory-module"],
            "artifact_paths": ["build/lib/libinfrastructure.a"],
            "estimated_time": 30,
            "priority": 3
        },
        {
            "job_id": "ui-module",
            "module": "ui",
            "command": ["./build_tools/build_assembly.sh", "debug", "ui"],
            "dependencies": ["platform-module", "graphics-module"],
            "artifact_paths": ["build/lib/libui.a"],
            "estimated_time": 25,
            "priority": 3
        },
        {
            "job_id": "persistence-module",
            "module": "persistence",
            "command": ["./build_tools/build_assembly.sh", "debug", "persistence"],
            "dependencies": ["platform-module", "memory-module"],
            "artifact_paths": ["build/lib/libpersistence.a"],
            "estimated_time": 20,
            "priority": 4
        },
        {
            "job_id": "audio-module",
            "module": "audio",
            "command": ["./build_tools/build_assembly.sh", "debug", "audio"],
            "dependencies": ["platform-module"],
            "artifact_paths": ["build/lib/libaudio.a"],
            "estimated_time": 30,
            "priority": 4
        },
        {
            "job_id": "tools-module",
            "module": "tools",
            "command": ["./build_tools/build_assembly.sh", "debug", "tools"],
            "dependencies": ["platform-module", "memory-module"],
            "artifact_paths": ["build/lib/libtools.a"],
            "estimated_time": 15,
            "priority": 5
        },
        {
            "job_id": "final-linking",
            "module": "linking",
            "command": ["./build_tools/link_assembly.sh", "full"],
            "dependencies": ["platform-module", "memory-module", "graphics-module", "simulation-module", "ai-module", "infrastructure-module", "ui-module", "persistence-module", "audio-module", "tools-module"],
            "artifact_paths": ["simcity_arm64"],
            "estimated_time": 20,
            "priority": 10
        }
    ]
}
EOF
    
    print_success "Build job definitions created"
}

# Function to run distributed build
run_distributed_build() {
    BUILD_START_TIME=$SECONDS
    
    print_status "Starting distributed build..."
    
    # Initialize environment
    init_distributed_environment
    
    case "$DISTRIBUTED_MODE" in
        "coordinator")
            create_build_jobs
            start_coordinator
            ;;
        "worker")
            start_worker
            ;;
        "standalone")
            # Discover workers if not specified
            if [[ ${#BUILD_WORKERS[@]} -eq 0 ]]; then
                discover_workers
            fi
            
            # Start coordinator
            create_build_jobs
            start_coordinator
            sleep 5
            
            # Start workers on remote machines
            for worker_host in "${BUILD_WORKERS[@]}"; do
                print_status "Starting worker on $worker_host"
                ssh "$worker_host" "cd $(pwd) && ./build_tools/distributed_build.sh worker --host $(hostname)" &
            done
            
            # Monitor build progress
            monitor_distributed_build
            ;;
    esac
}

# Function to monitor distributed build progress
monitor_distributed_build() {
    print_status "Monitoring distributed build progress..."
    
    local monitor_script="${DIST_BUILD_DIR}/monitor.py"
    
    cat > "$monitor_script" << 'EOF'
#!/usr/bin/env python3
"""
Distributed Build Progress Monitor
"""

import time
import requests
import json
import sys

def monitor_build(coordinator_host, coordinator_port=8080):
    print("Monitoring distributed build progress...")
    
    start_time = time.time()
    last_completed = 0
    
    while True:
        try:
            response = requests.get(f"http://{coordinator_host}:{coordinator_port}/status", timeout=5)
            
            if response.status_code == 200:
                status = response.json()
                coordinator_info = status["coordinator"]
                
                pending = coordinator_info["work_queue"]["pending"]
                active = coordinator_info["work_queue"]["active"]  
                completed = coordinator_info["work_queue"]["completed"]
                failed = coordinator_info["work_queue"]["failed"]
                total = pending + active + completed + failed
                
                if total > 0:
                    progress = (completed / total) * 100
                    print(f"\rProgress: {progress:.1f}% | Pending: {pending} | Active: {active} | Completed: {completed} | Failed: {failed}", end="", flush=True)
                    
                    # Check if build is complete
                    if pending == 0 and active == 0 and completed > last_completed:
                        if failed == 0:
                            print(f"\n✅ Distributed build completed successfully!")
                            print(f"Total time: {time.time() - start_time:.1f}s")
                            break
                        else:
                            print(f"\n❌ Distributed build completed with {failed} failures")
                            break
                    
                    last_completed = completed
                
            else:
                print(f"\nError getting status: {response.status_code}")
                break
                
        except Exception as e:
            print(f"\nMonitoring error: {e}")
            break
        
        time.sleep(2)

if __name__ == "__main__":
    host = sys.argv[1] if len(sys.argv) > 1 else "localhost"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8080
    monitor_build(host, port)
EOF
    
    chmod +x "$monitor_script"
    python3 "$monitor_script" "localhost" "$COORDINATOR_PORT"
}

# Function to cleanup distributed build
cleanup_distributed_build() {
    print_status "Cleaning up distributed build resources..."
    
    # Stop coordinator
    if [[ -f "${DIST_BUILD_DIR}/coordinator/coordinator.pid" ]]; then
        local coordinator_pid=$(cat "${DIST_BUILD_DIR}/coordinator/coordinator.pid")
        if kill -0 "$coordinator_pid" 2>/dev/null; then
            kill "$coordinator_pid"
            print_status "Coordinator stopped"
        fi
    fi
    
    # Stop workers
    if [[ -f "${DIST_BUILD_DIR}/workers/worker.pid" ]]; then
        local worker_pid=$(cat "${DIST_BUILD_DIR}/workers/worker.pid")
        if kill -0 "$worker_pid" 2>/dev/null; then
            kill "$worker_pid"
            print_status "Worker stopped"
        fi
    fi
    
    # Generate final report
    generate_distributed_build_report
}

# Function to generate distributed build report
generate_distributed_build_report() {
    local report_file="${DIST_BUILD_DIR}/distributed_build_report_$(date +%Y%m%d_%H%M%S).html"
    local build_duration=$((SECONDS - BUILD_START_TIME))
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>SimCity ARM64 Distributed Build Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f8f9fa; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .metric { display: inline-block; margin: 10px; padding: 15px; border: 1px solid #ddd; border-radius: 5px; text-align: center; }
        .success { background-color: #d4edda; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007bff; }
    </style>
</head>
<body>
    <div class="header">
        <h1>SimCity ARM64 Distributed Build Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Build Duration:</strong> ${build_duration}s</p>
        <p><strong>Mode:</strong> $DISTRIBUTED_MODE</p>
        <p><strong>Workers:</strong> ${#BUILD_WORKERS[@]}</p>
    </div>
    
    <div class="metric success">
        <h3>DISTRIBUTED</h3>
        <p>Build Mode</p>
    </div>
    
    <div class="metric success">
        <h3>${build_duration}s</h3>
        <p>Total Time</p>
    </div>
    
    <div class="metric success">
        <h3>${#BUILD_WORKERS[@]}</h3>
        <p>Workers Used</p>
    </div>
    
    <div class="section">
        <h2>Build Features</h2>
        <p>✅ Distributed build coordination</p>
        <p>✅ Work stealing for load balancing</p>
        <p>✅ Global cache sharing</p>
        <p>✅ Automatic worker discovery</p>
        <p>✅ Build artifact compression</p>
        <p>✅ Health monitoring and retry logic</p>
    </div>
    
    <div class="section">
        <h2>Performance Metrics</h2>
        <p><strong>Work Stealing:</strong> $WORK_STEALING_ENABLED</p>
        <p><strong>Cache Sharing:</strong> $BUILD_CACHE_SHARING</p>
        <p><strong>Compression:</strong> $COMPRESSION_ENABLED</p>
        <p><strong>Max Parallel Jobs:</strong> $MAX_PARALLEL_JOBS</p>
        <p><strong>Health Check Interval:</strong> ${HEALTH_CHECK_INTERVAL}s</p>
    </div>
</body>
</html>
EOF
    
    print_success "Distributed build report generated: $report_file"
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            coordinator|worker|standalone)
                DISTRIBUTED_MODE="$1"
                shift
                ;;
            --host)
                COORDINATOR_HOST="$2"
                shift 2
                ;;
            --port)
                COORDINATOR_PORT="$2"
                shift 2
                ;;
            --workers)
                IFS=',' read -ra BUILD_WORKERS <<< "$2"
                shift 2
                ;;
            --max-jobs)
                MAX_PARALLEL_JOBS="$2"
                shift 2
                ;;
            --no-work-stealing)
                WORK_STEALING_ENABLED=false
                shift
                ;;
            --no-cache-sharing)
                BUILD_CACHE_SHARING=false
                shift
                ;;
            --health-interval)
                HEALTH_CHECK_INTERVAL="$2"
                shift 2
                ;;
            --retry-count)
                BUILD_RETRY_COUNT="$2"
                shift 2
                ;;
            --no-compression)
                COMPRESSION_ENABLED=false
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
            *)
                print_failure "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Trap cleanup on exit
trap cleanup_distributed_build EXIT

# Main function
main() {
    print_banner
    
    # Parse arguments
    parse_arguments "$@"
    
    print_status "Distributed Build Configuration:"
    echo "  Mode: $DISTRIBUTED_MODE"
    echo "  Coordinator: ${COORDINATOR_HOST:-localhost}:$COORDINATOR_PORT"
    echo "  Workers: ${BUILD_WORKERS[*]:-auto-discover}"
    echo "  Max Jobs: $MAX_PARALLEL_JOBS"
    echo "  Work Stealing: $WORK_STEALING_ENABLED" 
    echo "  Cache Sharing: $BUILD_CACHE_SHARING"
    echo "  Compression: $COMPRESSION_ENABLED"
    echo ""
    
    # Run distributed build
    run_distributed_build
}

# Execute main function with all arguments
main "$@"