#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>
#import "NetworkGraph.h"

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

// City statistics
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

@interface InteractiveCity : MTKView <MTKViewDelegate>
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLTexture> spriteAtlas;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> indexBuffer;
@property (nonatomic, strong) id<MTLSamplerState> samplerState;

// City data
@property (nonatomic, assign) CityTileType *cityGrid;
@property (nonatomic, assign) uint8_t *buildingVariants; // Store random variant for each tile
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

// Shadow system
@property (nonatomic, assign) float timeOfDay; // 0.0 to 24.0 hours
@property (nonatomic, assign) BOOL shadowsEnabled;

// Overlay system
typedef enum {
    OVERLAY_NONE = 0,
    OVERLAY_ZONES = 1,
    OVERLAY_POPULATION = 2,
    OVERLAY_TRAFFIC = 3,
    OVERLAY_HAPPINESS = 4
} OverlayMode;

@property (nonatomic, assign) OverlayMode currentOverlay;
@property (nonatomic, strong) id<MTLRenderPipelineState> overlayPipelineState;
@property (nonatomic, strong) id<MTLBuffer> overlayVertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> overlayIndexBuffer;

// Network and traffic system
@property (nonatomic, strong) NetworkGraph *networkGraph;
@property (nonatomic, assign) NSTimeInterval lastFrameTime;
@property (nonatomic, assign) BOOL networkVisualizationEnabled;

// UI
@property (nonatomic, strong) NSTextField *statsLabel;
@property (nonatomic, strong) NSTextField *buildingTypeLabel;
@property (nonatomic, strong) NSTextField *timeLabel;
@property (nonatomic, strong) NSButton *pauseButton;
@property (nonatomic, strong) NSButton *speedButton;
@property (nonatomic, strong) NSTextField *overlayLabel;
@end

@implementation InteractiveCity

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.gridSize = 30; // Larger city
        self.currentBuildingType = TILE_HOUSE;
        self.zoom = 1.0f;
        self.targetZoom = 1.0f;
        
        // Initialize shadow system
        self.timeOfDay = 12.0f; // Start at noon
        self.shadowsEnabled = YES;
        
        // Initialize overlay system
        self.currentOverlay = OVERLAY_NONE;
        
        // Initialize network system
        self.lastFrameTime = 0;
        self.networkVisualizationEnabled = YES;
        
        [self setupMetal];
        [self loadSpriteAtlas];
        [self createShaders];
        [self createOverlayShaders];
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
    
    NSLog(@"🎮 Interactive City - Metal initialized");
}

- (void)loadSpriteAtlas {
    NSString *atlasPath = @"assets/atlases/buildings.png";
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:atlasPath];
    
    if (!image) return;
    
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
    
    NSLog(@"✅ Interactive city atlas loaded");
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
    
    NSLog(@"✅ Interactive shaders ready");
}

- (void)createOverlayShaders {
    NSString *overlayShaderSource = @""
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
    "struct OverlayUniforms {\n"
    "    float2 camera;\n"
    "    float zoom;\n"
    "    int overlayMode;\n"
    "    float4 overlayColor;\n"
    "};\n"
    "\n"
    "vertex VertexOut overlay_vertex(VertexIn in [[stage_in]],\n"
    "                               constant OverlayUniforms& uniforms [[buffer(1)]]) {\n"
    "    VertexOut out;\n"
    "    float2 worldPos = (in.position - uniforms.camera) * uniforms.zoom;\n"
    "    out.position = float4(worldPos, 0.0, 1.0);\n"
    "    out.texCoord = in.texCoord;\n"
    "    return out;\n"
    "}\n"
    "\n"
    "fragment float4 overlay_fragment(VertexOut in [[stage_in]],\n"
    "                                constant OverlayUniforms& uniforms [[buffer(1)]]) {\n"
    "    // Create gradient overlay effect\n"
    "    float intensity = 0.5 + 0.3 * sin(in.texCoord.x * 3.14159) * cos(in.texCoord.y * 3.14159);\n"
    "    float4 color = uniforms.overlayColor;\n"
    "    color.a *= intensity;\n"
    "    return color;\n"
    "}\n";
    
    NSError *error = nil;
    id<MTLLibrary> overlayLibrary = [self.device newLibraryWithSource:overlayShaderSource options:nil error:&error];
    if (!overlayLibrary) {
        NSLog(@"❌ Overlay shader error: %@", error);
        return;
    }
    
    id<MTLFunction> overlayVertexFunc = [overlayLibrary newFunctionWithName:@"overlay_vertex"];
    id<MTLFunction> overlayFragFunc = [overlayLibrary newFunctionWithName:@"overlay_fragment"];
    
    MTLVertexDescriptor *overlayVertexDescriptor = [[MTLVertexDescriptor alloc] init];
    overlayVertexDescriptor.attributes[0].format = MTLVertexFormatFloat2;
    overlayVertexDescriptor.attributes[0].offset = 0;
    overlayVertexDescriptor.attributes[0].bufferIndex = 0;
    overlayVertexDescriptor.attributes[1].format = MTLVertexFormatFloat2;
    overlayVertexDescriptor.attributes[1].offset = 8;
    overlayVertexDescriptor.attributes[1].bufferIndex = 0;
    overlayVertexDescriptor.layouts[0].stride = sizeof(IsometricVertex);
    
    MTLRenderPipelineDescriptor *overlayDesc = [[MTLRenderPipelineDescriptor alloc] init];
    overlayDesc.vertexFunction = overlayVertexFunc;
    overlayDesc.fragmentFunction = overlayFragFunc;
    overlayDesc.vertexDescriptor = overlayVertexDescriptor;
    overlayDesc.colorAttachments[0].pixelFormat = self.colorPixelFormat;
    overlayDesc.colorAttachments[0].blendingEnabled = YES;
    overlayDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    overlayDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    
    self.overlayPipelineState = [self.device newRenderPipelineStateWithDescriptor:overlayDesc error:&error];
    if (error) {
        NSLog(@"❌ Overlay pipeline error: %@", error);
    } else {
        NSLog(@"✅ Overlay shaders ready");
    }
}

- (void)initializeCityData {
    int totalTiles = self.gridSize * self.gridSize;
    self.cityGrid = malloc(totalTiles * sizeof(CityTileType));
    self.buildingVariants = malloc(totalTiles * sizeof(uint8_t));
    
    // Initialize random seed
    srand48(time(NULL));
    
    // Create initial city with main roads
    for (int y = 0; y < self.gridSize; y++) {
        for (int x = 0; x < self.gridSize; x++) {
            int index = y * self.gridSize + x;
            
            // Main roads every 5 tiles
            if ((x % 5) == 0 || (y % 5) == 0) {
                self.cityGrid[index] = TILE_ROAD;
            } else {
                self.cityGrid[index] = TILE_EMPTY;
            }
            
            // Initialize random variants
            self.buildingVariants[index] = arc4random_uniform(4);
        }
    }
    
    // Add some starter buildings with random variants
    [self setTileAt:2 y:2 type:TILE_HOUSE];
    [self setTileAt:3 y:2 type:TILE_HOUSE];
    [self setTileAt:2 y:3 type:TILE_COMMERCIAL];
    [self setTileAt:7 y:7 type:TILE_INDUSTRIAL];
    
    // Initialize network graph with ARM64 backend
    [self initializeNetworkSystem];
    
    NSLog(@"✅ City data initialized: %dx%d", self.gridSize, self.gridSize);
}

- (void)initializeNetworkSystem {
    NSLog(@"🌐 Network system initialization placeholder (economic system active)");
}

- (BOOL)isIntersectionAtX:(int)x y:(int)y {
    if (![self hasRoadAt:x y:y]) return NO;
    
    // Count adjacent roads
    int connections = 0;
    if ([self hasRoadAt:x y:y-1]) connections++;
    if ([self hasRoadAt:x+1 y:y]) connections++;
    if ([self hasRoadAt:x y:y+1]) connections++;
    if ([self hasRoadAt:x-1 y:y]) connections++;
    
    return connections >= 3; // T-junction or 4-way intersection
}

- (void)createGeometry {
    [self rebuildGeometry];
}

