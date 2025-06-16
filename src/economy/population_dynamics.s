//
// SimCity ARM64 Assembly - Population Dynamics System
// Agent 2: Economic and Population Systems
//
// Handles population growth, migration, and demographic changes
//

.include "economic_constants.s"
.include "../simulation/simulation_constants.s"

.text
.global init_population_system
.global update_population_growth
.global calculate_migration
.global get_population_happiness_factor
.global update_age_demographics

//
// Population Demographics Structure (128 bytes)
//
// Offset  Size  Field
// 0       4     total_population
// 4       4     population_children (0-17)
// 8       4     population_adults (18-64)
// 12      4     population_seniors (65+)
// 16      4     population_employed
// 20      4     population_unemployed
// 24      4     population_students
// 28      4     birth_rate (per 1000)
// 32      4     death_rate (per 1000)
// 36      4     migration_in (per month)
// 40      4     migration_out (per month)
// 44      4     education_level_average
// 48      4     income_level_average
// 52      4     happiness_residential
// 56-127        reserved for future expansion
//

.data
.align 8
population_demographics:
    .word   0                           // total_population
    .word   0                           // population_children
    .word   0                           // population_adults
    .word   0                           // population_seniors
    .word   0                           // population_employed
    .word   0                           // population_unemployed
    .word   0                           // population_students
    .word   12                          // birth_rate (1.2% default)
    .word   8                           // death_rate (0.8% default)
    .word   0                           // migration_in
    .word   0                           // migration_out
    .word   50                          // education_level_average
    .word   35000                       // income_level_average
    .word   50                          // happiness_residential
    .space  72                          // reserved space

// Age distribution lookup table (percentage of population)
age_distribution_default:
    .word   25                          // children (25%)
    .word   65                          // adults (65%)
    .word   10                          // seniors (10%)

.text

