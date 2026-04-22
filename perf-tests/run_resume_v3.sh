#!/usr/bin/env bash
# ─── Resume V3 — WebFlux (partial) + Vert.x (full) ──────────────────────────
# Resumes the interrupted run_master_v3.sh run.
# WebFlux already has: hey (all), ab (all), k6 customers (ramp/stress/spike)
# Resumes from: k6 accounts onwards for WebFlux, then full Vertx.
#
# Usage: bash run_resume_v3.sh results_v3_20260421_095020
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common_v2.sh"

RESULTS_DIR="${SCRIPT_DIR}/${1:?Usage: bash run_resume_v3.sh <results_dir>}"
WF_DIR="${RESULTS_DIR}/webflux"
VERTX_DIR="${RESULTS_DIR}/vertx"

if [[ ! -d "$WF_DIR" ]]; then
    echo "ERROR: WebFlux dir not found: $WF_DIR" >&2
    exit 1
fi
mkdir -p "$VERTX_DIR"

echo "=================================================================="
echo " V3 Resume — WebFlux (partial) + Vert.x (full)"
echo " Resuming into: ${RESULTS_DIR}"
echo " Started: $(date)"
echo "=================================================================="

# ─── Ensure ports are free ────────────────────────────────────────────────────
echo ""
echo ">>> Ensuring all ports are free..."
for port_name in "$GO_PORT:Go" "$SPRING_PORT:Spring" "$VT_PORT:VT" "$WF_PORT:WebFlux" "$VERTX_PORT:Vertx"; do
    port="${port_name%%:*}"
    name="${port_name##*:}"
    stop_server "$port" "${name} (cleanup)" 2>/dev/null || true
done
sleep 3

# ═══════════════════════════════════════════════════════════════════════════════
# ─── WebFlux Resume ───────────────────────────────────────────────────────────
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "=============================="
echo " WEBFLUX SERVER TESTS (RESUME)"
echo "=============================="
echo ""

CURRENT_SERVER="webflux"
METRICS_CSV="${WF_DIR}/metrics.csv"
CRASH_LOG="${WF_DIR}/crash_log.csv"
CRASH_COUNT_FILE="${WF_DIR}/.crash_count"
# Don't reset crash count — append to existing CSV
if [[ ! -f "$CRASH_COUNT_FILE" ]]; then echo "0" > "$CRASH_COUNT_FILE"; fi
export CURRENT_SERVER METRICS_CSV CRASH_LOG CRASH_COUNT_FILE

WF_START=$(date +%s)

start_webflux_server
verify_endpoints "$WF_URL" "WEBFLUX"

PHASE_FILE=$(mktemp)
echo "resume" > "$PHASE_FILE"
export PHASE_FILE

start_sampler

local_ep_urls=("/customers" "/accounts" "/customer-summary?id=c1")
local_ep_names=("customers" "accounts" "customer_summary")

# ── k6 accounts + customer_summary (customers already done) ──────────────────
echo ""
echo "--- [3/5] k6 (resume: accounts + customer_summary + multi) ---"
k6_scenarios=("k6_test.js:ramp" "k6_stress.js:stress" "k6_spike.js:spike")
for i in 1 2; do   # index 1=accounts, 2=customer_summary
    ep="${local_ep_urls[$i]}"
    name="${local_ep_names[$i]}"
    for scenario_entry in "${k6_scenarios[@]}"; do
        js_file="${scenario_entry%%:*}"
        scenario="${scenario_entry##*:}"
        set_phase "k6_${scenario}_${name}"
        echo ">>> k6: ${scenario} / ${name}"
        BASE_URL="$WF_URL" ENDPOINT="$ep" k6 run "${SCRIPT_DIR}/${js_file}" \
            --summary-export "${WF_DIR}/k6_${scenario}_${name}.json" \
            > "${WF_DIR}/k6_${scenario}_${name}.txt" 2>&1
        sample_to_csv "k6_${scenario}_${name}"
        health_check_and_recover "webflux" "k6_${scenario}_${name}"
        sleep "$COOLDOWN_SECONDS"
    done
