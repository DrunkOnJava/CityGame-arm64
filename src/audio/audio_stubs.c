#include <stdio.h>

// Audio system stubs
int core_audio_init(void) { printf("Audio: Core audio initialized\n"); return 0; }
int spatial_audio_init(void) { return 0; }
int sound_mixer_init(void) { return 0; }
void audio_update(void) { /* Update audio */ }
void audio_shutdown(void) {}
