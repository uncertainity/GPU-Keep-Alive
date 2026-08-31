#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
STATE_DIR="${GPU_KEEPALIVE_STATE_DIR:-$SCRIPT_DIR}"
PENDING_DIR="$STATE_DIR/pending"
RUNNING_DIR="$STATE_DIR/running"
FINISHED_DIR="$STATE_DIR/finished"
FAILED_DIR="$STATE_DIR/failed"

mkdir -p \
    "$PENDING_DIR" \
    "$RUNNING_DIR" \
    "$FINISHED_DIR" \
    "$FAILED_DIR"

pick_next_job() {
    find "$PENDING_DIR" -maxdepth 1 -type f -printf '%T@ %p\n' \
        | sort -n \
        | head -n 1 \
        | cut -d' ' -f2-
}


while true; do
    # Pick the oldest job based on timestamped filename.
    job_path=$(pick_next_job)

    # No pending job exists.
    if [[ -z "$job_path" ]]; then
        sleep 2
        continue
    fi

    job_name=$(basename "$job_path")
    running_path="$RUNNING_DIR/$job_name"

    echo "Claiming job: $job_name"

    # Move pending -> running.
    mv "$job_path" "$running_path"

    echo "Running job: $job_name"

    # Execute the shell script and wait for it to finish.
    bash "$running_path" & job_pid=$!
    echo "$job_pid" > "$RUNNING_DIR/active_pids.txt"
    wait "$job_pid"
    exit_code=$?
    rm -f "$RUNNING_DIR/active_pids.txt"

    if [[ $exit_code -eq 0 ]]; then
        echo "Job succeeded: $job_name"
        mv "$running_path" "$FINISHED_DIR/$job_name"
    else
        echo "Job failed with exit code $exit_code: $job_name"
        mv "$running_path" "$FAILED_DIR/$job_name"
    fi
done
