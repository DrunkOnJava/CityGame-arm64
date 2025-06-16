//
// SimCity ARM64 Assembly - Entity Component System Core
// Agent 2: Simulation Systems Developer
//
// Core ECS architecture providing entity management, component registry,
// and system coordination for the simulation engine
//

.include "simulation_constants.s"

.text
.align 4

// ECS Core Structures
.struct Entity
    id                  .quad       // Unique entity identifier
    generation          .word       // Generation counter for ID reuse
    active              .word       // 1 if active, 0 if destroyed
    component_mask      .quad       // Bitmask of attached components
    archetype_id        .word       // Which archetype this entity belongs to
    archetype_index     .word       // Index within archetype storage
    _padding            .space 16   // Cache line padding
.endstruct

.struct ComponentType
    type_id             .word       // Unique component type ID
    size                .word       // Component size in bytes
    alignment           .word       // Memory alignment requirement
    name_offset         .word       // Offset to component name string
    constructor_ptr     .quad       // Constructor function pointer
    destructor_ptr      .quad       // Destructor function pointer
    copy_ptr            .quad       // Copy function pointer
    serialize_ptr       .quad       // Serialization function pointer
    _padding            .space 8    // Alignment padding
.endstruct

.struct Archetype
    id                  .word       // Unique archetype ID
    component_count     .word       // Number of components in this archetype
    entity_count        .word       // Current number of entities
    entity_capacity     .word       // Maximum entities before reallocation
    component_mask      .quad       // Bitmask of component types
    component_types     .space 256  // Array of component type IDs (64 max)
    component_offsets   .space 256  // Offsets to component data arrays
    entity_data         .quad       // Pointer to entity storage
    component_data      .quad       // Pointer to component storage
    _padding            .space 16   // Cache alignment
.endstruct

.struct SystemInfo
    system_id           .word       // Unique system ID
    priority            .word       // Execution priority (lower = earlier)
    enabled             .word       // 1 if enabled, 0 if disabled
    update_frequency    .word       // Update frequency (0 = every frame)
    last_update_tick    .quad       // Last tick this system updated
    component_mask      .quad       // Required component mask
    update_func         .quad       // System update function pointer
    name_offset         .word       // Offset to system name string
    _padding            .word       // Alignment
.endstruct

.struct ECSWorld
    // Entity management
    entity_count        .word       // Current number of entities
    entity_capacity     .word       // Maximum entities
    next_entity_id      .quad       // Next entity ID to assign
    free_entity_list    .quad       // Head of free entity list
    entity_array        .quad       // Pointer to entity array
    
    // Component management
    component_type_count .word      // Number of registered component types
    max_component_types .word       // Maximum component types (64)
    component_registry  .quad       // Pointer to component type registry
    
    // Archetype management
    archetype_count     .word       // Number of archetypes
    archetype_capacity  .word       // Maximum archetypes
    archetype_array     .quad       // Pointer to archetype array
    archetype_map       .quad       // Hash map: component_mask -> archetype
    
    // System management
    system_count        .word       // Number of registered systems
    system_capacity     .word       // Maximum systems
    system_array        .quad       // Pointer to system array
    system_execution_order .quad    // Sorted system execution order
    
    // Memory management
    entity_allocator    .quad       // Entity memory allocator
    component_allocator .quad       // Component memory allocator
    archetype_allocator .quad       // Archetype memory allocator
    
    // Performance tracking
    total_entities_created .quad    // Lifetime entity creation count
    total_entities_destroyed .quad  // Lifetime entity destruction count
    update_frame_count  .quad       // Total update frames processed
    
    _padding            .space 32   // Cache alignment
.endstruct

// Component type definitions for SimCity
#define COMPONENT_POSITION      0
#define COMPONENT_BUILDING      1
#define COMPONENT_ECONOMIC      2
#define COMPONENT_POPULATION    3
#define COMPONENT_TRANSPORT     4
#define COMPONENT_UTILITY       5
#define COMPONENT_ZONE          6
#define COMPONENT_RENDER        7
#define COMPONENT_AGENT         8
#define COMPONENT_ENVIRONMENT   9
#define COMPONENT_TIME_BASED    10
#define COMPONENT_RESOURCE      11
#define COMPONENT_SERVICE       12
#define COMPONENT_INFRASTRUCTURE 13
#define COMPONENT_CLIMATE       14
#define COMPONENT_TRAFFIC       15

