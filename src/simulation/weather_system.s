// weather_system.s - Dynamic Weather System for SimCity ARM64
// Realistic weather simulation with precipitation, wind, temperature, and atmospheric effects
// Integrates with audio, lighting, and visual systems for immersive environmental experience

.section __TEXT,__text,regular,pure_instructions
.global _weather_system_init
.global _weather_system_update
.global _weather_system_shutdown
.global _weather_get_current_conditions
.global _weather_set_climate_zone
.global _weather_force_condition
.global _weather_get_precipitation_intensity
.global _weather_get_wind_vector
.global _weather_get_temperature
.global _weather_get_visibility
.align 2

// Weather condition types
.equ WEATHER_CLEAR, 0
.equ WEATHER_PARTLY_CLOUDY, 1
.equ WEATHER_OVERCAST, 2
.equ WEATHER_LIGHT_RAIN, 3
.equ WEATHER_HEAVY_RAIN, 4
.equ WEATHER_THUNDERSTORM, 5
.equ WEATHER_LIGHT_SNOW, 6
.equ WEATHER_HEAVY_SNOW, 7
.equ WEATHER_BLIZZARD, 8
.equ WEATHER_FOG, 9
.equ WEATHER_HAIL, 10
.equ WEATHER_TORNADO, 11

// Climate zones
.equ CLIMATE_TEMPERATE, 0
.equ CLIMATE_TROPICAL, 1
.equ CLIMATE_ARID, 2
.equ CLIMATE_CONTINENTAL, 3
.equ CLIMATE_POLAR, 4

// Weather simulation constants
.equ MAX_WEATHER_PARTICLES, 2048
.equ WEATHER_GRID_SIZE, 64
.equ WIND_VECTOR_COUNT, 16
.equ PRESSURE_SYSTEM_COUNT, 8
.equ WEATHER_UPDATE_INTERVAL, 3600  // Update every game hour

.section __DATA,__data
.align 3

// Current weather state
current_weather_condition:
    .long WEATHER_CLEAR

current_temperature:
    .float 20.0                     // Celsius

current_humidity:
    .float 0.5                      // 0.0 - 1.0

current_pressure:
    .float 1013.25                  // hPa (standard atmospheric pressure)

current_visibility:
    .float 10000.0                  // meters

precipitation_intensity:
    .float 0.0                      // 0.0 - 1.0

cloud_coverage:
    .float 0.0                      // 0.0 - 1.0

// Wind system
wind_speed:
    .float 0.0                      // m/s

wind_direction:
    .float 0.0                      // radians (0 = North)

wind_gusts:
    .float 0.0                      // gust factor multiplier

// Advanced wind field (for realistic wind patterns)
wind_field:
    .space WEATHER_GRID_SIZE * WEATHER_GRID_SIZE * 8  // x,y velocity per grid cell

// Pressure systems (high/low pressure areas)
pressure_systems:
    .space PRESSURE_SYSTEM_COUNT * 32  // Each system: position, strength, radius, type

pressure_system_count:
    .long 0

// Climate configuration
climate_zone:
    .long CLIMATE_TEMPERATE

seasonal_temperature_base:
    .float 15.0, 25.0, 20.0, 5.0   // Spring, Summer, Fall, Winter base temps

seasonal_humidity_base:
    .float 0.6, 0.7, 0.5, 0.4      // Seasonal humidity modifiers

seasonal_precipitation_chance:
    .float 0.3, 0.2, 0.4, 0.3      // Seasonal precipitation probability

// Weather particle system
weather_particles:
    .space MAX_WEATHER_PARTICLES * 32  // Each particle: position, velocity, life, type

active_particle_count:
    .long 0

particle_spawn_rate:
    .float 0.0

// Weather timing
last_weather_update:
    .quad 0

weather_change_timer:
    .float 0.0

next_weather_condition:
    .long WEATHER_CLEAR

weather_transition_duration:
    .float 300.0                    // 5 minutes to transition

// Atmospheric effects
atmospheric_scattering:
    .float 1.0                      // Rayleigh scattering factor

fog_density:
    .float 0.0                      // Fog density (0.0 - 1.0)

dust_level:
    .float 0.0                      // Dust/pollution in air

// Lightning system (for thunderstorms)
lightning_active:
    .long 0

lightning_strikes:
    .space 16 * 16                  // Up to 16 lightning strikes

lightning_strike_count:
    .long 0

// System state
weather_system_initialized:
    .long 0

weather_enabled:
    .long 1

weather_simulation_speed:
    .float 1.0

.section __TEXT,__text

// Initialize weather system
// x0 = climate zone (0-4)
// Returns: x0 = 0 on success, error code on failure
_weather_system_init:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    // Check if already initialized
    adrp x19, weather_system_initialized@PAGE
    add x19, x19, weather_system_initialized@PAGEOFF
    ldr w1, [x19]
    cbnz w1, weather_init_already_done
    
    // Store climate zone
    adrp x20, climate_zone@PAGE
    add x20, x20, climate_zone@PAGEOFF
    str w0, [x20]
    
    // Initialize weather state based on climate
    bl init_climate_based_weather
    
    // Initialize pressure systems
    bl init_pressure_systems
    
    // Initialize wind field
    bl init_wind_field
    
    // Initialize particle system
    bl init_weather_particles
    
    // Set initial weather conditions
    bl set_initial_weather_conditions
    
    // Mark as initialized
    mov w0, #1
    str w0, [x19]
    
    mov x0, #0                      // Success
    b weather_init_done

weather_init_already_done:
    mov x0, #-1                     // Already initialized

