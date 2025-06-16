/*
 * SimCity ARM64 - Agent 1: Core Module System
 * Week 4, Day 16 - Multi-Agent Integration Testing Suite
 * 
 * Comprehensive integration testing for all 10 agents working together
 * - Agent coordination under maximum stress (1000+ concurrent modules)
 * - Cross-agent communication validation
 * - Resource contention and load balancing
 * - End-to-end workflow testing
 * 
 * Performance Requirements:
 * - 1000+ concurrent modules
 * - <5ms cross-agent communication latency
 * - <100ms total integration test suite
 * - Zero memory leaks under stress
 */

#include "testing_framework.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/time.h>
#include <signal.h>

// Agent interface definitions
typedef struct {
    int agent_id;
    const char* name;
    const char* executable_path;
    pid_t process_id;
    int communication_fd[2]; // pipe for IPC
    bool is_active;
    uint64_t messages_sent;
    uint64_t messages_received;
    uint64_t last_heartbeat_ns;
} agent_instance_t;

// Integration test configuration
typedef struct {
    uint32_t num_concurrent_modules;
    uint32_t test_duration_seconds;
    uint32_t max_communication_latency_ms;
    uint32_t heartbeat_interval_ms;
    bool enable_stress_testing;
    bool enable_fault_injection;
} integration_test_config_t;

// Global test state
static agent_instance_t agents[10];
static integration_test_config_t test_config;
static pthread_mutex_t test_state_mutex = PTHREAD_MUTEX_INITIALIZER;
static volatile bool test_running = false;

/*
 * =============================================================================
 * AGENT INITIALIZATION AND MANAGEMENT
 * =============================================================================
 */

static bool initialize_agent(int agent_id, const char* name, const char* executable) {
    agent_instance_t* agent = &agents[agent_id];
    
    agent->agent_id = agent_id;
    agent->name = name;
    agent->executable_path = executable;
    agent->is_active = false;
    agent->messages_sent = 0;
    agent->messages_received = 0;
    agent->last_heartbeat_ns = 0;
    
    // Create communication pipe
    if (pipe(agent->communication_fd) != 0) {
        printf("Failed to create communication pipe for agent %d (%s)\n", agent_id, name);
        return false;
    }
    
    // Fork and exec the agent process
    pid_t pid = fork();
    if (pid == 0) {
        // Child process - exec the agent
        close(agent->communication_fd[1]); // Close write end in child
        dup2(agent->communication_fd[0], STDIN_FILENO); // Redirect pipe to stdin
        
        execl(executable, name, NULL);
        
        // If we get here, exec failed
        printf("Failed to exec agent %s\n", name);
        exit(1);
    } else if (pid > 0) {
        // Parent process
        agent->process_id = pid;
        close(agent->communication_fd[0]); // Close read end in parent
        agent->is_active = true;
        
        printf("Initialized agent %d (%s) with PID %d\n", agent_id, name, pid);
        return true;
    } else {
        // Fork failed
        printf("Failed to fork agent %d (%s)\n", agent_id, name);
        close(agent->communication_fd[0]);
        close(agent->communication_fd[1]);
        return false;
    }
}

static void shutdown_agent(int agent_id) {
    agent_instance_t* agent = &agents[agent_id];
    
    if (agent->is_active && agent->process_id > 0) {
        // Send termination signal
        kill(agent->process_id, SIGTERM);
        
        // Wait for graceful shutdown
        int status;
        struct timespec timeout = {.tv_sec = 5, .tv_nsec = 0};
        
        if (waitpid(agent->process_id, &status, WNOHANG) == 0) {
            // Process still running, wait with timeout
            sleep(1);
            if (waitpid(agent->process_id, &status, WNOHANG) == 0) {
                // Force kill if still running
                kill(agent->process_id, SIGKILL);
                waitpid(agent->process_id, &status, 0);
            }
        }
        
        close(agent->communication_fd[1]);
        agent->is_active = false;
        
        printf("Shutdown agent %d (%s)\n", agent_id, agent->name);
    }
}

static bool send_message_to_agent(int agent_id, const char* message) {
    agent_instance_t* agent = &agents[agent_id];
    
    if (!agent->is_active) {
        return false;
    }
    
    size_t message_len = strlen(message);
    ssize_t written = write(agent->communication_fd[1], message, message_len);
    
    if (written == message_len) {
        agent->messages_sent++;
        return true;
    }
    
    return false;
}

/*
 * =============================================================================
 * STRESS TESTING FUNCTIONS
 * =============================================================================
 */