// System IDs
#define SYSTEM_ECONOMIC         0
#define SYSTEM_POPULATION       1
#define SYSTEM_TRANSPORT        2
#define SYSTEM_BUILDING         3
#define SYSTEM_UTILITY          4
#define SYSTEM_ZONE_MANAGEMENT  5
#define SYSTEM_AGENT_AI         6
#define SYSTEM_ENVIRONMENT      7
#define SYSTEM_TIME_PROGRESSION 8
#define SYSTEM_RENDER           9
#define SYSTEM_PHYSICS          10
#define SYSTEM_CLIMATE          11

// Global ECS world instance
.section .bss
    .align 8
    ecs_world:          .space ECSWorld_size

// Component type registry storage
    .align 8
    component_registry: .space (ComponentType_size * 64)
    
// System registry storage
    .align 8
    system_registry:    .space (SystemInfo_size * 32)

// String storage for component and system names
    .align 8
    name_storage:       .space 4096

.section .text

//
// ecs_init - Initialize the ECS world
//
// Parameters:
//   x0 = max_entities (0 = use default 1000000)
//   x1 = max_archetypes (0 = use default 1024)
//
// Returns:
//   x0 = 0 on success, error code on failure
//
.global ecs_init
ecs_init:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    // Store parameters with defaults
    mov     x19, x0                 // max_entities
    cbnz    x19, 1f
    mov     x19, #1000000           // Default 1M entities
1:  mov     x20, x1                 // max_archetypes
    cbnz    x20, 2f
    mov     x20, #1024              // Default 1024 archetypes
