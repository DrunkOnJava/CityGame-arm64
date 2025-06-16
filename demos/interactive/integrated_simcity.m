#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

// Enhanced building types incorporating 3D assets
typedef enum {
    TILE_EMPTY = 0,
    TILE_ROAD = 1,
    
    // Residential
    TILE_HOUSE = 2,
    TILE_APARTMENT = 3,
    
    // Commercial
    TILE_COMMERCIAL = 4,
    TILE_MALL = 5,
    TILE_COFFEE_SHOP = 6,
    TILE_BAKERY = 7,
    TILE_CINEMA = 8,
    TILE_BEAUTY_SALON = 9,
    TILE_BARBERSHOP = 10,
    
    // Industrial
    TILE_INDUSTRIAL = 11,
    TILE_FACTORY = 12,
    TILE_WAREHOUSE = 13,
    
    // Services
    TILE_HOSPITAL = 14,
    TILE_POLICE_STATION = 15,
    TILE_FIRE_STATION = 16,
    TILE_SCHOOL = 17,
    TILE_LIBRARY = 18,
    TILE_BANK = 19,
    
    // Transportation
    TILE_BUS_STATION = 20,
    TILE_TRAIN_STATION = 21,
    TILE_AIRPORT = 22,
    
    // Utilities
    TILE_POWER_PLANT = 23,
    TILE_SOLAR_PANEL = 24,
    TILE_WATER_TOWER = 25,
    
    // Parks and Recreation
    TILE_PARK = 26,
    TILE_STADIUM = 27,
    TILE_GYM = 28,
    
    // Infrastructure
    TILE_TRAFFIC_LIGHT = 29,
    TILE_STREET_LAMP = 30,
    
    TILE_TYPE_COUNT = 31
} CityTileType;

// Building categories for UI organization
typedef enum {
    CATEGORY_RESIDENTIAL = 0,
    CATEGORY_COMMERCIAL = 1,
    CATEGORY_INDUSTRIAL = 2,
    CATEGORY_SERVICES = 3,
    CATEGORY_TRANSPORTATION = 4,
    CATEGORY_UTILITIES = 5,
    CATEGORY_PARKS = 6,
    CATEGORY_INFRASTRUCTURE = 7,
    CATEGORY_COUNT = 8
} BuildingCategory;

// Enhanced city statistics
typedef struct {
    // Population
    int population;
    int households;
    int employment_rate;
    
    // Economics
    int city_funds;
    int monthly_income;
    int monthly_expenses;
    int tax_rate;
    
    // Services
    int hospital_coverage;
    int police_coverage;
    int fire_coverage;
    int education_coverage;
    
    // Infrastructure
    int power_capacity;
    int power_usage;
    int water_capacity;
    int water_usage;
    
    // Quality metrics
    int happiness;
    int safety_rating;
    int traffic_efficiency;
    int environmental_score;
    
    // Buildings by category
    int residential_buildings;
    int commercial_buildings;
    int industrial_buildings;
    int service_buildings;
    int utility_buildings;
} EnhancedCityStats;

// Building properties
typedef struct {
    CityTileType type;
    int cost;
    int monthly_income;
    int monthly_expense;
    int population_capacity;
    int job_capacity;
    int service_range;
    float happiness_modifier;
    float environmental_impact;
    BuildingCategory category;
    const char* name;
} BuildingProperties;

// Vertex structure for isometric rendering
typedef struct {
    vector_float2 position;
    vector_float2 texCoord;
} IsometricVertex;

@interface IntegratedSimCity : MTKView <MTKViewDelegate>

// Metal rendering
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLTexture> enhancedSpriteAtlas;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLRenderPipelineState> overlayPipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> indexBuffer;
@property (nonatomic, strong) id<MTLBuffer> overlayVertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> overlayIndexBuffer;
@property (nonatomic, strong) id<MTLSamplerState> samplerState;

// City data
@property (nonatomic, assign) CityTileType *cityGrid;
@property (nonatomic, assign) uint8_t *buildingVariants;
@property (nonatomic, assign) uint16_t *buildingAges; // Age in months
@property (nonatomic, assign) int gridSize;
@property (nonatomic, assign) EnhancedCityStats stats;
@property (nonatomic, assign) CityTileType currentBuildingType;
@property (nonatomic, assign) BuildingCategory currentCategory;

// Time system integration
@property (nonatomic, assign) float gameTime; // Hours since start
@property (nonatomic, assign) float timeScale; // 1.0 = real time, 60.0 = 1 hour per minute
@property (nonatomic, assign) BOOL paused;
@property (nonatomic, assign) int dayOfYear;
@property (nonatomic, assign) int season; // 0=Spring, 1=Summer, 2=Fall, 3=Winter

// Animation and effects
@property (nonatomic, assign) float animationTime;
@property (nonatomic, assign) int animationFrame;
@property (nonatomic, assign) BOOL shadowsEnabled;

// Camera controls
@property (nonatomic, assign) float cameraX;
@property (nonatomic, assign) float cameraY;
@property (nonatomic, assign) float targetCameraX;
@property (nonatomic, assign) float targetCameraY;
@property (nonatomic, assign) float zoom;
@property (nonatomic, assign) float targetZoom;

// Overlay system
@property (nonatomic, assign) int overlayMode; // 0=none, 1=zones, 2=population, etc.
@property (nonatomic, assign) BOOL overlayEnabled;

// UI Elements
@property (nonatomic, strong) NSTextField *statsLabel;
@property (nonatomic, strong) NSTextField *timeLabel;
@property (nonatomic, strong) NSTextField *buildingTypeLabel;
@property (nonatomic, strong) NSSegmentedControl *categorySelector;
@property (nonatomic, strong) NSSegmentedControl *buildingSelector;
@property (nonatomic, strong) NSButton *pauseButton;

@end

@implementation IntegratedSimCity

