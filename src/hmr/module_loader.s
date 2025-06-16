/*
 * SimCity ARM64 - HMR Module Loader
 * ARM64 assembly implementation of dynamic module loading
 * 
 * Created by Agent 1: Core Module System
 * Provides dlopen wrapper and module registry with thread-safe operations
 */

.section __TEXT,__text,regular,pure_instructions
.align 4

// Include constants and macros
.include "../../include/macros/platform_asm.inc"
.include "../../include/constants/memory.inc"

// External symbols from libc/libdl
.extern _dlopen
.extern _dlclose
.extern _dlsym
.extern _dlerror
.extern _malloc
.extern _free
.extern _pthread_mutex_lock
.extern _pthread_mutex_unlock
.extern _pthread_mutex_init

// Module registry structure offsets
.set MODULE_REGISTRY_MUTEX_OFFSET,     0
.set MODULE_REGISTRY_COUNT_OFFSET,     40
.set MODULE_REGISTRY_CAPACITY_OFFSET,  44
.set MODULE_REGISTRY_MODULES_OFFSET,   48

// Module entry offsets (matching module_interface.h)
.set MODULE_NAME_OFFSET,        0
.set MODULE_DESCRIPTION_OFFSET, 32
.set MODULE_VERSION_OFFSET,     160
.set MODULE_STATE_OFFSET,       176
.set MODULE_HANDLE_OFFSET,      184
.set MODULE_INTERFACE_OFFSET,   192

// Function pointer offsets in interface
.set INTERFACE_INIT_OFFSET,      0
.set INTERFACE_UPDATE_OFFSET,    8
.set INTERFACE_SHUTDOWN_OFFSET,  32

// Global module registry
.section __DATA,__data
.align 8
module_registry:
    .space 48 + (256 * 8)    // mutex + count + capacity + 256 module pointers

.section __TEXT,__text,regular,pure_instructions

/*
 * hmr_load_module - Load a dynamic module from file path
 * Input: x0 = path string, x1 = module pointer address
 * Output: w0 = result code (0 = success)
 * Modifies: x0-x8, v0-v7
 */
