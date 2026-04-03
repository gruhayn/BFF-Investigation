#!/usr/bin/env bash
set -uo pipefail

# ─── Configuration ─────────────────────────────────────────────────────────────
NUM_ROUNDS=${1:-1}
GO_PORT=8080
SPRING_PORT=8084
GO_URL="http://localhost:${GO_PORT}"
SPRING_URL="http://localhost:${SPRING_PORT}"
ENDPOINT="/customer-summary?id=c1"
SAMPLE_INTERVAL=5  # seconds between metric samples

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PROFDIR="profiling_${TIMESTAMP}"
mkdir -p "$PROFDIR"
CSV="$PROFDIR/metrics_timeline.csv"
RESTART_LOG="$PROFDIR/restart_log.csv"

echo "timestamp,phase,round,go_rss_mb,spring_rss_mb,go_heap_mb,go_sys_mb,go_stack_mb,go_goroutines,go_heap_objects,go_gc_cycles,go_gc_pause_total_ms,go_gc_pause_last_us,spring_heap_mb,spring_nonheap_mb,spring_gc_count,spring_gc_time_ms,spring_gc_max_pause_ms,spring_threads" > "$CSV"
echo "timestamp,phase,service,reason" > "$RESTART_LOG"

# ─── PID / RSS helpers ────────────────────────────────────────────────────────
get_pid() {
  lsof -ti:"$1" -sTCP:LISTEN 2>/dev/null | head -1
}

get_rss_mb() {
  # Use vmmap physical footprint (accurate on macOS, especially for JVM)
  local pid=$1
  if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    echo "0"
    return
  fi
  local raw
  raw=$(vmmap --summary "$pid" 2>/dev/null | grep "Physical footprint:" | head -1 | awk '{print $NF}')
  if [[ -z "$raw" ]]; then
    echo "0"
    return
  fi
  # Parse value with unit suffix (e.g., "508.3M", "1.2G", "14.5K")
  local num unit
  num=$(echo "$raw" | sed 's/[^0-9.]//g')
  unit=$(echo "$raw" | sed 's/[0-9.]//g')
  case "$unit" in
    G) echo "$num" | awk '{printf "%.1f", $1 * 1024}' ;;
    M) echo "$num" | awk '{printf "%.1f", $1}' ;;
    K) echo "$num" | awk '{printf "%.1f", $1 / 1024}' ;;
    *) echo "$num" | awk '{printf "%.1f", $1 / 1048576}' ;;  # bytes
  esac
}

# ─── Metric collection ────────────────────────────────────────────────────────
collect_go_metrics() {
  curl -sf "${GO_URL}/memstats" 2>/dev/null || echo '{}'
}

collect_spring_metrics() {
  local heap nonheap gc_count gc_time gc_max threads
  heap=$(curl -sf "${SPRING_URL}/actuator/metrics/jvm.memory.used?tag=area:heap" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['measurements'][0]['value']/1048576)" 2>/dev/null || echo "0")
  nonheap=$(curl -sf "${SPRING_URL}/actuator/metrics/jvm.memory.used?tag=area:nonheap" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['measurements'][0]['value']/1048576)" 2>/dev/null || echo "0")
  gc_count=$(curl -sf "${SPRING_URL}/actuator/metrics/jvm.gc.pause" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin)['measurements']; print(int([m['value'] for m in d if m['statistic']=='COUNT'][0]))" 2>/dev/null || echo "0")
  gc_time=$(curl -sf "${SPRING_URL}/actuator/metrics/jvm.gc.pause" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin)['measurements']; print(round([m['value'] for m in d if m['statistic']=='TOTAL_TIME'][0]*1000))" 2>/dev/null || echo "0")
  gc_max=$(curl -sf "${SPRING_URL}/actuator/metrics/jvm.gc.pause" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin)['measurements']; print(round([m['value'] for m in d if m['statistic']=='MAX'][0]*1000))" 2>/dev/null || echo "0")
  threads=$(curl -sf "${SPRING_URL}/actuator/metrics/jvm.threads.live" 2>/dev/null | python3 -c "import sys,json; print(int(json.load(sys.stdin)['measurements'][0]['value']))" 2>/dev/null || echo "0")
  echo "${heap},${nonheap},${gc_count},${gc_time},${gc_max},${threads}"
}

