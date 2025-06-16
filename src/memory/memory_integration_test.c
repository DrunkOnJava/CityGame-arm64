// Memory Integration Test
// Test the memory integration system

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

// External function declarations from assembly
extern int configure_memory_pools(void);
extern void* module_memory_init(int module_id, size_t size, int flags);
extern int memory_pressure_monitor(void);
extern void* allocate_save_buffer(size_t size);
extern void* allocate_temp_buffer(size_t size);
extern void* allocate_compression_buffer(size_t size);
extern int get_module_memory(void* stats, int module_id);

// Memory layout constants from integration file
#define HEAP_SIZE        0x100000000ULL  // 4GB total
#define TLSF_HEAP_SIZE   0x40000000ULL   // 1GB for TLSF
#define AGENT_POOL_SIZE  0x40000000ULL   // 1GB for agents
#define GRAPHICS_SIZE    0x40000000ULL   // 1GB for graphics
#define TLS_SIZE         0x40000000ULL   // 1GB for TLS + misc

// Module IDs
#define MODULE_GRAPHICS    0
#define MODULE_SIMULATION  1
#define MODULE_AI          2
#define MODULE_AUDIO       3
#define MODULE_UI          4
#define MODULE_IO          5
#define MODULE_MAX         6

int main() {
    printf("SimCity ARM64 Memory Integration Test\n");
    printf("=====================================\n\n");
    
    // Test 1: Configure memory pools
    printf("Test 1: Configuring memory pools...\n");
    int result = configure_memory_pools();
    if (result == 0) {
        printf("✓ Memory pools configured successfully\n");
    } else {
        printf("✗ Memory pool configuration failed: %d\n", result);
        return 1;
    }
    
    // Test 2: Module memory initialization
    printf("\nTest 2: Module memory initialization...\n");
    for (int module = 0; module < MODULE_MAX; module++) {
        void* mem = module_memory_init(module, 1024, 0);  // 1KB allocation
        if (mem != NULL) {
            printf("✓ Module %d: Memory allocated at %p\n", module, mem);
            
            // Test writing to the memory
            memset(mem, 0xAA, 1024);
            if (((uint8_t*)mem)[0] == 0xAA && ((uint8_t*)mem)[1023] == 0xAA) {
                printf("  Memory is writable and accessible\n");
            } else {
                printf("  ✗ Memory corruption detected\n");
            }
        } else {
            printf("✗ Module %d: Memory allocation failed\n", module);
        }
    }
    
    // Test 3: Memory pressure monitoring
    printf("\nTest 3: Memory pressure monitoring...\n");
    int pressure_level = memory_pressure_monitor();
    printf("Current memory pressure level: %d\n", pressure_level);
    
    // Test 4: Specialized buffer allocation
    printf("\nTest 4: Specialized buffer allocation...\n");
    
    void* save_buf = allocate_save_buffer(64 * 1024);  // 64KB save buffer
    if (save_buf) {
        printf("✓ Save buffer allocated: %p (64KB)\n", save_buf);
    } else {
        printf("✗ Save buffer allocation failed\n");
    }
    
    void* temp_buf = allocate_temp_buffer(16 * 1024);  // 16KB temp buffer
    if (temp_buf) {
        printf("✓ Temp buffer allocated: %p (16KB)\n", temp_buf);
    } else {
        printf("✗ Temp buffer allocation failed\n");
    }
    
    void* comp_buf = allocate_compression_buffer(32 * 1024);  // 32KB compression buffer
    if (comp_buf) {
        printf("✓ Compression buffer allocated: %p (32KB)\n", comp_buf);
    } else {
        printf("✗ Compression buffer allocation failed\n");
    }
    
    // Test 5: Module memory statistics
    printf("\nTest 5: Module memory statistics...\n");
    uint64_t stats[2];  // current_size, peak_size
    for (int module = 0; module < MODULE_MAX; module++) {
        if (get_module_memory(stats, module) == 0) {
            printf("Module %d: Current=%lluKB, Peak=%lluKB\n", 
                   module, stats[0]/1024, stats[1]/1024);
        }
    }
    
    printf("\n=====================================\n");
    printf("Memory Integration Test Complete\n");
    
    return 0;
}