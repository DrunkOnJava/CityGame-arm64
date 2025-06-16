//
// SimCity ARM64 Assembly - Tax and Budget Management System
// Agent 2: Economic and Population Systems
//
// Handles tax collection, budget allocation, and financial management
//

.include "economic_constants.s"
.include "../simulation/simulation_constants.s"

.text
.global init_tax_system
.global set_tax_rates
.global collect_monthly_taxes
.global allocate_budget
.global get_budget_status
.global calculate_service_costs

//
// Budget System Structure (256 bytes)
//
// Offset  Size  Field
// 0       8     total_funds
// 8       8     monthly_tax_revenue
// 16      8     monthly_expenses
// 24      8     annual_budget
// 32      4     tax_rate_residential
// 36      4     tax_rate_commercial
// 40      4     tax_rate_industrial
// 44      4     budget_police (monthly allocation)
// 48      4     budget_fire (monthly allocation)
// 52      4     budget_health (monthly allocation)
// 56      4     budget_education (monthly allocation)
// 60      4     budget_transport (monthly allocation)
// 64      4     budget_utilities (monthly allocation)
// 68      4     debt_amount
// 72      4     credit_rating (0-100)
// 76      4     bond_payments
// 80      4     emergency_fund
// 84-255        reserved and detailed budget tracking
//

.data
.align 8
budget_system:
    .quad   STARTING_FUNDS              // total_funds
    .quad   0                           // monthly_tax_revenue
    .quad   0                           // monthly_expenses
    .quad   0                           // annual_budget
    .word   TAX_RATE_RESIDENTIAL_DEFAULT // tax_rate_residential
    .word   TAX_RATE_COMMERCIAL_DEFAULT  // tax_rate_commercial
    .word   TAX_RATE_INDUSTRIAL_DEFAULT  // tax_rate_industrial
    .word   5000                        // budget_police
    .word   3000                        // budget_fire
    .word   4000                        // budget_health
    .word   6000                        // budget_education
    .word   8000                        // budget_transport
    .word   7000                        // budget_utilities
    .word   0                           // debt_amount
    .word   100                         // credit_rating (AAA rating)
    .word   0                           // bond_payments
    .word   10000                       // emergency_fund
    .space  172                         // reserved space

// Tax efficiency lookup table (based on tax rate)
tax_efficiency_table:
    .word   95, 95, 94, 93, 92, 90, 88, 85, 82, 78    // 5%-14% tax rates
    .word   74, 70, 65, 60, 55, 50, 45, 40, 35, 30    // 15%-24% tax rates

.text

