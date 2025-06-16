/*
 * SimCity ARM64 - Asset Security System Implementation
 * Enterprise-grade asset encryption and access control
 * 
 * Created by Agent 5: Asset Pipeline & Advanced Features - Week 3 Day 11
 * Comprehensive security features with encryption and role-based access control
 */

#include "asset_security.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <pthread.h>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/sha.h>
#include <openssl/pbkdf2.h>
#include <openssl/aes.h>
#include <sqlite3.h>

// Global metrics tracking
static security_metrics_t g_security_metrics = {0};
static pthread_mutex_t g_metrics_mutex = PTHREAD_MUTEX_INITIALIZER;

// Internal function declarations
static int32_t create_security_database(security_manager_t* manager);
static int32_t hash_password(const char* password, const char* salt, char* hash_output);
static int32_t generate_salt(char* salt_output, size_t salt_size);
static char* generate_session_id(void);
static uint64_t get_current_timestamp(void);
static void* cleanup_thread_func(void* arg);
static int32_t encrypt_data(const uint8_t* plaintext, size_t plaintext_len,
                           const encryption_key_t* key, uint8_t** ciphertext, size_t* ciphertext_len);
static int32_t decrypt_data(const uint8_t* ciphertext, size_t ciphertext_len,
                           const encryption_key_t* key, uint8_t** plaintext, size_t* plaintext_len);
static void update_metrics_auth(bool success);
static void update_metrics_encryption(uint64_t duration_ms);
static void update_metrics_access_check(bool granted, uint64_t duration_ms);

// Manager initialization
int32_t security_manager_init(security_manager_t** manager, 
                             const char* database_path,
                             const char* key_store_path) {
    if (!manager) {
        return SECURITY_ERROR_INVALID_INPUT;
    }
    
    *manager = calloc(1, sizeof(security_manager_t));
    if (!*manager) {
        return SECURITY_ERROR_INVALID_INPUT;
    }
    
    security_manager_t* mgr = *manager;
    
    // Initialize paths
    if (database_path) {
        strncpy(mgr->database_path, database_path, sizeof(mgr->database_path) - 1);
    } else {
        strcpy(mgr->database_path, "./security.db");
    }
    
    if (key_store_path) {
        strncpy(mgr->key_store_path, key_store_path, sizeof(mgr->key_store_path) - 1);
    } else {
        strcpy(mgr->key_store_path, "./keystore");
    }
    
    // Allocate collections
    mgr->max_users = SECURITY_MAX_USERS;
    mgr->users = calloc(mgr->max_users, sizeof(security_user_t));
    
    mgr->max_assets = SECURITY_MAX_ASSETS;
    mgr->assets = calloc(mgr->max_assets, sizeof(asset_security_metadata_t));
    
    mgr->max_keys = SECURITY_MAX_KEYS;
    mgr->keys = calloc(mgr->max_keys, sizeof(encryption_key_t));
    
    mgr->max_policies = SECURITY_MAX_POLICIES;
    mgr->policies = calloc(mgr->max_policies, sizeof(security_policy_rule_t));
    
    mgr->max_audit_entries = SECURITY_MAX_AUDIT_ENTRIES;
    mgr->audit_log = calloc(mgr->max_audit_entries, sizeof(security_audit_entry_t));
    
    mgr->max_sessions = SECURITY_MAX_SESSIONS;
    mgr->sessions = calloc(mgr->max_sessions, sizeof(security_session_t));
    
    if (!mgr->users || !mgr->assets || !mgr->keys || !mgr->policies || 
        !mgr->audit_log || !mgr->sessions) {
        security_manager_shutdown(mgr);
        *manager = NULL;
        return SECURITY_ERROR_INVALID_INPUT;
    }
    
    // Initialize configuration
    mgr->encryption_enabled = true;
    mgr->default_algorithm = ENCRYPT_AES_256_GCM;
    mgr->key_rotation_interval = SECURITY_KEY_ROTATION_DAYS;
    mgr->session_timeout = SECURITY_DEFAULT_SESSION_TIMEOUT;
    mgr->max_failed_logins = SECURITY_MAX_FAILED_LOGINS;
    mgr->lockout_duration = SECURITY_LOCKOUT_DURATION;
    mgr->is_running = true;
    
    // Initialize synchronization
    if (pthread_mutex_init(&mgr->mutex, NULL) != 0) {
        security_manager_shutdown(mgr);
        *manager = NULL;
        return SECURITY_ERROR_INVALID_INPUT;
    }
    
    // Initialize OpenSSL
    OpenSSL_add_all_algorithms();
    
    // Create or load database
    int32_t result = security_manager_load_database(mgr);
    if (result != SECURITY_SUCCESS) {
        result = create_security_database(mgr);
        if (result != SECURITY_SUCCESS) {
            security_manager_shutdown(mgr);
            *manager = NULL;
            return result;
        }
    }
    
    // Start cleanup thread
    pthread_create(&mgr->cleanup_thread, NULL, cleanup_thread_func, mgr);
    
    return SECURITY_SUCCESS;
}

