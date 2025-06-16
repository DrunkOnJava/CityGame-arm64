//
// SimCity ARM64 Assembly - ECS Component Definitions
// Agent 2: Simulation Systems Developer
//
// Defines all component types used in the SimCity simulation
// Includes position, building, economic, population, and utility components
//

.include "ecs_core.s"

.text
.align 4

// Component Structures

.struct PositionComponent
    world_x             .word       // World X coordinate (tile units)
    world_y             .word       // World Y coordinate (tile units)
    local_x             .float      // Sub-tile X offset (0.0-1.0)
    local_y             .float      // Sub-tile Y offset (0.0-1.0)
    elevation           .float      // Elevation above sea level
    orientation         .word       // Rotation in degrees (0-359)
    _padding            .space 8    // Alignment padding
.endstruct

.struct BuildingComponent
    building_type       .word       // Building type ID
    construction_level  .word       // 0-100 (construction progress)
    health              .word       // 0-100 (building condition)
    upgrade_level       .word       // 0-10 (upgrade tier)
    construction_date   .quad       // Game time when built
    last_maintenance    .quad       // Last maintenance date
    capacity_current    .word       // Current occupancy/usage
    capacity_maximum    .word       // Maximum capacity
    efficiency_rating   .word       // 0-100 operational efficiency
    power_connected     .word       // 1 if connected to power grid
    water_connected     .word       // 1 if connected to water
    road_connected      .word       // 1 if connected to road network
    _padding            .space 4    // Alignment
.endstruct

.struct EconomicComponent
    construction_cost   .word       // Initial build cost
    monthly_maintenance .word       // Monthly upkeep cost
    monthly_revenue     .word       // Monthly income generated
    property_value      .word       // Current property value
    tax_rate            .word       // Tax rate percentage (0-100)
    economic_multiplier .word       // Effect on surrounding economy
    land_value_bonus    .word       // Bonus to surrounding land values
    employment_provided .word       // Jobs provided by this building
    employment_required .word       // Workers needed to operate
    resource_consumption .word      // Monthly resource usage
    utility_costs       .word       // Monthly utility expenses
    insurance_cost      .word       // Monthly insurance/safety costs
    depreciation_rate   .word       // Annual value loss percentage
    _padding            .space 4    // Alignment
.endstruct

.struct PopulationComponent
    residential_capacity .word      // Maximum residents
    current_residents   .word       // Current population
    income_low          .word       // Low-income residents
    income_medium       .word       // Medium-income residents  
    income_high         .word       // High-income residents
    age_children        .word       // Population under 18
    age_adults          .word       // Population 18-65
    age_seniors         .word       // Population over 65
    education_level     .word       // Average education (0-100)
    happiness_level     .word       // Average happiness (0-100)
    health_level        .word       // Average health (0-100)
    crime_exposure      .word       // Crime risk level (0-100)
    pollution_exposure  .word       // Pollution exposure (0-100)
    noise_level         .word       // Noise pollution (0-100)
    _padding            .space 8    // Alignment
.endstruct

.struct TransportComponent
    transport_type      .word       // Type of transport infrastructure
    capacity_per_hour   .word       // Throughput capacity
    current_usage       .word       // Current usage level (0-100)
    connection_north    .word       // Connected to north (entity ID or 0)
    connection_south    .word       // Connected to south
    connection_east     .word       // Connected to east  
    connection_west     .word       // Connected to west
    traffic_flow_ns     .word       // North-South traffic flow
    traffic_flow_ew     .word       // East-West traffic flow
    congestion_level    .word       // Traffic congestion (0-100)
    maintenance_needed  .word       // 1 if needs maintenance
    last_upgrade        .quad       // Date of last upgrade
    speed_limit         .word       // Speed limit (km/h)
    accident_count      .word       // Accidents this month
    _padding            .space 4    // Alignment
.endstruct

.struct UtilityComponent
    utility_type        .word       // Power, water, waste, etc.
    generation_capacity .word       // How much utility generated
    consumption_rate    .word       // How much utility consumed
    storage_capacity    .word       // Storage buffer size
    current_storage     .word       // Current stored amount
    efficiency_rating   .word       // Generation efficiency (0-100)
    fuel_type           .word       // Energy source type
    pollution_output    .word       // Pollution generated per hour
    maintenance_cost    .word       // Monthly maintenance expense
    fuel_cost_per_unit  .word       // Operating cost per unit
    grid_connections    .space 32   // Connected grid nodes (8 * 4 bytes)
    last_inspection     .quad       // Last safety inspection date
    safety_rating       .word       // Safety compliance (0-100)
    _padding            .space 4    // Alignment
