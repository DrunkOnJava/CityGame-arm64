// SimCity ARM64 Math Library - Matrix Operations
// Agent 1: Core Engine Developer
// NEON SIMD Optimized 4x4 Matrix Math

.cpu generic+simd
.arch armv8-a+simd

// Include platform constants
.include "../include/constants/platform_constants.h"
.include "../include/macros/platform_asm.inc"

.section .data
.align 4

// Identity matrix constant
.identity_matrix:
    .float 1.0, 0.0, 0.0, 0.0
    .float 0.0, 1.0, 0.0, 0.0
    .float 0.0, 0.0, 1.0, 0.0
    .float 0.0, 0.0, 0.0, 1.0

// Zero matrix constant
.zero_matrix:
    .float 0.0, 0.0, 0.0, 0.0
    .float 0.0, 0.0, 0.0, 0.0
    .float 0.0, 0.0, 0.0, 0.0
    .float 0.0, 0.0, 0.0, 0.0

.section .text
.align 4

//==============================================================================
// Matrix Initialization and Utilities
//==============================================================================

// mat4_identity: Create identity matrix
// Args: x0 = mat4* result
// Returns: x0 = result pointer
.global mat4_identity
mat4_identity:
    adrp    x1, .identity_matrix
    add     x1, x1, :lo12:.identity_matrix
    
    // Load and store identity matrix using NEON
    ld1     {v0.4s, v1.4s, v2.4s, v3.4s}, [x1]
    st1     {v0.4s, v1.4s, v2.4s, v3.4s}, [x0]
    
    ret

// mat4_zero: Create zero matrix
// Args: x0 = mat4* result
// Returns: x0 = result pointer
.global mat4_zero
mat4_zero:
    adrp    x1, .zero_matrix
    add     x1, x1, :lo12:.zero_matrix
    
    // Load and store zero matrix using NEON
    ld1     {v0.4s, v1.4s, v2.4s, v3.4s}, [x1]
    st1     {v0.4s, v1.4s, v2.4s, v3.4s}, [x0]
    
    ret

// mat4_copy: Copy matrix
// Args: x0 = mat4* dest, x1 = mat4* src
// Returns: x0 = dest pointer
.global mat4_copy
mat4_copy:
    // Copy entire 64-byte matrix using NEON
    ld1     {v0.4s, v1.4s, v2.4s, v3.4s}, [x1]
    st1     {v0.4s, v1.4s, v2.4s, v3.4s}, [x0]
    
    ret

//==============================================================================
// Matrix Multiplication (NEON Optimized)
//==============================================================================

// mat4_multiply: Multiply two 4x4 matrices (result = a * b)
// Args: x0 = mat4* result, x1 = mat4* a, x2 = mat4* b
// Returns: x0 = result pointer
.global mat4_multiply
mat4_multiply:
    // Load matrix A (left operand)
    ld1     {v0.4s, v1.4s, v2.4s, v3.4s}, [x1]    // A rows 0-3
    
    // Load matrix B (right operand)
    ld1     {v4.4s, v5.4s, v6.4s, v7.4s}, [x2]    // B rows 0-3
    
    // Transpose B to get columns in registers for easier multiplication
    // This is more efficient than multiple lane extractions
    transpose_4x4 v4, v5, v6, v7, v16, v17, v18, v19
    
    // Calculate result matrix row by row
    // Row 0 = A[0] * B (v0 * transposed B)
    calc_matrix_row v0, v16, v17, v18, v19, v20
    
    // Row 1 = A[1] * B (v1 * transposed B)  
    calc_matrix_row v1, v16, v17, v18, v19, v21
    
    // Row 2 = A[2] * B (v2 * transposed B)
    calc_matrix_row v2, v16, v17, v18, v19, v22
    
    // Row 3 = A[3] * B (v3 * transposed B)
    calc_matrix_row v3, v16, v17, v18, v19, v23
    
    // Store result matrix
    st1     {v20.4s, v21.4s, v22.4s, v23.4s}, [x0]
    
    ret

// Macro: transpose_4x4 - Transpose 4x4 matrix using NEON
// Args: r0-r3 (input rows), t0-t3 (output columns)
.macro transpose_4x4 r0, r1, r2, r3, t0, t1, t2, t3
    // Interleave rows to get columns
    zip1    \t0\().4s, \r0\().4s, \r1\().4s    // [A00,B00,A01,B01]
    zip2    \t1\().4s, \r0\().4s, \r1\().4s    // [A02,B02,A03,B03]
    zip1    \t2\().4s, \r2\().4s, \r3\().4s    // [C00,D00,C01,D01]
    zip2    \t3\().4s, \r2\().4s, \r3\().4s    // [C02,D02,C03,D03]
    
    // Final transpose
    zip1    \r0\().2d, \t0\().2d, \t2\().2d    // Column 0
    zip2    \r1\().2d, \t0\().2d, \t2\().2d    // Column 1
    zip1    \r2\().2d, \t1\().2d, \t3\().2d    // Column 2
    zip2    \r3\().2d, \t1\().2d, \t3\().2d    // Column 3
    
    mov     \t0\().16b, \r0\().16b              // Copy back
    mov     \t1\().16b, \r1\().16b
    mov     \t2\().16b, \r2\().16b
    mov     \t3\().16b, \r3\().16b