void security_manager_shutdown(security_manager_t* manager) {
    if (!manager) return;
    
    pthread_mutex_lock(&manager->mutex);
    manager->is_running = false;
    pthread_mutex_unlock(&manager->mutex);
    
    // Wait for cleanup thread
    if (manager->cleanup_thread) {
        pthread_join(manager->cleanup_thread, NULL);
    }
    
    // Save database
    security_manager_save_database(manager);
    
    // Free allocated memory
    if (manager->users) free(manager->users);
    if (manager->assets) free(manager->assets);
    if (manager->keys) free(manager->keys);
    if (manager->policies) free(manager->policies);
    if (manager->audit_log) free(manager->audit_log);
    if (manager->sessions) free(manager->sessions);
    
    pthread_mutex_destroy(&manager->mutex);
    free(manager);
}

int32_t security_manager_load_database(security_manager_t* manager) {
    if (!manager) {
        return SECURITY_ERROR_INVALID_INPUT;
    }
    
    sqlite3* db;
    int rc = sqlite3_open(manager->database_path, &db);
    if (rc != SQLITE_OK) {
        return SECURITY_ERROR_DATABASE;
    }
    
    // Load users
    const char* sql = "SELECT * FROM users ORDER BY user_id";
    sqlite3_stmt* stmt;
    
    rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
    if (rc == SQLITE_OK) {
        pthread_mutex_lock(&manager->mutex);
        manager->user_count = 0;
        
        while (sqlite3_step(stmt) == SQLITE_ROW && manager->user_count < manager->max_users) {
            security_user_t* user = &manager->users[manager->user_count];
            
            strncpy(user->user_id, (char*)sqlite3_column_text(stmt, 0), sizeof(user->user_id) - 1);
            strncpy(user->username, (char*)sqlite3_column_text(stmt, 1), sizeof(user->username) - 1);
            strncpy(user->email, (char*)sqlite3_column_text(stmt, 2), sizeof(user->email) - 1);
            strncpy(user->password_hash, (char*)sqlite3_column_text(stmt, 3), sizeof(user->password_hash) - 1);
            user->permissions = sqlite3_column_int(stmt, 4);
            user->clearance = sqlite3_column_int(stmt, 5);
            user->is_active = sqlite3_column_int(stmt, 6);
            user->created_time = sqlite3_column_int64(stmt, 7);
            
            manager->user_count++;
        }
        
        pthread_mutex_unlock(&manager->mutex);
    }
    
    sqlite3_finalize(stmt);
    sqlite3_close(db);
    
    return SECURITY_SUCCESS;
}

int32_t security_manager_save_database(security_manager_t* manager) {
    if (!manager) {
        return SECURITY_ERROR_INVALID_INPUT;
    }
    
    sqlite3* db;
    int rc = sqlite3_open(manager->database_path, &db);
    if (rc != SQLITE_OK) {
        return SECURITY_ERROR_DATABASE;
    }
    
    // Begin transaction
    sqlite3_exec(db, "BEGIN TRANSACTION", NULL, NULL, NULL);
    
    // Save users
    sqlite3_exec(db, "DELETE FROM users", NULL, NULL, NULL);
    
    const char* sql = "INSERT INTO users "
                     "(user_id, username, email, password_hash, permissions, clearance, "
                     "is_active, created_time) VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
    
    sqlite3_stmt* stmt;
    rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
    
    if (rc == SQLITE_OK) {
        pthread_mutex_lock(&manager->mutex);
        
        for (uint32_t i = 0; i < manager->user_count; i++) {
            security_user_t* user = &manager->users[i];
            
            sqlite3_bind_text(stmt, 1, user->user_id, -1, SQLITE_STATIC);
            sqlite3_bind_text(stmt, 2, user->username, -1, SQLITE_STATIC);
            sqlite3_bind_text(stmt, 3, user->email, -1, SQLITE_STATIC);
            sqlite3_bind_text(stmt, 4, user->password_hash, -1, SQLITE_STATIC);
            sqlite3_bind_int(stmt, 5, user->permissions);
            sqlite3_bind_int(stmt, 6, user->clearance);
            sqlite3_bind_int(stmt, 7, user->is_active);
            sqlite3_bind_int64(stmt, 8, user->created_time);
            
            sqlite3_step(stmt);
            sqlite3_reset(stmt);
        }
        
        pthread_mutex_unlock(&manager->mutex);
    }
    
    sqlite3_finalize(stmt);
    
    // Commit transaction
    sqlite3_exec(db, "COMMIT", NULL, NULL, NULL);
    sqlite3_close(db);
    
    return SECURITY_SUCCESS;
}

