#!/usr/bin/env python3
"""
CyberpunkMP Master Server (Python 3.9)
A complete replacement for the official CyberpunkMP master server
Handles server registration, heartbeats, server browser, and player statistics
"""

import asyncio
import json
import time
import logging
import sqlite3
import ipaddress
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from urllib.parse import parse_qs
import re

from aiohttp import web, ClientSession
from aiohttp.web_request import Request
from aiohttp.web_response import Response

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('CyberpunkMP-Master')

@dataclass
class ServerInfo:
    """Server information data structure"""
    name: str
    desc: str
    icon_url: str
    version: str
    ip: str
    port: int
    tick: int
    player_count: int
    max_player_count: int
    tags: str
    public: bool
    password: bool
    flags: int
    last_heartbeat: float
    first_seen: float
    total_players_served: int = 0
    uptime_minutes: int = 0
    region: str = "Unknown"
    game_mode: str = "Freeplay"

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        return {
            'name': self.name,
            'description': self.desc,
            'icon_url': self.icon_url,
            'version': self.version,
            'ip': self.ip,
            'port': self.port,
            'tick_rate': self.tick,
            'player_count': self.player_count,
            'max_player_count': self.max_player_count,
            'tags': self.tags.split(',') if self.tags else [],
            'public': self.public,
            'password_protected': self.password,
            'flags': self.flags,
            'last_seen': int(self.last_heartbeat),
            'uptime_minutes': self.uptime_minutes,
            'region': self.region,
            'game_mode': self.game_mode,
            'ping': self.calculate_ping()
        }

    def calculate_ping(self) -> int:
        """Calculate simulated ping based on last heartbeat"""
        time_since_heartbeat = time.time() - self.last_heartbeat
        return min(int(time_since_heartbeat * 1000), 999)  # Max 999ms ping

    def is_online(self, timeout_minutes: int = 5) -> bool:
        """Check if server is considered online"""
        return (time.time() - self.last_heartbeat) < (timeout_minutes * 60)

