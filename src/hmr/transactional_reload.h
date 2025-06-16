/*
 * SimCity ARM64 - Transactional Hot-Reload System
 * 
 * High-performance transactional hot-reload system with ACID properties for
 * atomic module updates, intelligent conflict resolution, and comprehensive
 * rollback capabilities.
 * 
 * Features:
 * - ACID-compliant transactions with distributed coordination
 * - Intelligent conflict resolution with automatic merging
 * - Multi-version concurrency control (MVCC)
 * - Zero-downtime atomic updates
 * - Comprehensive rollback and recovery
 * - Performance: <15ms hot-reload latency target
 * 
 * Performance Targets:
 * - Transaction commit: <5ms for single module
 * - Multi-module transaction: <15ms for full dependency chain
 * - Conflict resolution: <3ms for automatic merge
 * - Rollback latency: <2ms for automatic recovery
 * - State preservation: <3ms for complex states
 */

#ifndef TRANSACTIONAL_RELOAD_H
#define TRANSACTIONAL_RELOAD_H

#include <stdint.h>
#include <stdbool.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

// ACID Transaction Types
typedef enum {
    TXN_TYPE_SINGLE_MODULE = 0,     // Single module update
    TXN_TYPE_DEPENDENCY_CHAIN = 1,  // Multi-module dependency update
    TXN_TYPE_GLOBAL_STATE = 2,      // Global state modification
    TXN_TYPE_SCHEMA_MIGRATION = 3,  // Module interface changes
    TXN_TYPE_BATCH_UPDATE = 4       // Batch of independent updates
} txn_type_t;

// Transaction State
typedef enum {
    TXN_STATE_ACTIVE = 0,           // Transaction in progress
    TXN_STATE_PREPARING = 1,        // Preparing to commit (2PC Phase 1)
    TXN_STATE_PREPARED = 2,         // Ready to commit (2PC Phase 2)
    TXN_STATE_COMMITTING = 3,       // Commit in progress
    TXN_STATE_COMMITTED = 4,        // Successfully committed
    TXN_STATE_ABORTING = 5,         // Abort in progress
    TXN_STATE_ABORTED = 6,          // Transaction aborted
    TXN_STATE_FAILED = 7            // Transaction failed
} txn_state_t;

// Conflict Resolution Strategy
typedef enum {
    CONFLICT_STRATEGY_AUTO_MERGE = 0,      // Automatic merge using diff algorithms
    CONFLICT_STRATEGY_MANUAL_RESOLVE = 1,  // Manual conflict resolution required
    CONFLICT_STRATEGY_OVERRIDE_NEW = 2,    // Use new version (force update)
    CONFLICT_STRATEGY_KEEP_CURRENT = 3,    // Keep current version (reject update)
    CONFLICT_STRATEGY_THREE_WAY_MERGE = 4  // Three-way merge with common ancestor
} conflict_strategy_t;

// Transaction Isolation Level
typedef enum {
    ISOLATION_READ_UNCOMMITTED = 0,  // Lowest isolation
    ISOLATION_READ_COMMITTED = 1,    // Read committed data only
    ISOLATION_REPEATABLE_READ = 2,   // Repeatable reads
    ISOLATION_SERIALIZABLE = 3       // Highest isolation (default)
} isolation_level_t;

// Module Version Information
typedef struct {
    uint64_t version_id;             // Unique version identifier
    uint64_t timestamp;              // Version creation timestamp
    uint32_t checksum;               // Module content checksum
    uint32_t dependency_hash;        // Dependency graph hash
    char version_tag[64];            // Human-readable version tag
    uint8_t compatibility_level;     // API compatibility level
    uint8_t breaking_changes;        // Breaking change indicators
    uint8_t reserved[2];
} module_version_t;

// Module State Snapshot
typedef struct {
    uint64_t snapshot_id;            // Unique snapshot identifier
    uint64_t timestamp;              // Snapshot creation time
    void* state_data;                // Serialized module state
    size_t state_size;               // Size of state data
    uint32_t state_checksum;         // State data integrity check
    uint8_t compression_type;        // State compression algorithm
    uint8_t encryption_level;        // State encryption level
    uint8_t reserved[2];
} state_snapshot_t;

