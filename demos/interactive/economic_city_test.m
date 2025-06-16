#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

// City tile types
typedef enum {
    TILE_EMPTY = 0,
    TILE_ROAD = 1,
    TILE_HOUSE = 2,
    TILE_COMMERCIAL = 3,
    TILE_INDUSTRIAL = 4,
    TILE_PARK = 5,
    TILE_TYPE_COUNT = 6
} CityTileType;

// Vertex structure
typedef struct {
    vector_float2 position;
    vector_float2 texCoord;
} IsometricVertex;

// Enhanced City statistics with economic data
typedef struct {
    int population;
    int jobs;
    int houses;
    int commercial;
    int industrial;
    int happiness;
    
    // Economic indicators
    long long cityFunds;
    long long monthlyIncome;
    long long monthlyExpenses;
    int taxRateResidential;
    int taxRateCommercial;
    int taxRateIndustrial;
    int unemploymentRate;
    int landValueAverage;
    int economicIndicator;
    
    // RCI Demand
    int demandResidential;
    int demandCommercial;
    int demandIndustrial;
    
    // Population breakdown
    int populationEmployed;
    int populationUnemployed;
} CityStats;

@interface EconomicCityTest : MTKView <MTKViewDelegate>
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLTexture> spriteAtlas;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> indexBuffer;
@property (nonatomic, strong) id<MTLSamplerState> samplerState;

// City data
@property (nonatomic, assign) CityTileType *cityGrid;
@property (nonatomic, assign) uint8_t *buildingVariants;
@property (nonatomic, assign) int gridSize;
@property (nonatomic, assign) CityStats stats;
@property (nonatomic, assign) CityTileType currentBuildingType;

// Animation
@property (nonatomic, assign) float animationTime;
@property (nonatomic, assign) int animationFrame;

// Camera
@property (nonatomic, assign) float cameraX;
@property (nonatomic, assign) float cameraY;
@property (nonatomic, assign) float targetCameraX;
@property (nonatomic, assign) float targetCameraY;
@property (nonatomic, assign) float zoom;
@property (nonatomic, assign) float targetZoom;

// UI
@property (nonatomic, strong) NSTextField *statsLabel;
@property (nonatomic, strong) NSTextField *buildingTypeLabel;
@end

@implementation EconomicCityTest

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.gridSize = 30;
        self.currentBuildingType = TILE_HOUSE;
        self.zoom = 1.0f;
        self.targetZoom = 1.0f;
        
        [self setupMetal];
        [self loadSpriteAtlas];
        [self createShaders];
        [self initializeCityData];
        [self createGeometry];
        [self setupInteraction];
        [self createUI];
        [self updateStats];
        
        self.delegate = self;
    }
    return self;
}

- (void)setupMetal {
    self.device = MTLCreateSystemDefaultDevice();
    self.commandQueue = [self.device newCommandQueue];
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.clearColor = MTLClearColorMake(0.15, 0.7, 0.15, 1.0);
    
    NSLog(@"🎮 Economic City Test - Metal initialized");
}

- (void)loadSpriteAtlas {
    NSString *atlasPath = @"assets/atlases/buildings.png";
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:atlasPath];
    
    if (!image) {
        NSLog(@"❌ Could not load sprite atlas, using placeholder");
        return;
    }
    
    CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    
    size_t bytesPerRow = width * 4;
    unsigned char *data = malloc(height * bytesPerRow);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data, width, height, 8, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                          width:width
                                                                                         height:height
                                                                                      mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead;
    
    self.spriteAtlas = [self.device newTextureWithDescriptor:descriptor];
    [self.spriteAtlas replaceRegion:MTLRegionMake2D(0, 0, width, height)
                        mipmapLevel:0
                          withBytes:data
                        bytesPerRow:bytesPerRow];
    
    free(data);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    NSLog(@"✅ Sprite atlas loaded for economic test");
}

