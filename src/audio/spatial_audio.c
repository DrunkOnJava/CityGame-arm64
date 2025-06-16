// SimCity ARM64 Spatial Audio System
// Agent 8: Audio Systems
// Ring-buffer mixer with HRTF 3D positional audio for Apple Silicon

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include <pthread.h>
#include <AudioUnit/AudioUnit.h>
#include <CoreAudio/CoreAudio.h>
#include <AVFoundation/AVFoundation.h>
#include <Accelerate/Accelerate.h>
#include <stdatomic.h>
#include <sys/mman.h>

// Audio configuration constants
#define SAMPLE_RATE 48000.0f
#define FRAME_SIZE 512
#define RING_BUFFER_SIZE (FRAME_SIZE * 64)  // 32K samples per channel
#define MAX_AUDIO_SOURCES 256
#define MAX_CONCURRENT_SOUNDS 64
#define HRTF_FILTER_LENGTH 128
#define REVERB_BUFFER_SIZE (SAMPLE_RATE * 4)  // 4 second reverb buffer
#define MAX_AUDIO_DISTANCE 1000.0f
#define MIN_AUDIO_DISTANCE 1.0f

// HRTF database constants
#define HRTF_AZIMUTH_STEPS 72     // 5 degree steps
#define HRTF_ELEVATION_STEPS 37   // -90 to +90 degrees, 5 degree steps
#define HRTF_DATABASE_SIZE (HRTF_AZIMUTH_STEPS * HRTF_ELEVATION_STEPS * HRTF_FILTER_LENGTH * 2) // L+R

// Audio source types
typedef enum {
    AUDIO_SOURCE_AMBIENT = 0,
    AUDIO_SOURCE_ENTITY = 1,
    AUDIO_SOURCE_VEHICLE = 2,
    AUDIO_SOURCE_BUILDING = 3,
    AUDIO_SOURCE_ENVIRONMENT = 4,
    AUDIO_SOURCE_UI = 5
} AudioSourceType;

// Audio source state
typedef enum {
    AUDIO_STATE_STOPPED = 0,
    AUDIO_STATE_PLAYING = 1,
    AUDIO_STATE_PAUSED = 2,
    AUDIO_STATE_FADING_IN = 3,
    AUDIO_STATE_FADING_OUT = 4
} AudioState;

// 3D position vector
typedef struct {
    float x, y, z;
} Vector3;

// HRTF filter coefficients
typedef struct {
    float left[HRTF_FILTER_LENGTH];
    float right[HRTF_FILTER_LENGTH];
} HRTFFilter;

// Ring buffer for audio data
typedef struct {
    float* buffer;
    atomic_uint write_pos;
    atomic_uint read_pos;
    uint32_t size;
    uint32_t mask;  // size - 1 for efficient wrapping
} RingBuffer;

// Audio source instance
typedef struct {
    uint32_t id;
    AudioSourceType type;
    AudioState state;
    
    // Position and movement
    Vector3 position;
    Vector3 velocity;
    
    // Audio properties
    float volume;
    float pitch;
    float pan;
    float distance_attenuation;
    
    // Sample data
    float* sample_data;
    uint32_t sample_length;
    uint32_t sample_rate;
    uint32_t channels;
    
    // Playback state
    atomic_uint playback_position;
    uint32_t loop_start;
    uint32_t loop_end;
    uint8_t looping;
    
    // HRTF processing
    HRTFFilter current_hrtf;
    HRTFFilter target_hrtf;
    float hrtf_interpolation;
    float hrtf_delay_left[HRTF_FILTER_LENGTH];
    float hrtf_delay_right[HRTF_FILTER_LENGTH];
    
    // Fade control
    float fade_start_volume;
    float fade_target_volume;
    float fade_duration;
    float fade_current_time;
    
    // Performance tracking
    uint64_t samples_processed;
    uint32_t underruns;
} AudioSource;

// Listener (camera/player) properties
typedef struct {
    Vector3 position;
    Vector3 forward;
    Vector3 up;
    Vector3 right;
    Vector3 velocity;
    
    float master_volume;
    float distance_factor;
    float doppler_factor;
    float speed_of_sound;
} AudioListener;

// Reverb processor
typedef struct {
    float* delay_buffer;
    uint32_t delay_length;
    uint32_t delay_pos;
    float feedback;
    float wet_gain;
    float dry_gain;
    float damping;
    float room_size;
} ReverbProcessor;