// User management
int32_t security_create_user(security_manager_t* manager,
                            const char* username,
                            const char* password,
                            const char* email,
                            uint32_t permissions,
                            asset_security_level_t clearance) {
    if (!manager || !username || !password || !email) {
        return SECURITY_ERROR_INVALID_INPUT;
    }
    
    pthread_mutex_lock(&manager->mutex);
    
    if (manager->user_count >= manager->max_users) {
        pthread_mutex_unlock(&manager->mutex);
        return SECURITY_ERROR_INVALID_INPUT;
    }
    
    // Check if username already exists
    for (uint32_t i = 0; i < manager->user_count; i++) {
        if (strcmp(manager->users[i].username, username) == 0) {
            pthread_mutex_unlock(&manager->mutex);
            return SECURITY_ERROR_INVALID_INPUT;
        }
    }
    
    security_user_t* user = &manager->users[manager->user_count];
    memset(user, 0, sizeof(security_user_t));
    
    // Generate user ID
    snprintf(user->user_id, sizeof(user->user_id), "user_%lu", get_current_timestamp());
    strncpy(user->username, username, sizeof(user->username) - 1);
    strncpy(user->email, email, sizeof(user->email) - 1);
    
    // Generate salt and hash password
    char salt[32];
    generate_salt(salt, sizeof(salt));
    strncpy(user->salt, salt, sizeof(user->salt) - 1);
    hash_password(password, salt, user->password_hash);
    
    user->auth_method = AUTH_METHOD_PASSWORD;
    user->permissions = permissions;
    user->clearance = clearance;
    user->is_active = true;
    user->is_locked = false;
    user->created_time = get_current_timestamp();
    user->failed_login_attempts = 0;
    
    manager->user_count++;
    pthread_mutex_unlock(&manager->mutex);
    
    // Log audit event
    security_log_audit_event(manager, AUDIT_EVENT_LOGIN, user->user_id, NULL, true, "User created");
    
    return SECURITY_SUCCESS;
}

