#ifndef ASSET_WORKFLOW_AUTOMATION_H
#define ASSET_WORKFLOW_AUTOMATION_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

// Forward declarations
typedef struct workflow_engine_t workflow_engine_t;
typedef struct workflow_task_t workflow_task_t;
typedef struct pipeline_t pipeline_t;
typedef struct script_context_t script_context_t;

// Workflow task types
typedef enum {
    TASK_TYPE_LOAD_ASSET = 0,
    TASK_TYPE_VALIDATE_ASSET = 1,
    TASK_TYPE_COMPRESS_ASSET = 2,
    TASK_TYPE_OPTIMIZE_ASSET = 3,
    TASK_TYPE_CONVERT_FORMAT = 4,
    TASK_TYPE_GENERATE_VARIANTS = 5,
    TASK_TYPE_UPDATE_METADATA = 6,
    TASK_TYPE_DEPLOY_ASSET = 7,
    TASK_TYPE_CUSTOM_SCRIPT = 8,
    TASK_TYPE_PARALLEL_GROUP = 9,
    TASK_TYPE_CONDITIONAL = 10,
    TASK_TYPE_LOOP = 11
} workflow_task_type_t;

// Task execution states
typedef enum {
    TASK_STATE_PENDING = 0,
    TASK_STATE_RUNNING = 1,
    TASK_STATE_COMPLETED = 2,
    TASK_STATE_FAILED = 3,
    TASK_STATE_SKIPPED = 4,
    TASK_STATE_CANCELLED = 5,
    TASK_STATE_WAITING = 6
} workflow_task_state_t;

// Workflow execution modes
typedef enum {
    EXECUTION_MODE_SEQUENTIAL = 0,
    EXECUTION_MODE_PARALLEL = 1,
    EXECUTION_MODE_PIPELINE = 2,
    EXECUTION_MODE_CONDITIONAL = 3,
    EXECUTION_MODE_ADAPTIVE = 4
} workflow_execution_mode_t;

// Pipeline stage types
typedef enum {
    STAGE_TYPE_INPUT = 0,
    STAGE_TYPE_PROCESSING = 1,
    STAGE_TYPE_VALIDATION = 2,
    STAGE_TYPE_OUTPUT = 3,
    STAGE_TYPE_NOTIFICATION = 4
} pipeline_stage_type_t;

// Script execution environments
typedef enum {
    SCRIPT_ENV_JAVASCRIPT = 0,
    SCRIPT_ENV_PYTHON = 1,
    SCRIPT_ENV_LUA = 2,
    SCRIPT_ENV_SHELL = 3,
    SCRIPT_ENV_NATIVE = 4
} script_environment_t;

// Workflow variable types
typedef enum {
    VAR_TYPE_STRING = 0,
    VAR_TYPE_INTEGER = 1,
    VAR_TYPE_FLOAT = 2,
    VAR_TYPE_BOOLEAN = 3,
    VAR_TYPE_ARRAY = 4,
    VAR_TYPE_OBJECT = 5,
    VAR_TYPE_ASSET_REF = 6
} workflow_variable_type_t;

// Workflow variable structure
typedef struct workflow_variable_t {
    char name[64];
    workflow_variable_type_t type;
    
    union {
        char string_value[256];
        int64_t integer_value;
        double float_value;
        bool boolean_value;
        struct {
            uint32_t count;
            struct workflow_variable_t** elements;
        } array_value;
        void* object_value;
        char asset_ref[256];
    } value;
    
    bool is_readonly;
    bool is_global;
    uint64_t last_modified;
} workflow_variable_t;

// Task dependency structure
typedef struct task_dependency_t {
    char task_name[64];
    bool is_required;
    bool wait_for_completion;
    float timeout_seconds;
} task_dependency_t;

// Workflow task structure
typedef struct workflow_task_t {
    char task_id[64];
    char task_name[128];
    workflow_task_type_t type;
    workflow_task_state_t state;
    
    // Task configuration
    char input_pattern[256];
    char output_pattern[256];
    char script_path[256];
    script_environment_t script_env;
    
    // Dependencies
    uint32_t dependency_count;
    task_dependency_t* dependencies;
    
    // Execution parameters
    uint32_t max_retry_count;
    uint32_t current_retry;
    float timeout_seconds;
    uint32_t priority;
    bool can_run_parallel;
    
    // Resource requirements
    uint64_t memory_requirement;
    uint32_t cpu_cores_required;
    float gpu_usage_requirement;
    
    // Conditional execution
    char condition_script[512];
    bool condition_result;
    
    // Loop configuration
    uint32_t loop_count;
    uint32_t current_iteration;
    char loop_variable[64];
    
    // Runtime data
    uint64_t start_time;
    uint64_t end_time;
    uint32_t execution_time_ms;
    float progress_percent;
    
    // Input/output data
    uint32_t input_count;
    char** input_assets;
    uint32_t output_count;
    char** output_assets;
    
    // Variables
    uint32_t variable_count;
    workflow_variable_t* variables;
    
    // Error handling
    char error_message[512];
    bool continue_on_error;
    char fallback_task[64];
    
    // Monitoring
    struct {
        uint64_t bytes_processed;
        uint32_t assets_processed;
        float processing_rate;
        uint32_t error_count;
        float cpu_usage_percent;
        uint64_t memory_usage;
    } metrics;
    
    // Task function pointer
    int (*execute_function)(struct workflow_task_t* task, script_context_t* context);
    
    // Task links
    struct workflow_task_t* next;
    struct workflow_task_t* parallel_group;
} workflow_task_t;

