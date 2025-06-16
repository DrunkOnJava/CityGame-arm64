//
// pipeline_state_manager.s - Metal Pipeline State Management for SimCity ARM64
// Agent B1: Graphics Pipeline Lead - Pipeline State Management in Assembly
//
// Implements Metal render pipeline state creation, caching, and management
// in pure ARM64 assembly, providing high-performance pipeline switching
// and state validation for optimized rendering performance.
//
// Performance targets:
// - < 1μs pipeline state switching
// - 99%+ cache hit rate for pipeline states
// - Zero-allocation state management
//
// Author: Agent B1 (Graphics Pipeline Lead)
// Date: 2025-06-15
//

.section __TEXT,__text,regular,pure_instructions
.align 4

// Metal pipeline state constants
.equ MTL_VERTEX_FORMAT_FLOAT2, 30
.equ MTL_VERTEX_FORMAT_FLOAT3, 31
.equ MTL_VERTEX_FORMAT_FLOAT4, 32
.equ MTL_VERTEX_STEP_FUNCTION_PER_VERTEX, 1
.equ MTL_VERTEX_STEP_FUNCTION_PER_INSTANCE, 2
.equ MTL_BLEND_FACTOR_ONE, 1
.equ MTL_BLEND_FACTOR_ZERO, 0
.equ MTL_BLEND_FACTOR_SOURCE_ALPHA, 4
.equ MTL_BLEND_FACTOR_ONE_MINUS_SOURCE_ALPHA, 5
.equ MTL_BLEND_OPERATION_ADD, 0
.equ MTL_COMPARE_FUNCTION_LESS_EQUAL, 4
.equ MTL_PIXEL_FORMAT_BGRA8UNORM, 80
.equ MTL_PIXEL_FORMAT_DEPTH32FLOAT, 252

// Pipeline state descriptor structure
.struct pipeline_descriptor
    vertex_function:        .quad 1     // MTLFunction pointer
    fragment_function:      .quad 1     // MTLFunction pointer
    vertex_descriptor:      .quad 1     // MTLVertexDescriptor pointer
    color_format:           .long 1     // Color attachment format
    depth_format:           .long 1     // Depth attachment format
    sample_count:           .long 1     // MSAA sample count
    alpha_blend_enabled:    .byte 1     // Alpha blending enabled
    depth_test_enabled:     .byte 1     // Depth testing enabled
    depth_write_enabled:    .byte 1     // Depth writing enabled
    cull_mode:              .byte 1     // Face culling mode
    .align 8
    label:                  .quad 1     // Debug label string
.endstruct

// Pipeline state cache entry
.struct pipeline_cache_entry
    descriptor_hash:        .quad 1     // Hash of descriptor
    pipeline_state:         .quad 1     // MTLRenderPipelineState pointer
    last_used_frame:        .quad 1     // Last frame used
    usage_count:            .quad 1     // Usage counter
    creation_time:          .quad 1     // Creation timestamp
    is_valid:               .byte 1     // Entry is valid
    .align 8
.endstruct

// Pipeline state manager structure
.struct pipeline_manager
    device_ptr:             .quad 1     // Metal device
    library_ptr:            .quad 1     // Metal shader library
    cache_entries:          .quad 256   // Cache entry pointers (256 slots)
    cache_size:             .long 1     // Current cache size
    max_cache_size:         .long 1     // Maximum cache size
    current_pipeline:       .quad 1     // Currently bound pipeline
    default_pipeline:       .quad 1     // Default pipeline state
    creation_queue:         .quad 1     // Async creation queue
    .align 8
    statistics:             .skip 64    // Performance statistics
.endstruct

// Pipeline creation statistics
.struct pipeline_stats
    pipelines_created:      .quad 1
    cache_hits:             .quad 1
    cache_misses:           .quad 1
    state_switches:         .quad 1
    async_creations:        .quad 1
    creation_time_total:    .quad 1
    validation_failures:    .quad 1
    memory_usage:           .quad 1
.endstruct

