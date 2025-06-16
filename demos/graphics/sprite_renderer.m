#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

// Vertex structure for sprite rendering
typedef struct {
    vector_float2 position;
    vector_float2 texCoord;
} SpriteVertex;

@interface SpriteRenderer : MTKView <MTKViewDelegate>
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLTexture> spriteAtlas;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> indexBuffer;
@property (nonatomic, strong) id<MTLSamplerState> samplerState;
@end

@implementation SpriteRenderer

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupMetal];
        [self loadSpriteAtlas];
        [self createShaders];
        [self setupVertexData];
        self.delegate = self;
    }
    return self;
}

- (void)setupMetal {
    self.device = MTLCreateSystemDefaultDevice();
    self.commandQueue = [self.device newCommandQueue];
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.clearColor = MTLClearColorMake(0.4, 0.8, 0.4, 1.0); // Bright green grass
    
    NSLog(@"🎮 Metal GPU initialized: %@", self.device.name);
}

- (void)loadSpriteAtlas {
    NSString *atlasPath = @"assets/atlases/buildings.png";
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:atlasPath];
    
    if (!image) {
        NSLog(@"❌ Failed to load atlas from: %@", atlasPath);
        return;
    }
    
    // Convert NSImage to raw bitmap data
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithData:[image TIFFRepresentation]];
    if (!bitmap) {
        NSLog(@"❌ Failed to create bitmap from image");
        return;
    }
    
    // Create Metal texture
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                          width:bitmap.pixelsWide
                                                                                         height:bitmap.pixelsHigh
                                                                                      mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead;
    
    self.spriteAtlas = [self.device newTextureWithDescriptor:descriptor];
    
    // Upload bitmap data to texture
    [self.spriteAtlas replaceRegion:MTLRegionMake2D(0, 0, bitmap.pixelsWide, bitmap.pixelsHigh)
                        mipmapLevel:0
                          withBytes:bitmap.bitmapData
                        bytesPerRow:bitmap.bytesPerRow];
    
    NSLog(@"✅ Sprite atlas loaded: %dx%d texture with real bitmap data", (int)bitmap.pixelsWide, (int)bitmap.pixelsHigh);
}

- (void)createShaders {
    // Create shader source code as string
    NSString *shaderSource = @"
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
    
    vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        out.texCoord = in.texCoord;
        return out;
    }
    
    fragment float4 fragment_main(VertexOut in [[stage_in]],
                                 texture2d<float> spriteTexture [[texture(0)]],
                                 sampler spriteSampler [[sampler(0)]]) {
        float4 color = spriteTexture.sample(spriteSampler, in.texCoord);
        return color;
    }
    ";
    
    // Compile shaders
    NSError *error;
    id<MTLLibrary> library = [self.device newLibraryWithSource:shaderSource options:nil error:&error];
    if (!library) {
        NSLog(@"❌ Shader compilation failed: %@", error.localizedDescription);
        return;
    }
    
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_main"];
    
    // Create render pipeline
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat;
    
    // Enable alpha blending for transparent sprites
    pipelineDescriptor.colorAttachments[0].blendingEnabled = YES;
    pipelineDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    pipelineDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    
    self.pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (!self.pipelineState) {
        NSLog(@"❌ Pipeline state creation failed: %@", error.localizedDescription);
        return;
    }
    
    NSLog(@"✅ Metal shaders compiled and pipeline created");
}

