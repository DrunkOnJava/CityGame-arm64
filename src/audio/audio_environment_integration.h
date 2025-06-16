// audio_environment_integration.h - Integration Header for Audio and Environment Systems
// Coordinates between 3D audio, weather, environment effects, and time systems
// Agent 8: Audio and Environment Systems Developer

#ifndef AUDIO_ENVIRONMENT_INTEGRATION_H
#define AUDIO_ENVIRONMENT_INTEGRATION_H

#include <stdint.h>
#include <stdbool.h>

// Forward declarations for external systems
typedef struct GameTime GameTime;
typedef struct WeatherConditions WeatherConditions;
typedef struct LightingConditions LightingConditions;

// System initialization and management
typedef struct {
    bool audio_system_active;
    bool weather_system_active;
    bool environment_system_active;
    bool integration_enabled;
    
    // Performance metrics
    uint32_t active_audio_sources;
    uint32_t weather_particles;
    uint32_t environment_particles;
    float processing_load;
    
    // Integration state
    uint32_t last_weather_update;
    uint32_t last_environment_update;
    uint32_t last_audio_update;
} AudioEnvironmentState;

// Weather-Audio Integration
typedef struct {
    float precipitation_volume;     // Volume for rain/snow sounds
    float wind_volume;             // Volume for wind sounds
    float thunder_probability;     // Chance of thunder per frame
    float atmospheric_filtering;   // Audio filtering due to weather
    
    // Environmental acoustics
    float air_absorption;          // High frequency attenuation
    float humidity_reverb;         // Reverb changes due to humidity
    float pressure_doppler;        // Pressure effects on sound
} WeatherAudioParams;

// Time-Environment-Audio Integration
typedef struct {
    float time_of_day;            // 0.0 - 24.0 hours
    uint32_t time_phase;          // Dawn, day, dusk, night phases
    
    // Lighting parameters
    float ambient_light_intensity;
    float directional_light_intensity;
    float sky_brightness;
    
    // Audio parameters
    float ambient_volume_modifier; // Time-based volume changes
    float activity_level;         // City activity affects audio
    bool street_lights_active;
    
    // Sky and atmospheric colors
    float sky_color[4];           // RGBA
    float fog_density;
    float atmospheric_scattering;
} TimeEnvironmentParams;

// 3D Audio Spatial Integration
typedef struct {
    float listener_position[3];    // World coordinates
    float listener_velocity[3];    // For Doppler effects
    float listener_orientation[6]; // Forward and up vectors
    
    // Environmental acoustics
    float reverb_room_size;
    float reverb_damping;
    float occlusion_strength;
    
    // Weather-modified audio
    float wind_direction;          // Affects audio propagation
    float temperature;             // Affects sound speed
    float humidity;                // Affects attenuation
} SpatialAudioParams;

// Particle System Integration
typedef struct {
    // Weather particles
    uint32_t rain_particle_count;
    uint32_t snow_particle_count;
    uint32_t dust_particle_count;
    
    // Environment particles
    uint32_t steam_particle_count;
    uint32_t pollen_particle_count;
    uint32_t smoke_particle_count;
    
    // Audio-visual sync
    bool particles_affect_audio;   // Particles modify reverb/occlusion
    float particle_audio_density;
} ParticleIntegrationParams;

// === CORE INTEGRATION FUNCTIONS ===