//
// Initialize the population system
// Parameters: w0 = initial_population
// Returns: none
//
init_population_system:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get population demographics pointer
    adrp    x1, population_demographics
    add     x1, x1, :lo12:population_demographics
    
    // Set initial population
    str     w0, [x1, #0]                // total_population
    
    // Distribute population by age groups using default ratios
    adrp    x2, age_distribution_default
    add     x2, x2, :lo12:age_distribution_default
    
    // Children (25%)
    ldr     w3, [x2, #0]
    mul     w4, w0, w3
    mov     w5, #100
    udiv    w4, w4, w5
    str     w4, [x1, #4]                // population_children
    
    // Adults (65%)
    ldr     w3, [x2, #4]
    mul     w4, w0, w3
    udiv    w4, w4, w5
    str     w4, [x1, #8]                // population_adults
    
    // Seniors (10%)
    ldr     w3, [x2, #8]
    mul     w4, w0, w3
    udiv    w4, w4, w5
    str     w4, [x1, #12]               // population_seniors
    
    // Assume 70% of adults are employable
    ldr     w6, [x1, #8]                // population_adults
    mov     w7, #70
    mul     w8, w6, w7
    udiv    w8, w8, w5
    str     w8, [x1, #16]               // population_employed (initial)
    
    ldp     x29, x30, [sp], #16
    ret

//
// Update population growth based on economic conditions
// Parameters: x0 = economic_state pointer
// Returns: w0 = population_change
//
update_population_growth:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // Save economic state pointer
    
    // Get population demographics
    adrp    x20, population_demographics
    add     x20, x20, :lo12:population_demographics
    
    // Get current happiness and economic factors
    ldr     w1, [x19, #48]              // happiness_average from economic state
    ldr     w2, [x19, #80]              // economic_indicator
    
    // Calculate natural population change (births - deaths)
    ldr     w3, [x20, #0]               // total_population
    ldr     w4, [x20, #28]              // birth_rate
    ldr     w5, [x20, #32]              // death_rate
    
    // Natural increase = (birth_rate - death_rate) * population / 1000 / 12 (monthly)
    sub     w6, w4, w5                  // net_rate
    mul     w7, w3, w6                  // population * net_rate
    mov     w8, #12000                  // 1000 * 12 (annual to monthly conversion)
    sdiv    w7, w7, w8                  // monthly natural change
    
    // Calculate migration based on happiness
    mov     x0, x20
    mov     w1, w1                      // happiness
    bl      calculate_migration
    mov     w8, w0                      // migration_net
    
    // Total population change
    add     w0, w7, w8                  // natural_change + migration_net
    
    // Update total population
    add     w3, w3, w0
    cmp     w3, #0                      // Ensure population doesn't go negative
    csel    w3, w3, wzr, gt
    str     w3, [x20, #0]
    
    // Update age demographics (simplified)
    bl      update_age_demographics
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// Calculate net migration based on city conditions
// Parameters: x0 = population_demographics pointer, w1 = happiness_level
// Returns: w0 = net_migration (positive = immigration, negative = emigration)
//
calculate_migration:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    mov     w2, w1                      // Save happiness
    mov     w3, #0                      // net_migration
    
    // High happiness attracts immigrants
    cmp     w2, #MIGRATION_HAPPINESS_THRESHOLD
    b.lt    calculate_migration_emigration
    
    // Immigration rate increases with happiness above threshold
    sub     w4, w2, #MIGRATION_HAPPINESS_THRESHOLD
    mov     w5, #MIGRATION_RATE_MAX
    mul     w6, w4, w5
    mov     w7, #40                     // Scale factor (100 - 60)
    udiv    w3, w6, w7
    
    // Store immigration
    str     w3, [x0, #36]               // migration_in
    str     wzr, [x0, #40]              // migration_out = 0
    b       calculate_migration_exit
    
calculate_migration_emigration:
    // Low happiness causes emigration
    cmp     w2, #EMIGRATION_HAPPINESS_THRESHOLD
    b.gt    calculate_migration_minimal
    
    // Emigration rate increases as happiness drops below threshold
    sub     w4, #EMIGRATION_HAPPINESS_THRESHOLD, w2  // How far below threshold
    mov     w5, #MIGRATION_RATE_MAX
    mul     w6, w4, w5
    mov     w7, #30                     // Scale factor
    udiv    w6, w6, w7
    neg     w3, w6                      // Negative for emigration
    
    // Store emigration
    str     wzr, [x0, #36]              // migration_in = 0
    str     w6, [x0, #40]               // migration_out
    b       calculate_migration_exit
    
calculate_migration_minimal:
    // Neutral happiness = minimal migration
    mov     w3, #0
    str     wzr, [x0, #36]
    str     wzr, [x0, #40]
    
calculate_migration_exit:
    mov     w0, w3                      // Return net migration
    ldp     x29, x30, [sp], #16
    ret

//
// Get population happiness factor based on employment and services
// Parameters: x0 = population_demographics pointer, x1 = jobs_available
// Returns: w0 = happiness_factor (0-100)
//
get_population_happiness_factor:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Base happiness
    mov     w2, #50                     // Neutral happiness
    
    // Get employment data
    ldr     w3, [x0, #16]               // population_employed
    ldr     w4, [x0, #20]               // population_unemployed
    add     w5, w3, w4                  // total_workforce
    
    cbz     w5, get_happiness_factor_exit  // No workforce
    
    // Calculate employment rate
    mov     w6, #100
    mul     w7, w3, w6                  // employed * 100
    udiv    w8, w7, w5                  // employment_rate (percentage)
    
    // Happiness increases with employment rate
    // 100% employment = +30 happiness, 0% employment = -30 happiness
    sub     w9, w8, #50                 // Relative to neutral (50%)
    mov     w10, #30
    mul     w11, w9, w10
    mov     w12, #50
    sdiv    w11, w11, w12               // Scale to happiness impact
    add     w2, w2, w11
    
    // Cap happiness between 0 and 100
    cmp     w2, #100
    csel    w2, w2, #100, lt
    cmp     w2, #0
    csel    w2, w2, wzr, gt
    
get_happiness_factor_exit:
    mov     w0, w2
    ldp     x29, x30, [sp], #16
    ret

//
// Update age demographics over time
// Parameters: none (uses global population_demographics)
// Returns: none
//
update_age_demographics:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get population demographics
    adrp    x0, population_demographics
    add     x0, x0, :lo12:population_demographics
    
    // Age progression (simplified monthly aging)
    ldr     w1, [x0, #4]                // population_children
    ldr     w2, [x0, #8]                // population_adults
    ldr     w3, [x0, #12]               // population_seniors
    
    // Small percentage of children become adults each month
    mov     w4, #100                    // 1% of children age to adults monthly
    udiv    w5, w1, w4
    sub     w1, w1, w5                  // Reduce children
    add     w2, w2, w5                  // Increase adults
    
    // Small percentage of adults become seniors
    mov     w4, #200                    // 0.5% of adults age to seniors monthly
    udiv    w6, w2, w4
    sub     w2, w2, w6                  // Reduce adults
    add     w3, w3, w6                  // Increase seniors
    
    // Update demographics
    str     w1, [x0, #4]                // population_children
    str     w2, [x0, #8]                // population_adults
    str     w3, [x0, #12]               // population_seniors
    
    // Recalculate employable population (adults only)
    mov     w7, #75                     // 75% of adults are employable
    mul     w8, w2, w7
    mov     w9, #100
    udiv    w8, w8, w9
    
    // This becomes the potential employed population
    // Actual employment depends on job availability
    ldr     w10, [x0, #16]              // current employed
    ldr     w11, [x0, #20]              // current unemployed
    
    // Ensure employed + unemployed doesn't exceed employable population
    add     w12, w10, w11               // total_seeking_work
    cmp     w12, w8                     // Compare with employable
    b.le    update_age_demographics_exit
    
    // Adjust if needed (prioritize keeping jobs)
    cmp     w10, w8
    b.le    update_age_demographics_unemployed
    
    // Too many employed, reduce employment
    mov     w10, w8
    mov     w11, #0
    b       update_age_demographics_store
    
update_age_demographics_unemployed:
    // Adjust unemployed count
    sub     w11, w8, w10
    
update_age_demographics_store:
    str     w10, [x0, #16]              // population_employed
    str     w11, [x0, #20]              // population_unemployed
    
update_age_demographics_exit:
    ldp     x29, x30, [sp], #16
    ret

// Global population demographics accessor
.global get_population_demographics
get_population_demographics:
    adrp    x0, population_demographics
    add     x0, x0, :lo12:population_demographics
    ret

//
// Calculate education and skill levels impact on economic growth
// Parameters: x0 = population_demographics pointer
// Returns: w0 = education_multiplier (percentage, 100 = neutral)
//
.global calculate_education_impact
calculate_education_impact:
    ldr     w1, [x0, #44]               // education_level_average
    
    // Education level affects economic productivity
    // 0 = 50% productivity, 50 = 100% productivity, 100 = 150% productivity
    add     w2, w1, #50                 // Shift range
    cmp     w2, #200
    csel    w0, w2, #200, lt            // Cap at 200%
    ret

//
// Update employment based on available jobs
// Parameters: x0 = population_demographics pointer, w1 = jobs_available
// Returns: none
//
.global update_employment_status
update_employment_status:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get current employment status
    ldr     w2, [x0, #16]               // population_employed
    ldr     w3, [x0, #20]               // population_unemployed
    add     w4, w2, w3                  // total_workforce
    
    // Determine new employment based on job availability
    cmp     w1, w4                      // jobs vs workforce
    b.ge    update_employment_full      // More jobs than workers
    
    // Not enough jobs for everyone
    mov     w2, w1                      // employed = jobs_available
    sub     w3, w4, w1                  // unemployed = workforce - jobs
    b       update_employment_store
    
update_employment_full:
    // Full employment possible
    mov     w2, w4                      // all workforce employed
    mov     w3, #0                      // no unemployment
    
update_employment_store:
    str     w2, [x0, #16]               // population_employed
    str     w3, [x0, #20]               // population_unemployed
    
    ldp     x29, x30, [sp], #16
    ret