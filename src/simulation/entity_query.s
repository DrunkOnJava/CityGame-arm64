// SimCity ARM64 Entity Query System
// Agent A5: Simulation Team - Component Query and Filtering Implementation
// High-performance entity queries with NEON optimization

.cpu generic+simd
.arch armv8-a+simd

// Include simulation constants
.include "simulation_constants.s"

.section .data
.align 6

//==============================================================================
// Query System State
//==============================================================================

// Query builder state
.query_builder:
    .include_mask:          .quad   0           // Components that must be present
    .exclude_mask:          .quad   0           // Components that must NOT be present
    .optional_mask:         .quad   0           // Components that may be present
    .result_capacity:       .quad   1000        // Maximum results to return
    .result_count:          .quad   0           // Actual results returned
    .result_buffer:         .quad   0           // Pointer to result buffer
    .padding:               .space  16          // Cache alignment

// Query result cache for performance
.query_cache:
    .cached_queries:        .space  (10 * 64)  // Cache for 10 recent queries
    .cache_hits:            .quad   0           // Cache hit count
    .cache_misses:          .quad   0           // Cache miss count
    .cache_index:           .word   0           // Current cache index
    .cache_valid:           .word   0           // Cache validity flags

// Iteration state for query results
.query_iterator:
    .current_archetype:     .word   0           // Current archetype index
    .current_entity:        .word   0           // Current entity in archetype
    .entities_processed:    .word   0           // Total entities processed
    .total_matches:         .word   0           // Total matching entities

.section .text
.align 4

//==============================================================================
// Query Builder Interface
//==============================================================================

