.section __TEXT,__text,regular,pure_instructions
.align 4

// RCI Demand System - Pure ARM64 Assembly Implementation
// Agent A4 - Simulation Team
// Converts C implementation to high-performance assembly with NEON optimizations

// Constants and data structures
.equ ZONE_NONE, 0
.equ ZONE_RESIDENTIAL_LOW, 1
.equ ZONE_RESIDENTIAL_MEDIUM, 2
.equ ZONE_RESIDENTIAL_HIGH, 3
.equ ZONE_COMMERCIAL_LOW, 4
.equ ZONE_COMMERCIAL_HIGH, 5
.equ ZONE_INDUSTRIAL_AGRICULTURE, 6
.equ ZONE_INDUSTRIAL_DIRTY, 7
.equ ZONE_INDUSTRIAL_MANUFACTURING, 8
.equ ZONE_INDUSTRIAL_HIGHTECH, 9

// Struct sizes (in bytes)
.equ DEMAND_FACTORS_SIZE, 32        // 8 floats * 4 bytes
.equ RCI_DEMAND_SIZE, 36           // 9 floats * 4 bytes
.equ LOT_INFO_SIZE, 24             // 4 + 4 + 4 + 4 + 4 + 4 bytes
.equ ZONE_PARAMS_SIZE, 24          // 6 floats * 4 bytes

// Global data section
.section __DATA,__data
.align 8

// Global RCI demand state
g_current_demand:
    .space RCI_DEMAND_SIZE
    
g_simulation_tick:
    .word 0

// Zone parameter constants (6 floats per zone type)
// Format: base_demand, tax_sensitivity, unemployment_sensitivity, 
//         commute_sensitivity, education_requirement, pollution_tolerance
.align 4
g_zone_params:
    // ZONE_NONE (unused)
    .float 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
    // ZONE_RESIDENTIAL_LOW
    .float 20.0, -2.0, -3.0, -1.5, 0.0, 0.6
    // ZONE_RESIDENTIAL_MEDIUM  
    .float 15.0, -2.5, -4.0, -2.0, 0.3, 0.3
    // ZONE_RESIDENTIAL_HIGH
    .float 10.0, -3.0, -5.0, -3.0, 0.6, 0.1
    // ZONE_COMMERCIAL_LOW
    .float 15.0, -2.5, 2.0, -1.0, 0.2, 0.5
    // ZONE_COMMERCIAL_HIGH
    .float 10.0, -3.5, 1.5, -2.0, 0.7, 0.2
    // ZONE_INDUSTRIAL_AGRICULTURE
    .float 12.0, -1.5, 3.0, -0.5, 0.0, 0.8
    // ZONE_INDUSTRIAL_DIRTY
    .float 18.0, -2.0, 4.0, -0.5, 0.1, 1.0
    // ZONE_INDUSTRIAL_MANUFACTURING
    .float 15.0, -2.5, 3.5, -1.0, 0.4, 0.7
    // ZONE_INDUSTRIAL_HIGHTECH
    .float 8.0, -3.0, 2.5, -2.0, 0.8, 0.3

// Constants for calculations
.align 4
const_30_0:         .float 30.0     // Base commute time
const_10_0:         .float 10.0     // Commute divisor
const_20_0:         .float 20.0     // Education penalty
const_15_0:         .float 15.0     // Pollution penalty
const_5_0:          .float 5.0      // Utility boost
const_100_0:        .float 100.0    // Clamp bounds
const_neg_100_0:    .float -100.0   // Clamp bounds
const_200_0:        .float 200.0    // Desirability conversion
const_0_1:          .float 0.1      // Smoothing factor
const_0_9:          .float 0.9      // Smoothing factor
const_growth_thresh: .float 0.6     // Growth threshold
const_decay_thresh:  .float 0.3     // Decay threshold
const_120_0:        .float 120.0    // Commute time max
const_0_8:          .float 0.8      // Service base
const_0_2:          .float 0.2      // Service multiplier

// Residential demand weights
res_weights:        .float 0.5, 0.3, 0.2, 0.0
// Commercial demand weights  
com_weights:        .float 0.6, 0.4, 0.0, 0.0
// Industrial demand weights
ind_weights:        .float 0.2, 0.3, 0.3, 0.2