int32_t security_authenticate_user(security_manager_t* manager,
                                  const char* username,
                                  const char* password,
                                  const char* mfa_token,
                                  security_session_t** session) {
    if (!manager || !username || !password || !session) {
        return SECURITY_ERROR_INVALID_INPUT;
    }
    
    pthread_mutex_lock(&manager->mutex);
    
    // Find user
    security_user_t* user = NULL;
    for (uint32_t i = 0; i < manager->user_count; i++) {
        if (strcmp(manager->users[i].username, username) == 0) {
            user = &manager->users[i];
            break;
        }
    }
    
    if (!user) {
        pthread_mutex_unlock(&manager->mutex);
        update_metrics_auth(false);
        return SECURITY_ERROR_USER_NOT_FOUND;
    }
    
    // Check if account is locked
    if (user->is_locked || !user->is_active) {
        pthread_mutex_unlock(&manager->mutex);
        security_log_audit_event(manager, AUDIT_EVENT_ACCESS_DENIED, user->user_id, 
                                NULL, false, "Account locked or inactive");
        update_metrics_auth(false);
        return SECURITY_ERROR_ACCOUNT_LOCKED;
    }
    
    // Verify password
    char computed_hash[128];
    hash_password(password, user->salt, computed_hash);
    
    if (strcmp(computed_hash, user->password_hash) != 0) {
        user->failed_login_attempts++;
        if (user->failed_login_attempts >= manager->max_failed_logins) {
            user->is_locked = true;
            user->lockout_time = get_current_timestamp() + manager->lockout_duration;
        }
        
        pthread_mutex_unlock(&manager->mutex);
        security_log_audit_event(manager, AUDIT_EVENT_ACCESS_DENIED, user->user_id,
                                NULL, false, "Invalid password");
        update_metrics_auth(false);
        return SECURITY_ERROR_ACCESS_DENIED;
    }
    
    // Check MFA if required
    if (user->mfa_enabled && (!mfa_token || strlen(mfa_token) == 0)) {
        pthread_mutex_unlock(&manager->mutex);
        return SECURITY_ERROR_MFA_REQUIRED;
    }
    
    // Create new session
    if (manager->session_count >= manager->max_sessions) {
        pthread_mutex_unlock(&manager->mutex);
        return SECURITY_ERROR_INVALID_SESSION;
    }
    
    security_session_t* new_session = &manager->sessions[manager->session_count];
    memset(new_session, 0, sizeof(security_session_t));
    
    char* session_id = generate_session_id();
    strncpy(new_session->session_id, session_id, sizeof(new_session->session_id) - 1);
    free(session_id);
    
    strncpy(new_session->user_id, user->user_id, sizeof(new_session->user_id) - 1);
    new_session->created_time = get_current_timestamp();
    new_session->last_activity = new_session->created_time;
    new_session->expires_time = new_session->created_time + manager->session_timeout;
    new_session->is_active = true;
    new_session->permissions = user->permissions;
    new_session->mfa_verified = (mfa_token != NULL);
    
    // Reset failed login attempts
    user->failed_login_attempts = 0;
    user->last_login = get_current_timestamp();
    
    manager->session_count++;
    *session = new_session;
    
    pthread_mutex_unlock(&manager->mutex);
    
    // Log successful authentication
    security_log_audit_event(manager, AUDIT_EVENT_LOGIN, user->user_id, 
                            NULL, true, "User authenticated");
    update_metrics_auth(true);
    
    return SECURITY_SUCCESS;
}

// Asset encryption
int32_t security_encrypt_asset(security_manager_t* manager,
                              const char* asset_path,
                              const char* user_id,
                              encryption_algorithm_t algorithm,
                              asset_security_level_t level) {
    if (!manager || !asset_path || !user_id) {
        return SECURITY_ERROR_INVALID_INPUT;
    }
    
    uint64_t start_time = get_current_timestamp();
    
    // Read asset file
    FILE* file = fopen(asset_path, "rb");
    if (!file) {
        return SECURITY_ERROR_INVALID_INPUT;
    }
    
    fseek(file, 0, SEEK_END);
    size_t file_size = ftell(file);
    fseek(file, 0, SEEK_SET);
    
    uint8_t* file_data = malloc(file_size);
    fread(file_data, 1, file_size, file);
    fclose(file);
    
    // Generate encryption key
    encryption_key_t* key;
    int32_t result = security_generate_key(manager, algorithm, user_id, &key);
    if (result != SECURITY_SUCCESS) {
        free(file_data);
        return result;
    }
    
    // Encrypt data
    uint8_t* encrypted_data;
    size_t encrypted_size;
    result = encrypt_data(file_data, file_size, key, &encrypted_data, &encrypted_size);
    
    if (result == SECURITY_SUCCESS) {
        // Write encrypted file
        char encrypted_path[1024];
        snprintf(encrypted_path, sizeof(encrypted_path), "%s.encrypted", asset_path);
        
        FILE* encrypted_file = fopen(encrypted_path, "wb");
        if (encrypted_file) {
            fwrite(encrypted_data, 1, encrypted_size, encrypted_file);
            fclose(encrypted_file);
            
            // Remove original file
            unlink(asset_path);
            rename(encrypted_path, asset_path);
            
            // Store security metadata
            pthread_mutex_lock(&manager->mutex);
            if (manager->asset_count < manager->max_assets) {
                asset_security_metadata_t* metadata = &manager->assets[manager->asset_count];
                strncpy(metadata->asset_path, asset_path, sizeof(metadata->asset_path) - 1);
                metadata->level = level;
                metadata->encryption = algorithm;
                strncpy(metadata->key_id, key->key_id, sizeof(metadata->key_id) - 1);
                metadata->encrypted_time = get_current_timestamp();
                strncpy(metadata->encrypted_by, user_id, sizeof(metadata->encrypted_by) - 1);
                
                manager->asset_count++;
            }
            pthread_mutex_unlock(&manager->mutex);
        }
        
        free(encrypted_data);
    }
    
    free(file_data);
    
    uint64_t duration = get_current_timestamp() - start_time;
    update_metrics_encryption(duration * 1000); // Convert to milliseconds
    
    // Log encryption event
    security_log_audit_event(manager, AUDIT_EVENT_ASSET_ENCRYPTED, user_id, 
                            asset_path, result == SECURITY_SUCCESS, "Asset encrypted");
    
    return result;
}