// Main audio system state
typedef struct {
    // Audio unit
    AudioUnit output_unit;
    AudioStreamBasicDescription audio_format;
    
    // Ring buffers for mixing
    RingBuffer master_left;
    RingBuffer master_right;
    
    // Audio sources
    AudioSource sources[MAX_AUDIO_SOURCES];
    uint32_t active_sources;
    pthread_mutex_t sources_mutex;
    
    // Listener
    AudioListener listener;
    
    // HRTF database
    HRTFFilter* hrtf_database;
    uint8_t hrtf_loaded;
    
    // Reverb processor
    ReverbProcessor reverb;
    
    // Performance metrics
    atomic_uint frames_processed;
    atomic_uint buffer_underruns;
    atomic_uint cpu_overloads;
    float peak_cpu_usage;
    
    // System state
    uint8_t system_initialized;
    uint8_t system_running;
    pthread_t processing_thread;
} AudioSystem;

static AudioSystem g_audio_system = {0};

// Forward declarations
static OSStatus audio_render_callback(void* inRefCon, AudioUnitRenderActionFlags* ioActionFlags,
                                     const AudioTimeStamp* inTimeStamp, UInt32 inBusNumber,
                                     UInt32 inNumberFrames, AudioBufferList* ioData);
static int load_hrtf_database(void);
static void calculate_hrtf_filter(float azimuth, float elevation, HRTFFilter* filter);
static void process_3d_audio_source(AudioSource* source, float* output_left, float* output_right, uint32_t frames);
static void apply_hrtf_filter(float* input, float* output_left, float* output_right, 
                             HRTFFilter* filter, float* delay_left, float* delay_right, uint32_t frames);
static void calculate_distance_attenuation(AudioSource* source);
static void calculate_doppler_shift(AudioSource* source);
static void process_reverb(ReverbProcessor* reverb, float* input, float* output, uint32_t frames);
static int ring_buffer_init(RingBuffer* rb, uint32_t size);
static void ring_buffer_cleanup(RingBuffer* rb);
static uint32_t ring_buffer_write(RingBuffer* rb, const float* data, uint32_t frames);
static uint32_t ring_buffer_read(RingBuffer* rb, float* data, uint32_t frames);
static void* audio_processing_thread(void* arg);

//==============================================================================
// SYSTEM INITIALIZATION
//==============================================================================

