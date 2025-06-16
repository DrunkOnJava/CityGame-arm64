//
// Time System Stubs for Testing
// These are simplified C implementations for testing the UI integration
//

#include <stdio.h>
#include <time.h>
#include <stdlib.h>

// Global time state
static struct {
    int year;
    int month; 
    int day;
    int hour;
    int minute;
    int second;
    int paused;
    int speed_index;
    float time_scale;
    double last_update_time;
    double simulation_time;
} time_state = {
    .year = 2000,
    .month = 1,
    .day = 1,
    .hour = 8,
    .minute = 0,
    .second = 0,
    .paused = 0,
    .speed_index = 1,
    .time_scale = 1.0f,
    .last_update_time = 0.0,
    .simulation_time = 0.0
};

// Available speed multipliers
static float speed_multipliers[] = {0.0f, 1.0f, 2.0f, 3.0f, 10.0f, 50.0f, 100.0f, 1000.0f};
static int speed_count = 8;

double get_current_time_seconds() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1000000000.0;
}

void time_system_init(int year, int month, int day, float scale) {
    printf("🕰️ Time system initialized: %d/%d/%d, scale: %.1f\n", month, day, year, scale);
    
    time_state.year = year;
    time_state.month = month;
    time_state.day = day;
    time_state.hour = 8;
    time_state.minute = 0;
    time_state.second = 0;
    time_state.paused = 0;
    time_state.speed_index = 1;
    time_state.time_scale = 1.0f;
    time_state.last_update_time = get_current_time_seconds();
    time_state.simulation_time = 0.0;
}

void time_system_update(void) {
    if (time_state.paused) {
        time_state.last_update_time = get_current_time_seconds();
        return;
    }
    
    double current_time = get_current_time_seconds();
    double delta_time = current_time - time_state.last_update_time;
    time_state.last_update_time = current_time;
    
    // Apply time scaling
    double scaled_delta = delta_time * time_state.time_scale;
    time_state.simulation_time += scaled_delta;
    
    // Convert to game time (accelerated)
    int total_seconds = (int)(time_state.simulation_time * 60.0); // 1 real second = 1 game minute
    
    int new_second = total_seconds % 60;
    int new_minute = (total_seconds / 60) % 60;
    int new_hour = (total_seconds / 3600) % 24;
    int new_day = (total_seconds / 86400) + 1;
    
    // Simple month/year calculation
    int new_month = ((new_day - 1) / 30) + 1;
    int new_year = time_state.year + ((new_month - 1) / 12);
    new_month = ((new_month - 1) % 12) + 1;
    new_day = ((new_day - 1) % 30) + 1;
    
    // Update if changed
    if (new_day != time_state.day || new_month != time_state.month || new_year != time_state.year) {
        printf("📅 Date changed: %d/%d/%d %02d:%02d\n", new_month, new_day, new_year, new_hour, new_minute);
    }
    
    time_state.second = new_second;
    time_state.minute = new_minute;
    time_state.hour = new_hour;
    time_state.day = new_day;
    time_state.month = new_month;
    time_state.year = new_year;
}

void time_system_pause(int pause) {
    time_state.paused = pause;
    printf("⏸️ Time system %s\n", pause ? "paused" : "resumed");
}

void time_system_set_speed(int speed_index) {
    if (speed_index < 0 || speed_index >= speed_count) return;
    
    time_state.speed_index = speed_index;
    time_state.time_scale = speed_multipliers[speed_index];
    time_state.paused = (speed_index == 0);
    
    printf("⚡ Time speed set to index %d (%.1fx)\n", speed_index, time_state.time_scale);
}

int time_system_get_speed(void) {
    return time_state.speed_index;
}

void time_system_cycle_speed(void) {
    int new_speed = (time_state.speed_index + 1) % speed_count;
    time_system_set_speed(new_speed);
}

int time_system_get_season(void) {
    // Simple season calculation: 0=Winter, 1=Spring, 2=Summer, 3=Fall
    return (time_state.month - 1) / 3;
}

// Additional functions for getting time information
int time_system_get_year(void) { return time_state.year; }
int time_system_get_month(void) { return time_state.month; }
int time_system_get_day(void) { return time_state.day; }
int time_system_get_hour(void) { return time_state.hour; }
int time_system_get_minute(void) { return time_state.minute; }
int time_system_get_second(void) { return time_state.second; }
int time_system_is_paused(void) { return time_state.paused; }
float time_system_get_scale(void) { return time_state.time_scale; }