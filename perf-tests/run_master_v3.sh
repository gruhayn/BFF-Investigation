#!/usr/bin/env bash
# ─── Master Orchestrator V3 — All 5 Tools × All 5 Servers ────────────────────
# Runs a complete benchmark suite for every BFF implementation in one go:
#
#   Servers:  Go (8080)  Spring MVC (8084)  Virtual Threads (8081)
#             WebFlux (8082)  Vert.x (8083)
#
#   Tools per server (3 endpoints × each):
#     1. hey    — 10k/200c  +  50k/500c
#     2. ab     — 50k/100c
#     3. k6     — ramp / stress / spike / multi-endpoint
#     4. wrk    — 4t/50c/30s  +  8t/500c/30s
#     5. vegeta — 100 / 1k / 5k rps / 30s
#
# Usage: bash run_master_v3.sh
# Results: results_v3_TIMESTAMP/{go,spring,vt,webflux,vertx}/
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common_v2.sh"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="${SCRIPT_DIR}/results_v3_${TIMESTAMP}"
GO_DIR="${RESULTS_DIR}/go"
SPRING_DIR="${RESULTS_DIR}/spring"
VT_DIR="${RESULTS_DIR}/vt"
WF_DIR="${RESULTS_DIR}/webflux"
VERTX_DIR="${RESULTS_DIR}/vertx"
mkdir -p "$GO_DIR" "$SPRING_DIR" "$VT_DIR" "$WF_DIR" "$VERTX_DIR"

echo "=================================================================="
echo " Performance Test Suite V3 — All 5 Tools × All 5 Servers"
echo " Go | Spring MVC | Virtual Threads | WebFlux | Vert.x"
echo " Tools: hey  ab  k6  wrk  vegeta"
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

# ─── Run all tools for one server ─────────────────────────────────────────────
run_server_tests() {
    local server_type=$1   # go | spring | vt | webflux | vertx
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

    verify_endpoints "$base_url" "$server_upper"

    PHASE_FILE=$(mktemp)
    echo "idle" > "$PHASE_FILE"
    export CURRENT_SERVER METRICS_CSV CRASH_LOG PHASE_FILE CRASH_COUNT_FILE

    start_sampler

    # ── Idle baseline ─────────────────────────────────────────────────────────
    set_phase "idle"
    echo ">>> Recording idle baseline (15s)..."
    sleep 15
    sample_to_csv "idle"

    local ep_urls=("/customers" "/accounts" "/customer-summary?id=c1")
    local ep_names=("customers" "accounts" "customer_summary")

    # ── 1. hey ────────────────────────────────────────────────────────────────
    echo ""
    echo "--- [1/5] hey ---"
    for i in 0 1 2; do
        local ep="${ep_urls[$i]}"
        local name="${ep_names[$i]}"

        set_phase "hey_${name}_10k"
        echo ">>> hey: ${name} 10k/200c"
        hey -n 10000 -c 200 "${base_url}${ep}" > "${output_dir}/hey_${name}_10k.txt" 2>&1
        sample_to_csv "hey_${name}_10k"
        health_check_and_recover "$server_type" "hey_${name}_10k"
        sleep "$COOLDOWN_SECONDS"

        set_phase "hey_${name}_50k"
        echo ">>> hey: ${name} 50k/500c"
        hey -n 50000 -c 500 "${base_url}${ep}" > "${output_dir}/hey_${name}_50k.txt" 2>&1
        sample_to_csv "hey_${name}_50k"
        health_check_and_recover "$server_type" "hey_${name}_50k"
        sleep "$COOLDOWN_SECONDS"
    done

    # ── 2. ab ─────────────────────────────────────────────────────────────────
    echo ""
    echo "--- [2/5] ab (50k/100c) ---"
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

    # ── 3. k6 ─────────────────────────────────────────────────────────────────
    echo ""
    echo "--- [3/5] k6 ---"
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

    set_phase "k6_multi"
    echo ">>> k6: multi-endpoint"
    BASE_URL="$base_url" k6 run "${SCRIPT_DIR}/k6_multi_endpoint.js" \
        --summary-export "${output_dir}/k6_multi.json" \
        > "${output_dir}/k6_multi.txt" 2>&1
    sample_to_csv "k6_multi"
    health_check_and_recover "$server_type" "k6_multi"
    sleep "$COOLDOWN_SECONDS"

    # ── 4. wrk ────────────────────────────────────────────────────────────────
    echo ""
    echo "--- [4/5] wrk ---"
    for i in 0 1 2; do
        local ep="${ep_urls[$i]}"
        local name="${ep_names[$i]}"

        set_phase "wrk_${name}_50c"
        echo ">>> wrk: ${name} 4t/50c/30s"
        wrk -t4 -c50 -d30s "${base_url}${ep}" > "${output_dir}/wrk_${name}_50c.txt" 2>&1
        health_check_and_recover "$server_type" "wrk_${name}_50c"
        sleep "$COOLDOWN_SECONDS"

        set_phase "wrk_${name}_500c"
        echo ">>> wrk: ${name} 8t/500c/30s"
        wrk -t8 -c500 -d30s "${base_url}${ep}" > "${output_dir}/wrk_${name}_500c.txt" 2>&1
        health_check_and_recover "$server_type" "wrk_${name}_500c"
        sleep "$COOLDOWN_SECONDS"
    done

    # ── 5. vegeta ─────────────────────────────────────────────────────────────
    echo ""
    echo "--- [5/5] vegeta ---"
    local rates=("100" "1000" "5000")
    local rate_names=("100" "1k" "5k")
    for i in 0 1 2; do
        local ep="${ep_urls[$i]}"
        local name="${ep_names[$i]}"

        for r in 0 1 2; do
            local rate="${rates[$r]}"
            local rate_name="${rate_names[$r]}"
            set_phase "vegeta_${name}_${rate_name}"
            echo ">>> vegeta: ${name} ${rate_name} rps/30s"
            echo "GET ${base_url}${ep}" \
                | vegeta attack -rate="$rate" -duration=30s \
                | vegeta report > "${output_dir}/vegeta_${name}_${rate_name}.txt" 2>&1
            health_check_and_recover "$server_type" "vegeta_${name}_${rate_name}"
            sleep "$COOLDOWN_SECONDS"
        done
    done

    # ── Final cooldown ────────────────────────────────────────────────────────
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
run_server_tests "go"      "$GO_URL"     "$GO_DIR"     "$GO_PORT"
echo ">>> Pausing 5s between servers..."; sleep 5

run_server_tests "spring"  "$SPRING_URL" "$SPRING_DIR" "$SPRING_PORT"
echo ">>> Pausing 5s between servers..."; sleep 5

run_server_tests "vt"      "$VT_URL"     "$VT_DIR"     "$VT_PORT"
echo ">>> Pausing 5s between servers..."; sleep 5

run_server_tests "webflux" "$WF_URL"     "$WF_DIR"     "$WF_PORT"
echo ">>> Pausing 5s between servers..."; sleep 5

run_server_tests "vertx"   "$VERTX_URL"  "$VERTX_DIR"  "$VERTX_PORT"

# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "=================================================================="
echo " ALL TESTS COMPLETE — V3"
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
echo "   python3 extract_perf_v3.py ${RESULTS_DIR}"
echo "=================================================================="
