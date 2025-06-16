#include <stdio.h>

// Graphics system stubs
int metal_init(void) { printf("Graphics: Metal initialized\n"); return 0; }
int metal_pipeline_init(void) { return 0; }
int shader_loader_init(void) { return 0; }
int camera_init(void) { return 0; }
int sprite_batch_init(void) { return 0; }
int particle_system_init(void) { return 0; }
int debug_overlay_init(void) { return 0; }
void render_frame(void) { /* Render frame stub */ }
void camera_update_matrices(void) {}
void render_terrain_layer(void* encoder) {}
void render_building_layer(void* encoder) {}
void render_entity_layer(void* encoder) {}
void render_particle_layer(void* encoder) {}
void render_ui_layer(void* encoder) {}
void render_debug_overlay(void* encoder) {}
void* metal_encoder_begin_frame(void) { return NULL; }
void metal_encoder_end_frame(void* encoder) {}
void setup_render_pass(void* encoder) {}
void graphics_shutdown(void) {}
