#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

// Forward declarations for subsystems
extern int bootstrap_init(void);
extern int syscalls_init(void);
extern int threads_init(void);
extern int objc_bridge_init(void);
extern int tlsf_init(size_t size);
extern int tls_allocator_init(void);
extern int agent_allocator_init(void);
extern int metal_init(void);
extern int metal_pipeline_init(void);
extern int shader_loader_init(void);
extern int camera_init(void);
extern int sprite_batch_init(void);
extern int particle_system_init(void);
extern int debug_overlay_init(void);
extern int simulation_core_init(void);
extern int time_system_init(void);
extern int weather_system_init(void);
extern int zoning_system_init(void);
extern int economic_system_init(void);
extern int infrastructure_init(void);
extern int astar_core_init(void);
extern int navmesh_init(void);
extern int citizen_behavior_init(void);
extern int traffic_flow_init(void);
extern int emergency_services_init(void);
extern int mass_transit_init(void);
extern int save_load_init(void);
extern int asset_loader_init(void);
extern int config_parser_init(void);
extern int core_audio_init(void);
extern int spatial_audio_init(void);
extern int sound_mixer_init(void);
extern int input_handler_init(void);
extern int hud_init(void);
extern int ui_tools_init(void);
extern void process_input_events(void);
extern void simulation_update(void);
extern void ai_update(void);
extern void audio_update(void);
extern void render_frame(void);
extern void ui_update(void);
extern void calculate_frame_time(void);
extern void ui_shutdown(void);
extern void audio_shutdown(void);
extern void io_shutdown(void);
extern void ai_shutdown(void);
extern void simulation_shutdown(void);
extern void graphics_shutdown(void);
extern void platform_shutdown(void);

// Global state
static int should_quit = 0;
static int frame_count = 0;
static CFTimeInterval last_time;

// Renderer class interface
@interface SimCityRenderer : NSObject <MTKViewDelegate>
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@end

@implementation SimCityRenderer

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _device = device;
        _commandQueue = [device newCommandQueue];
        [self setupPipeline];
        [self setupBuffers];
    }
    return self;
}

- (void)setupPipeline {
    NSError *error = nil;
    
    // Combined shader source - fix the struct redefinition
    NSString *shaderSource = @R"(
        #include <metal_stdlib>
        using namespace metal;
        
        struct VertexIn {
            float2 position [[attribute(0)]];
            float3 color [[attribute(1)]];
        };
        
        struct VertexOut {
            float4 position [[position]];
            float3 color;
        };
        
        vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
            VertexOut out;
            out.position = float4(in.position, 0.0, 1.0);
            out.color = in.color;
            return out;
        }
        
        fragment float4 fragment_main(VertexOut in [[stage_in]]) {
            return float4(in.color, 1.0);
        }
    )";
    
    id<MTLLibrary> library = [self.device newLibraryWithSource:shaderSource
        options:nil error:&error];
    
    if (error) {
        NSLog(@"Error creating shader library: %@", error);
        NSLog(@"Using fallback rendering without custom shaders");
        self.pipelineState = nil;
        return;
    }
    
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_main"];
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    // Vertex descriptor
    MTLVertexDescriptor *vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat3;
    vertexDescriptor.attributes[1].offset = 8;
    vertexDescriptor.attributes[1].bufferIndex = 0;
    vertexDescriptor.layouts[0].stride = 20; // 2 floats + 3 floats = 5 * 4 = 20 bytes
    
    pipelineDescriptor.vertexDescriptor = vertexDescriptor;
    
    self.pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    
    if (error) {
        NSLog(@"Error creating pipeline state: %@", error);
        NSLog(@"Will use fallback rendering");
        self.pipelineState = nil;
    }
}

