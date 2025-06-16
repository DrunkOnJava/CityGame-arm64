//
// SimCity ARM64 Assembly - Population Dynamics System
// Agent 2: Simulation Systems Developer
//
// Advanced population simulation with demographics, migration patterns,
// lifecycle events, and social dynamics using the ECS framework
//

.include "ecs_core.s"
.include "ecs_components.s"

.text
.align 4

// Population System Structures

.struct PopulationStatistics
    // Total population breakdown
    total_population    .word       // Current total population
    birth_rate          .float      // Births per 1000 per year
    death_rate          .float      // Deaths per 1000 per year
    migration_rate      .float      // Net migration per 1000 per year
    
    // Age demographics
    population_0_17     .word       // Children and teens
    population_18_34    .word       // Young adults
    population_35_54    .word       // Middle-aged adults
    population_55_74    .word       // Older adults
    population_75_plus  .word       // Seniors
    
    // Income demographics
    low_income_pop      .word       // Bottom 25% income
    middle_income_pop   .word       // Middle 50% income
    high_income_pop     .word       // Top 25% income
    
    // Education levels
    no_education        .word       // No formal education
    primary_education   .word       // Elementary school
    secondary_education .word       // High school
    tertiary_education  .word       // College/university
    advanced_education  .word       // Graduate/professional
    
    // Employment status
    employed_population .word       // Currently employed
    unemployed_population .word     // Seeking employment
    retired_population  .word       // Retired individuals
    student_population  .word       // Full-time students
    
    // Health and social indicators
    average_health      .float      // Overall health index (0-100)
    average_happiness   .float      // Life satisfaction (0-100)
    crime_victimization .float      // Crime rate per 1000
    healthcare_access   .float      // Access to healthcare (0-100)
    
    // Growth trends
    population_growth_rate .float   // Annual population growth %
    urbanization_rate   .float      // Rural to urban migration %
    gentrification_rate .float      // Neighborhood change rate
    
    _padding            .space 16   // Cache alignment
.endstruct

.struct MigrationPatterns
    // Immigration factors
    job_attraction      .float      // Job availability factor
    cost_of_living      .float      // Affordability factor
    quality_of_life     .float      // Livability factor
    climate_appeal      .float      // Weather attractiveness
    cultural_factors    .float      // Cultural amenities
    
    // Emigration factors
    housing_shortage    .float      // Lack of housing pushes people away
    high_crime_rate     .float      // Safety concerns drive emigration
    economic_recession  .float      // Economic hardship
    pollution_levels    .float      // Environmental quality
    traffic_congestion  .float      // Transportation problems
    
    // Migration flows
    daily_immigrants    .word       // New arrivals per day
    daily_emigrants     .word       // Departures per day
    seasonal_workers    .word       // Temporary population
    tourists_daily      .word       // Tourist population
    
    // Regional connections
    nearby_cities       .space 32   // Connected metropolitan areas
    migration_routes    .space 64   // Major migration corridors
    
    // Migration history
    immigration_history .space 1460 // 4 years of daily immigration data
    emigration_history  .space 1460 // 4 years of daily emigration data
    
    _padding            .space 16   // Alignment
.endstruct

.struct LifecycleEvents
    // Birth events
    births_today        .word       // Births occurring today
    birth_queue         .space 1024 // Pending birth events
    birth_queue_size    .word       // Number of pending births
    
    // Death events
    deaths_today        .word       // Deaths occurring today
    death_queue         .space 1024 // Pending death events
    death_queue_size    .word       // Number of pending deaths
    
    // Life transitions
    children_aging_up   .word       // Children becoming adults
    adults_retiring     .word       // Workers becoming retirees
    students_graduating .word       // Students entering workforce
    
    // Marriage and family
    marriages_today     .word       // New marriages
    divorces_today      .word       // Divorces
    household_formations .word      // New households formed
    household_dissolutions .word    // Households dissolved
    
    // Education transitions
    school_enrollments  .word       // Children starting school
    college_enrollments .word       // Students starting college
    graduations         .word       // Students completing education
    
    // Career changes
    job_changes         .word       // People changing employment
    promotions          .word       // Career advancements
    layoffs             .word       // Job losses
    retirements         .word       // People leaving workforce
    
    _padding            .space 16   // Alignment
