//
// SimCity ARM64 Assembly - Time System
// Agent 1: Simulation Engine
//
// Core time management system with calendar, seasons, and time scaling
// Integrates with the main simulation loop to provide temporal context
//

.include "simulation_constants.s"

.text
.align 4

// Time system structures
.struct GameTime
    // Real time tracking
    real_time_ns        .quad       // Real nanoseconds since start
    simulation_time_ns  .quad       // Simulation nanoseconds since start
    last_update_ns      .quad       // Last real time update
    
    // Game time scale
    time_scale          .float      // Current time multiplier (1.0 = normal)
    target_time_scale   .float      // Target time multiplier for smooth transitions
    paused              .word       // 1 if paused, 0 if running
    pause_toggle        .word       // Toggle flag for pause state changes
    
    // Game calendar
    year                .word       // Current game year (starts at 1)
    month               .word       // Current month (1-12)
    day                 .word       // Current day of month (1-31)
    hour                .word       // Current hour (0-23)
    minute              .word       // Current minute (0-59)
    second              .word       // Current second (0-59)
    
    // Derived time information
    day_of_year         .word       // Day of year (1-365/366)
    day_of_week         .word       // Day of week (0-6, 0=Sunday)
    season              .word       // Current season (0-3)
    is_leap_year        .word       // 1 if current year is leap year
    
    // Time progression rates (configurable)
    ns_per_game_second  .quad       // Real nanoseconds per game second
    seconds_per_game_day .word      // Game seconds per game day (default 86400)
    days_per_game_month .word       // Days per game month (varies)
    months_per_game_year .word      // Months per game year (12)
    
    // Statistics
    total_game_days     .quad       // Total game days elapsed
    total_real_hours    .double     // Total real hours played
    
    _padding            .space 16   // Ensure cache line alignment
.endstruct

// Calendar data structure
.struct Calendar
    // Month definitions (days per month)
    days_in_month       .space 48   // 12 months * 4 bytes each
    month_names         .space 384  // 12 months * 32 bytes each
    season_months       .space 48   // Season for each month (12 * 4 bytes)
    
    // Season definitions
    season_names        .space 128  // 4 seasons * 32 bytes each
    
    // Day names
    day_names           .space 224  // 7 days * 32 bytes each
.endstruct

// Time control interface
.struct TimeControls
    available_speeds    .space 32   // Up to 8 different speed multipliers
    speed_count         .word       // Number of available speeds
    current_speed_index .word       // Current speed index
    
    // Speed transition
    transition_active   .word       // 1 if transitioning between speeds
    transition_duration .float      // Duration of speed transition in seconds
    transition_timer    .float      // Current transition timer
    
    _padding            .word
.endstruct

// Global time system state
.section .bss
    .align 8
    game_time:      .space GameTime_size
    calendar:       .space Calendar_size
    time_controls:  .space TimeControls_size

// Calendar data in read-only section
.section .rodata
    .align 4

days_per_month_data:
    .word 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31  // Non-leap year

month_names_data:
    .ascii "January\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "February\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "March\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "April\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "May\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "June\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "July\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "August\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "September\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "October\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "November\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "December\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"

season_mapping_data:
    .word 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 0  // Winter, Spring, Summer, Fall

season_names_data:
    .ascii "Winter\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "Spring\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "Summer\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "Fall\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"

day_names_data:
    .ascii "Sunday\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "Monday\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "Tuesday\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "Wednesday\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "Thursday\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "Friday\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
    .ascii "Saturday\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"

// Available time speed multipliers
speed_multipliers_data:
    .float 0.0, 1.0, 2.0, 3.0, 10.0, 50.0, 100.0, 1000.0  // Pause, Normal, 2x, 3x, 10x, 50x, 100x, Ultra

.section .text

//
// time_system_init - Initialize the time management system
//
// Parameters:
//   x0 = starting year (default 2000)
//   x1 = starting month (1-12, default 1)
//   x2 = starting day (1-31, default 1)
//   x3 = time scale (default 60.0 = 1 minute real = 1 hour game)
//
// Returns:
//   x0 = 0 on success, error code on failure
//
.global time_system_init
time_system_init:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    // Store parameters with defaults
    mov     x19, x0                 // year (default 2000)
    cbnz    x19, 1f
    mov     x19, #2000
1:  mov     x20, x1                 // month (default 1)
    cbnz    x20, 2f
    mov     x20, #1
