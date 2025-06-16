/*
 * SimCity ARM64 - Module Dependency Analyzer
 * Real-time dependency tracking and visualization for HMR Dashboard
 * 
 * Agent 4: Developer Tools & Debug Interface
 * Day 6: Enhanced Module Dependency Visualization
 */

#include "dependency_analyzer.h"
#include "dev_server.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include <time.h>
#include <regex.h>

// Configuration
#define MAX_MODULES 64
#define MAX_DEPENDENCIES 256
#define MAX_PATH_LENGTH 512
#define MAX_LINE_LENGTH 1024
#define SCAN_INTERVAL_SECONDS 5

// Module information
typedef struct {
    char name[64];
    char path[MAX_PATH_LENGTH];
    char type[16]; // "assembly", "c", "header", "makefiles"
    time_t last_modified;
    uint32_t line_count;
    uint32_t dependency_count;
    char dependencies[32][64];
    double load_time_ms;
    uint64_t memory_footprint;
    bool active;
} hmr_module_info_t;

// Dependency relationship
typedef struct {
    char source[64];
    char target[64];
    char type[16]; // "include", "link", "import", "call"
    double weight; // Strength of dependency
    uint32_t frequency; // How often accessed
} hmr_dependency_t;

// Global dependency analyzer state
typedef struct {
    hmr_module_info_t modules[MAX_MODULES];
    hmr_dependency_t dependencies[MAX_DEPENDENCIES];
    uint32_t module_count;
    uint32_t dependency_count;
    char project_root[MAX_PATH_LENGTH];
    time_t last_scan;
    pthread_t analyzer_thread;
    pthread_mutex_t analyzer_mutex;
    bool running;
    bool scan_needed;
} hmr_dependency_analyzer_t;

static hmr_dependency_analyzer_t g_analyzer = {0};

// Forward declarations
static void* hmr_analyzer_thread(void* arg);
static int hmr_scan_directory(const char* path, const char* relative_path);
static int hmr_analyze_file(const char* file_path, const char* relative_path);
static int hmr_extract_dependencies_from_c(const char* file_path, hmr_module_info_t* module);
static int hmr_extract_dependencies_from_assembly(const char* file_path, hmr_module_info_t* module);
static int hmr_extract_dependencies_from_makefile(const char* file_path, hmr_module_info_t* module);
static void hmr_update_dependency_graph(void);
static void hmr_calculate_load_times(void);
static const char* hmr_get_file_type(const char* file_path);
static uint32_t hmr_count_lines(const char* file_path);
static bool hmr_is_source_file(const char* file_path);

// Initialize dependency analyzer
int hmr_dependency_analyzer_init(const char* project_root) {
    if (g_analyzer.running) {
        printf("[HMR] Dependency analyzer already running\n");
        return HMR_SUCCESS;
    }
    
    // Initialize analyzer state
    memset(&g_analyzer, 0, sizeof(hmr_dependency_analyzer_t));
    strncpy(g_analyzer.project_root, project_root, sizeof(g_analyzer.project_root) - 1);
    g_analyzer.scan_needed = true;
    
    // Initialize mutex
    if (pthread_mutex_init(&g_analyzer.analyzer_mutex, NULL) != 0) {
        printf("[HMR] Failed to initialize analyzer mutex\n");
        return HMR_ERROR_THREADING;
    }
    
    // Start analyzer thread
    g_analyzer.running = true;
    if (pthread_create(&g_analyzer.analyzer_thread, NULL, hmr_analyzer_thread, NULL) != 0) {
        printf("[HMR] Failed to create analyzer thread\n");
        g_analyzer.running = false;
        pthread_mutex_destroy(&g_analyzer.analyzer_mutex);
        return HMR_ERROR_THREADING;
    }
    
    printf("[HMR] Dependency analyzer initialized for: %s\n", project_root);
    return HMR_SUCCESS;
}

