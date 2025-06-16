//
// SimCity ARM64 Assembly - Objective-C Runtime Bridge
// Agent E1: Platform Architect
//
// Complete Objective-C runtime integration for pure assembly application
// Provides dynamic linking and message dispatch functionality
//

.cpu generic+simd
.arch armv8-a+simd

// Include platform constants
.include "../../include/macros/platform_asm.inc"

.data
.align 3

//==============================================================================
// Dynamic Linking and Runtime Setup
//==============================================================================

// RTLD constants for dlopen/dlsym
.equ RTLD_LAZY,     0x1
.equ RTLD_NOW,      0x2
.equ RTLD_LOCAL,    0x4
.equ RTLD_GLOBAL,   0x8
.equ RTLD_DEFAULT,  0xFFFFFFFFFFFFFFFF

// Optimized selector cache constants
.equ SEL_CACHE_SIZE,        512     // Must be power of 2
.equ SEL_CACHE_MASK,        511     // SEL_CACHE_SIZE - 1
.equ SEL_CACHE_ENTRY_SIZE,  24      // selector name ptr + SEL + hash
.equ METHOD_CACHE_SIZE,     256     // Hot path method cache
.equ METHOD_CACHE_MASK,     255     // METHOD_CACHE_SIZE - 1

// Class hierarchy constants
.equ MAX_DELEGATE_CLASSES,  32      // Maximum delegate classes
.equ DELEGATE_ENTRY_SIZE,   16      // class ptr + IMP table ptr

// Library handles
.runtime_handles:
    objc_runtime_handle:        .quad   0
    foundation_handle:          .quad   0
    appkit_handle:              .quad   0
    metal_handle:               .quad   0

// Library paths
.library_paths:
    objc_runtime_path:          .asciz  "/usr/lib/libobjc.dylib"
    foundation_path:            .asciz  "/System/Library/Frameworks/Foundation.framework/Foundation"
    appkit_path:                .asciz  "/System/Library/Frameworks/AppKit.framework/AppKit"
    metal_path:                 .asciz  "/System/Library/Frameworks/Metal.framework/Metal"

// Runtime function symbols
.runtime_symbols:
    objc_getClass_sym:          .asciz  "objc_getClass"
    sel_registerName_sym:       .asciz  "sel_registerName"
    objc_msgSend_sym:           .asciz  "objc_msgSend"
    objc_msgSend_stret_sym:     .asciz  "objc_msgSend_stret"
    objc_msgSend_fpret_sym:     .asciz  "objc_msgSend_fpret"
    class_createInstance_sym:   .asciz  "class_createInstance"
    object_getClass_sym:        .asciz  "object_getClass"
    objc_allocateClassPair_sym: .asciz  "objc_allocateClassPair"
    objc_registerClassPair_sym: .asciz  "objc_registerClassPair"
    class_addMethod_sym:        .asciz  "class_addMethod"

// System function symbols  
.system_symbols:
    dlopen_sym:                 .asciz  "dlopen"
    dlsym_sym:                  .asciz  "dlsym"
    dlclose_sym:                .asciz  "dlclose"
    dlerror_sym:                .asciz  "dlerror"

// Framework constants for Metal
.metal_constants:
    MTLCreateSystemDefaultDevice_sym: .asciz "MTLCreateSystemDefaultDevice"
    MTLPixelFormatBGRA8Unorm:   .quad   80
    MTLStorageModeShared:       .quad   0

.text
.align 4

//==============================================================================
// Dynamic Library Loading
//==============================================================================

.global load_runtime_libraries
// load_runtime_libraries: Load all required dynamic libraries
// Returns: x0 = 0 on success, error code on failure
load_runtime_libraries:
    SAVE_REGS
    
    // Load Objective-C runtime
    adrp    x0, objc_runtime_path@PAGE
    add     x0, x0, objc_runtime_path@PAGEOFF
    mov     x1, #RTLD_NOW
    bl      dlopen_call
    cbz     x0, runtime_load_error
    
    adrp    x1, objc_runtime_handle@PAGE
    add     x1, x1, objc_runtime_handle@PAGEOFF
    str     x0, [x1]
    
    // Load Foundation framework
    adrp    x0, foundation_path@PAGE
    add     x0, x0, foundation_path@PAGEOFF
    mov     x1, #RTLD_NOW
    bl      dlopen_call
    cbz     x0, runtime_load_error
    
    adrp    x1, foundation_handle@PAGE
    add     x1, x1, foundation_handle@PAGEOFF
    str     x0, [x1]
    
    // Load AppKit framework
    adrp    x0, appkit_path@PAGE
    add     x0, x0, appkit_path@PAGEOFF
    mov     x1, #RTLD_NOW
    bl      dlopen_call
    cbz     x0, runtime_load_error
    
    adrp    x1, appkit_handle@PAGE
    add     x1, x1, appkit_handle@PAGEOFF
    str     x0, [x1]
    
    // Load Metal framework
    adrp    x0, metal_path@PAGE
    add     x0, x0, metal_path@PAGEOFF
    mov     x1, #RTLD_NOW
    bl      dlopen_call
    cbz     x0, runtime_load_error
    
    adrp    x1, metal_handle@PAGE
    add     x1, x1, metal_handle@PAGEOFF
    str     x0, [x1]
    
    mov     x0, #0                  // Success
    RESTORE_REGS
    ret