sample_metrics() {
  local phase=$1 round=$2
  local ts go_pid spring_pid go_rss spring_rss
  ts=$(date +%Y-%m-%dT%H:%M:%S)
  go_pid=$(get_pid $GO_PORT)
  spring_pid=$(get_pid $SPRING_PORT)
  go_rss=$(get_rss_mb "$go_pid")
  spring_rss=$(get_rss_mb "$spring_pid")

  local go_json go_heap go_sys go_stack go_goroutines go_heap_objects go_gc_cycles go_gc_pause_total go_gc_pause_last
  go_json=$(collect_go_metrics)
  go_heap=$(echo "$go_json" | python3 -c "import sys,json; print(round(json.load(sys.stdin).get('heap_alloc_mb',0),2))" 2>/dev/null || echo "0")
  go_sys=$(echo "$go_json" | python3 -c "import sys,json; print(round(json.load(sys.stdin).get('sys_mb',0),2))" 2>/dev/null || echo "0")
  go_stack=$(echo "$go_json" | python3 -c "import sys,json; print(round(json.load(sys.stdin).get('stack_inuse_mb',0),2))" 2>/dev/null || echo "0")
  go_goroutines=$(echo "$go_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('goroutines',0))" 2>/dev/null || echo "0")
  go_heap_objects=$(echo "$go_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('heap_objects',0))" 2>/dev/null || echo "0")
  go_gc_cycles=$(echo "$go_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('gc_cycles',0))" 2>/dev/null || echo "0")
  go_gc_pause_total=$(echo "$go_json" | python3 -c "import sys,json; print(round(json.load(sys.stdin).get('gc_pause_total_ms',0),1))" 2>/dev/null || echo "0")
  go_gc_pause_last=$(echo "$go_json" | python3 -c "import sys,json; print(round(json.load(sys.stdin).get('gc_pause_last_us',0),1))" 2>/dev/null || echo "0")

  local spring_metrics
  spring_metrics=$(collect_spring_metrics)

  echo "${ts},${phase},${round},${go_rss},${spring_rss},${go_heap},${go_sys},${go_stack},${go_goroutines},${go_heap_objects},${go_gc_cycles},${go_gc_pause_total},${go_gc_pause_last},${spring_metrics}" >> "$CSV"
}

# ─── Auto-restart helpers ─────────────────────────────────────────────────────
ensure_go() {
  if ! curl -sf "${GO_URL}/health" > /dev/null 2>&1; then
    echo "[RESTART] Go is down during phase '$1' — restarting..."
    echo "$(date +%Y-%m-%dT%H:%M:%S),$1,go,health-check-failed" >> "$RESTART_LOG"
    lsof -ti:${GO_PORT} | xargs kill -9 2>/dev/null || true
    sleep 1
    cd "$(dirname "$0")/../investigate_bff_go" && go build -o investigate_bff_bin . && ./investigate_bff_bin &
    cd "$(dirname "$0")"
    sleep 3
  fi
}

ensure_spring() {
  if ! curl -sf "${SPRING_URL}${ENDPOINT}" > /dev/null 2>&1; then
    echo "[RESTART] Spring is down during phase '$1' — restarting..."
    echo "$(date +%Y-%m-%dT%H:%M:%S),$1,spring,health-check-failed" >> "$RESTART_LOG"
    lsof -ti:${SPRING_PORT} | xargs kill -9 2>/dev/null || true
    sleep 1
    cd "$(dirname "$0")/../investigate_bff_spring" && ./gradlew bootRun &
    cd "$(dirname "$0")"
    local retries=0
    while ! curl -sf "${SPRING_URL}${ENDPOINT}" > /dev/null 2>&1; do
      sleep 2
      retries=$((retries + 1))
      if [[ $retries -ge 30 ]]; then
        echo "[WARN] Spring did not come back after 60s"
        break
      fi
    done
  fi
}

