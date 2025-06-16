#include "hmr_unified.h"
#include <stdio.h>
#include <assert.h>

int main() {
    printf("=== HMR Unified API Compatibility Test ===\n");
    
    // Test type definitions
    hmr_module_state_t state = HMR_MODULE_STATE_ACTIVE;
    hmr_capability_flags_t caps = HMR_CAP_HOT_SWAPPABLE | HMR_CAP_ARM64_ONLY;
    hmr_asset_type_t asset = HMR_ASSET_METAL_SHADER;
    hmr_shader_type_t shader = HMR_SHADER_VERTEX;
    
    printf("✓ Type definitions compiled successfully\n");
    printf("  Module state: %d\n", state);
    printf("  Capabilities: 0x%x\n", caps);
    printf("  Asset type: %d\n", asset);
    printf("  Shader type: %d\n", shader);
    
    // Test constants
    assert(HMR_SUCCESS == 0);
    assert(HMR_MAGIC_NUMBER == 0x484D522D41524D36ULL);
    assert(HMR_VERSION == 2);
    printf("✓ Constants validated\n");
    
    // Test structure sizes (basic validation)
    printf("Structure sizes:\n");
    printf("  hmr_module_info_t: %zu bytes\n", sizeof(hmr_module_info_t));
    printf("  hmr_unified_metrics_t: %zu bytes\n", sizeof(hmr_unified_metrics_t));
    printf("  hmr_shared_control_t: %zu bytes\n", sizeof(hmr_shared_control_t));
    
    // Verify cache alignment
    assert(sizeof(hmr_module_info_t) % 64 == 0);
    assert(sizeof(hmr_shared_control_t) % 4096 == 0);
    printf("✓ Structure alignment validated\n");
    
    printf("\n=== API Compatibility Test PASSED ===\n");
    return 0;
}