weather_init_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Initialize climate-based weather parameters
init_climate_based_weather:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    adrp x0, climate_zone@PAGE
    add x0, x0, climate_zone@PAGEOFF
    ldr w0, [x0]
    
    // Set base parameters based on climate zone
    cmp w0, #CLIMATE_TEMPERATE
    b.eq setup_temperate_climate
    cmp w0, #CLIMATE_TROPICAL
    b.eq setup_tropical_climate
    cmp w0, #CLIMATE_ARID
    b.eq setup_arid_climate
    cmp w0, #CLIMATE_CONTINENTAL
    b.eq setup_continental_climate
    cmp w0, #CLIMATE_POLAR
    b.eq setup_polar_climate
    b setup_temperate_climate       // Default

setup_temperate_climate:
    adrp x0, current_temperature@PAGE
    add x0, x0, current_temperature@PAGEOFF
    fmov s0, #15.0                  // 15°C base
    str s0, [x0]
    
    adrp x0, current_humidity@PAGE
    add x0, x0, current_humidity@PAGEOFF
    fmov s0, #0.6                   // 60% humidity
    str s0, [x0]
    b climate_setup_done

setup_tropical_climate:
    adrp x0, current_temperature@PAGE
    add x0, x0, current_temperature@PAGEOFF
    fmov s0, #28.0                  // 28°C base
    str s0, [x0]
    
    adrp x0, current_humidity@PAGE
    add x0, x0, current_humidity@PAGEOFF
    fmov s0, #0.8                   // 80% humidity
    str s0, [x0]
    b climate_setup_done

setup_arid_climate:
    adrp x0, current_temperature@PAGE
    add x0, x0, current_temperature@PAGEOFF
    fmov s0, #25.0                  // 25°C base
    str s0, [x0]
    
    adrp x0, current_humidity@PAGE
    add x0, x0, current_humidity@PAGEOFF
    fmov s0, #0.2                   // 20% humidity
    str s0, [x0]
    b climate_setup_done

setup_continental_climate:
    adrp x0, current_temperature@PAGE
    add x0, x0, current_temperature@PAGEOFF
    fmov s0, #10.0                  // 10°C base
    str s0, [x0]
    
    adrp x0, current_humidity@PAGE
    add x0, x0, current_humidity@PAGEOFF
    fmov s0, #0.5                   // 50% humidity
    str s0, [x0]
    b climate_setup_done

setup_polar_climate:
    adrp x0, current_temperature@PAGE
    add x0, x0, current_temperature@PAGEOFF
    fmov s0, #-10.0                 // -10°C base
    str s0, [x0]
    
    adrp x0, current_humidity@PAGE
    add x0, x0, current_humidity@PAGEOFF
    fmov s0, #0.7                   // 70% humidity
    str s0, [x0]

climate_setup_done:
    ldp x29, x30, [sp], #16
    ret

