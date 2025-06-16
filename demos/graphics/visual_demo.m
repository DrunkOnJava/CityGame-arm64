#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

@interface VisualDemoView : MTKView
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLTexture> spriteAtlas;
@end

@implementation VisualDemoView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupMetal];
        [self loadSpriteAtlas];
    }
    return self;
}

- (void)setupMetal {
    self.device = MTLCreateSystemDefaultDevice();
    self.commandQueue = [self.device newCommandQueue];
    
    // Configure the view
    self.delegate = self;
    self.device = self.device;
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.clearColor = MTLClearColorMake(0.2, 0.6, 0.9, 1.0); // Sky blue
}

- (void)loadSpriteAtlas {
    // Load the texture atlas we generated
    NSString *atlasPath = @"assets/atlases/buildings.png";
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:atlasPath];
    
    if (image) {
        NSLog(@"✅ Successfully loaded sprite atlas: %@", atlasPath);
        
        // Convert NSImage to MTLTexture (simplified for demo)
        MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                                                              width:image.size.width
                                                                                             height:image.size.height
                                                                                          mipmapped:NO];
        self.spriteAtlas = [self.device newTextureWithDescriptor:descriptor];
        NSLog(@"✅ Created Metal texture: %dx%d", (int)image.size.width, (int)image.size.height);
    } else {
        NSLog(@"❌ Failed to load sprite atlas");
    }
}

- (void)drawInMTKView:(MTKView *)view {
    // Create command buffer
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    
    // Get current drawable
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor) {
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        
        // For now, just clear the screen with sky blue
        // TODO: Render sprites here
        
        [encoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    
    [commandBuffer commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Handle viewport changes
    NSLog(@"Viewport changed to: %.0fx%.0f", size.width, size.height);
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) VisualDemoView *metalView;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Create window
    NSRect frame = NSMakeRect(100, 100, 1200, 800);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled | 
                                                       NSWindowStyleMaskClosable | 
                                                       NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    [self.window setTitle:@"🏗️ SimCity ARM64 - Graphics System Demo"];
    
    // Create Metal view
    self.metalView = [[VisualDemoView alloc] initWithFrame:frame];
    [self.window setContentView:self.metalView];
    
    // Show window
    [self.window makeKeyAndOrderFront:nil];
    
    NSLog(@"🎮 SimCity ARM64 Graphics Demo Window Launched!");
    NSLog(@"📱 Window Size: %.0fx%.0f", frame.size.width, frame.size.height);
    NSLog(@"🎨 Metal Device: %@", self.metalView.device.name);
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];
        [app run];
    }
    return 0;
}