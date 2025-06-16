//
// SimCity ARM64 Assembly - Enhanced Building Types Integration
// Asset Integration Specialist - 3D Asset Building System
//
// Extended building type system integrating discovered 3D assets
// Supports service buildings, commercial specializations, infrastructure, and utilities
//

.include "simulation_constants.s"

// Extended Building Types (continuing from base types)
.equ TILE_TYPE_SERVICE_BASE,     10      // Base for service buildings
.equ TILE_TYPE_HOSPITAL,         10      // Hospital building
.equ TILE_TYPE_POLICE_STATION,   11      // Police station
.equ TILE_TYPE_FIRE_STATION,     12      // Fire station  
.equ TILE_TYPE_SCHOOL,           13      // School building
.equ TILE_TYPE_LIBRARY,          14      // Library
.equ TILE_TYPE_BANK,             15      // Bank

.equ TILE_TYPE_COMMERCIAL_BASE,  20      // Base for specialized commercial
.equ TILE_TYPE_MALL,             20      // Shopping mall
.equ TILE_TYPE_CINEMA,           21      // Cinema
.equ TILE_TYPE_COFFEE_SHOP,      22      // Coffee shop
.equ TILE_TYPE_BAKERY,           23      // Bakery
.equ TILE_TYPE_BEAUTY_SALON,     24      // Beauty salon
.equ TILE_TYPE_BARBERSHOP,       25      // Barbershop
.equ TILE_TYPE_GYM,              26      // Gym building

.equ TILE_TYPE_TRANSPORT_BASE,   30      // Base for transportation
.equ TILE_TYPE_BUS_STATION,      30      // Bus station
.equ TILE_TYPE_TRAIN_STATION,    31      // Train station
.equ TILE_TYPE_AIRPORT,          32      // Airport
.equ TILE_TYPE_TAXI_STOP,        33      // Taxi stop

.equ TILE_TYPE_INFRASTRUCTURE_BASE, 40   // Base for infrastructure
.equ TILE_TYPE_TRAFFIC_LIGHT,    40      // Traffic light
.equ TILE_TYPE_STREET_LAMP,      41      // Street lamp
.equ TILE_TYPE_HYDRANT,          42      // Fire hydrant
.equ TILE_TYPE_ATM,              43      // ATM machine
.equ TILE_TYPE_MAIL_BOX,         44      // Mail box
.equ TILE_TYPE_FUEL_STATION,     45      // Fuel station
.equ TILE_TYPE_CHARGING_STATION, 46      // Electric vehicle charging station

.equ TILE_TYPE_UTILITIES_BASE,   50      // Base for utilities
.equ TILE_TYPE_SOLAR_PANEL,      50      // Solar panel
.equ TILE_TYPE_WIND_TURBINE,     51      // Wind turbine
.equ TILE_TYPE_POWER_PLANT,      52      // Power plant
.equ TILE_TYPE_WATER_TOWER,      53      // Water tower
.equ TILE_TYPE_SEWAGE_PLANT,     54      // Sewage treatment plant

.equ TILE_TYPE_PUBLIC_FACILITY_BASE, 60  // Base for public facilities
.equ TILE_TYPE_PUBLIC_TOILET,    60      // Public toilet
.equ TILE_TYPE_PARKING,          61      // Parking area
.equ TILE_TYPE_SIGN,             62      // Information sign
.equ TILE_TYPE_TRASH_CAN,        63      // Trash can
.equ TILE_TYPE_WATER_FOUNTAIN,   64      // Water fountain
.equ TILE_TYPE_BENCH,            65      // Park bench

.equ ENHANCED_TILE_TYPE_COUNT,   66      // Total enhanced tile types

// Building Categories for UI and Logic
.equ BUILDING_CATEGORY_BASIC,     0      // Basic RCI
.equ BUILDING_CATEGORY_SERVICE,   1      // Police, Fire, Hospital, etc.
.equ BUILDING_CATEGORY_COMMERCIAL, 2     // Specialized commercial
.equ BUILDING_CATEGORY_TRANSPORT, 3      // Transportation buildings
.equ BUILDING_CATEGORY_INFRASTRUCTURE, 4 // Infrastructure elements
.equ BUILDING_CATEGORY_UTILITIES, 5      // Power, water, etc.
.equ BUILDING_CATEGORY_PUBLIC,    6      // Public facilities
.equ BUILDING_CATEGORY_COUNT,     7

