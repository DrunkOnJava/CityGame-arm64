//
// SimCity ARM64 Assembly - Economic ECS System
// Agent 2: Simulation Systems Developer
//
// Advanced economic simulation system implementing supply/demand dynamics,
// market forces, and complex economic modeling using the ECS framework
//

.include "ecs_core.s"
.include "ecs_components.s"
.include "../economy/economic_constants.s"

.text
.align 4

// Economic System Structures

.struct EconomicMarket
    // Market categories
    residential_demand  .word       // Housing demand level (0-1000)
    commercial_demand   .word       // Business space demand
    industrial_demand   .word       // Industrial space demand
    
    // Resource markets
    power_price         .float      // Current power price per unit
    water_price         .float      // Current water price per unit
    waste_price         .float      // Waste disposal cost per unit
    
    // Labor market
    available_workers   .word       // Unemployed population
    job_openings        .word       // Available job positions
    average_salary      .word       // Average monthly salary
    skill_shortage      .word       // Bitmask of skill shortages
    
    // Housing market
    housing_prices      .space 16   // Prices by income level (4 levels)
    rent_prices         .space 16   // Rent by income level
    vacancy_rate        .float      // Percentage of empty housing
    
    // Commercial market
    retail_revenue      .word       // Monthly retail sales
    office_revenue      .word       // Office space revenue
    tourism_revenue     .word       // Tourism income
    consumer_spending   .word       // Average consumer spending
    
    // Industrial market
    manufacturing_output .word      // Industrial production
    export_value        .word       // Goods exported
    import_cost         .word       // Goods imported
    productivity_index  .float      // Industrial efficiency
    
    // Market dynamics
    inflation_rate      .float      // Monthly inflation percentage
    growth_rate         .float      // Economic growth rate
    recession_risk      .float      // Probability of economic downturn
    confidence_index    .float      // Business confidence (0.0-1.0)
    
    // External factors
    regional_economy    .float      // External economic influence
    government_spending .word       // Public sector investment
    interest_rates      .float      // Borrowing costs
    tax_efficiency      .float      // Tax collection efficiency
    
    _padding            .space 32   // Cache alignment
.endstruct

.struct SupplyDemandTracker
    commodity_type      .word       // What commodity this tracks
    local_supply        .word       // Available supply in city
    local_demand        .word       // Current demand in city
    import_supply       .word       // Available from imports
    export_demand       .word       // External demand for exports
    
    base_price          .float      // Baseline price per unit
    current_price       .float      // Current market price
    price_volatility    .float      // How much prices fluctuate
    
    supply_trend        .float      // Supply growth/decline trend
    demand_trend        .float      // Demand growth/decline trend
    
    seasonal_factor     .float      // Seasonal demand multiplier
    weather_factor      .float      // Weather impact on supply/demand
    
    stockpile_amount    .word       // Reserved/stored amount
    stockpile_target    .word       // Target stockpile level
    
    last_shortage_day   .word       // When last shortage occurred
    shortage_severity   .word       // How severe shortages get (0-100)
    
    _padding            .space 16   // Alignment
.endstruct

.struct BusinessCycle
    cycle_phase         .word       // Current economic cycle phase
    phase_duration      .word       // How long in current phase (days)
    phase_strength      .float      // Intensity of current phase
    
    expansion_factors   .space 32   // What drives economic growth
    recession_factors   .space 32   // What causes downturns
    
    boom_threshold      .float      // Growth rate for boom phase
    recession_threshold .float      // Decline rate for recession
    
    external_shocks     .word       // Recent external economic events
    policy_effects      .word       // Impact of city policies
    
    recovery_speed      .float      // How fast economy recovers
    volatility_index    .float      // Economic stability measure
    
    _padding            .space 16   // Alignment
.endstruct