- (void)createShaders {
    NSString *shaderSource = @""
    "#include <metal_stdlib>\n"
    "using namespace metal;\n"
    "\n"
    "struct VertexIn {\n"
    "    float2 position [[attribute(0)]];\n"
    "    float2 texCoord [[attribute(1)]];\n"
    "};\n"
    "\n"
    "struct VertexOut {\n"
    "    float4 position [[position]];\n"
    "    float2 texCoord;\n"
    "};\n"
    "\n"
    "struct Uniforms {\n"
    "    float2 camera;\n"
    "    float zoom;\n"
    "};\n"
    "\n"
    "vertex VertexOut vertex_main(VertexIn in [[stage_in]],\n"
    "                            constant Uniforms& uniforms [[buffer(1)]]) {\n"
    "    VertexOut out;\n"
    "    float2 worldPos = (in.position - uniforms.camera) * uniforms.zoom;\n"
    "    out.position = float4(worldPos, 0.0, 1.0);\n"
    "    out.texCoord = in.texCoord;\n"
    "    return out;\n"
    "}\n"
    "\n"
    "fragment float4 fragment_main(VertexOut in [[stage_in]],\n"
    "                             texture2d<float> atlas [[texture(0)]]) {\n"
    "    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::nearest);\n"
    "    float4 color = atlas.sample(s, in.texCoord);\n"
    "    if (color.a < 0.1) discard_fragment();\n"
    "    return color;\n"
    "}\n";
    
    NSError *error = nil;
    id<MTLLibrary> library = [self.device newLibraryWithSource:shaderSource options:nil error:&error];
    if (!library) {
        NSLog(@"❌ Shader error: %@", error);
        return;
    }
    
    id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragFunc = [library newFunctionWithName:@"fragment_main"];
    
    MTLVertexDescriptor *vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[1].offset = 8;
    vertexDescriptor.attributes[1].bufferIndex = 0;
    vertexDescriptor.layouts[0].stride = sizeof(IsometricVertex);
    
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = vertexFunc;
    desc.fragmentFunction = fragFunc;
    desc.vertexDescriptor = vertexDescriptor;
    desc.colorAttachments[0].pixelFormat = self.colorPixelFormat;
    desc.colorAttachments[0].blendingEnabled = YES;
    desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    
    self.pipelineState = [self.device newRenderPipelineStateWithDescriptor:desc error:&error];
    
    MTLSamplerDescriptor *samplerDesc = [[MTLSamplerDescriptor alloc] init];
    samplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
    samplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
    self.samplerState = [self.device newSamplerStateWithDescriptor:samplerDesc];
    
    NSLog(@"✅ Shaders ready for economic test");
}

- (void)initializeCityData {
    int totalTiles = self.gridSize * self.gridSize;
    self.cityGrid = malloc(totalTiles * sizeof(CityTileType));
    self.buildingVariants = malloc(totalTiles * sizeof(uint8_t));
    
    srand48(time(NULL));
    
    // Create test city with economic focus
    for (int y = 0; y < self.gridSize; y++) {
        for (int x = 0; x < self.gridSize; x++) {
            int index = y * self.gridSize + x;
            
            if ((x % 5) == 0 || (y % 5) == 0) {
                self.cityGrid[index] = TILE_ROAD;
            } else {
                self.cityGrid[index] = TILE_EMPTY;
            }
            
            self.buildingVariants[index] = arc4random_uniform(4);
        }
    }
    
    // Add test buildings for economic simulation
    [self setTileAt:2 y:2 type:TILE_HOUSE];
    [self setTileAt:3 y:2 type:TILE_HOUSE];
    [self setTileAt:2 y:3 type:TILE_HOUSE];
    [self setTileAt:7 y:7 type:TILE_COMMERCIAL];
    [self setTileAt:8 y:7 type:TILE_COMMERCIAL];
    [self setTileAt:12 y:12 type:TILE_INDUSTRIAL];
    [self setTileAt:13 y:12 type:TILE_INDUSTRIAL];
    [self setTileAt:6 y:8 type:TILE_PARK];
    
    NSLog(@"✅ Economic test city initialized: %dx%d", self.gridSize, self.gridSize);
}

- (void)setTileAt:(int)x y:(int)y type:(CityTileType)type {
    if (x >= 0 && x < self.gridSize && y >= 0 && y < self.gridSize) {
        self.cityGrid[y * self.gridSize + x] = type;
    }
}