- (void)rebuildGeometry {
    // First, collect all non-empty tiles with their depth order
    typedef struct {
        int x, y;
        CityTileType type;
        float depth;
    } TileInfo;
    
    int maxTiles = self.gridSize * self.gridSize;
    TileInfo *tiles = malloc(maxTiles * sizeof(TileInfo));
    int tileCount = 0;
    
    // Collect tiles
    for (int y = 0; y < self.gridSize; y++) {
        for (int x = 0; x < self.gridSize; x++) {
            int tileIndex = y * self.gridSize + x;
            CityTileType tileType = self.cityGrid[tileIndex];
            
            if (tileType == TILE_EMPTY) continue;
            
            // Enhanced depth calculation for proper building overlap
            // Factor in both position and height for proper sorting
            float baseDepth = (float)(x + y);
            float heightMultiplier = 0.0f;
            
            // Different height multipliers for building types
            switch (tileType) {
                case TILE_ROAD:
                    heightMultiplier = 0.0f;  // Ground level
                    break;
                case TILE_HOUSE:
                    heightMultiplier = 0.1f;  // Single story
                    break;
                case TILE_COMMERCIAL:
                    heightMultiplier = 0.3f;  // Multi-story
                    break;
                case TILE_INDUSTRIAL:
                    heightMultiplier = 0.5f;  // Tall structures
                    break;
                case TILE_PARK:
                    heightMultiplier = 0.05f; // Slightly elevated
                    break;
            }
            
            // Final depth includes base position plus height offset
            // Subtract height to ensure taller buildings are drawn last
            float depth = baseDepth - heightMultiplier;
            
            tiles[tileCount] = (TileInfo){x, y, tileType, depth};
            tileCount++;
        }
    }
    
    if (tileCount == 0) {
        free(tiles);
        return;
    }
    
    // Sort tiles by depth (back to front)
    for (int i = 0; i < tileCount - 1; i++) {
        for (int j = i + 1; j < tileCount; j++) {
            if (tiles[i].depth > tiles[j].depth) {
                TileInfo temp = tiles[i];
                tiles[i] = tiles[j];
                tiles[j] = temp;
            }
        }
    }
    
    // Count shadows (only buildings cast shadows, not roads) if shadows are enabled
    int shadowCount = 0;
    if (self.shadowsEnabled) {
        for (int i = 0; i < tileCount; i++) {
            if (tiles[i].type != TILE_ROAD && tiles[i].type != TILE_EMPTY) {
                shadowCount++;
            }
        }
    }
    
    // Count intersections for traffic light visualization
    int intersectionCount = 0;
    for (int i = 0; i < tileCount; i++) {
        if (tiles[i].type == TILE_ROAD && [self isIntersectionAtX:tiles[i].x y:tiles[i].y]) {
            intersectionCount++;
        }
    }
    
    // Now create geometry in sorted order (shadows first, then buildings, then traffic lights)
    // Each shadow, building, and traffic light needs 4 vertices and 6 indices
    int totalQuads = shadowCount + tileCount + (intersectionCount * 4); // 4 lights per intersection
    IsometricVertex *vertices = malloc(totalQuads * 4 * sizeof(IsometricVertex));
    uint16_t *indices = malloc(totalQuads * 6 * sizeof(uint16_t));
    
    int vertexIndex = 0;
    int indexIndex = 0;
    
    int quadIndex = 0;
    
    // First pass: Create shadows for buildings (if enabled)
    if (self.shadowsEnabled) {
        for (int i = 0; i < tileCount; i++) {
            TileInfo *tile = &tiles[i];
            
            // Skip roads and empty tiles for shadows
            if (tile->type == TILE_ROAD || tile->type == TILE_EMPTY) continue;
        
        // Time-based shadow calculation
        // Convert time of day to shadow angle (sun position)
        float sunAngle = (self.timeOfDay - 6.0f) * M_PI / 12.0f; // 6 AM to 6 PM = 0 to PI
        float shadowLength = 0.04f; // Base shadow length
        
        // Shadow length varies with time of day (longer at sunrise/sunset)
        float sunHeight = sinf(sunAngle);
        if (sunHeight > 0) {
            shadowLength *= (1.0f / fmaxf(sunHeight, 0.2f)); // Prevent division by zero
        } else {
            shadowLength = 0.0f; // No shadows at night
        }
        
        // Shadow direction based on sun position
        float shadowOffsetX = cosf(sunAngle) * shadowLength;
        float shadowOffsetY = -sinf(sunAngle) * shadowLength * 0.5f;
        
        // Isometric conversion for shadow
        float isoX = (tile->x - tile->y) * 0.1f + shadowOffsetX;
        float isoY = (tile->x + tile->y) * 0.05f + shadowOffsetY;
        
        float tileWidth = 0.08f;
        float tileHeight = 0.08f;
        
        // Use a dark semi-transparent color for shadow (using special UV coords)
        float u1 = 0.9375f; // Use a dark sprite area or shadow sprite
        float v1 = 0.9375f;
        float u2 = 1.0f;
        float v2 = 1.0f;
        
            // Create shadow quad (slightly skewed for perspective)
            vertices[vertexIndex + 0] = (IsometricVertex){{isoX - tileWidth * 0.8f, isoY - tileHeight * 0.6f}, {u1, v2}};
            vertices[vertexIndex + 1] = (IsometricVertex){{isoX + tileWidth * 0.8f, isoY - tileHeight * 0.6f}, {u2, v2}};
            vertices[vertexIndex + 2] = (IsometricVertex){{isoX + tileWidth * 0.8f, isoY + tileHeight * 0.6f}, {u2, v1}};
            vertices[vertexIndex + 3] = (IsometricVertex){{isoX - tileWidth * 0.8f, isoY + tileHeight * 0.6f}, {u1, v1}};
            
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
    
    // Second pass: Create actual buildings/roads
    for (int i = 0; i < tileCount; i++) {
        TileInfo *tile = &tiles[i];
        
        // Isometric conversion
        float isoX = (tile->x - tile->y) * 0.1f;
        float isoY = (tile->x + tile->y) * 0.05f;
        
        // Adjust height for building types (taller buildings need offset)
        float heightOffset = 0.0f;
        if (tile->type == TILE_COMMERCIAL) heightOffset = 0.02f;
        else if (tile->type == TILE_INDUSTRIAL) heightOffset = 0.03f;
        
        float tileWidth = 0.08f;
        float tileHeight = 0.08f;
        
        // Get UV coordinates
        float u1, v1, u2, v2;
        if (tile->type == TILE_ROAD) {
            [self getUVForRoadAt:tile->x y:tile->y u1:&u1 v1:&v1 u2:&u2 v2:&v2];
            
            // Modify UV coordinates for traffic visualization when network overlay is enabled
            if (self.currentOverlay == OVERLAY_TRAFFIC) {
                [self applyTrafficOverlayToRoadAt:tile->x y:tile->y u1:&u1 v1:&v1 u2:&u2 v2:&v2];
            }
        } else {
            [self getUVForTileType:tile->type x:tile->x y:tile->y u1:&u1 v1:&v1 u2:&u2 v2:&v2];
        }
        
        // Create quad with height offset
        vertices[vertexIndex + 0] = (IsometricVertex){{isoX - tileWidth, isoY - tileHeight + heightOffset}, {u1, v2}};
        vertices[vertexIndex + 1] = (IsometricVertex){{isoX + tileWidth, isoY - tileHeight + heightOffset}, {u2, v2}};
        vertices[vertexIndex + 2] = (IsometricVertex){{isoX + tileWidth, isoY + tileHeight + heightOffset}, {u2, v1}};
        vertices[vertexIndex + 3] = (IsometricVertex){{isoX - tileWidth, isoY + tileHeight + heightOffset}, {u1, v1}};
        
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
    
    self.vertexBuffer = [self.device newBufferWithBytes:vertices
                                                 length:(shadowCount + tileCount) * 4 * sizeof(IsometricVertex)
                                                options:MTLResourceStorageModeShared];
    
    self.indexBuffer = [self.device newBufferWithBytes:indices
                                                length:(shadowCount + tileCount) * 6 * sizeof(uint16_t)
                                               options:MTLResourceStorageModeShared];
    
    free(vertices);
    free(indices);
    free(tiles);
    
    // Rebuild overlay geometry if needed
    if (self.currentOverlay != OVERLAY_NONE) {
        [self rebuildOverlayGeometry];
    }
}

- (void)rebuildOverlayGeometry {
    if (self.currentOverlay == OVERLAY_NONE) {
        self.overlayVertexBuffer = nil;
        self.overlayIndexBuffer = nil;
        return;
    }
    
    // Create overlay quads for each non-empty tile
    int tileCount = 0;
    for (int i = 0; i < self.gridSize * self.gridSize; i++) {
        if (self.cityGrid[i] != TILE_EMPTY) {
            tileCount++;
        }
    }
    
    if (tileCount == 0) return;
    
    IsometricVertex *overlayVertices = malloc(tileCount * 4 * sizeof(IsometricVertex));
    uint16_t *overlayIndices = malloc(tileCount * 6 * sizeof(uint16_t));
    
    int vertexIndex = 0;
    int indexIndex = 0;
    int quadIndex = 0;
    
    for (int y = 0; y < self.gridSize; y++) {
        for (int x = 0; x < self.gridSize; x++) {
            int tileIndex = y * self.gridSize + x;
            CityTileType tileType = self.cityGrid[tileIndex];
            
            if (tileType == TILE_EMPTY) continue;
            
            // Isometric conversion
            float isoX = (x - y) * 0.1f;
            float isoY = (x + y) * 0.05f;
            
            float tileWidth = 0.08f;
            float tileHeight = 0.08f;
            
            // Create overlay quad slightly above the tile
            float overlayHeight = 0.005f;
            
            overlayVertices[vertexIndex + 0] = (IsometricVertex){{isoX - tileWidth, isoY - tileHeight + overlayHeight}, {0.0f, 1.0f}};
            overlayVertices[vertexIndex + 1] = (IsometricVertex){{isoX + tileWidth, isoY - tileHeight + overlayHeight}, {1.0f, 1.0f}};
            overlayVertices[vertexIndex + 2] = (IsometricVertex){{isoX + tileWidth, isoY + tileHeight + overlayHeight}, {1.0f, 0.0f}};
            overlayVertices[vertexIndex + 3] = (IsometricVertex){{isoX - tileWidth, isoY + tileHeight + overlayHeight}, {0.0f, 0.0f}};
            
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
                                                        length:tileCount * 4 * sizeof(IsometricVertex)
                                                       options:MTLResourceStorageModeShared];
    
    self.overlayIndexBuffer = [self.device newBufferWithBytes:overlayIndices
                                                       length:tileCount * 6 * sizeof(uint16_t)
                                                      options:MTLResourceStorageModeShared];
    
    free(overlayVertices);
    free(overlayIndices);
}

- (void)getUVForTileType:(CityTileType)tileType x:(int)x y:(int)y u1:(float*)u1 v1:(float*)v1 u2:(float*)u2 v2:(float*)v2 {
    // For roads, we need to determine which sprite to use based on neighbors
    if (tileType == TILE_ROAD) {
        [self getUVForRoadAt:x y:y u1:u1 v1:v1 u2:u2 v2:v2];
        return;
    }
    
    // Get the building variant for this tile
    int index = y * self.gridSize + x;
    uint8_t variant = self.buildingVariants[index];
    
    // Different sprites for each building type with variants
    float spriteSize = 0.0625f; // 256/4096
    int spriteIndex = 0;
    
    switch (tileType) {
        case TILE_HOUSE:
            // Houses use sprites 1-4 (4 variants)
            spriteIndex = 1 + (variant % 4);
            break;
        case TILE_COMMERCIAL:
            // Commercial buildings use sprites 5-8 (4 variants)
            spriteIndex = 5 + (variant % 4);
            break;
        case TILE_INDUSTRIAL: {
            // Industrial buildings animate and have 2 base variants
            int baseVariant = variant % 2;
            spriteIndex = 10 + (baseVariant * 4) + self.animationFrame; // Uses 10-13 or 14-17
            break;
        }
        case TILE_PARK:
            // Parks use sprites 20-23 (4 variants)
            spriteIndex = 20 + (variant % 4);
            break;
        default:
            spriteIndex = 0;
            break;
    }
    
    int row = spriteIndex / 16;
    int col = spriteIndex % 16;
    
    *u1 = col * spriteSize;
    *v1 = row * spriteSize;
    *u2 = *u1 + spriteSize;
    *v2 = *v1 + spriteSize;
}

- (void)getUVForRoadAt:(int)x y:(int)y u1:(float*)u1 v1:(float*)v1 u2:(float*)u2 v2:(float*)v2 {
    // Check all 8 neighbors for enhanced road auto-tiling
    BOOL hasNorth = [self hasRoadAt:x y:y-1];
    BOOL hasSouth = [self hasRoadAt:x y:y+1];
    BOOL hasEast = [self hasRoadAt:x+1 y:y];
    BOOL hasWest = [self hasRoadAt:x-1 y:y];
    
    // Check diagonal neighbors for smoother transitions
    BOOL hasNorthEast = [self hasRoadAt:x+1 y:y-1];
    BOOL hasNorthWest = [self hasRoadAt:x-1 y:y-1];
    BOOL hasSouthEast = [self hasRoadAt:x+1 y:y+1];
    BOOL hasSouthWest = [self hasRoadAt:x-1 y:y+1];
    
    // Determine road sprite based on connections
    int spriteIndex = 20; // Default straight road
    
    // Calculate main connection pattern (4-bit value)
    int connections = (hasNorth ? 1 : 0) | 
                     (hasEast ? 2 : 0) | 
                     (hasSouth ? 4 : 0) | 
                     (hasWest ? 8 : 0);
    
    // Enhanced mapping with diagonal support
    switch (connections) {
        case 0:  // Isolated road
            spriteIndex = 20;
            break;
        case 1:  // North only
            spriteIndex = 21;
            break;
        case 2:  // East only
            spriteIndex = 22;
            break;
        case 3:  // North-East corner
            // Check if we need a curved corner vs sharp corner
            spriteIndex = (hasNorthEast) ? 23 : 24; // Curved vs sharp corner
            break;
        case 4:  // South only
            spriteIndex = 21; // Reuse north sprite (rotated)
            break;
        case 5:  // North-South straight
            spriteIndex = 25;
            break;
        case 6:  // South-East corner
            spriteIndex = (hasSouthEast) ? 26 : 27;
            break;
        case 7:  // T-junction (no west)
            spriteIndex = 28;
            break;
        case 8:  // West only
            spriteIndex = 22; // Reuse east sprite
            break;
        case 9:  // North-West corner
            spriteIndex = (hasNorthWest) ? 29 : 30;
            break;
        case 10: // East-West straight
            spriteIndex = 31;
            break;
        case 11: // T-junction (no south)
            spriteIndex = 32;
            break;
        case 12: // South-West corner
            spriteIndex = (hasSouthWest) ? 33 : 34;
            break;
        case 13: // T-junction (no east)
            spriteIndex = 35;
            break;
        case 14: // T-junction (no north)
            spriteIndex = 36;
            break;
        case 15: { // Four-way intersection
            // Check diagonal connections for intersection type
            int diagonalCount = (hasNorthEast ? 1 : 0) + (hasNorthWest ? 1 : 0) + 
                               (hasSouthEast ? 1 : 0) + (hasSouthWest ? 1 : 0);
            spriteIndex = 37 + (diagonalCount > 2 ? 1 : 0); // Different intersection styles
            break;
        }
    }
    
    float spriteSize = 0.0625f;
    int row = spriteIndex / 16;
    int col = spriteIndex % 16;
    
    *u1 = col * spriteSize;
    *v1 = row * spriteSize;
    *u2 = *u1 + spriteSize;
    *v2 = *v1 + spriteSize;
}

- (BOOL)hasRoadAt:(int)x y:(int)y {
    if (x < 0 || x >= self.gridSize || y < 0 || y >= self.gridSize) {
        return NO;
    }
    int index = y * self.gridSize + x;
    return self.cityGrid[index] == TILE_ROAD;
}

- (void)applyTrafficOverlayToRoadAt:(int)x y:(int)y u1:(float*)u1 v1:(float*)v1 u2:(float*)u2 v2:(float*)v2 {
    if (!self.networkGraph || !self.networkGraph.isInitialized) {
        return;
    }
    
    // Get average traffic level from all adjacent road connections
    TrafficLevel maxTrafficLevel = TrafficLevelFree;
    int adjacentPositions[][2] = {{0, 1}, {1, 0}, {0, -1}, {-1, 0}};
    
    for (int i = 0; i < 4; i++) {
        int nx = x + adjacentPositions[i][0];
        int ny = y + adjacentPositions[i][1];
        
        if ([self hasRoadAt:nx y:ny]) {
            TrafficLevel trafficLevel = [self.networkGraph getTrafficLevelFromX:x fromY:y toX:nx toY:ny];
            if (trafficLevel > maxTrafficLevel) {
                maxTrafficLevel = trafficLevel;
            }
        }
    }
    
    // Modify UV coordinates based on traffic level
    // We'll use different sections of the sprite atlas for traffic colors
    float trafficOffsetV = 0.0f;
    
    switch (maxTrafficLevel) {
        case TrafficLevelFree:
            // Green tint - no offset
            trafficOffsetV = 0.0f;
            break;
        case TrafficLevelLight:
            // Yellow tint - offset by 1 sprite row
            trafficOffsetV = 0.0625f;
            break;
        case TrafficLevelMedium:
            // Orange tint - offset by 2 sprite rows
            trafficOffsetV = 0.125f;
            break;
        case TrafficLevelHeavy:
            // Red tint - offset by 3 sprite rows
            trafficOffsetV = 0.1875f;
            break;
        case TrafficLevelJammed:
            // Dark red tint - offset by 4 sprite rows
            trafficOffsetV = 0.25f;
            break;
        default:
            trafficOffsetV = 0.0f;
            break;
    }
    
    // Apply traffic color offset to V coordinates
    *v1 += trafficOffsetV;
    *v2 += trafficOffsetV;
    
    // Clamp UV coordinates to prevent overflow
    *v1 = fminf(*v1, 0.9375f);
    *v2 = fminf(*v2, 1.0f);
    
    // Add slight pulsing effect for jammed traffic
    if (maxTrafficLevel == TrafficLevelJammed) {
        float pulse = 0.5f + 0.5f * sinf(self.animationTime * 8.0f);
        *u1 += 0.001f * pulse;
        *u2 += 0.001f * pulse;
    }
}

- (void)addTrafficLightVisualizationAt:(float)isoX y:(float)isoY 
                              vertices:(IsometricVertex**)vertices 
                               indices:(uint16_t**)indices 
                           vertexIndex:(int*)vertexIndex 
                            indexIndex:(int*)indexIndex 
                             quadIndex:(int*)quadIndex 
                            tileCount:(int*)tileCount 
                           shadowCount:(int)shadowCount
                                gridX:(int)gridX 
                                gridY:(int)gridY {
    
    // Get intersection signal state
    SignalPhase signalPhase = [self.networkGraph getSignalPhaseForIntersectionAtX:gridX y:gridY];
    if (signalPhase < 0) return; // No intersection data
    
    // Traffic light positions (4 lights per intersection)
    float lightPositions[][2] = {
        {-0.06f, 0.0f},   // West light
        {0.06f, 0.0f},    // East light  
        {0.0f, -0.04f},   // North light
        {0.0f, 0.04f}     // South light
    };
    
    // Light colors based on signal phase
    float lightColors[][3] = {
        {1.0f, 0.0f, 0.0f}, // Red
        {1.0f, 1.0f, 0.0f}, // Yellow
        {0.0f, 1.0f, 0.0f}  // Green
    };
    
    // Determine which lights are active
    int lightStates[4] = {0, 0, 0, 0}; // 0=red, 1=yellow, 2=green
    
    switch (signalPhase) {
        case SignalPhaseNSGreen:
            lightStates[2] = 2; // North green
            lightStates[3] = 2; // South green
            lightStates[0] = 0; // West red
            lightStates[1] = 0; // East red
            break;
        case SignalPhaseNSYellow:
            lightStates[2] = 1; // North yellow
            lightStates[3] = 1; // South yellow
            lightStates[0] = 0; // West red
            lightStates[1] = 0; // East red
            break;
        case SignalPhaseEWGreen:
            lightStates[0] = 2; // West green
            lightStates[1] = 2; // East green
            lightStates[2] = 0; // North red
            lightStates[3] = 0; // South red
            break;
        case SignalPhaseEWYellow:
            lightStates[0] = 1; // West yellow
            lightStates[1] = 1; // East yellow
            lightStates[2] = 0; // North red
            lightStates[3] = 0; // South red
            break;
    }
    
    // Reallocate buffers to accommodate traffic lights
    int newTotalQuads = shadowCount + *tileCount + (4 * 1); // 4 lights for this intersection
    IsometricVertex *newVertices = realloc(*vertices, newTotalQuads * 4 * sizeof(IsometricVertex));
    uint16_t *newIndices = realloc(*indices, newTotalQuads * 6 * sizeof(uint16_t));
    
    if (!newVertices || !newIndices) {
        NSLog(@"❌ Failed to reallocate memory for traffic lights");
        return;
    }
    
    *vertices = newVertices;
    *indices = newIndices;
    
    // Add traffic light quads
    for (int i = 0; i < 4; i++) {
        float lightX = isoX + lightPositions[i][0];
        float lightY = isoY + lightPositions[i][1];
        float lightZ = 0.08f; // Above the road surface
        
        // Small light quad
        float lightSize = 0.01f;
        
        // Get UV coordinates for traffic light sprite based on color
        float u1 = 0.875f + (lightStates[i] * 0.03125f); // Traffic light sprites at end of atlas
        float v1 = 0.875f;
        float u2 = u1 + 0.03125f;
        float v2 = v1 + 0.03125f;
        
        // Create small light quad
        (*vertices)[*vertexIndex + 0] = (IsometricVertex){{lightX - lightSize, lightY - lightSize + lightZ}, {u1, v2}};
        (*vertices)[*vertexIndex + 1] = (IsometricVertex){{lightX + lightSize, lightY - lightSize + lightZ}, {u2, v2}};
        (*vertices)[*vertexIndex + 2] = (IsometricVertex){{lightX + lightSize, lightY + lightSize + lightZ}, {u2, v1}};
        (*vertices)[*vertexIndex + 3] = (IsometricVertex){{lightX - lightSize, lightY + lightSize + lightZ}, {u1, v1}};
        
        uint16_t baseVertex = *quadIndex * 4;
        (*indices)[*indexIndex + 0] = baseVertex + 0;
        (*indices)[*indexIndex + 1] = baseVertex + 1;
        (*indices)[*indexIndex + 2] = baseVertex + 2;
        (*indices)[*indexIndex + 3] = baseVertex + 2;
        (*indices)[*indexIndex + 4] = baseVertex + 3;
        (*indices)[*indexIndex + 5] = baseVertex + 0;
        
        *vertexIndex += 4;
        *indexIndex += 6;
        (*quadIndex)++;
    }
    
    (*tileCount)++; // Account for the additional quads
}

- (void)setupInteraction {
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                                options:(NSTrackingActiveInKeyWindow | 
                                                                       NSTrackingMouseMoved |
                                                                       NSTrackingInVisibleRect)
                                                                  owner:self
                                                               userInfo:nil];
    [self addTrackingArea:trackingArea];
    
    NSLog(@"✅ Mouse and keyboard controls enabled");
}

- (void)createUI {
    // Stats label
    self.statsLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, self.bounds.size.height - 100, 300, 80)];
    self.statsLabel.bezeled = NO;
    self.statsLabel.drawsBackground = YES;
    self.statsLabel.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.7];
    self.statsLabel.textColor = [NSColor whiteColor];
    self.statsLabel.editable = NO;
    self.statsLabel.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    [self addSubview:self.statsLabel];
    
    // Building type label
    self.buildingTypeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 10, 300, 30)];
    self.buildingTypeLabel.bezeled = NO;
    self.buildingTypeLabel.drawsBackground = YES;
    self.buildingTypeLabel.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.7];
    self.buildingTypeLabel.textColor = [NSColor whiteColor];
    self.buildingTypeLabel.editable = NO;
    self.buildingTypeLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightBold];
    [self addSubview:self.buildingTypeLabel];
    
    // Overlay control label
    self.overlayLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 50, 400, 60)];
    self.overlayLabel.bezeled = NO;
    self.overlayLabel.drawsBackground = YES;
    self.overlayLabel.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.7];
    self.overlayLabel.textColor = [NSColor whiteColor];
    self.overlayLabel.editable = NO;
    self.overlayLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    [self addSubview:self.overlayLabel];
    
    // Time display label
    self.timeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(self.bounds.size.width - 320, self.bounds.size.height - 60, 300, 50)];
    self.timeLabel.bezeled = NO;
    self.timeLabel.drawsBackground = YES;
    self.timeLabel.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.7];
    self.timeLabel.textColor = [NSColor whiteColor];
    self.timeLabel.editable = NO;
    self.timeLabel.font = [NSFont monospacedSystemFontOfSize:14 weight:NSFontWeightBold];
    self.timeLabel.alignment = NSTextAlignmentRight;
    [self addSubview:self.timeLabel];
    
    // Pause/Play button
    self.pauseButton = [[NSButton alloc] initWithFrame:NSMakeRect(self.bounds.size.width - 140, self.bounds.size.height - 100, 60, 30)];
    [self.pauseButton setTitle:@"⏸️"];
    [self.pauseButton setBezelStyle:NSBezelStyleRounded];
    [self.pauseButton setTarget:self];
    [self.pauseButton setAction:@selector(togglePause:)];
    [self addSubview:self.pauseButton];
    
    // Speed control button
    self.speedButton = [[NSButton alloc] initWithFrame:NSMakeRect(self.bounds.size.width - 70, self.bounds.size.height - 100, 60, 30)];
    [self.speedButton setTitle:@"1x"];
    [self.speedButton setBezelStyle:NSBezelStyleRounded];
    [self.speedButton setTarget:self];
    [self.speedButton setAction:@selector(cycleSpeed:)];
    [self addSubview:self.speedButton];
    
    [self updateBuildingTypeLabel];
    [self updateOverlayLabel];
    [self updateTimeDisplay];
}