class CyberpunkMPMasterServer:
    """CyberpunkMP Master Server Implementation"""

    def __init__(self, host: str = '127.0.0.1', port: int = 8000):
        self.host = host
        self.port = port
        self.servers: Dict[str, ServerInfo] = {}
        self.banned_servers: Dict[str, str] = {}  # IP -> reason
        self.banned_players: Dict[str, str] = {}  # Player ID -> reason
        self.stats = {
            'total_servers_registered': 0,
            'total_announcements': 0,
            'total_queries': 0,
            'total_players_online': 0,
            'peak_servers': 0,
            'peak_players': 0,
            'server_start_time': time.time()
        }

        # Initialize database
        self.init_database()

        # Create web application
        self.app = web.Application()
        self.setup_routes()

        logger.info(f"CyberpunkMP Master Server initialized on {host}:{port}")

    def init_database(self):
        """Initialize SQLite database for persistent storage"""
        self.db = sqlite3.connect('cyberpunkmp_master.db', check_same_thread=False)
        cursor = self.db.cursor()

        # Create servers table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS servers (
                server_id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                description TEXT,
                icon_url TEXT,
                version TEXT,
                ip TEXT NOT NULL,
                port INTEGER NOT NULL,
                tick_rate INTEGER,
                max_players INTEGER,
                tags TEXT,
                public INTEGER,
                password_protected INTEGER,
                flags INTEGER,
                first_seen REAL,
                last_seen REAL,
                total_players_served INTEGER DEFAULT 0,
                region TEXT DEFAULT 'Unknown'
            )
        ''')

        # Create player statistics table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS player_stats (
                player_id TEXT PRIMARY KEY,
                player_name TEXT,
                first_seen REAL,
                last_seen REAL,
                total_playtime_minutes INTEGER DEFAULT 0,
                servers_played TEXT,
                region TEXT DEFAULT 'Unknown'
            )
        ''')

        # Create server history table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS server_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                server_id TEXT,
                timestamp REAL,
                player_count INTEGER,
                status TEXT,
                FOREIGN KEY (server_id) REFERENCES servers (server_id)
            )
        ''')

        # Create bans table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS bans (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT NOT NULL, -- 'server' or 'player'
                target TEXT NOT NULL, -- IP or player ID
                reason TEXT,
                banned_at REAL,
                banned_by TEXT DEFAULT 'system',
                expires_at REAL -- NULL for permanent
            )
        ''')

        self.db.commit()
        logger.info("Database initialized successfully")

    def setup_routes(self):
        """Setup HTTP routes"""
        # Server registration and heartbeat
        self.app.router.add_post('/announce', self.handle_server_announce)

        # Server browser endpoints
        self.app.router.add_get('/servers', self.handle_get_servers)
        self.app.router.add_get('/list', self.handle_get_servers)  # Alias for launcher compatibility
        self.app.router.add_get('/servers/{server_id}', self.handle_get_server_details)

        # Statistics endpoints
        self.app.router.add_get('/stats', self.handle_get_stats)
        self.app.router.add_get('/stats/servers', self.handle_get_server_stats)
        self.app.router.add_get('/stats/players', self.handle_get_player_stats)

        # Admin endpoints
        self.app.router.add_post('/admin/ban', self.handle_ban)
        self.app.router.add_post('/admin/unban', self.handle_unban)
        self.app.router.add_get('/admin/bans', self.handle_get_bans)

        # Health check
        self.app.router.add_get('/health', self.handle_health_check)
        self.app.router.add_get('/', self.handle_root)

        # CORS support
        self.app.router.add_options('/{path:.*}', self.handle_options)

        # Middleware for CORS
        self.app.middlewares.append(self.cors_middleware)

        logger.info("Routes configured successfully")

    @web.middleware
    async def cors_middleware(self, request: Request, handler):
        """CORS middleware for browser compatibility"""
        try:
            response = await handler(request)
        except Exception as e:
            logger.error(f"Handler error: {e}")
            response = web.json_response({'error': 'Internal server error'}, status=500)

        # Add CORS headers
        response.headers['Access-Control-Allow-Origin'] = '*'
        response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type'

        return response

    async def handle_options(self, request: Request) -> Response:
        """Handle CORS preflight requests"""
        return web.Response(
            status=200,
            headers={
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            }
        )

    async def handle_root(self, request: Request) -> Response:
        """Root endpoint with server information"""
        uptime = time.time() - self.stats['server_start_time']
        online_servers = len([s for s in self.servers.values() if s.is_online()])

        info = {
            'server': 'CyberpunkMP Master Server',
            'version': '1.0.0',
            'uptime_seconds': int(uptime),
            'online_servers': online_servers,
            'total_servers': len(self.servers),
            'total_players_online': sum(s.player_count for s in self.servers.values() if s.is_online()),
            'endpoints': {
                'announce': '/announce',
                'servers': '/servers',
                'stats': '/stats',
                'health': '/health'
            }
        }

        return web.json_response(info)

    async def handle_server_announce(self, request: Request) -> Response:
        """Handle server announcement/heartbeat"""
        try:
            # Get client IP
            client_ip = self.get_client_ip(request)

            # Check if server is banned
            if client_ip in self.banned_servers:
                logger.warning(f"Banned server attempted to announce: {client_ip}")
                return web.Response(status=403, text=f"Server banned: {self.banned_servers[client_ip]}")

            # Parse form data
            data = await request.post()

            # Validate required fields
            required_fields = ['name', 'port', 'version']
            for field in required_fields:
                if field not in data:
                    return web.json_response({'error': f'Missing required field: {field}'}, status=400)

            # Create server ID from IP and port
            server_id = f"{client_ip}:{data['port']}"

            # Extract and validate data
            try:
                port = int(data['port'])
                tick = int(data.get('tick', 60))
                player_count = int(data.get('player_count', 0))
                max_player_count = int(data.get('max_player_count', 10))
                flags = int(data.get('flags', 0))
                public = data.get('public', 'true').lower() == 'true'
                password = data.get('pass', 'false').lower() == 'true'
            except ValueError as e:
                return web.json_response({'error': f'Invalid numeric field: {e}'}, status=400)

            # Validate port range
            if not (1024 <= port <= 65535):
                return web.json_response({'error': 'Port must be between 1024 and 65535'}, status=400)

            # Validate player counts
            if player_count < 0 or max_player_count < 1 or player_count > max_player_count:
                return web.json_response({'error': 'Invalid player count values'}, status=400)

            current_time = time.time()

            # Check if this is a new server or update
            is_new_server = server_id not in self.servers

            if is_new_server:
                # New server registration
                server_info = ServerInfo(
                    name=self.sanitize_string(data['name']),
                    desc=self.sanitize_string(data.get('desc', '')),
                    icon_url=self.sanitize_url(data.get('icon_url', '')),
                    version=self.sanitize_string(data['version']),
                    ip=client_ip,
                    port=port,
                    tick=tick,
                    player_count=player_count,
                    max_player_count=max_player_count,
                    tags=self.sanitize_string(data.get('tags', '')),
                    public=public,
                    password=password,
                    flags=flags,
                    last_heartbeat=current_time,
                    first_seen=current_time,
                    region=self.detect_region(client_ip)
                )

                self.stats['total_servers_registered'] += 1
                logger.info(f"New server registered: {server_info.name} ({server_id})")
            else:
                # Update existing server
                server_info = self.servers[server_id]
                server_info.name = self.sanitize_string(data['name'])
                server_info.desc = self.sanitize_string(data.get('desc', ''))
                server_info.icon_url = self.sanitize_url(data.get('icon_url', ''))
                server_info.version = self.sanitize_string(data['version'])
                server_info.tick = tick
                server_info.player_count = player_count
                server_info.max_player_count = max_player_count
                server_info.tags = self.sanitize_string(data.get('tags', ''))
                server_info.public = public
                server_info.password = password
                server_info.flags = flags
                server_info.last_heartbeat = current_time

                # Update uptime
                server_info.uptime_minutes = int((current_time - server_info.first_seen) / 60)

            # Store server info
            self.servers[server_id] = server_info

            # Update statistics
            self.stats['total_announcements'] += 1
            online_servers = len([s for s in self.servers.values() if s.is_online()])
            total_players = sum(s.player_count for s in self.servers.values() if s.is_online())

            self.stats['peak_servers'] = max(self.stats['peak_servers'], online_servers)
            self.stats['peak_players'] = max(self.stats['peak_players'], total_players)
            self.stats['total_players_online'] = total_players

            # Save to database
            await self.save_server_to_db(server_info)

            # Log server history
            await self.log_server_history(server_id, player_count, 'online')

            logger.debug(f"Server heartbeat: {server_info.name} ({player_count}/{max_player_count} players)")

            return web.json_response({'status': 'success', 'message': 'Server registered successfully'})

        except Exception as e:
            logger.error(f"Error handling server announcement: {e}")
            return web.json_response({'error': 'Internal server error'}, status=500)

    async def handle_get_servers(self, request: Request) -> Response:
        """Handle server list request"""
        try:
            self.stats['total_queries'] += 1

            # Parse query parameters
            params = request.query
            include_offline = params.get('include_offline', 'false').lower() == 'true'
            region_filter = params.get('region', '').strip()
            version_filter = params.get('version', '').strip()
            has_players = params.get('has_players', 'false').lower() == 'true'
            public_only = params.get('public_only', 'true').lower() == 'true'

            # Filter servers
            filtered_servers = []
            current_time = time.time()

            for server_id, server in self.servers.items():
                # Check if server is online
                if not include_offline and not server.is_online():
                    continue

                # Apply filters
                if region_filter and server.region.lower() != region_filter.lower():
                    continue

                if version_filter and server.version != version_filter:
                    continue

                if has_players and server.player_count == 0:
                    continue

                if public_only and not server.public:
                    continue

                server_data = server.to_dict()
                server_data['server_id'] = server_id
                filtered_servers.append(server_data)

            # Sort by player count (descending) then by name
            filtered_servers.sort(key=lambda x: (-x['player_count'], x['name']))

            response_data = {
                'servers': filtered_servers,
                'total': len(filtered_servers),
                'timestamp': int(current_time),
                'filters_applied': {
                    'include_offline': include_offline,
                    'region': region_filter,
                    'version': version_filter,
                    'has_players': has_players,
                    'public_only': public_only
                }
            }

            return web.json_response(response_data)

        except Exception as e:
            logger.error(f"Error handling server list request: {e}")
            return web.json_response({'error': 'Internal server error'}, status=500)

    async def handle_get_server_details(self, request: Request) -> Response:
        """Handle individual server details request"""
        try:
            server_id = request.match_info['server_id']

            if server_id not in self.servers:
                return web.json_response({'error': 'Server not found'}, status=404)

            server = self.servers[server_id]
            server_data = server.to_dict()
            server_data['server_id'] = server_id

            # Add additional details
            server_data['is_online'] = server.is_online()
            server_data['first_seen'] = int(server.first_seen)
            server_data['total_players_served'] = server.total_players_served

            return web.json_response(server_data)

        except Exception as e:
            logger.error(f"Error handling server details request: {e}")
            return web.json_response({'error': 'Internal server error'}, status=500)

    async def handle_get_stats(self, request: Request) -> Response:
        """Handle master server statistics request"""
        try:
            current_time = time.time()
            uptime = current_time - self.stats['server_start_time']

            online_servers = [s for s in self.servers.values() if s.is_online()]
            total_players = sum(s.player_count for s in online_servers)

            stats = {
                'master_server': {
                    'uptime_seconds': int(uptime),
                    'uptime_hours': round(uptime / 3600, 2),
                    'total_announcements': self.stats['total_announcements'],
                    'total_queries': self.stats['total_queries'],
                    'total_servers_registered': self.stats['total_servers_registered']
                },
                'current': {
                    'online_servers': len(online_servers),
                    'total_players_online': total_players,
                    'timestamp': int(current_time)
                },
                'peaks': {
                    'max_servers': self.stats['peak_servers'],
                    'max_players': self.stats['peak_players']
                },
                'server_breakdown': {
                    'public_servers': len([s for s in online_servers if s.public]),
                    'private_servers': len([s for s in online_servers if not s.public]),
                    'password_protected': len([s for s in online_servers if s.password]),
                    'empty_servers': len([s for s in online_servers if s.player_count == 0]),
                    'full_servers': len([s for s in online_servers if s.player_count >= s.max_player_count])
                },
                'regions': self.get_region_stats(online_servers),
                'versions': self.get_version_stats(online_servers)
            }

            return web.json_response(stats)

        except Exception as e:
            logger.error(f"Error handling stats request: {e}")
            return web.json_response({'error': 'Internal server error'}, status=500)

    async def handle_get_server_stats(self, request: Request) -> Response:
        """Handle detailed server statistics"""
        try:
            # Get server history from database
            cursor = self.db.cursor()
            cursor.execute('''
                SELECT server_id, timestamp, player_count, status
                FROM server_history
                WHERE timestamp > ?
                ORDER BY timestamp DESC
                LIMIT 1000
            ''', (time.time() - 86400,))  # Last 24 hours

            history = cursor.fetchall()

            # Process history data
            server_history = {}
            for server_id, timestamp, player_count, status in history:
                if server_id not in server_history:
                    server_history[server_id] = []
                server_history[server_id].append({
                    'timestamp': int(timestamp),
                    'player_count': player_count,
                    'status': status
                })

            return web.json_response({
                'server_history': server_history,
                'timeframe': '24_hours'
            })

        except Exception as e:
            logger.error(f"Error handling server stats request: {e}")
            return web.json_response({'error': 'Internal server error'}, status=500)

    async def handle_get_player_stats(self, request: Request) -> Response:
        """Handle player statistics request"""
        try:
            # This would be populated by game servers reporting player data
            # For now, return aggregate data
            online_servers = [s for s in self.servers.values() if s.is_online()]

            stats = {
                'total_players_online': sum(s.player_count for s in online_servers),
                'average_players_per_server': round(sum(s.player_count for s in online_servers) / max(len(online_servers), 1), 2),
                'servers_with_players': len([s for s in online_servers if s.player_count > 0]),
                'most_populated_server': max(online_servers, key=lambda s: s.player_count).to_dict() if online_servers else None
            }

            return web.json_response(stats)

        except Exception as e:
            logger.error(f"Error handling player stats request: {e}")
            return web.json_response({'error': 'Internal server error'}, status=500)

    async def handle_ban(self, request: Request) -> Response:
        """Handle ban request (admin endpoint)"""
        try:
            data = await request.json()

            ban_type = data.get('type')  # 'server' or 'player'
            target = data.get('target')  # IP or player ID
            reason = data.get('reason', 'No reason provided')
            duration = data.get('duration')  # minutes, None for permanent

            if not ban_type or not target:
                return web.json_response({'error': 'Missing type or target'}, status=400)

            if ban_type not in ['server', 'player']:
                return web.json_response({'error': 'Invalid ban type'}, status=400)

            # Calculate expiry time
            expires_at = None
            if duration:
                expires_at = time.time() + (duration * 60)

            # Store ban
            cursor = self.db.cursor()
            cursor.execute('''
                INSERT INTO bans (type, target, reason, banned_at, expires_at)
                VALUES (?, ?, ?, ?, ?)
            ''', (ban_type, target, reason, time.time(), expires_at))
            self.db.commit()

            # Apply ban
            if ban_type == 'server':
                self.banned_servers[target] = reason
                # Remove banned server from active list
                to_remove = [sid for sid, s in self.servers.items() if s.ip == target]
                for sid in to_remove:
                    del self.servers[sid]
            else:
                self.banned_players[target] = reason

            logger.info(f"Banned {ban_type}: {target} - {reason}")

            return web.json_response({'status': 'success', 'message': f'{ban_type.title()} banned successfully'})

        except Exception as e:
            logger.error(f"Error handling ban request: {e}")
            return web.json_response({'error': 'Internal server error'}, status=500)

    async def handle_unban(self, request: Request) -> Response:
        """Handle unban request (admin endpoint)"""
        try:
            data = await request.json()

            ban_type = data.get('type')
            target = data.get('target')

            if not ban_type or not target:
                return web.json_response({'error': 'Missing type or target'}, status=400)

            # Remove from active bans
            if ban_type == 'server' and target in self.banned_servers:
                del self.banned_servers[target]
            elif ban_type == 'player' and target in self.banned_players:
                del self.banned_players[target]

            # Mark as unbanned in database
            cursor = self.db.cursor()
            cursor.execute('''
                UPDATE bans SET expires_at = ? WHERE type = ? AND target = ? AND (expires_at IS NULL OR expires_at > ?)
            ''', (time.time(), ban_type, target, time.time()))
            self.db.commit()

            logger.info(f"Unbanned {ban_type}: {target}")

            return web.json_response({'status': 'success', 'message': f'{ban_type.title()} unbanned successfully'})

        except Exception as e:
            logger.error(f"Error handling unban request: {e}")
            return web.json_response({'error': 'Internal server error'}, status=500)

    async def handle_get_bans(self, request: Request) -> Response:
        """Handle get bans request (admin endpoint)"""
        try:
            cursor = self.db.cursor()
            cursor.execute('''
                SELECT type, target, reason, banned_at, expires_at
                FROM bans
                WHERE expires_at IS NULL OR expires_at > ?
                ORDER BY banned_at DESC
            ''', (time.time(),))

            bans = []
            for ban_type, target, reason, banned_at, expires_at in cursor.fetchall():
                bans.append({
                    'type': ban_type,
                    'target': target,
                    'reason': reason,
                    'banned_at': int(banned_at),
                    'expires_at': int(expires_at) if expires_at else None,
                    'is_permanent': expires_at is None
                })

            return web.json_response({'bans': bans})

        except Exception as e:
            logger.error(f"Error handling get bans request: {e}")
            return web.json_response({'error': 'Internal server error'}, status=500)

    async def handle_health_check(self, request: Request) -> Response:
        """Health check endpoint"""
        uptime = time.time() - self.stats['server_start_time']
        online_servers = len([s for s in self.servers.values() if s.is_online()])

        health = {
            'status': 'healthy',
            'uptime_seconds': int(uptime),
            'online_servers': online_servers,
            'database_ok': True,
            'timestamp': int(time.time())
        }

        # Test database connection
        try:
            cursor = self.db.cursor()
            cursor.execute('SELECT 1')
            cursor.fetchone()
        except Exception:
            health['database_ok'] = False
            health['status'] = 'unhealthy'

        return web.json_response(health)

    # Helper methods

    def get_client_ip(self, request: Request) -> str:
        """Get the real client IP address"""
        # Check for forwarded headers first
        forwarded_for = request.headers.get('X-Forwarded-For')
        if forwarded_for:
            # Take the first IP in the chain
            return forwarded_for.split(',')[0].strip()

        real_ip = request.headers.get('X-Real-IP')
        if real_ip:
            return real_ip

        # Fall back to remote address
        peername = request.transport.get_extra_info('peername')
        if peername:
            return peername[0]

        return '127.0.0.1'

    def sanitize_string(self, text: str, max_length: int = 200) -> str:
        """Sanitize string input"""
        if not text:
            return ''

        # Remove control characters and limit length
        text = re.sub(r'[\x00-\x1f\x7f-\x9f]', '', str(text))
        return text[:max_length].strip()

    def sanitize_url(self, url: str) -> str:
        """Sanitize URL input"""
        if not url:
            return ''

        url = self.sanitize_string(url, 500)

        # Basic URL validation
        if url and not (url.startswith('http://') or url.startswith('https://')):
            return ''

        return url

    def detect_region(self, ip: str) -> str:
        """Detect region from IP address (simplified)"""
        try:
            ip_obj = ipaddress.ip_address(ip)

            # Check for local/private IPs
            if ip_obj.is_private or ip_obj.is_loopback:
                return 'Local'

            # This would normally use a GeoIP database
            # For now, return based on IP ranges (very simplified)
            if ip.startswith('127.') or ip.startswith('192.168.') or ip.startswith('10.'):
                return 'Local'
            else:
                return 'Global'
        except:
            return 'Unknown'

    def get_region_stats(self, servers: List[ServerInfo]) -> Dict[str, int]:
        """Get server count by region"""
        regions = {}
        for server in servers:
            region = server.region
            regions[region] = regions.get(region, 0) + 1
        return regions

    def get_version_stats(self, servers: List[ServerInfo]) -> Dict[str, int]:
        """Get server count by version"""
        versions = {}
        for server in servers:
            version = server.version
            versions[version] = versions.get(version, 0) + 1
        return versions

    async def save_server_to_db(self, server: ServerInfo):
        """Save server information to database"""
        try:
            cursor = self.db.cursor()

            # Use REPLACE to update existing or insert new
            cursor.execute('''
                REPLACE INTO servers (
                    server_id, name, description, icon_url, version, ip, port,
                    tick_rate, max_players, tags, public, password_protected,
                    flags, first_seen, last_seen, region
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                f"{server.ip}:{server.port}",
                server.name, server.desc, server.icon_url, server.version,
                server.ip, server.port, server.tick, server.max_player_count,
                server.tags, int(server.public), int(server.password),
                server.flags, server.first_seen, server.last_heartbeat,
                server.region
            ))

            self.db.commit()
        except Exception as e:
            logger.error(f"Error saving server to database: {e}")

    async def log_server_history(self, server_id: str, player_count: int, status: str):
        """Log server history for analytics"""
        try:
            cursor = self.db.cursor()
            cursor.execute('''
                INSERT INTO server_history (server_id, timestamp, player_count, status)
                VALUES (?, ?, ?, ?)
            ''', (server_id, time.time(), player_count, status))
            self.db.commit()
        except Exception as e:
            logger.error(f"Error logging server history: {e}")

    async def cleanup_old_servers(self):
        """Remove servers that haven't sent heartbeats in a while"""
        current_time = time.time()
        timeout = 10 * 60  # 10 minutes

        to_remove = []
        for server_id, server in self.servers.items():
            if current_time - server.last_heartbeat > timeout:
                to_remove.append(server_id)

        for server_id in to_remove:
            logger.info(f"Removing inactive server: {server_id}")
            del self.servers[server_id]
            await self.log_server_history(server_id, 0, 'timeout')

    async def cleanup_task(self):
        """Background cleanup task"""
        while True:
            try:
                await self.cleanup_old_servers()
                await asyncio.sleep(300)  # Run every 5 minutes
            except Exception as e:
                logger.error(f"Error in cleanup task: {e}")
                await asyncio.sleep(60)  # Wait 1 minute on error

    async def start(self):
        """Start the master server"""
        # Start cleanup task
        cleanup_task = asyncio.create_task(self.cleanup_task())

        try:
            # Create and start web server
            runner = web.AppRunner(self.app)
            await runner.setup()

            site = web.TCPSite(runner, self.host, self.port)
            await site.start()

            logger.info(f"CyberpunkMP Master Server started on http://{self.host}:{self.port}")
            logger.info("Available endpoints:")
            logger.info("  GET  /           - Server information")
            logger.info("  POST /announce   - Server registration/heartbeat")
            logger.info("  GET  /servers    - Server browser")
            logger.info("  GET  /stats      - Master server statistics")
            logger.info("  GET  /health     - Health check")

            # Keep the server running
            try:
                await asyncio.Future()  # Run forever
            except KeyboardInterrupt:
                logger.info("Shutting down...")
            finally:
                cleanup_task.cancel()
                await runner.cleanup()

        except Exception as e:
            logger.error(f"Error starting server: {e}")
            cleanup_task.cancel()
            raise

def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(description='CyberpunkMP Master Server')
    parser.add_argument('--host', default='127.0.0.1', help='Host to bind to (default: 127.0.0.1)')
    parser.add_argument('--port', type=int, default=8000, help='Port to bind to (default: 8000)')
    parser.add_argument('--debug', action='store_true', help='Enable debug logging')

    args = parser.parse_args()

    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)

    # Create and start server
    master_server = CyberpunkMPMasterServer(args.host, args.port)

    try:
        asyncio.run(master_server.start())
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as e:
        logger.error(f"Server error: {e}")
        return 1

    return 0

if __name__ == '__main__':
    exit(main())