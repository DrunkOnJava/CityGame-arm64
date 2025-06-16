// SimCity ARM64 Math Library - Random Number Generation
// Agent 1: Core Engine Developer
// Deterministic PRNG with NEON batch generation for simulation reproducibility

.cpu generic+simd
.arch armv8-a+simd

// Include platform constants
.include "../include/constants/platform_constants.h"
.include "../include/macros/platform_asm.inc"

.section .data
.align 4

// Global PRNG state (Xorshift128+ algorithm)
.global_rng_state:
    .quad   0x123456789ABCDEF0          // s0
    .quad   0xFEDCBA9876543210          // s1

// Multiple independent streams for threading
.rng_streams:
    .rept 8                             // 8 independent streams
    .quad   0x123456789ABCDEF0 + (\@ * 0x1111111111111111)
    .quad   0xFEDCBA9876543210 + (\@ * 0x2222222222222222)
    .endr

// Constants for various distributions
.uniform_scale:     .float 2.3283064e-10    // 1.0 / (2^32)
.gaussian_scale:    .float 1.0              // Scale for Box-Muller
.pi_constant:       .float 3.141592653589793

.section .text
.align 4

//==============================================================================
// Core Random Number Generation (Xorshift128+)
//==============================================================================

// rng_init: Initialize random number generator with seed
// Args: x0 = seed
// Returns: none
.global rng_init
rng_init:
    adrp    x1, .global_rng_state
    add     x1, x1, :lo12:.global_rng_state
    
    // Initialize with seed variations
    str     x0, [x1]                    // s0 = seed
    eor     x2, x0, x0, lsl #13         // Mix seed
    eor     x2, x2, x2, lsr #7
    eor     x2, x2, x2, lsl #17
    str     x2, [x1, #8]                // s1 = mixed seed
    
    // Initialize all streams with different seeds
    adrp    x3, .rng_streams
    add     x3, x3, :lo12:.rng_streams
    
    mov     x4, #0
init_streams_loop:
    cmp     x4, #8
    b.ge    init_streams_done
    
    // Create unique seed for each stream
    add     x5, x0, x4, lsl #32
    eor     x5, x5, x4, lsl #16
    str     x5, [x3, x4, lsl #4]        // Store s0 for stream
    
    eor     x6, x5, x5, lsl #13
    eor     x6, x6, x6, lsr #7
    eor     x6, x6, x6, lsl #17
    str     x6, [x3, x4, lsl #4, #8]    // Store s1 for stream
    
    add     x4, x4, #1
    b       init_streams_loop

init_streams_done:
    ret

// rng_next: Generate next random number using Xorshift128+
// Args: none
// Returns: x0 = random uint64
.global rng_next
rng_next:
    adrp    x1, .global_rng_state
    add     x1, x1, :lo12:.global_rng_state
    
    // Load current state
    ldr     x2, [x1]                    // s0
    ldr     x3, [x1, #8]                // s1
    
    // Xorshift128+ algorithm
    eor     x4, x2, x2, lsl #23         // s0 ^= s0 << 23
    eor     x4, x4, x4, lsr #17         // s0 ^= s0 >> 17
    eor     x4, x4, x3                  // s0 ^= s1
    eor     x4, x4, x3, lsr #26         // s0 ^= s1 >> 26
    
    // Update state
    str     x3, [x1]                    // s0 = old s1
    str     x4, [x1, #8]                // s1 = new value
    
    // Return result
    add     x0, x3, x4                  // result = old_s1 + new_s1
    ret

// rng_next_stream: Generate random number from specific stream
// Args: x0 = stream_id (0-7)
// Returns: x0 = random uint64
.global rng_next_stream
rng_next_stream:
    and     x0, x0, #7                  // Clamp to valid stream range
    adrp    x1, .rng_streams
    add     x1, x1, :lo12:.rng_streams
    add     x1, x1, x0, lsl #4          // Point to stream state
    
    // Load stream state
    ldr     x2, [x1]                    // s0
    ldr     x3, [x1, #8]                // s1
    
    // Xorshift128+ algorithm
    eor     x4, x2, x2, lsl #23
    eor     x4, x4, x4, lsr #17
    eor     x4, x4, x3
    eor     x4, x4, x3, lsr #26
    
    // Update stream state
    str     x3, [x1]                    // s0 = old s1
    str     x4, [x1, #8]                // s1 = new value
    
    // Return result
    add     x0, x3, x4
    ret

//==============================================================================
// Uniform Distribution Functions
//==============================================================================

// rng_uniform_float: Generate uniform float [0.0, 1.0)
// Args: none
// Returns: s0 = uniform float
.global rng_uniform_float
rng_uniform_float:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    bl      rng_next                    // Get random uint64
    lsr     x0, x0, #32                 // Use upper 32 bits
    
    // Convert to float [0.0, 1.0)
    ucvtf   s0, w0                      // Convert to float
    adrp    x1, .uniform_scale
    add     x1, x1, :lo12:.uniform_scale
    ldr     s1, [x1]
    fmul    s0, s0, s1                  // Scale to [0.0, 1.0)
    
    ldp     x29, x30, [sp], #16
    ret

// rng_uniform_range: Generate uniform float in range [min, max)
// Args: s0 = min, s1 = max
// Returns: s0 = uniform float in range
.global rng_uniform_range
rng_uniform_range:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     d8, d9, [sp, #-16]!
    
    fmov    d8, d0                      // Save min
    fmov    d9, d1                      // Save max
    
    bl      rng_uniform_float           // Get [0.0, 1.0)
    
    fsub    s1, s9, s8                  // range = max - min
    fmul    s0, s0, s1                  // scale by range
    fadd    s0, s0, s8                  // offset by min
    
    ldp     d8, d9, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// rng_uniform_int: Generate uniform integer in range [0, max)
// Args: w0 = max (exclusive)
// Returns: w0 = uniform integer
.global rng_uniform_int
rng_uniform_int:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     w1, w0                      // Save max
    bl      rng_next                    // Get random uint64
    
    // Use rejection sampling to avoid bias
    mov     x2, #0xFFFFFFFFFFFFFFFF
    udiv    x3, x2, x1                  // threshold = UINT64_MAX / max
    mul     x3, x3, x1                  // threshold *= max
    
    cmp     x0, x3
    b.ge    rng_uniform_int             // Retry if above threshold
    
    udiv    x0, x0, x1                  // result = random / max
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// NEON Batch Random Generation
//==============================================================================

// rng_uniform_float_batch: Generate 4 uniform floats using NEON
// Args: x0 = float* output
// Returns: x0 = output pointer
.global rng_uniform_float_batch
rng_uniform_float_batch:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0                     // Save output pointer
    
    // Generate 4 random numbers
    bl      rng_next
    mov     x20, x0                     // Save first random
    bl      rng_next
    mov     v0.d[0], x20                // Load first random to NEON
    mov     v0.d[1], x0                 // Load second random to NEON
    
    bl      rng_next
    mov     x20, x0                     // Save third random
    bl      rng_next
    mov     v1.d[0], x20                // Load third random to NEON
    mov     v1.d[1], x0                 // Load fourth random to NEON
    
    // Convert to 32-bit integers (upper 32 bits)
    ushr    v0.2d, v0.2d, #32          // Shift to get upper 32 bits
    ushr    v1.2d, v1.2d, #32
    uzp1    v0.4s, v0.4s, v1.4s        // Pack to 4x 32-bit integers
    
    // Convert to float [0.0, 1.0)
    ucvtf   v0.4s, v0.4s               // Convert to float
    adrp    x1, .uniform_scale
    add     x1, x1, :lo12:.uniform_scale
    ldr     s1, [x1]
    dup     v1.4s, v1.s[0]              // Broadcast scale
    fmul    v0.4s, v0.4s, v1.4s         // Scale to [0.0, 1.0)
    
    // Store results
    st1     {v0.4s}, [x19]
    
    mov     x0, x19                     // Return output pointer
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// rng_uniform_range_batch: Generate 4 uniform floats in range using NEON
// Args: x0 = float* output, s0 = min, s1 = max
// Returns: x0 = output pointer
.global rng_uniform_range_batch
rng_uniform_range_batch:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     d8, d9, [sp, #-16]!
    
    fmov    d8, d0                      // Save min
    fmov    d9, d1                      // Save max
    
    bl      rng_uniform_float_batch     // Get 4 uniform [0.0, 1.0) values
    
    // Scale and offset all 4 values
    fsub    s1, s9, s8                  // range = max - min
    dup     v1.4s, v1.s[0]              // Broadcast range
    dup     v2.4s, v8.s[0]              // Broadcast min
    
    ld1     {v0.4s}, [x0]               // Load generated values
    fmul    v0.4s, v0.4s, v1.4s         // Scale by range
    fadd    v0.4s, v0.4s, v2.4s         // Offset by min
    st1     {v0.4s}, [x0]               // Store results
    
    ldp     d8, d9, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Gaussian (Normal) Distribution
//==============================================================================

// rng_gaussian: Generate Gaussian random number using Box-Muller transform
// Args: s0 = mean, s1 = standard_deviation
// Returns: s0 = gaussian random number
.global rng_gaussian
rng_gaussian:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     d8, d9, [sp, #-16]!
    stp     d10, d11, [sp, #-16]!
    
    fmov    d8, d0                      // Save mean
    fmov    d9, d1                      // Save std_dev
    
    // Generate two uniform random numbers
    bl      rng_uniform_float           // u1
    fmov    d10, d0
    bl      rng_uniform_float           // u2
    fmov    d11, d0
    
    // Box-Muller transform
    // z0 = sqrt(-2 * ln(u1)) * cos(2 * pi * u2)
    
    // Calculate -2 * ln(u1)
    bl      logf                        // ln(u2) - using u2 in s0
    fmov    s0, s10                     // Load u1
    bl      logf                        // ln(u1)
    fmov    s1, #-2.0
    fmul    s0, s0, s1                  // -2 * ln(u1)
    bl      sqrtf                       // sqrt(-2 * ln(u1))
    fmov    d10, d0                     // Save sqrt part
    
    // Calculate 2 * pi * u2
    adrp    x1, .pi_constant
    add     x1, x1, :lo12:.pi_constant
    ldr     s1, [x1]
    fmov    s2, #2.0
    fmul    s1, s1, s2                  // 2 * pi
    fmul    s0, s11, s1                 // 2 * pi * u2
    bl      cosf                        // cos(2 * pi * u2)
    
    // Combine: z0 = sqrt(-2 * ln(u1)) * cos(2 * pi * u2)
    fmul    s0, s10, s0                 // sqrt * cos
    
    // Scale and offset: result = mean + std_dev * z0
    fmul    s0, s0, s9                  // std_dev * z0
    fadd    s0, s0, s8                  // mean + std_dev * z0
    
    ldp     d10, d11, [sp], #16
    ldp     d8, d9, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Agent Behavior Random Functions
//==============================================================================

// rng_agent_decision: Generate random decision for agent behavior
// Args: x0 = agent_id, s0 = probability_threshold
// Returns: w0 = decision (0 or 1)
.global rng_agent_decision
rng_agent_decision:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     d8, x19, [sp, #-16]!
    
    fmov    d8, d0                      // Save threshold
    mov     x19, x0                     // Save agent_id
    
    // Use agent_id to determine stream for reproducibility
    and     x0, x19, #7                 // stream = agent_id % 8
    bl      rng_next_stream             // Get random from agent's stream
    
    // Convert to float [0.0, 1.0)
    lsr     x0, x0, #32                 // Use upper 32 bits
    ucvtf   s0, w0                      // Convert to float
    adrp    x1, .uniform_scale
    add     x1, x1, :lo12:.uniform_scale
    ldr     s1, [x1]
    fmul    s0, s0, s1                  // Scale to [0.0, 1.0)
    
    // Compare with threshold
    fcmp    s0, s8
    cset    w0, lt                      // Return 1 if random < threshold, 0 otherwise
    
    ldp     d8, x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// rng_spawn_position: Generate random spawn position within bounds
// Args: x0 = vec2* output, s0 = min_x, s1 = max_x, s2 = min_y, s3 = max_y
// Returns: x0 = output pointer
.global rng_spawn_position
rng_spawn_position:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     d8, d9, [sp, #-16]!
    stp     d10, d11, [sp, #-16]!
    stp     x19, xzr, [sp, #-16]!
    
    mov     x19, x0                     // Save output pointer
    fmov    d8, d0                      // Save min_x
    fmov    d9, d1                      // Save max_x
    fmov    d10, d2                     // Save min_y
    fmov    d11, d3                     // Save max_y
    
    // Generate random X coordinate
    fmov    s0, s8                      // min_x
    fmov    s1, s9                      // max_x
    bl      rng_uniform_range
    str     s0, [x19]                   // Store x coordinate
    
    // Generate random Y coordinate
    fmov    s0, s10                     // min_y
    fmov    s1, s11                     // max_y
    bl      rng_uniform_range
    str     s0, [x19, #4]               // Store y coordinate
    
    mov     x0, x19                     // Return output pointer
    
    ldp     x19, xzr, [sp], #16
    ldp     d10, d11, [sp], #16
    ldp     d8, d9, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Performance and Testing
//==============================================================================

// rng_benchmark: Benchmark random number generation performance
// Args: x0 = iterations
// Returns: x0 = time_per_iteration_ns
.global rng_benchmark
rng_benchmark:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0                     // Save iterations
    
    // Benchmark scalar generation
    mrs     x20, cntvct_el0             // Start time
    
    mov     x1, x19
scalar_bench_loop:
    bl      rng_next
    subs    x1, x1, #1
    b.ne    scalar_bench_loop
    
    mrs     x0, cntvct_el0              // End time
    sub     x0, x0, x20                 // Scalar time
    udiv    x0, x0, x19                 // Time per iteration
    
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// rng_test_distribution: Test random number distribution quality
// Args: x0 = sample_count, x1 = bucket_count
// Returns: x0 = chi_square_statistic (scaled by 1000)
.global rng_test_distribution
rng_test_distribution:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0                     // Save sample_count
    mov     x20, x1                     // Save bucket_count
    
    // Allocate bucket array
    lsl     x0, x20, #2                 // bucket_count * 4 bytes
    bl      malloc
    mov     x21, x0                     // Save bucket pointer
    
    // Clear buckets
    mov     x22, #0
clear_buckets:
    str     wzr, [x21, x22, lsl #2]
    add     x22, x22, #1
    cmp     x22, x20
    b.lt    clear_buckets
    
    // Generate samples and count buckets
    mov     x22, #0
sample_loop:
    cmp     x22, x19
    b.ge    calculate_chi_square
    
    bl      rng_uniform_float           // Get [0.0, 1.0)
    scvtf   s1, w20                     // Convert bucket_count to float
    fmul    s0, s0, s1                  // Scale to [0, bucket_count)
    fcvtzs  w0, s0                      // Convert to bucket index
    
    // Clamp to valid range
    cmp     w0, #0
    csel    w0, w0, wzr, ge
    cmp     w0, w20
    sub     w1, w20, #1
    csel    w0, w1, w0, lt
    
    // Increment bucket
    ldr     w1, [x21, x0, lsl #2]
    add     w1, w1, #1
    str     w1, [x21, x0, lsl #2]
    
    add     x22, x22, #1
    b       sample_loop

calculate_chi_square:
    // Calculate expected count per bucket
    udiv    x22, x19, x20               // expected = sample_count / bucket_count
    
    // Calculate chi-square statistic
    mov     x0, #0                      // chi_square = 0
    mov     x1, #0                      // bucket index
    
chi_square_loop:
    cmp     x1, x20
    b.ge    chi_square_done
    
    ldr     w2, [x21, x1, lsl #2]       // observed count
    sub     w3, w2, w22                 // observed - expected
    mul     w3, w3, w3                  // (observed - expected)²
    udiv    w3, w3, w22                 // (observed - expected)² / expected
    add     x0, x0, x3                  // chi_square += term
    
    add     x1, x1, #1
    b       chi_square_loop

chi_square_done:
    // Scale result by 1000 for integer return
    mov     x1, #1000
    mul     x0, x0, x1
    
    // Free bucket array
    mov     x22, x0                     // Save result
    mov     x0, x21
    bl      free
    
    mov     x0, x22                     // Return result
    
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

.end