- (void)setupBuffers {
    // Create a simple triangle with animation based on frame count
    float time = frame_count * 0.016f; // ~60 FPS
    
    // Animated triangle vertices (position + color)
    float vertices[] = {
        // Position        Color (RGB)
         0.0f,  0.5f,     1.0f, 0.2f, 0.2f,  // Top - red
        -0.5f, -0.5f,     0.2f, 1.0f, 0.2f,  // Bottom left - green  
         0.5f, -0.5f,     0.2f, 0.2f, 1.0f,  // Bottom right - blue
        
        // City grid lines
        -0.8f,  0.0f,     0.5f, 0.5f, 0.5f,
         0.8f,  0.0f,     0.5f, 0.5f, 0.5f,
         
         0.0f, -0.8f,     0.5f, 0.5f, 0.5f,
         0.0f,  0.8f,     0.5f, 0.5f, 0.5f,
    };
    
    // Apply some animation
    vertices[0] = sinf(time) * 0.3f;      // Animate triangle top X
    vertices[1] = 0.5f + cosf(time) * 0.2f; // Animate triangle top Y
    
    self.vertexBuffer = [self.device newBufferWithBytes:vertices
                                                 length:sizeof(vertices)
                                                options:MTLResourceStorageModeShared];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Handle resize
}

- (void)drawInMTKView:(MTKView *)view {
    // Update frame count
    frame_count++;
    
    // Update vertex buffer with new animation
    [self setupBuffers];
    
    // Run simulation update
    simulation_update();
    ai_update();
    audio_update();
    ui_update();
    
    // Create command buffer
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    
    // Get render pass descriptor
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (!renderPassDescriptor) return;
    
    // Animate clear color to show it's working
    float time = frame_count * 0.016f; // ~60 FPS
    float r = 0.1f + 0.4f * (sinf(time * 0.5f) + 1.0f) * 0.5f;
    float g = 0.1f + 0.4f * (sinf(time * 0.7f) + 1.0f) * 0.5f;
    float b = 0.3f + 0.3f * (sinf(time * 1.1f) + 1.0f) * 0.5f;
    
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(r, g, b, 1.0);
    
    // Create render encoder
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    // Only draw if we have a valid pipeline state
    if (self.pipelineState && self.vertexBuffer) {
        [renderEncoder setRenderPipelineState:self.pipelineState];
        [renderEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
        
        // Draw triangle
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        
        // Draw grid lines
        [renderEncoder drawPrimitives:MTLPrimitiveTypeLine vertexStart:3 vertexCount:4];
    }
    
    [renderEncoder endEncoding];
    
    // Take automatic screenshot
    if (frame_count == 120) { // 2 seconds
        printf("📸 Taking automatic screenshot...\n");
        
        // Wait for the command buffer to complete before capturing
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self captureMetalViewToFile:@"window_screenshot.png" view:view];
            });
        }];
    }
    
    // Present
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
    
    // Exit after a while for demo
    if (frame_count > 600) { // 10 seconds at 60fps
        should_quit = 1;
        [NSApp terminate:nil];
    }
    
    // Print status every second
    if (frame_count % 60 == 0) {
        printf("SimCity ARM64: Frame %d - Animated colors (R:%.2f G:%.2f B:%.2f)\n", frame_count, r, g, b);
    }
}

