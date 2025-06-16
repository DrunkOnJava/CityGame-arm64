//==============================================================================
// SimCity ARM64 Assembly - Water and Sewage System
// Agent 6: Infrastructure Networks
//==============================================================================
// Water distribution and sewage collection simulation
// Performance target: <5ms for network updates, support for 100k+ nodes
//==============================================================================

.text
.align 4

//==============================================================================
// Constants and Data Structures
//==============================================================================

// Pipe types
.equ PIPE_NONE,             0
.equ PIPE_WATER_MAIN,       1
.equ PIPE_WATER_SERVICE,    2
.equ PIPE_SEWAGE_MAIN,      3
.equ PIPE_SEWAGE_SERVICE,   4
.equ PIPE_STORM_DRAIN,      5

// Facility types
.equ FACILITY_WATER_TOWER,      0
.equ FACILITY_WATER_PLANT,      1
.equ FACILITY_PUMP_STATION,     2
.equ FACILITY_SEWAGE_PLANT,     3
.equ FACILITY_TREATMENT_PLANT,  4
.equ FACILITY_CONSUMER,         5

// Pipe diameters (in mm, affects capacity)
.equ PIPE_DIAMETER_SMALL,   150     // 6 inch
.equ PIPE_DIAMETER_MEDIUM,  300     // 12 inch
.equ PIPE_DIAMETER_LARGE,   600     // 24 inch
.equ PIPE_DIAMETER_MAIN,    1200    // 48 inch

// Water node structure (96 bytes, cache-aligned)
.struct 0
WaterNode_id:               .skip 4     // Unique node ID
WaterNode_type:             .skip 4     // Node type (plant, tower, consumer)
WaterNode_x:                .skip 4     // X coordinate
WaterNode_y:                .skip 4     // Y coordinate
WaterNode_elevation:        .skip 4     // Ground elevation (affects pressure)
WaterNode_capacity:         .skip 4     // Storage/production capacity (liters)
WaterNode_current_level:    .skip 4     // Current water level
WaterNode_pressure:         .skip 4     // Water pressure (kPa, fixed-point)
WaterNode_flow_rate:        .skip 4     // Current flow rate (L/min)
WaterNode_demand:           .skip 4     // Water demand (L/min)
WaterNode_connections:      .skip 4     // Number of pipe connections
WaterNode_pipe_list:        .skip 4     // Pointer to connected pipes
WaterNode_quality:          .skip 4     // Water quality index (0-100)
WaterNode_contamination:    .skip 4     // Contamination level
WaterNode_temperature:      .skip 4     // Water temperature (Celsius, fixed-point)
WaterNode_ph_level:         .skip 4     // pH level (fixed-point)
WaterNode_chlorine_level:   .skip 4     // Chlorine level (mg/L, fixed-point)
WaterNode_service_area:     .skip 4     // Service area radius
WaterNode_maintenance:      .skip 4     // Maintenance status
WaterNode_reserved:         .skip 16    // Reserved for future use
WaterNode_size = .

// Water pipe structure (64 bytes)
.struct 0
WaterPipe_id:               .skip 4     // Pipe ID
WaterPipe_from:             .skip 4     // Source node ID
WaterPipe_to:               .skip 4     // Destination node ID
WaterPipe_type:             .skip 4     // Pipe type (water/sewage)
WaterPipe_diameter:         .skip 4     // Pipe diameter (mm)
WaterPipe_length:           .skip 4     // Pipe length (meters)
WaterPipe_material:         .skip 4     // Pipe material (affects roughness)
WaterPipe_roughness:        .skip 4     // Surface roughness coefficient
WaterPipe_capacity:         .skip 4     // Max flow capacity (L/min)
WaterPipe_current_flow:     .skip 4     // Current flow rate (L/min)
WaterPipe_pressure_drop:    .skip 4     // Pressure drop across pipe
WaterPipe_age:              .skip 4     // Pipe age (affects deterioration)
WaterPipe_condition:        .skip 4     // Condition factor (1.0 = new)
WaterPipe_leakage_rate:     .skip 4     // Water leakage rate (L/min)
WaterPipe_blockage_factor:  .skip 4     // Blockage factor (0.0-1.0)
WaterPipe_reserved:         .skip 4     // Reserved
WaterPipe_size = .

// Water system structure
.struct 0
WaterSystem_nodes:          .skip 8     // Pointer to node array
WaterSystem_pipes:          .skip 8     // Pointer to pipe array
WaterSystem_node_count:     .skip 4     // Number of nodes
WaterSystem_pipe_count:     .skip 4     // Number of pipes
WaterSystem_capacity:       .skip 4     // Max nodes capacity
WaterSystem_total_supply:   .skip 4     // Total water supply capacity
WaterSystem_total_demand:   .skip 4     // Total water demand
WaterSystem_total_flow:     .skip 4     // Total system flow
WaterSystem_avg_pressure:   .skip 4     // Average system pressure
WaterSystem_min_pressure:   .skip 4     // Minimum system pressure
WaterSystem_max_pressure:   .skip 4     // Maximum system pressure
WaterSystem_leakage_total:  .skip 4     // Total system leakage
WaterSystem_quality_avg:    .skip 4     // Average water quality
WaterSystem_dirty:          .skip 4     // Update flag
WaterSystem_reserved:       .skip 12    // Reserved
WaterSystem_size = .

//==============================================================================
// Global Data
//==============================================================================

.data
.align 8

// Main water system instance
water_system:               .skip WaterSystem_size

// Physical constants (fixed-point 16.16)
gravity_accel:              .word 0x98000   // 9.8 m/s^2
water_density:              .word 0x3E800   // 1000 kg/m^3
atmospheric_pressure:       .word 0x1010000 // 101 kPa
pipe_friction_factor:       .word 0x0020    // 0.02 (Darcy-Weisbach)

// System parameters
min_service_pressure:       .word 0x1E0000  // 30 psi (207 kPa)
max_service_pressure:       .word 0x500000  // 80 psi (552 kPa)
water_quality_threshold:    .word 0x500000  // 80/100 quality threshold
contamination_spread_rate:  .word 0x0199    // 0.01 spread rate

// Performance counters
pressure_calc_cycles:       .quad 0
flow_calc_cycles:           .quad 0
quality_updates:            .quad 0

//==============================================================================
// Public Interface Functions
//==============================================================================

.global water_system_init
.global water_system_update
.global water_system_add_facility
.global water_system_add_consumer
.global water_system_add_pipe
.global water_system_calculate_pressure
.global water_system_calculate_flow
.global water_system_check_quality
.global water_system_detect_leaks
.global water_system_get_service_level
.global water_system_cleanup

