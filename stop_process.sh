#!/bin/bash

# Define file locations
PID_FILE="/tmp/python_process.pid"

# Check if PID file exists
if [ ! -f "$PID_FILE" ]; then
    echo "No PID file found. Process may not be running."
    exit 1
fi

# Get the PID
PID=$(cat "$PID_FILE")

# Check if process is running
if ! ps -p "$PID" > /dev/null; then
    echo "Process with PID $PID is not running."
    rm "$PID_FILE"
    exit 1
fi

# Kill the process
echo "Stopping process with PID: $PID"
kill "$PID"

# Wait for process to terminate
for i in {1..10}; do
    if ! ps -p "$PID" > /dev/null; then
        echo "Process successfully terminated."
        rm "$PID_FILE"
        exit 0
    fi
    echo "Waiting for process to terminate... ($i/10)"
    sleep 1
done

# Force kill if process doesn't terminate
echo "Process did not terminate gracefully. Forcing kill..."
kill -9 "$PID"

if ! ps -p "$PID" > /dev/null; then
    echo "Process forcefully terminated."
    rm "$PID_FILE"
    exit 0
else
    echo "Failed to terminate process with PID: $PID"
    exit 1
fi