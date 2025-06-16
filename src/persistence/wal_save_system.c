// SimCity ARM64 Write-Ahead Logging Save System
// Agent 6: Save System & Persistence
// Memory-mapped WAL for crash-safe incremental saves with Apple Silicon optimization

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <pthread.h>
#include <errno.h>
#include <zlib.h>
#include <stdint.h>
#include <stdatomic.h>
#include <mach/mach_time.h>
#include <libkern/OSCacheControl.h>

// WAL configuration
#define WAL_FILE_SIZE (128 * 1024 * 1024)    // 128MB WAL file
#define WAL_SEGMENT_SIZE (16 * 1024 * 1024)   // 16MB segments
#define WAL_MAX_SEGMENTS 8
#define WAL_HEADER_SIZE 4096
#define WAL_RECORD_ALIGNMENT 64               // Cache line alignment
#define WAL_COMPRESSION_THRESHOLD 1024        // Compress records > 1KB
#define MAX_CONCURRENT_WRITERS 8
#define CHECKPOINT_INTERVAL_MS 5000           // 5 second checkpoints
#define WAL_MAGIC 0x57414C30                 // "WAL0"
#define WAL_VERSION 1

// Record types
typedef enum {
    WAL_RECORD_SIMULATION_STATE = 1,
    WAL_RECORD_ENTITY_UPDATE = 2,
    WAL_RECORD_BUILDING_PLACEMENT = 3,
    WAL_RECORD_RESOURCE_CHANGE = 4,
    WAL_RECORD_POPULATION_UPDATE = 5,
    WAL_RECORD_CHECKPOINT = 6,
    WAL_RECORD_METADATA = 7
} WALRecordType;

// WAL header structure (4KB)
typedef struct {
    uint32_t magic;                    // WAL_MAGIC
    uint32_t version;                  // WAL_VERSION
    uint64_t creation_time;            // Creation timestamp
    uint64_t last_checkpoint_lsn;     // Last checkpoint LSN
    uint64_t current_lsn;             // Current log sequence number
    uint32_t segment_count;           // Number of segments
    uint32_t active_segment;          // Currently active segment
    uint64_t total_size;              // Total data size
    uint32_t checksum;                // Header checksum
    uint8_t compression_enabled;      // Compression flag
    uint8_t reserved[4071];           // Padding to 4KB
} __attribute__((packed)) WALHeader;

// WAL record header (64 bytes, cache-aligned)
typedef struct {
    uint64_t lsn;                     // Log sequence number
    uint64_t timestamp;               // Record timestamp (nanoseconds)
    uint32_t type;                    // Record type
    uint32_t size;                    // Record size (including header)
    uint32_t data_size;               // Data payload size
    uint32_t checksum;                // Record checksum
    uint32_t thread_id;               // Thread that wrote this record
    uint32_t compressed;              // 1 if data is compressed
    uint8_t reserved[24];             // Padding to 64 bytes
} __attribute__((packed)) WALRecord;

// Memory-mapped WAL file structure
typedef struct {
    int fd;                           // File descriptor
    void* base_addr;                  // Base memory address
    size_t file_size;                 // Total file size
    WALHeader* header;                // Header pointer
    uint8_t* segments[WAL_MAX_SEGMENTS]; // Segment pointers
    atomic_uint64_t write_offset;     // Current write offset
    atomic_uint64_t next_lsn;         // Next LSN to assign
    pthread_mutex_t write_mutex;     // Write synchronization
    pthread_rwlock_t checkpoint_lock; // Checkpoint synchronization
    int checkpoint_in_progress;       // Checkpoint flag
} WALFile;

// Save state structure
typedef struct {
    uint64_t simulation_tick;         // Current simulation tick
    uint32_t entity_count;            // Number of entities
    uint32_t building_count;          // Number of buildings
    uint64_t population;              // Total population
    uint64_t money;                   // Available money
    float happiness_avg;              // Average happiness
    uint32_t day_cycle;               // Current day in cycle
    uint8_t weather_state;            // Current weather
    uint8_t reserved[15];             // Alignment padding
} __attribute__((packed)) SimulationState;

// Entity update record
typedef struct {
    uint32_t entity_id;               // Entity identifier
    float position_x;                 // X position
    float position_y;                 // Y position
    uint32_t state;                   // Entity state
    uint16_t health;                  // Health value
    uint16_t happiness;               // Happiness value
    uint32_t flags;                   // Status flags
} __attribute__((packed)) EntityUpdate;

