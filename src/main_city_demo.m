#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <math.h>
#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

// Forward declarations for subsystems
extern int bootstrap_init(void);
extern int metal_init(void);
extern int simulation_core_init(void);
extern int astar_core_init(void);
extern void simulation_update(void);
extern void ai_update(void);
extern void audio_update(void);
extern void ui_update(void);

// Global state
static int frame_count = 0;
static float camera_x = 0.0f;
static float camera_y = 0.0f;
static float zoom = 1.0f;

// City simulation data
typedef struct {
    float x, y;
    float r, g, b;
    int type; // 0=residential, 1=commercial, 2=industrial, 3=road
    float growth;
} CityTile;

static CityTile city_grid[50][50];
static int city_width = 50;
static int city_height = 50;

// Initialize city with procedural generation
void init_city() {
    for (int x = 0; x < city_width; x++) {
        for (int y = 0; y < city_height; y++) {
            CityTile *tile = &city_grid[x][y];
            tile->x = (x - city_width/2) * 0.04f;
            tile->y = (y - city_height/2) * 0.04f;
            
            // Create road network
            if (x % 5 == 0 || y % 5 == 0) {
                tile->type = 3; // Road
                tile->r = 0.3f;
                tile->g = 0.3f;
                tile->b = 0.3f;
            }
            // Create districts
            else if (x < city_width/3) {
                tile->type = 0; // Residential
                tile->r = 0.2f + (rand() % 100) / 500.0f;
                tile->g = 0.6f + (rand() % 100) / 500.0f;
                tile->b = 0.2f + (rand() % 100) / 500.0f;
            }
            else if (x < 2*city_width/3) {
                tile->type = 1; // Commercial
                tile->r = 0.2f + (rand() % 100) / 500.0f;
                tile->g = 0.2f + (rand() % 100) / 500.0f;
                tile->b = 0.6f + (rand() % 100) / 500.0f;
            }
            else {
                tile->type = 2; // Industrial
                tile->r = 0.6f + (rand() % 100) / 500.0f;
                tile->g = 0.3f + (rand() % 100) / 500.0f;
                tile->b = 0.1f + (rand() % 100) / 500.0f;
            }
            
            tile->growth = (rand() % 100) / 100.0f;
        }
    }
}

// Update city simulation
void update_city() {
    for (int x = 1; x < city_width-1; x++) {
        for (int y = 1; y < city_height-1; y++) {
            CityTile *tile = &city_grid[x][y];
            
            if (tile->type != 3) { // Not a road
                // Growth simulation
                tile->growth += 0.001f * (rand() % 10 - 5);
                if (tile->growth > 1.0f) tile->growth = 1.0f;
                if (tile->growth < 0.0f) tile->growth = 0.0f;
                
                // Animate colors based on growth
                float pulse = sinf(frame_count * 0.01f + tile->x * 10.0f + tile->y * 10.0f) * 0.1f;
                
                if (tile->type == 0) { // Residential
                    tile->g = 0.6f + tile->growth * 0.3f + pulse;
                }
                else if (tile->type == 1) { // Commercial
                    tile->b = 0.6f + tile->growth * 0.3f + pulse;
                }
                else if (tile->type == 2) { // Industrial
                    tile->r = 0.6f + tile->growth * 0.3f + pulse;
                }
            }
        }
    }
}

// City Renderer
@interface CityRenderer : NSObject <MTKViewDelegate>
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@end

@implementation CityRenderer

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _device = device;
        _commandQueue = [device newCommandQueue];
        [self setupPipeline];
        init_city();
    }
    return self;
}

- (void)setupPipeline {
    NSError *error = nil;
    
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
    
    id<MTLLibrary> library = [self.device newLibraryWithSource:shaderSource options:nil error:&error];
    
    if (error) {
        NSLog(@"Shader error: %@", error);
        self.pipelineState = nil;
        return;
    }
    
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_main"];
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    MTLVertexDescriptor *vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat3;
    vertexDescriptor.attributes[1].offset = 8;
    vertexDescriptor.attributes[1].bufferIndex = 0;
    vertexDescriptor.layouts[0].stride = 20;
    
    pipelineDescriptor.vertexDescriptor = vertexDescriptor;
    
    self.pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    
    if (error) {
        NSLog(@"Pipeline error: %@", error);
        self.pipelineState = nil;
    }
}

