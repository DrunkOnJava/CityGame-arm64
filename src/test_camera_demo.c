#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <math.h>
#include <mach/mach_time.h>
#include <Carbon/Carbon.h>

// Input state structure matching assembly layout
typedef struct {
    uint32_t keys;              // 0x00 - Keyboard bitmask
    uint32_t _pad1;
    uint32_t _pad2;
    uint32_t _pad3;
    int32_t mouse_x;            // 0x10
    int32_t mouse_y;            // 0x14
    int32_t mouse_delta_x;      // 0x18
    int32_t mouse_delta_y;      // 0x1C
    uint32_t mouse_buttons;     // 0x20
    int16_t scroll_y;           // 0x24
    uint16_t _pad4;
} InputState;

// Camera state structure (matches assembly)
typedef struct {
    float iso_x, iso_y;
    float world_x, world_z;
    float height;
    float rotation;
    float vel_x, vel_z;
    float zoom_vel;
    float rot_vel;
    float edge_pan_x, edge_pan_z;
    uint32_t bounce_timer;
    uint32_t _padding[3];
} CameraState;

// Key bit positions
#define KEY_UP    0
#define KEY_DOWN  1
#define KEY_LEFT  2
#define KEY_RIGHT 3
#define KEY_SHIFT 4
#define KEY_W     5
#define KEY_A     6
#define KEY_S     7
#define KEY_D     8

// External assembly functions
extern void camera_update(InputState* input, float delta_time);
extern void camera_get_world_position(void); // Returns in s0,s1,s2
extern CameraState camera_state;  // Direct access to global state

// Global input state
static InputState g_input = {0};
static int g_last_mouse_x = 0;
static int g_last_mouse_y = 0;
static int g_running = 1;

// Event handler callback
static OSStatus HandleKeyEvent(EventHandlerCallRef handler, EventRef event, void* userData) {
    UInt32 keyCode;
    GetEventParameter(event, kEventParamKeyCode, typeUInt32, NULL, sizeof(keyCode), NULL, &keyCode);
    
    UInt32 eventKind = GetEventKind(event);
    int pressed = (eventKind == kEventRawKeyDown);
    
    // Map key codes to our bit positions
    switch(keyCode) {
        case 126: // Up arrow
            if (pressed) g_input.keys |= (1 << KEY_UP);
            else g_input.keys &= ~(1 << KEY_UP);
            break;
        case 125: // Down arrow
            if (pressed) g_input.keys |= (1 << KEY_DOWN);
            else g_input.keys &= ~(1 << KEY_DOWN);
            break;
        case 123: // Left arrow
            if (pressed) g_input.keys |= (1 << KEY_LEFT);
            else g_input.keys &= ~(1 << KEY_LEFT);
            break;
        case 124: // Right arrow
            if (pressed) g_input.keys |= (1 << KEY_RIGHT);
            else g_input.keys &= ~(1 << KEY_RIGHT);
            break;
        case 56: // Shift
            if (pressed) g_input.keys |= (1 << KEY_SHIFT);
            else g_input.keys &= ~(1 << KEY_SHIFT);
            break;
        case 13: // W
            if (pressed) g_input.keys |= (1 << KEY_W);
            else g_input.keys &= ~(1 << KEY_W);
            break;
        case 0: // A
            if (pressed) g_input.keys |= (1 << KEY_A);
            else g_input.keys &= ~(1 << KEY_A);
            break;
        case 1: // S
            if (pressed) g_input.keys |= (1 << KEY_S);
            else g_input.keys &= ~(1 << KEY_S);
            break;
        case 2: // D
            if (pressed) g_input.keys |= (1 << KEY_D);
            else g_input.keys &= ~(1 << KEY_D);
            break;
        case 53: // ESC
            if (pressed) g_running = 0;
            break;
    }
    
    return noErr;
}

static OSStatus HandleMouseEvent(EventHandlerCallRef handler, EventRef event, void* userData) {
    HIPoint mouseLoc;
    GetEventParameter(event, kEventParamMouseLocation, typeHIPoint, NULL, sizeof(mouseLoc), NULL, &mouseLoc);
    
    UInt32 eventKind = GetEventKind(event);
    
    // Update mouse position
    g_input.mouse_x = (int32_t)mouseLoc.x;
    g_input.mouse_y = (int32_t)mouseLoc.y;
    
    // Calculate delta
    if (g_last_mouse_x != 0 || g_last_mouse_y != 0) {
        g_input.mouse_delta_x = g_input.mouse_x - g_last_mouse_x;
        g_input.mouse_delta_y = g_input.mouse_y - g_last_mouse_y;
    }
    g_last_mouse_x = g_input.mouse_x;
    g_last_mouse_y = g_input.mouse_y;
    
    // Handle buttons
    switch(eventKind) {
        case kEventMouseDown:
            g_input.mouse_buttons |= 1;
            break;
        case kEventMouseUp:
            g_input.mouse_buttons &= ~1;
            break;
        case kEventMouseWheelMoved:
            {
                EventMouseWheelAxis axis;
                SInt32 delta;
                GetEventParameter(event, kEventParamMouseWheelAxis, typeMouseWheelAxis, 
                                 NULL, sizeof(axis), NULL, &axis);
                GetEventParameter(event, kEventParamMouseWheelDelta, typeSInt32,
                                 NULL, sizeof(delta), NULL, &delta);
                if (axis == kEventMouseWheelAxisY) {
                    g_input.scroll_y = (int16_t)delta;
                }
            }
            break;
    }
    
    return noErr;
}

