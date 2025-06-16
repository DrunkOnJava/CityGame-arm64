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

// City statistics
typedef struct {
    int population;
    int jobs;
    int houses;
    int commercial;
    int industrial;
    int happiness;
} CityStats;

// Overlay system
typedef enum {
    OVERLAY_NONE = 0,
    OVERLAY_ZONES = 1,
    OVERLAY_POPULATION = 2,
    OVERLAY_TRAFFIC = 3,
    OVERLAY_HAPPINESS = 4
} OverlayMode;

@interface InteractiveCity : MTKView <MTKViewDelegate>
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

// Shadow system
@property (nonatomic, assign) float timeOfDay;
@property (nonatomic, assign) BOOL shadowsEnabled;

// Overlay system
@property (nonatomic, assign) OverlayMode currentOverlay;
@property (nonatomic, strong) id<MTLRenderPipelineState> overlayPipelineState;
@property (nonatomic, strong) id<MTLBuffer> overlayVertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> overlayIndexBuffer;

// UI
@property (nonatomic, strong) NSTextField *statsLabel;
@property (nonatomic, strong) NSTextField *buildingTypeLabel;
@property (nonatomic, strong) NSTextField *overlayLabel;
@end

@implementation InteractiveCity

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.gridSize = 30;
        self.currentBuildingType = TILE_HOUSE;
        self.zoom = 1.0f;
        self.targetZoom = 1.0f;
        
        // Initialize shadow system
        self.timeOfDay = 12.0f;
        self.shadowsEnabled = YES;
        
        // Initialize overlay system
        self.currentOverlay = OVERLAY_NONE;
        
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
    
    srand48(time(NULL));
    
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
    
    [self setTileAt:2 y:2 type:TILE_HOUSE];
    [self setTileAt:3 y:2 type:TILE_HOUSE];
    [self setTileAt:2 y:3 type:TILE_COMMERCIAL];
    [self setTileAt:7 y:7 type:TILE_INDUSTRIAL];
    
    NSLog(@"✅ City data initialized: %dx%d", self.gridSize, self.gridSize);
}

- (void)createGeometry {
    [self rebuildGeometry];
}