// Service coverage ranges (in tiles)
.equ SERVICE_RANGE_HOSPITAL,     8       // Hospital coverage range
.equ SERVICE_RANGE_POLICE,       6       // Police station range
.equ SERVICE_RANGE_FIRE,         5       // Fire station range
.equ SERVICE_RANGE_SCHOOL,       4       // School coverage range
.equ SERVICE_RANGE_LIBRARY,      3       // Library range
.equ SERVICE_RANGE_BANK,         2       // Bank range

// Building placement requirements
.equ REQUIREMENT_NONE,           0       // No special requirements
.equ REQUIREMENT_ROAD_ACCESS,    (1 << 0) // Must be adjacent to road
.equ REQUIREMENT_POWER,          (1 << 1) // Must have power connection
.equ REQUIREMENT_WATER,          (1 << 2) // Must have water connection
.equ REQUIREMENT_FLAT_TERRAIN,   (1 << 3) // Must be on flat terrain
.equ REQUIREMENT_COASTAL,        (1 << 4) // Must be near water
.equ REQUIREMENT_INDUSTRIAL,     (1 << 5) // Must be in industrial zone

// Economic impact modifiers
.equ HAPPINESS_BONUS_HOSPITAL,   15      // Happiness boost from hospital
.equ HAPPINESS_BONUS_SCHOOL,     10      // Happiness boost from school
.equ HAPPINESS_BONUS_LIBRARY,    8       // Happiness boost from library
.equ HAPPINESS_BONUS_PARK,       5       // Happiness boost from park facilities

.equ SAFETY_BONUS_POLICE,        20      // Safety boost from police station
.equ SAFETY_BONUS_FIRE,          15      // Safety boost from fire station
.equ SAFETY_BONUS_HYDRANT,       5       // Safety boost from hydrant

.equ LAND_VALUE_BONUS_HOSPITAL,  300     // Land value boost near hospital
.equ LAND_VALUE_BONUS_SCHOOL,    200     // Land value boost near school
.equ LAND_VALUE_BONUS_LIBRARY,   150     // Land value boost near library
.equ LAND_VALUE_BONUS_PARK_FACILITY, 100 // Land value boost from park facilities

.equ POLLUTION_REDUCTION_TREE,   2       // Pollution reduction per tree
.equ POLLUTION_REDUCTION_PARK,   5       // Pollution reduction per park facility

// Specialized building sizes (in tiles)
.equ BUILDING_SIZE_SMALL,        1       // 1x1 tile
.equ BUILDING_SIZE_MEDIUM,       2       // 2x2 tiles
.equ BUILDING_SIZE_LARGE,        3       // 3x3 tiles
.equ BUILDING_SIZE_HUGE,         4       // 4x4 tiles

// Asset mapping structure for sprite atlas integration
.data
.align 8