static BuildingProperties buildingProperties[TILE_TYPE_COUNT] = {
    // Type, Cost, Income, Expense, Pop, Jobs, Range, Happiness, Environment, Category, Name
    {TILE_EMPTY, 0, 0, 0, 0, 0, 0, 0.0f, 0.0f, CATEGORY_RESIDENTIAL, "Empty"},
    {TILE_ROAD, 100, 0, 5, 0, 0, 0, 0.0f, -0.1f, CATEGORY_INFRASTRUCTURE, "Road"},
    
    // Residential
    {TILE_HOUSE, 1000, 50, 10, 4, 0, 0, 0.2f, 0.0f, CATEGORY_RESIDENTIAL, "House"},
    {TILE_APARTMENT, 3000, 150, 30, 12, 0, 0, 0.1f, -0.1f, CATEGORY_RESIDENTIAL, "Apartment"},
    
    // Commercial
    {TILE_COMMERCIAL, 2000, 100, 20, 0, 6, 5, 0.1f, -0.2f, CATEGORY_COMMERCIAL, "Shop"},
    {TILE_MALL, 10000, 500, 100, 0, 30, 10, 0.3f, -0.3f, CATEGORY_COMMERCIAL, "Shopping Mall"},
    {TILE_COFFEE_SHOP, 1500, 75, 15, 0, 3, 3, 0.15f, -0.1f, CATEGORY_COMMERCIAL, "Coffee Shop"},
    {TILE_BAKERY, 1200, 60, 12, 0, 2, 3, 0.1f, 0.0f, CATEGORY_COMMERCIAL, "Bakery"},
    {TILE_CINEMA, 5000, 200, 50, 0, 8, 8, 0.4f, -0.1f, CATEGORY_COMMERCIAL, "Cinema"},
    {TILE_BEAUTY_SALON, 1800, 80, 18, 0, 3, 4, 0.2f, -0.1f, CATEGORY_COMMERCIAL, "Beauty Salon"},
    {TILE_BARBERSHOP, 1000, 50, 10, 0, 2, 3, 0.1f, 0.0f, CATEGORY_COMMERCIAL, "Barbershop"},
    
    // Industrial
    {TILE_INDUSTRIAL, 3000, 150, 40, 0, 10, 0, -0.2f, -0.5f, CATEGORY_INDUSTRIAL, "Factory"},
    {TILE_FACTORY, 8000, 400, 100, 0, 25, 0, -0.3f, -0.8f, CATEGORY_INDUSTRIAL, "Heavy Industry"},
    {TILE_WAREHOUSE, 2500, 100, 25, 0, 5, 0, -0.1f, -0.2f, CATEGORY_INDUSTRIAL, "Warehouse"},
    
    // Services
    {TILE_HOSPITAL, 15000, 0, 200, 0, 50, 15, 0.8f, 0.1f, CATEGORY_SERVICES, "Hospital"},
    {TILE_POLICE_STATION, 8000, 0, 100, 0, 20, 12, 0.3f, 0.0f, CATEGORY_SERVICES, "Police Station"},
    {TILE_FIRE_STATION, 6000, 0, 80, 0, 15, 10, 0.4f, 0.0f, CATEGORY_SERVICES, "Fire Station"},
    {TILE_SCHOOL, 10000, 0, 150, 0, 30, 12, 0.6f, 0.1f, CATEGORY_SERVICES, "School"},
    {TILE_LIBRARY, 5000, 0, 50, 0, 10, 8, 0.4f, 0.1f, CATEGORY_SERVICES, "Library"},
    {TILE_BANK, 12000, 300, 80, 0, 25, 6, 0.1f, 0.0f, CATEGORY_SERVICES, "Bank"},
    
    // Transportation
    {TILE_BUS_STATION, 3000, 50, 30, 0, 5, 20, 0.2f, -0.1f, CATEGORY_TRANSPORTATION, "Bus Station"},
    {TILE_TRAIN_STATION, 20000, 200, 150, 0, 40, 30, 0.5f, -0.2f, CATEGORY_TRANSPORTATION, "Train Station"},
    {TILE_AIRPORT, 100000, 1000, 500, 0, 200, 50, 0.3f, -0.8f, CATEGORY_TRANSPORTATION, "Airport"},
    
    // Utilities
    {TILE_POWER_PLANT, 25000, 0, 200, 0, 30, 0, -0.5f, -1.0f, CATEGORY_UTILITIES, "Power Plant"},
    {TILE_SOLAR_PANEL, 8000, 0, 20, 0, 2, 0, 0.2f, 0.8f, CATEGORY_UTILITIES, "Solar Panel"},
    {TILE_WATER_TOWER, 15000, 0, 100, 0, 10, 0, 0.1f, 0.0f, CATEGORY_UTILITIES, "Water Tower"},
    
    // Parks and Recreation
    {TILE_PARK, 2000, 0, 20, 0, 2, 8, 0.5f, 0.6f, CATEGORY_PARKS, "Park"},
    {TILE_STADIUM, 50000, 500, 200, 0, 100, 25, 0.8f, -0.3f, CATEGORY_PARKS, "Stadium"},
    {TILE_GYM, 4000, 100, 40, 0, 8, 6, 0.3f, 0.0f, CATEGORY_PARKS, "Gym"},
    
    // Infrastructure
    {TILE_TRAFFIC_LIGHT, 500, 0, 5, 0, 0, 2, 0.1f, 0.0f, CATEGORY_INFRASTRUCTURE, "Traffic Light"},
    {TILE_STREET_LAMP, 200, 0, 2, 0, 0, 1, 0.05f, 0.0f, CATEGORY_INFRASTRUCTURE, "Street Lamp"}
};

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.gridSize = 40; // Larger city for enhanced features
        self.currentBuildingType = TILE_HOUSE;
        self.currentCategory = CATEGORY_RESIDENTIAL;
        self.zoom = 1.0f;
        self.targetZoom = 1.0f;
        self.timeScale = 60.0f; // 1 real minute = 1 game hour
        self.shadowsEnabled = YES;
        
        [self setupMetal];
        [self createEnhancedSpriteAtlas];
        [self createShaders];
        [self initializeCityData];
        [self createGeometry];
        [self setupInteraction];
        [self createEnhancedUI];
        [self updateStats];
        
        self.delegate = self;
    }
    return self;
}

