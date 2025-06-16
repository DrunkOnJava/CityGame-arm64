# Sub-Agent 4: Graphics Pipeline Integrator Plan

## Objective
Unify metal_encoder.s with all rendering modules, connect sprite_batch.s, particles.s, debug_overlay.s, wire isometric_transform.s to camera system, integrate depth sorting across all renderers.

## Graphics Architecture Overview

### Rendering Pipeline
1. **Metal Command Encoding**
   - Command buffer management
   - Render pass descriptors
   - Pipeline state objects
   - Resource binding

2. **Batch Rendering Systems**
   - Sprite batching (4-sprite NEON)
   - Particle systems (130K+)
   - Debug overlays
   - Tile rendering

3. **Coordinate Systems**
   - World space (simulation)
   - Isometric transformation
   - Screen space (pixels)
   - Depth sorting

## Implementation Tasks

### Task 1: Unified Render Loop
```assembly
.global unified_render_frame
unified_render_frame:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #32]
    stp x21, x22, [sp, #16]
    
    ; Get command buffer
    bl metal_encoder_begin_frame
    mov x19, x0  ; command buffer
    
    ; Clear and setup
    mov x0, x19
    bl setup_render_pass
    
    ; Update camera matrices
    bl camera_update_matrices
    
    ; Render layers in order
    mov x0, x19
    bl render_terrain_layer
    
    mov x0, x19
    bl render_building_layer
    
    mov x0, x19
    bl render_entity_layer
    
    mov x0, x19
    bl render_particle_layer
    
    mov x0, x19
    bl render_ui_layer
    
    mov x0, x19
    bl render_debug_overlay
    
    ; Commit and present
    mov x0, x19
    bl metal_encoder_end_frame
    
    ldp x21, x22, [sp, #16]
    ldp x19, x20, [sp, #32]
    ldp x29, x30, [sp], #48
    ret
```

### Task 2: Sprite Batch Integration
```assembly
.global sprite_batch_render_layer
sprite_batch_render_layer:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    
    mov x19, x0  ; command encoder
    mov x20, x1  ; layer_id
    
    ; Query visible sprites
    mov x0, x20
    bl query_visible_sprites
    mov x21, x0  ; sprite count
    mov x22, x1  ; sprite array
    
    ; Process in NEON batches of 4
    mov x23, #0
.batch_loop:
    cmp x23, x21
    b.ge .done
    
    ; Load 4 sprites
    add x0, x22, x23, lsl #6  ; sprite_size = 64
    bl load_sprite_batch_neon
    
    ; Transform to screen space
    bl isometric_transform_batch
    
    ; Depth sort
    bl depth_sort_batch
    
    ; Generate vertices
    bl generate_sprite_vertices
    
    ; Submit to GPU
    mov x0, x19
    bl submit_sprite_batch
    
    add x23, x23, #4
    b .batch_loop
    
.done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
```

### Task 3: Particle System Integration
```assembly
.global particle_system_render
particle_system_render:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    mov x19, x0  ; command encoder
    
    ; Update all particle systems
    bl particle_systems_update_all
    
    ; Get active particles
    bl get_active_particle_count
    mov x20, x0
    
    cbz x20, .no_particles
    
    ; Allocate vertex buffer
    lsl x0, x20, #5  ; 32 bytes per particle
    bl allocate_transient_buffer
    mov x21, x0
    
    ; Fill vertex buffer (NEON optimized)
    mov x0, x21
    mov x1, x20
    bl fill_particle_vertices_neon
    
    ; Bind particle pipeline
    mov x0, x19
    adrp x1, particle_pipeline
    ldr x1, [x1, :lo12:particle_pipeline]
    bl bind_render_pipeline
    
    ; Draw
    mov x0, x19
    mov x1, x20
    bl draw_particles
    
.no_particles:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
```