- (void)rebuildGeometry {
    typedef struct {
        int x, y;
        CityTileType type;
        float depth;
    } TileInfo;
    
    int maxTiles = self.gridSize * self.gridSize;
    TileInfo *tiles = malloc(maxTiles * sizeof(TileInfo));
    int tileCount = 0;
    
    for (int y = 0; y < self.gridSize; y++) {
        for (int x = 0; x < self.gridSize; x++) {
            int tileIndex = y * self.gridSize + x;
            CityTileType tileType = self.cityGrid[tileIndex];
            
            if (tileType == TILE_EMPTY) continue;
            
            float baseDepth = (float)(x + y);
            float heightMultiplier = 0.0f;
            
            switch (tileType) {
                case TILE_ROAD:
                    heightMultiplier = 0.0f;
                    break;
                case TILE_HOUSE:
                    heightMultiplier = 0.1f;
                    break;
                case TILE_COMMERCIAL:
                    heightMultiplier = 0.3f;
                    break;
                case TILE_INDUSTRIAL:
                    heightMultiplier = 0.5f;
                    break;
                case TILE_PARK:
                    heightMultiplier = 0.05f;
                    break;
                case TILE_EMPTY:
                case TILE_TYPE_COUNT:
                    break;
            }
            
            float depth = baseDepth - heightMultiplier;
            tiles[tileCount] = (TileInfo){x, y, tileType, depth};
            tileCount++;
        }
    }
    
    if (tileCount == 0) {
        free(tiles);
        return;
    }
    
    for (int i = 0; i < tileCount - 1; i++) {
        for (int j = i + 1; j < tileCount; j++) {
            if (tiles[i].depth > tiles[j].depth) {
                TileInfo temp = tiles[i];
                tiles[i] = tiles[j];
                tiles[j] = temp;
            }
        }
    }
    
    int shadowCount = 0;
    if (self.shadowsEnabled) {
        for (int i = 0; i < tileCount; i++) {
            if (tiles[i].type != TILE_ROAD && tiles[i].type != TILE_EMPTY) {
                shadowCount++;
            }
        }
    }
    
    IsometricVertex *vertices = malloc((shadowCount + tileCount) * 4 * sizeof(IsometricVertex));
    uint16_t *indices = malloc((shadowCount + tileCount) * 6 * sizeof(uint16_t));
    
    int vertexIndex = 0;
    int indexIndex = 0;
    int quadIndex = 0;
    
    if (self.shadowsEnabled) {
        for (int i = 0; i < tileCount; i++) {
            TileInfo *tile = &tiles[i];
            
            if (tile->type == TILE_ROAD || tile->type == TILE_EMPTY) continue;
            
            float sunAngle = (self.timeOfDay - 6.0f) * M_PI / 12.0f;
            float shadowLength = 0.04f;
            
            float sunHeight = sinf(sunAngle);
            if (sunHeight > 0) {
                shadowLength *= (1.0f / fmaxf(sunHeight, 0.2f));
            } else {
                shadowLength = 0.0f;
            }
            
            float shadowOffsetX = cosf(sunAngle) * shadowLength;
            float shadowOffsetY = -sinf(sunAngle) * shadowLength * 0.5f;
            
            float isoX = (tile->x - tile->y) * 0.1f + shadowOffsetX;
            float isoY = (tile->x + tile->y) * 0.05f + shadowOffsetY;
            
            float tileWidth = 0.08f;
            float tileHeight = 0.08f;
            
            float u1 = 0.9375f, v1 = 0.9375f, u2 = 1.0f, v2 = 1.0f;
            
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
    
    for (int i = 0; i < tileCount; i++) {
        TileInfo *tile = &tiles[i];
        
        float isoX = (tile->x - tile->y) * 0.1f;
        float isoY = (tile->x + tile->y) * 0.05f;
        
        float heightOffset = 0.0f;
        if (tile->type == TILE_COMMERCIAL) heightOffset = 0.02f;
        else if (tile->type == TILE_INDUSTRIAL) heightOffset = 0.03f;
        
        float tileWidth = 0.08f;
        float tileHeight = 0.08f;
        
        float u1, v1, u2, v2;
        if (tile->type == TILE_ROAD) {
            [self getUVForRoadAt:tile->x y:tile->y u1:&u1 v1:&v1 u2:&u2 v2:&v2];
        } else {
            [self getUVForTileType:tile->type x:tile->x y:tile->y u1:&u1 v1:&v1 u2:&u2 v2:&v2];
        }
        
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
            
            float isoX = (x - y) * 0.1f;
            float isoY = (x + y) * 0.05f;
            
            float tileWidth = 0.08f;
            float tileHeight = 0.08f;
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
    if (tileType == TILE_ROAD) {
        [self getUVForRoadAt:x y:y u1:u1 v1:v1 u2:u2 v2:v2];
        return;
    }
    
    int index = y * self.gridSize + x;
    uint8_t variant = self.buildingVariants[index];
    
    float spriteSize = 0.0625f;
    int spriteIndex = 0;
    
    switch (tileType) {
        case TILE_HOUSE:
            spriteIndex = 1 + (variant % 4);
            break;
        case TILE_COMMERCIAL:
            spriteIndex = 5 + (variant % 4);
            break;
        case TILE_INDUSTRIAL: {
            int baseVariant = variant % 2;
            spriteIndex = 10 + (baseVariant * 4) + self.animationFrame;
            break;
        }
        case TILE_PARK:
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
    BOOL hasNorth = [self hasRoadAt:x y:y-1];
    BOOL hasSouth = [self hasRoadAt:x y:y+1];
    BOOL hasEast = [self hasRoadAt:x+1 y:y];
    BOOL hasWest = [self hasRoadAt:x-1 y:y];
    
    BOOL hasNorthEast = [self hasRoadAt:x+1 y:y-1];
    BOOL hasNorthWest = [self hasRoadAt:x-1 y:y-1];
    BOOL hasSouthEast = [self hasRoadAt:x+1 y:y+1];
    BOOL hasSouthWest = [self hasRoadAt:x-1 y:y+1];
    
    int spriteIndex = 20;
    
    int connections = (hasNorth ? 1 : 0) | 
                     (hasEast ? 2 : 0) | 
                     (hasSouth ? 4 : 0) | 
                     (hasWest ? 8 : 0);
    
    switch (connections) {
        case 0:  spriteIndex = 20; break;
        case 1:  spriteIndex = 21; break;
        case 2:  spriteIndex = 22; break;
        case 3:  spriteIndex = (hasNorthEast) ? 23 : 24; break;
        case 4:  spriteIndex = 21; break;
        case 5:  spriteIndex = 25; break;
        case 6:  spriteIndex = (hasSouthEast) ? 26 : 27; break;
        case 7:  spriteIndex = 28; break;
        case 8:  spriteIndex = 22; break;
        case 9:  spriteIndex = (hasNorthWest) ? 29 : 30; break;
        case 10: spriteIndex = 31; break;
        case 11: spriteIndex = 32; break;
        case 12: spriteIndex = (hasSouthWest) ? 33 : 34; break;
        case 13: spriteIndex = 35; break;
        case 14: spriteIndex = 36; break;
        case 15: {
            int diagonalCount = (hasNorthEast ? 1 : 0) + (hasNorthWest ? 1 : 0) + 
                               (hasSouthEast ? 1 : 0) + (hasSouthWest ? 1 : 0);
            spriteIndex = 37 + (diagonalCount > 2 ? 1 : 0);
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
    self.statsLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, self.bounds.size.height - 100, 300, 80)];
    self.statsLabel.bezeled = NO;
    self.statsLabel.drawsBackground = YES;
    self.statsLabel.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.7];
    self.statsLabel.textColor = [NSColor whiteColor];
    self.statsLabel.editable = NO;
    self.statsLabel.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    [self addSubview:self.statsLabel];
    
    self.buildingTypeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 10, 300, 30)];
    self.buildingTypeLabel.bezeled = NO;
    self.buildingTypeLabel.drawsBackground = YES;
    self.buildingTypeLabel.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.7];
    self.buildingTypeLabel.textColor = [NSColor whiteColor];
    self.buildingTypeLabel.editable = NO;
    self.buildingTypeLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightBold];
    [self addSubview:self.buildingTypeLabel];
    
    self.overlayLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 50, 400, 60)];
    self.overlayLabel.bezeled = NO;
    self.overlayLabel.drawsBackground = YES;
    self.overlayLabel.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.7];
    self.overlayLabel.textColor = [NSColor whiteColor];
    self.overlayLabel.editable = NO;
    self.overlayLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    [self addSubview:self.overlayLabel];
    
    [self updateBuildingTypeLabel];
    [self updateOverlayLabel];
}

