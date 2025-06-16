// SimCity ARM64 Spatial Audio System
// Agent 8: Audio Systems
// Ring-buffer mixer with HRTF 3D positional audio for Apple Silicon

#ifndef SPATIAL_AUDIO_H
#define SPATIAL_AUDIO_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Audio source types
typedef enum {
    AUDIO_SOURCE_AMBIENT = 0,
    AUDIO_SOURCE_ENTITY = 1,
    AUDIO_SOURCE_VEHICLE = 2,
    AUDIO_SOURCE_BUILDING = 3,
    AUDIO_SOURCE_ENVIRONMENT = 4,
    AUDIO_SOURCE_UI = 5
} AudioSourceType;

//==============================================================================
// SYSTEM INITIALIZATION AND MANAGEMENT
//==============================================================================

/**
 * Initialize the spatial audio system
 * @return 0 on success, -1 on failure
 */
int audio_system_init(void);

/**
 * Shutdown the spatial audio system and cleanup resources
 */
void audio_system_shutdown(void);

//==============================================================================
// AUDIO SOURCE MANAGEMENT
//==============================================================================

/**
 * Create a new audio source
 * @param source_id Output parameter for the assigned source ID
 * @param type Type of audio source
 * @return 0 on success, -1 on failure
 */
int audio_create_source(uint32_t* source_id, AudioSourceType type);

/**
 * Start playback of an audio source
 * @param source_id Audio source ID
 * @return 0 on success, -1 on failure
 */
int audio_play_source(uint32_t source_id);

/**
 * Stop playback of an audio source
 * @param source_id Audio source ID
 * @return 0 on success, -1 on failure
 */
int audio_stop_source(uint32_t source_id);

/**
 * Pause playback of an audio source
 * @param source_id Audio source ID
 * @return 0 on success, -1 on failure
 */
int audio_pause_source(uint32_t source_id);

/**
 * Resume playback of a paused audio source
 * @param source_id Audio source ID
 * @return 0 on success, -1 on failure
 */
int audio_resume_source(uint32_t source_id);

/**
 * Set the volume of an audio source
 * @param source_id Audio source ID
 * @param volume Volume level (0.0 to 1.0)
 * @return 0 on success, -1 on failure
 */
int audio_set_source_volume(uint32_t source_id, float volume);

/**
 * Set the pitch of an audio source
 * @param source_id Audio source ID
 * @param pitch Pitch multiplier (1.0 = normal pitch)
 * @return 0 on success, -1 on failure
 */
int audio_set_source_pitch(uint32_t source_id, float pitch);

/**
 * Set looping for an audio source
 * @param source_id Audio source ID
 * @param looping 1 to enable looping, 0 to disable
 * @return 0 on success, -1 on failure
 */
int audio_set_source_looping(uint32_t source_id, uint8_t looping);

//==============================================================================
// 3D SPATIAL AUDIO
//==============================================================================

/**
 * Set the 3D position of an audio source
 * @param source_id Audio source ID
 * @param x X coordinate
 * @param y Y coordinate
 * @param z Z coordinate
 * @return 0 on success, -1 on failure
 */
int audio_set_source_position(uint32_t source_id, float x, float y, float z);

/**
 * Set the velocity of an audio source (for Doppler effect)
 * @param source_id Audio source ID
 * @param vx X velocity
 * @param vy Y velocity
 * @param vz Z velocity
 * @return 0 on success, -1 on failure
 */
int audio_set_source_velocity(uint32_t source_id, float vx, float vy, float vz);

/**
 * Set the audio listener (camera/player) position
 * @param x X coordinate
 * @param y Y coordinate
 * @param z Z coordinate
 * @return 0 on success, -1 on failure
 */
int audio_set_listener_position(float x, float y, float z);

/**
 * Set the audio listener orientation
 * @param forward_x Forward vector X component
 * @param forward_y Forward vector Y component
 * @param forward_z Forward vector Z component
 * @param up_x Up vector X component
 * @param up_y Up vector Y component
 * @param up_z Up vector Z component
 * @return 0 on success, -1 on failure
 */
int audio_set_listener_orientation(float forward_x, float forward_y, float forward_z,
                                  float up_x, float up_y, float up_z);

/**
 * Set the audio listener velocity (for Doppler effect)
 * @param vx X velocity
 * @param vy Y velocity
 * @param vz Z velocity
 * @return 0 on success, -1 on failure
 */
int audio_set_listener_velocity(float vx, float vy, float vz);

//==============================================================================
// AUDIO DATA MANAGEMENT
//==============================================================================

/**
 * Load audio data from a file into an audio source
 * @param source_id Audio source ID
 * @param file_path Path to audio file
 * @return 0 on success, -1 on failure
 */
int audio_load_source_file(uint32_t source_id, const char* file_path);

/**
 * Load audio data from memory buffer into an audio source
 * @param source_id Audio source ID
 * @param data Audio sample data (32-bit float)
 * @param sample_count Number of samples
 * @param sample_rate Sample rate in Hz
 * @param channels Number of channels (1 or 2)
 * @return 0 on success, -1 on failure
 */
