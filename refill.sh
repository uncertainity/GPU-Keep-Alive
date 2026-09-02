#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
STATE_DIR="${GPU_KEEPALIVE_STATE_DIR:-$SCRIPT_DIR}"
PENDING_DIR="$STATE_DIR/pending"
SUBMIT_SCRIPT="$SCRIPT_DIR/submit_job.sh"

if [[ $# -gt 1 ]]; then
    echo "Usage: $0 [path-to-fallback-job.sh]" >&2
    exit 1
fi

fallback_job="${1:-${GPU_KEEPALIVE_FALLBACK_JOB:-}}"
fallback_gpus="${GPU_KEEPALIVE_FALLBACK_GPUS:-${GPU_KEEPALIVE_GPUS:-0}}"

if [[ -z "$fallback_job" ]]; then
    echo "Usage: $0 <path-to-fallback-job.sh>" >&2
    echo "Alternatively, set GPU_KEEPALIVE_FALLBACK_JOB." >&2
    exit 1
fi

if [[ ! -f "$fallback_job" ]]; then
    echo "Error: fallback job does not exist: $fallback_job" >&2
    exit 1
fi

mkdir -p "$PENDING_DIR"

while true; do
    pending_count=$(find "$PENDING_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)

    if [[ "$pending_count" -eq 0 ]]; then
        "$SUBMIT_SCRIPT" --gpus "$fallback_gpus" "$fallback_job"
    fi

    sleep 5
done
