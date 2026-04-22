#!/usr/bin/env bash
# ─── Shared functions for perf-test V2 (all 5 servers) ────────────────────────
# Sourced by run_master_v2.sh
#
# Servers:
#   go      port 8080  health=/health      metrics=/memstats (Go schema)
#   spring  port 8084  health=/actuator/health  metrics=Actuator (JVM schema)
#   vt      port 8081  health=/actuator/health  metrics=Actuator (JVM schema)
#   webflux port 8082  health=/actuator/health  metrics=Actuator (JVM schema)
#   vertx   port 8083  health=/health      metrics=/memstats (Vert.x schema)

set -uo pipefail

# ─── Project paths ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GO_PROJECT_DIR="${SCRIPT_DIR}/../investigate_bff_go"
SPRING_PROJECT_DIR="${SCRIPT_DIR}/../investigate_bff_spring"
VT_PROJECT_DIR="${SCRIPT_DIR}/../investigate_bff_virtual_threads"
WF_PROJECT_DIR="${SCRIPT_DIR}/../investigate_bff_webflux"
VERTX_PROJECT_DIR="${SCRIPT_DIR}/../investigate_bff_vertx"

GO_PORT=8080
SPRING_PORT=8084
VT_PORT=8081
WF_PORT=8082
VERTX_PORT=8083

GO_URL="http://localhost:${GO_PORT}"
SPRING_URL="http://localhost:${SPRING_PORT}"
VT_URL="http://localhost:${VT_PORT}"
WF_URL="http://localhost:${WF_PORT}"
VERTX_URL="http://localhost:${VERTX_PORT}"

SAMPLE_INTERVAL=5
COOLDOWN_SECONDS=15

# ─── Crash tracking ────────────────────────────────────────────────────────────
CRASH_COUNT_FILE="${CRASH_COUNT_FILE:-}"

increment_crash_count() {
  local file=$1
  local current
  current=$(cat "$file" 2>/dev/null || echo "0")
  echo $((current + 1)) > "$file"
}

get_crash_count() {
  cat "$1" 2>/dev/null || echo "0"
}

# ─── State files (set by run_master_v2.sh before starting sampler) ─────────────
PHASE_FILE="${PHASE_FILE:-}"
METRICS_CSV="${METRICS_CSV:-}"
CRASH_LOG="${CRASH_LOG:-}"
CURRENT_SERVER="${CURRENT_SERVER:-}"   # "go","spring","vt","webflux","vertx"
SAMPLER_PID="${SAMPLER_PID:-}"

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

# ─── Metric collection ─────────────────────────────────────────────────────────

# Go: reads /memstats → goroutines schema
collect_go_metrics() {
  curl -sf "${GO_URL}/memstats" 2>/dev/null || echo '{}'
}

# Spring/VT/WebFlux: reads Spring Actuator → JVM schema
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

# Vert.x: reads /memstats → heap/gc schema, threads=0
collect_vertx_metrics() {
  local base_url=$1
  local json heap_used heap_max gc_count gc_time
  json=$(curl -sf "${base_url}/memstats" 2>/dev/null || echo '{}')
  heap_used=$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(round(d.get('heapUsed',0)/1048576,2))" 2>/dev/null || echo "0")
  heap_max=$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(round(d.get('heapMax',0)/1048576,2))" 2>/dev/null || echo "0")
  gc_count=$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(g.get('count',0) for g in d.get('gc',[])))" 2>/dev/null || echo "0")
  gc_time=$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(g.get('time',0) for g in d.get('gc',[])))" 2>/dev/null || echo "0")
  echo "${heap_used},${heap_max},${gc_count},${gc_time}"
}

# ─── Sample one row to CSV ─────────────────────────────────────────────────────
# CSV schemas:
#   go:     timestamp,phase,rss_mb,heap_mb,sys_mb,stack_mb,goroutines,heap_objects,gc_cycles,gc_pause_total_ms,gc_pause_last_us
#   jvm:    timestamp,phase,server,rss_mb,heap_mb,nonheap_mb,gc_count,gc_time_ms,gc_max_pause_ms,threads
#   vertx:  same jvm schema, nonheap_mb=heap_max, gc_max_pause_ms=0, threads=0
sample_to_csv() {
  local phase=${1:-$(cat "$PHASE_FILE" 2>/dev/null || echo "unknown")}
  local ts
  ts=$(date +%Y-%m-%dT%H:%M:%S)

  case "$CURRENT_SERVER" in
    go)
      local pid rss go_json heap sys stack goroutines heap_objects gc_cycles gc_pause_total gc_pause_last
      pid=$(get_pid $GO_PORT)
      rss=$(get_rss_mb "$pid")
      go_json=$(collect_go_metrics)
      heap=$(echo "$go_json"         | python3 -c "import sys,json; print(round(json.load(sys.stdin).get('heap_alloc_mb',0),2))" 2>/dev/null || echo "0")
      sys=$(echo "$go_json"          | python3 -c "import sys,json; print(round(json.load(sys.stdin).get('sys_mb',0),2))" 2>/dev/null || echo "0")
      stack=$(echo "$go_json"        | python3 -c "import sys,json; print(round(json.load(sys.stdin).get('stack_inuse_mb',0),2))" 2>/dev/null || echo "0")
      goroutines=$(echo "$go_json"   | python3 -c "import sys,json; print(json.load(sys.stdin).get('goroutines',0))" 2>/dev/null || echo "0")
      heap_objects=$(echo "$go_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('heap_objects',0))" 2>/dev/null || echo "0")
      gc_cycles=$(echo "$go_json"    | python3 -c "import sys,json; print(json.load(sys.stdin).get('gc_cycles',0))" 2>/dev/null || echo "0")
      gc_pause_total=$(echo "$go_json" | python3 -c "import sys,json; print(round(json.load(sys.stdin).get('gc_pause_total_ms',0),1))" 2>/dev/null || echo "0")
      gc_pause_last=$(echo "$go_json"  | python3 -c "import sys,json; print(round(json.load(sys.stdin).get('gc_pause_last_us',0),1))" 2>/dev/null || echo "0")
      echo "${ts},${phase},${rss},${heap},${sys},${stack},${goroutines},${heap_objects},${gc_cycles},${gc_pause_total},${gc_pause_last}" >> "$METRICS_CSV"
      ;;

    spring|vt|webflux)
      local port url pid rss metrics
      case "$CURRENT_SERVER" in
        spring)  port=$SPRING_PORT; url=$SPRING_URL ;;
        vt)      port=$VT_PORT;     url=$VT_URL ;;
        webflux) port=$WF_PORT;     url=$WF_URL ;;
      esac
      pid=$(get_pid "$port")
      rss=$(get_rss_mb "$pid")
      metrics=$(collect_jvm_metrics "$url")
      echo "${ts},${phase},${CURRENT_SERVER},${rss},${metrics}" >> "$METRICS_CSV"
      ;;

    vertx)
      local pid rss metrics heap nonheap gc_count gc_time
      pid=$(get_pid $VERTX_PORT)
      rss=$(get_rss_mb "$pid")
      metrics=$(collect_vertx_metrics "$VERTX_URL")
      IFS=',' read -r heap nonheap gc_count gc_time <<< "$metrics"
      echo "${ts},${phase},${CURRENT_SERVER},${rss},${heap},${nonheap},${gc_count},${gc_time},0,0" >> "$METRICS_CSV"
      ;;
  esac
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