int audio_system_init(void) {
    if (g_audio_system.system_initialized) {
        return 0; // Already initialized
    }
    
    printf("Initializing spatial audio system...\n");
    
    // Initialize mutexes
    if (pthread_mutex_init(&g_audio_system.sources_mutex, NULL) != 0) {
        printf("Failed to initialize sources mutex\n");
        return -1;
    }
    
    // Setup audio format
    AudioStreamBasicDescription* format = &g_audio_system.audio_format;
    format->mSampleRate = SAMPLE_RATE;
    format->mFormatID = kAudioFormatLinearPCM;
    format->mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
    format->mBytesPerPacket = sizeof(float);
    format->mFramesPerPacket = 1;
    format->mBytesPerFrame = sizeof(float);
    format->mChannelsPerFrame = 2;
    format->mBitsPerChannel = 32;
    
    // Initialize ring buffers
    if (ring_buffer_init(&g_audio_system.master_left, RING_BUFFER_SIZE) != 0 ||
        ring_buffer_init(&g_audio_system.master_right, RING_BUFFER_SIZE) != 0) {
        printf("Failed to initialize ring buffers\n");
        return -1;
    }
    
    // Load HRTF database
    if (load_hrtf_database() != 0) {
        printf("Warning: Failed to load HRTF database, using simple panning\n");
    }
    
    // Initialize reverb processor
    ReverbProcessor* reverb = &g_audio_system.reverb;
    reverb->delay_buffer = malloc(REVERB_BUFFER_SIZE * sizeof(float));
    if (!reverb->delay_buffer) {
        printf("Failed to allocate reverb buffer\n");
        return -1;
    }
    memset(reverb->delay_buffer, 0, REVERB_BUFFER_SIZE * sizeof(float));
    reverb->delay_length = REVERB_BUFFER_SIZE;
    reverb->delay_pos = 0;
    reverb->feedback = 0.3f;
    reverb->wet_gain = 0.2f;
    reverb->dry_gain = 0.8f;
    reverb->damping = 0.5f;
    reverb->room_size = 0.7f;
    
    // Initialize listener
    AudioListener* listener = &g_audio_system.listener;
    listener->position = (Vector3){0, 0, 0};
    listener->forward = (Vector3){0, 0, -1};
    listener->up = (Vector3){0, 1, 0};
    listener->right = (Vector3){1, 0, 0};
    listener->velocity = (Vector3){0, 0, 0};
    listener->master_volume = 1.0f;
    listener->distance_factor = 1.0f;
    listener->doppler_factor = 1.0f;
    listener->speed_of_sound = 343.3f; // m/s
    
    // Create audio unit
    AudioComponentDescription desc = {
        .componentType = kAudioUnitType_Output,
        .componentSubType = kAudioUnitSubType_DefaultOutput,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0
    };
    
    AudioComponent component = AudioComponentFindNext(NULL, &desc);
    if (!component) {
        printf("Failed to find audio component\n");
        return -1;
    }
    
    OSStatus result = AudioComponentInstanceNew(component, &g_audio_system.output_unit);
    if (result != noErr) {
        printf("Failed to create audio unit: %d\n", result);
        return -1;
    }
    
    // Set audio format
    result = AudioUnitSetProperty(g_audio_system.output_unit, kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Input, 0, format, sizeof(*format));
    if (result != noErr) {
        printf("Failed to set audio format: %d\n", result);
        return -1;
    }
    
    // Set render callback
    AURenderCallbackStruct callback_struct = {
        .inputProc = audio_render_callback,
        .inputProcRefCon = &g_audio_system
    };
    
    result = AudioUnitSetProperty(g_audio_system.output_unit, kAudioUnitProperty_SetRenderCallback,
                                 kAudioUnitScope_Input, 0, &callback_struct, sizeof(callback_struct));
    if (result != noErr) {
        printf("Failed to set render callback: %d\n", result);
        return -1;
    }
    
    // Initialize audio unit
    result = AudioUnitInitialize(g_audio_system.output_unit);
    if (result != noErr) {
        printf("Failed to initialize audio unit: %d\n", result);
        return -1;
    }
    
    // Start audio processing thread
    g_audio_system.system_running = 1;
    if (pthread_create(&g_audio_system.processing_thread, NULL, audio_processing_thread, NULL) != 0) {
        printf("Failed to create audio processing thread\n");
        g_audio_system.system_running = 0;
        return -1;
    }
    
    // Start audio output
    result = AudioOutputUnitStart(g_audio_system.output_unit);
    if (result != noErr) {
        printf("Failed to start audio output: %d\n", result);
        g_audio_system.system_running = 0;
        pthread_join(g_audio_system.processing_thread, NULL);
        return -1;
    }
    
    g_audio_system.system_initialized = 1;
    printf("Spatial audio system initialized successfully\n");
    
    return 0;
}

void audio_system_shutdown(void) {
    if (!g_audio_system.system_initialized) {
        return;
    }
    
    printf("Shutting down spatial audio system...\n");
    
    // Stop audio processing
    g_audio_system.system_running = 0;
    
    // Stop audio unit
    if (g_audio_system.output_unit) {
        AudioOutputUnitStop(g_audio_system.output_unit);
        AudioUnitUninitialize(g_audio_system.output_unit);
        AudioComponentInstanceDispose(g_audio_system.output_unit);
    }
    
    // Wait for processing thread
    pthread_join(g_audio_system.processing_thread, NULL);
    
    // Cleanup ring buffers
    ring_buffer_cleanup(&g_audio_system.master_left);
    ring_buffer_cleanup(&g_audio_system.master_right);
    
    // Cleanup reverb
    if (g_audio_system.reverb.delay_buffer) {
        free(g_audio_system.reverb.delay_buffer);
    }
    
    // Cleanup HRTF database
    if (g_audio_system.hrtf_database) {
        free(g_audio_system.hrtf_database);
    }
    
    // Cleanup sources
    pthread_mutex_lock(&g_audio_system.sources_mutex);
    for (uint32_t i = 0; i < MAX_AUDIO_SOURCES; i++) {
        if (g_audio_system.sources[i].sample_data) {
            free(g_audio_system.sources[i].sample_data);
        }
    }
    pthread_mutex_unlock(&g_audio_system.sources_mutex);
    
    pthread_mutex_destroy(&g_audio_system.sources_mutex);
    
    memset(&g_audio_system, 0, sizeof(AudioSystem));
    printf("Audio system shutdown complete\n");
}

//==============================================================================
// AUDIO RENDERING CALLBACK
//==============================================================================

