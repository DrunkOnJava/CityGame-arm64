#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <simd/simd.h>
#import <stdlib.h>

// Enhanced asset types with more detail
typedef enum {
    ASSET_TYPE_ROAD_STRAIGHT = 0,
    ASSET_TYPE_ROAD_INTERSECTION,
    ASSET_TYPE_ROAD_CORNER,
    ASSET_TYPE_BUILDING_R1,  // Small residential
    ASSET_TYPE_BUILDING_R2,  // Medium residential  
    ASSET_TYPE_BUILDING_R3,  // Large residential
    ASSET_TYPE_BUILDING_C1,  // Small commercial
    ASSET_TYPE_BUILDING_C2,  // Medium commercial
    ASSET_TYPE_BUILDING_C3,  // Large commercial
    ASSET_TYPE_BUILDING_I1,  // Small industrial
    ASSET_TYPE_BUILDING_I2,  // Medium industrial
    ASSET_TYPE_BUILDING_I3,  // Large industrial
    ASSET_TYPE_VEHICLE_CAR,
    ASSET_TYPE_VEHICLE_TRUCK,
    ASSET_TYPE_VEHICLE_BUS,
    ASSET_TYPE_TREE_OAK,
    ASSET_TYPE_TREE_PINE,
    ASSET_TYPE_PARK,
    ASSET_TYPE_PERSON
} AssetType;

// Enhanced asset structure with rendering data
typedef struct {
    float x, y, z;           // World position
    float scale;             // Scale factor
    float rotation;          // Y-axis rotation
    AssetType type;          // Asset type
    int assetId;            // Specific asset variant
    float animTime;         // Animation time
    float height;           // Building height
    int zoneType;          // 0=res, 1=com, 2=ind
    float growthLevel;     // 0.0 to 1.0
    int sortKey;           // For depth sorting
} CityAsset;

// Road network grid
#define CITY_WIDTH 100
#define CITY_HEIGHT 100
#define BLOCK_SIZE 5
#define MAX_ASSETS 100000

static CityAsset city_assets[MAX_ASSETS];
static int asset_count = 0;
static uint8_t road_grid[CITY_WIDTH][CITY_HEIGHT];

// Performance stats
static int frame_count = 0;
static int vehicles_active = 0;
static int people_active = 0;
static float time_of_day = 0.5f; // 0=night, 0.5=noon, 1=night

// Camera controls
static float camera_x = 0.0f;
static float camera_y = 0.0f;
static float camera_zoom = 1.0f;
static float camera_rotation = 0.0f;

// Enhanced asset catalog with realistic dimensions
typedef struct {
    const char* name;
    float width, height, depth;
    float r, g, b;
    float emission;  // Light emission for windows
} AssetCatalogEntry;

static AssetCatalogEntry asset_catalog[] = {
    // Roads (1x1 tiles to match grid placement)
    {"Road_Straight", 1.0f, 0.02f, 1.0f, 0.3f, 0.3f, 0.3f, 0.0f},
    {"Road_Intersection", 1.0f, 0.02f, 1.0f, 0.35f, 0.35f, 0.35f, 0.0f},
    {"Road_Corner", 1.0f, 0.02f, 1.0f, 0.3f, 0.3f, 0.3f, 0.0f},
    
    // Residential buildings (green tinted)
    {"R1_House", 1.5f, 2.0f, 1.5f, 0.4f, 0.7f, 0.4f, 0.2f},
    {"R2_Duplex", 2.0f, 3.0f, 2.0f, 0.3f, 0.6f, 0.3f, 0.3f},
    {"R3_Apartment", 3.0f, 8.0f, 3.0f, 0.3f, 0.5f, 0.3f, 0.4f},
    
    // Commercial buildings (blue tinted)
    {"C1_Shop", 2.0f, 3.0f, 2.0f, 0.4f, 0.5f, 0.7f, 0.5f},
    {"C2_Office", 3.0f, 12.0f, 3.0f, 0.3f, 0.4f, 0.6f, 0.6f},
    {"C3_Tower", 4.0f, 20.0f, 4.0f, 0.2f, 0.3f, 0.5f, 0.7f},
    
    // Industrial buildings (orange/brown tinted)
    {"I1_Workshop", 3.0f, 4.0f, 3.0f, 0.6f, 0.4f, 0.3f, 0.1f},
    {"I2_Factory", 4.0f, 6.0f, 5.0f, 0.5f, 0.3f, 0.2f, 0.2f},
    {"I3_Plant", 6.0f, 8.0f, 8.0f, 0.4f, 0.3f, 0.2f, 0.3f},
    
    // Vehicles
    {"V_Car", 0.15f, 0.1f, 0.3f, 0.6f, 0.6f, 0.7f, 0.0f},
    {"V_Truck", 0.2f, 0.15f, 0.4f, 0.5f, 0.5f, 0.6f, 0.0f},
    {"V_Bus", 0.2f, 0.2f, 0.6f, 0.7f, 0.7f, 0.3f, 0.0f},
    
    // Nature
    {"T_Oak", 0.8f, 1.5f, 0.8f, 0.2f, 0.5f, 0.2f, 0.0f},
    {"T_Pine", 0.6f, 2.0f, 0.6f, 0.1f, 0.4f, 0.1f, 0.0f},
    {"Park", 2.0f, 0.1f, 2.0f, 0.3f, 0.6f, 0.3f, 0.0f},
    
    // People
    {"Pedestrian", 0.05f, 0.15f, 0.05f, 0.8f, 0.7f, 0.6f, 0.0f}
};