// Global WAL system state
static struct {
    WALFile wal_file;
    char save_directory[256];
    pthread_t checkpoint_thread;
    atomic_bool system_running;
    uint64_t last_checkpoint_time;
    uint64_t records_written;
    uint64_t bytes_written;
    uint64_t checkpoints_completed;
    pthread_mutex_t stats_mutex;
} g_wal_system = {0};

// Forward declarations
static int wal_create_file(const char* path, size_t size);
static int wal_map_file(WALFile* wal, const char* path);
static void wal_unmap_file(WALFile* wal);
static uint64_t wal_write_record(WALFile* wal, WALRecordType type, const void* data, uint32_t size);
static int wal_compress_data(const void* input, uint32_t input_size, void* output, uint32_t* output_size);
static int wal_decompress_data(const void* input, uint32_t input_size, void* output, uint32_t output_size);
static void* checkpoint_thread_func(void* arg);
static int wal_perform_checkpoint(WALFile* wal);
static uint32_t calculate_checksum(const void* data, size_t size);
static uint64_t get_monotonic_time_ns(void);

//==============================================================================
// INITIALIZATION AND CLEANUP
//==============================================================================

int wal_system_init(const char* save_dir) {
    if (g_wal_system.system_running) {
        return 0; // Already initialized
    }
    
    // Copy save directory path
    strncpy(g_wal_system.save_directory, save_dir, sizeof(g_wal_system.save_directory) - 1);
    g_wal_system.save_directory[sizeof(g_wal_system.save_directory) - 1] = '\0';
    
    // Create save directory if it doesn't exist
    mkdir(save_dir, 0755);
    
    // Initialize WAL file
    char wal_path[512];
    snprintf(wal_path, sizeof(wal_path), "%s/simcity.wal", save_dir);
    
    WALFile* wal = &g_wal_system.wal_file;
    
    // Check if WAL file exists
    struct stat st;
    int file_exists = (stat(wal_path, &st) == 0);
    
    if (!file_exists) {
        printf("Creating new WAL file: %s\n", wal_path);
        if (wal_create_file(wal_path, WAL_FILE_SIZE) != 0) {
            printf("Failed to create WAL file\n");
            return -1;
        }
    }
    
    // Map WAL file into memory
    if (wal_map_file(wal, wal_path) != 0) {
        printf("Failed to map WAL file\n");
        return -1;
    }
    
    // Initialize synchronization primitives
    if (pthread_mutex_init(&wal->write_mutex, NULL) != 0) {
        printf("Failed to initialize write mutex\n");
        wal_unmap_file(wal);
        return -1;
    }
    
    if (pthread_rwlock_init(&wal->checkpoint_lock, NULL) != 0) {
        printf("Failed to initialize checkpoint lock\n");
        pthread_mutex_destroy(&wal->write_mutex);
        wal_unmap_file(wal);
        return -1;
    }
    
    if (pthread_mutex_init(&g_wal_system.stats_mutex, NULL) != 0) {
        printf("Failed to initialize stats mutex\n");
        pthread_rwlock_destroy(&wal->checkpoint_lock);
        pthread_mutex_destroy(&wal->write_mutex);
        wal_unmap_file(wal);
        return -1;
    }
    
    // Initialize atomic variables
    if (file_exists) {
        // Recovery: read current state from header
        atomic_store(&wal->write_offset, wal->header->total_size);
        atomic_store(&wal->next_lsn, wal->header->current_lsn + 1);
        printf("Recovered WAL: LSN=%llu, Size=%llu bytes\n", 
               wal->header->current_lsn, wal->header->total_size);
    } else {
        atomic_store(&wal->write_offset, WAL_HEADER_SIZE);
        atomic_store(&wal->next_lsn, 1);
    }
    
    g_wal_system.system_running = true;
    g_wal_system.last_checkpoint_time = get_monotonic_time_ns();
    
    // Start checkpoint thread
    if (pthread_create(&g_wal_system.checkpoint_thread, NULL, checkpoint_thread_func, NULL) != 0) {
        printf("Failed to create checkpoint thread\n");
        g_wal_system.system_running = false;
        pthread_mutex_destroy(&g_wal_system.stats_mutex);
        pthread_rwlock_destroy(&wal->checkpoint_lock);
        pthread_mutex_destroy(&wal->write_mutex);
        wal_unmap_file(wal);
        return -1;
    }
    
    printf("WAL system initialized: %s\n", wal_path);
    return 0;
}

