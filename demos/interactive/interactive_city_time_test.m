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
    TILE_PARK = 5,
    TILE_TYPE_COUNT = 6
} CityTileType;

// Vertex structure
typedef struct {
    vector_float2 position;
    vector_float2 texCoord;
} IsometricVertex;

// City statistics
typedef struct {
    int population;
    int jobs;
    int houses;
    int commercial;
    int industrial;
    int happiness;
} CityStats;

// External time system functions
extern void time_system_init(int year, int month, int day, float scale);
extern void time_system_update(void);
extern void time_system_pause(int pause);
extern void time_system_set_speed(int speed_index);
extern int time_system_get_speed(void);
extern void time_system_cycle_speed(void);
extern int time_system_get_season(void);
extern int time_system_get_year(void);
extern int time_system_get_month(void);
extern int time_system_get_day(void);
extern int time_system_get_hour(void);
extern int time_system_get_minute(void);
extern int time_system_get_second(void);
extern int time_system_is_paused(void);
extern float time_system_get_scale(void);

@interface InteractiveCityTimeTest : MTKView <MTKViewDelegate>
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLTexture> spriteAtlas;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> indexBuffer;
@property (nonatomic, strong) id<MTLSamplerState> samplerState;

// City data
@property (nonatomic, assign) CityTileType *cityGrid;
@property (nonatomic, assign) uint8_t *buildingVariants;
@property (nonatomic, assign) int gridSize;
@property (nonatomic, assign) CityStats stats;
@property (nonatomic, assign) CityTileType currentBuildingType;

// Animation
@property (nonatomic, assign) float animationTime;
@property (nonatomic, assign) int animationFrame;

// Camera
@property (nonatomic, assign) float cameraX;
@property (nonatomic, assign) float cameraY;
@property (nonatomic, assign) float targetCameraX;
@property (nonatomic, assign) float targetCameraY;
@property (nonatomic, assign) float zoom;
@property (nonatomic, assign) float targetZoom;

// UI
@property (nonatomic, strong) NSTextField *statsLabel;
@property (nonatomic, strong) NSTextField *buildingTypeLabel;
@property (nonatomic, strong) NSTextField *timeLabel;
@property (nonatomic, strong) NSButton *pauseButton;
@property (nonatomic, strong) NSButton *speedButton;
@end

@implementation InteractiveCityTimeTest

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.gridSize = 30;
        self.currentBuildingType = TILE_HOUSE;
        self.zoom = 1.0f;
        self.targetZoom = 1.0f;
        
        [self setupMetal];
        [self initializeCityData];
        [self createGeometry];
        [self setupInteraction];
        [self createUI];
        [self updateStats];
        
        // Initialize time system
        time_system_init(2000, 1, 1, 60.0f);
        
        self.delegate = self;
    }
    return self;
}

- (void)setupMetal {
    self.device = MTLCreateSystemDefaultDevice();
    self.commandQueue = [self.device newCommandQueue];
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.clearColor = MTLClearColorMake(0.15, 0.7, 0.15, 1.0);
    
    NSLog(@"🎮 Time Test City - Metal initialized");
}

- (void)initializeCityData {
    int totalTiles = self.gridSize * self.gridSize;
    self.cityGrid = malloc(totalTiles * sizeof(CityTileType));
    self.buildingVariants = malloc(totalTiles * sizeof(uint8_t));
    
    // Create simple test city
    for (int y = 0; y < self.gridSize; y++) {
        for (int x = 0; x < self.gridSize; x++) {
            int index = y * self.gridSize + x;
            
            if ((x % 5) == 0 || (y % 5) == 0) {
                self.cityGrid[index] = TILE_ROAD;
            } else {
                self.cityGrid[index] = TILE_EMPTY;
            }
            
            self.buildingVariants[index] = arc4random_uniform(4);
        }
    }
    
    // Add some starter buildings
    [self setTileAt:2 y:2 type:TILE_HOUSE];
    [self setTileAt:3 y:2 type:TILE_HOUSE];
    [self setTileAt:2 y:3 type:TILE_COMMERCIAL];
    [self setTileAt:7 y:7 type:TILE_INDUSTRIAL];
    
    NSLog(@"✅ Time test city data initialized: %dx%d", self.gridSize, self.gridSize);
}

