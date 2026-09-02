#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
STATE_DIR="${GPU_KEEPALIVE_STATE_DIR:-$SCRIPT_DIR}"
PENDING_DIR="$STATE_DIR/pending"
RUNNING_DIR="$STATE_DIR/running"
FINISHED_DIR="$STATE_DIR/finished"
FAILED_DIR="$STATE_DIR/failed"
GPU_LIST="${GPU_KEEPALIVE_GPUS:-0}"

if [[ ! "$GPU_LIST" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
    echo "Error: GPU_KEEPALIVE_GPUS must be a comma-separated list of GPU IDs." >&2
    exit 1
fi

IFS=',' read -r -a MANAGED_GPUS <<< "$GPU_LIST"

declare -A JOB_PID=()
declare -A JOB_PATH=()
declare -A JOB_GPUS=()
declare -A GPU_OWNER=()

for gpu in "${MANAGED_GPUS[@]}"; do
    if [[ ${GPU_OWNER[$gpu]+exists} ]]; then
        echo "Error: duplicate GPU ID in GPU_KEEPALIVE_GPUS: $gpu" >&2
        exit 1
    fi
    GPU_OWNER["$gpu"]=""
done

mkdir -p \
    "$PENDING_DIR" \
    "$RUNNING_DIR" \
    "$FINISHED_DIR" \
    "$FAILED_DIR"

scan_pending_jobs() {
    local timestamp job_dir requested_gpus

    while read -r timestamp job_dir; do
        [[ -n "${job_dir:-}" ]] || continue

        if [[ ! -f "$job_dir/job.sh" || ! -f "$job_dir/gpu_ids" ]]; then
            echo "Skipping invalid job directory: $job_dir" >&2
            continue
        fi

        requested_gpus=$(< "$job_dir/gpu_ids")

        if gpus_are_free "$requested_gpus"; then
            launch_job "$job_dir" "$requested_gpus"
        fi
    done < <(
        find "$PENDING_DIR" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -printf '%T@ %p\n' \
            | sort -n
    )
}

gpus_are_free() {
    local requested_gpus="$1"
    local gpu
    local -a requested

    # Reject malformed GPU lists.
    if [[ ! "$requested_gpus" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
        return 1
    fi

    IFS=',' read -r -a requested <<< "$requested_gpus"

    for gpu in "${requested[@]}"; do
        # The GPU is not managed by this worker.
        if [[ ! ${GPU_OWNER[$gpu]+exists} ]]; then
            return 1
        fi

        # The GPU already belongs to another running job.
        if [[ -n "${GPU_OWNER[$gpu]}" ]]; then
            return 1
        fi
    done

    return 0
}

launch_job() {
    local job_dir="$1"
    local requested_gpus="$2"
    local job_name running_path job_pid gpu
    local -a used_gpus

    job_name=$(basename "$job_dir")
    running_path="$RUNNING_DIR/$job_name"
    mv -- "$job_dir" "$running_path"

    CUDA_VISIBLE_DEVICES="$requested_gpus" bash "$running_path/job.sh" & job_pid=$!
    JOB_PID["$job_name"]="$job_pid"
    JOB_PATH["$job_name"]="$running_path"
    JOB_GPUS["$job_name"]="$requested_gpus"

    IFS=',' read -r -a used_gpus <<< "$requested_gpus"
    for gpu in "${used_gpus[@]}"; do
        GPU_OWNER["$gpu"]="$job_name"
    done

    printf '%s\n' "$job_pid" > "$running_path/active_pid"

    echo "Launching: $job_name"
    echo "PID: $job_pid"
    echo "GPUs: $requested_gpus"
}

reap_finished_jobs() {
    local job_name pid exit_code gpu running_path
    local -a used_gpus

    for job_name in "${!JOB_PID[@]}"; do
        pid="${JOB_PID[$job_name]}"

        if kill -0 "$pid" 2>/dev/null; then
            continue
        fi

        if wait "$pid"; then
            exit_code=0
        else
            exit_code=$?
        fi

        running_path="${JOB_PATH[$job_name]}"
        rm -f -- "$running_path/active_pid"

        if [[ $exit_code -eq 0 ]]; then
            echo "Job succeeded: $job_name"
            mv -- "$running_path" "$FINISHED_DIR/$job_name"
        else
            echo "Job failed with exit code $exit_code: $job_name"
            mv -- "$running_path" "$FAILED_DIR/$job_name"
        fi

        IFS=',' read -r -a used_gpus <<< "${JOB_GPUS[$job_name]}"
        for gpu in "${used_gpus[@]}"; do
            GPU_OWNER["$gpu"]=""
        done
        unset 'JOB_PID[$job_name]'
        unset 'JOB_PATH[$job_name]'
        unset 'JOB_GPUS[$job_name]'
    done
}



while true; do
    reap_finished_jobs
    scan_pending_jobs
    sleep 1
done