// Pipeline stage structure
typedef struct pipeline_stage_t {
    char stage_id[64];
    char stage_name[128];
    pipeline_stage_type_t type;
    
    // Stage tasks
    uint32_t task_count;
    workflow_task_t** tasks;
    
    // Stage configuration
    workflow_execution_mode_t execution_mode;
    uint32_t max_parallel_tasks;
    float stage_timeout_seconds;
    
    // Stage filtering
    char input_filter[256];
    char output_filter[256];
    
    // Stage metrics
    struct {
        uint32_t assets_processed;
        uint32_t successful_tasks;
        uint32_t failed_tasks;
        float average_processing_time;
        float throughput_assets_per_second;
    } metrics;
    
    struct pipeline_stage_t* next;
} pipeline_stage_t;

// Pipeline structure
typedef struct pipeline_t {
    char pipeline_id[64];
    char pipeline_name[128];
    char description[512];
    
    // Pipeline stages
    uint32_t stage_count;
    pipeline_stage_t* stages;
    
    // Pipeline configuration
    workflow_execution_mode_t execution_mode;
    uint32_t max_concurrent_assets;
    float pipeline_timeout_seconds;
    bool auto_retry_failed_assets;
    
    // Input/output configuration
    char input_directory[256];
    char output_directory[256];
    char working_directory[256];
    char log_directory[256];
    
    // Pipeline state
    bool is_running;
    bool is_paused;
    uint64_t start_time;
    uint64_t last_activity_time;
    
    // Pipeline metrics
    struct {
        uint32_t total_assets_queued;
        uint32_t assets_completed;
        uint32_t assets_failed;
        uint32_t assets_in_progress;
        float completion_percentage;
        float estimated_time_remaining;
        uint64_t total_processing_time;
        float average_asset_processing_time;
    } metrics;
    
    // Global variables
    uint32_t global_variable_count;
    workflow_variable_t* global_variables;
    
    struct pipeline_t* next;
} pipeline_t;

// Script execution context
typedef struct script_context_t {
    script_environment_t environment;
    
    // Context variables
    uint32_t variable_count;
    workflow_variable_t* variables;
    
    // Asset context
    char current_asset_path[256];
    char current_output_path[256];
    uint64_t current_asset_size;
    char current_asset_type[32];
    
    // Execution environment
    void* script_engine;
    char working_directory[256];
    char temp_directory[256];
    
    // Resource limits
    uint64_t memory_limit;
    uint32_t execution_timeout_ms;
    
    // Logging
    FILE* log_file;
    bool verbose_logging;
    
    // Error handling
    char last_error[512];
    uint32_t error_count;
} script_context_t;

// Workflow execution statistics
typedef struct workflow_statistics_t {
    // Execution metrics
    uint64_t total_workflows_executed;
    uint64_t successful_workflows;
    uint64_t failed_workflows;
    float success_rate_percent;
    
    // Performance metrics
    float average_workflow_duration_seconds;
    float average_task_duration_seconds;
    uint32_t peak_parallel_tasks;
    float resource_utilization_percent;
    
    // Asset processing metrics
    uint64_t total_assets_processed;
    uint64_t total_bytes_processed;
    float processing_throughput_mbps;
    float average_asset_processing_time;
    
    // Error metrics
    uint32_t total_task_failures;
    uint32_t timeout_failures;
    uint32_t resource_failures;
    uint32_t dependency_failures;
    
    // Optimization metrics
    float workflow_optimization_score;
    uint32_t bottleneck_stages_detected;
    float parallel_efficiency_percent;
} workflow_statistics_t;