// Draw simple ASCII representation of the camera view
void draw_view() {
    // Clear screen
    printf("\033[2J\033[H");
    
    // Get camera position
    float world_x, world_z, height;
    world_x = camera_state.world_x;
    world_z = camera_state.world_z;
    height = camera_state.height;
    
    printf("=== SimCity ARM64 Camera Controller Test ===\n\n");
    
    printf("Controls:\n");
    printf("  WASD/Arrows: Move camera\n");
    printf("  Shift + Move: 2.5x speed\n");
    printf("  Mouse Wheel: Zoom in/out\n");
    printf("  Left Click + Drag: Pan view\n");
    printf("  Right Click + Drag: Rotate camera\n");
    printf("  Move to screen edge: Edge panning\n");
    printf("  ESC: Exit\n\n");
    
    printf("Camera State:\n");
    printf("  World Position: (%.1f, %.1f)\n", world_x, world_z);
    printf("  Height: %.1f\n", height);
    printf("  Rotation: %.1f°\n", camera_state.rotation);
    printf("  Velocity: (%.2f, %.2f)\n", camera_state.vel_x, camera_state.vel_z);
    printf("  Isometric: (%.1f, %.1f)\n", camera_state.iso_x, camera_state.iso_y);
    
    // Draw simple grid view
    printf("\n");
    int view_size = 20;
    for (int z = 0; z < view_size; z++) {
        for (int x = 0; x < view_size; x++) {
            int wx = (int)(world_x - view_size/2 + x);
            int wz = (int)(world_z - view_size/2 + z);
            
            // Draw camera position
            if (x == view_size/2 && z == view_size/2) {
                printf("📷 ");
            }
            // Draw grid
            else if (wx >= 0 && wx < 100 && wz >= 0 && wz < 100) {
                if (wx % 5 == 0 && wz % 5 == 0) {
                    printf("╬ ");
                } else if (wx % 5 == 0 || wz % 5 == 0) {
                    printf("┼ ");
                } else {
                    printf("· ");
                }
            } else {
                printf("  ");
            }
        }
        printf("\n");
    }
    
    // Show zoom level indicator
    printf("\nZoom: [");
    int zoom_bar = (int)((height - 5.0) / 995.0 * 20);
    for (int i = 0; i < 20; i++) {
        if (i <= zoom_bar) printf("█");
        else printf("░");
    }
    printf("] %.0f units\n", height);
    
    // Show input state
    printf("\nInput: ");
    if (g_input.keys & (1 << KEY_UP)) printf("↑ ");
    if (g_input.keys & (1 << KEY_DOWN)) printf("↓ ");
    if (g_input.keys & (1 << KEY_LEFT)) printf("← ");
    if (g_input.keys & (1 << KEY_RIGHT)) printf("→ ");
    if (g_input.keys & (1 << KEY_SHIFT)) printf("⇧ ");
    if (g_input.mouse_buttons & 1) printf("🖱️ ");
    printf("\n");
}

int main(int argc, char* argv[]) {
    printf("Initializing camera controller test...\n");
    
    // Install event handlers
    EventTypeSpec keyEvents[] = {
        { kEventClassKeyboard, kEventRawKeyDown },
        { kEventClassKeyboard, kEventRawKeyUp }
    };
    InstallApplicationEventHandler(HandleKeyEvent, 2, keyEvents, NULL, NULL);
    
    EventTypeSpec mouseEvents[] = {
        { kEventClassMouse, kEventMouseMoved },
        { kEventClassMouse, kEventMouseDragged },
        { kEventClassMouse, kEventMouseDown },
        { kEventClassMouse, kEventMouseUp },
        { kEventClassMouse, kEventMouseWheelMoved }
    };
    InstallApplicationEventHandler(HandleMouseEvent, 5, mouseEvents, NULL, NULL);
    
    // Main loop
    uint64_t last_time = 0;
    while (g_running) {
        // Process events
        EventRef event;
        EventTargetRef target = GetEventDispatcherTarget();
        if (ReceiveNextEvent(0, NULL, kEventDurationNoWait, true, &event) == noErr) {
            SendEventToEventTarget(event, target);
            ReleaseEvent(event);
        }
        
        // Calculate delta time
        uint64_t current_time = mach_absolute_time();
        if (last_time == 0) last_time = current_time;
        
        float delta_time = (current_time - last_time) / 1000000000.0f; // Convert to seconds
        last_time = current_time;
        
        // Update camera
        camera_update(&g_input, delta_time);
        
        // Reset scroll for next frame
        g_input.scroll_y = 0;
        g_input.mouse_delta_x = 0;
        g_input.mouse_delta_y = 0;
        
        // Draw view
        draw_view();
        
        // 60 FPS
        usleep(16666);
    }
    
    printf("\nCamera test terminated.\n");
    return 0;
}