- (void)updateStats {
    // Calculate city statistics
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
    newStats.population = newStats.houses * 4; // 4 people per house
    newStats.jobs = newStats.commercial * 6 + newStats.industrial * 10;
    newStats.happiness = 50 + (newStats.jobs > newStats.population ? 20 : -10);
    
    // Economic calculations
    newStats.cityFunds = 50000 + (newStats.houses * 1000) + (newStats.commercial * 2000) + (newStats.industrial * 1500); // Simplified funding
    newStats.monthlyIncome = (newStats.houses * 45) + (newStats.commercial * 110) + (newStats.industrial * 80); // Tax income
    newStats.monthlyExpenses = (newStats.houses * 15) + (newStats.commercial * 25) + (newStats.industrial * 35); // Service costs
    
    // Tax rates (default values)
    newStats.taxRateResidential = 9;
    newStats.taxRateCommercial = 11;
    newStats.taxRateIndustrial = 8;
    
    // Population employment
    newStats.populationEmployed = MIN(newStats.population, newStats.jobs);
    newStats.populationUnemployed = MAX(0, newStats.population - newStats.jobs);
    newStats.unemploymentRate = newStats.population > 0 ? (newStats.populationUnemployed * 100) / newStats.population : 0;
    
    // Land value (simplified)
    newStats.landValueAverage = 1000 + (newStats.houses * 200) + (newStats.commercial * 150) - (newStats.industrial * 50);
    
    // Economic indicator (-100 to +100)
    long long netIncome = newStats.monthlyIncome - newStats.monthlyExpenses;
    newStats.economicIndicator = (int)(netIncome / 50); // Scale to indicator range
    newStats.economicIndicator = MAX(-100, MIN(100, newStats.economicIndicator));
    
    // RCI Demand (simplified demand calculation)
    int totalBuildings = newStats.houses + newStats.commercial + newStats.industrial;
    if (totalBuildings > 0) {
        // Residential demand increases if jobs > population
        newStats.demandResidential = newStats.jobs > newStats.population ? 150 : 75;
        
        // Commercial demand based on population/residential ratio
        int expectedCommercial = newStats.houses / 4; // 1 commercial per 4 residential
        newStats.demandCommercial = newStats.commercial < expectedCommercial ? 120 : 60;
        
        // Industrial demand based on commercial needs
        int expectedIndustrial = newStats.commercial / 3; // 1 industrial per 3 commercial
        newStats.demandIndustrial = newStats.industrial < expectedIndustrial ? 100 : 50;
    } else {
        newStats.demandResidential = 100;
        newStats.demandCommercial = 80;
        newStats.demandIndustrial = 60;
    }
    
    self.stats = newStats;
    
    // Get network performance metrics
    NSString *networkStats = @"";
    if (self.networkGraph && self.networkGraph.isInitialized) {
        double avgUpdateTime = [self.networkGraph getAverageUpdateTimeMs];
        double avgTrafficDensity = [self.networkGraph getAverageTrafficDensity];
        int totalNodes = [self.networkGraph getTotalNodes];
        int totalEdges = [self.networkGraph getTotalEdges];
        int totalIntersections = [self.networkGraph getTotalIntersections];
        
        networkStats = [NSString stringWithFormat:
            @"\n🌐 NETWORK PERFORMANCE\n"
            @"Nodes: %d | Edges: %d | Intersections: %d\n"
            @"Update Time: %.2fms | Traffic Density: %.1f",
            totalNodes, totalEdges, totalIntersections,
            avgUpdateTime, avgTrafficDensity];
    }
    
    // Update UI with expanded information including network stats
    NSString *statsText = [NSString stringWithFormat:
        @"🏙️ CITY STATISTICS\n"
        @"Population: %d (Employed: %d, Unemployed: %d)\n"
        @"Unemployment Rate: %d%%\n"
        @"Jobs: %d | Happiness: %d%%\n"
        @"💰 Funds: $%lld | Monthly: +$%lld -$%lld\n"
        @"🏠 Houses: %d | 🏢 Commercial: %d | 🏭 Industrial: %d\n"
        @"📊 RCI Demand: R:%d C:%d I:%d\n"
        @"📈 Economic Indicator: %d | Land Value: $%d%@",
        self.stats.population, self.stats.populationEmployed, self.stats.populationUnemployed,
        self.stats.unemploymentRate,
        self.stats.jobs, self.stats.happiness,
        self.stats.cityFunds, self.stats.monthlyIncome, self.stats.monthlyExpenses,
        self.stats.houses, self.stats.commercial, self.stats.industrial,
        self.stats.demandResidential, self.stats.demandCommercial, self.stats.demandIndustrial,
        self.stats.economicIndicator, self.stats.landValueAverage, networkStats];
    
    self.statsLabel.stringValue = statsText;
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

- (void)updateOverlayLabel {
    NSString *overlayName = @"";
    switch (self.currentOverlay) {
        case OVERLAY_NONE: overlayName = @"None"; break;
        case OVERLAY_ZONES: overlayName = @"Zones (RCI)"; break;
        case OVERLAY_POPULATION: overlayName = @"Population Density"; break;
        case OVERLAY_TRAFFIC: overlayName = @"Traffic Flow"; break;
        case OVERLAY_HAPPINESS: overlayName = @"Happiness Level"; break;
    }
    
    float timeHour = (int)self.timeOfDay % 24;
    float timeMinute = (self.timeOfDay - timeHour) * 60;
    
    self.overlayLabel.stringValue = [NSString stringWithFormat:
        @"Overlay: %@ (F1-F4 to change)\n"
        @"Time: %02.0f:%02.0f | Shadows: %@ (F5 toggle)\n"
        @"Press F6 to advance time",
        overlayName,
        timeHour, timeMinute,
        self.shadowsEnabled ? @"ON" : @"OFF"];
}

// Time Control Methods

- (void)updateTimeDisplay {
    // This method would need to call into the C time system
    // For now, using placeholder values
    static int gameYear = 2000;
    static int gameMonth = 1;
    static int gameDay = 1;
    static int gameHour = 8;
    static int gameMinute = 0;
    static const char* months[] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
    static const char* seasons[] = {"Winter", "Spring", "Summer", "Fall"};
    
    // Determine season based on month (simplified)
    int season = (gameMonth - 1) / 3; // 0=Winter, 1=Spring, 2=Summer, 3=Fall
    if (season > 3) season = 3;
    
    // Get current speed setting
    const char* speedNames[] = {"⏸️", "1x", "2x", "3x", "10x", "50x", "100x", "🚀"};
    static int currentSpeedIndex = 1; // Start at normal speed
    
    NSString *timeString = [NSString stringWithFormat:
        @"📅 %s %d, %d\n"
        @"⏰ %02d:%02d\n"
        @"🌿 %s | %s",
        months[gameMonth-1], gameDay, gameYear,
        gameHour, gameMinute,
        seasons[season], speedNames[currentSpeedIndex]];
    
    self.timeLabel.stringValue = timeString;
    
    // Update button labels based on current state
    if (currentSpeedIndex == 0) {
        [self.pauseButton setTitle:@"▶️"];
        [self.speedButton setTitle:@"⏸️"];
    } else {
        [self.pauseButton setTitle:@"⏸️"];
        [self.speedButton setTitle:[NSString stringWithFormat:@"%s", speedNames[currentSpeedIndex]]];
    }
}

- (void)togglePause:(id)sender {
    // Call the simulation pause toggle function
    // extern void simulation_pause_toggle(void);
    // simulation_pause_toggle();
    
    NSLog(@"🎮 Time control: Pause toggled");
    [self updateTimeDisplay];
}

- (void)cycleSpeed:(id)sender {
    // Call the simulation speed increase function  
    // extern void simulation_speed_increase(void);
    // simulation_speed_increase();
    
    NSLog(@"🎮 Time control: Speed cycled");
    [self updateTimeDisplay];
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    
    // Convert screen to world coordinates
    float screenX = (locationInView.x / self.bounds.size.width) * 2.0f - 1.0f;
    float screenY = (locationInView.y / self.bounds.size.height) * 2.0f - 1.0f;
    
    float worldX = screenX / self.zoom + self.cameraX;
    float worldY = screenY / self.zoom + self.cameraY;
    
    // Convert world to grid coordinates (inverse isometric)
    float gridX = (worldX / 0.1f + worldY / 0.05f) / 2.0f;
    float gridY = (worldY / 0.05f - worldX / 0.1f) / 2.0f;
    
    int tileX = (int)roundf(gridX);
    int tileY = (int)roundf(gridY);
    
    if (tileX >= 0 && tileX < self.gridSize && tileY >= 0 && tileY < self.gridSize) {
        [self setTileAt:tileX y:tileY type:self.currentBuildingType];
        [self rebuildGeometry];
        [self updateStats];
        NSLog(@"🏗️ Placed %d at (%d, %d)", self.currentBuildingType, tileX, tileY);
    }
}

- (void)rightMouseDown:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    
    // Same coordinate conversion
    float screenX = (locationInView.x / self.bounds.size.width) * 2.0f - 1.0f;
    float screenY = (locationInView.y / self.bounds.size.height) * 2.0f - 1.0f;
    
    float worldX = screenX / self.zoom + self.cameraX;
    float worldY = screenY / self.zoom + self.cameraY;
    
    float gridX = (worldX / 0.1f + worldY / 0.05f) / 2.0f;
    float gridY = (worldY / 0.05f - worldX / 0.1f) / 2.0f;
    
    int tileX = (int)roundf(gridX);
    int tileY = (int)roundf(gridY);
    
    if (tileX >= 0 && tileX < self.gridSize && tileY >= 0 && tileY < self.gridSize) {
        // If we're holding option key, use this for pathfinding destination
        if (event.modifierFlags & NSEventModifierFlagOption) {
            static int pathfindingStartX = -1, pathfindingStartY = -1;
            
            if (pathfindingStartX < 0 || pathfindingStartY < 0) {
                // Set start point
                pathfindingStartX = tileX;
                pathfindingStartY = tileY;
                NSLog(@"🗺️ Pathfinding start set to (%d, %d)", tileX, tileY);
            } else {
                // Find path from start to current position
                [self findAndDisplayPathFrom:pathfindingStartX startY:pathfindingStartY 
                                        toX:tileX toY:tileY];
                // Reset for next pathfinding
                pathfindingStartX = -1;
                pathfindingStartY = -1;
            }
        } else {
            // Normal tile removal
            [self setTileAt:tileX y:tileY type:TILE_EMPTY];
            [self rebuildGeometry];
            [self updateStats];
            NSLog(@"🗑️ Removed tile at (%d, %d)", tileX, tileY);
        }
    }
}

