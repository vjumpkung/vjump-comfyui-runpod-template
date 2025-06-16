#!/usr/bin/env python3
import socket
import subprocess
import time
import re
import sys
from concurrent.futures import ThreadPoolExecutor


def check_port_open(host, port, timeout=5):
    """Check if a port is open and accepting connections"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except:
        return False


def wait_for_port(host, port, max_wait=1200):
    """Wait until port is open, checking every second"""
    for _ in range(max_wait):
        if check_port_open(host, port):
            return True
        time.sleep(1)
    return False


def start_tunnel(port):
    """Start cloudflared tunnel for a specific port"""
    try:
        # Wait for port to be available
        if not wait_for_port("localhost", port):
            print(f"Port {port} is not available after waiting", file=sys.stderr)
            return None

        # Start cloudflared process
        cmd = ["cloudflared", "tunnel", "--url", f"http://localhost:{port}"]
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
            bufsize=1,
        )

        # Read output to find tunnel URL
        # for line in iter(process.stdout.readline, ""):
        #     # Look for tunnel URL in output
        #     if "trycloudflare.com" in line or "https://" in line:
        #         # Extract URL using regex
        #         url_match = re.search(r"https://[^\s]+\.trycloudflare\.com", line)
        #         if url_match:
        #             tunnel_url = url_match.group(0)
        #             print(f"{tunnel_url}")
        #             return process

        # If no URL found in stdout, check stderr
        for line in iter(process.stderr.readline, ""):
            if "trycloudflare.com" in line or "https://" in line:
                url_match = re.search(r"https://[^\s]+\.trycloudflare\.com", line)
                if url_match:
                    tunnel_url = url_match.group(0)
                    print(f"{tunnel_url}")
                    return process

    except Exception as e:
        print(f"Error starting tunnel for port {port}: {e}", file=sys.stderr)
        return None


def main():
    # Define ports to tunnel
    ports = [3000, 8080, 5000, 8000]  # Add your desired ports here

    # You can also accept ports as command line arguments
    if len(sys.argv) > 1:
        try:
            ports = [int(port) for port in sys.argv[1:]]
        except ValueError:
            print("Error: All arguments must be valid port numbers", file=sys.stderr)
            sys.exit(1)

    # Start tunnels for all ports concurrently
    processes = []

    with ThreadPoolExecutor(max_workers=len(ports)) as executor:
        futures = {executor.submit(start_tunnel, port): port for port in ports}

        for future in futures:
            process = future.result()
            if process:
                processes.append(process)

    # Keep script running
    try:
        while processes:
            time.sleep(1)
            # Remove dead processes
            processes = [p for p in processes if p.poll() is None]
    except KeyboardInterrupt:
        # Clean up processes on exit
        for process in processes:
            process.terminate()


if __name__ == "__main__":
    main()
