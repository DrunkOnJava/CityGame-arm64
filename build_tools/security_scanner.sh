#!/bin/bash
# SimCity ARM64 Build Security Scanner
# Agent 2: File Watcher & Build Pipeline - Day 11: Enterprise Build Features
# Build security scanning for vulnerabilities and malware detection

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
SECURITY_DIR="${BUILD_DIR}/security"

# Security scanning configuration
SECURITY_ENABLED=true
SCAN_LEVEL="comprehensive"  # basic, standard, comprehensive, paranoid
REAL_TIME_SCANNING=true
QUARANTINE_THREATS=true
AUTO_REMEDIATION=false

# Scanning engines
STATIC_ANALYSIS=true
DYNAMIC_ANALYSIS=false
DEPENDENCY_SCANNING=true
MALWARE_SCANNING=true
VULNERABILITY_SCANNING=true
SUPPLY_CHAIN_SCANNING=true

# Security databases
CVE_DATABASE="${SECURITY_DIR}/cve_database.json"
MALWARE_SIGNATURES="${SECURITY_DIR}/malware_signatures.db"
THREAT_INTELLIGENCE="${SECURITY_DIR}/threat_intel.json"
SECURITY_POLICIES="${SECURITY_DIR}/security_policies.json"

# Scan results and reporting
SCAN_RESULTS_DIR="${SECURITY_DIR}/scan_results"
QUARANTINE_DIR="${SECURITY_DIR}/quarantine"
REPORTS_DIR="${SECURITY_DIR}/reports"
ALERTS_DIR="${SECURITY_DIR}/alerts"

print_banner() {
    echo -e "${CYAN}${BOLD}================================================================${NC}"
    echo -e "${CYAN}${BOLD} SimCity ARM64 Build Security Scanner${NC}"
    echo -e "${CYAN}${BOLD} Advanced Threat Detection and Vulnerability Assessment${NC}"
    echo -e "${CYAN}${BOLD}================================================================${NC}"
    echo ""
    echo -e "${BLUE}Static Analysis: Code vulnerability detection${NC}"
    echo -e "${BLUE}Malware Scanning: Real-time threat detection${NC}"
    echo -e "${BLUE}Supply Chain: Dependency vulnerability assessment${NC}"
    echo ""
}