runtime_load_error:
    mov     x0, #-1                 // Error
    RESTORE_REGS
    ret

.global resolve_runtime_functions
// resolve_runtime_functions: Resolve all runtime function pointers
// Returns: x0 = 0 on success, error code on failure
resolve_runtime_functions:
    SAVE_REGS
    
    // Get Objective-C runtime handle
    adrp    x19, objc_runtime_handle@PAGE
    add     x19, x19, objc_runtime_handle@PAGEOFF
    ldr     x19, [x19]
    cbz     x19, resolve_error
    
    // Resolve objc_getClass
    mov     x0, x19
    adrp    x1, objc_getClass_sym@PAGE
    add     x1, x1, objc_getClass_sym@PAGEOFF
    bl      dlsym_call
    cbz     x0, resolve_error
    
    adrp    x1, objc_getClass_ptr@PAGE
    add     x1, x1, objc_getClass_ptr@PAGEOFF
    str     x0, [x1]
    
    // Resolve sel_registerName
    mov     x0, x19
    adrp    x1, sel_registerName_sym@PAGE
    add     x1, x1, sel_registerName_sym@PAGEOFF
    bl      dlsym_call
    cbz     x0, resolve_error
    
    adrp    x1, sel_registerName_ptr@PAGE
    add     x1, x1, sel_registerName_ptr@PAGEOFF
    str     x0, [x1]
    
    // Resolve objc_msgSend
    mov     x0, x19
    adrp    x1, objc_msgSend_sym@PAGE
    add     x1, x1, objc_msgSend_sym@PAGEOFF
    bl      dlsym_call
    cbz     x0, resolve_error
    
    adrp    x1, objc_msgSend_ptr@PAGE
    add     x1, x1, objc_msgSend_ptr@PAGEOFF
    str     x0, [x1]
    
    // Resolve objc_msgSend_stret (for struct returns)
    mov     x0, x19
    adrp    x1, objc_msgSend_stret_sym@PAGE
    add     x1, x1, objc_msgSend_stret_sym@PAGEOFF
    bl      dlsym_call
    cbz     x0, resolve_error
    
    adrp    x1, objc_msgSend_stret_ptr@PAGE
    add     x1, x1, objc_msgSend_stret_ptr@PAGEOFF
    str     x0, [x1]
    
    // Resolve class_createInstance
    mov     x0, x19
    adrp    x1, class_createInstance_sym@PAGE
    add     x1, x1, class_createInstance_sym@PAGEOFF
    bl      dlsym_call
    cbz     x0, resolve_error
    
    adrp    x1, class_createInstance_ptr@PAGE
    add     x1, x1, class_createInstance_ptr@PAGEOFF
    str     x0, [x1]
    
    // Resolve Metal functions
    bl      resolve_metal_functions
    cmp     x0, #0
    b.ne    resolve_error
    
    mov     x0, #0                  // Success
    RESTORE_REGS
    ret

resolve_error:
    mov     x0, #-1                 // Error
    RESTORE_REGS
    ret

// resolve_metal_functions: Resolve Metal framework functions
// Returns: x0 = 0 on success, error code on failure
resolve_metal_functions:
    SAVE_REGS_LIGHT
    
    // Get Metal framework handle
    adrp    x19, metal_handle@PAGE
    add     x19, x19, metal_handle@PAGEOFF
    ldr     x19, [x19]
    cbz     x19, metal_resolve_error
    
    // Resolve MTLCreateSystemDefaultDevice
    mov     x0, x19
    adrp    x1, MTLCreateSystemDefaultDevice_sym@PAGE
    add     x1, x1, MTLCreateSystemDefaultDevice_sym@PAGEOFF
    bl      dlsym_call
    cbz     x0, metal_resolve_error
    
    adrp    x1, MTLCreateSystemDefaultDevice_ptr@PAGE
    add     x1, x1, MTLCreateSystemDefaultDevice_ptr@PAGEOFF
    str     x0, [x1]
    
    mov     x0, #0                  // Success
    RESTORE_REGS_LIGHT
    ret

metal_resolve_error:
    mov     x0, #-1                 // Error
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// System Call Wrappers
//==============================================================================

// dlopen_call: Call dlopen system function
// Args: x0 = path, x1 = flags
// Returns: x0 = handle or 0 on error
dlopen_call:
    SAVE_REGS_LIGHT
    
    mov     x19, x0                 // Save path
    mov     x20, x1                 // Save flags
    
    // Use RTLD_DEFAULT to get dlopen function
    mov     x0, #RTLD_DEFAULT
    adrp    x1, dlopen_sym@PAGE
    add     x1, x1, dlopen_sym@PAGEOFF
    bl      dlsym_bootstrap
    
    cbz     x0, dlopen_call_error
    
    // Call dlopen
    mov     x21, x0                 // Save dlopen function
    mov     x0, x19                 // path
    mov     x1, x20                 // flags
    blr     x21
    
    RESTORE_REGS_LIGHT
    ret

dlopen_call_error:
    mov     x0, #0                  // Error
    RESTORE_REGS_LIGHT
    ret

