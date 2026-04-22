#!/usr/bin/env bash
# ─── Master Orchestrator V2 (all 5 servers) ───────────────────────────────────
# Runs perf tests for all 5 BFF implementations in sequence:
#   1. Go              port 8080
#   2. Spring MVC      port 8084
#   3. Virtual Threads port 8081
#   4. WebFlux         port 8082
#   5. Vert.x          port 8083
#
# All tests use identical conditions (ab=100c for all servers).
# Single results dir: results_v2_TIMESTAMP/{go,spring,vt,webflux,vertx}/
#
# Usage: bash run_master_v2.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common_v2.sh"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="${SCRIPT_DIR}/results_v2_${TIMESTAMP}"
GO_DIR="${RESULTS_DIR}/go"
SPRING_DIR="${RESULTS_DIR}/spring"
VT_DIR="${RESULTS_DIR}/vt"
WF_DIR="${RESULTS_DIR}/webflux"
VERTX_DIR="${RESULTS_DIR}/vertx"
mkdir -p "$GO_DIR" "$SPRING_DIR" "$VT_DIR" "$WF_DIR" "$VERTX_DIR"

echo "=================================================================="
echo " Performance Test Suite V2 — All 5 BFF Servers"
echo " Go | Spring | Virtual Threads | WebFlux | Vert.x"
echo " Output: ${RESULTS_DIR}"
echo " Started: $(date)"
echo "=================================================================="

# ─── Ensure all ports are free before starting ─────────────────────────────────
echo ""
echo ">>> Ensuring all ports are free..."
for port_name in "$GO_PORT:Go" "$SPRING_PORT:Spring" "$VT_PORT:VT" "$WF_PORT:WebFlux" "$VERTX_PORT:Vertx"; do
  port="${port_name%%:*}"
  name="${port_name##*:}"
  stop_server "$port" "${name} (cleanup)" 2>/dev/null || true
done
sleep 3

# ─── Run tests for one server ─────────────────────────────────────────────────
run_server_tests() {
  local server_type=$1   # "go","spring","vt","webflux","vertx"
  local base_url=$2
  local output_dir=$3
  local server_port=$4
  local start_time

  start_time=$(date +%s)
  CURRENT_SERVER="$server_type"
  METRICS_CSV="${output_dir}/metrics.csv"
  CRASH_LOG="${output_dir}/crash_log.csv"
  CRASH_COUNT_FILE="${output_dir}/.crash_count"
  echo "0" > "$CRASH_COUNT_FILE"

  # CSV header depends on server type
  if [[ "$server_type" == "go" ]]; then
    echo "timestamp,phase,rss_mb,heap_mb,sys_mb,stack_mb,goroutines,heap_objects,gc_cycles,gc_pause_total_ms,gc_pause_last_us" > "$METRICS_CSV"
  else
    echo "timestamp,phase,server,rss_mb,heap_mb,nonheap_mb,gc_count,gc_time_ms,gc_max_pause_ms,threads" > "$METRICS_CSV"
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
  case "$server_type" in
    go)      start_go_server ;;
    spring)  start_spring_server ;;
    vt)      start_vt_server ;;
    webflux) start_webflux_server ;;
    vertx)   start_vertx_server ;;
  esac

  # Verify all 3 endpoints respond with 200
  verify_endpoints "$base_url" "$server_upper"

  # Set up sampler state
  PHASE_FILE=$(mktemp)
  echo "idle" > "$PHASE_FILE"
  export CURRENT_SERVER METRICS_CSV CRASH_LOG PHASE_FILE CRASH_COUNT_FILE

  start_sampler

  # ─── Idle baseline ───────────────────────────────────────────────────────────
  set_phase "idle"
  echo ">>> Recording idle baseline (15s)..."
  sleep 15
  sample_to_csv "idle"

  local ep_urls=("/customers" "/accounts" "/customer-summary?id=c1")
  local ep_names=("customers" "accounts" "customer_summary")

  # ─── hey tests ───────────────────────────────────────────────────────────────
  echo ""
  echo "--- hey tests ---"
  for i in 0 1 2; do
    local ep="${ep_urls[$i]}"
    local name="${ep_names[$i]}"

    set_phase "hey_${name}_10k_200c"
    echo ">>> hey: ${name} 10k/200c"
    hey -n 10000 -c 200 "${base_url}${ep}" > "${output_dir}/hey_${name}_10k.txt" 2>&1
    sample_to_csv "hey_${name}_10k"
    health_check_and_recover "$server_type" "hey_${name}_10k"
    sleep "$COOLDOWN_SECONDS"

    set_phase "hey_${name}_50k_500c"
    echo ">>> hey: ${name} 50k/500c"
    hey -n 50000 -c 500 "${base_url}${ep}" > "${output_dir}/hey_${name}_50k.txt" 2>&1
    sample_to_csv "hey_${name}_50k"
    health_check_and_recover "$server_type" "hey_${name}_50k"
    sleep "$COOLDOWN_SECONDS"
  done

  # ─── k6 tests ────────────────────────────────────────────────────────────────
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
      health_check_and_recover "$server_type" "k6_${scenario}_${name}"
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
  health_check_and_recover "$server_type" "k6_multi"
  sleep "$COOLDOWN_SECONDS"

  # ─── ab tests (100c for ALL servers — standardized) ──────────────────────────
  echo ""
  echo "--- ab tests (100c standardized) ---"
  for i in 0 1 2; do
    local ep="${ep_urls[$i]}"
    local name="${ep_names[$i]}"
    set_phase "ab_${name}_50k"
    echo ">>> ab: ${name} 50k/100c"
    ab -n 50000 -c 100 "${base_url}${ep}" > "${output_dir}/ab_${name}_50k.txt" 2>&1
    sample_to_csv "ab_${name}_50k"
    health_check_and_recover "$server_type" "ab_${name}_50k"
    sleep "$COOLDOWN_SECONDS"
  done

  # ─── Final cooldown ───────────────────────────────────────────────────────────
  set_phase "final_cooldown"
  echo ">>> Final cooldown (30s)..."
  sleep 30
  sample_to_csv "final_cooldown"

  stop_sampler
  stop_server "$server_port" "$server_upper"

  local end_time elapsed samples crashes
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  samples=$(tail -n +2 "$METRICS_CSV" | wc -l | tr -d ' ')
  crashes=$(get_crash_count "$CRASH_COUNT_FILE")

  echo ""
  echo "  ${server_upper} done:"
  echo "    Duration:  ${elapsed}s"
  echo "    Samples:   ${samples}"
  echo "    Crashes:   ${crashes}"
  echo "    Output:    ${output_dir}"
  echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Phase 1: Go