- (void)setupMetal {
    self.device = MTLCreateSystemDefaultDevice();
    self.commandQueue = [self.device newCommandQueue];
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.clearColor = MTLClearColorMake(0.2, 0.7, 0.2, 1.0); // Green grass background
    
    NSLog(@"🎮 Integrated SimCity - Metal initialized");
}

- (void)createEnhancedSpriteAtlas {
    // For this demo, create a colored atlas representing different building types
    int atlasSize = 2048;
    int tileSize = 64; // 32x32 grid of tiles
    int tilesPerRow = atlasSize / tileSize;
    
    // Create texture data
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = atlasSize * bytesPerPixel;
    NSUInteger totalBytes = atlasSize * atlasSize * bytesPerPixel;
    uint8_t *textureData = (uint8_t *)calloc(totalBytes, 1);
    
    // Generate tiles for each building type
    for (int tileType = 0; tileType < TILE_TYPE_COUNT; tileType++) {
        int tileX = tileType % tilesPerRow;
        int tileY = tileType / tilesPerRow;
        
        // Get building color based on category
        uint8_t r, g, b;
        switch (buildingProperties[tileType].category) {
            case CATEGORY_RESIDENTIAL: r = 100; g = 200; b = 100; break; // Green
            case CATEGORY_COMMERCIAL: r = 100; g = 100; b = 200; break; // Blue
            case CATEGORY_INDUSTRIAL: r = 150; g = 150; b = 150; break; // Gray
            case CATEGORY_SERVICES: r = 200; g = 100; b = 100; break; // Red
            case CATEGORY_TRANSPORTATION: r = 200; g = 200; b = 100; break; // Yellow
            case CATEGORY_UTILITIES: r = 200; g = 150; b = 100; break; // Orange
            case CATEGORY_PARKS: r = 50; g = 200; b = 50; break; // Bright Green
            case CATEGORY_INFRASTRUCTURE: r = 100; g = 100; b = 100; break; // Dark Gray
            default: r = 128; g = 128; b = 128; break;
        }
        
        // Draw tile with gradient and border
        for (int y = 0; y < tileSize; y++) {
            for (int x = 0; x < tileSize; x++) {
                int atlasX = tileX * tileSize + x;
                int atlasY = tileY * tileSize + y;
                int pixelIndex = (atlasY * atlasSize + atlasX) * 4;
                
                // Create gradient effect
                float centerX = tileSize / 2.0f;
                float centerY = tileSize / 2.0f;
                float distance = sqrtf((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
                float factor = 1.0f - (distance / (tileSize * 0.7f));
                factor = fmaxf(0.3f, fminf(1.0f, factor));
                
                // Add border
                if (x < 2 || x >= tileSize - 2 || y < 2 || y >= tileSize - 2) {
                    factor *= 0.5f;
                }
                
                textureData[pixelIndex + 0] = (uint8_t)(b * factor); // B
                textureData[pixelIndex + 1] = (uint8_t)(g * factor); // G
                textureData[pixelIndex + 2] = (uint8_t)(r * factor); // R
                textureData[pixelIndex + 3] = 255; // A
            }
        }
    }
    
    // Create Metal texture
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                                                          width:atlasSize
                                                                                         height:atlasSize
                                                                                      mipmapped:NO];
    self.enhancedSpriteAtlas = [self.device newTextureWithDescriptor:descriptor];
    
    MTLRegion region = MTLRegionMake2D(0, 0, atlasSize, atlasSize);
    [self.enhancedSpriteAtlas replaceRegion:region
                                mipmapLevel:0
                                  withBytes:textureData
                                bytesPerRow:bytesPerRow];
    
    free(textureData);
    NSLog(@"✅ Enhanced sprite atlas created: %dx%d with %d building types", atlasSize, atlasSize, TILE_TYPE_COUNT);
}

- (void)createShaders {
    NSString *vertexSource = @R"(
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float2 camera;
    float zoom;
    float time;
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                           constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    
    float2 worldPos = (in.position - uniforms.camera) * uniforms.zoom;
    out.position = float4(worldPos, 0.0, 1.0);
    out.texCoord = in.texCoord;
    
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                            texture2d<float> tex [[texture(0)]],
                            sampler samp [[sampler(0)]]) {
    float4 color = tex.sample(samp, in.texCoord);
    return color;
}
)";

    NSString *overlayVertexSource = @R"(
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct OverlayUniforms {
    float2 camera;
    float zoom;
    int mode;
    float4 color;
};

vertex VertexOut overlay_vertex_main(VertexIn in [[stage_in]],
                                   constant OverlayUniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    
    float2 worldPos = (in.position - uniforms.camera) * uniforms.zoom;
    out.position = float4(worldPos, 0.0, 1.0);
    out.texCoord = in.texCoord;
    
    return out;
}