static OSStatus audio_render_callback(void* inRefCon, AudioUnitRenderActionFlags* ioActionFlags,
                                     const AudioTimeStamp* inTimeStamp, UInt32 inBusNumber,
                                     UInt32 inNumberFrames, AudioBufferList* ioData) {
    AudioSystem* audio_sys = (AudioSystem*)inRefCon;
    
    if (!audio_sys->system_running || inNumberFrames == 0) {
        // Silence output
        for (UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
            memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
        }
        return noErr;
    }
    
    float* left_output = (float*)ioData->mBuffers[0].mData;
    float* right_output = (float*)ioData->mBuffers[1].mData;
    
    // Read from ring buffers
    uint32_t samples_read_left = ring_buffer_read(&audio_sys->master_left, left_output, inNumberFrames);
    uint32_t samples_read_right = ring_buffer_read(&audio_sys->master_right, right_output, inNumberFrames);
    
    // Handle underruns
    if (samples_read_left < inNumberFrames || samples_read_right < inNumberFrames) {
        atomic_fetch_add(&audio_sys->buffer_underruns, 1);
        
        // Fill remaining with silence
        if (samples_read_left < inNumberFrames) {
            memset(left_output + samples_read_left, 0, (inNumberFrames - samples_read_left) * sizeof(float));
        }
        if (samples_read_right < inNumberFrames) {
            memset(right_output + samples_read_right, 0, (inNumberFrames - samples_read_right) * sizeof(float));
        }
    }
    
    // Apply master volume
    float master_vol = audio_sys->listener.master_volume;
    if (master_vol != 1.0f) {
        vDSP_vsmul(left_output, 1, &master_vol, left_output, 1, inNumberFrames);
        vDSP_vsmul(right_output, 1, &master_vol, right_output, 1, inNumberFrames);
    }
    
    atomic_fetch_add(&audio_sys->frames_processed, inNumberFrames);
    
    return noErr;
}

//==============================================================================
// AUDIO PROCESSING THREAD
//==============================================================================

static void* audio_processing_thread(void* arg) {
    printf("Audio processing thread started\n");
    
    float* mix_buffer_left = malloc(FRAME_SIZE * sizeof(float));
    float* mix_buffer_right = malloc(FRAME_SIZE * sizeof(float));
    float* temp_buffer = malloc(FRAME_SIZE * sizeof(float));
    
    if (!mix_buffer_left || !mix_buffer_right || !temp_buffer) {
        printf("Failed to allocate audio processing buffers\n");
        return NULL;
    }
    
    while (g_audio_system.system_running) {
        // Clear mix buffers
        memset(mix_buffer_left, 0, FRAME_SIZE * sizeof(float));
        memset(mix_buffer_right, 0, FRAME_SIZE * sizeof(float));
        
        pthread_mutex_lock(&g_audio_system.sources_mutex);
        
        // Process all active audio sources
        for (uint32_t i = 0; i < MAX_AUDIO_SOURCES; i++) {
            AudioSource* source = &g_audio_system.sources[i];
            
            if (source->state == AUDIO_STATE_PLAYING) {
                process_3d_audio_source(source, mix_buffer_left, mix_buffer_right, FRAME_SIZE);
            }
        }
        
        pthread_mutex_unlock(&g_audio_system.sources_mutex);
        
        // Apply reverb
        process_reverb(&g_audio_system.reverb, mix_buffer_left, temp_buffer, FRAME_SIZE);
        vDSP_vadd(mix_buffer_left, 1, temp_buffer, 1, mix_buffer_left, 1, FRAME_SIZE);
        
        process_reverb(&g_audio_system.reverb, mix_buffer_right, temp_buffer, FRAME_SIZE);
        vDSP_vadd(mix_buffer_right, 1, temp_buffer, 1, mix_buffer_right, 1, FRAME_SIZE);
        
        // Write to ring buffers
        ring_buffer_write(&g_audio_system.master_left, mix_buffer_left, FRAME_SIZE);
        ring_buffer_write(&g_audio_system.master_right, mix_buffer_right, FRAME_SIZE);
        
        // Sleep for frame duration
        usleep((FRAME_SIZE * 1000000) / SAMPLE_RATE);
    }
    
    free(mix_buffer_left);
    free(mix_buffer_right);
    free(temp_buffer);
    
    printf("Audio processing thread shutting down\n");
    return NULL;
}

//==============================================================================
// 3D AUDIO SOURCE PROCESSING
//==============================================================================

