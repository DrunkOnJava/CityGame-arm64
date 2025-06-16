#import "NetworkGraph.h"
#import <mach/mach_time.h>

@implementation NetworkGraph

- (instancetype)initWithGridSize:(int)gridSize {
    self = [super init];
    if (self) {
        _gridSize = gridSize;
        _maxNodes = gridSize * gridSize;
        _maxEdges = _maxNodes * 4; // Assume max 4 connections per node
        _isInitialized = NO;
        _lastUpdateTime = 0;
        _averageUpdateCycles = 0;
        _updateCount = 0;
        
        // Initialize data structures
        _trafficDensityMap = [[NSMutableDictionary alloc] init];
        _intersectionStateMap = [[NSMutableDictionary alloc] init];
        _gridToNodeMap = [[NSMutableDictionary alloc] init];
        _gridToIntersectionMap = [[NSMutableDictionary alloc] init];
        
        NSLog(@"🌐 NetworkGraph initialized for %dx%d grid (max nodes: %d, max edges: %d)", 
              gridSize, gridSize, _maxNodes, _maxEdges);
    }
    return self;
}

- (BOOL)initializeNetwork {
    if (_isInitialized) {
        NSLog(@"⚠️ Network already initialized");
        return YES;
    }
    
    NSLog(@"🚀 Initializing ARM64 road network system...");
    
    // Call ARM64 assembly function to initialize the network
    int result = road_network_init(_maxNodes, _maxEdges);
    
    if (result == 1) {
        _isInitialized = YES;
        NSLog(@"✅ ARM64 road network initialized successfully");
        return YES;
    } else {
        NSLog(@"❌ Failed to initialize ARM64 road network");
        return NO;
    }
}

- (int)addNodeAtX:(int)x y:(int)y roadType:(RoadType)roadType capacity:(int)capacity {
    if (!_isInitialized) {
        NSLog(@"❌ Network not initialized");
        return -1;
    }
    
    // Check if node already exists at this position
    NSString *key = [self keyForX:x y:y];
    NSNumber *existingNodeId = _gridToNodeMap[key];
    if (existingNodeId) {
        return [existingNodeId intValue];
    }
    
    // Call ARM64 assembly function to add node
    int nodeId = road_network_add_node(x, y, (int)roadType, capacity);
    
    if (nodeId >= 0) {
        // Store the mapping
        _gridToNodeMap[key] = @(nodeId);
        NSLog(@"🔗 Added network node %d at (%d, %d) type: %ld", nodeId, x, y, (long)roadType);
        return nodeId;
    } else {
        NSLog(@"❌ Failed to add node at (%d, %d)", x, y);
        return -1;
    }
}

- (int)getNodeIdAtX:(int)x y:(int)y {
    NSString *key = [self keyForX:x y:y];
    NSNumber *nodeId = _gridToNodeMap[key];
    return nodeId ? [nodeId intValue] : -1;
}

- (BOOL)addEdgeFromNodeId:(int)fromNodeId toNodeId:(int)toNodeId weight:(int)weight capacity:(int)capacity {
    if (!_isInitialized) {
        NSLog(@"❌ Network not initialized");
        return NO;
    }
    
    // Call ARM64 assembly function to add edge
    int result = road_network_add_edge(fromNodeId, toNodeId, weight, capacity);
    
    if (result == 1) {
        NSLog(@"🔗 Added network edge %d -> %d (weight: %d, capacity: %d)", 
              fromNodeId, toNodeId, weight, capacity);
        return YES;
    } else {
        NSLog(@"❌ Failed to add edge %d -> %d", fromNodeId, toNodeId);
        return NO;
    }
}

- (BOOL)connectGridPositionFromX:(int)fromX fromY:(int)fromY toX:(int)toX toY:(int)toY weight:(int)weight capacity:(int)capacity {
    int fromNodeId = [self getNodeIdAtX:fromX y:fromY];
    int toNodeId = [self getNodeIdAtX:toX y:toY];
    
    if (fromNodeId < 0 || toNodeId < 0) {
        NSLog(@"❌ Cannot connect grid positions - nodes not found");
        return NO;
    }
    
    return [self addEdgeFromNodeId:fromNodeId toNodeId:toNodeId weight:weight capacity:capacity];
}

- (int)addIntersectionAtX:(int)x y:(int)y type:(int)intersectionType {
    if (!_isInitialized) {
        NSLog(@"❌ Network not initialized");
        return -1;
    }
    
    // Check if intersection already exists at this position
    NSString *key = [self keyForX:x y:y];
    NSNumber *existingIntersectionId = _gridToIntersectionMap[key];
    if (existingIntersectionId) {
        return [existingIntersectionId intValue];
    }
    
    // Call ARM64 assembly function to add intersection
    int intersectionId = road_network_add_intersection(x, y, intersectionType);
    
    if (intersectionId >= 0) {
        // Store the mapping
        _gridToIntersectionMap[key] = @(intersectionId);
        NSLog(@"🚦 Added intersection %d at (%d, %d) type: %d", intersectionId, x, y, intersectionType);
        return intersectionId;
    } else {
        NSLog(@"❌ Failed to add intersection at (%d, %d)", x, y);
        return -1;
    }
}