- (void)createGeometry {
    // Simple geometry creation - just make colored squares for now
    int visibleTiles = 0;
    for (int i = 0; i < self.gridSize * self.gridSize; i++) {
        if (self.cityGrid[i] != TILE_EMPTY) visibleTiles++;
    }
    
    if (visibleTiles == 0) return;
    
    IsometricVertex *vertices = malloc(visibleTiles * 4 * sizeof(IsometricVertex));
    uint16_t *indices = malloc(visibleTiles * 6 * sizeof(uint16_t));
    
    int vertexIndex = 0;
    int indexIndex = 0;
    int quadIndex = 0;
    
    for (int y = 0; y < self.gridSize; y++) {
        for (int x = 0; x < self.gridSize; x++) {
            int tileIndex = y * self.gridSize + x;
            CityTileType tileType = self.cityGrid[tileIndex];
            
            if (tileType == TILE_EMPTY) continue;
            
            float isoX = (x - y) * 0.1f;
            float isoY = (x + y) * 0.05f;
            float tileWidth = 0.08f;
            float tileHeight = 0.08f;
            
            // Simple colored UV coordinates based on tile type
            float u1 = 0.0f, v1 = 0.0f, u2 = 1.0f, v2 = 1.0f;
            switch (tileType) {
                case TILE_ROAD: u1 = 0.5f; v1 = 0.5f; u2 = 0.6f; v2 = 0.6f; break;
                case TILE_HOUSE: u1 = 0.0f; v1 = 0.0f; u2 = 0.1f; v2 = 0.1f; break;
                case TILE_COMMERCIAL: u1 = 0.1f; v1 = 0.0f; u2 = 0.2f; v2 = 0.1f; break;
                case TILE_INDUSTRIAL: u1 = 0.2f; v1 = 0.0f; u2 = 0.3f; v2 = 0.1f; break;
                case TILE_PARK: u1 = 0.3f; v1 = 0.0f; u2 = 0.4f; v2 = 0.1f; break;
                default: break;
            }
            
            vertices[vertexIndex + 0] = (IsometricVertex){{isoX - tileWidth, isoY - tileHeight}, {u1, v2}};
            vertices[vertexIndex + 1] = (IsometricVertex){{isoX + tileWidth, isoY - tileHeight}, {u2, v2}};
            vertices[vertexIndex + 2] = (IsometricVertex){{isoX + tileWidth, isoY + tileHeight}, {u2, v1}};
            vertices[vertexIndex + 3] = (IsometricVertex){{isoX - tileWidth, isoY + tileHeight}, {u1, v1}};
            
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
    
    self.vertexBuffer = [self.device newBufferWithBytes:vertices
                                                 length:visibleTiles * 4 * sizeof(IsometricVertex)
                                                options:MTLResourceStorageModeShared];
    
    self.indexBuffer = [self.device newBufferWithBytes:indices
                                                length:visibleTiles * 6 * sizeof(uint16_t)
                                               options:MTLResourceStorageModeShared];
    
    free(vertices);
    free(indices);
}

- (void)setupInteraction {
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                                options:(NSTrackingActiveInKeyWindow | 
                                                                       NSTrackingMouseMoved |
                                                                       NSTrackingInVisibleRect)
                                                                  owner:self
                                                               userInfo:nil];
    [self addTrackingArea:trackingArea];
    
    NSLog(@"✅ Mouse and keyboard controls enabled");
}

- (void)createUI {
    // Stats label
    self.statsLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, self.bounds.size.height - 100, 300, 80)];
    self.statsLabel.bezeled = NO;
    self.statsLabel.drawsBackground = YES;
    self.statsLabel.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.7];
    self.statsLabel.textColor = [NSColor whiteColor];
    self.statsLabel.editable = NO;
    self.statsLabel.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    [self addSubview:self.statsLabel];
    
    // Building type label
    self.buildingTypeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 10, 300, 30)];
    self.buildingTypeLabel.bezeled = NO;
    self.buildingTypeLabel.drawsBackground = YES;
    self.buildingTypeLabel.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.7];
    self.buildingTypeLabel.textColor = [NSColor whiteColor];
    self.buildingTypeLabel.editable = NO;
    self.buildingTypeLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightBold];
    [self addSubview:self.buildingTypeLabel];
    
    // Time display label
    self.timeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(self.bounds.size.width - 320, self.bounds.size.height - 60, 300, 50)];
    self.timeLabel.bezeled = NO;
    self.timeLabel.drawsBackground = YES;
    self.timeLabel.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.7];
    self.timeLabel.textColor = [NSColor whiteColor];
    self.timeLabel.editable = NO;
    self.timeLabel.font = [NSFont monospacedSystemFontOfSize:14 weight:NSFontWeightBold];
    self.timeLabel.alignment = NSTextAlignmentRight;
    [self addSubview:self.timeLabel];
    
    // Pause/Play button
    self.pauseButton = [[NSButton alloc] initWithFrame:NSMakeRect(self.bounds.size.width - 140, self.bounds.size.height - 100, 60, 30)];
    [self.pauseButton setTitle:@"⏸️"];
    [self.pauseButton setBezelStyle:NSBezelStyleRounded];
    [self.pauseButton setTarget:self];
    [self.pauseButton setAction:@selector(togglePause:)];
    [self addSubview:self.pauseButton];
    
    // Speed control button
    self.speedButton = [[NSButton alloc] initWithFrame:NSMakeRect(self.bounds.size.width - 70, self.bounds.size.height - 100, 60, 30)];
    [self.speedButton setTitle:@"1x"];
    [self.speedButton setBezelStyle:NSBezelStyleRounded];
    [self.speedButton setTarget:self];
    [self.speedButton setAction:@selector(cycleSpeed:)];
    [self addSubview:self.speedButton];
    
    [self updateBuildingTypeLabel];
    [self updateTimeDisplay];
}