.endstruct

.struct SocialDynamics
    // Community cohesion
    social_capital      .float      // Community connections strength
    civic_engagement    .float      // Political participation level
    volunteer_rate      .float      // Volunteer participation %
    crime_reporting     .float      // Citizens reporting crimes %
    
    // Cultural diversity
    ethnic_diversity    .float      // Cultural mix index
    language_diversity  .word       // Number of languages spoken
    religious_diversity .float      // Religious variety index
    
    // Social problems
    homelessness_rate   .float      // Homeless per 1000 population
    addiction_rate      .float      // Substance abuse rate
    mental_health_issues .float     // Mental health problems %
    domestic_violence   .float      // Domestic abuse incidents
    
    // Social mobility
    upward_mobility     .float      // People improving economic status
    downward_mobility   .float      // People losing economic status
    intergenerational_mobility .float // Children exceeding parents
    
    // Social services usage
    welfare_recipients  .word       // People receiving assistance
    food_bank_usage     .word       // People needing food aid
    homeless_services   .word       // People using homeless services
    mental_health_services .word    // Mental health service users
    
    _padding            .space 16   // Alignment
.endstruct

// Global population system state
.section .bss
    .align 8
    population_stats:       .space PopulationStatistics_size
    migration_patterns:     .space MigrationPatterns_size
    lifecycle_events:       .space LifecycleEvents_size
    social_dynamics:        .space SocialDynamics_size
    
    // Population entity tracking
    population_entities:    .space (8 * 50000)  // Entity IDs with population components
    population_entity_count: .word
    
    // Demographic calculation workspace
    demographic_calculations: .space 2048
    population_projections:   .space (4 * 365 * 5)  // 5 years of projections

.section .text

