// SimCity ARM64 Secure Networking Layer
// Agent 5: Infrastructure & Networking
// TLS encryption and actor-model reliability for multi-agent communication

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/x509.h>
#include <openssl/pem.h>
#include <sys/epoll.h>
#include <sys/time.h>
#include <fcntl.h>
#include <errno.h>

// Actor model constants
#define MAX_ACTORS 1024
#define MAX_MESSAGES_PER_ACTOR 256
#define MESSAGE_QUEUE_SIZE 8192
#define ACTOR_THREAD_POOL_SIZE 8
#define TLS_CERTIFICATE_PATH "certs/server.crt"
#define TLS_PRIVATE_KEY_PATH "certs/server.key"
#define MAX_CONNECTIONS 512
#define EPOLL_MAX_EVENTS 64

// Message types for actor communication
typedef enum {
    MSG_TYPE_TASK_ASSIGNMENT = 1,
    MSG_TYPE_HEARTBEAT = 2,
    MSG_TYPE_RESOURCE_REQUEST = 3,
    MSG_TYPE_INTEGRATION_REQUEST = 4,
    MSG_TYPE_ERROR_REPORT = 5,
    MSG_TYPE_SHUTDOWN = 6
} MessageType;

// Actor message structure
typedef struct {
    uint32_t id;
    uint32_t sender_id;
    uint32_t recipient_id;
    MessageType type;
    uint32_t size;
    uint64_t timestamp;
    uint8_t data[512];
    uint8_t checksum[32]; // SHA-256 for integrity
} ActorMessage;

// Actor state
typedef enum {
    ACTOR_STATE_IDLE = 0,
    ACTOR_STATE_RUNNING = 1,
    ACTOR_STATE_BLOCKED = 2,
    ACTOR_STATE_ERROR = 3,
    ACTOR_STATE_SHUTDOWN = 4
} ActorState;

// Actor context
typedef struct {
    uint32_t id;
    ActorState state;
    pthread_t thread;
    pthread_mutex_t message_queue_mutex;
    pthread_cond_t message_available;
    ActorMessage message_queue[MAX_MESSAGES_PER_ACTOR];
    uint32_t queue_head;
    uint32_t queue_tail;
    uint32_t queue_count;
    
    // Performance metrics
    uint64_t messages_processed;
    uint64_t messages_sent;
    uint64_t last_heartbeat;
    uint32_t error_count;
    
    // Actor-specific handler
    void (*message_handler)(struct ActorContext* actor, ActorMessage* msg);
    void* user_data;
} ActorContext;

// TLS connection context
typedef struct {
    int socket_fd;
    SSL* ssl;
    SSL_CTX* ssl_ctx;
    struct sockaddr_in client_addr;
    uint32_t actor_id;
    uint64_t last_activity;
    uint32_t message_count;
    uint8_t connection_secure;
} TLSConnection;

// Network server context
typedef struct {
    int server_fd;
    SSL_CTX* ssl_ctx;
    int epoll_fd;
    pthread_t server_thread;
    pthread_mutex_t connections_mutex;
    TLSConnection connections[MAX_CONNECTIONS];
    uint32_t active_connections;
    uint8_t server_running;
} NetworkServer;

// Global actor system state
static struct {
    ActorContext actors[MAX_ACTORS];
    uint32_t active_actors;
    pthread_mutex_t system_mutex;
    pthread_t thread_pool[ACTOR_THREAD_POOL_SIZE];
    NetworkServer network_server;
    uint8_t system_initialized;
} g_actor_system = {0};

// Forward declarations
static void* actor_thread_worker(void* arg);
static void* network_server_thread(void* arg);
static int setup_tls_context(SSL_CTX** ctx);
static int handle_new_connection(NetworkServer* server);
static int handle_client_message(TLSConnection* conn);
static void actor_default_message_handler(ActorContext* actor, ActorMessage* msg);
static uint32_t calculate_message_checksum(ActorMessage* msg);
static int verify_message_integrity(ActorMessage* msg);

//==============================================================================
// TLS SETUP AND CERTIFICATE MANAGEMENT
//==============================================================================

