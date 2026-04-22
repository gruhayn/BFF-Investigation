#!/usr/bin/env bash
# ─── Shared functions for NEW perf test infrastructure (VT, WebFlux, Vert.x) ──
# Sourced by run_master_new.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VT_PROJECT_DIR="${SCRIPT_DIR}/../investigate_bff_virtual_threads"
WF_PROJECT_DIR="${SCRIPT_DIR}/../investigate_bff_webflux"
VERTX_PROJECT_DIR="${SCRIPT_DIR}/../investigate_bff_vertx"

VT_PORT=8081
WF_PORT=8082
VERTX_PORT=8083

VT_URL="http://localhost:${VT_PORT}"
WF_URL="http://localhost:${WF_PORT}"
VERTX_URL="http://localhost:${VERTX_PORT}"

SAMPLE_INTERVAL=5
COOLDOWN_SECONDS=15

# ─── Crash tracking ────────────────────────────────────────────────────────────
increment_crash_count() {
  local file=$1
  local current
  current=$(cat "$file" 2>/dev/null || echo "0")
  echo $((current + 1)) > "$file"
}

get_crash_count() {
  cat "$1" 2>/dev/null || echo "0"
}

# ─── State files (set by run_master_new.sh before starting sampler) ────────────
PHASE_FILE="${PHASE_FILE:-}"
METRICS_CSV="${METRICS_CSV:-}"
CRASH_LOG="${CRASH_LOG:-}"
CURRENT_SERVER="${CURRENT_SERVER:-}"   # "vt", "webflux", or "vertx"
SAMPLER_PID="${SAMPLER_PID:-}"
CRASH_COUNT_FILE="${CRASH_COUNT_FILE:-}"

# ─── PID / RSS helpers ─────────────────────────────────────────────────────────
get_pid() {
  lsof -ti:"$1" -sTCP:LISTEN 2>/dev/null | head -1
}

get_rss_mb() {
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
  local num unit
  num=$(echo "$raw" | sed 's/[^0-9.]//g')
  unit=$(echo "$raw" | sed 's/[0-9.]//g')
  case "$unit" in
    G) echo "$num" | awk '{printf "%.1f", $1 * 1024}' ;;
    M) echo "$num" | awk '{printf "%.1f", $1}' ;;
    K) echo "$num" | awk '{printf "%.1f", $1 / 1024}' ;;
    *) echo "$num" | awk '{printf "%.1f", $1 / 1048576}' ;;
  esac
}

# ─── Spring-compatible metric collector (works for VT and WebFlux via Actuator) ─
collect_jvm_metrics() {
  local base_url=$1
  local heap nonheap gc_count gc_time gc_max threads
  heap=$(curl -sf "${base_url}/actuator/metrics/jvm.memory.used?tag=area:heap" 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['measurements'][0]['value']/1048576)" 2>/dev/null || echo "0")
  nonheap=$(curl -sf "${base_url}/actuator/metrics/jvm.memory.used?tag=area:nonheap" 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['measurements'][0]['value']/1048576)" 2>/dev/null || echo "0")
  gc_count=$(curl -sf "${base_url}/actuator/metrics/jvm.gc.pause" 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin)['measurements']; print(int([m['value'] for m in d if m['statistic']=='COUNT'][0]))" 2>/dev/null || echo "0")
  gc_time=$(curl -sf "${base_url}/actuator/metrics/jvm.gc.pause" 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin)['measurements']; print(round([m['value'] for m in d if m['statistic']=='TOTAL_TIME'][0]*1000))" 2>/dev/null || echo "0")
  gc_max=$(curl -sf "${base_url}/actuator/metrics/jvm.gc.pause" 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin)['measurements']; print(round([m['value'] for m in d if m['statistic']=='MAX'][0]*1000))" 2>/dev/null || echo "0")
  threads=$(curl -sf "${base_url}/actuator/metrics/jvm.threads.live" 2>/dev/null \
    | python3 -c "import sys,json; print(int(json.load(sys.stdin)['measurements'][0]['value']))" 2>/dev/null || echo "0")
  echo "${heap},${nonheap},${gc_count},${gc_time},${gc_max},${threads}"
}

# Vert.x exposes /memstats with JVM heap info
collect_vertx_metrics() {
  local base_url=$1
  local json heap_used heap_max gc_count gc_time threads
  json=$(curl -sf "${base_url}/memstats" 2>/dev/null || echo '{}')
  heap_used=$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(round(d.get('heapUsed',0)/1048576,2))" 2>/dev/null || echo "0")
  heap_max=$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(round(d.get('heapMax',0)/1048576,2))" 2>/dev/null || echo "0")
  gc_count=$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(g.get('count',0) for g in d.get('gc',[])))" 2>/dev/null || echo "0")
  gc_time=$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(g.get('time',0) for g in d.get('gc',[])))" 2>/dev/null || echo "0")
  # Vert.x doesn't expose thread count via /memstats; use 0 as placeholder
  threads=0
  echo "${heap_used},${heap_max},${gc_count},${gc_time},${threads}"
}

