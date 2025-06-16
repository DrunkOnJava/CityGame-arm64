// positional.s - 3D Spatial Audio System for SimCity ARM64
// High-performance 3D audio with HRTF, distance attenuation, and occlusion
// Optimized for real-time processing of 100+ simultaneous positioned sounds

.section __TEXT,__text,regular,pure_instructions
.global _audio_3d_init
.global _audio_3d_shutdown
.global _audio_3d_set_listener
.global _audio_3d_create_source
.global _audio_3d_destroy_source
.global _audio_3d_set_source_position
.global _audio_3d_set_source_velocity
.global _audio_3d_process_frame
.global _audio_3d_update_sources
.align 2

// 3D Audio constants
.equ MAX_AUDIO_SOURCES, 128         // Support 128 simultaneous positioned sounds
.equ HRTF_LENGTH, 256               // HRTF filter length (samples)
.equ MAX_DISTANCE, 1000             // Maximum audible distance (units)
.equ SPEED_OF_SOUND, 343            // m/s for Doppler calculations
.equ OCCLUSION_RAYS, 8              // Number of rays for occlusion testing
.equ DISTANCE_MODEL_LINEAR, 0
.equ DISTANCE_MODEL_INVERSE, 1
.equ DISTANCE_MODEL_EXPONENTIAL, 2

// HRTF interpolation constants
.equ HRTF_AZIMUTH_RESOLUTION, 5     // Degrees between HRTF samples
.equ HRTF_ELEVATION_RESOLUTION, 10  // Degrees between HRTF samples
.equ NUM_HRTF_AZIMUTHS, 72          // 360 / 5
.equ NUM_HRTF_ELEVATIONS, 19        // 180 / 10 + 1

.section __DATA,__data
.align 3

// Listener state
listener_position:
    .float 0.0, 0.0, 0.0            // x, y, z

listener_velocity:
    .float 0.0, 0.0, 0.0            // vx, vy, vz

listener_orientation:
    .float 0.0, 0.0, -1.0           // Forward vector (x, y, z)
    .float 0.0, 1.0, 0.0            // Up vector (x, y, z)

// Audio source pool
audio_sources:
    .space MAX_AUDIO_SOURCES * 128  // Each source: 128 bytes

// Source active flags
source_active:
    .space MAX_AUDIO_SOURCES        // Byte per source

// Source free list
source_free_list:
    .space MAX_AUDIO_SOURCES * 4    // Int32 indices

source_free_count:
    .long MAX_AUDIO_SOURCES

// HRTF coefficient storage (simplified - normally loaded from file)
hrtf_coefficients:
    .space NUM_HRTF_AZIMUTHS * NUM_HRTF_ELEVATIONS * HRTF_LENGTH * 2 * 4  // L/R channels, float32

// Distance attenuation lookup table
distance_attenuation_table:
    .space 1024 * 4                 // 1024 entries, float32

// Advanced HRTF processing state
hrtf_convolution_buffers:
    .space MAX_AUDIO_SOURCES * HRTF_LENGTH * 2 * 4  // Left/Right conv buffers per source

// Doppler processing state
doppler_delay_lines:
    .space MAX_AUDIO_SOURCES * 1024 * 4  // Delay lines for Doppler

previous_source_positions:
    .space MAX_AUDIO_SOURCES * 12   // Previous positions for velocity calculation

// Environmental parameters
air_absorption_coefficients:
    .float 0.0002, 0.0005, 0.001, 0.002, 0.004, 0.008  // Per frequency band

occlusion_levels:
    .space MAX_AUDIO_SOURCES * 4    // Occlusion factor per source

// System state
audio_3d_initialized:
    .long 0

listener_gain:
    .float 1.0

master_3d_enabled:
    .long 1

.section __TEXT,__text

