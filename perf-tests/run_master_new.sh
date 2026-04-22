#!/usr/bin/env bash
# ─── Master Orchestrator (NEW: VT, WebFlux, Vert.x) ──────────────────────────
# Runs perf tests for the 3 new Kotlin services:
#   1. Virtual Threads (port 8081)  → run all tests → stop
#   2. WebFlux/Netty  (port 8082)   → run all tests → stop
#   3. Vert.x         (port 8083)   → run all tests → stop
#
# Usage: bash run_master_new.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common_new.sh"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="${SCRIPT_DIR}/results_new_${TIMESTAMP}"
VT_DIR="${RESULTS_DIR}/vt"
WF_DIR="${RESULTS_DIR}/webflux"
VERTX_DIR="${RESULTS_DIR}/vertx"
mkdir -p "$VT_DIR" "$WF_DIR" "$VERTX_DIR"

echo "=============================================================="
echo " Performance Test Suite — New JVM Services (VT | WF | Vert.x)"
echo " Output: ${RESULTS_DIR}"
echo " Started: $(date)"
echo "=============================================================="

# ─── Ensure ports are free ─────────────────────────────────────────────────────
echo ""
echo ">>> Ensuring ports ${VT_PORT}, ${WF_PORT}, ${VERTX_PORT} are free..."
stop_server $VT_PORT    "VT (cleanup)"     2>/dev/null || true
stop_server $WF_PORT    "WebFlux (cleanup)" 2>/dev/null || true
stop_server $VERTX_PORT "Vert.x (cleanup)" 2>/dev/null || true
sleep 2

# ─── Run tests for one server ─────────────────────────────────────────────────
run_server_tests() {
  local server_type=$1   # "vt", "webflux", "vertx"
  local base_url=$2
  local output_dir=$3
  local start_time

  start_time=$(date +%s)
  CURRENT_SERVER="$server_type"
  METRICS_CSV="${output_dir}/metrics.csv"
  CRASH_LOG="${output_dir}/crash_log.csv"
  CRASH_COUNT_FILE="${output_dir}/.crash_count"
  echo "0" > "$CRASH_COUNT_FILE"

  # CSV header: same schema for all JVM-based services
  echo "timestamp,phase,server,rss_mb,heap_mb,nonheap_mb,gc_count,gc_time_ms,gc_max_pause_ms,threads" > "$METRICS_CSV"
  echo "timestamp,phase,event" > "$CRASH_LOG"

  local server_upper
  server_upper=$(echo "$server_type" | tr '[:lower:]' '[:upper:]')

  echo ""
  echo "=============================="
  echo " ${server_upper} SERVER TESTS"
  echo "=============================="
  echo ""

  # Start server
  case "$server_type" in
    vt)      start_vt_server ;;
    webflux) start_webflux_server ;;
    vertx)   start_vertx_server ;;
  esac

  # Verify all 3 endpoints before running tests
  verify_endpoints "$base_url" "$server_upper"

  # Export state for sampler
  PHASE_FILE=$(mktemp)
  echo "idle" > "$PHASE_FILE"
  export CURRENT_SERVER METRICS_CSV CRASH_LOG PHASE_FILE CRASH_COUNT_FILE

  start_sampler

  # Idle baseline
  set_phase "idle"
  echo ">>> Recording idle baseline (15s)..."
  sleep 15
  sample_to_csv "idle"

  # ─── hey tests ────────────────────────────────────────────────────────────────
  echo ""
  echo "--- hey tests ---"
  local ep_urls=("/customers" "/accounts" "/customer-summary?id=c1")
  local ep_names=("customers" "accounts" "customer_summary")

  for i in 0 1 2; do
    local ep="${ep_urls[$i]}"
    local name="${ep_names[$i]}"

    set_phase "hey_${name}_10k_200c"
    echo ">>> hey: ${name} 10k/200c"
    hey -n 10000 -c 200 "${base_url}${ep}" > "${output_dir}/hey_${name}_10k.txt" 2>&1
    sample_to_csv "hey_${name}_10k"
    sleep "$COOLDOWN_SECONDS"

    set_phase "hey_${name}_50k_500c"
    echo ">>> hey: ${name} 50k/500c"
    hey -n 50000 -c 500 "${base_url}${ep}" > "${output_dir}/hey_${name}_50k.txt" 2>&1
    sample_to_csv "hey_${name}_50k"
    sleep "$COOLDOWN_SECONDS"
  done

  # ─── k6 tests ─────────────────────────────────────────────────────────────────
  echo ""
  echo "--- k6 tests ---"
  local k6_scenarios=("k6_test.js:ramp" "k6_stress.js:stress" "k6_spike.js:spike")

  for i in 0 1 2; do
    local ep="${ep_urls[$i]}"
    local name="${ep_names[$i]}"

    for scenario_entry in "${k6_scenarios[@]}"; do
      local js_file="${scenario_entry%%:*}"
      local scenario="${scenario_entry##*:}"
      set_phase "k6_${scenario}_${name}"
      echo ">>> k6: ${scenario} / ${name}"
      BASE_URL="$base_url" ENDPOINT="$ep" k6 run "${SCRIPT_DIR}/${js_file}" \
        --summary-export "${output_dir}/k6_${scenario}_${name}.json" \
        > "${output_dir}/k6_${scenario}_${name}.txt" 2>&1
      sample_to_csv "k6_${scenario}_${name}"
      sleep "$COOLDOWN_SECONDS"
    done
  done

  # k6 multi-endpoint
  set_phase "k6_multi"
  echo ">>> k6: multi-endpoint"
  BASE_URL="$base_url" k6 run "${SCRIPT_DIR}/k6_multi_endpoint.js" \
    --summary-export "${output_dir}/k6_multi.json" \
    > "${output_dir}/k6_multi.txt" 2>&1
  sample_to_csv "k6_multi"
  sleep "$COOLDOWN_SECONDS"

  # ─── ab tests ─────────────────────────────────────────────────────────────────
  echo ""
  echo "--- ab tests ---"
  for i in 0 1 2; do
    local ep="${ep_urls[$i]}"
    local name="${ep_names[$i]}"
    set_phase "ab_${name}_50k"
    echo ">>> ab: ${name} 50k/100c"
    ab -n 50000 -c 100 "${base_url}${ep}" > "${output_dir}/ab_${name}_50k.txt" 2>&1
    sample_to_csv "ab_${name}_50k"
    sleep "$COOLDOWN_SECONDS"
  done

  # ─── Final cooldown ───────────────────────────────────────────────────────────
  set_phase "final_cooldown"
  echo ">>> Final cooldown (30s)..."
  sleep 30
  sample_to_csv "final_cooldown"

  stop_sampler

  local port
  case "$server_type" in
    vt)      port=$VT_PORT ;;
    webflux) port=$WF_PORT ;;
    vertx)   port=$VERTX_PORT ;;
  esac
  stop_server "$port" "$server_upper"

  local end_time elapsed samples crashes
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  samples=$(tail -n +2 "$METRICS_CSV" | wc -l | tr -d ' ')
  crashes=$(get_crash_count "$CRASH_COUNT_FILE")

  echo ""
  echo "  ${server_upper} summary:"
  echo "    Duration:  ${elapsed}s"
  echo "    Samples:   ${samples}"
  echo "    Crashes:   ${crashes}"
  echo "    Output:    ${output_dir}"
  echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Phase 1: Virtual Threads