# ─── Sample one row to CSV ─────────────────────────────────────────────────────
# CSV columns (all JVM-based servers):
#   timestamp,phase,server,rss_mb,heap_mb,nonheap_mb,gc_count,gc_time_ms,gc_max_pause_ms,threads
sample_to_csv() {
  local phase=${1:-$(cat "$PHASE_FILE" 2>/dev/null || echo "unknown")}
  local ts
  ts=$(date +%Y-%m-%dT%H:%M:%S)

  local port url
  case "$CURRENT_SERVER" in
    vt)     port=$VT_PORT;    url=$VT_URL ;;
    webflux) port=$WF_PORT;   url=$WF_URL ;;
    vertx)  port=$VERTX_PORT; url=$VERTX_URL ;;
    *)      echo "unknown server: $CURRENT_SERVER"; return ;;
  esac

  local pid rss
  pid=$(get_pid "$port")
  rss=$(get_rss_mb "$pid")

  if [[ "$CURRENT_SERVER" == "vertx" ]]; then
    local metrics
    metrics=$(collect_vertx_metrics "$url")
    # vertx: heap_used_mb, heap_max_mb, gc_count, gc_time_ms, threads(0)
    # Map into same schema: heap_mb=heap_used, nonheap_mb=heap_max, gc_count, gc_time_ms, gc_max=0, threads
    local heap nonheap gc_count gc_time threads
    IFS=',' read -r heap nonheap gc_count gc_time threads <<< "$metrics"
    echo "${ts},${phase},${CURRENT_SERVER},${rss},${heap},${nonheap},${gc_count},${gc_time},0,${threads}" >> "$METRICS_CSV"
  else
    local metrics
    metrics=$(collect_jvm_metrics "$url")
    echo "${ts},${phase},${CURRENT_SERVER},${rss},${metrics}" >> "$METRICS_CSV"
  fi
}

# ─── Phase management ──────────────────────────────────────────────────────────
set_phase() {
  echo "$1" > "$PHASE_FILE"
  echo "  [phase] $1"
}

# ─── Background sampling loop ──────────────────────────────────────────────────
sampling_loop() {
  while true; do
    local phase
    phase=$(cat "$PHASE_FILE" 2>/dev/null || echo "unknown")
    sample_to_csv "$phase"
    sleep "$SAMPLE_INTERVAL"
  done
}

start_sampler() {
  if [[ -z "$PHASE_FILE" ]]; then
    PHASE_FILE=$(mktemp)
    echo "idle" > "$PHASE_FILE"
  fi
  sampling_loop &
  SAMPLER_PID=$!
  echo "  [sampler] started (PID=$SAMPLER_PID, interval=${SAMPLE_INTERVAL}s)"
}

stop_sampler() {
  if [[ -n "$SAMPLER_PID" ]]; then
    kill "$SAMPLER_PID" 2>/dev/null
    wait "$SAMPLER_PID" 2>/dev/null
    SAMPLER_PID=""
    echo "  [sampler] stopped"
  fi
  [[ -n "$PHASE_FILE" ]] && rm -f "$PHASE_FILE"
}

# ─── Server management ─────────────────────────────────────────────────────────
wait_ready() {
  local url=$1 name=$2 max_retries=${3:-30}
  for i in $(seq 1 "$max_retries"); do
    if curl -sf "$url" > /dev/null 2>&1; then
      echo "  $name is ready (attempt $i)"
      return 0
    fi
    sleep 2
  done
  echo "  WARNING: $name not responding after $((max_retries * 2))s"
  return 1
}

stop_server() {
  local port=$1 name=$2
  echo ">>> Stopping $name (port $port)..."
  local pids
  pids=$(lsof -ti:"$port" 2>/dev/null || true)
  if [[ -n "$pids" ]]; then
    echo "$pids" | xargs kill -9 2>/dev/null || true
    sleep 2
  fi
  local retries=0
  while lsof -ti:"$port" > /dev/null 2>&1; do
    sleep 1
    retries=$((retries + 1))
    if [[ $retries -ge 10 ]]; then
      echo "  WARNING: port $port still in use after 10s"
      lsof -ti:"$port" | xargs kill -9 2>/dev/null || true
      sleep 2
      break
    fi
  done
  echo "  $name stopped"
}

start_vt_server() {
  echo ">>> Starting Virtual Threads server (port ${VT_PORT})..."
  pushd "$VT_PROJECT_DIR" > /dev/null
  nohup ./gradlew bootRun > /tmp/vt_server.log 2>&1 &
  popd > /dev/null
  wait_ready "${VT_URL}/actuator/health" "VirtualThreads" 60
}

start_webflux_server() {
  echo ">>> Starting WebFlux server (port ${WF_PORT})..."
  pushd "$WF_PROJECT_DIR" > /dev/null
  nohup ./gradlew bootRun > /tmp/wf_server.log 2>&1 &
  popd > /dev/null
  wait_ready "${WF_URL}/actuator/health" "WebFlux" 60
}

start_vertx_server() {
  echo ">>> Starting Vert.x server (port ${VERTX_PORT})..."
  local jar="${VERTX_PROJECT_DIR}/build/libs/investigate-bff-vertx.jar"
  if [[ ! -f "$jar" ]]; then
    echo "  Building Vert.x JAR..."
    pushd "$VERTX_PROJECT_DIR" > /dev/null
    ./gradlew shadowJar -q
    popd > /dev/null
  fi
  nohup java -jar "$jar" > /tmp/vertx_server.log 2>&1 &
  wait_ready "${VERTX_URL}/health" "Vertx" 30
}

# ─── Endpoint verification ─────────────────────────────────────────────────────
verify_endpoints() {
  local base_url=$1 name=$2
  local all_ok=true
  echo "  Verifying endpoints for $name..."
  for path in "/customers" "/accounts" "/customer-summary?id=c1"; do
    local code
    code=$(curl -sf -o /dev/null -w "%{http_code}" "${base_url}${path}" 2>/dev/null || echo "000")
    if [[ "$code" == "200" ]]; then
      echo "    [OK] ${base_url}${path} => $code"
    else
      echo "    [FAIL] ${base_url}${path} => $code"
      all_ok=false
    fi
  done
  if [[ "$all_ok" == "false" ]]; then
    echo "  ERROR: Endpoint verification failed for $name. Aborting."
    exit 1
  fi
  echo "  All endpoints OK for $name"
}
