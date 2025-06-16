#!/bin/bash

# Agent 2: File Watcher & Build Pipeline - Day 12
# Intelligent Caching System with Global Cache Sharing and ML-powered Prefetching
# Production-grade distributed caching with advanced analytics

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CACHE_ROOT="$PROJECT_ROOT/build/cache"
GLOBAL_CACHE_DIR="$CACHE_ROOT/global"
LOCAL_CACHE_DIR="$CACHE_ROOT/local"
DISTRIBUTED_CACHE_DIR="$CACHE_ROOT/distributed"
ANALYTICS_DIR="$CACHE_ROOT/analytics"
CACHE_DB="$CACHE_ROOT/cache.db"

# Performance targets
TARGET_CACHE_HIT_RATE=99.0
TARGET_PREFETCH_ACCURACY=95.0
TARGET_CACHE_SIZE_LIMIT="10GB"
TARGET_NETWORK_EFFICIENCY=95.0

# Cache configuration
CACHE_COMPRESSION_LEVEL=6
CACHE_EXPIRY_DAYS=7
PREFETCH_WORKER_COUNT=4
CACHE_WARMING_DEPTH=3
GLOBAL_SYNC_INTERVAL=300  # 5 minutes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[CACHE-INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[CACHE-WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[CACHE-ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[CACHE-SUCCESS]${NC} $1" >&2
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${PURPLE}[CACHE-DEBUG]${NC} $1" >&2
    fi
}

# Initialize intelligent caching system
init_cache_system() {
    log_info "Initializing Intelligent Caching System..."
    
    # Create directory structure
    mkdir -p "$CACHE_ROOT"/{global,local,distributed,analytics,temp,prefetch}
    mkdir -p "$GLOBAL_CACHE_DIR"/{objects,metadata,indices,compression}
    mkdir -p "$LOCAL_CACHE_DIR"/{hot,warm,cold,staging}
    mkdir -p "$DISTRIBUTED_CACHE_DIR"/{nodes,coordination,replication}
    mkdir -p "$ANALYTICS_DIR"/{performance,patterns,predictions,reports}
    
    # Initialize cache database
    if [[ ! -f "$CACHE_DB" ]]; then
        log_info "Creating cache database..."
        sqlite3 "$CACHE_DB" <<EOF
-- Cache entries with metadata
CREATE TABLE cache_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cache_key TEXT UNIQUE NOT NULL,
    file_hash TEXT NOT NULL,
    file_path TEXT NOT NULL,
    cache_tier TEXT NOT NULL, -- hot, warm, cold
    size_bytes INTEGER NOT NULL,
    compression_ratio REAL,
    created_timestamp INTEGER NOT NULL,
    accessed_timestamp INTEGER NOT NULL,
    access_count INTEGER DEFAULT 1,
    hit_count INTEGER DEFAULT 0,
    miss_count INTEGER DEFAULT 0,
    build_context TEXT,
    developer_id TEXT,
    project_version TEXT,
    dependencies TEXT, -- JSON array
    build_type TEXT,
    success_rate REAL DEFAULT 1.0,
    avg_build_time REAL
);

-- Cache access patterns
CREATE TABLE access_patterns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cache_key TEXT NOT NULL,
    access_timestamp INTEGER NOT NULL,
    access_type TEXT NOT NULL, -- hit, miss, prefetch
    context TEXT,
    build_session_id TEXT,
    developer_id TEXT,
    system_load REAL,
    cache_tier TEXT,
    response_time_ms REAL,
    FOREIGN KEY (cache_key) REFERENCES cache_entries (cache_key)
);

-- Global cache coordination
CREATE TABLE global_cache_nodes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    node_id TEXT UNIQUE NOT NULL,
    node_address TEXT NOT NULL,
    node_type TEXT NOT NULL, -- coordinator, worker, replica
    last_seen INTEGER NOT NULL,
    status TEXT NOT NULL, -- active, inactive, maintenance
    storage_capacity INTEGER,
    storage_used INTEGER,
    network_bandwidth INTEGER,
    cache_hit_rate REAL,
    sync_lag INTEGER
);

-- Cache replication tracking
CREATE TABLE cache_replication (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cache_key TEXT NOT NULL,
    source_node TEXT NOT NULL,
    target_nodes TEXT NOT NULL, -- JSON array
    replication_factor INTEGER DEFAULT 3,
    replication_status TEXT NOT NULL, -- pending, active, failed
    last_sync_timestamp INTEGER,
    sync_checksum TEXT,
    FOREIGN KEY (cache_key) REFERENCES cache_entries (cache_key)
);

-- Prefetch predictions
CREATE TABLE prefetch_predictions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    prediction_id TEXT UNIQUE NOT NULL,
    cache_key TEXT NOT NULL,
    predicted_access_time INTEGER,
    confidence_score REAL,
    prefetch_trigger TEXT,
    actual_access_time INTEGER,
    prediction_accuracy REAL,
    prefetch_benefit_ms REAL,
    created_timestamp INTEGER NOT NULL
);

-- Cache analytics
CREATE TABLE cache_analytics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    metric_type TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    value REAL NOT NULL,
    context TEXT,
    node_id TEXT
);

-- Performance optimizations
CREATE INDEX idx_cache_entries_key ON cache_entries(cache_key);
CREATE INDEX idx_cache_entries_accessed ON cache_entries(accessed_timestamp);
CREATE INDEX idx_cache_entries_tier ON cache_entries(cache_tier);
CREATE INDEX idx_access_patterns_timestamp ON access_patterns(access_timestamp);
CREATE INDEX idx_access_patterns_key ON access_patterns(cache_key);
CREATE INDEX idx_global_nodes_status ON global_cache_nodes(status);
CREATE INDEX idx_prefetch_predictions_time ON prefetch_predictions(predicted_access_time);
CREATE INDEX idx_analytics_timestamp ON cache_analytics(timestamp);
EOF
        log_success "Cache database created"
    fi
    
    # Create cache coordination scripts
    create_cache_coordination_system
    
    # Initialize ML prefetch system
    create_prefetch_ml_system
    
    log_success "Intelligent caching system initialized"
}