// Function declarations
extern int bootstrap_init(void);
extern int metal_init(void);
extern int simulation_core_init(void);
extern int astar_core_init(void);
extern int core_audio_init(void);
extern int input_handler_init(void);
extern void io_init(void);
extern void io_shutdown(void);
extern void simulation_update(void);
extern void ai_update(void);
extern void audio_update(void);
extern void ui_update(void);
extern void platform_shutdown(void);
extern void graphics_shutdown(void);
extern void simulation_shutdown(void);
extern void ai_shutdown(void);
extern void audio_shutdown(void);
extern void ui_shutdown(void);

// Init wrappers
static void platform_init(void) { bootstrap_init(); }
static void graphics_init(void) { metal_init(); }
static void simulation_init(void) { simulation_core_init(); }
static void ai_init(void) { astar_core_init(); }
static void audio_init(void) { core_audio_init(); }
static void ui_init(void) { input_handler_init(); }

// Generate road network
static void generate_road_network(void) {
    memset(road_grid, 0, sizeof(road_grid));
    
    // Create main roads every BLOCK_SIZE units
    for (int x = 0; x < CITY_WIDTH; x++) {
        for (int y = 0; y < CITY_HEIGHT; y++) {
            if (x % BLOCK_SIZE == 0 || y % BLOCK_SIZE == 0) {
                road_grid[x][y] = 1;
            }
        }
    }
    
    // Add some diagonal roads for variety
    for (int i = 0; i < CITY_WIDTH && i < CITY_HEIGHT; i += BLOCK_SIZE * 2) {
        road_grid[i][i] = 1;
        if (i + 1 < CITY_WIDTH && i + 1 < CITY_HEIGHT) {
            road_grid[i + 1][i + 1] = 1;
        }
    }
}

