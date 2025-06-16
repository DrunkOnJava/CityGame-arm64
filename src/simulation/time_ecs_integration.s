//
// SimCity ARM64 Assembly - Time System ECS Integration
// Agent 2: Simulation Systems Developer
//
// Integration layer connecting the time system with ECS components
// Handles time-based updates, scheduling, and temporal state management
//

.include "ecs_core.s"
.include "ecs_components.s"
.include "time_system.s"

.text
.align 4

// Time Integration Structures

.struct TimeSystem
    // Time progression control
    time_multiplier     .float      // Global time speed multiplier
    pause_state         .word       // 1 if simulation is paused
    tick_accumulator    .float      // Accumulated time for fixed timestep
    fixed_timestep      .float      // Fixed timestep for simulation (1/30 sec)
    
    // Update scheduling
    daily_update_timer  .float      // Timer for daily updates
    weekly_update_timer .float      // Timer for weekly updates
    monthly_update_timer .float     // Timer for monthly updates
    yearly_update_timer .float      // Timer for yearly updates
    
    // Time-based component tracking
    timebased_entities  .space 4096 // List of entities with TimeBasedComponent
    timebased_count     .word       // Number of time-based entities
    
    // Scheduled events
    event_queue         .space 8192 // Queue of timed events
    event_count         .word       // Number of pending events
    next_event_time     .quad       // Time of next scheduled event
    
    // Performance tracking
    update_performance  .space 64   // Performance stats for time updates
    last_update_duration .float     // Time spent in last update
    
    _padding            .space 16   // Cache alignment
.endstruct

.struct ScheduledEvent
    event_time          .quad       // When this event should trigger
    entity_id           .quad       // Entity this event affects
    event_type          .word       // Type of event
    event_data          .space 16   // Event-specific data
    next_event          .quad       // Pointer to next event in queue
    _padding            .space 8    // Alignment
.endstruct

.struct TimeBasedUpdate
    update_type         .word       // Daily, weekly, monthly, yearly
    last_update_time    .quad       // Last time this update ran
    update_interval     .quad       // Interval between updates
    update_function     .quad       // Function to call for update
    _padding            .space 8    // Alignment
.endstruct

// Event types
#define EVENT_BUILDING_COMPLETE     0
#define EVENT_CITIZEN_AGE_UP        1
#define EVENT_ECONOMIC_CYCLE        2
#define EVENT_SEASONAL_CHANGE       3
#define EVENT_POLICY_EFFECT         4
#define EVENT_RANDOM_EVENT          5
#define EVENT_MAINTENANCE_DUE       6
#define EVENT_POPULATION_MILESTONE  7

// Update intervals
#define UPDATE_DAILY                0
#define UPDATE_WEEKLY               1
#define UPDATE_MONTHLY              2
#define UPDATE_YEARLY               3

// Global time integration state
.section .bss
    .align 8
    time_system_state:  .space TimeSystem_size
    scheduled_events:   .space (ScheduledEvent_size * 1000)
    time_based_updates: .space (TimeBasedUpdate_size * 32)

.section .text

