#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

// Traffic congestion levels (matching ARM64 assembly constants)
typedef NS_ENUM(NSInteger, TrafficLevel) {
    TrafficLevelFree = 0,
    TrafficLevelLight = 1,
    TrafficLevelMedium = 2,
    TrafficLevelHeavy = 3,
    TrafficLevelJammed = 4
};

// Road types (matching ARM64 assembly constants)
typedef NS_ENUM(NSInteger, RoadType) {
    RoadTypeNone = 0,
    RoadTypeResidential = 1,
    RoadTypeCommercial = 2,
    RoadTypeIndustrial = 3,
    RoadTypeHighway = 4,
    RoadTypeBridge = 5
};

// Intersection signal phases
typedef NS_ENUM(NSInteger, SignalPhase) {
    SignalPhaseNSGreen = 0,
    SignalPhaseNSYellow = 1,
    SignalPhaseEWGreen = 2,
    SignalPhaseEWYellow = 3
};

// Forward declarations for C functions from ARM64 assembly
extern int road_network_init(int max_nodes, int max_edges);
extern int road_network_add_node(int x_coord, int y_coord, int road_type, int capacity);
extern int road_network_add_edge(int from_node_id, int to_node_id, int weight, int capacity);
extern long road_network_calculate_flow(void);
extern long road_network_find_path(int start_node_id, int end_node_id);
extern int road_network_get_congestion(int from_node_id, int to_node_id);
extern long road_network_update(int delta_time_ms);
extern int road_network_add_intersection(int x_coord, int y_coord, int intersection_type);
extern int road_network_connect_intersection(int intersection_id, int road_from_id, int road_to_id);
extern void road_network_get_intersection_state(int intersection_id, int *signal_phase, int *congestion_level, int *queue_total);
extern void road_network_cleanup(void);

@interface NetworkGraph : NSObject

// Core network properties
@property (nonatomic, assign) int gridSize;
@property (nonatomic, assign) int maxNodes;
@property (nonatomic, assign) int maxEdges;
@property (nonatomic, assign) BOOL isInitialized;

// Performance tracking
@property (nonatomic, assign) NSTimeInterval lastUpdateTime;
@property (nonatomic, assign) long averageUpdateCycles;
@property (nonatomic, assign) int updateCount;

// Traffic density data for visualization
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *trafficDensityMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *intersectionStateMap;

// Node and edge mappings (grid coordinates to network IDs)
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *gridToNodeMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *gridToIntersectionMap;

// Initialization
- (instancetype)initWithGridSize:(int)gridSize;
- (BOOL)initializeNetwork;

// Node management
- (int)addNodeAtX:(int)x y:(int)y roadType:(RoadType)roadType capacity:(int)capacity;
- (int)getNodeIdAtX:(int)x y:(int)y;

// Edge management  
- (BOOL)addEdgeFromNodeId:(int)fromNodeId toNodeId:(int)toNodeId weight:(int)weight capacity:(int)capacity;
- (BOOL)connectGridPositionFromX:(int)fromX fromY:(int)fromY toX:(int)toX toY:(int)toY weight:(int)weight capacity:(int)capacity;

// Intersection management
- (int)addIntersectionAtX:(int)x y:(int)y type:(int)intersectionType;
- (BOOL)connectIntersection:(int)intersectionId fromNodeId:(int)fromNodeId toNodeId:(int)toNodeId;

// Traffic simulation
- (void)updateTrafficSimulation:(NSTimeInterval)deltaTime;
- (TrafficLevel)getTrafficLevelFromX:(int)fromX fromY:(int)fromY toX:(int)toX toY:(int)toY;
- (TrafficLevel)getTrafficLevelForEdge:(int)fromNodeId toNodeId:(int)toNodeId;

// Pathfinding
- (NSArray<NSValue *> *)findPathFromX:(int)startX startY:(int)startY toX:(int)endX endY:(int)endY;
- (long)calculatePathDistance:(NSArray<NSValue *> *)path;

// Intersection state
- (SignalPhase)getSignalPhaseForIntersectionAtX:(int)x y:(int)y;
- (TrafficLevel)getIntersectionCongestionAtX:(int)x y:(int)y;
- (int)getIntersectionQueueLengthAtX:(int)x y:(int)y;

// Grid integration helpers
- (NSString *)keyForX:(int)x y:(int)y;
- (NSPoint)pointFromKey:(NSString *)key;

// Performance monitoring
- (double)getAverageUpdateTimeMs;
- (void)resetPerformanceCounters;

// Network analysis
- (int)getTotalNodes;
- (int)getTotalEdges;
- (int)getTotalIntersections;
- (double)getAverageTrafficDensity;

// Cleanup
- (void)cleanup;

@end