2:  mov     x21, x2                 // day (default 1)
    cbnz    x21, 3f
    mov     x21, #1
3:  
    // Initialize time scale (default 60 seconds real = 1 game hour)
    fcmp    s0, #0.0
    b.ne    4f
    fmov    s0, #60.0               // Default time scale
4:
    
    // Get time system structures
    adrp    x9, game_time
    add     x9, x9, :lo12:game_time
    adrp    x10, calendar
    add     x10, x10, :lo12:calendar
    adrp    x11, time_controls
    add     x11, x11, :lo12:time_controls
    
    // Clear all structures
    mov     x12, #0
    mov     x13, #(GameTime_size / 8)
5:  str     x12, [x9], #8
    subs    x13, x13, #1
    b.ne    5b
    
    mov     x13, #(Calendar_size / 8)
6:  str     x12, [x10], #8
    subs    x13, x13, #1
    b.ne    6b
    
    mov     x13, #(TimeControls_size / 8)
7:  str     x12, [x11], #8
    subs    x13, x13, #1
    b.ne    7b
    
    // Reset pointers
    adrp    x9, game_time
    add     x9, x9, :lo12:game_time
    adrp    x10, calendar
    add     x10, x10, :lo12:calendar
    adrp    x11, time_controls
    add     x11, x11, :lo12:time_controls
    
    // Initialize GameTime structure
    bl      get_current_time_ns
    str     x0, [x9, #GameTime.real_time_ns]
    str     x0, [x9, #GameTime.last_update_ns]
    str     xzr, [x9, #GameTime.simulation_time_ns]
    
    // Set initial calendar
    str     w19, [x9, #GameTime.year]
    str     w20, [x9, #GameTime.month]
    str     w21, [x9, #GameTime.day]
    str     wzr, [x9, #GameTime.hour]
    str     wzr, [x9, #GameTime.minute]
    str     wzr, [x9, #GameTime.second]
    
    // Set time scaling (1 real minute = 1 game hour by default)
    fmov    s1, #1.0
    str     s1, [x9, #GameTime.time_scale]
    str     s1, [x9, #GameTime.target_time_scale]
    
    // Calculate nanoseconds per game second (60 real seconds = 3600 game seconds)
    mov     x22, #NANOSECONDS_PER_SECOND
    mov     x0, #60                 // 60 real seconds
    udiv    x22, x22, x0            // ns per real second / 60
    mov     x0, #3600               // 3600 game seconds in game hour
    udiv    x22, x22, x0            // Adjust for game time
    str     x22, [x9, #GameTime.ns_per_game_second]
    
    // Set time constants
    mov     w0, #86400
    str     w0, [x9, #GameTime.seconds_per_game_day]
    mov     w0, #12
    str     w0, [x9, #GameTime.months_per_game_year]
    
    // Initialize calendar data
    bl      initialize_calendar_data
    
    // Initialize time controls
    bl      initialize_time_controls
    
    // Calculate initial derived values
    bl      update_derived_time_values
    
    mov     x0, #0                  // Success
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// time_system_update - Update the time system
//
// Called from the main simulation loop to advance game time
//
// Returns:
//   x0 = 1 if day changed, 0 otherwise
//
.global time_system_update
time_system_update:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    adrp    x19, game_time
    add     x19, x19, :lo12:game_time
    
    // Check if paused
    ldr     w20, [x19, #GameTime.paused]
    cbnz    w20, time_update_paused
    
    // Get current real time
    bl      get_current_time_ns
    mov     x20, x0                 // current_real_time
    
    // Calculate real time delta
    ldr     x1, [x19, #GameTime.last_update_ns]
    sub     x2, x20, x1             // real_delta_ns
    str     x20, [x19, #GameTime.last_update_ns]
    
    // Apply time scaling and add to simulation time
    ldr     s0, [x19, #GameTime.time_scale]
    scvtf   s1, x2                  // real_delta_ns to float
    fmul    s1, s1, s0              // Apply time scale
    fcvtzs  x2, s1                  // Back to integer
    
    ldr     x3, [x19, #GameTime.simulation_time_ns]
    add     x3, x3, x2
    str     x3, [x19, #GameTime.simulation_time_ns]
    
    // Update total real time
    ldr     d0, [x19, #GameTime.total_real_hours]
    scvtf   d1, x2                  // real_delta_ns to double
    mov     x4, #3600000000000      // nanoseconds per hour
    scvtf   d2, x4
    fdiv    d1, d1, d2              // Convert to hours
    fadd    d0, d0, d1
    str     d0, [x19, #GameTime.total_real_hours]
    
    // Convert simulation time to game time units
    bl      convert_simulation_time_to_calendar
    
    // Smooth time scale transitions
    bl      update_time_scale_transition
    
    // Check if day changed for return value
    mov     x0, #0                  // Default: no day change
    // TODO: Implement day change detection
    
    b       time_update_done
    
time_update_paused:
    // Update last_update_ns even when paused to prevent large jumps
    bl      get_current_time_ns
    str     x0, [x19, #GameTime.last_update_ns]
    mov     x0, #0                  // No day change when paused
    
time_update_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// convert_simulation_time_to_calendar - Convert nanoseconds to calendar time
//
convert_simulation_time_to_calendar:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    adrp    x19, game_time
    add     x19, x19, :lo12:game_time
    
    // Get simulation time in nanoseconds
    ldr     x0, [x19, #GameTime.simulation_time_ns]
    
    // Get nanoseconds per game second
    ldr     x1, [x19, #GameTime.ns_per_game_second]
    cbz     x1, calendar_convert_done
    
    // Convert to game seconds
    udiv    x2, x0, x1              // total_game_seconds
    
    // Calculate seconds within current minute
    mov     x3, #60
    udiv    x4, x2, x3              // total_minutes
    msub    x5, x4, x3, x2          // seconds = total_seconds - (minutes * 60)
    str     w5, [x19, #GameTime.second]
    
    // Calculate minutes within current hour
    udiv    x6, x4, x3              // total_hours
    msub    x7, x6, x3, x4          // minutes = total_minutes - (hours * 60)
    str     w7, [x19, #GameTime.minute]
    
    // Calculate hours within current day
    mov     x3, #24
    udiv    x8, x6, x3              // total_days
    msub    x9, x8, x3, x6          // hours = total_hours - (days * 24)
    str     w9, [x19, #GameTime.hour]
    
    // Store total game days for reference
    str     x8, [x19, #GameTime.total_game_days]
    
    // Calculate calendar date from total days
    mov     x0, x8                  // total_days
    bl      convert_days_to_calendar_date
    
calendar_convert_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// convert_days_to_calendar_date - Convert total days to year/month/day
//
// Parameters:
//   x0 = total days since start
//
convert_days_to_calendar_date:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    adrp    x19, game_time
    add     x19, x19, :lo12:game_time
    
    mov     x20, x0                 // remaining_days
    
    // Get starting year, month, day
    ldr     w21, [x19, #GameTime.year]      // current_year (starting year)
    ldr     w22, [x19, #GameTime.month]     // current_month (starting month)
    ldr     w0, [x19, #GameTime.day]        // current_day (starting day)
    
    // Add the starting day offset to total days
    add     x20, x20, x0
    sub     x20, x20, #1            // Adjust for 0-based calculation
    
    // Year calculation loop
year_loop:
    cbz     x20, date_calculation_done
    
    // Check if current year is leap year
    mov     w0, w21
    bl      is_leap_year
    mov     w1, w0                  // leap_year_flag
    
    // Days in current year
    mov     w2, #365
    cbnz    w1, 1f
    mov     w2, #366
1:  
    // Check if we have enough days to complete this year
    cmp     x20, x2
    b.lt    month_calculation
    
    // Subtract year and advance
    sub     x20, x20, x2
    add     w21, w21, #1
    b       year_loop
    
month_calculation:
    // Now we have the correct year and remaining days in x20
    mov     w22, #1                 // Start from January
    
month_loop:
    cmp     w22, #12
    b.gt    day_calculation
    
    // Get days in current month
    mov     w0, w22                 // month
    mov     w1, w21                 // year
    bl      get_days_in_month
    mov     w2, w0                  // days_in_month
    
    // Check if we have enough days to complete this month
    cmp     x20, x2
    b.lt    day_calculation
    
    // Subtract month and advance
    sub     x20, x20, x2
    add     w22, w22, #1
    b       month_loop
    
day_calculation:
    // Remaining days + 1 is the day of month
    add     w0, w20, #1
    
    // Store final date
    str     w21, [x19, #GameTime.year]
    str     w22, [x19, #GameTime.month]
    str     w0, [x19, #GameTime.day]
    
    // Update derived values
    bl      update_derived_time_values
    
date_calculation_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// update_derived_time_values - Calculate derived time information
//
update_derived_time_values:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    adrp    x19, game_time
    add     x19, x19, :lo12:game_time
    
    // Get current date
    ldr     w0, [x19, #GameTime.year]
    ldr     w1, [x19, #GameTime.month]
    ldr     w2, [x19, #GameTime.day]
    
    // Calculate day of year
    bl      calculate_day_of_year
    str     w0, [x19, #GameTime.day_of_year]
    
    // Calculate day of week (using a simple algorithm)
    ldr     w0, [x19, #GameTime.year]
    ldr     w1, [x19, #GameTime.month]
    ldr     w2, [x19, #GameTime.day]
    bl      calculate_day_of_week
    str     w0, [x19, #GameTime.day_of_week]
    
    // Calculate season
    ldr     w0, [x19, #GameTime.month]
    bl      get_season_for_month
    str     w0, [x19, #GameTime.season]
    
    // Check if leap year
    ldr     w0, [x19, #GameTime.year]
    bl      is_leap_year
    str     w0, [x19, #GameTime.is_leap_year]
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// Helper functions for calendar calculations
//

// is_leap_year - Check if year is a leap year
// Parameters: w0 = year
// Returns: w0 = 1 if leap year, 0 otherwise
is_leap_year:
    // Leap year rules: divisible by 4, except century years must be divisible by 400
    mov     w2, w0                  // Save year
    
    // Check divisible by 4
    and     w1, w0, #3
    cbnz    w1, not_leap_year
    
    // Check if century year (divisible by 100)
    mov     w1, #100
    udiv    w3, w2, w1
    msub    w4, w3, w1, w2
    cbnz    w4, is_leap_year_true   // Not century year, so leap year
    
    // Century year, check divisible by 400
    mov     w1, #400
    udiv    w3, w2, w1
    msub    w4, w3, w1, w2
    cbz     w4, is_leap_year_true
    
not_leap_year:
    mov     w0, #0
    ret
    
is_leap_year_true:
    mov     w0, #1
    ret

// get_days_in_month - Get number of days in a month
// Parameters: w0 = month (1-12), w1 = year
// Returns: w0 = days in month
get_days_in_month:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // February special case
    cmp     w0, #2
    b.ne    regular_month
    
    // Check if leap year
    mov     w2, w0                  // Save month
    mov     w0, w1                  // Year parameter
    bl      is_leap_year
    mov     w1, w0                  // Leap year result
    mov     w0, w2                  // Restore month
    
    mov     w2, #28
    cbz     w1, february_done
    mov     w2, #29
february_done:
    mov     w0, w2
    b       get_days_done
    
regular_month:
    // Use lookup table
    adrp    x2, days_per_month_data
    add     x2, x2, :lo12:days_per_month_data
    sub     w0, w0, #1              // Convert to 0-based index
    ldr     w0, [x2, w0, lsl #2]
    
get_days_done:
    ldp     x29, x30, [sp], #16
    ret

// calculate_day_of_year - Calculate day of year
// Parameters: w0 = year, w1 = month, w2 = day
// Returns: w0 = day of year (1-366)
calculate_day_of_year:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     w19, w2                 // Save day
    mov     w20, w0                 // Save year
    
    mov     w0, #0                  // Running total
    mov     w2, #1                  // Month counter
    
day_of_year_loop:
    cmp     w2, w1
    b.ge    day_of_year_add_days
    
    // Add days from this month
    mov     w3, w0                  // Save running total
    mov     w0, w2                  // month
    mov     w1, w20                 // year
    bl      get_days_in_month
    add     w0, w3, w0              // Add to running total
    
    add     w2, w2, #1              // Next month
    mov     w1, w19                 // Restore target month (in loop variable reuse)
    b       day_of_year_loop
    
day_of_year_add_days:
    add     w0, w0, w19             // Add the day of month
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// calculate_day_of_week - Calculate day of week using Doomsday algorithm
// Parameters: w0 = year, w1 = month, w2 = day
// Returns: w0 = day of week (0=Sunday, 1=Monday, etc.)
calculate_day_of_week:
    // Simplified algorithm - use January 1, 2000 as Saturday (day 6)
    // This is not astronomically accurate but good enough for simulation
    
    // Calculate days since January 1, 2000
    sub     w0, w0, #2000           // Years since 2000
    
    // Approximate: 365.25 days per year
    mov     w3, #365
    mul     w4, w0, w3              // Years * 365
    
    // Add leap days (rough approximation)
    add     w3, w0, #3
    lsr     w3, w3, #2              // Divide by 4
    add     w4, w4, w3              // Add leap days
    
    // Add days from months in current year
    sub     w1, w1, #1              // Convert to 0-based month
    mov     w5, #0                  // Running month total
    
month_day_loop:
    cbz     w1, month_day_done
    
    // Approximate days per month (30.4 average)
    mov     w6, #30
    add     w5, w5, w6
    
    sub     w1, w1, #1
    b       month_day_loop
    
month_day_done:
    add     w4, w4, w5              // Add month days
    add     w4, w4, w2              // Add day of month
    
    // January 1, 2000 was a Saturday (6), so adjust
    add     w4, w4, #6
    
    // Modulo 7 to get day of week
    mov     w0, #7
    udiv    w5, w4, w0
    msub    w0, w5, w0, w4
    
    ret

// get_season_for_month - Get season for a given month
// Parameters: w0 = month (1-12)
// Returns: w0 = season (0=Winter, 1=Spring, 2=Summer, 3=Fall)
get_season_for_month:
    adrp    x1, season_mapping_data
    add     x1, x1, :lo12:season_mapping_data
    sub     w0, w0, #1              // Convert to 0-based
    ldr     w0, [x1, w0, lsl #2]
    ret

//
// Time control functions
//

// time_system_pause - Pause or unpause the simulation
// Parameters: w0 = 1 to pause, 0 to unpause
.global time_system_pause
time_system_pause:
    adrp    x1, game_time
    add     x1, x1, :lo12:game_time
    
    str     w0, [x1, #GameTime.paused]
    
    // Reset time scale if unpausing
    cbz     w0, unpause_reset_time
    ret
    
unpause_reset_time:
    // Update last_update_ns to prevent time jump
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    bl      get_current_time_ns
    str     x0, [x1, #GameTime.last_update_ns]
    
    ldp     x29, x30, [sp], #16
    ret

// time_system_set_speed - Set time speed multiplier
// Parameters: x0 = speed index (0-7)
.global time_system_set_speed
time_system_set_speed:
    adrp    x1, time_controls
    add     x1, x1, :lo12:time_controls
    
    // Validate speed index
    ldr     w2, [x1, #TimeControls.speed_count]
    cmp     w0, w2
    b.ge    invalid_speed_index
    
    // Store new speed index
    str     w0, [x1, #TimeControls.current_speed_index]
    
    // Get new speed multiplier
    adrp    x2, speed_multipliers_data
    add     x2, x2, :lo12:speed_multipliers_data
    ldr     s0, [x2, w0, lsl #2]
    
    // Set target time scale for smooth transition
    adrp    x3, game_time
    add     x3, x3, :lo12:game_time
    str     s0, [x3, #GameTime.target_time_scale]
    
    // Check for pause (speed 0)
    fcmp    s0, #0.0
    b.ne    not_pause_speed
    
    mov     w4, #1
    str     w4, [x3, #GameTime.paused]
    b       set_speed_done
    
not_pause_speed:
    str     wzr, [x3, #GameTime.paused]
    
set_speed_done:
    ret
    
invalid_speed_index:
    // Invalid index, do nothing
    ret

// time_system_get_speed - Get current time speed index
// Returns: w0 = current speed index
.global time_system_get_speed
time_system_get_speed:
    adrp    x0, time_controls
    add     x0, x0, :lo12:time_controls
    ldr     w0, [x0, #TimeControls.current_speed_index]
    ret

// time_system_cycle_speed - Cycle to next speed setting
.global time_system_cycle_speed
time_system_cycle_speed:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    bl      time_system_get_speed
    mov     w1, w0                  // Current speed
    
    adrp    x2, time_controls
    add     x2, x2, :lo12:time_controls
    ldr     w2, [x2, #TimeControls.speed_count]
    
    add     w1, w1, #1              // Next speed
    cmp     w1, w2
    csel    w1, w1, wzr, lo         // Wrap to 0 if >= count
    
    mov     x0, x1
    bl      time_system_set_speed
    
    ldp     x29, x30, [sp], #16
    ret

//
// Initialization helper functions
//

initialize_calendar_data:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, calendar
    add     x0, x0, :lo12:calendar
    
    // Copy days per month
    adrp    x1, days_per_month_data
    add     x1, x1, :lo12:days_per_month_data
    add     x2, x0, #Calendar.days_in_month
    mov     w3, #12
1:  ldr     w4, [x1], #4
    str     w4, [x2], #4
    subs    w3, w3, #1
    b.ne    1b
    
    // Copy month names
    adrp    x1, month_names_data
    add     x1, x1, :lo12:month_names_data
    add     x2, x0, #Calendar.month_names
    mov     w3, #384                // 12 * 32 bytes
2:  ldrb    w4, [x1], #1
    strb    w4, [x2], #1
    subs    w3, w3, #1
    b.ne    2b
    
    // Copy season mapping
    adrp    x1, season_mapping_data
    add     x1, x1, :lo12:season_mapping_data
    add     x2, x0, #Calendar.season_months
    mov     w3, #12
3:  ldr     w4, [x1], #4
    str     w4, [x2], #4
    subs    w3, w3, #1
    b.ne    3b
    
    // Copy season names
    adrp    x1, season_names_data
    add     x1, x1, :lo12:season_names_data
    add     x2, x0, #Calendar.season_names
    mov     w3, #128                // 4 * 32 bytes
4:  ldrb    w4, [x1], #1
    strb    w4, [x2], #1
    subs    w3, w3, #1
    b.ne    4b
    
    // Copy day names
    adrp    x1, day_names_data
    add     x1, x1, :lo12:day_names_data
    add     x2, x0, #Calendar.day_names
    mov     w3, #224                // 7 * 32 bytes
5:  ldrb    w4, [x1], #1
    strb    w4, [x2], #1
    subs    w3, w3, #1
    b.ne    5b
    
    ldp     x29, x30, [sp], #16
    ret

initialize_time_controls:
    adrp    x0, time_controls
    add     x0, x0, :lo12:time_controls
    
    // Copy speed multipliers
    adrp    x1, speed_multipliers_data
    add     x1, x1, :lo12:speed_multipliers_data
    add     x2, x0, #TimeControls.available_speeds
    mov     w3, #8                  // 8 speeds
1:  ldr     w4, [x1], #4
    str     w4, [x2], #4
    subs    w3, w3, #1
    b.ne    1b
    
    // Set speed count and initial speed (1x = index 1)
    mov     w1, #8
    str     w1, [x0, #TimeControls.speed_count]
    mov     w1, #1                  // Start at normal speed
    str     w1, [x0, #TimeControls.current_speed_index]
    
    ret

update_time_scale_transition:
    adrp    x0, game_time
    add     x0, x0, :lo12:game_time
    
    // Get current and target time scales
    ldr     s0, [x0, #GameTime.time_scale]
    ldr     s1, [x0, #GameTime.target_time_scale]
    
    // Check if we need to transition
    fcmp    s0, s1
    b.eq    transition_done
    
    // Smooth transition (10% per frame)
    fsub    s2, s1, s0              // difference
    fmov    s3, #0.1                // transition rate
    fmul    s2, s2, s3              // scaled difference
    fadd    s0, s0, s2              // new current scale
    
    str     s0, [x0, #GameTime.time_scale]
    
transition_done:
    ret

//
// External interface functions for getting time information
//

// time_system_get_date_string - Get formatted date string
// Parameters: x0 = buffer pointer, x1 = buffer size
// Returns: x0 = string length
.global time_system_get_date_string
time_system_get_date_string:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                 // buffer
    mov     x20, x1                 // size
    
    adrp    x9, game_time
    add     x9, x9, :lo12:game_time
    
    // Get date components
    ldr     w0, [x9, #GameTime.month]
    ldr     w1, [x9, #GameTime.day]
    ldr     w2, [x9, #GameTime.year]
    
    // Simple formatting: "Month DD, YYYY"
    // For now, just format as numbers: "MM/DD/YYYY"
    // TODO: Use month names from calendar data
    
    // This is a simplified implementation
    mov     x0, #0                  // Return 0 for now
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// time_system_get_time_string - Get formatted time string
// Parameters: x0 = buffer pointer, x1 = buffer size
// Returns: x0 = string length
.global time_system_get_time_string
time_system_get_time_string:
    // TODO: Format time as "HH:MM:SS"
    mov     x0, #0
    ret

// time_system_get_season - Get current season
// Returns: w0 = season (0=Winter, 1=Spring, 2=Summer, 3=Fall)
.global time_system_get_season
time_system_get_season:
    adrp    x0, game_time
    add     x0, x0, :lo12:game_time
    ldr     w0, [x0, #GameTime.season]
    ret

// External function declarations
.extern get_current_time_ns