//
// time_ecs_init - Initialize time system integration with ECS
//
// Parameters:
//   x0 = initial_time_multiplier (1.0 = normal speed)
//   x1 = fixed_timestep_ms (33 = 30 FPS)
//
// Returns:
//   x0 = 0 on success, error code on failure
//
.global time_ecs_init
time_ecs_init:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    fmov    s19, s0                 // time_multiplier
    mov     x20, x1                 // timestep_ms
    
    // Clear time system state
    adrp    x0, time_system_state
    add     x0, x0, :lo12:time_system_state
    mov     x1, #TimeSystem_size
    bl      memset
    
    // Initialize time system parameters
    adrp    x21, time_system_state
    add     x21, x21, :lo12:time_system_state
    
    str     s19, [x21, #TimeSystem.time_multiplier]
    str     wzr, [x21, #TimeSystem.pause_state]
    fmov    s0, #0.0
    str     s0, [x21, #TimeSystem.tick_accumulator]
    
    // Convert timestep to seconds
    scvtf   s1, x20                 // timestep_ms to float
    fmov    s2, #1000.0
    fdiv    s3, s1, s2              // Convert to seconds
    str     s3, [x21, #TimeSystem.fixed_timestep]
    
    // Initialize update timers
    str     s0, [x21, #TimeSystem.daily_update_timer]
    str     s0, [x21, #TimeSystem.weekly_update_timer]
    str     s0, [x21, #TimeSystem.monthly_update_timer]
    str     s0, [x21, #TimeSystem.yearly_update_timer]
    
    // Clear event queue
    adrp    x0, scheduled_events
    add     x0, x0, :lo12:scheduled_events
    mov     x1, #(ScheduledEvent_size * 1000)
    bl      memset
    
    str     wzr, [x21, #TimeSystem.event_count]
    str     xzr, [x21, #TimeSystem.next_event_time]
    
    // Initialize time-based update schedule
    bl      initialize_time_based_updates
    
    // Register time progression system with ECS
    mov     x0, #SYSTEM_TIME_PROGRESSION
    mov     x1, #0                  // Highest priority (runs first)
    mov     x2, #1                  // Enabled
    mov     x3, #0                  // Update every frame
    adrp    x4, time_progression_system_update
    add     x4, x4, :lo12:time_progression_system_update
    bl      register_ecs_system
    
    mov     x0, #0                  // Success
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// time_progression_system_update - Main time progression system update
//
// Parameters:
//   x0 = current_tick
//   d0 = delta_time
//   x2 = ecs_world_ptr
//
.global time_progression_system_update
time_progression_system_update:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    mov     x19, x0                 // current_tick
    fmov    s20, s0                 // delta_time
    mov     x21, x2                 // ecs_world_ptr
    
    adrp    x22, time_system_state
    add     x22, x22, :lo12:time_system_state
    
    // Check if simulation is paused
    ldr     w0, [x22, #TimeSystem.pause_state]
    cbnz    w0, time_update_done
    
    // Apply time multiplier to delta time
    ldr     s1, [x22, #TimeSystem.time_multiplier]
    fmul    s20, s20, s1            // scaled_delta_time
    
    // Update the core time system
    fmov    s0, s20
    bl      time_system_update
    
    // Accumulate time for fixed timestep updates
    ldr     s2, [x22, #TimeSystem.tick_accumulator]
    fadd    s2, s2, s20
    str     s2, [x22, #TimeSystem.tick_accumulator]
    
    // Check if we need to perform fixed timestep updates
    ldr     s3, [x22, #TimeSystem.fixed_timestep]
    
fixed_timestep_loop:
    fcmp    s2, s3
    b.lt    process_scheduled_events
    
    // Perform fixed timestep update
    bl      fixed_timestep_update
    
    // Subtract timestep from accumulator
    fsub    s2, s2, s3
    str     s2, [x22, #TimeSystem.tick_accumulator]
    b       fixed_timestep_loop
    
process_scheduled_events:
    // Process any scheduled events that are due
    bl      process_time_based_events
    
    // Update time-based components
    bl      update_timebased_components
    
    // Check for periodic updates (daily, weekly, monthly, yearly)
    bl      check_periodic_updates
    
time_update_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// fixed_timestep_update - Perform consistent timestep simulation updates
//
fixed_timestep_update:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Update time-based components with fixed timestep
    bl      update_component_timers
    
    // Update economic calculations
    bl      update_economic_timers
    
    // Update population lifecycles
    bl      update_population_timers
    
    // Update building construction/aging
    bl      update_building_timers
    
    ldp     x29, x30, [sp], #16
    ret

//
// update_timebased_components - Update all entities with TimeBasedComponent
//
update_timebased_components:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    // Query ECS for all entities with TimeBasedComponent
    mov     x0, #COMPONENT_TIME_BASED
    bl      query_entities_with_component
    mov     x19, x0                 // entity_list
    mov     x20, x1                 // entity_count
    
    cbz     x19, update_timebased_done
    
    mov     w21, #0                 // entity_index
    
timebased_update_loop:
    cmp     w21, w20
    b.ge    update_timebased_done
    
    // Get entity ID
    ldr     x22, [x19, x21, lsl #3] // entity_id
    
    // Update time-based component for this entity
    mov     x0, x22
    bl      update_entity_timebased_component
    
    add     w21, w21, #1
    b       timebased_update_loop
    
update_timebased_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// update_entity_timebased_component - Update a single entity's time-based component
//
// Parameters:
//   x0 = entity_id
//
update_entity_timebased_component:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                 // entity_id
    
    // Get time-based component
    mov     x0, x19
    mov     x1, #COMPONENT_TIME_BASED
    bl      ecs_get_component
    cbz     x0, update_entity_timebased_done
    mov     x20, x0                 // timebased_component
    
    // Get current game time
    bl      time_system_get_current_tick
    mov     x21, x0                 // current_tick
    
    // Check if it's time to update this entity
    ldr     w1, [x20, #TimeBasedComponent.update_interval]
    cbz     w1, always_update       // 0 = update every tick
    
    ldr     x2, [x20, #TimeBasedComponent.last_update_tick]
    sub     x3, x21, x2             // ticks_since_update
    cmp     x3, x1
    b.lt    update_entity_timebased_done
    
always_update:
    // Update last update tick
    str     x21, [x20, #TimeBasedComponent.last_update_tick]
    
    // Update lifespan
    ldr     w4, [x20, #TimeBasedComponent.lifespan_remaining]
    cmp     w4, #-1                 // -1 = infinite lifespan
    b.eq    update_decay
    
    sub     w4, w4, #1
    str     w4, [x20, #TimeBasedComponent.lifespan_remaining]
    
    // Check if entity has expired
    cbz     w4, entity_expired
    
update_decay:
    // Apply decay rate
    ldr     s0, [x20, #TimeBasedComponent.decay_rate]
    fcmp    s0, #0.0
    b.eq    update_growth
    
    // TODO: Apply decay to relevant components (health, condition, etc.)
    
update_growth:
    // Apply growth rate
    ldr     s1, [x20, #TimeBasedComponent.growth_rate]
    fcmp    s1, #0.0
    b.eq    update_maturity
    
    // TODO: Apply growth to relevant components (size, capacity, etc.)
    
update_maturity:
    // Update maturity level
    ldr     w5, [x20, #TimeBasedComponent.maturity_level]
    cmp     w5, #100                // Already at max maturity
    b.ge    check_scheduled_events
    
    // Increment maturity based on growth rate
    ldr     s2, [x20, #TimeBasedComponent.growth_rate]
    fmov    s3, #0.1                // Base maturity increment
    fmul    s4, s2, s3              // Scaled increment
    fcvtzs  w6, s4
    add     w5, w5, w6
    mov     w7, #100
    cmp     w5, w7
    csel    w5, w5, w7, lt          // Clamp to 100
    str     w5, [x20, #TimeBasedComponent.maturity_level]
    
check_scheduled_events:
    // Check if this entity has a scheduled event coming up
    ldr     x8, [x20, #TimeBasedComponent.next_event_time]
    cbz     x8, update_entity_timebased_done
    
    // Convert current tick to game time for comparison
    bl      convert_tick_to_game_time
    cmp     x0, x8
    b.lt    update_entity_timebased_done
    
    // Event is due - schedule it for processing
    mov     x0, x19                 // entity_id
    mov     x1, x8                  // event_time
    bl      schedule_entity_event
    
    b       update_entity_timebased_done
    
entity_expired:
    // Entity has reached end of lifespan - destroy it
    mov     x0, x19
    bl      ecs_destroy_entity
    
update_entity_timebased_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// process_time_based_events - Process scheduled events that are due
//
process_time_based_events:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    adrp    x19, time_system_state
    add     x19, x19, :lo12:time_system_state
    
    // Get current game time
    bl      time_system_get_current_tick
    mov     x20, x0                 // current_time
    
    // Get event queue
    adrp    x21, scheduled_events
    add     x21, x21, :lo12:scheduled_events
    ldr     w22, [x19, #TimeSystem.event_count]
    
    mov     w23, #0                 // event_index
    
event_processing_loop:
    cmp     w23, w22
    b.ge    event_processing_done
    
    // Get event pointer
    mov     x0, #ScheduledEvent_size
    mul     x0, x23, x0
    add     x24, x21, x0            // event_ptr
    
    // Check if event is due
    ldr     x1, [x24, #ScheduledEvent.event_time]
    cmp     x20, x1
    b.lt    next_event
    
    // Process this event
    mov     x0, x24
    bl      execute_scheduled_event
    
    // Remove event from queue
    mov     x0, x23                 // event_index
    bl      remove_event_from_queue
    
    // Decrement count and index since we removed an event
    sub     w22, w22, #1
    sub     w23, w23, #1
    
next_event:
    add     w23, w23, #1
    b       event_processing_loop
    
event_processing_done:
    // Update event count
    str     w22, [x19, #TimeSystem.event_count]
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// check_periodic_updates - Check for daily, weekly, monthly, yearly updates
//
check_periodic_updates:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    adrp    x19, time_system_state
    add     x19, x19, :lo12:time_system_state
    
    // Get current game time
    bl      time_system_get_current_tick
    bl      convert_tick_to_game_time
    mov     x20, x0                 // current_game_time
    
    // Check daily updates
    ldr     s0, [x19, #TimeSystem.daily_update_timer]
    fmov    s1, #86400.0            // Seconds in a day
    fadd    s0, s0, s20             // Add scaled delta time
    fcmp    s0, s1
    b.lt    check_weekly
    
    // Time for daily update
    fsub    s0, s0, s1
    str     s0, [x19, #TimeSystem.daily_update_timer]
    bl      trigger_daily_updates
    
check_weekly:
    ldr     s0, [x19, #TimeSystem.weekly_update_timer]
    fmov    s1, #604800.0           // Seconds in a week
    fadd    s0, s0, s20
    fcmp    s0, s1
    b.lt    check_monthly
    
    fsub    s0, s0, s1
    str     s0, [x19, #TimeSystem.weekly_update_timer]
    bl      trigger_weekly_updates
    
check_monthly:
    ldr     s0, [x19, #TimeSystem.monthly_update_timer]
    fmov    s1, #2592000.0          // Approx seconds in a month
    fadd    s0, s0, s20
    fcmp    s0, s1
    b.lt    check_yearly
    
    fsub    s0, s0, s1
    str     s0, [x19, #TimeSystem.monthly_update_timer]
    bl      trigger_monthly_updates
    
check_yearly:
    ldr     s0, [x19, #TimeSystem.yearly_update_timer]
    fmov    s1, #31536000.0         // Seconds in a year
    fadd    s0, s0, s20
    fcmp    s0, s1
    b.lt    periodic_updates_done
    
    fsub    s0, s0, s1
    str     s0, [x19, #TimeSystem.yearly_update_timer]
    bl      trigger_yearly_updates
    
periodic_updates_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// Periodic update trigger functions
//

trigger_daily_updates:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Trigger daily economic updates
    bl      daily_economic_update
    
    // Trigger daily population updates
    bl      daily_population_update
    
    // Trigger daily building maintenance checks
    bl      daily_building_update
    
    ldp     x29, x30, [sp], #16
    ret

trigger_weekly_updates:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Trigger weekly zone development
    bl      weekly_zone_update
    
    // Trigger weekly crime/safety updates
    bl      weekly_safety_update
    
    ldp     x29, x30, [sp], #16
    ret

trigger_monthly_updates:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Trigger monthly economic cycle updates
    bl      monthly_economic_cycle_update
    
    // Trigger monthly population demographics
    bl      monthly_population_demographics_update
    
    // Trigger monthly budget calculations
    bl      monthly_budget_update
    
    ldp     x29, x30, [sp], #16
    ret

trigger_yearly_updates:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Trigger yearly statistics compilation
    bl      yearly_statistics_update
    
    // Trigger yearly policy evaluations
    bl      yearly_policy_evaluation
    
    ldp     x29, x30, [sp], #16
    ret

//
// Time control functions
//

// time_ecs_set_speed - Set time progression speed
// Parameters: s0 = time_multiplier (1.0 = normal, 2.0 = 2x speed, etc.)
.global time_ecs_set_speed
time_ecs_set_speed:
    adrp    x0, time_system_state
    add     x0, x0, :lo12:time_system_state
    str     s0, [x0, #TimeSystem.time_multiplier]
    ret

// time_ecs_pause - Pause or unpause simulation
// Parameters: w0 = 1 to pause, 0 to unpause
.global time_ecs_pause
time_ecs_pause:
    adrp    x1, time_system_state
    add     x1, x1, :lo12:time_system_state
    str     w0, [x1, #TimeSystem.pause_state]
    ret

// time_ecs_get_speed - Get current time multiplier
// Returns: s0 = current time multiplier
.global time_ecs_get_speed
time_ecs_get_speed:
    adrp    x0, time_system_state
    add     x0, x0, :lo12:time_system_state
    ldr     s0, [x0, #TimeSystem.time_multiplier]
    ret

// schedule_event - Schedule a future event
// Parameters: x0 = entity_id, x1 = event_time, w2 = event_type
// Returns: x0 = 0 on success, error code on failure
.global schedule_event
schedule_event:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                 // entity_id
    mov     x20, x1                 // event_time
    mov     w21, w2                 // event_type
    
    adrp    x22, time_system_state
    add     x22, x22, :lo12:time_system_state
    
    // Check if event queue is full
    ldr     w0, [x22, #TimeSystem.event_count]
    cmp     w0, #1000               // Max events
    b.ge    schedule_event_error
    
    // Find slot in event queue
    adrp    x1, scheduled_events
    add     x1, x1, :lo12:scheduled_events
    mov     x2, #ScheduledEvent_size
    mul     x2, x0, x2
    add     x3, x1, x2              // event_slot
    
    // Fill in event data
    str     x20, [x3, #ScheduledEvent.event_time]
    str     x19, [x3, #ScheduledEvent.entity_id]
    str     w21, [x3, #ScheduledEvent.event_type]
    
    // Increment event count
    add     w0, w0, #1
    str     w0, [x22, #TimeSystem.event_count]
    
    mov     x0, #0                  // Success
    b       schedule_event_done
    
schedule_event_error:
    mov     x0, #-1                 // Error
    
schedule_event_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// External function declarations
.extern memset
.extern register_ecs_system
.extern query_entities_with_component
.extern ecs_get_component
.extern ecs_destroy_entity
.extern time_system_update
.extern time_system_get_current_tick