fragment float4 overlay_fragment_main(VertexOut in [[stage_in]],
                                    constant OverlayUniforms& uniforms [[buffer(1)]]) {
    return uniforms.color;
}
)";

    NSError *error = nil;
    id<MTLLibrary> library = [self.device newLibraryWithSource:vertexSource options:nil error:&error];
    id<MTLLibrary> overlayLibrary = [self.device newLibraryWithSource:overlayVertexSource options:nil error:&error];
    
    if (error) {
        NSLog(@"❌ Shader compilation error: %@", error);
        return;
    }
    
    id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragFunc = [library newFunctionWithName:@"fragment_main"];
    id<MTLFunction> overlayVertexFunc = [overlayLibrary newFunctionWithName:@"overlay_vertex_main"];
    id<MTLFunction> overlayFragFunc = [overlayLibrary newFunctionWithName:@"overlay_fragment_main"];
    
    // Main pipeline
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = vertexFunc;
    desc.fragmentFunction = fragFunc;
    desc.colorAttachments[0].pixelFormat = self.colorPixelFormat;
    desc.colorAttachments[0].blendingEnabled = YES;
    desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    
    MTLVertexDescriptor *vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[1].offset = 8;
    vertexDescriptor.attributes[1].bufferIndex = 0;
    vertexDescriptor.layouts[0].stride = sizeof(IsometricVertex);
    desc.vertexDescriptor = vertexDescriptor;
    
    self.pipelineState = [self.device newRenderPipelineStateWithDescriptor:desc error:&error];
    
    // Overlay pipeline
    MTLRenderPipelineDescriptor *overlayDesc = [[MTLRenderPipelineDescriptor alloc] init];
    overlayDesc.vertexFunction = overlayVertexFunc;
    overlayDesc.fragmentFunction = overlayFragFunc;
    overlayDesc.colorAttachments[0].pixelFormat = self.colorPixelFormat;
    overlayDesc.colorAttachments[0].blendingEnabled = YES;
    overlayDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    overlayDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    overlayDesc.vertexDescriptor = vertexDescriptor;
    
    self.overlayPipelineState = [self.device newRenderPipelineStateWithDescriptor:overlayDesc error:&error];
    
    MTLSamplerDescriptor *samplerDesc = [[MTLSamplerDescriptor alloc] init];
    samplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
    samplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
    self.samplerState = [self.device newSamplerStateWithDescriptor:samplerDesc];
    
    NSLog(@"✅ Enhanced shaders compiled successfully");
}

- (void)initializeCityData {
    int totalTiles = self.gridSize * self.gridSize;
    self.cityGrid = malloc(totalTiles * sizeof(CityTileType));
    self.buildingVariants = malloc(totalTiles * sizeof(uint8_t));
    self.buildingAges = malloc(totalTiles * sizeof(uint16_t));
    
    // Initialize with empty tiles
    for (int i = 0; i < totalTiles; i++) {
        self.cityGrid[i] = TILE_EMPTY;
        self.buildingVariants[i] = arc4random_uniform(4);
        self.buildingAges[i] = 0;
    }
    
    // Create main roads
    for (int y = 0; y < self.gridSize; y += 8) {
        for (int x = 0; x < self.gridSize; x++) {
            if (y < self.gridSize) self.cityGrid[y * self.gridSize + x] = TILE_ROAD;
        }
    }
    
    for (int x = 0; x < self.gridSize; x += 8) {
        for (int y = 0; y < self.gridSize; y++) {
            if (x < self.gridSize) self.cityGrid[y * self.gridSize + x] = TILE_ROAD;
        }
    }
    
    // Add starter buildings showcasing different categories
    [self setTileAt:2 y:2 type:TILE_HOUSE];
    [self setTileAt:3 y:2 type:TILE_APARTMENT];
    [self setTileAt:2 y:3 type:TILE_COFFEE_SHOP];
    [self setTileAt:3 y:3 type:TILE_BAKERY];
    [self setTileAt:10 y:10 type:TILE_HOSPITAL];
    [self setTileAt:12 y:10 type:TILE_SCHOOL];
    [self setTileAt:14 y:10 type:TILE_POLICE_STATION];
    [self setTileAt:18 y:18 type:TILE_MALL];
    [self setTileAt:20 y:20 type:TILE_INDUSTRIAL];
    [self setTileAt:25 y:25 type:TILE_PARK];
    [self setTileAt:30 y:30 type:TILE_POWER_PLANT];
    [self setTileAt:32 y:30 type:TILE_SOLAR_PANEL];
    
    NSLog(@"✅ Enhanced city data initialized: %dx%d", self.gridSize, self.gridSize);
}

- (void)setTileAt:(int)x y:(int)y type:(CityTileType)type {
    if (x >= 0 && x < self.gridSize && y >= 0 && y < self.gridSize) {
        int index = y * self.gridSize + x;
        self.cityGrid[index] = type;
        self.buildingAges[index] = 0;
        NSLog(@"🏗️ Placed %s at (%d, %d)", buildingProperties[type].name, x, y);
    }
}

- (CityTileType)getTileAt:(int)x y:(int)y {
    if (x >= 0 && x < self.gridSize && y >= 0 && y < self.gridSize) {
        return self.cityGrid[y * self.gridSize + x];
    }
    return TILE_EMPTY;
}

- (void)createGeometry {
    [self rebuildGeometry];
}

