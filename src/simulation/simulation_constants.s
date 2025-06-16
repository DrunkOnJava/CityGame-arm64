//
// SimCity ARM64 Assembly - Simulation Constants
// Agent 4: Simulation Engine
//
// Defines constants, macros, and structure sizes for the simulation engine
//

// World dimensions
.equ WORLD_WIDTH,           4096    // World width in tiles
.equ WORLD_HEIGHT,          4096    // World height in tiles
.equ CHUNK_SIZE,            16      // Tiles per chunk side
.equ CHUNK_COUNT_X,         256     // Chunks in X direction (4096/16)
.equ CHUNK_COUNT_Y,         256     // Chunks in Y direction (4096/16)
.equ TOTAL_CHUNKS,          65536   // Total chunks (256*256)

// Tile constants
.equ TILE_SIZE_BYTES,       64      // Size of each tile structure
.equ TILES_PER_CHUNK,       256     // Tiles per chunk (16*16)
.equ CHUNK_TILE_DATA_SIZE,  16384   // Tile data size per chunk (256*64)

// Timing constants
.equ DEFAULT_TICK_RATE,     30      // Default simulation rate (Hz)
.equ NANOSECONDS_PER_SECOND, 1000000000
.equ MAX_SIMULATION_STEPS,  5       // Max steps per frame (spiral protection)

// Performance constants
.equ CACHE_LINE_SIZE,       64      // ARM64 cache line size
.equ SIMD_VECTOR_SIZE,      16      // NEON vector size in bytes
.equ MAX_PARALLEL_JOBS,     16      // Maximum parallel jobs

// Tile types
.equ TILE_TYPE_EMPTY,       0
.equ TILE_TYPE_RESIDENTIAL, 1
.equ TILE_TYPE_COMMERCIAL,  2
.equ TILE_TYPE_INDUSTRIAL,  3
.equ TILE_TYPE_ROAD,        4
.equ TILE_TYPE_RAIL,        5
.equ TILE_TYPE_WATER,       6
.equ TILE_TYPE_POWER,       7
.equ TILE_TYPE_PARK,        8
.equ TILE_TYPE_SPECIAL,     9

// Zone types
.equ ZONE_NONE,             0
.equ ZONE_RESIDENTIAL,      1
.equ ZONE_COMMERCIAL,       2
.equ ZONE_INDUSTRIAL,       3

// Tile flags
.equ TILE_FLAG_DIRTY,       (1 << 0)    // Needs update
.equ TILE_FLAG_DEVELOPED,   (1 << 1)    // Has building
.equ TILE_FLAG_POWERED,     (1 << 2)    // Has power
.equ TILE_FLAG_WATERED,     (1 << 3)    // Has water
.equ TILE_FLAG_CONNECTED,   (1 << 4)    // Connected to road
.equ TILE_FLAG_POLLUTED,    (1 << 5)    // Pollution present
.equ TILE_FLAG_CRIME,       (1 << 6)    // Crime present
.equ TILE_FLAG_FIRE,        (1 << 7)    // Fire present

// Chunk flags
.equ CHUNK_FLAG_ACTIVE,     (1 << 0)    // Chunk is active
.equ CHUNK_FLAG_DIRTY,      (1 << 1)    // Chunk needs update
.equ CHUNK_FLAG_VISIBLE,    (1 << 2)    // Chunk is visible
.equ CHUNK_FLAG_LOADED,     (1 << 3)    // Chunk data loaded

// LOD levels
.equ LOD_NEAR,              0           // Every frame (visible area)
.equ LOD_MEDIUM,            1           // Every 4 frames
.equ LOD_FAR,               2           // Every 16 frames
.equ LOD_INACTIVE,          3           // No updates

// Update frequencies
.equ UPDATE_FREQ_NEAR,      1           // Every tick
.equ UPDATE_FREQ_MEDIUM,    4           // Every 4 ticks
.equ UPDATE_FREQ_FAR,       16          // Every 16 ticks

// Service coverage levels
.equ SERVICE_NONE,          0
.equ SERVICE_LOW,           64
.equ SERVICE_MEDIUM,        128
.equ SERVICE_HIGH,          192
.equ SERVICE_FULL,          255

// Economic constants
.equ BASE_LAND_VALUE,       1000
.equ MAX_LAND_VALUE,        10000
.equ BASE_TAX_RATE,         10          // 10% base tax rate

// Population constants
.equ MAX_TILE_POPULATION,   1000
.equ MAX_TILE_JOBS,         2000

// Pathfinding constants
.equ MAX_PATH_LENGTH,       512
.equ PATH_NODE_SIZE,        16

// Memory alignment macros
.macro ALIGN_TO_CACHE_LINE reg
    add     \reg, \reg, #(CACHE_LINE_SIZE - 1)
    and     \reg, \reg, #~(CACHE_LINE_SIZE - 1)
.endm

