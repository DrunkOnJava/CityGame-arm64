// core_audio.s - Core Audio system setup and management for SimCity ARM64
// High-performance audio initialization with low-latency requirements
// Target: <10ms latency, hardware acceleration support

.section __TEXT,__text,regular,pure_instructions
.global _audio_core_init
.global _audio_core_shutdown
.global _audio_core_set_callback
.global _audio_core_start
.global _audio_core_stop
.global _audio_core_get_latency
.global _audio_core_write_buffer
.global _audio_core_read_buffer
.global _audio_core_get_buffer_stats
.align 2

// Audio constants
.equ SAMPLE_RATE, 44100
.equ FRAMES_PER_BUFFER, 128     // Low latency: 128 frames = ~2.9ms at 44.1kHz
.equ CHANNELS, 2                // Stereo output
.equ BITS_PER_SAMPLE, 32        // 32-bit float samples
.equ MAX_AUDIO_UNITS, 4         // Support multiple output units
.equ MAX_AUDIO_GRAPH_NODES, 8   // Maximum nodes in audio graph
.equ BUFFER_RING_SIZE, 4        // Circular buffer ring size

// AudioUnit property constants
.equ kAudioUnitProperty_StreamFormat, 8
.equ kAudioUnitProperty_SetRenderCallback, 23
.equ kAudioUnitProperty_MaximumFramesPerSlice, 14
.equ kAudioUnitProperty_SampleRate, 2
.equ kAudioUnitScope_Input, 1
.equ kAudioUnitScope_Output, 0
.equ kAudioUnitScope_Global, 0
.equ kAudioFormatFlagIsFloat, 1
.equ kAudioFormatFlagIsPacked, 2
.equ kAudioFormatFlagIsNonInterleaved, 4

// Audio graph constants
.equ kAUGraphErr_NodeNotFound, -10863
.equ kAUGraphErr_OutputNodeErr, -10862
.equ kAUGraphErr_InvalidConnection, -10861

// Data structures
.section __DATA,__data
.align 3

// Audio Unit instance storage
audio_unit_instances:
    .quad 0, 0, 0, 0            // Array of AudioUnit pointers

// Audio graph instance
audio_graph_instance:
    .quad 0                     // AUGraph pointer

// Audio graph nodes
audio_graph_nodes:
    .space MAX_AUDIO_GRAPH_NODES * 4    // Array of AUNode identifiers

// Audio format description
audio_format:
    .double 44100.0             // mSampleRate
    .long 0x6C70636D            // mFormatID ('lpcm')
    .long 0x00000009            // mFormatFlags (float, packed, non-interleaved)
    .long 8                     // mBytesPerPacket
    .long 1                     // mFramesPerPacket
    .long 4                     // mBytesPerFrame
    .long 2                     // mChannelsPerFrame
    .long 32                    // mBitsPerChannel
    .long 0                     // mReserved

// Callback function pointer
audio_callback_ptr:
    .quad 0

// Circular buffer management
audio_buffer_ring:
    .space BUFFER_RING_SIZE * FRAMES_PER_BUFFER * CHANNELS * 4  // Ring buffer

buffer_write_index:
    .long 0

buffer_read_index:
    .long 0

buffer_available_frames:
    .long 0

// Performance metrics
audio_latency_samples:
    .long FRAMES_PER_BUFFER

audio_underruns:
    .quad 0

audio_overruns:
    .quad 0

frames_processed:
    .quad 0

// System state
audio_system_active:
    .long 0

graph_initialized:
    .long 0

.section __TEXT,__text

// Initialize Core Audio system
// Returns: x0 = 0 on success, error code on failure
_audio_core_init:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    // Check if already initialized
    adrp x19, audio_system_active@PAGE
    add x19, x19, audio_system_active@PAGEOFF
    ldr w0, [x19]
    cbnz w0, init_already_done
    
    // Initialize audio graph
    bl create_audio_graph
    cbnz x0, init_error
    
    // Initialize first audio unit (main output)
    mov x0, #0                  // Unit index
    bl create_audio_unit
    cbnz x0, init_error
    
    // Configure audio format
    bl configure_audio_format
    cbnz x0, init_error
    
    // Set up render callback
    bl setup_render_callback
    cbnz x0, init_error
    
    // Configure for low latency
    bl configure_low_latency
    cbnz x0, init_error
    
    // Initialize circular buffer system
    bl init_circular_buffers
    cbnz x0, init_error
    
    // Mark system as active
    mov w0, #1
    str w0, [x19]
    
    mov x0, #0                  // Success
    b init_done

