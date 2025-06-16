// SimCity ARM64 Entity Component System - Pure Assembly Implementation
// Agent A5: Simulation Team - Entity/Agent Management System
// High-performance ECS targeting 1M+ entities at 60 FPS

.cpu generic+simd
.arch armv8-a+simd

// Include simulation constants and platform definitions
.include "simulation_constants.s"

.section .data
.align 6

//==============================================================================
// ECS World State - Cache-aligned for optimal performance
//==============================================================================

// Main ECS world structure (256 bytes, cache-aligned)
.ecs_world:
    // Entity management
    .entity_count:              .quad   0           // Current active entities
    .entity_capacity:           .quad   1048576     // Maximum entities (1M)
    .entity_generation:         .quad   1           // Generation counter for reuse
    .entity_free_list:          .quad   0           // Head of free entity list
    
    // Archetype management
    .archetype_count:           .quad   0           // Number of active archetypes
    .archetype_capacity:        .quad   256         // Maximum archetypes
    .archetype_array:           .quad   0           // Pointer to archetype array
    .archetype_lookup:          .quad   0           // Hash table for archetype lookup
    
    // Component storage
    .component_arrays:          .space  128         // Pointers to component arrays (16 types * 8 bytes)
    .component_counts:          .space  64          // Component counts (16 types * 4 bytes)
    .component_masks:           .quad   0           // Bitmask for active component types
    
    // System management
    .system_count:              .quad   0           // Number of registered systems
    .system_array:              .quad   0           // Pointer to system array
    .update_queue:              .quad   0           // System update queue
    
    // Performance metrics
    .frame_entities:            .quad   0           // Entities processed this frame
    .total_updates:             .quad   0           // Total system updates
    .avg_update_time:           .quad   0           // Average update time (ns)
    
    .padding:                   .space  32          // Cache alignment padding

// Entity storage - optimized for cache locality
.entity_array:              .space  0               // Will be dynamically allocated

// Component type registry
.component_registry:
    // Position components (32 bytes each)
    .position_array:            .quad   0           // Pointer to position data
    .position_count:            .word   0           // Active position components
    .position_capacity:         .word   0           // Maximum position components
    .position_stride:           .word   32          // Stride between positions
    .position_padding:          .word   0           // Alignment padding
    
    // Building components (64 bytes each)
    .building_array:            .quad   0
    .building_count:            .word   0
    .building_capacity:         .word   0
    .building_stride:           .word   64
    .building_padding:          .word   0
    
    // Economic components (64 bytes each)
    .economic_array:            .quad   0
    .economic_count:            .word   0
    .economic_capacity:         .word   0
    .economic_stride:           .word   64
    .economic_padding:          .word   0
    
    // Population components (64 bytes each)
    .population_array:          .quad   0
    .population_count:          .word   0
    .population_capacity:       .word   0
    .population_stride:         .word   64
    .population_padding:        .word   0
    
    // Add space for 12 more component types (expandable)
    .space (12 * 24)            // 12 components * 24 bytes per registry entry

// Archetype storage for entity organization
.archetype_storage:         .space  0               // Will be dynamically allocated

// System update queues
.system_queues:
    .active_entities:           .quad   0           // Entities to process this frame
    .dirty_entities:            .quad   0           // Entities needing updates
    .cleanup_entities:          .quad   0           // Entities to remove
    .spawn_queue:               .quad   0           // New entities to create

//==============================================================================
// Performance optimization structures
//==============================================================================

// NEON processing batches (16 entities at a time)
.neon_batch_buffer:         .space  (16 * 128)     // Buffer for NEON batch operations
.batch_indices:             .space  (16 * 4)       // Entity indices for current batch
.batch_masks:               .space  (16 * 8)       // Component masks for batch

// Cache-friendly iteration state
.iteration_state:
    .current_archetype:         .word   0           // Current archetype being processed
    .current_entity:            .word   0           // Current entity in archetype
    .batch_size:                .word   16          // NEON batch size
    .prefetch_distance:         .word   2           // Cache prefetch distance

