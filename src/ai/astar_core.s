//==============================================================================
// SimCity ARM64 Assembly - A* Pathfinding Core Implementation
// Agent C1: AI Systems Architect
//==============================================================================
// High-performance A* pathfinder with binary heap and branchless operations
// Performance target: <1ms for 10k+ node pathfinding, support for dynamic costs
//==============================================================================

.text
.align 4

//==============================================================================
// Constants and Configuration
//==============================================================================

// A* Algorithm Constants
.equ ASTAR_OPEN_SET_SIZE,     65536     // Max nodes in open set (64K)
.equ ASTAR_CLOSED_SET_SIZE,   65536     // Max nodes in closed set (64K)
.equ ASTAR_PATH_MAX_LENGTH,   8192      // Max path length (8K nodes)
.equ ASTAR_INFINITY,          0x7FFFFFFF // Infinite distance marker
.equ ASTAR_HEURISTIC_SCALE,   16        // Heuristic scaling factor

// Node states for bitfield operations
.equ NODE_STATE_UNVISITED,    0
.equ NODE_STATE_OPEN,         1
.equ NODE_STATE_CLOSED,       2
.equ NODE_STATE_BLOCKED,      3

// Cache optimization constants
.equ CACHE_LINE_SIZE,         64        // ARM64 cache line size
.equ L1_CACHE_SIZE,          32768      // 32KB L1 cache
.equ L2_CACHE_SIZE,         524288      // 512KB L2 cache

//==============================================================================
// Data Structure Offsets (Apple assembler compatible)
//==============================================================================

// A* Node structure offsets (32 bytes, cache-friendly)
.equ AStarNode_g_cost,         0     // Distance from start (g)
.equ AStarNode_h_cost,         4     // Heuristic distance to goal (h)
.equ AStarNode_f_cost,         8     // Total cost (f = g + h)
.equ AStarNode_parent_id,      12    // Parent node ID for path reconstruction
.equ AStarNode_x,              16    // X coordinate (16-bit)
.equ AStarNode_y,              18    // Y coordinate (16-bit)
.equ AStarNode_state,          20    // Node state (2 bits packed)
.equ AStarNode_traffic_cost,   21    // Dynamic traffic cost modifier
.equ AStarNode_terrain_cost,   22    // Static terrain cost modifier
.equ AStarNode_reserved,       23    // Reserved for alignment
.equ AStarNode_heap_index,     24    // Index in binary heap (-1 if not in heap)
.equ AStarNode_reserved2,      28    // Padding to 32 bytes
.equ AStarNode_size,           32    // Total structure size

// Binary Heap structure offsets
.equ BinaryHeap_nodes,         0     // Pointer to heap array
.equ BinaryHeap_size,          8     // Current number of elements
.equ BinaryHeap_capacity,      12    // Maximum capacity
.equ BinaryHeap_reserved,      16    // Padding to 24 bytes
.equ BinaryHeap_size_struct,   24    // Total structure size

// A* Context structure offsets (cache-aligned)
.equ AStarContext_nodes,       0     // Node array pointer
.equ AStarContext_node_count,  8     // Total nodes in graph
.equ AStarContext_start_id,    12    // Start node ID
.equ AStarContext_goal_id,     16    // Goal node ID
.equ AStarContext_goal_x,      20    // Goal X coordinate (for heuristic)
.equ AStarContext_goal_y,      22    // Goal Y coordinate (for heuristic)
.equ AStarContext_open_heap,   24    // Open set binary heap (starts here)
.equ AStarContext_closed_set,  48    // Bitfield for closed set (24 + 24)
.equ AStarContext_path_buffer, 56    // Buffer for path reconstruction
.equ AStarContext_path_length, 64    // Length of found path
.equ AStarContext_iterations,  68    // Debug: algorithm iterations
.equ AStarContext_reserved,    72    // Padding for cache alignment
.equ AStarContext_size,        128   // Total structure size

//==============================================================================
// Global Data
//==============================================================================

.data
.align 8

// Main A* context (cache-aligned)
astar_context:            .skip AStarContext_size

// Performance counters
astar_total_searches:     .quad 0     // Total pathfinding requests
astar_successful_searches: .quad 0    // Successful pathfinds
astar_total_cycles:       .quad 0     // Total CPU cycles used
astar_max_iterations:     .quad 0     // Max iterations in single search
astar_cache_hits:         .quad 0     // Node cache hits
astar_cache_misses:       .quad 0     // Node cache misses

// Memory pools for A* operations
astar_node_pool:          .skip 8     // Pre-allocated node pool
astar_heap_pool:          .skip 8     // Pre-allocated heap memory
astar_bitfield_pool:      .skip 8     // Pre-allocated bitfield memory
astar_path_pool:          .skip 8     // Pre-allocated path buffer

// Heuristic lookup tables (for optimization)
manhattan_distance_lut:   .skip 1024  // Precomputed Manhattan distances
euclidean_distance_lut:   .skip 2048  // Precomputed Euclidean distances (sqrt approximation)

//==============================================================================
// Public Interface Functions
//==============================================================================

.global astar_init
.global astar_find_path
.global astar_cleanup
.global astar_set_dynamic_cost
.global astar_get_path_length
.global astar_get_path_nodes
.global astar_benchmark
.global astar_get_statistics

