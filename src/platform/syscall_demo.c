//
// SimCity ARM64 Assembly - System Call Demo
// Agent E3: Platform Team - System Call Wrappers Demo
//
// Simple C program to test and demonstrate the system call wrappers
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include "../../include/interfaces/platform.h"

#define TEST_FILE_PATH "/tmp/simcity_syscall_test"
#define TEST_DIR_PATH "/tmp/simcity_test_dir"
#define TEST_DATA "SimCity ARM64 System Call Test Data"

int main() {
    printf("Agent E3 System Call Wrappers Demo\n");
    printf("==================================\n\n");
    
    int tests_passed = 0;
    int tests_total = 0;
    
    // Test 1: Basic file operations
    printf("Test 1: Basic file operations\n");
    tests_total++;
    
    // Create and write to a file
    int fd = sys_open(TEST_FILE_PATH, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd >= 0) {
        ssize_t written = sys_write(fd, TEST_DATA, strlen(TEST_DATA));
        sys_close(fd);
        
        if (written == strlen(TEST_DATA)) {
            // Read the file back
            fd = sys_open(TEST_FILE_PATH, O_RDONLY, 0);
            if (fd >= 0) {
                char buffer[256];
                ssize_t read_bytes = sys_read(fd, buffer, sizeof(buffer));
                sys_close(fd);
                
                if (read_bytes == strlen(TEST_DATA) && 
                    memcmp(buffer, TEST_DATA, strlen(TEST_DATA)) == 0) {
                    printf("  ✓ File I/O operations successful\n");
                    tests_passed++;
                } else {
                    printf("  ✗ File read verification failed\n");
                }
            } else {
                printf("  ✗ Failed to open file for reading\n");
            }
        } else {
            printf("  ✗ File write failed\n");
        }
    } else {
        printf("  ✗ Failed to create file\n");
    }
    
    // Test 2: File status operations
    printf("\nTest 2: File status operations\n");
    tests_total++;
    
    struct stat st;
    if (sys_stat(TEST_FILE_PATH, &st) == 0) {
        if (st.st_size == strlen(TEST_DATA)) {
            printf("  ✓ File stat successful, size: %lld bytes\n", st.st_size);
            tests_passed++;
        } else {
            printf("  ✗ File size mismatch: expected %zu, got %lld\n", 
                   strlen(TEST_DATA), st.st_size);
        }
    } else {
        printf("  ✗ File stat failed\n");
    }
    
    // Test 3: High-level platform functions
    printf("\nTest 3: High-level platform functions\n");
    tests_total++;
    
    int exists = platform_file_exists(TEST_FILE_PATH);
    off_t size = platform_get_file_size(TEST_FILE_PATH);
    
    if (exists == 1 && size == strlen(TEST_DATA)) {
        printf("  ✓ Platform file functions successful\n");
        printf("    - File exists: %s\n", exists ? "yes" : "no");
        printf("    - File size: %lld bytes\n", size);
        tests_passed++;
    } else {
        printf("  ✗ Platform file functions failed\n");
        printf("    - File exists: %s (expected: yes)\n", exists ? "yes" : "no");
        printf("    - File size: %lld (expected: %zu)\n", size, strlen(TEST_DATA));
    }
    
    // Test 4: Directory operations
    printf("\nTest 4: Directory operations\n");
    tests_total++;
    
    if (platform_create_directory(TEST_DIR_PATH, 0755) == 0) {
        if (sys_access(TEST_DIR_PATH, F_OK) == 0) {
            printf("  ✓ Directory creation successful\n");
            tests_passed++;
            
            // Clean up directory
            sys_rmdir(TEST_DIR_PATH);
        } else {
            printf("  ✗ Directory access failed\n");
        }
    } else {
        printf("  ✗ Directory creation failed\n");
    }
    
    // Test 5: Memory operations
    printf("\nTest 5: Memory operations\n");
    tests_total++;
    
    void* mem = platform_alloc_memory(4096);
    if (mem != NULL) {
        // Write test pattern
        *(uint32_t*)mem = 0x12345678;
        
        // Verify pattern
        if (*(uint32_t*)mem == 0x12345678) {
            printf("  ✓ Memory allocation and access successful\n");
            tests_passed++;
        } else {
            printf("  ✗ Memory access verification failed\n");
        }
        
        // Free memory
        platform_free_memory(mem, 4096);
    } else {
        printf("  ✗ Memory allocation failed\n");
    }
    
    // Test 6: Process information
    printf("\nTest 6: Process information\n");
    tests_total++;
    
    pid_t pid = sys_getpid();
    pid_t ppid = sys_getppid();
    
    if (pid > 0 && ppid > 0) {
        printf("  ✓ Process information successful\n");
        printf("    - Process ID: %d\n", pid);
        printf("    - Parent Process ID: %d\n", ppid);
        tests_passed++;
    } else {
        printf("  ✗ Process information failed\n");
    }
    
    // Test 7: Time operations
    printf("\nTest 7: Time operations\n");
    tests_total++;
    
    uint64_t start_time = platform_get_precise_time();
    platform_sleep_nanoseconds(1000000); // Sleep 1ms
    uint64_t end_time = platform_get_precise_time();
    
    uint64_t elapsed = end_time - start_time;
    if (elapsed >= 900000 && elapsed <= 2000000) { // Allow some variance
        printf("  ✓ Time operations successful\n");
        printf("    - Elapsed time: %llu ns\n", elapsed);
        tests_passed++;
    } else {
        printf("  ✗ Time operations failed\n");
        printf("    - Elapsed time: %llu ns (expected ~1000000)\n", elapsed);
    }
    
    // Clean up test file
    sys_unlink(TEST_FILE_PATH);
    
    // Print summary
    printf("\n==================================\n");
    printf("Test Summary: %d/%d tests passed\n", tests_passed, tests_total);
    
    if (tests_passed == tests_total) {
        printf("🎉 All tests passed! System call wrappers are working correctly.\n");
        return 0;
    } else {
        printf("❌ Some tests failed. Please check the implementation.\n");
        return 1;
    }
}