static int setup_tls_context(SSL_CTX** ctx) {
    const SSL_METHOD* method;
    
    // Initialize OpenSSL
    SSL_load_error_strings();
    OpenSSL_add_ssl_algorithms();
    
    // Create SSL context
    method = TLS_server_method();
    *ctx = SSL_CTX_new(method);
    if (!*ctx) {
        printf("Failed to create SSL context\n");
        ERR_print_errors_fp(stderr);
        return -1;
    }
    
    // Set minimum TLS version to 1.2
    SSL_CTX_set_min_proto_version(*ctx, TLS1_2_VERSION);
    
    // Load server certificate
    if (SSL_CTX_use_certificate_file(*ctx, TLS_CERTIFICATE_PATH, SSL_FILETYPE_PEM) <= 0) {
        printf("Failed to load server certificate from %s\n", TLS_CERTIFICATE_PATH);
        ERR_print_errors_fp(stderr);
        SSL_CTX_free(*ctx);
        return -1;
    }
    
    // Load private key
    if (SSL_CTX_use_PrivateKey_file(*ctx, TLS_PRIVATE_KEY_PATH, SSL_FILETYPE_PEM) <= 0) {
        printf("Failed to load private key from %s\n", TLS_PRIVATE_KEY_PATH);
        ERR_print_errors_fp(stderr);
        SSL_CTX_free(*ctx);
        return -1;
    }
    
    // Verify private key matches certificate
    if (!SSL_CTX_check_private_key(*ctx)) {
        printf("Private key does not match certificate\n");
        SSL_CTX_free(*ctx);
        return -1;
    }
    
    // Set cipher preferences (strong ciphers only)
    const char* cipher_list = "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-SHA384";
    if (!SSL_CTX_set_cipher_list(*ctx, cipher_list)) {
        printf("Failed to set cipher list\n");
        SSL_CTX_free(*ctx);
        return -1;
    }
    
    // Enable certificate verification
    SSL_CTX_set_verify(*ctx, SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT, NULL);
    
    printf("TLS context initialized successfully\n");
    return 0;
}

//==============================================================================
// ACTOR SYSTEM IMPLEMENTATION
//==============================================================================

int actor_system_init(void) {
    if (g_actor_system.system_initialized) {
        return 0; // Already initialized
    }
    
    // Initialize system mutex
    if (pthread_mutex_init(&g_actor_system.system_mutex, NULL) != 0) {
        printf("Failed to initialize system mutex\n");
        return -1;
    }
    
    // Initialize all actors
    for (int i = 0; i < MAX_ACTORS; i++) {
        ActorContext* actor = &g_actor_system.actors[i];
        actor->id = i;
        actor->state = ACTOR_STATE_IDLE;
        actor->queue_head = 0;
        actor->queue_tail = 0;
        actor->queue_count = 0;
        actor->messages_processed = 0;
        actor->messages_sent = 0;
        actor->error_count = 0;
        actor->message_handler = actor_default_message_handler;
        actor->user_data = NULL;
        
        if (pthread_mutex_init(&actor->message_queue_mutex, NULL) != 0) {
            printf("Failed to initialize actor %d mutex\n", i);
            return -1;
        }
        
        if (pthread_cond_init(&actor->message_available, NULL) != 0) {
            printf("Failed to initialize actor %d condition variable\n", i);
            return -1;
        }
    }
    
    // Start actor thread pool
    for (int i = 0; i < ACTOR_THREAD_POOL_SIZE; i++) {
        if (pthread_create(&g_actor_system.thread_pool[i], NULL, actor_thread_worker, &i) != 0) {
            printf("Failed to create actor thread %d\n", i);
            return -1;
        }
    }
    
    // Initialize network server
    memset(&g_actor_system.network_server, 0, sizeof(NetworkServer));
    if (pthread_mutex_init(&g_actor_system.network_server.connections_mutex, NULL) != 0) {
        printf("Failed to initialize network server mutex\n");
        return -1;
    }
    
    // Setup TLS context
    if (setup_tls_context(&g_actor_system.network_server.ssl_ctx) != 0) {
        printf("Failed to setup TLS context\n");
        return -1;
    }
    
    g_actor_system.system_initialized = 1;
    printf("Actor system initialized with %d actors and %d threads\n", 
           MAX_ACTORS, ACTOR_THREAD_POOL_SIZE);
    
    return 0;
}