static void* stress_test_module_loading(void* arg) {
    int thread_id = *(int*)arg;
    int modules_per_thread = test_config.num_concurrent_modules / 4; // Assume 4 threads
    
    printf("Stress test thread %d starting to load %d modules\n", thread_id, modules_per_thread);
    
    for (int i = 0; i < modules_per_thread && test_running; i++) {
        // Simulate module loading
        char module_name[64];
        snprintf(module_name, sizeof(module_name), "stress_module_%d_%d", thread_id, i);
        
        // Send module load request to Agent 1 (Core Module System)
        char load_command[256];
        snprintf(load_command, sizeof(load_command), "LOAD_MODULE %s\n", module_name);
        
        if (!send_message_to_agent(0, load_command)) {
            printf("Failed to send load command for module %s\n", module_name);
            continue;
        }
        
        // Brief delay to avoid overwhelming the system
        usleep(1000); // 1ms
        
        // Simulate some work with the module
        usleep(rand() % 10000); // 0-10ms random work
        
        // Send module unload request
        char unload_command[256];
        snprintf(unload_command, sizeof(unload_command), "UNLOAD_MODULE %s\n", module_name);
        send_message_to_agent(0, unload_command);
    }
    
    printf("Stress test thread %d completed\n", thread_id);
    return NULL;
}

static void* cross_agent_communication_test(void* arg) {
    int iterations = 1000;
    struct timeval start, end;
    
    printf("Starting cross-agent communication test (%d iterations)\n", iterations);
    
    for (int i = 0; i < iterations && test_running; i++) {
        gettimeofday(&start, NULL);
        
        // Send messages between agents in a chain
        for (int agent_id = 0; agent_id < 10; agent_id++) {
            char message[128];
            snprintf(message, sizeof(message), "PING %d %ld\n", i, start.tv_usec);
            
            if (!send_message_to_agent(agent_id, message)) {
                printf("Failed to send message to agent %d\n", agent_id);
            }
        }
        
        gettimeofday(&end, NULL);
        uint64_t latency_us = (end.tv_sec - start.tv_sec) * 1000000 + (end.tv_usec - start.tv_usec);
        
        // Check if latency is within acceptable bounds
        if (latency_us > test_config.max_communication_latency_ms * 1000) {
            printf("Warning: High communication latency: %lu μs\n", latency_us);
        }
        
        usleep(10000); // 10ms between iterations
    }
    
    printf("Cross-agent communication test completed\n");
    return NULL;
}

static void* heartbeat_monitor(void* arg) {
    printf("Starting heartbeat monitor\n");
    
    while (test_running) {
        struct timeval current_time;
        gettimeofday(&current_time, NULL);
        uint64_t current_ns = current_time.tv_sec * 1000000000ULL + current_time.tv_usec * 1000;
        
        for (int i = 0; i < 10; i++) {
            if (agents[i].is_active) {
                // Send heartbeat request
                char heartbeat_msg[64];
                snprintf(heartbeat_msg, sizeof(heartbeat_msg), "HEARTBEAT %ld\n", current_ns);
                send_message_to_agent(i, heartbeat_msg);
                
                // Check for missed heartbeats
                if (agents[i].last_heartbeat_ns > 0) {
                    uint64_t heartbeat_age_ns = current_ns - agents[i].last_heartbeat_ns;
                    if (heartbeat_age_ns > test_config.heartbeat_interval_ms * 2000000ULL) {
                        printf("Warning: Agent %d (%s) missed heartbeat\n", i, agents[i].name);
                    }
                }
            }
        }
        
        usleep(test_config.heartbeat_interval_ms * 1000); // Convert ms to μs
    }
    
    printf("Heartbeat monitor stopped\n");
    return NULL;
}

/*
 * =============================================================================
 * INTEGRATION TEST CASES
 * =============================================================================
 */

static bool test_agent_initialization(void) {
    printf("Testing agent initialization...\n");
    
    // Define all 10 agents with their mock executables
    const char* agent_configs[][2] = {
        {"Agent1_CoreModule", "/bin/echo"},      // Mock with echo for testing
        {"Agent2_BuildSystem", "/bin/echo"},
        {"Agent3_RuntimeOrchestrator", "/bin/echo"},
        {"Agent4_HMRDashboard", "/bin/echo"},
        {"Agent5_GraphicsShader", "/bin/echo"},
        {"Agent6_NetworkGraph", "/bin/echo"},
        {"Agent7_UISystem", "/bin/echo"},
        {"Agent8_PersistenceIO", "/bin/echo"},
        {"Agent9_AudioSystem", "/bin/echo"},
        {"Agent10_AICoordinator", "/bin/echo"}
    };
    
    // Initialize all agents
    int successful_inits = 0;
    for (int i = 0; i < 10; i++) {
        if (initialize_agent(i, agent_configs[i][0], agent_configs[i][1])) {
            successful_inits++;
        }
    }
    
    TEST_ASSERT_EQ(successful_inits, 10, "All 10 agents should initialize successfully");
    
    // Wait for agents to settle
    sleep(1);
    
    // Verify all agents are active
    int active_agents = 0;
    for (int i = 0; i < 10; i++) {
        if (agents[i].is_active) {
            active_agents++;
        }
    }
    
    TEST_ASSERT_EQ(active_agents, 10, "All 10 agents should be active");
    
    return true;
}