// Shutdown dependency analyzer
void hmr_dependency_analyzer_shutdown(void) {
    if (!g_analyzer.running) {
        return;
    }
    
    printf("[HMR] Shutting down dependency analyzer...\n");
    
    g_analyzer.running = false;
    pthread_join(g_analyzer.analyzer_thread, NULL);
    pthread_mutex_destroy(&g_analyzer.analyzer_mutex);
    
    printf("[HMR] Dependency analyzer shutdown complete\n");
}

// Trigger immediate dependency scan
void hmr_trigger_dependency_scan(void) {
    pthread_mutex_lock(&g_analyzer.analyzer_mutex);
    g_analyzer.scan_needed = true;
    pthread_mutex_unlock(&g_analyzer.analyzer_mutex);
}

// Get dependency data as JSON
void hmr_get_dependency_data(char* json_buffer, size_t max_len) {
    if (!json_buffer || max_len == 0) return;
    
    pthread_mutex_lock(&g_analyzer.analyzer_mutex);
    
    size_t pos = 0;
    pos += snprintf(json_buffer + pos, max_len - pos,
        "{"
        "\"modules\":[");
    
    // Serialize modules
    for (uint32_t i = 0; i < g_analyzer.module_count && pos < max_len - 1000; i++) {
        hmr_module_info_t* module = &g_analyzer.modules[i];
        
        if (i > 0) {
            pos += snprintf(json_buffer + pos, max_len - pos, ",");
        }
        
        pos += snprintf(json_buffer + pos, max_len - pos,
            "{"
            "\"name\":\"%s\","
            "\"path\":\"%s\","
            "\"type\":\"%s\","
            "\"line_count\":%u,"
            "\"dependency_count\":%u,"
            "\"load_time_ms\":%.2f,"
            "\"memory_footprint\":%llu,"
            "\"last_modified\":%ld"
            "}",
            module->name,
            module->path,
            module->type,
            module->line_count,
            module->dependency_count,
            module->load_time_ms,
            module->memory_footprint,
            module->last_modified);
    }
    
    pos += snprintf(json_buffer + pos, max_len - pos,
        "],"
        "\"dependencies\":[");
    
    // Serialize dependencies
    for (uint32_t i = 0; i < g_analyzer.dependency_count && pos < max_len - 500; i++) {
        hmr_dependency_t* dep = &g_analyzer.dependencies[i];
        
        if (i > 0) {
            pos += snprintf(json_buffer + pos, max_len - pos, ",");
        }
        
        pos += snprintf(json_buffer + pos, max_len - pos,
            "{"
            "\"source\":\"%s\","
            "\"target\":\"%s\","
            "\"type\":\"%s\","
            "\"weight\":%.2f,"
            "\"frequency\":%u"
            "}",
            dep->source,
            dep->target,
            dep->type,
            dep->weight,
            dep->frequency);
    }
    
    pos += snprintf(json_buffer + pos, max_len - pos,
        "],"
        "\"last_scan\":%ld,"
        "\"module_count\":%u,"
        "\"dependency_count\":%u"
        "}",
        g_analyzer.last_scan,
        g_analyzer.module_count,
        g_analyzer.dependency_count);
    
    pthread_mutex_unlock(&g_analyzer.analyzer_mutex);
}