// Global economic system state
.section .bss
    .align 8
    economic_market:        .space EconomicMarket_size
    supply_demand_trackers: .space (SupplyDemandTracker_size * 32)
    business_cycle:         .space BusinessCycle_size
    
    // Economic entity tracking
    economic_entities:      .space (8 * 10000)  // Entity IDs with economic components
    economic_entity_count:  .word
    
    // Market calculation workspace
    market_calculations:    .space 1024
    price_history:          .space (4 * 365 * 10)  // 10 years of daily prices

.section .text

//
// economic_system_init - Initialize the economic simulation system
//
// Parameters:
//   x0 = starting_population
//   x1 = starting_budget
//
// Returns:
//   x0 = 0 on success, error code on failure
//
.global economic_system_init
economic_system_init:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                 // starting_population
    mov     x20, x1                 // starting_budget
    
    // Clear economic structures
    adrp    x0, economic_market
    add     x0, x0, :lo12:economic_market
    mov     x1, #EconomicMarket_size
    bl      memset
    
    adrp    x0, supply_demand_trackers
    add     x0, x0, :lo12:supply_demand_trackers
    mov     x1, #(SupplyDemandTracker_size * 32)
    bl      memset
    
    adrp    x0, business_cycle
    add     x0, x0, :lo12:business_cycle
    mov     x1, #BusinessCycle_size
    bl      memset
    
    // Initialize market with starting values
    bl      initialize_starting_market
    
    // Initialize supply/demand trackers for core commodities
    bl      initialize_commodity_trackers
    
    // Initialize business cycle
    bl      initialize_business_cycle
    
    // Register economic system with ECS
    mov     x0, #SYSTEM_ECONOMIC
    mov     x1, #1                  // Priority 1 (high priority)
    mov     x2, #1                  // Enabled
    mov     x3, #0                  // Update every frame
    adrp    x4, economic_system_update
    add     x4, x4, :lo12:economic_system_update
    bl      register_ecs_system
    
    mov     x0, #0                  // Success
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// economic_system_update - Main economic system update function
//
// Parameters:
//   x0 = current_tick
//   d0 = delta_time
//   x2 = ecs_world_ptr
//
.global economic_system_update
economic_system_update:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    mov     x19, x0                 // current_tick
    fmov    s20, s0                 // delta_time
    mov     x21, x2                 // ecs_world_ptr
    
    // Update market prices based on supply and demand
    bl      update_market_prices
    
    // Calculate economic effects on entities
    bl      update_economic_entities
    
    // Update business cycle
    bl      update_business_cycle
    
    // Process economic transactions
    bl      process_economic_transactions
    
    // Update employment and labor market
    bl      update_labor_market
    
    // Calculate city-wide economic statistics
    bl      calculate_economic_statistics
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// update_market_prices - Update commodity and service prices
//
update_market_prices:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    adrp    x19, supply_demand_trackers
    add     x19, x19, :lo12:supply_demand_trackers
    
    // Iterate through all commodity trackers
    mov     w20, #0                 // tracker_index
    
