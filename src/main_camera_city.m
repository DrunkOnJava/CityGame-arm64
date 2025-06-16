#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <simd/simd.h>
#import <mach/mach_time.h>

// Camera state structure (matches assembly)
typedef struct {
    float iso_x, iso_y;
    float world_x, world_z;
    float height;
    float rotation;
    float vel_x, vel_z;
    float zoom_vel;
    float rot_vel;
    float edge_pan_x, edge_pan_z;
    uint32_t bounce_timer;
    uint32_t _padding[3];
} CameraState;

// Input state structure
typedef struct {
    uint32_t keys;
    uint32_t _pad1, _pad2, _pad3;
    int32_t mouse_x, mouse_y;
    int32_t mouse_delta_x, mouse_delta_y;
    uint32_t mouse_buttons;
    int16_t scroll_y;
    uint16_t _pad4;
} InputState;

// External camera functions
extern void camera_update(InputState* input, float delta_time);
extern CameraState camera_state;
extern float camera_view_matrix[16];

// City tile structure
typedef struct {
    float x, y, z;
    float r, g, b;
    int type;
    float size;
} CityTile;

#define CITY_SIZE 100
static CityTile city_grid[CITY_SIZE][CITY_SIZE];
static InputState g_input = {0};
static int last_mouse_x = 0;
static int last_mouse_y = 0;
static uint64_t last_time = 0;

// Initialize city
static void init_city() {
    for (int x = 0; x < CITY_SIZE; x++) {
        for (int z = 0; z < CITY_SIZE; z++) {
            city_grid[x][z].x = x;
            city_grid[x][z].z = z;
            city_grid[x][z].y = 0;
            
            // Zone coloring
            if (x < CITY_SIZE * 0.4) {
                // Residential - green
                city_grid[x][z].r = 0.2f;
                city_grid[x][z].g = 0.8f;
                city_grid[x][z].b = 0.3f;
                city_grid[x][z].type = 0;
            } else if (x < CITY_SIZE * 0.7) {
                // Commercial - blue
                city_grid[x][z].r = 0.3f;
                city_grid[x][z].g = 0.4f;
                city_grid[x][z].b = 0.9f;
                city_grid[x][z].type = 1;
            } else {
                // Industrial - orange
                city_grid[x][z].r = 0.9f;
                city_grid[x][z].g = 0.5f;
                city_grid[x][z].b = 0.2f;
                city_grid[x][z].type = 2;
            }
            
            // Random building heights
            if ((x % 5 != 0 && z % 5 != 0) && (rand() % 100 < 70)) {
                city_grid[x][z].size = 0.5f + (rand() % 100) / 50.0f;
            } else {
                city_grid[x][z].size = 0.0f; // Road
                city_grid[x][z].r *= 0.3f;
                city_grid[x][z].g *= 0.3f;
                city_grid[x][z].b *= 0.3f;
            }
        }
    }
}

// Camera city renderer
@interface CameraCityRenderer : NSObject <MTKViewDelegate>
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic) NSUInteger vertexCount;
@property (nonatomic) NSUInteger frameCount;
@end

@implementation CameraCityRenderer

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        self.device = device;
        self.commandQueue = [device newCommandQueue];
        self.frameCount = 0;
        [self setupPipeline];
    }
    return self;
}

