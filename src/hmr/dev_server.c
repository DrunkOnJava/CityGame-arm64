/*
 * SimCity ARM64 - HMR Development Server
 * WebSocket-based development server for real-time HMR communication
 * 
 * Agent 4: Developer Tools & Debug Interface
 * Day 1: WebSocket Development Server Implementation
 */

#include "module_interface.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <pthread.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <sys/select.h>
#include <time.h>
#include <openssl/sha.h>
#include <openssl/evp.h>
#include <openssl/bio.h>
#include <openssl/buffer.h>

// Configuration constants
#define HMR_DEV_SERVER_PORT         8080
#define HMR_MAX_CLIENTS             32
#define HMR_BUFFER_SIZE             4096
#define HMR_WS_KEY_LEN              24
#define HMR_WS_ACCEPT_LEN           28
#define HMR_WS_MAGIC_STRING         "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

// WebSocket frame opcodes
typedef enum {
    WS_OPCODE_CONTINUATION = 0x0,
    WS_OPCODE_TEXT         = 0x1,
    WS_OPCODE_BINARY       = 0x2,
    WS_OPCODE_CLOSE        = 0x8,
    WS_OPCODE_PING         = 0x9,
    WS_OPCODE_PONG         = 0xA
} ws_opcode_t;

// HMR message types
typedef enum {
    HMR_MSG_BUILD_START,
    HMR_MSG_BUILD_SUCCESS,
    HMR_MSG_BUILD_ERROR,
    HMR_MSG_MODULE_RELOAD,
    HMR_MSG_MODULE_ERROR,
    HMR_MSG_PERFORMANCE_UPDATE,
    HMR_MSG_DEPENDENCY_UPDATE,
    HMR_MSG_CLIENT_CONNECT,
    HMR_MSG_CLIENT_DISCONNECT,
    HMR_MSG_STATUS_REQUEST
} hmr_message_type_t;

// Client connection state
typedef struct {
    int socket_fd;
    bool websocket_handshake_complete;
    char client_ip[16];
    uint16_t client_port;
    time_t connect_time;
    uint32_t message_count;
    char receive_buffer[HMR_BUFFER_SIZE];
    size_t receive_buffer_len;
    bool active;
} hmr_client_t;

// Performance history entry
typedef struct {
    double fps;
    double frame_time_ms;
    double memory_mb;
    uint64_t timestamp;
} hmr_performance_sample_t;

// Collaborative session tracking
typedef struct {
    char author[64];
    char file_path[256];
    uint64_t last_activity_time;
    bool active;
} hmr_collaborator_t;

// HMR development server state
typedef struct {
    int server_socket;
    int port;
    bool running;
    pthread_t server_thread;
    pthread_mutex_t clients_mutex;
    hmr_client_t clients[HMR_MAX_CLIENTS];
    uint32_t client_count;
    uint32_t total_connections;
    time_t start_time;
    
    // Performance monitoring
    uint64_t messages_sent;
    uint64_t messages_received;
    uint64_t bytes_sent;
    uint64_t bytes_received;
    
    // Day 6: Enhanced features
    hmr_performance_sample_t performance_history[1000]; // Rolling buffer
    uint32_t performance_history_index;
    uint32_t performance_history_count;
    pthread_mutex_t performance_mutex;
    
    // Collaborative features
    hmr_collaborator_t collaborators[16];
    uint32_t collaborator_count;
    pthread_mutex_t collaborators_mutex;
} hmr_dev_server_t;

// Global server instance
static hmr_dev_server_t g_dev_server = {0};

// Forward declarations
static void* hmr_server_thread(void* arg);
static int hmr_handle_http_request(hmr_client_t* client);
static int hmr_handle_websocket_frame(hmr_client_t* client);
static int hmr_send_websocket_frame(hmr_client_t* client, ws_opcode_t opcode, const char* data, size_t len);
static int hmr_broadcast_message(hmr_message_type_t type, const char* data);
static void hmr_generate_websocket_accept(const char* key, char* accept);
static void hmr_cleanup_client(hmr_client_t* client);
static int hmr_add_client(int socket_fd, struct sockaddr_in* addr);
static void hmr_remove_client(int client_index);

