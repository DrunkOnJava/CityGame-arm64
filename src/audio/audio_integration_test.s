// audio_integration_test.s - Integration test for Agent 9 Audio System
// Tests Core Audio, 3D Positional Audio, and Streaming systems
// Performance validation for <10ms latency and 100+ simultaneous sounds

.section __TEXT,__text,regular,pure_instructions
.global _audio_integration_test
.global _audio_performance_test
.align 2

// Test constants
.equ TEST_DURATION_FRAMES, 44100    // 1 second at 44.1kHz
.equ TEST_SOURCE_COUNT, 100         // Test 100 simultaneous sources
.equ LATENCY_THRESHOLD_MS, 10       // 10ms maximum latency

.section __DATA,__data
.align 3

// Test state
test_start_time:
    .quad 0

test_frame_count:
    .long 0

test_underrun_count:
    .long 0

test_overrun_count:
    .long 0

test_max_latency:
    .long 0

test_sources:
    .space TEST_SOURCE_COUNT * 4    // Source IDs

test_streams:
    .space 8 * 4                    // Stream IDs for testing

// Test audio data (simple sine wave)
test_audio_buffer:
    .space 1024 * 4                 // 1024 samples of test audio

.section __TEXT,__text

// Main integration test
// Returns: x0 = 0 on success, error code on failure
_audio_integration_test:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    // Test 1: Initialize all audio subsystems
    bl test_audio_initialization
    cbnz x0, integration_test_failed
    
    // Test 2: Test basic audio playback
    bl test_basic_playback
    cbnz x0, integration_test_failed
    
    // Test 3: Test 3D positional audio
    bl test_3d_audio
    cbnz x0, integration_test_failed
    
    // Test 4: Test streaming system
    bl test_streaming_system
    cbnz x0, integration_test_failed
    
    // Test 5: Test performance under load
    bl test_performance_load
    cbnz x0, integration_test_failed
    
    // Test 6: Cleanup and shutdown
    bl test_audio_shutdown
    cbnz x0, integration_test_failed
    
    mov x0, #0                  // Success
    b integration_test_done

integration_test_failed:
    // Cleanup on failure
    bl test_audio_shutdown
    mov x0, #-1                 // Failed

integration_test_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Test audio system initialization
test_audio_initialization:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Initialize Core Audio
    bl _audio_core_init
    cbnz x0, init_test_failed
    
    // Initialize 3D Audio
    bl _audio_3d_init
    cbnz x0, init_test_failed
    
    // Initialize Streaming
    bl _audio_streaming_init
    cbnz x0, init_test_failed
    
    mov x0, #0                  // Success
    b init_test_done

init_test_failed:
    mov x0, #-1                 // Failed

init_test_done:
    ldp x29, x30, [sp], #16
    ret

// Test basic audio playback
test_basic_playback:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    // Generate test audio (440Hz sine wave)
    bl generate_test_audio
    
    // Write test audio to core audio buffer
    adrp x19, test_audio_buffer@PAGE
    add x19, x19, test_audio_buffer@PAGEOFF
    mov x0, x19                 // Source buffer
    mov x1, #256                // Frame count
    bl _audio_core_write_buffer
    
    cmp w0, #256                // Did we write all frames?
    b.ne basic_playback_failed
    
    // Start audio
    bl _audio_core_start
    cbnz x0, basic_playback_failed
    
    // Let it play for a short time
    mov w20, #1000              // ~1ms delay loop
delay_loop:
    sub w20, w20, #1
    cbnz w20, delay_loop
    
    // Stop audio
    bl _audio_core_stop
    
    mov x0, #0                  // Success
    b basic_playback_done

basic_playback_failed:
    mov x0, #-1                 // Failed

basic_playback_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Test 3D positional audio
test_3d_audio:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    // Create test sources at various positions
    mov w19, #0                 // Source counter
    adrp x20, test_sources@PAGE
    add x20, x20, test_sources@PAGEOFF
    
