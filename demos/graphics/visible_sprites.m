#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

@interface VisibleSpritesView : MTKView <MTKViewDelegate>
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLTexture> spriteAtlas;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLSamplerState> samplerState;
@end

@implementation VisibleSpritesView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupMetal];
        [self loadAtlas];
        [self createShaders];
        [self createVertices];
        self.delegate = self;
    }
    return self;
}

- (void)setupMetal {
    self.device = MTLCreateSystemDefaultDevice();
    self.commandQueue = [self.device newCommandQueue];
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.clearColor = MTLClearColorMake(0.5, 0.8, 1.0, 1.0); // Sky blue background
    
    NSLog(@"🎮 Metal GPU ready: %@", self.device.name);
}

- (void)loadAtlas {
    NSString *atlasPath = @"assets/atlases/buildings.png";
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:atlasPath];
    
    if (!image) {
        NSLog(@"❌ Cannot find sprite atlas at: %@", atlasPath);
        return;
    }
    
    // Get image representation
    CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
    if (!cgImage) {
        NSLog(@"❌ Cannot get CGImage from NSImage");
        return;
    }
    
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    
    // Create raw RGBA data
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
    
    NSLog(@"✅ Sprite atlas loaded: %zux%zu pixels with real bitmap data", width, height);
}

- (void)createShaders {
    // Very simple shaders that will definitely work
    NSString *shaderSource = @""
    "#include <metal_stdlib>\n"
    "using namespace metal;\n"
    "\n"
    "struct VertexOut {\n"
    "    float4 position [[position]];\n"
    "    float2 texCoord;\n"
    "};\n"
    "\n"
    "vertex VertexOut vertex_main(uint vertexID [[vertex_id]]) {\n"
    "    VertexOut out;\n"
    "    \n"
    "    // Create a triangle that covers most of the screen\n"
    "    float2 positions[3] = {\n"
    "        float2(-0.8, -0.8),\n"
    "        float2( 0.8, -0.8),\n"
    "        float2( 0.0,  0.8)\n"
    "    };\n"
    "    \n"
    "    // UV coordinates that sample from the top-left of our atlas\n"
    "    float2 uvs[3] = {\n"
    "        float2(0.0, 0.1),    // Sample from atlas top area\n"
    "        float2(0.1, 0.1),\n"
    "        float2(0.05, 0.0)\n"
    "    };\n"
    "    \n"
    "    out.position = float4(positions[vertexID], 0.0, 1.0);\n"
    "    out.texCoord = uvs[vertexID];\n"
    "    \n"
    "    return out;\n"
    "}\n"
    "\n"
    "fragment float4 fragment_main(VertexOut in [[stage_in]],\n"
    "                             texture2d<float> atlas [[texture(0)]]) {\n"
    "    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::nearest);\n"
    "    \n"
    "    // Sample the atlas texture\n"
    "    float4 color = atlas.sample(s, in.texCoord);\n"
    "    \n"
    "    // Make sure we see something - if texture is transparent, show red\n"
    "    if (color.a < 0.1) {\n"
    "        return float4(1.0, 0.0, 0.0, 1.0); // Red if no sprite data\n"
    "    }\n"
    "    \n"
    "    return color;\n"
    "}\n";
    
    NSError *error = nil;
    id<MTLLibrary> library = [self.device newLibraryWithSource:shaderSource options:nil error:&error];
    if (!library) {
        NSLog(@"❌ Shader compilation error: %@", error.localizedDescription);
        return;
    }
    
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_main"];
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat;
    
    self.pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (!self.pipelineState) {
        NSLog(@"❌ Pipeline creation error: %@", error.localizedDescription);
        return;
    }
    
    NSLog(@"✅ Shaders compiled - ready to display sprites!");
}

- (void)createVertices {
    // We don't need vertex buffer since we're generating vertices in the shader
    NSLog(@"✅ Using procedural vertex generation in shader");
}

- (void)drawInMTKView:(MTKView *)view {
    if (!self.pipelineState || !self.spriteAtlas) {
        return;
    }
    
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    commandBuffer.label = @"Sprite Display Command";
    
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor) {
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        encoder.label = @"Sprite Render Encoder";
        
        [encoder setRenderPipelineState:self.pipelineState];
        [encoder setFragmentTexture:self.spriteAtlas atIndex:0];
        
        // Draw a triangle that will show part of our sprite atlas
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        
        [encoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    
    [commandBuffer commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    NSLog(@"📐 Window resized to: %.0fx%.0f", size.width, size.height);
}

@end

@interface VisibleApp : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) VisibleSpritesView *spriteView;
@end

@implementation VisibleApp

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSLog(@"🚀 Launching VISIBLE Sprites Demo...");
    
    // Create window
    NSRect frame = NSMakeRect(300, 300, 1000, 700);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled | 
                                                       NSWindowStyleMaskClosable | 
                                                       NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    [self.window setTitle:@"🎨 SimCity ARM64 - VISIBLE Building Sprites"];
    
    // Create sprite view
    self.spriteView = [[VisibleSpritesView alloc] initWithFrame:frame];
    [self.window setContentView:self.spriteView];
    
    // Show window and bring to front
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    NSLog(@"✅ Window launched! You SHOULD see actual sprite content now!");
    NSLog(@"🎨 Look for a triangle showing building sprites from our atlas");
    NSLog(@"🔴 If you see red, that means texture coords need adjustment");
    NSLog(@"🏗️ If you see building graphics, SUCCESS!");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"🎯 SimCity ARM64 - VISIBLE Sprites Test");
        NSLog(@"📋 This version will definitely show visual content!");
        
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        
        VisibleApp *delegate = [[VisibleApp alloc] init];
        [app setDelegate:delegate];
        
        [app run];
    }
    return 0;
}