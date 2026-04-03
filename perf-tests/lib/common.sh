#!/usr/bin/env bash
# ─── Shared functions for perf test infrastructure ─────────────────────────────
# Sourced by run_master.sh and tests/test_*.sh

set -uo pipefail

# ─── Project paths ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GO_PROJECT_DIR="${SCRIPT_DIR}/../investigate_bff_go"
SPRING_PROJECT_DIR="${SCRIPT_DIR}/../investigate_bff_spring"

GO_PORT=8080
SPRING_PORT=8084
GO_URL="http://localhost:${GO_PORT}"
SPRING_URL="http://localhost:${SPRING_PORT}"

SAMPLE_INTERVAL=5
COOLDOWN_SECONDS=15

# ─── Crash tracking ───────────────────────────────────────────────────────────
# Crash counts stored in files so child scripts can increment them
# Preserve exported values from parent process (run_master.sh)
GO_CRASH_COUNT_FILE="${GO_CRASH_COUNT_FILE:-}"
SPRING_CRASH_COUNT_FILE="${SPRING_CRASH_COUNT_FILE:-}"

increment_crash_count() {
  local file=$1
  local current
  current=$(cat "$file" 2>/dev/null || echo "0")
  echo $((current + 1)) > "$file"
}

get_crash_count() {
  cat "$1" 2>/dev/null || echo "0"
}

# ─── State files (set by run_master.sh before starting sampler) ────────────────
# Preserve exported values from parent process when sourced by child test scripts
PHASE_FILE="${PHASE_FILE:-}"
METRICS_CSV="${METRICS_CSV:-}"
CRASH_LOG="${CRASH_LOG:-}"
CURRENT_SERVER="${CURRENT_SERVER:-}"   # "go" or "spring"
SAMPLER_PID="${SAMPLER_PID:-}"

# ─── PID / RSS helpers ────────────────────────────────────────────────────────
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

# ─── Metric collection ────────────────────────────────────────────────────────
collect_go_metrics() {
  curl -sf "${GO_URL}/memstats" 2>/dev/null || echo '{}'
}

collect_spring_metrics() {
  local heap nonheap gc_count gc_time gc_max threads
  heap=$(curl -sf "${SPRING_URL}/actuator/metrics/jvm.memory.used?tag=area:heap" 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['measurements'][0]['value']/1048576)" 2>/dev/null || echo "0")
  nonheap=$(curl -sf "${SPRING_URL}/actuator/metrics/jvm.memory.used?tag=area:nonheap" 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['measurements'][0]['value']/1048576)" 2>/dev/null || echo "0")
  gc_count=$(curl -sf "${SPRING_URL}/actuator/metrics/jvm.gc.pause" 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin)['measurements']; print(int([m['value'] for m in d if m['statistic']=='COUNT'][0]))" 2>/dev/null || echo "0")
  gc_time=$(curl -sf "${SPRING_URL}/actuator/metrics/jvm.gc.pause" 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin)['measurements']; print(round([m['value'] for m in d if m['statistic']=='TOTAL_TIME'][0]*1000))" 2>/dev/null || echo "0")
  gc_max=$(curl -sf "${SPRING_URL}/actuator/metrics/jvm.gc.pause" 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin)['measurements']; print(round([m['value'] for m in d if m['statistic']=='MAX'][0]*1000))" 2>/dev/null || echo "0")
  threads=$(curl -sf "${SPRING_URL}/actuator/metrics/jvm.threads.live" 2>/dev/null \
    | python3 -c "import sys,json; print(int(json.load(sys.stdin)['measurements'][0]['value']))" 2>/dev/null || echo "0")
  echo "${heap},${nonheap},${gc_count},${gc_time},${gc_max},${threads}"
}