// Main analyzer thread
static void* hmr_analyzer_thread(void* arg) {
    (void)arg;
    
    printf("[HMR] Dependency analyzer thread started\n");
    
    while (g_analyzer.running) {
        bool should_scan = false;
        
        pthread_mutex_lock(&g_analyzer.analyzer_mutex);
        should_scan = g_analyzer.scan_needed || 
                     (time(NULL) - g_analyzer.last_scan) > SCAN_INTERVAL_SECONDS;
        pthread_mutex_unlock(&g_analyzer.analyzer_mutex);
        
        if (should_scan) {
            printf("[HMR] Starting dependency scan...\n");
            
            pthread_mutex_lock(&g_analyzer.analyzer_mutex);
            
            // Reset counters
            g_analyzer.module_count = 0;
            g_analyzer.dependency_count = 0;
            
            // Scan project directory
            if (hmr_scan_directory(g_analyzer.project_root, "") == HMR_SUCCESS) {
                // Update dependency relationships
                hmr_update_dependency_graph();
                
                // Calculate estimated load times
                hmr_calculate_load_times();
                
                g_analyzer.last_scan = time(NULL);
                g_analyzer.scan_needed = false;
                
                printf("[HMR] Dependency scan complete: %u modules, %u dependencies\n",
                       g_analyzer.module_count, g_analyzer.dependency_count);
                
                // Broadcast dependency update
                char json_data[8192];
                hmr_get_dependency_data(json_data, sizeof(json_data));
                hmr_notify_dependency_update(json_data);
            }
            
            pthread_mutex_unlock(&g_analyzer.analyzer_mutex);
        }
        
        sleep(1); // Check every second
    }
    
    printf("[HMR] Dependency analyzer thread exiting\n");
    return NULL;
}

// Scan directory recursively
static int hmr_scan_directory(const char* path, const char* relative_path) {
    DIR* dir = opendir(path);
    if (!dir) {
        return HMR_ERROR_NOT_FOUND;
    }
    
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] == '.') continue; // Skip hidden files
        
        char full_path[MAX_PATH_LENGTH];
        char rel_path[MAX_PATH_LENGTH];
        
        snprintf(full_path, sizeof(full_path), "%s/%s", path, entry->d_name);
        snprintf(rel_path, sizeof(rel_path), "%s%s%s", 
                relative_path, 
                strlen(relative_path) > 0 ? "/" : "",
                entry->d_name);
        
        struct stat file_stat;
        if (stat(full_path, &file_stat) != 0) continue;
        
        if (S_ISDIR(file_stat.st_mode)) {
            // Skip certain directories
            if (strcmp(entry->d_name, "build") == 0 ||
                strcmp(entry->d_name, ".git") == 0 ||
                strcmp(entry->d_name, "node_modules") == 0) {
                continue;
            }
            
            // Recursively scan subdirectory
            hmr_scan_directory(full_path, rel_path);
        } else if (S_ISREG(file_stat.st_mode) && hmr_is_source_file(full_path)) {
            // Analyze source file
            hmr_analyze_file(full_path, rel_path);
        }
    }
    
    closedir(dir);
    return HMR_SUCCESS;
}