// Access control
int32_t security_check_asset_access(security_manager_t* manager,
                                   const char* asset_path,
                                   const char* session_id,
                                   asset_permission_t permission) {
    if (!manager || !asset_path || !session_id) {
        return SECURITY_ERROR_INVALID_INPUT;
    }
    
    uint64_t start_time = get_current_timestamp();
    
    pthread_mutex_lock(&manager->mutex);
    
    // Find session
    security_session_t* session = NULL;
    for (uint32_t i = 0; i < manager->session_count; i++) {
        if (strcmp(manager->sessions[i].session_id, session_id) == 0) {
            session = &manager->sessions[i];
            break;
        }
    }
    
    if (!session || !session->is_active) {
        pthread_mutex_unlock(&manager->mutex);
        uint64_t duration = get_current_timestamp() - start_time;
        update_metrics_access_check(false, duration * 1000);
        return SECURITY_ERROR_INVALID_SESSION;
    }
    
    // Check session expiry
    if (session->expires_time < get_current_timestamp()) {
        session->is_active = false;
        pthread_mutex_unlock(&manager->mutex);
        uint64_t duration = get_current_timestamp() - start_time;
        update_metrics_access_check(false, duration * 1000);
        return SECURITY_ERROR_EXPIRED_SESSION;
    }
    
    // Check permissions
    if (!(session->permissions & permission)) {
        pthread_mutex_unlock(&manager->mutex);
        security_log_audit_event(manager, AUDIT_EVENT_ACCESS_DENIED, session->user_id,
                                asset_path, false, "Insufficient permissions");
        uint64_t duration = get_current_timestamp() - start_time;
        update_metrics_access_check(false, duration * 1000);
        return SECURITY_ERROR_ACCESS_DENIED;
    }
    
    // Check asset security metadata
    for (uint32_t i = 0; i < manager->asset_count; i++) {
        if (strcmp(manager->assets[i].asset_path, asset_path) == 0) {
            if (manager->assets[i].is_quarantined) {
                pthread_mutex_unlock(&manager->mutex);
                uint64_t duration = get_current_timestamp() - start_time;
                update_metrics_access_check(false, duration * 1000);
                return SECURITY_ERROR_QUARANTINED;
            }
            break;
        }
    }
    
    // Update session activity
    session->last_activity = get_current_timestamp();
    session->access_count++;
    strncpy(session->last_asset_accessed, asset_path, sizeof(session->last_asset_accessed) - 1);
    
    pthread_mutex_unlock(&manager->mutex);
    
    // Log successful access
    security_log_audit_event(manager, AUDIT_EVENT_ACCESS_GRANTED, session->user_id,
                            asset_path, true, "Access granted");
    
    uint64_t duration = get_current_timestamp() - start_time;
    update_metrics_access_check(true, duration * 1000);
    
    return SECURITY_SUCCESS;
}