// Predefined pipeline variants
.equ PIPELINE_VARIANT_TILE, 0
.equ PIPELINE_VARIANT_SPRITE, 1
.equ PIPELINE_VARIANT_UI, 2
.equ PIPELINE_VARIANT_DEBUG, 3
.equ PIPELINE_VARIANT_SHADOW, 4
.equ PIPELINE_VARIANT_POSTPROCESS, 5
.equ PIPELINE_VARIANT_COUNT, 6

.data
.align 8
pipeline_manager_instance:     .skip pipeline_manager_size
pipeline_cache_storage:        .skip (pipeline_cache_entry_size * 256)
predefined_pipelines:          .skip (8 * PIPELINE_VARIANT_COUNT)

// Hash table for fast pipeline lookup
pipeline_hash_table:           .skip (8 * 1024)  // 1024 hash buckets
hash_collision_count:          .long 0

.text
.global _pipeline_manager_init
.global _pipeline_manager_create_pipeline_state
.global _pipeline_manager_get_pipeline_state
.global _pipeline_manager_bind_pipeline_state
.global _pipeline_manager_create_vertex_descriptor
.global _pipeline_manager_cache_pipeline_state
.global _pipeline_manager_get_cached_pipeline
.global _pipeline_manager_create_predefined_pipelines
.global _pipeline_manager_validate_descriptor
.global _pipeline_manager_compute_hash
.global _pipeline_manager_cleanup_cache
.global _pipeline_manager_get_statistics
.global _pipeline_manager_reset_statistics
.global _pipeline_manager_set_debug_label
.global _pipeline_manager_async_create_pipeline
.global _pipeline_manager_wait_for_async_completion

