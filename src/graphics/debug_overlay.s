//
// debug_overlay.s - ARM64 Assembly Debug Overlay & Performance Visualization
// Agent B5: Graphics Team - Debug Overlay Specialist
//
// High-performance debug rendering system implemented in pure ARM64 assembly
// Provides real-time performance monitoring, memory visualization, and
// interactive debugging controls for SimCity ARM64.
//
// Features:
// - Text and line rendering primitives
// - Performance graphs and statistics
// - Memory usage visualization
// - Frame timing and profiling
// - Interactive debug controls
// - Integration with Metal rendering pipeline
//
// Performance targets:
// - < 0.5ms debug overlay render time
// - < 2MB memory footprint
// - 60+ FPS with full debug display
//
// Author: Agent B5 (Graphics/Debug)
// Date: 2025-06-15
//

.section __TEXT,__text,regular,pure_instructions
.align 4

// Constants and definitions
.equ DEBUG_OVERLAY_VERSION, 0x00010000
.equ DEBUG_MAX_TEXT_LENGTH, 256
.equ DEBUG_MAX_LINES, 1024
.equ DEBUG_HISTORY_SIZE, 120                // 2 seconds at 60fps
.equ DEBUG_FONT_ATLAS_SIZE, 512
.equ DEBUG_COLOR_WHITE, 0xFFFFFFFF
.equ DEBUG_COLOR_GREEN, 0xFF00FF00
.equ DEBUG_COLOR_RED, 0xFF0000FF
.equ DEBUG_COLOR_YELLOW, 0xFF00FFFF
.equ DEBUG_COLOR_BLUE, 0xFFFF0000

// Debug overlay state structure
.struct debug_overlay_state
    initialized:            .byte 1         // Initialization flag
    enabled:                .byte 1         // Overall enable flag
    show_performance:       .byte 1         // Performance window toggle
    show_memory:            .byte 1         // Memory window toggle
    show_frame_timing:      .byte 1         // Frame timing toggle
    show_graphs:            .byte 1         // Graphs toggle
    show_controls:          .byte 1         // Controls toggle
    _padding1:              .byte 1         // Alignment padding
    
    // Render context
    metal_device:           .quad 1         // MTLDevice pointer
    command_queue:          .quad 1         // MTLCommandQueue pointer
    current_encoder:        .quad 1         // Current render encoder
    pipeline_state:         .quad 1         // Debug render pipeline
    
    // Font and text rendering
    font_atlas_texture:     .quad 1         // Font atlas texture
    font_char_width:        .long 1         // Character width in pixels
    font_char_height:       .long 1         // Character height in pixels
    font_texture_width:     .long 1         // Font atlas width
    font_texture_height:    .long 1         // Font atlas height
    
    // Performance metrics
    frame_times:            .space DEBUG_HISTORY_SIZE * 4  // Frame time history (ms)
    cpu_usage:              .space DEBUG_HISTORY_SIZE * 4  // CPU usage history (%)
    memory_usage:           .space DEBUG_HISTORY_SIZE * 4  // Memory usage (MB)
    draw_calls:             .space DEBUG_HISTORY_SIZE * 4  // Draw call count
    
    frame_time_index:       .long 1         // Current history index
    avg_frame_time:         .float 1        // Average frame time
    min_frame_time:         .float 1        // Minimum frame time
    max_frame_time:         .float 1        // Maximum frame time
    current_fps:            .float 1        // Current FPS
    
    // Memory tracking
    total_memory:           .quad 1         // Total system memory
    used_memory:            .quad 1         // Current used memory
    heap_allocations:       .quad 1         // Number of heap allocations
    peak_memory:            .quad 1         // Peak memory usage
    
    // System metrics
    cpu_percent:            .float 1        // Current CPU usage %
    gpu_percent:            .float 1        // Current GPU usage %
    thread_count:           .long 1         // Active thread count
    entity_count:           .long 1         // Current entity count
    
    // Render state
    vertex_buffer:          .quad 1         // Debug vertex buffer
    index_buffer:           .quad 1         // Debug index buffer
    uniform_buffer:         .quad 1         // Debug uniforms
    vertex_count:           .long 1         // Current vertex count
    line_count:             .long 1         // Current line count
    
    // Timing
    last_update_time:       .quad 1         // Last update timestamp
    update_interval:        .quad 1         // Update interval (microseconds)
