//
// SimCity ARM64 Assembly - Agent Behavior State Machines
// Agent 5: Agent Systems & AI
//
// Implements behavior state machines for agent AI
// Handles home/work/shop routines, daily schedules, and decision making
// Optimized for 1M+ agents with efficient state transitions
//

.text
.align 4

// Include dependencies
.include "../simulation/simulation_constants.s"
.include "../include/constants/memory.inc"

// ============================================================================
// BEHAVIOR CONSTANTS
// ============================================================================

// Daily schedule time constants (in simulation minutes)
.equ SCHEDULE_DAY_LENGTH,       1440        // 24 hours in minutes
.equ SCHEDULE_WORK_START,       480         // 8:00 AM
.equ SCHEDULE_WORK_END,         1020        // 5:00 PM  
.equ SCHEDULE_LUNCH_START,      720         // 12:00 PM
.equ SCHEDULE_LUNCH_END,        780         // 1:00 PM
.equ SCHEDULE_SLEEP_START,      1380        // 11:00 PM
.equ SCHEDULE_SLEEP_END,        420         // 7:00 AM

// Behavior state machine constants
.equ BEHAVIOR_STATE_COUNT,      16          // Number of behavior states
.equ BEHAVIOR_TRANSITION_TABLE_SIZE, 256   // State transition table size
.equ BEHAVIOR_DECISION_TREE_DEPTH, 8       // Maximum decision tree depth

// Agent need levels (0-255)
.equ NEED_HUNGER_MAX,           255
.equ NEED_SLEEP_MAX,            255
.equ NEED_SOCIAL_MAX,           255
.equ NEED_SHOPPING_MAX,         255
.equ NEED_RECREATION_MAX,       255

// Need thresholds for behavior triggers
.equ HUNGER_CRITICAL,           200
.equ SLEEP_CRITICAL,            220
.equ SHOPPING_THRESHOLD,        150
.equ SOCIAL_THRESHOLD,          180

// Location type constants
.equ LOC_TYPE_HOME,             0
.equ LOC_TYPE_WORK,             1
.equ LOC_TYPE_SHOP,             2
.equ LOC_TYPE_RESTAURANT,       3
.equ LOC_TYPE_PARK,             4
.equ LOC_TYPE_TRANSPORT,        5

// Behavior priorities
.equ PRIORITY_CRITICAL,         10          // Emergency behaviors
.equ PRIORITY_HIGH,             7           // Important daily needs
.equ PRIORITY_MEDIUM,           5           // Regular activities
.equ PRIORITY_LOW,              3           // Optional activities
.equ PRIORITY_IDLE,             1           // Default/idle

// ============================================================================
// STRUCTURE DEFINITIONS
// ============================================================================

// Agent needs structure (16 bytes)
.struct AgentNeeds
    hunger                      .byte       // Hunger level (0-255)
    sleep                       .byte       // Sleep/tiredness level  
    social                      .byte       // Social interaction need
    shopping                    .byte       // Shopping need
    recreation                  .byte       // Recreation need
    health                      .byte       // Health level
    happiness                   .byte       // Happiness level
    stress                      .byte       // Stress level
    money                       .word       // Available money
    last_update                 .word       // Last needs update time
.endstruct

// Behavior state entry
.struct BehaviorState
    state_id                    .word       // State identifier
    priority                    .word       // State priority
    entry_function              .quad       // Function called on state entry
    update_function             .quad       // Function called each update
    exit_function               .quad       // Function called on state exit
    transition_table            .quad       // Pointer to transition table
    min_duration                .word       // Minimum time in state
    max_duration                .word       // Maximum time in state
.endstruct

// Behavior transition
.struct BehaviorTransition
    from_state                  .word       // Source state
    to_state                    .word       // Target state
    condition_function          .quad       // Condition check function
    probability                 .word       // Base probability (0-100)
    cooldown                    .word       // Cooldown between transitions
.endstruct

// Daily schedule entry
.struct ScheduleEntry
    start_time                  .hword      // Start time (minutes from midnight)
    end_time                    .hword      // End time
    activity_type               .word       // Type of activity
    location_type               .word       // Type of location required
    priority                    .word       // Priority of this activity
    flexibility                 .word       // How flexible the timing is
.endstruct

