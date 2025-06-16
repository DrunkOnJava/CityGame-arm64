// SimCity ARM64 Math Library - Vector Operations
// Agent 1: Core Engine Developer
// NEON SIMD Optimized Vector Math

.cpu generic+simd
.arch armv8-a+simd

// External functions we need
.extern malloc
.extern free
.extern sinf
.extern cosf
.extern logf
.extern sqrtf

.data
.align 4

// Constants for NEON operations
.vec_zero:          .float 0.0, 0.0, 0.0, 0.0
.vec_one:           .float 1.0, 1.0, 1.0, 1.0
.vec_epsilon:       .float 1e-6, 1e-6, 1e-6, 1e-6

.text
.align 4

//==============================================================================
// Single Vector Operations (2D)
//==============================================================================

// vec2_add: Add two 2D vectors
// Args: x0 = vec2* result, x1 = vec2* a, x2 = vec2* b
// Returns: x0 = result pointer
.global vec2_add
vec2_add:
    ldr     s0, [x1]                // Load a.x
    ldr     s1, [x1, #4]            // Load a.y
    ldr     s2, [x2]                // Load b.x
    ldr     s3, [x2, #4]            // Load b.y
    
    fadd    s0, s0, s2              // result.x = a.x + b.x
    fadd    s1, s1, s3              // result.y = a.y + b.y
    
    str     s0, [x0]                // Store result.x
    str     s1, [x0, #4]            // Store result.y
    
    ret

// vec2_sub: Subtract two 2D vectors
// Args: x0 = vec2* result, x1 = vec2* a, x2 = vec2* b
// Returns: x0 = result pointer
.global vec2_sub
vec2_sub:
    ldr     s0, [x1]                // Load a.x
    ldr     s1, [x1, #4]            // Load a.y
    ldr     s2, [x2]                // Load b.x
    ldr     s3, [x2, #4]            // Load b.y
    
    fsub    s0, s0, s2              // result.x = a.x - b.x
    fsub    s1, s1, s3              // result.y = a.y - b.y
    
    str     s0, [x0]                // Store result.x
    str     s1, [x0, #4]            // Store result.y
    
    ret

// vec2_mul_scalar: Multiply 2D vector by scalar
// Args: x0 = vec2* result, x1 = vec2* a, s0 = scalar
// Returns: x0 = result pointer
.global vec2_mul_scalar
vec2_mul_scalar:
    ldr     s1, [x1]                // Load a.x
    ldr     s2, [x1, #4]            // Load a.y
    
    fmul    s1, s1, s0              // result.x = a.x * scalar
    fmul    s2, s2, s0              // result.y = a.y * scalar
    
    str     s1, [x0]                // Store result.x
    str     s2, [x0, #4]            // Store result.y
    
    ret

// vec2_dot: Dot product of two 2D vectors
// Args: x0 = vec2* a, x1 = vec2* b
// Returns: s0 = dot product
.global vec2_dot
vec2_dot:
    ldr     s0, [x0]                // Load a.x
    ldr     s1, [x0, #4]            // Load a.y
    ldr     s2, [x1]                // Load b.x
    ldr     s3, [x1, #4]            // Load b.y
    
    fmul    s0, s0, s2              // a.x * b.x
    fmul    s1, s1, s3              // a.y * b.y
    fadd    s0, s0, s1              // return a.x * b.x + a.y * b.y
    
    ret

// vec2_length_squared: Get squared length of 2D vector
// Args: x0 = vec2* a
// Returns: s0 = length squared
.global vec2_length_squared
vec2_length_squared:
    ldr     s0, [x0]                // Load a.x
    ldr     s1, [x0, #4]            // Load a.y
    
    fmul    s0, s0, s0              // a.x * a.x
    fmul    s1, s1, s1              // a.y * a.y
    fadd    s0, s0, s1              // return a.x² + a.y²
    
    ret

// vec2_length: Get length of 2D vector
// Args: x0 = vec2* a
// Returns: s0 = length
.global vec2_length
vec2_length:
    stp     x30, x19, [sp, #-16]!   // Save registers
    mov     x19, x0                 // Save vector pointer
    
    bl      vec2_length_squared     // Get length squared
    fsqrt   s0, s0                  // Get square root
    
    ldp     x30, x19, [sp], #16     // Restore registers
    ret

// vec2_normalize: Normalize 2D vector
// Args: x0 = vec2* result, x1 = vec2* a
// Returns: x0 = result pointer, s0 = original length
.global vec2_normalize
vec2_normalize:
    stp     x30, x19, [sp, #-16]!   // Save registers
    stp     x20, x21, [sp, #-16]!
    
    mov     x19, x0                 // Save result pointer
    mov     x20, x1                 // Save input pointer
    
    mov     x0, x1                  // Prepare for length calculation
    bl      vec2_length             // Get length
    
    // Check for zero length
    fcmp    s0, #0.0
    b.eq    normalize_zero
    
    // Calculate 1/length
    fmov    s1, #1.0
    fdiv    s1, s1, s0              // s1 = 1/length
    
    // Multiply vector by 1/length
    mov     x0, x19                 // result
    mov     x1, x20                 // input
    fmov    s0, s1                  // scalar = 1/length
    bl      vec2_mul_scalar
    
    mov     x0, x19                 // Return result pointer
    ldp     x20, x21, [sp], #16     // Restore registers
    ldp     x30, x19, [sp], #16
    ret

normalize_zero:
    // Handle zero vector case
    mov     w1, #0
    str     w1, [x19]               // result.x = 0
    str     w1, [x19, #4]           // result.y = 0
    
    mov     x0, x19                 // Return result pointer
    ldp     x20, x21, [sp], #16     // Restore registers
    ldp     x30, x19, [sp], #16
    ret

//==============================================================================
// NEON Batch Vector Operations (4 vectors at once)
//==============================================================================

// vec2_add_batch: Add 4 pairs of 2D vectors using NEON
// Args: x0 = vec2* result[4], x1 = vec2* a[4], x2 = vec2* b[4]
// Returns: x0 = result pointer
.global vec2_add_batch
vec2_add_batch:
    // Load 4 pairs of 2D vectors (structure of arrays format)
    // Each vector is 8 bytes (2x float32)
    ld1     {v0.4s}, [x1]           // Load a[0].x, a[0].y, a[1].x, a[1].y
    add     x3, x1, #16
    ld1     {v1.4s}, [x3]           // Load a[2].x, a[2].y, a[3].x, a[3].y
    ld1     {v2.4s}, [x2]           // Load b[0].x, b[0].y, b[1].x, b[1].y
    add     x3, x2, #16
    ld1     {v3.4s}, [x3]           // Load b[2].x, b[2].y, b[3].x, b[3].y
    
    // Perform SIMD addition
    fadd    v0.4s, v0.4s, v2.4s     // result[0,1] = a[0,1] + b[0,1]
    fadd    v1.4s, v1.4s, v3.4s     // result[2,3] = a[2,3] + b[2,3]
    
    // Store results
    st1     {v0.4s}, [x0]           // Store result[0,1]
    add     x3, x0, #16
    st1     {v1.4s}, [x3]           // Store result[2,3]
    
    ret

// vec2_sub_batch: Subtract 4 pairs of 2D vectors using NEON
// Args: x0 = vec2* result[4], x1 = vec2* a[4], x2 = vec2* b[4]
// Returns: x0 = result pointer
.global vec2_sub_batch
vec2_sub_batch:
    // Load vectors
    ld1     {v0.4s}, [x1]           // Load a[0,1]
    ld1     {v1.4s}, [x1, #16]      // Load a[2,3]
    ld1     {v2.4s}, [x2]           // Load b[0,1]
    ld1     {v3.4s}, [x2, #16]      // Load b[2,3]
    
    // Perform SIMD subtraction
    fsub    v0.4s, v0.4s, v2.4s     // result[0,1] = a[0,1] - b[0,1]
    fsub    v1.4s, v1.4s, v3.4s     // result[2,3] = a[2,3] - b[2,3]
    
    // Store results
    st1     {v0.4s}, [x0]           // Store result[0,1]
    st1     {v1.4s}, [x0, #16]      // Store result[2,3]
    
    ret

// vec2_mul_scalar_batch: Multiply 4 2D vectors by scalars using NEON
// Args: x0 = vec2* result[4], x1 = vec2* a[4], x2 = float* scalars[4]
// Returns: x0 = result pointer
.global vec2_mul_scalar_batch
vec2_mul_scalar_batch:
    // Load vectors
    ld1     {v0.4s}, [x1]           // Load a[0,1]
    ld1     {v1.4s}, [x1, #16]      // Load a[2,3]
    
    // Load scalars and duplicate for vector multiplication
    ld1     {v2.4s}, [x2]           // Load scalars[0,1,2,3]
    
    // Duplicate scalars for proper multiplication
    // v2 = [s0, s1, s2, s3]
    // We need [s0, s0, s1, s1] and [s2, s2, s3, s3]
    dup     v3.2s, v2.s[0]          // [s0, s0]
    dup     v4.2s, v2.s[1]          // [s1, s1]
    dup     v5.2s, v2.s[2]          // [s2, s2]
    dup     v6.2s, v2.s[3]          // [s3, s3]
    
    // Combine duplicated scalars
    mov     v3.d[1], v4.d[0]        // v3 = [s0, s0, s1, s1]
    mov     v5.d[1], v6.d[0]        // v5 = [s2, s2, s3, s3]
    
    // Perform SIMD multiplication
    fmul    v0.4s, v0.4s, v3.4s     // result[0,1] = a[0,1] * scalars[0,1]
    fmul    v1.4s, v1.4s, v5.4s     // result[2,3] = a[2,3] * scalars[2,3]
    
    // Store results
    st1     {v0.4s}, [x0]           // Store result[0,1]
    st1     {v1.4s}, [x0, #16]      // Store result[2,3]
    
    ret

// vec2_length_batch: Calculate length of 4 2D vectors using NEON
// Args: x0 = vec2* vectors[4], x1 = float* lengths[4]
// Returns: x0 = vectors pointer
.global vec2_length_batch
vec2_length_batch:
    // Load vectors
    ld1     {v0.4s}, [x0]           // Load vectors[0,1]
    ld1     {v1.4s}, [x0, #16]      // Load vectors[2,3]
    
    // Calculate squared lengths using NEON
    fmul    v2.4s, v0.4s, v0.4s     // Square all components
    fmul    v3.4s, v1.4s, v1.4s
    
    // Sum x² + y² for each vector using pairwise addition
    faddp   v4.4s, v2.4s, v3.4s     // Pairwise add: [x0²+y0², x1²+y1², x2²+y2², x3²+y3²]
    
    // Calculate square root
    fsqrt   v4.4s, v4.4s            // lengths = sqrt(x² + y²)
    
    // Store lengths
    st1     {v4.4s}, [x1]           // Store all 4 lengths
    
    ret

// vec2_dot_batch: Calculate dot product of 4 pairs of 2D vectors using NEON
// Args: x0 = vec2* a[4], x1 = vec2* b[4], x2 = float* dots[4]
// Returns: x0 = a pointer
.global vec2_dot_batch
vec2_dot_batch:
    // Load vectors
    ld1     {v0.4s}, [x0]           // Load a[0,1]
    ld1     {v1.4s}, [x0, #16]      // Load a[2,3]
    ld1     {v2.4s}, [x1]           // Load b[0,1]
    ld1     {v3.4s}, [x1, #16]      // Load b[2,3]
    
    // Calculate component-wise multiplication
    fmul    v4.4s, v0.4s, v2.4s     // a[0,1] * b[0,1]
    fmul    v5.4s, v1.4s, v3.4s     // a[2,3] * b[2,3]
    
    // Sum x*x + y*y for each vector using pairwise addition
    faddp   v6.4s, v4.4s, v5.4s     // Pairwise add: [dot0, dot1, dot2, dot3]
    
    // Store dot products
    st1     {v6.4s}, [x2]           // Store all 4 dot products
    
    ret

//==============================================================================
// High-Performance Agent Math Operations
//==============================================================================

// agent_update_positions_batch: Update positions for multiple agents using NEON
// Args: x0 = agent_position_array, x1 = agent_velocity_array, x2 = count, s0 = delta_time
// Returns: x0 = position array pointer
.global agent_update_positions_batch
agent_update_positions_batch:
    cbz     x2, update_positions_done   // Exit if count is 0
    
    // Broadcast delta_time to all NEON lanes
    dup     v31.4s, v0.s[0]             // v31 = [dt, dt, dt, dt]
    
    // Process 4 agents at a time
    lsr     x3, x2, #2                  // x3 = count / 4
    and     x4, x2, #3                  // x4 = count % 4 (remainder)
    
    cbz     x3, update_positions_remainder
    
update_positions_loop:
    // Load 4 agent positions (8 floats: x0,y0,x1,y1,x2,y2,x3,y3)
    ld1     {v0.4s, v1.4s}, [x0]
    
    // Load 4 agent velocities (8 floats: vx0,vy0,vx1,vy1,vx2,vy2,vx3,vy3)
    ld1     {v2.4s, v3.4s}, [x1], #32
    
    // Calculate position += velocity * delta_time
    fmul    v2.4s, v2.4s, v31.4s        // velocities * delta_time
    fmul    v3.4s, v3.4s, v31.4s
    
    fadd    v0.4s, v0.4s, v2.4s         // positions += velocity * dt
    fadd    v1.4s, v1.4s, v3.4s
    
    // Store updated positions
    st1     {v0.4s, v1.4s}, [x0], #32
    
    subs    x3, x3, #1                  // Decrement loop counter
    b.ne    update_positions_loop
    
update_positions_remainder:
    // Handle remaining agents (< 4)
    cbz     x4, update_positions_done
    
remainder_loop:
    ldr     s0, [x0]                    // Load position.x
    ldr     s1, [x0, #4]                // Load position.y
    ldr     s2, [x1], #4                // Load velocity.x
    ldr     s3, [x1], #4                // Load velocity.y
    
    fmul    s2, s2, s31.s[0]            // velocity.x * delta_time
    fmul    s3, s3, s31.s[0]            // velocity.y * delta_time
    
    fadd    s0, s0, s2                  // position.x += velocity.x * dt
    fadd    s1, s1, s3                  // position.y += velocity.y * dt
    
    str     s0, [x0], #4                // Store position.x
    str     s1, [x0], #4                // Store position.y
    
    subs    x4, x4, #1                  // Decrement remainder counter
    b.ne    remainder_loop
    
update_positions_done:
    ret

//==============================================================================
// Performance Monitoring
//==============================================================================

// vec_benchmark_neon: Benchmark NEON vs scalar operations
// Args: x0 = iterations
// Returns: x0 = neon_time_ns, x1 = scalar_time_ns
.global vec_benchmark_neon
vec_benchmark_neon:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0                     // Save iterations
    
    // Allocate test data
    mov     x0, #1024                   // 1KB for test vectors
    bl      malloc
    mov     x20, x0                     // Save test data pointer
    
    // Benchmark NEON operations
    mrs     x0, cntvct_el0              // Get start time
    mov     x21, x0
    
    mov     x2, x19                     // iterations
neon_benchmark_loop:
    mov     x0, x20                     // result
    mov     x1, x20                     // a
    add     x22, x20, #32               // b
    bl      vec2_add_batch              // NEON add operation
    
    subs    x2, x2, #1
    b.ne    neon_benchmark_loop
    
    mrs     x0, cntvct_el0              // Get end time
    sub     x21, x0, x21                // NEON time
    
    // Benchmark scalar operations
    mrs     x0, cntvct_el0              // Get start time
    mov     x22, x0
    
    mov     x2, x19                     // iterations
scalar_benchmark_loop:
    mov     x0, x20                     // result
    mov     x1, x20                     // a
    add     x3, x20, #32                // b
    bl      vec2_add                    // Scalar add operation
    
    subs    x2, x2, #1
    b.ne    scalar_benchmark_loop
    
    mrs     x0, cntvct_el0              // Get end time
    sub     x22, x0, x22                // Scalar time
    
    // Free test data
    mov     x0, x20
    bl      free
    
    // Return times
    mov     x0, x21                     // NEON time
    mov     x1, x22                     // Scalar time
    
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

.end