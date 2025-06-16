//
// SimCity ARM64 Assembly - Economic Constants
// Agent 2: Economic and Population Systems
//
// Defines economic constants, tax rates, building values, and population parameters
//

// Tax system constants
.equ TAX_RATE_RESIDENTIAL_MIN,   5      // Minimum residential tax rate (%)
.equ TAX_RATE_RESIDENTIAL_MAX,   20     // Maximum residential tax rate (%)
.equ TAX_RATE_RESIDENTIAL_DEFAULT, 9   // Default residential tax rate (%)

.equ TAX_RATE_COMMERCIAL_MIN,    5      // Minimum commercial tax rate (%)
.equ TAX_RATE_COMMERCIAL_MAX,    20     // Maximum commercial tax rate (%)
.equ TAX_RATE_COMMERCIAL_DEFAULT, 11   // Default commercial tax rate (%)

.equ TAX_RATE_INDUSTRIAL_MIN,    5      // Minimum industrial tax rate (%)
.equ TAX_RATE_INDUSTRIAL_MAX,    20     // Maximum industrial tax rate (%)
.equ TAX_RATE_INDUSTRIAL_DEFAULT, 8    // Default industrial tax rate (%)

// Building values (in simoleons)
.equ BUILDING_VALUE_HOUSE_LOW,      10000   // Low-density residential
.equ BUILDING_VALUE_HOUSE_MEDIUM,   15000   // Medium-density residential
.equ BUILDING_VALUE_HOUSE_HIGH,     25000   // High-density residential
.equ BUILDING_VALUE_HOUSE_LUXURY,   40000   // Luxury residential

.equ BUILDING_VALUE_COMMERCIAL_SMALL,  20000   // Small commercial
.equ BUILDING_VALUE_COMMERCIAL_MEDIUM, 35000   // Medium commercial
.equ BUILDING_VALUE_COMMERCIAL_LARGE,  60000   // Large commercial
.equ BUILDING_VALUE_COMMERCIAL_MALL,   100000  // Shopping mall

.equ BUILDING_VALUE_INDUSTRIAL_LIGHT, 15000   // Light industrial
.equ BUILDING_VALUE_INDUSTRIAL_HEAVY, 30000   // Heavy industrial
.equ BUILDING_VALUE_INDUSTRIAL_HIGH,  50000   // High-tech industrial

.equ BUILDING_VALUE_PARK_SMALL,     5000    // Small park
.equ BUILDING_VALUE_PARK_LARGE,     12000   // Large park
.equ BUILDING_VALUE_SPECIAL,        50000   // Special buildings

// Population constants
.equ POPULATION_PER_HOUSE_LOW,      4       // Low-density residential
.equ POPULATION_PER_HOUSE_MEDIUM,   8       // Medium-density residential
.equ POPULATION_PER_HOUSE_HIGH,     16      // High-density residential
.equ POPULATION_PER_HOUSE_LUXURY,   6       // Luxury (fewer people, more space)

// Job creation constants
.equ JOBS_PER_COMMERCIAL_SMALL,     6       // Small commercial jobs
.equ JOBS_PER_COMMERCIAL_MEDIUM,    12      // Medium commercial jobs
.equ JOBS_PER_COMMERCIAL_LARGE,     25      // Large commercial jobs
.equ JOBS_PER_COMMERCIAL_MALL,      50      // Shopping mall jobs

.equ JOBS_PER_INDUSTRIAL_LIGHT,     10      // Light industrial jobs
.equ JOBS_PER_INDUSTRIAL_HEAVY,     20      // Heavy industrial jobs
.equ JOBS_PER_INDUSTRIAL_HIGH,      15      // High-tech industrial jobs

// Economic demand factors
.equ DEMAND_RESIDENTIAL_BASE,       100     // Base residential demand
.equ DEMAND_COMMERCIAL_BASE,        80      // Base commercial demand
.equ DEMAND_INDUSTRIAL_BASE,        60      // Base industrial demand

// Economic multipliers (scaled by 1000)
.equ HAPPINESS_TAX_MULTIPLIER,      50      // Tax impact on happiness (0.050)
.equ UNEMPLOYMENT_HAPPINESS_FACTOR, 30      // Unemployment impact (0.030)
.equ POPULATION_GROWTH_RATE,        25      // Growth rate per month (0.025)

// Land value factors
.equ LAND_VALUE_BASE,               1000    // Base land value
.equ LAND_VALUE_MAX,                15000   // Maximum land value
.equ LAND_VALUE_PARK_BONUS,         200     // Land value bonus per nearby park
.equ LAND_VALUE_COMMERCIAL_BONUS,   150     // Land value bonus per nearby commercial
.equ LAND_VALUE_INDUSTRIAL_PENALTY, 100     // Land value penalty per nearby industrial

// Budget categories
.equ BUDGET_CATEGORY_POLICE,        0
.equ BUDGET_CATEGORY_FIRE,          1
.equ BUDGET_CATEGORY_HEALTH,        2
.equ BUDGET_CATEGORY_EDUCATION,     3
.equ BUDGET_CATEGORY_TRANSPORT,     4
.equ BUDGET_CATEGORY_UTILITIES,     5
.equ BUDGET_CATEGORY_COUNT,         6