- (void)setTileAt:(int)x y:(int)y type:(CityTileType)type {
    if (x >= 0 && x < self.gridSize && y >= 0 && y < self.gridSize) {
        CityTileType oldType = self.cityGrid[y * self.gridSize + x];
        self.cityGrid[y * self.gridSize + x] = type;
        
        // Update network system when roads are modified
        if (self.networkGraph && self.networkGraph.isInitialized) {
            [self updateNetworkForTileChangeAt:x y:y oldType:oldType newType:type];
        }
    }
}

- (void)updateNetworkForTileChangeAt:(int)x y:(int)y oldType:(CityTileType)oldType newType:(CityTileType)newType {
    // If we're removing a road, we should ideally remove the network node
    // For now, we'll just log the change and let the next full rebuild handle it
    if (oldType == TILE_ROAD && newType != TILE_ROAD) {
        NSLog(@"🚧 Road removed at (%d, %d) - network will rebuild on next update", x, y);
    }
    
    // If we're adding a road, add it to the network
    if (oldType != TILE_ROAD && newType == TILE_ROAD) {
        NSLog(@"🛣️ Road added at (%d, %d) - updating network...", x, y);
        
        // Add network node for new road
        RoadType roadType = RoadTypeResidential;
        int capacity = 100;
        
        // Main roads have different properties
        if ((x % 5) == 0 || (y % 5) == 0) {
            roadType = RoadTypeCommercial;
            capacity = 200;
        }
        
        int nodeId = [self.networkGraph addNodeAtX:x y:y roadType:roadType capacity:capacity];
        
        // Check if this creates new intersections
        if ([self isIntersectionAtX:x y:y]) {
            int intersectionType = 2; // Default 4-way
            int connections = 0;
            if ([self hasRoadAt:x y:y-1]) connections++;
            if ([self hasRoadAt:x+1 y:y]) connections++;
            if ([self hasRoadAt:x y:y+1]) connections++;
            if ([self hasRoadAt:x-1 y:y]) connections++;
            
            if (connections == 3) intersectionType = 1;
            else if (connections == 2) intersectionType = 0;
            
            int intersectionId = [self.networkGraph addIntersectionAtX:x y:y type:intersectionType];
            if (intersectionId >= 0 && nodeId >= 0) {
                [self.networkGraph connectIntersection:intersectionId fromNodeId:nodeId toNodeId:nodeId];
            }
        }
        
        // Connect to adjacent roads
        int directions[][2] = {{0, 1}, {1, 0}, {0, -1}, {-1, 0}};
        for (int i = 0; i < 4; i++) {
            int nx = x + directions[i][0];
            int ny = y + directions[i][1];
            
            if ([self hasRoadAt:nx y:ny]) {
                int weight = 10;
                int capacity = 50;
                
                if (((x % 5) == 0 || (y % 5) == 0) && ((nx % 5) == 0 || (ny % 5) == 0)) {
                    weight = 5;
                    capacity = 100;
                }
                
                [self.networkGraph connectGridPositionFromX:x fromY:y toX:nx toY:ny weight:weight capacity:capacity];
                [self.networkGraph connectGridPositionFromX:nx fromY:ny toX:x toY:y weight:weight capacity:capacity];
            }
        }
        
        NSLog(@"✅ Network updated for new road at (%d, %d)", x, y);
    }
}

