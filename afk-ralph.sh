#!/usr/bin/env bash
# afk-ralph.sh — Run Ralph Loop autonomously for N iterations
# Usage: ./afk-ralph.sh [max_iterations]
# Default: 20 iterations

set -euo pipefail

MAX_ITERATIONS="${1:-20}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/ralph-log.txt"

echo "=== Ralph Loop Started: $(date) ===" | tee -a "$LOG_FILE"
echo "Max iterations: $MAX_ITERATIONS" | tee -a "$LOG_FILE"

for i in $(seq 1 "$MAX_ITERATIONS"); do
  echo "" | tee -a "$LOG_FILE"
  echo "--- Iteration $i of $MAX_ITERATIONS: $(date) ---" | tee -a "$LOG_FILE"

  OUTPUT=$(bash "${SCRIPT_DIR}/ralph-once.sh" 2>&1) || true

  echo "$OUTPUT" >> "$LOG_FILE"

  if echo "$OUTPUT" | grep -q '<promise>COMPLETE</promise>'; then
    echo "" | tee -a "$LOG_FILE"
    echo "=== ALL TASKS COMPLETE at iteration $i: $(date) ===" | tee -a "$LOG_FILE"
    exit 0
  fi

  echo "Iteration $i completed. Continuing..." | tee -a "$LOG_FILE"
  sleep 5
done

echo "" | tee -a "$LOG_FILE"
echo "=== Ralph Loop finished $MAX_ITERATIONS iterations without completion: $(date) ===" | tee -a "$LOG_FILE"
exit 1