- (void)updateVertexBuffer {
    // Create vertex data for the entire city
    int maxVertices = city_width * city_height * 6; // 2 triangles per tile
    float *vertices = malloc(maxVertices * 5 * sizeof(float)); // 5 floats per vertex (x,y,r,g,b)
    int vertexCount = 0;
    
    for (int x = 0; x < city_width; x++) {
        for (int y = 0; y < city_height; y++) {
            CityTile *tile = &city_grid[x][y];
            
            float size = 0.018f;
            if (tile->type != 3) { // Not road - make buildings taller
                size += tile->growth * 0.015f;
            }
            
            float x1 = tile->x - size;
            float y1 = tile->y - size;
            float x2 = tile->x + size;
            float y2 = tile->y + size;
            
            // Triangle 1
            vertices[vertexCount*5 + 0] = x1; vertices[vertexCount*5 + 1] = y1;
            vertices[vertexCount*5 + 2] = tile->r; vertices[vertexCount*5 + 3] = tile->g; vertices[vertexCount*5 + 4] = tile->b;
            vertexCount++;
            
            vertices[vertexCount*5 + 0] = x2; vertices[vertexCount*5 + 1] = y1;
            vertices[vertexCount*5 + 2] = tile->r; vertices[vertexCount*5 + 3] = tile->g; vertices[vertexCount*5 + 4] = tile->b;
            vertexCount++;
            
            vertices[vertexCount*5 + 0] = x1; vertices[vertexCount*5 + 1] = y2;
            vertices[vertexCount*5 + 2] = tile->r; vertices[vertexCount*5 + 3] = tile->g; vertices[vertexCount*5 + 4] = tile->b;
            vertexCount++;
            
            // Triangle 2
            vertices[vertexCount*5 + 0] = x2; vertices[vertexCount*5 + 1] = y1;
            vertices[vertexCount*5 + 2] = tile->r; vertices[vertexCount*5 + 3] = tile->g; vertices[vertexCount*5 + 4] = tile->b;
            vertexCount++;
            
            vertices[vertexCount*5 + 0] = x2; vertices[vertexCount*5 + 1] = y2;
            vertices[vertexCount*5 + 2] = tile->r; vertices[vertexCount*5 + 3] = tile->g; vertices[vertexCount*5 + 4] = tile->b;
            vertexCount++;
            
            vertices[vertexCount*5 + 0] = x1; vertices[vertexCount*5 + 1] = y2;
            vertices[vertexCount*5 + 2] = tile->r; vertices[vertexCount*5 + 3] = tile->g; vertices[vertexCount*5 + 4] = tile->b;
            vertexCount++;
        }
    }
    
    self.vertexBuffer = [self.device newBufferWithBytes:vertices
                                                 length:vertexCount * 5 * sizeof(float)
                                                options:MTLResourceStorageModeShared];
    free(vertices);
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Handle resize
}

- (void)drawInMTKView:(MTKView *)view {
    frame_count++;
    
    // Update city simulation
    update_city();
    
    // Update camera (slow pan)
    camera_x = sinf(frame_count * 0.002f) * 0.2f;
    camera_y = cosf(frame_count * 0.003f) * 0.15f;
    
    // Update vertex buffer with new city state
    [self updateVertexBuffer];
    
    // Run subsystems
    simulation_update();
    ai_update();
    audio_update();
    ui_update();
    
    // Render
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (!renderPassDescriptor) return;
    
    // Sky color that changes from day to night
    float dayNight = (sinf(frame_count * 0.004f) + 1.0f) * 0.5f;
    float skyR = 0.1f + dayNight * 0.4f;
    float skyG = 0.2f + dayNight * 0.5f;
    float skyB = 0.3f + dayNight * 0.3f;
    
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(skyR, skyG, skyB, 1.0);
    
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    if (self.pipelineState && self.vertexBuffer) {
        [renderEncoder setRenderPipelineState:self.pipelineState];
        [renderEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
        
        // Draw the entire city
        int tileCount = city_width * city_height;
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:tileCount * 6];
    }
    
    [renderEncoder endEncoding];
    
    // Take screenshot after city is fully loaded and visible
    if (frame_count == 180) { // 3 seconds to let city stabilize
        printf("📸 Taking automatic screenshot...\n");
        
        // Wait for the command buffer to complete before capturing
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self captureMetalViewToFile:@"city_screenshot.png" view:view];
            });
        }];
    }
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
    
    // Status updates
    if (frame_count % 60 == 0) {
        printf("SimCity ARM64: Frame %d - %dx%d city, Day/Night: %.1f%%, Camera: (%.2f, %.2f)\n", 
               frame_count, city_width, city_height, dayNight * 100.0f, camera_x, camera_y);
    }
    
    // Run for longer demo
    if (frame_count > 1200) { // 20 seconds
        printf("\nCity simulation demo complete!\n");
        [NSApp terminate:nil];
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

// Application delegate
@interface CityAppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, strong) CityRenderer *renderer;
@end

@implementation CityAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    printf("\n=== SimCity ARM64 - CITY SIMULATION DEMO ===\n");
    printf("Generating procedural city with districts...\n");
    printf("🏘️  Residential (Green) | 🏢 Commercial (Blue) | 🏭 Industrial (Red)\n");
    printf("🛣️  Road network connecting all districts\n");
    printf("📈 Real-time growth simulation with day/night cycle\n\n");
    
    // Initialize subsystems
    bootstrap_init();
    metal_init();
    simulation_core_init();
    astar_core_init();
    
    // Create Metal device
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    printf("Metal device: %s\n\n", [device.name UTF8String]);
    
    // Create larger window for city view
    NSRect frame = NSMakeRect(100, 100, 1200, 900);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    [self.window setTitle:@"SimCity ARM64 - Live City Simulation"];
    
    // Create Metal view
    self.mtkView = [[MTKView alloc] initWithFrame:frame device:device];
    self.mtkView.preferredFramesPerSecond = 60;
    
    // Create city renderer
    self.renderer = [[CityRenderer alloc] initWithDevice:device];
    self.mtkView.delegate = self.renderer;
    
    [self.window setContentView:self.mtkView];
    [self.window makeKeyAndOrderFront:nil];
    [self.window center];
    
    printf("🏙️ City window opened! Watch the living, breathing city simulation!\n\n");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return YES;
}

@end

int main(int argc, char* argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        
        CityAppDelegate *delegate = [[CityAppDelegate alloc] init];
        [app setDelegate:delegate];
        
        [app run];
    }
    return 0;
}