// Initialize enhanced city with proper urban planning
static void init_enhanced_city(void) {
    asset_count = 0;
    
    // First generate road network
    generate_road_network();
    
    // Place roads as assets
    for (int x = 0; x < CITY_WIDTH; x++) {
        for (int y = 0; y < CITY_HEIGHT; y++) {
            if (road_grid[x][y] && asset_count < MAX_ASSETS) {
                CityAsset* road = &city_assets[asset_count++];
                road->x = x;
                road->y = 0.0f;
                road->z = y;
                road->scale = 1.0f;
                road->rotation = 0.0f;
                road->type = ASSET_TYPE_ROAD_STRAIGHT;
                road->assetId = 0;
                road->height = 0.05f;
                road->zoneType = -1;
                road->growthLevel = 1.0f;
                road->animTime = 0.0f;
                
                // Check for intersections
                int neighbors = 0;
                if (x > 0 && road_grid[x-1][y]) neighbors++;
                if (x < CITY_WIDTH-1 && road_grid[x+1][y]) neighbors++;
                if (y > 0 && road_grid[x][y-1]) neighbors++;
                if (y < CITY_HEIGHT-1 && road_grid[x][y+1]) neighbors++;
                
                if (neighbors > 2) {
                    road->type = ASSET_TYPE_ROAD_INTERSECTION;
                    road->assetId = 1;
                } else if (neighbors == 2) {
                    // Check for corner
                    if ((x > 0 && road_grid[x-1][y] && y > 0 && road_grid[x][y-1]) ||
                        (x > 0 && road_grid[x-1][y] && y < CITY_HEIGHT-1 && road_grid[x][y+1]) ||
                        (x < CITY_WIDTH-1 && road_grid[x+1][y] && y > 0 && road_grid[x][y-1]) ||
                        (x < CITY_WIDTH-1 && road_grid[x+1][y] && y < CITY_HEIGHT-1 && road_grid[x][y+1])) {
                        road->type = ASSET_TYPE_ROAD_CORNER;
                        road->assetId = 2;
                    }
                }
            }
        }
    }
    
    // Place buildings in blocks between roads
    for (int bx = 0; bx < CITY_WIDTH / BLOCK_SIZE; bx++) {
        for (int by = 0; by < CITY_HEIGHT / BLOCK_SIZE; by++) {
            if (asset_count >= MAX_ASSETS - 100) break;
            
            int block_x = bx * BLOCK_SIZE;
            int block_y = by * BLOCK_SIZE;
            
            // Determine zone type based on location
            int zone_type;
            AssetType building_types[3];
            
            float dist_from_center = sqrtf(powf(block_x - CITY_WIDTH/2, 2) + powf(block_y - CITY_HEIGHT/2, 2));
            
            if (dist_from_center < CITY_WIDTH * 0.2f) {
                // City center - commercial
                zone_type = 1;
                building_types[0] = ASSET_TYPE_BUILDING_C1;
                building_types[1] = ASSET_TYPE_BUILDING_C2;
                building_types[2] = ASSET_TYPE_BUILDING_C3;
            } else if (block_x > CITY_WIDTH * 0.7f) {
                // Industrial zone
                zone_type = 2;
                building_types[0] = ASSET_TYPE_BUILDING_I1;
                building_types[1] = ASSET_TYPE_BUILDING_I2;
                building_types[2] = ASSET_TYPE_BUILDING_I3;
            } else {
                // Residential zone
                zone_type = 0;
                building_types[0] = ASSET_TYPE_BUILDING_R1;
                building_types[1] = ASSET_TYPE_BUILDING_R2;
                building_types[2] = ASSET_TYPE_BUILDING_R3;
            }
            
            // Fill block with buildings
            for (int dx = 1; dx < BLOCK_SIZE - 1; dx++) {
                for (int dy = 1; dy < BLOCK_SIZE - 1; dy++) {
                    int x = block_x + dx;
                    int y = block_y + dy;
                    
                    if (x >= CITY_WIDTH || y >= CITY_HEIGHT) continue;
                    if (road_grid[x][y]) continue;
                    
                    // Random chance to place building
                    if (rand() % 100 < 70) {
                        CityAsset* building = &city_assets[asset_count++];
                        
                        // Choose building size based on location in block
                        int size_category = (dx == 2 && dy == 2) ? 2 : (rand() % 3);
                        
                        building->x = x + (rand() % 50 - 25) * 0.01f;
                        building->y = 0.0f;
                        building->z = y + (rand() % 50 - 25) * 0.01f;
                        building->type = building_types[size_category];
                        building->assetId = building->type - ASSET_TYPE_BUILDING_R1 + 3;
                        building->scale = 0.8f + (rand() % 40) * 0.01f;
                        building->rotation = (rand() % 4) * 1.57f;
                        building->zoneType = zone_type;
                        building->growthLevel = 0.5f + (rand() % 50) * 0.01f;
                        
                        // Set height based on type and growth
                        AssetCatalogEntry* catalog = &asset_catalog[building->assetId];
                        building->height = catalog->height * building->scale * building->growthLevel;
                        building->animTime = 0.0f;
                        
                        // Add trees around residential buildings
                        if (zone_type == 0 && rand() % 100 < 30 && asset_count < MAX_ASSETS - 5) {
                            CityAsset* tree = &city_assets[asset_count++];
                            tree->x = x + (rand() % 100 - 50) * 0.02f;
                            tree->y = 0.0f;
                            tree->z = y + (rand() % 100 - 50) * 0.02f;
                            tree->type = ASSET_TYPE_TREE_OAK + (rand() % 2);
                            tree->assetId = tree->type - ASSET_TYPE_ROAD_STRAIGHT;
                            tree->scale = 0.5f + (rand() % 100) * 0.01f;
                            tree->rotation = (rand() % 360) * 0.0174f;
                            tree->height = asset_catalog[tree->assetId].height * tree->scale;
                            tree->zoneType = -1;
                            tree->growthLevel = 1.0f;
                            tree->animTime = rand() % 1000 * 0.001f;
                        }
                    }
                }
            }
            
            // Add park in some blocks
            if (zone_type == 0 && rand() % 100 < 20 && asset_count < MAX_ASSETS) {
                CityAsset* park = &city_assets[asset_count++];
                park->x = block_x + BLOCK_SIZE/2;
                park->y = 0.0f;
                park->z = block_y + BLOCK_SIZE/2;
                park->type = ASSET_TYPE_PARK;
                park->assetId = 17;
                park->scale = 2.0f;
                park->rotation = 0.0f;
                park->height = 0.1f;
                park->zoneType = -1;
                park->growthLevel = 1.0f;
                park->animTime = 0.0f;
            }
        }
    }
    
    // Add vehicles on roads
    for (int i = 0; i < 1000 && asset_count < MAX_ASSETS; i++) {
        int rx = rand() % CITY_WIDTH;
        int ry = rand() % CITY_HEIGHT;
        
        if (road_grid[rx][ry]) {
            CityAsset* vehicle = &city_assets[asset_count++];
            vehicle->x = rx + (rand() % 100 - 50) * 0.01f;
            vehicle->y = 0.1f;
            vehicle->z = ry + (rand() % 100 - 50) * 0.01f;
            vehicle->type = ASSET_TYPE_VEHICLE_CAR + (rand() % 3);
            vehicle->assetId = vehicle->type - ASSET_TYPE_ROAD_STRAIGHT;
            vehicle->scale = 1.0f;
            vehicle->rotation = (rand() % 4) * 1.57f;
            vehicle->height = asset_catalog[vehicle->assetId].height;
            vehicle->zoneType = -1;
            vehicle->growthLevel = 1.0f;
            vehicle->animTime = rand() % 1000 * 0.001f;
            vehicles_active++;
        }
    }
    
    // Add pedestrians
    for (int i = 0; i < 2000 && asset_count < MAX_ASSETS; i++) {
        CityAsset* person = &city_assets[asset_count++];
        person->x = rand() % CITY_WIDTH;
        person->y = 0.0f;
        person->z = rand() % CITY_HEIGHT;
        person->type = ASSET_TYPE_PERSON;
        person->assetId = 18;
        person->scale = 1.0f;
        person->rotation = (rand() % 360) * 0.0174f;
        person->height = asset_catalog[person->assetId].height;
        person->zoneType = -1;
        person->growthLevel = 1.0f;
        person->animTime = rand() % 1000 * 0.001f;
        people_active++;
    }
    
    printf("🏙️  Generated enhanced city with %d assets\n", asset_count);
    printf("🛣️  Road network: %d segments\n", asset_count - vehicles_active - people_active);
    printf("🏢  Buildings and structures\n");
    printf("🚗  Vehicles: %d\n", vehicles_active);
    printf("👥  Pedestrians: %d\n", people_active);
}