done

set_phase "k6_multi"
echo ">>> k6: multi-endpoint"
BASE_URL="$WF_URL" k6 run "${SCRIPT_DIR}/k6_multi_endpoint.js" \
    --summary-export "${WF_DIR}/k6_multi.json" \
    > "${WF_DIR}/k6_multi.txt" 2>&1
sample_to_csv "k6_multi"
health_check_and_recover "webflux" "k6_multi"
sleep "$COOLDOWN_SECONDS"

# ── wrk ───────────────────────────────────────────────────────────────────────
echo ""
echo "--- [4/5] wrk ---"
for i in 0 1 2; do
    ep="${local_ep_urls[$i]}"
    name="${local_ep_names[$i]}"
    set_phase "wrk_${name}_50c"
    echo ">>> wrk: ${name} 4t/50c/30s"
    wrk -t4 -c50 -d30s "${WF_URL}${ep}" > "${WF_DIR}/wrk_${name}_50c.txt" 2>&1
    health_check_and_recover "webflux" "wrk_${name}_50c"
    sleep "$COOLDOWN_SECONDS"

    set_phase "wrk_${name}_500c"
    echo ">>> wrk: ${name} 8t/500c/30s"
    wrk -t8 -c500 -d30s "${WF_URL}${ep}" > "${WF_DIR}/wrk_${name}_500c.txt" 2>&1
    health_check_and_recover "webflux" "wrk_${name}_500c"
    sleep "$COOLDOWN_SECONDS"
done

# ── vegeta ────────────────────────────────────────────────────────────────────
echo ""
echo "--- [5/5] vegeta ---"
rates=("100" "1000" "5000")
rate_names=("100" "1k" "5k")
for i in 0 1 2; do
    ep="${local_ep_urls[$i]}"
    name="${local_ep_names[$i]}"
    for r in 0 1 2; do
        rate="${rates[$r]}"
        rate_name="${rate_names[$r]}"
        set_phase "vegeta_${name}_${rate_name}"
        echo ">>> vegeta: ${name} ${rate_name} rps/30s"
        echo "GET ${WF_URL}${ep}" \
            | vegeta attack -rate="$rate" -duration=30s \
            | vegeta report > "${WF_DIR}/vegeta_${name}_${rate_name}.txt" 2>&1
        health_check_and_recover "webflux" "vegeta_${name}_${rate_name}"
        sleep "$COOLDOWN_SECONDS"
    done
done

# ── Final cooldown ────────────────────────────────────────────────────────────
set_phase "final_cooldown"
echo ">>> Final cooldown (30s)..."
sleep 30
sample_to_csv "final_cooldown"

stop_sampler
stop_server "$WF_PORT" "WEBFLUX"

WF_END=$(date +%s)
WF_ELAPSED=$((WF_END - WF_START))
WF_SAMPLES=$(tail -n +2 "$METRICS_CSV" | wc -l | tr -d ' ')
WF_CRASHES=$(get_crash_count "$CRASH_COUNT_FILE")
echo ""
echo "  WEBFLUX done:"
echo "    Duration:  ${WF_ELAPSED}s"
echo "    Samples:   ${WF_SAMPLES}"
echo "    Crashes:   ${WF_CRASHES}"
echo "    Output:    ${WF_DIR}"
echo ""

echo ">>> Pausing 5s between servers..."; sleep 5

# ═══════════════════════════════════════════════════════════════════════════════
# ─── Vert.x Full Run ──────────────────────────────────────────────────────────
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "=============================="
echo " VERTX SERVER TESTS"
echo "=============================="
echo ""

CURRENT_SERVER="vertx"
METRICS_CSV="${VERTX_DIR}/metrics.csv"
CRASH_LOG="${VERTX_DIR}/crash_log.csv"
CRASH_COUNT_FILE="${VERTX_DIR}/.crash_count"
echo "0" > "$CRASH_COUNT_FILE"
echo "timestamp,phase,server,rss_mb,heap_mb,nonheap_mb,gc_count,gc_time_ms,gc_max_pause_ms,threads" > "$METRICS_CSV"
echo "timestamp,phase,event" > "$CRASH_LOG"
export CURRENT_SERVER METRICS_CSV CRASH_LOG CRASH_COUNT_FILE