- (void)setupVertexData {
    // Create vertex data for multiple building sprites
    SpriteVertex vertices[] = {
        // First building sprite (top-left of atlas)
        {{-0.8f, -0.4f}, {0.0f, 0.0625f}},      // Bottom left
        {{-0.4f, -0.4f}, {0.0625f, 0.0625f}},   // Bottom right
        {{-0.4f,  0.0f}, {0.0625f, 0.0f}},      // Top right
        {{-0.8f,  0.0f}, {0.0f, 0.0f}},         // Top left
        
        // Second building sprite
        {{-0.2f, -0.4f}, {0.0625f, 0.0625f}},   // Bottom left
        {{ 0.2f, -0.4f}, {0.125f, 0.0625f}},    // Bottom right
        {{ 0.2f,  0.0f}, {0.125f, 0.0f}},       // Top right
        {{-0.2f,  0.0f}, {0.0625f, 0.0f}},      // Top left
        
        // Third building sprite
        {{ 0.4f, -0.4f}, {0.125f, 0.0625f}},    // Bottom left
        {{ 0.8f, -0.4f}, {0.1875f, 0.0625f}},   // Bottom right
        {{ 0.8f,  0.0f}, {0.1875f, 0.0f}},      // Top right
        {{ 0.4f,  0.0f}, {0.125f, 0.0f}},       // Top left
        
        // Fourth building sprite (second row)
        {{-0.6f,  0.2f}, {0.0f, 0.125f}},       // Bottom left
        {{-0.2f,  0.2f}, {0.0625f, 0.125f}},    // Bottom right
        {{-0.2f,  0.6f}, {0.0625f, 0.0625f}},   // Top right
        {{-0.6f,  0.6f}, {0.0f, 0.0625f}},      // Top left
        
        // Fifth building sprite
        {{ 0.0f,  0.2f}, {0.0625f, 0.125f}},    // Bottom left
        {{ 0.4f,  0.2f}, {0.125f, 0.125f}},     // Bottom right
        {{ 0.4f,  0.6f}, {0.125f, 0.0625f}},    // Top right
        {{ 0.0f,  0.6f}, {0.0625f, 0.0625f}},   // Top left
    };
    
    // Create indices for quads
    uint16_t indices[] = {
        // First quad
        0, 1, 2, 2, 3, 0,
        // Second quad
        4, 5, 6, 6, 7, 4,
        // Third quad
        8, 9, 10, 10, 11, 8,
        // Fourth quad
        12, 13, 14, 14, 15, 12,
        // Fifth quad
        16, 17, 18, 18, 19, 16
    };
    
    self.vertexBuffer = [self.device newBufferWithBytes:vertices
                                                 length:sizeof(vertices)
                                                options:MTLResourceStorageModeShared];
    
    self.indexBuffer = [self.device newBufferWithBytes:indices
                                                length:sizeof(indices)
                                               options:MTLResourceStorageModeShared];
    
    // Create sampler for texture filtering
    MTLSamplerDescriptor *samplerDescriptor = [[MTLSamplerDescriptor alloc] init];
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.sAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDescriptor.tAddressMode = MTLSamplerAddressModeClampToEdge;
    
    self.samplerState = [self.device newSamplerStateWithDescriptor:samplerDescriptor];
    
    NSLog(@"✅ Vertex data created for 5 building sprites");
}

- (void)drawInMTKView:(MTKView *)view {
    if (!self.pipelineState || !self.spriteAtlas) return;
    
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    commandBuffer.label = @"SimCity Sprite Render";
    
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor) {
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        encoder.label = @"Sprite Render Encoder";
        
        // Set pipeline and resources
        [encoder setRenderPipelineState:self.pipelineState];
        [encoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
        [encoder setFragmentTexture:self.spriteAtlas atIndex:0];
        [encoder setFragmentSamplerState:self.samplerState atIndex:0];
        
        // Draw 5 building sprites
        [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                            indexCount:30  // 5 quads * 6 indices each
                             indexType:MTLIndexTypeUInt16
                           indexBuffer:self.indexBuffer
                     indexBufferOffset:0];
        
        [encoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    
    [commandBuffer commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    NSLog(@"📐 Viewport resized to: %.0fx%.0f", size.width, size.height);
}

@end

@interface SpriteApp : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) SpriteRenderer *renderer;
@end

@implementation SpriteApp

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSLog(@"🚀 Launching SimCity ARM64 Sprite Renderer...");
    
    // Create window
    NSRect frame = NSMakeRect(100, 100, 1200, 800);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled | 
                                                       NSWindowStyleMaskClosable | 
                                                       NSWindowStyleMaskResizable |
                                                       NSWindowStyleMaskMiniaturizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    [self.window setTitle:@"🏗️ SimCity ARM64 - Building Sprites Demo"];
    
    // Create renderer
    self.renderer = [[SpriteRenderer alloc] initWithFrame:frame];
    [self.window setContentView:self.renderer];
    
    // Show window
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    NSLog(@"✅ Window launched: %@", self.window.title);
    NSLog(@"🏗️ Displaying 5 building sprites from our atlas!");
    NSLog(@"🎨 Green background = grass, sprites = isometric buildings");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"🎯 SimCity ARM64 - Building Sprite Renderer Starting...");
        
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        
        SpriteApp *delegate = [[SpriteApp alloc] init];
        [app setDelegate:delegate];
        
        [app run];
    }
    return 0;
}