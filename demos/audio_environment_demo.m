// audio_environment_demo.m - Audio and Environment Integration Demo
// Demonstrates the coordinated operation of weather, lighting, and audio systems
// Agent 8: Audio and Environment Systems Developer

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>

// Include our integration header
#include "../src/audio/audio_environment_integration.h"

@interface AudioEnvironmentDemo : NSObject <MTKViewDelegate>

@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) MTKView *metalView;
@property (nonatomic, strong) NSTimer *updateTimer;

// Demo state
@property (nonatomic) float currentTime;
@property (nonatomic) float timeScale;
@property (nonatomic) uint32_t currentWeather;
@property (nonatomic) uint32_t currentSeason;
@property (nonatomic) bool systemsInitialized;

// Performance monitoring
@property (nonatomic) uint64_t lastFrameTime;
@property (nonatomic) float averageFrameTime;
@property (nonatomic) uint32_t frameCount;

@end

@implementation AudioEnvironmentDemo

- (instancetype)init {
    self = [super init];
    if (self) {
        self.currentTime = 12.0f;  // Start at noon
        self.timeScale = 60.0f;    // 1 real minute = 1 game hour
        self.currentWeather = 0;   // WEATHER_CLEAR
        self.currentSeason = 1;    // Summer
        self.systemsInitialized = false;
        self.frameCount = 0;
        
        [self setupMetal];
        [self initializeIntegratedSystems];
        [self setupDemoUI];
        [self startUpdateLoop];
    }
    return self;
}

- (void)setupMetal {
    // Initialize Metal for rendering
    self.device = MTLCreateSystemDefaultDevice();
    if (!self.device) {
        NSLog(@"Metal is not supported on this device");
        return;
    }
    
    self.commandQueue = [self.device newCommandQueue];
    
    // Create Metal view
    self.metalView = [[MTKView alloc] init];
    self.metalView.device = self.device;
    self.metalView.delegate = self;
    self.metalView.preferredFramesPerSecond = 60;
    self.metalView.clearColor = MTLClearColorMake(0.5, 0.7, 1.0, 1.0); // Sky blue
}

- (void)initializeIntegratedSystems {
    NSLog(@"Initializing integrated audio and environment systems...");
    
    // Initialize the integrated system
    // Climate zone: temperate (0), latitude: 45 degrees, time: noon
    int result = audio_environment_init(0, 45.0f, 12.0f);
    if (result != AUDIO_ENV_SUCCESS) {
        NSLog(@"Failed to initialize audio-environment integration: %d", result);
        return;
    }
    
    self.systemsInitialized = true;
    NSLog(@"Audio-environment integration initialized successfully");
    
    // Set initial configuration
    audio_config_set_master_volume(0.8f);
    audio_config_set_ambient_volume(0.6f);
    audio_config_set_weather_volume(0.7f);
    
    environment_config_set_time_scale(self.timeScale);
    environment_config_set_lighting_quality(AUDIO_QUALITY_HIGH);
    environment_config_set_particle_density(0.8f);
    
    // Start with a pleasant spring morning
    [self setDemoWeather:0]; // Clear weather
    [self setDemoSeason:0];  // Spring
}

- (void)setupDemoUI {
    // Create main window
    NSRect windowFrame = NSMakeRect(100, 100, 1200, 800);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:windowFrame
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    window.title = @"SimCity ARM64 - Audio & Environment Integration Demo";
    
    // Create main container view
    NSView *containerView = [[NSView alloc] initWithFrame:windowFrame];
    
    // Add Metal view for rendering
    self.metalView.frame = NSMakeRect(0, 200, 1200, 600);
    [containerView addSubview:self.metalView];
    
    // Create control panel
    [self createControlPanel:containerView];
    
    // Create info panel
    [self createInfoPanel:containerView];
    
    window.contentView = containerView;
    [window makeKeyAndOrderFront:nil];
    
    NSLog(@"Demo UI setup complete");
}

