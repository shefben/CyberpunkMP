#!/usr/bin/env python3
"""
CyberpunkMP Master Server Startup Script
Simplified launcher for the master server with configuration options
"""

import sys
import os
import subprocess
import platform

def check_python_version():
    """Check if Python 3.9+ is available"""
    if sys.version_info < (3, 9):
        print("ERROR: Python 3.9 or higher is required!")
        print(f"Current version: {sys.version}")
        return False
    return True

def install_requirements():
    """Install required packages"""
    print("Installing requirements...")
    try:
        subprocess.check_call([sys.executable, '-m', 'pip', 'install', '-r', 'requirements.txt'])
        print("Requirements installed successfully!")
        return True
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Failed to install requirements: {e}")
        return False

def start_server(host='127.0.0.1', port=8000, debug=False):
    """Start the master server"""
    print(f"Starting CyberpunkMP Master Server on {host}:{port}")
    print("Press Ctrl+C to stop the server")
    print("-" * 50)

    try:
        cmd = [sys.executable, 'cyberpunkmp_master_server.py', '--host', host, '--port', str(port)]
        if debug:
            cmd.append('--debug')

        subprocess.run(cmd)
    except KeyboardInterrupt:
        print("\nServer stopped by user")
    except Exception as e:
        print(f"ERROR: Failed to start server: {e}")

def main():
    """Main function"""
    print("CyberpunkMP Master Server Launcher")
    print("=" * 40)

    if not check_python_version():
        return 1

    # Check if requirements are installed
    try:
        import aiohttp
    except ImportError:
        print("Requirements not installed. Installing now...")
        if not install_requirements():
            return 1

    # Default configuration for local development
    host = '127.0.0.1'  # Localhost for development
    port = 8000
    debug = True

    print(f"Configuration:")
    print(f"  Host: {host}")
    print(f"  Port: {port}")
    print(f"  Debug: {debug}")
    print(f"  Platform: {platform.system()} {platform.release()}")
    print()

    # Start the server
    start_server(host, port, debug)

    return 0

if __name__ == '__main__':
    exit(main())