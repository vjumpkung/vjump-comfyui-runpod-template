#!/bin/bash

# Define log file locations
PID_FILE="/tmp/python_process.pid"

# Check if process is already running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null; then
        echo "Process is already running with PID: $PID"
        exit 1
    else
        echo "Stale PID file found. Previous process is not running."
        rm "$PID_FILE"
    fi
fi

# Start the process with nohup
echo "Starting process..."
cd /notebooks/ComfyUI
nohup $CMD > "$PROGRAM_LOG" 2>&1 &

# Save the PID
echo $! > "$PID_FILE"
echo "Process started with PID: $(cat "$PID_FILE")"
echo "Logs are being written to $LOG_FILE"

cd /notebooks