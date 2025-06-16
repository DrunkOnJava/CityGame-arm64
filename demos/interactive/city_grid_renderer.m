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
    TILE_PARK = 5
} CityTileType;

// Vertex structure for isometric sprites
typedef struct {
    vector_float2 position;
    vector_float2 texCoord;
} IsometricVertex;

@interface CityGridRenderer : MTKView <MTKViewDelegate>
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLTexture> spriteAtlas;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> indexBuffer;
@property (nonatomic, strong) id<MTLSamplerState> samplerState;

// City data
@property (nonatomic, assign) CityTileType *cityGrid;
@property (nonatomic, assign) int gridSize;
@property (nonatomic, assign) float cameraX;
@property (nonatomic, assign) float cameraY;
@property (nonatomic, assign) float zoom;
@end

@implementation CityGridRenderer

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.gridSize = 20;
        self.cameraX = 0.0f;
        self.cameraY = 0.0f;
        self.zoom = 1.0f;
        
        [self setupMetal];
        [self loadSpriteAtlas];
        [self createShaders];
        [self initializeCityData];
        [self createGeometry];
        [self setupMouseHandling];
        
        self.delegate = self;
    }
    return self;
}

- (void)setupMetal {
    self.device = MTLCreateSystemDefaultDevice();
    self.commandQueue = [self.device newCommandQueue];
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.clearColor = MTLClearColorMake(0.1, 0.7, 0.1, 1.0); // Grass green
    
    NSLog(@"🎮 City Grid Renderer - Metal initialized");
}

- (void)loadSpriteAtlas {
    NSString *atlasPath = @"assets/atlases/buildings.png";
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:atlasPath];
    
    if (!image) {
        NSLog(@"❌ Atlas not found: %@", atlasPath);
        return;
    }
    
    // Convert to CGImage and then to raw RGBA data
    CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    
    size_t bytesPerPixel = 4;
    size_t bytesPerRow = width * bytesPerPixel;
    size_t dataSize = height * bytesPerRow;
    
    unsigned char *data = malloc(dataSize);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data, width, height, 8, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    
    // Create Metal texture
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
    
    // Cleanup
    free(data);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    NSLog(@"✅ City atlas loaded: %zux%zu", width, height);
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
    "    float2 screenSize;\n"
    "};\n"
    "\n"
    "vertex VertexOut vertex_main(VertexIn in [[stage_in]],\n"
    "                            constant Uniforms& uniforms [[buffer(1)]]) {\n"
    "    VertexOut out;\n"
    "    \n"
    "    // Apply camera transform\n"
    "    float2 worldPos = (in.position - uniforms.camera) * uniforms.zoom;\n"
    "    \n"
    "    out.position = float4(worldPos, 0.0, 1.0);\n"
    "    out.texCoord = in.texCoord;\n"
    "    \n"
    "    return out;\n"
    "}\n"
    "\n"
    "fragment float4 fragment_main(VertexOut in [[stage_in]],\n"
    "                             texture2d<float> atlas [[texture(0)]]) {\n"
    "    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::nearest);\n"
    "    \n"
    "    float4 color = atlas.sample(s, in.texCoord);\n"
    "    \n"
    "    // Skip transparent pixels\n"
    "    if (color.a < 0.1) {\n"
    "        discard_fragment();\n"
    "    }\n"
    "    \n"
    "    return color;\n"
    "}\n";
    
    NSError *error = nil;
    id<MTLLibrary> library = [self.device newLibraryWithSource:shaderSource options:nil error:&error];
    if (!library) {
        NSLog(@"❌ Shader error: %@", error.localizedDescription);
        return;
    }
    
    id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragFunc = [library newFunctionWithName:@"fragment_main"];
    
    // Create vertex descriptor
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
    
    // Enable alpha blending
    desc.colorAttachments[0].blendingEnabled = YES;
    desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    
    self.pipelineState = [self.device newRenderPipelineStateWithDescriptor:desc error:&error];
    if (!self.pipelineState) {
        NSLog(@"❌ Pipeline error: %@", error.localizedDescription);
        return;
    }
    
    // Create sampler
    MTLSamplerDescriptor *samplerDesc = [[MTLSamplerDescriptor alloc] init];
    samplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
    samplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
    self.samplerState = [self.device newSamplerStateWithDescriptor:samplerDesc];
    
    NSLog(@"✅ City shaders compiled successfully");
}