- (void)rebuildGeometry {
    // Count non-empty tiles for dynamic allocation
    int tileCount = 0;
    for (int y = 0; y < self.gridSize; y++) {
        for (int x = 0; x < self.gridSize; x++) {
            CityTileType type = [self getTileAt:x y:y];
            if (type != TILE_EMPTY) {
                tileCount++;
            }
        }
    }
    
    if (tileCount == 0) return;
    
    // Allocate vertex and index arrays
    IsometricVertex *vertices = malloc(tileCount * 4 * sizeof(IsometricVertex));
    uint16_t *indices = malloc(tileCount * 6 * sizeof(uint16_t));
    
    int vertexIndex = 0;
    int indexIndex = 0;
    int quadIndex = 0;
    
    // Generate geometry for all non-empty tiles
    for (int y = 0; y < self.gridSize; y++) {
        for (int x = 0; x < self.gridSize; x++) {
            CityTileType type = [self getTileAt:x y:y];
            if (type == TILE_EMPTY) continue;
            
            // Isometric conversion with height offsets
            float isoX = (x - y) * 0.08f;
            float isoY = (x + y) * 0.04f;
            
            // Height offset based on building category
            float heightOffset = 0.0f;
            switch (buildingProperties[type].category) {
                case CATEGORY_SERVICES: heightOffset = 0.02f; break;
                case CATEGORY_TRANSPORTATION: heightOffset = 0.025f; break;
                case CATEGORY_COMMERCIAL: heightOffset = 0.015f; break;
                case CATEGORY_INDUSTRIAL: heightOffset = 0.02f; break;
                case CATEGORY_UTILITIES: heightOffset = 0.03f; break;
                default: heightOffset = 0.01f; break;
            }
            
            float tileWidth = 0.06f;
            float tileHeight = 0.06f;
            
            // Get UV coordinates for this tile type
            float u1, v1, u2, v2;
            [self getUVForTileType:type u1:&u1 v1:&v1 u2:&u2 v2:&v2];
            
            // Create quad vertices
            vertices[vertexIndex + 0] = (IsometricVertex){{isoX - tileWidth, isoY - tileHeight + heightOffset}, {u1, v2}};
            vertices[vertexIndex + 1] = (IsometricVertex){{isoX + tileWidth, isoY - tileHeight + heightOffset}, {u2, v2}};
            vertices[vertexIndex + 2] = (IsometricVertex){{isoX + tileWidth, isoY + tileHeight + heightOffset}, {u2, v1}};
            vertices[vertexIndex + 3] = (IsometricVertex){{isoX - tileWidth, isoY + tileHeight + heightOffset}, {u1, v1}};
            
            // Create triangle indices
            uint16_t baseVertex = quadIndex * 4;
            indices[indexIndex + 0] = baseVertex + 0;
            indices[indexIndex + 1] = baseVertex + 1;
            indices[indexIndex + 2] = baseVertex + 2;
            indices[indexIndex + 3] = baseVertex + 2;
            indices[indexIndex + 4] = baseVertex + 3;
            indices[indexIndex + 5] = baseVertex + 0;
            
            vertexIndex += 4;
            indexIndex += 6;
            quadIndex++;
        }
    }
    
    // Create Metal buffers
    self.vertexBuffer = [self.device newBufferWithBytes:vertices
                                                 length:tileCount * 4 * sizeof(IsometricVertex)
                                                options:MTLResourceStorageModeShared];
    
    self.indexBuffer = [self.device newBufferWithBytes:indices
                                               length:tileCount * 6 * sizeof(uint16_t)
                                              options:MTLResourceStorageModeShared];
    
    // Create overlay geometry if enabled
    if (self.overlayEnabled) {
        [self createOverlayGeometry];
    }
    
    free(vertices);
    free(indices);
}

- (void)createOverlayGeometry {
    // Count tiles that need overlay
    int overlayCount = 0;
    for (int y = 0; y < self.gridSize; y++) {
        for (int x = 0; x < self.gridSize; x++) {
            CityTileType type = [self getTileAt:x y:y];
            if (type != TILE_EMPTY && [self shouldShowOverlay:type]) {
                overlayCount++;
            }
        }
    }
    
    if (overlayCount == 0) return;
    
    IsometricVertex *overlayVertices = malloc(overlayCount * 4 * sizeof(IsometricVertex));
    uint16_t *overlayIndices = malloc(overlayCount * 6 * sizeof(uint16_t));
    
    int vertexIndex = 0;
    int indexIndex = 0;
    int quadIndex = 0;
    
    for (int y = 0; y < self.gridSize; y++) {
        for (int x = 0; x < self.gridSize; x++) {
            CityTileType type = [self getTileAt:x y:y];
            if (type == TILE_EMPTY || ![self shouldShowOverlay:type]) continue;
            
            float isoX = (x - y) * 0.08f;
            float isoY = (x + y) * 0.04f + 0.005f; // Slightly above buildings
            
            float tileWidth = 0.065f;
            float tileHeight = 0.065f;
            
            // Create overlay quad
            overlayVertices[vertexIndex + 0] = (IsometricVertex){{isoX - tileWidth, isoY - tileHeight}, {0, 1}};
            overlayVertices[vertexIndex + 1] = (IsometricVertex){{isoX + tileWidth, isoY - tileHeight}, {1, 1}};
            overlayVertices[vertexIndex + 2] = (IsometricVertex){{isoX + tileWidth, isoY + tileHeight}, {1, 0}};
            overlayVertices[vertexIndex + 3] = (IsometricVertex){{isoX - tileWidth, isoY + tileHeight}, {0, 0}};
            
            uint16_t baseVertex = quadIndex * 4;
            overlayIndices[indexIndex + 0] = baseVertex + 0;
            overlayIndices[indexIndex + 1] = baseVertex + 1;
            overlayIndices[indexIndex + 2] = baseVertex + 2;
            overlayIndices[indexIndex + 3] = baseVertex + 2;
            overlayIndices[indexIndex + 4] = baseVertex + 3;
            overlayIndices[indexIndex + 5] = baseVertex + 0;
            
            vertexIndex += 4;
            indexIndex += 6;
            quadIndex++;
        }
    }
    
    self.overlayVertexBuffer = [self.device newBufferWithBytes:overlayVertices
                                                        length:overlayCount * 4 * sizeof(IsometricVertex)
                                                       options:MTLResourceStorageModeShared];
    
    self.overlayIndexBuffer = [self.device newBufferWithBytes:overlayIndices
                                                       length:overlayCount * 6 * sizeof(uint16_t)
                                                      options:MTLResourceStorageModeShared];
    
    free(overlayVertices);
    free(overlayIndices);
}

- (BOOL)shouldShowOverlay:(CityTileType)type {
    switch (self.overlayMode) {
        case 1: return buildingProperties[type].category == CATEGORY_RESIDENTIAL;
        case 2: return buildingProperties[type].category == CATEGORY_COMMERCIAL;
        case 3: return buildingProperties[type].category == CATEGORY_SERVICES;
        case 4: return buildingProperties[type].category == CATEGORY_UTILITIES;
        default: return NO;
    }
}