// Depth sorting comparison
static int depth_sort_compare(const void* a, const void* b) {
    const CityAsset* asset_a = (const CityAsset*)a;
    const CityAsset* asset_b = (const CityAsset*)b;
    
    // Calculate isometric depth - far objects (higher x+z) should be drawn first
    // In isometric view: back-to-front = high depth to low depth
    float depth_a = (asset_a->x + asset_a->z) + asset_a->y * 100.0f;
    float depth_b = (asset_b->x + asset_b->z) + asset_b->y * 100.0f;
    
    // Sort in reverse order - higher depth values first (back to front)
    if (depth_a > depth_b) return -1;
    if (depth_a < depth_b) return 1;
    return 0;
}

// Update dynamic assets
static void update_city_simulation(void) {
    float dt = 1.0f / 60.0f;
    time_of_day += dt * 0.01f; // Full cycle every 100 seconds
    if (time_of_day > 1.0f) time_of_day -= 1.0f;
    
    for (int i = 0; i < asset_count; i++) {
        CityAsset* asset = &city_assets[i];
        
        // Update vehicles
        if (asset->type >= ASSET_TYPE_VEHICLE_CAR && asset->type <= ASSET_TYPE_VEHICLE_BUS) {
            asset->animTime += dt;
            
            // Move along roads
            float speed = (asset->type == ASSET_TYPE_VEHICLE_CAR) ? 3.0f : 2.0f;
            float new_x = asset->x + cosf(asset->rotation) * speed * dt;
            float new_z = asset->z + sinf(asset->rotation) * speed * dt;
            
            // Check if still on road
            int grid_x = (int)new_x;
            int grid_z = (int)new_z;
            
            if (grid_x >= 0 && grid_x < CITY_WIDTH && grid_z >= 0 && grid_z < CITY_HEIGHT) {
                if (road_grid[grid_x][grid_z]) {
                    asset->x = new_x;
                    asset->z = new_z;
                } else {
                    // Turn at intersection
                    asset->rotation += 1.57f;
                }
            } else {
                // Wrap around
                if (new_x < 0) asset->x = CITY_WIDTH - 1;
                else if (new_x >= CITY_WIDTH) asset->x = 0;
                if (new_z < 0) asset->z = CITY_HEIGHT - 1;
                else if (new_z >= CITY_HEIGHT) asset->z = 0;
            }
        }
        
        // Update pedestrians
        else if (asset->type == ASSET_TYPE_PERSON) {
            asset->animTime += dt;
            
            // Simple wandering
            if ((int)(asset->animTime * 10) % 50 == 0) {
                asset->rotation += (rand() % 180 - 90) * 0.0174f;
            }
            
            float speed = 0.5f;
            asset->x += cosf(asset->rotation) * speed * dt;
            asset->z += sinf(asset->rotation) * speed * dt;
            
            // Keep in bounds
            if (asset->x < 0 || asset->x >= CITY_WIDTH) {
                asset->x = fmaxf(0, fminf(CITY_WIDTH - 1, asset->x));
                asset->rotation += 3.14f;
            }
            if (asset->z < 0 || asset->z >= CITY_HEIGHT) {
                asset->z = fmaxf(0, fminf(CITY_HEIGHT - 1, asset->z));
                asset->rotation += 3.14f;
            }
        }
        
        // Building growth simulation
        else if (asset->type >= ASSET_TYPE_BUILDING_R1 && asset->type <= ASSET_TYPE_BUILDING_I3) {
            if (asset->growthLevel < 1.0f) {
                asset->growthLevel += dt * 0.01f;
                if (asset->growthLevel > 1.0f) asset->growthLevel = 1.0f;
                
                AssetCatalogEntry* catalog = &asset_catalog[asset->assetId];
                asset->height = catalog->height * asset->scale * asset->growthLevel;
            }
        }
    }
    
    // Sort assets by depth for proper rendering
    qsort(city_assets, asset_count, sizeof(CityAsset), depth_sort_compare);
}

