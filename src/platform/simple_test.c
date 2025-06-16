#include <stdio.h>

// Simple test to verify basic syscall functionality
// Declare the functions we want to test
extern int sys_getpid(void);
extern int sys_write(int fd, const void* buf, int count);

int main() {
    printf("Testing basic syscall wrappers...\n");
    
    int pid = sys_getpid();
    printf("Process ID: %d\n", pid);
    
    const char* msg = "Direct syscall test\n";
    sys_write(1, msg, 20);  // Write to stdout
    
    return 0;
}