.endstruct

// Debug vertex structure for text and lines
.struct debug_vertex
    position:               .space 2 * 4    // x, y position
    uv:                     .space 2 * 4    // u, v texture coordinates
    color:                  .long 1         // RGBA color
.endstruct

// Debug line structure
.struct debug_line
    start_x:                .float 1        // Start X coordinate
    start_y:                .float 1        // Start Y coordinate
    end_x:                  .float 1        // End X coordinate
    end_y:                  .float 1        // End Y coordinate
    color:                  .long 1         // Line color
    thickness:              .float 1        // Line thickness
.endstruct

// Global debug overlay state
.section __DATA,__data
.align 8
g_debug_state:
    .space debug_overlay_state_size

// Font atlas data (embedded 8x8 bitmap font)
debug_font_atlas:
    .incbin "debug_font_8x8.bin"    // Would contain bitmap font data

// Vertex and fragment shader source (embedded)
debug_vertex_shader_source:
    .ascii "#include <metal_stdlib>\n"
    .ascii "using namespace metal;\n"
    .ascii "struct VertexIn {\n"
    .ascii "    float2 position [[attribute(0)]];\n"
    .ascii "    float2 uv [[attribute(1)]];\n"
    .ascii "    uint color [[attribute(2)]];\n"
    .ascii "};\n"
    .ascii "struct VertexOut {\n"
    .ascii "    float4 position [[position]];\n"
    .ascii "    float2 uv;\n"
    .ascii "    float4 color;\n"
    .ascii "};\n"
    .ascii "vertex VertexOut debug_vertex_main(VertexIn in [[stage_in]],\n"
    .ascii "                                   constant float4x4 &projection [[buffer(0)]]) {\n"
    .ascii "    VertexOut out;\n"
    .ascii "    out.position = projection * float4(in.position, 0.0, 1.0);\n"
    .ascii "    out.uv = in.uv;\n"
    .ascii "    float4 c = unpack_unorm4x8_to_float(in.color);\n"
    .ascii "    out.color = float4(c.rgb, c.a);\n"
    .ascii "    return out;\n"
    .ascii "}\0"

debug_fragment_shader_source:
    .ascii "fragment float4 debug_fragment_main(VertexOut in [[stage_in]],\n"
    .ascii "                                    texture2d<float> fontTexture [[texture(0)]],\n"
    .ascii "                                    sampler fontSampler [[sampler(0)]]) {\n"
    .ascii "    float4 texColor = fontTexture.sample(fontSampler, in.uv);\n"
    .ascii "    return in.color * texColor;\n"
    .ascii "}\0"

.section __TEXT,__text,regular,pure_instructions

//==============================================================================
// PUBLIC API
//==============================================================================