static void process_3d_audio_source(AudioSource* source, float* output_left, float* output_right, uint32_t frames) {
    if (!source->sample_data || source->sample_length == 0) {
        return;
    }
    
    // Calculate distance attenuation
    calculate_distance_attenuation(source);
    
    // Calculate doppler shift
    calculate_doppler_shift(source);
    
    // Calculate 3D position relative to listener
    Vector3 relative_pos = {
        source->position.x - g_audio_system.listener.position.x,
        source->position.y - g_audio_system.listener.position.y,
        source->position.z - g_audio_system.listener.position.z
    };
    
    // Calculate spherical coordinates for HRTF
    float distance = sqrtf(relative_pos.x * relative_pos.x + 
                          relative_pos.y * relative_pos.y + 
                          relative_pos.z * relative_pos.z);
    
    if (distance < MIN_AUDIO_DISTANCE) {
        distance = MIN_AUDIO_DISTANCE;
    }
    
    float azimuth = atan2f(relative_pos.x, -relative_pos.z) * 180.0f / M_PI;
    float elevation = asinf(relative_pos.y / distance) * 180.0f / M_PI;
    
    // Normalize azimuth to 0-360 range
    if (azimuth < 0) azimuth += 360.0f;
    
    // Calculate target HRTF filter
    HRTFFilter target_hrtf;
    calculate_hrtf_filter(azimuth, elevation, &target_hrtf);
    
    // Interpolate HRTF filters for smooth transitions
    if (source->hrtf_interpolation < 1.0f) {
        source->hrtf_interpolation += 0.05f; // Adjust interpolation speed
        if (source->hrtf_interpolation > 1.0f) {
            source->hrtf_interpolation = 1.0f;
        }
        
        float t = source->hrtf_interpolation;
        for (int i = 0; i < HRTF_FILTER_LENGTH; i++) {
            source->current_hrtf.left[i] = source->current_hrtf.left[i] * (1.0f - t) + target_hrtf.left[i] * t;
            source->current_hrtf.right[i] = source->current_hrtf.right[i] * (1.0f - t) + target_hrtf.right[i] * t;
        }
    } else {
        source->current_hrtf = target_hrtf;
    }
    
    // Process audio samples
    float* temp_buffer = malloc(frames * sizeof(float));
    if (!temp_buffer) return;
    
    uint32_t playback_pos = atomic_load(&source->playback_position);
    
    // Copy samples with volume and distance attenuation
    float volume = source->volume * source->distance_attenuation;
    
    for (uint32_t i = 0; i < frames; i++) {
        if (playback_pos >= source->sample_length) {
            if (source->looping) {
                playback_pos = source->loop_start;
            } else {
                source->state = AUDIO_STATE_STOPPED;
                break;
            }
        }
        
        temp_buffer[i] = source->sample_data[playback_pos] * volume;
        playback_pos++;
    }
    
    atomic_store(&source->playback_position, playback_pos);
    
    // Apply HRTF filtering
    apply_hrtf_filter(temp_buffer, output_left, output_right, 
                     &source->current_hrtf, 
                     source->hrtf_delay_left, 
                     source->hrtf_delay_right, 
                     frames);
    
    free(temp_buffer);
    
    source->samples_processed += frames;
}

//==============================================================================
// HRTF PROCESSING
//==============================================================================

static int load_hrtf_database(void) {
    // Allocate HRTF database
    g_audio_system.hrtf_database = malloc(HRTF_DATABASE_SIZE * sizeof(float));
    if (!g_audio_system.hrtf_database) {
        return -1;
    }
    
    // Generate simple HRTF approximation (in a real implementation, 
    // you would load from CIPIC database or similar)
    for (int az = 0; az < HRTF_AZIMUTH_STEPS; az++) {
        for (int el = 0; el < HRTF_ELEVATION_STEPS; el++) {
            int base_idx = (az * HRTF_ELEVATION_STEPS + el) * HRTF_FILTER_LENGTH * 2;
            
            // Simple head shadow simulation
            float azimuth_rad = (az * 5.0f) * M_PI / 180.0f;
            float elevation_rad = ((el - 18) * 5.0f) * M_PI / 180.0f;
            
            // Left ear
            float left_delay = sinf(azimuth_rad) * 0.0006f; // ~0.6ms max delay
            float left_gain = 1.0f - fabsf(sinf(azimuth_rad)) * 0.3f;
            
            // Right ear  
            float right_delay = -sinf(azimuth_rad) * 0.0006f;
            float right_gain = 1.0f + fabsf(sinf(azimuth_rad)) * 0.3f;
            
            for (int i = 0; i < HRTF_FILTER_LENGTH; i++) {
                // Simple impulse responses with delay and frequency shaping
                float t = (float)i / SAMPLE_RATE;
                
                // Left ear filter
                float left_impulse = 0.0f;
                if (i == (int)(left_delay * SAMPLE_RATE)) {
                    left_impulse = left_gain;
                }
                g_audio_system.hrtf_database[base_idx + i] = left_impulse;
                
                // Right ear filter
                float right_impulse = 0.0f;
                if (i == (int)(right_delay * SAMPLE_RATE)) {
                    right_impulse = right_gain;
                }
                g_audio_system.hrtf_database[base_idx + HRTF_FILTER_LENGTH + i] = right_impulse;
            }
        }
    }
    
    g_audio_system.hrtf_loaded = 1;
    printf("HRTF database loaded (%d filters)\n", HRTF_AZIMUTH_STEPS * HRTF_ELEVATION_STEPS);
    
    return 0;
}