### Task 4: Isometric Transform Integration
```assembly
.global isometric_transform_unified
isometric_transform_unified:
    ; x0 = world position (x, y, z)
    ; Returns screen position in v0
    
    ; Load transform matrix
    adrp x1, isometric_matrix
    add x1, x1, :lo12:isometric_matrix
    ld1 {v4.4s, v5.4s, v6.4s, v7.4s}, [x1]
    
    ; Load world position
    ld1 {v0.4s}, [x0]
    
    ; Transform
    fmul v1.4s, v4.4s, v0.s[0]
    fmla v1.4s, v5.4s, v0.s[1]
    fmla v1.4s, v6.4s, v0.s[2]
    fadd v1.4s, v1.4s, v7.4s
    
    ; Apply camera offset
    adrp x1, camera_offset
    ldr q2, [x1, :lo12:camera_offset]
    fsub v0.4s, v1.4s, v2.4s
    
    ret
```

### Task 5: Unified Depth Sorting
```assembly
.global unified_depth_sort
unified_depth_sort:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    
    ; Collect all renderable objects
    bl collect_all_renderables
    mov x19, x0  ; object count
    mov x20, x1  ; object array
    
    ; Calculate depth values
    mov x0, x20
    mov x1, x19
    bl calculate_isometric_depths
    
    ; Radix sort by depth
    mov x0, x20
    mov x1, x19
    bl radix_sort_by_depth
    
    ; Generate draw calls
    mov x0, x20
    mov x1, x19
    bl generate_sorted_draw_calls
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
```

## Metal Integration

### Pipeline State Management
```assembly
.data
.align 3
render_pipelines:
    .quad terrain_pipeline
    .quad building_pipeline
    .quad entity_pipeline
    .quad particle_pipeline
    .quad ui_pipeline
    .quad debug_pipeline

.text
.global bind_pipeline_for_layer
bind_pipeline_for_layer:
    ; x0 = encoder
    ; x1 = layer_id
    
    adrp x2, render_pipelines
    add x2, x2, :lo12:render_pipelines
    ldr x2, [x2, x1, lsl #3]
    
    ; Bind pipeline
    mov x1, x2
    bl metal_bind_pipeline_state
    
    ret
```

### Resource Binding
```assembly
.global bind_frame_resources
bind_frame_resources:
    ; Bind camera uniforms
    mov x0, #0  ; buffer index
    adrp x1, camera_uniforms
    ldr x1, [x1, :lo12:camera_uniforms]
    mov x2, #0  ; offset
    bl metal_bind_buffer
    
    ; Bind time uniforms
    mov x0, #1
    adrp x1, time_uniforms
    ldr x1, [x1, :lo12:time_uniforms]
    mov x2, #0
    bl metal_bind_buffer
    
    ; Bind textures
    mov x0, #0  ; texture index
    adrp x1, sprite_atlas
    ldr x1, [x1, :lo12:sprite_atlas]
    bl metal_bind_texture
    
    ret
```

## Performance Optimizations

### Instanced Rendering
- Buildings use hardware instancing
- Repeated sprites batched
- Particle instancing
- UI element atlasing

### Culling Strategies
- Frustum culling
- Occlusion culling
- LOD selection
- Small object culling

### Memory Management
- Transient vertex buffers
- Ring buffer allocation
- Texture atlasing
- Compressed vertex formats

## Integration Points

### Simulation Integration (Sub-Agent 3)
- Entity position updates
- Building placement
- Effect triggers
- Zone visualization

### Memory Integration (Sub-Agent 2)
- Vertex buffer allocation
- Texture memory
- Command buffer pools
- Transient allocations

### Performance Integration (Sub-Agent 7)
- Frame time tracking
- Draw call counting
- GPU utilization
- Memory bandwidth

## Success Metrics
1. Stable 60 FPS with 1M+ entities
2. < 10ms CPU render time
3. < 5000 draw calls per frame
4. < 2GB GPU memory usage
5. Zero visual artifacts

## Timeline
- Day 1: Unified render loop
- Day 2: Batch rendering integration
- Day 3: Transform and depth sorting
- Day 4: Metal resource management
- Day 5: Performance optimization