# ─── Server lifecycle ──────────────────────────────────────────────────────────
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

start_go_server() {
  echo ">>> Building & starting Go server (port ${GO_PORT})..."
  pushd "$GO_PROJECT_DIR" > /dev/null
  go build -o investigate_bff_bin . 2>&1
  ./investigate_bff_bin &
  popd > /dev/null
  wait_ready "${GO_URL}/health" "Go" 15
}

start_spring_server() {
  echo ">>> Starting Spring Boot server (port ${SPRING_PORT})..."
  pushd "$SPRING_PROJECT_DIR" > /dev/null
  nohup ./gradlew bootRun > /tmp/spring_v2.log 2>&1 &
  popd > /dev/null
  # Spring is slow to start; allow 90s (45 retries × 2s)
  wait_ready "${SPRING_URL}/actuator/health" "Spring" 45
}

start_vt_server() {
  echo ">>> Starting Virtual Threads server (port ${VT_PORT})..."
  pushd "$VT_PROJECT_DIR" > /dev/null
  nohup ./gradlew bootRun > /tmp/vt_v2.log 2>&1 &
  popd > /dev/null
  wait_ready "${VT_URL}/actuator/health" "VirtualThreads" 45
}

start_webflux_server() {
  echo ">>> Starting WebFlux server (port ${WF_PORT})..."
  pushd "$WF_PROJECT_DIR" > /dev/null
  nohup ./gradlew bootRun > /tmp/wf_v2.log 2>&1 &
  popd > /dev/null
  wait_ready "${WF_URL}/actuator/health" "WebFlux" 45
}

start_vertx_server() {
  echo ">>> Starting Vert.x server (port ${VERTX_PORT})..."
  local jar="${VERTX_PROJECT_DIR}/build/libs/investigate-bff-vertx.jar"
  if [[ ! -f "$jar" ]]; then
    echo "  Building Vert.x shadow JAR..."
    pushd "$VERTX_PROJECT_DIR" > /dev/null
    ./gradlew shadowJar -q
    popd > /dev/null
  fi
  nohup java -jar "$jar" > /tmp/vertx_v2.log 2>&1 &
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

# ─── Crash recovery ────────────────────────────────────────────────────────────
health_check_and_recover() {
  local server_type=$1 phase=$2
  local url port

  case "$server_type" in
    go)      url="${GO_URL}/health";             port=$GO_PORT ;;
    spring)  url="${SPRING_URL}/actuator/health"; port=$SPRING_PORT ;;
    vt)      url="${VT_URL}/actuator/health";     port=$VT_PORT ;;
    webflux) url="${WF_URL}/actuator/health";     port=$WF_PORT ;;
    vertx)   url="${VERTX_URL}/health";           port=$VERTX_PORT ;;
  esac

  if curl -sf "$url" > /dev/null 2>&1; then
    return 0
  fi

  echo "  [CRASH] $server_type is DOWN during phase '$phase'"
  local ts
  ts=$(date +%Y-%m-%dT%H:%M:%S)
  increment_crash_count "$CRASH_COUNT_FILE"
  echo "${ts},${phase},restart_$(get_crash_count "$CRASH_COUNT_FILE")" >> "$CRASH_LOG"

  stop_server "$port" "$server_type"

  case "$server_type" in
    go)      start_go_server ;;
    spring)  start_spring_server ;;
    vt)      start_vt_server ;;
    webflux) start_webflux_server ;;
    vertx)   start_vertx_server ;;
  esac
}

# ─── Cooldown helper ───────────────────────────────────────────────────────────
cooldown() {
  local test_name=$1
  set_phase "cooldown_${test_name}"
  sleep "$COOLDOWN_SECONDS"
}