// Enhanced renderer with proper lighting and shadows
@interface EnhancedCityRenderer : NSObject <MTKViewDelegate>
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLRenderPipelineState> shadowPipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLDepthStencilState> depthState;
@property (nonatomic) NSUInteger vertexCount;
@end

@implementation EnhancedCityRenderer

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        self.device = device;
        self.commandQueue = [device newCommandQueue];
        [self setupPipeline];
        [self setupDepthState];
        
        printf("Enhanced renderer initialized with device: %s\n", [[device name] UTF8String]);
    }
    return self;
}

- (void)setupDepthState {
    MTLDepthStencilDescriptor *depthDescriptor = [[MTLDepthStencilDescriptor alloc] init];
    depthDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    depthDescriptor.depthWriteEnabled = YES;
    self.depthState = [self.device newDepthStencilStateWithDescriptor:depthDescriptor];
}

- (void)setupPipeline {
    NSError *error = nil;
    
    NSString *shaderSource = @"#include <metal_stdlib>\n"
        "using namespace metal;\n"
        "\n"
        "struct VertexIn {\n"
        "    float3 position [[attribute(0)]];\n"
        "    float3 normal [[attribute(1)]];\n"
        "    float3 color [[attribute(2)]];\n"
        "    float emission [[attribute(3)]];\n"
        "};\n"
        "\n"
        "struct VertexOut {\n"
        "    float4 position [[position]];\n"
        "    float3 worldPos;\n"
        "    float3 normal;\n"
        "    float3 color;\n"
        "    float emission;\n"
        "    float fogFactor;\n"
        "};\n"
        "\n"
        "struct Uniforms {\n"
        "    float4x4 viewProjection;\n"
        "    float3 sunDirection;\n"
        "    float timeOfDay;\n"
        "    float3 cameraPos;\n"
        "};\n"
        "\n"
        "vertex VertexOut vertex_main(VertexIn in [[stage_in]],\n"
        "                             constant Uniforms& uniforms [[buffer(1)]]) {\n"
        "    VertexOut out;\n"
        "    \n"
        "    // Enhanced isometric projection\n"
        "    float4 worldPos = float4(in.position, 1.0);\n"
        "    float2 iso;\n"
        "    iso.x = (worldPos.x - worldPos.z) * 0.866;\n"
        "    iso.y = (worldPos.x + worldPos.z) * 0.5 - worldPos.y * 2.0;\n"
        "    \n"
        "    // Proper depth for depth buffer (0 to 1, closer = smaller)\n"
        "    float depth = 0.5 + (worldPos.x + worldPos.z - worldPos.y * 2.0) * 0.001;\n"
        "    out.position = float4(iso.x * 0.02, iso.y * 0.02, depth, 1.0);\n"
        "    \n"
        "    out.worldPos = in.position;\n"
        "    out.normal = in.normal;\n"
        "    out.color = in.color;\n"
        "    out.emission = in.emission;\n"
        "    \n"
        "    // Distance fog\n"
        "    float dist = length(in.position.xz - uniforms.cameraPos.xz);\n"
        "    out.fogFactor = exp(-dist * 0.01);\n"
        "    \n"
        "    return out;\n"
        "}\n"
        "\n"
        "fragment float4 fragment_main(VertexOut in [[stage_in]],\n"
        "                             constant Uniforms& uniforms [[buffer(1)]]) {\n"
        "    // Time of day affects lighting\n"
        "    float dayIntensity = smoothstep(0.2, 0.3, uniforms.timeOfDay) *\n"
        "                        (1.0 - smoothstep(0.7, 0.8, uniforms.timeOfDay));\n"
        "    \n"
        "    // Sun direction changes with time\n"
        "    float3 sunDir = normalize(float3(cos(uniforms.timeOfDay * 6.28), -0.7, sin(uniforms.timeOfDay * 6.28)));\n"
        "    \n"
        "    // Basic lighting\n"
        "    float NdotL = max(0.0, dot(in.normal, -sunDir));\n"
        "    float3 ambient = float3(0.2, 0.25, 0.3) * (0.3 + dayIntensity * 0.7);\n"
        "    float3 diffuse = float3(1.0, 0.95, 0.8) * NdotL * dayIntensity;\n"
        "    \n"
        "    // Add some rim lighting for depth\n"
        "    float rim = 1.0 - max(0.0, dot(in.normal, float3(0, -1, 0)));\n"
        "    rim = pow(rim, 3.0) * 0.3;\n"
        "    \n"
        "    // Window lights at night\n"
        "    float nightLights = in.emission * (1.0 - dayIntensity) * 2.0;\n"
        "    \n"
        "    // Final color\n"
        "    float3 finalColor = in.color * (ambient + diffuse + rim) + nightLights;\n"
        "    \n"
        "    // Fog\n"
        "    float3 fogColor = float3(0.6, 0.7, 0.8) * (0.5 + dayIntensity * 0.5);\n"
        "    finalColor = mix(fogColor, finalColor, in.fogFactor);\n"
        "    \n"
        "    return float4(finalColor, 1.0);\n"
        "}\n";
    
    id<MTLLibrary> library = [self.device newLibraryWithSource:shaderSource options:nil error:&error];
    if (error) {
        NSLog(@"Shader error: %@", error);
        return;
    }
    
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_main"];
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    
    MTLVertexDescriptor *vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    // Position
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat3;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    // Normal
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat3;
    vertexDescriptor.attributes[1].offset = 12;
    vertexDescriptor.attributes[1].bufferIndex = 0;
    // Color
    vertexDescriptor.attributes[2].format = MTLVertexFormatFloat3;
    vertexDescriptor.attributes[2].offset = 24;
    vertexDescriptor.attributes[2].bufferIndex = 0;
    // Emission
    vertexDescriptor.attributes[3].format = MTLVertexFormatFloat;
    vertexDescriptor.attributes[3].offset = 36;
    vertexDescriptor.attributes[3].bufferIndex = 0;
    
    vertexDescriptor.layouts[0].stride = 40;
    
    pipelineDescriptor.vertexDescriptor = vertexDescriptor;
    
    self.pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (error) {
        NSLog(@"Pipeline error: %@", error);
    }
}

