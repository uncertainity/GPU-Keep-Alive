#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
STATE_DIR="${GPU_KEEPALIVE_STATE_DIR:-$SCRIPT_DIR}"
PENDING_DIR="$STATE_DIR/pending"
gpu_ids=""

if [[ "${1:-}" == "--gpus" && $# -eq 3 ]]; then
    gpu_ids="$2"
    shift 2
else
    echo "Usage: $0 --gpus <id[,id...]> <job.sh>" >&2
    exit 1
fi

if [[ ! "$gpu_ids" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
    echo "Error: GPUs must be a comma-separated list of numeric IDs." >&2
    exit 1
fi

source_job="$1"

if [[ ! -f "$source_job" ]]; then
    echo "Error: file does not exist: $source_job" >&2
    exit 1
fi

mkdir -p "$PENDING_DIR"

timestamp=$(date +%Y%m%d_%H%M%S_%N)
original_name=$(basename "$source_job")
job_id="${timestamp}_${original_name}"
job_dir="$PENDING_DIR/$job_id"
staging_dir="$STATE_DIR/.${job_id}.submitting"

mkdir "$staging_dir"
trap 'rm -rf -- "$staging_dir"' EXIT

cp -- "$source_job" "$staging_dir/job.sh"
printf '%s\n' "$gpu_ids" > "$staging_dir/gpu_ids"
mv -- "$staging_dir" "$job_dir"
trap - EXIT

echo "Submitted: $job_id (GPUs: $gpu_ids)"