- (void)initializeCityData {
    // Allocate city grid
    int totalTiles = self.gridSize * self.gridSize;
    self.cityGrid = malloc(totalTiles * sizeof(CityTileType));
    
    // Initialize with a sample city layout
    for (int y = 0; y < self.gridSize; y++) {
        for (int x = 0; x < self.gridSize; x++) {
            int index = y * self.gridSize + x;
            
            // Create roads
            if (x == 5 || x == 10 || x == 15 || y == 5 || y == 10 || y == 15) {
                self.cityGrid[index] = TILE_ROAD;
            }
            // Create buildings in blocks
            else if ((x % 4) == 1 && (y % 4) == 1) {
                self.cityGrid[index] = TILE_HOUSE;
            }
            else if ((x % 4) == 2 && (y % 4) == 2) {
                self.cityGrid[index] = TILE_COMMERCIAL;
            }
            else if ((x % 4) == 3 && (y % 4) == 3) {
                self.cityGrid[index] = TILE_INDUSTRIAL;
            }
            else {
                self.cityGrid[index] = TILE_EMPTY;
            }
        }
    }
    
    NSLog(@"✅ City grid initialized: %dx%d tiles", self.gridSize, self.gridSize);
}

- (void)createGeometry {
    // Calculate how many tiles have buildings (non-empty)
    int buildingCount = 0;
    for (int i = 0; i < self.gridSize * self.gridSize; i++) {
        if (self.cityGrid[i] != TILE_EMPTY) {
            buildingCount++;
        }
    }
    
    // Create vertices for each building tile
    IsometricVertex *vertices = malloc(buildingCount * 4 * sizeof(IsometricVertex));
    uint16_t *indices = malloc(buildingCount * 6 * sizeof(uint16_t));
    
    int vertexIndex = 0;
    int indexIndex = 0;
    int quadIndex = 0;
    
    for (int y = 0; y < self.gridSize; y++) {
        for (int x = 0; x < self.gridSize; x++) {
            int tileIndex = y * self.gridSize + x;
            CityTileType tileType = self.cityGrid[tileIndex];
            
            if (tileType == TILE_EMPTY) continue;
            
            // Convert grid coordinates to isometric screen coordinates
            float isoX = (x - y) * 0.1f;
            float isoY = (x + y) * 0.05f;
            
            // Size of each tile sprite
            float tileWidth = 0.08f;
            float tileHeight = 0.08f;
            
            // Get UV coordinates based on tile type
            float u1, v1, u2, v2;
            [self getUVForTileType:tileType u1:&u1 v1:&v1 u2:&u2 v2:&v2];
            
            // Create quad vertices
            vertices[vertexIndex + 0] = (IsometricVertex){{isoX - tileWidth, isoY - tileHeight}, {u1, v2}};
            vertices[vertexIndex + 1] = (IsometricVertex){{isoX + tileWidth, isoY - tileHeight}, {u2, v2}};
            vertices[vertexIndex + 2] = (IsometricVertex){{isoX + tileWidth, isoY + tileHeight}, {u2, v1}};
            vertices[vertexIndex + 3] = (IsometricVertex){{isoX - tileWidth, isoY + tileHeight}, {u1, v1}};
            
            // Create indices for the quad
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
                                                 length:buildingCount * 4 * sizeof(IsometricVertex)
                                                options:MTLResourceStorageModeShared];
    
    self.indexBuffer = [self.device newBufferWithBytes:indices
                                                length:buildingCount * 6 * sizeof(uint16_t)
                                               options:MTLResourceStorageModeShared];
    
    free(vertices);
    free(indices);
    
    NSLog(@"✅ Created geometry for %d buildings in isometric grid", buildingCount);
}

- (void)getUVForTileType:(CityTileType)tileType u1:(float*)u1 v1:(float*)v1 u2:(float*)u2 v2:(float*)v2 {
    // Map tile types to different sprites in our atlas
    switch (tileType) {
        case TILE_ROAD:
            *u1 = 0.0f; *v1 = 0.0f; *u2 = 0.0625f; *v2 = 0.0625f; // First sprite
            break;
        case TILE_HOUSE:
            *u1 = 0.0625f; *v1 = 0.0f; *u2 = 0.125f; *v2 = 0.0625f; // Second sprite
            break;
        case TILE_COMMERCIAL:
            *u1 = 0.125f; *v1 = 0.0f; *u2 = 0.1875f; *v2 = 0.0625f; // Third sprite
            break;
        case TILE_INDUSTRIAL:
            *u1 = 0.1875f; *v1 = 0.0f; *u2 = 0.25f; *v2 = 0.0625f; // Fourth sprite
            break;
        default:
            *u1 = 0.0f; *v1 = 0.0f; *u2 = 0.0625f; *v2 = 0.0625f;
            break;
    }
}

- (void)setupMouseHandling {
    // Add mouse event handling for camera control
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                                options:(NSTrackingActiveInKeyWindow | NSTrackingMouseMoved)
                                                                  owner:self
                                                               userInfo:nil];
    [self addTrackingArea:trackingArea];
    
    NSLog(@"✅ Mouse controls enabled (drag to pan, scroll to zoom)");
}