// Transaction Dependency
typedef struct {
    uint32_t module_id;              // Dependent module ID
    uint32_t required_version;       // Required minimum version
    uint8_t dependency_type;         // Type of dependency
    uint8_t critical_path;           // Is on critical update path
    uint8_t reserved[2];
} txn_dependency_t;

// Conflict Information
typedef struct {
    uint32_t conflict_id;            // Unique conflict identifier
    uint32_t module_id;              // Module with conflict
    uint64_t current_version;        // Current module version
    uint64_t new_version;            // Attempted new version
    uint32_t conflict_type;          // Type of conflict
    char conflict_location[256];     // Location description
    void* conflict_data;             // Conflict-specific data
    size_t conflict_data_size;       // Size of conflict data
    conflict_strategy_t strategy;    // Resolution strategy
    uint8_t auto_resolvable;         // Can be automatically resolved
    uint8_t severity;               // Conflict severity (0-255)
    uint8_t reserved[2];
} conflict_info_t;

// Transaction Operation
typedef struct {
    uint32_t operation_id;           // Unique operation identifier
    uint32_t module_id;              // Target module ID
    uint8_t operation_type;          // Type of operation
    uint8_t rollback_required;       // Requires rollback support
    uint8_t state_dependent;         // Depends on module state
    uint8_t reserved;
    void* operation_data;            // Operation-specific data
    size_t data_size;               // Size of operation data
    void* rollback_data;            // Data needed for rollback
    size_t rollback_size;           // Size of rollback data
} txn_operation_t;

// Transaction Log Entry
typedef struct {
    uint64_t log_sequence_number;    // LSN for WAL ordering
    uint64_t transaction_id;         // Transaction identifier
    uint64_t timestamp;              // Operation timestamp
    uint32_t operation_id;           // Operation being logged
    uint8_t operation_type;          // Type of operation
    uint8_t log_level;              // Log entry importance
    uint8_t reserved[2];
    void* log_data;                 // Log entry data
    size_t log_data_size;           // Size of log data
    uint32_t checksum;              // Log entry integrity
} txn_log_entry_t;

// Performance Metrics
typedef struct {
    uint64_t transaction_count;      // Total transactions processed
    uint64_t commit_count;           // Successful commits
    uint64_t abort_count;            // Aborted transactions
    uint64_t conflict_count;         // Total conflicts encountered
    uint64_t auto_resolved_conflicts; // Automatically resolved conflicts
    
    // Timing metrics (in microseconds)
    uint32_t avg_commit_time;        // Average commit time
    uint32_t max_commit_time;        // Maximum commit time
    uint32_t avg_rollback_time;      // Average rollback time
    uint32_t max_rollback_time;      // Maximum rollback time
    uint32_t avg_conflict_resolution_time; // Average conflict resolution time
    
    // Current active metrics
    uint32_t active_transactions;    // Currently active transactions
    uint32_t pending_conflicts;      // Conflicts awaiting resolution
    uint32_t lock_contention_count;  // Lock contention events
    uint8_t reserved[12];
} txn_performance_metrics_t;

// Multi-Version Concurrency Control (MVCC) Entry
typedef struct {
    uint64_t version_id;             // Version identifier
    uint64_t creation_timestamp;     // When version was created
    uint64_t commit_timestamp;       // When version was committed (0 if uncommitted)
    uint32_t creator_txn_id;         // Transaction that created this version
    uint8_t visibility_mask;         // Which transactions can see this version
    uint8_t is_committed;           // Is this version committed
    uint8_t reserved[2];
    void* version_data;             // Version-specific data
    size_t data_size;               // Size of version data
} mvcc_version_t;

