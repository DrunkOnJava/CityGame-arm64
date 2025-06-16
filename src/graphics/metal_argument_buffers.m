// SimCity ARM64 Metal Argument Buffer System
// Agent 3: Graphics & Rendering Pipeline
// Optimized argument buffers for Apple Silicon GPUs

#import <Metal/Metal.h>
#import <Foundation/Foundation.h>
#import "metal_argument_buffers.h"

// Performance constants for Apple Silicon
static const NSUInteger kArgumentBufferAlignment = 256;  // GPU memory alignment
static const NSUInteger kMaxArgumentBuffers = 16;       // Maximum concurrent buffers
static const NSUInteger kArgumentBufferPoolSize = 64;   // Pre-allocated buffer pool

// Argument buffer resource binding indices
typedef NS_ENUM(NSUInteger, ArgumentBufferIndex) {
    ArgumentBufferIndexScene = 0,
    ArgumentBufferIndexTile = 1,
    ArgumentBufferIndexWeather = 2,
    ArgumentBufferIndexLighting = 3,
    ArgumentBufferIndexMaterial = 4,
    ArgumentBufferIndexInstances = 5,
    ArgumentBufferIndexCulling = 6,
    ArgumentBufferIndexPostProcess = 7
};

@interface MetalArgumentBufferSystem : NSObject

@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) NSMutableArray<id<MTLBuffer>>* bufferPool;
@property (nonatomic, strong) NSMutableDictionary* encoderCache;
@property (nonatomic, strong) dispatch_queue_t bufferQueue;
@property (nonatomic, assign) NSUInteger nextBufferIndex;

// Performance tracking
@property (nonatomic, assign) NSUInteger totalAllocations;
@property (nonatomic, assign) NSUInteger cacheHits;
@property (nonatomic, assign) NSUInteger cacheMisses;

- (instancetype)initWithDevice:(id<MTLDevice>)device;
- (id<MTLArgumentEncoder>)encoderForStructure:(NSString*)structureName;
- (id<MTLBuffer>)createArgumentBufferWithEncoder:(id<MTLArgumentEncoder>)encoder;
- (void)encodeSceneUniforms:(SceneUniforms*)uniforms inBuffer:(id<MTLBuffer>)buffer;
- (void)encodeTileUniforms:(TileUniforms*)uniforms inBuffer:(id<MTLBuffer>)buffer;
- (void)encodeWeatherUniforms:(WeatherUniforms*)uniforms inBuffer:(id<MTLBuffer>)buffer;

@end

@implementation MetalArgumentBufferSystem

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _device = device;
        _bufferPool = [[NSMutableArray alloc] initWithCapacity:kArgumentBufferPoolSize];
        _encoderCache = [[NSMutableDictionary alloc] init];
        _bufferQueue = dispatch_queue_create("com.simcity.argument_buffers", 
                                           DISPATCH_QUEUE_CONCURRENT);
        _nextBufferIndex = 0;
        
        // Pre-allocate argument buffer pool
        [self preallocateBufferPool];
        
        // Initialize performance counters
        _totalAllocations = 0;
        _cacheHits = 0;
        _cacheMisses = 0;
    }
    return self;
}

- (void)preallocateBufferPool {
    for (NSUInteger i = 0; i < kArgumentBufferPoolSize; i++) {
        // Create a large buffer that can hold multiple argument structures
        NSUInteger bufferSize = sizeof(SceneUniforms) + sizeof(TileUniforms) + 
                               sizeof(WeatherUniforms) + kArgumentBufferAlignment;
        
        id<MTLBuffer> buffer = [self.device newBufferWithLength:bufferSize
                                                       options:MTLResourceStorageModeShared];
        buffer.label = [NSString stringWithFormat:@"ArgumentBuffer_%lu", i];
        
        [self.bufferPool addObject:buffer];
    }
    
    NSLog(@"Pre-allocated %lu argument buffers (%lu KB total)", 
          kArgumentBufferPoolSize, 
          (bufferSize * kArgumentBufferPoolSize) / 1024);
}