- (void)createControlPanel:(NSView *)parent {
    NSRect controlFrame = NSMakeRect(20, 20, 400, 160);
    NSBox *controlBox = [[NSBox alloc] initWithFrame:controlFrame];
    controlBox.title = @"Environment Controls";
    controlBox.borderType = NSLineBorder;
    
    // Time controls
    NSTextField *timeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 120, 100, 20)];
    timeLabel.stringValue = @"Time of Day:";
    timeLabel.editable = NO;
    timeLabel.bordered = NO;
    timeLabel.backgroundColor = [NSColor clearColor];
    [controlBox addSubview:timeLabel];
    
    NSSlider *timeSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(120, 120, 200, 20)];
    timeSlider.minValue = 0.0;
    timeSlider.maxValue = 24.0;
    timeSlider.floatValue = self.currentTime;
    timeSlider.target = self;
    timeSlider.action = @selector(timeSliderChanged:);
    [controlBox addSubview:timeSlider];
    
    // Weather controls
    NSTextField *weatherLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 90, 100, 20)];
    weatherLabel.stringValue = @"Weather:";
    weatherLabel.editable = NO;
    weatherLabel.bordered = NO;
    weatherLabel.backgroundColor = [NSColor clearColor];
    [controlBox addSubview:weatherLabel];
    
    NSPopUpButton *weatherPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(120, 85, 150, 25)];
    [weatherPopup addItemsWithTitles:@[@"Clear", @"Partly Cloudy", @"Overcast", @"Light Rain", @"Heavy Rain", @"Thunderstorm", @"Light Snow", @"Heavy Snow", @"Blizzard", @"Fog"]];
    [weatherPopup selectItemAtIndex:self.currentWeather];
    weatherPopup.target = self;
    weatherPopup.action = @selector(weatherChanged:);
    [controlBox addSubview:weatherPopup];
    
    // Season controls
    NSTextField *seasonLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 55, 100, 20)];
    seasonLabel.stringValue = @"Season:";
    seasonLabel.editable = NO;
    seasonLabel.bordered = NO;
    seasonLabel.backgroundColor = [NSColor clearColor];
    [controlBox addSubview:seasonLabel];
    
    NSPopUpButton *seasonPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(120, 50, 150, 25)];
    [seasonPopup addItemsWithTitles:@[@"Spring", @"Summer", @"Fall", @"Winter"]];
    [seasonPopup selectItemAtIndex:self.currentSeason];
    seasonPopup.target = self;
    seasonPopup.action = @selector(seasonChanged:);
    [controlBox addSubview:seasonPopup];
    
    // Audio volume control
    NSTextField *volumeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 20, 100, 20)];
    volumeLabel.stringValue = @"Audio Volume:";
    volumeLabel.editable = NO;
    volumeLabel.bordered = NO;
    volumeLabel.backgroundColor = [NSColor clearColor];
    [controlBox addSubview:volumeLabel];
    
    NSSlider *volumeSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(120, 20, 200, 20)];
    volumeSlider.minValue = 0.0;
    volumeSlider.maxValue = 1.0;
    volumeSlider.floatValue = 0.8;
    volumeSlider.target = self;
    volumeSlider.action = @selector(volumeSliderChanged:);
    [controlBox addSubview:volumeSlider];
    
    [parent addSubview:controlBox];
}

- (void)createInfoPanel:(NSView *)parent {
    NSRect infoFrame = NSMakeRect(440, 20, 350, 160);
    NSBox *infoBox = [[NSBox alloc] initWithFrame:infoFrame];
    infoBox.title = @"System Information";
    infoBox.borderType = NSLineBorder;
    
    // Create info text view
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 10, 330, 130)];
    NSTextView *infoText = [[NSTextView alloc] init];
    infoText.editable = NO;
    infoText.font = [NSFont fontWithName:@"Monaco" size:10];
    
    scrollView.documentView = infoText;
    scrollView.hasVerticalScroller = YES;
    [infoBox addSubview:scrollView];
    
    // Store reference for updates
    infoText.tag = 1001; // Use tag to find later
    
    [parent addSubview:infoBox];
}

- (void)startUpdateLoop {
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/60.0 // 60 FPS
                                                        target:self
                                                      selector:@selector(updateDemo:)
                                                      userInfo:nil
                                                       repeats:YES];
    
    NSLog(@"Update loop started");
}

- (void)updateDemo:(NSTimer *)timer {
    if (!self.systemsInitialized) return;
    
    uint64_t currentTime = mach_absolute_time();
    if (self.lastFrameTime > 0) {
        uint64_t deltaTime = currentTime - self.lastFrameTime;
        
        // Convert to milliseconds
        mach_timebase_info_data_t timebase;
        mach_timebase_info(&timebase);
        uint64_t deltaNs = deltaTime * timebase.numer / timebase.denom;
        uint64_t deltaMs = deltaNs / 1000000;
        
        // Update integrated systems
        audio_environment_update(deltaMs);
        
        // Update frame time tracking
        float frameTimeMs = (float)deltaMs;
        self.averageFrameTime = (self.averageFrameTime * 0.9f) + (frameTimeMs * 0.1f);
        self.frameCount++;
        
        // Update demo-specific logic
        [self updateDemoLogic:deltaMs];
        
        // Update info display every 30 frames
        if (self.frameCount % 30 == 0) {
            [self updateInfoDisplay];
        }
    }
    self.lastFrameTime = currentTime;
}