init_already_done:
    mov x0, #-1                 // Already initialized
    b init_done

init_error:
    // Clean up on error
    bl _audio_core_shutdown
    mov x0, #-2                 // Initialization failed

init_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Create and initialize an AudioUnit
// x0 = unit index
// Returns: x0 = 0 on success, error code on failure
create_audio_unit:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    
    mov x19, x0                 // Save unit index
    
    // Allocate space for AudioUnit on stack
    sub sp, sp, #16
    mov x20, sp                 // x20 = pointer to AudioUnit storage
    
    // Create AudioComponentDescription for default output
    sub sp, sp, #32
    mov x21, sp
    
    // Set up component description based on unit index
    cmp x19, #0
    b.eq setup_output_unit
    cmp x19, #1
    b.eq setup_mixer_unit
    cmp x19, #2
    b.eq setup_converter_unit
    b setup_output_unit         // Default to output

setup_output_unit:
    // Default Audio Output Unit
    mov w0, #0x61756F75          // 'auou' - Audio Unit Output
    str w0, [x21]
    mov w0, #0x64656675          // 'defo' - Default Output  
    str w0, [x21, #4]
    mov w0, #0x6170706C          // 'appl' - Apple
    str w0, [x21, #8]
    str wzr, [x21, #12]          // componentFlags
    str wzr, [x21, #16]          // componentFlagsMask
    b find_component

setup_mixer_unit:
    // MultiChannel Mixer Unit
    mov w0, #0x61756D78          // 'aumx' - Audio Unit Mixer
    str w0, [x21]
    mov w0, #0x6D636D78          // 'mcmx' - MultiChannel Mixer
    str w0, [x21, #4]
    mov w0, #0x6170706C          // 'appl' - Apple
    str w0, [x21, #8]
    str wzr, [x21, #12]          // componentFlags
    str wzr, [x21, #16]          // componentFlagsMask
    b find_component

setup_converter_unit:
    // Format Converter Unit
    mov w0, #0x61756663          // 'aufc' - Audio Unit Format Converter
    str w0, [x21]
    mov w0, #0x636F6E76          // 'conv' - Converter
    str w0, [x21, #4]
    mov w0, #0x6170706C          // 'appl' - Apple
    str w0, [x21, #8]
    str wzr, [x21, #12]          // componentFlags
    str wzr, [x21, #16]          // componentFlagsMask

find_component:
    // Find the component
    mov x0, xzr                 // NULL to start search
    mov x1, x21                 // AudioComponentDescription
    bl AudioComponentFindNext
    cbz x0, create_unit_error
    mov x22, x0                 // Save component reference
    
    // Create the AudioUnit instance
    mov x0, x22                 // Component
    mov x1, x20                 // Destination for AudioUnit
    bl AudioComponentInstanceNew
    cbnz x0, create_unit_error
    
    // Store the AudioUnit instance
    adrp x1, audio_unit_instances@PAGE
    add x1, x1, audio_unit_instances@PAGEOFF
    ldr x2, [x20]               // Load AudioUnit pointer
    str x2, [x1, x19, lsl #3]   // Store in array
    
    // Get component information for debugging
    mov x0, x22                 // Component
    sub sp, sp, #32             // Space for ComponentDescription
    mov x1, sp
    bl AudioComponentGetDescription
    
    // Additional setup based on unit type
    ldr x23, [x20]              // AudioUnit instance
    cmp x19, #1                 // Mixer unit?
    b.eq setup_mixer_properties
    cmp x19, #2                 // Converter unit?
    b.eq setup_converter_properties
    b unit_setup_complete

setup_mixer_properties:
    // Set mixer input count
    mov x0, x23                 // AudioUnit
    mov x1, #4                  // kAudioUnitProperty_ElementCount
    mov x2, #kAudioUnitScope_Input
    mov x3, #0                  // Element
    sub sp, sp, #8
    mov w4, #4                  // 4 input channels
    str w4, [sp]
    mov x4, sp
    mov x5, #4                  // Size
    bl AudioUnitSetProperty
    add sp, sp, #8
    b unit_setup_complete

setup_converter_properties:
    // Converter properties can be set here if needed
    b unit_setup_complete

unit_setup_complete:
    add sp, sp, #32             // Clean up component description
    add sp, sp, #48             // Clean up stack
    mov x0, #0                  // Success
    b create_unit_done

create_unit_error:
    add sp, sp, #32             // Clean up component description
    add sp, sp, #48             // Clean up stack
    mov x0, #-1                 // Error

create_unit_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// Configure audio format for low-latency operation
// Returns: x0 = 0 on success, error code on failure
configure_audio_format:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Get the main AudioUnit
    adrp x0, audio_unit_instances@PAGE
    add x0, x0, audio_unit_instances@PAGEOFF
    ldr x0, [x0]                // Load first AudioUnit
    cbz x0, config_format_error
    
    // Set the stream format
    mov x1, #kAudioUnitProperty_StreamFormat
    mov x2, #kAudioUnitScope_Input
    mov x3, #0                  // Element 0
    adrp x4, audio_format@PAGE
    add x4, x4, audio_format@PAGEOFF
    mov x5, #40                 // Size of AudioStreamBasicDescription
    bl AudioUnitSetProperty
    cbnz x0, config_format_error
    
    // Set maximum frames per slice for low latency
    mov x1, #kAudioUnitProperty_MaximumFramesPerSlice
    mov x2, #kAudioUnitScope_Global
    mov x3, #0
    adrp x4, audio_latency_samples@PAGE
    add x4, x4, audio_latency_samples@PAGEOFF
    mov x5, #4
    bl AudioUnitSetProperty
    cbnz x0, config_format_error
    
    mov x0, #0                  // Success
    b config_format_done

config_format_error:
    mov x0, #-1                 // Error

config_format_done:
    ldp x29, x30, [sp], #16
    ret

// Set up the render callback for audio processing
// Returns: x0 = 0 on success, error code on failure
setup_render_callback:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    
    // Get the main AudioUnit
    adrp x0, audio_unit_instances@PAGE
    add x0, x0, audio_unit_instances@PAGEOFF
    ldr x0, [x0]
    cbz x0, setup_callback_error
    
    // Create AURenderCallbackStruct on stack
    sub sp, sp, #16
    adr x1, audio_render_callback
    str x1, [sp]                // inputProc
    str xzr, [sp, #8]           // inputProcRefCon
    
    // Set the render callback
    mov x1, #kAudioUnitProperty_SetRenderCallback
    mov x2, #kAudioUnitScope_Input
    mov x3, #0
    mov x4, sp                  // Callback struct
    mov x5, #16                 // Size of struct
    bl AudioUnitSetProperty
    
    add sp, sp, #16             // Clean up stack
    cbnz x0, setup_callback_error
    
    mov x0, #0                  // Success
    b setup_callback_done

setup_callback_error:
    mov x0, #-1                 // Error

setup_callback_done:
    ldp x29, x30, [sp], #32
    ret

// Configure system for low-latency operation
// Returns: x0 = 0 on success, error code on failure
configure_low_latency:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Initialize the AudioUnit
    adrp x0, audio_unit_instances@PAGE
    add x0, x0, audio_unit_instances@PAGEOFF
    ldr x0, [x0]
    cbz x0, config_latency_error
    
    bl AudioUnitInitialize
    cbnz x0, config_latency_error
    
    mov x0, #0                  // Success
    b config_latency_done

config_latency_error:
    mov x0, #-1                 // Error

config_latency_done:
    ldp x29, x30, [sp], #16
    ret

// Main audio render callback - called by Core Audio for each buffer
// This is the critical path for low-latency audio
audio_render_callback:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    
    // x0 = inRefCon
    // x1 = ioActionFlags  
    // x2 = inTimeStamp
    // x3 = inBusNumber
    // x4 = inNumberFrames
    // x5 = ioData (AudioBufferList)
    
    mov x19, x4                 // Number of frames
    mov x20, x5                 // AudioBufferList
    mov x21, x2                 // TimeStamp
    
    // Update performance metrics
    adrp x22, frames_processed@PAGE
    add x22, x22, frames_processed@PAGEOFF
    ldr x23, [x22]
    add x23, x23, x19
    str x23, [x22]
    
    // Check for buffer availability from circular buffer
    adrp x22, buffer_available_frames@PAGE
    add x22, x22, buffer_available_frames@PAGEOFF
    ldr w23, [x22]
    cmp w23, w19                // Do we have enough frames?
    b.lt render_underrun        // Not enough data
    
    // Read from circular buffer
    ldr x24, [x20, #8]          // First buffer mData pointer
    mov x0, x24                 // Destination
    mov x1, x19                 // Frame count
    bl _audio_core_read_buffer
    
    // Check if we successfully read enough frames
    cmp w0, w19
    b.eq render_success
    
    // Partial read - fill remainder with silence
    lsl w1, w0, #3              // Read frames * 8 bytes
    add x1, x24, x1             // Start of unfilled area
    sub w2, w19, w0             // Remaining frames
    lsl w2, w2, #3              // Convert to bytes
    mov x0, x1
    mov x1, #0
    bl memset
    b render_success

render_underrun:
    // Handle underrun - try user callback first
    adrp x22, audio_callback_ptr@PAGE
    add x22, x22, audio_callback_ptr@PAGEOFF
    ldr x22, [x22]
    cbz x22, render_silence     // No callback, render silence
    
    // Call user callback as fallback
    mov x0, x20                 // AudioBufferList
    mov x1, x19                 // Frame count
    blr x22
    b render_done

render_silence:
    // Clear the output buffers
    ldr w22, [x20]              // mNumberBuffers
    add x23, x20, #4            // First AudioBuffer
    
clear_loop:
    cbz w22, render_done
    ldr x24, [x23, #8]          // mData pointer
    ldr w21, [x23, #4]          // mDataByteSize
    
    // Clear buffer to silence
    mov x0, x24
    mov x1, #0
    mov x2, x21
    bl memset
    
    add x23, x23, #16           // Next AudioBuffer
    sub w22, w22, #1
    b clear_loop

render_success:
    // Check if we need additional processing (3D audio, effects, etc.)
    adrp x22, audio_callback_ptr@PAGE
    add x22, x22, audio_callback_ptr@PAGEOFF
    ldr x22, [x22]
    cbz x22, render_done        // No additional processing
    
    // Call user callback for post-processing
    mov x0, x20                 // AudioBufferList
    mov x1, x19                 // Frame count
    blr x22

render_done:
    mov x0, #0                  // noErr
    
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// Set the audio callback function
// x0 = callback function pointer
_audio_core_set_callback:
    adrp x1, audio_callback_ptr@PAGE
    add x1, x1, audio_callback_ptr@PAGEOFF
    str x0, [x1]
    ret

// Start audio processing
// Returns: x0 = 0 on success, error code on failure
_audio_core_start:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Check if system is initialized
    adrp x1, audio_system_active@PAGE
    add x1, x1, audio_system_active@PAGEOFF
    ldr w1, [x1]
    cbz w1, start_error
    
    // Start the AudioUnit
    adrp x0, audio_unit_instances@PAGE
    add x0, x0, audio_unit_instances@PAGEOFF
    ldr x0, [x0]
    cbz x0, start_error
    
    bl AudioOutputUnitStart
    cbnz x0, start_error
    
    mov x0, #0                  // Success
    b start_done

start_error:
    mov x0, #-1                 // Error

start_done:
    ldp x29, x30, [sp], #16
    ret

// Stop audio processing
// Returns: x0 = 0 on success, error code on failure
_audio_core_stop:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Stop the AudioUnit
    adrp x0, audio_unit_instances@PAGE
    add x0, x0, audio_unit_instances@PAGEOFF
    ldr x0, [x0]
    cbz x0, stop_done           // Already stopped
    
    bl AudioOutputUnitStop
    mov x0, #0                  // Always return success

stop_done:
    ldp x29, x30, [sp], #16
    ret

// Get current audio latency in samples
// Returns: x0 = latency in samples
_audio_core_get_latency:
    adrp x0, audio_latency_samples@PAGE
    add x0, x0, audio_latency_samples@PAGEOFF
    ldr w0, [x0]
    ret

// Shutdown Core Audio system
_audio_core_shutdown:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    // Stop audio first
    bl _audio_core_stop
    
    // Uninitialize and dispose of AudioUnits
    adrp x19, audio_unit_instances@PAGE
    add x19, x19, audio_unit_instances@PAGEOFF
    mov x20, #0                 // Index counter
    
cleanup_loop:
    cmp x20, #MAX_AUDIO_UNITS
    b.ge cleanup_done
    
    ldr x0, [x19, x20, lsl #3]  // Load AudioUnit pointer
    cbz x0, cleanup_next        // Skip if null
    
    // Uninitialize the unit
    bl AudioUnitUninitialize
    
    // Dispose of the unit
    ldr x0, [x19, x20, lsl #3]
    bl AudioComponentInstanceDispose
    
    // Clear the pointer
    str xzr, [x19, x20, lsl #3]
    
cleanup_next:
    add x20, x20, #1
    b cleanup_loop

cleanup_done:
    // Mark system as inactive
    adrp x0, audio_system_active@PAGE
    add x0, x0, audio_system_active@PAGEOFF
    str wzr, [x0]
    
    // Clear callback pointer
    adrp x0, audio_callback_ptr@PAGE
    add x0, x0, audio_callback_ptr@PAGEOFF
    str xzr, [x0]
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Create and initialize audio graph
// Returns: x0 = 0 on success, error code on failure
create_audio_graph:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    
    // Create AUGraph
    adrp x19, audio_graph_instance@PAGE
    add x19, x19, audio_graph_instance@PAGEOFF
    mov x0, x19                 // Destination for AUGraph
    bl NewAUGraph
    cbnz x0, create_graph_error
    
    // Open the graph
    ldr x0, [x19]               // Load AUGraph instance
    bl AUGraphOpen
    cbnz x0, create_graph_error
    
    // Mark graph as initialized
    adrp x0, graph_initialized@PAGE
    add x0, x0, graph_initialized@PAGEOFF
    mov w1, #1
    str w1, [x0]
    
    mov x0, #0                  // Success
    b create_graph_done

create_graph_error:
    mov x0, #-1                 // Error

create_graph_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Initialize circular buffer system
// Returns: x0 = 0 on success, error code on failure
init_circular_buffers:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Clear buffer ring
    adrp x0, audio_buffer_ring@PAGE
    add x0, x0, audio_buffer_ring@PAGEOFF
    mov x1, #0
    mov x2, #BUFFER_RING_SIZE * FRAMES_PER_BUFFER * CHANNELS * 4
    bl memset
    
    // Reset buffer indices
    adrp x0, buffer_write_index@PAGE
    add x0, x0, buffer_write_index@PAGEOFF
    str wzr, [x0]               // write_index = 0
    
    adrp x0, buffer_read_index@PAGE
    add x0, x0, buffer_read_index@PAGEOFF
    str wzr, [x0]               // read_index = 0
    
    adrp x0, buffer_available_frames@PAGE
    add x0, x0, buffer_available_frames@PAGEOFF
    str wzr, [x0]               // available_frames = 0
    
    mov x0, #0                  // Success
    ldp x29, x30, [sp], #16
    ret

// Write audio data to circular buffer
// x0 = source buffer pointer
// x1 = number of frames
// Returns: x0 = frames actually written
_audio_core_write_buffer:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    mov x19, x0                 // Source buffer
    mov w20, w1                 // Frame count
    
    // Check available space
    adrp x21, buffer_available_frames@PAGE
    add x21, x21, buffer_available_frames@PAGEOFF
    ldr w0, [x21]
    mov w1, #BUFFER_RING_SIZE * FRAMES_PER_BUFFER
    sub w1, w1, w0              // Available space
    cmp w20, w1
    csel w20, w1, w20, gt       // Limit to available space
    
    cbz w20, write_buffer_done  // Nothing to write
    
    // Get write position
    adrp x22, buffer_write_index@PAGE
    add x22, x22, buffer_write_index@PAGEOFF
    ldr w0, [x22]               // Current write index
    
    // Calculate write address
    adrp x1, audio_buffer_ring@PAGE
    add x1, x1, audio_buffer_ring@PAGEOFF
    mov w2, #CHANNELS * 4       // Bytes per frame
    umull x2, w0, w2
    add x1, x1, x2              // Write address
    
    // Copy data (simplified - assumes same format)
    mov x0, x1                  // Destination
    mov x1, x19                 // Source
    lsl w2, w20, #3             // frames * 8 bytes (stereo float)
    bl memcpy
    
    // Update write index
    ldr w0, [x22]
    add w0, w0, w20
    mov w1, #BUFFER_RING_SIZE * FRAMES_PER_BUFFER
    udiv w2, w0, w1             // Quotient
    msub w0, w2, w1, w0         // Remainder (modulo)
    str w0, [x22]
    
    // Update available frames
    ldr w0, [x21]
    add w0, w0, w20
    str w0, [x21]
    
write_buffer_done:
    mov w0, w20                 // Return frames written
    
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Read audio data from circular buffer
// x0 = destination buffer pointer
// x1 = number of frames requested
// Returns: x0 = frames actually read
_audio_core_read_buffer:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    
    mov x19, x0                 // Destination buffer
    mov w20, w1                 // Frame count
    
    // Check available data
    adrp x21, buffer_available_frames@PAGE
    add x21, x21, buffer_available_frames@PAGEOFF
    ldr w0, [x21]
    cmp w20, w0
    csel w20, w0, w20, gt       // Limit to available data
    
    cbz w20, read_buffer_underrun // Nothing available
    
    // Get read position
    adrp x22, buffer_read_index@PAGE
    add x22, x22, buffer_read_index@PAGEOFF
    ldr w0, [x22]               // Current read index
    
    // Calculate read address
    adrp x1, audio_buffer_ring@PAGE
    add x1, x1, audio_buffer_ring@PAGEOFF
    mov w2, #CHANNELS * 4       // Bytes per frame
    umull x2, w0, w2
    add x1, x1, x2              // Read address
    
    // Copy data
    mov x0, x19                 // Destination
    lsl w2, w20, #3             // frames * 8 bytes (stereo float)
    bl memcpy
    
    // Update read index
    ldr w0, [x22]
    add w0, w0, w20
    mov w1, #BUFFER_RING_SIZE * FRAMES_PER_BUFFER
    udiv w2, w0, w1             // Quotient
    msub w0, w2, w1, w0         // Remainder (modulo)
    str w0, [x22]
    
    // Update available frames
    ldr w0, [x21]
    sub w0, w0, w20
    str w0, [x21]
    
    b read_buffer_done

read_buffer_underrun:
    // Handle underrun
    adrp x0, audio_underruns@PAGE
    add x0, x0, audio_underruns@PAGEOFF
    ldr x1, [x0]
    add x1, x1, #1
    str x1, [x0]
    
    // Clear output buffer
    mov x0, x19
    mov x1, #0
    lsl w2, w20, #3
    bl memset
    
read_buffer_done:
    mov w0, w20                 // Return frames read
    
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Get buffer statistics
// Returns: x0 = available frames, x1 = underruns, x2 = overruns
_audio_core_get_buffer_stats:
    adrp x0, buffer_available_frames@PAGE
    add x0, x0, buffer_available_frames@PAGEOFF
    ldr w0, [x0]
    
    adrp x1, audio_underruns@PAGE
    add x1, x1, audio_underruns@PAGEOFF
    ldr x1, [x1]
    
    adrp x2, audio_overruns@PAGE
    add x2, x2, audio_overruns@PAGEOFF
    ldr x2, [x2]
    
    ret

// External function declarations (Core Audio framework)
.extern AudioComponentFindNext
.extern AudioComponentInstanceNew
.extern AudioComponentInstanceDispose
.extern AudioComponentGetDescription
.extern AudioUnitSetProperty
.extern AudioUnitInitialize
.extern AudioUnitUninitialize
.extern AudioOutputUnitStart
.extern AudioOutputUnitStop
.extern NewAUGraph
.extern AUGraphOpen
.extern AUGraphClose
.extern AUGraphUninitialize
.extern AUGraphStart
.extern AUGraphStop
.extern memset
.extern memcpy