- (void)getUVForTileType:(CityTileType)tileType u1:(float*)u1 v1:(float*)v1 u2:(float*)u2 v2:(float*)v2 {
    float atlasSize = 2048.0f;
    float tileSize = 64.0f;
    float tilesPerRow = atlasSize / tileSize;
    
    int tileX = tileType % (int)tilesPerRow;
    int tileY = tileType / (int)tilesPerRow;
    
    *u1 = (tileX * tileSize) / atlasSize;
    *v1 = (tileY * tileSize) / atlasSize;
    *u2 = *u1 + (tileSize / atlasSize);
    *v2 = *v1 + (tileSize / atlasSize);
}

- (void)setupInteraction {
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                                options:(NSTrackingActiveInKeyWindow | 
                                                                       NSTrackingMouseMoved |
                                                                       NSTrackingInVisibleRect)
                                                                  owner:self
                                                               userInfo:nil];
    [self addTrackingArea:trackingArea];
    
    NSLog(@"✅ Enhanced interaction controls enabled");
}

- (void)createEnhancedUI {
    // Category selector
    NSArray *categoryNames = @[@"Residential", @"Commercial", @"Industrial", @"Services", 
                              @"Transport", @"Utilities", @"Parks", @"Infrastructure"];
    self.categorySelector = [[NSSegmentedControl alloc] initWithLabels:categoryNames
                                                            trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                  target:self
                                                                  action:@selector(categoryChanged:)];
    self.categorySelector.frame = NSMakeRect(10, 10, 600, 25);
    self.categorySelector.selectedSegment = 0;
    [self addSubview:self.categorySelector];
    
    // Building selector (will be populated based on category)
    self.buildingSelector = [[NSSegmentedControl alloc] initWithLabels:@[@"House", @"Apartment"]
                                                           trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                 target:self
                                                                 action:@selector(buildingChanged:)];
    self.buildingSelector.frame = NSMakeRect(10, 40, 400, 25);
    self.buildingSelector.selectedSegment = 0;
    [self addSubview:self.buildingSelector];
    
    // Enhanced statistics label
    self.statsLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 200, 350, 120)];
    self.statsLabel.editable = NO;
    self.statsLabel.bordered = NO;
    self.statsLabel.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.8];
    self.statsLabel.textColor = [NSColor whiteColor];
    self.statsLabel.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    [self addSubview:self.statsLabel];
    
    // Time display
    self.timeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 330, 200, 40)];
    self.timeLabel.editable = NO;
    self.timeLabel.bordered = NO;
    self.timeLabel.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.8];
    self.timeLabel.textColor = [NSColor yellowColor];
    self.timeLabel.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightBold];
    [self addSubview:self.timeLabel];
    
    // Pause button
    self.pauseButton = [[NSButton alloc] initWithFrame:NSMakeRect(220, 330, 80, 40)];
    [self.pauseButton setTitle:@"⏸️ Pause"];
    [self.pauseButton setTarget:self];
    [self.pauseButton setAction:@selector(togglePause:)];
    [self addSubview:self.pauseButton];
    
    // Building type label
    self.buildingTypeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 70, 300, 20)];
    self.buildingTypeLabel.editable = NO;
    self.buildingTypeLabel.bordered = NO;
    self.buildingTypeLabel.backgroundColor = [NSColor clearColor];
    self.buildingTypeLabel.textColor = [NSColor blackColor];
    self.buildingTypeLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightBold];
    [self addSubview:self.buildingTypeLabel];
    
    [self updateBuildingOptions];
    [self updateBuildingTypeLabel];
    
    NSLog(@"✅ Enhanced UI created with category selection");
}

- (void)categoryChanged:(NSSegmentedControl*)sender {
    self.currentCategory = (BuildingCategory)sender.selectedSegment;
    [self updateBuildingOptions];
    [self updateBuildingTypeLabel];
}

- (void)buildingChanged:(NSSegmentedControl*)sender {
    // Find the building type based on category and selection
    int selectionIndex = 0;
    for (int i = 0; i < TILE_TYPE_COUNT; i++) {
        if (buildingProperties[i].category == self.currentCategory) {
            if (selectionIndex == sender.selectedSegment) {
                self.currentBuildingType = (CityTileType)i;
                break;
            }
            selectionIndex++;
        }
    }
    [self updateBuildingTypeLabel];
}

- (void)updateBuildingOptions {
    // Count buildings in current category
    NSMutableArray *buildingNames = [[NSMutableArray alloc] init];
    for (int i = 0; i < TILE_TYPE_COUNT; i++) {
        if (buildingProperties[i].category == self.currentCategory) {
            [buildingNames addObject:[NSString stringWithUTF8String:buildingProperties[i].name]];
        }
    }
    
    // Update building selector
    [self.buildingSelector removeFromSuperview];
    self.buildingSelector = [[NSSegmentedControl alloc] initWithLabels:buildingNames
                                                           trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                 target:self
                                                                 action:@selector(buildingChanged:)];
    self.buildingSelector.frame = NSMakeRect(10, 40, MIN(600, buildingNames.count * 80), 25);
    self.buildingSelector.selectedSegment = 0;
    [self addSubview:self.buildingSelector];
    
    // Update current building type to first in category
    for (int i = 0; i < TILE_TYPE_COUNT; i++) {
        if (buildingProperties[i].category == self.currentCategory) {
            self.currentBuildingType = (CityTileType)i;
            break;
        }
    }
}

- (void)togglePause:(NSButton*)sender {
    self.paused = !self.paused;
    [self.pauseButton setTitle:self.paused ? @"▶️ Play" : @"⏸️ Pause"];
}

- (void)updateBuildingTypeLabel {
    BuildingProperties props = buildingProperties[self.currentBuildingType];
    self.buildingTypeLabel.stringValue = [NSString stringWithFormat:@"Selected: %s (Cost: $%d, Income: $%d/month)", 
                                         props.name, props.cost, props.monthly_income];
}