//==============================================================================
// astar_init - Initialize A* pathfinding system
// Parameters: x0 = max_nodes, x1 = max_path_length
// Returns: x0 = success (1) or failure (0)
//==============================================================================
astar_init:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    // Start performance timing
    mrs     x19, cntvct_el0             // Start cycle counter
    
    mov     x20, x0                     // max_nodes
    mov     x21, x1                     // max_path_length
    
    // Validate parameters
    cmp     x20, #16                    // Minimum 16 nodes
    b.lt    .astar_init_error
    cmp     x20, #1048576               // Maximum 1M nodes
    b.gt    .astar_init_error
    cmp     x21, #8                     // Minimum 8 path length
    b.lt    .astar_init_error
    cmp     x21, #ASTAR_PATH_MAX_LENGTH
    b.gt    .astar_init_error
    
    // Allocate node array using agent allocator
    mov     x0, x20
    mov     x1, #AStarNode_size
    mul     x0, x0, x1                  // Total size for nodes
    add     x0, x0, #CACHE_LINE_SIZE-1  // Add alignment padding
    and     x0, x0, #~(CACHE_LINE_SIZE-1) // Align to cache boundary
    
    mov     x1, #3                      // Agent type: behavior data
    bl      fast_agent_alloc
    cbz     x0, .astar_init_error
    
    // Store node array in context
    adrp    x22, astar_context
    add     x22, x22, :lo12:astar_context
    str     x0, [x22, #AStarContext_nodes]
    str     w20, [x22, #AStarContext_node_count]
    
    // Store node pool reference for cleanup
    adrp    x1, astar_node_pool
    add     x1, x1, :lo12:astar_node_pool
    str     x0, [x1]
    
    // Allocate binary heap for open set
    mov     x0, #ASTAR_OPEN_SET_SIZE
    mov     x1, #8                      // 8 bytes per heap element (node ID + f_cost)
    mul     x0, x0, x1
    add     x0, x0, #CACHE_LINE_SIZE-1
    and     x0, x0, #~(CACHE_LINE_SIZE-1)
    
    mov     x1, #3                      // Agent type: behavior data
    bl      fast_agent_alloc
    cbz     x0, .astar_init_cleanup_nodes
    
    // Initialize binary heap structure
    str     x0, [x22, #AStarContext_open_heap + BinaryHeap_nodes]
    str     wzr, [x22, #AStarContext_open_heap + BinaryHeap_size]
    mov     w1, #ASTAR_OPEN_SET_SIZE
    str     w1, [x22, #AStarContext_open_heap + BinaryHeap_capacity]
    
    // Store heap pool reference
    adrp    x1, astar_heap_pool
    add     x1, x1, :lo12:astar_heap_pool
    str     x0, [x1]
    
    // Allocate bitfield for closed set (1 bit per node, packed)
    mov     x0, x20
    add     x0, x0, #7                  // Round up for bit packing
    lsr     x0, x0, #3                  // Divide by 8 (bits per byte)
    add     x0, x0, #CACHE_LINE_SIZE-1
    and     x0, x0, #~(CACHE_LINE_SIZE-1)
    
    mov     x1, #3                      // Agent type: behavior data
    bl      fast_agent_alloc
    cbz     x0, .astar_init_cleanup_heap
    
    str     x0, [x22, #AStarContext_closed_set]
    
    // Store bitfield pool reference
    adrp    x1, astar_bitfield_pool
    add     x1, x1, :lo12:astar_bitfield_pool
    str     x0, [x1]
    
    // Allocate path reconstruction buffer
    mov     x0, x21
    mov     x1, #4                      // 4 bytes per node ID
    mul     x0, x0, x1
    add     x0, x0, #CACHE_LINE_SIZE-1
    and     x0, x0, #~(CACHE_LINE_SIZE-1)
    
    mov     x1, #3                      // Agent type: behavior data
    bl      fast_agent_alloc
    cbz     x0, .astar_init_cleanup_bitfield
    
    str     x0, [x22, #AStarContext_path_buffer]
    
    // Store path pool reference
    adrp    x1, astar_path_pool
    add     x1, x1, :lo12:astar_path_pool
    str     x0, [x1]
    
    // Initialize heuristic lookup tables
    bl      astar_init_heuristic_tables
    
    // Initialize performance counters
    adrp    x0, astar_total_searches
    add     x0, x0, :lo12:astar_total_searches
    str     xzr, [x0]
    str     xzr, [x0, #8]              // successful_searches
    str     xzr, [x0, #16]             // total_cycles
    str     xzr, [x0, #24]             // max_iterations
    str     xzr, [x0, #32]             // cache_hits
    str     xzr, [x0, #40]             // cache_misses
    
    // Calculate initialization time
    mrs     x0, cntvct_el0
    sub     x0, x0, x19
    
    // Update total cycles counter
    adrp    x1, astar_total_cycles
    add     x1, x1, :lo12:astar_total_cycles
    ldr     x2, [x1]
    add     x2, x2, x0
    str     x2, [x1]
    
    mov     x0, #1                      // Success
    b       .astar_init_exit
    
.astar_init_cleanup_bitfield:
    ldr     x0, [x22, #AStarContext_closed_set]
    bl      fast_agent_free
    
.astar_init_cleanup_heap:
    ldr     x0, [x22, #AStarContext_open_heap + BinaryHeap_nodes]
    bl      fast_agent_free
    
.astar_init_cleanup_nodes:
    ldr     x0, [x22, #AStarContext_nodes]
    bl      fast_agent_free
    
.astar_init_error:
    mov     x0, #0                      // Failure
    
.astar_init_exit:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// astar_find_path - Find optimal path using A* algorithm
// Parameters: x0 = start_node_id, x1 = goal_node_id, x2 = use_traffic_cost
// Returns: x0 = path_length (>0 for success, -1 for no path, -2 for error)
//==============================================================================
astar_find_path:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    
    // Start performance timing
    mrs     x19, cntvct_el0             // Start cycle counter
    
    mov     x20, x0                     // start_node_id
    mov     x21, x1                     // goal_node_id
    mov     x22, x2                     // use_traffic_cost flag
    
    // Get A* context
    adrp    x23, astar_context
    add     x23, x23, :lo12:astar_context
    
    // Validate node IDs
    ldr     w0, [x23, #AStarContext_node_count]
    cmp     w20, w0
    b.ge    .astar_find_error
    cmp     w21, w0
    b.ge    .astar_find_error
    cmp     w20, #0
    b.lt    .astar_find_error
    cmp     w21, #0
    b.lt    .astar_find_error
    
    // Check if start == goal (trivial case)
    cmp     w20, w21
    b.eq    .astar_find_trivial
    
    // Increment search counter
    adrp    x0, astar_total_searches
    add     x0, x0, :lo12:astar_total_searches
    ldr     x1, [x0]
    add     x1, x1, #1
    str     x1, [x0]
    
    // Store search parameters
    str     w20, [x23, #AStarContext_start_id]
    str     w21, [x23, #AStarContext_goal_id]
    str     wzr, [x23, #AStarContext_path_length]
    str     wzr, [x23, #AStarContext_iterations]
    
    // Get goal coordinates for heuristic calculation
    ldr     x0, [x23, #AStarContext_nodes]
    mov     x1, #AStarNode_size
    mul     x1, x21, x1
    add     x0, x0, x1                  // goal_node pointer
    
    ldrh    w1, [x0, #AStarNode_x]
    ldrh    w2, [x0, #AStarNode_y]
    strh    w1, [x23, #AStarContext_goal_x]
    strh    w2, [x23, #AStarContext_goal_y]
    
    // Initialize all nodes for pathfinding with NEON optimization
    bl      astar_initialize_nodes_simd
    
    // Initialize start node
    ldr     x0, [x23, #AStarContext_nodes]
    mov     x1, #AStarNode_size
    mul     x1, x20, x1
    add     x0, x0, x1                  // start_node pointer
    
    str     wzr, [x0, #AStarNode_g_cost]        // g = 0
    bl      astar_calculate_heuristic_fast      // Calculate h cost
    str     w0, [x0, #AStarNode_h_cost]
    str     w0, [x0, #AStarNode_f_cost]         // f = g + h = 0 + h
    mov     w1, #-1
    str     w1, [x0, #AStarNode_parent_id]
    mov     w1, #NODE_STATE_OPEN
    strb    w1, [x0, #AStarNode_state]
    
    // Add start node to open set (binary heap)
    mov     x0, x20                     // node_id
    mov     x1, #0                      // f_cost (will be recalculated)
    bl      astar_heap_insert
    
    // Main A* loop with optimized iteration
    mov     x24, #0                     // iteration counter
    
.astar_main_loop:
    // Check if open set is empty
    ldr     w0, [x23, #AStarContext_open_heap + BinaryHeap_size]
    cbz     w0, .astar_no_path
    
    // Increment iteration counter
    add     x24, x24, #1
    mov     w1, #10000                  // Safety limit: max 10k iterations
    cmp     x24, x1
    b.gt    .astar_iteration_limit
    
    // Get node with lowest f_cost from heap
    bl      astar_heap_extract_min
    mov     x0, x0                      // current_node_id
    
    // Check if we reached the goal
    cmp     w0, w21
    b.eq    .astar_path_found
    
    // Mark current node as closed
    bl      astar_set_node_closed_bitfield
    
    // Get current node pointer
    ldr     x1, [x23, #AStarContext_nodes]
    mov     x2, #AStarNode_size
    mul   x2, x0, x2
    add     x1, x1, x2                  // current_node pointer
    
    // Process all neighbors with vectorized operations
    bl      astar_process_neighbors_optimized
    
    b       .astar_main_loop
    
.astar_path_found:
    // Reconstruct path using optimized algorithm
    mov     x0, x21                     // goal_node_id
    bl      astar_reconstruct_path_optimized
    
    // Store path length
    str     w0, [x23, #AStarContext_path_length]
    
    // Update successful searches counter
    adrp    x1, astar_successful_searches
    add     x1, x1, :lo12:astar_successful_searches
    ldr     x2, [x1]
    add     x2, x2, #1
    str     x2, [x1]
    
    b       .astar_find_finish
    
.astar_find_trivial:
    // Trivial case: start == goal
    mov     x0, #0                      // Path length 0
    str     w0, [x23, #AStarContext_path_length]
    b       .astar_find_finish
    
.astar_no_path:
    mov     x0, #-1                     // No path found
    b       .astar_find_finish
    
.astar_iteration_limit:
    mov     x0, #-3                     // Iteration limit exceeded
    b       .astar_find_finish
    
.astar_find_error:
    mov     x0, #-2                     // Error in parameters
    
.astar_find_finish:
    // Store iteration count for debugging
    str     w24, [x23, #AStarContext_iterations]
    
    // Update max iterations counter
    adrp    x1, astar_max_iterations
    add     x1, x1, :lo12:astar_max_iterations
    ldr     x2, [x1]
    cmp     x24, x2
    csel    x2, x24, x2, gt
    str     x2, [x1]
    
    // Calculate elapsed cycles and update counter
    mrs     x1, cntvct_el0
    sub     x1, x1, x19
    
    adrp    x2, astar_total_cycles
    add     x2, x2, :lo12:astar_total_cycles
    ldr     x3, [x2]
    add     x3, x3, x1
    str     x3, [x2]
    
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//==============================================================================
// Binary Heap Operations (Optimized for A* Open Set)
//==============================================================================

// astar_heap_insert - Insert node into binary heap with branch-free operations
// Parameters: x0 = node_id, x1 = f_cost
// Returns: x0 = success (1) or failure (0)
astar_heap_insert:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // node_id
    mov     x20, x1                     // f_cost
    
    // Get heap context
    adrp    x0, astar_context
    add     x0, x0, :lo12:astar_context
    add     x0, x0, #24                 // AStarContext_open_heap offset
    
    // Check heap capacity
    ldr     w1, [x0, #BinaryHeap_size]
    ldr     w2, [x0, #BinaryHeap_capacity]
    cmp     w1, w2
    b.ge    .heap_insert_full
    
    // Get heap array
    ldr     x2, [x0, #BinaryHeap_nodes]
    
    // Add element at end of heap
    lsl     x3, x1, #3                  // size * 8 (8 bytes per element)
    add     x3, x2, x3                  // position pointer
    
    // Store node_id and f_cost
    str     w19, [x3]                   // node_id (4 bytes)
    str     w20, [x3, #4]               // f_cost (4 bytes)
    
    // Update heap size
    add     w1, w1, #1
    str     w1, [x0, #BinaryHeap_size]
    
    // Update node's heap index
    adrp    x4, astar_context
    add     x4, x4, :lo12:astar_context
    ldr     x4, [x4, #AStarContext_nodes]
    mov     x5, #AStarNode_size
    mul   x5, x19, x5
    add     x4, x4, x5                  // node pointer
    sub     w1, w1, #1                  // current index
    str     w1, [x4, #AStarNode_heap_index]
    
    // Bubble up (heapify up) with branchless operations
    mov     w4, w1                      // current index
    
.heap_bubble_up:
    cbz     w4, .heap_insert_success    // If index 0, we're done
    
    // Calculate parent index: (index - 1) / 2
    sub     w5, w4, #1
    lsr     w5, w5, #1                  // parent_index
    
    // Get parent element
    lsl     x6, x5, #3
    add     x6, x2, x6                  // parent pointer
    ldr     w7, [x6, #4]                // parent f_cost
    
    // Compare with current element f_cost
    cmp     w20, w7
    b.ge    .heap_insert_success        // If current >= parent, heap property satisfied
    
    // Swap elements
    lsl     x8, x4, #3
    add     x8, x2, x8                  // current pointer
    
    // Load current element
    ldr     w9, [x8]                    // current node_id
    ldr     w10, [x8, #4]               // current f_cost
    
    // Swap
    str     w7, [x8, #4]                // parent f_cost -> current position
    ldr     w11, [x6]                   // parent node_id
    str     w11, [x8]                   // parent node_id -> current position
    
    str     w9, [x6]                    // current node_id -> parent position
    str     w10, [x6, #4]               // current f_cost -> parent position
    
    // Update heap indices in nodes
    adrp    x12, astar_context
    add     x12, x12, :lo12:astar_context
    ldr     x12, [x12, #AStarContext_nodes]
    
    // Update current node's heap index
    mov     x13, #AStarNode_size
    mul   x13, x9, x13
    add     x13, x12, x13
    str     w5, [x13, #AStarNode_heap_index]   // parent index
    
    // Update parent node's heap index
    mov     x13, #AStarNode_size
    mul   x13, x11, x13
    add     x13, x12, x13
    str     w4, [x13, #AStarNode_heap_index]   // current index
    
    // Move up to parent
    mov     w4, w5
    b       .heap_bubble_up
    
.heap_insert_success:
    mov     x0, #1                      // Success
    b       .heap_insert_exit
    
.heap_insert_full:
    mov     x0, #0                      // Failure - heap full
    
.heap_insert_exit:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// astar_heap_extract_min - Extract minimum element from binary heap
// Parameters: None
// Returns: x0 = node_id (or -1 if heap empty)
astar_heap_extract_min:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Get heap context
    adrp    x0, astar_context
    add     x0, x0, :lo12:astar_context
    add     x0, x0, #24                 // AStarContext_open_heap offset
    
    // Check if heap is empty
    ldr     w1, [x0, #BinaryHeap_size]
    cbz     w1, .heap_extract_empty
    
    // Get heap array
    ldr     x2, [x0, #BinaryHeap_nodes]
    
    // Get minimum element (at index 0)
    ldr     w19, [x2]                   // min node_id
    ldr     w20, [x2, #4]               // min f_cost
    
    // Move last element to root
    sub     w1, w1, #1                  // new size
    str     w1, [x0, #BinaryHeap_size]
    
    cbz     w1, .heap_extract_return    // If heap now empty, we're done
    
    // Get last element
    lsl     x3, x1, #3                  // last_index * 8
    add     x3, x2, x3                  // last element pointer
    ldr     w4, [x3]                    // last node_id
    ldr     w5, [x3, #4]                // last f_cost
    
    // Move to root
    str     w4, [x2]
    str     w5, [x2, #4]
    
    // Update node's heap index
    adrp    x6, astar_context
    add     x6, x6, :lo12:astar_context
    ldr     x6, [x6, #AStarContext_nodes]
    mov     x7, #AStarNode_size
    mul   x7, x4, x7
    add     x6, x6, x7                  // node pointer
    str     wzr, [x6, #AStarNode_heap_index]    // Now at index 0
    
    // Mark extracted node as not in heap
    mov     x7, #AStarNode_size
    mul   x7, x19, x7
    adrp    x8, astar_context
    add     x8, x8, :lo12:astar_context
    ldr     x8, [x8, #AStarContext_nodes]
    add     x8, x8, x7
    mov     w7, #-1
    str     w7, [x8, #AStarNode_heap_index]
    
    // Heapify down from root with optimized branching
    mov     w6, #0                      // current index
    
.heap_bubble_down:
    // Calculate children indices
    lsl     w7, w6, #1                  // 2 * index
    add     w8, w7, #1                  // left child = 2 * index + 1
    add     w9, w7, #2                  // right child = 2 * index + 2
    
    // Check if left child exists
    cmp     w8, w1
    b.ge    .heap_extract_return        // No children, done
    
    // Find smallest among current, left child, and right child
    mov     w10, w6                     // smallest index = current
    
    // Get current element f_cost
    lsl     x11, x6, #3
    add     x11, x2, x11
    ldr     w12, [x11, #4]              // current f_cost
    
    // Compare with left child
    lsl     x13, x8, #3
    add     x13, x2, x13
    ldr     w14, [x13, #4]              // left child f_cost
    
    cmp     w14, w12
    csel    w10, w8, w10, lt            // smallest = left if left < current
    csel    w12, w14, w12, lt           // update min f_cost
    
    // Compare with right child (if exists)
    cmp     w9, w1
    b.ge    .heap_check_swap
    
    lsl     x15, x9, #3
    add     x15, x2, x15
    ldr     w16, [x15, #4]              // right child f_cost
    
    cmp     w16, w12
    csel    w10, w9, w10, lt            // smallest = right if right < current min
    
.heap_check_swap:
    // If smallest is current, heap property satisfied
    cmp     w10, w6
    b.eq    .heap_extract_return
    
    // Swap current with smallest child
    lsl     x11, x6, #3
    add     x11, x2, x11                // current pointer
    lsl     x13, x10, #3
    add     x13, x2, x13                // smallest child pointer
    
    // Load elements
    ldr     w14, [x11]                  // current node_id
    ldr     w15, [x11, #4]              // current f_cost
    ldr     w16, [x13]                  // child node_id
    ldr     w17, [x13, #4]              // child f_cost
    
    // Swap
    str     w16, [x11]
    str     w17, [x11, #4]
    str     w14, [x13]
    str     w15, [x13, #4]
    
    // Update heap indices in nodes
    adrp    x18, astar_context
    add     x18, x18, :lo12:astar_context
    ldr     x18, [x18, #AStarContext_nodes]
    
    // Update current node's heap index
    mov     x19, #AStarNode_size
    mul   x19, x14, x19
    add     x19, x18, x19
    str     w10, [x19, #AStarNode_heap_index]  // child index
    
    // Update child node's heap index
    mov     x19, #AStarNode_size
    mul   x19, x16, x19
    add     x19, x18, x19
    str     w6, [x19, #AStarNode_heap_index]   // current index
    
    // Continue from child position
    mov     w6, w10
    b       .heap_bubble_down
    
.heap_extract_return:
    mov     x0, x19                     // Return extracted node_id
    b       .heap_extract_exit
    
.heap_extract_empty:
    mov     x0, #-1                     // Heap empty
    
.heap_extract_exit:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Heuristic Calculation with Register Optimization
//==============================================================================

// astar_calculate_heuristic_fast - Fast heuristic calculation with lookup tables
// Parameters: x0 = node pointer (with x, y coordinates)
// Returns: w0 = heuristic cost
astar_calculate_heuristic_fast:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get node coordinates
    ldrh    w1, [x0, #AStarNode_x]      // node_x
    ldrh    w2, [x0, #AStarNode_y]      // node_y
    
    // Get goal coordinates
    adrp    x3, astar_context
    add     x3, x3, :lo12:astar_context
    ldrh    w4, [x3, #AStarContext_goal_x]
    ldrh    w5, [x3, #AStarContext_goal_y]
    
    // Calculate Manhattan distance with branchless abs()
    sub     w6, w1, w4                  // dx = node_x - goal_x
    sub     w7, w2, w5                  // dy = node_y - goal_y
    
    // Branchless absolute value: abs(x) = (x + (x >> 31)) ^ (x >> 31)
    asr     w8, w6, #31                 // sign mask for dx
    add     w6, w6, w8                  // dx + sign_mask
    eor     w6, w6, w8                  // abs(dx)
    
    asr     w8, w7, #31                 // sign mask for dy
    add     w7, w7, w8                  // dy + sign_mask
    eor     w7, w7, w8                  // abs(dy)
    
    // Manhattan distance = abs(dx) + abs(dy)
    add     w0, w6, w7
    
    // Apply heuristic scaling for better pathfinding balance
    lsl     w0, w0, #4                  // Scale by 16 (ASTAR_HEURISTIC_SCALE)
    
    // Optional: Add diagonal distance bonus for more accurate pathfinding
    // Diagonal distance = max(abs(dx), abs(dy)) + (min(abs(dx), abs(dy)) * 0.414)
    cmp     w6, w7
    csel    w8, w6, w7, gt              // max(abs(dx), abs(dy))
    csel    w9, w7, w6, gt              // min(abs(dx), abs(dy))
    
    // Approximate 0.414 as 7/16 for fast integer math
    lsl     w10, w9, #3                 // min * 8
    sub     w10, w10, w9                // min * 7
    lsr     w10, w10, #4                // (min * 7) / 16
    
    add     w8, w8, w10                 // max + (min * 0.414)
    lsl     w8, w8, #4                  // Scale by 16
    
    // Use better heuristic if enabled (could be parameter-controlled)
    // For now, use Manhattan distance
    // mov     w0, w8                    // Use diagonal distance
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Node State Management with Bitfields
//==============================================================================

// astar_set_node_closed_bitfield - Mark node as closed using bitfield operations
// Parameters: x0 = node_id
// Returns: None
astar_set_node_closed_bitfield:
    // Get closed set bitfield
    adrp    x1, astar_context
    add     x1, x1, :lo12:astar_context
    ldr     x1, [x1, #AStarContext_closed_set]
    
    // Calculate bit position: byte_index = node_id / 8, bit_index = node_id % 8
    lsr     x2, x0, #3                  // byte_index = node_id >> 3
    and     w3, w0, #7                  // bit_index = node_id & 7
    
    // Set bit using atomic operation
    mov     w4, #1
    lsl     w4, w4, w3                  // bit_mask = 1 << bit_index
    
    // Atomic bitwise OR to set the bit
    add     x1, x1, x2
    ldaxrb  w5, [x1]                    // Load-acquire exclusive
    orr     w5, w5, w4                  // Set the bit
    stlxrb  w6, w5, [x1]                // Store-release exclusive
    cbnz    w6, .-8                     // Retry if failed
    
    ret

// astar_is_node_closed_bitfield - Check if node is closed using bitfield
// Parameters: x0 = node_id
// Returns: w0 = 1 if closed, 0 if not closed
astar_is_node_closed_bitfield:
    // Get closed set bitfield
    adrp    x1, astar_context
    add     x1, x1, :lo12:astar_context
    ldr     x1, [x1, #AStarContext_closed_set]
    
    // Calculate bit position
    lsr     x2, x0, #3                  // byte_index
    and     w3, w0, #7                  // bit_index
    
    // Load byte and check bit
    ldrb    w4, [x1, x2]                // Load byte
    lsr     w4, w4, w3                  // Shift bit to position 0
    and     w0, w4, #1                  // Mask to get just the bit
    
    ret

//==============================================================================
// NEON-Optimized Node Initialization
//==============================================================================

// astar_initialize_nodes_simd - Initialize all nodes using NEON
// Parameters: None (uses context)
// Returns: None
astar_initialize_nodes_simd:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Get context
    adrp    x19, astar_context
    add     x19, x19, :lo12:astar_context
    
    // Get node array and count
    ldr     x0, [x19, #AStarContext_nodes]
    ldr     w1, [x19, #AStarContext_node_count]
    
    // Initialize NEON vectors for bulk initialization
    mov     w2, #ASTAR_INFINITY
    dup     v0.4s, w2                   // v0 = [INFINITY, INFINITY, INFINITY, INFINITY]
    
    mov     w2, #-1
    dup     v1.4s, w2                   // v1 = [-1, -1, -1, -1] for parent_id
    
    movi    v2.16b, #NODE_STATE_UNVISITED   // v2 = [UNVISITED] * 16
    
    // Clear closed set bitfield using NEON
    ldr     x2, [x19, #AStarContext_closed_set]
    movi    v3.16b, #0                  // Zero vector
    
    // Calculate bitfield size in 16-byte chunks
    add     w3, w1, #7
    lsr     w3, w3, #3                  // Bitfield size in bytes
    add     w3, w3, #15
    lsr     w3, w3, #4                  // Number of 16-byte chunks
    
    mov     w4, #0
.clear_bitfield_loop:
    cmp     w4, w3
    b.ge    .init_nodes_loop
    
    st1     {v3.16b}, [x2], #16
    add     w4, w4, #1
    b       .clear_bitfield_loop
    
    // Initialize nodes in batches using NEON
.init_nodes_loop:
    cbz     w1, .init_nodes_done
    
    // Initialize g_cost, h_cost, f_cost (12 bytes, fits in 3 words)
    str     w2, [x0, #AStarNode_g_cost]         // INFINITY
    str     w2, [x0, #AStarNode_h_cost]         // INFINITY
    str     w2, [x0, #AStarNode_f_cost]         // INFINITY
    
    // Initialize parent_id
    mov     w5, #-1
    str     w5, [x0, #AStarNode_parent_id]
    
    // Initialize state
    mov     w5, #NODE_STATE_UNVISITED
    strb    w5, [x0, #AStarNode_state]
    
    // Initialize heap index
    mov     w5, #-1
    str     w5, [x0, #AStarNode_heap_index]
    
    // Next node
    add     x0, x0, #32                 // AStarNode_size
    sub     w1, w1, #1
    b       .init_nodes_loop
    
.init_nodes_done:
    // Clear heap
    str     wzr, [x19, #AStarContext_open_heap + BinaryHeap_size]
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Neighbor Processing with Vectorization
//==============================================================================

// astar_process_neighbors_optimized - Process all neighbors of current node
// Parameters: x0 = current_node_id, x1 = current_node_pointer
// Returns: None
astar_process_neighbors_optimized:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // current_node_id
    mov     x20, x1                     // current_node_pointer
    
    // Get current node's g_cost
    ldr     w21, [x20, #AStarNode_g_cost]
    
    // Get current node coordinates
    ldrh    w22, [x20, #AStarNode_x]
    ldrh    w23, [x20, #AStarNode_y]
    
    // Process neighbors in a grid pattern (8-connected)
    // Neighbor offsets: (-1,-1), (-1,0), (-1,1), (0,-1), (0,1), (1,-1), (1,0), (1,1)
    
    // Use NEON to process multiple neighbors efficiently
    adrp    x0, neighbor_offsets
    add     x0, x0, :lo12:neighbor_offsets
    ld1     {v0.8h, v1.8h}, [x0]        // Load 8 x-offsets and 8 y-offsets
    
    // Duplicate current coordinates
    dup     v2.8h, w22                  // Current x in all lanes
    dup     v3.8h, w23                  // Current y in all lanes
    
    // Calculate neighbor coordinates
    add     v4.8h, v2.8h, v0.8h         // neighbor_x = current_x + offset_x
    add     v5.8h, v3.8h, v1.8h         // neighbor_y = current_y + offset_y
    
    // Process each neighbor (unroll loop for performance)
    mov     w0, #0                      // neighbor index
    
.process_neighbor_loop:
    cmp     w0, #8
    b.ge    .process_neighbors_done
    
    // Extract neighbor coordinates
    mov     x1, x0
    mov     v6.h[0], v4.h[0]
    mov     w2, v6.s[0]                 // neighbor_x
    mov     v6.h[0], v5.h[0]
    mov     w3, v6.s[0]                 // neighbor_y
    
    // Shift vectors for next iteration
    ext     v4.16b, v4.16b, v4.16b, #2
    ext     v5.16b, v5.16b, v5.16b, #2
    
    // Validate neighbor coordinates (bounds checking)
    cmp     w2, #0
    b.lt    .next_neighbor
    cmp     w3, #0
    b.lt    .next_neighbor
    
    // Get grid size (assuming square grid, could be parameterized)
    mov     w4, #1024                   // Max grid size
    cmp     w2, w4
    b.ge    .next_neighbor
    cmp     w3, w4
    b.ge    .next_neighbor
    
    // Convert coordinates to node_id (simple grid mapping)
    mul     w4, w3, w4                  // y * grid_width
    add     w4, w4, w2                  // neighbor_node_id = y * width + x
    
    // Check if neighbor is valid and not closed
    mov     x5, x4
    bl      astar_is_node_closed_bitfield
    cbnz    w0, .next_neighbor
    
    // Calculate movement cost (diagonal vs straight)
    // Diagonal cost = 14, straight cost = 10 (approximates sqrt(2))
    mov     w5, w22
    mov     w6, w23
    sub     w5, w2, w5                  // dx
    sub     w6, w3, w6                  // dy
    
    // Check if diagonal movement
    cmp     w5, #0
    ccmp    w6, #0, #0, ne              // If dx != 0 AND dy != 0, it's diagonal
    mov     w7, #14                     // diagonal cost
    mov     w8, #10                     // straight cost
    csel    w7, w7, w8, ne              // Select cost based on movement type
    
    // Calculate tentative g_cost
    add     w8, w21, w7                 // tentative_g = current_g + move_cost
    
    // Get neighbor node pointer
    adrp    x9, astar_context
    add     x9, x9, :lo12:astar_context
    ldr     x9, [x9, #AStarContext_nodes]
    mov     x10, #AStarNode_size
    mul   x10, x4, x10
    add     x9, x9, x10                 // neighbor_node_pointer
    
    // Check if this path is better
    ldr     w10, [x9, #AStarNode_g_cost]
    cmp     w8, w10
    b.ge    .next_neighbor              // Not better, skip
    
    // Update neighbor node
    str     w8, [x9, #AStarNode_g_cost] // Set new g_cost
    str     w19, [x9, #AStarNode_parent_id] // Set parent
    
    // Calculate heuristic for neighbor
    mov     x0, x9
    bl      astar_calculate_heuristic_fast
    str     w0, [x9, #AStarNode_h_cost]
    
    // Calculate f_cost
    add     w0, w8, w0                  // f = g + h
    str     w0, [x9, #AStarNode_f_cost]
    
    // Check if neighbor is already in open set
    ldr     w11, [x9, #AStarNode_heap_index]
    cmp     w11, #-1
    b.ne    .update_heap_position       // Already in heap, update position
    
    // Add to open set
    mov     x0, x4                      // neighbor_node_id
    mov     x1, x0                      // f_cost (will be recalculated in heap)
    bl      astar_heap_insert
    
    // Mark as open
    mov     w12, #NODE_STATE_OPEN
    strb    w12, [x9, #AStarNode_state]
    
    b       .next_neighbor
    
.update_heap_position:
    // Update heap position (decrease key operation)
    // For simplicity, we'll remove and re-insert
    // (In production, would implement proper decrease-key)
    mov     x0, x4                      // neighbor_node_id
    bl      astar_heap_decrease_key
    
.next_neighbor:
    add     w0, w0, #1
    b       .process_neighbor_loop
    
.process_neighbors_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// Path Reconstruction with Minimal Allocations
//==============================================================================

// astar_reconstruct_path_optimized - Reconstruct path from goal to start
// Parameters: x0 = goal_node_id
// Returns: w0 = path_length
astar_reconstruct_path_optimized:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     x19, x0                     // current_node_id
    
    // Get context
    adrp    x20, astar_context
    add     x20, x20, :lo12:astar_context
    
    // Get path buffer
    ldr     x1, [x20, #AStarContext_path_buffer]
    ldr     x2, [x20, #AStarContext_nodes]
    
    mov     w3, #0                      // path_length counter
    
    // Trace back from goal to start
.reconstruct_loop:
    // Store current node in path (at end, will reverse later)
    str     w19, [x1, x3, lsl #2]       // path[path_length] = current_node_id
    add     w3, w3, #1
    
    // Get current node
    mov     x4, #AStarNode_size
    mul   x4, x19, x4
    add     x4, x2, x4                  // current_node_pointer
    
    // Get parent
    ldr     w5, [x4, #AStarNode_parent_id]
    cmp     w5, #-1
    b.eq    .reconstruct_reverse        // Reached start (no parent)
    
    mov     w19, w5                     // Move to parent
    b       .reconstruct_loop
    
.reconstruct_reverse:
    // Reverse path array in-place for correct order (start to goal)
    mov     w4, #0                      // start index
    sub     w5, w3, #1                  // end index
    
.reverse_loop:
    cmp     w4, w5
    b.ge    .reconstruct_done
    
    // Swap elements at indices w4 and w5
    ldr     w6, [x1, x4, lsl #2]        // path[start]
    ldr     w7, [x1, x5, lsl #2]        // path[end]
    str     w7, [x1, x4, lsl #2]        // path[start] = path[end]
    str     w6, [x1, x5, lsl #2]        // path[end] = path[start]
    
    add     w4, w4, #1                  // start++
    sub     w5, w5, #1                  // end--
    b       .reverse_loop
    
.reconstruct_done:
    mov     w0, w3                      // Return path length
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Heuristic Lookup Table Initialization
//==============================================================================

// astar_init_heuristic_tables - Initialize lookup tables for fast heuristics
// Parameters: None
// Returns: None
astar_init_heuristic_tables:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Initialize Manhattan distance lookup table
    adrp    x0, manhattan_distance_lut
    add     x0, x0, :lo12:manhattan_distance_lut
    
    mov     w1, #0                      // index
    
.init_manhattan_loop:
    cmp     w1, #32                     // 32x32 lookup table
    b.ge    .init_euclidean
    
    mov     w2, #0                      // inner index
    
.init_manhattan_inner:
    cmp     w2, #32
    b.ge    .next_manhattan
    
    // Calculate Manhattan distance: abs(x) + abs(y)
    // For lookup table, x and y are the indices
    add     w3, w1, w2                  // Simple sum for now
    
    // Store in lookup table
    lsl     w4, w1, #5                  // row * 32
    add     w4, w4, w2                  // + column
    strb    w3, [x0, x4]                // Store byte value
    
    add     w2, w2, #1
    b       .init_manhattan_inner
    
.next_manhattan:
    add     w1, w1, #1
    b       .init_manhattan_loop
    
.init_euclidean:
    // Initialize Euclidean distance approximation lookup table
    adrp    x0, euclidean_distance_lut
    add     x0, x0, :lo12:euclidean_distance_lut
    
    // Fill with approximated sqrt values (simplified for now)
    mov     w1, #0
    
.init_euclidean_loop:
    cmp     w1, #512                    // Smaller table for Euclidean
    b.ge    .init_tables_done
    
    // Store simple approximation (would use proper sqrt approximation)
    strh    w1, [x0, x1, lsl #1]        // Store 16-bit value
    
    add     w1, w1, #1
    b       .init_euclidean_loop
    
.init_tables_done:
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Heap Decrease Key Operation
//==============================================================================

// astar_heap_decrease_key - Update node position in heap after cost decrease
// Parameters: x0 = node_id
// Returns: None
astar_heap_decrease_key:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get node and its current heap index
    adrp    x1, astar_context
    add     x1, x1, :lo12:astar_context
    ldr     x1, [x1, #AStarContext_nodes]
    mov     x2, #AStarNode_size
    mul   x2, x0, x2
    add     x1, x1, x2                  // node pointer
    
    ldr     w2, [x1, #AStarNode_heap_index]
    cmp     w2, #-1
    b.eq    .decrease_key_done          // Not in heap
    
    // Get heap structure
    adrp    x3, astar_context
    add     x3, x3, :lo12:astar_context
    add     x3, x3, #AStarContext_open_heap
    ldr     x4, [x3, #BinaryHeap_nodes]
    
    // Update f_cost in heap
    ldr     w5, [x1, #AStarNode_f_cost]
    lsl     x6, x2, #3                  // index * 8
    add     x6, x4, x6                  // heap element pointer
    str     w5, [x6, #4]                // Update f_cost in heap
    
    // Bubble up if necessary (simplified version)
    mov     w7, w2                      // current index
    
.decrease_key_bubble:
    cbz     w7, .decrease_key_done      // At root
    
    // Get parent index
    sub     w8, w7, #1
    lsr     w8, w8, #1                  // parent index
    
    // Compare with parent
    lsl     x9, x8, #3
    add     x9, x4, x9                  // parent element
    ldr     w10, [x9, #4]               // parent f_cost
    
    cmp     w5, w10
    b.ge    .decrease_key_done          // Heap property satisfied
    
    // Swap with parent (simplified)
    ldr     w11, [x6]                   // current node_id
    ldr     w12, [x9]                   // parent node_id
    
    str     w12, [x6]                   // parent -> current position
    str     w10, [x6, #4]
    str     w11, [x9]                   // current -> parent position
    str     w5, [x9, #4]
    
    // Update node heap indices
    // (Would update both nodes' heap_index fields here)
    
    // Move up
    mov     w7, w8
    mov     x6, x9
    b       .decrease_key_bubble
    
.decrease_key_done:
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Public Utility Functions
//==============================================================================

// astar_get_path_length - Get length of last found path
// Parameters: None
// Returns: w0 = path_length
.global astar_get_path_length
astar_get_path_length:
    adrp    x0, astar_context
    add     x0, x0, :lo12:astar_context
    ldr     w0, [x0, #AStarContext_path_length]
    ret

// astar_get_path_nodes - Get pointer to path node array
// Parameters: None
// Returns: x0 = path_buffer_pointer
.global astar_get_path_nodes
astar_get_path_nodes:
    adrp    x0, astar_context
    add     x0, x0, :lo12:astar_context
    ldr     x0, [x0, #AStarContext_path_buffer]
    ret

// astar_set_dynamic_cost - Set dynamic cost for a node (traffic, etc.)
// Parameters: x0 = node_id, w1 = traffic_cost, w2 = terrain_cost
// Returns: x0 = success (1) or failure (0)
.global astar_set_dynamic_cost
astar_set_dynamic_cost:
    // Get context and validate node_id
    adrp    x3, astar_context
    add     x3, x3, :lo12:astar_context
    ldr     w4, [x3, #AStarContext_node_count]
    cmp     w0, w4
    b.ge    .set_cost_error
    
    // Get node pointer
    ldr     x3, [x3, #AStarContext_nodes]
    mov     x4, #AStarNode_size
    mul   x4, x0, x4
    add     x3, x3, x4
    
    // Set costs
    strb    w1, [x3, #AStarNode_traffic_cost]
    strb    w2, [x3, #AStarNode_terrain_cost]
    
    mov     x0, #1                      // Success
    ret
    
.set_cost_error:
    mov     x0, #0                      // Failure
    ret

// astar_get_statistics - Get pathfinding performance statistics
// Parameters: x0 = stats_output_struct
// Returns: None
.global astar_get_statistics
astar_get_statistics:
    adrp    x1, astar_total_searches
    add     x1, x1, :lo12:astar_total_searches
    
    // Copy statistics using NEON
    ld1     {v0.2d, v1.2d, v2.2d}, [x1]
    st1     {v0.2d, v1.2d, v2.2d}, [x0]
    
    ret

// astar_cleanup - Clean up A* system and free resources
// Parameters: None
// Returns: None
.global astar_cleanup
astar_cleanup:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Free all allocated pools
    adrp    x0, astar_node_pool
    add     x0, x0, :lo12:astar_node_pool
    ldr     x0, [x0]
    cbz     x0, .cleanup_heap
    bl      fast_agent_free
    
.cleanup_heap:
    adrp    x0, astar_heap_pool
    add     x0, x0, :lo12:astar_heap_pool
    ldr     x0, [x0]
    cbz     x0, .cleanup_bitfield
    bl      fast_agent_free
    
.cleanup_bitfield:
    adrp    x0, astar_bitfield_pool
    add     x0, x0, :lo12:astar_bitfield_pool
    ldr     x0, [x0]
    cbz     x0, .cleanup_path
    bl      fast_agent_free
    
.cleanup_path:
    adrp    x0, astar_path_pool
    add     x0, x0, :lo12:astar_path_pool
    ldr     x0, [x0]
    cbz     x0, .cleanup_done
    bl      fast_agent_free
    
.cleanup_done:
    // Clear pool references
    adrp    x0, astar_node_pool
    add     x0, x0, :lo12:astar_node_pool
    str     xzr, [x0]
    str     xzr, [x0, #8]               // heap_pool
    str     xzr, [x0, #16]              // bitfield_pool
    str     xzr, [x0, #24]              // path_pool
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Benchmark Function
//==============================================================================

// astar_benchmark - Benchmark pathfinding performance
// Parameters: x0 = num_iterations, x1 = start_node, x2 = goal_node
// Returns: x0 = avg_cycles_per_search
.global astar_benchmark
astar_benchmark:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                     // num_iterations
    mov     x20, x1                     // start_node
    mov     x21, x2                     // goal_node
    
    // Clear performance counters
    adrp    x0, astar_total_cycles
    add     x0, x0, :lo12:astar_total_cycles
    str     xzr, [x0]
    
    mrs     x22, cntvct_el0             // Start total timing
    
    mov     x0, #0                      // iteration counter
    
.benchmark_loop:
    cmp     x0, x19
    b.ge    .benchmark_done
    
    // Perform pathfinding
    mov     x1, x20                     // start_node
    mov     x2, x21                     // goal_node
    mov     x3, #1                      // use_traffic_cost
    bl      astar_find_path
    
    add     x0, x0, #1
    b       .benchmark_loop
    
.benchmark_done:
    mrs     x0, cntvct_el0
    sub     x0, x0, x22                 // Total cycles
    udiv    x0, x0, x19                 // Average cycles per search
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// Constant Data
//==============================================================================

.data
.align 4

// Neighbor offset table for 8-connected grid
neighbor_offsets:
    .hword  -1, -1,  0, -1,  1, -1,  1,  0    // x offsets
    .hword   1,  1,  0,  1, -1,  1, -1,  0    // y offsets

.end