- (id<MTLArgumentEncoder>)encoderForStructure:(NSString*)structureName {
    // Check cache first
    id<MTLArgumentEncoder> encoder = self.encoderCache[structureName];
    if (encoder) {
        self.cacheHits++;
        return encoder;
    }
    
    self.cacheMisses++;
    
    // Create new encoder based on structure type
    NSArray<MTLArgumentDescriptor*>* arguments = nil;
    
    if ([structureName isEqualToString:@"SceneUniforms"]) {
        arguments = [self createSceneUniformsDescriptors];
    } else if ([structureName isEqualToString:@"TileUniforms"]) {
        arguments = [self createTileUniformsDescriptors];
    } else if ([structureName isEqualToString:@"WeatherUniforms"]) {
        arguments = [self createWeatherUniformsDescriptors];
    } else {
        NSLog(@"Unknown argument structure: %@", structureName);
        return nil;
    }
    
    encoder = [self.device newArgumentEncoderWithArguments:arguments];
    encoder.label = [NSString stringWithFormat:@"ArgumentEncoder_%@", structureName];
    
    // Cache for future use
    self.encoderCache[structureName] = encoder;
    
    return encoder;
}

- (NSArray<MTLArgumentDescriptor*>*)createSceneUniformsDescriptors {
    NSMutableArray* descriptors = [[NSMutableArray alloc] init];
    
    // View-projection matrix
    MTLArgumentDescriptor* viewProjDesc = [MTLArgumentDescriptor argumentDescriptor];
    viewProjDesc.index = 0;
    viewProjDesc.dataType = MTLDataTypeFloat4x4;
    viewProjDesc.access = MTLArgumentAccessReadOnly;
    [descriptors addObject:viewProjDesc];
    
    // Isometric matrix
    MTLArgumentDescriptor* isoDesc = [MTLArgumentDescriptor argumentDescriptor];
    isoDesc.index = 1;
    isoDesc.dataType = MTLDataTypeFloat4x4;
    isoDesc.access = MTLArgumentAccessReadOnly;
    [descriptors addObject:isoDesc];
    
    // Camera position
    MTLArgumentDescriptor* cameraPosDesc = [MTLArgumentDescriptor argumentDescriptor];
    cameraPosDesc.index = 2;
    cameraPosDesc.dataType = MTLDataTypeFloat3;
    cameraPosDesc.access = MTLArgumentAccessReadOnly;
    [descriptors addObject:cameraPosDesc];
    
    // Time
    MTLArgumentDescriptor* timeDesc = [MTLArgumentDescriptor argumentDescriptor];
    timeDesc.index = 3;
    timeDesc.dataType = MTLDataTypeFloat;
    timeDesc.access = MTLArgumentAccessReadOnly;
    [descriptors addObject:timeDesc];
    
    // Fog color
    MTLArgumentDescriptor* fogColorDesc = [MTLArgumentDescriptor argumentDescriptor];
    fogColorDesc.index = 4;
    fogColorDesc.dataType = MTLDataTypeFloat4;
    fogColorDesc.access = MTLArgumentAccessReadOnly;
    [descriptors addObject:fogColorDesc];
    
    // Additional descriptors for other scene uniforms...
    
    return [descriptors copy];
}

- (NSArray<MTLArgumentDescriptor*>*)createTileUniformsDescriptors {
    NSMutableArray* descriptors = [[NSMutableArray alloc] init];
    
    // Tile position
    MTLArgumentDescriptor* tilePosDesc = [MTLArgumentDescriptor argumentDescriptor];
    tilePosDesc.index = 0;
    tilePosDesc.dataType = MTLDataTypeFloat2;
    tilePosDesc.access = MTLArgumentAccessReadOnly;
    [descriptors addObject:tilePosDesc];
    
    // Elevation
    MTLArgumentDescriptor* elevationDesc = [MTLArgumentDescriptor argumentDescriptor];
    elevationDesc.index = 1;
    elevationDesc.dataType = MTLDataTypeFloat;
    elevationDesc.access = MTLArgumentAccessReadOnly;
    [descriptors addObject:elevationDesc];
    
    // Tile type
    MTLArgumentDescriptor* tileTypeDesc = [MTLArgumentDescriptor argumentDescriptor];
    tileTypeDesc.index = 2;
    tileTypeDesc.dataType = MTLDataTypeFloat;
    tileTypeDesc.access = MTLArgumentAccessReadOnly;
    [descriptors addObject:tileTypeDesc];
    
    // Tile color
    MTLArgumentDescriptor* tileColorDesc = [MTLArgumentDescriptor argumentDescriptor];
    tileColorDesc.index = 3;
    tileColorDesc.dataType = MTLDataTypeFloat4;
    tileColorDesc.access = MTLArgumentAccessReadOnly;
    [descriptors addObject:tileColorDesc];
    
    return [descriptors copy];
}