void wal_system_shutdown(void) {
    if (!g_wal_system.system_running) {
        return;
    }
    
    printf("Shutting down WAL system...\n");
    
    // Signal shutdown
    g_wal_system.system_running = false;
    
    // Wait for checkpoint thread to finish
    pthread_join(g_wal_system.checkpoint_thread, NULL);
    
    // Perform final checkpoint
    WALFile* wal = &g_wal_system.wal_file;
    wal_perform_checkpoint(wal);
    
    // Cleanup
    pthread_mutex_destroy(&g_wal_system.stats_mutex);
    pthread_rwlock_destroy(&wal->checkpoint_lock);
    pthread_mutex_destroy(&wal->write_mutex);
    wal_unmap_file(wal);
    
    printf("WAL system shutdown complete\n");
}

//==============================================================================
// FILE MANAGEMENT
//==============================================================================

static int wal_create_file(const char* path, size_t size) {
    int fd = open(path, O_CREAT | O_RDWR | O_TRUNC, 0644);
    if (fd < 0) {
        perror("open");
        return -1;
    }
    
    // Pre-allocate file space
    if (ftruncate(fd, size) != 0) {
        perror("ftruncate");
        close(fd);
        return -1;
    }
    
    // Write initial header
    WALHeader header = {0};
    header.magic = WAL_MAGIC;
    header.version = WAL_VERSION;
    header.creation_time = get_monotonic_time_ns();
    header.current_lsn = 0;
    header.segment_count = WAL_MAX_SEGMENTS;
    header.active_segment = 0;
    header.total_size = WAL_HEADER_SIZE;
    header.compression_enabled = 1;
    header.checksum = calculate_checksum(&header, sizeof(header) - sizeof(header.checksum));
    
    if (write(fd, &header, sizeof(header)) != sizeof(header)) {
        perror("write header");
        close(fd);
        return -1;
    }
    
    // Force write to disk
    fsync(fd);
    close(fd);
    
    return 0;
}

static int wal_map_file(WALFile* wal, const char* path) {
    wal->fd = open(path, O_RDWR);
    if (wal->fd < 0) {
        perror("open WAL file");
        return -1;
    }
    
    // Get file size
    struct stat st;
    if (fstat(wal->fd, &st) != 0) {
        perror("fstat");
        close(wal->fd);
        return -1;
    }
    
    wal->file_size = st.st_size;
    
    // Memory map the file
    wal->base_addr = mmap(NULL, wal->file_size, PROT_READ | PROT_WRITE, MAP_SHARED, wal->fd, 0);
    if (wal->base_addr == MAP_FAILED) {
        perror("mmap");
        close(wal->fd);
        return -1;
    }
    
    // Set up pointers
    wal->header = (WALHeader*)wal->base_addr;
    
    // Verify header
    if (wal->header->magic != WAL_MAGIC) {
        printf("Invalid WAL magic: 0x%x\n", wal->header->magic);
        munmap(wal->base_addr, wal->file_size);
        close(wal->fd);
        return -1;
    }
    
    if (wal->header->version != WAL_VERSION) {
        printf("Unsupported WAL version: %d\n", wal->header->version);
        munmap(wal->base_addr, wal->file_size);
        close(wal->fd);
        return -1;
    }
    
    // Set up segment pointers
    uint8_t* base = (uint8_t*)wal->base_addr + WAL_HEADER_SIZE;
    for (int i = 0; i < WAL_MAX_SEGMENTS; i++) {
        wal->segments[i] = base + (i * WAL_SEGMENT_SIZE);
    }
    
    // Advise kernel about access patterns
    madvise(wal->base_addr, wal->file_size, MADV_SEQUENTIAL);
    
    printf("WAL file mapped: %zu bytes\n", wal->file_size);
    return 0;
}

static void wal_unmap_file(WALFile* wal) {
    if (wal->base_addr && wal->base_addr != MAP_FAILED) {
        // Ensure all writes are flushed
        msync(wal->base_addr, wal->file_size, MS_SYNC);
        munmap(wal->base_addr, wal->file_size);
    }
    
    if (wal->fd >= 0) {
        close(wal->fd);
    }
    
    memset(wal, 0, sizeof(WALFile));
}

//==============================================================================
// RECORD WRITING
//==============================================================================