# ═══════════════════════════════════════════════════════════════════════════════
run_server_tests "go"      "$GO_URL"     "$GO_DIR"     "$GO_PORT"
echo ">>> Pausing 5s between servers..."; sleep 5

# ═══════════════════════════════════════════════════════════════════════════════
#  Phase 2: Spring MVC
# ═══════════════════════════════════════════════════════════════════════════════
run_server_tests "spring"  "$SPRING_URL" "$SPRING_DIR" "$SPRING_PORT"
echo ">>> Pausing 5s between servers..."; sleep 5

# ═══════════════════════════════════════════════════════════════════════════════
#  Phase 3: Virtual Threads
# ═══════════════════════════════════════════════════════════════════════════════
run_server_tests "vt"      "$VT_URL"     "$VT_DIR"     "$VT_PORT"
echo ">>> Pausing 5s between servers..."; sleep 5

# ═══════════════════════════════════════════════════════════════════════════════
#  Phase 4: WebFlux
# ═══════════════════════════════════════════════════════════════════════════════
run_server_tests "webflux" "$WF_URL"     "$WF_DIR"     "$WF_PORT"
echo ">>> Pausing 5s between servers..."; sleep 5

# ═══════════════════════════════════════════════════════════════════════════════
#  Phase 5: Vert.x
# ═══════════════════════════════════════════════════════════════════════════════
run_server_tests "vertx"   "$VERTX_URL"  "$VERTX_DIR"  "$VERTX_PORT"

# ═══════════════════════════════════════════════════════════════════════════════
#  Final Summary
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "=================================================================="
echo " ALL TESTS COMPLETE — V2"
echo " Finished: $(date)"
echo " Results:  ${RESULTS_DIR}"
echo ""
for srv_info in "go:${GO_DIR}" "spring:${SPRING_DIR}" "vt:${VT_DIR}" "webflux:${WF_DIR}" "vertx:${VERTX_DIR}"; do
  srv="${srv_info%%:*}"
  dir="${srv_info##*:}"
  crash_file="${dir}/.crash_count"
  samples=$(tail -n +2 "${dir}/metrics.csv" 2>/dev/null | wc -l | tr -d ' ')
  crashes=$(get_crash_count "$crash_file")
  printf "  %-10s  samples=%-4s  crashes=%s\n" "$srv" "$samples" "$crashes"
done
echo ""
echo " Run extractor:"
echo "   python3 extract_perf_v2.py ${RESULTS_DIR}"
echo "=================================================================="