.section __TEXT,__text,regular,pure_instructions

//==============================================================================
// _rci_init: Initialize RCI demand system
// Input: none
// Output: x0 = 0 on success
// Modifies: x0-x2, v0-v1
//==============================================================================
.global _rci_init
_rci_init:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Clear demand structure using NEON
    adrp x0, g_current_demand@PAGE
    add x0, x0, g_current_demand@PAGEOFF
    
    // Zero out 36 bytes (9 floats) using NEON
    movi v0.4s, #0
    movi v1.4s, #0
    
    stp q0, q1, [x0]        // Store first 32 bytes
    str w1, [x0, #32]       // Store last 4 bytes
    
    // Reset simulation tick
    adrp x1, g_simulation_tick@PAGE
    add x1, x1, g_simulation_tick@PAGEOFF
    str wzr, [x1]
    
    // Set initial demand values
    adrp x1, const_20_0@PAGE
    add x1, x1, const_20_0@PAGEOFF
    ldr s0, [x1]            // 20.0f for residential
    str s0, [x0]            // Store at offset 0 (residential)
    
    adrp x1, const_10_0@PAGE
    add x1, x1, const_10_0@PAGEOFF
    ldr s1, [x1]            // 10.0f for commercial
    str s1, [x0, #4]        // Store at offset 4 (commercial)
    
    adrp x1, const_15_0@PAGE
    add x1, x1, const_15_0@PAGEOFF
    ldr s2, [x1]            // 15.0f for industrial
    str s2, [x0, #8]        // Store at offset 8 (industrial)
    
    mov x0, #0              // Return success
    ldp x29, x30, [sp], #16
    ret

//==============================================================================
// _clamp_float: Clamp float value between min and max
// Input: s0 = value, s1 = min, s2 = max
// Output: s0 = clamped value
// Modifies: s0
//==============================================================================
_clamp_float:
    fmin s0, s0, s2         // value = min(value, max)
    fmax s0, s0, s1         // value = max(value, min)
    ret

//==============================================================================
// _calculate_zone_demand: Calculate demand for specific zone type using NEON
// Input: w0 = zone_type, x1 = DemandFactors pointer
// Output: s0 = calculated demand
// Modifies: x0-x4, v0-v7
//==============================================================================
_calculate_zone_demand:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Validate zone type
    cmp w0, #ZONE_NONE
    b.le _calc_zone_zero
    cmp w0, #ZONE_INDUSTRIAL_HIGHTECH
    b.gt _calc_zone_zero
    
    // Load zone parameters using NEON
    adrp x2, g_zone_params@PAGE
    add x2, x2, g_zone_params@PAGEOFF
    mov x3, #ZONE_PARAMS_SIZE
    mul x3, x0, x3          // offset = zone_type * 24
    add x2, x2, x3          // x2 = &g_zone_params[zone_type]
    
    // Load zone parameters using individual loads for simplicity
    ldr s10, [x2]           // base_demand
    ldr s11, [x2, #4]       // tax_sensitivity
    ldr s12, [x2, #8]       // unemployment_sensitivity
    ldr s13, [x2, #12]      // commute_sensitivity
    ldr s14, [x2, #16]      // education_requirement
    ldr s15, [x2, #20]      // pollution_tolerance
    
    // Load demand factors
    ldr s20, [x1]           // tax_rate
    ldr s21, [x1, #4]       // unemployment_rate
    ldr s22, [x1, #8]       // average_commute_time
    ldr s23, [x1, #12]      // education_level
    ldr s24, [x1, #16]      // pollution_level
    ldr s25, [x1, #20]      // crime_rate
    ldr s26, [x1, #24]      // land_value
    ldr s27, [x1, #28]      // utility_coverage
    
    // Start with base demand
    fmov s4, s10            // s4 = base_demand
    
    // Tax impact: demand += tax_sensitivity * tax_rate
    fmul s5, s11, s20       // s5 = tax_sens * tax_rate
    fadd s4, s4, s5         // demand += tax impact
    
    // Unemployment impact: demand += unemployment_sensitivity * unemployment_rate
    fmul s5, s12, s21       // s5 = unemployment_sensitivity * unemployment_rate
    fadd s4, s4, s5
    
    // Commute time impact
    fmov s5, s13            // s5 = commute_sensitivity
    fmov s6, s22            // s6 = average_commute_time
    adrp x2, const_30_0@PAGE
    add x2, x2, const_30_0@PAGEOFF
    ldr s7, [x2]            // s7 = 30.0
    fsub s6, s6, s7         // commute_time - 30.0
    adrp x2, const_10_0@PAGE
    add x2, x2, const_10_0@PAGEOFF
    ldr s7, [x2]            // s7 = 10.0
    fdiv s6, s6, s7         // (commute_time - 30.0) / 10.0
    fmul s5, s5, s6
    fadd s4, s4, s5
    
    // Education impact
    fmov s5, s14            // s5 = education_requirement
    fmov s6, s23            // s6 = education_level
    fsub s5, s5, s6         // education_gap = requirement - level
    fcmp s5, #0.0
    b.le _skip_education_penalty
    
    adrp x2, const_20_0@PAGE
    add x2, x2, const_20_0@PAGEOFF
    ldr s6, [x2]            // s6 = 20.0
    fmul s5, s5, s6         // education_gap * 20.0
    fsub s4, s4, s5         // demand -= education penalty
    
_skip_education_penalty:
    // Pollution impact
    fmov s5, s24            // s5 = pollution_level
    fmov s6, s15            // s6 = pollution_tolerance
    fsub s5, s5, s6         // pollution_penalty = level - tolerance
    fcmp s5, #0.0
    b.le _skip_pollution_penalty
    
    adrp x2, const_15_0@PAGE
    add x2, x2, const_15_0@PAGEOFF
    ldr s6, [x2]            // s6 = 15.0
    fmul s5, s5, s6         // pollution_penalty * 15.0
    fsub s4, s4, s5         // demand -= pollution penalty
    
_skip_pollution_penalty:
    // Crime impact: demand -= crime_rate * 10.0
    fmov s5, s25            // s5 = crime_rate
    adrp x2, const_10_0@PAGE
    add x2, x2, const_10_0@PAGEOFF
    ldr s6, [x2]            // s6 = 10.0
    fmul s5, s5, s6
    fsub s4, s4, s5
    
    // Utility coverage boost: demand += utility_coverage * 5.0
    fmov s5, s27            // s5 = utility_coverage
    adrp x2, const_5_0@PAGE
    add x2, x2, const_5_0@PAGEOFF
    ldr s6, [x2]            // s6 = 5.0
    fmul s5, s5, s6
    fadd s4, s4, s5
    
    // Clamp result between -100.0 and 100.0
    adrp x2, const_neg_100_0@PAGE
    add x2, x2, const_neg_100_0@PAGEOFF
    ldr s1, [x2]            // s1 = -100.0
    adrp x2, const_100_0@PAGE
    add x2, x2, const_100_0@PAGEOFF
    ldr s2, [x2]            // s2 = 100.0
    fmov s0, s4             // Move result to s0
    bl _clamp_float
    
    ldp x29, x30, [sp], #16
    ret

_calc_zone_zero:
    fmov s0, wzr            // Return 0.0 for invalid zones
    ldp x29, x30, [sp], #16
    ret

//==============================================================================
// _rci_tick: Update RCI demand calculations (main simulation tick)
// Input: x0 = DemandFactors pointer
// Output: none
// Modifies: many registers
//==============================================================================
.global _rci_tick
_rci_tick:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    str x23, [sp, #48]
    
    mov x19, x0             // Save DemandFactors pointer
    
    // Get demand structure pointer
    adrp x20, g_current_demand@PAGE
    add x20, x20, g_current_demand@PAGEOFF
    
    // Calculate demand for each zone type
    // Residential Low
    mov w0, #ZONE_RESIDENTIAL_LOW
    mov x1, x19
    bl _calculate_zone_demand
    str s0, [x20, #12]      // Store at residential_low offset
    
    // Residential Medium
    mov w0, #ZONE_RESIDENTIAL_MEDIUM
    mov x1, x19
    bl _calculate_zone_demand
    str s0, [x20, #16]      // Store at residential_medium offset
    
    // Residential High
    mov w0, #ZONE_RESIDENTIAL_HIGH
    mov x1, x19
    bl _calculate_zone_demand
    str s0, [x20, #20]      // Store at residential_high offset
    
    // Commercial Low
    mov w0, #ZONE_COMMERCIAL_LOW
    mov x1, x19
    bl _calculate_zone_demand
    str s0, [x20, #24]      // Store at commercial_low offset
    
    // Commercial High
    mov w0, #ZONE_COMMERCIAL_HIGH
    mov x1, x19
    bl _calculate_zone_demand
    str s0, [x20, #28]      // Store at commercial_high offset
    
    // Industrial Agriculture
    mov w0, #ZONE_INDUSTRIAL_AGRICULTURE
    mov x1, x19
    bl _calculate_zone_demand
    str s0, [x20, #32]      // Store at industrial_agriculture offset
    
    // Industrial Dirty
    mov w0, #ZONE_INDUSTRIAL_DIRTY
    mov x1, x19
    bl _calculate_zone_demand
    str s0, [x20, #36]      // Store at industrial_dirty offset
    
    // Industrial Manufacturing
    mov w0, #ZONE_INDUSTRIAL_MANUFACTURING
    mov x1, x19
    bl _calculate_zone_demand
    str s0, [x20, #40]      // Store at industrial_manufacturing offset
    
    // Industrial High-tech
    mov w0, #ZONE_INDUSTRIAL_HIGHTECH
    mov x1, x19
    bl _calculate_zone_demand
    str s0, [x20, #44]      // Store at industrial_hightech offset
    
    // Calculate aggregate RCI values using NEON for parallel computation
    // Residential aggregate = res_low * 0.5 + res_med * 0.3 + res_high * 0.2
    adrp x21, res_weights@PAGE
    add x21, x21, res_weights@PAGEOFF
    ld1 {v0.4s}, [x21]      // Load weights: [0.5, 0.3, 0.2, 0.0]
    
    // Load residential demands
    add x21, x20, #12       // Point to residential_low
    ld1 {v1.4s}, [x21]      // Load [res_low, res_med, res_high, com_low]
    
    // Multiply and sum using NEON
    fmul v2.4s, v1.4s, v0.4s    // Multiply by weights
    faddp v3.4s, v2.4s, v2.4s   // Pairwise add
    faddp v3.4s, v3.4s, v3.4s   // Final sum
    str s3, [x20]               // Store residential aggregate
    
    // Commercial aggregate = com_low * 0.6 + com_high * 0.4
    adrp x21, com_weights@PAGE
    add x21, x21, com_weights@PAGEOFF
    ld1 {v0.2s}, [x21]      // Load weights: [0.6, 0.4]
    
    ldr d1, [x20, #24]      // Load [com_low, com_high]
    fmul v2.2s, v1.2s, v0.2s    // Multiply by weights
    faddp v3.2s, v2.2s, v2.2s   // Sum
    str s3, [x20, #4]           // Store commercial aggregate
    
    // Industrial aggregate = ind_agri * 0.2 + ind_dirty * 0.3 + ind_manu * 0.3 + ind_tech * 0.2
    adrp x21, ind_weights@PAGE
    add x21, x21, ind_weights@PAGEOFF
    ld1 {v0.4s}, [x21]      // Load weights: [0.2, 0.3, 0.3, 0.2]
    
    add x21, x20, #32       // Point to industrial_agriculture
    ld1 {v1.4s}, [x21]      // Load all industrial demands
    
    fmul v2.4s, v1.4s, v0.4s    // Multiply by weights
    faddp v3.4s, v2.4s, v2.4s   // Pairwise add
    faddp v3.4s, v3.4s, v3.4s   // Final sum
    str s3, [x20, #8]           // Store industrial aggregate
    
    // Increment simulation tick
    adrp x21, g_simulation_tick@PAGE
    add x21, x21, g_simulation_tick@PAGEOFF
    ldr w22, [x21]
    add w22, w22, #1
    str w22, [x21]
    
    ldr x23, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

//==============================================================================
// _rci_get_demand: Get current demand values
// Input: none
// Output: x0 = pointer to RCIDemand structure
// Modifies: x0
//==============================================================================
.global _rci_get_demand
_rci_get_demand:
    adrp x0, g_current_demand@PAGE
    add x0, x0, g_current_demand@PAGEOFF
    ret

//==============================================================================
// _rci_calculate_lot_desirability: Calculate lot desirability using NEON
// Input: w0 = zone_type, s0 = land_value, s1 = commute_time, s2 = services
// Output: s0 = desirability (0.0 to 1.0)
// Modifies: x0-x3, v0-v7
//==============================================================================
.global _rci_calculate_lot_desirability
_rci_calculate_lot_desirability:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Save input parameters in separate registers
    fmov s28, s0            // land_value
    fmov s29, s1            // commute_time
    fmov s30, s2            // services
    mov w3, w0              // zone_type
    
    // Get zone demand from current demand structure
    adrp x1, g_current_demand@PAGE
    add x1, x1, g_current_demand@PAGEOFF
    
    // Calculate offset for zone-specific demand
    fmov s0, wzr            // Default to 0.0
    
    cmp w3, #ZONE_RESIDENTIAL_LOW
    b.ne _check_res_med
    ldr s0, [x1, #12]       // residential_low
    b _got_zone_demand
    
_check_res_med:
    cmp w3, #ZONE_RESIDENTIAL_MEDIUM
    b.ne _check_res_high
    ldr s0, [x1, #16]       // residential_medium
    b _got_zone_demand
    
_check_res_high:
    cmp w3, #ZONE_RESIDENTIAL_HIGH
    b.ne _check_com_low
    ldr s0, [x1, #20]       // residential_high
    b _got_zone_demand
    
_check_com_low:
    cmp w3, #ZONE_COMMERCIAL_LOW
    b.ne _check_com_high
    ldr s0, [x1, #24]       // commercial_low
    b _got_zone_demand
    
_check_com_high:
    cmp w3, #ZONE_COMMERCIAL_HIGH
    b.ne _check_ind_agri
    ldr s0, [x1, #28]       // commercial_high
    b _got_zone_demand
    
_check_ind_agri:
    cmp w3, #ZONE_INDUSTRIAL_AGRICULTURE
    b.ne _check_ind_dirty
    ldr s0, [x1, #32]       // industrial_agriculture
    b _got_zone_demand
    
_check_ind_dirty:
    cmp w3, #ZONE_INDUSTRIAL_DIRTY
    b.ne _check_ind_manu
    ldr s0, [x1, #36]       // industrial_dirty
    b _got_zone_demand
    
_check_ind_manu:
    cmp w3, #ZONE_INDUSTRIAL_MANUFACTURING
    b.ne _check_ind_tech
    ldr s0, [x1, #40]       // industrial_manufacturing
    b _got_zone_demand
    
_check_ind_tech:
    cmp w3, #ZONE_INDUSTRIAL_HIGHTECH
    b.ne _got_zone_demand
    ldr s0, [x1, #44]       // industrial_hightech
    
_got_zone_demand:
    // Convert demand (-100 to +100) to desirability (0 to 1)
    adrp x1, const_100_0@PAGE
    add x1, x1, const_100_0@PAGEOFF
    ldr s1, [x1]            // s1 = 100.0
    fadd s0, s0, s1         // demand + 100.0
    adrp x1, const_200_0@PAGE
    add x1, x1, const_200_0@PAGEOFF
    ldr s2, [x1]            // s2 = 200.0
    fdiv s0, s0, s2         // (demand + 100.0) / 200.0
    
    // Land value modifier for medium+ zones
    fmov s5, #1.0           // Default land_value_factor = 1.0
    cmp w3, #ZONE_RESIDENTIAL_MEDIUM
    b.lt _skip_land_value
    cmp w3, #ZONE_COMMERCIAL_HIGH
    b.gt _skip_land_value
    
    // land_value_factor = 0.5 + land_value * 0.5
    fmov s6, #0.5
    fmov s7, s28            // land_value
    fmul s7, s7, s6         // land_value * 0.5
    fadd s5, s6, s7         // 0.5 + (land_value * 0.5)
    
_skip_land_value:
    // Apply land value factor
    fmul s0, s0, s5
    
    // Commute time penalty: factor = 1.0 - (commute_time / 120.0)
    fmov s6, s29            // commute_time
    adrp x2, const_120_0@PAGE
    add x2, x2, const_120_0@PAGEOFF
    ldr s7, [x2]            // 120.0
    fdiv s6, s6, s7         // commute_time / 120.0
    fmov s7, #1.0
    fsub s6, s7, s6         // 1.0 - (commute_time / 120.0)
    
    // Clamp commute factor between 0.1 and 1.0
    adrp x2, const_0_1@PAGE
    add x2, x2, const_0_1@PAGEOFF
    ldr s1, [x2]            // 0.1
    fmov s2, #1.0
    fmov s8, s0             // Save desirability
    fmov s0, s6
    bl _clamp_float
    fmov s6, s0
    fmov s0, s8             // Restore desirability
    
    // Service coverage factor: 0.8 + services * 0.2
    adrp x2, const_0_8@PAGE
    add x2, x2, const_0_8@PAGEOFF
    ldr s7, [x2]            // 0.8
    fmov s8, s30            // services
    adrp x2, const_0_2@PAGE
    add x2, x2, const_0_2@PAGEOFF
    ldr s9, [x2]            // 0.2
    fmul s8, s8, s9         // services * 0.2
    fadd s7, s7, s8         // 0.8 + (services * 0.2)
    
    // Multiply factors together
    fmul s0, s0, s6         // desirability * commute_factor
    fmul s0, s0, s7         // * service_factor
    
    // Final clamp between 0.0 and 1.0
    fmov s1, wzr            // 0.0
    fmov s2, #1.0           // 1.0
    bl _clamp_float
    
    ldp x29, x30, [sp], #16
    ret

//==============================================================================
// _rci_process_lot_development: Process lot growth/decay with NEON optimization
// Input: x0 = LotInfo pointer, x1 = DemandFactors pointer
// Output: none
// Modifies: many registers
//==============================================================================
.global _rci_process_lot_development
_rci_process_lot_development:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    mov x19, x0             // Save LotInfo pointer
    mov x20, x1             // Save DemandFactors pointer
    
    // Calculate current desirability
    ldr w0, [x19]           // zone_type
    ldr s0, [x20, #24]      // land_value from DemandFactors
    ldr s1, [x20, #8]       // average_commute_time
    ldr s2, [x20, #28]      // utility_coverage
    bl _rci_calculate_lot_desirability
    
    // Update lot desirability with smoothing: new = old * 0.9 + current * 0.1
    ldr s1, [x19, #12]      // old desirability
    adrp x1, const_0_9@PAGE
    add x1, x1, const_0_9@PAGEOFF
    ldr s2, [x1]            // 0.9
    fmul s1, s1, s2         // old * 0.9
    
    adrp x1, const_0_1@PAGE
    add x1, x1, const_0_1@PAGEOFF
    ldr s2, [x1]            // 0.1
    fmul s3, s0, s2         // current * 0.1
    fadd s1, s1, s3         // old * 0.9 + current * 0.1
    str s1, [x19, #12]      // Store new desirability
    
    // Check growth/decay thresholds
    adrp x1, const_growth_thresh@PAGE
    add x1, x1, const_growth_thresh@PAGEOFF
    ldr s2, [x1]            // 0.6 growth threshold
    fcmp s1, s2
    b.hi _lot_growth
    
    adrp x1, const_decay_thresh@PAGE
    add x1, x1, const_decay_thresh@PAGEOFF
    ldr s2, [x1]            // 0.3 decay threshold
    fcmp s1, s2
    b.lo _lot_decay
    
    // Stable - set growth rate to 0
    str wzr, [x19, #16]     // growth_rate = 0.0
    b _update_tick
    
_lot_growth:
    // growth_rate = (desirability - GROWTH_THRESHOLD) * 2.0
    adrp x1, const_growth_thresh@PAGE
    add x1, x1, const_growth_thresh@PAGEOFF
    ldr s2, [x1]            // 0.6
    fsub s3, s1, s2         // desirability - threshold
    fmov s4, #2.0
    fmul s3, s3, s4         // * 2.0
    str s3, [x19, #16]      // Store growth_rate
    
    // Update population/jobs based on zone type
    ldr w1, [x19]           // zone_type
    cmp w1, #ZONE_RESIDENTIAL_LOW
    b.lt _update_tick
    cmp w1, #ZONE_RESIDENTIAL_HIGH
    b.gt _growth_jobs
    
    // Residential growth: population += growth_rate * 10
    fmov s4, #10.0
    fmul s3, s3, s4         // growth_rate * 10
    fcvtzu w2, s3           // Convert to integer
    ldr w3, [x19, #4]       // current population
    add w3, w3, w2          // Add growth
    str w3, [x19, #4]       // Store new population
    b _update_tick
    
_growth_jobs:
    // Commercial/Industrial growth: jobs += growth_rate * 5
    fmov s4, #5.0
    fmul s3, s3, s4         // growth_rate * 5
    fcvtzu w2, s3           // Convert to integer
    ldr w3, [x19, #8]       // current jobs
    add w3, w3, w2          // Add growth
    str w3, [x19, #8]       // Store new jobs
    b _update_tick
    
_lot_decay:
    // growth_rate = (desirability - DECAY_THRESHOLD) * 1.5 (negative)
    adrp x1, const_decay_thresh@PAGE
    add x1, x1, const_decay_thresh@PAGEOFF
    ldr s2, [x1]            // 0.3
    fsub s3, s1, s2         // desirability - threshold (negative)
    fmov s4, #1.5
    fmul s3, s3, s4         // * 1.5
    str s3, [x19, #16]      // Store growth_rate (negative)
    
    // Calculate loss amounts
    fneg s3, s3             // Make positive for loss calculation
    
    // Population loss
    ldr w1, [x19, #4]       // current population
    cbz w1, _check_jobs_decay
    
    fmov s4, #5.0
    fmul s5, s3, s4         // loss_rate * 5
    fcvtzu w2, s5           // Convert to integer loss
    cmp w2, w1              // Compare loss to current
    b.ge _zero_population
    sub w1, w1, w2          // Subtract loss
    str w1, [x19, #4]       // Store new population
    b _check_jobs_decay
    
_zero_population:
    str wzr, [x19, #4]      // Set population to 0
    
_check_jobs_decay:
    // Jobs loss
    ldr w1, [x19, #8]       // current jobs
    cbz w1, _update_tick
    
    fmov s4, #3.0
    fmul s5, s3, s4         // loss_rate * 3
    fcvtzu w2, s5           // Convert to integer loss
    cmp w2, w1              // Compare loss to current
    b.ge _zero_jobs
    sub w1, w1, w2          // Subtract loss
    str w1, [x19, #8]       // Store new jobs
    b _update_tick
    
_zero_jobs:
    str wzr, [x19, #8]      // Set jobs to 0
    
_update_tick:
    // Update last_update_tick
    adrp x1, g_simulation_tick@PAGE
    add x1, x1, g_simulation_tick@PAGEOFF
    ldr w2, [x1]
    str w2, [x19, #20]      // Store current tick
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

//==============================================================================
// _rci_cleanup: Cleanup RCI demand system
// Input: none
// Output: none
// Modifies: none (placeholder for future cleanup needs)
//==============================================================================
.global _rci_cleanup
_rci_cleanup:
    ret

// Export symbols for C compatibility (with double underscore for C linkage)
.global __rci_init
.global __rci_tick
.global __rci_get_demand
.global __rci_calculate_lot_desirability
.global __rci_process_lot_development
.global __rci_cleanup

// Alias double underscore names to single underscore implementations
__rci_init = _rci_init
__rci_tick = _rci_tick
__rci_get_demand = _rci_get_demand
__rci_calculate_lot_desirability = _rci_calculate_lot_desirability
__rci_process_lot_development = _rci_process_lot_development
__rci_cleanup = _rci_cleanup