int audio_load_source_data(uint32_t source_id, const float* data, uint32_t sample_count,
                          uint32_t sample_rate, uint32_t channels);

/**
 * Unload audio data from a source
 * @param source_id Audio source ID
 * @return 0 on success, -1 on failure
 */
int audio_unload_source(uint32_t source_id);

//==============================================================================
// SYSTEM CONFIGURATION
//==============================================================================

/**
 * Set the master volume for all audio
 * @param volume Master volume level (0.0 to 1.0)
 */
void audio_set_master_volume(float volume);

/**
 * Set the distance attenuation factor
 * @param factor Distance attenuation factor (1.0 = normal)
 */
void audio_set_distance_factor(float factor);

/**
 * Set the Doppler effect factor
 * @param factor Doppler factor (1.0 = normal, 0.0 = disabled)
 */
void audio_set_doppler_factor(float factor);

/**
 * Set reverb parameters
 * @param room_size Room size (0.0 to 1.0)
 * @param damping Damping factor (0.0 to 1.0)
 * @param wet_gain Reverb wet gain (0.0 to 1.0)
 * @param dry_gain Reverb dry gain (0.0 to 1.0)
 */
void audio_set_reverb_params(float room_size, float damping, float wet_gain, float dry_gain);

//==============================================================================
// PERFORMANCE AND DEBUGGING
//==============================================================================

/**
 * Get audio system performance statistics
 * @param frames_processed Output for total frames processed
 * @param buffer_underruns Output for number of buffer underruns
 * @param cpu_overloads Output for number of CPU overloads
 * @param peak_cpu_usage Output for peak CPU usage percentage
 */
void audio_get_performance_stats(uint32_t* frames_processed, uint32_t* buffer_underruns, 
                                uint32_t* cpu_overloads, float* peak_cpu_usage);

/**
 * Print audio system statistics to stdout
 */
void audio_print_statistics(void);

/**
 * Get the number of active audio sources
 * @return Number of currently playing audio sources
 */
uint32_t audio_get_active_source_count(void);

/**
 * Check if HRTF processing is available
 * @return 1 if HRTF is available, 0 otherwise
 */
int audio_is_hrtf_available(void);

//==============================================================================
// CONVENIENCE FUNCTIONS FOR SIMCITY INTEGRATION
//==============================================================================

/**
 * Play a positioned sound effect (fire-and-forget)
 * @param file_path Path to audio file
 * @param x X position
 * @param y Y position
 * @param z Z position
 * @param volume Volume level (0.0 to 1.0)
 * @return 0 on success, -1 on failure
 */
int audio_play_sound_at_position(const char* file_path, float x, float y, float z, float volume);

/**
 * Play a UI sound effect (non-positional)
 * @param file_path Path to audio file
 * @param volume Volume level (0.0 to 1.0)
 * @return 0 on success, -1 on failure
 */
int audio_play_ui_sound(const char* file_path, float volume);

/**
 * Create and start ambient audio loop
 * @param file_path Path to audio file
 * @param volume Volume level (0.0 to 1.0)
 * @param source_id Output parameter for source ID (for later control)
 * @return 0 on success, -1 on failure
 */
int audio_start_ambient_loop(const char* file_path, float volume, uint32_t* source_id);

/**
 * Update entity audio position (call every frame for moving entities)
 * @param entity_id Entity identifier
 * @param x X position
 * @param y Y position
 * @param z Z position
 * @param vx X velocity
 * @param vy Y velocity
 * @param vz Z velocity
 * @return 0 on success, -1 on failure
 */
int audio_update_entity_position(uint32_t entity_id, float x, float y, float z, 
                                float vx, float vy, float vz);

//==============================================================================
// CONVENIENCE MACROS
//==============================================================================

// Macro for updating listener position from camera
#define AUDIO_UPDATE_LISTENER_FROM_CAMERA(cam) \\\n    audio_set_listener_position((cam)->position.x, (cam)->position.y, (cam)->position.z); \\\n    audio_set_listener_orientation((cam)->forward.x, (cam)->forward.y, (cam)->forward.z, \\\n                                   (cam)->up.x, (cam)->up.y, (cam)->up.z)\n\n// Macro for distance-based volume calculation\n#define AUDIO_CALCULATE_DISTANCE_VOLUME(distance, max_distance) \\\n    ((distance) < (max_distance) ? (1.0f - (distance) / (max_distance)) : 0.0f)\n\n// Macro for quick sound effect playback\n#define AUDIO_PLAY_SFX(file, vol) audio_play_ui_sound(file, vol)\n\n// Macro for positioned vehicle sounds\n#define AUDIO_PLAY_VEHICLE_SOUND(file, x, y, z, vol) \\\n    audio_play_sound_at_position(file, x, y, z, vol)\n\n#ifdef __cplusplus\n}\n#endif\n\n#endif // SPATIAL_AUDIO_H