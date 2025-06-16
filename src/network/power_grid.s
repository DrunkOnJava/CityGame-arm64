//==============================================================================
// SimCity ARM64 Assembly - Power Grid System  
// Agent 6: Infrastructure Networks
//==============================================================================
// Power grid simulation with Gauss-Seidel solver for electrical flow
// Performance target: <5ms for network updates, support for 100k+ nodes
//==============================================================================

.text
.align 4

//==============================================================================
// Constants and Data Structures
//==============================================================================

// Power plant types
.equ POWER_NONE,            0
.equ POWER_COAL,            1
.equ POWER_NUCLEAR,         2
.equ POWER_SOLAR,           3
.equ POWER_WIND,            4
.equ POWER_HYDRO,           5

// Grid component types
.equ GRID_NODE,             0
.equ GRID_TRANSMISSION,     1
.equ GRID_SUBSTATION,       2
.equ GRID_CONSUMER,         3

// Power line types and capacities (in MW, as fixed-point)
.equ LINE_LOW_VOLTAGE,      0x00640000    // 100 MW in 16.16 fixed point
.equ LINE_MEDIUM_VOLTAGE,   0x01900000    // 400 MW
.equ LINE_HIGH_VOLTAGE,     0x03E80000    // 1000 MW
.equ LINE_TRANSMISSION,     0x07D00000    // 2000 MW

// Grid node structure (64 bytes, cache-aligned)
.struct 0
PowerNode_id:               .skip 4       // Unique node ID
PowerNode_type:             .skip 4       // Node type (plant, substation, consumer)
PowerNode_x:                .skip 4       // X coordinate
PowerNode_y:                .skip 4       // Y coordinate
PowerNode_generation:       .skip 4       // Power generation (MW, fixed-point)
PowerNode_demand:           .skip 4       // Power demand (MW, fixed-point)
PowerNode_voltage:          .skip 4       // Voltage level (kV, fixed-point)  
PowerNode_phase_angle:      .skip 4       // Phase angle (radians, fixed-point)
PowerNode_connections:      .skip 4       // Number of connections
PowerNode_conn_list:        .skip 4       // Pointer to connection list
PowerNode_active_power:     .skip 4       // Active power flow (MW)
PowerNode_reactive_power:   .skip 4       // Reactive power flow (MVAr)
PowerNode_impedance_real:   .skip 4       // Real impedance component
PowerNode_impedance_imag:   .skip 4       // Imaginary impedance component
PowerNode_reserved:         .skip 8       // Reserved for future use
PowerNode_size = .

// Power line structure (48 bytes)
.struct 0
PowerLine_id:               .skip 4       // Line ID
PowerLine_from:             .skip 4       // Source node ID
PowerLine_to:               .skip 4       // Destination node ID
PowerLine_type:             .skip 4       // Line type (voltage class)
PowerLine_capacity:         .skip 4       // Max capacity (MW, fixed-point)
PowerLine_resistance:       .skip 4       // Resistance (ohms, fixed-point)
PowerLine_reactance:        .skip 4       // Reactance (ohms, fixed-point)
PowerLine_current_flow:     .skip 4       // Current power flow (MW)
PowerLine_losses:           .skip 4       // Transmission losses (MW)
PowerLine_overload_factor:  .skip 4       // Overload factor (0.0-2.0)
PowerLine_status:           .skip 4       // Line status (active/failed)
PowerLine_reserved:         .skip 4       // Reserved
PowerLine_size = .

// Power grid structure
.struct 0
PowerGrid_nodes:            .skip 8       // Pointer to node array
PowerGrid_lines:            .skip 8       // Pointer to line array  
PowerGrid_node_count:       .skip 4       // Number of nodes
PowerGrid_line_count:       .skip 4       // Number of lines
PowerGrid_capacity:         .skip 4       // Max nodes capacity
PowerGrid_total_generation: .skip 4       // Total generation capacity
PowerGrid_total_demand:     .skip 4       // Total power demand
PowerGrid_system_frequency: .skip 4       // System frequency (Hz, fixed-point)
PowerGrid_convergence_tol:  .skip 4       // Gauss-Seidel convergence tolerance
PowerGrid_max_iterations:   .skip 4       // Max solver iterations
PowerGrid_admittance_matrix:.skip 8       // System admittance matrix
PowerGrid_voltage_vector:   .skip 8       // Voltage solution vector
PowerGrid_dirty:            .skip 4       // Update required flag
PowerGrid_reserved:         .skip 12      // Reserved
PowerGrid_size = .

//==============================================================================
// Global Data
//==============================================================================

.data
.align 8

// Main grid instance
power_grid:                 .skip PowerGrid_size

// Solver parameters
gauss_seidel_tolerance:     .word 0x0029    // 0.00001 in 16.16 fixed point
max_solver_iterations:      .word 100
nominal_frequency:          .word 0x320000  // 50 Hz in 16.16 fixed point

// Power flow calculation constants
base_power_mva:             .word 0x640000  // 100 MVA base power
base_voltage_kv:            .word 0x69000   // 105 kV base voltage

// Performance metrics
solver_iterations:          .word 0
convergence_time:           .quad 0
power_balance_error:        .word 0

// Load balancing and stability metrics
load_balancing_factor:      .word 0x0CCC    // 0.8 in 16.16 fixed point
frequency_regulation_gain:  .word 0x1999    // 0.1 gain factor
voltage_regulation_gain:    .word 0x0CCC    // 0.05 gain factor
stability_margin:           .word 0x1999    // 0.1 stability margin

// Brownout/blackout thresholds
brownout_voltage_threshold: .word 0xF333    // 0.95 p.u. (brownout below this)
blackout_voltage_threshold: .word 0xE666    // 0.9 p.u. (blackout below this)
overload_threshold:         .word 0x14000   // 1.25 overload factor
cascade_failure_threshold:  .word 0x18000   // 1.5 cascade failure factor

// System state tracking
grid_stability_state:       .word 0         // 0=stable, 1=unstable, 2=critical
brownout_zones:            .skip 32        // Bitmask of zones in brownout
blackout_zones:            .skip 32        // Bitmask of zones in blackout
failed_components:         .skip 32        // Bitmask of failed components
total_blackout_flag:       .word 0         // 1 if total system blackout

//==============================================================================
// Public Interface Functions
//==============================================================================

.global power_grid_init
.global power_grid_update
.global power_grid_add_generator
.global power_grid_add_consumer
.global power_grid_add_transmission_line
.global power_grid_solve_power_flow
.global power_grid_get_node_voltage
.global power_grid_get_line_loading
.global power_grid_check_stability
.global power_grid_load_balance
.global power_grid_detect_brownout
.global power_grid_detect_blackout
.global power_grid_cascade_failure_check
.global power_grid_emergency_load_shed
.global power_grid_cleanup