- (void)generateEnhancedGeometry {
    // Enhanced geometry with normals and multiple faces
    int verticesPerBox = 36; // 6 faces * 2 triangles * 3 vertices
    int maxVertices = asset_count * verticesPerBox;
    float *vertices = malloc(maxVertices * 10 * sizeof(float)); // 10 floats per vertex
    int vertexIndex = 0;
    
    for (int i = 0; i < asset_count; i++) {
        CityAsset* asset = &city_assets[i];
        AssetCatalogEntry* catalog = &asset_catalog[asset->assetId];
        
        // Skip tiny assets when zoomed out
        if (asset->height < 0.1f && camera_zoom < 0.5f) continue;
        
        float wx = asset->x - camera_x - CITY_WIDTH/2;
        float wy = asset->y;
        float wz = asset->z - camera_y - CITY_HEIGHT/2;
        
        float w = catalog->width * asset->scale * 0.5f;
        float h = asset->height;
        float d = catalog->depth * asset->scale * 0.5f;
        
        // Apply rotation
        float cos_r = cosf(asset->rotation);
        float sin_r = sinf(asset->rotation);
        
        // Define vertices for a box with proper normals
        float box_vertices[][10] = {
            // Front face (normal = 0,0,-1)
            {wx-w, wy,   wz-d,  0,0,-1,  catalog->r, catalog->g, catalog->b, catalog->emission},
            {wx+w, wy,   wz-d,  0,0,-1,  catalog->r, catalog->g, catalog->b, catalog->emission},
            {wx+w, wy+h, wz-d,  0,0,-1,  catalog->r*0.8f, catalog->g*0.8f, catalog->b*0.8f, catalog->emission},
            {wx-w, wy,   wz-d,  0,0,-1,  catalog->r, catalog->g, catalog->b, catalog->emission},
            {wx+w, wy+h, wz-d,  0,0,-1,  catalog->r*0.8f, catalog->g*0.8f, catalog->b*0.8f, catalog->emission},
            {wx-w, wy+h, wz-d,  0,0,-1,  catalog->r*0.8f, catalog->g*0.8f, catalog->b*0.8f, catalog->emission},
            
            // Right face (normal = 1,0,0)
            {wx+w, wy,   wz-d,  1,0,0,  catalog->r*0.85f, catalog->g*0.85f, catalog->b*0.85f, catalog->emission},
            {wx+w, wy,   wz+d,  1,0,0,  catalog->r*0.85f, catalog->g*0.85f, catalog->b*0.85f, catalog->emission},
            {wx+w, wy+h, wz+d,  1,0,0,  catalog->r*0.7f, catalog->g*0.7f, catalog->b*0.7f, catalog->emission},
            {wx+w, wy,   wz-d,  1,0,0,  catalog->r*0.85f, catalog->g*0.85f, catalog->b*0.85f, catalog->emission},
            {wx+w, wy+h, wz+d,  1,0,0,  catalog->r*0.7f, catalog->g*0.7f, catalog->b*0.7f, catalog->emission},
            {wx+w, wy+h, wz-d,  1,0,0,  catalog->r*0.7f, catalog->g*0.7f, catalog->b*0.7f, catalog->emission},
            
            // Top face (normal = 0,1,0)
            {wx-w, wy+h, wz-d,  0,1,0,  catalog->r*0.95f, catalog->g*0.95f, catalog->b*0.95f, catalog->emission},
            {wx+w, wy+h, wz-d,  0,1,0,  catalog->r*0.95f, catalog->g*0.95f, catalog->b*0.95f, catalog->emission},
            {wx+w, wy+h, wz+d,  0,1,0,  catalog->r*0.95f, catalog->g*0.95f, catalog->b*0.95f, catalog->emission},
            {wx-w, wy+h, wz-d,  0,1,0,  catalog->r*0.95f, catalog->g*0.95f, catalog->b*0.95f, catalog->emission},
            {wx+w, wy+h, wz+d,  0,1,0,  catalog->r*0.95f, catalog->g*0.95f, catalog->b*0.95f, catalog->emission},
            {wx-w, wy+h, wz+d,  0,1,0,  catalog->r*0.95f, catalog->g*0.95f, catalog->b*0.95f, catalog->emission},
        };
        
        // Copy only visible faces (optimization for isometric view)
        memcpy(&vertices[vertexIndex], box_vertices, sizeof(box_vertices));
        vertexIndex += 18 * 10;
    }
    
    self.vertexCount = vertexIndex / 10;
    
    if (self.vertexCount > 0) {
        self.vertexBuffer = [self.device newBufferWithBytes:vertices 
                                                     length:vertexIndex * sizeof(float) 
                                                    options:MTLResourceStorageModeShared];
    }
    
    free(vertices);
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
}