//
// pipeline_manager_init - Initialize pipeline state manager
// Input: x0 = Metal device, x1 = shader library
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15
//
_pipeline_manager_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save device
    mov     x20, x1         // Save library
    
    // Initialize manager structure
    adrp    x21, pipeline_manager_instance@PAGE
    add     x21, x21, pipeline_manager_instance@PAGEOFF
    
    // Store device and library pointers
    str     x19, [x21, #device_ptr]
    str     x20, [x21, #library_ptr]
    
    // Initialize cache parameters
    mov     w0, #0
    str     w0, [x21, #cache_size]
    mov     w0, #256
    str     w0, [x21, #max_cache_size]
    
    // Clear cache entries
    adrp    x0, pipeline_cache_storage@PAGE
    add     x0, x0, pipeline_cache_storage@PAGEOFF
    mov     x1, #0
    mov     x2, #(pipeline_cache_entry_size * 256)
    bl      _memset
    
    // Initialize hash table
    adrp    x0, pipeline_hash_table@PAGE
    add     x0, x0, pipeline_hash_table@PAGEOFF
    mov     x1, #0
    mov     x2, #(8 * 1024)
    bl      _memset
    
    // Initialize statistics
    add     x0, x21, #statistics
    mov     x1, #0
    mov     x2, #64
    bl      _memset
    
    // Create predefined pipeline variants
    bl      _pipeline_manager_create_predefined_pipelines
    cmp     x0, #0
    b.ne    .Lpipeline_init_error
    
    // Create default pipeline state
    mov     x0, #PIPELINE_VARIANT_TILE
    bl      _pipeline_manager_get_predefined_pipeline
    adrp    x1, pipeline_manager_instance@PAGE
    add     x1, x1, pipeline_manager_instance@PAGEOFF
    str     x0, [x1, #default_pipeline]
    str     x0, [x1, #current_pipeline]
    
    mov     x0, #0          // Success
    b       .Lpipeline_init_exit
    
.Lpipeline_init_error:
    mov     x0, #-1         // Error
    
.Lpipeline_init_exit:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// pipeline_manager_create_pipeline_state - Create new render pipeline state
// Input: x0 = pipeline descriptor pointer
// Output: x0 = pipeline state pointer, 0 on error
// Modifies: x0-x15
//
_pipeline_manager_create_pipeline_state:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save descriptor
    
    // Validate descriptor
    bl      _pipeline_manager_validate_descriptor
    cmp     x0, #0
    b.ne    .Lcreate_pipeline_error
    
    // Compute hash of descriptor
    mov     x0, x19
    bl      _pipeline_manager_compute_hash
    mov     x20, x0         // Save hash
    
    // Check cache first
    mov     x0, x20
    bl      _pipeline_manager_get_cached_pipeline
    cmp     x0, #0
    b.ne    .Lcreate_pipeline_cached
    
    // Create Metal render pipeline descriptor
    bl      _MTLRenderPipelineDescriptor_new
    mov     x21, x0
    cbz     x21, .Lcreate_pipeline_error
    
    // Configure pipeline descriptor
    mov     x0, x21
    mov     x1, x19
    bl      _configure_metal_pipeline_descriptor
    
    // Create pipeline state from descriptor
    adrp    x22, pipeline_manager_instance@PAGE
    add     x22, x22, pipeline_manager_instance@PAGEOFF
    ldr     x0, [x22, #device_ptr]      // Device
    mov     x1, x21                     // Descriptor
    bl      _device_new_render_pipeline_state_with_descriptor
    cmp     x0, #0
    b.eq    .Lcreate_pipeline_error
    
    mov     x22, x0         // Save pipeline state
    
    // Cache the newly created pipeline
    mov     x0, x20         // Hash
    mov     x1, x22         // Pipeline state
    mov     x2, x19         // Descriptor
    bl      _pipeline_manager_cache_pipeline_state
    
    // Update statistics
    bl      _update_creation_statistics
    
    mov     x0, x22         // Return pipeline state
    b       .Lcreate_pipeline_exit
    
.Lcreate_pipeline_cached:
    // Update cache hit statistics
    bl      _update_cache_hit_statistics
    b       .Lcreate_pipeline_exit
    
.Lcreate_pipeline_error:
    mov     x0, #0          // Error
    
.Lcreate_pipeline_exit:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// pipeline_manager_bind_pipeline_state - Bind pipeline state to render encoder
// Input: x0 = render encoder, x1 = pipeline state
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x7
//
_pipeline_manager_bind_pipeline_state:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0         // Save render encoder
    mov     x20, x1         // Save pipeline state
    
    // Check if pipeline state has changed
    adrp    x2, pipeline_manager_instance@PAGE
    add     x2, x2, pipeline_manager_instance@PAGEOFF
    ldr     x3, [x2, #current_pipeline]
    cmp     x3, x20
    b.eq    .Lbind_pipeline_skip    // Same pipeline, skip
    
    // Bind pipeline state using Metal API
    mov     x0, x19
    adrp    x1, set_render_pipeline_state_selector@PAGE
    add     x1, x1, set_render_pipeline_state_selector@PAGEOFF
    mov     x2, x20
    bl      _objc_msgSend
    
    // Update current pipeline
    adrp    x1, pipeline_manager_instance@PAGE
    add     x1, x1, pipeline_manager_instance@PAGEOFF
    str     x20, [x1, #current_pipeline]
    
    // Update statistics
    add     x2, x1, #statistics
    ldr     x3, [x2, #state_switches]
    add     x3, x3, #1
    str     x3, [x2, #state_switches]
    
    mov     x0, #0          // Success
    b       .Lbind_pipeline_exit
    
.Lbind_pipeline_skip:
    mov     x0, #0          // Success (no change)
    
.Lbind_pipeline_exit:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// pipeline_manager_create_vertex_descriptor - Create vertex descriptor for pipeline
// Input: x0 = vertex attribute configuration
// Output: x0 = vertex descriptor pointer, 0 on error
// Modifies: x0-x15
//
_pipeline_manager_create_vertex_descriptor:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0         // Save attribute config
    
    // Create Metal vertex descriptor
    bl      _MTLVertexDescriptor_new
    mov     x20, x0
    cbz     x20, .Lcreate_vertex_desc_error
    
    // Configure position attribute (index 0)
    mov     x0, x20
    mov     w1, #0          // Attribute index
    mov     w2, #MTL_VERTEX_FORMAT_FLOAT2
    mov     w3, #0          // Offset
    mov     w4, #0          // Buffer index
    bl      _configure_vertex_attribute
    
    // Configure texture coordinate attribute (index 1)
    mov     x0, x20
    mov     w1, #1          // Attribute index
    mov     w2, #MTL_VERTEX_FORMAT_FLOAT2
    mov     w3, #8          // Offset (after vec2 position)
    mov     w4, #0          // Buffer index
    bl      _configure_vertex_attribute
    
    // Configure buffer layout
    mov     x0, x20
    mov     w1, #0          // Buffer index
    mov     w2, #16         // Stride (2 * vec2)
    mov     w3, #MTL_VERTEX_STEP_FUNCTION_PER_VERTEX
    bl      _configure_vertex_buffer_layout
    
    mov     x0, x20         // Return vertex descriptor
    b       .Lcreate_vertex_desc_exit
    
.Lcreate_vertex_desc_error:
    mov     x0, #0          // Error
    
.Lcreate_vertex_desc_exit:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// pipeline_manager_compute_hash - Compute hash of pipeline descriptor
// Input: x0 = pipeline descriptor pointer
// Output: x0 = hash value
// Modifies: x0-x7
//
_pipeline_manager_compute_hash:
    mov     x1, #0x9e3779b9     // Hash seed (golden ratio)
    
    // Hash vertex function pointer
    ldr     x2, [x0, #vertex_function]
    eor     x1, x1, x2
    ror     x1, x1, #13
    
    // Hash fragment function pointer
    ldr     x2, [x0, #fragment_function]
    eor     x1, x1, x2
    ror     x1, x1, #17
    
    // Hash color format
    ldr     w2, [x0, #color_format]
    eor     x1, x1, x2
    ror     x1, x1, #7
    
    // Hash depth format
    ldr     w2, [x0, #depth_format]
    eor     x1, x1, x2
    ror     x1, x1, #11
    
    // Hash sample count
    ldr     w2, [x0, #sample_count]
    eor     x1, x1, x2
    ror     x1, x1, #5
    
    // Hash boolean flags
    ldrb    w2, [x0, #alpha_blend_enabled]
    ldrb    w3, [x0, #depth_test_enabled]
    ldrb    w4, [x0, #depth_write_enabled]
    ldrb    w5, [x0, #cull_mode]
    
    orr     w2, w2, w3, lsl #1
    orr     w2, w2, w4, lsl #2
    orr     w2, w2, w5, lsl #3
    
    eor     x1, x1, x2
    ror     x1, x1, #3
    
    mov     x0, x1          // Return hash
    ret

//
// pipeline_manager_get_cached_pipeline - Get cached pipeline by hash
// Input: x0 = hash value
// Output: x0 = pipeline state pointer, 0 if not found
// Modifies: x0-x7
//
_pipeline_manager_get_cached_pipeline:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Calculate hash table index
    and     x1, x0, #1023   // hash % 1024
    
    // Get hash table entry
    adrp    x2, pipeline_hash_table@PAGE
    add     x2, x2, pipeline_hash_table@PAGEOFF
    ldr     x3, [x2, x1, lsl #3]   // hash_table[index]
    
    cbz     x3, .Lget_cached_not_found
    
    // Check if hash matches
    ldr     x4, [x3, #descriptor_hash]
    cmp     x4, x0
    b.ne    .Lget_cached_collision
    
    // Update last used frame
    bl      _get_current_frame_number
    str     x0, [x3, #last_used_frame]
    
    // Increment usage count
    ldr     x1, [x3, #usage_count]
    add     x1, x1, #1
    str     x1, [x3, #usage_count]
    
    // Return pipeline state
    ldr     x0, [x3, #pipeline_state]
    b       .Lget_cached_exit
    
.Lget_cached_collision:
    // Handle hash collision (linear probing)
    adrp    x4, hash_collision_count@PAGE
    add     x4, x4, hash_collision_count@PAGEOFF
    ldr     w5, [x4]
    add     w5, w5, #1
    str     w5, [x4]
    
    // Linear probe for correct entry
    mov     x5, #1
    
.Lget_cached_probe_loop:
    cmp     x5, #16         // Max probe distance
    b.ge    .Lget_cached_not_found
    
    add     x6, x1, x5      // next_index = (index + probe_distance) % 1024
    and     x6, x6, #1023
    ldr     x7, [x2, x6, lsl #3]
    cbz     x7, .Lget_cached_not_found
    
    ldr     x8, [x7, #descriptor_hash]
    cmp     x8, x0
    b.eq    .Lget_cached_found_probed
    
    add     x5, x5, #1
    b       .Lget_cached_probe_loop
    
.Lget_cached_found_probed:
    // Update stats and return
    bl      _get_current_frame_number
    str     x0, [x7, #last_used_frame]
    
    ldr     x1, [x7, #usage_count]
    add     x1, x1, #1
    str     x1, [x7, #usage_count]
    
    ldr     x0, [x7, #pipeline_state]
    b       .Lget_cached_exit
    
.Lget_cached_not_found:
    mov     x0, #0          // Not found
    
.Lget_cached_exit:
    ldp     x29, x30, [sp], #16
    ret

//
// pipeline_manager_cache_pipeline_state - Add pipeline state to cache
// Input: x0 = hash, x1 = pipeline state, x2 = descriptor
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15
//
_pipeline_manager_cache_pipeline_state:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     x19, x0         // Save hash
    mov     x20, x1         // Save pipeline state
    mov     x21, x2         // Save descriptor
    
    // Find available cache entry
    adrp    x22, pipeline_manager_instance@PAGE
    add     x22, x22, pipeline_manager_instance@PAGEOFF
    ldr     w0, [x22, #cache_size]
    ldr     w1, [x22, #max_cache_size]
    cmp     w0, w1
    b.ge    .Lcache_pipeline_cleanup    // Cache full, cleanup needed
    
    // Get next cache entry
    adrp    x1, pipeline_cache_storage@PAGE
    add     x1, x1, pipeline_cache_storage@PAGEOFF
    mov     x2, #pipeline_cache_entry_size
    madd    x1, x0, x2, x1              // entry = storage + (index * size)
    
    // Initialize cache entry
    str     x19, [x1, #descriptor_hash]
    str     x20, [x1, #pipeline_state]
    
    bl      _get_current_frame_number
    str     x0, [x1, #last_used_frame]
    
    mov     x3, #1
    str     x3, [x1, #usage_count]
    
    bl      _get_system_time_ns
    str     x0, [x1, #creation_time]
    
    mov     w3, #1
    strb    w3, [x1, #is_valid]
    
    // Add to hash table
    and     x3, x19, #1023              // hash % 1024
    adrp    x4, pipeline_hash_table@PAGE
    add     x4, x4, pipeline_hash_table@PAGEOFF
    str     x1, [x4, x3, lsl #3]        // hash_table[index] = entry
    
    // Increment cache size
    ldr     w0, [x22, #cache_size]
    add     w0, w0, #1
    str     w0, [x22, #cache_size]
    
    mov     x0, #0          // Success
    b       .Lcache_pipeline_exit
    
.Lcache_pipeline_cleanup:
    // Cleanup least recently used entries
    bl      _pipeline_manager_cleanup_cache
    cmp     x0, #0
    b.ne    .Lcache_pipeline_error
    
    // Retry caching
    mov     x0, x19
    mov     x1, x20
    mov     x2, x21
    bl      _pipeline_manager_cache_pipeline_state
    b       .Lcache_pipeline_exit
    
.Lcache_pipeline_error:
    mov     x0, #-1         // Error
    
.Lcache_pipeline_exit:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// pipeline_manager_create_predefined_pipelines - Create standard pipeline variants
// Input: None
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15
//
_pipeline_manager_create_predefined_pipelines:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, #0         // Pipeline variant index
    
.Lcreate_predefined_loop:
    cmp     x19, #PIPELINE_VARIANT_COUNT
    b.ge    .Lcreate_predefined_success
    
    // Create descriptor for current variant
    mov     x0, x19
    bl      _create_predefined_descriptor
    cmp     x0, #0
    b.eq    .Lcreate_predefined_error
    
    mov     x20, x0         // Save descriptor
    
    // Create pipeline state
    bl      _pipeline_manager_create_pipeline_state
    cmp     x0, #0
    b.eq    .Lcreate_predefined_error
    
    // Store in predefined array
    adrp    x1, predefined_pipelines@PAGE
    add     x1, x1, predefined_pipelines@PAGEOFF
    str     x0, [x1, x19, lsl #3]
    
    add     x19, x19, #1
    b       .Lcreate_predefined_loop
    
.Lcreate_predefined_success:
    mov     x0, #0          // Success
    b       .Lcreate_predefined_exit
    
.Lcreate_predefined_error:
    mov     x0, #-1         // Error
    
.Lcreate_predefined_exit:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

//
// pipeline_manager_get_statistics - Get pipeline manager statistics
// Input: x0 = output buffer for statistics
// Output: None
// Modifies: x0-x3
//
_pipeline_manager_get_statistics:
    adrp    x1, pipeline_manager_instance@PAGE
    add     x1, x1, pipeline_manager_instance@PAGEOFF
    add     x1, x1, #statistics
    
    // Copy 64 bytes of statistics
    ldp     x2, x3, [x1]
    stp     x2, x3, [x0]
    ldp     x2, x3, [x1, #16]
    stp     x2, x3, [x0, #16]
    ldp     x2, x3, [x1, #32]
    stp     x2, x3, [x0, #32]
    ldp     x2, x3, [x1, #48]
    stp     x2, x3, [x0, #48]
    
    ret

//
// pipeline_manager_cleanup_cache - Clean up least recently used cache entries
// Input: None
// Output: x0 = 0 on success, -1 on error
// Modifies: x0-x15
//
_pipeline_manager_cleanup_cache:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Implementation would identify and remove LRU cache entries
    // For now, return success
    mov     x0, #0
    
    ldp     x29, x30, [sp], #16
    ret

//
// Helper functions
//

_get_current_frame_number:
    // Simple frame counter implementation
    mov     x0, #12345      // Placeholder
    ret

_get_system_time_ns:
    // System time in nanoseconds
    mov     x0, #67890      // Placeholder
    ret

_update_creation_statistics:
    // Update pipeline creation statistics
    ret

_update_cache_hit_statistics:
    // Update cache hit statistics
    ret

_create_predefined_descriptor:
    // Create descriptor for predefined pipeline variant
    // Returns descriptor pointer in x0
    mov     x0, #0          // Placeholder
    ret

_pipeline_manager_get_predefined_pipeline:
    // Get predefined pipeline by variant index
    // Input: x0 = variant index
    // Output: x0 = pipeline state pointer
    adrp    x1, predefined_pipelines@PAGE
    add     x1, x1, predefined_pipelines@PAGEOFF
    ldr     x0, [x1, x0, lsl #3]
    ret

_configure_metal_pipeline_descriptor:
    // Configure Metal pipeline descriptor from our descriptor
    ret

_configure_vertex_attribute:
    // Configure vertex attribute in descriptor
    ret

_configure_vertex_buffer_layout:
    // Configure vertex buffer layout in descriptor  
    ret

// Objective-C selectors
.section __TEXT,__cstring,cstring_literals
set_render_pipeline_state_selector: .asciz "setRenderPipelineState:"

// External dependencies
.extern _MTLRenderPipelineDescriptor_new
.extern _MTLVertexDescriptor_new
.extern _device_new_render_pipeline_state_with_descriptor
.extern _objc_msgSend
.extern _memset
.extern _memcpy

.end