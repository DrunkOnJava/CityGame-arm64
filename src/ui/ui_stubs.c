#include <stdio.h>

// UI system stubs
int input_handler_init(void) { printf("UI: Input handler initialized\n"); return 0; }
int hud_init(void) { return 0; }
int ui_tools_init(void) { return 0; }
void process_input_events(void) { /* Process input */ }
void ui_update(void) { /* Update UI */ }
void ui_shutdown(void) {}