- (BOOL)connectIntersection:(int)intersectionId fromNodeId:(int)fromNodeId toNodeId:(int)toNodeId {
    if (!_isInitialized) {
        NSLog(@"❌ Network not initialized");
        return NO;
    }
    
    // Call ARM64 assembly function to connect intersection
    int result = road_network_connect_intersection(intersectionId, fromNodeId, toNodeId);
    
    if (result == 1) {
        NSLog(@"🚦 Connected intersection %d with nodes %d -> %d", intersectionId, fromNodeId, toNodeId);
        return YES;
    } else {
        NSLog(@"❌ Failed to connect intersection %d", intersectionId);
        return NO;
    }
}

- (void)updateTrafficSimulation:(NSTimeInterval)deltaTime {
    if (!_isInitialized) {
        return;
    }
    
    // Convert delta time to milliseconds
    int deltaTimeMs = (int)(deltaTime * 1000.0);
    
    // Get high-precision timer for performance measurement
    uint64_t startTime = mach_absolute_time();
    
    // Call ARM64 assembly function to update traffic simulation
    long processingCycles = road_network_update(deltaTimeMs);
    
    // Calculate elapsed time
    uint64_t endTime = mach_absolute_time();
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    uint64_t elapsedNanoseconds = (endTime - startTime) * timebase.numer / timebase.denom;
    double elapsedMs = elapsedNanoseconds / 1000000.0;
    
    // Update performance tracking
    _updateCount++;
    if (_averageUpdateCycles == 0) {
        _averageUpdateCycles = processingCycles;
    } else {
        _averageUpdateCycles = (_averageUpdateCycles * 0.9) + (processingCycles * 0.1);
    }
    _lastUpdateTime = elapsedMs;
    
    // Update traffic density map for visualization
    [self updateTrafficDensityMap];
    [self updateIntersectionStateMap];
    
    // Log performance every 60 updates (roughly once per second at 60 FPS)
    if (_updateCount % 60 == 0) {
        NSLog(@"🚦 Traffic update #%d: %.2fms CPU, %ld ARM64 cycles, avg %.1f cycles", 
              _updateCount, elapsedMs, processingCycles, (double)_averageUpdateCycles);
    }
}

- (void)updateTrafficDensityMap {
    // Update traffic density for all known edges
    [_trafficDensityMap removeAllObjects];
    
    for (NSString *fromKey in _gridToNodeMap) {
        CGPoint fromPoint = [self pointFromKey:fromKey];
        int fromNodeId = [_gridToNodeMap[fromKey] intValue];
        
        // Check adjacent positions for edges
        int adjacentPositions[][2] = {{0, 1}, {1, 0}, {0, -1}, {-1, 0}};
        
        for (int i = 0; i < 4; i++) {
            int toX = (int)fromPoint.x + adjacentPositions[i][0];
            int toY = (int)fromPoint.y + adjacentPositions[i][1];
            
            if (toX >= 0 && toX < _gridSize && toY >= 0 && toY < _gridSize) {
                int toNodeId = [self getNodeIdAtX:toX y:toY];
                if (toNodeId >= 0) {
                    // Get congestion level for this edge
                    TrafficLevel trafficLevel = [self getTrafficLevelForEdge:fromNodeId toNodeId:toNodeId];
                    if (trafficLevel >= 0) {
                        NSString *edgeKey = [NSString stringWithFormat:@"%@-%@", 
                                           fromKey, [self keyForX:toX y:toY]];
                        _trafficDensityMap[edgeKey] = @(trafficLevel);
                    }
                }
            }
        }
    }
}

- (void)updateIntersectionStateMap {
    // Update intersection states for visualization
    [_intersectionStateMap removeAllObjects];
    
    for (NSString *key in _gridToIntersectionMap) {
        int intersectionId = [_gridToIntersectionMap[key] intValue];
        
        int signalPhase, congestionLevel, queueTotal;
        road_network_get_intersection_state(intersectionId, &signalPhase, &congestionLevel, &queueTotal);
        
        // Store intersection state data
        NSDictionary *state = @{
            @"signalPhase": @(signalPhase),
            @"congestionLevel": @(congestionLevel),
            @"queueTotal": @(queueTotal)
        };
        [_intersectionStateMap setObject:state forKey:key];
    }
}

- (TrafficLevel)getTrafficLevelFromX:(int)fromX fromY:(int)fromY toX:(int)toX toY:(int)toY {
    int fromNodeId = [self getNodeIdAtX:fromX y:fromY];
    int toNodeId = [self getNodeIdAtX:toX y:toY];
    
    if (fromNodeId < 0 || toNodeId < 0) {
        return -1;
    }
    
    return [self getTrafficLevelForEdge:fromNodeId toNodeId:toNodeId];
}

