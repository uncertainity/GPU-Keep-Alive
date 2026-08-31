#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
STATE_DIR="${GPU_KEEPALIVE_STATE_DIR:-$SCRIPT_DIR}"
PID_FILE="$STATE_DIR/running/active_pids.txt"

if [[ ! -f "$PID_FILE" ]]; then
    echo "No active Job PID found"
    exit 0
fi

read -r job_pid < "$PID_FILE"

if ! kill -0 "$job_pid" 2>/dev/null; then
    echo "Job is no longer running: $job_pid"
    rm -f "$PID_FILE"
    exit 0
fi

echo "Stopping job PID $job_pid"
kill -TERM "$job_pid"
