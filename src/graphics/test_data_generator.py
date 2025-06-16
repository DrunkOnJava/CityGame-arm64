#!/usr/bin/env python3
"""
Test Data Generator for Camera Controller
Generates various test scenarios and input sequences
"""

import numpy as np
import json
import struct
import random
from pathlib import Path
from datetime import datetime

class CameraTestDataGenerator:
    def __init__(self, output_dir="test_data"):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        # Camera constraints (matching assembly code)
        self.min_x, self.max_x = 0, 4096
        self.min_y, self.max_y = 0, 4096
        self.min_z, self.max_z = 10, 800
        self.min_zoom, self.max_zoom = 1.0, 10.0
        
    def generate_all_test_data(self):
        """Generate all test data sets"""
        print("Generating camera test data...")
        
        self.generate_movement_sequences()
        self.generate_rotation_sequences()
        self.generate_zoom_sequences()
        self.generate_input_sequences()
        self.generate_stress_test_data()
        self.generate_edge_case_data()
        self.generate_interpolation_paths()
        self.generate_regression_test_vectors()
        self.generate_performance_benchmark_data()
        self.generate_fuzz_test_seeds()
        
        print(f"Test data generated in {self.output_dir}")
    
    def generate_movement_sequences(self):
        """Generate various movement test sequences"""
        sequences = []
        
        # Linear movements
        for direction in ['north', 'south', 'east', 'west', 'up', 'down']:
            sequence = self._create_linear_movement(direction, steps=100)
            sequences.append({
                'name': f'linear_{direction}',
                'type': 'movement',
                'frames': sequence
            })
        
        # Diagonal movements
        for diagonal in ['ne', 'nw', 'se', 'sw']:
            sequence = self._create_diagonal_movement(diagonal, steps=100)
            sequences.append({
                'name': f'diagonal_{diagonal}',
                'type': 'movement',
                'frames': sequence
            })
        
        # Circular movement
        sequence = self._create_circular_movement(radius=500, steps=360)
        sequences.append({
            'name': 'circular_movement',
            'type': 'movement',
            'frames': sequence
        })
        
        # Spiral movement
        sequence = self._create_spiral_movement(steps=200)
        sequences.append({
            'name': 'spiral_movement',
            'type': 'movement',
            'frames': sequence
        })
        
        # Random walk
        sequence = self._create_random_walk(steps=500)
        sequences.append({
            'name': 'random_walk',
            'type': 'movement',
            'frames': sequence
        })
        
        # Boundary testing
        sequence = self._create_boundary_test_movement()
        sequences.append({
            'name': 'boundary_test',
            'type': 'movement',
            'frames': sequence
        })
        
        # Save sequences
        output_file = self.output_dir / "movement_sequences.json"
        with open(output_file, 'w') as f:
            json.dump(sequences, f, indent=2)
        
        # Also save as binary for direct loading
        self._save_binary_sequences(sequences, "movement_sequences.bin")
    
    def generate_rotation_sequences(self):
        """Generate rotation test sequences"""
        sequences = []
        
        # Single axis rotations
        for axis, angle_delta in [('pitch', 1), ('yaw', 1), ('roll', 1)]:
            sequence = self._create_single_axis_rotation(axis, angle_delta, steps=360)
            sequences.append({
                'name': f'{axis}_rotation',
                'type': 'rotation',
                'frames': sequence
            })
        
        # Combined rotations
        sequence = self._create_combined_rotation(steps=100)
        sequences.append({
            'name': 'combined_rotation',
            'type': 'rotation',
            'frames': sequence
        })
        
        # Gimbal lock test
        sequence = self._create_gimbal_lock_test()
        sequences.append({
            'name': 'gimbal_lock_test',
            'type': 'rotation',
            'frames': sequence
        })
        
        # Quaternion interpolation test
        sequence = self._create_quaternion_interpolation_test()
        sequences.append({
            'name': 'quaternion_interpolation',
            'type': 'rotation',
            'frames': sequence
        })
        
        # Save sequences
        output_file = self.output_dir / "rotation_sequences.json"
        with open(output_file, 'w') as f:
            json.dump(sequences, f, indent=2)
        
        self._save_binary_sequences(sequences, "rotation_sequences.bin")
    
    def generate_zoom_sequences(self):
        """Generate zoom test sequences"""
        sequences = []
        
        # Linear zoom in/out
        sequence = self._create_linear_zoom(start=5.0, end=1.0, steps=60)
        sequences.append({
            'name': 'zoom_in',
            'type': 'zoom',
            'frames': sequence
        })
        
        sequence = self._create_linear_zoom(start=1.0, end=10.0, steps=60)
        sequences.append({
            'name': 'zoom_out',
            'type': 'zoom',
            'frames': sequence
        })
        
        # Zoom oscillation
        sequence = self._create_zoom_oscillation(steps=120)
        sequences.append({
            'name': 'zoom_oscillation',
            'type': 'zoom',
            'frames': sequence
        })
        
        # Zoom constraint testing
        sequence = self._create_zoom_constraint_test()
        sequences.append({
            'name': 'zoom_constraints',
            'type': 'zoom',
            'frames': sequence
        })
        
        # Save sequences
        output_file = self.output_dir / "zoom_sequences.json"
        with open(output_file, 'w') as f:
            json.dump(sequences, f, indent=2)
        
        self._save_binary_sequences(sequences, "zoom_sequences.bin")
    
    def generate_input_sequences(self):
        """Generate user input test sequences"""
        sequences = []
        
        # Keyboard sequences
        keyboard_patterns = [
            "WWWWW",           # Forward movement
            "SSSSSS",          # Backward movement
            "ADADAD",          # Left-right alternation
            "WASDWASD",        # Circle strafe
            "W+SHIFT",         # Modified movement
            "QQQEEE",          # Rotation
            "RFRF",            # Zoom in/out
        ]
        
        for pattern in keyboard_patterns:
            sequence = self._create_keyboard_sequence(pattern)
            sequences.append({
                'name': f'keyboard_{pattern.replace("+", "_")}',
                'type': 'keyboard',
                'inputs': sequence
            })
        
        # Mouse sequences
        mouse_patterns = [
            'drag_horizontal',
            'drag_vertical',
            'drag_diagonal',
            'click_and_drag',
            'double_click',
            'scroll_up',
            'scroll_down',
        ]
        
        for pattern in mouse_patterns:
            sequence = self._create_mouse_sequence(pattern)
            sequences.append({
                'name': f'mouse_{pattern}',
                'type': 'mouse',
                'inputs': sequence
            })
        
        # Combined input
        sequence = self._create_combined_input_sequence()
        sequences.append({
            'name': 'combined_input',
            'type': 'combined',
            'inputs': sequence
        })
        
        # Save sequences
        output_file = self.output_dir / "input_sequences.json"
        with open(output_file, 'w') as f:
            json.dump(sequences, f, indent=2)
    
    def generate_stress_test_data(self):
        """Generate stress test scenarios"""
        stress_tests = []
        
        # Rapid movement changes
        test = {
            'name': 'rapid_direction_changes',
            'type': 'stress',
            'duration_seconds': 10,
            'operations_per_second': 1000,
            'pattern': 'random_direction'
        }
        stress_tests.append(test)
        
        # Maximum speed movement
        test = {
            'name': 'maximum_speed',
            'type': 'stress',
            'duration_seconds': 30,
            'speed_multiplier': 10.0,
            'pattern': 'continuous_movement'
        }
        stress_tests.append(test)
        
        # Concurrent operations
        test = {
            'name': 'concurrent_operations',
            'type': 'stress',
            'thread_count': 8,
            'operations_per_thread': 10000,
            'operation_types': ['move', 'rotate', 'zoom', 'query']
        }
        stress_tests.append(test)
        
        # Memory pressure
        test = {
            'name': 'memory_pressure',
            'type': 'stress',
            'allocation_count': 1000000,
            'allocation_pattern': 'random_size',
            'min_size': 16,
            'max_size': 4096
        }
        stress_tests.append(test)
        
        # Save stress tests
        output_file = self.output_dir / "stress_tests.json"
        with open(output_file, 'w') as f:
            json.dump(stress_tests, f, indent=2)
    
    def generate_edge_case_data(self):
        """Generate edge case test data"""
        edge_cases = []
        
        # Extreme positions
        positions = [
            (0, 0, 10),                              # Minimum corner
            (4096, 4096, 800),                       # Maximum corner
            (-100, 2048, 400),                       # Outside bounds X
            (2048, -100, 400),                       # Outside bounds Y
            (2048, 2048, -50),                       # Outside bounds Z low
            (2048, 2048, 1000),                      # Outside bounds Z high
            (float('inf'), 0, 0),                    # Infinity
            (float('nan'), 0, 0),                    # NaN
            (1e-10, 1e-10, 1e-10),                  # Very small values
            (1e10, 1e10, 1e10),                     # Very large values
        ]
        
        for i, pos in enumerate(positions):
            edge_cases.append({
                'name': f'extreme_position_{i}',
                'type': 'position',
                'value': pos,
                'expected_behavior': 'clamp_or_reject'
            })
        
        # Extreme rotations
        rotations = [
            (0, 0, 0, 1),                            # Identity quaternion
            (1, 0, 0, 0),                            # 180 degree rotation
            (0.7071, 0, 0.7071, 0),                  # 90 degree pitch
            (0, 0, 0, 0),                            # Invalid quaternion
            (2, 0, 0, 0),                            # Non-normalized
        ]
        
        for i, quat in enumerate(rotations):
            edge_cases.append({
                'name': f'extreme_rotation_{i}',
                'type': 'rotation',
                'value': quat,
                'expected_behavior': 'normalize_or_reject'
            })
        
        # Extreme zoom values
        zoom_values = [0, -1, 0.5, 1.0, 10.0, 15.0, float('inf'), float('nan')]
        
        for i, zoom in enumerate(zoom_values):
            edge_cases.append({
                'name': f'extreme_zoom_{i}',
                'type': 'zoom',
                'value': zoom,
                'expected_behavior': 'clamp_or_reject'
            })
        
        # Save edge cases
        output_file = self.output_dir / "edge_cases.json"
        with open(output_file, 'w') as f:
            json.dump(edge_cases, f, indent=2)
    
    def generate_interpolation_paths(self):
        """Generate smooth interpolation test paths"""
        paths = []
        
        # Linear interpolation path
        path = {
            'name': 'linear_interpolation',
            'type': 'linear',
            'waypoints': [
                {'position': [0, 0, 100], 'rotation': [0, 0, 0, 1], 'zoom': 5.0, 'time': 0},
                {'position': [1000, 1000, 200], 'rotation': [0, 0.7071, 0, 0.7071], 'zoom': 3.0, 'time': 2},
                {'position': [2000, 500, 150], 'rotation': [0, 1, 0, 0], 'zoom': 7.0, 'time': 4},
                {'position': [1000, 0, 100], 'rotation': [0, 0.7071, 0, -0.7071], 'zoom': 5.0, 'time': 6},
                {'position': [0, 0, 100], 'rotation': [0, 0, 0, 1], 'zoom': 5.0, 'time': 8},
            ]
        }
        paths.append(path)
        
        # Bezier curve path
        path = self._create_bezier_path()
        paths.append(path)
        
        # Spline path
        path = self._create_spline_path()
        paths.append(path)
        
        # Save paths
        output_file = self.output_dir / "interpolation_paths.json"
        with open(output_file, 'w') as f:
            json.dump(paths, f, indent=2)
    
    def generate_regression_test_vectors(self):
        """Generate regression test vectors with expected outputs"""
        vectors = []
        
        # Movement vectors
        movement_tests = [
            {
                'input': {'dx': 100, 'dy': 0, 'dz': 0},
                'initial': {'x': 0, 'y': 0, 'z': 100},
                'expected': {'x': 100, 'y': 0, 'z': 100}
            },
            {
                'input': {'dx': -200, 'dy': 0, 'dz': 0},
                'initial': {'x': 100, 'y': 0, 'z': 100},
                'expected': {'x': 0, 'y': 0, 'z': 100}  # Clamped to min
            },
            {
                'input': {'dx': 5000, 'dy': 5000, 'dz': 1000},
                'initial': {'x': 0, 'y': 0, 'z': 100},
                'expected': {'x': 4096, 'y': 4096, 'z': 800}  # Clamped to max
            }
        ]
        
        for i, test in enumerate(movement_tests):
            vectors.append({
                'name': f'movement_vector_{i}',
                'type': 'movement',
                'test': test
            })
        
        # Rotation vectors (euler to quaternion)
        rotation_tests = [
            {
                'input': {'pitch': 0, 'yaw': 0, 'roll': 0},
                'expected': {'w': 1, 'x': 0, 'y': 0, 'z': 0}
            },
            {
                'input': {'pitch': 90, 'yaw': 0, 'roll': 0},
                'expected': {'w': 0.7071, 'x': 0.7071, 'y': 0, 'z': 0}
            },
            {
                'input': {'pitch': 0, 'yaw': 90, 'roll': 0},
                'expected': {'w': 0.7071, 'x': 0, 'y': 0.7071, 'z': 0}
            }
        ]
        
        for i, test in enumerate(rotation_tests):
            vectors.append({
                'name': f'rotation_vector_{i}',
                'type': 'rotation',
                'test': test
            })
        
        # Matrix calculation vectors
        matrix_tests = self._generate_matrix_test_vectors()
        vectors.extend(matrix_tests)
        
        # Save vectors
        output_file = self.output_dir / "regression_vectors.json"
        with open(output_file, 'w') as f:
            json.dump(vectors, f, indent=2)
    
    def generate_performance_benchmark_data(self):
        """Generate data for performance benchmarking"""
        benchmarks = []
        
        # Operation counts for different scales
        scales = [1000, 10000, 100000, 1000000]
        
        for scale in scales:
            benchmark = {
                'name': f'scale_{scale}',
                'operations': scale,
                'tests': [
                    {
                        'name': 'position_updates',
                        'operation': 'update_position',
                        'iterations': scale,
                        'warmup': 1000
                    },
                    {
                        'name': 'rotation_updates',
                        'operation': 'update_rotation',
                        'iterations': scale,
                        'warmup': 1000
                    },
                    {
                        'name': 'matrix_calculations',
                        'operation': 'calculate_matrices',
                        'iterations': scale // 10,  # More expensive
                        'warmup': 100
                    },
                    {
                        'name': 'full_update_cycle',
                        'operation': 'full_update',
                        'iterations': scale // 100,
                        'warmup': 10
                    }
                ]
            }
            benchmarks.append(benchmark)
        
        # Save benchmarks
        output_file = self.output_dir / "performance_benchmarks.json"
        with open(output_file, 'w') as f:
            json.dump(benchmarks, f, indent=2)
    
    def generate_fuzz_test_seeds(self):
        """Generate seeds for fuzzing"""
        seeds = []
        
        # Random valid inputs
        for i in range(100):
            seed = {
                'id': i,
                'type': 'valid_random',
                'position': [
                    random.uniform(0, 4096),
                    random.uniform(0, 4096),
                    random.uniform(10, 800)
                ],
                'rotation': self._random_quaternion(),
                'zoom': random.uniform(1.0, 10.0)
            }
            seeds.append(seed)
        
        # Boundary values
        boundary_positions = [
            [0, 0, 10],
            [4096, 4096, 800],
            [0, 4096, 10],
            [4096, 0, 800],
            [2048, 2048, 400]
        ]
        
        for i, pos in enumerate(boundary_positions):
            seed = {
                'id': 100 + i,
                'type': 'boundary',
                'position': pos,
                'rotation': self._random_quaternion(),
                'zoom': random.choice([1.0, 5.0, 10.0])
            }
            seeds.append(seed)
        
        # Invalid/malformed inputs
        for i in range(50):
            seed = {
                'id': 200 + i,
                'type': 'invalid',
                'position': self._random_invalid_position(),
                'rotation': self._random_invalid_quaternion(),
                'zoom': self._random_invalid_zoom()
            }
            seeds.append(seed)
        
        # Save seeds
        output_file = self.output_dir / "fuzz_seeds.json"
        with open(output_file, 'w') as f:
            json.dump(seeds, f, indent=2)
        
        # Also save as binary corpus
        self._save_binary_fuzz_corpus(seeds)
    
    # Helper methods
    
    def _create_linear_movement(self, direction, steps):
        """Create linear movement sequence"""
        frames = []
        delta = {'north': (0, 10, 0), 'south': (0, -10, 0),
                'east': (10, 0, 0), 'west': (-10, 0, 0),
                'up': (0, 0, 5), 'down': (0, 0, -5)}[direction]
        
        for i in range(steps):
            frames.append({
                'frame': i,
                'delta_position': list(delta),
                'delta_rotation': [0, 0, 0],
                'delta_zoom': 0
            })
        
        return frames
    
    def _create_diagonal_movement(self, diagonal, steps):
        """Create diagonal movement sequence"""
        frames = []
        delta = {'ne': (7, 7, 0), 'nw': (-7, 7, 0),
                'se': (7, -7, 0), 'sw': (-7, -7, 0)}[diagonal]
        
        for i in range(steps):
            frames.append({
                'frame': i,
                'delta_position': list(delta),
                'delta_rotation': [0, 0, 0],
                'delta_zoom': 0
            })
        
        return frames
    
    def _create_circular_movement(self, radius, steps):
        """Create circular movement pattern"""
        frames = []
        center_x, center_y = 2048, 2048
        
        for i in range(steps):
            angle = (i / steps) * 2 * np.pi
            x = center_x + radius * np.cos(angle)
            y = center_y + radius * np.sin(angle)
            
            if i == 0:
                prev_x, prev_y = x, y
            else:
                prev_angle = ((i-1) / steps) * 2 * np.pi
                prev_x = center_x + radius * np.cos(prev_angle)
                prev_y = center_y + radius * np.sin(prev_angle)
            
            frames.append({
                'frame': i,
                'delta_position': [x - prev_x, y - prev_y, 0],
                'delta_rotation': [0, 0, 0],
                'delta_zoom': 0
            })
        
        return frames
    
    def _create_spiral_movement(self, steps):
        """Create spiral movement pattern"""
        frames = []
        center_x, center_y = 2048, 2048
        max_radius = 1000
        
        for i in range(steps):
            t = i / steps
            radius = max_radius * t
            angle = t * 4 * np.pi
            
            x = center_x + radius * np.cos(angle)
            y = center_y + radius * np.sin(angle)
            z = 100 + 300 * t  # Ascending spiral
            
            if i == 0:
                prev_x, prev_y, prev_z = x, y, z
            else:
                prev_t = (i-1) / steps
                prev_radius = max_radius * prev_t
                prev_angle = prev_t * 4 * np.pi
                prev_x = center_x + prev_radius * np.cos(prev_angle)
                prev_y = center_y + prev_radius * np.sin(prev_angle)
                prev_z = 100 + 300 * prev_t
            
            frames.append({
                'frame': i,
                'delta_position': [x - prev_x, y - prev_y, z - prev_z],
                'delta_rotation': [0, 0, 0],
                'delta_zoom': 0
            })
        
        return frames
    
    def _create_random_walk(self, steps):
        """Create random walk movement"""
        frames = []
        
        for i in range(steps):
            frames.append({
                'frame': i,
                'delta_position': [
                    random.uniform(-20, 20),
                    random.uniform(-20, 20),
                    random.uniform(-5, 5)
                ],
                'delta_rotation': [0, 0, 0],
                'delta_zoom': 0
            })
        
        return frames
    
    def _create_boundary_test_movement(self):
        """Create movement that tests boundaries"""
        frames = []
        
        # Test each boundary
        test_positions = [
            # Move to each corner
            (0, 0, 10),
            (4096, 0, 10),
            (4096, 4096, 10),
            (0, 4096, 10),
            # Test Z boundaries
            (2048, 2048, 10),
            (2048, 2048, 800),
            # Try to exceed boundaries
            (-100, 2048, 400),
            (5000, 2048, 400),
            (2048, -100, 400),
            (2048, 5000, 400),
            (2048, 2048, -50),
            (2048, 2048, 1000),
        ]
        
        current_pos = [2048, 2048, 400]
        for i, target_pos in enumerate(test_positions):
            delta = [
                target_pos[0] - current_pos[0],
                target_pos[1] - current_pos[1],
                target_pos[2] - current_pos[2]
            ]
            
            frames.append({
                'frame': i,
                'delta_position': delta,
                'delta_rotation': [0, 0, 0],
                'delta_zoom': 0,
                'expected_clamping': True if any(p < 0 or p > 4096 for p in target_pos[:2]) or target_pos[2] < 10 or target_pos[2] > 800 else False
            })
            
            # Update current position (with clamping)
            current_pos = [
                max(0, min(4096, target_pos[0])),
                max(0, min(4096, target_pos[1])),
                max(10, min(800, target_pos[2]))
            ]
        
        return frames
    
    def _create_single_axis_rotation(self, axis, angle_delta, steps):
        """Create single axis rotation sequence"""
        frames = []
        
        for i in range(steps):
            delta_rotation = [0, 0, 0]
            if axis == 'pitch':
                delta_rotation[0] = angle_delta
            elif axis == 'yaw':
                delta_rotation[1] = angle_delta
            elif axis == 'roll':
                delta_rotation[2] = angle_delta
            
            frames.append({
                'frame': i,
                'delta_position': [0, 0, 0],
                'delta_rotation': delta_rotation,
                'delta_zoom': 0
            })
        
        return frames
    
    def _create_combined_rotation(self, steps):
        """Create combined rotation sequence"""
        frames = []
        
        for i in range(steps):
            t = i / steps
            frames.append({
                'frame': i,
                'delta_position': [0, 0, 0],
                'delta_rotation': [
                    np.sin(t * 2 * np.pi) * 2,
                    np.cos(t * 2 * np.pi) * 2,
                    np.sin(t * 4 * np.pi) * 1
                ],
                'delta_zoom': 0
            })
        
        return frames
    
    def _create_gimbal_lock_test(self):
        """Create gimbal lock test sequence"""
        frames = []
        
        # Approach gimbal lock
        for i in range(90):
            frames.append({
                'frame': i,
                'delta_position': [0, 0, 0],
                'delta_rotation': [1, 0, 0],  # Pitch up to 90 degrees
                'delta_zoom': 0
            })
        
        # Try to yaw at 90 degree pitch
        for i in range(90, 180):
            frames.append({
                'frame': i,
                'delta_position': [0, 0, 0],
                'delta_rotation': [0, 1, 0],  # Yaw (should behave differently)
                'delta_zoom': 0
            })
        
        return frames
    
    def _create_quaternion_interpolation_test(self):
        """Create quaternion interpolation test"""
        frames = []
        
        # Define key quaternions
        quaternions = [
            [1, 0, 0, 0],  # Identity
            [0.7071, 0.7071, 0, 0],  # 90 degree X rotation
            [0.7071, 0, 0.7071, 0],  # 90 degree Y rotation
            [0.7071, 0, 0, 0.7071],  # 90 degree Z rotation
            [0.5, 0.5, 0.5, 0.5],    # Combined rotation
            [1, 0, 0, 0],  # Back to identity
        ]
        
        # Interpolate between quaternions
        for i in range(len(quaternions) - 1):
            q1 = np.array(quaternions[i])
            q2 = np.array(quaternions[i + 1])
            
            for j in range(20):  # 20 frames between each pair
                t = j / 20.0
                # Spherical linear interpolation
                q_interp = self._slerp(q1, q2, t)
                
                frames.append({
                    'frame': i * 20 + j,
                    'delta_position': [0, 0, 0],
                    'target_quaternion': q_interp.tolist(),
                    'delta_zoom': 0
                })
        
        return frames
    
    def _create_linear_zoom(self, start, end, steps):
        """Create linear zoom sequence"""
        frames = []
        
        for i in range(steps):
            t = i / (steps - 1)
            zoom = start + (end - start) * t
            
            frames.append({
                'frame': i,
                'delta_position': [0, 0, 0],
                'delta_rotation': [0, 0, 0],
                'target_zoom': zoom
            })
        
        return frames
    
    def _create_zoom_oscillation(self, steps):
        """Create zoom oscillation sequence"""
        frames = []
        
        for i in range(steps):
            t = i / steps
            zoom = 5.5 + 4.5 * np.sin(t * 4 * np.pi)  # Oscillate between 1 and 10
            
            frames.append({
                'frame': i,
                'delta_position': [0, 0, 0],
                'delta_rotation': [0, 0, 0],
                'target_zoom': zoom
            })
        
        return frames
    
    def _create_zoom_constraint_test(self):
        """Test zoom constraints"""
        frames = []
        
        # Test values that should be clamped
        test_zooms = [-1, 0, 0.5, 1.0, 5.0, 10.0, 15.0, 100.0]
        
        for i, zoom in enumerate(test_zooms):
            frames.append({
                'frame': i,
                'delta_position': [0, 0, 0],
                'delta_rotation': [0, 0, 0],
                'target_zoom': zoom,
                'expected_zoom': max(1.0, min(10.0, zoom))
            })
        
        return frames
    
    def _create_keyboard_sequence(self, pattern):
        """Create keyboard input sequence"""
        inputs = []
        
        for i, char in enumerate(pattern):
            if char == '+':
                continue  # Skip modifier separator
            
            is_modified = i > 0 and pattern[i-1] == '+'
            modifier = 'SHIFT' if is_modified else None
            
            inputs.append({
                'frame': i,
                'type': 'keyboard',
                'key': char,
                'action': 'press',
                'modifier': modifier
            })
            
            inputs.append({
                'frame': i + 0.5,
                'type': 'keyboard',
                'key': char,
                'action': 'release',
                'modifier': modifier
            })
        
        return inputs
    
    def _create_mouse_sequence(self, pattern):
        """Create mouse input sequence"""
        inputs = []
        
        if pattern == 'drag_horizontal':
            for i in range(100):
                inputs.append({
                    'frame': i,
                    'type': 'mouse',
                    'action': 'move',
                    'position': [100 + i * 5, 300],
                    'buttons': ['left']
                })
        
        elif pattern == 'drag_vertical':
            for i in range(100):
                inputs.append({
                    'frame': i,
                    'type': 'mouse',
                    'action': 'move',
                    'position': [300, 100 + i * 5],
                    'buttons': ['left']
                })
        
        elif pattern == 'drag_diagonal':
            for i in range(100):
                inputs.append({
                    'frame': i,
                    'type': 'mouse',
                    'action': 'move',
                    'position': [100 + i * 5, 100 + i * 5],
                    'buttons': ['left']
                })
        
        elif pattern == 'click_and_drag':
            inputs.append({
                'frame': 0,
                'type': 'mouse',
                'action': 'press',
                'position': [200, 200],
                'button': 'left'
            })
            
            for i in range(1, 50):
                inputs.append({
                    'frame': i,
                    'type': 'mouse',
                    'action': 'move',
                    'position': [200 + i * 2, 200 + i * 2],
                    'buttons': ['left']
                })
            
            inputs.append({
                'frame': 50,
                'type': 'mouse',
                'action': 'release',
                'position': [300, 300],
                'button': 'left'
            })
        
        elif pattern == 'double_click':
            for i in range(2):
                inputs.append({
                    'frame': i * 0.2,
                    'type': 'mouse',
                    'action': 'press',
                    'position': [400, 400],
                    'button': 'left'
                })
                inputs.append({
                    'frame': i * 0.2 + 0.1,
                    'type': 'mouse',
                    'action': 'release',
                    'position': [400, 400],
                    'button': 'left'
                })
        
        elif pattern in ['scroll_up', 'scroll_down']:
            direction = 1 if pattern == 'scroll_up' else -1
            for i in range(10):
                inputs.append({
                    'frame': i * 0.1,
                    'type': 'mouse',
                    'action': 'scroll',
                    'position': [400, 400],
                    'delta': [0, direction * 10]
                })
        
        return inputs
    
    def _create_combined_input_sequence(self):
        """Create combined keyboard and mouse input"""
        inputs = []
        
        # Move with keyboard while rotating with mouse
        for i in range(60):
            # Keyboard movement
            if i % 10 < 5:
                inputs.append({
                    'frame': i,
                    'type': 'keyboard',
                    'key': 'W',
                    'action': 'press'
                })
            else:
                inputs.append({
                    'frame': i,
                    'type': 'keyboard',
                    'key': 'W',
                    'action': 'release'
                })
            
            # Mouse rotation
            inputs.append({
                'frame': i,
                'type': 'mouse',
                'action': 'move',
                'position': [400 + np.sin(i * 0.1) * 100, 300],
                'buttons': ['right']
            })
        
        return inputs
    
    def _create_bezier_path(self):
        """Create Bezier curve path"""
        control_points = [
            [0, 0, 100],
            [1000, 500, 200],
            [2000, 2000, 300],
            [3000, 1500, 150],
            [4000, 4000, 100]
        ]
        
        waypoints = []
        num_segments = 50
        
        for i in range(num_segments + 1):
            t = i / num_segments
            pos = self._bezier_point(control_points, t)
            
            waypoints.append({
                'position': pos,
                'rotation': [0, t * np.pi, 0, 1],  # Rotate during movement
                'zoom': 5.0 + 3.0 * np.sin(t * np.pi),
                'time': t * 10.0  # 10 second path
            })
        
        return {
            'name': 'bezier_path',
            'type': 'bezier',
            'control_points': control_points,
            'waypoints': waypoints
        }
    
    def _create_spline_path(self):
        """Create spline interpolation path"""
        key_points = [
            {'position': [500, 500, 100], 'time': 0},
            {'position': [1500, 1000, 200], 'time': 2},
            {'position': [2500, 2500, 300], 'time': 4},
            {'position': [3500, 2000, 200], 'time': 6},
            {'position': [2500, 500, 100], 'time': 8},
            {'position': [500, 500, 100], 'time': 10}
        ]
        
        # Generate smooth spline through points
        waypoints = []
        for i in range(101):  # 100 segments
            t = i / 100.0 * 10.0  # 0 to 10 seconds
            
            # Find surrounding key points
            for j in range(len(key_points) - 1):
                if key_points[j]['time'] <= t <= key_points[j+1]['time']:
                    t_local = (t - key_points[j]['time']) / (key_points[j+1]['time'] - key_points[j]['time'])
                    
                    # Catmull-Rom spline interpolation
                    p0 = key_points[max(0, j-1)]['position']
                    p1 = key_points[j]['position']
                    p2 = key_points[j+1]['position']
                    p3 = key_points[min(len(key_points)-1, j+2)]['position']
                    
                    pos = self._catmull_rom(p0, p1, p2, p3, t_local)
                    
                    waypoints.append({
                        'position': pos,
                        'rotation': [0, 0, 0, 1],
                        'zoom': 5.0,
                        'time': t
                    })
                    break
        
        return {
            'name': 'spline_path',
            'type': 'spline',
            'key_points': key_points,
            'waypoints': waypoints
        }
    
    def _generate_matrix_test_vectors(self):
        """Generate matrix calculation test vectors"""
        vectors = []
        
        # View matrix tests
        view_tests = [
            {
                'position': [0, 0, 0],
                'rotation': [1, 0, 0, 0],  # Identity
                'expected_view': [
                    [1, 0, 0, 0],
                    [0, 1, 0, 0],
                    [0, 0, 1, 0],
                    [0, 0, 0, 1]
                ]
            },
            {
                'position': [100, 200, 300],
                'rotation': [1, 0, 0, 0],  # Identity
                'expected_view': [
                    [1, 0, 0, -100],
                    [0, 1, 0, -200],
                    [0, 0, 1, -300],
                    [0, 0, 0, 1]
                ]
            }
        ]
        
        for i, test in enumerate(view_tests):
            vectors.append({
                'name': f'view_matrix_{i}',
                'type': 'matrix',
                'subtype': 'view',
                'test': test
            })
        
        # Projection matrix tests
        proj_tests = [
            {
                'fov': 60,
                'aspect': 16/9,
                'near': 0.1,
                'far': 1000,
                'expected_elements': {
                    '00': 1.299,  # Approximate values
                    '11': 2.309,
                    '22': -1.0002,
                    '23': -0.20002
                }
            }
        ]
        
        for i, test in enumerate(proj_tests):
            vectors.append({
                'name': f'projection_matrix_{i}',
                'type': 'matrix',
                'subtype': 'projection',
                'test': test
            })
        
        return vectors
    
    def _random_quaternion(self):
        """Generate random normalized quaternion"""
        # Generate random unit quaternion using uniform distribution
        u1, u2, u3 = np.random.random(3)
        
        sqrt1_u1 = np.sqrt(1 - u1)
        sqrtu1 = np.sqrt(u1)
        
        w = sqrt1_u1 * np.sin(2 * np.pi * u2)
        x = sqrt1_u1 * np.cos(2 * np.pi * u2)
        y = sqrtu1 * np.sin(2 * np.pi * u3)
        z = sqrtu1 * np.cos(2 * np.pi * u3)
        
        return [w, x, y, z]
    
    def _random_invalid_position(self):
        """Generate random invalid position"""
        invalid_types = ['nan', 'inf', 'huge', 'tiny', 'negative']
        choice = random.choice(invalid_types)
        
        if choice == 'nan':
            return [float('nan'), random.uniform(0, 4096), random.uniform(10, 800)]
        elif choice == 'inf':
            return [float('inf'), random.uniform(0, 4096), random.uniform(10, 800)]
        elif choice == 'huge':
            return [1e20, 1e20, 1e20]
        elif choice == 'tiny':
            return [1e-20, 1e-20, 1e-20]
        elif choice == 'negative':
            return [-1000, -1000, -100]
    
    def _random_invalid_quaternion(self):
        """Generate random invalid quaternion"""
        invalid_types = ['zero', 'huge', 'nan']
        choice = random.choice(invalid_types)
        
        if choice == 'zero':
            return [0, 0, 0, 0]
        elif choice == 'huge':
            return [100, 100, 100, 100]
        elif choice == 'nan':
            return [float('nan'), 0, 0, 0]
    
    def _random_invalid_zoom(self):
        """Generate random invalid zoom value"""
        return random.choice([float('nan'), float('inf'), -10, 0, 1000])
    
    def _slerp(self, q1, q2, t):
        """Spherical linear interpolation between quaternions"""
        # Normalize quaternions
        q1 = q1 / np.linalg.norm(q1)
        q2 = q2 / np.linalg.norm(q2)
        
        # Compute dot product
        dot = np.dot(q1, q2)
        
        # If negative dot, negate one quaternion
        if dot < 0:
            q2 = -q2
            dot = -dot
        
        # Clamp dot product
        dot = np.clip(dot, -1, 1)
        
        # Calculate interpolation
        if dot > 0.9995:
            # Linear interpolation for very close quaternions
            result = q1 + t * (q2 - q1)
        else:
            # Spherical interpolation
            theta = np.arccos(dot)
            sin_theta = np.sin(theta)
            
            w1 = np.sin((1 - t) * theta) / sin_theta
            w2 = np.sin(t * theta) / sin_theta
            
            result = w1 * q1 + w2 * q2
        
        return result / np.linalg.norm(result)
    
    def _bezier_point(self, control_points, t):
        """Calculate point on Bezier curve"""
        n = len(control_points) - 1
        point = np.zeros(3)
        
        for i, cp in enumerate(control_points):
            # Bernstein polynomial
            coeff = self._binomial(n, i) * (1 - t)**(n - i) * t**i
            point += coeff * np.array(cp)
        
        return point.tolist()
    
    def _catmull_rom(self, p0, p1, p2, p3, t):
        """Catmull-Rom spline interpolation"""
        p0, p1, p2, p3 = map(np.array, [p0, p1, p2, p3])
        
        v0 = (p2 - p0) * 0.5
        v1 = (p3 - p1) * 0.5
        
        t2 = t * t
        t3 = t2 * t
        
        return (
            p1 +
            v0 * t +
            (3 * (p2 - p1) - 2 * v0 - v1) * t2 +
            (2 * (p1 - p2) + v0 + v1) * t3
        ).tolist()
    
    def _binomial(self, n, k):
        """Binomial coefficient"""
        if k > n:
            return 0
        if k == 0 or k == n:
            return 1
        
        result = 1
        for i in range(min(k, n - k)):
            result = result * (n - i) // (i + 1)
        
        return result
    
    def _save_binary_sequences(self, sequences, filename):
        """Save sequences as binary file for faster loading"""
        binary_file = self.output_dir / filename
        
        with open(binary_file, 'wb') as f:
            # Write header
            f.write(struct.pack('I', len(sequences)))  # Number of sequences
            
            for seq in sequences:
                # Write sequence name (max 64 chars)
                name_bytes = seq['name'].encode('utf-8')[:64]
                f.write(struct.pack('64s', name_bytes))
                
                # Write sequence type (max 32 chars)
                type_bytes = seq['type'].encode('utf-8')[:32]
                f.write(struct.pack('32s', type_bytes))
                
                # Write frame count
                frames = seq.get('frames', seq.get('inputs', []))
                f.write(struct.pack('I', len(frames)))
                
                # Write frame data
                for frame in frames:
                    # Pack frame data based on type
                    if seq['type'] in ['movement', 'rotation', 'zoom']:
                        f.write(struct.pack('I', frame.get('frame', 0)))
                        
                        delta_pos = frame.get('delta_position', [0, 0, 0])
                        f.write(struct.pack('3f', *delta_pos))
                        
                        delta_rot = frame.get('delta_rotation', [0, 0, 0])
                        f.write(struct.pack('3f', *delta_rot))
                        
                        delta_zoom = frame.get('delta_zoom', 0)
                        target_zoom = frame.get('target_zoom', 0)
                        f.write(struct.pack('2f', delta_zoom, target_zoom))
    
    def _save_binary_fuzz_corpus(self, seeds):
        """Save fuzz test corpus as binary files"""
        corpus_dir = self.output_dir / "fuzz_corpus"
        corpus_dir.mkdir(exist_ok=True)
        
        for seed in seeds:
            filename = corpus_dir / f"seed_{seed['id']:04d}.bin"
            
            with open(filename, 'wb') as f:
                # Write position (3 floats)
                pos = seed['position']
                f.write(struct.pack('3f', *pos))
                
                # Write rotation (4 floats)
                rot = seed['rotation']
                f.write(struct.pack('4f', *rot))
                
                # Write zoom (1 float)
                zoom = seed['zoom']
                f.write(struct.pack('f', zoom))

def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Generate test data for camera controller")
    parser.add_argument("--output-dir", default="test_data", help="Output directory")
    parser.add_argument("--seed", type=int, default=42, help="Random seed")
    
    args = parser.parse_args()
    
    # Set random seed for reproducibility
    random.seed(args.seed)
    np.random.seed(args.seed)
    
    generator = CameraTestDataGenerator(args.output_dir)
    generator.generate_all_test_data()

if __name__ == "__main__":
    main()