static void calculate_hrtf_filter(float azimuth, float elevation, HRTFFilter* filter) {
    if (!g_audio_system.hrtf_loaded) {
        // Fallback to simple panning
        float pan = azimuth / 180.0f - 1.0f; // -1 to 1
        float left_gain = (1.0f - pan) * 0.5f;
        float right_gain = (1.0f + pan) * 0.5f;
        
        memset(filter, 0, sizeof(HRTFFilter));
        filter->left[0] = left_gain;
        filter->right[0] = right_gain;
        return;
    }
    
    // Quantize angles to database resolution
    int az_idx = (int)(azimuth / 5.0f) % HRTF_AZIMUTH_STEPS;
    int el_idx = (int)((elevation + 90.0f) / 5.0f);
    el_idx = el_idx < 0 ? 0 : (el_idx >= HRTF_ELEVATION_STEPS ? HRTF_ELEVATION_STEPS - 1 : el_idx);
    
    int base_idx = (az_idx * HRTF_ELEVATION_STEPS + el_idx) * HRTF_FILTER_LENGTH * 2;
    
    // Copy filter coefficients
    memcpy(filter->left, &g_audio_system.hrtf_database[base_idx], HRTF_FILTER_LENGTH * sizeof(float));
    memcpy(filter->right, &g_audio_system.hrtf_database[base_idx + HRTF_FILTER_LENGTH], HRTF_FILTER_LENGTH * sizeof(float));
}

static void apply_hrtf_filter(float* input, float* output_left, float* output_right, 
                             HRTFFilter* filter, float* delay_left, float* delay_right, uint32_t frames) {
    
    for (uint32_t i = 0; i < frames; i++) {
        float left_sample = 0.0f;
        float right_sample = 0.0f;
        
        // Shift delay lines
        memmove(delay_left + 1, delay_left, (HRTF_FILTER_LENGTH - 1) * sizeof(float));
        memmove(delay_right + 1, delay_right, (HRTF_FILTER_LENGTH - 1) * sizeof(float));
        
        delay_left[0] = input[i];
        delay_right[0] = input[i];
        
        // Convolve with HRTF filters
        vDSP_dotpr(delay_left, 1, filter->left, 1, &left_sample, HRTF_FILTER_LENGTH);
        vDSP_dotpr(delay_right, 1, filter->right, 1, &right_sample, HRTF_FILTER_LENGTH);
        
        output_left[i] += left_sample;
        output_right[i] += right_sample;
    }
}

//==============================================================================
// UTILITY FUNCTIONS
//==============================================================================

static void calculate_distance_attenuation(AudioSource* source) {
    Vector3 listener_pos = g_audio_system.listener.position;
    float distance = sqrtf(powf(source->position.x - listener_pos.x, 2) +
                          powf(source->position.y - listener_pos.y, 2) +
                          powf(source->position.z - listener_pos.z, 2));
    
    if (distance < MIN_AUDIO_DISTANCE) {
        distance = MIN_AUDIO_DISTANCE;
    }
    
    // Inverse square law with limits
    float attenuation = MIN_AUDIO_DISTANCE / distance;
    if (distance > MAX_AUDIO_DISTANCE) {
        attenuation = 0.0f;
    }
    
    source->distance_attenuation = attenuation * g_audio_system.listener.distance_factor;
}