# ═══════════════════════════════════════════════════════════════════════════════
run_server_tests "vt" "$VT_URL" "$VT_DIR"
echo ">>> Pausing 5s between servers..."
sleep 5

# ═══════════════════════════════════════════════════════════════════════════════
#  Phase 2: WebFlux
# ═══════════════════════════════════════════════════════════════════════════════
run_server_tests "webflux" "$WF_URL" "$WF_DIR"
echo ">>> Pausing 5s between servers..."
sleep 5

# ═══════════════════════════════════════════════════════════════════════════════
#  Phase 3: Vert.x
# ═══════════════════════════════════════════════════════════════════════════════
run_server_tests "vertx" "$VERTX_URL" "$VERTX_DIR"

# ═══════════════════════════════════════════════════════════════════════════════
#  Final Summary
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "=============================================================="
echo " ALL TESTS COMPLETE"
echo " Finished: $(date)"
echo " Results:  ${RESULTS_DIR}"
echo ""
echo " VT crashes:     $(get_crash_count "${VT_DIR}/.crash_count")"
echo " WebFlux crashes: $(get_crash_count "${WF_DIR}/.crash_count")"
echo " Vert.x crashes: $(get_crash_count "${VERTX_DIR}/.crash_count")"
echo ""
echo " Metrics samples:"
echo "   VT:      $(tail -n +2 "${VT_DIR}/metrics.csv" | wc -l | tr -d ' ')"
echo "   WebFlux: $(tail -n +2 "${WF_DIR}/metrics.csv" | wc -l | tr -d ' ')"
echo "   Vert.x:  $(tail -n +2 "${VERTX_DIR}/metrics.csv" | wc -l | tr -d ' ')"
echo "=============================================================="