- (void)updateDemoLogic:(uint64_t)deltaMs {
    // Simulate time progression
    float deltaSeconds = deltaMs / 1000.0f;
    float timeIncrement = (deltaSeconds * self.timeScale) / 3600.0f; // Convert to game hours
    
    self.currentTime += timeIncrement;
    if (self.currentTime >= 24.0f) {
        self.currentTime -= 24.0f;
    }
    
    // Update environment based on time
    TimeEnvironmentParams envParams = {0};
    envParams.time_of_day = self.currentTime;
    envParams.time_phase = get_time_phase(self.currentTime);
    
    sync_environment_to_audio(&envParams);
    
    // Simulate weather changes (random transitions)
    static uint32_t weatherChangeTimer = 0;
    weatherChangeTimer += deltaMs;
    
    if (weatherChangeTimer > 30000) { // Change weather every 30 seconds for demo
        weatherChangeTimer = 0;
        uint32_t newWeather = arc4random() % 6; // 0-5 for variety
        if (newWeather != self.currentWeather) {
            [self setDemoWeather:newWeather];
        }
    }
}

- (void)updateInfoDisplay {
    // Find the info text view
    NSWindow *window = [NSApp mainWindow];
    NSTextView *infoText = [window.contentView viewWithTag:1001];
    if (!infoText) return;
    
    // Get system performance stats
    AudioEnvironmentState stats = {0};
    audio_environment_get_performance_stats(&stats);
    
    // Build info string
    NSMutableString *info = [NSMutableString string];
    [info appendFormat:@"=== SimCity ARM64 Audio & Environment Demo ===\n\n"];
    
    // Time information
    uint32_t hours = (uint32_t)self.currentTime;
    uint32_t minutes = (uint32_t)((self.currentTime - hours) * 60);
    [info appendFormat:@"Game Time: %02d:%02d\n", hours, minutes];
    [info appendFormat:@"Time Phase: %@\n", [self getTimePhaseString:get_time_phase(self.currentTime)]];
    [info appendFormat:@"Season: %@\n", [self getSeasonString:self.currentSeason]];
    [info appendFormat:@"Weather: %@\n\n", [self getWeatherString:self.currentWeather]];
    
    // System status
    [info appendFormat:@"=== System Status ===\n"];
    [info appendFormat:@"Audio System: %@\n", stats.audio_system_active ? @"Active" : @"Inactive"];
    [info appendFormat:@"Weather System: %@\n", stats.weather_system_active ? @"Active" : @"Inactive"];
    [info appendFormat:@"Environment System: %@\n", stats.environment_system_active ? @"Active" : @"Inactive"];
    [info appendFormat:@"Integration: %@\n\n", stats.integration_enabled ? @"Enabled" : @"Disabled"];
    
    // Performance metrics
    [info appendFormat:@"=== Performance ===\n"];
    [info appendFormat:@"Frame Time: %.2f ms\n", self.averageFrameTime];
    [info appendFormat:@"FPS: %.1f\n", 1000.0f / self.averageFrameTime];
    [info appendFormat:@"Processing Load: %.1f%%\n", stats.processing_load * 100.0f];
    [info appendFormat:@"Active Audio Sources: %d\n", stats.active_audio_sources];
    [info appendFormat:@"Weather Particles: %d\n", stats.weather_particles];
    [info appendFormat:@"Environment Particles: %d\n\n", stats.environment_particles];
    
    // Audio status
    float ambientVolume = _env_audio_get_ambient_volume();
    [info appendFormat:@"=== Audio Status ===\n"];
    [info appendFormat:@"Ambient Volume: %.2f\n", ambientVolume];
    [info appendFormat:@"3D Audio Sources: %d\n", stats.active_audio_sources];
    
    // Environment status
    float sunPos[3];
    _environment_get_sun_position(sunPos);
    float ambientLight = _environment_get_ambient_light();
    
    [info appendFormat:@"\n=== Environment Status ===\n"];
    [info appendFormat:@"Sun Position: (%.2f, %.2f, %.2f)\n", sunPos[0], sunPos[1], sunPos[2]];
    [info appendFormat:@"Ambient Light: %.2f\n", ambientLight];
    
    // Weather status
    float precipIntensity = _weather_get_precipitation_intensity();
    float windVector[2];
    _weather_get_wind_vector(windVector);
    float temperature = _weather_get_temperature();
    
    [info appendFormat:@"\n=== Weather Status ===\n"];
    [info appendFormat:@"Precipitation: %.2f\n", precipIntensity];
    [info appendFormat:@"Wind: (%.2f, %.2f)\n", windVector[0], windVector[1]];
    [info appendFormat:@"Temperature: %.1f°C\n", temperature];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        infoText.string = info;
    });
}

// Control event handlers
- (void)timeSliderChanged:(NSSlider *)sender {
    self.currentTime = sender.floatValue;
    environment_config_set_time_scale(self.timeScale);
}