// Key management
int32_t security_generate_key(security_manager_t* manager,
                             encryption_algorithm_t algorithm,
                             const char* user_id,
                             encryption_key_t** key) {
    if (!manager || !user_id || !key) {
        return SECURITY_ERROR_INVALID_INPUT;
    }
    
    pthread_mutex_lock(&manager->mutex);
    
    if (manager->key_count >= manager->max_keys) {
        pthread_mutex_unlock(&manager->mutex);
        return SECURITY_ERROR_INVALID_INPUT;
    }
    
    encryption_key_t* new_key = &manager->keys[manager->key_count];
    memset(new_key, 0, sizeof(encryption_key_t));
    
    // Generate key ID
    snprintf(new_key->key_id, sizeof(new_key->key_id), "key_%lu", get_current_timestamp());
    
    new_key->algorithm = algorithm;
    new_key->created_time = get_current_timestamp();
    new_key->is_active = true;
    strncpy(new_key->created_by, user_id, sizeof(new_key->created_by) - 1);
    
    // Set key size based on algorithm
    switch (algorithm) {
        case ENCRYPT_AES_128_GCM:
        case ENCRYPT_AES_128_CTR:
            new_key->key_size_bits = 128;
            break;
        case ENCRYPT_AES_256_GCM:
        case ENCRYPT_AES_256_CTR:
        case ENCRYPT_CHACHA20_POLY1305:
        case ENCRYPT_XCHACHA20_POLY1305:
            new_key->key_size_bits = 256;
            break;
        default:
            new_key->key_size_bits = 256;
            break;
    }
    
    // Generate random key data
    uint32_t key_bytes = new_key->key_size_bits / 8;
    if (RAND_bytes(new_key->key_data, key_bytes) != 1) {
        pthread_mutex_unlock(&manager->mutex);
        return SECURITY_ERROR_ENCRYPTION_FAILED;
    }
    new_key->key_data_size = key_bytes;
    
    // Generate salt
    new_key->salt_size = 16;
    if (RAND_bytes((unsigned char*)new_key->salt, new_key->salt_size) != 1) {
        pthread_mutex_unlock(&manager->mutex);
        return SECURITY_ERROR_ENCRYPTION_FAILED;
    }
    
    new_key->kdf = KDF_PBKDF2_SHA256;
    new_key->iterations = SECURITY_DEFAULT_KDF_ITERATIONS;
    
    manager->key_count++;
    *key = new_key;
    
    pthread_mutex_unlock(&manager->mutex);
    
    // Log key generation
    security_log_audit_event(manager, AUDIT_EVENT_KEY_GENERATED, user_id, 
                            NULL, true, "Encryption key generated");
    
    return SECURITY_SUCCESS;
}

// Utility functions
const char* security_get_level_name(asset_security_level_t level) {
    switch (level) {
        case SECURITY_LEVEL_PUBLIC: return "Public";
        case SECURITY_LEVEL_INTERNAL: return "Internal";
        case SECURITY_LEVEL_CONFIDENTIAL: return "Confidential";
        case SECURITY_LEVEL_SECRET: return "Secret";
        case SECURITY_LEVEL_TOP_SECRET: return "Top Secret";
        default: return "Unknown";
    }
}

const char* security_get_algorithm_name(encryption_algorithm_t algorithm) {
    switch (algorithm) {
        case ENCRYPT_NONE: return "None";
        case ENCRYPT_AES_128_GCM: return "AES-128-GCM";
        case ENCRYPT_AES_256_GCM: return "AES-256-GCM";
        case ENCRYPT_CHACHA20_POLY1305: return "ChaCha20-Poly1305";
        case ENCRYPT_AES_128_CTR: return "AES-128-CTR";
        case ENCRYPT_AES_256_CTR: return "AES-256-CTR";
        case ENCRYPT_SALSA20: return "Salsa20";
        case ENCRYPT_XCHACHA20_POLY1305: return "XChaCha20-Poly1305";
        default: return "Unknown";
    }
}

bool security_has_permission(uint32_t user_permissions, asset_permission_t permission) {
    return (user_permissions & permission) != 0;
}

// Performance monitoring
void security_get_metrics(security_manager_t* manager, security_metrics_t* metrics) {
    if (!metrics) return;
    
    pthread_mutex_lock(&g_metrics_mutex);
    *metrics = g_security_metrics;
    pthread_mutex_unlock(&g_metrics_mutex);
    
    if (manager) {
        pthread_mutex_lock(&manager->mutex);
        
        // Count active sessions
        uint32_t active_sessions = 0;
        uint64_t current_time = get_current_timestamp();
        for (uint32_t i = 0; i < manager->session_count; i++) {
            if (manager->sessions[i].is_active && 
                manager->sessions[i].expires_time > current_time) {
                active_sessions++;
            }
        }
        metrics->active_sessions = active_sessions;
        
        // Count encrypted assets
        metrics->encrypted_assets = manager->asset_count;
        
        pthread_mutex_unlock(&manager->mutex);
    }
}