.macro ALIGN_TO_SIMD reg
    add     \reg, \reg, #(SIMD_VECTOR_SIZE - 1)
    and     \reg, \reg, #~(SIMD_VECTOR_SIZE - 1)
.endm

// Tile coordinate conversion macros
.macro TILE_TO_CHUNK_X tile_x, chunk_x
    lsr     \chunk_x, \tile_x, #4
.endm

.macro TILE_TO_CHUNK_Y tile_y, chunk_y
    lsr     \chunk_y, \tile_y, #4
.endm

.macro CHUNK_TO_TILE_X chunk_x, tile_x
    lsl     \tile_x, \chunk_x, #4
.endm

.macro CHUNK_TO_TILE_Y chunk_y, tile_y
    lsl     \tile_y, \chunk_y, #4
.endm

// Bounds checking macros
.macro CHECK_TILE_BOUNDS tile_x, tile_y, label_out_of_bounds
    cmp     \tile_x, #WORLD_WIDTH
    b.ge    \label_out_of_bounds
    cmp     \tile_y, #WORLD_HEIGHT
    b.ge    \label_out_of_bounds
.endm

.macro CHECK_CHUNK_BOUNDS chunk_x, chunk_y, label_out_of_bounds
    cmp     \chunk_x, #CHUNK_COUNT_X
    b.ge    \label_out_of_bounds
    cmp     \chunk_y, #CHUNK_COUNT_Y
    b.ge    \label_out_of_bounds
.endm

// Performance measurement macros
.macro START_TIMER timer_reg
    bl      get_current_time_ns
    mov     \timer_reg, x0
.endm

.macro END_TIMER timer_reg, result_reg
    bl      get_current_time_ns
    sub     \result_reg, x0, \timer_reg
.endm

// Structure size calculations
.equ SimulationState_size,  128     // Must match actual structure
.equ Tile_size,             64      // Must match actual structure  
.equ Chunk_size,            16512   // Must match actual structure
.equ ChunkHeader_size,      128     // Chunk metadata size

// Time system structure sizes
.equ GameTime_size,         192     // Time state structure
.equ Calendar_size,         1024    // Calendar data structure
.equ TimeControls_size,     64      // Time control structure

// Time system constants
.equ TIME_SCALE_PAUSE,      0       // Pause time scale index
.equ TIME_SCALE_NORMAL,     1       // Normal time scale index  
.equ TIME_SCALE_FAST,       2       // 2x time scale index
.equ TIME_SCALE_FASTER,     3       // 3x time scale index
.equ TIME_SCALE_ULTRA,      4       // 10x time scale index

// ECS Component Type IDs
.equ COMPONENT_POSITION,        0
.equ COMPONENT_BUILDING,        1
.equ COMPONENT_ECONOMIC,        2
.equ COMPONENT_POPULATION,      3
.equ COMPONENT_TRANSPORT,       4
.equ COMPONENT_UTILITY,         5
.equ COMPONENT_ZONE,            6
.equ COMPONENT_RENDER,          7
.equ COMPONENT_AGENT,           8
.equ COMPONENT_ENVIRONMENT,     9
.equ COMPONENT_TIME_BASED,      10
.equ COMPONENT_RESOURCE,        11
.equ COMPONENT_SERVICE,         12
.equ COMPONENT_INFRASTRUCTURE,  13
.equ COMPONENT_CLIMATE,         14
.equ COMPONENT_TRAFFIC,         15

// ECS System IDs
.equ SYSTEM_TIME_PROGRESSION,   0
.equ SYSTEM_ECONOMIC,           1
.equ SYSTEM_POPULATION,         2
.equ SYSTEM_TRANSPORT,          3
.equ SYSTEM_BUILDING,           4
.equ SYSTEM_UTILITY,            5
.equ SYSTEM_ZONE_MANAGEMENT,    6
.equ SYSTEM_AGENT_AI,           7
.equ SYSTEM_ENVIRONMENT,        8
.equ SYSTEM_RENDER,             9
.equ SYSTEM_PHYSICS,            10
.equ SYSTEM_CLIMATE,            11

// ECS Structure Sizes
.equ Entity_size,               64
.equ ComponentType_size,        64
.equ Archetype_size,            512
.equ SystemInfo_size,           64
.equ ECSWorld_size,             256

// Component Structure Sizes
.equ PositionComponent_size,        32
.equ BuildingComponent_size,        64
.equ EconomicComponent_size,        64
.equ PopulationComponent_size,      64
.equ TransportComponent_size,       96
.equ UtilityComponent_size,         128
.equ ZoneComponent_size,            64
.equ RenderComponent_size,          64
.equ AgentComponent_size,           96
.equ EnvironmentComponent_size,     64
.equ TimeBasedComponent_size,       64
.equ ResourceComponent_size,        64
.equ ServiceComponent_size,         64
.equ InfrastructureComponent_size,  64
.equ ClimateComponent_size,         64
.equ TrafficComponent_size,         64

