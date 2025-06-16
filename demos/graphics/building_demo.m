#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

// Vertex structure
typedef struct {
    vector_float2 position;
    vector_float2 texCoord;
} Vertex;

@interface BuildingDemo : MTKView <MTKViewDelegate>
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLTexture> spriteAtlas;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> indexBuffer;
@property (nonatomic, strong) id<MTLSamplerState> samplerState;
@end

@implementation BuildingDemo

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupMetal];
        [self loadAtlas];
        [self createPipeline];
        [self setupGeometry];
        self.delegate = self;
    }
    return self;
}

- (void)setupMetal {
    self.device = MTLCreateSystemDefaultDevice();
    self.commandQueue = [self.device newCommandQueue];
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.clearColor = MTLClearColorMake(0.2, 0.7, 0.2, 1.0); // Green grass
    
    NSLog(@"🎮 Metal initialized: %@", self.device.name);
}

- (void)loadAtlas {
    NSString *path = @"assets/atlases/buildings.png";
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
    
    if (!image) {
        NSLog(@"❌ Atlas not found at: %@", path);
        return;
    }
    
    // Convert to bitmap
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithData:[image TIFFRepresentation]];
    
    // Create texture
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                    width:bitmap.pixelsWide
                                                                                   height:bitmap.pixelsHigh
                                                                                mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead;
    
    self.spriteAtlas = [self.device newTextureWithDescriptor:desc];
    [self.spriteAtlas replaceRegion:MTLRegionMake2D(0, 0, bitmap.pixelsWide, bitmap.pixelsHigh)
                        mipmapLevel:0
                          withBytes:bitmap.bitmapData
                        bytesPerRow:bitmap.bytesPerRow];
    
    NSLog(@"✅ Atlas loaded: %dx%d", (int)bitmap.pixelsWide, (int)bitmap.pixelsHigh);
}

- (void)createPipeline {
    // Shader source as single string
    NSString *shaders = @""
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
    "vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {\n"
    "    VertexOut out;\n"
    "    out.position = float4(in.position, 0.0, 1.0);\n"
    "    out.texCoord = in.texCoord;\n"
    "    return out;\n"
    "}\n"
    "\n"
    "fragment float4 fragment_main(VertexOut in [[stage_in]],\n"
    "                             texture2d<float> tex [[texture(0)]],\n"
    "                             sampler smp [[sampler(0)]]) {\n"
    "    return tex.sample(smp, in.texCoord);\n"
    "}\n";
    
    NSError *error;
    id<MTLLibrary> library = [self.device newLibraryWithSource:shaders options:nil error:&error];
    if (!library) {
        NSLog(@"❌ Shader error: %@", error);
        return;
    }
    
    id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragFunc = [library newFunctionWithName:@"fragment_main"];
    
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = vertexFunc;
    desc.fragmentFunction = fragFunc;
    desc.colorAttachments[0].pixelFormat = self.colorPixelFormat;
    
    // Alpha blending
    desc.colorAttachments[0].blendingEnabled = YES;
    desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    
    self.pipelineState = [self.device newRenderPipelineStateWithDescriptor:desc error:&error];
    if (!self.pipelineState) {
        NSLog(@"❌ Pipeline error: %@", error);
        return;
    }
    
    NSLog(@"✅ Shaders compiled successfully");
}

- (void)setupGeometry {
    // Create vertices for 3 building sprites arranged in a row
    Vertex vertices[] = {
        // Building 1 (uses first sprite from atlas)
        {{-0.6f, -0.3f}, {0.0f, 0.0625f}},        // Bottom left
        {{-0.2f, -0.3f}, {0.0625f, 0.0625f}},     // Bottom right  
        {{-0.2f,  0.3f}, {0.0625f, 0.0f}},        // Top right
        {{-0.6f,  0.3f}, {0.0f, 0.0f}},           // Top left
        
        // Building 2 (second sprite)
        {{-0.1f, -0.3f}, {0.0625f, 0.0625f}},     // Bottom left
        {{ 0.3f, -0.3f}, {0.125f, 0.0625f}},      // Bottom right
        {{ 0.3f,  0.3f}, {0.125f, 0.0f}},         // Top right
        {{-0.1f,  0.3f}, {0.0625f, 0.0f}},        // Top left
        
        // Building 3 (third sprite)
        {{ 0.4f, -0.3f}, {0.125f, 0.0625f}},      // Bottom left
        {{ 0.8f, -0.3f}, {0.1875f, 0.0625f}},     // Bottom right
        {{ 0.8f,  0.3f}, {0.1875f, 0.0f}},        // Top right
        {{ 0.4f,  0.3f}, {0.125f, 0.0f}},         // Top left
    };
    
    uint16_t indices[] = {
        0, 1, 2,  2, 3, 0,    // Building 1
        4, 5, 6,  6, 7, 4,    // Building 2  
        8, 9, 10, 10, 11, 8   // Building 3
    };
    
    self.vertexBuffer = [self.device newBufferWithBytes:vertices
                                                 length:sizeof(vertices)
                                                options:MTLResourceStorageModeShared];
    
    self.indexBuffer = [self.device newBufferWithBytes:indices
                                                length:sizeof(indices)
                                               options:MTLResourceStorageModeShared];
    
    // Sampler
    MTLSamplerDescriptor *sampDesc = [[MTLSamplerDescriptor alloc] init];
    sampDesc.minFilter = MTLSamplerMinMagFilterLinear;
    sampDesc.magFilter = MTLSamplerMinMagFilterLinear;
    self.samplerState = [self.device newSamplerStateWithDescriptor:sampDesc];
    
    NSLog(@"✅ Created geometry for 3 building sprites");
}

- (void)drawInMTKView:(MTKView *)view {
    if (!self.pipelineState || !self.spriteAtlas) return;
    
    id<MTLCommandBuffer> cmd = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *pass = view.currentRenderPassDescriptor;
    
    if (pass) {
        id<MTLRenderCommandEncoder> enc = [cmd renderCommandEncoderWithDescriptor:pass];
        
        [enc setRenderPipelineState:self.pipelineState];
        [enc setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
        [enc setFragmentTexture:self.spriteAtlas atIndex:0];
        [enc setFragmentSamplerState:self.samplerState atIndex:0];
        
        [enc drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                        indexCount:18
                         indexType:MTLIndexTypeUInt16
                       indexBuffer:self.indexBuffer
                 indexBufferOffset:0];
        
        [enc endEncoding];
        [cmd presentDrawable:view.currentDrawable];
    }
    
    [cmd commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    NSLog(@"📐 Viewport: %.0fx%.0f", size.width, size.height);
}

@end

@interface DemoApp : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) BuildingDemo *demo;
@end

@implementation DemoApp

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSLog(@"🚀 Launching Building Sprite Demo...");
    
    NSRect frame = NSMakeRect(150, 150, 1200, 800);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled | 
                                                       NSWindowStyleMaskClosable | 
                                                       NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    [self.window setTitle:@"🏗️ SimCity ARM64 - Real Building Sprites!"];
    
    self.demo = [[BuildingDemo alloc] initWithFrame:frame];
    [self.window setContentView:self.demo];
    
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    NSLog(@"✅ Demo launched! You should see 3 building sprites on green grass");
    NSLog(@"🏗️ These are real isometric building sprites from our atlas");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"🎯 SimCity ARM64 - Building Sprites Demo");
        
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        
        DemoApp *delegate = [[DemoApp alloc] init];
        [app setDelegate:delegate];
        
        [app run];
    }
    return 0;
}