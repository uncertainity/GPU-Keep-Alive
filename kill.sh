#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
STATE_DIR="${GPU_KEEPALIVE_STATE_DIR:-$SCRIPT_DIR}"
RUNNING_DIR="$STATE_DIR/running"

if [[ $# -gt 1 ]]; then
    echo "Usage: $0 [job-id]" >&2
    exit 1
fi

mapfile -t pid_files < <(
    find "$RUNNING_DIR" -mindepth 2 -maxdepth 2 -type f -name active_pid 2>/dev/null \
        | sort
)

if [[ $# -eq 1 ]]; then
    PID_FILE="$RUNNING_DIR/$1/active_pid"
    if [[ ! -f "$PID_FILE" ]]; then
        echo "No active job found with ID: $1" >&2
        exit 1
    fi
elif [[ ${#pid_files[@]} -eq 0 ]]; then
    echo "No active job PID found"
    exit 0
elif [[ ${#pid_files[@]} -eq 1 ]]; then
    PID_FILE="${pid_files[0]}"
else
    echo "Multiple jobs are active; specify one job ID:" >&2
    for pid_file in "${pid_files[@]}"; do
        basename "$(dirname "$pid_file")" >&2
    done
    exit 1
fi

read -r job_pid < "$PID_FILE"

if ! kill -0 "$job_pid" 2>/dev/null; then
    echo "Job is no longer running: $job_pid"
    rm -f "$PID_FILE"
    exit 0
fi

job_name=$(basename "$(dirname "$PID_FILE")")
echo "Stopping job $job_name (PID $job_pid)"
kill -TERM "$job_pid"
