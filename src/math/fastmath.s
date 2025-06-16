// SimCity ARM64 Math Library - Fast Math Functions
// Agent 1: Core Engine Developer
// Optimized approximations and lookup tables for real-time performance

.cpu generic+simd
.arch armv8-a+simd

// Include platform constants
.include "../include/constants/platform_constants.h"
.include "../include/macros/platform_asm.inc"

.section .data
.align 4

// Constants
.math_pi:           .float 3.141592653589793
.math_half_pi:      .float 1.570796326794897
.math_two_pi:       .float 6.283185307179586
.math_inv_pi:       .float 0.318309886183791
.math_inv_two_pi:   .float 0.159154943091895

// Fast sine/cosine lookup table (256 entries for one quarter period)
// Each entry represents sin(i * π/512) for i = 0 to 255
.align 4
.sin_table:
.rept 256
    .float sin((\@ * 3.141592653589793) / 512.0)
.endr

// Fast square root reciprocal lookup table for distance calculations
.align 4
.rsqrt_table:
.rept 256
    .float (1.0 / sqrt(1.0 + \@ / 256.0))
.endr

// Fast arctangent lookup table
.align 4
.atan_table:
.rept 256
    .float atan(\@ / 256.0)
.endr

.section .text
.align 4

//==============================================================================
// Fast Trigonometric Functions
//==============================================================================

// fast_sin: Fast sine approximation using lookup table + interpolation
// Args: s0 = angle (radians)
// Returns: s0 = sin(angle)
.global fast_sin
fast_sin:
    // Normalize angle to [0, 2π]
    adrp    x0, .math_two_pi
    add     x0, x0, :lo12:.math_two_pi
    ldr     s1, [x0]                   // Load 2π
    
    // Reduce angle to [0, 2π] using fmod-like operation
    fdiv    s2, s0, s1                 // angle / 2π
    frintm  s3, s2                     // floor(angle / 2π)
    fmul    s3, s3, s1                 // floor * 2π
    fsub    s0, s0, s3                 // angle = angle - floor * 2π
    
    // Convert to table index (0-1023 for full period)
    fmov    s2, #512.0
    fmul    s2, s0, s2                 // angle * 512 / π
    adrp    x0, .math_inv_pi
    add     x0, x0, :lo12:.math_inv_pi
    ldr     s3, [x0]
    fmul    s2, s2, s3                 // (angle * 512) / π
    
    // Convert to integer index
    fcvtzs  w1, s2                     // Integer part
    scvtf   s3, w1                     // Convert back to float
    fsub    s4, s2, s3                 // Fractional part for interpolation
    
    // Handle quadrant mapping
    and     w2, w1, #1023              // Keep within table bounds
    cmp     w2, #256
    b.lt    sin_quad_0_1
    cmp     w2, #512
    b.lt    sin_quad_2
    cmp     w2, #768
    b.lt    sin_quad_3
    b       sin_quad_4