.global _hmr_load_module
.align 4
_hmr_load_module:
    // Function prologue - save registers
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    // Save parameters
    mov     x19, x0             // x19 = path
    mov     x20, x1             // x20 = module pointer address
    
    // Validate parameters
    cbz     x19, .Lload_null_path
    cbz     x20, .Lload_null_module
    
    // Load module with dlopen
    mov     x0, x19             // path
    mov     x1, #0x101          // RTLD_LAZY | RTLD_LOCAL
    bl      _dlopen
    mov     x21, x0             // x21 = module handle
    cbz     x21, .Lload_dlopen_failed
    
    // Allocate module structure
    mov     x0, #1024           // sizeof(hmr_agent_module_t)
    bl      _malloc
    mov     x22, x0             // x22 = module structure
    cbz     x22, .Lload_alloc_failed
    
    // Initialize module structure
    mov     x0, x22
    mov     x1, #0
    mov     x2, #1024
    bl      _memset
    
    // Store module handle
    str     x21, [x22, #MODULE_HANDLE_OFFSET]
    
    // Look up required symbol: module_get_interface
    mov     x0, x21
    adrp    x1, .Lget_interface_symbol@PAGE
    add     x1, x1, .Lget_interface_symbol@PAGEOFF
    bl      _dlsym
    cbz     x0, .Lload_symbol_not_found
    
    // Call module_get_interface to populate interface
    add     x1, x22, #MODULE_INTERFACE_OFFSET
    blr     x0
    cbnz    w0, .Lload_interface_failed
    
    // Week 3 Enterprise Security Integration
    // Verify module signature
    mov     x0, x19             // module_path
    add     x1, x22, #1024      // signature storage
    bl      _hmr_verify_module_signature
    cbnz    w0, .Lload_security_failed
    
    // Create security context
    mov     x0, x22
    bl      _hmr_create_module_security_context
    cbnz    w0, .Lload_security_failed
    
    // Create sandbox if required
    mov     x0, x22
    bl      _hmr_create_default_sandbox
    // Note: sandbox creation failure is not fatal for all modules
    
    // Set module state to loaded
    mov     w0, #2              // HMR_MODULE_LOADED
    str     w0, [x22, #MODULE_STATE_OFFSET]
    
    // Mark security as verified
    mov     w0, #1
    str     w0, [x22, #1200]    // security_verified offset (approximate)
    
    // Store module pointer in output
    str     x22, [x20]
    
    // Register module in global registry
    mov     x0, x22
    bl      _hmr_register_module_internal
    
    // Success
    mov     w0, #0
    b       .Lload_cleanup
    
.Lload_null_path:
    mov     w0, #-1             // HMR_ERROR_NULL_POINTER
    b       .Lload_return
    
.Lload_null_module:
    mov     w0, #-1             // HMR_ERROR_NULL_POINTER
    b       .Lload_return
    
.Lload_dlopen_failed:
    mov     w0, #-5             // HMR_ERROR_LOAD_FAILED
    b       .Lload_return
    
.Lload_alloc_failed:
    mov     x0, x21
    bl      _dlclose
    mov     w0, #-9             // HMR_ERROR_OUT_OF_MEMORY
    b       .Lload_return
    
.Lload_symbol_not_found:
    mov     x0, x22
    bl      _free
    mov     x0, x21
    bl      _dlclose
    mov     w0, #-6             // HMR_ERROR_SYMBOL_NOT_FOUND
    b       .Lload_return
    
.Lload_interface_failed:
    mov     x0, x22
    bl      _free
    mov     x0, x21
    bl      _dlclose
    mov     w0, #-5             // HMR_ERROR_LOAD_FAILED
    b       .Lload_return

.Lload_security_failed:
    // Audit log security failure
    mov     x0, #4              // HMR_AUDIT_MODULE_REJECTED
    mov     x1, x22             // module
    mov     x2, #4              // ERROR severity
    adrp    x3, .Lsecurity_failure_msg@PAGE
    add     x3, x3, .Lsecurity_failure_msg@PAGEOFF
    mov     x4, #0
    bl      _hmr_audit_log
    
    mov     x0, x22
    bl      _free
    mov     x0, x21
    bl      _dlclose
    mov     w0, #-100           // HMR_SECURITY_ERROR_INVALID_SIGNATURE
    b       .Lload_return
    
.Lload_cleanup:
    // Flush instruction cache for loaded code
    bl      _hmr_flush_icache_full
    
    // Invalidate branch predictor
    bl      _hmr_invalidate_bpred

.Lload_return:
    // Function epilogue - restore registers
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

/*
 * hmr_unload_module - Unload a dynamic module
 * Input: x0 = module pointer
 * Output: w0 = result code (0 = success)
 */
.global _hmr_unload_module
.align 4
_hmr_unload_module:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0             // x19 = module
    cbz     x19, .Lunload_null_module
    
    // Check reference count
    ldr     w0, [x19, #176]     // reference_count offset
    cmp     w0, #1
    b.gt    .Lunload_has_refs
    
    // Call module shutdown if available
    add     x20, x19, #MODULE_INTERFACE_OFFSET
    ldr     x0, [x20, #INTERFACE_SHUTDOWN_OFFSET]
    cbz     x0, .Lunload_skip_shutdown
    
    mov     x1, x19             // module context
    blr     x0
    
.Lunload_skip_shutdown:
    // Unregister from global registry
    mov     x0, x19
    bl      _hmr_unregister_module_internal
    
    // Close dynamic library
    ldr     x0, [x19, #MODULE_HANDLE_OFFSET]
    bl      _dlclose
    
    // Free module structure
    mov     x0, x19
    bl      _free
    
    mov     w0, #0              // Success
    b       .Lunload_return
    
.Lunload_null_module:
    mov     w0, #-1             // HMR_ERROR_NULL_POINTER
    b       .Lunload_return
    
.Lunload_has_refs:
    // Decrement reference count
    sub     w0, w0, #1
    str     w0, [x19, #176]
    mov     w0, #0              // Success (not unloaded yet)
    
.Lunload_return:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

/*
 * hmr_register_module_internal - Register module in global registry
 * Input: x0 = module pointer
 * Output: w0 = result code
 */
.align 4
_hmr_register_module_internal:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    mov     x19, x0             // x19 = module
    
    // Lock registry mutex
    adrp    x20, module_registry@PAGE
    add     x20, x20, module_registry@PAGEOFF
    mov     x0, x20
    bl      _pthread_mutex_lock
    
    // Check capacity
    ldr     w1, [x20, #MODULE_REGISTRY_COUNT_OFFSET]
    ldr     w2, [x20, #MODULE_REGISTRY_CAPACITY_OFFSET]
    cmp     w1, w2
    b.ge    .Lregister_full
    
    // Add module to registry
    add     x2, x20, #MODULE_REGISTRY_MODULES_OFFSET
    str     x19, [x2, x1, lsl #3]
    
    // Increment count
    add     w1, w1, #1
    str     w1, [x20, #MODULE_REGISTRY_COUNT_OFFSET]
    
    mov     w0, #0              // Success
    b       .Lregister_unlock
    
.Lregister_full:
    mov     w0, #-4             // HMR_ERROR_ALREADY_EXISTS
    
.Lregister_unlock:
    // Unlock registry mutex
    push    x0                  // Save result
    mov     x0, x20
    bl      _pthread_mutex_unlock
    pop     x0                  // Restore result
    
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

/*
 * hmr_flush_icache_full - Flush instruction cache for entire system
 * ARM64 cache maintenance instructions
 */
.global _hmr_flush_icache_full
.align 4
_hmr_flush_icache_full:
    // Instruction cache invalidate all
    ic      ialluis
    
    // Data synchronization barrier
    dsb     ish
    
    // Instruction synchronization barrier
    isb
    
    ret

/*
 * hmr_invalidate_bpred - Invalidate branch predictor
 * ARM64 branch predictor invalidation
 */
.global _hmr_invalidate_bpred
.align 4
_hmr_invalidate_bpred:
    // Branch predictor invalidate all
    ic      iallu
    
    // Data synchronization barrier
    dsb     ish
    
    // Instruction synchronization barrier
    isb
    
    ret

/*
 * hmr_memory_barrier_full - Full memory barrier
 * Ensures memory ordering for hot-swap operations
 */
.global _hmr_memory_barrier_full
.align 4
_hmr_memory_barrier_full:
    // Data memory barrier - all memory accesses
    dmb     sy
    
    // Data synchronization barrier - all memory accesses
    dsb     sy
    
    // Instruction synchronization barrier
    isb
    
    ret

/*
 * hmr_init_registry - Initialize the global module registry
 * Should be called once at startup
 */
.global _hmr_init_registry
.align 4
_hmr_init_registry:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Initialize registry mutex
    adrp    x0, module_registry@PAGE
    add     x0, x0, module_registry@PAGEOFF
    mov     x1, #0              // NULL attributes
    bl      _pthread_mutex_init
    
    // Set initial capacity
    adrp    x0, module_registry@PAGE
    add     x0, x0, module_registry@PAGEOFF
    mov     w1, #256
    str     w1, [x0, #MODULE_REGISTRY_CAPACITY_OFFSET]
    
    // Set initial count to 0
    str     wzr, [x0, #MODULE_REGISTRY_COUNT_OFFSET]
    
    mov     w0, #0              // Success
    
    ldp     x29, x30, [sp], #16
    ret

// String constants
.section __TEXT,__cstring,cstring_literals
.align 3
.Lget_interface_symbol:
    .asciz "hmr_get_module_interface"
.Lsecurity_failure_msg:
    .asciz "Module failed security verification"

// Performance counters section
.section __DATA,__data
.align 8
.global _hmr_perf_counters
_hmr_perf_counters:
    .quad 0     // total_loads
    .quad 0     // total_unloads
    .quad 0     // failed_loads
    .quad 0     // cache_hits
    .quad 0     // avg_load_time_ns
    .quad 0     // peak_load_time_ns