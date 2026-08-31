#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
STATE_DIR="${GPU_KEEPALIVE_STATE_DIR:-$SCRIPT_DIR}"
PENDING_DIR="$STATE_DIR/pending"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <path-to-job.sh>" >&2
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
queued_name="${timestamp}_${original_name}"

cp -- "$source_job" "$PENDING_DIR/$queued_name"

echo "Submitted: $queued_name"