- (void)setupPipeline {
    NSError *error = nil;
    
    NSString *shaderSource = @"#include <metal_stdlib>\n"
        "using namespace metal;\n"
        "\n"
        "struct VertexIn {\n"
        "    float3 position [[attribute(0)]];\n"
        "    float3 color [[attribute(1)]];\n"
        "};\n"
        "\n"
        "struct VertexOut {\n"
        "    float4 position [[position]];\n"
        "    float3 color;\n"
        "};\n"
        "\n"
        "vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {\n"
        "    VertexOut out;\n"
        "    \n"
        "    // Apply camera transform\n"
        "    float3 worldPos = in.position;\n"
        "    \n"
        "    // Get camera offset from global state\n"
        "    float camX = 50.0;\n"
        "    float camZ = 50.0;\n"
        "    float camHeight = 100.0;\n"
        "    \n"
        "    // Translate by camera position\n"
        "    worldPos.x -= camX;\n"
        "    worldPos.z -= camZ;\n"
        "    \n"
        "    // Isometric projection\n"
        "    float2 iso;\n"
        "    iso.x = (worldPos.x - worldPos.z) * 0.866;\n"
        "    iso.y = (worldPos.x + worldPos.z) * 0.5 - worldPos.y * 2.0;\n"
        "    \n"
        "    // Scale based on camera height\n"
        "    float scale = 50.0 / camHeight;\n"
        "    out.position = float4(iso.x * scale * 0.02, iso.y * scale * 0.02,\n"
        "                          0.5 + (worldPos.x + worldPos.z) * 0.001, 1.0);\n"
        "    out.color = in.color;\n"
        "    return out;\n"
        "}\n"
        "\n"
        "fragment float4 fragment_main(VertexOut in [[stage_in]]) {\n"
        "    return float4(in.color, 1.0);\n"
        "}\n";
    
    id<MTLLibrary> library = [self.device newLibraryWithSource:shaderSource options:nil error:&error];
    if (error) {
        NSLog(@"Shader error: %@", error);
        return;
    }
    
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_main"];
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    MTLVertexDescriptor *vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat3;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat3;
    vertexDescriptor.attributes[1].offset = 12;
    vertexDescriptor.attributes[1].bufferIndex = 0;
    vertexDescriptor.layouts[0].stride = 24;
    
    pipelineDescriptor.vertexDescriptor = vertexDescriptor;
    
    self.pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (error) {
        NSLog(@"Pipeline error: %@", error);
    }
}

- (void)generateCityGeometry {
    // Calculate visible bounds based on camera
    float cam_x = camera_state.world_x;
    float cam_z = camera_state.world_z;
    float view_range = camera_state.height * 0.5f;
    
    int min_x = fmax(0, cam_x - view_range);
    int max_x = fmin(CITY_SIZE, cam_x + view_range);
    int min_z = fmax(0, cam_z - view_range);
    int max_z = fmin(CITY_SIZE, cam_z + view_range);
    
    // Count visible tiles
    int visibleTiles = 0;
    for (int x = min_x; x < max_x; x++) {
        for (int z = min_z; z < max_z; z++) {
            if (city_grid[x][z].size > 0) visibleTiles++;
        }
    }
    
    // Generate vertices for visible area only
    int maxVertices = visibleTiles * 36; // 6 faces * 2 triangles * 3 vertices
    float *vertices = malloc(maxVertices * 6 * sizeof(float));
    int vertexIndex = 0;
    
    for (int x = min_x; x < max_x; x++) {
        for (int z = min_z; z < max_z; z++) {
            CityTile *tile = &city_grid[x][z];
            if (tile->size == 0) continue;
            
            float h = tile->size * 2.0f;
            float w = 0.4f;
            
            // Simple box geometry (top face only for performance)
            float box_verts[] = {
                // Top face
                x-w, h, z-w,  tile->r, tile->g, tile->b,
                x+w, h, z-w,  tile->r, tile->g, tile->b,
                x+w, h, z+w,  tile->r, tile->g, tile->b,
                x-w, h, z-w,  tile->r, tile->g, tile->b,
                x+w, h, z+w,  tile->r, tile->g, tile->b,
                x-w, h, z+w,  tile->r, tile->g, tile->b,
                
                // Front face
                x-w, 0, z-w,  tile->r*0.8f, tile->g*0.8f, tile->b*0.8f,
                x+w, 0, z-w,  tile->r*0.8f, tile->g*0.8f, tile->b*0.8f,
                x+w, h, z-w,  tile->r*0.8f, tile->g*0.8f, tile->b*0.8f,
                x-w, 0, z-w,  tile->r*0.8f, tile->g*0.8f, tile->b*0.8f,
                x+w, h, z-w,  tile->r*0.8f, tile->g*0.8f, tile->b*0.8f,
                x-w, h, z-w,  tile->r*0.8f, tile->g*0.8f, tile->b*0.8f,
            };
            
            memcpy(&vertices[vertexIndex], box_verts, sizeof(box_verts));
            vertexIndex += 12 * 6;
        }
    }
    
    self.vertexCount = vertexIndex / 6;
    
    if (self.vertexCount > 0) {
        self.vertexBuffer = [self.device newBufferWithBytes:vertices 
                                                     length:vertexIndex * sizeof(float) 
                                                    options:MTLResourceStorageModeShared];
    }
    
    free(vertices);
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
}