# ─── Sampling loop (background) ──────────────────────────────────────────────
# Use temp files to communicate phase/round between main process and background sampler
PHASE_FILE=$(mktemp)
ROUND_FILE=$(mktemp)
echo "idle" > "$PHASE_FILE"
echo "0" > "$ROUND_FILE"

sampling_loop() {
  while true; do
    local phase round
    phase=$(cat "$PHASE_FILE" 2>/dev/null || echo "unknown")
    round=$(cat "$ROUND_FILE" 2>/dev/null || echo "0")
    sample_metrics "$phase" "$round"
    sleep "$SAMPLE_INTERVAL"
  done
}

set_phase() {
  echo "$1" > "$PHASE_FILE"
  echo "  [phase] $1"
}

# ─── Load test phases ────────────────────────────────────────────────────────
run_profiling_round() {
  local round=$1
  echo "$round" > "$ROUND_FILE"
  local RDIR="$PROFDIR/round_${round}"
  mkdir -p "$RDIR"

  echo "=== Round $round / $NUM_ROUNDS ==="

  ensure_go "pre_round_${round}"
  ensure_spring "pre_round_${round}"

  # idle baseline
  set_phase "idle"
  sleep 15

  # ── hey 50k ──
  set_phase "hey_50k_500c_go"
  hey -n 50000 -c 500 "${GO_URL}${ENDPOINT}" > "$RDIR/hey_go.txt" 2>&1
  ensure_spring "hey_50k_500c_go"

  set_phase "hey_50k_500c_spring"
  hey -n 50000 -c 500 "${SPRING_URL}${ENDPOINT}" > "$RDIR/hey_spring.txt" 2>&1
  ensure_go "hey_50k_500c_spring"

  # ── wrk ──
  set_phase "wrk_50c_go"
  wrk -t4 -c50 -d15s "${GO_URL}${ENDPOINT}" > "$RDIR/wrk_go_50c.txt" 2>&1
  ensure_spring "wrk_50c_go"

  set_phase "wrk_50c_spring"
  wrk -t4 -c50 -d15s "${SPRING_URL}${ENDPOINT}" > "$RDIR/wrk_spring_50c.txt" 2>&1
  ensure_go "wrk_50c_spring"

  set_phase "wrk_500c_go"
  wrk -t8 -c500 -d15s "${GO_URL}${ENDPOINT}" > "$RDIR/wrk_go_500c.txt" 2>&1
  ensure_spring "wrk_500c_go"

  set_phase "wrk_500c_spring"
  wrk -t8 -c500 -d15s "${SPRING_URL}${ENDPOINT}" > "$RDIR/wrk_spring_500c.txt" 2>&1
  ensure_go "wrk_500c_spring"

  # ── k6 ──
  set_phase "k6_ramp_go"
  BASE_URL="$GO_URL" k6 run k6_test.js > "$RDIR/k6_ramp_go.txt" 2>&1
  ensure_spring "k6_ramp_go"

  set_phase "k6_ramp_spring"
  BASE_URL="$SPRING_URL" k6 run k6_test.js > "$RDIR/k6_ramp_spring.txt" 2>&1
  ensure_go "k6_ramp_spring"

  set_phase "k6_stress_go"
  BASE_URL="$GO_URL" k6 run k6_stress.js > "$RDIR/k6_stress_go.txt" 2>&1
  ensure_spring "k6_stress_go"

  set_phase "k6_stress_spring"
  BASE_URL="$SPRING_URL" k6 run k6_stress.js > "$RDIR/k6_stress_spring.txt" 2>&1
  ensure_go "k6_stress_spring"

  set_phase "k6_spike_go"
  BASE_URL="$GO_URL" k6 run k6_spike.js > "$RDIR/k6_spike_go.txt" 2>&1
  ensure_spring "k6_spike_go"

  set_phase "k6_spike_spring"
  BASE_URL="$SPRING_URL" k6 run k6_spike.js > "$RDIR/k6_spike_spring.txt" 2>&1
  ensure_go "k6_spike_spring"

  set_phase "k6_multi_go"
  BASE_URL="$GO_URL" k6 run k6_multi_endpoint.js > "$RDIR/k6_multi_go.txt" 2>&1
  ensure_spring "k6_multi_go"

  set_phase "k6_multi_spring"
  BASE_URL="$SPRING_URL" k6 run k6_multi_endpoint.js > "$RDIR/k6_multi_spring.txt" 2>&1
  ensure_go "k6_multi_spring"

  # ── vegeta ──
  set_phase "vegeta_100_go"
  echo "GET ${GO_URL}${ENDPOINT}" | vegeta attack -rate=100 -duration=30s | vegeta report > "$RDIR/vegeta_go.txt" 2>&1
  ensure_spring "vegeta_100_go"

  set_phase "vegeta_100_spring"
  echo "GET ${SPRING_URL}${ENDPOINT}" | vegeta attack -rate=100 -duration=30s | vegeta report > "$RDIR/vegeta_spring.txt" 2>&1
  ensure_go "vegeta_100_spring"

  set_phase "vegeta_1k_go"
  echo "GET ${GO_URL}${ENDPOINT}" | vegeta attack -rate=1000 -duration=30s | vegeta report > "$RDIR/vegeta_go_1k.txt" 2>&1
  ensure_spring "vegeta_1k_go"

  set_phase "vegeta_1k_spring"
  echo "GET ${SPRING_URL}${ENDPOINT}" | vegeta attack -rate=1000 -duration=30s | vegeta report > "$RDIR/vegeta_spring_1k.txt" 2>&1
  ensure_go "vegeta_1k_spring"

  set_phase "vegeta_5k_go"
  echo "GET ${GO_URL}${ENDPOINT}" | vegeta attack -rate=5000 -duration=30s | vegeta report > "$RDIR/vegeta_go_5k.txt" 2>&1
  ensure_spring "vegeta_5k_go"

  set_phase "vegeta_5k_spring"
  echo "GET ${SPRING_URL}${ENDPOINT}" | vegeta attack -rate=5000 -duration=30s | vegeta report > "$RDIR/vegeta_spring_5k.txt" 2>&1
  ensure_go "vegeta_5k_spring"

  # ── ab ──
  set_phase "ab_50k_500c_spring"
  ab -n 50000 -c 500 "${SPRING_URL}${ENDPOINT}" > "$RDIR/ab_spring.txt" 2>&1
  ensure_go "ab_50k_500c_spring"

  # ── extra endpoint tests ──
  set_phase "hey_customers_50k_spring"
  hey -n 50000 -c 500 "${SPRING_URL}/customers" > "$RDIR/hey_spring_customers_50k.txt" 2>&1
  ensure_go "hey_customers_50k_spring"

  set_phase "hey_accounts_50k_go"
  hey -n 50000 -c 500 "${GO_URL}/accounts" > "$RDIR/hey_go_accounts_50k.txt" 2>&1
  ensure_spring "hey_accounts_50k_go"

  # ── cooldown ──
  set_phase "final_cooldown"
  sleep 40
}