static void* actor_thread_worker(void* arg) {
    int thread_id = *(int*)arg;
    printf("Actor thread %d started\n", thread_id);
    
    while (g_actor_system.system_initialized) {
        // Round-robin through actors
        for (int i = 0; i < MAX_ACTORS; i++) {
            ActorContext* actor = &g_actor_system.actors[i];
            
            pthread_mutex_lock(&actor->message_queue_mutex);
            
            // Check if actor has messages to process
            if (actor->queue_count > 0 && actor->state == ACTOR_STATE_RUNNING) {
                ActorMessage msg = actor->message_queue[actor->queue_head];
                actor->queue_head = (actor->queue_head + 1) % MAX_MESSAGES_PER_ACTOR;
                actor->queue_count--;
                
                pthread_mutex_unlock(&actor->message_queue_mutex);
                
                // Verify message integrity
                if (verify_message_integrity(&msg) == 0) {
                    // Process message
                    actor->message_handler(actor, &msg);
                    actor->messages_processed++;
                } else {
                    printf("Actor %d: Message integrity check failed\n", actor->id);
                    actor->error_count++;
                }
            } else {
                pthread_mutex_unlock(&actor->message_queue_mutex);
            }
        }
        
        // Small sleep to prevent busy waiting
        usleep(1000); // 1ms
    }
    
    printf("Actor thread %d shutting down\n", thread_id);
    return NULL;
}

int actor_create(uint32_t* actor_id, void (*message_handler)(ActorContext*, ActorMessage*), void* user_data) {
    pthread_mutex_lock(&g_actor_system.system_mutex);
    
    // Find available actor slot
    for (int i = 0; i < MAX_ACTORS; i++) {
        ActorContext* actor = &g_actor_system.actors[i];
        if (actor->state == ACTOR_STATE_IDLE) {
            actor->state = ACTOR_STATE_RUNNING;
            actor->message_handler = message_handler ? message_handler : actor_default_message_handler;
            actor->user_data = user_data;
            actor->last_heartbeat = time(NULL) * 1000; // Current time in ms
            
            *actor_id = i;
            g_actor_system.active_actors++;
            
            pthread_mutex_unlock(&g_actor_system.system_mutex);
            printf("Created actor %d\n", i);
            return 0;
        }
    }
    
    pthread_mutex_unlock(&g_actor_system.system_mutex);
    printf("Failed to create actor: no available slots\n");
    return -1;
}

int actor_send_message(uint32_t sender_id, uint32_t recipient_id, MessageType type, const void* data, uint32_t size) {
    if (recipient_id >= MAX_ACTORS || size > sizeof(((ActorMessage*)0)->data)) {
        return -1;
    }
    
    ActorContext* recipient = &g_actor_system.actors[recipient_id];
    
    pthread_mutex_lock(&recipient->message_queue_mutex);
    
    if (recipient->queue_count >= MAX_MESSAGES_PER_ACTOR) {
        pthread_mutex_unlock(&recipient->message_queue_mutex);
        printf("Actor %d message queue full\n", recipient_id);
        return -1;
    }
    
    // Create message
    ActorMessage* msg = &recipient->message_queue[recipient->queue_tail];
    msg->id = recipient->messages_processed + recipient->queue_count;
    msg->sender_id = sender_id;
    msg->recipient_id = recipient_id;
    msg->type = type;
    msg->size = size;
    msg->timestamp = time(NULL) * 1000;
    
    if (data && size > 0) {
        memcpy(msg->data, data, size);
    }
    
    // Calculate and store checksum
    calculate_message_checksum(msg);
    
    recipient->queue_tail = (recipient->queue_tail + 1) % MAX_MESSAGES_PER_ACTOR;
    recipient->queue_count++;
    
    pthread_cond_signal(&recipient->message_available);
    pthread_mutex_unlock(&recipient->message_queue_mutex);
    
    // Update sender stats
    if (sender_id < MAX_ACTORS) {
        g_actor_system.actors[sender_id].messages_sent++;
    }
    
    return 0;
}

static void actor_default_message_handler(ActorContext* actor, ActorMessage* msg) {
    switch (msg->type) {
        case MSG_TYPE_HEARTBEAT:
            actor->last_heartbeat = msg->timestamp;
            printf("Actor %d: Heartbeat received\n", actor->id);
            break;
            
        case MSG_TYPE_TASK_ASSIGNMENT:
            printf("Actor %d: Task assignment received from actor %d\n", 
                   actor->id, msg->sender_id);
            break;
            
        case MSG_TYPE_SHUTDOWN:
            printf("Actor %d: Shutdown message received\n", actor->id);
            actor->state = ACTOR_STATE_SHUTDOWN;
            break;
            
        default:
            printf("Actor %d: Unknown message type %d\n", actor->id, msg->type);
            break;
    }
}