2:
    
    // Get ECS world pointer
    adrp    x21, ecs_world
    add     x21, x21, :lo12:ecs_world
    
    // Clear the world structure
    mov     x0, x21
    mov     x1, #ECSWorld_size
    bl      memset
    
    // Initialize basic world parameters
    str     wzr, [x21, #ECSWorld.entity_count]
    str     w19, [x21, #ECSWorld.entity_capacity]
    mov     x0, #1
    str     x0, [x21, #ECSWorld.next_entity_id]
    str     xzr, [x21, #ECSWorld.free_entity_list]
    
    // Initialize component system
    str     wzr, [x21, #ECSWorld.component_type_count]
    mov     w0, #64
    str     w0, [x21, #ECSWorld.max_component_types]
    
    // Initialize archetype system
    str     wzr, [x21, #ECSWorld.archetype_count]
    str     w20, [x21, #ECSWorld.archetype_capacity]
    
    // Initialize system registry
    str     wzr, [x21, #ECSWorld.system_count]
    mov     w0, #32
    str     w0, [x21, #ECSWorld.system_capacity]
    
    // Allocate entity array
    mov     x0, x19                 // max_entities
    mov     x1, #Entity_size
    bl      slab_alloc_array
    cbz     x0, ecs_init_error
    str     x0, [x21, #ECSWorld.entity_array]
    
    // Allocate archetype array
    mov     x0, x20                 // max_archetypes
    mov     x1, #Archetype_size
    bl      slab_alloc_array
    cbz     x0, ecs_init_error
    str     x0, [x21, #ECSWorld.archetype_array]
    
    // Set up component registry pointer
    adrp    x0, component_registry
    add     x0, x0, :lo12:component_registry
    str     x0, [x21, #ECSWorld.component_registry]
    
    // Set up system registry pointer
    adrp    x0, system_registry
    add     x0, x0, :lo12:system_registry
    str     x0, [x21, #ECSWorld.system_array]
    
    // Initialize memory allocators
    bl      init_ecs_allocators
    cmp     x0, #0
    b.ne    ecs_init_error
    
    // Register core component types
    bl      register_core_components
    cmp     x0, #0
    b.ne    ecs_init_error
    
    // Register core systems
    bl      register_core_systems
    cmp     x0, #0
    b.ne    ecs_init_error
    
    mov     x0, #0                  // Success
    b       ecs_init_done
    
ecs_init_error:
    mov     x0, #-1                 // Error
    
ecs_init_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// ecs_create_entity - Create a new entity
//
// Returns:
//   x0 = entity ID (0 = error)
//
.global ecs_create_entity
ecs_create_entity:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    adrp    x19, ecs_world
    add     x19, x19, :lo12:ecs_world
    
    // Check if we have space for more entities
    ldr     w0, [x19, #ECSWorld.entity_count]
    ldr     w1, [x19, #ECSWorld.entity_capacity]
    cmp     w0, w1
    b.ge    create_entity_error
    
    // Check free list first
    ldr     x20, [x19, #ECSWorld.free_entity_list]
    cbnz    x20, reuse_entity_slot
    
    // Allocate new entity slot
    ldr     x1, [x19, #ECSWorld.entity_array]
    ldr     w2, [x19, #ECSWorld.entity_count]
    mov     x3, #Entity_size
    madd    x20, x2, x3, x1         // entity_ptr = array + (count * size)
    
    // Get next entity ID
    ldr     x0, [x19, #ECSWorld.next_entity_id]
    add     x1, x0, #1
    str     x1, [x19, #ECSWorld.next_entity_id]
    
    // Initialize entity
    str     x0, [x20, #Entity.id]
    mov     w1, #1
    str     w1, [x20, #Entity.generation]
    str     w1, [x20, #Entity.active]
    str     xzr, [x20, #Entity.component_mask]
    mov     w1, #-1
    str     w1, [x20, #Entity.archetype_id]
    str     w1, [x20, #Entity.archetype_index]
    
    // Increment entity count
    ldr     w1, [x19, #ECSWorld.entity_count]
    add     w1, w1, #1
    str     w1, [x19, #ECSWorld.entity_count]
    
    // Update statistics
    ldr     x1, [x19, #ECSWorld.total_entities_created]
    add     x1, x1, #1
    str     x1, [x19, #ECSWorld.total_entities_created]
    
    b       create_entity_done
    
reuse_entity_slot:
    // TODO: Implement entity slot reuse from free list
    // For now, fall back to new allocation
    mov     x0, #0
    b       create_entity_error
    
create_entity_error:
    mov     x0, #0                  // Return 0 for error
    
create_entity_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// ecs_destroy_entity - Destroy an entity and remove all its components
//
// Parameters:
//   x0 = entity ID
//
// Returns:
//   x0 = 0 on success, error code on failure
//
.global ecs_destroy_entity
ecs_destroy_entity:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                 // entity_id
    
    // Find entity
    mov     x0, x19
    bl      find_entity
    cbz     x0, destroy_entity_error
    mov     x20, x0                 // entity_ptr
    
    // Check if entity is active
    ldr     w1, [x20, #Entity.active]
    cbz     w1, destroy_entity_error
    
    // Remove from archetype
    ldr     w0, [x20, #Entity.archetype_id]
    ldr     w1, [x20, #Entity.archetype_index]
    bl      remove_entity_from_archetype
    
    // Mark as inactive
    str     wzr, [x20, #Entity.active]
    
    // Add to free list
    adrp    x1, ecs_world
    add     x1, x1, :lo12:ecs_world
    ldr     x2, [x1, #ECSWorld.free_entity_list]
    str     x2, [x20, #Entity.id]   // Use ID field as next pointer
    str     x20, [x1, #ECSWorld.free_entity_list]
    
    // Update statistics
    ldr     x2, [x1, #ECSWorld.total_entities_destroyed]
    add     x2, x2, #1
    str     x2, [x1, #ECSWorld.total_entities_destroyed]
    
    mov     x0, #0                  // Success
    b       destroy_entity_done
    
destroy_entity_error:
    mov     x0, #-1                 // Error
    
destroy_entity_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// ecs_add_component - Add a component to an entity
//
// Parameters:
//   x0 = entity ID
//   x1 = component type ID
//   x2 = component data pointer (optional, can be NULL)
//
// Returns:
//   x0 = pointer to component data, NULL on error
//
.global ecs_add_component
ecs_add_component:
    stp     x29, x30, [sp, #-48]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x29, sp
    
    mov     x19, x0                 // entity_id
    mov     x20, x1                 // component_type_id
    mov     x21, x2                 // component_data
    
    // Find entity
    mov     x0, x19
    bl      find_entity
    cbz     x0, add_component_error
    mov     x22, x0                 // entity_ptr
    
    // Check if entity already has this component
    ldr     x0, [x22, #Entity.component_mask]
    mov     x1, #1
    lsl     x1, x1, x20             // component_bit = 1 << type_id
    tst     x0, x1
    b.ne    add_component_error     // Already has component
    
    // Add component bit to mask
    orr     x0, x0, x1
    str     x0, [x22, #Entity.component_mask]
    
    // Find or create archetype for new component mask
    mov     x0, x0                  // component_mask
    bl      find_or_create_archetype
    cbz     x0, add_component_error
    mov     x1, x0                  // archetype_ptr
    
    // Move entity to new archetype
    mov     x0, x22                 // entity_ptr
    mov     x1, x1                  // new_archetype_ptr
    mov     x2, x20                 // component_type_id
    mov     x3, x21                 // component_data
    bl      move_entity_to_archetype
    
    b       add_component_done
    
add_component_error:
    mov     x0, #0                  // Return NULL on error
    
add_component_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

//
// ecs_remove_component - Remove a component from an entity
//
// Parameters:
//   x0 = entity ID
//   x1 = component type ID
//
// Returns:
//   x0 = 0 on success, error code on failure
//
.global ecs_remove_component
ecs_remove_component:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                 // entity_id
    mov     x20, x1                 // component_type_id
    
    // Find entity
    mov     x0, x19
    bl      find_entity
    cbz     x0, remove_component_error
    mov     x21, x0                 // entity_ptr
    
    // Check if entity has this component
    ldr     x0, [x21, #Entity.component_mask]
    mov     x1, #1
    lsl     x1, x1, x20             // component_bit = 1 << type_id
    tst     x0, x1
    b.eq    remove_component_error  // Doesn't have component
    
    // Remove component bit from mask
    bic     x0, x0, x1
    str     x0, [x21, #Entity.component_mask]
    
    // Find or create archetype for new component mask
    mov     x0, x0                  // component_mask
    bl      find_or_create_archetype
    cbz     x0, remove_component_error
    mov     x1, x0                  // archetype_ptr
    
    // Move entity to new archetype
    mov     x0, x21                 // entity_ptr
    mov     x1, x1                  // new_archetype_ptr
    mov     x2, #-1                 // No component to add
    mov     x3, #0                  // No component data
    bl      move_entity_to_archetype
    
    mov     x0, #0                  // Success
    b       remove_component_done
    
remove_component_error:
    mov     x0, #-1                 // Error
    
remove_component_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// ecs_get_component - Get a pointer to an entity's component data
//
// Parameters:
//   x0 = entity ID
//   x1 = component type ID
//
// Returns:
//   x0 = pointer to component data, NULL if not found
//
.global ecs_get_component
ecs_get_component:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                 // entity_id
    mov     x20, x1                 // component_type_id
    
    // Find entity
    mov     x0, x19
    bl      find_entity
    cbz     x0, get_component_error
    mov     x21, x0                 // entity_ptr
    
    // Check if entity has this component
    ldr     x0, [x21, #Entity.component_mask]
    mov     x1, #1
    lsl     x1, x1, x20             // component_bit = 1 << type_id
    tst     x0, x1
    b.eq    get_component_error     // Doesn't have component
    
    // Get archetype
    ldr     w0, [x21, #Entity.archetype_id]
    bl      get_archetype_by_id
    cbz     x0, get_component_error
    mov     x22, x0                 // archetype_ptr
    
    // Calculate component data pointer
    mov     x0, x22                 // archetype_ptr
    mov     x1, x20                 // component_type_id
    ldr     w2, [x21, #Entity.archetype_index]
    bl      get_component_data_pointer
    
    b       get_component_done
    
get_component_error:
    mov     x0, #0                  // Return NULL on error
    
get_component_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// ecs_update_systems - Update all enabled systems
//
// Parameters:
//   x0 = current_tick
//   d0 = delta_time (in seconds)
//
.global ecs_update_systems
ecs_update_systems:
    stp     x29, x30, [sp, #-32]!
    stp     x19, x20, [sp, #16]
    mov     x29, sp
    
    mov     x19, x0                 // current_tick
    fmov    s20, s0                 // delta_time
    
    adrp    x21, ecs_world
    add     x21, x21, :lo12:ecs_world
    
    // Update frame count
    ldr     x0, [x21, #ECSWorld.update_frame_count]
    add     x0, x0, #1
    str     x0, [x21, #ECSWorld.update_frame_count]
    
    // Get system array and count
    ldr     x22, [x21, #ECSWorld.system_array]
    ldr     w23, [x21, #ECSWorld.system_count]
    
    // Iterate through systems in priority order
    mov     w24, #0                 // system_index
    
system_update_loop:
    cmp     w24, w23
    b.ge    system_update_done
    
    // Get system info
    mov     x0, #SystemInfo_size
    mul     x0, x24, x0
    add     x25, x22, x0            // system_info_ptr
    
    // Check if system is enabled
    ldr     w0, [x25, #SystemInfo.enabled]
    cbz     w0, next_system
    
    // Check update frequency
    ldr     w0, [x25, #SystemInfo.update_frequency]
    cbnz    w0, check_frequency
    b       update_system           // Update every frame
    
check_frequency:
    ldr     x1, [x25, #SystemInfo.last_update_tick]
    sub     x2, x19, x1             // ticks_since_update
    cmp     x2, x0
    b.lt    next_system             // Too soon to update
    
update_system:
    // Update last update tick
    str     x19, [x25, #SystemInfo.last_update_tick]
    
    // Call system update function
    ldr     x0, [x25, #SystemInfo.update_func]
    cbz     x0, next_system
    
    // Parameters: current_tick, delta_time, ecs_world_ptr
    mov     x0, x19                 // current_tick
    fmov    s0, s20                 // delta_time
    mov     x2, x21                 // ecs_world_ptr
    blr     x1                      // Call system update function
    
next_system:
    add     w24, w24, #1
    b       system_update_loop
    
system_update_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//
// Helper functions
//

// find_entity - Find entity by ID
// Parameters: x0 = entity_id
// Returns: x0 = entity pointer, NULL if not found
find_entity:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x1, ecs_world
    add     x1, x1, :lo12:ecs_world
    ldr     x2, [x1, #ECSWorld.entity_array]
    ldr     w3, [x1, #ECSWorld.entity_count]
    
    // Linear search for now (could optimize with hash table)
    mov     w4, #0                  // index
    
find_loop:
    cmp     w4, w3
    b.ge    find_entity_not_found
    
    mov     x5, #Entity_size
    madd    x6, x4, x5, x2          // entity_ptr = array + (index * size)
    
    ldr     x7, [x6, #Entity.id]
    cmp     x7, x0
    b.eq    find_entity_found
    
    add     w4, w4, #1
    b       find_loop
    
find_entity_not_found:
    mov     x0, #0
    b       find_entity_done
    
find_entity_found:
    mov     x0, x6                  // Return entity pointer
    
find_entity_done:
    ldp     x29, x30, [sp], #16
    ret

// Additional helper functions would be implemented here:
// - find_or_create_archetype
// - move_entity_to_archetype  
// - get_archetype_by_id
// - get_component_data_pointer
// - init_ecs_allocators
// - register_core_components
// - register_core_systems
// - remove_entity_from_archetype

// External function declarations
.extern memset
.extern slab_alloc_array