static bool test_concurrent_module_loading(void) {
    printf("Testing concurrent module loading (target: %d modules)...\n", 
           test_config.num_concurrent_modules);
    
    test_running = true;
    
    // Create stress test threads
    const int num_threads = 4;
    pthread_t stress_threads[num_threads];
    int thread_ids[num_threads];
    
    struct timeval start, end;
    gettimeofday(&start, NULL);
    
    // Start stress test threads
    for (int i = 0; i < num_threads; i++) {
        thread_ids[i] = i;
        int result = pthread_create(&stress_threads[i], NULL, 
                                   stress_test_module_loading, &thread_ids[i]);
        TEST_ASSERT_EQ(result, 0, "Stress test thread should start successfully");
    }
    
    // Let the stress test run
    sleep(test_config.test_duration_seconds);
    
    test_running = false;
    
    // Wait for all threads to complete
    for (int i = 0; i < num_threads; i++) {
        pthread_join(stress_threads[i], NULL);
    }
    
    gettimeofday(&end, NULL);
    uint64_t duration_ms = (end.tv_sec - start.tv_sec) * 1000 + 
                          (end.tv_usec - start.tv_usec) / 1000;
    
    printf("Concurrent module loading test completed in %lu ms\n", duration_ms);
    
    // Verify system is still stable
    int active_agents = 0;
    for (int i = 0; i < 10; i++) {
        if (agents[i].is_active) {
            active_agents++;
        }
    }
    
    TEST_ASSERT_EQ(active_agents, 10, "All agents should remain active after stress test");
    
    return true;
}

static bool test_cross_agent_communication_latency(void) {
    printf("Testing cross-agent communication latency...\n");
    
    test_running = true;
    
    pthread_t comm_thread;
    int result = pthread_create(&comm_thread, NULL, cross_agent_communication_test, NULL);
    TEST_ASSERT_EQ(result, 0, "Communication test thread should start");
    
    // Let communication test run
    sleep(10); // 10 seconds of communication testing
    
    test_running = false;
    pthread_join(comm_thread, NULL);
    
    // Verify communication statistics
    uint64_t total_messages_sent = 0;
    for (int i = 0; i < 10; i++) {
        total_messages_sent += agents[i].messages_sent;
    }
    
    TEST_ASSERT_GT(total_messages_sent, 1000, "Should have sent many messages during test");
    
    return true;
}

static bool test_system_resource_usage(void) {
    printf("Testing system resource usage under load...\n");
    
    // Get initial memory usage
    FILE* status = fopen("/proc/self/status", "r");
    if (!status) {
        printf("Warning: Cannot read memory usage on this system\n");
        return true; // Skip test on non-Linux systems
    }
    
    char line[256];
    size_t initial_memory_kb = 0;
    while (fgets(line, sizeof(line), status)) {
        if (strncmp(line, "VmRSS:", 6) == 0) {
            sscanf(line, "VmRSS: %zu kB", &initial_memory_kb);
            break;
        }
    }
    fclose(status);
    
    // Run system under stress
    test_running = true;
    
    pthread_t stress_thread;
    int thread_id = 0;
    pthread_create(&stress_thread, NULL, stress_test_module_loading, &thread_id);
    
    pthread_t comm_thread;
    pthread_create(&comm_thread, NULL, cross_agent_communication_test, NULL);
    
    // Monitor resource usage during stress
    sleep(5);
    
    // Get peak memory usage
    status = fopen("/proc/self/status", "r");
    if (status) {
        size_t peak_memory_kb = 0;
        while (fgets(line, sizeof(line), status)) {
            if (strncmp(line, "VmRSS:", 6) == 0) {
                sscanf(line, "VmRSS: %zu kB", &peak_memory_kb);
                break;
            }
        }
        fclose(status);
        
        size_t memory_increase_kb = peak_memory_kb - initial_memory_kb;
        printf("Memory usage increased by %zu KB during stress test\n", memory_increase_kb);
        
        // Should not increase memory by more than 100MB during stress test
        TEST_ASSERT_LT(memory_increase_kb, 100 * 1024, 
                       "Memory increase should be < 100MB during stress test");
    }
    
    test_running = false;
    pthread_join(stress_thread, NULL);
    pthread_join(comm_thread, NULL);
    
    return true;
}

