#!/usr/bin/env python3
"""
Camera Controller Fuzzing Framework
Automated fuzzing to find edge cases and crashes
"""

import subprocess
import os
import sys
import time
import random
import struct
import signal
import multiprocessing
import json
import hashlib
from pathlib import Path
from datetime import datetime
from concurrent.futures import ProcessPoolExecutor, as_completed

class CameraFuzzer:
    def __init__(self, target_binary, corpus_dir="fuzz_corpus", crashes_dir="crashes"):
        self.target_binary = Path(target_binary)
        self.corpus_dir = Path(corpus_dir)
        self.crashes_dir = Path(crashes_dir)
        
        # Create directories
        self.corpus_dir.mkdir(exist_ok=True)
        self.crashes_dir.mkdir(exist_ok=True)
        
        # Fuzzing statistics
        self.stats = {
            'start_time': time.time(),
            'total_executions': 0,
            'crashes': 0,
            'timeouts': 0,
            'interesting_inputs': 0,
            'coverage_increase': 0
        }
        
        # Input mutation strategies
        self.mutation_strategies = [
            self.bit_flip,
            self.byte_flip,
            self.arithmetic_mutation,
            self.interesting_values,
            self.block_shuffle,
            self.truncate_extend,
            self.splice_inputs,
            self.dictionary_mutation
        ]
        
        # Interesting values for mutation
        self.interesting_8bit = [0, 1, 16, 32, 64, 100, 127, 128, 255]
        self.interesting_16bit = [0, 128, 255, 256, 512, 1000, 1024, 4096, 32767, 65535]
        self.interesting_32bit = [0, 1, -1, 256, 65536, 2147483647, 4294967295]
        self.interesting_floats = [0.0, -0.0, 1.0, -1.0, float('inf'), float('-inf'), float('nan')]
        
        # Coverage tracking
        self.coverage_map = {}
        self.unique_crashes = set()
        
    def run(self, duration_seconds=3600, num_workers=4):
        """Run fuzzer for specified duration"""
        print(f"Starting camera fuzzer with {num_workers} workers")
        print(f"Target: {self.target_binary}")
        print(f"Corpus: {self.corpus_dir}")
        print(f"Duration: {duration_seconds} seconds")
        print("-" * 60)
        
        # Load initial corpus
        corpus = self.load_corpus()
        if not corpus:
            print("Generating initial corpus...")
            corpus = self.generate_initial_corpus()
        
        print(f"Loaded {len(corpus)} initial inputs")
        
        # Set up signal handler for clean shutdown
        signal.signal(signal.SIGINT, self.signal_handler)
        
        # Start fuzzing workers
        end_time = time.time() + duration_seconds
        
        with ProcessPoolExecutor(max_workers=num_workers) as executor:
            # Submit initial jobs
            futures = []
            for i in range(num_workers * 2):
                if corpus:
                    seed_input = random.choice(corpus)
                    future = executor.submit(self.fuzz_iteration, seed_input)
                    futures.append(future)
            
            # Process results and submit new jobs
            while time.time() < end_time:
                # Wait for any job to complete
                done, pending = as_completed(futures, timeout=1)
                
                for future in done:
                    try:
                        result = future.result()
                        if result:
                            self.process_result(result)
                            
                            # Add interesting inputs to corpus
                            if result['interesting']:
                                corpus.append(result['input'])
                                
                    except Exception as e:
                        print(f"Worker error: {e}")
                    
                    # Submit new job
                    if corpus and time.time() < end_time:
                        seed_input = random.choice(corpus)
                        new_future = executor.submit(self.fuzz_iteration, seed_input)
                        futures.append(new_future)
                    
                futures = list(pending)
                
                # Print statistics periodically
                if self.stats['total_executions'] % 1000 == 0:
                    self.print_stats()
        
        # Final statistics
        print("\n" + "=" * 60)
        print("FUZZING COMPLETE")
        self.print_stats()
        self.generate_report()
        
    def fuzz_iteration(self, seed_input):
        """Single fuzzing iteration"""
        # Mutate input
        mutated_input = self.mutate_input(seed_input)
        
        # Execute target
        result = self.execute_target(mutated_input)
        
        # Analyze result
        result['input'] = mutated_input
        result['interesting'] = self.is_interesting(result)
        
        return result
    
    def mutate_input(self, input_data):
        """Mutate input using various strategies"""
        # Choose mutation strategy
        strategy = random.choice(self.mutation_strategies)
        
        # Apply mutation
        mutated = strategy(input_data.copy())
        
        # Sometimes stack multiple mutations
        if random.random() < 0.1:
            num_mutations = random.randint(2, 5)
            for _ in range(num_mutations):
                strategy = random.choice(self.mutation_strategies)
                mutated = strategy(mutated)
        
        return mutated
    
    def execute_target(self, input_data):
        """Execute target with input and collect results"""
        result = {
            'execution_time': 0,
            'exit_code': 0,
            'crashed': False,
            'timeout': False,
            'stdout': '',
            'stderr': '',
            'coverage': None
        }
        
        # Create temporary input file
        input_file = Path(f"/tmp/fuzz_input_{os.getpid()}.bin")
        self.write_input_file(input_file, input_data)
        
        # Build command
        cmd = [
            str(self.target_binary),
            "--fuzz-input", str(input_file),
            "--timeout", "1000"  # 1 second timeout
        ]
        
        # Execute with timeout
        start_time = time.time()
        try:
            proc = subprocess.run(
                cmd,
                capture_output=True,
                timeout=2.0,  # 2 second hard timeout
                check=False
            )
            
            result['execution_time'] = time.time() - start_time
            result['exit_code'] = proc.returncode
            result['stdout'] = proc.stdout.decode('utf-8', errors='ignore')
            result['stderr'] = proc.stderr.decode('utf-8', errors='ignore')
            
            # Check for crashes
            if proc.returncode < 0:  # Negative = signal
                result['crashed'] = True
                result['signal'] = -proc.returncode
            
            # Extract coverage if available
            coverage = self.extract_coverage(result['stdout'])
            if coverage:
                result['coverage'] = coverage
                
        except subprocess.TimeoutExpired:
            result['timeout'] = True
            result['execution_time'] = time.time() - start_time
            
        finally:
            # Clean up
            input_file.unlink(missing_ok=True)
        
        self.stats['total_executions'] += 1
        
        return result
    
    def is_interesting(self, result):
        """Determine if result is interesting"""
        # Crashes are always interesting
        if result['crashed']:
            return True
        
        # Timeouts might be interesting
        if result['timeout'] and random.random() < 0.1:
            return True
        
        # New coverage is interesting
        if result['coverage']:
            coverage_hash = self.hash_coverage(result['coverage'])
            if coverage_hash not in self.coverage_map:
                self.coverage_map[coverage_hash] = True
                self.stats['coverage_increase'] += 1
                return True
        
        # Unusual execution time
        if result['execution_time'] > 0.5:  # Slow execution
            return True
        
        # Unusual output
        if len(result['stderr']) > 1000:  # Lots of errors
            return True
        
        return False
    
    def process_result(self, result):
        """Process fuzzing result"""
        if result['crashed']:
            self.stats['crashes'] += 1
            self.save_crash(result)
        
        if result['timeout']:
            self.stats['timeouts'] += 1
        
        if result['interesting']:
            self.stats['interesting_inputs'] += 1
            self.save_interesting_input(result)
    
    def save_crash(self, result):
        """Save crash information"""
        # Generate crash ID
        crash_data = f"{result['signal']}:{result['stderr']}"
        crash_id = hashlib.sha256(crash_data.encode()).hexdigest()[:16]
        
        # Check if unique
        if crash_id in self.unique_crashes:
            return
        
        self.unique_crashes.add(crash_id)
        
        # Save crash info
        crash_dir = self.crashes_dir / crash_id
        crash_dir.mkdir(exist_ok=True)
        
        # Save input
        input_file = crash_dir / "input.bin"
        self.write_input_file(input_file, result['input'])
        
        # Save metadata
        metadata = {
            'timestamp': datetime.now().isoformat(),
            'signal': result.get('signal', 0),
            'exit_code': result['exit_code'],
            'execution_time': result['execution_time'],
            'stdout': result['stdout'][:1000],  # First 1000 chars
            'stderr': result['stderr'][:1000]
        }
        
        with open(crash_dir / "metadata.json", 'w') as f:
            json.dump(metadata, f, indent=2)
        
        # Save reproduction script
        with open(crash_dir / "reproduce.sh", 'w') as f:
            f.write("#!/bin/bash\n")
            f.write(f"# Crash reproduction script\n")
            f.write(f"# Signal: {result.get('signal', 'unknown')}\n")
            f.write(f"{self.target_binary} --fuzz-input input.bin\n")
        
        os.chmod(crash_dir / "reproduce.sh", 0o755)
        
        print(f"\n[!] New crash found: {crash_id} (signal {result.get('signal', '?')})")
    
    def save_interesting_input(self, result):
        """Save interesting input to corpus"""
        # Generate filename based on properties
        properties = []
        if result['crashed']:
            properties.append('crash')
        if result['timeout']:
            properties.append('timeout')
        if result.get('coverage'):
            properties.append('cov')
        
        timestamp = int(time.time())
        filename = f"id_{timestamp}_{'_'.join(properties)}.bin"
        
        input_file = self.corpus_dir / filename
        self.write_input_file(input_file, result['input'])
    
    # Mutation strategies
    
    def bit_flip(self, data):
        """Flip random bits"""
        if 'bytes' not in data:
            return data
        
        bytes_data = bytearray(data['bytes'])
        if not bytes_data:
            return data
        
        num_flips = random.randint(1, 8)
        for _ in range(num_flips):
            byte_idx = random.randint(0, len(bytes_data) - 1)
            bit_idx = random.randint(0, 7)
            bytes_data[byte_idx] ^= (1 << bit_idx)
        
        data['bytes'] = bytes(bytes_data)
        return data
    
    def byte_flip(self, data):
        """Flip random bytes"""
        if 'bytes' not in data:
            return data
        
        bytes_data = bytearray(data['bytes'])
        if not bytes_data:
            return data
        
        num_flips = random.randint(1, 4)
        for _ in range(num_flips):
            idx = random.randint(0, len(bytes_data) - 1)
            bytes_data[idx] ^= 0xFF
        
        data['bytes'] = bytes(bytes_data)
        return data
    
    def arithmetic_mutation(self, data):
        """Add/subtract small values"""
        if 'position' in data:
            idx = random.randint(0, 2)
            delta = random.choice([-100, -10, -1, 1, 10, 100])
            data['position'][idx] += delta
        
        if 'zoom' in data:
            delta = random.choice([-5, -1, -0.1, 0.1, 1, 5])
            data['zoom'] += delta
        
        return data
    
    def interesting_values(self, data):
        """Replace with interesting values"""
        if 'position' in data and random.random() < 0.3:
            idx = random.randint(0, 2)
            data['position'][idx] = random.choice(self.interesting_floats)
        
        if 'rotation' in data and random.random() < 0.3:
            idx = random.randint(0, 3)
            data['rotation'][idx] = random.choice(self.interesting_floats)
        
        if 'zoom' in data and random.random() < 0.3:
            data['zoom'] = random.choice(self.interesting_floats)
        
        return data
    
    def block_shuffle(self, data):
        """Shuffle blocks of data"""
        if 'bytes' not in data:
            return data
        
        bytes_data = bytearray(data['bytes'])
        if len(bytes_data) < 8:
            return data
        
        # Choose block size
        block_size = random.choice([4, 8, 16, 32])
        if block_size > len(bytes_data) // 2:
            return data
        
        # Shuffle two blocks
        idx1 = random.randint(0, len(bytes_data) - block_size)
        idx2 = random.randint(0, len(bytes_data) - block_size)
        
        if idx1 != idx2:
            block1 = bytes_data[idx1:idx1 + block_size]
            block2 = bytes_data[idx2:idx2 + block_size]
            bytes_data[idx1:idx1 + block_size] = block2
            bytes_data[idx2:idx2 + block_size] = block1
        
        data['bytes'] = bytes(bytes_data)
        return data
    
    def truncate_extend(self, data):
        """Truncate or extend data"""
        if 'bytes' not in data:
            return data
        
        bytes_data = bytearray(data['bytes'])
        
        if random.random() < 0.5:
            # Truncate
            if len(bytes_data) > 4:
                new_len = random.randint(1, len(bytes_data) - 1)
                bytes_data = bytes_data[:new_len]
        else:
            # Extend
            extend_len = random.randint(1, 100)
            if random.random() < 0.5:
                # Extend with zeros
                bytes_data.extend(b'\x00' * extend_len)
            else:
                # Extend with random
                bytes_data.extend(os.urandom(extend_len))
        
        data['bytes'] = bytes(bytes_data)
        return data
    
    def splice_inputs(self, data):
        """Splice parts from corpus"""
        # This would splice from other corpus inputs
        # For now, just duplicate part of current input
        if 'bytes' in data:
            bytes_data = bytearray(data['bytes'])
            if len(bytes_data) > 8:
                start = random.randint(0, len(bytes_data) - 4)
                length = random.randint(4, min(32, len(bytes_data) - start))
                splice = bytes_data[start:start + length]
                
                insert_pos = random.randint(0, len(bytes_data))
                bytes_data[insert_pos:insert_pos] = splice
                
                data['bytes'] = bytes(bytes_data)
        
        return data
    
    def dictionary_mutation(self, data):
        """Use dictionary tokens"""
        # Camera-specific dictionary tokens
        tokens = [
            b"CAMERA",
            b"POSITION",
            b"ROTATION",
            b"ZOOM",
            b"MATRIX",
            b"QUATERNION",
            b"\x00\x00\x00\x00",  # Zero
            b"\xff\xff\xff\xff",  # -1
            b"\x00\x00\x80\x3f",  # 1.0 float
            b"\x00\x00\x80\xbf",  # -1.0 float
        ]
        
        if 'bytes' in data:
            bytes_data = bytearray(data['bytes'])
            token = random.choice(tokens)
            
            if len(bytes_data) >= len(token):
                pos = random.randint(0, len(bytes_data) - len(token))
                bytes_data[pos:pos + len(token)] = token
            
            data['bytes'] = bytes(bytes_data)
        
        return data
    
    # Helper methods
    
    def load_corpus(self):
        """Load existing corpus"""
        corpus = []
        
        for file_path in self.corpus_dir.glob("*.bin"):
            try:
                input_data = self.read_input_file(file_path)
                corpus.append(input_data)
            except:
                pass
        
        return corpus
    
    def generate_initial_corpus(self):
        """Generate initial corpus if none exists"""
        corpus = []
        
        # Valid inputs
        for i in range(10):
            corpus.append({
                'position': [random.uniform(0, 4096) for _ in range(3)],
                'rotation': self._random_quaternion(),
                'zoom': random.uniform(1, 10)
            })
        
        # Edge cases
        corpus.extend([
            {'position': [0, 0, 10], 'rotation': [1, 0, 0, 0], 'zoom': 1.0},
            {'position': [4096, 4096, 800], 'rotation': [1, 0, 0, 0], 'zoom': 10.0},
            {'position': [2048, 2048, 400], 'rotation': [0, 0, 0, 1], 'zoom': 5.0},
        ])
        
        # Save initial corpus
        for i, input_data in enumerate(corpus):
            filename = self.corpus_dir / f"seed_{i:03d}.bin"
            self.write_input_file(filename, input_data)
        
        return corpus
    
    def write_input_file(self, path, input_data):
        """Write input data to file"""
        with open(path, 'wb') as f:
            if 'bytes' in input_data:
                # Raw bytes
                f.write(input_data['bytes'])
            else:
                # Structured data
                if 'position' in input_data:
                    pos = input_data['position']
                    f.write(struct.pack('3f', *pos))
                
                if 'rotation' in input_data:
                    rot = input_data['rotation']
                    f.write(struct.pack('4f', *rot))
                
                if 'zoom' in input_data:
                    f.write(struct.pack('f', input_data['zoom']))
    
    def read_input_file(self, path):
        """Read input data from file"""
        with open(path, 'rb') as f:
            data = f.read()
        
        # Try to parse as structured data
        if len(data) >= 32:  # 3 floats + 4 floats + 1 float = 32 bytes
            try:
                pos = struct.unpack('3f', data[0:12])
                rot = struct.unpack('4f', data[12:28])
                zoom = struct.unpack('f', data[28:32])[0]
                
                return {
                    'position': list(pos),
                    'rotation': list(rot),
                    'zoom': zoom,
                    'bytes': data
                }
            except:
                pass
        
        # Return as raw bytes
        return {'bytes': data}
    
    def extract_coverage(self, output):
        """Extract coverage information from output"""
        # Look for coverage markers in output
        coverage = []
        
        for line in output.split('\n'):
            if line.startswith('COV:'):
                try:
                    # Parse coverage data
                    parts = line.split(':')[1].strip().split(',')
                    coverage.extend(int(p) for p in parts if p)
                except:
                    pass
        
        return coverage if coverage else None
    
    def hash_coverage(self, coverage):
        """Generate hash of coverage data"""
        coverage_str = ','.join(str(c) for c in sorted(coverage))
        return hashlib.sha256(coverage_str.encode()).hexdigest()
    
    def _random_quaternion(self):
        """Generate random quaternion"""
        u1, u2, u3 = random.random(), random.random(), random.random()
        
        sqrt1_u1 = (1 - u1) ** 0.5
        sqrtu1 = u1 ** 0.5
        
        w = sqrt1_u1 * random.choice([1, -1])
        x = sqrt1_u1 * (2 * u2 - 1)
        y = sqrtu1 * (2 * u3 - 1)
        z = sqrtu1 * random.choice([1, -1])
        
        # Normalize
        norm = (w*w + x*x + y*y + z*z) ** 0.5
        if norm > 0:
            return [w/norm, x/norm, y/norm, z/norm]
        return [1, 0, 0, 0]
    
    def signal_handler(self, signum, frame):
        """Handle shutdown signal"""
        print("\n\nShutting down fuzzer...")
        self.print_stats()
        self.generate_report()
        sys.exit(0)
    
    def print_stats(self):
        """Print current statistics"""
        elapsed = time.time() - self.stats['start_time']
        exec_per_sec = self.stats['total_executions'] / elapsed if elapsed > 0 else 0
        
        print(f"\n--- Fuzzing Statistics ---")
        print(f"Elapsed time: {elapsed:.1f}s")
        print(f"Total executions: {self.stats['total_executions']}")
        print(f"Executions/sec: {exec_per_sec:.1f}")
        print(f"Crashes: {self.stats['crashes']} (unique: {len(self.unique_crashes)})")
        print(f"Timeouts: {self.stats['timeouts']}")
        print(f"Interesting inputs: {self.stats['interesting_inputs']}")
        print(f"Coverage increase: {self.stats['coverage_increase']}")
    
    def generate_report(self):
        """Generate final fuzzing report"""
        report = {
            'timestamp': datetime.now().isoformat(),
            'duration': time.time() - self.stats['start_time'],
            'statistics': self.stats,
            'unique_crashes': len(self.unique_crashes),
            'crash_ids': list(self.unique_crashes),
            'coverage_blocks': len(self.coverage_map),
            'corpus_size': len(list(self.corpus_dir.glob("*.bin")))
        }
        
        report_file = self.crashes_dir / "fuzzing_report.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"\nReport saved to: {report_file}")

def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Camera Controller Fuzzer")
    parser.add_argument("target", help="Target binary to fuzz")
    parser.add_argument("--corpus", default="fuzz_corpus", help="Corpus directory")
    parser.add_argument("--crashes", default="crashes", help="Crashes directory")
    parser.add_argument("--duration", type=int, default=3600, help="Duration in seconds")
    parser.add_argument("--jobs", type=int, default=4, help="Number of parallel jobs")
    
    args = parser.parse_args()
    
    # Validate target
    if not Path(args.target).exists():
        print(f"Error: Target binary not found: {args.target}")
        sys.exit(1)
    
    # Run fuzzer
    fuzzer = CameraFuzzer(args.target, args.corpus, args.crashes)
    fuzzer.run(args.duration, args.jobs)

if __name__ == "__main__":
    main()