#!/usr/bin/env bash
# ─── Master Orchestrator ──────────────────────────────────────────────────────
# Runs ALL perf + profiling tests with server isolation:
#   1. Start Go server → run all tests → stop Go
#   2. Start Spring server → run all tests → stop Spring
#
# Usage: bash run_master.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="${SCRIPT_DIR}/results_${TIMESTAMP}"
GO_DIR="${RESULTS_DIR}/go"
SPRING_DIR="${RESULTS_DIR}/spring"
mkdir -p "$GO_DIR" "$SPRING_DIR"

echo "=============================================="
echo " Performance Test Suite — Isolated Execution"
echo " Output: ${RESULTS_DIR}"
echo " Started: $(date)"
echo "=============================================="

# ─── Ensure ports are free ─────────────────────────────────────────────────────
echo ""
echo ">>> Ensuring ports $GO_PORT and $SPRING_PORT are free..."
stop_server $GO_PORT "Go (cleanup)" 2>/dev/null || true
stop_server $SPRING_PORT "Spring (cleanup)" 2>/dev/null || true
sleep 2

# ─── Run tests for one server ─────────────────────────────────────────────────
run_server_tests() {
  local server_type=$1  # "go" or "spring"
  local base_url=$2
  local output_dir=$3
  local start_time

  start_time=$(date +%s)
  CURRENT_SERVER="$server_type"
  METRICS_CSV="${output_dir}/metrics.csv"
  CRASH_LOG="${output_dir}/crash_log.csv"

  # Initialize crash count files
  GO_CRASH_COUNT_FILE="${output_dir}/.go_crash_count"
  SPRING_CRASH_COUNT_FILE="${output_dir}/.spring_crash_count"
  echo "0" > "$GO_CRASH_COUNT_FILE"
  echo "0" > "$SPRING_CRASH_COUNT_FILE"

  # Initialize CSV headers
  if [[ "$server_type" == "go" ]]; then
    echo "timestamp,phase,rss_mb,heap_mb,sys_mb,stack_mb,goroutines,heap_objects,gc_cycles,gc_pause_total_ms,gc_pause_last_us" > "$METRICS_CSV"
  else
    echo "timestamp,phase,rss_mb,heap_mb,nonheap_mb,gc_count,gc_time_ms,gc_max_pause_ms,threads" > "$METRICS_CSV"
  fi
  echo "timestamp,phase,event" > "$CRASH_LOG"

  local server_upper
  server_upper=$(echo "$server_type" | tr '[:lower:]' '[:upper:]')

  echo ""
  echo "=============================="
  echo " ${server_upper} SERVER TESTS"
  echo "=============================="
  echo ""

  # Start server
  if [[ "$server_type" == "go" ]]; then
    start_go_server
  else
    start_spring_server
  fi

  # Export state for child test scripts
  # Create PHASE_FILE before start_sampler so it can be exported
  PHASE_FILE=$(mktemp)
  echo "idle" > "$PHASE_FILE"
  export CURRENT_SERVER METRICS_CSV CRASH_LOG PHASE_FILE GO_CRASH_COUNT_FILE SPRING_CRASH_COUNT_FILE

  # Start background sampler (uses existing PHASE_FILE)
  start_sampler

  # Idle baseline (15s)
  set_phase "idle"
  echo ">>> Recording idle baseline (15s)..."
  sleep 15
  sample_to_csv "idle"

  # Run all test suites sequentially
  echo ""
  echo "--- hey tests ---"
  bash "$SCRIPT_DIR/tests/test_hey.sh" "$base_url" "$output_dir" "$server_type"

  echo ""
  echo "--- wrk tests ---"
  bash "$SCRIPT_DIR/tests/test_wrk.sh" "$base_url" "$output_dir" "$server_type"

  echo ""
  echo "--- k6 tests ---"
  bash "$SCRIPT_DIR/tests/test_k6.sh" "$base_url" "$output_dir" "$server_type"

  echo ""
  echo "--- vegeta tests ---"
  bash "$SCRIPT_DIR/tests/test_vegeta.sh" "$base_url" "$output_dir" "$server_type"

  echo ""
  echo "--- ab tests ---"
  bash "$SCRIPT_DIR/tests/test_ab.sh" "$base_url" "$output_dir" "$server_type"

  # Final cooldown (30s)
  set_phase "final_cooldown"
  echo ">>> Final cooldown (30s)..."
  sleep 30
  sample_to_csv "final_cooldown"

  # Stop sampler and server
  stop_sampler

  local port
  if [[ "$server_type" == "go" ]]; then
    port=$GO_PORT
  else
    port=$SPRING_PORT
  fi
  stop_server "$port" "$server_upper"

  local end_time elapsed
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))

  local samples crashes
  samples=$(tail -n +2 "$METRICS_CSV" | wc -l | tr -d ' ')
  if [[ "$server_type" == "go" ]]; then
    crashes=$(get_crash_count "$GO_CRASH_COUNT_FILE")
  else
    crashes=$(get_crash_count "$SPRING_CRASH_COUNT_FILE")
  fi

  echo ""
  echo "  ${server_upper} summary:"
  echo "    Duration:  ${elapsed}s"
  echo "    Samples:   ${samples}"
  echo "    Crashes:   ${crashes}"
  echo "    Output:    ${output_dir}"
  echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Phase 1: GO
# ═══════════════════════════════════════════════════════════════════════════════
run_server_tests "go" "$GO_URL" "$GO_DIR"

# Brief pause between servers to let OS reclaim resources
echo ">>> Pausing 5s between servers..."
sleep 5

# ═══════════════════════════════════════════════════════════════════════════════
#  Phase 2: SPRING
# ═══════════════════════════════════════════════════════════════════════════════
run_server_tests "spring" "$SPRING_URL" "$SPRING_DIR"

# ═══════════════════════════════════════════════════════════════════════════════
#  Final Summary
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "=============================================="
echo " ALL TESTS COMPLETE"
echo " Finished: $(date)"
echo " Results:  ${RESULTS_DIR}"
echo ""
echo " Go crashes:     $(get_crash_count "$GO_DIR/.go_crash_count")"
echo " Spring crashes: $(get_crash_count "$SPRING_DIR/.spring_crash_count")"
echo ""
echo " Files per server:"
ls "$GO_DIR"/*.txt 2>/dev/null | wc -l | xargs echo "   Go test files:    "
ls "$SPRING_DIR"/*.txt 2>/dev/null | wc -l | xargs echo "   Spring test files:"
echo ""
echo " Metrics:"
echo "   Go:     $(tail -n +2 "$GO_DIR/metrics.csv" | wc -l | tr -d ' ') samples"
echo "   Spring: $(tail -n +2 "$SPRING_DIR/metrics.csv" | wc -l | tr -d ' ') samples"
echo "=============================================="