- (void)findAndDisplayPathFrom:(int)startX startY:(int)startY toX:(int)endX toY:(int)endY {
    if (!self.networkGraph || !self.networkGraph.isInitialized) {
        NSLog(@"❌ Network not initialized for pathfinding");
        return;
    }
    
    // Check if both points are on roads
    if (![self hasRoadAt:startX y:startY] || ![self hasRoadAt:endX y:endY]) {
        NSLog(@"❌ Pathfinding requires both start and end points to be on roads");
        return;
    }
    
    NSLog(@"🗺️ Finding path from (%d, %d) to (%d, %d)...", startX, startY, endX, endY);
    
    // Use ARM64 pathfinding algorithm
    NSArray<NSValue *> *path = [self.networkGraph findPathFromX:startX startY:startY toX:endX toY:endY];
    
    if (path && path.count > 0) {
        long distance = [self.networkGraph calculatePathDistance:path];
        
        NSLog(@"✅ Path found with distance: %ld", distance);
        NSLog(@"📍 Path points:");
        for (NSValue *pointValue in path) {
            NSPoint point = [pointValue pointValue];
            NSLog(@"   -> (%.0f, %.0f)", point.x, point.y);
        }
        
        // Analyze path for traffic conditions
        [self analyzePathTrafficConditions:path];
        
        // Show path performance metrics
        double avgTrafficDensity = [self.networkGraph getAverageTrafficDensity];
        double updateTime = [self.networkGraph getAverageUpdateTimeMs];
        
        NSLog(@"📊 Network Performance:");
        NSLog(@"   • Average update time: %.2f ms", updateTime);
        NSLog(@"   • Average traffic density: %.1f", avgTrafficDensity);
        NSLog(@"   • Total network nodes: %d", [self.networkGraph getTotalNodes]);
        NSLog(@"   • Total network edges: %d", [self.networkGraph getTotalEdges]);
        
    } else {
        NSLog(@"❌ No path found between (%d, %d) and (%d, %d)", startX, startY, endX, endY);
    }
}

