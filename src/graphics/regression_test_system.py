#!/usr/bin/env python3
"""
Camera Controller Regression Test System
Automated testing framework for camera functionality
"""

import subprocess
import json
import os
import sys
import time
import numpy as np
from datetime import datetime
from pathlib import Path

class CameraRegressionTester:
    def __init__(self, build_dir=".", output_dir="test_results"):
        self.build_dir = Path(build_dir)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        self.test_executable = self.build_dir / "camera_test"
        self.results = []
        self.baseline_data = None
        
    def load_baseline(self, baseline_file="baseline_metrics.json"):
        """Load baseline metrics for comparison"""
        baseline_path = self.output_dir / baseline_file
        if baseline_path.exists():
            with open(baseline_path, 'r') as f:
                self.baseline_data = json.load(f)
        else:
            print(f"Warning: No baseline found at {baseline_path}")
            
    def run_test_suite(self):
        """Run all camera regression tests"""
        test_cases = [
            self.test_basic_movement,
            self.test_rotation_accuracy,
            self.test_zoom_behavior,
            self.test_constraint_enforcement,
            self.test_performance_metrics,
            self.test_edge_cases,
            self.test_stress_scenarios,
            self.test_interpolation_smoothness,
            self.test_input_responsiveness,
            self.test_memory_stability
        ]
        
        print("Starting Camera Regression Tests...")
        print("=" * 60)
        
        for test_func in test_cases:
            print(f"\nRunning: {test_func.__name__}")
            try:
                result = test_func()
                self.results.append(result)
                
                # Compare with baseline if available
                if self.baseline_data and result['name'] in self.baseline_data:
                    self.compare_with_baseline(result, self.baseline_data[result['name']])
                    
                print(f"✓ {result['status']}: {result['message']}")
            except Exception as e:
                print(f"✗ FAILED: {str(e)}")
                self.results.append({
                    'name': test_func.__name__,
                    'status': 'FAILED',
                    'message': str(e),
                    'timestamp': datetime.now().isoformat()
                })
        
        self.generate_report()
        
    def test_basic_movement(self):
        """Test basic camera movement operations"""
        test_vectors = [
            # (dx, dy, dz, expected_x, expected_y, expected_z)
            (100, 0, 0, 100, 0, 0),
            (0, 100, 0, 100, 100, 0),
            (0, 0, 100, 100, 100, 100),
            (-100, -100, -100, 0, 0, 0),
        ]
        
        results = []
        for dx, dy, dz, exp_x, exp_y, exp_z in test_vectors:
            cmd = [
                str(self.test_executable),
                "--test", "movement",
                "--delta", f"{dx},{dy},{dz}"
            ]
            
            output = subprocess.run(cmd, capture_output=True, text=True)
            if output.returncode == 0:
                # Parse output for actual position
                lines = output.stdout.split('\n')
                for line in lines:
                    if "Final position:" in line:
                        parts = line.split(':')[1].strip().split(',')
                        actual_x = float(parts[0])
                        actual_y = float(parts[1])
                        actual_z = float(parts[2])
                        
                        error = np.sqrt((actual_x - exp_x)**2 + 
                                      (actual_y - exp_y)**2 + 
                                      (actual_z - exp_z)**2)
                        results.append({
                            'input': (dx, dy, dz),
                            'expected': (exp_x, exp_y, exp_z),
                            'actual': (actual_x, actual_y, actual_z),
                            'error': error
                        })
        
        max_error = max(r['error'] for r in results)
        return {
            'name': 'test_basic_movement',
            'status': 'PASSED' if max_error < 0.001 else 'FAILED',
            'message': f"Max position error: {max_error:.6f}",
            'details': results,
            'timestamp': datetime.now().isoformat()
        }
    
    def test_rotation_accuracy(self):
        """Test camera rotation precision"""
        test_angles = [
            (0, 0, 0),
            (90, 0, 0),
            (0, 90, 0),
            (0, 0, 90),
            (45, 45, 0),
            (30, 60, 90),
            (360, 360, 360),  # Full rotations
        ]
        
        results = []
        for pitch, yaw, roll in test_angles:
            cmd = [
                str(self.test_executable),
                "--test", "rotation",
                "--angles", f"{pitch},{yaw},{roll}"
            ]
            
            output = subprocess.run(cmd, capture_output=True, text=True)
            if output.returncode == 0:
                # Parse quaternion output
                lines = output.stdout.split('\n')
                for line in lines:
                    if "Quaternion:" in line:
                        parts = line.split(':')[1].strip().split(',')
                        qw = float(parts[0])
                        qx = float(parts[1])
                        qy = float(parts[2])
                        qz = float(parts[3])
                        
                        # Verify quaternion is normalized
                        norm = np.sqrt(qw**2 + qx**2 + qy**2 + qz**2)
                        results.append({
                            'angles': (pitch, yaw, roll),
                            'quaternion': (qw, qx, qy, qz),
                            'norm': norm,
                            'norm_error': abs(norm - 1.0)
                        })
        
        max_norm_error = max(r['norm_error'] for r in results)
        return {
            'name': 'test_rotation_accuracy',
            'status': 'PASSED' if max_norm_error < 1e-6 else 'FAILED',
            'message': f"Max quaternion norm error: {max_norm_error:.9f}",
            'details': results,
            'timestamp': datetime.now().isoformat()
        }
    
    def test_zoom_behavior(self):
        """Test zoom constraints and behavior"""
        zoom_tests = [
            (0.5, True),    # Below min
            (1.0, True),    # At min
            (5.0, True),    # Normal
            (10.0, True),   # At max
            (15.0, False),  # Above max
            (-1.0, False),  # Negative
        ]
        
        results = []
        for zoom_level, should_succeed in zoom_tests:
            cmd = [
                str(self.test_executable),
                "--test", "zoom",
                "--level", str(zoom_level)
            ]
            
            output = subprocess.run(cmd, capture_output=True, text=True)
            success = output.returncode == 0
            
            if success:
                # Parse actual zoom level
                lines = output.stdout.split('\n')
                for line in lines:
                    if "Zoom level:" in line:
                        actual_zoom = float(line.split(':')[1].strip())
                        results.append({
                            'requested': zoom_level,
                            'actual': actual_zoom,
                            'clamped': zoom_level != actual_zoom,
                            'success': success == should_succeed
                        })
        
        all_passed = all(r['success'] for r in results)
        return {
            'name': 'test_zoom_behavior',
            'status': 'PASSED' if all_passed else 'FAILED',
            'message': f"Zoom constraint tests: {sum(r['success'] for r in results)}/{len(results)} passed",
            'details': results,
            'timestamp': datetime.now().isoformat()
        }
    
    def test_constraint_enforcement(self):
        """Test boundary and constraint enforcement"""
        boundary_tests = [
            # (x, y, z, should_clamp)
            (-100, 500, 50, True),    # Outside X min
            (5000, 500, 50, True),    # Outside X max
            (500, -100, 50, True),    # Outside Y min
            (500, 5000, 50, True),    # Outside Y max
            (500, 500, -10, True),    # Outside Z min
            (500, 500, 1000, True),   # Outside Z max
            (500, 500, 50, False),    # Inside all bounds
        ]
        
        results = []
        for x, y, z, should_clamp in boundary_tests:
            cmd = [
                str(self.test_executable),
                "--test", "constraints",
                "--position", f"{x},{y},{z}"
            ]
            
            output = subprocess.run(cmd, capture_output=True, text=True)
            if output.returncode == 0:
                lines = output.stdout.split('\n')
                for line in lines:
                    if "Clamped position:" in line:
                        parts = line.split(':')[1].strip().split(',')
                        clamped_x = float(parts[0])
                        clamped_y = float(parts[1])
                        clamped_z = float(parts[2])
                        
                        was_clamped = (x != clamped_x or y != clamped_y or z != clamped_z)
                        results.append({
                            'input': (x, y, z),
                            'output': (clamped_x, clamped_y, clamped_z),
                            'clamped': was_clamped,
                            'correct': was_clamped == should_clamp
                        })
        
        all_correct = all(r['correct'] for r in results)
        return {
            'name': 'test_constraint_enforcement',
            'status': 'PASSED' if all_correct else 'FAILED',
            'message': f"Constraint tests: {sum(r['correct'] for r in results)}/{len(results)} correct",
            'details': results,
            'timestamp': datetime.now().isoformat()
        }
    
    def test_performance_metrics(self):
        """Test performance characteristics"""
        iterations = 10000
        operations = [
            "update_position",
            "update_rotation",
            "calculate_matrices",
            "apply_constraints",
            "handle_input"
        ]
        
        results = {}
        for op in operations:
            cmd = [
                str(self.test_executable),
                "--benchmark", op,
                "--iterations", str(iterations)
            ]
            
            output = subprocess.run(cmd, capture_output=True, text=True)
            if output.returncode == 0:
                # Parse timing results
                lines = output.stdout.split('\n')
                for line in lines:
                    if "Average time:" in line:
                        avg_time = float(line.split(':')[1].strip().split()[0])
                        results[op] = {
                            'iterations': iterations,
                            'avg_time_ns': avg_time,
                            'ops_per_sec': 1e9 / avg_time if avg_time > 0 else 0
                        }
        
        # Check if all operations meet performance targets
        perf_targets = {
            'update_position': 100,      # 100ns target
            'update_rotation': 150,      # 150ns target
            'calculate_matrices': 500,   # 500ns target
            'apply_constraints': 200,    # 200ns target
            'handle_input': 300         # 300ns target
        }
        
        all_met = all(
            results.get(op, {}).get('avg_time_ns', float('inf')) <= target
            for op, target in perf_targets.items()
        )
        
        return {
            'name': 'test_performance_metrics',
            'status': 'PASSED' if all_met else 'FAILED',
            'message': f"Performance targets: {sum(1 for op in perf_targets if results.get(op, {}).get('avg_time_ns', float('inf')) <= perf_targets[op])}/{len(perf_targets)} met",
            'details': results,
            'timestamp': datetime.now().isoformat()
        }
    
    def test_edge_cases(self):
        """Test edge cases and corner scenarios"""
        edge_cases = [
            {
                'name': 'zero_movement',
                'test': 'movement',
                'params': '--delta 0,0,0',
                'expected': 'no change'
            },
            {
                'name': 'tiny_movement',
                'test': 'movement',
                'params': '--delta 0.0001,0.0001,0.0001',
                'expected': 'precise handling'
            },
            {
                'name': 'large_movement',
                'test': 'movement',
                'params': '--delta 10000,10000,10000',
                'expected': 'clamping'
            },
            {
                'name': 'gimbal_lock',
                'test': 'rotation',
                'params': '--angles 90,0,0',
                'expected': 'no singularity'
            }
        ]
        
        results = []
        for case in edge_cases:
            cmd = [
                str(self.test_executable),
                "--test", case['test']
            ] + case['params'].split()
            
            output = subprocess.run(cmd, capture_output=True, text=True)
            results.append({
                'case': case['name'],
                'success': output.returncode == 0,
                'output': output.stdout[:200]  # First 200 chars
            })
        
        all_passed = all(r['success'] for r in results)
        return {
            'name': 'test_edge_cases',
            'status': 'PASSED' if all_passed else 'FAILED',
            'message': f"Edge cases: {sum(r['success'] for r in results)}/{len(results)} passed",
            'details': results,
            'timestamp': datetime.now().isoformat()
        }
    
    def test_stress_scenarios(self):
        """Test under stress conditions"""
        stress_tests = [
            {
                'name': 'rapid_updates',
                'iterations': 100000,
                'operation': 'random_movement'
            },
            {
                'name': 'concurrent_access',
                'threads': 8,
                'iterations': 10000
            },
            {
                'name': 'memory_pressure',
                'allocations': 1000000
            }
        ]
        
        results = []
        for test in stress_tests:
            if test['name'] == 'rapid_updates':
                cmd = [
                    str(self.test_executable),
                    "--stress", "rapid",
                    "--iterations", str(test['iterations'])
                ]
            elif test['name'] == 'concurrent_access':
                cmd = [
                    str(self.test_executable),
                    "--stress", "concurrent",
                    "--threads", str(test['threads']),
                    "--iterations", str(test['iterations'])
                ]
            else:
                cmd = [
                    str(self.test_executable),
                    "--stress", "memory",
                    "--allocations", str(test['allocations'])
                ]
            
            start_time = time.time()
            output = subprocess.run(cmd, capture_output=True, text=True)
            duration = time.time() - start_time
            
            results.append({
                'test': test['name'],
                'success': output.returncode == 0,
                'duration': duration,
                'details': test
            })
        
        all_passed = all(r['success'] for r in results)
        return {
            'name': 'test_stress_scenarios',
            'status': 'PASSED' if all_passed else 'FAILED',
            'message': f"Stress tests: {sum(r['success'] for r in results)}/{len(results)} passed",
            'details': results,
            'timestamp': datetime.now().isoformat()
        }
    
    def test_interpolation_smoothness(self):
        """Test interpolation quality"""
        # Test smooth transitions
        cmd = [
            str(self.test_executable),
            "--test", "interpolation",
            "--frames", "60",
            "--start", "0,0,100",
            "--end", "1000,1000,500"
        ]
        
        output = subprocess.run(cmd, capture_output=True, text=True)
        if output.returncode == 0:
            # Parse frame positions
            positions = []
            lines = output.stdout.split('\n')
            for line in lines:
                if "Frame" in line and "position:" in line:
                    parts = line.split('position:')[1].strip().split(',')
                    x = float(parts[0])
                    y = float(parts[1])
                    z = float(parts[2])
                    positions.append((x, y, z))
            
            # Check for smoothness (no sudden jumps)
            max_delta = 0
            for i in range(1, len(positions)):
                dx = positions[i][0] - positions[i-1][0]
                dy = positions[i][1] - positions[i-1][1]
                dz = positions[i][2] - positions[i-1][2]
                delta = np.sqrt(dx**2 + dy**2 + dz**2)
                max_delta = max(max_delta, delta)
            
            # Verify smoothness
            smooth = max_delta < 50  # Max 50 units per frame
            
            return {
                'name': 'test_interpolation_smoothness',
                'status': 'PASSED' if smooth else 'FAILED',
                'message': f"Max frame delta: {max_delta:.2f} units",
                'details': {
                    'frame_count': len(positions),
                    'max_delta': max_delta,
                    'avg_delta': sum(np.sqrt((positions[i][0]-positions[i-1][0])**2 + 
                                           (positions[i][1]-positions[i-1][1])**2 + 
                                           (positions[i][2]-positions[i-1][2])**2) 
                                    for i in range(1, len(positions))) / (len(positions)-1)
                },
                'timestamp': datetime.now().isoformat()
            }
        else:
            return {
                'name': 'test_interpolation_smoothness',
                'status': 'FAILED',
                'message': 'Interpolation test failed to run',
                'timestamp': datetime.now().isoformat()
            }
    
    def test_input_responsiveness(self):
        """Test input handling latency"""
        input_sequences = [
            "WASD",           # Basic movement
            "QE",             # Rotation
            "RF",             # Zoom
            "SHIFT+W",        # Modified input
            "MOUSE_DRAG",     # Mouse input
        ]
        
        results = []
        for sequence in input_sequences:
            cmd = [
                str(self.test_executable),
                "--test", "input_latency",
                "--sequence", sequence
            ]
            
            output = subprocess.run(cmd, capture_output=True, text=True)
            if output.returncode == 0:
                # Parse latency measurements
                lines = output.stdout.split('\n')
                for line in lines:
                    if "Latency:" in line:
                        latency_us = float(line.split(':')[1].strip().split()[0])
                        results.append({
                            'sequence': sequence,
                            'latency_us': latency_us,
                            'meets_target': latency_us < 1000  # 1ms target
                        })
        
        avg_latency = sum(r['latency_us'] for r in results) / len(results) if results else 0
        all_meet_target = all(r['meets_target'] for r in results) if results else False
        
        return {
            'name': 'test_input_responsiveness',
            'status': 'PASSED' if all_meet_target else 'FAILED',
            'message': f"Average input latency: {avg_latency:.2f} μs",
            'details': results,
            'timestamp': datetime.now().isoformat()
        }
    
    def test_memory_stability(self):
        """Test for memory leaks and stability"""
        cmd = [
            str(self.test_executable),
            "--test", "memory_stability",
            "--duration", "10",  # 10 seconds
            "--operations", "1000000"
        ]
        
        output = subprocess.run(cmd, capture_output=True, text=True)
        if output.returncode == 0:
            # Parse memory statistics
            lines = output.stdout.split('\n')
            stats = {}
            for line in lines:
                if "Initial memory:" in line:
                    stats['initial'] = int(line.split(':')[1].strip().split()[0])
                elif "Final memory:" in line:
                    stats['final'] = int(line.split(':')[1].strip().split()[0])
                elif "Peak memory:" in line:
                    stats['peak'] = int(line.split(':')[1].strip().split()[0])
                elif "Allocations:" in line:
                    stats['allocations'] = int(line.split(':')[1].strip())
                elif "Deallocations:" in line:
                    stats['deallocations'] = int(line.split(':')[1].strip())
            
            # Check for leaks
            memory_growth = stats.get('final', 0) - stats.get('initial', 0)
            allocation_balance = stats.get('allocations', 0) - stats.get('deallocations', 0)
            
            no_leak = memory_growth < 1024 and allocation_balance == 0  # Less than 1KB growth
            
            return {
                'name': 'test_memory_stability',
                'status': 'PASSED' if no_leak else 'FAILED',
                'message': f"Memory growth: {memory_growth} bytes, Unbalanced allocations: {allocation_balance}",
                'details': stats,
                'timestamp': datetime.now().isoformat()
            }
        else:
            return {
                'name': 'test_memory_stability',
                'status': 'FAILED',
                'message': 'Memory stability test failed to run',
                'timestamp': datetime.now().isoformat()
            }
    
    def compare_with_baseline(self, current, baseline):
        """Compare current results with baseline"""
        if current['name'] == 'test_performance_metrics':
            # Compare performance metrics
            current_ops = current.get('details', {})
            baseline_ops = baseline.get('details', {})
            
            print("\n  Performance comparison:")
            for op, current_data in current_ops.items():
                if op in baseline_ops:
                    current_time = current_data.get('avg_time_ns', 0)
                    baseline_time = baseline_ops[op].get('avg_time_ns', 0)
                    if baseline_time > 0:
                        change = ((current_time - baseline_time) / baseline_time) * 100
                        symbol = "↑" if change > 0 else "↓"
                        print(f"    {op}: {current_time:.1f}ns ({symbol} {abs(change):.1f}%)")
    
    def generate_report(self):
        """Generate test report"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = self.output_dir / f"regression_report_{timestamp}.json"
        
        # Calculate summary statistics
        total_tests = len(self.results)
        passed_tests = sum(1 for r in self.results if r['status'] == 'PASSED')
        failed_tests = total_tests - passed_tests
        
        report = {
            'timestamp': datetime.now().isoformat(),
            'summary': {
                'total': total_tests,
                'passed': passed_tests,
                'failed': failed_tests,
                'pass_rate': (passed_tests / total_tests * 100) if total_tests > 0 else 0
            },
            'results': self.results
        }
        
        # Save report
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        # Print summary
        print("\n" + "=" * 60)
        print("REGRESSION TEST SUMMARY")
        print("=" * 60)
        print(f"Total Tests: {total_tests}")
        print(f"Passed: {passed_tests} ({report['summary']['pass_rate']:.1f}%)")
        print(f"Failed: {failed_tests}")
        print(f"\nReport saved to: {report_file}")
        
        # Update baseline if all tests passed
        if failed_tests == 0:
            baseline_file = self.output_dir / "baseline_metrics.json"
            baseline_data = {r['name']: r for r in self.results}
            with open(baseline_file, 'w') as f:
                json.dump(baseline_data, f, indent=2)
            print(f"Baseline updated: {baseline_file}")

def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Camera Controller Regression Test System")
    parser.add_argument("--build-dir", default=".", help="Build directory")
    parser.add_argument("--output-dir", default="test_results", help="Output directory")
    parser.add_argument("--baseline", help="Baseline file to compare against")
    
    args = parser.parse_args()
    
    tester = CameraRegressionTester(args.build_dir, args.output_dir)
    
    if args.baseline:
        tester.load_baseline(args.baseline)
    else:
        tester.load_baseline()  # Try default
    
    tester.run_test_suite()

if __name__ == "__main__":
    main()