// Audio source structure (128 bytes)
// Offset 0:   position (3 floats, 12 bytes)
// Offset 12:  velocity (3 floats, 12 bytes) 
// Offset 24:  gain (float, 4 bytes)
// Offset 28:  pitch (float, 4 bytes)
// Offset 32:  reference_distance (float, 4 bytes)
// Offset 36:  max_distance (float, 4 bytes)
// Offset 40:  rolloff_factor (float, 4 bytes)
// Offset 44:  distance_model (int32, 4 bytes)
// Offset 48:  cone_inner_angle (float, 4 bytes)
// Offset 52:  cone_outer_angle (float, 4 bytes)
// Offset 56:  cone_outer_gain (float, 4 bytes)
// Offset 60:  direction (3 floats, 12 bytes)
// Offset 72:  last_left_gain (float, 4 bytes)
// Offset 76:  last_right_gain (float, 4 bytes)
// Offset 80:  delay_left_samples (int32, 4 bytes)
// Offset 84:  delay_right_samples (int32, 4 bytes)
// Offset 88:  hrtf_left_coeffs (pointer, 8 bytes)
// Offset 96:  hrtf_right_coeffs (pointer, 8 bytes)
// Offset 104: convolution_state (24 bytes for SIMD alignment)

// Initialize 3D audio system
// Returns: x0 = 0 on success, error code on failure
_audio_3d_init:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    // Check if already initialized
    adrp x19, audio_3d_initialized@PAGE
    add x19, x19, audio_3d_initialized@PAGEOFF
    ldr w0, [x19]
    cbnz w0, init_3d_already_done
    
    // Initialize source free list
    bl init_source_pool
    
    // Load or generate HRTF data
    bl init_hrtf_data
    cbnz x0, init_3d_error
    
    // Build distance attenuation lookup table
    bl build_distance_table
    
    // Initialize listener to default position
    bl reset_listener_state
    
    // Mark as initialized
    mov w0, #1
    str w0, [x19]
    
    mov x0, #0                  // Success
    b init_3d_done

init_3d_already_done:
    mov x0, #-1                 // Already initialized
    b init_3d_done

init_3d_error:
    mov x0, #-2                 // Initialization failed

init_3d_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Initialize the audio source pool
init_source_pool:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    // Clear all sources
    adrp x19, audio_sources@PAGE
    add x19, x19, audio_sources@PAGEOFF
    mov x0, x19
    mov x1, #0
    mov x2, #MAX_AUDIO_SOURCES * 128
    bl memset
    
    // Clear active flags
    adrp x20, source_active@PAGE
    add x20, x20, source_active@PAGEOFF
    mov x0, x20
    mov x1, #0
    mov x2, #MAX_AUDIO_SOURCES
    bl memset
    
    // Initialize free list with all indices
    adrp x19, source_free_list@PAGE
    add x19, x19, source_free_list@PAGEOFF
    mov w20, #0                 // Counter
    