- (void)updateStats {
    // Reset statistics
    memset(&self.stats, 0, sizeof(EnhancedCityStats));
    self.stats.city_funds = 50000; // Starting funds
    
    // Count buildings and calculate statistics
    for (int y = 0; y < self.gridSize; y++) {
        for (int x = 0; x < self.gridSize; x++) {
            CityTileType type = [self getTileAt:x y:y];
            if (type == TILE_EMPTY) continue;
            
            BuildingProperties props = buildingProperties[type];
            
            // Add population and jobs
            self.stats.population += props.population_capacity;
            self.stats.monthly_income += props.monthly_income;
            self.stats.monthly_expenses += props.monthly_expense;
            
            // Count by category
            switch (props.category) {
                case CATEGORY_RESIDENTIAL: self.stats.residential_buildings++; break;
                case CATEGORY_COMMERCIAL: self.stats.commercial_buildings++; break;
                case CATEGORY_INDUSTRIAL: self.stats.industrial_buildings++; break;
                case CATEGORY_SERVICES: self.stats.service_buildings++; break;
                case CATEGORY_UTILITIES: self.stats.utility_buildings++; break;
                default: break;
            }
            
            // Calculate coverage and efficiency
            if (type == TILE_HOSPITAL) self.stats.hospital_coverage += 15;
            if (type == TILE_POLICE_STATION) self.stats.police_coverage += 12;
            if (type == TILE_FIRE_STATION) self.stats.fire_coverage += 10;
            if (type == TILE_SCHOOL || type == TILE_LIBRARY) self.stats.education_coverage += 8;
            if (type == TILE_POWER_PLANT) self.stats.power_capacity += 1000;
            if (type == TILE_SOLAR_PANEL) self.stats.power_capacity += 100;
            if (type == TILE_WATER_TOWER) self.stats.water_capacity += 500;
        }
    }
    
    // Calculate derived metrics
    int totalBuildings = self.stats.residential_buildings + self.stats.commercial_buildings + 
                        self.stats.industrial_buildings + self.stats.service_buildings;
    
    if (totalBuildings > 0) {
        self.stats.happiness = 50 + (self.stats.service_buildings * 5) - (self.stats.industrial_buildings * 2);
        self.stats.happiness = MAX(0, MIN(100, self.stats.happiness));
        
        self.stats.safety_rating = MIN(100, self.stats.police_coverage + self.stats.fire_coverage);
        self.stats.environmental_score = MAX(0, 50 + (self.stats.utility_buildings * 2) - (self.stats.industrial_buildings * 3));
    }
    
    self.stats.power_usage = totalBuildings * 10;
    self.stats.water_usage = self.stats.population * 2;
    self.stats.employment_rate = self.stats.population > 0 ? MIN(100, (self.stats.monthly_income / 10) * 100 / self.stats.population) : 0;
    
    // Update display
    NSString *statsText = [NSString stringWithFormat:
        @"🏙️ SIMCITY STATISTICS\n"
        @"Population: %d\n"
        @"Employment: %d%%\n"
        @"Happiness: %d%%\n"
        @"Safety: %d%%\n"
        @"Environment: %d%%\n"
        @"\n💰 ECONOMICS\n"
        @"Funds: $%d\n"
        @"Income: $%d/month\n"
        @"Expenses: $%d/month\n"
        @"Net: $%d/month",
        self.stats.population,
        self.stats.employment_rate,
        self.stats.happiness,
        self.stats.safety_rating,
        self.stats.environmental_score,
        self.stats.city_funds,
        self.stats.monthly_income,
        self.stats.monthly_expenses,
        self.stats.monthly_income - self.stats.monthly_expenses
    ];
    
    self.statsLabel.stringValue = statsText;
}

- (void)updateTimeDisplay {
    int hours = (int)self.gameTime % 24;
    int minutes = (int)((self.gameTime - hours) * 60) % 60;
    self.dayOfYear = ((int)self.gameTime / 24) % 365;
    self.season = (self.dayOfYear / 91) % 4;
    
    NSArray *seasonNames = @[@"🌸 Spring", @"☀️ Summer", @"🍂 Fall", @"❄️ Winter"];
    
    NSString *timeText = [NSString stringWithFormat:@"Day %d - %02d:%02d\n%@ (%.1fx speed)",
                         self.dayOfYear + 1, hours, minutes, seasonNames[self.season], self.timeScale];
    
    self.timeLabel.stringValue = timeText;
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    
    // Convert screen coordinates to world coordinates
    float worldX = (location.x / self.frame.size.width * 2.0f - 1.0f) / self.zoom + self.cameraX;
    float worldY = (1.0f - location.y / self.frame.size.height * 2.0f) / self.zoom + self.cameraY;
    
    // Convert to tile coordinates (reverse isometric)
    int tileX = (int)((worldX / 0.08f + worldY / 0.04f) / 2.0f);
    int tileY = (int)((worldY / 0.04f - worldX / 0.08f) / 2.0f);
    
    if (tileX >= 0 && tileX < self.gridSize && tileY >= 0 && tileY < self.gridSize) {
        if ([event buttonNumber] == 0) { // Left click - place building
            // Check if we can afford it
            BuildingProperties props = buildingProperties[self.currentBuildingType];
            if (self.stats.city_funds >= props.cost) {
                [self setTileAt:tileX y:tileY type:self.currentBuildingType];
                self.stats.city_funds -= props.cost;
                [self rebuildGeometry];
                [self updateStats];
            } else {
                NSLog(@"💰 Not enough funds! Need $%d, have $%d", props.cost, self.stats.city_funds);
            }
        } else { // Right click - remove building
            CityTileType currentType = [self getTileAt:tileX y:tileY];
            if (currentType != TILE_EMPTY) {
                BuildingProperties props = buildingProperties[currentType];
                [self setTileAt:tileX y:tileY type:TILE_EMPTY];
                self.stats.city_funds += props.cost / 2; // 50% refund
                [self rebuildGeometry];
                [self updateStats];
            }
        }
    }
}