.endstruct

.struct ZoneComponent
    zone_type           .word       // Residential, Commercial, Industrial
    zone_density        .word       // Low, Medium, High density
    development_level   .word       // How built-up the zone is (0-100)
    desirability        .word       // How attractive for development
    land_value          .word       // Current land value per sq unit  
    pollution_level     .word       // Environmental pollution (0-100)
    noise_level         .word       // Noise pollution (0-100)
    crime_rate          .word       // Crime incidents per month
    fire_risk           .word       // Fire hazard level (0-100)
    flood_risk          .word       // Flood risk level (0-100)
    soil_quality        .word       // Agricultural/foundation quality
    natural_resources   .word       // Available resources bitmask
    zoning_restrictions .word       // Legal building restrictions
    historical_value    .word       // Cultural/historical significance
    _padding            .space 8    // Alignment
.endstruct

.struct RenderComponent
    sprite_id           .word       // Sprite/model to render
    animation_state     .word       // Current animation frame
    render_layer        .word       // Rendering depth layer
    visibility_flags    .word       // When this should be visible
    tint_color          .word       // Color modification (RGBA)
    scale_x             .float      // X scale factor
    scale_y             .float      // Y scale factor
    rotation            .float      // Rotation in radians
    alpha               .float      // Transparency (0.0-1.0)
    last_render_tick    .quad       // Last frame rendered
    animation_speed     .float      // Animation playback speed
    lighting_affected   .word       // 1 if affected by lighting
    shadow_casting      .word       // 1 if casts shadows
    _padding            .space 4    // Alignment
.endstruct

.struct AgentComponent
    agent_type          .word       // Citizen, Vehicle, Service, etc.
    behavior_state      .word       // Current AI behavior state
    destination_x       .word       // Target world X coordinate
    destination_y       .word       // Target world Y coordinate
    movement_speed      .float      // Units per second
    path_index          .word       // Current position in path
    path_length         .word       // Total path waypoints
    path_data           .quad       // Pointer to path waypoint array
    schedule_data       .quad       // Pointer to daily schedule
    needs_food          .word       // Hunger level (0-100)
    needs_work          .word       // Employment need (0-100)  
    needs_entertainment .word       // Fun need (0-100)
    needs_healthcare    .word       // Health need (0-100)
    current_activity    .word       // What agent is doing now
    home_building       .word       // Home building entity ID
    work_building       .word       // Work building entity ID
    _padding            .space 4    // Alignment
.endstruct

.struct EnvironmentComponent
    temperature         .float      // Current temperature (Celsius)
    humidity            .float      // Humidity percentage (0-100)
    wind_speed          .float      // Wind speed (m/s)
    wind_direction      .word       // Wind direction (degrees)
    air_quality         .word       // Air quality index (0-500)
    water_quality       .word       // Water quality index (0-100)
    soil_contamination  .word       // Soil pollution level (0-100)
    noise_pollution     .word       // Ambient noise level (dB)
    light_pollution     .word       // Light pollution intensity
    radiation_level     .word       // Background radiation
    pollen_count        .word       // Allergen levels
    uv_index            .word       // UV radiation strength
    weather_conditions  .word       // Current weather bitmask
    seasonal_modifier   .float      // Seasonal environmental factor
    _padding            .space 8    // Alignment
.endstruct

.struct TimeBasedComponent
    creation_time       .quad       // When entity was created
    update_interval     .word       // How often to update (ticks)
    last_update_tick    .quad       // Last update tick
    lifespan_remaining  .word       // Time until expiration (-1 = infinite)
    decay_rate          .float      // Rate of degradation per day
    seasonal_active     .word       // Which seasons this is active
    time_of_day_active  .word       // Which hours this is active
    growth_rate         .float      // Growth/expansion rate
    maturity_level      .word       // Development stage (0-100)
    cycles_completed    .word       // Number of full cycles done
    next_event_time     .quad       // When next scripted event occurs
    time_acceleration   .float      // Local time speed multiplier
    _padding            .space 4    // Alignment
.endstruct

.struct ResourceComponent
    resource_type       .word       // Type of resource (power, water, etc.)
    quantity_current    .word       // Current amount stored
    quantity_maximum    .word       // Storage capacity
    production_rate     .word       // Units produced per hour
    consumption_rate    .word       // Units consumed per hour
    quality_level       .word       // Resource quality (0-100)
    source_building     .word       // Where this resource comes from
    distribution_range  .word       // How far resource can travel
    transport_cost      .word       // Cost per unit to transport
    spoilage_rate       .float      // Decay rate per day
    market_price        .word       // Current market value per unit
    reserve_amount      .word       // Emergency reserve quantity
    import_cost         .word       // Cost to import externally
    export_value        .word       // Value when exported
    _padding            .space 8    // Alignment