- (void)updateStats {
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
    
    newStats.population = newStats.houses * 4;
    newStats.jobs = newStats.commercial * 6 + newStats.industrial * 10;
    newStats.happiness = 50 + (newStats.jobs > newStats.population ? 20 : -10);
    
    self.stats = newStats;
    
    NSString *statsText = [NSString stringWithFormat:
        @"🏙️ CITY STATISTICS\n"
        @"Population: %d\n"
        @"Jobs: %d\n"
        @"Houses: %d | Commercial: %d | Industrial: %d\n"
        @"Happiness: %d%%",
        self.stats.population, self.stats.jobs,
        self.stats.houses, self.stats.commercial, self.stats.industrial,
        self.stats.happiness];
    
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
        NSLog(@"🏗️ Placed %d at (%d, %d)", self.currentBuildingType, tileX, tileY);
    }
}

- (void)rightMouseDown:(NSEvent *)event {
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
        [self setTileAt:tileX y:tileY type:TILE_EMPTY];
        [self rebuildGeometry];
        [self updateStats];
        NSLog(@"🗑️ Removed tile at (%d, %d)", tileX, tileY);
    }
}

- (void)setTileAt:(int)x y:(int)y type:(CityTileType)type {
    if (x >= 0 && x < self.gridSize && y >= 0 && y < self.gridSize) {
        self.cityGrid[y * self.gridSize + x] = type;
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
        case 96: // F5
            self.shadowsEnabled = !self.shadowsEnabled;
            [self updateOverlayLabel];
            [self rebuildGeometry];
            break;
        case 97: // F6
            self.timeOfDay += 1.0f;
            if (self.timeOfDay >= 24.0f) self.timeOfDay = 0.0f;
            [self updateOverlayLabel];
            [self rebuildGeometry];
            break;
        case 98: // F7
            self.currentOverlay = OVERLAY_NONE;
            [self updateOverlayLabel];
            [self rebuildGeometry];
            break;
    }
}