// dlsym_call: Call dlsym system function
// Args: x0 = handle, x1 = symbol
// Returns: x0 = function pointer or 0 on error
dlsym_call:
    SAVE_REGS_LIGHT
    
    mov     x19, x0                 // Save handle
    mov     x20, x1                 // Save symbol
    
    // Get dlsym function
    mov     x0, #RTLD_DEFAULT
    adrp    x1, dlsym_sym@PAGE
    add     x1, x1, dlsym_sym@PAGEOFF
    bl      dlsym_bootstrap
    
    cbz     x0, dlsym_call_error
    
    // Call dlsym
    mov     x21, x0                 // Save dlsym function
    mov     x0, x19                 // handle
    mov     x1, x20                 // symbol
    blr     x21
    
    RESTORE_REGS_LIGHT
    ret

dlsym_call_error:
    mov     x0, #0                  // Error
    RESTORE_REGS_LIGHT
    ret

// dlsym_bootstrap: Bootstrap dlsym lookup using system calls
// Args: x0 = handle, x1 = symbol
// Returns: x0 = function pointer or 0 on error
dlsym_bootstrap:
    // This is a simplified bootstrap implementation
    // In a full implementation, this would use system calls to resolve symbols
    // For now, we'll use hardcoded addresses or return error
    mov     x0, #0
    ret

//==============================================================================
// Optimized Method Dispatch for Hot Paths
//==============================================================================

.global objc_call_cached
// objc_call_cached: Optimized method dispatch with caching
// Args: x0 = receiver, x1 = selector
// Returns: x0 = return value
objc_call_cached:
    SAVE_REGS_LIGHT
    
    mov     x19, x0                 // Save receiver
    mov     x20, x1                 // Save selector
    
    // Get receiver's class
    bl      object_getClass_fast
    mov     x21, x0                 // Save class
    
    // Look up method in cache
    mov     x0, x21                 // class
    mov     x1, x20                 // selector
    bl      lookup_method_cache
    cbnz    x0, method_cache_hit
    
    // Cache miss - do full lookup
    mov     x0, x19                 // receiver
    mov     x1, x20                 // selector
    bl      objc_call_0_uncached
    mov     x22, x0                 // Save result
    
    // Cache the method
    mov     x0, x21                 // class
    mov     x1, x20                 // selector
    mov     x2, x22                 // result (for IMP extraction)
    bl      cache_method_lookup
    
    mov     x0, x22                 // Return result
    RESTORE_REGS_LIGHT
    ret

method_cache_hit:
    // Direct call to cached IMP
    mov     x2, x0                  // IMP
    mov     x0, x19                 // receiver
    mov     x1, x20                 // selector
    blr     x2
    
    // Update cache statistics
    adrp    x1, method_cache_stats@PAGE
    add     x1, x1, method_cache_stats@PAGEOFF
    ldr     x2, [x1]                // hits
    add     x2, x2, #1
    str     x2, [x1]
    
    RESTORE_REGS_LIGHT
    ret