static uint64_t wal_write_record(WALFile* wal, WALRecordType type, const void* data, uint32_t size) {
    if (!data || size == 0) {
        return 0;
    }
    
    // Acquire read lock to prevent checkpoint during write
    pthread_rwlock_rdlock(&wal->checkpoint_lock);
    
    uint64_t lsn = atomic_fetch_add(&wal->next_lsn, 1);
    uint64_t timestamp = get_monotonic_time_ns();
    
    // Prepare record header
    WALRecord record_header = {0};
    record_header.lsn = lsn;
    record_header.timestamp = timestamp;
    record_header.type = type;
    record_header.data_size = size;
    record_header.thread_id = (uint32_t)pthread_self();
    record_header.compressed = 0;
    
    // Check if we should compress the data
    void* write_data = (void*)data;
    uint32_t write_size = size;
    uint8_t* compressed_buffer = NULL;
    
    if (size >= WAL_COMPRESSION_THRESHOLD && wal->header->compression_enabled) {
        compressed_buffer = malloc(size + 64); // Extra space for compression overhead
        if (compressed_buffer) {
            uint32_t compressed_size = size + 64;
            if (wal_compress_data(data, size, compressed_buffer, &compressed_size) == 0) {
                if (compressed_size < size) {
                    write_data = compressed_buffer;
                    write_size = compressed_size;
                    record_header.compressed = 1;
                }
            }
        }
    }
    
    // Calculate total record size (aligned)
    uint32_t total_size = sizeof(WALRecord) + write_size;
    uint32_t aligned_size = (total_size + WAL_RECORD_ALIGNMENT - 1) & ~(WAL_RECORD_ALIGNMENT - 1);
    record_header.size = aligned_size;
    
    // Calculate checksum
    record_header.checksum = calculate_checksum(write_data, write_size);
    
    // Acquire write mutex for atomic write
    pthread_mutex_lock(&wal->write_mutex);
    
    uint64_t write_offset = atomic_load(&wal->write_offset);
    
    // Check if we have enough space
    if (write_offset + aligned_size > wal->file_size) {
        printf("WAL file full, triggering emergency checkpoint\n");
        pthread_mutex_unlock(&wal->write_mutex);
        pthread_rwlock_unlock(&wal->checkpoint_lock);
        
        if (compressed_buffer) free(compressed_buffer);
        
        // Emergency checkpoint
        wal_perform_checkpoint(wal);
        return 0;
    }
    
    // Write record header
    uint8_t* write_ptr = (uint8_t*)wal->base_addr + write_offset;
    memcpy(write_ptr, &record_header, sizeof(WALRecord));
    write_ptr += sizeof(WALRecord);
    
    // Write data
    memcpy(write_ptr, write_data, write_size);
    write_ptr += write_size;
    
    // Zero-pad to alignment
    uint32_t padding = aligned_size - total_size;
    if (padding > 0) {
        memset(write_ptr, 0, padding);
    }
    
    // Ensure cache coherency on Apple Silicon
    sys_cache_control(kCacheFunctionPrepareForStore, write_ptr - aligned_size, aligned_size);
    
    // Update offsets
    atomic_store(&wal->write_offset, write_offset + aligned_size);
    wal->header->current_lsn = lsn;
    wal->header->total_size = write_offset + aligned_size;
    
    pthread_mutex_unlock(&wal->write_mutex);
    pthread_rwlock_unlock(&wal->checkpoint_lock);
    
    // Update statistics
    pthread_mutex_lock(&g_wal_system.stats_mutex);
    g_wal_system.records_written++;
    g_wal_system.bytes_written += aligned_size;
    pthread_mutex_unlock(&g_wal_system.stats_mutex);
    
    if (compressed_buffer) {
        free(compressed_buffer);
    }
    
    return lsn;
}

//==============================================================================
// PUBLIC API
//==============================================================================

int wal_save_simulation_state(const SimulationState* state) {
    if (!g_wal_system.system_running || !state) {
        return -1;
    }
    
    uint64_t lsn = wal_write_record(&g_wal_system.wal_file, WAL_RECORD_SIMULATION_STATE, 
                                    state, sizeof(SimulationState));
    return (lsn > 0) ? 0 : -1;
}

int wal_save_entity_update(const EntityUpdate* update) {
    if (!g_wal_system.system_running || !update) {
        return -1;
    }
    
    uint64_t lsn = wal_write_record(&g_wal_system.wal_file, WAL_RECORD_ENTITY_UPDATE,
                                    update, sizeof(EntityUpdate));
    return (lsn > 0) ? 0 : -1;
}

int wal_save_batch_entity_updates(const EntityUpdate* updates, uint32_t count) {
    if (!g_wal_system.system_running || !updates || count == 0) {
        return -1;
    }
    
    uint64_t lsn = wal_write_record(&g_wal_system.wal_file, WAL_RECORD_ENTITY_UPDATE,
                                    updates, sizeof(EntityUpdate) * count);
    return (lsn > 0) ? 0 : -1;
}

int wal_force_checkpoint(void) {
    if (!g_wal_system.system_running) {
        return -1;
    }
    
    return wal_perform_checkpoint(&g_wal_system.wal_file);
}