// Transaction Coordinator (for distributed transactions)
typedef struct {
    uint64_t coordinator_id;         // Unique coordinator identifier
    uint32_t participant_count;      // Number of transaction participants
    uint32_t active_transactions;    // Currently coordinating
    txn_state_t coordinator_state;   // Overall coordination state
    uint8_t two_phase_commit_enabled; // Using 2PC protocol
    uint8_t reserved[3];
    
    // Timing for distributed coordination
    uint32_t phase1_timeout_ms;      // Phase 1 (prepare) timeout
    uint32_t phase2_timeout_ms;      // Phase 2 (commit) timeout
    uint32_t abort_timeout_ms;       // Abort operation timeout
    
    // Performance tracking
    uint64_t successful_2pc_count;   // Successful 2PC transactions
    uint64_t failed_2pc_count;       // Failed 2PC transactions
    uint32_t avg_2pc_latency;        // Average 2PC latency (μs)
    uint32_t max_2pc_latency;        // Maximum 2PC latency (μs)
} txn_coordinator_t;

// Main Transaction Context
typedef struct {
    uint64_t transaction_id;         // Unique transaction identifier
    uint64_t start_timestamp;        // Transaction start time
    uint64_t last_activity;          // Last activity timestamp
    
    txn_type_t type;                // Transaction type
    txn_state_t state;              // Current transaction state
    isolation_level_t isolation;     // Isolation level
    
    uint32_t operation_count;        // Number of operations in transaction
    uint32_t max_operations;         // Maximum operations allowed
    txn_operation_t* operations;     // Array of operations
    
    uint32_t dependency_count;       // Number of dependencies
    uint32_t max_dependencies;       // Maximum dependencies allowed
    txn_dependency_t* dependencies;  // Dependency list
    
    uint32_t conflict_count;         // Number of conflicts encountered
    uint32_t max_conflicts;          // Maximum conflicts to handle
    conflict_info_t* conflicts;      // Conflict information
    
    uint32_t snapshot_count;         // Number of state snapshots
    uint32_t max_snapshots;          // Maximum snapshots allowed
    state_snapshot_t* snapshots;     // State snapshots for rollback
    
    // MVCC support
    uint64_t read_timestamp;         // Transaction read timestamp
    uint64_t write_timestamp;        // Transaction write timestamp
    uint32_t mvcc_version_count;     // Number of MVCC versions
    mvcc_version_t* mvcc_versions;   // MVCC version tracking
    
    // Performance tracking
    uint64_t bytes_read;             // Bytes read during transaction
    uint64_t bytes_written;          // Bytes written during transaction
    uint32_t lock_wait_time;         // Time spent waiting for locks (μs)
    uint32_t conflict_resolution_time; // Time spent resolving conflicts (μs)
    
    // Distributed transaction support
    txn_coordinator_t* coordinator;  // Distributed transaction coordinator
    uint32_t participant_id;         // This participant's ID in distributed txn
    
    // Rollback and recovery
    void* rollback_log;             // Rollback operation log
    size_t rollback_log_size;       // Size of rollback log
    uint8_t auto_rollback_enabled;   // Automatic rollback on failure
    uint8_t checkpoint_enabled;      // Checkpointing enabled
    uint8_t reserved[2];
    
    // Security and audit
    uint32_t security_level;         // Required security level
    char audit_trail_id[64];        // Audit trail identifier
    uint8_t audit_required;         // Audit trail required
    uint8_t compliance_mode;        // Compliance mode active
    uint8_t reserved2[2];
} transaction_context_t;

// Global Transaction Manager
typedef struct {
    uint64_t next_transaction_id;    // Next available transaction ID
    uint32_t max_concurrent_txns;    // Maximum concurrent transactions
    uint32_t active_transaction_count; // Currently active transactions
    
    transaction_context_t* active_transactions; // Array of active transactions
    uint32_t transaction_table_size; // Size of transaction table
    uint32_t* free_transaction_slots; // Available transaction slots
    uint32_t free_slot_count;        // Number of free slots
    
    // Global coordination
    txn_coordinator_t global_coordinator; // Global transaction coordinator
    uint64_t global_timestamp;       // Global timestamp counter
    uint32_t deadlock_detection_interval; // Deadlock detection frequency (ms)
    uint32_t txn_timeout_ms;         // Default transaction timeout
    
    // Performance monitoring
    txn_performance_metrics_t metrics; // Performance metrics
    uint64_t total_commits;          // Total committed transactions
    uint64_t total_aborts;           // Total aborted transactions
    
    // Configuration
    uint8_t strict_2pc_enabled;      // Strict 2PC for all distributed txns
    uint8_t auto_retry_enabled;      // Automatic retry on conflicts
    uint8_t deadlock_prevention;     // Deadlock prevention enabled
    uint8_t reserved[5];
    
    // Memory management
    void* memory_pool;              // Memory pool for transactions
    size_t pool_size;               // Size of memory pool
    size_t pool_used;               // Currently used pool memory
    uint32_t allocation_count;       // Number of allocations
    uint32_t deallocation_count;     // Number of deallocations
    
    // Lock management (for concurrency control)
    void* lock_manager;             // Lock manager instance
    uint32_t max_locks;             // Maximum concurrent locks
    uint32_t active_locks;          // Currently held locks
    uint32_t lock_timeout_ms;       // Lock acquisition timeout
} transaction_manager_t;