- (void)createGeometry {
    [self rebuildGeometry];
}

- (void)rebuildGeometry {
    // Simple geometry creation for testing
    int maxTiles = self.gridSize * self.gridSize;
    IsometricVertex *vertices = malloc(maxTiles * 4 * sizeof(IsometricVertex));
    uint16_t *indices = malloc(maxTiles * 6 * sizeof(uint16_t));
    
    int vertexIndex = 0;
    int indexIndex = 0;
    int quadIndex = 0;
    
    for (int y = 0; y < self.gridSize; y++) {
        for (int x = 0; x < self.gridSize; x++) {
            int tileIndex = y * self.gridSize + x;
            CityTileType tileType = self.cityGrid[tileIndex];
            
            if (tileType == TILE_EMPTY) continue;
            
            float isoX = (x - y) * 0.1f;
            float isoY = (x + y) * 0.05f;
            float tileWidth = 0.08f;
            float tileHeight = 0.08f;
            
            float u1 = 0.0f, v1 = 0.0f, u2 = 0.0625f, v2 = 0.0625f; // Simple UV
            
            vertices[vertexIndex + 0] = (IsometricVertex){{isoX - tileWidth, isoY - tileHeight}, {u1, v2}};
            vertices[vertexIndex + 1] = (IsometricVertex){{isoX + tileWidth, isoY - tileHeight}, {u2, v2}};
            vertices[vertexIndex + 2] = (IsometricVertex){{isoX + tileWidth, isoY + tileHeight}, {u2, v1}};
            vertices[vertexIndex + 3] = (IsometricVertex){{isoX - tileWidth, isoY + tileHeight}, {u1, v1}};
            
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
    
    if (quadIndex > 0) {
        self.vertexBuffer = [self.device newBufferWithBytes:vertices
                                                     length:quadIndex * 4 * sizeof(IsometricVertex)
                                                    options:MTLResourceStorageModeShared];
        
        self.indexBuffer = [self.device newBufferWithBytes:indices
                                                    length:quadIndex * 6 * sizeof(uint16_t)
                                                   options:MTLResourceStorageModeShared];
    }
    
    free(vertices);
    free(indices);
}

- (void)updateStats {
    // Enhanced statistics calculation with economic focus
    CityStats newStats = {0};
    
    for (int i = 0; i < self.gridSize * self.gridSize; i++) {
        switch (self.cityGrid[i]) {
            case TILE_HOUSE:
                newStats.houses++;
                break;
            case TILE_COMMERCIAL:
                newStats.commercial++;
                break;
            case TILE_INDUSTRIAL:
                newStats.industrial++;
                break;
            default:
                break;
        }
    }
    
    // Basic population and job calculations
    newStats.population = newStats.houses * 4;
    newStats.jobs = newStats.commercial * 6 + newStats.industrial * 10;
    newStats.happiness = 50 + (newStats.jobs > newStats.population ? 20 : -10);
    
    // Economic calculations based on our economic system
    newStats.cityFunds = 50000 + (newStats.houses * 1000) + (newStats.commercial * 2000) + (newStats.industrial * 1500);
    newStats.monthlyIncome = (newStats.houses * 45) + (newStats.commercial * 110) + (newStats.industrial * 80);
    newStats.monthlyExpenses = (newStats.houses * 15) + (newStats.commercial * 25) + (newStats.industrial * 35);
    
    // Tax rates from economic constants
    newStats.taxRateResidential = 9;
    newStats.taxRateCommercial = 11;
    newStats.taxRateIndustrial = 8;
    
    // Employment calculations
    newStats.populationEmployed = MIN(newStats.population, newStats.jobs);
    newStats.populationUnemployed = MAX(0, newStats.population - newStats.jobs);
    newStats.unemploymentRate = newStats.population > 0 ? (newStats.populationUnemployed * 100) / newStats.population : 0;
    
    // Land value calculation
    newStats.landValueAverage = 1000 + (newStats.houses * 200) + (newStats.commercial * 150) - (newStats.industrial * 50);
    
    // Economic indicator
    long long netIncome = newStats.monthlyIncome - newStats.monthlyExpenses;
    newStats.economicIndicator = (int)(netIncome / 50);
    newStats.economicIndicator = MAX(-100, MIN(100, newStats.economicIndicator));
    
    // RCI Demand calculations
    int totalBuildings = newStats.houses + newStats.commercial + newStats.industrial;
    if (totalBuildings > 0) {
        newStats.demandResidential = newStats.jobs > newStats.population ? 150 : 75;
        int expectedCommercial = newStats.houses / 4;
        newStats.demandCommercial = newStats.commercial < expectedCommercial ? 120 : 60;
        int expectedIndustrial = newStats.commercial / 3;
        newStats.demandIndustrial = newStats.industrial < expectedIndustrial ? 100 : 50;
    } else {
        newStats.demandResidential = 100;
        newStats.demandCommercial = 80;
        newStats.demandIndustrial = 60;
    }
    
    self.stats = newStats;
    
    // Update UI with comprehensive economic data
    NSString *statsText = [NSString stringWithFormat:
        @"💰 ECONOMIC CITY TEST\n"
        @"Population: %d (Employed: %d, Unemployed: %d)\n"
        @"Unemployment Rate: %d%% | Happiness: %d%%\n"
        @"💵 Funds: $%lld | Monthly: +$%lld -$%lld\n"
        @"🏠 Houses: %d | 🏢 Commercial: %d | 🏭 Industrial: %d\n"
        @"📊 RCI Demand: R:%d C:%d I:%d\n"
        @"💹 Economic Health: %d | Land Value: $%d\n"
        @"📈 Tax Rates: R:%d%% C:%d%% I:%d%%",
        self.stats.population, self.stats.populationEmployed, self.stats.populationUnemployed,
        self.stats.unemploymentRate, self.stats.happiness,
        self.stats.cityFunds, self.stats.monthlyIncome, self.stats.monthlyExpenses,
        self.stats.houses, self.stats.commercial, self.stats.industrial,
        self.stats.demandResidential, self.stats.demandCommercial, self.stats.demandIndustrial,
        self.stats.economicIndicator, self.stats.landValueAverage,
        self.stats.taxRateResidential, self.stats.taxRateCommercial, self.stats.taxRateIndustrial];
    
    self.statsLabel.stringValue = statsText;
}

- (void)setupInteraction {
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                                options:(NSTrackingActiveInKeyWindow | 
                                                                       NSTrackingMouseMoved |
                                                                       NSTrackingInVisibleRect)
                                                                  owner:self
                                                               userInfo:nil];
    [self addTrackingArea:trackingArea];
}

- (void)createUI {
    // Economic-focused UI
    self.statsLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, self.bounds.size.height - 140, 400, 120)];
    self.statsLabel.bezeled = NO;
    self.statsLabel.drawsBackground = YES;
    self.statsLabel.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.8];
    self.statsLabel.textColor = [NSColor whiteColor];
    self.statsLabel.editable = NO;
    self.statsLabel.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    [self addSubview:self.statsLabel];
    
    self.buildingTypeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 10, 300, 30)];
    self.buildingTypeLabel.bezeled = NO;
    self.buildingTypeLabel.drawsBackground = YES;
    self.buildingTypeLabel.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.8];
    self.buildingTypeLabel.textColor = [NSColor whiteColor];
    self.buildingTypeLabel.editable = NO;
    self.buildingTypeLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightBold];
    [self addSubview:self.buildingTypeLabel];
    
    [self updateBuildingTypeLabel];
}

