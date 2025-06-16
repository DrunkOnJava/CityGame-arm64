//
// SimCity ARM64 Assembly - Economic System Implementation
// Agent 2: Economic and Population Systems
//
// Core economic system with tax collection, budgeting, and RCI demand
//

.include "economic_constants.s"
.include "../simulation/simulation_constants.s"

.text
.global init_economic_system
.global update_economic_system
.global calculate_taxes
.global get_building_value
.global update_rci_demand
.global get_unemployment_rate
.global process_monthly_budget

//
// Economic State Structure (256 bytes)
//
// Offset  Size  Field
// 0       8     city_funds (int64)
// 8       8     monthly_income (int64)
// 16      8     monthly_expenses (int64)
// 24      4     tax_rate_residential (int32)
// 28      4     tax_rate_commercial (int32)
// 32      4     tax_rate_industrial (int32)
// 36      4     population_total (int32)
// 40      4     population_employed (int32)
// 44      4     population_unemployed (int32)
// 48      4     happiness_average (int32)
// 52      4     land_value_average (int32)
// 56      4     rci_demand_residential (int32)
// 60      4     rci_demand_commercial (int32)
// 64      4     rci_demand_industrial (int32)
// 68      4     buildings_residential (int32)
// 72      4     buildings_commercial (int32)
// 76      4     buildings_industrial (int32)
// 80      4     economic_indicator (int32)
// 84      4     months_elapsed (int32)
// 88      4     last_update_tick (int32)
// 92-255        budget_categories[6] and reserved space
//

.data
.align 8
economic_state:
    .quad   STARTING_FUNDS              // city_funds
    .quad   0                           // monthly_income
    .quad   0                           // monthly_expenses
    .word   TAX_RATE_RESIDENTIAL_DEFAULT // tax_rate_residential
    .word   TAX_RATE_COMMERCIAL_DEFAULT  // tax_rate_commercial
    .word   TAX_RATE_INDUSTRIAL_DEFAULT  // tax_rate_industrial
    .word   0                           // population_total
    .word   0                           // population_employed
    .word   0                           // population_unemployed
    .word   50                          // happiness_average (neutral)
    .word   LAND_VALUE_BASE             // land_value_average
    .word   DEMAND_RESIDENTIAL_BASE     // rci_demand_residential
    .word   DEMAND_COMMERCIAL_BASE      // rci_demand_commercial
    .word   DEMAND_INDUSTRIAL_BASE      // rci_demand_industrial
    .word   0                           // buildings_residential
    .word   0                           // buildings_commercial
    .word   0                           // buildings_industrial
    .word   0                           // economic_indicator
    .word   0                           // months_elapsed
    .word   0                           // last_update_tick
    .space  164                         // reserved space

// Building value lookup table
building_values:
    .word   0                           // TILE_EMPTY
    .word   BUILDING_VALUE_HOUSE_LOW    // TILE_HOUSE
    .word   BUILDING_VALUE_COMMERCIAL_SMALL // TILE_COMMERCIAL
    .word   BUILDING_VALUE_INDUSTRIAL_LIGHT // TILE_INDUSTRIAL
    .word   50                          // TILE_ROAD (maintenance cost)
    .word   BUILDING_VALUE_PARK_SMALL   // TILE_PARK

.text

