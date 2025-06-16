// Metal initialization for SimCity ARM64
.global metal_init
.global metal_create_device
.global metal_create_command_queue
.align 4

.section __DATA,__const
device_selector:
    .asciz "MTLCreateSystemDefaultDevice"
queue_selector:
    .asciz "newCommandQueue"
library_selector:
    .asciz "newDefaultLibrary"

.section __TEXT,__text
metal_init:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    // Create Metal device
    bl metal_create_device
    cbz x0, .metal_init_failed
    mov x19, x0  // Save device
    
    // Create command queue
    mov x0, x19
    bl metal_create_command_queue
    cbz x0, .metal_init_failed
    mov x20, x0  // Save command queue
    
    // Store in global context
    adrp x0, metal_context@PAGE
    add x0, x0, metal_context@PAGEOFF
    stp x19, x20, [x0]      // device, queue
    str xzr, [x0, #16]      // library (to be set later)
    str xzr, [x0, #24]      // reserved
    
    mov x0, #1  // Success
    b .metal_init_done
    
.metal_init_failed:
    mov x0, #0  // Failure
    
.metal_init_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

metal_create_device:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Call MTLCreateSystemDefaultDevice()
    // This is a C function that returns an id<MTLDevice>
    bl _MTLCreateSystemDefaultDevice
    
    ldp x29, x30, [sp], #16
    ret

metal_create_command_queue:
    // x0 = device
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    mov x1, x0  // device becomes self
    adrp x0, queue_selector@PAGE
    add x0, x0, queue_selector@PAGEOFF
    bl _objc_msgSend
    
    ldp x29, x30, [sp], #16
    ret

.section __DATA,__bss
.global metal_context
metal_context:
    .space 32  // device, queue, library, reserved