# ─── Sample one row to CSV ────────────────────────────────────────────────────
# CSV columns differ based on server type:
#   Go:     timestamp,phase,rss_mb,heap_mb,sys_mb,stack_mb,goroutines,heap_objects,gc_cycles,gc_pause_total_ms,gc_pause_last_us
#   Spring: timestamp,phase,rss_mb,heap_mb,nonheap_mb,gc_count,gc_time_ms,gc_max_pause_ms,threads
sample_to_csv() {
  local phase=${1:-$(cat "$PHASE_FILE" 2>/dev/null || echo "unknown")}
  local ts
  ts=$(date +%Y-%m-%dT%H:%M:%S)

  if [[ "$CURRENT_SERVER" == "go" ]]; then
    local pid rss go_json heap sys stack goroutines heap_objects gc_cycles gc_pause_total gc_pause_last
    pid=$(get_pid $GO_PORT)
    rss=$(get_rss_mb "$pid")
    go_json=$(collect_go_metrics)
    heap=$(echo "$go_json" | python3 -c "import sys,json; print(round(json.load(sys.stdin).get('heap_alloc_mb',0),2))" 2>/dev/null || echo "0")
    sys=$(echo "$go_json" | python3 -c "import sys,json; print(round(json.load(sys.stdin).get('sys_mb',0),2))" 2>/dev/null || echo "0")
    stack=$(echo "$go_json" | python3 -c "import sys,json; print(round(json.load(sys.stdin).get('stack_inuse_mb',0),2))" 2>/dev/null || echo "0")
    goroutines=$(echo "$go_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('goroutines',0))" 2>/dev/null || echo "0")
    heap_objects=$(echo "$go_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('heap_objects',0))" 2>/dev/null || echo "0")
    gc_cycles=$(echo "$go_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('gc_cycles',0))" 2>/dev/null || echo "0")
    gc_pause_total=$(echo "$go_json" | python3 -c "import sys,json; print(round(json.load(sys.stdin).get('gc_pause_total_ms',0),1))" 2>/dev/null || echo "0")
    gc_pause_last=$(echo "$go_json" | python3 -c "import sys,json; print(round(json.load(sys.stdin).get('gc_pause_last_us',0),1))" 2>/dev/null || echo "0")
    echo "${ts},${phase},${rss},${heap},${sys},${stack},${goroutines},${heap_objects},${gc_cycles},${gc_pause_total},${gc_pause_last}" >> "$METRICS_CSV"

  elif [[ "$CURRENT_SERVER" == "spring" ]]; then
    local pid rss spring_metrics
    pid=$(get_pid $SPRING_PORT)
    rss=$(get_rss_mb "$pid")
    spring_metrics=$(collect_spring_metrics)
    echo "${ts},${phase},${rss},${spring_metrics}" >> "$METRICS_CSV"
  fi
}

# ─── Phase management ─────────────────────────────────────────────────────────
set_phase() {
  echo "$1" > "$PHASE_FILE"
  echo "  [phase] $1"
}

# ─── Background sampling loop ─────────────────────────────────────────────────
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

# ─── Server management ────────────────────────────────────────────────────────
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

start_go_server() {
  echo ">>> Building & starting Go server..."
  pushd "$GO_PROJECT_DIR" > /dev/null
  go build -o investigate_bff_bin . 2>&1
  ./investigate_bff_bin &
  popd > /dev/null
  wait_ready "${GO_URL}/health" "Go" 15
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
  # Verify port is free
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

start_spring_server() {
  echo ">>> Starting Spring Boot server..."
  pushd "$SPRING_PROJECT_DIR" > /dev/null
  ./gradlew bootRun &
  popd > /dev/null
  wait_ready "${SPRING_URL}/actuator/health" "Spring" 60
}

# ─── Health check & crash recovery ────────────────────────────────────────────
health_check() {
  local server_type=$1 phase=$2
  local url pid_port

  if [[ "$server_type" == "go" ]]; then
    url="${GO_URL}/health"
    pid_port=$GO_PORT
  else
    url="${SPRING_URL}/actuator/health"
    pid_port=$SPRING_PORT
  fi

  if curl -sf "$url" > /dev/null 2>&1; then
    return 0
  fi

  echo "  [CRASH] $server_type is DOWN during phase '$phase'"
  local ts
  ts=$(date +%Y-%m-%dT%H:%M:%S)

  if [[ "$server_type" == "go" ]]; then
    increment_crash_count "$GO_CRASH_COUNT_FILE"
    echo "${ts},${phase},restart_$(get_crash_count "$GO_CRASH_COUNT_FILE")" >> "$CRASH_LOG"
    stop_server $GO_PORT "Go"
    start_go_server
  else
    increment_crash_count "$SPRING_CRASH_COUNT_FILE"
    echo "${ts},${phase},restart_$(get_crash_count "$SPRING_CRASH_COUNT_FILE")" >> "$CRASH_LOG"
    stop_server $SPRING_PORT "Spring"
    start_spring_server
  fi
}

# ─── Cooldown ──────────────────────────────────────────────────────────────────
cooldown() {
  local test_name=$1
  set_phase "cooldown_${test_name}"
  sleep "$COOLDOWN_SECONDS"
}