// query_builder_create - Create a new query builder
// Returns: x0 = query_builder_handle (always returns global builder for now)
.global query_builder_create
query_builder_create:
    // Clear query builder state
    adrp    x0, .query_builder
    add     x0, x0, :lo12:.query_builder
    
    // Clear masks
    str     xzr, [x0]                       // include_mask
    str     xzr, [x0, #8]                   // exclude_mask
    str     xzr, [x0, #16]                  // optional_mask
    str     xzr, [x0, #32]                  // result_count
    
    ret

// query_with_component - Add a required component to query
// Parameters:
//   x0 = query_builder_handle
//   x1 = component_type
// Returns: x0 = query_builder_handle (for chaining)
.global query_with_component
query_with_component:
    cmp     x1, #16                         // Validate component type
    b.ge    invalid_component_type
    
    // Add component to include mask
    ldr     x2, [x0]                        // Current include_mask
    mov     x3, #1
    lsl     x3, x3, x1                      // Create component bit
    orr     x2, x2, x3                      // Add to include mask
    str     x2, [x0]                        // Store updated mask
    
invalid_component_type:
    ret

// query_without_component - Exclude a component from query
// Parameters:
//   x0 = query_builder_handle
//   x1 = component_type
// Returns: x0 = query_builder_handle (for chaining)
.global query_without_component
query_without_component:
    cmp     x1, #16                         // Validate component type
    b.ge    invalid_exclude_component
    
    // Add component to exclude mask
    ldr     x2, [x0, #8]                    // Current exclude_mask
    mov     x3, #1
    lsl     x3, x3, x1                      // Create component bit
    orr     x2, x2, x3                      // Add to exclude mask
    str     x2, [x0, #8]                    // Store updated mask
    
invalid_exclude_component:
    ret

// query_maybe_component - Add optional component to query
// Parameters:
//   x0 = query_builder_handle
//   x1 = component_type
// Returns: x0 = query_builder_handle (for chaining)
.global query_maybe_component
query_maybe_component:
    cmp     x1, #16                         // Validate component type
    b.ge    invalid_optional_component
    
    // Add component to optional mask
    ldr     x2, [x0, #16]                   // Current optional_mask
    mov     x3, #1
    lsl     x3, x3, x1                      // Create component bit
    orr     x2, x2, x3                      // Add to optional mask
    str     x2, [x0, #16]                   // Store updated mask
    
invalid_optional_component:
    ret

//==============================================================================
// Query Execution
//==============================================================================

// execute_query - Execute the built query and return matching entities
// Parameters:
//   x0 = query_builder_handle
//   x1 = result_buffer (array of entity IDs)
//   x2 = max_results
// Returns: x0 = number of matching entities found
.global execute_query
execute_query:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    mov     x19, x0                         // Save query builder
    mov     x20, x1                         // Save result buffer
    mov     x21, x2                         // Save max results
    
    // Store result buffer info in query builder
    str     x20, [x19, #40]                 // result_buffer
    str     x21, [x19, #24]                 // result_capacity
    str     xzr, [x19, #32]                 // result_count = 0
    
    // Check query cache first
    bl      check_query_cache
    cbnz    x0, query_cache_hit
    
    // Cache miss - execute query
    bl      execute_query_full_scan
    
    // Cache the results
    bl      cache_query_results
    
    b       query_execution_done
    
query_cache_hit:
    // Use cached results
    bl      use_cached_query_results
    
query_execution_done:
    // Return result count
    ldr     x0, [x19, #32]                  // result_count
    
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// execute_query_full_scan - Perform full archetype scan for query
execute_query_full_scan:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    // Get ECS world
    adrp    x19, .ecs_world
    add     x19, x19, :lo12:.ecs_world
    
    // Get archetype array and count
    ldr     x20, [x19, #40]                 // archetype_array
    ldr     x21, [x19, #24]                 // archetype_count
    
    mov     x22, #0                         // archetype_index
    
scan_archetypes_loop:
    cmp     x22, x21
    b.ge    scan_archetypes_done
    
    // Calculate archetype pointer
    mov     x0, #512                        // archetype size
    mul     x1, x22, x0
    add     x23, x20, x1                    // current archetype
    
    // Check if archetype matches query
    adrp    x0, .query_builder
    add     x0, x0, :lo12:.query_builder
    mov     x1, x23                         // archetype
    bl      archetype_matches_query
    cbz     x0, next_scan_archetype
    
    // Archetype matches - collect entities
    mov     x0, x23                         // archetype
    bl      collect_entities_from_archetype
    
next_scan_archetype:
    add     x22, x22, #1
    b       scan_archetypes_loop
    
scan_archetypes_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Archetype Matching
//==============================================================================

// archetype_matches_query - Check if archetype matches query criteria
// Parameters:
//   x0 = query_builder
//   x1 = archetype
// Returns: x0 = 1 if matches, 0 if not
archetype_matches_query:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Load archetype component mask
    ldr     x2, [x1, #8]                    // archetype component_mask
    
    // Load query masks
    ldr     x3, [x0]                        // include_mask
    ldr     x4, [x0, #8]                    // exclude_mask
    
    // Check include mask - archetype must have ALL required components
    and     x5, x2, x3                      // Components archetype has from required
    cmp     x5, x3                          // Does archetype have all required?
    b.ne    archetype_no_match
    
    // Check exclude mask - archetype must have NONE of excluded components
    and     x5, x2, x4                      // Components archetype has from excluded
    cbnz    x5, archetype_no_match          // If any excluded components present, no match
    
    mov     x0, #1                          // Match
    b       archetype_match_done
    
archetype_no_match:
    mov     x0, #0                          // No match
    
archetype_match_done:
    ldp     x29, x30, [sp], #16
    ret

// collect_entities_from_archetype - Collect all entities from matching archetype
// Parameters:
//   x0 = archetype
collect_entities_from_archetype:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                         // Save archetype
    
    // Get entity count in archetype
    ldr     w20, [x19, #16]                 // entity_count
    cbz     w20, collect_entities_done
    
    // Get query builder
    adrp    x21, .query_builder
    add     x21, x21, :lo12:.query_builder
    
    // Get current result count and capacity
    ldr     x22, [x21, #32]                 // current result_count
    ldr     x23, [x21, #24]                 // result_capacity
    
    // Check if we have space for more results
    cmp     x22, x23
    b.ge    collect_entities_done
    
    // Get result buffer
    ldr     x24, [x21, #40]                 // result_buffer
    
    // Get entity array from archetype (simplified - would need proper implementation)
    ldr     x25, [x19, #24]                 // entity_array pointer
    
    // Copy entities to result buffer
    mov     w26, #0                         // entity_index
    
collect_entity_loop:
    cmp     w26, w20                        // Check if done with archetype entities
    b.ge    collect_entities_done
    cmp     x22, x23                        // Check if result buffer full
    b.ge    collect_entities_done
    
    // Load entity ID (simplified)
    ldr     x0, [x25, x26, lsl #3]          // Load entity ID
    str     x0, [x24, x22, lsl #3]          // Store in result buffer
    
    add     x22, x22, #1                    // Increment result count
    add     w26, w26, #1                    // Next entity
    b       collect_entity_loop
    
collect_entities_done:
    // Update result count
    str     x22, [x21, #32]                 // Store updated result_count
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Query Caching System
//==============================================================================

// check_query_cache - Check if query results are cached
// Returns: x0 = 1 if cached, 0 if not cached
check_query_cache:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Simplified cache check - in real implementation would hash query masks
    // and check against cached queries
    
    adrp    x0, .query_cache
    add     x0, x0, :lo12:.query_cache
    
    // For now, always return cache miss
    mov     x0, #0                          // Cache miss
    
    ldp     x29, x30, [sp], #16
    ret

// cache_query_results - Cache the current query results
cache_query_results:
    // Placeholder for caching implementation
    ret

// use_cached_query_results - Use previously cached query results
use_cached_query_results:
    // Placeholder for using cached results
    ret

//==============================================================================
// Specialized Query Functions
//==============================================================================

// query_entities_with_position - Quick query for entities with position component
// Parameters:
//   x0 = result_buffer
//   x1 = max_results
// Returns: x0 = number of entities found
.global query_entities_with_position
query_entities_with_position:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Create query for position component
    bl      query_builder_create
    mov     x2, x0                          // Save query builder
    mov     x1, #COMPONENT_POSITION
    bl      query_with_component
    
    // Execute query
    mov     x0, x2                          // query_builder
    // x1 and x2 already set from parameters
    bl      execute_query
    
    ldp     x29, x30, [sp], #16
    ret

// query_entities_with_building - Quick query for entities with building component
// Parameters:
//   x0 = result_buffer
//   x1 = max_results
// Returns: x0 = number of entities found
.global query_entities_with_building
query_entities_with_building:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    bl      query_builder_create
    mov     x2, x0
    mov     x1, #COMPONENT_BUILDING
    bl      query_with_component
    
    mov     x0, x2
    bl      execute_query
    
    ldp     x29, x30, [sp], #16
    ret

// query_buildings_with_position - Query for entities with both building and position
// Parameters:
//   x0 = result_buffer
//   x1 = max_results
// Returns: x0 = number of entities found
.global query_buildings_with_position
query_buildings_with_position:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    bl      query_builder_create
    mov     x2, x0
    
    // Add position component requirement
    mov     x1, #COMPONENT_POSITION
    bl      query_with_component
    
    // Add building component requirement
    mov     x0, x2
    mov     x1, #COMPONENT_BUILDING
    bl      query_with_component
    
    // Execute query
    mov     x0, x2
    bl      execute_query
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// NEON-Optimized Query Processing
//==============================================================================

// query_execute_neon - Execute query with NEON optimization for large result sets
// Parameters:
//   x0 = query_builder
//   x1 = result_buffer
//   x2 = max_results
// Returns: x0 = number of entities found
.global query_execute_neon
query_execute_neon:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                         // Save query builder
    mov     x20, x1                         // Save result buffer
    mov     x21, x2                         // Save max results
    
    // Load query masks into NEON registers for parallel comparison
    ldr     x0, [x19]                       // include_mask
    ldr     x1, [x19, #8]                   // exclude_mask
    
    // Broadcast masks to NEON registers
    dup     v0.2d, x0                       // Include mask in v0
    dup     v1.2d, x1                       // Exclude mask in v1
    
    // Process archetypes in parallel using NEON
    bl      neon_scan_archetypes
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// neon_scan_archetypes - Scan archetypes using NEON parallel processing
neon_scan_archetypes:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get ECS world
    adrp    x0, .ecs_world
    add     x0, x0, :lo12:.ecs_world
    ldr     x1, [x0, #40]                   // archetype_array
    ldr     x2, [x0, #24]                   // archetype_count
    
    mov     x3, #0                          // archetype_index
    mov     x4, #0                          // result_count
    
neon_archetype_loop:
    cmp     x3, x2
    b.ge    neon_scan_done
    
    // Process archetypes in batches of 4 for NEON efficiency
    sub     x5, x2, x3                      // Remaining archetypes
    cmp     x5, #4
    csel    x5, x5, #4, lt                 // min(remaining, 4)
    
    // Load 4 archetype component masks
    mov     x6, #512                        // archetype size
    mul     x7, x3, x6
    add     x7, x1, x7                      // current archetype base
    
    // Load component masks using NEON (simplified)
    ldr     q2, [x7, #8]                    // Load first archetype mask
    add     x7, x7, #512
    ldr     q3, [x7, #8]                    // Load second archetype mask
    
    // Perform parallel mask comparisons
    and     v4.16b, v2.16b, v0.16b          // Check include requirements
    and     v5.16b, v3.16b, v1.16b          // Check exclude requirements
    
    // Process results (simplified)
    add     x3, x3, x5                      // Next batch
    b       neon_archetype_loop
    
neon_scan_done:
    mov     x0, x4                          // Return result count
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Query Result Iteration
//==============================================================================

// query_iterator_create - Create iterator for query results
// Parameters:
//   x0 = query_results_buffer
//   x1 = result_count
// Returns: x0 = iterator_handle
.global query_iterator_create
query_iterator_create:
    adrp    x2, .query_iterator
    add     x2, x2, :lo12:.query_iterator
    
    // Initialize iterator state
    str     x0, [x2, #16]                   // result_buffer
    str     x1, [x2, #24]                   // total_results
    str     wzr, [x2]                       // current_index = 0
    
    mov     x0, x2                          // Return iterator handle
    ret

// query_iterator_next - Get next entity from query results
// Parameters:
//   x0 = iterator_handle
// Returns: x0 = entity_id (0 if no more entities)
.global query_iterator_next
query_iterator_next:
    // Load current index and total count
    ldr     w1, [x0]                        // current_index
    ldr     x2, [x0, #24]                   // total_results
    
    // Check if we've reached the end
    cmp     x1, x2
    b.ge    iterator_end
    
    // Get result buffer and load entity ID
    ldr     x3, [x0, #16]                   // result_buffer
    ldr     x4, [x3, x1, lsl #3]            // Load entity_id
    
    // Increment index
    add     w1, w1, #1
    str     w1, [x0]                        // Update current_index
    
    mov     x0, x4                          // Return entity_id
    ret
    
iterator_end:
    mov     x0, #0                          // No more entities
    ret

//==============================================================================
// Query Performance Monitoring
//==============================================================================

// get_query_performance_stats - Get query system performance statistics
// Parameters:
//   x0 = stats_output_buffer
.global get_query_performance_stats
get_query_performance_stats:
    adrp    x1, .query_cache
    add     x1, x1, :lo12:.query_cache
    
    // Copy cache statistics
    ldr     x2, [x1, #640]                  // cache_hits
    str     x2, [x0]
    ldr     x2, [x1, #648]                  // cache_misses
    str     x2, [x0, #8]
    
    // Calculate hit rate
    ldr     x3, [x1, #640]                  // cache_hits
    ldr     x4, [x1, #648]                  // cache_misses
    add     x5, x3, x4                      // total_queries
    cbz     x5, no_hit_rate
    
    // Hit rate = (hits * 100) / total
    mov     x6, #100
    mul     x3, x3, x6
    udiv    x3, x3, x5
    str     x3, [x0, #16]                   // hit_rate_percent
    
    ret
    
no_hit_rate:
    str     xzr, [x0, #16]                  // 0% hit rate
    ret

//==============================================================================
// External References
//==============================================================================

.extern .ecs_world

.end