# ─── Main ─────────────────────────────────────────────────────────────────────
echo "Starting profiling: $NUM_ROUNDS round(s), sampling every ${SAMPLE_INTERVAL}s"
echo "Output: $PROFDIR"

sampling_loop &
SAMPLER_PID=$!
trap "kill $SAMPLER_PID 2>/dev/null; wait $SAMPLER_PID 2>/dev/null; rm -f $PHASE_FILE $ROUND_FILE" EXIT

for r in $(seq 1 "$NUM_ROUNDS"); do
  run_profiling_round "$r"
done

kill $SAMPLER_PID 2>/dev/null
wait $SAMPLER_PID 2>/dev/null

SAMPLES=$(tail -n +2 "$CSV" | wc -l | tr -d ' ')
GO_RESTARTS=$(grep -c ",go," "$RESTART_LOG" 2>/dev/null || echo 0)
SPRING_RESTARTS=$(grep -c ",spring," "$RESTART_LOG" 2>/dev/null || echo 0)

echo ""
echo "=== Profiling complete ==="
echo "  Rounds:           $NUM_ROUNDS"
echo "  Samples:          $SAMPLES"
echo "  Go restarts:      $GO_RESTARTS"
echo "  Spring restarts:  $SPRING_RESTARTS"
echo "  Data:             $CSV"