- (TrafficLevel)getTrafficLevelForEdge:(int)fromNodeId toNodeId:(int)toNodeId {
    if (!_isInitialized) {
        return -1;
    }
    
    // Call ARM64 assembly function to get congestion level
    int congestionLevel = road_network_get_congestion(fromNodeId, toNodeId);
    
    return (TrafficLevel)congestionLevel;
}

- (NSArray<NSValue *> *)findPathFromX:(int)startX startY:(int)startY toX:(int)endX endY:(int)endY {
    if (!_isInitialized) {
        return nil;
    }
    
    int startNodeId = [self getNodeIdAtX:startX y:startY];
    int endNodeId = [self getNodeIdAtX:endX y:endY];
    
    if (startNodeId < 0 || endNodeId < 0) {
        NSLog(@"❌ Cannot find path - start or end node not found");
        return nil;
    }
    
    // Call ARM64 assembly function to find path
    long pathLength = road_network_find_path(startNodeId, endNodeId);
    
    if (pathLength < 0) {
        NSLog(@"❌ No path found from (%d, %d) to (%d, %d)", startX, startY, endX, endY);
        return nil;
    }
    
    // For now, return a simple path representation
    // In a full implementation, we would reconstruct the path from the ARM64 pathfinding result
    NSMutableArray *path = [[NSMutableArray alloc] init];
    [path addObject:[NSValue valueWithPoint:NSMakePoint(startX, startY)]];
    [path addObject:[NSValue valueWithPoint:NSMakePoint(endX, endY)]];
    
    NSLog(@"🗺️ Path found: length %ld", pathLength);
    return [path copy];
}

- (long)calculatePathDistance:(NSArray<NSValue *> *)path {
    if (path.count < 2) {
        return 0;
    }
    
    long totalDistance = 0;
    for (NSUInteger i = 0; i < path.count - 1; i++) {
        NSPoint from = [path[i] pointValue];
        NSPoint to = [path[i + 1] pointValue];
        
        // Simple Manhattan distance
        totalDistance += abs((int)to.x - (int)from.x) + abs((int)to.y - (int)from.y);
    }
    
    return totalDistance;
}

- (SignalPhase)getSignalPhaseForIntersectionAtX:(int)x y:(int)y {
    NSString *key = [self keyForX:x y:y];
    NSDictionary *state = [_intersectionStateMap objectForKey:key];
    
    if (state && [state isKindOfClass:[NSDictionary class]]) {
        return (SignalPhase)[state[@"signalPhase"] intValue];
    }
    
    return -1;
}

- (TrafficLevel)getIntersectionCongestionAtX:(int)x y:(int)y {
    NSString *key = [self keyForX:x y:y];
    NSDictionary *state = [_intersectionStateMap objectForKey:key];
    
    if (state && [state isKindOfClass:[NSDictionary class]]) {
        return (TrafficLevel)[state[@"congestionLevel"] intValue];
    }
    
    return -1;
}

- (int)getIntersectionQueueLengthAtX:(int)x y:(int)y {
    NSString *key = [self keyForX:x y:y];
    NSDictionary *state = [_intersectionStateMap objectForKey:key];
    
    if (state && [state isKindOfClass:[NSDictionary class]]) {
        return [state[@"queueTotal"] intValue];
    }
    
    return -1;
}

- (NSString *)keyForX:(int)x y:(int)y {
    return [NSString stringWithFormat:@"%d,%d", x, y];
}

- (NSPoint)pointFromKey:(NSString *)key {
    NSArray *components = [key componentsSeparatedByString:@","];
    if (components.count == 2) {
        return NSMakePoint([components[0] intValue], [components[1] intValue]);
    }
    return NSZeroPoint;
}

- (double)getAverageUpdateTimeMs {
    return _lastUpdateTime;
}

- (void)resetPerformanceCounters {
    _updateCount = 0;
    _averageUpdateCycles = 0;
    _lastUpdateTime = 0;
    NSLog(@"🔄 Performance counters reset");
}

- (int)getTotalNodes {
    return (int)_gridToNodeMap.count;
}

- (int)getTotalEdges {
    return (int)_trafficDensityMap.count;
}

- (int)getTotalIntersections {
    return (int)_gridToIntersectionMap.count;
}

- (double)getAverageTrafficDensity {
    if (_trafficDensityMap.count == 0) {
        return 0.0;
    }
    
    double totalDensity = 0.0;
    for (NSNumber *density in _trafficDensityMap.allValues) {
        totalDensity += [density doubleValue];
    }
    
    return totalDensity / _trafficDensityMap.count;
}

- (void)cleanup {
    if (_isInitialized) {
        NSLog(@"🧹 Cleaning up ARM64 road network...");
        road_network_cleanup();
        _isInitialized = NO;
    }
    
    [_trafficDensityMap removeAllObjects];
    [_intersectionStateMap removeAllObjects];
    [_gridToNodeMap removeAllObjects];
    [_gridToIntersectionMap removeAllObjects];
    
    NSLog(@"✅ NetworkGraph cleanup complete");
}

- (void)dealloc {
    [self cleanup];
}

@end