- (void)drawInMTKView:(MTKView *)view {
    frame_count++;
    
    // Update simulation
    update_city_simulation();
    
    // Update camera for nice view
    camera_rotation += 0.002f;
    camera_x = sinf(camera_rotation) * 30.0f;
    camera_y = cosf(camera_rotation) * 30.0f;
    camera_zoom = 0.8f + sinf(frame_count * 0.01f) * 0.2f;
    
    // Regenerate geometry
    [self generateEnhancedGeometry];
    
    // Run subsystems
    simulation_update();
    ai_update();
    audio_update();
    ui_update();
    
    // Render
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (!renderPassDescriptor) return;
    
    // Dynamic sky color based on time of day
    float dayIntensity = sinf(time_of_day * 3.14159f);
    dayIntensity = dayIntensity * dayIntensity; // Square for smoother transition
    
    float skyR = 0.1f + dayIntensity * 0.4f;
    float skyG = 0.15f + dayIntensity * 0.5f;
    float skyB = 0.2f + dayIntensity * 0.6f;
    
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(skyR, skyG, skyB, 1.0);
    
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [renderEncoder setDepthStencilState:self.depthState];
    
    if (self.pipelineState && self.vertexBuffer && self.vertexCount > 0) {
        [renderEncoder setRenderPipelineState:self.pipelineState];
        [renderEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
        
        // Set uniforms
        struct {
            simd_float4x4 viewProjection;
            simd_float3 sunDirection;
            float timeOfDay;
            simd_float3 cameraPos;
        } uniforms = {
            .viewProjection = matrix_identity_float4x4,
            .sunDirection = simd_make_float3(cosf(time_of_day * 6.28f), -0.7f, sinf(time_of_day * 6.28f)),
            .timeOfDay = time_of_day,
            .cameraPos = simd_make_float3(camera_x, 0, camera_y)
        };
        
        [renderEncoder setVertexBytes:&uniforms length:sizeof(uniforms) atIndex:1];
        [renderEncoder setFragmentBytes:&uniforms length:sizeof(uniforms) atIndex:1];
        
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:self.vertexCount];
    }
    
    [renderEncoder endEncoding];
    
    // Screenshot at frame 180
    if (frame_count == 180) {
        printf("📸 Taking automatic screenshot...\n");
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self captureMetalViewToFile:@"enhanced_city_screenshot.png" view:view];
            });
        }];
    }
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
    
    // Status updates
    if (frame_count % 60 == 0) {
        printf("SimCity ARM64 Enhanced: Frame %d - %d assets, Time: %.1f%%, Camera: (%.1f, %.1f)\n", 
               frame_count, asset_count, time_of_day * 100.0f, camera_x, camera_y);
    }
    
    // Run for 30 seconds
    if (frame_count > 1800) {
        printf("\n✅ Enhanced city demo complete!\n");
        printf("   Rendered %d assets with depth sorting\n", asset_count);
        printf("   Dynamic lighting and day/night cycle\n");
        printf("   Road network and urban planning\n");
        [NSApp terminate:nil];
    }
}