.endstruct

.struct ServiceComponent
    service_type        .word       // Healthcare, Education, Safety, etc.
    service_level       .word       // Quality of service (0-100)
    coverage_radius     .word       // Service area in tiles
    current_demand      .word       // How much service is needed
    capacity_available  .word       // How much service can be provided
    staff_count         .word       // Number of employees
    staff_required      .word       // Minimum staff needed
    equipment_level     .word       // Quality of equipment (0-100)
    funding_level       .word       // Budget allocation (0-100)
    response_time       .word       // Average response time (minutes)
    success_rate        .word       // Service effectiveness (0-100)
    citizen_satisfaction .word      // User satisfaction rating
    operating_hours     .word       // Hours per day in operation
    emergency_capacity  .word       // Extra capacity for emergencies
    _padding            .space 8    // Alignment
.endstruct

.struct InfrastructureComponent
    infrastructure_type .word       // Roads, Pipes, Cables, etc.
    condition_rating    .word       // Physical condition (0-100)
    load_capacity       .word       // Maximum load/throughput
    current_load        .word       // Current usage level
    material_type       .word       // Construction material
    construction_date   .quad       // When built
    expected_lifespan   .word       // Years until replacement needed
    maintenance_due     .word       // Days until next maintenance
    repair_cost         .word       // Cost of next repair
    upgrade_cost        .word       // Cost to upgrade
    weather_resistance  .word       // Durability rating (0-100)
    seismic_rating      .word       // Earthquake resistance
    flood_protection    .word       // Flood resistance level
    fire_resistance     .word       // Fire protection rating
    _padding            .space 8    // Alignment
.endstruct

.struct ClimateComponent
    base_temperature    .float      // Baseline temperature for area
    temperature_variance .float     // Daily temperature range
    precipitation_rate  .float      // Average rainfall (mm/day)
    humidity_base       .float      // Base humidity level
    seasonal_variation  .float      // How much seasons affect climate
    microclimate_type   .word       // Urban heat island, etc.
    vegetation_density  .word       // Plant coverage (0-100)
    water_nearby        .word       // Distance to water body
    elevation_effect    .float      // Temperature change due to altitude
    prevailing_winds    .word       // Dominant wind direction
    storm_frequency     .word       // Severe weather events per year
    drought_risk        .word       // Likelihood of drought (0-100)
    extreme_weather_risk .word      // Risk of hurricanes, etc.
    _padding            .space 12   // Alignment
.endstruct

.struct TrafficComponent
    vehicle_count       .word       // Current vehicles on this tile
    max_vehicle_capacity .word      // Maximum vehicles that can fit
    average_speed       .float      // Current average vehicle speed
    congestion_level    .word       // Traffic density (0-100)
    accident_probability .float     // Chance of accident per hour
    pollution_generated .word       // Vehicle emissions per hour
    noise_generated     .word       // Traffic noise level (dB)
    pedestrian_count    .word       // People walking through
    bicycle_count       .word       // Cyclists using this area
    public_transport_usage .word    // Bus/train passengers per hour
    parking_available   .word       // Available parking spaces
    traffic_light_cycle .word       // Traffic signal timing (seconds)
    emergency_access    .word       // 1 if emergency vehicles can use
    construction_delay  .word       // Extra time due to construction
    _padding            .space 8    // Alignment
.endstruct

// Component Registration Functions
.section .text

//
// register_core_components - Register all core component types
//
// Returns:
//   x0 = 0 on success, error code on failure
//
.global register_core_components
register_core_components:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Register PositionComponent
    mov     x0, #COMPONENT_POSITION
    mov     x1, #PositionComponent_size
    mov     x2, #8                  // 8-byte alignment
    adrp    x3, position_component_name
    add     x3, x3, :lo12:position_component_name
    mov     x4, #0                  // No constructor
    mov     x5, #0                  // No destructor
    bl      register_component_type
    cmp     x0, #0
    b.ne    register_components_error
    
    // Register BuildingComponent
    mov     x0, #COMPONENT_BUILDING
    mov     x1, #BuildingComponent_size
    mov     x2, #8
    adrp    x3, building_component_name
    add     x3, x3, :lo12:building_component_name
    mov     x4, #0
    mov     x5, #0
    bl      register_component_type
    cmp     x0, #0
    b.ne    register_components_error
    
    // Register EconomicComponent
    mov     x0, #COMPONENT_ECONOMIC
    mov     x1, #EconomicComponent_size
    mov     x2, #4
    adrp    x3, economic_component_name
    add     x3, x3, :lo12:economic_component_name
    mov     x4, #0
    mov     x5, #0
    bl      register_component_type
    cmp     x0, #0
    b.ne    register_components_error
    
    // Register PopulationComponent
    mov     x0, #COMPONENT_POPULATION
    mov     x1, #PopulationComponent_size
    mov     x2, #8
    adrp    x3, population_component_name
    add     x3, x3, :lo12:population_component_name
    mov     x4, #0
    mov     x5, #0
    bl      register_component_type
    cmp     x0, #0
    b.ne    register_components_error
    
    // Continue registering other components...
    // (Similar pattern for all component types)
    
    mov     x0, #0                  // Success
    b       register_components_done
    