// Economic System Structure Sizes
.equ EconomicMarket_size,           256
.equ SupplyDemandTracker_size,      64
.equ BusinessCycle_size,            128

// Population System Structure Sizes
.equ PopulationStatistics_size,     128
.equ MigrationPatterns_size,        512
.equ LifecycleEvents_size,          256
.equ SocialDynamics_size,           128

// Zone Management Structure Sizes
.equ ZoneTypeInfo_size,             64
.equ ZoneDevelopment_size,          256
.equ ZoningRegulations_size,        128
.equ ZoneGrowthPattern_size,        64

// Time Integration Structure Sizes
.equ TimeSystem_size,               256
.equ ScheduledEvent_size,           64
.equ TimeBasedUpdate_size,          32

// System Integration Structure Sizes
.equ SimulationIntegration_size,    256
.equ InterSystemMessage_size,       64

// Enhanced Building Types (extending original tile types)
.equ TILE_TYPE_SERVICE_BASE,        100     // Base for service buildings
.equ TILE_TYPE_HOSPITAL,            100
.equ TILE_TYPE_POLICE_STATION,      101
.equ TILE_TYPE_FIRE_STATION,        102
.equ TILE_TYPE_SCHOOL,              103
.equ TILE_TYPE_LIBRARY,             104
.equ TILE_TYPE_BANK,                105
.equ TILE_TYPE_MALL,                106
.equ TILE_TYPE_CINEMA,              107
.equ TILE_TYPE_COFFEE_SHOP,         108
.equ TILE_TYPE_BAKERY,              109
.equ TILE_TYPE_BEAUTY_SALON,        110
.equ TILE_TYPE_BARBERSHOP,          111
.equ TILE_TYPE_GYM,                 112
.equ TILE_TYPE_BUS_STATION,         113
.equ TILE_TYPE_TRAIN_STATION,       114
.equ TILE_TYPE_AIRPORT,             115
.equ TILE_TYPE_TRAFFIC_LIGHT,       116
.equ TILE_TYPE_STREET_LAMP,         117
.equ TILE_TYPE_HYDRANT,             118
.equ TILE_TYPE_ATM,                 119
.equ TILE_TYPE_MAIL_BOX,            120
.equ TILE_TYPE_FUEL_STATION,        121
.equ TILE_TYPE_CHARGING_STATION,    122
.equ TILE_TYPE_SOLAR_PANEL,         123
.equ TILE_TYPE_WIND_TURBINE,        124
.equ TILE_TYPE_PUBLIC_TOILET,       125
.equ TILE_TYPE_PARKING,             126
.equ TILE_TYPE_TRASH_CAN,           127

.equ ENHANCED_TILE_TYPE_COUNT,      28      // Number of enhanced building types

// Zone Type Constants
.equ ZONE_RESIDENTIAL_LOW,          0
.equ ZONE_RESIDENTIAL_MEDIUM,       1
.equ ZONE_RESIDENTIAL_HIGH,         2
.equ ZONE_COMMERCIAL_LOW,           3
.equ ZONE_COMMERCIAL_MEDIUM,        4
.equ ZONE_COMMERCIAL_HIGH,          5
.equ ZONE_INDUSTRIAL_LIGHT,         6
.equ ZONE_INDUSTRIAL_HEAVY,         7
.equ ZONE_MIXED_USE,                8
.equ ZONE_SPECIAL_DISTRICT,         9

// Development Status Constants
.equ DEVELOPMENT_EMPTY,             0
.equ DEVELOPMENT_PLANNED,           1
.equ DEVELOPMENT_UNDER_CONSTRUCTION, 2
.equ DEVELOPMENT_COMPLETED,         3
.equ DEVELOPMENT_RENOVATING,        4
.equ DEVELOPMENT_DECLINING,         5

// Event Type Constants
.equ EVENT_BUILDING_COMPLETE,       0
.equ EVENT_CITIZEN_AGE_UP,          1
.equ EVENT_ECONOMIC_CYCLE,          2
.equ EVENT_SEASONAL_CHANGE,         3
.equ EVENT_POLICY_EFFECT,           4
.equ EVENT_RANDOM_EVENT,            5
.equ EVENT_MAINTENANCE_DUE,         6
.equ EVENT_POPULATION_MILESTONE,    7

// Message Type Constants
.equ MSG_ECONOMIC_UPDATE,           0
.equ MSG_POPULATION_CHANGE,         1
.equ MSG_ZONE_DEVELOPMENT,          2
.equ MSG_BUILDING_COMPLETE,         3
.equ MSG_RESOURCE_SHORTAGE,         4
.equ MSG_POLICY_CHANGE,             5
.equ MSG_EMERGENCY_EVENT,           6
.equ MSG_SYSTEM_ERROR,              7