static void calculate_doppler_shift(AudioSource* source) {
    // Calculate relative velocity
    Vector3 relative_velocity = {
        source->velocity.x - g_audio_system.listener.velocity.x,
        source->velocity.y - g_audio_system.listener.velocity.y,
        source->velocity.z - g_audio_system.listener.velocity.z
    };
    
    // Calculate direction to source
    Vector3 direction = {
        source->position.x - g_audio_system.listener.position.x,
        source->position.y - g_audio_system.listener.position.y,
        source->position.z - g_audio_system.listener.position.z
    };
    
    float distance = sqrtf(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z);
    if (distance > 0.0f) {
        direction.x /= distance;
        direction.y /= distance;
        direction.z /= distance;
        
        // Calculate radial velocity
        float radial_velocity = relative_velocity.x * direction.x +
                               relative_velocity.y * direction.y +
                               relative_velocity.z * direction.z;
        
        // Calculate doppler shift
        float speed_of_sound = g_audio_system.listener.speed_of_sound;
        float doppler_factor = g_audio_system.listener.doppler_factor;
        
        float pitch_shift = (speed_of_sound + radial_velocity * doppler_factor) / speed_of_sound;
        source->pitch = pitch_shift;
    }
}

static void process_reverb(ReverbProcessor* reverb, float* input, float* output, uint32_t frames) {
    for (uint32_t i = 0; i < frames; i++) {
        // Read delayed sample
        float delayed = reverb->delay_buffer[reverb->delay_pos];
        
        // Apply damping (simple low-pass filter)
        delayed *= reverb->damping;
        
        // Calculate feedback
        float feedback_sample = input[i] + delayed * reverb->feedback;
        
        // Write to delay buffer
        reverb->delay_buffer[reverb->delay_pos] = feedback_sample;
        
        // Advance delay position
        reverb->delay_pos = (reverb->delay_pos + 1) % reverb->delay_length;
        
        // Mix wet and dry signals
        output[i] = delayed * reverb->wet_gain;
    }
}

//==============================================================================
// RING BUFFER IMPLEMENTATION
//==============================================================================

static int ring_buffer_init(RingBuffer* rb, uint32_t size) {
    // Ensure size is power of 2
    uint32_t actual_size = 1;
    while (actual_size < size) {
        actual_size <<= 1;
    }
    
    rb->buffer = malloc(actual_size * sizeof(float));
    if (!rb->buffer) {
        return -1;
    }
    
    memset(rb->buffer, 0, actual_size * sizeof(float));
    rb->size = actual_size;
    rb->mask = actual_size - 1;
    atomic_store(&rb->write_pos, 0);
    atomic_store(&rb->read_pos, 0);
    
    return 0;
}

static void ring_buffer_cleanup(RingBuffer* rb) {
    if (rb->buffer) {
        free(rb->buffer);
        rb->buffer = NULL;
    }
}

static uint32_t ring_buffer_write(RingBuffer* rb, const float* data, uint32_t frames) {
    uint32_t write_pos = atomic_load(&rb->write_pos);
    uint32_t read_pos = atomic_load(&rb->read_pos);
    uint32_t available = rb->size - ((write_pos - read_pos) & rb->mask);
    
    if (available <= 1) {
        available = 0; // Leave one slot empty to distinguish full from empty
    } else {
        available--;
    }
    
    uint32_t to_write = frames < available ? frames : available;
    
    for (uint32_t i = 0; i < to_write; i++) {
        rb->buffer[write_pos & rb->mask] = data[i];
        write_pos++;
    }
    
    atomic_store(&rb->write_pos, write_pos);
    return to_write;
}

static uint32_t ring_buffer_read(RingBuffer* rb, float* data, uint32_t frames) {
    uint32_t write_pos = atomic_load(&rb->write_pos);
    uint32_t read_pos = atomic_load(&rb->read_pos);
    uint32_t available = (write_pos - read_pos) & rb->mask;
    
    uint32_t to_read = frames < available ? frames : available;
    
    for (uint32_t i = 0; i < to_read; i++) {
        data[i] = rb->buffer[read_pos & rb->mask];
        read_pos++;
    }
    
    atomic_store(&rb->read_pos, read_pos);
    return to_read;
}

//==============================================================================
// PUBLIC API
//==============================================================================