#ifdef __cplusplus
extern "C" {
#endif

// System initialization and coordination
int audio_environment_init(uint32_t climate_zone, float latitude, float initial_time);
int audio_environment_shutdown(void);
int audio_environment_update(uint64_t delta_time_ms);

// Cross-system state synchronization
int sync_weather_to_audio(const WeatherConditions* weather);
int sync_environment_to_audio(const TimeEnvironmentParams* env_params);
int sync_time_to_systems(const GameTime* game_time);

// Real-time parameter updates
int update_weather_audio_integration(void);
int update_environment_lighting_integration(void);
int update_spatial_audio_integration(void);

// === WEATHER-AUDIO INTEGRATION ===

// Weather sound management
int weather_audio_start_precipitation(float intensity, uint32_t type);
int weather_audio_stop_precipitation(void);
int weather_audio_update_wind(float speed, float direction);
int weather_audio_trigger_thunder(float intensity, float distance);

// Environmental acoustics based on weather
int weather_audio_update_reverb(float humidity, float pressure);
int weather_audio_update_attenuation(float temperature, float humidity);
int weather_audio_update_filtering(float precipitation, float wind);

// === ENVIRONMENT-LIGHTING INTEGRATION ===

// Time-based lighting updates
int environment_update_sun_position(float time_of_day, float latitude);
int environment_update_moon_position(float time_of_day);
int environment_update_sky_color(float time_of_day, uint32_t weather_condition);
int environment_update_ambient_lighting(float time_of_day, uint32_t season);

// Atmospheric effects
int environment_update_fog(float temperature, float humidity);
int environment_update_atmospheric_scattering(float pollution, float humidity);
int environment_update_heat_shimmer(float temperature, float sun_intensity);

// City lighting integration
int environment_update_street_lights(float ambient_light);
int environment_update_building_lights(float time_of_day);
int environment_update_vehicle_lights(float ambient_light, uint32_t traffic_density);

// === SPATIAL AUDIO INTEGRATION ===

// 3D audio positioning
int spatial_audio_set_listener(const float position[3], const float orientation[6]);
int spatial_audio_update_doppler(const float velocity[3]);
int spatial_audio_update_environmental_reverb(const SpatialAudioParams* params);

// Weather-affected spatial audio
int spatial_audio_apply_wind_effects(float wind_speed, float wind_direction);
int spatial_audio_apply_temperature_effects(float temperature);
int spatial_audio_apply_humidity_effects(float humidity);

// === PARTICLE SYSTEM INTEGRATION ===

// Weather particle-audio sync
int particles_sync_rain_audio(uint32_t particle_count, float intensity);
int particles_sync_snow_audio(uint32_t particle_count, float wind_speed);
int particles_update_audio_occlusion(const ParticleIntegrationParams* params);

// Environmental particle effects
int particles_create_dust_motes(const float sun_position[3], float intensity);
int particles_create_steam_effects(float temperature_diff, const float position[3]);
int particles_create_pollen_cloud(uint32_t season, float wind_speed);

// === PERFORMANCE AND OPTIMIZATION ===

// LOD (Level of Detail) management
int audio_environment_update_lod(float camera_distance, float performance_budget);
int audio_environment_cull_distant_sources(float max_distance);
int audio_environment_adjust_quality(float performance_target);

// Memory and resource management
int audio_environment_cleanup_expired_sources(void);
int audio_environment_optimize_buffers(void);
int audio_environment_get_memory_usage(uint64_t* total_bytes, uint64_t* peak_bytes);

// === CONFIGURATION AND TUNING ===

// Audio configuration
int audio_config_set_master_volume(float volume);
int audio_config_set_ambient_volume(float volume);
int audio_config_set_weather_volume(float volume);
int audio_config_set_spatial_quality(uint32_t quality_level);

// Environment configuration
int environment_config_set_time_scale(float scale);
int environment_config_set_weather_intensity(float intensity);
int environment_config_set_lighting_quality(uint32_t quality_level);
int environment_config_set_particle_density(float density);

// === DEBUG AND MONITORING ===

// Performance monitoring
int audio_environment_get_performance_stats(AudioEnvironmentState* stats);
int audio_environment_log_active_sources(void);
int audio_environment_validate_integration(void);

// Debug visualization
int audio_environment_debug_draw_audio_sources(void);
int audio_environment_debug_draw_weather_particles(void);
int audio_environment_debug_draw_lighting_grid(void);

// === UTILITY FUNCTIONS ===

// Interpolation and smoothing
float lerp_float(float a, float b, float t);
void lerp_vec3(const float a[3], const float b[3], float t, float result[3]);
void lerp_color(const float a[4], const float b[4], float t, float result[4]);

// Coordinate transformations
void world_to_audio_coordinates(const float world_pos[3], float audio_pos[3]);
void audio_to_world_coordinates(const float audio_pos[3], float world_pos[3]);

// Time utilities
float hours_to_radians(float hours);
float radians_to_hours(float radians);
uint32_t get_time_phase(float time_of_day);

// Weather utilities
float precipitation_to_audio_volume(float precipitation_intensity);
float wind_to_audio_volume(float wind_speed);
float temperature_to_audio_filtering(float temperature);

// Environmental utilities
float calculate_atmospheric_attenuation(float distance, float humidity, float temperature);
float calculate_reverb_time(float room_size, float damping);
float calculate_occlusion_factor(const float source_pos[3], const float listener_pos[3]);

#ifdef __cplusplus
}
#endif

// === CONSTANTS AND CONFIGURATION ===

// System limits
#define MAX_INTEGRATED_AUDIO_SOURCES 256
#define MAX_WEATHER_AUDIO_SOURCES 32
#define MAX_ENVIRONMENT_PARTICLES 4096
#define MAX_LIGHTING_GRID_SIZE 256

// Update frequencies (milliseconds)
#define WEATHER_AUDIO_UPDATE_INTERVAL 100
#define ENVIRONMENT_LIGHTING_UPDATE_INTERVAL 50
#define SPATIAL_AUDIO_UPDATE_INTERVAL 16  // ~60 FPS

// Quality levels
#define AUDIO_QUALITY_LOW 0
#define AUDIO_QUALITY_MEDIUM 1
#define AUDIO_QUALITY_HIGH 2
#define AUDIO_QUALITY_ULTRA 3

// Performance targets
#define PERFORMANCE_TARGET_30FPS 33.333f
#define PERFORMANCE_TARGET_60FPS 16.667f
#define PERFORMANCE_TARGET_120FPS 8.333f

// Error codes
#define AUDIO_ENV_SUCCESS 0
#define AUDIO_ENV_ERROR_NOT_INITIALIZED -1
#define AUDIO_ENV_ERROR_INVALID_PARAMETER -2
#define AUDIO_ENV_ERROR_OUT_OF_MEMORY -3
#define AUDIO_ENV_ERROR_SYSTEM_FAILURE -4
#define AUDIO_ENV_ERROR_INTEGRATION_FAILED -5

// Integration flags
#define INTEGRATION_FLAG_WEATHER_AUDIO (1 << 0)
#define INTEGRATION_FLAG_ENVIRONMENT_LIGHTING (1 << 1)
#define INTEGRATION_FLAG_SPATIAL_AUDIO (1 << 2)
#define INTEGRATION_FLAG_PARTICLE_SYNC (1 << 3)
#define INTEGRATION_FLAG_ALL 0xFFFFFFFF

#endif // AUDIO_ENVIRONMENT_INTEGRATION_H