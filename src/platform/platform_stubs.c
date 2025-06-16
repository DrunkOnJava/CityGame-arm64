#include <stdio.h>
#include <unistd.h>
#include <time.h>
#include <stddef.h>

// Platform initialization stubs
int bootstrap_init(void) { printf("Platform: Bootstrap initialized\n"); return 0; }
int syscalls_init(void) { printf("Platform: Syscalls initialized\n"); return 0; }
int threads_init(void) { printf("Platform: Threading initialized\n"); return 0; }
int objc_bridge_init(void) { printf("Platform: Objective-C bridge initialized\n"); return 0; }

int should_exit_game(void) {
    static int frame_count = 0;
    frame_count++;
    return frame_count > 600; // Exit after 10 seconds at 60fps
}

void print_error(const char* msg) {
    fprintf(stderr, "%s", msg);
}

long long get_current_time_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000000000LL + ts.tv_nsec;
}

void calculate_frame_time(void) {
    // Stub
}

void platform_shutdown(void) {}
void memory_shutdown(void) {}
void core_shutdown(void) {}