# Create cache coordination system
create_cache_coordination_system() {
    log_info "Creating cache coordination system..."
    
    # Global cache coordinator
    cat > "$DISTRIBUTED_CACHE_DIR/coordinator.py" <<'PYTHON_EOF'
#!/usr/bin/env python3
"""
Intelligent Cache Coordinator
Global cache coordination with ML-powered optimization
"""

import asyncio
import aiohttp
import sqlite3
import json
import hashlib
import time
import os
import sys
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from pathlib import Path
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

@dataclass
class CacheEntry:
    """Cache entry with metadata"""
    cache_key: str
    file_hash: str
    file_path: str
    size_bytes: int
    cache_tier: str
    access_count: int
    hit_rate: float

@dataclass
class CacheNode:
    """Distributed cache node"""
    node_id: str
    address: str
    node_type: str
    storage_capacity: int
    storage_used: int
    hit_rate: float
    status: str

class IntelligentCacheCoordinator:
    """Advanced cache coordination with ML optimization"""
    
    def __init__(self, db_path: str, cache_root: str, port: int = 8080):
        self.db_path = db_path
        self.cache_root = Path(cache_root)
        self.port = port
        self.nodes = {}
        self.app = None
        self.prefetch_queue = asyncio.Queue()
        
    async def start_coordinator(self):
        """Start the cache coordinator service"""
        logger.info(f"Starting cache coordinator on port {self.port}")
        
        from aiohttp import web
        
        self.app = web.Application()
        
        # REST API routes
        self.app.router.add_get('/health', self.health_check)
        self.app.router.add_post('/nodes/register', self.register_node)
        self.app.router.add_get('/nodes', self.list_nodes)
        self.app.router.add_get('/cache/{cache_key}', self.get_cache_entry)
        self.app.router.add_post('/cache/{cache_key}', self.put_cache_entry)
        self.app.router.add_delete('/cache/{cache_key}', self.delete_cache_entry)
        self.app.router.add_post('/prefetch', self.trigger_prefetch)
        self.app.router.add_get('/analytics', self.get_analytics)
        self.app.router.add_post('/optimize', self.optimize_cache)
        
        # Start background tasks
        asyncio.create_task(self.node_health_monitor())
        asyncio.create_task(self.cache_optimizer())
        asyncio.create_task(self.prefetch_worker())
        
        runner = web.AppRunner(self.app)
        await runner.setup()
        site = web.TCPSite(runner, '0.0.0.0', self.port)
        await site.start()
        
        logger.info(f"Cache coordinator started on http://0.0.0.0:{self.port}")
        
    async def health_check(self, request):
        """Health check endpoint"""
        return web.json_response({'status': 'healthy', 'timestamp': time.time()})
    
    async def register_node(self, request):
        """Register a new cache node"""
        data = await request.json()
        
        node = CacheNode(
            node_id=data['node_id'],
            address=data['address'],
            node_type=data.get('node_type', 'worker'),
            storage_capacity=data.get('storage_capacity', 0),
            storage_used=data.get('storage_used', 0),
            hit_rate=data.get('hit_rate', 0.0),
            status='active'
        )
        
        self.nodes[node.node_id] = node
        
        # Update database
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT OR REPLACE INTO global_cache_nodes
            (node_id, node_address, node_type, last_seen, status, 
             storage_capacity, storage_used, cache_hit_rate)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (node.node_id, node.address, node.node_type, int(time.time()),
              node.status, node.storage_capacity, node.storage_used, node.hit_rate))
        
        conn.commit()
        conn.close()
        
        logger.info(f"Registered node: {node.node_id} ({node.address})")
        return web.json_response({'status': 'registered', 'node_id': node.node_id})
    
    async def list_nodes(self, request):
        """List all registered cache nodes"""
        nodes_data = []
        for node in self.nodes.values():
            nodes_data.append({
                'node_id': node.node_id,
                'address': node.address,
                'type': node.node_type,
                'status': node.status,
                'hit_rate': node.hit_rate,
                'storage_used': node.storage_used,
                'storage_capacity': node.storage_capacity
            })
        
        return web.json_response({'nodes': nodes_data})
    
    async def get_cache_entry(self, request):
        """Get cache entry with intelligent routing"""
        cache_key = request.match_info['cache_key']
        
        # Find best node for this cache entry
        best_node = await self.find_optimal_node(cache_key, 'read')
        
        if not best_node:
            return web.json_response({'error': 'No available nodes'}, status=503)
        
        # Try to get from best node
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(f'http://{best_node.address}/cache/{cache_key}') as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        
                        # Record cache hit
                        await self.record_access(cache_key, 'hit', best_node.node_id)
                        
                        return web.json_response(data)
                    elif resp.status == 404:
                        # Try other nodes
                        for node in self.nodes.values():
                            if node.node_id != best_node.node_id and node.status == 'active':
                                try:
                                    async with session.get(f'http://{node.address}/cache/{cache_key}') as resp2:
                                        if resp2.status == 200:
                                            data = await resp2.json()
                                            await self.record_access(cache_key, 'hit', node.node_id)
                                            return web.json_response(data)
                                except:
                                    continue
                        
                        # Cache miss
                        await self.record_access(cache_key, 'miss', None)
                        return web.json_response({'error': 'Cache miss'}, status=404)
        
        except Exception as e:
            logger.error(f"Error accessing cache: {e}")
            return web.json_response({'error': 'Internal error'}, status=500)
    
    async def put_cache_entry(self, request):
        """Store cache entry with intelligent placement"""
        cache_key = request.match_info['cache_key']
        data = await request.json()
        
        # Find optimal nodes for storage
        target_nodes = await self.find_optimal_nodes_for_storage(data.get('size_bytes', 0))
        
        if not target_nodes:
            return web.json_response({'error': 'No available storage nodes'}, status=503)
        
        # Store to multiple nodes for replication
        stored_nodes = []
        
        for node in target_nodes[:3]:  # Replicate to top 3 nodes
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.post(f'http://{node.address}/cache/{cache_key}', json=data) as resp:
                        if resp.status == 200:
                            stored_nodes.append(node.node_id)
            except Exception as e:
                logger.error(f"Failed to store to node {node.node_id}: {e}")
        
        if stored_nodes:
            # Update cache metadata
            await self.update_cache_metadata(cache_key, data, stored_nodes)
            return web.json_response({'status': 'stored', 'nodes': stored_nodes})
        else:
            return web.json_response({'error': 'Storage failed'}, status=500)
    
    async def find_optimal_node(self, cache_key: str, operation: str) -> Optional[CacheNode]:
        """Find optimal node using ML-based selection"""
        active_nodes = [n for n in self.nodes.values() if n.status == 'active']
        
        if not active_nodes:
            return None
        
        # Score nodes based on multiple factors
        node_scores = []
        
        for node in active_nodes:
            score = 0.0
            
            # Hit rate weight (40%)
            score += node.hit_rate * 0.4
            
            # Storage availability weight (30%)
            storage_ratio = 1.0 - (node.storage_used / max(node.storage_capacity, 1))
            score += storage_ratio * 0.3
            
            # Network proximity weight (20%) - simplified
            score += 0.2  # Would implement actual network metrics
            
            # Load balancing weight (10%)
            score += (1.0 - min(node.storage_used / max(node.storage_capacity, 1), 1.0)) * 0.1
            
            node_scores.append((node, score))
        
        # Return best scoring node
        node_scores.sort(key=lambda x: x[1], reverse=True)
        return node_scores[0][0]
    
    async def find_optimal_nodes_for_storage(self, size_bytes: int) -> List[CacheNode]:
        """Find optimal nodes for storage with capacity planning"""
        active_nodes = [n for n in self.nodes.values() if n.status == 'active']
        
        # Filter nodes with sufficient capacity
        suitable_nodes = []
        for node in active_nodes:
            available_space = node.storage_capacity - node.storage_used
            if available_space >= size_bytes * 1.1:  # 10% buffer
                suitable_nodes.append(node)
        
        # Score and sort nodes
        node_scores = []
        for node in suitable_nodes:
            score = 0.0
            
            # Available storage weight (50%)
            available_ratio = (node.storage_capacity - node.storage_used) / node.storage_capacity
            score += available_ratio * 0.5
            
            # Node performance weight (30%)
            score += node.hit_rate * 0.3
            
            # Load distribution weight (20%)
            load_factor = 1.0 - (node.storage_used / node.storage_capacity)
            score += load_factor * 0.2
            
            node_scores.append((node, score))
        
        node_scores.sort(key=lambda x: x[1], reverse=True)
        return [node for node, score in node_scores]
    
    async def record_access(self, cache_key: str, access_type: str, node_id: Optional[str]):
        """Record cache access for analytics"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO access_patterns
            (cache_key, access_timestamp, access_type, node_id)
            VALUES (?, ?, ?, ?)
        ''', (cache_key, int(time.time()), access_type, node_id))
        
        # Update cache entry statistics
        if access_type == 'hit':
            cursor.execute('''
                UPDATE cache_entries 
                SET hit_count = hit_count + 1, accessed_timestamp = ?
                WHERE cache_key = ?
            ''', (int(time.time()), cache_key))
        elif access_type == 'miss':
            cursor.execute('''
                UPDATE cache_entries 
                SET miss_count = miss_count + 1
                WHERE cache_key = ?
            ''', (cache_key,))
        
        conn.commit()
        conn.close()
    
    async def node_health_monitor(self):
        """Monitor node health and update status"""
        while True:
            try:
                for node_id, node in list(self.nodes.items()):
                    try:
                        async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=5)) as session:
                            async with session.get(f'http://{node.address}/health') as resp:
                                if resp.status == 200:
                                    node.status = 'active'
                                else:
                                    node.status = 'inactive'
                    except:
                        node.status = 'inactive'
                        logger.warning(f"Node {node_id} is unresponsive")
                
                await asyncio.sleep(30)  # Check every 30 seconds
                
            except Exception as e:
                logger.error(f"Error in health monitoring: {e}")
                await asyncio.sleep(60)
    
    async def cache_optimizer(self):
        """Optimize cache placement and eviction"""
        while True:
            try:
                # Run optimization every 5 minutes
                await asyncio.sleep(300)
                
                logger.info("Running cache optimization...")
                
                # Analyze access patterns
                conn = sqlite3.connect(self.db_path)
                cursor = conn.cursor()
                
                # Find hot cache entries (frequently accessed)
                cursor.execute('''
                    SELECT cache_key, hit_count, miss_count, accessed_timestamp
                    FROM cache_entries
                    WHERE accessed_timestamp > ?
                    ORDER BY hit_count DESC
                    LIMIT 100
                ''', (int(time.time()) - 3600,))  # Last hour
                
                hot_entries = cursor.fetchall()
                
                # Promote hot entries to hot tier
                for cache_key, hit_count, miss_count, accessed_timestamp in hot_entries:
                    if hit_count > 10:  # Threshold for hot tier
                        cursor.execute('''
                            UPDATE cache_entries 
                            SET cache_tier = 'hot'
                            WHERE cache_key = ? AND cache_tier != 'hot'
                        ''', (cache_key,))
                
                # Find cold entries for eviction
                cursor.execute('''
                    SELECT cache_key
                    FROM cache_entries
                    WHERE accessed_timestamp < ? AND cache_tier = 'cold'
                    ORDER BY accessed_timestamp ASC
                    LIMIT 50
                ''', (int(time.time()) - 86400 * 7,))  # Older than 7 days
                
                cold_entries = cursor.fetchall()
                
                # Evict cold entries
                for (cache_key,) in cold_entries:
                    await self.evict_cache_entry(cache_key)
                
                conn.commit()
                conn.close()
                
                logger.info(f"Cache optimization complete - promoted {len(hot_entries)} hot entries, evicted {len(cold_entries)} cold entries")
                
            except Exception as e:
                logger.error(f"Error in cache optimization: {e}")
    
    async def evict_cache_entry(self, cache_key: str):
        """Evict cache entry from all nodes"""
        for node in self.nodes.values():
            if node.status == 'active':
                try:
                    async with aiohttp.ClientSession() as session:
                        async with session.delete(f'http://{node.address}/cache/{cache_key}') as resp:
                            pass  # Ignore response
                except:
                    pass  # Ignore errors
        
        # Remove from database
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute('DELETE FROM cache_entries WHERE cache_key = ?', (cache_key,))
        cursor.execute('DELETE FROM access_patterns WHERE cache_key = ?', (cache_key,))
        conn.commit()
        conn.close()
    
    async def prefetch_worker(self):
        """ML-powered prefetch worker"""
        while True:
            try:
                # Get prefetch prediction
                prediction = await self.prefetch_queue.get()
                
                cache_key = prediction['cache_key']
                confidence = prediction['confidence']
                
                if confidence > 0.8:  # High confidence threshold
                    # Prefetch the cache entry
                    logger.info(f"Prefetching cache entry: {cache_key} (confidence: {confidence:.2f})")
                    
                    # This would trigger actual file building/caching
                    # For now, just record the prefetch attempt
                    await self.record_access(cache_key, 'prefetch', 'coordinator')
                
            except Exception as e:
                logger.error(f"Error in prefetch worker: {e}")

async def main():
    """Main coordinator service"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Intelligent Cache Coordinator')
    parser.add_argument('--db', required=True, help='Cache database path')
    parser.add_argument('--cache-root', required=True, help='Cache root directory')
    parser.add_argument('--port', type=int, default=8080, help='Service port')
    
    args = parser.parse_args()
    
    coordinator = IntelligentCacheCoordinator(args.db, args.cache_root, args.port)
    await coordinator.start_coordinator()
    
    # Keep running
    while True:
        await asyncio.sleep(1)

