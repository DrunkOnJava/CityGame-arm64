// Metal texture loading
.global load_texture_from_file
.global create_texture_descriptor
.align 4

.section __DATA,__const
texture_descriptor_class:
    .asciz "MTLTextureDescriptor"
alloc_selector:
    .asciz "alloc"
init_selector:
    .asciz "init"
new_texture_selector:
    .asciz "newTextureWithDescriptor:"
set_width_selector:
    .asciz "setWidth:"
set_height_selector:
    .asciz "setHeight:"
set_pixel_format_selector:
    .asciz "setPixelFormat:"
set_usage_selector:
    .asciz "setUsage:"

.section __TEXT,__text
load_texture_from_file:
    // x0 = filepath
    // Returns texture object in x0
    
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov x19, x0  // Save filepath
    
    // Load image data from file
    bl load_image_data
    cbz x0, .load_texture_failed
    mov x20, x0  // Save image data
    
    // Create texture descriptor
    mov w0, #256  // width
    mov w1, #256  // height
    bl create_texture_descriptor
    cbz x0, .load_texture_failed
    
    // Get Metal device
    adrp x1, metal_context@PAGE
    add x1, x1, metal_context@PAGEOFF
    ldr x1, [x1]  // device
    
    // Create texture
    mov x2, x0    // descriptor
    mov x0, x1    // device
    mov x1, x2    // descriptor
    adrp x2, new_texture_selector@PAGE
    add x2, x2, new_texture_selector@PAGEOFF
    bl _objc_msgSend
    
    // TODO: Upload image data to texture
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

.load_texture_failed:
    mov x0, #0
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

create_texture_descriptor:
    // w0 = width
    // w1 = height
    // Returns texture descriptor in x0
    
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov w19, w0  // Save width
    mov w20, w1  // Save height
    
    // Get MTLTextureDescriptor class
    adrp x0, texture_descriptor_class@PAGE
    add x0, x0, texture_descriptor_class@PAGEOFF
    bl _objc_getClass
    
    // Alloc and init
    mov x1, x0
    adrp x0, alloc_selector@PAGE
    add x0, x0, alloc_selector@PAGEOFF
    bl _objc_msgSend
    
    mov x1, x0
    adrp x0, init_selector@PAGE
    add x0, x0, init_selector@PAGEOFF
    bl _objc_msgSend
    mov x21, x0  // Save descriptor
    
    // Set width
    mov x1, x21
    adrp x0, set_width_selector@PAGE
    add x0, x0, set_width_selector@PAGEOFF
    mov x2, x19  // width
    bl _objc_msgSend
    
    // Set height
    mov x1, x21
    adrp x0, set_height_selector@PAGE
    add x0, x0, set_height_selector@PAGEOFF
    mov x2, x20  // height
    bl _objc_msgSend
    
    // Set pixel format (BGRA8Unorm = 80)
    mov x1, x21
    adrp x0, set_pixel_format_selector@PAGE
    add x0, x0, set_pixel_format_selector@PAGEOFF
    mov x2, #80  // MTLPixelFormatBGRA8Unorm
    bl _objc_msgSend
    
    // Set usage (ShaderRead = 1)
    mov x1, x21
    adrp x0, set_usage_selector@PAGE
    add x0, x0, set_usage_selector@PAGEOFF
    mov x2, #1   // MTLTextureUsageShaderRead
    bl _objc_msgSend
    
    mov x0, x21  // Return descriptor
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

load_image_data:
    // x0 = filepath
    // Returns image data pointer in x0, size in x1
    
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // TODO: Implement PNG/JPEG loading
    // For now, return null
    mov x0, #0
    mov x1, #0
    
    ldp x29, x30, [sp], #16
    ret