// ============================================================================
// Core Transaction Management API
// ============================================================================

/*
 * Initialize the transactional hot-reload system
 * 
 * @param max_concurrent_txns Maximum concurrent transactions
 * @param memory_pool_size Size of memory pool for transactions
 * @param enable_2pc Enable two-phase commit for distributed transactions
 * @return Transaction manager instance or NULL on failure
 */
transaction_manager_t* txn_init_manager(
    uint32_t max_concurrent_txns,
    size_t memory_pool_size,
    bool enable_2pc
);

/*
 * Shutdown the transaction manager and cleanup resources
 * 
 * @param manager Transaction manager to shutdown
 * @return 0 on success, -1 on failure
 */
int txn_shutdown_manager(transaction_manager_t* manager);

/*
 * Begin a new transaction
 * 
 * @param manager Transaction manager
 * @param type Transaction type
 * @param isolation Isolation level
 * @return Transaction context or NULL on failure
 */
transaction_context_t* txn_begin(
    transaction_manager_t* manager,
    txn_type_t type,
    isolation_level_t isolation
);

/*
 * Commit a transaction (ACID compliant)
 * 
 * @param manager Transaction manager
 * @param txn Transaction context
 * @return 0 on success, -1 on failure
 */
int txn_commit(transaction_manager_t* manager, transaction_context_t* txn);

/*
 * Abort a transaction and rollback all changes
 * 
 * @param manager Transaction manager
 * @param txn Transaction context
 * @return 0 on success, -1 on failure
 */
int txn_abort(transaction_manager_t* manager, transaction_context_t* txn);

// ============================================================================
// Module Update Operations
// ============================================================================

/*
 * Add a module update operation to a transaction
 * 
 * @param txn Transaction context
 * @param module_id Module to update
 * @param new_version New module version
 * @param module_data New module data
 * @param data_size Size of module data
 * @return 0 on success, -1 on failure
 */
int txn_add_module_update(
    transaction_context_t* txn,
    uint32_t module_id,
    const module_version_t* new_version,
    const void* module_data,
    size_t data_size
);

/*
 * Add a state preservation operation to a transaction
 * 
 * @param txn Transaction context
 * @param module_id Module whose state to preserve
 * @param state_data Current state data
 * @param state_size Size of state data
 * @return 0 on success, -1 on failure
 */
int txn_add_state_preservation(
    transaction_context_t* txn,
    uint32_t module_id,
    const void* state_data,
    size_t state_size
);

/*
 * Add a dependency constraint to a transaction
 * 
 * @param txn Transaction context
 * @param module_id Module with dependency
 * @param dependency Dependency information
 * @return 0 on success, -1 on failure
 */
int txn_add_dependency(
    transaction_context_t* txn,
    uint32_t module_id,
    const txn_dependency_t* dependency
);

// ============================================================================
// Conflict Detection and Resolution
// ============================================================================

/*
 * Detect conflicts in a transaction
 * 
 * @param manager Transaction manager
 * @param txn Transaction context
 * @return Number of conflicts detected
 */
uint32_t txn_detect_conflicts(
    transaction_manager_t* manager,
    transaction_context_t* txn
);