// Main workflow engine structure
typedef struct workflow_engine_t {
    // Engine configuration
    uint32_t max_parallel_workflows;
    uint32_t max_parallel_tasks;
    uint64_t memory_limit;
    char base_directory[256];
    
    // Pipelines
    uint32_t pipeline_count;
    pipeline_t* pipelines;
    
    // Task queue
    struct {
        uint32_t capacity;
        uint32_t count;
        uint32_t head;
        uint32_t tail;
        workflow_task_t** tasks;
    } task_queue;
    
    // Worker threads
    struct {
        uint32_t thread_count;
        void** threads;
        bool* thread_active;
        uint32_t next_thread_index;
    } thread_pool;
    
    // Script engines
    struct {
        void* javascript_engine;
        void* python_engine;
        void* lua_engine;
    } script_engines;
    
    // Monitoring and statistics
    workflow_statistics_t statistics;
    
    // Resource monitoring
    struct {
        uint64_t current_memory_usage;
        uint32_t active_task_count;
        float cpu_utilization_percent;
        uint32_t pending_asset_count;
    } resource_monitor;
    
    // Runtime state
    bool is_running;
    bool is_paused;
    uint64_t engine_start_time;
    
    // Thread safety
    void* mutex;
    void* condition_variable;
    
    // Callbacks
    void (*on_workflow_start)(const char* pipeline_id);
    void (*on_workflow_complete)(const char* pipeline_id, bool success);
    void (*on_task_start)(const char* task_id);
    void (*on_task_complete)(const char* task_id, bool success);
    void (*on_asset_processed)(const char* asset_path, const char* output_path);
    void (*on_error)(const char* error_message);
    void (*on_progress)(const char* pipeline_id, float progress_percent);
} workflow_engine_t;

// Core workflow engine functions
int workflow_engine_init(workflow_engine_t** engine, uint32_t max_parallel_workflows);
void workflow_engine_destroy(workflow_engine_t* engine);

// Pipeline management
int workflow_create_pipeline(workflow_engine_t* engine, const char* pipeline_id,
                            const char* name, const char* description);
int workflow_add_stage(workflow_engine_t* engine, const char* pipeline_id,
                      const char* stage_id, pipeline_stage_type_t type);
int workflow_add_task(workflow_engine_t* engine, const char* pipeline_id,
                     const char* stage_id, workflow_task_t* task);

// Task creation helpers
workflow_task_t* workflow_create_load_task(const char* task_id, const char* input_pattern);
workflow_task_t* workflow_create_compress_task(const char* task_id, const char* compression_type);
workflow_task_t* workflow_create_optimize_task(const char* task_id, const char* optimization_level);
workflow_task_t* workflow_create_script_task(const char* task_id, const char* script_path, 
                                            script_environment_t env);
workflow_task_t* workflow_create_conditional_task(const char* task_id, const char* condition);

// Workflow execution
int workflow_execute_pipeline(workflow_engine_t* engine, const char* pipeline_id,
                             const char* input_directory);
int workflow_execute_task(workflow_engine_t* engine, workflow_task_t* task,
                         script_context_t* context);

// Workflow control
int workflow_start_engine(workflow_engine_t* engine);
int workflow_stop_engine(workflow_engine_t* engine);
int workflow_pause_pipeline(workflow_engine_t* engine, const char* pipeline_id);
int workflow_resume_pipeline(workflow_engine_t* engine, const char* pipeline_id);
int workflow_cancel_pipeline(workflow_engine_t* engine, const char* pipeline_id);

// Variable management
int workflow_set_variable(script_context_t* context, const char* name,
                         workflow_variable_type_t type, const void* value);
int workflow_get_variable(script_context_t* context, const char* name,
                         workflow_variable_t* variable);

// Script execution
int workflow_execute_script(script_context_t* context, const char* script_path);
int workflow_execute_script_code(script_context_t* context, const char* code);

// Pipeline templates
int workflow_load_pipeline_template(workflow_engine_t* engine, const char* template_path);
int workflow_save_pipeline_template(workflow_engine_t* engine, const char* pipeline_id,
                                   const char* template_path);

// Monitoring and statistics
int workflow_get_statistics(workflow_engine_t* engine, workflow_statistics_t* stats);
int workflow_get_pipeline_status(workflow_engine_t* engine, const char* pipeline_id,
                                struct {
                                    workflow_task_state_t state;
                                    float progress_percent;
                                    uint32_t assets_processed;
                                    uint32_t assets_remaining;
                                    float estimated_time_remaining;
                                } *status);

// Utility functions
const char* workflow_task_type_to_string(workflow_task_type_t type);
const char* workflow_task_state_to_string(workflow_task_state_t state);
const char* script_environment_to_string(script_environment_t env);
void workflow_task_destroy(workflow_task_t* task);

// Advanced features
int workflow_optimize_pipeline(workflow_engine_t* engine, const char* pipeline_id);
int workflow_analyze_bottlenecks(workflow_engine_t* engine, const char* pipeline_id,
                                struct {
                                    char bottleneck_stage[64];
                                    float severity_score;
                                    char recommendation[256];
                                } *analysis);

#endif // ASSET_WORKFLOW_AUTOMATION_H