VERTX_START=$(date +%s)

start_vertx_server
verify_endpoints "$VERTX_URL" "VERTX"

PHASE_FILE=$(mktemp)
echo "idle" > "$PHASE_FILE"
export PHASE_FILE

start_sampler

set_phase "idle"
echo ">>> Recording idle baseline (15s)..."
sleep 15
sample_to_csv "idle"

vx_ep_urls=("/customers" "/accounts" "/customer-summary?id=c1")
vx_ep_names=("customers" "accounts" "customer_summary")

# ── hey ───────────────────────────────────────────────────────────────────────
echo ""
echo "--- [1/5] hey ---"
for i in 0 1 2; do
    ep="${vx_ep_urls[$i]}"
    name="${vx_ep_names[$i]}"
    set_phase "hey_${name}_10k"
    echo ">>> hey: ${name} 10k/200c"
    hey -n 10000 -c 200 "${VERTX_URL}${ep}" > "${VERTX_DIR}/hey_${name}_10k.txt" 2>&1
    sample_to_csv "hey_${name}_10k"
    health_check_and_recover "vertx" "hey_${name}_10k"
    sleep "$COOLDOWN_SECONDS"

    set_phase "hey_${name}_50k"
    echo ">>> hey: ${name} 50k/500c"
    hey -n 50000 -c 500 "${VERTX_URL}${ep}" > "${VERTX_DIR}/hey_${name}_50k.txt" 2>&1
    sample_to_csv "hey_${name}_50k"
    health_check_and_recover "vertx" "hey_${name}_50k"
    sleep "$COOLDOWN_SECONDS"
done

# ── ab ────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [2/5] ab (50k/100c) ---"
for i in 0 1 2; do
    ep="${vx_ep_urls[$i]}"
    name="${vx_ep_names[$i]}"
    set_phase "ab_${name}_50k"
    echo ">>> ab: ${name} 50k/100c"
    ab -n 50000 -c 100 "${VERTX_URL}${ep}" > "${VERTX_DIR}/ab_${name}_50k.txt" 2>&1
    sample_to_csv "ab_${name}_50k"
    health_check_and_recover "vertx" "ab_${name}_50k"
    sleep "$COOLDOWN_SECONDS"
done

# ── k6 ────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [3/5] k6 ---"
vx_k6_scenarios=("k6_test.js:ramp" "k6_stress.js:stress" "k6_spike.js:spike")
for i in 0 1 2; do
    ep="${vx_ep_urls[$i]}"
    name="${vx_ep_names[$i]}"
    for scenario_entry in "${vx_k6_scenarios[@]}"; do
        js_file="${scenario_entry%%:*}"
        scenario="${scenario_entry##*:}"
        set_phase "k6_${scenario}_${name}"
        echo ">>> k6: ${scenario} / ${name}"
        BASE_URL="$VERTX_URL" ENDPOINT="$ep" k6 run "${SCRIPT_DIR}/${js_file}" \
            --summary-export "${VERTX_DIR}/k6_${scenario}_${name}.json" \
            > "${VERTX_DIR}/k6_${scenario}_${name}.txt" 2>&1
        sample_to_csv "k6_${scenario}_${name}"
        health_check_and_recover "vertx" "k6_${scenario}_${name}"
        sleep "$COOLDOWN_SECONDS"
    done
done

set_phase "k6_multi"
echo ">>> k6: multi-endpoint"
BASE_URL="$VERTX_URL" k6 run "${SCRIPT_DIR}/k6_multi_endpoint.js" \
    --summary-export "${VERTX_DIR}/k6_multi.json" \
    > "${VERTX_DIR}/k6_multi.txt" 2>&1