/*
 * Resolve conflicts automatically using specified strategy
 * 
 * @param manager Transaction manager
 * @param txn Transaction context
 * @param strategy Conflict resolution strategy
 * @return Number of conflicts resolved, -1 on failure
 */
int txn_resolve_conflicts(
    transaction_manager_t* manager,
    transaction_context_t* txn,
    conflict_strategy_t strategy
);

/*
 * Get detailed conflict information
 * 
 * @param txn Transaction context
 * @param conflict_index Index of conflict to query
 * @return Conflict information or NULL if invalid index
 */
const conflict_info_t* txn_get_conflict_info(
    const transaction_context_t* txn,
    uint32_t conflict_index
);

/*
 * Perform three-way merge for conflicting modules
 * 
 * @param base_version Common ancestor version
 * @param current_version Current version
 * @param new_version New version being applied
 * @param merged_result Output buffer for merged result
 * @param result_size Size of output buffer
 * @return Size of merged result, -1 on failure
 */
ssize_t txn_three_way_merge(
    const module_version_t* base_version,
    const module_version_t* current_version,
    const module_version_t* new_version,
    void* merged_result,
    size_t result_size
);

// ============================================================================
// MVCC (Multi-Version Concurrency Control)
// ============================================================================

/*
 * Create a new MVCC version for a module
 * 
 * @param txn Transaction context
 * @param module_id Module identifier
 * @param version_data Version-specific data
 * @param data_size Size of version data
 * @return Version ID or 0 on failure
 */
uint64_t txn_create_mvcc_version(
    transaction_context_t* txn,
    uint32_t module_id,
    const void* version_data,
    size_t data_size
);

/*
 * Get the appropriate MVCC version for reading
 * 
 * @param manager Transaction manager
 * @param txn Transaction context
 * @param module_id Module identifier
 * @return MVCC version or NULL if not found
 */
const mvcc_version_t* txn_get_readable_version(
    transaction_manager_t* manager,
    transaction_context_t* txn,
    uint32_t module_id
);

/*
 * Commit MVCC versions (make them visible to other transactions)
 * 
 * @param manager Transaction manager
 * @param txn Transaction context
 * @return 0 on success, -1 on failure
 */
int txn_commit_mvcc_versions(
    transaction_manager_t* manager,
    transaction_context_t* txn
);

/*
 * Cleanup old MVCC versions (garbage collection)
 * 
 * @param manager Transaction manager
 * @param before_timestamp Only cleanup versions older than this
 * @return Number of versions cleaned up
 */
uint32_t txn_cleanup_old_versions(
    transaction_manager_t* manager,
    uint64_t before_timestamp
);

// ============================================================================
// Distributed Transaction Support (2PC)
// ============================================================================

/*
 * Initialize distributed transaction coordinator
 * 
 * @param manager Transaction manager
 * @param participant_count Number of participants
 * @param phase1_timeout_ms Phase 1 timeout in milliseconds
 * @param phase2_timeout_ms Phase 2 timeout in milliseconds
 * @return 0 on success, -1 on failure
 */
int txn_init_distributed_coordinator(
    transaction_manager_t* manager,
    uint32_t participant_count,
    uint32_t phase1_timeout_ms,
    uint32_t phase2_timeout_ms
);

/*
 * Prepare phase of two-phase commit
 * 
 * @param manager Transaction manager
 * @param txn Transaction context
 * @return 0 if prepared, -1 on failure
 */
int txn_prepare_phase(transaction_manager_t* manager, transaction_context_t* txn);

/*
 * Commit phase of two-phase commit
 * 
 * @param manager Transaction manager
 * @param txn Transaction context
 * @return 0 on success, -1 on failure
 */
int txn_commit_phase(transaction_manager_t* manager, transaction_context_t* txn);

/*
 * Abort phase for failed two-phase commit
 * 
 * @param manager Transaction manager
 * @param txn Transaction context
 * @return 0 on success, -1 on failure
 */
int txn_abort_phase(transaction_manager_t* manager, transaction_context_t* txn);

// ============================================================================
// Rollback and Recovery
// ============================================================================

/*
 * Create a checkpoint for rollback purposes
 * 
 * @param txn Transaction context
 * @param checkpoint_name Name for the checkpoint
 * @return Checkpoint ID or 0 on failure
 */