// Service costs (per month)
.equ SERVICE_COST_POLICE_STATION,   1000
.equ SERVICE_COST_FIRE_STATION,     800
.equ SERVICE_COST_HOSPITAL,         1500
.equ SERVICE_COST_SCHOOL,           600
.equ SERVICE_COST_ROAD_MAINTENANCE, 10      // Per road tile
.equ SERVICE_COST_POWER_PLANT,      2000

// Supply and demand curve parameters
.equ RCI_DEMAND_MAX,                255     // Maximum demand level
.equ RCI_SUPPLY_MAX,                255     // Maximum supply level
.equ DEMAND_DECAY_RATE,             5       // How fast demand decays per month
.equ SUPPLY_GROWTH_RATE,            3       // How fast supply grows

// Economic indicators thresholds
.equ ECONOMIC_INDICATOR_RECESSION,  -50     // Below this = recession
.equ ECONOMIC_INDICATOR_GROWTH,     50      // Above this = boom
.equ UNEMPLOYMENT_RATE_HIGH,        15      // High unemployment threshold (%)
.equ UNEMPLOYMENT_RATE_LOW,         3       // Low unemployment threshold (%)

// Monthly economic update constants
.equ MONTHS_PER_YEAR,               12
.equ ECONOMIC_UPDATE_FREQUENCY,     30      // Update every 30 simulation ticks
.equ TAX_COLLECTION_FREQUENCY,      30      // Collect taxes every 30 ticks

// Building maintenance costs (per month, percentage of value)
.equ MAINTENANCE_RATE_RESIDENTIAL,  2       // 0.2% per month
.equ MAINTENANCE_RATE_COMMERCIAL,   3       // 0.3% per month
.equ MAINTENANCE_RATE_INDUSTRIAL,   4       // 0.4% per month

// Economic balance parameters
.equ STARTING_FUNDS,                50000   // Starting city funds
.equ MINIMUM_FUNDS,                 -25000  // City can go into debt
.equ LOAN_INTEREST_RATE,            5       // 5% annual interest on debt

// Population migration factors
.equ MIGRATION_HAPPINESS_THRESHOLD, 60      // Above this attracts residents
.equ MIGRATION_RATE_MAX,            50      // Maximum people moving per month
.equ EMIGRATION_HAPPINESS_THRESHOLD, 30     // Below this causes emigration

// Economic difficulty modifiers
.equ DIFFICULTY_EASY_TAX_BONUS,     20      // 20% tax bonus on easy
.equ DIFFICULTY_HARD_TAX_PENALTY,   20      // 20% tax penalty on hard
.equ DIFFICULTY_EASY_COST_REDUCTION, 25     // 25% cost reduction on easy
.equ DIFFICULTY_HARD_COST_INCREASE, 25      // 25% cost increase on hard

// RCI Balance factors (for SimCity-style gameplay)
.equ RCI_BALANCE_OPTIMAL_RATIO_R,   40      // 40% residential
.equ RCI_BALANCE_OPTIMAL_RATIO_C,   30      // 30% commercial  
.equ RCI_BALANCE_OPTIMAL_RATIO_I,   30      // 30% industrial

// Macros for economic calculations

// Calculate tax revenue from building value
.macro CALCULATE_TAX_REVENUE building_value, tax_rate, result
    mul     \result, \building_value, \tax_rate
    mov     x9, #100
    udiv    \result, \result, x9        // Divide by 100 for percentage
.endm

// Calculate population growth based on happiness
.macro CALCULATE_POPULATION_GROWTH current_pop, happiness, result
    sub     x9, \happiness, #50         // Happiness relative to neutral (50)
    mul     x9, x9, #POPULATION_GROWTH_RATE
    mov     x10, #1000
    sdiv    x9, x9, x10                 // Scale down
    mul     \result, \current_pop, x9
    mov     x10, #100
    sdiv    \result, \result, x10       // Percentage of current population
.endm

// Check if city is in economic crisis
.macro CHECK_ECONOMIC_CRISIS funds, unemployment_rate, label_crisis
    cmp     \funds, #MINIMUM_FUNDS
    b.lt    \label_crisis
    cmp     \unemployment_rate, #UNEMPLOYMENT_RATE_HIGH
    b.gt    \label_crisis
.endm

// Calculate land value based on surroundings
.macro CALCULATE_LAND_VALUE base_value, park_count, commercial_count, industrial_count, result
    mov     \result, \base_value
    mov     x9, #LAND_VALUE_PARK_BONUS
    mul     x10, \park_count, x9
    add     \result, \result, x10
    mov     x9, #LAND_VALUE_COMMERCIAL_BONUS
    mul     x10, \commercial_count, x9
    add     \result, \result, x10
    mov     x9, #LAND_VALUE_INDUSTRIAL_PENALTY
    mul     x10, \industrial_count, x9
    sub     \result, \result, x10
    mov     x9, #LAND_VALUE_MAX
    cmp     \result, x9
    csel    \result, \result, x9, lt     // Cap at maximum
.endm

// Structure size calculations for economic data
.equ EconomicState_size,        256     // Size of economic state structure
.equ TaxRecord_size,            32      // Size of tax record entry
.equ BudgetCategory_size,       16      // Size of budget category
.equ RCIDemand_size,            12      // Size of RCI demand structure