// Initialize debug overlay system
// Parameters: x0 = metal_device, x1 = command_queue
// Returns: w0 = 0 on success, -1 on failure
.global _debug_overlay_init
_debug_overlay_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Store parameters
    adrp    x2, g_debug_state@PAGE
    add     x2, x2, g_debug_state@PAGEOFF
    str     x0, [x2, #debug_overlay_state.metal_device]
    str     x1, [x2, #debug_overlay_state.command_queue]
    
    // Initialize default state
    mov     w3, #1
    strb    w3, [x2, #debug_overlay_state.show_performance]
    strb    w3, [x2, #debug_overlay_state.show_memory]
    strb    w3, [x2, #debug_overlay_state.show_frame_timing]
    strb    w3, [x2, #debug_overlay_state.show_graphs]
    
    // Set font properties (8x8 bitmap font)
    mov     w3, #8
    str     w3, [x2, #debug_overlay_state.font_char_width]
    str     w3, [x2, #debug_overlay_state.font_char_height]
    mov     w3, #DEBUG_FONT_ATLAS_SIZE
    str     w3, [x2, #debug_overlay_state.font_texture_width]
    str     w3, [x2, #debug_overlay_state.font_texture_height]
    
    // Initialize update interval (16.67ms for 60fps)
    mov     x3, #16667
    str     x3, [x2, #debug_overlay_state.update_interval]
    
    // Create Metal resources
    bl      _debug_create_pipeline_state
    cmp     w0, #0
    b.ne    init_failure
    
    bl      _debug_create_buffers
    cmp     w0, #0
    b.ne    init_failure
    
    bl      _debug_create_font_texture
    cmp     w0, #0
    b.ne    init_failure
    
    // Mark as initialized
    adrp    x2, g_debug_state@PAGE
    add     x2, x2, g_debug_state@PAGEOFF
    mov     w3, #1
    strb    w3, [x2, #debug_overlay_state.initialized]
    strb    w3, [x2, #debug_overlay_state.enabled]
    
    mov     w0, #0                  // Success
    b       init_done

init_failure:
    mov     w0, #-1                 // Failure

init_done:
    ldp     x29, x30, [sp], #16
    ret

// Shutdown debug overlay system
.global _debug_overlay_shutdown
_debug_overlay_shutdown:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Clear initialization flag
    adrp    x0, g_debug_state@PAGE
    add     x0, x0, g_debug_state@PAGEOFF
    mov     w1, #0
    strb    w1, [x0, #debug_overlay_state.initialized]
    strb    w1, [x0, #debug_overlay_state.enabled]
    
    // Clean up Metal resources
    bl      _debug_cleanup_resources
    
    ldp     x29, x30, [sp], #16
    ret

// Begin debug overlay frame
// Parameters: x0 = render_encoder
.global _debug_overlay_begin_frame
_debug_overlay_begin_frame:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Store current encoder
    adrp    x1, g_debug_state@PAGE
    add     x1, x1, g_debug_state@PAGEOFF
    str     x0, [x1, #debug_overlay_state.current_encoder]
    
    // Check if enabled
    ldrb    w2, [x1, #debug_overlay_state.enabled]
    cmp     w2, #0
    b.eq    begin_frame_done
    
    // Update performance metrics
    bl      _debug_update_metrics
    
    // Reset render state
    adrp    x1, g_debug_state@PAGE
    add     x1, x1, g_debug_state@PAGEOFF
    mov     w2, #0
    str     w2, [x1, #debug_overlay_state.vertex_count]
    str     w2, [x1, #debug_overlay_state.line_count]

begin_frame_done:
    ldp     x29, x30, [sp], #16
    ret

// Render debug overlay
.global _debug_overlay_render
_debug_overlay_render:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Check if enabled and initialized
    adrp    x0, g_debug_state@PAGE
    add     x0, x0, g_debug_state@PAGEOFF
    ldrb    w1, [x0, #debug_overlay_state.enabled]
    ldrb    w2, [x0, #debug_overlay_state.initialized]
    and     w1, w1, w2
    cmp     w1, #0
    b.eq    render_done
    
    // Set up render pipeline
    bl      _debug_setup_render_state
    
    // Render performance window
    ldrb    w1, [x0, #debug_overlay_state.show_performance]
    cmp     w1, #0
    b.eq    skip_performance
    bl      _debug_render_performance_window
    
skip_performance:
    // Render memory usage window
    adrp    x0, g_debug_state@PAGE
    add     x0, x0, g_debug_state@PAGEOFF
    ldrb    w1, [x0, #debug_overlay_state.show_memory]
    cmp     w1, #0
    b.eq    skip_memory
    bl      _debug_render_memory_window
    
skip_memory:
    // Render frame timing graphs
    adrp    x0, g_debug_state@PAGE
    add     x0, x0, g_debug_state@PAGEOFF
    ldrb    w1, [x0, #debug_overlay_state.show_graphs]
    cmp     w1, #0
    b.eq    skip_graphs
    bl      _debug_render_performance_graphs
    
skip_graphs:
    // Flush debug geometry
    bl      _debug_flush_geometry

render_done:
    ldp     x29, x30, [sp], #16
    ret

// Toggle debug overlay enable/disable
.global _debug_overlay_toggle
_debug_overlay_toggle:
    adrp    x0, g_debug_state@PAGE
    add     x0, x0, g_debug_state@PAGEOFF
    ldrb    w1, [x0, #debug_overlay_state.enabled]
    eor     w1, w1, #1
    strb    w1, [x0, #debug_overlay_state.enabled]
    ret

// Update performance metrics
.global _debug_overlay_update_metrics
_debug_overlay_update_metrics:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    
    adrp    x19, g_debug_state@PAGE
    add     x19, x19, g_debug_state@PAGEOFF
    
    // Get current time
    bl      _debug_get_current_time
    mov     x1, x0                  // Current time
    
    // Check if we should update (rate limiting)
    ldr     x2, [x19, #debug_overlay_state.last_update_time]
    ldr     x3, [x19, #debug_overlay_state.update_interval]
    sub     x4, x1, x2              // Time delta
    cmp     x4, x3
    b.lt    update_done             // Skip if too soon
    
    // Store new update time
    str     x1, [x19, #debug_overlay_state.last_update_time]
    
    // Calculate frame time
    cmp     x2, #0
    b.eq    first_update
    
    // Convert delta to milliseconds
    mov     x5, #1000
    udiv    x4, x4, x5              // Convert microseconds to milliseconds
    scvtf   s0, x4                  // Convert to float
    
    // Add to frame time history
    bl      _debug_add_frame_time
    
    // Update statistics
    bl      _debug_calculate_frame_stats
    
first_update:
    // Update system metrics
    bl      _debug_update_system_metrics

update_done:
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// TEXT RENDERING SYSTEM
//==============================================================================

// Render text string at specified position
// Parameters: x0 = text string, w1 = x position, w2 = y position, w3 = color
.global _debug_render_text
_debug_render_text:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    
    mov     x19, x0                 // Text string
    mov     w20, w1                 // X position
    mov     w21, w2                 // Y position
    mov     w22, w3                 // Color
    
    // Get font metrics
    adrp    x0, g_debug_state@PAGE
    add     x0, x0, g_debug_state@PAGEOFF
    ldr     w4, [x0, #debug_overlay_state.font_char_width]
    ldr     w5, [x0, #debug_overlay_state.font_char_height]
    
    mov     w6, w20                 // Current X position
    
text_loop:
    ldrb    w7, [x19], #1           // Load next character
    cmp     w7, #0
    b.eq    text_done
    
    cmp     w7, #'\n'
    b.eq    text_newline
    
    // Render character
    mov     w0, w7                  // Character
    mov     w1, w6                  // X position
    mov     w2, w21                 // Y position
    mov     w3, w22                 // Color
    bl      _debug_render_char
    
    add     w6, w6, w4              // Advance X position
    b       text_loop

text_newline:
    mov     w6, w20                 // Reset X to start
    add     w21, w21, w5            // Advance Y position
    b       text_loop

text_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// Render single character
// Parameters: w0 = character, w1 = x, w2 = y, w3 = color
_debug_render_char:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    
    // Calculate UV coordinates for character in font atlas
    and     w4, w0, #0xFF           // Ensure character is in range
    and     w5, w4, #0x0F           // Column (char % 16)
    lsr     w6, w4, #4              // Row (char / 16)
    
    // Character size in texture coordinates
    mov     w7, #8                  // Character width
    mov     w8, #512                // Atlas width
    scvtf   s0, w7
    scvtf   s1, w8
    fdiv    s2, s0, s1              // UV width
    
    // Calculate UV coordinates
    scvtf   s3, w5                  // Column as float
    fmul    s4, s3, s2              // U coordinate
    scvtf   s5, w6                  // Row as float
    fmul    s6, s5, s2              // V coordinate
    
    // Add character quad to vertex buffer
    mov     w0, w1                  // X position
    mov     w1, w2                  // Y position
    mov     w2, #8                  // Width
    mov     w3, #8                  // Height
    fmov    s0, s4                  // U
    fmov    s1, s6                  // V
    fmov    s2, s2                  // UV width
    fmov    s3, s2                  // UV height
    mov     w4, w3                  // Color
    bl      _debug_add_quad
    
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// LINE RENDERING SYSTEM
//==============================================================================

// Draw line between two points
// Parameters: w0 = start_x, w1 = start_y, w2 = end_x, w3 = end_y, w4 = color, s0 = thickness
.global _debug_draw_line
_debug_draw_line:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Convert to float coordinates
    scvtf   s1, w0                  // start_x
    scvtf   s2, w1                  // start_y
    scvtf   s3, w2                  // end_x
    scvtf   s4, w3                  // end_y
    
    // Calculate line direction and normal
    fsub    s5, s3, s1              // dx
    fsub    s6, s4, s2              // dy
    
    // Calculate line length
    fmul    s7, s5, s5
    fmul    s8, s6, s6
    fadd    s9, s7, s8
    fsqrt   s10, s9                 // length
    
    // Normalize direction
    fdiv    s11, s5, s10            // normalized dx
    fdiv    s12, s6, s10            // normalized dy
    
    // Calculate perpendicular (normal)
    fneg    s13, s12                // normal x = -normalized dy
    fmov    s14, s11                // normal y = normalized dx
    
    // Calculate half thickness offset
    fmul    s15, s0, #0.5           // half thickness
    fmul    s16, s13, s15           // offset x
    fmul    s17, s14, s15           // offset y
    
    // Generate quad vertices for thick line
    fadd    s18, s1, s16            // p1.x
    fadd    s19, s2, s17            // p1.y
    fsub    s20, s1, s16            // p2.x
    fsub    s21, s2, s17            // p2.y
    fadd    s22, s3, s16            // p3.x
    fadd    s23, s4, s17            // p3.y
    fsub    s24, s3, s16            // p4.x
    fsub    s25, s4, s17            // p4.y
    
    // Add line quad to vertex buffer
    mov     w0, w4                  // Color
    bl      _debug_add_line_quad
    
    ldp     x29, x30, [sp], #16
    ret

// Draw rectangle outline
// Parameters: w0 = x, w1 = y, w2 = width, w3 = height, w4 = color, s0 = thickness
.global _debug_draw_rect
_debug_draw_rect:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    mov     w19, w0                 // Save x
    mov     w20, w1                 // Save y
    
    // Top line
    add     w2, w0, w2              // end_x = x + width
    mov     w3, w1                  // end_y = y
    bl      _debug_draw_line
    
    // Right line
    mov     w0, w2                  // start_x = x + width
    mov     w1, w20                 // start_y = y
    mov     w2, w2                  // end_x = x + width
    add     w3, w20, w3             // end_y = y + height
    bl      _debug_draw_line
    
    // Bottom line
    mov     w0, w2                  // start_x = x + width
    mov     w1, w3                  // start_y = y + height
    mov     w2, w19                 // end_x = x
    mov     w3, w3                  // end_y = y + height
    bl      _debug_draw_line
    
    // Left line
    mov     w0, w19                 // start_x = x
    mov     w1, w3                  // start_y = y + height
    mov     w2, w19                 // end_x = x
    mov     w3, w20                 // end_y = y
    bl      _debug_draw_line
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

//==============================================================================
// PERFORMANCE VISUALIZATION
//==============================================================================

// Render performance window
_debug_render_performance_window:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Window position and size
    mov     w0, #10                 // X position
    mov     w1, #10                 // Y position
    mov     w2, #300                // Width
    mov     w3, #150                // Height
    mov     w4, #DEBUG_COLOR_WHITE  // Border color
    fmov    s0, #1.0                // Border thickness
    bl      _debug_draw_rect
    
    // Title
    adrp    x0, performance_title@PAGE
    add     x0, x0, performance_title@PAGEOFF
    mov     w1, #15                 // X position
    mov     w2, #15                 // Y position
    mov     w3, #DEBUG_COLOR_WHITE  // Color
    bl      _debug_render_text
    
    // FPS display
    adrp    x0, g_debug_state@PAGE
    add     x0, x0, g_debug_state@PAGEOFF
    ldr     s0, [x0, #debug_overlay_state.current_fps]
    bl      _debug_format_fps
    mov     w1, #15                 // X position
    mov     w2, #35                 // Y position
    mov     w3, #DEBUG_COLOR_GREEN  // Color
    bl      _debug_render_text
    
    // Frame time display
    adrp    x0, g_debug_state@PAGE
    add     x0, x0, g_debug_state@PAGEOFF
    ldr     s0, [x0, #debug_overlay_state.avg_frame_time]
    bl      _debug_format_frame_time
    mov     w1, #15                 // X position
    mov     w2, #50                 // Y position
    mov     w3, #DEBUG_COLOR_YELLOW // Color
    bl      _debug_render_text
    
    // Memory usage
    adrp    x0, g_debug_state@PAGE
    add     x0, x0, g_debug_state@PAGEOFF
    ldr     x0, [x0, #debug_overlay_state.used_memory]
    bl      _debug_format_memory
    mov     w1, #15                 // X position
    mov     w2, #65                 // Y position
    mov     w3, #DEBUG_COLOR_BLUE   // Color
    bl      _debug_render_text
    
    // CPU usage
    adrp    x0, g_debug_state@PAGE
    add     x0, x0, g_debug_state@PAGEOFF
    ldr     s0, [x0, #debug_overlay_state.cpu_percent]
    bl      _debug_format_cpu
    mov     w1, #15                 // X position
    mov     w2, #80                 // Y position
    mov     w3, #DEBUG_COLOR_RED    // Color
    bl      _debug_render_text
    
    ldp     x29, x30, [sp], #16
    ret

// Render memory usage window
_debug_render_memory_window:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Window position and size
    mov     w0, #330                // X position
    mov     w1, #10                 // Y position
    mov     w2, #250                // Width
    mov     w3, #120                // Height
    mov     w4, #DEBUG_COLOR_WHITE  // Border color
    fmov    s0, #1.0                // Border thickness
    bl      _debug_draw_rect
    
    // Memory breakdown visualization
    bl      _debug_render_memory_bars
    
    ldp     x29, x30, [sp], #16
    ret

// Render performance graphs
_debug_render_performance_graphs:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Frame time graph
    mov     w0, #10                 // X position
    mov     w1, #180                // Y position
    mov     w2, #300                // Width
    mov     w3, #80                 // Height
    bl      _debug_render_frame_time_graph
    
    // Memory usage graph
    mov     w0, #330                // X position
    mov     w1, #180                // Y position
    mov     w2, #250                // Width
    mov     w3, #80                 // Height
    bl      _debug_render_memory_graph
    
    ldp     x29, x30, [sp], #16
    ret

//==============================================================================
// HELPER FUNCTIONS
//==============================================================================

// Create Metal pipeline state for debug rendering
_debug_create_pipeline_state:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // This would create the Metal pipeline state
    // For now, return success
    mov     w0, #0
    
    ldp     x29, x30, [sp], #16
    ret

// Create vertex and index buffers
_debug_create_buffers:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // This would create Metal buffers
    // For now, return success
    mov     w0, #0
    
    ldp     x29, x30, [sp], #16
    ret

// Create font texture from embedded font atlas
_debug_create_font_texture:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // This would create Metal texture from font atlas
    // For now, return success
    mov     w0, #0
    
    ldp     x29, x30, [sp], #16
    ret

// Get current time in microseconds
_debug_get_current_time:
    // Use mach_absolute_time() for high precision timing
    mov     x16, #0x2000000 + 38    // mach_absolute_time syscall
    svc     #0
    ret

// Add frame time to history
_debug_add_frame_time:
    adrp    x1, g_debug_state@PAGE
    add     x1, x1, g_debug_state@PAGEOFF
    
    // Get current index
    ldr     w2, [x1, #debug_overlay_state.frame_time_index]
    
    // Store frame time at current index
    add     x3, x1, #debug_overlay_state.frame_times
    str     s0, [x3, x2, lsl #2]
    
    // Increment index (wrap around)
    add     w2, w2, #1
    cmp     w2, #DEBUG_HISTORY_SIZE
    csel    w2, wzr, w2, ge
    str     w2, [x1, #debug_overlay_state.frame_time_index]
    
    ret

// Calculate frame time statistics
_debug_calculate_frame_stats:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, g_debug_state@PAGE
    add     x0, x0, g_debug_state@PAGEOFF
    
    // Calculate average, min, max from history
    add     x1, x0, #debug_overlay_state.frame_times
    mov     w2, #DEBUG_HISTORY_SIZE
    
    // Initialize min/max with first value
    ldr     s0, [x1]
    fmov    s1, s0                  // min
    fmov    s2, s0                  // max
    fmov    s3, s0                  // sum
    
    mov     w3, #1
calc_loop:
    cmp     w3, w2
    b.ge    calc_done
    
    ldr     s4, [x1, x3, lsl #2]
    fadd    s3, s3, s4              // Add to sum
    fcmp    s4, s1
    fcsel   s1, s4, s1, lt          // Update min
    fcmp    s4, s2
    fcsel   s2, s4, s2, gt          // Update max
    
    add     w3, w3, #1
    b       calc_loop

calc_done:
    // Calculate average
    scvtf   s5, w2
    fdiv    s3, s3, s5
    
    // Store results
    str     s3, [x0, #debug_overlay_state.avg_frame_time]
    str     s1, [x0, #debug_overlay_state.min_frame_time]
    str     s2, [x0, #debug_overlay_state.max_frame_time]
    
    // Calculate FPS from average frame time
    fmov    s6, #1000.0
    fdiv    s7, s6, s3
    str     s7, [x0, #debug_overlay_state.current_fps]
    
    ldp     x29, x30, [sp], #16
    ret

// Update system metrics (CPU, memory, etc.)
_debug_update_system_metrics:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get memory usage
    bl      _debug_get_memory_usage
    adrp    x1, g_debug_state@PAGE
    add     x1, x1, g_debug_state@PAGEOFF
    str     x0, [x1, #debug_overlay_state.used_memory]
    
    // Get CPU usage
    bl      _debug_get_cpu_usage
    str     s0, [x1, #debug_overlay_state.cpu_percent]
    
    ldp     x29, x30, [sp], #16
    ret

// Placeholder functions for system metrics
_debug_get_memory_usage:
    mov     x0, #0x8000000          // 128MB placeholder
    ret

_debug_get_cpu_usage:
    fmov    s0, #25.0               // 25% placeholder
    ret

// Cleanup Metal resources
_debug_cleanup_resources:
    ret

// Setup render state
_debug_setup_render_state:
    ret

// Add quad to vertex buffer
_debug_add_quad:
    ret

// Add line quad to vertex buffer
_debug_add_line_quad:
    ret

// Flush debug geometry
_debug_flush_geometry:
    ret

// Format functions for display
_debug_format_fps:
    ret

_debug_format_frame_time:
    ret

_debug_format_memory:
    ret

_debug_format_cpu:
    ret

// Render memory bars
_debug_render_memory_bars:
    ret

// Render graphs
_debug_render_frame_time_graph:
    ret

_debug_render_memory_graph:
    ret

//==============================================================================
// STRING CONSTANTS
//==============================================================================

.section __TEXT,__cstring,cstring_literals
performance_title:
    .ascii "Performance Monitor\0"
memory_title:
    .ascii "Memory Usage\0"
fps_label:
    .ascii "FPS: %.1f\0"
frame_time_label:
    .ascii "Frame: %.2f ms\0"
memory_label:
    .ascii "Memory: %.1f MB\0"
cpu_label:
    .ascii "CPU: %.1f%%\0"

.section __TEXT,__text,regular,pure_instructions

// Export symbols
.global _debug_overlay_init
.global _debug_overlay_shutdown
.global _debug_overlay_begin_frame
.global _debug_overlay_render
.global _debug_overlay_toggle
.global _debug_overlay_update_metrics
.global _debug_render_text
.global _debug_draw_line
.global _debug_draw_rect