register_components_error:
    mov     x0, #-1                 // Error
    
register_components_done:
    ldp     x29, x30, [sp], #16
    ret

//
// Component factory functions for creating and initializing components
//

// create_position_component - Create a position component with default values
// Parameters: x0 = world_x, x1 = world_y
// Returns: x0 = component data pointer
.global create_position_component
create_position_component:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                 // world_x
    mov     x20, x1                 // world_y
    
    // Allocate component memory
    mov     x0, #PositionComponent_size
    bl      slab_alloc
    cbz     x0, create_position_error
    mov     x21, x0                 // component_ptr
    
    // Initialize component data
    str     w19, [x21, #PositionComponent.world_x]
    str     w20, [x21, #PositionComponent.world_y]
    fmov    s0, #0.0
    str     s0, [x21, #PositionComponent.local_x]
    str     s0, [x21, #PositionComponent.local_y]
    str     s0, [x21, #PositionComponent.elevation]
    str     wzr, [x21, #PositionComponent.orientation]
    
    mov     x0, x21                 // Return component pointer
    b       create_position_done
    
create_position_error:
    mov     x0, #0                  // Return NULL on error
    
create_position_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// create_building_component - Create a building component
// Parameters: w0 = building_type
// Returns: x0 = component data pointer
.global create_building_component
create_building_component:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     w19, w0                 // building_type
    
    // Allocate component memory
    mov     x0, #BuildingComponent_size
    bl      slab_alloc
    cbz     x0, create_building_error
    mov     x20, x0                 // component_ptr
    
    // Initialize component data
    str     w19, [x20, #BuildingComponent.building_type]
    str     wzr, [x20, #BuildingComponent.construction_level]
    mov     w1, #100
    str     w1, [x20, #BuildingComponent.health]
    str     wzr, [x20, #BuildingComponent.upgrade_level]
    
    // Get current game time for construction date
    bl      time_system_get_current_tick
    str     x0, [x20, #BuildingComponent.construction_date]
    str     x0, [x20, #BuildingComponent.last_maintenance]
    
    // Set default capacities and connections
    str     wzr, [x20, #BuildingComponent.capacity_current]
    mov     w1, #100               // Default capacity
    str     w1, [x20, #BuildingComponent.capacity_maximum]
    mov     w1, #80                // Default efficiency
    str     w1, [x20, #BuildingComponent.efficiency_rating]
    
    // Initially not connected to utilities
    str     wzr, [x20, #BuildingComponent.power_connected]
    str     wzr, [x20, #BuildingComponent.water_connected]
    str     wzr, [x20, #BuildingComponent.road_connected]
    
    mov     x0, x20                 // Return component pointer
    b       create_building_done
    
create_building_error:
    mov     x0, #0                  // Return NULL on error
    
create_building_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// Component name strings
.section .rodata
    .align 8
    
position_component_name:
    .asciz "PositionComponent"
    
building_component_name:
    .asciz "BuildingComponent"
    
economic_component_name:
    .asciz "EconomicComponent"
    
population_component_name:
    .asciz "PopulationComponent"
    
transport_component_name:
    .asciz "TransportComponent"
    
utility_component_name:
    .asciz "UtilityComponent"
    
zone_component_name:
    .asciz "ZoneComponent"
    
render_component_name:
    .asciz "RenderComponent"
    
agent_component_name:
    .asciz "AgentComponent"
    
environment_component_name:
    .asciz "EnvironmentComponent"
    
timebased_component_name:
    .asciz "TimeBasedComponent"
    
resource_component_name:
    .asciz "ResourceComponent"
    
service_component_name:
    .asciz "ServiceComponent"
    
infrastructure_component_name:
    .asciz "InfrastructureComponent"
    
climate_component_name:
    .asciz "ClimateComponent"
    
traffic_component_name:
    .asciz "TrafficComponent"

// External function declarations
.extern register_component_type
.extern slab_alloc
.extern time_system_get_current_tick