- (NSArray<MTLArgumentDescriptor*>*)createWeatherUniformsDescriptors {
    NSMutableArray* descriptors = [[NSMutableArray alloc] init];
    
    // Rain intensity
    MTLArgumentDescriptor* rainDesc = [MTLArgumentDescriptor argumentDescriptor];
    rainDesc.index = 0;
    rainDesc.dataType = MTLDataTypeFloat;
    rainDesc.access = MTLArgumentAccessReadOnly;
    [descriptors addObject:rainDesc];
    
    // Fog density
    MTLArgumentDescriptor* fogDesc = [MTLArgumentDescriptor argumentDescriptor];
    fogDesc.index = 1;
    fogDesc.dataType = MTLDataTypeFloat;
    fogDesc.access = MTLArgumentAccessReadOnly;
    [descriptors addObject:fogDesc];
    
    // Wind parameters
    MTLArgumentDescriptor* windSpeedDesc = [MTLArgumentDescriptor argumentDescriptor];
    windSpeedDesc.index = 2;
    windSpeedDesc.dataType = MTLDataTypeFloat;
    windSpeedDesc.access = MTLArgumentAccessReadOnly;
    [descriptors addObject:windSpeedDesc];
    
    MTLArgumentDescriptor* windDirDesc = [MTLArgumentDescriptor argumentDescriptor];
    windDirDesc.index = 3;
    windDirDesc.dataType = MTLDataTypeFloat;
    windDirDesc.access = MTLArgumentAccessReadOnly;
    [descriptors addObject:windDirDesc];
    
    return [descriptors copy];
}

- (id<MTLBuffer>)createArgumentBufferWithEncoder:(id<MTLArgumentEncoder>)encoder {
    __block id<MTLBuffer> buffer = nil;
    
    dispatch_sync(self.bufferQueue, ^{
        // Try to reuse buffer from pool
        if (self.bufferPool.count > 0) {
            NSUInteger index = self.nextBufferIndex % self.bufferPool.count;
            buffer = self.bufferPool[index];
            self.nextBufferIndex++;
        } else {
            // Create new buffer if pool is exhausted
            NSUInteger bufferSize = encoder.encodedLength + kArgumentBufferAlignment;
            buffer = [self.device newBufferWithLength:bufferSize
                                             options:MTLResourceStorageModeShared];
            self.totalAllocations++;
        }
    });
    
    return buffer;
}

- (void)encodeSceneUniforms:(SceneUniforms*)uniforms inBuffer:(id<MTLBuffer>)buffer {
    id<MTLArgumentEncoder> encoder = [self encoderForStructure:@"SceneUniforms"];
    if (!encoder) return;
    
    [encoder setArgumentBuffer:buffer offset:0];
    
    // Encode matrices
    [encoder setBytes:&uniforms->viewProjectionMatrix 
               length:sizeof(simd_float4x4) 
              atIndex:0];
    [encoder setBytes:&uniforms->isometricMatrix 
               length:sizeof(simd_float4x4) 
              atIndex:1];
    
    // Encode vectors
    [encoder setBytes:&uniforms->cameraPosition 
               length:sizeof(simd_float3) 
              atIndex:2];
    [encoder setBytes:&uniforms->time 
               length:sizeof(float) 
              atIndex:3];
    [encoder setBytes:&uniforms->fogColor 
               length:sizeof(simd_float4) 
              atIndex:4];
    
    // Additional encoding for other scene uniform fields...
}

- (void)encodeTileUniforms:(TileUniforms*)uniforms inBuffer:(id<MTLBuffer>)buffer {
    id<MTLArgumentEncoder> encoder = [self encoderForStructure:@"TileUniforms"];
    if (!encoder) return;
    
    [encoder setArgumentBuffer:buffer offset:sizeof(SceneUniforms)];
    
    [encoder setBytes:&uniforms->tilePosition 
               length:sizeof(simd_float2) 
              atIndex:0];
    [encoder setBytes:&uniforms->elevation 
               length:sizeof(float) 
              atIndex:1];
    [encoder setBytes:&uniforms->tileType 
               length:sizeof(float) 
              atIndex:2];
    [encoder setBytes:&uniforms->tileColor 
               length:sizeof(simd_float4) 
              atIndex:3];
}