- (void)drawInMTKView:(MTKView *)view {
    self.frameCount++;
    
    // Calculate delta time
    uint64_t current_time = mach_absolute_time();
    if (last_time == 0) last_time = current_time;
    float delta_time = (current_time - last_time) / 1000000000.0f;
    last_time = current_time;
    
    // Update camera
    camera_update(&g_input, delta_time);
    
    // Rebuild shader with new camera position (simplified approach)
    
    // Generate visible geometry
    [self generateCityGeometry];
    
    // Clear inputs for next frame
    g_input.mouse_delta_x = 0;
    g_input.mouse_delta_y = 0;
    g_input.scroll_y = 0;
    
    // Render
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (!renderPassDescriptor) return;
    
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.7, 0.9, 1.0);
    
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    if (self.pipelineState && self.vertexBuffer && self.vertexCount > 0) {
        [renderEncoder setRenderPipelineState:self.pipelineState];
        [renderEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:self.vertexCount];
    }
    
    [renderEncoder endEncoding];
    
    // Take screenshot
    if (self.frameCount == 180) {
        printf("📸 Taking screenshot with camera controls...\n");
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self captureScreenshot:view];
            });
        }];
    }
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
    
    // Status
    if (self.frameCount % 60 == 0) {
        printf("Camera: World(%.1f, %.1f) Height:%.1f Vel:(%.2f, %.2f)\n",
               camera_state.world_x, camera_state.world_z, camera_state.height,
               camera_state.vel_x, camera_state.vel_z);
    }
}

