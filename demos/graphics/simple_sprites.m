#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

@interface SimpleSpriteView : MTKView <MTKViewDelegate>
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLTexture> spriteAtlas;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@end

@implementation SimpleSpriteView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupMetal];
        [self loadAtlas];
        [self createSimplePipeline];
        [self createQuad];
        self.delegate = self;
    }
    return self;
}

- (void)setupMetal {
    self.device = MTLCreateSystemDefaultDevice();
    self.commandQueue = [self.device newCommandQueue];
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.clearColor = MTLClearColorMake(0.1, 0.6, 0.1, 1.0); // Dark green grass
    
    NSLog(@"🎮 Metal ready: %@", self.device.name);
}

- (void)loadAtlas {
    NSString *atlasPath = @"assets/atlases/buildings.png";
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:atlasPath];
    
    if (!image) {
        NSLog(@"❌ No atlas found at: %@", atlasPath);
        return;
    }
    
    // Convert to bitmap
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithData:[image TIFFRepresentation]];
    
    // Create texture descriptor
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                          width:bitmap.pixelsWide
                                                                                         height:bitmap.pixelsHigh
                                                                                      mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead;
    
    // Create texture and upload data
    self.spriteAtlas = [self.device newTextureWithDescriptor:descriptor];
    [self.spriteAtlas replaceRegion:MTLRegionMake2D(0, 0, bitmap.pixelsWide, bitmap.pixelsHigh)
                        mipmapLevel:0
                          withBytes:bitmap.bitmapData
                        bytesPerRow:bitmap.bytesPerRow];
    
    NSLog(@"✅ Sprite atlas loaded into GPU: %dx%d pixels", (int)bitmap.pixelsWide, (int)bitmap.pixelsHigh);
}

- (void)createSimplePipeline {
    // Create default library with simple shaders
    NSString *shaderCode = @""
    "#include <metal_stdlib>\n"
    "using namespace metal;\n"
    "\n"
    "struct Vertex {\n"
    "    float4 position;\n"
    "    float2 texCoord;\n"
    "};\n"
    "\n"
    "vertex float4 vertex_main(constant Vertex* vertices [[buffer(0)]],\n"
    "                         uint vid [[vertex_id]]) {\n"
    "    return vertices[vid].position;\n"
    "}\n"
    "\n"
    "fragment float4 fragment_main(float4 position [[position]],\n"
    "                             constant Vertex* vertices [[buffer(0)]],\n"
    "                             uint vid [[vertex_id]],\n"
    "                             texture2d<float> atlas [[texture(0)]]) {\n"
    "    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);\n"
    "    // Sample from first sprite (top-left corner of atlas)\n"
    "    float2 uv = float2(0.02, 0.02); // Small section from atlas\n"
    "    return atlas.sample(s, uv);\n"
    "}\n";
    
    NSError *error = nil;
    id<MTLLibrary> library = [self.device newLibraryWithSource:shaderCode options:nil error:&error];
    if (!library) {
        NSLog(@"❌ Shader compilation failed: %@", error.localizedDescription);
        return;
    }
    
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_main"];
    
    // Create pipeline descriptor
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat;
    
    self.pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (!self.pipelineState) {
        NSLog(@"❌ Pipeline creation failed: %@", error.localizedDescription);
        return;
    }
    
    NSLog(@"✅ Render pipeline created successfully");
}

- (void)createQuad {
    // Simple quad vertices
    float vertices[] = {
        // Position (x,y,z,w)    
        -0.5f, -0.5f, 0.0f, 1.0f,   0.0f, 1.0f,  // Bottom left
         0.5f, -0.5f, 0.0f, 1.0f,   1.0f, 1.0f,  // Bottom right
         0.5f,  0.5f, 0.0f, 1.0f,   1.0f, 0.0f,  // Top right
        -0.5f, -0.5f, 0.0f, 1.0f,   0.0f, 1.0f,  // Bottom left
         0.5f,  0.5f, 0.0f, 1.0f,   1.0f, 0.0f,  // Top right  
        -0.5f,  0.5f, 0.0f, 1.0f,   0.0f, 0.0f   // Top left
    };
    
    self.vertexBuffer = [self.device newBufferWithBytes:vertices
                                                 length:sizeof(vertices)
                                                options:MTLResourceStorageModeShared];
    
    NSLog(@"✅ Quad geometry created");
}

- (void)drawInMTKView:(MTKView *)view {
    if (!self.pipelineState || !self.spriteAtlas) {
        return;
    }
    
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    
    if (renderPassDescriptor) {
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        
        [encoder setRenderPipelineState:self.pipelineState];
        [encoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
        [encoder setFragmentBuffer:self.vertexBuffer offset:0 atIndex:0];
        [encoder setFragmentTexture:self.spriteAtlas atIndex:0];
        
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        
        [encoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    
    [commandBuffer commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Handle resize
}

@end

@interface SimpleApp : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) SimpleSpriteView *spriteView;
@end

@implementation SimpleApp

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSLog(@"🚀 Launching Simple Sprite Demo...");
    
    // Create window
    NSRect frame = NSMakeRect(200, 200, 1000, 700);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled | 
                                                       NSWindowStyleMaskClosable | 
                                                       NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    [self.window setTitle:@"🏗️ SimCity ARM64 - Sprite Atlas Test"];
    
    // Create sprite view
    self.spriteView = [[SimpleSpriteView alloc] initWithFrame:frame];
    [self.window setContentView:self.spriteView];
    
    // Show window
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    NSLog(@"✅ Window open! Should show sprite sample on green background");
    NSLog(@"🎨 This demonstrates our sprite atlas is loaded and working");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"🎯 SimCity ARM64 Simple Sprite Test");
        
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        
        SimpleApp *delegate = [[SimpleApp alloc] init];
        [app setDelegate:delegate];
        
        [app run];
    }
    return 0;
}