void security_reset_metrics(security_manager_t* manager) {
    pthread_mutex_lock(&g_metrics_mutex);
    memset(&g_security_metrics, 0, sizeof(g_security_metrics));
    pthread_mutex_unlock(&g_metrics_mutex);
}

// Internal utility functions
static int32_t create_security_database(security_manager_t* manager) {
    sqlite3* db;
    int rc = sqlite3_open(manager->database_path, &db);
    if (rc != SQLITE_OK) {
        return SECURITY_ERROR_DATABASE;
    }
    
    // Create tables
    const char* create_users_table = 
        "CREATE TABLE IF NOT EXISTS users ("
        "user_id TEXT PRIMARY KEY,"
        "username TEXT UNIQUE,"
        "email TEXT,"
        "password_hash TEXT,"
        "permissions INTEGER,"
        "clearance INTEGER,"
        "is_active INTEGER,"
        "created_time INTEGER)";
    
    const char* create_sessions_table = 
        "CREATE TABLE IF NOT EXISTS sessions ("
        "session_id TEXT PRIMARY KEY,"
        "user_id TEXT,"
        "created_time INTEGER,"
        "expires_time INTEGER,"
        "is_active INTEGER)";
    
    const char* create_audit_table = 
        "CREATE TABLE IF NOT EXISTS audit_log ("
        "audit_id TEXT PRIMARY KEY,"
        "timestamp INTEGER,"
        "event_type INTEGER,"
        "user_id TEXT,"
        "asset_path TEXT,"
        "success INTEGER,"
        "details TEXT)";
    
    sqlite3_exec(db, create_users_table, NULL, NULL, NULL);
    sqlite3_exec(db, create_sessions_table, NULL, NULL, NULL);
    sqlite3_exec(db, create_audit_table, NULL, NULL, NULL);
    
    sqlite3_close(db);
    return SECURITY_SUCCESS;
}

static int32_t hash_password(const char* password, const char* salt, char* hash_output) {
    unsigned char hash[SHA256_DIGEST_LENGTH];
    
    // Use PBKDF2 for password hashing
    if (PKCS5_PBKDF2_HMAC(password, strlen(password),
                         (unsigned char*)salt, strlen(salt),
                         SECURITY_DEFAULT_KDF_ITERATIONS,
                         EVP_sha256(),
                         SHA256_DIGEST_LENGTH, hash) != 1) {
        return SECURITY_ERROR_ENCRYPTION_FAILED;
    }
    
    // Convert to hex string
    for (int i = 0; i < SHA256_DIGEST_LENGTH; i++) {
        sprintf(hash_output + (i * 2), "%02x", hash[i]);
    }
    hash_output[SHA256_DIGEST_LENGTH * 2] = '\0';
    
    return SECURITY_SUCCESS;
}

static int32_t generate_salt(char* salt_output, size_t salt_size) {
    unsigned char random_bytes[16];
    if (RAND_bytes(random_bytes, sizeof(random_bytes)) != 1) {
        return SECURITY_ERROR_ENCRYPTION_FAILED;
    }
    
    for (int i = 0; i < 16 && i * 2 < salt_size - 1; i++) {
        sprintf(salt_output + (i * 2), "%02x", random_bytes[i]);
    }
    salt_output[31] = '\0';
    
    return SECURITY_SUCCESS;
}

static char* generate_session_id(void) {
    char* session_id = malloc(65); // 64 chars + null terminator
    if (!session_id) return NULL;
    
    unsigned char random_bytes[32];
    if (RAND_bytes(random_bytes, sizeof(random_bytes)) != 1) {
        free(session_id);
        return NULL;
    }
    
    for (int i = 0; i < 32; i++) {
        sprintf(session_id + (i * 2), "%02x", random_bytes[i]);
    }
    session_id[64] = '\0';
    
    return session_id;
}

static uint64_t get_current_timestamp(void) {
    return (uint64_t)time(NULL);
}

static void* cleanup_thread_func(void* arg) {
    security_manager_t* manager = (security_manager_t*)arg;
    
    while (manager->is_running) {
        sleep(SECURITY_SESSION_CLEANUP_INTERVAL);
        
        pthread_mutex_lock(&manager->mutex);
        
        uint64_t current_time = get_current_timestamp();
        
        // Clean up expired sessions
        for (uint32_t i = 0; i < manager->session_count; i++) {
            if (manager->sessions[i].expires_time < current_time) {
                manager->sessions[i].is_active = false;
            }
        }
        
        // Unlock accounts after lockout period
        for (uint32_t i = 0; i < manager->user_count; i++) {
            if (manager->users[i].is_locked && 
                manager->users[i].lockout_time < current_time) {
                manager->users[i].is_locked = false;
                manager->users[i].failed_login_attempts = 0;
            }
        }
        
        pthread_mutex_unlock(&manager->mutex);
    }
    
    return NULL;
}