sin_quad_0_1:
    // First quadrant: use table directly
    adrp    x0, .sin_table
    add     x0, x0, :lo12:.sin_table
    ldr     s0, [x0, w2, uxtw #2]      // Load sin(index)
    
    // Linear interpolation
    add     w3, w2, #1
    and     w3, w3, #255               // Next index (wrap around)
    ldr     s1, [x0, w3, uxtw #2]      // Load sin(index+1)
    fsub    s1, s1, s0                 // Difference
    fmul    s1, s1, s4                 // Difference * fraction
    fadd    s0, s0, s1                 // Final result
    ret

sin_quad_2:
    // Second quadrant: sin(π - x) = sin(x)
    sub     w2, w2, #256
    rsb     w2, w2, #255               // 255 - (index - 256)
    b       sin_lookup_interp

sin_quad_3:
    // Third quadrant: sin(π + x) = -sin(x)
    sub     w2, w2, #512
    bl      sin_lookup_interp
    fneg    s0, s0                     // Negate result
    ret

sin_quad_4:
    // Fourth quadrant: sin(2π - x) = -sin(x)
    sub     w2, w2, #768
    rsb     w2, w2, #255               // 255 - (index - 768)
    bl      sin_lookup_interp
    fneg    s0, s0                     // Negate result
    ret

sin_lookup_interp:
    adrp    x0, .sin_table
    add     x0, x0, :lo12:.sin_table
    ldr     s0, [x0, w2, uxtw #2]      // Load sin(index)
    
    add     w3, w2, #1
    and     w3, w3, #255               // Next index
    ldr     s1, [x0, w3, uxtw #2]      // Load sin(index+1)
    fsub    s1, s1, s0                 // Difference
    fmul    s1, s1, s4                 // Difference * fraction
    fadd    s0, s0, s1                 // Final result
    ret

// fast_cos: Fast cosine approximation
// Args: s0 = angle (radians)
// Returns: s0 = cos(angle)
.global fast_cos
fast_cos:
    // cos(x) = sin(x + π/2)
    adrp    x0, .math_half_pi
    add     x0, x0, :lo12:.math_half_pi
    ldr     s1, [x0]
    fadd    s0, s0, s1                 // angle + π/2
    b       fast_sin                   // Use fast_sin

//==============================================================================
// Fast Square Root Functions
//==============================================================================

// fast_sqrt: Fast square root using Newton-Raphson approximation
// Args: s0 = x
// Returns: s0 = sqrt(x)
.global fast_sqrt
fast_sqrt:
    // Check for zero or negative
    fcmp    s0, #0.0
    b.le    sqrt_special_case
    
    // Initial guess using bit manipulation (magic number method)
    fmov    w1, s0                     // Move float bits to integer
    lsr     w1, w1, #1                 // Divide exponent by 2
    add     w1, w1, #0x1FC00000        // Add magic number
    fmov    s1, w1                     // Move back to float
    
    // Newton-Raphson iterations (2 iterations for good precision)
    // x_new = 0.5 * (x_old + a / x_old)
    fdiv    s2, s0, s1                 // a / x_old
    fadd    s1, s1, s2                 // x_old + a / x_old
    fmov    s3, #0.5
    fmul    s1, s1, s3                 // 0.5 * (x_old + a / x_old)
    
    // Second iteration
    fdiv    s2, s0, s1
    fadd    s1, s1, s2
    fmul    s0, s1, s3                 // Final result
    
    ret

sqrt_special_case:
    fmov    s0, #0.0                   // Return 0 for non-positive input
    ret

// fast_rsqrt: Fast reciprocal square root (1/sqrt(x))
// Args: s0 = x
// Returns: s0 = 1/sqrt(x)
.global fast_rsqrt
fast_rsqrt:
    // Check for zero or negative
    fcmp    s0, #0.0
    b.le    rsqrt_special_case
    
    // Quake-style fast inverse square root with ARM64 optimization
    fmov    w1, s0                     // Move float bits to integer
    mov     w2, #0x5F3759DF            // Magic number
    lsr     w1, w1, #1                 // i >> 1
    sub     w1, w2, w1                 // Magic - (i >> 1)
    fmov    s1, w1                     // Move back to float
    
    // Newton-Raphson iteration: y = y * (1.5 - 0.5 * x * y * y)
    fmul    s2, s0, s1                 // x * y
    fmul    s2, s2, s1                 // x * y * y
    fmov    s3, #0.5
    fmul    s2, s2, s3                 // 0.5 * x * y * y
    fmov    s3, #1.5
    fsub    s2, s3, s2                 // 1.5 - 0.5 * x * y * y
    fmul    s0, s1, s2                 // y * (1.5 - 0.5 * x * y * y)
    
    ret

rsqrt_special_case:
    fmov    s0, #0.0                   // Return 0 for non-positive input
    ret

//==============================================================================
// Fast Distance and Length Functions
//==============================================================================

// fast_distance_2d: Fast 2D distance calculation
// Args: s0 = dx, s1 = dy
// Returns: s0 = distance
.global fast_distance_2d
fast_distance_2d:
    // Calculate dx² + dy²
    fmul    s0, s0, s0                 // dx²
    fmul    s1, s1, s1                 // dy²
    fadd    s0, s0, s1                 // dx² + dy²
    
    // Use fast sqrt
    b       fast_sqrt

// fast_distance_squared_2d: Fast 2D distance squared (no sqrt needed)
// Args: s0 = dx, s1 = dy
// Returns: s0 = distance²
.global fast_distance_squared_2d
fast_distance_squared_2d:
    fmul    s0, s0, s0                 // dx²
    fmul    s1, s1, s1                 // dy²
    fadd    s0, s0, s1                 // dx² + dy²
    ret

// fast_distance_batch_2d: Calculate distances for multiple point pairs using NEON
// Args: x0 = float* distances, x1 = vec2* points_a, x2 = vec2* points_b, x3 = count
// Returns: x0 = distances pointer
.global fast_distance_batch_2d
fast_distance_batch_2d:
    cbz     x3, distance_batch_done
    
    // Process 4 distance calculations at once
    lsr     x4, x3, #2                 // count / 4
    and     x5, x3, #3                 // count % 4
    
    cbz     x4, distance_batch_remainder

distance_batch_loop:
    // Load 4 pairs of 2D points
    ld1     {v0.4s, v1.4s}, [x1], #32  // Load 4 points A (x0,y0,x1,y1,x2,y2,x3,y3)
    ld1     {v2.4s, v3.4s}, [x2], #32  // Load 4 points B
    
    // Calculate differences
    fsub    v4.4s, v0.4s, v2.4s        // dx values
    fsub    v5.4s, v1.4s, v3.4s        // dy values
    
    // Calculate squared distances
    fmul    v4.4s, v4.4s, v4.4s        // dx²
    fmul    v5.4s, v5.4s, v5.4s        // dy²
    
    // Rearrange for proper pairing (interleave dx² and dy²)
    zip1    v6.4s, v4.4s, v5.4s        // [dx0², dy0², dx1², dy1²]
    zip2    v7.4s, v4.4s, v5.4s        // [dx2², dy2², dx3², dy3²]
    
    // Sum pairs to get distance²
    faddp   v8.4s, v6.4s, v7.4s        // [dist0², dist1², dist2², dist3²]
    
    // Calculate square root for all 4 distances
    fsqrt   v8.4s, v8.4s
    
    // Store results
    st1     {v8.4s}, [x0], #16
    
    subs    x4, x4, #1
    b.ne    distance_batch_loop

distance_batch_remainder:
    // Handle remaining distances (< 4)
    cbz     x5, distance_batch_done

remainder_loop:
    ldr     s0, [x1], #4               // Load point A.x
    ldr     s1, [x1], #4               // Load point A.y
    ldr     s2, [x2], #4               // Load point B.x
    ldr     s3, [x2], #4               // Load point B.y
    
    fsub    s0, s0, s2                 // dx
    fsub    s1, s1, s3                 // dy
    
    bl      fast_distance_2d           // Calculate distance
    
    str     s0, [x0], #4               // Store result
    
    subs    x5, x5, #1
    b.ne    remainder_loop

distance_batch_done:
    ret

//==============================================================================
// Fast Arctangent Functions
//==============================================================================

// fast_atan2: Fast arctangent2 for angle calculations
// Args: s0 = y, s1 = x
// Returns: s0 = atan2(y, x) in radians
.global fast_atan2
fast_atan2:
    // Handle special cases
    fcmp    s1, #0.0
    b.eq    atan2_x_zero
    fcmp    s0, #0.0
    b.eq    atan2_y_zero
    
    // Calculate abs(y/x) for table lookup
    fdiv    s2, s0, s1                 // y/x
    fabs    s3, s2                     // abs(y/x)
    
    // Check if we need to use reciprocal for better precision
    fmov    s4, #1.0
    fcmp    s3, s4
    b.gt    atan2_use_reciprocal
    
    // Use direct lookup for abs(y/x) <= 1
    fmov    s4, #256.0
    fmul    s3, s3, s4                 // Scale to table size
    fcvtzs  w1, s3                     // Integer index
    scvtf   s4, w1                     // Convert back
    fsub    s5, s3, s4                 // Fractional part
    
    // Table lookup with interpolation
    adrp    x0, .atan_table
    add     x0, x0, :lo12:.atan_table
    ldr     s6, [x0, w1, uxtw #2]      // atan(index/256)
    
    add     w2, w1, #1
    cmp     w2, #256
    b.ge    atan2_no_interp
    ldr     s7, [x0, w2, uxtw #2]      // atan((index+1)/256)
    fsub    s7, s7, s6                 // Difference
    fmul    s7, s7, s5                 // Difference * fraction
    fadd    s6, s6, s7                 // Interpolated value

atan2_no_interp:
    mov     s0, s6                     // Result = atan(abs(y/x))
    b       atan2_adjust_quadrant

atan2_use_reciprocal:
    // For abs(y/x) > 1, use atan(x/y) = π/2 - atan(y/x)
    fdiv    s3, s1, s0                 // x/y
    fabs    s3, s3                     // abs(x/y)
    
    fmov    s4, #256.0
    fmul    s3, s3, s4                 // Scale to table size
    fcvtzs  w1, s3                     // Integer index
    
    adrp    x0, .atan_table
    add     x0, x0, :lo12:.atan_table
    ldr     s6, [x0, w1, uxtw #2]      // atan(abs(x/y))
    
    // Result = π/2 - atan(abs(x/y))
    adrp    x0, .math_half_pi
    add     x0, x0, :lo12:.math_half_pi
    ldr     s7, [x0]
    fsub    s0, s7, s6

atan2_adjust_quadrant:
    // Adjust for correct quadrant based on signs of x and y
    fcmp    s1, #0.0                   // Check x sign
    b.lt    atan2_x_negative
    fcmp    s0, #0.0                   // Check y sign (stored in original s0)
    b.lt    atan2_negate
    ret                                // Quadrant I: positive result

atan2_x_negative:
    fcmp    s0, #0.0                   // Check y sign
    b.ge    atan2_quad_ii
    // Quadrant III: result = result - π
    adrp    x0, .math_pi
    add     x0, x0, :lo12:.math_pi
    ldr     s1, [x0]
    fsub    s0, s0, s1
    ret

atan2_quad_ii:
    // Quadrant II: result = π - result
    adrp    x0, .math_pi
    add     x0, x0, :lo12:.math_pi
    ldr     s1, [x0]
    fsub    s0, s1, s0
    ret

atan2_negate:
    fneg    s0, s0                     // Quadrant IV: negative result
    ret

atan2_x_zero:
    fcmp    s0, #0.0
    b.gt    atan2_pos_y_axis
    b.lt    atan2_neg_y_axis
    fmov    s0, #0.0                   // Both zero
    ret

atan2_pos_y_axis:
    adrp    x0, .math_half_pi
    add     x0, x0, :lo12:.math_half_pi
    ldr     s0, [x0]                   // +π/2
    ret

atan2_neg_y_axis:
    adrp    x0, .math_half_pi
    add     x0, x0, :lo12:.math_half_pi
    ldr     s0, [x0]
    fneg    s0, s0                     // -π/2
    ret

atan2_y_zero:
    fcmp    s1, #0.0
    b.gt    atan2_pos_x_axis
    adrp    x0, .math_pi
    add     x0, x0, :lo12:.math_pi
    ldr     s0, [x0]                   // π
    ret

atan2_pos_x_axis:
    fmov    s0, #0.0                   // 0
    ret

//==============================================================================
// Performance Benchmarking
//==============================================================================

// fastmath_benchmark: Compare fast vs standard math functions
// Args: x0 = iterations
// Returns: x0 = fast_time_ns, x1 = standard_time_ns
.global fastmath_benchmark
fastmath_benchmark:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0                    // Save iterations
    
    // Benchmark fast_sin
    mrs     x20, cntvct_el0            // Start time
    mov     x21, x19                   // Counter
    fmov    s0, #1.0                   // Test angle

fast_bench_loop:
    bl      fast_sin
    subs    x21, x21, #1
    b.ne    fast_bench_loop
    
    mrs     x21, cntvct_el0            // End time
    sub     x20, x21, x20              // Fast time
    
    // Benchmark standard sinf
    mrs     x21, cntvct_el0            // Start time
    mov     x22, x19                   // Counter
    fmov    s0, #1.0                   // Test angle

std_bench_loop:
    bl      sinf
    subs    x22, x22, #1
    b.ne    std_bench_loop
    
    mrs     x22, cntvct_el0            // End time
    sub     x21, x22, x21              // Standard time
    
    // Return results
    mov     x0, x20                    // Fast time
    mov     x1, x21                    // Standard time
    
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

.end