- (void)encodeWeatherUniforms:(WeatherUniforms*)uniforms inBuffer:(id<MTLBuffer>)buffer {
    id<MTLArgumentEncoder> encoder = [self encoderForStructure:@"WeatherUniforms"];
    if (!encoder) return;
    
    NSUInteger offset = sizeof(SceneUniforms) + sizeof(TileUniforms);
    [encoder setArgumentBuffer:buffer offset:offset];
    
    [encoder setBytes:&uniforms->rainIntensity 
               length:sizeof(float) 
              atIndex:0];
    [encoder setBytes:&uniforms->fogDensity 
               length:sizeof(float) 
              atIndex:1];
    [encoder setBytes:&uniforms->windSpeed 
               length:sizeof(float) 
              atIndex:2];
    [encoder setBytes:&uniforms->windDirection 
               length:sizeof(float) 
              atIndex:3];
}

- (void)printPerformanceStats {
    float cacheHitRatio = (float)self.cacheHits / (self.cacheHits + self.cacheMisses);
    
    NSLog(@"=== Argument Buffer Performance Stats ===");
    NSLog(@"Total allocations: %lu", self.totalAllocations);
    NSLog(@"Cache hits: %lu", self.cacheHits);
    NSLog(@"Cache misses: %lu", self.cacheMisses);
    NSLog(@"Cache hit ratio: %.2f%%", cacheHitRatio * 100.0f);
    NSLog(@"Buffer pool size: %lu", self.bufferPool.count);
}

@end

// C interface functions for use from assembly code
static MetalArgumentBufferSystem* g_argumentBufferSystem = nil;

void metal_argument_buffers_init(void* device) {
    @autoreleasepool {
        g_argumentBufferSystem = [[MetalArgumentBufferSystem alloc] 
                                 initWithDevice:(__bridge id<MTLDevice>)device];
        NSLog(@"Metal argument buffer system initialized");
    }
}

void* metal_create_scene_argument_buffer(SceneUniforms* uniforms) {
    @autoreleasepool {
        if (!g_argumentBufferSystem) return NULL;
        
        id<MTLArgumentEncoder> encoder = [g_argumentBufferSystem 
                                         encoderForStructure:@"SceneUniforms"];
        id<MTLBuffer> buffer = [g_argumentBufferSystem 
                               createArgumentBufferWithEncoder:encoder];
        
        [g_argumentBufferSystem encodeSceneUniforms:uniforms inBuffer:buffer];
        
        return (__bridge_retained void*)buffer;
    }
}

void* metal_create_tile_argument_buffer(TileUniforms* uniforms) {
    @autoreleasepool {
        if (!g_argumentBufferSystem) return NULL;
        
        id<MTLArgumentEncoder> encoder = [g_argumentBufferSystem 
                                         encoderForStructure:@"TileUniforms"];
        id<MTLBuffer> buffer = [g_argumentBufferSystem 
                               createArgumentBufferWithEncoder:encoder];
        
        [g_argumentBufferSystem encodeTileUniforms:uniforms inBuffer:buffer];
        
        return (__bridge_retained void*)buffer;
    }
}

void* metal_create_weather_argument_buffer(WeatherUniforms* uniforms) {
    @autoreleasepool {
        if (!g_argumentBufferSystem) return NULL;
        
        id<MTLArgumentEncoder> encoder = [g_argumentBufferSystem 
                                         encoderForStructure:@"WeatherUniforms"];
        id<MTLBuffer> buffer = [g_argumentBufferSystem 
                               createArgumentBufferWithEncoder:encoder];
        
        [g_argumentBufferSystem encodeWeatherUniforms:uniforms inBuffer:buffer];
        
        return (__bridge_retained void*)buffer;
    }
}

void metal_argument_buffer_release(void* buffer) {
    if (buffer) {
        CFRelease(buffer);
    }
}

void metal_argument_buffers_print_stats(void) {
    @autoreleasepool {
        if (g_argumentBufferSystem) {
            [g_argumentBufferSystem printPerformanceStats];
        }
    }
}