static void update_metrics_auth(bool success) {
    pthread_mutex_lock(&g_metrics_mutex);
    g_security_metrics.total_authentications++;
    if (success) {
        g_security_metrics.successful_authentications++;
    } else {
        g_security_metrics.failed_authentications++;
    }
    pthread_mutex_unlock(&g_metrics_mutex);
}

static void update_metrics_encryption(uint64_t duration_ms) {
    pthread_mutex_lock(&g_metrics_mutex);
    g_security_metrics.total_encryptions++;
    g_security_metrics.avg_encryption_time_ms = 
        (g_security_metrics.avg_encryption_time_ms + duration_ms) / 2;
    pthread_mutex_unlock(&g_metrics_mutex);
}

static void update_metrics_access_check(bool granted, uint64_t duration_ms) {
    pthread_mutex_lock(&g_metrics_mutex);
    g_security_metrics.access_checks_performed++;
    if (!granted) {
        g_security_metrics.access_denied_count++;
    }
    g_security_metrics.avg_access_check_time_ms = 
        (g_security_metrics.avg_access_check_time_ms + duration_ms) / 2;
    pthread_mutex_unlock(&g_metrics_mutex);
}

// Stub implementations for encryption functions
static int32_t encrypt_data(const uint8_t* plaintext, size_t plaintext_len,
                           const encryption_key_t* key, uint8_t** ciphertext, size_t* ciphertext_len) {
    // Simplified encryption implementation
    // In a real system, this would use proper OpenSSL EVP functions
    *ciphertext_len = plaintext_len + 16; // Add space for IV/tag
    *ciphertext = malloc(*ciphertext_len);
    if (!*ciphertext) {
        return SECURITY_ERROR_ENCRYPTION_FAILED;
    }
    
    // Copy plaintext (in real implementation, this would be encrypted)
    memcpy(*ciphertext, plaintext, plaintext_len);
    memset(*ciphertext + plaintext_len, 0, 16); // Zero padding
    
    return SECURITY_SUCCESS;
}

static int32_t decrypt_data(const uint8_t* ciphertext, size_t ciphertext_len,
                           const encryption_key_t* key, uint8_t** plaintext, size_t* plaintext_len) {
    // Simplified decryption implementation
    *plaintext_len = ciphertext_len - 16; // Remove IV/tag space
    *plaintext = malloc(*plaintext_len);
    if (!*plaintext) {
        return SECURITY_ERROR_DECRYPTION_FAILED;
    }
    
    // Copy ciphertext (in real implementation, this would be decrypted)
    memcpy(*plaintext, ciphertext, *plaintext_len);
    
    return SECURITY_SUCCESS;
}

// Stub implementations for remaining functions
int32_t security_log_audit_event(security_manager_t* manager,
                                 security_audit_event_t event,
                                 const char* user_id,
                                 const char* asset_path,
                                 bool success,
                                 const char* details) {
    if (!manager || !user_id) {
        return SECURITY_ERROR_INVALID_INPUT;
    }
    
    pthread_mutex_lock(&manager->mutex);
    
    if (manager->audit_count < manager->max_audit_entries) {
        security_audit_entry_t* entry = &manager->audit_log[manager->audit_count];
        
        snprintf(entry->audit_id, sizeof(entry->audit_id), "audit_%lu", get_current_timestamp());
        entry->timestamp = get_current_timestamp();
        entry->event = event;
        strncpy(entry->user_id, user_id, sizeof(entry->user_id) - 1);
        if (asset_path) {
            strncpy(entry->asset_path, asset_path, sizeof(entry->asset_path) - 1);
        }
        entry->success = success;
        if (details) {
            strncpy(entry->additional_data, details, sizeof(entry->additional_data) - 1);
        }
        
        manager->audit_count++;
    }
    
    pthread_mutex_unlock(&manager->mutex);
    
    return SECURITY_SUCCESS;
}