static uint32_t calculate_message_checksum(ActorMessage* msg) {
    // Simple checksum for demo - in production, use SHA-256
    uint32_t checksum = 0;
    uint8_t* data = (uint8_t*)msg;
    size_t len = sizeof(ActorMessage) - sizeof(msg->checksum);
    
    for (size_t i = 0; i < len; i++) {
        checksum += data[i];
    }
    
    // Store in first 4 bytes of checksum field
    memcpy(msg->checksum, &checksum, sizeof(checksum));
    return checksum;
}

static int verify_message_integrity(ActorMessage* msg) {
    uint32_t stored_checksum;
    memcpy(&stored_checksum, msg->checksum, sizeof(stored_checksum));
    
    // Clear checksum field and recalculate
    memset(msg->checksum, 0, sizeof(msg->checksum));
    uint32_t calculated_checksum = calculate_message_checksum(msg);
    
    return (stored_checksum == calculated_checksum) ? 0 : -1;
}

//==============================================================================
// NETWORK SERVER IMPLEMENTATION
//==============================================================================

int network_server_start(uint16_t port) {
    NetworkServer* server = &g_actor_system.network_server;
    
    // Create server socket
    server->server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server->server_fd < 0) {
        perror("socket creation failed");
        return -1;
    }
    
    // Set socket options
    int opt = 1;
    if (setsockopt(server->server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
        perror("setsockopt failed");
        close(server->server_fd);
        return -1;
    }
    
    // Set non-blocking
    int flags = fcntl(server->server_fd, F_GETFL, 0);
    fcntl(server->server_fd, F_SETFL, flags | O_NONBLOCK);
    
    // Bind socket
    struct sockaddr_in server_addr;
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(port);
    
    if (bind(server->server_fd, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        perror("bind failed");
        close(server->server_fd);
        return -1;
    }
    
    // Listen for connections
    if (listen(server->server_fd, 128) < 0) {
        perror("listen failed");
        close(server->server_fd);
        return -1;
    }
    
    // Create epoll instance
    server->epoll_fd = epoll_create1(0);
    if (server->epoll_fd < 0) {
        perror("epoll_create1 failed");
        close(server->server_fd);
        return -1;
    }
    
    // Add server socket to epoll
    struct epoll_event event;
    event.events = EPOLLIN;
    event.data.fd = server->server_fd;
    if (epoll_ctl(server->epoll_fd, EPOLL_CTL_ADD, server->server_fd, &event) < 0) {
        perror("epoll_ctl failed");
        close(server->epoll_fd);
        close(server->server_fd);
        return -1;
    }
    
    server->server_running = 1;
    
    // Start server thread
    if (pthread_create(&server->server_thread, NULL, network_server_thread, server) != 0) {
        printf("Failed to create server thread\n");
        server->server_running = 0;
        close(server->epoll_fd);
        close(server->server_fd);
        return -1;
    }
    
    printf("Secure network server started on port %d\n", port);
    return 0;
}

static void* network_server_thread(void* arg) {
    NetworkServer* server = (NetworkServer*)arg;
    struct epoll_event events[EPOLL_MAX_EVENTS];
    
    printf("Network server thread started\n");
    
    while (server->server_running) {
        int event_count = epoll_wait(server->epoll_fd, events, EPOLL_MAX_EVENTS, 1000);
        
        for (int i = 0; i < event_count; i++) {
            if (events[i].data.fd == server->server_fd) {
                // New connection
                handle_new_connection(server);
            } else {
                // Existing connection data
                TLSConnection* conn = (TLSConnection*)events[i].data.ptr;
                if (handle_client_message(conn) < 0) {
                    // Connection error, cleanup
                    SSL_shutdown(conn->ssl);
                    SSL_free(conn->ssl);
                    close(conn->socket_fd);
                    memset(conn, 0, sizeof(TLSConnection));
                    
                    pthread_mutex_lock(&server->connections_mutex);
                    server->active_connections--;
                    pthread_mutex_unlock(&server->connections_mutex);
                }
            }
        }
    }
    
    printf("Network server thread shutting down\n");
    return NULL;
}

static int handle_new_connection(NetworkServer* server) {
    struct sockaddr_in client_addr;
    socklen_t client_len = sizeof(client_addr);
    
    int client_fd = accept(server->server_fd, (struct sockaddr*)&client_addr, &client_len);
    if (client_fd < 0) {
        if (errno != EAGAIN && errno != EWOULDBLOCK) {
            perror("accept failed");
        }
        return -1;
    }
    
    // Set non-blocking
    int flags = fcntl(client_fd, F_GETFL, 0);
    fcntl(client_fd, F_SETFL, flags | O_NONBLOCK);
    
    pthread_mutex_lock(&server->connections_mutex);
    
    if (server->active_connections >= MAX_CONNECTIONS) {
        pthread_mutex_unlock(&server->connections_mutex);
        printf("Max connections reached, rejecting new connection\n");
        close(client_fd);
        return -1;
    }
    
    // Find available connection slot
    TLSConnection* conn = NULL;
    for (int i = 0; i < MAX_CONNECTIONS; i++) {
        if (server->connections[i].socket_fd == 0) {
            conn = &server->connections[i];
            break;
        }
    }
    
    if (!conn) {
        pthread_mutex_unlock(&server->connections_mutex);
        printf("No available connection slots\n");
        close(client_fd);
        return -1;
    }
    
    // Initialize connection
    conn->socket_fd = client_fd;
    conn->client_addr = client_addr;
    conn->last_activity = time(NULL);
    conn->message_count = 0;
    conn->connection_secure = 0;
    
    // Create SSL structure
    conn->ssl = SSL_new(server->ssl_ctx);
    if (!conn->ssl) {
        pthread_mutex_unlock(&server->connections_mutex);
        printf("Failed to create SSL structure\n");
        close(client_fd);
        return -1;
    }
    
    SSL_set_fd(conn->ssl, client_fd);
    
    // Perform TLS handshake
    int ssl_result = SSL_accept(conn->ssl);
    if (ssl_result <= 0) {
        int ssl_error = SSL_get_error(conn->ssl, ssl_result);
        if (ssl_error != SSL_ERROR_WANT_READ && ssl_error != SSL_ERROR_WANT_WRITE) {
            printf("TLS handshake failed: %d\n", ssl_error);
            ERR_print_errors_fp(stderr);
            SSL_free(conn->ssl);
            close(client_fd);
            memset(conn, 0, sizeof(TLSConnection));
            pthread_mutex_unlock(&server->connections_mutex);
            return -1;
        }
    } else {
        conn->connection_secure = 1;
        printf("Secure connection established from %s:%d\n", 
               inet_ntoa(client_addr.sin_addr), ntohs(client_addr.sin_port));
    }
    
    // Add to epoll
    struct epoll_event event;
    event.events = EPOLLIN | EPOLLET; // Edge-triggered
    event.data.ptr = conn;
    if (epoll_ctl(server->epoll_fd, EPOLL_CTL_ADD, client_fd, &event) < 0) {
        printf("Failed to add connection to epoll\n");
        SSL_free(conn->ssl);
        close(client_fd);
        memset(conn, 0, sizeof(TLSConnection));
        pthread_mutex_unlock(&server->connections_mutex);
        return -1;
    }
    
    server->active_connections++;
    pthread_mutex_unlock(&server->connections_mutex);
    
    return 0;
}

static int handle_client_message(TLSConnection* conn) {
    if (!conn->connection_secure) {
        return -1;
    }
    
    ActorMessage msg;
    int bytes_read = SSL_read(conn->ssl, &msg, sizeof(ActorMessage));
    
    if (bytes_read <= 0) {
        int ssl_error = SSL_get_error(conn->ssl, bytes_read);
        if (ssl_error == SSL_ERROR_WANT_READ || ssl_error == SSL_ERROR_WANT_WRITE) {
            return 0; // Would block, try again later
        }
        printf("SSL_read error: %d\n", ssl_error);
        return -1;
    }
    
    if (bytes_read != sizeof(ActorMessage)) {
        printf("Incomplete message received: %d bytes\n", bytes_read);
        return -1;
    }
    
    conn->last_activity = time(NULL);
    conn->message_count++;
    
    // Verify message integrity
    if (verify_message_integrity(&msg) != 0) {
        printf("Message integrity check failed\n");
        return -1;
    }
    
    // Forward message to appropriate actor
    if (msg.recipient_id < MAX_ACTORS) {
        return actor_send_message(msg.sender_id, msg.recipient_id, msg.type, msg.data, msg.size);
    }
    
    printf("Invalid recipient actor ID: %d\n", msg.recipient_id);
    return -1;
}

//==============================================================================
// EXTERNAL API
//==============================================================================

void actor_system_shutdown(void) {
    if (!g_actor_system.system_initialized) {
        return;
    }
    
    printf("Shutting down actor system...\n");
    
    // Stop network server
    g_actor_system.network_server.server_running = 0;
    if (g_actor_system.network_server.server_thread) {
        pthread_join(g_actor_system.network_server.server_thread, NULL);
    }
    
    // Send shutdown messages to all active actors
    for (int i = 0; i < MAX_ACTORS; i++) {
        if (g_actor_system.actors[i].state == ACTOR_STATE_RUNNING) {
            actor_send_message(0, i, MSG_TYPE_SHUTDOWN, NULL, 0);
        }
    }
    
    // Wait for actor threads to finish
    for (int i = 0; i < ACTOR_THREAD_POOL_SIZE; i++) {
        pthread_join(g_actor_system.thread_pool[i], NULL);
    }
    
    // Cleanup SSL context
    if (g_actor_system.network_server.ssl_ctx) {
        SSL_CTX_free(g_actor_system.network_server.ssl_ctx);
    }
    
    // Cleanup connections
    for (int i = 0; i < MAX_CONNECTIONS; i++) {
        TLSConnection* conn = &g_actor_system.network_server.connections[i];
        if (conn->socket_fd > 0) {
            if (conn->ssl) {
                SSL_shutdown(conn->ssl);
                SSL_free(conn->ssl);
            }
            close(conn->socket_fd);
        }
    }
    
    if (g_actor_system.network_server.epoll_fd > 0) {
        close(g_actor_system.network_server.epoll_fd);
    }
    
    if (g_actor_system.network_server.server_fd > 0) {
        close(g_actor_system.network_server.server_fd);
    }
    
    // Cleanup actor mutexes and condition variables
    for (int i = 0; i < MAX_ACTORS; i++) {
        pthread_mutex_destroy(&g_actor_system.actors[i].message_queue_mutex);
        pthread_cond_destroy(&g_actor_system.actors[i].message_available);
    }
    
    pthread_mutex_destroy(&g_actor_system.system_mutex);
    pthread_mutex_destroy(&g_actor_system.network_server.connections_mutex);
    
    g_actor_system.system_initialized = 0;
    printf("Actor system shutdown complete\n");
}

int actor_get_stats(uint32_t actor_id, uint64_t* messages_processed, uint64_t* messages_sent, uint32_t* error_count) {
    if (actor_id >= MAX_ACTORS) {
        return -1;
    }
    
    ActorContext* actor = &g_actor_system.actors[actor_id];
    if (messages_processed) *messages_processed = actor->messages_processed;
    if (messages_sent) *messages_sent = actor->messages_sent;
    if (error_count) *error_count = actor->error_count;
    
    return 0;
}

int network_send_secure_message(const char* host, uint16_t port, const ActorMessage* msg) {
    // Client-side TLS connection for sending messages to other nodes
    // Implementation would create SSL client connection and send message
    printf("Sending secure message to %s:%d (type: %d)\n", host, port, msg->type);
    return 0; // Stub implementation
}

// Print system statistics
void actor_system_print_stats(void) {
    printf("\n=== Actor System Statistics ===\n");
    printf("Active actors: %d\n", g_actor_system.active_actors);
    printf("Active connections: %d\n", g_actor_system.network_server.active_connections);
    
    uint64_t total_messages_processed = 0;
    uint64_t total_messages_sent = 0;
    uint32_t total_errors = 0;
    
    for (int i = 0; i < MAX_ACTORS; i++) {
        ActorContext* actor = &g_actor_system.actors[i];
        if (actor->state == ACTOR_STATE_RUNNING) {
            total_messages_processed += actor->messages_processed;
            total_messages_sent += actor->messages_sent;
            total_errors += actor->error_count;
            
            printf("Actor %d: processed=%llu, sent=%llu, errors=%u, queue=%u\n",
                   i, actor->messages_processed, actor->messages_sent, 
                   actor->error_count, actor->queue_count);
        }
    }
    
    printf("Total messages processed: %llu\n", total_messages_processed);
    printf("Total messages sent: %llu\n", total_messages_sent);
    printf("Total errors: %u\n", total_errors);
    printf("==============================\n\n");
}