void wal_get_statistics(uint64_t* records_written, uint64_t* bytes_written, 
                       uint64_t* checkpoints_completed) {
    pthread_mutex_lock(&g_wal_system.stats_mutex);
    if (records_written) *records_written = g_wal_system.records_written;
    if (bytes_written) *bytes_written = g_wal_system.bytes_written;
    if (checkpoints_completed) *checkpoints_completed = g_wal_system.checkpoints_completed;
    pthread_mutex_unlock(&g_wal_system.stats_mutex);
}

//==============================================================================
// CHECKPOINT SYSTEM
//==============================================================================

static void* checkpoint_thread_func(void* arg) {
    printf("Checkpoint thread started\n");
    
    while (g_wal_system.system_running) {
        usleep(CHECKPOINT_INTERVAL_MS * 1000); // Convert to microseconds
        
        if (!g_wal_system.system_running) break;
        
        uint64_t current_time = get_monotonic_time_ns();
        uint64_t elapsed = current_time - g_wal_system.last_checkpoint_time;
        
        if (elapsed >= (CHECKPOINT_INTERVAL_MS * 1000000ULL)) { // Convert to nanoseconds
            wal_perform_checkpoint(&g_wal_system.wal_file);
            g_wal_system.last_checkpoint_time = current_time;
        }
    }
    
    printf("Checkpoint thread shutting down\n");
    return NULL;
}

static int wal_perform_checkpoint(WALFile* wal) {
    // Acquire write lock to prevent new writes during checkpoint
    pthread_rwlock_wrlock(&wal->checkpoint_lock);
    
    printf("Performing WAL checkpoint...\n");
    
    // Update header with current state
    wal->header->last_checkpoint_lsn = wal->header->current_lsn;
    wal->header->checksum = calculate_checksum(wal->header, 
                                               sizeof(WALHeader) - sizeof(wal->header->checksum));
    
    // Force write to storage
    if (msync(wal->base_addr, wal->file_size, MS_SYNC) != 0) {
        perror("msync during checkpoint");
        pthread_rwlock_unlock(&wal->checkpoint_lock);
        return -1;
    }
    
    // Additional fsync for extra safety
    if (fsync(wal->fd) != 0) {
        perror("fsync during checkpoint");
        pthread_rwlock_unlock(&wal->checkpoint_lock);
        return -1;
    }
    
    pthread_mutex_lock(&g_wal_system.stats_mutex);
    g_wal_system.checkpoints_completed++;
    pthread_mutex_unlock(&g_wal_system.stats_mutex);
    
    pthread_rwlock_unlock(&wal->checkpoint_lock);
    
    printf("Checkpoint completed (LSN: %llu)\n", wal->header->current_lsn);
    return 0;
}

//==============================================================================
// UTILITY FUNCTIONS
//==============================================================================

static int wal_compress_data(const void* input, uint32_t input_size, void* output, uint32_t* output_size) {
    uLongf dest_len = *output_size;
    int result = compress2((Bytef*)output, &dest_len, (const Bytef*)input, input_size, Z_DEFAULT_COMPRESSION);
    
    if (result == Z_OK) {
        *output_size = (uint32_t)dest_len;
        return 0;
    }
    
    return -1;
}

static int wal_decompress_data(const void* input, uint32_t input_size, void* output, uint32_t output_size) {
    uLongf dest_len = output_size;
    int result = uncompress((Bytef*)output, &dest_len, (const Bytef*)input, input_size);
    
    return (result == Z_OK) ? 0 : -1;
}

static uint32_t calculate_checksum(const void* data, size_t size) {
    // Simple CRC32 checksum using zlib
    return (uint32_t)crc32(0L, (const Bytef*)data, size);
}

static uint64_t get_monotonic_time_ns(void) {
    // Use mach_absolute_time for high-precision timing on macOS
    static mach_timebase_info_data_t timebase = {0, 0};
    if (timebase.denom == 0) {
        mach_timebase_info(&timebase);
    }
    
    uint64_t mach_time = mach_absolute_time();
    return mach_time * timebase.numer / timebase.denom;
}

void wal_print_statistics(void) {
    uint64_t records, bytes, checkpoints;
    wal_get_statistics(&records, &bytes, &checkpoints);
    
    printf("\n=== WAL System Statistics ===\n");
    printf("Records written: %llu\n", records);
    printf("Bytes written: %llu (%.2f MB)\n", bytes, bytes / (1024.0 * 1024.0));
    printf("Checkpoints completed: %llu\n", checkpoints);
    printf("Current LSN: %llu\n", g_wal_system.wal_file.header->current_lsn);
    printf("WAL file size: %.2f MB\n", g_wal_system.wal_file.file_size / (1024.0 * 1024.0));
    printf("============================\n\n");
}