.endm

// Macro: calc_matrix_row - Calculate one row of matrix multiplication
// Args: row (input row), col0-col3 (matrix B columns), result (output)
.macro calc_matrix_row row, col0, col1, col2, col3, result
    // Multiply row by each column and sum
    fmul    v24.4s, \row\().4s, \col0\().4s     // row * col0
    fmul    v25.4s, \row\().4s, \col1\().4s     // row * col1
    fmul    v26.4s, \row\().4s, \col2\().4s     // row * col2
    fmul    v27.4s, \row\().4s, \col3\().4s     // row * col3
    
    // Sum elements in each vector to get final values
    faddp   v24.4s, v24.4s, v25.4s              // [sum0, sum0, sum1, sum1]
    faddp   v26.4s, v26.4s, v27.4s              // [sum2, sum2, sum3, sum3]
    faddp   \result\().4s, v24.4s, v26.4s       // [sum0, sum1, sum2, sum3]
.endm

//==============================================================================
// Transformation Matrices
//==============================================================================

// mat4_translate: Create translation matrix
// Args: x0 = mat4* result, s0 = x, s1 = y, s2 = z
// Returns: x0 = result pointer
.global mat4_translate
mat4_translate:
    // Start with identity matrix
    bl      mat4_identity
    
    // Set translation values in last column
    str     s0, [x0, #48]              // [3][0] = x
    str     s1, [x0, #52]              // [3][1] = y
    str     s2, [x0, #56]              // [3][2] = z
    
    ret

// mat4_scale: Create scale matrix
// Args: x0 = mat4* result, s0 = x, s1 = y, s2 = z
// Returns: x0 = result pointer
.global mat4_scale
mat4_scale:
    // Start with zero matrix
    bl      mat4_zero
    
    // Set scale values on diagonal
    str     s0, [x0]                   // [0][0] = x
    str     s1, [x0, #20]              // [1][1] = y
    str     s2, [x0, #40]              // [2][2] = z
    fmov    s3, #1.0
    str     s3, [x0, #60]              // [3][3] = 1.0
    
    ret

// mat4_rotate_z: Create rotation matrix around Z axis
// Args: x0 = mat4* result, s0 = angle_radians
// Returns: x0 = result pointer
.global mat4_rotate_z
mat4_rotate_z:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     d8, d9, [sp, #-16]!
    
    fmov    d8, d0                     // Save angle
    
    // Calculate sin and cos
    bl      sinf                       // s0 = sin(angle)
    fmov    d9, d0                     // Save sin
    fmov    d0, d8                     // Restore angle
    bl      cosf                       // s0 = cos(angle)
    
    // Start with identity matrix
    bl      mat4_identity
    
    // Set rotation values
    str     s0, [x0]                   // [0][0] = cos
    fneg    s1, s9                     // -sin
    str     s1, [x0, #4]               // [0][1] = -sin
    str     s9, [x0, #16]              // [1][0] = sin
    str     s0, [x0, #20]              // [1][1] = cos
    
    ldp     d8, d9, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Projection Matrices
//==============================================================================

// mat4_perspective: Create perspective projection matrix
// Args: x0 = mat4* result, s0 = fov_radians, s1 = aspect, s2 = near, s3 = far
// Returns: x0 = result pointer
.global mat4_perspective
mat4_perspective:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     d8, d9, [sp, #-16]!
    stp     d10, d11, [sp, #-16]!
    
    // Save parameters
    fmov    d8, d0                     // fov
    fmov    d9, d1                     // aspect
    fmov    d10, d2                    // near
    fmov    d11, d3                    // far
    
    // Start with zero matrix
    bl      mat4_zero
    
    // Calculate cot(fov/2)
    fmov    s0, #0.5
    fmul    s0, s8, s0                 // fov/2
    bl      tanf                       // tan(fov/2)
    fmov    s1, #1.0
    fdiv    s0, s1, s0                 // cot(fov/2)
    
    // Set matrix values
    fdiv    s1, s0, s9                 // cot(fov/2) / aspect
    str     s1, [x0]                   // [0][0]
    str     s0, [x0, #20]              // [1][1] = cot(fov/2)
    
    // Calculate depth values
    fsub    s1, s10, s11               // near - far
    fadd    s2, s10, s11               // near + far
    fdiv    s2, s2, s1                 // (near + far) / (near - far)
    str     s2, [x0, #40]              // [2][2]
    
    fmov    s3, #2.0
    fmul    s3, s3, s10                // 2 * near
    fmul    s3, s3, s11                // 2 * near * far
    fdiv    s3, s3, s1                 // 2 * near * far / (near - far)
    str     s3, [x0, #56]              // [3][2]
    
    fmov    s4, #-1.0
    str     s4, [x0, #44]              // [2][3] = -1
    
    ldp     d10, d11, [sp], #16
    ldp     d8, d9, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// mat4_orthographic: Create orthographic projection matrix
// Args: x0 = mat4* result, s0 = left, s1 = right, s2 = bottom, s3 = top, s4 = near, s5 = far
// Returns: x0 = result pointer
.global mat4_orthographic
mat4_orthographic:
    // Start with zero matrix
    bl      mat4_zero
    
    // Calculate width, height, depth
    fsub    s6, s1, s0                 // width = right - left
    fsub    s7, s3, s2                 // height = top - bottom
    fsub    s16, s5, s4                // depth = far - near
    
    // Set scale values
    fmov    s17, #2.0
    fdiv    s17, s17, s6               // 2 / width
    str     s17, [x0]                  // [0][0]
    
    fdiv    s17, s17, s7               // 2 / height (reuse register)
    str     s17, [x0, #20]             // [1][1]
    
    fmov    s17, #-2.0
    fdiv    s17, s17, s16              // -2 / depth
    str     s17, [x0, #40]             // [2][2]
    
    // Set translation values
    fadd    s17, s0, s1                // left + right
    fneg    s17, s17                   // -(left + right)
    fdiv    s17, s17, s6               // -(left + right) / width
    str     s17, [x0, #48]             // [3][0]
    
    fadd    s17, s2, s3                // bottom + top
    fneg    s17, s17                   // -(bottom + top)
    fdiv    s17, s17, s7               // -(bottom + top) / height
    str     s17, [x0, #52]             // [3][1]
    
    fadd    s17, s4, s5                // near + far
    fneg    s17, s17                   // -(near + far)
    fdiv    s17, s17, s16              // -(near + far) / depth
    str     s17, [x0, #56]             // [3][2]
    
    fmov    s17, #1.0
    str     s17, [x0, #60]             // [3][3] = 1.0
    
    ret

//==============================================================================
// Isometric Projection for SimCity
//==============================================================================

// mat4_isometric: Create isometric projection matrix for SimCity view
// Args: x0 = mat4* result, s0 = scale
// Returns: x0 = result pointer
.global mat4_isometric
mat4_isometric:
    // Start with zero matrix
    bl      mat4_zero
    
    // Isometric projection matrix for 2.5D city view
    // Standard isometric angles: 30° rotation around X, 45° around Y
    
    // Precomputed values for isometric projection
    fmov    s1, #0.866025              // cos(30°) ≈ √3/2
    fmul    s1, s1, s0                 // scale * cos(30°)
    str     s1, [x0]                   // [0][0]
    
    fmov    s2, #-0.5                  // -sin(30°)
    fmul    s2, s2, s0                 // scale * -sin(30°)
    str     s2, [x0, #4]               // [0][1]
    
    fmov    s3, #0.866025              // cos(30°)
    fmul    s3, s3, s0                 // scale * cos(30°)
    str     s3, [x0, #16]              // [1][0]
    
    fmov    s4, #0.5                   // sin(30°)
    fmul    s4, s4, s0                 // scale * sin(30°)
    str     s4, [x0, #20]              // [1][1]
    
    str     s0, [x0, #40]              // [2][2] = scale (Z axis)
    
    fmov    s5, #1.0
    str     s5, [x0, #60]              // [3][3] = 1.0
    
    ret

//==============================================================================
// Vector Transformation
//==============================================================================

// mat4_transform_point: Transform 3D point by 4x4 matrix
// Args: x0 = vec3* result, x1 = mat4* matrix, x2 = vec3* point
// Returns: x0 = result pointer
.global mat4_transform_point
mat4_transform_point:
    // Load point coordinates
    ldr     s0, [x2]                   // x
    ldr     s1, [x2, #4]               // y
    ldr     s2, [x2, #8]               // z
    fmov    s3, #1.0                   // w = 1.0 for point
    
    // Load matrix rows
    ld1     {v4.4s}, [x1]              // Row 0
    ld1     {v5.4s}, [x1, #16]         // Row 1
    ld1     {v6.4s}, [x1, #32]         // Row 2
    ld1     {v7.4s}, [x1, #48]         // Row 3
    
    // Create point vector [x, y, z, 1]
    mov     v0.s[0], v0.s[0]           // x
    mov     v0.s[1], v1.s[0]           // y
    mov     v0.s[2], v2.s[0]           // z
    mov     v0.s[3], v3.s[0]           // w = 1.0
    
    // Transform point
    fmul    v8.4s, v4.4s, v0.4s        // row0 * point
    fmul    v9.4s, v5.4s, v0.4s        // row1 * point
    fmul    v10.4s, v6.4s, v0.4s       // row2 * point
    
    // Sum components for each row
    faddp   v8.4s, v8.4s, v9.4s        // [x', x', y', y']
    faddp   v10.4s, v10.4s, v10.4s     // [z', z', z', z']
    faddp   v8.4s, v8.4s, v10.4s       // [x', y', z', z']
    
    // Store result (only need first 3 components)
    str     s8, [x0]                   // result.x
    mov     v0.s[0], v8.s[1]
    str     s0, [x0, #4]               // result.y
    mov     v0.s[0], v8.s[2]
    str     s0, [x0, #8]               // result.z
    
    ret

//==============================================================================
// Batch Transformations for Performance
//==============================================================================

// mat4_transform_points_batch: Transform multiple 3D points using NEON
// Args: x0 = vec3* results, x1 = mat4* matrix, x2 = vec3* points, x3 = count
// Returns: x0 = results pointer
.global mat4_transform_points_batch
mat4_transform_points_batch:
    cbz     x3, batch_transform_done    // Exit if count is 0
    
    // Load matrix once for all transformations
    ld1     {v20.4s, v21.4s, v22.4s, v23.4s}, [x1]  // Load entire matrix
    
    // Process points in batches
batch_transform_loop:
    // Load point
    ldr     s0, [x2]                   // x
    ldr     s1, [x2, #4]               // y
    ldr     s2, [x2, #8]               // z
    fmov    s3, #1.0                   // w = 1.0
    add     x2, x2, #12                // Advance to next point
    
    // Create point vector
    mov     v0.s[0], v0.s[0]
    mov     v0.s[1], v1.s[0]
    mov     v0.s[2], v2.s[0]
    mov     v0.s[3], v3.s[0]
    
    // Transform point (matrix * point)
    fmul    v4.4s, v20.4s, v0.4s       // row0 * point
    fmul    v5.4s, v21.4s, v0.4s       // row1 * point
    fmul    v6.4s, v22.4s, v0.4s       // row2 * point
    
    // Sum components
    faddp   v4.4s, v4.4s, v5.4s
    faddp   v6.4s, v6.4s, v6.4s
    faddp   v4.4s, v4.4s, v6.4s
    
    // Store result
    str     s4, [x0]                   // result.x
    mov     v7.s[0], v4.s[1]
    str     s7, [x0, #4]               // result.y
    mov     v7.s[0], v4.s[2]
    str     s7, [x0, #8]               // result.z
    add     x0, x0, #12                // Advance to next result
    
    subs    x3, x3, #1                 // Decrement counter
    b.ne    batch_transform_loop
    
batch_transform_done:
    ret

//==============================================================================
// Performance Monitoring
//==============================================================================

// mat4_benchmark: Benchmark matrix multiplication performance
// Args: x0 = iterations
// Returns: x0 = time_ns
.global mat4_benchmark
mat4_benchmark:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0                    // Save iterations
    
    // Allocate test matrices
    mov     x0, #192                   // 3 * 64 bytes for matrices
    bl      malloc
    mov     x20, x0                    // Save pointer
    
    // Initialize test matrices
    mov     x0, x20                    // Result matrix
    bl      mat4_identity
    add     x0, x20, #64               // Matrix A
    bl      mat4_identity
    add     x0, x20, #128              // Matrix B
    bl      mat4_identity
    
    // Start timing
    mrs     x0, cntvct_el0
    mov     x21, x0
    
    // Benchmark loop
    mov     x2, x19
benchmark_loop:
    mov     x0, x20                    // Result
    add     x1, x20, #64               // Matrix A
    add     x2, x20, #128              // Matrix B
    bl      mat4_multiply
    
    subs    x2, x2, #1
    b.ne    benchmark_loop
    
    // End timing
    mrs     x0, cntvct_el0
    sub     x0, x0, x21                // Total cycles
    
    // Free test matrices
    mov     x1, x20
    mov     x20, x0                    // Save timing result
    mov     x0, x1
    bl      free
    
    mov     x0, x20                    // Return timing
    
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

.end