- (void)captureMetalViewToFile:(NSString *)filename view:(MTKView *)mtkView {
    // Get the current drawable's texture
    id<CAMetalDrawable> drawable = mtkView.currentDrawable;
    if (!drawable || !drawable.texture) {
        printf("Warning: No drawable available for screenshot\n");
        return;
    }
    
    id<MTLTexture> texture = drawable.texture;
    
    // Get texture dimensions
    NSUInteger width = texture.width;
    NSUInteger height = texture.height;
    NSUInteger bytesPerRow = width * 4; // BGRA8 = 4 bytes per pixel
    
    // Allocate memory for texture data
    void *imageBytes = malloc(height * bytesPerRow);
    if (!imageBytes) {
        printf("Failed to allocate memory for screenshot\n");
        return;
    }
    
    // Copy texture data to CPU
    [texture getBytes:imageBytes
          bytesPerRow:bytesPerRow
           fromRegion:MTLRegionMake2D(0, 0, width, height)
          mipmapLevel:0];
    
    // Create CGImage from the raw data
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(imageBytes, width, height, 8, bytesPerRow, colorSpace,
                                                  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    if (!context) {
        printf("Failed to create bitmap context for screenshot\n");
        free(imageBytes);
        CGColorSpaceRelease(colorSpace);
        return;
    }
    
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    
    // Create bitmap representation and save as PNG
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    NSData *pngData = [bitmapRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    
    BOOL success = [pngData writeToFile:filename atomically:YES];
    if (success) {
        printf("Screenshot saved successfully: %ld x %ld pixels\n", (long)width, (long)height);
    } else {
        printf("Failed to save screenshot to file\n");
    }
    
    // Clean up
    CGImageRelease(cgImage);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(imageBytes);
}

@end

// Window delegate
@interface SimCityWindowDelegate : NSObject <NSWindowDelegate>
@end

@implementation SimCityWindowDelegate

- (BOOL)windowShouldClose:(NSWindow *)window {
    should_quit = 1;
    [NSApp terminate:nil];
    return YES;
}

@end

// Application delegate
@interface SimCityAppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, strong) SimCityRenderer *renderer;
@property (nonatomic, strong) SimCityWindowDelegate *windowDelegate;
@end

@implementation SimCityAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    printf("\n=== SimCity ARM64 Engine Starting ===\n");
    printf("Opening Metal window...\n");
    printf("Integrated ARM64 assembly modules: 25+\n");
    printf("Target performance: 1M+ agents @ 60 FPS\n");
    printf("Platform: Apple Silicon\n\n");
    
    // Initialize all subsystems
    printf("Initializing platform...\n");
    bootstrap_init();
    syscalls_init();
    threads_init();
    objc_bridge_init();
    
    printf("Initializing memory...\n");
    tlsf_init(1024 * 1024 * 1024); // 1GB
    tls_allocator_init();
    agent_allocator_init();
    
    printf("Initializing graphics...\n");
    metal_init();
    metal_pipeline_init();
    shader_loader_init();
    camera_init();
    sprite_batch_init();
    particle_system_init();
    debug_overlay_init();
    
    printf("Initializing simulation...\n");
    simulation_core_init();
    time_system_init();
    weather_system_init();
    zoning_system_init();
    economic_system_init();
    infrastructure_init();
    
    printf("Initializing AI...\n");
    astar_core_init();
    navmesh_init();
    citizen_behavior_init();
    traffic_flow_init();
    emergency_services_init();
    mass_transit_init();
    
    printf("Initializing I/O...\n");
    save_load_init();
    asset_loader_init();
    config_parser_init();
    
    printf("Initializing audio...\n");
    core_audio_init();
    spatial_audio_init();
    sound_mixer_init();
    
    printf("Initializing UI...\n");
    input_handler_init();
    hud_init();
    ui_tools_init();
    
    // Create Metal device
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        printf("Metal is not supported on this device\n");
        [NSApp terminate:nil];
        return;
    }
    
    printf("Metal device: %s\n", [device.name UTF8String]);
    
    // Create window
    NSRect windowFrame = NSMakeRect(100, 100, 1024, 768);
    self.window = [[NSWindow alloc] initWithContentRect:windowFrame
                                              styleMask:NSWindowStyleMaskTitled | 
                                                       NSWindowStyleMaskClosable |
                                                       NSWindowStyleMaskResizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    [self.window setTitle:@"SimCity ARM64 - Integrated Engine Demo"];
    [self.window makeKeyAndOrderFront:nil];
    
    // Create Metal view
    self.mtkView = [[MTKView alloc] initWithFrame:windowFrame device:device];
    self.mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.mtkView.preferredFramesPerSecond = 60;
    
    // Create renderer
    self.renderer = [[SimCityRenderer alloc] initWithDevice:device];
    self.mtkView.delegate = self.renderer;
    
    // Create window delegate
    self.windowDelegate = [[SimCityWindowDelegate alloc] init];
    self.window.delegate = self.windowDelegate;
    
    // Set Metal view as content view
    [self.window setContentView:self.mtkView];
    [self.window center];
    
    printf("\nSimCity ARM64 window opened successfully!\n");
    printf("Running simulation with Metal rendering...\n\n");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    printf("\nShutting down...\n");
    ui_shutdown();
    audio_shutdown();
    io_shutdown();
    ai_shutdown();
    simulation_shutdown();
    graphics_shutdown();
    platform_shutdown();
    
    printf("\n=== SimCity ARM64 Engine Shutdown ===\n");
    printf("Total frames rendered: %d\n", frame_count);
    printf("Demo completed successfully!\n");
}

@end

int main(int argc, char* argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        
        SimCityAppDelegate *delegate = [[SimCityAppDelegate alloc] init];
        [app setDelegate:delegate];
        
        [app run];
    }
    return 0;
}