- (void)keyDown:(NSEvent *)event {
    switch (event.keyCode) {
        case 49: // Space - pause/unpause
            [self togglePause:self.pauseButton];
            break;
        case 24: // + key - increase speed
            self.timeScale = MIN(300.0f, self.timeScale * 2.0f);
            break;
        case 27: // - key - decrease speed
            self.timeScale = MAX(1.0f, self.timeScale / 2.0f);
            break;
        case 7: // X key - toggle overlays
            self.overlayMode = (self.overlayMode + 1) % 5;
            self.overlayEnabled = (self.overlayMode > 0);
            [self rebuildGeometry];
            break;
    }
}

- (void)drawInMTKView:(MTKView *)view {
    // Update time
    if (!self.paused) {
        self.gameTime += (1.0f/60.0f) * self.timeScale / 60.0f; // Convert to game hours
    }
    [self updateTimeDisplay];
    
    // Update camera
    self.cameraX += (self.targetCameraX - self.cameraX) * 0.1f;
    self.cameraY += (self.targetCameraY - self.cameraY) * 0.1f;
    self.zoom += (self.targetZoom - self.zoom) * 0.1f;
    
    // Update animation
    self.animationTime += 1.0f/60.0f;
    self.animationFrame = ((int)(self.animationTime * 4.0f)) % 4;
    
    if (!self.pipelineState || !self.enhancedSpriteAtlas || !self.vertexBuffer) return;
    
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    
    if (renderPassDescriptor) {
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        
        // Render main buildings
        [encoder setRenderPipelineState:self.pipelineState];
        [encoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
        
        struct {
            vector_float2 camera;
            float zoom;
            float time;
        } uniforms = {
            .camera = {self.cameraX, self.cameraY},
            .zoom = self.zoom,
            .time = self.animationTime
        };
        
        [encoder setVertexBytes:&uniforms length:sizeof(uniforms) atIndex:1];
        [encoder setFragmentTexture:self.enhancedSpriteAtlas atIndex:0];
        [encoder setFragmentSamplerState:self.samplerState atIndex:0];
        
        NSUInteger indexCount = [self.indexBuffer length] / sizeof(uint16_t);
        [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                            indexCount:indexCount
                             indexType:MTLIndexTypeUInt16
                           indexBuffer:self.indexBuffer
                     indexBufferOffset:0];
        
        // Render overlays if enabled
        if (self.overlayEnabled && self.overlayVertexBuffer) {
            [encoder setRenderPipelineState:self.overlayPipelineState];
            [encoder setVertexBuffer:self.overlayVertexBuffer offset:0 atIndex:0];
            
            struct {
                vector_float2 camera;
                float zoom;
                int mode;
                vector_float4 color;
            } overlayUniforms = {
                .camera = {self.cameraX, self.cameraY},
                .zoom = self.zoom,
                .mode = self.overlayMode,
                .color = [self getOverlayColor]
            };
            
            [encoder setVertexBytes:&overlayUniforms length:sizeof(overlayUniforms) atIndex:1];
            
            NSUInteger overlayIndexCount = [self.overlayIndexBuffer length] / sizeof(uint16_t);
            [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                indexCount:overlayIndexCount
                                 indexType:MTLIndexTypeUInt16
                               indexBuffer:self.overlayIndexBuffer
                         indexBufferOffset:0];
        }
        
        [encoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    
    [commandBuffer commit];
}

- (vector_float4)getOverlayColor {
    switch (self.overlayMode) {
        case 1: return (vector_float4){0.0f, 1.0f, 0.0f, 0.3f}; // Green for residential
        case 2: return (vector_float4){0.0f, 0.0f, 1.0f, 0.3f}; // Blue for commercial
        case 3: return (vector_float4){1.0f, 0.0f, 0.0f, 0.3f}; // Red for services
        case 4: return (vector_float4){1.0f, 1.0f, 0.0f, 0.3f}; // Yellow for utilities
        default: return (vector_float4){1.0f, 1.0f, 1.0f, 0.2f};
    }
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Adjust UI layout for new size
    self.statsLabel.frame = NSMakeRect(10, size.height - 150, 350, 120);
    self.timeLabel.frame = NSMakeRect(10, size.height - 180, 200, 40);
    self.pauseButton.frame = NSMakeRect(220, size.height - 180, 80, 40);
}

- (void)dealloc {
    if (self.cityGrid) free(self.cityGrid);
    if (self.buildingVariants) free(self.buildingVariants);
    if (self.buildingAges) free(self.buildingAges);
}

@end

// Main application
@interface IntegratedSimCityApp : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) IntegratedSimCity *simCityView;
@end

@implementation IntegratedSimCityApp

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSRect frame = NSMakeRect(100, 100, 1400, 900);
    
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled | 
                                                       NSWindowStyleMaskClosable | 
                                                       NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    self.window.title = @"🏙️ SimCity ARM64 - Enhanced with 3D Assets";
    
    self.simCityView = [[IntegratedSimCity alloc] initWithFrame:frame];
    self.window.contentView = self.simCityView;
    
    [self.window makeKeyAndOrderFront:nil];
    [self.window center];
    
    NSLog(@"🚀 Integrated SimCity launched with enhanced 3D assets!");
    NSLog(@"🎮 Controls:");
    NSLog(@"   • Click categories to select building types");
    NSLog(@"   • Left click: Place building");
    NSLog(@"   • Right click: Remove building");
    NSLog(@"   • Space: Pause/unpause");
    NSLog(@"   • +/-: Change time speed");
    NSLog(@"   • X: Toggle overlays");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return YES;
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        IntegratedSimCityApp *delegate = [[IntegratedSimCityApp alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}