- (void)analyzePathTrafficConditions:(NSArray<NSValue *> *)path {
    if (path.count < 2) return;
    
    NSLog(@"🚦 Path Traffic Analysis:");
    
    int trafficCounts[5] = {0}; // Count of each traffic level
    
    for (NSUInteger i = 0; i < path.count - 1; i++) {
        NSPoint from = [path[i] pointValue];
        NSPoint to = [path[i + 1] pointValue];
        
        TrafficLevel traffic = [self.networkGraph getTrafficLevelFromX:(int)from.x 
                                                                 fromY:(int)from.y 
                                                                   toX:(int)to.x 
                                                                   toY:(int)to.y];
        
        if (traffic >= 0 && traffic <= 4) {
            trafficCounts[traffic]++;
        }
        
        NSString *trafficDesc = @"Unknown";
        switch (traffic) {
            case TrafficLevelFree: trafficDesc = @"Free"; break;
            case TrafficLevelLight: trafficDesc = @"Light"; break;
            case TrafficLevelMedium: trafficDesc = @"Medium"; break;
            case TrafficLevelHeavy: trafficDesc = @"Heavy"; break;
            case TrafficLevelJammed: trafficDesc = @"Jammed"; break;
        }
        
        NSLog(@"   • (%.0f,%.0f) -> (%.0f,%.0f): %@", from.x, from.y, to.x, to.y, trafficDesc);
    }
    
    NSLog(@"📈 Traffic Summary:");
    NSLog(@"   • Free: %d segments", trafficCounts[0]);
    NSLog(@"   • Light: %d segments", trafficCounts[1]);
    NSLog(@"   • Medium: %d segments", trafficCounts[2]);
    NSLog(@"   • Heavy: %d segments", trafficCounts[3]);
    NSLog(@"   • Jammed: %d segments", trafficCounts[4]);
    
    // Calculate overall path condition
    int totalSegments = (int)(path.count - 1);
    if (totalSegments > 0) {
        float avgTrafficLevel = (trafficCounts[1] * 1.0f + trafficCounts[2] * 2.0f + 
                                trafficCounts[3] * 3.0f + trafficCounts[4] * 4.0f) / totalSegments;
        
        NSString *overallCondition = @"Excellent";
        if (avgTrafficLevel > 3.0f) overallCondition = @"Poor";
        else if (avgTrafficLevel > 2.0f) overallCondition = @"Moderate";
        else if (avgTrafficLevel > 1.0f) overallCondition = @"Good";
        
        NSLog(@"🎯 Overall Path Condition: %@ (%.1f/4.0)", overallCondition, avgTrafficLevel);
    }
}