- (void)drawInMTKView:(MTKView *)view {
    float smoothing = 0.1f;
    self.cameraX += (self.targetCameraX - self.cameraX) * smoothing;
    self.cameraY += (self.targetCameraY - self.cameraY) * smoothing;
    self.zoom += (self.targetZoom - self.zoom) * smoothing;
    
    self.animationTime += 1.0f/60.0f;
    int newFrame = ((int)(self.animationTime * 4.0f)) % 4;
    if (newFrame != self.animationFrame) {
        self.animationFrame = newFrame;
        [self rebuildGeometry];
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
        
        if (self.currentOverlay != OVERLAY_NONE && self.overlayPipelineState && self.overlayVertexBuffer && self.overlayIndexBuffer) {
            [encoder setRenderPipelineState:self.overlayPipelineState];
            [encoder setVertexBuffer:self.overlayVertexBuffer offset:0 atIndex:0];
            
            struct {
                vector_float2 camera;
                float zoom;
                int overlayMode;
                vector_float4 overlayColor;
            } overlayUniforms;
            
            overlayUniforms.camera = (vector_float2){self.cameraX, self.cameraY};
            overlayUniforms.zoom = self.zoom;
            overlayUniforms.overlayMode = (int)self.currentOverlay;
            
            switch (self.currentOverlay) {
                case OVERLAY_ZONES:
                    overlayUniforms.overlayColor = (vector_float4){0.2f, 0.8f, 0.2f, 0.3f};
                    break;
                case OVERLAY_POPULATION:
                    overlayUniforms.overlayColor = (vector_float4){0.8f, 0.2f, 0.2f, 0.4f};
                    break;
                case OVERLAY_TRAFFIC:
                    overlayUniforms.overlayColor = (vector_float4){0.2f, 0.2f, 0.8f, 0.35f};
                    break;
                case OVERLAY_HAPPINESS:
                    overlayUniforms.overlayColor = (vector_float4){0.8f, 0.8f, 0.2f, 0.3f};
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
    self.statsLabel.frame = NSMakeRect(10, size.height - 100, 300, 80);
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

@interface InteractiveCityApp : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) InteractiveCity *city;
@end

@implementation InteractiveCityApp

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSLog(@"🚀 Launching Enhanced SimCity!");
    
    NSRect frame = NSMakeRect(100, 100, 1600, 1100);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled | 
                                                       NSWindowStyleMaskClosable | 
                                                       NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    [self.window setTitle:@"🏗️ SimCity Enhanced Graphics - Interactive City Builder"];
    
    self.city = [[InteractiveCity alloc] initWithFrame:frame];
    [self.window setContentView:self.city];
    [self.window makeFirstResponder:self.city];
    
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    NSLog(@"✅ Enhanced graphics city launched!");
    NSLog(@"🎮 Controls:");
    NSLog(@"   • Left click: Place building");
    NSLog(@"   • Right click: Remove building");
    NSLog(@"   • Number keys 1-5: Change building type");
    NSLog(@"   • WASD: Move camera");
    NSLog(@"   • Drag: Pan view");
    NSLog(@"   • Scroll: Zoom in/out");
    NSLog(@"   • F1-F4: Overlay modes");
    NSLog(@"   • F5: Toggle shadows");
    NSLog(@"   • F6: Advance time");
    NSLog(@"   • F7: Turn off overlays");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"🎯 SimCity Enhanced Graphics - Interactive City Builder");
        
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        
        InteractiveCityApp *delegate = [[InteractiveCityApp alloc] init];
        [app setDelegate:delegate];
        
        [app run];
    }
    return 0;
}