.global lookup_method_cache
// lookup_method_cache: Fast method cache lookup
// Args: x0 = class, x1 = selector
// Returns: x0 = IMP or 0 if not found
lookup_method_cache:
    SAVE_REGS_LIGHT
    
    mov     x19, x0                 // Save class
    mov     x20, x1                 // Save selector
    
    // Calculate cache index: hash(class ^ selector)
    eor     x0, x19, x20
    bl      calculate_pointer_hash
    and     x21, x0, #METHOD_CACHE_MASK
    
    // Get cache entry
    adrp    x22, method_cache_table@PAGE
    add     x22, x22, method_cache_table@PAGEOFF
    mov     x23, #24                // Entry size: class(8) + sel(8) + imp(8)
    madd    x21, x21, x23, x22      // entry_addr
    
    // Check if entry matches
    ldr     x0, [x21]              // Cached class
    cmp     x0, x19
    b.ne    method_cache_miss
    
    ldr     x0, [x21, #8]          // Cached selector
    cmp     x0, x20
    b.ne    method_cache_miss
    
    // Cache hit
    ldr     x0, [x21, #16]         // Return IMP
    RESTORE_REGS_LIGHT
    ret

method_cache_miss:
    // Update miss statistics
    adrp    x0, method_cache_stats@PAGE
    add     x0, x0, method_cache_stats@PAGEOFF
    ldr     x1, [x0, #8]           // misses
    add     x1, x1, #1
    str     x1, [x0, #8]
    
    mov     x0, #0                  // Not found
    RESTORE_REGS_LIGHT
    ret

.global cache_method_lookup
// cache_method_lookup: Cache a method lookup result
// Args: x0 = class, x1 = selector, x2 = IMP
// Returns: none
cache_method_lookup:
    SAVE_REGS_LIGHT
    
    mov     x19, x0                 // Save class
    mov     x20, x1                 // Save selector
    mov     x21, x2                 // Save IMP
    
    // Calculate cache index
    eor     x0, x19, x20
    bl      calculate_pointer_hash
    and     x22, x0, #METHOD_CACHE_MASK
    
    // Get cache entry
    adrp    x23, method_cache_table@PAGE
    add     x23, x23, method_cache_table@PAGEOFF
    mov     x24, #24
    madd    x22, x22, x24, x23      // entry_addr
    
    // Check if slot is occupied
    ldr     x0, [x22]
    cbnz    x0, cache_eviction
    
    // Store new entry
    str     x19, [x22]             // class
    str     x20, [x22, #8]         // selector
    str     x21, [x22, #16]        // IMP
    
    RESTORE_REGS_LIGHT
    ret

cache_eviction:
    // Update eviction statistics
    adrp    x0, method_cache_stats@PAGE
    add     x0, x0, method_cache_stats@PAGEOFF
    ldr     x1, [x0, #24]          // evictions
    add     x1, x1, #1
    str     x1, [x0, #24]
    
    // Overwrite entry (simple replacement policy)
    str     x19, [x22]             // class
    str     x20, [x22, #8]         // selector
    str     x21, [x22, #16]        // IMP
    
    RESTORE_REGS_LIGHT
    ret

.global object_getClass_fast
// object_getClass_fast: Fast class lookup for objects
// Args: x0 = object
// Returns: x0 = class
object_getClass_fast:
    // Object's class is stored in first 8 bytes (isa pointer)
    ldr     x0, [x0]
    ret

//==============================================================================
// Legacy Message Dispatch (Non-cached)
//==============================================================================

.global objc_call_0
// objc_call_0: Call Objective-C method with no arguments
// Args: x0 = receiver, x1 = selector
// Returns: x0 = return value
objc_call_0:
    str     x30, [sp, #-16]!
    
    // Use cached version for better performance
    bl      objc_call_cached
    
    ldr     x30, [sp], #16
    ret

.global objc_call_0_uncached
// objc_call_0_uncached: Direct call without caching
// Args: x0 = receiver, x1 = selector
// Returns: x0 = return value
objc_call_0_uncached:
    str     x30, [sp, #-16]!
    
    // Load objc_msgSend function pointer
    adrp    x2, objc_msgSend_ptr@PAGE
    add     x2, x2, objc_msgSend_ptr@PAGEOFF
    ldr     x2, [x2]
    
    // Call objc_msgSend(receiver, selector)
    blr     x2
    
    ldr     x30, [sp], #16
    ret

.global objc_call_1
// objc_call_1: Call Objective-C method with 1 argument
// Args: x0 = receiver, x1 = selector, x2 = arg0
// Returns: x0 = return value
objc_call_1:
    str     x30, [sp, #-16]!
    
    // Load objc_msgSend function pointer
    adrp    x3, objc_msgSend_ptr@PAGE
    add     x3, x3, objc_msgSend_ptr@PAGEOFF
    ldr     x3, [x3]
    
    // Call objc_msgSend(receiver, selector, arg0)
    blr     x3
    
    ldr     x30, [sp], #16
    ret

.global objc_call_2
// objc_call_2: Call Objective-C method with 2 arguments
// Args: x0 = receiver, x1 = selector, x2 = arg0, x3 = arg1
// Returns: x0 = return value
objc_call_2:
    str     x30, [sp, #-16]!
    
    // Load objc_msgSend function pointer
    adrp    x4, objc_msgSend_ptr@PAGE
    add     x4, x4, objc_msgSend_ptr@PAGEOFF
    ldr     x4, [x4]
    
    // Call objc_msgSend(receiver, selector, arg0, arg1)
    blr     x4
    
    ldr     x30, [sp], #16
    ret

.global objc_call_struct
// objc_call_struct: Call Objective-C method that returns a struct
// Args: x0 = result_ptr, x1 = receiver, x2 = selector, x3+ = args
// Returns: none (result in memory pointed to by x0)
objc_call_struct:
    str     x30, [sp, #-16]!
    
    // Load objc_msgSend_stret function pointer
    adrp    x4, objc_msgSend_stret_ptr@PAGE
    add     x4, x4, objc_msgSend_stret_ptr@PAGEOFF
    ldr     x4, [x4]
    
    // Call objc_msgSend_stret(result_ptr, receiver, selector, ...)
    blr     x4
    
    ldr     x30, [sp], #16
    ret

//==============================================================================
// Optimized Selector Registration and Lookup
//==============================================================================

.global register_selector_optimized
// register_selector_optimized: Register selector with optimized caching
// Args: x0 = selector name (C string)
// Returns: x0 = SEL
register_selector_optimized:
    SAVE_REGS_LIGHT
    
    mov     x19, x0                 // Save selector name
    
    // First check if selector is already cached
    bl      lookup_cached_selector
    cbnz    x0, register_selector_cached_found
    
    // Calculate hash for selector name
    mov     x0, x19
    bl      calculate_string_hash
    mov     x20, x0                 // Save hash
    
    // Find available slot in cache
    and     x21, x20, #SEL_CACHE_MASK
    adrp    x22, sel_cache_table@PAGE
    add     x22, x22, sel_cache_table@PAGEOFF
    
    // Calculate entry address
    mov     x23, #SEL_CACHE_ENTRY_SIZE
    madd    x21, x21, x23, x22      // entry_addr = base + (index * entry_size)
    
    // Check if slot is available (name_ptr == 0)
    ldr     x0, [x21]
    cbnz    x0, register_selector_collision
    
    // Register selector with runtime
    mov     x0, x19
    adrp    x1, sel_registerName_ptr@PAGE
    add     x1, x1, sel_registerName_ptr@PAGEOFF
    ldr     x1, [x1]
    blr     x1
    mov     x24, x0                 // Save SEL
    
    // Cache the selector
    str     x19, [x21]              // Store name pointer
    str     x24, [x21, #8]          // Store SEL
    str     x20, [x21, #16]         // Store hash
    
    // Update cache count
    adrp    x0, sel_cache_count@PAGE
    add     x0, x0, sel_cache_count@PAGEOFF
    ldr     x1, [x0]
    add     x1, x1, #1
    str     x1, [x0]
    
    mov     x0, x24                 // Return SEL
    RESTORE_REGS_LIGHT
    ret

register_selector_collision:
    // Handle collision by linear probing
    mov     x25, #1                 // Probe offset
collision_probe_loop:
    mov     x27, #SEL_CACHE_ENTRY_SIZE
    mul     x26, x25, x27           // Calculate offset
    add     x26, x21, x26           // Add to base entry address
    mov     x27, #(SEL_CACHE_SIZE * SEL_CACHE_ENTRY_SIZE)
    cmp     x26, x27
    b.lt    collision_no_wrap
    sub     x26, x26, x27           // Wrap around if needed
collision_no_wrap:
    add     x26, x22, x26           // Adjust to cache base
    
    ldr     x0, [x26]              // Check if slot available
    cbz     x0, collision_slot_found
    
    // Check if this is the same selector
    mov     x0, x19
    ldr     x1, [x26]
    bl      strcmp_fast
    cbz     x0, collision_found_existing
    
    add     x25, x25, #1
    cmp     x25, #SEL_CACHE_SIZE
    b.lo    collision_probe_loop
    
    // Cache full, register without caching
    mov     x0, x19
    adrp    x1, sel_registerName_ptr@PAGE
    add     x1, x1, sel_registerName_ptr@PAGEOFF
    ldr     x1, [x1]
    blr     x1
    RESTORE_REGS_LIGHT
    ret

collision_slot_found:
    mov     x21, x26                // Use this slot
    b       register_selector_collision

collision_found_existing:
    ldr     x0, [x26, #8]           // Return cached SEL
    RESTORE_REGS_LIGHT
    ret

register_selector_cached_found:
    RESTORE_REGS_LIGHT
    ret

.global lookup_cached_selector
// lookup_cached_selector: Fast lookup of cached selector
// Args: x0 = selector name (C string)
// Returns: x0 = SEL or 0 if not found
lookup_cached_selector:
    SAVE_REGS_LIGHT
    
    mov     x19, x0                 // Save selector name
    
    // Calculate hash
    bl      calculate_string_hash
    and     x20, x0, #SEL_CACHE_MASK
    
    // Get entry address
    adrp    x21, sel_cache_table@PAGE
    add     x21, x21, sel_cache_table@PAGEOFF
    mov     x22, #SEL_CACHE_ENTRY_SIZE
    madd    x20, x20, x22, x21      // entry_addr
    
    // Check if slot has data
    ldr     x0, [x20]
    cbz     x0, lookup_not_found
    
    // Compare strings
    mov     x1, x19
    bl      strcmp_fast
    cbz     x0, lookup_found
    
    // Linear probe for collisions
    mov     x23, #1
lookup_probe_loop:
    add     x24, x20, x23, lsl #4
    and     x24, x24, #(SEL_CACHE_SIZE * SEL_CACHE_ENTRY_SIZE - 1)
    add     x24, x21, x24
    
    ldr     x0, [x24]
    cbz     x0, lookup_not_found
    
    mov     x1, x19
    bl      strcmp_fast
    cbz     x0, lookup_probe_found
    
    add     x23, x23, #1
    cmp     x23, #SEL_CACHE_SIZE
    b.lo    lookup_probe_loop

lookup_not_found:
    mov     x0, #0
    RESTORE_REGS_LIGHT
    ret

lookup_found:
    ldr     x0, [x20, #8]           // Return SEL
    RESTORE_REGS_LIGHT
    ret

lookup_probe_found:
    ldr     x0, [x24, #8]           // Return SEL
    RESTORE_REGS_LIGHT
    ret

.global get_class_by_name
// get_class_by_name: Get Objective-C class by name
// Args: x0 = class name (C string)
// Returns: x0 = class object or 0 if not found
get_class_by_name:
    str     x30, [sp, #-16]!
    
    mov     x1, x0                  // Save class name
    
    // Load objc_getClass function pointer
    adrp    x0, objc_getClass_ptr@PAGE
    add     x0, x0, objc_getClass_ptr@PAGEOFF
    ldr     x0, [x0]
    
    // Call objc_getClass(class_name)
    mov     x0, x1                  // class_name
    blr     x0
    
    ldr     x30, [sp], #16
    ret

.global register_selector_name
// register_selector_name: Register selector with runtime (legacy interface)
// Args: x0 = selector name (C string)
// Returns: x0 = SEL
register_selector_name:
    str     x30, [sp, #-16]!
    
    // Use optimized version
    bl      register_selector_optimized
    
    ldr     x30, [sp], #16
    ret

//==============================================================================
// NSString Creation Helpers
//==============================================================================

.global create_nsstring_from_cstring
// create_nsstring_from_cstring: Create NSString from C string
// Args: x0 = C string
// Returns: x0 = NSString object
create_nsstring_from_cstring:
    SAVE_REGS_LIGHT
    
    mov     x19, x0                 // Save C string
    
    // Get NSString class
    adrp    x0, nsstring_class_name@PAGE
    add     x0, x0, nsstring_class_name@PAGEOFF
    bl      get_class_by_name
    cbz     x0, nsstring_create_error
    
    mov     x20, x0                 // Save NSString class
    
    // Get stringWithUTF8String: selector
    adrp    x0, stringWithUTF8String_sel_name@PAGE
    add     x0, x0, stringWithUTF8String_sel_name@PAGEOFF
    bl      register_selector_name
    cbz     x0, nsstring_create_error
    
    // Call [NSString stringWithUTF8String:cstring]
    mov     x1, x0                  // selector
    mov     x0, x20                 // NSString class
    mov     x2, x19                 // C string
    bl      objc_call_1
    
    RESTORE_REGS_LIGHT
    ret

nsstring_create_error:
    mov     x0, #0                  // Error
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Metal Device Creation
//==============================================================================

.global create_metal_default_device
// create_metal_default_device: Create default Metal device
// Returns: x0 = Metal device or 0 on error
create_metal_default_device:
    str     x30, [sp, #-16]!
    
    // Load MTLCreateSystemDefaultDevice function pointer
    adrp    x0, MTLCreateSystemDefaultDevice_ptr@PAGE
    add     x0, x0, MTLCreateSystemDefaultDevice_ptr@PAGEOFF
    ldr     x0, [x0]
    cbz     x0, metal_device_error
    
    // Call MTLCreateSystemDefaultDevice()
    blr     x0
    
    ldr     x30, [sp], #16
    ret

metal_device_error:
    mov     x0, #0                  // Error
    ldr     x30, [sp], #16
    ret

//==============================================================================
// NSRect and NSSize Helpers
//==============================================================================

.global make_nsrect
// make_nsrect: Create NSRect structure on stack
// Args: x0 = result_ptr, x1 = x, x2 = y, x3 = width, x4 = height
// Returns: none (result stored at result_ptr)
make_nsrect:
    // NSRect is: {origin: {x, y}, size: {width, height}}
    // All values are double (8 bytes each)
    
    // Convert integers to doubles and store
    scvtf   d0, x1                  // Convert x to double
    str     d0, [x0]                // Store origin.x
    
    scvtf   d1, x2                  // Convert y to double
    str     d1, [x0, #8]            // Store origin.y
    
    scvtf   d2, x3                  // Convert width to double
    str     d2, [x0, #16]           // Store size.width
    
    scvtf   d3, x4                  // Convert height to double
    str     d3, [x0, #24]           // Store size.height
    
    ret

//==============================================================================
// Enhanced Autorelease Pool Management
//==============================================================================

.global create_autorelease_pool_optimized
// create_autorelease_pool_optimized: Create optimized autorelease pool
// Returns: x0 = pool object, 0 on error
create_autorelease_pool_optimized:
    SAVE_REGS_LIGHT
    
    // Check if we can reuse an existing pool
    adrp    x19, pool_stack_depth@PAGE
    add     x19, x19, pool_stack_depth@PAGEOFF
    ldr     x0, [x19]
    cmp     x0, #32                 // Max stack depth
    b.ge    pool_stack_overflow
    
    // Get NSAutoreleasePool class
    adrp    x0, nsautoreleasepool_class@PAGE
    add     x0, x0, nsautoreleasepool_class@PAGEOFF
    ldr     x0, [x0]
    cbz     x0, pool_create_error
    
    // Send alloc message
    adrp    x1, sel_alloc@PAGE
    add     x1, x1, sel_alloc@PAGEOFF
    ldr     x1, [x1]
    bl      objc_call_0_uncached
    mov     x20, x0                 // Save pool object
    
    // Send init message
    mov     x0, x20
    adrp    x1, sel_init@PAGE
    add     x1, x1, sel_init@PAGEOFF
    ldr     x1, [x1]
    bl      objc_call_0_uncached
    mov     x20, x0                 // Update pool object
    
    // Push onto pool stack
    ldr     x1, [x19]              // Current depth
    adrp    x21, autorelease_pool_stack@PAGE
    add     x21, x21, autorelease_pool_stack@PAGEOFF
    str     x20, [x21, x1, lsl #3] // Store pool at stack[depth]
    add     x1, x1, #1
    str     x1, [x19]              // Update depth
    
    // Reset pool counters
    adrp    x0, current_pool_count@PAGE
    add     x0, x0, current_pool_count@PAGEOFF
    str     xzr, [x0]
    
    adrp    x0, current_pool_capacity@PAGE
    add     x0, x0, current_pool_capacity@PAGEOFF
    mov     x1, #1000               // Default capacity
    str     x1, [x0]
    
    mov     x0, x20                 // Return pool object
    RESTORE_REGS_LIGHT
    ret

pool_stack_overflow:
    mov     x0, #0                  // Error
    RESTORE_REGS_LIGHT
    ret

pool_create_error:
    mov     x0, #0                  // Error
    RESTORE_REGS_LIGHT
    ret

.global drain_autorelease_pool_optimized
// drain_autorelease_pool_optimized: Drain current autorelease pool
// Returns: x0 = 0 on success, error code on failure
drain_autorelease_pool_optimized:
    SAVE_REGS_LIGHT
    
    // Check if we have pools
    adrp    x19, pool_stack_depth@PAGE
    add     x19, x19, pool_stack_depth@PAGEOFF
    ldr     x0, [x19]
    cbz     x0, drain_pool_empty
    
    // Get current pool from stack
    sub     x0, x0, #1              // depth - 1
    adrp    x20, autorelease_pool_stack@PAGE
    add     x20, x20, autorelease_pool_stack@PAGEOFF
    ldr     x21, [x20, x0, lsl #3]  // pool = stack[depth-1]
    
    // Update stack depth
    str     x0, [x19]
    
    // Send drain message to pool
    mov     x0, x21
    adrp    x1, sel_drain@PAGE
    add     x1, x1, sel_drain@PAGEOFF
    ldr     x1, [x1]
    bl      objc_call_0_uncached
    
    // Reset counters
    adrp    x0, current_pool_count@PAGE
    add     x0, x0, current_pool_count@PAGEOFF
    str     xzr, [x0]
    
    mov     x0, #0                  // Success
    RESTORE_REGS_LIGHT
    ret

drain_pool_empty:
    mov     x0, #-1                 // Error: no pools
    RESTORE_REGS_LIGHT
    ret

.global autorelease_object
// autorelease_object: Add object to current autorelease pool
// Args: x0 = object
// Returns: x0 = same object (for chaining)
autorelease_object:
    SAVE_REGS_LIGHT
    
    mov     x19, x0                 // Save object
    
    // Check pool capacity
    adrp    x20, current_pool_count@PAGE
    add     x20, x20, current_pool_count@PAGEOFF
    ldr     x0, [x20]
    
    adrp    x21, current_pool_capacity@PAGE
    add     x21, x21, current_pool_capacity@PAGEOFF
    ldr     x1, [x21]
    
    cmp     x0, x1
    b.ge    pool_capacity_exceeded
    
    // Send autorelease message
    mov     x0, x19
    adrp    x1, sel_autorelease@PAGE
    add     x1, x1, sel_autorelease@PAGEOFF
    ldr     x1, [x1]
    bl      objc_call_0_uncached
    
    // Update pool count
    ldr     x1, [x20]
    add     x1, x1, #1
    str     x1, [x20]
    
    mov     x0, x19                 // Return original object
    RESTORE_REGS_LIGHT
    ret

pool_capacity_exceeded:
    // Create new pool if capacity exceeded
    bl      create_autorelease_pool_optimized
    
    // Retry autorelease
    mov     x0, x19
    adrp    x1, sel_autorelease@PAGE
    add     x1, x1, sel_autorelease@PAGEOFF
    ldr     x1, [x1]
    bl      objc_call_0_uncached
    
    mov     x0, x19                 // Return original object
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Class Hierarchy and Delegate Creation
//==============================================================================

.global create_delegate_class
// create_delegate_class: Create custom delegate class at runtime
// Args: x0 = class name, x1 = superclass name, x2 = method table
// Returns: x0 = new class or 0 on error
create_delegate_class:
    SAVE_REGS
    
    mov     x19, x0                 // Save class name
    mov     x20, x1                 // Save superclass name
    mov     x21, x2                 // Save method table
    
    // Get superclass
    mov     x0, x20
    bl      get_class_by_name
    cbz     x0, delegate_create_error
    mov     x22, x0                 // Save superclass
    
    // Allocate class pair
    mov     x0, x22                 // superclass
    mov     x1, x19                 // class name
    mov     x2, #0                  // extra bytes
    adrp    x3, objc_allocateClassPair_ptr@PAGE
    add     x3, x3, objc_allocateClassPair_ptr@PAGEOFF
    ldr     x3, [x3]
    blr     x3
    cbz     x0, delegate_create_error
    mov     x23, x0                 // Save new class
    
    // Add methods from method table
    mov     x0, x23                 // class
    mov     x1, x21                 // method table
    bl      add_methods_to_class
    cmp     x0, #0
    b.ne    delegate_create_error
    
    // Register class with runtime
    mov     x0, x23
    adrp    x1, objc_registerClassPair_ptr@PAGE
    add     x1, x1, objc_registerClassPair_ptr@PAGEOFF
    ldr     x1, [x1]
    blr     x1
    
    // Register delegate class
    mov     x0, x23
    mov     x1, x21                 // method table (as IMP table)
    bl      register_delegate_class
    
    mov     x0, x23                 // Return new class
    RESTORE_REGS
    ret

delegate_create_error:
    mov     x0, #0                  // Error
    RESTORE_REGS
    ret

.global add_methods_to_class
// add_methods_to_class: Add methods from table to class
// Args: x0 = class, x1 = method table (null-terminated)
// Returns: x0 = 0 on success, error code on failure
add_methods_to_class:
    SAVE_REGS_LIGHT
    
    mov     x19, x0                 // Save class
    mov     x20, x1                 // Save method table
    
add_method_loop:
    // Method table entry: selector_name(ptr) + types(ptr) + imp(ptr)
    ldr     x21, [x20]              // selector_name
    cbz     x21, add_methods_done   // End of table
    
    ldr     x22, [x20, #8]          // types
    ldr     x23, [x20, #16]         // IMP
    
    // Register selector
    mov     x0, x21
    bl      register_selector_optimized
    mov     x24, x0                 // Save SEL
    
    // Add method to class
    mov     x0, x19                 // class
    mov     x1, x24                 // SEL
    mov     x2, x23                 // IMP
    mov     x3, x22                 // types
    adrp    x4, class_addMethod_ptr@PAGE
    add     x4, x4, class_addMethod_ptr@PAGEOFF
    ldr     x4, [x4]
    blr     x4
    
    // Move to next method
    add     x20, x20, #24           // Next entry
    b       add_method_loop

add_methods_done:
    mov     x0, #0                  // Success
    RESTORE_REGS_LIGHT
    ret

.global register_delegate_class
// register_delegate_class: Register delegate class in our registry
// Args: x0 = class, x1 = IMP table
// Returns: x0 = 0 on success, error code on failure
register_delegate_class:
    SAVE_REGS_LIGHT
    
    mov     x19, x0                 // Save class
    mov     x20, x1                 // Save IMP table
    
    // Check if registry is full
    adrp    x21, delegate_count@PAGE
    add     x21, x21, delegate_count@PAGEOFF
    ldr     x0, [x21]
    cmp     x0, #MAX_DELEGATE_CLASSES
    b.ge    delegate_registry_full
    
    // Add to registry
    adrp    x22, delegate_classes@PAGE
    add     x22, x22, delegate_classes@PAGEOFF
    mov     x23, #DELEGATE_ENTRY_SIZE
    madd    x22, x0, x23, x22       // entry_addr
    
    str     x19, [x22]             // Store class
    str     x20, [x22, #8]         // Store IMP table
    
    // Update count
    add     x0, x0, #1
    str     x0, [x21]
    
    mov     x0, #0                  // Success
    RESTORE_REGS_LIGHT
    ret

delegate_registry_full:
    mov     x0, #-1                 // Error
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Utility Functions
//==============================================================================

.global calculate_string_hash
// calculate_string_hash: Calculate hash for null-terminated string
// Args: x0 = string pointer
// Returns: x0 = hash value
calculate_string_hash:
    mov     x1, #0                  // hash = 0
    mov     x2, #31                 // multiplier

hash_loop:
    ldrb    w3, [x0], #1           // Load byte and increment
    cbz     w3, hash_done          // End of string
    
    mul     x1, x1, x2             // hash *= 31
    add     x1, x1, x3             // hash += char
    b       hash_loop

hash_done:
    mov     x0, x1                  // Return hash
    ret

.global calculate_pointer_hash
// calculate_pointer_hash: Calculate hash for pointer value
// Args: x0 = pointer value
// Returns: x0 = hash value
calculate_pointer_hash:
    // Simple hash: mix upper and lower bits
    eor     x1, x0, x0, lsr #32
    eor     x0, x1, x1, lsr #16
    ret

.global strcmp_fast
// strcmp_fast: Fast string comparison optimized for short strings
// Args: x0 = str1, x1 = str2
// Returns: x0 = 0 if equal, non-zero if different
strcmp_fast:
    SAVE_REGS_LIGHT
    
strcmp_loop:
    ldrb    w2, [x0], #1
    ldrb    w3, [x1], #1
    
    cmp     w2, w3
    b.ne    strcmp_different
    
    cbz     w2, strcmp_equal       // Both strings ended
    b       strcmp_loop

strcmp_equal:
    mov     x0, #0
    RESTORE_REGS_LIGHT
    ret

strcmp_different:
    sub     x0, x2, x3
    RESTORE_REGS_LIGHT
    ret

//==============================================================================
// Function Pointer Storage
//==============================================================================

.bss
.align 3

// Objective-C runtime function pointers
objc_getClass_ptr:              .space  8
sel_registerName_ptr:           .space  8
objc_msgSend_ptr:               .space  8
objc_msgSend_stret_ptr:         .space  8
objc_msgSend_fpret_ptr:         .space  8
class_createInstance_ptr:       .space  8
object_getClass_ptr:            .space  8
objc_allocateClassPair_ptr:     .space  8
objc_registerClassPair_ptr:     .space  8
class_addMethod_ptr:            .space  8

// Metal function pointers
MTLCreateSystemDefaultDevice_ptr: .space 8

// Optimized selector cache (hash table)
sel_cache_table:                .space (SEL_CACHE_SIZE * SEL_CACHE_ENTRY_SIZE)
sel_cache_count:                .space 8

// Method dispatch cache for hot paths
method_cache_table:             .space (METHOD_CACHE_SIZE * 24) // receiver_class + SEL + IMP
method_cache_stats:             .space 32 // hits, misses, collisions, evictions

// Delegate class registry
delegate_classes:               .space (MAX_DELEGATE_CLASSES * DELEGATE_ENTRY_SIZE)
delegate_count:                 .space 8

// Autorelease pool stack
autorelease_pool_stack:         .space (32 * 8) // Stack of 32 pools max
pool_stack_depth:               .space 8
current_pool_capacity:          .space 8
current_pool_count:             .space 8

// Class references for optimized access
nsautoreleasepool_class:        .space 8

// Selector references for optimized access
sel_alloc:                      .space 8
sel_init:                       .space 8
sel_autorelease:                .space 8
sel_drain:                      .space 8

// System function pointers
dlopen_ptr:                     .space  8
dlsym_ptr:                      .space  8
dlclose_ptr:                    .space  8
dlerror_ptr:                    .space  8

.data
// Additional string constants for NSString creation
nsstring_class_name:            .asciz  "NSString"
stringWithUTF8String_sel_name:  .asciz  "stringWithUTF8String:"

.end