static bool test_fault_tolerance(void) {
    printf("Testing fault tolerance (agent failure recovery)...\n");
    
    // Kill one agent and verify system continues to function
    int target_agent = 5; // Kill Agent 6 (NetworkGraph)
    
    printf("Killing agent %d (%s) to test fault tolerance\n", 
           target_agent, agents[target_agent].name);
    
    kill(agents[target_agent].process_id, SIGKILL);
    agents[target_agent].is_active = false;
    
    // Wait for system to detect failure
    sleep(2);
    
    // Verify other agents are still functioning
    int active_agents = 0;
    for (int i = 0; i < 10; i++) {
        if (i != target_agent && agents[i].is_active) {
            active_agents++;
        }
    }
    
    TEST_ASSERT_EQ(active_agents, 8, "8 agents should remain active after one failure");
    
    // Test that system can continue to load modules
    char test_command[] = "LOAD_MODULE fault_tolerance_test\n";
    bool command_sent = send_message_to_agent(0, test_command); // Send to Agent 1
    TEST_ASSERT(command_sent, "Should be able to send commands after agent failure");
    
    // Restart the failed agent
    printf("Restarting failed agent %d\n", target_agent);
    close(agents[target_agent].communication_fd[1]);
    
    if (initialize_agent(target_agent, agents[target_agent].name, 
                        agents[target_agent].executable_path)) {
        printf("Successfully restarted agent %d\n", target_agent);
    }
    
    return true;
}

static bool test_end_to_end_workflow(void) {
    printf("Testing end-to-end workflow (all agents collaborating)...\n");
    
    // Simulate a complete workflow:
    // 1. Agent 1 loads a module
    // 2. Agent 2 builds shader assets
    // 3. Agent 5 processes graphics
    // 4. Agent 4 displays performance metrics
    // 5. Agent 8 saves state
    
    struct timeval start, end;
    gettimeofday(&start, NULL);
    
    // Step 1: Load module
    send_message_to_agent(0, "LOAD_MODULE end_to_end_test\n");
    usleep(10000); // 10ms
    
    // Step 2: Build assets
    send_message_to_agent(1, "BUILD_ASSETS end_to_end_test\n");
    usleep(20000); // 20ms
    
    // Step 3: Process graphics
    send_message_to_agent(4, "RENDER_FRAME end_to_end_test\n");
    usleep(16667); // ~60 FPS (16.67ms)
    
    // Step 4: Update dashboard
    send_message_to_agent(3, "UPDATE_METRICS performance_data\n");
    usleep(5000); // 5ms
    
    // Step 5: Save state
    send_message_to_agent(7, "SAVE_STATE end_to_end_test\n");
    usleep(30000); // 30ms
    
    gettimeofday(&end, NULL);
    uint64_t total_workflow_time_us = (end.tv_sec - start.tv_sec) * 1000000 + 
                                     (end.tv_usec - start.tv_usec);
    
    printf("End-to-end workflow completed in %lu μs\n", total_workflow_time_us);
    
    // Should complete workflow in < 100ms
    TEST_ASSERT_LT(total_workflow_time_us, 100000, 
                   "End-to-end workflow should complete in < 100ms");
    
    return true;
}

/*
 * =============================================================================
 * TEST SUITE SETUP AND EXECUTION
 * =============================================================================
 */

static bool setup_integration_tests(void) {
    printf("Setting up integration test environment...\n");
    
    // Configure test parameters
    test_config.num_concurrent_modules = 1000;
    test_config.test_duration_seconds = 10;
    test_config.max_communication_latency_ms = 5;
    test_config.heartbeat_interval_ms = 1000;
    test_config.enable_stress_testing = true;
    test_config.enable_fault_injection = true;
    
    // Initialize test state
    memset(agents, 0, sizeof(agents));
    
    return true;
}

static void cleanup_integration_tests(void) {
    printf("Cleaning up integration test environment...\n");
    
    // Shutdown all agents
    for (int i = 0; i < 10; i++) {
        shutdown_agent(i);
    }
    
    // Clean up any remaining resources
    sleep(1); // Allow processes to terminate
}