- (void)updateStats {
    CityStats newStats = {0};
    
    for (int i = 0; i < self.gridSize * self.gridSize; i++) {
        switch (self.cityGrid[i]) {
            case TILE_HOUSE:
                newStats.houses++;
                break;
            case TILE_COMMERCIAL:
                newStats.commercial++;
                break;
            case TILE_INDUSTRIAL:
                newStats.industrial++;
                break;
            default:
                break;
        }
    }
    
    newStats.population = newStats.houses * 4;
    newStats.jobs = newStats.commercial * 6 + newStats.industrial * 10;
    newStats.happiness = 50 + (newStats.jobs > newStats.population ? 20 : -10);
    
    self.stats = newStats;
    
    NSString *statsText = [NSString stringWithFormat:
        @"🏙️ CITY STATISTICS\n"
        @"Population: %d\n"
        @"Jobs: %d\n"
        @"Houses: %d | Commercial: %d | Industrial: %d\n"
        @"Happiness: %d%%",
        self.stats.population, self.stats.jobs,
        self.stats.houses, self.stats.commercial, self.stats.industrial,
        self.stats.happiness];
    
    self.statsLabel.stringValue = statsText;
}

- (void)updateBuildingTypeLabel {
    NSString *buildingName = @"";
    switch (self.currentBuildingType) {
        case TILE_HOUSE: buildingName = @"🏠 House"; break;
        case TILE_COMMERCIAL: buildingName = @"🏢 Commercial"; break;
        case TILE_INDUSTRIAL: buildingName = @"🏭 Industrial"; break;
        case TILE_PARK: buildingName = @"🌳 Park"; break;
        case TILE_ROAD: buildingName = @"🛣️ Road"; break;
        default: buildingName = @"Empty"; break;
    }
    
    self.buildingTypeLabel.stringValue = [NSString stringWithFormat:@"Building: %@ (1-5 to change) | Space=Pause +/-=Speed", buildingName];
}