// Agent behavior context
.struct BehaviorContext
    current_state               .word       // Current behavior state
    previous_state              .word       // Previous state (for transitions)
    state_enter_time            .quad       // When current state was entered
    last_decision_time          .quad       // Last decision update time
    
    current_goal_x              .word       // Current movement goal
    current_goal_y              .word       // Current movement goal
    goal_type                   .word       // Type of current goal
    
    daily_schedule              .quad       // Pointer to daily schedule
    schedule_entry_count        .word       // Number of schedule entries
    current_schedule_index      .word       // Current schedule entry
    
    needs                       .space AgentNeeds_size // Agent needs
    
    decision_tree_state         .space 32   // Decision tree traversal state
    last_behavior_update        .quad       // Last behavior update time
.endstruct

// ============================================================================
// GLOBAL DATA
// ============================================================================

.section .data
.align 8

// Behavior state definitions
behavior_states:

// State 0: Idle/At Home
.quad   0                               // state_id  
.quad   PRIORITY_LOW                    // priority
.quad   behavior_idle_enter             // entry_function
.quad   behavior_idle_update            // update_function  
.quad   behavior_idle_exit              // exit_function
.quad   idle_transitions                // transition_table
.quad   60                              // min_duration (1 minute)
.quad   300                             // max_duration (5 minutes)

// State 1: Commuting to Work
.quad   1                               // state_id
.quad   PRIORITY_HIGH                   // priority
.quad   behavior_commute_work_enter     // entry_function
.quad   behavior_commute_update         // update_function
.quad   behavior_commute_exit           // exit_function
.quad   commute_work_transitions        // transition_table
.quad   300                             // min_duration (5 minutes)
.quad   1800                            // max_duration (30 minutes)

// State 2: At Work
.quad   2                               // state_id
.quad   PRIORITY_HIGH                   // priority
.quad   behavior_work_enter             // entry_function
.quad   behavior_work_update            // update_function
.quad   behavior_work_exit              // exit_function
.quad   work_transitions                // transition_table
.quad   3600                            // min_duration (1 hour)
.quad   28800                           // max_duration (8 hours)

// State 3: Shopping
.quad   3                               // state_id
.quad   PRIORITY_MEDIUM                 // priority
.quad   behavior_shopping_enter         // entry_function
.quad   behavior_shopping_update        // update_function
.quad   behavior_shopping_exit          // exit_function
.quad   shopping_transitions            // transition_table
.quad   600                             // min_duration (10 minutes)
.quad   3600                            // max_duration (1 hour)

// Behavior transition tables
idle_transitions:
    .word   0, 1, 0, 30, 0              // Idle -> Commute to Work (30% chance)
    .word   0, 3, 0, 20, 0              // Idle -> Shopping (20% chance)
    .word   -1, -1, 0, 0, 0             // End marker

commute_work_transitions:
    .word   1, 2, 0, 90, 0              // Commute -> Work (90% chance when at work)
    .word   1, 0, 0, 10, 0              // Commute -> Idle (if can't reach work)
    .word   -1, -1, 0, 0, 0             // End marker

work_transitions:
    .word   2, 4, 0, 15, 0              // Work -> Lunch (during lunch time)
    .word   2, 5, 0, 80, 0              // Work -> Commute Home (end of day)
    .word   -1, -1, 0, 0, 0             // End marker

shopping_transitions:
    .word   3, 0, 0, 70, 0              // Shopping -> Idle (return home)
    .word   3, 6, 0, 20, 0              // Shopping -> Recreation
    .word   -1, -1, 0, 0, 0             // End marker

// Default daily schedules for different agent types
default_schedule_citizen:
    .hword  420, 480,   0, LOC_TYPE_HOME, PRIORITY_HIGH, 30      // Wake up, get ready
    .hword  480, 540,   1, LOC_TYPE_TRANSPORT, PRIORITY_HIGH, 60 // Commute to work
    .hword  540, 720,   2, LOC_TYPE_WORK, PRIORITY_HIGH, 0       // Morning work
    .hword  720, 780,   3, LOC_TYPE_RESTAURANT, PRIORITY_MEDIUM, 30 // Lunch
    .hword  780, 1020,  2, LOC_TYPE_WORK, PRIORITY_HIGH, 0       // Afternoon work
    .hword  1020, 1080, 1, LOC_TYPE_TRANSPORT, PRIORITY_HIGH, 60 // Commute home
    .hword  1080, 1200, 0, LOC_TYPE_HOME, PRIORITY_MEDIUM, 120   // Evening at home
    .hword  1200, 1380, 4, LOC_TYPE_PARK, PRIORITY_LOW, 180     // Recreation
    .hword  1380, 420,  5, LOC_TYPE_HOME, PRIORITY_HIGH, 0      // Sleep