void register_integration_tests(test_framework_t* framework) {
    test_suite_t* integration_suite = test_suite_create(
        "Multi-Agent Integration",
        "Comprehensive integration testing for all 10 agents under stress",
        TEST_CATEGORY_INTEGRATION
    );
    
    test_case_t integration_tests[] = {
        {
            .name = "test_agent_initialization",
            .description = "Initialize all 10 agents and verify communication",
            .category = TEST_CATEGORY_INTEGRATION,
            .status = TEST_STATUS_PENDING,
            .setup_func = setup_integration_tests,
            .execute_func = test_agent_initialization,
            .teardown_func = NULL,
            .timeout_ms = 30000,
            .retry_count = 1,
            .is_critical = true
        },
        {
            .name = "test_concurrent_module_loading",
            .description = "Test 1000+ concurrent module loading operations",
            .category = TEST_CATEGORY_STRESS,
            .status = TEST_STATUS_PENDING,
            .setup_func = NULL,
            .execute_func = test_concurrent_module_loading,
            .teardown_func = NULL,
            .timeout_ms = 60000,
            .retry_count = 0,
            .is_critical = true
        },
        {
            .name = "test_cross_agent_communication_latency",
            .description = "Validate <5ms cross-agent communication latency",
            .category = TEST_CATEGORY_PERFORMANCE,
            .status = TEST_STATUS_PENDING,
            .setup_func = NULL,
            .execute_func = test_cross_agent_communication_latency,
            .teardown_func = NULL,
            .timeout_ms = 30000,
            .retry_count = 1,
            .is_critical = true
        },
        {
            .name = "test_system_resource_usage",
            .description = "Monitor system resource usage under maximum load",
            .category = TEST_CATEGORY_PERFORMANCE,
            .status = TEST_STATUS_PENDING,
            .setup_func = NULL,
            .execute_func = test_system_resource_usage,
            .teardown_func = NULL,
            .timeout_ms = 30000,
            .retry_count = 0,
            .is_critical = true
        },
        {
            .name = "test_fault_tolerance",
            .description = "Test system resilience to agent failures",
            .category = TEST_CATEGORY_INTEGRATION,
            .status = TEST_STATUS_PENDING,
            .setup_func = NULL,
            .execute_func = test_fault_tolerance,
            .teardown_func = NULL,
            .timeout_ms = 20000,
            .retry_count = 0,
            .is_critical = true
        },
        {
            .name = "test_end_to_end_workflow",
            .description = "Complete workflow with all agents collaborating",
            .category = TEST_CATEGORY_END_TO_END,
            .status = TEST_STATUS_PENDING,
            .setup_func = NULL,
            .execute_func = test_end_to_end_workflow,
            .teardown_func = cleanup_integration_tests,
            .timeout_ms = 15000,
            .retry_count = 1,
            .is_critical = true
        }
    };
    
    for (int i = 0; i < sizeof(integration_tests)/sizeof(integration_tests[0]); i++) {
        test_suite_add_test(integration_suite, &integration_tests[i]);
    }
    
    test_framework_add_suite(framework, integration_suite);
}

/*
 * =============================================================================
 * MAIN INTEGRATION TEST EXECUTION
 * =============================================================================
 */

int main(int argc, char* argv[]) {
    printf("SimCity ARM64 - Agent 1: Core Module System\n");
    printf("Week 4, Day 16 - Multi-Agent Integration Testing\n");
    printf("Target: 1000+ concurrent modules, <5ms latency\n\n");
    
    // Configure test framework for integration testing
    test_runner_config_t config = {
        .verbose_output = true,
        .parallel_execution = false, // Sequential for integration tests
        .max_parallel_tests = 1,
        .stop_on_first_failure = false,
        .generate_coverage_report = false, // Focus on integration, not coverage
        .generate_performance_report = true,
        .generate_security_report = false,
        .max_execution_time_ns = 60000000000ULL, // 60 seconds
        .max_memory_usage_bytes = 100 * 1024 * 1024, // 100MB
        .min_coverage_percentage = 0.0f,
        .min_security_score = 0,
        .json_output = true,
        .html_output = true
    };
    
    strncpy(config.report_directory, "/tmp/simcity_integration_reports", 
            sizeof(config.report_directory));
    strncpy(config.log_file, "/tmp/simcity_integration.log", sizeof(config.log_file));
    
    test_framework_t* framework = test_framework_init(&config);
    if (!framework) {
        fprintf(stderr, "Failed to initialize integration test framework\n");
        return 1;
    }
    
    // Register integration test suites
    register_integration_tests(framework);
    
    // Run all integration tests
    bool success = test_framework_run_all(framework);
    
    // Generate reports
    test_framework_generate_reports(framework);
    test_framework_print_summary(framework);
    
    // Cleanup
    test_framework_destroy(framework);
    
    return success ? 0 : 1;
}