- (void)mouseDragged:(NSEvent *)event {
    self.targetCameraX -= event.deltaX * 0.01f / self.zoom;
    self.targetCameraY += event.deltaY * 0.01f / self.zoom;
}

- (void)scrollWheel:(NSEvent *)event {
    self.targetZoom *= (1.0f + event.deltaY * 0.1f);
    self.targetZoom = fmaxf(0.3f, fminf(3.0f, self.targetZoom));
}

- (void)keyDown:(NSEvent *)event {
    float moveSpeed = 0.05f / self.zoom;
    
    switch (event.keyCode) {
        case 0: // A
            self.targetCameraX -= moveSpeed;
            break;
        case 2: // D
            self.targetCameraX += moveSpeed;
            break;
        case 13: // W
            self.targetCameraY += moveSpeed;
            break;
        case 1: // S
            self.targetCameraY -= moveSpeed;
            break;
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
        case 122: // F1
            self.currentOverlay = OVERLAY_ZONES;
            [self updateOverlayLabel];
            [self rebuildGeometry];
            break;
        case 120: // F2
            self.currentOverlay = OVERLAY_POPULATION;
            [self updateOverlayLabel];
            [self rebuildGeometry];
            break;
        case 99: // F3
            self.currentOverlay = OVERLAY_TRAFFIC;
            [self updateOverlayLabel];
            [self rebuildGeometry];
            break;
        case 118: // F4
            self.currentOverlay = OVERLAY_HAPPINESS;
            [self updateOverlayLabel];
            [self rebuildGeometry];
            break;
        case 96: // F5 - Toggle shadows
            self.shadowsEnabled = !self.shadowsEnabled;
            [self updateOverlayLabel];
            [self rebuildGeometry];
            break;
        case 97: // F6 - Advance time
            self.timeOfDay += 1.0f;
            if (self.timeOfDay >= 24.0f) self.timeOfDay = 0.0f;
            [self updateOverlayLabel];
            [self rebuildGeometry];
            break;
        case 98: // F7 - Toggle overlay off
            self.currentOverlay = OVERLAY_NONE;
            [self updateOverlayLabel];
            [self rebuildGeometry];
            break;
        case 100: // F8 - Show detailed network performance
            [self showDetailedNetworkPerformance];
            break;
    }
}