.section .text
.align 4

//==============================================================================
// ECS World Initialization
//==============================================================================

// entity_system_init - Initialize the Entity Component System
// Returns: x0 = 0 on success, error code on failure
.global entity_system_init
entity_system_init:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    // Initialize ECS world structure
    adrp    x19, .ecs_world
    add     x19, x19, :lo12:.ecs_world
    
    // Clear the world structure
    mov     x0, x19
    mov     x1, #256                        // Size of ECS world structure
    bl      memset
    
    // Set initial capacities
    mov     x0, #1048576                    // 1M entities
    str     x0, [x19, #8]                   // entity_capacity
    mov     x0, #1
    str     x0, [x19, #16]                  // entity_generation
    mov     x0, #256
    str     x0, [x19, #32]                  // archetype_capacity
    
    // Allocate entity array (64 bytes per entity)
    mov     x0, #1048576                    // Max entities
    mov     x1, #64                         // Entity size
    mul     x0, x0, x1                      // Total size needed
    bl      aligned_alloc_cache             // Cache-aligned allocation
    cbz     x0, init_failed
    
    adrp    x20, .entity_array
    add     x20, x20, :lo12:.entity_array
    str     x0, [x20]                       // Store entity array pointer
    
    // Allocate archetype array (512 bytes per archetype)
    mov     x0, #256                        // Max archetypes
    mov     x1, #512                        // Archetype size
    mul     x0, x0, x1
    bl      aligned_alloc_cache
    cbz     x0, init_failed
    str     x0, [x19, #40]                  // archetype_array
    
    // Allocate archetype lookup hash table
    mov     x0, #1024                       // Hash table size
    mov     x1, #8                          // Pointer size
    mul     x0, x0, x1
    bl      aligned_alloc_cache
    cbz     x0, init_failed
    str     x0, [x19, #48]                  // archetype_lookup
    
    // Initialize component arrays
    bl      init_component_storage
    cmp     x0, #0
    b.ne    init_failed
    
    // Initialize entity free list
    bl      init_entity_free_list
    cmp     x0, #0
    b.ne    init_failed
    
    // Initialize archetype system
    bl      init_archetype_system
    cmp     x0, #0
    b.ne    init_failed
    
    // Initialize system registry
    bl      init_system_registry
    cmp     x0, #0
    b.ne    init_failed
    
    // Initialize performance tracking
    bl      init_performance_tracking
    
    mov     x0, #0                          // Success
    b       init_done
    
init_failed:
    mov     x0, #-1                         // Error
    
init_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// Entity Lifecycle Management
//==============================================================================

// create_entity - Create a new entity with specified components
// Parameters:
//   x0 = component_mask (bitmask of components to add)
// Returns:
//   x0 = entity_id (0 = failed)
.global create_entity
create_entity:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                         // Save component mask
    
    // Get entity from free list or allocate new
    bl      allocate_entity_id
    cbz     x0, create_entity_failed
    mov     x20, x0                         // Save entity ID
    
    // Find or create archetype for this component combination
    mov     x0, x19                         // component_mask
    bl      find_or_create_archetype
    cbz     x0, create_entity_failed
    mov     x21, x0                         // Save archetype pointer
    
    // Add entity to archetype
    mov     x0, x21                         // archetype
    mov     x1, x20                         // entity_id
    bl      add_entity_to_archetype
    cmp     x0, #0
    b.ne    create_entity_failed
    
    // Initialize components with default values
    mov     x0, x20                         // entity_id
    mov     x1, x19                         // component_mask
    bl      initialize_entity_components
    
    // Update entity count
    adrp    x0, .ecs_world
    add     x0, x0, :lo12:.ecs_world
    ldr     x1, [x0]                        // current entity_count
    add     x1, x1, #1
    str     x1, [x0]                        // Update count
    
    mov     x0, x20                         // Return entity ID
    b       create_entity_done
    
create_entity_failed:
    mov     x0, #0                          // Failed
    
create_entity_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// destroy_entity - Remove an entity and clean up its components
// Parameters:
//   x0 = entity_id
// Returns:
//   x0 = 0 on success, error code on failure
.global destroy_entity
destroy_entity:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                         // Save entity ID
    
    // Validate entity ID
    bl      validate_entity_id
    cmp     x0, #0
    b.ne    destroy_failed
    
    // Find archetype containing this entity
    mov     x0, x19                         // entity_id
    bl      find_entity_archetype
    cbz     x0, destroy_failed
    mov     x20, x0                         // Save archetype
    
    // Remove entity from archetype
    mov     x0, x20                         // archetype
    mov     x1, x19                         // entity_id
    bl      remove_entity_from_archetype
    
    // Cleanup component data
    mov     x0, x19                         // entity_id
    bl      cleanup_entity_components
    
    // Return entity ID to free list
    mov     x0, x19                         // entity_id
    bl      return_entity_to_free_list
    
    // Update entity count
    adrp    x0, .ecs_world
    add     x0, x0, :lo12:.ecs_world
    ldr     x1, [x0]                        // current entity_count
    sub     x1, x1, #1
    str     x1, [x0]                        // Update count
    
    mov     x0, #0                          // Success
    b       destroy_done
    
destroy_failed:
    mov     x0, #-1                         // Error
    
destroy_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// Component Management
//==============================================================================

// add_component - Add a component to an existing entity
// Parameters:
//   x0 = entity_id
//   x1 = component_type
//   x2 = component_data_ptr (optional)
// Returns:
//   x0 = 0 on success, error code on failure
.global add_component
add_component:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    mov     x19, x0                         // Save entity_id
    mov     x20, x1                         // Save component_type
    mov     x21, x2                         // Save component_data_ptr
    
    // Validate inputs
    bl      validate_entity_id
    cmp     x0, #0
    b.ne    add_component_failed
    
    cmp     x20, #16                        // Check component type range
    b.ge    add_component_failed
    
    // Get current archetype
    mov     x0, x19                         // entity_id
    bl      find_entity_archetype
    cbz     x0, add_component_failed
    mov     x22, x0                         // Save current archetype
    
    // Get current component mask
    ldr     x0, [x22, #8]                   // Load component_mask from archetype
    mov     x1, #1
    lsl     x1, x1, x20                     // Create bit for new component
    tst     x0, x1                          // Check if component already exists
    b.ne    add_component_failed            // Already has this component
    
    orr     x23, x0, x1                     // New component mask
    
    // Find or create new archetype
    mov     x0, x23                         // new_component_mask
    bl      find_or_create_archetype
    cbz     x0, add_component_failed
    mov     x24, x0                         // Save new archetype
    
    // Move entity to new archetype
    mov     x0, x19                         // entity_id
    mov     x1, x22                         // old_archetype
    mov     x2, x24                         // new_archetype
    mov     x3, x20                         // component_type being added
    mov     x4, x21                         // component_data_ptr
    bl      migrate_entity_archetype
    
    mov     x0, #0                          // Success
    b       add_component_done
    
add_component_failed:
    mov     x0, #-1                         // Error
    
add_component_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// remove_component - Remove a component from an entity
// Parameters:
//   x0 = entity_id
//   x1 = component_type
// Returns:
//   x0 = 0 on success, error code on failure
.global remove_component
remove_component:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    mov     x19, x0                         // Save entity_id
    mov     x20, x1                         // Save component_type
    
    // Validate inputs
    bl      validate_entity_id
    cmp     x0, #0
    b.ne    remove_component_failed
    
    // Get current archetype
    mov     x0, x19                         // entity_id
    bl      find_entity_archetype
    cbz     x0, remove_component_failed
    mov     x21, x0                         // Save current archetype
    
    // Get current component mask
    ldr     x0, [x21, #8]                   // Load component_mask from archetype
    mov     x1, #1
    lsl     x1, x1, x20                     // Create bit for component to remove
    tst     x0, x1                          // Check if component exists
    b.eq    remove_component_failed         // Doesn't have this component
    
    bic     x22, x0, x1                     // Remove component bit
    
    // Find archetype for new component combination
    mov     x0, x22                         // new_component_mask
    bl      find_or_create_archetype
    cbz     x0, remove_component_failed
    mov     x23, x0                         // Save new archetype
    
    // Move entity to new archetype
    mov     x0, x19                         // entity_id
    mov     x1, x21                         // old_archetype
    mov     x2, x23                         // new_archetype
    mov     x3, x20                         // component_type being removed
    mov     x4, #0                          // No new component data
    bl      migrate_entity_archetype
    
    mov     x0, #0                          // Success
    b       remove_component_done
    
remove_component_failed:
    mov     x0, #-1                         // Error
    
remove_component_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// get_component - Get pointer to entity's component data
// Parameters:
//   x0 = entity_id
//   x1 = component_type
// Returns:
//   x0 = component_data_ptr (NULL if not found)
.global get_component
get_component:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                         // Save entity_id
    mov     x20, x1                         // Save component_type
    
    // Validate entity ID
    bl      validate_entity_id
    cmp     x0, #0
    b.ne    get_component_failed
    
    // Find entity's archetype
    mov     x0, x19                         // entity_id
    bl      find_entity_archetype
    cbz     x0, get_component_failed
    mov     x21, x0                         // Save archetype
    
    // Check if archetype has this component type
    ldr     x0, [x21, #8]                   // Load component_mask
    mov     x1, #1
    lsl     x1, x1, x20                     // Create component bit
    tst     x0, x1                          // Test if component exists
    b.eq    get_component_failed
    
    // Calculate component data pointer
    mov     x0, x21                         // archetype
    mov     x1, x19                         // entity_id
    mov     x2, x20                         // component_type
    bl      get_component_data_pointer
    
    // x0 already contains the result
    b       get_component_done
    
get_component_failed:
    mov     x0, #0                          // NULL pointer
    
get_component_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// System Update and Iteration
//==============================================================================

// entity_system_update - Update all entities and systems
// Parameters:
//   d0 = delta_time (float)
// Returns:
//   none
.global entity_system_update
entity_system_update:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    fmov    s19, s0                         // Save delta_time
    
    // Start performance timing
    mrs     x20, cntvct_el0                 // Start cycle counter
    
    // Process all archetypes with NEON optimization
    bl      update_all_archetypes_neon
    
    // Run registered systems
    fmov    s0, s19                         // Restore delta_time
    bl      update_all_systems
    
    // Process entity lifecycle events
    bl      process_entity_lifecycle
    
    // Update performance metrics
    mrs     x0, cntvct_el0                  // End cycle counter
    sub     x0, x0, x20                     // Calculate duration
    bl      update_performance_metrics
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// update_all_archetypes_neon - Update entities using NEON bulk processing
// Uses SIMD instructions to process 16 entities simultaneously
update_all_archetypes_neon:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    // Get ECS world
    adrp    x19, .ecs_world
    add     x19, x19, :lo12:.ecs_world
    
    // Get archetype array and count
    ldr     x20, [x19, #40]                 // archetype_array
    ldr     x21, [x19, #24]                 // archetype_count
    
    mov     x22, #0                         // archetype_index
    
archetype_loop:
    cmp     x22, x21
    b.ge    archetype_loop_done
    
    // Calculate archetype pointer
    mov     x0, #512                        // archetype size
    mul     x1, x22, x0
    add     x23, x20, x1                    // current archetype
    
    // Check if archetype has entities
    ldr     w0, [x23, #16]                  // entity_count
    cbz     w0, next_archetype
    
    // Process archetype entities in NEON batches
    mov     x0, x23                         // archetype
    bl      process_archetype_neon_batches
    
next_archetype:
    add     x22, x22, #1
    b       archetype_loop
    
archetype_loop_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// process_archetype_neon_batches - Process entities in an archetype using NEON
// Parameters:
//   x0 = archetype_pointer
process_archetype_neon_batches:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                         // Save archetype
    ldr     w20, [x19, #16]                 // entity_count
    
    // Process entities in batches of 16 (NEON vector size)
    mov     w21, #0                         // entity_index
    
neon_batch_loop:
    cmp     w21, w20
    b.ge    neon_batch_done
    
    // Calculate batch size (min(16, remaining_entities))
    sub     w0, w20, w21                    // remaining entities
    cmp     w0, #16
    csel    w22, w0, #16, lt               // batch_size = min(remaining, 16)
    
    // Load entity batch into NEON registers
    mov     x0, x19                         // archetype
    mov     w1, w21                         // start_index
    mov     w2, w22                         // batch_size
    bl      load_entity_batch_neon
    
    // Process position components if present
    ldr     x0, [x19, #8]                   // component_mask
    tst     x0, #(1 << COMPONENT_POSITION)
    b.eq    skip_position_update
    
    bl      update_position_components_neon
    
skip_position_update:
    // Process other components with NEON as needed
    // Add more component-specific NEON processing here
    
    // Store updated batch back to memory
    mov     x0, x19                         // archetype
    mov     w1, w21                         // start_index
    mov     w2, w22                         // batch_size
    bl      store_entity_batch_neon
    
    add     w21, w21, w22                   // Next batch
    b       neon_batch_loop
    
neon_batch_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// NEON Optimization Functions
//==============================================================================

// load_entity_batch_neon - Load entity data into NEON registers
// Parameters:
//   x0 = archetype
//   w1 = start_index
//   w2 = batch_size
load_entity_batch_neon:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get component data pointers
    ldr     x3, [x0, #32]                   // position_array
    cbz     x3, no_position_data
    
    // Load position data for batch (16 entities * 32 bytes = 512 bytes)
    mov     x4, #32                         // position stride
    mul     x5, x1, x4                      // start offset
    add     x3, x3, x5                      // position data start
    
    // Load positions using NEON (4 positions per load, 4 loads total)
    ld4     {v0.4s, v1.4s, v2.4s, v3.4s}, [x3], #64    // Load first 4 positions
    ld4     {v4.4s, v5.4s, v6.4s, v7.4s}, [x3], #64    // Load next 4 positions
    ld4     {v8.4s, v9.4s, v10.4s, v11.4s}, [x3], #64   // Load next 4 positions
    ld4     {v12.4s, v13.4s, v14.4s, v15.4s}, [x3]      // Load last 4 positions
    
no_position_data:
    ldp     x29, x30, [sp], #16
    ret

// update_position_components_neon - Update position components using NEON
update_position_components_neon:
    // Simulate movement - add small delta to all positions
    // In a real implementation, this would read velocity components
    // and integrate physics
    
    movi    v31.4s, #0x3f800000             // Load 1.0f into v31
    
    // Update X coordinates
    fadd    v0.4s, v0.4s, v31.4s
    fadd    v4.4s, v4.4s, v31.4s
    fadd    v8.4s, v8.4s, v31.4s
    fadd    v12.4s, v12.4s, v31.4s
    
    // Update Y coordinates (could add different deltas)
    fadd    v1.4s, v1.4s, v31.4s
    fadd    v5.4s, v5.4s, v31.4s
    fadd    v9.4s, v9.4s, v31.4s
    fadd    v13.4s, v13.4s, v31.4s
    
    ret

// store_entity_batch_neon - Store NEON register data back to entity components
// Parameters:
//   x0 = archetype
//   w1 = start_index  
//   w2 = batch_size
store_entity_batch_neon:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get position data pointer
    ldr     x3, [x0, #32]                   // position_array
    cbz     x3, no_position_store
    
    mov     x4, #32                         // position stride
    mul     x5, x1, x4                      // start offset
    add     x3, x3, x5                      // position data start
    
    // Store updated positions using NEON
    st4     {v0.4s, v1.4s, v2.4s, v3.4s}, [x3], #64
    st4     {v4.4s, v5.4s, v6.4s, v7.4s}, [x3], #64
    st4     {v8.4s, v9.4s, v10.4s, v11.4s}, [x3], #64
    st4     {v12.4s, v13.4s, v14.4s, v15.4s}, [x3]
    
no_position_store:
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// Archetype Management
//==============================================================================

// find_or_create_archetype - Find existing archetype or create new one
// Parameters:
//   x0 = component_mask
// Returns:
//   x0 = archetype_pointer (NULL on failure)
find_or_create_archetype:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                         // Save component_mask
    
    // First try to find existing archetype
    mov     x0, x19                         // component_mask
    bl      find_archetype_by_mask
    cbnz    x0, archetype_found             // Found existing archetype
    
    // Create new archetype
    mov     x0, x19                         // component_mask
    bl      create_new_archetype
    
archetype_found:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// create_new_archetype - Create a new archetype for component combination
// Parameters:
//   x0 = component_mask
// Returns:
//   x0 = archetype_pointer (NULL on failure)
create_new_archetype:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    mov     x19, x0                         // Save component_mask
    
    // Get ECS world
    adrp    x20, .ecs_world
    add     x20, x20, :lo12:.ecs_world
    
    // Check if we have space for new archetype
    ldr     x0, [x20, #24]                  // archetype_count
    ldr     x1, [x20, #32]                  // archetype_capacity
    cmp     x0, x1
    b.ge    create_archetype_failed
    
    // Get archetype array
    ldr     x21, [x20, #40]                 // archetype_array
    
    // Calculate new archetype pointer
    mov     x1, #512                        // archetype size
    mul     x2, x0, x1
    add     x22, x21, x2                    // new archetype pointer
    
    // Initialize archetype structure
    str     x19, [x22, #8]                  // component_mask
    str     wzr, [x22, #16]                 // entity_count = 0
    mov     w0, #1024                       // Initial capacity
    str     w0, [x22, #20]                  // entity_capacity
    
    // Allocate component arrays for this archetype
    mov     x0, x22                         // archetype
    mov     x1, x19                         // component_mask
    bl      allocate_archetype_component_arrays
    cmp     x0, #0
    b.ne    create_archetype_failed
    
    // Increment archetype count
    ldr     x0, [x20, #24]                  // archetype_count
    add     x0, x0, #1
    str     x0, [x20, #24]                  // Update count
    
    mov     x0, x22                         // Return archetype pointer
    b       create_archetype_done
    
create_archetype_failed:
    mov     x0, #0                          // NULL pointer
    
create_archetype_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//==============================================================================
// Entity Management Helper Functions
//==============================================================================

// allocate_entity_id - Get next available entity ID
// Returns:
//   x0 = entity_id (0 if failed)
allocate_entity_id:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x1, .ecs_world
    add     x1, x1, :lo12:.ecs_world
    
    // Check free list first
    ldr     x0, [x1, #24]                   // entity_free_list
    cbnz    x0, use_free_entity
    
    // No free entities, allocate new one
    ldr     x0, [x1]                        // entity_count
    ldr     x2, [x1, #8]                    // entity_capacity
    cmp     x0, x2
    b.ge    allocation_failed
    
    add     x0, x0, #1                      // Next entity ID
    // Return entity ID (current count + 1)
    b       allocation_done
    
use_free_entity:
    // Pop from free list (simplified - in real implementation would be more complex)
    str     xzr, [x1, #24]                  // Clear free list head for now
    
allocation_done:
    ldp     x29, x30, [sp], #16
    ret
    
allocation_failed:
    mov     x0, #0                          // Failed
    ldp     x29, x30, [sp], #16
    ret

// validate_entity_id - Check if entity ID is valid
// Parameters:
//   x0 = entity_id
// Returns:
//   x0 = 0 if valid, error code if invalid
validate_entity_id:
    cbz     x0, invalid_entity              // Entity ID 0 is invalid
    
    adrp    x1, .ecs_world
    add     x1, x1, :lo12:.ecs_world
    ldr     x2, [x1, #8]                    // entity_capacity
    cmp     x0, x2
    b.gt    invalid_entity
    
    mov     x0, #0                          // Valid
    ret
    
invalid_entity:
    mov     x0, #-1                         // Invalid
    ret

//==============================================================================
// Initialization Helper Functions
//==============================================================================

// init_component_storage - Initialize component storage arrays
init_component_storage:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    adrp    x19, .component_registry
    add     x19, x19, :lo12:.component_registry
    
    // Initialize position component array
    mov     x0, #1048576                    // Max entities
    mov     x1, #32                         // Position component size
    mul     x0, x0, x1                      // Total size
    bl      aligned_alloc_cache
    str     x0, [x19]                       // position_array
    
    mov     w0, #1048576
    str     w0, [x19, #12]                  // position_capacity
    
    // Repeat for other component types (abbreviated for space)
    // In full implementation, would initialize all 16 component types
    
    mov     x0, #0                          // Success
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// init_entity_free_list - Initialize entity free list
init_entity_free_list:
    // For now, just clear the free list head
    adrp    x0, .ecs_world
    add     x0, x0, :lo12:.ecs_world
    str     xzr, [x0, #24]                  // entity_free_list = NULL
    mov     x0, #0                          // Success
    ret

// init_archetype_system - Initialize archetype management
init_archetype_system:
    mov     x0, #0                          // Success (placeholder)
    ret

// init_system_registry - Initialize system registry
init_system_registry:
    mov     x0, #0                          // Success (placeholder)
    ret

// init_performance_tracking - Initialize performance monitoring
init_performance_tracking:
    ret

//==============================================================================
// Utility Functions
//==============================================================================

// aligned_alloc_cache - Allocate cache-aligned memory
// Parameters:
//   x0 = size
// Returns:
//   x0 = pointer (NULL on failure)
aligned_alloc_cache:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    add     x0, x0, #63                     // Add cache line size - 1
    mov     x1, #64                         // Cache line alignment
    bl      posix_memalign
    cmp     x0, #0
    csel    x0, x1, xzr, eq                // Return pointer or NULL
    
    ldp     x29, x30, [sp], #16
    ret

// Placeholder implementations for complex functions
// These would be fully implemented in a complete system

find_archetype_by_mask:
    mov     x0, #0                          // Placeholder: not found
    ret

find_entity_archetype:
    mov     x0, #0                          // Placeholder
    ret

add_entity_to_archetype:
    mov     x0, #0                          // Placeholder: success
    ret

remove_entity_from_archetype:
    ret

initialize_entity_components:
    ret

cleanup_entity_components:
    ret

return_entity_to_free_list:
    ret

migrate_entity_archetype:
    ret

get_component_data_pointer:
    mov     x0, #0                          // Placeholder
    ret

allocate_archetype_component_arrays:
    mov     x0, #0                          // Placeholder: success
    ret

update_all_systems:
    ret

process_entity_lifecycle:
    ret

update_performance_metrics:
    ret

//==============================================================================
// Entity System Shutdown
//==============================================================================

// entity_system_shutdown - Clean up ECS resources
.global entity_system_shutdown
entity_system_shutdown:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Free allocated memory (simplified)
    // In full implementation would free all component arrays,
    // archetype arrays, entity arrays, etc.
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// External Function References
//==============================================================================

.extern memset
.extern posix_memalign
.extern tlsf_alloc
.extern tlsf_free

.end