//
// Initialize the economic system
// Parameters: none
// Returns: none
//
init_economic_system:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Initialize economic state with default values
    adrp    x0, economic_state
    add     x0, x0, :lo12:economic_state
    
    // Set starting funds
    mov     x1, #STARTING_FUNDS
    str     x1, [x0, #0]                // city_funds
    
    // Initialize tax rates to defaults
    mov     w1, #TAX_RATE_RESIDENTIAL_DEFAULT
    str     w1, [x0, #24]
    mov     w1, #TAX_RATE_COMMERCIAL_DEFAULT
    str     w1, [x0, #28]
    mov     w1, #TAX_RATE_INDUSTRIAL_DEFAULT
    str     w1, [x0, #32]
    
    // Initialize happiness to neutral
    mov     w1, #50
    str     w1, [x0, #48]
    
    // Initialize land value
    mov     w1, #LAND_VALUE_BASE
    str     w1, [x0, #52]
    
    // Initialize RCI demand
    mov     w1, #DEMAND_RESIDENTIAL_BASE
    str     w1, [x0, #56]
    mov     w1, #DEMAND_COMMERCIAL_BASE
    str     w1, [x0, #60]
    mov     w1, #DEMAND_INDUSTRIAL_BASE
    str     w1, [x0, #64]
    
    ldp     x29, x30, [sp], #16
    ret

//
// Update the economic system (called each simulation tick)
// Parameters: x0 = current_tick
// Returns: none
//
update_economic_system:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save current_tick
    
    // Get economic state
    adrp    x0, economic_state
    add     x0, x0, :lo12:economic_state
    mov     x20, x0                     // Save state pointer
    
    // Check if it's time for monthly update
    ldr     w1, [x0, #88]               // last_update_tick
    sub     w2, w19, w1                 // ticks since last update
    cmp     w2, #ECONOMIC_UPDATE_FREQUENCY
    b.lt    update_economic_system_exit
    
    // Store new last_update_tick
    str     w19, [x0, #88]
    
    // Increment months_elapsed
    ldr     w1, [x0, #84]
    add     w1, w1, #1
    str     w1, [x0, #84]
    
    // Collect taxes
    mov     x0, x20
    bl      calculate_taxes
    
    // Update RCI demand
    mov     x0, x20
    bl      update_rci_demand
    
    // Process monthly expenses
    mov     x0, x20
    bl      process_monthly_budget
    
    // Update economic indicators
    mov     x0, x20
    bl      update_economic_indicators
    
update_economic_system_exit:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// Calculate and collect taxes from all buildings
// Parameters: x0 = economic_state pointer
// Returns: x0 = total tax revenue
//
calculate_taxes:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // Save state pointer
    mov     x20, #0                     // Total tax revenue
    
    // Get building counts and tax rates
    ldr     w21, [x19, #68]             // buildings_residential
    ldr     w1, [x19, #24]              // tax_rate_residential
    
    // Calculate residential tax revenue
    mov     w0, #BUILDING_VALUE_HOUSE_LOW
    CALCULATE_TAX_REVENUE w0, w1, x2
    mul     x2, x2, x21                 // multiply by building count
    add     x20, x20, x2                // add to total
    
    // Commercial buildings
    ldr     w21, [x19, #72]             // buildings_commercial
    ldr     w1, [x19, #28]              // tax_rate_commercial
    mov     w0, #BUILDING_VALUE_COMMERCIAL_SMALL
    CALCULATE_TAX_REVENUE w0, w1, x2
    mul     x2, x2, x21
    add     x20, x20, x2
    
    // Industrial buildings
    ldr     w21, [x19, #76]             // buildings_industrial
    ldr     w1, [x19, #32]              // tax_rate_industrial
    mov     w0, #BUILDING_VALUE_INDUSTRIAL_LIGHT
    CALCULATE_TAX_REVENUE w0, w1, x2
    mul     x2, x2, x21
    add     x20, x20, x2
    
    // Add tax revenue to city funds
    ldr     x1, [x19, #0]               // current city_funds
    add     x1, x1, x20
    str     x1, [x19, #0]               // update city_funds
    
    // Update monthly_income
    str     x20, [x19, #8]
    
    mov     x0, x20                     // Return total revenue
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// Get building value by type
// Parameters: w0 = building_type
// Returns: w0 = building_value
//
get_building_value:
    cmp     w0, #TILE_TYPE_COUNT
    b.ge    get_building_value_invalid
    
    adrp    x1, building_values
    add     x1, x1, :lo12:building_values
    ldr     w0, [x1, w0, uxtw #2]       // Load value from lookup table
    ret
    
get_building_value_invalid:
    mov     w0, #0
    ret

//
// Update RCI (Residential/Commercial/Industrial) demand
// Parameters: x0 = economic_state pointer
// Returns: none
//
update_rci_demand:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save state pointer
    
    // Get current building counts
    ldr     w1, [x19, #68]              // buildings_residential
    ldr     w2, [x19, #72]              // buildings_commercial
    ldr     w3, [x19, #76]              // buildings_industrial
    
    // Calculate total buildings
    add     w4, w1, w2
    add     w4, w4, w3
    
    // Calculate residential demand (based on job availability)
    ldr     w5, [x19, #40]              // population_employed
    ldr     w6, [x19, #36]              // population_total
    
    // If more jobs than people, increase residential demand
    cmp     w5, w6
    b.le    update_rci_demand_commercial
    
    // Increase residential demand
    ldr     w7, [x19, #56]              // current residential demand
    add     w7, w7, #10
    mov     w8, #RCI_DEMAND_MAX
    cmp     w7, w8
    csel    w7, w7, w8, lt
    str     w7, [x19, #56]
    
update_rci_demand_commercial:
    // Commercial demand based on population
    mov     w8, #4                      // 1 commercial per 4 residential
    udiv    w8, w1, w8                  // Expected commercial buildings
    cmp     w2, w8                      // Current vs expected
    b.ge    update_rci_demand_industrial
    
    // Increase commercial demand
    ldr     w7, [x19, #60]
    add     w7, w7, #5
    mov     w8, #RCI_DEMAND_MAX
    cmp     w7, w8
    csel    w7, w7, w8, lt
    str     w7, [x19, #60]
    
update_rci_demand_industrial:
    // Industrial demand based on commercial needs
    mov     w8, #3                      // 1 industrial per 3 commercial
    udiv    w8, w2, w8
    cmp     w3, w8
    b.ge    update_rci_demand_decay
    
    // Increase industrial demand
    ldr     w7, [x19, #64]
    add     w7, w7, #5
    mov     w8, #RCI_DEMAND_MAX
    cmp     w7, w8
    csel    w7, w7, w8, lt
    str     w7, [x19, #64]
    
update_rci_demand_decay:
    // Gradually decay all demands over time
    ldr     w1, [x19, #56]              // residential
    sub     w1, w1, #DEMAND_DECAY_RATE
    cmp     w1, #0
    csel    w1, w1, wzr, gt
    str     w1, [x19, #56]
    
    ldr     w2, [x19, #60]              // commercial
    sub     w2, w2, #DEMAND_DECAY_RATE
    cmp     w2, #0
    csel    w2, w2, wzr, gt
    str     w2, [x19, #60]
    
    ldr     w3, [x19, #64]              // industrial
    sub     w3, w3, #DEMAND_DECAY_RATE
    cmp     w3, #0
    csel    w3, w3, wzr, gt
    str     w3, [x19, #64]
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// Calculate unemployment rate
// Parameters: x0 = economic_state pointer
// Returns: w0 = unemployment_rate (percentage)
//
get_unemployment_rate:
    ldr     w1, [x0, #36]               // population_total
    cbz     w1, get_unemployment_rate_zero
    
    ldr     w2, [x0, #44]               // population_unemployed
    mov     x3, #100
    mul     x2, x2, x3                  // unemployed * 100
    udiv    w0, w2, w1                  // (unemployed * 100) / total
    ret
    
get_unemployment_rate_zero:
    mov     w0, #0
    ret

//
// Process monthly budget and expenses
// Parameters: x0 = economic_state pointer
// Returns: none
//
process_monthly_budget:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Calculate total monthly expenses
    mov     x1, #0                      // Total expenses
    
    // Service maintenance costs (simplified)
    ldr     w2, [x0, #68]               // buildings_residential
    mov     w3, #50                     // Base service cost per building
    mul     w2, w2, w3
    add     x1, x1, x2
    
    ldr     w2, [x0, #72]               // buildings_commercial
    mov     w3, #75
    mul     w2, w2, w3
    add     x1, x1, x2
    
    ldr     w2, [x0, #76]               // buildings_industrial
    mov     w3, #100
    mul     w2, w2, w3
    add     x1, x1, x2
    
    // Deduct expenses from city funds
    ldr     x2, [x0, #0]                // city_funds
    sub     x2, x2, x1
    str     x2, [x0, #0]
    
    // Store monthly expenses
    str     x1, [x0, #16]
    
    ldp     x29, x30, [sp], #16
    ret

//
// Update economic indicators
// Parameters: x0 = economic_state pointer
// Returns: none
//
update_economic_indicators:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Calculate economic indicator based on various factors
    ldr     x1, [x0, #8]                // monthly_income
    ldr     x2, [x0, #16]               // monthly_expenses
    sub     x3, x1, x2                  // Net income
    
    // Convert to indicator scale (-100 to +100)
    mov     x4, #1000                   // Scale factor
    sdiv    x3, x3, x4
    
    // Cap the indicator
    mov     x4, #100
    cmp     x3, x4
    csel    x3, x3, x4, lt
    mov     x4, #-100
    cmp     x3, x4
    csel    x3, x3, x4, gt
    
    // Store economic indicator
    str     w3, [x0, #80]
    
    ldp     x29, x30, [sp], #16
    ret

// Global economic state accessor
.global get_economic_state
get_economic_state:
    adrp    x0, economic_state
    add     x0, x0, :lo12:economic_state
    ret