// Analyze individual file
static int hmr_analyze_file(const char* file_path, const char* relative_path) {
    if (g_analyzer.module_count >= MAX_MODULES) {
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    hmr_module_info_t* module = &g_analyzer.modules[g_analyzer.module_count];
    memset(module, 0, sizeof(hmr_module_info_t));
    
    // Extract module name from path
    const char* name_start = strrchr(relative_path, '/');
    name_start = name_start ? name_start + 1 : relative_path;
    strncpy(module->name, name_start, sizeof(module->name) - 1);
    
    strncpy(module->path, relative_path, sizeof(module->path) - 1);
    strncpy(module->type, hmr_get_file_type(file_path), sizeof(module->type) - 1);
    
    // Get file stats
    struct stat file_stat;
    if (stat(file_path, &file_stat) == 0) {
        module->last_modified = file_stat.st_mtime;
        module->memory_footprint = file_stat.st_size;
    }
    
    module->line_count = hmr_count_lines(file_path);
    module->active = true;
    
    // Extract dependencies based on file type
    if (strstr(module->type, "c") || strstr(module->type, "header")) {
        hmr_extract_dependencies_from_c(file_path, module);
    } else if (strstr(module->type, "assembly")) {
        hmr_extract_dependencies_from_assembly(file_path, module);
    } else if (strstr(module->type, "makefile")) {
        hmr_extract_dependencies_from_makefile(file_path, module);
    }
    
    g_analyzer.module_count++;
    return HMR_SUCCESS;
}

// Extract dependencies from C/C++ files
static int hmr_extract_dependencies_from_c(const char* file_path, hmr_module_info_t* module) {
    FILE* file = fopen(file_path, "r");
    if (!file) return HMR_ERROR_NOT_FOUND;
    
    char line[MAX_LINE_LENGTH];
    regex_t regex;
    regmatch_t matches[2];
    
    // Compile regex for #include statements
    if (regcomp(&regex, "#include[ \t]+[\"<]([^\\\"<>]+)[\">]", REG_EXTENDED) != 0) {
        fclose(file);
        return HMR_ERROR_INVALID_ARG;
    }
    
    while (fgets(line, sizeof(line), file) && module->dependency_count < 32) {
        if (regexec(&regex, line, 2, matches, 0) == 0) {
            // Extract included file name
            int start = matches[1].rm_so;
            int end = matches[1].rm_eo;
            
            if (start >= 0 && end > start && end - start < 64) {
                strncpy(module->dependencies[module->dependency_count], 
                       line + start, end - start);
                module->dependencies[module->dependency_count][end - start] = '\0';
                module->dependency_count++;
            }
        }
    }
    
    regfree(&regex);
    fclose(file);
    return HMR_SUCCESS;
}

// Extract dependencies from Assembly files
static int hmr_extract_dependencies_from_assembly(const char* file_path, hmr_module_info_t* module) {
    FILE* file = fopen(file_path, "r");
    if (!file) return HMR_ERROR_NOT_FOUND;
    
    char line[MAX_LINE_LENGTH];
    
    while (fgets(line, sizeof(line), file) && module->dependency_count < 32) {
        // Look for .include directives
        if (strstr(line, ".include") || strstr(line, ".import")) {
            char* start = strchr(line, '"');
            if (start) {
                start++;
                char* end = strchr(start, '"');
                if (end && end - start < 64) {
                    strncpy(module->dependencies[module->dependency_count], 
                           start, end - start);
                    module->dependencies[module->dependency_count][end - start] = '\0';
                    module->dependency_count++;
                }
            }
        }
        
        // Look for external function calls
        if (strstr(line, "bl ") || strstr(line, "call ")) {
            // Extract function name after bl/call
            char* func_start = strstr(line, "bl ");
            if (!func_start) func_start = strstr(line, "call ");
            if (func_start) {
                func_start += (func_start[0] == 'b') ? 3 : 5; // Skip "bl " or "call "
                while (*func_start == ' ' || *func_start == '\t') func_start++;
                
                char func_name[64];
                int i = 0;
                while (func_start[i] && func_start[i] != ' ' && func_start[i] != '\t' && 
                       func_start[i] != '\n' && i < 63) {
                    func_name[i] = func_start[i];
                    i++;
                }
                func_name[i] = '\0';
                
                if (strlen(func_name) > 0 && module->dependency_count < 32) {
                    strncpy(module->dependencies[module->dependency_count], 
                           func_name, sizeof(module->dependencies[0]) - 1);
                    module->dependency_count++;
                }
            }
        }
    }
    
    fclose(file);
    return HMR_SUCCESS;
}

// Extract dependencies from Makefile
static int hmr_extract_dependencies_from_makefile(const char* file_path, hmr_module_info_t* module) {
    FILE* file = fopen(file_path, "r");
    if (!file) return HMR_ERROR_NOT_FOUND;
    
    char line[MAX_LINE_LENGTH];
    regex_t regex;
    regmatch_t matches[2];
    
    // Look for target dependencies
    if (regcomp(&regex, "([^:]+):.*\\.([scho])\\b", REG_EXTENDED) != 0) {
        fclose(file);
        return HMR_ERROR_INVALID_ARG;
    }
    
    while (fgets(line, sizeof(line), file) && module->dependency_count < 32) {
        if (regexec(&regex, line, 2, matches, 0) == 0) {
            // Extract file dependencies from makefile rules
            char* token = strtok(line, " \t\n");
            while (token && module->dependency_count < 32) {
                if (strstr(token, ".s") || strstr(token, ".c") || 
                    strstr(token, ".h") || strstr(token, ".o")) {
                    strncpy(module->dependencies[module->dependency_count], 
                           token, sizeof(module->dependencies[0]) - 1);
                    module->dependency_count++;
                }
                token = strtok(NULL, " \t\n");
            }
        }
    }
    
    regfree(&regex);
    fclose(file);
    return HMR_SUCCESS;
}

// Update dependency graph relationships
static void hmr_update_dependency_graph(void) {
    g_analyzer.dependency_count = 0;
    
    for (uint32_t i = 0; i < g_analyzer.module_count; i++) {
        hmr_module_info_t* source = &g_analyzer.modules[i];
        
        for (uint32_t j = 0; j < source->dependency_count; j++) {
            const char* dep_name = source->dependencies[j];
            
            // Find target module
            for (uint32_t k = 0; k < g_analyzer.module_count; k++) {
                hmr_module_info_t* target = &g_analyzer.modules[k];
                
                if (strstr(target->name, dep_name) || 
                    strstr(target->path, dep_name)) {
                    
                    if (g_analyzer.dependency_count < MAX_DEPENDENCIES) {
                        hmr_dependency_t* dep = &g_analyzer.dependencies[g_analyzer.dependency_count];
                        
                        strncpy(dep->source, source->name, sizeof(dep->source) - 1);
                        strncpy(dep->target, target->name, sizeof(dep->target) - 1);
                        strncpy(dep->type, "include", sizeof(dep->type) - 1);
                        dep->weight = 1.0;
                        dep->frequency = 1;
                        
                        g_analyzer.dependency_count++;
                    }
                    break;
                }
            }
        }
    }
}

// Calculate estimated load times
static void hmr_calculate_load_times(void) {
    for (uint32_t i = 0; i < g_analyzer.module_count; i++) {
        hmr_module_info_t* module = &g_analyzer.modules[i];
        
        // Simple heuristic: base time + lines * factor + dependencies * factor
        double base_time = 1.0; // Base load time in ms
        double line_factor = 0.01; // 0.01ms per line
        double dep_factor = 0.5; // 0.5ms per dependency
        
        if (strstr(module->type, "assembly")) {
            line_factor = 0.005; // Assembly is faster to parse
        } else if (strstr(module->type, "c")) {
            line_factor = 0.02; // C requires more processing
        }
        
        module->load_time_ms = base_time + 
                              (module->line_count * line_factor) + 
                              (module->dependency_count * dep_factor);
    }
}

// Helper functions
static const char* hmr_get_file_type(const char* file_path) {
    const char* ext = strrchr(file_path, '.');
    if (!ext) return "unknown";
    
    if (strcmp(ext, ".s") == 0) return "assembly";
    if (strcmp(ext, ".c") == 0) return "c";
    if (strcmp(ext, ".h") == 0) return "header";
    if (strcmp(ext, ".cpp") == 0 || strcmp(ext, ".cc") == 0) return "cpp";
    if (strcmp(ext, ".m") == 0) return "objc";
    if (strstr(file_path, "Makefile") || strstr(file_path, "makefile")) return "makefile";
    
    return "unknown";
}

static uint32_t hmr_count_lines(const char* file_path) {
    FILE* file = fopen(file_path, "r");
    if (!file) return 0;
    
    uint32_t lines = 0;
    int ch;
    while ((ch = fgetc(file)) != EOF) {
        if (ch == '\n') lines++;
    }
    
    fclose(file);
    return lines;
}

static bool hmr_is_source_file(const char* file_path) {
    const char* ext = strrchr(file_path, '.');
    if (!ext) {
        // Check for makefiles without extension
        return (strstr(file_path, "Makefile") != NULL || 
                strstr(file_path, "makefile") != NULL);
    }
    
    return (strcmp(ext, ".s") == 0 ||
            strcmp(ext, ".c") == 0 ||
            strcmp(ext, ".h") == 0 ||
            strcmp(ext, ".cpp") == 0 ||
            strcmp(ext, ".cc") == 0 ||
            strcmp(ext, ".m") == 0);
}