- (void)weatherChanged:(NSPopUpButton *)sender {
    [self setDemoWeather:(uint32_t)sender.indexOfSelectedItem];
}

- (void)seasonChanged:(NSPopUpButton *)sender {
    [self setDemoSeason:(uint32_t)sender.indexOfSelectedItem];
}

- (void)volumeSliderChanged:(NSSlider *)sender {
    audio_config_set_master_volume(sender.floatValue);
}

- (void)setDemoWeather:(uint32_t)weatherType {
    self.currentWeather = weatherType;
    _weather_force_condition(weatherType);
    
    // Update audio to match weather
    update_weather_audio_integration();
    
    NSLog(@"Weather changed to: %@", [self getWeatherString:weatherType]);
}

- (void)setDemoSeason:(uint32_t)season {
    self.currentSeason = season;
    _env_audio_set_seasonal_sounds(season);
    
    NSLog(@"Season changed to: %@", [self getSeasonString:season]);
}

// Helper methods for string conversion
- (NSString *)getTimePhaseString:(uint32_t)phase {
    NSArray *phases = @[@"Dawn", @"Morning", @"Midday", @"Afternoon", @"Dusk", @"Night", @"Midnight", @"Late Night"];
    if (phase < phases.count) {
        return phases[phase];
    }
    return @"Unknown";
}

- (NSString *)getSeasonString:(uint32_t)season {
    NSArray *seasons = @[@"Spring", @"Summer", @"Fall", @"Winter"];
    if (season < seasons.count) {
        return seasons[season];
    }
    return @"Unknown";
}

- (NSString *)getWeatherString:(uint32_t)weather {
    NSArray *conditions = @[@"Clear", @"Partly Cloudy", @"Overcast", @"Light Rain", @"Heavy Rain", 
                           @"Thunderstorm", @"Light Snow", @"Heavy Snow", @"Blizzard", @"Fog"];
    if (weather < conditions.count) {
        return conditions[weather];
    }
    return @"Unknown";
}

// MTKViewDelegate methods
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Handle resize
}

- (void)drawInMTKView:(MTKView *)view {
    if (!self.systemsInitialized) return;
    
    // Create command buffer
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    
    // Get render pass descriptor
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (!renderPassDescriptor) return;
    
    // Update sky color based on time of day
    float skyColor[4];
    LightingConditions lighting = {0};
    _environment_get_lighting_conditions(&lighting);
    
    // Simple sky color calculation (would be more complex in real implementation)
    float timePhase = get_time_phase(self.currentTime);
    if (timePhase <= 2) { // Dawn/Morning
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 0.7, 0.4, 1.0); // Orange
    } else if (timePhase <= 4) { // Day/Afternoon
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.7, 1.0, 1.0); // Blue
    } else if (timePhase <= 5) { // Dusk
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.9, 0.5, 0.3, 1.0); // Red
    } else { // Night
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.05, 0.05, 0.15, 1.0); // Dark blue
    }
    
    // Create render encoder
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    // Here we would render the city, weather effects, particles, etc.
    // For this demo, we just show the changing sky color
    
    [renderEncoder endEncoding];
    
    // Present drawable
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

- (void)dealloc {
    [self.updateTimer invalidate];
    if (self.systemsInitialized) {
        audio_environment_shutdown();
    }
}

@end

// Demo entry point
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        app.activationPolicy = NSApplicationActivationPolicyRegular;
        
        AudioEnvironmentDemo *demo = [[AudioEnvironmentDemo alloc] init];
        
        [app run];
    }
    return 0;
}

// Makefile target information:
/*
To build this demo:

1. Create a Makefile target:

audio_environment_demo: demos/audio_environment_demo.m src/audio/*.s src/simulation/*.s
	clang -framework Foundation -framework Metal -framework MetalKit -framework AVFoundation -framework AppKit \
	      -I./src -O2 -target arm64-apple-macos11.0 \
	      demos/audio_environment_demo.m \
	      src/audio/core_audio.s \
	      src/audio/positional.s \
	      src/audio/environmental_audio.s \
	      src/simulation/weather_system.s \
	      src/simulation/environment_effects.s \
	      src/simulation/time_system.s \
	      -o demos/audio_environment_demo

2. Run the demo:
   ./demos/audio_environment_demo

3. Features demonstrated:
   - Real-time weather changes affecting audio
   - Day/night cycle with lighting changes
   - 3D positioned ambient sounds
   - Weather-synchronized particle effects
   - Environmental reverb and acoustics
   - Performance monitoring
   - Interactive controls

4. Integration points shown:
   - Weather system → Audio system
   - Time system → Lighting system
   - Environment → Particle effects
   - All systems → Performance monitoring
*/