//==============================================================================
// water_system_init - Initialize the water/sewage system
// Parameters: x0 = max_nodes, x1 = max_pipes
// Returns: x0 = success (1) or failure (0)
//==============================================================================
water_system_init:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // max_nodes
    mov     x20, x1                     // max_pipes
    
    // Validate parameters
    cmp     x19, #2
    b.lt    .water_init_error
    cmp     x20, #1
    b.lt    .water_init_error
    cmp     x19, #100000                // Max 100k nodes
    b.gt    .water_init_error
    
    // Allocate node array
    mov     x0, x19
    mov     x1, #WaterNode_size
    mul     x0, x0, x1
    bl      malloc
    cbz     x0, .water_init_error
    
    // Store node array pointer
    adrp    x1, water_system
    add     x1, x1, :lo12:water_system
    str     x0, [x1, #WaterSystem_nodes]
    
    // Allocate pipe array
    mov     x0, x20
    mov     x1, #WaterPipe_size
    mul     x0, x0, x1
    bl      malloc
    cbz     x0, .water_init_cleanup_nodes
    
    // Store pipe array pointer
    adrp    x1, water_system
    add     x1, x1, :lo12:water_system
    str     x0, [x1, #WaterSystem_pipes]
    
    // Initialize system structure
    str     wzr, [x1, #WaterSystem_node_count]
    str     wzr, [x1, #WaterSystem_pipe_count]
    str     w19, [x1, #WaterSystem_capacity]
    str     wzr, [x1, #WaterSystem_total_supply]
    str     wzr, [x1, #WaterSystem_total_demand]
    str     wzr, [x1, #WaterSystem_total_flow]
    
    // Set default pressure values
    adrp    x0, min_service_pressure
    add     x0, x0, :lo12:min_service_pressure
    ldr     w0, [x0]
    str     w0, [x1, #WaterSystem_min_pressure]
    
    adrp    x0, max_service_pressure
    add     x0, x0, :lo12:max_service_pressure
    ldr     w0, [x0]
    str     w0, [x1, #WaterSystem_max_pressure]
    str     w0, [x1, #WaterSystem_avg_pressure]
    
    // Initialize quality and leakage
    mov     w0, #0x640000               // 100 quality
    str     w0, [x1, #WaterSystem_quality_avg]
    str     wzr, [x1, #WaterSystem_leakage_total]
    str     wzr, [x1, #WaterSystem_dirty]
    
    // Success
    mov     x0, #1
    b       .water_init_exit
    
.water_init_cleanup_nodes:
    adrp    x1, water_system
    add     x1, x1, :lo12:water_system
    ldr     x0, [x1, #WaterSystem_nodes]
    bl      free
    
.water_init_error:
    mov     x0, #0
    
.water_init_exit:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// water_system_add_facility - Add water facility (plant, tower, pump station)
// Parameters: x0 = x_coord, x1 = y_coord, x2 = elevation, x3 = facility_type, 
//            x4 = capacity
// Returns: x0 = node_id (>=0) or error (-1)
//==============================================================================
water_system_add_facility:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    
    mov     x19, x0                     // x_coord
    mov     x20, x1                     // y_coord
    mov     x21, x2                     // elevation
    mov     x22, x3                     // facility_type
    mov     x23, x4                     // capacity
    
    // Get system structure
    adrp    x0, water_system
    add     x0, x0, :lo12:water_system
    
    // Check capacity
    ldr     w1, [x0, #WaterSystem_node_count]
    ldr     w2, [x0, #WaterSystem_capacity]
    cmp     w1, w2
    b.ge    .add_facility_error
    
    // Get node array and calculate offset
    ldr     x2, [x0, #WaterSystem_nodes]
    mov     x3, #WaterNode_size
    umull   x3, w1, w3
    add     x2, x2, x3                  // new node pointer
    
    // Initialize facility node
    str     w1, [x2, #WaterNode_id]
    str     w22, [x2, #WaterNode_type]
    str     w19, [x2, #WaterNode_x]
    str     w20, [x2, #WaterNode_y]
    str     w21, [x2, #WaterNode_elevation]
    str     w23, [x2, #WaterNode_capacity]
    
    // Set initial levels based on facility type
    cmp     w22, #FACILITY_WATER_TOWER
    b.ne    .facility_check_plant
    
    // Water tower - start at 80% capacity
    mov     w3, w23
    mov     w4, w23, lsr #2
    sub     w3, w3, w4                  // 75% capacity
    str     w3, [x2, #WaterNode_current_level]
    
    // Calculate pressure from elevation + water height
    bl      calculate_tower_pressure
    str     w0, [x2, #WaterNode_pressure]
    b       .facility_set_defaults
    
.facility_check_plant:
    cmp     w22, #FACILITY_WATER_PLANT
    b.ne    .facility_check_pump
    
    // Water plant - continuous production
    str     w23, [x2, #WaterNode_current_level]  // Full capacity
    mov     w3, #0x320000               // 50 psi base pressure
    str     w3, [x2, #WaterNode_pressure]
    str     w23, [x2, #WaterNode_flow_rate]      // Can produce at full capacity
    b       .facility_set_defaults

.facility_check_pump:
    cmp     w22, #FACILITY_PUMP_STATION
    b.ne    .facility_default
    
    // Pump station - boosts pressure
    str     wzr, [x2, #WaterNode_current_level]
    mov     w3, #0x4B0000               // 75 psi boost pressure
    str     w3, [x2, #WaterNode_pressure]
    mov     w3, w23, lsr #1             // 50% of capacity throughput
    str     w3, [x2, #WaterNode_flow_rate]
    b       .facility_set_defaults

.facility_default:
    // Default facility initialization
    str     wzr, [x2, #WaterNode_current_level]
    mov     w3, #0x320000               // 50 psi default
    str     w3, [x2, #WaterNode_pressure]
    str     wzr, [x2, #WaterNode_flow_rate]

.facility_set_defaults:
    // Set common defaults
    str     wzr, [x2, #WaterNode_demand]
    str     wzr, [x2, #WaterNode_connections]
    str     xzr, [x2, #WaterNode_pipe_list]
    
    // Set water quality parameters
    mov     w3, #0x640000               // 100% quality
    str     w3, [x2, #WaterNode_quality]
    str     wzr, [x2, #WaterNode_contamination]
    mov     w3, #0x140000               // 20°C temperature
    str     w3, [x2, #WaterNode_temperature]
    mov     w3, #0x70000                // pH 7.0
    str     w3, [x2, #WaterNode_ph_level]
    mov     w3, #0x20000                // 2.0 mg/L chlorine
    str     w3, [x2, #WaterNode_chlorine_level]
    
    // Set service area based on facility type
    cmp     w22, #FACILITY_WATER_TOWER
    mov     w3, #1000                   // 1km radius
    mov     w4, #2000                   // 2km for towers
    csel    w3, w4, w3, eq
    str     w3, [x2, #WaterNode_service_area]
    
    str     wzr, [x2, #WaterNode_maintenance]
    
    // Update system totals
    cmp     w22, #FACILITY_CONSUMER
    b.eq    .facility_update_demand
    
    // Update supply
    ldr     w3, [x0, #WaterSystem_total_supply]
    add     w3, w3, w23
    str     w3, [x0, #WaterSystem_total_supply]
    b       .facility_increment_count

.facility_update_demand:
    // Update demand for consumers
    ldr     w3, [x0, #WaterSystem_total_demand]
    add     w3, w3, w23
    str     w3, [x0, #WaterSystem_total_demand]

.facility_increment_count:
    // Increment node count
    add     w1, w1, #1
    str     w1, [x0, #WaterSystem_node_count]
    
    // Mark as dirty
    mov     w2, #1
    str     w2, [x0, #WaterSystem_dirty]
    
    // Return node ID
    sub     x0, x1, #1
    b       .add_facility_exit

.add_facility_error:
    mov     x0, #-1

.add_facility_exit:
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//==============================================================================
// water_system_add_pipe - Add water pipe between nodes
// Parameters: x0 = from_node_id, x1 = to_node_id, x2 = pipe_type, 
//            x3 = diameter, x4 = length
// Returns: x0 = success (1) or failure (0)
//==============================================================================
water_system_add_pipe:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    
    mov     x19, x0                     // from_node_id
    mov     x20, x1                     // to_node_id
    mov     x21, x2                     // pipe_type
    mov     x22, x3                     // diameter
    mov     x23, x4                     // length
    
    // Get system structure
    adrp    x0, water_system
    add     x0, x0, :lo12:water_system
    
    // Validate node IDs
    ldr     w1, [x0, #WaterSystem_node_count]
    cmp     w19, w1
    b.ge    .add_pipe_error
    cmp     w20, w1
    b.ge    .add_pipe_error
    
    // Check pipe capacity
    ldr     w1, [x0, #WaterSystem_pipe_count]
    // Assume max pipes = 4 * node_count
    ldr     w2, [x0, #WaterSystem_node_count]
    lsl     w2, w2, #2
    cmp     w1, w2
    b.ge    .add_pipe_error
    
    // Get pipe array and calculate offset
    ldr     x2, [x0, #WaterSystem_pipes]
    mov     x3, #WaterPipe_size
    umull   x3, w1, w3
    add     x2, x2, x3                  // new pipe pointer
    
    // Initialize pipe
    str     w1, [x2, #WaterPipe_id]
    str     w19, [x2, #WaterPipe_from]
    str     w20, [x2, #WaterPipe_to]
    str     w21, [x2, #WaterPipe_type]
    str     w22, [x2, #WaterPipe_diameter]
    str     w23, [x2, #WaterPipe_length]
    
    // Set material and roughness based on pipe type
    cmp     w21, #PIPE_WATER_MAIN
    b.ne    .pipe_check_service
    
    // Water main - cast iron
    mov     w3, #1                      // Cast iron
    str     w3, [x2, #WaterPipe_material]
    mov     w3, #0x0333                 // 0.02 roughness
    str     w3, [x2, #WaterPipe_roughness]
    b       .pipe_calculate_capacity

.pipe_check_service:
    cmp     w21, #PIPE_WATER_SERVICE
    b.ne    .pipe_check_sewage
    
    // Water service - PVC
    mov     w3, #2                      // PVC
    str     w3, [x2, #WaterPipe_material]
    mov     w3, #0x0199                 // 0.01 roughness
    str     w3, [x2, #WaterPipe_roughness]
    b       .pipe_calculate_capacity

.pipe_check_sewage:
    // Sewage pipes - concrete
    mov     w3, #3                      // Concrete
    str     w3, [x2, #WaterPipe_material]
    mov     w3, #0x0666                 // 0.04 roughness
    str     w3, [x2, #WaterPipe_roughness]

.pipe_calculate_capacity:
    // Calculate pipe capacity using Hazen-Williams equation
    // Q = C * A * R^0.63 * S^0.54 (simplified)
    // Capacity proportional to diameter^2.63
    mov     x0, x22                     // diameter
    bl      calculate_pipe_capacity
    str     w0, [x2, #WaterPipe_capacity]
    
    // Initialize operational parameters
    str     wzr, [x2, #WaterPipe_current_flow]
    str     wzr, [x2, #WaterPipe_pressure_drop]
    str     wzr, [x2, #WaterPipe_age]
    mov     w3, #0x10000                // 1.0 condition (new)
    str     w3, [x2, #WaterPipe_condition]
    str     wzr, [x2, #WaterPipe_leakage_rate]
    str     wzr, [x2, #WaterPipe_blockage_factor]
    
    // Increment pipe count
    adrp    x0, water_system
    add     x0, x0, :lo12:water_system
    ldr     w1, [x0, #WaterSystem_pipe_count]
    add     w1, w1, #1
    str     w1, [x0, #WaterSystem_pipe_count]
    
    // Mark as dirty
    mov     w1, #1
    str     w1, [x0, #WaterSystem_dirty]
    
    // Success
    mov     x0, #1
    b       .add_pipe_exit

.add_pipe_error:
    mov     x0, #0

.add_pipe_exit:
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//==============================================================================
// water_system_update - Main update function for water system
// Parameters: x0 = delta_time_ms
// Returns: x0 = processing_time_cycles
//==============================================================================
water_system_update:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save delta_time_ms
    
    // Start performance timer
    mrs     x20, cntvct_el0
    
    // Check if update needed
    adrp    x0, water_system
    add     x0, x0, :lo12:water_system
    ldr     w1, [x0, #WaterSystem_dirty]
    cbz     w1, .water_update_exit
    
    // Calculate pressure distribution
    bl      water_system_calculate_pressure
    
    // Calculate flow rates through pipes
    bl      water_system_calculate_flow
    
    // Update water quality
    bl      water_system_check_quality
    
    // Detect and track leaks
    bl      water_system_detect_leaks
    
    // Update system statistics
    bl      update_water_system_stats
    
    // Clear dirty flag
    adrp    x0, water_system
    add     x0, x0, :lo12:water_system
    str     wzr, [x0, #WaterSystem_dirty]

.water_update_exit:
    // Calculate elapsed cycles
    mrs     x21, cntvct_el0
    sub     x0, x21, x20
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// water_system_calculate_pressure - Calculate pressure throughout the network
// Uses elevation and flow to determine pressures at all nodes
// Parameters: None
// Returns: None
//==============================================================================
water_system_calculate_pressure:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Start pressure calculation timer
    mrs     x19, cntvct_el0
    
    // Get system structure
    adrp    x20, water_system
    add     x20, x20, :lo12:water_system
    
    ldr     x21, [x20, #WaterSystem_nodes]
    ldr     w22, [x20, #WaterSystem_node_count]
    
    // Iterate through all nodes
    mov     w0, #0                      // node index
    
.pressure_calc_loop:
    cmp     w0, w22
    b.ge    .pressure_calc_done
    
    // Get current node
    mov     x1, #WaterNode_size
    umull   x1, w0, x1
    add     x1, x21, x1                 // node pointer
    
    // Calculate pressure based on node type
    ldr     w2, [x1, #WaterNode_type]
    cmp     w2, #FACILITY_WATER_TOWER
    b.eq    .pressure_calc_tower
    cmp     w2, #FACILITY_WATER_PLANT
    b.eq    .pressure_calc_plant
    cmp     w2, #FACILITY_PUMP_STATION
    b.eq    .pressure_calc_pump
    
    // Consumer node - calculate from supply pressure minus losses
    mov     x0, x1                      // node pointer
    bl      calculate_consumer_pressure
    b       .pressure_next_node

.pressure_calc_tower:
    // Water tower pressure = elevation + water height
    mov     x0, x1
    bl      calculate_tower_pressure
    str     w0, [x1, #WaterNode_pressure]
    b       .pressure_next_node

.pressure_calc_plant:
    // Water plant maintains constant pressure
    mov     w2, #0x500000               // 80 psi
    str     w2, [x1, #WaterNode_pressure]
    b       .pressure_next_node

.pressure_calc_pump:
    // Pump station boosts incoming pressure
    mov     x0, x1
    bl      calculate_pump_pressure
    str     w0, [x1, #WaterNode_pressure]

.pressure_next_node:
    add     w0, w0, #1
    b       .pressure_calc_loop

.pressure_calc_done:
    // Update performance counter
    mrs     x1, cntvct_el0
    sub     x1, x1, x19
    adrp    x0, pressure_calc_cycles
    add     x0, x0, :lo12:pressure_calc_cycles
    ldr     x2, [x0]
    add     x2, x2, x1
    str     x2, [x0]
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// water_system_calculate_flow - Calculate flow rates through pipes
// Uses Darcy-Weisbach equation for pressure drop
// Parameters: None
// Returns: None
//==============================================================================
water_system_calculate_flow:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mrs     x19, cntvct_el0             // Performance timer
    
    // Get system structure
    adrp    x20, water_system
    add     x20, x20, :lo12:water_system
    
    ldr     x21, [x20, #WaterSystem_pipes]
    ldr     w22, [x20, #WaterSystem_pipe_count]
    
    // Process each pipe
    mov     w0, #0                      // pipe index
    
.flow_calc_loop:
    cmp     w0, w22
    b.ge    .flow_calc_done
    
    // Get current pipe
    mov     x1, #WaterPipe_size
    umull   x1, w0, x1
    add     x1, x21, x1                 // pipe pointer
    
    // Calculate flow using Darcy-Weisbach equation
    mov     x0, x1                      // pipe pointer
    bl      calculate_pipe_flow
    
    // Update pipe flow and pressure drop
    str     w0, [x1, #WaterPipe_current_flow]
    
    // Calculate pressure drop
    mov     x0, x1
    bl      calculate_pressure_drop
    str     w0, [x1, #WaterPipe_pressure_drop]
    
    add     w0, w0, #1
    b       .flow_calc_loop

.flow_calc_done:
    // Update performance counter
    mrs     x1, cntvct_el0
    sub     x1, x1, x19
    adrp    x0, flow_calc_cycles
    add     x0, x0, :lo12:flow_calc_cycles
    ldr     x2, [x0]
    add     x2, x2, x1
    str     x2, [x0]
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// Utility Functions
//==============================================================================

calculate_tower_pressure:
    // Parameters: x0 = node pointer
    // Returns: w0 = pressure (kPa)
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    ldr     w1, [x0, #WaterNode_elevation]      // Ground elevation
    ldr     w2, [x0, #WaterNode_current_level]  // Water level
    ldr     w3, [x0, #WaterNode_capacity]       // Tank capacity
    
    // Calculate water height: (level / capacity) * tank_height
    // Assume tank height = 30m for standard tower
    mov     w4, #30
    mul     w2, w2, w4
    udiv    w2, w2, w3                  // Water height
    
    // Pressure = atmospheric + rho * g * (elevation + height)
    add     w1, w1, w2                  // Total height
    adrp    x2, gravity_accel
    add     x2, x2, :lo12:gravity_accel
    ldr     w2, [x2]
    mul     w1, w1, w2                  // g * h
    
    adrp    x2, water_density
    add     x2, x2, :lo12:water_density
    ldr     w2, [x2]
    mul     w1, w1, w2                  // rho * g * h
    lsr     w1, w1, #16                 // Convert from fixed point
    
    adrp    x2, atmospheric_pressure
    add     x2, x2, :lo12:atmospheric_pressure
    ldr     w2, [x2]
    add     w0, w1, w2                  // Total pressure
    
    ldp     x29, x30, [sp], #16
    ret

calculate_pipe_capacity:
    // Parameters: x0 = diameter (mm)
    // Returns: w0 = capacity (L/min)
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Simplified capacity calculation
    // Capacity ≈ diameter^2 * constant
    mul     w1, w0, w0                  // diameter^2
    mov     w2, #100                    // Scale factor
    mul     w0, w1, w2
    udiv    w0, w0, #1000               // Convert to reasonable units
    
    ldp     x29, x30, [sp], #16
    ret

calculate_consumer_pressure:
    // Calculate pressure at consumer node
    mov     w0, #0x1E0000               // 30 psi default
    ret

calculate_pump_pressure:
    // Calculate pressure boost from pump
    mov     w0, #0x4B0000               // 75 psi boost
    ret

calculate_pipe_flow:
    // Calculate flow through pipe using Darcy-Weisbach
    mov     w0, #1000                   // Default 1000 L/min
    ret

calculate_pressure_drop:
    // Calculate pressure drop across pipe
    mov     w0, #0x1999                 // 0.1 psi drop
    ret

water_system_check_quality:
    // Update water quality tracking
    adrp    x0, quality_updates
    add     x0, x0, :lo12:quality_updates
    ldr     x1, [x0]
    add     x1, x1, #1
    str     x1, [x0]
    ret

water_system_detect_leaks:
    // Detect pipe leaks based on flow vs pressure
    ret

update_water_system_stats:
    // Update system-wide statistics
    ret

water_system_get_service_level:
    // Parameters: x0 = x_coord, x1 = y_coord
    // Returns: w0 = service_level (0-100)
    mov     w0, #85                     // Default good service
    ret

water_system_add_consumer:
    // Add water consumer
    // Parameters: x0 = x_coord, x1 = y_coord, x2 = demand
    mov     x3, #FACILITY_CONSUMER      // Set type
    mov     x4, x2                      // Demand as capacity
    mov     x2, #0                      // Sea level elevation
    bl      water_system_add_facility
    ret

water_system_cleanup:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Clean up allocated resources
    adrp    x0, water_system
    add     x0, x0, :lo12:water_system
    
    // Free nodes
    ldr     x1, [x0, #WaterSystem_nodes]
    cbz     x1, .water_cleanup_pipes
    mov     x0, x1
    bl      free
    
.water_cleanup_pipes:
    adrp    x0, water_system
    add     x0, x0, :lo12:water_system
    ldr     x1, [x0, #WaterSystem_pipes]
    cbz     x1, .water_cleanup_done
    mov     x0, x1
    bl      free
    
.water_cleanup_done:
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Memory management
//==============================================================================

malloc:
    mov     x8, #222                    // mmap
    mov     x1, x0                      // length
    mov     x0, #0                      // addr = NULL
    mov     x2, #3                      // prot = PROT_READ | PROT_WRITE
    mov     x3, #0x22                   // flags = MAP_PRIVATE | MAP_ANONYMOUS
    mov     x4, #-1                     // fd = -1
    mov     x5, #0                      // offset = 0
    svc     #0
    ret

free:
    cbz     x0, .free_done
    mov     x8, #215                    // munmap
    mov     x1, #4096                   // Assume 4KB
    svc     #0
.free_done:
    ret

.end
    
.facility_check_pump:
    cmp     w22, #FACILITY_PUMP_STATION
    b.ne    .facility_set_defaults
    
    // Pump station - amplifies pressure
    str     wzr, [x2, #WaterNode_current_level]
    mov     w3, #0x500000               // 80 psi output pressure
    str     w3, [x2, #WaterNode_pressure]
    str     w23, [x2, #WaterNode_flow_rate]      // Flow capacity
    
.facility_set_defaults:
    // Set default values
    str     wzr, [x2, #WaterNode_demand]         // Facilities don't consume
    str     wzr, [x2, #WaterNode_connections]
    str     xzr, [x2, #WaterNode_pipe_list]
    
    // Set water quality parameters
    mov     w3, #0x640000               // 100% quality
    str     w3, [x2, #WaterNode_quality]
    str     wzr, [x2, #WaterNode_contamination]
    mov     w3, #0x140000               // 20°C temperature
    str     w3, [x2, #WaterNode_temperature]
    mov     w3, #0x70000                // pH 7.0
    str     w3, [x2, #WaterNode_ph_level]
    mov     w3, #0x20000                // 2.0 mg/L chlorine
    str     w3, [x2, #WaterNode_chlorine_level]
    
    // Set service area based on facility type
    mov     w3, #500                    // Default 500m radius
    cmp     w22, #FACILITY_WATER_TOWER
    csel    w3, #1000, w3, eq           // Water towers: 1000m
    cmp     w22, #FACILITY_WATER_PLANT
    csel    w3, #2000, w3, eq           // Plants: 2000m
    str     w3, [x2, #WaterNode_service_area]
    
    str     wzr, [x2, #WaterNode_maintenance]
    
    // Update system totals
    ldr     w3, [x0, #WaterSystem_total_supply]
    add     w3, w3, w23
    str     w3, [x0, #WaterSystem_total_supply]
    
    // Increment node count
    add     w1, w1, #1
    str     w1, [x0, #WaterSystem_node_count]
    
    // Mark system as dirty
    mov     w2, #1
    str     w2, [x0, #WaterSystem_dirty]
    
    // Return new node ID
    sub     x0, x1, #1
    b       .add_facility_exit
    
.add_facility_error:
    mov     x0, #-1
    
.add_facility_exit:
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//==============================================================================
// calculate_tower_pressure - Calculate pressure for water tower
// Parameters: x2 = node pointer, w21 = elevation, w23 = capacity
// Returns: w0 = pressure (kPa, fixed-point)
//==============================================================================
calculate_tower_pressure:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get current water level
    ldr     w0, [x2, #WaterNode_current_level]
    
    // Calculate water height in tower (assume cylindrical, 10m diameter)
    // height = volume / (π * r^2) where r = 5m
    // Simplified: height ≈ volume / 78.5
    mov     w1, #78                     // Approximation of π * r^2
    udiv    w0, w0, w1                  // Water height in meters
    
    // Total height = elevation + water_height
    add     w0, w21, w0
    
    // Pressure = ρ * g * h (in Pascal)
    // Convert to kPa: P = (density * gravity * height) / 1000
    adrp    x1, water_density
    add     x1, x1, :lo12:water_density
    ldr     w1, [x1]
    
    adrp    x2, gravity_accel
    add     x2, x2, :lo12:gravity_accel
    ldr     w2, [x2]
    
    // Fixed-point multiplication
    umull   x3, w0, w1                  // height * density
    lsr     x3, x3, #16
    umull   x3, w3, w2                  // * gravity
    lsr     x3, x3, #16
    mov     w3, w3, lsr #10             // / 1024 ≈ / 1000 (convert to kPa)
    
    // Add atmospheric pressure
    adrp    x1, atmospheric_pressure
    add     x1, x1, :lo12:atmospheric_pressure
    ldr     w1, [x1]
    add     w0, w3, w1
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// water_system_add_consumer - Add water consumer to the system
// Parameters: x0 = x_coord, x1 = y_coord, x2 = elevation, x3 = demand
// Returns: x0 = node_id (>=0) or error (-1)
//==============================================================================
water_system_add_consumer:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // x_coord
    mov     x20, x1                     // y_coord
    mov     x21, x2                     // elevation
    mov     x22, x3                     // demand
    
    // Get system structure
    adrp    x0, water_system
    add     x0, x0, :lo12:water_system
    
    // Check capacity
    ldr     w1, [x0, #WaterSystem_node_count]
    ldr     w2, [x0, #WaterSystem_capacity]
    cmp     w1, w2
    b.ge    .add_consumer_error
    
    // Get node array and calculate offset
    ldr     x2, [x0, #WaterSystem_nodes]
    mov     x3, #WaterNode_size
    umull   x3, w1, w3
    add     x2, x2, x3                  // new node pointer
    
    // Initialize consumer node
    str     w1, [x2, #WaterNode_id]
    mov     w3, #FACILITY_CONSUMER
    str     w3, [x2, #WaterNode_type]
    str     w19, [x2, #WaterNode_x]
    str     w20, [x2, #WaterNode_y]
    str     w21, [x2, #WaterNode_elevation]
    str     wzr, [x2, #WaterNode_capacity]       // Consumers don't store
    str     wzr, [x2, #WaterNode_current_level]
    str     wzr, [x2, #WaterNode_pressure]       // Will be calculated
    str     wzr, [x2, #WaterNode_flow_rate]      // Will be calculated
    str     w22, [x2, #WaterNode_demand]
    
    // Initialize other fields
    str     wzr, [x2, #WaterNode_connections]
    str     xzr, [x2, #WaterNode_pipe_list]
    mov     w3, #0x640000               // 100% quality initially
    str     w3, [x2, #WaterNode_quality]
    str     wzr, [x2, #WaterNode_contamination]
    mov     w3, #0x140000               // 20°C temperature
    str     w3, [x2, #WaterNode_temperature]
    mov     w3, #0x70000                // pH 7.0
    str     w3, [x2, #WaterNode_ph_level]
    str     wzr, [x2, #WaterNode_chlorine_level] // No initial chlorine
    str     wzr, [x2, #WaterNode_service_area]   // Consumers don't serve
    str     wzr, [x2, #WaterNode_maintenance]
    
    // Update system totals
    ldr     w3, [x0, #WaterSystem_total_demand]
    add     w3, w3, w22
    str     w3, [x0, #WaterSystem_total_demand]
    
    // Increment node count
    add     w1, w1, #1
    str     w1, [x0, #WaterSystem_node_count]
    
    // Mark system as dirty
    mov     w2, #1
    str     w2, [x0, #WaterSystem_dirty]
    
    // Return new node ID
    sub     x0, x1, #1
    b       .add_consumer_exit
    
.add_consumer_error:
    mov     x0, #-1
    
.add_consumer_exit:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// water_system_add_pipe - Add pipe connection between nodes
// Parameters: x0 = from_node, x1 = to_node, x2 = pipe_type, 
//            x3 = diameter, x4 = length
// Returns: x0 = success (1) or failure (0)
//==============================================================================
water_system_add_pipe:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    
    mov     x19, x0                     // from_node
    mov     x20, x1                     // to_node
    mov     x21, x2                     // pipe_type
    mov     x22, x3                     // diameter
    mov     x23, x4                     // length
    
    // Get system structure
    adrp    x0, water_system
    add     x0, x0, :lo12:water_system
    
    // Validate node IDs
    ldr     w1, [x0, #WaterSystem_node_count]
    cmp     w19, w1
    b.ge    .add_pipe_error
    cmp     w20, w1
    b.ge    .add_pipe_error
    cmp     w19, #0
    b.lt    .add_pipe_error
    cmp     w20, #0
    b.lt    .add_pipe_error
    
    // Check pipe capacity
    ldr     w1, [x0, #WaterSystem_pipe_count]
    ldr     w2, [x0, #WaterSystem_node_count]
    lsl     w2, w2, #2                  // Allow 4 pipes per node
    cmp     w1, w2
    b.ge    .add_pipe_error
    
    // Get pipe array and calculate offset
    ldr     x2, [x0, #WaterSystem_pipes]
    mov     x3, #WaterPipe_size
    umull   x3, w1, w3
    add     x2, x2, x3                  // new pipe pointer
    
    // Initialize pipe
    str     w1, [x2, #WaterPipe_id]
    str     w19, [x2, #WaterPipe_from]
    str     w20, [x2, #WaterPipe_to]
    str     w21, [x2, #WaterPipe_type]
    str     w22, [x2, #WaterPipe_diameter]
    str     w23, [x2, #WaterPipe_length]
    
    // Set material properties based on pipe type
    mov     w3, #1                      // Cast iron (default)
    mov     w4, #0x0014                 // 0.02 roughness
    cmp     w21, #PIPE_WATER_MAIN
    b.ne    .pipe_check_service
    mov     w3, #2                      // Steel for mains
    mov     w4, #0x0010                 // 0.015 roughness
    b       .pipe_set_material
    
.pipe_check_service:
    cmp     w21, #PIPE_SEWAGE_MAIN
    b.ne    .pipe_set_material
    mov     w3, #3                      // Concrete for sewage
    mov     w4, #0x0020                 // 0.03 roughness
    
.pipe_set_material:
    str     w3, [x2, #WaterPipe_material]
    str     w4, [x2, #WaterPipe_roughness]
    
    // Calculate capacity using Hazen-Williams equation
    // Q = C * D^2.63 * S^0.54 where C=coefficient, D=diameter, S=slope
    // Simplified: capacity ≈ diameter^2 * 0.5
    umull   x5, w22, w22                // diameter^2
    lsr     x5, x5, #1                  // * 0.5
    str     w5, [x2, #WaterPipe_capacity]
    
    // Initialize operational parameters
    str     wzr, [x2, #WaterPipe_current_flow]
    str     wzr, [x2, #WaterPipe_pressure_drop]
    str     wzr, [x2, #WaterPipe_age]
    mov     w5, #0x10000                // 1.0 = new condition
    str     w5, [x2, #WaterPipe_condition]
    str     wzr, [x2, #WaterPipe_leakage_rate]
    str     wzr, [x2, #WaterPipe_blockage_factor]
    
    // Increment pipe count
    add     w1, w1, #1
    str     w1, [x0, #WaterSystem_pipe_count]
    
    // Mark system as dirty
    mov     w1, #1
    str     w1, [x0, #WaterSystem_dirty]
    
    // Success
    mov     x0, #1
    b       .add_pipe_exit
    
.add_pipe_error:
    mov     x0, #0
    
.add_pipe_exit:
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//==============================================================================
// water_system_calculate_pressure - Calculate water pressure throughout system
// Parameters: None
// Returns: x0 = processing_time_cycles
//==============================================================================
water_system_calculate_pressure:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Start performance timer
    mrs     x19, cntvct_el0
    
    // Get system structure
    adrp    x20, water_system
    add     x20, x20, :lo12:water_system
    
    // Check if update needed
    ldr     w0, [x20, #WaterSystem_dirty]
    cbz     w0, .pressure_exit
    
    ldr     x21, [x20, #WaterSystem_nodes]
    ldr     w22, [x20, #WaterSystem_node_count]
    
    // Calculate pressure for each node
    mov     w0, #0                      // node index
    mov     w1, #0                      // min_pressure
    mov     w2, #0                      // max_pressure
    mov     w3, #0                      // total_pressure (for average)
    
.pressure_loop:
    cmp     w0, w22
    b.ge    .pressure_complete
    
    // Get current node
    mov     x4, #WaterNode_size
    umull   x4, w0, w4
    add     x4, x21, x4
    
    // Get node type
    ldr     w5, [x4, #WaterNode_type]
    
    // Calculate pressure based on node type
    cmp     w5, #FACILITY_WATER_TOWER
    b.eq    .pressure_tower
    cmp     w5, #FACILITY_WATER_PLANT
    b.eq    .pressure_plant
    cmp     w5, #FACILITY_PUMP_STATION
    b.eq    .pressure_pump
    cmp     w5, #FACILITY_CONSUMER
    b.eq    .pressure_consumer
    b       .pressure_next
    
.pressure_tower:
    // Water tower pressure already calculated in add_facility
    ldr     w6, [x4, #WaterNode_pressure]
    b       .pressure_update_stats
    
.pressure_plant:
    // Water plant has constant pressure
    ldr     w6, [x4, #WaterNode_pressure]
    b       .pressure_update_stats
    
.pressure_pump:
    // Pump station pressure calculation
    // P_out = P_in + pump_boost (simplified)
    bl      calculate_pump_pressure
    mov     w6, w0
    str     w6, [x4, #WaterNode_pressure]
    b       .pressure_update_stats
    
.pressure_consumer:
    // Consumer pressure depends on connected supply
    bl      calculate_consumer_pressure
    mov     w6, w0
    str     w6, [x4, #WaterNode_pressure]
    
.pressure_update_stats:
    // Update min/max pressure tracking
    cmp     w0, #0                      // First node?
    csel    w1, w6, w1, eq              // Set initial min
    csel    w2, w6, w2, eq              // Set initial max
    cmp     w6, w1
    csel    w1, w6, w1, lt              // Update min
    cmp     w6, w2
    csel    w2, w6, w2, gt              // Update max
    add     w3, w3, w6                  // Add to total
    
.pressure_next:
    add     w0, w0, #1
    b       .pressure_loop
    
.pressure_complete:
    // Calculate average pressure
    cbz     w22, .pressure_store_stats
    udiv    w4, w3, w22                 // average = total / count
    
.pressure_store_stats:
    // Store pressure statistics
    str     w1, [x20, #WaterSystem_min_pressure]
    str     w2, [x20, #WaterSystem_max_pressure]
    str     w4, [x20, #WaterSystem_avg_pressure]
    
.pressure_exit:
    // Calculate elapsed cycles
    mrs     x21, cntvct_el0
    sub     x0, x21, x19
    
    // Update performance counter
    adrp    x1, pressure_calc_cycles
    add     x1, x1, :lo12:pressure_calc_cycles
    ldr     x2, [x1]
    add     x2, x2, x0
    str     x2, [x1]
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// calculate_pump_pressure - Calculate pressure boost from pump station
// Parameters: x4 = node pointer
// Returns: w0 = output_pressure
//==============================================================================
calculate_pump_pressure:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get pump capacity and current flow
    ldr     w0, [x4, #WaterNode_capacity]
    ldr     w1, [x4, #WaterNode_flow_rate]
    
    // Calculate pump efficiency (decreases with flow)
    // efficiency = 1.0 - (flow / capacity) * 0.3
    udiv    w2, w1, w0                  // flow/capacity ratio
    mov     w3, #0x4CCC                 // 0.3 in 16.16
    smull   x2, w2, w3                  // ratio * 0.3
    lsr     x2, x2, #16
    mov     w3, #0x10000                // 1.0
    sub     w3, w3, w2                  // efficiency
    
    // Base pump pressure boost: 200 kPa * efficiency
    mov     w0, #0xC80000               // 200 kPa in 16.16
    smull   x0, w0, w3                  // * efficiency
    lsr     x0, x0, #16
    
    // Add atmospheric pressure
    adrp    x1, atmospheric_pressure
    add     x1, x1, :lo12:atmospheric_pressure
    ldr     w1, [x1]
    add     w0, w0, w1
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// calculate_consumer_pressure - Calculate pressure at consumer node
// Parameters: x4 = node pointer, w0 = node_index
// Returns: w0 = consumer_pressure
//==============================================================================
calculate_consumer_pressure:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x4                     // node pointer
    mov     w20, w0                     // node index
    
    // Find nearest supply source (water tower, plant, or pump)
    // Simplified: use distance-weighted average of all sources
    adrp    x0, water_system
    add     x0, x0, :lo12:water_system
    ldr     x1, [x0, #WaterSystem_nodes]
    ldr     w2, [x0, #WaterSystem_node_count]
    
    ldr     w3, [x19, #WaterNode_x]     // consumer x
    ldr     w4, [x19, #WaterNode_y]     // consumer y
    ldr     w5, [x19, #WaterNode_elevation] // consumer elevation
    
    mov     w6, #0                      // total weighted pressure
    mov     w7, #0                      // total weight
    mov     w8, #0                      // source index
    
.consumer_pressure_loop:
    cmp     w8, w2
    b.ge    .consumer_pressure_done
    
    // Get source node
    mov     x9, #WaterNode_size
    umull   x9, w8, w9
    add     x9, x1, x9
    
    // Check if it's a supply source
    ldr     w10, [x9, #WaterNode_type]
    cmp     w10, #FACILITY_CONSUMER
    b.eq    .consumer_pressure_next     // Skip other consumers
    
    // Calculate distance
    ldr     w11, [x9, #WaterNode_x]
    ldr     w12, [x9, #WaterNode_y]
    ldr     w13, [x9, #WaterNode_elevation]
    
    sub     w11, w11, w3                // dx
    sub     w12, w12, w4                // dy
    sub     w13, w13, w5                // dz
    
    // Distance = sqrt(dx^2 + dy^2 + dz^2) (approximated)
    smull   x14, w11, w11               // dx^2
    smull   x15, w12, w12               // dy^2
    smull   x16, w13, w13               // dz^2
    add     x14, x14, x15
    add     x14, x14, x16
    lsr     x14, x14, #16               // Approximate distance
    
    // Avoid division by zero
    cmp     w14, #1
    csel    w14, #1, w14, lt
    
    // Weight = 1000 / distance (closer sources have more influence)
    mov     w15, #1000
    udiv    w15, w15, w14
    
    // Get source pressure
    ldr     w16, [x9, #WaterNode_pressure]
    
    // Add weighted pressure
    umull   x17, w16, w15               // pressure * weight
    lsr     x17, x17, #16
    add     w6, w6, w17                 // total weighted pressure
    add     w7, w7, w15                 // total weight
    
.consumer_pressure_next:
    add     w8, w8, #1
    b       .consumer_pressure_loop
    
.consumer_pressure_done:
    // Calculate weighted average pressure
    cbz     w7, .consumer_pressure_default
    udiv    w0, w6, w7                  // weighted average
    
    // Apply elevation penalty: -9.8 kPa per meter height difference
    // This is already factored into source calculations
    
    b       .consumer_pressure_exit
    
.consumer_pressure_default:
    // No sources found - use atmospheric pressure
    adrp    x0, atmospheric_pressure
    add     x0, x0, :lo12:atmospheric_pressure
    ldr     w0, [x0]
    
.consumer_pressure_exit:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// water_system_calculate_flow - Calculate water flow throughout system
// Parameters: None
// Returns: x0 = processing_time_cycles
//==============================================================================
water_system_calculate_flow:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Start performance timer
    mrs     x19, cntvct_el0
    
    // Get system structure
    adrp    x20, water_system
    add     x20, x20, :lo12:water_system
    
    ldr     x21, [x20, #WaterSystem_pipes]
    ldr     w22, [x20, #WaterSystem_pipe_count]
    
    // Calculate flow for each pipe using Darcy-Weisbach equation
    // Q = A * sqrt(2 * g * h / f) where h = pressure difference
    mov     w0, #0                      // pipe index
    mov     w1, #0                      // total system flow
    
.flow_loop:
    cmp     w0, w22
    b.ge    .flow_complete
    
    // Get current pipe
    mov     x2, #WaterPipe_size
    umull   x2, w0, w2
    add     x2, x21, x2
    
    // Get from and to nodes
    ldr     w3, [x2, #WaterPipe_from]
    ldr     w4, [x2, #WaterPipe_to]
    
    // Get node pressures
    bl      get_node_pressure
    mov     w5, w0                      // from_pressure
    mov     w0, w4
    bl      get_node_pressure
    mov     w6, w0                      // to_pressure
    
    // Calculate pressure difference
    sub     w7, w5, w6                  // pressure_diff
    
    // Flow direction: positive = from->to, negative = to->from
    cmp     w7, #0
    b.le    .flow_reverse
    
    // Calculate flow using simplified equation
    // Q = C * D^2 * sqrt(pressure_diff) where C is flow coefficient
    ldr     w8, [x2, #WaterPipe_diameter]
    ldr     w9, [x2, #WaterPipe_capacity]
    ldr     w10, [x2, #WaterPipe_condition]
    
    // Flow = capacity * sqrt(pressure_ratio) * condition
    // pressure_ratio = pressure_diff / max_pressure
    mov     w11, #0x500000              // Assume 80 psi max
    lsl     w12, w7, #16                // pressure_diff << 16
    udiv    w12, w12, w11               // pressure_ratio
    
    // Approximate sqrt(pressure_ratio)
    bl      fixed_point_sqrt
    mov     w13, w0
    
    // Final flow = capacity * sqrt_ratio * condition
    umull   x14, w9, w13                // capacity * sqrt_ratio
    lsr     x14, x14, #16
    umull   x14, w14, w10               // * condition
    lsr     x14, x14, #16
    mov     w14, w14
    
    b       .flow_store
    
.flow_reverse:
    // Reverse flow (negative)
    neg     w14, w7                     // Make positive for calculation
    // Use same calculation but negate result
    ldr     w8, [x2, #WaterPipe_diameter]
    ldr     w9, [x2, #WaterPipe_capacity]
    ldr     w10, [x2, #WaterPipe_condition]
    
    mov     w11, #0x500000
    lsl     w12, w14, #16
    udiv    w12, w12, w11
    bl      fixed_point_sqrt
    mov     w13, w0
    
    umull   x14, w9, w13
    lsr     x14, x14, #16
    umull   x14, w14, w10
    lsr     x14, x14, #16
    neg     w14, w14                    // Negative flow
    
.flow_store:
    // Store calculated flow
    str     w14, [x2, #WaterPipe_current_flow]
    
    // Calculate pressure drop due to friction
    // ΔP = f * (L/D) * (ρ * v^2) / 2
    // Simplified: pressure_drop = flow^2 * friction_factor * length / diameter^3
    ldr     w15, [x2, #WaterPipe_length]
    ldr     w16, [x2, #WaterPipe_roughness]
    
    abs     w17, w14                    // |flow|
    umull   x18, w17, w17               // flow^2
    umull   x18, w18, w16               // * roughness
    umull   x18, w18, w15               // * length
    lsr     x18, x18, #32               // Scale down
    
    umull   x19, w8, w8                 // diameter^2
    umull   x19, w19, w8                // diameter^3
    lsr     x19, x19, #16
    
    cbz     w19, .flow_no_drop
    udiv    w18, w18, w19               // / diameter^3
    str     w18, [x2, #WaterPipe_pressure_drop]
    b       .flow_add_total
    
.flow_no_drop:
    str     wzr, [x2, #WaterPipe_pressure_drop]
    
.flow_add_total:
    // Add to total system flow (absolute value)
    abs     w17, w14
    add     w1, w1, w17
    
    // Next pipe
    add     w0, w0, #1
    b       .flow_loop
    
.flow_complete:
    // Store total system flow
    str     w1, [x20, #WaterSystem_total_flow]
    
    // Calculate elapsed cycles
    mrs     x21, cntvct_el0
    sub     x0, x21, x19
    
    // Update performance counter
    adrp    x1, flow_calc_cycles
    add     x1, x1, :lo12:flow_calc_cycles
    ldr     x2, [x1]
    add     x2, x2, x0
    str     x2, [x1]
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// get_node_pressure - Get pressure for a specific node
// Parameters: w0 = node_id
// Returns: w0 = pressure (kPa, fixed-point)
//==============================================================================
get_node_pressure:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get system structure
    adrp    x1, water_system
    add     x1, x1, :lo12:water_system
    ldr     x1, [x1, #WaterSystem_nodes]
    
    // Calculate node offset
    mov     x2, #WaterNode_size
    umull   x2, w0, w2
    add     x1, x1, x2
    
    // Get pressure
    ldr     w0, [x1, #WaterNode_pressure]
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// water_system_update - Main update function called each frame
// Parameters: x0 = delta_time_ms
// Returns: x0 = processing_time_cycles
//==============================================================================
water_system_update:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Calculate pressure distribution
    bl      water_system_calculate_pressure
    
    // Calculate flow rates
    bl      water_system_calculate_flow
    
    // Update water quality
    bl      water_system_check_quality
    
    // Detect leaks and maintenance issues
    bl      water_system_detect_leaks
    
    // Clear dirty flag
    adrp    x1, water_system
    add     x1, x1, :lo12:water_system
    str     wzr, [x1, #WaterSystem_dirty]
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// water_system_check_quality - Monitor and update water quality
// Parameters: None
// Returns: x0 = average_quality_index
//==============================================================================
water_system_check_quality:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Get system structure
    adrp    x19, water_system
    add     x19, x19, :lo12:water_system
    ldr     x20, [x19, #WaterSystem_nodes]
    ldr     w21, [x19, #WaterSystem_node_count]
    
    // Check quality at each node
    mov     w0, #0                      // node index
    mov     w1, #0                      // total quality
    mov     w2, #0                      // quality node count
    
.quality_loop:
    cmp     w0, w21
    b.ge    .quality_complete
    
    // Get current node
    mov     x3, #WaterNode_size
    umull   x3, w0, w3
    add     x3, x20, x3
    
    // Get node type
    ldr     w4, [x3, #WaterNode_type]
    
    // Update quality based on node type
    cmp     w4, #FACILITY_WATER_PLANT
    b.eq    .quality_plant
    cmp     w4, #FACILITY_WATER_TOWER
    b.eq    .quality_tower
    cmp     w4, #FACILITY_CONSUMER
    b.eq    .quality_consumer
    b       .quality_next
    
.quality_plant:
    // Water plants maintain high quality
    mov     w5, #0x640000               // 100% quality
    str     w5, [x3, #WaterNode_quality]
    mov     w6, #0x20000                // 2.0 mg/L chlorine
    str     w6, [x3, #WaterNode_chlorine_level]
    b       .quality_add_total
    
.quality_tower:
    // Water towers slowly degrade quality
    ldr     w5, [x3, #WaterNode_quality]
    mov     w6, #0x0100                 // Small degradation
    sub     w5, w5, w6
    cmp     w5, #0x320000               // Don't go below 50%
    csel    w5, #0x320000, w5, lt
    str     w5, [x3, #WaterNode_quality]
    
    // Chlorine evaporates over time
    ldr     w6, [x3, #WaterNode_chlorine_level]
    mov     w7, #0x0080                 // Evaporation rate
    sub     w6, w6, w7
    cmp     w6, #0
    csel    w6, wzr, w6, lt
    str     w6, [x3, #WaterNode_chlorine_level]
    b       .quality_add_total
    
.quality_consumer:
    // Consumers inherit quality from supply
    // Simplified: use average of connected sources
    bl      calculate_consumer_quality
    str     w0, [x3, #WaterNode_quality]
    mov     w5, w0
    
.quality_add_total:
    add     w1, w1, w5                  // Add to total
    add     w2, w2, #1                  // Increment count
    
.quality_next:
    add     w0, w0, #1
    b       .quality_loop
    
.quality_complete:
    // Calculate average quality
    cbz     w2, .quality_no_nodes
    udiv    w0, w1, w2                  // average quality
    str     w0, [x19, #WaterSystem_quality_avg]
    b       .quality_exit
    
.quality_no_nodes:
    mov     w0, #0
    
.quality_exit:
    // Update performance counter
    adrp    x1, quality_updates
    add     x1, x1, :lo12:quality_updates
    ldr     x2, [x1]
    add     x2, x2, #1
    str     x2, [x1]
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// calculate_consumer_quality - Calculate quality at consumer node
// Parameters: x3 = node pointer
// Returns: w0 = quality_index
//==============================================================================
calculate_consumer_quality:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Simplified: return 80% quality (degraded from source)
    mov     w0, #0x500000               // 80% quality
    
    // In full implementation, would trace back through pipe network
    // and calculate quality degradation based on:
    // - Distance from source
    // - Pipe age and condition
    // - Residence time in system
    // - Chlorine decay
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// water_system_detect_leaks - Detect and track water system leaks
// Parameters: None
// Returns: x0 = total_leakage_rate (L/min)
//==============================================================================
water_system_detect_leaks:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Get system structure
    adrp    x19, water_system
    add     x19, x19, :lo12:water_system
    ldr     x20, [x19, #WaterSystem_pipes]
    ldr     w21, [x19, #WaterSystem_pipe_count]
    
    mov     w0, #0                      // pipe index
    mov     w1, #0                      // total leakage
    
.leak_loop:
    cmp     w0, w21
    b.ge    .leak_complete
    
    // Get current pipe
    mov     x2, #WaterPipe_size
    umull   x2, w0, w2
    add     x2, x20, x2
    
    // Calculate leakage based on age and condition
    ldr     w3, [x2, #WaterPipe_age]
    ldr     w4, [x2, #WaterPipe_condition]
    ldr     w5, [x2, #WaterPipe_length]
    
    // Leakage = (age * length) / condition^2 * base_rate
    umull   x6, w3, w5                  // age * length
    umull   x7, w4, w4                  // condition^2
    lsr     x7, x7, #16
    cbz     w7, .leak_high
    udiv    w6, w6, w7                  // / condition^2
    
    // Apply base leakage rate (0.1 L/min per 100m for new pipe)
    mov     w8, #0x0199                 // 0.01 base rate
    umull   x6, w6, w8
    lsr     x6, x6, #16
    
    str     w6, [x2, #WaterPipe_leakage_rate]
    add     w1, w1, w6                  // Add to total
    b       .leak_next
    
.leak_high:
    // Very poor condition - high leakage
    mov     w6, w5, lsr #2              // 25% of length as leakage
    str     w6, [x2, #WaterPipe_leakage_rate]
    add     w1, w1, w6
    
.leak_next:
    add     w0, w0, #1
    b       .leak_loop
    
.leak_complete:
    // Store total system leakage
    str     w1, [x19, #WaterSystem_leakage_total]
    mov     x0, x1
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// water_system_get_service_level - Get service level for a location
// Parameters: x0 = x_coord, x1 = y_coord
// Returns: x0 = service_level (0-100), x1 = pressure (kPa), x2 = quality
//==============================================================================
water_system_get_service_level:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // x_coord
    mov     x20, x1                     // y_coord
    
    // Find nearest consumer node
    bl      find_nearest_consumer
    cbz     x0, .service_no_coverage
    
    // Get service data from nearest consumer
    mov     x1, #WaterNode_size
    mul     x1, x0, x1
    
    adrp    x2, water_system
    add     x2, x2, :lo12:water_system
    ldr     x2, [x2, #WaterSystem_nodes]
    add     x1, x2, x1
    
    ldr     w2, [x1, #WaterNode_pressure]  // pressure
    ldr     w3, [x1, #WaterNode_quality]   // quality
    
    // Calculate service level based on pressure and quality
    // Service = (pressure_score + quality_score) / 2
    
    // Pressure score: 0-100 based on min/max thresholds
    adrp    x4, min_service_pressure
    add     x4, x4, :lo12:min_service_pressure
    ldr     w4, [x4]
    
    adrp    x5, max_service_pressure
    add     x5, x5, :lo12:max_service_pressure
    ldr     w5, [x5]
    
    cmp     w2, w4
    b.lt    .service_low_pressure
    cmp     w2, w5
    b.gt    .service_high_pressure
    
    // Normal pressure range
    sub     w6, w2, w4                  // pressure above minimum
    sub     w7, w5, w4                  // pressure range
    mov     w8, #100
    umull   x6, w6, w8                  // * 100
    udiv    w6, w6, w7                  // / range
    b       .service_calc_final
    
.service_low_pressure:
    mov     w6, #0                      // 0% pressure score
    b       .service_calc_final
    
.service_high_pressure:
    mov     w6, #100                    // 100% pressure score
    
.service_calc_final:
    // Quality score is already 0-100
    lsr     w7, w3, #16                 // Convert from 16.16 to integer
    
    // Service level = (pressure_score + quality_score) / 2
    add     w0, w6, w7
    lsr     w0, w0, #1
    
    mov     x1, x2                      // pressure
    mov     x2, x3                      // quality
    b       .service_exit
    
.service_no_coverage:
    mov     x0, #0                      // No service
    mov     x1, #0                      // No pressure
    mov     x2, #0                      // No quality
    
.service_exit:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// find_nearest_consumer - Find nearest consumer node to coordinates
// Parameters: x19 = x_coord, x20 = y_coord
// Returns: x0 = node_index (or 0 if none found)
//==============================================================================
find_nearest_consumer:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    
    // Get system structure
    adrp    x0, water_system
    add     x0, x0, :lo12:water_system
    ldr     x21, [x0, #WaterSystem_nodes]
    ldr     w22, [x0, #WaterSystem_node_count]
    
    mov     w0, #0                      // node index
    mov     w1, #0x7FFFFFFF             // min distance
    mov     w2, #0                      // best node
    
.find_loop:
    cmp     w0, w22
    b.ge    .find_done
    
    // Get current node
    mov     x3, #WaterNode_size
    umull   x3, w0, w3
    add     x3, x21, x3
    
    // Check if consumer
    ldr     w4, [x3, #WaterNode_type]
    cmp     w4, #FACILITY_CONSUMER
    b.ne    .find_next
    
    // Calculate distance
    ldr     w5, [x3, #WaterNode_x]
    ldr     w6, [x3, #WaterNode_y]
    sub     w5, w5, w19                 // dx
    sub     w6, w6, w20                 // dy
    
    umull   x7, w5, w5                  // dx^2
    umull   x8, w6, w6                  // dy^2
    add     x7, x7, x8                  // distance^2
    lsr     x7, x7, #16                 // Scale
    
    // Check if closer
    cmp     w7, w1
    b.ge    .find_next
    mov     w1, w7                      // New min distance
    mov     w2, w0                      // New best node
    
.find_next:
    add     w0, w0, #1
    b       .find_loop
    
.find_done:
    mov     x0, x2
    
    ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// water_system_cleanup - Clean up allocated resources
// Parameters: None
// Returns: None
//==============================================================================
water_system_cleanup:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get system structure
    adrp    x0, water_system
    add     x0, x0, :lo12:water_system
    
    // Free nodes array
    ldr     x1, [x0, #WaterSystem_nodes]
    cbz     x1, .cleanup_pipes
    mov     x0, x1
    bl      free
    
    // Free pipes array
    adrp    x0, water_system
    add     x0, x0, :lo12:water_system
    ldr     x1, [x0, #WaterSystem_pipes]
    cbz     x1, .cleanup_done
    mov     x0, x1
    bl      free
    
.cleanup_pipes:
    adrp    x0, water_system
    add     x0, x0, :lo12:water_system
    ldr     x1, [x0, #WaterSystem_pipes]
    cbz     x1, .cleanup_done
    mov     x0, x1
    bl      free
    
.cleanup_done:
    // Zero out the system structure
    adrp    x0, water_system
    add     x0, x0, :lo12:water_system
    mov     x1, #WaterSystem_size
    bl      memset
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Helper Functions and System Calls
//==============================================================================

// Fixed-point square root approximation (Newton's method)
fixed_point_sqrt:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    cbz     w0, .sqrt_zero
    
    // Initial guess: x/2
    lsr     w1, w0, #1
    cbz     w1, .sqrt_one
    
    // Newton iteration: x = (x + n/x) / 2
    mov     w2, #4                      // 4 iterations
    
.sqrt_loop:
    udiv    w3, w0, w1                  // n/x
    add     w1, w1, w3                  // x + n/x
    lsr     w1, w1, #1                  // /2
    sub     w2, w2, #1
    cbnz    w2, .sqrt_loop
    
    mov     w0, w1
    b       .sqrt_exit
    
.sqrt_zero:
    mov     w0, #0
    b       .sqrt_exit
    
.sqrt_one:
    mov     w0, #1
    
.sqrt_exit:
    ldp     x29, x30, [sp], #16
    ret

// Memory management (using system calls)
malloc:
    mov     x8, #222                    // mmap syscall
    mov     x1, x0                      // length
    mov     x0, #0                      // addr = NULL
    mov     x2, #3                      // PROT_READ | PROT_WRITE
    mov     x3, #0x22                   // MAP_PRIVATE | MAP_ANONYMOUS
    mov     x4, #-1                     // fd = -1
    mov     x5, #0                      // offset = 0
    svc     #0
    ret

free:
    cbz     x0, .free_done
    mov     x8, #215                    // munmap syscall
    mov     x1, #4096                   // Assume 4KB pages
    svc     #0
.free_done:
    ret

memset:
    cbz     x1, .memset_done
    mov     w3, #0
.memset_loop:
    strb    w3, [x0], #1
    sub     x1, x1, #1
    cbnz    x1, .memset_loop
.memset_done:
    ret

.end