.equ DEFAULT_SCHEDULE_CITIZEN_COUNT, 9

.section .bss
.align 8

// Behavior system state
behavior_system_state:      .space 64

// Behavior context pool for agents
behavior_contexts:          .space (MAX_AGENTS * BehaviorContext_size)

// Decision tree cache
decision_cache:             .space (1024 * 64)

.section .text

// ============================================================================
// GLOBAL SYMBOLS
// ============================================================================

.global behavior_system_init
.global behavior_system_shutdown
.global behavior_update_agent
.global behavior_get_agent_context
.global behavior_set_agent_state
.global behavior_update_needs
.global behavior_get_current_activity
.global behavior_force_transition

// External dependencies
.extern pathfind_request
.extern get_current_time_ns
.extern agent_set_target

// ============================================================================
// BEHAVIOR SYSTEM INITIALIZATION
// ============================================================================

//
// behavior_system_init - Initialize the behavior system
//
// Returns:
//   x0 = 0 on success, error code on failure
//
behavior_system_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Initialize behavior contexts for all agents
    adrp    x0, behavior_contexts
    add     x0, x0, :lo12:behavior_contexts
    
    mov     x1, #0                      // Agent index
    mov     x2, #MAX_AGENTS
    
init_contexts_loop:
    // Calculate context address
    mov     x3, #BehaviorContext_size
    mul     x4, x1, x3
    add     x3, x0, x4                  // context_ptr
    
    // Initialize context to default values
    str     wzr, [x3, #BehaviorContext.current_state]
    str     wzr, [x3, #BehaviorContext.previous_state]
    str     xzr, [x3, #BehaviorContext.state_enter_time]
    str     xzr, [x3, #BehaviorContext.last_decision_time]
    
    // Set default schedule
    adrp    x4, default_schedule_citizen
    add     x4, x4, :lo12:default_schedule_citizen
    str     x4, [x3, #BehaviorContext.daily_schedule]
    mov     x4, #DEFAULT_SCHEDULE_CITIZEN_COUNT
    str     w4, [x3, #BehaviorContext.schedule_entry_count]
    str     wzr, [x3, #BehaviorContext.current_schedule_index]
    
    // Initialize needs to moderate levels
    add     x4, x3, #BehaviorContext.needs
    mov     w5, #128                    // Half of max need level
    strb    w5, [x4, #AgentNeeds.hunger]
    strb    w5, [x4, #AgentNeeds.sleep]
    strb    w5, [x4, #AgentNeeds.social]
    strb    w5, [x4, #AgentNeeds.shopping]
    strb    w5, [x4, #AgentNeeds.recreation]
    mov     w5, #200                    // Good health/happiness
    strb    w5, [x4, #AgentNeeds.health]
    strb    w5, [x4, #AgentNeeds.happiness]
    mov     w5, #50                     // Low stress
    strb    w5, [x4, #AgentNeeds.stress]
    mov     w5, #1000                   // Starting money
    str     w5, [x4, #AgentNeeds.money]
    
    add     x1, x1, #1
    cmp     x1, x2
    b.lt    init_contexts_loop
    
    mov     x0, #0                      // Success
    ldp     x29, x30, [sp], #16
    ret

//
// behavior_get_agent_context - Get behavior context for an agent
//
// Parameters:
//   x0 = agent_id
//
// Returns:
//   x0 = behavior context pointer (0 if invalid)
//
behavior_get_agent_context:
    // For now, use simple mapping: agent_id % MAX_AGENTS
    and     x1, x0, #(MAX_AGENTS - 1)   // Simple modulo for demo
    
    // Calculate context address
    adrp    x0, behavior_contexts
    add     x0, x0, :lo12:behavior_contexts
    mov     x2, #BehaviorContext_size
    mul     x3, x1, x2
    add     x0, x0, x3
    
    ret

// ============================================================================
// BEHAVIOR UPDATE SYSTEM
// ============================================================================

//
// behavior_update_agent - Update behavior for a single agent
//
// Parameters:
//   x0 = agent_id
//   x1 = current_world_time (simulation time in minutes)
//
// Returns:
//   x0 = 0 on success, error code on failure
//
behavior_update_agent:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // agent_id
    mov     x20, x1                     // current_world_time
    
    // Get agent behavior context
    mov     x0, x19
    bl      behavior_get_agent_context
    cbz     x0, behavior_update_error
    mov     x21, x0                     // context_ptr
    
    // Check if it's time for a behavior update
    bl      get_current_time_ns
    mov     x22, x0                     // current_time_ns
    
    ldr     x0, [x21, #BehaviorContext.last_behavior_update]
    sub     x1, x22, x0
    
    // Update every 100ms (100,000,000 nanoseconds)
    mov     x2, #100000000
    cmp     x1, x2
    b.lt    behavior_update_done
    
    // Store current update time
    str     x22, [x21, #BehaviorContext.last_behavior_update]
    
    // Update agent needs first
    mov     x0, x21                     // context_ptr
    mov     x1, x20                     // current_world_time
    bl      behavior_update_needs
    
    // Check daily schedule
    mov     x0, x21                     // context_ptr
    mov     x1, x20                     // current_world_time
    bl      behavior_check_schedule
    
    // Process current behavior state
    mov     x0, x21                     // context_ptr
    mov     x1, x19                     // agent_id
    bl      behavior_process_current_state
    
    // Check for state transitions
    mov     x0, x21                     // context_ptr
    mov     x1, x19                     // agent_id
    bl      behavior_check_transitions
    
behavior_update_done:
    mov     x0, #0                      // Success
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

behavior_update_error:
    mov     x0, #MEM_ERROR_INVALID_PTR
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// behavior_update_needs - Update agent's needs over time
//
// Parameters:
//   x0 = context_ptr
//   x1 = current_world_time
//
behavior_update_needs:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // context_ptr
    mov     x20, x1                     // current_world_time
    
    add     x21, x19, #BehaviorContext.needs // needs_ptr
    
    // Get time since last update
    ldr     w0, [x21, #AgentNeeds.last_update]
    sub     w22, w20, w0                // time_delta
    str     w20, [x21, #AgentNeeds.last_update]
    
    // Update hunger (increases over time)
    ldrb    w0, [x21, #AgentNeeds.hunger]
    add     w0, w0, w22, lsr #4         // Hunger increases slowly
    cmp     w0, #NEED_HUNGER_MAX
    csel    w0, w0, #NEED_HUNGER_MAX, le
    strb    w0, [x21, #AgentNeeds.hunger]
    
    // Update sleep need (increases over time, resets during sleep hours)
    ldrb    w0, [x21, #AgentNeeds.sleep]
    
    // Check if it's sleep time (11 PM to 7 AM)
    cmp     w20, #SCHEDULE_SLEEP_START
    b.ge    sleep_time_check
    cmp     w20, #SCHEDULE_SLEEP_END
    b.le    sleep_time_active
    b       sleep_time_awake

sleep_time_check:
    cmp     w20, #SCHEDULE_DAY_LENGTH
    b.ge    sleep_time_awake

sleep_time_active:
    // During sleep hours, decrease sleep need
    sub     w0, w0, w22, lsr #2         // Sleep need decreases faster
    cmp     w0, #0
    csel    w0, w0, #0, ge
    b       sleep_update_done

sleep_time_awake:
    // During awake hours, increase sleep need
    add     w0, w0, w22, lsr #5         // Sleep need increases slowly
    cmp     w0, #NEED_SLEEP_MAX
    csel    w0, w0, #NEED_SLEEP_MAX, le

sleep_update_done:
    strb    w0, [x21, #AgentNeeds.sleep]
    
    // Update social need (increases over time)
    ldrb    w0, [x21, #AgentNeeds.social]
    add     w0, w0, w22, lsr #6         // Social need increases very slowly
    cmp     w0, #NEED_SOCIAL_MAX
    csel    w0, w0, #NEED_SOCIAL_MAX, le
    strb    w0, [x21, #AgentNeeds.social]
    
    // Update shopping need (increases over time)
    ldrb    w0, [x21, #AgentNeeds.shopping]
    add     w0, w0, w22, lsr #7         // Shopping need increases very slowly
    cmp     w0, #NEED_SHOPPING_MAX
    csel    w0, w0, #NEED_SHOPPING_MAX, le
    strb    w0, [x21, #AgentNeeds.shopping]
    
    // Update happiness based on need satisfaction
    bl      behavior_calculate_happiness
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// behavior_check_schedule - Check if agent should follow daily schedule
//
// Parameters:
//   x0 = context_ptr
//   x1 = current_world_time
//
behavior_check_schedule:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // context_ptr
    mov     x20, x1                     // current_world_time
    
    // Get current schedule entry
    ldr     x21, [x19, #BehaviorContext.daily_schedule]
    ldr     w22, [x19, #BehaviorContext.current_schedule_index]
    ldr     w23, [x19, #BehaviorContext.schedule_entry_count]
    
    // Validate schedule index
    cmp     w22, w23
    b.ge    schedule_check_done
    
    // Calculate current schedule entry address
    mov     x0, #ScheduleEntry_size
    mul     x1, x22, x0
    add     x24, x21, x1                // current_entry_ptr
    
    // Check if current time is within this schedule entry
    ldrh    w0, [x24, #ScheduleEntry.start_time]
    ldrh    w1, [x24, #ScheduleEntry.end_time]
    
    // Handle schedule entries that cross midnight
    cmp     w1, w0
    b.ge    schedule_normal_check
    
    // Schedule crosses midnight (e.g., sleep: 23:00 to 07:00)
    cmp     w20, w0
    b.ge    schedule_in_range
    cmp     w20, w1
    b.le    schedule_in_range
    b       schedule_advance

schedule_normal_check:
    cmp     w20, w0
    b.lt    schedule_advance
    cmp     w20, w1
    b.gt    schedule_advance

schedule_in_range:
    // Agent should be following current schedule entry
    ldr     w0, [x24, #ScheduleEntry.activity_type]
    mov     x1, x19                     // context_ptr
    bl      behavior_enforce_schedule_activity
    b       schedule_check_done

schedule_advance:
    // Move to next schedule entry
    add     w22, w22, #1
    cmp     w22, w23
    csel    w22, w22, #0, lt            // Wrap to 0 if at end
    str     w22, [x19, #BehaviorContext.current_schedule_index]

schedule_check_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// behavior_process_current_state - Process agent's current behavior state
//
// Parameters:
//   x0 = context_ptr
//   x1 = agent_id
//
behavior_process_current_state:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // context_ptr
    mov     x20, x1                     // agent_id
    
    // Get current state
    ldr     w21, [x19, #BehaviorContext.current_state]
    
    // Get state definition
    adrp    x0, behavior_states
    add     x0, x0, :lo12:behavior_states
    mov     x1, #BehaviorState_size
    mul     x2, x21, x1
    add     x22, x0, x2                 // state_definition_ptr
    
    // Call state update function
    ldr     x0, [x22, #BehaviorState.update_function]
    cbz     x0, process_state_done
    
    mov     x1, x19                     // context_ptr
    mov     x2, x20                     // agent_id
    blr     x0                          // Call update function
    
process_state_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// behavior_check_transitions - Check for state transitions
//
// Parameters:
//   x0 = context_ptr
//   x1 = agent_id
//
behavior_check_transitions:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // context_ptr
    mov     x20, x1                     // agent_id
    
    // Get current state
    ldr     w21, [x19, #BehaviorContext.current_state]
    
    // Get state definition
    adrp    x0, behavior_states
    add     x0, x0, :lo12:behavior_states
    mov     x1, #BehaviorState_size
    mul     x2, x21, x1
    add     x22, x0, x2                 // state_definition_ptr
    
    // Get transition table
    ldr     x23, [x22, #BehaviorState.transition_table]
    cbz     x23, check_transitions_done
    
    // Iterate through transitions
check_transition_loop:
    ldr     w0, [x23, #BehaviorTransition.from_state]
    cmp     w0, #-1                     // End marker
    b.eq    check_transitions_done
    
    cmp     w0, w21                     // Check if this transition applies
    b.ne    next_transition
    
    // Check transition condition
    ldr     x0, [x23, #BehaviorTransition.condition_function]
    cbz     x0, check_probability
    
    mov     x1, x19                     // context_ptr
    mov     x2, x20                     // agent_id
    blr     x0                          // Call condition function
    cbz     x0, next_transition         // Condition not met
    
check_probability:
    // Check random probability
    ldr     w0, [x23, #BehaviorTransition.probability]
    bl      random_percentage
    cmp     x0, #1
    b.ne    next_transition
    
    // Transition should occur
    ldr     w0, [x23, #BehaviorTransition.to_state]
    mov     x1, x19                     // context_ptr
    mov     x2, x20                     // agent_id
    bl      behavior_transition_to_state
    b       check_transitions_done
    
next_transition:
    add     x23, x23, #BehaviorTransition_size
    b       check_transition_loop

check_transitions_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ============================================================================
// BEHAVIOR STATE IMPLEMENTATIONS
// ============================================================================

// Idle behavior state functions
behavior_idle_enter:
    // Agent enters idle state (at home)
    ret

behavior_idle_update:
    // Update idle behavior
    ret

behavior_idle_exit:
    // Agent leaves idle state
    ret

// Commuting behavior state functions
behavior_commute_work_enter:
    // Start commute to work - request pathfinding
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get agent's work location and request pathfinding
    // Implementation would get work coordinates and call pathfind_request
    
    ldp     x29, x30, [sp], #16
    ret

behavior_commute_update:
    // Update commuting behavior - check if arrived at destination
    ret

behavior_commute_exit:
    // Finish commuting
    ret

// Work behavior state functions
behavior_work_enter:
    // Agent arrives at work
    ret

behavior_work_update:
    // Update work behavior - generate money, reduce certain needs
    ret

behavior_work_exit:
    // Agent leaves work
    ret

// Shopping behavior state functions
behavior_shopping_enter:
    // Agent starts shopping
    ret

behavior_shopping_update:
    // Update shopping behavior - spend money, reduce shopping need
    ret

behavior_shopping_exit:
    // Agent finishes shopping
    ret

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

//
// behavior_transition_to_state - Transition agent to new behavior state
//
// Parameters:
//   x0 = new_state_id
//   x1 = context_ptr
//   x2 = agent_id
//
behavior_transition_to_state:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // new_state_id
    mov     x20, x1                     // context_ptr
    mov     x21, x2                     // agent_id
    
    // Get current state
    ldr     w22, [x20, #BehaviorContext.current_state]
    
    // Call exit function for current state
    adrp    x0, behavior_states
    add     x0, x0, :lo12:behavior_states
    mov     x1, #BehaviorState_size
    mul     x2, x22, x1
    add     x2, x0, x2                  // current_state_def_ptr
    
    ldr     x0, [x2, #BehaviorState.exit_function]
    cbz     x0, transition_set_new_state
    mov     x1, x20                     // context_ptr
    mov     x2, x21                     // agent_id
    blr     x0                          // Call exit function

transition_set_new_state:
    // Update state in context
    str     w22, [x20, #BehaviorContext.previous_state]
    str     w19, [x20, #BehaviorContext.current_state]
    
    // Record state entry time
    bl      get_current_time_ns
    str     x0, [x20, #BehaviorContext.state_enter_time]
    
    // Call entry function for new state
    adrp    x0, behavior_states
    add     x0, x0, :lo12:behavior_states
    mov     x1, #BehaviorState_size
    mul     x2, x19, x1
    add     x2, x0, x2                  // new_state_def_ptr
    
    ldr     x0, [x2, #BehaviorState.entry_function]
    cbz     x0, transition_done
    mov     x1, x20                     // context_ptr
    mov     x2, x21                     // agent_id
    blr     x0                          // Call entry function

transition_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// behavior_calculate_happiness - Calculate agent happiness based on needs
//
// Parameters:
//   x19 = context_ptr (preserved from caller)
//
behavior_calculate_happiness:
    add     x0, x19, #BehaviorContext.needs // needs_ptr
    
    // Calculate happiness based on inverse of unmet needs
    ldrb    w1, [x0, #AgentNeeds.hunger]
    ldrb    w2, [x0, #AgentNeeds.sleep]
    ldrb    w3, [x0, #AgentNeeds.social]
    
    // Simple happiness calculation: 255 - average of needs
    add     w4, w1, w2
    add     w4, w4, w3
    mov     w5, #3
    udiv    w4, w4, w5                  // Average need level
    mov     w5, #255
    sub     w4, w5, w4                  // Happiness = 255 - avg_needs
    
    // Clamp to valid range
    cmp     w4, #0
    csel    w4, w4, #0, ge
    cmp     w4, #255
    csel    w4, w4, #255, le
    
    strb    w4, [x0, #AgentNeeds.happiness]
    ret

//
// random_percentage - Generate random number and check against percentage
//
// Parameters:
//   x0 = percentage (0-100)
//
// Returns:
//   x0 = 1 if random number <= percentage, 0 otherwise
//
random_percentage:
    // Simple random number generator (placeholder)
    // In real implementation, would use proper RNG
    mov     x1, #42                     // Dummy random number (0-99)
    cmp     x1, x0
    cset    x0, le
    ret

// ============================================================================
// STUB IMPLEMENTATIONS
// ============================================================================

behavior_enforce_schedule_activity:
    ret

behavior_set_agent_state:
    mov     x0, #0
    ret

behavior_get_current_activity:
    mov     x0, #0
    ret

behavior_force_transition:
    mov     x0, #0
    ret

behavior_system_shutdown:
    mov     x0, #0
    ret