// Base64 encoding for WebSocket handshake
static char* base64_encode(const unsigned char* input, int length) {
    BIO *bmem, *b64;
    BUF_MEM *bptr;
    
    b64 = BIO_new(BIO_f_base64());
    bmem = BIO_new(BIO_s_mem());
    b64 = BIO_push(b64, bmem);
    BIO_set_flags(b64, BIO_FLAGS_BASE64_NO_NL);
    BIO_write(b64, input, length);
    BIO_flush(b64);
    BIO_get_mem_ptr(b64, &bptr);
    
    char* result = malloc(bptr->length + 1);
    memcpy(result, bptr->data, bptr->length);
    result[bptr->length] = 0;
    
    BIO_free_all(b64);
    return result;
}

// Initialize HMR development server
int hmr_dev_server_init(int port) {
    if (g_dev_server.running) {
        printf("[HMR] Development server already running on port %d\n", g_dev_server.port);
        return HMR_ERROR_ALREADY_EXISTS;
    }
    
    // Initialize server state
    memset(&g_dev_server, 0, sizeof(hmr_dev_server_t));
    g_dev_server.port = port > 0 ? port : HMR_DEV_SERVER_PORT;
    g_dev_server.start_time = time(NULL);
    
    // Initialize mutexes
    if (pthread_mutex_init(&g_dev_server.clients_mutex, NULL) != 0) {
        printf("[HMR] Failed to initialize clients mutex\n");
        return HMR_ERROR_THREADING;
    }
    
    if (pthread_mutex_init(&g_dev_server.performance_mutex, NULL) != 0) {
        printf("[HMR] Failed to initialize performance mutex\n");
        pthread_mutex_destroy(&g_dev_server.clients_mutex);
        return HMR_ERROR_THREADING;
    }
    
    if (pthread_mutex_init(&g_dev_server.collaborators_mutex, NULL) != 0) {
        printf("[HMR] Failed to initialize collaborators mutex\n");
        pthread_mutex_destroy(&g_dev_server.clients_mutex);
        pthread_mutex_destroy(&g_dev_server.performance_mutex);
        return HMR_ERROR_THREADING;
    }
    
    // Create server socket
    g_dev_server.server_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (g_dev_server.server_socket < 0) {
        printf("[HMR] Failed to create server socket: %s\n", strerror(errno));
        pthread_mutex_destroy(&g_dev_server.clients_mutex);
        return HMR_ERROR_NOT_SUPPORTED;
    }
    
    // Set socket options
    int opt = 1;
    if (setsockopt(g_dev_server.server_socket, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
        printf("[HMR] Failed to set socket options: %s\n", strerror(errno));
        close(g_dev_server.server_socket);
        pthread_mutex_destroy(&g_dev_server.clients_mutex);
        return HMR_ERROR_NOT_SUPPORTED;
    }
    
    // Bind server socket
    struct sockaddr_in server_addr = {0};
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(g_dev_server.port);
    
    if (bind(g_dev_server.server_socket, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        printf("[HMR] Failed to bind server socket to port %d: %s\n", g_dev_server.port, strerror(errno));
        close(g_dev_server.server_socket);
        pthread_mutex_destroy(&g_dev_server.clients_mutex);
        return HMR_ERROR_NOT_SUPPORTED;
    }
    
    // Start listening
    if (listen(g_dev_server.server_socket, 10) < 0) {
        printf("[HMR] Failed to listen on server socket: %s\n", strerror(errno));
        close(g_dev_server.server_socket);
        pthread_mutex_destroy(&g_dev_server.clients_mutex);
        return HMR_ERROR_NOT_SUPPORTED;
    }
    
    // Start server thread
    g_dev_server.running = true;
    if (pthread_create(&g_dev_server.server_thread, NULL, hmr_server_thread, NULL) != 0) {
        printf("[HMR] Failed to create server thread\n");
        g_dev_server.running = false;
        close(g_dev_server.server_socket);
        pthread_mutex_destroy(&g_dev_server.clients_mutex);
        return HMR_ERROR_THREADING;
    }
    
    printf("[HMR] Development server started on port %d\n", g_dev_server.port);
    printf("[HMR] WebSocket endpoint: ws://localhost:%d/ws\n", g_dev_server.port);
    printf("[HMR] Dashboard URL: http://localhost:%d/\n", g_dev_server.port);
    
    return HMR_SUCCESS;
}

// Shutdown HMR development server
void hmr_dev_server_shutdown(void) {
    if (!g_dev_server.running) {
        return;
    }
    
    printf("[HMR] Shutting down development server...\n");
    
    // Stop server thread
    g_dev_server.running = false;
    
    // Close server socket to wake up accept()
    close(g_dev_server.server_socket);
    
    // Wait for server thread to finish
    pthread_join(g_dev_server.server_thread, NULL);
    
    // Clean up all clients
    pthread_mutex_lock(&g_dev_server.clients_mutex);
    for (int i = 0; i < HMR_MAX_CLIENTS; i++) {
        if (g_dev_server.clients[i].active) {
            hmr_cleanup_client(&g_dev_server.clients[i]);
        }
    }
    pthread_mutex_unlock(&g_dev_server.clients_mutex);
    
    // Clean up mutexes
    pthread_mutex_destroy(&g_dev_server.clients_mutex);
    pthread_mutex_destroy(&g_dev_server.performance_mutex);
    pthread_mutex_destroy(&g_dev_server.collaborators_mutex);
    
    // Print server statistics
    time_t uptime = time(NULL) - g_dev_server.start_time;
    printf("[HMR] Server statistics:\n");
    printf("  Uptime: %ld seconds\n", uptime);
    printf("  Total connections: %u\n", g_dev_server.total_connections);
    printf("  Messages sent: %llu\n", g_dev_server.messages_sent);
    printf("  Messages received: %llu\n", g_dev_server.messages_received);
    printf("  Bytes sent: %llu\n", g_dev_server.bytes_sent);
    printf("  Bytes received: %llu\n", g_dev_server.bytes_received);
    
    printf("[HMR] Development server shutdown complete\n");
}

// Main server thread
static void* hmr_server_thread(void* arg) {
    (void)arg;
    
    fd_set read_fds, write_fds;
    int max_fd;
    struct timeval timeout;
    
    printf("[HMR] Server thread started, listening for connections...\n");
    
    while (g_dev_server.running) {
        FD_ZERO(&read_fds);
        FD_ZERO(&write_fds);
        
        // Add server socket to read set
        FD_SET(g_dev_server.server_socket, &read_fds);
        max_fd = g_dev_server.server_socket;
        
        // Add client sockets to read set
        pthread_mutex_lock(&g_dev_server.clients_mutex);
        for (int i = 0; i < HMR_MAX_CLIENTS; i++) {
            if (g_dev_server.clients[i].active) {
                FD_SET(g_dev_server.clients[i].socket_fd, &read_fds);
                if (g_dev_server.clients[i].socket_fd > max_fd) {
                    max_fd = g_dev_server.clients[i].socket_fd;
                }
            }
        }
        pthread_mutex_unlock(&g_dev_server.clients_mutex);
        
        // Set timeout for select
        timeout.tv_sec = 1;
        timeout.tv_usec = 0;
        
        int result = select(max_fd + 1, &read_fds, &write_fds, NULL, &timeout);
        
        if (result < 0) {
            if (errno != EINTR) {
                printf("[HMR] Select error: %s\n", strerror(errno));
            }
            continue;
        }
        
        if (result == 0) {
            // Timeout - continue loop for clean shutdown check
            continue;
        }
        
        // Check for new connections
        if (FD_ISSET(g_dev_server.server_socket, &read_fds)) {
            struct sockaddr_in client_addr;
            socklen_t client_len = sizeof(client_addr);
            
            int client_socket = accept(g_dev_server.server_socket, (struct sockaddr*)&client_addr, &client_len);
            if (client_socket >= 0) {
                // Set non-blocking mode
                int flags = fcntl(client_socket, F_GETFL, 0);
                fcntl(client_socket, F_SETFL, flags | O_NONBLOCK);
                
                // Add client
                if (hmr_add_client(client_socket, &client_addr) != HMR_SUCCESS) {
                    close(client_socket);
                }
            }
        }
        
        // Handle client data
        pthread_mutex_lock(&g_dev_server.clients_mutex);
        for (int i = 0; i < HMR_MAX_CLIENTS; i++) {
            if (g_dev_server.clients[i].active && FD_ISSET(g_dev_server.clients[i].socket_fd, &read_fds)) {
                hmr_client_t* client = &g_dev_server.clients[i];
                
                if (!client->websocket_handshake_complete) {
                    // Handle HTTP/WebSocket handshake
                    if (hmr_handle_http_request(client) != HMR_SUCCESS) {
                        hmr_remove_client(i);
                        continue;
                    }
                } else {
                    // Handle WebSocket frames
                    if (hmr_handle_websocket_frame(client) != HMR_SUCCESS) {
                        hmr_remove_client(i);
                        continue;
                    }
                }
            }
        }
        pthread_mutex_unlock(&g_dev_server.clients_mutex);
    }
    
    printf("[HMR] Server thread exiting\n");
    return NULL;
}

// Add new client connection
static int hmr_add_client(int socket_fd, struct sockaddr_in* addr) {
    pthread_mutex_lock(&g_dev_server.clients_mutex);
    
    // Find empty slot
    int client_index = -1;
    for (int i = 0; i < HMR_MAX_CLIENTS; i++) {
        if (!g_dev_server.clients[i].active) {
            client_index = i;
            break;
        }
    }
    
    if (client_index == -1) {
        pthread_mutex_unlock(&g_dev_server.clients_mutex);
        printf("[HMR] Maximum clients reached, rejecting connection\n");
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    // Initialize client
    hmr_client_t* client = &g_dev_server.clients[client_index];
    memset(client, 0, sizeof(hmr_client_t));
    client->socket_fd = socket_fd;
    client->websocket_handshake_complete = false;
    client->connect_time = time(NULL);
    client->active = true;
    
    // Store client address
    inet_ntop(AF_INET, &addr->sin_addr, client->client_ip, sizeof(client->client_ip));
    client->client_port = ntohs(addr->sin_port);
    
    g_dev_server.client_count++;
    g_dev_server.total_connections++;
    
    pthread_mutex_unlock(&g_dev_server.clients_mutex);
    
    printf("[HMR] Client connected: %s:%u (slot %d)\n", client->client_ip, client->client_port, client_index);
    
    return HMR_SUCCESS;
}

// Remove client connection
static void hmr_remove_client(int client_index) {
    hmr_client_t* client = &g_dev_server.clients[client_index];
    
    if (client->active) {
        printf("[HMR] Client disconnected: %s:%u (messages: %u)\n", 
               client->client_ip, client->client_port, client->message_count);
        
        hmr_cleanup_client(client);
        g_dev_server.client_count--;
    }
}

// Clean up client resources
static void hmr_cleanup_client(hmr_client_t* client) {
    if (client->socket_fd >= 0) {
        close(client->socket_fd);
    }
    memset(client, 0, sizeof(hmr_client_t));
    client->socket_fd = -1;
}

// Generate WebSocket accept key
static void hmr_generate_websocket_accept(const char* key, char* accept) {
    char combined[256];
    snprintf(combined, sizeof(combined), "%s%s", key, HMR_WS_MAGIC_STRING);
    
    unsigned char hash[SHA_DIGEST_LENGTH];
    SHA1((unsigned char*)combined, strlen(combined), hash);
    
    char* encoded = base64_encode(hash, SHA_DIGEST_LENGTH);
    strncpy(accept, encoded, HMR_WS_ACCEPT_LEN);
    accept[HMR_WS_ACCEPT_LEN - 1] = '\0';
    free(encoded);
}

// Handle HTTP request and WebSocket handshake
static int hmr_handle_http_request(hmr_client_t* client) {
    char buffer[HMR_BUFFER_SIZE];
    ssize_t bytes_read = recv(client->socket_fd, buffer, sizeof(buffer) - 1, 0);
    
    if (bytes_read <= 0) {
        if (bytes_read == 0 || (errno != EAGAIN && errno != EWOULDBLOCK)) {
            return HMR_ERROR_NOT_FOUND;
        }
        return HMR_SUCCESS; // Would block, try again later
    }
    
    buffer[bytes_read] = '\0';
    g_dev_server.bytes_received += bytes_read;
    
    // Check for WebSocket upgrade request
    if (strstr(buffer, "Upgrade: websocket") && strstr(buffer, "Connection: Upgrade")) {
        // Extract WebSocket key
        char* key_start = strstr(buffer, "Sec-WebSocket-Key: ");
        if (!key_start) {
            return HMR_ERROR_INVALID_ARG;
        }
        
        key_start += 19; // Length of "Sec-WebSocket-Key: "
        char* key_end = strstr(key_start, "\r\n");
        if (!key_end) {
            return HMR_ERROR_INVALID_ARG;
        }
        
        char websocket_key[HMR_WS_KEY_LEN + 1];
        size_t key_len = key_end - key_start;
        if (key_len > HMR_WS_KEY_LEN) {
            key_len = HMR_WS_KEY_LEN;
        }
        strncpy(websocket_key, key_start, key_len);
        websocket_key[key_len] = '\0';
        
        // Generate accept key
        char accept_key[HMR_WS_ACCEPT_LEN];
        hmr_generate_websocket_accept(websocket_key, accept_key);
        
        // Send WebSocket handshake response
        char response[1024];
        int response_len = snprintf(response, sizeof(response),
            "HTTP/1.1 101 Switching Protocols\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            "Sec-WebSocket-Accept: %s\r\n"
            "Sec-WebSocket-Protocol: hmr\r\n"
            "\r\n",
            accept_key);
        
        ssize_t sent = send(client->socket_fd, response, response_len, 0);
        if (sent != response_len) {
            return HMR_ERROR_NOT_SUPPORTED;
        }
        
        client->websocket_handshake_complete = true;
        g_dev_server.bytes_sent += sent;
        
        printf("[HMR] WebSocket handshake completed for %s:%u\n", client->client_ip, client->client_port);
        
        // Send welcome message
        hmr_send_websocket_frame(client, WS_OPCODE_TEXT, 
            "{\"type\":\"welcome\",\"message\":\"Connected to HMR development server\"}", -1);
        
        return HMR_SUCCESS;
    }
    
    // Handle regular HTTP request (serve dashboard)
    const char* http_response = 
        "HTTP/1.1 200 OK\r\n"
        "Content-Type: text/html\r\n"
        "Connection: close\r\n"
        "\r\n"
        "<!DOCTYPE html>\n"
        "<html><head><title>HMR Development Server</title></head>\n"
        "<body><h1>SimCity ARM64 HMR Development Server</h1>\n"
        "<p>WebSocket endpoint: <code>ws://localhost:" STR(HMR_DEV_SERVER_PORT) "/ws</code></p>\n"
        "<p>Dashboard will be available at: <a href=\"/dashboard\">/dashboard</a></p>\n"
        "</body></html>\n";
    
    ssize_t sent = send(client->socket_fd, http_response, strlen(http_response), 0);
    g_dev_server.bytes_sent += sent;
    
    return HMR_ERROR_NOT_FOUND; // Close connection after serving HTTP
}

#define STR_HELPER(x) #x
#define STR(x) STR_HELPER(x)

// Handle WebSocket frame
static int hmr_handle_websocket_frame(hmr_client_t* client) {
    // Basic WebSocket frame parsing - simplified for development use
    char buffer[HMR_BUFFER_SIZE];
    ssize_t bytes_read = recv(client->socket_fd, buffer, sizeof(buffer), 0);
    
    if (bytes_read <= 0) {
        if (bytes_read == 0 || (errno != EAGAIN && errno != EWOULDBLOCK)) {
            return HMR_ERROR_NOT_FOUND;
        }
        return HMR_SUCCESS;
    }
    
    g_dev_server.bytes_received += bytes_read;
    client->message_count++;
    g_dev_server.messages_received++;
    
    // For now, just echo back a status message
    hmr_send_websocket_frame(client, WS_OPCODE_TEXT, 
        "{\"type\":\"status\",\"message\":\"HMR server active\"}", -1);
    
    return HMR_SUCCESS;
}

// Send WebSocket frame to client
static int hmr_send_websocket_frame(hmr_client_t* client, ws_opcode_t opcode, const char* data, size_t len) {
    if (len == (size_t)-1) {
        len = strlen(data);
    }
    
    // Simple WebSocket frame format (no masking for server->client)
    char frame[HMR_BUFFER_SIZE];
    size_t frame_len = 0;
    
    // First byte: FIN bit + opcode
    frame[frame_len++] = 0x80 | (opcode & 0x0F);
    
    // Payload length
    if (len < 126) {
        frame[frame_len++] = len;
    } else if (len < 65536) {
        frame[frame_len++] = 126;
        frame[frame_len++] = (len >> 8) & 0xFF;
        frame[frame_len++] = len & 0xFF;
    } else {
        // We don't support very large frames for now
        return HMR_ERROR_NOT_SUPPORTED;
    }
    
    // Copy payload
    if (frame_len + len > sizeof(frame)) {
        return HMR_ERROR_OUT_OF_MEMORY;
    }
    
    memcpy(frame + frame_len, data, len);
    frame_len += len;
    
    ssize_t sent = send(client->socket_fd, frame, frame_len, 0);
    if (sent != (ssize_t)frame_len) {
        return HMR_ERROR_NOT_SUPPORTED;
    }
    
    g_dev_server.bytes_sent += sent;
    g_dev_server.messages_sent++;
    
    return HMR_SUCCESS;
}

// Broadcast message to all connected clients
static int hmr_broadcast_message(hmr_message_type_t type, const char* data) {
    if (!g_dev_server.running) {
        return HMR_ERROR_NOT_FOUND;
    }
    
    // Create JSON message
    char message[HMR_BUFFER_SIZE];
    const char* type_str = "unknown";
    
    switch (type) {
        case HMR_MSG_BUILD_START: type_str = "build_start"; break;
        case HMR_MSG_BUILD_SUCCESS: type_str = "build_success"; break;
        case HMR_MSG_BUILD_ERROR: type_str = "build_error"; break;
        case HMR_MSG_MODULE_RELOAD: type_str = "module_reload"; break;
        case HMR_MSG_MODULE_ERROR: type_str = "module_error"; break;
        case HMR_MSG_PERFORMANCE_UPDATE: type_str = "performance_update"; break;
        case HMR_MSG_DEPENDENCY_UPDATE: type_str = "dependency_update"; break;
        default: break;
    }
    
    int msg_len = snprintf(message, sizeof(message),
        "{\"type\":\"%s\",\"timestamp\":%ld,\"data\":%s}",
        type_str, time(NULL), data ? data : "null");
    
    // Broadcast to all connected WebSocket clients
    pthread_mutex_lock(&g_dev_server.clients_mutex);
    int success_count = 0;
    
    for (int i = 0; i < HMR_MAX_CLIENTS; i++) {
        if (g_dev_server.clients[i].active && g_dev_server.clients[i].websocket_handshake_complete) {
            if (hmr_send_websocket_frame(&g_dev_server.clients[i], WS_OPCODE_TEXT, message, msg_len) == HMR_SUCCESS) {
                success_count++;
            }
        }
    }
    
    pthread_mutex_unlock(&g_dev_server.clients_mutex);
    
    return success_count > 0 ? HMR_SUCCESS : HMR_ERROR_NOT_FOUND;
}

// Public API functions

// Notify build start
void hmr_notify_build_start(const char* module_name) {
    char data[256];
    snprintf(data, sizeof(data), "{\"module\":\"%s\"}", module_name ? module_name : "all");
    hmr_broadcast_message(HMR_MSG_BUILD_START, data);
}

// Notify build success
void hmr_notify_build_success(const char* module_name, uint64_t build_time_ms) {
    char data[256];
    snprintf(data, sizeof(data), "{\"module\":\"%s\",\"build_time_ms\":%llu}", 
             module_name ? module_name : "all", build_time_ms);
    hmr_broadcast_message(HMR_MSG_BUILD_SUCCESS, data);
}

// Notify build error
void hmr_notify_build_error(const char* module_name, const char* error_message) {
    char data[512];
    snprintf(data, sizeof(data), "{\"module\":\"%s\",\"error\":\"%s\"}", 
             module_name ? module_name : "unknown", error_message ? error_message : "Unknown error");
    hmr_broadcast_message(HMR_MSG_BUILD_ERROR, data);
}

// Notify module reload
void hmr_notify_module_reload(const char* module_name, bool success) {
    char data[256];
    snprintf(data, sizeof(data), "{\"module\":\"%s\",\"success\":%s}", 
             module_name ? module_name : "unknown", success ? "true" : "false");
    hmr_broadcast_message(HMR_MSG_MODULE_RELOAD, data);
}

// Get server status
void hmr_get_server_status(char* status_json, size_t max_len) {
    if (!status_json || max_len == 0) return;
    
    time_t uptime = g_dev_server.running ? (time(NULL) - g_dev_server.start_time) : 0;
    
    snprintf(status_json, max_len,
        "{"
        "\"running\":%s,"
        "\"port\":%d,"
        "\"uptime\":%ld,"
        "\"clients\":%u,"
        "\"total_connections\":%u,"
        "\"messages_sent\":%llu,"
        "\"messages_received\":%llu,"
        "\"bytes_sent\":%llu,"
        "\"bytes_received\":%llu"
        "}",
        g_dev_server.running ? "true" : "false",
        g_dev_server.port,
        uptime,
        g_dev_server.client_count,
        g_dev_server.total_connections,
        g_dev_server.messages_sent,
        g_dev_server.messages_received,
        g_dev_server.bytes_sent,
        g_dev_server.bytes_received);
}

// Day 6: Enhanced API Implementation

// Add performance sample to history
void hmr_add_performance_sample(double fps, double frame_time_ms, double memory_mb, uint64_t timestamp) {
    pthread_mutex_lock(&g_dev_server.performance_mutex);
    
    // Add to rolling buffer
    hmr_performance_sample_t* sample = &g_dev_server.performance_history[g_dev_server.performance_history_index];
    sample->fps = fps;
    sample->frame_time_ms = frame_time_ms;
    sample->memory_mb = memory_mb;
    sample->timestamp = timestamp;
    
    g_dev_server.performance_history_index = (g_dev_server.performance_history_index + 1) % 1000;
    if (g_dev_server.performance_history_count < 1000) {
        g_dev_server.performance_history_count++;
    }
    
    pthread_mutex_unlock(&g_dev_server.performance_mutex);
    
    // Broadcast performance update
    char perf_data[512];
    snprintf(perf_data, sizeof(perf_data),
        "{\"system\":{\"fps\":%.2f,\"avg_frame_time_ms\":%.3f,\"memory_usage_mb\":%.1f,\"timestamp\":%llu}}",
        fps, frame_time_ms, memory_mb, timestamp);
    hmr_broadcast_message(HMR_MSG_PERFORMANCE_UPDATE, perf_data);
}

// Get performance history as JSON
void hmr_get_performance_history(char* history_json, size_t max_len) {
    if (!history_json || max_len == 0) return;
    
    pthread_mutex_lock(&g_dev_server.performance_mutex);
    
    size_t pos = 0;
    pos += snprintf(history_json + pos, max_len - pos, "{\"samples\":[");
    
    uint32_t count = g_dev_server.performance_history_count;
    uint32_t start_index = (g_dev_server.performance_history_index + 1000 - count) % 1000;
    
    for (uint32_t i = 0; i < count && pos < max_len - 100; i++) {
        uint32_t idx = (start_index + i) % 1000;
        hmr_performance_sample_t* sample = &g_dev_server.performance_history[idx];
        
        if (i > 0) {
            pos += snprintf(history_json + pos, max_len - pos, ",");
        }
        
        pos += snprintf(history_json + pos, max_len - pos,
            "{\"fps\":%.2f,\"frame_time_ms\":%.3f,\"memory_mb\":%.1f,\"timestamp\":%llu}",
            sample->fps, sample->frame_time_ms, sample->memory_mb, sample->timestamp);
    }
    
    snprintf(history_json + pos, max_len - pos, "]}");
    
    pthread_mutex_unlock(&g_dev_server.performance_mutex);
}

// Notify code change for collaborative editing
void hmr_notify_code_change(const char* file_path, const char* content, const char* author) {
    char data[1024];
    snprintf(data, sizeof(data),
        "{\"file_path\":\"%s\",\"author\":\"%s\",\"timestamp\":%ld,\"content_length\":%zu}",
        file_path ? file_path : "unknown",
        author ? author : "anonymous",
        time(NULL),
        content ? strlen(content) : 0);
    
    hmr_broadcast_message(HMR_MSG_MODULE_RELOAD, data);
}

// Serve file content for code editor
void hmr_serve_file_content(const char* file_path, char* content_buffer, size_t max_len) {
    if (!file_path || !content_buffer || max_len == 0) return;
    
    FILE* file = fopen(file_path, "r");
    if (!file) {
        snprintf(content_buffer, max_len, "// File not found: %s", file_path);
        return;
    }
    
    size_t bytes_read = fread(content_buffer, 1, max_len - 1, file);
    content_buffer[bytes_read] = '\0';
    fclose(file);
}

// Save file content from code editor
void hmr_save_file_content(const char* file_path, const char* content, const char* author) {
    if (!file_path || !content) return;
    
    FILE* file = fopen(file_path, "w");
    if (!file) {
        printf("[HMR] Failed to save file: %s\n", file_path);
        return;
    }
    
    fwrite(content, 1, strlen(content), file);
    fclose(file);
    
    printf("[HMR] File saved by %s: %s\n", author ? author : "anonymous", file_path);
    hmr_notify_code_change(file_path, content, author);
}

// Track collaborative activity
void hmr_notify_collaborative_event(const hmr_collaborative_event_t* event) {
    if (!event) return;
    
    pthread_mutex_lock(&g_dev_server.collaborators_mutex);
    
    // Find or create collaborator entry
    hmr_collaborator_t* collaborator = NULL;
    for (uint32_t i = 0; i < g_dev_server.collaborator_count; i++) {
        if (strcmp(g_dev_server.collaborators[i].author, event->author) == 0) {
            collaborator = &g_dev_server.collaborators[i];
            break;
        }
    }
    
    if (!collaborator && g_dev_server.collaborator_count < 16) {
        collaborator = &g_dev_server.collaborators[g_dev_server.collaborator_count++];
        strncpy(collaborator->author, event->author, sizeof(collaborator->author) - 1);
        collaborator->author[sizeof(collaborator->author) - 1] = '\0';
        collaborator->active = true;
    }
    
    if (collaborator) {
        strncpy(collaborator->file_path, event->file_path, sizeof(collaborator->file_path) - 1);
        collaborator->file_path[sizeof(collaborator->file_path) - 1] = '\0';
        collaborator->last_activity_time = event->timestamp;
        collaborator->active = true;
    }
    
    pthread_mutex_unlock(&g_dev_server.collaborators_mutex);
    
    // Broadcast collaborative event
    char data[512];
    snprintf(data, sizeof(data),
        "{\"author\":\"%s\",\"file_path\":\"%s\",\"action\":\"%s\",\"timestamp\":%llu}",
        event->author, event->file_path, event->action, event->timestamp);
    hmr_broadcast_message(HMR_MSG_MODULE_RELOAD, data);
}

// Get active collaborators list
void hmr_get_active_collaborators(char* collaborators_json, size_t max_len) {
    if (!collaborators_json || max_len == 0) return;
    
    pthread_mutex_lock(&g_dev_server.collaborators_mutex);
    
    size_t pos = 0;
    pos += snprintf(collaborators_json + pos, max_len - pos, "{\"collaborators\":[");
    
    uint64_t current_time = (uint64_t)time(NULL);
    bool first = true;
    
    for (uint32_t i = 0; i < g_dev_server.collaborator_count && pos < max_len - 100; i++) {
        hmr_collaborator_t* collab = &g_dev_server.collaborators[i];
        
        // Consider collaborator active if last activity was within 5 minutes
        if (collab->active && (current_time - collab->last_activity_time) < 300) {
            if (!first) {
                pos += snprintf(collaborators_json + pos, max_len - pos, ",");
            }
            first = false;
            
            pos += snprintf(collaborators_json + pos, max_len - pos,
                "{\"author\":\"%s\",\"file_path\":\"%s\",\"last_activity\":%llu}",
                collab->author, collab->file_path, collab->last_activity_time);
        }
    }
    
    snprintf(collaborators_json + pos, max_len - pos, "]}");
    
    pthread_mutex_unlock(&g_dev_server.collaborators_mutex);
}

// Get module dependencies
void hmr_get_module_dependencies(const char* module_name, char* deps_json, size_t max_len) {
    if (!module_name || !deps_json || max_len == 0) return;
    
    // This is a placeholder - in a real implementation, this would parse
    // the module files and extract actual dependencies
    snprintf(deps_json, max_len,
        "{"
        "\"module\":\"%s\","
        "\"dependencies\":["
        "{\"name\":\"platform\",\"type\":\"direct\",\"load_time_ms\":12.5},"
        "{\"name\":\"memory\",\"type\":\"direct\",\"load_time_ms\":8.3},"
        "{\"name\":\"graphics\",\"type\":\"indirect\",\"load_time_ms\":15.7}"
        "],"
        "\"dependents\":["
        "{\"name\":\"simulation\",\"type\":\"direct\"},"
        "{\"name\":\"ui\",\"type\":\"indirect\"}"
        "]"
        "}",
        module_name);
}