// Enhanced building information table
enhanced_building_info:
    // TILE_TYPE_HOSPITAL (10)
    .word   BUILDING_CATEGORY_SERVICE
    .word   BUILDING_SIZE_LARGE
    .word   REQUIREMENT_ROAD_ACCESS | REQUIREMENT_POWER | REQUIREMENT_WATER
    .word   SERVICE_RANGE_HOSPITAL
    .word   150000                  // Construction cost
    .word   2000                    // Monthly maintenance
    .word   HAPPINESS_BONUS_HOSPITAL
    .word   LAND_VALUE_BONUS_HOSPITAL
    
    // TILE_TYPE_POLICE_STATION (11)
    .word   BUILDING_CATEGORY_SERVICE
    .word   BUILDING_SIZE_MEDIUM
    .word   REQUIREMENT_ROAD_ACCESS | REQUIREMENT_POWER
    .word   SERVICE_RANGE_POLICE
    .word   80000                   // Construction cost
    .word   1200                    // Monthly maintenance
    .word   5                       // Happiness bonus
    .word   SAFETY_BONUS_POLICE
    
    // TILE_TYPE_FIRE_STATION (12)
    .word   BUILDING_CATEGORY_SERVICE
    .word   BUILDING_SIZE_MEDIUM
    .word   REQUIREMENT_ROAD_ACCESS | REQUIREMENT_POWER | REQUIREMENT_WATER
    .word   SERVICE_RANGE_FIRE
    .word   75000                   // Construction cost
    .word   1000                    // Monthly maintenance
    .word   5                       // Happiness bonus
    .word   SAFETY_BONUS_FIRE
    
    // TILE_TYPE_SCHOOL (13)
    .word   BUILDING_CATEGORY_SERVICE
    .word   BUILDING_SIZE_LARGE
    .word   REQUIREMENT_ROAD_ACCESS | REQUIREMENT_POWER
    .word   SERVICE_RANGE_SCHOOL
    .word   120000                  // Construction cost
    .word   1500                    // Monthly maintenance
    .word   HAPPINESS_BONUS_SCHOOL
    .word   LAND_VALUE_BONUS_SCHOOL
    
    // TILE_TYPE_LIBRARY (14)
    .word   BUILDING_CATEGORY_SERVICE
    .word   BUILDING_SIZE_MEDIUM
    .word   REQUIREMENT_ROAD_ACCESS | REQUIREMENT_POWER
    .word   SERVICE_RANGE_LIBRARY
    .word   60000                   // Construction cost
    .word   800                     // Monthly maintenance
    .word   HAPPINESS_BONUS_LIBRARY
    .word   LAND_VALUE_BONUS_LIBRARY
    
    // TILE_TYPE_BANK (15)
    .word   BUILDING_CATEGORY_SERVICE
    .word   BUILDING_SIZE_MEDIUM
    .word   REQUIREMENT_ROAD_ACCESS | REQUIREMENT_POWER
    .word   SERVICE_RANGE_BANK
    .word   100000                  // Construction cost
    .word   1200                    // Monthly maintenance
    .word   0                       // Happiness bonus
    .word   100                     // Land value bonus
    
    // TILE_TYPE_MALL (20)
    .word   BUILDING_CATEGORY_COMMERCIAL
    .word   BUILDING_SIZE_HUGE
    .word   REQUIREMENT_ROAD_ACCESS | REQUIREMENT_POWER
    .word   0                       // No service range
    .word   300000                  // Construction cost
    .word   3000                    // Monthly maintenance
    .word   8                       // Happiness bonus
    .word   200                     // Land value bonus
    
    // TILE_TYPE_CINEMA (21)
    .word   BUILDING_CATEGORY_COMMERCIAL
    .word   BUILDING_SIZE_LARGE
    .word   REQUIREMENT_ROAD_ACCESS | REQUIREMENT_POWER
    .word   0                       // No service range
    .word   180000                  // Construction cost
    .word   2000                    // Monthly maintenance
    .word   12                      // Happiness bonus
    .word   150                     // Land value bonus
    
    // TILE_TYPE_COFFEE_SHOP (22)
    .word   BUILDING_CATEGORY_COMMERCIAL
    .word   BUILDING_SIZE_SMALL
    .word   REQUIREMENT_ROAD_ACCESS | REQUIREMENT_POWER
    .word   0                       // No service range
    .word   25000                   // Construction cost
    .word   400                     // Monthly maintenance
    .word   3                       // Happiness bonus
    .word   50                      // Land value bonus
    
    // Continue for all enhanced building types...
    // [Note: For brevity, showing representative entries. Full table would include all 66 types]

.text

//
// Get enhanced building information
// Parameters: w0 = building_type
// Returns: x0 = pointer to building info structure (or null if invalid)
//
.global get_enhanced_building_info
get_enhanced_building_info:
    cmp     w0, #ENHANCED_TILE_TYPE_COUNT
    b.ge    get_enhanced_building_info_invalid
    
    cmp     w0, #TILE_TYPE_SERVICE_BASE
    b.lt    get_enhanced_building_info_invalid
    
    // Calculate offset into info table
    sub     w0, w0, #TILE_TYPE_SERVICE_BASE
    adrp    x1, enhanced_building_info
    add     x1, x1, :lo12:enhanced_building_info
    mov     x2, #32                     // Size of each info entry (8 words)
    mul     x0, x0, x2
    add     x0, x1, x0
    ret
    
get_enhanced_building_info_invalid:
    mov     x0, #0
    ret