- (void)captureMetalViewToFile:(NSString *)filename view:(MTKView *)mtkView {
    id<CAMetalDrawable> drawable = mtkView.currentDrawable;
    if (!drawable || !drawable.texture) return;
    
    id<MTLTexture> texture = drawable.texture;
    NSUInteger width = texture.width;
    NSUInteger height = texture.height;
    NSUInteger bytesPerRow = width * 4;
    
    void *imageBytes = malloc(height * bytesPerRow);
    if (!imageBytes) return;
    
    [texture getBytes:imageBytes
          bytesPerRow:bytesPerRow
           fromRegion:MTLRegionMake2D(0, 0, width, height)
          mipmapLevel:0];
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(imageBytes, width, height, 8, bytesPerRow, colorSpace,
                                                  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    if (!context) {
        free(imageBytes);
        CGColorSpaceRelease(colorSpace);
        return;
    }
    
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    NSData *pngData = [bitmapRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    
    BOOL success = [pngData writeToFile:filename atomically:YES];
    if (success) {
        printf("Screenshot saved successfully: %ld x %ld pixels\n", (long)width, (long)height);
    }
    
    CGImageRelease(cgImage);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(imageBytes);
}

@end

// Application delegate
@interface EnhancedCityAppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, strong) EnhancedCityRenderer *renderer;
@end

@implementation EnhancedCityAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    printf("\n=== SimCity ARM64 - ENHANCED CITY VISUALIZATION ===\n");
    printf("Featuring:\n");
    printf("🛣️  Complete road network grid system\n");
    printf("🏙️  Proper depth-sorted rendering\n");
    printf("🌅  Dynamic day/night cycle with lighting\n");
    printf("🏗️  Realistic building heights and zones\n");
    printf("🚗  Vehicles following road paths\n");
    printf("👥  2000+ pedestrians with AI movement\n\n");
    
    // Initialize subsystems
    platform_init();
    graphics_init();
    simulation_init();
    ai_init();
    audio_init();
    ui_init();
    io_init();
    
    // Create window
    NSRect frame = NSMakeRect(50, 50, 1920, 1080);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable;
    self.window = [[NSWindow alloc] initWithContentRect:frame styleMask:style backing:NSBackingStoreBuffered defer:NO];
    [self.window setTitle:@"SimCity ARM64 - Enhanced City Visualization"];
    
    // Create Metal view with depth buffer
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    self.mtkView = [[MTKView alloc] initWithFrame:frame device:device];
    self.mtkView.preferredFramesPerSecond = 60;
    self.mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
    self.mtkView.clearDepth = 1.0;
    
    // Initialize enhanced city
    init_enhanced_city();
    
    // Create renderer
    self.renderer = [[EnhancedCityRenderer alloc] initWithDevice:device];
    self.mtkView.delegate = self.renderer;
    
    [self.window setContentView:self.mtkView];
    [self.window makeKeyAndOrderFront:nil];
    [self.window center];
    
    printf("🎮 Enhanced city window opened! Experience the living city!\n\n");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return YES;
}

@end

int main(int argc, char* argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        
        EnhancedCityAppDelegate *delegate = [[EnhancedCityAppDelegate alloc] init];
        [app setDelegate:delegate];
        
        [app run];
    }
    return 0;
}