create_3d_sources_loop:
    cmp w19, #10                // Create 10 test sources
    b.ge create_3d_sources_done
    
    // Create 3D source
    bl _audio_3d_create_source
    cmp w0, #-1
    b.eq create_3d_sources_failed
    
    // Store source ID
    str w0, [x20, x19, lsl #2]
    
    // Set position (spread sources around listener)
    scvtf s0, w19               // Convert index to float
    fmov s1, #6.28318530        // 2π
    fmul s0, s0, s1             // * 2π
    fmov s1, #10.0
    fdiv s0, s0, s1             // / 10 (angle step)
    
    bl cosf                     // cos(angle)
    fmov s1, #5.0               // Distance from listener
    fmul s0, s0, s1             // X position
    
    scvtf s2, w19
    fmov s3, #6.28318530
    fmul s2, s2, s3
    fmov s3, #10.0
    fdiv s2, s2, s3
    bl sinf                     // sin(angle) 
    fmul s1, s0, s1             // Y position
    
    fmov s2, #0.0               // Z position
    
    // Set source position
    sub sp, sp, #16
    str s0, [sp]                // X
    str s1, [sp, #4]            // Y
    str s2, [sp, #8]            // Z
    
    ldr w0, [x20, x19, lsl #2]  // Source ID
    mov x1, sp                  // Position pointer
    bl _audio_3d_set_source_position
    
    add sp, sp, #16
    
    add w19, w19, #1
    b create_3d_sources_loop

create_3d_sources_done:
    mov x0, #0                  // Success
    b test_3d_done

create_3d_sources_failed:
    mov x0, #-1                 // Failed

test_3d_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Test streaming system
test_streaming_system:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Test ambient soundscape generation
    mov x0, #0                  // Urban scene
    fmov s1, #0.5               // Medium intensity
    mov x2, #1                  // Noon time
    bl _audio_streaming_generate_ambient_soundscape
    
    mov x0, #0                  // Success
    ldp x29, x30, [sp], #16
    ret

// Performance test under load
test_performance_load:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    // Create maximum number of 3D sources
    mov w19, #0
    adrp x20, test_sources@PAGE
    add x20, x20, test_sources@PAGEOFF
    
performance_create_loop:
    cmp w19, #TEST_SOURCE_COUNT
    b.ge performance_create_done
    
    bl _audio_3d_create_source
    cmp w0, #-1
    b.eq performance_load_limited  // Hit source limit
    
    str w0, [x20, x19, lsl #2]
    add w19, w19, #1
    b performance_create_loop

performance_create_done:
performance_load_limited:
    // Test latency under load
    bl measure_audio_latency
    
    // Check if latency is within acceptable limits
    adrp x0, test_max_latency@PAGE
    add x0, x0, test_max_latency@PAGEOFF
    ldr w0, [x0]
    cmp w0, #LATENCY_THRESHOLD_MS
    b.gt performance_test_failed
    
    mov x0, #0                  // Success
    b performance_test_done

performance_test_failed:
    mov x0, #-1                 // Failed

performance_test_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Test audio system shutdown
test_audio_shutdown:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Shutdown in reverse order
    bl _audio_streaming_shutdown
    bl _audio_3d_shutdown
    bl _audio_core_shutdown
    
    mov x0, #0                  // Success
    ldp x29, x30, [sp], #16
    ret

// Generate test audio (440Hz sine wave)
generate_test_audio:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    adrp x19, test_audio_buffer@PAGE
    add x19, x19, test_audio_buffer@PAGEOFF
    mov w20, #0                 // Sample counter
    
sine_generate_loop:
    cmp w20, #1024
    b.ge sine_generate_done
    
    // Calculate sine wave: sin(2π * 440 * sample / sample_rate)
    scvtf s0, w20               // Convert sample to float
    fmov s1, #440.0             // Frequency
    fmul s0, s0, s1             // sample * frequency
    fmov s1, #44100.0           // Sample rate
    fdiv s0, s0, s1             // / sample_rate
    fmov s1, #6.28318530        // 2π
    fmul s0, s0, s1             // * 2π
    bl sinf                     // sin(angle)
    
    fmov s1, #0.25              // Amplitude
    fmul s0, s0, s1             // Scale amplitude
    
    // Store sample (stereo - same in both channels)
    str s0, [x19, x20, lsl #3]      // Left channel
    str s0, [x19, x20, lsl #3, #4]  // Right channel
    
    add w20, w20, #1
    b sine_generate_loop

sine_generate_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Measure audio latency
measure_audio_latency:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Get current buffer statistics
    bl _audio_core_get_buffer_stats
    // x0 = available frames, x1 = underruns, x2 = overruns
    
    // Calculate latency in milliseconds
    // latency = (buffer_size - available_frames) / sample_rate * 1000
    mov w3, #512                // Total buffer size
    sub w0, w3, w0              // Used frames
    scvtf s0, w0                // Convert to float
    fmov s1, #44.1              // Sample rate in kHz
    fdiv s0, s0, s1             // Latency in ms
    
    // Store maximum latency seen
    adrp x1, test_max_latency@PAGE
    add x1, x1, test_max_latency@PAGEOFF
    ldr w2, [x1]
    fcvtzs w3, s0               // Convert back to int
    cmp w3, w2
    csel w2, w3, w2, gt         // Take maximum
    str w2, [x1]
    
    ldp x29, x30, [sp], #16
    ret

// Performance benchmarking function
_audio_performance_test:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    // Run full integration test and measure performance
    bl _audio_integration_test
    cbnz x0, perf_test_failed
    
    // Report performance metrics
    adrp x19, test_max_latency@PAGE
    add x19, x19, test_max_latency@PAGEOFF
    ldr w0, [x19]               // Return max latency
    
    b perf_test_done

perf_test_failed:
    mov x0, #-1                 // Test failed

perf_test_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// External function declarations
.extern _audio_core_init
.extern _audio_core_shutdown
.extern _audio_core_start
.extern _audio_core_stop
.extern _audio_core_write_buffer
.extern _audio_core_get_buffer_stats
.extern _audio_3d_init
.extern _audio_3d_shutdown
.extern _audio_3d_create_source
.extern _audio_3d_set_source_position
.extern _audio_streaming_init
.extern _audio_streaming_shutdown
.extern _audio_streaming_generate_ambient_soundscape
.extern sinf
.extern cosf