// Initialize pressure systems
init_pressure_systems:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    // Create 2-3 initial pressure systems
    adrp x19, pressure_systems@PAGE
    add x19, x19, pressure_systems@PAGEOFF
    
    // High pressure system at center
    fmov s0, #500.0                 // X position
    fmov s1, #500.0                 // Y position
    fmov s2, #1020.0                // Pressure (hPa)
    fmov s3, #200.0                 // Radius
    mov w4, #1                      // Type: High pressure
    str s0, [x19]
    str s1, [x19, #4]
    str s2, [x19, #8]
    str s3, [x19, #12]
    str w4, [x19, #16]
    
    // Low pressure system offset
    add x19, x19, #32
    fmov s0, #800.0                 // X position
    fmov s1, #300.0                 // Y position
    fmov s2, #995.0                 // Pressure (hPa)
    fmov s3, #150.0                 // Radius
    mov w4, #0                      // Type: Low pressure
    str s0, [x19]
    str s1, [x19, #4]
    str s2, [x19, #8]
    str s3, [x19, #12]
    str w4, [x19, #16]
    
    // Set active count
    adrp x0, pressure_system_count@PAGE
    add x0, x0, pressure_system_count@PAGEOFF
    mov w1, #2
    str w1, [x0]
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Initialize wind field
init_wind_field:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    adrp x19, wind_field@PAGE
    add x19, x19, wind_field@PAGEOFF
    
    // Clear wind field
    mov x0, x19
    mov x1, #0
    mov x2, #WEATHER_GRID_SIZE * WEATHER_GRID_SIZE * 8
    bl memset
    
    // Generate initial wind pattern based on pressure systems
    bl calculate_wind_field
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Initialize weather particle system
init_weather_particles:
    adrp x0, weather_particles@PAGE
    add x0, x0, weather_particles@PAGEOFF
    
    // Clear all particles
    mov x1, #0
    mov x2, #MAX_WEATHER_PARTICLES * 32
    bl memset
    
    // Reset particle count
    adrp x0, active_particle_count@PAGE
    add x0, x0, active_particle_count@PAGEOFF
    str wzr, [x0]
    
    ret

// Set initial weather conditions based on climate and season
set_initial_weather_conditions:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Get current season from time system
    bl _time_system_get_season      // External call to time system
    mov w1, w0                      // Season
    
    // Get climate zone
    adrp x2, climate_zone@PAGE
    add x2, x2, climate_zone@PAGEOFF
    ldr w2, [x2]
    
    // Determine initial weather based on season and climate
    bl determine_seasonal_weather
    
    // Set the weather condition
    adrp x1, current_weather_condition@PAGE
    add x1, x1, current_weather_condition@PAGEOFF
    str w0, [x1]
    
    ldp x29, x30, [sp], #16
    ret

// Update weather system (called each frame)
// x0 = delta time in milliseconds
_weather_system_update:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    // Check if system is initialized and enabled
    adrp x19, weather_system_initialized@PAGE
    add x19, x19, weather_system_initialized@PAGEOFF
    ldr w1, [x19]
    cbz w1, weather_update_done
    
    adrp x19, weather_enabled@PAGE
    add x19, x19, weather_enabled@PAGEOFF
    ldr w1, [x19]
    cbz w1, weather_update_done
    
    mov x19, x0                     // Save delta time
    
    // Update weather transition timer
    bl update_weather_transition
    
    // Update pressure systems (move and evolve)
    bl update_pressure_systems
    
    // Recalculate wind field
    bl calculate_wind_field
    
    // Update atmospheric conditions
    bl update_atmospheric_conditions
    
    // Update precipitation
    bl update_precipitation
    
    // Update weather particles
    mov x0, x19                     // delta time
    bl update_weather_particles
    
    // Update lightning system
    bl update_lightning_system
    
    // Check for weather pattern changes
    bl check_weather_pattern_change

weather_update_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Update weather transition between conditions
update_weather_transition:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    adrp x0, weather_change_timer@PAGE
    add x0, x0, weather_change_timer@PAGEOFF
    ldr s0, [x0]                    // Current timer
    
    // Check if transition is active
    fcmp s0, #0.0
    b.le transition_complete
    
    // Decrease timer
    fmov s1, #0.016667              // 1/60 second (assuming 60 FPS)
    fsub s0, s0, s1
    str s0, [x0]
    
    // Calculate transition progress (0.0 to 1.0)
    adrp x1, weather_transition_duration@PAGE
    add x1, x1, weather_transition_duration@PAGEOFF
    ldr s2, [x1]                    // Total duration
    fsub s3, s2, s0                 // Elapsed time
    fdiv s3, s3, s2                 // Progress ratio
    
    // Interpolate weather parameters
    bl interpolate_weather_conditions
    
    // Check if transition is complete
    fcmp s0, #0.0
    b.gt transition_done
    
transition_complete:
    // Transition finished, set final conditions
    adrp x1, next_weather_condition@PAGE
    add x1, x1, next_weather_condition@PAGEOFF
    ldr w2, [x1]
    
    adrp x3, current_weather_condition@PAGE
    add x3, x3, current_weather_condition@PAGEOFF
    str w2, [x3]
    
    // Reset timer
    str wzr, [x0]

transition_done:
    ldp x29, x30, [sp], #16
    ret

// Update pressure systems
update_pressure_systems:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    adrp x19, pressure_system_count@PAGE
    add x19, x19, pressure_system_count@PAGEOFF
    ldr w20, [x19]                  // System count
    
    cbz w20, pressure_update_done
    
    adrp x19, pressure_systems@PAGE
    add x19, x19, pressure_systems@PAGEOFF
    mov w0, #0                      // Index

pressure_update_loop:
    cmp w0, w20
    b.ge pressure_update_done
    
    // Calculate offset for this system
    mov w1, #32
    mul w1, w0, w1
    add x1, x19, x1, lsl #0         // System address
    
    // Update pressure system position (slow drift)
    ldr s0, [x1]                    // X position
    ldr s1, [x1, #4]                // Y position
    
    // Simple drift pattern
    fmov s2, #0.1                   // Drift speed
    bl rand                         // Get random value
    and w2, w0, #0xFF
    scvtf s3, w2
    fmov s4, #128.0
    fdiv s3, s3, s4                 // -1 to 1 range
    fsub s3, s3, #1.0
    fmul s3, s3, s2
    fadd s0, s0, s3                 // Update X
    
    bl rand
    and w2, w0, #0xFF
    scvtf s3, w2
    fdiv s3, s3, s4
    fsub s3, s3, #1.0
    fmul s3, s3, s2
    fadd s1, s1, s3                 // Update Y
    
    // Keep systems within bounds (0-1000)
    fmov s2, #0.0
    fmax s0, s0, s2
    fmax s1, s1, s2
    fmov s2, #1000.0
    fmin s0, s0, s2
    fmin s1, s1, s2
    
    str s0, [x1]
    str s1, [x1, #4]
    
    add w0, w0, #1
    b pressure_update_loop

pressure_update_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Calculate wind field based on pressure systems
calculate_wind_field:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    
    adrp x19, wind_field@PAGE
    add x19, x19, wind_field@PAGEOFF
    
    // Clear wind field
    mov x0, x19
    mov x1, #0
    mov x2, #WEATHER_GRID_SIZE * WEATHER_GRID_SIZE * 8
    bl memset
    
    // Get pressure systems
    adrp x20, pressure_systems@PAGE
    add x20, x20, pressure_systems@PAGEOFF
    adrp x21, pressure_system_count@PAGE
    add x21, x21, pressure_system_count@PAGEOFF
    ldr w21, [x21]
    
    cbz w21, wind_calculation_done
    
    // For each grid cell
    mov w22, #0                     // Y index
wind_field_y_loop:
    cmp w22, #WEATHER_GRID_SIZE
    b.ge wind_calculation_done
    
    mov w23, #0                     // X index
wind_field_x_loop:
    cmp w23, #WEATHER_GRID_SIZE
    b.ge wind_field_next_y
    
    // Calculate world position for this grid cell
    scvtf s0, w23                   // Grid X
    fmov s1, #1000.0
    fmov s2, #WEATHER_GRID_SIZE
    fdiv s1, s1, s2                 // Scale factor
    fmul s0, s0, s1                 // World X
    
    scvtf s1, w22                   // Grid Y
    fmov s2, #1000.0
    fmov s3, #WEATHER_GRID_SIZE
    fdiv s2, s2, s3                 // Scale factor
    fmul s1, s1, s2                 // World Y
    
    // Calculate wind velocity at this position
    mov x0, x20                     // Pressure systems
    mov w1, w21                     // System count
    bl calculate_wind_at_position
    // Returns: s0 = wind_x, s1 = wind_y
    
    // Store in wind field
    mov w24, #WEATHER_GRID_SIZE
    mul w24, w22, w24               // Y * width
    add w24, w24, w23               // + X
    lsl w24, w24, #3                // * 8 bytes per entry
    add x24, x19, x24, lsl #0       // Final address
    
    str s0, [x24]                   // Wind X
    str s1, [x24, #4]               // Wind Y
    
    add w23, w23, #1
    b wind_field_x_loop

wind_field_next_y:
    add w22, w22, #1
    b wind_field_y_loop

wind_calculation_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// Calculate wind velocity at a specific position
// x0 = pressure systems array
// w1 = system count
// s0 = world X position
// s1 = world Y position
// Returns: s0 = wind_x, s1 = wind_y
calculate_wind_at_position:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    mov x19, x0                     // Pressure systems
    mov w20, w1                     // System count
    fmov s2, s0                     // Save X
    fmov s3, s1                     // Save Y
    
    // Initialize wind velocity
    fmov s0, #0.0                   // wind_x
    fmov s1, #0.0                   // wind_y
    
    mov w21, #0                     // System index
wind_calc_loop:
    cmp w21, w20
    b.ge wind_calc_done
    
    // Get system properties
    mov w22, #32
    mul w22, w21, w22
    add x22, x19, x22, lsl #0
    
    ldr s4, [x22]                   // System X
    ldr s5, [x22, #4]               // System Y
    ldr s6, [x22, #8]               // Pressure
    ldr s7, [x22, #12]              // Radius
    ldr w0, [x22, #16]              // Type (0=low, 1=high)
    
    // Calculate distance to pressure center
    fsub s8, s2, s4                 // dx
    fsub s9, s3, s5                 // dy
    fmul s10, s8, s8                // dx²
    fmul s11, s9, s9                // dy²
    fadd s12, s10, s11              // dx² + dy²
    fsqrt s12, s12                  // distance
    
    // Check if within influence radius
    fcmp s12, s7
    b.gt wind_calc_next_system
    
    // Calculate wind strength (inversely proportional to distance)
    fmov s13, #1.0
    fadd s14, s12, s13              // distance + 1 (avoid divide by zero)
    fdiv s13, s13, s14              // 1 / (distance + 1)
    
    // Wind direction depends on pressure type
    cbnz w0, high_pressure_wind
    
    // Low pressure: wind flows toward center (clockwise in NH)
    fneg s8, s8                     // -dx (toward center)
    fneg s9, s9                     // -dy
    
    // Add Coriolis effect (simplified)
    fmov s14, s9                    // temp = -dy
    fneg s9, s8                     // wind_y = -(-dx) = dx
    fmov s8, s14                    // wind_x = -dy
    
    b apply_wind_contribution

high_pressure_wind:
    // High pressure: wind flows away from center (anti-clockwise in NH)
    // s8, s9 already point away from center
    
    // Add Coriolis effect
    fmov s14, s9                    // temp = dy
    fmov s9, s8                     // wind_y = dx
    fneg s8, s14                    // wind_x = -dy

apply_wind_contribution:
    // Scale by strength and add to total wind
    fmul s8, s8, s13                // wind_x * strength
    fmul s9, s9, s13                // wind_y * strength
    
    fadd s0, s0, s8                 // Add to total wind_x
    fadd s1, s1, s9                 // Add to total wind_y

wind_calc_next_system:
    add w21, w21, #1
    b wind_calc_loop

wind_calc_done:
    // Scale final wind velocity
    fmov s2, #10.0                  // Wind scaling factor
    fmul s0, s0, s2
    fmul s1, s1, s2
    
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Update atmospheric conditions based on current weather
update_atmospheric_conditions:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Get current weather condition
    adrp x0, current_weather_condition@PAGE
    add x0, x0, current_weather_condition@PAGEOFF
    ldr w0, [x0]
    
    // Update visibility based on weather
    bl update_visibility_for_weather
    
    // Update atmospheric scattering
    bl update_atmospheric_scattering
    
    // Update fog density
    bl update_fog_density
    
    ldp x29, x30, [sp], #16
    ret

// Update visibility based on weather condition
// w0 = weather condition
update_visibility_for_weather:
    adrp x1, current_visibility@PAGE
    add x1, x1, current_visibility@PAGEOFF
    
    // Set visibility based on condition
    cmp w0, #WEATHER_CLEAR
    b.eq set_clear_visibility
    cmp w0, #WEATHER_LIGHT_RAIN
    b.eq set_light_rain_visibility
    cmp w0, #WEATHER_HEAVY_RAIN
    b.eq set_heavy_rain_visibility
    cmp w0, #WEATHER_THUNDERSTORM
    b.eq set_storm_visibility
    cmp w0, #WEATHER_FOG
    b.eq set_fog_visibility
    cmp w0, #WEATHER_BLIZZARD
    b.eq set_blizzard_visibility
    b set_default_visibility

set_clear_visibility:
    fmov s0, #10000.0               // 10km visibility
    b store_visibility

set_light_rain_visibility:
    fmov s0, #5000.0                // 5km visibility
    b store_visibility

set_heavy_rain_visibility:
    fmov s0, #2000.0                // 2km visibility
    b store_visibility

set_storm_visibility:
    fmov s0, #1000.0                // 1km visibility
    b store_visibility

set_fog_visibility:
    fmov s0, #200.0                 // 200m visibility
    b store_visibility

set_blizzard_visibility:
    fmov s0, #100.0                 // 100m visibility
    b store_visibility

set_default_visibility:
    fmov s0, #8000.0                // 8km default

store_visibility:
    str s0, [x1]
    ret

// Update atmospheric scattering effects
update_atmospheric_scattering:
    adrp x0, current_humidity@PAGE
    add x0, x0, current_humidity@PAGEOFF
    ldr s0, [x0]                    // Humidity
    
    adrp x1, dust_level@PAGE
    add x1, x1, dust_level@PAGEOFF
    ldr s1, [x1]                    // Dust level
    
    // Calculate scattering factor
    fmov s2, #1.0                   // Base scattering
    fmul s3, s0, #0.3               // Humidity contribution
    fmul s4, s1, #0.5               // Dust contribution
    fadd s2, s2, s3
    fadd s2, s2, s4
    
    // Clamp to reasonable range
    fmov s5, #0.5
    fmax s2, s2, s5
    fmov s5, #3.0
    fmin s2, s2, s5
    
    adrp x2, atmospheric_scattering@PAGE
    add x2, x2, atmospheric_scattering@PAGEOFF
    str s2, [x2]
    
    ret

// Update fog density
update_fog_density:
    adrp x0, current_weather_condition@PAGE
    add x0, x0, current_weather_condition@PAGEOFF
    ldr w0, [x0]
    
    adrp x1, fog_density@PAGE
    add x1, x1, fog_density@PAGEOFF
    
    cmp w0, #WEATHER_FOG
    b.eq set_heavy_fog
    
    adrp x2, current_humidity@PAGE
    add x2, x2, current_humidity@PAGEOFF
    ldr s0, [x2]
    
    // Light fog based on humidity
    fmov s1, #0.8                   // Fog threshold
    fcmp s0, s1
    b.lt no_fog
    
    fsub s2, s0, s1                 // Excess humidity
    fmov s3, #0.2
    fdiv s2, s2, s3                 // Scale to 0-1
    fmul s2, s2, #0.3               // Light fog density
    b store_fog_density

set_heavy_fog:
    fmov s2, #0.8                   // Heavy fog
    b store_fog_density

no_fog:
    fmov s2, #0.0                   // No fog

store_fog_density:
    str s2, [x1]
    ret

// Update precipitation effects
update_precipitation:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    adrp x0, current_weather_condition@PAGE
    add x0, x0, current_weather_condition@PAGEOFF
    ldr w0, [x0]
    
    // Set precipitation intensity based on weather
    adrp x1, precipitation_intensity@PAGE
    add x1, x1, precipitation_intensity@PAGEOFF
    
    cmp w0, #WEATHER_LIGHT_RAIN
    b.eq set_light_precipitation
    cmp w0, #WEATHER_HEAVY_RAIN
    b.eq set_heavy_precipitation
    cmp w0, #WEATHER_THUNDERSTORM
    b.eq set_storm_precipitation
    cmp w0, #WEATHER_LIGHT_SNOW
    b.eq set_light_snow
    cmp w0, #WEATHER_HEAVY_SNOW
    b.eq set_heavy_snow
    cmp w0, #WEATHER_BLIZZARD
    b.eq set_blizzard_precipitation
    
    // No precipitation
    fmov s0, #0.0
    b store_precipitation

set_light_precipitation:
    fmov s0, #0.3
    b store_precipitation

set_heavy_precipitation:
    fmov s0, #0.7
    b store_precipitation

set_storm_precipitation:
    fmov s0, #0.9
    b store_precipitation

set_light_snow:
    fmov s0, #0.2
    b store_precipitation

set_heavy_snow:
    fmov s0, #0.6
    b store_precipitation

set_blizzard_precipitation:
    fmov s0, #1.0

store_precipitation:
    str s0, [x1]
    
    // Update particle spawn rate
    adrp x2, particle_spawn_rate@PAGE
    add x2, x2, particle_spawn_rate@PAGEOFF
    fmul s1, s0, #50.0              // Scale to particles per second
    str s1, [x2]
    
    ldp x29, x30, [sp], #16
    ret

// Update weather particle system
// x0 = delta time in milliseconds
update_weather_particles:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    // Convert delta time to seconds
    scvtf s0, x0
    fmov s1, #1000.0
    fdiv s0, s0, s1                 // dt in seconds
    
    // Update existing particles
    bl update_existing_particles
    
    // Spawn new particles
    mov x0, sp
    str x0, [sp, #-8]!              // Store dt on stack
    bl spawn_new_particles
    ldr x0, [sp], #8
    
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Update existing weather particles
update_existing_particles:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    adrp x19, active_particle_count@PAGE
    add x19, x19, active_particle_count@PAGEOFF
    ldr w20, [x19]                  // Particle count
    
    cbz w20, particle_update_done
    
    adrp x0, weather_particles@PAGE
    add x0, x0, weather_particles@PAGEOFF
    mov w1, #0                      // Index

particle_update_loop:
    cmp w1, w20
    b.ge particle_update_done
    
    // Calculate particle address
    mov w2, #32
    mul w2, w1, w2
    add x2, x0, x2, lsl #0
    
    // Update particle position and life
    // Particle structure: x, y, z, vx, vy, vz, life, type (32 bytes)
    ldr s0, [x2]                    // x
    ldr s1, [x2, #4]                // y
    ldr s2, [x2, #8]                // z
    ldr s3, [x2, #12]               // vx
    ldr s4, [x2, #16]               // vy
    ldr s5, [x2, #20]               // vz
    ldr s6, [x2, #24]               // life
    
    // Update position
    fmov s7, #0.016667              // dt (1/60 sec)
    fmul s8, s3, s7                 // vx * dt
    fmul s9, s4, s7                 // vy * dt
    fmul s10, s5, s7                // vz * dt
    
    fadd s0, s0, s8                 // new x
    fadd s1, s1, s9                 // new y
    fadd s2, s2, s10                // new z
    
    // Update life
    fsub s6, s6, s7
    
    // Check if particle should be removed
    fcmp s6, #0.0
    b.le remove_particle
    
    // Store updated values
    str s0, [x2]
    str s1, [x2, #4]
    str s2, [x2, #8]
    str s6, [x2, #24]
    
    add w1, w1, #1
    b particle_update_loop

remove_particle:
    // Remove particle by swapping with last particle
    sub w3, w20, #1                 // Last index
    cmp w1, w3
    b.eq particle_removed           // Already last particle
    
    // Swap particle data
    mov w4, #32
    mul w4, w3, w4
    add x4, x0, x4, lsl #0          // Last particle address
    
    // Copy last particle to current position
    ldp x5, x6, [x4]
    stp x5, x6, [x2]
    ldp x5, x6, [x4, #16]
    stp x5, x6, [x2, #16]

particle_removed:
    sub w20, w20, #1                // Decrease count
    // Don't increment w1, check same index again
    b particle_update_loop

particle_update_done:
    str w20, [x19]                  // Update count
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Spawn new weather particles
spawn_new_particles:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    // Get spawn rate
    adrp x19, particle_spawn_rate@PAGE
    add x19, x19, particle_spawn_rate@PAGEOFF
    ldr s0, [x19]                   // Particles per second
    
    fcmp s0, #0.0
    b.le spawn_particles_done
    
    // Calculate particles to spawn this frame
    fmov s1, #0.016667              // dt (1/60 sec)
    fmul s0, s0, s1                 // Particles this frame
    fcvtzs w0, s0                   // Convert to integer
    
    cbz w0, spawn_particles_done
    
    // Get current particle count
    adrp x20, active_particle_count@PAGE
    add x20, x20, active_particle_count@PAGEOFF
    ldr w1, [x20]
    
    // Don't exceed maximum
    add w2, w1, w0                  // New total
    cmp w2, #MAX_WEATHER_PARTICLES
    mov w3, #MAX_WEATHER_PARTICLES
    csel w0, w0, w3, le             // Limit spawn count
    sub w0, w3, w1                  // Available slots
    
    cbz w0, spawn_particles_done
    
    // Spawn particles
    adrp x2, weather_particles@PAGE
    add x2, x2, weather_particles@PAGEOFF
    mov w3, #0                      // Spawn counter

spawn_particle_loop:
    cmp w3, w0
    b.ge spawn_particles_complete
    
    // Calculate particle address
    add w4, w1, w3                  // Particle index
    mov w5, #32
    mul w5, w4, w5
    add x5, x2, x5, lsl #0          // Particle address
    
    // Generate random particle properties
    bl create_weather_particle
    
    add w3, w3, #1
    b spawn_particle_loop

spawn_particles_complete:
    add w1, w1, w0                  // Update count
    str w1, [x20]

spawn_particles_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Create a new weather particle at address x5
create_weather_particle:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Generate random position above the view area
    bl rand
    and w0, w0, #0x3FF              // 0-1023
    scvtf s0, w0                    // X position
    
    bl rand
    and w0, w0, #0x3FF              // 0-1023
    scvtf s1, w0                    // Y position
    
    fmov s2, #1000.0                // Z position (above)
    
    // Get wind velocity at this position
    adrp x0, wind_speed@PAGE
    add x0, x0, wind_speed@PAGEOFF
    ldr s3, [x0]                    // Wind speed
    
    adrp x0, wind_direction@PAGE
    add x0, x0, wind_direction@PAGEOFF
    ldr s4, [x0]                    // Wind direction
    
    // Calculate wind velocity components
    bl cosf                         // cos(wind_direction)
    fmul s5, s0, s3                 // vx = wind_speed * cos(dir)
    
    fmov s0, s4
    bl sinf                         // sin(wind_direction)
    fmul s6, s0, s3                 // vy = wind_speed * sin(dir)
    
    // Vertical velocity (falling)
    fmov s7, #-10.0                 // Base fall speed
    
    // Get current weather for particle type
    adrp x0, current_weather_condition@PAGE
    add x0, x0, current_weather_condition@PAGEOFF
    ldr w0, [x0]
    
    // Adjust fall speed based on weather type
    cmp w0, #WEATHER_LIGHT_SNOW
    b.eq slow_fall_speed
    cmp w0, #WEATHER_HEAVY_SNOW
    b.eq medium_fall_speed
    b normal_fall_speed

slow_fall_speed:
    fmov s7, #-3.0
    b store_particle_data

medium_fall_speed:
    fmov s7, #-5.0
    b store_particle_data

normal_fall_speed:
    // s7 already set to -10.0

store_particle_data:
    // Store particle data
    str s0, [x5]                    // x position
    str s1, [x5, #4]                // y position
    str s2, [x5, #8]                // z position
    str s5, [x5, #12]               // vx
    str s6, [x5, #16]               // vy
    str s7, [x5, #20]               // vz
    
    // Life time (5-10 seconds)
    bl rand
    and w1, w0, #0x1F               // 0-31
    add w1, w1, #150                // 150-181 frames (~5-6 seconds at 30fps)
    scvtf s8, w1
    fmov s9, #30.0
    fdiv s8, s8, s9                 // Convert to seconds
    str s8, [x5, #24]               // life
    
    // Particle type (based on weather)
    str w0, [x5, #28]               // weather condition as type
    
    ldp x29, x30, [sp], #16
    ret

// Update lightning system for thunderstorms
update_lightning_system:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Check if we're in a thunderstorm
    adrp x0, current_weather_condition@PAGE
    add x0, x0, current_weather_condition@PAGEOFF
    ldr w0, [x0]
    
    cmp w0, #WEATHER_THUNDERSTORM
    b.ne lightning_inactive
    
    // Random chance of lightning strike
    bl rand
    and w0, w0, #0x3FF              // 0-1023
    cmp w0, #10                     // ~1% chance per frame
    b.gt lightning_update_done
    
    // Create lightning strike
    bl create_lightning_strike
    b lightning_update_done

lightning_inactive:
    // Clear lightning if not thunderstorm
    adrp x0, lightning_active@PAGE
    add x0, x0, lightning_active@PAGEOFF
    str wzr, [x0]

lightning_update_done:
    ldp x29, x30, [sp], #16
    ret

// Create a lightning strike
create_lightning_strike:
    // Set lightning as active
    adrp x0, lightning_active@PAGE
    add x0, x0, lightning_active@PAGEOFF
    mov w1, #1
    str w1, [x0]
    
    // Generate random strike position
    bl rand
    and w0, w0, #0x3FF              // 0-1023
    scvtf s0, w0                    // X position
    
    bl rand
    and w0, w0, #0x3FF              // 0-1023
    scvtf s1, w0                    // Y position
    
    // Store lightning strike data (for audio and visual systems)
    adrp x2, lightning_strikes@PAGE
    add x2, x2, lightning_strikes@PAGEOFF
    
    adrp x3, lightning_strike_count@PAGE
    add x3, x3, lightning_strike_count@PAGEOFF
    ldr w4, [x3]
    
    // Store strike if we have room
    cmp w4, #16
    b.ge lightning_buffer_full
    
    mov w5, #8                      // 8 bytes per strike (x, y)
    mul w5, w4, w5
    add x5, x2, x5, lsl #0
    
    str s0, [x5]                    // X position
    str s1, [x5, #4]                // Y position
    
    add w4, w4, #1
    str w4, [x3]

lightning_buffer_full:
    ret

// Check for weather pattern changes
check_weather_pattern_change:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Check if we're already transitioning
    adrp x0, weather_change_timer@PAGE
    add x0, x0, weather_change_timer@PAGEOFF
    ldr s0, [x0]
    
    fcmp s0, #0.0
    b.gt weather_change_in_progress
    
    // Random chance of weather change
    bl rand
    and w0, w0, #0x7FF              // 0-2047
    cmp w0, #5                      // Very low chance per frame
    b.gt weather_change_done
    
    // Initiate weather change
    bl select_next_weather_condition
    
    adrp x1, weather_transition_duration@PAGE
    add x1, x1, weather_transition_duration@PAGEOFF
    ldr s1, [x1]
    str s1, [x0]                    // Set transition timer

weather_change_in_progress:
weather_change_done:
    ldp x29, x30, [sp], #16
    ret

// Select next weather condition based on current conditions and climate
select_next_weather_condition:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Get current weather and climate
    adrp x0, current_weather_condition@PAGE
    add x0, x0, current_weather_condition@PAGEOFF
    ldr w0, [x0]                    // Current weather
    
    adrp x1, climate_zone@PAGE
    add x1, x1, climate_zone@PAGEOFF
    ldr w1, [x1]                    // Climate zone
    
    // Simple state machine for weather transitions
    bl rand
    and w2, w0, #7                  // 0-7 random
    
    // Basic weather progression logic
    cmp w0, #WEATHER_CLEAR
    b.eq from_clear_weather
    cmp w0, #WEATHER_PARTLY_CLOUDY
    b.eq from_partly_cloudy
    cmp w0, #WEATHER_OVERCAST
    b.eq from_overcast
    b default_weather_transition

from_clear_weather:
    cmp w2, #6
    mov w3, #WEATHER_PARTLY_CLOUDY
    csel w3, w3, w0, lt             // 75% chance to partly cloudy, 25% stay clear
    b store_next_weather

from_partly_cloudy:
    cmp w2, #3
    mov w3, #WEATHER_CLEAR
    mov w4, #WEATHER_OVERCAST
    csel w3, w3, w4, lt             // 50% clear, 50% overcast
    b store_next_weather

from_overcast:
    cmp w2, #4
    mov w3, #WEATHER_LIGHT_RAIN
    mov w4, #WEATHER_PARTLY_CLOUDY
    csel w3, w3, w4, lt             // 50% rain, 50% partly cloudy
    b store_next_weather

default_weather_transition:
    mov w3, #WEATHER_CLEAR          // Default to clear

store_next_weather:
    adrp x2, next_weather_condition@PAGE
    add x2, x2, next_weather_condition@PAGEOFF
    str w3, [x2]
    
    ldp x29, x30, [sp], #16
    ret

// Public interface functions

// Get current weather conditions
// Returns weather data in a structure pointed to by x0
_weather_get_current_conditions:
    // x0 = pointer to weather data structure
    cbz x0, get_conditions_error
    
    // Copy current weather data
    adrp x1, current_weather_condition@PAGE
    add x1, x1, current_weather_condition@PAGEOFF
    ldr w2, [x1]
    str w2, [x0]                    // Weather condition
    
    adrp x1, current_temperature@PAGE
    add x1, x1, current_temperature@PAGEOFF
    ldr s0, [x1]
    str s0, [x0, #4]                // Temperature
    
    adrp x1, current_humidity@PAGE
    add x1, x1, current_humidity@PAGEOFF
    ldr s0, [x1]
    str s0, [x0, #8]                // Humidity
    
    adrp x1, wind_speed@PAGE
    add x1, x1, wind_speed@PAGEOFF
    ldr s0, [x1]
    str s0, [x0, #12]               // Wind speed
    
    adrp x1, wind_direction@PAGE
    add x1, x1, wind_direction@PAGEOFF
    ldr s0, [x1]
    str s0, [x0, #16]               // Wind direction
    
    adrp x1, precipitation_intensity@PAGE
    add x1, x1, precipitation_intensity@PAGEOFF
    ldr s0, [x1]
    str s0, [x0, #20]               // Precipitation
    
    adrp x1, current_visibility@PAGE
    add x1, x1, current_visibility@PAGEOFF
    ldr s0, [x1]
    str s0, [x0, #24]               // Visibility
    
    mov x0, #0                      // Success
    ret

get_conditions_error:
    mov x0, #-1                     // Error
    ret

// Set climate zone
// x0 = climate zone (0-4)
_weather_set_climate_zone:
    cmp x0, #CLIMATE_POLAR
    b.gt invalid_climate_zone
    
    adrp x1, climate_zone@PAGE
    add x1, x1, climate_zone@PAGEOFF
    str w0, [x1]
    
    mov x0, #0                      // Success
    ret

invalid_climate_zone:
    mov x0, #-1                     // Error
    ret

// Force specific weather condition
// x0 = weather condition
_weather_force_condition:
    cmp x0, #WEATHER_TORNADO
    b.gt invalid_weather_condition
    
    adrp x1, current_weather_condition@PAGE
    add x1, x1, current_weather_condition@PAGEOFF
    str w0, [x1]
    
    // Reset transition timer to apply immediately
    adrp x1, weather_change_timer@PAGE
    add x1, x1, weather_change_timer@PAGEOFF
    str wzr, [x1]
    
    mov x0, #0                      // Success
    ret

invalid_weather_condition:
    mov x0, #-1                     // Error
    ret

// Get precipitation intensity
// Returns: s0 = precipitation intensity (0.0 - 1.0)
_weather_get_precipitation_intensity:
    adrp x0, precipitation_intensity@PAGE
    add x0, x0, precipitation_intensity@PAGEOFF
    ldr s0, [x0]
    ret

// Get wind vector
// x0 = pointer to wind vector (x, y components)
_weather_get_wind_vector:
    cbz x0, get_wind_error
    
    adrp x1, wind_speed@PAGE
    add x1, x1, wind_speed@PAGEOFF
    ldr s0, [x1]                    // Wind speed
    
    adrp x1, wind_direction@PAGE
    add x1, x1, wind_direction@PAGEOFF
    ldr s1, [x1]                    // Wind direction (radians)
    
    // Calculate components
    fmov s2, s1
    bl cosf
    fmul s0, s0, s0                 // wind_x = speed * cos(direction)
    str s0, [x0]
    
    fmov s0, s2
    bl sinf
    fmul s0, s1, s0                 // wind_y = speed * sin(direction)
    str s0, [x0, #4]
    
    mov x0, #0                      // Success
    ret

get_wind_error:
    mov x0, #-1                     // Error
    ret

// Get current temperature
// Returns: s0 = temperature in Celsius
_weather_get_temperature:
    adrp x0, current_temperature@PAGE
    add x0, x0, current_temperature@PAGEOFF
    ldr s0, [x0]
    ret

// Get current visibility
// Returns: s0 = visibility in meters
_weather_get_visibility:
    adrp x0, current_visibility@PAGE
    add x0, x0, current_visibility@PAGEOFF
    ldr s0, [x0]
    ret

// Shutdown weather system
_weather_system_shutdown:
    adrp x0, weather_system_initialized@PAGE
    add x0, x0, weather_system_initialized@PAGEOFF
    str wzr, [x0]
    
    // Clear all particles
    adrp x0, active_particle_count@PAGE
    add x0, x0, active_particle_count@PAGEOFF
    str wzr, [x0]
    
    // Clear lightning
    adrp x0, lightning_active@PAGE
    add x0, x0, lightning_active@PAGEOFF
    str wzr, [x0]
    
    ret

// Helper function stubs (would normally call system functions)
determine_seasonal_weather:
    // Simple seasonal weather determination
    // w1 = season, w2 = climate
    
    cmp w1, #0                      // Winter
    b.eq winter_weather
    cmp w1, #1                      // Spring
    b.eq spring_weather
    cmp w1, #2                      // Summer
    b.eq summer_weather
    // Fall
    mov w0, #WEATHER_PARTLY_CLOUDY
    ret

winter_weather:
    cmp w2, #CLIMATE_POLAR
    mov w0, #WEATHER_HEAVY_SNOW
    mov w3, #WEATHER_OVERCAST
    csel w0, w0, w3, eq
    ret

spring_weather:
    mov w0, #WEATHER_LIGHT_RAIN
    ret

summer_weather:
    mov w0, #WEATHER_CLEAR
    ret

interpolate_weather_conditions:
    // Placeholder for weather interpolation during transitions
    ret

// External function declarations
.extern memset
.extern rand
.extern cosf
.extern sinf
.extern sqrtf
.extern _time_system_get_season