init_free_list_loop:
    cmp w20, #MAX_AUDIO_SOURCES
    b.ge init_free_list_done
    str w20, [x19, x20, lsl #2] // Store index
    add w20, w20, #1
    b init_free_list_loop

init_free_list_done:
    // Set free count
    adrp x0, source_free_count@PAGE
    add x0, x0, source_free_count@PAGEOFF
    mov w1, #MAX_AUDIO_SOURCES
    str w1, [x0]
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Initialize HRTF data (simplified version - normally loaded from file)
init_hrtf_data:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // For now, initialize with simple panning coefficients
    // In a real implementation, this would load HRTF measurements
    adrp x0, hrtf_coefficients@PAGE
    add x0, x0, hrtf_coefficients@PAGEOFF
    
    // Generate simple stereo panning HRTF approximation
    bl generate_simple_hrtf
    
    mov x0, #0                  // Success
    ldp x29, x30, [sp], #16
    ret

// Generate simplified HRTF coefficients based on azimuth
generate_simple_hrtf:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    mov x19, x0                 // HRTF buffer
    mov w20, #0                 // Azimuth counter
    
hrtf_azimuth_loop:
    cmp w20, #NUM_HRTF_AZIMUTHS
    b.ge hrtf_generation_done
    
    // Calculate angle in radians
    scvtf s0, w20               // Convert to float
    fmov s1, #5.0               // Azimuth resolution
    fmul s0, s0, s1             // Angle in degrees
    fmov s1, #0.017453292       // Pi/180 for conversion to radians
    fmul s0, s0, s1             // Angle in radians
    
    // Calculate left and right gains using simple cosine panning
    bl cosf                     // cos(angle)
    fmov s1, #0.5
    fadd s1, s0, s1             // (cos(angle) + 1) / 2 for left gain
    fmov s2, #1.0
    fsub s2, s2, s1             // 1 - left_gain for right gain
    
    // Store coefficients for all elevations (simplified)
    mov w21, #0                 // Elevation counter
    
hrtf_elevation_loop:
    cmp w21, #NUM_HRTF_ELEVATIONS
    b.ge hrtf_next_azimuth
    
    // Calculate buffer offset
    umull x22, w20, #NUM_HRTF_ELEVATIONS
    add x22, x22, x21, lsl #0   // Add elevation
    mov w0, #HRTF_LENGTH * 2 * 4  // Size per HRTF pair
    umull x22, w22, w0
    add x22, x19, x22           // Final address
    
    // Store left channel coefficients
    mov w0, #0                  // Sample counter
hrtf_left_loop:
    cmp w0, #HRTF_LENGTH
    b.ge hrtf_store_right
    str s1, [x22, x0, lsl #2]   // Store left gain
    add w0, w0, #1
    b hrtf_left_loop
    
hrtf_store_right:
    // Store right channel coefficients
    add x22, x22, #HRTF_LENGTH * 4  // Offset to right channel
    mov w0, #0                  // Sample counter
hrtf_right_loop:
    cmp w0, #HRTF_LENGTH
    b.ge hrtf_next_elevation
    str s2, [x22, x0, lsl #2]   // Store right gain
    add w0, w0, #1
    b hrtf_right_loop

hrtf_next_elevation:
    add w21, w21, #1
    b hrtf_elevation_loop

hrtf_next_azimuth:
    add w20, w20, #1
    b hrtf_azimuth_loop

hrtf_generation_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Build distance attenuation lookup table
build_distance_table:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    adrp x19, distance_attenuation_table@PAGE
    add x19, x19, distance_attenuation_table@PAGEOFF
    mov w20, #0                 // Index counter
    
distance_table_loop:
    cmp w20, #1024
    b.ge distance_table_done
    
    // Calculate distance: index * (MAX_DISTANCE / 1024)
    scvtf s0, w20               // Convert index to float
    fmov s1, #MAX_DISTANCE      // Max distance
    fmov s2, #1024.0            // Table size
    fdiv s1, s1, s2             // Distance per entry
    fmul s0, s0, s1             // Current distance
    
    // Realistic attenuation model with air absorption
    // Base inverse square law: 1 / (distance^2)
    fmul s1, s0, s0             // distance^2
    fmov s2, #1.0
    fadd s1, s1, s2             // 1 + distance^2 (avoid divide by zero)
    fdiv s1, s2, s1             // 1 / (1 + distance^2)
    
    // Apply air absorption (high frequency rolloff)
    fmov s2, #0.001             // Air absorption coefficient
    fmul s3, s0, s2             // distance * absorption
    fneg s3, s3                 // -distance * absorption
    bl expf                     // exp(-distance * absorption)
    fmul s1, s1, s0             // Combine with distance attenuation
    
    // Clamp to reasonable range
    fmov s2, #0.0001            // Minimum attenuation
    fmax s1, s1, s2
    fmov s2, #1.0               // Maximum attenuation
    fmin s1, s1, s2
    
    // Store in table
    str s1, [x19, x20, lsl #2]
    add w20, w20, #1
    b distance_table_loop

distance_table_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Reset listener to default state
reset_listener_state:
    // Set listener position to origin
    adrp x0, listener_position@PAGE
    add x0, x0, listener_position@PAGEOFF
    movi v0.4s, #0
    str q0, [x0]                // Clear position and velocity
    
    // Set default orientation (forward = -Z, up = +Y)
    adrp x0, listener_orientation@PAGE
    add x0, x0, listener_orientation@PAGEOFF
    fmov s0, #0.0               // Forward X
    fmov s1, #0.0               // Forward Y
    fmov s2, #-1.0              // Forward Z
    fmov s3, #0.0               // Up X
    str s0, [x0]
    str s1, [x0, #4]
    str s2, [x0, #8]
    str s3, [x0, #12]
    fmov s0, #1.0               // Up Y
    fmov s1, #0.0               // Up Z
    str s0, [x0, #16]
    str s1, [x0, #20]
    
    ret

// Set listener position and orientation
// x0 = pointer to position (3 floats)
// x1 = pointer to forward vector (3 floats)
// x2 = pointer to up vector (3 floats)
_audio_3d_set_listener:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Copy position
    adrp x3, listener_position@PAGE
    add x3, x3, listener_position@PAGEOFF
    ldr q0, [x0]                // Load position (assuming 4th component is ignored)
    str q0, [x3]
    
    // Copy orientation
    adrp x3, listener_orientation@PAGE
    add x3, x3, listener_orientation@PAGEOFF
    ldr q0, [x1]                // Load forward vector
    str q0, [x3]
    ldr q0, [x2]                // Load up vector
    str q0, [x3, #16]
    
    ldp x29, x30, [sp], #16
    ret

// Create a new audio source
// Returns: x0 = source ID (0-127), or -1 if no free sources
_audio_3d_create_source:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    // Check if we have free sources
    adrp x19, source_free_count@PAGE
    add x19, x19, source_free_count@PAGEOFF
    ldr w20, [x19]
    cbz w20, create_source_failed
    
    // Get source from free list
    sub w20, w20, #1
    str w20, [x19]              // Update free count
    
    adrp x19, source_free_list@PAGE
    add x19, x19, source_free_list@PAGEOFF
    ldr w0, [x19, x20, lsl #2]  // Get source ID from free list
    
    // Mark source as active
    adrp x1, source_active@PAGE
    add x1, x1, source_active@PAGEOFF
    mov w2, #1
    strb w2, [x1, x0]
    
    // Initialize source to defaults
    bl init_source_defaults
    
    b create_source_done

create_source_failed:
    mov x0, #-1                 // No free sources

create_source_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Initialize source with default values
// x0 = source ID
init_source_defaults:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Calculate source address
    mov x1, #128                // Source size
    umull x1, w0, w1
    adrp x2, audio_sources@PAGE
    add x2, x2, audio_sources@PAGEOFF
    add x1, x2, x1              // Source address
    
    // Clear entire source structure
    mov x0, x1
    mov x1, #0
    mov x2, #128
    bl memset
    
    // Set default values
    // gain = 1.0, pitch = 1.0, reference_distance = 1.0
    // max_distance = 1000.0, rolloff_factor = 1.0
    fmov s0, #1.0
    str s0, [x1, #24]           // gain
    str s0, [x1, #28]           // pitch
    str s0, [x1, #32]           // reference_distance
    str s0, [x1, #40]           // rolloff_factor
    fmov s0, #1000.0
    str s0, [x1, #36]           // max_distance
    
    // Set default cone angles (360 degrees = no directivity)
    fmov s0, #360.0
    str s0, [x1, #48]           // cone_inner_angle
    str s0, [x1, #52]           // cone_outer_angle
    fmov s0, #1.0
    str s0, [x1, #56]           // cone_outer_gain
    
    ldp x29, x30, [sp], #16
    ret

// Destroy an audio source
// x0 = source ID
_audio_3d_destroy_source:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    // Validate source ID
    cmp w0, #MAX_AUDIO_SOURCES
    b.ge destroy_source_done
    
    mov w19, w0                 // Save source ID
    
    // Check if source is active
    adrp x20, source_active@PAGE
    add x20, x20, source_active@PAGEOFF
    ldrb w1, [x20, x19]
    cbz w1, destroy_source_done // Not active
    
    // Mark as inactive
    strb wzr, [x20, x19]
    
    // Add back to free list
    adrp x20, source_free_count@PAGE
    add x20, x20, source_free_count@PAGEOFF
    ldr w1, [x20]
    
    adrp x2, source_free_list@PAGE
    add x2, x2, source_free_list@PAGEOFF
    str w19, [x2, x1, lsl #2]   // Store source ID in free list
    
    add w1, w1, #1
    str w1, [x20]               // Increment free count

destroy_source_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Set source position
// x0 = source ID
// x1 = pointer to position (3 floats)
_audio_3d_set_source_position:
    // Validate source ID
    cmp w0, #MAX_AUDIO_SOURCES
    b.ge set_position_done
    
    // Check if source is active
    adrp x2, source_active@PAGE
    add x2, x2, source_active@PAGEOFF
    ldrb w2, [x2, x0]
    cbz w2, set_position_done
    
    // Calculate source address
    mov x2, #128
    umull x2, w0, w2
    adrp x3, audio_sources@PAGE
    add x3, x3, audio_sources@PAGEOFF
    add x2, x3, x2
    
    // Copy position
    ldr q0, [x1]
    str q0, [x2]                // Store position at offset 0

set_position_done:
    ret

// Set source velocity
// x0 = source ID
// x1 = pointer to velocity (3 floats)
_audio_3d_set_source_velocity:
    // Validate source ID
    cmp w0, #MAX_AUDIO_SOURCES
    b.ge set_velocity_done
    
    // Check if source is active
    adrp x2, source_active@PAGE
    add x2, x2, source_active@PAGEOFF
    ldrb w2, [x2, x0]
    cbz w2, set_velocity_done
    
    // Calculate source address
    mov x2, #128
    umull x2, w0, w2
    adrp x3, audio_sources@PAGE
    add x3, x3, audio_sources@PAGEOFF
    add x2, x3, x2
    
    // Copy velocity
    ldr q0, [x1]
    str q0, [x2, #12]           // Store velocity at offset 12

set_velocity_done:
    ret

// Process 3D audio for current frame
// x0 = output buffer (interleaved stereo)
// x1 = number of frames
// x2 = input sources array
// x3 = number of active sources
_audio_3d_process_frame:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    
    mov x19, x0                 // Output buffer
    mov x20, x1                 // Frame count
    mov x21, x2                 // Input sources
    mov x22, x3                 // Source count
    
    // Clear output buffer
    mov x0, x19
    mov x1, #0
    lsl x2, x20, #3             // frames * 2 channels * 4 bytes
    bl memset
    
    // Process each active source
    mov x23, #0                 // Source counter
    
process_source_loop:
    cmp x23, x22
    b.ge process_frame_done
    
    // Get source ID and audio data
    ldr w0, [x21, x23, lsl #3]  // Source ID
    ldr x1, [x21, x23, lsl #3, #4]  // Audio data pointer
    
    // Process this source
    mov x2, x19                 // Output buffer
    mov x3, x20                 // Frame count
    bl process_single_source
    
    add x23, x23, #1
    b process_source_loop

process_frame_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// Process a single 3D audio source
// x0 = source ID
// x1 = input audio data
// x2 = output buffer (interleaved stereo)
// x3 = frame count
process_single_source:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    
    mov w19, w0                 // Source ID
    mov x20, x1                 // Input data
    mov x21, x2                 // Output buffer
    mov x22, x3                 // Frame count
    
    // Get source structure
    mov x0, #128
    umull x0, w19, w0
    adrp x23, audio_sources@PAGE
    add x23, x23, audio_sources@PAGEOFF
    add x23, x23, x0            // Source address
    
    // Calculate 3D parameters
    bl calculate_3d_parameters
    
    // Apply 3D spatialization and mix to output
    mov x0, x20                 // Input data
    mov x1, x21                 // Output buffer
    mov x2, x22                 // Frame count
    mov x3, x23                 // Source structure
    bl apply_3d_spatialization

process_single_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// Calculate 3D audio parameters (distance, angle, etc.)
// x23 = source structure
calculate_3d_parameters:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    // Load source and listener positions
    ldr q0, [x23]               // Source position
    adrp x19, listener_position@PAGE
    add x19, x19, listener_position@PAGEOFF
    ldr q1, [x19]               // Listener position
    
    // Calculate distance vector
    fsub v2.4s, v0.4s, v1.4s    // source - listener
    
    // Calculate distance
    fmul v3.4s, v2.4s, v2.4s    // Square components
    faddp v4.2s, v3.2s, v3.2s   // Add pairs
    faddp s5, v4.2s             // Add final pair
    fadd s5, s5, v3.s[2]        // Add Z component
    fsqrt s5, s5                // Distance
    
    // Calculate azimuth angle
    // atan2(x, -z) for standard audio coordinates
    fmov s0, v2.s[0]            // X component
    fneg s1, v2.s[2]            // -Z component
    bl atan2f
    // s0 now contains azimuth in radians
    
    // Convert to degrees and normalize to 0-359
    fmov s1, #57.29578          // 180/PI
    fmul s0, s0, s1             // Convert to degrees
    fcmp s0, #0.0
    b.ge azimuth_positive
    fadd s0, s0, #360.0         // Make positive
azimuth_positive:
    
    // Calculate elevation angle
    fdiv s1, v2.s[1], s5        // Y / distance
    bl asinf                    // asin(y/distance)
    fmul s1, s0, #57.29578      // Convert to degrees
    
    // Store calculated values in source structure
    str s5, [x23, #88]          // Distance (temporary storage)
    str s0, [x23, #92]          // Azimuth
    str s1, [x23, #96]          // Elevation
    
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Apply 3D spatialization to audio
// x0 = input data
// x1 = output buffer
// x2 = frame count
// x3 = source structure
apply_3d_spatialization:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    
    mov x19, x0                 // Input data
    mov x20, x1                 // Output buffer
    mov x21, x2                 // Frame count
    mov x22, x3                 // Source structure
    
    // Load distance and calculate attenuation
    ldr s0, [x22, #88]          // Distance
    bl calculate_distance_attenuation
    // s0 now contains attenuation factor
    
    // Load azimuth and calculate HRTF gains
    ldr s1, [x22, #92]          // Azimuth
    bl calculate_hrtf_gains
    // s0 = left gain, s1 = right gain
    
    // Apply gains and mix to output
    mov x23, #0                 // Frame counter

spatialization_loop:
    cmp x23, x21
    b.ge spatialization_done
    
    // Load input sample
    ldr s2, [x19, x23, lsl #2]
    
    // Apply left channel
    fmul s3, s2, s0             // input * left_gain
    ldr s4, [x20, x23, lsl #3]  // Current left output
    fadd s4, s4, s3             // Add to existing
    str s4, [x20, x23, lsl #3]  // Store back
    
    // Apply right channel
    fmul s3, s2, s1             // input * right_gain
    ldr s4, [x20, x23, lsl #3, #4]  // Current right output
    fadd s4, s4, s3             // Add to existing
    str s4, [x20, x23, lsl #3, #4]  // Store back
    
    add x23, x23, #1
    b spatialization_loop

spatialization_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// Calculate distance-based attenuation
// s0 = distance
// Returns: s0 = attenuation factor
calculate_distance_attenuation:
    // Clamp distance to reasonable range
    fmov s1, #0.1               // Minimum distance
    fmax s0, s0, s1
    fmov s1, #1000.0            // Maximum distance
    fmin s0, s0, s1
    
    // Simple inverse distance law: 1 / (1 + distance)
    fmov s1, #1.0
    fadd s0, s0, s1
    fdiv s0, s1, s0
    
    ret

// Calculate HRTF-based stereo gains with realistic processing
// s1 = azimuth in degrees
// s2 = elevation in degrees
// s3 = distance
// Returns: s0 = left gain, s1 = right gain, s2 = left delay, s3 = right delay
calculate_hrtf_gains:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    // Save input parameters
    fmov s4, s1                 // azimuth
    fmov s5, s2                 // elevation
    fmov s6, s3                 // distance
    
    // Normalize azimuth to 0-360 range
    fcmp s4, #0.0
    b.ge azimuth_positive
    fadd s4, s4, #360.0
azimuth_positive:
    fmov s7, #360.0
    fcmp s4, s7
    b.lt azimuth_normalized
    fsub s4, s4, s7
azimuth_normalized:
    
    // Calculate HRTF index for azimuth
    fmov s7, #HRTF_AZIMUTH_RESOLUTION
    fdiv s8, s4, s7             // Azimuth index (float)
    fcvtzs w19, s8              // Integer part
    fsub s8, s8, s8             // Fractional part (for interpolation)
    
    // Calculate HRTF index for elevation (clamp to valid range)
    fadd s9, s5, #90.0          // Convert -90..90 to 0..180
    fmov s7, #HRTF_ELEVATION_RESOLUTION
    fdiv s10, s9, s7            // Elevation index (float)
    fcvtzs w20, s10             // Integer part
    fsub s10, s10, s10          // Fractional part
    
    // Clamp indices to valid ranges
    cmp w19, #NUM_HRTF_AZIMUTHS
    csel w19, wzr, w19, ge      // Wrap azimuth
    cmp w20, #0
    csel w20, wzr, w20, lt      // Clamp elevation low
    cmp w20, #NUM_HRTF_ELEVATIONS-1
    mov w21, #NUM_HRTF_ELEVATIONS-1
    csel w20, w21, w20, gt      // Clamp elevation high
    
    // Calculate base HRTF coefficient address
    adrp x21, hrtf_coefficients@PAGE
    add x21, x21, hrtf_coefficients@PAGEOFF
    
    // Calculate offset: (azimuth * NUM_ELEVATIONS + elevation) * HRTF_LENGTH * 2 * 4
    mov w22, #NUM_HRTF_ELEVATIONS
    mul w22, w19, w22           // azimuth * NUM_ELEVATIONS
    add w22, w22, w20           // + elevation
    mov w0, #HRTF_LENGTH * 2 * 4  // * coeffs per position
    umull x22, w22, w0
    add x21, x21, x22           // Final coefficient address
    
    // Load left and right HRTF gains (simplified to first coefficient)
    ldr s0, [x21]               // Left gain
    add x21, x21, #HRTF_LENGTH * 4
    ldr s1, [x21]               // Right gain
    
    // Calculate interaural time delay (ITD) based on azimuth
    // ITD = (head_radius / speed_of_sound) * sin(azimuth)
    fmov s7, #0.017453292       // PI/180
    fmul s4, s4, s7             // Convert azimuth to radians
    bl sinf                     // sin(azimuth)
    fmov s7, #0.0875            // Head radius (8.75cm)
    fmul s4, s0, s7             // radius * sin(azimuth)
    fmov s7, #343.0             // Speed of sound
    fdiv s4, s4, s7             // ITD in seconds
    
    // Convert ITD to samples at 44.1kHz
    fmov s7, #44100.0           // Sample rate
    fmul s4, s4, s7             // ITD in samples
    
    // Calculate left and right delays
    fcmp s4, #0.0
    b.ge itd_right_delayed
    // Left ear delayed
    fneg s2, s4                 // Left delay = -ITD
    fmov s3, #0.0               // Right delay = 0
    b itd_done
itd_right_delayed:
    // Right ear delayed
    fmov s2, #0.0               // Left delay = 0
    fmov s3, s4                 // Right delay = ITD
itd_done:
    
    // Apply distance-based gain reduction
    fmov s7, #1.0
    fadd s8, s6, s7             // 1 + distance
    fdiv s7, s7, s8             // 1 / (1 + distance)
    fmul s0, s0, s7             // Scale left gain
    fmul s1, s1, s7             // Scale right gain
    
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Update all active sources (called once per frame)
_audio_3d_update_sources:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    mov x19, #0                 // Source counter
    
update_sources_loop:
    cmp x19, #MAX_AUDIO_SOURCES
    b.ge update_sources_done
    
    // Check if source is active
    adrp x20, source_active@PAGE
    add x20, x20, source_active@PAGEOFF
    ldrb w0, [x20, x19]
    cbz w0, update_next_source
    
    // Update source parameters
    mov x0, x19
    bl update_single_source

update_next_source:
    add x19, x19, #1
    b update_sources_loop

update_sources_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Update a single source (Doppler, occlusion, etc.)
// x0 = source ID
update_single_source:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    
    mov w19, w0                 // Source ID
    
    // Get source structure
    mov x0, #128
    umull x0, w19, w0
    adrp x20, audio_sources@PAGE
    add x20, x20, audio_sources@PAGEOFF
    add x20, x20, x0            // Source address
    
    // Calculate Doppler effect
    bl calculate_doppler_effect
    
    // Calculate occlusion
    bl calculate_occlusion
    
    // Update previous position for next frame
    bl update_previous_position
    
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// Calculate Doppler effect for source
// x19 = source ID, x20 = source structure
calculate_doppler_effect:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x21, x22, [sp, #16]
    stp x23, x24, [sp, #32]
    
    // Load current and previous positions
    ldr q0, [x20]               // Current position
    
    // Get previous position
    adrp x21, previous_source_positions@PAGE
    add x21, x21, previous_source_positions@PAGEOFF
    mov x22, #12                // 3 floats per position
    umull x22, w19, w22
    add x21, x21, x22           // Previous position address
    ldr q1, [x21]               // Previous position
    
    // Calculate velocity: (current - previous) / dt
    fsub v2.4s, v0.4s, v1.4s    // Position delta
    fmov s3, #60.0              // Assume 60 FPS (1/60 second dt)
    fmul v2.4s, v2.4s, v3.s[0]  // Velocity = delta / dt
    
    // Get listener position and velocity
    adrp x22, listener_position@PAGE
    add x22, x22, listener_position@PAGEOFF
    ldr q4, [x22]               // Listener position
    adrp x22, listener_velocity@PAGE
    add x22, x22, listener_velocity@PAGEOFF
    ldr q5, [x22]               // Listener velocity
    
    // Calculate relative velocity
    fsub v6.4s, v2.4s, v5.4s    // Source vel - listener vel
    
    // Calculate distance vector (source - listener)
    fsub v7.4s, v0.4s, v4.4s    // Distance vector
    
    // Calculate distance
    fmul v8.4s, v7.4s, v7.4s    // Square components
    faddp v9.2s, v8.2s, v8.2s   // Add pairs
    faddp s10, v9.2s            // Add final pair  
    fadd s10, s10, v8.s[2]      // Add Z component
    fsqrt s10, s10              // Distance
    
    // Normalize distance vector
    fdiv v7.4s, v7.4s, v10.s[0] // Unit vector toward source
    
    // Calculate radial velocity (component toward listener)
    fmul v11.4s, v6.4s, v7.4s   // Dot product components
    faddp v12.2s, v11.2s, v11.2s
    faddp s13, v12.2s
    fadd s13, s13, v11.s[2]     // Radial velocity
    
    // Calculate Doppler factor: (speed_of_sound + listener_vel) / (speed_of_sound + source_vel)
    fmov s14, #SPEED_OF_SOUND   // Speed of sound
    fadd s15, s14, s13          // Denominator: c + v_source
    fsub s16, s14, s13          // Numerator: c - v_source (approaching = higher pitch)
    fdiv s17, s16, s15          // Doppler factor
    
    // Clamp Doppler factor to reasonable range (0.5 to 2.0)
    fmov s18, #0.5
    fmax s17, s17, s18
    fmov s18, #2.0
    fmin s17, s17, s18
    
    // Store Doppler factor in source pitch field
    str s17, [x20, #28]         // Update pitch
    
    ldp x23, x24, [sp, #32]
    ldp x21, x22, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Calculate occlusion level for source
// x19 = source ID, x20 = source structure
calculate_occlusion:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x21, x22, [sp, #16]
    
    // Simple occlusion model based on distance and angle
    // In a real implementation, this would trace rays through geometry
    
    // Load source and listener positions
    ldr q0, [x20]               // Source position
    adrp x21, listener_position@PAGE
    add x21, x21, listener_position@PAGEOFF
    ldr q1, [x21]               // Listener position
    
    // Calculate distance
    fsub v2.4s, v0.4s, v1.4s    // Distance vector
    fmul v3.4s, v2.4s, v2.4s    // Square components
    faddp v4.2s, v3.2s, v3.2s   // Add pairs
    faddp s5, v4.2s             // Add final pair
    fadd s5, s5, v3.s[2]        // Add Z component
    fsqrt s5, s5                // Distance
    
    // Simple occlusion model: more occlusion with distance
    fmov s6, #100.0             // Distance where occlusion starts
    fcmp s5, s6
    b.lt no_occlusion
    
    // Calculate occlusion factor based on distance
    fsub s7, s5, s6             // Distance beyond threshold
    fmov s8, #500.0             // Max occlusion distance
    fdiv s7, s7, s8             // Normalize
    fmov s8, #1.0
    fmin s7, s7, s8             // Clamp to 1.0
    
    // Store occlusion level
    adrp x21, occlusion_levels@PAGE
    add x21, x21, occlusion_levels@PAGEOFF
    str s7, [x21, x19, lsl #2]
    b occlusion_done

no_occlusion:
    // No occlusion
    adrp x21, occlusion_levels@PAGE
    add x21, x21, occlusion_levels@PAGEOFF
    fmov s7, #0.0
    str s7, [x21, x19, lsl #2]

occlusion_done:
    ldp x21, x22, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Update previous position for next frame
// x19 = source ID, x20 = source structure
update_previous_position:
    // Get previous position storage
    adrp x0, previous_source_positions@PAGE
    add x0, x0, previous_source_positions@PAGEOFF
    mov x1, #12                 // 3 floats per position
    umull x1, w19, w1
    add x0, x0, x1              // Previous position address
    
    // Copy current position to previous
    ldr q0, [x20]               // Current position
    str q0, [x0]                // Store as previous
    
    ret

// Shutdown 3D audio system
_audio_3d_shutdown:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Mark as uninitialized
    adrp x0, audio_3d_initialized@PAGE
    add x0, x0, audio_3d_initialized@PAGEOFF
    str wzr, [x0]
    
    // Clear all sources
    adrp x0, source_active@PAGE
    add x0, x0, source_active@PAGEOFF
    mov x1, #0
    mov x2, #MAX_AUDIO_SOURCES
    bl memset
    
    ldp x29, x30, [sp], #16
    ret

// External function declarations
.extern memset
.extern cosf
.extern sinf
.extern atan2f
.extern asinf
.extern expf
.extern sqrtf
.extern logf