- (void)drawInMTKView:(MTKView *)view {
    // Calculate frame time for network updates
    NSTimeInterval currentTime = CACurrentMediaTime();
    NSTimeInterval deltaTime = currentTime - self.lastFrameTime;
    if (self.lastFrameTime == 0) deltaTime = 1.0/60.0; // First frame
    self.lastFrameTime = currentTime;
    
    // Update network traffic simulation
    if (self.networkGraph && self.networkGraph.isInitialized) {
        [self.networkGraph updateTrafficSimulation:deltaTime];
    }
    
    // Smooth camera movement
    float smoothing = 0.1f;
    self.cameraX += (self.targetCameraX - self.cameraX) * smoothing;
    self.cameraY += (self.targetCameraY - self.cameraY) * smoothing;
    self.zoom += (self.targetZoom - self.zoom) * smoothing;
    
    // Update animation
    self.animationTime += 1.0f/60.0f; // 60 FPS
    int newFrame = ((int)(self.animationTime * 4.0f)) % 4; // 4 frames per second
    if (newFrame != self.animationFrame) {
        self.animationFrame = newFrame;
        [self rebuildGeometry]; // Rebuild to update animated sprites
    }
    
    if (!self.pipelineState || !self.spriteAtlas || !self.vertexBuffer) return;
    
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
        [encoder setFragmentTexture:self.spriteAtlas atIndex:0];
        [encoder setFragmentSamplerState:self.samplerState atIndex:0];
        
        NSUInteger indexCount = [self.indexBuffer length] / sizeof(uint16_t);
        [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                            indexCount:indexCount
                             indexType:MTLIndexTypeUInt16
                           indexBuffer:self.indexBuffer
                     indexBufferOffset:0];
        
        // Render overlays if enabled
        if (self.currentOverlay != OVERLAY_NONE && self.overlayPipelineState && self.overlayVertexBuffer && self.overlayIndexBuffer) {
            [encoder setRenderPipelineState:self.overlayPipelineState];
            [encoder setVertexBuffer:self.overlayVertexBuffer offset:0 atIndex:0];
            
            // Set overlay uniforms
            struct {
                vector_float2 camera;
                float zoom;
                int overlayMode;
                vector_float4 overlayColor;
            } overlayUniforms;
            
            overlayUniforms.camera = (vector_float2){self.cameraX, self.cameraY};
            overlayUniforms.zoom = self.zoom;
            overlayUniforms.overlayMode = (int)self.currentOverlay;
            
            // Set overlay color based on mode
            switch (self.currentOverlay) {
                case OVERLAY_ZONES:
                    overlayUniforms.overlayColor = (vector_float4){0.2f, 0.8f, 0.2f, 0.3f}; // Green for zones
                    break;
                case OVERLAY_POPULATION:
                    overlayUniforms.overlayColor = (vector_float4){0.8f, 0.2f, 0.2f, 0.4f}; // Red for population
                    break;
                case OVERLAY_TRAFFIC:
                    overlayUniforms.overlayColor = (vector_float4){0.2f, 0.2f, 0.8f, 0.35f}; // Blue for traffic
                    break;
                case OVERLAY_HAPPINESS:
                    overlayUniforms.overlayColor = (vector_float4){0.8f, 0.8f, 0.2f, 0.3f}; // Yellow for happiness
                    break;
                default:
                    overlayUniforms.overlayColor = (vector_float4){0.5f, 0.5f, 0.5f, 0.2f};
                    break;
            }
            
            [encoder setVertexBytes:&overlayUniforms length:sizeof(overlayUniforms) atIndex:1];
            [encoder setFragmentBytes:&overlayUniforms length:sizeof(overlayUniforms) atIndex:1];
            
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

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Update UI positions
    self.statsLabel.frame = NSMakeRect(10, size.height - 100, 300, 80);
}

- (void)takeScreenshot:(id)sender {
    // Create screenshots directory if it doesn't exist
    NSString *projectPath = [[NSFileManager defaultManager] currentDirectoryPath];
    NSString *screenshotsPath = [projectPath stringByAppendingPathComponent:@"screenshots"];
    
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:screenshotsPath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    
    if (error) {
        NSLog(@"❌ Failed to create screenshots directory: %@", error);
        return;
    }
    
    // Get the current drawable texture from Metal
    id<CAMetalDrawable> drawable = self.currentDrawable;
    if (!drawable) {
        NSLog(@"❌ No drawable available for screenshot");
        return;
    }
    
    id<MTLTexture> texture = drawable.texture;
    
    // Calculate texture size
    NSUInteger width = texture.width;
    NSUInteger height = texture.height;
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = width * bytesPerPixel;
    NSUInteger imageByteCount = height * bytesPerRow;
    
    // Allocate memory for pixel data
    void *imageBytes = malloc(imageByteCount);
    
    // Copy texture data to CPU
    [texture getBytes:imageBytes
          bytesPerRow:bytesPerRow
           fromRegion:MTLRegionMake2D(0, 0, width, height)
          mipmapLevel:0];
    
    // Create CGImage from the pixel data
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, imageBytes, imageByteCount, NULL);
    
    CGImageRef cgImage = CGImageCreate(width, height,
                                      8, 32, bytesPerRow,
                                      colorSpace,
                                      kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast,
                                      provider, NULL, false,
                                      kCGRenderingIntentDefault);
    
    // Create NSImage from CGImage
    NSImage *image = [[NSImage alloc] initWithCGImage:cgImage size:NSMakeSize(width, height)];
    
    // Convert to PNG data
    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    NSData *pngData = [imageRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    
    // Create timestamp for filename
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd_HH-mm-ss";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    NSString *filename = [NSString stringWithFormat:@"simcity_%@.png", timestamp];
    NSString *filepath = [screenshotsPath stringByAppendingPathComponent:filename];
    
    // Save to file
    if ([pngData writeToFile:filepath atomically:YES]) {
        NSLog(@"📸 Screenshot saved: %@", filepath);
        NSLog(@"📐 Screenshot size: %lux%lu pixels", width, height);
        
        // Simple console notification since NSUserNotification is deprecated
        NSLog(@"✅ Screenshot successfully saved to screenshots/%@", filename);
    } else {
        NSLog(@"❌ Failed to save screenshot");
    }
    
    // Cleanup
    free(imageBytes);
    CGImageRelease(cgImage);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
}

- (void)dealloc {
    if (self.cityGrid) {
        free(self.cityGrid);
    }
}

@end

@interface InteractiveCityApp : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) InteractiveCity *city;
@end

@implementation InteractiveCityApp

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSLog(@"🚀 Launching Interactive SimCity!");
    
    // Create custom menu
    [self createApplicationMenu];
    
    NSRect frame = NSMakeRect(100, 100, 1600, 1100);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled | 
                                                       NSWindowStyleMaskClosable | 
                                                       NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    [self.window setTitle:@"🏗️ SimCity ARM64 - Interactive City Builder"];
    
    self.city = [[InteractiveCity alloc] initWithFrame:frame];
    [self.window setContentView:self.city];
    [self.window makeFirstResponder:self.city];
    
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    NSLog(@"✅ Interactive city launched!");
    NSLog(@"🎮 Controls:");
    NSLog(@"   • Left click: Place building");
    NSLog(@"   • Right click: Remove building");
    NSLog(@"   • Number keys 1-5: Change building type");
    NSLog(@"   • WASD: Move camera");
    NSLog(@"   • Drag: Pan view");
    NSLog(@"   • Scroll: Zoom in/out");
    
    // Take automatic startup screenshot after a brief delay to ensure rendering is complete
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"📸 Taking automatic startup screenshot...");
        [self takeScreenshot:nil];
    });
}

- (void)createApplicationMenu {
    NSMenu *mainMenu = [[NSMenu alloc] init];
    [NSApp setMainMenu:mainMenu];
    
    // Application menu
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:appMenuItem];
    
    NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenuItem setSubmenu:appMenu];
    
    // About item
    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:@"About SimCity ARM64"
                                                       action:@selector(orderFrontStandardAboutPanel:)
                                                keyEquivalent:@""];
    [appMenu addItem:aboutItem];
    
    [appMenu addItem:[NSMenuItem separatorItem]];
    
    // Screenshot item
    NSMenuItem *screenshotItem = [[NSMenuItem alloc] initWithTitle:@"Take Screenshot"
                                                           action:@selector(takeScreenshot:)
                                                    keyEquivalent:@"s"];
    [screenshotItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
    [screenshotItem setTarget:self];
    [appMenu addItem:screenshotItem];
    
    [appMenu addItem:[NSMenuItem separatorItem]];
    
    // Quit item
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit SimCity ARM64"
                                                      action:@selector(terminate:)
                                               keyEquivalent:@"q"];
    [appMenu addItem:quitItem];
    
    // File menu
    NSMenuItem *fileMenuItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:fileMenuItem];
    
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [fileMenuItem setSubmenu:fileMenu];
    
    // Add screenshot to File menu too
    NSMenuItem *fileScreenshotItem = [[NSMenuItem alloc] initWithTitle:@"Take Screenshot..."
                                                               action:@selector(takeScreenshot:)
                                                        keyEquivalent:@"p"];
    [fileScreenshotItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand | NSEventModifierFlagShift];
    [fileScreenshotItem setTarget:self];
    [fileMenu addItem:fileScreenshotItem];
}

- (void)takeScreenshot:(id)sender {
    // Forward to the city view's screenshot method
    if (self.city) {
        [self.city takeScreenshot:sender];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"🎯 SimCity ARM64 - Interactive City Builder");
        
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        
        InteractiveCityApp *delegate = [[InteractiveCityApp alloc] init];
        [app setDelegate:delegate];
        
        [app run];
    }
    return 0;
}