- (void)mouseDragged:(NSEvent *)event {
    // Pan camera
    self.cameraX -= event.deltaX * 0.01f / self.zoom;
    self.cameraY += event.deltaY * 0.01f / self.zoom;
}

- (void)scrollWheel:(NSEvent *)event {
    // Zoom camera
    self.zoom *= (1.0f + event.deltaY * 0.1f);
    self.zoom = fmaxf(0.2f, fminf(5.0f, self.zoom)); // Clamp zoom
}

- (void)drawInMTKView:(MTKView *)view {
    if (!self.pipelineState || !self.spriteAtlas || !self.vertexBuffer) {
        return;
    }
    
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    commandBuffer.label = @"City Grid Render";
    
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor) {
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        encoder.label = @"City Grid Encoder";
        
        [encoder setRenderPipelineState:self.pipelineState];
        [encoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
        
        // Set camera uniforms
        struct {
            vector_float2 camera;
            float zoom;
            vector_float2 screenSize;
        } uniforms = {
            .camera = {self.cameraX, self.cameraY},
            .zoom = self.zoom,
            .screenSize = {(float)view.drawableSize.width, (float)view.drawableSize.height}
        };
        
        [encoder setVertexBytes:&uniforms length:sizeof(uniforms) atIndex:1];
        [encoder setFragmentTexture:self.spriteAtlas atIndex:0];
        [encoder setFragmentSamplerState:self.samplerState atIndex:0];
        
        // Draw all building tiles
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
    NSLog(@"📐 City view resized to: %.0fx%.0f", size.width, size.height);
}

- (void)dealloc {
    if (self.cityGrid) {
        free(self.cityGrid);
    }
}

@end

@interface CityApp : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) CityGridRenderer *cityRenderer;
@end

@implementation CityApp

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSLog(@"🚀 Launching SimCity ARM64 - Isometric City Grid!");
    
    // Create main window
    NSRect frame = NSMakeRect(100, 100, 1400, 1000);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled | 
                                                       NSWindowStyleMaskClosable | 
                                                       NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    [self.window setTitle:@"🏗️ SimCity ARM64 - Isometric City Grid"];
    
    // Create city renderer
    self.cityRenderer = [[CityGridRenderer alloc] initWithFrame:frame];
    [self.window setContentView:self.cityRenderer];
    
    // Show window
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    NSLog(@"✅ City grid renderer launched!");
    NSLog(@"🎮 Controls: Drag to pan, scroll to zoom");
    NSLog(@"🏗️ You should see a 20x20 isometric city with buildings and roads!");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"🎯 SimCity ARM64 - Isometric City Grid Renderer");
        NSLog(@"🏗️ Building a 20x20 city with real sprites...");
        
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        
        CityApp *delegate = [[CityApp alloc] init];
        [app setDelegate:delegate];
        
        [app run];
    }
    return 0;
}