//
// Initialize the tax and budget system
// Parameters: none
// Returns: none
//
init_tax_system:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get budget system pointer
    adrp    x0, budget_system
    add     x0, x0, :lo12:budget_system
    
    // Set initial tax rates to default values
    mov     w1, #TAX_RATE_RESIDENTIAL_DEFAULT
    str     w1, [x0, #32]
    mov     w1, #TAX_RATE_COMMERCIAL_DEFAULT
    str     w1, [x0, #36]
    mov     w1, #TAX_RATE_INDUSTRIAL_DEFAULT
    str     w1, [x0, #40]
    
    // Initialize credit rating to excellent
    mov     w1, #100
    str     w1, [x0, #72]
    
    // Set emergency fund
    mov     w1, #10000
    str     w1, [x0, #80]
    
    ldp     x29, x30, [sp], #16
    ret

//
// Set tax rates for different zones
// Parameters: w0 = residential_rate, w1 = commercial_rate, w2 = industrial_rate
// Returns: w0 = success (1) or failure (0)
//
set_tax_rates:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Validate tax rates are within acceptable ranges
    cmp     w0, #TAX_RATE_RESIDENTIAL_MIN
    b.lt    set_tax_rates_invalid
    cmp     w0, #TAX_RATE_RESIDENTIAL_MAX
    b.gt    set_tax_rates_invalid
    
    cmp     w1, #TAX_RATE_COMMERCIAL_MIN
    b.lt    set_tax_rates_invalid
    cmp     w1, #TAX_RATE_COMMERCIAL_MAX
    b.gt    set_tax_rates_invalid
    
    cmp     w2, #TAX_RATE_INDUSTRIAL_MIN
    b.lt    set_tax_rates_invalid
    cmp     w2, #TAX_RATE_INDUSTRIAL_MAX
    b.gt    set_tax_rates_invalid
    
    // Store the new tax rates
    adrp    x3, budget_system
    add     x3, x3, :lo12:budget_system
    
    str     w0, [x3, #32]               // tax_rate_residential
    str     w1, [x3, #36]               // tax_rate_commercial
    str     w2, [x3, #40]               // tax_rate_industrial
    
    mov     w0, #1                      // Success
    b       set_tax_rates_exit
    
set_tax_rates_invalid:
    mov     w0, #0                      // Failure
    
set_tax_rates_exit:
    ldp     x29, x30, [sp], #16
    ret

//
// Collect monthly taxes from all zones
// Parameters: x0 = building_count_array (residential, commercial, industrial)
//            x1 = building_values_array
// Returns: x0 = total_tax_collected
//
collect_monthly_taxes:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // building_count_array
    mov     x20, x1                     // building_values_array
    mov     x21, #0                     // total_tax_collected
    
    // Get budget system
    adrp    x22, budget_system
    add     x22, x22, :lo12:budget_system
    
    // Collect residential taxes
    ldr     w0, [x19, #0]               // residential_buildings
    ldr     w1, [x20, #0]               // residential_building_value
    ldr     w2, [x22, #32]              // tax_rate_residential
    bl      calculate_zone_taxes
    add     x21, x21, x0
    
    // Collect commercial taxes
    ldr     w0, [x19, #4]               // commercial_buildings
    ldr     w1, [x20, #4]               // commercial_building_value
    ldr     w2, [x22, #36]              // tax_rate_commercial
    bl      calculate_zone_taxes
    add     x21, x21, x0
    
    // Collect industrial taxes
    ldr     w0, [x19, #8]               // industrial_buildings
    ldr     w1, [x20, #8]               // industrial_building_value
    ldr     w2, [x22, #40]              // tax_rate_industrial
    bl      calculate_zone_taxes
    add     x21, x21, x0
    
    // Add tax revenue to total funds
    ldr     x0, [x22, #0]               // current total_funds
    add     x0, x0, x21
    str     x0, [x22, #0]               // update total_funds
    
    // Store monthly tax revenue
    str     x21, [x22, #8]              // monthly_tax_revenue
    
    mov     x0, x21                     // Return total tax collected
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// Calculate taxes for a specific zone type
// Parameters: w0 = building_count, w1 = building_value, w2 = tax_rate
// Returns: x0 = tax_amount
//
calculate_zone_taxes:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Calculate base tax: buildings * value * rate / 100
    mul     w3, w0, w1                  // buildings * value
    mul     w4, w3, w2                  // * tax_rate
    mov     w5, #100
    udiv    w4, w4, w5                  // / 100 for percentage
    
    // Apply tax efficiency based on tax rate
    mov     x0, x2                      // tax_rate
    bl      get_tax_efficiency
    mov     w6, w0                      // efficiency_percentage
    
    // Apply efficiency: tax_amount * efficiency / 100
    mul     w7, w4, w6
    mov     w8, #100
    udiv    w0, w7, w8                  // Final tax amount
    
    ldp     x29, x30, [sp], #16
    ret

//
// Get tax collection efficiency based on tax rate
// Parameters: x0 = tax_rate
// Returns: w0 = efficiency_percentage (0-100)
//
get_tax_efficiency:
    // Tax rates above optimal levels reduce efficiency due to evasion
    cmp     x0, #5
    b.lt    get_tax_efficiency_low
    cmp     x0, #25
    b.ge    get_tax_efficiency_high
    
    // Normal range (5-24%), use lookup table
    sub     x1, x0, #5                  // Offset to table index
    adrp    x2, tax_efficiency_table
    add     x2, x2, :lo12:tax_efficiency_table
    ldr     w0, [x2, x1, lsl #2]
    ret
    
get_tax_efficiency_low:
    mov     w0, #95                     // Very low tax rates are efficient
    ret
    
get_tax_efficiency_high:
    mov     w0, #25                     // Very high tax rates cause evasion
    ret

//
// Allocate budget to different city services
// Parameters: w0 = police_budget, w1 = fire_budget, w2 = health_budget
//            w3 = education_budget, w4 = transport_budget, w5 = utilities_budget
// Returns: w0 = success (1) or insufficient funds (0)
//
allocate_budget:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Calculate total requested budget
    add     w6, w0, w1
    add     w6, w6, w2
    add     w6, w6, w3
    add     w6, w6, w4
    add     w6, w6, w5
    
    // Get budget system
    adrp    x19, budget_system
    add     x19, x19, :lo12:budget_system
    
    // Check if we have enough funds
    ldr     x7, [x19, #0]               // total_funds
    cmp     x7, x6                      // Compare funds with requested budget
    b.lt    allocate_budget_insufficient
    
    // Allocate the budget
    str     w0, [x19, #44]              // budget_police
    str     w1, [x19, #48]              // budget_fire
    str     w2, [x19, #52]              // budget_health
    str     w3, [x19, #56]              // budget_education
    str     w4, [x19, #60]              // budget_transport
    str     w5, [x19, #64]              // budget_utilities
    
    mov     w0, #1                      // Success
    b       allocate_budget_exit
    
allocate_budget_insufficient:
    mov     w0, #0                      // Insufficient funds
    
allocate_budget_exit:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// Calculate monthly service costs based on city size and service levels
// Parameters: w0 = population, w1 = total_buildings
// Returns: x0 = total_monthly_service_costs
//
calculate_service_costs:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     x2, #0                      // total_costs
    
    // Police costs: base cost + per capita cost + per building cost
    mov     w3, #SERVICE_COST_POLICE_STATION
    mov     w4, #2                      // $2 per person
    mul     w5, w0, w4
    add     w3, w3, w5
    mov     w4, #5                      // $5 per building
    mul     w5, w1, w4
    add     w3, w3, w5
    add     x2, x2, x3
    
    // Fire costs
    mov     w3, #SERVICE_COST_FIRE_STATION
    mov     w4, #1                      // $1 per person
    mul     w5, w0, w4
    add     w3, w3, w5
    mov     w4, #3                      // $3 per building
    mul     w5, w1, w4
    add     w3, w3, w5
    add     x2, x2, x3
    
    // Health costs
    mov     w3, #SERVICE_COST_HOSPITAL
    mov     w4, #3                      // $3 per person
    mul     w5, w0, w4
    add     w3, w3, w5
    add     x2, x2, x3
    
    // Education costs
    mov     w3, #SERVICE_COST_SCHOOL
    mov     w4, #5                      // $5 per person (includes children)
    mul     w5, w0, w4
    add     w3, w3, w5
    add     x2, x2, x3
    
    // Infrastructure maintenance (roads, utilities)
    mov     w4, #SERVICE_COST_ROAD_MAINTENANCE
    mul     w5, w1, w4                  // Maintenance per building
    add     x2, x2, x5
    
    mov     x0, x2                      // Return total costs
    ldp     x29, x30, [sp], #16
    ret

//
// Get current budget status and financial health
// Parameters: none
// Returns: x0 = budget_system_pointer
//
get_budget_status:
    adrp    x0, budget_system
    add     x0, x0, :lo12:budget_system
    ret

//
// Process monthly budget cycle
// Parameters: w0 = population, w1 = total_buildings
// Returns: none
//
.global process_monthly_budget_cycle
process_monthly_budget_cycle:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     w19, w0                     // Save population
    mov     w20, w1                     // Save buildings
    
    // Calculate service costs
    bl      calculate_service_costs
    mov     x21, x0                     // Save service costs
    
    // Get budget system
    adrp    x22, budget_system
    add     x22, x22, :lo12:budget_system
    
    // Deduct service costs from funds
    ldr     x0, [x22, #0]               // total_funds
    sub     x0, x0, x21                 // subtract service costs
    str     x0, [x22, #0]               // update funds
    
    // Store monthly expenses
    str     x21, [x22, #16]
    
    // Update credit rating based on financial health
    bl      update_credit_rating
    
    // Check for emergency situations (negative funds)
    ldr     x0, [x22, #0]
    cmp     x0, #0
    b.ge    process_monthly_budget_exit
    
    // Handle deficit spending (simplified)
    neg     x1, x0                      // Amount needed
    ldr     x2, [x22, #68]              // current debt
    add     x2, x2, x1                  // Increase debt
    str     x2, [x22, #68]
    
    // Set funds to zero (borrowed money covers deficit)
    str     xzr, [x22, #0]
    
process_monthly_budget_exit:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// Update city's credit rating based on financial performance
// Parameters: none (uses global budget_system)
// Returns: none
//
update_credit_rating:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, budget_system
    add     x0, x0, :lo12:budget_system
    
    ldr     x1, [x0, #0]                // total_funds
    ldr     x2, [x0, #68]               // debt_amount
    ldr     x3, [x0, #8]                // monthly_tax_revenue
    ldr     x4, [x0, #16]               // monthly_expenses
    
    // Calculate debt-to-revenue ratio and budget balance
    mov     w5, #100                    // Base credit rating
    
    // Penalty for debt
    cbz     x2, update_credit_no_debt
    cbz     x3, update_credit_no_revenue
    
    // Debt ratio penalty: debt / (annual revenue)
    mov     x6, #12
    mul     x7, x3, x6                  // Annual revenue estimate
    mul     x8, x2, #100                // debt * 100
    udiv    x9, x8, x7                  // debt percentage of annual revenue
    
    // Reduce rating based on debt ratio
    cmp     x9, #50                     // 50% debt ratio
    b.lt    update_credit_no_debt
    sub     x10, x9, #50                // Excess debt
    sub     w5, w5, w10                 // Reduce credit rating
    
update_credit_no_debt:
    // Penalty for deficits
    cmp     x4, x3                      // expenses vs revenue
    b.le    update_credit_balanced
    
    sub     x11, x4, x3                 // Deficit amount
    mov     x12, #10
    udiv    x13, x11, x12               // Deficit impact
    sub     w5, w5, w13                 // Reduce rating
    
update_credit_balanced:
update_credit_no_revenue:
    // Ensure rating stays within bounds
    cmp     w5, #100
    csel    w5, w5, #100, lt
    cmp     w5, #0
    csel    w5, w5, wzr, gt
    
    str     w5, [x0, #72]               // Update credit_rating
    
    ldp     x29, x30, [sp], #16
    ret