- (void)updateBuildingTypeLabel {
    NSString *buildingName = @"";
    switch (self.currentBuildingType) {
        case TILE_HOUSE: buildingName = @"🏠 House"; break;
        case TILE_COMMERCIAL: buildingName = @"🏢 Commercial"; break;
        case TILE_INDUSTRIAL: buildingName = @"🏭 Industrial"; break;
        case TILE_PARK: buildingName = @"🌳 Park"; break;
        case TILE_ROAD: buildingName = @"🛣️ Road"; break;
        default: buildingName = @"Empty"; break;
    }
    
    self.buildingTypeLabel.stringValue = [NSString stringWithFormat:@"Building: %@ (1-5 to change)", buildingName];
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    
    float screenX = (locationInView.x / self.bounds.size.width) * 2.0f - 1.0f;
    float screenY = (locationInView.y / self.bounds.size.height) * 2.0f - 1.0f;
    
    float worldX = screenX / self.zoom + self.cameraX;
    float worldY = screenY / self.zoom + self.cameraY;
    
    float gridX = (worldX / 0.1f + worldY / 0.05f) / 2.0f;
    float gridY = (worldY / 0.05f - worldX / 0.1f) / 2.0f;
    
    int tileX = (int)roundf(gridX);
    int tileY = (int)roundf(gridY);
    
    if (tileX >= 0 && tileX < self.gridSize && tileY >= 0 && tileY < self.gridSize) {
        [self setTileAt:tileX y:tileY type:self.currentBuildingType];
        [self rebuildGeometry];
        [self updateStats];
        NSLog(@"🏗️ Economic test: Placed %d at (%d, %d)", self.currentBuildingType, tileX, tileY);
    }
}