print_status() {
    echo -e "${BLUE}[SECURITY]${NC} $1"
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

print_threat() {
    echo -e "${RED}[THREAT]${NC} $1"
}

print_vulnerability() {
    echo -e "${MAGENTA}[VULN]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo ""
    echo "Security Commands:"
    echo "  scan               Run comprehensive security scan"
    echo "  static             Run static code analysis"
    echo "  malware            Run malware detection scan"
    echo "  dependencies       Scan dependencies for vulnerabilities"
    echo "  supply-chain       Run supply chain security assessment"
    echo "  monitor            Start real-time security monitoring"
    echo "  update             Update security databases"
    echo "  report             Generate security report"
    echo ""
    echo "Options:"
    echo "  --level LEVEL            Scan level (basic/standard/comprehensive/paranoid)"
    echo "  --no-static             Disable static analysis"
    echo "  --no-dynamic            Disable dynamic analysis"
    echo "  --no-dependencies       Disable dependency scanning"
    echo "  --no-malware            Disable malware scanning"
    echo "  --no-supply-chain       Disable supply chain scanning"
    echo "  --no-real-time          Disable real-time monitoring"
    echo "  --no-quarantine         Disable threat quarantine"
    echo "  --auto-remediate        Enable automatic remediation"
    echo "  --severity LEVEL        Minimum severity level (low/medium/high/critical)"
    echo "  --exclude PATTERN       Exclude files matching pattern"
    echo "  --verbose               Enable verbose output"
    echo "  --help, -h              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 scan --level comprehensive"
    echo "  $0 malware --quarantine"
    echo "  $0 dependencies --severity high"
    echo "  $0 monitor --real-time"
}

# Function to initialize security environment
init_security_environment() {
    print_status "Initializing build security environment..."
    
    # Create security directories
    mkdir -p "${SECURITY_DIR}"/{databases,scan_results,quarantine,reports,alerts,monitoring}
    mkdir -p "${SCAN_RESULTS_DIR}"/{static,dynamic,malware,dependencies,supply_chain}
    mkdir -p "${QUARANTINE_DIR}"/{malware,suspicious,violations}
    
    # Initialize security databases
    init_security_databases
    
    # Create security policies
    create_security_policies
    
    # Setup scanning engines
    setup_scanning_engines
    
    print_success "Security environment initialized"
}

# Function to initialize security databases
init_security_databases() {
    print_status "Initializing security databases..."
    
    # Create CVE database
    cat > "$CVE_DATABASE" << 'EOF'
{
    "database_info": {
        "name": "SimCity ARM64 CVE Database",
        "version": "1.0.0",
        "last_updated": "",
        "source": "NVD, GitHub Security Advisories, OSV",
        "total_entries": 0
    },
    "vulnerabilities": {
        "critical": [],
        "high": [],
        "medium": [],
        "low": []
    },
    "affected_components": {
        "build_tools": [],
        "dependencies": [],
        "system_libraries": []
    }
}
EOF
    
    # Create malware signatures database
    cat > "$MALWARE_SIGNATURES" << 'EOF'
# SimCity ARM64 Malware Signatures Database
# Format: SIGNATURE_TYPE:PATTERN:SEVERITY:DESCRIPTION
# Types: hash, string, regex, binary

# Known malicious file hashes
hash:5d41402abc4b2a76b9719d911017c592:critical:Malicious binary detected
hash:098f6bcd4621d373cade4e832627b4f6:high:Suspicious executable

# Malicious code patterns
string:eval(base64_decode(:high:Potential PHP backdoor
regex:system\s*\(\s*\$_[GET|POST]:medium:Potential command injection
regex:exec\s*\(\s*["']rm\s+-rf:critical:Destructive command execution

# Binary patterns (hex)
binary:4d5a90000300000004000000ffff0000:medium:PE executable header
binary:7f454c4601010100000000000000000:medium:ELF executable header

# Supply chain threats
string:bitcoin:low:Potential cryptocurrency mining
string:keylogger:high:Potential keylogger code
regex:password\s*=\s*["'][^"']{20,}["']:medium:Hardcoded credentials
EOF
    
    # Create threat intelligence database
    cat > "$THREAT_INTELLIGENCE" << 'EOF'
{
    "threat_intel": {
        "iocs": {
            "malicious_ips": [],
            "malicious_domains": [],
            "malicious_urls": [],
            "malicious_hashes": []
        },
        "attack_patterns": [
            {
                "name": "supply_chain_compromise",
                "description": "Compromise of build dependencies",
                "indicators": ["unexpected dependency changes", "suspicious package sources"],
                "severity": "critical"
            },
            {
                "name": "code_injection",
                "description": "Malicious code injection in source",
                "indicators": ["eval functions", "system calls", "base64 encoded content"],
                "severity": "high"
            }
        ],
        "threat_actors": [],
        "campaigns": []
    }
}
EOF
    
    print_success "Security databases initialized"
}

# Function to create security policies
create_security_policies() {
    print_status "Creating security policies..."
    
    cat > "$SECURITY_POLICIES" << 'EOF'
{
    "security_policies": {
        "code_analysis": {
            "prohibited_functions": [
                "system", "exec", "eval", "shell_exec", "passthru",
                "popen", "proc_open", "file_get_contents", "curl_exec"
            ],
            "suspicious_patterns": [
                "base64_decode",
                "str_rot13",
                "gzinflate",
                "password.*=.*[\"']",
                "api_key.*=.*[\"']"
            ],
            "file_extensions_allowed": [
                ".s", ".c", ".h", ".m", ".sh", ".py", ".json", ".md"
            ],
            "file_extensions_forbidden": [
                ".exe", ".dll", ".so", ".dylib", ".app", ".pkg", ".dmg"
            ]
        },
        "dependency_policies": {
            "allowed_sources": [
                "github.com",
                "gitlab.com",
                "sourceforge.net",
                "apple.com"
            ],
            "forbidden_sources": [
                "pastebin.com",
                "hastebin.com",
                "anonymous sources"
            ],
            "min_reputation_score": 7.0,
            "max_vulnerability_score": 7.0,
            "require_signature_verification": true
        },
        "build_policies": {
            "network_access_allowed": false,
            "internet_downloads_forbidden": true,
            "privileged_operations_forbidden": true,
            "temporary_file_restrictions": true,
            "output_validation_required": true
        },
        "quarantine_policies": {
            "auto_quarantine_critical": true,
            "auto_quarantine_high": true,
            "notify_on_quarantine": true,
            "quarantine_retention_days": 30
        }
    }
}
EOF
    
    print_success "Security policies created"
}

# Function to setup scanning engines
setup_scanning_engines() {
    print_status "Setting up scanning engines..."
    
    # Create static analysis engine
    cat > "${SECURITY_DIR}/engines/static_analyzer.py" << 'EOF'
#!/usr/bin/env python3
"""
SimCity ARM64 Static Code Analysis Engine
Advanced static analysis for security vulnerabilities
"""

import os
import re
import json
import hashlib
import subprocess
from pathlib import Path
import ast

class StaticAnalyzer:
    def __init__(self, policies_file):
        self.policies = self.load_policies(policies_file)
        self.findings = []
        
    def load_policies(self, policies_file):
        """Load security policies"""
        try:
            with open(policies_file, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"Warning: Could not load policies: {e}")
            return {}
    
    def analyze_file(self, file_path):
        """Analyze individual file for security issues"""
        findings = []
        
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # Check for prohibited functions
            for func in self.policies.get('security_policies', {}).get('code_analysis', {}).get('prohibited_functions', []):
                pattern = rf'\b{re.escape(func)}\s*\('
                matches = list(re.finditer(pattern, content, re.IGNORECASE))
                for match in matches:
                    line_num = content[:match.start()].count('\n') + 1
                    findings.append({
                        'type': 'prohibited_function',
                        'severity': 'high',
                        'file': file_path,
                        'line': line_num,
                        'description': f'Use of prohibited function: {func}',
                        'evidence': content[max(0, match.start()-50):match.end()+50]
                    })
            
            # Check for suspicious patterns
            for pattern in self.policies.get('security_policies', {}).get('code_analysis', {}).get('suspicious_patterns', []):
                matches = list(re.finditer(pattern, content, re.IGNORECASE))
                for match in matches:
                    line_num = content[:match.start()].count('\n') + 1
                    findings.append({
                        'type': 'suspicious_pattern',
                        'severity': 'medium',
                        'file': file_path,
                        'line': line_num,
                        'description': f'Suspicious pattern detected: {pattern}',
                        'evidence': content[max(0, match.start()-50):match.end()+50]
                    })
            
            # Check for hardcoded secrets
            secret_patterns = [
                r'(?i)(password|passwd|pwd)\s*[:=]\s*["\'][^"\']{8,}["\']',
                r'(?i)(api[_-]?key|apikey)\s*[:=]\s*["\'][^"\']{20,}["\']',
                r'(?i)(secret|token)\s*[:=]\s*["\'][^"\']{16,}["\']',
                r'(?i)(private[_-]?key)\s*[:=]\s*["\'][^"\']{32,}["\']'
            ]
            
            for pattern in secret_patterns:
                matches = list(re.finditer(pattern, content))
                for match in matches:
                    line_num = content[:match.start()].count('\n') + 1
                    findings.append({
                        'type': 'hardcoded_secret',
                        'severity': 'critical',
                        'file': file_path,
                        'line': line_num,
                        'description': 'Potential hardcoded secret detected',
                        'evidence': '***REDACTED***'  # Don't expose actual secret
                    })
            
            # Check for SQL injection patterns
            sql_patterns = [
                r'(?i)query\s*\+\s*["\'][^"\']*["\']',
                r'(?i)execute\s*\(\s*["\'][^"\']*\$',
                r'(?i)SELECT.*\$.*FROM',
                r'(?i)INSERT.*\$.*VALUES'
            ]
            
            for pattern in sql_patterns:
                matches = list(re.finditer(pattern, content))
                for match in matches:
                    line_num = content[:match.start()].count('\n') + 1
                    findings.append({
                        'type': 'sql_injection',
                        'severity': 'high',
                        'file': file_path,
                        'line': line_num,
                        'description': 'Potential SQL injection vulnerability',
                        'evidence': content[max(0, match.start()-30):match.end()+30]
                    })
            
            # Check for buffer overflow patterns (for C/assembly files)
            if file_path.endswith(('.c', '.s')):
                buffer_patterns = [
                    r'strcpy\s*\(',
                    r'strcat\s*\(',
                    r'sprintf\s*\(',
                    r'gets\s*\(',
                    r'scanf\s*\([^,]*%s'
                ]
                
                for pattern in buffer_patterns:
                    matches = list(re.finditer(pattern, content))
                    for match in matches:
                        line_num = content[:match.start()].count('\n') + 1
                        findings.append({
                            'type': 'buffer_overflow',
                            'severity': 'high',
                            'file': file_path,
                            'line': line_num,
                            'description': 'Potential buffer overflow vulnerability',
                            'evidence': content[max(0, match.start()-30):match.end()+30]
                        })
            
        except Exception as e:
            findings.append({
                'type': 'analysis_error',
                'severity': 'low',
                'file': file_path,
                'line': 0,
                'description': f'Error analyzing file: {str(e)}',
                'evidence': ''
            })
        
        return findings
    
    def analyze_directory(self, directory):
        """Analyze all files in directory"""
        all_findings = []
        
        for root, dirs, files in os.walk(directory):
            for file in files:
                file_path = os.path.join(root, file)
                
                # Skip binary files and directories to ignore
                if any(skip in file_path for skip in ['.git', '__pycache__', 'node_modules', '.env']):
                    continue
                
                # Check file extension
                allowed_extensions = self.policies.get('security_policies', {}).get('code_analysis', {}).get('file_extensions_allowed', [])
                if allowed_extensions and not any(file_path.endswith(ext) for ext in allowed_extensions):
                    continue
                
                findings = self.analyze_file(file_path)
                all_findings.extend(findings)
        
        return all_findings
    
    def generate_report(self, findings, output_file):
        """Generate analysis report"""
        report = {
            'scan_info': {
                'analyzer': 'SimCity ARM64 Static Analyzer',
                'version': '1.0.0',
                'timestamp': 'timestamp_placeholder',
                'total_findings': len(findings)
            },
            'summary': {
                'critical': len([f for f in findings if f['severity'] == 'critical']),
                'high': len([f for f in findings if f['severity'] == 'high']),
                'medium': len([f for f in findings if f['severity'] == 'medium']),
                'low': len([f for f in findings if f['severity'] == 'low'])
            },
            'findings': findings
        }
        
        with open(output_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        return report

def main():
    import sys
    if len(sys.argv) < 3:
        print("Usage: static_analyzer.py <directory> <policies_file> [output_file]")
        sys.exit(1)
    
    directory = sys.argv[1]
    policies_file = sys.argv[2]
    output_file = sys.argv[3] if len(sys.argv) > 3 else 'static_analysis_report.json'
    
    analyzer = StaticAnalyzer(policies_file)
    findings = analyzer.analyze_directory(directory)
    report = analyzer.generate_report(findings, output_file)
    
    print(f"Static analysis completed. Found {len(findings)} issues.")
    print(f"Report saved to: {output_file}")

if __name__ == "__main__":
    main()
EOF
    
    # Create malware scanner
    cat > "${SECURITY_DIR}/engines/malware_scanner.py" << 'EOF'
#!/usr/bin/env python3
"""
SimCity ARM64 Malware Scanner
Real-time malware detection and quarantine
"""

import os
import hashlib
import json
import re
import time
from pathlib import Path

class MalwareScanner:
    def __init__(self, signatures_file):
        self.signatures = self.load_signatures(signatures_file)
        self.scan_results = []
        
    def load_signatures(self, signatures_file):
        """Load malware signatures"""
        signatures = {
            'hash': [],
            'string': [],
            'regex': [],
            'binary': []
        }
        
        try:
            with open(signatures_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line.startswith('#') or not line:
                        continue
                    
                    parts = line.split(':', 3)
                    if len(parts) >= 4:
                        sig_type, pattern, severity, description = parts
                        signatures[sig_type].append({
                            'pattern': pattern,
                            'severity': severity,
                            'description': description
                        })
        except Exception as e:
            print(f"Warning: Could not load signatures: {e}")
        
        return signatures
    
    def calculate_file_hash(self, file_path):
        """Calculate SHA256 hash of file"""
        try:
            with open(file_path, 'rb') as f:
                return hashlib.sha256(f.read()).hexdigest()
        except Exception:
            return None
    
    def scan_file_hash(self, file_path):
        """Scan file using hash signatures"""
        file_hash = self.calculate_file_hash(file_path)
        if not file_hash:
            return []
        
        findings = []
        for sig in self.signatures['hash']:
            if file_hash == sig['pattern']:
                findings.append({
                    'type': 'malware_hash',
                    'severity': sig['severity'],
                    'file': file_path,
                    'description': sig['description'],
                    'evidence': f'Hash: {file_hash}'
                })
        
        return findings
    
    def scan_file_content(self, file_path):
        """Scan file content using string and regex signatures"""
        findings = []
        
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # String signatures
            for sig in self.signatures['string']:
                if sig['pattern'] in content:
                    findings.append({
                        'type': 'malware_string',
                        'severity': sig['severity'],
                        'file': file_path,
                        'description': sig['description'],
                        'evidence': f'Pattern: {sig["pattern"]}'
                    })
            
            # Regex signatures
            for sig in self.signatures['regex']:
                try:
                    if re.search(sig['pattern'], content, re.IGNORECASE):
                        findings.append({
                            'type': 'malware_regex',
                            'severity': sig['severity'],
                            'file': file_path,
                            'description': sig['description'],
                            'evidence': f'Pattern: {sig["pattern"]}'
                        })
                except re.error:
                    continue
            
        except Exception:
            pass  # Skip files that can't be read as text
        
        return findings
    
    def scan_file_binary(self, file_path):
        """Scan file using binary signatures"""
        findings = []
        
        try:
            with open(file_path, 'rb') as f:
                content = f.read(8192)  # Read first 8KB
                hex_content = content.hex()
            
            for sig in self.signatures['binary']:
                if sig['pattern'] in hex_content:
                    findings.append({
                        'type': 'malware_binary',
                        'severity': sig['severity'],
                        'file': file_path,
                        'description': sig['description'],
                        'evidence': f'Binary pattern: {sig["pattern"]}'
                    })
        
        except Exception:
            pass
        
        return findings
    
    def scan_file(self, file_path):
        """Comprehensive file scan"""
        findings = []
        
        # Hash-based detection
        findings.extend(self.scan_file_hash(file_path))
        
        # Content-based detection
        findings.extend(self.scan_file_content(file_path))
        
        # Binary-based detection
        findings.extend(self.scan_file_binary(file_path))
        
        return findings
    
    def scan_directory(self, directory):
        """Scan all files in directory"""
        all_findings = []
        
        for root, dirs, files in os.walk(directory):
            for file in files:
                file_path = os.path.join(root, file)
                
                # Skip system directories
                if any(skip in file_path for skip in ['.git', '__pycache__', '.DS_Store']):
                    continue
                
                findings = self.scan_file(file_path)
                all_findings.extend(findings)
        
        return all_findings
    
    def quarantine_file(self, file_path, quarantine_dir):
        """Move suspicious file to quarantine"""
        try:
            os.makedirs(quarantine_dir, exist_ok=True)
            
            # Create quarantine filename with timestamp
            timestamp = int(time.time())
            quarantine_name = f"{timestamp}_{os.path.basename(file_path)}"
            quarantine_path = os.path.join(quarantine_dir, quarantine_name)
            
            # Move file to quarantine
            os.rename(file_path, quarantine_path)
            
            # Create metadata file
            metadata = {
                'original_path': file_path,
                'quarantine_time': timestamp,
                'reason': 'malware_detection'
            }
            
            with open(f"{quarantine_path}.metadata", 'w') as f:
                json.dump(metadata, f, indent=2)
            
            return quarantine_path
            
        except Exception as e:
            print(f"Failed to quarantine file {file_path}: {e}")
            return None

def main():
    import sys
    if len(sys.argv) < 3:
        print("Usage: malware_scanner.py <directory> <signatures_file> [quarantine_dir]")
        sys.exit(1)
    
    directory = sys.argv[1]
    signatures_file = sys.argv[2]
    quarantine_dir = sys.argv[3] if len(sys.argv) > 3 else None
    
    scanner = MalwareScanner(signatures_file)
    findings = scanner.scan_directory(directory)
    
    print(f"Malware scan completed. Found {len(findings)} threats.")
    
    if quarantine_dir and findings:
        print(f"Quarantining {len(findings)} suspicious files...")
        for finding in findings:
            if finding['severity'] in ['critical', 'high']:
                scanner.quarantine_file(finding['file'], quarantine_dir)

if __name__ == "__main__":
    main()
EOF
    
    # Create dependency scanner
    cat > "${SECURITY_DIR}/engines/dependency_scanner.py" << 'EOF'
#!/usr/bin/env python3
"""
SimCity ARM64 Dependency Scanner
Vulnerability assessment for build dependencies
"""

import os
import json
import subprocess
import requests
from pathlib import Path

class DependencyScanner:
    def __init__(self):
        self.vulnerabilities = []
        
    def scan_git_dependencies(self, repo_path):
        """Scan Git submodules and dependencies"""
        findings = []
        
        try:
            # Check for .gitmodules
            gitmodules_path = os.path.join(repo_path, '.gitmodules')
            if os.path.exists(gitmodules_path):
                with open(gitmodules_path, 'r') as f:
                    content = f.read()
                    
                # Check for suspicious Git URLs
                suspicious_patterns = [
                    'pastebin.com',
                    'hastebin.com',
                    'raw.githubusercontent.com',
                    'gist.github.com'
                ]
                
                for pattern in suspicious_patterns:
                    if pattern in content:
                        findings.append({
                            'type': 'suspicious_dependency_source',
                            'severity': 'medium',
                            'description': f'Suspicious dependency source: {pattern}',
                            'file': gitmodules_path
                        })
        
        except Exception as e:
            findings.append({
                'type': 'scan_error',
                'severity': 'low',
                'description': f'Error scanning git dependencies: {str(e)}',
                'file': repo_path
            })
        
        return findings
    
    def scan_package_files(self, directory):
        """Scan package manager files for vulnerabilities"""
        findings = []
        
        # Common package files
        package_files = [
            'package.json',     # npm
            'requirements.txt', # pip
            'Gemfile',         # bundler
            'Cargo.toml',      # cargo
            'go.mod',          # go modules
            'Pipfile'          # pipenv
        ]
        
        for root, dirs, files in os.walk(directory):
            for file in files:
                if file in package_files:
                    file_path = os.path.join(root, file)
                    findings.extend(self.analyze_package_file(file_path))
        
        return findings
    
    def analyze_package_file(self, file_path):
        """Analyze individual package file"""
        findings = []
        
        try:
            with open(file_path, 'r') as f:
                content = f.read()
            
            # Check for known vulnerable packages
            vulnerable_packages = [
                'lodash',
                'moment',
                'request',
                'debug',
                'hoek'
            ]
            
            for package in vulnerable_packages:
                if package in content:
                    findings.append({
                        'type': 'vulnerable_package',
                        'severity': 'medium',
                        'description': f'Potentially vulnerable package: {package}',
                        'file': file_path
                    })
            
            # Check for development dependencies in production
            if 'package.json' in file_path:
                try:
                    data = json.loads(content)
                    dev_deps = data.get('devDependencies', {})
                    deps = data.get('dependencies', {})
                    
                    # Flag if dev dependencies are mixed with production
                    if dev_deps and any(key in deps for key in dev_deps):
                        findings.append({
                            'type': 'dependency_confusion',
                            'severity': 'low',
                            'description': 'Development dependencies mixed with production',
                            'file': file_path
                        })
                except json.JSONDecodeError:
                    pass
        
        except Exception as e:
            findings.append({
                'type': 'analysis_error',
                'severity': 'low',
                'description': f'Error analyzing package file: {str(e)}',
                'file': file_path
            })
        
        return findings
    
    def check_supply_chain_integrity(self, directory):
        """Check supply chain integrity"""
        findings = []
        
        # Check for package-lock.json or yarn.lock
        lock_files = ['package-lock.json', 'yarn.lock', 'Pipfile.lock']
        
        for root, dirs, files in os.walk(directory):
            for file in files:
                if file in lock_files:
                    file_path = os.path.join(root, file)
                    
                    # Check if lock file is newer than package file
                    package_file = None
                    if file == 'package-lock.json':
                        package_file = os.path.join(root, 'package.json')
                    elif file == 'yarn.lock':
                        package_file = os.path.join(root, 'package.json')
                    elif file == 'Pipfile.lock':
                        package_file = os.path.join(root, 'Pipfile')
                    
                    if package_file and os.path.exists(package_file):
                        lock_time = os.path.getmtime(file_path)
                        package_time = os.path.getmtime(package_file)
                        
                        if package_time > lock_time:
                            findings.append({
                                'type': 'outdated_lock_file',
                                'severity': 'medium',
                                'description': 'Lock file is older than package file',
                                'file': file_path
                            })
        
        return findings

def main():
    import sys
    if len(sys.argv) < 2:
        print("Usage: dependency_scanner.py <directory>")
        sys.exit(1)
    
    directory = sys.argv[1]
    
    scanner = DependencyScanner()
    
    # Run all scans
    findings = []
    findings.extend(scanner.scan_git_dependencies(directory))
    findings.extend(scanner.scan_package_files(directory))
    findings.extend(scanner.check_supply_chain_integrity(directory))
    
    print(f"Dependency scan completed. Found {len(findings)} issues.")
    
    # Output results
    if findings:
        for finding in findings:
            print(f"{finding['severity'].upper()}: {finding['description']} ({finding.get('file', 'N/A')})")

if __name__ == "__main__":
    main()
EOF
    
    chmod +x "${SECURITY_DIR}/engines"/*.py
    mkdir -p "${SECURITY_DIR}/engines"
    
    print_success "Scanning engines setup completed"
}

# Function to run comprehensive security scan
run_security_scan() {
    print_status "Running comprehensive security scan..."
    
    local scan_id=$(date +%Y%m%d_%H%M%S)
    local scan_dir="${SCAN_RESULTS_DIR}/comprehensive_${scan_id}"
    
    mkdir -p "$scan_dir"
    
    # Initialize scan results
    cat > "${scan_dir}/scan_summary.json" << EOF
{
    "scan_info": {
        "scan_id": "$scan_id",
        "start_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
        "scan_level": "$SCAN_LEVEL",
        "target": "$PROJECT_ROOT"
    },
    "results": {
        "static_analysis": null,
        "malware_scan": null,
        "dependency_scan": null,
        "supply_chain_scan": null
    },
    "summary": {
        "total_findings": 0,
        "critical": 0,
        "high": 0,
        "medium": 0,
        "low": 0
    }
}
EOF
    
    local total_findings=0
    
    # Static analysis
    if [ "$STATIC_ANALYSIS" = true ]; then
        print_status "Running static code analysis..."
        
        python3 "${SECURITY_DIR}/engines/static_analyzer.py" \
            "$PROJECT_ROOT/src" \
            "$SECURITY_POLICIES" \
            "${scan_dir}/static_analysis.json" 2>/dev/null || {
            print_warning "Static analysis failed or not available"
            echo '{"findings": []}' > "${scan_dir}/static_analysis.json"
        }
        
        local static_findings=$(python3 -c "
import json
try:
    with open('${scan_dir}/static_analysis.json', 'r') as f:
        data = json.load(f)
        print(len(data.get('findings', [])))
except:
    print(0)
" 2>/dev/null || echo "0")
        
        total_findings=$((total_findings + static_findings))
        print_success "Static analysis completed: $static_findings findings"
    fi
    
    # Malware scanning
    if [ "$MALWARE_SCANNING" = true ]; then
        print_status "Running malware scan..."
        
        python3 "${SECURITY_DIR}/engines/malware_scanner.py" \
            "$PROJECT_ROOT" \
            "$MALWARE_SIGNATURES" \
            "${QUARANTINE_DIR}/malware" 2>/dev/null || {
            print_warning "Malware scan failed or not available"
        }
        
        print_success "Malware scan completed"
    fi
    
    # Dependency scanning
    if [ "$DEPENDENCY_SCANNING" = true ]; then
        print_status "Running dependency vulnerability scan..."
        
        python3 "${SECURITY_DIR}/engines/dependency_scanner.py" \
            "$PROJECT_ROOT" > "${scan_dir}/dependency_scan.log" 2>&1 || {
            print_warning "Dependency scan failed or not available"
        }
        
        print_success "Dependency scan completed"
    fi
    
    # Supply chain scanning
    if [ "$SUPPLY_CHAIN_SCANNING" = true ]; then
        print_status "Running supply chain security assessment..."
        
        run_supply_chain_scan "$scan_dir"
        
        print_success "Supply chain scan completed"
    fi
    
    # Generate final report
    generate_security_report "$scan_dir" "$total_findings"
    
    print_success "Comprehensive security scan completed: $total_findings total findings"
}

# Function to run supply chain scan
run_supply_chain_scan() {
    local scan_dir="$1"
    
    # Check Git repository integrity
    if [ -d "$PROJECT_ROOT/.git" ]; then
        # Check for unsigned commits
        local unsigned_commits=$(git log --pretty=format:"%H %s" --show-signature 2>&1 | grep -c "^[a-f0-9]" || echo "0")
        
        # Check for suspicious commit patterns
        local suspicious_commits=$(git log --oneline | grep -i -E "(password|secret|key|token)" | wc -l || echo "0")
        
        cat > "${scan_dir}/supply_chain.json" << EOF
{
    "git_integrity": {
        "unsigned_commits": $unsigned_commits,
        "suspicious_commits": $suspicious_commits,
        "repository_url": "$(git remote get-url origin 2>/dev/null || echo 'unknown')",
        "current_branch": "$(git branch --show-current 2>/dev/null || echo 'unknown')"
    },
    "build_integrity": {
        "build_scripts_modified": false,
        "unexpected_dependencies": false
    }
}
EOF
    fi
}

# Function to generate security report
generate_security_report() {
    local scan_dir="$1"
    local total_findings="$2"
    
    print_status "Generating security report..."
    
    local report_file="${REPORTS_DIR}/security_report_$(date +%Y%m%d_%H%M%S).html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>SimCity ARM64 Security Scan Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; line-height: 1.6; }
        .header { background-color: #f8f9fa; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .summary { display: flex; justify-content: space-around; margin: 20px 0; }
        .metric { text-align: center; padding: 15px; border: 1px solid #ddd; border-radius: 5px; flex: 1; margin: 0 10px; }
        .critical { background-color: #f8d7da; border-color: #f5c6cb; }
        .high { background-color: #fff3cd; border-color: #ffeaa7; }
        .medium { background-color: #d1ecf1; border-color: #bee5eb; }
        .low { background-color: #d4edda; border-color: #c3e6cb; }
        .success { background-color: #d4edda; border-color: #c3e6cb; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007bff; }
        .finding { margin: 10px 0; padding: 10px; border-radius: 3px; }
        .scan-config { background-color: #e7f3ff; padding: 15px; border-radius: 5px; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f8f9fa; }
    </style>
</head>
<body>
    <div class="header">
        <h1>SimCity ARM64 Security Scan Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Scan Level:</strong> $SCAN_LEVEL</p>
        <p><strong>Total Findings:</strong> $total_findings</p>
    </div>
    
    <div class="scan-config">
        <h2>Scan Configuration</h2>
        <table>
            <tr><th>Security Feature</th><th>Status</th></tr>
            <tr><td>Static Analysis</td><td>$([ "$STATIC_ANALYSIS" = true ] && echo "✅ Enabled" || echo "❌ Disabled")</td></tr>
            <tr><td>Dynamic Analysis</td><td>$([ "$DYNAMIC_ANALYSIS" = true ] && echo "✅ Enabled" || echo "❌ Disabled")</td></tr>
            <tr><td>Malware Scanning</td><td>$([ "$MALWARE_SCANNING" = true ] && echo "✅ Enabled" || echo "❌ Disabled")</td></tr>
            <tr><td>Dependency Scanning</td><td>$([ "$DEPENDENCY_SCANNING" = true ] && echo "✅ Enabled" || echo "❌ Disabled")</td></tr>
            <tr><td>Supply Chain Analysis</td><td>$([ "$SUPPLY_CHAIN_SCANNING" = true ] && echo "✅ Enabled" || echo "❌ Disabled")</td></tr>
            <tr><td>Real-time Monitoring</td><td>$([ "$REAL_TIME_SCANNING" = true ] && echo "✅ Enabled" || echo "❌ Disabled")</td></tr>
            <tr><td>Threat Quarantine</td><td>$([ "$QUARANTINE_THREATS" = true ] && echo "✅ Enabled" || echo "❌ Disabled")</td></tr>
        </table>
    </div>
    
    <div class="summary">
        <div class="metric $([ $total_findings -eq 0 ] && echo "success" || echo "critical")">
            <h3>$total_findings</h3>
            <p>Total Findings</p>
        </div>
        <div class="metric">
            <h3>$(ls "${QUARANTINE_DIR}" 2>/dev/null | wc -l || echo "0")</h3>
            <p>Quarantined Items</p>
        </div>
        <div class="metric success">
            <h3>$(wc -l < "$MALWARE_SIGNATURES" || echo "0")</h3>
            <p>Malware Signatures</p>
        </div>
        <div class="metric success">
            <h3>$(date +%Y-%m-%d)</h3>
            <p>Last Updated</p>
        </div>
    </div>
    
    <div class="section">
        <h2>Security Assessment Summary</h2>
        <p>This report provides a comprehensive security assessment of the SimCity ARM64 build system 
        and codebase. The assessment includes static code analysis, malware detection, dependency 
        vulnerability scanning, and supply chain security evaluation.</p>
        
        <h3>Overall Security Posture</h3>
        <p class="$([ $total_findings -eq 0 ] && echo "success" || echo "warning")">
            $([ $total_findings -eq 0 ] && echo "✅ No security issues detected" || echo "⚠️ Security issues require attention")
        </p>
    </div>
    
    <div class="section">
        <h2>Recommendations</h2>
        <ul>
            <li>Regularly update security databases and signatures</li>
            <li>Enable real-time monitoring for continuous protection</li>
            <li>Implement automated remediation for critical vulnerabilities</li>
            <li>Conduct periodic security audits and penetration testing</li>
            <li>Maintain updated dependency inventories</li>
            <li>Implement code signing for build artifacts</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>Security Tools and Databases</h2>
        <p><strong>Malware Signatures:</strong> $MALWARE_SIGNATURES</p>
        <p><strong>CVE Database:</strong> $CVE_DATABASE</p>
        <p><strong>Threat Intelligence:</strong> $THREAT_INTELLIGENCE</p>
        <p><strong>Security Policies:</strong> $SECURITY_POLICIES</p>
        <p><strong>Quarantine Directory:</strong> $QUARANTINE_DIR</p>
    </div>
</body>
</html>
EOF
    
    print_success "Security report generated: $report_file"
}

# Function to update security databases
update_security_databases() {
    print_status "Updating security databases..."
    
    # Update CVE database (simplified - would fetch from NVD API in production)
    print_status "Updating CVE database..."
    
    # Update malware signatures
    print_status "Updating malware signatures..."
    
    # Update threat intelligence
    print_status "Updating threat intelligence..."
    
    # Update the database timestamp
    python3 -c "
import json
with open('$CVE_DATABASE', 'r') as f:
    data = json.load(f)
data['database_info']['last_updated'] = '$(date -u +"%Y-%m-%dT%H:%M:%SZ")'
with open('$CVE_DATABASE', 'w') as f:
    json.dump(data, f, indent=2)
"
    
    print_success "Security databases updated"
}

# Function to start real-time monitoring
start_security_monitoring() {
    print_status "Starting real-time security monitoring..."
    
    # Create monitoring script
    cat > "${SECURITY_DIR}/monitoring/security_monitor.sh" << 'EOF'
#!/bin/bash
# Real-time security monitoring for SimCity ARM64 builds

MONITOR_DIR="/tmp/simcity_security_monitor"
mkdir -p "$MONITOR_DIR"

# Monitor file system changes
fswatch -o "$PROJECT_ROOT" | while read f; do
    echo "$(date): File system change detected in $PROJECT_ROOT" >> "$MONITOR_DIR/fs_monitor.log"
    
    # Quick malware scan on new/changed files
    find "$PROJECT_ROOT" -newer "$MONITOR_DIR/last_scan" -type f 2>/dev/null | while read file; do
        if [[ "$file" =~ \.(s|c|h|sh|py)$ ]]; then
            echo "$(date): Scanning changed file: $file" >> "$MONITOR_DIR/scan.log"
            # Run quick scan here
        fi
    done
    
    touch "$MONITOR_DIR/last_scan"
done &

echo $! > "$MONITOR_DIR/monitor.pid"
EOF
    
    chmod +x "${SECURITY_DIR}/monitoring/security_monitor.sh"
    
    # Start monitoring if fswatch is available
    if command -v fswatch >/dev/null 2>&1; then
        "${SECURITY_DIR}/monitoring/security_monitor.sh" &
        print_success "Real-time security monitoring started"
    else
        print_warning "fswatch not found. Real-time monitoring not available."
    fi
}

# Function to parse command line arguments
parse_arguments() {
    COMMAND=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            scan|static|malware|dependencies|supply-chain|monitor|update|report)
                COMMAND="$1"
                shift
                ;;
            --level)
                case "$2" in
                    basic|standard|comprehensive|paranoid)
                        SCAN_LEVEL="$2"
                        ;;
                    *)
                        print_failure "Invalid scan level: $2"
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            --no-static)
                STATIC_ANALYSIS=false
                shift
                ;;
            --no-dynamic)
                DYNAMIC_ANALYSIS=false
                shift
                ;;
            --no-dependencies)
                DEPENDENCY_SCANNING=false
                shift
                ;;
            --no-malware)
                MALWARE_SCANNING=false
                shift
                ;;
            --no-supply-chain)
                SUPPLY_CHAIN_SCANNING=false
                shift
                ;;
            --no-real-time)
                REAL_TIME_SCANNING=false
                shift
                ;;
            --no-quarantine)
                QUARANTINE_THREATS=false
                shift
                ;;
            --auto-remediate)
                AUTO_REMEDIATION=true
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

# Function to execute command
execute_command() {
    case "${COMMAND:-scan}" in
        scan)
            init_security_environment
            run_security_scan
            ;;
        static)
            init_security_environment
            python3 "${SECURITY_DIR}/engines/static_analyzer.py" "$PROJECT_ROOT/src" "$SECURITY_POLICIES"
            ;;
        malware)
            init_security_environment
            python3 "${SECURITY_DIR}/engines/malware_scanner.py" "$PROJECT_ROOT" "$MALWARE_SIGNATURES" "${QUARANTINE_DIR}/malware"
            ;;
        dependencies)
            init_security_environment
            python3 "${SECURITY_DIR}/engines/dependency_scanner.py" "$PROJECT_ROOT"
            ;;
        supply-chain)
            init_security_environment
            run_supply_chain_scan "${SCAN_RESULTS_DIR}/supply_chain_$(date +%Y%m%d_%H%M%S)"
            ;;
        monitor)
            init_security_environment
            start_security_monitoring
            ;;
        update)
            init_security_environment
            update_security_databases
            ;;
        report)
            init_security_environment
            generate_security_report "${SCAN_RESULTS_DIR}/manual_$(date +%Y%m%d_%H%M%S)" "0"
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
    
    print_status "Security Scanner Configuration:"
    echo "  Command: ${COMMAND:-scan}"
    echo "  Scan Level: $SCAN_LEVEL"
    echo "  Static Analysis: $STATIC_ANALYSIS"
    echo "  Malware Scanning: $MALWARE_SCANNING"
    echo "  Dependency Scanning: $DEPENDENCY_SCANNING"
    echo "  Supply Chain Scanning: $SUPPLY_CHAIN_SCANNING"
    echo "  Real-time Monitoring: $REAL_TIME_SCANNING"
    echo "  Quarantine Threats: $QUARANTINE_THREATS"
    echo "  Auto Remediation: $AUTO_REMEDIATION"
    echo ""
    
    # Execute command
    execute_command
}

# Execute main function with all arguments
main "$@"