//
// population_system_init - Initialize the population dynamics system
//
// Parameters:
//   x0 = starting_population
//   x1 = city_attractiveness (0-100)
//
// Returns:
//   x0 = 0 on success, error code on failure
//
.global population_system_init
population_system_init:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                 // starting_population
    mov     x20, x1                 // city_attractiveness
    
    // Clear population structures
    adrp    x0, population_stats
    add     x0, x0, :lo12:population_stats
    mov     x1, #PopulationStatistics_size
    bl      memset
    
    adrp    x0, migration_patterns
    add     x0, x0, :lo12:migration_patterns
    mov     x1, #MigrationPatterns_size
    bl      memset
    
    adrp    x0, lifecycle_events
    add     x0, x0, :lo12:lifecycle_events
    mov     x1, #LifecycleEvents_size
    bl      memset
    
    adrp    x0, social_dynamics
    add     x0, x0, :lo12:social_dynamics
    mov     x1, #SocialDynamics_size
    bl      memset
    
    // Initialize starting population statistics
    bl      initialize_starting_demographics
    
    // Initialize migration patterns
    bl      initialize_migration_system
    
    // Initialize social dynamics
    bl      initialize_social_system
    
    // Register population system with ECS
    mov     x0, #SYSTEM_POPULATION
    mov     x1, #2                  // Priority 2
    mov     x2, #1                  // Enabled
    mov     x3, #0                  // Update every frame
    adrp    x4, population_system_update
    add     x4, x4, :lo12:population_system_update
    bl      register_ecs_system
    
    mov     x0, #0                  // Success
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// population_system_update - Main population system update function
//
// Parameters:
//   x0 = current_tick
//   d0 = delta_time
//   x2 = ecs_world_ptr
//
.global population_system_update
population_system_update:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    mov     x19, x0                 // current_tick
    fmov    s20, s0                 // delta_time
    mov     x21, x2                 // ecs_world_ptr
    
    // Process lifecycle events (births, deaths, aging)
    bl      process_lifecycle_events
    
    // Update migration patterns
    bl      update_migration_flows
    
    // Update population demographics
    bl      update_population_demographics
    
    // Process social dynamics
    bl      update_social_dynamics
    
    // Update all population entities
    bl      update_population_entities
    
    // Calculate city-wide population statistics
    bl      calculate_population_statistics
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// process_lifecycle_events - Handle births, deaths, and aging
//
process_lifecycle_events:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    adrp    x19, lifecycle_events
    add     x19, x19, :lo12:lifecycle_events
    
    // Process births
    bl      process_birth_events
    
    // Process deaths
    bl      process_death_events
    
    // Process aging transitions
    bl      process_aging_events
    
    // Process life transitions (marriage, education, employment)
    bl      process_life_transitions
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// process_birth_events - Generate new population through births
//
process_birth_events:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    adrp    x19, population_stats
    add     x19, x19, :lo12:population_stats
    
    // Calculate births per day based on birth rate
    ldr     w0, [x19, #PopulationStatistics.total_population]
    ldr     s1, [x19, #PopulationStatistics.birth_rate]
    
    // Convert annual birth rate to daily
    scvtf   s2, w0                  // population to float
    fmul    s3, s2, s1              // annual_births = population * birth_rate / 1000
    fmov    s4, #1000.0
    fdiv    s3, s3, s4
    
    fmov    s5, #365.0              // days per year
    fdiv    s6, s3, s5              // daily_births = annual_births / 365
    
    // Add random variation (±20%)
    bl      get_random_float_01
    fmov    s7, #0.4                // 40% range
    fmul    s8, s0, s7              // random * range
    fmov    s9, #0.8                // 80% base
    fadd    s8, s8, s9              // 0.8 to 1.2 multiplier
    fmul    s6, s6, s8              // Apply variation
    
    fcvtzs  w20, s6                 // births_today
    
    // Store births for today
    adrp    x0, lifecycle_events
    add     x0, x0, :lo12:lifecycle_events
    str     w20, [x0, #LifecycleEvents.births_today]
    
    // Create birth events for processing
    cbz     w20, birth_events_done
    
    mov     w21, #0                 // birth_index
create_birth_loop:
    cmp     w21, w20
    b.ge    birth_events_done
    
    // Create new citizen entity
    bl      create_newborn_citizen
    
    add     w21, w21, #1
    b       create_birth_loop
    
birth_events_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// process_death_events - Handle population deaths
//
process_death_events:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    adrp    x19, population_stats
    add     x19, x19, :lo12:population_stats
    
    // Calculate deaths per day based on death rate
    ldr     w0, [x19, #PopulationStatistics.total_population]
    ldr     s1, [x19, #PopulationStatistics.death_rate]
    
    // Convert annual death rate to daily
    scvtf   s2, w0                  // population to float
    fmul    s3, s2, s1              // annual_deaths = population * death_rate / 1000
    fmov    s4, #1000.0
    fdiv    s3, s3, s4
    
    fmov    s5, #365.0              // days per year
    fdiv    s6, s3, s5              // daily_deaths = annual_deaths / 365
    
    // Add random variation
    bl      get_random_float_01
    fmov    s7, #0.3                // 30% range
    fmul    s8, s0, s7
    fmov    s9, #0.85               // 85% base
    fadd    s8, s8, s9              // 0.85 to 1.15 multiplier
    fmul    s6, s6, s8
    
    fcvtzs  w20, s6                 // deaths_today
    
    // Store deaths for today
    adrp    x0, lifecycle_events
    add     x0, x0, :lo12:lifecycle_events
    str     w20, [x0, #LifecycleEvents.deaths_today]
    
    // Process death events
    cbz     w20, death_events_done
    
    mov     w21, #0                 // death_index
process_death_loop:
    cmp     w21, w20
    b.ge    death_events_done
    
    // Select citizen for death based on age and health
    bl      select_citizen_for_death
    cbz     x0, skip_death
    
    // Remove citizen entity
    bl      ecs_destroy_entity
    
skip_death:
    add     w21, w21, #1
    b       process_death_loop
    
death_events_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// update_migration_flows - Handle immigration and emigration
//
update_migration_flows:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    adrp    x19, migration_patterns
    add     x19, x19, :lo12:migration_patterns
    
    // Calculate immigration attractiveness
    bl      calculate_immigration_attractiveness
    fmov    s20, s0                 // attractiveness_factor
    
    // Calculate emigration pressure
    bl      calculate_emigration_pressure
    fmov    s21, s0                 // emigration_factor
    
    // Base migration rates per day
    adrp    x22, population_stats
    add     x22, x22, :lo12:population_stats
    ldr     w0, [x22, #PopulationStatistics.total_population]
    scvtf   s22, w0                 // total_population
    
    // Calculate daily immigration
    fmov    s0, #0.001              // Base immigration rate (0.1% annually)
    fmul    s1, s22, s0             // base_annual_immigration
    fmov    s2, #365.0
    fdiv    s3, s1, s2              // base_daily_immigration
    fmul    s4, s3, s20             // Apply attractiveness factor
    fcvtzs  w23, s4                 // daily_immigrants
    
    // Calculate daily emigration
    fmov    s0, #0.0008             // Base emigration rate (0.08% annually)
    fmul    s1, s22, s0             // base_annual_emigration
    fdiv    s3, s1, s2              // base_daily_emigration
    fmul    s4, s3, s21             // Apply emigration pressure
    fcvtzs  w24, s4                 // daily_emigrants
    
    // Store migration flows
    str     w23, [x19, #MigrationPatterns.daily_immigrants]
    str     w24, [x19, #MigrationPatterns.daily_emigrants]
    
    // Process immigration
    cbz     w23, process_emigration
    mov     w25, #0                 // immigrant_index
immigration_loop:
    cmp     w25, w23
    b.ge    process_emigration
    
    bl      create_immigrant_citizen
    
    add     w25, w25, #1
    b       immigration_loop
    
process_emigration:
    // Process emigration
    cbz     w24, migration_done
    mov     w25, #0                 // emigrant_index
emigration_loop:
    cmp     w25, w24
    b.ge    migration_done
    
    bl      select_citizen_for_emigration
    cbz     x0, skip_emigration
    
    bl      ecs_destroy_entity
    
skip_emigration:
    add     w25, w25, #1
    b       emigration_loop
    
migration_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// update_population_entities - Update all entities with population components
//
update_population_entities:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    // Query ECS for all entities with PopulationComponent
    mov     x0, #COMPONENT_POPULATION
    bl      query_entities_with_component
    mov     x19, x0                 // entity_list
    mov     x20, x1                 // entity_count
    
    cbz     x19, update_pop_entities_done
    
    mov     w21, #0                 // entity_index
    
pop_entity_update_loop:
    cmp     w21, w20
    b.ge    update_pop_entities_done
    
    // Get entity ID
    ldr     x22, [x19, x21, lsl #3] // entity_id
    
    // Update population factors for this entity
    mov     x0, x22
    bl      update_entity_population
    
    add     w21, w21, #1
    b       pop_entity_update_loop
    
update_pop_entities_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// Helper functions for population simulation
//

// create_newborn_citizen - Create a new citizen entity for birth
create_newborn_citizen:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Create new entity
    bl      ecs_create_entity
    cbz     x0, create_newborn_done
    mov     x19, x0                 // entity_id
    
    // Add population component
    mov     x0, x19
    mov     x1, #COMPONENT_POPULATION
    mov     x2, #0                  // Will initialize component
    bl      ecs_add_component
    cbz     x0, create_newborn_done
    mov     x20, x0                 // population_component
    
    // Initialize newborn data
    str     wzr, [x20, #PopulationComponent.current_residents]
    mov     w1, #1
    str     w1, [x20, #PopulationComponent.age_children]
    str     wzr, [x20, #PopulationComponent.age_adults]
    str     wzr, [x20, #PopulationComponent.age_seniors]
    
    // Set health and happiness
    mov     w1, #85                 // Newborns start healthy
    str     w1, [x20, #PopulationComponent.health_level]
    mov     w1, #90                 // High happiness for new families
    str     w1, [x20, #PopulationComponent.happiness_level]
    
    // Add position component (place in residential area)
    bl      find_suitable_residential_location
    mov     x1, x19                 // entity_id
    mov     x2, x0                  // location_x
    mov     x3, x1                  // location_y
    bl      add_position_component_to_entity
    
create_newborn_done:
    ldp     x29, x30, [sp], #16
    ret

// calculate_immigration_attractiveness - Calculate city appeal for immigrants
calculate_immigration_attractiveness:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    fmov    s0, #1.0                // Base attractiveness
    
    // Get economic indicators
    adrp    x1, economic_market
    add     x1, x1, :lo12:economic_market
    ldr     w2, [x1, #EconomicMarket.job_openings]
    ldr     w3, [x1, #EconomicMarket.available_workers]
    
    // Job availability factor
    cbz     w3, jobs_factor_done
    scvtf   s1, w2                  // job_openings
    scvtf   s2, w3                  // available_workers
    fdiv    s3, s1, s2              // job_ratio
    fmov    s4, #0.2                // Weight for jobs
    fmul    s5, s3, s4
    fadd    s0, s0, s5              // Add to attractiveness
    
jobs_factor_done:
    // Add other factors: cost of living, crime rate, services, etc.
    // TODO: Integrate with other city systems
    
    // Cap attractiveness between 0.1 and 3.0
    fmov    s6, #0.1
    fmov    s7, #3.0
    fmax    s0, s0, s6
    fmin    s0, s0, s7
    
    ldp     x29, x30, [sp], #16
    ret

// initialize_starting_demographics - Set up initial population distribution
initialize_starting_demographics:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, population_stats
    add     x0, x0, :lo12:population_stats
    
    // Set starting population
    str     w19, [x0, #PopulationStatistics.total_population]
    
    // Age distribution (typical city demographics)
    mov     w1, #22                 // 22% children (0-17)
    mul     w2, w19, w1
    mov     w3, #100
    udiv    w2, w2, w3
    str     w2, [x0, #PopulationStatistics.population_0_17]
    
    mov     w1, #28                 // 28% young adults (18-34)
    mul     w2, w19, w1
    udiv    w2, w2, w3
    str     w2, [x0, #PopulationStatistics.population_18_34]
    
    mov     w1, #30                 // 30% middle-aged (35-54)
    mul     w2, w19, w1
    udiv    w2, w2, w3
    str     w2, [x0, #PopulationStatistics.population_35_54]
    
    mov     w1, #15                 // 15% older adults (55-74)
    mul     w2, w19, w1
    udiv    w2, w2, w3
    str     w2, [x0, #PopulationStatistics.population_55_74]
    
    mov     w1, #5                  // 5% seniors (75+)
    mul     w2, w19, w1
    udiv    w2, w2, w3
    str     w2, [x0, #PopulationStatistics.population_75_plus]
    
    // Income distribution (25% low, 50% middle, 25% high)
    mov     w1, #25
    mul     w2, w19, w1
    udiv    w2, w2, w3
    str     w2, [x0, #PopulationStatistics.low_income_pop]
    
    mov     w1, #50
    mul     w2, w19, w1
    udiv    w2, w2, w3
    str     w2, [x0, #PopulationStatistics.middle_income_pop]
    
    mov     w1, #25
    mul     w2, w19, w1
    udiv    w2, w2, w3
    str     w2, [x0, #PopulationStatistics.high_income_pop]
    
    // Set demographic rates
    fmov    s1, #12.5               // 12.5 births per 1000 per year
    str     s1, [x0, #PopulationStatistics.birth_rate]
    fmov    s1, #8.0                // 8.0 deaths per 1000 per year
    str     s1, [x0, #PopulationStatistics.death_rate]
    fmov    s1, #5.0                // 5.0 net migration per 1000 per year
    str     s1, [x0, #PopulationStatistics.migration_rate]
    
    ldp     x29, x30, [sp], #16
    ret

// External function declarations
.extern memset
.extern register_ecs_system
.extern query_entities_with_component
.extern ecs_create_entity
.extern ecs_add_component
.extern ecs_destroy_entity
.extern get_random_float_01