//
// Check if building can be placed at location
// Parameters: w0 = building_type, w1 = tile_x, w2 = tile_y
// Returns: w0 = 1 if can place, 0 if cannot
//
.global can_place_enhanced_building
can_place_enhanced_building:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     w19, w0                     // Save building type
    mov     w20, w1                     // Save coordinates
    mov     w21, w2
    
    // Get building information
    bl      get_enhanced_building_info
    cbz     x0, can_place_enhanced_building_no
    
    // Check placement requirements
    ldr     w1, [x0, #8]                // Load requirements
    
    // Check road access requirement
    tst     w1, #REQUIREMENT_ROAD_ACCESS
    b.eq    can_place_enhanced_building_check_power
    
    // TODO: Check if adjacent to road
    // [Implementation would check surrounding tiles for roads]
    
can_place_enhanced_building_check_power:
    tst     w1, #REQUIREMENT_POWER
    b.eq    can_place_enhanced_building_check_water
    
    // TODO: Check power connection
    // [Implementation would check power grid connectivity]
    
can_place_enhanced_building_check_water:
    tst     w1, #REQUIREMENT_WATER
    b.eq    can_place_enhanced_building_yes
    
    // TODO: Check water connection
    // [Implementation would check water system connectivity]
    
can_place_enhanced_building_yes:
    mov     w0, #1
    b       can_place_enhanced_building_exit
    
can_place_enhanced_building_no:
    mov     w0, #0
    
can_place_enhanced_building_exit:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// Calculate service coverage for a building
// Parameters: w0 = building_type, w1 = center_x, w2 = center_y, x3 = coverage_map
// Returns: w0 = number of tiles covered
//
.global calculate_service_coverage
calculate_service_coverage:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     w19, w0                     // Save building type
    mov     w20, w1                     // Save center coordinates
    mov     w21, w2
    mov     x22, x3                     // Save coverage map pointer
    
    // Get building information
    bl      get_enhanced_building_info
    cbz     x0, calculate_service_coverage_exit
    
    ldr     w1, [x0, #12]               // Load service range
    cbz     w1, calculate_service_coverage_exit
    
    // Calculate coverage area
    mov     w0, #0                      // Tile counter
    
    // For each tile in range...
    sub     w2, w20, w1                 // Start X
    sub     w3, w21, w1                 // Start Y
    add     w4, w20, w1                 // End X
    add     w5, w21, w1                 // End Y
    
calculate_service_coverage_loop_y:
    cmp     w3, w5
    b.gt    calculate_service_coverage_exit
    
    mov     w6, w2                      // Reset X
    
calculate_service_coverage_loop_x:
    cmp     w6, w4
    b.gt    calculate_service_coverage_next_y
    
    // Calculate distance from center
    sub     w7, w6, w20                 // dx
    sub     w8, w3, w21                 // dy
    mul     w7, w7, w7                  // dx²
    mul     w8, w8, w8                  // dy²
    add     w7, w7, w8                  // dx² + dy²
    
    // Check if within circular range
    mul     w8, w1, w1                  // range²
    cmp     w7, w8
    b.gt    calculate_service_coverage_next_x
    
    // Mark tile as covered (simplified - would update actual coverage map)
    add     w0, w0, #1
    
calculate_service_coverage_next_x:
    add     w6, w6, #1
    b       calculate_service_coverage_loop_x
    
calculate_service_coverage_next_y:
    add     w3, w3, #1
    b       calculate_service_coverage_loop_y
    
calculate_service_coverage_exit:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// Asset filename mapping for sprite atlas generation
.data
.align 8

building_asset_filenames:
    .ascii  "HOSPITAL BUILDING.png\0"
    .align  8
    .ascii  "POLICE STATION BUILDING.png\0"
    .align  8
    .ascii  "FIRE STATION BUILDING.png\0"
    .align  8
    .ascii  "School Building.png\0"
    .align  8
    .ascii  "LIBRARY BUILDING.png\0"
    .align  8
    .ascii  "BANK BUILDING.png\0"
    .align  8
    .ascii  "MALL BUILDING.png\0"
    .align  8
    .ascii  "CINEMA BUILDING.png\0"
    .align  8
    .ascii  "COFFEE SHOP BUILDING.png\0"
    .align  8
    .ascii  "BAKERY BUILDING.png\0"
    .align  8
    .ascii  "BEAUTY SALON BUILDING.png\0"
    .align  8
    .ascii  "BARBERSHOP BUILDING.png\0"
    .align  8
    .ascii  "GYM BUILDING.png\0"
    .align  8
    .ascii  "BUS STATION BUILDING.png\0"
    .align  8
    .ascii  "TRAIN STATION BUILDING.png\0"
    .align  8
    .ascii  "AIRPORT BUILDING.png\0"
    .align  8
    .ascii  "Traffic Light.png\0"
    .align  8
    .ascii  "Lamp.png\0"
    .align  8
    .ascii  "Hydrant.png\0"
    .align  8
    .ascii  "Atm.png\0"
    .align  8
    .ascii  "Mail Box .png\0"
    .align  8
    .ascii  "Fuel Station .png\0"
    .align  8
    .ascii  "charging station.png\0"
    .align  8
    .ascii  "solar panel.png\0"
    .align  8
    .ascii  "Windmill.png\0"
    .align  8
    .ascii  "Public Toilet .png\0"
    .align  8
    .ascii  "parking.png\0"
    .align  8
    .ascii  "Sign.png\0"
    .align  8
    .ascii  "Trash Can.png\0"
    .align  8
    .ascii  "water fountain.png\0"
    .align  8
    .ascii  "Chair.png\0"
    .align  8

.global get_building_asset_filename
get_building_asset_filename:
    // Implementation to return asset filename for building type
    // This would be used by the atlas generation system
    ret