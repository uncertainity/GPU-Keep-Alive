#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
result_file="$SCRIPT_DIR/non_dummy_test_result.txt"
printf 'started=%s pid=%s\n' "$(date --iso-8601=seconds)" "$$" > "$result_file"
sleep 10
printf 'finished=%s pid=%s\n' "$(date --iso-8601=seconds)" "$$" >> "$result_file"