- (void)updateTimeDisplay {
    // Get time information from actual C time system
    int gameYear = time_system_get_year();
    int gameMonth = time_system_get_month();
    int gameDay = time_system_get_day();
    int gameHour = time_system_get_hour();
    int gameMinute = time_system_get_minute();
    int gameSecond = time_system_get_second();
    
    static const char* months[] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
    static const char* seasons[] = {"Winter", "Spring", "Summer", "Fall"};
    
    int season = time_system_get_season();
    if (season < 0 || season > 3) season = 0;
    
    int currentSpeed = time_system_get_speed();
    float timeScale = time_system_get_scale();
    BOOL paused = time_system_is_paused();
    
    const char* speedNames[] = {"⏸️", "1x", "2x", "3x", "10x", "50x", "100x", "🚀"};
    const char* speedName = (currentSpeed < 8) ? speedNames[currentSpeed] : "??";
    
    NSString *timeString = [NSString stringWithFormat:
        @"📅 %s %d, %d\n"
        @"⏰ %02d:%02d:%02d\n"
        @"🌿 %s | %s (%.1fx)\n"
        @"%@",
        months[gameMonth-1], gameDay, gameYear,
        gameHour, gameMinute, gameSecond,
        seasons[season], speedName, timeScale,
        paused ? @"⏸️ PAUSED" : @"▶️ RUNNING"];
    
    self.timeLabel.stringValue = timeString;
    
    // Update button labels
    if (paused) {
        [self.pauseButton setTitle:@"▶️"];
        [self.speedButton setTitle:@"⏸️"];
    } else {
        [self.pauseButton setTitle:@"⏸️"];
        [self.speedButton setTitle:[NSString stringWithFormat:@"%s", speedName]];
    }
}

- (void)togglePause:(id)sender {
    NSLog(@"🎮 Time control: Pause toggled");
    
    // Get current speed and toggle pause
    int currentSpeed = time_system_get_speed();
    if (currentSpeed == 0) {
        time_system_set_speed(1); // Unpause to normal speed
    } else {
        time_system_set_speed(0); // Pause
    }
    
    [self updateTimeDisplay];
}

- (void)cycleSpeed:(id)sender {
    NSLog(@"🎮 Time control: Speed cycled");
    time_system_cycle_speed();
    [self updateTimeDisplay];
}

- (void)setTileAt:(int)x y:(int)y type:(CityTileType)type {
    if (x >= 0 && x < self.gridSize && y >= 0 && y < self.gridSize) {
        self.cityGrid[y * self.gridSize + x] = type;
    }
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    
    float screenX = (locationInView.x / self.bounds.size.width) * 2.0f - 1.0f;
    float screenY = (locationInView.y / self.bounds.size.height) * 2.0f - 1.0f;
    
    float worldX = screenX / self.zoom + self.cameraX;
    float worldY = screenY / self.zoom + self.cameraY;
    
    float gridX = (worldX / 0.1f + worldY / 0.05f) / 2.0f;
    float gridY = (worldY / 0.05f - worldX / 0.1f) / 2.0f;
    
    int tileX = (int)roundf(gridX);
    int tileY = (int)roundf(gridY);
    
    if (tileX >= 0 && tileX < self.gridSize && tileY >= 0 && tileY < self.gridSize) {
        [self setTileAt:tileX y:tileY type:self.currentBuildingType];
        [self createGeometry];
        [self updateStats];
        NSLog(@"🏗️ Placed %d at (%d, %d)", self.currentBuildingType, tileX, tileY);
    }
}

- (void)rightMouseDown:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    
    float screenX = (locationInView.x / self.bounds.size.width) * 2.0f - 1.0f;
    float screenY = (locationInView.y / self.bounds.size.height) * 2.0f - 1.0f;
    
    float worldX = screenX / self.zoom + self.cameraX;
    float worldY = screenY / self.zoom + self.cameraY;
    
    float gridX = (worldX / 0.1f + worldY / 0.05f) / 2.0f;
    float gridY = (worldY / 0.05f - worldX / 0.1f) / 2.0f;
    
    int tileX = (int)roundf(gridX);
    int tileY = (int)roundf(gridY);
    
    if (tileX >= 0 && tileX < self.gridSize && tileY >= 0 && tileY < self.gridSize) {
        [self setTileAt:tileX y:tileY type:TILE_EMPTY];
        [self createGeometry];
        [self updateStats];
        NSLog(@"🗑️ Removed tile at (%d, %d)", tileX, tileY);
    }
}

- (void)mouseDragged:(NSEvent *)event {
    self.targetCameraX -= event.deltaX * 0.01f / self.zoom;
    self.targetCameraY += event.deltaY * 0.01f / self.zoom;
}

- (void)scrollWheel:(NSEvent *)event {
    self.targetZoom *= (1.0f + event.deltaY * 0.1f);
    self.targetZoom = fmaxf(0.3f, fminf(3.0f, self.targetZoom));
}