sample_to_csv "k6_multi"
health_check_and_recover "vertx" "k6_multi"
sleep "$COOLDOWN_SECONDS"

# ── wrk ───────────────────────────────────────────────────────────────────────
echo ""
echo "--- [4/5] wrk ---"
for i in 0 1 2; do
    ep="${vx_ep_urls[$i]}"
    name="${vx_ep_names[$i]}"
    set_phase "wrk_${name}_50c"
    echo ">>> wrk: ${name} 4t/50c/30s"
    wrk -t4 -c50 -d30s "${VERTX_URL}${ep}" > "${VERTX_DIR}/wrk_${name}_50c.txt" 2>&1
    health_check_and_recover "vertx" "wrk_${name}_50c"
    sleep "$COOLDOWN_SECONDS"

    set_phase "wrk_${name}_500c"
    echo ">>> wrk: ${name} 8t/500c/30s"
    wrk -t8 -c500 -d30s "${VERTX_URL}${ep}" > "${VERTX_DIR}/wrk_${name}_500c.txt" 2>&1
    health_check_and_recover "vertx" "wrk_${name}_500c"
    sleep "$COOLDOWN_SECONDS"
done

# ── vegeta ────────────────────────────────────────────────────────────────────
echo ""
echo "--- [5/5] vegeta ---"
vx_rates=("100" "1000" "5000")
vx_rate_names=("100" "1k" "5k")
for i in 0 1 2; do
    ep="${vx_ep_urls[$i]}"
    name="${vx_ep_names[$i]}"
    for r in 0 1 2; do
        rate="${vx_rates[$r]}"
        rate_name="${vx_rate_names[$r]}"
        set_phase "vegeta_${name}_${rate_name}"
        echo ">>> vegeta: ${name} ${rate_name} rps/30s"
        echo "GET ${VERTX_URL}${ep}" \
            | vegeta attack -rate="$rate" -duration=30s \
            | vegeta report > "${VERTX_DIR}/vegeta_${name}_${rate_name}.txt" 2>&1
        health_check_and_recover "vertx" "vegeta_${name}_${rate_name}"
        sleep "$COOLDOWN_SECONDS"
    done
done

# ── Final cooldown ────────────────────────────────────────────────────────────
set_phase "final_cooldown"
echo ">>> Final cooldown (30s)..."
sleep 30
sample_to_csv "final_cooldown"

stop_sampler
stop_server "$VERTX_PORT" "VERTX"

VERTX_END=$(date +%s)
VERTX_ELAPSED=$((VERTX_END - VERTX_START))
VERTX_SAMPLES=$(tail -n +2 "$METRICS_CSV" | wc -l | tr -d ' ')
VERTX_CRASHES=$(get_crash_count "$CRASH_COUNT_FILE")
echo ""
echo "  VERTX done:"
echo "    Duration:  ${VERTX_ELAPSED}s"
echo "    Samples:   ${VERTX_SAMPLES}"
echo "    Crashes:   ${VERTX_CRASHES}"
echo "    Output:    ${VERTX_DIR}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "=================================================================="
echo " RESUME COMPLETE — V3"
echo " Finished: $(date)"
echo " Results:  ${RESULTS_DIR}"
echo ""
for srv_info in "go:${RESULTS_DIR}/go" "spring:${RESULTS_DIR}/spring" "vt:${RESULTS_DIR}/vt" "webflux:${WF_DIR}" "vertx:${VERTX_DIR}"; do
    srv="${srv_info%%:*}"
    dir="${srv_info##*:}"
    crash_file="${dir}/.crash_count"
    samples=$(tail -n +2 "${dir}/metrics.csv" 2>/dev/null | wc -l | tr -d ' ')
    crashes=$(get_crash_count "$crash_file")
    printf "  %-10s  samples=%-4s  crashes=%s\n" "$srv" "$samples" "$crashes"
done
echo ""
echo " Run extractor:"
echo "   python3 extract_perf_v3.py ${RESULTS_DIR}"
echo "=================================================================="