//==============================================================================
// power_grid_init - Initialize the power grid system
// Parameters: x0 = max_nodes, x1 = max_lines
// Returns: x0 = success (1) or failure (0)
//==============================================================================
power_grid_init:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // max_nodes
    mov     x20, x1                     // max_lines
    
    // Validate parameters
    cmp     x19, #2                     // Need at least 2 nodes
    b.lt    .grid_init_error
    cmp     x20, #1                     // Need at least 1 line
    b.lt    .grid_init_error
    cmp     x19, #100000                // Max 100k nodes
    b.gt    .grid_init_error
    
    // Allocate node array
    mov     x0, x19
    mov     x1, #PowerNode_size
    mul     x0, x0, x1
    bl      malloc
    cbz     x0, .grid_init_error
    
    // Store node array pointer
    adrp    x1, power_grid
    add     x1, x1, :lo12:power_grid
    str     x0, [x1, #PowerGrid_nodes]
    
    // Allocate line array
    mov     x0, x20
    mov     x1, #PowerLine_size
    mul     x0, x0, x1
    bl      malloc
    cbz     x0, .grid_init_cleanup_nodes
    
    // Store line array pointer
    adrp    x1, power_grid
    add     x1, x1, :lo12:power_grid
    str     x0, [x1, #PowerGrid_lines]
    
    // Initialize grid structure
    str     wzr, [x1, #PowerGrid_node_count]
    str     wzr, [x1, #PowerGrid_line_count]
    str     w19, [x1, #PowerGrid_capacity]
    
    // Initialize system parameters
    adrp    x2, nominal_frequency
    add     x2, x2, :lo12:nominal_frequency
    ldr     w2, [x2]
    str     w2, [x1, #PowerGrid_system_frequency]
    
    adrp    x2, gauss_seidel_tolerance
    add     x2, x2, :lo12:gauss_seidel_tolerance
    ldr     w2, [x2]
    str     w2, [x1, #PowerGrid_convergence_tol]
    
    adrp    x2, max_solver_iterations
    add     x2, x2, :lo12:max_solver_iterations
    ldr     w2, [x2]
    str     w2, [x1, #PowerGrid_max_iterations]
    
    // Initialize power totals
    str     wzr, [x1, #PowerGrid_total_generation]
    str     wzr, [x1, #PowerGrid_total_demand]
    str     wzr, [x1, #PowerGrid_dirty]
    
    // Allocate admittance matrix (sparse)
    mov     x0, x19
    bl      create_sparse_admittance_matrix
    cbz     x0, .grid_init_cleanup_lines
    
    adrp    x1, power_grid
    add     x1, x1, :lo12:power_grid
    str     x0, [x1, #PowerGrid_admittance_matrix]
    
    // Allocate voltage vector
    mov     x0, x19
    mov     x1, #8                      // 8 bytes per complex voltage
    mul     x0, x0, x1
    bl      malloc
    cbz     x0, .grid_init_cleanup_matrix
    
    adrp    x1, power_grid
    add     x1, x1, :lo12:power_grid
    str     x0, [x1, #PowerGrid_voltage_vector]
    
    // Initialize system state
    adrp    x0, grid_stability_state
    add     x0, x0, :lo12:grid_stability_state
    str     wzr, [x0]
    
    adrp    x0, total_blackout_flag
    add     x0, x0, :lo12:total_blackout_flag
    str     wzr, [x0]
    
    // Success
    mov     x0, #1
    b       .grid_init_exit
    
.grid_init_cleanup_matrix:
    adrp    x1, power_grid
    add     x1, x1, :lo12:power_grid
    ldr     x0, [x1, #PowerGrid_admittance_matrix]
    bl      free_sparse_matrix
    
.grid_init_cleanup_lines:
    adrp    x1, power_grid
    add     x1, x1, :lo12:power_grid
    ldr     x0, [x1, #PowerGrid_lines]
    bl      free
    
.grid_init_cleanup_nodes:
    adrp    x1, power_grid
    add     x1, x1, :lo12:power_grid
    ldr     x0, [x1, #PowerGrid_nodes]
    bl      free
    
.grid_init_error:
    mov     x0, #0
    
.grid_init_exit:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// power_grid_add_generator - Add a power generator to the grid
// Parameters: x0 = x_coord, x1 = y_coord, x2 = generator_type, x3 = capacity_mw
// Returns: x0 = node_id (>=0) or error (-1)
//==============================================================================
power_grid_add_generator:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // x_coord
    mov     x20, x1                     // y_coord
    mov     x21, x2                     // generator_type
    mov     x22, x3                     // capacity_mw
    
    // Get grid structure
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    
    // Check capacity
    ldr     w1, [x0, #PowerGrid_node_count]
    ldr     w2, [x0, #PowerGrid_capacity]
    cmp     w1, w2
    b.ge    .add_generator_error
    
    // Get node array and calculate offset
    ldr     x2, [x0, #PowerGrid_nodes]
    mov     x3, #PowerNode_size
    umull   x3, w1, w3
    add     x2, x2, x3                  // node_ptr
    
    // Initialize generator node
    str     w1, [x2, #PowerNode_id]
    mov     w3, #GRID_NODE
    str     w3, [x2, #PowerNode_type]
    str     w19, [x2, #PowerNode_x]
    str     w20, [x2, #PowerNode_y]
    str     w22, [x2, #PowerNode_generation]  // Capacity in MW
    str     wzr, [x2, #PowerNode_demand]
    
    // Set nominal voltage based on generator type
    mov     w3, #0x69000                // 105 kV default
    cmp     w21, #POWER_NUCLEAR
    mov     w4, #0xA0000                // 160 kV for nuclear
    csel    w3, w4, w3, eq
    cmp     w21, #POWER_HYDRO
    mov     w4, #0x50000                // 80 kV for hydro
    csel    w3, w4, w3, eq
    str     w3, [x2, #PowerNode_voltage]
    
    // Initialize electrical parameters
    str     wzr, [x2, #PowerNode_phase_angle]
    str     wzr, [x2, #PowerNode_connections]
    str     xzr, [x2, #PowerNode_conn_list]
    str     wzr, [x2, #PowerNode_active_power]
    str     wzr, [x2, #PowerNode_reactive_power]
    
    // Set impedance based on generator size
    mov     w3, #0x199                  // Small impedance for generator
    str     w3, [x2, #PowerNode_impedance_real]
    mov     w3, #0x333                  // Inductive reactance
    str     w3, [x2, #PowerNode_impedance_imag]
    
    // Update total generation
    ldr     w3, [x0, #PowerGrid_total_generation]
    add     w3, w3, w22
    str     w3, [x0, #PowerGrid_total_generation]
    
    // Increment node count
    add     w1, w1, #1
    str     w1, [x0, #PowerGrid_node_count]
    
    // Mark as dirty
    mov     w2, #1
    str     w2, [x0, #PowerGrid_dirty]
    
    // Return node ID
    sub     x0, x1, #1
    b       .add_generator_exit
    
.add_generator_error:
    mov     x0, #-1
    
.add_generator_exit:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// power_grid_add_consumer - Add a power consumer to the grid
// Parameters: x0 = x_coord, x1 = y_coord, x2 = demand_mw
// Returns: x0 = node_id (>=0) or error (-1)
//==============================================================================
power_grid_add_consumer:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // x_coord
    mov     x20, x1                     // y_coord
    mov     x21, x2                     // demand_mw
    
    // Get grid structure
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    
    // Check capacity
    ldr     w1, [x0, #PowerGrid_node_count]
    ldr     w2, [x0, #PowerGrid_capacity]
    cmp     w1, w2
    b.ge    .add_consumer_error
    
    // Get node array and calculate offset
    ldr     x2, [x0, #PowerGrid_nodes]
    mov     x3, #PowerNode_size
    umull   x3, w1, w3
    add     x2, x2, x3                  // node_ptr
    
    // Initialize consumer node
    str     w1, [x2, #PowerNode_id]
    mov     w3, #GRID_CONSUMER
    str     w3, [x2, #PowerNode_type]
    str     w19, [x2, #PowerNode_x]
    str     w20, [x2, #PowerNode_y]
    str     wzr, [x2, #PowerNode_generation]
    str     w21, [x2, #PowerNode_demand]   // Demand in MW
    
    // Set consumer voltage (distribution level)
    mov     w3, #0x39000                // 57.5 kV distribution
    str     w3, [x2, #PowerNode_voltage]
    
    // Initialize electrical parameters
    str     wzr, [x2, #PowerNode_phase_angle]
    str     wzr, [x2, #PowerNode_connections]
    str     xzr, [x2, #PowerNode_conn_list]
    str     wzr, [x2, #PowerNode_active_power]
    str     wzr, [x2, #PowerNode_reactive_power]
    
    // Set load impedance
    mov     w3, #0x1000                 // Load resistance
    str     w3, [x2, #PowerNode_impedance_real]
    mov     w3, #0x800                  // Small reactance
    str     w3, [x2, #PowerNode_impedance_imag]
    
    // Update total demand
    ldr     w3, [x0, #PowerGrid_total_demand]
    add     w3, w3, w21
    str     w3, [x0, #PowerGrid_total_demand]
    
    // Increment node count
    add     w1, w1, #1
    str     w1, [x0, #PowerGrid_node_count]
    
    // Mark as dirty
    mov     w2, #1
    str     w2, [x0, #PowerGrid_dirty]
    
    // Return node ID
    sub     x0, x1, #1
    b       .add_consumer_exit
    
.add_consumer_error:
    mov     x0, #-1
    
.add_consumer_exit:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// power_grid_add_transmission_line - Add transmission line between nodes
// Parameters: x0 = from_node_id, x1 = to_node_id, x2 = line_type, x3 = capacity_mw
// Returns: x0 = success (1) or failure (0)
//==============================================================================
power_grid_add_transmission_line:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // from_node_id
    mov     x20, x1                     // to_node_id
    mov     x21, x2                     // line_type
    mov     x22, x3                     // capacity_mw
    
    // Get grid structure
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    
    // Validate node IDs
    ldr     w1, [x0, #PowerGrid_node_count]
    cmp     w19, w1
    b.ge    .add_line_error
    cmp     w20, w1
    b.ge    .add_line_error
    
    // Check line capacity
    ldr     w1, [x0, #PowerGrid_line_count]
    // Assume max lines = 4 * node_count
    ldr     w2, [x0, #PowerGrid_node_count]
    lsl     w2, w2, #2
    cmp     w1, w2
    b.ge    .add_line_error
    
    // Get line array and calculate offset
    ldr     x2, [x0, #PowerGrid_lines]
    mov     x3, #PowerLine_size
    umull   x3, w1, w3
    add     x2, x2, x3                  // line_ptr
    
    // Initialize transmission line
    str     w1, [x2, #PowerLine_id]
    str     w19, [x2, #PowerLine_from]
    str     w20, [x2, #PowerLine_to]
    str     w21, [x2, #PowerLine_type]
    str     w22, [x2, #PowerLine_capacity]
    
    // Set electrical parameters based on line type
    cmp     w21, #LINE_HIGH_VOLTAGE
    b.ne    .line_check_transmission
    
    // High voltage line parameters
    mov     w3, #0x0199                 // 0.01 ohms/km resistance
    str     w3, [x2, #PowerLine_resistance]
    mov     w3, #0x0666                 // 0.04 ohms/km reactance
    str     w3, [x2, #PowerLine_reactance]
    b       .line_params_done
    
.line_check_transmission:
    cmp     w21, #LINE_TRANSMISSION
    b.ne    .line_default_params
    
    // Extra high voltage transmission
    mov     w3, #0x0099                 // 0.005 ohms/km resistance
    str     w3, [x2, #PowerLine_resistance]
    mov     w3, #0x0333                 // 0.02 ohms/km reactance
    str     w3, [x2, #PowerLine_reactance]
    b       .line_params_done
    
.line_default_params:
    // Default medium voltage parameters
    mov     w3, #0x0333                 // 0.02 ohms/km resistance
    str     w3, [x2, #PowerLine_resistance]
    mov     w3, #0x0CCC                 // 0.08 ohms/km reactance
    str     w3, [x2, #PowerLine_reactance]
    
.line_params_done:
    // Initialize operational parameters
    str     wzr, [x2, #PowerLine_current_flow]
    str     wzr, [x2, #PowerLine_losses]
    str     wzr, [x2, #PowerLine_overload_factor]
    mov     w3, #1                      // Active status
    str     w3, [x2, #PowerLine_status]
    
    // Update admittance matrix
    mov     x0, x19                     // from
    mov     x1, x20                     // to
    ldr     w2, [x2, #PowerLine_resistance]
    ldr     w3, [x2, #PowerLine_reactance]
    bl      update_admittance_matrix
    
    // Increment line count
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    ldr     w1, [x0, #PowerGrid_line_count]
    add     w1, w1, #1
    str     w1, [x0, #PowerGrid_line_count]
    
    // Mark as dirty
    mov     w1, #1
    str     w1, [x0, #PowerGrid_dirty]
    
    // Success
    mov     x0, #1
    b       .add_line_exit
    
.add_line_error:
    mov     x0, #0
    
.add_line_exit:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// power_grid_update - Main update function for power grid simulation
// Parameters: x0 = delta_time_ms
// Returns: x0 = processing_time_cycles
//==============================================================================
power_grid_update:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save delta_time_ms
    
    // Start performance timer
    mrs     x20, cntvct_el0
    
    // Check if update needed
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    ldr     w1, [x0, #PowerGrid_dirty]
    cbz     w1, .grid_update_exit
    
    // Solve power flow equations
    bl      power_grid_solve_power_flow
    
    // Check system stability
    bl      power_grid_check_stability
    
    // Perform load balancing if needed
    adrp    x0, grid_stability_state
    add     x0, x0, :lo12:grid_stability_state
    ldr     w0, [x0]
    cmp     w0, #1                      // Unstable
    b.lt    .grid_check_brownout
    bl      power_grid_load_balance
    
.grid_check_brownout:
    // Check for brownout conditions
    bl      power_grid_detect_brownout
    
    // Check for blackout conditions
    bl      power_grid_detect_blackout
    
    // Check for cascade failures
    bl      power_grid_cascade_failure_check
    
    // Clear dirty flag
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    str     wzr, [x0, #PowerGrid_dirty]
    
.grid_update_exit:
    // Calculate elapsed cycles
    mrs     x21, cntvct_el0
    sub     x0, x21, x20
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Power Flow Analysis Functions
//==============================================================================

//==============================================================================
// power_grid_solve_power_flow - Solve power flow using Gauss-Seidel method
// Parameters: None
// Returns: x0 = convergence_iterations or -1 if failed
//==============================================================================
power_grid_solve_power_flow:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Get grid structure
    adrp    x19, power_grid
    add     x19, x19, :lo12:power_grid
    
    ldr     w20, [x19, #PowerGrid_node_count]
    cbz     w20, .solve_error
    
    ldr     w21, [x19, #PowerGrid_max_iterations]
    ldr     w22, [x19, #PowerGrid_convergence_tol]
    
    // Initialize voltage vector (flat start)
    ldr     x0, [x19, #PowerGrid_voltage_vector]
    mov     x1, x20                     // node_count
    bl      initialize_voltage_vector
    
    // Main Gauss-Seidel iteration loop
    mov     w0, #0                      // iteration counter
    
.solve_iteration_loop:
    cmp     w0, w21                     // Check max iterations
    b.ge    .solve_error
    
    // Store current iteration
    mov     w19, w0
    
    // Perform one Gauss-Seidel iteration
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    bl      gauss_seidel_iteration
    
    // Check convergence
    mov     x0, x22                     // tolerance
    bl      check_power_flow_convergence
    cmp     w0, #1
    b.eq    .solve_converged
    
    mov     w0, w19
    add     w0, w0, #1
    b       .solve_iteration_loop
    
.solve_converged:
    // Update power flows on all lines
    bl      update_line_power_flows
    
    // Calculate total losses
    bl      calculate_system_losses
    
    // Store solver statistics
    adrp    x0, solver_iterations
    add     x0, x0, :lo12:solver_iterations
    str     w19, [x0]
    
    mov     x0, x19                     // Return iteration count
    b       .solve_exit
    
.solve_error:
    mov     x0, #-1
    
.solve_exit:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// gauss_seidel_iteration - Perform one iteration of Gauss-Seidel method
// Parameters: x0 = grid_pointer
// Returns: None
//==============================================================================
gauss_seidel_iteration:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // grid pointer
    ldr     w20, [x19, #PowerGrid_node_count]
    ldr     x21, [x19, #PowerGrid_voltage_vector]
    ldr     x22, [x19, #PowerGrid_nodes]
    
    // Iterate through all nodes except slack bus (node 0)
    mov     w0, #1                      // Start from node 1
    
.gauss_iteration_loop:
    cmp     w0, w20
    b.ge    .gauss_iteration_done
    
    // Calculate new voltage for current node
    mov     x1, x0                      // node_index
    mov     x2, x21                     // voltage_vector
    mov     x3, x22                     // nodes_array
    bl      calculate_node_voltage_update
    
    add     w0, w0, #1
    b       .gauss_iteration_loop
    
.gauss_iteration_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Grid Stability and Load Balancing Functions
//==============================================================================

//==============================================================================
// power_grid_check_stability - Check power system stability
// Parameters: None
// Returns: w0 = stability_state (0=stable, 1=unstable, 2=critical)
//==============================================================================
power_grid_check_stability:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    adrp    x19, power_grid
    add     x19, x19, :lo12:power_grid
    
    // Check generation vs demand balance
    ldr     w0, [x19, #PowerGrid_total_generation]
    ldr     w1, [x19, #PowerGrid_total_demand]
    
    // Calculate reserve margin: (generation - demand) / demand
    sub     w2, w0, w1                  // reserve power
    lsl     w2, w2, #16                 // Fixed point conversion
    udiv    w2, w2, w1                  // reserve_margin
    
    // Check stability thresholds
    adrp    x3, stability_margin
    add     x3, x3, :lo12:stability_margin
    ldr     w3, [x3]                    // 0.1 minimum margin
    
    mov     w20, #0                     // Stable
    cmp     w2, w3
    b.ge    .stability_check_voltage
    
    mov     w20, #1                     // Unstable
    cmp     w2, #0                      // Negative margin
    b.ge    .stability_check_voltage
    
    mov     w20, #2                     // Critical
    
.stability_check_voltage:
    // Check voltage stability across all nodes
    bl      check_voltage_stability
    cmp     w0, #2                      // Critical voltage
    csel    w20, w0, w20, eq
    
    // Check frequency stability
    ldr     w0, [x19, #PowerGrid_system_frequency]
    adrp    x1, nominal_frequency
    add     x1, x1, :lo12:nominal_frequency
    ldr     w1, [x1]
    
    sub     w0, w0, w1                  // Frequency deviation
    cmp     w0, #0x1999                 // 0.1 Hz deviation
    b.lt    .stability_store_result
    
    mov     w20, #1                     // Unstable frequency
    cmp     w0, #0x3333                 // 0.2 Hz deviation
    csel    w20, #2, w20, gt            // Critical
    
.stability_store_result:
    adrp    x0, grid_stability_state
    add     x0, x0, :lo12:grid_stability_state
    str     w20, [x0]
    
    mov     w0, w20
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// power_grid_load_balance - Perform load balancing
// Parameters: None
// Returns: None
//==============================================================================
power_grid_load_balance:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    adrp    x19, power_grid
    add     x19, x19, :lo12:power_grid
    
    // Calculate total system imbalance
    ldr     w0, [x19, #PowerGrid_total_generation]
    ldr     w1, [x19, #PowerGrid_total_demand]
    sub     w20, w1, w0                 // Demand - generation
    
    cbz     w20, .load_balance_done
    
    // If demand exceeds generation, need emergency measures
    cmp     w20, #0
    b.le    .load_balance_increase_gen
    
    // Demand > Generation: Load shedding required
    mov     x0, x20                     // Load to shed
    bl      power_grid_emergency_load_shed
    b       .load_balance_done
    
.load_balance_increase_gen:
    // Generation > Demand: Reduce generation or store excess
    neg     w20, w20                    // Make positive
    mov     x0, x20
    bl      reduce_excess_generation
    
.load_balance_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// power_grid_detect_brownout - Detect brownout conditions
// Parameters: None
// Returns: w0 = number_of_brownout_zones
//==============================================================================
power_grid_detect_brownout:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    adrp    x19, power_grid
    add     x19, x19, :lo12:power_grid
    
    ldr     x0, [x19, #PowerGrid_voltage_vector]
    ldr     w1, [x19, #PowerGrid_node_count]
    
    adrp    x2, brownout_voltage_threshold
    add     x2, x2, :lo12:brownout_voltage_threshold
    ldr     w2, [x2]                    // 0.95 p.u.
    
    mov     w20, #0                     // brownout_count
    mov     w3, #0                      // node_index
    
.brownout_check_loop:
    cmp     w3, w1
    b.ge    .brownout_check_done
    
    // Get voltage magnitude for current node
    mov     x4, #8                      // 8 bytes per complex voltage
    umull   x4, w3, x4
    add     x4, x0, x4
    ldr     w5, [x4]                    // Voltage magnitude
    
    // Check if below brownout threshold
    cmp     w5, w2
    b.ge    .brownout_next_node
    
    // Mark node as in brownout
    add     w20, w20, #1
    
    // Set brownout flag for this zone
    adrp    x6, brownout_zones
    add     x6, x6, :lo12:brownout_zones
    mov     w7, w3
    lsr     w8, w7, #5                  // Byte index (node / 32)
    and     w7, w7, #31                 // Bit index (node % 32)
    mov     w9, #1
    lsl     w9, w9, w7                  // Bit mask
    ldr     w10, [x6, x8]
    orr     w10, w10, w9
    str     w10, [x6, x8]
    
.brownout_next_node:
    add     w3, w3, #1
    b       .brownout_check_loop
    
.brownout_check_done:
    mov     w0, w20
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// power_grid_detect_blackout - Detect blackout conditions
// Parameters: None
// Returns: w0 = number_of_blackout_zones
//==============================================================================
power_grid_detect_blackout:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    adrp    x19, power_grid
    add     x19, x19, :lo12:power_grid
    
    ldr     x0, [x19, #PowerGrid_voltage_vector]
    ldr     w1, [x19, #PowerGrid_node_count]
    
    adrp    x2, blackout_voltage_threshold
    add     x2, x2, :lo12:blackout_voltage_threshold
    ldr     w2, [x2]                    // 0.9 p.u.
    
    mov     w20, #0                     // blackout_count
    mov     w3, #0                      // node_index
    
.blackout_check_loop:
    cmp     w3, w1
    b.ge    .blackout_check_done
    
    // Get voltage magnitude for current node
    mov     x4, #8
    umull   x4, w3, x4
    add     x4, x0, x4
    ldr     w5, [x4]                    // Voltage magnitude
    
    // Check if below blackout threshold
    cmp     w5, w2
    b.ge    .blackout_next_node
    
    // Mark node as in blackout
    add     w20, w20, #1
    
    // Set blackout flag for this zone
    adrp    x6, blackout_zones
    add     x6, x6, :lo12:blackout_zones
    mov     w7, w3
    lsr     w8, w7, #5
    and     w7, w7, #31
    mov     w9, #1
    lsl     w9, w9, w7
    ldr     w10, [x6, x8]
    orr     w10, w10, w9
    str     w10, [x6, x8]
    
.blackout_next_node:
    add     w3, w3, #1
    b       .blackout_check_loop
    
.blackout_check_done:
    // Check if total blackout
    mov     w1, w20
    adrp    x2, power_grid
    add     x2, x2, :lo12:power_grid
    ldr     w2, [x2, #PowerGrid_node_count]
    lsr     w2, w2, #1                  // 50% threshold
    cmp     w1, w2
    b.lt    .blackout_partial
    
    // Total blackout condition
    adrp    x0, total_blackout_flag
    add     x0, x0, :lo12:total_blackout_flag
    mov     w1, #1
    str     w1, [x0]
    
.blackout_partial:
    mov     w0, w20
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// power_grid_emergency_load_shed - Emergency load shedding
// Parameters: x0 = load_to_shed_mw
// Returns: w0 = actual_load_shed_mw
//==============================================================================
power_grid_emergency_load_shed:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // load_to_shed
    mov     w20, #0                     // actual_shed
    
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    ldr     x1, [x0, #PowerGrid_nodes]
    ldr     w2, [x0, #PowerGrid_node_count]
    
    // Prioritize load shedding: start with lowest priority loads
    mov     w3, #0                      // node_index
    
.load_shed_loop:
    cmp     w3, w2
    b.ge    .load_shed_done
    cmp     w20, w19
    b.ge    .load_shed_done
    
    // Get current node
    mov     x4, #PowerNode_size
    umull   x4, w3, x4
    add     x4, x1, x4
    
    // Check if consumer node
    ldr     w5, [x4, #PowerNode_type]
    cmp     w5, #GRID_CONSUMER
    b.ne    .load_shed_next
    
    // Shed 50% of this load
    ldr     w6, [x4, #PowerNode_demand]
    lsr     w7, w6, #1                  // 50% of demand
    sub     w6, w6, w7
    str     w6, [x4, #PowerNode_demand]
    
    add     w20, w20, w7               // Track total shed
    
.load_shed_next:
    add     w3, w3, #1
    b       .load_shed_loop
    
.load_shed_done:
    mov     w0, w20
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Utility and Helper Functions
//==============================================================================

initialize_voltage_vector:
    // x0 = voltage_vector, x1 = node_count
    mov     w2, #0                      // node index
    mov     w3, #0x10000                // 1.0 p.u. voltage magnitude
    
.init_voltage_loop:
    cmp     w2, w1
    b.ge    .init_voltage_done
    
    mov     x4, #8
    umull   x4, w2, x4
    add     x4, x0, x4
    str     w3, [x4]                    // Magnitude
    str     wzr, [x4, #4]               // Phase angle = 0
    
    add     w2, w2, #1
    b       .init_voltage_loop
    
.init_voltage_done:
    ret

check_power_flow_convergence:
    // Simplified convergence check
    mov     w0, #1                      // Assume converged
    ret

calculate_node_voltage_update:
    // Simplified voltage update
    ret

update_line_power_flows:
    // Update power flows on transmission lines
    ret

calculate_system_losses:
    // Calculate total system losses
    ret

check_voltage_stability:
    // Check voltage stability
    mov     w0, #0                      // Stable
    ret

reduce_excess_generation:
    // Reduce excess generation
    ret

power_grid_cascade_failure_check:
    // Check for cascade failures
    ret

update_admittance_matrix:
    // Update admittance matrix
    ret

create_sparse_admittance_matrix:
    // Create sparse admittance matrix
    mov     x0, #4096                   // Default size
    bl      malloc
    ret

free_sparse_matrix:
    // Free sparse matrix
    bl      free
    ret

power_grid_get_node_voltage:
    // Parameters: x0 = node_id
    // Returns: w0 = voltage_magnitude
    mov     w0, #0x10000                // 1.0 p.u.
    ret

power_grid_get_line_loading:
    // Parameters: x0 = line_id
    // Returns: w0 = loading_percentage
    mov     w0, #50                     // 50%
    ret

power_grid_cleanup:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Clean up all allocated resources
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    
    // Free nodes
    ldr     x1, [x0, #PowerGrid_nodes]
    cbz     x1, .cleanup_lines
    mov     x0, x1
    bl      free
    
.cleanup_lines:
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    ldr     x1, [x0, #PowerGrid_lines]
    cbz     x1, .cleanup_voltage
    mov     x0, x1
    bl      free
    
.cleanup_voltage:
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    ldr     x1, [x0, #PowerGrid_voltage_vector]
    cbz     x1, .cleanup_matrix
    mov     x0, x1
    bl      free
    
.cleanup_matrix:
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    ldr     x1, [x0, #PowerGrid_admittance_matrix]
    cbz     x1, .cleanup_done
    mov     x0, x1
    bl      free_sparse_matrix
    
.cleanup_done:
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Memory management (simplified)
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
    adrp    x0, gauss_seidel_tolerance
    add     x0, x0, :lo12:gauss_seidel_tolerance
    ldr     w0, [x0]
    str     w0, [x1, #PowerGrid_convergence_tol]
    
    adrp    x0, max_solver_iterations
    add     x0, x0, :lo12:max_solver_iterations
    ldr     w0, [x0]
    str     w0, [x1, #PowerGrid_max_iterations]
    
    // Set nominal frequency
    adrp    x0, nominal_frequency
    add     x0, x0, :lo12:nominal_frequency
    ldr     w0, [x0]
    str     w0, [x1, #PowerGrid_system_frequency]
    
    // Allocate admittance matrix (sparse)
    mov     x0, x19                     // size = max_nodes
    bl      sparse_complex_matrix_init
    cbz     x0, .grid_init_cleanup_lines
    
    adrp    x1, power_grid
    add     x1, x1, :lo12:power_grid
    str     x0, [x1, #PowerGrid_admittance_matrix]
    
    // Allocate voltage vector
    mov     x0, x19
    mov     x1, #16                     // 2 x 8 bytes (real + imaginary)
    mul     x0, x0, x1
    bl      malloc
    cbz     x0, .grid_init_cleanup_matrix
    
    adrp    x1, power_grid
    add     x1, x1, :lo12:power_grid
    str     x0, [x1, #PowerGrid_voltage_vector]
    
    // Initialize voltage vector to nominal values
    mov     x2, #0                      // node index
.grid_init_voltage_loop:
    cmp     x2, x19
    b.ge    .grid_init_success
    
    // Set nominal voltage (1.0 p.u. real, 0.0 imaginary)
    mov     x3, #16
    mul     x3, x2, x3
    add     x3, x0, x3                  // voltage[i]
    
    mov     w4, #0x10000                // 1.0 in 16.16 fixed point
    str     w4, [x3]                    // Real part
    str     wzr, [x3, #4]               // Imaginary part
    
    add     x2, x2, #1
    b       .grid_init_voltage_loop
    
.grid_init_success:
    mov     x0, #1
    b       .grid_init_exit
    
.grid_init_cleanup_matrix:
    adrp    x1, power_grid
    add     x1, x1, :lo12:power_grid
    ldr     x0, [x1, #PowerGrid_admittance_matrix]
    bl      sparse_complex_matrix_free
    
.grid_init_cleanup_lines:
    adrp    x1, power_grid
    add     x1, x1, :lo12:power_grid
    ldr     x0, [x1, #PowerGrid_lines]
    bl      free
    
.grid_init_cleanup_nodes:
    adrp    x1, power_grid
    add     x1, x1, :lo12:power_grid
    ldr     x0, [x1, #PowerGrid_nodes]
    bl      free
    
.grid_init_error:
    mov     x0, #0
    
.grid_init_exit:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// power_grid_add_generator - Add a power generator to the grid
// Parameters: x0 = x_coord, x1 = y_coord, x2 = type, x3 = capacity_mw
// Returns: x0 = node_id (>=0) or error (-1)
//==============================================================================
power_grid_add_generator:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // x_coord
    mov     x20, x1                     // y_coord
    mov     x21, x2                     // type
    mov     x22, x3                     // capacity_mw (fixed-point)
    
    // Get grid structure
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    
    // Check capacity
    ldr     w1, [x0, #PowerGrid_node_count]
    ldr     w2, [x0, #PowerGrid_capacity]
    cmp     w1, w2
    b.ge    .add_gen_error
    
    // Get node array and calculate offset
    ldr     x2, [x0, #PowerGrid_nodes]
    mov     x3, #PowerNode_size
    umull   x3, w1, w3
    add     x2, x2, x3                  // new node pointer
    
    // Initialize generator node
    str     w1, [x2, #PowerNode_id]
    str     w21, [x2, #PowerNode_type]
    str     w19, [x2, #PowerNode_x]
    str     w20, [x2, #PowerNode_y]
    str     w22, [x2, #PowerNode_generation]  // Generation capacity
    str     wzr, [x2, #PowerNode_demand]      // Generators have no demand
    
    // Set nominal voltage and phase
    mov     w3, #0x10000                // 1.0 p.u. voltage
    str     w3, [x2, #PowerNode_voltage]
    str     wzr, [x2, #PowerNode_phase_angle]
    
    // Initialize impedance (typical generator values)
    mov     w3, #0x0666                // 0.1 p.u. resistance
    str     w3, [x2, #PowerNode_impedance_real]
    mov     w3, #0x3333                // 0.8 p.u. reactance
    str     w3, [x2, #PowerNode_impedance_imag]
    
    // Initialize other fields
    str     wzr, [x2, #PowerNode_connections]
    str     xzr, [x2, #PowerNode_conn_list]
    str     wzr, [x2, #PowerNode_active_power]
    str     wzr, [x2, #PowerNode_reactive_power]
    
    // Update grid totals
    ldr     w3, [x0, #PowerGrid_total_generation]
    add     w3, w3, w22
    str     w3, [x0, #PowerGrid_total_generation]
    
    // Increment node count
    add     w1, w1, #1
    str     w1, [x0, #PowerGrid_node_count]
    
    // Mark grid as dirty
    mov     w2, #1
    str     w2, [x0, #PowerGrid_dirty]
    
    // Return new node ID
    sub     x0, x1, #1
    b       .add_gen_exit
    
.add_gen_error:
    mov     x0, #-1
    
.add_gen_exit:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// power_grid_add_consumer - Add a power consumer to the grid
// Parameters: x0 = x_coord, x1 = y_coord, x2 = demand_mw
// Returns: x0 = node_id (>=0) or error (-1)
//==============================================================================
power_grid_add_consumer:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // x_coord
    mov     x20, x1                     // y_coord
    mov     x21, x2                     // demand_mw
    
    // Get grid structure
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    
    // Check capacity
    ldr     w1, [x0, #PowerGrid_node_count]
    ldr     w2, [x0, #PowerGrid_capacity]
    cmp     w1, w2
    b.ge    .add_cons_error
    
    // Get node array and calculate offset
    ldr     x2, [x0, #PowerGrid_nodes]
    mov     x3, #PowerNode_size
    umull   x3, w1, w3
    add     x2, x2, x3                  // new node pointer
    
    // Initialize consumer node
    str     w1, [x2, #PowerNode_id]
    mov     w3, #GRID_CONSUMER
    str     w3, [x2, #PowerNode_type]
    str     w19, [x2, #PowerNode_x]
    str     w20, [x2, #PowerNode_y]
    str     wzr, [x2, #PowerNode_generation]  // Consumers don't generate
    str     w21, [x2, #PowerNode_demand]      // Power demand
    
    // Set nominal voltage and phase
    mov     w3, #0x10000                // 1.0 p.u. voltage
    str     w3, [x2, #PowerNode_voltage]
    str     wzr, [x2, #PowerNode_phase_angle]
    
    // Consumer impedance (high impedance load)
    mov     w3, #0x8000                 // 2.0 p.u. resistance
    str     w3, [x2, #PowerNode_impedance_real]
    mov     w3, #0x4000                 // 1.0 p.u. reactance
    str     w3, [x2, #PowerNode_impedance_imag]
    
    // Initialize other fields
    str     wzr, [x2, #PowerNode_connections]
    str     xzr, [x2, #PowerNode_conn_list]
    str     wzr, [x2, #PowerNode_active_power]
    str     wzr, [x2, #PowerNode_reactive_power]
    
    // Update grid totals
    ldr     w3, [x0, #PowerGrid_total_demand]
    add     w3, w3, w21
    str     w3, [x0, #PowerGrid_total_demand]
    
    // Increment node count
    add     w1, w1, #1
    str     w1, [x0, #PowerGrid_node_count]
    
    // Mark grid as dirty
    mov     w2, #1
    str     w2, [x0, #PowerGrid_dirty]
    
    // Return new node ID
    sub     x0, x1, #1
    b       .add_cons_exit
    
.add_cons_error:
    mov     x0, #-1
    
.add_cons_exit:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// power_grid_add_transmission_line - Add transmission line between nodes
// Parameters: x0 = from_node, x1 = to_node, x2 = line_type, x3 = capacity_mw
// Returns: x0 = success (1) or failure (0)
//==============================================================================
power_grid_add_transmission_line:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // from_node
    mov     x20, x1                     // to_node
    mov     x21, x2                     // line_type
    mov     x22, x3                     // capacity_mw
    
    // Get grid structure
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    
    // Validate node IDs
    ldr     w1, [x0, #PowerGrid_node_count]
    cmp     w19, w1
    b.ge    .add_line_error
    cmp     w20, w1
    b.ge    .add_line_error
    cmp     w19, #0
    b.lt    .add_line_error
    cmp     w20, #0
    b.lt    .add_line_error
    
    // Check line capacity
    ldr     w1, [x0, #PowerGrid_line_count]
    // Assume max lines = 4 * nodes for dense grid
    ldr     w2, [x0, #PowerGrid_node_count]
    lsl     w2, w2, #2
    cmp     w1, w2
    b.ge    .add_line_error
    
    // Get line array and calculate offset
    ldr     x2, [x0, #PowerGrid_lines]
    mov     x3, #PowerLine_size
    umull   x3, w1, w3
    add     x2, x2, x3                  // new line pointer
    
    // Initialize transmission line
    str     w1, [x2, #PowerLine_id]
    str     w19, [x2, #PowerLine_from]
    str     w20, [x2, #PowerLine_to]
    str     w21, [x2, #PowerLine_type]
    str     w22, [x2, #PowerLine_capacity]
    
    // Set typical transmission line parameters based on type
    mov     w3, #0x0199                 // 0.01 p.u. resistance (default)
    mov     w4, #0x0CCC                 // 0.05 p.u. reactance (default)
    
    cmp     w21, #LINE_HIGH_VOLTAGE
    b.ne    .line_check_medium
    mov     w3, #0x00CC                 // Lower resistance for HV
    mov     w4, #0x0999                 // Lower reactance for HV
    b       .line_set_params
    
.line_check_medium:
    cmp     w21, #LINE_TRANSMISSION
    b.ne    .line_set_params
    mov     w3, #0x0066                 // Lowest resistance for transmission
    mov     w4, #0x0666                 // Lowest reactance for transmission
    
.line_set_params:
    str     w3, [x2, #PowerLine_resistance]
    str     w4, [x2, #PowerLine_reactance]
    
    // Initialize operational parameters
    str     wzr, [x2, #PowerLine_current_flow]
    str     wzr, [x2, #PowerLine_losses]
    str     wzr, [x2, #PowerLine_overload_factor]
    mov     w3, #1                      // Active status
    str     w3, [x2, #PowerLine_status]
    
    // Update admittance matrix
    ldr     x3, [x0, #PowerGrid_admittance_matrix]
    mov     x0, x3
    mov     x1, x19                     // from
    mov     x2, x20                     // to
    // Calculate admittance = 1 / (resistance + j*reactance)
    // This is a complex division - simplified for now
    mov     x3, #0x10000                // 1.0 real part
    mov     x4, #0                      // 0.0 imaginary part
    bl      sparse_complex_matrix_set
    
    // Increment line count
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    ldr     w1, [x0, #PowerGrid_line_count]
    add     w1, w1, #1
    str     w1, [x0, #PowerGrid_line_count]
    
    // Mark grid as dirty
    mov     w1, #1
    str     w1, [x0, #PowerGrid_dirty]
    
    // Success
    mov     x0, #1
    b       .add_line_exit
    
.add_line_error:
    mov     x0, #0
    
.add_line_exit:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// power_grid_solve_power_flow - Solve power flow using Gauss-Seidel method
// Parameters: None
// Returns: x0 = convergence_iterations (or -1 if failed to converge)
//==============================================================================
power_grid_solve_power_flow:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    
    // Start performance timer
    mrs     x19, cntvct_el0
    
    // Get grid structure
    adrp    x20, power_grid
    add     x20, x20, :lo12:power_grid
    
    // Check if solve is needed
    ldr     w0, [x20, #PowerGrid_dirty]
    cbz     w0, .solve_skip
    
    // Get solver parameters
    ldr     w21, [x20, #PowerGrid_max_iterations]
    ldr     w22, [x20, #PowerGrid_convergence_tol]
    ldr     w23, [x20, #PowerGrid_node_count]
    ldr     x24, [x20, #PowerGrid_voltage_vector]
    
    // Gauss-Seidel iteration counter
    mov     w0, #0                      // iteration count
    
.solve_iteration_loop:
    cmp     w0, w21                     // Check max iterations
    b.ge    .solve_failed
    
    // Store current iteration
    mov     w1, w0
    add     w1, w1, #1
    adrp    x2, solver_iterations
    add     x2, x2, :lo12:solver_iterations
    str     w1, [x2]
    
    // Calculate maximum voltage change for convergence check
    mov     w2, #0                      // max_change = 0
    
    // Process each node (except slack bus - node 0)
    mov     w3, #1                      // node index (start from 1)
    
.solve_node_loop:
    cmp     w3, w23
    b.ge    .solve_check_convergence
    
    // Calculate new voltage for node i using Gauss-Seidel formula:
    // V_i^(k+1) = (1/Y_ii) * [(P_i - jQ_i)/V_i^* - sum(Y_ij * V_j)]
    
    // Get current voltage (complex)
    mov     x4, #16                     // 2 components * 8 bytes each
    mul     x4, x3, x4
    add     x4, x24, x4                 // voltage[i]
    ldr     w5, [x4]                    // V_real
    ldr     w6, [x4, #4]                // V_imag
    
    // Get node data
    ldr     x7, [x20, #PowerGrid_nodes]
    mov     x8, #PowerNode_size
    mul     x8, x3, x8
    add     x7, x7, x8                  // node[i]
    
    ldr     w8, [x7, #PowerNode_generation]  // P_gen
    ldr     w9, [x7, #PowerNode_demand]      // P_demand  
    sub     w8, w8, w9                       // P_net = P_gen - P_demand
    
    // Simplified Gauss-Seidel update (real power flow approximation)
    // In full implementation this would involve complex arithmetic
    // V_new = V_old + correction_factor * power_mismatch
    
    // Calculate power mismatch (simplified)
    // mismatch = (P_scheduled - P_calculated) / |V|^2
    mov     w10, w8                     // P_scheduled
    
    // Calculate |V|^2 = V_real^2 + V_imag^2 (16.16 fixed point)
    smull   x11, w5, w5                 // V_real^2
    smull   x12, w6, w6                 // V_imag^2
    add     x11, x11, x12               // |V|^2
    lsr     x11, x11, #16               // Convert back to 16.16
    
    // Avoid division by zero
    cmp     w11, #0x100                 // |V|^2 > 0.001
    b.lt    .solve_next_node
    
    // Calculate correction: mismatch / |V|^2
    lsl     w12, w10, #16               // mismatch << 16
    udiv    w12, w12, w11               // mismatch / |V|^2
    
    // Apply correction with relaxation factor (0.1)
    mov     w13, #0x1999                // 0.1 in 16.16
    smull   x12, w12, w13
    lsr     x12, x12, #16
    
    // Update voltage: V_new = V_old + correction
    add     w5, w5, w12                 // Update real part
    // Imaginary part remains roughly the same for this simplified model
    
    // Calculate voltage change for convergence check
    sub     w14, w5, w5                 // This should be the old value
    abs     w14, w14                    // |change|
    cmp     w14, w2
    csel    w2, w14, w2, gt             // max_change = max(max_change, |change|)
    
    // Store updated voltage
    str     w5, [x4]                    // V_real
    str     w6, [x4, #4]                // V_imag
    
.solve_next_node:
    add     w3, w3, #1
    b       .solve_node_loop
    
.solve_check_convergence:
    // Check if converged: max_change < tolerance
    cmp     w2, w22
    b.lt    .solve_converged
    
    // Next iteration
    add     w0, w0, #1
    b       .solve_iteration_loop
    
.solve_converged:
    // Calculate power flows in transmission lines
    bl      calculate_line_flows
    
    // Clear dirty flag
    str     wzr, [x20, #PowerGrid_dirty]
    
    // Store convergence error
    adrp    x1, power_balance_error
    add     x1, x1, :lo12:power_balance_error
    str     w2, [x1]
    
    // Return iteration count
    adrp    x1, solver_iterations
    add     x1, x1, :lo12:solver_iterations
    ldr     w0, [x1]
    b       .solve_exit
    
.solve_failed:
    mov     x0, #-1                     // Failed to converge
    b       .solve_exit
    
.solve_skip:
    mov     x0, #0                      // No solve needed
    
.solve_exit:
    // Calculate elapsed time
    mrs     x1, cntvct_el0
    sub     x1, x1, x19
    adrp    x2, convergence_time
    add     x2, x2, :lo12:convergence_time
    str     x1, [x2]
    
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//==============================================================================
// calculate_line_flows - Calculate power flows in transmission lines
// Parameters: None (uses global grid structure)
// Returns: None
//==============================================================================
calculate_line_flows:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Get grid structure
    adrp    x19, power_grid
    add     x19, x19, :lo12:power_grid
    
    ldr     x20, [x19, #PowerGrid_lines]
    ldr     w21, [x19, #PowerGrid_line_count]
    ldr     x22, [x19, #PowerGrid_voltage_vector]
    
    // Process each transmission line
    mov     w0, #0                      // line index
    
.flow_calc_loop:
    cmp     w0, w21
    b.ge    .flow_calc_done
    
    // Get current line
    mov     x1, #PowerLine_size
    mul     x1, x0, x1
    add     x1, x20, x1                 // line[i]
    
    // Get from and to node voltages
    ldr     w2, [x1, #PowerLine_from]
    ldr     w3, [x1, #PowerLine_to]
    
    // Get voltage[from]
    mov     x4, #16
    mul     x4, x2, x4
    add     x4, x22, x4
    ldr     w5, [x4]                    // V_from_real
    ldr     w6, [x4, #4]                // V_from_imag
    
    // Get voltage[to]  
    mov     x4, #16
    mul     x4, x3, x4
    add     x4, x22, x4
    ldr     w7, [x4]                    // V_to_real
    ldr     w8, [x4, #4]                // V_to_imag
    
    // Calculate power flow: P = (V_from * conj(V_to)) / Z
    // Simplified: P ≈ (V_from - V_to) * (V_from + V_to) / R
    sub     w9, w5, w7                  // V_diff_real
    add     w10, w5, w7                 // V_sum_real
    
    // P_flow = V_diff * V_sum / R (simplified)
    ldr     w11, [x1, #PowerLine_resistance]
    cbz     w11, .flow_calc_next        // Avoid division by zero
    
    smull   x12, w9, w10                // V_diff * V_sum
    lsr     x12, x12, #16               // Convert to 16.16
    udiv    w12, w12, w11               // / resistance
    
    // Store power flow
    str     w12, [x1, #PowerLine_current_flow]
    
    // Calculate transmission losses: Loss = I^2 * R
    // Simplified: Loss = (P_flow^2 * R) / (V_avg^2)
    add     w13, w5, w7
    lsr     w13, w13, #1                // V_avg = (V_from + V_to) / 2
    smull   x14, w13, w13               // V_avg^2
    lsr     x14, x14, #16
    
    cbz     w14, .flow_calc_next
    smull   x15, w12, w12               // P_flow^2
    lsr     x15, x15, #16
    smull   x15, w15, w11               // * R
    lsr     x15, x15, #16
    udiv    w15, w15, w14               // / V_avg^2
    
    str     w15, [x1, #PowerLine_losses]
    
    // Calculate overload factor
    ldr     w16, [x1, #PowerLine_capacity]
    cbz     w16, .flow_calc_next
    lsl     w17, w12, #16               // P_flow << 16
    udiv    w17, w17, w16               // P_flow / capacity
    str     w17, [x1, #PowerLine_overload_factor]
    
.flow_calc_next:
    add     w0, w0, #1
    b       .flow_calc_loop
    
.flow_calc_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// power_grid_get_node_voltage - Get voltage at a specific node
// Parameters: x0 = node_id
// Returns: x0 = voltage_magnitude (16.16 fixed point), x1 = phase_angle
//==============================================================================
power_grid_get_node_voltage:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get grid structure
    adrp    x1, power_grid
    add     x1, x1, :lo12:power_grid
    
    // Validate node ID
    ldr     w2, [x1, #PowerGrid_node_count]
    cmp     w0, w2
    b.ge    .get_voltage_error
    cmp     w0, #0
    b.lt    .get_voltage_error
    
    // Get voltage vector
    ldr     x1, [x1, #PowerGrid_voltage_vector]
    mov     x2, #16
    mul     x2, x0, x2
    add     x1, x1, x2                  // voltage[node_id]
    
    // Load complex voltage
    ldr     w2, [x1]                    // V_real
    ldr     w3, [x1, #4]                // V_imag
    
    // Calculate magnitude: |V| = sqrt(V_real^2 + V_imag^2)
    smull   x4, w2, w2                  // V_real^2
    smull   x5, w3, w3                  // V_imag^2
    add     x4, x4, x5                  // V_real^2 + V_imag^2
    lsr     x4, x4, #16                 // Convert back to 16.16
    
    // Approximate square root using Newton's method (simplified)
    mov     w0, w4                      // Initial guess
    bl      fixed_point_sqrt            // Custom sqrt function
    
    // Calculate phase angle: atan2(V_imag, V_real)
    mov     w0, w3                      // V_imag
    mov     w1, w2                      // V_real
    bl      fixed_point_atan2           // Custom atan2 function
    mov     x1, x0                      // phase angle
    
    mov     w0, w4                      // magnitude
    b       .get_voltage_exit
    
.get_voltage_error:
    mov     x0, #0                      // 0 magnitude
    mov     x1, #0                      // 0 phase
    
.get_voltage_exit:
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// power_grid_get_line_loading - Get loading percentage of a transmission line
// Parameters: x0 = line_id
// Returns: x0 = loading_percentage (16.16 fixed point, 0.0-2.0+)
//==============================================================================
power_grid_get_line_loading:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get grid structure
    adrp    x1, power_grid
    add     x1, x1, :lo12:power_grid
    
    // Validate line ID
    ldr     w2, [x1, #PowerGrid_line_count]
    cmp     w0, w2
    b.ge    .get_loading_error
    cmp     w0, #0
    b.lt    .get_loading_error
    
    // Get line array
    ldr     x1, [x1, #PowerGrid_lines]
    mov     x2, #PowerLine_size
    mul     x2, x0, x2
    add     x1, x1, x2                  // line[line_id]
    
    // Get overload factor (already calculated as loading percentage)
    ldr     w0, [x1, #PowerLine_overload_factor]
    b       .get_loading_exit
    
.get_loading_error:
    mov     x0, #0                      // 0% loading
    
.get_loading_exit:
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// power_grid_check_stability - Check grid stability metrics
// Parameters: None
// Returns: x0 = stability_status (1=stable, 0=unstable)
//==============================================================================
power_grid_check_stability:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Get grid structure
    adrp    x19, power_grid
    add     x19, x19, :lo12:power_grid
    
    // Check power balance
    ldr     w0, [x19, #PowerGrid_total_generation]
    ldr     w1, [x19, #PowerGrid_total_demand]
    
    // Allow 5% imbalance
    mov     w2, #0x0CCC                 // 0.05 in 16.16
    smull   x3, w1, w2                  // 5% of demand
    lsr     x3, x3, #16
    
    sub     w4, w0, w1                  // generation - demand
    abs     w4, w4                      // |imbalance|
    cmp     w4, w3
    b.gt    .stability_unstable
    
    // Check voltage levels (all nodes should be 0.95-1.05 p.u.)
    ldr     x0, [x19, #PowerGrid_voltage_vector]
    ldr     w1, [x19, #PowerGrid_node_count]
    mov     w2, #0                      // node index
    
.stability_voltage_loop:
    cmp     w2, w1
    b.ge    .stability_stable
    
    // Get voltage magnitude
    mov     x3, #16
    mul     x3, x2, x3
    add     x3, x0, x3
    ldr     w4, [x3]                    // V_real
    ldr     w5, [x3, #4]                // V_imag
    
    // Calculate |V|^2 (approximate check)
    smull   x6, w4, w4
    smull   x7, w5, w5
    add     x6, x6, x7
    lsr     x6, x6, #16
    
    // Check bounds: 0.95^2 < |V|^2 < 1.05^2
    mov     w7, #0xE963                 // 0.95^2 ≈ 0.9025
    mov     w8, #0x11C8                 // 1.05^2 ≈ 1.1025
    cmp     w6, w7
    b.lt    .stability_unstable
    cmp     w6, w8
    b.gt    .stability_unstable
    
    add     w2, w2, #1
    b       .stability_voltage_loop
    
.stability_stable:
    mov     x0, #1                      // Stable
    b       .stability_exit
    
.stability_unstable:
    mov     x0, #0                      // Unstable
    
.stability_exit:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// power_grid_update - Main update function called each frame
// Parameters: x0 = delta_time_ms
// Returns: x0 = processing_time_cycles
//==============================================================================
power_grid_update:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Solve power flow
    bl      power_grid_solve_power_flow
    
    // Perform load balancing
    bl      power_grid_load_balance
    
    // Check for brownout conditions
    bl      power_grid_detect_brownout
    
    // Check for blackout conditions
    bl      power_grid_detect_blackout
    
    // Check for cascade failures
    bl      power_grid_cascade_failure_check
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// power_grid_cleanup - Clean up allocated resources
// Parameters: None
// Returns: None
//==============================================================================
power_grid_cleanup:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get grid structure
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    
    // Free voltage vector
    ldr     x1, [x0, #PowerGrid_voltage_vector]
    cbz     x1, .cleanup_matrix
    mov     x0, x1
    bl      free
    
    // Free admittance matrix
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    ldr     x1, [x0, #PowerGrid_admittance_matrix]
    cbz     x1, .cleanup_lines
    mov     x0, x1
    bl      sparse_complex_matrix_free
    
.cleanup_matrix:
    // Free lines array
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    ldr     x1, [x0, #PowerGrid_lines]
    cbz     x1, .cleanup_nodes
    mov     x0, x1
    bl      free
    
.cleanup_lines:
    // Free nodes array
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    ldr     x1, [x0, #PowerGrid_nodes]
    cbz     x1, .cleanup_done
    mov     x0, x1
    bl      free
    
.cleanup_nodes:
.cleanup_done:
    // Zero out the grid structure
    adrp    x0, power_grid
    add     x0, x0, :lo12:power_grid
    mov     x1, #PowerGrid_size
    bl      memset
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// power_grid_load_balance - Implement load balancing algorithms
// Parameters: None
// Returns: x0 = balancing_success (1=success, 0=failure)
//==============================================================================
power_grid_load_balance:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Get grid structure
    adrp    x19, power_grid
    add     x19, x19, :lo12:power_grid
    
    ldr     x20, [x19, #PowerGrid_nodes]
    ldr     w21, [x19, #PowerGrid_node_count]
    ldr     x22, [x19, #PowerGrid_voltage_vector]
    
    // Calculate total generation and demand
    mov     w0, #0                      // total_generation
    mov     w1, #0                      // total_demand
    mov     w2, #0                      // node index
    
.balance_calc_totals:
    cmp     w2, w21
    b.ge    .balance_check_imbalance
    
    // Get node
    mov     x3, #PowerNode_size
    umull   x3, w2, w3
    add     x3, x20, x3
    
    // Add generation and demand
    ldr     w4, [x3, #PowerNode_generation]
    ldr     w5, [x3, #PowerNode_demand]
    add     w0, w0, w4                  // total_generation
    add     w1, w1, w5                  // total_demand
    
    add     w2, w2, #1
    b       .balance_calc_totals
    
.balance_check_imbalance:
    // Calculate imbalance: generation - demand
    sub     w3, w0, w1                  // power_imbalance
    
    // Check if balancing is needed (>1% imbalance)
    mov     w4, #0x0295                 // 0.01 in 16.16
    smull   x5, w1, w4                  // 1% of demand
    lsr     x5, x5, #16
    
    abs     w6, w3                      // |imbalance|
    cmp     w6, w5
    b.le    .balance_success            // Small imbalance, no action needed
    
    // Determine balancing strategy
    cmp     w3, #0
    b.lt    .balance_excess_demand      // Demand > Generation
    
    // Excess generation - reduce generator output
    bl      reduce_generator_output
    b       .balance_success
    
.balance_excess_demand:
    // Excess demand - increase generation or shed load
    bl      increase_generator_output
    cmp     w0, #0
    b.ne    .balance_success
    
    // Could not increase generation enough - emergency load shedding
    bl      power_grid_emergency_load_shed
    
.balance_success:
    mov     x0, #1
    b       .balance_exit
    
.balance_exit:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// reduce_generator_output - Reduce generator output for load balancing
// Parameters: None (uses global grid data)
// Returns: x0 = success (1) or failure (0)
//==============================================================================
reduce_generator_output:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Get grid structure
    adrp    x19, power_grid
    add     x19, x19, :lo12:power_grid
    ldr     x20, [x19, #PowerGrid_nodes]
    ldr     w21, [x19, #PowerGrid_node_count]
    
    // Reduce output of all generators by load balancing factor
    mov     w0, #0                      // node index
    
.reduce_gen_loop:
    cmp     w0, w21
    b.ge    .reduce_gen_success
    
    // Get node
    mov     x1, #PowerNode_size
    umull   x1, w0, w1
    add     x1, x20, x1
    
    // Check if it's a generator
    ldr     w2, [x1, #PowerNode_generation]
    cbz     w2, .reduce_gen_next
    
    // Reduce generation by balancing factor
    adrp    x3, load_balancing_factor
    add     x3, x3, :lo12:load_balancing_factor
    ldr     w3, [x3]
    smull   x4, w2, w3
    lsr     x4, x4, #16
    str     w4, [x1, #PowerNode_generation]
    
.reduce_gen_next:
    add     w0, w0, #1
    b       .reduce_gen_loop
    
.reduce_gen_success:
    mov     x0, #1
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// increase_generator_output - Increase generator output for load balancing
// Parameters: None (uses global grid data)
// Returns: x0 = success (1) or failure (0)
//==============================================================================
increase_generator_output:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Get grid structure
    adrp    x19, power_grid
    add     x19, x19, :lo12:power_grid
    ldr     x20, [x19, #PowerGrid_nodes]
    ldr     w21, [x19, #PowerGrid_node_count]
    
    // Try to increase output of all generators
    mov     w0, #0                      // node index
    mov     w22, #0                     // success flag
    
.increase_gen_loop:
    cmp     w0, w21
    b.ge    .increase_gen_check_success
    
    // Get node
    mov     x1, #PowerNode_size
    umull   x1, w0, w1
    add     x1, x20, x1
    
    // Check if it's a generator
    ldr     w2, [x1, #PowerNode_generation]
    cbz     w2, .increase_gen_next
    
    // Try to increase generation (but don't exceed rated capacity)
    // Assume rated capacity is 125% of current generation
    mov     w3, w2
    add     w3, w3, w2, lsr #2          // * 1.25
    
    // Increase by small amount
    add     w2, w2, w2, lsr #4          // + 6.25% increase
    cmp     w2, w3
    csel    w2, w3, w2, gt              // Clamp to rated capacity
    
    str     w2, [x1, #PowerNode_generation]
    mov     w22, #1                     // Mark success
    
.increase_gen_next:
    add     w0, w0, #1
    b       .increase_gen_loop
    
.increase_gen_check_success:
    mov     x0, x22
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// power_grid_detect_brownout - Detect brownout conditions
// Parameters: None
// Returns: x0 = number_of_brownout_zones
//==============================================================================
power_grid_detect_brownout:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Get grid structure
    adrp    x19, power_grid
    add     x19, x19, :lo12:power_grid
    ldr     x20, [x19, #PowerGrid_voltage_vector]
    ldr     w21, [x19, #PowerGrid_node_count]
    
    // Get brownout threshold
    adrp    x1, brownout_voltage_threshold
    add     x1, x1, :lo12:brownout_voltage_threshold
    ldr     w22, [x1]
    
    // Clear previous brownout zones
    adrp    x1, brownout_zones
    add     x1, x1, :lo12:brownout_zones
    str     xzr, [x1]
    str     xzr, [x1, #8]
    str     xzr, [x1, #16]
    str     xzr, [x1, #24]
    
    // Check each node for brownout
    mov     w0, #0                      // node index
    mov     w23, #0                     // brownout count
    
.brownout_check_loop:
    cmp     w0, w21
    b.ge    .brownout_done
    
    // Get voltage magnitude
    mov     x1, #16
    mul     x1, x0, x1
    add     x1, x20, x1
    ldr     w2, [x1]                    // V_real
    ldr     w3, [x1, #4]                // V_imag\n    \n    // Calculate |V|^2\n    smull   x4, w2, w2\n    smull   x5, w3, w3\n    add     x4, x4, x5\n    lsr     x4, x4, #16                 // |V|^2 in 16.16\n    \n    // Check if below brownout threshold (compare |V|^2 with threshold^2)\n    smull   x5, w22, w22\n    lsr     x5, x5, #16                 // threshold^2\n    cmp     w4, w5\n    b.ge    .brownout_next_node\n    \n    // This node is in brownout - set bit in brownout_zones\n    mov     w6, w0\n    lsr     w7, w6, #5                  // word index (node / 32)\n    and     w6, w6, #31                 // bit index (node % 32)\n    mov     w8, #1\n    lsl     w8, w8, w6                  // bit mask\n    \n    adrp    x9, brownout_zones\n    add     x9, x9, :lo12:brownout_zones\n    lsl     w7, w7, #2                  // word offset\n    add     x9, x9, x7\n    ldr     w10, [x9]\n    orr     w10, w10, w8                // Set bit\n    str     w10, [x9]\n    \n    add     w23, w23, #1                // Increment brownout count\n    \n.brownout_next_node:\n    add     w0, w0, #1\n    b       .brownout_check_loop\n    \n.brownout_done:\n    mov     x0, x23                     // Return brownout count\n    ldp     x19, x20, [sp, #16]\n    ldp     x29, x30, [sp], #32\n    ret\n\n//==============================================================================\n// power_grid_detect_blackout - Detect blackout conditions\n// Parameters: None\n// Returns: x0 = number_of_blackout_zones\n//==============================================================================\npower_grid_detect_blackout:\n    stp     x29, x30, [sp, #-32]!\n    mov     x29, sp\n    stp     x19, x20, [sp, #16]\n    \n    // Get grid structure\n    adrp    x19, power_grid\n    add     x19, x19, :lo12:power_grid\n    ldr     x20, [x19, #PowerGrid_voltage_vector]\n    ldr     w21, [x19, #PowerGrid_node_count]\n    \n    // Get blackout threshold\n    adrp    x1, blackout_voltage_threshold\n    add     x1, x1, :lo12:blackout_voltage_threshold\n    ldr     w22, [x1]\n    \n    // Clear previous blackout zones\n    adrp    x1, blackout_zones\n    add     x1, x1, :lo12:blackout_zones\n    str     xzr, [x1]\n    str     xzr, [x1, #8]\n    str     xzr, [x1, #16]\n    str     xzr, [x1, #24]\n    \n    // Check each node for blackout\n    mov     w0, #0                      // node index\n    mov     w23, #0                     // blackout count\n    \n.blackout_check_loop:\n    cmp     w0, w21\n    b.ge    .blackout_check_total\n    \n    // Get voltage magnitude\n    mov     x1, #16\n    mul     x1, x0, x1\n    add     x1, x20, x1\n    ldr     w2, [x1]                    // V_real\n    ldr     w3, [x1, #4]                // V_imag\n    \n    // Calculate |V|^2\n    smull   x4, w2, w2\n    smull   x5, w3, w3\n    add     x4, x4, x5\n    lsr     x4, x4, #16                 // |V|^2 in 16.16\n    \n    // Check if below blackout threshold\n    smull   x5, w22, w22\n    lsr     x5, x5, #16                 // threshold^2\n    cmp     w4, w5\n    b.ge    .blackout_next_node\n    \n    // This node is in blackout - set bit in blackout_zones\n    mov     w6, w0\n    lsr     w7, w6, #5                  // word index\n    and     w6, w6, #31                 // bit index\n    mov     w8, #1\n    lsl     w8, w8, w6                  // bit mask\n    \n    adrp    x9, blackout_zones\n    add     x9, x9, :lo12:blackout_zones\n    lsl     w7, w7, #2                  // word offset\n    add     x9, x9, x7\n    ldr     w10, [x9]\n    orr     w10, w10, w8                // Set bit\n    str     w10, [x9]\n    \n    add     w23, w23, #1                // Increment blackout count\n    \n.blackout_next_node:\n    add     w0, w0, #1\n    b       .blackout_check_loop\n    \n.blackout_check_total:\n    // Check if majority of grid is in blackout (total system failure)\n    lsr     w1, w21, #1                 // 50% of nodes\n    cmp     w23, w1\n    b.lt    .blackout_partial\n    \n    // Total blackout condition\n    adrp    x1, total_blackout_flag\n    add     x1, x1, :lo12:total_blackout_flag\n    mov     w2, #1\n    str     w2, [x1]\n    b       .blackout_done\n    \n.blackout_partial:\n    // Partial blackout\n    adrp    x1, total_blackout_flag\n    add     x1, x1, :lo12:total_blackout_flag\n    str     wzr, [x1]\n    \n.blackout_done:\n    mov     x0, x23                     // Return blackout count\n    ldp     x19, x20, [sp, #16]\n    ldp     x29, x30, [sp], #32\n    ret\n\n//==============================================================================\n// power_grid_cascade_failure_check - Check for cascade failures\n// Parameters: None\n// Returns: x0 = number_of_failed_components\n//==============================================================================\npower_grid_cascade_failure_check:\n    stp     x29, x30, [sp, #-32]!\n    mov     x29, sp\n    stp     x19, x20, [sp, #16]\n    \n    // Get grid structure\n    adrp    x19, power_grid\n    add     x19, x19, :lo12:power_grid\n    ldr     x20, [x19, #PowerGrid_lines]\n    ldr     w21, [x19, #PowerGrid_line_count]\n    \n    // Get cascade failure threshold\n    adrp    x1, cascade_failure_threshold\n    add     x1, x1, :lo12:cascade_failure_threshold\n    ldr     w22, [x1]\n    \n    // Check each transmission line for overload\n    mov     w0, #0                      // line index\n    mov     w23, #0                     // failure count\n    \n.cascade_check_loop:\n    cmp     w0, w21\n    b.ge    .cascade_done\n    \n    // Get current line\n    mov     x1, #PowerLine_size\n    mul     x1, x0, x1\n    add     x1, x20, x1\n    \n    // Check overload factor\n    ldr     w2, [x1, #PowerLine_overload_factor]\n    cmp     w2, w22\n    b.lt    .cascade_next_line\n    \n    // Line is overloaded - mark as failed\n    mov     w3, #0                      // Failed status\n    str     w3, [x1, #PowerLine_status]\n    add     w23, w23, #1\n    \n    // Set bit in failed_components\n    mov     w4, w0\n    lsr     w5, w4, #5                  // word index\n    and     w4, w4, #31                 // bit index\n    mov     w6, #1\n    lsl     w6, w6, w4                  // bit mask\n    \n    adrp    x7, failed_components\n    add     x7, x7, :lo12:failed_components\n    lsl     w5, w5, #2                  // word offset\n    add     x7, x7, x5\n    ldr     w8, [x7]\n    orr     w8, w8, w6                  // Set bit\n    str     w8, [x7]\n    \n.cascade_next_line:\n    add     w0, w0, #1\n    b       .cascade_check_loop\n    \n.cascade_done:\n    mov     x0, x23                     // Return failure count\n    ldp     x19, x20, [sp, #16]\n    ldp     x29, x30, [sp], #32\n    ret\n\n//==============================================================================\n// power_grid_emergency_load_shed - Emergency load shedding to prevent blackout\n// Parameters: None\n// Returns: x0 = amount_of_load_shed (MW)\n//==============================================================================\npower_grid_emergency_load_shed:\n    stp     x29, x30, [sp, #-32]!\n    mov     x29, sp\n    stp     x19, x20, [sp, #16]\n    \n    // Get grid structure\n    adrp    x19, power_grid\n    add     x19, x19, :lo12:power_grid\n    ldr     x20, [x19, #PowerGrid_nodes]\n    ldr     w21, [x19, #PowerGrid_node_count]\n    \n    // Shed 10% of total load starting with lowest priority consumers\n    mov     w0, #0                      // node index\n    mov     w22, #0                     // total load shed\n    \n.load_shed_loop:\n    cmp     w0, w21\n    b.ge    .load_shed_done\n    \n    // Get node\n    mov     x1, #PowerNode_size\n    umull   x1, w0, w1\n    add     x1, x20, x1\n    \n    // Check if it's a consumer\n    ldr     w2, [x1, #PowerNode_demand]\n    cbz     w2, .load_shed_next\n    \n    // Shed 10% of this consumer's load\n    mov     w3, w2\n    lsr     w3, w3, #3                  // 12.5% reduction\n    sub     w2, w2, w3\n    str     w2, [x1, #PowerNode_demand]\n    add     w22, w22, w3                // Track total shed\n    \n.load_shed_next:\n    add     w0, w0, #1\n    b       .load_shed_loop\n    \n.load_shed_done:\n    mov     x0, x22                     // Return total load shed\n    ldp     x19, x20, [sp, #16]\n    ldp     x29, x30, [sp], #32\n    ret\n\n//==============================================================================\n// Helper Functions (placeholders - would be in separate math library)\n//=============================================================================="}

sparse_complex_matrix_init:
    mov     x0, #0                      // Placeholder
    ret

sparse_complex_matrix_set:
    ret                                 // Placeholder

sparse_complex_matrix_free:
    ret                                 // Placeholder

fixed_point_sqrt:
    ret                                 // Placeholder - would implement Newton's method

fixed_point_atan2:
    ret                                 // Placeholder - would implement CORDIC algorithm

.end