price_update_loop:
    cmp     w20, #32               // Max trackers
    b.ge    price_update_done
    
    // Get tracker pointer
    mov     x0, #SupplyDemandTracker_size
    mul     x0, x20, x0
    add     x21, x19, x0            // tracker_ptr
    
    // Check if tracker is active
    ldr     w0, [x21, #SupplyDemandTracker.commodity_type]
    cbz     w0, next_tracker
    
    // Calculate supply/demand ratio
    ldr     w1, [x21, #SupplyDemandTracker.local_supply]
    ldr     w2, [x21, #SupplyDemandTracker.import_supply]
    add     w1, w1, w2              // total_supply
    
    ldr     w2, [x21, #SupplyDemandTracker.local_demand]
    cbz     w2, next_tracker        // Avoid division by zero
    
    // Calculate price adjustment
    scvtf   s0, w1                  // total_supply to float
    scvtf   s1, w2                  // local_demand to float
    fdiv    s2, s0, s1              // supply_demand_ratio
    
    // Ideal ratio is 1.0, adjust price based on deviation
    fmov    s3, #1.0
    fsub    s4, s2, s3              // ratio_deviation
    
    // Price adjustment: -10% to +50% based on supply shortage
    fmov    s5, #-0.1               // Max price decrease
    fmov    s6, #0.5                // Max price increase
    
    fcmp    s4, #0.0
    b.lt    oversupply
    
    // Undersupply: increase price
    fmul    s7, s4, s6              // positive adjustment
    b       apply_price_change
    
oversupply:
    // Oversupply: decrease price
    fmul    s7, s4, s5              // negative adjustment
    
apply_price_change:
    // Apply price change with volatility factor
    ldr     s8, [x21, #SupplyDemandTracker.current_price]
    ldr     s9, [x21, #SupplyDemandTracker.price_volatility]
    fmul    s7, s7, s9              // Scale by volatility
    fmul    s10, s8, s7             // price_delta = current_price * adjustment
    fadd    s8, s8, s10             // new_price = current_price + delta
    
    // Ensure price doesn't go below 10% of base price
    ldr     s11, [x21, #SupplyDemandTracker.base_price]
    fmov    s12, #0.1
    fmul    s13, s11, s12           // min_price = base_price * 0.1
    fcmp    s8, s13
    fcsel   s8, s8, s13, ge         // max(new_price, min_price)
    
    // Store updated price
    str     s8, [x21, #SupplyDemandTracker.current_price]
    
next_tracker:
    add     w20, w20, #1
    b       price_update_loop
    
price_update_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// update_economic_entities - Update all entities with economic components
//
update_economic_entities:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    // Query ECS for all entities with EconomicComponent
    mov     x0, #COMPONENT_ECONOMIC
    bl      query_entities_with_component
    mov     x19, x0                 // entity_list
    mov     x20, x1                 // entity_count
    
    cbz     x19, update_entities_done
    
    mov     w21, #0                 // entity_index
    
entity_update_loop:
    cmp     w21, w20
    b.ge    update_entities_done
    
    // Get entity ID
    ldr     x22, [x19, x21, lsl #3] // entity_id
    
    // Update economic factors for this entity
    mov     x0, x22
    bl      update_entity_economics
    
    add     w21, w21, #1
    b       entity_update_loop
    
update_entities_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// update_entity_economics - Update economic factors for a single entity
//
// Parameters:
//   x0 = entity_id
//
update_entity_economics:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    mov     x19, x0                 // entity_id
    
    // Get economic component
    mov     x0, x19
    mov     x1, #COMPONENT_ECONOMIC
    bl      ecs_get_component
    cbz     x0, update_entity_done
    mov     x20, x0                 // economic_component
    
    // Get building component if present
    mov     x0, x19
    mov     x1, #COMPONENT_BUILDING
    bl      ecs_get_component
    mov     x21, x0                 // building_component (may be NULL)
    
    // Get population component if present
    mov     x0, x19
    mov     x1, #COMPONENT_POPULATION
    bl      ecs_get_component
    mov     x22, x0                 // population_component (may be NULL)
    
    // Update property value based on market conditions
    bl      calculate_property_value
    str     w0, [x20, #EconomicComponent.property_value]
    
    // Update revenue based on building type and market
    cbnz    x21, calculate_building_revenue
    cbnz    x22, calculate_population_revenue
    b       update_maintenance_costs
    
calculate_building_revenue:
    mov     x0, x21                 // building_component
    mov     x1, x20                 // economic_component
    bl      calculate_building_economic_output
    b       update_maintenance_costs
    
calculate_population_revenue:
    mov     x0, x22                 // population_component
    mov     x1, x20                 // economic_component
    bl      calculate_population_economic_output
    
update_maintenance_costs:
    // Update maintenance costs based on inflation
    ldr     w0, [x20, #EconomicComponent.monthly_maintenance]
    bl      apply_inflation_to_cost
    str     w0, [x20, #EconomicComponent.monthly_maintenance]
    
    // Update utility costs based on current prices
    bl      calculate_utility_costs
    str     w0, [x20, #EconomicComponent.utility_costs]
    
update_entity_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// calculate_building_economic_output - Calculate revenue for buildings
//
// Parameters:
//   x0 = building_component
//   x1 = economic_component
//
calculate_building_economic_output:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                 // building_component
    mov     x20, x1                 // economic_component
    
    // Get building type
    ldr     w21, [x19, #BuildingComponent.building_type]
    
    // Calculate base revenue for building type
    mov     x0, x21
    bl      get_base_building_revenue
    mov     w22, w0                 // base_revenue
    
    // Apply efficiency modifier
    ldr     w0, [x19, #BuildingComponent.efficiency_rating]
    scvtf   s0, w0                  // efficiency to float
    fmov    s1, #100.0
    fdiv    s0, s0, s1              // efficiency_factor (0.0-1.0)
    
    scvtf   s1, w22                 // base_revenue to float
    fmul    s2, s1, s0              // adjusted_revenue
    fcvtzs  w23, s2                 // back to integer
    
    // Apply market demand factor
    mov     x0, x21                 // building_type
    bl      get_market_demand_factor
    fmov    s3, s0                  // demand_factor
    
    scvtf   s4, w23                 // adjusted_revenue to float
    fmul    s5, s4, s3              // final_revenue
    fcvtzs  w24, s5                 // back to integer
    
    // Apply seasonal and economic cycle modifiers
    bl      get_economic_cycle_modifier
    fmov    s6, s0                  // cycle_modifier
    
    scvtf   s7, w24
    fmul    s8, s7, s6
    fcvtzs  w25, s8                 // final_adjusted_revenue
    
    // Store in economic component
    str     w25, [x20, #EconomicComponent.monthly_revenue]
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// update_business_cycle - Update the business cycle state
//
update_business_cycle:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, business_cycle
    add     x0, x0, :lo12:business_cycle
    
    // Increment phase duration
    ldr     w1, [x0, #BusinessCycle.phase_duration]
    add     w1, w1, #1
    str     w1, [x0, #BusinessCycle.phase_duration]
    
    // Check for phase transitions
    ldr     w2, [x0, #BusinessCycle.cycle_phase]
    
    cmp     w2, #0                  // Expansion phase
    b.eq    check_expansion_end
    cmp     w2, #1                  // Peak phase
    b.eq    check_peak_end
    cmp     w2, #2                  // Recession phase
    b.eq    check_recession_end
    cmp     w2, #3                  // Trough phase
    b.eq    check_trough_end
    b       business_cycle_done
    
check_expansion_end:
    // Check if expansion should end (move to peak)
    bl      calculate_economic_growth_rate
    ldr     s1, [x0, #BusinessCycle.boom_threshold]
    fcmp    s0, s1
    b.lt    business_cycle_done
    
    // Transition to peak
    mov     w1, #1
    str     w1, [x0, #BusinessCycle.cycle_phase]
    str     wzr, [x0, #BusinessCycle.phase_duration]
    b       business_cycle_done
    
check_peak_end:
    // Peaks last 30-90 days typically
    cmp     w1, #60                 // Average peak duration
    b.lt    business_cycle_done
    
    // Transition to recession
    mov     w2, #2
    str     w2, [x0, #BusinessCycle.cycle_phase]
    str     wzr, [x0, #BusinessCycle.phase_duration]
    b       business_cycle_done
    
check_recession_end:
    // Check if recession should end (move to trough)
    bl      calculate_economic_growth_rate
    ldr     s1, [x0, #BusinessCycle.recession_threshold]
    fcmp    s0, s1
    b.gt    business_cycle_done
    
    // Transition to trough
    mov     w2, #3
    str     w2, [x0, #BusinessCycle.cycle_phase]
    str     wzr, [x0, #BusinessCycle.phase_duration]
    b       business_cycle_done
    
check_trough_end:
    // Troughs last 60-180 days typically
    cmp     w1, #120                // Average trough duration
    b.lt    business_cycle_done
    
    // Transition to expansion
    str     wzr, [x0, #BusinessCycle.cycle_phase]
    str     wzr, [x0, #BusinessCycle.phase_duration]
    
business_cycle_done:
    ldp     x29, x30, [sp], #16
    ret

//
// Helper functions for economic calculations
//

// initialize_starting_market - Set up initial market conditions
initialize_starting_market:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, economic_market
    add     x0, x0, :lo12:economic_market
    
    // Set initial demand levels
    mov     w1, #500               // Medium demand
    str     w1, [x0, #EconomicMarket.residential_demand]
    str     w1, [x0, #EconomicMarket.commercial_demand]
    str     w1, [x0, #EconomicMarket.industrial_demand]
    
    // Set initial utility prices
    fmov    s1, #0.12              // $0.12 per kWh power
    str     s1, [x0, #EconomicMarket.power_price]
    fmov    s1, #0.08              // $0.08 per gallon water
    str     s1, [x0, #EconomicMarket.water_price]
    fmov    s1, #0.05              // $0.05 per pound waste
    str     s1, [x0, #EconomicMarket.waste_price]
    
    // Set initial labor market
    mov     w1, #1000              // 1000 available workers
    str     w1, [x0, #EconomicMarket.available_workers]
    mov     w1, #800               // 800 job openings
    str     w1, [x0, #EconomicMarket.job_openings]
    mov     w1, #3500              // $3500 average salary
    str     w1, [x0, #EconomicMarket.average_salary]
    
    // Set initial economic indicators
    fmov    s1, #0.02              // 2% inflation
    str     s1, [x0, #EconomicMarket.inflation_rate]
    fmov    s1, #0.03              // 3% growth
    str     s1, [x0, #EconomicMarket.growth_rate]
    fmov    s1, #0.75              // 75% confidence
    str     s1, [x0, #EconomicMarket.confidence_index]
    
    ldp     x29, x30, [sp], #16
    ret

// initialize_commodity_trackers - Set up supply/demand tracking
initialize_commodity_trackers:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Initialize trackers for core commodities
    // Power, Water, Food, Housing, etc.
    
    adrp    x0, supply_demand_trackers
    add     x0, x0, :lo12:supply_demand_trackers
    
    // Power tracker (index 0)
    mov     w1, #1                  // COMMODITY_POWER
    str     w1, [x0, #SupplyDemandTracker.commodity_type]
    mov     w1, #10000              // Initial supply
    str     w1, [x0, #SupplyDemandTracker.local_supply]
    mov     w1, #8000               // Initial demand
    str     w1, [x0, #SupplyDemandTracker.local_demand]
    fmov    s1, #0.12               // Base price
    str     s1, [x0, #SupplyDemandTracker.base_price]
    str     s1, [x0, #SupplyDemandTracker.current_price]
    
    // Continue for other commodities...
    
    ldp     x29, x30, [sp], #16
    ret

// initialize_business_cycle - Set up initial business cycle
initialize_business_cycle:
    adrp    x0, business_cycle
    add     x0, x0, :lo12:business_cycle
    
    // Start in expansion phase
    str     wzr, [x0, #BusinessCycle.cycle_phase]
    str     wzr, [x0, #BusinessCycle.phase_duration]
    fmov    s1, #1.0                // Normal strength
    str     s1, [x0, #BusinessCycle.phase_strength]
    
    // Set thresholds
    fmov    s1, #0.06               // 6% growth for boom
    str     s1, [x0, #BusinessCycle.boom_threshold]
    fmov    s1, #-0.02              // -2% growth for recession
    str     s1, [x0, #BusinessCycle.recession_threshold]
    
    ret

// External function declarations
.extern memset
.extern register_ecs_system
.extern query_entities_with_component
.extern ecs_get_component