- (void)keyDown:(NSEvent *)event {
    float moveSpeed = 0.05f / self.zoom;
    
    switch (event.keyCode) {
        case 0: // A
            self.targetCameraX -= moveSpeed;
            break;
        case 2: // D
            self.targetCameraX += moveSpeed;
            break;
        case 13: // W
            self.targetCameraY += moveSpeed;
            break;
        case 1: // S
            self.targetCameraY -= moveSpeed;
            break;
        case 18: // 1
            self.currentBuildingType = TILE_HOUSE;
            [self updateBuildingTypeLabel];
            break;
        case 19: // 2
            self.currentBuildingType = TILE_COMMERCIAL;
            [self updateBuildingTypeLabel];
            break;
        case 20: // 3
            self.currentBuildingType = TILE_INDUSTRIAL;
            [self updateBuildingTypeLabel];
            break;
        case 21: // 4
            self.currentBuildingType = TILE_PARK;
            [self updateBuildingTypeLabel];
            break;
        case 23: // 5
            self.currentBuildingType = TILE_ROAD;
            [self updateBuildingTypeLabel];
            break;
        case 49: // Space bar - Pause/unpause
            [self togglePause:nil];
            break;
        case 24: // + (equals key) - Increase speed
        case 27: // - (minus key) - Cycle speed
            [self cycleSpeed:nil];
            break;
    }
}

- (void)drawInMTKView:(MTKView *)view {
    // Update time system
    time_system_update();
    
    // Smooth camera movement
    float smoothing = 0.1f;
    self.cameraX += (self.targetCameraX - self.cameraX) * smoothing;
    self.cameraY += (self.targetCameraY - self.cameraY) * smoothing;
    self.zoom += (self.targetZoom - self.zoom) * smoothing;
    
    // Update animation
    self.animationTime += 1.0f/60.0f;
    
    // Update time display periodically
    static int timeUpdateCounter = 0;
    timeUpdateCounter++;
    if (timeUpdateCounter >= 30) {
        timeUpdateCounter = 0;
        [self updateTimeDisplay];
    }
    
    // Simple render without textures for now
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    
    if (renderPassDescriptor && self.vertexBuffer) {
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        
        // Simple vertex rendering without pipeline state for now
        [encoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    
    [commandBuffer commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    self.statsLabel.frame = NSMakeRect(10, size.height - 100, 300, 80);
    self.buildingTypeLabel.frame = NSMakeRect(10, 10, 300, 30);
    self.timeLabel.frame = NSMakeRect(size.width - 320, size.height - 60, 300, 50);
    self.pauseButton.frame = NSMakeRect(size.width - 140, size.height - 100, 60, 30);
    self.speedButton.frame = NSMakeRect(size.width - 70, size.height - 100, 60, 30);
}

- (void)dealloc {
    if (self.cityGrid) {
        free(self.cityGrid);
    }
    if (self.buildingVariants) {
        free(self.buildingVariants);
    }
}

@end

@interface InteractiveCityTimeTestApp : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) InteractiveCityTimeTest *city;
@end

@implementation InteractiveCityTimeTestApp

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSLog(@"🚀 Launching Time System Test!");
    
    NSRect frame = NSMakeRect(100, 100, 1200, 800);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled | 
                                                       NSWindowStyleMaskClosable | 
                                                       NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    [self.window setTitle:@"🕰️ SimCity Time System Test"];
    
    self.city = [[InteractiveCityTimeTest alloc] initWithFrame:frame];
    [self.window setContentView:self.city];
    [self.window makeFirstResponder:self.city];
    
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    NSLog(@"✅ Time system test launched!");
    NSLog(@"🎮 Controls:");
    NSLog(@"   • Space: Pause/Unpause");
    NSLog(@"   • +/-: Change time speed");
    NSLog(@"   • 1-5: Change building type");
    NSLog(@"   • Click: Place building");
    NSLog(@"   • Right click: Remove building");
    NSLog(@"   • WASD: Move camera");
    NSLog(@"   • Scroll: Zoom");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"🎯 SimCity Time System Test");
        
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        
        InteractiveCityTimeTestApp *delegate = [[InteractiveCityTimeTestApp alloc] init];
        [app setDelegate:delegate];
        
        [app run];
    }
    return 0;
}