int audio_create_source(uint32_t* source_id, AudioSourceType type) {
    pthread_mutex_lock(&g_audio_system.sources_mutex);
    
    // Find available source slot
    for (uint32_t i = 0; i < MAX_AUDIO_SOURCES; i++) {
        if (g_audio_system.sources[i].state == AUDIO_STATE_STOPPED) {
            AudioSource* source = &g_audio_system.sources[i];
            memset(source, 0, sizeof(AudioSource));
            
            source->id = i;
            source->type = type;
            source->state = AUDIO_STATE_STOPPED;
            source->volume = 1.0f;
            source->pitch = 1.0f;
            source->distance_attenuation = 1.0f;
            
            *source_id = i;
            g_audio_system.active_sources++;
            
            pthread_mutex_unlock(&g_audio_system.sources_mutex);
            return 0;
        }
    }
    
    pthread_mutex_unlock(&g_audio_system.sources_mutex);
    printf("No available audio source slots\n");
    return -1;
}

int audio_play_source(uint32_t source_id) {
    if (source_id >= MAX_AUDIO_SOURCES) return -1;
    
    pthread_mutex_lock(&g_audio_system.sources_mutex);
    
    AudioSource* source = &g_audio_system.sources[source_id];
    source->state = AUDIO_STATE_PLAYING;
    atomic_store(&source->playback_position, 0);
    
    pthread_mutex_unlock(&g_audio_system.sources_mutex);
    return 0;
}

int audio_stop_source(uint32_t source_id) {
    if (source_id >= MAX_AUDIO_SOURCES) return -1;
    
    pthread_mutex_lock(&g_audio_system.sources_mutex);
    
    AudioSource* source = &g_audio_system.sources[source_id];
    source->state = AUDIO_STATE_STOPPED;
    atomic_store(&source->playback_position, 0);
    
    pthread_mutex_unlock(&g_audio_system.sources_mutex);
    return 0;
}

int audio_set_source_position(uint32_t source_id, float x, float y, float z) {
    if (source_id >= MAX_AUDIO_SOURCES) return -1;
    
    pthread_mutex_lock(&g_audio_system.sources_mutex);
    
    AudioSource* source = &g_audio_system.sources[source_id];
    source->position.x = x;
    source->position.y = y;
    source->position.z = z;
    
    // Reset HRTF interpolation for position changes
    source->hrtf_interpolation = 0.0f;
    
    pthread_mutex_unlock(&g_audio_system.sources_mutex);
    return 0;
}

int audio_set_listener_position(float x, float y, float z) {
    g_audio_system.listener.position.x = x;
    g_audio_system.listener.position.y = y;
    g_audio_system.listener.position.z = z;
    return 0;
}

int audio_set_listener_orientation(float forward_x, float forward_y, float forward_z,
                                  float up_x, float up_y, float up_z) {
    g_audio_system.listener.forward.x = forward_x;
    g_audio_system.listener.forward.y = forward_y;
    g_audio_system.listener.forward.z = forward_z;
    
    g_audio_system.listener.up.x = up_x;
    g_audio_system.listener.up.y = up_y;
    g_audio_system.listener.up.z = up_z;
    
    // Calculate right vector
    g_audio_system.listener.right.x = forward_y * up_z - forward_z * up_y;
    g_audio_system.listener.right.y = forward_z * up_x - forward_x * up_z;
    g_audio_system.listener.right.z = forward_x * up_y - forward_y * up_x;
    
    return 0;
}

void audio_set_master_volume(float volume) {
    g_audio_system.listener.master_volume = volume < 0.0f ? 0.0f : (volume > 1.0f ? 1.0f : volume);
}

void audio_get_performance_stats(uint32_t* frames_processed, uint32_t* buffer_underruns, 
                                uint32_t* cpu_overloads, float* peak_cpu_usage) {
    if (frames_processed) *frames_processed = atomic_load(&g_audio_system.frames_processed);
    if (buffer_underruns) *buffer_underruns = atomic_load(&g_audio_system.buffer_underruns);
    if (cpu_overloads) *cpu_overloads = atomic_load(&g_audio_system.cpu_overloads);
    if (peak_cpu_usage) *peak_cpu_usage = g_audio_system.peak_cpu_usage;
}

void audio_print_statistics(void) {
    uint32_t frames, underruns, overloads;
    float peak_cpu;
    audio_get_performance_stats(&frames, &underruns, &overloads, &peak_cpu);
    
    printf("\n=== Audio System Statistics ===\n");
    printf("Frames processed: %u\n", frames);
    printf("Buffer underruns: %u\n", underruns);
    printf("CPU overloads: %u\n", overloads);
    printf("Peak CPU usage: %.1f%%\n", peak_cpu);
    printf("Active sources: %u\n", g_audio_system.active_sources);
    printf("HRTF enabled: %s\n", g_audio_system.hrtf_loaded ? "Yes" : "No");
    printf("==============================\n\n");
}