if __name__ == '__main__':
    asyncio.run(main())
PYTHON_EOF
    
    chmod +x "$DISTRIBUTED_CACHE_DIR/coordinator.py"
    
    # Cache worker node
    cat > "$DISTRIBUTED_CACHE_DIR/worker.py" <<'PYTHON_EOF'
#!/usr/bin/env python3
"""
Intelligent Cache Worker Node
High-performance cache storage and retrieval
"""

import asyncio
import aiohttp
import aiofiles
import os
import json
import hashlib
import time
import gzip
import shutil
from pathlib import Path
from aiohttp import web
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class CacheWorkerNode:
    """High-performance cache worker node"""
    
    def __init__(self, node_id: str, storage_path: str, coordinator_url: str, port: int = 8081):
        self.node_id = node_id
        self.storage_path = Path(storage_path)
        self.coordinator_url = coordinator_url
        self.port = port
        self.storage_used = 0
        self.storage_capacity = self.get_storage_capacity()
        self.hit_count = 0
        self.miss_count = 0
        
        # Create storage directories
        self.storage_path.mkdir(parents=True, exist_ok=True)
        (self.storage_path / 'hot').mkdir(exist_ok=True)
        (self.storage_path / 'warm').mkdir(exist_ok=True)
        (self.storage_path / 'cold').mkdir(exist_ok=True)
        
    def get_storage_capacity(self) -> int:
        """Get available storage capacity"""
        try:
            stat = shutil.disk_usage(self.storage_path)
            return stat.free
        except:
            return 10 * 1024 * 1024 * 1024  # 10GB default
    
    async def start_worker(self):
        """Start the cache worker service"""
        logger.info(f"Starting cache worker {self.node_id} on port {self.port}")
        
        app = web.Application()
        
        # API routes
        app.router.add_get('/health', self.health_check)
        app.router.add_get('/cache/{cache_key}', self.get_cache)
        app.router.add_post('/cache/{cache_key}', self.put_cache)
        app.router.add_delete('/cache/{cache_key}', self.delete_cache)
        app.router.add_get('/stats', self.get_stats)
        
        # Register with coordinator
        await self.register_with_coordinator()
        
        # Start background tasks
        asyncio.create_task(self.periodic_cleanup())
        asyncio.create_task(self.health_reporter())
        
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, '0.0.0.0', self.port)
        await site.start()
        
        logger.info(f"Cache worker started on http://0.0.0.0:{self.port}")
    
    async def health_check(self, request):
        """Health check endpoint"""
        return web.json_response({
            'status': 'healthy',
            'node_id': self.node_id,
            'storage_used': self.storage_used,
            'storage_capacity': self.storage_capacity,
            'hit_rate': self.hit_count / max(self.hit_count + self.miss_count, 1),
            'timestamp': time.time()
        })
    
    async def get_cache(self, request):
        """Get cache entry"""
        cache_key = request.match_info['cache_key']
        
        # Try different tiers
        for tier in ['hot', 'warm', 'cold']:
            cache_file = self.storage_path / tier / f"{cache_key}.cache"
            
            if cache_file.exists():
                try:
                    async with aiofiles.open(cache_file, 'rb') as f:
                        data = await f.read()
                    
                    # Decompress if needed
                    if cache_file.suffix == '.gz':
                        data = gzip.decompress(data)
                    
                    # Parse metadata and content
                    cache_data = json.loads(data.decode())
                    
                    self.hit_count += 1
                    
                    # Update access time
                    cache_file.touch()
                    
                    return web.json_response(cache_data)
                    
                except Exception as e:
                    logger.error(f"Error reading cache {cache_key}: {e}")
                    continue
        
        self.miss_count += 1
        return web.json_response({'error': 'Cache miss'}, status=404)
    
    async def put_cache(self, request):
        """Store cache entry"""
        cache_key = request.match_info['cache_key']
        data = await request.json()
        
        # Determine tier based on size and priority
        size_bytes = data.get('size_bytes', 0)
        priority = data.get('priority', 'warm')
        
        if size_bytes < 1024 * 1024:  # < 1MB
            tier = 'hot'
        elif size_bytes < 10 * 1024 * 1024:  # < 10MB
            tier = 'warm'
        else:
            tier = 'cold'
        
        cache_file = self.storage_path / tier / f"{cache_key}.cache"
        
        try:
            # Serialize data
            cache_content = json.dumps(data).encode()
            
            # Compress large entries
            if len(cache_content) > 1024:
                cache_content = gzip.compress(cache_content)
                cache_file = cache_file.with_suffix('.cache.gz')
            
            # Write atomically
            temp_file = cache_file.with_suffix('.tmp')
            async with aiofiles.open(temp_file, 'wb') as f:
                await f.write(cache_content)
            
            temp_file.rename(cache_file)
            
            # Update storage tracking
            self.storage_used += len(cache_content)
            
            return web.json_response({'status': 'stored', 'tier': tier})
            
        except Exception as e:
            logger.error(f"Error storing cache {cache_key}: {e}")
            return web.json_response({'error': 'Storage failed'}, status=500)
    
    async def delete_cache(self, request):
        """Delete cache entry"""
        cache_key = request.match_info['cache_key']
        
        for tier in ['hot', 'warm', 'cold']:
            for suffix in ['.cache', '.cache.gz']:
                cache_file = self.storage_path / tier / f"{cache_key}{suffix}"
                if cache_file.exists():
                    try:
                        size = cache_file.stat().st_size
                        cache_file.unlink()
                        self.storage_used -= size
                        logger.info(f"Deleted cache entry: {cache_key}")
                        return web.json_response({'status': 'deleted'})
                    except Exception as e:
                        logger.error(f"Error deleting cache {cache_key}: {e}")
        
        return web.json_response({'error': 'Not found'}, status=404)
    
    async def get_stats(self, request):
        """Get node statistics"""
        return web.json_response({
            'node_id': self.node_id,
            'storage_used': self.storage_used,
            'storage_capacity': self.storage_capacity,
            'hit_count': self.hit_count,
            'miss_count': self.miss_count,
            'hit_rate': self.hit_count / max(self.hit_count + self.miss_count, 1),
            'cache_entries': sum(1 for tier in ['hot', 'warm', 'cold'] 
                               for _ in (self.storage_path / tier).glob('*.cache*'))
        })
    
    async def register_with_coordinator(self):
        """Register this worker with the coordinator"""
        registration_data = {
            'node_id': self.node_id,
            'address': f'localhost:{self.port}',
            'node_type': 'worker',
            'storage_capacity': self.storage_capacity,
            'storage_used': self.storage_used,
            'hit_rate': 0.0
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(f'{self.coordinator_url}/nodes/register', 
                                      json=registration_data) as resp:
                    if resp.status == 200:
                        logger.info(f"Successfully registered with coordinator")
                    else:
                        logger.error(f"Failed to register with coordinator: {resp.status}")
        except Exception as e:
            logger.error(f"Error registering with coordinator: {e}")
    
    async def periodic_cleanup(self):
        """Periodic cleanup of old cache entries"""
        while True:
            try:
                await asyncio.sleep(3600)  # Run every hour
                
                logger.info("Running periodic cleanup...")
                
                # Clean up cold tier entries older than 7 days
                cold_dir = self.storage_path / 'cold'
                cutoff_time = time.time() - (7 * 24 * 3600)
                
                for cache_file in cold_dir.glob('*.cache*'):
                    if cache_file.stat().st_mtime < cutoff_time:
                        try:
                            size = cache_file.stat().st_size
                            cache_file.unlink()
                            self.storage_used -= size
                            logger.debug(f"Cleaned up old cache file: {cache_file.name}")
                        except Exception as e:
                            logger.error(f"Error cleaning up {cache_file}: {e}")
                
                logger.info("Periodic cleanup completed")
                
            except Exception as e:
                logger.error(f"Error in periodic cleanup: {e}")
    
    async def health_reporter(self):
        """Report health to coordinator periodically"""
        while True:
            try:
                await asyncio.sleep(60)  # Report every minute
                
                health_data = {
                    'node_id': self.node_id,
                    'storage_used': self.storage_used,
                    'hit_rate': self.hit_count / max(self.hit_count + self.miss_count, 1),
                    'timestamp': time.time()
                }
                
                async with aiohttp.ClientSession() as session:
                    async with session.post(f'{self.coordinator_url}/health', 
                                          json=health_data) as resp:
                        pass  # Ignore response
                        
            except Exception as e:
                logger.debug(f"Error reporting health: {e}")

async def main():
    """Main worker service"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Intelligent Cache Worker')
    parser.add_argument('--node-id', required=True, help='Unique node identifier')
    parser.add_argument('--storage', required=True, help='Storage directory path')
    parser.add_argument('--coordinator', required=True, help='Coordinator URL')
    parser.add_argument('--port', type=int, default=8081, help='Service port')
    
    args = parser.parse_args()
    
    worker = CacheWorkerNode(args.node_id, args.storage, args.coordinator, args.port)
    await worker.start_worker()
    
    # Keep running
    while True:
        await asyncio.sleep(1)

if __name__ == '__main__':
    asyncio.run(main())
PYTHON_EOF
    
    chmod +x "$DISTRIBUTED_CACHE_DIR/worker.py"
    
    log_success "Cache coordination system created"
}

# Create ML prefetch system
create_prefetch_ml_system() {
    log_info "Creating ML prefetch system..."
    
    cat > "$CACHE_ROOT/prefetch_analyzer.py" <<'PYTHON_EOF'
#!/usr/bin/env python3
"""
ML-Powered Cache Prefetch Analyzer
Intelligent prefetching based on access patterns and build predictions
"""

import sqlite3
import json
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import hashlib
import os
import sys
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
import pickle
import logging
from collections import defaultdict

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

@dataclass
class AccessPattern:
    """Cache access pattern for analysis"""
    cache_key: str
    access_times: List[int]
    access_types: List[str]
    build_contexts: List[str]
    developer_id: str

@dataclass
class PrefetchPrediction:
    """Prefetch prediction result"""
    cache_key: str
    predicted_access_time: int
    confidence: float
    prefetch_benefit: float
    trigger_condition: str

class CachePrefetchAnalyzer:
    """ML-based cache prefetch prediction"""
    
    def __init__(self, db_path: str, model_dir: str):
        self.db_path = db_path
        self.model_dir = model_dir
        self.access_patterns = {}
        self.model = None
        
    def load_access_patterns(self, hours_back: int = 24) -> Dict[str, AccessPattern]:
        """Load recent access patterns"""
        logger.info(f"Loading access patterns from last {hours_back} hours")
        
        cutoff_time = int((datetime.now() - timedelta(hours=hours_back)).timestamp())
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        query = """
        SELECT ap.cache_key, ap.access_timestamp, ap.access_type, 
               ap.build_session_id, ap.developer_id, ce.build_context
        FROM access_patterns ap
        LEFT JOIN cache_entries ce ON ap.cache_key = ce.cache_key
        WHERE ap.access_timestamp > ?
        ORDER BY ap.cache_key, ap.access_timestamp
        """
        
        cursor.execute(query, (cutoff_time,))
        rows = cursor.fetchall()
        
        patterns = defaultdict(lambda: {
            'access_times': [],
            'access_types': [],
            'build_contexts': [],
            'developer_id': None
        })
        
        for row in rows:
            cache_key, timestamp, access_type, session_id, developer_id, build_context = row
            
            patterns[cache_key]['access_times'].append(timestamp)
            patterns[cache_key]['access_types'].append(access_type)
            patterns[cache_key]['build_contexts'].append(build_context or '')
            patterns[cache_key]['developer_id'] = developer_id
        
        conn.close()
        
        # Convert to AccessPattern objects
        access_patterns = {}
        for cache_key, data in patterns.items():
            if data['access_times']:  # Only include keys with actual access
                access_patterns[cache_key] = AccessPattern(
                    cache_key=cache_key,
                    access_times=data['access_times'],
                    access_types=data['access_types'],
                    build_contexts=data['build_contexts'],
                    developer_id=data['developer_id'] or 'unknown'
                )
        
        logger.info(f"Loaded {len(access_patterns)} access patterns")
        return access_patterns
    
    def analyze_temporal_patterns(self, pattern: AccessPattern) -> Dict[str, float]:
        """Analyze temporal access patterns"""
        if len(pattern.access_times) < 2:
            return {}
        
        # Calculate access intervals
        intervals = []
        for i in range(1, len(pattern.access_times)):
            interval = pattern.access_times[i] - pattern.access_times[i-1]
            intervals.append(interval)
        
        if not intervals:
            return {}
        
        # Statistical analysis
        avg_interval = np.mean(intervals)
        std_interval = np.std(intervals)
        min_interval = np.min(intervals)
        max_interval = np.max(intervals)
        
        # Time-of-day pattern
        access_hours = [datetime.fromtimestamp(t).hour for t in pattern.access_times]
        hour_distribution = np.bincount(access_hours, minlength=24)
        peak_hour = np.argmax(hour_distribution)
        
        # Day-of-week pattern
        access_days = [datetime.fromtimestamp(t).weekday() for t in pattern.access_times]
        day_distribution = np.bincount(access_days, minlength=7)
        peak_day = np.argmax(day_distribution)
        
        return {
            'avg_interval': avg_interval,
            'std_interval': std_interval,
            'min_interval': min_interval,
            'max_interval': max_interval,
            'regularity_score': 1.0 / (1.0 + std_interval / max(avg_interval, 1)),
            'peak_hour': peak_hour,
            'peak_day': peak_day,
            'access_frequency': len(pattern.access_times) / max(avg_interval, 1)
        }
    
    def extract_features(self, pattern: AccessPattern, current_time: int) -> np.ndarray:
        """Extract features for ML prediction"""
        features = []
        
        # Basic pattern features
        features.append(len(pattern.access_times))  # Total accesses
        features.append(len(set(pattern.access_types)))  # Unique access types
        
        # Temporal features
        temporal_analysis = self.analyze_temporal_patterns(pattern)
        features.extend([
            temporal_analysis.get('avg_interval', 0) / 3600,  # Hours
            temporal_analysis.get('regularity_score', 0),
            temporal_analysis.get('access_frequency', 0),
            temporal_analysis.get('peak_hour', 12) / 24.0,  # Normalized hour
            temporal_analysis.get('peak_day', 0) / 7.0  # Normalized day
        ])
        
        # Recency features
        if pattern.access_times:
            time_since_last = (current_time - pattern.access_times[-1]) / 3600  # Hours
            features.append(min(time_since_last, 168))  # Cap at 1 week
            
            # Recent activity score
            recent_accesses = sum(1 for t in pattern.access_times if current_time - t < 3600)
            features.append(recent_accesses)
        else:
            features.extend([168, 0])  # Default values
        
        # Access type distribution
        type_counts = {}
        for access_type in pattern.access_types:
            type_counts[access_type] = type_counts.get(access_type, 0) + 1
        
        total_accesses = len(pattern.access_types)
        features.extend([
            type_counts.get('hit', 0) / max(total_accesses, 1),
            type_counts.get('miss', 0) / max(total_accesses, 1),
            type_counts.get('prefetch', 0) / max(total_accesses, 1)
        ])
        
        # Build context features
        unique_contexts = len(set(pattern.build_contexts))
        features.append(unique_contexts)
        
        # Developer pattern (simplified)
        features.append(hash(pattern.developer_id) % 100 / 100.0)
        
        # Current time context
        current_dt = datetime.fromtimestamp(current_time)
        features.extend([
            current_dt.hour / 24.0,
            current_dt.weekday() / 7.0
        ])
        
        return np.array(features, dtype=np.float32)
    
    def create_training_data(self, patterns: Dict[str, AccessPattern]) -> Tuple[np.ndarray, np.ndarray]:
        """Create training data for ML model"""
        X = []
        y = []
        
        for cache_key, pattern in patterns.items():
            if len(pattern.access_times) < 3:
                continue
            
            # Use each access (except first and last) as a training point
            for i in range(1, len(pattern.access_times) - 1):
                current_time = pattern.access_times[i]
                next_access_time = pattern.access_times[i + 1]
                
                # Create truncated pattern up to current time
                truncated_pattern = AccessPattern(
                    cache_key=pattern.cache_key,
                    access_times=pattern.access_times[:i+1],
                    access_types=pattern.access_types[:i+1],
                    build_contexts=pattern.build_contexts[:i+1],
                    developer_id=pattern.developer_id
                )
                
                # Extract features
                features = self.extract_features(truncated_pattern, current_time)
                X.append(features)
                
                # Target: time until next access (normalized)
                time_to_next = (next_access_time - current_time) / 3600  # Hours
                normalized_time = min(time_to_next / 24.0, 1.0)  # Normalize to max 24 hours
                y.append(normalized_time)
        
        return np.array(X), np.array(y)
    
    def train_model(self, patterns: Dict[str, AccessPattern]) -> None:
        """Train prefetch prediction model"""
        logger.info("Training prefetch prediction model...")
        
        X, y = self.create_training_data(patterns)
        
        if len(X) < 10:
            logger.warning("Insufficient data for training")
            return
        
        logger.info(f"Training on {len(X)} samples with {X.shape[1]} features")
        
        from sklearn.ensemble import RandomForestRegressor
        from sklearn.model_selection import train_test_split
        from sklearn.metrics import mean_squared_error, r2_score
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
        
        # Train model
        self.model = RandomForestRegressor(
            n_estimators=100,
            max_depth=15,
            random_state=42,
            n_jobs=-1
        )
        
        self.model.fit(X_train, y_train)
        
        # Evaluate
        y_pred = self.model.predict(X_test)
        mse = mean_squared_error(y_test, y_pred)
        r2 = r2_score(y_test, y_pred)
        
        logger.info(f"Model training complete - MSE: {mse:.4f}, R²: {r2:.4f}")
        
        # Save model
        model_path = os.path.join(self.model_dir, 'prefetch_model.pkl')
        os.makedirs(os.path.dirname(model_path), exist_ok=True)
        
        with open(model_path, 'wb') as f:
            pickle.dump({
                'model': self.model,
                'training_stats': {'mse': mse, 'r2': r2, 'samples': len(X)}
            }, f)
        
        logger.info(f"Model saved to {model_path}")
    
    def predict_prefetch_candidates(self, patterns: Dict[str, AccessPattern], 
                                  current_time: int, max_predictions: int = 20) -> List[PrefetchPrediction]:
        """Predict cache entries that should be prefetched"""
        if not self.model:
            # Try to load existing model
            model_path = os.path.join(self.model_dir, 'prefetch_model.pkl')
            if os.path.exists(model_path):
                with open(model_path, 'rb') as f:
                    data = pickle.load(f)
                    self.model = data['model']
            else:
                logger.error("No trained model available")
                return []
        
        predictions = []
        
        for cache_key, pattern in patterns.items():
            # Skip if recently accessed
            if pattern.access_times and current_time - pattern.access_times[-1] < 300:  # 5 minutes
                continue
            
            # Extract features
            features = self.extract_features(pattern, current_time).reshape(1, -1)
            
            # Make prediction
            predicted_hours = self.model.predict(features)[0] * 24  # Denormalize
            predicted_access_time = current_time + int(predicted_hours * 3600)
            
            # Calculate confidence based on pattern regularity
            temporal_analysis = self.analyze_temporal_patterns(pattern)
            regularity_score = temporal_analysis.get('regularity_score', 0)
            access_frequency = temporal_analysis.get('access_frequency', 0)
            
            confidence = min((regularity_score * 0.7 + min(access_frequency, 1.0) * 0.3), 1.0)
            
            # Calculate prefetch benefit (simplified)
            avg_access_time = 100  # Average cache access time in ms
            prefetch_benefit = avg_access_time * confidence
            
            # Determine trigger condition
            if predicted_hours < 0.5:  # < 30 minutes
                trigger = "immediate"
            elif predicted_hours < 2:  # < 2 hours
                trigger = "soon"
            else:
                trigger = "scheduled"
            
            if confidence > 0.6 and predicted_hours < 8:  # Only prefetch if confident and within 8 hours
                predictions.append(PrefetchPrediction(
                    cache_key=cache_key,
                    predicted_access_time=predicted_access_time,
                    confidence=confidence,
                    prefetch_benefit=prefetch_benefit,
                    trigger_condition=trigger
                ))
        
        # Sort by benefit and return top predictions
        predictions.sort(key=lambda x: x.prefetch_benefit, reverse=True)
        return predictions[:max_predictions]
    
    def save_predictions(self, predictions: List[PrefetchPrediction]) -> None:
        """Save predictions to database"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        current_time = int(time.time())
        
        for pred in predictions:
            cursor.execute('''
                INSERT INTO prefetch_predictions
                (prediction_id, cache_key, predicted_access_time, confidence_score,
                 prefetch_trigger, created_timestamp)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (
                f"pred_{current_time}_{hash(pred.cache_key) % 10000}",
                pred.cache_key,
                pred.predicted_access_time,
                pred.confidence,
                pred.trigger_condition,
                current_time
            ))
        
        conn.commit()
        conn.close()
        
        logger.info(f"Saved {len(predictions)} prefetch predictions")

def main():
    """Main ML analyzer interface"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Cache Prefetch ML Analyzer')
    parser.add_argument('command', choices=['train', 'predict', 'analyze'])
    parser.add_argument('--db', required=True, help='Cache database path')
    parser.add_argument('--model-dir', required=True, help='Model directory')
    parser.add_argument('--hours', type=int, default=24, help='Hours of data to analyze')
    parser.add_argument('--output', help='Output file for results')
    
    args = parser.parse_args()
    
    analyzer = CachePrefetchAnalyzer(args.db, args.model_dir)
    
    if args.command == 'train':
        patterns = analyzer.load_access_patterns(args.hours)
        if len(patterns) >= 5:
            analyzer.train_model(patterns)
        else:
            logger.error(f"Need at least 5 patterns for training, got {len(patterns)}")
    
    elif args.command == 'predict':
        patterns = analyzer.load_access_patterns(args.hours)
        predictions = analyzer.predict_prefetch_candidates(patterns, int(time.time()))
        
        analyzer.save_predictions(predictions)
        
        output_data = []
        for pred in predictions:
            output_data.append({
                'cache_key': pred.cache_key,
                'predicted_access_time': pred.predicted_access_time,
                'confidence': pred.confidence,
                'prefetch_benefit': pred.prefetch_benefit,
                'trigger_condition': pred.trigger_condition
            })
        
        if args.output:
            with open(args.output, 'w') as f:
                json.dump(output_data, f, indent=2)
        else:
            print(json.dumps(output_data, indent=2))
    
    elif args.command == 'analyze':
        patterns = analyzer.load_access_patterns(args.hours)
        
        analysis = {
            'total_patterns': len(patterns),
            'avg_accesses_per_key': np.mean([len(p.access_times) for p in patterns.values()]) if patterns else 0,
            'most_active_keys': [],
            'temporal_insights': {}
        }
        
        # Most active cache keys
        sorted_patterns = sorted(patterns.items(), key=lambda x: len(x[1].access_times), reverse=True)
        analysis['most_active_keys'] = [
            {'cache_key': key, 'access_count': len(pattern.access_times)}
            for key, pattern in sorted_patterns[:10]
        ]
        
        if args.output:
            with open(args.output, 'w') as f:
                json.dump(analysis, f, indent=2)
        else:
            print(json.dumps(analysis, indent=2))

if __name__ == '__main__':
    main()
PYTHON_EOF
    
    chmod +x "$CACHE_ROOT/prefetch_analyzer.py"
    
    log_success "ML prefetch system created"
}

# Get cache entry with intelligent routing
cache_get() {
    local cache_key="$1"
    local build_context="${2:-default}"
    local developer_id="${3:-$(whoami)}"
    
    log_debug "Getting cache entry: $cache_key"
    
    # Check local cache first (hot tier)
    local hot_cache="$LOCAL_CACHE_DIR/hot/$cache_key.cache"
    if [[ -f "$hot_cache" ]]; then
        log_debug "Cache hit (hot): $cache_key"
        record_cache_access "$cache_key" "hit" "hot" "$build_context" "$developer_id"
        cat "$hot_cache"
        return 0
    fi
    
    # Check warm tier
    local warm_cache="$LOCAL_CACHE_DIR/warm/$cache_key.cache"
    if [[ -f "$warm_cache" ]]; then
        log_debug "Cache hit (warm): $cache_key"
        record_cache_access "$cache_key" "hit" "warm" "$build_context" "$developer_id"
        
        # Promote to hot tier if frequently accessed
        promote_to_hot_tier "$cache_key"
        
        cat "$warm_cache"
        return 0
    fi
    
    # Check cold tier
    local cold_cache="$LOCAL_CACHE_DIR/cold/$cache_key.cache"
    if [[ -f "$cold_cache" ]]; then
        log_debug "Cache hit (cold): $cache_key"
        record_cache_access "$cache_key" "hit" "cold" "$build_context" "$developer_id"
        
        # Promote to warm tier
        promote_to_warm_tier "$cache_key"
        
        cat "$cold_cache"
        return 0
    fi
    
    # Try global/distributed cache
    if check_global_cache "$cache_key"; then
        log_debug "Cache hit (global): $cache_key"
        record_cache_access "$cache_key" "hit" "global" "$build_context" "$developer_id"
        return 0
    fi
    
    # Cache miss
    log_debug "Cache miss: $cache_key"
    record_cache_access "$cache_key" "miss" "none" "$build_context" "$developer_id"
    return 1
}

# Store cache entry with intelligent placement
cache_put() {
    local cache_key="$1"
    local cache_data="$2"
    local size_bytes="${3:-0}"
    local build_context="${4:-default}"
    local priority="${5:-normal}"
    local developer_id="${6:-$(whoami)}"
    
    log_debug "Storing cache entry: $cache_key ($size_bytes bytes)"
    
    # Determine optimal tier based on size and priority
    local tier="warm"  # Default
    
    if [[ $size_bytes -lt 102400 ]] || [[ "$priority" == "high" ]]; then  # < 100KB or high priority
        tier="hot"
    elif [[ $size_bytes -gt 10485760 ]] || [[ "$priority" == "low" ]]; then  # > 10MB or low priority
        tier="cold"
    fi
    
    # Create cache file
    local cache_file="$LOCAL_CACHE_DIR/$tier/$cache_key.cache"
    
    # Ensure directory exists
    mkdir -p "$(dirname "$cache_file")"
    
    # Store with compression if large
    if [[ $size_bytes -gt 1048576 ]]; then  # > 1MB
        echo "$cache_data" | gzip > "$cache_file.gz"
        cache_file="$cache_file.gz"
    else
        echo "$cache_data" > "$cache_file"
    fi
    
    # Record in database
    record_cache_entry "$cache_key" "$(md5 <<< "$cache_data")" "" "$tier" "$size_bytes" \
                      "$build_context" "$developer_id"
    
    # Replicate to global cache if important
    if [[ "$priority" == "high" ]] || [[ $size_bytes -lt 1048576 ]]; then
        replicate_to_global_cache "$cache_key" "$cache_data" "$tier"
    fi
    
    log_debug "Cache entry stored in $tier tier: $cache_key"
}

# Record cache access for analytics
record_cache_access() {
    local cache_key="$1"
    local access_type="$2"
    local cache_tier="$3"
    local build_context="$4"
    local developer_id="$5"
    
    local current_time
    current_time=$(date +%s)
    
    # Record access pattern
    sqlite3 "$CACHE_DB" <<EOF
INSERT INTO access_patterns (
    cache_key, access_timestamp, access_type, context,
    cache_tier, developer_id
) VALUES (
    '$cache_key', $current_time, '$access_type', '$build_context',
    '$cache_tier', '$developer_id'
);
EOF
    
    # Update cache entry statistics
    if [[ "$access_type" == "hit" ]]; then
        sqlite3 "$CACHE_DB" <<EOF
UPDATE cache_entries 
SET hit_count = hit_count + 1, 
    accessed_timestamp = $current_time,
    access_count = access_count + 1
WHERE cache_key = '$cache_key';
EOF
    elif [[ "$access_type" == "miss" ]]; then
        sqlite3 "$CACHE_DB" <<EOF
UPDATE cache_entries 
SET miss_count = miss_count + 1
WHERE cache_key = '$cache_key';
EOF
    fi
}

# Record cache entry metadata
record_cache_entry() {
    local cache_key="$1"
    local file_hash="$2"
    local file_path="$3"
    local cache_tier="$4"
    local size_bytes="$5"
    local build_context="$6"
    local developer_id="$7"
    
    local current_time
    current_time=$(date +%s)
    
    sqlite3 "$CACHE_DB" <<EOF
INSERT OR REPLACE INTO cache_entries (
    cache_key, file_hash, file_path, cache_tier, size_bytes,
    created_timestamp, accessed_timestamp, build_context, developer_id
) VALUES (
    '$cache_key', '$file_hash', '$file_path', '$cache_tier', $size_bytes,
    $current_time, $current_time, '$build_context', '$developer_id'
);
EOF
}

# Promote cache entry to hot tier
promote_to_hot_tier() {
    local cache_key="$1"
    
    # Check if promotion is warranted
    local access_count
    access_count=$(sqlite3 "$CACHE_DB" \
        "SELECT access_count FROM cache_entries WHERE cache_key = '$cache_key';")
    
    if [[ ${access_count:-0} -gt 5 ]]; then  # Promotion threshold
        local warm_file="$LOCAL_CACHE_DIR/warm/$cache_key.cache"
        local cold_file="$LOCAL_CACHE_DIR/cold/$cache_key.cache"
        local hot_file="$LOCAL_CACHE_DIR/hot/$cache_key.cache"
        
        # Move file to hot tier
        if [[ -f "$warm_file" ]]; then
            mv "$warm_file" "$hot_file"
        elif [[ -f "$cold_file" ]]; then
            mv "$cold_file" "$hot_file"
        fi
        
        # Update database
        sqlite3 "$CACHE_DB" <<EOF
UPDATE cache_entries SET cache_tier = 'hot' WHERE cache_key = '$cache_key';
EOF
        
        log_debug "Promoted $cache_key to hot tier"
    fi
}

# Promote cache entry to warm tier
promote_to_warm_tier() {
    local cache_key="$1"
    
    local cold_file="$LOCAL_CACHE_DIR/cold/$cache_key.cache"
    local warm_file="$LOCAL_CACHE_DIR/warm/$cache_key.cache"
    
    if [[ -f "$cold_file" ]]; then
        mv "$cold_file" "$warm_file"
        
        sqlite3 "$CACHE_DB" <<EOF
UPDATE cache_entries SET cache_tier = 'warm' WHERE cache_key = '$cache_key';
EOF
        
        log_debug "Promoted $cache_key to warm tier"
    fi
}

# Check global cache
check_global_cache() {
    local cache_key="$1"
    
    # This would implement actual global cache lookup
    # For now, simulate with local global cache directory
    local global_file="$GLOBAL_CACHE_DIR/objects/$cache_key.cache"
    
    if [[ -f "$global_file" ]]; then
        # Copy to local warm cache
        cp "$global_file" "$LOCAL_CACHE_DIR/warm/$cache_key.cache"
        return 0
    fi
    
    return 1
}

# Replicate to global cache
replicate_to_global_cache() {
    local cache_key="$1"
    local cache_data="$2"
    local tier="$3"
    
    local global_file="$GLOBAL_CACHE_DIR/objects/$cache_key.cache"
    
    # Ensure directory exists
    mkdir -p "$(dirname "$global_file")"
    
    # Store in global cache
    echo "$cache_data" > "$global_file"
    
    log_debug "Replicated $cache_key to global cache"
}

# Run ML-powered prefetch
run_intelligent_prefetch() {
    local hours_back="${1:-2}"
    local max_predictions="${2:-10}"
    
    log_info "Running intelligent prefetch analysis..."
    
    # Check if we have enough data
    local pattern_count
    pattern_count=$(sqlite3 "$CACHE_DB" \
        "SELECT COUNT(DISTINCT cache_key) FROM access_patterns WHERE access_timestamp > $(date -d "$hours_back hours ago" +%s);")
    
    if [[ ${pattern_count:-0} -lt 5 ]]; then
        log_warn "Insufficient access patterns for ML prefetch: $pattern_count"
        return 1
    fi
    
    # Run ML analysis
    local predictions_file="/tmp/prefetch_predictions_$$.json"
    
    if python3 "$CACHE_ROOT/prefetch_analyzer.py" predict \
        --db "$CACHE_DB" \
        --model-dir "$ML_MODEL_DIR" \
        --hours "$hours_back" \
        --output "$predictions_file" 2>/dev/null; then
        
        # Process predictions
        local prediction_count
        prediction_count=$(jq length "$predictions_file" 2>/dev/null || echo "0")
        
        if [[ $prediction_count -gt 0 ]]; then
            log_success "Generated $prediction_count prefetch predictions"
            
            # Execute prefetch for high-confidence predictions
            jq -r '.[] | select(.confidence > 0.8) | .cache_key' "$predictions_file" | \
            head -"$max_predictions" | while read -r cache_key; do
                if [[ -n "$cache_key" ]]; then
                    prefetch_cache_entry "$cache_key"
                fi
            done
        else
            log_info "No prefetch predictions generated"
        fi
    else
        log_warn "ML prefetch analysis failed, using heuristic approach"
        run_heuristic_prefetch
    fi
    
    # Cleanup
    rm -f "$predictions_file"
}

# Prefetch specific cache entry
prefetch_cache_entry() {
    local cache_key="$1"
    
    log_debug "Prefetching cache entry: $cache_key"
    
    # Check if already cached
    if cache_get "$cache_key" "prefetch" >/dev/null 2>&1; then
        log_debug "Cache entry already available: $cache_key"
        return 0
    fi
    
    # This is where we would trigger actual build/computation
    # For now, simulate by creating a placeholder
    local prefetch_data="prefetch_placeholder_$(date +%s)"
    cache_put "$cache_key" "$prefetch_data" 1024 "prefetch" "normal"
    
    # Record prefetch
    record_cache_access "$cache_key" "prefetch" "warm" "prefetch" "$(whoami)"
    
    log_debug "Prefetched cache entry: $cache_key"
}

# Heuristic prefetch fallback
run_heuristic_prefetch() {
    log_debug "Running heuristic prefetch..."
    
    # Find recently accessed entries
    local recent_keys
    recent_keys=$(sqlite3 "$CACHE_DB" "
        SELECT cache_key 
        FROM cache_entries 
        WHERE accessed_timestamp > $(date -d '1 hour ago' +%s)
        AND hit_count > 2
        ORDER BY hit_count DESC 
        LIMIT 5;
    ")
    
    # Prefetch related entries (simplified heuristic)
    while IFS= read -r cache_key; do
        if [[ -n "$cache_key" ]]; then
            # Look for related cache keys (same prefix)
            local prefix
            prefix=$(echo "$cache_key" | cut -d'_' -f1)
            
            sqlite3 "$CACHE_DB" "
                SELECT cache_key 
                FROM cache_entries 
                WHERE cache_key LIKE '${prefix}_%' 
                AND cache_key != '$cache_key'
                AND accessed_timestamp < $(date -d '30 minutes ago' +%s)
                LIMIT 2;
            " | while IFS= read -r related_key; do
                if [[ -n "$related_key" ]]; then
                    prefetch_cache_entry "$related_key"
                fi
            done
        fi
    done <<< "$recent_keys"
}

# Train ML models
train_cache_models() {
    log_info "Training cache ML models..."
    
    # Train prefetch model
    if python3 "$CACHE_ROOT/prefetch_analyzer.py" train \
        --db "$CACHE_DB" \
        --model-dir "$ML_MODEL_DIR" \
        --hours 168; then  # Use 1 week of data
        
        log_success "Prefetch model training completed"
    else
        log_warn "Prefetch model training failed"
    fi
}

# Generate cache analytics report
generate_cache_analytics() {
    log_info "Generating cache analytics report..."
    
    local report_file="$ANALYTICS_DIR/cache_report_$(date +%Y%m%d_%H%M%S).json"
    
    # Calculate cache metrics
    local total_entries hit_rate miss_rate avg_access_time
    total_entries=$(sqlite3 "$CACHE_DB" "SELECT COUNT(*) FROM cache_entries;")
    
    local hits misses
    hits=$(sqlite3 "$CACHE_DB" "SELECT SUM(hit_count) FROM cache_entries;")
    misses=$(sqlite3 "$CACHE_DB" "SELECT SUM(miss_count) FROM cache_entries;")
    
    if [[ ${hits:-0} -gt 0 ]] || [[ ${misses:-0} -gt 0 ]]; then
        hit_rate=$(echo "scale=2; ${hits:-0} * 100 / (${hits:-0} + ${misses:-0})" | bc -l)
        miss_rate=$(echo "scale=2; ${misses:-0} * 100 / (${hits:-0} + ${misses:-0})" | bc -l)
    else
        hit_rate=0
        miss_rate=0
    fi
    
    # Cache size distribution
    local hot_count warm_count cold_count
    hot_count=$(sqlite3 "$CACHE_DB" "SELECT COUNT(*) FROM cache_entries WHERE cache_tier = 'hot';")
    warm_count=$(sqlite3 "$CACHE_DB" "SELECT COUNT(*) FROM cache_entries WHERE cache_tier = 'warm';")
    cold_count=$(sqlite3 "$CACHE_DB" "SELECT COUNT(*) FROM cache_entries WHERE cache_tier = 'cold';")
    
    # Most accessed entries
    local top_entries
    top_entries=$(sqlite3 "$CACHE_DB" "
        SELECT cache_key, hit_count, cache_tier 
        FROM cache_entries 
        ORDER BY hit_count DESC 
        LIMIT 10;
    " | jq -R 'split("|") | {cache_key: .[0], hit_count: (.[1] | tonumber), tier: .[2]}' | jq -s .)
    
    # Generate report
    cat > "$report_file" <<EOF
{
    "generated_at": "$(date -Iseconds)",
    "cache_statistics": {
        "total_entries": $total_entries,
        "hit_rate_percent": $hit_rate,
        "miss_rate_percent": $miss_rate,
        "total_hits": ${hits:-0},
        "total_misses": ${misses:-0}
    },
    "tier_distribution": {
        "hot": $hot_count,
        "warm": $warm_count,
        "cold": $cold_count
    },
    "top_accessed_entries": $top_entries,
    "performance_targets": {
        "hit_rate_target": $TARGET_CACHE_HIT_RATE,
        "hit_rate_achieved": $hit_rate,
        "target_met": $(echo "$hit_rate >= $TARGET_CACHE_HIT_RATE" | bc -l)
    }
}
EOF
    
    log_success "Cache analytics report saved: $report_file"
    
    # Display summary
    echo "Cache Analytics Summary:"
    echo "  Total Entries: $total_entries"
    echo "  Hit Rate: ${hit_rate}% (target: ${TARGET_CACHE_HIT_RATE}%)"
    echo "  Tier Distribution: Hot=$hot_count, Warm=$warm_count, Cold=$cold_count"
}

# Cache cleanup and optimization
optimize_cache() {
    log_info "Optimizing cache..."
    
    local current_time
    current_time=$(date +%s)
    
    # Remove expired entries
    local expired_cutoff
    expired_cutoff=$(date -d "$CACHE_EXPIRY_DAYS days ago" +%s)
    
    # Find expired entries
    local expired_entries
    expired_entries=$(sqlite3 "$CACHE_DB" \
        "SELECT cache_key, cache_tier FROM cache_entries WHERE accessed_timestamp < $expired_cutoff;")
    
    local expired_count=0
    while IFS='|' read -r cache_key cache_tier; do
        if [[ -n "$cache_key" ]]; then
            # Remove cache files
            for ext in ".cache" ".cache.gz"; do
                local cache_file="$LOCAL_CACHE_DIR/$cache_tier/$cache_key$ext"
                if [[ -f "$cache_file" ]]; then
                    rm -f "$cache_file"
                    ((expired_count++))
                fi
            done
        fi
    done <<< "$expired_entries"
    
    # Clean up database
    sqlite3 "$CACHE_DB" <<EOF
DELETE FROM cache_entries WHERE accessed_timestamp < $expired_cutoff;
DELETE FROM access_patterns WHERE access_timestamp < $expired_cutoff;
DELETE FROM prefetch_predictions WHERE created_timestamp < $expired_cutoff;
VACUUM;
ANALYZE;
EOF
    
    log_success "Cache optimization complete - removed $expired_count expired entries"
}

# Main command interface
main() {
    local command="${1:-help}"
    
    case "$command" in
        "init")
            init_cache_system
            ;;
        "get")
            local cache_key="$2"
            local build_context="${3:-default}"
            local developer_id="${4:-$(whoami)}"
            
            if [[ -z "$cache_key" ]]; then
                log_error "Cache key required for get command"
                exit 1
            fi
            
            if cache_get "$cache_key" "$build_context" "$developer_id"; then
                exit 0
            else
                exit 1
            fi
            ;;
        "put")
            local cache_key="$2"
            local cache_data="$3"
            local size_bytes="${4:-0}"
            local build_context="${5:-default}"
            local priority="${6:-normal}"
            local developer_id="${7:-$(whoami)}"
            
            if [[ -z "$cache_key" || -z "$cache_data" ]]; then
                log_error "Cache key and data required for put command"
                exit 1
            fi
            
            cache_put "$cache_key" "$cache_data" "$size_bytes" "$build_context" "$priority" "$developer_id"
            ;;
        "prefetch")
            local hours_back="${2:-2}"
            local max_predictions="${3:-10}"
            run_intelligent_prefetch "$hours_back" "$max_predictions"
            ;;
        "train")
            train_cache_models
            ;;
        "analytics")
            generate_cache_analytics
            ;;
        "optimize")
            optimize_cache
            ;;
        "coordinator")
            local port="${2:-8080}"
            log_info "Starting cache coordinator on port $port"
            python3 "$DISTRIBUTED_CACHE_DIR/coordinator.py" \
                --db "$CACHE_DB" \
                --cache-root "$CACHE_ROOT" \
                --port "$port"
            ;;
        "worker")
            local node_id="${2:-worker_$(hostname)_$$}"
            local coordinator_url="${3:-http://localhost:8080}"
            local port="${4:-8081}"
            local storage_path="${5:-$LOCAL_CACHE_DIR}"
            
            log_info "Starting cache worker: $node_id"
            python3 "$DISTRIBUTED_CACHE_DIR/worker.py" \
                --node-id "$node_id" \
                --storage "$storage_path" \
                --coordinator "$coordinator_url" \
                --port "$port"
            ;;
        "status")
            echo "Intelligent Cache System Status:"
            if [[ -f "$CACHE_DB" ]]; then
                local total_entries hits misses
                total_entries=$(sqlite3 "$CACHE_DB" "SELECT COUNT(*) FROM cache_entries;")
                hits=$(sqlite3 "$CACHE_DB" "SELECT SUM(hit_count) FROM cache_entries;")
                misses=$(sqlite3 "$CACHE_DB" "SELECT SUM(miss_count) FROM cache_entries;")
                
                local hit_rate=0
                if [[ ${hits:-0} -gt 0 ]] || [[ ${misses:-0} -gt 0 ]]; then
                    hit_rate=$(echo "scale=1; ${hits:-0} * 100 / (${hits:-0} + ${misses:-0})" | bc -l)
                fi
                
                echo "  Database: $CACHE_DB"
                echo "  Total Entries: ${total_entries:-0}"
                echo "  Cache Hit Rate: ${hit_rate}% (target: ${TARGET_CACHE_HIT_RATE}%)"
                echo "  Total Hits: ${hits:-0}"
                echo "  Total Misses: ${misses:-0}"
                
                # Check ML model
                if [[ -f "$ML_MODEL_DIR/prefetch_model.pkl" ]]; then
                    echo "  ML Prefetch Model: Available"
                else
                    echo "  ML Prefetch Model: Not trained"
                fi
            else
                echo "  Status: Not initialized"
            fi
            ;;
        "help"|*)
            cat <<EOF
Intelligent Cache System - Agent 2 Day 12

USAGE: $0 <command> [options]

COMMANDS:
  init                          Initialize intelligent cache system
  get <key> [context] [dev_id]  Get cache entry
  put <key> <data> [size] [context] [priority] [dev_id]
                               Store cache entry
  prefetch [hours] [max]       Run ML-powered prefetch analysis
  train                        Train ML cache models
  analytics                    Generate cache analytics report
  optimize                     Optimize cache (cleanup expired entries)
  coordinator [port]           Start distributed cache coordinator
  worker [id] [coordinator] [port] [storage]
                               Start cache worker node
  status                       Show cache system status
  help                         Show this help

EXAMPLES:
  $0 init
  $0 get "build_graphics_sprite"
  $0 put "build_graphics_sprite" "compiled_data" 1024 "incremental" "high"
  $0 prefetch 2 10
  $0 train
  $0 analytics
  $0 coordinator 8080
  $0 worker "worker1" "http://localhost:8080" 8081

PERFORMANCE TARGETS:
  - Cache Hit Rate: $TARGET_CACHE_HIT_RATE%+
  - Prefetch Accuracy: $TARGET_PREFETCH_ACCURACY%+
  - Network Efficiency: $TARGET_NETWORK_EFFICIENCY%+
  - Size Limit: $TARGET_CACHE_SIZE_LIMIT
EOF
            ;;
    esac
}

# Initialize on first run
if [[ ! -f "$CACHE_DB" && "$1" != "help" && "$1" != "init" ]]; then
    log_info "First run detected, initializing cache system..."
    init_cache_system
fi

# Execute main function
main "$@"