- (void)captureScreenshot:(MTKView *)view {
    id<CAMetalDrawable> drawable = view.currentDrawable;
    if (!drawable) return;
    
    id<MTLTexture> texture = drawable.texture;
    NSUInteger width = texture.width;
    NSUInteger height = texture.height;
    NSUInteger bytesPerRow = width * 4;
    
    void *imageBytes = malloc(height * bytesPerRow);
    if (!imageBytes) return;
    
    [texture getBytes:imageBytes
          bytesPerRow:bytesPerRow
           fromRegion:MTLRegionMake2D(0, 0, width, height)
          mipmapLevel:0];
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(imageBytes, width, height, 8, bytesPerRow, colorSpace,
                                                  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    if (!context) {
        free(imageBytes);
        CGColorSpaceRelease(colorSpace);
        return;
    }
    
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    NSData *pngData = [bitmapRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    
    [pngData writeToFile:@"camera_city_screenshot.png" atomically:YES];
    printf("📸 Screenshot saved as camera_city_screenshot.png\n");
    
    CGImageRelease(cgImage);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(imageBytes);
}

@end

// Window with input handling
@interface CameraWindow : NSWindow
@end

@implementation CameraWindow

- (void)keyDown:(NSEvent *)event {
    switch(event.keyCode) {
        case 126: g_input.keys |= (1 << 0); break; // Up
        case 125: g_input.keys |= (1 << 1); break; // Down
        case 123: g_input.keys |= (1 << 2); break; // Left
        case 124: g_input.keys |= (1 << 3); break; // Right
        case 56:  g_input.keys |= (1 << 4); break; // Shift
        case 13:  g_input.keys |= (1 << 5); break; // W
        case 0:   g_input.keys |= (1 << 6); break; // A
        case 1:   g_input.keys |= (1 << 7); break; // S
        case 2:   g_input.keys |= (1 << 8); break; // D
    }
}

- (void)keyUp:(NSEvent *)event {
    switch(event.keyCode) {
        case 126: g_input.keys &= ~(1 << 0); break;
        case 125: g_input.keys &= ~(1 << 1); break;
        case 123: g_input.keys &= ~(1 << 2); break;
        case 124: g_input.keys &= ~(1 << 3); break;
        case 56:  g_input.keys &= ~(1 << 4); break;
        case 13:  g_input.keys &= ~(1 << 5); break;
        case 0:   g_input.keys &= ~(1 << 6); break;
        case 1:   g_input.keys &= ~(1 << 7); break;
        case 2:   g_input.keys &= ~(1 << 8); break;
    }
}

- (void)scrollWheel:(NSEvent *)event {
    g_input.scroll_y = event.deltaY * 10;
}

- (void)mouseMoved:(NSEvent *)event {
    NSPoint loc = [event locationInWindow];
    g_input.mouse_x = loc.x;
    g_input.mouse_y = self.frame.size.height - loc.y;
}

- (void)mouseDragged:(NSEvent *)event {
    [self mouseMoved:event];
    if (last_mouse_x != 0) {
        g_input.mouse_delta_x = g_input.mouse_x - last_mouse_x;
        g_input.mouse_delta_y = g_input.mouse_y - last_mouse_y;
    }
    last_mouse_x = g_input.mouse_x;
    last_mouse_y = g_input.mouse_y;
}

- (void)mouseDown:(NSEvent *)event {
    g_input.mouse_buttons |= 1;
    last_mouse_x = g_input.mouse_x;
    last_mouse_y = g_input.mouse_y;
}

- (void)mouseUp:(NSEvent *)event {
    g_input.mouse_buttons &= ~1;
    last_mouse_x = 0;
    last_mouse_y = 0;
}

- (void)rightMouseDragged:(NSEvent *)event {
    [self mouseMoved:event];
    if (last_mouse_x != 0) {
        g_input.mouse_delta_x = g_input.mouse_x - last_mouse_x;
        g_input.mouse_delta_y = g_input.mouse_y - last_mouse_y;
    }
    last_mouse_x = g_input.mouse_x;
    last_mouse_y = g_input.mouse_y;
}

- (void)rightMouseDown:(NSEvent *)event {
    g_input.mouse_buttons |= 2;
    last_mouse_x = g_input.mouse_x;
    last_mouse_y = g_input.mouse_y;
}

- (void)rightMouseUp:(NSEvent *)event {
    g_input.mouse_buttons &= ~2;
    last_mouse_x = 0;
    last_mouse_y = 0;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

@end

// App delegate
@interface CameraCityAppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) CameraWindow *window;
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, strong) CameraCityRenderer *renderer;
@end

@implementation CameraCityAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    printf("\n=== SimCity ARM64 - Camera Controller Demo ===\n");
    printf("Controls:\n");
    printf("  🎮 WASD/Arrows: Move camera\n");
    printf("  ⚡ Shift: 2.5x speed\n");
    printf("  🔍 Mouse Wheel: Zoom\n");
    printf("  🖱️  Left Drag: Pan\n");
    printf("  🔄 Right Drag: Rotate\n\n");
    
    init_city();
    
    NSRect frame = NSMakeRect(100, 100, 1280, 720);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable;
    self.window = [[CameraWindow alloc] initWithContentRect:frame styleMask:style backing:NSBackingStoreBuffered defer:NO];
    [self.window setTitle:@"SimCity ARM64 - Camera Controller Demo"];
    [self.window makeFirstResponder:self.window];
    
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    self.mtkView = [[MTKView alloc] initWithFrame:frame device:device];
    self.mtkView.preferredFramesPerSecond = 60;
    
    self.renderer = [[CameraCityRenderer alloc] initWithDevice:device];
    self.mtkView.delegate = self.renderer;
    
    [self.window setContentView:self.mtkView];
    [self.window makeKeyAndOrderFront:nil];
    [self.window center];
    
    // Set tracking for mouse move events
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:self.mtkView.bounds
                                                                 options:(NSTrackingActiveInKeyWindow | 
                                                                         NSTrackingInVisibleRect |
                                                                         NSTrackingMouseMoved |
                                                                         NSTrackingMouseEnteredAndExited)
                                                                   owner:self.window
                                                                userInfo:nil];
    [self.mtkView addTrackingArea:trackingArea];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return YES;
}

@end

int main(int argc, char* argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        
        CameraCityAppDelegate *delegate = [[CameraCityAppDelegate alloc] init];
        [app setDelegate:delegate];
        
        [app run];
    }
    return 0;
}