uint64_t txn_create_checkpoint(transaction_context_t* txn, const char* checkpoint_name);

/*
 * Rollback to a specific checkpoint
 * 
 * @param manager Transaction manager
 * @param txn Transaction context
 * @param checkpoint_id Checkpoint to rollback to
 * @return 0 on success, -1 on failure
 */
int txn_rollback_to_checkpoint(
    transaction_manager_t* manager,
    transaction_context_t* txn,
    uint64_t checkpoint_id
);

/*
 * Perform automatic recovery after system failure
 * 
 * @param manager Transaction manager
 * @param recovery_log Recovery log data
 * @param log_size Size of recovery log
 * @return Number of transactions recovered, -1 on failure
 */
int txn_automatic_recovery(
    transaction_manager_t* manager,
    const void* recovery_log,
    size_t log_size
);

/*
 * Write transaction to write-ahead log (WAL)
 * 
 * @param manager Transaction manager
 * @param txn Transaction context
 * @param operation_type Type of operation being logged
 * @return 0 on success, -1 on failure
 */
int txn_write_ahead_log(
    transaction_manager_t* manager,
    transaction_context_t* txn,
    uint8_t operation_type
);

/*
 * Replay write-ahead log for recovery
 * 
 * @param manager Transaction manager
 * @param wal_data Write-ahead log data
 * @param wal_size Size of WAL data
 * @return Number of operations replayed, -1 on failure
 */
int txn_replay_wal(
    transaction_manager_t* manager,
    const void* wal_data,
    size_t wal_size
);

// ============================================================================
// Performance Monitoring and Analytics
// ============================================================================

/*
 * Get current performance metrics
 * 
 * @param manager Transaction manager
 * @return Performance metrics structure
 */
const txn_performance_metrics_t* txn_get_performance_metrics(
    const transaction_manager_t* manager
);

/*
 * Reset performance counters
 * 
 * @param manager Transaction manager
 * @return 0 on success, -1 on failure
 */
int txn_reset_performance_counters(transaction_manager_t* manager);

/*
 * Get transaction statistics for a specific time period
 * 
 * @param manager Transaction manager
 * @param start_time Start of time period
 * @param end_time End of time period
 * @param stats Output buffer for statistics
 * @return 0 on success, -1 on failure
 */
int txn_get_statistics(
    transaction_manager_t* manager,
    uint64_t start_time,
    uint64_t end_time,
    txn_performance_metrics_t* stats
);

/*
 * Enable/disable detailed transaction tracing
 * 
 * @param manager Transaction manager
 * @param enable Enable tracing if true
 * @param trace_level Level of detail for tracing
 * @return 0 on success, -1 on failure
 */
int txn_set_tracing(
    transaction_manager_t* manager,
    bool enable,
    uint8_t trace_level
);

// ============================================================================
// Utility Functions
// ============================================================================

/*
 * Get current global timestamp
 * 
 * @param manager Transaction manager
 * @return Current timestamp
 */
uint64_t txn_get_timestamp(transaction_manager_t* manager);

/*
 * Check if a transaction is deadlocked
 * 
 * @param manager Transaction manager
 * @param txn Transaction context
 * @return true if deadlocked, false otherwise
 */
bool txn_is_deadlocked(
    transaction_manager_t* manager,
    transaction_context_t* txn
);

/*
 * Detect and resolve deadlocks
 * 
 * @param manager Transaction manager
 * @return Number of deadlocks resolved
 */
uint32_t txn_resolve_deadlocks(transaction_manager_t* manager);

/*
 * Validate transaction integrity
 * 
 * @param txn Transaction context
 * @return true if valid, false if corrupted
 */
bool txn_validate_integrity(const transaction_context_t* txn);

/*
 * Calculate transaction priority based on age and resources
 * 
 * @param txn Transaction context
 * @return Priority score (higher = more priority)
 */
uint32_t txn_calculate_priority(const transaction_context_t* txn);

#ifdef __cplusplus
}
#endif

#endif // TRANSACTIONAL_RELOAD_H