- (void)keyDown:(NSEvent *)event {
    switch (event.keyCode) {
        case 18: // 1
            self.currentBuildingType = TILE_HOUSE;
            [self updateBuildingTypeLabel];
            break;
        case 19: // 2
            self.currentBuildingType = TILE_COMMERCIAL;
            [self updateBuildingTypeLabel];
            break;
        case 20: // 3
            self.currentBuildingType = TILE_INDUSTRIAL;
            [self updateBuildingTypeLabel];
            break;
        case 21: // 4
            self.currentBuildingType = TILE_PARK;
            [self updateBuildingTypeLabel];
            break;
        case 23: // 5
            self.currentBuildingType = TILE_ROAD;
            [self updateBuildingTypeLabel];
            break;
    }
}

- (void)drawInMTKView:(MTKView *)view {
    if (!self.pipelineState || !self.vertexBuffer) return;
    
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    
    if (renderPassDescriptor) {
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        
        [encoder setRenderPipelineState:self.pipelineState];
        [encoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
        
        struct {
            vector_float2 camera;
            float zoom;
        } uniforms = {
            .camera = {self.cameraX, self.cameraY},
            .zoom = self.zoom
        };
        
        [encoder setVertexBytes:&uniforms length:sizeof(uniforms) atIndex:1];
        if (self.spriteAtlas) {
            [encoder setFragmentTexture:self.spriteAtlas atIndex:0];
        }
        if (self.samplerState) {
            [encoder setFragmentSamplerState:self.samplerState atIndex:0];
        }
        
        NSUInteger indexCount = [self.indexBuffer length] / sizeof(uint16_t);
        [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                            indexCount:indexCount
                             indexType:MTLIndexTypeUInt16
                           indexBuffer:self.indexBuffer
                     indexBufferOffset:0];
        
        [encoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    
    [commandBuffer commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    self.statsLabel.frame = NSMakeRect(10, size.height - 140, 400, 120);
}

- (void)dealloc {
    if (self.cityGrid) {
        free(self.cityGrid);
    }
    if (self.buildingVariants) {
        free(self.buildingVariants);
    }
}

@end

@interface EconomicCityApp : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) EconomicCityTest *city;
@end

@implementation EconomicCityApp

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSLog(@"🚀 Launching Economic City Test!");
    
    NSRect frame = NSMakeRect(100, 100, 1200, 800);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled | 
                                                       NSWindowStyleMaskClosable | 
                                                       NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    [self.window setTitle:@"💰 SimCity ARM64 - Economic System Test"];
    
    self.city = [[EconomicCityTest alloc] initWithFrame:frame];
    [self.window setContentView:self.city];
    [self.window makeFirstResponder:self.city];
    
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    NSLog(@"✅ Economic city test launched!");
    NSLog(@"🎮 Controls:");
    NSLog(@"   • Left click: Place building");
    NSLog(@"   • Number keys 1-5: Change building type");
    NSLog(@"   • Watch economic indicators update in real-time");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"🎯 Economic City Test - ARM64 Assembly Economic System");
        
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        
        EconomicCityApp *delegate = [[EconomicCityApp alloc] init];
        [app setDelegate:delegate];
        
        [app run];
    }
    return 0;
}