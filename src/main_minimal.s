.global _main
.align 4

; SimCity ARM64 - Minimal Main Entry Point
; Basic function calls without complex addressing

.text
_main:
    ; Save frame pointer and link register
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    ; Initialize all subsystems in dependency order
    bl bootstrap_init
    bl syscalls_init  
    bl threads_init
    bl objc_bridge_init
    
    bl tlsf_init
    bl tls_allocator_init
    bl agent_allocator_init
    
    bl event_bus_init
    bl ecs_core_init
    bl entity_system_init
    bl frame_control_init
    
    bl metal_init
    bl metal_pipeline_init
    bl shader_loader_init
    bl camera_init
    bl sprite_batch_init
    bl particle_system_init
    bl debug_overlay_init
    
    bl simulation_core_init
    bl time_system_init
    bl weather_system_init
    bl zoning_system_init
    bl economic_system_init
    bl infrastructure_init
    
    bl astar_core_init
    bl navmesh_init
    bl citizen_behavior_init
    bl traffic_flow_init
    bl emergency_services_init
    bl mass_transit_init
    
    bl save_load_init
    bl asset_loader_init
    bl config_parser_init
    
    bl core_audio_init
    bl spatial_audio_init
    bl sound_mixer_init
    
    bl input_handler_init
    bl hud_init
    bl ui_tools_init
    
    ; Simple game loop for demo
    mov x19, #600  ; Run for 600 frames (10 seconds at 60fps)
    
.game_loop:
    ; Process systems
    bl process_input_events
    bl simulation_update
    bl ai_update
    bl audio_update
    bl render_frame
    bl ui_update
    bl calculate_frame_time
    
    ; Simple frame limiter (sleep 16ms)
    mov x0, #16000  ; 16ms in microseconds  
    bl usleep
    
    ; Decrement counter
    sub x19, x19, #1
    cbnz x19, .game_loop
    
    ; Shutdown systems
    bl ui_shutdown
    bl audio_shutdown
    bl io_shutdown
    bl ai_shutdown
    bl simulation_shutdown
    bl graphics_shutdown
    bl core_shutdown
    bl memory_shutdown
    bl platform_shutdown
    
    ; Success
    mov x0, #0
    ldp x29, x30, [sp], #16
    ret