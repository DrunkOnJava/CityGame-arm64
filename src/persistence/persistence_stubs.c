#include <stdio.h>

// Persistence system stubs
int save_load_init(void) { printf("Persistence: Save/load initialized\n"); return 0; }
int asset_loader_init(void) { return 0; }
int config_parser_init(void) { return 0; }
void io_init(void) { printf("IO: Input/output initialized\n"); }
void io_shutdown(void) {}
