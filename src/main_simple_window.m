#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
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

// Simple renderer that draws colored rectangles
@interface SimpleRenderer : NSObject <MTKViewDelegate>
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@end

@implementation SimpleRenderer

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _device = device;
        _commandQueue = [device newCommandQueue];
    }
    return self;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Handle resize
}

- (void)drawInMTKView:(MTKView *)view {
    frame_count++;
    
    // Run simulation systems
    simulation_update();
    ai_update();
    audio_update();
    ui_update();
    
    // Create command buffer
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    
    // Get render pass descriptor
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (!renderPassDescriptor) return;
    
    // Animate the clear color to show it's working
    float time = frame_count * 0.016f;
    float r = 0.1f + 0.4f * (sinf(time * 0.5f) + 1.0f) * 0.5f;
    float g = 0.1f + 0.4f * (sinf(time * 0.7f) + 1.0f) * 0.5f; 
    float b = 0.3f + 0.3f * (sinf(time * 1.1f) + 1.0f) * 0.5f;
    
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(r, g, b, 1.0);
    
    // Create render encoder (even if we're not drawing anything, this shows the clear color)
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    // End encoding (this will clear the screen with our animated color)
    [renderEncoder endEncoding];
    
    // Present
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
    
    // Print status
    if (frame_count % 60 == 0) {
        printf(\"SimCity ARM64: Frame %d - Animated background (R:%.2f G:%.2f B:%.2f)\\n\", frame_count, r, g, b);
    }
    
    // Exit after demo period
    if (frame_count > 300) { // 5 seconds at 60fps
        printf(\"\\nDemo complete! Window will close.\\n\");
        [NSApp terminate:nil];
    }
}

@end

// Window delegate
@interface SimpleWindowDelegate : NSObject <NSWindowDelegate>
@end

@implementation SimpleWindowDelegate
- (BOOL)windowShouldClose:(NSWindow *)window {
    [NSApp terminate:nil];
    return YES;
}
@end

// Application delegate
@interface SimpleAppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, strong) SimpleRenderer *renderer;
@end

@implementation SimpleAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    printf(\"\\n=== SimCity ARM64 Engine - Visual Demo ===\\n\");
    printf(\"Opening animated Metal window...\\n\");
    printf(\"Watch for animated background colors!\\n\\n\");
    
    // Initialize core systems
    printf(\"Initializing systems...\\n\");
    bootstrap_init();
    metal_init();
    simulation_core_init();
    astar_core_init();
    printf(\"Systems initialized!\\n\\n\");
    
    // Create Metal device
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        printf(\"Metal not supported!\\n\");
        [NSApp terminate:nil];
        return;
    }
    
    printf(\"Metal device: %s\\n\", [device.name UTF8String]);
    
    // Create window
    NSRect frame = NSMakeRect(200, 200, 800, 600);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    [self.window setTitle:@\"SimCity ARM64 - Animated Demo\"];
    
    // Create Metal view
    self.mtkView = [[MTKView alloc] initWithFrame:frame device:device];
    self.mtkView.preferredFramesPerSecond = 60;
    
    // Create renderer
    self.renderer = [[SimpleRenderer alloc] initWithDevice:device];
    self.mtkView.delegate = self.renderer;
    
    // Set up window
    [self.window setContentView:self.mtkView];
    [self.window setDelegate:[[SimpleWindowDelegate alloc] init]];
    [self.window makeKeyAndOrderFront:nil];
    [self.window center];
    
    printf(\"Window opened! You should see animated colors.\\n\");
    printf(\"The background will cycle through different colors.\\n\\n\");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    printf(\"\\n=== SimCity ARM64 Engine Shutdown ===\\n\");
    printf(\"Total frames: %d\\n\", frame_count);
    printf(\"Demo completed successfully!\\n\");
}

@end

int main(int argc, char* argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        
        SimpleAppDelegate *delegate = [[SimpleAppDelegate alloc] init];
        [app setDelegate:delegate];
        
        [app run];
    }
    return 0;
}