.global load_shader_library
.global create_shader_library_from_source
.align 4

.section __DATA,__const
shader_source:
    .asciz "#include <metal_stdlib>\nusing namespace metal;\n\nstruct VertexIn {\n    float2 position [[attribute(0)]];\n    float2 texCoord [[attribute(1)]];\n};\n\nstruct VertexOut {\n    float4 position [[position]];\n    float2 texCoord;\n    float depth;\n};\n\nstruct Uniforms {\n    float4x4 viewProjectionMatrix;\n    float2 tilePosition;\n    float elevation;\n};\n\nvertex VertexOut isometric_vertex(\n    VertexIn in [[stage_in]],\n    constant Uniforms& uniforms [[buffer(0)]],\n    uint instanceID [[instance_id]]\n) {\n    VertexOut out;\n    \n    // Convert to isometric coordinates\n    float2 isoPos;\n    isoPos.x = (uniforms.tilePosition.x - uniforms.tilePosition.y) * 32.0;\n    isoPos.y = (uniforms.tilePosition.x + uniforms.tilePosition.y) * 16.0;\n    isoPos.y -= uniforms.elevation * 8.0;\n    \n    // Apply vertex position\n    float4 worldPos = float4(isoPos + in.position, 0.0, 1.0);\n    out.position = uniforms.viewProjectionMatrix * worldPos;\n    out.texCoord = in.texCoord;\n    \n    // Calculate depth for sorting\n    out.depth = uniforms.tilePosition.x + uniforms.tilePosition.y + uniforms.elevation;\n    \n    return out;\n}\n\nfragment float4 isometric_fragment(\n    VertexOut in [[stage_in]],\n    texture2d<float> atlas [[texture(0)]],\n    sampler atlasSampler [[sampler(0)]]\n) {\n    float4 color = atlas.sample(atlasSampler, in.texCoord);\n    \n    // Apply fog based on depth\n    float fogFactor = saturate(in.depth / 100.0);\n    float3 fogColor = float3(0.8, 0.85, 0.9);\n    color.rgb = mix(color.rgb, fogColor, fogFactor * 0.3);\n    \n    return color;\n}"

nsstring_class:
    .asciz "NSString"
string_with_cstring_selector:
    .asciz "stringWithCString:encoding:"
new_library_selector:
    .asciz "newLibraryWithSource:options:error:"

.section __TEXT,__text
load_shader_library:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Create shader library from embedded source
    bl create_shader_library_from_source
    
    ldp x29, x30, [sp], #16
    ret

create_shader_library_from_source:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    // Get Metal device
    adrp x19, metal_context@PAGE
    add x19, x19, metal_context@PAGEOFF
    ldr x19, [x19]  // device
    cbz x19, .create_library_failed
    
    // Create NSString from shader source
    adrp x0, nsstring_class@PAGE
    add x0, x0, nsstring_class@PAGEOFF
    bl _objc_getClass
    
    mov x1, x0
    adrp x0, string_with_cstring_selector@PAGE
    add x0, x0, string_with_cstring_selector@PAGEOFF
    adrp x2, shader_source@PAGE
    add x2, x2, shader_source@PAGEOFF
    mov x3, #4  // NSUTF8StringEncoding
    bl _objc_msgSend
    mov x20, x0  // Save NSString
    
    // Create library from source
    mov x1, x19  // device
    adrp x0, new_library_selector@PAGE
    add x0, x0, new_library_selector@PAGEOFF
    mov x2, x20  // source string
    mov x3, #0   // options (nil)
    mov x4, #0   // error (nil)
    bl _objc_msgSend
    
    // x0 now contains the library
    cbz x0, .create_library_failed
    
    // Store library in metal context
    adrp x1, metal_context@PAGE
    add x1, x1, metal_context@PAGEOFF
    str x0, [x1, #16]  // Store in library slot
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

.create_library_failed:
    mov x0, #0
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret